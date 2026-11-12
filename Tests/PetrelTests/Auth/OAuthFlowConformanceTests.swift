#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

/// End-to-end authorization flows against `FakeOAuthServer`.
///
/// Every negative test here runs against a server whose token endpoint works:
/// a callback that should be refused would otherwise succeed. Each asserts the
/// specific error *and* what did or did not reach the server, so it cannot pass
/// because of an unrelated failure.
@Suite("OAuth authorization flow conformance", .serialized)
struct OAuthFlowConformanceTests {
    private static let aliceDID = "did:plc:flowalice"
    private static let bobDID = "did:plc:flowbob"

    /// Starts an identifier-first flow for Alice and has the user approve it.
    private func startAndApprove(
        _ client: OAuthTestClient,
        _ server: FakeOAuthServer,
        approveAs did: String = aliceDID
    ) async throws -> (redirect: URL, state: String, authorizationURL: URL) {
        client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
        let (url, state) = try await client.strategy.startOAuthFlowWithState(identifier: "alice.test")
        return (try server.approve(url, as: did), state, url)
    }

    private func replacing(_ name: String, with value: String?, in url: URL) -> URL {
        // Custom-scheme redirect: rebuild the query by hand.
        let text = url.absoluteString
        let parts = text.split(separator: "?", maxSplits: 1).map(String.init)
        var items = parts[1].split(separator: "&").map(String.init).filter { !$0.hasPrefix("\(name)=") }
        if let value {
            items.append("\(name)=\(value)")
        }
        return URL(string: "\(parts[0])?\(items.joined(separator: "&"))")!
    }

    // MARK: - Happy paths

    @Test("Identifier-first login: PAR, PKCE, redirect, code exchange, stored session")
    func identifierFirstLogin() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.identifier", server: server)
            let (redirect, state, authorizationURL) = try await startAndApprove(client, server)

            // Pushed authorization request: every required field, PKCE S256, the
            // user's own identifier as login_hint, and no client secret.
            let par = try #require(server.requests(to: .par).last)
            #expect(par.status == 201)
            #expect(par.form["client_id"] == OAuthTestClient.clientID)
            #expect(par.form["response_type"] == "code")
            #expect(par.form["code_challenge_method"] == "S256")
            #expect(par.form["redirect_uri"] == OAuthTestClient.redirectURI)
            #expect(par.form["scope"] == "atproto transition:generic")
            #expect(par.form["state"] == state)
            #expect(par.form["login_hint"] == "alice.test")
            #expect(par.form["client_secret"] == nil)
            #expect(par.form["client_assertion"] == nil)
            let challenge = try #require(par.form["code_challenge"])
            #expect(TestJOSE.base64URLDecode(challenge)?.count == 32)

            // The redirect carries only the pushed request's handle.
            #expect(authorizationURL.absoluteString.hasPrefix(server.authorizationEndpoint + "?"))
            #expect(Set(server.lastAuthorizationQueryNames) == ["client_id", "request_uri"])

            let result = try await client.strategy.handleOAuthCallback(url: redirect)
            #expect(result.did == Self.aliceDID)
            #expect(result.handle == "alice.test")
            #expect(result.pdsURL == server.pdsURL)

            // Code exchange: the server verified PKCE and the DPoP key binding
            // (it answers invalid_grant otherwise); only spec fields were sent.
            let exchange = try #require(server.requests(to: .token).last)
            #expect(exchange.status == 200)
            #expect(Set(exchange.form.keys) == ["grant_type", "code", "redirect_uri", "code_verifier", "client_id"])
            let verifier = try #require(exchange.form["code_verifier"])
            #expect(TestJOSE.sha256Base64URL(verifier) == challenge)
            // The same DPoP key from PAR onward.
            #expect(exchange.proof?.thumbprint == par.proof?.thumbprint)

