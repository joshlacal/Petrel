//
//  SpaceCredentialManagerTests.swift
//  PetrelTests
//

#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import Crypto
@testable import Petrel
import PetrelCrypto
import Synchronization
import Testing

// MARK: - Helper Functions

private func makeB64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func makeMockCredentialJWT(exp: Int, sub: String = "did:plc:user123", iss: String = "did:plc:auth123") -> String {
    let header = ##"{"alg":"ES256","typ":"JWT","kid":"#atproto"}"##
    let payload = #"{"exp":\#(exp),"sub":"\#(sub)","iss":"\#(iss)"}"#
    let headerB64 = makeB64URL(Data(header.utf8))
    let payloadB64 = makeB64URL(Data(payload.utf8))
    let dummySig = makeB64URL(Data(repeating: 0x42, count: 64))
    return "\(headerB64).\(payloadB64).\(dummySig)"
}

private final class SpaceMockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    static func setHandler(_ newHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?) {
        lock.lock()
        defer { lock.unlock() }
        handler = newHandler
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        SpaceMockURLProtocol.lock.lock()
        let currentHandler = SpaceMockURLProtocol.handler
        SpaceMockURLProtocol.lock.unlock()

        guard let currentHandler else {
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
            let (response, data) = try currentHandler(normalized)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [SpaceMockURLProtocol.self]
    let delegate = HardenedURLSessionDelegate(allowsRedirects: false, limits: .default)
    return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
}

private func withSpaceTestSession<T>(_ body: () async throws -> T) async throws -> T {
    try await withSerializedStorageOverrideTest {
        NetworkService.setNetworkTestProtocolClasses([SpaceMockURLProtocol.self])
        NetworkService.dnsResolverOverride = { host in
            if host == "localhost" || host == "127.0.0.1" || host == "::1" {
                return ["127.0.0.1"]
            }
            return ["93.184.216.34"]
        }
        defer {
            SpaceMockURLProtocol.setHandler(nil)
            NetworkService.setNetworkTestProtocolClasses(nil)
            NetworkService.dnsResolverOverride = nil
        }
        return try await body()
    }
}

// MARK: - SpaceHTTPSignature Tests

private func spaceSignatureBytes(_ header: String?) -> Data? {
    guard let header, header.hasPrefix("atproto-space-credential=:"), header.hasSuffix(":") else { return nil }
    return Data(base64Encoded: String(header.dropFirst("atproto-space-credential=:".count).dropLast()))
}

private func verifySpaceSignature(_ signature: Data, base: Data, keyID: String) throws -> Bool {
    let publicKey = try P256DIDKey(keyID).publicKey
    let ecdsa = try P256.Signing.ECDSASignature(rawRepresentation: signature)
    return publicKey.isValidSignature(ecdsa, for: base)
}

@Suite("Space HTTP message signatures")
struct SpaceHTTPSignatureTests {
    // Same constants as the reference http-signature.test.ts.
    private let authorization = "Atproto-Space-Credential credential"
    private let audience = "did:example:repo"

    @Test("credential signature base preserves exact bytes and required tag")
    func exactBase() throws {
        let params = SpaceHTTPSignature.signatureParams()
        #expect(params == #"("authorization" "atproto-space-audience");tag="atproto-space-credential""#)
        let base = SpaceHTTPSignature.signatureBase(authorization: authorization, audience: audience, signatureParams: params)
        let expected = "\"authorization\": \(authorization)\n\"atproto-space-audience\": \(audience)\n\"@signature-params\": \(params)"
        #expect(base == Data(expected.utf8))
        let key = P256.Signing.PrivateKey()
        let headers = try SpaceHTTPSignature.headers(key: key, authorization: authorization, audience: audience)
        #expect(headers["Signature-Input"] == "atproto-space-credential=" + params)
        let signature = try #require(spaceSignatureBytes(headers["Signature"]))
        #expect(signature.count == 64)
        #expect(try verifySpaceSignature(signature, base: base, keyID: P256DIDKey(publicKey: key.publicKey).value))
        let changed = SpaceHTTPSignature.signatureBase(authorization: authorization.lowercased(), audience: audience, signatureParams: params)
        #expect(try !verifySpaceSignature(signature, base: changed, keyID: P256DIDKey(publicKey: key.publicKey).value))
        #expect(throws: SpaceCredentialError.self) { try SpaceHTTPSignature.headers(key: key, authorization: "Atproto-Space old", audience: audience) }
        #expect(throws: SpaceCredentialError.self) { try SpaceHTTPSignature.headers(key: key, authorization: "Bearer exchange", audience: nil) }
    }

    @Test("audience defaults to the repo DID, else the bare space authority DID")
    func audienceDerivation() throws {
        let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")
        let repoURL = try #require(URL(string: "https://repo.test/xrpc/com.atproto.space.getRecord?space=at://did:plc:auth123/space/com.example.drive/self&repo=did:plc:writer&collection=a.b.c&rkey=self"))
        #expect(SpaceHTTPSignature.audience(for: repoURL, space: space) == "did:plc:writer")
        let hostURL = try #require(URL(string: "https://space.test/xrpc/com.atproto.space.listRepos?space=at://did:plc:auth123/space/com.example.drive/self"))
        #expect(SpaceHTTPSignature.audience(for: hostURL, space: space) == "did:plc:auth123")
    }

