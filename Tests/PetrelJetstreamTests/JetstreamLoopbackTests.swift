import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel
import PetrelFirehose
@testable import PetrelJetstream
import PetrelStreamingTestSupport
import Testing

/// `JetstreamSubscription` with its default transports (URLSession WebSocket and HTTP) against
/// a real loopback server that frames messages the way production does: JSON as WebSocket TEXT
/// messages, zstd as BINARY.
///
/// As in the firehose real-socket suite, nothing here may depend on timing: the process can
/// stall for seconds on a loaded runner. Scripts advance on observed events and the time limit
/// only turns a hang into a failure.
@Suite(
  "Jetstream over a real socket",
  .enabled("URLSession cannot open WebSockets on this platform") {
    await URLSessionWebSocketAvailability.shared.isAvailable()
  },
  .timeLimit(.minutes(3))
)
struct JetstreamLoopbackTests {
  static let fastBackoff = FirehoseBackoffConfiguration(initialDelay: 0.01, maxDelay: 0.05, multiplier: 2)
  static let v2Path = "/xrpc/network.bsky.jetstream.subscribeEvents"

  static func commit(seq: Int64) -> String {
    """
    {"$type":"message","payload":{"$type":"network.bsky.jetstream.subscribeEvents#commit",\
    "seq":\(seq),"did":"did:plc:testuser","time":"2026-08-27T12:00:00.000000Z","rev":"rev123",\
    "operation":"create","collection":"app.bsky.feed.post","rkey":"rkey123",\
    "record":{"$type":"app.bsky.feed.post","text":"hello","createdAt":"2026-08-27T12:00:00.000Z"}}}
    """
  }

  static func legacyCommit(timeUS: Int64, collection: String) -> String {
    """
    {"did":"did:plc:testuser","time_us":\(timeUS),"kind":"commit","commit":{"rev":"rev123",\
    "operation":"create","collection":"\(collection)","rkey":"rkey123",\
    "record":{"$type":"\(collection)","createdAt":"2026-08-27T12:00:00.000Z"}}}
    """
  }

  static func sequences(_ subscription: JetstreamSubscription, count: Int) async throws -> [Int64] {
    var seen: [Int64] = []
    for try await event in subscription.events() {
      if case let .event(event) = event, let seq = event.seq {
        seen.append(seq)
      }
      if seen.count == count { break }
    }
    return seen
  }

  @Test("the default configuration receives production-style TEXT frames")
  func defaultConfigurationReceivesTextFrames() async throws {
    let server = try LoopbackWebSocketServer { _, request in
      guard request.isUpgrade else { return .http(status: 426) }
      return .accept(
        subprotocol: request.headers["sec-websocket-protocol"],
        script: [.text(Self.commit(seq: 1)), .text(Self.commit(seq: 2))]
      )
    }
    defer { server.stop() }

    // No session factory, no HTTP transport: exactly what a caller gets by default.
    let subscription = JetstreamSubscription(configuration: .init(
      url: server.httpURL(),
      filter: .init(kinds: [.commit], collections: ["app.bsky.feed.post"]),
      backoff: Self.fastBackoff
    ))
    #expect(try await Self.sequences(subscription, count: 2) == [1, 2])

    let upgrade = try #require(server.upgradeRequests.first)
    #expect(upgrade.path == Self.v2Path)
    #expect(upgrade.query("kinds") == "commit")
    #expect(upgrade.query("collections") == "app.bsky.feed.post")
    #expect(upgrade.headers["sec-websocket-protocol"] == "xrpc.v1.json")
  }

  @Test("a server that does not echo the subprotocol still works")
  func subprotocolNotEchoed() async throws {
    let server = try LoopbackWebSocketServer { _, _ in .accept(script: [.text(Self.commit(seq: 7))]) }
    defer { server.stop() }
    let subscription = JetstreamSubscription(configuration: .init(url: server.httpURL(), backoff: Self.fastBackoff))
    #expect(try await Self.sequences(subscription, count: 1) == [7])
  }

