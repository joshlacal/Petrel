import Foundation
import Petrel
import PetrelFirehose
import PetrelStreamingTestSupport
import Testing

/// `com.atproto.label.subscribeLabels` through the generic `EventStreamSubscription`.
@Suite("LabelSubscription (EventStreamSubscription)")
struct LabelSubscriptionTests {
  static let labeler = "did:plc:ar7c4by46qjdydhdevvrndac"
  static let fastBackoff = FirehoseBackoffConfiguration(initialDelay: 0.001, maxDelay: 0.002, multiplier: 1)

  static func labels(seq: Int64, values: [String]) -> Data {
    TestDAGCBOR.messageFrame(type: "#labels", payload: [
      ("seq", .int(seq)),
      ("labels", .array(values.map { value in
        .map([
          ("ver", .unsigned(1)),
          ("src", .text(labeler)),
          ("uri", .text("at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3jzfcijpj2z2a")),
          ("val", .text(value)),
          ("cts", .text("2026-08-08T12:00:00.000Z")),
          ("sig", .bytes(Data(repeating: 0xAB, count: 64))),
        ])
      })),
    ])
  }

  static func subscription(
    _ factory: ScriptedWebSocketFactory,
    storage: any FirehoseCursorStorage = InMemoryFirehoseCursorStorage()
  ) -> LabelSubscription {
    LabelSubscription.labels(
      service: URL(string: "https://mod.example")!,
      cursorStorage: storage,
      backoff: fastBackoff,
      sessionFactory: factory,
      autoAcknowledge: true
    )
  }

  @Test("label batches and #info decode into the generated lexicon types")
  func decodesLabels() async throws {
    let session = ScriptedWebSocketSession(messages: [
      TestDAGCBOR.messageFrame(type: "#info", payload: [("name", .text("OutdatedCursor"))]),
      Self.labels(seq: 1, values: ["porn"]),
      Self.labels(seq: 2, values: ["spam", "!hide"]),
    ])
    let factory = ScriptedWebSocketFactory(sessions: [session])
    let storage = InMemoryFirehoseCursorStorage(initialCursor: 0)

    var batches: [(seq: Int64?, values: [String])] = []
    var infoNames: [String] = []
    for try await event in Self.subscription(factory, storage: storage).events() {
      switch event {
      case let .message(.labels(batch), sequence):
        #expect(Int64(batch.seq) == sequence)
        #expect(batch.labels.allSatisfy { $0.src.description == Self.labeler && $0.sig?.data.count == 64 })
        batches.append((sequence, batch.labels.map(\.val)))
      case let .message(.info(info), sequence):
        #expect(sequence == nil)
        infoNames.append(info.name)
      case .sequenceGap, .ignoredFrame:
        Issue.record("unexpected \(event)")
      }
      if batches.count == 2 { break }
    }

    #expect(infoNames == ["OutdatedCursor"])
    #expect(batches.map(\.seq) == [1, 2])
    #expect(batches.map(\.values) == [["porn"], ["spam", "!hide"]])
    #expect(await factory.connectedURLs.map(\.absoluteString)
      == ["wss://mod.example/xrpc/com.atproto.label.subscribeLabels?cursor=0"])
    #expect(await storage.loadCursor() == 1)
  }

  @Test("message types the generated union does not know are skipped")
  func unknownTypeIsSkipped() async throws {
    let session = ScriptedWebSocketSession(messages: [
      TestDAGCBOR.messageFrame(type: "#somethingNew", payload: [("seq", .unsigned(1))]),
      Self.labels(seq: 2, values: ["spam"]),
    ])
    var summary: [String] = []
    for try await event in Self.subscription(ScriptedWebSocketFactory(sessions: [session])).events() {
      switch event {
      case let .ignoredFrame(frame):
        #expect(frame.type == "com.atproto.label.subscribeLabels#somethingNew")
        #expect(frame.sequence == 1)
        summary.append("ignored")
      case .message(.labels, _):
        summary.append("labels")
      default:
        summary.append("other")
      }
      if summary.count == 2 { break }
    }
    #expect(summary == ["ignored", "labels"])
  }

  @Test("FutureCursor from a labeler ends the stream with the typed error")
  func futureCursor() async throws {
    let session = ScriptedWebSocketSession(messages: [TestDAGCBOR.errorFrame(error: "FutureCursor")])
    let factory = ScriptedWebSocketFactory(sessions: [session])
    await #expect(throws: EventStreamError.futureCursor(message: nil)) {
      for try await _ in Self.subscription(factory, storage: InMemoryFirehoseCursorStorage(initialCursor: 99)).events() {}
    }
    #expect(await factory.connectedURLs.count == 1)
  }

  @Test("reconnects resume from the acknowledged cursor")
  func resumesFromCursor() async throws {
    let first = ScriptedWebSocketSession(messages: [Self.labels(seq: 1, values: ["a"]), Self.labels(seq: 2, values: ["b"])], then: FirehoseSubscriptionError.connectionClosed)
    let second = ScriptedWebSocketSession(messages: [Self.labels(seq: 2, values: ["b"]), Self.labels(seq: 3, values: ["c"])])
    let factory = ScriptedWebSocketFactory(sessions: [first, second])

    var seen: [Int64] = []
    for try await event in Self.subscription(factory).events() {
      if case let .message(_, sequence?) = event {
        seen.append(sequence)
      }
      if seen.count == 3 { break }
    }
    // The consumer came back after 2, so 2 is acknowledged; the server replays it on resume
    // (inclusive cursor) and the copy is dropped.
    #expect(seen == [1, 2, 3])
    #expect(await factory.cursors == [nil, "2"])
  }

  @Test("service URLs map to the subscription endpoint")
  func endpointURLs() {
    let relay = FirehoseSubscription(service: URL(string: "https://bsky.network")!)
    #expect(relay.configuration.url.absoluteString == "wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos")
    let local = LabelSubscription.labels(service: URL(string: "http://localhost:2584/base/")!)
    #expect(local.configuration.url.absoluteString == "ws://localhost:2584/base/xrpc/com.atproto.label.subscribeLabels")
    #expect(local.nsid == "com.atproto.label.subscribeLabels")
  }
}