    @Test("payload(ofJWT:) throws on malformed JWT segments")
    func malformedJWTPayload() throws {
        for jwt in ["onlyonepart", "header.payload", "header.payload.sig.extra", "header..sig", ".payload.sig", "header.payload."] {
            #expect(throws: SpaceCredentialError.self) {
                _ = try SpaceCredentialJWT.payload(ofJWT: jwt)
            }
        }
    }
}

// MARK: - SpaceCredentialManager Tests

@Suite("SpaceCredentialManager exchange", .serialized)
struct SpaceCredentialManagerTests {
    private let didDocJSON = """
    {
      "@context": ["https://www.w3.org/ns/did/v1"],
      "id": "did:plc:auth123",
      "alsoKnownAs": ["at://auth.test"],
      "verificationMethod": [
        {
          "id": "did:plc:auth123#atproto",
          "type": "Multikey",
          "controller": "did:plc:auth123",
          "publicKeyMultibase": "zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPqiYBme"
        }
      ],
      "service": [
        {
          "id": "#atproto_pds",
          "type": "AtprotoSpaceHost",
          "serviceEndpoint": "https://space.test"
        }
      ]
    }
    """

    private final class DummyDIDResolver: DIDResolving, @unchecked Sendable {
        func resolveHandleToDID(handle: String) async throws -> String {
            "did:plc:123"
        }

        func resolveDIDToPDSURL(did: String) async throws -> URL {
            URL(string: "https://pds.test")!
        }

