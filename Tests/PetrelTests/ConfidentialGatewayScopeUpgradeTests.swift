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

private final class TestAtomicCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

private final class TestThreadSafeArray<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [T] = []

    func append(_ item: T) {
        lock.withLock {
            items.append(item)
        }
    }

    var values: [T] {
        lock.withLock {
            items
        }
    }
}

private final class ThrowingStorageBackend: SecureStorage, @unchecked Sendable {
    let errorToThrow: Error
    init(errorToThrow: Error) { self.errorToThrow = errorToThrow }
    func store(key: String, value: Data, namespace: String, accessGroup: String?) throws { throw errorToThrow }
    func retrieve(key: String, namespace: String, accessGroup: String?) throws -> Data { throw errorToThrow }
    func delete(key: String, namespace: String, accessGroup: String?) throws { throw errorToThrow }
    func deleteAll(namespace: String, accessGroup: String?) throws { throw errorToThrow }
    func storeDPoPKeyRepresentation(_ representation: Data, keyTag: String, accessGroup: String?) throws { throw errorToThrow }
    func retrieveDPoPKeyRepresentation(keyTag: String, accessGroup: String?) throws -> Data { throw errorToThrow }
    func deleteDPoPKey(keyTag: String, accessGroup: String?) throws { throw errorToThrow }
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
        _ = URLProtocol.registerClass(GatewayUpgradeTestURLProtocol.self)
        NetworkService.setNetworkTestProtocolClasses([GatewayUpgradeTestURLProtocol.self])
        NetworkService.dnsResolverOverride = { _ in ["93.184.216.34"] }
    }

    override func tearDown() {
        NetworkService.dnsResolverOverride = nil
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

            // 3. Unbounded single scope (> 256 chars)
            let longScope = String(repeating: "a", count: 257)
            do {
                _ = try await client.startGatewayScopeUpgrade(requesting: [longScope], for: self.aliceDID, callbackURL: self.validCallbackBase)
                XCTFail("Expected failure for >256-char scope")
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
            let freshSessionUUID = UUID().uuidString.lowercased()
            let (loginURL1, stateToken1) = try await client.startOAuthFlowWithState(identifier: alice)
            _ = loginURL1
            GatewayUpgradeTestURLProtocol.setHandler { request in
                if request.url?.path == "/auth/exchange" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = #"{"session_id":"\#(freshSessionUUID)"}"#.data(using: .utf8)!
                    return (resp, body)
                }
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

            let callbackURL = URL(string: "https://catbird.blue/oauth/callback?code=code_fresh_nest_dto&state=\(stateToken1)")!
            try await client.handleOAuthCallback(url: callbackURL)
            let current = await client.getCurrentAccount()
            XCTAssertEqual(current?.did, alice)
            XCTAssertEqual(current?.handle, "alice.test")

            // 4. Explicit active == false in handleOAuthCallback is rejected
            let (_, stateToken2) = try await client.startOAuthFlowWithState(identifier: alice)
            GatewayUpgradeTestURLProtocol.setHandler { request in
                if request.url?.path == "/auth/exchange" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = #"{"session_id":"\#(freshSessionUUID)"}"#.data(using: .utf8)!
                    return (resp, body)
                }
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

            let callbackURL2 = URL(string: "https://catbird.blue/oauth/callback?code=code_fresh_nest_dto_2&state=\(stateToken2)")!
            do {
                _ = try await client.handleOAuthCallback(url: callbackURL2)
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
            let terminal401Body = #"{"error":"ExpiredToken","message":"The token has expired"}"#.data(using: .utf8)!

            do {
                _ = try await strategy.handleUnauthorizedResponse(
                    gateway401Response,
                    data: terminal401Body,
                    for: req
                )
                XCTFail("handleUnauthorizedResponse must throw when recovery fails on terminal 401")
            } catch let error as ConfidentialGatewayStrategy.GatewayError {
                guard case .upgradeTemporarilyUnavailable = error else {
                    XCTFail("Expected .upgradeTemporarilyUnavailable, got \(error)")
                    return
                }
            } catch {
                XCTFail("Expected GatewayError, got \(error)")
            }
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

            let (_, stateToken) = try await client.startOAuthFlowWithState(identifier: alice)
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/exchange" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = #"{"session_id":"\#(thirdSessionUUID)"}"#.data(using: .utf8)!
                    return (resp, body)
                }
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

            let callbackURL = URL(string: "https://catbird.blue/oauth/callback?code=code_third_session&state=\(stateToken)")!
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
                if path == "/auth/exchange" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = #"{"session_id":"\#(thirdSessionUUID)"}"#.data(using: .utf8)!
                    return (resp, body)
                }
                if path == "/auth/upgrade/commit" {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"error":"service_unavailable"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let (_, stateToken) = try await client.startOAuthFlowWithState(identifier: alice)
            let callbackURL = URL(string: "https://catbird.blue/oauth/callback?code=code_third_session&state=\(stateToken)")!
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
                if path == "/auth/exchange" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = #"{"session_id":"\#(thirdSessionUUID)"}"#.data(using: .utf8)!
                    return (resp, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let (_, stateToken) = try await client.startOAuthFlowWithState(identifier: alice)
            let callbackURL = URL(string: "https://catbird.blue/oauth/callback?code=code_third_session&state=\(stateToken)")!
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
    func testCandidateCommitNetworkErrorDuringHasValidSessionPreservesContinuityAndPrepareFails() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.continuity.networkerror.\(UUID().uuidString)"
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

            // Handler: commit throws transport error (URLError)
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    throw URLError(.notConnectedToInternet)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // 1. client.hasValidSession() returns true on retryable network error
            let isValid = await client.hasValidSession()
            XCTAssertTrue(isValid, "Session continuity must be preserved as valid when candidate recovery encounters network error")

            // 2. Old session and pending upgrade state must remain intact in storage (no destructive clear)
            let sessionAfterFail = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterFail, oldSessionUUID, "Old session must remain intact in storage")
            let pendingAfterFail = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfterFail, "Pending upgrade state must remain intact in storage")

            // 3. prepareAuthenticatedRequest must still throw and propagate recovery failure
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
            do {
                _ = try await strategy.prepareAuthenticatedRequest(req)
                XCTFail("prepareAuthenticatedRequest must throw when candidate recovery encounters network error")
            } catch {}
        }
    }

    func testCandidateRecoveryWithCurrentDIDMismatchYieldsInvalidSessionWithoutDestructiveClear() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.continuity.didmismatch.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: oldSessionUUID)
            let alice = self.aliceDID
            let bob = self.bobDID

            // Plant candidate-bearing pending upgrade state for Alice
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

            // Simulate storage currentDID mismatch: currentDID is bob while account is alice
            try await storage.saveCurrentDID(bob)

            // 1. client.hasValidSession() returns false
            let isValid = await client.hasValidSession()
            XCTAssertFalse(isValid, "hasValidSession must return false when currentDID mismatches")

            // 2. Old session and pending upgrade state for Alice must remain intact in storage (no destructive clear)
            let sessionAfterFail = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterFail, oldSessionUUID, "Alice's old session must remain intact in storage")
            let pendingAfterFail = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfterFail, "Alice's pending upgrade state must remain intact in storage")

            // 3. prepareAuthenticatedRequest must throw
            let accountManager = await AccountManager(storage: storage)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)
            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager
            )
            let req = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
            do {
                _ = try await strategy.prepareAuthenticatedRequest(req)
                XCTFail("prepareAuthenticatedRequest must throw on currentDID mismatch")
            } catch {}
        }
    }

    func testCandidateRecoveryWithMissingSessionYieldsInvalidSessionWithoutDestructiveClear() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.continuity.missingsession.\(UUID().uuidString)"
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

            // Delete gateway session (simulate missing session)
            try await storage.deleteGatewaySession(for: alice)

            // 1. client.hasValidSession() returns false
            let isValid = await client.hasValidSession()
            XCTAssertFalse(isValid, "hasValidSession must return false when gateway session is missing")

            // 2. Pending upgrade state must remain intact in storage (no destructive clear)
            let pendingAfterFail = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfterFail, "Pending upgrade state must remain intact in storage")

            // 3. prepareAuthenticatedRequest must throw
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
            do {
                _ = try await strategy.prepareAuthenticatedRequest(req)
                XCTFail("prepareAuthenticatedRequest must throw when session is missing")
            } catch {}
        }
    }

    func testCandidateRecoveryWithThirdSessionYieldsInvalidSessionWithoutDestructiveClear() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.continuity.thirdsession.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let thirdSessionUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: oldSessionUUID)
            let alice = self.aliceDID

            // Plant candidate-bearing pending upgrade state (old = oldSessionUUID, candidate = candidateUUID)
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

            // Set current stored session to thirdSessionUUID (neither old nor candidate)
            try await storage.saveGatewaySession(thirdSessionUUID, for: alice)

            // 1. client.hasValidSession() returns false
            let isValid = await client.hasValidSession()
            XCTAssertFalse(isValid, "hasValidSession must return false when current session is an un-promoted third session")

            // 2. Storage must NOT be destructively cleared
            let storedSession = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(storedSession, thirdSessionUUID, "Stored third session must remain intact")
            let pendingAfterFail = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfterFail, "Pending upgrade state must remain intact in storage")

            // 3. prepareAuthenticatedRequest must throw
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
            do {
                _ = try await strategy.prepareAuthenticatedRequest(req)
                XCTFail("prepareAuthenticatedRequest must throw when current session is a third session")
            } catch {}
        }
    }

    func testCandidateCommit4xxErrorYieldsInvalidSessionWithoutDestructiveClear() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.continuity.commit4xx.\(UUID().uuidString)"
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

            // Handler: commit returns HTTP 400 Bad Request
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"error":"invalid_request"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // 1. client.hasValidSession() returns false on terminal 4xx error
            let isValid = await client.hasValidSession()
            XCTAssertFalse(isValid, "hasValidSession must return false on terminal 4xx commit failure")

            // 2. Old session and pending upgrade state must remain intact in storage (no destructive clear)
            let sessionAfterFail = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterFail, oldSessionUUID, "Old session must remain intact in storage")
            let pendingAfterFail = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfterFail, "Pending upgrade state must remain intact in storage")

            // 3. prepareAuthenticatedRequest must throw
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
            do {
                _ = try await strategy.prepareAuthenticatedRequest(req)
                XCTFail("prepareAuthenticatedRequest must throw when candidate commit returns 400")
            } catch {}
        }
    }

    func testCandidateCommitMalformedReceiptYieldsInvalidSessionWithoutDestructiveClear() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.continuity.malformedcommit.\(UUID().uuidString)"
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

            // Handler: commit returns HTTP 200 with malformed/truncated JSON
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"status": "committed", "session_id": "#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // 1. client.hasValidSession() returns false on malformed commit receipt
            let isValid = await client.hasValidSession()
            XCTAssertFalse(isValid, "hasValidSession must return false on malformed commit receipt")

            // 2. Old session and pending upgrade state must remain intact in storage (no destructive clear)
            let sessionAfterFail = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterFail, oldSessionUUID, "Old session must remain intact in storage")
            let pendingAfterFail = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfterFail, "Pending upgrade state must remain intact in storage")

            // 3. prepareAuthenticatedRequest must throw
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
            do {
                _ = try await strategy.prepareAuthenticatedRequest(req)
                XCTFail("prepareAuthenticatedRequest must throw on malformed commit receipt")
            } catch {}
        }
    }

    func testCandidateCommitInvalidReceiptYieldsInvalidSessionWithoutDestructiveClear() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.continuity.invalidreceipt.\(UUID().uuidString)"
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

            // Handler: commit returns HTTP 200 with wrong session_id (mismatched candidate receipt)
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "status": "committed",
                        "session_id": "wrong-candidate-session-id",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // 1. client.hasValidSession() returns false on invalid commit receipt
            let isValid = await client.hasValidSession()
            XCTAssertFalse(isValid, "hasValidSession must return false on invalid commit receipt")

            // 2. Old session and pending upgrade state must remain intact in storage (no destructive clear)
            let sessionAfterFail = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterFail, oldSessionUUID, "Old session must remain intact in storage")
            let pendingAfterFail = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfterFail, "Pending upgrade state must remain intact in storage")

            // 3. prepareAuthenticatedRequest must throw
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
            do {
                _ = try await strategy.prepareAuthenticatedRequest(req)
                XCTFail("prepareAuthenticatedRequest must throw on invalid commit receipt")
            } catch {}
        }
    }

    func testCandidateCommitCASFalseYieldsInvalidSessionWithoutDestructiveClear() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.continuity.casfalse.\(UUID().uuidString)"
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

            // Handler: commit returns 200, but in handler we mutate stored session deterministically before returning 200
            let writeGate = TestAsyncGate()
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    Task {
                        try? await storage.saveGatewaySession(thirdSessionUUID, for: alice)
                        writeGate.open()
                    }
                    writeGate.waitBlocking()
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

            // 1. client.hasValidSession() returns false when CAS returns false
            let isValid = await client.hasValidSession()
            XCTAssertFalse(isValid, "hasValidSession must return false when CAS fails")

            // 2. Assert third session was indeed stored in storage
            let sessionInStorage = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionInStorage, thirdSessionUUID, "Stored session must be thirdSessionUUID")
            // 2. Storage and pending upgrade state must remain intact (no destructive clear)
            let pendingAfterFail = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfterFail, "Pending upgrade state must remain intact in storage")

            // 3. prepareAuthenticatedRequest must throw
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
            do {
                _ = try await strategy.prepareAuthenticatedRequest(req)
                XCTFail("prepareAuthenticatedRequest must throw when CAS fails")
            } catch {}
        }
    }

    func testCandidateCleanupWhenLocalSessionAlreadyCandidateYieldsStillValid() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.continuity.alreadycandidate.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: candidateUUID)
            let alice = self.aliceDID

            // Plant candidate-bearing pending upgrade state (session in storage is already candidateUUID)
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

            // 1. client.hasValidSession() returns true because local session is already candidate
            let isValid = await client.hasValidSession()
            XCTAssertTrue(isValid, "hasValidSession must return true when local session is already candidate")

            // 2. Candidate session remains in storage and pending data is cleaned up
            let session = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(session, candidateUUID)

            // 3. prepareAuthenticatedRequest succeeds with candidate bearer token
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
            let prepared = try await strategy.prepareAuthenticatedRequest(req)
            XCTAssertEqual(prepared.value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
        }
    }

    func testLogoutCandidateAbandonmentDeletesPendingBeforeRemoteLogout() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.logout.candidate.abandonment.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let freshSessionUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: oldSessionUUID)
            let alice = self.aliceDID

            // Plant terminal candidate-bearing pending upgrade state
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

            // Setup mock handler for logout that peeks storage to verify pending data was deleted BEFORE /auth/logout
            GatewayUpgradeTestURLProtocol.reset()
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/logout" {
                    let pendingPeek = backend.peek(key: "pendingGatewayUpgrade.\(alice)", namespace: namespace)
                    XCTAssertNil(pendingPeek, "Pending upgrade data must be deleted before remote /auth/logout request is issued")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"status":"ok"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // Perform explicit logout
            try await client.logout()

            // 1. Verify remote logout requests sent for candidate first, then old session
            let logoutRequests = GatewayUpgradeTestURLProtocol.recordedRequests().filter { $0.url?.path == "/auth/logout" }
            XCTAssertEqual(logoutRequests.count, 2, "Explicit logout must retire both candidate and old sessions")
            XCTAssertEqual(logoutRequests[0].value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
            XCTAssertEqual(logoutRequests[1].value(forHTTPHeaderField: "Authorization"), "Bearer \(oldSessionUUID)")

            // 2. Pending upgrade state must be deleted BEFORE anchor session is cleared
            let pendingAfterLogout = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNil(pendingAfterLogout, "Pending gateway upgrade must be deleted on logout")

            // 3. Gateway session and current account must be cleared
            let sessionAfterLogout = try await storage.getGatewaySession(for: alice)
            XCTAssertNil(sessionAfterLogout, "Gateway session must be deleted on logout")
            let currentAccount = await client.getCurrentAccount()
            XCTAssertNil(currentAccount, "Current account must be cleared on logout")

            // 4. Fresh same-DID OAuth callback succeeds now that pending upgrade is gone
            let (_, stateToken) = try await client.startOAuthFlowWithState(identifier: alice)
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/exchange" {
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = #"{"session_id":"\#(freshSessionUUID)"}"#.data(using: .utf8)!
                    return (resp, body)
                }
                if path == "/auth/session" {
                    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(freshSessionUUID)")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    let body = """
                    {
                        "session_id": "\(freshSessionUUID)",
                        "did": "\(alice)",
                        "handle": "alice.test",
                        "active": true,
                        "scope": "atproto transition:generic"
                    }
                    """.data(using: .utf8)!
                    return (resp, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let callbackURL = URL(string: "https://catbird.blue/oauth/callback?code=code_fresh_session&state=\(stateToken)")!
            try await client.handleOAuthCallback(url: callbackURL)

            let restoredSession = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(restoredSession, freshSessionUUID, "Fresh session must be saved")
            let restoredAccount = await client.getCurrentAccount()
            XCTAssertEqual(restoredAccount?.did, alice, "Current account must be restored to alice")
            let isValid = await client.hasValidSession()
            XCTAssertTrue(isValid, "Session must be valid after fresh login")
        }
    }

    func testLogoutCandidateWhenLocalSessionAlreadyPromotedSendsCandidateBearerOnce() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.logout.promoted.candidate.\(UUID().uuidString)"
            let candidateUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: candidateUUID)
            let alice = self.aliceDID

            // Plant candidate-bearing pending upgrade state where candidate matches local session
            let pendingState = """
            {
                "oldSession": "\(UUID().uuidString.lowercased())",
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

            GatewayUpgradeTestURLProtocol.reset()
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/logout" {
                    let pendingPeek = backend.peek(key: "pendingGatewayUpgrade.\(alice)", namespace: namespace)
                    XCTAssertNil(pendingPeek, "Pending upgrade data must be deleted before remote /auth/logout request is issued")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"status":"ok"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            try await client.logout()

            let logoutRequests = GatewayUpgradeTestURLProtocol.recordedRequests().filter { $0.url?.path == "/auth/logout" }
            XCTAssertEqual(logoutRequests.count, 1, "Promoted candidate session must only send a single logout request")
            XCTAssertEqual(logoutRequests[0].value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")

            let pendingAfterLogout = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNil(pendingAfterLogout, "Pending gateway upgrade must be deleted on logout")
            let sessionAfterLogout = try await storage.getGatewaySession(for: alice)
            XCTAssertNil(sessionAfterLogout, "Gateway session must be deleted on logout")
            let currentAccount = await client.getCurrentAccount()
            XCTAssertNil(currentAccount, "Current account must be cleared on logout")
        }
    }

    func testLogoutCandidateStagedReturns401ContinuesToOldSession() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.logout.staged.401.\(UUID().uuidString)"
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

            // Setup mock handler: candidate returns 401, oldSession returns 200
            GatewayUpgradeTestURLProtocol.reset()
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/logout" {
                    let authHeader = request.value(forHTTPHeaderField: "Authorization") ?? ""
                    if authHeader == "Bearer \(candidateUUID)" {
                        let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                        return (resp, #"{"error":"unauthorized","message":"staged candidate not committed"}"#.data(using: .utf8)!)
                    } else if authHeader == "Bearer \(oldSessionUUID)" {
                        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                        return (resp, #"{"status":"ok"}"#.data(using: .utf8)!)
                    }
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // Logout should succeed without throwing
            try await client.logout()

            let logoutRequests = GatewayUpgradeTestURLProtocol.recordedRequests().filter { $0.url?.path == "/auth/logout" }
            XCTAssertEqual(logoutRequests.count, 2)
            XCTAssertEqual(logoutRequests[0].value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
            XCTAssertEqual(logoutRequests[1].value(forHTTPHeaderField: "Authorization"), "Bearer \(oldSessionUUID)")

            let pendingAfterLogout = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNil(pendingAfterLogout, "Pending gateway upgrade must be deleted on logout")
            let sessionAfterLogout = try await storage.getGatewaySession(for: alice)
            XCTAssertNil(sessionAfterLogout, "Gateway session must be deleted on logout")
            let currentAccount = await client.getCurrentAccount()
            XCTAssertNil(currentAccount, "Current account must be cleared on logout")
        }
    }

    func testLogoutPreCandidateAbandonmentDeletesPendingBeforeRemoteLogout() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.logout.precandidate.abandonment.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: oldSessionUUID)
            let alice = self.aliceDID

            // Plant pre-candidate pending upgrade state (no candidateSession)
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

            // Setup mock handler for logout that peeks storage to verify pending data was deleted BEFORE /auth/logout
            GatewayUpgradeTestURLProtocol.reset()
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/logout" {
                    let pendingPeek = backend.peek(key: "pendingGatewayUpgrade.\(alice)", namespace: namespace)
                    XCTAssertNil(pendingPeek, "Pre-candidate pending upgrade data must be deleted before remote /auth/logout request is issued")
                    let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                    return (resp, #"{"status":"ok"}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // Perform explicit logout
            try await client.logout()

            // Verify remote logout request sent for old session only
            let logoutRequests = GatewayUpgradeTestURLProtocol.recordedRequests().filter { $0.url?.path == "/auth/logout" }
            XCTAssertEqual(logoutRequests.count, 1, "Pre-candidate upgrade must only send old session logout request")
            XCTAssertEqual(logoutRequests[0].value(forHTTPHeaderField: "Authorization"), "Bearer \(oldSessionUUID)")

            // 1. Pending upgrade state must be deleted
            let pendingAfterLogout = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNil(pendingAfterLogout, "Pending gateway upgrade must be deleted on logout")

            // 2. Gateway session and current account must be cleared
            let sessionAfterLogout = try await storage.getGatewaySession(for: alice)
            XCTAssertNil(sessionAfterLogout, "Gateway session must be deleted on logout")
            let currentAccount = await client.getCurrentAccount()
            XCTAssertNil(currentAccount, "Current account must be cleared on logout")
        }
    }

    func testLogoutAbandonmentClearsLocalStateEvenWhenRemoteLogoutUnavailable() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.logout.remote.unavailable.\(UUID().uuidString)"
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

            // Setup mock handler for logout that fails with network error
            GatewayUpgradeTestURLProtocol.reset()
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/logout" {
                    let pendingPeek = backend.peek(key: "pendingGatewayUpgrade.\(alice)", namespace: namespace)
                    XCTAssertNil(pendingPeek, "Pending upgrade data must be deleted before remote logout call even when remote is down")
                    throw URLError(.notConnectedToInternet)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // Best-effort remote logout must not throw
            try await client.logout()

            let logoutRequests = GatewayUpgradeTestURLProtocol.recordedRequests().filter { $0.url?.path == "/auth/logout" }
            XCTAssertEqual(logoutRequests.count, 2)
            XCTAssertEqual(logoutRequests[0].value(forHTTPHeaderField: "Authorization"), "Bearer \(candidateUUID)")
            XCTAssertEqual(logoutRequests[1].value(forHTTPHeaderField: "Authorization"), "Bearer \(oldSessionUUID)")

            // 1. Pending upgrade state must be deleted
            let pendingAfterLogout = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNil(pendingAfterLogout, "Pending gateway upgrade must be deleted on logout even if remote failed")

            // 2. Gateway session and current account must be cleared
            let sessionAfterLogout = try await storage.getGatewaySession(for: alice)
            XCTAssertNil(sessionAfterLogout, "Gateway session must be deleted on logout even if remote failed")
            let currentAccount = await client.getCurrentAccount()
            XCTAssertNil(currentAccount, "Current account must be cleared on logout even if remote failed")
        }
    }

    func testLogoutFailsWhenPendingUpgradeDeletionFailsPreservingSessionAndAccount() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.logout.fail.\(UUID().uuidString)"
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

            // Install URLProtocol handler that fails if any network request occurs
            GatewayUpgradeTestURLProtocol.reset()
            GatewayUpgradeTestURLProtocol.setHandler { request in
                XCTFail("No network request should occur when pending upgrade deletion fails: \(request.url?.absoluteString ?? "")")
                return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }

            // Inject failure when deleting pending gateway upgrade
            backend.failDeleteMatching = { key in
                key.contains("pendingGatewayUpgrade")
            }

            do {
                try await client.logout()
                XCTFail("Logout must throw when deleting pending upgrade fails")
            } catch {}

            // Assert zero requests occurred
            let requests = GatewayUpgradeTestURLProtocol.recordedRequests()
            XCTAssertEqual(requests.count, 0, "Zero network requests must be made when pending deletion fails")

            // Verify session, selector, and pending data are NOT deleted
            let pendingAfterFail = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfterFail, "Pending upgrade must NOT be deleted when deletion throws")
            let sessionAfterFail = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterFail, oldSessionUUID, "Gateway session must NOT be deleted when pending deletion throws")
            let currentAccount = await client.getCurrentAccount()
            XCTAssertEqual(currentAccount?.did, alice, "Current account must NOT be cleared when pending deletion throws")
            let currentDID = try await storage.getCurrentDID()
            XCTAssertEqual(currentDID, alice, "Current DID selector must NOT be cleared when pending deletion throws")
        }
    }
    func testLogoutFailsWhenPendingUpgradeDecodeFailsPreservingSessionAndAccount() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.logout.decodefail.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: oldSessionUUID)
            let alice = self.aliceDID

            // Plant corrupted pending upgrade state data (invalid JSON)
            let corruptedData = Data([0x00, 0x01, 0x02, 0x03])
            try await storage.savePendingGatewayUpgradeData(corruptedData, for: alice)

            // Install URLProtocol handler that fails if any network request occurs
            GatewayUpgradeTestURLProtocol.reset()
            GatewayUpgradeTestURLProtocol.setHandler { request in
                XCTFail("No network request should occur when pending upgrade decode fails: \(request.url?.absoluteString ?? "")")
                return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }

            do {
                try await client.logout()
                XCTFail("Logout must throw when decoding pending upgrade fails")
            } catch {}

            // Assert zero requests occurred
            let requests = GatewayUpgradeTestURLProtocol.recordedRequests()
            XCTAssertEqual(requests.count, 0, "Zero network requests must be made when pending decode fails")

            // Verify session, selector, and pending data are NOT deleted
            let pendingAfterFail = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfterFail, "Pending upgrade must NOT be deleted when decode throws")
            let sessionAfterFail = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterFail, oldSessionUUID, "Gateway session must NOT be deleted when pending decode throws")
            let currentAccount = await client.getCurrentAccount()
            XCTAssertEqual(currentAccount?.did, alice, "Current account must NOT be cleared when pending decode throws")
            let currentDID = try await storage.getCurrentDID()
            XCTAssertEqual(currentDID, alice, "Current DID selector must NOT be cleared when pending decode throws")
        }
    }

    func testCandidateRecoveryWithCorruptedCurrentDIDOrSessionIsTerminal() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.corrupted.terminal.\(UUID().uuidString)"
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

            // 1. Plant invalid UTF-8 bytes at currentDID key (corrupted selector)
            let invalidUTF8 = Data([0xFF, 0xFE, 0xFD, 0x00, 0xFF])
            KeychainManager.clearCache()
            backend.plant(key: "currentDID", namespace: namespace, data: invalidUTF8)

            // hasValidSession must return false (terminal dataFormatError propagates)
            let isValidWithCorruptedDID = await client.hasValidSession()
            XCTAssertFalse(isValidWithCorruptedDID, "Corrupted currentDID must be terminal (hasValidSession = false)")

            // Restore valid currentDID, but plant invalid UTF-8 bytes at gatewaySession key
            KeychainManager.clearCache()
            backend.plant(key: "currentDID", namespace: namespace, data: Data(alice.utf8))
            backend.plant(key: "gatewaySession.\(alice)", namespace: namespace, data: invalidUTF8)

            let isValidWithCorruptedSession = await client.hasValidSession()
            XCTAssertFalse(isValidWithCorruptedSession, "Corrupted session must be terminal (hasValidSession = false)")
        }
    }

    func testCandidateRecoveryWithRetrievalOrStorageUnavailableIsTerminal() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.unavailable.terminal.\(UUID().uuidString)"
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

            // 1. Fail retrieval of pendingGatewayUpgrade with itemRetrievalError (non-not-found)
            KeychainManager.clearCache()
            backend.failRetrieveMatching = { key in
                key.contains("pendingGatewayUpgrade")
            }

            let isValidWithRetrievalFail = await client.hasValidSession()
            XCTAssertFalse(isValidWithRetrievalFail, "Retrieval failure must be terminal (hasValidSession = false)")

            // 2. Storage unavailable error
            backend.failRetrieveMatching = nil
            KeychainManager.clearCache()
            let unavailableStorage = ThrowingStorageBackend(errorToThrow: KeychainError.storageUnavailable("Secure enclave unavailable"))
            KeychainManager._setStorageOverride(unavailableStorage)

            let isValidWithUnavailable = await client.hasValidSession()
            XCTAssertFalse(isValidWithUnavailable, "Storage unavailable must be terminal (hasValidSession = false)")

            // Reset back
            KeychainManager._setStorageOverride(backend)
            KeychainManager.clearCache()
        }
    }
    func testCandidateRecoveryWithRetryableStoreOrDeletionErrorPreservesSessionContinuity() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.retryable.keychain.\(UUID().uuidString)"
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

            // Setup commit handler returning 200
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
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

            // 1. Fail store of candidate session with itemStoreError (atomic failure preserves old)
            backend.failStoreMatching = { key in
                key.contains("gatewaySession")
            }

            let isValidWithStoreError = await client.hasValidSession()
            XCTAssertTrue(isValidWithStoreError, "itemStoreError is retryable; session continuity must be preserved")

            // 2. Allow store, but fail deletion of pending upgrade data with deletionError
            backend.failStoreMatching = nil
            backend.failDeleteMatching = { key in
                key.contains("pendingGatewayUpgrade")
            }

            let isValidWithDeleteError = await client.hasValidSession()
            XCTAssertTrue(isValidWithDeleteError, "deletionError is retryable; session continuity must be preserved")
        }
    }

    // MARK: - Lifecycle Serialization & Queue Concurrency Tests

    func testStartBlockedInUpgradeNetworkSerializesLogoutAndClearsPendingAndSession() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.start.blocked.logout.\(UUID().uuidString)"
            let initialSessionUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: initialSessionUUID)
            let alice = self.aliceDID
            let callbackBase = Self.validCallbackBase

            let startUpgradeEntered = TestAsyncGate()
            let startUpgradeRelease = TestAsyncGate()

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
                    startUpgradeEntered.open()
                    startUpgradeRelease.waitBlocking()
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
                } else if path == "/auth/logout" {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (response, Data())
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let startTask = Task {
                try await client.startGatewayScopeUpgrade(
                    requesting: ["identity:handle"],
                    for: alice,
                    callbackURL: callbackBase
                )
            }
            await startUpgradeEntered.wait()

            // Begin logout while startGatewayScopeUpgrade is blocked in /auth/upgrade network
            let logoutTask = Task {
                try await client.logout()
            }

            // Verify that while start is in-flight, logout has not called /auth/logout or cleared session
            let logoutReqsBefore = GatewayUpgradeTestURLProtocol.recordedRequests().filter { $0.url?.path == "/auth/logout" }
            XCTAssertTrue(logoutReqsBefore.isEmpty, "Logout network request must wait for in-flight start to complete")
            let sessionBefore = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionBefore, initialSessionUUID, "Session must not be cleared while start is in-flight")

            // Release start
            startUpgradeRelease.open()

            let authURL = try await startTask.value
            XCTAssertEqual(authURL.absoluteString, "https://auth.pds.test/oauth/authorize?req=123")

            try await logoutTask.value

            // Prove logout serialized after start, cleared the newly persisted pending upgrade and session
            let pendingAfter = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNil(pendingAfter, "Logout must clear pending gateway upgrade state persisted by start")
            let sessionAfter = try await storage.getGatewaySession(for: alice)
            XCTAssertNil(sessionAfter, "Logout must clear local gateway session")
            let currentAccount = await client.getCurrentAccount()
            XCTAssertNil(currentAccount, "Logout must clear current account")

            let logoutReqsAfter = GatewayUpgradeTestURLProtocol.recordedRequests().filter { $0.url?.path == "/auth/logout" }
            XCTAssertFalse(logoutReqsAfter.isEmpty, "Logout network call must have occurred")
        }
    }

    func testCompleteBlockedInCommitSerializesLogoutAndRetiresCandidateAndClearsState() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.complete.blocked.logout.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: oldSessionUUID)
            let alice = self.aliceDID
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

            let commitEntered = TestAsyncGate()
            let commitRelease = TestAsyncGate()

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    commitEntered.open()
                    commitRelease.waitBlocking()
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = """
                    {
                        "status": "committed",
                        "session_id": "\(candidateUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (response, body)
                } else if path == "/auth/logout" {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (response, Data())
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let incomingCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=auth-code-12345")!
            let completeTask = Task {
                try await client.completeGatewayScopeUpgrade(
                    callbackURL: incomingCallback,
                    for: alice
                )
            }
            await commitEntered.wait()

            // Start logout while completeGatewayScopeUpgrade is blocked inside /auth/upgrade/commit
            let logoutTask = Task {
                try await client.logout()
            }

            // Verify logout is waiting and has not sent /auth/logout
            let logoutReqsBefore = GatewayUpgradeTestURLProtocol.recordedRequests().filter { $0.url?.path == "/auth/logout" }
            XCTAssertTrue(logoutReqsBefore.isEmpty, "Logout must wait for in-flight complete/commit")

            // Release commit
            commitRelease.open()

            let grants = try await completeTask.value
            XCTAssertTrue(grants.contains("identity:handle"))

            try await logoutTask.value

            // Prove logout serialized, candidate session was retired and all state cleared
            let pendingAfter = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNil(pendingAfter, "Pending upgrade data must be nil after logout")
            let sessionAfter = try await storage.getGatewaySession(for: alice)
            XCTAssertNil(sessionAfter, "Gateway session must be nil after logout")
            let currentAccount = await client.getCurrentAccount()
            XCTAssertNil(currentAccount, "Current account must be nil after logout")
            let logoutReqsAfter = GatewayUpgradeTestURLProtocol.recordedRequests().filter { $0.url?.path == "/auth/logout" }
            let logoutTokens = logoutReqsAfter.compactMap { $0.value(forHTTPHeaderField: "Authorization") }
            XCTAssertTrue(logoutTokens.contains("Bearer \(candidateUUID)"), "Candidate session must be invalidated during logout")
        }
    }

    func testCancelWhileStartBlockedSerializesAndClearsResultingPreCandidate() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.cancel.start.blocked.\(UUID().uuidString)"
            let initialSessionUUID = UUID().uuidString.lowercased()
            let (client, storage) = try await self.makeClient(namespace: namespace, initialSession: initialSessionUUID)
            let alice = self.aliceDID
            let callbackBase = Self.validCallbackBase
            let startEntered = TestAsyncGate()
            let startRelease = TestAsyncGate()
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
                    startEntered.open()
                    startRelease.waitBlocking()
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

            let startTask = Task {
                try await client.startGatewayScopeUpgrade(
                    requesting: ["identity:handle"],
                    for: alice,
                    callbackURL: callbackBase
                )
            }
            await startEntered.wait()

            // Queue cancel while start is blocked in /auth/upgrade
            let cancelTask = Task {
                await client.cancelOAuthFlow()
            }

            // Release start
            startRelease.open()

            _ = try await startTask.value
            await cancelTask.value

            // Verify that cancel serialized after start, clearing the persisted pre-candidate
            let pendingAfter = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNil(pendingAfter, "Cancel must clear pre-candidate state persisted by start")
            let sessionAfter = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfter, initialSessionUUID, "Original session must remain intact")

            // Verify start can immediately be started again cleanly
            let authURL2 = try await client.startGatewayScopeUpgrade(
                requesting: ["identity:handle"],
                for: alice,
                callbackURL: callbackBase
            )
            XCTAssertEqual(authURL2.absoluteString, "https://auth.pds.test/oauth/authorize?req=123")
        }
    }

    func testCallerCancellationWhileQueuedRemovesOperationWithoutDeadlockingQueue() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.queued.cancellation.\(UUID().uuidString)"
            let initialSessionUUID = UUID().uuidString.lowercased()
            let (client, _) = try await self.makeClient(namespace: namespace, initialSession: initialSessionUUID)
            let alice = self.aliceDID
            let callbackBase = Self.validCallbackBase
            let op1Entered = TestAsyncGate()
            let op1Release = TestAsyncGate()

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
                    op1Entered.open()
                    op1Release.waitBlocking()
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

            // Task 1: start scope upgrade (will block in /auth/upgrade)
            let task1 = Task {
                try await client.startGatewayScopeUpgrade(
                    requesting: ["identity:handle"],
                    for: alice,
                    callbackURL: callbackBase
                )
            }

            await op1Entered.wait()

            // Task 2: complete scope upgrade (enqueued behind task 1)
            let incomingCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=auth-code-12345")!
            let task2 = Task {
                try await client.completeGatewayScopeUpgrade(
                    callbackURL: incomingCallback,
                    for: alice
                )
            }
            let task3 = Task {
                try await client.fetchGrantedScopes(for: alice)
            }

            // Cancel task 2 while queued
            task2.cancel()

            // Release task 1
            op1Release.open()

            let authURL = try await task1.value
            XCTAssertEqual(authURL.absoluteString, "https://auth.pds.test/oauth/authorize?req=123")

            do {
                _ = try await task2.value
                XCTFail("task2 should have thrown CancellationError")
            } catch is CancellationError {
                // Expected: task2 cancelled cleanly while queued
            } catch {
                XCTFail("task2 threw unexpected error: \(error)")
            }

            // Task 3 must have executed and succeeded without queue deadlock
            let scopes = try await task3.value
            XCTAssertTrue(scopes.contains("atproto"))
        }
    }

    func testCompleteBlockedInCommitQueuesPrepareAuthenticatedRequestReturningCandidateBearer() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.complete.blocked.prepare.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(oldSessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

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

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager
            )

            let commitEntered = TestAsyncGate()
            let commitRelease = TestAsyncGate()

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    commitEntered.open()
                    commitRelease.waitBlocking()
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = """
                    {
                        "status": "committed",
                        "session_id": "\(candidateUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (response, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let incomingCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=auth-code-12345")!
            let completeTask = Task {
                try await strategy.completeGatewayScopeUpgrade(
                    callbackURL: incomingCallback,
                    for: alice
                )
            }
            await commitEntered.wait()

            // At this point, commit is blocked holding the coordinator lock.
            // Pending candidate is in storage; storage gateway session is still oldSessionUUID.
            let sessionWhileBlocked = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionWhileBlocked, oldSessionUUID, "Storage session is oldSessionUUID while commit is in flight")

            let req = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
            let prepareTask = Task {
                try await strategy.prepareAuthenticatedRequest(req)
            }

            // Release commit
            commitRelease.open()

            let grants = try await completeTask.value
            XCTAssertTrue(grants.contains("identity:handle"))

            let authedReq = try await prepareTask.value
            XCTAssertEqual(
                authedReq.value(forHTTPHeaderField: "Authorization"),
                "Bearer \(candidateUUID)",
                "prepareAuthenticatedRequest must return the newly committed candidate session, never the old bearer"
            )

            let sessionAfter = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfter, candidateUUID)
        }
    }

    func testCompleteBlockedInCommitQueuesPrepareWithContextReturningCandidateBearer() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.complete.blocked.prepare.ctx.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(oldSessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

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

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager
            )

            let commitEntered = TestAsyncGate()
            let commitRelease = TestAsyncGate()

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    commitEntered.open()
                    commitRelease.waitBlocking()
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = """
                    {
                        "status": "committed",
                        "session_id": "\(candidateUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (response, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let incomingCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=auth-code-12345")!
            let completeTask = Task {
                try await strategy.completeGatewayScopeUpgrade(
                    callbackURL: incomingCallback,
                    for: alice
                )
            }
            await commitEntered.wait()

            let req = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
            let prepareTask = Task {
                try await strategy.prepareAuthenticatedRequestWithContext(req)
            }

            commitRelease.open()

            _ = try await completeTask.value
            let (authedReq, ctx) = try await prepareTask.value
            XCTAssertEqual(
                authedReq.value(forHTTPHeaderField: "Authorization"),
                "Bearer \(candidateUUID)",
                "prepareAuthenticatedRequestWithContext must return the candidate session"
            )
            XCTAssertNil(ctx.did)
            XCTAssertNil(ctx.jkt)
        }
    }

    func testRetryableCommitFailureQueuesPrepareWhichRunsRecoveryAndFailsClosedWhenRecoveryFails() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.retryable.commit.recovery.fail.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(oldSessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

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

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager
            )

            let commitEntered = TestAsyncGate()
            let commitRelease = TestAsyncGate()
            let commitCounter = TestAtomicCounter()

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    let count = commitCounter.increment()

                    if count == 1 {
                        // First attempt from completeGatewayScopeUpgrade: block then fail retryably (503)
                        commitEntered.open()
                        commitRelease.waitBlocking()
                        let response = HTTPURLResponse(
                            url: request.url!,
                            statusCode: 503,
                            httpVersion: nil,
                            headerFields: ["Content-Type": "application/json"]
                        )!
                        return (response, Data())
                    } else {
                        // Second attempt from recovery during prepare: fail terminal (400)
                        let response = HTTPURLResponse(
                            url: request.url!,
                            statusCode: 400,
                            httpVersion: nil,
                            headerFields: ["Content-Type": "application/json"]
                        )!
                        let body = """
                        {"error": "InvalidRequest", "message": "Commit rejected"}
                        """.data(using: .utf8)!
                        return (response, body)
                    }
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let incomingCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=auth-code-12345")!
            let completeTask = Task {
                try await strategy.completeGatewayScopeUpgrade(
                    callbackURL: incomingCallback,
                    for: alice
                )
            }
            await commitEntered.wait()

            let req = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
            let prepareTask = Task {
                try await strategy.prepareAuthenticatedRequest(req)
            }

            // Release the first commit attempt to fail with 503
            commitRelease.open()

            do {
                _ = try await completeTask.value
                XCTFail("completeGatewayScopeUpgrade must throw on 503")
            } catch {}

            // Queued prepare runs recovery, which encounters 400 and throws.
            // It MUST throw and NEVER return the old bearer.
            do {
                _ = try await prepareTask.value
                XCTFail("prepareAuthenticatedRequest must throw and never return old bearer when recovery fails")
            } catch {}

            // Verify old session and pending upgrade remain intact (no destructive clear)
            let sessionAfter = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfter, oldSessionUUID, "Old session remains intact in storage")
            let pendingAfter = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfter, "Pending candidate remains in storage for subsequent recovery")
        }
    }

    func testRetryableCommitFailureQueuesPrepareWhichRunsRecoveryAndSucceedsWithCandidateBearer() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.retryable.commit.recovery.success.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(oldSessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

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

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager
            )

            let commitEntered = TestAsyncGate()
            let commitRelease = TestAsyncGate()
            let commitCounter = TestAtomicCounter()

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    let count = commitCounter.increment()

                    if count == 1 {
                        // First attempt fails retryably
                        commitEntered.open()
                        commitRelease.waitBlocking()
                        let response = HTTPURLResponse(
                            url: request.url!,
                            statusCode: 503,
                            httpVersion: nil,
                            headerFields: ["Content-Type": "application/json"]
                        )!
                        return (response, Data())
                    } else {
                        // Second attempt from recovery succeeds
                        let response = HTTPURLResponse(
                            url: request.url!,
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: ["Content-Type": "application/json"]
                        )!
                        let body = """
                        {
                            "status": "committed",
                            "session_id": "\(candidateUUID)",
                            "did": "\(alice)",
                            "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                        }
                        """.data(using: .utf8)!
                        return (response, body)
                    }
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let incomingCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=auth-code-12345")!
            let completeTask = Task {
                try await strategy.completeGatewayScopeUpgrade(
                    callbackURL: incomingCallback,
                    for: alice
                )
            }
            await commitEntered.wait()

            let req = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
            let prepareTask = Task {
                try await strategy.prepareAuthenticatedRequest(req)
            }

            commitRelease.open()

            do {
                _ = try await completeTask.value
                XCTFail("completeGatewayScopeUpgrade must throw on 503")
            } catch {}

            // Queued prepare runs recovery, which succeeds and returns candidate bearer
            let authedReq = try await prepareTask.value
            XCTAssertEqual(
                authedReq.value(forHTTPHeaderField: "Authorization"),
                "Bearer \(candidateUUID)",
                "prepareAuthenticatedRequest after successful recovery must return candidate bearer"
            )

            let sessionAfter = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfter, candidateUUID, "Candidate promoted to active session")
            let pendingAfter = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNil(pendingAfter, "Pending state deleted after successful recovery")
        }
    }

    func testCallerCancellationOfQueuedPrepareCancelsCleanlyAndSubsequentPrepareSucceeds() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.queued.prepare.cancellation.\(UUID().uuidString)"
            let initialSessionUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(initialSessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager
            )

            let op1Entered = TestAsyncGate()
            let op1Release = TestAsyncGate()

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
                    op1Entered.open()
                    op1Release.waitBlocking()
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

            let task1 = Task {
                try await strategy.startGatewayScopeUpgrade(
                    requesting: ["identity:handle"],
                    for: alice,
                    callbackURL: Self.validCallbackBase
                )
            }
            await op1Entered.wait()

            let req = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
            let task2 = Task {
                try await strategy.prepareAuthenticatedRequest(req)
            }
            let task3 = Task {
                try await strategy.prepareAuthenticatedRequestWithContext(req)
            }
            let task4 = Task {
                await strategy.tokensExist()
            }

            // Cancel task 2 while queued
            task2.cancel()
            // Release task 1
            op1Release.open()

            let authURL = try await task1.value
            XCTAssertEqual(authURL.absoluteString, "https://auth.pds.test/oauth/authorize?req=123")

            do {
                _ = try await task2.value
                XCTFail("task2 should have thrown CancellationError")
            } catch is CancellationError {
                // Expected
            } catch {
                XCTFail("task2 threw unexpected error: \(error)")
            }

            // Task 3 must execute and succeed without coordinator deadlock
            let (authedReq3, ctx3) = try await task3.value
            XCTAssertEqual(authedReq3.value(forHTTPHeaderField: "Authorization"), "Bearer \(initialSessionUUID)")
            XCTAssertNil(ctx3.did)
            XCTAssertNil(ctx3.jkt)
            ctx3.releaseAuthenticationLease()

            // Task 4 must execute and succeed
            let tokensExist = await task4.value
            XCTAssertTrue(tokensExist)
        }
    }

    func testCompleteBlockedInCommitQueuesPrepareWithContextAndUnreleasedLeaseBlocksNextMutationUntilReleased() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.complete.blocked.prepare.unreleased.lease.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(oldSessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

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

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager
            )

            let commitEntered = TestAsyncGate()
            let commitRelease = TestAsyncGate()
            let logoutEntered = TestAsyncGate()

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/commit" {
                    commitEntered.open()
                    commitRelease.waitBlocking()
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = """
                    {
                        "status": "committed",
                        "session_id": "\(candidateUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (response, body)
                } else if path == "/auth/logout" {
                    logoutEntered.open()
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (response, "{}".data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let incomingCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=auth-code-12345")!
            let completeTask = Task {
                try await strategy.completeGatewayScopeUpgrade(
                    callbackURL: incomingCallback,
                    for: alice
                )
            }
            await commitEntered.wait()

            let req = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
            let prepareTask = Task {
                try await strategy.prepareAuthenticatedRequestWithContext(req)
            }

            commitRelease.open()

            _ = try await completeTask.value
            let (authedReq, ctx) = try await prepareTask.value
            XCTAssertEqual(
                authedReq.value(forHTTPHeaderField: "Authorization"),
                "Bearer \(candidateUUID)",
                "prepareAuthenticatedRequestWithContext must return the candidate session"
            )
            XCTAssertNotNil(ctx.lease, "AuthContext must carry an authentication request lease")

            // Start logout task while lease is unreleased - it must wait behind the lease
            let logoutTask = Task {
                try await strategy.logout()
            }

            // Yield execution to allow logoutTask to queue in coordinator
            await Task.yield()

            // Now release the lease from the prepared request
            ctx.releaseAuthenticationLease()

            // Logout should now proceed and enter the network handler
            await logoutEntered.wait()
            try await logoutTask.value

            let sessionAfter = try await storage.getGatewaySession(for: alice)
            XCTAssertNil(sessionAfter, "Session must be cleared after logout completes")
        }
    }

    func testNetworkServiceIntegrationPrepareRequestHoldsLeasePreventingConcurrentCandidateCommitUntilDataFinishes() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.networkservice.lease.race.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(oldSessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

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

            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [GatewayUpgradeTestURLProtocol.self]
            let customSession = URLSession(configuration: config)

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager,
                urlSession: customSession
            )

            let networkService = NetworkService(
                baseURL: self.gatewayURL,
                authService: strategy
            )

            let profileReqEntered = TestAsyncGate()
            let profileReqRelease = TestAsyncGate()
            let commitEntered = TestAsyncGate()

            let capturedAuthHeaders = TestThreadSafeArray<String>()

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path.contains("app.bsky.actor.getProfile") {
                    if let auth = request.value(forHTTPHeaderField: "Authorization") {
                        capturedAuthHeaders.append(auth)
                    }
                    profileReqEntered.open()
                    profileReqRelease.waitBlocking()
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (response, #"{"did":"\#(alice)","handle":"alice.test"}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade/exchange" {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = """
                    {
                        "candidate_session_id": "\(candidateUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (response, body)
                } else if path == "/auth/upgrade/commit" {
                    commitEntered.open()
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = """
                    {
                        "status": "committed",
                        "session_id": "\(candidateUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (response, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            let profileReq = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))

            // Launch request 1 through NetworkService - it prepares with oldSessionUUID and holds lease during session.data
            let profileTask1 = Task {
                try await networkService.request(profileReq)
            }
            await profileReqEntered.wait()

            // At this point, profileTask1 is suspended in session.data, holding the auth lease
            // Concurrently, candidate completion arrives:
            let incomingCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=auth-code-12345")!
            let completeTask = Task {
                try await strategy.completeGatewayScopeUpgrade(
                    callbackURL: incomingCallback,
                    for: alice
                )
            }

            // Yield execution to verify completeTask is queued and cannot persist/commit candidate yet
            await Task.yield()

            let sessionWhileInFlight = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionWhileInFlight, oldSessionUUID, "Session in storage must remain oldSessionUUID while request 1 is in flight")

            // Release profile request 1
            profileReqRelease.open()

            _ = try await profileTask1.value
            _ = try await completeTask.value

            let sessionAfterCommit = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterCommit, candidateUUID, "Session in storage must be candidateUUID after complete finishes")

            // Now send request 2 through NetworkService - it must use the new candidateUUID
            let (data2, res2) = try await networkService.request(profileReq)
            XCTAssertEqual((res2 as? HTTPURLResponse)?.statusCode, 200)
            XCTAssertFalse(data2.isEmpty)

            let headers = capturedAuthHeaders.values
            XCTAssertEqual(headers.count, 2)
            XCTAssertEqual(headers[0], "Bearer \(oldSessionUUID)", "First request must have sent old bearer while authoritative")
            XCTAssertEqual(headers[1], "Bearer \(candidateUUID)", "Second request must have sent candidate bearer")
        }
    }

    func testExactAndGeneratedAndStreamingPathsReleaseLeaseOnThrownTransportAndSuccess() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.paths.lease.release.\(UUID().uuidString)"
            let sessionUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(sessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [GatewayUpgradeTestURLProtocol.self]
            let customSession = URLSession(configuration: config)

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager,
                urlSession: customSession
            )

            let networkService = NetworkService(
                baseURL: self.gatewayURL,
                authService: strategy
            )

            // 1. Streaming path: prepareStreamingRequest returns PreparedStreamingRequest holding lease until released
            let streamReq = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/com.atproto.sync.subscribeRepos"))
            let preparedStream = try await networkService.prepareStreamingRequest(streamReq)
            XCTAssertEqual(preparedStream.request.value(forHTTPHeaderField: "Authorization"), "Bearer \(sessionUUID)")

            // Release lease as caller (e.g. SSE query after handshake)
            preparedStream.releaseAuthenticationLease()

            // Verify coordinator is free (tokensExist succeeds immediately)
            let tokensExist1 = await strategy.tokensExist()
            XCTAssertTrue(tokensExist1)

            // 2. Simple request path: transport throws error -> lease released
            GatewayUpgradeTestURLProtocol.setHandler { _ in
                throw URLError(.timedOut)
            }

            let profileReq = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
            do {
                _ = try await networkService.request(profileReq)
                XCTFail("Should have thrown error")
            } catch {
                // Expected
            }

            // Verify coordinator is free
            let tokensExist2 = await strategy.tokensExist()
            XCTAssertTrue(tokensExist2)

            // 3. Retry loop path: non-retryable transport error -> lease released immediately without loop delay
            GatewayUpgradeTestURLProtocol.setHandler { _ in
                throw URLError(.badServerResponse)
            }
            do {
                _ = try await networkService.request(profileReq, skipTokenRefresh: false)
                XCTFail("Should have thrown error")
            } catch {
                // Expected
            }
            // Verify coordinator is free
            let tokensExist3 = await strategy.tokensExist()
            XCTAssertTrue(tokensExist3)

            // 4. Successful request path -> lease released
            GatewayUpgradeTestURLProtocol.setHandler { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (response, #"{"status":"ok"}"#.data(using: .utf8)!)
            }

            let (data, res) = try await networkService.request(profileReq)
            XCTAssertEqual((res as? HTTPURLResponse)?.statusCode, 200)
            XCTAssertFalse(data.isEmpty)

            // Verify coordinator is free
            let tokensExist4 = await strategy.tokensExist()
            XCTAssertTrue(tokensExist4)
        }
    }

    func testCoordinatorCancellationInRegistrationWindowViaHookAndLaterOperationProceeds() async throws {
        let coordinator = ConfidentialGatewayStrategy.SerialOperationCoordinator()

        // 1. Acquire initial lease so coordinator is held
        let lease1 = try await coordinator.acquireLease()

        let registrationHookEntered = TestAsyncGate()
        let cancelSignal = TestAsyncGate()

        coordinator._onBeforeRegistration = { _ in
            registrationHookEntered.open()
            cancelSignal.waitBlocking()
        }

        // 2. Launch task 2 that attempts to acquire lease
        let task2 = Task {
            try await coordinator.acquireLease()
        }

        // Wait until task 2 reaches the registration window before lock acquisition
        await registrationHookEntered.wait()

        // Cancel task 2 in the exact registration window
        task2.cancel()
        cancelSignal.open()

        // Task 2 must throw CancellationError and not be queued
        do {
            _ = try await task2.value
            XCTFail("Task 2 should have thrown CancellationError")
        } catch is CancellationError {
            // Expected
        } catch {
            XCTFail("Task 2 threw unexpected error: \(error)")
        }

        // Reset hook
        coordinator._onBeforeRegistration = nil

        // 3. Release lease 1
        lease1.release()

        // 4. Task 3 must acquire lease immediately without being blocked or wedged
        let lease3 = try await coordinator.acquireLease()
        lease3.release()
    }

    func testBlockedCandidateCompletionCannotPersistOrCommitBetweenSSEPrepareAndLaunchAndReleasesAfterHandshake() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.sse.lease.race.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(oldSessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

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

            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [GatewayUpgradeTestURLProtocol.self]
            let customSession = URLSession(configuration: config)

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager,
                urlSession: customSession
            )

            let networkService = NetworkService(
                baseURL: self.gatewayURL,
                authService: strategy
            )

            let commitEntered = TestAsyncGate()

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/exchange" {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = """
                    {
                        "candidate_session_id": "\(candidateUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (response, body)
                } else if path == "/auth/upgrade/commit" {
                    commitEntered.open()
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = """
                    {
                        "status": "committed",
                        "session_id": "\(candidateUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (response, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            // 1. Prepare streaming request - holds lease in PreparedStreamingRequest
            let streamReq = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/com.atproto.sync.subscribeRepos"))
            let preparedStream = try await networkService.prepareStreamingRequest(streamReq)
            XCTAssertEqual(preparedStream.request.value(forHTTPHeaderField: "Authorization"), "Bearer \(oldSessionUUID)")

            // 2. Concurrently, candidate completion arrives
            let incomingCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=auth-code-12345")!
            let completeTask = Task {
                try await strategy.completeGatewayScopeUpgrade(
                    callbackURL: incomingCallback,
                    for: alice
                )
            }

            // Yield execution to verify completeTask is queued behind the streaming lease
            await Task.yield()

            // Verify session in storage is still oldSessionUUID while lease is held
            let sessionWhilePrepared = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionWhilePrepared, oldSessionUUID, "Session in storage must remain oldSessionUUID while SSE lease is held")

            // 3. Simulate SSE handshake returning and releasing lease
            preparedStream.releaseAuthenticationLease()

            // 4. Upgrade completion should now proceed and commit
            await commitEntered.wait()
            _ = try await completeTask.value

            let sessionAfterCommit = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterCommit, candidateUUID, "Session in storage must be candidateUUID after upgrade completes")
        }
    }

    func testBlockedCandidateCompletionCannotPersistOrCommitBetweenWebSocketPrepareAndResumeAndReleasesAfterResume() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.ws.lease.race.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(oldSessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

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

            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [GatewayUpgradeTestURLProtocol.self]
            let customSession = URLSession(configuration: config)

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager,
                urlSession: customSession
            )

            let networkService = NetworkService(
                baseURL: self.gatewayURL,
                authService: strategy
            )

            let commitEntered = TestAsyncGate()

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/upgrade/exchange" {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = """
                    {
                        "candidate_session_id": "\(candidateUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (response, body)
                } else if path == "/auth/upgrade/commit" {
                    commitEntered.open()
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    let body = """
                    {
                        "status": "committed",
                        "session_id": "\(candidateUUID)",
                        "did": "\(alice)",
                        "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                    }
                    """.data(using: .utf8)!
                    return (response, body)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            struct DummyMessage: Codable, Sendable {}

            // 1. Subscribe to WebSocket endpoint
            let stream: AsyncThrowingStream<DummyMessage, Error> = try await networkService.subscribe(
                endpoint: "com.atproto.sync.subscribeRepos",
                parameters: nil as (any Parametrizable)?
            )
            _ = stream

            // 2. Once subscribe returns, the lease has already been released after task resume
            // Complete task should be able to acquire coordinator lease immediately
            let incomingCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=auth-code-12345")!
            let completeTask = Task {
                try await strategy.completeGatewayScopeUpgrade(
                    callbackURL: incomingCallback,
                    for: alice
                )
            }

            await commitEntered.wait()
            _ = try await completeTask.value

            let sessionAfterCommit = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterCommit, candidateUUID, "Session in storage must be candidateUUID after upgrade completes")
        }
    }
    func testWebSocketAuthFailureThrowsAuthenticationFailedAndEmitsNoWebSocketTask() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.ws.auth.failure.\(UUID().uuidString)"
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            // No gateway session saved in storage -> prepareAuthenticatedRequest will fail

            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [GatewayUpgradeTestURLProtocol.self]
            let customSession = URLSession(configuration: config)

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager,
                urlSession: customSession
            )

            let networkService = NetworkService(
                baseURL: self.gatewayURL,
                authService: strategy
            )

            struct DummyMessage: Codable, Sendable {}

            do {
                let _: AsyncThrowingStream<DummyMessage, Error> = try await networkService.subscribe(
                    endpoint: "com.atproto.sync.subscribeRepos",
                    parameters: nil as (any Parametrizable)?
                )
                XCTFail("Should have thrown NetworkError.authenticationFailed")
            } catch let error as NetworkError {
                switch error {
                case .authenticationFailed:
                    // Expected!
                    break
                default:
                    XCTFail("Unexpected NetworkError: \(error)")
                }
            } catch {
                XCTFail("Unexpected error thrown: \(error)")
            }

            // Verify coordinator is not wedged
            let tokensExist = await strategy.tokensExist()
            XCTAssertFalse(tokensExist)
        }
    }

    func testSSETransportThrowReleasesLeaseImmediately() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.sse.throw.release.\(UUID().uuidString)"
            let sessionUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(sessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager
            )

            let networkService = NetworkService(
                baseURL: self.gatewayURL,
                authService: strategy
            )

            let streamReq = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/com.atproto.sync.subscribeRepos"))
            do {
                let prepared = try await networkService.prepareStreamingRequest(streamReq)
                defer {
                    prepared.releaseAuthenticationLease()
                }
                // Simulate transport throwing
                throw URLError(.cannotConnectToHost)
            } catch {
                // Expected throw
            }

            // Coordinator lease must be free immediately
            let tokensExist = await strategy.tokensExist()
            XCTAssertTrue(tokensExist)
        }
    }

    func testStaleUnauthorizedDoesNotDeletePromotedCandidateOrAutoLogout() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.stale.401.candidate.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(oldSessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager
            )

            let dummyReq = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
            let (oldPreparedReq, authCtx) = try await strategy.prepareAuthenticatedRequestWithContext(dummyReq)
            // Release lease so candidate promotion can proceed
            authCtx.releaseAuthenticationLease()

            // Promote candidate session
            let casResult = try await storage.compareAndSwapGatewaySession(
                expectedOldSession: oldSessionUUID,
                newSession: candidateUUID,
                for: alice
            )
            XCTAssertTrue(casResult)
            let storedBefore401 = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(storedBefore401, candidateUUID)

            // Deliver terminal 401 for old request
            let gateway401Response = HTTPURLResponse(
                url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"),
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let terminal401Body = #"{"error":"invalid_session","message":"Session has been revoked"}"#.data(using: .utf8)!

            do {
                _ = try await strategy.handleUnauthorizedResponse(
                    gateway401Response,
                    data: terminal401Body,
                    for: oldPreparedReq
                )
                XCTFail("handleUnauthorizedResponse should throw authenticationRequired for stale 401")
            } catch let error as ConfidentialGatewayStrategy.GatewayError {
                guard case .authenticationRequired = error else {
                    XCTFail("Expected .authenticationRequired, got \(error)")
                    return
                }
            } catch {
                XCTFail("Unexpected error: \(error)")
            }

            // Promoted candidate must remain intact, no session deletion or auto-logout
            let storedAfter401 = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(storedAfter401, candidateUUID)
            let currentDIDAfter401 = try await storage.getCurrentDID()
            XCTAssertEqual(currentDIDAfter401, alice)
        }
    }

    func testMatchingBearer401DeletesSessionAndThrowsSessionExpired() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.matching.401.delete.\(UUID().uuidString)"
            let currentSessionUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(currentSessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager
            )

            let dummyReq = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
            let (preparedReq, authCtx) = try await strategy.prepareAuthenticatedRequestWithContext(dummyReq)
            authCtx.releaseAuthenticationLease()

            let gateway401Response = HTTPURLResponse(
                url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"),
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let terminal401Body = #"{"error":"invalid_session","message":"Session has expired"}"#.data(using: .utf8)!

            do {
                _ = try await strategy.handleUnauthorizedResponse(
                    gateway401Response,
                    data: terminal401Body,
                    for: preparedReq
                )
                XCTFail("handleUnauthorizedResponse should throw sessionExpired for matching 401")
            } catch let error as ConfidentialGatewayStrategy.GatewayError {
                guard case .sessionExpired = error else {
                    XCTFail("Expected .sessionExpired, got \(error)")
                    return
                }
            } catch {
                XCTFail("Unexpected error: \(error)")
            }

            // Matching session must be deleted
            let storedAfter401 = try await storage.getGatewaySession(for: alice)
            XCTAssertNil(storedAfter401)
        }
    }

    func testMalformedOrMissingBearer401CannotDeleteSession() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.malformed.401.\(UUID().uuidString)"
            let currentSessionUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(currentSessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager
            )

            let gateway401Response = HTTPURLResponse(
                url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"),
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let terminal401Body = #"{"error":"invalid_session","message":"Session has expired"}"#.data(using: .utf8)!

            // Case 1: Missing Authorization header
            let missingAuthReq = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
            do {
                _ = try await strategy.handleUnauthorizedResponse(
                    gateway401Response,
                    data: terminal401Body,
                    for: missingAuthReq
                )
                XCTFail("Expected throw for missing auth header")
            } catch let error as ConfidentialGatewayStrategy.GatewayError {
                guard case .authenticationRequired = error else {
                    XCTFail("Expected .authenticationRequired, got \(error)")
                    return
                }
            }
            let sessionAfterCase1 = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterCase1, currentSessionUUID)

            // Case 2: Malformed Bearer (no token)
            var emptyBearerReq = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
            emptyBearerReq.setValue("Bearer ", forHTTPHeaderField: "Authorization")
            do {
                _ = try await strategy.handleUnauthorizedResponse(
                    gateway401Response,
                    data: terminal401Body,
                    for: emptyBearerReq
                )
                XCTFail("Expected throw for empty bearer")
            } catch let error as ConfidentialGatewayStrategy.GatewayError {
                guard case .authenticationRequired = error else {
                    XCTFail("Expected .authenticationRequired, got \(error)")
                    return
                }
            }
            let sessionAfterCase2 = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterCase2, currentSessionUUID)

            // Case 3: Multiple tokens in Bearer header
            var multiTokenReq = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
            multiTokenReq.setValue("Bearer \(currentSessionUUID) extra", forHTTPHeaderField: "Authorization")
            do {
                _ = try await strategy.handleUnauthorizedResponse(
                    gateway401Response,
                    data: terminal401Body,
                    for: multiTokenReq
                )
                XCTFail("Expected throw for multi-token bearer")
            } catch let error as ConfidentialGatewayStrategy.GatewayError {
                guard case .authenticationRequired = error else {
                    XCTFail("Expected .authenticationRequired, got \(error)")
                    return
                }
            }
            let sessionAfterCase3 = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterCase3, currentSessionUUID)

            // Case 4: Non-Bearer scheme
            var basicAuthReq = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
            basicAuthReq.setValue("Basic dXNlcjpwYXNz", forHTTPHeaderField: "Authorization")
            do {
                _ = try await strategy.handleUnauthorizedResponse(
                    gateway401Response,
                    data: terminal401Body,
                    for: basicAuthReq
                )
                XCTFail("Expected throw for basic auth header")
            } catch let error as ConfidentialGatewayStrategy.GatewayError {
                guard case .authenticationRequired = error else {
                    XCTFail("Expected .authenticationRequired, got \(error)")
                    return
                }
            }
            let sessionAfterCase4 = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfterCase4, currentSessionUUID)
        }
    }

    func testKeychainStorageDeleteGatewaySessionIfMatchesExactBehavior() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.keychain.delete.ifmatches.\(UUID().uuidString)"
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)

            // 1. Missing session -> returns false
            let missingResult = try await storage.deleteGatewaySession(ifMatches: "some-session", for: alice)
            XCTAssertFalse(missingResult)

            // 2. Save session-A
            try await storage.saveGatewaySession("session-A", for: alice)
            let session1 = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(session1, "session-A")

            // 3. Mismatched session-B -> returns false, session-A remains
            let mismatchResult = try await storage.deleteGatewaySession(ifMatches: "session-B", for: alice)
            XCTAssertFalse(mismatchResult)
            let session2 = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(session2, "session-A")

            // 4. Matching session-A -> returns true, session deleted
            let matchResult = try await storage.deleteGatewaySession(ifMatches: "session-A", for: alice)
            XCTAssertTrue(matchResult)
            let session3 = try await storage.getGatewaySession(for: alice)
            XCTAssertNil(session3)

            // 5. Subsequent delete on now-empty -> returns false
            let emptyResult = try await storage.deleteGatewaySession(ifMatches: "session-A", for: alice)
            XCTAssertFalse(emptyResult)
        }
    }

    func testCrossInstanceStaleCacheCompareDeleteObservesAuthoritativeBackendValueAndPreservesNewerSession() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.stale.cache.comparedelete.\(UUID().uuidString)"
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let oldSession = "session-v1-old"
            let newerSession = "session-v2-newer"

            // 1. Store oldSession through storage and warm KeychainManager's in-memory cache
            try await storage.saveGatewaySession(oldSession, for: alice)
            try await storage.saveCurrentDID(alice)
            let cachedSession = try await storage.getGatewaySession(for: alice)
            let cachedDID = try await storage.getCurrentDID()
            XCTAssertEqual(cachedSession, oldSession)
            XCTAssertEqual(cachedDID, alice)

            // 2. Simulate external cross-instance write: mutate backend directly to newerSession without clearing cache
            backend.plant(key: "gatewaySession.\(alice)", namespace: namespace, data: newerSession.data(using: .utf8)!)

            // 3. Stale 401 arrives presenting oldSession -> call deleteGatewaySession(ifMatches: oldSession, for: alice)
            // Authoritative bypassCache: true reads newerSession from backend, detects mismatch, returns false
            let deleted = try await storage.deleteGatewaySession(ifMatches: oldSession, for: alice)
            XCTAssertFalse(deleted, "Compare-delete must return false when backend has newer session")

            // 4. Verify newerSession is preserved in backend
            let backendData = backend.peek(key: "gatewaySession.\(alice)", namespace: namespace)
            XCTAssertNotNil(backendData)
            XCTAssertEqual(String(data: backendData!, encoding: .utf8), newerSession, "Newer session must be preserved in backend")

            // 5. Subsequent delete matching the actual authoritative session returns true and deletes it
            let deletedNewer = try await storage.deleteGatewaySession(ifMatches: newerSession, for: alice)
            XCTAssertTrue(deletedNewer)
            let peekAfterDelete = backend.peek(key: "gatewaySession.\(alice)", namespace: namespace)
            XCTAssertNil(peekAfterDelete)
        }
    }

    func testCrossInstanceStaleCacheCASObservesAuthoritativeBackendValueAndPreservesNewerSession() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.stale.cache.cas.session.\(UUID().uuidString)"
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let oldSession = "session-v1-old"
            let newerSession = "session-v2-newer"

            // 1. Store oldSession through storage and warm KeychainManager's cache
            try await storage.saveGatewaySession(oldSession, for: alice)
            try await storage.saveCurrentDID(alice)
            let cachedSession = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(cachedSession, oldSession)

            // 2. Mutate backend directly to newerSession without clearing cache
            backend.plant(key: "gatewaySession.\(alice)", namespace: namespace, data: newerSession.data(using: .utf8)!)

            // 3. Attempt CAS expecting oldSession
            let casResult = try await storage.compareAndSwapGatewaySession(
                expectedOldSession: oldSession,
                newSession: "session-v3-candidate",
                for: alice
            )
            XCTAssertFalse(casResult, "CAS must fail when backend authoritative session does not match expectedOldSession")

            // 4. Newer session must remain in backend
            let backendData = backend.peek(key: "gatewaySession.\(alice)", namespace: namespace)
            XCTAssertNotNil(backendData)
            XCTAssertEqual(String(data: backendData!, encoding: .utf8), newerSession)
        }
    }

    func testCrossInstanceStaleCacheCASObservesAuthoritativeCurrentDIDAndPreservesSession() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.stale.cache.cas.did.\(UUID().uuidString)"
            let alice = self.aliceDID
            let bob = self.bobDID
            let storage = KeychainStorage(namespace: namespace)
            let session = "session-alice-1"

            // 1. Store session and currentDID = alice and warm cache
            try await storage.saveGatewaySession(session, for: alice)
            try await storage.saveCurrentDID(alice)
            let cachedDID = try await storage.getCurrentDID()
            XCTAssertEqual(cachedDID, alice)

            // 2. Mutate backend currentDID directly to bob without clearing cache
            backend.plant(key: "currentDID", namespace: namespace, data: bob.data(using: .utf8)!)

            // 3. Attempt CAS for alice expecting session
            let casResult = try await storage.compareAndSwapGatewaySession(
                expectedOldSession: session,
                newSession: "session-alice-promoted",
                for: alice
            )
            XCTAssertFalse(casResult, "CAS must fail when backend authoritative currentDID does not match target DID")

            // 4. Verify alice's session is untouched
            let backendData = backend.peek(key: "gatewaySession.\(alice)", namespace: namespace)
            XCTAssertNotNil(backendData)
            XCTAssertEqual(String(data: backendData!, encoding: .utf8), session)
        }
    }

    func testSSEStreamTerminationCancelsProducerAndReleasesLease() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.sse.termination.lease.\(UUID().uuidString)"
            let sessionUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(sessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

            let strategy = ConfidentialGatewayStrategy(
                gatewayURL: self.gatewayURL,
                storage: storage,
                accountManager: accountManager
            )

            let networkService = NetworkService(
                baseURL: self.gatewayURL,
                authService: strategy
            )

            let streamReq = URLRequest(url: self.gatewayURL.appendingPathComponent("xrpc/com.atproto.sync.subscribeRepos"))
            let leaseAcquired = TestAsyncGate()

            let stream = AsyncThrowingStream<String, Error> { continuation in
                let producerTask = Task {
                    do {
                        let preparedRequest = try await networkService.prepareStreamingRequest(streamReq)
                        defer {
                            preparedRequest.releaseAuthenticationLease()
                        }
                        leaseAcquired.open()

                        while !Task.isCancelled {
                            try await Task.sleep(nanoseconds: 50_000_000)
                        }
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }
                    continuation.finish()
                }

                continuation.onTermination = { @Sendable _ in
                    producerTask.cancel()
                }
            }

            let consumerTask = Task {
                for try await _ in stream {
                    break
                }
            }

            await leaseAcquired.wait()

            consumerTask.cancel()
            _ = try? await consumerTask.value

            try await Task.sleep(nanoseconds: 100_000_000)

            let tokensExist = await strategy.tokensExist()
            XCTAssertTrue(tokensExist, "Coordinator lease must be free after SSE stream termination")
        }
    }

    func testTerminal401WithItemStoreErrorPreservesPendingStateAndEmitsNoAutoLogout() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.terminal.401.itemstoreerror.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(oldSessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

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
            try await storage.savePendingGatewayUpgradeData(pendingState, for: alice)

            let logoutEvents = TestThreadSafeArray<AuthEvent>()
            await AuthEventBroadcaster.shared.addObserver { event in
                if case .autoLogoutTriggered = event {
                    logoutEvents.append(event)
                }
            }
            defer {
                Task {
                    await AuthEventBroadcaster.shared.removeAllObservers()
                }
            }

            backend.failStoreMatching = { key in
                key.contains("gatewaySession")
            }

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
            let terminal401Body = #"{"error":"invalid_session","message":"The token has expired"}"#.data(using: .utf8)!

            do {
                _ = try await strategy.handleUnauthorizedResponse(
                    gateway401Response,
                    data: terminal401Body,
                    for: req
                )
                XCTFail("handleUnauthorizedResponse must throw when recovery fails on terminal 401")
            } catch let error as ConfidentialGatewayStrategy.GatewayError {
                guard case .upgradeTemporarilyUnavailable = error else {
                    XCTFail("Expected .upgradeTemporarilyUnavailable, got \(error)")
                    return
                }
            } catch {
                XCTFail("Expected GatewayError, got \(error)")
            }

            await PetrelAuthEvents.drain()

            XCTAssertEqual(logoutEvents.values.count, 0, "No autoLogoutTriggered event must be broadcast for retryable itemStoreError")

            let sessionAfter401 = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(sessionAfter401, oldSessionUUID, "Old session must NOT be deleted after terminal 401 when recovery fails with itemStoreError")
            let pendingAfter401 = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNotNil(pendingAfter401, "Pending upgrade state must NOT be deleted after terminal 401 when recovery fails with itemStoreError")

            backend.failStoreMatching = nil
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

            try await strategy.attemptRecoveryFromServerFailures(for: alice)
            let promotedSession = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(promotedSession, candidateUUID, "Candidate session must be promoted once storage recovers")
        }
    }

    func testTerminal401WithDeletionErrorPreservesPendingStateAndEmitsNoAutoLogout() async throws {
        try await withInMemoryBackend { backend in
            let namespace = "test.gateway.terminal.401.deletionerror.\(UUID().uuidString)"
            let oldSessionUUID = UUID().uuidString.lowercased()
            let candidateUUID = UUID().uuidString.lowercased()
            let alice = self.aliceDID
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let account = Account(did: alice, handle: "alice.test", pdsURL: self.gatewayURL)
            try await storage.saveAccount(account, for: alice)
            try await storage.saveGatewaySession(oldSessionUUID, for: alice)
            try await storage.saveCurrentDID(alice)
            try await accountManager.updateAccountFromStorage(did: alice)
            try await accountManager.setCurrentAccount(did: alice)

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
            try await storage.savePendingGatewayUpgradeData(pendingState, for: alice)

            let logoutEvents = TestThreadSafeArray<AuthEvent>()
            await AuthEventBroadcaster.shared.addObserver { event in
                if case .autoLogoutTriggered = event {
                    logoutEvents.append(event)
                }
            }
            defer {
                Task {
                    await AuthEventBroadcaster.shared.removeAllObservers()
                }
            }

            backend.failDeleteMatching = { key in
                key.contains("pendingGatewayUpgrade")
            }

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
            let terminal401Body = #"{"error":"invalid_session","message":"The token has expired"}"#.data(using: .utf8)!

            do {
                _ = try await strategy.handleUnauthorizedResponse(
                    gateway401Response,
                    data: terminal401Body,
                    for: req
                )
                XCTFail("handleUnauthorizedResponse must throw when recovery fails on terminal 401")
            } catch let error as ConfidentialGatewayStrategy.GatewayError {
                guard case .upgradeTemporarilyUnavailable = error else {
                    XCTFail("Expected .upgradeTemporarilyUnavailable, got \(error)")
                    return
                }
            } catch {
                XCTFail("Expected GatewayError, got \(error)")
            }

            await PetrelAuthEvents.drain()

            XCTAssertEqual(logoutEvents.values.count, 0, "No autoLogoutTriggered event must be broadcast for retryable deletionError")

            backend.failDeleteMatching = nil
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

            try await strategy.attemptRecoveryFromServerFailures(for: alice)
            let promotedSession = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(promotedSession, candidateUUID, "Candidate session must be promoted once deletion error clears")
            let pendingAfterSuccess = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertNil(pendingAfterSuccess, "Pending upgrade data must be cleaned up on promotion")
        }
    }
}
