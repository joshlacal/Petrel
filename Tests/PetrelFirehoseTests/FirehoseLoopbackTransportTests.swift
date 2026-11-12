import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel
@testable import PetrelFirehose
import PetrelStreamingTestSupport
import Testing

/// The default `URLSession` transport against a real WebSocket server on a loopback TCP
/// socket: actual HTTP upgrade, actual RFC 6455 framing.
///
/// These tests share a process with the rest of the package, on runners where the whole
/// process can stall for seconds. None of them may depend on something happening within a
/// fixed time: the server script advances on observed events (`awaitPings`, `awaitGate`,
/// `awaitClientText`), and assertions are about what happened, not how fast. The time limit
/// only turns a hang into a failure.
@Suite(
  "FirehoseSubscription over a real socket",
  .enabled("URLSession cannot open WebSockets on this platform") {
    await URLSessionWebSocketAvailability.shared.isAvailable()
  },
  .timeLimit(.minutes(3))
)
struct FirehoseLoopbackTransportTests {
  static let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  static let time = "2026-08-08T12:00:00.000Z"
  static let path = "/xrpc/com.atproto.sync.subscribeRepos"
  static let fastBackoff = FirehoseBackoffConfiguration(initialDelay: 0.01, maxDelay: 0.05, multiplier: 2)

  static func identity(_ seq: Int64) -> Data {
    TestDAGCBOR.messageFrame(type: "#identity", payload: [
      ("seq", .int(seq)), ("did", .text(did)), ("time", .text(time)),
    ])
  }

  /// A valid `#info` frame of exactly `byteCount` bytes.
  static func infoFrame(byteCount: Int) -> Data {
    let overhead = TestDAGCBOR.messageFrame(type: "#info", payload: [
      ("name", .text("OutdatedCursor")), ("message", .text(String(repeating: "x", count: 70_000))),
    ]).count - 70_000
    let frame = TestDAGCBOR.messageFrame(type: "#info", payload: [
      ("name", .text("OutdatedCursor")),
      ("message", .text(String(repeating: "x", count: byteCount - overhead))),
    ])
    precondition(frame.count == byteCount)
    return frame
  }

  static func subscription(
    _ server: LoopbackWebSocketServer,
    storage: any FirehoseCursorStorage = InMemoryFirehoseCursorStorage(),
    options: FirehoseWebSocketOptions = .init(),
    autoAcknowledge: Bool = true
  ) -> FirehoseSubscription {
    FirehoseSubscription(
      url: server.webSocketURL(path),
      cursorStorage: storage,
      backoff: fastBackoff,
      sessionFactory: URLSessionFirehoseWebSocketFactory(options: options),
      autoAcknowledge: autoAcknowledge
    )
  }

  /// Collects `count` sequenced events. `onEvent` runs while the event is being processed,
  /// before the consumer asks for the next element.
  static func sequences(
    _ subscription: FirehoseSubscription,
    count: Int,
    onEvent: (Int64) -> Void = { _ in }
  ) async throws -> [Int64] {
    var seen: [Int64] = []
    for try await event in subscription.events() {
      if case let .event(relayEvent) = event, let sequence = relayEvent.sequence {
        seen.append(sequence)
        onEvent(sequence)
      }
      if seen.count == count { break }
    }
    return seen
  }

  @Test("binary frames arrive, and a dropped connection is resumed from the cursor")
  func receivesAndResumes() async throws {
    let server = try LoopbackWebSocketServer { connection, request in
      guard request.isUpgrade else { return .http(status: 426) }
      if connection == 0 {
        // Drop only once the test has seen event 2, so the drop cannot overtake it.
        return .accept(script: [
          .binary(Self.identity(1)), .binary(Self.identity(2)), .awaitGate("drop"), .drop,
        ])
      }
      // Inclusive resume: replay the event at the cursor, then continue.
      let cursor = Int64(request.query("cursor") ?? "") ?? 0
      return .accept(script: [.binary(Self.identity(cursor)), .binary(Self.identity(cursor + 1))])
    }
    defer { server.stop() }

    let storage = InMemoryFirehoseCursorStorage()
    let seen = try await Self.sequences(Self.subscription(server, storage: storage), count: 3) { sequence in
      // Still processing event 2 here. The cursor is saved when the loop asks for the next
      // element, which is before that request can observe the dropped connection.
      if sequence == 2 { server.openGate("drop") }
    }
    #expect(seen == [1, 2, 3])

    let upgrades = server.upgradeRequests
    #expect(upgrades.count == 2)
    #expect(upgrades[0].path == Self.path)
    #expect(upgrades[0].query("cursor") == nil)
    #expect(upgrades[1].query("cursor") == "2")
  }