        func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL) {
            ("user.test", URL(string: "https://pds.test")!)
        }
    }

    @Test("exchange POSTs body-bound credential key and delegation without Authorization or signature")
    func exchangeAndCache() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let didResolver = DummyDIDResolver()
            let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))

            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")
            let expTime = Int(Date().addingTimeInterval(3600).timeIntervalSince1970)
            let credentialJWT = makeMockCredentialJWT(exp: expTime)

            let capturedRequests = Mutex<[URLRequest]>([])

            SpaceMockURLProtocol.setHandler { request in
                capturedRequests.withLock { $0.append(request) }
                let urlString = request.url?.absoluteString ?? ""

                if urlString.contains("plc.directory") || urlString.contains(".well-known/did.json") {
                    let resp = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (resp, Data(self.didDocJSON.utf8))
                }

                if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    let resp = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = try JSONEncoder().encode(["credential": credentialJWT])
                    return (resp, body)
                }

                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                resolver: spaceResolver,
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token-123" }
            )

            // 1. Initial exchange
            let cred1 = try await manager.credential(for: space)
            #expect(cred1.token == credentialJWT)
            #expect(abs(cred1.expiresAt.timeIntervalSince1970 - Double(expTime)) < 2.0)
            #expect(!cred1.keyRawRepresentation.isEmpty)

            // 2. Second call should hit cache (no additional getSpaceCredential request)
            let cred2 = try await manager.credential(for: space)
            #expect(cred2.token == cred1.token)
            #expect(cred2.expiresAt == cred1.expiresAt)
            #expect(cred2.keyRawRepresentation == cred1.keyRawRepresentation)

            let requests = capturedRequests.withLock { $0 }
            let exchangeRequests = requests.filter {
                $0.url?.absoluteString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential"
            }
            #expect(exchangeRequests.count == 1)

            let req = exchangeRequests[0]
            #expect(req.httpMethod == "POST")
            #expect(req.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")

            #expect(req.value(forHTTPHeaderField: "DPoP") == nil)
            #expect(req.value(forHTTPHeaderField: "Atproto-Space-Audience") == nil)

            let credentialKey = try P256.Signing.PrivateKey(rawRepresentation: cred1.keyRawRepresentation)
            let keyID = P256DIDKey(publicKey: credentialKey.publicKey).value
            #expect(req.value(forHTTPHeaderField: "Signature-Input") == nil)
            #expect(req.value(forHTTPHeaderField: "Signature") == nil)
            let body = try #require(req.httpBody)
            let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
            #expect(object["credentialKid"] == keyID)
            #expect(object["delegationToken"] == "mock-delegation-token-123")
            #expect(object["space"] == space.uriString())
        }
    }

    @Test("get() sends Atproto-Space-Credential credential, repo-DID audience, and a signature over both")
    func signedRead() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let didResolver = DummyDIDResolver()
            let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))

            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")
            let expTime = Int(Date().addingTimeInterval(3600).timeIntervalSince1970)
            let credentialJWT = makeMockCredentialJWT(exp: expTime)

            let capturedRequests = Mutex<[URLRequest]>([])

            SpaceMockURLProtocol.setHandler { request in
                capturedRequests.withLock { $0.append(request) }
                let urlString = request.url?.absoluteString ?? ""

                if urlString.contains("plc.directory") || urlString.contains(".well-known/did.json") {
                    let resp = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (resp, Data(self.didDocJSON.utf8))
                }

                if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    let resp = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = try JSONEncoder().encode(["credential": credentialJWT])
                    return (resp, body)
                }

                if urlString.contains("repo.test") {
                    let resp = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (resp, Data(#"{"record":{"value":"ok"}}"#.utf8))
                }

                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                resolver: spaceResolver,
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token" }
            )

            let targetURL = try #require(URL(string: "https://repo.test/xrpc/com.atproto.space.getBlob?repo=did:plc:writer&rkey=self"))
            let (data, response) = try await manager.get(url: targetURL, space: space)
            #expect(response.statusCode == 200)
            #expect(String(data: data, encoding: .utf8) == #"{"record":{"value":"ok"}}"#)

            let requests = capturedRequests.withLock { $0 }
            let getRequests = requests.filter { $0.url?.host == "repo.test" }
            #expect(getRequests.count == 1)

            let getReq = getRequests[0]
            #expect(getReq.httpMethod == "GET")
            #expect(getReq.value(forHTTPHeaderField: "Authorization") == "Atproto-Space-Credential \(credentialJWT)")
            #expect(getReq.value(forHTTPHeaderField: "Atproto-Space-Audience") == "did:plc:writer")
            #expect(getReq.value(forHTTPHeaderField: "DPoP") == nil)
            let params = SpaceHTTPSignature.signatureParams()
            #expect(getReq.value(forHTTPHeaderField: "Signature-Input") == "atproto-space-credential=" + params)

            let cred = try await manager.credential(for: space)
            let keyID = try P256DIDKey(publicKey: P256.Signing.PrivateKey(rawRepresentation: cred.keyRawRepresentation).publicKey).value
            let signature = try #require(spaceSignatureBytes(getReq.value(forHTTPHeaderField: "Signature")))
            #expect(signature.count == 64)
            let base = SpaceHTTPSignature.signatureBase(
                authorization: "Atproto-Space-Credential \(credentialJWT)",
                audience: "did:plc:writer",
                signatureParams: params
            )
            #expect(try verifySpaceSignature(signature, base: base, keyID: keyID))

            // Space-host operations (no repo) are addressed to the bare authority DID;
            // an explicit audience overrides derivation.
            _ = try await manager.get(url: #require(URL(string: "https://repo.test/xrpc/com.atproto.space.listRepos?space=x")), space: space)
            _ = try await manager.get(url: #require(URL(string: "https://repo.test/xrpc/x")), space: space, audience: "did:plc:explicit")
            let audiences = capturedRequests.withLock { $0 }
                .filter { $0.url?.host == "repo.test" }
                .map { $0.value(forHTTPHeaderField: "Atproto-Space-Audience") }
            #expect(audiences == ["did:plc:writer", "did:plc:auth123", "did:plc:explicit"])
        }
    }

    @Test("get() refuses a non-DID or fragment-bearing audience before sending")
    func rejectsInvalidAudience() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))
            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")
            let sent = Mutex<Int>(0)
            SpaceMockURLProtocol.setHandler { request in
                sent.withLock { $0 += 1 }
                return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                authorityHostProvider: { _ in URL(string: "https://space.test")! },
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token" }
            )
            for audience in ["did:plc:auth123#atproto_pds", "space.test", "https://space.test"] {
                await #expect(throws: SpaceCredentialError.self) {
                    _ = try await manager.get(url: #require(URL(string: "https://repo.test/xrpc/x")), space: space, audience: audience)
                }
            }
            #expect(sent.withLock { $0 } == 0)
        }
    }

    @Test("401 CredentialRevoked drops the cached credential; the next request uses a fresh exchange and key")
    func credentialRevokedDropsCache() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))
            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")
            let exchangeCount = Mutex<Int>(0)
            let revokeNext = Mutex<Bool>(true)

            SpaceMockURLProtocol.setHandler { request in
                let urlString = request.url?.absoluteString ?? ""
                if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    let n = exchangeCount.withLock { count -> Int in
                        count += 1
                        return count
                    }
                    let jwt = makeMockCredentialJWT(exp: Int(Date().addingTimeInterval(600).timeIntervalSince1970), sub: "cred-\(n)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return try (resp, JSONEncoder().encode(["credential": jwt]))
                }
                if request.url?.host == "repo.test" {
                    if revokeNext.withLock({ value -> Bool in
                        defer { value = false }
                        return value
                    }) {
                        let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                        return (resp, Data(#"{"error":"CredentialRevoked","message":"space credential has been revoked"}"#.utf8))
                    }
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, Data("{}".utf8))
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                authorityHostProvider: { _ in URL(string: "https://space.test")! },
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token" }
            )
            let url = try #require(URL(string: "https://repo.test/xrpc/com.atproto.space.getBlob?repo=did:plc:writer"))

            let first = try await manager.credential(for: space)
            let (_, revoked) = try await manager.get(url: url, space: space)
            #expect(revoked.statusCode == 401)
            #expect(exchangeCount.withLock { $0 } == 1)

            let (_, ok) = try await manager.get(url: url, space: space)
            #expect(ok.statusCode == 200)
            #expect(exchangeCount.withLock { $0 } == 2)
            let second = try await manager.credential(for: space)
            #expect(second.token != first.token)
            #expect(second.keyRawRepresentation != first.keyRawRepresentation)
        }
    }

    @Test("a non-revocation 401 keeps the cached credential")
    func otherUnauthorizedKeepsCache() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))
            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")
            let exchangeCount = Mutex<Int>(0)

            SpaceMockURLProtocol.setHandler { request in
                if request.url?.absoluteString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    exchangeCount.withLock { $0 += 1 }
                    let jwt = makeMockCredentialJWT(exp: Int(Date().addingTimeInterval(600).timeIntervalSince1970))
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return try (resp, JSONEncoder().encode(["credential": jwt]))
                }
                let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, Data(#"{"error":"BadSpaceAudience","message":"space audience does not match the request"}"#.utf8))
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                authorityHostProvider: { _ in URL(string: "https://space.test")! },
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token" }
            )
            let url = try #require(URL(string: "https://repo.test/xrpc/com.atproto.space.getBlob?repo=did:plc:writer"))
            _ = try await manager.get(url: url, space: space)
            _ = try await manager.get(url: url, space: space)
            #expect(exchangeCount.withLock { $0 } == 1)
        }
    }

    @Test("get() rejects non-HTTPS non-loopback URLs")
    func rejectsInsecureURLs() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let didResolver = DummyDIDResolver()
            let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))

            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")

            let manager = SpaceCredentialManager(
                client: client,
                resolver: spaceResolver,
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token" }
            )

            let insecureURL = try #require(URL(string: "http://insecure.repo.test/xrpc/com.atproto.space.getRecord"))
            await #expect(throws: SpaceCredentialError.self) {
                _ = try await manager.get(url: insecureURL, space: space)
            }
        }
    }

    @Test("invalidate drops cache; next call re-exchanges")
    func invalidation() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let didResolver = DummyDIDResolver()
            let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))

            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")
            let expTime = Int(Date().addingTimeInterval(3600).timeIntervalSince1970)
            let credentialJWT = makeMockCredentialJWT(exp: expTime)

            let exchangeCount = Mutex<Int>(0)

            SpaceMockURLProtocol.setHandler { request in
                let urlString = request.url?.absoluteString ?? ""

                if urlString.contains("plc.directory") || urlString.contains(".well-known/did.json") {
                    let resp = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (resp, Data(self.didDocJSON.utf8))
                }

                if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    exchangeCount.withLock { $0 += 1 }
                    let resp = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = try! JSONEncoder().encode(["credential": credentialJWT])
                    return (resp, body)
                }

                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                resolver: spaceResolver,
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token" }
            )

            _ = try await manager.credential(for: space)
            #expect(exchangeCount.withLock { $0 } == 1)

            _ = try await manager.credential(for: space)
            #expect(exchangeCount.withLock { $0 } == 1)

            await manager.invalidate(space)

            _ = try await manager.credential(for: space)
            #expect(exchangeCount.withLock { $0 } == 2)
        }
    }

    @Test("invalidation while exchange is in flight discards the stale exchange result")
    func invalidationDuringInFlightExchange() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let didResolver = DummyDIDResolver()
            let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))

            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")
            let expTime = Int(Date().addingTimeInterval(3600).timeIntervalSince1970)
            let credentialJWT = makeMockCredentialJWT(exp: expTime)

            let exchangeCount = Mutex<Int>(0)
            let delegationAttempts = Mutex<Int>(0)
            let (startedStream, startedContinuation) = AsyncStream.makeStream(of: Void.self)
            let (releaseStream, releaseContinuation) = AsyncStream.makeStream(of: Void.self)

            SpaceMockURLProtocol.setHandler { request in
                let urlString = request.url?.absoluteString ?? ""

                if urlString.contains("plc.directory") || urlString.contains(".well-known/did.json") {
                    let resp = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (resp, Data(self.didDocJSON.utf8))
                }

                if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    exchangeCount.withLock { $0 += 1 }
                    let resp = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = try! JSONEncoder().encode(["credential": credentialJWT])
                    return (resp, body)
                }

                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                resolver: spaceResolver,
                urlSession: session,
                delegationTokenProvider: { _ in
                    let attempt = delegationAttempts.withLock { count -> Int in
                        count += 1
                        return count
                    }
                    if attempt == 1 {
                        startedContinuation.yield()
                        for await _ in releaseStream {
                            break
                        }
                    }
                    return "mock-delegation-token"
                }
            )

            // 1. Start first exchange in background
            async let backgroundCred: SpaceCredential = manager.credential(for: space)

            // 2. Deterministically wait until first exchange is running inside delegationTokenProvider
            for await _ in startedStream {
                break
            }

            // 3. Invalidate while first exchange is in flight and blocked
            await manager.invalidate(space)

            // 4. Start second exchange (post-invalidation caller)
            async let freshCred: SpaceCredential = manager.credential(for: space)

            // 5. Release blocked first exchange
            releaseContinuation.yield()
            releaseContinuation.finish()

            // 6. Assert the stale pre-invalidation caller throws CancellationError
            do {
                _ = try await backgroundCred
                Issue.record("Expected stale in-flight exchange to throw on invalidation")
            } catch is CancellationError {
                // Expected cancellation
            } catch {
                // Any cancellation-related error is accepted
            }

            // 7. Assert post-invalidation caller completes successfully with fresh credential from distinct attempt
            let cred = try await freshCred
            #expect(cred.token == credentialJWT)
            #expect(delegationAttempts.withLock { $0 } == 2)
        }
    }

    @Test("renews credential when within 60s of expiry")
    func renewalNearExpiry() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let didResolver = DummyDIDResolver()
            let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))

            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")
            let exchangeCount = Mutex<Int>(0)

            SpaceMockURLProtocol.setHandler { request in
                let urlString = request.url?.absoluteString ?? ""

                if urlString.contains("plc.directory") || urlString.contains(".well-known/did.json") {
                    let resp = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (resp, Data(self.didDocJSON.utf8))
                }

                if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    let current = exchangeCount.withLock { count -> Int in
                        count += 1
                        return count
                    }

                    // First response expires in 30 seconds (within 60s window)
                    // Second response expires in 3600 seconds
                    let exp = (current == 1)
                        ? Int(Date().addingTimeInterval(30).timeIntervalSince1970)
                        : Int(Date().addingTimeInterval(3600).timeIntervalSince1970)

                    let jwt = makeMockCredentialJWT(exp: exp)
                    let resp = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = try! JSONEncoder().encode(["credential": jwt])
                    return (resp, body)
                }

                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                resolver: spaceResolver,
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token" }
            )

            let cred1 = try await manager.credential(for: space)
            #expect(exchangeCount.withLock { $0 } == 1)

            // Since cred1 expires in 30s (< 60s buffer), next call should trigger re-exchange
            let cred2 = try await manager.credential(for: space)
            #expect(exchangeCount.withLock { $0 } == 2)
            #expect(cred2.expiresAt > cred1.expiresAt)
        }
    }

    @Test("exchange classifies 400 InvalidDelegationToken as tokenRejected with plain message when probe returns nothing")
    func exchangeClassifiesTokenRejectedProbeFailed() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let didResolver = DummyDIDResolver()
            let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))
            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")

            SpaceMockURLProtocol.setHandler { request in
                let urlString = request.url?.absoluteString ?? ""
                if urlString.contains("plc.directory") || urlString.contains(".well-known/did.json") {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, Data(self.didDocJSON.utf8))
                }
                if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = #"{"error":"InvalidDelegationToken","message":"Delegation token signature invalid"}"#.data(using: .utf8)!
                    return (resp, body)
                }
                if urlString == "https://space.test/xrpc/com.atproto.server.describeServer" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                    return (resp, Data())
                }
                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                resolver: spaceResolver,
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token" }
            )

            do {
                _ = try await manager.credential(for: space)
                Issue.record("Expected credential to throw tokenRejected")
            } catch let err as SpaceCredentialError {
                guard case let .tokenRejected(host, error, msg, evidence) = err else {
                    Issue.record("Expected .tokenRejected, got \(err)")
                    return
                }
                #expect(host == "space.test")
                #expect(error == "InvalidDelegationToken")
                #expect(msg == "Delegation token signature invalid")
                #expect(evidence == nil)
                let desc = err.errorDescription ?? ""
                #expect(desc == "space.test rejected the delegation token as invalid (not an access denial; membership is unaffected).")
                #expect(!desc.contains("usually means"))
                #expect(!desc.contains("different permissioned-data profile"))
            } catch {
                Issue.record("Expected SpaceCredentialError, got \(error)")
            }
        }
    }

    @Test("exchange classifies 400 InvalidDelegationToken and cites identifying evidence when probe succeeds")
    func exchangeClassifiesTokenRejectedProbeSucceeded() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let didResolver = DummyDIDResolver()
            let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))
            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")

            SpaceMockURLProtocol.setHandler { request in
                let urlString = request.url?.absoluteString ?? ""
                if urlString.contains("plc.directory") || urlString.contains(".well-known/did.json") {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, Data(self.didDocJSON.utf8))
                }
                if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = #"{"error":"InvalidDelegationToken","message":"Delegation token signature invalid"}"#.data(using: .utf8)!
                    return (resp, body)
                }
                if urlString == "https://space.test/xrpc/com.atproto.server.describeServer" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = #"{"did":"did:web:space.test","availableUserDomains":[],"inviteCodeRequired":true,"swanProfile":"permissioned-data-0016-2026-07-30"}"#.data(using: .utf8)!
                    return (resp, body)
                }
                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                resolver: spaceResolver,
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token" }
            )

            do {
                _ = try await manager.credential(for: space)
                Issue.record("Expected credential to throw tokenRejected")
            } catch let err as SpaceCredentialError {
                guard case let .tokenRejected(host, error, msg, evidence) = err else {
                    Issue.record("Expected .tokenRejected, got \(err)")
                    return
                }
                #expect(host == "space.test")
                #expect(error == "InvalidDelegationToken")
                #expect(msg == "Delegation token signature invalid")
                #expect(evidence == "swanProfile=permissioned-data-0016-2026-07-30")
                let desc = err.errorDescription ?? ""
                #expect(desc == "space.test rejected the delegation token as invalid (not an access denial; membership is unaffected). space.test reports: swanProfile=permissioned-data-0016-2026-07-30.")
                #expect(!desc.contains("usually means"))
            } catch {
                Issue.record("Expected SpaceCredentialError, got \(error)")
            }
        }
    }

    @Test("exchange tokenRejected probe timeout does not fail or hang error path")
    func exchangeClassifiesTokenRejectedProbeTimeout() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let didResolver = DummyDIDResolver()
            let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))
            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")

            SpaceMockURLProtocol.setHandler { request in
                let urlString = request.url?.absoluteString ?? ""
                if urlString.contains("plc.directory") || urlString.contains(".well-known/did.json") {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, Data(self.didDocJSON.utf8))
                }
                if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = #"{"error":"InvalidDelegationToken","message":"Expired delegation token"}"#.data(using: .utf8)!
                    return (resp, body)
                }
                if urlString == "https://space.test/xrpc/com.atproto.server.describeServer" {
                    // Simulate network error / connection dropped
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                    return (resp, Data("server error".utf8))
                }
                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                resolver: spaceResolver,
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token" }
            )

            do {
                _ = try await manager.credential(for: space)
                Issue.record("Expected credential to throw tokenRejected")
            } catch let err as SpaceCredentialError {
                guard case let .tokenRejected(host, _, _, evidence) = err else {
                    Issue.record("Expected .tokenRejected, got \(err)")
                    return
                }
                #expect(host == "space.test")
                #expect(evidence == nil)
                let desc = err.errorDescription ?? ""
                #expect(desc == "space.test rejected the delegation token as invalid (not an access denial; membership is unaffected).")
            } catch {
                Issue.record("Expected SpaceCredentialError, got \(error)")
            }
        }
    }

    @Test("exchange classifies 403 UserNotAuthorized as authorizationRefused")
    func exchangeClassifiesAuthorizationRefused() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let didResolver = DummyDIDResolver()
            let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))
            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")

            SpaceMockURLProtocol.setHandler { request in
                let urlString = request.url?.absoluteString ?? ""
                if urlString.contains("plc.directory") || urlString.contains(".well-known/did.json") {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, Data(self.didDocJSON.utf8))
                }
                if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = #"{"error":"UserNotAuthorized","message":"User is not a member of this space"}"#.data(using: .utf8)!
                    return (resp, body)
                }
                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                resolver: spaceResolver,
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token" }
            )

            do {
                _ = try await manager.credential(for: space)
                Issue.record("Expected credential to throw authorizationRefused")
            } catch let err as SpaceCredentialError {
                guard case let .authorizationRefused(host, error, msg) = err else {
                    Issue.record("Expected .authorizationRefused, got \(err)")
                    return
                }
                #expect(host == "space.test")
                #expect(error == "UserNotAuthorized")
                #expect(msg == "User is not a member of this space")
                let desc = err.errorDescription ?? ""
                #expect(desc.contains("You no longer have access to this space"))
                #expect(desc.contains("space.test"))
            } catch {
                Issue.record("Expected SpaceCredentialError, got \(error)")
            }
        }
    }

    @Test("exchange classifies SpaceDeleted error as spaceDeleted")
    func exchangeClassifiesSpaceDeleted() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let didResolver = DummyDIDResolver()
            let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))
            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")

            SpaceMockURLProtocol.setHandler { request in
                let urlString = request.url?.absoluteString ?? ""
                if urlString.contains("plc.directory") || urlString.contains(".well-known/did.json") {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, Data(self.didDocJSON.utf8))
                }
                if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = #"{"error":"SpaceDeleted","message":"The space was deleted"}"#.data(using: .utf8)!
                    return (resp, body)
                }
                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                resolver: spaceResolver,
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token" }
            )

            do {
                _ = try await manager.credential(for: space)
                Issue.record("Expected credential to throw spaceDeleted")
            } catch let err as SpaceCredentialError {
                guard case let .spaceDeleted(host, msg) = err else {
                    Issue.record("Expected .spaceDeleted, got \(err)")
                    return
                }
                #expect(host == "space.test")
                #expect(msg == "The space was deleted")
                let desc = err.errorDescription ?? ""
                #expect(desc.contains("SpaceDeleted"))
            } catch {
                Issue.record("Expected SpaceCredentialError, got \(error)")
            }
        }
    }

    @Test("exchange preserves opaque 500 error as exchangeFailed")
    func exchangeClassifiesOpaque500() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let didResolver = DummyDIDResolver()
            let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))
            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")

            SpaceMockURLProtocol.setHandler { request in
                let urlString = request.url?.absoluteString ?? ""
                if urlString.contains("plc.directory") || urlString.contains(".well-known/did.json") {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, Data(self.didDocJSON.utf8))
                }
                if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: ["Content-Type": "text/plain"])!
                    let body = "Internal Server Error".data(using: .utf8)!
                    return (resp, body)
                }
                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                resolver: spaceResolver,
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token" }
            )

            do {
                _ = try await manager.credential(for: space)
                Issue.record("Expected credential to throw exchangeFailed")
            } catch let err as SpaceCredentialError {
                guard case let .exchangeFailed(statusCode, message) = err else {
                    Issue.record("Expected .exchangeFailed, got \(err)")
                    return
                }
                #expect(statusCode == 500)
                #expect(message == "Internal Server Error")
                let desc = err.errorDescription ?? ""
                #expect(desc.contains("500"))
                #expect(desc.contains("Internal Server Error"))
            } catch {
                Issue.record("Expected SpaceCredentialError, got \(error)")
            }
        }
    }

    @Test("provider-injection path: custom SpaceAuthorityHostProvider is invoked with space authority DID and used for exchange")
    func customAuthorityHostProviderPath() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))
            let space = try SpaceRef(uriString: "at://did:plc:customauth/space/com.example.drive/self")
            let expTime = Int(Date().addingTimeInterval(3600).timeIntervalSince1970)
            let credentialJWT = makeMockCredentialJWT(exp: expTime)

            let capturedRequests = Mutex<[URLRequest]>([])
            let providerCalledWithDID = Mutex<String?>(nil)

            SpaceMockURLProtocol.setHandler { request in
                capturedRequests.withLock { $0.append(request) }
                let urlString = request.url?.absoluteString ?? ""
                if urlString == "https://custom-space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    let resp = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = try JSONEncoder().encode(["credential": credentialJWT])
                    return (resp, body)
                }
                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                authorityHostProvider: { did in
                    providerCalledWithDID.withLock { $0 = did }
                    return URL(string: "https://custom-space.test")!
                },
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token-custom" }
            )

            let cred = try await manager.credential(for: space)
            #expect(cred.token == credentialJWT)
            #expect(providerCalledWithDID.withLock { $0 } == "did:plc:customauth")

            let requests = capturedRequests.withLock { $0 }
            let exchangeRequests = requests.filter {
                $0.url?.absoluteString == "https://custom-space.test/xrpc/com.atproto.space.getSpaceCredential"
            }
            #expect(exchangeRequests.count == 1)
            #expect(exchangeRequests[0].value(forHTTPHeaderField: "Authorization") == nil)
        }
    }

    @Test("compatibility-sugar path: init(resolver:) delegates to authorityHostProvider correctly")
    func compatibilitySugarResolverPath() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let didResolver = DummyDIDResolver()
            let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))

            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")
            let expTime = Int(Date().addingTimeInterval(3600).timeIntervalSince1970)
            let credentialJWT = makeMockCredentialJWT(exp: expTime)

            SpaceMockURLProtocol.setHandler { request in
                let urlString = request.url?.absoluteString ?? ""
                if urlString.contains("plc.directory") || urlString.contains(".well-known/did.json") {
                    let resp = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (resp, Data(self.didDocJSON.utf8))
                }
                if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    let resp = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = try JSONEncoder().encode(["credential": credentialJWT])
                    return (resp, body)
                }
                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                resolver: spaceResolver,
                urlSession: session,
                delegationTokenProvider: { _ in "mock-delegation-token-sugar" }
            )

            let cred = try await manager.credential(for: space)
            #expect(cred.token == credentialJWT)
        }
    }

    @Test("ordering preservation: authorityHostProvider is invoked before delegationTokenProvider minting")
    func orderingPreservationProviderBeforeMint() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))
            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")
            let expTime = Int(Date().addingTimeInterval(3600).timeIntervalSince1970)
            let credentialJWT = makeMockCredentialJWT(exp: expTime)

            let callOrder = Mutex<[String]>([])

            SpaceMockURLProtocol.setHandler { request in
                let urlString = request.url?.absoluteString ?? ""
                if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                    let resp = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = try JSONEncoder().encode(["credential": credentialJWT])
                    return (resp, body)
                }
                let resp = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }

            let manager = SpaceCredentialManager(
                client: client,
                authorityHostProvider: { did in
                    callOrder.withLock { $0.append("authorityHostProvider:\(did)") }
                    return URL(string: "https://space.test")!
                },
                urlSession: session,
                delegationTokenProvider: { ref in
                    callOrder.withLock { $0.append("delegationTokenProvider:\(ref.spaceDID)") }
                    return "mock-delegation-token"
                }
            )

            _ = try await manager.credential(for: space)

            let order = callOrder.withLock { $0 }
            #expect(order == [
                "authorityHostProvider:did:plc:auth123",
                "delegationTokenProvider:did:plc:auth123",
            ])
        }
    }

    @Test("isSecureOrLoopback rejects https URL with no host")
    func isSecureOrLoopbackRejectsNoHost() throws {
        #expect(try SpaceCredentialManager.isSecureOrLoopback(#require(URL(string: "https://example.com"))) == true)
        #expect(try SpaceCredentialManager.isSecureOrLoopback(#require(URL(string: "https://pds.test/xrpc"))) == true)

        #expect(try SpaceCredentialManager.isSecureOrLoopback(#require(URL(string: "https:"))) == false)
        #expect(try SpaceCredentialManager.isSecureOrLoopback(#require(URL(string: "https://"))) == false)
        #expect(try SpaceCredentialManager.isSecureOrLoopback(#require(URL(string: "https:///path/only"))) == false)

        #expect(try SpaceCredentialManager.isSecureOrLoopback(#require(URL(string: "http://127.0.0.1:8080"))) == true)
        #expect(try SpaceCredentialManager.isSecureOrLoopback(#require(URL(string: "http://localhost:3000"))) == true)
        #expect(try SpaceCredentialManager.isSecureOrLoopback(#require(URL(string: "http://[::1]:8080"))) == true)

        #expect(try SpaceCredentialManager.isSecureOrLoopback(#require(URL(string: "http://insecure.example.com"))) == false)
        #expect(try SpaceCredentialManager.isSecureOrLoopback(#require(URL(string: "http:"))) == false)
    }
}

