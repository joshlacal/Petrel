import XCTest
import Petrel
import PetrelCore
import PetrelFirehose
import SwiftCBOR

@testable import PetrelJetstream

final class SegmentBlockTests: XCTestCase {
  private struct RawEventSpec {
    var seq: Int64
    var witnessedAtUS: Int64
    var indexedAtUS: Int64
    var kind: UInt8
    var collection: String
    var did: String
    var rkey: String
    var rev: String
    var payload: Data
  }

  private func encodeBlock(_ events: [RawEventSpec]) -> Data {
    var data = Data()
    let count = UInt32(events.count)
    var countLE = count.littleEndian
    data.append(Data(bytes: &countLE, count: 4))

    if events.isEmpty {
      return data
    }

    // Column 1: seq (u64 x N)
    for e in events {
      var val = UInt64(bitPattern: e.seq).littleEndian
      data.append(Data(bytes: &val, count: 8))
    }
    // Column 2: witnessed_at (i64 x N)
    for e in events {
      var val = UInt64(bitPattern: e.witnessedAtUS).littleEndian
      data.append(Data(bytes: &val, count: 8))
    }
    // Column 3: indexed_at (i64 x N)
    for e in events {
      var val = UInt64(bitPattern: e.indexedAtUS).littleEndian
      data.append(Data(bytes: &val, count: 8))
    }
    // Column 4: kind (u8 x N)
    for e in events {
      data.append(e.kind)
    }
    // Column 5: collection_len (u8 x N)
    for e in events {
      data.append(UInt8(e.collection.utf8.count))
    }
    // Column 6: did_len (u16 x N)
    for e in events {
      var val = UInt16(e.did.utf8.count).littleEndian
      data.append(Data(bytes: &val, count: 2))
    }
    // Column 7: rkey_len (u8 x N)
    for e in events {
      data.append(UInt8(e.rkey.utf8.count))
    }
    // Column 8: rev_len (u8 x N)
    for e in events {
      data.append(UInt8(e.rev.utf8.count))
    }
    // Column 9: event_len (u32 x N)
    for e in events {
      var val = UInt32(e.payload.count).littleEndian
      data.append(Data(bytes: &val, count: 4))
    }

    // Var regions
    for e in events {
      data.append(contentsOf: e.collection.utf8)
    }
    for e in events {
      data.append(contentsOf: e.did.utf8)
    }
    for e in events {
      data.append(contentsOf: e.rkey.utf8)
    }
    for e in events {
      data.append(contentsOf: e.rev.utf8)
    }
    for e in events {
      data.append(e.payload)
    }

    return data
  }

  private func makeJSSHeader(
    magic: String = "jss0",
    checksum: UInt64 = 0x1234_5678_9ABC_DEF0,
    version: UInt16 = 1,
    blockCount: UInt32 = 2,
    eventCount: UInt32 = 10,
    uniqueDidCount: UInt32 = 5,
    minSeq: UInt64 = 1,
    maxSeq: UInt64 = 10,
    minWitnessed: Int64 = 1000,
    maxWitnessed: Int64 = 2000,
    footerOffset: UInt64
  ) -> Data {
    var header = Data(count: 256)
    header.withUnsafeMutableBytes { ptr in
      for (i, b) in magic.utf8.prefix(4).enumerated() {
        ptr.storeBytes(of: b, toByteOffset: i, as: UInt8.self)
      }
      ptr.storeBytes(of: checksum.littleEndian, toByteOffset: 4, as: UInt64.self)
      ptr.storeBytes(of: version.littleEndian, toByteOffset: 12, as: UInt16.self)
      ptr.storeBytes(of: blockCount.littleEndian, toByteOffset: 14, as: UInt32.self)
      ptr.storeBytes(of: eventCount.littleEndian, toByteOffset: 18, as: UInt32.self)
      ptr.storeBytes(of: uniqueDidCount.littleEndian, toByteOffset: 22, as: UInt32.self)
      ptr.storeBytes(of: minSeq.littleEndian, toByteOffset: 26, as: UInt64.self)
      ptr.storeBytes(of: maxSeq.littleEndian, toByteOffset: 34, as: UInt64.self)
      ptr.storeBytes(of: UInt64(bitPattern: minWitnessed).littleEndian, toByteOffset: 42, as: UInt64.self)
      ptr.storeBytes(of: UInt64(bitPattern: maxWitnessed).littleEndian, toByteOffset: 50, as: UInt64.self)
      ptr.storeBytes(of: footerOffset.littleEndian, toByteOffset: 58, as: UInt64.self)
    }
    return header
  }

