import Foundation
import Petrel
@testable import PetrelFirehose
import PetrelStreamingTestSupport
import Testing

/// Consumer-side decoding rules from the event-stream and sync specifications. Every frame is
/// built with `TestDAGCBOR`, an encoder independent of the library, in the layout observed on
/// `bsky.network` (canonical key order, so `t` precedes `op` in the header).
@Suite("RelayFrameDecoder: spec-legal payloads")
struct RelayFrameLenientDecodingTests {
  static let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  static let time = "2026-08-08T12:00:00.000Z"
  static let rev = "3jzfcijpj2z2a"
  static let cid = CID.fromDAGCBOR(Data([0xA0]))

  static func identity(
    seq: Int64 = 7,
    extraHeader: [(String, TestDAGCBOR)] = [],
    extraBody: [(String, TestDAGCBOR)] = []
  ) -> Data {
    TestDAGCBOR.frame(
      header: .map([("op", .unsigned(1)), ("t", .text("#identity"))] + extraHeader),
      payload: .map([
        ("seq", .int(seq)), ("did", .text(did)), ("time", .text(time)),
        ("handle", .text("alice.test")),
      ] + extraBody)
    )
  }

  static func account(active: Bool, status: String?) -> Data {
    var body: [(String, TestDAGCBOR)] = [
      ("seq", .unsigned(8)), ("did", .text(did)), ("time", .text(time)), ("active", .bool(active)),
    ]
    if let status {
      body.append(("status", .text(status)))
    }
    return TestDAGCBOR.messageFrame(type: "#account", payload: body)
  }

  static func commit(
    seq: Int64 = 9,
    ops: [TestDAGCBOR],
    flags: [(String, TestDAGCBOR)] = [("rebase", .bool(false)), ("tooBig", .bool(false)), ("blobs", .array([]))],
    since: TestDAGCBOR? = .null,
    extra: [(String, TestDAGCBOR)] = []
  ) -> Data {
    var body: [(String, TestDAGCBOR)] = [
      ("seq", .int(seq)), ("repo", .text(did)), ("commit", .link(cid.bytes)),
      ("rev", .text(rev)), ("blocks", .bytes(Data())), ("ops", .array(ops)),
      ("time", .text(time)),
    ]
    if let since {
      body.append(("since", since))
    }
    return TestDAGCBOR.messageFrame(type: "#commit", payload: body + flags + extra)
  }

  static func op(_ action: String, prev: Bool) -> TestDAGCBOR {
    var fields: [(String, TestDAGCBOR)] = [
      ("action", .text(action)),
      ("path", .text("app.bsky.feed.post/3jzfcijpj2z2a")),
      ("cid", action == "delete" ? .null : .link(cid.bytes)),
    ]
    if prev {
      fields.append(("prev", .link(cid.bytes)))
    }
    return .map(fields)
  }

  @Test("the test encoder reproduces the header bytes captured from bsky.network")
  func headerLayoutMatchesProductionCapture() {
    let header = TestDAGCBOR.map([("op", .unsigned(1)), ("t", .text("#commit"))]).encoded
    #expect(Array(header) == [0xA2, 0x61, 0x74, 0x67] + Array("#commit".utf8) + [0x62, 0x6F, 0x70, 0x01])
    // cid-link: tag 42, 37-byte string, multibase identity prefix 0x00, then CIDv1 dag-cbor sha-256.
    let link = TestDAGCBOR.link(Self.cid.bytes).encoded
    #expect(Array(link.prefix(9)) == [0xD8, 0x2A, 0x58, 0x25, 0x00, 0x01, 0x71, 0x12, 0x20])
  }

