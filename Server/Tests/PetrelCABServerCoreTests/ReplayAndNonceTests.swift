import Foundation
@testable import PetrelCABServerCore
import Testing

@Suite("Replay store")
struct ReplayStoreTests {
  @Test("First use is fresh, second is a replay")
  func replayDetected() async {
    let store = ReplayStore(ttl: 300)
    #expect(await store.checkAndInsert("jti-a", now: Date()) == .fresh)
    #expect(await store.checkAndInsert("jti-a", now: Date()) == .replayed)
    #expect(await store.checkAndInsert("jti-b", now: Date()) == .fresh)
  }

  @Test("Entries expire after the TTL")
  func entriesExpire() async {
    let store = ReplayStore(ttl: 10)
    let start = Date()
    #expect(await store.checkAndInsert("jti-x", now: start) == .fresh)
    // Within TTL: still a replay.
    #expect(await store.checkAndInsert("jti-x", now: start.addingTimeInterval(5)) == .replayed)
    // Past TTL: treated as fresh again
    #expect(await store.checkAndInsert("jti-x", now: start.addingTimeInterval(11)) == .fresh)
  }

  @Test("Pruning never drops an unexpired jti")
  func unexpiredSurvivesPruning() async {
    let store = ReplayStore(ttl: 10_000)
    let start = Date(timeIntervalSince1970: 1_000_000)
    #expect(await store.checkAndInsert("jti-first", now: start) == .fresh)

    for i in 0 ..< 150 {
      _ = await store.checkAndInsert("jti-flood-\(i)", now: start.addingTimeInterval(Double(i) * 0.01))
    }

    #expect(await store.checkAndInsert("jti-first", now: start.addingTimeInterval(2)) == .replayed)
  }

  @Test("Expired entries are pruned in O(1) from the expiry queue")
  func expiredEntriesArePruned() async {
    let store = ReplayStore(ttl: 1)
    let start = Date(timeIntervalSince1970: 2_000_000)

    for i in 0 ..< 99 {
      #expect(await store.checkAndInsert("jti-\(i)", now: start) == .fresh)
    }
    #expect(await store.seenCountForTesting == 99)

    // Next call 2 seconds later prunes expired entries from the queue
    #expect(await store.checkAndInsert("new-item", now: start.addingTimeInterval(2)) == .fresh)
    #expect(await store.seenCountForTesting == 1)
  }

  @Test("Capacity saturation fails closed without evicting live replay records")
  func capacitySaturationFailsClosed() async {
    let store = ReplayStore(ttl: 100, capacity: 5)
    let start = Date(timeIntervalSince1970: 3_000_000)

    for i in 0 ..< 5 {
      #expect(await store.checkAndInsert("jti-\(i)", now: start) == .fresh)
    }
    #expect(await store.seenCountForTesting == 5)

    // 6th entry while all 5 are unexpired must return .saturated
    #expect(await store.checkAndInsert("jti-overflow", now: start.addingTimeInterval(1)) == .saturated)
    #expect(await store.seenCountForTesting == 5)

    // Original entries must still be recognized as replayed (never evicted!)
    #expect(await store.checkAndInsert("jti-0", now: start.addingTimeInterval(2)) == .replayed)
    #expect(await store.checkAndInsert("jti-4", now: start.addingTimeInterval(2)) == .replayed)

    // Once time passes TTL, expired entries prune and new insertions succeed
    #expect(await store.checkAndInsert("jti-after-expiry", now: start.addingTimeInterval(101)) == .fresh)
    #expect(await store.seenCountForTesting == 1)
  }

  @Test("Concurrent insertions maintain bounded cardinality and thread safety")
  func concurrentInsertions() async {
    let store = ReplayStore(ttl: 10, capacity: 50)
    let start = Date()

    await withTaskGroup(of: Void.self) { group in
      for i in 0 ..< 100 {
        group.addTask {
          _ = await store.checkAndInsert("jti-concurrent-\(i)", now: start)
        }
      }
    }

    let count = await store.seenCountForTesting
    #expect(count == 50)
  }
}

@Suite("Nonce service")
struct NonceServiceTests {
  @Test("Issued nonces validate within the window")
  func roundTrip() {
    let service = NonceService(secretBase64: nil, validity: 300)
    let nonce = service.issue(now: Date())
    #expect(service.isValid(nonce, now: Date()) == true)
  }

  @Test("Tampered nonces fail")
  func tamperFails() {
    let service = NonceService(secretBase64: nil, validity: 300)
    let nonce = service.issue(now: Date())
    #expect(service.isValid(nonce + "x", now: Date()) == false)
    #expect(service.isValid("999999." + nonce.split(separator: ".")[1], now: Date()) == false)
    #expect(service.isValid("garbage", now: Date()) == false)
  }

  @Test("Nonces expire after the validity window")
  func expiry() {
    let service = NonceService(secretBase64: nil, validity: 300)
    let issued = Date()
    let nonce = service.issue(now: issued)
    #expect(service.isValid(nonce, now: issued.addingTimeInterval(301)) == false)
  }

  @Test("A fixed secret validates across instances; different secrets do not")
  func secretStability() {
    let secret = Data((0 ..< 32).map { UInt8($0) }).base64EncodedString()
    let a = NonceService(secretBase64: secret, validity: 300)
    let b = NonceService(secretBase64: secret, validity: 300)
    let c = NonceService(secretBase64: nil, validity: 300)
    let nonce = a.issue(now: Date())
    #expect(b.isValid(nonce, now: Date()) == true)
    #expect(c.isValid(nonce, now: Date()) == false)
  }
}
