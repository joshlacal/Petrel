//
//  OAuthConfig.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/22/2025.
//

import Foundation

/// Configuration for OAuth authentication.
public struct OAuthConfig: Sendable {
    /// The client ID used to identify the application: the `https` URL of its
    /// client metadata document, or an `http://localhost` development client ID.
    public let clientId: String

    /// The redirect URI that will receive the authorization code.
    public let redirectUri: String

    /// The scope requested by default, as a space-delimited string. It must
    /// include `atproto`. Build it with `ATProtoScopeSet` (module
    /// `PetrelOAuthScopes`, re-exported by Petrel) to avoid hand-written scope strings.
    public let scope: String

    /// Retained for source compatibility; no longer consulted.
    ///
    /// The atproto OAuth profile requires every authorization server to return
    /// the `iss` parameter (RFC 9207), and Petrel refuses servers whose metadata
    /// does not declare it, so the callback's `iss` is always required and
    /// always compared with the issuer the flow was started against.
    public let requireIssInCallback: Bool

    /// When true, an identifier-first flow re-fetches the protected resource
    /// metadata of the account's PDS after the token exchange and requires it to
    /// name the authorization server used for the flow. Server-first flows
    /// always perform this check, whatever the value. Defaults to `true`.
    public let enforcePDSAuthorizationBinding: Bool

    /// Initializes a new OAuthConfig instance.
    /// - Parameters:
    ///   - clientId: The client ID.
    ///   - redirectUri: The redirect URI.
    ///   - scope: The scope of access.
    ///   - requireIssInCallback: Ignored; the callback issuer is always verified.
    ///   - enforcePDSAuthorizationBinding: Whether the resolved PDS must authorize the server used for the flow.
    public init(
        clientId: String,
        redirectUri: String,
        scope: String,
        requireIssInCallback: Bool = true,
        enforcePDSAuthorizationBinding: Bool = true
    ) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.scope = scope
        self.requireIssInCallback = requireIssInCallback
        self.enforcePDSAuthorizationBinding = enforcePDSAuthorizationBinding
    }

    /// Extracts the scheme from the redirect URI.
    public var redirectUriScheme: String {
        URL(string: redirectUri)?.scheme ?? ""
    }
}

/// Alias for backward compatibility
public typealias OAuthConfiguration = OAuthConfig

/// A client configuration that the atproto OAuth profile does not allow.
public enum OAuthConfigurationError: Error, LocalizedError, Equatable, Sendable {
    /// The requested scope does not include `atproto`, which every atproto
    /// OAuth session requires.
    case scopeMissingAtproto(String)
    /// The client ID is neither an `https` URL without a port nor an
    /// `http://localhost` development client ID.
    case invalidClientID(String)
    /// The redirect URI is not one the profile allows for this client ID.
    case invalidRedirectURI(String)
    /// The client's authentication mode does not offer the operation — for
    /// example an OAuth flow on an app-password client, or any sign-in on a
    /// client created without authentication.
    case unsupportedByAuthMode

    public var errorDescription: String? {
        switch self {
        case let .scopeMissingAtproto(scope):
            return "The OAuth scope '\(scope)' does not include 'atproto'."
        case let .invalidClientID(clientID):
            return "'\(clientID)' is not a valid atproto OAuth client ID: it must be an https URL without a port, or http://localhost for development."
        case let .invalidRedirectURI(redirectURI):
            return "'\(redirectURI)' is not a valid redirect URI for this client ID."
        case .unsupportedByAuthMode:
            return "This client's authentication mode does not support the operation."
        }
    }
}

public extension OAuthConfig {
    // MARK: - Typed scopes

    /// Creates a configuration from typed scopes.
    /// - Parameters:
    ///   - clientId: The client ID.
    ///   - redirectUri: The redirect URI.
    ///   - scopes: The scopes requested by default; must include `.atproto`.
    init(clientId: String, redirectUri: String, scopes: ATProtoScopeSet) {
        self.init(clientId: clientId, redirectUri: redirectUri, scope: scopes.scopeString)
    }

    /// The configured scope as typed scopes. Tokens Petrel does not recognise
    /// are listed in the set's `unrecognized` and grant nothing.
    var scopes: ATProtoScopeSet {
        ATProtoScopeSet(scope: scope)
    }

    // MARK: - Localhost development client

    /// Whether this is a localhost development client (`http://localhost` client ID).
    var isLoopbackClient: Bool {
        guard let components = URLComponents(string: clientId) else { return false }
        return components.scheme == "http" && components.host == "localhost"
    }

    /// A configuration for the profile's "Localhost Client Development"
    /// exception: no client metadata document has to be published; the
    /// authorization server derives one from the client ID.
    ///
    /// The client ID is `http://localhost` with the redirect URI and scope as
    /// query parameters, and the redirect URI is `http://127.0.0.1:<port><path>`.
    /// Authorization servers match the redirect path but ignore its port, so any
    /// free local port can be used. Works as a public client only, and only with
    /// authorization servers that support the exception.
    ///
    /// - Parameters:
    ///   - port: The local port the app listens on for the redirect.
    ///   - path: The redirect path, starting with `/`.
    ///   - scope: The scope to request and declare; must include `atproto`.
    static func loopback(port: Int, path: String = "/callback", scope: String = "atproto") -> OAuthConfig {
        let redirectURI = "http://127.0.0.1:\(port)\(path.hasPrefix("/") ? path : "/" + path)"
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+;:/?#")
        let encodedRedirect = redirectURI.addingPercentEncoding(withAllowedCharacters: allowed) ?? redirectURI
        let encodedScope = scope.addingPercentEncoding(withAllowedCharacters: allowed) ?? scope
        return OAuthConfig(
            clientId: "http://localhost?redirect_uri=\(encodedRedirect)&scope=\(encodedScope)",
            redirectUri: redirectURI,
            scope: scope
        )
    }

