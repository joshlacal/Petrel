# Petrel API Reference

Complete API documentation for the Petrel Swift library for AT Protocol and Bluesky.

## Table of Contents

- [Core Components](#core-components)
- [Authentication APIs](#authentication-apis)
- [Feed APIs](#feed-apis)
- [Social Graph APIs](#social-graph-apis)
- [Actor/Profile APIs](#actorprofile-apis)
- [Repository APIs](#repository-apis)
- [Moderation APIs](#moderation-apis)
- [Notification APIs](#notification-apis)
- [Chat APIs](#chat-apis)
- [Utility Classes](#utility-classes)
- [Error Types](#error-types)

## Core Components

### ATProtoClient

The main client actor for making API calls.

```swift
public actor ATProtoClient {
    // Initialize with OAuth configuration and a storage namespace
    public init(
        baseURL: URL = URL(string: "https://bsky.social")!,
        oauthConfig: OAuthConfig,
        namespace: String,
        userAgent: String? = nil,
        didResolver: DIDResolving? = nil
    )

    // High‑level helpers
    public func startOAuthFlow(identifier: String?) async throws -> URL
    public func handleOAuthCallback(url: URL) async throws
    public func logout() async throws
    public func refreshToken() async throws -> Bool

    // Namespaces for API access (generated)
    public var app: AppNamespace { get }
    public var com: ComNamespace { get }
    public var chat: ChatNamespace { get }
    public var tools: ToolsNamespace { get }
}
```

## Authentication APIs

### Password Authentication

```swift
// com.atproto.server.createSession
let session = try await client.com.atproto.server.createSession(
    ComAtprotoServerCreateSession.Input(
        identifier: "alice.bsky.social",
        password: "app-password"
    )
)
```

### Token Refresh

```swift
// com.atproto.server.refreshSession
let refreshed = try await client.com.atproto.server.refreshSession()
```

### App Passwords

```swift
// Create app password
let appPassword = try await client.com.atproto.server.createAppPassword(
    ComAtprotoServerCreateAppPassword.Input(
        name: "My App"
    )
)

// List app passwords
let passwords = try await client.com.atproto.server.listAppPasswords()

// Revoke app password
try await client.com.atproto.server.revokeAppPassword(
    ComAtprotoServerRevokeAppPassword.Input(
        name: "My App"
    )
)
```

## Feed APIs

### Timeline Operations

```swift
// Get home timeline
let timeline = try await client.app.bsky.feed.getTimeline(
    AppBskyFeedGetTimeline.Parameters(
        algorithm: "reverse-chronological",
        limit: 50,
        cursor: nil
    )
)

// Process timeline posts - unwrapping ATProtocolValueContainer
for feedViewPost in timeline.feed {
    // Unwrap the post record from ATProtocolValueContainer
    if case .knownType(let record) = feedViewPost.post.record,
       let feedPost = record as? AppBskyFeedPost {
        // Now you can access feedPost.text and other AppBskyFeedPost properties
        print("Post text: \(feedPost.text)")
        print("Created at: \(feedPost.createdAt)")
        
        // Access facets (mentions, links, hashtags)
        if let facets = feedPost.facets {
            for facet in facets {
                // Process facets
            }
        }
        
        // Check for embeds
        if let embed = feedPost.embed {
            switch embed {
            case .appBskyEmbedImages(let images):
                print("Post has \(images.images.count) images")
            case .appBskyEmbedExternal(let external):
                print("External link: \(external.external.uri)")
            case .appBskyEmbedRecord(let record):
                print("Quote post")
            case .appBskyEmbedRecordWithMedia(let recordWithMedia):
                print("Quote post with media")
            default:
                break
            }
        }
    }
}

// Get author feed
let authorFeed = try await client.app.bsky.feed.getAuthorFeed(
    AppBskyFeedGetAuthorFeed.Parameters(
        actor: "alice.bsky.social",
        limit: 30,
        cursor: nil,
        filter: "posts_with_replies" // or "posts_no_replies", "posts_with_media"
    )
)
```

### Post Operations

```swift
// Create a post
let post = AppBskyFeedPost(
    text: "Hello world!",
    facets: nil,
    reply: nil,
    embed: nil,
    langs: ["en"],
    labels: nil,
    tags: nil,
    createdAt: Date()
)

let created = try await client.com.atproto.repo.createRecord(
    ComAtprotoRepoCreateRecord.Input(
        repo: account.did,
        collection: "app.bsky.feed.post",
        rkey: nil, // optional record key
        validate: true,
        record: .appBskyFeedPost(post),
        swapCommit: nil
    )
)

// Get posts
let posts = try await client.app.bsky.feed.getPosts(
    AppBskyFeedGetPosts.Parameters(
        uris: ["at://did:plc:abc123/app.bsky.feed.post/xyz789"]
    )
)

// Delete a post
try await client.com.atproto.repo.deleteRecord(
    ComAtprotoRepoDeleteRecord.Input(
        repo: account.did,
        collection: "app.bsky.feed.post",
        rkey: "xyz789",
        swapRecord: nil,
        swapCommit: nil
    )
)
```

### Thread Operations

```swift
// Get post thread
let thread = try await client.app.bsky.feed.getPostThread(
    AppBskyFeedGetPostThread.Parameters(
        uri: "at://did:plc:abc123/app.bsky.feed.post/xyz789",
        depth: 10,
        parentHeight: 10
    )
)

// Reply to a post
let reply = AppBskyFeedPost(
    text: "Great post!",
    reply: ReplyRef(
        root: StrongRef(uri: rootUri, cid: rootCid),
        parent: StrongRef(uri: parentUri, cid: parentCid)
    ),
    createdAt: Date()
)
```

### Interactions

```swift
// Like a post
let like = AppBskyFeedLike(
    subject: StrongRef(uri: postUri, cid: postCid),
    createdAt: Date()
)

let likeResult = try await client.com.atproto.repo.createRecord(
    ComAtprotoRepoCreateRecord.Input(
        repo: account.did,
        collection: "app.bsky.feed.like",
        record: .appBskyFeedLike(like)
    )
)

// Repost
let repost = AppBskyFeedRepost(
    subject: StrongRef(uri: postUri, cid: postCid),
    createdAt: Date()
)

// Get likes for a post
let likes = try await client.app.bsky.feed.getLikes(
    AppBskyFeedGetLikes.Parameters(
        uri: postUri,
        limit: 50,
        cursor: nil
    )
)

// Get reposts
let reposts = try await client.app.bsky.feed.getRepostedBy(
    AppBskyFeedGetRepostedBy.Parameters(
        uri: postUri,
        limit: 50,
        cursor: nil
    )
)
```

### Feed Generators

```swift
// Get feed generator
let generator = try await client.app.bsky.feed.getFeedGenerator(
    AppBskyFeedGetFeedGenerator.Parameters(
        feed: "at://did:plc:abc123/app.bsky.feed.generator/whats-hot"
    )
)

// Get feed from generator
let feed = try await client.app.bsky.feed.getFeed(
    AppBskyFeedGetFeed.Parameters(
        feed: "at://did:plc:abc123/app.bsky.feed.generator/whats-hot",
        limit: 50,
        cursor: nil
    )
)

// Get suggested feeds
let suggested = try await client.app.bsky.feed.getSuggestedFeeds(
    AppBskyFeedGetSuggestedFeeds.Parameters(
        limit: 10,
        cursor: nil
    )
)
```

## Social Graph APIs

### Following/Followers

```swift
// Follow someone
let follow = AppBskyGraphFollow(
    subject: "did:plc:targetuser",
    createdAt: Date()
)

let followResult = try await client.com.atproto.repo.createRecord(
    ComAtprotoRepoCreateRecord.Input(
        repo: account.did,
        collection: "app.bsky.graph.follow",
        record: .appBskyGraphFollow(follow)
    )
)

// Get followers
let followers = try await client.app.bsky.graph.getFollowers(
    AppBskyGraphGetFollowers.Parameters(
        actor: "alice.bsky.social",
        limit: 100,
        cursor: nil
    )
)

// Get following
let following = try await client.app.bsky.graph.getFollows(
    AppBskyGraphGetFollows.Parameters(
        actor: "alice.bsky.social",
        limit: 100,
        cursor: nil
    )
)

// Unfollow
try await client.com.atproto.repo.deleteRecord(
    ComAtprotoRepoDeleteRecord.Input(
        repo: account.did,
        collection: "app.bsky.graph.follow",
        rkey: followRecordKey
    )
)
```

### Blocks and Mutes

```swift
// Block a user
let block = AppBskyGraphBlock(
    subject: "did:plc:blockeduser",
    createdAt: Date()
)

let blockResult = try await client.com.atproto.repo.createRecord(
    ComAtprotoRepoCreateRecord.Input(
        repo: account.did,
        collection: "app.bsky.graph.block",
        record: .appBskyGraphBlock(block)
    )
)

// Mute a user
try await client.app.bsky.graph.muteActor(
    AppBskyGraphMuteActor.Input(
        actor: "did:plc:muteduser"
    )
)

// Unmute a user
try await client.app.bsky.graph.unmuteActor(
    AppBskyGraphUnmuteActor.Input(
        actor: "did:plc:muteduser"
    )
)

// Get muted users
let mutes = try await client.app.bsky.graph.getMutes(
    AppBskyGraphGetMutes.Parameters(
        limit: 50,
        cursor: nil
    )
)

// Get blocked users
let blocks = try await client.app.bsky.graph.getBlocks(
    AppBskyGraphGetBlocks.Parameters(
        limit: 50,
        cursor: nil
    )
)
```

### Lists

```swift
// Create a list
let list = AppBskyGraphList(
    purpose: "app.bsky.graph.defs#curatelist", // or "app.bsky.graph.defs#modlist"
    name: "My Favorite Accounts",
    description: "A curated list of great accounts",
    descriptionFacets: nil,
    avatar: nil,
    labels: nil,
    createdAt: Date()
)

let listResult = try await client.com.atproto.repo.createRecord(
    ComAtprotoRepoCreateRecord.Input(
        repo: account.did,
        collection: "app.bsky.graph.list",
        record: .appBskyGraphList(list)
    )
)

// Add user to list
let listItem = AppBskyGraphListitem(
    subject: "did:plc:usertoAdd",
    list: listResult.uri,
    createdAt: Date()
)

// Get lists
let lists = try await client.app.bsky.graph.getLists(
    AppBskyGraphGetLists.Parameters(
        actor: "alice.bsky.social",
        limit: 50,
        cursor: nil
    )
)

// Get list members
let listMembers = try await client.app.bsky.graph.getList(
    AppBskyGraphGetList.Parameters(
        list: listUri,
        limit: 100,
        cursor: nil
    )
)
```

## Actor/Profile APIs

### Profile Management

```swift
// Get profile
let profile = try await client.app.bsky.actor.getProfile(
    AppBskyActorGetProfile.Parameters(
        actor: "alice.bsky.social"
    )
)

// Get multiple profiles
let profiles = try await client.app.bsky.actor.getProfiles(
    AppBskyActorGetProfiles.Parameters(
        actors: ["alice.bsky.social", "bob.bsky.social"]
    )
)

// Update profile
let profileRecord = AppBskyActorProfile(
    displayName: "Alice",
    description: "Swift developer 🧑‍💻",
    avatar: avatarBlob,
    banner: bannerBlob,
    labels: nil,
    joinedViaStarterPack: nil,
    associatedChat: nil,
    createdAt: nil
)

try await client.com.atproto.repo.putRecord(
    ComAtprotoRepoPutRecord.Input(
        repo: account.did,
        collection: "app.bsky.actor.profile",
        rkey: "self",
        validate: true,
        record: .appBskyActorProfile(profileRecord),
        swapRecord: currentProfileCid,
        swapCommit: nil
    )
)
```

### Search

```swift
// Search for actors
let searchResults = try await client.app.bsky.actor.searchActors(
    AppBskyActorSearchActors.Parameters(
        q: "swift developer",
        limit: 25,
        cursor: nil
    )
)

// Typeahead search
let typeahead = try await client.app.bsky.actor.searchActorsTypeahead(
    AppBskyActorSearchActorsTypeahead.Parameters(
        q: "ali",
        limit: 10
    )
)
```

### Preferences

```swift
// Get preferences
let prefs = try await client.app.bsky.actor.getPreferences()

// Update preferences
try await client.app.bsky.actor.putPreferences(
    AppBskyActorPutPreferences.Input(
        preferences: [
            .adultContentPref(AdultContentPref(enabled: false)),
            .contentLabelPref(ContentLabelPref(
                label: "nsfw",
                visibility: "hide"
            )),
            .feedViewPref(FeedViewPref(
                feed: "at://did:plc:abc/app.bsky.feed.generator/whats-hot",
                hideReplies: false,
                hideRepliesByUnfollowed: true,
                hideRepliesByLikeCount: 2,
                hideReposts: false,
                hideQuotePosts: false
            ))
        ]
    )
)
```

## Repository APIs

### Record Management

```swift
// Create record
let created = try await client.com.atproto.repo.createRecord(
    ComAtprotoRepoCreateRecord.Input(
        repo: account.did,
        collection: "app.bsky.feed.post",
        rkey: nil,
        validate: true,
        record: record,
        swapCommit: nil
    )
)

// Get record
let record = try await client.com.atproto.repo.getRecord(
    ComAtprotoRepoGetRecord.Parameters(
        repo: account.did,
        collection: "app.bsky.feed.post",
        rkey: "3k7xz3gefds2l",
        cid: nil
    )
)

// Update record
try await client.com.atproto.repo.putRecord(
    ComAtprotoRepoPutRecord.Input(
        repo: account.did,
        collection: "app.bsky.feed.post",
        rkey: "3k7xz3gefds2l",
        validate: true,
        record: updatedRecord,
        swapRecord: currentCid,
        swapCommit: nil
    )
)

// Delete record
try await client.com.atproto.repo.deleteRecord(
    ComAtprotoRepoDeleteRecord.Input(
        repo: account.did,
        collection: "app.bsky.feed.post",
        rkey: "3k7xz3gefds2l",
        swapRecord: currentCid,
        swapCommit: nil
    )
)

// List records
let records = try await client.com.atproto.repo.listRecords(
    ComAtprotoRepoListRecords.Parameters(
        repo: account.did,
        collection: "app.bsky.feed.post",
        limit: 100,
        cursor: nil,
        rkeyStart: nil,
        rkeyEnd: nil,
        reverse: false
    )
)
```

### Blob Management

```swift
// Upload blob
let imageData = try Data(contentsOf: imageURL)
let blob = try await client.com.atproto.repo.uploadBlob(imageData)

// The returned blob can be used in records
let post = AppBskyFeedPost(
    text: "Check this out!",
    embed: .appBskyEmbedImages(AppBskyEmbedImages(
        images: [AppBskyEmbedImages.Image(
            image: blob.blob,
            alt: "Description"
        )]
    )),
    createdAt: Date()
)
```

## Moderation APIs

### Reporting

```swift
// Report a post
try await client.com.atproto.moderation.createReport(
    ComAtprotoModerationCreateReport.Input(
        reasonType: "com.atproto.moderation.defs#reasonSpam",
        reason: "This is spam",
        subject: .repoRef(RepoRef(did: "did:plc:spammer"))
    )
)

// Report with specific content
try await client.com.atproto.moderation.createReport(
    ComAtprotoModerationCreateReport.Input(
        reasonType: "com.atproto.moderation.defs#reasonViolation",
        reason: "Violates community guidelines",
        subject: .strongRef(StrongRef(
            uri: "at://did:plc:abc/app.bsky.feed.post/xyz",
            cid: "bafyreib..."
        ))
    )
)
```

### Labels

```swift
// Subscribe to label updates
let labels = try await client.com.atproto.label.subscribeLabels(
    ComAtprotoLabelSubscribeLabels.Parameters(
        cursor: nil
    )
)

// Query labels
let labelResults = try await client.com.atproto.label.queryLabels(
    ComAtprotoLabelQueryLabels.Parameters(
        uriPatterns: ["did:plc:*"],
        sources: nil,
        limit: 50,
        cursor: nil
    )
)
```

## Notification APIs

### Notifications

```swift
// List notifications
let notifications = try await client.app.bsky.notification.listNotifications(
    AppBskyNotificationListNotifications.Parameters(
        limit: 50,
        cursor: nil,
        seenAt: nil,
        includeReadd: false,
        includeReason: true,
        verificationState: nil
    )
)

// Update seen status
try await client.app.bsky.notification.updateSeen(
    AppBskyNotificationUpdateSeen.Input(
        seenAt: Date()
    )
)

// Get unread count
let unreadCount = try await client.app.bsky.notification.getUnreadCount(
    AppBskyNotificationGetUnreadCount.Parameters(
        seenAt: lastSeenDate
    )
)
```

### Push Notifications

```swift
// Register for push notifications
try await client.app.bsky.notification.registerPush(
    AppBskyNotificationRegisterPush.Input(
        serviceDid: "did:web:api.bsky.app",
        token: deviceToken,
        platform: "ios",
        appId: "com.example.app"
    )
)
```

## Chat APIs

### Conversations

```swift
// List conversations
let convos = try await client.chat.bsky.convo.listConvos(
    ChatBskyConvoListConvos.Parameters(
        limit: 50,
        cursor: nil
    )
)

// Get conversation
let convo = try await client.chat.bsky.convo.getConvo(
    ChatBskyConvoGetConvo.Parameters(
        convoId: "convo123"
    )
)

// Get messages
let messages = try await client.chat.bsky.convo.getMessages(
    ChatBskyConvoGetMessages.Parameters(
        convoId: "convo123",
        limit: 100,
        cursor: nil
    )
)
```

### Messaging

```swift
// Send message
let message = try await client.chat.bsky.convo.sendMessage(
    ChatBskyConvoSendMessage.Input(
        convoId: "convo123",
        message: MessageInput(
            text: "Hello!",
            facets: nil,
            embed: nil
        )
    )
)

// Delete message
try await client.chat.bsky.convo.deleteMessageForSelf(
    ChatBskyConvoDeleteMessageForSelf.Input(
        convoId: "convo123",
        messageId: "msg456"
    )
)

// Update read status
try await client.chat.bsky.convo.updateRead(
    ChatBskyConvoUpdateRead.Input(
        convoId: "convo123",
        messageId: "msg456"
    )
)
```

## Utility Classes

### ATProtocolValueContainer

A container enum that wraps various AT Protocol values, providing type-safe access to records.

```swift
public enum ATProtocolValueContainer {
    case knownType(any ATProtocolValue)
    case string(String)
    case number(Int)
    case object([String: ATProtocolValueContainer])
    case array([ATProtocolValueContainer])
    case bool(Bool)
    case null
    // ... other cases
}

// Example: Unwrapping post records from timeline
for feedViewPost in timeline.feed {
    // Use pattern matching to unwrap the record
    if case .knownType(let record) = feedViewPost.post.record,
       let post = record as? AppBskyFeedPost {
        // Access post properties
        print("Text: \(post.text)")
        print("Created: \(post.createdAt)")
        
        // Access optional properties
        if let reply = post.reply {
            print("This is a reply to: \(reply.parent.uri)")
        }
    }
}

// Example: Handling different record types
switch someRecord {
case .knownType(let record):
    switch record {
    case let post as AppBskyFeedPost:
        print("Post: \(post.text)")
    case let like as AppBskyFeedLike:
        print("Like of: \(like.subject.uri)")
    case let follow as AppBskyGraphFollow:
        print("Follow of: \(follow.subject)")
    default:
        print("Other record type")
    }
case .string(let str):
    print("String value: \(str)")
case .object(let dict):
    print("Object with \(dict.count) properties")
default:
    print("Other value type")
}
```

### RichText

Helper for building rich text with facets.

```swift
public class RichText {
    public init(text: String)
    
    // Build facets for mentions, links, and hashtags
    public func buildFacets(client: ATProtoClient) async throws -> [Facet]
    
    // Manual facet creation
    public func addMention(handle: String, did: String, range: NSRange)
    public func addLink(url: URL, range: NSRange)
    public func addHashtag(tag: String, range: NSRange)
}

// Example usage
let richText = RichText(text: "Hello @alice.bsky.social! #welcome")
let facets = try await richText.buildFacets(client: client)
```

### TIDGenerator

Generate Time-based IDs for records.

```swift
public struct TIDGenerator {
    // Generate a new TID
    public static func generate() -> String
    
    // Generate TID for specific timestamp
    public static func generate(for date: Date, clockID: UInt16) -> String
}

// Example usage
let tid = TIDGenerator.generate()
```

### CID

Content Identifier handling.

```swift
public struct CID {
    public let bytes: Data
    
    // Create from string
    public init(string: String) throws
    
    // Convert to string
    public var string: String { get }
}
```

### StrongRef

Reference to a record with URI and CID.

```swift
public struct StrongRef: Codable {
    public let uri: String
    public let cid: String
    
    public init(uri: String, cid: String)
}
```

## Error Types

### NetworkError

```swift
public enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(statusCode: Int, message: String?)
    case decodingError(Error)
    case encodingError(Error)
    case networkFailure(Error)
    case cancelled
    case unknown(Error)
}
```

### ATProtoError

```swift
public struct ATProtoError: Error, Codable {
    public let error: String
    public let message: String?
}
```

### Common Error Handling

```swift
do {
    let result = try await client.someAPICall()
} catch NetworkError.unauthorized {
    // Handle authentication failure
} catch NetworkError.rateLimited {
    // Handle rate limiting
} catch NetworkError.serverError(let code, let message) {
    // Handle server errors
} catch {
    // Handle other errors
}
```

## Best Practices

1. **Always use app passwords** - Never use main account passwords
2. **Handle rate limits gracefully** - Implement exponential backoff
3. **Use cursors for pagination** - Don't fetch all data at once
4. **Cache frequently used data** - Reduce API calls
5. **Validate inputs** - Check string lengths and formats
6. **Use proper error handling** - Handle all error cases
7. **Clean up resources** - Delete unused records and blobs

## Type Mappings

Lexicon types map to Swift as follows:

- `string` → `String`
- `number` → `Int`
- `boolean` → `Bool`
- `datetime` → `Date`
- `uri` → `String`
- `at-uri` → `String`
- `did` → `String`
- `handle` → `String`
- `cid` → `String`
- `blob` → `Blob`
- `array` → `[Type]`
- `object` → Custom struct/class
- `union` → Enum with associated values

## Rate Limits

Current Bluesky rate limits (subject to change):

- **Authenticated requests**: 3,000/5 minutes
- **Unauthenticated requests**: 100/5 minutes
- **Create post**: 100/hour
- **Upload blob**: 1,000/hour

Always check response headers for current limits:
- `RateLimit-Limit`
- `RateLimit-Remaining`
- `RateLimit-Reset`

---

For the most up-to-date API documentation, refer to the [AT Protocol specifications](https://atproto.com/specs/xrpc) and [Bluesky API docs](https://docs.bsky.app).
