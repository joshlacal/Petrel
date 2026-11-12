import Foundation
@testable import PetrelOAuthServer
import Testing

/// The complete authorization-code flow against the server's public entry
/// point, for the three client shapes the profile defines.
@Suite("Authorization server: end-to-end flows")
struct OAuthEndToEndFlowTests {
    @Test("public web client: PAR → sign-in → consent → code → token → refresh → revoke")
    func publicClientFlow() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let tokens = try await client.signIn()

        #expect(tokens.tokenType == "DPoP")
        #expect(tokens.sub == TestAccounts.alice.did)
        #expect(tokens.scope == "atproto transition:generic")
        #expect(tokens.expiresIn <= 15 * 60)
        let refreshToken = try #require(tokens.refreshToken)

        // The access token works at the resource server.
        let verifier = OAuthResourceServerVerifier(authorizationServer: harness.server)
        let grant = try await authenticate(verifier, client, token: tokens.accessToken)
        #expect(grant.subject == TestAccounts.alice.did)
        #expect(grant.clientID == TestServer.webClientID)
        #expect(grant.permissions.hasTransitionGeneric)

        // Refresh rotates both tokens.
        let refreshed = try await client.refresh(refreshToken)
        #expect(refreshed.status == 200)
        let second = try refreshed.decode(OAuthTokenResponse.self)
        #expect(second.accessToken != tokens.accessToken)
        #expect(second.refreshToken != nil && second.refreshToken != refreshToken)
        #expect(second.sub == TestAccounts.alice.did)

        // Revoking the refresh token ends the session.
        let revoked = await harness.post(
            OAuthAuthorizationServer.Path.revoke,
            [("token", try #require(second.refreshToken)), ("client_id", client.clientID)]
        )
        #expect(revoked.status == 200)
        await #expect(throws: OAuthResourceAuthorizationFailure.self) {
            _ = try await authenticate(verifier, client, token: second.accessToken)
        }
        let afterRevoke = try await client.refresh(#require(second.refreshToken))
        #expect(afterRevoke.oauthError == "invalid_grant")
    }

    @Test("loopback development client completes the flow with a port-agnostic redirect")
    func loopbackClientFlow() async throws {
        let harness = try TestServer()
        let client = try TestClient.loopback(harness)
        let tokens = try await client.signIn()
        #expect(tokens.sub == TestAccounts.alice.did)
        #expect(tokens.refreshToken != nil)
    }

    @Test("confidential client authenticates with private_key_jwt and is bound to its key")
    func confidentialClientFlow() async throws {
        let harness = try TestServer()
        let client = try TestClient.confidential(harness)
        let tokens = try await client.signIn()
        let refreshed = try await client.refresh(#require(tokens.refreshToken))
        #expect(refreshed.status == 200)
        #expect(harness.clients.revalidations >= 1, "client keys are refetched at refresh")

        let sessions = try await harness.server.sessions(subject: TestAccounts.alice.did)
        #expect(sessions.count == 1)
        #expect(sessions.first?.binding.clientKey?.keyID == "key-1")
    }

    @Test("an ES256K DPoP key is accepted end to end")
    func secp256k1DPoPKey() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness, dpopAlgorithm: .es256k)
        let tokens = try await client.signIn()
        let verifier = OAuthResourceServerVerifier(authorizationServer: harness.server)
        let grant = try await authenticate(verifier, client, token: tokens.accessToken)
        #expect(grant.dpopJKT == (try client.dpopKey.thumbprint))
    }

    @Test("signed at+jwt access tokens verify with only the server's public keys")
    func signedAccessTokens() async throws {
        let signingKey = try OAuthSigningKey.generate(keyID: "as-1")
        let harness = try TestServer(accessTokenFormat: .signedJWT(signingKey))
        let client = try TestClient(harness)
        let tokens = try await client.signIn()

        struct JWKS: Decodable { let keys: [OAuthJSONWebKey] }
        let published = try await harness.get(OAuthAuthorizationServer.Path.jwks).decode(JWKS.self)
        let stateless = try OAuthResourceServerVerifier(
            issuer: #require(URL(string: TestServer.issuer)),
            resource: #require(URL(string: TestServer.issuer)),
            keys: OAuthJSONWebKeySet(keys: published.keys),
            secret: Data(repeating: 7, count: 32),
            replayStore: InMemoryOAuthStore(),
            clock: harness.clock
        )
        let grant = try await authenticate(stateless, client, token: tokens.accessToken)
        #expect(grant.subject == TestAccounts.alice.did)
        #expect(grant.dpopJKT == (try client.dpopKey.thumbprint))
        #expect(grant.permissions.rawScopes == ["atproto", "transition:generic"])

        let header = try OAuthCompactJWT.unverifiedHeader(tokens.accessToken)
        #expect(header.type == "at+jwt")
        #expect(header.keyID == "as-1")
        let claims = try OAuthCompactJWT.unverifiedClaims(OAuthAccessTokenClaims.self, from: tokens.accessToken)
        #expect(claims.sub == TestAccounts.alice.did)
        #expect(claims.cnf.jkt == (try client.dpopKey.thumbprint))
        #expect(claims.exp - claims.iat <= 15 * 60)
    }
}

/// Presents `token` at a resource with a fresh proof, retrying once for the
/// nonce like a real client.
func authenticate(
    _ verifier: OAuthResourceServerVerifier,
    _ client: TestClient,
    token: String,
    method: String = "GET",
    url: String = TestServer.issuer + "/xrpc/com.atproto.repo.listRecords",
    scheme: String = "DPoP"
) async throws -> OAuthAccessGrant {
    var nonce = client.nonce
    var lastFailure: OAuthResourceAuthorizationFailure = .missingToken
    for _ in 0 ..< 2 {
        let proof = try makeDPoPProof(
            key: client.dpopKey, method: method, url: url, nonce: nonce,
            accessToken: token, issuedAt: client.harness.clock.now()
        )
        do {
            return try await verifier.authenticate(
                method: method,
                url: #require(URL(string: url + "?collection=app.bsky.feed.post")),
                headers: .init([("Authorization", "\(scheme) \(token)"), ("DPoP", proof)])
            )
        } catch let failure as OAuthResourceAuthorizationFailure {
            guard failure == .useDPoPNonce else { throw failure }
            nonce = verifier.currentNonce()
            lastFailure = failure
        }
    }
    throw lastFailure
}