    // MARK: - Validation

    /// Checks the configuration against the atproto OAuth profile's client rules:
    ///
    /// - the scope includes `atproto`;
    /// - the client ID is an `https` URL without a port, or `http://localhost`
    ///   (no port, empty path) for development;
    /// - the redirect URI is an `https` URL, a loopback `http://127.0.0.1` /
    ///   `http://[::1]` URL (development clients), or a custom scheme that is
    ///   the client ID's hostname in reverse-domain order followed by `:/` and a path.
    ///
    /// Authorization servers enforce the same rules; validating up front turns
    /// a rejected pushed authorization request into a precise local error.
    func validate() throws {
        guard ATProtoScopeSet(scope: scope).includesAtproto else {
            throw OAuthConfigurationError.scopeMissingAtproto(scope)
        }

        guard let client = URLComponents(string: clientId), let clientHost = client.host?.lowercased(),
              client.user == nil, client.password == nil, client.fragment == nil, client.port == nil
        else {
            throw OAuthConfigurationError.invalidClientID(clientId)
        }
        let isLoopback = client.scheme == "http" && clientHost == "localhost"
        if isLoopback {
            guard client.path.isEmpty || client.path == "/" else {
                throw OAuthConfigurationError.invalidClientID(clientId)
            }
        } else {
            guard client.scheme == "https", client.query == nil else {
                throw OAuthConfigurationError.invalidClientID(clientId)
            }
        }

        guard let redirect = URLComponents(string: redirectUri), let scheme = redirect.scheme?.lowercased(),
              redirect.fragment == nil
        else {
            throw OAuthConfigurationError.invalidRedirectURI(redirectUri)
        }
        switch scheme {
        case "https":
            guard !isLoopback, let host = redirect.host, !host.isEmpty, redirect.port != 443 else {
                throw OAuthConfigurationError.invalidRedirectURI(redirectUri)
            }
        case "http":
            // Only the localhost development exception may use cleartext loopback redirects.
            let host = redirect.host?.lowercased()
            guard isLoopback, host == "127.0.0.1" || host == "[::1]" || host == "::1" else {
                throw OAuthConfigurationError.invalidRedirectURI(redirectUri)
            }
        default:
            // A native client's custom scheme: the client ID hostname reversed,
            // then exactly ":/" and a path.
            let reversedHost = clientHost.split(separator: ".").reversed().joined(separator: ".")
            guard !isLoopback, scheme == reversedHost,
                  redirectUri.dropFirst(scheme.count).hasPrefix(":/"),
                  !redirectUri.dropFirst(scheme.count).hasPrefix("://"),
                  redirect.host == nil
            else {
                throw OAuthConfigurationError.invalidRedirectURI(redirectUri)
            }
        }
    }

    // MARK: - Client metadata document

    /// Builds the client metadata document this configuration must be published
    /// with, at the URL that is the client ID.
    ///
    /// The result contains every member the atproto OAuth profile requires
    /// (`client_id`, `grant_types`, `scope`, `response_types`, `redirect_uris`,
    /// `dpop_bound_access_tokens`) plus the client-authentication members for the
    /// chosen client type. Serialise it with `JSONSerialization` and serve it as
    /// `application/json` with HTTP 200.
    ///
    /// - Parameters:
    ///   - applicationType: `native` for apps using a custom-scheme redirect, `web` otherwise.
    ///   - clientName: A human-readable name, shown only for clients the server trusts.
    ///   - additionalRedirectURIs: Further redirect URIs to declare.
    ///   - confidentialKeys: Client-authentication keys. When non-empty the
    ///     document declares a confidential client (`private_key_jwt`, `ES256`)
    ///     and publishes the keys' public halves in `jwks`; when empty it
    ///     declares a public client (`none`).
    /// - Throws: ``OAuthConfigurationError`` when the configuration is not valid
    ///   (see ``validate()``).
    func clientMetadataDocument(
        applicationType: ApplicationType,
        clientName: String? = nil,
        additionalRedirectURIs: [String] = [],
        confidentialKeys: [OAuthClientAssertionKey] = []
    ) throws -> [String: Any] {
        try validate()
        var document: [String: Any] = [
            "client_id": clientId,
            "application_type": applicationType.rawValue,
            "grant_types": ["authorization_code", "refresh_token"],
            "scope": scope,
            "response_types": ["code"],
            "redirect_uris": [redirectUri] + additionalRedirectURIs,
            "dpop_bound_access_tokens": true,
        ]
        if let clientName {
            document["client_name"] = clientName
        }
        if confidentialKeys.isEmpty {
            document["token_endpoint_auth_method"] = "none"
        } else {
            document["token_endpoint_auth_method"] = "private_key_jwt"
            document["token_endpoint_auth_signing_alg"] = "ES256"
            document["jwks"] = ["keys": confidentialKeys.map(\.publicJWK)]
        }
        return document
    }

    /// The `application_type` of a client metadata document.
    enum ApplicationType: String, Sendable {
        /// A web service or browser app; redirect URIs are `https` URLs.
        case web
        /// A mobile or desktop app; redirect URIs may use a custom scheme.
        case native
    }
}
