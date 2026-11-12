import Foundation
import PetrelCrypto

/// An AT Protocol OAuth authorization server.
///
/// The server is a value with one entry point, ``handle(_:)``, that maps an
/// ``OAuthHTTPRequest`` to an ``OAuthHTTPResponse``. It depends on no web
/// framework: an adapter registers ``routes`` and forwards requests. Storage,
/// accounts, client discovery, Lexicon resolution, the user interface, the
/// clock and the random source are all injected.
///
/// Endpoints:
///
/// | method | path | purpose |
/// |---|---|---|
/// | GET | `/.well-known/oauth-authorization-server` | server metadata (RFC 8414) |
/// | GET | `/.well-known/oauth-protected-resource` | resource metadata (RFC 9728) |
/// | GET | `/oauth/jwks` | access-token verification keys |
/// | POST | `/oauth/par` | pushed authorization request (RFC 9126) |
/// | GET | `/oauth/authorize` | start of the Authorization Interface |
/// | POST | `/oauth/authorize/sign-in`, `/select-account`, `/second-factor`, `/consent` | interface forms |
/// | POST | `/oauth/token` | `authorization_code` and `refresh_token` grants |
/// | POST | `/oauth/revoke` | token revocation (RFC 7009) |
public struct OAuthAuthorizationServer: Sendable {
    /// The paths the server answers.
    public enum Path {
        /// Authorization server metadata.
        public static let authorizationServerMetadata = "/.well-known/oauth-authorization-server"
        /// Protected resource metadata.
        public static let protectedResourceMetadata = "/.well-known/oauth-protected-resource"
        /// The server's public signing keys.
        public static let jwks = "/oauth/jwks"
        /// Pushed authorization requests.
        public static let pushedAuthorizationRequest = "/oauth/par"
        /// The authorization endpoint.
        public static let authorize = "/oauth/authorize"
        /// The sign-in form target.
        public static let signIn = "/oauth/authorize/sign-in"
        /// The account-selection form target.
        public static let selectAccount = "/oauth/authorize/select-account"
        /// The second-factor form target.
        public static let secondFactor = "/oauth/authorize/second-factor"
        /// The consent form target.
        public static let consent = "/oauth/authorize/consent"
        /// The token endpoint.
        public static let token = "/oauth/token"
        /// The revocation endpoint.
        public static let revoke = "/oauth/revoke"
    }

    /// Every method and path ``handle(_:)`` answers, for registering with a
    /// web framework. `OPTIONS` routes are the CORS preflights.
    public static let routes: [OAuthRoute] = {
        var routes = [
            OAuthRoute(method: "GET", path: Path.authorizationServerMetadata),
            OAuthRoute(method: "GET", path: Path.protectedResourceMetadata),
            OAuthRoute(method: "GET", path: Path.jwks),
            OAuthRoute(method: "POST", path: Path.pushedAuthorizationRequest),
            OAuthRoute(method: "GET", path: Path.authorize),
            OAuthRoute(method: "POST", path: Path.signIn),
            OAuthRoute(method: "POST", path: Path.selectAccount),
            OAuthRoute(method: "POST", path: Path.secondFactor),
            OAuthRoute(method: "POST", path: Path.consent),
            OAuthRoute(method: "POST", path: Path.token),
            OAuthRoute(method: "POST", path: Path.revoke),
        ]
        for path in corsPaths {
            routes.append(OAuthRoute(method: "OPTIONS", path: path))
        }
        return routes
    }()

    static let corsPaths: Set<String> = [
        Path.authorizationServerMetadata, Path.protectedResourceMetadata, Path.jwks,
        Path.pushedAuthorizationRequest, Path.token, Path.revoke,
    ]

    /// The server's configuration.
    public let configuration: OAuthAuthorizationServerConfiguration
    /// The metadata documents the server publishes.
    public let metadata: OAuthMetadataPublication
    /// The DPoP nonces the server issues. Share it with a resource server on
    /// the same host so both accept each other's nonces.
    public let nonceService: OAuthDPoPNonceService

    let store: any OAuthServerStore
    let accounts: any OAuthAccountAuthenticating
    let clients: any OAuthClientResolving
    let lexiconResolver: (any OAuthLexiconResolving)?
    let interface: any OAuthInterfaceRendering
    let clock: any OAuthClock
    let random: any OAuthRandomSource
    let digest: OAuthKeyedDigest
    let dpopValidator: OAuthDPoPProofValidator
    let assertionValidator: OAuthClientAssertionValidator
    let flows: OAuthBrowserFlowService

