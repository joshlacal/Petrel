import Foundation
@testable import PetrelOAuthServer
import Testing

/// Re-signs a token the server minted with new lifetime and key, keeping every
/// other claim, so a verifier can be shown a token the server would no longer
/// mint.
private func resign(
    _ token: String,
    with key: OAuthSigningKey,
    lifetime: Int64? = nil
) throws -> String {
    let claims = try OAuthCompactJWT.unverifiedClaims(OAuthAccessTokenClaims.self, from: token)
    let changed = OAuthAccessTokenClaims(
        iss: claims.iss, aud: claims.aud, sub: claims.sub, clientID: claims.clientID, scope: claims.scope,
        cnf: claims.cnf, iat: claims.iat, exp: lifetime.map { claims.iat + $0 } ?? claims.exp, jti: claims.jti
    )
    return try OAuthCompactJWT.sign(changed, with: key, type: OAuthAccessTokenType.jwtType)
}

private func configuration(
    _ format: OAuthAccessTokenFormat,
    lifetime: TimeInterval = 15 * 60,
    retiring: [OAuthJSONWebKey] = []
) throws -> OAuthAuthorizationServerConfiguration {
    var configuration = try OAuthAuthorizationServerConfiguration(
        issuer: #require(URL(string: TestServer.issuer)),
        serverSecret: Data(repeating: 7, count: 32),
        accessTokenFormat: format
    )
    configuration.accessTokenLifetime = lifetime
    configuration.retiringAccessTokenKeys = retiring
    try configuration.validate()
    return configuration
}

@Suite("Server hardening: token lifetimes, key rotation, concurrent flows, purging")
struct OAuthServerHardeningTests {
    @Test("signed access tokens cannot outlive 15 minutes; opaque ones may live up to 30")
    func signedTokenLifetimeCap() throws {
        let key = try OAuthSigningKey.generate(keyID: "as-1")
        _ = try configuration(.signedJWT(key), lifetime: 15 * 60)
        #expect(throws: OAuthServerError.self) { try configuration(.signedJWT(key), lifetime: 15 * 60 + 1) }
        _ = try configuration(.opaque, lifetime: 29 * 60)
    }

    @Test("a stateless verifier refuses a signed token whose lifetime exceeds 15 minutes")
    func statelessVerifierLifetime() async throws {
        let key = try OAuthSigningKey.generate(keyID: "as-1")
        let harness = try TestServer(accessTokenFormat: .signedJWT(key))
        let client = try TestClient(harness)
        let tokens = try await client.signIn()
        let verifier = try OAuthResourceServerVerifier(
            issuer: #require(URL(string: TestServer.issuer)),
            resource: #require(URL(string: TestServer.issuer)),
            keys: OAuthJSONWebKeySet(keys: [key.publicJWK]),
            secret: Data(repeating: 9, count: 32),
            replayStore: InMemoryOAuthStore(),
            clock: harness.clock
        )
        _ = try await authenticate(verifier, client, token: resign(tokens.accessToken, with: key, lifetime: 15 * 60))
        await #expect(throws: OAuthResourceAuthorizationFailure.self) {
            _ = try await authenticate(verifier, client, token: resign(tokens.accessToken, with: key, lifetime: 16 * 60))
        }
    }

    @Test("a retiring signing key stays in the JWKS and its tokens stay valid until it is removed")
    func retiringKeys() async throws {
        let old = try OAuthSigningKey.generate(keyID: "as-old")
        let current = try OAuthSigningKey.generate(keyID: "as-new")
        let harness = try TestServer(accessTokenFormat: .signedJWT(current), retiringAccessTokenKeys: [old.publicJWK])
        struct JWKS: Decodable {
            struct Key: Decodable { let kid: String? }
            let keys: [Key]
        }
        let jwks = try await harness.get(OAuthAuthorizationServer.Path.jwks).decode(JWKS.self)
        #expect(jwks.keys.map(\.kid) == ["as-new", "as-old"])

        let client = try TestClient(harness)
        let tokens = try await client.signIn()
        _ = try await authenticate(OAuthResourceServerVerifier(authorizationServer: harness.server), client, token: tokens.accessToken)
        // A stateless resource server that loads the published JWKS accepts
        // tokens from both keys, as it must during a rotation.
        let published = try await harness.get(OAuthAuthorizationServer.Path.jwks).decode(OAuthJSONWebKeySet.self)
        let verifier = try OAuthResourceServerVerifier(
            issuer: #require(URL(string: TestServer.issuer)),
            resource: #require(URL(string: TestServer.issuer)),
            keys: published,
            secret: Data(repeating: 9, count: 32),
            replayStore: InMemoryOAuthStore(),
            clock: harness.clock
        )
        _ = try await authenticate(verifier, client, token: tokens.accessToken)
        _ = try await authenticate(verifier, client, token: resign(tokens.accessToken, with: old))
        let unknown = try OAuthSigningKey.generate(keyID: "as-other")
        await #expect(throws: OAuthResourceAuthorizationFailure.self) {
            _ = try await authenticate(verifier, client, token: resign(tokens.accessToken, with: unknown))
        }

        // Key ids must be present and distinct, or a token could not name its key.
        #expect(throws: OAuthServerError.self) { try configuration(.signedJWT(current), retiring: [current.publicJWK]) }
        let unnamed = try OAuthSigningKey.generate(keyID: nil)
        #expect(throws: OAuthServerError.self) { try configuration(.signedJWT(current), retiring: [unnamed.publicJWK]) }
        // Retiring keys only make sense for signed tokens.
        #expect(throws: OAuthServerError.self) { try configuration(.opaque, retiring: [old.publicJWK]) }
    }

    @Test("two authorizations in one browser do not clobber each other's flow")
    func concurrentFlows() async throws {
        let harness = try TestServer()
        let browser = TestBrowser(harness)
        let first = try TestClient(harness)
        let second = try TestClient(harness)
        await browser.open(requestURI: try await first.pushRequest(), clientID: first.clientID)
        let firstCSRF = browser.csrf
        await browser.open(requestURI: try await second.pushRequest(), clientID: second.clientID)
        let secondCSRF = browser.csrf
        #expect(firstCSRF != secondCSRF)

        let credentials = [("identifier", "alice.test"), ("password", "alice-password")]
        let firstSignedIn = await browser.submit(OAuthAuthorizationServer.Path.signIn, credentials, csrf: firstCSRF)
        #expect(firstSignedIn.status == 200, "\(firstSignedIn.text)")
        let secondSignedIn = await browser.submit(OAuthAuthorizationServer.Path.signIn, credentials, csrf: secondCSRF)
        #expect(secondSignedIn.status == 200, "\(secondSignedIn.text)")

        // A CSRF token whose flow cookie is absent is still refused.
        let forged = await TestBrowser(harness).submit(OAuthAuthorizationServer.Path.signIn, credentials, csrf: firstCSRF)
        #expect(forged.status == 400)
    }

    @Test("expired requests, codes and replay markers are purged as the server runs")
    func opportunisticPurge() async throws {
        let harness = try TestServer()
        for _ in 0 ..< 3 {
            _ = try await TestClient(harness).pushRequest()
        }
        #expect(await harness.store.storedRecordCount > 0)
        harness.clock.advance(25 * 60 * 60)
        _ = await harness.get(OAuthAuthorizationServer.Path.authorizationServerMetadata)
        #expect(await harness.store.storedRecordCount == 0)
    }
}
