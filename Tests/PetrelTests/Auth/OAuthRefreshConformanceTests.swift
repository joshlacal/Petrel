import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

/// Token refresh on the wire ("Tokens and Session Lifetime" in the OAuth spec):
/// the request itself, single-use rotation, the lock that keeps concurrent
/// callers from presenting the same refresh token twice, and verification of
/// the refreshed tokens.
///
/// `FakeOAuthServer` rotates refresh tokens and revokes the whole session when
/// a rotated token is presented again, so `revokedGrantCount == 0` is proof
/// that no token was ever replayed.
@Suite("OAuth refresh conformance", .serialized)
struct OAuthRefreshConformanceTests {
    private static let aliceDID = "did:plc:refreshalice"

    private func refreshRequests(_ server: FakeOAuthServer) -> [FakeOAuthServer.RecordedRequest] {
        server.requests(to: .token).filter { $0.form["grant_type"] == "refresh_token" }
    }

    @Test("A refresh sends the refresh-token grant with DPoP and stores the rotated tokens")
    func refreshWireFormatAndRotation() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "refresh.wire", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            let original = try #require(try await client.storage.getSession(for: Self.aliceDID))

            #expect(try await client.strategy.refreshTokenIfNeeded(forceRefresh: true) == .refreshedSuccessfully)

