import Crypto
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import PetrelCrypto
import Synchronization
import Testing

private struct AtprotoSpacesVectorsV1: Decodable {
    let version: Int
    let lthash: LtHashVectors
    let kem_p256: KemP256Vector
    let commit_mac: CommitMacVector
    let record_mac: RecordMacVector
    let rfc9421_low_s: Rfc9421Vector
    let rfc9421_high_s: Rfc9421Vector
    let delegation_jwt_did_plc: DelegationJwtVector
    let credential_jwt_did_web: CredentialJwtVector
    let star_repo: StarRepoVectors

    struct LtHashRecordFixture: Decodable {
        let collection: String
        let rkey: String
        let path: String
        let dagcbor_hex: String
        let cid: String
        let cid_bytes_hex: String
        let element_key: String
        let element_hash_first32_hex: String
        let element_hash_sha256_hex: String
    }

    struct LtHashVectors: Decodable {
        let record_a: LtHashRecordFixture
        let record_b: LtHashRecordFixture
        let empty_commitment_hex: String
        let only_a_commitment_hex: String
        let only_b_commitment_hex: String
        let combined_ab_commitment_hex: String
        let after_remove_a_commitment_hex: String
    }

    struct KemP256Vector: Decodable {
        let author_secret_hex: String
        let author_kem_did_key: String
        let ephemeral_secret_hex: String
        let key_share_did_key: String
        let shared_secret_hex: String
        let want_commit_mac_header: String
        let want_record_mac_header: String
    }

    struct CommitMacVector: Decodable {
        let shared_secret_hex: String
        let space: String
        let repo: String
        let rev: String
        let data_hex: String
        let mac_hex: String
        let header_value: String
    }

    struct RecordMacVector: Decodable {
        let shared_secret_hex: String
        let record_uri: String
        let cid: String
        let cid_bytes_hex: String
        let mac_hex: String
        let header_value: String
    }

    struct Rfc9421Vector: Decodable {
        let cnf_secret_hex: String
        let cnf_did_key: String
        let credential_jwt: String
        let audience_did: String
        let created: UInt64
        let nonce: String
        let authorization: String
        let atproto_space_audience: String
        let signature_input: String
        let signature: String
        let raw_signature_hex: String
    }

    struct DelegationJwtVector: Decodable {
        let signer_secret_hex: String
        let signer_did_key: String
        let iss: String
        let sub: String
        let aud: String
        let iat: UInt64
        let exp: UInt64
        let jti: String
        let verify_now_sec: UInt64
        let jwt: String
    }

    struct CredentialJwtVector: Decodable {
        let authority_secret_hex: String
        let authority_did_key: String
        let iss: String
        let sub: String
        let cnf_kid: String
        let iat: UInt64
        let exp: UInt64
        let jti: String
        let verify_now_sec: UInt64
        let jwt: String
    }

    struct StarRepoVectors: Decodable {
        let empty_swan_space: String
        let empty_swan_repo: String
        let empty_swan_rev: String
        let empty_swan_archive_hex: String
        let populated_space: String
        let populated_repo: String
        let populated_rev: String
        let populated_data_hex: String
        let populated_archive_hex: String
    }
}

