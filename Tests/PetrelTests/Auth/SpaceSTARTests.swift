import Crypto
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import PetrelCrypto
import Testing

@Suite("November 12 STAR and MAC responses")
struct SpaceSTARTests {
    let repo = "did:example:alice"
    let space = try! SpaceRef(uriString: "at://did:example:space/space/app.bsky.group/test")
    let rev = "3kbcq3p7ad422"
    let secret = Data(0 ..< 32)

    func frame(_ bytes: Data) -> Data {
        var length = bytes.count
        var prefix = Data()
        repeat {
            var byte = UInt8(length & 127)
            length >>= 7
            if length != 0 { byte |= 128 }
            prefix.append(byte)
        } while length != 0
        return prefix + bytes
    }

    func archive(records: [(String, Data)], digest: Data? = nil) throws -> (bytes: Data, digest: Data) {
        var set = SpaceSetHash()
        for (path, bytes) in records {
            set.add(path: path, cid: CID.fromDAGCBOR(bytes).string)
        }
        let data = digest ?? set.digest
        let metadata: [String: Any] = [
            "$type": "atproto-space-repo",
            "ver": 1,
            "repo": repo,
            "space": space.uriString(),
            "rev": rev,
            "data": data,
        ]
        var bytes = try Data([0x2A, 0x6C, 1, 0]) + frame(DAGCBOR.encodeValue(metadata))
        for (path, value) in records {
            bytes += Data([1]) + frame(Data(path.utf8)) + frame(value)
        }
        bytes.append(0)
        return (bytes, data)
    }

