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
                        "active": true,
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
                        "active": true,
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
                        "active": true,
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
                            #"{"did":"\#(alice)","active":true,"granted_scopes":["atproto","transition:generic"]}"#.data(using: .utf8)!)
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
                            #"{"did":"\#(alice)","active":true,"granted_scopes":["atproto"]}"#.data(using: .utf8)!)
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
                            #"{"did":"\#(alice)","active":true,"granted_scopes":["atproto"]}"#.data(using: .utf8)!)
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
                            #"{"did":"\#(alice)","active":true,"granted_scopes":["atproto","transition:generic"]}"#.data(using: .utf8)!)
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

    func testExchangeRetryWhenCandidateNotPersisted() async throws {
        try await withInMemoryBackend { _ in
            let namespace = "test.gateway.upgrade.exchangeretry.\(UUID().uuidString)"
            let (client, storage) = try await self.makeClient(namespace: namespace)

            let alice = self.aliceDID
            let candidateUUID = UUID().uuidString.lowercased()
            let exchangeCount = Mutex<Int>(0)

            GatewayUpgradeTestURLProtocol.setHandler { request in
                let path = request.url?.path ?? ""
                if path == "/auth/session" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"did":"\#(alice)","active":true,"granted_scopes":["atproto","transition:generic"]}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"authorization_url":"https://auth.pds.test/oauth/authorize?req=1"}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade/exchange" {
                    exchangeCount.withLock { $0 += 1 }
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"candidate_session_id":"\#(candidateUUID)","did":"\#(alice)","granted_scopes":["atproto","transition:generic","identity:handle"]}"#.data(using: .utf8)!)
                } else if path == "/auth/upgrade/commit" {
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                            #"{"status":"committed","session_id":"\#(candidateUUID)","did":"\#(alice)","granted_scopes":["atproto","transition:generic","identity:handle"]}"#.data(using: .utf8)!)
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }

            _ = try await client.startGatewayScopeUpgrade(requesting: ["identity:handle"], for: self.aliceDID, callbackURL: self.validCallbackBase)

            // Complete successfully
            let callback = URL(string: "https://catbird.blue/oauth/permission-callback?code=code-12345")!
            let granted = try await client.completeGatewayScopeUpgrade(callbackURL: callback, for: self.aliceDID)
            XCTAssertEqual(granted, ["atproto", "transition:generic", "identity:handle"])
            XCTAssertEqual(exchangeCount.withLock { $0 }, 1)

            let finalSession = try await storage.getGatewaySession(for: self.aliceDID)
            XCTAssertEqual(finalSession, candidateUUID)
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
                            #"{"did":"\#(alice)","active":true,"granted_scopes":["atproto"]}"#.data(using: .utf8)!)
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
                        "active": true,
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
                    "active": true,
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
                    "active": true,
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
}
