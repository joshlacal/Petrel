# Posting and the Social Graph

Publish posts with rich text, replies, quotes and media, and like, repost, follow, mute and block, with ``BskyAgent``.

## Overview

The generated API under `client.app.bsky` covers every Bluesky lexicon, but writing a post through it means assembling a record, computing facet byte offsets and calling `com.atproto.repo.createRecord` yourself. ``BskyAgent`` does that work. Get one from ``ATProtoClient/bsky``:

```swift
let bsky = client.bsky
```

`BskyAgent` is a lightweight value; create it whenever you need it. Record writes go to the signed-in account's repository on its PDS. Every helper throws ``BskyAgentError``: `.notAuthenticated` when there is no session, `.xrpc` with the server's error name and message when a call fails, and `.invalidInput` when an argument is rejected before anything is sent.

Every example on this page is compiled and run by `Tests/PetrelTests/BskyDocumentationExampleTests.swift`.

### Post text

Links, mentions and hashtags in the text become facets automatically. Mentioned handles are resolved to DIDs through the PDS; a handle that does not resolve stays plain text.

```swift
// Links, mentions and hashtags in the text become facets automatically.
let post = try await bsky.post("Reading https://atproto.com with @alice.bsky.social #atproto")
```

The result is a `ComAtprotoRepoStrongRef`: the `at://` URI and CID of the new post. That pair is what replies, quotes, likes and reposts refer to.

### Work with rich text directly

``RichText`` holds text and its facets. Facet positions are UTF-8 byte offsets, and `RichText` keeps them correct while text is inserted or deleted. Use it when you want to inspect or edit facets before posting, check the length, or render a post.

```swift
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
```

`detectFacetsWithoutResolution()` finds links and tags. To include mentions, call `detectFacets(resolveMention:)` with a closure that maps a handle to a DID, such as `bsky.resolveHandle`. To place facets yourself, build the text with `append(_:)`, `appendLink(_:uri:)`, `appendMention(_:did:)` and `appendTag(_:tag:)`.

Detection follows the official client: the same patterns for mentions, links, hashtags and cashtags, the IANA top-level domain list for bare domains, and the same trailing-punctuation rules. Facets received from the network are not trusted. Offsets that are negative, out of range, overlapping or inside a character never crash; ``RichText/segments()`` skips or clamps them.

### Reply and quote

```swift
// A reply names its parent and the root of the thread; reply(to:)
// reads the parent once to find the root.
let reply = try await bsky.reply(to: post, "Thanks for sharing")
try await bsky.reply(to: reply, "And one more thing")

// A quote post embeds the quoted post.
try await bsky.quote(post, "Worth a read")
```

If you already hold the parent as an `AppBskyFeedDefs.PostView`, `bsky.replyRef(to:)` builds the reply reference from it without a network call; pass it to `post(_:reply:)`.

### Attach images, video or a link card

Upload the bytes first, then reference the returned blob from a ``PostEmbed``. `uploadBlob(_:mimeType:)` sends the data unmodified with the media type you give it.

```swift
// The bytes are uploaded as they are; say what they are.
let blob = try await bsky.uploadBlob(imageData, mimeType: "image/png")

try await bsky.post("Seen today", embed: .images([
    .init(image: blob, alt: "A storm petrel skimming the waves", width: 1600, height: 900),
]))

// A link card instead of an image:
try await bsky.post("Background reading", embed: .external(
    uri: URI(uriString: "https://atproto.com/specs/label"),
    title: "Labels",
    description: "How moderation labels work in the AT Protocol"
))
```

A post takes one to four images, and `quoting(_:)` adds a quoted record to any media embed.

Video does not go to the PDS like an image. `uploadVideo(_:mimeType:name:)` asks the PDS for a short-lived upload token, sends the file to the Bluesky video service, waits for processing, and returns the blob for `PostEmbed.video(_:alt:aspectRatio:captions:)`:

```swift
let video = try await bsky.uploadVideo(data, name: "landing.mp4")
try await bsky.post("Landing", embed: .video(video, alt: "A petrel landing"))
```

### Like, repost, follow, mute and block

```swift
// Each verb returns the record it created. Keep the URI to undo it.
let like = try await bsky.like(post)
let repost = try await bsky.repost(post)
let follow = try await bsky.follow(author)

try await bsky.deleteLike(like.uri)
try await bsky.deleteRepost(repost.uri)
try await bsky.deleteFollow(follow.uri)

// Mutes are private and live on the AppView; blocks are public records.
try await bsky.mute(ATIdentifier(string: "spammer.bsky.social"))
let block = try await bsky.block(author)
try await bsky.deleteBlock(block.uri)
```

The URIs to undo an action are also in what the AppView returns: a post's `viewer.like` and `viewer.repost`, a profile's `viewer.following` and `viewer.blocking`. Moderation lists have `muteModList`, `unmuteModList`, `blockModList` and `unblockModList`.

### Update the profile

```swift
// Read-modify-write: the closure receives the stored profile and
// returns the new one. It runs again if another client wrote first.
try await bsky.upsertProfile { existing in
    var profile = ProfileUpdate(existing)
    profile.displayName = "Storm Petrel"
    profile.description = "Pelagic. Posts from the open sea."
    return profile.record
}
```

The write is conditional on the profile not having changed since it was read, so two clients editing at once cannot silently overwrite each other. Fields of the stored record that this SDK does not model are kept.

### Link to the Bluesky app

``BskyAppURL`` converts between `at://` URIs and `bsky.app` addresses.

```swift
let uri = try ATProtocolURI(uriString: "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3kabc")
let shareURL = BskyAppURL.url(for: uri, handle: "bsky.app")
// https://bsky.app/profile/bsky.app/post/3kabc

let pasted = URL(string: "https://bsky.app/profile/bsky.app/post/3kabc")
let parsed = pasted.flatMap { BskyAppURL.atURI(from: $0) }
// at://bsky.app/app.bsky.feed.post/3kabc — resolve the handle before storing it
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
- ``ProfileUpdate``
- ``RecordSwap``

### Links

- ``BskyAppURL``
