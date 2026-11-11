import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

/// Credentials go only to the session's own servers.
///
/// A 401 is how a strategy is asked to refresh and replay a request. If the
/// request was for some other origin, replaying it with the account's token
/// attached would hand that token to a third party, and the third party's 401
/// would be mistaken for a problem with the session.
@Suite("OAuth credential scope", .serialized)
struct OAuthCredentialScopeTests {
    private static let aliceDID = "did:plc:scopealice"
    private static let thirdPartyURL = URL(string: "https://third.party.test/xrpc/app.example.getThing")!

    private func unauthorized(_ url: URL, body: String) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: url, statusCode: 401, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }

    private func refreshRequests(_ server: FakeOAuthServer) -> [FakeOAuthServer.RecordedRequest] {
        server.requests(to: .token).filter { $0.form["grant_type"] == "refresh_token" }
    }

    @Test(
        "A 401 from another origin is handed back untouched: no refresh, no replay, no status error",
        arguments: [
            #"{"error":"AuthenticationRequired"}"#,
            #"{"error":"ExpiredToken"}"#,
            #"{"error":"AccountTakedown","message":"says a stranger"}"#,
        ]
    )
    func thirdPartyUnauthorizedIsNotHandled(body: String) async throws {
        let server = FakeOAuthServer()
        let thirdParty = RecordingBackend(host: "third.party.test")
        try await withOAuthTestNetwork([server, thirdParty]) {
            let client = await OAuthTestClient.make(namespace: "scope.thirdparty.\(body.count)", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            let session = try #require(try await client.storage.getSession(for: Self.aliceDID))

            let (response, data) = unauthorized(Self.thirdPartyURL, body: body)
            let (returnedData, returnedResponse) = try await client.strategy.handleUnauthorizedResponse(
                response, data: data, for: URLRequest(url: Self.thirdPartyURL)
            )

            #expect(returnedResponse.statusCode == 401)
            #expect(returnedData == data)
            #expect(thirdParty.requests.isEmpty) // not replayed
            #expect(refreshRequests(server).isEmpty) // not a session problem
            #expect(try await client.storage.getSession(for: Self.aliceDID) == session)
        }
    }

    @Test("With nobody signed in, a 401 is reported as having no active account")
    func unauthorizedWithoutAccount() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "scope.noaccount", server: server)
            let url = URL(string: "\(server.pdsOrigin)/xrpc/app.bsky.feed.getTimeline")!
            let (response, data) = unauthorized(url, body: #"{"error":"AuthMissing"}"#)
            await #expect(throws: AuthError.noActiveAccount) {
                _ = try await client.strategy.handleUnauthorizedResponse(response, data: data, for: URLRequest(url: url))
            }
            #expect(server.requests.isEmpty)
        }
    }

    @Test("The authorization server's origin is not sent the access token either")
    func authorizationServerOriginIsNotReplayed() async throws {
        let server = FakeOAuthServer() // entryway layout: issuer differs from the PDS
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "scope.issuer", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            let url = URL(string: "\(server.issuer)/xrpc/com.atproto.server.getSession")!
            let before = server.requests.count

            let (response, data) = unauthorized(url, body: #"{"error":"InvalidToken"}"#)
            let (_, returned) = try await client.strategy.handleUnauthorizedResponse(
                response, data: data, for: URLRequest(url: url)
            )
            #expect(returned.statusCode == 401)
            #expect(server.requests.count == before)
        }
    }

    @Test("A request to another origin made through the client never carries the account's credentials")
    func thirdPartyRequestThroughNetworkService() async throws {
        let server = FakeOAuthServer()
        let thirdParty = RecordingBackend(host: "third.party.test")
        try await withOAuthTestNetwork([server, thirdParty]) {
            let client = await OAuthTestClient.make(namespace: "scope.network", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)

            // Whether the 401 is returned or thrown is the network layer's
            // business; what matters here is what the third party was sent.
            _ = try? await client.networkService.request(URLRequest(url: Self.thirdPartyURL), skipTokenRefresh: false)

            #expect(!thirdParty.requests.isEmpty)
            for request in thirdParty.requests {
                #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
                #expect(request.value(forHTTPHeaderField: "DPoP") == nil)
            }
            #expect(refreshRequests(server).isEmpty)
            // The session is untouched and still works against its own PDS.
            #expect(try await client.getSession().1.statusCode == 200)
        }
    }

    @Test("A 401 from the account's own PDS is still answered by refreshing and replaying")
    func ownPDSUnauthorizedIsHandled() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "scope.ownpds", server: server)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            #expect(try await client.getSession().1.statusCode == 200)
            let url = URL(string: "\(server.pdsOrigin)/xrpc/com.atproto.server.getSession")!

            let (response, data) = unauthorized(url, body: #"{"error":"InvalidToken"}"#)
            let (_, replayed) = try await client.strategy.handleUnauthorizedResponse(
                response, data: data, for: URLRequest(url: url)
            )
            #expect(replayed.statusCode == 200)
            #expect(refreshRequests(server).count == 1)
        }
    }

    @Test("App-password sessions: a 401 from another origin is not refreshed for and not replayed")
    func passwordSessionThirdParty() async throws {
        let pds = FakePasswordPDS()
        pds.add(FakePasswordPDS.Account(
            did: Self.aliceDID, handle: "alice.test", email: "alice@example.com", password: "app-password"
        ))
        let thirdParty = RecordingBackend(host: "third.party.test")
        try await withOAuthTestNetwork([pds, thirdParty]) {
            let storage = KeychainStorage(namespace: "scope.password")
            let accountManager = await AccountManager(storage: storage)
            let networkService = NetworkService(baseURL: pds.url)
            let resolver = OAuthTestDIDResolver()
            resolver.register(did: Self.aliceDID, handle: "alice.test", pds: pds.url)
            let strategy = LegacyPasswordStrategy(
                storage: storage, accountManager: accountManager, networkService: networkService, didResolver: resolver
            )
            await networkService.setAuthenticationProvider(strategy)
            _ = try await strategy.loginWithPassword(
                identifier: "alice.test", password: "app-password", bskyAppViewDID: nil, bskyChatDID: nil
            )

            let (response, data) = unauthorized(Self.thirdPartyURL, body: #"{"error":"ExpiredToken"}"#)
            let (_, returned) = try await strategy.handleUnauthorizedResponse(
                response, data: data, for: URLRequest(url: Self.thirdPartyURL)
            )
            #expect(returned.statusCode == 401)
            #expect(pds.requests(to: "refreshSession").isEmpty)
            #expect(thirdParty.requests.isEmpty)

            _ = try? await networkService.request(URLRequest(url: Self.thirdPartyURL), skipTokenRefresh: false)
            #expect(thirdParty.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == nil })
            #expect(pds.requests(to: "refreshSession").isEmpty)
        }
    }

    // MARK: - Fresh identity at the callback

    @Test("Server-first: the account is re-resolved past the resolver's cache before it is trusted")
    func subjectIsResolvedFresh() async throws {
        let server = FakeOAuthServer()
        let resolver = CachingTestDIDResolver()
        // The cache still remembers a PDS the account has since left.
        resolver.cached.register(did: Self.aliceDID, handle: "alice.test", pds: URL(string: "https://pds.stale.test")!)
        resolver.network.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)

        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "scope.fresh.server", server: server, didResolver: resolver)
            let (url, _) = try await client.strategy.startOAuthFlow(target: .server(server.pdsURL), scope: nil)
            let result = try await client.strategy.handleOAuthCallback(url: server.approve(url, as: Self.aliceDID))

            #expect(result.pdsURL == server.pdsURL)
            #expect(resolver.forcedLookups == [Self.aliceDID])
        }
    }

    @Test("Identifier-first: an account that has moved since the cache was filled is refused")
    func staleCacheDoesNotHideAMove() async throws {
        let server = FakeOAuthServer()
        let resolver = CachingTestDIDResolver()
        resolver.cached.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
        // The network knows the account now lives elsewhere.
        resolver.network.register(did: Self.aliceDID, handle: "alice.test", pds: URL(string: "https://pds.moved.test")!)

        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "scope.fresh.identifier", server: server, didResolver: resolver)
            let (url, _) = try await client.strategy.startOAuthFlowWithState(identifier: "alice.test")
            let redirect = try server.approve(url, as: Self.aliceDID)
            await #expect(throws: AuthError.invalidOAuthConfiguration) {
                _ = try await client.strategy.handleOAuthCallback(url: redirect)
            }
            #expect(resolver.forcedLookups == [Self.aliceDID])
            #expect(server.isRevoked(sub: Self.aliceDID))
        }
    }
}
