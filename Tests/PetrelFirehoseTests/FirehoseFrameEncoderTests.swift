import Foundation
import XCTest
@testable import PetrelFirehose
import Petrel

final class FirehoseFrameEncoderTests: XCTestCase {
  private let did = "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa"
  private let time = "2026-08-04T12:00:00.000Z"
  private let rev = "3kabcdefghijklmno"

  private func makeCID(_ seed: Data) -> CID {
    CID.fromDAGCBOR(seed)
  }

  private func decode(_ frame: Data) throws -> (header: FirehoseTestCBORValue, body: FirehoseTestCBORValue) {
    var reader = FirehoseTestCBORReader(frame)
    return try reader.readFrame()
  }

  private func commitMaterial(
    since: String?,
    prevData: String?,
    ops: [PublicFirehoseRepoOp],
    commitCID: CID
  ) -> PublicFirehoseCommitMaterial {
    PublicFirehoseCommitMaterial(
      did: did,
      rev: rev,
      since: since,
      commitCID: commitCID.string,
      prevDataCID: prevData,
      ops: ops,
      time: time
    )
  }

  // MARK: - Frames

  func testOrdinaryCreateCommitFrame() throws {
    let commitCID = makeCID(Data([0x01]))
    let prevDataCID = makeCID(Data([0x02]))
    let op = PublicFirehoseRepoOp(
      action: .create,
      path: "app.bsky.feed.post/3k1",
      cid: makeCID(Data([0x03])).string,
      prev: nil
    )
    let blocks = Data([0xde, 0xad, 0xbe, 0xef])

    let frame = try FirehoseFrameEncoder.commitFrame(
      seq: 42,
      material: commitMaterial(since: "3k0", prevData: prevDataCID.string, ops: [op], commitCID: commitCID),
      diffCAR: blocks
    )
    let (header, body) = try decode(frame)

    guard case let .map(headerEntries) = header else {
      return XCTFail("header is not a map")
    }
    XCTAssertEqual(entry(headerEntries, "op")?.unsigned, 1)
    XCTAssertEqual(entry(headerEntries, "t")?.text, "#commit")

    guard case let .map(bodyEntries) = body else {
      return XCTFail("body is not a map")
    }
    XCTAssertEqual(entry(bodyEntries, "seq")?.unsigned, 42)
    XCTAssertEqual(entry(bodyEntries, "rebase")?.bool, false)
    XCTAssertEqual(entry(bodyEntries, "tooBig")?.bool, false)
    XCTAssertEqual(entry(bodyEntries, "repo")?.text, did)
    XCTAssertEqual(entry(bodyEntries, "commit")?.cidLink, commitCID)
    XCTAssertEqual(entry(bodyEntries, "rev")?.text, rev)
    XCTAssertEqual(entry(bodyEntries, "since")?.text, "3k0")
    XCTAssertEqual(entry(bodyEntries, "blocks")?.bytes, blocks)
    XCTAssertEqual(entry(bodyEntries, "prevData")?.cidLink, prevDataCID)
    XCTAssertEqual(entry(bodyEntries, "time")?.text, time)
    XCTAssertEqual(entry(bodyEntries, "blobs")?.arrayValue?.count, 0)

    let ops = try XCTUnwrap(entry(bodyEntries, "ops")?.arrayValue)
    guard case let .map(opEntries) = ops[0] else {
      return XCTFail("op is not a map")
    }
    XCTAssertEqual(entry(opEntries, "action")?.text, "create")
    XCTAssertEqual(entry(opEntries, "path")?.text, "app.bsky.feed.post/3k1")
    XCTAssertEqual(entry(opEntries, "cid")?.cidLink, makeCID(Data([0x03])))
    XCTAssertNil(entry(opEntries, "prev"))
  }

  func testGenesisShapedCommitSinceNullAndNoPrevData() throws {
    let commitCID = makeCID(Data([0x01]))
    let op = PublicFirehoseRepoOp(
      action: .create,
      path: "app.bsky.feed.post/3k1",
      cid: makeCID(Data([0x03])).string,
      prev: nil
    )
    let frame = try FirehoseFrameEncoder.commitFrame(
      seq: 1,
      material: commitMaterial(since: nil, prevData: nil, ops: [op], commitCID: commitCID),
      diffCAR: Data([0x01])
    )
    let (_, body) = try decode(frame)
    guard case let .map(entries) = body else {
      return XCTFail("body is not a map")
    }
    XCTAssertEqual(entry(entries, "since")?.isNull, true)
    XCTAssertNil(entry(entries, "prevData"))
  }