            // The session is stored with exactly what the server granted, and the
            // account remembers the validated authorization server.
            let session = try #require(try await client.storage.getSession(for: Self.aliceDID))
            #expect(session.tokenType == .dpop)
            #expect(session.grantedScopes == ["atproto", "transition:generic"])
            #expect(session.expiresIn == 3600)
            let account = try #require(await client.accountManager.getCurrentAccount())
            #expect(account.did == Self.aliceDID)
            #expect(account.authorizationServerIssuer == server.issuer)
            // The flow's DPoP key became the account's key, and the flow state is gone.
            #expect(try await client.storage.getDPoPKeyRepresentation(for: Self.aliceDID) != nil)
            #expect(try await client.storage.getOAuthState(for: state) == nil)

            // And the session works against the resource server.
            let (_, response) = try await client.getSession()
            #expect(response.statusCode == 200)
        }
    }

    @Test("Login by DID uses the DID as login_hint and binds it to the flow")
    func loginByDID() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.did", server: server)
            client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
            let (url, _) = try await client.strategy.startOAuthFlowWithState(identifier: Self.aliceDID)
            #expect(server.requests(to: .par).last?.form["login_hint"] == Self.aliceDID)
            let result = try await client.strategy.handleOAuthCallback(url: server.approve(url, as: Self.aliceDID))
            #expect(result.did == Self.aliceDID)
        }
    }

    @Test("Each flow uses a fresh state, PKCE verifier and DPoP key")
    func flowsDoNotShareSecrets() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.fresh", server: server)
            client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
            _ = try await client.strategy.startOAuthFlowWithState(identifier: "alice.test")
            _ = try await client.strategy.startOAuthFlowWithState(identifier: "alice.test")
            let pars = server.requests(to: .par).filter { $0.status == 201 }
            #expect(pars.count == 2)
            #expect(pars[0].form["state"] != pars[1].form["state"])
            #expect(pars[0].form["code_challenge"] != pars[1].form["code_challenge"])
            #expect(pars[0].proof?.thumbprint != pars[1].proof?.thumbprint)
        }
    }

    @Test(
        "Server-first login from a PDS host or an entryway host, with no login_hint",
        arguments: ["https://pds.oauth.test", "https://auth.oauth.test"]
    )
    func serverFirstLogin(serverInput: String) async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.server.\(serverInput.hashValue)", server: server)
            client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)

            let (url, _) = try await client.strategy.startOAuthFlow(
                target: .server(URL(string: serverInput)!), scope: nil
            )
            let par = try #require(server.requests(to: .par).last)
            #expect(par.form["login_hint"] == nil)

            let resourceFetchesBefore = server.requests(to: .protectedResourceMetadata).count
            let result = try await client.strategy.handleOAuthCallback(url: server.approve(url, as: Self.aliceDID))
            #expect(result.did == Self.aliceDID)
            // The account was bound to the issuer through its own PDS after the exchange.
            #expect(server.requests(to: .protectedResourceMetadata).count == resourceFetchesBefore + 1)
        }
    }

    @Test("Starting without an identifier is a server-first flow")
    func signUpFlowIsServerFirst() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.signup", server: server)
            let url = try await client.strategy.startOAuthFlowForSignUp(
                pdsURL: server.pdsURL, bskyAppViewDID: nil, bskyChatDID: nil
            )
            #expect(url.absoluteString.hasPrefix(server.authorizationEndpoint))
            #expect(server.requests(to: .par).last?.form["login_hint"] == nil)
        }
    }

    @Test("A per-flow scope overrides the configured one and must include atproto")
    func perFlowScope() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.scope", server: server, scope: "atproto")
            client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)

            let upgraded = try ATProtoScopeSet([.atproto, .repo(collections: ["app.bsky.feed.post"])])
            let (url, _) = try await client.strategy.startOAuthFlow(
                target: .identifier("alice.test"), scope: upgraded.scopeString
            )
            #expect(server.requests(to: .par).last?.form["scope"] == "atproto repo:app.bsky.feed.post")
            _ = try await client.strategy.handleOAuthCallback(url: server.approve(url, as: Self.aliceDID))
            let granted = try #require(try await client.storage.getSession(for: Self.aliceDID)).grantedScopes
            #expect(ATProtoScopeSet(rawScopes: granted)
                .allowsRepo(.init(collection: "app.bsky.feed.post", action: .create)))

            await #expect(throws: OAuthConfigurationError.scopeMissingAtproto("transition:generic")) {
                _ = try await client.strategy.startOAuthFlow(
                    target: .identifier("alice.test"), scope: "transition:generic"
                )
            }
        }
    }

    // MARK: - Callback verification (mix-up defences)

    @Test("A callback from the wrong issuer is refused before the code is sent anywhere")
    func wrongIssuerInCallback() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.iss.wrong", server: server)
            let (redirect, _, _) = try await startAndApprove(client, server)
            let forged = replacing("iss", with: "https%3A%2F%2Fevil.oauth.test", in: redirect)
            await #expect(throws: AuthError.invalidCallbackURL) {
                _ = try await client.strategy.handleOAuthCallback(url: forged)
            }
            #expect(server.requests(to: .token).isEmpty)
            #expect(try await client.storage.getSession(for: Self.aliceDID) == nil)
        }
    }

    @Test("A callback without iss is refused, whatever requireIssInCallback says")
    func missingIssuerInCallback() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let storage = KeychainStorage(namespace: "flow.iss.missing")
            let accountManager = await AccountManager(storage: storage)
            let resolver = OAuthTestDIDResolver()
            resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
            // Even a configuration that asks for the check to be skipped gets it.
            let strategy = PublicOAuthStrategy(
                storage: storage,
                accountManager: accountManager,
                networkService: NetworkService(baseURL: server.pdsURL),
                oauthConfig: OAuthConfig(
                    clientId: OAuthTestClient.clientID,
                    redirectUri: OAuthTestClient.redirectURI,
                    scope: "atproto",
                    requireIssInCallback: false
                ),
                didResolver: resolver
            )
            let (url, _) = try await strategy.startOAuthFlowWithState(identifier: "alice.test")
            let redirect = replacing("iss", with: nil, in: try server.approve(url, as: Self.aliceDID))
            await #expect(throws: AuthError.invalidCallbackURL) {
                _ = try await strategy.handleOAuthCallback(url: redirect)
            }
            #expect(server.requests(to: .token).isEmpty)
        }
    }

    @Test(
        "A callback delivered to a different redirect URI is refused",
        arguments: [
            "other.oauth.app:/callback", // different scheme
            "test.oauth.app:/elsewhere", // different path
            "https://app.oauth.test/callback", // web URL instead of the registered custom scheme
        ]
    )
    func redirectURIMismatch(redirectBase: String) async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            // A fresh flow per variant, so the refusal is about the redirect, not a spent state.
            let client = await OAuthTestClient.make(namespace: "flow.redirect.\(redirectBase.hashValue)", server: server)
            let (redirect, _, _) = try await startAndApprove(client, server)
            let query = redirect.absoluteString.split(separator: "?", maxSplits: 1)[1]
            let misdelivered = URL(string: "\(redirectBase)?\(query)")!
            await #expect(throws: AuthError.invalidCallbackURL) {
                _ = try await client.strategy.handleOAuthCallback(url: misdelivered)
            }
            #expect(server.requests(to: .token).isEmpty)
        }
    }

    @Test("state is single-use: a replayed callback is refused and reaches no endpoint")
    func stateIsSingleUse() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.state.replay", server: server)
            let (redirect, _, _) = try await startAndApprove(client, server)
            _ = try await client.strategy.handleOAuthCallback(url: redirect)
            let tokenRequests = server.requests(to: .token).count

            await #expect(throws: AuthError.invalidCallbackURL) {
                _ = try await client.strategy.handleOAuthCallback(url: redirect)
            }
            #expect(server.requests(to: .token).count == tokenRequests)
        }
    }

    @Test("An unknown state is refused")
    func unknownState() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.state.unknown", server: server)
            let (redirect, _, _) = try await startAndApprove(client, server)
            await #expect(throws: AuthError.invalidCallbackURL) {
                _ = try await client.strategy.handleOAuthCallback(
                    url: replacing("state", with: UUID().uuidString, in: redirect)
                )
            }
            #expect(server.requests(to: .token).isEmpty)
        }
    }

    @Test("A flow whose stored DPoP key no longer matches its recorded thumbprint is refused")
    func dpopKeyThumbprintMismatch() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.jkt", server: server)
            let (redirect, state, _) = try await startAndApprove(client, server)

            // Swap the persisted flow key for another one, as a tampered store would.
            var tampered = try #require(try await client.storage.getOAuthState(for: state))
            tampered.ephemeralDPoPKey = P256.Signing.PrivateKey().rawRepresentation
            try await client.storage.saveOAuthState(tampered)

            await #expect(throws: AuthError.dpopKeyError) {
                _ = try await client.strategy.handleOAuthCallback(url: redirect)
            }
            #expect(server.requests(to: .token).isEmpty)
        }
    }

    @Test("A cancelled flow cannot be completed")
    func cancelledFlow() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.cancelled", server: server)
            let (redirect, state, _) = try await startAndApprove(client, server)
            #expect(try await client.storage.getOAuthState(for: state) != nil)
            await client.strategy.cancelOAuthFlow()
            // The persisted flow state — PKCE verifier and DPoP key — is purged.
            #expect(try await client.storage.getOAuthState(for: state) == nil)
            await #expect(throws: AuthError.invalidCallbackURL) {
                _ = try await client.strategy.handleOAuthCallback(url: redirect)
            }
            #expect(server.requests(to: .token).isEmpty)
        }
    }

    @Test("The user denying the request surfaces as cancellation and spends the state")
    func accessDenied() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.denied", server: server)
            let (redirect, state, _) = try await startAndApprove(client, server)
            let denied = URL(string: "\(OAuthTestClient.redirectURI)?error=access_denied&state=\(state)")!
            await #expect(throws: AuthError.cancelled) {
                _ = try await client.strategy.handleOAuthCallback(url: denied)
            }
            #expect(try await client.storage.getOAuthState(for: state) == nil)
            // The genuine callback can no longer be used either.
            await #expect(throws: AuthError.invalidCallbackURL) {
                _ = try await client.strategy.handleOAuthCallback(url: redirect)
            }
            #expect(server.requests(to: .token).isEmpty)
        }
    }

    // MARK: - Token response verification

    @Test("sub must equal the DID the flow was started for; the issued session is revoked")
    func subjectMustMatchExpectedDID() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.sub", server: server)
            client.resolver.register(did: Self.bobDID, handle: "bob.test", pds: server.pdsURL)
            // Alice started the flow; the server signs in Bob.
            let (redirect, _, _) = try await startAndApprove(client, server, approveAs: Self.bobDID)

            await #expect(throws: AuthError.invalidResponse) {
                _ = try await client.strategy.handleOAuthCallback(url: redirect)
            }
            // The exchange itself succeeded — the refusal is the client's.
            #expect(server.requests(to: .token).last?.status == 200)
            // Nothing was stored for either account…
            #expect(try await client.storage.getSession(for: Self.bobDID) == nil)
            #expect(try await client.storage.getSession(for: Self.aliceDID) == nil)
            #expect(await client.accountManager.getCurrentAccount() == nil)
            // …and the session the server had issued was revoked, not abandoned.
            #expect(server.requests(to: .revoke).last?.status == 200)
            #expect(server.isRevoked(sub: Self.bobDID))
        }
    }

    @Test(
        "A token response that is not a usable atproto session is refused and revoked",
        arguments: ["no-atproto-scope", "bearer", "no-sub", "non-did-sub"]
    )
    func unusableTokenResponse(defect: String) async throws {
        let server = FakeOAuthServer()
        server.tokenResponseTransform = { response, _ in
            var response = response
            switch defect {
            case "no-atproto-scope": response["scope"] = "transition:generic"
            case "bearer": response["token_type"] = "Bearer"
            case "no-sub": response.removeValue(forKey: "sub")
            default: response["sub"] = "alice.test"
            }
            return response
        }
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.token.\(defect)", server: server)
            let (redirect, _, _) = try await startAndApprove(client, server)
            await #expect(throws: AuthError.invalidResponse) {
                _ = try await client.strategy.handleOAuthCallback(url: redirect)
            }
            #expect(server.requests(to: .token).last?.status == 200)
            #expect(try await client.storage.getSession(for: Self.aliceDID) == nil)
            #expect(server.isRevoked(sub: Self.aliceDID))
        }
    }

    @Test("Partial authorization is kept as granted, not as requested")
    func partialGrantIsRecorded() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.partial", server: server)
            client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
            let (url, _) = try await client.strategy.startOAuthFlowWithState(identifier: "alice.test")
            let redirect = try server.approve(url, as: Self.aliceDID, grantedScope: "atproto")
            _ = try await client.strategy.handleOAuthCallback(url: redirect)
            #expect(try await client.storage.getSession(for: Self.aliceDID)?.grantedScopes == ["atproto"])
        }
    }

    @Test("A token response without a DPoP nonce is refused and revoked")
    func tokenResponseMustCarryNonce() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.nonce.missing", server: server)
            let (redirect, _, _) = try await startAndApprove(client, server)
            server.omitsNonceOn = [.token]
            await #expect(throws: AuthError.invalidResponse) {
                _ = try await client.strategy.handleOAuthCallback(url: redirect)
            }
            #expect(server.requests(to: .token).last?.status == 200)
            #expect(try await client.storage.getSession(for: Self.aliceDID) == nil)
            #expect(server.isRevoked(sub: Self.aliceDID))
        }
    }

    @Test("A pushed authorization response without a DPoP nonce is refused")
    func parResponseMustCarryNonce() async throws {
        // A server that neither demands nor issues nonces: the request is
        // accepted (201) and it is the client that must refuse to continue.
        let server = FakeOAuthServer()
        server.enforcesNonce = false
        server.omitsNonceOn = [.par]
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.nonce.par", server: server)
            client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
            await #expect(throws: AuthError.invalidResponse) {
                _ = try await client.strategy.startOAuthFlowWithState(identifier: "alice.test")
            }
            #expect(server.requests(to: .par).map(\.status) == [201])
        }
    }

    // MARK: - Server-first account binding

    @Test("Server-first: an account whose own PDS names a different authorization server is refused and revoked")
    func serverFirstBindsSubjectToIssuer() async throws {
        // The user names `entry`. Its token endpoint claims Bob, whose DID
        // document points at a PDS protected by a different authorization server.
        let entry = FakeOAuthServer(pdsOrigin: "https://entry.oauth.test", issuer: "https://entry.oauth.test")
        let bobHost = FakeOAuthServer(pdsOrigin: "https://pds.bob.test", issuer: "https://auth.bob.test")

        try await withOAuthTestNetwork([entry, bobHost]) {
            let client = await OAuthTestClient.make(namespace: "flow.server.binding", server: entry)
            client.resolver.register(did: Self.bobDID, handle: "bob.test", pds: bobHost.pdsURL)

            let (url, _) = try await client.strategy.startOAuthFlow(target: .server(entry.pdsURL), scope: nil)
            let redirect = try entry.approve(url, as: Self.bobDID)

            await #expect(throws: AuthError.invalidOAuthConfiguration) {
                _ = try await client.strategy.handleOAuthCallback(url: redirect)
            }
            // The exchange succeeded and Bob's real PDS was consulted…
            #expect(entry.requests(to: .token).last?.status == 200)
            #expect(bobHost.requests(to: .protectedResourceMetadata).count == 1)
            // …but no account was created, and the stray session was revoked.
            #expect(try await client.storage.getSession(for: Self.bobDID) == nil)
            #expect(await client.accountManager.listAccounts().isEmpty)
            #expect(entry.isRevoked(sub: Self.bobDID))
        }
    }

    @Test("Identifier-first: an account that moved to another PDS mid-flow is refused")
    func identifierFirstRequiresSamePDS() async throws {
        let server = FakeOAuthServer()
        let other = FakeOAuthServer(pdsOrigin: "https://pds.moved.test", issuer: "https://auth.moved.test")
        try await withOAuthTestNetwork([server, other]) {
            let client = await OAuthTestClient.make(namespace: "flow.pds.moved", server: server)
            let (redirect, _, _) = try await startAndApprove(client, server)
            client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: other.pdsURL)
            await #expect(throws: AuthError.invalidOAuthConfiguration) {
                _ = try await client.strategy.handleOAuthCallback(url: redirect)
            }
            #expect(server.isRevoked(sub: Self.aliceDID))
        }
    }

    @Test("An error callback other than access_denied is reported with the server's error")
    func authorizationErrorCallback() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.error", server: server)
            let (_, state, _) = try await startAndApprove(client, server)
            let failed = URL(string: "\(OAuthTestClient.redirectURI)?error=invalid_scope&error_description=nope&state=\(state)")!
            await #expect(throws: AuthError.serverError(0, "invalid_scope: nope")) {
                _ = try await client.strategy.handleOAuthCallback(url: failed)
            }
            #expect(try await client.storage.getOAuthState(for: state) == nil)
        }
    }

    @Test("A denied flow stays denied even when its stored state could not be deleted")
    func denialSurvivesStorageFailure() async throws {
        let server = FakeOAuthServer()
        let backend = InMemorySecureStorage()
        try await withOAuthTestNetwork([server], storage: backend) {
            let client = await OAuthTestClient.make(namespace: "flow.denied.undeletable", server: server)
            let (redirect, state, _) = try await startAndApprove(client, server)

            // The keychain refuses to delete the flow state.
            backend.failDeleteMatching = { $0.contains("oauthState") }
            let denied = URL(string: "\(OAuthTestClient.redirectURI)?error=access_denied&state=\(state)")!
            await #expect(throws: AuthError.cancelled) {
                _ = try await client.strategy.handleOAuthCallback(url: denied)
            }
            backend.failDeleteMatching = nil

            // The state is still on disk, but the flow was denied and stays so.
            await #expect(throws: AuthError.invalidCallbackURL) {
                _ = try await client.strategy.handleOAuthCallback(url: redirect)
            }
            #expect(server.requests(to: .token).isEmpty)
        }
    }

    @Test(
        "A stored flow state missing part of its trust tuple fails closed without contacting the server",
        arguments: ["issuer", "jkt", "redirect", "pds", "key", "metadata", "did"]
    )
    func incompleteFlowStateFailsClosed(missing: String) async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.state.incomplete.\(missing)", server: server)
            let (redirect, state, _) = try await startAndApprove(client, server)
            let stored = try #require(try await client.storage.getOAuthState(for: state))

            // Rewrite the stored state as a version that lacked one member would have.
            var incomplete = OAuthState(
                stateToken: stored.stateToken,
                codeVerifier: stored.codeVerifier,
                createdAt: stored.createdAt,
                initialIdentifier: stored.initialIdentifier,
                targetPDSURL: stored.targetPDSURL,
                ephemeralDPoPKey: missing == "key" ? nil : stored.ephemeralDPoPKey,
                parResponseNonce: stored.parResponseNonce,
                expectedIssuer: missing == "issuer" ? nil : stored.expectedIssuer,
                expectedPDSOrigin: missing == "pds" ? nil : stored.expectedPDSOrigin,
                expectedDID: missing == "did" ? nil : stored.expectedDID,
                redirectURI: missing == "redirect" ? nil : stored.redirectURI,
                dpopJKT: missing == "jkt" ? nil : stored.dpopJKT,
                tokenEndpoint: stored.tokenEndpoint,
                authorizationEndpoint: stored.authorizationEndpoint
            )
            incomplete.authorizationServerMetadata = missing == "metadata" ? nil : stored.authorizationServerMetadata
            try await client.storage.saveOAuthState(incomplete)
            let requestsBefore = server.requests.count

            await #expect(throws: AuthError.invalidCallbackURL) {
                _ = try await client.strategy.handleOAuthCallback(url: redirect)
            }
            // Nothing was rediscovered and the code was not sent anywhere.
            #expect(server.requests.count == requestsBefore)
        }
    }

    @Test("A stored flow state whose server metadata names another issuer fails closed")
    func tamperedFlowMetadataFailsClosed() async throws {
        let server = FakeOAuthServer()
        let other = FakeOAuthServer(pdsOrigin: "https://pds.other.test", issuer: "https://auth.other.test")
        try await withOAuthTestNetwork([server, other]) {
            let client = await OAuthTestClient.make(namespace: "flow.state.tampered", server: server)
            let (redirect, state, _) = try await startAndApprove(client, server)

            // Point the stored token endpoint at another server while keeping the bound issuer.
            var tampered = try #require(try await client.storage.getOAuthState(for: state))
            tampered.authorizationServerMetadata = try await client.core.fetchAuthorizationServerMetadata(issuer: other.issuer)
            try await client.storage.saveOAuthState(tampered)

            await #expect(throws: AuthError.invalidCallbackURL) {
                _ = try await client.strategy.handleOAuthCallback(url: redirect)
            }
            #expect(server.requests(to: .token).isEmpty)
            #expect(other.requests(to: .token).isEmpty)
        }
    }

    @Test("Identifier-first: a PDS that stops naming the flow's authorization server is refused")
    func identifierFirstBindingIsRechecked() async throws {
        let server = FakeOAuthServer()
        let other = FakeOAuthServer(pdsOrigin: "https://pds.other.test", issuer: "https://auth.other.test")
        try await withOAuthTestNetwork([server, other]) {
            let client = await OAuthTestClient.make(namespace: "flow.binding.recheck", server: server)
            let (redirect, _, _) = try await startAndApprove(client, server)

            // Between the redirect and the callback the PDS switches authorization server.
            server.protectedResourceMetadata = [
                "resource": server.pdsOrigin,
                "authorization_servers": [other.issuer],
            ]
            other.authorizationServerMetadataOverrides["protected_resources"] = [server.pdsOrigin]

            await #expect(throws: AuthError.invalidOAuthConfiguration) {
                _ = try await client.strategy.handleOAuthCallback(url: redirect)
            }
            #expect(try await client.storage.getSession(for: Self.aliceDID) == nil)
            #expect(server.isRevoked(sub: Self.aliceDID))
        }
    }

    @Test("Identifier-first: the account's PDS must have the same origin, port included, as at flow start")
    func identifierFirstRequiresSamePort() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.pds.port", server: server)
            let (redirect, _, _) = try await startAndApprove(client, server)
            client.resolver.register(
                did: Self.aliceDID, handle: "alice.test", pds: URL(string: "https://pds.oauth.test:8443")!
            )
            await #expect(throws: AuthError.invalidOAuthConfiguration) {
                _ = try await client.strategy.handleOAuthCallback(url: redirect)
            }
            #expect(server.isRevoked(sub: Self.aliceDID))
        }
    }

    @Test("Password login is not available on an OAuth strategy")
    func passwordLoginUnsupported() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "flow.password", server: server)
            await #expect(throws: AuthError.invalidOAuthConfiguration) {
                _ = try await client.strategy.loginWithPassword(
                    identifier: "alice.test", password: "pw", bskyAppViewDID: nil, bskyChatDID: nil
                )
            }
        }
    }
}
