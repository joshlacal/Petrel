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
  private var devices: [String: DeviceRecord] = [:]
  private let deniedJKTs: Set<String>

  public init(deniedJKTs: [String]) {
    self.deniedJKTs = Set(deniedJKTs)
  }

  public func record(jkt: String, now: Date) {
    if var record = devices[jkt] {
      record.lastSeen = now
      record.requestCount += 1
      devices[jkt] = record
    } else {
      devices[jkt] = DeviceRecord(firstSeen: now, lastSeen: now, requestCount: 1)
    }
  }

  public func isDenied(jkt: String) -> Bool {
    deniedJKTs.contains(jkt)
  }

  public func snapshot() -> [String: DeviceRecord] {
    devices
  }
}
