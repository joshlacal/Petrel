import Crypto
import Foundation
@testable import Petrel
import Testing
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
private final class OAuthBindingTestURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?
    private nonisolated(unsafe) static var requests: [URLRequest] = []

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        handler = nil
        requests.removeAll()
    }

    static func setHandler(_ newHandler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?) {
        lock.lock()
        defer { lock.unlock() }
        handler = newHandler
    }

    static func recordedRequests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let currentHandler = Self.handler
        Self.lock.unlock()

        guard let currentHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let (response, data) = currentHandler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeHTTPResponse(
    url: URL,
    statusCode: Int,
    headers: [String: String] = [:]
) -> HTTPURLResponse {
    var allHeaders = headers
    if allHeaders["Content-Type"] == nil {
        allHeaders["Content-Type"] = "application/json"
    }
    return HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: allHeaders
    )!
}

private let testPDSHost = "https://pds.strict.test"
private let testAuthHost = "https://auth.strict.test"
private let evilAuthHost = "https://evil.auth.test"
private let testRedirectURI = "blue.catbird.atprotodrive:/callback"
private let testAliceDID = "did:plc:strictalice12345678901234"
private let testBobDID = "did:plc:strictbob98765432109876"

private func withOAuthBindingTransport<T>(
    _ backend: InMemorySecureStorage,
    handler: @escaping @Sendable (URLRequest) -> (HTTPURLResponse, Data),
    _ body: () async throws -> T
) async throws -> T {
    try await withSerializedStorageOverrideTest {
        KeychainManager._setStorageOverride(backend)
        OAuthBindingTestURLProtocol.reset()
        OAuthBindingTestURLProtocol.setHandler(handler)
        NetworkService.setNetworkTestProtocolClasses([OAuthBindingTestURLProtocol.self])
        NetworkService.dnsResolverOverride = { _ in ["93.184.216.34"] }
        defer {
            NetworkService.dnsResolverOverride = nil
            NetworkService.setNetworkTestProtocolClasses(nil)
            OAuthBindingTestURLProtocol.reset()
            KeychainManager._setStorageOverride(nil)
        }
        return try await body()
    }
}

private final class StrictMockDIDResolver: DIDResolving, @unchecked Sendable {
    var didToHandle: [String: String] = [testAliceDID: "alice.strict.test", testBobDID: "bob.strict.test"]
    var didToPDS: [String: URL] = [testAliceDID: URL(string: testPDSHost)!, testBobDID: URL(string: testPDSHost)!]
    var handleToDID: [String: String] = ["alice.strict.test": testAliceDID, "bob.strict.test": testBobDID]

    func resolveHandleToDID(handle: String) async throws -> String {
        guard let did = handleToDID[handle] else { throw NetworkError.requestFailed }
        return did
    }

    func resolveDIDToPDSURL(did: String) async throws -> URL {
        guard let pds = didToPDS[did] else { throw NetworkError.requestFailed }
        return pds
    }

    func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL) {
        guard let pds = didToPDS[did], let handle = didToHandle[did] else { throw NetworkError.requestFailed }
        return (handle, pds)
    }

    func resolveDIDDocument(did: String) async throws -> DIDDocument {
        throw NetworkError.requestFailed
    }
}

private final class ThreadSafeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }

    func get() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

@Suite("OAuth Strict Binding and Trust Tuple Tests", .serialized)
struct OAuthStrictBindingTests {
    private let protectedResourceJSON = """
    {
      "resource": "\(testPDSHost)",
      "authorization_servers": ["\(testAuthHost)"],
      "scopes_supported": ["atproto"],
      "bearer_methods_supported": ["header"],
      "resource_documentation": "\(testPDSHost)/docs"
    }
    """

    private let evilProtectedResourceJSON = """
    {
      "resource": "\(testPDSHost)",
      "authorization_servers": ["\(evilAuthHost)"],
      "scopes_supported": ["atproto"],
      "bearer_methods_supported": ["header"],
      "resource_documentation": "\(testPDSHost)/docs"
    }
    """

    private let authServerJSON = """
    {
      "issuer": "\(testAuthHost)",
      "scopes_supported": ["atproto"],
      "subject_types_supported": ["public"],
      "response_types_supported": ["code"],
      "response_modes_supported": ["query"],
      "grant_types_supported": ["authorization_code", "refresh_token"],
      "code_challenge_methods_supported": ["S256"],
      "authorization_response_iss_parameter_supported": true,
      "jwks_uri": "\(testAuthHost)/oauth/jwks",
      "authorization_endpoint": "\(testAuthHost)/oauth/authorize",
      "token_endpoint": "\(testAuthHost)/oauth/token",
      "token_endpoint_auth_methods_supported": ["none"],
      "revocation_endpoint": "\(testAuthHost)/oauth/revoke",
      "pushed_authorization_request_endpoint": "\(testAuthHost)/oauth/par",
      "require_pushed_authorization_requests": true,
      "dpop_signing_alg_values_supported": ["ES256"]
    }
    """

