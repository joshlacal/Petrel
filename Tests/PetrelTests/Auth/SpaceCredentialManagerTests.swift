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
import Synchronization
import Testing
@testable import Petrel

// MARK: - Helper Functions

private func makeB64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func makeMockCredentialJWT(exp: Int, sub: String = "did:plc:user123", iss: String = "did:plc:auth123") -> String {
    let header = #"{"alg":"ES256","typ":"JWT"}"#
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

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        SpaceMockURLProtocol.lock.lock()
        let currentHandler = SpaceMockURLProtocol.handler
        SpaceMockURLProtocol.lock.unlock()

        guard let currentHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try currentHandler(request)
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
    NetworkService.setNetworkTestProtocolClasses([SpaceMockURLProtocol.self])
    NetworkService.dnsResolverOverride = { host in
        if host == "localhost" || host == "127.0.0.1" || host == "::1" {
            return ["127.0.0.1"]
        }
        return ["93.184.216.34"]
    }
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
    guard let header, header.hasPrefix("atproto-space=:"), header.hasSuffix(":") else { return nil }
    return Data(base64Encoded: String(header.dropFirst("atproto-space=:".count).dropLast()))
}

private func verifySpaceSignature(_ signature: Data, base: Data, keyID: String) throws -> Bool {
    let publicKey = try P256DIDKey(keyID).publicKey
    let ecdsa = try P256.Signing.ECDSASignature(rawRepresentation: signature)
    return publicKey.isValidSignature(ecdsa, for: base)
}

@Suite("Space HTTP message signatures")
struct SpaceHTTPSignatureTests {
    // Same constants as the reference http-signature.test.ts.
    private let authorization = "Atproto-Space credential"
    private let audience = "did:example:repo"

    @Test("credential-use signature base is the guide's three LF-joined lines with no trailing LF")
    func credentialUseSignatureBase() throws {
        let params = SpaceHTTPSignature.signatureParams(keyID: "unused", coversAudience: true)
        #expect(params == #"("authorization" "atproto-space-audience")"#)
        let base = SpaceHTTPSignature.signatureBase(
            authorization: authorization,
            audience: audience,
            signatureParams: params
        )
        let expected = Data((
            #""authorization": Atproto-Space credential"# + "\n" +
                #""atproto-space-audience": did:example:repo"# + "\n" +
                #""@signature-params": ("authorization" "atproto-space-audience")"#
        ).utf8)
        #expect(base == expected)
        #expect(base.last != UInt8(ascii: "\n"))
    }

    @Test("delegation-exchange signature base covers only authorization and names the keyid")
    func exchangeSignatureBase() throws {
        let keyID = "did:key:zDnaeiDB58sNddU7kh8FyUhsXdYX1MjHED261r8yfrYo5JwXM"
        let params = SpaceHTTPSignature.signatureParams(keyID: keyID, coversAudience: false)
        #expect(params == #"("authorization");keyid="did:key:zDnaeiDB58sNddU7kh8FyUhsXdYX1MjHED261r8yfrYo5JwXM""#)
        let base = SpaceHTTPSignature.signatureBase(
            authorization: "Bearer delegation",
            audience: nil,
            signatureParams: params
        )
        #expect(String(decoding: base, as: UTF8.self) == #""authorization": Bearer delegation"# + "\n" + #""@signature-params": "# + params)
    }

