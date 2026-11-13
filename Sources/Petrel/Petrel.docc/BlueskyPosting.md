# Posting and the Social Graph

Publish posts with rich text, replies, quotes and media, and like, repost, follow, mute and block, with ``BskyAgent``.

## Overview

The generated API under `client.app.bsky` covers every Bluesky lexicon, but writing a post through it means assembling a record, computing facet byte offsets and calling `com.atproto.repo.createRecord` yourself. ``BskyAgent`` does that work. Get one from ``ATProtoClient/bsky``:

<!-- compile-example: bsky-posting-obtain-agent -->
```swift
import Petrel

func makeBlueskyAgent(client: ATProtoClient) -> BskyAgent {
    client.bsky
}
```

`BskyAgent` is a lightweight value; create it whenever you need it. Record writes go to the signed-in account's repository on its PDS. The helpers report failures as ``BskyAgentError``: `.notAuthenticated` when there is no session, `.xrpc` with the method, HTTP status and the server's error name and message when a call fails, and `.invalidInput` when an argument is rejected before anything is sent. The image helpers can also throw ``ImageMetadataStrippingError``, described under Image metadata below.

### Post text

Links, mentions and hashtags in the text become facets automatically. Mentioned handles are resolved to DIDs through the PDS; a handle that does not resolve stays plain text.

<!-- compile-example: bsky-posting-text -->
```swift
import Petrel

func publishTextPost(bsky: BskyAgent) async throws -> ComAtprotoRepoStrongRef {
    // Links, mentions and hashtags in the text become facets automatically.
    try await bsky.post("Reading https://atproto.com with @alice.bsky.social #atproto")
}
```

The result is a `ComAtprotoRepoStrongRef`: the `at://` URI and CID of the new post. That pair is what replies, quotes, likes and reposts refer to.

### Work with rich text directly

``RichText`` holds text and its facets. Facet positions are UTF-8 byte offsets, and `RichText` keeps them correct while text is inserted or deleted. Use it when you want to inspect or edit facets before posting, check the length, or render a post.

<!-- compile-example: bsky-posting-richtext -->
```swift
import Petrel

func publishAndRenderRichText(bsky: BskyAgent) async throws -> [String] {
    var text = RichText(text: "The label spec: https://atproto.com/specs/label #moderation")
    text.detectFacetsWithoutResolution()

    // Check the length the way the network does: graphemes, not characters or bytes.
    guard !text.exceedsPostLimits else { return [] }
    try await bsky.post(text, langs: ["en"])

    // Render it: one run per segment, links shortened for display only.
    var rendered: [String] = []
    for segment in text.shorteningLinks().segments() {
        if let link = segment.link {
            rendered.append("[\(segment.text)](\(link.uri.uriString()))")
        } else if let tag = segment.tag {
            rendered.append("<tag \(tag.tag)>")
        } else {
            rendered.append(segment.text)
        }
    }
    return rendered
}
```

`detectFacetsWithoutResolution()` finds links and tags. To include mentions, call `detectFacets(resolveMention:)` with a closure that maps a handle to a DID, such as `bsky.resolveHandle`. To place facets yourself, build the text with `append(_:)`, `appendLink(_:uri:)`, `appendMention(_:did:)` and `appendTag(_:tag:)`.

Detection follows the official client: the same patterns for mentions, links, hashtags and cashtags, the IANA top-level domain list for bare domains, and the same trailing-punctuation rules. Facets received from the network are not trusted. Offsets that are negative, out of range, overlapping or inside a character never crash; ``RichText/segments()`` skips or clamps them.

### Reply and quote

<!-- compile-example: bsky-posting-reply-quote -->
```swift
import Petrel

func replyAndQuote(bsky: BskyAgent, post: ComAtprotoRepoStrongRef) async throws {
    // A reply names its parent and the root of the thread; reply(to:)
    // reads the parent once to find the root.
    let reply = try await bsky.reply(to: post, "Thanks for sharing")
    try await bsky.reply(to: reply, "And one more thing")

    // A quote post embeds the quoted post.
    try await bsky.quote(post, "Worth a read")
}
```

If you already hold the parent as an `AppBskyFeedDefs.PostView`, `bsky.replyRef(to:)` builds the reply reference from it without a network call; pass it to `post(_:reply:)`.

### Attach images, video or a link card

<!-- compile-example: bsky-posting-media -->
```swift
import Foundation
import Petrel

func publishMediaPosts(bsky: BskyAgent, imageData: Data) async throws {
    // Upload and embed in one step. Location and other metadata are removed
    // from the file before it is sent (stripImageMetadata defaults to true).
    try await bsky.post("Seen today", images: [
        PostImage(
            data: imageData,
            mimeType: "image/jpeg",
            alt: "A storm petrel skimming the waves",
            width: 1600,
            height: 900
        ),
    ])

    // Or upload first and build the embed yourself.
    let blob = try await bsky.uploadImage(imageData, mimeType: "image/jpeg")
    try await bsky.post("Seen today", embed: try .images([.init(image: blob, alt: "The same petrel")]))

    // A link card instead of an image:
    try await bsky.post("Background reading", embed: .external(
        uri: URI(uriString: "https://atproto.com/specs/label"),
        title: "Labels",
        description: "How moderation labels work in the AT Protocol"
    ))
}
```

A post takes one to four images, and `quoting(_:)` adds a quoted record to any media embed.

