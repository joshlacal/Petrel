import Foundation
@testable import PetrelCABServerCore
import Testing

@Suite("Device store")
struct DeviceStoreTests {
  @Test("Records first-seen, last-seen, and request counts per jkt")
  func recordsUsage() async {
    let store = InMemoryDeviceStore(deniedJKTs: [])
    let first = Date(timeIntervalSince1970: 1_000_000)
    let second = Date(timeIntervalSince1970: 1_000_100)
    await store.record(jkt: "device-1", now: first)
    await store.record(jkt: "device-1", now: second)
    await store.record(jkt: "device-2", now: second)

    let snapshot = await store.snapshot()
    #expect(snapshot.count == 2)
    #expect(snapshot["device-1"]?.firstSeen == first)
    #expect(snapshot["device-1"]?.lastSeen == second)
    #expect(snapshot["device-1"]?.requestCount == 2)
    #expect(snapshot["device-2"]?.requestCount == 1)
  }

  @Test("Denies exactly the configured jkts")
  func denyList() async {
    let store = InMemoryDeviceStore(deniedJKTs: ["bad-jkt"])
    #expect(await store.isDenied(jkt: "bad-jkt") == true)
    #expect(await store.isDenied(jkt: "good-jkt") == false)
  }

  @Test("At capacity, a new jkt evicts the oldest-by-lastSeen entry; existing-key updates are unaffected")
  func evictsOldestAtCapacityButNotOnUpdate() async {
    let store = InMemoryDeviceStore(deniedJKTs: [])
    let base = Date(timeIntervalSince1970: 1_000_000)

    // Fill to capacity (10_000), each jkt's lastSeen strictly increasing so
    // "device-0" is unambiguously the oldest.
    for i in 0 ..< 10000 {
      await store.record(jkt: "device-\(i)", now: base.addingTimeInterval(Double(i)))
    }
    var snapshot = await store.snapshot()
    #expect(snapshot.count == 10000)
    #expect(snapshot["device-0"] != nil)

    // Re-touching an existing key at capacity must update it in place —
    // no eviction, no change to the dict's size or membership.
    let updatedSeen = base.addingTimeInterval(20000)
    await store.record(jkt: "device-5000", now: updatedSeen)
    snapshot = await store.snapshot()
    #expect(snapshot.count == 10000)
    #expect(snapshot["device-0"] != nil)
    #expect(snapshot["device-5000"]?.lastSeen == updatedSeen)
    #expect(snapshot["device-5000"]?.requestCount == 2)

    // A genuinely new key at capacity evicts the oldest-by-lastSeen entry
    // ("device-0") to make room; every other existing entry is untouched.
    await store.record(jkt: "device-new", now: base.addingTimeInterval(30000))
    snapshot = await store.snapshot()
    #expect(snapshot.count == 10000)
    #expect(snapshot["device-0"] == nil)
    #expect(snapshot["device-new"] != nil)
    #expect(snapshot["device-1"] != nil)
    #expect(snapshot["device-5000"]?.requestCount == 2)
  }

  @Test("Configurable capacity strictly bounds device store size")
  func configurableCapacity() async {
    let store = InMemoryDeviceStore(deniedJKTs: [], capacity: 10)
    let base = Date(timeIntervalSince1970: 2_000_000)

    for i in 0 ..< 25 {
      await store.record(jkt: "dev-\(i)", now: base.addingTimeInterval(Double(i)))
    }

    let snapshot = await store.snapshot()
    #expect(snapshot.count == 10)
    #expect(snapshot["dev-0"] == nil)
    #expect(snapshot["dev-24"] != nil)
  }

  @Test("Concurrent device records maintain thread safety and bounded capacity")
  func concurrentDeviceRecords() async {
    let store = InMemoryDeviceStore(deniedJKTs: [], capacity: 20)
    let base = Date()

    await withTaskGroup(of: Void.self) { group in
      for i in 0 ..< 100 {
        group.addTask {
          await store.record(jkt: "concurrent-dev-\(i)", now: base)
        }
      }
    }

    let snapshot = await store.snapshot()
    #expect(snapshot.count == 20)
  }
}
