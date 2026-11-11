import Foundation

/// Looks up the public key a service-auth token must be signed with.
///
/// The specification: "The receiving service can validate the signature by
/// checking this key against the account's DID document." A resolver is the
/// seam between ``ServiceAuthVerifier`` and whatever resolves DID documents:
/// an identity resolver with a cache, a PLC mirror, or a fixed table.
///
/// `forceRefresh` is the key-rotation hook. The verifier first asks with
/// `false`, and only if the signature does not verify asks once more with
/// `true`; an implementation must then bypass its cache and re-read the DID
/// document.
public protocol ServiceAuthKeyResolver: Sendable {
    /// Returns the issuer's `#atproto` signing key.
    ///
    /// - Parameters:
    ///   - did: The issuer's DID, without a fragment.
    ///   - forceRefresh: `true` to bypass any cache.
    func signingKey(for did: String, forceRefresh: Bool) async throws -> ATProtoPublicKey

    /// Returns the key published under a specific verification method.
    ///
    /// The default implementation serves `#atproto` through
    /// ``signingKey(for:forceRefresh:)`` and throws
    /// ``ServiceAuthError/keyNotAccepted(keyID:)`` for anything else.
    /// Implement it to support services that sign with their own key, such
    /// as labelers (`#atproto_label`).
    ///
    /// - Parameters:
    ///   - did: The issuer's DID, without a fragment.
    ///   - keyID: The verification method fragment, with its `#`.
    ///   - forceRefresh: `true` to bypass any cache.
    func signingKey(for did: String, keyID: String, forceRefresh: Bool) async throws -> ATProtoPublicKey
}

public extension ServiceAuthKeyResolver {
    /// Serves `#atproto` through ``signingKey(for:forceRefresh:)``.
    func signingKey(for did: String, keyID: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
        guard keyID == ServiceJWT.defaultKeyID else {
            throw ServiceAuthError.keyNotAccepted(keyID: keyID)
        }
        return try await signingKey(for: did, forceRefresh: forceRefresh)
    }
}

/// A fixed table of signing keys: for tests, for services with a short list
/// of known callers, and for pinning a key that was resolved out of band.
///
/// ```swift
/// let resolver = StaticServiceAuthKeyResolver(keys: [
///     "did:plc:abcdefghijklmnopqrstuvwx": accountKey,
/// ])
/// ```
public struct StaticServiceAuthKeyResolver: ServiceAuthKeyResolver {
    private let keys: [String: [String: ATProtoPublicKey]]

    /// Creates a resolver that knows each DID's `#atproto` key.
    public init(keys: [String: ATProtoPublicKey]) {
        self.keys = keys.mapValues { [ServiceJWT.defaultKeyID: $0] }
    }

    /// Creates a resolver from DID → key identifier (with `#`) → key.
    public init(keysByID: [String: [String: ATProtoPublicKey]]) {
        keys = keysByID
    }

    /// Returns the DID's `#atproto` key.
    ///
    /// - Throws: ``ServiceAuthError/keyResolutionFailed(did:keyID:reason:)``
    ///   if the table has no entry.
    public func signingKey(for did: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
        try await signingKey(for: did, keyID: ServiceJWT.defaultKeyID, forceRefresh: forceRefresh)
    }

    /// Returns the DID's key under `keyID`.
    ///
    /// - Throws: ``ServiceAuthError/keyResolutionFailed(did:keyID:reason:)``
    ///   if the table has no entry.
    public func signingKey(for did: String, keyID: String, forceRefresh _: Bool) async throws -> ATProtoPublicKey {
        guard let key = keys[did]?[keyID] else {
            throw ServiceAuthError.keyResolutionFailed(did: did, keyID: keyID, reason: "no key on record")
        }
        return key
    }
}

/// A resolver backed by a closure, for adapting any DID-document source
/// without declaring a type.
///
/// ```swift
/// let resolver = ClosureServiceAuthKeyResolver { did, keyID, forceRefresh in
///     let document = try await myDirectory.document(for: did, bypassCache: forceRefresh)
///     return try document.key(named: keyID)
/// }
/// ```
public struct ClosureServiceAuthKeyResolver: ServiceAuthKeyResolver {
    private let resolve: @Sendable (_ did: String, _ keyID: String, _ forceRefresh: Bool) async throws -> ATProtoPublicKey

