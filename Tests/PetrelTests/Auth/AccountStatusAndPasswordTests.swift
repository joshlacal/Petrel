import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

/// An in-memory PDS implementing the app-password session endpoints. It checks
/// which token authorizes which endpoint — `refreshSession` and `deleteSession`
/// take the refresh JWT, everything else the access JWT — so a client that
/// sends the wrong one fails here as it would against a real PDS.
final class FakePasswordPDS: OAuthTestBackend, @unchecked Sendable {
    struct Account {
        var did: String
        var handle: String
        var email: String
        var password: String
        var status: (active: Bool, status: String?) = (true, nil)
        var requiresAuthFactor = false
    }

    struct RecordedRequest: @unchecked Sendable {
        let path: String
        let headers: [String: String]
        let body: [String: Any]
        let status: Int
    }

    static let authFactorCode = "ABCDE-12345"

    let origin: String
    /// Makes `createSession` answer for this DID whatever was asked (a misbehaving server).
    var createSessionDIDOverride: String?
    var forcedStatus: [String: Int] = [:]
    /// Lifetime, in seconds, of the access JWTs issued (`exp` − `iat`).
    var accessTokenLifetime = 7200

    private let lock = NSLock()
    private var accounts: [String: Account] = [:]
    private var accessTokens: [String: String] = [:]
    private var refreshTokens: [String: String] = [:]
    private var recorded: [RecordedRequest] = []
    private var counter = 0

    init(origin: String = "https://pds.password.test") {
        self.origin = origin
    }

    var url: URL { URL(string: origin)! }
    var requests: [RecordedRequest] { lock.withLock { recorded } }
    func requests(to method: String) -> [RecordedRequest] { requests.filter { $0.path.hasSuffix(method) } }
    var liveSessionCount: Int { lock.withLock { refreshTokens.count } }

    func add(_ account: Account) {
        lock.withLock { accounts[account.did] = account }
    }

    func setStatus(_ status: (active: Bool, status: String?), for did: String) {
        lock.withLock { accounts[did]?.status = status }
    }

    func serves(host: String) -> Bool {
        host == URL(string: origin)?.host
    }

    func handle(_ request: URLRequest, body: Data) -> (HTTPURLResponse, Data) {
        let path = request.url!.path
        let json = ((try? JSONSerialization.jsonObject(with: body)) as? [String: Any]) ?? [:]
        let bearer = request.value(forHTTPHeaderField: "Authorization").flatMap {
            $0.hasPrefix("Bearer ") ? String($0.dropFirst(7)) : nil
        }
        let (status, payload): (Int, [String: Any]) = lock.withLock {
            if let forced = forcedStatus[path.components(separatedBy: "/").last ?? ""] {
                return (forced, ["error": "InternalServerError", "message": "forced"])
            }
            switch path {
            case "/xrpc/com.atproto.server.createSession": return createSession(json, bearer: bearer)
            case "/xrpc/com.atproto.server.refreshSession": return refreshSession(bearer)
            case "/xrpc/com.atproto.server.deleteSession": return deleteSession(bearer)
            case "/xrpc/com.atproto.server.getSession": return getSession(bearer)
            default: return (404, ["error": "MethodNotImplemented"])
            }
        }
        lock.withLock {
            recorded.append(RecordedRequest(
                path: path, headers: request.allHTTPHeaderFields ?? [:], body: json, status: status
            ))
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, try! JSONSerialization.data(withJSONObject: payload))
    }

    private func statusRefusal(_ account: Account) -> (Int, [String: Any])? {
        switch account.status.status {
        case "takendown": (401, ["error": "AccountTakedown", "message": "Account has been taken down"])
        case "suspended": (401, ["error": "AccountSuspended", "message": "Account is suspended"])
        default: nil
        }
    }

    private func issue(for account: Account) -> [String: Any] {
        counter += 1
        let now = Int(Date().timeIntervalSince1970)
        let claims = try! JSONSerialization.data(withJSONObject: ["iat": now, "exp": now + accessTokenLifetime, "sub": account.did])
        let accessJwt = "eyJhbGciOiJIUzI1NiJ9.\(TestJOSE.base64URLEncode(claims)).access\(counter)"
        let refreshJwt = "refresh-jwt-\(counter)"
        accessTokens[accessJwt] = account.did
        refreshTokens[refreshJwt] = account.did
        var response: [String: Any] = [
            "accessJwt": accessJwt,
            "refreshJwt": refreshJwt,
            "handle": account.handle,
            "did": createSessionDIDOverride ?? account.did,
            "active": account.status.active,
        ]
        response["status"] = account.status.status
        return response
    }

