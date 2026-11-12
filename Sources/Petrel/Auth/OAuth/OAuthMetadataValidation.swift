//
//  OAuthMetadataValidation.swift
//  Petrel
//
//  Validation of authorization-server and protected-resource metadata against
//  the atproto OAuth profile ("Server Metadata" in the OAuth specification).
//

import Foundation

/// Why a server's OAuth metadata was rejected.
///
/// Every case is a requirement of the atproto OAuth profile's "Server Metadata"
/// section (or of RFC 8414 / RFC 9728, which it builds on). A server that fails
/// one of them cannot be used to sign in.
public enum OAuthMetadataError: Error, LocalizedError, Equatable, Sendable {
    /// The two metadata documents an atproto OAuth client reads.
    public enum Document: String, Sendable {
        /// `/.well-known/oauth-protected-resource`, served by the PDS.
        case protectedResource = "oauth-protected-resource"
        /// `/.well-known/oauth-authorization-server`, served by the PDS or entryway.
        case authorizationServer = "oauth-authorization-server"
    }

    /// A URL that should be a plain `https` origin is not one. Authorization
    /// server issuers and resource identifiers must have no credentials, path,
    /// query or fragment, and no explicit default port.
    case invalidOrigin(String)
    /// The document was not served with HTTP 200. Redirects are never followed.
    case unexpectedStatus(document: Document, status: Int)
    /// The document was not served as `application/json`.
    case unexpectedContentType(document: Document, contentType: String?)
    /// The document is not a JSON object of the expected shape.
    case malformedDocument(document: Document)
    /// `issuer` differs from the origin the document was fetched from. Accepting
    /// such a document would let any host impersonate another authorization server.
    case issuerMismatch(expected: String, actual: String)
    /// `resource` differs from the origin the document was fetched from.
    case resourceMismatch(expected: String, actual: String)
    /// `authorization_servers` must list exactly one authorization server.
    case authorizationServerCount(Int)
    /// A required list does not contain a required value, e.g.
    /// `code_challenge_methods_supported` without `S256`.
    case missingRequiredValue(field: String, value: String)
    /// A list contains a value the profile forbids, e.g. `none` as a signing algorithm.
    case forbiddenValue(field: String, value: String)
    /// A boolean the profile requires to be `true` is absent or `false`.
    case requirementNotMet(field: String)
    /// An endpoint is missing or is not an `https` URL.
    case invalidEndpoint(field: String, value: String?)
    /// The authorization server lists the resources it protects and the PDS is not one of them.
    case resourceNotProtected(resource: String, issuer: String)

    /// A sentence naming the requirement the server failed.
    public var errorDescription: String? {
        switch self {
        case let .invalidOrigin(value):
            return "'\(value)' is not a valid https origin."
        case let .unexpectedStatus(document, status):
            return "The server answered HTTP \(status) for its \(document.rawValue) metadata; HTTP 200 is required."
        case let .unexpectedContentType(document, contentType):
            return "The server's \(document.rawValue) metadata has content type '\(contentType ?? "none")'; application/json is required."
        case let .malformedDocument(document):
            return "The server's \(document.rawValue) metadata is not a valid metadata document."
        case let .issuerMismatch(expected, actual):
            return "The authorization server at \(expected) claims to be '\(actual)'."
        case let .resourceMismatch(expected, actual):
            return "The resource server at \(expected) claims to be '\(actual)'."
        case let .authorizationServerCount(count):
            return "The resource server lists \(count) authorization servers; exactly one is required."
        case let .missingRequiredValue(field, value):
            return "The authorization server's '\(field)' does not include '\(value)'."
        case let .forbiddenValue(field, value):
            return "The authorization server's '\(field)' must not include '\(value)'."
        case let .requirementNotMet(field):
            return "The authorization server does not declare '\(field)' as true."
        case let .invalidEndpoint(field, value):
            return "The authorization server's '\(field)' ('\(value ?? "missing")') is not a valid https URL."
        case let .resourceNotProtected(resource, issuer):
            return "The authorization server \(issuer) does not list \(resource) among the resources it protects."
        }
    }
}

/// How this client authenticates to the authorization server's token endpoint.
/// Metadata validation requires the server to support the method in use.
enum OAuthClientAuthenticationMethod: String, Sendable {
    /// A public client: no client authentication.
    case none
    /// A confidential client: a signed JWT client assertion.
    case privateKeyJWT = "private_key_jwt"
}

/// Origin handling shared by issuer and resource validation.
enum OAuthOrigin {
    /// Hosts for which cleartext `http` is tolerated, matching the transport's own
    /// loopback exception. Everything else must be `https`.
    private static func isLoopback(_ host: String) -> Bool {
        host == "localhost" || host == "127.0.0.1" || host == "[::1]" || host == "::1"
    }

    /// The canonical origin (`scheme://host[:port]`, lowercased, default port
    /// dropped) of `url`, or `nil` when it has no usable scheme and host.
    static func canonical(of url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(), !host.isEmpty,
              scheme == "https" || (scheme == "http" && isLoopback(host))
        else { return nil }
        let renderedHost = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
        let defaultPort = scheme == "https" ? 443 : 80
        if let port = components.port, port != defaultPort {
            return "\(scheme)://\(renderedHost):\(port)"
        }
        return "\(scheme)://\(renderedHost)"
    }

