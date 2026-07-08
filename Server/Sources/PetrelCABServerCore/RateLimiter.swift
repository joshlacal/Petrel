import Foundation

/// Token-bucket limiter keyed by arbitrary strings (this server keys by
/// device `jkt` after proof validation, so attackers can't exhaust someone
/// else's budget without their key).
public actor RateLimiter {
  private var buckets: [String: (tokens: Double, lastRefill: Date)] = [:]
  private let capacity: Double
  private let refillPerSecond: Double

  public init(requestsPerMinute: Int) {
    capacity = Double(requestsPerMinute)
    refillPerSecond = Double(requestsPerMinute) / 60.0
  }

  public func allow(key: String, now: Date = Date()) -> Bool {
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
}