  @Test("unknown header and payload fields are ignored")
  func unknownFieldsAreIgnored() throws {
    let frame = Self.identity(
      extraHeader: [("v", .unsigned(2))],
      extraBody: [
        ("future", .map([("nested", .array([.unsigned(1), .null, .float64(1.5)]))])),
      ]
    )
    #expect(try RelayFrameDecoder.decode(frame)
      == .identity(.init(seq: 7, did: Self.did, time: Self.time, handle: "alice.test")))
    #expect(throws: RelayVerifierError.invalidFrameHeader) {
      try RelayFrameDecoder.decode(frame, mode: .strict)
    }
    #expect(throws: RelayVerifierError.invalidEventBody) {
      try RelayFrameDecoder.decode(Self.identity(extraBody: [("future", .null)]), mode: .strict)
    }
  }

  @Test(
    "#account status is an open set and independent of `active`",
    arguments: [
      (true, nil), (false, "takendown"), (true, "throttled"), (true, "desynchronized"),
      (false, "some-future-status"), (false, nil),
    ] as [(Bool, String?)]
  )
  func accountStatusIsOpen(active: Bool, status: String?) throws {
    let event = try RelayFrameDecoder.decode(Self.account(active: active, status: status))
    #expect(event == .account(.init(seq: 8, did: Self.did, time: Self.time, active: active, status: status)))
  }

  @Test("strict mode still pins the account status rules used on relay captures")
  func strictAccountStatus() {
    #expect(throws: RelayVerifierError.invalidAccountStatus) {
      try RelayFrameDecoder.decode(Self.account(active: true, status: "throttled"), mode: .strict)
    }
    #expect(throws: RelayVerifierError.invalidAccountStatus) {
      try RelayFrameDecoder.decode(Self.account(active: false, status: "some-future-status"), mode: .strict)
    }
  }

  @Test("deprecated tooBig / rebase / blobs are ignored, whatever their value")
  func deprecatedCommitFlagsAreIgnored() throws {
    let legacy = Self.commit(
      ops: [],
      flags: [("rebase", .bool(true)), ("tooBig", .bool(true)), ("blobs", .array([.link(Self.cid.bytes)]))]
    )
    guard case let .commit(event) = try RelayFrameDecoder.decode(legacy) else {
      Issue.record("expected a commit")
      return
    }
    #expect(event.seq == 9)
    #expect(event.ops.isEmpty)
    #expect(event.since == nil)

    // A producer that has dropped the deprecated fields altogether.
    let future = Self.commit(ops: [Self.op("create", prev: false)], flags: [], since: nil)
    guard case let .commit(trimmed) = try RelayFrameDecoder.decode(future) else {
      Issue.record("expected a commit")
      return
    }
    #expect(trimmed.ops.map(\.action) == [.create])

    #expect(throws: RelayVerifierError.invalidEventBody) {
      try RelayFrameDecoder.decode(legacy, mode: .strict)
    }
  }

  @Test("update and delete operations without `prev` decode (pre-sync-1.1 producers)")
  func operationsWithoutPrev() throws {
    let frame = Self.commit(ops: [
      Self.op("create", prev: false), Self.op("update", prev: false), Self.op("delete", prev: false),
      Self.op("update", prev: true), Self.op("delete", prev: true),
    ])
    guard case let .commit(event) = try RelayFrameDecoder.decode(frame) else {
      Issue.record("expected a commit")
      return
    }
    #expect(event.ops.map(\.action) == [.create, .update, .delete, .update, .delete])
    #expect(event.ops.map { $0.prev != nil } == [false, false, false, true, true])
    #expect(event.ops[2].cid == nil)

    #expect(throws: RelayVerifierError.invalidRepositoryOperation) {
      try RelayFrameDecoder.decode(frame, mode: .strict)
    }
  }

  @Test("prevData is carried through")
  func prevData() throws {
    let frame = Self.commit(ops: [], extra: [("prevData", .link(Self.cid.bytes))])
    guard case let .commit(event) = try RelayFrameDecoder.decode(frame) else {
      Issue.record("expected a commit")
      return
    }
    #expect(event.prevDataCID == Self.cid)
    #expect(event.commitCID == Self.cid)
  }

  @Test(
    "unknown and deprecated message types are ignored, keeping their sequence number",
    arguments: ["#handle", "#migrate", "#tombstone", "#somethingNew"]
  )
  func unknownTypesAreIgnored(type: String) throws {
    let frame = TestDAGCBOR.messageFrame(type: type, payload: [
      ("seq", .unsigned(41)), ("did", .text(Self.did)), ("time", .text(Self.time)),
    ])
    #expect(try RelayFrameDecoder.decodeFrame(frame) == .ignored(.init(
      operation: 1, type: type, sequence: 41, reason: .unknownType
    )))
    // `RelayEvent` cannot represent the frame, so the typed entry point reports it.
    #expect(throws: RelayVerifierError.unknownEventKind) { try RelayFrameDecoder.decode(frame) }
    #expect(throws: RelayVerifierError.unknownEventKind) {
      try RelayFrameDecoder.decodeFrame(frame, mode: .strict)
    }
  }

  @Test("an unknown `op` is ignored")
  func unknownOperationIsIgnored() throws {
    let frame = TestDAGCBOR.frame(
      header: .map([("op", .unsigned(2)), ("t", .text("#identity"))]),
      payload: .map([("seq", .unsigned(5))])
    )
    #expect(try RelayFrameDecoder.decodeFrame(frame) == .ignored(.init(
      operation: 2, type: "#identity", sequence: 5, reason: .unknownOperation
    )))
    #expect(throws: RelayVerifierError.invalidFrameHeader) {
      try RelayFrameDecoder.decodeFrame(frame, mode: .strict)
    }
  }

  @Test("an error frame decodes from its wire bytes")
  func errorFrameFromWireBytes() throws {
    // Header {"op": -1} is exactly a1 62 6f 70 20.
    let header = Data([0xA1, 0x62, 0x6F, 0x70, 0x20])
    let payload = TestDAGCBOR.map([
      ("error", .text("FutureCursor")), ("message", .text("Cursor in the future.")),
    ]).encoded
    #expect(TestDAGCBOR.errorFrame(error: "FutureCursor", message: "Cursor in the future.") == header + payload)
    #expect(try RelayFrameDecoder.decode(header + payload)
      == .error(.init(error: "FutureCursor", message: "Cursor in the future.")))

    // Extra header and payload fields on an error frame are ignored as well.
    let decorated = TestDAGCBOR.frame(
      header: .map([("op", .negative(-1)), ("t", .text("#error"))]),
      payload: .map([("error", .text("ConsumerTooSlow")), ("retryAfter", .unsigned(5))])
    )
    #expect(try RelayFrameDecoder.decode(decorated) == .error(.init(error: "ConsumerTooSlow", message: nil)))
  }

  @Test("invalid framing stays a hard error in lenient mode")
  func framingErrorsAreHard() {
    let valid = Self.identity()
    #expect(throws: RelayVerifierError.truncatedFrame) { try RelayFrameDecoder.decodeFrame(Data(valid.dropLast())) }
    #expect(throws: RelayVerifierError.trailingFrameBytes) { try RelayFrameDecoder.decodeFrame(valid + Data([0xF6])) }
    #expect(throws: RelayVerifierError.truncatedFrame) { try RelayFrameDecoder.decodeFrame(Data()) }
    // op: 1 without `t`.
    let untyped = TestDAGCBOR.frame(header: .map([("op", .unsigned(1))]), payload: .map([]))
    #expect(throws: RelayVerifierError.invalidFrameHeader) { try RelayFrameDecoder.decodeFrame(untyped) }
    // Non-canonical map key order.
    let unordered = TestDAGCBOR.frame(
      header: .rawOrder([("op", .unsigned(1)), ("t", .text("#identity"))]),
      payload: .map([])
    )
    #expect(throws: RelayVerifierError.nonCanonicalCBOR) { try RelayFrameDecoder.decodeFrame(unordered) }
    let oversized = Data(repeating: 0, count: FirehoseFrameLimits.maximumFrameBytes + 1)
    #expect(throws: RelayVerifierError.frameTooLarge) { try RelayFrameDecoder.decodeFrame(oversized) }
  }
}
