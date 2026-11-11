import Foundation
import Petrel
import PetrelFirehose
import PetrelRepo
import PetrelStreamingTestSupport
import Testing

/// Compiled and executed counterparts of the snippets in
/// `Sources/PetrelFirehose/PetrelFirehose.docc/EventStreams.md`. If a snippet there changes,
/// change it here too.
@Suite("Documentation: Consuming event streams")
struct EventStreamsDocumentationTests {
  static let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
  static let time = "2026-08-08T12:00:00.000Z"

  /// A `#commit` creating one post, with its record block in the diff CAR.
  static func commitFrame() async throws -> (frame: Data, recordCID: CID) {
    let record = TestDAGCBOR.map([
      ("$type", .text("app.bsky.feed.post")), ("text", .text("hello firehose")),
      ("createdAt", .text(time)),
    ]).encoded
    let recordCID = CID.fromDAGCBOR(record)
    let commit = TestDAGCBOR.map([
      ("did", .text(did)), ("version", .unsigned(3)), ("data", .link(recordCID.bytes)),
      ("rev", .text("3jzfcijpj2z2a")), ("prev", .null), ("sig", .bytes(Data(repeating: 0, count: 64))),
    ]).encoded
    let commitCID = CID.fromDAGCBOR(commit)
    let car = try await PublicFirehoseDiffCAR.build(
      commitCID: commitCID,
      commitBytes: commit,
      newBlocks: try PublicRepositoryBlockMap(blocks: [.init(cid: recordCID, bytes: record)])
    )
    let frame = TestDAGCBOR.messageFrame(type: "#commit", payload: [
      ("seq", .unsigned(1)), ("rebase", .bool(false)), ("tooBig", .bool(false)),
      ("repo", .text(did)), ("commit", .link(commitCID.bytes)), ("rev", .text("3jzfcijpj2z2a")),
      ("since", .null), ("blocks", .bytes(car)),
      ("ops", .array([
        .map([("action", .text("create")), ("path", .text("app.bsky.feed.post/3jzfcijpj2z2a")), ("cid", .link(recordCID.bytes))]),
        .map([("action", .text("delete")), ("path", .text("app.bsky.feed.like/3jzfcijpj2z2b")), ("cid", .null)]),
      ])),
      ("blobs", .array([])), ("time", .text(time)),
    ])
    return (frame, recordCID)
  }