    private func createSession(_ json: [String: Any], bearer: String?) -> (Int, [String: Any]) {
        guard bearer == nil else { return (400, ["error": "InvalidRequest", "message": "unexpected credentials"]) }
        let identifier = json["identifier"] as? String
        guard let account = accounts.values.first(where: {
            $0.did == identifier || $0.handle == identifier || $0.email == identifier
        }), account.password == json["password"] as? String else {
            return (401, ["error": "AuthenticationRequired", "message": "Invalid identifier or password"])
        }
        if let refusal = statusRefusal(account) { return refusal }
        if account.requiresAuthFactor {
            guard let token = json["authFactorToken"] as? String else {
                return (401, ["error": "AuthFactorTokenRequired", "message": "A sign in code has been sent to your email address"])
            }
            guard token == Self.authFactorCode else {
                return (401, ["error": "AuthenticationRequired", "message": "Token is invalid"])
            }
        }
        return (200, issue(for: account))
    }

    private func refreshSession(_ bearer: String?) -> (Int, [String: Any]) {
        guard let bearer, let did = refreshTokens[bearer], let account = accounts[did] else {
            return (400, ["error": "InvalidToken", "message": "refresh token required"])
        }
        // As in the reference PDS, the account's status is checked before the
        // refresh token is rotated: a refusal leaves the token valid.
        if let refusal = statusRefusal(account) { return refusal }
        refreshTokens.removeValue(forKey: bearer)
        return (200, issue(for: account))
    }

    private func deleteSession(_ bearer: String?) -> (Int, [String: Any]) {
        guard let bearer, let did = refreshTokens.removeValue(forKey: bearer) else {
            return (400, ["error": "InvalidToken", "message": "refresh token required"])
        }
        accessTokens = accessTokens.filter { $0.value != did }
        return (200, [:])
    }

    private func getSession(_ bearer: String?) -> (Int, [String: Any]) {
        guard let bearer, let did = accessTokens[bearer], let account = accounts[did] else {
            return (401, ["error": "InvalidToken", "message": "access token required"])
        }
        if let refusal = statusRefusal(account) { return refusal }
        var response: [String: Any] = ["did": did, "handle": account.handle, "active": account.status.active]
        response["status"] = account.status.status
        return (200, response)
    }
}

/// Account hosting status (the atproto Account spec) at the session layer, and
/// the app-password session endpoints.
@Suite("Account status and app-password sessions", .serialized)
struct AccountStatusAndPasswordTests {
    private static let aliceDID = "did:plc:passwordalice"
    private static let alice = FakePasswordPDS.Account(
        did: aliceDID, handle: "alice.test", email: "alice@example.com", password: "app-password"
    )

    private struct Client {
        let strategy: LegacyPasswordStrategy
        let storage: KeychainStorage
        let accountManager: AccountManager
        let networkService: NetworkService
    }

    /// An app-password client whose configured service is `entryway`.
    private func makeClient(namespace: String, pds: FakePasswordPDS, service: URL? = nil) async -> Client {
        let storage = KeychainStorage(namespace: namespace)
        let accountManager = await AccountManager(storage: storage)
        let networkService = NetworkService(baseURL: service ?? pds.url)
        let resolver = OAuthTestDIDResolver()
        resolver.register(did: Self.aliceDID, handle: "alice.test", pds: pds.url)
        let strategy = LegacyPasswordStrategy(
            storage: storage, accountManager: accountManager, networkService: networkService, didResolver: resolver
        )
        await networkService.setAuthenticationProvider(strategy)
        return Client(strategy: strategy, storage: storage, accountManager: accountManager, networkService: networkService)
    }

    private func signIn(_ client: Client, identifier: String = "alice.test", authFactorToken: String? = nil) async throws -> String {
        try await client.strategy.loginWithPassword(
            identifier: identifier, password: "app-password", authFactorToken: authFactorToken,
            bskyAppViewDID: nil, bskyChatDID: nil
        ).did
    }

