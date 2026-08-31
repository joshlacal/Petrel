import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel
import PetrelFirehose
@testable import PetrelJetstream
import XCTest

final class SubscriptionTests: XCTestCase {
  private let testURL = URL(string: "https://jetstream.test")!
  private let fastBackoff = FirehoseBackoffConfiguration(
    initialDelay: 0.001,
    maxDelay: 0.005,
    multiplier: 1.0
  )

  func testBuiltURLContainsFilterParametersAndCursor() async throws {
    let filter = JetstreamFilter(
      kinds: [.commit, .identity],
      dids: ["did:plc:123", "did:plc:456"],
      collections: ["app.bsky.feed.post", "app.bsky.graph.*"]
    )

    let commitData = commitFrameJSON(seq: 12345, did: "did:plc:123")
    let session = FakeWebSocketSession(messages: [commitData])
    let factory = FakeWebSocketFactory(sessions: [session])
    let transport = FakeHTTPTransport()

    let config = JetstreamSubscriptionConfiguration(
      url: testURL,
      filter: filter,
      cursor: 12345,
      compression: false,
      backoff: fastBackoff,
      sessionFactory: factory,
      httpTransport: transport
    )

    let subscription = JetstreamSubscription(configuration: config)
    var receivedEvents: [JetstreamSubscriptionEvent] = []

    for try await event in subscription.events() {
      receivedEvents.append(event)
      break
    }

    XCTAssertEqual(receivedEvents.count, 1)

    let connectedURLs = await factory.getConnectedURLs()
    XCTAssertEqual(connectedURLs.count, 1)

    let url = try XCTUnwrap(connectedURLs.first)
    XCTAssertEqual(url.scheme, "wss")
    XCTAssertEqual(url.host, "jetstream.test")
    XCTAssertEqual(url.path, "/xrpc/network.bsky.jetstream.subscribeEvents")

    let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let items = try XCTUnwrap(components.queryItems)

    let kinds = items.filter { $0.name == "kinds" }.map(\.value)
    XCTAssertEqual(kinds, ["commit", "identity"])

    let dids = items.filter { $0.name == "dids" }.map(\.value)
    XCTAssertEqual(dids, ["did:plc:123", "did:plc:456"])

    let collections = items.filter { $0.name == "collections" }.map(\.value)
    XCTAssertEqual(collections, ["app.bsky.feed.post", "app.bsky.graph.*"])

    let cursor = items.first(where: { $0.name == "cursor" })?.value
    XCTAssertEqual(cursor, "12345")
  }

  func testDeduplicationDropsSeqBelowInitialCursorAndPreventsDuplicatesOnReconnect() async throws {
    // Initial cursor 100 -> initial lastSeq = 99.
    // Session 1: frames 98, 99, 100, 101, then disconnects.
    // Session 2: connects with cursor 101, replays 101, then 102.
    let session1 = FakeWebSocketSession(
      messages: [
        commitFrameJSON(seq: 98),
        commitFrameJSON(seq: 99),
        commitFrameJSON(seq: 100),
        commitFrameJSON(seq: 101),
      ],
      errorAfterMessages: URLError(.networkConnectionLost)
    )

    let session2 = FakeWebSocketSession(
      messages: [
        commitFrameJSON(seq: 101), // Replayed by server; should be dropped by dedup
        commitFrameJSON(seq: 102),
      ]
    )

    let factory = FakeWebSocketFactory(sessions: [session1, session2])
    let transport = FakeHTTPTransport()

    let config = JetstreamSubscriptionConfiguration(
      url: testURL,
      cursor: 100,
      backoff: fastBackoff,
      sessionFactory: factory,
      httpTransport: transport
    )

    let subscription = JetstreamSubscription(configuration: config)
    var emittedSeqs: [Int64] = []

    for try await event in subscription.events() {
      if case let .event(jetstreamEvent) = event, let seq = jetstreamEvent.seq {
        emittedSeqs.append(seq)
        if emittedSeqs.count == 3 {
          break
        }
      }
    }

    XCTAssertEqual(emittedSeqs, [100, 101, 102])

    let connectedURLs = await factory.getConnectedURLs()
    XCTAssertEqual(connectedURLs.count, 2)

    let url1 = try XCTUnwrap(connectedURLs.first)
    let comp1 = try XCTUnwrap(URLComponents(url: url1, resolvingAgainstBaseURL: false))
    XCTAssertEqual(comp1.queryItems?.first(where: { $0.name == "cursor" })?.value, "100")

    let url2 = try XCTUnwrap(connectedURLs.last)
    let comp2 = try XCTUnwrap(URLComponents(url: url2, resolvingAgainstBaseURL: false))
    XCTAssertEqual(comp2.queryItems?.first(where: { $0.name == "cursor" })?.value, "101")
  }

