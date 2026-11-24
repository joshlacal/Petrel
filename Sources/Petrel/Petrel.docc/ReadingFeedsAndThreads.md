# Reading Feeds and Threads

Load a home timeline, a profile's posts, a custom feed and a whole thread, and read the posts in them.

## Overview

Bluesky feeds come from the AppView, not from the account's PDS. Petrel routes each
`app.bsky.feed.*` call there for you: an authenticated ``ATProtoClient`` adds the
`atproto-proxy` header, and an unauthenticated client pointed at
`https://public.api.bsky.app` calls the public AppView directly. You write the same
call either way.

| You want | Call | Needs an account |
| :--- | :--- | :--- |
| The signed-in account's home timeline | `client.app.bsky.feed.getTimeline` | Yes |
| One account's posts and reposts | `client.app.bsky.feed.getAuthorFeed` | No |
| A custom feed (a feed generator) | `client.app.bsky.feed.getFeed` | No, but some feeds personalize for a signed-in account |
| A post with its parents and replies | `client.app.bsky.feed.getPostThread` | No |

Every feed call returns a page of `AppBskyFeedDefs.FeedViewPost` values and a `cursor`
for the next page. A thread call returns a tree.

## Read a profile's posts

`getAuthorFeed` works without an account. Its `filter` picks what the page holds:
`"posts_with_replies"` (the Lexicon default), `"posts_no_replies"`,
`"posts_with_media"`, `"posts_and_author_threads"` or `"posts_with_video"`.

Each item's `post.record` is the post record as an ``ATProtocolValueContainer``. Decode it
with `decoded(_:)` to read the text. An item whose `reason` is a repost is shown in the
feed because someone reposted it, and the reposter is in `reason`:

<!-- compile-example: feeds-author-feed -->
```swift
import Foundation
import Petrel

func printRecentPosts() async throws {
    let client = await ATProtoClient(
        baseURL: URL(string: "https://public.api.bsky.app")!
    )
    let (_, page) = try await client.app.bsky.feed.getAuthorFeed(
        input: .init(
            actor: try ATIdentifier(string: "atproto.com"),
            limit: 20,
            filter: "posts_no_replies"
        )
    )

    for item in page?.feed ?? [] {
        let author = item.post.author.handle.description
        let text = item.post.record.decoded(AppBskyFeedPost.self)?.text ?? ""

        if case let .appBskyFeedDefsReasonRepost(repost)? = item.reason {
            print("\(repost.by.handle.description) reposted @\(author): \(text)")
        } else {
            print("@\(author): \(text)")
        }
    }
}
```

`decoded(_:)` returns `nil` when the record is not the type you asked for, so a record
that a newer Lexicon revision changed never crashes your feed.

## Load the next page

Pass the `cursor` from one page as the `cursor` of the next. ``XRPCPages`` does that loop
for any cursor-paginated query and stops at the last page, at `maxPages`, or when a server
repeats a cursor. Pages are fetched only as you iterate, so breaking out of the loop stops
the requests:

<!-- compile-example: feeds-author-feed-pages -->
```swift
import Petrel

func collectPostURIs(client: ATProtoClient, actor: ATIdentifier) async throws -> [ATProtocolURI] {
    let pages = XRPCPages(
        startingAt: AppBskyFeedGetAuthorFeed.Parameters(actor: actor, limit: 100),
        maxPages: 3
    ) {
        try await client.app.bsky.feed.getAuthorFeed(input: $0)
    }

    var uris: [ATProtocolURI] = []
    for try await page in pages {
        uris.append(contentsOf: page.feed.map(\.post.uri))
    }
    return uris
}
```

For a scrolling list, keep the last `cursor` yourself and call again when the user nears
the end. A `nil` or empty cursor means there are no more pages.

## Read the home timeline

`getTimeline` needs a signed-in client (see <doc:Authentication>). It is the feed the
account's Following tab shows:

<!-- compile-example: feeds-timeline -->
```swift
import Petrel

func loadHomeTimeline(client: ATProtoClient) async throws -> (posts: [AppBskyFeedDefs.FeedViewPost], cursor: String?) {
    let (_, page) = try await client.app.bsky.feed.getTimeline(
        input: .init(limit: 30)
    )
    return (page?.feed ?? [], page?.cursor)
}
```

To fetch the page after it, call again with `.init(limit: 30, cursor: cursor)`.

## Read a custom feed

A custom feed is served by a feed generator and named by the AT-URI of its
`app.bsky.feed.generator` record. Pass that URI to `getFeed`. The AppView asks the
generator for the post list and hydrates it, so the result has the same shape as a
timeline page:

<!-- compile-example: feeds-custom-feed -->
```swift
import Petrel

func loadCustomFeed(client: ATProtoClient) async throws -> [AppBskyFeedDefs.FeedViewPost] {
    // Bluesky's "Discover" feed, published by the bsky.app account.
    let feed = try ATProtocolURI(
        uriString: "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"
    )
    let (_, page) = try await client.app.bsky.feed.getFeed(
        input: .init(feed: feed, limit: 30)
    )
    return page?.feed ?? []
}
```

Some generators tailor their results to the account that asks. Call them from a signed-in
client to get that account's view. To build a feed generator of your own, see
<doc:ServiceAuthentication>, which shows how to verify the service-auth token the AppView
sends with each `app.bsky.feed.getFeedSkeleton` request.

## Read a thread

`getPostThread` returns the post at `uri` with up to `parentHeight` ancestors and `depth`
levels of replies. Each node is a union: a post you can see, a post that was deleted
(`NotFoundPost`), or a post hidden by a block (`BlockedPost`). Handle all three, and treat
any other value as hidden, because new node types can appear:

<!-- compile-example: feeds-post-thread -->
```swift
import Petrel

func printThread(client: ATProtoClient, uri: ATProtocolURI) async throws {
    let (_, output) = try await client.app.bsky.feed.getPostThread(
        input: .init(uri: uri, depth: 3, parentHeight: 10)
    )
    guard let output else { return }

    switch output.thread {
    case let .appBskyFeedDefsThreadViewPost(root):
        printReplies(of: root, indent: "")
    case .appBskyFeedDefsNotFoundPost:
        print("This post was deleted.")
    case .appBskyFeedDefsBlockedPost:
        print("This post is hidden because of a block.")
    case .unexpected:
        print("This post can't be shown.")
    }
}

func printReplies(of node: AppBskyFeedDefs.ThreadViewPost, indent: String) {
    let text = node.post.record.decoded(AppBskyFeedPost.self)?.text ?? ""
    print("\(indent)@\(node.post.author.handle.description): \(text)")

    for reply in node.replies ?? [] {
        if case let .appBskyFeedDefsThreadViewPost(child) = reply {
            printReplies(of: child, indent: indent + "  ")
        }
    }
}
```

Ancestors are in `parent`, nearest first, with the same three cases.

## Show posts safely

A feed item can carry labels, and the account's moderation preferences decide whether to
show, blur or hide it. Run each post through ``Moderation`` before you render it; see
<doc:BlueskyModeration>. To reply to, like or repost what you show, see
<doc:BlueskyPosting>.