    private func getSession(_ client: Client, pds: FakePasswordPDS) async throws -> HTTPURLResponse {
        let url = URL(string: "\(pds.origin)/xrpc/com.atproto.server.getSession")!
        let (_, response) = try await client.networkService.request(URLRequest(url: url), skipTokenRefresh: false)
        return try #require(response as? HTTPURLResponse)
    }

    // MARK: - AccountStatus

    @Test("active and status are interpreted per the Account spec, and unknown statuses are preserved")
    func accountStatusInterpretation() {
        #expect(AccountStatus(active: true, status: nil) == .active)
        #expect(AccountStatus(active: nil, status: nil).isActive) // endpoints predating the flag
        for (status, reason) in [
            ("takendown", AccountStatus.Reason.takendown), ("suspended", .suspended), ("deleted", .deleted),
            ("deactivated", .deactivated), ("desynchronized", .desynchronized), ("throttled", .throttled),
        ] {
            let parsed = AccountStatus(active: false, status: status)
            #expect(!parsed.isActive)
            #expect(parsed.reason == reason)
            #expect(parsed.reason?.rawValue == status)
        }
        // "active may be true" for these two.
        #expect(AccountStatus(active: true, status: "desynchronized").isActive)
        #expect(AccountStatus(active: true, status: "throttled").reason == .throttled)
        // New states may be added at any time.
        let future = AccountStatus(active: false, status: "quarantined")
        #expect(future.reason == .other("quarantined"))
        #expect(future.reason?.rawValue == "quarantined")
        // active: false with no status is valid.
        #expect(AccountStatus(active: false, status: nil) == AccountStatus(isActive: false, reason: nil))
        #expect(AccountStatus(active: false, status: "takendown").description == "inactive (takendown)")
    }