  func testUpdateAndDeleteOperationSemantics() throws {
    let commitCID = makeCID(Data([0x01]))
    let update = PublicFirehoseRepoOp(
      action: .update,
      path: "app.bsky.feed.post/3k1",
      cid: makeCID(Data([0x04])).string,
      prev: makeCID(Data([0x03])).string
    )
    let delete = PublicFirehoseRepoOp(
      action: .delete,
      path: "app.bsky.feed.post/3k1",
      cid: nil,
      prev: makeCID(Data([0x04])).string
    )
    let frame = try FirehoseFrameEncoder.commitFrame(
      seq: 2,
      material: commitMaterial(since: "3k0", prevData: nil, ops: [update, delete], commitCID: commitCID),
      diffCAR: Data([0x02])
    )
    let (_, body) = try decode(frame)
    let ops = try XCTUnwrap(entry(FirehoseTestCBORValue.mapEntries(body), "ops")?.arrayValue)

    guard case let .map(updateEntries) = ops[0] else {
      return XCTFail("update op is not a map")
    }
    XCTAssertEqual(entry(updateEntries, "action")?.text, "update")
    XCTAssertEqual(entry(updateEntries, "cid")?.cidLink, makeCID(Data([0x04])))
    XCTAssertEqual(entry(updateEntries, "prev")?.cidLink, makeCID(Data([0x03])))

    guard case let .map(deleteEntries) = ops[1] else {
      return XCTFail("delete op is not a map")
    }
    XCTAssertEqual(entry(deleteEntries, "action")?.text, "delete")
    XCTAssertEqual(entry(deleteEntries, "cid")?.isNull, true)
    XCTAssertEqual(entry(deleteEntries, "prev")?.cidLink, makeCID(Data([0x04])))
  }

  func testSyncFrameUsesOnlyRequiredBodyFields() throws {
    let commitCID = makeCID(Data([0x01]))
    let material = PublicFirehoseSyncMaterial(did: did, rev: rev, commitCID: commitCID.string, time: time)
    let frame = try FirehoseFrameEncoder.syncFrame(seq: 7, material: material, commitCAR: Data([0xaa]))
    let (header, body) = try decode(frame)

    XCTAssertEqual(entry(FirehoseTestCBORValue.mapEntries(header), "op")?.unsigned, 1)
    XCTAssertEqual(entry(FirehoseTestCBORValue.mapEntries(header), "t")?.text, "#sync")

    guard case let .map(entries) = body else {
      return XCTFail("body is not a map")
    }
    XCTAssertEqual(Set(entries.map(\.key)), ["seq", "did", "blocks", "rev", "time"])
    XCTAssertEqual(entry(entries, "seq")?.unsigned, 7)
    XCTAssertEqual(entry(entries, "did")?.text, did)
    XCTAssertEqual(entry(entries, "blocks")?.bytes, Data([0xaa]))
    XCTAssertEqual(entry(entries, "rev")?.text, rev)
    XCTAssertEqual(entry(entries, "time")?.text, time)
  }

  func testIdentityWithAndWithoutHandle() throws {
    let withHandle = PublicFirehoseIdentityMaterial(did: did, handle: "alice.test", time: time)
    let frame = try FirehoseFrameEncoder.identityFrame(seq: 3, material: withHandle)
    let (header, body) = try decode(frame)
    XCTAssertEqual(entry(FirehoseTestCBORValue.mapEntries(header), "t")?.text, "#identity")
    XCTAssertEqual(entry(FirehoseTestCBORValue.mapEntries(body), "handle")?.text, "alice.test")
    XCTAssertEqual(entry(FirehoseTestCBORValue.mapEntries(body), "did")?.text, did)

    let withoutHandle = PublicFirehoseIdentityMaterial(did: did, handle: nil, time: time)
    let bare = try FirehoseFrameEncoder.identityFrame(seq: 4, material: withoutHandle)
    let (_, bareBody) = try decode(bare)
    XCTAssertNil(entry(FirehoseTestCBORValue.mapEntries(bareBody), "handle"))
  }

