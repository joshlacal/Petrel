//
//  OAuthConfig.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/22/2025.
//

import Foundation

/// Configuration for OAuth authentication.
public struct OAuthConfig: Sendable {
    /// The client ID used to identify the application.
    public let clientId: String

    /// The redirect URI that will receive the authorization code.
    public let redirectUri: String

    /// The scope of access being requested.
    public let scope: String

    /// When true and the authorization server metadata declares support for `authorization_response_iss_parameter_supported`,
    /// require that the OAuth callback contain an `iss` query parameter matching the server issuer.
    /// Defaults to `false` to avoid breaking existing integrations; enable for stricter verification.
    public let requireIssInCallback: Bool

    /// When true, after exchanging the code and resolving the account DID to its PDS URL, verify that the PDS's
    /// protected resource metadata lists the same authorization server `issuer` used for the flow. If it does not,
    /// the callback fails. Defaults to `false` for compatibility; enable to mirror stricter security checks.
    public let enforcePDSAuthorizationBinding: Bool

    /// Initializes a new OAuthConfig instance.
    /// - Parameters:
    ///   - clientId: The client ID.
    ///   - redirectUri: The redirect URI.
    ///   - scope: The scope of access.
    public init(
        clientId: String,
        redirectUri: String,
        scope: String,
        requireIssInCallback: Bool = false,
        enforcePDSAuthorizationBinding: Bool = false
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
