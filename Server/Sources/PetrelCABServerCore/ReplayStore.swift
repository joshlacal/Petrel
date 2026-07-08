import Foundation

/// Tracks seen DPoP proof `jti` values for the proof-acceptance window.
/// In-memory by design: replay protection only needs to span the iat window,
/// and a restart inside that window is an acceptable trade for a
/// zero-dependency server.
public actor ReplayStore {
  private var seen: [String: Date] = [:]
  private let ttl: TimeInterval

  public init(ttl: TimeInterval) {
    self.ttl = ttl
  }

  /// Returns true when the jti is fresh (and records it); false on replay.
  public func checkAndInsert(_ jti: String, now: Date = Date()) -> Bool {
    // O(n) prune per call is fine at this endpoint's request rates.
    seen = seen.filter { $0.value > now }
    if seen[jti] != nil { return false }
    seen[jti] = now.addingTimeInterval(ttl)
    return true
  }
}