  @Test("a close frame from the server leads to a reconnect")
  func reconnectsAfterCloseFrame() async throws {
    let server = try LoopbackWebSocketServer { connection, _ in
      connection == 0
        ? .accept(script: [.binary(Self.identity(1)), .awaitGate("close"), .close(code: 1001)])
        : .accept(script: [.binary(Self.identity(2))])
    }
    defer { server.stop() }
    let seen = try await Self.sequences(Self.subscription(server), count: 2) { sequence in
      if sequence == 1 { server.openGate("close") }
    }
    #expect(seen == [1, 2])
    #expect(server.upgradeRequests.count == 2)
  }

  @Test("a 3 MB frame is delivered: the transport accepts the 5 MB spec maximum")
  func largeFrameIsDelivered() async throws {
    let large = Self.infoFrame(byteCount: 3_000_000)
    let server = try LoopbackWebSocketServer { _, _ in
      .accept(script: [.binary(large), .binary(Self.identity(1))])
    }
    defer { server.stop() }

    var received: [FirehoseSubscriptionEvent] = []
    for try await event in Self.subscription(server).events() {
      received.append(event)
      if received.count == 2 { break }
    }
    guard case let .event(.info(info)) = received.first else {
      Issue.record("expected the large #info frame first, got \(received)")
      return
    }
    let messageBytes: Int = (info.message ?? "").utf8.count
    #expect(messageBytes > 2_900_000)
    let expectedLast = FirehoseSubscriptionEvent.event(
      .identity(.init(seq: 1, did: Self.did, time: Self.time, handle: nil))
    )
    #expect(received.last == expectedLast)
    // Delivered on the first connection: no reconnect loop.
    #expect(server.upgradeRequests.count == 1)
  }