  func testAccountActiveRequiresNilStatusAndInactiveRequiresStatus() throws {
    let active = PublicFirehoseAccountMaterial(did: did, active: true, status: nil, time: time)
    let frame = try FirehoseFrameEncoder.accountFrame(seq: 5, material: active)
    let (_, body) = try decode(frame)
    XCTAssertEqual(entry(FirehoseTestCBORValue.mapEntries(body), "active")?.bool, true)
    XCTAssertNil(entry(FirehoseTestCBORValue.mapEntries(body), "status"))

    let inactive = PublicFirehoseAccountMaterial(did: did, active: false, status: .deleted, time: time)
    let deleted = try FirehoseFrameEncoder.accountFrame(seq: 6, material: inactive)
    let (_, deletedBody) = try decode(deleted)
    XCTAssertEqual(entry(FirehoseTestCBORValue.mapEntries(deletedBody), "active")?.bool, false)
    XCTAssertEqual(entry(FirehoseTestCBORValue.mapEntries(deletedBody), "status")?.text, "deleted")

    XCTAssertThrowsError(
      try FirehoseFrameEncoder.accountFrame(
        seq: 6,
        material: PublicFirehoseAccountMaterial(did: did, active: true, status: .suspended, time: time)
      )
    ) { error in
      XCTAssertEqual(error as? FirehoseFrameEncoderError, .invalidAccountStatus)
    }
    XCTAssertThrowsError(
      try FirehoseFrameEncoder.accountFrame(
        seq: 6,
        material: PublicFirehoseAccountMaterial(did: did, active: false, status: nil, time: time)
      )
    ) { error in
      XCTAssertEqual(error as? FirehoseFrameEncoderError, .invalidAccountStatus)
    }
  }

  func testInfoFrameHeaderAndBody() throws {
    let frame = try FirehoseFrameEncoder.infoFrame(name: "OutdatedCursor", message: "resuming from retained window")
    let (header, body) = try decode(frame)
    XCTAssertEqual(entry(FirehoseTestCBORValue.mapEntries(header), "op")?.unsigned, 1)
    XCTAssertEqual(entry(FirehoseTestCBORValue.mapEntries(header), "t")?.text, "#info")
    XCTAssertEqual(entry(FirehoseTestCBORValue.mapEntries(body), "name")?.text, "OutdatedCursor")
    XCTAssertEqual(entry(FirehoseTestCBORValue.mapEntries(body), "message")?.text, "resuming from retained window")

    let bare = try FirehoseFrameEncoder.infoFrame(name: "OutdatedCursor", message: nil)
    let (_, bareBody) = try decode(bare)
    XCTAssertNil(entry(FirehoseTestCBORValue.mapEntries(bareBody), "message"))
  }

  func testErrorFrameHasOpMinusOneAndNoType() throws {
    let frame = try FirehoseFrameEncoder.errorFrame(error: "FutureCursor", message: "cursor ahead of log")
    let (header, body) = try decode(frame)
    XCTAssertEqual(entry(FirehoseTestCBORValue.mapEntries(header), "op")?.signed, -1)
    XCTAssertNil(entry(FirehoseTestCBORValue.mapEntries(header), "t"))
    XCTAssertEqual(entry(FirehoseTestCBORValue.mapEntries(body), "error")?.text, "FutureCursor")
    XCTAssertEqual(entry(FirehoseTestCBORValue.mapEntries(body), "message")?.text, "cursor ahead of log")
  }

  // MARK: - Limits and validation

  func testSequenceZeroAndTwoToTheFiftyThirdRejected() {
    let material = commitMaterial(
      since: nil,
      prevData: nil,
      ops: [],
      commitCID: makeCID(Data([0x01]))
    )
    XCTAssertThrowsError(try FirehoseFrameEncoder.commitFrame(seq: 0, material: material, diffCAR: Data())) { error in
      XCTAssertEqual(error as? FirehoseFrameEncoderError, .sequenceOutOfRange)
    }
    XCTAssertThrowsError(
      try FirehoseFrameEncoder.commitFrame(seq: 9_007_199_254_740_992, material: material, diffCAR: Data())
    ) { error in
      XCTAssertEqual(error as? FirehoseFrameEncoderError, .sequenceOutOfRange)
    }
  }

  func testMaximumSequenceAccepted() throws {
    let material = commitMaterial(
      since: nil,
      prevData: nil,
      ops: [],
      commitCID: makeCID(Data([0x01]))
    )
    _ = try FirehoseFrameEncoder.commitFrame(
      seq: FirehoseFrameLimits.maximumSequence,
      material: material,
      diffCAR: Data()
    )
  }

  func testTwoHundredAndOneOpsRejected() throws {
    let op = PublicFirehoseRepoOp(
      action: .create,
      path: "app.bsky.feed.post/3k1",
      cid: makeCID(Data([0x03])).string,
      prev: nil
    )
    let material = commitMaterial(since: nil, prevData: nil, ops: Array(repeating: op, count: 201), commitCID: makeCID(Data([0x01])))
    XCTAssertThrowsError(
      try FirehoseFrameEncoder.commitFrame(seq: 1, material: material, diffCAR: Data())
    ) { error in
      XCTAssertEqual(error as? FirehoseFrameEncoderError, .tooManyOperations(201))
    }
  }