private func loadSpacesVectors() throws -> AtprotoSpacesVectorsV1 {
    let thisFile = URL(fileURLWithPath: #filePath)
    let petrelRoot = thisFile
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let siblingVectors = petrelRoot
        .deletingLastPathComponent()
        .appendingPathComponent("catbird-atproto/atproto-spaces/tests/vectors/atproto_spaces_v1.json")
    let data = try Data(contentsOf: siblingVectors)
    return try JSONDecoder().decode(AtprotoSpacesVectorsV1.self, from: data)
}

private func hexDecode(_ hex: String) throws -> Data {
    let chars = Array(hex.utf8)
    guard chars.count % 2 == 0 else {
        throw PetrelCryptoError.malformed("odd hex length")
    }
    var out = Data(capacity: chars.count / 2)
    func nibble(_ byte: UInt8) throws -> UInt8 {
        switch byte {
        case 48 ... 57: return byte - 48
        case 97 ... 102: return byte - 97 + 10
        case 65 ... 70: return byte - 65 + 10
        default: throw PetrelCryptoError.malformed("invalid hex nibble")
        }
    }
    var idx = 0
    while idx < chars.count {
        let hi = try nibble(chars[idx])
        let lo = try nibble(chars[idx + 1])
        out.append((hi << 4) | lo)
        idx += 2
    }
    return out
}

private func b64urlEncode(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func b64urlDecode(_ value: String) throws -> Data {
    var padded = value
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    while padded.count % 4 != 0 {
        padded.append("=")
    }
    guard let data = Data(base64Encoded: padded) else {
        throw PetrelCryptoError.malformed("invalid base64url")
    }
    return data
}

private func signSpaceCredentialForTest(
    key: P256.Signing.PrivateKey,
    kid: String = "#atproto",
    typ: String = "atproto-space-credential+jwt",
    iss: String,
    sub: String,
    cnfKid: String,
    iat: Int,
    exp: Int,
    jti: String = UUID().uuidString,
    aud: String? = nil
) throws -> String {
    let headerObj: [String: Any] = ["alg": "ES256", "typ": typ, "kid": kid]
    var payloadObj: [String: Any] = [
        "iss": iss,
        "sub": sub,
        "iat": iat,
        "exp": exp,
        "jti": jti,
        "cnf": ["kid": cnfKid],
    ]
    if let aud {
        payloadObj["aud"] = aud
    }
    let headerB64 = try b64urlEncode(JSONSerialization.data(withJSONObject: headerObj, options: [.sortedKeys]))
    let payloadB64 = try b64urlEncode(JSONSerialization.data(withJSONObject: payloadObj, options: [.sortedKeys]))
    let signingInput = "\(headerB64).\(payloadB64)"
    let sig = try P256WireSignature.sign(Data(signingInput.utf8), using: key)
    return "\(signingInput).\(b64urlEncode(sig))"
}

private final class Gate7MockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    static func setHandler(_ newHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?) {
        lock.lock()
        defer { lock.unlock() }
        handler = newHandler
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let current = Self.handler
        Self.lock.unlock()
        guard let current else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            var normalized = request
            if normalized.httpBody == nil, let stream = normalized.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var bytes = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    bytes.append(contentsOf: buffer.prefix(count))
                }
                normalized.httpBody = bytes
            }
            let (resp, body) = try current(normalized)
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite("ATProto Spaces cross-language conformance vectors & Gate 7")
struct SpacesCrossLanguageVectorsTests {
    @Test("Petrel verifies all 9 deterministic atproto_spaces_v1.json vector groups")
    func crossLanguageVectorsMatchPetrel() throws {
        let vectors = try loadSpacesVectors()
        #expect(vectors.version == 1)

        // 1. LtHash (SpaceSetHash)
        let bytesA = try hexDecode(vectors.lthash.record_a.dagcbor_hex)
        let bytesB = try hexDecode(vectors.lthash.record_b.dagcbor_hex)
        let cidA = CID.fromDAGCBOR(bytesA)
        let cidB = CID.fromDAGCBOR(bytesB)
        #expect(cidA.string == vectors.lthash.record_a.cid)
        #expect(cidB.string == vectors.lthash.record_b.cid)
        #expect(Hex.encode(cidA.bytes) == vectors.lthash.record_a.cid_bytes_hex)
        #expect(Hex.encode(cidB.bytes) == vectors.lthash.record_b.cid_bytes_hex)

        let emptySet = SpaceSetHash()
        #expect(Hex.encode(emptySet.digest) == vectors.lthash.empty_commitment_hex)

        var forwardSet = SpaceSetHash()
        forwardSet.add(path: vectors.lthash.record_a.path, cid: cidA.string)
        #expect(Hex.encode(forwardSet.digest) == vectors.lthash.only_a_commitment_hex)
        forwardSet.add(path: vectors.lthash.record_b.path, cid: cidB.string)
        #expect(Hex.encode(forwardSet.digest) == vectors.lthash.combined_ab_commitment_hex)

        var reverseSet = SpaceSetHash()
        reverseSet.add(path: vectors.lthash.record_b.path, cid: cidB.string)
        reverseSet.add(path: vectors.lthash.record_a.path, cid: cidA.string)
        #expect(Hex.encode(reverseSet.digest) == vectors.lthash.combined_ab_commitment_hex)

        forwardSet.remove(path: vectors.lthash.record_a.path, cid: cidA.string)
        #expect(Hex.encode(forwardSet.digest) == vectors.lthash.after_remove_a_commitment_hex)
        #expect(Hex.encode(forwardSet.digest) == vectors.lthash.only_b_commitment_hex)

        // 2. KEM P-256
        let authorKemPriv = try P256.KeyAgreement.PrivateKey(
            rawRepresentation: hexDecode(vectors.kem_p256.author_secret_hex)
        )
        let ephKemPriv = try P256.KeyAgreement.PrivateKey(
            rawRepresentation: hexDecode(vectors.kem_p256.ephemeral_secret_hex)
        )
        let encap = try SpaceMAC.encapsulate(
            authorKey: vectors.kem_p256.author_kem_did_key,
            ephemeralKey: ephKemPriv
        )
        #expect(encap.keyShare == vectors.kem_p256.key_share_did_key)
        #expect(Hex.encode(encap.sharedSecret) == vectors.kem_p256.shared_secret_hex)
        let decapped = try SpaceMAC.decapsulate(
            privateKey: authorKemPriv,
            keyShare: vectors.kem_p256.key_share_did_key
        )
        #expect(Hex.encode(decapped) == vectors.kem_p256.shared_secret_hex)

        // 3. Commit MAC & 4. Record MAC
        let commitData = try hexDecode(vectors.commit_mac.data_hex)
        let computedCommitMac = try SpaceMAC.commit(
            sharedSecret: decapped,
            space: vectors.commit_mac.space,
            repo: vectors.commit_mac.repo,
            rev: vectors.commit_mac.rev,
            data: commitData
        )
        #expect(Hex.encode(computedCommitMac) == vectors.commit_mac.mac_hex)
        #expect(
            "type=\"atproto-space-repo\", ver=1, mac=:\(computedCommitMac.base64EncodedString()):"
                == vectors.commit_mac.header_value
        )

        let computedRecordMac = try SpaceMAC.record(
            sharedSecret: decapped,
            uri: vectors.record_mac.record_uri,
            cid: hexDecode(vectors.record_mac.cid_bytes_hex)
        )
        #expect(Hex.encode(computedRecordMac) == vectors.record_mac.mac_hex)
        #expect(
            "type=\"atproto-space-record\", ver=1, mac=:\(computedRecordMac.base64EncodedString()):"
                == vectors.record_mac.header_value
        )

        // 5. RFC 9421 Low-S and WebCrypto High-S
        for vec9421 in [vectors.rfc9421_low_s, vectors.rfc9421_high_s] {
            let paramsPrefix = "atproto-space-credential="
            #expect(vec9421.signature_input.hasPrefix(paramsPrefix))
            let signatureParams = String(vec9421.signature_input.dropFirst(paramsPrefix.count))
            let base = SpaceHTTPSignature.signatureBase(
                authorization: vec9421.authorization,
                audience: vec9421.atproto_space_audience,
                signatureParams: signatureParams
            )
            let rawSig = try hexDecode(vec9421.raw_signature_hex)
            let pubKey = try P256DIDKey(vec9421.cnf_did_key).publicKey
            let ecdsa = try P256WireSignature.decodeMalleabilityTolerant(rawSig)
            #expect(pubKey.isValidSignature(ecdsa, for: base))
        }
        #expect(try P256WireSignature.isCanonicalLowS(hexDecode(vectors.rfc9421_low_s.raw_signature_hex)) == true)
        #expect(try P256WireSignature.isCanonicalLowS(hexDecode(vectors.rfc9421_high_s.raw_signature_hex)) == false)

        // 6. Delegation JWT (did:plc) & 7. Credential JWT (did:web)
        for (jwt, didKey) in [
            (vectors.delegation_jwt_did_plc.jwt, vectors.delegation_jwt_did_plc.signer_did_key),
            (vectors.credential_jwt_did_web.jwt, vectors.credential_jwt_did_web.authority_did_key),
        ] {
            let parts = jwt.split(separator: ".", omittingEmptySubsequences: false)
            #expect(parts.count == 3)
            let signingInput = Data("\(parts[0]).\(parts[1])".utf8)
            let sig = try b64urlDecode(String(parts[2]))
            let vk = try ATProtoJWTVerificationKey(PLCDIDKeyCodec.decode(didKey))
            #expect(try vk.verify(signature: sig, signingInput: signingInput, algorithm: "ES256"))
        }

        // 8. STAR-lite (empty Swan fixture + populated 2-record fixture)
        let emptySpace = try SpaceRef(uriString: vectors.star_repo.empty_swan_space)
        let verifiedEmpty = try SpaceSTAR.verify(
            archive: hexDecode(vectors.star_repo.empty_swan_archive_hex),
            space: emptySpace,
            repo: vectors.star_repo.empty_swan_repo
        )
        #expect(verifiedEmpty.records.isEmpty)
        #expect(verifiedEmpty.revision == vectors.star_repo.empty_swan_rev)

        let popSpace = try SpaceRef(uriString: vectors.star_repo.populated_space)
        let verifiedPop = try SpaceSTAR.verify(
            archive: hexDecode(vectors.star_repo.populated_archive_hex),
            space: popSpace,
            repo: vectors.star_repo.populated_repo,
            sharedSecret: decapped,
            mac: computedCommitMac
        )
        #expect(verifiedPop.records.count == 2)
        #expect(verifiedPop.revision == vectors.star_repo.populated_rev)
        #expect(Hex.encode(verifiedPop.data) == vectors.star_repo.populated_data_hex)
    }

    @Test("Gate 7: SpaceCredentialManager verifies signatures & claims and rejects expired, wrong-space, and bad-signature credentials for did:plc and did:web")
    func gate7SpaceCredentialVerification() async throws {
        try await withSerializedStorageOverrideTest {
            NetworkService.setNetworkTestProtocolClasses([Gate7MockURLProtocol.self])
            NetworkService.dnsResolverOverride = { _ in ["93.184.216.34"] }
            defer {
                Gate7MockURLProtocol.setHandler(nil)
                NetworkService.setNetworkTestProtocolClasses(nil)
                NetworkService.dnsResolverOverride = nil
            }

            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [Gate7MockURLProtocol.self]
            let delegate = HardenedURLSessionDelegate(allowsRedirects: false, limits: .default)
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            defer { session.invalidateAndCancel() }

            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))
            let oldKey = P256.Signing.PrivateKey()
            let activeKey = P256.Signing.PrivateKey()
            let wrongKey = P256.Signing.PrivateKey()

            for authorityDID in ["did:plc:ewvi7nxzyoun6zhxrhs64oiz", "did:web:ds.catbird.blue"] {
                let space = try SpaceRef(uriString: "at://\(authorityDID)/space/blue.catbird.mlsChat/3l2aaaaaaaaaa")
                let wrongSpace = "at://\(authorityDID)/space/blue.catbird.mlsChat/other-space"

                @Sendable func makeDidDocJSON(signingKey: P256.Signing.PrivateKey) -> Data {
                    let multibase = String(P256DIDKey(publicKey: signingKey.publicKey).value.dropFirst("did:key:".count))
                    let json = """
                    {
                      "id": "\(authorityDID)",
                      "verificationMethod": [
                        {
                          "id": "\(authorityDID)#atproto",
                          "type": "Multikey",
                          "controller": "\(authorityDID)",
                          "publicKeyMultibase": "\(multibase)"
                        }
                      ],
                      "service": [
                        {
                          "id": "#atproto_pds",
                          "type": "AtprotoPersonalDataServer",
                          "serviceEndpoint": "https://space.test"
                        }
                      ]
                    }
                    """
                    return Data(json.utf8)
                }

                // Negative cases: expired, wrong-space, bad-signature, wrong-cnf-kid
                enum NegativeCase { case expired, wrongSpace, badSignature, wrongCnfKid }
                for neg in [NegativeCase.expired, .wrongSpace, .badSignature, .wrongCnfKid] {
                    Gate7MockURLProtocol.setHandler { request in
                        let url = request.url!
                        if url.host == "plc.directory" || url.path.hasSuffix("/did.json") {
                            let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                            return (resp, makeDidDocJSON(signingKey: activeKey))
                        }
                        let rawBody = try #require(request.httpBody)
                        let bodyObj = try #require(JSONSerialization.jsonObject(with: rawBody) as? [String: Any])
                        let requestedKid = try #require(bodyObj["credentialKid"] as? String)
                        let now = Int(Date().timeIntervalSince1970)
                        let jwt: String
                        switch neg {
                        case .expired:
                            jwt = try signSpaceCredentialForTest(
                                key: activeKey,
                                iss: authorityDID,
                                sub: space.uriString(),
                                cnfKid: requestedKid,
                                iat: now - 700,
                                exp: now - 100
                            )
                        case .wrongSpace:
                            jwt = try signSpaceCredentialForTest(
                                key: activeKey,
                                iss: authorityDID,
                                sub: wrongSpace,
                                cnfKid: requestedKid,
                                iat: now,
                                exp: now + 600
                            )
                        case .badSignature:
                            jwt = try signSpaceCredentialForTest(
                                key: wrongKey,
                                iss: authorityDID,
                                sub: space.uriString(),
                                cnfKid: requestedKid,
                                iat: now,
                                exp: now + 600
                            )
                        case .wrongCnfKid:
                            let otherCnf = P256DIDKey(publicKey: P256.Signing.PrivateKey().publicKey).value
                            jwt = try signSpaceCredentialForTest(
                                key: activeKey,
                                iss: authorityDID,
                                sub: space.uriString(),
                                cnfKid: otherCnf,
                                iat: now,
                                exp: now + 600
                            )
                        }
                        let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                        return try (resp, JSONEncoder().encode(["credential": jwt]))
                    }

                    let manager = SpaceCredentialManager(
                        client: client,
                        authorityHostProvider: { _ in URL(string: "https://space.test")! },
                        urlSession: session,
                        delegationTokenProvider: { _ in "mock-delegation" }
                    )
                    do {
                        _ = try await manager.credential(for: space)
                        Issue.record("Expected Gate 7 rejection for \(neg) on \(authorityDID)")
                    } catch let error as SpaceCredentialError {
                        if case .invalidToken = error {
                            // Expected
                        } else {
                            Issue.record("Unexpected SpaceCredentialError \(error) for \(neg) on \(authorityDID)")
                        }
                    }
                }

                // Positive case + rotated key single forceRefresh retry
                let didFetchCount = Mutex<Int>(0)
                Gate7MockURLProtocol.setHandler { request in
                    let url = request.url!
                    if url.host == "plc.directory" || url.path.hasSuffix("/did.json") {
                        let attempt = didFetchCount.withLock { c -> Int in
                            c += 1
                            return c
                        }
                        let keyToServe = attempt == 1 ? oldKey : activeKey
                        let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                        return (resp, makeDidDocJSON(signingKey: keyToServe))
                    }
                    let rawBody = try #require(request.httpBody)
                    let bodyObj = try #require(JSONSerialization.jsonObject(with: rawBody) as? [String: Any])
                    let requestedKid = try #require(bodyObj["credentialKid"] as? String)
                    let now = Int(Date().timeIntervalSince1970)
                    let jwt = try signSpaceCredentialForTest(
                        key: activeKey,
                        iss: authorityDID,
                        sub: space.uriString(),
                        cnfKid: requestedKid,
                        iat: now,
                        exp: now + 600
                    )
                    let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return try (resp, JSONEncoder().encode(["credential": jwt]))
                }

                let rotatingManager = SpaceCredentialManager(
                    client: client,
                    authorityHostProvider: { _ in URL(string: "https://space.test")! },
                    urlSession: session,
                    delegationTokenProvider: { _ in "mock-delegation" }
                )
                let verifiedCred = try await rotatingManager.credential(for: space)
                #expect(!verifiedCred.token.isEmpty)
                #expect(didFetchCount.withLock { $0 } == 2)
            }
        }
    }
}