    @Test("XRPC status error names map to typed errors; other errors do not")
    func statusErrorNames() {
        #expect(AccountStatusError(xrpcErrorName: "AccountTakedown")?.status.reason == .takendown)
        #expect(AccountStatusError(xrpcErrorName: "AccountSuspended")?.status.reason == .suspended)
        #expect(AccountStatusError(xrpcErrorName: "AccountDeactivated")?.status.reason == .deactivated)
        #expect(AccountStatusError(xrpcErrorName: "AccountDeleted")?.status.reason == .deleted)
        #expect(AccountStatusError(xrpcErrorName: "AccountTakedown")?.status.isActive == false)
        #expect(AccountStatusError(xrpcErrorName: "ExpiredToken") == nil)
        #expect(AccountStatusError(xrpcErrorName: "InvalidToken") == nil)
        let parsed = AccountStatusError(xrpcErrorBody: Data(#"{"error":"AccountTakedown","message":"gone"}"#.utf8))
        #expect(parsed == AccountStatusError(status: AccountStatus(isActive: false, reason: .takendown), message: "gone"))
        #expect(AccountStatusError(xrpcErrorBody: Data("not json".utf8)) == nil)
    }

    // MARK: - Sign-in

    @Test(
        "Sign-in by handle or DID goes to the account's own PDS, with no credentials attached",
        arguments: ["alice.test", "did:plc:passwordalice"]
    )
    func signInByHandleOrDID(identifier: String) async throws {
        let pds = FakePasswordPDS()
        pds.add(Self.alice)
        // The client is configured for some other service; the PDS comes from the DID.
        let elsewhere = FakePasswordPDS(origin: "https://entryway.password.test")
        try await withOAuthTestNetwork([pds, elsewhere]) {
            let client = await makeClient(namespace: "password.signin.\(identifier)", pds: pds, service: elsewhere.url)
            #expect(try await signIn(client, identifier: identifier) == Self.aliceDID)

            let request = try #require(pds.requests(to: "createSession").last)
            #expect(elsewhere.requests.isEmpty)
            #expect(request.body["identifier"] as? String == identifier)
            #expect(request.body["authFactorToken"] == nil)
            #expect(request.headers["Authorization"] == nil)
            #expect(request.headers["DPoP"] == nil)

            let session = try #require(try await client.storage.getSession(for: Self.aliceDID))
            #expect(session.tokenType == .bearer)
            #expect(session.expiresIn == 7200) // read from the access JWT's exp − iat
            let account = try #require(await client.accountManager.getCurrentAccount())
            #expect(account.pdsURL == pds.url)
            #expect(account.authorizationServerIssuer == nil)
            #expect(await client.strategy.lastKnownAccountStatus(for: Self.aliceDID) == .active)
            #expect(try await getSession(client, pds: pds).statusCode == 200)
        }
    }

    @Test("Sign-in by email goes to the configured service; the PDS comes from the account's DID")
    func signInByEmail() async throws {
        let pds = FakePasswordPDS()
        // The configured service knows the account by email; its real PDS is elsewhere.
        let entryway = FakePasswordPDS(origin: "https://entryway.password.test")
        entryway.add(Self.alice)
        try await withOAuthTestNetwork([pds, entryway]) {
            let client = await makeClient(namespace: "password.signin.email", pds: pds, service: entryway.url)
            let did = try await signIn(client, identifier: "alice@example.com")
            #expect(did == Self.aliceDID)
            #expect(entryway.requests(to: "createSession").last?.body["identifier"] as? String == "alice@example.com")
            #expect(pds.requests.isEmpty)
            #expect(await client.accountManager.getCurrentAccount()?.pdsURL == pds.url)
        }
    }

    @Test("A wrong password is invalid credentials")
    func wrongPassword() async throws {
        let pds = FakePasswordPDS()
        pds.add(Self.alice)
        try await withOAuthTestNetwork([pds]) {
            let client = await makeClient(namespace: "password.wrong", pds: pds)
            await #expect(throws: AuthError.invalidCredentials) {
                _ = try await client.strategy.loginWithPassword(
                    identifier: "alice.test", password: "nope", bskyAppViewDID: nil, bskyChatDID: nil
                )
            }
            let stored = try await client.storage.getSession(for: Self.aliceDID)
            #expect(stored == nil)
        }
    }

    @Test(
        "Signing in to a taken-down or suspended account reports the status, not bad credentials",
        arguments: ["takendown", "suspended"]
    )
    func signInRefusedForStatus(status: String) async throws {
        let pds = FakePasswordPDS()
        var account = Self.alice
        account.status = (false, status)
        pds.add(account)
        try await withOAuthTestNetwork([pds]) {
            let client = await makeClient(namespace: "password.status.\(status)", pds: pds)
            let error = await #expect(throws: AccountStatusError.self) {
                _ = try await signIn(client)
            }
            #expect(error?.status == AccountStatus(isActive: false, reason: AccountStatus.Reason(status)))
            #expect(error?.message != nil)
            let stored = try await client.storage.getSession(for: Self.aliceDID)
            #expect(stored == nil)
        }
    }

