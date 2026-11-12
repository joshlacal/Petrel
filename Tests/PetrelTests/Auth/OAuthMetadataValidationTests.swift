import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

/// Server metadata validation ("Server Metadata" in the atproto OAuth spec).
///
/// The first half exercises the validators directly, one requirement per
/// case. The second half drives real flows against `FakeOAuthServer`, which has
/// working PAR and token endpoints, so a rejection can only come from the
/// metadata check under test and the tests can assert that nothing was sent to
/// a server whose metadata was refused.
@Suite("OAuth server metadata validation", .serialized)
struct OAuthMetadataValidationTests {
    // MARK: - Fixtures

    private static let issuer = "https://auth.example.com"

    /// A document satisfying every requirement of the profile.
    private static func conformingAuthorizationServer(issuer: String = issuer) -> [String: Any] {
        [
            "issuer": issuer,
            "authorization_endpoint": "\(issuer)/authorize",
            "token_endpoint": "\(issuer)/token",
            "pushed_authorization_request_endpoint": "\(issuer)/par",
            "response_types_supported": ["code"],
            "grant_types_supported": ["authorization_code", "refresh_token"],
            "code_challenge_methods_supported": ["S256"],
            "token_endpoint_auth_methods_supported": ["none", "private_key_jwt"],
            "token_endpoint_auth_signing_alg_values_supported": ["ES256"],
            "scopes_supported": ["atproto"],
            "authorization_response_iss_parameter_supported": true,
            "require_pushed_authorization_requests": true,
            "dpop_signing_alg_values_supported": ["ES256"],
            "client_id_metadata_document_supported": true,
        ]
    }

    private static func decodeAuthorizationServer(_ object: [String: Any]) throws -> AuthorizationServerMetadata {
        try JSONDecoder().decode(
            AuthorizationServerMetadata.self, from: JSONSerialization.data(withJSONObject: object)
        )
    }

    private static func validate(
        _ mutate: (inout [String: Any]) -> Void,
        fetchedFrom issuer: String = issuer,
        clientAuthentication: OAuthClientAuthenticationMethod = .none
    ) throws {
        var document = conformingAuthorizationServer()
        mutate(&document)
        try decodeAuthorizationServer(document)
            .validate(fetchedFrom: issuer, clientAuthentication: clientAuthentication)
    }

    // MARK: - Issuer and origin shape

    @Test("A conforming document validates for public and confidential clients")
    func conformingDocumentValidates() throws {
        try Self.validate { _ in }
        try Self.validate({ _ in }, clientAuthentication: .privateKeyJWT)
    }

