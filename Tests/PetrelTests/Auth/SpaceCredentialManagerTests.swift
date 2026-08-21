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
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [SpaceMockURLProtocol.self]
    return URLSession(configuration: config)
}

// MARK: - SpaceDPoP Tests

@Suite("SpaceDPoP")
struct SpaceDPoPTests {
    @Test("proof carries htm/htu/jti/iat and typ dpop+jwt with embedded jwk")
    func proofShape() throws {
        let key = P256.Signing.PrivateKey()
        let jwt = try SpaceDPoP.proof(
            key: key,
            htm: "GET",
            htu: "https://pds.test/xrpc/com.atproto.space.getRecord",
            accessToken: nil
        )
        let parts = jwt.split(separator: ".")
        #expect(parts.count == 3)

        func b64url(_ s: Substring) -> Data {
            var s = String(s).replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            while s.count % 4 != 0 { s += "=" }
            return Data(base64Encoded: s)!
        }

        let h = try JSONSerialization.jsonObject(with: b64url(parts[0])) as! [String: Any]
        #expect(h["typ"] as? String == "dpop+jwt")
        #expect(h["alg"] as? String == "ES256")
        #expect((h["jwk"] as? [String: Any])?["crv"] as? String == "P-256")

        let p = try JSONSerialization.jsonObject(with: b64url(parts[1])) as! [String: Any]
        #expect(p["htm"] as? String == "GET")
        #expect(p["htu"] as? String == "https://pds.test/xrpc/com.atproto.space.getRecord")
        #expect(p["jti"] is String)
        #expect(p["ath"] == nil)
    }

    @Test("ath present and correct when accessToken given")
    func athBinding() throws {
        let key = P256.Signing.PrivateKey()
        let cred = "credential.jwt.value"
        let jwt = try SpaceDPoP.proof(
            key: key,
            htm: "GET",
            htu: "https://h.test/x",
            accessToken: cred
        )
        let payload = try SpaceDPoP.payload(ofJWT: jwt)
        let expected = Data(SHA256.hash(data: Data(cred.utf8)))
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        #expect(payload["ath"] as? String == expected)
    }

    @Test("payload(ofJWT:) throws on malformed JWT segments")
    func malformedJWTPayload() throws {
        // 1 part
        #expect(throws: SpaceCredentialError.self) {
            _ = try SpaceDPoP.payload(ofJWT: "onlyonepart")
        }

        // 2 parts
        #expect(throws: SpaceCredentialError.self) {
            _ = try SpaceDPoP.payload(ofJWT: "header.payload")
        }

        // 4 parts
        #expect(throws: SpaceCredentialError.self) {
            _ = try SpaceDPoP.payload(ofJWT: "header.payload.sig.extra")
        }

        // Empty parts
        #expect(throws: SpaceCredentialError.self) {
            _ = try SpaceDPoP.payload(ofJWT: "header..sig")
        }

        #expect(throws: SpaceCredentialError.self) {
            _ = try SpaceDPoP.payload(ofJWT: ".payload.sig")
        }

        #expect(throws: SpaceCredentialError.self) {
            _ = try SpaceDPoP.payload(ofJWT: "header.payload.")
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

    @Test("exchange POSTs delegation token as Bearer with DPoP header, caches until expiry")
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
        #expect(cred2 == cred1)

        let requests = capturedRequests.withLock { $0 }
        let exchangeRequests = requests.filter {
            $0.url?.absoluteString == "https://space.test/xrpc/com.atproto.space.getSpaceCredential"
        }
        #expect(exchangeRequests.count == 1)

        let req = exchangeRequests[0]
        #expect(req.httpMethod == "POST")
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer mock-delegation-token-123")
        #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")

        guard let dpopHeader = req.value(forHTTPHeaderField: "DPoP") else {
            Issue.record("DPoP header is missing")
            return
        }

        let dpopPayload = try SpaceDPoP.payload(ofJWT: dpopHeader)
        #expect(dpopPayload["htm"] as? String == "POST")
        #expect(dpopPayload["htu"] as? String == "https://space.test/xrpc/com.atproto.space.getSpaceCredential")
        #expect(dpopPayload["jti"] is String)
    }

    @Test("get() sends Authorization: DPoP <cred> and proof with ath")
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

        let targetURL = URL(string: "https://repo.test/xrpc/com.atproto.space.getRecord?rkey=self")!
        let (data, response) = try await manager.get(url: targetURL, space: space)
        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == #"{"record":{"value":"ok"}}"#)

        let requests = capturedRequests.withLock { $0 }
        let getRequests = requests.filter { $0.url?.host == "repo.test" }
        #expect(getRequests.count == 1)

        let getReq = getRequests[0]
        #expect(getReq.httpMethod == "GET")
        #expect(getReq.value(forHTTPHeaderField: "Authorization") == "DPoP \(credentialJWT)")

        guard let dpopProof = getReq.value(forHTTPHeaderField: "DPoP") else {
            Issue.record("Missing DPoP proof in get request")
            return
        }

        let proofPayload = try SpaceDPoP.payload(ofJWT: dpopProof)
        #expect(proofPayload["htm"] as? String == "GET")
        #expect(proofPayload["htu"] as? String == "https://repo.test/xrpc/com.atproto.space.getRecord")

        let expectedATH = makeB64URL(Data(SHA256.hash(data: Data(credentialJWT.utf8))))
        #expect(proofPayload["ath"] as? String == expectedATH)
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
        let slowExchangeGate = Mutex<Bool>(false)
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
                delegationAttempts.withLock { $0 += 1 }
                // Pause if gate is enabled
                if slowExchangeGate.withLock({ $0 }) {
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                return "mock-delegation-token"
            }
        )

        slowExchangeGate.withLock { $0 = true }

        // Start first exchange in background
        async let backgroundCred: SpaceCredential = manager.credential(for: space)

        // Invalidate while in-flight
        try await Task.sleep(nanoseconds: 10_000_000)
        await manager.invalidate(space)

        // The background task that was invalidated should throw (CancellationError)
        do {
            _ = try await backgroundCred
            // If it didn't throw before completion, next call must still re-exchange
        } catch {
            // Expected cancellation
        }

        slowExchangeGate.withLock { $0 = false }

        // Subsequent call must perform a fresh exchange, not use a stale cached result
        let cred = try await manager.credential(for: space)
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
}
