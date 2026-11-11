import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

/// A stub Client Assertion Backend: answers every assertion request with a new
/// opaque assertion and records the audience it was asked for.
final class FakeAssertionBackend: OAuthTestBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var issued: [(assertion: String, audience: String?)] = []

    var issuedAssertions: [String] { lock.withLock { issued.map(\.assertion) } }
    var audiences: [String?] { lock.withLock { issued.map(\.audience) } }

    func serves(host: String) -> Bool {
        host == "cab.oauth.test"
    }

    func handle(_ request: URLRequest, body: Data) -> (HTTPURLResponse, Data) {
        let form = FakeOAuthServer.parseForm(body)
        let assertion: String = lock.withLock {
            let value = "backend-assertion-\(issued.count + 1)"
            issued.append((value, form["aud"]))
            return value
        }
        let payload = ["client_id": OAuthTestClient.clientID, "client_assertion": assertion]
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, try! JSONSerialization.data(withJSONObject: payload))
    }

    /// A session whose requests are routed to the installed test backends.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OAuthTestURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

/// Logout and account removal must end the session at the authorization
/// server (RFC 7009), not merely forget it locally. `FakeOAuthServer` verifies
/// the revocation request's DPoP proof and nonce exactly as it does for token
/// requests — which is what the reference authorization server does — so these
/// tests fail if revocation is sent without a valid proof, without a retry on
/// a nonce challenge, or (for a confidential client) without client authentication.
@Suite("OAuth revocation", .serialized)
struct OAuthRevocationTests {
    private static let aliceDID = "did:plc:revokealice"

    @Test("Logout revokes the refresh token with a valid DPoP proof and wipes local state")
    func logoutRevokes() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "revoke.logout", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            let session = try #require(try await client.storage.getSession(for: Self.aliceDID))

            try await client.strategy.logout()