  func testErrorFrameYieldsStreamErrorAndReconnectsWithUpdatedCursor() async throws {
    let session1 = FakeWebSocketSession(
      messages: [
        commitFrameJSON(seq: 50),
        commitFrameJSON(seq: 51),
        errorFrameJSON(name: "ConsumerTooSlow", message: "reading too slowly"),
      ]
    )

    let session2 = FakeWebSocketSession(
      messages: [
        commitFrameJSON(seq: 52),
      ]
    )

    let factory = FakeWebSocketFactory(sessions: [session1, session2])
    let transport = FakeHTTPTransport()

    let config = JetstreamSubscriptionConfiguration(
      url: testURL,
      cursor: 50,
      backoff: fastBackoff,
      sessionFactory: factory,
      httpTransport: transport
    )

    let subscription = JetstreamSubscription(configuration: config)
    var receivedEvents: [JetstreamSubscriptionEvent] = []

    for try await event in subscription.events() {
      receivedEvents.append(event)
      if receivedEvents.count == 4 {
        break
      }
    }

    XCTAssertEqual(receivedEvents.count, 4)

    // Check event 0: commit 50
    if case let .event(e) = receivedEvents[0] {
      XCTAssertEqual(e.seq, 50)
    } else {
      XCTFail("Expected event at index 0")
    }

    // Check event 1: commit 51
    if case let .event(e) = receivedEvents[1] {
      XCTAssertEqual(e.seq, 51)
    } else {
      XCTFail("Expected event at index 1")
    }

    // Check event 2: streamError
    if case let .streamError(name, message) = receivedEvents[2] {
      XCTAssertEqual(name, "ConsumerTooSlow")
      XCTAssertEqual(message, "reading too slowly")
    } else {
      XCTFail("Expected streamError at index 2")
    }

    // Check event 3: commit 52
    if case let .event(e) = receivedEvents[3] {
      XCTAssertEqual(e.seq, 52)
    } else {
      XCTFail("Expected event at index 3")
    }

    let connectedURLs = await factory.getConnectedURLs()
    XCTAssertEqual(connectedURLs.count, 2)

    let url2 = try XCTUnwrap(connectedURLs.last)
    let comp2 = try XCTUnwrap(URLComponents(url: url2, resolvingAgainstBaseURL: false))
    XCTAssertEqual(comp2.queryItems?.first(where: { $0.name == "cursor" })?.value, "51")
  }

