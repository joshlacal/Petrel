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
    // long since rejected proofs this old anyway).
    #expect(await store.checkAndInsert("jti-x", now: start.addingTimeInterval(11)) == true)
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
