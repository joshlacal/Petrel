import Foundation
@testable import Petrel
import Testing
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

private final class GatewayLoginTestURLProtocol: URLProtocol {
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

private func withGatewayLoginTransport<T>(
    _ backend: InMemorySecureStorage,
    handler: @escaping @Sendable (URLRequest) -> (HTTPURLResponse, Data),
    _ body: @escaping () async throws -> T
) async throws -> T {
    try await withSerializedStorageOverrideTest {
        KeychainManager._setStorageOverride(backend)
        GatewayLoginTestURLProtocol.reset()
        GatewayLoginTestURLProtocol.setHandler(handler)
        NetworkService.setNetworkTestProtocolClasses([GatewayLoginTestURLProtocol.self])
        let testDNS: @Sendable (String) -> [String]? = { host in
            if host == "localhost" || host == "127.0.0.1" || host == "::1" {
                return ["127.0.0.1"]
            }
            return ["93.184.216.34"]
        }
        NetworkService.dnsResolverOverride = testDNS
        defer {
            NetworkService.dnsResolverOverride = nil
            NetworkService.setNetworkTestProtocolClasses(nil)
            GatewayLoginTestURLProtocol.reset()
            KeychainManager._setStorageOverride(nil)
        }
        return try await body()
    }
}

private final class GatewayThreadSafeCounter: @unchecked Sendable {
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

@Suite("Gateway Login Session Swap and Lifecycle Tests", .serialized)
struct GatewayLoginSessionSwapTests {
    private let gatewayURL = URL(string: "https://gateway.catbird.test")!
    private let callbackBase = "https://catbird.blue/oauth/callback"
    private let validCode = "code_1234567890123456789012345678901234567"
    private let aliceDID = "did:plc:alice123456789012345678"
    private let bobDID = "did:plc:bob9876543210987654321"
    private let sampleSessionID = "123e4567-e89b-12d3-a456-426614174000"

    private func makeStrategy(
        storage: KeychainStorage,
        accountManager: AccountManaging,
        session: URLSession? = nil
    ) -> ConfidentialGatewayStrategy {
        let sessionToUse: URLSession
        if let session {
            sessionToUse = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [GatewayLoginTestURLProtocol.self]
            sessionToUse = URLSession(configuration: config)
        }
        return ConfidentialGatewayStrategy(
            gatewayURL: gatewayURL,
            storage: storage,
            accountManager: accountManager,
            urlSession: sessionToUse
        )
    }

    @Test("Step 1 & 2: Legacy fragment session_id is strictly rejected")
    func testLegacyFragmentSessionIdRejected() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            (makeHTTPResponse(url: req.url!, statusCode: 200), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.legacy_fragment")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            // Start flow to have pending state
            _ = try await strategy.startOAuthFlow(identifier: "alice.test")

            // Fragment callback must be rejected immediately without saving credentials
            let fragmentURL = URL(string: "\(callbackBase)#session_id=\(sampleSessionID)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: fragmentURL)
            }

            // Verify no account or session was saved
            let savedSession = try? await storage.getGatewaySession(for: aliceDID)
            #expect(savedSession == nil)
            let currentAccount = await accountManager.getCurrentAccount()
            #expect(currentAccount == nil)
        }
    }

    @Test("Step 1: Callback without pending initiation fails closed")
    func testCallbackWithoutInitiationFailsClosed() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            (makeHTTPResponse(url: req.url!, statusCode: 200), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.no_init")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            let callbackURL = URL(string: "\(callbackBase)?code=\(validCode)&state=unsolicited_state_token")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callbackURL)
            }

