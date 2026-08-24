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

// MARK: - Test Suite

final class ConfidentialGatewayScopeUpgradeTests: XCTestCase {
    private static let gatewayURL = URL(string: "https://gateway.catbird.test")!
    private static let validCallbackBase = URL(string: "https://catbird.blue/oauth/permission-callback")!
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
        initialSession: String = "session-alice-initial"
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
        let namespace = "test.gateway.upgrade.start.\(UUID().uuidString)"
        let (client, storage) = try await makeClient(namespace: namespace)

        GatewayUpgradeTestURLProtocol.setHandler { request in
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

        let requestedScopes: Set<String> = ["identity:handle", "account:email?action=manage"]
        let authURL = try await client.startGatewayScopeUpgrade(
            requesting: requestedScopes,
            for: aliceDID,
            callbackURL: validCallbackBase
        )

        XCTAssertEqual(authURL.absoluteString, "https://auth.pds.test/oauth/authorize?req=123")

        let reqs = GatewayUpgradeTestURLProtocol.recordedRequests()
        guard let req = reqs.first(where: { $0.url?.path == "/auth/upgrade" }) else {
            XCTFail("No /auth/upgrade request captured")
            return
        }

        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.url?.path, "/auth/upgrade")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer session-alice-initial")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")

        // Inspect body
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
        let currentSession = try await storage.getGatewaySession(for: aliceDID)
        XCTAssertEqual(currentSession, "session-alice-initial")
        let currentDID = try await storage.getCurrentDID()
        XCTAssertEqual(currentDID, aliceDID)
    }

    func testStartUpgradeRejectsInvalidScopesAndCallbacks() async throws {
        let namespace = "test.gateway.upgrade.start.invalid.\(UUID().uuidString)"
        let (client, _) = try await makeClient(namespace: namespace)

        // 1. Empty scope set
        do {
            _ = try await client.startGatewayScopeUpgrade(requesting: [], for: aliceDID, callbackURL: validCallbackBase)
            XCTFail("Expected failure for empty scopes")
        } catch {}

        // 2. Unbounded scope set (> 16)
        let tooManyScopes = Set((0..<17).map { "scope:\($0)" })
        do {
            _ = try await client.startGatewayScopeUpgrade(requesting: tooManyScopes, for: aliceDID, callbackURL: validCallbackBase)
            XCTFail("Expected failure for >16 scopes")
        } catch {}

        // 3. Unbounded single scope (> 128 chars)
        let longScope = String(repeating: "a", count: 129)
        do {
            _ = try await client.startGatewayScopeUpgrade(requesting: [longScope], for: aliceDID, callbackURL: validCallbackBase)
            XCTFail("Expected failure for >128-char scope")
        } catch {}

        // 4. Wildcard scope
        do {
            _ = try await client.startGatewayScopeUpgrade(requesting: ["repo:*"], for: aliceDID, callbackURL: validCallbackBase)
            XCTFail("Expected failure for wildcard scope")
        } catch {}

        // 5. Whitespace scope
        do {
            _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle "], for: aliceDID, callbackURL: validCallbackBase)
            XCTFail("Expected failure for whitespace in scope")
        } catch {}

        // 6. Wrong active DID
        do {
            _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: bobDID, callbackURL: validCallbackBase)
            XCTFail("Expected failure for mismatched DID")
        } catch {}

        // 7. Insecure or malformed callback URL (http instead of https)
        let insecureCallback = URL(string: "http://catbird.blue/oauth/callback")!
        do {
            _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: aliceDID, callbackURL: insecureCallback)
            XCTFail("Expected failure for insecure callback")
        } catch {}

        // 8. Callback URL with query or fragment
        let callbackWithQuery = URL(string: "https://catbird.blue/oauth/callback?foo=bar")!
        do {
            _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: aliceDID, callbackURL: callbackWithQuery)
            XCTFail("Expected failure for callback with query")
        } catch {}

        let callbackWithFragment = URL(string: "https://catbird.blue/oauth/callback#fragment")!
        do {
            _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: aliceDID, callbackURL: callbackWithFragment)
            XCTFail("Expected failure for callback with fragment")
        } catch {}
    }

    // MARK: - 2. Complete Scope Upgrade Flow Tests

    func testCompleteUpgradeSuccessFlow() async throws {
        let namespace = "test.gateway.upgrade.complete.\(UUID().uuidString)"
        let (client, storage) = try await makeClient(namespace: namespace)

        let alice = Self.aliceDID

        GatewayUpgradeTestURLProtocol.setHandler { request in
            let path = request.url?.path ?? ""
            if path == "/auth/upgrade" {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                let body = #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=1"}"#.data(using: .utf8)!
                return (resp, body)
            } else if path == "/auth/upgrade/exchange" {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                let body = """
                {
                    "candidate_session_id": "candidate-session-uuid-1234",
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
                    "session_id": "candidate-session-uuid-1234",
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
            for: aliceDID,
            callbackURL: validCallbackBase
        )

        // Complete with valid code
        let incomingCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=auth-code-12345")!
        let granted = try await client.completeGatewayScopeUpgrade(callbackURL: incomingCallback, for: aliceDID)

        let reqs = GatewayUpgradeTestURLProtocol.recordedRequests()
        let capturedExchangeReq = reqs.first(where: { $0.url?.path == "/auth/upgrade/exchange" })
        let capturedCommitReq = reqs.first(where: { $0.url?.path == "/auth/upgrade/commit" })

        XCTAssertNotNil(capturedExchangeReq)
        XCTAssertNotNil(capturedCommitReq)
        XCTAssertEqual(granted, ["atproto", "transition:generic", "identity:handle"])

        // Verify exchange request
        XCTAssertEqual(capturedExchangeReq?.value(forHTTPHeaderField: "Authorization"), "Bearer session-alice-initial")
        XCTAssertEqual(capturedExchangeReq?.value(forHTTPHeaderField: "Origin"), "https://gateway.catbird.test")

        // Verify commit request uses candidate bearer
        XCTAssertEqual(capturedCommitReq?.value(forHTTPHeaderField: "Authorization"), "Bearer candidate-session-uuid-1234")

        // Verify local session is now promoted
        let upgradedSession = try await storage.getGatewaySession(for: aliceDID)
        XCTAssertEqual(upgradedSession, "candidate-session-uuid-1234")
    }

    // MARK: - 3. Commit/Network/Storage Failure, Candidate Durability, Idempotent Retry & CAS

    func testCommitFailureAllowsIdempotentRetryWithoutReExchange() async throws {
        let namespace = "test.gateway.upgrade.retry.\(UUID().uuidString)"
        let (client, storage) = try await makeClient(namespace: namespace)

        let shouldFailCommit = Mutex<Bool>(true)
        let alice = Self.aliceDID

        GatewayUpgradeTestURLProtocol.setHandler { request in
            let path = request.url?.path ?? ""
            if path == "/auth/upgrade" {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=1"}"#.data(using: .utf8)!)
            } else if path == "/auth/upgrade/exchange" {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                let body = """
                {
                    "candidate_session_id": "candidate-session-uuid-retry",
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
                        "session_id": "candidate-session-uuid-retry",
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
            for: aliceDID,
            callbackURL: validCallbackBase
        )

        let incomingCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=auth-code-retry-1")!

        // First attempt fails at commit
        do {
            _ = try await client.completeGatewayScopeUpgrade(callbackURL: incomingCallback, for: aliceDID)
            XCTFail("Expected commit 503 failure")
        } catch {}

        let firstReqs = GatewayUpgradeTestURLProtocol.recordedRequests()
        let firstExchangeCount = firstReqs.filter({ $0.url?.path == "/auth/upgrade/exchange" }).count
        let firstCommitCount = firstReqs.filter({ $0.url?.path == "/auth/upgrade/commit" }).count
        XCTAssertEqual(firstExchangeCount, 1)
        XCTAssertEqual(firstCommitCount, 1)

        // Stored session MUST still be old session
        let midSession = try await storage.getGatewaySession(for: aliceDID)
        XCTAssertEqual(midSession, "session-alice-initial")

        // Retry complete: must NOT call exchange again because candidate is durably saved!
        shouldFailCommit.withLock { $0 = false }
        let granted = try await client.completeGatewayScopeUpgrade(callbackURL: incomingCallback, for: aliceDID)

        let secondReqs = GatewayUpgradeTestURLProtocol.recordedRequests()
        let secondExchangeCount = secondReqs.filter({ $0.url?.path == "/auth/upgrade/exchange" }).count
        let secondCommitCount = secondReqs.filter({ $0.url?.path == "/auth/upgrade/commit" }).count

        XCTAssertEqual(secondExchangeCount, 1, "Exchange must not be called again on retry")
        XCTAssertEqual(secondCommitCount, 2, "Commit was retried")
        XCTAssertEqual(granted, ["atproto", "transition:generic", "identity:handle"])

        // Session promoted after commit succeeds
        let finalSession = try await storage.getGatewaySession(for: aliceDID)
        XCTAssertEqual(finalSession, "candidate-session-uuid-retry")
    }

    func testCASFailsIfOldSessionChangedConcurrently() async throws {
        let namespace = "test.gateway.upgrade.cas.\(UUID().uuidString)"
        let (client, storage) = try await makeClient(namespace: namespace)

        let alice = Self.aliceDID

        GatewayUpgradeTestURLProtocol.setHandler { request in
            let path = request.url?.path ?? ""
            if path == "/auth/upgrade" {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=1"}"#.data(using: .utf8)!)
            } else if path == "/auth/upgrade/exchange" {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                let body = """
                {
                    "candidate_session_id": "candidate-cas-uuid",
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
                    "session_id": "candidate-cas-uuid",
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
            for: aliceDID,
            callbackURL: validCallbackBase
        )

        // Concurrently change the stored session (e.g. login on another device / relogin)
        try await storage.saveGatewaySession("session-concurrently-changed", for: aliceDID)

        let incomingCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=auth-code-cas")!

        // Complete should fail CAS promotion
        do {
            _ = try await client.completeGatewayScopeUpgrade(callbackURL: incomingCallback, for: aliceDID)
            XCTFail("Expected failure on CAS mismatch")
        } catch {}

        // Current session must remain the concurrently set session
        let currentSession = try await storage.getGatewaySession(for: aliceDID)
        XCTAssertEqual(currentSession, "session-concurrently-changed")
    }

    // MARK: - 4. Cancellation, Denial, Mismatch, Replay Fail-Closed Tests

    func testCancellationAndCallbackErrorsFailClosed() async throws {
        let namespace = "test.gateway.upgrade.errors.\(UUID().uuidString)"
        let (client, storage) = try await makeClient(namespace: namespace)

        GatewayUpgradeTestURLProtocol.setHandler { request in
            let path = request.url?.path ?? ""
            if path == "/auth/upgrade" {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=1"}"#.data(using: .utf8)!)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }

        _ = try await client.startGatewayScopeUpgrade(
            requesting: ["identity:handle"],
            for: aliceDID,
            callbackURL: validCallbackBase
        )

        // 1. User denied/cancelled callback
        let denialCallback = URL(string: "https://catbird.blue/oauth/permission-callback?error=access_denied&error_description=User+denied")!
        do {
            _ = try await client.completeGatewayScopeUpgrade(callbackURL: denialCallback, for: aliceDID)
            XCTFail("Expected error for access_denied callback")
        } catch {}

        // 2. Callback base URL mismatch (different host/path)
        let mismatchCallback = URL(string: "https://evil.attacker.test/oauth/permission-callback?code=12345")!
        do {
            _ = try await client.completeGatewayScopeUpgrade(callbackURL: mismatchCallback, for: aliceDID)
            XCTFail("Expected error for mismatched callback host")
        } catch {}

        // 3. Callback code length unbounded (> 512 chars)
        let longCode = String(repeating: "c", count: 513)
        let unboundedCallback = URL(string: "https://catbird.blue/oauth/permission-callback?code=\(longCode)")!
        do {
            _ = try await client.completeGatewayScopeUpgrade(callbackURL: unboundedCallback, for: aliceDID)
            XCTFail("Expected error for unbounded code")
        } catch {}

        // Session must be untouched
        let currentSession = try await storage.getGatewaySession(for: aliceDID)
        XCTAssertEqual(currentSession, "session-alice-initial")
    }

    func testCandidateScopeNonMonotonicFailsClosed() async throws {
        let namespace = "test.gateway.upgrade.nonmonotonic.\(UUID().uuidString)"
        let (client, storage) = try await makeClient(namespace: namespace)

        let alice = Self.aliceDID

        GatewayUpgradeTestURLProtocol.setHandler { request in
            let path = request.url?.path ?? ""
            if path == "/auth/upgrade" {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                return (resp, #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=1"}"#.data(using: .utf8)!)
            } else if path == "/auth/upgrade/exchange" {
                // Returns scopes missing requested scope "identity:handle"
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                let body = """
                {
                    "candidate_session_id": "candidate-uuid-shrink",
                    "did": "\(alice)",
                    "granted_scopes": ["atproto", "transition:generic"]
                }
                """.data(using: .utf8)!
                return (resp, body)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }

        _ = try await client.startGatewayScopeUpgrade(
            requesting: ["identity:handle"],
            for: aliceDID,
            callbackURL: validCallbackBase
        )

        let callback = URL(string: "https://catbird.blue/oauth/permission-callback?code=code123")!
        do {
            _ = try await client.completeGatewayScopeUpgrade(callbackURL: callback, for: aliceDID)
            XCTFail("Expected failure when candidate scopes do not contain requested scopes")
        } catch {}

        let currentSession = try await storage.getGatewaySession(for: aliceDID)
        XCTAssertEqual(currentSession, "session-alice-initial")
    }

    // MARK: - 5. Fetch Granted Scopes Tests

    func testFetchGrantedScopesReturnsAuthoritativeSetAndThrowsOnError() async throws {
        let namespace = "test.gateway.fetch.scopes.\(UUID().uuidString)"
        let (client, _) = try await makeClient(namespace: namespace)

        let alice = Self.aliceDID
        let bob = Self.bobDID

        GatewayUpgradeTestURLProtocol.setHandler { request in
            if request.url?.path == "/auth/session" {
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                let body = """
                {
                    "did": "\(alice)",
                    "handle": "alice.test",
                    "active": true,
                    "granted_scopes": ["atproto", "transition:generic", "identity:handle"]
                }
                """.data(using: .utf8)!
                return (resp, body)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }

        let scopes = try await client.fetchGrantedScopes(for: aliceDID)
        XCTAssertEqual(scopes, ["atproto", "transition:generic", "identity:handle"])

        let reqs = GatewayUpgradeTestURLProtocol.recordedRequests()
        let sessionReq = reqs.first(where: { $0.url?.path == "/auth/session" })
        XCTAssertEqual(sessionReq?.value(forHTTPHeaderField: "Authorization"), "Bearer session-alice-initial")

        // 1. Non-200 (401) must throw, never return empty set
        GatewayUpgradeTestURLProtocol.setHandler { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (resp, #"{"error":"invalid_session"}"#.data(using: .utf8)!)
        }
        do {
            _ = try await client.fetchGrantedScopes(for: aliceDID)
            XCTFail("Expected throw on 401 response")
        } catch {}

        // 2. Response without 'atproto' scope must throw
        GatewayUpgradeTestURLProtocol.setHandler { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            let body = """
            {
                "did": "\(alice)",
                "handle": "alice.test",
                "active": true,
                "granted_scopes": ["identity:handle"]
            }
            """.data(using: .utf8)!
            return (resp, body)
        }
        do {
            _ = try await client.fetchGrantedScopes(for: aliceDID)
            XCTFail("Expected throw on missing atproto scope")
        } catch {}

        // 3. Response with mismatched DID must throw
        GatewayUpgradeTestURLProtocol.setHandler { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            let body = """
            {
                "did": "\(bob)",
                "handle": "bob.test",
                "active": true,
                "granted_scopes": ["atproto", "identity:handle"]
            }
            """.data(using: .utf8)!
            return (resp, body)
        }
        do {
            _ = try await client.fetchGrantedScopes(for: aliceDID)
            XCTFail("Expected throw on mismatched DID")
        } catch {}

        // 4. Missing session for non-existent DID must throw
        do {
            _ = try await client.fetchGrantedScopes(for: "did:plc:nonexistent")
            XCTFail("Expected throw on missing session")
        } catch {}
    }
}
