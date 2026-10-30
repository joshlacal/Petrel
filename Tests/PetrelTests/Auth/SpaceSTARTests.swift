import Foundation
@testable import Petrel
import PetrelCrypto
import Testing

@Suite("October 22 STAR and MAC responses")
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

    func archive(records: [(String, Data)], digest: Data? = nil) throws -> (Data, Data) {
        var set = SpaceSetHash()
        for (path, bytes) in records {
            set.add(path: path, cid: CID.fromDAGCBOR(bytes).string)
        }
        let data = digest ?? set.digest
        let metadata: [String: Any] = ["$type": "atproto-space-repo", "ver": 1, "repo": repo, "space": space.uriString(), "rev": rev, "data": data]
        var bytes = try Data([0x2A, 0x6C, 1, 0]) + frame(DAGCBOR.encodeValue(metadata))
        for (path, value) in records {
            bytes += frame(Data(path.utf8)) + frame(value)
        }
        let mac = try SpaceMAC.commit(sharedSecret: secret, space: space.uriString(), repo: repo, rev: rev, data: data)
        return (bytes, mac)
    }

    @Test("Independent Python cbor2/BLAKE3 archive includes integer and CID-link records")
    func independentArchive() throws {
        // Reproduce with Scripts/generate-space-vectors.py; no Petrel encoder used.
        let bytes = try #require(Data(base64Encoded: "KmwBAKcBpmNyZXZtM2tiY3EzcDdhZDQyMmN2ZXIBZGRhdGFYIAPti/dnzI3Ij07mC2HCTa1QGHC6pGj8nXzGZVYsfhnaZHJlcG9xZGlkOmV4YW1wbGU6YWxpY2VlJHR5cGVyYXRwcm90by1zcGFjZS1yZXBvZXNwYWNleDBhdDovL2RpZDpleGFtcGxlOnNwYWNlL3NwYWNlL2FwcC5ic2t5Lmdyb3VwL3Rlc3QXYXBwLmJza3kuZmVlZC5wb3N0L3NlbGZAo2NyZWbYKlglAAFxEiBkKPAjBLjbjLEHyJM2SB8P6tcovzdMqAFo0scZOM7652R0ZXh0ZWhlbGxvZWNvdW50AQ=="))
        let mac = try #require(Data(base64Encoded: "8CFY1EOGNI4+DEmP746Vk6nORywX8ik6yK0Nlohaqa0="))
        let result = try SpaceSTAR.verify(archive: bytes, space: space, repo: repo, sharedSecret: secret, mac: mac)
        #expect(result.records.count == 1)
        #expect(result.records[0].cid.string == "bafyreidpnhlqcmg7f3bbn6zd7kr2p3x3ciaqgpy7333hlp3gc4vluyuzvm")
    }

    @Test("Empty and populated archives complete before exposing records")
    func completeArchives() throws {
        for records: [(String, Data)] in try [[], [("app.bsky.feed.post/a", DAGCBOR.encodeValue(["text": "hello"]))]] {
            let (bytes, mac) = try archive(records: records)
            let result = try SpaceSTAR.verify(archive: bytes, space: space, repo: repo, sharedSecret: secret, mac: mac)
            #expect(result.records.count == records.count)
            #expect(result.revision == rev)
        }
    }

    @Test("Duplicate, out-of-order, oversized and truncated frames fail closed")
    func malformedArchives() throws {
        let record = try DAGCBOR.encodeValue(["text": "hello"])
        for paths in [["app.bsky.feed.post/a", "app.bsky.feed.post/a"], ["app.bsky.feed.post/b", "app.bsky.feed.post/a"]] {
            let (bytes, mac) = try archive(records: paths.map { ($0, record) })
            #expect(throws: (any Error).self) { try SpaceSTAR.verify(archive: bytes, space: space, repo: repo, sharedSecret: secret, mac: mac) }
        }
        let (valid, mac) = try archive(records: [("app.bsky.feed.post/a", record)])
        for length in [0, 3, valid.count - 1] {
            #expect(throws: (any Error).self) { try SpaceSTAR.verify(archive: Data(valid.prefix(length)), space: space, repo: repo, sharedSecret: secret, mac: mac) }
        }
        let (large, largeMAC) = try archive(records: [("app.bsky.feed.post/a", Data(repeating: 0, count: 1_048_577))])
        #expect(throws: SpaceVerificationError.boundsExceeded) { try SpaceSTAR.verify(archive: large, space: space, repo: repo, sharedSecret: secret, mac: largeMAC) }
        var nonMinimal = valid
        // Metadata length uses two bytes; append a redundant zero varint byte.
        var end = 4
        while nonMinimal[end] & 128 != 0 {
            end += 1
        }
        nonMinimal[end] |= 128
        nonMinimal.insert(0, at: end + 1)
        #expect(throws: (any Error).self) { try SpaceSTAR.verify(archive: nonMinimal, space: space, repo: repo, sharedSecret: secret, mac: mac) }
    }

    @Test("Digest, MAC, repo and space are independently enforced")
    func authenticatedContext() throws {
        let record = try DAGCBOR.encodeValue(["text": "hello"])
        let (bytes, mac) = try archive(records: [("app.bsky.feed.post/a", record)])
        #expect(throws: SpaceMAC.Failure.mismatch) { try SpaceSTAR.verify(archive: bytes, space: space, repo: repo, sharedSecret: Data(repeating: 7, count: 32), mac: mac) }
        #expect(throws: SpaceVerificationError.invalidCommit) { try SpaceSTAR.verify(archive: bytes, space: space, repo: "did:example:bob", sharedSecret: secret, mac: mac) }
        let wrongSpace = try SpaceRef(uriString: "at://did:example:space/space/app.bsky.group/other")
        #expect(throws: SpaceVerificationError.invalidCommit) { try SpaceSTAR.verify(archive: bytes, space: wrongSpace, repo: repo, sharedSecret: secret, mac: mac) }
        let (wrong, correctMACForWrongDigest) = try archive(records: [("app.bsky.feed.post/a", record)], digest: Data(repeating: 0, count: 32))
        #expect(throws: SpaceVerificationError.digestMismatch) { try SpaceSTAR.verify(archive: wrong, space: space, repo: repo, sharedSecret: secret, mac: correctMACForWrongDigest) }
    }

    @Test("Non-canonical metadata integers are rejected")
    func nonCanonicalMetadata() throws {
        let digest = SpaceSetHash().digest
        let metadata: [String: Any] = ["$type": "atproto-space-repo", "ver": 1, "repo": repo, "space": space.uriString(), "rev": rev, "data": digest]
        var encoded = try DAGCBOR.encodeValue(metadata)
        let location = try #require(encoded.range(of: Data([0x63, 0x76, 0x65, 0x72, 0x01])))
        encoded.replaceSubrange((location.upperBound - 1) ..< location.upperBound, with: [0x18, 0x01])
        let malformed = Data([0x2A, 0x6C, 1, 0]) + frame(encoded)
        #expect(throws: (any Error).self) { try SpaceSTAR.verify(archive: malformed, space: space, repo: repo) }
    }

    @Test("MAC dictionary preserves types and accepts reference base64 spellings")
    func headers() throws {
        let mac = Data(0 ..< 32)
        for encoded in [mac.base64EncodedString(), mac.base64EncodedString().replacingOccurrences(of: "=", with: "")] {
            #expect(try SpaceMACHeader.parse("mac=:\(encoded):, type=\"atproto-space-repo\", ver=1", type: "atproto-space-repo") == mac)
        }
        for header in [nil, "", "type=\"atproto-space-repo\", ver=\"1\", mac=:AA==:", "type=\"atproto-space-record\", ver=1, mac=:AA==:", "type=\"atproto-space-repo\", ver=2, mac=:AA==:", "type=\"atproto-space-repo\", ver=1, ver=1, mac=:AA==:"] {
            #expect(throws: SpaceVerificationError.malformedHeader) { try SpaceMACHeader.parse(header, type: "atproto-space-repo") }
        }
    }

    @Test("Record response authenticates URI, CID, and encoded record bytes")
    func records() throws {
        let record = ["text": "hello"]
        let cid = try CID.fromDAGCBOR(DAGCBOR.encodeValue(record))
        let uri = "\(space.uriString())/\(repo)/app.bsky.feed.post/self"
        let mac = try SpaceMAC.record(sharedSecret: secret, uri: uri, cid: cid.bytes)
        let header = "type=\"atproto-space-record\", ver=1, mac=:\(mac.base64EncodedString()):"
        let url = try #require(URL(string: "https://repo.example/xrpc/com.atproto.space.getRecord?collection=app.bsky.feed.post&rkey=self"))
        func body(_ value: Any, recordURI: String = uri, cidString: String = cid.string) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["uri": recordURI, "cid": cidString, "value": value])
        }
        try SpaceResponseVerifier.verifyJSON(body(record), method: "getRecord", url: url, space: space, repo: repo, secret: secret, macHeader: header)
        #expect(throws: (any Error).self) { try SpaceResponseVerifier.verifyJSON(body(["text": "tampered"]), method: "getRecord", url: url, space: space, repo: repo, secret: secret, macHeader: header) }
        #expect(throws: (any Error).self) { try SpaceResponseVerifier.verifyJSON(body(record, recordURI: uri + "x"), method: "getRecord", url: url, space: space, repo: repo, secret: secret, macHeader: header) }
    }

    @Test("JSON record integer conversion matches the upstream safe-number boundary")
    func safeJSONIntegers() throws {
        let uri = "\(space.uriString())/\(repo)/app.bsky.feed.post/self"
        let url = try #require(URL(string: "https://repo.example/xrpc/com.atproto.space.getRecord?collection=app.bsky.feed.post&rkey=self"))
        for number: Int64 in [9_007_199_254_740_991, -9_007_199_254_740_991, 9_007_199_254_740_992, -9_007_199_254_740_992] {
            let record: [String: Any] = ["count": number]
            let cid = try CID.fromDAGCBOR(DAGCBOR.encodeValue(record))
            let mac = try SpaceMAC.record(sharedSecret: secret, uri: uri, cid: cid.bytes)
            let header = "type=\"atproto-space-record\", ver=1, mac=:\(mac.base64EncodedString()):"
            let body = try JSONSerialization.data(withJSONObject: ["uri": uri, "cid": cid.string, "value": record])
            if abs(number) <= 9_007_199_254_740_991 {
                try SpaceResponseVerifier.verifyJSON(body, method: "getRecord", url: url, space: space, repo: repo, secret: secret, macHeader: header)
            } else {
                #expect(throws: SpaceVerificationError.invalidRecord) { try SpaceResponseVerifier.verifyJSON(body, method: "getRecord", url: url, space: space, repo: repo, secret: secret, macHeader: header) }
            }
        }
    }
}
