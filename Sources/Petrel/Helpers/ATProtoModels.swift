//
//  ATProtoModels.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/22/2025.
//

#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation

public struct AuthorizationServerMetadata: Codable, Sendable, Hashable {
    let issuer: String
    let scopesSupported: [String]
    let subjectTypesSupported: [String]
    let responseTypesSupported: [String]
    let responseModesSupported: [String]
    let grantTypesSupported: [String]
    let codeChallengeMethodsSupported: [String]
    let uiLocalesSupported: [String]
    let displayValuesSupported: [String]
    let authorizationResponseIssParameterSupported: Bool
    let requestObjectSigningAlgValuesSupported: [String]
    let requestObjectEncryptionAlgValuesSupported: [String]
    let requestObjectEncryptionEncValuesSupported: [String]
    let requestParameterSupported: Bool
    let requestUriParameterSupported: Bool
    let requireRequestUriRegistration: Bool
    let jwksUri: String
    let authorizationEndpoint: String
    let tokenEndpoint: String
    let tokenEndpointAuthMethodsSupported: [String]
    let tokenEndpointAuthSigningAlgValuesSupported: [String]
    let revocationEndpoint: String
    let introspectionEndpoint: String
    let pushedAuthorizationRequestEndpoint: String
    let requirePushedAuthorizationRequests: Bool
    let dpopSigningAlgValuesSupported: [String]
    let clientIdMetadataDocumentSupported: Bool

    enum CodingKeys: String, CodingKey {
        case issuer
        case scopesSupported = "scopes_supported"
        case subjectTypesSupported = "subject_types_supported"
        case responseTypesSupported = "response_types_supported"
        case responseModesSupported = "response_modes_supported"
        case grantTypesSupported = "grant_types_supported"
        case codeChallengeMethodsSupported = "code_challenge_methods_supported"
        case uiLocalesSupported = "ui_locales_supported"
        case displayValuesSupported = "display_values_supported"
        case authorizationResponseIssParameterSupported =
            "authorization_response_iss_parameter_supported"
        case requestObjectSigningAlgValuesSupported = "request_object_signing_alg_values_supported"
        case requestObjectEncryptionAlgValuesSupported =
            "request_object_encryption_alg_values_supported"
        case requestObjectEncryptionEncValuesSupported =
            "request_object_encryption_enc_values_supported"
        case requestParameterSupported = "request_parameter_supported"
        case requestUriParameterSupported = "request_uri_parameter_supported"
        case requireRequestUriRegistration = "require_request_uri_registration"
        case jwksUri = "jwks_uri"
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case tokenEndpointAuthMethodsSupported = "token_endpoint_auth_methods_supported"
        case tokenEndpointAuthSigningAlgValuesSupported =
            "token_endpoint_auth_signing_alg_values_supported"
        case revocationEndpoint = "revocation_endpoint"
        case introspectionEndpoint = "introspection_endpoint"
        case pushedAuthorizationRequestEndpoint = "pushed_authorization_request_endpoint"
        case requirePushedAuthorizationRequests = "require_pushed_authorization_requests"
        case dpopSigningAlgValuesSupported = "dpop_signing_alg_values_supported"
        case clientIdMetadataDocumentSupported = "client_id_metadata_document_supported"
    }
}

// MARK: - ProtectedResourceMetadata Structure

public struct ProtectedResourceMetadata: Codable, Sendable, Hashable {
    let resource: URL
    let authorizationServers: [URL]
    let scopesSupported: [String]
    let bearerMethodsSupported: [String]
    let resourceDocumentation: URL

    enum CodingKeys: String, CodingKey {
        case resource
        case authorizationServers = "authorization_servers"
        case scopesSupported = "scopes_supported"
        case bearerMethodsSupported = "bearer_methods_supported"
        case resourceDocumentation = "resource_documentation"
    }
}

// MARK: - Account Model

/// Represents a user account in the AT Protocol
public struct Account: Codable, Equatable, Sendable {
    public static func == (lhs: Account, rhs: Account) -> Bool {
        lhs.did == rhs.did && lhs.handle == rhs.handle && lhs.pdsURL == rhs.pdsURL
            && lhs.protectedResourceMetadata == rhs.protectedResourceMetadata
            && lhs.authorizationServerMetadata == rhs.authorizationServerMetadata
            && lhs.bskyAppViewDID == rhs.bskyAppViewDID
            && lhs.bskyChatDID == rhs.bskyChatDID
    }

    /// The decentralized identifier for the account
    public let did: String

    /// The user's handle (username)
    public var handle: String?

    /// The URL of the user's Personal Data Server
    public var pdsURL: URL

