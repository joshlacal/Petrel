# How Lexicon Types Map to Swift

Read a Lexicon and predict the Swift type or method Petrel generates for it.

## Overview

[Lexicon](https://atproto.com/specs/lexicon) schemas define every endpoint, record and event stream in the AT Protocol. Each schema has an NSID, such as `app.bsky.feed.getTimeline`. Petrel generates one Swift namespace per schema, named by the NSID in Pascal case (`AppBskyFeedGetTimeline`), and one method on ``ATProtoClient`` per endpoint, at the NSID's path (`client.app.bsky.feed.getTimeline`).

| Lexicon | Swift |
| :--- | :--- |
| `query` | `Parameters`, `Output` and `Error` types; an async method that takes `input: Parameters` and returns `(responseCode: Int, data: Output?)` |
| `procedure` | `Input`, `Output` and `Error` types; the method returns `(responseCode: Int, data: Output?)`, or `Int` when the Lexicon declares no output |
| `procedure` with input encoding `*/*` | a method that takes `data: Data` and `mimeType: String` |
| `subscription` | a `Message` enum; the method returns `AsyncThrowingStream<Message, Error>` |
| `query` with output encoding `text/event-stream` | a method that returns `AsyncThrowingStream<Output, Error>`, one `Output` per server-sent event |
| `record` | a struct with `typeIdentifier` and `recordKeyType`; encoding writes `$type` |
| `object` | a struct; an inline object becomes a nested struct |
| `union` | an enum with one case per ref; an open union adds `.unexpected(ATProtocolValueContainer)` |
| `ref` | the referenced type |
| `token` | a string constant holding `nsid#name` |
| `permission-set` | a `permissionSet` constant (``LexiconPermissionSet``) with `includeScope(audience:)` |
| `errors` | cases of the endpoint's `Error` enum, thrown as `ATProtoError<Endpoint.Error>` |
| `string` with `format` | a validated type such as ``DID``, ``Handle``, ``ATProtocolURI`` or ``ATProtocolDate``; see <doc:Identifiers>. The `cid` format is ``CIDString`` |
| `string` with `enum` | an enum with a `.value_<x>` case per value |
| `string` with `knownValues` | for a named definition, a struct with `rawValue`, static constants and `predefinedValues`; an inline property stays `String` |
| `integer`, `boolean`, `array` | `Int`, `Bool`, `[T]` |
| `bytes` | ``Bytes`` (`{"$bytes": …}` in JSON, a byte string in DAG-CBOR) |
| `cid-link` | `ATProtoLink` (`{"$link": …}` in JSON, tag 42 in DAG-CBOR) |
| `blob` | ``Blob`` |
| `unknown` | ``ATProtocolValueContainer`` |
| `required`, `nullable` | required is non-optional, anything else is optional; optional and nullable is `ATProtoNullable<T>?` |

Generated types are `Sendable` and encode to both JSON and DAG-CBOR. Value constraints such as `maxLength`, `maxGraphemes` and `minimum` are not part of the Swift types; validate with the `PetrelLexicon` product when you need them checked.

## Queries and procedures

This Lexicon:

```json
{
  "id": "app.bsky.feed.getTimeline",
  "defs": { "main": {
    "type": "query",
    "parameters": { "type": "params", "properties": {
      "algorithm": { "type": "string" },
      "limit": { "type": "integer", "minimum": 1, "maximum": 100, "default": 50 },
      "cursor": { "type": "string" }
    } },
    "output": { "encoding": "application/json", "schema": {
      "type": "object",
      "required": ["feed"],
      "properties": {
        "cursor": { "type": "string" },
        "feed": { "type": "array", "items": { "type": "ref", "ref": "app.bsky.feed.defs#feedViewPost" } }
      }
    } }
  } }
}
```

is called like this:

<!-- compile-example: lexicon-types-query -->
```swift
import Petrel

func loadTimeline(client: ATProtoClient) async throws -> [AppBskyFeedDefs.FeedViewPost] {
    let (_, output) = try await client.app.bsky.feed.getTimeline(
        input: .init(limit: 30)
    )
    return output?.feed ?? []
}
```

A parameter's Lexicon `default` is its initializer default, so `limit=50` is sent unless you pass another value or `nil`. A procedure works the same way with `Input` as the request body. <doc:XRPCClient> covers paging, errors, per-call options and blob uploads.

## Records and unknown values

A `record` is a struct whose `typeIdentifier` is its NSID. Endpoints that work with any collection, such as `com.atproto.repo.createRecord` and `getRecord`, declare the record as `unknown`, which is ``ATProtocolValueContainer`` in Swift. Wrap a record in `.knownType(_:)` to write it, and call `decoded(_:)` to read one back:

<!-- compile-example: rosetta-record-crud -->
```swift
import Foundation
import Petrel

func writeAndReadPostRecord(client: ATProtoClient, repoDID: DID) async throws {
    let post = AppBskyFeedPost(
        text: "Writing a typed record directly via com.atproto.repo.createRecord",
        facets: nil,
        reply: nil,
        embed: nil,
        langs: [LanguageCodeContainer(languageCode: "en")],
        labels: nil,
        tags: ["atproto", "swift"],
        createdAt: ATProtocolDate(date: Date())
    )

    // 1. Create the record inside the user's PDS repository
    let (_, created) = try await client.com.atproto.repo.createRecord(
        input: .init(
            repo: .did(repoDID),
            collection: try NSID(nsidString: AppBskyFeedPost.typeIdentifier),
            rkey: RecordKey(keyString: await TIDGenerator.next()),
            record: .knownType(post)
        )
    )

    guard let uri = created?.uri, let rkey = uri.rkey else { return }

    // 2. Fetch the record back and hydrate `ATProtocolValueContainer` -> `AppBskyFeedPost`
    let (_, fetched) = try await client.com.atproto.repo.getRecord(
        input: .init(
            repo: .did(repoDID),
            collection: try NSID(nsidString: AppBskyFeedPost.typeIdentifier),
            rkey: rkey
        )
    )

    if let hydrated = fetched?.value.decoded(AppBskyFeedPost.self) {
        print("Round-tripped text: \(hydrated.text)")
    }
}
```

To post to Bluesky, use ``BskyAgent`` instead (see <doc:BlueskyPosting>); it builds facets and embeds for you.

## Subscriptions

A `subscription` becomes a `Message` enum with one case per message type, and a method that returns a stream:

<!-- compile-example: rosetta-subscription -->
```swift
import Petrel

func consumeLabelSubscription(client: ATProtoClient) async throws {
    let stream = try await client.com.atproto.label.subscribeLabels(cursor: nil)

    for try await message in stream {
        switch message {
        case let .labels(batch):
            for label in batch.labels {
                print("[\(label.src)] \(label.uri) -> \(label.val)")
            }
        case let .info(info):
            print("Label stream info: \(info.name)")
        }
    }
}
```

For reconnection and cursor persistence, use `PetrelFirehose` or `PetrelJetstream`; see <doc:StreamingAndVerification>.

## Unions

A union is open unless the Lexicon says `"closed": true`. An open union decodes a `$type` it does not know as `.unexpected`, so a new variant does not fail the whole response. A closed union has no such case and rejects unknown variants.

<!-- compile-example: rosetta-unions -->
```swift
import Petrel

func describeEmbed(_ embed: AppBskyFeedDefs.PostViewEmbedUnion?) -> String {
    guard let embed else { return "No embed" }

    switch embed {
    case let .appBskyEmbedImagesView(imagesView):
        return "\(imagesView.images.count) image(s)"
    case let .appBskyEmbedGalleryView(galleryView):
        return "Gallery (\(galleryView.items.count) item(s))"
    case let .appBskyEmbedVideoView(videoView):
        return "Video (\(videoView.cid.string))"
    case let .appBskyEmbedExternalView(externalView):
        return "Link card: \(externalView.external.title)"
    case .appBskyEmbedRecordView:
        return "Quoted record"
    case .appBskyEmbedRecordWithMediaView:
        return "Quoted record + media"
    case .unexpected:
        return "Forward-compatible unknown embed $type"
    }
}
```

## Known values and enums

An `enum` string accepts only the listed values, so it is a Swift enum. A `knownValues` string accepts others too, so a named definition is a struct that keeps any string in `rawValue`:

<!-- compile-example: rosetta-known-values -->
```swift
import Petrel

func inspectReasonType(_ reason: ComAtprotoModerationDefs.ReasonType) -> String {
    switch reason {
    case .comatprotomoderationdefsreasonspam:
        return "Standard spam report"
    case .comatprotomoderationdefsreasonviolation:
        return "Community rule violation"
    default:
        // Values this Lexicon does not list are kept in `rawValue`.
        return "Custom reason: \(reason.rawValue)"
    }
}
```
