import Foundation

/// A permission-set cache in front of any ``OAuthLexiconResolving``, with the
/// lifetimes the permission specification recommends.
///
/// - A resolved set is served from cache until it is **stale** (24 hours by
///   default, never less than `minimumFreshness`, which should be at least the
///   access-token lifetime).
/// - A stale set triggers a new resolution. If that fails, the stale value is
///   still used, until the set **expires** (90 days after it last resolved).
/// - A failed resolution with nothing usable in cache is remembered briefly so
///   a burst of requests for a broken set costs one lookup.
///
/// Cancellation is never cached: a cancelled lookup says nothing about the
/// permission set.
public struct CachingOAuthLexiconResolver: OAuthLexiconResolving {
    private let upstream: any OAuthLexiconResolving
    private let cache: any OAuthLexiconCacheStore
    private let clock: any OAuthClock
    private let staleAfter: TimeInterval
    private let expiresAfter: TimeInterval
    private let negativeLifetime: TimeInterval

    /// Creates a caching resolver.
    ///
    /// - Parameters:
    ///   - upstream: the resolver that actually performs Lexicon resolution.
    ///   - cache: where outcomes are kept. May be shared by every account and
    ///     session of the server.
    ///   - clock: the time source.
    ///   - staleAfter: seconds a resolved set is served without re-resolving.
    ///     Clamped to between 15 minutes and 24 hours, the specification's
    ///     firm bounds.
    ///   - expiresAfter: seconds after its last successful resolution that a
    ///     set may still be used when re-resolution fails.
    ///   - negativeLifetime: seconds a failure is remembered.
    public init(
        upstream: any OAuthLexiconResolving,
        cache: any OAuthLexiconCacheStore,
        clock: any OAuthClock = SystemOAuthClock(),
        staleAfter: TimeInterval = 24 * 60 * 60,
        expiresAfter: TimeInterval = 90 * 24 * 60 * 60,
        negativeLifetime: TimeInterval = 5 * 60
    ) {
        self.upstream = upstream
        self.cache = cache
        self.clock = clock
        self.staleAfter = min(max(staleAfter, 15 * 60), 24 * 60 * 60)
        self.expiresAfter = max(expiresAfter, self.staleAfter)
        self.negativeLifetime = min(max(negativeLifetime, 0), 60 * 60)
    }

    public func resolve(_ nsid: String) async throws -> OAuthLexiconResolution {
        let now = clock.now()
        let cached = try? await cache.cachedLexicon(nsid: nsid)
        if let cached {
            let age = now.timeIntervalSince(cached.fetchedAt)
            switch cached.resolution {
            case .resolved where age < staleAfter:
                return cached.resolution
            case .unresolvable where age < negativeLifetime:
                return cached.resolution
            default:
                break
            }
        }

        var fresh: OAuthLexiconResolution = .unresolvable
        do {
            fresh = try await upstream.resolve(nsid)
        } catch {
            try Task.checkCancellation()
            if error is CancellationError { throw error }
            // Any other resolver failure is treated like "could not resolve"
            // for the purpose of falling back to a stale value below.
        }
        if case .resolved = fresh {
            try? await cache.cacheLexicon(
                OAuthCachedLexicon(resolution: fresh, fetchedAt: now, lastSucceededAt: now), nsid: nsid
            )
            return fresh
        }

        // Resolution failed. A previously resolved set remains usable until it
        // expires; the next attempt is deferred by the negative lifetime.
        if let cached, case .resolved = cached.resolution, let lastSucceededAt = cached.lastSucceededAt,
           now.timeIntervalSince(lastSucceededAt) < expiresAfter
        {
            try? await cache.cacheLexicon(
                OAuthCachedLexicon(
                    resolution: cached.resolution,
                    fetchedAt: now.addingTimeInterval(negativeLifetime - staleAfter),
                    lastSucceededAt: lastSucceededAt
                ),
                nsid: nsid
            )
            return cached.resolution
        }
        try? await cache.cacheLexicon(
            OAuthCachedLexicon(resolution: .unresolvable, fetchedAt: now, lastSucceededAt: cached?.lastSucceededAt),
            nsid: nsid
        )
        return .unresolvable
    }
}

/// A resolver over a fixed table of permission sets, for tests and for
/// deployments that vendor the sets they accept.
public struct StaticOAuthLexiconResolver: OAuthLexiconResolving {
    private let documents: [String: OAuthLexiconDocument]

    /// Creates a resolver that knows `permissionSets`, keyed by NSID.
    public init(permissionSets: [String: LexiconPermissionSet]) {
        documents = permissionSets.mapValues { .permissionSet($0) }
    }

    /// Creates a resolver over arbitrary documents, keyed by NSID.
    public init(documents: [String: OAuthLexiconDocument]) {
        self.documents = documents
    }

    public func resolve(_ nsid: String) async throws -> OAuthLexiconResolution {
        guard let document = documents[nsid] else { return .unresolvable }
        return .resolved(
            document,
            sourceURI: "at://did:web:static.invalid/com.atproto.lexicon.schema/\(nsid)",
            verifiedCID: ""
        )
    }
}
