import Foundation

/// Coalesces and briefly caches hostname resolutions in front of another
/// resolver.
///
/// The system resolver admits only a few concurrent blocking lookups and fails
/// closed past that. A burst of fetches for the same host therefore shares one
/// lookup here, and a successful answer is reused for a short time.
///
/// This is not a policy relaxation. Callers still policy-check every address
/// on every use, and failures are never cached: a lookup that threw is retried
/// by the next caller instead of being remembered as a refusal. The lifetime
/// is deliberately short, because it is also the DNS-rebinding window.
public actor CachingOAuthHostnameResolver: OAuthHostnameResolving {
    private struct Entry {
        let addresses: [OAuthIPAddress]
        let expiresAt: Date
    }

    private let upstream: any OAuthHostnameResolving
    private let ttl: TimeInterval
    private let maximumEntries: Int
    private let now: @Sendable () -> Date
    private var entries: [String: Entry] = [:]
    private var inFlight: [String: Task<[OAuthIPAddress], any Error>] = [:]

    /// Creates a caching resolver.
    public init(
        upstream: any OAuthHostnameResolving,
        ttl: TimeInterval = 30,
        maximumEntries: Int = 256,
        now: @Sendable @escaping () -> Date = { Date() }
    ) throws {
        guard ttl > 0, ttl <= 300, ttl.isFinite, (1 ... 4_096).contains(maximumEntries) else {
            throw OAuthServerError.malformed("hostname resolution cache configuration is invalid")
        }
        self.upstream = upstream
        self.ttl = ttl
        self.maximumEntries = maximumEntries
        self.now = now
    }

    /// Resolves `host`, sharing one upstream lookup among concurrent callers and reusing a recent answer.
    public func resolve(host: String) async throws -> [OAuthIPAddress] {
        let moment = now()
        if let entry = entries[host], entry.expiresAt > moment {
            return entry.addresses
        }
        entries.removeValue(forKey: host)
        if let existing = inFlight[host] {
            return try await existing.value
        }
        let upstream = upstream
        let task = Task<[OAuthIPAddress], any Error> {
            try await upstream.resolve(host: host)
        }
        inFlight[host] = task
        defer { inFlight.removeValue(forKey: host) }
        // A thrown lookup leaves no entry: a transient resolver outage must not
        // become a cached refusal for the whole TTL.
        let addresses = try await task.value
        store(host: host, addresses: addresses, at: now())
        return addresses
    }

    private func store(host: String, addresses: [OAuthIPAddress], at moment: Date) {
        entries[host] = Entry(addresses: addresses, expiresAt: moment.addingTimeInterval(ttl))
        guard entries.count > maximumEntries else { return }
        entries = entries.filter { $0.value.expiresAt > moment }
        guard entries.count > maximumEntries else { return }
        // Still over budget with nothing expired: drop the entries closest to
        // expiry, which are the ones a caller is least likely to reuse.
        let ordered = entries.sorted { $0.value.expiresAt < $1.value.expiresAt }
        for (host, _) in ordered.prefix(entries.count - maximumEntries) {
            entries.removeValue(forKey: host)
        }
    }
}
