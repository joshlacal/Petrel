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

/// The in-process confidential client ("Confidential Client Authentication"):
/// `private_key_jwt` assertions signed with a key the app holds.
///
/// `FakeOAuthServer` in `.jwks` mode verifies each assertion's ES256 signature
/// against the published JWKS and its `iss`, `sub`, `aud`, `exp`, `iat` and
/// single-use `jti` on every endpoint.
@Suite("OAuth confidential client", .serialized)
struct OAuthConfidentialClientTests {
    private static let aliceDID = "did:plc:confidentialalice"

    private func assertionClaims(_ request: FakeOAuthServer.RecordedRequest) throws -> (header: [String: Any], payload: [String: Any]) {
        let assertion = try #require(request.form["client_assertion"])
        let parts = assertion.split(separator: ".").map(String.init)
        try #require(parts.count == 3)
        return (try #require(TestJOSE.decodeObject(parts[0])), try #require(TestJOSE.decodeObject(parts[1])))
    }

    @Test("Login, refresh and logout authenticate every request with a valid, unique assertion")
    func confidentialClientLifecycle() async throws {
        let key = try OAuthClientAssertionKey.generate(keyID: "client-key-1")
        let server = FakeOAuthServer()
        server.clientAuthentication = .jwks([key.publicJWK])

        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "confidential.lifecycle", server: server, signer: key)
            try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            #expect(try await client.strategy.refreshTokenIfNeeded(forceRefresh: true) == .refreshedSuccessfully)
            try await client.strategy.logout()

            // The server accepted each of them, so signatures and claims verified.
            #expect(server.requests(to: .par).last?.status == 201)
            #expect(server.requests(to: .token).map(\.status) == [200, 200])
            #expect(server.requests(to: .revoke).last?.status == 200)
            #expect(server.isRevoked(sub: Self.aliceDID))

            let authenticated = server.requests.filter { [.par, .token, .revoke].contains($0.endpoint) }
            var identifiers: Set<String> = []
            for request in authenticated {
                #expect(request.form["client_assertion_type"] == "urn:ietf:params:oauth:client-assertion-type:jwt-bearer")
                #expect(request.form["client_id"] == OAuthTestClient.clientID)
                #expect(request.form["client_secret"] == nil)
                let (header, payload) = try assertionClaims(request)
                #expect(header["alg"] as? String == "ES256")
                #expect(header["kid"] as? String == "client-key-1")
                #expect(payload["iss"] as? String == OAuthTestClient.clientID)
                #expect(payload["sub"] as? String == OAuthTestClient.clientID)
                #expect(payload["aud"] as? String == server.issuer)
                let issuedAt = try #require(payload["iat"] as? Int)
                let expires = try #require(payload["exp"] as? Int)
                #expect(expires > issuedAt && expires - issuedAt <= 300)
                identifiers.insert(try #require(payload["jti"] as? String))
            }
            // A new jti for every request, including the PAR nonce retry.
            #expect(authenticated.count >= 5)
            #expect(identifiers.count == authenticated.count)
        }
    }

