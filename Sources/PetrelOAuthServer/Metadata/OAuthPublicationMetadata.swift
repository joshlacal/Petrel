import Foundation

/// A standards-shaped protected-resource metadata document. Constructing this
/// value validates only URL and schema facts; it deliberately does not claim
/// that the corresponding authorization server is reachable or complete.
public struct OAuthProtectedResourceMetadata: Codable, Sendable, Equatable {
    /// `resource`: the resource server's identifier.
    public let resource: URL
    /// `authorization_servers`: exactly one issuer.
    public let authorizationServers: [URL]
    /// `bearer_methods_supported`.
    public let bearerMethodsSupported: [String]
    /// `scopes_supported`.
    public let scopesSupported: [String]

    /// Creates resource metadata naming one authorization server.
    public init(
        resource: URL,
        authorizationServer: URL,
        scopesSupported: [String] = ["atproto"]
    ) throws {
        self.resource = try OAuthPublishedURL.validate(resource, role: "resource")
        authorizationServers = [try OAuthPublishedURL.validateIssuer(authorizationServer)]
        bearerMethodsSupported = ["header"]
        self.scopesSupported = try OAuthPublishedURL.validateScopes(scopesSupported)
    }

    private enum CodingKeys: String, CodingKey {
        case resource
        case authorizationServers = "authorization_servers"
        case bearerMethodsSupported = "bearer_methods_supported"
        case scopesSupported = "scopes_supported"
    }
}

/// The authorization server metadata document (RFC 8414) with the values the
/// AT Protocol OAuth profile fixes: PAR required, PKCE S256 only, DPoP, the
/// `iss` response parameter, and client-ID metadata documents.
public struct OAuthAuthorizationServerMetadata: Codable, Sendable, Equatable {
    /// `issuer`.
    public let issuer: URL
    /// `authorization_endpoint`.
    public let authorizationEndpoint: URL
    /// `token_endpoint`.
    public let tokenEndpoint: URL
    /// `pushed_authorization_request_endpoint`.
    public let pushedAuthorizationRequestEndpoint: URL
    /// `revocation_endpoint`.
    public let revocationEndpoint: URL
    /// `jwks_uri`, when the server signs access tokens.
    public let jwksURI: URL?
    /// `response_types_supported`.
    public let responseTypesSupported: [String]
    /// `response_modes_supported`.
    public let responseModesSupported: [String]
    /// `grant_types_supported`.
    public let grantTypesSupported: [String]
    /// `code_challenge_methods_supported`.
    public let codeChallengeMethodsSupported: [String]
    /// `token_endpoint_auth_methods_supported`.
    public let tokenEndpointAuthMethodsSupported: [String]
    /// `token_endpoint_auth_signing_alg_values_supported`.
    public let tokenEndpointAuthSigningAlgValuesSupported: [String]
    /// `dpop_signing_alg_values_supported`.
    public let dpopSigningAlgValuesSupported: [String]
    /// `scopes_supported`.
    public let scopesSupported: [String]
    /// `authorization_response_iss_parameter_supported`: always true.
    public let authorizationResponseIssuerParameterSupported: Bool
    /// `require_pushed_authorization_requests`: always true.
    public let requirePushedAuthorizationRequests: Bool
    /// `client_id_metadata_document_supported`: always true.
    public let clientIDMetadataDocumentSupported: Bool

    /// Creates the metadata for an issuer, deriving every endpoint from it.
    public init(issuer: URL, scopesSupported: [String] = ["atproto"], publishesSigningKeys: Bool = false) throws {
        self.issuer = try OAuthPublishedURL.validateIssuer(issuer)
        jwksURI = publishesSigningKeys
            ? try OAuthPublishedURL.endpoint(issuer: self.issuer, path: "oauth/jwks")
            : nil
        authorizationEndpoint = try OAuthPublishedURL.endpoint(issuer: self.issuer, path: "oauth/authorize")
        tokenEndpoint = try OAuthPublishedURL.endpoint(issuer: self.issuer, path: "oauth/token")
        pushedAuthorizationRequestEndpoint = try OAuthPublishedURL.endpoint(issuer: self.issuer, path: "oauth/par")
        revocationEndpoint = try OAuthPublishedURL.endpoint(issuer: self.issuer, path: "oauth/revoke")
        responseTypesSupported = ["code"]
        responseModesSupported = ["query", "fragment"]
        grantTypesSupported = ["authorization_code", "refresh_token"]
        codeChallengeMethodsSupported = ["S256"]
        tokenEndpointAuthMethodsSupported = ["none", "private_key_jwt"]
        tokenEndpointAuthSigningAlgValuesSupported = OAuthJWSAlgorithm.allCases.map(\.rawValue)
        dpopSigningAlgValuesSupported = OAuthJWSAlgorithm.allCases.map(\.rawValue)
        self.scopesSupported = try OAuthPublishedURL.validateScopes(scopesSupported)
        authorizationResponseIssuerParameterSupported = true
        requirePushedAuthorizationRequests = true
        clientIDMetadataDocumentSupported = true
    }

