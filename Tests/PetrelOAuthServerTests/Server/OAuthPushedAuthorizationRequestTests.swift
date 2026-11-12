import Foundation
@testable import PetrelOAuthServer
import Testing

/// One test per way a pushed authorization request can be wrong, each
/// asserting the OAuth error code.
@Suite("Authorization server: pushed authorization requests")
struct OAuthPushedAuthorizationRequestTests {
    private let par = OAuthAuthorizationServer.Path.pushedAuthorizationRequest

    @Test("a valid request returns 201, a request_uri, expires_in and a DPoP nonce")
    func success() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let response = try await client.send(par, client.parFields())
        #expect(response.status == 201)
        let body = try response.decode(TestClient.PAR.self)
        #expect(body.request_uri.hasPrefix("urn:ietf:params:oauth:request_uri:"))
        #expect(body.expires_in == 300)
        #expect(response.headers["DPoP-Nonce"] != nil)
        #expect(response.headers["Cache-Control"] == "no-store")
    }

    @Test("a proof without a server nonce is challenged with use_dpop_nonce and a nonce header")
    func nonceChallenge() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let proof = try makeDPoPProof(
            key: client.dpopKey, method: "POST", url: TestServer.issuer + par, nonce: nil,
            issuedAt: harness.clock.now()
        )
        let response = try await harness.post(par, client.parFields(), headers: [("DPoP", proof)])
        #expect(response.status == 400)
        #expect(response.oauthError == "use_dpop_nonce")
        let nonce = try #require(response.headers["DPoP-Nonce"])
        #expect(harness.server.nonceService.isValid(nonce, now: harness.clock.now()))
    }

    @Test("a nonce challenge does not consume the client assertion: the same body succeeds on retry")
    func nonceChallengeKeepsClientAssertion() async throws {
        let harness = try TestServer()
        let client = try TestClient.confidential(harness)
        let fields = try client.parFields()
        let first = try makeDPoPProof(
            key: client.dpopKey, method: "POST", url: TestServer.issuer + par, nonce: nil, issuedAt: harness.clock.now()
        )
        let challenged = await harness.post(par, fields, headers: [("DPoP", first)])
        #expect(challenged.oauthError == "use_dpop_nonce")
        let retry = try makeDPoPProof(
            key: client.dpopKey, method: "POST", url: TestServer.issuer + par,
            nonce: challenged.headers["DPoP-Nonce"], issuedAt: harness.clock.now()
        )
        let accepted = await harness.post(par, fields, headers: [("DPoP", retry)])
        #expect(accepted.status == 201, "\(accepted.text)")
        // The assertion is still single-use once it has been accepted.
        client.state = UUID().uuidString
        let again = try makeDPoPProof(
            key: client.dpopKey, method: "POST", url: TestServer.issuer + par,
            nonce: accepted.headers["DPoP-Nonce"], issuedAt: harness.clock.now()
        )
        let replayed = await harness.post(par, fields, headers: [("DPoP", again)])
        #expect(replayed.oauthError == "invalid_client")
    }

    @Test("a request without a DPoP proof is refused")
    func missingProof() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let response = try await harness.post(par, client.parFields())
        #expect(response.oauthError == "invalid_dpop_proof")
    }

    @Test("two DPoP headers are refused")
    func twoProofs() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let nonce = harness.server.nonceService.current(now: harness.clock.now())
        let proofs = try (0 ..< 2).map { _ in
            try ("DPoP", makeDPoPProof(
                key: client.dpopKey, method: "POST", url: TestServer.issuer + par, nonce: nonce,
                issuedAt: harness.clock.now()
            ))
        }
        let response = try await harness.post(par, client.parFields(), headers: proofs)
        #expect(response.oauthError == "invalid_dpop_proof")
    }

    @Test("invalid parameters are refused with the right code", arguments: [
        (["code_challenge_method": "plain"], "invalid_request"),
        (["code_challenge_method": nil], "invalid_request"),
        (["code_challenge": nil], "invalid_request"),
        (["code_challenge": "too-short"], "invalid_request"),
        (["state": nil], "invalid_request"),
        (["state": ""], "invalid_request"),
        (["redirect_uri": nil], "invalid_request"),
        (["redirect_uri": "https://attacker.example/callback"], "invalid_request"),
        (["redirect_uri": "https://app.example.test/callback/extra"], "invalid_request"),
        (["response_type": "token"], "unsupported_response_type"),
        (["response_type": "code id_token"], "unsupported_response_type"),
        (["response_type": nil], "invalid_request"),
        (["response_mode": "form_post"], "invalid_request"),
        (["request_uri": "urn:ietf:params:oauth:request_uri:abc"], "invalid_request"),
        (["scope": nil], "invalid_scope"),
        (["scope": "transition:generic"], "invalid_scope"),
        (["scope": "atproto openid"], "invalid_scope"),
        (["scope": "atproto transition:email"], "invalid_scope"),
        (["scope": "atproto repo:app.bsky.feed.like"], "invalid_scope"),
        (["scope": "atproto nonsense:thing"], "invalid_scope"),
        (["scope": "atproto atproto"], "invalid_request"),
        (["client_id": nil], "invalid_request"),
        (["client_id": "https://unknown.example/client.json"], "invalid_client_metadata"),
        (["dpop_jkt": "not-the-proof-key"], "invalid_request"),
        (["login_hint": "has space"], "invalid_request"),
    ] as [([String: String?], String)])
    func invalidParameters(overrides: [String: String?], expected: String) async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let response = try await client.send(par, client.parFields(overrides: overrides))
        #expect(response.status == 400)
        #expect(response.oauthError == expected, "\(overrides) → \(response.text)")
    }

    @Test("a repeated form parameter is refused instead of resolved by position")
    func repeatedParameter() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let response = try await client.send(par, client.parFields() + [("state", "second")])
        #expect(response.oauthError == "invalid_request")
    }

    @Test("a JSON body is refused: the endpoint takes form encoding only")
    func jsonBody() async throws {
        let harness = try TestServer()
        let response = await harness.server.handle(OAuthHTTPRequest(
            method: "POST", path: par,
            headers: .init([("Content-Type", "application/json")]),
            body: Data("{}".utf8)
        ))
        #expect(response.oauthError == "invalid_request")
    }

    @Test("an oversized body is refused with 413")
    func oversizedBody() async throws {
        let harness = try TestServer()
        let response = await harness.post(par, [("scope", String(repeating: "a", count: 70000))])
        #expect(response.status == 413)
    }

    @Test("a code_challenge cannot be reused by a second request")
    func codeChallengeReuse() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        _ = try await client.pushRequest()
        client.state = UUID().uuidString
        let second = try await client.send(par, client.parFields())
        #expect(second.oauthError == "invalid_request")
        #expect(second.text.contains("code_challenge"))
    }

    @Test("a requested scope may be spelled differently from the declared one")
    func canonicalScopeComparison() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let response = try await client.send(
            par, client.parFields(scope: "atproto repo?collection=app.bsky.feed.post&action=create")
        )
        #expect(response.status == 201)
    }

    @Test("with the ignore policy an unknown scope is dropped from the grant instead of failing the request")
    func unknownScopeIgnored() async throws {
        let harness = try TestServer(
            webClientScopes: ["atproto", "transition:generic", "future:thing"], unknownScopePolicy: .ignore
        )
        let client = try TestClient(harness)
        let tokens = try await client.signIn(scope: "atproto transition:generic future:thing")
        #expect(tokens.scope == "atproto transition:generic")
    }

    @Test("a public client that sends a client assertion is refused")
    func publicClientWithAssertion() async throws {
        let harness = try TestServer()
        let client = try TestClient(harness)
        let other = try TestClient.confidential(harness)
        let response = try await client.send(par, client.parFields() + [
            ("client_assertion_type", OAuthClientAssertionValidator.assertionType),
            ("client_assertion", other.assertion()),
        ])
        #expect(response.status == 401)
        #expect(response.oauthError == "invalid_client")
    }

    @Test("a confidential client without an assertion is refused")
    func confidentialWithoutAssertion() async throws {
        let harness = try TestServer()
        let client = try TestClient(
            harness, clientID: TestServer.confidentialClientID, redirectURI: TestServer.confidentialRedirect
        )
        let response = try await client.send(par, client.parFields())
        #expect(response.status == 401)
        #expect(response.oauthError == "invalid_client")
    }

    @Test("client assertion failures", arguments: ["wrong-audience", "replayed", "unknown-key", "too-long", "wrong-issuer"])
    func clientAssertionFailures(scenario: String) async throws {
        let harness = try TestServer()
        let client = try TestClient.confidential(harness)
        // `send` would mint a fresh assertion, so post directly with a nonce.
        func post(_ assertion: String) async throws -> OAuthHTTPResponse {
            let nonce = harness.server.nonceService.current(now: harness.clock.now())
            let proof = try makeDPoPProof(
                key: OAuthSigningKey.generate(), method: "POST", url: TestServer.issuer + par, nonce: nonce,
                issuedAt: harness.clock.now()
            )
            var fields = try replacing(client.parFields(), assertion)
            fields.removeAll { $0.0 == "code_challenge" || $0.0 == "state" }
            fields.append(("code_challenge", OAuthPKCE.s256Challenge(for: UUID().uuidString + UUID().uuidString)))
            fields.append(("state", UUID().uuidString))
            return await harness.post(par, fields, headers: [("DPoP", proof)])
        }
        let assertion: String
        switch scenario {
        case "wrong-audience":
            assertion = try client.assertion(audience: "https://other.example")
        case "replayed":
            assertion = try client.assertion(jti: "fixed")
            let first = try await post(assertion)
            #expect(first.status == 201)
        case "unknown-key":
            assertion = try client.assertion(key: OAuthSigningKey.generate(keyID: "key-1"))
        case "too-long":
            assertion = try client.assertion(lifetime: 3600)
        default:
            let stranger = try TestClient(
                harness, clientID: "https://stranger.example/client.json",
                redirectURI: TestServer.confidentialRedirect, assertionKey: harness.confidentialKey
            )
            assertion = try stranger.assertion()
        }
        let response = try await post(assertion)
        #expect(response.status == 401, "\(scenario): \(response.text)")
        #expect(response.oauthError == "invalid_client")
    }

    private func replacing(_ fields: [(String, String)], _ assertion: String) -> [(String, String)] {
        fields.map { $0.0 == "client_assertion" ? ("client_assertion", assertion) : $0 }
    }

    @Test("a client assertion signed with ES256K is accepted when the client declares it")
    func secp256k1Assertion() async throws {
        let harness = try TestServer()
        let key = try OAuthSigningKey.generate(algorithm: .es256k, keyID: "k256")
        let keySet = try OAuthJSONWebKeySet(keys: [key.publicJWK])
        let clientID = "https://k256.example.test/client-metadata.json"
        try harness.clients.register(.init(
            metadata: OAuthClientMetadata(
                clientID: #require(URL(string: clientID)),
                redirectURIs: [#require(URL(string: "https://k256.example.test/cb"))],
                grantTypes: ["authorization_code"],
                responseTypes: ["code"],
                scopes: ["atproto"],
                tokenEndpointAuthMethod: .privateKeyJWT,
                tokenEndpointAuthSigningAlgorithm: "ES256K",
                dpopBoundAccessTokens: true,
                jwks: keySet
            ),
            keySet: keySet
        ))
        let client = try TestClient(
            harness, clientID: clientID, redirectURI: "https://k256.example.test/cb", assertionKey: key
        )
        let tokens = try await client.signIn(scope: "atproto")
        #expect(tokens.refreshToken == nil, "the client did not declare the refresh_token grant")
    }
}