    /// Validates that `value` is already written as a canonical origin: `https`
    /// (or loopback `http`), no credentials, path, query or fragment, no trailing
    /// slash and no explicit default port.
    /// - Returns: `value`, unchanged.
    @discardableResult
    static func requireCanonical(_ value: String) throws -> String {
        guard let url = URL(string: value),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.path.isEmpty,
              let canonical = canonical(of: url),
              canonical == value
        else {
            throw OAuthMetadataError.invalidOrigin(value)
        }
        return value
    }

    /// Whether `value` is an absolute `https` URL (or loopback `http`) without
    /// credentials or a fragment — the shape required of an OAuth endpoint.
    static func isEndpointURL(_ value: String) -> Bool {
        guard let url = URL(string: value),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.user == nil, components.password == nil,
              components.fragment == nil,
              canonical(of: url) != nil
        else { return false }
        return true
    }
}

extension AuthorizationServerMetadata {
    /// Checks this document against the atproto OAuth profile.
    ///
    /// - Parameters:
    ///   - issuer: The canonical origin the document was fetched from. `issuer`
    ///     must equal it exactly (RFC 8414 §3.3); this is the defence against one
    ///     host presenting itself as another authorization server.
    ///   - clientAuthentication: The token-endpoint authentication method this
    ///     client uses, which the server must support.
    /// - Throws: ``OAuthMetadataError`` naming the first requirement that failed.
    func validate(
        fetchedFrom issuer: String,
        clientAuthentication: OAuthClientAuthenticationMethod
    ) throws {
        try OAuthOrigin.requireCanonical(self.issuer)
        guard self.issuer == issuer else {
            throw OAuthMetadataError.issuerMismatch(expected: issuer, actual: self.issuer)
        }

        // The browser is sent to `authorization_endpoint` and credentials to the
        // others, so none of them may be anything but an https URL.
        let endpoints: [(String, String?)] = [
            ("authorization_endpoint", authorizationEndpoint),
            ("token_endpoint", tokenEndpoint),
            ("pushed_authorization_request_endpoint", pushedAuthorizationRequestEndpoint),
        ]
        for (field, value) in endpoints {
            guard let value, OAuthOrigin.isEndpointURL(value) else {
                throw OAuthMetadataError.invalidEndpoint(field: field, value: value)
            }
        }
        if let revocationEndpoint, !OAuthOrigin.isEndpointURL(revocationEndpoint) {
            throw OAuthMetadataError.invalidEndpoint(field: "revocation_endpoint", value: revocationEndpoint)
        }

        try Self.require("code", in: responseTypesSupported, field: "response_types_supported")
        try Self.require("authorization_code", in: grantTypesSupported, field: "grant_types_supported")
        try Self.require("refresh_token", in: grantTypesSupported, field: "grant_types_supported")
        try Self.require("S256", in: codeChallengeMethodsSupported, field: "code_challenge_methods_supported")
        try Self.require(
            clientAuthentication.rawValue,
            in: tokenEndpointAuthMethodsSupported,
            field: "token_endpoint_auth_methods_supported"
        )
        if tokenEndpointAuthSigningAlgValuesSupported?.contains("none") == true {
            throw OAuthMetadataError.forbiddenValue(
                field: "token_endpoint_auth_signing_alg_values_supported", value: "none"
            )
        }
        if clientAuthentication == .privateKeyJWT {
            try Self.require(
                "ES256",
                in: tokenEndpointAuthSigningAlgValuesSupported,
                field: "token_endpoint_auth_signing_alg_values_supported"
            )
        }
        try Self.require("atproto", in: scopesSupported, field: "scopes_supported")
        try Self.require("ES256", in: dpopSigningAlgValuesSupported, field: "dpop_signing_alg_values_supported")

        guard authorizationResponseIssParameterSupported == true else {
            throw OAuthMetadataError.requirementNotMet(field: "authorization_response_iss_parameter_supported")
        }
        guard requirePushedAuthorizationRequests == true else {
            throw OAuthMetadataError.requirementNotMet(field: "require_pushed_authorization_requests")
        }
        guard clientIdMetadataDocumentSupported == true else {
            throw OAuthMetadataError.requirementNotMet(field: "client_id_metadata_document_supported")
        }
        // Optional, defaults to true, but must not be false.
        guard requireRequestUriRegistration != false else {
            throw OAuthMetadataError.requirementNotMet(field: "require_request_uri_registration")
        }
    }

    private static func require(_ value: String, in list: [String]?, field: String) throws {
        guard let list, list.contains(value) else {
            throw OAuthMetadataError.missingRequiredValue(field: field, value: value)
        }
    }
}

extension ProtectedResourceMetadata {
    /// Checks this document against the atproto OAuth profile and returns the
    /// issuer of the single authorization server it names.
    ///
    /// - Parameter origin: The canonical origin the document was fetched from;
    ///   `resource` must equal it (RFC 9728 §3.3).
    /// - Returns: The authorization server's issuer, verified to be a canonical origin.
    /// - Throws: ``OAuthMetadataError`` naming the first requirement that failed.
    func validate(forResourceAt origin: String) throws -> String {
        let declared = resource.absoluteString
        guard declared == origin else {
            throw OAuthMetadataError.resourceMismatch(expected: origin, actual: declared)
        }
        guard authorizationServers.count == 1, let server = authorizationServers.first else {
            throw OAuthMetadataError.authorizationServerCount(authorizationServers.count)
        }
        return try OAuthOrigin.requireCanonical(server.absoluteString)
    }
}
