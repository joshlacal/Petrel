import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Synchronization
import XCTest

// MARK: - Mock URLProtocol for Gateway Upgrade Tests

private final class GatewayUpgradeTestURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?
    private nonisolated(unsafe) static var requests: [URLRequest] = []

    static func reset() {
        lock.lock()
        handler = nil
        requests = []
        lock.unlock()
    }

    static func setHandler(_ newHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?) {
        lock.lock()
        handler = newHandler
        lock.unlock()
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
        GatewayUpgradeTestURLProtocol.lock.lock()
        let currentHandler = GatewayUpgradeTestURLProtocol.handler
        GatewayUpgradeTestURLProtocol.requests.append(request)
        GatewayUpgradeTestURLProtocol.lock.unlock()

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

// MARK: - Test Helpers

private func withInMemoryBackend<T>(
    _ backend: InMemorySecureStorage = InMemorySecureStorage(),
    _ body: (InMemorySecureStorage) async throws -> T
) async throws -> T {
    try await withSerializedStorageOverrideTest {
        KeychainManager._setStorageOverride(backend)
        defer { KeychainManager._setStorageOverride(nil) }
        return try await body(backend)
    }
}

private final class TestAsyncGate: @unchecked Sendable {
    private let lock = NSLock()
    private let blockingSignal = DispatchSemaphore(value: 0)
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func open() {
        lock.lock()
        isOpen = true
        let continuations = waiters
        waiters.removeAll()
        lock.unlock()
        blockingSignal.signal()
        for c in continuations {
            c.resume()
        }
    }
    func waitBlocking() {
        lock.lock()
        let alreadyOpen = isOpen
        lock.unlock()
        if !alreadyOpen {
            blockingSignal.wait()
        }
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if isOpen {
                lock.unlock()
                continuation.resume()
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }
}

// MARK: - Test Suite

final class ConfidentialGatewayScopeUpgradeTests: XCTestCase {
    private static let gatewayURL = URL(string: "https://gateway.catbird.test")!
    private static let validCallbackBase = ConfidentialGatewayStrategy.permissionCallbackURL
    private static let aliceDID = "did:plc:alice123456789012345678"
    private static let bobDID = "did:plc:bob9876543210987654321"

    private var gatewayURL: URL { Self.gatewayURL }
    private var validCallbackBase: URL { Self.validCallbackBase }
    private var aliceDID: String { Self.aliceDID }
    private var bobDID: String { Self.bobDID }

    override func setUp() {
        super.setUp()
        GatewayUpgradeTestURLProtocol.reset()
        URLProtocol.registerClass(GatewayUpgradeTestURLProtocol.self)
        NetworkService.setNetworkTestProtocolClasses([GatewayUpgradeTestURLProtocol.self])
    }

    override func tearDown() {
        URLProtocol.unregisterClass(GatewayUpgradeTestURLProtocol.self)
        NetworkService.setNetworkTestProtocolClasses(nil)
        GatewayUpgradeTestURLProtocol.reset()
        super.tearDown()
    }

    private func makeClient(
        namespace: String,
        initialSession: String = UUID().uuidString.lowercased()
    ) async throws -> (ATProtoClient, KeychainStorage) {
        let storage = KeychainStorage(namespace: namespace)
        let client = try await ATProtoClient(
            oauthConfig: OAuthConfig(
                clientId: "https://catbird.blue/oauth/client-metadata.json",
                redirectUri: "https://catbird.blue/oauth/callback",
                scope: "atproto transition:generic"
            ),
            namespace: namespace,
            authMode: .gateway,
            gatewayURL: gatewayURL
        )

        let account = Account(
            did: aliceDID,
            handle: "alice.test",
            pdsURL: gatewayURL
        )
        try await storage.saveAccount(account, for: aliceDID)
        try await storage.saveGatewaySession(initialSession, for: aliceDID)
        try await client.switchToAccount(did: aliceDID)

        return (client, storage)
    }

    // MARK: - 1. Start Scope Upgrade Tests

    func testStartUpgradeSendsCorrectWireRequestAndValidatesParameters() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.start.\(UUID().uuidString)"
            let initialSessionUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: initialSessionUUID)

            let alice = self.aliceDID

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.test",
                        "granted_scopes": ["atproto", "transition:generic"]
                    }
                    """.data(using: .utf8)!
                    return (response, body)
                } else if path == "/auth/upgrade" {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = """
                    {"authorization_url":"https://auth.pds.test/oauth/authorize?req=123"}
                    """.data(using: .utf8)!
                    return (response, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let requestedScopes: Set<String> = ["identity:handle", "account:email?action=manage"]
            let authURL = try await client.startGatewayScopeUpgrade(
                requesting: requestedScopes,
                for: self.aliceDID,
                callbackURL: self.validCallbackBase
            )

            XCTAssertEqual(authURL.absoluteString, "https://auth.pds.test/oauth/authorize?req=123")

            let reqs = GatewayUpgradeTestURLProtocol.recordedRequests()
            guard let sessionReq = reqs.first(where: { $0.url?.path == "/auth/session" }) else {
                XCTFail("No /auth/session request captured")
                return
            }
            XCTAssertEqual(sessionReq.value(forHTTPHeaderField: "Authorization"), "Bearer \(initialSessionUUID)")

            guard let req = reqs.first(where: { $0.url?.path == "/auth/upgrade" }) else {
                XCTFail("No /auth/upgrade request captured")
                return
            }

            XCTAssertEqual(req.httpMethod, "POST")
            XCTAssertEqual(req.url?.path, "/auth/upgrade")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer \(initialSessionUUID)")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let bodyData = req.httpBody ?? req.httpBodyStream.flatMap { stream in
                var data = Data()
                stream.open()
                defer { stream.close() }
                let bufferSize = 1024
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { buffer.deallocate() }
                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: bufferSize)
                    if read > 0 { data.append(buffer, count: read) } else { break }
                }
                return data
            }
            XCTAssertNotNil(bodyData)

            let bodyObj = try JSONSerialization.jsonObject(with: bodyData ?? Data()) as? [String: Any]
            let additionalScopes = bodyObj?["additional_scopes"] as? [String]
            let browserNonce = bodyObj?["browser_nonce"] as? String

            XCTAssertEqual(additionalScopes, ["account:email?action=manage", "identity:handle"], "Scopes must be sorted alphabetically")
            XCTAssertNotNil(browserNonce)
            XCTAssertEqual(browserNonce?.count, 43, "Nonce must be exactly 43 characters (32 bytes base64url unpadded)")

            // Session and current account must remain untouched
            let currentSession = try await storage.getGatewaySession(for: self.aliceDID)
            XCTAssertEqual(currentSession, initialSessionUUID)
            let currentDID = try await storage.getCurrentDID()
            XCTAssertEqual(currentDID, self.aliceDID)
        }
    }

    func testStartUpgradeRejectsInvalidScopesAndCallbacks() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.start.invalid.\(UUID().uuidString)"
            let (client, _) = try await self.makeClient(namespace: namespace)

            // 1. Empty scope set
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: [], for: self.aliceDID, callbackURL: self.validCallbackBase)
                XCTFail("Expected failure for empty scopes")
            } catch {}

            // 2. Unbounded scope set (> 16)
            let tooManyScopes = Set((0..<17).map { "scope:\($0)" })
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: tooManyScopes, for: self.aliceDID, callbackURL: self.validCallbackBase)
                XCTFail("Expected failure for >16 scopes")
            } catch {}

            // 3. Unbounded single scope (> 128 chars)
            let longScope = String(repeating: "a", count: 129)
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: [longScope], for: self.aliceDID, callbackURL: self.validCallbackBase)
                XCTFail("Expected failure for >128-char scope")
            } catch {}

            // 4. Wildcard scope
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: ["repo:*"], for: self.aliceDID, callbackURL: self.validCallbackBase)
                XCTFail("Expected failure for wildcard scope")
            } catch {}

            // 5. Whitespace scope
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle "], for: self.aliceDID, callbackURL: self.validCallbackBase)
                XCTFail("Expected failure for whitespace in scope")
            } catch {}

            // 6. Wrong active DID
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: self.bobDID, callbackURL: self.validCallbackBase)
                XCTFail("Expected failure for mismatched DID")
            } catch {}

            // 7. Insecure or malformed callback URL (http instead of https)
            let insecureCallback = URL(string: "http://catbird.blue/oauth/permission-callback")!
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: self.aliceDID, callbackURL: insecureCallback)
                XCTFail("Expected failure for insecure callback")
            } catch {}

            // 8. Loopback callback rejected
            let loopbackCallback = URL(string: "http://127.0.0.1:8080/oauth/permission-callback")!
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: self.aliceDID, callbackURL: loopbackCallback)
                XCTFail("Expected failure for loopback callback")
            } catch {}

            // 9. Wrong callback path
            let wrongPathCallback = URL(string: "https://catbird.blue/oauth/wrong-path")!
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: self.aliceDID, callbackURL: wrongPathCallback)
                XCTFail("Expected failure for wrong path callback")
            } catch {}

            // 10. Callback URL with query or fragment
            let callbackWithQuery = URL(string: "https://catbird.blue/oauth/permission-callback?foo=bar")!
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: self.aliceDID, callbackURL: callbackWithQuery)
                XCTFail("Expected failure for callback with query")
            } catch {}

            let callbackWithFragment = URL(string: "https://catbird.blue/oauth/permission-callback#fragment")!
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: self.aliceDID, callbackURL: callbackWithFragment)
                XCTFail("Expected failure for callback with fragment")
            } catch {}
        }
    }

    func testStartUpgradeThrowsWhenPriorSessionFetchFailsOrInactive() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.start.priorfail.\(UUID().uuidString)"
            let (client, _) = try await self.makeClient(namespace: namespace)

            // 1. Session fetch 401
            GatewayUpgradeTestURLProtocol.setHandler { request in
                if request.url?.path == "/auth/session" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, #"{"error":"invalid_session"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: self.aliceDID, callbackURL: self.validCallbackBase)
                XCTFail("Expected throw when /auth/session returns 401")
            } catch {}

            // 2. Session active == false
            let alice = self.aliceDID
            GatewayUpgradeTestURLProtocol.setHandler { request in
                if request.url?.path == "/auth/session" {
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.test",
                        "active": false,
                        "granted_scopes": ["atproto", "transition:generic"]
                    }
                    """.data(using: .utf8)!
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: self.aliceDID, callbackURL: self.validCallbackBase)
                XCTFail("Expected throw when /auth/session has active == false")
            } catch {}

            // 3. Session missing atproto scope
            GatewayUpgradeTestURLProtocol.setHandler { request in
                if request.url?.path == "/auth/session" {
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.test",
                        "granted_scopes": ["identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: self.aliceDID, callbackURL: self.validCallbackBase)
                XCTFail("Expected throw when /auth/session lacks atproto scope")
            } catch {}
        }
    }

    // MARK: - 2. Complete Scope Upgrade Flow Tests

    func testCompleteUpgradeSuccessFlow() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.complete.\(UUID().uuidString)"
            let initialSessionUUID = UUID().uuidString.lowercased()
            let candidateSessionUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: initialSessionUUID)

            let alice = self.aliceDID

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.test",
                        "granted_scopes": ["atproto", "transition:generic"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                } else if path == "/auth/upgrade" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=1"}"#.data(using: .utf8)!
                    return (resp, body)
                } else if path == "/auth/upgrade/exchange" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "candidate_session_id": "\(candidateSessionUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                } else if path == "/auth/upgrade/commit" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "status": "committed",
                        "session_id": "\(candidateSessionUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // Start
            _ = try await client.startGatewayScopeUpgrade(
                requesting: ["identity:handle"],
                for: self.aliceDID,
                callbackURL: self.validCallbackBase
            )

            // Complete with valid code
            let incomingCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=auth-code-12345")!
            let granted = try await client.completeGatewayScopeUpgrade(callbackURL: incomingCallback, for: self.aliceDID)

            let reqs = GatewayUpgradeTestURLProtocol.recordedRequests()
            let capturedExchangeReq = reqs.first(where: { $0.url?.path == "/auth/upgrade/exchange" })
            let capturedCommitReq = reqs.first(where: { $0.url?.path == "/auth/upgrade/commit" })

            XCTAssertNotNil(capturedExchangeReq)
            XCTAssertNotNil(capturedCommitReq)
            XCTAssertEqual(granted, ["atproto", "transition:generic", "identity:handle"])

            // Verify exchange request
            XCTAssertEqual(capturedExchangeReq?.value(forHTTPHeaderField: "Authorization"), "Bearer \(initialSessionUUID)")
            XCTAssertEqual(capturedExchangeReq?.value(forHTTPHeaderField: "Origin"), "https://catbird.blue", "Origin must be derived from fixed callback, not gateway URL")

            // Verify commit request uses candidate bearer and empty body
            XCTAssertEqual(capturedCommitReq?.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateSessionUUID)")
            XCTAssertNil(capturedCommitReq?.httpBody, "Commit request body must be empty")

            // Verify local session is now promoted
            let upgradedSession = try await storage.getGatewaySession(for: self.aliceDID)
            XCTAssertEqual(upgradedSession, candidateSessionUUID)

            // Verify pending state was deleted
            let pendingAfter = try await storage.getPendingGatewayUpgradeData(for: self.aliceDID)
            XCTAssertNil(pendingAfter)
        }
    }

    // MARK: - 3. Scope Downgrades and Exact Wire Validations

    func testExchangeAndCommitRejectScopeDowngrades() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.downgrades.\(UUID().uuidString)"
            let (client, storage) = try await self.makeClient(namespace: namespace)

            let alice = self.aliceDID
            let candidateUUID = UUID().uuidString.lowercased()

            // 1. Exchange drops requested scope
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"did":"\#(alice)","granted_scopes":["atproto","transition:generic"]}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=1"}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade/exchange" {
                    // Missing "identity:handle"
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"candidate_session_id":"\#(candidateUUID)","did":"\#(alice)","granted_scopes":["atproto","transition:generic"]}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: self.aliceDID, callbackURL: self.validCallbackBase)

            let callback = URL(string: "https://catbird.blue/oauth/permission-callback?code=code123")!
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: callback, for: self.aliceDID)
                XCTFail("Expected failure when exchange drops requested scope")
            } catch {}

            // 2. Commit drops prior scope
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/exchange" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"candidate_session_id":"\#(candidateUUID)","did":"\#(alice)","granted_scopes":["atproto","transition:generic","identity:handle"]}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade/commit" {
                    // Missing "transition:generic"
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"status":"committed","session_id":"\#(candidateUUID)","did":"\#(alice)","granted_scopes":["atproto","identity:handle"]}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: callback, for: self.aliceDID)
                XCTFail("Expected failure when commit drops prior scope")
            } catch {}

            let currentSession = try await storage.getGatewaySession(for: self.aliceDID)
            XCTAssertNotEqual(currentSession, candidateUUID)
        }
    }

    func testExchangeAndCommitRejectUnknownKeysAndAliasesAndCasing() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.strictwire.\(UUID().uuidString)"
            let (client, _) = try await self.makeClient(namespace: namespace)

            let alice = self.aliceDID
            let candidateUUID = UUID().uuidString.lowercased()

            // 1. Start response contains unknown field
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"did":"\#(alice)","granted_scopes":["atproto"]}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"authorization_url":"https://auth.pds.test/oauth/authorize","unknown_field":"rejected"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: self.aliceDID, callbackURL: self.validCallbackBase)
                XCTFail("Expected failure when start response has unknown field")
            } catch {}

            // Setup valid start
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"did":"\#(alice)","granted_scopes":["atproto"]}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"authorization_url":"https://auth.pds.test/oauth/authorize"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
            _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: self.aliceDID, callbackURL: self.validCallbackBase)

            let callback = URL(string: "https://catbird.blue/oauth/permission-callback?code=code123")!

            // 2. Exchange response with non-UUID candidate_session_id
            GatewayUpgradeTestURLProtocol.setHandler { request in
                if request.url?.path == "/auth/upgrade/exchange" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"candidate_session_id":"not-a-uuid","did":"\#(alice)","granted_scopes":["atproto","identity:handle"]}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: callback, for: self.aliceDID)
                XCTFail("Expected failure for non-UUID candidate_session_id")
            } catch {}

            // 3. Commit response with alias candidate_session_id instead of session_id
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/exchange" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"candidate_session_id":"\#(candidateUUID)","did":"\#(alice)","granted_scopes":["atproto","identity:handle"]}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade/commit" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"status":"committed","candidate_session_id":"\#(candidateUUID)","did":"\#(alice)","granted_scopes":["atproto","identity:handle"]}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: callback, for: self.aliceDID)
                XCTFail("Expected failure when commit response uses alias key")
            } catch {}

            // 4. Commit response with wrong casing "Committed"
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"status":"Committed","session_id":"\#(candidateUUID)","did":"\#(alice)","granted_scopes":["atproto","identity:handle"]}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: callback, for: self.aliceDID)
                XCTFail("Expected failure when commit status is capitalized")
            } catch {}
        }
    }

    // MARK: - 4. Durability, Retries, and Recovery

    func testCommitFailureAllowsIdempotentRetryWithoutReExchange() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.retry.\(UUID().uuidString)"
            let (client, storage) = try await self.makeClient(namespace: namespace)

            let shouldFailCommit = Mutex<Bool>(true)
            let alice = self.aliceDID
            let candidateUUID = UUID().uuidString.lowercased()

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"did":"\#(alice)","granted_scopes":["atproto","transition:generic"]}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=1"}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade/exchange" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "candidate_session_id": "\(candidateUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                } else if path == "/auth/upgrade/commit" {
                    let fail = shouldFailCommit.withLock { $0 }
                    if fail {
                        let resp = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                        return (resp, #"{"error":"service_unavailable"}"#.data(using: .utf8)!)
                    } else {
                        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                        let body = """
                        {
                            "status": "committed",
                            "session_id": "\(candidateUUID)",
                            "did": "\(alice)",
                            "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                        }
                        """.data(using: .utf8)!
                        return (resp, body)
                    }
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // Start
            _ = try await client.startGatewayScopeUpgrade(
                requesting: ["identity:handle"],
                for: self.aliceDID,
                callbackURL: self.validCallbackBase
            )

            let incomingCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=auth-code-retry-1")!

            // First attempt fails at commit
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: incomingCallback, for: self.aliceDID)
                XCTFail("Expected commit 503 failure")
            } catch {}

            let firstReqs = GatewayUpgradeTestURLProtocol.recordedRequests()
            let firstExchangeCount = firstReqs.filter({ $0.url?.path == "/auth/upgrade/exchange" }).count
            let firstCommitCount = firstReqs.filter({ $0.url?.path == "/auth/upgrade/commit" }).count
            XCTAssertEqual(firstExchangeCount, 1)
            XCTAssertEqual(firstCommitCount, 1)

            // Retry complete: must NOT call exchange again because candidate is durably saved!
            shouldFailCommit.withLock { $0 = false }
            let granted = try await client.completeGatewayScopeUpgrade(callbackURL: incomingCallback, for: self.aliceDID)

            let secondReqs = GatewayUpgradeTestURLProtocol.recordedRequests()
            let secondExchangeCount = secondReqs.filter({ $0.url?.path == "/auth/upgrade/exchange" }).count
            let secondCommitCount = secondReqs.filter({ $0.url?.path == "/auth/upgrade/commit" }).count

            XCTAssertEqual(secondExchangeCount, 1, "Exchange must not be called again on retry")
            XCTAssertEqual(secondCommitCount, 2, "Commit was retried")
            XCTAssertEqual(granted, ["atproto", "transition:generic", "identity:handle"])

            // Session promoted after commit succeeds
            let finalSession = try await storage.getGatewaySession(for: self.aliceDID)
            XCTAssertEqual(finalSession, candidateUUID)
        }
    }

    func testExchangeFailureWithInjectedStorageErrorAndIdempotentRetry() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.upgrade.storagefail.\(UUID().uuidString)"
            let (client, storage) = try await self.makeClient(namespace: namespace)

            let alice = self.aliceDID
            let oldSession = try await storage.getGatewaySession(for: alice)
            XCTAssertNotNil(oldSession)
            let candidateUUID = UUID().uuidString.lowercased()
            let exchangeCount = Mutex<Int>(0)
            let commitCount = Mutex<Int>(0)

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"did":"\#(alice)","granted_scopes":["atproto","transition:generic"]}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=1"}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade/exchange" {
                    exchangeCount.withLock { $0 += 1 }
                    // Idempotently returns SAME candidate on repeated calls with same code+nonce
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"candidate_session_id":"\#(candidateUUID)","did":"\#(alice)","granted_scopes":["atproto","transition:generic","identity:handle"]}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade/commit" {
                    commitCount.withLock { $0 += 1 }
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"status":"committed","session_id":"\#(candidateUUID)","did":"\#(alice)","granted_scopes":["atproto","transition:generic","identity:handle"]}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: self.aliceDID, callbackURL: self.validCallbackBase)

            // Inject storage failure specifically for saving pending upgrade candidate data
            let shouldFailPendingStore = Mutex<Bool>(true)
            backend.failStoreMatching = { key in
                if key.contains("pendingGatewayUpgrade") && shouldFailPendingStore.withLock({ $0 }) {
                    return true
                }
                return false
            }

            let callback = URL(string: "https://catbird.blue/oauth/permission-callback?code=code-12345")!

            // First complete attempt: exchange succeeds, but candidate persistence fails
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: callback, for: self.aliceDID)
                XCTFail("Expected completeGatewayScopeUpgrade to throw on pending-state write failure")
            } catch {}

            XCTAssertEqual(exchangeCount.withLock { $0 }, 1, "First exchange was executed")
            XCTAssertEqual(commitCount.withLock { $0 }, 0, "Commit must not be called when candidate persistence fails")

            // Read the backend directly so this proves the physical anchor survived,
            // not merely a KeychainStorage cache hit.
            let physicalSession = try backend.retrieve(
                key: "gatewaySession.\(alice)", namespace: namespace, accessGroup: nil
            )
            XCTAssertEqual(String(data: physicalSession, encoding: .utf8), oldSession)
            let sessionAfterFail = try await storage.getGatewaySession(for: self.aliceDID)
            XCTAssertEqual(sessionAfterFail, oldSession)
            // Disable failure injection for retry
            shouldFailPendingStore.withLock { $0 = false }

            // Retry complete: simulated Nest returns the SAME candidate; retry persists and commits
            let granted = try await client.completeGatewayScopeUpgrade(callbackURL: callback, for: self.aliceDID)
            XCTAssertEqual(granted, ["atproto", "transition:generic", "identity:handle"])
            XCTAssertEqual(exchangeCount.withLock { $0 }, 2, "Second exchange was executed with same candidate returned")
            XCTAssertEqual(commitCount.withLock { $0 }, 1, "Commit was executed after candidate persisted")

            let finalSession = try await storage.getGatewaySession(for: self.aliceDID)
            XCTAssertEqual(finalSession, candidateUUID)
        }
    }

    func testRelaunchRecoveryCommitsPersistedCandidateWithoutCallback() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.relaunch.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID

            // Initial client setup
            let storage1 = KeychainStorage(namespace: namespace)
            let client1 = try await ATProtoClient(
                oauthConfig: OAuthConfig(
                    clientId: "https://catbird.blue/oauth/client-metadata.json",
                    redirectUri: "https://catbird.blue/oauth/callback",
                    scope: "atproto transition:generic"
                ),
                namespace: namespace,
                authMode: .gateway,
                gatewayURL: self.gatewayURL
            )

            let account = Account(
                did: alice,
                handle: "alice.test",
                pdsURL: self.gatewayURL
            )
            try await storage1.saveAccount(account, for: alice)
            try await storage1.saveGatewaySession(oldSessionUUID, for: alice)
            try await client1.switchToAccount(did: alice)

            // Plant pending upgrade state with persisted candidate (as if exchange completed, but crashed before commit)
            let pendingState = """
            {
                "oldSession": "\(oldSessionUUID)",
                "expectedDID": "\(alice)",
                "requestedScopes": ["identity:handle"],
                "priorScopes": ["atproto", "transition:generic"],
                "browserNonce": "abcdefg123456",
                "callbackURL": "https://catbird.blue/oauth/permission-callback",
                "candidateSession": "\(candidateUUID)",
                "candidateGrantedScopes": ["atproto", "transition:generic", "identity:handle"]
            }
            """.data(using: .utf8)!
            try await storage1.savePendingGatewayUpgradeData(pendingState, for: alice)

            // Setup mock handler for commit
            let commitCount = Mutex<Int>(0)
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"did":"\#(alice)","granted_scopes":["atproto","transition:generic","identity:handle"]}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade/commit" {
                    commitCount.withLock { $0 += 1 }
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"status":"committed","session_id":"\#(candidateUUID)","did":"\#(alice)","granted_scopes":["atproto","transition:generic","identity:handle"]}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // Verify session on storage1 is still oldSessionUUID before relaunch
            let sessionBeforeRelaunch = try await storage1.getGatewaySession(for: alice)
            XCTAssertEqual(sessionBeforeRelaunch, oldSessionUUID)

            // Construct client2 (new KeychainStorage and Auth client in SAME namespace, simulating app relaunch)
            let storage2 = KeychainStorage(namespace: namespace)
            let client2 = try await ATProtoClient(
                oauthConfig: OAuthConfig(
                    clientId: "https://catbird.blue/oauth/client-metadata.json",
                    redirectUri: "https://catbird.blue/oauth/callback",
                    scope: "atproto transition:generic"
                ),
                namespace: namespace,
                authMode: .gateway,
                gatewayURL: self.gatewayURL
            )

            // Recovery runs automatically on client startup via refreshTokenIfNeeded, or can be explicitly driven
            // Relaunch committed the persisted candidate with zero callbackURL passed
            XCTAssertEqual(commitCount.withLock { $0 }, 1, "Recovery committed the persisted candidate")

            // Session has been promoted to candidate
            let sessionAfterRecovery = try await storage2.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterRecovery, candidateUUID)

            let scopes = try await client2.fetchGrantedScopes(for: alice)
            XCTAssertEqual(scopes, ["atproto", "transition:generic", "identity:handle"])

            // Pending state cleaned up
            let pendingAfter = try await storage2.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNil(pendingAfter)

            // DID and account preserved
            let currentDID = try await storage2.getCurrentDID()
            XCTAssertEqual(currentDID, alice)
            let currentAccount = await client2.getCurrentAccount()
            XCTAssertEqual(currentAccount?.did, alice)
        }
    }

    func testRecoveryWhenLocalSessionAlreadyCandidate() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.alreadypromoted.\(UUID().uuidString)"
            let candidateUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: candidateUUID)

            // Plant pending upgrade data with candidateSession already equal to current session
            let pendingState = """
            {
                "oldSession": "old-session-uuid",
                "expectedDID": "\(self.aliceDID)",
                "requestedScopes": ["identity:handle"],
                "priorScopes": ["atproto"],
                "browserNonce": "abcdefg",
                "callbackURL": "https://catbird.blue/oauth/permission-callback",
                "candidateSession": "\(candidateUUID)",
                "candidateGrantedScopes": ["atproto", "identity:handle"]
            }
            """.data(using: .utf8)!
            try await storage.savePendingGatewayUpgradeData(pendingState, for: self.aliceDID)

            let callback = URL(string: "https://catbird.blue/oauth/permission-callback?code=irrelevant")!
            let granted = try await client.completeGatewayScopeUpgrade(callbackURL: callback, for: self.aliceDID)

            XCTAssertEqual(granted, ["atproto", "identity:handle"])

            // Pending state cleaned up
            let pendingAfter = try await storage.getPendingGatewayUpgradeData(for: self.aliceDID)
            XCTAssertNil(pendingAfter)
        }
    }

    func testStartAndFetchScopeUpgradeRejectWhenCandidateRecoveryFailsAndPreserveOldState() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.candidate.fail.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: oldSessionUUID)
            let alice = self.aliceDID

            // Plant pending upgrade state with persisted candidate (as if exchange completed, but commit failed)
            let pendingState = """
            {
                "oldSession": "\(oldSessionUUID)",
                "expectedDID": "\(alice)",
                "requestedScopes": ["identity:handle"],
                "priorScopes": ["atproto", "transition:generic"],
                "browserNonce": "browser-nonce-12345",
                "callbackURL": "https://catbird.blue/oauth/permission-callback",
                "candidateSession": "\(candidateUUID)",
                "candidateGrantedScopes": ["atproto", "transition:generic", "identity:handle"]
            }
            """.data(using: .utf8)!
            try await storage.savePendingGatewayUpgradeData(pendingState, for: alice)

            // Configure recovery failure: commit returns 503
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"error":"service_unavailable"}"#.data(using: .utf8)!)
                }
                // Disallow any /auth/session or /auth/upgrade request using old bearer
                if request.value(forHTTPHeaderField: "Authorization") == "Bearer \(oldSessionUUID)" {
                    XCTFail("Must not emit request using old bearer: \(path)")
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // 1. startGatewayScopeUpgrade must throw, emit no /auth/upgrade with old bearer, and preserve old+pending
            do {
                _ = try await client.startGatewayScopeUpgrade(
                    requesting: ["identity:handle"],
                    for: alice,
                    callbackURL: self.validCallbackBase
                )
                XCTFail("Expected startGatewayScopeUpgrade to throw when candidate recovery fails")
            } catch {}

            let reqsAfterStart = GatewayUpgradeTestURLProtocol.recordedRequests()
            let upgradeReqsWithOldBearer = reqsAfterStart.filter { req in
                req.url?.path == "/auth/upgrade" && req.value(forHTTPHeaderField: "Authorization") == "Bearer \(oldSessionUUID)"
            }
            XCTAssertTrue(upgradeReqsWithOldBearer.isEmpty, "No /auth/upgrade request using old bearer must be emitted")

            let sessionAfterStartFail = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterStartFail, oldSessionUUID, "Old session must remain intact in keychain")
            let pendingAfterStartFail = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfterStartFail, "Pending upgrade state must remain intact in keychain")

            // 2. fetchGrantedScopes must throw, emit no /auth/session with old bearer, and preserve old+pending
            do {
                _ = try await client.fetchGrantedScopes(for: alice)
                XCTFail("Expected fetchGrantedScopes to throw when candidate recovery fails")
            } catch {}

            let reqsAfterFetch = GatewayUpgradeTestURLProtocol.recordedRequests()
            let sessionReqsWithOldBearer = reqsAfterFetch.filter { req in
                req.url?.path == "/auth/session" && req.value(forHTTPHeaderField: "Authorization") == "Bearer \(oldSessionUUID)"
            }
            XCTAssertTrue(sessionReqsWithOldBearer.isEmpty, "No /auth/session request using old bearer must be emitted")

            let sessionAfterFetchFail = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterFetchFail, oldSessionUUID, "Old session must remain intact in keychain")
            let pendingAfterFetchFail = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfterFetchFail, "Pending upgrade state must remain intact in keychain")
        }
    }

    func testStartAndFetchScopeUpgradeRecoverCandidateOnIdempotentCommitSuccess() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.candidate.success.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: oldSessionUUID)
            let alice = self.aliceDID

            // Plant pending upgrade state with persisted candidate
            let pendingState = """
            {
                "oldSession": "\(oldSessionUUID)",
                "expectedDID": "\(alice)",
                "requestedScopes": ["identity:handle"],
                "priorScopes": ["atproto", "transition:generic"],
                "browserNonce": "browser-nonce-12345",
                "callbackURL": "https://catbird.blue/oauth/permission-callback",
                "candidateSession": "\(candidateUUID)",
                "candidateGrantedScopes": ["atproto", "transition:generic", "identity:handle"]
            }
            """.data(using: .utf8)!
            try await storage.savePendingGatewayUpgradeData(pendingState, for: alice)

            // Configure idempotent commit success
            let commitCount = Mutex<Int>(0)
            let sessionCount = Mutex<Int>(0)
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    commitCount.withLock { $0 += 1 }
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "status": "committed",
                        "session_id": "\(candidateUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                } else if path == "/auth/session" {
                    sessionCount.withLock { $0 += 1 }
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)", "Session info must use candidate bearer")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.test",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                }
                if request.value(forHTTPHeaderField: "Authorization") == "Bearer \(oldSessionUUID)" {
                    XCTFail("Must not emit request using old bearer: \(path)")
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // 1. fetchGrantedScopes first recovers candidate, then queries /auth/session with candidate bearer
            let scopes = try await client.fetchGrantedScopes(for: alice)
            XCTAssertEqual(scopes, ["atproto", "transition:generic", "identity:handle"])
            XCTAssertEqual(commitCount.withLock { $0 }, 1, "Candidate was committed")
            XCTAssertEqual(sessionCount.withLock { $0 }, 1, "Session was fetched with candidate bearer")

            let sessionAfterFetch = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterFetch, candidateUUID, "Session promoted to candidate")
            let pendingAfterFetch = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNil(pendingAfterFetch, "Pending candidate state cleaned up")

            // 2. Now start a new upgrade: uses candidate session as the base and creates new pending state
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.test",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                } else if path == "/auth/upgrade" {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)", "Upgrade request must use candidate bearer")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=new"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let authURL = try await client.startGatewayScopeUpgrade(
                requesting: ["account:email"],
                for: alice,
                callbackURL: self.validCallbackBase
            )
            XCTAssertEqual(authURL.absoluteString, "https://auth.pds.test/oauth/authorize?req=new")

            let newPendingData = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(newPendingData)
            let newPendingObj = try JSONSerialization.jsonObject(with: newPendingData!) as? [String: Any]
            XCTAssertEqual(newPendingObj?["oldSession"] as? String, candidateUUID, "New pending state has candidate as oldSession")
            XCTAssertNil(newPendingObj?["candidateSession"], "New pending state has nil candidateSession")
        }
    }

    func testStartScopeUpgradeDirectlyRecoversCandidateBeforeStartingNewUpgrade() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.start.recovers.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: oldSessionUUID)
            let alice = self.aliceDID

            // Plant pending upgrade state with persisted candidate
            let pendingState = """
            {
                "oldSession": "\(oldSessionUUID)",
                "expectedDID": "\(alice)",
                "requestedScopes": ["identity:handle"],
                "priorScopes": ["atproto", "transition:generic"],
                "browserNonce": "browser-nonce-12345",
                "callbackURL": "https://catbird.blue/oauth/permission-callback",
                "candidateSession": "\(candidateUUID)",
                "candidateGrantedScopes": ["atproto", "transition:generic", "identity:handle"]
            }
            """.data(using: .utf8)!
            try await storage.savePendingGatewayUpgradeData(pendingState, for: alice)

            let commitCount = Mutex<Int>(0)
            let sessionCount = Mutex<Int>(0)
            let upgradeCount = Mutex<Int>(0)

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    commitCount.withLock { $0 += 1 }
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "status": "committed",
                        "session_id": "\(candidateUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                } else if path == "/auth/session" {
                    sessionCount.withLock { $0 += 1 }
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.test",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                } else if path == "/auth/upgrade" {
                    upgradeCount.withLock { $0 += 1 }
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=recovered"}"#.data(using: .utf8)!)
                }
                if request.value(forHTTPHeaderField: "Authorization") == "Bearer \(oldSessionUUID)" {
                    XCTFail("Must not emit request using old bearer: \(path)")
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let authURL = try await client.startGatewayScopeUpgrade(
                requesting: ["account:email"],
                for: alice,
                callbackURL: self.validCallbackBase
            )
            XCTAssertEqual(authURL.absoluteString, "https://auth.pds.test/oauth/authorize?req=recovered")
            XCTAssertEqual(commitCount.withLock { $0 }, 1, "Candidate committed during startGatewayScopeUpgrade recovery")
            XCTAssertEqual(sessionCount.withLock { $0 }, 1, "Session queried using candidate bearer")
            XCTAssertEqual(upgradeCount.withLock { $0 }, 1, "Upgrade initiated using candidate bearer")

            let sessionAfterStart = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterStart, candidateUUID)

            let newPendingData = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(newPendingData)
            let newPendingObj = try JSONSerialization.jsonObject(with: newPendingData!) as? [String: Any]
            XCTAssertEqual(newPendingObj?["oldSession"] as? String, candidateUUID)
            XCTAssertNil(newPendingObj?["candidateSession"])
        }
    }

    func testStartScopeUpgradeFailsWhenPreCandidatePendingUpgradeInProgress() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.start.precandidate.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: oldSessionUUID)
            let alice = self.aliceDID

            // Plant pre-candidate pending upgrade state (browser flow in progress)
            let pendingState = """
            {
                "oldSession": "\(oldSessionUUID)",
                "expectedDID": "\(alice)",
                "requestedScopes": ["identity:handle"],
                "priorScopes": ["atproto", "transition:generic"],
                "browserNonce": "browser-nonce-12345",
                "callbackURL": "https://catbird.blue/oauth/permission-callback",
                "candidateSession": null,
                "candidateGrantedScopes": null
            }
            """.data(using: .utf8)!
            try await storage.savePendingGatewayUpgradeData(pendingState, for: alice)

            // 1. Calling startGatewayScopeUpgrade while pre-candidate pending exists must fail without overwriting
            do {
                _ = try await client.startGatewayScopeUpgrade(
                    requesting: ["account:email"],
                    for: alice,
                    callbackURL: self.validCallbackBase
                )
                XCTFail("Expected startGatewayScopeUpgrade to fail when pending upgrade is already in progress")
            } catch {}

            let reqs = GatewayUpgradeTestURLProtocol.recordedRequests()
            XCTAssertTrue(reqs.filter({ $0.url?.path == "/auth/upgrade" }).isEmpty, "No /auth/upgrade request sent")

            let pendingAfterStartFail = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertEqual(pendingAfterStartFail, pendingState, "Pending data must not be overwritten")

            // 2. Calling fetchGrantedScopes while pre-candidate pending exists still queries current authoritative grants without mutating state
            GatewayUpgradeTestURLProtocol.setHandler { request in
                if request.url?.path == "/auth/session" {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(oldSessionUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.test",
                        "granted_scopes": ["atproto", "transition:generic"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let scopes = try await client.fetchGrantedScopes(for: alice)
            XCTAssertEqual(scopes, ["atproto", "transition:generic"])

            let pendingAfterFetch = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertEqual(pendingAfterFetch, pendingState, "Pending data must remain untouched")
        }
    }

    // MARK: - 5. Cancellation, Denial, and Fail-Closed Tests

    func testCancellationAndCallbackErrorsFailClosed() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.errors.\(UUID().uuidString)"
            let (client, storage) = try await self.makeClient(namespace: namespace)

            let alice = self.aliceDID

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"did":"\#(alice)","granted_scopes":["atproto"]}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=1"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            _ = try await client.startGatewayScopeUpgrade(
                requesting: ["identity:handle"],
                for: self.aliceDID,
                callbackURL: self.validCallbackBase
            )

            // 1. User denied/cancelled callback
            let denialCallback = URL(string: "https://catbird.blue/oauth/permission-callback?error=access_denied&error_description=User+denied")!
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: denialCallback, for: self.aliceDID)
                XCTFail("Expected error for access_denied callback")
            } catch {}

            // Restart upgrade for subsequent validation tests
            _ = try await client.startGatewayScopeUpgrade(
                requesting: ["identity:handle"],
                for: self.aliceDID,
                callbackURL: self.validCallbackBase
            )

            // 2. Callback base URL mismatch (different host)
            let mismatchCallback = URL(string: "https://evil.attacker.test/oauth/permission-callback?code=12345")!
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: mismatchCallback, for: self.aliceDID)
                XCTFail("Expected error for mismatched callback host")
            } catch {}

            // 3. Callback code length unbounded (> 512 chars)
            let longCode = String(repeating: "c", count: 513)
            let unboundedCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=\(longCode)")!
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: unboundedCallback, for: self.aliceDID)
                XCTFail("Expected error for unbounded code")
            } catch {}

            // 4. Callback with extra query parameters
            let extraQueryCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=12345&extra=bad")!
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: extraQueryCallback, for: self.aliceDID)
                XCTFail("Expected error for extra query parameters")
            } catch {}
            // Session must remain untouched
            let currentDID = try await storage.getCurrentDID()
            XCTAssertEqual(currentDID, self.aliceDID)
        }
    }
    func testDeniedCallbackDeletesPreCandidateSessionUnchangedAndAllowsRestart() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.denied.restart.\(UUID().uuidString)"
            let initialSession = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: initialSession)

            let alice = self.aliceDID

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"did":"\#(alice)","granted_scopes":["atproto"]}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=1"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // Start upgrade creates pre-candidate state
            _ = try await client.startGatewayScopeUpgrade(
                requesting: ["identity:handle"],
                for: self.aliceDID,
                callbackURL: self.validCallbackBase
            )

            let pendingDataBefore = try await storage.getPendingGatewayUpgradeData(for: self.aliceDID)
            XCTAssertNotNil(pendingDataBefore, "Pending upgrade state should exist after start")

            // Complete with exact ?error=access_denied
            let denialCallback = URL(string: "https://catbird.blue/oauth/permission-callback?error=access_denied&error_description=User+denied")!
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: denialCallback, for: self.aliceDID)
                XCTFail("Expected AuthError.cancelled for access_denied callback")
            } catch let error as AuthError {
                guard case .cancelled = error else {
                    XCTFail("Expected AuthError.cancelled, got: \(error)")
                    return
                }
            } catch {
                XCTFail("Expected AuthError.cancelled, got other error: \(error)")
            }

            // Pre-candidate pending data must be deleted
            let pendingDataAfter = try await storage.getPendingGatewayUpgradeData(for: self.aliceDID)
            XCTAssertNil(pendingDataAfter, "Pending upgrade state must be deleted on denied callback")

            // Old session, current account, current DID must remain unchanged
            let currentSession = try await storage.getGatewaySession(for: self.aliceDID)
            XCTAssertEqual(currentSession, initialSession, "Old session must remain unchanged")
            let currentDID = try await storage.getCurrentDID()
            XCTAssertEqual(currentDID, self.aliceDID)
            let currentAccount = try await storage.getAccount(for: self.aliceDID)
            XCTAssertEqual(currentAccount?.did, self.aliceDID)

            // Subsequent start succeeds and creates new state
            _ = try await client.startGatewayScopeUpgrade(
                requesting: ["identity:handle"],
                for: self.aliceDID,
                callbackURL: self.validCallbackBase
            )

            let newPendingData = try await storage.getPendingGatewayUpgradeData(for: self.aliceDID)
            XCTAssertNotNil(newPendingData, "New pending upgrade state should exist after restart")
            XCTAssertNotEqual(pendingDataBefore, newPendingData, "New pending state must be distinct from prior state")
        }
    }

    func testCancelOAuthFlowClearsPreCandidateSessionUnchangedAndAllowsRestart() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.cancel.restart.\(UUID().uuidString)"
            let initialSession = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: initialSession)

            let alice = self.aliceDID

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"did":"\#(alice)","granted_scopes":["atproto"]}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=1"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // Start upgrade creates pre-candidate state
            _ = try await client.startGatewayScopeUpgrade(
                requesting: ["identity:handle"],
                for: self.aliceDID,
                callbackURL: self.validCallbackBase
            )

            let pendingDataBefore = try await storage.getPendingGatewayUpgradeData(for: self.aliceDID)
            XCTAssertNotNil(pendingDataBefore)

            // Cancel OAuth flow
            await client.cancelOAuthFlow()

            // Pre-candidate pending data must be deleted
            let pendingDataAfter = try await storage.getPendingGatewayUpgradeData(for: self.aliceDID)
            XCTAssertNil(pendingDataAfter, "Pending upgrade state must be cleared by cancelOAuthFlow")

            // Old session, account, and DID unchanged
            let currentSession = try await storage.getGatewaySession(for: self.aliceDID)
            XCTAssertEqual(currentSession, initialSession)
            let currentDID = try await storage.getCurrentDID()
            XCTAssertEqual(currentDID, self.aliceDID)

            // Subsequent start succeeds and creates new state
            _ = try await client.startGatewayScopeUpgrade(
                requesting: ["identity:handle"],
                for: self.aliceDID,
                callbackURL: self.validCallbackBase
            )

            let newPendingData = try await storage.getPendingGatewayUpgradeData(for: self.aliceDID)
            XCTAssertNotNil(newPendingData)
        }
    }

    func testCandidateStateSurvivesCancelAndPermitsRecovery() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.candidate.survives.\(UUID().uuidString)"
            let oldSession = UUID().uuidString.lowercased()
            let candidateSession = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: oldSession)
            let alice = self.aliceDID

            // Seed candidate-bearing pending upgrade state
            let pendingState = """
            {
                "oldSession": "\(oldSession)",
                "expectedDID": "\(alice)",
                "requestedScopes": ["identity:handle"],
                "priorScopes": ["atproto"],
                "browserNonce": "test_nonce_1234567890123456789012",
                "callbackURL": "https://catbird.blue/oauth/permission-callback",
                "candidateSession": "\(candidateSession)",
                "candidateGrantedScopes": ["atproto", "identity:handle"]
            }
            """.data(using: .utf8)!
            try await storage.savePendingGatewayUpgradeData(pendingState, for: alice)

            // Call cancelOAuthFlow
            await client.cancelOAuthFlow()

            // Candidate state must survive cancellation
            let pendingDataAfter = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingDataAfter, "Candidate-bearing state must not be deleted by cancelOAuthFlow")

            // Verify sessions/accounts unchanged
            let currentSession = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(currentSession, oldSession)
            let currentDID = try await storage.getCurrentDID()
            XCTAssertEqual(currentDID, alice)
        }
    }

    func testCancelOAuthFlowWithMalformedOrMismatchedStateFailsSafely() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.cancel.safe.\(UUID().uuidString)"
            let initialSession = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: initialSession)
            let alice = self.aliceDID
            let bob = self.bobDID

            // 1. Malformed pending data in storage
            let malformedData = "not-valid-json".data(using: .utf8)!
            try await storage.savePendingGatewayUpgradeData(malformedData, for: alice)

            await client.cancelOAuthFlow()

            // State retained, no crash, session unchanged
            let storedData = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertEqual(storedData, malformedData, "Malformed state must be retained")
            let currentSession = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(currentSession, initialSession)

            // 2. Mismatched DID in pending state
            let mismatchedData = """
            {
                "oldSession": "\(initialSession)",
                "expectedDID": "\(bob)",
                "requestedScopes": ["identity:handle"],
                "priorScopes": ["atproto"],
                "browserNonce": "test_nonce_1234567890123456789012",
                "callbackURL": "https://catbird.blue/oauth/permission-callback",
                "candidateSession": null,
                "candidateGrantedScopes": null
            }
            """.data(using: .utf8)!
            try await storage.savePendingGatewayUpgradeData(mismatchedData, for: alice)

            await client.cancelOAuthFlow()

            let storedMismatched = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertEqual(storedMismatched, mismatchedData, "Mismatched DID state must be retained")
            let currentSession2 = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(currentSession2, initialSession)
        }
    }

    func testDeniedCallbackPropagatesStorageDeletionError() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.upgrade.storagefail.denial.\(UUID().uuidString)"
            let initialSession = UUID().uuidString.lowercased()
            let (client, _) = try await self.makeClient(namespace: namespace, initialSession: initialSession)
            let alice = self.aliceDID

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"did":"\#(alice)","granted_scopes":["atproto"]}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=1"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            _ = try await client.startGatewayScopeUpgrade(
                requesting: ["identity:handle"],
                for: self.aliceDID,
                callbackURL: self.validCallbackBase
            )

            // Inject storage failure on delete
            backend.failDeleteMatching = { key in key.contains("pendingGatewayUpgrade") }

            let denialCallback = URL(string: "https://catbird.blue/oauth/permission-callback?error=access_denied&error_description=User+denied")!
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: denialCallback, for: self.aliceDID)
                XCTFail("Expected storage error, not success")
            } catch let error as AuthError {
                if case .cancelled = error {
                    XCTFail("Should not return AuthError.cancelled when storage deletion failed")
                }
            } catch {
                // Storage error expected and properly propagated
            }
        }
    }

    func testCompleteThrowsWhenActiveDIDOrKeychainDIDMismatchOrNil() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.mismatch.\(UUID().uuidString)"
            let (client, storage) = try await self.makeClient(namespace: namespace)

            let callback = URL(string: "https://catbird.blue/oauth/permission-callback?code=12345")!

            // 1. Mismatched expected DID vs active account
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: callback, for: self.bobDID)
                XCTFail("Expected error for mismatched expected DID")
            } catch {}

            // 2. Switched active account to Bob while expected DID is Alice
            let bobAccount = Account(did: self.bobDID, handle: "bob.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(bobAccount, for: self.bobDID)
            try await storage.saveGatewaySession(UUID().uuidString.lowercased(), for: self.bobDID)
            try await client.switchToAccount(did: self.bobDID)
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: callback, for: self.aliceDID)
                XCTFail("Expected error when active account is Bob but expected DID is Alice")
            } catch {}

            // 3. Keychain current DID deleted
            try await storage.deleteCurrentDID()
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: callback, for: self.bobDID)
                XCTFail("Expected error when keychain current DID is nil")
            } catch {}
        }
    }

    // MARK: - 6. Concurrent CAS and Non-Reentrancy Tests

    func testConcurrentCASAndSelectorMismatch() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.concurrentcas.\(UUID().uuidString)"
            let storage = KeychainStorage(namespace: namespace)
            let initialSession = UUID().uuidString.lowercased()
            let alice = self.aliceDID

            try await storage.saveCurrentDID(alice)
            try await storage.saveGatewaySession(initialSession, for: alice)

            let newSessionA = UUID().uuidString.lowercased()
            let newSessionB = UUID().uuidString.lowercased()

            // Run two concurrent CAS operations with the same expectedOldSession
            async let taskA = storage.compareAndSwapGatewaySession(
                expectedOldSession: initialSession,
                newSession: newSessionA,
                for: alice
            )
            async let taskB = storage.compareAndSwapGatewaySession(
                expectedOldSession: initialSession,
                newSession: newSessionB,
                for: alice
            )

            let (resultA, resultB) = try await (taskA, taskB)

            // Exactly ONE must succeed and the other must fail
            XCTAssertTrue((resultA && !resultB) || (!resultA && resultB), "Exactly one concurrent CAS must succeed")

            let finalSession = try await storage.getGatewaySession(for: alice)
            if resultA {
                XCTAssertEqual(finalSession, newSessionA)
            } else {
                XCTAssertEqual(finalSession, newSessionB)
            }

            // Mismatched expectedOldSession must fail
            let mismatchResult = try await storage.compareAndSwapGatewaySession(
                expectedOldSession: "wrong-old-session",
                newSession: UUID().uuidString.lowercased(),
                for: alice
            )
            XCTAssertFalse(mismatchResult)

            // Mismatched / nil current DID must fail
            try await storage.saveCurrentDID(self.bobDID)
            let wrongDIDResult = try await storage.compareAndSwapGatewaySession(
                expectedOldSession: finalSession!,
                newSession: UUID().uuidString.lowercased(),
                for: alice
            )
            XCTAssertFalse(wrongDIDResult)
        }
    }
    func testLateCallbackWhenActiveSessionChangedFailsBeforeNetwork() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.latesession.\(UUID().uuidString)"
            let initialSession = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: initialSession)

            let alice = self.aliceDID

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, """
                    {
                        "did": "\(alice)",
                        "handle": "alice.test",
                        "granted_scopes": ["atproto", "transition:generic"]
                    }
                    """.data(using: .utf8)!)
                } else if path == "/auth/upgrade" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"authorization_url":"https://catbird.blue/auth/authorize?req=1"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }

            _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: self.aliceDID)

            // Simulate user logging in again or rotating to a third session
            let thirdSession = UUID().uuidString.lowercased()
            try await storage.saveGatewaySession(thirdSession, for: self.aliceDID)

            // Reset recorded network requests and set handler that fails if network is hit
            GatewayUpgradeTestURLProtocol.reset()
            GatewayUpgradeTestURLProtocol.setHandler { request in
                XCTFail("No network requests should be made when current session is a third session: \(request.url?.path ?? "")")
                return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }

            let callback = URL(string: "https://catbird.blue/oauth/permission-callback?code=late-code-12345")!
            do {
                _ = try await client.completeGatewayScopeUpgrade(callbackURL: callback, for: self.aliceDID)
                XCTFail("Expected completeGatewayScopeUpgrade to fail before network when session has changed")
            } catch {
                // Expected failure
            }

            let reqs = GatewayUpgradeTestURLProtocol.recordedRequests()
            XCTAssertEqual(reqs.count, 0, "Zero exchange/commit network requests must be made on late callback with third session")

            let currentSession = try await storage.getGatewaySession(for: self.aliceDID)
            XCTAssertEqual(currentSession, thirdSession)
        }
    }

    func testTwoStorageInstancesSameNamespaceConcurrentCAS() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.twostorage.cas.\(UUID().uuidString)"
            let storage1 = KeychainStorage(namespace: namespace)
            let storage2 = KeychainStorage(namespace: namespace)
            let initialSession = UUID().uuidString.lowercased()
            let alice = self.aliceDID

            try await storage1.saveCurrentDID(alice)
            try await storage1.saveGatewaySession(initialSession, for: alice)

            let candidateA = UUID().uuidString.lowercased()
            let candidateB = UUID().uuidString.lowercased()

            async let taskA = storage1.compareAndSwapGatewaySession(
                expectedOldSession: initialSession,
                newSession: candidateA,
                for: alice
            )
            async let taskB = storage2.compareAndSwapGatewaySession(
                expectedOldSession: initialSession,
                newSession: candidateB,
                for: alice
            )

            let (resultA, resultB) = try await (taskA, taskB)

            XCTAssertTrue((resultA && !resultB) || (!resultA && resultB), "Across two storage instances, exactly one CAS must succeed")

            let finalSession1 = try await storage1.getGatewaySession(for: alice)
            let finalSession2 = try await storage2.getGatewaySession(for: alice)
            XCTAssertEqual(finalSession1, finalSession2)
            if resultA {
                XCTAssertEqual(finalSession1, candidateA)
            } else {
                XCTAssertEqual(finalSession1, candidateB)
            }
        }
    }

    func testCompareAndSwapWithLegacyOnlySessionDoesNotDeadlockOrMigrate() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.cas.legacyonly.\(UUID().uuidString)"
            let storage = KeychainStorage(namespace: namespace)
            let alice = self.aliceDID
            let legacySession = "legacy-session-value-12345"

            // Install eligible legacy source and current DID, but NO per-DID key
            try await storage.saveCurrentDID(alice)
            backend.plant(key: "gatewaySession", namespace: namespace, data: Data(legacySession.utf8))
            KeychainManager.clearCache()

            // Run CAS under timeout
            let newSession = UUID().uuidString.lowercased()
            let casTask = Task {
                try await storage.compareAndSwapGatewaySession(
                    expectedOldSession: legacySession,
                    newSession: newSession,
                    for: alice
                )
            }

            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                casTask.cancel()
            }

            let casResult = try await casTask.value
            timeoutTask.cancel()

            // CAS must return false promptly
            XCTAssertFalse(casResult, "CAS must return false when no exact per-DID session is present")

            // Must NOT alter or delete legacy source
            let legacyDataInBackend = backend.peek(key: "gatewaySession", namespace: namespace)
            XCTAssertEqual(legacyDataInBackend, Data(legacySession.utf8), "Legacy session must remain unaltered")

            // Must NOT have migrated to per-DID key
            let perDIDKeyInBackend = backend.peek(key: "gatewaySession.\(alice)", namespace: namespace)
            XCTAssertNil(perDIDKeyInBackend, "CAS must not migrate legacy session to per-DID key")

            // Subsequent normal getGatewaySession CAN still migrate the legacy session
            let migratedSession = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(migratedSession, legacySession)
        }
    }

    func testTwoStorageInstancesConcurrentDeleteAndSaveSerialized() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.twostorage.deletesave.\(UUID().uuidString)"
            let storage1 = KeychainStorage(namespace: namespace)
            let storage2 = KeychainStorage(namespace: namespace)
            let alice = self.aliceDID
            let initialSession = UUID().uuidString.lowercased()

            try await storage1.saveCurrentDID(alice)
            try await storage1.saveGatewaySession(initialSession, for: alice)

            let deleteStarted = TestAsyncGate()
            let saveCanProceed = TestAsyncGate()

            backend.beforeDelete = { key in
                if key.contains("gatewaySession") {
                    deleteStarted.open()
                }
            }

            let newSession = UUID().uuidString.lowercased()

            async let deleteTask: Void = {
                try await storage1.deleteGatewaySession(for: alice)
                saveCanProceed.open()
            }()

            async let saveTask: Void = {
                await deleteStarted.wait()
                await saveCanProceed.wait()
                try await storage2.saveGatewaySession(newSession, for: alice)
            }()


            _ = try await (deleteTask, saveTask)

            let session1 = try await storage1.getGatewaySession(for: alice)
            let session2 = try await storage2.getGatewaySession(for: alice)
            XCTAssertEqual(session1, newSession)
            XCTAssertEqual(session2, newSession)
        }
    }

    func testGatewayCASSelectorLinearization() async throws {
        try await withInMemoryBackend { backend in
            for iteration in 0..<50 {
                let namespace = "test.gateway.linearization.\(iteration).\(UUID().uuidString)"
                let storageA = KeychainStorage(namespace: namespace)
                let storageB = KeychainStorage(namespace: namespace)
                let alice = self.aliceDID
                let bob = self.bobDID
                let oldSession = UUID().uuidString.lowercased()
                let candidateSession = UUID().uuidString.lowercased()
                try await storageA.saveCurrentDID(alice)
                try await storageA.saveGatewaySession(oldSession, for: alice)
                let candidateStarted = Mutex<Int>(0)
                let selectorStarted = Mutex<Int>(0)
                let candidateEntered = TestAsyncGate()
                let candidateRelease = TestAsyncGate()
                backend.beforeStore = { key in
                    if key == "gatewaySession.\(alice)" {
                        candidateStarted.withLock { $0 += 1 }
                        candidateEntered.open()
                        candidateRelease.waitBlocking()
                    } else if key == "currentDID" {
                        selectorStarted.withLock { $0 += 1 }
                    }
                }
                defer {
                    backend.beforeStore = nil
                    backend.beforeDelete = nil
                    candidateRelease.open()
                }

                let casStarted = TestAsyncGate()
                let casTask = Task {
                    casStarted.open()
                    return try await storageA.compareAndSwapGatewaySession(
                        expectedOldSession: oldSession, newSession: candidateSession, for: alice)
                }
                await casStarted.wait()
                await candidateEntered.wait()
                let selectorTask = Task {
                    try await storageB.saveCurrentDID(bob)
                }
                XCTAssertEqual(selectorStarted.withLock { $0 }, 0)
                candidateRelease.open()
                let casResult = try await casTask.value
                XCTAssertTrue(casResult)
                try await selectorTask.value
                let currentDID = try await storageB.getCurrentDID()
                let promotedSession = try await storageA.getGatewaySession(for: alice)
                XCTAssertEqual(currentDID, bob)
                backend.beforeStore = nil
                backend.beforeDelete = nil
                try await storageB.saveCurrentDID(alice)
                try await storageB.saveGatewaySession(oldSession, for: alice)
                XCTAssertEqual(promotedSession, candidateSession)

                try await storageB.saveCurrentDID(alice)
                let selectorRelease = TestAsyncGate()
                let selectorEntered = TestAsyncGate()
                let candidateStarted2 = Mutex<Int>(0)
                backend.beforeStore = { key in
                    if key == "gatewaySession.\(alice)" {
                        candidateStarted2.withLock { $0 += 1 }
                    } else if key == "currentDID" {
                        selectorEntered.open()
                        selectorRelease.waitBlocking()
                    }
                }
                let selectorTask2 = Task {
                    try await storageB.saveCurrentDID(bob)
                }
                await selectorEntered.wait()
                let casStarted2 = TestAsyncGate()
                let casTask2 = Task {
                    casStarted2.open()
                    return try await storageA.compareAndSwapGatewaySession(
                        expectedOldSession: oldSession, newSession: candidateSession, for: alice)
                }
                await casStarted2.wait()
                XCTAssertEqual(candidateStarted2.withLock { $0 }, 0)
                selectorRelease.open()
                try await selectorTask2.value
                let casResult2 = try await casTask2.value
                let sessionAfterSelector = try await storageA.getGatewaySession(for: alice)
                XCTAssertFalse(casResult2)
                XCTAssertEqual(sessionAfterSelector, oldSession)

                // Re-establish Alice before proving delete-first ordering.
                try await storageB.saveCurrentDID(alice)
                try await storageB.saveGatewaySession(oldSession, for: alice)

                let deleteEntered = TestAsyncGate()
                let deleteRelease = TestAsyncGate()
                let candidateStarted3 = Mutex<Int>(0)
                backend.beforeStore = { key in
                    if key == "gatewaySession.\(alice)" {
                        candidateStarted3.withLock { $0 += 1 }
                    }
                }
                backend.beforeDelete = { key in
                    if key == "currentDID" {
                        deleteEntered.open()
                        deleteRelease.waitBlocking()
                    }
                }
                let deleteTask = Task { try await storageB.deleteCurrentDID() }
                await deleteEntered.wait()
                let casStarted3 = TestAsyncGate()
                let casTask3 = Task {
                    casStarted3.open()
                    return try await storageA.compareAndSwapGatewaySession(
                        expectedOldSession: oldSession, newSession: candidateSession, for: alice)
                }
                await casStarted3.wait()
                XCTAssertEqual(candidateStarted3.withLock { $0 }, 0)
                deleteRelease.open()
                try await deleteTask.value
                let casResult3 = try await casTask3.value
                let currentDIDAfterDelete = try await storageA.getCurrentDID()
                XCTAssertFalse(casResult3)
                XCTAssertEqual(candidateStarted3.withLock { $0 }, 0)
                XCTAssertNil(currentDIDAfterDelete)
            }
        }
    }

    func testClientBlueNamespaceRootAnchor() async throws {
        let client = await ATProtoClient(baseURL: URL(string: "https://bsky.social")!)
        let blue = await client.blue
        _ = blue.networkService
        XCTAssertTrue(type(of: blue) == ATProtoClient.Blue.self)
    }

    // MARK: - 7. Fetch Granted Scopes Tests

    func testFetchGrantedScopesReturnsAuthoritativeSetAndThrowsOnError() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.fetch.scopes.\(UUID().uuidString)"
            let initialSession = UUID().uuidString.lowercased()
            let (client, _) = try await self.makeClient(namespace: namespace, initialSession: initialSession)

            let alice = self.aliceDID
            let bob = self.bobDID

            GatewayUpgradeTestURLProtocol.setHandler { request in
                if request.url?.path == "/auth/session" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.test",
                        "created_at": "2026-08-24T10:00:00Z",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let scopes = try await client.fetchGrantedScopes(for: self.aliceDID)
            XCTAssertEqual(scopes, ["atproto", "transition:generic", "identity:handle"])

            let reqs = GatewayUpgradeTestURLProtocol.recordedRequests()
            let sessionReq = reqs.first(where: { $0.url?.path == "/auth/session" })
            XCTAssertEqual(sessionReq?.value(forHTTPHeaderField: "Authorization"), "Bearer \(initialSession)")

            // 1. Non-200 (401) must throw, never return empty set
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, #"{"error":"invalid_session"}"#.data(using: .utf8)!)
            }
            do {
                _ = try await client.fetchGrantedScopes(for: self.aliceDID)
                XCTFail("Expected throw on 401 response")
            } catch {}

            // 2. Response with active == false must throw
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                let body = """
                {
                    "did": "\(alice)",
                    "handle": "alice.test",
                    "active": false,
                    "granted_scopes": ["atproto", "identity:handle"]
                }
                """.data(using: .utf8)!
                return (resp, body)
            }
            do {
                _ = try await client.fetchGrantedScopes(for: self.aliceDID)
                XCTFail("Expected throw on inactive session")
            } catch {}

            // 3. Response without 'atproto' scope must throw
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                let body = """
                {
                    "did": "\(alice)",
                    "handle": "alice.test",
                    "granted_scopes": ["identity:handle"]
                }
                """.data(using: .utf8)!
                return (resp, body)
            }
            do {
                _ = try await client.fetchGrantedScopes(for: self.aliceDID)
                XCTFail("Expected throw on missing atproto scope")
            } catch {}

            // 4. Response with mismatched DID must throw
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                let body = """
                {
                    "did": "\(bob)",
                    "handle": "bob.test",
                    "granted_scopes": ["atproto", "identity:handle"]
                }
                """.data(using: .utf8)!
                return (resp, body)
            }
            do {
                _ = try await client.fetchGrantedScopes(for: self.aliceDID)
                XCTFail("Expected throw on mismatched DID")
            } catch {}

            // 5. Missing session for non-existent DID must throw
            do {
                _ = try await client.fetchGrantedScopes(for: "did:plc:nonexistent")
                XCTFail("Expected throw on missing session")
            } catch {}
        }
    }

    func testExactNestSessionDTODecodesWithoutActiveAndRejectsExplicitFalse() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.exactnestdto.\(UUID().uuidString)"
            let initialSession = UUID().uuidString.lowercased()
            let (client, _) = try await self.makeClient(namespace: namespace, initialSession: initialSession)
            let alice = self.aliceDID

            // 1. Exact Nest DTO without active (with created_at) succeeds in fetchGrantedScopes
            GatewayUpgradeTestURLProtocol.setHandler { request in
                if request.url?.path == "/auth/session" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.test",
                        "created_at": "2026-08-24T10:00:00.123456Z",
                        "granted_scopes": ["atproto", "transition:generic"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let scopes = try await client.fetchGrantedScopes(for: self.aliceDID)
            XCTAssertEqual(scopes, ["atproto", "transition:generic"])

            // 2. Explicit active == false in fetchGrantedScopes is rejected
            GatewayUpgradeTestURLProtocol.setHandler { request in
                if request.url?.path == "/auth/session" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.test",
                        "active": false,
                        "granted_scopes": ["atproto", "transition:generic"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            do {
                _ = try await client.fetchGrantedScopes(for: self.aliceDID)
                XCTFail("Expected fetchGrantedScopes to reject active == false")
            } catch {}

            // 3. Exact Nest DTO in handleOAuthCallback succeeds
            GatewayUpgradeTestURLProtocol.setHandler { request in
                if request.url?.path == "/auth/session" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.test",
                        "created_at": "2026-08-24T10:00:00.123456Z",
                        "granted_scopes": ["atproto"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let callbackURL = URL(string: "https://catbird.blue/oauth/callback#session_id=\(UUID().uuidString.lowercased())")!
            try await client.handleOAuthCallback(url: callbackURL)
            let current = await client.getCurrentAccount()
            XCTAssertEqual(current?.did, alice)
            XCTAssertEqual(current?.handle, "alice.test")

            // 4. Explicit active == false in handleOAuthCallback is rejected
            GatewayUpgradeTestURLProtocol.setHandler { request in
                if request.url?.path == "/auth/session" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.test",
                        "active": false,
                        "granted_scopes": ["atproto"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            do {
                _ = try await client.handleOAuthCallback(url: callbackURL)
                XCTFail("Expected handleOAuthCallback to reject active == false")
            } catch {}
        }
    }

    // MARK: - 9. Auth Continuity & Same-DID Reauth Tests

    func testCandidateCommitFailureDuringHasValidSessionPreservesContinuityAndOldStateUntilPromoted() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.continuity.commitfail.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: oldSessionUUID)
            let alice = self.aliceDID

            // Plant candidate-bearing pending upgrade state
            let pendingState = """
            {
                "oldSession": "\(oldSessionUUID)",
                "expectedDID": "\(alice)",
                "requestedScopes": ["identity:handle"],
                "priorScopes": ["atproto", "transition:generic"],
                "browserNonce": "browser-nonce-12345",
                "callbackURL": "https://catbird.blue/oauth/permission-callback",
                "candidateSession": "\(candidateUUID)",
                "candidateGrantedScopes": ["atproto", "transition:generic", "identity:handle"]
            }
            """.data(using: .utf8)!
            try await storage.savePendingGatewayUpgradeData(pendingState, for: alice)

            // Handler: commit returns 503 Service Unavailable
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"error":"service_unavailable"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // 1. client.hasValidSession() returns true during commit failure
            let isValid = await client.hasValidSession()
            XCTAssertTrue(isValid, "Session continuity must be preserved as valid when candidate recovery commit fails")

            let sessionAfterFail = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterFail, oldSessionUUID, "Old session must remain intact in storage")
            let pendingAfterFail = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfterFail, "Pending upgrade state must remain intact in storage")
            let currentAccount = await client.getCurrentAccount()
            XCTAssertEqual(currentAccount?.did, alice, "Account DID must remain unchanged")

            // 2. Direct completeGatewayScopeUpgrade still throws on 503
            do {
                _ = try await client.completeGatewayScopeUpgrade(
                    callbackURL: URL(string: "https://catbird.blue/oauth/permission-callback?code=some-code")!,
                    for: alice
                )
                XCTFail("Direct complete must throw on 503")
            } catch {}

            // 3. Subsequent ordinary terminal 401 does not delete old session if recovery still fails
            let accountManager = await AccountManager(storage: storage)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)
            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager
            )
            let req = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
            let gateway401Response = HTTPURLResponse(
                url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"),
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let terminal401Body = #"{"error":"AuthenticationRequired","message":"token expired"}"#.data(using: .utf8)!

            do {
                _ = try await strategy.handleUnauthorizedResponse(
                    gateway401Response,
                    data: terminal401Body,
                    for: req
                )
                XCTFail("handleUnauthorizedResponse must throw when recovery fails")
            } catch {}

            let sessionAfter401 = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfter401, oldSessionUUID, "Old session must NOT be deleted after terminal 401 when recovery fails")
            let pendingAfter401 = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfter401, "Pending upgrade state must NOT be deleted after terminal 401 when recovery fails")

            // 4. Later idempotent commit succeeds and promotes
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "status": "committed",
                        "session_id": "\(candidateUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let isValidAfterSuccess = await client.hasValidSession()
            XCTAssertTrue(isValidAfterSuccess)

            let sessionAfterSuccess = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterSuccess, candidateUUID, "Candidate session must be promoted in storage")
            let pendingAfterSuccess = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNil(pendingAfterSuccess, "Pending upgrade data must be cleaned up on promotion")
        }
    }

    func testSameDIDOAuthCallbackWithCandidateRecoverySuccessRejectsCallbackWithoutSavingThirdSession() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.reauth.success.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let thirdSessionUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: oldSessionUUID)
            let alice = self.aliceDID

            // Plant candidate-bearing pending upgrade state
            let pendingState = """
            {
                "oldSession": "\(oldSessionUUID)",
                "expectedDID": "\(alice)",
                "requestedScopes": ["identity:handle"],
                "priorScopes": ["atproto", "transition:generic"],
                "browserNonce": "browser-nonce-12345",
                "callbackURL": "https://catbird.blue/oauth/permission-callback",
                "candidateSession": "\(candidateUUID)",
                "candidateGrantedScopes": ["atproto", "transition:generic", "identity:handle"]
            }
            """.data(using: .utf8)!
            try await storage.savePendingGatewayUpgradeData(pendingState, for: alice)

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(thirdSessionUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.third",
                        "active": true,
                        "granted_scopes": ["atproto"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                }
                if path == "/auth/upgrade/commit" {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "status": "committed",
                        "session_id": "\(candidateUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let callbackURL = URL(string: "https://catbird.blue/oauth/callback#session_id=\(thirdSessionUUID)")!
            do {
                _ = try await client.handleOAuthCallback(url: callbackURL)
                XCTFail("Ordinary callback must be rejected when candidate upgrade is pending")
            } catch {}

            // The third session must never be saved in storage
            let currentStoredSession = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(currentStoredSession, candidateUUID, "Candidate must remain promoted, third session must never be saved")
            let pendingData = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNil(pendingData, "Pending upgrade state must be cleared after successful candidate promotion")

            let currentAccount = await client.getCurrentAccount()
            XCTAssertEqual(currentAccount?.handle, "alice.test", "Account handle must NOT be overwritten by third session")
        }
    }

    func testSameDIDOAuthCallbackWithCandidateRecoveryFailureRejectsCallbackAndPreservesOldAndPending() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.reauth.fail.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let thirdSessionUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: oldSessionUUID)
            let alice = self.aliceDID

            // Plant candidate-bearing pending upgrade state
            let pendingState = """
            {
                "oldSession": "\(oldSessionUUID)",
                "expectedDID": "\(alice)",
                "requestedScopes": ["identity:handle"],
                "priorScopes": ["atproto", "transition:generic"],
                "browserNonce": "browser-nonce-12345",
                "callbackURL": "https://catbird.blue/oauth/permission-callback",
                "candidateSession": "\(candidateUUID)",
                "candidateGrantedScopes": ["atproto", "transition:generic", "identity:handle"]
            }
            """.data(using: .utf8)!
            try await storage.savePendingGatewayUpgradeData(pendingState, for: alice)

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(thirdSessionUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.third",
                        "active": true,
                        "granted_scopes": ["atproto"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                }
                if path == "/auth/upgrade/commit" {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"error":"service_unavailable"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let callbackURL = URL(string: "https://catbird.blue/oauth/callback#session_id=\(thirdSessionUUID)")!
            do {
                _ = try await client.handleOAuthCallback(url: callbackURL)
                XCTFail("Ordinary callback must be rejected when candidate upgrade is pending")
            } catch {}

            // Third session must never be saved; old session and pending upgrade state must remain
            let currentStoredSession = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(currentStoredSession, oldSessionUUID, "Old session must remain intact in storage")
            let pendingData = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingData, "Pending upgrade state must remain intact in storage")

            let currentAccount = await client.getCurrentAccount()
            XCTAssertEqual(currentAccount?.handle, "alice.test", "Account handle must NOT be overwritten by third session")
        }
    }

    func testSameDIDOAuthCallbackWithPreCandidatePendingRejectsCallbackAndRetainsPendingState() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.reauth.precandidate.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let thirdSessionUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: oldSessionUUID)
            let alice = self.aliceDID

            // Plant pre-candidate pending upgrade state (browser flow in progress)
            let pendingState = """
            {
                "oldSession": "\(oldSessionUUID)",
                "expectedDID": "\(alice)",
                "requestedScopes": ["identity:handle"],
                "priorScopes": ["atproto", "transition:generic"],
                "browserNonce": "browser-nonce-12345",
                "callbackURL": "https://catbird.blue/oauth/permission-callback"
            }
            """.data(using: .utf8)!
            try await storage.savePendingGatewayUpgradeData(pendingState, for: alice)

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(thirdSessionUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "did": "\(alice)",
                        "handle": "alice.third",
                        "active": true,
                        "granted_scopes": ["atproto"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let callbackURL = URL(string: "https://catbird.blue/oauth/callback#session_id=\(thirdSessionUUID)")!
            do {
                _ = try await client.handleOAuthCallback(url: callbackURL)
                XCTFail("Ordinary callback must be rejected when pre-candidate upgrade is in progress")
            } catch {}

            // Third session must never be saved; old session and pending upgrade state must remain
            let currentStoredSession = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(currentStoredSession, oldSessionUUID, "Old session must remain intact in storage")
            let pendingData = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingData, "Pending upgrade state must remain intact in storage")

            let currentAccount = await client.getCurrentAccount()
            XCTAssertEqual(currentAccount?.handle, "alice.test", "Account handle must NOT be overwritten by third session")
        }
    }
}
