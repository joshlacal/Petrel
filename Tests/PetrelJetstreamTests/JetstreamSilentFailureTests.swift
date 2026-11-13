import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel
import PetrelFirehose
@testable import PetrelJetstream
import PetrelStreamingTestSupport
import Testing

/// Nothing the server sends, and no cursor-storage failure, disappears without a trace: every
/// frame the stream cannot use is surfaced as ``JetstreamSubscriptionEvent/ignoredFrame(_:)``
/// and storage failures end the stream with a typed error.
@Suite("Jetstream reports what it cannot use")
struct JetstreamSilentFailureTests {
  static let host = URL(string: "https://jetstream.test")!
  static let legacyHost = URL(string: "https://jetstream.test/subscribe")!
  static let fastBackoff = FirehoseBackoffConfiguration(initialDelay: 0.001, maxDelay: 0.002, multiplier: 1)

  struct StorageFailure: Error {}

  actor FailingStorage: FirehoseCursorStorage {
    let failsLoad: Bool
    let failsSave: Bool
    private(set) var saved: [Int64] = []

    init(failsLoad: Bool = false, failsSave: Bool = false) {
      self.failsLoad = failsLoad
      self.failsSave = failsSave
    }

    func loadCursor() async throws -> Int64? {
      if failsLoad { throw StorageFailure() }
      return nil
    }

    func saveCursor(_ cursor: Int64) async throws {
      if failsSave { throw StorageFailure() }
      saved.append(cursor)
    }
  }

  struct DictionaryTransport: JetstreamHTTPTransport {
    let dictionary: Data

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
      (dictionary, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }

    func download(for request: URLRequest) async throws -> (URL, HTTPURLResponse) {
      throw URLError(.unsupportedURL)
    }
  }

  static func configuration(
    _ factory: ScriptedWebSocketFactory,
    url: URL = host,
    storage: (any FirehoseCursorStorage)? = nil
  ) -> JetstreamSubscriptionConfiguration {
    JetstreamSubscriptionConfiguration(
      url: url, cursorStorage: storage, backoff: fastBackoff, sessionFactory: factory,
      httpTransport: JetstreamStreamSemanticsTests.StatusTransport(status: 426)
    )
  }