    private enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case pushedAuthorizationRequestEndpoint = "pushed_authorization_request_endpoint"
        case revocationEndpoint = "revocation_endpoint"
        case jwksURI = "jwks_uri"
        case responseTypesSupported = "response_types_supported"
        case responseModesSupported = "response_modes_supported"
        case grantTypesSupported = "grant_types_supported"
        case codeChallengeMethodsSupported = "code_challenge_methods_supported"
        case tokenEndpointAuthMethodsSupported = "token_endpoint_auth_methods_supported"
        case tokenEndpointAuthSigningAlgValuesSupported = "token_endpoint_auth_signing_alg_values_supported"
        case dpopSigningAlgValuesSupported = "dpop_signing_alg_values_supported"
        case scopesSupported = "scopes_supported"
        case authorizationResponseIssuerParameterSupported = "authorization_response_iss_parameter_supported"
        case requirePushedAuthorizationRequests = "require_pushed_authorization_requests"
        case clientIDMetadataDocumentSupported = "client_id_metadata_document_supported"
    }
}

/// The two documents that a complete future OAuth HTTP assembly will pass to
/// its publication gate. Keeping the pair together prevents an accidental
/// resource metadata success response without its matching server metadata.
public struct OAuthMetadataPublication: Sendable, Equatable {
    /// The document served at `/.well-known/oauth-protected-resource`.
    public let protectedResource: OAuthProtectedResourceMetadata
    /// The document served at `/.well-known/oauth-authorization-server`.
    public let authorizationServer: OAuthAuthorizationServerMetadata

    /// Creates both documents.
    public init(
        resource: URL,
        issuer: URL,
        scopesSupported: [String] = ["atproto"],
        publishesSigningKeys: Bool = false
    ) throws {
        let authorizationServer = try OAuthAuthorizationServerMetadata(
            issuer: issuer,
            scopesSupported: scopesSupported,
            publishesSigningKeys: publishesSigningKeys
        )
        protectedResource = try OAuthProtectedResourceMetadata(
            resource: resource,
            authorizationServer: authorizationServer.issuer,
            scopesSupported: scopesSupported
        )
        self.authorizationServer = authorizationServer
    }
}

/// Stable JSON rendering for metadata fixtures and future HTTP publication.
public enum OAuthMetadataRenderer {
    /// Encodes a metadata document as JSON with sorted keys.
    public static func render(_ metadata: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(metadata)
    }
}

private enum OAuthPublishedURL {
    /// The AT Protocol authorization-server issuer is an origin identifier,
    /// not a base URL. Keeping this separate from generic endpoint/resource
    /// validation prevents a path-bearing issuer from changing the advertised
    /// endpoint or the confidential-client assertion audience. An explicit
    /// HTTPS default port is also forbidden by the AT OAuth issuer profile.
    /// A trailing slash is refused too: the issuer is published as given and
    /// clients compare the `iss` response parameter to it exactly, so the one
    /// spelling must be the bare origin.
    static func validateIssuer(_ url: URL) throws -> URL {
        let validated = try validate(url, role: "issuer")
        guard let components = URLComponents(url: validated, resolvingAgainstBaseURL: false),
              components.path.isEmpty,
              components.port != 443 else {
            throw OAuthServerError.malformed("OAuth issuer URL must be an origin")
        }
        return validated
    }

    static func validate(_ url: URL, role: String) throws -> URL {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty,
              scheme == "https" || (scheme == "http" && isLoopbackHost(host)),
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              url.absoluteString.utf8.count <= 2_048 else {
            throw OAuthServerError.malformed("OAuth \(role) URL is invalid")
        }
        return url
    }

    /// `http` is tolerated only for a development server on the loopback
    /// interface, where no certificate can exist.
    static func isLoopbackHost(_ host: String) -> Bool {
        let bare = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).lowercased()
        return bare == "localhost" || bare == "127.0.0.1" || bare == "::1"
    }

    static func endpoint(issuer: URL, path: String) throws -> URL {
        guard !path.isEmpty else {
            throw OAuthServerError.malformed("OAuth endpoint URL is invalid")
        }
        let base = issuer.absoluteString.hasSuffix("/") ? String(issuer.absoluteString.dropLast()) : issuer.absoluteString
        guard let endpoint = URL(string: "\(base)/\(path)") else {
            throw OAuthServerError.malformed("OAuth endpoint URL is invalid")
        }
        return try validate(endpoint, role: "endpoint")
    }

    static func validateScopes(_ scopes: [String]) throws -> [String] {
        // ASCII first: after that, String identity is byte identity and the
        // duplicate and atproto checks below are exact.
        guard !scopes.isEmpty, scopes.count <= 64,
              scopes.allSatisfy({ scope in
                  !scope.isEmpty && scope.utf8.count <= 256
                      && scope.utf8.allSatisfy { $0 >= 0x21 && $0 <= 0x7E }
              }),
              Set(scopes).count == scopes.count,
              scopes.contains(where: { scope in
                  if case .atproto? = try? ATProtoScope.parse(scope) { return true }
                  return false
              }) else {
            throw OAuthServerError.malformed("OAuth metadata scopes are invalid")
        }
        return scopes.sorted()
    }
}
