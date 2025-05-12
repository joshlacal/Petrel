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
    
    /// Initializes a new OAuthConfig instance.
    /// - Parameters:
    ///   - clientId: The client ID.
    ///   - redirectUri: The redirect URI.
    ///   - scope: The scope of access.
    public init(clientId: String, redirectUri: String, scope: String) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.scope = scope
    }
    
    /// Extracts the scheme from the redirect URI.
    public var redirectUriScheme: String {
        URL(string: redirectUri)?.scheme ?? ""
    }
}

// Alias for backward compatibility
public typealias OAuthConfiguration = OAuthConfig
