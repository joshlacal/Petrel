import Foundation
@testable import PetrelCABServerCore
import Testing

@Suite("Replay store")
struct ReplayStoreTests {
  @Test("First use is fresh, second is a replay")
  func replayDetected() async {
    let store = ReplayStore(ttl: 300)
    #expect(await store.checkAndInsert("jti-a", now: Date()) == true)
    #expect(await store.checkAndInsert("jti-a", now: Date()) == false)
    #expect(await store.checkAndInsert("jti-b", now: Date()) == true)
  }

  @Test("Entries expire after the TTL")
  func entriesExpire() async {
    let store = ReplayStore(ttl: 10)
    let start = Date()
    #expect(await store.checkAndInsert("jti-x", now: start) == true)
    // Within TTL: still a replay.
    #expect(await store.checkAndInsert("jti-x", now: start.addingTimeInterval(5)) == false)
    // Past TTL: treated as fresh again (the proof's own iat window has
    // long since rejected proofs this old anyway). This holds even though
    // the internal prune sweep is amortized and hasn't necessarily run —
    // checkAndInsert compares expiry directly.
    #expect(await store.checkAndInsert("jti-x", now: start.addingTimeInterval(11)) == true)
  }

  @Test("Amortized pruning never drops an unexpired jti, even across the sweep boundary")
  func unexpiredSurvivesAmortizationBoundary() async {
    let store = ReplayStore(ttl: 10_000)
    let start = Date(timeIntervalSince1970: 1_000_000)
    #expect(await store.checkAndInsert("jti-first", now: start) == true)

    // Flood with 150 distinct jtis — enough calls to cross the ~100-call
    // amortization threshold and trigger at least one internal sweep.
    for i in 0 ..< 150 {
      _ = await store.checkAndInsert("jti-flood-\(i)", now: start.addingTimeInterval(Double(i) * 0.01))
    }

    // "jti-first" has a 10,000s TTL and under 2s has elapsed — still
    // unexpired, so it must still be recognized as a replay regardless of
    // whether a sweep ran in between.
    #expect(await store.checkAndInsert("jti-first", now: start.addingTimeInterval(2)) == false)
  }

  @Test("A sweep still reclaims memory: expired entries are pruned once the interval is hit")
  func expiredEntriesAreEventuallyPruned() async {
    let store = ReplayStore(ttl: 1)
    let start = Date(timeIntervalSince1970: 2_000_000)

    // 99 short-lived jtis, all already past their 1s TTL by the time we
    // check, but under the ~100-call amortization threshold — no sweep
    // has run yet, so they're all still sitting in `seen`.
    for i in 0 ..< 99 {
      _ = await store.checkAndInsert("jti-\(i)", now: start)
    }
    #expect(await store.seenCountForTesting == 99)

    // The 100th call trips the sweep; every prior entry is well past its
    // 1s TTL by now, so the sweep prunes them all, leaving only the entry
    // just inserted.
    _ = await store.checkAndInsert("sweep-trigger", now: start.addingTimeInterval(2))
    #expect(await store.seenCountForTesting == 1)
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
