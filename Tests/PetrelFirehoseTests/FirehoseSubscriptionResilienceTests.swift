import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel
@testable import PetrelFirehose
import PetrelStreamingTestSupport
import Testing

/// Stream-level behaviour required by the event-stream specification: what is skipped, what
/// ends the stream, and how the cursor moves.
@Suite("FirehoseSubscription: resilience and cursor semantics")
struct FirehoseSubscriptionResilienceTests {
  static let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  static let time = "2026-08-08T12:00:00.000Z"
  static let url = URL(string: "wss://relay.example/xrpc/com.atproto.sync.subscribeRepos")!
  static let fastBackoff = FirehoseBackoffConfiguration(initialDelay: 0.001, maxDelay: 0.002, multiplier: 1)

  static func identity(_ seq: Int64) -> Data {
    TestDAGCBOR.messageFrame(type: "#identity", payload: [
      ("seq", .int(seq)), ("did", .text(did)), ("time", .text(time)),
    ])
  }

  static func info(_ name: String) -> Data {
    TestDAGCBOR.messageFrame(type: "#info", payload: [("name", .text(name))])
  }

  static func subscription(
    _ factory: ScriptedWebSocketFactory,
    storage: any FirehoseCursorStorage = InMemoryFirehoseCursorStorage(),
    autoAcknowledge: Bool = false,
    configure: (inout FirehoseSubscriptionConfiguration) -> Void = { _ in }
  ) -> FirehoseSubscription {
    var configuration = FirehoseSubscriptionConfiguration(
      url: url,
      cursorStorage: storage,
      backoff: fastBackoff,
      sessionFactory: factory,
      autoAcknowledge: autoAcknowledge
    )
    configure(&configuration)
    return FirehoseSubscription(configuration: configuration)
  }

  static func summary(_ event: FirehoseSubscriptionEvent) -> String {
    switch event {
    case let .event(.info(info)): "info \(info.name)"
    case let .event(event): "event \(event.sequence.map(String.init) ?? "-")"
    case let .sequenceGap(expected, received): "gap \(expected)-\(received)"
    case let .ignoredFrame(frame): "ignored \(frame.type ?? "op\(frame.operation)") \(frame.sequence.map(String.init) ?? "-")"
    }
  }

  /// Collects `count` elements, or everything up to the end of the stream.
  static func collect(
    _ subscription: FirehoseSubscription, count: Int
  ) async throws -> [String] {
    var received: [String] = []
    for try await event in subscription.events() {
      received.append(summary(event))
      if received.count == count { break }
    }
    return received
  }

  // MARK: - Ignore rules