    private let parSuccessJSON = """
    {
      "request_uri": "urn:ietf:params:oauth:request_uri:strict-test-req-uri",
      "expires_in": 300
    }
    """

    private func tokenSuccessJSON(sub: String, tokenType: String = "DPoP") -> String {
        """
        {
          "access_token": "strict_access_token_123",
          "token_type": "\(tokenType)",
          "refresh_token": "strict_refresh_token_456",
          "expires_in": 3600,
          "sub": "\(sub)",
          "scope": "atproto"
        }
        """
    }

    private func makeStrategy(
        namespace: String,
        requireIssInCallback: Bool? = nil,
        enforcePDSAuthorizationBinding: Bool? = nil,
        didResolver: DIDResolving = StrictMockDIDResolver()
    ) -> PublicOAuthStrategy {
        let storage = KeychainStorage(namespace: namespace)
        let accountManager = MockAccountManager(
            account: Account(
                did: testAliceDID,
                handle: "alice.strict.test",
                pdsURL: URL(string: testPDSHost)!
            )
        )
        let config: OAuthConfig
        if let requireIss = requireIssInCallback, let enforceBinding = enforcePDSAuthorizationBinding {
            config = OAuthConfig(
                clientId: "https://client.example/oauth-client-metadata.json",
                redirectUri: testRedirectURI,
                scope: "atproto",
                requireIssInCallback: requireIss,
                enforcePDSAuthorizationBinding: enforceBinding
            )
        } else if let requireIss = requireIssInCallback {
            config = OAuthConfig(
                clientId: "https://client.example/oauth-client-metadata.json",
                redirectUri: testRedirectURI,
                scope: "atproto",
                requireIssInCallback: requireIss
            )
        } else if let enforceBinding = enforcePDSAuthorizationBinding {
            config = OAuthConfig(
                clientId: "https://client.example/oauth-client-metadata.json",
                redirectUri: testRedirectURI,
                scope: "atproto",
                enforcePDSAuthorizationBinding: enforceBinding
            )
        } else {
            // Default construction
            config = OAuthConfig(
                clientId: "https://client.example/oauth-client-metadata.json",
                redirectUri: testRedirectURI,
                scope: "atproto"
            )
        }
        return PublicOAuthStrategy(
            storage: storage,
            accountManager: accountManager,
            networkService: NetworkService(baseURL: URL(string: testPDSHost)!),
            oauthConfig: config,
            didResolver: didResolver
        )
    }

    private func makeCABStrategy(
        namespace: String,
        didResolver: DIDResolving = StrictMockDIDResolver()
    ) -> CABOAuthStrategy {
        let storage = KeychainStorage(namespace: namespace)
        let accountManager = MockAccountManager(
            account: Account(
                did: testAliceDID,
                handle: "alice.strict.test",
                pdsURL: URL(string: testPDSHost)!
            )
        )
        let config = OAuthConfig(
            clientId: "https://client.example/oauth-client-metadata.json",
            redirectUri: testRedirectURI,
            scope: "atproto"
        )
        return CABOAuthStrategy(
            backendURL: URL(string: "https://backend.example")!,
            storage: storage,
            accountManager: accountManager,
            networkService: NetworkService(baseURL: URL(string: testPDSHost)!),
            oauthConfig: config,
            didResolver: didResolver
        )
    }

