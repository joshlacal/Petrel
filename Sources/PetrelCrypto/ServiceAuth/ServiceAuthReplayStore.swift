import Foundation

/// Remembers which service-auth tokens have been used, so each is accepted
/// once.
///
/// The specification on `jti`: "unique random string nonce. Should be used
/// by receiving services to prevent reuse of token and replay attacks."
/// ``ServiceAuthVerifier`` calls the store only after a token has passed
/// every other check, including its signature, so unauthenticated input
/// never reaches it.
///
/// A service running several instances needs a shared store (Redis,
/// a database table with a unique index); ``InMemoryServiceAuthReplayStore``
/// covers a single process.
public protocol ServiceAuthReplayStore: Sendable {
    /// Atomically records that a token was used.
    ///
    /// - Parameters:
    ///   - nonce: The token's `jti`.
    ///   - issuer: The issuer DID; nonces are only unique per issuer.
    ///   - expiresAt: When the record may be forgotten: the first instant
    ///     the verifier refuses the token as expired (`exp` plus the clock
    ///     skew plus the one second lost to whole-second comparison). A
    ///     token cannot be presented after that, so nothing is lost by
    ///     dropping it.
    /// - Returns: `true` if this is the first use, `false` if the nonce was
    ///   already recorded.
    func claim(nonce: String, issuer: String, expiresAt: Date) async throws -> Bool
}

/// A process-local ``ServiceAuthReplayStore``.
///
/// Entries are dropped once their token has expired. If more than
/// `capacity` unexpired tokens are outstanding the store refuses new ones
/// (``claim(nonce:issuer:expiresAt:)`` throws) rather than forget a nonce
/// that could still be replayed.
public actor InMemoryServiceAuthReplayStore: ServiceAuthReplayStore {
    /// Thrown when the store is full of unexpired entries.
    public struct CapacityExceeded: Error, Sendable, Equatable, CustomStringConvertible {
        /// The configured capacity.
        public let capacity: Int

        /// Creates the error for a store of the given capacity.
        public init(capacity: Int) {
            self.capacity = capacity
        }

        /// A description naming the capacity.
        public var description: String { "replay store is full (\(capacity) unexpired tokens)" }
    }

    private struct Key: Hashable {
        let issuer: String
        let nonce: String
    }

    private let capacity: Int
    private let clock: @Sendable () -> Date
    private var seen: [Key: Date] = [:]
    private var nextSweep: Date = .distantPast

    /// - Parameters:
    ///   - capacity: The most unexpired tokens remembered at once.
    ///   - clock: The time source; replace in tests.
    public init(capacity: Int = 100_000, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.capacity = max(1, capacity)
        self.clock = clock
    }

    /// The number of nonces currently remembered.
    public var count: Int { seen.count }

    /// Records the nonce, or reports that it was already used.
    ///
    /// - Throws: ``CapacityExceeded`` if the store is full of unexpired
    ///   entries.
    public func claim(nonce: String, issuer: String, expiresAt: Date) async throws -> Bool {
        let now = clock()
        if now >= nextSweep || seen.count >= capacity {
            seen = seen.filter { $0.value > now }
            nextSweep = now.addingTimeInterval(30)
        }
        let key = Key(issuer: issuer, nonce: nonce)
        if let recordedUntil = seen[key], recordedUntil > now {
            return false
        }
        guard seen.count < capacity else {
            throw CapacityExceeded(capacity: capacity)
        }
        seen[key] = expiresAt
        return true
    }
}