            let request = try #require(refreshRequests(server).last)
            #expect(request.status == 200)
            #expect(request.url.absoluteString == server.tokenEndpoint)
            #expect(request.method == "POST")
            #expect(request.form == [
                "grant_type": "refresh_token",
                "refresh_token": try #require(original.refreshToken),
                "client_id": OAuthTestClient.clientID,
            ])
            #expect(request.headers["Authorization"] == nil)
            // Signed by the session's key; a token request carries no ath.
            #expect(request.proof?.thumbprint == server.requests(to: .par).last?.proof?.thumbprint)
            #expect(request.proof?.ath == nil)

            let refreshed = try #require(try await client.storage.getSession(for: Self.aliceDID))
            #expect(refreshed.accessToken != original.accessToken)
            #expect(refreshed.refreshToken != original.refreshToken)
            #expect(refreshed.did == Self.aliceDID)
            #expect(refreshed.tokenType == .dpop)
            #expect(refreshed.grantedScopes == original.grantedScopes)

            // The next refresh presents the new token, never the spent one.
            _ = try await client.strategy.refreshTokenIfNeeded(forceRefresh: true)
            #expect(refreshRequests(server).last?.form["refresh_token"] == refreshed.refreshToken)
            #expect(server.revokedGrantCount == 0)
            // And the new access token works.
            #expect(try await client.getSession().1.statusCode == 200)
        }
    }

    @Test("Concurrent callers share one refresh: an expiring token is refreshed exactly once")
    func concurrentRefreshIsSerialized() async throws {
        let server = FakeOAuthServer()
        server.accessTokenLifetime = 0 // the login's access token is already due
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "refresh.concurrent", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            server.accessTokenLifetime = 3600

            let strategy = client.strategy
            let results = try await withThrowingTaskGroup(of: TokenRefreshResult.self) { group in
                for _ in 0 ..< 32 {
                    group.addTask { try await strategy.refreshTokenIfNeeded() }
                }
                var collected: [TokenRefreshResult] = []
                for try await result in group {
                    collected.append(result)
                }
                return collected
            }

            #expect(results.count == 32)
            #expect(refreshRequests(server).count == 1)
            #expect(server.revokedGrantCount == 0)
            #expect(results.contains(.refreshedSuccessfully))
        }
    }

    @Test("Concurrent forced refreshes never present the same refresh token twice")
    func concurrentForcedRefreshNeverReplays() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "refresh.concurrent.forced", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)

            let strategy = client.strategy
            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0 ..< 24 {
                    group.addTask { _ = try await strategy.refreshTokenIfNeeded(forceRefresh: true) }
                }
                try await group.waitForAll()
            }

            let presented = refreshRequests(server).compactMap { $0.form["refresh_token"] }
            #expect(!presented.isEmpty)
            #expect(Set(presented).count == presented.count)
            #expect(refreshRequests(server).allSatisfy { $0.status == 200 })
            #expect(server.revokedGrantCount == 0)
            #expect(try await client.getSession().1.statusCode == 200)
        }
    }

    @Test("invalid_grant is definitive: the token is never presented again")
    func invalidGrantIsNotRetried() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "refresh.invalid_grant", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            server.forcedErrors[.token] = (400, "invalid_grant")

            await #expect(throws: AuthError.invalidCredentials) {
                _ = try await client.strategy.refreshTokenIfNeeded(forceRefresh: true)
            }
            let after = refreshRequests(server).count
            #expect(after == 1)

            server.forcedErrors[.token] = nil
            await #expect(throws: AuthError.self) {
                _ = try await client.strategy.refreshTokenIfNeeded(forceRefresh: true)
            }
            #expect(refreshRequests(server).count == after)
        }
    }

    @Test("A transient server error does not spend the refresh token")
    func transientFailureKeepsRefreshToken() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "refresh.transient", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            let original = try #require(try await client.storage.getSession(for: Self.aliceDID))

            server.forcedErrors[.token] = (503, "temporarily_unavailable")
            await #expect(throws: AuthError.tokenRefreshFailed) {
                _ = try await client.strategy.refreshTokenIfNeeded(forceRefresh: true)
            }
            #expect(try await client.storage.getSession(for: Self.aliceDID) == original)

            server.forcedErrors[.token] = nil
            #expect(try await client.strategy.refreshTokenIfNeeded(forceRefresh: true) == .refreshedSuccessfully)
            let attempts = refreshRequests(server)
            #expect(attempts.map(\.status) == [503, 200])
            #expect(attempts[0].form["refresh_token"] == attempts[1].form["refresh_token"])
        }
    }

    @Test(
        "A refresh response for another account, or without a subject, is refused and revoked",
        arguments: ["did:plc:someoneelse", nil] as [String?]
    )
    func refreshSubjectIsVerified(returnedSubject: String?) async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "refresh.sub.\(returnedSubject ?? "none")", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            let original = try #require(try await client.storage.getSession(for: Self.aliceDID))

            server.tokenResponseTransform = { response, grantType in
                guard grantType == "refresh_token" else { return response }
                var response = response
                response["sub"] = returnedSubject
                return response
            }
            await #expect(throws: AuthError.invalidResponse) {
                _ = try await client.strategy.refreshTokenIfNeeded(forceRefresh: true)
            }

            // The server answered 200; the client refused the tokens, kept the
            // stored session untouched, and revoked what it had been handed.
            #expect(refreshRequests(server).last?.status == 200)
            #expect(try await client.storage.getSession(for: Self.aliceDID) == original)
            #expect(server.requests(to: .revoke).last?.status == 200)
            #expect(server.isRevoked(sub: Self.aliceDID))

            // The spent refresh token is not presented again.
            let count = refreshRequests(server).count
            await #expect(throws: AuthError.self) {
                _ = try await client.strategy.refreshTokenIfNeeded(forceRefresh: true)
            }
            #expect(refreshRequests(server).count == count)
        }
    }

    @Test("A refreshed grant that lost the atproto scope is refused")
    func refreshScopeIsVerified() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "refresh.scope", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            server.tokenResponseTransform = { response, grantType in
                guard grantType == "refresh_token" else { return response }
                var response = response
                response["scope"] = "transition:generic"
                return response
            }
            await #expect(throws: AuthError.invalidResponse) {
                _ = try await client.strategy.refreshTokenIfNeeded(forceRefresh: true)
            }
        }
    }

    @Test("A server that reduces the grant on refresh is believed")
    func reducedGrantIsStored() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "refresh.reduced", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            #expect(try await client.storage.getSession(for: Self.aliceDID)?.grantedScopes == ["atproto", "transition:generic"])
            server.tokenResponseTransform = { response, grantType in
                guard grantType == "refresh_token" else { return response }
                var response = response
                response["scope"] = "atproto"
                return response
            }
            _ = try await client.strategy.refreshTokenIfNeeded(forceRefresh: true)
            #expect(try await client.storage.getSession(for: Self.aliceDID)?.grantedScopes == ["atproto"])
        }
    }

    @Test("A server that does not rotate refresh tokens can be refreshed against repeatedly")
    func nonRotatingServer() async throws {
        let server = FakeOAuthServer()
        server.rotatesRefreshTokens = false
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "refresh.norotation", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            let original = try #require(try await client.storage.getSession(for: Self.aliceDID)?.refreshToken)

            for _ in 0 ..< 3 {
                #expect(try await client.strategy.refreshTokenIfNeeded(forceRefresh: true) == .refreshedSuccessfully)
            }
            #expect(refreshRequests(server).map { $0.form["refresh_token"] } == [original, original, original])
            #expect(try await client.storage.getSession(for: Self.aliceDID)?.refreshToken == original)
        }
    }

    // MARK: - Lifetimes

    @Test(
        "Short-lived access tokens are not refreshed on every request",
        arguments: [300, 900, 1800]
    )
    func shortLivedTokensAreNotRefreshedEveryRequest(lifetime: Int) async throws {
        let server = FakeOAuthServer()
        server.accessTokenLifetime = lifetime
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "refresh.lifetime.\(lifetime)", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            for _ in 0 ..< 5 {
                #expect(try await client.getSession().1.statusCode == 200)
            }
            #expect(refreshRequests(server).isEmpty)
        }
    }

    @Test("The refresh lead time is a fifth of the lifetime, capped at a minute")
    func refreshLeadTime() {
        func session(lifetime: TimeInterval, age: TimeInterval) -> Session {
            Session(
                accessToken: "a", refreshToken: "r", createdAt: Date().addingTimeInterval(-age),
                expiresIn: lifetime, tokenType: .dpop, did: Self.aliceDID
            )
        }
        #expect(session(lifetime: 300, age: 0).refreshLeadTime == 60)
        #expect(session(lifetime: 900, age: 0).refreshLeadTime == 60)
        #expect(session(lifetime: 3600, age: 0).refreshLeadTime == 60)
        #expect(session(lifetime: 100, age: 0).refreshLeadTime == 20)

        // A five-minute token: fresh for four minutes, due in the last one.
        #expect(!session(lifetime: 300, age: 0).isExpiringSoon)
        #expect(!session(lifetime: 300, age: 230).isExpiringSoon)
        #expect(session(lifetime: 300, age: 245).isExpiringSoon)
        #expect(!session(lifetime: 300, age: 245).isExpired)
        #expect(session(lifetime: 300, age: 301).isExpired)
        // A fifteen-minute token is not due from the moment it is issued.
        #expect(!session(lifetime: 900, age: 600).isExpiringSoon)
        #expect(session(lifetime: 900, age: 845).isExpiringSoon)
    }

    @Test("A token response without expires_in gets the conservative assumed lifetime")
    func missingExpiresIn() async throws {
        let server = FakeOAuthServer()
        server.accessTokenLifetime = nil
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "refresh.noexpiry", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            #expect(try await client.storage.getSession(for: Self.aliceDID)?.expiresIn == 300)
        }
    }

    // MARK: - Recovery

    @Test("An access token the resource server no longer accepts is refreshed and the request replayed")
    func invalidTokenTriggersRefresh() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "refresh.invalidtoken", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            #expect(try await client.getSession().1.statusCode == 200)

            server.expireAccessTokens()
            #expect(try await client.getSession().1.statusCode == 200)
            #expect(refreshRequests(server).count == 1)
        }
    }

    @Test("An account stored without authorization-server metadata recovers it through its PDS")
    func missingMetadataIsRecovered() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "refresh.backfill", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)

            // Simulate an account persisted by a version that could lose the metadata.
            var account = try #require(try await client.storage.getAccount(for: Self.aliceDID))
            let session = try #require(try await client.storage.getSession(for: Self.aliceDID))
            account.authorizationServerMetadata = nil
            try await client.storage.saveAccountAndSession(account, session: session, for: Self.aliceDID)
            try await client.accountManager.updateAccountFromStorage(did: Self.aliceDID)
            #expect(await client.accountManager.getCurrentAccount()?.authorizationServerIssuer == nil)

            #expect(try await client.strategy.refreshTokenIfNeeded(forceRefresh: true) == .refreshedSuccessfully)
            #expect(try await client.storage.getAccount(for: Self.aliceDID)?.authorizationServerIssuer == server.issuer)
        }
    }
}