    @Test("An assertion signed with a key the server does not know is rejected by the server")
    func unknownKeyIsRejected() async throws {
        let published = try OAuthClientAssertionKey.generate(keyID: "client-key-1")
        // Same key ID, different key material.
        let impostor = try OAuthClientAssertionKey.generate(keyID: "client-key-1")
        let server = FakeOAuthServer()
        server.clientAuthentication = .jwks([published.publicJWK])

        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "confidential.impostor", server: server, signer: impostor)
            client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
            await #expect(throws: AuthError.serverError(401, "invalid_client: assertion signature")) {
                _ = try await client.strategy.startOAuthFlowWithState(identifier: "alice.test")
            }
        }
    }

    @Test("A signer that returns a malformed signature is refused locally")
    func malformedSignatureIsRefused() async throws {
        struct BrokenSigner: OAuthClientAssertionSigner {
            let keyID = "broken"
            func signES256(_: Data) async throws -> Data { Data([1, 2, 3]) }
        }
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "confidential.broken", server: server, signer: BrokenSigner())
            client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
            await #expect(throws: OAuthClientAssertionError.invalidSignature) {
                _ = try await client.strategy.startOAuthFlowWithState(identifier: "alice.test")
            }
            #expect(server.requests(to: .par).isEmpty)
        }
    }

    @Test("AuthManager switches a public OAuth client to confidential authentication")
    func authManagerUsesSigner() async throws {
        let key = try OAuthClientAssertionKey.generate(keyID: "client-key-1")
        let server = FakeOAuthServer()
        server.clientAuthentication = .jwks([key.publicJWK])
        try await withOAuthTestNetwork([server]) {
            let storage = KeychainStorage(namespace: "confidential.authmanager")
            let resolver = OAuthTestDIDResolver()
            resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
            let authManager = try AuthManager(
                mode: .publicOAuth,
                storage: storage,
                accountManager: await AccountManager(storage: storage),
                networkService: NetworkService(baseURL: server.pdsURL),
                oauthConfig: OAuthConfig(
                    clientId: OAuthTestClient.clientID, redirectUri: OAuthTestClient.redirectURI, scope: "atproto"
                ),
                didResolver: resolver
            )
            try await authManager.useClientAssertionSigner(key)
            let (url, _) = try await authManager.startOAuthFlowWithState(identifier: "alice.test")
            let result = try await authManager.handleOAuthCallback(url: server.approve(url, as: Self.aliceDID))
            #expect(result.did == Self.aliceDID)
            #expect(server.requests(to: .token).last?.form["client_assertion"] != nil)
        }
    }

    // MARK: - Keys and JWKS

    @Test("The published JWK is the public half only and verifies the key's signatures")
    func jwkExport() async throws {
        let key = try OAuthClientAssertionKey.generate(keyID: "kid-42")
        let jwk = key.publicJWK
        #expect(Set(jwk.keys) == ["kty", "crv", "x", "y", "kid", "use", "alg"])
        #expect(jwk["kty"] == "EC")
        #expect(jwk["crv"] == "P-256")
        #expect(jwk["kid"] == "kid-42")
        #expect(jwk["use"] == "sig")
        #expect(jwk["alg"] == "ES256")

        let signingInput = "eyJhbGciOiJFUzI1NiJ9.eyJ0ZXN0Ijp0cnVlfQ"
        let signature = try await key.signES256(Data(signingInput.utf8))
        #expect(signature.count == 64)
        let jws = "\(signingInput).\(TestJOSE.base64URLEncode(signature))"
        #expect(TestJOSE.verifyES256(jws, x: try #require(jwk["x"]), y: try #require(jwk["y"])))

        let other = try OAuthClientAssertionKey.generate()
        #expect(!TestJOSE.verifyES256(jws, x: try #require(other.publicJWK["x"]), y: try #require(other.publicJWK["y"])))
    }

    @Test("A JWKS document lists every key and contains no private material")
    func jwksDocument() throws {
        let keys = [
            try OAuthClientAssertionKey.generate(keyID: "current"),
            try OAuthClientAssertionKey.generate(keyID: "next"),
        ]
        let data = try OAuthClientAssertionKey.jwksDocument(for: keys)
        let document = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let published = try #require(document["keys"] as? [[String: String]])
        #expect(published.map { $0["kid"] } == ["current", "next"])
        #expect(published.allSatisfy { $0["d"] == nil })
        #expect(!String(decoding: data, as: UTF8.self).contains("\"d\""))
    }

    @Test("Key material is validated on construction")
    func keyValidation() throws {
        let raw = P256.Signing.PrivateKey().rawRepresentation
        #expect(throws: OAuthClientAssertionError.invalidKey) {
            _ = try OAuthClientAssertionKey(keyID: "", rawRepresentation: raw)
        }
        #expect(throws: OAuthClientAssertionError.invalidKey) {
            _ = try OAuthClientAssertionKey(keyID: "k", rawRepresentation: Data([1, 2, 3]))
        }
        #expect(throws: OAuthClientAssertionError.invalidKey) {
            _ = try OAuthClientAssertionKey(keyID: "k", pemRepresentation: "not a key")
        }
        // A PEM key and the same key as raw bytes publish the same JWK.
        let pemKey = P256.Signing.PrivateKey()
        let fromPEM = try OAuthClientAssertionKey(keyID: "k", pemRepresentation: pemKey.pemRepresentation)
        let fromRaw = try OAuthClientAssertionKey(keyID: "k", rawRepresentation: pemKey.rawRepresentation)
        #expect(fromPEM == fromRaw)
        #expect(fromPEM.publicJWK == fromRaw.publicJWK)
    }
}

