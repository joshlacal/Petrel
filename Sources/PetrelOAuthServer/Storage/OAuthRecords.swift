import Foundation

/// The confidential-client key a session is bound to for its whole lifetime.
///
/// A refresh must be authenticated with this same key and algorithm, and the
/// session is revoked when the key leaves the client's published JWKS.
public struct OAuthClientKeyBinding: Sendable, Equatable, Hashable, Codable {
    /// The JWKS `kid` the client assertion named.
    public let keyID: String
    /// The assertion's signature algorithm.
    public let algorithm: String
    /// The RFC 7638 thumbprint of the key.
    public let thumbprint: String

    /// Creates a binding.
    public init(keyID: String, algorithm: String, thumbprint: String) {
        self.keyID = keyID
        self.algorithm = algorithm
        self.thumbprint = thumbprint
    }
}

/// Everything an authorization is bound to, fixed when the request is pushed
/// and carried unchanged through the code and every token of the session.
public struct OAuthGrantBinding: Sendable, Equatable, Hashable, Codable {
    /// The authorization server's issuer identifier.
    public let issuer: String
    /// The client the grant belongs to.
    public let clientID: String
    /// The exact redirect URI of the authorization request.
    public let redirectURI: String
    /// The scopes exactly as the client requested them, `include:` scopes
    /// unexpanded. Returned in the token response and the baseline every
    /// refresh re-derives the effective grant from.
    public let requestedScopes: Set<String>
    /// The effective grant resource servers enforce: ``requestedScopes`` with
    /// each `include:` replaced by the permissions it expands to.
    ///
    /// Members of both sets are RFC 6749 scope-tokens (ASCII; validated when
    /// the request was pushed, or produced by `IncludedPermission.scopeString()`,
    /// which parses back to the permission), so `String` identity here is byte
    /// identity. What a set grants is decided by parsing it
    /// (`ScopePermissions`), never by comparing strings.
    public let grantedScopes: Set<String>
    /// The thumbprint of the DPoP key every token of the session is bound to.
    public let dpopJKT: String
    /// The confidential client's key, or `nil` for a public client.
    public let clientKey: OAuthClientKeyBinding?
    /// Whether the client declared the `refresh_token` grant.
    public let refreshTokenAllowed: Bool

    /// Creates a binding.
    public init(
        issuer: String,
        clientID: String,
        redirectURI: String,
        requestedScopes: Set<String>,
        grantedScopes: Set<String>? = nil,
        dpopJKT: String,
        clientKey: OAuthClientKeyBinding? = nil,
        refreshTokenAllowed: Bool = true
    ) {
        self.issuer = issuer
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.requestedScopes = requestedScopes
        self.grantedScopes = grantedScopes ?? requestedScopes
        self.dpopJKT = dpopJKT
        self.clientKey = clientKey
        self.refreshTokenAllowed = refreshTokenAllowed
    }

    /// A copy whose effective grant is `scopes`. The requested side is the
    /// client's own frozen input and never changes.
    public func withGrantedScopes(_ scopes: Set<String>) -> OAuthGrantBinding {
        OAuthGrantBinding(
            issuer: issuer,
            clientID: clientID,
            redirectURI: redirectURI,
            requestedScopes: requestedScopes,
            grantedScopes: scopes,
            dpopJKT: dpopJKT,
            clientKey: clientKey,
            refreshTokenAllowed: refreshTokenAllowed
        )
    }
}

/// How the authorization response parameters are returned to the client.
public enum OAuthResponseMode: String, Sendable, Equatable, Hashable, Codable {
    /// In the redirect URI's query. The default, used by server-side and
    /// native clients.
    case query
    /// In the redirect URI's fragment, which never reaches the client's own
    /// server. Used by browser-based clients.
    case fragment
}

/// A pushed authorization request (RFC 9126), keyed by a digest of its opaque
/// `request_uri`. The raw `request_uri` is never stored.
public struct OAuthPushedAuthorizationRequest: Sendable, Equatable, Codable {
    /// The keyed digest of the `request_uri`.
    public let requestDigest: Data
    /// What the request is bound to.
    public let binding: OAuthGrantBinding
    /// The client's `state`, returned verbatim on the redirect.
    public let state: String
    /// The PKCE S256 `code_challenge`.
    public let codeChallenge: String
    /// The client's `login_hint` (a handle or DID), when it sent one.
    public let loginHint: String?
    /// Where the response parameters go on the redirect.
    public let responseMode: OAuthResponseMode
    /// When the request stops being usable.
    public let expiresAt: Date

    /// Creates a request record.
    public init(
        requestDigest: Data,
        binding: OAuthGrantBinding,
        state: String,
        codeChallenge: String,
        loginHint: String? = nil,
        responseMode: OAuthResponseMode = .query,
        expiresAt: Date
    ) {
        self.responseMode = responseMode
        self.requestDigest = requestDigest
        self.binding = binding
        self.state = state
        self.codeChallenge = codeChallenge
        self.loginHint = loginHint
        self.expiresAt = expiresAt
    }
}

/// An authorization code, keyed by a digest; raw codes never cross the storage
/// boundary. A consumed code remains as a replay sentinel until its session
/// can no longer be valid.
public struct OAuthAuthorizationCode: Sendable, Equatable, Codable {
    /// The keyed digest of the code.
    public let codeDigest: Data
    /// The session a successful exchange activates.
    public let sessionID: UUID
    /// The account DID that approved the request.
    public let subject: String
    /// What the code is bound to.
    public let binding: OAuthGrantBinding
    /// The PKCE S256 challenge the verifier must match.
    public let codeChallenge: String
    /// When the code stops being redeemable.
    public let expiresAt: Date
    /// When the code was redeemed, if it was.
    public var consumedAt: Date?

