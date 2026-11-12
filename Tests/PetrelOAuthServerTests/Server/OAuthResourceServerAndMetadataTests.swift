import Foundation
@testable import PetrelOAuthServer
import Testing

@Suite("Authorization server: metadata and CORS")
struct OAuthMetadataTests {
    private typealias Path = OAuthAuthorizationServer.Path

    private func object(_ response: OAuthHTTPResponse) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: response.body) as? [String: Any])
    }

    @Test("authorization server metadata carries every field the profile requires")
    func authorizationServerMetadata() async throws {
        let harness = try TestServer()
        let response = await harness.get(Path.authorizationServerMetadata)
        #expect(response.status == 200)
        #expect(response.headers["Content-Type"] == "application/json")
        let metadata = try object(response)
        #expect(metadata["issuer"] as? String == TestServer.issuer)
        #expect(metadata["authorization_endpoint"] as? String == TestServer.issuer + "/oauth/authorize")
        #expect(metadata["token_endpoint"] as? String == TestServer.issuer + "/oauth/token")
        #expect(metadata["pushed_authorization_request_endpoint"] as? String == TestServer.issuer + "/oauth/par")
        #expect(metadata["revocation_endpoint"] as? String == TestServer.issuer + "/oauth/revoke")
        #expect(metadata["response_types_supported"] as? [String] == ["code"])
        #expect(metadata["grant_types_supported"] as? [String] == ["authorization_code", "refresh_token"])
        #expect(metadata["code_challenge_methods_supported"] as? [String] == ["S256"])
        let authMethods = try #require(metadata["token_endpoint_auth_methods_supported"] as? [String])
        #expect(Set(authMethods) == ["none", "private_key_jwt"])
        let authAlgorithms = try #require(metadata["token_endpoint_auth_signing_alg_values_supported"] as? [String])
        #expect(authAlgorithms.contains("ES256") && !authAlgorithms.contains("none"))
        #expect((metadata["dpop_signing_alg_values_supported"] as? [String])?.contains("ES256") == true)
        let scopes = try #require(metadata["scopes_supported"] as? [String])
        #expect(scopes.contains("atproto") && scopes.contains("transition:generic"))
        #expect(metadata["authorization_response_iss_parameter_supported"] as? Bool == true)
        #expect(metadata["require_pushed_authorization_requests"] as? Bool == true)
        #expect(metadata["client_id_metadata_document_supported"] as? Bool == true)
        #expect(metadata["jwks_uri"] == nil, "no keys are published for opaque access tokens")
    }

    @Test("protected resource metadata names exactly one authorization server")
    func protectedResourceMetadata() async throws {
        let harness = try TestServer()
        let metadata = try await object(harness.get(Path.protectedResourceMetadata))
        #expect(metadata["resource"] as? String == TestServer.issuer)
        #expect(metadata["authorization_servers"] as? [String] == [TestServer.issuer])
        #expect((metadata["scopes_supported"] as? [String])?.contains("atproto") == true)
    }

    @Test("issuer rules: https origin, no path, no default port, no query")
    func issuerValidation() throws {
        for bad in [
            "http://auth.example.test", "https://auth.example.test/path", "https://auth.example.test:443",
            // A trailing slash would be published as is but sent as `iss`
            // without it, and clients compare the two exactly.
            "https://auth.example.test/", "http://127.0.0.1:8080/",
            "https://auth.example.test?x=1", "https://user@auth.example.test", "ftp://auth.example.test",
        ] {
            #expect(throws: OAuthServerError.self, "\(bad)") {
                _ = try OAuthAuthorizationServerConfiguration(
                    issuer: #require(URL(string: bad)), serverSecret: Data(repeating: 1, count: 32)
                )
            }
        }
        for bad in ["https://auth.example.test/", "https://auth.example.test"] {
            let url = try #require(URL(string: bad))
            if bad.hasSuffix("/") {
                #expect(throws: OAuthServerError.self) { _ = try OAuthAuthorizationServerMetadata(issuer: url) }
            } else {
                // What is published is what is sent as `iss`, byte for byte.
                let server = try OAuthAuthorizationServer(
                    configuration: OAuthAuthorizationServerConfiguration(issuer: url, serverSecret: Data(repeating: 1, count: 32)),
                    store: InMemoryOAuthStore(), accounts: TestAccounts(), clients: MutableClientResolver()
                )
                #expect(try OAuthAuthorizationServerMetadata(issuer: url).issuer.absoluteString == server.issuer)
            }
        }
        // A loopback development issuer may use http.
        _ = try OAuthAuthorizationServerConfiguration(
            issuer: #require(URL(string: "http://127.0.0.1:8080")), serverSecret: Data(repeating: 1, count: 32)
        )
    }

    @Test("configuration refuses lifetimes outside the profile and a short secret")
    func configurationLimits() throws {
        let issuer = try #require(URL(string: TestServer.issuer))
        let secret = Data(repeating: 1, count: 32)
        #expect(throws: OAuthServerError.self) {
            _ = try OAuthAuthorizationServerConfiguration(issuer: issuer, serverSecret: Data(repeating: 1, count: 16))
        }
        #expect(throws: OAuthServerError.self) {
            _ = try OAuthAuthorizationServerConfiguration(issuer: issuer, serverSecret: secret, accessTokenLifetime: 30 * 60)
        }
        #expect(throws: OAuthServerError.self) {
            _ = try OAuthAuthorizationServerConfiguration(
                issuer: issuer, serverSecret: secret, publicClientSessionLifetime: 15 * 24 * 60 * 60
            )
        }
        #expect(throws: OAuthServerError.self) {
            _ = try OAuthAuthorizationServerConfiguration(
                issuer: issuer, serverSecret: secret, confidentialClientRefreshLifetime: 181 * 24 * 60 * 60
            )
        }
        #expect(throws: OAuthServerError.self) {
            _ = try OAuthAuthorizationServerConfiguration(issuer: issuer, serverSecret: secret, scopesSupported: ["transition:generic"])
        }
    }

    @Test("metadata, PAR, token and revocation answer CORS preflights and expose DPoP-Nonce")
    func cors() async throws {
        let harness = try TestServer()
        for path in [Path.authorizationServerMetadata, Path.protectedResourceMetadata, Path.pushedAuthorizationRequest, Path.token, Path.revoke] {
            let preflight = await harness.server.handle(OAuthHTTPRequest(method: "OPTIONS", path: path))
            #expect(preflight.status == 204, "\(path)")
            #expect(preflight.headers["Access-Control-Allow-Origin"] == "*")
            #expect(preflight.headers["Access-Control-Allow-Headers"]?.contains("DPoP") == true)
            #expect(preflight.headers["Access-Control-Allow-Methods"]?.contains("POST") == true)
        }
        let error = await harness.post(Path.token, [("grant_type", "authorization_code")])
        #expect(error.headers["Access-Control-Allow-Origin"] == "*")
        let exposed = try #require(error.headers["Access-Control-Expose-Headers"])
        #expect(exposed.contains("DPoP-Nonce") && exposed.contains("WWW-Authenticate"))
        // The browser-facing authorization endpoint is not a CORS resource.
        let page = await harness.server.handle(OAuthHTTPRequest(method: "OPTIONS", path: Path.authorize))
        #expect(page.status == 405)
    }

    @Test("unknown paths are 404 and wrong methods are 405 with Allow")
    func routing() async throws {
        let harness = try TestServer()
        #expect(await harness.get("/oauth/unknown").status == 404)
        let wrong = await harness.get(Path.token)
        #expect(wrong.status == 405)
        #expect(wrong.headers["Allow"]?.contains("POST") == true)
        #expect(Set(OAuthAuthorizationServer.routes.map(\.path)).count == 11)
    }
}