    @Test("A deactivated account can sign in, and its status is kept")
    func deactivatedAccountSignsIn() async throws {
        let pds = FakePasswordPDS()
        var account = Self.alice
        account.status = (false, "deactivated")
        pds.add(account)
        try await withOAuthTestNetwork([pds]) {
            let client = await makeClient(namespace: "password.deactivated", pds: pds)
            let did = try await signIn(client)
            #expect(did == Self.aliceDID)
            #expect(await client.strategy.lastKnownAccountStatus(for: Self.aliceDID)
                == AccountStatus(isActive: false, reason: .deactivated))
        }
    }

    @Test("Email two-factor: the first attempt asks for a code, the second supplies it")
    func authFactorToken() async throws {
        let pds = FakePasswordPDS()
        var account = Self.alice
        account.requiresAuthFactor = true
        pds.add(account)
        try await withOAuthTestNetwork([pds]) {
            let client = await makeClient(namespace: "password.2fa", pds: pds)
            await #expect(throws: AuthFactorTokenRequiredError()) {
                _ = try await signIn(client)
            }
            await #expect(throws: AuthError.invalidCredentials) {
                _ = try await signIn(client, authFactorToken: "wrong")
            }
            let did = try await signIn(client, authFactorToken: FakePasswordPDS.authFactorCode)
            #expect(did == Self.aliceDID)
            #expect(pds.requests(to: "createSession").last?.body["authFactorToken"] as? String == FakePasswordPDS.authFactorCode)
        }
    }

    @Test("A session for a different account than the one requested is discarded and ended")
    func mismatchedAccountIsRefused() async throws {
        let pds = FakePasswordPDS()
        pds.add(Self.alice)
        pds.createSessionDIDOverride = "did:plc:someoneelse"
        try await withOAuthTestNetwork([pds]) {
            let client = await makeClient(namespace: "password.mismatch", pds: pds)
            await #expect(throws: AuthError.invalidResponse) {
                _ = try await signIn(client)
            }
            let requested = try await client.storage.getSession(for: Self.aliceDID)
            let returned = try await client.storage.getSession(for: "did:plc:someoneelse")
            #expect(requested == nil)
            #expect(returned == nil)
            #expect(await client.accountManager.getCurrentAccount() == nil)
            // The stray session was ended server-side.
            #expect(pds.requests(to: "deleteSession").last?.status == 200)
            #expect(pds.liveSessionCount == 0)
        }
    }

    // MARK: - Refresh and logout

    @Test("Refresh presents the refresh JWT to the account's PDS and leaves the client's base URL alone")
    func refreshUsesRefreshToken() async throws {
        let pds = FakePasswordPDS()
        pds.add(Self.alice)
        try await withOAuthTestNetwork([pds]) {
            let client = await makeClient(namespace: "password.refresh", pds: pds)
            _ = try await signIn(client)
            let original = try #require(try await client.storage.getSession(for: Self.aliceDID))
            let baseURL = await client.networkService.baseURL

            #expect(try await client.strategy.refreshTokenIfNeeded(forceRefresh: true) == .refreshedSuccessfully)

            let request = try #require(pds.requests(to: "refreshSession").last)
            #expect(request.status == 200)
            #expect(request.headers["Authorization"] == "Bearer \(try #require(original.refreshToken))")
            let refreshed = try #require(try await client.storage.getSession(for: Self.aliceDID))
            #expect(refreshed.accessToken != original.accessToken)
            #expect(refreshed.refreshToken != original.refreshToken)
            #expect(await client.networkService.baseURL == baseURL)
            #expect(try await getSession(client, pds: pds).statusCode == 200)
        }
    }

    @Test("A server error during refresh does not spend the refresh token")
    func refreshSurvivesServerError() async throws {
        let pds = FakePasswordPDS()
        pds.add(Self.alice)
        try await withOAuthTestNetwork([pds]) {
            let client = await makeClient(namespace: "password.refresh.5xx", pds: pds)
            _ = try await signIn(client)
            pds.forcedStatus["com.atproto.server.refreshSession"] = 503
            await #expect(throws: AuthError.tokenRefreshFailed) {
                _ = try await client.strategy.refreshTokenIfNeeded(forceRefresh: true)
            }
            pds.forcedStatus = [:]
            #expect(try await client.strategy.refreshTokenIfNeeded(forceRefresh: true) == .refreshedSuccessfully)
        }
    }

    @Test("Refreshing a taken-down account reports the status")
    func refreshReportsStatus() async throws {
        let pds = FakePasswordPDS()
        pds.add(Self.alice)
        try await withOAuthTestNetwork([pds]) {
            let client = await makeClient(namespace: "password.refresh.takedown", pds: pds)
            _ = try await signIn(client)
            pds.setStatus((false, "takendown"), for: Self.aliceDID)
            let error = await #expect(throws: AccountStatusError.self) {
                _ = try await client.strategy.refreshTokenIfNeeded(forceRefresh: true)
            }
            #expect(error?.status.reason == .takendown)
            #expect(await client.strategy.lastKnownAccountStatus(for: Self.aliceDID)?.reason == .takendown)
        }
    }

    @Test("A refresh refused for the account's status, on the way to an ordinary request, reaches the caller as the status")
    func proactiveRefreshRefusedForStatus() async throws {
        let pds = FakePasswordPDS()
        pds.add(Self.alice)
        pds.accessTokenLifetime = 1 // due for refresh before the next request
        try await withOAuthTestNetwork([pds]) {
            let client = await makeClient(namespace: "password.proactive.takedown", pds: pds)
            _ = try await signIn(client)
            try await Task.sleep(nanoseconds: 1_100_000_000)
            pds.setStatus((false, "suspended"), for: Self.aliceDID)

            // The request itself is never sent: preparing it refreshes, and the
            // refresh is what the server refuses.
            let error = await #expect(throws: AccountStatusError.self) {
                _ = try await getSession(client, pds: pds)
            }
            #expect(error?.status == AccountStatus(isActive: false, reason: .suspended))
            #expect(pds.requests(to: "refreshSession").map(\.status) == [401])
            #expect(pds.requests(to: "getSession").isEmpty)
            let stored = try await client.storage.getSession(for: Self.aliceDID)
            #expect(stored != nil)

            // The refusal did not spend the refresh token or trip the circuit
            // breaker: asked again, the caller is told the status again…
            for _ in 0 ..< 4 {
                await #expect(throws: AccountStatusError.self) {
                    _ = try await client.strategy.refreshTokenIfNeeded(forceRefresh: true)
                }
            }
            // …and once the account is reinstated the same session refreshes and works.
            pds.setStatus((true, nil), for: Self.aliceDID)
            pds.accessTokenLifetime = 7200
            #expect(try await client.strategy.refreshTokenIfNeeded(forceRefresh: true) == .refreshedSuccessfully)
            #expect(try await getSession(client, pds: pds).statusCode == 200)
        }
    }

    @Test("Logout ends the session at the PDS with the refresh JWT, then forgets it")
    func logoutDeletesSession() async throws {
        let pds = FakePasswordPDS()
        pds.add(Self.alice)
        try await withOAuthTestNetwork([pds]) {
            let client = await makeClient(namespace: "password.logout", pds: pds)
            _ = try await signIn(client)
            let refreshToken = try #require(try await client.storage.getSession(for: Self.aliceDID)?.refreshToken)

            try await client.strategy.logout()

            let request = try #require(pds.requests(to: "deleteSession").last)
            #expect(request.status == 200)
            #expect(request.headers["Authorization"] == "Bearer \(refreshToken)")
            #expect(pds.liveSessionCount == 0)
            #expect(try await client.storage.getSession(for: Self.aliceDID) == nil)
            #expect(await client.accountManager.getCurrentAccount() == nil)
        }
    }

    // MARK: - Status on authenticated requests

    @Test("A request refused for the account's status throws the status, without refreshing or signing out")
    func passwordSessionRequestRefusedForStatus() async throws {
        let pds = FakePasswordPDS()
        pds.add(Self.alice)
        try await withOAuthTestNetwork([pds]) {
            let client = await makeClient(namespace: "password.request.takedown", pds: pds)
            _ = try await signIn(client)
            pds.setStatus((false, "takendown"), for: Self.aliceDID)

            let error = await #expect(throws: AccountStatusError.self) {
                _ = try await getSession(client, pds: pds)
            }
            #expect(error?.status == AccountStatus(isActive: false, reason: .takendown))
            #expect(error?.message == "Account has been taken down")
            #expect(pds.requests(to: "refreshSession").isEmpty)
            #expect(try await client.storage.getSession(for: Self.aliceDID) != nil)
        }
    }

    @Test(
        "OAuth session: a request refused for the account's status throws the status and keeps the session",
        arguments: [("AccountTakedown", AccountStatus.Reason.takendown), ("AccountDeactivated", .deactivated), ("AccountSuspended", .suspended)]
    )
    func oauthSessionRequestRefusedForStatus(errorName: String, reason: AccountStatus.Reason) async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "status.oauth.\(errorName)", server: server)
            try await client.signIn(handle: "alice.test", did: "did:plc:statusalice", server: server)
            #expect(try await client.getSession().1.statusCode == 200)

            server.forcedErrors[.resource] = (401, errorName)
            let error = await #expect(throws: AccountStatusError.self) {
                _ = try await client.getSession()
            }
            #expect(error?.status == AccountStatus(isActive: false, reason: reason))
            // Not treated as an expired token: no refresh, and the session survives.
            #expect(server.requests(to: .token).filter { $0.form["grant_type"] == "refresh_token" }.isEmpty)
            #expect(try await client.storage.getSession(for: "did:plc:statusalice") != nil)
            #expect(await client.accountManager.getCurrentAccount() != nil)
        }
    }
}

