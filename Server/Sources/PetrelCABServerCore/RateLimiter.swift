import Foundation

/// Token-bucket limiter keyed by arbitrary strings (this server keys by
/// device `jkt` after proof validation, so attackers can't exhaust someone
/// else's budget without their key).
public actor RateLimiter {
  private final class Node {
    let key: String
    var tokens: Double
    var lastRefill: Date
    var prev: Node?
    var next: Node?

    init(key: String, tokens: Double, lastRefill: Date) {
      self.key = key
      self.tokens = tokens
      self.lastRefill = lastRefill
    }
  }

  private var nodes: [String: Node] = [:]
  private var head: Node?
  private var tail: Node?
  private let capacity: Double
  private let refillPerSecond: Double
  private let maxKeys: Int
  /// Buckets idle longer than this have already refilled to `capacity`
  /// (refill is capped there), so dropping them loses no accuracy: the
  /// next `allow(key:)` for that key recreates an identical full bucket.
  /// Set to twice the time a bucket takes to fully refill.
  private let staleHorizon: TimeInterval

  public init(requestsPerMinute: Int, maxKeys: Int = 10_000) {
    self.capacity = Double(requestsPerMinute)
    self.maxKeys = maxKeys
    self.refillPerSecond = Double(requestsPerMinute) / 60.0
    let timeToFullRefill = refillPerSecond > 0 ? capacity / refillPerSecond : 60.0
    self.staleHorizon = timeToFullRefill * 2
  }

  private func removeNode(_ node: Node) {
    if let prev = node.prev {
      prev.next = node.next
    } else {
      head = node.next
    }
    if let next = node.next {
      next.prev = node.prev
    } else {
      tail = node.prev
    }
    node.prev = nil
    node.next = nil
    nodes.removeValue(forKey: node.key)
  }

  private func appendNode(_ node: Node) {
    node.prev = tail
    node.next = nil
    if let tail {
      tail.next = node
    } else {
      head = node
    }
    tail = node
    nodes[node.key] = node
  }

  private func moveToTail(_ node: Node) {
    guard tail !== node else { return }
    if let prev = node.prev {
      prev.next = node.next
    } else {
      head = node.next
    }
    if let next = node.next {
      next.prev = node.prev
    }
    node.prev = tail
    node.next = nil
    tail?.next = node
    tail = node
  }

  private func pruneStale(now: Date) {
    while let currentHead = head, now.timeIntervalSince(currentHead.lastRefill) >= staleHorizon {
      removeNode(currentHead)
    }
  }

  public func allow(key: String, now: Date = Date()) -> Bool {
    pruneStale(now: now)

    if let node = nodes[key] {
      node.tokens = min(
        capacity,
        node.tokens + now.timeIntervalSince(node.lastRefill) * refillPerSecond
      )
      node.lastRefill = now
      moveToTail(node)
      if node.tokens < 1 {
        return false
      }
      node.tokens -= 1
      return true
    }

    if nodes.count >= maxKeys, let oldest = head {
      removeNode(oldest)
    }

    let node = Node(key: key, tokens: capacity - 1, lastRefill: now)
    appendNode(node)
    return true
  }

  /// Exposed for tests only — the number of buckets currently tracked.
  var bucketCountForTesting: Int { nodes.count }
}