    func signedResponse(
        profile: SpaceMACHeader.Profile,
        coveredHeader: String,
        keyShare: String,
        tag: String? = nil,
        responseKey: String? = nil,
        duplicateTaggedSignature: Bool = false
    ) throws -> HTTPURLResponse {
        let tag = tag ?? profile.rawValue
        let responseKey = responseKey ?? keyShare
        let parameters = "(\"\(profile.rawValue)\";sf);keyid=\"\(responseKey)\";tag=\"\(tag)\""
        let base = Data(
            "\"\(profile.rawValue)\";sf: \(coveredHeader)\n\"@signature-params\": \(parameters)".utf8
        )
        let authenticationCode = Data(
            HMAC<SHA256>.authenticationCode(for: base, using: SymmetricKey(data: secret))
        ).base64EncodedString()
        let signatureInputs = duplicateTaggedSignature
            ? "mac=\(parameters), other=\(parameters)"
            : "mac=\(parameters)"
        let signatures = duplicateTaggedSignature
            ? "mac=:\(authenticationCode):, other=:\(authenticationCode):"
            : "mac=:\(authenticationCode):"
        return HTTPURLResponse(
            url: URL(string: "https://repo.example")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                profile.responseHeader: coveredHeader,
                "Signature-Input": signatureInputs,
                "Signature": signatures,
            ]
        )!
    }

    @Test("Independent Python cbor2/BLAKE3 archive includes integer and CID-link records")
    func independentArchive() throws {
        // Reproduce with Scripts/generate-space-vectors.py; no Petrel encoder used.
        let bytes = try #require(Data(base64Encoded: "KmwBAKcBpmNyZXZtM2tiY3EzcDdhZDQyMmN2ZXIBZGRhdGFYIAPti/dnzI3Ij07mC2HCTa1QGHC6pGj8nXzGZVYsfhnaZHJlcG9xZGlkOmV4YW1wbGU6YWxpY2VlJHR5cGVyYXRwcm90by1zcGFjZS1yZXBvZXNwYWNleDBhdDovL2RpZDpleGFtcGxlOnNwYWNlL3NwYWNlL2FwcC5ic2t5Lmdyb3VwL3Rlc3QBF2FwcC5ic2t5LmZlZWQucG9zdC9zZWxmQKNjcmVm2CpYJQABcRIgZCjwIwS424yxB8iTNkgfD+rXKL83TKgBaNLHGTjO+udkdGV4dGVoZWxsb2Vjb3VudAEA"))
        let result = try SpaceSTAR.verify(archive: bytes, space: space, repo: repo)
        #expect(result.records.count == 1)
        #expect(result.records[0].cid.string == "bafyreidpnhlqcmg7f3bbn6zd7kr2p3x3ciaqgpy7333hlp3gc4vluyuzvm")
    }

    @Test("Empty and populated archives complete before exposing records")
    func completeArchives() throws {
        for records: [(String, Data)] in try [[], [("app.bsky.feed.post/a", DAGCBOR.encodeValue(["text": "hello"]))]] {
            let archive = try archive(records: records).bytes
            let result = try SpaceSTAR.verify(archive: archive, space: space, repo: repo)
            #expect(result.records.count == records.count)
            #expect(result.revision == rev)
        }
    }

    @Test("End marker, pair controls, and trailing bytes fail closed")
    func archiveControls() throws {
        let valid = try archive(records: []).bytes
        #expect(throws: SpaceVerificationError.invalidArchive) {
            try SpaceSTAR.verify(archive: Data(valid.dropLast()), space: space, repo: repo)
        }
        var badControl = valid
        badControl[badControl.count - 1] = 2
        #expect(throws: SpaceVerificationError.invalidArchive) {
            try SpaceSTAR.verify(archive: badControl, space: space, repo: repo)
        }
        #expect(throws: SpaceVerificationError.invalidArchive) {
            try SpaceSTAR.verify(archive: valid + Data([0]), space: space, repo: repo)
        }
    }

    @Test("Ordering, profile limits, truncated frames, and varints fail closed")
    func malformedArchives() throws {
        let record = try DAGCBOR.encodeValue(["text": "hello"])
        for paths in [["app.bsky.feed.post/a", "app.bsky.feed.post/a"], ["app.bsky.feed.post/b", "app.bsky.feed.post/a"]] {
            let bytes = try archive(records: paths.map { ($0, record) }).bytes
            #expect(throws: (any Error).self) {
                try SpaceSTAR.verify(archive: bytes, space: space, repo: repo)
            }
        }

        let valid = try archive(records: [("app.bsky.feed.post/a", record)]).bytes
        for length in [0, 3, valid.count - 2] {
            #expect(throws: (any Error).self) {
                try SpaceSTAR.verify(archive: Data(valid.prefix(length)), space: space, repo: repo)
            }
        }
        let oversizedValue = try archive(
            records: [("app.bsky.feed.post/a", Data(repeating: 0, count: SpaceSTAR.maximumRecordBytes + 1))]
        ).bytes
        #expect(throws: SpaceVerificationError.boundsExceeded) {
            try SpaceSTAR.verify(archive: oversizedValue, space: space, repo: repo)
        }
        let oversizedKey = try archive(
            records: [(String(repeating: "a", count: SpaceSTAR.maximumKeyBytes + 1), record)]
        ).bytes
        #expect(throws: SpaceVerificationError.boundsExceeded) {
            try SpaceSTAR.verify(archive: oversizedKey, space: space, repo: repo)
        }
        let oversizedMetadata = Data([0x2A, 0x6C, 1, 0]) +
            frame(Data(repeating: 0, count: SpaceSTAR.maximumMetadataBytes + 1)) +
            Data([0])
        #expect(throws: SpaceVerificationError.boundsExceeded) {
            try SpaceSTAR.verify(archive: oversizedMetadata, space: space, repo: repo)
        }

        var nonMinimal = valid
        var end = 4
        while nonMinimal[end] & 128 != 0 {
            end += 1
        }
        nonMinimal[end] |= 128
        nonMinimal.insert(0, at: end + 1)
        #expect(throws: SpaceVerificationError.invalidArchive) {
            try SpaceSTAR.verify(archive: nonMinimal, space: space, repo: repo)
        }
    }

    @Test("Digest, repo, and space are independently enforced")
    func authenticatedContext() throws {
        let record = try DAGCBOR.encodeValue(["text": "hello"])
        let bytes = try archive(records: [("app.bsky.feed.post/a", record)]).bytes
        #expect(throws: SpaceVerificationError.invalidCommit) {
            try SpaceSTAR.verify(archive: bytes, space: space, repo: "did:example:bob")
        }
        let wrongSpace = try SpaceRef(uriString: "at://did:example:space/space/app.bsky.group/other")
        #expect(throws: SpaceVerificationError.invalidCommit) {
            try SpaceSTAR.verify(archive: bytes, space: wrongSpace, repo: repo)
        }
        let wrong = try archive(
            records: [("app.bsky.feed.post/a", record)],
            digest: Data(repeating: 0, count: 32)
        ).bytes
        #expect(throws: SpaceVerificationError.digestMismatch) {
            try SpaceSTAR.verify(archive: wrong, space: space, repo: repo)
        }
    }

    @Test("Non-canonical metadata integers are rejected")
    func nonCanonicalMetadata() throws {
        let digest = SpaceSetHash().digest
        let metadata: [String: Any] = [
            "$type": "atproto-space-repo",
            "ver": 1,
            "repo": repo,
            "space": space.uriString(),
            "rev": rev,
            "data": digest,
        ]
        var encoded = try DAGCBOR.encodeValue(metadata)
        let location = try #require(encoded.range(of: Data([0x63, 0x76, 0x65, 0x72, 0x01])))
        encoded.replaceSubrange((location.upperBound - 1) ..< location.upperBound, with: [0x18, 0x01])
        let malformed = Data([0x2A, 0x6C, 1, 0]) + frame(encoded) + Data([0])
        #expect(throws: (any Error).self) {
            try SpaceSTAR.verify(archive: malformed, space: space, repo: repo)
        }
    }

    @Test("Commit MAC verifies by tag and rejects wrong tag, duplicate tag, and keyid")
    func commitMAC() throws {
        let keyShare = "did:key:zDnaExample"
        let digest = Data(repeating: 1, count: 32)
        let covered = "ver=1, repo=\"\(repo)\", space=\"\(space.uriString())\", rev=\"\(rev)\", data=:\(digest.base64EncodedString()):"
        let valid = try signedResponse(
            profile: .commit, coveredHeader: covered, keyShare: keyShare
        )
        #expect(
            SpaceMACHeader.request(profile: .commit, keyShare: keyShare) ==
                "mac=(\"atproto-space-commit\";sf);keyid=\"\(keyShare)\";tag=\"atproto-space-commit\""
        )
        try SpaceMACHeader.verifyCommit(
            response: valid,
            keyShare: keyShare,
            sharedSecret: secret,
            space: space,
            repo: repo,
            revision: rev,
            data: digest
        )
        #expect(throws: SpaceMAC.Failure.mismatch) {
            try SpaceMACHeader.verifyCommit(
                response: valid,
                keyShare: keyShare,
                sharedSecret: Data(repeating: 7, count: 32),
                space: space,
                repo: repo,
                revision: rev,
                data: digest
            )
        }
        for response in try [
            signedResponse(
                profile: .commit,
                coveredHeader: covered,
                keyShare: keyShare,
                tag: SpaceMACHeader.Profile.record.rawValue
            ),
            signedResponse(
                profile: .commit,
                coveredHeader: covered,
                keyShare: keyShare,
                responseKey: "did:key:zWrong"
            ),
            signedResponse(
                profile: .commit,
                coveredHeader: covered,
                keyShare: keyShare,
                duplicateTaggedSignature: true
            ),
        ] {
            #expect(throws: SpaceVerificationError.malformedHeader) {
                try SpaceMACHeader.verifyCommit(
                    response: response,
                    keyShare: keyShare,
                    sharedSecret: secret,
                    space: space,
                    repo: repo,
                    revision: rev,
                    data: digest
                )
            }
        }
    }

    @Test("Record MAC authenticates the covered URI and CID")
    func recordMAC() throws {
        let keyShare = "did:key:zDnaExample"
        let record = ["text": "hello"]
        let cid = try CID.fromDAGCBOR(DAGCBOR.encodeValue(record))
        let uri = "\(space.uriString())/\(repo)/app.bsky.feed.post/self"
        let covered = "uri=\"\(uri)\", cid=\"\(cid.string)\""
        let response = try signedResponse(
            profile: .record, coveredHeader: covered, keyShare: keyShare
        )
        #expect(
            SpaceMACHeader.request(profile: .record, keyShare: keyShare) ==
                "mac=(\"atproto-space-record\";sf);keyid=\"\(keyShare)\";tag=\"atproto-space-record\""
        )
        try SpaceMACHeader.verifyRecord(
            response: response,
            keyShare: keyShare,
            sharedSecret: secret,
            uri: uri,
            cid: cid
        )
        #expect(throws: SpaceVerificationError.invalidRecord) {
            try SpaceMACHeader.verifyRecord(
                response: response,
                keyShare: keyShare,
                sharedSecret: secret,
                uri: uri + "x",
                cid: cid
            )
        }
    }

    @Test("Record JSON authenticates URI, CID, and encoded record bytes")
    func records() throws {
        let record = ["text": "hello"]
        let cid = try CID.fromDAGCBOR(DAGCBOR.encodeValue(record))
        let uri = "\(space.uriString())/\(repo)/app.bsky.feed.post/self"
        let url = try #require(URL(string: "https://repo.example/xrpc/com.atproto.space.getRecord?collection=app.bsky.feed.post&rkey=self"))
        func body(_ value: Any, recordURI: String = uri, cidString: String = cid.string) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["uri": recordURI, "cid": cidString, "value": value])
        }
        _ = try SpaceResponseVerifier.verifyJSON(
            body(record), method: "getRecord", url: url, space: space, repo: repo
        )
        #expect(throws: (any Error).self) {
            try SpaceResponseVerifier.verifyJSON(
                body(["text": "tampered"]), method: "getRecord", url: url, space: space, repo: repo
            )
        }
        #expect(throws: (any Error).self) {
            try SpaceResponseVerifier.verifyJSON(
                body(record, recordURI: uri + "x"), method: "getRecord", url: url, space: space, repo: repo
            )
        }
    }

    @Test("listRepoOps requires a commit on every page")
    func listRepoOpsCommitRequired() throws {
        let url = try #require(URL(string: "https://repo.example/xrpc/com.atproto.space.listRepoOps"))
        #expect(throws: SpaceVerificationError.invalidCommit) {
            try SpaceResponseVerifier.verifyJSON(
                Data(#"{"ops":[],"cursor":"next"}"#.utf8),
                method: "listRepoOps",
                url: url,
                space: space,
                repo: repo
            )
        }
    }

    @Test("JSON record integer conversion matches the upstream safe-number boundary")
    func safeJSONIntegers() throws {
        let uri = "\(space.uriString())/\(repo)/app.bsky.feed.post/self"
        let url = try #require(URL(string: "https://repo.example/xrpc/com.atproto.space.getRecord?collection=app.bsky.feed.post&rkey=self"))
        for number: Int64 in [9_007_199_254_740_991, -9_007_199_254_740_991, 9_007_199_254_740_992, -9_007_199_254_740_992] {
            let record: [String: Any] = ["count": number]
            let cid = try CID.fromDAGCBOR(DAGCBOR.encodeValue(record))
            let body = try JSONSerialization.data(withJSONObject: ["uri": uri, "cid": cid.string, "value": record])
            if abs(number) <= 9_007_199_254_740_991 {
                _ = try SpaceResponseVerifier.verifyJSON(
                    body, method: "getRecord", url: url, space: space, repo: repo
                )
            } else {
                #expect(throws: SpaceVerificationError.invalidRecord) {
                    try SpaceResponseVerifier.verifyJSON(
                        body, method: "getRecord", url: url, space: space, repo: repo
                    )
                }
            }
        }
    }
}