  @Test("Read the firehose")
  func readTheFirehose() async throws {
    let (commitFrame, recordCID) = try await Self.commitFrame()
    let frames = [
      commitFrame,
      TestDAGCBOR.messageFrame(type: "#identity", payload: [
        ("seq", .unsigned(2)), ("did", .text(Self.did)), ("time", .text(Self.time)), ("handle", .text("alice.test")),
      ]),
      TestDAGCBOR.messageFrame(type: "#account", payload: [
        ("seq", .unsigned(3)), ("did", .text(Self.did)), ("time", .text(Self.time)),
        ("active", .bool(false)), ("status", .text("deactivated")),
      ]),
    ]
    let storage = InMemoryFirehoseCursorStorage()

    // The documented initialiser, pointed at scripted frames instead of a relay.
    let documented = FirehoseSubscription(
      service: URL(string: "https://bsky.network")!,
      cursorStorage: storage,
      autoAcknowledge: true
    )
    #expect(documented.configuration.url.absoluteString == "wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos")
    let subscription = FirehoseSubscription(
      url: documented.configuration.url,
      cursorStorage: storage,
      sessionFactory: ScriptedWebSocketFactory(sessions: [ScriptedWebSocketSession(messages: frames)]),
      autoAcknowledge: true
    )

    var log: [String] = []
    for try await element in subscription.events() {
      switch element {
      case let .event(.commit(commit)):
        for operation in try commit.records() {
          log.append("\(operation.action.rawValue) \(operation.uri(repo: commit.repo)) record=\(operation.record != nil)")
          if operation.action == .create {
            #expect(operation.cid == recordCID)
            #expect(operation.collection == "app.bsky.feed.post")
            #expect(operation.recordKey == "3jzfcijpj2z2a")
            guard case let .knownType(value)? = operation.record, let post = value as? AppBskyFeedPost else {
              Issue.record("expected a decoded app.bsky.feed.post, got \(String(describing: operation.record))")
              continue
            }
            #expect(post.text == "hello firehose")
          }
        }
      case let .event(.identity(identity)):
        log.append("identity \(identity.handle ?? "-")")
      case let .event(.account(account)):
        log.append("account active=\(account.active) status=\(account.status ?? "-")")
      case .event(.sync), .event(.info), .event(.error):
        break
      case let .sequenceGap(expected, received):
        log.append("gap \(expected) \(received)")
      case let .ignoredFrame(frame):
        log.append("ignored \(frame.type ?? "-")")
      }
      if log.count == 4 { break }
    }

    #expect(log == [
      "create at://\(Self.did)/app.bsky.feed.post/3jzfcijpj2z2a record=true",
      "delete at://\(Self.did)/app.bsky.feed.like/3jzfcijpj2z2b record=false",
      "identity alice.test",
      "account active=false status=deactivated",
    ])
    #expect(await storage.loadCursor() == 2)
  }

  @Test("records() rejects a block that does not match its CID")
  func recordsCheckBlockCIDs() async throws {
    let (frame, _) = try await Self.commitFrame()
    guard case let .commit(commit) = try RelayFrameDecoder.decode(frame) else {
      Issue.record("expected a commit")
      return
    }
    // Same commit, but the create operation now names a CID whose block is a different record.
    let other = CID.fromDAGCBOR(Data([0xA0]))
    let tampered = RelayCommitEvent(
      seq: commit.seq, repo: commit.repo, commitCID: commit.commitCID, rev: commit.rev,
      since: commit.since, blocks: Data([0x01, 0x02, 0x03]),
      ops: [.init(action: .create, path: "app.bsky.feed.post/a", cid: other, prev: nil)],
      prevDataCID: nil, time: commit.time
    )
    #expect(throws: RelayVerifierError.invalidRepositoryCAR) { try tampered.records() }

    // A commit whose producer left the blocks out still lists its operations.
    let empty = RelayCommitEvent(
      seq: commit.seq, repo: commit.repo, commitCID: commit.commitCID, rev: commit.rev,
      since: nil, blocks: Data(), ops: commit.ops, prevDataCID: nil, time: commit.time
    )
    #expect(try empty.records().map { $0.record == nil } == [true, true])
  }

  @Test("Read labels, or any other subscription")
  func readLabels() async throws {
    let frame = TestDAGCBOR.messageFrame(type: "#labels", payload: [
      ("seq", .unsigned(1)),
      ("labels", .array([.map([
        ("ver", .unsigned(1)), ("src", .text("did:plc:ar7c4by46qjdydhdevvrndac")),
        ("uri", .text("at://\(Self.did)/app.bsky.feed.post/3jzfcijpj2z2a")),
        ("val", .text("spam")), ("neg", .bool(true)), ("cts", .text(Self.time)),
      ])])),
    ])
    let labels = LabelSubscription.labels(
      service: URL(string: "https://mod.bsky.app")!,
      cursorStorage: InMemoryFirehoseCursorStorage(initialCursor: 0),
      sessionFactory: ScriptedWebSocketFactory(sessions: [ScriptedWebSocketSession(messages: [frame])]),
      autoAcknowledge: true
    )

    var values: [String] = []
    for try await element in labels.events() {
      if case let .message(.labels(batch), _) = element {
        for label in batch.labels {
          values.append("\(label.neg == true ? "-" : "+")\(label.val) \(label.src.description)")
        }
        break
      }
    }
    #expect(values == ["-spam did:plc:ar7c4by46qjdydhdevvrndac"])

    let stream = EventStreamSubscription<ComAtprotoSyncSubscribeRepos.Message>(
      nsid: "com.atproto.sync.subscribeRepos",
      configuration: FirehoseSubscriptionConfiguration(
        url: URL(string: "wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos")!
      )
    )
    #expect(stream.nsid == "com.atproto.sync.subscribeRepos")
  }

  @Test("Error frames are typed")
  func typedErrorFrames() async throws {
    let subscription = FirehoseSubscription(
      url: URL(string: "wss://relay.example/xrpc/com.atproto.sync.subscribeRepos")!,
      cursorStorage: InMemoryFirehoseCursorStorage(initialCursor: 1 << 50),
      sessionFactory: ScriptedWebSocketFactory(sessions: [
        ScriptedWebSocketSession(messages: [TestDAGCBOR.errorFrame(error: "FutureCursor")]),
      ])
    )

    var outcome = "finished"
    do {
      for try await _ in subscription.events() {}
    } catch EventStreamError.futureCursor {
      outcome = "future cursor"
    } catch EventStreamError.consumerTooSlow {
      outcome = "too slow"
    }
    #expect(outcome == "future cursor")
  }

  @Test("Authentication headers and a custom transport")
  func transports() async throws {
    let token = "example-token"
    let url = URL(string: "wss://relay.example/xrpc/com.atproto.sync.subscribeRepos")!
    let factory = URLSessionFirehoseWebSocketFactory(
      options: FirehoseWebSocketOptions(additionalHeaders: ["Authorization": "Bearer \(token)"])
    )
    #expect(factory.options.additionalHeaders["Authorization"] == "Bearer example-token")
    #expect(factory.options.maximumMessageSize == 5_000_000)
    _ = FirehoseSubscription(url: url, sessionFactory: factory)

    // The "Linux" snippet: any type conforming to the two protocols is a transport.
    struct MySession: FirehoseWebSocketSession {
      let frames: ScriptedWebSocketSession
      func receiveMessage() async throws -> Data { try await frames.receiveMessage() }
      func close() async { await frames.close() }
    }
    struct MyFactory: FirehoseWebSocketSessionFactory {
      let frames: ScriptedWebSocketSession
      func makeSession(url: URL) async throws -> any FirehoseWebSocketSession { MySession(frames: frames) }
    }
    let frames = ScriptedWebSocketSession(messages: [
      TestDAGCBOR.messageFrame(type: "#identity", payload: [
        ("seq", .unsigned(1)), ("did", .text(Self.did)), ("time", .text(Self.time)),
      ]),
    ])
    let subscription = FirehoseSubscription(url: url, sessionFactory: MyFactory(frames: frames))
    var count = 0
    for try await _ in subscription.events() {
      count += 1
      break
    }
    #expect(count == 1)
    // A receive-only transport reports that it cannot send.
    await #expect(throws: FirehoseSubscriptionError.sendingUnsupported) {
      try await MySession(frames: frames).sendText("{}")
    }
  }

  @Test("Decode frames without a connection")
  func decodeFrames() throws {
    let frameData = TestDAGCBOR.messageFrame(type: "#tombstone", payload: [("seq", .unsigned(9))])
    switch try RelayFrameDecoder.decodeFrame(frameData) {
    case .event:
      Issue.record("a deprecated message type is not an event")
    case let .ignored(frame):
      #expect(frame.type == "#tombstone")
      #expect(frame.sequence == 9)
    }
  }
}
