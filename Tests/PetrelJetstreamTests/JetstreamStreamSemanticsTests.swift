import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel
import PetrelFirehose
@testable import PetrelJetstream
import PetrelStreamingTestSupport
import Testing

/// v2 stream behaviour that does not need a socket: error frames, cursor kinds, probe
/// classification, backpressure.
@Suite("Jetstream v2 stream semantics")
struct JetstreamStreamSemanticsTests {
  static let host = URL(string: "https://jetstream.test")!
  static let fastBackoff = FirehoseBackoffConfiguration(initialDelay: 0.001, maxDelay: 0.002, multiplier: 1)

  static func commit(seq: Int64) -> Data {
    Data("""
    {"$type":"message","payload":{"$type":"network.bsky.jetstream.subscribeEvents#commit",\
    "seq":\(seq),"did":"did:plc:testuser","time":"2026-08-27T12:00:00.000000Z","rev":"rev123",\
    "operation":"create","collection":"app.bsky.feed.post","rkey":"rkey123"}}
    """.utf8)
  }

  static func error(_ name: String, _ message: String) -> Data {
    Data(#"{"$type":"error","error":"\#(name)","message":"\#(message)"}"#.utf8)
  }

  struct StatusTransport: JetstreamHTTPTransport {
    let status: Int
    var body = Data()

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
      (body, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    func download(for request: URLRequest) async throws -> (URL, HTTPURLResponse) {
      throw URLError(.unsupportedURL)
    }
  }

  static func configuration(
    _ factory: ScriptedWebSocketFactory,
    cursor: Int64? = nil,
    storage: (any FirehoseCursorStorage)? = nil,
    transport: any JetstreamHTTPTransport = StatusTransport(status: 426)
  ) -> JetstreamSubscriptionConfiguration {
    JetstreamSubscriptionConfiguration(
      url: host, cursor: cursor, cursorStorage: storage, backoff: fastBackoff,
      sessionFactory: factory, httpTransport: transport
    )
  }

  @Test("an error frame is surfaced, closes the socket, and ends the stream with a typed error")
  func errorFrameIsTerminal() async throws {
    let session = ScriptedWebSocketSession(messages: [Self.commit(seq: 1), Self.error("FutureCursor", "cursor ahead of stream")])
    let factory = ScriptedWebSocketFactory(sessions: [session])

    var received: [String] = []
    await #expect(throws: EventStreamError.futureCursor(message: "cursor ahead of stream")) {
      for try await event in JetstreamSubscription(configuration: Self.configuration(factory)).events() {
        switch event {
        case let .event(event): received.append("event \(event.seq ?? -1)")
        case let .streamError(name, _): received.append("error \(name)")
        case .ignoredFrame: received.append("ignored")
        }
      }
    }
    #expect(received == ["event 1", "error FutureCursor"])
    #expect(await session.isClosed)
    #expect(await factory.connectedURLs.count == 1)
  }

  @Test("JetstreamClient propagates a terminal error frame instead of reconnecting forever")
  func clientPropagatesTerminalError() async throws {
    let session = ScriptedWebSocketSession(messages: [Self.commit(seq: 1), Self.error("ConsumerTooSlow", "too slow")])
    let factory = ScriptedWebSocketFactory(sessions: [session])
    let client = JetstreamClient(configuration: .init(
      host: Self.host, mode: .live(), transport: StatusTransport(status: 426),
      sessionFactory: factory, backoff: Self.fastBackoff
    ))

    var cursors: [Int64] = []
    await #expect(throws: EventStreamError.consumerTooSlow(message: "too slow")) {
      for try await batch in client.events() {
        cursors.append(batch.lastCursor)
      }
    }
    #expect(cursors == [1])
    #expect(await factory.connectedURLs.count == 1)
  }