extension SpaceCredentialManagerTests {
    @Test("KEM rotation refreshes once and uses a new share on every retry and page")
    func rotatingKEMAndPaging() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")
            let repo = "did:plc:writer"
            let staleKey = Crypto.P256.KeyAgreement.PrivateKey()
            let currentKey = Crypto.P256.KeyAgreement.PrivateKey()
            func didKey(_ key: Crypto.P256.KeyAgreement.PrivateKey) throws -> String {
                let publicKey = try Crypto.P256.Signing.PublicKey(compressedRepresentation: key.publicKey.compressedRepresentation)
                return P256DIDKey(publicKey: publicKey).value
            }
            let stale = try didKey(staleKey), current = try didKey(currentKey)
            let refreshes = Mutex<[Bool]>([])
            let shares = Mutex<[String]>([])
            let token = makeMockCredentialJWT(exp: Int(Date().addingTimeInterval(600).timeIntervalSince1970))
            let digest = Data(repeating: 1, count: 32)
            let revision = "3kbcq3p7ad422"
            SpaceMockURLProtocol.setHandler { request in
                let url = request.url!
                if url.lastPathComponent == "com.atproto.space.getSpaceCredential" {
                    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
                    #expect(request.value(forHTTPHeaderField: "Signature") == nil)
                    return try (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, JSONEncoder().encode(["credential": token]))
                }
                let want = try #require(request.value(forHTTPHeaderField: "Atproto-Space-Want-Mac"))
                let share = try #require(want.components(separatedBy: "key_share=\"").last?.split(separator: "\"").first.map(String.init))
                shares.withLock { $0.append(share) }
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Atproto-Space-Credential " + token)
                #expect(request.value(forHTTPHeaderField: "Signature-Input") == "atproto-space-credential=" + SpaceHTTPSignature.signatureParams())
                if url.lastPathComponent == "com.atproto.space.listRepoOps" {
                    return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"ops":[],"cursor":"next"}"#.utf8))
                }
                let secret = try SpaceMAC.decapsulate(privateKey: currentKey, keyShare: share)
                let mac = try SpaceMAC.commit(sharedSecret: secret, space: space.uriString(), repo: repo, rev: revision, data: digest)
                let body: [String: Any] = ["commit": ["ver": 1, "space": space.uriString(), "repo": repo, "rev": revision, "data": ["$bytes": digest.base64EncodedString().replacingOccurrences(of: "=", with: "")]]]
                return try (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Atproto-Space-Mac": "type=\"atproto-space-repo\", ver=1, mac=:\(mac.base64EncodedString()):"])!, JSONSerialization.data(withJSONObject: body))
            }
            defer { SpaceMockURLProtocol.setHandler(nil) }
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))
            let manager = SpaceCredentialManager(client: client, authorityHostProvider: { _ in URL(string: "https://space.test")! }, urlSession: session, delegationTokenProvider: { _ in "delegation" }, authorKEMKeyProvider: { _, forceRefresh in
                refreshes.withLock { $0.append(forceRefresh) }
                return forceRefresh ? current : stale
            })
            _ = try await manager.get(url: #require(URL(string: "https://repo.test/xrpc/com.atproto.space.getLatestCommit?repo=\(repo)")), space: space)
            _ = try await manager.get(url: #require(URL(string: "https://repo.test/xrpc/com.atproto.space.listRepoOps?repo=\(repo)&cursor=one")), space: space)
            _ = try await manager.get(url: #require(URL(string: "https://repo.test/xrpc/com.atproto.space.listRepoOps?repo=\(repo)&cursor=two")), space: space)
            #expect(refreshes.withLock { $0 } == [false, true, false, false])
            #expect(Set(shares.withLock { $0 }).count == 4)
        }
    }

    @Test("Only structured exact SpaceDeleted is destructive; InvalidDelegationToken is HTTP 400")
    func exactErrors() async throws {
        try await withSpaceTestSession {
            let session = makeMockSession()
            defer { session.invalidateAndCancel() }
            let client = try await ATProtoClient(baseURL: #require(URL(string: "https://pds.test")))
            let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")
            for (status, body, expected) in [(400, #"{"error":"InvalidDelegationToken","message":"expired"}"#, "token"), (400, #"{"error":"Other","message":"Upstream said SpaceDeleted"}"#, "exchange"), (400, "SpaceDeleted", "exchange"), (400, #"{"error":"SpaceDeleted"}"#, "deleted"), (500, #"{"error":"SpaceDeleted"}"#, "exchange"), (503, #"{"error":"SpaceDeleted"}"#, "exchange")] {
                SpaceMockURLProtocol.setHandler { request in
                    (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
                }
                let manager = SpaceCredentialManager(client: client, authorityHostProvider: { _ in URL(string: "https://space.test")! }, urlSession: session, delegationTokenProvider: { _ in "delegation" })
                do { _ = try await manager.credential(for: space); Issue.record("Expected rejection") }
                catch let error as SpaceCredentialError {
                    switch error {
                    case .tokenRejected: #expect(expected == "token")
                    case .spaceDeleted: #expect(expected == "deleted")
                    case .exchangeFailed: #expect(expected == "exchange")
                    default: Issue.record("Unexpected \(error)")
                    }
                }
            }
            SpaceMockURLProtocol.setHandler(nil)
        }
    }
}
