import Foundation
import Petrel
@testable import PetrelFirehose
import XCTest

final class FirehoseSubscriptionTests: XCTestCase {
  private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  private let time = "2026-08-08T12:00:00.000Z"

  func testStreamReceivesAndDecodesFrames() async throws {
    let frame1 = try FirehoseFrameEncoder.identityFrame(
      seq: 1,
      material: .init(did: did, handle: "alice.test", time: time)
    )
    let frame2 = try FirehoseFrameEncoder.accountFrame(
      seq: 2,
      material: .init(did: did, active: true, status: nil, time: time)
    )

    let session = FakeWebSocketSession(messages: [frame1, frame2])
    let factory = FakeWebSocketFactory(sessions: [session])
    let storage = InMemoryFirehoseCursorStorage()

    let subscription = FirehoseSubscription(
      url: URL(string: "wss://relay.example/xrpc/com.atproto.sync.subscribeRepos")!,
      cursorStorage: storage,
      backoff: .init(initialDelay: 0.01, maxDelay: 0.02, multiplier: 1.5),
      sessionFactory: factory
    )

    var received: [FirehoseSubscriptionEvent] = []
    let stream = subscription.events()

    for await event in stream {
      received.append(event)
      if received.count == 2 {
        break
      }
    }

    XCTAssertEqual(received.count, 2)
    guard case let .event(.identity(identity)) = received[0] else {
      return XCTFail("expected identity event")
    }
    XCTAssertEqual(identity.seq, 1)
    XCTAssertEqual(identity.handle, "alice.test")

    guard case let .event(.account(account)) = received[1] else {
      return XCTFail("expected account event")
    }
    XCTAssertEqual(account.seq, 2)
    XCTAssertEqual(account.active, true)

    let savedCursor = await storage.loadCursor()
    XCTAssertEqual(savedCursor, 2)
  }

  func testSequenceGapDetectionSurfacesTypedEvent() async throws {
    let frame1 = try FirehoseFrameEncoder.identityFrame(
      seq: 10,
      material: .init(did: did, handle: nil, time: time)
    )
    let frame2 = try FirehoseFrameEncoder.identityFrame(
      seq: 15,
      material: .init(did: did, handle: nil, time: time)
    )

    let session = FakeWebSocketSession(messages: [frame1, frame2])
    let factory = FakeWebSocketFactory(sessions: [session])
    let storage = InMemoryFirehoseCursorStorage()

    let subscription = FirehoseSubscription(
      url: URL(string: "wss://relay.example/xrpc/com.atproto.sync.subscribeRepos")!,
      cursorStorage: storage,
      backoff: .init(initialDelay: 0.01, maxDelay: 0.02, multiplier: 1.5),
      sessionFactory: factory
    )

    var received: [FirehoseSubscriptionEvent] = []
    let stream = subscription.events()

    for await event in stream {
      received.append(event)
      if received.count == 3 {
        break
      }
    }

    XCTAssertEqual(received.count, 3)
    guard case let .event(.identity(first)) = received[0] else {
      return XCTFail("expected first identity event")
    }
    XCTAssertEqual(first.seq, 10)

    guard case let .sequenceGap(expected, receivedSeq) = received[1] else {
      return XCTFail("expected sequenceGap event")
    }
    XCTAssertEqual(expected, 11)
    XCTAssertEqual(receivedSeq, 15)

    guard case let .event(.identity(second)) = received[2] else {
      return XCTFail("expected second identity event")
    }
    XCTAssertEqual(second.seq, 15)
  }

  func testSequenceGapDetectionWithInitialCursor() async throws {
    let frame = try FirehoseFrameEncoder.identityFrame(
      seq: 50,
      material: .init(did: did, handle: nil, time: time)
    )

    let session = FakeWebSocketSession(messages: [frame])
    let factory = FakeWebSocketFactory(sessions: [session])
    let storage = InMemoryFirehoseCursorStorage(initialCursor: 40)

    let subscription = FirehoseSubscription(
      url: URL(string: "wss://relay.example/xrpc/com.atproto.sync.subscribeRepos")!,
      cursorStorage: storage,
      backoff: .init(initialDelay: 0.01, maxDelay: 0.02, multiplier: 1.5),
      sessionFactory: factory
    )

    var received: [FirehoseSubscriptionEvent] = []
    let stream = subscription.events()

    for await event in stream {
      received.append(event)
      if received.count == 2 {
        break
      }
    }

    XCTAssertEqual(received.count, 2)
    guard case let .sequenceGap(expected, receivedSeq) = received[0] else {
      return XCTFail("expected sequenceGap event")
    }
    XCTAssertEqual(expected, 41)
    XCTAssertEqual(receivedSeq, 50)

    guard case let .event(.identity(idEvent)) = received[1] else {
      return XCTFail("expected identity event")
    }
    XCTAssertEqual(idEvent.seq, 50)
  }