  func testCommitBlocksOverTwoMillionRejected() throws {
    let material = commitMaterial(since: nil, prevData: nil, ops: [], commitCID: makeCID(Data([0x01])))
    XCTAssertThrowsError(
      try FirehoseFrameEncoder.commitFrame(seq: 1, material: material, diffCAR: Data(repeating: 0, count: 2_000_001))
    ) { error in
      XCTAssertEqual(error as? FirehoseFrameEncoderError, .blocksTooLarge(actual: 2_000_001, maximum: 2_000_000))
    }
  }

  func testSyncBlocksOverTenThousandRejected() throws {
    let material = PublicFirehoseSyncMaterial(did: did, rev: rev, commitCID: makeCID(Data([0x01])).string, time: time)
    XCTAssertThrowsError(
      try FirehoseFrameEncoder.syncFrame(seq: 1, material: material, commitCAR: Data(repeating: 0, count: 10_001))
    ) { error in
      XCTAssertEqual(error as? FirehoseFrameEncoderError, .blocksTooLarge(actual: 10_001, maximum: 10_000))
    }
  }

  func testCompleteFrameOverFiveMillionRejected() throws {
    XCTAssertThrowsError(
      try FirehoseFrameEncoder.infoFrame(name: "x", message: String(repeating: "y", count: 5_000_001))
    ) { error in
      guard case let .frameTooLarge(count) = error as? FirehoseFrameEncoderError else {
        return XCTFail("expected frameTooLarge, got \(error)")
      }
      XCTAssertGreaterThan(count, 5_000_000)
    }
  }

  func testInvalidCIDRejected() throws {
    let material = commitMaterial(
      since: nil,
      prevData: nil,
      ops: [],
      commitCID: "not-a-cid",
      time: time
    )
    XCTAssertThrowsError(
      try FirehoseFrameEncoder.commitFrame(seq: 1, material: material, diffCAR: Data())
    ) { error in
      XCTAssertEqual(error as? FirehoseFrameEncoderError, .invalidCID("not-a-cid"))
    }
  }

  func testMalformedActionCIDPrevCombinationsRejected() throws {
    let commitCID = makeCID(Data([0x01]))
    let createWithPrev = PublicFirehoseRepoOp(
      action: .create,
      path: "app.bsky.feed.post/3k1",
      cid: makeCID(Data([0x03])).string,
      prev: makeCID(Data([0x02])).string
    )
    let updateWithoutPrev = PublicFirehoseRepoOp(
      action: .update,
      path: "app.bsky.feed.post/3k1",
      cid: makeCID(Data([0x03])).string,
      prev: nil
    )
    let deleteWithCID = PublicFirehoseRepoOp(
      action: .delete,
      path: "app.bsky.feed.post/3k1",
      cid: makeCID(Data([0x03])).string,
      prev: makeCID(Data([0x02])).string
    )
    let deleteWithoutPrev = PublicFirehoseRepoOp(
      action: .delete,
      path: "app.bsky.feed.post/3k1",
      cid: nil,
      prev: nil
    )
    for (index, op) in [createWithPrev, updateWithoutPrev, deleteWithCID, deleteWithoutPrev].enumerated() {
      let material = commitMaterial(since: nil, prevData: nil, ops: [op], commitCID: commitCID)
      XCTAssertThrowsError(
        try FirehoseFrameEncoder.commitFrame(seq: 1, material: material, diffCAR: Data())
      ) { error in
        guard case let .invalidOperation(opIndex, _) = error as? FirehoseFrameEncoderError else {
          return XCTFail("expected invalidOperation, got \(error)")
        }
        XCTAssertEqual(opIndex, 0)
      }
    }
  }

  func testDeterministicByteEqualityAcrossRepeatedEncodes() throws {
    let commitCID = makeCID(Data([0x01]))
    let op = PublicFirehoseRepoOp(
      action: .update,
      path: "app.bsky.feed.post/3k1",
      cid: makeCID(Data([0x04])).string,
      prev: makeCID(Data([0x03])).string
    )
    let material = commitMaterial(since: "3k0", prevData: makeCID(Data([0x02])).string, ops: [op], commitCID: commitCID)
    let first = try FirehoseFrameEncoder.commitFrame(seq: 99, material: material, diffCAR: Data([0x00, 0x01]))
    let second = try FirehoseFrameEncoder.commitFrame(seq: 99, material: material, diffCAR: Data([0x00, 0x01]))
    XCTAssertEqual(first, second)
  }