    /// Metadata about the protected resource (PDS)
    var protectedResourceMetadata: ProtectedResourceMetadata?

    /// Metadata about the authorization server
    var authorizationServerMetadata: AuthorizationServerMetadata?
    
    /// Custom AppView service DID for app.bsky namespace (defaults to official Bluesky AppView)
    public var bskyAppViewDID: String
    
    /// Custom Chat service DID for chat.bsky namespace (defaults to official Bluesky Chat)
    public var bskyChatDID: String

    public init(
        did: String,
        handle: String? = nil,
        pdsURL: URL,
        protectedResourceMetadata: ProtectedResourceMetadata? = nil,
        authorizationServerMetadata: AuthorizationServerMetadata? = nil,
        bskyAppViewDID: String = "did:web:api.bsky.app#bsky_appview",
        bskyChatDID: String = "did:web:api.bsky.chat#bsky_chat"
    ) {
        self.did = did
        self.handle = handle
        self.pdsURL = pdsURL
        self.protectedResourceMetadata = protectedResourceMetadata
        self.authorizationServerMetadata = authorizationServerMetadata
        self.bskyAppViewDID = bskyAppViewDID
        self.bskyChatDID = bskyChatDID
    }
}

// MARK: - Session Model

/// Represents an authentication session
public struct Session: Codable, Equatable, Sendable {
    /// The access token used for authenticated requests
    public let accessToken: String

    /// The refresh token used to obtain new tokens
    public let refreshToken: String?

    /// When the session was created
    public let createdAt: Date

    /// The number of seconds until the token expires
    public let expiresIn: TimeInterval

    /// The type of token (bearer or DPoP)
    public let tokenType: TokenType

    /// The DID associated with this session
    public let did: String

    /// Whether the token has expired
    public var isExpired: Bool {
        Date() > createdAt.addingTimeInterval(expiresIn)
    }

    /// Whether the token is expiring soon (within 15 minutes)
    /// Increased from 5 to 15 minutes to handle server clock skew and shorter-than-expected token lifetimes
    public var isExpiringSoon: Bool {
        Date() > createdAt.addingTimeInterval(expiresIn - 900)
    }

    public init(
        accessToken: String,
        refreshToken: String?,
        createdAt: Date,
        expiresIn: TimeInterval,
        tokenType: TokenType,
        did: String
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.createdAt = createdAt
        self.expiresIn = expiresIn
        self.tokenType = tokenType
        self.did = did
    }
}

/// Token types supported by the AT Protocol
public enum TokenType: String, Codable, Equatable, Sendable {
    case bearer
    case dpop
}

// MARK: - OAuth State Model

/// Represents the state during OAuth authorization
public struct OAuthState: Codable, Equatable, Sendable {
    /// The state token used to prevent CSRF attacks
    public let stateToken: String

    /// The code verifier for PKCE
    public let codeVerifier: String

    /// When the state was created
    public let createdAt: Date

    /// The initial identifier (handle) used to start the OAuth flow
    public let initialIdentifier: String?

    /// The target PDS URL for the OAuth flow
    public let targetPDSURL: URL?

    /// The ephemeral DPoP key used for this OAuth session
    /// This ensures the same key is used throughout the entire auth flow
    public var ephemeralDPoPKey: Data?

    /// The DPoP nonce received from the PAR response
    /// Used for the subsequent token exchange request
    public var parResponseNonce: String?
    
    /// Custom AppView service DID to use for this account
    public let bskyAppViewDID: String?
    
    /// Custom Chat service DID to use for this account
    public let bskyChatDID: String?

    public init(
        stateToken: String,
        codeVerifier: String,
        createdAt: Date,
        initialIdentifier: String? = nil,
        targetPDSURL: URL? = nil,
        ephemeralDPoPKey: Data? = nil,
        parResponseNonce: String? = nil,
        bskyAppViewDID: String? = nil,
        bskyChatDID: String? = nil
    ) {
        self.stateToken = stateToken
        self.codeVerifier = codeVerifier
        self.createdAt = createdAt
        self.initialIdentifier = initialIdentifier
        self.targetPDSURL = targetPDSURL
        self.ephemeralDPoPKey = ephemeralDPoPKey
        self.parResponseNonce = parResponseNonce
        self.bskyAppViewDID = bskyAppViewDID
        self.bskyChatDID = bskyChatDID
    }
}

// MARK: - DPoP Proof Type

/// Types of DPoP proofs that can be generated
public enum DPoPProofType {
    /// For pushed authorization requests
    case authorization

    /// For token endpoint requests
    case tokenRequest

    /// For API resource access
    case resourceAccess

    /// For token refresh requests
    case tokenRefresh
}
