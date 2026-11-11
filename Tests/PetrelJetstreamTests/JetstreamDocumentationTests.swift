import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel
import PetrelFirehose
import PetrelJetstream
import PetrelStreamingTestSupport
import Testing

/// Compiled and executed counterparts of the snippets in
/// `Sources/PetrelJetstream/PetrelJetstream.docc/Jetstream.md`. If a snippet there changes,
/// change it here too.
@Suite("Documentation: Subscribing to Jetstream")
struct JetstreamDocumentationTests {
  struct NoHTTP: JetstreamHTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) { throw URLError(.notConnectedToInternet) }
    func download(for request: URLRequest) async throws -> (URL, HTTPURLResponse) { throw URLError(.notConnectedToInternet) }
  }

  @Test("Overview: filtered commits from the v2 API")
  func overview() async throws {
    let frame = Data("""
    {"$type":"message","payload":{"$type":"network.bsky.jetstream.subscribeEvents#commit",\
    "seq":27060984573,"did":"did:plc:ewvi7nxzyoun6zhxrhs64oiz","time":"2026-08-27T12:00:00.000000Z",\
    "rev":"3jzfcijpj2z2a","operation":"create","collection":"app.bsky.feed.post","rkey":"3jzfcijpj2z2a",\
    "record":{"$type":"app.bsky.feed.post","text":"hello jetstream","createdAt":"2026-08-27T12:00:00.000Z"}}}
    """.utf8)
    let factory = ScriptedWebSocketFactory(sessions: [ScriptedWebSocketSession(messages: [frame])])

    let subscription = JetstreamSubscription(configuration: .init(
      url: URL(string: "https://jetstream2.us-east.bsky.network")!,
      filter: JetstreamFilter(kinds: [.commit], collections: ["app.bsky.feed.post"]),
      sessionFactory: factory,
      httpTransport: NoHTTP()
    ))

    var texts: [String] = []
    for try await element in subscription.events() {
      guard case let .event(.commit(commit)) = element else { continue }
      #expect(commit.collection == "app.bsky.feed.post")
      #expect(commit.operation == .create)
      if case let .knownType(value)? = commit.decodedRecord(), let post = value as? AppBskyFeedPost {
        texts.append(post.text)
      }
      break
    }
    #expect(texts == ["hello jetstream"])
    #expect(await factory.connectedURLs.first?.absoluteString
      == "wss://jetstream2.us-east.bsky.network/xrpc/network.bsky.jetstream.subscribeEvents?kinds=commit&collections=app.bsky.feed.post")
  }

  @Test("Two APIs: the legacy endpoint, requireHello and updateOptions")
  func legacy() async throws {
    let like = Data("""
    {"did":"did:plc:ewvi7nxzyoun6zhxrhs64oiz","time_us":1725911162329308,"kind":"commit","commit":\
    {"rev":"3jzfcijpj2z2a","operation":"delete","collection":"app.bsky.feed.like","rkey":"3jzfcijpj2z2a"}}
    """.utf8)
    let session = ScriptedWebSocketSession(messages: [like])

    var configuration = JetstreamSubscriptionConfiguration(
      url: URL(string: "wss://jetstream2.us-east.bsky.network/subscribe")!,
      filter: JetstreamFilter(collections: ["app.bsky.feed.like"]),
      sessionFactory: ScriptedWebSocketFactory(sessions: [session]),
      httpTransport: NoHTTP()
    )
    configuration.requireHello = true
    let legacy = JetstreamSubscription(configuration: configuration)
    #expect(configuration.resolvedAPIVersion == .v1)

    for try await element in legacy.events() {
      guard case let .event(event) = element else { continue }
      // No sequence numbers on the legacy API: the position is time_us.
      #expect(event.seq == 1_725_911_162_329_308)
      try await legacy.updateOptions(JetstreamOptionsUpdate(wantedCollections: ["app.bsky.feed.post"]))
      break
    }
    #expect(await session.sentTexts.count == 2)
  }

  @Test("Backfill, then live: configuration compiles as documented")
  func client() {
    let client = JetstreamClient(configuration: .init(
      host: URL(string: "https://jetstream.example")!,
      mode: .snapshotThenLive(afterSeq: 0),
      filter: JetstreamFilter(collections: ["app.bsky.feed.post"])
    ))
    #expect(client.configuration.mode == .snapshotThenLive(afterSeq: 0))
  }
}