  func testCompressedBinaryFrameDecodesWithDictionary() async throws {
    let dictionaryData = Data(repeating: 0x42, count: 128)

    let commitJSON = commitFrameJSON(seq: 200, did: "did:plc:compressed")
    let compressedFrame = try JetstreamZstd.compress(commitJSON, dictionary: dictionaryData)

    let session = FakeWebSocketSession(messages: [compressedFrame])
    let factory = FakeWebSocketFactory(sessions: [session])

    let transport = FakeHTTPTransport(dataHandler: { req in
      let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (dictionaryData, resp)
    })

    let config = JetstreamSubscriptionConfiguration(
      url: testURL,
      cursor: 200,
      compression: true,
      backoff: fastBackoff,
      sessionFactory: factory,
      httpTransport: transport
    )

    let subscription = JetstreamSubscription(configuration: config)
    var receivedEvents: [JetstreamSubscriptionEvent] = []

    for try await event in subscription.events() {
      receivedEvents.append(event)
      break
    }

    XCTAssertEqual(receivedEvents.count, 1)
    if case let .event(jetstreamEvent) = receivedEvents[0] {
      XCTAssertEqual(jetstreamEvent.seq, 200)
      XCTAssertEqual(jetstreamEvent.did, "did:plc:compressed")
    } else {
      XCTFail("Expected event")
    }
  }