    /// Creates a server.
    ///
    /// - Parameters:
    ///   - configuration: issuer, secret, lifetimes and policy.
    ///   - store: persistence. ``InMemoryOAuthStore`` for tests and
    ///     development.
    ///   - accounts: the host's account system.
    ///   - clients: client discovery. Usually an ``OAuthClientMetadataLoader``.
    ///   - lexiconResolver: resolves `include:` permission sets. Without one,
    ///     a request that names a permission set is refused with
    ///     `invalid_scope`.
    ///   - interface: renders the Authorization Interface.
    ///   - clock: the time source.
    ///   - random: the source of codes, tokens and other opaque values.
    public init(
        configuration: OAuthAuthorizationServerConfiguration,
        store: any OAuthServerStore,
        accounts: any OAuthAccountAuthenticating,
        clients: any OAuthClientResolving,
        lexiconResolver: (any OAuthLexiconResolving)? = nil,
        interface: any OAuthInterfaceRendering = OAuthDefaultInterface(),
        clock: any OAuthClock = SystemOAuthClock(),
        random: any OAuthRandomSource = SystemOAuthRandomSource()
    ) throws {
        try configuration.validate()
        self.configuration = configuration
        var publishesKeys = false
        if case .signedJWT = configuration.accessTokenFormat { publishesKeys = true }
        metadata = try OAuthMetadataPublication(
            resource: configuration.resource,
            issuer: configuration.issuer,
            scopesSupported: configuration.scopesSupported,
            publishesSigningKeys: publishesKeys
        )
        self.store = store
        self.accounts = accounts
        self.clients = clients
        self.lexiconResolver = lexiconResolver
        self.interface = interface
        self.clock = clock
        self.random = random
        digest = try OAuthKeyedDigest(secret: configuration.serverSecret)
        nonceService = try OAuthDPoPNonceService(secret: configuration.serverSecret)
        dpopValidator = try OAuthDPoPProofValidator(
            secret: configuration.serverSecret,
            nonceService: nonceService,
            replayStore: store
        )
        assertionValidator = try OAuthClientAssertionValidator(
            secret: configuration.serverSecret,
            replayStore: store
        )
        flows = try OAuthBrowserFlowService(secret: configuration.serverSecret, random: random)
    }

    /// The issuer identifier as it appears in metadata, tokens and the `iss`
    /// response parameter: exactly the configured origin, which configuration
    /// validation guarantees has no path, not even `/`.
    public var issuer: String {
        configuration.issuer.absoluteString
    }

    /// Answers one request. Requests for paths or methods the server does not
    /// serve get `404` or `405`; nothing throws.
    public func handle(_ request: OAuthHTTPRequest) async -> OAuthHTTPResponse {
        let known = Self.routes.filter { $0.path == request.path }
        guard !known.isEmpty else {
            return jsonError(404, "not_found", "no such endpoint", cors: false)
        }
        guard known.contains(where: { $0.method == request.method }) else {
            var response = jsonError(405, "invalid_request", "method not allowed", cors: Self.corsPaths.contains(request.path))
            response.headers.set("Allow", known.map(\.method).sorted().joined(separator: ", "))
            return response
        }
        if request.method == "OPTIONS" {
            return preflight()
        }
        switch request.path {
        case Path.authorizationServerMetadata:
            return metadataResponse(metadata.authorizationServer)
        case Path.protectedResourceMetadata:
            return metadataResponse(metadata.protectedResource)
        case Path.jwks:
            return jwksResponse()
        case Path.pushedAuthorizationRequest:
            return await handlePushedAuthorizationRequest(request)
        case Path.authorize:
            return await handleAuthorize(request)
        case Path.signIn:
            return await handleSignIn(request)
        case Path.selectAccount:
            return await handleSelectAccount(request)
        case Path.secondFactor:
            return await handleSecondFactor(request)
        case Path.consent:
            return await handleConsent(request)
        case Path.token:
            return await handleToken(request)
        case Path.revoke:
            return await handleRevoke(request)
        default:
            return jsonError(404, "not_found", "no such endpoint", cors: false)
        }
    }

    // MARK: - Session management