    @Test("Step 4 & 5: Wrong issuer in callback is rejected")
    func testWrongIssuerInCallbackRejected() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/.well-known/oauth-protected-resource") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(protectedResourceJSON.utf8))
            } else if url.path.hasSuffix("/.well-known/oauth-authorization-server") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(authServerJSON.utf8))
            } else if url.path.hasSuffix("/oauth/par") {
                return (makeHTTPResponse(url: url, statusCode: 201), Data(parSuccessJSON.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.wrong_iss"
            let strategy = makeStrategy(namespace: namespace, requireIssInCallback: true)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.strict.test")

            // Callback with attacker issuer must fail
            let evilCallback = URL(string: "\(testRedirectURI)?code=test_code_123&state=\(stateToken)&iss=\(evilAuthHost)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: evilCallback)
            }
        }
    }

    @Test("Step 4 & 5: Missing issuer in callback is rejected when requireIssInCallback is true")
    func testMissingIssuerRejectedWhenRequired() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/.well-known/oauth-protected-resource") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(protectedResourceJSON.utf8))
            } else if url.path.hasSuffix("/.well-known/oauth-authorization-server") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(authServerJSON.utf8))
            } else if url.path.hasSuffix("/oauth/par") {
                return (makeHTTPResponse(url: url, statusCode: 201), Data(parSuccessJSON.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.missing_iss"
            let strategy = makeStrategy(namespace: namespace, requireIssInCallback: true)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.strict.test")

            let callbackWithoutIss = URL(string: "\(testRedirectURI)?code=test_code_123&state=\(stateToken)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callbackWithoutIss)
            }
        }
    }

    @Test("Step 4 & 5: Subject DID mismatch between initial identifier and token response throws")
    func testSubjectDIDMismatchThrows() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/.well-known/oauth-protected-resource") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(protectedResourceJSON.utf8))
            } else if url.path.hasSuffix("/.well-known/oauth-authorization-server") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(authServerJSON.utf8))
            } else if url.path.hasSuffix("/oauth/par") {
                return (makeHTTPResponse(url: url, statusCode: 201), Data(parSuccessJSON.utf8))
            } else if url.path.hasSuffix("/oauth/token") {
                // Return Bob's DID when Alice was initiated
                return (makeHTTPResponse(url: url, statusCode: 200), Data(tokenSuccessJSON(sub: testBobDID).utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.sub_mismatch"
            let strategy = makeStrategy(namespace: namespace)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.strict.test")

            let callback = URL(string: "\(testRedirectURI)?code=test_code_123&state=\(stateToken)&iss=\(testAuthHost)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callback)
            }
        }
    }

    @Test("Step 4 & 5: Non-DPoP token type is rejected")
    func testNonDPoPTokenTypeRejected() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/.well-known/oauth-protected-resource") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(protectedResourceJSON.utf8))
            } else if url.path.hasSuffix("/.well-known/oauth-authorization-server") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(authServerJSON.utf8))
            } else if url.path.hasSuffix("/oauth/par") {
                return (makeHTTPResponse(url: url, statusCode: 201), Data(parSuccessJSON.utf8))
            } else if url.path.hasSuffix("/oauth/token") {
                // Insecure Bearer token type returned
                return (makeHTTPResponse(url: url, statusCode: 200), Data(tokenSuccessJSON(sub: testAliceDID, tokenType: "Bearer").utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.bearer_rejected"
            let strategy = makeStrategy(namespace: namespace)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.strict.test")

            let callback = URL(string: "\(testRedirectURI)?code=test_code_123&state=\(stateToken)&iss=\(testAuthHost)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callback)
            }
        }
    }

    @Test("Step 4 & 5: PDS authorization binding failure is rejected when enforcePDSAuthorizationBinding is enabled")
    func testPDSAuthorizationBindingEnforced() async throws {
        let backend = InMemorySecureStorage()
        let pdsResourceCheckCount = ThreadSafeCounter()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/.well-known/oauth-protected-resource") {
                let count = pdsResourceCheckCount.increment()
                if count > 1 {
                    // Subsequent check on resolved PDS returns authorization server mismatch (evilAuthHost instead of testAuthHost)
                    return (makeHTTPResponse(url: url, statusCode: 200), Data(evilProtectedResourceJSON.utf8))
                }
                return (makeHTTPResponse(url: url, statusCode: 200), Data(protectedResourceJSON.utf8))
            } else if url.path.hasSuffix("/.well-known/oauth-authorization-server") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(authServerJSON.utf8))
            } else if url.path.hasSuffix("/oauth/par") {
                return (makeHTTPResponse(url: url, statusCode: 201), Data(parSuccessJSON.utf8))
            } else if url.path.hasSuffix("/oauth/token") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(tokenSuccessJSON(sub: testAliceDID).utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.pds_binding"
            let strategy = makeStrategy(namespace: namespace, enforcePDSAuthorizationBinding: true)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.strict.test")

            let callback = URL(string: "\(testRedirectURI)?code=test_code_123&state=\(stateToken)&iss=\(testAuthHost)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callback)
            }
        }
    }

    @Test("Step 4 & 6: Single-use state consumption prevents callback replay")
    func testOAuthStateSingleUseReplayProtection() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/.well-known/oauth-protected-resource") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(protectedResourceJSON.utf8))
            } else if url.path.hasSuffix("/.well-known/oauth-authorization-server") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(authServerJSON.utf8))
            } else if url.path.hasSuffix("/oauth/par") {
                return (makeHTTPResponse(url: url, statusCode: 201), Data(parSuccessJSON.utf8))
            } else if url.path.hasSuffix("/oauth/token") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(tokenSuccessJSON(sub: testAliceDID).utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.replay_protection"
            let strategy = makeStrategy(namespace: namespace)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.strict.test")
            let callback = URL(string: "\(testRedirectURI)?code=test_code_123&state=\(stateToken)&iss=\(testAuthHost)")!

            // First callback succeeds
            let result = try await strategy.handleOAuthCallback(url: callback)
            #expect(result.did == testAliceDID)

            // Second callback fails immediately
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callback)
            }
        }
    }

    @Test("Step 5: Successful OAuth callback persists DPoP key, hydrates session, and activates account")
    func testSuccessfulOAuthCallbackFlow() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/.well-known/oauth-protected-resource") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(protectedResourceJSON.utf8))
            } else if url.path.hasSuffix("/.well-known/oauth-authorization-server") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(authServerJSON.utf8))
            } else if url.path.hasSuffix("/oauth/par") {
                return (makeHTTPResponse(url: url, statusCode: 201), Data(parSuccessJSON.utf8))
            } else if url.path.hasSuffix("/oauth/token") {
                #expect(req.value(forHTTPHeaderField: "DPoP") != nil)
                return (makeHTTPResponse(url: url, statusCode: 200), Data(tokenSuccessJSON(sub: testAliceDID).utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.success_flow"
            let strategy = makeStrategy(namespace: namespace, requireIssInCallback: true, enforcePDSAuthorizationBinding: true)
            let storage = KeychainStorage(namespace: namespace)

            let (authURL, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.strict.test")
            #expect(authURL.absoluteString.contains("request_uri="))

            let callback = URL(string: "\(testRedirectURI)?code=test_code_123&state=\(stateToken)&iss=\(testAuthHost)")!
            let result = try await strategy.handleOAuthCallback(url: callback)

            #expect(result.did == testAliceDID)
            #expect(result.handle == "alice.strict.test")

            // Verify DPoP key and session stored
            let storedKey = try? await storage.getDPoPKeyRepresentation(for: testAliceDID)
            #expect(storedKey != nil)
            let storedSession = try? await storage.getSession(for: testAliceDID)
            #expect(storedSession != nil)
            #expect(storedSession?.tokenType == .dpop)
        }
    }

    @Test("Step 4 & 5: Default OAuthConfig enforces issuer in callback and PDS authorization binding")
    func testDefaultOAuthConfigEnforcesIssuerAndPDSBinding() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/.well-known/oauth-protected-resource") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(protectedResourceJSON.utf8))
            } else if url.path.hasSuffix("/.well-known/oauth-authorization-server") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(authServerJSON.utf8))
            } else if url.path.hasSuffix("/oauth/par") {
                return (makeHTTPResponse(url: url, statusCode: 201), Data(parSuccessJSON.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.defaults"
            let strategy = makeStrategy(namespace: namespace) // Uses default OAuthConfig

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.strict.test")

            // 1. Missing iss must fail under default config
            let callbackWithoutIss = URL(string: "\(testRedirectURI)?code=test_code_123&state=\(stateToken)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callbackWithoutIss)
            }
        }
    }

    @Test("Step 4 & 5: Legacy OAuthState lacking required trust tuple fields fails closed")
    func testLegacyOAuthStateMissingTupleFieldsFailsClosed() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            (makeHTTPResponse(url: req.url!, statusCode: 200), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.legacy_missing_tuple"
            let storage = KeychainStorage(namespace: namespace)
            let strategy = makeStrategy(namespace: namespace)

            let legacyStateToken = "legacy_state_without_tuple"
            // Manually persist legacy OAuthState lacking expectedIssuer, dpopJKT, redirectURI, expectedPDSOrigin
            let legacyState = OAuthState(
                stateToken: legacyStateToken,
                codeVerifier: "legacy_verifier_123",
                createdAt: Date(),
                initialIdentifier: "alice.strict.test",
                targetPDSURL: URL(string: testPDSHost)!,
                ephemeralDPoPKey: P256.Signing.PrivateKey().rawRepresentation,
                parResponseNonce: nil,
                bskyAppViewDID: nil,
                bskyChatDID: nil,
                expectedIssuer: nil,
                expectedPDSOrigin: nil,
                expectedDID: nil,
                redirectURI: nil,
                dpopJKT: nil,
                tokenEndpoint: nil,
                authorizationEndpoint: nil
            )
            try await storage.saveOAuthState(legacyState)

            let callback = URL(string: "\(testRedirectURI)?code=test_code_123&state=\(legacyStateToken)&iss=\(testAuthHost)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callback)
            }

            // State is consumed and deleted
            let remaining = try? await storage.getOAuthState(for: legacyStateToken)
            #expect(remaining == nil)
        }
    }

    @Test("Step 4 & 5: Mismatched redirect URI scheme, host, port, or path fails closed")
    func testMismatchedRedirectURIFailsClosed() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/.well-known/oauth-protected-resource") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(protectedResourceJSON.utf8))
            } else if url.path.hasSuffix("/.well-known/oauth-authorization-server") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(authServerJSON.utf8))
            } else if url.path.hasSuffix("/oauth/par") {
                return (makeHTTPResponse(url: url, statusCode: 201), Data(parSuccessJSON.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.mismatched_redirect"
            let strategy = makeStrategy(namespace: namespace)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.strict.test")

            let mismatchedURLs = [
                "other.scheme:/callback?code=test_code_123&state=\(stateToken)&iss=\(testAuthHost)",
                "blue.catbird.atprotodrive:/otherpath?code=test_code_123&state=\(stateToken)&iss=\(testAuthHost)",
                "https://catbird.blue/callback?code=test_code_123&state=\(stateToken)&iss=\(testAuthHost)",
            ]

            for rawURL in mismatchedURLs {
                let callback = URL(string: rawURL)!
                await #expect(throws: (any Error).self) {
                    try await strategy.handleOAuthCallback(url: callback)
                }
            }
        }
    }

    @Test("Step 4 & 6: cancelOAuthFlow purges persisted OAuthState from keychain")
    func testCancelOAuthFlowPurgesPersistedOAuthState() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/.well-known/oauth-protected-resource") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(protectedResourceJSON.utf8))
            } else if url.path.hasSuffix("/.well-known/oauth-authorization-server") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(authServerJSON.utf8))
            } else if url.path.hasSuffix("/oauth/par") {
                return (makeHTTPResponse(url: url, statusCode: 201), Data(parSuccessJSON.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.cancel_purge"
            let storage = KeychainStorage(namespace: namespace)
            let strategy = makeStrategy(namespace: namespace)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.strict.test")
            #expect(try await storage.getOAuthState(for: stateToken) != nil)

            await strategy.cancelOAuthFlow()

            #expect(try await storage.getOAuthState(for: stateToken) == nil)

            let callback = URL(string: "\(testRedirectURI)?code=test_code_123&state=\(stateToken)&iss=\(testAuthHost)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callback)
            }
        }
    }

    @Test("Step 4 & 6: Explicit error callback purges persisted OAuthState")
    func testErrorCallbackPurgesPersistedOAuthState() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/.well-known/oauth-protected-resource") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(protectedResourceJSON.utf8))
            } else if url.path.hasSuffix("/.well-known/oauth-authorization-server") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(authServerJSON.utf8))
            } else if url.path.hasSuffix("/oauth/par") {
                return (makeHTTPResponse(url: url, statusCode: 201), Data(parSuccessJSON.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.error_purge"
            let storage = KeychainStorage(namespace: namespace)
            let strategy = makeStrategy(namespace: namespace)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.strict.test")
            #expect(try await storage.getOAuthState(for: stateToken) != nil)

            let errorCallback = URL(string: "\(testRedirectURI)?error=access_denied&state=\(stateToken)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: errorCallback)
            }

            #expect(try await storage.getOAuthState(for: stateToken) == nil)
        }
    }

    @Test("A1-R2-02: LegacyPasswordStrategy createSession sends unauthenticated exact-origin request without bearer tokens")
    func testLegacyPasswordCreateSessionUnauthenticatedExactOrigin() async throws {
        let backend = InMemorySecureStorage()
        let pdsA = "https://pds-a.strict.test"
        let pdsB = "https://pds-b.strict.test"
        let pdsBURL = URL(string: pdsB)!

        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.contains("createSession") {
                let sessionOutput = """
                {
                    "did": "did:plc:bob-pds-b",
                    "handle": "bob.pds-b.test",
                    "accessJwt": "jwt-for-bob",
                    "refreshJwt": "refresh-for-bob"
                }
                """
                return (makeHTTPResponse(url: url, statusCode: 200), Data(sessionOutput.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.legacy.unauthenticated_pds_b"
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let networkService = NetworkService(baseURL: URL(string: pdsA)!)

            // Set up active account A with a legacy Bearer token
            let accountA = Account(
                did: "did:plc:alice-pds-a",
                handle: "alice.pds-a.test",
                pdsURL: URL(string: pdsA)!
            )
            try await storage.saveAccount(accountA, for: accountA.did)
            let sessionA = Session(
                accessToken: "secret-bearer-token-for-account-a",
                refreshToken: "refresh-a",
                createdAt: Date(),
                expiresIn: 3600,
                tokenType: .bearer,
                did: accountA.did
            )
            try await storage.saveSession(sessionA, for: accountA.did)
            try await accountManager.setCurrentAccount(did: accountA.did)

            let didResolver = StrictMockDIDResolver()
            didResolver.didToPDS["did:plc:bob-pds-b"] = pdsBURL
            didResolver.handleToDID["bob.pds-b.test"] = "did:plc:bob-pds-b"

            let legacyStrategy = LegacyPasswordStrategy(
                storage: storage,
                accountManager: accountManager,
                networkService: networkService,
                didResolver: didResolver
            )

            _ = try await legacyStrategy.loginWithPassword(identifier: "bob.pds-b.test", password: "password123", bskyAppViewDID: nil, bskyChatDID: nil)

            // Find the createSession request
            let recorded = OAuthBindingTestURLProtocol.recordedRequests()
            let createSessionReq = recorded.first { $0.url?.path.contains("createSession") == true }
            guard let req = createSessionReq else {
                Issue.record("Missing createSession request")
                return
            }
            #expect(req.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(req.value(forHTTPHeaderField: "DPoP") == nil)
            #expect(req.value(forHTTPHeaderField: "Cookie") == nil)
            #expect(req.value(forHTTPHeaderField: "Proxy-Authorization") == nil)
            #expect(req.value(forHTTPHeaderField: "atproto-proxy") == nil)

            // Test that cross-origin redirect on createSession is not followed and fails
            OAuthBindingTestURLProtocol.reset()
            OAuthBindingTestURLProtocol.setHandler { req in
                let url = req.url!
                if url.path.contains("createSession") {
                    return (makeHTTPResponse(url: url, statusCode: 302, headers: ["Location": "https://evil.test/hijack"]), Data())
                }
                return (makeHTTPResponse(url: url, statusCode: 200), Data("{}".utf8))
            }
            await #expect(throws: (any Error).self) {
                try await legacyStrategy.loginWithPassword(identifier: "bob.pds-b.test", password: "password123", bskyAppViewDID: nil, bskyChatDID: nil)
            }
            let redirectedRequests = OAuthBindingTestURLProtocol.recordedRequests()
            #expect(!redirectedRequests.contains { $0.url?.host == "evil.test" }, "Cross-origin redirect must not be followed")
        }
    }
    @Test("A1-R2-04: Missing persisted tokenEndpoint fails closed without rediscovery")
    func testMissingPersistedTokenEndpointFailsClosed() async throws {
        let backend = InMemorySecureStorage()
        let rediscoveryCounter = ThreadSafeCounter()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/.well-known/oauth-authorization-server") {
                _ = rediscoveryCounter.increment()
                return (makeHTTPResponse(url: url, statusCode: 200), Data(authServerJSON.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.missing_token_endpoint"
            let storage = KeychainStorage(namespace: namespace)
            let strategy = makeStrategy(namespace: namespace)

            let stateToken = UUID().uuidString
            let ephemeralKey = P256.Signing.PrivateKey()
            let jwk = try await strategy.core.createJWK(from: ephemeralKey)
            let dpopJKT = try await strategy.core.calculateJWKThumbprint(jwk: jwk)

            // Persist state with nil tokenEndpoint
            let state = OAuthState(
                stateToken: stateToken,
                codeVerifier: "test_verifier",
                createdAt: Date(),
                initialIdentifier: "alice.strict.test",
                targetPDSURL: URL(string: testPDSHost)!,
                ephemeralDPoPKey: ephemeralKey.rawRepresentation,
                expectedIssuer: testAuthHost,
                expectedPDSOrigin: testPDSHost,
                expectedDID: testAliceDID,
                redirectURI: testRedirectURI,
                dpopJKT: dpopJKT,
                tokenEndpoint: nil,
                authorizationEndpoint: "\(testAuthHost)/oauth/authorize"
            )
            try await storage.saveOAuthState(state)

            let callback = URL(string: "\(testRedirectURI)?code=code_123&state=\(stateToken)&iss=\(testAuthHost)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callback)
            }
            #expect(rediscoveryCounter.get() == 0, "Token endpoint must not be rediscovered on callback handling")
        }
    }

    @Test("A1-R2-04: Persisted PDS scheme, host, and port mismatches fail closed for login across Public and CAB")
    func testPDSOriginSchemeHostPortMismatchesFailClosed() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/oauth/token") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(tokenSuccessJSON(sub: testAliceDID).utf8))
            } else if url.path.hasSuffix("/.well-known/oauth-protected-resource") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(protectedResourceJSON.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.pds_mismatches"
            let storage = KeychainStorage(namespace: namespace)
            let publicStrategy = makeStrategy(namespace: namespace)
            let cabStrategy = makeCABStrategy(namespace: namespace)

            // Mismatch cases: scheme mismatch (http vs https), port mismatch (:8443 vs :443), host mismatch
            let mismatchedExpectedPDS = [
                "http://pds.strict.test",
                "https://pds.strict.test:8443",
                "https://other-pds.strict.test"
            ]

            for expectedPDS in mismatchedExpectedPDS {
                // Test Public Strategy Login (initialIdentifier != nil)
                let stateTokenPub = UUID().uuidString
                let ephemeralKeyPub = P256.Signing.PrivateKey()
                let jwkPub = try await publicStrategy.core.createJWK(from: ephemeralKeyPub)
                let dpopJKTPub = try await publicStrategy.core.calculateJWKThumbprint(jwk: jwkPub)

                let statePub = OAuthState(
                    stateToken: stateTokenPub,
                    codeVerifier: "test_verifier",
                    createdAt: Date(),
                    initialIdentifier: "alice.strict.test",
                    targetPDSURL: URL(string: testPDSHost)!,
                    ephemeralDPoPKey: ephemeralKeyPub.rawRepresentation,
                    expectedIssuer: testAuthHost,
                    expectedPDSOrigin: expectedPDS,
                    expectedDID: testAliceDID,
                    redirectURI: testRedirectURI,
                    dpopJKT: dpopJKTPub,
                    tokenEndpoint: "\(testAuthHost)/oauth/token",
                    authorizationEndpoint: "\(testAuthHost)/oauth/authorize"
                )
                try await storage.saveOAuthState(statePub)
                let callbackPub = URL(string: "\(testRedirectURI)?code=code_123&state=\(stateTokenPub)&iss=\(testAuthHost)")!
                await #expect(throws: (any Error).self) {
                    try await publicStrategy.handleOAuthCallback(url: callbackPub)
                }

                // Test CAB Strategy Login (initialIdentifier != nil)
                let stateTokenCAB = UUID().uuidString
                let ephemeralKeyCAB = P256.Signing.PrivateKey()
                let jwkCAB = try await cabStrategy.core.createJWK(from: ephemeralKeyCAB)
                let dpopJKTCAB = try await cabStrategy.core.calculateJWKThumbprint(jwk: jwkCAB)

                let stateCAB = OAuthState(
                    stateToken: stateTokenCAB,
                    codeVerifier: "test_verifier",
                    createdAt: Date(),
                    initialIdentifier: "alice.strict.test",
                    targetPDSURL: URL(string: testPDSHost)!,
                    ephemeralDPoPKey: ephemeralKeyCAB.rawRepresentation,
                    expectedIssuer: testAuthHost,
                    expectedPDSOrigin: expectedPDS,
                    expectedDID: testAliceDID,
                    redirectURI: testRedirectURI,
                    dpopJKT: dpopJKTCAB,
                    tokenEndpoint: "\(testAuthHost)/oauth/token",
                    authorizationEndpoint: "\(testAuthHost)/oauth/authorize"
                )
                try await storage.saveOAuthState(stateCAB)
                let callbackCAB = URL(string: "\(testRedirectURI)?code=code_123&state=\(stateTokenCAB)&iss=\(testAuthHost)")!
                await #expect(throws: (any Error).self) {
                    try await cabStrategy.handleOAuthCallback(url: callbackCAB)
                }
            }
        }
    }

    @Test("A1-R3-04: Public OAuth signup with different resolved PDS host succeeds when PDS authorizes initiating issuer")
    func testPublicOAuthSignupWithDifferentPDSHostSucceedsWhenIssuerMatches() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/oauth/token") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(tokenSuccessJSON(sub: testAliceDID).utf8))
            } else if url.path.hasSuffix("/.well-known/oauth-protected-resource") {
                // Resolved PDS returns protected resource declaring initiating issuer as its auth server
                return (makeHTTPResponse(url: url, statusCode: 200), Data(protectedResourceJSON.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.signup_different_pds_host_success"
            let storage = KeychainStorage(namespace: namespace)
            let strategy = makeStrategy(namespace: namespace)

            let stateToken = UUID().uuidString
            let ephemeralKey = P256.Signing.PrivateKey()
            let jwk = try await strategy.core.createJWK(from: ephemeralKey)
            let dpopJKT = try await strategy.core.calculateJWKThumbprint(jwk: jwk)

            // Signup flow initiated at an entryway (e.g. https://bsky.social) but resolved DID PDS is testPDSHost (https://pds.strict.test)
            let signupState = OAuthState(
                stateToken: stateToken,
                codeVerifier: "test_verifier",
                createdAt: Date(),
                initialIdentifier: nil, // signup has no initialIdentifier
                targetPDSURL: URL(string: "https://bsky.social")!,
                ephemeralDPoPKey: ephemeralKey.rawRepresentation,
                expectedIssuer: testAuthHost,
                expectedPDSOrigin: "https://bsky.social", // Entryway origin differs from resolved PDS
                expectedDID: nil,
                redirectURI: testRedirectURI,
                dpopJKT: dpopJKT,
                tokenEndpoint: "\(testAuthHost)/oauth/token",
                authorizationEndpoint: "\(testAuthHost)/oauth/authorize"
            )
            try await storage.saveOAuthState(signupState)

            let callback = URL(string: "\(testRedirectURI)?code=code_123&state=\(stateToken)&iss=\(testAuthHost)")!
            let result = try await strategy.handleOAuthCallback(url: callback)
            #expect(result.did == testAliceDID)
            #expect(result.handle == "alice.strict.test")
        }
    }

    @Test("A1-R3-04: Public OAuth signup fails when resolved PDS declares a different issuer")
    func testPublicOAuthSignupFailsWhenResolvedPDSDeclaresDifferentIssuer() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/oauth/token") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(tokenSuccessJSON(sub: testAliceDID).utf8))
            } else if url.path.hasSuffix("/.well-known/oauth-protected-resource") {
                // Resolved PDS declares a rogue/untrusted issuer
                let rogueResourceJSON = """
                {"resource":"\(testPDSHost)","authorization_servers":["https://rogue-auth.untrusted.test"]}
                """
                return (makeHTTPResponse(url: url, statusCode: 200), Data(rogueResourceJSON.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.signup_different_issuer_fails"
            let storage = KeychainStorage(namespace: namespace)
            let strategy = makeStrategy(namespace: namespace)

            let stateToken = UUID().uuidString
            let ephemeralKey = P256.Signing.PrivateKey()
            let jwk = try await strategy.core.createJWK(from: ephemeralKey)
            let dpopJKT = try await strategy.core.calculateJWKThumbprint(jwk: jwk)

            let signupState = OAuthState(
                stateToken: stateToken,
                codeVerifier: "test_verifier",
                createdAt: Date(),
                initialIdentifier: nil,
                targetPDSURL: URL(string: "https://bsky.social")!,
                ephemeralDPoPKey: ephemeralKey.rawRepresentation,
                expectedIssuer: testAuthHost,
                expectedPDSOrigin: "https://bsky.social",
                expectedDID: nil,
                redirectURI: testRedirectURI,
                dpopJKT: dpopJKT,
                tokenEndpoint: "\(testAuthHost)/oauth/token",
                authorizationEndpoint: "\(testAuthHost)/oauth/authorize"
            )
            try await storage.saveOAuthState(signupState)

            let callback = URL(string: "\(testRedirectURI)?code=code_123&state=\(stateToken)&iss=\(testAuthHost)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callback)
            }
        }
    }

    @Test("A1-R2-05: Delete failure retains terminal denial and subsequent callback fails closed")
    func testDeleteFailureRetainsTerminalDenial() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/.well-known/oauth-protected-resource") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(protectedResourceJSON.utf8))
            } else if url.path.hasSuffix("/.well-known/oauth-authorization-server") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data(authServerJSON.utf8))
            } else if url.path.hasSuffix("/oauth/par") {
                return (makeHTTPResponse(url: url, statusCode: 201), Data(parSuccessJSON.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.oauth.delete_failure_terminal"
            let storage = KeychainStorage(namespace: namespace)
            let strategy = makeStrategy(namespace: namespace)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.strict.test")
            #expect(try await storage.getOAuthState(for: stateToken) != nil)

            // Explicit provider error callback
            let errorCallback = URL(string: "\(testRedirectURI)?error=access_denied&state=\(stateToken)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: errorCallback)
            }

            // Subsequent attempt with a fake success callback on same stateToken must fail closed
            let callback = URL(string: "\(testRedirectURI)?code=test_code_123&state=\(stateToken)&iss=\(testAuthHost)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callback)
            }
        }
    }
}