  @Test("a frame above the limit ends the stream instead of reconnecting to the same frame forever")
  func oversizedFrameIsTerminal() async throws {
    let oversized = Data(repeating: 0x41, count: 5_200_000)
    let server = try LoopbackWebSocketServer { _, _ in
      .accept(script: [.binary(oversized)])
    }
    defer { server.stop() }

    await #expect(throws: FirehoseSubscriptionError.frameTooLarge) {
      for try await _ in Self.subscription(server).events() {}
    }
    #expect(server.upgradeRequests.count == 1)
  }

  @Test("a text message on a CBOR stream is rejected")
  func textFrameIsRejected() async throws {
    let server = try LoopbackWebSocketServer { _, _ in .accept(script: [.text("{}")]) }
    defer { server.stop() }
    await #expect(throws: FirehoseSubscriptionError.unsupportedMessageFormat) {
      for try await _ in Self.subscription(server).events() {}
    }
  }

  @Test("an error frame closes the connection and ends the stream")
  func errorFrameOverTheWire() async throws {
    let server = try LoopbackWebSocketServer { _, _ in
      .accept(script: [.binary(TestDAGCBOR.errorFrame(error: "FutureCursor", message: "Cursor in the future."))])
    }
    defer { server.stop() }
    await #expect(throws: EventStreamError.futureCursor(message: "Cursor in the future.")) {
      for try await _ in Self.subscription(server, storage: InMemoryFirehoseCursorStorage(initialCursor: 1 << 40)).events() {}
    }
    #expect(server.upgradeRequests.count == 1)
    #expect(server.upgradeRequests[0].query("cursor") == String(1 << 40))
  }

  @Test("429 with Retry-After is retried; the request then succeeds")
  func retriesAfter429() async throws {
    let server = try LoopbackWebSocketServer { connection, _ in
      connection == 0
        ? .http(status: 429, headers: ["Retry-After": "0"])
        : .accept(script: [.binary(Self.identity(1))])
    }
    defer { server.stop() }
    #expect(try await Self.sequences(Self.subscription(server), count: 1) == [1])
    #expect(server.requests.count == 2)
  }

  @Test("501 Not Implemented is not retried")
  func doesNotRetry501() async throws {
    let server = try LoopbackWebSocketServer { _, _ in .http(status: 501) }
    defer { server.stop() }
    await #expect(throws: FirehoseSubscriptionError.upgradeRejected(status: 501, retryAfter: nil)) {
      for try await _ in Self.subscription(server).events() {}
    }
    #expect(server.requests.count == 1)
  }

  @Test("additional headers and subprotocols reach the upgrade request")
  func headersAndSubprotocols() async throws {
    let server = try LoopbackWebSocketServer { _, request in
      .accept(subprotocol: request.headers["sec-websocket-protocol"], script: [.binary(Self.identity(1))])
    }
    defer { server.stop() }

    let factory = URLSessionFirehoseWebSocketFactory(
      options: .init(additionalHeaders: ["Authorization": "Bearer test-token"])
    )
    let session = try await factory.makeSession(url: server.webSocketURL(Self.path), subprotocols: ["xrpc.v1.json"])
    #expect(try await session.receiveMessage() == Self.identity(1))
    await session.close()

    let request = try #require(server.upgradeRequests.first)
    #expect(request.headers["authorization"] == "Bearer test-token")
    #expect(request.headers["sec-websocket-protocol"] == "xrpc.v1.json")
  }

  @Test("keep-alive pings are sent on an idle connection")
  func keepAlivePings() async throws {
    // The server stays silent until it has received three pings, then sends its one event.
    // Receiving the event therefore proves the pings, with no assumption about how long
    // three ping intervals take on this machine.
    let server = try LoopbackWebSocketServer { _, _ in
      .accept(script: [.awaitPings(count: 3), .binary(Self.identity(1))])
    }
    defer { server.stop() }
    let subscription = Self.subscription(server, options: .init(pingInterval: 0.1))
    #expect(try await Self.sequences(subscription, count: 1) == [1])
    #expect(server.pingCount >= 3)
  }

  @Test("an idle stream outlives URLSession's request timeout")
  func idleStreamStaysOpen() async throws {
    // Every connection is silent for 2.5 s before its one event, and the session's request
    // timeout is 1 s. The event can only arrive over a connection that stayed open, idle, for
    // longer than the request timeout, so receiving it is the proof; how many connections it
    // took, and how many pings were exchanged, depends on scheduling and is not asserted.
    let server = try LoopbackWebSocketServer { _, _ in
      .accept(script: [.wait(2.5), .binary(Self.identity(1))])
    }
    defer { server.stop() }

    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 1
    var factory = URLSessionFirehoseWebSocketFactory(session: URLSession(configuration: configuration))
    factory.options.pingInterval = 0.5

    let subscription = FirehoseSubscription(
      url: server.webSocketURL(Self.path), backoff: Self.fastBackoff, sessionFactory: factory
    )
    #expect(try await Self.sequences(subscription, count: 1) == [1])
  }

  @Test("cancelling the consumer closes the real socket")
  func cancellationClosesTheSocket() async throws {
    let server = try LoopbackWebSocketServer { _, _ in .accept(script: [.binary(Self.identity(1))]) }
    defer { server.stop() }
    let subscription = Self.subscription(server)

    let (firstEvent, signalFirstEvent) = AsyncStream<Void>.makeStream()
    let consumer = Task {
      var count = 0
      for try await _ in subscription.events() {
        count += 1
        signalFirstEvent.yield()
      }
      return count
    }
    for await _ in firstEvent { break }
    consumer.cancel()
    #expect(try await consumer.value == 1)
  }
}