    @Test("verifies Node crypto signatures (low-S use, high-S exchange) over our signature bases")
    func crossImplementationVectors() throws {
        // Produced by node:crypto (ecdsa P-256, sha256, ieee-p1363) over the
        // reference signature bases; the exchange signature is high-S.
        let keyID = "did:key:zDnaeiDB58sNddU7kh8FyUhsXdYX1MjHED261r8yfrYo5JwXM"
        let useBase = SpaceHTTPSignature.signatureBase(
            authorization: authorization,
            audience: audience,
            signatureParams: SpaceHTTPSignature.signatureParams(keyID: keyID, coversAudience: true)
        )
        let useSig = try #require(Data(base64Encoded: "TavSjMA3LhHfPfifjA9AWgADPEAUK9YX5xV2BvlBUDk570Tbosj25cXbFb2O4ttEoS6ykUMs82R7YtXdM1BAew=="))
        #expect(try verifySpaceSignature(useSig, base: useBase, keyID: keyID))

        let exchangeBase = SpaceHTTPSignature.signatureBase(
            authorization: "Bearer delegation",
            audience: nil,
            signatureParams: SpaceHTTPSignature.signatureParams(keyID: keyID, coversAudience: false)
        )
        let exchangeSig = try #require(Data(base64Encoded: "75oRo+NDKwVXeGu0nb3DTk7blEQn2nl9LE+iDEbCSiv5Qe0ZWe/GXKkXOJ4MGY6GSGv9NBkpskQCq/3A4S7R3g=="))
        #expect(!P256WireSignature.isCanonicalLowS(exchangeSig))
        #expect(try verifySpaceSignature(exchangeSig, base: exchangeBase, keyID: keyID))

        // Positive control: the same signature does not verify over the other base.
        #expect(try !verifySpaceSignature(useSig, base: exchangeBase, keyID: keyID))
    }

    @Test("credential-use headers: exact field values and a 64-byte raw signature that round-trips")
    func credentialUseHeaders() throws {
        let key = P256.Signing.PrivateKey()
        let keyID = SpaceHTTPSignature.keyID(for: key)
        #expect(keyID.hasPrefix("did:key:zDn"))
        #expect(try P256DIDKey(keyID).publicKey.rawRepresentation == key.publicKey.rawRepresentation)

        let headers = try SpaceHTTPSignature.headers(key: key, authorization: authorization, audience: audience)
        #expect(Set(headers.keys) == ["Authorization", "Atproto-Space-Audience", "Signature-Input", "Signature"])
        #expect(headers["Authorization"] == authorization)
        #expect(headers["Atproto-Space-Audience"] == audience)
        #expect(headers["Signature-Input"] == #"atproto-space=("authorization" "atproto-space-audience")"#)

        let signature = try #require(spaceSignatureBytes(headers["Signature"]))
        #expect(signature.count == 64)
        let base = SpaceHTTPSignature.signatureBase(
            authorization: authorization,
            audience: audience,
            signatureParams: #"("authorization" "atproto-space-audience")"#
        )
        #expect(try verifySpaceSignature(signature, base: base, keyID: keyID))
        // A different audience must not verify.
        let wrongBase = SpaceHTTPSignature.signatureBase(
            authorization: authorization,
            audience: "did:example:other",
            signatureParams: #"("authorization" "atproto-space-audience")"#
        )
        #expect(try !verifySpaceSignature(signature, base: wrongBase, keyID: keyID))
    }

    @Test("delegation-exchange headers carry keyid and no audience")
    func exchangeHeaders() throws {
        let key = P256.Signing.PrivateKey()
        let keyID = SpaceHTTPSignature.keyID(for: key)
        let headers = try SpaceHTTPSignature.headers(key: key, authorization: "Bearer delegation", audience: nil)
        #expect(headers["Atproto-Space-Audience"] == nil)
        #expect(headers["Signature-Input"] == #"atproto-space=("authorization");keyid=""# + keyID + #"""#)
        let signature = try #require(spaceSignatureBytes(headers["Signature"]))
        #expect(signature.count == 64)
        let base = SpaceHTTPSignature.signatureBase(
            authorization: "Bearer delegation",
            audience: nil,
            signatureParams: #"("authorization");keyid=""# + keyID + #"""#
        )
        #expect(try verifySpaceSignature(signature, base: base, keyID: keyID))
    }

