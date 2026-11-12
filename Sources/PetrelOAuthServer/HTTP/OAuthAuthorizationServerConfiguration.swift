import Foundation

/// Everything that configures an ``OAuthAuthorizationServer``.
public struct OAuthAuthorizationServerConfiguration: Sendable {
    /// The issuer identifier: an `https` origin with no path (not even a
    /// trailing `/`), query, fragment or default port. Every endpoint URL, the `iss` response parameter and
    /// every DPoP `htu` are derived from it, never from request headers.
    public var issuer: URL

    /// The resource server (PDS) these tokens are for, used as the access
    /// token audience and in protected-resource metadata. Defaults to the
    /// issuer, the common case of a PDS that is its own authorization server.
    public var resource: URL

    /// At least 32 random bytes. Keys every stored digest, the DPoP nonces and
    /// the browser-flow cookie. Instances that share state must share it.
    public var serverSecret: Data

    /// The scopes advertised in metadata. Must include `atproto`.
    public var scopesSupported: [String]

    /// The representation of access tokens.
    public var accessTokenFormat: OAuthAccessTokenFormat

    /// Access token lifetime. The profile requires under 30 minutes, and at
    /// most 15 where tokens are not individually revocable.
    public var accessTokenLifetime: TimeInterval

    /// How long an unused refresh token of a public client stays valid.
    public var publicClientRefreshLifetime: TimeInterval
    /// The hard limit on a public client's whole session.
    public var publicClientSessionLifetime: TimeInterval
    /// How long an unused refresh token of a confidential client stays valid.
    public var confidentialClientRefreshLifetime: TimeInterval
    /// The hard limit on a confidential client's whole session, or `nil` for
    /// no limit (the profile permits that for confidential clients).
    public var confidentialClientSessionLifetime: TimeInterval?

    /// How long a pushed authorization request may wait for the user.
    public var requestLifetime: TimeInterval
    /// How long an authorization code may wait to be exchanged.
    public var codeLifetime: TimeInterval
    /// How long a PKCE `code_challenge` stays unusable after it was seen.
    public var codeChallengeReuseWindow: TimeInterval
    /// How long a sign-in on a browser is offered for account selection.
    public var deviceSessionLifetime: TimeInterval

    /// What to do with a requested scope that is not a known permission.
    public var unknownScopePolicy: OAuthUnknownScopePolicy

    /// Clients whose self-declared `client_name`, `client_uri` and `logo_uri`
    /// are shown on the consent screen. For every other client only the
    /// verified `client_id` is shown, because any party can publish metadata
    /// claiming any name.
    public var trustedClientIDs: Set<String>

    /// Whether the session cookies carry the `Secure` attribute. Only turn
    /// this off for a loopback development server.
    public var secureCookies: Bool

    /// The largest form body accepted by the PAR, token and revocation
    /// endpoints.
    public var maximumFormBytes: Int

    /// Creates a configuration with the profile's recommended lifetimes.
    ///
    /// - Throws: ``OAuthServerError/malformed(_:)`` when the issuer is not a
    ///   valid issuer URL, the secret is too short, or a lifetime violates the
    ///   profile.
    public init(
        issuer: URL,
        resource: URL? = nil,
        serverSecret: Data,
        scopesSupported: [String] = ["atproto", "transition:generic", "transition:chat.bsky", "transition:email"],
        accessTokenFormat: OAuthAccessTokenFormat = .opaque,
        accessTokenLifetime: TimeInterval = 15 * 60,
        publicClientRefreshLifetime: TimeInterval = 14 * 24 * 60 * 60,
        publicClientSessionLifetime: TimeInterval = 14 * 24 * 60 * 60,
        confidentialClientRefreshLifetime: TimeInterval = 180 * 24 * 60 * 60,
        confidentialClientSessionLifetime: TimeInterval? = 2 * 365 * 24 * 60 * 60,
        requestLifetime: TimeInterval = 5 * 60,
        codeLifetime: TimeInterval = 60,
        codeChallengeReuseWindow: TimeInterval = 24 * 60 * 60,
        deviceSessionLifetime: TimeInterval = 7 * 24 * 60 * 60,
        unknownScopePolicy: OAuthUnknownScopePolicy = .reject,
        trustedClientIDs: Set<String> = [],
        secureCookies: Bool = true,
        maximumFormBytes: Int = 64 * 1024
    ) throws {
        self.issuer = issuer
        self.resource = resource ?? issuer
        self.serverSecret = serverSecret
        self.scopesSupported = scopesSupported
        self.accessTokenFormat = accessTokenFormat
        self.accessTokenLifetime = accessTokenLifetime
        self.publicClientRefreshLifetime = publicClientRefreshLifetime
        self.publicClientSessionLifetime = publicClientSessionLifetime
        self.confidentialClientRefreshLifetime = confidentialClientRefreshLifetime
        self.confidentialClientSessionLifetime = confidentialClientSessionLifetime
        self.requestLifetime = requestLifetime
        self.codeLifetime = codeLifetime
        self.codeChallengeReuseWindow = codeChallengeReuseWindow
        self.deviceSessionLifetime = deviceSessionLifetime
        self.unknownScopePolicy = unknownScopePolicy
        self.trustedClientIDs = trustedClientIDs
        self.secureCookies = secureCookies
        self.maximumFormBytes = maximumFormBytes
        try validate()
    }

    /// Checks the configuration against the profile's limits.
    public func validate() throws {
        _ = try OAuthMetadataPublication(resource: resource, issuer: issuer, scopesSupported: scopesSupported)
        guard serverSecret.count >= 32 else {
            throw OAuthServerError.malformed("OAuth server secret must be at least 32 bytes")
        }
        let day: TimeInterval = 24 * 60 * 60
        guard accessTokenLifetime >= 30, accessTokenLifetime < 30 * 60,
              publicClientRefreshLifetime >= 60, publicClientRefreshLifetime <= 14 * day,
              publicClientSessionLifetime >= 60, publicClientSessionLifetime <= 14 * day,
              confidentialClientRefreshLifetime >= 60, confidentialClientRefreshLifetime <= 180 * day,
              confidentialClientSessionLifetime.map({ $0 >= 60 }) ?? true,
              requestLifetime >= 10, requestLifetime <= 10 * 60,
              codeLifetime >= 5, codeLifetime <= 5 * 60,
              codeChallengeReuseWindow >= requestLifetime,
              deviceSessionLifetime >= 0,
              (1024 ... 1_048_576).contains(maximumFormBytes)
        else {
            throw OAuthServerError.malformed("OAuth server lifetime configuration is outside the profile's limits")
        }
    }
}