    /// Creates a code record.
    public init(
        codeDigest: Data,
        sessionID: UUID,
        subject: String,
        binding: OAuthGrantBinding,
        codeChallenge: String,
        expiresAt: Date,
        consumedAt: Date? = nil
    ) {
        self.codeDigest = codeDigest
        self.sessionID = sessionID
        self.subject = subject
        self.binding = binding
        self.codeChallenge = codeChallenge
        self.expiresAt = expiresAt
        self.consumedAt = consumedAt
    }
}

/// Keyed digests of the tokens issued by one grant or refresh. Raw bearer
/// strings exist only in the response to the client.
public struct OAuthIssuedTokenDigests: Sendable, Equatable, Codable {
    /// The digest (or, for a signed token, the token identifier digest) of the
    /// access token.
    public let accessTokenDigest: Data
    /// When the access token expires.
    public let accessExpiresAt: Date
    /// The digest of the refresh token, or `nil` when the client did not
    /// declare the `refresh_token` grant and so receives none.
    public let refreshTokenDigest: Data?
    /// When the refresh token expires.
    public let refreshExpiresAt: Date?

    /// Creates a digest set.
    public init(
        accessTokenDigest: Data,
        accessExpiresAt: Date,
        refreshTokenDigest: Data? = nil,
        refreshExpiresAt: Date? = nil
    ) {
        self.accessTokenDigest = accessTokenDigest
        self.accessExpiresAt = accessExpiresAt
        self.refreshTokenDigest = refreshTokenDigest
        self.refreshExpiresAt = refreshExpiresAt
    }
}

/// One OAuth session: a user's approval of one client on one device, and the
/// chain of tokens issued under it (a "token family").
///
/// A session is created together with its authorization code, before any token
/// exists, so that a later replay of that code can revoke everything the first
/// redemption produced.
public struct OAuthSession: Sendable, Equatable, Codable {
    /// The session identifier.
    public let sessionID: UUID
    /// The account DID.
    public let subject: String
    /// What the session is bound to. `grantedScopes` may change on refresh.
    public var binding: OAuthGrantBinding
    /// When the user approved the request.
    public let createdAt: Date
    /// The hard end of the session, or `nil` when it is unlimited (permitted
    /// for confidential clients only).
    public let expiresAt: Date?
    /// When the session was revoked, if it was.
    public var revokedAt: Date?
    /// The current tokens, or `nil` until the code is redeemed.
    public var tokens: OAuthIssuedTokenDigests?

    /// Creates a session.
    public init(
        sessionID: UUID,
        subject: String,
        binding: OAuthGrantBinding,
        createdAt: Date,
        expiresAt: Date?,
        revokedAt: Date? = nil,
        tokens: OAuthIssuedTokenDigests? = nil
    ) {
        self.sessionID = sessionID
        self.subject = subject
        self.binding = binding
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.revokedAt = revokedAt
        self.tokens = tokens
    }

    /// True when the session is neither revoked nor past its hard end.
    public func isActive(at now: Date) -> Bool {
        revokedAt == nil && (expiresAt.map { $0 > now } ?? true)
    }
}

/// A validated client metadata document (and JWKS) cached until `expiresAt`.
/// The document is public metadata; no client secret belongs here.
public struct OAuthCachedClientMetadata: Sendable, Equatable, Codable {
    /// The `client_id` the document was fetched from.
    public let clientID: String
    /// The encoded ``OAuthResolvedClientMetadata``.
    public let document: Data
    /// When the entry must be refetched.
    public let expiresAt: Date

    /// Creates a cache entry.
    public init(clientID: String, document: Data, expiresAt: Date) {
        self.clientID = clientID
        self.document = document
        self.expiresAt = expiresAt
    }
}

/// The separate single-use namespaces the server keeps. A value claimed in one
/// never collides with the same bytes in another.
public enum OAuthReplayNamespace: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    /// DPoP proof `jti` values.
    case dpopProof = "dpop-jti"
    /// Client assertion `jti` values, scoped per client.
    case clientAssertion = "client-assertion-jti"
    /// PKCE `code_challenge` values, which must not be reused across sessions.
    case codeChallenge = "code-challenge"
    /// Client `state` values of live authorization requests.
    case state
}

/// One account signed in on a browser ("device"), for account selection.
public struct OAuthDeviceAccount: Sendable, Equatable, Codable {
    /// The account DID.
    public let subject: String
    /// When the user last authenticated as this account on this device.
    public let authenticatedAt: Date

    /// Creates a device account entry.
    public init(subject: String, authenticatedAt: Date) {
        self.subject = subject
        self.authenticatedAt = authenticatedAt
    }
}

/// A cached Lexicon resolution outcome for one NSID.
public struct OAuthCachedLexicon: Sendable, Equatable {
    /// The resolution result, including the negative outcome.
    public let resolution: OAuthLexiconResolution
    /// When the resolver was last asked.
    public let fetchedAt: Date
    /// When resolution last succeeded, or `nil` if it never has.
    public let lastSucceededAt: Date?

    /// Creates a cache entry.
    public init(resolution: OAuthLexiconResolution, fetchedAt: Date, lastSucceededAt: Date?) {
        self.resolution = resolution
        self.fetchedAt = fetchedAt
        self.lastSucceededAt = lastSucceededAt
    }
}