  func testProbeClassificationOnFirstReceiveFailureThrowsConnectionRejected() async throws {
    let session = FakeWebSocketSession(messages: [], errorAfterMessages: URLError(.badServerResponse))
    let factory = FakeWebSocketFactory(sessions: [session])

    let errorJSON = """
    {
      "error": "CursorTooOld",
      "message": "Requested seq is below retention floor"
    }
    """.data(using: .utf8)!

    let transport = FakeHTTPTransport(dataHandler: { req in
      let resp = HTTPURLResponse(url: req.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
      return (errorJSON, resp)
    })

    let config = JetstreamSubscriptionConfiguration(
      url: testURL,
      cursor: 1,
      backoff: fastBackoff,
      sessionFactory: factory,
      httpTransport: transport
    )

    let subscription = JetstreamSubscription(configuration: config)

    do {
      for try await _ in subscription.events() {
        XCTFail("Stream should have thrown connectionRejected")
      }
      XCTFail("Stream did not throw")
    } catch let error as JetstreamSubscriptionError {
      XCTAssertEqual(
        error,
        .connectionRejected(
          status: 400,
          error: "CursorTooOld",
          message: "Requested seq is below retention floor"
        )
      )
    }
  }

  func testProbeClassificationWithUnknownEnvelope400ThrowsConnectionRejectedWithNilError() async throws {
    let session = FakeWebSocketSession(messages: [], errorAfterMessages: URLError(.badServerResponse))
    let factory = FakeWebSocketFactory(sessions: [session])

    let transport = FakeHTTPTransport(dataHandler: { req in
      let resp = HTTPURLResponse(url: req.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
      return ("Bad Request".data(using: .utf8)!, resp)
    })

    let config = JetstreamSubscriptionConfiguration(
      url: testURL,
      cursor: 1,
      backoff: fastBackoff,
      sessionFactory: factory,
      httpTransport: transport
    )

    let subscription = JetstreamSubscription(configuration: config)

    do {
      for try await _ in subscription.events() {
        XCTFail("Stream should have thrown connectionRejected")
      }
      XCTFail("Stream did not throw")
    } catch let error as JetstreamSubscriptionError {
      XCTAssertEqual(error, .connectionRejected(status: 400, error: nil, message: nil))
    }
  }

  func testCursorStorageLoadsInitialCursorAndSavesAdvances() async throws {
    let storage = InMemoryFirehoseCursorStorage(initialCursor: 150)
    let session = FakeWebSocketSession(messages: [
      commitFrameJSON(seq: 150),
      commitFrameJSON(seq: 151),
    ])
    let factory = FakeWebSocketFactory(sessions: [session])
    let transport = FakeHTTPTransport()

    let config = JetstreamSubscriptionConfiguration(
      url: testURL,
      cursor: nil,
      cursorStorage: storage,
      backoff: fastBackoff,
      sessionFactory: factory,
      httpTransport: transport
    )

    let subscription = JetstreamSubscription(configuration: config)
    var count = 0

    for try await _ in subscription.events() {
      count += 1
      if count == 2 {
        break
      }
    }

    XCTAssertEqual(count, 2)
    let finalCursor = await storage.loadCursor()
    XCTAssertEqual(finalCursor, 151)

    let connectedURLs = await factory.getConnectedURLs()
    let url = try XCTUnwrap(connectedURLs.first)
    let comp = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
    XCTAssertEqual(comp.queryItems?.first(where: { $0.name == "cursor" })?.value, "150")
  }

  func testInfoFrameYieldedWithoutAdvancingCursor() async throws {
    let infoJSON = """
    {
      "$type": "message",
      "payload": {
        "$type": "network.bsky.jetstream.subscribeEvents#info",
        "name": "OutdatedCursor",
        "message": "resumed from seq 1000"
      }
    }
    """.data(using: .utf8)!

    let commitJSON = commitFrameJSON(seq: 1000)
    let session = FakeWebSocketSession(messages: [infoJSON, commitJSON])
    let factory = FakeWebSocketFactory(sessions: [session])
    let transport = FakeHTTPTransport()

    let config = JetstreamSubscriptionConfiguration(
      url: testURL,
      cursor: 1000,
      backoff: fastBackoff,
      sessionFactory: factory,
      httpTransport: transport
    )

    let subscription = JetstreamSubscription(configuration: config)
    var events: [JetstreamSubscriptionEvent] = []

    for try await event in subscription.events() {
      events.append(event)
      if events.count == 2 {
        break
      }
    }

    XCTAssertEqual(events.count, 2)
    if case let .event(e1) = events[0], case let .info(info) = e1 {
      XCTAssertEqual(info.name, "OutdatedCursor")
      XCTAssertEqual(info.message, "resumed from seq 1000")
    } else {
      XCTFail("Expected info event at index 0")
    }

    if case let .event(e2) = events[1], case let .commit(commit) = e2 {
      XCTAssertEqual(commit.seq, 1000)
    } else {
      XCTFail("Expected commit event at index 1")
    }
  }

  // MARK: - Helpers

  private func commitFrameJSON(
    seq: Int64,
    did: String = "did:plc:testuser",
    time: String = "2026-08-27T12:00:00.000000Z",
    rev: String = "rev123",
    operation: String = "create",
    collection: String = "app.bsky.feed.post",
    rkey: String = "rkey123"
  ) -> Data {
    let json = """
    {
      "$type": "message",
      "payload": {
        "$type": "network.bsky.jetstream.subscribeEvents#commit",
        "seq": \(seq),
        "did": "\(did)",
        "time": "\(time)",
        "rev": "\(rev)",
        "operation": "\(operation)",
        "collection": "\(collection)",
        "rkey": "\(rkey)"
      }
    }
    """
    return json.data(using: .utf8)!
  }

  private func errorFrameJSON(name: String, message: String? = nil) -> Data {
    let msgField = message != nil ? ",\"message\":\"\(message!)\"" : ""
    let json = """
    {
      "$type": "error",
      "error": "\(name)"\(msgField)
    }
    """
    return json.data(using: .utf8)!
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
    if messages.isEmpty {
      if let error = errorAfterMessages {
        throw error
      }
      throw URLError(.cancelled)
    }
    return messages.removeFirst()
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
      throw URLError(.badServerResponse)
    }
    return sessions.removeFirst()
  }

  func getConnectedURLs() -> [URL] {
    connectedURLs
  }
}

private struct FakeHTTPTransport: JetstreamHTTPTransport {
  var dataHandler: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

  init(dataHandler: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse) = { req in
    let resp = HTTPURLResponse(url: req.url ?? URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    return (Data(), resp)
  }) {
    self.dataHandler = dataHandler
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    try await dataHandler(request)
  }

  func download(for request: URLRequest) async throws -> (URL, HTTPURLResponse) {
    let resp = HTTPURLResponse(url: request.url ?? URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try Data().write(to: tempURL)
    return (tempURL, resp)
  }
}