    /// The account's active sessions, for a "connected applications" page.
    public func sessions(subject: String) async throws -> [OAuthSession] {
        try await store.sessions(subject: subject, now: clock.now())
    }

    /// Revokes one of the account's sessions. A session that belongs to
    /// another account is left untouched, so a caller cannot revoke by
    /// guessing identifiers.
    ///
    /// - Returns: whether a session of this account was revoked.
    @discardableResult
    public func revokeSession(id: UUID, subject: String) async throws -> Bool {
        let now = clock.now()
        guard let session = try await store.session(id: id, now: now), session.subject == subject else {
            return false
        }
        try await store.revokeSession(id: id, now: now)
        return true
    }

    /// Revokes every session of an account, for example when its password
    /// changes or the account is disabled.
    public func revokeAllSessions(subject: String) async throws {
        // Not the "connected apps" listing: that omits sessions whose code
        // has been issued but not redeemed, and those codes must die too.
        try await store.revokeSessions(subject: subject, now: clock.now())
    }

    // MARK: - Metadata

    private func metadataResponse(_ document: some Encodable) -> OAuthHTTPResponse {
        guard let body = try? OAuthMetadataRenderer.render(document) else {
            return jsonError(500, "server_error", "metadata could not be rendered", cors: true)
        }
        var headers = corsHeaders()
        headers.set("Content-Type", "application/json")
        headers.set("Cache-Control", "max-age=300")
        return OAuthHTTPResponse(status: 200, headers: headers, body: body)
    }

    private func jwksResponse() -> OAuthHTTPResponse {
        struct Document: Encodable { let keys: [OAuthJSONWebKey] }
        var keys: [OAuthJSONWebKey] = []
        if case let .signedJWT(key) = configuration.accessTokenFormat, let jwk = try? key.publicJWK {
            keys = [jwk]
        }
        return metadataResponse(Document(keys: keys))
    }

    // MARK: - Shared response helpers

    struct ErrorBody: Encodable {
        let error: String
        let errorDescription: String?

        enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
        }
    }

    /// A failure of a JSON endpoint, carried as a thrown value so each
    /// handler reads as the happy path.
    struct EndpointError: Error {
        let status: Int
        let code: String
        let description: String
        var challengesNonce = false

        static func invalidRequest(_ description: String) -> EndpointError {
            EndpointError(status: 400, code: "invalid_request", description: description)
        }

        static func invalidClient(_ description: String) -> EndpointError {
            EndpointError(status: 401, code: "invalid_client", description: description)
        }

        static func invalidGrant(_ description: String) -> EndpointError {
            EndpointError(status: 400, code: "invalid_grant", description: description)
        }

        static let unavailable = EndpointError(
            status: 503, code: "temporarily_unavailable", description: "the server cannot answer right now"
        )
        static let serverError = EndpointError(
            status: 500, code: "server_error", description: "the request could not be completed"
        )
    }

    func corsHeaders() -> OAuthHTTPHeaders {
        OAuthHTTPHeaders([
            ("Access-Control-Allow-Origin", "*"),
            ("Access-Control-Expose-Headers", "DPoP-Nonce, WWW-Authenticate"),
        ])
    }

    private func preflight() -> OAuthHTTPResponse {
        var headers = corsHeaders()
        headers.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        headers.set("Access-Control-Allow-Headers", "Content-Type, DPoP, Authorization")
        headers.set("Access-Control-Max-Age", "86400")
        return OAuthHTTPResponse(status: 204, headers: headers)
    }

    func json(_ status: Int, _ body: some Encodable, nonce: Bool = true) -> OAuthHTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var headers = corsHeaders()
        headers.set("Content-Type", "application/json")
        headers.set("Cache-Control", "no-store")
        headers.set("Pragma", "no-cache")
        if nonce {
            headers.set("DPoP-Nonce", nonceService.current(now: clock.now()))
        }
        return OAuthHTTPResponse(status: status, headers: headers, body: (try? encoder.encode(body)) ?? Data("{}".utf8))
    }

    func jsonError(_ status: Int, _ code: String, _ description: String, cors: Bool = true) -> OAuthHTTPResponse {
        var response = json(status, ErrorBody(error: code, errorDescription: description), nonce: cors)
        if !cors {
            response.headers = OAuthHTTPHeaders([("Content-Type", "application/json"), ("Cache-Control", "no-store")])
        }
        return response
    }

    func response(for error: EndpointError) -> OAuthHTTPResponse {
        jsonError(error.status, error.code, error.description)
    }

    // MARK: - Shared request steps

    /// Parses a form body under the endpoint's size limit.
    func form(_ request: OAuthHTTPRequest) throws(EndpointError) -> [String: String] {
        guard OAuthForm.isFormContentType(request.headers) else {
            throw .invalidRequest("request body must be application/x-www-form-urlencoded")
        }
        do {
            return try OAuthForm.parse(request.body, maximumBytes: configuration.maximumFormBytes)
        } catch .tooLarge {
            throw EndpointError(status: 413, code: "invalid_request", description: "request body is too large")
        } catch {
            throw .invalidRequest("request body is malformed or repeats a parameter")
        }
    }

    /// The absolute URL of one of this server's endpoints, derived from the
    /// configured issuer and never from request headers.
    func endpointURL(_ path: String) -> URL {
        URL(string: issuer + path) ?? configuration.issuer
    }

    /// Validates the request's single DPoP proof for `path`.
    func requireDPoP(
        _ request: OAuthHTTPRequest,
        path: String,
        now: Date
    ) async throws(EndpointError) -> OAuthValidatedDPoPProof {
        let proofs = request.headers.values(for: "DPoP")
        guard proofs.count == 1, let proof = proofs.first else {
            throw EndpointError(
                status: 400, code: "invalid_dpop_proof",
                description: proofs.isEmpty ? "a DPoP proof is required" : "exactly one DPoP header is allowed"
            )
        }
        do {
            return try await dpopValidator.validate(
                proof, method: request.method, target: endpointURL(path), now: now
            )
        } catch .useNonce {
            throw EndpointError(
                status: 400, code: "use_dpop_nonce",
                description: "retry with the nonce from the DPoP-Nonce header", challengesNonce: true
            )
        } catch let .invalidProof(reason) {
            throw EndpointError(status: 400, code: "invalid_dpop_proof", description: reason)
        } catch {
            throw .unavailable
        }
    }

    /// Resolves the request's client and, for a confidential client, verifies
    /// its `private_key_jwt` assertion.
    func authenticateClient(
        _ fields: [String: String],
        revalidate: Bool,
        now: Date
    ) async throws(EndpointError) -> (client: OAuthResolvedClientMetadata, key: OAuthClientKeyBinding?) {
        guard let rawClientID = fields["client_id"], rawClientID.utf8.count <= 2048,
              let clientID = URL(string: rawClientID), clientID.absoluteString == rawClientID
        else {
            throw .invalidRequest("client_id is required and must be a URL")
        }
        let client: OAuthResolvedClientMetadata
        do {
            client = try await clients.resolve(clientID: clientID, revalidate: revalidate, now: now)
        } catch let error as OAuthServerError {
            if case .unavailable = error { throw .unavailable }
            throw EndpointError(
                status: 400, code: "invalid_client_metadata",
                description: "client metadata could not be validated: \(error)"
            )
        } catch {
            throw .unavailable
        }
        let assertion = fields["client_assertion"]
        let assertionType = fields["client_assertion_type"]
        switch client.metadata.tokenEndpointAuthMethod {
        case .none:
            guard assertion == nil, assertionType == nil else {
                throw .invalidClient("a public client must not send a client assertion")
            }
            return (client, nil)
        case .privateKeyJWT:
            guard let assertion, let assertionType else {
                throw .invalidClient("a confidential client must authenticate with private_key_jwt")
            }
            do {
                let validated = try await assertionValidator.validate(
                    assertion,
                    assertionType: assertionType,
                    client: client,
                    authorizationServerIssuer: issuer,
                    now: now
                )
                return (client, validated.key)
            } catch let error as OAuthServerError {
                if case .unavailable = error { throw .unavailable }
                if case let .unauthorized(reason) = error { throw .invalidClient(reason) }
                throw .invalidClient("client assertion was not accepted")
            } catch {
                throw .unavailable
            }
        }
    }

    /// Resolves `include:` scopes into the effective grant.
    func effectiveGrant(
        for requestedScopes: Set<String>,
        stage: OAuthScopeResolutionStage
    ) async throws -> OAuthExpandedScopeSet {
        try await OAuthLexiconScopeResolution.expandIncludes(
            requestedScopes, resolver: lexiconResolver, stage: stage
        )
    }
}