  // MARK: - Strict decoder behavior

  func testDecoderRejectsTrailingBytes() {
    let material = PublicFirehoseIdentityMaterial(did: did, handle: nil, time: time)
    let frame = try! FirehoseFrameEncoder.identityFrame(seq: 1, material: material)
    var reader = FirehoseTestCBORReader(frame + Data([0x00]))
    XCTAssertThrowsError(try reader.readFrame()) { error in
      XCTAssertEqual(error as? FirehoseFrameTestDecoderError, .trailingBytes)
    }
  }

  func testDecoderRejectsNonCanonicalInteger() throws {
    // The integer 23 encoded with a one-byte extension (0x18 0x17) instead
    // of the shortest form (0x17).
    let bytes = Data([0x18, 0x17])
    var reader = FirehoseTestCBORReader(bytes)
    XCTAssertThrowsError(try reader.readNext()) { error in
      XCTAssertEqual(error as? FirehoseFrameTestDecoderError, .nonCanonicalInteger)
    }
  }

  func testDecoderRejectsNonCanonicalMapKeyOrder() throws {
    // Map with keys "b" then "a": lexicographically out of order.
    let bytes = Data([0xa2, 0x61, 0x62, 0x01, 0x61, 0x61, 0x01])
    var reader = FirehoseTestCBORReader(bytes)
    XCTAssertThrowsError(try reader.readNext()) { error in
      XCTAssertEqual(error as? FirehoseFrameTestDecoderError, .nonCanonicalMapKeyOrder)
    }
  }

  func testDecoderPreservesNullOmittedAndCIDLinkDistinctions() throws {
    let commitCID = makeCID(Data([0x01]))
    let op = PublicFirehoseRepoOp(
      action: .create,
      path: "app.bsky.feed.post/3k1",
      cid: makeCID(Data([0x03])).string,
      prev: nil
    )
    let frame = try FirehoseFrameEncoder.commitFrame(
      seq: 1,
      material: commitMaterial(since: nil, prevData: nil, ops: [op], commitCID: commitCID),
      diffCAR: Data([0x01])
    )
    let (_, body) = try decode(frame)
    let since = try XCTUnwrap(entry(FirehoseTestCBORValue.mapEntries(body), "since"))
    XCTAssertTrue(since.isNull)
    XCTAssertNotNil(entry(FirehoseTestCBORValue.mapEntries(body), "commit")?.cidLink)
  }

  func testConsumedByteCountHelper() throws {
    let bytes = Data([0x01, 0x02, 0x03])
    XCTAssertEqual(try FirehoseTestCBORReader.consumedByteCount(ofFirstValueIn: bytes), 1)
  }

  // MARK: - Helpers

  private func entry(_ entries: [FirehoseTestCBORMapEntry], _ key: String) -> FirehoseTestCBORValue? {
    entries.first(where: { $0.key == key })?.value
  }

  private func commitMaterial(
    since: String?,
    prevData: String?,
    ops: [PublicFirehoseRepoOp],
    commitCID: String,
    time: String
  ) -> PublicFirehoseCommitMaterial {
    PublicFirehoseCommitMaterial(
      did: did,
      rev: rev,
      since: since,
      commitCID: commitCID,
      prevDataCID: prevData,
      ops: ops,
      time: time
    )
  }
}

extension FirehoseTestCBORValue {
  var unsigned: UInt64? {
    if case let .unsigned(value) = self { return value }
    return nil
  }

  var signed: Int64? {
    if case let .signed(value) = self { return value }
    return nil
  }

  var text: String? {
    if case let .text(value) = self { return value }
    return nil
  }

  var bytes: Data? {
    if case let .bytes(value) = self { return value }
    return nil
  }

  var bool: Bool? {
    if case let .boolean(value) = self { return value }
    return nil
  }

  var isNull: Bool {
    if case .null = self { return true }
    return false
  }

  var arrayValue: [FirehoseTestCBORValue]? {
    if case let .array(value) = self { return value }
    return nil
  }

  var cidLink: CID? {
    if case let .cidLink(value) = self { return value }
    return nil
  }

  static func mapEntries(_ value: FirehoseTestCBORValue) -> [FirehoseTestCBORMapEntry] {
    if case let .map(entries) = value { return entries }
    return []
  }
}