/// The public authentication API on `ATProtoClient`, end to end. The snippets
/// in the `OAuthClient` documentation article mirror these tests.
@Suite("ATProtoClient authentication API", .serialized)
struct ATProtoClientAuthenticationTests {
    private static let aliceDID = "did:plc:clientalice"

    private func makeClient(
        namespace: String, server: FakeOAuthServer, scope: String = "atproto transition:generic"
    ) async throws -> ATProtoClient {
        let resolver = OAuthTestDIDResolver()
        resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
        return try await ATProtoClient(
            baseURL: server.pdsURL,
            oauthConfig: OAuthConfig(
                clientId: OAuthTestClient.clientID, redirectUri: OAuthTestClient.redirectURI, scope: scope
            ),
            namespace: namespace,
            authMode: .publicOAuth,
            didResolver: resolver
        )
    }

    @Test("Sign in with a handle, call the PDS, read the grant and the account status, sign out")
    func identifierFirstLifecycle() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = try await makeClient(namespace: "client.lifecycle", server: server)

            // 1. Start the flow and open the URL in a browser.
            let authorizationURL = try await client.startOAuthFlow(identifier: "alice.test")
            // 2. The user approves; the app receives the redirect.
            let redirect = try server.approve(authorizationURL, as: Self.aliceDID)
            try await client.handleOAuthCallback(url: redirect)

