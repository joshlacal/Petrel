import Foundation

public struct DeviceRecord: Sendable, Equatable {
  public var firstSeen: Date
  public var lastSeen: Date
  public var requestCount: Int
}

/// Per-device (`jkt`) usage tracking and refusal policy — the backend's
/// veto power from the proposal. Implementations may persist; the protocol
/// is the seam for a future SQLite-backed store.
public protocol DeviceStore: Sendable {
  func record(jkt: String, now: Date) async
  func isDenied(jkt: String) async -> Bool
  func snapshot() async -> [String: DeviceRecord]
}

public actor InMemoryDeviceStore: DeviceStore {
  private final class Node {
    let jkt: String
    var record: DeviceRecord
    var prev: Node?
    var next: Node?

    init(jkt: String, record: DeviceRecord) {
      self.jkt = jkt
      self.record = record
    }
  }

  private var nodes: [String: Node] = [:]
  private var head: Node?
  private var tail: Node?
  private let capacity: Int
  private let deniedJKTs: Set<String>

  public init(deniedJKTs: [String], capacity: Int = 10_000) {
    self.deniedJKTs = Set(deniedJKTs)
    self.capacity = capacity
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
    nodes.removeValue(forKey: node.jkt)
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
    nodes[node.jkt] = node
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

  public func record(jkt: String, now: Date) {
    if let node = nodes[jkt] {
      node.record.lastSeen = now
      node.record.requestCount += 1
      moveToTail(node)
    } else {
      if nodes.count >= capacity, let oldest = head {
        removeNode(oldest)
      }
      let record = DeviceRecord(firstSeen: now, lastSeen: now, requestCount: 1)
      let node = Node(jkt: jkt, record: record)
      appendNode(node)
    }
  }

  public func isDenied(jkt: String) -> Bool {
    deniedJKTs.contains(jkt)
  }

  public func snapshot() -> [String: DeviceRecord] {
    var result: [String: DeviceRecord] = [:]
    result.reserveCapacity(nodes.count)
    for (jkt, node) in nodes {
      result[jkt] = node.record
    }
    return result
  }
}