  private func withTempFile(data: Data, block: (URL) throws -> Void) throws {
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent(UUID().uuidString + ".jss")
    try data.write(to: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL) }
    try block(fileURL)
  }

  func testRoundTripDecode() throws {
    let postMap = OrderedCBORMap(entries: [
      (key: "$type", value: "app.bsky.feed.post"),
      (key: "text", value: "hi"),
    ])
    let postPayload = try DAGCBOR.encodeValue(postMap)

    let identityMap = OrderedCBORMap(entries: [
      (key: "$type", value: "com.atproto.sync.subscribeRepos#identity"),
      (key: "seq", value: 101),
      (key: "did", value: "did:plc:alice"),
      (key: "time", value: "2026-08-27T10:00:00.000Z"),
      (key: "handle", value: "alice.test"),
    ])
    let identityPayload = try DAGCBOR.encodeValue(identityMap)

    let accountMap = OrderedCBORMap(entries: [
      (key: "$type", value: "com.atproto.sync.subscribeRepos#account"),
      (key: "seq", value: 102),
      (key: "did", value: "did:plc:bob"),
      (key: "time", value: "2026-08-27T10:00:01.000Z"),
      (key: "active", value: false),
      (key: "status", value: "deleted"),
    ])
    let accountPayload = try DAGCBOR.encodeValue(accountMap)

    let syncMap = OrderedCBORMap(entries: [
      (key: "$type", value: "com.atproto.sync.subscribeRepos#sync"),
      (key: "seq", value: 103),
      (key: "did", value: "did:plc:carol"),
      (key: "blocks", value: Data([0x01, 0x02, 0x03])),
      (key: "rev", value: "3l3rev"),
      (key: "time", value: "2026-08-27T10:00:02.000Z"),
    ])
    let syncPayload = try DAGCBOR.encodeValue(syncMap)

    let rawEvents: [RawEventSpec] = [
      RawEventSpec(
        seq: 1000,
        witnessedAtUS: 1_700_000_000_000_000,
        indexedAtUS: 1_700_000_000_123_456,
        kind: 1, // Create
        collection: "app.bsky.feed.post",
        did: "did:plc:author1",
        rkey: "rkey1",
        rev: "rev1",
        payload: postPayload
      ),
      RawEventSpec(
        seq: 1001,
        witnessedAtUS: 1_700_000_001_000_000,
        indexedAtUS: 0, // indexed_at == 0 -> use witnessed_at
        kind: 3, // Delete
        collection: "app.bsky.feed.post",
        did: "did:plc:author1",
        rkey: "rkey2",
        rev: "rev2",
        payload: Data()
      ),
      RawEventSpec(
        seq: 1002,
        witnessedAtUS: 1_700_000_002_000_000,
        indexedAtUS: 1_700_000_002_500_000,
        kind: 4, // Identity
        collection: "$identity",
        did: "did:plc:alice",
        rkey: "",
        rev: "",
        payload: identityPayload
      ),
      RawEventSpec(
        seq: 1003,
        witnessedAtUS: 1_700_000_003_000_000,
        indexedAtUS: 1_700_000_003_500_000,
        kind: 5, // Account
        collection: "$account",
        did: "did:plc:bob",
        rkey: "",
        rev: "",
        payload: accountPayload
      ),
      RawEventSpec(
        seq: 1004,
        witnessedAtUS: 1_700_000_004_000_000,
        indexedAtUS: 1_700_000_004_500_000,
        kind: 6, // Sync
        collection: "$sync",
        did: "did:plc:carol",
        rkey: "",
        rev: "3l3rev",
        payload: syncPayload
      ),
      RawEventSpec(
        seq: 1005,
        witnessedAtUS: 1_700_000_005_000_000,
        indexedAtUS: 1_700_000_005_123_456,
        kind: 7, // CreateResync
        collection: "app.bsky.feed.post",
        did: "did:plc:author2",
        rkey: "rkey3",
        rev: "rev3",
        payload: postPayload
      ),
    ]

    let uncompressed = encodeBlock(rawEvents)
    let compressed = try JetstreamZstd.compress(uncompressed)
    let decoded = try SegmentBlockDecoder.decodeFrame(compressed)

    XCTAssertEqual(decoded.count, 6)

    // Event 0: Commit Create
    let e0 = decoded[0]
    XCTAssertEqual(e0.seq, 1000)
    XCTAssertEqual(e0.witnessedAtUS, 1_700_000_000_000_000)
    XCTAssertEqual(e0.indexedAtUS, 1_700_000_000_123_456)
    XCTAssertEqual(e0.timeUS, 1_700_000_000_123_456)
    XCTAssertEqual(e0.kind, 1)
    XCTAssertEqual(e0.collection, "app.bsky.feed.post")
    XCTAssertEqual(e0.did, "did:plc:author1")
    XCTAssertEqual(e0.rkey, "rkey1")
    XCTAssertEqual(e0.rev, "rev1")
    XCTAssertEqual(e0.payload, postPayload)

    guard case let .commit(c0) = e0.toJetstreamEvent() else {
      return XCTFail("expected commit event for e0")
    }
    XCTAssertEqual(c0.seq, 1000)
    XCTAssertEqual(c0.did, "did:plc:author1")
    XCTAssertEqual(c0.operation, .create)
    XCTAssertEqual(c0.timeUS, 1_700_000_000_123_456)
    XCTAssertEqual(c0.collection, "app.bsky.feed.post")
    XCTAssertEqual(c0.rkey, "rkey1")
    XCTAssertEqual(c0.rev, "rev1")
    XCTAssertNil(c0.cid)
    let rec0 = try XCTUnwrap(c0.recordJSON)
    let obj0 = try XCTUnwrap(JSONSerialization.jsonObject(with: rec0) as? [String: Any])
    XCTAssertEqual(obj0["text"] as? String, "hi")
    XCTAssertNotNil(c0.decodedRecord())

    // Event 1: Commit Delete (indexed_at == 0 -> timeUS uses witnessed_at)
    let e1 = decoded[1]
    XCTAssertEqual(e1.seq, 1001)
    XCTAssertEqual(e1.timeUS, 1_700_000_001_000_000)
    XCTAssertEqual(e1.kind, 3)
    XCTAssertEqual(e1.payload, Data())

    guard case let .commit(c1) = e1.toJetstreamEvent() else {
      return XCTFail("expected commit event for e1")
    }
    XCTAssertEqual(c1.seq, 1001)
    XCTAssertEqual(c1.operation, .delete)
    XCTAssertNil(c1.recordJSON)
    XCTAssertNil(c1.cid)

    // Event 2: Identity
    let e2 = decoded[2]
    XCTAssertEqual(e2.seq, 1002)
    XCTAssertEqual(e2.kind, 4)
    guard case let .identity(i2) = e2.toJetstreamEvent() else {
      return XCTFail("expected identity event for e2")
    }
    XCTAssertEqual(i2.seq, 1002)
    XCTAssertEqual(i2.did, "did:plc:alice")
    let idDetail = try XCTUnwrap(i2.identity)
    XCTAssertEqual(idDetail.handle?.description, "alice.test")

    // Event 3: Account (active = false, status = deleted)
    let e3 = decoded[3]
    XCTAssertEqual(e3.seq, 1003)
    XCTAssertEqual(e3.kind, 5)
    guard case let .account(a3) = e3.toJetstreamEvent() else {
      return XCTFail("expected account event for e3")
    }
    XCTAssertEqual(a3.seq, 1003)
    XCTAssertEqual(a3.did, "did:plc:bob")
    let accDetail = try XCTUnwrap(a3.account)
    XCTAssertEqual(accDetail.active, false)
    XCTAssertEqual(accDetail.status, "deleted")

    // Event 4: Sync
    let e4 = decoded[4]
    XCTAssertEqual(e4.seq, 1004)
    XCTAssertEqual(e4.kind, 6)
    guard case let .sync(s4) = e4.toJetstreamEvent() else {
      return XCTFail("expected sync event for e4")
    }
    XCTAssertEqual(s4.seq, 1004)
    XCTAssertEqual(s4.did, "did:plc:carol")
    let syncDetail = try XCTUnwrap(s4.sync)
    XCTAssertEqual(syncDetail.blocks.data, Data([0x01, 0x02, 0x03]))
    XCTAssertEqual(syncDetail.rev, "3l3rev")

    // Event 5: CreateResync (kind 7 -> commit .create)
    let e5 = decoded[5]
    XCTAssertEqual(e5.seq, 1005)
    XCTAssertEqual(e5.kind, 7)
    guard case let .commit(c5) = e5.toJetstreamEvent() else {
      return XCTFail("expected commit event for e5")
    }
    XCTAssertEqual(c5.seq, 1005)
    XCTAssertEqual(c5.operation, .create)
    XCTAssertNotNil(c5.recordJSON)
  }

  func testZeroEventBlock() throws {
    let uncompressed = Data([0x00, 0x00, 0x00, 0x00])
    let compressed = try JetstreamZstd.compress(uncompressed)
    let decoded = try SegmentBlockDecoder.decodeFrame(compressed)
    XCTAssertEqual(decoded, [])
  }

  func testZeroEventBlockWithTrailingBytesThrows() throws {
    let uncompressed = Data([0x00, 0x00, 0x00, 0x00, 0xFF])
    let compressed = try JetstreamZstd.compress(uncompressed)
    XCTAssertThrowsError(try SegmentBlockDecoder.decodeFrame(compressed)) { error in
      guard case let SegmentBlockError.invalidHeader(msg) = error else {
        return XCTFail("expected invalidHeader error, got \(error)")
      }
      XCTAssertTrue(msg.contains("trailing bytes"))
    }
  }

  func testTruncatedFixedBlockThrows() throws {
    // Declares 1 event (needs at least 4 + 34 bytes), but only provides 10 bytes total.
    var uncompressed = Data([0x01, 0x00, 0x00, 0x00])
    uncompressed.append(Data(repeating: 0x00, count: 6))
    let compressed = try JetstreamZstd.compress(uncompressed)
    XCTAssertThrowsError(try SegmentBlockDecoder.decodeFrame(compressed)) { error in
      XCTAssertEqual(error as? SegmentBlockError, .truncated)
    }
  }

  func testTruncatedVarRegionThrows() throws {
    let raw = RawEventSpec(
      seq: 1, witnessedAtUS: 1, indexedAtUS: 1, kind: 1,
      collection: "test", did: "did:plc:test", rkey: "rkey", rev: "rev",
      payload: Data([0x01, 0x02, 0x03, 0x04])
    )
    var uncompressed = encodeBlock([raw])
    uncompressed.removeLast(2) // Truncate var region
    let compressed = try JetstreamZstd.compress(uncompressed)
    XCTAssertThrowsError(try SegmentBlockDecoder.decodeFrame(compressed)) { error in
      XCTAssertEqual(error as? SegmentBlockError, .truncated)
    }
  }

  func testTrailingBytesAfterVarRegionThrows() throws {
    let raw = RawEventSpec(
      seq: 1, witnessedAtUS: 1, indexedAtUS: 1, kind: 1,
      collection: "test", did: "did:plc:test", rkey: "rkey", rev: "rev",
      payload: Data([0x01])
    )
    var uncompressed = encodeBlock([raw])
    uncompressed.append(contentsOf: [0xDE, 0xAD]) // Extra trailing bytes
    let compressed = try JetstreamZstd.compress(uncompressed)
    XCTAssertThrowsError(try SegmentBlockDecoder.decodeFrame(compressed)) { error in
      guard case let SegmentBlockError.invalidHeader(msg) = error else {
        return XCTFail("expected invalidHeader error, got \(error)")
      }
      XCTAssertTrue(msg.contains("trailing bytes"))
    }
  }

  func testExceedingMaxEventCountThrows() throws {
    // 262_145 in LE u32 is 0x00040001 -> [0x01, 0x00, 0x04, 0x00]
    let uncompressed = Data([0x01, 0x00, 0x04, 0x00])
    let compressed = try JetstreamZstd.compress(uncompressed)
    XCTAssertThrowsError(try SegmentBlockDecoder.decodeFrame(compressed)) { error in
      guard case let SegmentBlockError.invalidHeader(msg) = error else {
        return XCTFail("expected invalidHeader error, got \(error)")
      }
      XCTAssertTrue(msg.contains("exceeds maximum"))
    }
  }

  func testInvalidKindThrows() throws {
    let raw = RawEventSpec(
      seq: 1, witnessedAtUS: 1, indexedAtUS: 1, kind: 8, // Invalid kind
      collection: "test", did: "did:plc:test", rkey: "rkey", rev: "rev",
      payload: Data()
    )
    let uncompressed = encodeBlock([raw])
    let compressed = try JetstreamZstd.compress(uncompressed)
    XCTAssertThrowsError(try SegmentBlockDecoder.decodeFrame(compressed)) { error in
      guard case let SegmentBlockError.invalidHeader(msg) = error else {
        return XCTFail("expected invalidHeader error, got \(error)")
      }
      XCTAssertTrue(msg.contains("invalid event kind"))
    }
  }

  func testSegmentFileReaderSuccess() throws {
    let raw1 = RawEventSpec(
      seq: 10, witnessedAtUS: 100, indexedAtUS: 100, kind: 1,
      collection: "app.bsky.feed.post", did: "did:plc:user1", rkey: "1", rev: "r1",
      payload: Data()
    )
    let block1 = encodeBlock([raw1])
    let frame1 = try JetstreamZstd.compress(block1)

    let raw2 = RawEventSpec(
      seq: 20, witnessedAtUS: 200, indexedAtUS: 200, kind: 3,
      collection: "app.bsky.feed.post", did: "did:plc:user2", rkey: "2", rev: "r2",
      payload: Data()
    )
    let block2 = encodeBlock([raw2])
    let frame2 = try JetstreamZstd.compress(block2)

    let footerOffset = UInt64(256 + (8 + frame1.count) + (8 + frame2.count))

    var fileData = makeJSSHeader(
      blockCount: 2,
      eventCount: 2,
      minSeq: 10,
      maxSeq: 20,
      footerOffset: footerOffset
    )

    var len1 = UInt64(frame1.count).littleEndian
    fileData.append(Data(bytes: &len1, count: 8))
    fileData.append(frame1)

    var len2 = UInt64(frame2.count).littleEndian
    fileData.append(Data(bytes: &len2, count: 8))
    fileData.append(frame2)

    // Garbage footer after footerOffset
    fileData.append(Data(repeating: 0xEE, count: 64))

    try withTempFile(data: fileData) { url in
      let reader = try SegmentFileReader(fileURL: url)
      XCTAssertEqual(reader.blockCount, 2)

      let b1 = try XCTUnwrap(reader.nextBlock())
      XCTAssertEqual(b1.count, 1)
      XCTAssertEqual(b1[0].seq, 10)

      let b2 = try XCTUnwrap(reader.nextBlock())
      XCTAssertEqual(b2.count, 1)
      XCTAssertEqual(b2[0].seq, 20)

      let b3 = try reader.nextBlock()
      XCTAssertNil(b3)

      reader.close()
    }
  }

  func testSegmentFileReaderBadMagic() throws {
    let header = makeJSSHeader(magic: "bad0", footerOffset: 256)
    try withTempFile(data: header) { url in
      XCTAssertThrowsError(try SegmentFileReader(fileURL: url)) { error in
        XCTAssertEqual(error as? SegmentBlockError, .badMagic)
      }
    }
  }

  func testSegmentFileReaderZeroChecksumNotSealed() throws {
    let header = makeJSSHeader(checksum: 0, footerOffset: 256)
    try withTempFile(data: header) { url in
      XCTAssertThrowsError(try SegmentFileReader(fileURL: url)) { error in
        XCTAssertEqual(error as? SegmentBlockError, .notSealed)
      }
    }
  }

  func testSegmentFileReaderUnsupportedVersion() throws {
    let header = makeJSSHeader(version: 2, footerOffset: 256)
    try withTempFile(data: header) { url in
      XCTAssertThrowsError(try SegmentFileReader(fileURL: url)) { error in
        XCTAssertEqual(error as? SegmentBlockError, .unsupportedVersion(2))
      }
    }
  }

  func testSegmentFileReaderTruncatedHeader() throws {
    let header = Data(repeating: 0x00, count: 128)
    try withTempFile(data: header) { url in
      XCTAssertThrowsError(try SegmentFileReader(fileURL: url)) { error in
        XCTAssertEqual(error as? SegmentBlockError, .truncated)
      }
    }
  }

  func testSegmentFileReaderBlockCrossingFooterOffsetThrows() throws {
    var fileData = makeJSSHeader(blockCount: 1, footerOffset: 256 + 12)
    // Declare a block of length 100, but footer_offset is 256 + 12 (needs at least 8 + 100 = 108 bytes)
    var len = UInt64(100).littleEndian
    fileData.append(Data(bytes: &len, count: 8))
    fileData.append(Data(repeating: 0x00, count: 4))

    try withTempFile(data: fileData) { url in
      let reader = try SegmentFileReader(fileURL: url)
      XCTAssertThrowsError(try reader.nextBlock()) { error in
        XCTAssertEqual(error as? SegmentBlockError, .truncated)
      }
    }
  }
}

// Equatable conformance for test assertions
extension SegmentEvent: Equatable {
  public static func == (lhs: SegmentEvent, rhs: SegmentEvent) -> Bool {
    lhs.seq == rhs.seq &&
      lhs.witnessedAtUS == rhs.witnessedAtUS &&
      lhs.indexedAtUS == rhs.indexedAtUS &&
      lhs.kind == rhs.kind &&
      lhs.collection == rhs.collection &&
      lhs.did == rhs.did &&
      lhs.rkey == rhs.rkey &&
      lhs.rev == rhs.rev &&
      lhs.payload == rhs.payload
  }
}