            let revocation = try #require(server.requests(to: .revoke).last)
            #expect(revocation.status == 200)
            #expect(revocation.url.absoluteString == server.revocationEndpoint)
            #expect(revocation.form == [
                "token": try #require(session.refreshToken),
                "client_id": OAuthTestClient.clientID,
            ])
            #expect(revocation.proof?.thumbprint == server.requests(to: .token).last?.proof?.thumbprint)
            #expect(server.isRevoked(sub: Self.aliceDID))
            #expect(server.activeGrantCount == 0)

            // Local state is gone: session, DPoP key, nonces, current account.
            #expect(try await client.storage.getSession(for: Self.aliceDID) == nil)
            #expect(try await client.storage.getDPoPKeyRepresentation(for: Self.aliceDID) == nil)
            #expect(try await client.storage.getDPoPNonces(for: Self.aliceDID)?.isEmpty != false)
            #expect(await client.accountManager.getCurrentAccount() == nil)
            #expect(!(await client.strategy.tokensExist()))
        }
    }

    @Test("Logout with a stale authorization-server nonce retries and still revokes")
    func logoutRevokesAfterNonceChallenge() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "revoke.nonce", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            // The usual case: the authorization server's nonce has rotated since
            // the client last spoke to it.
            let stale = server.currentAuthorizationServerNonce
            server.rotateAuthorizationServerNonce()

            try await client.strategy.logout()

            let attempts = server.requests(to: .revoke)
            #expect(attempts.map(\.status) == [400, 200])
            #expect(attempts[0].proof?.nonce == stale)
            #expect(attempts[1].proof?.nonce == server.currentAuthorizationServerNonce)
            #expect(server.isRevoked(sub: Self.aliceDID))
        }
    }

    @Test("Logout completes locally when the authorization server cannot revoke")
    func logoutSurvivesRevocationFailure() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "revoke.failure", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            server.forcedErrors[.revoke] = (503, "temporarily_unavailable")

            #expect(await client.strategy.revokeSession(for: Self.aliceDID) == false)
            try await client.strategy.logout()

            #expect(!server.isRevoked(sub: Self.aliceDID))
            #expect(try await client.storage.getSession(for: Self.aliceDID) == nil)
            #expect(await client.accountManager.getCurrentAccount() == nil)
        }
    }

    @Test("A server without a revocation endpoint is reported as not revoked")
    func noRevocationEndpoint() async throws {
        let server = FakeOAuthServer()
        server.authorizationServerMetadataOverrides["revocation_endpoint"] = NSNull()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "revoke.noendpoint", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            #expect(await client.strategy.revokeSession(for: Self.aliceDID) == false)
            #expect(server.requests(to: .revoke).isEmpty)
        }
    }

    @Test("revokeSession reports true only when the server confirmed, and the session is then dead")
    func revokeSessionOutcome() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "revoke.outcome", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            #expect(try await client.getSession().1.statusCode == 200)

            #expect(await client.strategy.revokeSession(for: Self.aliceDID) == true)
            #expect(await client.strategy.revokeSession(for: "did:plc:nobody") == false)

            // The server now refuses both the access token and the refresh token.
            await #expect(throws: (any Error).self) {
                _ = try await client.getSession()
            }
            #expect(server.requests(to: .resource).last?.status == 401)
        }
    }

    @Test("Removing an account revokes its session before deleting it")
    func removeAccountRevokes() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            // Wired the way ATProtoClient wires it: AuthManager over a real AccountManager.
            let storage = KeychainStorage(namespace: "revoke.remove")
            let accountManager = await AccountManager(storage: storage)
            let networkService = NetworkService(baseURL: server.pdsURL)
            let resolver = OAuthTestDIDResolver()
            resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
            let authManager = try AuthManager(
                mode: .publicOAuth,
                storage: storage,
                accountManager: accountManager,
                networkService: networkService,
                oauthConfig: OAuthConfig(
                    clientId: OAuthTestClient.clientID, redirectUri: OAuthTestClient.redirectURI, scope: "atproto"
                ),
                didResolver: resolver
            )
            await networkService.setAuthenticationProvider(authManager)

            let (url, _) = try await authManager.startOAuthFlowWithState(identifier: "alice.test")
            _ = try await authManager.handleOAuthCallback(url: server.approve(url, as: Self.aliceDID))
            let refreshToken = try #require(try await storage.getSession(for: Self.aliceDID)?.refreshToken)

            try await accountManager.removeAccount(did: Self.aliceDID)

            let revocation = try #require(server.requests(to: .revoke).last)
            #expect(revocation.status == 200)
            #expect(revocation.form["token"] == refreshToken)
            #expect(server.isRevoked(sub: Self.aliceDID))
            #expect(try await storage.getSession(for: Self.aliceDID) == nil)
            #expect(await accountManager.listAccounts().isEmpty)
        }
    }

    // MARK: - Confidential client through a Client Assertion Backend

    @Test("CAB: every authorization-server request, including revocation, carries a fresh client assertion")
    func cabAuthenticatesEveryRequest() async throws {
        let server = FakeOAuthServer()
        server.clientAuthentication = .opaqueSingleUse
        let backend = FakeAssertionBackend()
        try await withOAuthTestNetwork([server, backend]) {
            let client = await OAuthTestClient.make(
                namespace: "revoke.cab", server: server, cabBackendSession: FakeAssertionBackend.makeSession()
            )
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            _ = try await client.strategy.refreshTokenIfNeeded(forceRefresh: true)

            // A stale nonce at logout, so the revocation is itself retried.
            server.rotateAuthorizationServerNonce()
            try await client.strategy.logout()

            let revocations = server.requests(to: .revoke)
            #expect(revocations.map(\.status) == [400, 200])
            for revocation in revocations {
                #expect(revocation.form["client_assertion_type"] == "urn:ietf:params:oauth:client-assertion-type:jwt-bearer")
                #expect(revocation.form["client_assertion"]?.hasPrefix("backend-assertion-") == true)
                #expect(revocation.form["client_id"] == OAuthTestClient.clientID)
            }
            #expect(server.isRevoked(sub: Self.aliceDID))

            // No assertion was ever sent twice — not even on a nonce retry — and
            // each was requested for the validated issuer.
            let sent = server.requests
                .filter { [.par, .token, .revoke].contains($0.endpoint) }
                .compactMap { $0.form["client_assertion"] }
            #expect(sent.count >= 6) // PAR ×2, code exchange, refresh, revoke ×2
            #expect(Set(sent).count == sent.count)
            #expect(backend.audiences.allSatisfy { $0 == server.issuer })
        }
    }

    @Test("CAB: a public-only authorization server is refused before any assertion is requested")
    func cabRequiresPrivateKeyJWTSupport() async throws {
        let server = FakeOAuthServer()
        server.authorizationServerMetadataOverrides["token_endpoint_auth_methods_supported"] = ["none"]
        let backend = FakeAssertionBackend()
        try await withOAuthTestNetwork([server, backend]) {
            let client = await OAuthTestClient.make(
                namespace: "revoke.cab.publiconly", server: server, cabBackendSession: FakeAssertionBackend.makeSession()
            )
            client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
            await #expect(throws: OAuthMetadataError.missingRequiredValue(
                field: "token_endpoint_auth_methods_supported", value: "private_key_jwt"
            )) {
                _ = try await client.strategy.startOAuthFlowWithState(identifier: "alice.test")
            }
            #expect(backend.issuedAssertions.isEmpty)
        }
    }
}
