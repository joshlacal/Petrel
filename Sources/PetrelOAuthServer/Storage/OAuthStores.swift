import Foundation

// Storage is a set of narrow protocols, one per concern, so a host can put
// each on the backend that suits it (requests and replay markers in a cache,
// sessions in a database). ``InMemoryOAuthStore`` implements all of them for
// tests, development and single-process deployments.
//
// Every method that changes state names the transaction boundary it needs: an
// implementation must make each one atomic, because the security properties
// (single-use codes, single-use refresh tokens, replay detection) are exactly
// those boundaries.

/// Why a store refused an operation. Stores throw these for protocol facts and
/// any other error for infrastructure failures.
public enum OAuthStoreError: Error, Sendable, Equatable {
    /// The record does not exist, expired, or was already consumed.
    case notFound
    /// The presented value was used before. The session it belonged to has
    /// been revoked by the store as part of the same transaction.
    case replayed
    /// The session is revoked or past its hard end.
    case revoked
    /// A record with the same key already exists.
    case duplicate
}

/// Pushed authorization requests.
public protocol OAuthAuthorizationRequestStore: Sendable {
    /// Stores a request. Throws ``OAuthStoreError/duplicate`` when the digest
    /// is already present.
    func storePushedAuthorizationRequest(_ request: OAuthPushedAuthorizationRequest, now: Date) async throws

    /// Returns an unexpired, unconsumed request without consuming it, for
    /// rendering the authorization interface.
    func pushedAuthorizationRequest(requestDigest: Data, now: Date) async throws
        -> OAuthPushedAuthorizationRequest?

    /// Atomically removes and returns an unexpired request. Throws
    /// ``OAuthStoreError/notFound`` when it is absent, expired or already
    /// consumed, so a `request_uri` yields at most one code or one denial.
    func consumePushedAuthorizationRequest(requestDigest: Data, now: Date) async throws
        -> OAuthPushedAuthorizationRequest
}

/// Authorization codes and sessions (token families).
public protocol OAuthSessionStore: Sendable {
    /// Atomically stores a code and its not-yet-active session.
    func storeAuthorizationCode(_ code: OAuthAuthorizationCode, session: OAuthSession, now: Date) async throws

    /// Atomically redeems a code and activates its session with `tokens`.
    ///
    /// - Throws: ``OAuthStoreError/notFound`` when the code is unknown or
    ///   expired; ``OAuthStoreError/replayed`` when it was already redeemed,
    ///   in which case the session and every token issued from the first
    ///   redemption are revoked in the same transaction.
    func redeemAuthorizationCode(
        codeDigest: Data,
        verifying verify: @Sendable (OAuthAuthorizationCode) throws -> Void,
        issuing tokens: OAuthIssuedTokenDigests,
        now: Date
    ) async throws -> OAuthSession

    /// Reads a code's immutable facts without redeeming it. A consumed code is
    /// still returned (as a replay sentinel).
    func authorizationCode(codeDigest: Data, now: Date) async throws -> OAuthAuthorizationCode?

    /// The active session whose current access token has this digest and has
    /// not expired.
    func session(accessTokenDigest: Data, now: Date) async throws -> OAuthSession?

    /// The session a refresh token belongs to, whether the token is the
    /// current one or one that was already rotated away.
    func session(refreshTokenDigest: Data, now: Date) async throws -> OAuthSession?

    /// The session with this identifier, in any state.
    func session(id: UUID, now: Date) async throws -> OAuthSession?

    /// Atomically replaces the session's tokens, provided `refreshTokenDigest`
    /// is still the current refresh token.
    ///
    /// - Parameters:
    ///   - refreshTokenDigest: the digest of the presented refresh token.
    ///   - replacement: the digests of the newly minted tokens.
    ///   - grantedScopes: when non-nil, the re-derived effective grant is
    ///     written in the same transaction, so a token is never minted whose
    ///     stored grant is the one the re-derivation just replaced.
    ///   - now: the evaluation instant.
    /// - Throws: ``OAuthStoreError/replayed`` when the token was already
    ///   rotated away (the session is revoked in the same transaction);
    ///   ``OAuthStoreError/revoked`` when the session is no longer active;
    ///   ``OAuthStoreError/notFound`` when the token is unknown or expired.
    func rotateRefreshToken(
        refreshTokenDigest: Data,
        replacement: OAuthIssuedTokenDigests,
        grantedScopes: Set<String>?,
        now: Date
    ) async throws -> OAuthSession

    /// Revokes a session and all of its tokens. Idempotent.
    func revokeSession(id: UUID, now: Date) async throws

    /// The account's active sessions, for a "connected apps" page.
    func sessions(subject: String, now: Date) async throws -> [OAuthSession]

    /// True when the client currently holds at least one active session.
    func clientHoldsActiveSession(clientID: String, now: Date) async throws -> Bool

    /// Drops records that can no longer affect any decision.
    func purgeExpired(now: Date) async throws
}

/// Single-use markers: DPoP `jti`, client assertion `jti`, PKCE challenges and
/// request `state` values.
public protocol OAuthReplayStore: Sendable {
    /// Atomically reserves `digest` in `namespace` until `expiresAt`.
    ///
    /// - Returns: `false` when the value is already reserved and unexpired.
    func claim(namespace: OAuthReplayNamespace, digest: Data, expiresAt: Date, now: Date) async throws -> Bool
}

/// The cache of validated client metadata documents.
public protocol OAuthClientMetadataCacheStore: Sendable {
    /// The unexpired entry for `clientID`, if any.
    func cachedClientMetadata(clientID: String, now: Date) async throws -> OAuthCachedClientMetadata?
    /// Stores or replaces an entry.
    func cacheClientMetadata(_ metadata: OAuthCachedClientMetadata, now: Date) async throws
    /// Drops the entry for `clientID`, forcing the next load to refetch.
    func evictClientMetadata(clientID: String) async throws
}

/// The accounts signed in on each browser, for account selection.
public protocol OAuthDeviceSessionStore: Sendable {
    /// The accounts signed in on the device, most recently authenticated
    /// first, excluding entries older than `maximumAge`.
    func deviceAccounts(deviceDigest: Data, maximumAge: TimeInterval, now: Date) async throws
        -> [OAuthDeviceAccount]
    /// Records (or refreshes) a sign-in on the device.
    func rememberDeviceAccount(_ account: OAuthDeviceAccount, deviceDigest: Data, now: Date) async throws
    /// Signs an account out of the device.
    func forgetDeviceAccount(subject: String, deviceDigest: Data, now: Date) async throws
}

/// The cache of resolved Lexicon documents used for `include:` scopes.
public protocol OAuthLexiconCacheStore: Sendable {
    /// The cached outcome for `nsid`, however old.
    func cachedLexicon(nsid: String) async throws -> OAuthCachedLexicon?
    /// Stores or replaces the outcome for `nsid`.
    func cacheLexicon(_ entry: OAuthCachedLexicon, nsid: String) async throws
}

/// Everything the authorization server persists. A single value that conforms
/// to all of the store protocols.
public typealias OAuthServerStore = OAuthAuthorizationRequestStore
    & OAuthSessionStore
    & OAuthReplayStore
    & OAuthClientMetadataCacheStore
    & OAuthDeviceSessionStore
    & OAuthLexiconCacheStore