            #expect(await client.hasValidSession())
            #expect(try await client.getDid() == Self.aliceDID)
            #expect(await client.getCurrentAccount()?.authorizationServerIssuer == server.issuer)

            // 3. Authenticated requests are DPoP-signed and refreshed automatically.
            let (code, session) = try await client.com.atproto.server.getSession()
            #expect(code == 200)
            #expect(session?.did.description == Self.aliceDID)

            // 4. What was actually granted, as typed scopes.
            let granted = await client.grantedScopes()
            #expect(granted.includesAtproto)
            #expect(granted.covers(.transitionGeneric))
            #expect(granted.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create)))

            // 5. The account's hosting status.
            #expect(try await client.fetchAccountStatus() == .active)
            server.sessionStatus = (false, "deactivated")
            #expect(try await client.fetchAccountStatus() == AccountStatus(isActive: false, reason: .deactivated))
            server.sessionStatus = (true, nil)
            server.forcedErrors[.resource] = (401, "AccountTakedown")
            #expect(try await client.fetchAccountStatus() == AccountStatus(isActive: false, reason: .takendown))
            server.forcedErrors[.resource] = nil

            // 6. Logging out revokes the session at the authorization server.
            try await client.logout()
            #expect(server.isRevoked(sub: Self.aliceDID))
            #expect(!(await client.hasValidSession()))
        }
    }

    @Test("App-password client: fetchAccountStatus returns the status when the refresh before the request is refused")
    func fetchAccountStatusThroughRefusedRefresh() async throws {
        let pds = FakePasswordPDS()
        pds.add(FakePasswordPDS.Account(
            did: Self.aliceDID, handle: "alice.test", email: "alice@example.com", password: "app-password"
        ))
        pds.accessTokenLifetime = 1
        try await withOAuthTestNetwork([pds]) {
            let resolver = OAuthTestDIDResolver()
            resolver.register(did: Self.aliceDID, handle: "alice.test", pds: pds.url)
            let client = try await ATProtoClient(
                baseURL: pds.url,
                oauthConfig: OAuthConfig(
                    clientId: OAuthTestClient.clientID, redirectUri: OAuthTestClient.redirectURI, scope: "atproto"
                ),
                namespace: "client.password.status",
                authMode: .legacy,
                didResolver: resolver
            )
            try await client.loginWithPassword(identifier: "alice.test", password: "app-password")
            #expect(try await client.fetchAccountStatus() == .active)

            try await Task.sleep(nanoseconds: 1_100_000_000)
            pds.setStatus((false, "takendown"), for: Self.aliceDID)
            #expect(try await client.fetchAccountStatus() == AccountStatus(isActive: false, reason: .takendown))
            #expect(await client.lastKnownAccountStatus() == AccountStatus(isActive: false, reason: .takendown))
            // It was the refresh that was refused; the status request was never sent.
            #expect(pds.requests(to: "refreshSession").last?.status == 401)
            #expect(pds.requests(to: "getSession").filter { $0.status == 401 }.isEmpty)

            // An ordinary generated call reports the status too, not a generic failure.
            let error = await #expect(throws: AccountStatusError.self) {
                _ = try await client.com.atproto.server.getSession()
            }
            #expect(error?.status.reason == .takendown)
        }
    }

    @Test("Server-first sign-in from a provider URL")
    func serverFirst() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = try await makeClient(namespace: "client.serverfirst", server: server)
            let authorizationURL = try await client.startOAuthFlow(server: URL(string: server.issuer)!)
            #expect(server.requests(to: .par).last?.form["login_hint"] == nil)
            try await client.handleOAuthCallback(url: server.approve(authorizationURL, as: Self.aliceDID))
            #expect(try await client.getDid() == Self.aliceDID)
        }
    }

    @Test("Requesting more scopes re-authorizes the same account and replaces its session")
    func scopeUpgrade() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = try await makeClient(namespace: "client.upgrade", server: server, scope: "atproto")
            try await client.handleOAuthCallback(
                url: server.approve(try await client.startOAuthFlow(identifier: "alice.test"), as: Self.aliceDID)
            )
            #expect(!(await client.grantedScopes().allowsRepo(.init(collection: "app.bsky.feed.post", action: .create))))

            let wanted = try ATProtoScopeSet([.atproto, .repo(collections: ["app.bsky.feed.post"], actions: [.create])])
            let upgradeURL = try await client.requestScopes(wanted)
            // The flow is bound to the signed-in account.
            #expect(server.requests(to: .par).last?.form["login_hint"] == Self.aliceDID)
            #expect(server.requests(to: .par).last?.form["scope"] == wanted.scopeString)
            try await client.handleOAuthCallback(url: server.approve(upgradeURL, as: Self.aliceDID))

            let granted = await client.grantedScopes()
            #expect(granted.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create)))
            #expect(!granted.allowsRepo(.init(collection: "app.bsky.feed.post", action: .delete)))
            #expect(await client.listAccounts().count == 1)
        }
    }

    @Test("Removing an account through the client revokes its session")
    func removeAccountRevokes() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = try await makeClient(namespace: "client.remove", server: server)
            try await client.handleOAuthCallback(
                url: server.approve(try await client.startOAuthFlow(identifier: "alice.test"), as: Self.aliceDID)
            )
            try await client.removeAccount(did: Self.aliceDID)
            #expect(server.requests(to: .revoke).last?.status == 200)
            #expect(server.isRevoked(sub: Self.aliceDID))
            #expect(await client.listAccounts().isEmpty)
        }
    }

    @Test("A confidential client signs its own assertions")
    func confidentialClient() async throws {
        let key = try OAuthClientAssertionKey.generate(keyID: "key-1")
        let server = FakeOAuthServer()
        server.clientAuthentication = .jwks([key.publicJWK])
        try await withOAuthTestNetwork([server]) {
            let client = try await makeClient(namespace: "client.confidential", server: server)
            try await client.useClientAssertionSigner(key)
            try await client.handleOAuthCallback(
                url: server.approve(try await client.startOAuthFlow(identifier: "alice.test"), as: Self.aliceDID)
            )
            #expect(try await client.getDid() == Self.aliceDID)
            #expect(server.requests(to: .token).last?.form["client_assertion"] != nil)
        }
    }

    @Test("OAuth-only operations are refused on clients without an OAuth flow")
    func unsupportedModes() async throws {
        let unauthenticated = await ATProtoClient(baseURL: URL(string: "https://pds.oauth.test")!)
        await #expect(throws: OAuthConfigurationError.unsupportedByAuthMode) {
            _ = try await unauthenticated.startOAuthFlow(server: URL(string: "https://pds.oauth.test")!)
        }
        await #expect(throws: AuthError.noActiveAccount) {
            _ = try await unauthenticated.fetchAccountStatus()
        }
        #expect(await unauthenticated.grantedScopes().rawScopes.isEmpty)
        #expect(await unauthenticated.lastKnownAccountStatus() == nil)
    }
}
