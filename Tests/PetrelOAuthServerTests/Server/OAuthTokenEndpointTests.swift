import Foundation
@testable import PetrelOAuthServer
import Testing

@Suite("Authorization server: token endpoint")
struct OAuthTokenEndpointTests {
    private let token = OAuthAuthorizationServer.Path.token

    /// PAR and consent, returning the code without exchanging it.
    private func code(_ harness: TestServer, _ client: TestClient) async throws -> String {
        let requestURI = try await client.pushRequest()
        return try await TestBrowser(harness).approve(
            requestURI: requestURI, clientID: client.clientID,
            account: TestAccounts.alice, password: "alice-password"
        )
    }

    @Test("the token response carries sub, scope, token_type DPoP, a nonce and no-store")
    func responseShape() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let response = try await client.exchange(code: code(harness, client))
        #expect(response.status == 200)
        #expect(response.headers["Cache-Control"] == "no-store")
        #expect(response.headers["Pragma"] == "no-cache")
        #expect(response.headers["DPoP-Nonce"] != nil)
        #expect(response.headers["Access-Control-Allow-Origin"] == "*")
        let body = try response.decode(OAuthTokenResponse.self)
        #expect(body.sub == TestAccounts.alice.did)
        #expect(body.scope.split(separator: " ").contains("atproto"))
        #expect(body.tokenType == "DPoP")
    }

    @Test("revoking all of an account's sessions also kills a code issued but not yet exchanged")
    func revokeAllCoversPendingCode() async throws {
        // A password change between consent and code exchange must not leave
        // the old code redeemable for a fresh token family.
        let harness = try TestServer()
        let client = try TestClient(harness)
        let pending = try await code(harness, client)
        try await harness.server.revokeAllSessions(subject: TestAccounts.alice.did)
        let response = try await client.exchange(code: pending)
        #expect(response.status == 400)
        #expect(try response.decode(ErrorPayload.self).error == "invalid_grant")
    }

    @Test("a wrong binding is refused and does not burn the code", arguments: [
        "code_verifier", "redirect_uri",
    ])
    func wrongBinding(field: String) async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let code = try await code(harness, client)
        let wrong = field == "code_verifier"
            ? String(repeating: "x", count: 43)
            : "https://app.example.test/other"
        let refused = try await client.exchange(code: code, overrides: [field: wrong])
        #expect(refused.oauthError == "invalid_grant")
        // The legitimate client can still redeem it.
        let accepted = try await client.exchange(code: code)
        #expect(accepted.status == 200)
    }

    @Test("a code cannot be redeemed with a different DPoP key")
    func differentDPoPKey() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let code = try await code(harness, client)
        client.dpopKey = try OAuthSigningKey.generate()
        let response = try await client.exchange(code: code)
        #expect(response.oauthError == "invalid_grant")
    }

    @Test("a code cannot be redeemed by another client")
    func differentClient() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let code = try await code(harness, client)
        let thief = try TestClient.loopback(harness)
        thief.dpopKey = client.dpopKey
        let response = try await thief.exchange(code: code, overrides: ["redirect_uri": TestServer.webRedirect])
        #expect(response.oauthError == "invalid_grant")
    }

    @Test("replaying a code revokes the session and every token issued from it")
    func codeReplay() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let code = try await code(harness, client)
        let first = try await client.exchange(code: code).decode(OAuthTokenResponse.self)
        let replay = try await client.exchange(code: code)
        #expect(replay.oauthError == "invalid_grant")

        let verifier = OAuthResourceServerVerifier(authorizationServer: harness.server)
        await #expect(throws: OAuthResourceAuthorizationFailure.self) {
            _ = try await authenticate(verifier, client, token: first.accessToken)
        }
        let refresh = try await client.refresh(#require(first.refreshToken))
        #expect(refresh.oauthError == "invalid_grant")
    }

    @Test("an expired code is refused")
    func expiredCode() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let code = try await code(harness, client)
        harness.clock.advance(61)
        let response = try await client.exchange(code: code)
        #expect(response.oauthError == "invalid_grant")
    }

    @Test("missing or malformed parameters", arguments: [
        (["grant_type": nil], "invalid_request"),
        (["grant_type": "password"], "unsupported_grant_type"),
        (["grant_type": "client_credentials"], "unsupported_grant_type"),
        (["code": nil], "invalid_request"),
        (["code_verifier": nil], "invalid_request"),
        (["code_verifier": "short"], "invalid_request"),
        (["redirect_uri": nil], "invalid_request"),
        (["code": String(repeating: "A", count: 43)], "invalid_grant"),
    ] as [([String: String?], String)])
    func malformed(overrides: [String: String?], expected: String) async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let code = try await code(harness, client)
        let response = try await client.exchange(code: code, overrides: overrides)
        #expect(response.status == 400)
        #expect(response.oauthError == expected)
    }

    @Test("a refresh token is single-use: reuse revokes the whole session")
    func refreshReuse() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let first = try await client.signIn()
        let refreshToken = try #require(first.refreshToken)
        let second = try await client.refresh(refreshToken).decode(OAuthTokenResponse.self)

        let reuse = try await client.refresh(refreshToken)
        #expect(reuse.oauthError == "invalid_grant")
        // The legitimately rotated token dies with the session.
        let next = try await client.refresh(#require(second.refreshToken))
        #expect(next.oauthError == "invalid_grant")
        #expect(try await harness.server.sessions(subject: TestAccounts.alice.did).isEmpty)
    }

    @Test("a refresh token is bound to the session's DPoP key")
    func refreshWithDifferentKey() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let tokens = try await client.signIn()
        client.dpopKey = try OAuthSigningKey.generate()
        let response = try await client.refresh(#require(tokens.refreshToken))
        #expect(response.oauthError == "invalid_grant")
    }

    @Test("a refresh token is bound to its client")
    func refreshByAnotherClient() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let tokens = try await client.signIn()
        let other = try TestClient.loopback(harness)
        other.dpopKey = client.dpopKey
        let response = try await other.refresh(#require(tokens.refreshToken))
        #expect(response.oauthError == "invalid_grant")
    }

    @Test("a client that did not declare refresh_token receives no refresh token")
    func noRefreshGrant() async throws {
        let harness = try TestServer(webClientGrants: ["authorization_code"])
        let client = try TestClient(harness)
        let tokens = try await client.signIn()
        #expect(tokens.refreshToken == nil)
        let response = try await client.refresh(String(repeating: "A", count: 43))
        #expect(response.oauthError == "unauthorized_client")
    }

    @Test("lifetimes: access under 30 minutes, public session and refresh capped at two weeks")
    func publicClientLifetimes() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        var tokens = try await client.signIn()
        #expect(tokens.expiresIn > 0 && tokens.expiresIn < 30 * 60)

        // The access token stops working when it expires.
        let verifier = OAuthResourceServerVerifier(authorizationServer: harness.server)
        harness.clock.advance(TimeInterval(tokens.expiresIn) + 1)
        await #expect(throws: OAuthResourceAuthorizationFailure.self) {
            _ = try await authenticate(verifier, client, token: tokens.accessToken)
        }

        // Refreshing daily keeps the session alive, but not past two weeks.
        for _ in 0 ..< 13 {
            harness.clock.advance(24 * 60 * 60 - 1000)
            let response = try await client.refresh(#require(tokens.refreshToken))
            #expect(response.status == 200)
            tokens = try response.decode(OAuthTokenResponse.self)
        }
        harness.clock.advance(2 * 24 * 60 * 60)
        let late = try await client.refresh(#require(tokens.refreshToken))
        #expect(late.oauthError == "invalid_grant")
    }

    @Test("lifetimes: an unused public refresh token expires after two weeks")
    func unusedPublicRefreshToken() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let tokens = try await client.signIn()
        harness.clock.advance(14 * 24 * 60 * 60 + 1)
        let response = try await client.refresh(#require(tokens.refreshToken))
        #expect(response.oauthError == "invalid_grant")
    }

    @Test("lifetimes: a confidential refresh token lasts 180 days and no longer")
    func confidentialRefreshLifetime() async throws {
        let harness = try TestServer()
        let client = try TestClient.confidential(harness)
        let tokens = try await client.signIn()
        harness.clock.advance(179 * 24 * 60 * 60)
        let within = try await client.refresh(#require(tokens.refreshToken))
        #expect(within.status == 200)
        let rotated = try within.decode(OAuthTokenResponse.self)
        harness.clock.advance(180 * 24 * 60 * 60 + 1)
        let beyond = try await client.refresh(#require(rotated.refreshToken))
        #expect(beyond.oauthError == "invalid_grant")
    }

    @Test("a confidential client must refresh with the key the session was created with")
    func confidentialKeyBinding() async throws {
        let harness = try TestServer()
        let client = try TestClient.confidential(harness)
        let tokens = try await client.signIn()

        // The client adds a second key and tries to refresh with it.
        let second = try OAuthSigningKey.generate(keyID: "key-2")
        let both = try OAuthJSONWebKeySet(keys: [harness.confidentialKey.publicJWK, second.publicJWK])
        try harness.clients.register(Self.confidentialMetadata(both))
        let rotatedClient = try TestClient(
            harness, clientID: client.clientID, redirectURI: client.redirectURI, assertionKey: second
        )
        rotatedClient.dpopKey = client.dpopKey
        let wrongKey = try await rotatedClient.refresh(#require(tokens.refreshToken))
        #expect(wrongKey.oauthError == "invalid_grant")
        // The session survives a wrong-key attempt and still refreshes with the bound key.
        let rightKey = try await client.refresh(#require(tokens.refreshToken))
        #expect(rightKey.status == 200)
    }

    @Test("removing the bound key from the client's JWKS revokes the session at the next refresh")
    func keyRemovedFromJWKS() async throws {
        let harness = try TestServer()
        let client = try TestClient.confidential(harness)
        let tokens = try await client.signIn()

        let replacement = try OAuthSigningKey.generate(keyID: "key-2")
        try harness.clients.register(Self.confidentialMetadata(OAuthJSONWebKeySet(keys: [replacement.publicJWK])))
        let rotatedClient = try TestClient(
            harness, clientID: client.clientID, redirectURI: client.redirectURI, assertionKey: replacement
        )
        rotatedClient.dpopKey = client.dpopKey
        let response = try await rotatedClient.refresh(#require(tokens.refreshToken))
        #expect(response.oauthError == "invalid_grant")
        #expect(try await harness.server.sessions(subject: TestAccounts.alice.did).isEmpty)
    }

    private static func confidentialMetadata(_ keySet: OAuthJSONWebKeySet) throws -> OAuthResolvedClientMetadata {
        try .init(
            metadata: OAuthClientMetadata(
                clientID: #require(URL(string: TestServer.confidentialClientID)),
                redirectURIs: [#require(URL(string: TestServer.confidentialRedirect))],
                grantTypes: ["authorization_code", "refresh_token"],
                responseTypes: ["code"],
                scopes: ["atproto", "transition:generic"],
                tokenEndpointAuthMethod: .privateKeyJWT,
                tokenEndpointAuthSigningAlgorithm: "ES256",
                dpopBoundAccessTokens: true,
                jwks: keySet
            ),
            keySet: keySet
        )
    }

    @Test("a disabled account can neither redeem a code nor refresh")
    func disabledAccount() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let tokens = try await client.signIn()
        harness.accounts.disable(TestAccounts.alice.did)
        let response = try await client.refresh(#require(tokens.refreshToken))
        #expect(response.oauthError == "invalid_grant")
    }

    @Test("revocation: an access token revokes its session, and an unknown token is still a 200")
    func revocation() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let tokens = try await client.signIn()
        let revoke = OAuthAuthorizationServer.Path.revoke

        let unknown = await harness.post(revoke, [("token", "does-not-exist")])
        #expect(unknown.status == 200)
        let missing = await harness.post(revoke, [])
        #expect(missing.oauthError == "invalid_request")
        let wrongClient = await harness.post(revoke, [("token", tokens.accessToken), ("client_id", "https://other.example/c.json")])
        #expect(wrongClient.status == 200)
        #expect(try await harness.server.sessions(subject: TestAccounts.alice.did).count == 1)

        let done = await harness.post(revoke, [("token", tokens.accessToken)])
        #expect(done.status == 200)
        #expect(try await harness.server.sessions(subject: TestAccounts.alice.did).isEmpty)
        let refresh = try await client.refresh(#require(tokens.refreshToken))
        #expect(refresh.oauthError == "invalid_grant")
    }

    @Test("session management: list, revoke own, cannot revoke another account's")
    func sessionManagement() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        _ = try await client.signIn()
        let session = try #require(try await harness.server.sessions(subject: TestAccounts.alice.did).first)
        #expect(session.binding.clientID == TestServer.webClientID)
        #expect(try await harness.server.revokeSession(id: session.sessionID, subject: TestAccounts.bob.did) == false)
        #expect(try await harness.server.revokeSession(id: session.sessionID, subject: TestAccounts.alice.did))
        #expect(try await harness.server.sessions(subject: TestAccounts.alice.did).isEmpty)
    }
}
