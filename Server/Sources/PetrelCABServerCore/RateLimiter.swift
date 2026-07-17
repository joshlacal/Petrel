import Foundation

/// Token-bucket limiter keyed by arbitrary strings (this server keys by
/// device `jkt` after proof validation, so attackers can't exhaust someone
/// else's budget without their key).
public actor RateLimiter {
  private var buckets: [String: (tokens: Double, lastRefill: Date)] = [:]
  private let capacity: Double
  private let refillPerSecond: Double
  /// Buckets idle longer than this have already refilled to `capacity`
  /// (refill is capped there), so dropping them loses no accuracy: the
  /// next `allow(key:)` for that key recreates an identical full bucket.
  /// Set to twice the time a bucket takes to fully refill.
  private let staleHorizon: TimeInterval
  /// Amortizes the prune sweep: running `buckets.filter` on every call is
  /// O(n) per call, which is O(n^2) CPU under a flood of rotated keys.
  /// Sweeping only every `cleanupInterval` calls keeps the average cost
  /// O(1) per call; `buckets` can transiently exceed the live-key count by
  /// at most `cleanupInterval` entries between sweeps, so memory stays
  /// bounded even though it's no longer pruned on every single call.
  private var cleanupCounter = 0
  private let cleanupInterval = 100

  public init(requestsPerMinute: Int) {
    capacity = Double(requestsPerMinute)
    refillPerSecond = Double(requestsPerMinute) / 60.0
    let timeToFullRefill = refillPerSecond > 0 ? capacity / refillPerSecond : 60.0
    staleHorizon = timeToFullRefill * 2
  }

  public func allow(key: String, now: Date = Date()) -> Bool {
    cleanupCounter += 1
    if cleanupCounter >= cleanupInterval {
      cleanupCounter = 0
      buckets = buckets.filter { now.timeIntervalSince($0.value.lastRefill) < staleHorizon }
    }

    var bucket = buckets[key] ?? (tokens: capacity, lastRefill: now)
    bucket.tokens = min(
      capacity,
      bucket.tokens + now.timeIntervalSince(bucket.lastRefill) * refillPerSecond
    )
    bucket.lastRefill = now
    if bucket.tokens < 1 {
      buckets[key] = bucket
      return false
    }
    bucket.tokens -= 1
    buckets[key] = bucket
    return true
  }

  /// Exposed for tests only — the number of buckets currently tracked.
  var bucketCountForTesting: Int { buckets.count }
}
