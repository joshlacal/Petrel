import Foundation

public enum ReplayCheckResult: Sendable, Equatable {
  case fresh
  case replayed
  case saturated
}

/// Tracks seen DPoP proof `jti` values for the proof-acceptance window.
/// In-memory by design: replay protection only needs to span the iat window,
/// and a restart inside that window is an acceptable trade for a
/// zero-dependency server.
public actor ReplayStore {
  private struct ExpiryEntry {
    let jti: String
    let expiry: Date
  }

  private var seen: [String: Date] = [:]
  private var expiryQueue: [ExpiryEntry] = []
  private var queueHead = 0
  private let ttl: TimeInterval
  private let capacity: Int

  public init(ttl: TimeInterval, capacity: Int = 50_000) {
    self.ttl = ttl
    self.capacity = capacity
  }

  private func pruneExpired(now: Date) {
    while queueHead < expiryQueue.count {
      let entry = expiryQueue[queueHead]
      if entry.expiry <= now {
        if seen[entry.jti] == entry.expiry {
          seen.removeValue(forKey: entry.jti)
        }
        queueHead += 1
      } else {
        break
      }
    }
    if queueHead > 1024 && queueHead > expiryQueue.count / 2 {
      expiryQueue.removeFirst(queueHead)
      queueHead = 0
    }
  }

  /// Checks whether a jti is fresh, replayed, or if the store is saturated.
  public func checkAndInsert(_ jti: String, now: Date = Date()) -> ReplayCheckResult {
    pruneExpired(now: now)

    if let expiry = seen[jti] {
      if expiry > now {
        return .replayed
      } else {
        seen.removeValue(forKey: jti)
      }
    }

    if seen.count >= capacity {
      // Replay saturation fails closed rather than evicting unexpired protection.
      return .saturated
    }

    let expiry = now.addingTimeInterval(ttl)
    seen[jti] = expiry
    expiryQueue.append(ExpiryEntry(jti: jti, expiry: expiry))
    return .fresh
  }

  /// Exposed for tests only — the number of jtis currently tracked.
  var seenCountForTesting: Int {
    seen.count
  }
}