  @Test("an info event before the first sequence number does not store a timestamp cursor", .timeLimit(.minutes(5)))
  func timestampCursorStaysOutOfPersistence() async throws {
    let timestamp: Int64 = 1_725_911_162_329_308
    let info = Data(#"{"$type":"message","payload":{"$type":"network.bsky.jetstream.subscribeEvents#info","name":"OutdatedCursor"}}"#.utf8)
    let factory = ScriptedWebSocketFactory(sessions: [
      ScriptedWebSocketSession(messages: [info, Self.commit(seq: 10), Self.commit(seq: 11)]),
    ])
    let storage = InMemoryFirehoseCursorStorage()
    let client = JetstreamClient(configuration: .init(
      host: Self.host, mode: .live(cursor: timestamp), cursorStorage: storage,
      transport: StatusTransport(status: 426), sessionFactory: factory, backoff: Self.fastBackoff
    ))
    var batches = 0
    for try await _ in client.events() {
      batches += 1
      // Asking for the third batch is what persists the second one (seq 10).
      if batches == 3 { break }
    }
    #expect(await storage.loadCursor() == 10)
  }

  @Test("the v2 connection offers the xrpc.v1.json subprotocol")
  func offersJSONSubprotocol() async throws {
    let factory = ScriptedWebSocketFactory(sessions: [ScriptedWebSocketSession(messages: [Self.commit(seq: 1)])])
    for try await _ in JetstreamSubscription(configuration: Self.configuration(factory)).events() {
      break
    }
    #expect(await factory.offeredSubprotocols == [["xrpc.v1.json"]])
  }

  @Test("a unix-microsecond cursor on the v2 API does not drop the events that follow")
  func timestampCursor() async throws {
    let cursor: Int64 = 1_725_911_162_329_308
    let factory = ScriptedWebSocketFactory(sessions: [
      ScriptedWebSocketSession(messages: [Self.commit(seq: 27_060_984_573), Self.commit(seq: 27_060_984_574)]),
    ])
    var seen: [Int64] = []
    for try await event in JetstreamSubscription(configuration: Self.configuration(factory, cursor: cursor)).events() {
      if case let .event(event) = event, let seq = event.seq {
        seen.append(seq)
      }
      if seen.count == 2 { break }
    }
    #expect(seen == [27_060_984_573, 27_060_984_574])
    #expect(await factory.cursors == [String(cursor)])
  }

  @Test("426 from the HTTP probe means the endpoint is healthy: the connection is retried")
  func probe426IsNotTerminal() async throws {
    // What production answers to a plain GET with valid parameters.
    let factory = ScriptedWebSocketFactory([
      .failure(URLError(.badServerResponse)),
      .session(ScriptedWebSocketSession(messages: [], then: URLError(.networkConnectionLost))),
      .session(ScriptedWebSocketSession(messages: [Self.commit(seq: 5)])),
    ])
    let transport = StatusTransport(
      status: 426,
      body: Data(#"WebSocket protocol violation: Connection header "" does not contain Upgrade"#.utf8)
    )
    var seen: [Int64] = []
    for try await event in JetstreamSubscription(configuration: Self.configuration(factory, transport: transport)).events() {
      if case let .event(event) = event, let seq = event.seq {
        seen.append(seq)
      }
      break
    }
    #expect(seen == [5])
    #expect(await factory.connectedURLs.count == 3)
  }

  @Test("a rejected upgrade is terminal with the server's explanation")
  func rejectedUpgrade() async throws {
    let factory = ScriptedWebSocketFactory([
      .failure(FirehoseSubscriptionError.upgradeRejected(status: 400, retryAfter: nil)),
    ])
    let transport = StatusTransport(status: 400, body: Data("subscribe: invalid cursor: \"abc\"\n".utf8))
    await #expect(throws: JetstreamSubscriptionError.connectionRejected(
      status: 400, error: nil, message: "subscribe: invalid cursor: \"abc\""
    )) {
      for try await _ in JetstreamSubscription(configuration: Self.configuration(factory, transport: transport)).events() {}
    }
    #expect(await factory.connectedURLs.count == 1)
  }

  @Test("503 on upgrade is retried")
  func serviceUnavailableIsRetried() async throws {
    let factory = ScriptedWebSocketFactory([
      .failure(FirehoseSubscriptionError.upgradeRejected(status: 503, retryAfter: nil)),
      .session(ScriptedWebSocketSession(messages: [Self.commit(seq: 9)])),
    ])
    for try await _ in JetstreamSubscription(configuration: Self.configuration(factory, transport: StatusTransport(status: 503))).events() {
      break
    }
    #expect(await factory.connectedURLs.count == 2)
  }

  @Test("the socket is read only when the consumer asks, and the cursor is saved after processing")
  func backpressureAndCursor() async throws {
    let session = ScriptedWebSocketSession(messages: (1 ... 20).map { Self.commit(seq: $0) })
    let storage = InMemoryFirehoseCursorStorage()
    let subscription = JetstreamSubscription(
      configuration: Self.configuration(ScriptedWebSocketFactory(sessions: [session]), storage: storage)
    )

    var consumed = 0
    for try await _ in subscription.events() {
      consumed += 1
      #expect(await session.deliveredCount == consumed)
      // While event N is being processed, the saved cursor is N-1.
      let saved: Int64? = await storage.loadCursor()
      let expectedSaved: Int64? = consumed == 1 ? nil : Int64(consumed - 1)
      #expect(saved == expectedSaved)
      if consumed == 20 { break }
    }
    #expect(consumed == 20)
  }

  @Test("JetstreamClient buffers a bounded number of batches ahead of a slow consumer")
  func clientBackpressure() async throws {
    let session = ScriptedWebSocketSession(messages: (1 ... 200).map { Self.commit(seq: $0) })
    let client = JetstreamClient(configuration: .init(
      host: Self.host, mode: .live(), transport: StatusTransport(status: 426),
      sessionFactory: ScriptedWebSocketFactory(sessions: [session]), backoff: Self.fastBackoff
    ))

    var consumed = 0
    for try await _ in client.events() {
      consumed += 1
      if consumed == 5 {
        try await Task.sleep(nanoseconds: 50_000_000)
        // 5 consumed, at most 4 buffered, 1 waiting to be buffered, 1 being read.
        let delivered: Int = await session.deliveredCount
        let upperBound = 11
        #expect(delivered <= upperBound)
        break
      }
    }
  }
}
