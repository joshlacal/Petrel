import Foundation
@testable import Petrel
import Testing

@Suite("URI serialization fidelity")
struct URISerializationTests {
    @Test("Encoded URI spelling survives JSON and CBOR", arguments: [
        "https://example.com/article?author=did%3Aplc%3Aexample%2Fpost",
        "https://example.com/a%2Fb?q=a%26b%3Dc%2Bd#section%2Fone",
        "https://example.com:8443/%7euser?q=%3a%2f",
    ])
    func encodedURIStaysUnchanged(_ raw: String) throws {
        let decoded = try JSONDecoder().decode(URI.self, from: JSONEncoder().encode(raw))
        try expectSerialized(decoded, equals: raw)
    }

    @Test("Constructed URI serialization uses the supplied value")
    func constructedURIs() throws {
        let raw = "https://example.com/a%2Fb?author=did%3Aplc%3Atest"
        let url = try #require(URL(string: raw))
        try expectSerialized(URI(uriString: raw), equals: raw)
        try expectSerialized(URI(url: url), equals: url.absoluteString)
        try expectSerialized(URI(stringLiteral: raw), equals: raw)
        try expectSerialized(try #require(URI(raw)), equals: raw)

        // URI has immutable components. Changing a URL creates a new URI,
        // which must serialize that new input rather than an older value.
        var components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        components.percentEncodedQuery = "author=did%3Aplc%3Areplacement"
        let changed = try #require(components.url)
        try expectSerialized(URI(url: changed), equals: changed.absoluteString)
    }

    @Test("Malformed and whitespace-trimmed inputs keep existing behavior")
    func malformedURIBehavior() throws {
        for raw in ["", "//", "missing-scheme"] {
            let uri = URI(uriString: raw)
            try expectSerialized(uri, equals: uri.uriString())
        }
        let relative = URI(url: try #require(URL(string: "relative/path")))
        try expectSerialized(relative, equals: relative.uriString())
        try expectSerialized(URI(uriString: " https://example.com/plain "), equals: "https://example.com/plain")
    }

    @Test("Aster post stays typed through thread, JSON cache, and DAG-CBOR decoding")
    func asterPostRoundTrips() throws {
        let postData = Data(Self.asterPostJSON.utf8)
        let postObject = try JSONSerialization.jsonObject(with: postData)
        // The exact public root PostView; unrelated replies are omitted.
        let response = try JSONSerialization.data(withJSONObject: [
            "thread": ["$type": "app.bsky.feed.defs#threadViewPost", "post": postObject, "replies": []],
        ])
        let output = try JSONDecoder().decode(AppBskyFeedGetPostThread.Output.self, from: response)
        guard case let .appBskyFeedDefsThreadViewPost(thread) = output.thread else {
            Issue.record("Expected the public Aster thread")
            return
        }
        try expectTypedPost(thread.post)
        let cached = try JSONEncoder().encode(output)
        let restored = try JSONDecoder().decode(AppBskyFeedGetPostThread.Output.self, from: cached)
        guard case let .appBskyFeedDefsThreadViewPost(restoredThread) = restored.thread else {
            Issue.record("Expected the cached Aster thread")
            return
        }
        try expectTypedPost(restoredThread.post)
        let recordBytes = try thread.post.record.encodedDAGCBOR()
        let record = try ATProtocolValueContainer.decodedFromDAGCBOR(recordBytes)
        let typed = try #require(record.decoded(AppBskyFeedPost.self))
        #expect(typed.text == thread.post.record.decoded(AppBskyFeedPost.self)?.text)
    }

    @Test("Ordinary encoded links stay typed without standard.site references")
    func ordinaryEncodedLinkRoundTrips() throws {
        var post = try #require(JSONSerialization.jsonObject(with: Data(Self.asterPostJSON.utf8)) as? [String: Any])
        var record = try #require(post["record"] as? [String: Any])
        var embed = try #require(record["embed"] as? [String: Any])
        var external = try #require(embed["external"] as? [String: Any])
        let raw = "https://example.com/article?author=did%3Aplc%3Aexample%2Fpost"
        external["uri"] = raw
        external.removeValue(forKey: "associatedRefs")
        embed["external"] = external
        record["embed"] = embed
        post["record"] = record
        post.removeValue(forKey: "embed")
        let view = try JSONDecoder().decode(AppBskyFeedDefs.PostView.self, from: JSONSerialization.data(withJSONObject: post))
        let feedPost = try #require(view.record.decoded(AppBskyFeedPost.self))
        guard case let .appBskyEmbedExternal(decodedEmbed) = feedPost.embed else {
            Issue.record("Expected an ordinary external link")
            return
        }
        #expect(decodedEmbed.external.associatedRefs == nil)
        try expectSerialized(decodedEmbed.external.uri, equals: raw)
        let restored = try JSONDecoder().decode(AppBskyFeedDefs.PostView.self, from: JSONEncoder().encode(view))
        #expect(restored.record.decoded(AppBskyFeedPost.self)?.text == feedPost.text)
        let cbor = try ATProtocolValueContainer.decodedFromDAGCBOR(view.record.encodedDAGCBOR())
        #expect(cbor.decoded(AppBskyFeedPost.self)?.text == feedPost.text)
    }

    private func expectSerialized(_ uri: URI, equals raw: String) throws {
        #expect(try JSONDecoder().decode(String.self, from: JSONEncoder().encode(uri)) == raw)
        #expect(try uri.toCBORValue() as? String == raw)
    }

    private func expectTypedPost(_ view: AppBskyFeedDefs.PostView) throws {
        let record = try #require(view.record.decoded(AppBskyFeedPost.self))
        #expect(record.text.hasPrefix("The modern research ecosystem"))
        guard case let .appBskyEmbedExternal(embed) = record.embed,
              case let .appBskyEmbedExternalView(hydrated) = view.embed else {
            Issue.record("Expected the Aster record and hydrated external embeds")
            return
        }
        try expectSerialized(embed.external.uri, equals: Self.asterURI)
        try expectSerialized(hydrated.external.uri, equals: Self.asterURI)
        #expect(embed.external.associatedRefs?.count == 2)
        #expect(hydrated.external.source?.title == "Aster Blog")
    }

    private static let asterURI = "https://blog.aster.place/3mwqgs7dp2s2a?utm_source=bluesky&utm_medium=social&utm_campaign=publish&utm_content=did%3Aplc%3Aifn645rwvsuolxg7o3w7ouo4%2F3mwqgsd4cgs2a"

    // Public https://bsky.app/profile/aster.id/post/3mwqgsd4cgs2a PostView.
    private static let asterPostJSON = #"""
    {
      "uri": "at://did:plc:ifn645rwvsuolxg7o3w7ouo4/app.bsky.feed.post/3mwqgsd4cgs2a",
      "cid": "bafyreiesf6zo5wqojuoxdekbqap7pqev6t6xa2q5kzayntr6bgrt2ixi7m",
      "author": {
        "did": "did:plc:ifn645rwvsuolxg7o3w7ouo4",
        "handle": "aster.id",
        "displayName": "Aster ID",
        "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:ifn645rwvsuolxg7o3w7ouo4/bafkreicid7hoyx5d2if24eryyhb3lg4ioy2mdrmiriga3k2cay6k5io4ta",
        "associated": {
          "chat": {
            "allowIncoming": "all",
            "allowGroupInvites": "all"
          },
          "activitySubscription": {
            "allowSubscriptions": "followers"
          }
        },
        "labels": [],
        "createdAt": "2026-08-31T07:23:03.599Z"
      },
      "record": {
        "$type": "app.bsky.feed.post",
        "createdAt": "2026-09-30T13:22:23.989Z",
        "embed": {
          "$type": "app.bsky.embed.external",
          "external": {
            "associatedRefs": [
              {
                "$type": "com.atproto.repo.strongRef",
                "cid": "bafyreifsqap4ezss7xrghaaffq62bpozbsiy2movcqq6srb3ukrw77n5ky",
                "uri": "at://did:plc:ifn645rwvsuolxg7o3w7ouo4/site.standard.document/3mwqgs7dp2s2a"
              },
              {
                "$type": "com.atproto.repo.strongRef",
                "cid": "bafyreigq3k6pnrpn5x3g5jiextybdiopboxjczy7uxzcdpvl5qvhd5uezq",
                "uri": "at://did:plc:ifn645rwvsuolxg7o3w7ouo4/site.standard.publication/3mvimt7nmrs2m"
              }
            ],
            "description": "",
            "thumb": {
              "$type": "blob",
              "ref": {
                "$link": "bafkreieolaxfe3uql5dczruhkjynkvjdrbwcxhn2vcrfnxbbzvb7rdil7i"
              },
              "mimeType": "image/webp",
              "size": 4748
            },
            "title": "Announcing Aster - a home for researchers on the open web ",
            "uri": "https://blog.aster.place/3mwqgs7dp2s2a?utm_source=bluesky&utm_medium=social&utm_campaign=publish&utm_content=did%3Aplc%3Aifn645rwvsuolxg7o3w7ouo4%2F3mwqgsd4cgs2a"
          }
        },
        "facets": [],
        "langs": [
          "en"
        ],
        "text": "The modern research ecosystem of online tools and communities is controlled by for-profit companies.\n\nBut we think that researchers should be the priority - not the product.\n\nSo, we're announcing Aster ID: not-for-profit Atmosphere account hosting for researchers."
      },
      "embed": {
        "external": {
          "uri": "https://blog.aster.place/3mwqgs7dp2s2a?utm_source=bluesky&utm_medium=social&utm_campaign=publish&utm_content=did%3Aplc%3Aifn645rwvsuolxg7o3w7ouo4%2F3mwqgsd4cgs2a",
          "title": "Announcing Aster - a home for researchers on the open web ",
          "description": "",
          "thumb": "https://cdn.bsky.app/img/feed_thumbnail/plain/did:plc:ifn645rwvsuolxg7o3w7ouo4/bafkreieolaxfe3uql5dczruhkjynkvjdrbwcxhn2vcrfnxbbzvb7rdil7i",
          "createdAt": "2026-09-30T13:22:17.189Z",
          "source": {
            "uri": "https://blog.aster.place",
            "icon": "https://cdn.bsky.app/img/avatar/plain/did:plc:ifn645rwvsuolxg7o3w7ouo4/bafkreieasq5ho7s5rai44b44jyqte4ryyaeiuyqkgf5sxw7dxaqcu7raki",
            "title": "Aster Blog",
            "description": "",
            "theme": {
              "backgroundRGB": {
                "r": 253,
                "g": 252,
                "b": 250,
                "$type": "app.bsky.embed.external#colorRGB"
              },
              "foregroundRGB": {
                "r": 0,
                "g": 0,
                "b": 0,
                "$type": "app.bsky.embed.external#colorRGB"
              },
              "accentRGB": {
                "r": 73,
                "g": 53,
                "b": 125,
                "$type": "app.bsky.embed.external#colorRGB"
              },
              "accentForegroundRGB": {
                "r": 255,
                "g": 255,
                "b": 255,
                "$type": "app.bsky.embed.external#colorRGB"
              }
            },
            "$type": "app.bsky.embed.external#viewExternalSource"
          },
          "associatedProfiles": [
            {
              "did": "did:plc:ifn645rwvsuolxg7o3w7ouo4",
              "handle": "aster.id",
              "displayName": "Aster ID",
              "avatar": "https://cdn.bsky.app/img/avatar/plain/did:plc:ifn645rwvsuolxg7o3w7ouo4/bafkreicid7hoyx5d2if24eryyhb3lg4ioy2mdrmiriga3k2cay6k5io4ta",
              "associated": {
                "chat": {
                  "allowIncoming": "all",
                  "allowGroupInvites": "all"
                },
                "activitySubscription": {
                  "allowSubscriptions": "followers"
                }
              },
              "labels": [],
              "createdAt": "2026-08-31T07:23:03.599Z"
            }
          ],
          "associatedRefs": [
            {
              "$type": "com.atproto.repo.strongRef",
              "cid": "bafyreifsqap4ezss7xrghaaffq62bpozbsiy2movcqq6srb3ukrw77n5ky",
              "uri": "at://did:plc:ifn645rwvsuolxg7o3w7ouo4/site.standard.document/3mwqgs7dp2s2a"
            },
            {
              "$type": "com.atproto.repo.strongRef",
              "cid": "bafyreigq3k6pnrpn5x3g5jiextybdiopboxjczy7uxzcdpvl5qvhd5uezq",
              "uri": "at://did:plc:ifn645rwvsuolxg7o3w7ouo4/site.standard.publication/3mvimt7nmrs2m"
            }
          ]
        },
        "$type": "app.bsky.embed.external#view"
      },
      "bookmarkCount": 156,
      "replyCount": 21,
      "repostCount": 152,
      "likeCount": 764,
      "quoteCount": 34,
      "indexedAt": "2026-09-30T13:22:24.362Z",
      "labels": []
    }
    """#
}