Video does not go to the PDS like an image. `uploadVideo(_:mimeType:name:)` asks the PDS for a short-lived upload token, sends the file to the Bluesky video service, waits for processing, and returns the blob for `PostEmbed.video(_:alt:aspectRatio:captions:)`:

<!-- compile-example: bsky-posting-video -->
```swift
import Foundation
import Petrel

func publishVideoPost(bsky: BskyAgent, data: Data) async throws {
    let video = try await bsky.uploadVideo(data, name: "landing.mp4")
    try await bsky.post("Landing", embed: .video(video, alt: "A petrel landing"))
}
```

### Image metadata

Photos carry more than pixels: the GPS position where they were taken, the time, the device, sometimes the owner's name, and thumbnails of the picture before it was cropped. **Every helper that uploads an image removes that metadata by default**: `post(_:images:)`, `uploadImage(_:mimeType:)`, `setAvatar(_:mimeType:)` and `setBanner(_:mimeType:)`.

- JPEG, PNG, WebP and GIF are rewritten losslessly in pure Swift on every platform, Linux included. Metadata blocks are left out and the compressed image data is copied as it is: the pixels do not change, nothing is re-encoded, and the format stays the same. The ICC colour profile, transparency and animation are kept. Pixel density is kept too. If the image is rotated by its EXIF orientation, that one value is kept so it still displays the right way up.
- Other image types (HEIC, HEIF, AVIF, TIFF and so on) are decoded and written back in the same format by ImageIO on Apple platforms. On other platforms they are refused with `ImageMetadataStrippingError.unsupportedImageFormat`.
- If metadata cannot be removed, because the format is unsupported or the file is damaged, the helper throws ``ImageMetadataStrippingError`` and nothing is uploaded.

Before any image is uploaded, `post(_:images:)` checks and strips all of them, so a problem with one leaves nothing behind on the PDS. The `mimeType` passed to these helpers must be an `image/*` type.

To upload a file with its metadata intact, say so: pass `stripImageMetadata: false` to `post(_:images:)`, or `stripMetadata: false` to the other three. `uploadBlob(_:mimeType:)` is the raw path: it sends bytes exactly as given and never strips anything. **Video metadata is never removed:** `uploadVideo` sends the file as given, so remove location or device tags yourself first if that matters for your users.

``ImageMetadataStripper/stripMetadata(from:mimeType:)`` is the function behind the helpers and can be called directly.

### Like, repost, follow, mute and block

<!-- compile-example: bsky-posting-social-graph -->
```swift
import Petrel

func exerciseSocialGraphVerbs(
    bsky: BskyAgent,
    post: ComAtprotoRepoStrongRef,
    author: DID
) async throws {
    // Each verb returns the record it created. Keep the URI to undo it.
    let like = try await bsky.like(post)
    let repost = try await bsky.repost(post)
    let follow = try await bsky.follow(author)

    try await bsky.deleteLike(like.uri)
    try await bsky.deleteRepost(repost.uri)
    try await bsky.deleteFollow(follow.uri)

    // Mutes are private and live on the AppView; blocks are public records.
    try await bsky.mute(try ATIdentifier(string: "spammer.bsky.social"))
    let block = try await bsky.block(author)
    try await bsky.deleteBlock(block.uri)
}
```

The URIs to undo an action are also in what the AppView returns: a post's `viewer.like` and `viewer.repost`, a profile's `viewer.following` and `viewer.blocking`. Moderation lists have `muteModList`, `unmuteModList`, `blockModList` and `unblockModList`.

### Update the profile

<!-- compile-example: bsky-posting-upsert-profile -->
```swift
import Petrel

func updateAccountProfile(bsky: BskyAgent) async throws {
    // Read-modify-write: the closure receives the stored profile and
    // returns the new one. It runs again if another client wrote first.
    try await bsky.upsertProfile { existing in
        var profile = ProfileUpdate(existing)
        profile.displayName = "Storm Petrel"
        profile.description = "Pelagic. Posts from the open sea."
        return profile.record
    }
}
```

The write is conditional on the profile not having changed since it was read, so two clients editing at once cannot silently overwrite each other. Fields of the stored record that this SDK does not model are kept.

### Link to the Bluesky app

``BskyAppURL`` converts between `at://` URIs and `bsky.app` addresses.

<!-- compile-example: bsky-posting-app-url -->
```swift
import Foundation
import Petrel

func convertBlueskyAppURLs() throws {
    let uri = try ATProtocolURI(
        uriString: "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3kabc"
    )
    let shareURL = BskyAppURL.url(for: uri, handle: "bsky.app")
    // https://bsky.app/profile/bsky.app/post/3kabc

    let pasted = URL(string: "https://bsky.app/profile/bsky.app/post/3kabc")
    let parsed = pasted.flatMap { BskyAppURL.atURI(from: $0) }
    // at://bsky.app/app.bsky.feed.post/3kabc — resolve the handle before storing it
    _ = (shareURL, parsed)
}
```

## Topics

### Agent

- ``BskyAgent``
- ``BskyAgentError``
- ``ATProtoClient/bsky``

### Rich text

- ``RichText``
- ``RichTextSegment``
- ``RichTextDetection``

### Records and embeds

- ``PostEmbed``
- ``PostImage``
- ``ImageMetadataStripper``
- ``ImageMetadataStrippingError``
- ``ProfileUpdate``
- ``RecordSwap``

### Links

- ``BskyAppURL``
