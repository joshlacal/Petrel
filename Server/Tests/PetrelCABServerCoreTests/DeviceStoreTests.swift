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
}