  static func message(_ payload: String) -> Data {
    Data(#"{"$type":"message","payload":\#(payload)}"#.utf8)
  }

  /// Collects the first `count` elements, rendered as short strings.
  static func collect(
    _ subscription: JetstreamSubscription,
    count: Int
  ) async throws -> [String] {
    var seen: [String] = []
    for try await element in subscription.events() {
      seen.append(describe(element))
      if seen.count == count { break }
    }
    return seen
  }

  static func describe(_ element: JetstreamSubscriptionEvent) -> String {
    switch element {
    case let .event(event): return "event \(event.seq ?? -1)"
    case let .streamError(name, _): return "error \(name)"
    case let .ignoredFrame(frame):
      let reason: String
      switch frame.reason {
      case .malformedFrame: reason = "malformed"
      case .unknownType: reason = "unknown"
      case .undecodablePayload: reason = "undecodable"
      case .undecompressable: reason = "undecompressable"
      case let .duplicateSequence(seq): reason = "duplicate \(seq)"
      }
      return "ignored \(frame.type ?? "-") \(frame.sequence.map(String.init) ?? "-") \(reason)"
    }
  }

  @Test("a frame that is not JSON is reported and the stream continues")
  func malformedFrameIsReported() async throws {
    let factory = ScriptedWebSocketFactory(sessions: [
      ScriptedWebSocketSession(messages: [Data("{not json".utf8), JetstreamStreamSemanticsTests.commit(seq: 2)]),
    ])
    let seen = try await Self.collect(JetstreamSubscription(configuration: Self.configuration(factory)), count: 2)
    #expect(seen == ["ignored - - malformed", "event 2"])
    #expect(await factory.connectedURLs.count == 1)
  }

  @Test("uncompressed JSON with leading whitespace still decodes")
  func whitespacePrefixedJSONDecodes() async throws {
    let padded = Data(" \n".utf8) + JetstreamStreamSemanticsTests.commit(seq: 3)
    let factory = ScriptedWebSocketFactory(sessions: [ScriptedWebSocketSession(messages: [padded])])
    let seen = try await Self.collect(JetstreamSubscription(configuration: Self.configuration(factory)), count: 1)
    #expect(seen == ["event 3"])
  }

  @Test("an ignored frame whose seq is not a positive integer is reported without moving the cursor")
  func invalidIgnoredSequenceDoesNotMoveCursor() async throws {
    let fractional = Self.message(#"{"$type":"network.bsky.jetstream.subscribeEvents#future","seq":1000000.5}"#)
    let storage = InMemoryFirehoseCursorStorage()
    let factory = ScriptedWebSocketFactory(sessions: [
      ScriptedWebSocketSession(messages: [fractional, JetstreamStreamSemanticsTests.commit(seq: 7)]),
    ])
    var seen: [String] = []
    for try await element in JetstreamSubscription(configuration: Self.configuration(factory, storage: storage)).events() {
      seen.append(Self.describe(element))
      if seen.count == 2 { break }
    }
    // seq 7 is below the truncated 1000000 and must not be dropped as a duplicate.
    #expect(seen == ["ignored future - unknown", "event 7"])
    #expect(await storage.loadCursor() == nil)
  }

  @Test("only positive JSON integers are positions")
  func positionParsing() throws {
    let object = try #require(JSONSerialization.jsonObject(with: Data("""
    {"int":27060984573,"time":1725911162329308,"frac":1000000.5,"zero":0,"neg":-3,"t":true,"f":false,\
    "s":"5","big":9007199254740993,"one":1}
    """.utf8)) as? [String: Any])
    #expect(JetstreamWire.positiveInteger(object["int"]) == 27_060_984_573)
    #expect(JetstreamWire.positiveInteger(object["time"]) == 1_725_911_162_329_308)
    #expect(JetstreamWire.positiveInteger(object["one"]) == 1)
    for key in ["frac", "zero", "neg", "t", "f", "s", "big", "missing"] {
      #expect(JetstreamWire.positiveInteger(object[key]) == nil, "\(key)")
    }
  }

  @Test("a known message type with an invalid body is reported, and the cursor moves past it")
  func undecodableKnownTypeIsReported() async throws {
    // A commit without `rkey`.
    let broken = Self.message("""
    {"$type":"network.bsky.jetstream.subscribeEvents#commit","seq":5,"did":"did:plc:testuser",\
    "time":"2026-08-27T12:00:00.000000Z","rev":"rev123","operation":"create","collection":"app.bsky.feed.post"}
    """)
    let storage = InMemoryFirehoseCursorStorage()
    let factory = ScriptedWebSocketFactory(sessions: [
      ScriptedWebSocketSession(messages: [broken, JetstreamStreamSemanticsTests.commit(seq: 6)]),
    ])
    var seen: [String] = []
    for try await element in JetstreamSubscription(configuration: Self.configuration(factory, storage: storage)).events() {
      seen.append(Self.describe(element))
      if seen.count == 1 {
        guard case let .ignoredFrame(frame) = element, case let .undecodablePayload(detail) = frame.reason else {
          Issue.record("expected an undecodable-payload report, got \(element)")
          break
        }
        #expect(detail.contains("rkey"))
      }
      if seen.count == 2 { break }
    }
    #expect(seen == ["ignored commit 5 undecodable", "event 6"])
    // Pulling the second element persisted the first one's position.
    #expect(await storage.loadCursor() == 5)
  }

  @Test("an unknown payload type is reported as unknown, not dropped")
  func unknownTypeIsReported() async throws {
    let unknown = Self.message(#"{"$type":"network.bsky.jetstream.subscribeEvents#future","seq":3}"#)
    let factory = ScriptedWebSocketFactory(sessions: [
      ScriptedWebSocketSession(messages: [unknown, JetstreamStreamSemanticsTests.commit(seq: 4)]),
    ])
    let seen = try await Self.collect(JetstreamSubscription(configuration: Self.configuration(factory)), count: 2)
    #expect(seen == ["ignored future 3 unknown", "event 4"])
  }

  @Test("legacy API: a commit event without a commit body is reported")
  func legacyUndecodableIsReported() async throws {
    let broken = Data(#"{"did":"did:plc:a","time_us":1725911162329308,"kind":"commit"}"#.utf8)
    let good = Data("""
    {"did":"did:plc:a","time_us":1725911162329309,"kind":"commit","commit":{"rev":"r","operation":"delete",\
    "collection":"app.bsky.feed.post","rkey":"k"}}
    """.utf8)
    let factory = ScriptedWebSocketFactory(sessions: [ScriptedWebSocketSession(messages: [broken, good])])
    let seen = try await Self.collect(
      JetstreamSubscription(configuration: Self.configuration(factory, url: Self.legacyHost)),
      count: 2
    )
    #expect(seen == ["ignored commit 1725911162329308 undecodable", "event 1725911162329309"])
  }

  @Test("a cursor that cannot be loaded ends the stream before connecting, instead of starting at the live tip")
  func loadFailureIsTerminal() async throws {
    let factory = ScriptedWebSocketFactory(sessions: [
      ScriptedWebSocketSession(messages: [JetstreamStreamSemanticsTests.commit(seq: 1)]),
    ])
    let subscription = JetstreamSubscription(configuration: Self.configuration(factory, storage: FailingStorage(failsLoad: true)))
    await #expect(throws: JetstreamSubscriptionError.self) {
      for try await _ in subscription.events() {}
    }
    do {
      for try await _ in subscription.events() {}
      Issue.record("expected a cursor storage failure")
    } catch let JetstreamSubscriptionError.cursorStorageFailure(operation, _) {
      #expect(operation == .load)
    }
    #expect(await factory.connectedURLs.isEmpty)
  }

  @Test("a cursor that cannot be saved ends the stream with a typed error")
  func saveFailureIsTerminal() async throws {
    let factory = ScriptedWebSocketFactory(sessions: [
      ScriptedWebSocketSession(messages: [JetstreamStreamSemanticsTests.commit(seq: 1), JetstreamStreamSemanticsTests.commit(seq: 2)]),
    ])
    let subscription = JetstreamSubscription(configuration: Self.configuration(factory, storage: FailingStorage(failsSave: true)))
    var seen: [String] = []
    do {
      for try await element in subscription.events() {
        seen.append(Self.describe(element))
      }
      Issue.record("expected a cursor storage failure")
    } catch let JetstreamSubscriptionError.cursorStorageFailure(operation, _) {
      #expect(operation == .save)
    }
    // The first event was delivered; saving its position when the consumer came back failed.
    #expect(seen == ["event 1"])
  }

  @Test("a compressed frame that does not decompress is reported once, without reconnecting at the same cursor")
  func undecompressableFrameDoesNotLivelock() async throws {
    let dictionary = Data(repeating: 0x42, count: 128)
    let good = try JetstreamZstd.compress(JetstreamStreamSemanticsTests.commit(seq: 8), dictionary: dictionary)
    let garbage = Data([0x28, 0xB5, 0x2F, 0xFD, 0x00, 0x01, 0x02, 0x03])
    let factory = ScriptedWebSocketFactory(sessions: [
      ScriptedWebSocketSession(messages: [garbage, good]),
      ScriptedWebSocketSession(messages: [garbage, good]),
    ])
    var configuration = Self.configuration(factory)
    configuration.compression = true
    configuration.httpTransport = DictionaryTransport(dictionary: dictionary)
    let seen = try await Self.collect(JetstreamSubscription(configuration: configuration), count: 2)
    #expect(seen == ["ignored - - undecompressable", "event 8"])
    #expect(await factory.connectedURLs.count == 1)
  }

  @Test("a sequence number repeated within one connection is reported; the inclusive replay after a reconnect is not")
  func duplicateSequenceIsReported() async throws {
    let factory = ScriptedWebSocketFactory(sessions: [
      ScriptedWebSocketSession(
        messages: [JetstreamStreamSemanticsTests.commit(seq: 1), JetstreamStreamSemanticsTests.commit(seq: 2),
                   JetstreamStreamSemanticsTests.commit(seq: 2)],
        then: URLError(.networkConnectionLost)
      ),
      ScriptedWebSocketSession(messages: [JetstreamStreamSemanticsTests.commit(seq: 2), JetstreamStreamSemanticsTests.commit(seq: 3)]),
    ])
    let seen = try await Self.collect(JetstreamSubscription(configuration: Self.configuration(factory)), count: 4)
    #expect(seen == ["event 1", "event 2", "ignored commit 2 duplicate 2", "event 3"])
    #expect(await factory.cursors == [nil, "2"])
  }
}