    @Test("audience defaults to the repo DID, else the bare space authority DID")
    func audienceDerivation() throws {
        let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")
        let repoURL = URL(string: "https://repo.test/xrpc/com.atproto.space.getRecord?space=at://did:plc:auth123/space/com.example.drive/self&repo=did:plc:writer&collection=a.b.c&rkey=self")!
        #expect(SpaceHTTPSignature.audience(for: repoURL, space: space) == "did:plc:writer")
        let hostURL = URL(string: "https://space.test/xrpc/com.atproto.space.listRepos?space=at://did:plc:auth123/space/com.example.drive/self")!
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
          "id": "did:plc:auth123#atproto_space",
          "type": "Multikey",
          "controller": "did:plc:auth123",
          "publicKeyMultibase": "zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPqiYBme"
        }
      ],
      "service": [
        {
          "id": "#atproto_space_host",
          "type": "AtprotoSpaceHost",
          "serviceEndpoint": "https://space.test"
        }
      ]
    }
    """

    private final class DummyDIDResolver: DIDResolving, @unchecked Sendable {
        func resolveHandleToDID(handle: String) async throws -> String { "did:plc:123" }
        func resolveDIDToPDSURL(did: String) async throws -> URL { URL(string: "https://pds.test")! }
        func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL) { ("user.test", URL(string: "https://pds.test")!) }
    }
    @Test("exchange POSTs delegation token as Bearer with an HTTP message signature naming the credential key, caches until expiry")
    func exchangeAndCache() async throws {
        let session = makeMockSession()
        let didResolver = DummyDIDResolver()
        let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)

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
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer mock-delegation-token-123")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")

        #expect(req.value(forHTTPHeaderField: "DPoP") == nil)
        #expect(req.value(forHTTPHeaderField: "Atproto-Space-Audience") == nil)

        // keyid names the credential's own key, which signed `("authorization")`.
        let credentialKey = try P256.Signing.PrivateKey(rawRepresentation: cred1.keyRawRepresentation)
        let keyID = P256DIDKey(publicKey: credentialKey.publicKey).value
        let params = #"("authorization");keyid=""# + keyID + #"""#
        #expect(req.value(forHTTPHeaderField: "Signature-Input") == "atproto-space=" + params)
        let signature = try #require(spaceSignatureBytes(req.value(forHTTPHeaderField: "Signature")))
        #expect(signature.count == 64)
        let base = SpaceHTTPSignature.signatureBase(
            authorization: "Bearer mock-delegation-token-123",
            audience: nil,
            signatureParams: params
        )
        #expect(try verifySpaceSignature(signature, base: base, keyID: keyID))
    }

    @Test("get() sends Atproto-Space credential, repo-DID audience, and a signature over both")
    func signedRead() async throws {
        let session = makeMockSession()
        let didResolver = DummyDIDResolver()
        let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)

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

        let targetURL = URL(string: "https://repo.test/xrpc/com.atproto.space.getRecord?repo=did:plc:writer&rkey=self")!
        let (data, response) = try await manager.get(url: targetURL, space: space)
        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == #"{"record":{"value":"ok"}}"#)

        let requests = capturedRequests.withLock { $0 }
        let getRequests = requests.filter { $0.url?.host == "repo.test" }
        #expect(getRequests.count == 1)

        let getReq = getRequests[0]
        #expect(getReq.httpMethod == "GET")
        #expect(getReq.value(forHTTPHeaderField: "Authorization") == "Atproto-Space \(credentialJWT)")
        #expect(getReq.value(forHTTPHeaderField: "Atproto-Space-Audience") == "did:plc:writer")
        #expect(getReq.value(forHTTPHeaderField: "DPoP") == nil)
        let params = #"("authorization" "atproto-space-audience")"#
        #expect(getReq.value(forHTTPHeaderField: "Signature-Input") == "atproto-space=" + params)

        let cred = try await manager.credential(for: space)
        let keyID = P256DIDKey(publicKey: try P256.Signing.PrivateKey(rawRepresentation: cred.keyRawRepresentation).publicKey).value
        let signature = try #require(spaceSignatureBytes(getReq.value(forHTTPHeaderField: "Signature")))
        #expect(signature.count == 64)
        let base = SpaceHTTPSignature.signatureBase(
            authorization: "Atproto-Space \(credentialJWT)",
            audience: "did:plc:writer",
            signatureParams: params
        )
        #expect(try verifySpaceSignature(signature, base: base, keyID: keyID))

        // Space-host operations (no repo) are addressed to the bare authority DID;
        // an explicit audience overrides derivation.
        _ = try await manager.get(url: URL(string: "https://repo.test/xrpc/com.atproto.space.listRepos?space=x")!, space: space)
        _ = try await manager.get(url: URL(string: "https://repo.test/xrpc/x")!, space: space, audience: "did:plc:explicit")
        let audiences = capturedRequests.withLock { $0 }
            .filter { $0.url?.host == "repo.test" }
            .map { $0.value(forHTTPHeaderField: "Atproto-Space-Audience") }
        #expect(audiences == ["did:plc:writer", "did:plc:auth123", "did:plc:explicit"])
    }

    @Test("get() refuses a non-DID or fragment-bearing audience before sending")
    func rejectsInvalidAudience() async throws {
        let session = makeMockSession()
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)
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
        for audience in ["did:plc:auth123#atproto_space_host", "space.test", "https://space.test"] {
            await #expect(throws: SpaceCredentialError.self) {
                _ = try await manager.get(url: URL(string: "https://repo.test/xrpc/x")!, space: space, audience: audience)
            }
        }
        #expect(sent.withLock { $0 } == 0)
    }

    @Test("401 CredentialRevoked drops the cached credential; the next request uses a fresh exchange and key")
    func credentialRevokedDropsCache() async throws {
        let session = makeMockSession()
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)
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
                return (resp, try JSONEncoder().encode(["credential": jwt]))
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
        let url = URL(string: "https://repo.test/xrpc/com.atproto.space.getRecord?repo=did:plc:writer")!

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

    @Test("a non-revocation 401 keeps the cached credential")
    func otherUnauthorizedKeepsCache() async throws {
        let session = makeMockSession()
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)
        let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")
        let exchangeCount = Mutex<Int>(0)

        SpaceMockURLProtocol.setHandler { request in
            if request.url?.absoluteString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                exchangeCount.withLock { $0 += 1 }
                let jwt = makeMockCredentialJWT(exp: Int(Date().addingTimeInterval(600).timeIntervalSince1970))
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, try JSONEncoder().encode(["credential": jwt]))
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
        let url = URL(string: "https://repo.test/xrpc/com.atproto.space.getRecord?repo=did:plc:writer")!
        _ = try await manager.get(url: url, space: space)
        _ = try await manager.get(url: url, space: space)
        #expect(exchangeCount.withLock { $0 } == 1)
    }

    @Test("get() rejects non-HTTPS non-loopback URLs")
    func rejectsInsecureURLs() async throws {
        let session = makeMockSession()
        let didResolver = DummyDIDResolver()
        let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)

        let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")

        let manager = SpaceCredentialManager(
            client: client,
            resolver: spaceResolver,
            urlSession: session,
            delegationTokenProvider: { _ in "mock-delegation-token" }
        )

        let insecureURL = URL(string: "http://insecure.repo.test/xrpc/com.atproto.space.getRecord")!
        await #expect(throws: SpaceCredentialError.self) {
            _ = try await manager.get(url: insecureURL, space: space)
        }
    }

    @Test("invalidate drops cache; next call re-exchanges")
    func invalidation() async throws {
        let session = makeMockSession()
        let didResolver = DummyDIDResolver()
        let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)

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

    @Test("invalidation while exchange is in flight discards the stale exchange result")
    func invalidationDuringInFlightExchange() async throws {
        let session = makeMockSession()
        let didResolver = DummyDIDResolver()
        let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)

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

    @Test("renews credential when within 60s of expiry")
    func renewalNearExpiry() async throws {
        let session = makeMockSession()
        let didResolver = DummyDIDResolver()
        let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)

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

    @Test("exchange classifies 401 InvalidDelegationToken as tokenRejected with plain message when probe returns nothing")
    func exchangeClassifiesTokenRejectedProbeFailed() async throws {
        let session = makeMockSession()
        let didResolver = DummyDIDResolver()
        let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)
        let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")

        SpaceMockURLProtocol.setHandler { request in
            let urlString = request.url?.absoluteString ?? ""
            if urlString.contains("plc.directory") || urlString.contains(".well-known/did.json") {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, Data(self.didDocJSON.utf8))
            }
            if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
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
            guard case .tokenRejected(let host, let error, let msg, let evidence) = err else {
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

    @Test("exchange classifies 401 InvalidDelegationToken and cites identifying evidence when probe succeeds")
    func exchangeClassifiesTokenRejectedProbeSucceeded() async throws {
        let session = makeMockSession()
        let didResolver = DummyDIDResolver()
        let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)
        let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")

        SpaceMockURLProtocol.setHandler { request in
            let urlString = request.url?.absoluteString ?? ""
            if urlString.contains("plc.directory") || urlString.contains(".well-known/did.json") {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, Data(self.didDocJSON.utf8))
            }
            if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
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
            guard case .tokenRejected(let host, let error, let msg, let evidence) = err else {
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

    @Test("exchange tokenRejected probe timeout does not fail or hang error path")
    func exchangeClassifiesTokenRejectedProbeTimeout() async throws {
        let session = makeMockSession()
        let didResolver = DummyDIDResolver()
        let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)
        let space = try SpaceRef(uriString: "at://did:plc:auth123/space/com.example.drive/self")

        SpaceMockURLProtocol.setHandler { request in
            let urlString = request.url?.absoluteString ?? ""
            if urlString.contains("plc.directory") || urlString.contains(".well-known/did.json") {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, Data(self.didDocJSON.utf8))
            }
            if urlString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential" {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
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
            guard case .tokenRejected(let host, _, _, let evidence) = err else {
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

    @Test("exchange classifies 403 UserNotAuthorized as authorizationRefused")
    func exchangeClassifiesAuthorizationRefused() async throws {
        let session = makeMockSession()
        let didResolver = DummyDIDResolver()
        let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)
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
            guard case .authorizationRefused(let host, let error, let msg) = err else {
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

    @Test("exchange classifies SpaceDeleted error as spaceDeleted")
    func exchangeClassifiesSpaceDeleted() async throws {
        let session = makeMockSession()
        let didResolver = DummyDIDResolver()
        let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)
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
            guard case .spaceDeleted(let host, let msg) = err else {
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

    @Test("exchange preserves opaque 500 error as exchangeFailed")
    func exchangeClassifiesOpaque500() async throws {
        let session = makeMockSession()
        let didResolver = DummyDIDResolver()
        let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)
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
            guard case .exchangeFailed(let statusCode, let message) = err else {
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

    @Test("provider-injection path: custom SpaceAuthorityHostProvider is invoked with space authority DID and used for exchange")
    func customAuthorityHostProviderPath() async throws {
        let session = makeMockSession()
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)
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
        #expect(exchangeRequests[0].value(forHTTPHeaderField: "Authorization") == "Bearer mock-delegation-token-custom")
    }

    @Test("compatibility-sugar path: init(resolver:) delegates to authorityHostProvider correctly")
    func compatibilitySugarResolverPath() async throws {
        let session = makeMockSession()
        let didResolver = DummyDIDResolver()
        let spaceResolver = SpaceHostResolver(didResolver: didResolver, urlSession: session)
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)

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

    @Test("ordering preservation: authorityHostProvider is invoked before delegationTokenProvider minting")
    func orderingPreservationProviderBeforeMint() async throws {
        let session = makeMockSession()
        let client = await ATProtoClient(baseURL: URL(string: "https://pds.test")!)
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
            "delegationTokenProvider:did:plc:auth123"
        ])
    }

    @Test("isSecureOrLoopback rejects https URL with no host")
    func isSecureOrLoopbackRejectsNoHost() {
        #expect(SpaceCredentialManager.isSecureOrLoopback(URL(string: "https://example.com")!) == true)
        #expect(SpaceCredentialManager.isSecureOrLoopback(URL(string: "https://pds.test/xrpc")!) == true)

        #expect(SpaceCredentialManager.isSecureOrLoopback(URL(string: "https:")!) == false)
        #expect(SpaceCredentialManager.isSecureOrLoopback(URL(string: "https://")!) == false)
        #expect(SpaceCredentialManager.isSecureOrLoopback(URL(string: "https:///path/only")!) == false)

        #expect(SpaceCredentialManager.isSecureOrLoopback(URL(string: "http://127.0.0.1:8080")!) == true)
        #expect(SpaceCredentialManager.isSecureOrLoopback(URL(string: "http://localhost:3000")!) == true)
        #expect(SpaceCredentialManager.isSecureOrLoopback(URL(string: "http://[::1]:8080")!) == true)

        #expect(SpaceCredentialManager.isSecureOrLoopback(URL(string: "http://insecure.example.com")!) == false)
        #expect(SpaceCredentialManager.isSecureOrLoopback(URL(string: "http:")!) == false)
    }
}
