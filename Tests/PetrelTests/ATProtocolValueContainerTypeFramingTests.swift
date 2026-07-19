import Foundation
import Testing

@testable import Petrel

/// Regression tests for the lossless-decode round-trip guard.
///
/// Generated `encode(to:)` implementations frame every nested object definition
/// with its `$type` discriminator, while records written by real AT Protocol
/// clients omit `$type` on non-union nested objects (facet `index`, embed
/// `images[]`, `aspectRatio`, `reply` refs, self-label values, …). The guard
/// must not treat that framing difference as data loss, or every real-world
/// post containing those fields demotes to `.unknownType` and renderers
/// tombstone it ("Post format error" in Catbird).
struct ATProtocolValueContainerTypeFramingTests {
  /// Verbatim wire record (facets post) as returned by the AppView for
  /// at://…/app.bsky.feed.post/3mqyilqx6qc2d — nested objects carry no `$type`.
  private static let facetedRecordJSON = """
    {
      "$type": "app.bsky.feed.post",
      "createdAt": "2026-07-19T09:31:59.000Z",
      "facets": [
        {
          "features": [
            {"$type": "app.bsky.richtext.facet#mention", "did": "did:plc:yirep3fqwvhazp5kcimfo2ne"}
          ],
          "index": {"byteEnd": 48, "byteStart": 19}
        },
        {
          "features": [
            {"$type": "app.bsky.richtext.facet#link", "uri": "https://catbird.blue"}
          ],
          "index": {"byteEnd": 75, "byteStart": 55}
        },
        {
          "features": [
            {"$type": "app.bsky.richtext.facet#tag", "tag": "CatbirdPreviews"}
          ],
          "index": {"byteEnd": 96, "byteStart": 80}
        }
      ],
      "text": "Testing rich text: @catbird-appstore.bsky.social check https://catbird.blue and #CatbirdPreviews"
    }
    """

  /// Verbatim wire record (single image post) — blob ref, alt, aspectRatio, no nested `$type`
  /// beyond the embed union member and the blob itself.
  private static let imageRecordJSON = """
    {
      "$type": "app.bsky.feed.post",
      "createdAt": "2026-07-19T09:32:07.000Z",
      "embed": {
        "$type": "app.bsky.embed.images",
        "images": [
          {
            "alt": "A solid green preview image",
            "aspectRatio": {"height": 480, "width": 640},
            "image": {
              "$type": "blob",
              "ref": {"$link": "bafkreibubdyzcgxfmpq6grnnwds62djzzujazttf6mbiv5bhcjnzejvw24"},
              "mimeType": "image/png",
              "size": 2196
            }
          }
        ]
      },
      "text": "One image, landscape, with alt text."
    }
    """

  /// Verbatim wire record (reply) — strongRefs with no `$type`.
  private static let replyRecordJSON = """
    {
      "$type": "app.bsky.feed.post",
      "createdAt": "2026-07-19T09:32:22.000Z",
      "reply": {
        "parent": {
          "cid": "bafyreiblkecirw3zwuqmm7hru77pgxzn2wexvi2kkqbpicrqrqhri7ne2u",
          "uri": "at://did:plc:oq3qa6f332ergklpj2dvd3up/app.bsky.feed.post/3mqyilyckxx2h"
        },
        "root": {
          "cid": "bafyreiblkecirw3zwuqmm7hru77pgxzn2wexvi2kkqbpicrqrqhri7ne2u",
          "uri": "at://did:plc:oq3qa6f332ergklpj2dvd3up/app.bsky.feed.post/3mqyilyckxx2h"
        }
      },
      "text": "Obviously the catbird. Self-reply, level one."
    }
    """

  @Test(
    "Wire records without nested $type framing decode as known types",
    arguments: [facetedRecordJSON, imageRecordJSON, replyRecordJSON]
  )
  func wireRecordDecodesAsKnownType(_ json: String) throws {
    let container = try JSONDecoder().decode(
      ATProtocolValueContainer.self, from: Data(json.utf8))
    guard case .knownType(let value) = container else {
      Issue.record("Expected .knownType(AppBskyFeedPost), got \(container)")
      return
    }
    #expect(value is AppBskyFeedPost)
  }

  @Test("Faceted wire record retains its facets through typed dispatch")
  func facetsSurviveTypedDispatch() throws {
    let container = try JSONDecoder().decode(
      ATProtocolValueContainer.self, from: Data(Self.facetedRecordJSON.utf8))
    guard case .knownType(let value) = container, let post = value as? AppBskyFeedPost else {
      Issue.record("Expected .knownType(AppBskyFeedPost), got \(container)")
      return
    }
    #expect(post.facets?.count == 3)
  }

  @Test("Future fields still demote typed dispatch to the raw fallback")
  func futureFieldsStillFallBack() throws {
    let json = """
      {
        "$type": "app.bsky.feed.post",
        "createdAt": "2026-07-19T09:31:59.000Z",
        "text": "future",
        "future": {"enabled": true}
      }
      """
    let container = try JSONDecoder().decode(
      ATProtocolValueContainer.self, from: Data(json.utf8))
    guard case .unknownType(let type, _) = container else {
      Issue.record("Expected .unknownType raw fallback for future fields, got \(container)")
      return
    }
    #expect(type == "app.bsky.feed.post")
  }
}