    @Test("issuer must equal the origin the document was fetched from")
    func issuerMustMatchFetchOrigin() {
        #expect(throws: OAuthMetadataError.issuerMismatch(
            expected: "https://evil.example", actual: Self.issuer
        )) {
            try Self.validate({ _ in }, fetchedFrom: "https://evil.example")
        }
    }

    @Test(
        "issuer must be a canonical https origin",
        arguments: [
            "http://auth.example.com", // not https
            "https://auth.example.com/", // trailing slash
            "https://auth.example.com/path", // path segment
            "https://auth.example.com:443", // default port spelled out
            "https://user:pass@auth.example.com", // credentials
            "https://auth.example.com?x=1", // query
            "https://auth.example.com#frag", // fragment
            "https://AUTH.example.com", // not canonical case
            "auth.example.com", // no scheme
            "",
        ]
    )
    func issuerMustBeCanonicalOrigin(_ issuer: String) {
        #expect(throws: OAuthMetadataError.invalidOrigin(issuer)) {
            // Fetched "from" the same string, so only the shape check can fail.
            try Self.validate({ $0["issuer"] = issuer }, fetchedFrom: issuer)
        }
    }

    @Test("A non-default port is part of the origin; loopback http is allowed for development")
    func originCanonicalisation() throws {
        #expect(try OAuthOrigin.requireCanonical("https://auth.example.com:8443") == "https://auth.example.com:8443")
        #expect(try OAuthOrigin.requireCanonical("http://localhost:2583") == "http://localhost:2583")
        #expect(OAuthOrigin.canonical(of: URL(string: "https://PDS.Example.com:443/xrpc/x?y=1")!) == "https://pds.example.com")
        #expect(OAuthOrigin.canonical(of: URL(string: "http://pds.example.com")!) == nil)
        #expect(OAuthOrigin.canonical(of: URL(string: "ftp://pds.example.com")!) == nil)
    }

    // MARK: - Required values

    @Test(
        "A required list value that is missing is reported by field and value",
        arguments: [
            ("response_types_supported", "code"),
            ("grant_types_supported", "authorization_code"),
            ("grant_types_supported", "refresh_token"),
            ("code_challenge_methods_supported", "S256"),
            ("token_endpoint_auth_methods_supported", "none"),
            ("scopes_supported", "atproto"),
            ("dpop_signing_alg_values_supported", "ES256"),
        ]
    )
    func requiredListValues(field: String, value: String) {
        // Present but without the value.
        #expect(throws: OAuthMetadataError.missingRequiredValue(field: field, value: value)) {
            try Self.validate { document in
                document[field] = (document[field] as? [String] ?? []).filter { $0 != value }
            }
        }
        // Absent altogether: reported against the same field.
        #expect {
            try Self.validate { $0.removeValue(forKey: field) }
        } throws: { error in
            guard case let OAuthMetadataError.missingRequiredValue(reportedField, _) = error else { return false }
            return reportedField == field
        }
    }

    @Test("PKCE 'plain' alone is not accepted")
    func plainPKCERejected() {
        #expect(throws: OAuthMetadataError.missingRequiredValue(
            field: "code_challenge_methods_supported", value: "S256"
        )) {
            try Self.validate { $0["code_challenge_methods_supported"] = ["plain"] }
        }
    }

    @Test(
        "A boolean the profile requires must be present and true",
        arguments: [
            "authorization_response_iss_parameter_supported",
            "require_pushed_authorization_requests",
            "client_id_metadata_document_supported",
        ]
    )
    func requiredBooleans(field: String) {
        #expect(throws: OAuthMetadataError.requirementNotMet(field: field)) {
            try Self.validate { $0[field] = false }
        }
        #expect(throws: OAuthMetadataError.requirementNotMet(field: field)) {
            try Self.validate { $0.removeValue(forKey: field) }
        }
    }

    @Test("require_request_uri_registration may be omitted but must not be false")
    func requestURIRegistration() throws {
        try Self.validate { $0["require_request_uri_registration"] = true }
        #expect(throws: OAuthMetadataError.requirementNotMet(field: "require_request_uri_registration")) {
            try Self.validate { $0["require_request_uri_registration"] = false }
        }
    }

    @Test("The server must support the client's own authentication method")
    func clientAuthenticationMethod() {
        #expect(throws: OAuthMetadataError.missingRequiredValue(
            field: "token_endpoint_auth_methods_supported", value: "private_key_jwt"
        )) {
            try Self.validate(
                { $0["token_endpoint_auth_methods_supported"] = ["none"] },
                clientAuthentication: .privateKeyJWT
            )
        }
        #expect(throws: OAuthMetadataError.missingRequiredValue(
            field: "token_endpoint_auth_signing_alg_values_supported", value: "ES256"
        )) {
            try Self.validate(
                { $0["token_endpoint_auth_signing_alg_values_supported"] = ["RS256"] },
                clientAuthentication: .privateKeyJWT
            )
        }
        #expect(throws: OAuthMetadataError.forbiddenValue(
            field: "token_endpoint_auth_signing_alg_values_supported", value: "none"
        )) {
            try Self.validate { $0["token_endpoint_auth_signing_alg_values_supported"] = ["ES256", "none"] }
        }
    }

    // MARK: - Endpoints

    @Test(
        "Endpoints must be https URLs",
        arguments: [
            ("authorization_endpoint", "javascript:alert(1)"),
            ("authorization_endpoint", "http://auth.example.com/authorize"),
            ("authorization_endpoint", "myapp://authorize"),
            ("token_endpoint", "http://auth.example.com/token"),
            ("pushed_authorization_request_endpoint", "/par"),
            ("revocation_endpoint", "http://auth.example.com/revoke"),
            ("token_endpoint", "https://user:pw@auth.example.com/token"),
        ]
    )
    func endpointsMustBeHTTPS(field: String, value: String) {
        #expect(throws: OAuthMetadataError.invalidEndpoint(field: field, value: value)) {
            try Self.validate { $0[field] = value }
        }
    }

    @Test("A document missing an endpoint does not decode")
    func missingEndpointDoesNotDecode() {
        var document = Self.conformingAuthorizationServer()
        document.removeValue(forKey: "token_endpoint")
        #expect(throws: DecodingError.self) {
            try Self.decodeAuthorizationServer(document)
        }
    }

    // MARK: - Protected resource metadata

    private static func decodeProtectedResource(_ json: String) throws -> ProtectedResourceMetadata {
        try JSONDecoder().decode(ProtectedResourceMetadata.self, from: Data(json.utf8))
    }

    @Test("The minimal document the spec requires decodes and validates")
    func minimalProtectedResourceDocument() throws {
        let metadata = try Self.decodeProtectedResource(
            #"{"resource":"https://pds.example.com","authorization_servers":["https://auth.example.com"]}"#
        )
        #expect(try metadata.validate(forResourceAt: "https://pds.example.com") == "https://auth.example.com")
    }

    @Test("resource must equal the PDS origin")
    func resourceMustMatchOrigin() throws {
        let metadata = try Self.decodeProtectedResource(
            #"{"resource":"https://other.example.com","authorization_servers":["https://auth.example.com"]}"#
        )
        #expect(throws: OAuthMetadataError.resourceMismatch(
            expected: "https://pds.example.com", actual: "https://other.example.com"
        )) {
            try metadata.validate(forResourceAt: "https://pds.example.com")
        }
    }

    @Test("Exactly one authorization server is required", arguments: [0, 2])
    func exactlyOneAuthorizationServer(count: Int) throws {
        let servers = (0 ..< count).map { "\"https://auth\($0).example.com\"" }.joined(separator: ",")
        let metadata = try Self.decodeProtectedResource(
            #"{"resource":"https://pds.example.com","authorization_servers":[\#(servers)]}"#
        )
        #expect(throws: OAuthMetadataError.authorizationServerCount(count)) {
            try metadata.validate(forResourceAt: "https://pds.example.com")
        }
    }

    @Test(
        "The authorization server must be a plain https origin",
        arguments: [
            "https://auth.example.com/",
            "https://auth.example.com/oauth",
            "http://auth.example.com",
            "https://auth.example.com:443",
            "https://auth.example.com?x=1",
        ]
    )
    func authorizationServerOriginShape(server: String) throws {
        let metadata = try Self.decodeProtectedResource(
            #"{"resource":"https://pds.example.com","authorization_servers":["\#(server)"]}"#
        )
        #expect(throws: OAuthMetadataError.invalidOrigin(server)) {
            try metadata.validate(forResourceAt: "https://pds.example.com")
        }
    }

    // MARK: - Fetching

    private static let aliceDID = "did:plc:metadataalice"

    private func startIdentifierFlow(
        _ server: FakeOAuthServer, namespace: String
    ) async throws -> (url: URL, state: String) {
        let client = await OAuthTestClient.make(namespace: namespace, server: server)
        client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
        return try await client.strategy.startOAuthFlowWithState(identifier: "alice.test")
    }

    @Test("A PDS publishing only the mandated protected-resource fields can be signed in to")
    func minimalProtectedResourceMetadataCompletesLogin() async throws {
        let server = FakeOAuthServer()
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "metadata.minimal", server: server)
            let did = try await client.signIn(handle: "alice.test", did: Self.aliceDID, server: server)
            #expect(did == Self.aliceDID)
        }
    }

    @Test(
        "Metadata must be served with HTTP 200; redirects are not followed",
        arguments: [
            (FakeOAuthServer.Endpoint.protectedResourceMetadata, 204),
            (.protectedResourceMetadata, 302),
            (.protectedResourceMetadata, 404),
            (.authorizationServerMetadata, 201),
            (.authorizationServerMetadata, 301),
            (.authorizationServerMetadata, 500),
        ]
    )
    func metadataRequiresStatus200(endpoint: FakeOAuthServer.Endpoint, status: Int) async throws {
        let server = FakeOAuthServer()
        server.metadataStatus[endpoint] = status
        server.metadataHeaders[endpoint] = ["Location": "https://elsewhere.oauth.test/metadata"]
        let document: OAuthMetadataError.Document =
            endpoint == .protectedResourceMetadata ? .protectedResource : .authorizationServer
        try await withOAuthTestNetwork([server]) {
            await #expect(throws: OAuthMetadataError.unexpectedStatus(document: document, status: status)) {
                _ = try await startIdentifierFlow(server, namespace: "metadata.status.\(endpoint.rawValue).\(status)")
            }
            // Refused before anything was pushed. Had the redirect been followed,
            // the unknown host would have surfaced as a network error instead.
            #expect(server.requests(to: .par).isEmpty)
        }
    }

    @Test(
        "Metadata must be served as application/json",
        arguments: [FakeOAuthServer.Endpoint.protectedResourceMetadata, .authorizationServerMetadata]
    )
    func metadataRequiresJSONContentType(endpoint: FakeOAuthServer.Endpoint) async throws {
        let server = FakeOAuthServer()
        server.metadataContentType[endpoint] = "text/html"
        let document: OAuthMetadataError.Document =
            endpoint == .protectedResourceMetadata ? .protectedResource : .authorizationServer
        try await withOAuthTestNetwork([server]) {
            await #expect(throws: OAuthMetadataError.unexpectedContentType(document: document, contentType: "text/html")) {
                _ = try await startIdentifierFlow(server, namespace: "metadata.ctype.\(endpoint.rawValue)")
            }
            #expect(server.requests(to: .par).isEmpty)
        }
    }

    @Test("application/json with a charset parameter is accepted")
    func jsonContentTypeWithParameters() async throws {
        let server = FakeOAuthServer()
        server.metadataContentType[.authorizationServerMetadata] = "Application/JSON; charset=utf-8"
        try await withOAuthTestNetwork([server]) {
            _ = try await startIdentifierFlow(server, namespace: "metadata.ctype.charset")
            #expect(server.requests(to: .par).last?.status == 201)
        }
    }

    @Test("A failing protected-resource document is an error, never a silent fallback to the PDS")
    func identifierFlowDoesNotFallBackToPDSAsAuthorizationServer() async throws {
        // The PDS answers its protected-resource document with garbage but would
        // happily serve authorization-server metadata if asked.
        let server = FakeOAuthServer(pdsOrigin: "https://solo.oauth.test", issuer: "https://solo.oauth.test")
        server.protectedResourceMetadata = ["unexpected": true]
        try await withOAuthTestNetwork([server]) {
            await #expect(throws: OAuthMetadataError.malformedDocument(document: .protectedResource)) {
                _ = try await startIdentifierFlow(server, namespace: "metadata.nofallback")
            }
            #expect(server.requests(to: .authorizationServerMetadata).isEmpty)
            #expect(server.requests(to: .par).isEmpty)
        }
    }

    @Test("The PDS must be among the resources its authorization server lists")
    func protectedResourcesMustListPDS() async throws {
        let server = FakeOAuthServer()
        server.authorizationServerMetadataOverrides["protected_resources"] = ["https://another-pds.oauth.test"]
        try await withOAuthTestNetwork([server]) {
            await #expect(throws: OAuthMetadataError.resourceNotProtected(
                resource: server.pdsOrigin, issuer: server.issuer
            )) {
                _ = try await startIdentifierFlow(server, namespace: "metadata.protected")
            }
        }
    }

    // MARK: - The forged-issuer attack

    /// The attack the issuer check exists to stop. A host the user names serves
    /// authorization-server metadata claiming to be a different, legitimate
    /// issuer, and runs its own PAR and token endpoints. Its token endpoint
    /// would return any `sub` it likes; the victim's real PDS does list the
    /// legitimate issuer, so every later check would pass.
    @Test("Server-first login refuses a host whose metadata claims another issuer")
    func serverFirstRefusesForgedIssuer() async throws {
        let legitimate = FakeOAuthServer(pdsOrigin: "https://pds.honest.test", issuer: "https://auth.honest.test")
        let evil = FakeOAuthServer(pdsOrigin: "https://evil.test", issuer: "https://evil.test")
        evil.authorizationServerMetadataOverrides["issuer"] = legitimate.issuer

        try await withOAuthTestNetwork([legitimate, evil]) {
            let client = await OAuthTestClient.make(namespace: "metadata.forged.server", server: legitimate)
            await #expect(throws: OAuthMetadataError.issuerMismatch(
                expected: "https://evil.test", actual: legitimate.issuer
            )) {
                _ = try await client.strategy.startOAuthFlowForSignUp(
                    pdsURL: URL(string: "https://evil.test")!, bskyAppViewDID: nil, bskyChatDID: nil
                )
            }
            // The forged server received nothing it could turn into a session.
            #expect(evil.requests(to: .par).isEmpty)
            #expect(evil.requests(to: .token).isEmpty)
            #expect(await client.accountManager.listAccounts().isEmpty)
        }
    }

    @Test("Identifier-first login refuses a PDS whose authorization server claims another issuer")
    func identifierFirstRefusesForgedIssuer() async throws {
        let server = FakeOAuthServer()
        server.authorizationServerMetadataOverrides["issuer"] = "https://bsky.social"
        try await withOAuthTestNetwork([server]) {
            await #expect(throws: OAuthMetadataError.issuerMismatch(
                expected: server.issuer, actual: "https://bsky.social"
            )) {
                _ = try await startIdentifierFlow(server, namespace: "metadata.forged.identifier")
            }
            #expect(server.requests(to: .par).isEmpty)
        }
    }

    @Test("An authorization endpoint that is not https is never handed to the app")
    func hostileAuthorizationEndpointRejected() async throws {
        let server = FakeOAuthServer()
        server.authorizationServerMetadataOverrides["authorization_endpoint"] = "tel:+15555550100"
        try await withOAuthTestNetwork([server]) {
            await #expect(throws: OAuthMetadataError.invalidEndpoint(
                field: "authorization_endpoint", value: "tel:+15555550100"
            )) {
                _ = try await startIdentifierFlow(server, namespace: "metadata.authz.endpoint")
            }
            #expect(server.requests(to: .par).isEmpty)
        }
    }

    @Test("A confidential client refuses to mint an assertion for an unvalidated issuer")
    func confidentialClientMintsNoAssertionForForgedIssuer() async throws {
        let server = FakeOAuthServer()
        server.authorizationServerMetadataOverrides["issuer"] = "https://bsky.social"
        let key = try OAuthClientAssertionKey.generate(keyID: "key-1")
        let signer = CountingSigner(key: key)
        try await withOAuthTestNetwork([server]) {
            let client = await OAuthTestClient.make(namespace: "metadata.forged.confidential", server: server, signer: signer)
            client.resolver.register(did: Self.aliceDID, handle: "alice.test", pds: server.pdsURL)
            await #expect(throws: OAuthMetadataError.self) {
                _ = try await client.strategy.startOAuthFlowWithState(identifier: "alice.test")
            }
            #expect(signer.signatureCount == 0)
        }
    }
}

/// Counts how many assertions a confidential client signed.
final class CountingSigner: OAuthClientAssertionSigner, @unchecked Sendable {
    private let key: OAuthClientAssertionKey
    private let lock = NSLock()
    private var count = 0

    init(key: OAuthClientAssertionKey) {
        self.key = key
    }

    var keyID: String { key.keyID }
    var signatureCount: Int { lock.withLock { count } }

    func signES256(_ signingInput: Data) async throws -> Data {
        lock.withLock { count += 1 }
        return try await key.signES256(signingInput)
    }
}