  @Test("unknown and deprecated message types are skipped and the cursor moves past them")
  func unknownTypesAreSkipped() async throws {
    let legacy = ["#handle", "#migrate", "#tombstone", "#brandNew"].enumerated().map { index, type in
      TestDAGCBOR.messageFrame(type: type, payload: [
        ("seq", .int(Int64(2 + index))), ("did", .text(Self.did)), ("time", .text(Self.time)),
      ])
    }
    var messages: [Data] = [Self.identity(1)]
    messages.append(contentsOf: legacy)
    messages.append(contentsOf: [Self.identity(6), Self.identity(7)])
    let session = ScriptedWebSocketSession(messages: messages)
    let storage = InMemoryFirehoseCursorStorage()
    let subscription = Self.subscription(ScriptedWebSocketFactory(sessions: [session]), storage: storage, autoAcknowledge: true)

    let received = try await Self.collect(subscription, count: 7)
    #expect(received == [
      "event 1", "ignored #handle 2", "ignored #migrate 3", "ignored #tombstone 4",
      "ignored #brandNew 5", "event 6", "event 7",
    ])
    // Everything up to the element before the last one was processed.
    #expect(await storage.loadCursor() == 6)
  }

  @Test("a frame with an unknown op is skipped")
  func unknownOperationIsSkipped() async throws {
    let odd = TestDAGCBOR.frame(header: .map([("op", .unsigned(3))]), payload: .map([("seq", .unsigned(2))]))
    let session = ScriptedWebSocketSession(messages: [Self.identity(1), odd, Self.identity(3)])
    let received = try await Self.collect(Self.subscription(ScriptedWebSocketFactory(sessions: [session])), count: 3)
    #expect(received == ["event 1", "ignored op3 2", "event 3"])
  }

  @Test("one payload that does not match its schema is reported and the stream continues")
  func undecodablePayloadIsReported() async throws {
    // #identity without the required `did`.
    let broken = TestDAGCBOR.messageFrame(type: "#identity", payload: [
      ("seq", .unsigned(2)), ("time", .text(Self.time)),
    ])
    let session = ScriptedWebSocketSession(messages: [Self.identity(1), broken, Self.identity(3)])
    var events: [FirehoseSubscriptionEvent] = []
    for try await event in Self.subscription(ScriptedWebSocketFactory(sessions: [session])).events() {
      events.append(event)
      if events.count == 3 { break }
    }
    let expected = FirehoseSubscriptionEvent.ignoredFrame(EventStreamIgnoredFrame(
      operation: 1, type: "#identity", sequence: 2, reason: .undecodablePayload("invalidEventBody")
    ))
    #expect(events[1] == expected)
    #expect(Self.summary(events[2]) == "event 3")
  }

  @Test("invalid framing is a hard error: the connection is dropped and not retried")
  func invalidFramingEndsTheStream() async throws {
    let session = ScriptedWebSocketSession(messages: [Self.identity(1), Data([0xA1, 0x62])])
    let factory = ScriptedWebSocketFactory(sessions: [session])
    await #expect(throws: RelayVerifierError.truncatedFrame) {
      _ = try await Self.collect(Self.subscription(factory), count: 10)
    }
    #expect(await session.isClosed)
    #expect(await factory.connectedURLs.count == 1)
  }

  // MARK: - Error frames

  @Test("FutureCursor ends the stream with a typed error instead of reconnecting forever")
  func futureCursorIsTerminal() async throws {
    let session = ScriptedWebSocketSession(messages: [
      TestDAGCBOR.errorFrame(error: "FutureCursor", message: "Cursor in the future."),
    ])
    let factory = ScriptedWebSocketFactory(sessions: [session])
    let subscription = Self.subscription(factory, storage: InMemoryFirehoseCursorStorage(initialCursor: 999))

    await #expect(throws: EventStreamError.futureCursor(message: "Cursor in the future.")) {
      _ = try await Self.collect(subscription, count: 10)
    }
    // The stream is closed right after the error frame and no second connection is made.
    #expect(await session.isClosed)
    #expect(await factory.connectedURLs.count == 1)
  }

  @Test("ConsumerTooSlow ends the stream by default")
  func consumerTooSlowIsTerminalByDefault() async throws {
    let session = ScriptedWebSocketSession(messages: [
      Self.identity(1), TestDAGCBOR.errorFrame(error: "ConsumerTooSlow"),
    ])
    let factory = ScriptedWebSocketFactory(sessions: [session])
    var received: [String] = []
    await #expect(throws: EventStreamError.consumerTooSlow(message: nil)) {
      for try await event in Self.subscription(factory).events() {
        received.append(Self.summary(event))
      }
    }
    #expect(received == ["event 1"])
    #expect(await factory.connectedURLs.count == 1)
  }

  @Test("ConsumerTooSlow reconnects from the cursor when opted in")
  func consumerTooSlowReconnectsWhenOptedIn() async throws {
    let first = ScriptedWebSocketSession(messages: [
      Self.identity(1), TestDAGCBOR.errorFrame(error: "ConsumerTooSlow"),
    ])
    let second = ScriptedWebSocketSession(messages: [Self.identity(2)])
    let factory = ScriptedWebSocketFactory(sessions: [first, second])
    let subscription = Self.subscription(factory, autoAcknowledge: true) {
      $0.reconnectsOnConsumerTooSlow = true
    }
    #expect(try await Self.collect(subscription, count: 2) == ["event 1", "event 2"])
    #expect(await factory.cursors == [nil, "1"])
    #expect(await first.isClosed)
  }

  @Test("an unknown error name is surfaced with its name and message")
  func unknownErrorName() async throws {
    let session = ScriptedWebSocketSession(messages: [TestDAGCBOR.errorFrame(error: "Maintenance", message: "back soon")])
    await #expect(throws: EventStreamError.other(name: "Maintenance", message: "back soon")) {
      _ = try await Self.collect(Self.subscription(ScriptedWebSocketFactory(sessions: [session])), count: 1)
    }
  }

  // MARK: - Cursor rules

  @Test("resume is inclusive: the event at the cursor is replayed by the server and dropped")
  func inclusiveReplayIsDropped() async throws {
    // "server sends any persisted messages with greater-or-equal seq number"
    let session = ScriptedWebSocketSession(messages: [Self.identity(100), Self.identity(101)])
    let factory = ScriptedWebSocketFactory(sessions: [session])
    let subscription = Self.subscription(factory, storage: InMemoryFirehoseCursorStorage(initialCursor: 100))
    #expect(try await Self.collect(subscription, count: 1) == ["event 101"])
    #expect(await factory.cursors == ["100"])
  }

  @Test("a server that resumes exclusively (seq > cursor) works the same")
  func exclusiveResume() async throws {
    let session = ScriptedWebSocketSession(messages: [Self.identity(101), Self.identity(102)])
    let subscription = Self.subscription(
      ScriptedWebSocketFactory(sessions: [session]),
      storage: InMemoryFirehoseCursorStorage(initialCursor: 100)
    )
    #expect(try await Self.collect(subscription, count: 2) == ["event 101", "event 102"])
  }

  @Test("cursor 0 asks for the oldest available event; its first sequence is not a gap")
  func cursorZero() async throws {
    let session = ScriptedWebSocketSession(messages: [Self.identity(5000), Self.identity(5001)])
    let factory = ScriptedWebSocketFactory(sessions: [session])
    let subscription = Self.subscription(factory, storage: InMemoryFirehoseCursorStorage(initialCursor: 0))
    #expect(try await Self.collect(subscription, count: 2) == ["event 5000", "event 5001"])
    #expect(await factory.cursors == ["0"])
  }

  @Test("an outdated cursor yields the #info message, then the oldest available events")
  func outdatedCursor() async throws {
    let session = ScriptedWebSocketSession(messages: [
      Self.info("OutdatedCursor"), Self.identity(900), Self.identity(901),
    ])
    let subscription = Self.subscription(
      ScriptedWebSocketFactory(sessions: [session]),
      storage: InMemoryFirehoseCursorStorage(initialCursor: 10)
    )
    #expect(try await Self.collect(subscription, count: 4)
      == ["info OutdatedCursor", "gap 11-900", "event 900", "event 901"])
  }

  @Test("automatic acknowledgement saves the cursor only after the consumer comes back for more")
  func autoAcknowledgeIsAtLeastOnce() async throws {
    let session = ScriptedWebSocketSession(messages: [Self.identity(1), Self.identity(2), Self.identity(3)])
    let storage = InMemoryFirehoseCursorStorage()
    let subscription = Self.subscription(ScriptedWebSocketFactory(sessions: [session]), storage: storage, autoAcknowledge: true)

    var cursorsSeenWhileProcessing: [Int64?] = []
    for try await event in subscription.events() {
      // While event N is being processed the saved cursor is still N-1: a crash here replays N.
      cursorsSeenWhileProcessing.append(await storage.loadCursor())
      if case let .event(relayEvent) = event, relayEvent.sequence == 3 { break }
    }
    let expectedCursors: [Int64?] = [nil, 1, 2]
    #expect(cursorsSeenWhileProcessing == expectedCursors)
    #expect(await subscription.currentCursor() == 2)
  }

  @Test("a reconnect without any acknowledgement resumes from the last delivered sequence")
  func reconnectWithoutAcknowledgementDoesNotSkip() async throws {
    let first = ScriptedWebSocketSession(messages: [Self.identity(10), Self.identity(11)], then: URLError(.networkConnectionLost))
    let second = ScriptedWebSocketSession(messages: [Self.identity(11), Self.identity(12)])
    let factory = ScriptedWebSocketFactory(sessions: [first, second])

    #expect(try await Self.collect(Self.subscription(factory), count: 3) == ["event 10", "event 11", "event 12"])
    #expect(await factory.cursors == [nil, "11"])
  }

  @Test("a duplicate sequence in the middle of a connection is an error")
  func duplicateMidStream() async throws {
    let session = ScriptedWebSocketSession(messages: [Self.identity(5), Self.identity(6), Self.identity(6)])
    await #expect(throws: FirehoseSubscriptionError.duplicateSequence(6)) {
      _ = try await Self.collect(Self.subscription(ScriptedWebSocketFactory(sessions: [session])), count: 5)
    }
  }

  // MARK: - Connection failures

  @Test("429 and 5xx upgrade responses are retried, honouring Retry-After")
  func retryableUpgradeRejections() async throws {
    let session = ScriptedWebSocketSession(messages: [Self.identity(1)])
    let factory = ScriptedWebSocketFactory([
      .failure(FirehoseSubscriptionError.upgradeRejected(status: 429, retryAfter: 0.05)),
      .failure(FirehoseSubscriptionError.upgradeRejected(status: 503, retryAfter: nil)),
      .session(session),
    ])
    let started = Date()
    #expect(try await Self.collect(Self.subscription(factory), count: 1) == ["event 1"])
    #expect(await factory.connectedURLs.count == 3)
    #expect(Date().timeIntervalSince(started) >= 0.05)
  }

  @Test(
    "501 and request errors end the stream instead of retrying",
    arguments: [501, 400, 401, 403, 404]
  )
  func terminalUpgradeRejections(status: Int) async throws {
    let factory = ScriptedWebSocketFactory([
      .failure(FirehoseSubscriptionError.upgradeRejected(status: status, retryAfter: nil)),
    ])
    await #expect(throws: FirehoseSubscriptionError.upgradeRejected(status: status, retryAfter: nil)) {
      _ = try await Self.collect(Self.subscription(factory), count: 1)
    }
    #expect(await factory.connectedURLs.count == 1)
  }

  @Test("a platform without WebSocket support fails once with a clear error")
  func transportUnavailableIsTerminal() async throws {
    let error = FirehoseSubscriptionError.webSocketTransportUnavailable("WebSockets not supported by libcurl")
    let factory = ScriptedWebSocketFactory([.failure(error)])
    await #expect(throws: error) {
      _ = try await Self.collect(Self.subscription(factory), count: 1)
    }
    #expect(await factory.connectedURLs.count == 1)
  }

  @Test("the transport maps URLSession failures to typed errors")
  func transportErrorClassification() throws {
    let url = URL(string: "https://relay.example/xrpc/com.atproto.sync.subscribeRepos")!
    let rejected = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": "7"])
    let classifiedRejection = URLSessionFirehoseWebSocketSession.classify(
      URLError(.badServerResponse), response: rejected
    ) as? FirehoseSubscriptionError
    #expect(classifiedRejection == FirehoseSubscriptionError.upgradeRejected(status: 429, retryAfter: 7))

    // What swift-corelibs-foundation reports when libcurl lacks WebSocket support.
    let unsupported = URLSessionFirehoseWebSocketSession.classify(URLError(.unsupportedURL), response: nil)
    guard case .webSocketTransportUnavailable = unsupported as? FirehoseSubscriptionError else {
      Issue.record("expected webSocketTransportUnavailable, got \(unsupported)")
      return
    }

    let tooLong = NSError(domain: NSPOSIXErrorDomain, code: Int(EMSGSIZE))
    let classifiedTooLong = URLSessionFirehoseWebSocketSession.classify(tooLong, response: nil)
      as? FirehoseSubscriptionError
    #expect(classifiedTooLong == FirehoseSubscriptionError.frameTooLarge)

    let upgraded = HTTPURLResponse(url: url, statusCode: 101, httpVersion: nil, headerFields: nil)
    let passedThrough = URLSessionFirehoseWebSocketSession.classify(
      URLError(.networkConnectionLost), response: upgraded
    )
    #expect(passedThrough is URLError)
  }

  // MARK: - Cancellation and backoff

  @Test("cancelling the consuming task ends the stream and closes the socket")
  func cancellationClosesTheSocket() async throws {
    let session = ScriptedWebSocketSession(messages: [Self.identity(1)])
    let subscription = Self.subscription(ScriptedWebSocketFactory(sessions: [session]))

    let consumer = Task {
      var count = 0
      // The second element never arrives; the task is suspended in receiveMessage().
      for try await _ in subscription.events() {
        count += 1
      }
      return count
    }
    while await session.deliveredCount < 1 {
      try await Task.sleep(nanoseconds: 1_000_000)
    }
    consumer.cancel()
    #expect(try await consumer.value == 1)
    await session.waitForClose()
    #expect(await session.isClosed)
  }

  @Test("cancelling between reads closes the socket of a retained stream", .timeLimit(.minutes(1)))
  func cancellationBetweenReadsClosesRetainedStream() async throws {
    let session = ScriptedWebSocketSession(messages: [Self.identity(1), Self.identity(2)])
    let subscription = Self.subscription(ScriptedWebSocketFactory(sessions: [session]))
    let stream = subscription.events()
    let entered = AsyncStream<Void>.makeStream()
    let proceed = AsyncStream<Void>.makeStream()
    let consumer = Task {
      var count = 0
      for try await _ in stream {
        count += 1
        // Cancelled while handling the element, not while suspended in a read.
        entered.continuation.yield()
        for await _ in proceed.stream {
          break
        }
      }
      return count
    }
    for await _ in entered.stream {
      break
    }
    consumer.cancel()
    proceed.continuation.yield()
    #expect(try await consumer.value == 1)
    await session.waitForClose()
    #expect(await session.isClosed)
    withExtendedLifetime(stream) {}
  }

  @Test("the stream closes the socket on cancellation even while something else holds the pump", .timeLimit(.minutes(1)))
  func cancellationClosesSocketIndependentOfPumpLifetime() async throws {
    let session = ScriptedWebSocketSession(messages: [Self.identity(1), Self.identity(2)])
    let configuration = FirehoseSubscriptionConfiguration(
      url: Self.url,
      cursorStorage: InMemoryFirehoseCursorStorage(),
      backoff: Self.fastBackoff,
      sessionFactory: ScriptedWebSocketFactory(sessions: [session])
    )
    // The pump outlives the stream here, so its deinit cannot be what closes the socket.
    let pump = EventStreamPump<FirehoseSubscriptionEvent>(
      configuration: configuration.pumpConfiguration,
      coordinator: EventStreamCursorCoordinator(storage: configuration.cursorStorage),
      decode: FirehoseSubscription.step(for:),
      makeGap: { .sequenceGap(expected: $0, received: $1) }
    )
    let stream = pump.makeStream()
    let entered = AsyncStream<Void>.makeStream()
    let consumer = Task {
      var count = 0
      for try await _ in stream {
        count += 1
        entered.continuation.yield()
        while !Task.isCancelled {
          await Task.yield()
        }
      }
      return count
    }
    for await _ in entered.stream {
      break
    }
    consumer.cancel()
    #expect(try await consumer.value == 1)
    await session.waitForClose()
    #expect(await session.isClosed)
    withExtendedLifetime((stream, pump)) {}
  }

  @Test("dropping the stream without cancelling closes the socket")
  func droppingTheStreamClosesTheSocket() async throws {
    let session = ScriptedWebSocketSession(messages: [Self.identity(1), Self.identity(2)])
    let subscription = Self.subscription(ScriptedWebSocketFactory(sessions: [session]))
    for try await _ in subscription.events() {
      break
    }
    await session.waitForClose()
    #expect(await session.isClosed)
  }

  @Test("backoff jitter stays within its configured spread")
  func backoffJitter() {
    var backoff = FirehoseBackoffConfiguration(initialDelay: 1, maxDelay: 8, multiplier: 2)
    #expect(backoff.jitter == 0.25)
    for _ in 0 ..< 200 {
      let delay = backoff.jittered(4)
      #expect(delay >= 3 && delay <= 5)
    }
    backoff.jitter = 0
    #expect(backoff.jittered(4) == 4)
  }
}