@Suite("Resource server verifier")
struct OAuthResourceServerVerifierTests {
    private func setUp(
        _ format: OAuthAccessTokenFormat = .opaque,
        scope: String = "atproto repo:app.bsky.feed.post?action=create"
    ) async throws -> (TestServer, TestClient, OAuthTokenResponse, OAuthResourceServerVerifier) {
        let harness = try TestServer(accessTokenFormat: format)
        let client = try TestClient(harness)
        let tokens = try await client.signIn(scope: scope)
        return (harness, client, tokens, OAuthResourceServerVerifier(authorizationServer: harness.server))
    }

    private let url = TestServer.issuer + "/xrpc/com.atproto.repo.createRecord"

    private func headers(_ client: TestClient, token: String, verifier: OAuthResourceServerVerifier,
                         scheme: String = "DPoP", ath: String? = nil, method: String = "POST",
                         htu: String? = nil, nonce: String?? = nil) throws -> OAuthHTTPHeaders
    {
        let proof = try makeDPoPProof(
            key: client.dpopKey, method: method, url: htu ?? url,
            nonce: nonce ?? verifier.currentNonce(), accessToken: ath ?? token,
            issuedAt: client.harness.clock.now()
        )
        return .init([("Authorization", "\(scheme) \(token)"), ("DPoP", proof)])
    }

