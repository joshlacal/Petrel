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

    for try await event in stream {
      received.append(event)
      if case let .event(relayEvent) = event {
        try await subscription.acknowledge(relayEvent)
      }
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

    var streamError: Error?
    do {
      for try await event in stream {
        received.append(event)
      }
    } catch {
      streamError = error
    }

    XCTAssertEqual(received.count, 2)
    guard case let .event(.identity(first)) = received.first else {
      return XCTFail("expected first identity event")
    }
    XCTAssertEqual(first.seq, 10)

    guard case let .sequenceGap(expected, receivedSeq) = received.last else {
      return XCTFail("expected sequenceGap event")
    }
    XCTAssertEqual(expected, 11)
    XCTAssertEqual(receivedSeq, 15)

    XCTAssertEqual(streamError as? FirehoseSubscriptionError, .resynchronizationRequired)
    await session.waitForClose()
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

    var streamError: Error?
    do {
      for try await event in stream {
        received.append(event)
      }
    } catch {
      streamError = error
    }

    XCTAssertEqual(received.count, 1)
    guard case let .sequenceGap(expected, receivedSeq) = received.first else {
      return XCTFail("expected sequenceGap event")
    }
    XCTAssertEqual(expected, 41)
    XCTAssertEqual(receivedSeq, 50)

    XCTAssertEqual(streamError as? FirehoseSubscriptionError, .resynchronizationRequired)
    await session.waitForClose()
  }

  func testSubscriptionExposesCurrentCursor() async throws {
    let storage = InMemoryFirehoseCursorStorage()
    let subscription = FirehoseSubscription(
      url: URL(string: "wss://relay.example/xrpc/com.atproto.sync.subscribeRepos")!,
      cursorStorage: storage
    )
    let initial = await subscription.currentCursor()
    XCTAssertNil(initial)
    try await subscription.acknowledge(sequence: 43)
    let acked = await subscription.currentCursor()
    XCTAssertEqual(acked, 43)
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
    for try await _ in stream {
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

    let session1 = FakeWebSocketSession(messages: [frame1], errorAfterMessages: FirehoseSubscriptionError.connectionClosed)
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

    for try await event in stream {
      received.append(event)
      if case let .event(relayEvent) = event {
        try await subscription.acknowledge(relayEvent)
      }
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
  func testReconnectionRebasesWatermarkOnPersistedCursorAfterUnacknowledgedDelivery() async throws {
    let frame10 = try FirehoseFrameEncoder.identityFrame(
      seq: 10,
      material: .init(did: did, handle: nil, time: time)
    )
    let frame11 = try FirehoseFrameEncoder.identityFrame(
      seq: 11,
      material: .init(did: did, handle: nil, time: time)
    )
    let frame11Replay = try FirehoseFrameEncoder.identityFrame(
      seq: 11,
      material: .init(did: did, handle: nil, time: time)
    )
    let frame12 = try FirehoseFrameEncoder.identityFrame(
      seq: 12,
      material: .init(did: did, handle: nil, time: time)
    )

    let session1 = FakeWebSocketSession(messages: [frame10, frame11], errorAfterMessages: FirehoseSubscriptionError.connectionClosed)
    let session2 = FakeWebSocketSession(messages: [frame11Replay, frame12])

    let factory = FakeWebSocketFactory(sessions: [session1, session2])
    let storage = InMemoryFirehoseCursorStorage()

    let subscription = FirehoseSubscription(
      url: URL(string: "wss://relay.example/xrpc/com.atproto.sync.subscribeRepos")!,
      cursorStorage: storage,
      backoff: .init(initialDelay: 0.005, maxDelay: 0.01, multiplier: 1.5),
      sessionFactory: factory
    )

    var receivedSeqs: [Int64] = []
    let stream = subscription.events()

    for try await event in stream {
      if case let .event(.identity(ident)) = event {
        receivedSeqs.append(ident.seq)
        if ident.seq == 10 {
          try await subscription.acknowledge(sequence: 10)
        } else if receivedSeqs.count >= 3 {
          try await subscription.acknowledge(sequence: ident.seq)
        }
      }
      if receivedSeqs.count == 3 {
        break
      }
    }

    XCTAssertEqual(receivedSeqs, [10, 11, 11])
    let urls = await factory.connectedURLs
    XCTAssertEqual(urls.count, 2)
    XCTAssertNil(urls[0].query)
    XCTAssertEqual(urls[1].query, "cursor=10")
  }

  func testDuplicateSequenceTerminatesWithError() async throws {
    let frame1 = try FirehoseFrameEncoder.identityFrame(
      seq: 10,
      material: .init(did: did, handle: nil, time: time)
    )
    let frame2 = try FirehoseFrameEncoder.identityFrame(
      seq: 10,
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

    let stream = subscription.events()
    var caughtError: Error?
    do {
      for try await _ in stream {}
    } catch {
      caughtError = error
    }
    XCTAssertEqual(caughtError as? FirehoseSubscriptionError, .duplicateSequence(10))
  }

  func testSequenceRegressionTerminatesWithError() async throws {
    let frame1 = try FirehoseFrameEncoder.identityFrame(
      seq: 10,
      material: .init(did: did, handle: nil, time: time)
    )
    let frame2 = try FirehoseFrameEncoder.identityFrame(
      seq: 9,
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

    let stream = subscription.events()
    var caughtError: Error?
    do {
      for try await _ in stream {}
    } catch {
      caughtError = error
    }
    XCTAssertEqual(caughtError as? FirehoseSubscriptionError, .cursorRegression(expected: 11, received: 9))
  }

  func testFailedDurableApplicationDoesNotAdvanceCursor() async throws {
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

    let stream = subscription.events()
    var count = 0
    for try await event in stream {
      count += 1
      if count == 1 {
        // Consumer succeeds on event 1 and acknowledges it
        if case let .event(relayEvent) = event {
          try await subscription.acknowledge(relayEvent)
        }
      } else {
        // Consumer simulates application failure on event 2 and does NOT acknowledge
        break
      }
    }

    let savedCursor = await storage.loadCursor()
    // Stored cursor must remain at 1, because event 2 was never acknowledged
    XCTAssertEqual(savedCursor, 1)
  }

  func testFailedCursorSaveFailsClosed() async throws {
    actor FailingCursorStorage: FirehoseCursorStorage {
      struct Boom: Error, Equatable {}
      func loadCursor() async throws -> Int64? { nil }
      func saveCursor(_ cursor: Int64) async throws { throw Boom() }
    }

    let storage = FailingCursorStorage()
    let subscription = FirehoseSubscription(
      url: URL(string: "wss://relay.example/xrpc/com.atproto.sync.subscribeRepos")!,
      cursorStorage: storage,
      sessionFactory: FakeWebSocketFactory(sessions: [])
    )

    do {
      try await subscription.acknowledge(sequence: 1)
      XCTFail("expected storageFailure")
    } catch {
      XCTAssertEqual(error as? FirehoseSubscriptionError, .storageFailure)
    }
  }

  func testUnacknowledgedSequenceGapThrowsError() async throws {
    let storage = InMemoryFirehoseCursorStorage()
    let subscription = FirehoseSubscription(
      url: URL(string: "wss://relay.example/xrpc/com.atproto.sync.subscribeRepos")!,
      cursorStorage: storage,
      sessionFactory: FakeWebSocketFactory(sessions: [])
    )

    try await subscription.acknowledge(sequence: 1)
    // Acknowledging sequence 3 when sequence 2 was skipped
    do {
      try await subscription.acknowledge(sequence: 3)
      XCTFail("expected unacknowledgedSequenceGap")
    } catch {
      XCTAssertEqual(error as? FirehoseSubscriptionError, .unacknowledgedSequenceGap)
    }
  }

  func testConsumerCancellationClosesSocketSession() async throws {
    let frame1 = try FirehoseFrameEncoder.identityFrame(
      seq: 1,
      material: .init(did: did, handle: nil, time: time)
    )

    let session = FakeWebSocketSession(messages: [frame1])
    let factory = FakeWebSocketFactory(sessions: [session])
    let storage = InMemoryFirehoseCursorStorage()

    let subscription = FirehoseSubscription(
      url: URL(string: "wss://relay.example/xrpc/com.atproto.sync.subscribeRepos")!,
      cursorStorage: storage,
      sessionFactory: factory
    )

    let consumerTask = Task {
      for try await _ in subscription.events() {
        break
      }
    }
    _ = await consumerTask.result

    // Wait for the session's close to be signaled rather than relying on a fixed delay
    await session.waitForClose()
    let isClosed = await session.isClosed
    XCTAssertTrue(isClosed)
  }

  func testBoundedStreamOverflowTerminatesWithResynchronizationRequired() async throws {
    var frames: [Data] = []
    for i in 1 ... 10 {
      frames.append(try FirehoseFrameEncoder.identityFrame(
        seq: Int64(i),
        material: .init(did: did, handle: nil, time: time)
      ))
    }

    let session = FakeWebSocketSession(messages: frames)
    let factory = FakeWebSocketFactory(sessions: [session])
    let storage = InMemoryFirehoseCursorStorage()

    // Buffer limit of 2: producing messages without consumer reading will overflow
    let subscription = FirehoseSubscription(
      url: URL(string: "wss://relay.example/xrpc/com.atproto.sync.subscribeRepos")!,
      cursorStorage: storage,
      sessionFactory: factory,
      bufferLimit: 2
    )

    let stream = subscription.events()
    // Wait until the session has delivered enough messages to overflow the 2-slot buffer
    await session.waitForDeliveryCount(atLeast: 3)

    var caughtError: Error?
    do {
      for try await _ in stream {}
    } catch {
      caughtError = error
    }
    XCTAssertEqual(caughtError as? FirehoseSubscriptionError, .resynchronizationRequired)
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
  private var closeContinuations: [CheckedContinuation<Void, Never>] = []
  private var deliveredCount = 0
  private var deliveryContinuations: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

  init(messages: [Data], errorAfterMessages: Error? = nil) {
    self.messages = messages
    self.errorAfterMessages = errorAfterMessages
  }

  func receiveMessage() async throws -> Data {
    if isClosed {
      throw FirehoseSubscriptionError.connectionClosed
    }
    if !messages.isEmpty {
      let msg = messages.removeFirst()
      deliveredCount += 1
      notifyDeliveryWaiters()
      return msg
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
    let waiters = closeContinuations
    closeContinuations.removeAll()
    for continuation in waiters {
      continuation.resume()
    }
  }

  func waitForClose() async {
    if isClosed { return }
    await withCheckedContinuation { continuation in
      if isClosed {
        continuation.resume()
      } else {
        closeContinuations.append(continuation)
      }
    }
  }

  func waitForDeliveryCount(atLeast count: Int) async {
    if deliveredCount >= count { return }
    await withCheckedContinuation { continuation in
      if deliveredCount >= count {
        continuation.resume()
      } else {
        deliveryContinuations.append((count: count, continuation: continuation))
      }
    }
  }

  private func notifyDeliveryWaiters() {
    var pending: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    for waiter in deliveryContinuations {
      if deliveredCount >= waiter.count {
        waiter.continuation.resume()
      } else {
        pending.append(waiter)
      }
    }
    deliveryContinuations = pending
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
