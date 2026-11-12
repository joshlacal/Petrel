import Foundation
import Petrel
import PetrelStreamingTestSupport
import Testing

/// `ATProtoWebSocketFrameDecoder` is the frame decoder behind the lexicon-generated
/// subscriptions (`client.com.atproto.sync.subscribeRepos()` and friends) and
/// `EventStreamSubscription`.
@Suite("ATProtoWebSocketFrameDecoder")
struct EventStreamFrameDecoderTests {
  static let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  static let cid = CID.fromDAGCBOR(Data([0xA0]))

  static func commitFrame() -> Data {
    TestDAGCBOR.messageFrame(type: "#commit", payload: [
      ("seq", .unsigned(27_060_984_573)), ("rebase", .bool(false)), ("tooBig", .bool(false)),
      ("repo", .text(did)), ("commit", .link(cid.bytes)), ("rev", .text("3jzfcijpj2z2a")),
      ("since", .null), ("blocks", .bytes(Data([1, 2, 3]))),
      ("ops", .array([.map([
        ("action", .text("create")), ("path", .text("app.bsky.feed.post/3jzfcijpj2z2a")),
        ("cid", .link(cid.bytes)),
      ])])),
      ("blobs", .array([])), ("prevData", .link(cid.bytes)),
      ("time", .text("2026-08-08T12:00:00.000Z")),
    ])
  }

  @Test("a #commit with cid-links decodes into the generated message union")
  func commitWithCIDLinks() throws {
    let frame = try ATProtoWebSocketFrameDecoder.decodeFrame(
      Self.commitFrame(), defaultLexicon: "com.atproto.sync.subscribeRepos"
    )
    #expect(frame.messageType == "com.atproto.sync.subscribeRepos#commit")
    #expect(frame.sequence == 27_060_984_573)

    let message = try JSONCoders.decode(ComAtprotoSyncSubscribeRepos.Message.self, from: frame.jsonData)
    guard case let .commit(commit) = message else {
      Issue.record("expected a commit, got \(message)")
      return
    }
    #expect(commit.commit == Self.cid)
    #expect(commit.prevData == Self.cid)
    #expect(commit.ops.first?.cid == Self.cid)
    #expect(commit.ops.first?.prev == nil)
    #expect(commit.repo.description == Self.did)
    let expectedBlocks = Data([1, 2, 3] as [UInt8])
    #expect(commit.blocks.data == expectedBlocks)
  }

  @Test("a cid-link without the 0x00 multibase prefix is rejected")
  func cidLinkWithoutPrefix() {
    let frame = TestDAGCBOR.messageFrame(type: "#commit", payload: [
      ("commit", .tag(42, .bytes(Self.cid.bytes))),
    ])
    #expect(throws: (any Error).self) { try ATProtoWebSocketFrameDecoder.decode(frame) }
  }

  @Test("a real error frame (op: -1) is recognised and typed")
  func errorFrame() throws {
    let headerBytes: [UInt8] = [0xA1, 0x62, 0x6F, 0x70, 0x20]
    let payloadFields: [(String, TestDAGCBOR)] = [
      ("error", .text("FutureCursor")), ("message", .text("Cursor in the future.")),
    ]
    var wire = Data(headerBytes)
    wire.append(TestDAGCBOR.map(payloadFields).encoded)
    guard case let .error(error) = try ATProtoWebSocketFrameDecoder.decode(wire) else {
      Issue.record("expected an error frame")
      return
    }
    #expect(error == .futureCursor(message: "Cursor in the future."))
    #expect(error.name == "FutureCursor")

    #expect(throws: EventStreamError.consumerTooSlow(message: nil)) {
      try ATProtoWebSocketFrameDecoder.decodeFrame(TestDAGCBOR.errorFrame(error: "ConsumerTooSlow"))
    }
    #expect(throws: EventStreamError.other(name: "InvalidRequest", message: "bad")) {
      try ATProtoWebSocketFrameDecoder.decodeFrame(TestDAGCBOR.errorFrame(error: "InvalidRequest", message: "bad"))
    }
  }

  @Test("an unknown op is reported for skipping, not thrown")
  func unknownOperation() throws {
    let frame = TestDAGCBOR.frame(
      header: .map([("op", .unsigned(7)), ("t", .text("#x"))]),
      payload: .map([("seq", .unsigned(1))])
    )
    guard case let .unknownOperation(operation) = try ATProtoWebSocketFrameDecoder.decode(frame) else {
      Issue.record("expected unknownOperation")
      return
    }
    #expect(operation == 7)
  }

  @Test("unknown header fields are ignored and unsequenced messages have no sequence")
  func headerFieldsAndSequence() throws {
    let frame = TestDAGCBOR.frame(
      header: .map([("op", .unsigned(1)), ("t", .text("#info")), ("extra", .unsigned(1))]),
      payload: .map([("name", .text("OutdatedCursor"))])
    )
    guard case let .message(decoded) = try ATProtoWebSocketFrameDecoder.decode(
      frame, defaultLexicon: "com.atproto.sync.subscribeRepos"
    ) else {
      Issue.record("expected a message")
      return
    }
    #expect(decoded.sequence == nil)
    #expect(decoded.messageType == "com.atproto.sync.subscribeRepos#info")
  }

  @Test("framing errors throw")
  func framingErrors() {
    #expect(throws: (any Error).self) { try ATProtoWebSocketFrameDecoder.decode(Data()) }
    // Header only.
    #expect(throws: (any Error).self) {
      try ATProtoWebSocketFrameDecoder.decode(TestDAGCBOR.map([("op", .unsigned(1)), ("t", .text("#x"))]).encoded)
    }
    // op: 1 without t.
    #expect(throws: (any Error).self) {
      try ATProtoWebSocketFrameDecoder.decode(
        TestDAGCBOR.frame(header: .map([("op", .unsigned(1))]), payload: .map([]))
      )
    }
    #expect(throws: (any Error).self) {
      try ATProtoWebSocketFrameDecoder.decode(Data(repeating: 0, count: ATProtoWebSocketFrameDecoder.maximumFrameBytes + 1))
    }
  }
}