    /// - Parameter resolve: Returns the key published by `did` under the
    ///   verification method `keyID` (`#atproto`, `#atproto_label`, …).
    public init(
        _ resolve: @escaping @Sendable (_ did: String, _ keyID: String, _ forceRefresh: Bool) async throws -> ATProtoPublicKey
    ) {
        self.resolve = resolve
    }

    /// Calls the closure for `#atproto`.
    public func signingKey(for did: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
        try await resolve(did, ServiceJWT.defaultKeyID, forceRefresh)
    }

    /// Calls the closure.
    public func signingKey(for did: String, keyID: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
        try await resolve(did, keyID, forceRefresh)
    }
}

/// Caches another resolver's answers and rate-limits forced refreshes.
///
/// A verifier asks for a forced refresh whenever a signature fails, and
/// anyone can send a token with a bad signature. Without a limit that turns
/// each forged request into a DID-document fetch. This wrapper answers a
/// forced refresh from the upstream resolver at most once per
/// `minimumRefreshInterval` for a given DID and key, and otherwise returns
/// what it already has.
///
/// Wrap resolvers that do not cache themselves. A resolver that already
/// caches and throttles can be given to ``ServiceAuthVerifier`` directly.
public actor CachingServiceAuthKeyResolver: ServiceAuthKeyResolver {
    private struct Entry {
        let key: ATProtoPublicKey
        let fetchedAt: Date
    }

    private struct CacheKey: Hashable {
        let did: String
        let keyID: String
    }

    private let upstream: any ServiceAuthKeyResolver
    private let timeToLive: TimeInterval
    private let minimumRefreshInterval: TimeInterval
    private let capacity: Int
    private let clock: @Sendable () -> Date
    private var entries: [CacheKey: Entry] = [:]

    /// - Parameters:
    ///   - upstream: The resolver that actually reads DID documents.
    ///   - timeToLive: How long a key is served without asking upstream.
    ///   - minimumRefreshInterval: The shortest time between two upstream
    ///     fetches of the same key, forced or not.
    ///   - capacity: The most keys kept; the oldest are dropped first.
    ///   - clock: The time source; replace in tests.
    public init(
        upstream: any ServiceAuthKeyResolver,
        timeToLive: TimeInterval = 15 * 60,
        minimumRefreshInterval: TimeInterval = 30,
        capacity: Int = 10000,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.upstream = upstream
        self.timeToLive = max(0, timeToLive)
        self.minimumRefreshInterval = max(0, minimumRefreshInterval)
        self.capacity = max(1, capacity)
        self.clock = clock
    }

    /// Returns the cached `#atproto` key, fetching it when missing, stale or
    /// (subject to the rate limit) when `forceRefresh` is set.
    public func signingKey(for did: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
        try await signingKey(for: did, keyID: ServiceJWT.defaultKeyID, forceRefresh: forceRefresh)
    }

    /// Returns the cached key under `keyID`, fetching it when missing, stale
    /// or (subject to the rate limit) when `forceRefresh` is set.
    public func signingKey(for did: String, keyID: String, forceRefresh: Bool) async throws -> ATProtoPublicKey {
        let cacheKey = CacheKey(did: did, keyID: keyID)
        let now = clock()
        if let entry = entries[cacheKey] {
            let age = now.timeIntervalSince(entry.fetchedAt)
            let fresh = age >= 0 && age < timeToLive
            let recentlyFetched = age >= 0 && age < minimumRefreshInterval
            if recentlyFetched || (fresh && !forceRefresh) {
                return entry.key
            }
        }
        // A stale or distrusted entry here means upstream's own cache, if it
        // has one, is no better: ask it to re-read the DID document.
        let key = try await upstream.signingKey(
            for: did, keyID: keyID, forceRefresh: forceRefresh || entries[cacheKey] != nil
        )
        if entries[cacheKey] == nil, entries.count >= capacity {
            evictOldest()
        }
        entries[cacheKey] = Entry(key: key, fetchedAt: clock())
        return key
    }

    /// Forgets every cached key.
    public func removeAll() {
        entries.removeAll()
    }

    private func evictOldest() {
        // Drop a tenth at a time so a full cache does not sort on every insert.
        let batch = max(1, capacity / 10)
        for (cacheKey, _) in entries.sorted(by: { $0.value.fetchedAt < $1.value.fetchedAt }).prefix(batch) {
            entries[cacheKey] = nil
        }
    }
}
