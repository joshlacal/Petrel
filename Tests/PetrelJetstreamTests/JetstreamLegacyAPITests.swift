import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel
import PetrelFirehose
@testable import PetrelJetstream
import PetrelStreamingTestSupport
import Testing

/// The original Jetstream API (`/subscribe`), still served in production and by self-hosted
/// instances: `wantedCollections` / `wantedDids`, `time_us` cursors, bare event objects,
/// `requireHello` and `options_update`.
@Suite("Jetstream legacy /subscribe API")
struct JetstreamLegacyAPITests {
  static let endpoint = URL(string: "wss://jetstream.test/subscribe")!
  static let fastBackoff = FirehoseBackoffConfiguration(initialDelay: 0.001, maxDelay: 0.002, multiplier: 1)

  /// Event shapes from the Jetstream README.
  static func commit(timeUS: Int64, collection: String = "app.bsky.feed.like", did: String = "did:plc:eygmaihciaxprqvxpfvl6flk") -> Data {
    Data("""
    {"did":"\(did)","time_us":\(timeUS),"kind":"commit","commit":{"rev":"3l3qo2vutsw2b",\
    "operation":"create","collection":"\(collection)","rkey":"3l3qo2vuowo2b",\
    "record":{"$type":"\(collection)","createdAt":"2024-09-09T19:46:02.102Z","subject":\
    {"cid":"bafyreidc6sydkkbchcyg62v77wbhzvb2mvytlmsychqgwf2xojjtirmzj4",\
    "uri":"at://did:plc:wa7b35aakoll7hugkrjtf3xf/app.bsky.feed.post/3l3pte3p2e325"}},\
    "cid":"bafyreidwaivazkwu67xztlmuobx35hs2lnfh3kolmgfmucldvhd3sgzcqi"}}
    """.utf8)
  }

  static let identity = Data("""
  {"did":"did:plc:ufbl4k27gp6kzas5glhz7fim","time_us":1725516665234703,"kind":"identity",\
  "identity":{"did":"did:plc:ufbl4k27gp6kzas5glhz7fim","handle":"yohenrique.bsky.social",\
  "seq":1409752997,"time":"2024-09-05T06:11:04.870Z"}}
  """.utf8)

  static let account = Data("""
  {"did":"did:plc:ufbl4k27gp6kzas5glhz7fim","time_us":1725516665333808,"kind":"account",\
  "account":{"active":true,"did":"did:plc:ufbl4k27gp6kzas5glhz7fim","seq":1409753013,\
  "time":"2024-09-05T06:11:04.870Z"}}
  """.utf8)

  static func configuration(
    _ factory: ScriptedWebSocketFactory,
    filter: JetstreamFilter = .init(),
    cursor: Int64? = nil,
    configure: (inout JetstreamSubscriptionConfiguration) -> Void = { _ in }
  ) -> JetstreamSubscriptionConfiguration {
    var configuration = JetstreamSubscriptionConfiguration(
      url: endpoint,
      filter: filter,
      cursor: cursor,
      backoff: fastBackoff,
      sessionFactory: factory,
      httpTransport: UnreachableHTTPTransport()
    )
    configure(&configuration)
    return configuration
  }

