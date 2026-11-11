import Foundation
import PetrelOAuthServer
import Testing

/// The code in the DocC guide "Run your own authorization server", compiled
/// and run so the guide cannot drift from the API.
@Suite("Documentation: run your own authorization server")
struct DocumentationExampleTests {
    struct MyAccounts: OAuthAccountAuthenticating {
        func signIn(identifier: String, password: String, context _: OAuthSignInContext) async throws -> OAuthSignInResult {
            guard identifier == "alice.example.com", password == "correct horse" else { return .rejected }
            return .authenticated(OAuthAccount(did: "did:plc:alice", handle: "alice.example.com"))
        }

        func account(did: String) async throws -> OAuthAccount? {
            did == "did:plc:alice" ? OAuthAccount(did: did, handle: "alice.example.com") : nil
        }
    }

    @Test("the guide's server answers metadata and challenges an unauthenticated resource request")
    func guide() async throws {
        let secret = Data((0 ..< 32).map { _ in UInt8.random(in: .min ... .max) })

        let store = InMemoryOAuthStore()
        // A transport that pins each connection to the approved DNS answers,
        // such as PinnedNIOOAuthRemoteTransport from PetrelOAuthServerHummingbird.
        let transport: any OAuthRemoteTransport = StubTransport()
        let server = try OAuthAuthorizationServer(
            configuration: OAuthAuthorizationServerConfiguration(
                issuer: #require(URL(string: "https://pds.example.com")),
                serverSecret: secret
            ),
            store: store,
            accounts: MyAccounts(),
            clients: OAuthClientMetadataLoader(
                fetcher: OAuthRemoteDocumentFetcher(policy: OAuthRemoteFetchPolicy(), transport: transport),
                cache: store
            )
        )

        let response = await server.handle(
            OAuthHTTPRequest(method: "GET", path: "/.well-known/oauth-authorization-server")
        )
        #expect(response.status == 200)
        #expect(String(decoding: response.body, as: UTF8.self).contains("\"issuer\":\"https://pds.example.com\""))
        #expect(OAuthAuthorizationServer.routes.contains(OAuthRoute(method: "POST", path: "/oauth/par")))

        let verifier = OAuthResourceServerVerifier(authorizationServer: server)
        let requestURL = try #require(URL(string: "https://pds.example.com/xrpc/com.atproto.repo.createRecord"))
        let requestHeaders = OAuthHTTPHeaders()
        var challenge: OAuthHTTPResponse?
        do {
            let grant = try await verifier.authenticate(method: "POST", url: requestURL, headers: requestHeaders)
            try grant.requireRepo(collection: "app.bsky.feed.post", action: .create)
        } catch {
            challenge = verifier.challenge(for: error)
        }
        #expect(challenge?.status == 401)
        #expect(challenge?.headers["WWW-Authenticate"]?.hasPrefix("DPoP") == true)
        #expect(challenge?.headers["DPoP-Nonce"] == verifier.currentNonce())
    }
}