/// `OAuthConfig` validation, the localhost development client, and the client
/// metadata document ("Clients" in the OAuth spec).
@Suite("OAuth client configuration")
struct OAuthConfigTests {
    private func config(
        clientId: String = "https://app.example.com/oauth-client-metadata.json",
        redirectUri: String = "com.example.app:/callback",
        scope: String = "atproto"
    ) -> OAuthConfig {
        OAuthConfig(clientId: clientId, redirectUri: redirectUri, scope: scope)
    }

    @Test(
        "Valid configurations",
        arguments: [
            ("https://app.example.com/oauth-client-metadata.json", "com.example.app:/callback"),
            ("https://app.example.com/oauth-client-metadata.json", "https://app.example.com/callback"),
            ("https://example.com/client.json", "com.example:/auth/done"),
            ("http://localhost", "http://127.0.0.1:8080/callback"),
            ("http://localhost?redirect_uri=http%3A%2F%2F%5B%3A%3A1%5D%2Fcb", "http://[::1]:9000/cb"),
        ]
    )
    func validConfigurations(clientId: String, redirectUri: String) throws {
        try config(clientId: clientId, redirectUri: redirectUri).validate()
    }

    @Test(
        "The scope must include atproto",
        arguments: ["transition:generic", "", "atprotox", "repo:app.bsky.feed.post"]
    )
    func scopeMustIncludeAtproto(scope: String) {
        #expect(throws: OAuthConfigurationError.scopeMissingAtproto(scope)) {
            try config(scope: scope).validate()
        }
    }

    @Test(
        "The client ID must be an https URL without a port, or http://localhost",
        arguments: [
            "http://app.example.com/client.json", // not https
            "https://app.example.com:8443/client.json", // port
            "http://localhost:3000", // localhost with a port
            "http://localhost/path", // localhost with a path
            "http://127.0.0.1", // IP address instead of localhost
            "app.example.com/client.json", // no scheme
            "https://user@app.example.com/client.json", // credentials
            "https://app.example.com/client.json#x", // fragment
            "my-client-id", // not a URL
        ]
    )
    func invalidClientIDs(clientId: String) {
        #expect(throws: OAuthConfigurationError.invalidClientID(clientId)) {
            try config(clientId: clientId).validate()
        }
    }

    @Test(
        "The redirect URI must fit the client ID",
        arguments: [
            ("https://app.example.com/client.json", "app.example.com:/callback"), // scheme not reversed
            ("https://app.example.com/client.json", "com.example.other:/callback"), // different domain
            ("https://app.example.com/client.json", "com.example.app://callback"), // two slashes
            ("https://app.example.com/client.json", "com.example.app:callback"), // no slash
            ("https://app.example.com/client.json", "http://app.example.com/callback"), // cleartext web redirect
            ("https://app.example.com/client.json", "http://127.0.0.1:8080/callback"), // loopback without a localhost client
            ("https://app.example.com/client.json", "https://app.example.com/callback#frag"), // fragment
            ("http://localhost", "http://localhost:8080/callback"), // hostname instead of loopback IP
            ("http://localhost", "com.example.app:/callback"), // custom scheme on a localhost client
        ]
    )
    func invalidRedirectURIs(clientId: String, redirectUri: String) {
        #expect(throws: OAuthConfigurationError.invalidRedirectURI(redirectUri)) {
            try config(clientId: clientId, redirectUri: redirectUri).validate()
        }
    }

    @Test("The localhost development client encodes its redirect URI and scope in the client ID")
    func loopbackClient() throws {
        let config = OAuthConfig.loopback(port: 8765, scope: "atproto transition:generic")
        try config.validate()
        #expect(config.isLoopbackClient)
        #expect(config.redirectUri == "http://127.0.0.1:8765/callback")
        #expect(config.scope == "atproto transition:generic")

        // What an authorization server derives the virtual client metadata from.
        let components = try #require(URLComponents(string: config.clientId))
        #expect(components.scheme == "http")
        #expect(components.host == "localhost")
        #expect(components.port == nil)
        #expect(components.path.isEmpty)
        let items = try #require(components.queryItems)
        #expect(items.map(\.name) == ["redirect_uri", "scope"])
        #expect(items.first(where: { $0.name == "redirect_uri" })?.value == "http://127.0.0.1:8765/callback")
        #expect(items.first(where: { $0.name == "scope" })?.value == "atproto transition:generic")
        #expect(!config.clientId.contains(" "))

        #expect(!self.config().isLoopbackClient)
        #expect(OAuthConfig.loopback(port: 1, path: "done").redirectUri == "http://127.0.0.1:1/done")
    }

    @Test("Typed scopes build the scope string")
    func typedScopes() throws {
        let scopes = try ATProtoScopeSet([
            .atproto,
            .repo(collections: ["app.bsky.feed.post"], actions: [.create]),
            .rpc(lxm: ["app.bsky.feed.getTimeline"], aud: "did:web:api.bsky.app#bsky_appview"),
        ])
        let config = OAuthConfig(
            clientId: "https://app.example.com/client.json", redirectUri: "com.example.app:/cb", scopes: scopes
        )
        try config.validate()
        #expect(config.scopes == scopes)
        #expect(config.scope.split(separator: " ").first == "atproto")
        #expect(config.scopes.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create)))
        #expect(!config.scopes.allowsRepo(.init(collection: "app.bsky.feed.post", action: .delete)))
        #expect(config.scopes.allowsRPC(.init(lxm: "app.bsky.feed.getTimeline", aud: "did:web:api.bsky.app#bsky_appview")))
        #expect(config.scopes.unrecognized.isEmpty)
    }

    @Test("The client metadata document carries every member the profile requires")
    func clientMetadataDocument() throws {
        let publicDocument = try config(scope: "atproto transition:generic").clientMetadataDocument(
            applicationType: .native, clientName: "Example"
        )
        #expect(publicDocument["client_id"] as? String == "https://app.example.com/oauth-client-metadata.json")
        #expect(publicDocument["application_type"] as? String == "native")
        #expect(publicDocument["grant_types"] as? [String] == ["authorization_code", "refresh_token"])
        #expect(publicDocument["scope"] as? String == "atproto transition:generic")
        #expect(publicDocument["response_types"] as? [String] == ["code"])
        #expect(publicDocument["redirect_uris"] as? [String] == ["com.example.app:/callback"])
        #expect(publicDocument["dpop_bound_access_tokens"] as? Bool == true)
        #expect(publicDocument["token_endpoint_auth_method"] as? String == "none")
        #expect(publicDocument["client_name"] as? String == "Example")
        #expect(publicDocument["jwks"] == nil)
        #expect(JSONSerialization.isValidJSONObject(publicDocument))

        let key = try OAuthClientAssertionKey.generate(keyID: "k1")
        let confidential = try config(redirectUri: "https://app.example.com/callback").clientMetadataDocument(
            applicationType: .web, confidentialKeys: [key]
        )
        #expect(confidential["token_endpoint_auth_method"] as? String == "private_key_jwt")
        #expect(confidential["token_endpoint_auth_signing_alg"] as? String == "ES256")
        let jwks = try #require(confidential["jwks"] as? [String: [[String: String]]])
        #expect(jwks["keys"] == [key.publicJWK])
        #expect(JSONSerialization.isValidJSONObject(confidential))

        #expect(throws: OAuthConfigurationError.scopeMissingAtproto("email")) {
            _ = try config(scope: "email").clientMetadataDocument(applicationType: .web)
        }
    }
}
