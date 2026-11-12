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
    var header: [(String, TestDAGCBOR)] = [("op", .unsigned(1)), ("t", .text("#identity"))]
    header.append(contentsOf: extraHeader)
    var body: [(String, TestDAGCBOR)] = [
      ("seq", .int(seq)), ("did", .text(did)), ("time", .text(time)),
      ("handle", .text("alice.test")),
    ]
    body.append(contentsOf: extraBody)
    return TestDAGCBOR.frame(header: .map(header), payload: .map(body))
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
    body.append(contentsOf: flags)
    body.append(contentsOf: extra)
    return TestDAGCBOR.messageFrame(type: "#commit", payload: body)
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
    // Operands are typed constants: Swift 6.1 cannot type-check literal arithmetic inside
    // `#expect` in reasonable time.
    let headerFields: [(String, TestDAGCBOR)] = [("op", .unsigned(1)), ("t", .text("#commit"))]
    let header: [UInt8] = Array(TestDAGCBOR.map(headerFields).encoded)
    var expectedHeader: [UInt8] = [0xA2, 0x61, 0x74, 0x67]
    expectedHeader.append(contentsOf: Array("#commit".utf8))
    expectedHeader.append(contentsOf: [0x62, 0x6F, 0x70, 0x01])
    #expect(header == expectedHeader)
    // cid-link: tag 42, 37-byte string, multibase identity prefix 0x00, then CIDv1 dag-cbor sha-256.
    let link: [UInt8] = Array(TestDAGCBOR.link(Self.cid.bytes).encoded.prefix(9))
    let expectedLink: [UInt8] = [0xD8, 0x2A, 0x58, 0x25, 0x00, 0x01, 0x71, 0x12, 0x20]
    #expect(link == expectedLink)
  }

  @Test("unknown header and payload fields are ignored")
  func unknownFieldsAreIgnored() throws {
    let frame = Self.identity(
      extraHeader: [("v", .unsigned(2))],
      extraBody: [
        ("future", .map([("nested", .array([.unsigned(1), .null, .float64(1.5)]))])),
      ]
    )
    let expected = RelayEvent.identity(.init(seq: 7, did: Self.did, time: Self.time, handle: "alice.test"))
    let decoded = try RelayFrameDecoder.decode(frame)
    #expect(decoded == expected)
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
    let expected = RelayEvent.account(
      .init(seq: 8, did: Self.did, time: Self.time, active: active, status: status)
    )
    #expect(event == expected)
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
    let trimmedActions: [RelayRepoAction] = trimmed.ops.map(\.action)
    #expect(trimmedActions == [RelayRepoAction.create])

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
    let actions: [RelayRepoAction] = event.ops.map(\.action)
    let expectedActions: [RelayRepoAction] = [.create, .update, .delete, .update, .delete]
    #expect(actions == expectedActions)
    let hasPrev: [Bool] = event.ops.map { $0.prev != nil }
    let expectedHasPrev: [Bool] = [false, false, false, true, true]
    #expect(hasPrev == expectedHasPrev)
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
    let expected = RelayFrame.ignored(
      EventStreamIgnoredFrame(operation: 1, type: type, sequence: 41, reason: .unknownType)
    )
    let decoded = try RelayFrameDecoder.decodeFrame(frame)
    #expect(decoded == expected)
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
    let expected = RelayFrame.ignored(
      EventStreamIgnoredFrame(operation: 2, type: "#identity", sequence: 5, reason: .unknownOperation)
    )
    let decoded = try RelayFrameDecoder.decodeFrame(frame)
    #expect(decoded == expected)
    #expect(throws: RelayVerifierError.invalidFrameHeader) {
      try RelayFrameDecoder.decodeFrame(frame, mode: .strict)
    }
  }

  @Test("an error frame decodes from its wire bytes")
  func errorFrameFromWireBytes() throws {
    // Header {"op": -1} is exactly a1 62 6f 70 20.
    let headerBytes: [UInt8] = [0xA1, 0x62, 0x6F, 0x70, 0x20]
    let payloadFields: [(String, TestDAGCBOR)] = [
      ("error", .text("FutureCursor")), ("message", .text("Cursor in the future.")),
    ]
    var wire = Data(headerBytes)
    wire.append(TestDAGCBOR.map(payloadFields).encoded)
    let built: Data = TestDAGCBOR.errorFrame(error: "FutureCursor", message: "Cursor in the future.")
    #expect(built == wire)
    let expected = RelayEvent.error(.init(error: "FutureCursor", message: "Cursor in the future."))
    let decoded = try RelayFrameDecoder.decode(wire)
    #expect(decoded == expected)

    // Extra header and payload fields on an error frame are ignored as well.
    let decorated = TestDAGCBOR.frame(
      header: .map([("op", .negative(-1)), ("t", .text("#error"))]),
      payload: .map([("error", .text("ConsumerTooSlow")), ("retryAfter", .unsigned(5))])
    )
    let expectedDecorated = RelayEvent.error(.init(error: "ConsumerTooSlow", message: nil))
    let decodedDecorated = try RelayFrameDecoder.decode(decorated)
    #expect(decodedDecorated == expectedDecorated)
  }

  @Test("canonically equivalent map keys are invalid CBOR, not a crash")
  func canonicallyEquivalentMapKeys() {
    // "é" precomposed (NFC, C3 A9) and decomposed (NFD, 65 CC 81) are distinct byte strings,
    // so the pair passes the byte-wise key order check, but Swift `String` equality treats
    // them as the same key. A relay must not be able to trap the process with such a frame.
    let nfc = "\u{E9}"
    let nfd = "e\u{301}"
    #expect(Array(nfc.utf8) != Array(nfd.utf8))
    #expect(nfc == nfd)
    let inPayload = TestDAGCBOR.frame(
      header: .map([("op", .unsigned(1)), ("t", .text("#identity"))]),
      payload: .rawOrder([(nfc, .unsigned(1)), (nfd, .unsigned(2))])
    )
    #expect(throws: RelayVerifierError.invalidCBOR) { try RelayFrameDecoder.decodeFrame(inPayload) }
    let inHeader = TestDAGCBOR.frame(
      // Canonical order: shorter keys first, then bytewise.
      header: .rawOrder([("t", .text("#identity")), ("op", .unsigned(1)), (nfc, .unsigned(1)), (nfd, .unsigned(2))]),
      payload: .map([])
    )
    #expect(throws: RelayVerifierError.invalidCBOR) { try RelayFrameDecoder.decodeFrame(inHeader) }
    // The subscription treats it as a hard framing error as well.
    #expect(throws: RelayVerifierError.invalidCBOR) { try FirehoseSubscription.step(for: inPayload) }
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
