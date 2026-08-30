import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

@Suite("LogManager Tests", .serialized)
struct LogManagerTests {
    @Test("Logout auto-switch incidents preserve logout semantics")
    func logoutAutoSwitchIncidentMapping() {
        let event = LogManager.convertToAuthEvent(
            type: "AccountAutoSwitchedAfterLogout",
            details: [
                "previousDid": "did:plc:previous",
                "newDid": "did:plc:next",
                "reason": "logout",
            ]
        )

        #expect(event == .logoutAutoSwitched(
            previousDid: "did:plc:previous",
            newDid: "did:plc:next"
        ))
    }

    @Test("Live producer detail keys map to their exact typed values")
    func liveProducerDetailKeys() {
        #expect(LogManager.convertToAuthEvent(
            type: "AccountAutoSwitchAfterRemoval",
            details: [
                "previousDid": "did:plc:removed",
                "newDid": "did:plc:next",
                "reason": "account_removed",
            ]
        ) == .accountAutoSwitched(
            previousDid: "did:plc:removed",
            newDid: "did:plc:next",
            reason: "account_removed"
        ))

        #expect(LogManager.convertToAuthEvent(
            type: "CurrentAccountChanged",
            details: [
                "previousDid": "did:plc:previous",
                "newDid": "did:plc:next",
                "trigger": "setCurrentAccount",
            ]
        ) == .currentAccountChanged(
            previousDid: "did:plc:previous",
            newDid: "did:plc:next"
        ))

        #expect(LogManager.convertToAuthEvent(
            type: "DPoPNonceMismatchRefresh",
            details: [
                "did": "did:plc:nonce",
                "retry": 1,
                "status": 400,
            ]
        ) == .dpopNonceMismatch(did: "did:plc:nonce", retryAttempt: 1))

        #expect(LogManager.convertToAuthEvent(
            type: "SessionMissingForAccount",
            details: [
                "did": "did:plc:session",
                "endpoint": "https://pds.example/xrpc/app.bsky.feed.getTimeline",
                "accountExists": true,
                "sessionExists": false,
            ]
        ) == .sessionMissing(
            did: "did:plc:session",
            context: "https://pds.example/xrpc/app.bsky.feed.getTimeline"
        ))
    }

    @Test("Unrepresentable live incidents and unknown types remain JSON-only")
    func unrepresentableIncidentsAreNotFabricated() {
        let incidents: [(String, [String: Any])] = [
            ("CircuitBreakerOpened", [
                "did": "did:plc:breaker",
                "failures": 3,
                "lastKind": "network",
                "backoffExponent": 2,
            ]),
            ("InvalidGrantWithValidToken", [
                "did": "did:plc:valid",
                "tokenExpiresIn": "3600.0",
                "description": "refresh rejected while access token remains valid",
            ]),
            ("DPoPKeyMissingForOAuthSession", [
                "did": "did:plc:dpop",
                "tokenType": "dpop",
                "action": "signal_reauth_needed",
            ]),
            ("LegacyRefreshInvalidToken", [
                "status": 401,
                "error": "InvalidToken",
                "message": "expired",
            ]),
            ("FutureUnknownIncident", ["did": "did:plc:unknown"]),
        ]

        for (type, details) in incidents {
            #expect(
                LogManager.convertToAuthEvent(type: type, details: details) == nil,
                "\(type) must not masquerade as a typed logout event"
            )
        }
    }

    @Test("Typed incidents reject missing required identity")
    func missingRequiredIdentityIsRejected() {
        for type in ["RefreshInvalidGrant", "InvalidClientMetadata", "InvalidClient"] {
            #expect(LogManager.convertToAuthEvent(
                type: type,
                details: [
                    "status": 401,
                    "error": "invalid",
                    "desc": "no account identity is available",
                ]
            ) == nil)
        }

        #expect(LogManager.convertToAuthEvent(
            type: "RefreshInvalidGrant",
            details: [
                "did": "did:plc:known",
                "status": 401,
                "error": "invalid_grant",
            ]
        ) == .refreshTokenInvalid(
            did: "did:plc:known",
            statusCode: 401,
            error: "invalid_grant"
        ))

        #expect(LogManager.convertToAuthEvent(
            type: "CurrentAccountChanged",
            details: ["previousDid": "did:plc:previous"]
        ) == nil)
        #expect(LogManager.convertToAuthEvent(
            type: "DPoPNonceMismatchRefresh",
            details: [
                "did": "did:plc:nonce",
                "retryAttempt": 1,
            ]
        ) == nil)
    }

    @Test("Explicit auto-logout incidents retain their exact semantics")
    func explicitAutoLogoutMapping() {
        #expect(LogManager.convertToAuthEvent(
            type: "AutoLogoutTriggered",
            details: [
                "did": "did:plc:logout",
                "reason": "invalid_grant",
            ]
        ) == .autoLogoutTriggered(
            did: "did:plc:logout",
            reason: "invalid_grant"
        ))
    }

    @Test("Unrepresentable incidents are not delivered to typed observers")
    func unrepresentableIncidentBroadcastIsSuppressed() async {
        await PetrelAuthEvents.removeAllObservers()
        let recorder = AuthEventRecorder()
        await PetrelAuthEvents.addObserverAndWait { event in
            await recorder.record(event)
        }

        // Unique to this test: the broadcast bus is global, so suites running in
        // parallel deliver their own incidents to this observer. Only an event
        // carrying this DID would prove the unrepresentable incident leaked through.
        let did = "did:plc:unrepresentable-incident-probe"
        LogManager.logAuthIncident(
            "InvalidGrantWithValidToken",
            details: [
                "did": did,
                "tokenExpiresIn": "3600.0",
                "description": "session preserved",
            ]
        )
        await PetrelAuthEvents.drain()

        let leaked = await recorder.events.filter { String(describing: $0).contains(did) }
        #expect(leaked.isEmpty)
        await PetrelAuthEvents.removeAllObservers()
    }

    @Test("LogManager should not crash on nil values")
    func logManagerNilSafety() {
        // These should not crash
        LogManager.logSensitiveValue(nil, label: "test")
        #expect(LogManager.logDID(nil) == "nil")
        LogManager.logSensitiveValue("", label: "empty")
        #expect(LogManager.logDID("") == "")
    }

    @Test("LogManager categories should work")
    func logManagerCategories() {
        // These should not crash and should use different loggers
        LogManager.logInfo("Test message", category: .general)
        LogManager.logInfo("Network message", category: .network)
        LogManager.logInfo("Auth message", category: .authentication)

        LogManager.logError("Test error", category: .general)
        LogManager.logError("Network error", category: .network)
        LogManager.logError("Auth error", category: .authentication)
    }

    @Test("LogManager should handle sensitive request logging")
    func sensitiveRequestLogging() throws {
        let url = try #require(URL(string: "https://example.com/oauth/token"))
        var request = URLRequest(url: url)
        request.addValue("Bearer secret-token", forHTTPHeaderField: "Authorization")
        request.addValue("sensitive-dpop-proof", forHTTPHeaderField: "X-DPoP")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // This should not crash and should filter sensitive headers
        LogManager.logRequest(request)
    }

    @Test("LogManager should handle sensitive response logging")
    func sensitiveResponseLogging() throws {
        let url = try #require(URL(string: "https://example.com/oauth/token"))
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Set-Cookie": "sensitive-session-id=123456",
                "X-Auth-Token": "secret-token",
            ]
        ))

        let responseData = """
        {
            "access_token": "secret-access-token",
            "refresh_token": "secret-refresh-token"
        }
        """.data(using: .utf8)!

        // This should not crash and should filter sensitive data
        LogManager.logResponse(response, data: responseData)
    }

    @Test("LogManager should handle non-token endpoint responses")
    func nonTokenEndpointLogging() throws {
        let url = try #require(URL(string: "https://example.com/api/posts"))
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "1.1",
            headerFields: ["Content-Type": "application/json"]
        ))

        let responseData = """
        {
            "posts": [{"id": "123", "text": "Hello world"}]
        }
        """.data(using: .utf8)!

        // This should log the response body since it's not a token endpoint
        LogManager.logResponse(response, data: responseData)
    }

    @Test("LogManager should handle large responses")
    func largeResponseLogging() throws {
        let url = try #require(URL(string: "https://example.com/api/data"))
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "1.1",
            headerFields: ["Content-Type": "application/json"]
        ))

        // Create a large response (over 1000 characters)
        let largeData = try #require(String(repeating: "x", count: 2000).data(using: .utf8))

        // This should truncate the response
        LogManager.logResponse(response, data: largeData)
    }

    @Test("LogManager should handle request with sensitive body")
    func sensitiveRequestBody() throws {
        let url = try #require(URL(string: "https://example.com/api/test"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let sensitiveBody = """
        {
            "password": "secret123",
            "client_secret": "very-secret",
            "code": "auth-code-123"
        }
        """.data(using: .utf8)

        request.httpBody = sensitiveBody

        // This should detect sensitive data and not log the body
        LogManager.logRequest(request)
    }

    @Test("LogManager should handle safe request body")
    func safeRequestBody() throws {
        let url = try #require(URL(string: "https://example.com/api/posts"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let safeBody = """
        {
            "title": "My Post",
            "content": "Hello world!"
        }
        """.data(using: .utf8)

        request.httpBody = safeBody

        // This should log the body since it doesn't contain sensitive data
        LogManager.logRequest(request)
    }

    @Test("Step 8 & N1-N5: sanitizeURLForLogging emits normalized path and allowlisted parameter names only")
    func sanitizeURLForLoggingComprehensive() {
        let url = URL(string: "https://user:pass123@alice.bsky.social/oauth/authorize?response_type=code&client_id=myclient&code=secret123&state=xyz789&email=alice@example.com#token123")!
        let sanitized = LogManager.sanitizeURLForLogging(url)

        #expect(!sanitized.contains("user"))
        #expect(!sanitized.contains("pass123"))
        #expect(!sanitized.contains("secret123"))
        #expect(!sanitized.contains("xyz789"))
        #expect(!sanitized.contains("alice@example.com"))
        #expect(!sanitized.contains("token123"))
        #expect(!sanitized.contains("#"))
        #expect(!sanitized.contains("alice.bsky.social"))
        #expect(!sanitized.contains("code"))
        #expect(!sanitized.contains("state"))
        #expect(!sanitized.contains("email"))
        #expect(sanitized.contains("response_type"))
        #expect(sanitized.contains("client_id"))
        #expect(sanitized.hasPrefix("/oauth/authorize"))

        let didURL = URL(string: "https://plc.directory/did:plc:12345/data?limit=50&cursor=abc&secret_key=topsecret")!
        let sanitizedDID = LogManager.sanitizeURLForLogging(didURL)
        #expect(!sanitizedDID.contains("plc.directory"))
        #expect(!sanitizedDID.contains("50"))
        #expect(!sanitizedDID.contains("abc"))
        #expect(!sanitizedDID.contains("secret_key"))
        #expect(!sanitizedDID.contains("topsecret"))
        #expect(sanitizedDID.contains("limit"))
        #expect(sanitizedDID.contains("cursor"))
        #expect(sanitizedDID.hasPrefix("/did:plc:12345/data"))
    }
}

private actor AuthEventRecorder {
    private(set) var events: [AuthEvent] = []

    func record(_ event: AuthEvent) {
        events.append(event)
    }
}
