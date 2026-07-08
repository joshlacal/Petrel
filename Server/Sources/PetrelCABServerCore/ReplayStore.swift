import Foundation

/// Tracks seen DPoP proof `jti` values for the proof-acceptance window.
/// In-memory by design: replay protection only needs to span the iat window,
/// and a restart inside that window is an acceptable trade for a
/// zero-dependency server.
public actor ReplayStore {
  private var seen: [String: Date] = [:]
  private let ttl: TimeInterval
  /// Amortizes the prune sweep: running `seen.filter` on every call is
  /// O(n) per call, which is O(n^2) CPU under a flood of unique jtis.
  /// Sweeping only every `cleanupInterval` calls keeps expired entries
  /// around a little longer between sweeps, which is harmless — we only
  /// ever remove entries whose expiry is `<= now`, so an unexpired jti is
  /// never dropped. `checkAndInsert` compares expiry directly (not mere
  /// key presence), so the deferred sweep never changes its result.
  private var cleanupCounter = 0
  private let cleanupInterval = 100

  public init(ttl: TimeInterval) {
    self.ttl = ttl
  }

  /// Returns true when the jti is fresh (and records it); false on replay.
  public func checkAndInsert(_ jti: String, now: Date = Date()) -> Bool {
    cleanupCounter += 1
    if cleanupCounter >= cleanupInterval {
      cleanupCounter = 0
      seen = seen.filter { $0.value > now }
    }
    // Check expiry directly rather than mere key presence: because the
    // sweep is now deferred, a stale entry can still be sitting in `seen`
    // between sweeps. Comparing `expiry > now` keeps checkAndInsert's
    // observable behavior identical to eager pruning regardless of where
    // we are in the amortization cycle.
    if let expiry = seen[jti], expiry > now { return false }
    seen[jti] = now.addingTimeInterval(ttl)
    return true
  }

  /// Exposed for tests only — the number of jtis currently tracked.
  var seenCountForTesting: Int { seen.count }
}