  @Test("legacy events decode, with time_us as the cursor position")
  func decodesLegacyEvents() throws {
    guard case let .message(.commit(commit)) = try JetstreamWire.decodeLegacyFrame(Self.commit(timeUS: 1_725_911_162_329_308)) else {
      Issue.record("expected a commit")
      return
    }
    #expect(commit.seq == 1_725_911_162_329_308)
    #expect(commit.timeUS == 1_725_911_162_329_308)
    #expect(commit.did == "did:plc:eygmaihciaxprqvxpfvl6flk")
    #expect(commit.operation == .create)
    #expect(commit.collection == "app.bsky.feed.like")
    #expect(commit.rkey == "3l3qo2vuowo2b")
    #expect(commit.cid == "bafyreidwaivazkwu67xztlmuobx35hs2lnfh3kolmgfmucldvhd3sgzcqi")
    #expect(commit.decodedRecord() != nil)

    guard case let .message(.identity(identity)) = try JetstreamWire.decodeLegacyFrame(Self.identity) else {
      Issue.record("expected an identity event")
      return
    }
    #expect(identity.seq == 1_725_516_665_234_703)
    #expect(identity.identity?.handle?.description == "yohenrique.bsky.social")

    guard case let .message(.account(account)) = try JetstreamWire.decodeLegacyFrame(Self.account) else {
      Issue.record("expected an account event")
      return
    }
    #expect(account.account?.active == true)

    // Unknown kinds and non-events are skipped, not fatal.
    let unknown = Data(#"{"did":"did:plc:x","time_us":1,"kind":"somethingNew"}"#.utf8)
    guard case .skipped = try JetstreamWire.decodeLegacyFrame(unknown) else {
      Issue.record("expected skipped")
      return
    }
    #expect(throws: JetstreamWireError.self) { try JetstreamWire.decodeLegacyFrame(Data("nope".utf8)) }
  }

  @Test("the dialect is inferred from the URL and can be forced")
  func dialectSelection() {
    #expect(JetstreamSubscriptionConfiguration(url: Self.endpoint).resolvedAPIVersion == .v1)
    #expect(JetstreamSubscriptionConfiguration(url: URL(string: "https://jetstream.test")!).resolvedAPIVersion == .v2)
    var forced = JetstreamSubscriptionConfiguration(url: URL(string: "https://jetstream.test")!)
    forced.apiVersion = .v1
    #expect(forced.resolvedAPIVersion == .v1)
  }

  @Test("legacy connect URL uses wantedCollections / wantedDids / time_us cursor")
  func legacyURL() async throws {
    let factory = ScriptedWebSocketFactory(sessions: [ScriptedWebSocketSession(messages: [Self.commit(timeUS: 1_725_911_162_329_308)])])
    let configuration = Self.configuration(
      factory,
      filter: .init(kinds: [.commit], dids: ["did:plc:eygmaihciaxprqvxpfvl6flk"], collections: ["app.bsky.feed.like", "app.bsky.graph.*"]),
      cursor: 1_725_911_162_329_308
    ) {
      $0.maxMessageSizeBytes = 1_000_000
    }
    for try await _ in JetstreamSubscription(configuration: configuration).events() {
      break
    }

    let url = try #require(await factory.connectedURLs.first)
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    #expect(components.scheme == "wss")
    #expect(components.path == "/subscribe")
    let items = components.queryItems ?? []
    #expect(items.filter { $0.name == "wantedCollections" }.map(\.value) == ["app.bsky.feed.like", "app.bsky.graph.*"])
    #expect(items.filter { $0.name == "wantedDids" }.map(\.value) == ["did:plc:eygmaihciaxprqvxpfvl6flk"])
    #expect(items.first { $0.name == "cursor" }?.value == "1725911162329308")
    #expect(items.first { $0.name == "maxMessageSizeBytes" }?.value == "1000000")
    // No v2-only parameters, and no JSON subprotocol offer on the legacy endpoint.
    #expect(!items.contains { ["kinds", "dids", "collections", "zstdDictionary", "compress"].contains($0.name) })
    #expect(await factory.offeredSubprotocols == [[]])
  }

  @Test("a base host with apiVersion .v1 gets /subscribe appended")
  func legacyURLFromBaseHost() {
    let url = JetstreamSubscriptionRunner.buildLegacyWebSocketURL(
      baseURL: URL(string: "https://jetstream.test/prefix")!,
      filter: .init(),
      cursor: nil,
      compress: true,
      maxMessageSizeBytes: nil,
      requireHello: false
    )
    #expect(url?.absoluteString == "wss://jetstream.test/prefix/subscribe?compress=true")
  }

  @Test("reconnect resumes from the last time_us and drops the replayed event")
  func legacyResume() async throws {
    let first = ScriptedWebSocketSession(messages: [Self.commit(timeUS: 100), Self.commit(timeUS: 200)], then: URLError(.networkConnectionLost))
    let second = ScriptedWebSocketSession(messages: [Self.commit(timeUS: 200), Self.commit(timeUS: 300)])
    let factory = ScriptedWebSocketFactory(sessions: [first, second])

    var seen: [Int64] = []
    for try await event in JetstreamSubscription(configuration: Self.configuration(factory)).events() {
      if case let .event(.commit(commit)) = event {
        seen.append(commit.timeUS)
      }
      if seen.count == 3 { break }
    }
    #expect(seen == [100, 200, 300])
    #expect(await factory.cursors == [nil, "200"])
  }

  @Test("kinds is applied client-side on the legacy API")
  func kindsFilteredClientSide() async throws {
    let session = ScriptedWebSocketSession(messages: [Self.identity, Self.account, Self.commit(timeUS: 1_725_911_162_329_308)])
    let configuration = Self.configuration(ScriptedWebSocketFactory(sessions: [session]), filter: .init(kinds: [.commit]))
    var kinds: [String] = []
    for try await event in JetstreamSubscription(configuration: configuration).events() {
      if case let .event(.commit(commit)) = event {
        kinds.append("commit \(commit.timeUS)")
      } else {
        kinds.append("other")
      }
      break
    }
    #expect(kinds == ["commit 1725911162329308"])
  }

  @Test("requireHello sends the filters as the first options_update instead of in the URL")
  func requireHello() async throws {
    let session = ScriptedWebSocketSession(messages: [Self.commit(timeUS: 1)])
    let factory = ScriptedWebSocketFactory(sessions: [session])
    let configuration = Self.configuration(
      factory, filter: .init(dids: ["did:plc:eygmaihciaxprqvxpfvl6flk"], collections: ["app.bsky.feed.like"])
    ) {
      $0.requireHello = true
    }
    for try await _ in JetstreamSubscription(configuration: configuration).events() {
      break
    }

    let url = try #require(await factory.connectedURLs.first)
    #expect(url.absoluteString == "wss://jetstream.test/subscribe?requireHello=true")
    let hello = try #require(await session.sentTexts.first)
    #expect(hello == #"{"payload":{"maxMessageSizeBytes":0,"wantedCollections":["app.bsky.feed.like"],"wantedDids":["did:plc:eygmaihciaxprqvxpfvl6flk"]},"type":"options_update"}"#)
  }

  @Test("updateOptions sends options_update on the open connection and re-filters locally")
  func updateOptions() async throws {
    let session = ScriptedWebSocketSession(messages: [
      Self.commit(timeUS: 1, collection: "app.bsky.feed.like"),
      Self.commit(timeUS: 2, collection: "app.bsky.feed.like"),
      Self.commit(timeUS: 3, collection: "app.bsky.feed.post"),
    ])
    let factory = ScriptedWebSocketFactory(sessions: [session])
    let subscription = JetstreamSubscription(
      configuration: Self.configuration(factory, filter: .init(collections: ["app.bsky.feed.like"]))
    )

    var collections: [String] = []
    for try await event in subscription.events() {
      guard case let .event(.commit(commit)) = event else { continue }
      collections.append(commit.collection)
      if collections.count == 1 {
        try await subscription.updateOptions(.init(wantedCollections: ["app.bsky.feed.post"]))
      }
      if collections.count == 2 { break }
    }
    // The second like no longer matches; the post does.
    #expect(collections == ["app.bsky.feed.like", "app.bsky.feed.post"])
    #expect(await session.sentTexts == [
      #"{"payload":{"maxMessageSizeBytes":0,"wantedCollections":["app.bsky.feed.post"],"wantedDids":[]},"type":"options_update"}"#,
    ])
  }

  @Test("options_update does not exist on the v2 API")
  func updateOptionsUnsupportedOnV2() async {
    let subscription = JetstreamSubscription(configuration: .init(url: URL(string: "https://jetstream.test")!))
    await #expect(throws: JetstreamSubscriptionError.optionsUpdateUnsupported) {
      try await subscription.updateOptions(.init())
    }
  }

  @Test("legacy compression needs the published dictionary and then decodes binary frames")
  func legacyCompression() async throws {
    let missing = Self.configuration(ScriptedWebSocketFactory(sessions: [])) { $0.compression = true }
    await #expect(throws: JetstreamSubscriptionError.missingZstdDictionary) {
      for try await _ in JetstreamSubscription(configuration: missing).events() {}
    }

    let dictionary = Data(repeating: 0x42, count: 128)
    let frame = try JetstreamZstd.compress(Self.commit(timeUS: 42), dictionary: dictionary)
    let factory = ScriptedWebSocketFactory(sessions: [ScriptedWebSocketSession(messages: [frame])])
    let configuration = Self.configuration(factory) {
      $0.compression = true
      $0.legacyZstdDictionary = dictionary
    }
    var seen: [Int64] = []
    for try await event in JetstreamSubscription(configuration: configuration).events() {
      if case let .event(.commit(commit)) = event {
        seen.append(commit.timeUS)
      }
      break
    }
    #expect(seen == [42])
    #expect(await factory.connectedURLs.first?.query == "compress=true")
  }
}

/// The legacy tests never need HTTP; reaching it is a test failure.
struct UnreachableHTTPTransport: JetstreamHTTPTransport {
  struct Unreachable: Error {}

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    throw Unreachable()
  }

  func download(for request: URLRequest) async throws -> (URL, HTTPURLResponse) {
    throw Unreachable()
  }
}
