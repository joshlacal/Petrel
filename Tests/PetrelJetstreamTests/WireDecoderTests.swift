import XCTest

@testable import PetrelJetstream

final class WireDecoderTests: XCTestCase {
  private func frame(_ json: String) -> Data { Data(json.utf8) }

  func testCommitCreateWithRecord() throws {
    let data = frame("""
      {"$type":"message","payload":{
        "$type":"network.bsky.jetstream.subscribeEvents#commit",
        "seq":1234,"did":"did:plc:abc123","time":"2026-08-27T12:34:56.123456Z",
        "rev":"3l3xyz","operation":"create","collection":"app.bsky.feed.post",
        "rkey":"3l3rkey","cid":"bafyreib2rxk3rh6kzwq",
        "record":{"$type":"app.bsky.feed.post","text":"hello","createdAt":"2026-08-27T12:34:56.123Z"}
      }}
      """)
    guard case let .message(.commit(commit)) = try JetstreamWire.decodeFrame(data) else {
      return XCTFail("expected commit")
    }
    XCTAssertEqual(commit.seq, 1234)
    XCTAssertEqual(commit.did, "did:plc:abc123")
    XCTAssertEqual(commit.operation, .create)
    XCTAssertEqual(commit.collection, "app.bsky.feed.post")
    XCTAssertEqual(commit.rkey, "3l3rkey")
    XCTAssertEqual(commit.cid, "bafyreib2rxk3rh6kzwq")
    // µs precision preserved: 2026-08-27T12:34:56Z == 1787834096.
    XCTAssertEqual(commit.timeUS % 1_000_000, 123_456)
    let record = try XCTUnwrap(commit.recordJSON)
    let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: record) as? [String: Any])
    XCTAssertEqual(obj["text"] as? String, "hello")
    XCTAssertNotNil(commit.decodedRecord())
  }

  func testCommitDeleteWithoutRecord() throws {
    let data = frame("""
      {"$type":"message","payload":{
        "$type":"network.bsky.jetstream.subscribeEvents#commit",
        "seq":1235,"did":"did:plc:abc123","time":"2026-08-27T12:34:56.000001Z",
        "rev":"3l3xyz","operation":"delete","collection":"app.bsky.feed.post","rkey":"3l3rkey"
      }}
      """)
    guard case let .message(.commit(commit)) = try JetstreamWire.decodeFrame(data) else {
      return XCTFail("expected commit")
    }
    XCTAssertEqual(commit.operation, .delete)
    XCTAssertNil(commit.recordJSON)
    XCTAssertNil(commit.cid)
    XCTAssertEqual(commit.timeUS % 1_000_000, 1)
  }

  func testIdentity() throws {
    let data = frame("""
      {"$type":"message","payload":{
        "$type":"network.bsky.jetstream.subscribeEvents#identity",
        "seq":42,"did":"did:plc:abc123","time":"2026-08-27T00:00:00.500000Z",
        "identity":{"$type":"com.atproto.sync.subscribeRepos#identity",
          "seq":990,"did":"did:plc:abc123","time":"2026-08-27T00:00:00.400Z","handle":"alice.test"}
      }}
      """)
    guard case let .message(.identity(event)) = try JetstreamWire.decodeFrame(data) else {
      return XCTFail("expected identity")
    }
    XCTAssertEqual(event.seq, 42)
    let detail = try XCTUnwrap(event.identity)
    XCTAssertEqual(detail.seq, 990)
    XCTAssertEqual(detail.handle?.description, "alice.test")
  }

  func testAccount() throws {
    let data = frame("""
      {"$type":"message","payload":{
        "$type":"network.bsky.jetstream.subscribeEvents#account",
        "seq":43,"did":"did:plc:abc123","time":"2026-08-27T00:00:01.000000Z",
        "account":{"$type":"com.atproto.sync.subscribeRepos#account",
          "seq":991,"did":"did:plc:abc123","time":"2026-08-27T00:00:00.900Z",
          "active":false,"status":"deleted"}
      }}
      """)
    guard case let .message(.account(event)) = try JetstreamWire.decodeFrame(data) else {
      return XCTFail("expected account")
    }
    let detail = try XCTUnwrap(event.account)
    XCTAssertFalse(detail.active)
    XCTAssertEqual(detail.status, "deleted")
  }

  func testSync() throws {
    let data = frame("""
      {"$type":"message","payload":{
        "$type":"network.bsky.jetstream.subscribeEvents#sync",
        "seq":44,"did":"did:plc:abc123","time":"2026-08-27T00:00:02.000000Z",
        "sync":{"$type":"com.atproto.sync.subscribeRepos#sync",
          "seq":992,"did":"did:plc:abc123","rev":"3l3rev",
          "time":"2026-08-27T00:00:01.900Z","blocks":{"$bytes":"3q2+7w=="}}
      }}
      """)
    guard case let .message(.sync(event)) = try JetstreamWire.decodeFrame(data) else {
      return XCTFail("expected sync")
    }
    XCTAssertEqual(event.seq, 44)
    let detail = try XCTUnwrap(event.sync)
    XCTAssertEqual(detail.rev, "3l3rev")
  }

  func testMalformedDetailKeepsEnvelope() throws {
    // Wrapped detail missing required fields: event still delivered, detail nil.
    let data = frame("""
      {"$type":"message","payload":{
        "$type":"network.bsky.jetstream.subscribeEvents#identity",
        "seq":45,"did":"did:plc:abc123","time":"2026-08-27T00:00:03.000000Z",
        "identity":{"unexpected":true}
      }}
      """)
    guard case let .message(.identity(event)) = try JetstreamWire.decodeFrame(data) else {
      return XCTFail("expected identity")
    }
    XCTAssertEqual(event.seq, 45)
    XCTAssertNil(event.identity)
  }

  func testInfo() throws {
    let data = frame("""
      {"$type":"message","payload":{
        "$type":"network.bsky.jetstream.subscribeEvents#info",
        "name":"OutdatedCursor","message":"resumed from seq 500"
      }}
      """)
    guard case let .message(.info(info)) = try JetstreamWire.decodeFrame(data) else {
      return XCTFail("expected info")
    }
    XCTAssertEqual(info.name, "OutdatedCursor")
    XCTAssertEqual(info.message, "resumed from seq 500")
  }

  func testErrorFrame() throws {
    let data = frame(#"{"$type":"error","error":"ConsumerTooSlow","message":"too slow"}"#)
    guard case let .error(name, message) = try JetstreamWire.decodeFrame(data) else {
      return XCTFail("expected error")
    }
    XCTAssertEqual(name, "ConsumerTooSlow")
    XCTAssertEqual(message, "too slow")
  }

  func testUnknownPayloadTypeSkipped() throws {
    let data = frame("""
      {"$type":"message","payload":{
        "$type":"network.bsky.jetstream.subscribeEvents#future","seq":1}}
      """)
    guard case .skipped = try JetstreamWire.decodeFrame(data) else {
      return XCTFail("expected skipped")
    }
  }

  func testMalformedJSONThrows() {
    XCTAssertThrowsError(try JetstreamWire.decodeFrame(Data("not json".utf8)))
  }

  func testMicrosecondParsing() {
    // 2026-08-27T00:00:00Z == 1787788800 epoch seconds.
    XCTAssertEqual(
      JetstreamWire.microseconds(fromRFC3339: "2026-08-27T00:00:00.123456Z"),
      1_787_788_800_123_456
    )
    XCTAssertEqual(
      JetstreamWire.microseconds(fromRFC3339: "2026-08-27T00:00:00Z"),
      1_787_788_800_000_000
    )
    // Millisecond input pads to micros.
    XCTAssertEqual(
      JetstreamWire.microseconds(fromRFC3339: "2026-08-27T00:00:00.5Z"),
      1_787_788_800_500_000
    )
    XCTAssertNil(JetstreamWire.microseconds(fromRFC3339: "garbage"))
  }

  func testFilterMatching() {
    let commit = JetstreamEvent.commit(JetstreamCommitEvent(
      seq: 1, did: "did:plc:a", timeUS: 0, rev: "r", operation: .create,
      collection: "app.bsky.feed.post", rkey: "k"
    ))
    let account = JetstreamEvent.account(JetstreamAccountEvent(
      seq: 2, did: "did:plc:b", timeUS: 0, account: nil
    ))

    XCTAssertTrue(JetstreamFilter().matches(commit))
    XCTAssertTrue(JetstreamFilter(collections: ["app.bsky.feed.post"]).matches(commit))
    XCTAssertTrue(JetstreamFilter(collections: ["app.bsky.feed.*"]).matches(commit))
    XCTAssertFalse(JetstreamFilter(collections: ["app.bsky.graph.*"]).matches(commit))
    // Wildcard must not match a bare prefix without the dot boundary.
    XCTAssertFalse(JetstreamFilter(collections: ["app.bsky.feed.post.*"]).matches(commit))
    XCTAssertFalse(JetstreamFilter(dids: ["did:plc:other"]).matches(commit))
    XCTAssertTrue(JetstreamFilter(dids: ["did:plc:a"]).matches(commit))
    XCTAssertFalse(JetstreamFilter(kinds: [.identity]).matches(commit))

    // collections constrains ONLY commits — markers always pass a collections filter.
    XCTAssertTrue(JetstreamFilter(collections: ["app.bsky.feed.post"]).matches(account))
    XCTAssertFalse(JetstreamFilter(kinds: [.commit], collections: ["app.bsky.feed.post"]).matches(account))

    // .info always passes.
    let info = JetstreamEvent.info(JetstreamInfoEvent(name: "OutdatedCursor"))
    XCTAssertTrue(JetstreamFilter(kinds: [.commit], dids: ["did:plc:x"]).matches(info))
  }
}
