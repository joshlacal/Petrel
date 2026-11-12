import Foundation

/// A complete in-process implementation of ``OAuthServerStore``.
///
/// Suitable for tests, development and a single-process server that accepts
/// losing sessions on restart. Actor isolation makes every method one atomic
/// transaction, which is the property a persistent implementation has to
/// reproduce with its own transactions.
public actor InMemoryOAuthStore: OAuthAuthorizationRequestStore, OAuthSessionStore, OAuthReplayStore,
    OAuthClientMetadataCacheStore, OAuthDeviceSessionStore, OAuthLexiconCacheStore
{
    private var requests: [Data: OAuthPushedAuthorizationRequest] = [:]
    private var codes: [Data: OAuthAuthorizationCode] = [:]
    private var sessions: [UUID: OAuthSession] = [:]
    /// Refresh-token digests that were rotated away, so reuse can be told
    /// apart from an unknown token.
    private var retiredRefreshTokens: [Data: UUID] = [:]
    private var replay: [OAuthReplayNamespace: [Data: Date]] = [:]
    private var clientMetadata: [String: OAuthCachedClientMetadata] = [:]
    private var devices: [Data: [OAuthDeviceAccount]] = [:]
    private var lexicons: [String: OAuthCachedLexicon] = [:]
    private let replayCapacity: Int

    /// Creates an empty store.
    ///
    /// - Parameter replayCapacity: the most single-use markers kept per
    ///   namespace. When the limit is reached after expired markers are
    ///   dropped, new claims fail closed instead of evicting live ones.
    public init(replayCapacity: Int = 1_000_000) {
        self.replayCapacity = max(1, replayCapacity)
    }

    // MARK: Requests

    public func storePushedAuthorizationRequest(_ request: OAuthPushedAuthorizationRequest, now: Date) throws {
        if let existing = requests[request.requestDigest], existing.expiresAt > now {
            throw OAuthStoreError.duplicate
        }
        requests[request.requestDigest] = request
    }

    public func pushedAuthorizationRequest(requestDigest: Data, now: Date) -> OAuthPushedAuthorizationRequest? {
        guard let request = requests[requestDigest], request.expiresAt > now else { return nil }
        return request
    }

    public func consumePushedAuthorizationRequest(
        requestDigest: Data,
        now: Date
    ) throws -> OAuthPushedAuthorizationRequest {
        guard let request = requests.removeValue(forKey: requestDigest), request.expiresAt > now else {
            throw OAuthStoreError.notFound
        }
        return request
    }

    // MARK: Codes and sessions

    public func storeAuthorizationCode(_ code: OAuthAuthorizationCode, session: OAuthSession, now _: Date) throws {
        guard codes[code.codeDigest] == nil, sessions[session.sessionID] == nil,
              code.sessionID == session.sessionID
        else {
            throw OAuthStoreError.duplicate
        }
        codes[code.codeDigest] = code
        sessions[session.sessionID] = session
    }

    public func redeemAuthorizationCode(
        codeDigest: Data,
        verifying verify: @Sendable (OAuthAuthorizationCode) throws -> Void,
        issuing tokens: OAuthIssuedTokenDigests,
        now: Date
    ) throws -> OAuthSession {
        guard var code = codes[codeDigest] else { throw OAuthStoreError.notFound }
        guard code.consumedAt == nil else {
            revoke(code.sessionID, now: now)
            throw OAuthStoreError.replayed
        }
        guard code.expiresAt > now else { throw OAuthStoreError.notFound }
        guard var session = sessions[code.sessionID], session.isActive(at: now) else {
            throw OAuthStoreError.revoked
        }
        // A request that fails verification (wrong verifier, client or key)
        // does not burn the code: the legitimate client can still redeem it.
        try verify(code)
        code.consumedAt = now
        codes[codeDigest] = code
        session.tokens = tokens
        sessions[session.sessionID] = session
        return session
    }

    public func authorizationCode(codeDigest: Data, now _: Date) -> OAuthAuthorizationCode? {
        codes[codeDigest]
    }

    public func session(accessTokenDigest: Data, now: Date) -> OAuthSession? {
        sessions.values.first { session in
            session.isActive(at: now)
                && session.tokens?.accessTokenDigest == accessTokenDigest
                && (session.tokens?.accessExpiresAt ?? .distantPast) > now
        }
    }

    public func session(refreshTokenDigest: Data, now _: Date) -> OAuthSession? {
        if let retired = retiredRefreshTokens[refreshTokenDigest] { return sessions[retired] }
        return sessions.values.first { $0.tokens?.refreshTokenDigest == refreshTokenDigest }
    }

    public func session(id: UUID, now _: Date) -> OAuthSession? {
        sessions[id]
    }

    public func rotateRefreshToken(
        refreshTokenDigest: Data,
        replacement: OAuthIssuedTokenDigests,
        grantedScopes: Set<String>?,
        now: Date
    ) throws -> OAuthSession {
        if let retired = retiredRefreshTokens[refreshTokenDigest] {
            revoke(retired, now: now)
            throw OAuthStoreError.replayed
        }
        guard var session = sessions.values.first(where: { $0.tokens?.refreshTokenDigest == refreshTokenDigest }),
              let current = session.tokens
        else {
            throw OAuthStoreError.notFound
        }
        guard session.isActive(at: now) else { throw OAuthStoreError.revoked }
        guard (current.refreshExpiresAt ?? .distantPast) > now else { throw OAuthStoreError.notFound }
        retiredRefreshTokens[refreshTokenDigest] = session.sessionID
        session.tokens = replacement
        if let grantedScopes {
            session.binding = session.binding.withGrantedScopes(grantedScopes)
        }
        sessions[session.sessionID] = session
        return session
    }

    public func revokeSession(id: UUID, now: Date) {
        revoke(id, now: now)
    }

    public func revokeSessions(subject: String, now: Date) {
        for session in sessions.values where session.subject == subject {
            revoke(session.sessionID, now: now)
        }
        for (device, accounts) in devices where accounts.contains(where: { $0.subject == subject }) {
            devices[device] = accounts.filter { $0.subject != subject }
        }
    }

    public func sessions(subject: String, now: Date) -> [OAuthSession] {
        sessions.values
            .filter { $0.subject == subject && $0.isActive(at: now) && $0.tokens != nil }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func clientHoldsActiveSession(clientID: String, now: Date) -> Bool {
        sessions.values.contains { $0.binding.clientID == clientID && $0.isActive(at: now) && $0.tokens != nil }
    }

    public func purgeExpired(now: Date) {
        requests = requests.filter { $0.value.expiresAt > now }
        let dead = Set(sessions.values.filter { session in
            if let expiresAt = session.expiresAt, expiresAt <= now { return true }
            if let tokens = session.tokens {
                let last = max(tokens.accessExpiresAt, tokens.refreshExpiresAt ?? .distantPast)
                return last <= now
            }
            return false
        }.map(\.sessionID))
        // A pending session (code issued, never redeemed) dies with its code.
        let pendingDead = Set(codes.values.filter { $0.consumedAt == nil && $0.expiresAt <= now }.map(\.sessionID))
        let removed = dead.union(pendingDead.filter { sessions[$0]?.tokens == nil })
        for id in removed {
            sessions.removeValue(forKey: id)
        }
        codes = codes.filter { !removed.contains($0.value.sessionID) }
        retiredRefreshTokens = retiredRefreshTokens.filter { !removed.contains($0.value) }
        for namespace in replay.keys {
            replay[namespace] = replay[namespace]?.filter { $0.value > now }
        }
        clientMetadata = clientMetadata.filter { $0.value.expiresAt > now }
    }

    private func revoke(_ id: UUID, now: Date) {
        guard var session = sessions[id], session.revokedAt == nil else { return }
        session.revokedAt = now
        sessions[id] = session
    }

    // MARK: Replay

    public func claim(namespace: OAuthReplayNamespace, digest: Data, expiresAt: Date, now: Date) -> Bool {
        var markers = replay[namespace] ?? [:]
        if let existing = markers[digest], existing > now { return false }
        if markers.count >= replayCapacity {
            markers = markers.filter { $0.value > now }
            guard markers.count < replayCapacity else {
                replay[namespace] = markers
                return false
            }
        }
        markers[digest] = expiresAt
        replay[namespace] = markers
        return true
    }

    // MARK: Client metadata cache

    public func cachedClientMetadata(clientID: String, now: Date) -> OAuthCachedClientMetadata? {
        guard let entry = clientMetadata[clientID], entry.expiresAt > now else { return nil }
        return entry
    }

    public func cacheClientMetadata(_ metadata: OAuthCachedClientMetadata, now _: Date) {
        clientMetadata[metadata.clientID] = metadata
    }

    public func evictClientMetadata(clientID: String) {
        clientMetadata.removeValue(forKey: clientID)
    }

    // MARK: Device sessions

    public func deviceAccounts(deviceDigest: Data, maximumAge: TimeInterval, now: Date) -> [OAuthDeviceAccount] {
        (devices[deviceDigest] ?? [])
            .filter { now.timeIntervalSince($0.authenticatedAt) <= maximumAge }
            .sorted { $0.authenticatedAt > $1.authenticatedAt }
    }

    public func rememberDeviceAccount(_ account: OAuthDeviceAccount, deviceDigest: Data, now _: Date) {
        var accounts = (devices[deviceDigest] ?? []).filter { $0.subject != account.subject }
        accounts.append(account)
        devices[deviceDigest] = accounts
    }

    public func forgetDeviceAccount(subject: String, deviceDigest: Data, now _: Date) {
        devices[deviceDigest] = (devices[deviceDigest] ?? []).filter { $0.subject != subject }
    }

    public func moveDeviceAccounts(from old: Data, to new: Data, now _: Date) {
        guard old != new, let moving = devices.removeValue(forKey: old) else { return }
        var merged: [String: OAuthDeviceAccount] = [:]
        for account in (devices[new] ?? []) + moving {
            if let existing = merged[account.subject], existing.authenticatedAt >= account.authenticatedAt { continue }
            merged[account.subject] = account
        }
        devices[new] = Array(merged.values)
    }

    // MARK: Lexicon cache

    public func cachedLexicon(nsid: String) -> OAuthCachedLexicon? {
        lexicons[nsid]
    }

    public func cacheLexicon(_ entry: OAuthCachedLexicon, nsid: String) {
        lexicons[nsid] = entry
    }
}