  @Test("compression: the dictionary is fetched over HTTP and BINARY zstd frames decode")
  func compressedBinaryFrames() async throws {
    let dictionary = Data(repeating: 0x42, count: 128)
    let frames = try (1 ... 3).map { try JetstreamZstd.compress(Data(Self.commit(seq: $0).utf8), dictionary: dictionary) }
    let magic: [UInt8] = Array(frames[0].prefix(4))
    let zstdMagic: [UInt8] = [0x28, 0xB5, 0x2F, 0xFD]
    #expect(magic == zstdMagic)
    let server = try LoopbackWebSocketServer { _, request in
      if request.path == "/xrpc/network.bsky.jetstream.getZstdDictionary" {
        return .http(status: 200, headers: ["Content-Type": "application/octet-stream"], body: dictionary)
      }
      guard request.isUpgrade else { return .http(status: 426) }
      return .accept(script: frames.map { .binary($0) })
    }
    defer { server.stop() }

    let subscription = JetstreamSubscription(configuration: .init(
      url: server.httpURL(), compression: true, backoff: Self.fastBackoff
    ))
    #expect(try await Self.sequences(subscription, count: 3) == [1, 2, 3])
    #expect(server.requests.first?.path == "/xrpc/network.bsky.jetstream.getZstdDictionary")
  }

  @Test("a dropped connection resumes from the last sequence; the HTTP probe's 426 is not a rejection")
  func resumesAfterDrop() async throws {
    let server = try LoopbackWebSocketServer { connection, request in
      // Plain GETs come from the failure probe; answer like production.
      guard request.isUpgrade else {
        return .http(status: 426, body: Data("WebSocket protocol violation".utf8))
      }
      if connection == 0 {
        return .accept(script: [.drop])
      }
      let cursor = Int64(request.query("cursor") ?? "") ?? 10
      return cursor == 10
        ? .accept(script: [.text(Self.commit(seq: 10)), .text(Self.commit(seq: 11)), .drop])
        : .accept(script: [.text(Self.commit(seq: cursor)), .text(Self.commit(seq: cursor + 1))])
    }
    defer { server.stop() }

    let subscription = JetstreamSubscription(configuration: .init(
      url: server.httpURL(), cursor: 10, backoff: Self.fastBackoff
    ))
    #expect(try await Self.sequences(subscription, count: 3) == [10, 11, 12])
    let cursors = server.upgradeRequests.map { $0.query("cursor") }
    #expect(cursors.first == "10")
    #expect(cursors.last == "11")
  }

  @Test("an invalid request is rejected before the upgrade and reported with the server's text")
  func rejectionBeforeUpgrade() async throws {
    let server = try LoopbackWebSocketServer { _, _ in
      .http(status: 400, headers: ["Content-Type": "application/json"],
            body: Data(#"{"error":"CursorTooOld","message":"Requested seq is below retention floor"}"#.utf8))
    }
    defer { server.stop() }

    let subscription = JetstreamSubscription(configuration: .init(url: server.httpURL(), cursor: 1, backoff: Self.fastBackoff))
    await #expect(throws: JetstreamSubscriptionError.connectionRejected(
      status: 400, error: "CursorTooOld", message: "Requested seq is below retention floor"
    )) {
      for try await _ in subscription.events() {}
    }
  }

  @Test("legacy /subscribe: text events, requireHello, and options_update over the wire")
  func legacyOptionsUpdateOverTheWire() async throws {
    let server = try LoopbackWebSocketServer { _, request in
      guard request.isUpgrade else { return .http(status: 426) }
      return .accept(script: [
        // requireHello: nothing is sent until the first options_update arrives.
        .awaitClientText(count: 1),
        .text(Self.legacyCommit(timeUS: 1000, collection: "app.bsky.feed.like")),
        .awaitClientText(count: 2),
        .text(Self.legacyCommit(timeUS: 2000, collection: "app.bsky.feed.post")),
      ])
    }
    defer { server.stop() }

    var configuration = JetstreamSubscriptionConfiguration(
      url: server.webSocketURL("/subscribe"),
      filter: .init(collections: ["app.bsky.feed.like"]),
      backoff: Self.fastBackoff
    )
    configuration.requireHello = true
    let subscription = JetstreamSubscription(configuration: configuration)

    var collections: [String] = []
    for try await event in subscription.events() {
      guard case let .event(.commit(commit)) = event else { continue }
      collections.append(commit.collection)
      if collections.count == 1 {
        try await subscription.updateOptions(.init(wantedCollections: ["app.bsky.feed.post"]))
      }
      if collections.count == 2 { break }
    }
    #expect(collections == ["app.bsky.feed.like", "app.bsky.feed.post"])

    let upgrade = try #require(server.upgradeRequests.first)
    #expect(upgrade.target == "/subscribe?requireHello=true")
    #expect(upgrade.headers["sec-websocket-protocol"] == nil)
    #expect(server.receivedTexts == [
      #"{"payload":{"maxMessageSizeBytes":0,"wantedCollections":["app.bsky.feed.like"],"wantedDids":[]},"type":"options_update"}"#,
      #"{"payload":{"maxMessageSizeBytes":0,"wantedCollections":["app.bsky.feed.post"],"wantedDids":[]},"type":"options_update"}"#,
    ])
  }
}