    @Test("a valid token and proof yield the subject, client and scope permissions")
    func success() async throws {
        let (_, client, tokens, verifier) = try await setUp()
        let grant = try await verifier.authenticate(
            method: "POST", url: #require(URL(string: url)),
            headers: headers(client, token: tokens.accessToken, verifier: verifier)
        )
        #expect(grant.subject == TestAccounts.alice.did)
        #expect(grant.clientID == TestServer.webClientID)
        #expect(grant.sessionID != nil)
        try grant.requireRepo(collection: "app.bsky.feed.post", action: .create)
        #expect(throws: OAuthResourceAuthorizationFailure.insufficientScope(needed: "repo:app.bsky.feed.post?action=delete")) {
            try grant.requireRepo(collection: "app.bsky.feed.post", action: .delete)
        }
        #expect(throws: OAuthResourceAuthorizationFailure.self) {
            try grant.requireRPC(lxm: "app.bsky.feed.getTimeline", aud: "did:web:api.bsky.app#bsky_appview")
        }
        #expect(throws: OAuthResourceAuthorizationFailure.self) { try grant.requireBlob(mime: "image/png") }
    }

    @Test("failures map to the right challenge", arguments: [
        "no-authorization", "bearer-scheme", "no-proof", "wrong-ath", "wrong-method", "wrong-url",
        "no-nonce", "unknown-token", "other-key",
    ])
    func failures(scenario: String) async throws {
        let (harness, client, tokens, verifier) = try await setUp()
        let target = try #require(URL(string: url))
        var requestHeaders = try headers(client, token: tokens.accessToken, verifier: verifier)
        var expected = "invalid_token"
        switch scenario {
        case "no-authorization":
            requestHeaders = .init([("DPoP", try #require(requestHeaders["DPoP"]))])
            expected = "missing"
        case "bearer-scheme":
            requestHeaders = try headers(client, token: tokens.accessToken, verifier: verifier, scheme: "Bearer")
        case "no-proof":
            requestHeaders = .init([("Authorization", "DPoP \(tokens.accessToken)")])
            expected = "invalid_dpop_proof"
        case "wrong-ath":
            requestHeaders = try headers(client, token: tokens.accessToken, verifier: verifier, ath: "another-token")
            expected = "invalid_dpop_proof"
        case "wrong-method":
            requestHeaders = try headers(client, token: tokens.accessToken, verifier: verifier, method: "GET")
            expected = "invalid_dpop_proof"
        case "wrong-url":
            requestHeaders = try headers(
                client, token: tokens.accessToken, verifier: verifier,
                htu: TestServer.issuer + "/xrpc/com.atproto.repo.deleteRecord"
            )
            expected = "invalid_dpop_proof"
        case "no-nonce":
            requestHeaders = try headers(client, token: tokens.accessToken, verifier: verifier, nonce: .some(nil))
            expected = "use_dpop_nonce"
        case "unknown-token":
            requestHeaders = try headers(client, token: String(repeating: "B", count: 43), verifier: verifier)
        default:
            client.dpopKey = try OAuthSigningKey.generate()
            requestHeaders = try headers(client, token: tokens.accessToken, verifier: verifier)
        }
        var failure: OAuthResourceAuthorizationFailure?
        do {
            _ = try await verifier.authenticate(method: "POST", url: target, headers: requestHeaders)
        } catch {
            failure = error
        }
        let caught = try #require(failure, "\(scenario) was accepted")
        let challenge = verifier.challenge(for: caught)
        #expect(challenge.status == 401)
        let header = try #require(challenge.headers["WWW-Authenticate"])
        #expect(header.hasPrefix("DPoP "))
        if expected == "missing" {
            #expect(!header.contains("error="))
        } else {
            #expect(header.contains("error=\"\(expected)\""), "\(scenario): \(header)")
        }
        let nonce = try #require(challenge.headers["DPoP-Nonce"])
        #expect(harness.server.nonceService.isValid(nonce, now: harness.clock.now()))
    }

    @Test("a replayed proof is refused")
    func proofReplay() async throws {
        let (_, client, tokens, verifier) = try await setUp()
        let requestHeaders = try headers(client, token: tokens.accessToken, verifier: verifier)
        let target = try #require(URL(string: url))
        _ = try await verifier.authenticate(method: "POST", url: target, headers: requestHeaders)
        await #expect(throws: OAuthResourceAuthorizationFailure.invalidDPoPProof("DPoP proof was replayed")) {
            _ = try await verifier.authenticate(method: "POST", url: target, headers: requestHeaders)
        }
    }

    @Test("a revoked session's access token stops working immediately")
    func revokedSession() async throws {
        let (harness, client, tokens, verifier) = try await setUp()
        try await harness.server.revokeAllSessions(subject: TestAccounts.alice.did)
        await #expect(throws: OAuthResourceAuthorizationFailure.self) {
            _ = try await authenticate(verifier, client, token: tokens.accessToken)
        }
    }

    @Test("a scope failure is a 403 insufficient_scope challenge")
    func insufficientScope() async throws {
        let (_, _, _, verifier) = try await setUp()
        let challenge = verifier.challenge(for: .insufficientScope(needed: "repo:app.bsky.feed.like"))
        #expect(challenge.status == 403)
        #expect(challenge.headers["WWW-Authenticate"]?.contains("insufficient_scope") == true)
    }

    @Test("signed tokens: tampering, a foreign issuer key, a wrong audience and expiry are all refused")
    func signedTokenFailures() async throws {
        let key = try OAuthSigningKey.generate(keyID: "as-1")
        let (harness, client, tokens, _) = try await setUp(.signedJWT(key))
        func stateless(resource: String = TestServer.issuer, key verificationKey: OAuthSigningKey = key) throws -> OAuthResourceServerVerifier {
            try OAuthResourceServerVerifier(
                issuer: #require(URL(string: TestServer.issuer)),
                resource: #require(URL(string: resource)),
                keys: OAuthJSONWebKeySet(keys: [verificationKey.publicJWK]),
                secret: Data(repeating: 9, count: 32),
                replayStore: InMemoryOAuthStore(),
                clock: harness.clock
            )
        }
        _ = try await authenticate(stateless(), client, token: tokens.accessToken)

        var parts = tokens.accessToken.split(separator: ".").map(String.init)
        parts[1] = String(parts[1].dropLast()) + (parts[1].hasSuffix("A") ? "B" : "A")
        let tampered = parts.joined(separator: ".")
        for (label, verifier, token) in try [
            ("tampered", stateless(), tampered),
            ("foreign key", stateless(key: OAuthSigningKey.generate(keyID: "as-1")), tokens.accessToken),
            ("wrong audience", stateless(resource: "https://other-pds.example"), tokens.accessToken),
        ] {
            await #expect(throws: OAuthResourceAuthorizationFailure.self, "\(label)") {
                _ = try await authenticate(verifier, client, token: token)
            }
        }
        harness.clock.advance(16 * 60)
        await #expect(throws: OAuthResourceAuthorizationFailure.self) {
            _ = try await authenticate(stateless(), client, token: tokens.accessToken)
        }
    }

    /// `count` distinct repo scopes of about 80 bytes each, plus `atproto`.
    private static func largeScopes(_ count: Int) -> [String] {
        ["atproto"] + (0 ..< count).map { "repo:app.example.c\($0)" + String(repeating: "x", count: 55) }
    }

    @Test("signed tokens: a grant too large for a token the verifier accepts is refused at PAR, before consent")
    func signedTokenSizeRefusedAtPAR() async throws {
        let scopes = Self.largeScopes(60) // about 4.9 KB: admitted raw, too large to sign
        let scope = scopes.joined(separator: " ")
        #expect(scope.utf8.count > OAuthAccessTokenFormat.signedTokenScopeBudget)
        #expect(scope.utf8.count <= OAuthScopeBudget.rawInput.bytesPerSet)

        let signed = try TestServer(
            accessTokenFormat: .signedJWT(OAuthSigningKey.generate(keyID: "as-1")),
            webClientScopes: Set(scopes)
        )
        let response = try await TestClient(signed).send(
            OAuthAuthorizationServer.Path.pushedAuthorizationRequest, TestClient(signed).parFields(scope: scope)
        )
        #expect(response.status == 400)
        #expect(response.oauthError == "invalid_scope")

        // Opaque tokens carry no scope, so the same request is fine there.
        let opaque = try TestServer(webClientScopes: Set(scopes))
        _ = try await TestClient(opaque).signIn(scope: scope)
    }

    @Test("signed tokens: the largest grant PAR admits yields a token the resource verifier accepts")
    func signedTokenSizeFitsVerifier() async throws {
        let key = try OAuthSigningKey.generate(keyID: "as-1")
        var scopes = Self.largeScopes(0)
        while (scopes + ["repo:app.example.c\(scopes.count)" + String(repeating: "x", count: 55)])
            .joined(separator: " ").utf8.count <= OAuthAccessTokenFormat.signedTokenScopeBudget
        {
            scopes.append("repo:app.example.c\(scopes.count)" + String(repeating: "x", count: 55))
        }
        let harness = try TestServer(accessTokenFormat: .signedJWT(key), webClientScopes: Set(scopes))
        let client = try TestClient(harness)
        let tokens = try await client.signIn(scope: scopes.joined(separator: " "))
        #expect(tokens.accessToken.utf8.count <= OAuthAccessTokenFormat.maximumSignedTokenBytes)
        let verifier = try OAuthResourceServerVerifier(
            issuer: #require(URL(string: TestServer.issuer)),
            resource: #require(URL(string: TestServer.issuer)),
            keys: OAuthJSONWebKeySet(keys: [key.publicJWK]),
            secret: Data(repeating: 9, count: 32),
            replayStore: InMemoryOAuthStore(),
            clock: harness.clock
        )
        let grant = try await authenticate(verifier, client, token: tokens.accessToken)
        try grant.requireRepo(collection: "app.example.c1" + String(repeating: "x", count: 55), action: .create)
    }
}