  func testCursorIsAppendedToURLOnConnect() async throws {
    let frame = try FirehoseFrameEncoder.identityFrame(
      seq: 101,
      material: .init(did: did, handle: nil, time: time)
    )

    let session = FakeWebSocketSession(messages: [frame])
    let factory = FakeWebSocketFactory(sessions: [session])
    let storage = InMemoryFirehoseCursorStorage(initialCursor: 100)

    let subscription = FirehoseSubscription(
      url: URL(string: "wss://relay.example/xrpc/com.atproto.sync.subscribeRepos")!,
      cursorStorage: storage,
      backoff: .init(initialDelay: 0.01, maxDelay: 0.02, multiplier: 1.5),
      sessionFactory: factory
    )

    let stream = subscription.events()
    for await _ in stream {
      break
    }

    let urls = await factory.connectedURLs
    XCTAssertEqual(urls.count, 1)
    XCTAssertEqual(urls.first?.query, "cursor=100")
  }

  func testReconnectionAfterErrorWithUpdatedCursor() async throws {
    let frame1 = try FirehoseFrameEncoder.identityFrame(
      seq: 10,
      material: .init(did: did, handle: nil, time: time)
    )
    let frame2 = try FirehoseFrameEncoder.identityFrame(
      seq: 11,
      material: .init(did: did, handle: nil, time: time)
    )

    // Session 1 delivers frame1, then throws error
    let session1 = FakeWebSocketSession(messages: [frame1], errorAfterMessages: FirehoseSubscriptionError.connectionClosed)
    // Session 2 delivers frame2
    let session2 = FakeWebSocketSession(messages: [frame2])

    let factory = FakeWebSocketFactory(sessions: [session1, session2])
    let storage = InMemoryFirehoseCursorStorage()

    let subscription = FirehoseSubscription(
      url: URL(string: "wss://relay.example/xrpc/com.atproto.sync.subscribeRepos")!,
      cursorStorage: storage,
      backoff: .init(initialDelay: 0.005, maxDelay: 0.01, multiplier: 1.5),
      sessionFactory: factory
    )

    var received: [FirehoseSubscriptionEvent] = []
    let stream = subscription.events()

    for await event in stream {
      received.append(event)
      if received.count == 2 {
        break
      }
    }

    XCTAssertEqual(received.count, 2)
    guard case let .event(.identity(first)) = received[0] else {
      return XCTFail("expected first identity")
    }
    XCTAssertEqual(first.seq, 10)

    guard case let .event(.identity(second)) = received[1] else {
      return XCTFail("expected second identity")
    }
    XCTAssertEqual(second.seq, 11)

    let urls = await factory.connectedURLs
    XCTAssertEqual(urls.count, 2)
    XCTAssertNil(urls[0].query)
    XCTAssertEqual(urls[1].query, "cursor=10")
  }

  func testBackoffCalculation() {
    let backoff = FirehoseBackoffConfiguration(initialDelay: 1.0, maxDelay: 8.0, multiplier: 2.0)
    XCTAssertEqual(backoff.nextDelay(after: nil), 1.0)
    XCTAssertEqual(backoff.nextDelay(after: 1.0), 2.0)
    XCTAssertEqual(backoff.nextDelay(after: 2.0), 4.0)
    XCTAssertEqual(backoff.nextDelay(after: 4.0), 8.0)
    XCTAssertEqual(backoff.nextDelay(after: 8.0), 8.0)
    XCTAssertEqual(backoff.nextDelay(after: 16.0), 8.0)
  }
}

// MARK: - Test Doubles

private actor FakeWebSocketSession: FirehoseWebSocketSession {
  private var messages: [Data]
  private let errorAfterMessages: Error?
  private(set) var isClosed = false

  init(messages: [Data], errorAfterMessages: Error? = nil) {
    self.messages = messages
    self.errorAfterMessages = errorAfterMessages
  }

  func receiveMessage() async throws -> Data {
    if isClosed {
      throw FirehoseSubscriptionError.connectionClosed
    }
    if !messages.isEmpty {
      return messages.removeFirst()
    }
    if let error = errorAfterMessages {
      throw error
    }
    // Block indefinitely until closed
    while !isClosed {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    throw FirehoseSubscriptionError.connectionClosed
  }

  func close() {
    isClosed = true
  }
}

private actor FakeWebSocketFactory: FirehoseWebSocketSessionFactory {
  private var sessions: [any FirehoseWebSocketSession]
  private(set) var connectedURLs: [URL] = []

  init(sessions: [any FirehoseWebSocketSession]) {
    self.sessions = sessions
  }

  func makeSession(url: URL) async throws -> any FirehoseWebSocketSession {
    connectedURLs.append(url)
    guard !sessions.isEmpty else {
      return FakeWebSocketSession(messages: [], errorAfterMessages: FirehoseSubscriptionError.connectionClosed)
    }
    return sessions.removeFirst()
  }
}