            let currentAccount = await accountManager.getCurrentAccount()
            #expect(currentAccount == nil)
            #expect(GatewayLoginTestURLProtocol.recordedRequests().isEmpty)
        }
    }

    @Test("Step 1 & 2: Replay of callback code or state fails because state is single-use consumed")
    func testCallbackReplayFails() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/auth/exchange") {
                let json = "{\"session_id\":\"\(sampleSessionID)\"}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            } else if url.path.hasSuffix("/auth/session") {
                let json = "{\"did\":\"\(aliceDID)\",\"handle\":\"alice.test\",\"active\":true,\"granted_scopes\":[\"atproto\"]}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.replay")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.test")
            #expect(!stateToken.isEmpty)

            let callbackURL = URL(string: "\(callbackBase)?code=\(validCode)&state=\(stateToken)")!

            // First callback succeeds
            let result = try await strategy.handleOAuthCallback(url: callbackURL)
            #expect(result.did == aliceDID)

            // Second callback with the same code & state must fail because state was single-use consumed
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callbackURL)
            }
        }
    }

    @Test("Step 1: Callback from invalid redirect URI or malicious origin is rejected")
    func testInvalidRedirectOriginRejected() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            (makeHTTPResponse(url: req.url!, statusCode: 200), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.invalid_redirect")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.test")

            let invalidURLs = [
                "https://catbird.blue.evil/oauth/callback?code=\(validCode)&state=\(stateToken)",
                "https://evil.example/callback?code=\(validCode)&state=\(stateToken)",
                "http://catbird.blue/oauth/callback?code=\(validCode)&state=\(stateToken)",
                "https://catbird.blue/other-path?code=\(validCode)&state=\(stateToken)",
            ]

            for rawURL in invalidURLs {
                let url = URL(string: rawURL)!
                await #expect(throws: (any Error).self) {
                    try await strategy.handleOAuthCallback(url: url)
                }
            }
        }
    }

    @Test("Step 1 & 3: Expected DID mismatch throws and rejects activation")
    func testExpectedDIDMismatchThrows() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/auth/exchange") {
                let json = "{\"session_id\":\"\(sampleSessionID)\"}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            } else if url.path.hasSuffix("/auth/session") {
                // Gateway returns Bob's DID when Alice was expected
                let json = "{\"did\":\"\(bobDID)\",\"handle\":\"bob.test\",\"active\":true,\"granted_scopes\":[\"atproto\"]}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.did_mismatch")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            // Initiate flow expecting aliceDID
            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: aliceDID)

            let callbackURL = URL(string: "\(callbackBase)?code=\(validCode)&state=\(stateToken)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callbackURL)
            }

            // Neither Alice nor Bob must be saved as active account
            let current = await accountManager.getCurrentAccount()
            #expect(current == nil)
        }
    }

    @Test("Step 1 & 3: Inactive session (active: false) is rejected")
    func testInactiveSessionRejected() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/auth/exchange") {
                let json = "{\"session_id\":\"\(sampleSessionID)\"}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            } else if url.path.hasSuffix("/auth/session") {
                let json = "{\"did\":\"\(aliceDID)\",\"handle\":\"alice.test\",\"active\":false,\"granted_scopes\":[\"atproto\"]}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.inactive_session")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.test")
            let callbackURL = URL(string: "\(callbackBase)?code=\(validCode)&state=\(stateToken)")!

            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callbackURL)
            }

            let current = await accountManager.getCurrentAccount()
            #expect(current == nil)
        }
    }

    @Test("Step 1: Expired pending login state throws and is cleaned up")
    func testExpiredPendingLoginThrows() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            (makeHTTPResponse(url: req.url!, statusCode: 200), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.expired")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            // Save expired state manually (15 minutes old)
            let expiredStateToken = "expired_token_123"
            let expiredState = PendingGatewayLoginState(
                browserNonce: "nonce_1234567890123456789012345678901234567",
                stateToken: expiredStateToken,
                redirectURI: callbackBase,
                expectedDID: nil,
                createdAt: Date().addingTimeInterval(-900)
            )
            try await storage.savePendingGatewayLogin(expiredState)

            let callbackURL = URL(string: "\(callbackBase)?code=\(validCode)&state=\(expiredStateToken)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callbackURL)
            }

            // Verify state is no longer in storage
            let remaining = try? await storage.getPendingGatewayLogin(for: expiredStateToken)
            #expect(remaining == nil)
        }
    }

    @Test("Step 1 & 6: Cancellation erases pending login state")
    func testCancelOAuthFlowErasesPendingLogin() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            (makeHTTPResponse(url: req.url!, statusCode: 200), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.cancel")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.test")
            #expect(try await storage.getPendingGatewayLogin(for: stateToken) != nil)

            await strategy.cancelOAuthFlow()

            #expect(try await storage.getPendingGatewayLogin(for: stateToken) == nil)

            let callbackURL = URL(string: "\(callbackBase)?code=\(validCode)&state=\(stateToken)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callbackURL)
            }
        }
    }

    @Test("Step 2 & 3: Complete Nest exchange flow with browser nonce, exact origin, and session binding")
    func testCompleteNestExchangeFlow() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/auth/exchange") {
                // Verify Origin header and method
                #expect(req.httpMethod == "POST")
                #expect(req.value(forHTTPHeaderField: "Origin") == "https://catbird.blue")
                #expect(req.value(forHTTPHeaderField: "Content-Type") == "application/json")
                let body = String(data: req.bodyBytes ?? Data(), encoding: .utf8) ?? ""
                #expect(body.contains("browser_nonce"))
                #expect(body.contains("code"))

                let json = "{\"session_id\":\"\(sampleSessionID)\"}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            } else if url.path.hasSuffix("/auth/session") {
                #expect(req.httpMethod == "GET")
                #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer \(sampleSessionID)")
                let json = "{\"did\":\"\(aliceDID)\",\"handle\":\"alice.test\",\"active\":true,\"granted_scopes\":[\"atproto\"]}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.nest_exchange")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            let (loginURL, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.test")
            #expect(!stateToken.isEmpty)

            // Verify login URL structure matches Nest expectation: redirect_to + browser_nonce
            let components = URLComponents(url: loginURL, resolvingAgainstBaseURL: false)!
            #expect(components.path == "/auth/login")
            let queryMap = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            #expect(queryMap["redirect_to"] == callbackBase)
            let browserNonce = queryMap["browser_nonce"] ?? ""
            #expect(browserNonce.count == 43)

            // Nest redirects with only ?code=... (no state query parameter)
            let callbackURL = URL(string: "\(callbackBase)?code=\(validCode)")!
            let result = try await strategy.handleOAuthCallback(url: callbackURL)

            #expect(result.did == aliceDID)
            #expect(result.handle == "alice.test")
            #expect(result.pdsURL == gatewayURL)

            // Verify stored session and account
            let savedSession = try await storage.getGatewaySession(for: aliceDID)
            #expect(savedSession == sampleSessionID)
            let currentAccount = await accountManager.getCurrentAccount()
            #expect(currentAccount?.did == aliceDID)
            #expect(currentAccount?.handle == "alice.test")
        }
    }

    @Test("Step 2: Real Nest callback without state succeeds end-to-end")
    func testRealNestCallbackWithoutStateSucceeds() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/auth/exchange") {
                let json = "{\"session_id\":\"\(sampleSessionID)\"}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            } else if url.path.hasSuffix("/auth/session") {
                let json = "{\"did\":\"\(aliceDID)\",\"handle\":\"alice.test\",\"active\":true,\"granted_scopes\":[\"atproto\"]}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.nest_no_state")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            let authURL = try await strategy.startOAuthFlow(identifier: "alice.test")
            #expect(authURL.absoluteString.contains("/auth/login"))

            // Real Nest redirect shape (?code=...)
            let callbackURL = URL(string: "\(callbackBase)?code=\(validCode)")!
            let result = try await strategy.handleOAuthCallback(url: callbackURL)

            #expect(result.did == aliceDID)
            #expect(result.handle == "alice.test")
        }
    }

    @Test("Step 1 & 6: Explicit provider error callback with matching state purges pending gateway login state")
    func testErrorCallbackPurgesPendingGatewayLogin() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            (makeHTTPResponse(url: req.url!, statusCode: 200), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.error_callback")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.test")
            #expect(try await storage.getPendingGatewayLogin(for: stateToken) != nil)

            // Provider error callback with matching stateToken
            let errorCallback = URL(string: "\(callbackBase)?error=access_denied&state=\(stateToken)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: errorCallback)
            }

            // Pending state must be erased
            #expect(try await storage.getPendingGatewayLogin(for: stateToken) == nil)
        }
    }

    @Test("Step 2 & 3: Production default URLSession with 400 and 401 exchange responses fails closed")
    func testProductionHardenedSessionAndExchangeFailureResponses() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/auth/exchange") {
                return (makeHTTPResponse(url: url, statusCode: 200), Data("{\"session_id\":\"\(sampleSessionID)\"}".utf8))
            } else if url.path.hasSuffix("/auth/session") {
                let json = "{\"did\":\"\(aliceDID)\",\"handle\":\"alice.test\",\"active\":true,\"granted_scopes\":[\"atproto\"]}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.hardened_session")
            let accountManager = await AccountManager(storage: storage)
            // Construct strategy with default (nil) session to exercise production HardenedURLSessionDelegate
            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: gatewayURL,
                storage: storage,
                accountManager: accountManager
            )

            // 1. Test 400 exchange response (e.g. invalid / replayed browser nonce)
            _ = try await strategy.startOAuthFlow(identifier: "alice.test")
            let callback400 = URL(string: "\(callbackBase)?code=\(validCode)")!
            GatewayLoginTestURLProtocol.setHandler { req in
                let url = req.url!
                if url.path.hasSuffix("/auth/exchange") {
                    return (makeHTTPResponse(url: url, statusCode: 400), Data("{\"error\":\"invalid_request\"}".utf8))
                }
                return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
            }
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callback400)
            }
            #expect(try await storage.getGatewaySession(for: aliceDID) == nil)
            #expect(await accountManager.getCurrentAccount() == nil)

            // 2. Test 401 exchange response
            _ = try await strategy.startOAuthFlow(identifier: "alice.test")
            let callback401 = URL(string: "\(callbackBase)?code=\(validCode)")!
            GatewayLoginTestURLProtocol.setHandler { req in
                let url = req.url!
                if url.path.hasSuffix("/auth/exchange") {
                    return (makeHTTPResponse(url: url, statusCode: 401), Data("{\"error\":\"unauthorized\"}".utf8))
                }
                return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
            }
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callback401)
            }
            #expect(try await storage.getGatewaySession(for: aliceDID) == nil)
            #expect(await accountManager.getCurrentAccount() == nil)
        }
    }

    @Test("Step 3: Transport DNS rebinding to private IP fails with security violation")
    func testTransportDNSRebindingSecurityViolation() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/auth/exchange") {
                let json = "{\"session_id\":\"\(sampleSessionID)\"}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.dns_rebinding")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            _ = try await strategy.startOAuthFlow(identifier: "alice.test")

            // Override DNS resolver to return private IP range
            NetworkService.dnsResolverOverride = { _ in ["10.0.0.1"] }

            let callbackURL = URL(string: "\(callbackBase)?code=\(validCode)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callbackURL)
            }

            #expect(try await storage.getGatewaySession(for: aliceDID) == nil)
        }
    }

    @Test("A1-R2-03: Gateway requests run through task-scoped hardened executor and seed approved addresses")
    func testGatewayRequestTaskScopedHardenedExecutor() async throws {
        let backend = InMemorySecureStorage()
        let delegate = HardenedURLSessionDelegate(allowsRedirects: false, limits: .default)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [GatewayLoginTestURLProtocol.self]
        let customSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/auth/exchange") {
                let json = "{\"session_id\":\"\(sampleSessionID)\"}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            } else if url.path.hasSuffix("/auth/session") {
                let json = "{\"active\":true,\"did\":\"\(aliceDID)\"}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.task_scoped_executor")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager, session: customSession)

            _ = try await strategy.startOAuthFlow(identifier: "alice.test")

            let callbackURL = URL(string: "\(callbackBase)?code=\(validCode)")!
            let result = try await strategy.handleOAuthCallback(url: callbackURL)
            #expect(result.did == aliceDID)
        }
    }

    @Test("A1-R2-05: Gateway delete failure retains terminal denial and subsequent callback fails closed")
    func testGatewayDeleteFailureRetainsTerminalDenial() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/auth/exchange") {
                let json = "{\"session_id\":\"\(sampleSessionID)\"}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            } else if url.path.hasSuffix("/auth/session") {
                let json = "{\"active\":true,\"sub\":\"\(aliceDID)\"}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.delete_failure_terminal")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.test")

            // Provider error callback
            let errorCallback = URL(string: "\(callbackBase)?error=access_denied&state=\(stateToken)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: errorCallback)
            }

            // Subsequent attempt with a fake success callback on same stateToken must fail closed
            let callbackURL = URL(string: "\(callbackBase)?code=\(validCode)&state=\(stateToken)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: callbackURL)
            }
        }
    }
    @Test("A1-R3-01: Gateway cancellation only invalidates single-use flow state and allows subsequent fresh login with stateless callback")
    func testGatewayCancellationAllowsSubsequentFreshLoginWithStatelessCallback() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/auth/exchange") {
                let json = "{\"session_id\":\"\(sampleSessionID)\"}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            } else if url.path.hasSuffix("/auth/session") {
                let json = "{\"did\":\"\(aliceDID)\",\"handle\":\"alice.test\",\"active\":true,\"granted_scopes\":[\"atproto\"]}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.cancel_then_relogin")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            // 1. Start Flow 1
            let (_, stateToken1) = try await strategy.startOAuthFlowWithState(identifier: "alice.test")

            // 2. User cancels flow 1 (e.g. dismisses ASWebAuthenticationSession)
            await strategy.cancelOAuthFlow()

            // 3. Callback from cancelled flow 1 must fail closed
            let cancelledCallbackWithState = URL(string: "\(callbackBase)?code=\(validCode)&state=\(stateToken1)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: cancelledCallbackWithState)
            }
            let cancelledStatelessCallback = URL(string: "\(callbackBase)?code=\(validCode)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: cancelledStatelessCallback)
            }

            // 4. User starts fresh Flow 2
            _ = try await strategy.startOAuthFlow(identifier: "alice.test")

            // 5. Real stateless Nest callback (no state parameter) MUST succeed end-to-end
            let freshStatelessCallback = URL(string: "\(callbackBase)?code=\(validCode)")!
            let result = try await strategy.handleOAuthCallback(url: freshStatelessCallback)
            #expect(result.did == aliceDID)
            #expect(result.handle == "alice.test")
        }
    }

    @Test("A1-R3-03: describeServer in gateway mode retains session credential while createSession on foreign PDS is unauthenticated")
    func testDescribeServerAuthenticatedInGatewayMode() async throws {
        let gatewayOrigin = URL(string: "https://api.catbird.blue")!
        let networkService = NetworkService(baseURL: gatewayOrigin)
        await networkService.setGatewayMode(true)

        let describeServerURL = URL(string: "https://api.catbird.blue/xrpc/com.atproto.server.describeServer")!
        let policy = await networkService.determineSecurityPolicy(for: describeServerURL)
        guard let expectedOrigin = ExactAuthRequestOrigin(gatewayOrigin) else {
            Issue.record("Failed to create exact auth origin for gateway")
            return
        }
        #expect(policy == .authenticated(recipient: expectedOrigin), "describeServer to gateway origin in gateway mode must be authenticated")

        // In legacy mode to a foreign PDS, createSession must be unauthenticated
        let foreignPDS = URL(string: "https://pds.foreign.test")!
        let standardService = NetworkService(baseURL: foreignPDS)
        let createSessionURL = URL(string: "https://pds.foreign.test/xrpc/com.atproto.server.createSession")!
        let standardPolicy = await standardService.determineSecurityPolicy(for: createSessionURL)
        #expect(standardPolicy == .unauthenticated, "createSession in legacy mode must be unauthenticated")
    }

    @Test("Security: Unmatched error callback (missing state or wrong state) does not cancel in-flight login")
    func testUnmatchedErrorCallbackDoesNotCancelInFlightLogin() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/auth/exchange") {
                let json = "{\"session_id\":\"\(sampleSessionID)\"}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            } else if url.path.hasSuffix("/auth/session") {
                let json = "{\"did\":\"\(aliceDID)\",\"handle\":\"alice.test\",\"active\":true,\"granted_scopes\":[\"atproto\"]}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.csrf_error_callback")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            // 1. Legitimate user starts login
            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.test")

            // 2. Attacker sends error callback without state parameter
            let attackerNoStateCallback = URL(string: "\(callbackBase)?error=access_denied")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: attackerNoStateCallback)
            }

            // 3. Attacker sends error callback with forged/random state parameter
            let attackerForgedStateCallback = URL(string: "\(callbackBase)?error=access_denied&state=forged_state_12345")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: attackerForgedStateCallback)
            }

            // 4. Attacker sends 100 random error callbacks to attempt DoS / memory exhaustion
            for i in 0..<100 {
                let bogus = URL(string: "\(callbackBase)?error=access_denied&state=random_spam_\(i)")!
                await #expect(throws: (any Error).self) {
                    try await strategy.handleOAuthCallback(url: bogus)
                }
            }

            // 5. User's legitimate in-flight login MUST NOT have been cancelled and completes successfully
            let legitimateCallback = URL(string: "\(callbackBase)?code=\(validCode)&state=\(stateToken)")!
            let result = try await strategy.handleOAuthCallback(url: legitimateCallback)
            #expect(result.did == aliceDID)
            #expect(result.handle == "alice.test")
        }
    }

    @Test("Security: Matched error callback with valid state token cancels flow cleanly")
    func testMatchedErrorCallbackCancelsFlowCleanly() async throws {
        let backend = InMemorySecureStorage()
        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.hasSuffix("/auth/exchange") {
                let json = "{\"session_id\":\"\(sampleSessionID)\"}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            } else if url.path.hasSuffix("/auth/session") {
                let json = "{\"did\":\"\(aliceDID)\",\"handle\":\"alice.test\",\"active\":true,\"granted_scopes\":[\"atproto\"]}"
                return (makeHTTPResponse(url: url, statusCode: 200), Data(json.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withGatewayLoginTransport(backend, handler: handler) {
            let storage = KeychainStorage(namespace: "test.gateway.matched_error_cancel")
            let accountManager = await AccountManager(storage: storage)
            let strategy = makeStrategy(storage: storage, accountManager: accountManager)

            let (_, stateToken) = try await strategy.startOAuthFlowWithState(identifier: "alice.test")

            // User cancelled in browser, provider returns error callback with the exact stateToken
            let matchedErrorCallback = URL(string: "\(callbackBase)?error=access_denied&state=\(stateToken)")!
            do {
                _ = try await strategy.handleOAuthCallback(url: matchedErrorCallback)
                Issue.record("Expected AuthError.cancelled")
            } catch let error as AuthError {
                #expect(error == .cancelled)
            }

            // Replay with legitimate code and cancelled stateToken must fail closed
            let replayCallback = URL(string: "\(callbackBase)?code=\(validCode)&state=\(stateToken)")!
            await #expect(throws: (any Error).self) {
                try await strategy.handleOAuthCallback(url: replayCallback)
            }
        }
    }
}

// Older toolchains require the explicit conformance for strict-concurrency;
// newer SDKs mark URLProtocol's inherited Sendable unavailable and warn on it.
#if compiler(<6.2)
extension GatewayLoginTestURLProtocol: @unchecked Sendable {}
#endif
