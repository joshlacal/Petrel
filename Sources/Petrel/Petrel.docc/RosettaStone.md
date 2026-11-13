# The Petrel Rosetta Stone

How each Lexicon JSON construct maps to Petrel's generated Swift types, calling conventions, primitives and typed errors.

## Overview

In the AT Protocol, API endpoints, repository records, and event streams are defined in [Lexicon](https://atproto.com/specs/lexicon) JSON schemas identified by reverse-DNS **NSIDs** (such as `app.bsky.feed.getTimeline` or `com.atproto.repo.createRecord`).

Petrel compiles those schemas directly into Swift 6 value types (`Sendable`, `Codable`, and deterministic `DAG-CBOR`-capable via `ATProtocolCodable`) plus hierarchical methods on ``ATProtoClient``. With the rules on this page you can read a Lexicon and predict the Swift API Petrel generates for it.


## Quick Mapping Cheat Sheet

| Lexicon Construct | JSON Shape | Generated Swift Type / Signature |
| :--- | :--- | :--- |
| **NSID Namespace** | `"id": "app.bsky.feed.getTimeline"` | `enum AppBskyFeedGetTimeline` + `client.app.bsky.feed.getTimeline(input:)` |
| **`query`** | `"type": "query"`, `"parameters"`, `"output"` | `struct Parameters: Parametrizable`, `struct Output: ATProtocolCodable` → `async throws -> (responseCode: Int, data: Output?)`; Lexicon parameter defaults become initializer defaults |
| **`procedure` (JSON)** | `"type": "procedure"`, `"input"`, `"output"` | `struct Input: ATProtocolCodable`, `struct Output: ATProtocolCodable` → `async throws -> (responseCode: Int, data: Output?)` (or `Int` when output-less) |
| **`procedure` (Blob)** | `"input": { "encoding": "*/*" }` | `uploadBlob(data: Data, mimeType: String, stripMetadata: Bool = true)` |
| **`record`** | `"type": "record"`, `"key": "tid"` | `struct <PascalNSID>: ATProtocolCodable, ATProtocolValue` (`static let typeIdentifier`) |
| **`subscription`** | `"type": "subscription"`, `"message"` | `enum Message: Codable, Sendable` → `AsyncThrowingStream<Message, Error>` |
| **`union`** | `"type": "union"`, `"refs": [...]` | `enum <Parent><Prop>Union` with typed cases + `.unexpected(ATProtocolValueContainer)` |
| **`knownValues`** (named string def) | `"type": "string", "knownValues": [...]` | Open `struct <Name>: ATProtocolCodable` (`rawValue: String`, static constants, `predefinedValues`); an inline `knownValues` property stays `String` |
| **Closed `enum`** | `"type": "string", "enum": [...]` | `enum <Name>: String, ATProtocolCodable` with one `.value_<x>` case per value |
| **`unknown`** | `"type": "unknown"` | ``ATProtocolValueContainer`` (hydrate with `.decoded(MyRecord.self)`) |


## 1. `query` — HTTP GET & Cursor Pagination

A Lexicon `query` compiles into an `enum` namespace containing `Parameters` (URL query items), `Output` (the decoded JSON body), and `Error` (any endpoint-specific error names):

```json
{
  "lexicon": 1,
  "id": "app.bsky.feed.getTimeline",
  "defs": {
    "main": {
      "type": "query",
      "parameters": {
        "type": "params",
        "properties": {
          "algorithm": { "type": "string" },
          "limit": { "type": "integer", "minimum": 1, "maximum": 100, "default": 50 },
          "cursor": { "type": "string" }
        }
      },
      "output": {
        "encoding": "application/json",
        "schema": {
          "type": "object",
          "required": ["feed"],
          "properties": {
            "cursor": { "type": "string" },
            "feed": { "type": "array", "items": { "type": "ref", "ref": "app.bsky.feed.defs#feedViewPost" } }
          }
        }
      }
    }
  }
}
```

### Generated Swift Calling Convention

A generated query that has parameters takes `input: <Lexicon>.Parameters` and returns `(responseCode: Int, data: <Lexicon>.Output?)`. The Lexicon's `"default": 50` becomes the initializer default `limit: Int? = 50`, so it is sent unless you pass `nil`.

To page by hand, pass the returned `cursor` back into the next `Parameters` until it is `nil`:

<!-- compile-example: rosetta-query-pagination -->
```swift
import Petrel

func fetchTimelinePages(
    client: ATProtoClient,
    maxPages: Int = 3
) async throws -> [AppBskyFeedDefs.FeedViewPost] {
    var collected: [AppBskyFeedDefs.FeedViewPost] = []
    var cursor: String? = nil

    for _ in 0 ..< maxPages {
        let (responseCode, output) = try await client.app.bsky.feed.getTimeline(
            input: .init(limit: 50, cursor: cursor)
        )
        guard responseCode == 200, let page = output else {
            break
        }

        collected.append(contentsOf: page.feed)
        guard let nextCursor = page.cursor, !page.feed.isEmpty else {
            break
        }
        cursor = nextCursor
    }

    return collected
}
```

``XRPCPages`` does the same loop for any cursor-paginated query, and also stops on a repeated cursor; see <doc:XRPCClient>.


## 2. `procedure` — HTTP POST and blob uploads

A JSON `procedure` encodes `<Lexicon>.Input` as `application/json` and returns `(responseCode: Int, data: <Lexicon>.Output?)` (or `Int` alone when the Lexicon declares no `output`, such as `app.bsky.actor.putPreferences`).

Binary procedures (`encoding: "*/*"`, notably `com.atproto.repo.uploadBlob`) take raw `Data` and `mimeType: String`. By default (`stripMetadata: true`) Petrel removes image metadata (EXIF including GPS position, XMP, IPTC, comments, timestamps, embedded thumbnails) before the upload. JPEG, PNG, WebP and GIF are rewritten losslessly without re-encoding; other image types (HEIC, AVIF, TIFF, …) are re-encoded in their own format by ImageIO on Apple platforms and refused elsewhere. Bodies that are not `image/*` are sent unchanged:

<!-- compile-example: rosetta-procedure-and-blob -->
```swift
import Foundation
import Petrel

func uploadSanitizedImageBlob(
    client: ATProtoClient,
    jpegBytes: Data
) async throws -> Blob {
    // stripMetadata defaults to true; it is spelled out here for clarity.
    let (status, output) = try await client.com.atproto.repo.uploadBlob(
        data: jpegBytes,
        mimeType: "image/jpeg",
        stripMetadata: true
    )

    guard (200 ..< 300).contains(status), let blob = output?.blob else {
        throw NetworkError.responseError(statusCode: status)
    }

    // `blob.ref` links the blob's CID; reference `blob` from a record.
    print("Uploaded \(blob.mimeType) (\(blob.size) bytes) -> CID \(blob.ref?.cid.string ?? "legacy")")
    return blob
}
```


## 3. `record` & `unknown` — Repository Documents and Dynamic Hydration

A Lexicon `record` defines a document stored inside a user's repository (`at://<did>/<collection>/<rkey>`):

```json
{
  "lexicon": 1,
  "id": "app.bsky.feed.post",
  "defs": {
    "main": {
      "type": "record",
      "key": "tid",
      "record": {
        "type": "object",
        "required": ["text", "createdAt"],
        "properties": {
          "text": { "type": "string", "maxLength": 3000, "maxGraphemes": 300 },
          "facets": { "type": "array", "items": { "type": "ref", "ref": "app.bsky.richtext.facet" } },
          "createdAt": { "type": "string", "format": "datetime" }
        }
      }
    }
  }
}
```

Because generic endpoints like `com.atproto.repo.createRecord`, `getRecord`, and `listRecords` work with *any* collection (`"type": "unknown"` in Lexicon JSON), Petrel models open record slots as ``ATProtocolValueContainer``:

- **Writing**: Wrap any generated record struct in `.knownType(record)` — Petrel automatically injects `"$type": Record.typeIdentifier` on the wire.
- **Reading**: Call `.decoded(AppBskyFeedPost.self)` on any ``ATProtocolValueContainer`` (`postView.record`, `getRecord` output, or Jetstream/Firehose records) to extract the strongly typed Swift value.

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

> Tip: For everyday Bluesky posting, replies, quotes, likes, and image/video uploads, prefer ``BskyAgent`` (`client.bsky.post("...")`), which computes UTF-8 facet offsets and builds `createRecord` calls automatically. Use `com.atproto.repo.*` directly when working with custom Lexicons or low-level repository records.


## 4. `subscription` — Event Streams

A Lexicon `subscription` (such as `com.atproto.sync.subscribeRepos` or `com.atproto.label.subscribeLabels`) compiles into a `Message` enum and an `AsyncThrowingStream<Message, Error>` method on ``ATProtoClient``:

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

For long-running consumers with reconnection and cursor persistence, use `PetrelFirehose` (`FirehoseSubscription`) or `PetrelJetstream` (`JetstreamSubscription`). See <doc:StreamingAndVerification>.


## 5. `union` — Open & Closed Polymorphic Unions

Lexicon `union` properties list multiple `$type` references (`refs`) that may appear in a single field — for example, a post's `embed` (`images`, `video`, `external`, `record`, or `recordWithMedia`).

Petrel generates a dedicated Swift `enum` with one associated-value case per declared ref **plus** `.unexpected(ATProtocolValueContainer)` on open unions (`"closed": false`, the Lexicon default). If a new embed `$type` appears, older apps decode it as `.unexpected(...)` instead of failing the whole response. A closed union (`"closed": true`) has no `.unexpected` case and rejects unknown variants.

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


## 6. `knownValues` vs. Closed `enum`

AT Protocol Lexicons intentionally distinguish between **closed** and **open** string sets:

- **`"enum": ["asc", "desc"]` (Closed)**: Only these values are valid, so Petrel generates a Swift `enum` (`String, ATProtocolCodable`) with cases such as `.value_asc`.
- **`"knownValues": [...]` (Open)**: Other values are allowed. For a named string definition Petrel generates a `struct` wrapping `public let rawValue: String`, with static constants and `predefinedValues`, so unknown strings survive JSON and DAG-CBOR round trips. A property with inline `knownValues` is a plain `String`.

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


## 7. String Formats & IPLD Primitives

String formats and binary primitives map to validated, `Sendable` Swift types:

| Lexicon Type / Format | JSON Wire Form | DAG-CBOR Wire Form | Petrel Swift Type | Construction Example |
| :--- | :--- | :--- | :--- | :--- |
| `"format": "did"` | `"did:plc:..."` | UTF-8 text | ``DID`` | `try DID(didString: "did:plc:ewvi7nxzyoun6zhxrhs64oiz")` |
| `"format": "handle"` | `"alice.bsky.social"` | UTF-8 text | ``Handle`` | `try Handle(handleString: "alice.bsky.social")` |
| `"format": "at-identifier"` | DID or Handle | UTF-8 text | ``ATIdentifier`` | `try ATIdentifier(string: "alice.bsky.social")` |
| `"format": "at-uri"` | `"at://did.../col/rkey"` | UTF-8 text | ``ATProtocolURI`` | `try ATProtocolURI(uriString: "at://...")` |
| `"format": "nsid"` | `"app.bsky.feed.post"` | UTF-8 text | ``NSID`` | `try NSID(nsidString: "app.bsky.feed.post")` |
| `"format": "tid"` | `"3jzfcijpj2z2a"` | UTF-8 text | ``TID`` / ``TIDGenerator`` | `await TIDGenerator.nextTID()` |
| `"format": "record-key"` | `"self"` or TID | UTF-8 text | ``RecordKey`` | `try RecordKey(keyString: "self")` |
| `"format": "datetime"` | `"2026-11-12T10:00:00.000Z"` | UTF-8 text | ``ATProtocolDate`` | `ATProtocolDate(date: Date())` |
| `"format": "language"` | `"en-US"` | UTF-8 text | ``LanguageCodeContainer`` | `try LanguageCodeContainer(validating: "en-US")` |
| `"format": "uri"` | `"https://atproto.com"` | UTF-8 text | ``URI`` | `try URI(validating: "https://atproto.com")` |
| `"format": "cid"` | `"bafyrei..."` | UTF-8 text | `CID` / ``CIDSyntax`` | `try CID.parse("bafyrei...")` |
| `"type": "cid-link"` | `{ "$link": "bafy..." }` | CBOR Tag 42 | `CID` / `ATProtoLink` | `CID.fromDAGCBOR(cborBytes)` |
| `"type": "blob"` | `{ "$type": "blob", "ref": { "$link": "..." }, ... }` | Map w/ Tag 42 `ref` | ``Blob`` | Returned by `uploadBlob` |
| `"type": "bytes"` | `{ "$bytes": "<base64>" }` | Raw CBOR byte string | ``Bytes`` | `Bytes(data: rawBytes)` |

<!-- compile-example: rosetta-primitives -->
```swift
import Foundation
import Petrel

func buildValidatedPrimitives() async throws {
    let did = try DID(didString: "did:plc:ewvi7nxzyoun6zhxrhs64oiz")
    let handle = try Handle(handleString: "atproto.com")
    let actor = ATIdentifier.handle(handle)
    let collection = try NSID(nsidString: "app.bsky.feed.post")
    let rkey = try RecordKey(keyString: await TIDGenerator.next())
    let postURI = try ATProtocolURI(authority: .did(did), collection: collection, recordKey: rkey)

    // Compute a deterministic DAG-CBOR CIDv1 (`PetrelCore`) and raw byte wrapper (`Bytes`)
    let cborBytes = try DAGCBOR.encodeValue(["$type": "app.bsky.feed.post", "text": "Hello IPLD"])
    let cid = CID.fromDAGCBOR(cborBytes)
    let payloadBytes = Bytes(data: Data([0xDE, 0xAD, 0xBE, 0xEF]))

    print("Actor: \(actor.stringValue()), URI: \(postURI.uriString()), CID: \(cid.string), \(payloadBytes.data.count) bytes")
}
```


## 8. Typed Error Handling

XRPC calls throw structured errors, so you never parse error strings:

1. **`ATProtoError<Lexicon.Error>`**: Matched when the server returns a named domain error declared in that Lexicon's `"errors"` array (for example, `AppBskyFeedGetPostThread.Error.notFound`).
2. **``AccountStatusError``**: Thrown when a request is refused because the signed-in account is `.deactivated`, `.suspended`, or `.takendown`, preserving the session so the user can inspect status or reactivate.
3. **``ATProtoXRPCError``**: Preserves any generic `{ "error": "...", "message": "..." }` XRPC error payload plus `statusCode`.
4. **``NetworkError``**: Transport, content-type, response-size limit, metadata-stripping, or authentication-state errors (for example, `.responseError(statusCode: 429)`, `.authenticationRequired`, `.metadataStrippingFailed`).

<!-- compile-example: rosetta-error-handling -->
```swift
import Petrel

func loadThreadSafely(
    client: ATProtoClient,
    postURI: ATProtocolURI
) async -> Result<AppBskyFeedGetPostThread.Output?, Error> {
    do {
        let (_, output) = try await client.app.bsky.feed.getPostThread(
            input: .init(uri: postURI)
        )
        return .success(output)
    } catch let domainError as ATProtoError<AppBskyFeedGetPostThread.Error> {
        switch domainError.error {
        case .notFound:
            print("Thread root not found (\(domainError.statusCode)): \(domainError.message ?? "")")
        }
        return .failure(domainError)
    } catch let statusError as AccountStatusError {
        let reason = statusError.status.reason?.rawValue ?? "inactive"
        print("Signed-in account is inactive: \(reason)")
        return .failure(statusError)
    } catch let xrpcError as ATProtoXRPCError {
        print("XRPC \(xrpcError.statusCode) \(xrpcError.error): \(xrpcError.message ?? "")")
        return .failure(xrpcError)
    } catch let networkError as NetworkError {
        print("Transport error: \(networkError.localizedDescription)")
        return .failure(networkError)
    } catch {
        return .failure(error)
    }
}
```

## Next Steps

- Generate a typed API for your own `xyz.myapp.*` Lexicons in <doc:CustomLexicons> and <doc:CustomLexiconsAndOverlays>.
- Page through results, set per-call options and read response headers in <doc:XRPCClient>.
- See the string-format rules in detail in <doc:Identifiers>.
- See <doc:BlueskyPosting> for high-level rich-text, embed, and social-graph helpers via ``BskyAgent``.
