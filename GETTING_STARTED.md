# Getting Started with Petrel

This guide will walk you through setting up Petrel in your Swift project and making your first API calls to interact with Bluesky.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Basic Setup](#basic-setup)
- [Authentication](#authentication)
- [Making Your First API Calls](#making-your-first-api-calls)
- [Working with Posts](#working-with-posts)
- [Handling Media](#handling-media)
- [Error Handling](#error-handling)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before you begin, ensure you have:

- **Xcode 16.0** or later
- **Swift 6.0** or later
- **iOS 17.0+** or **macOS 14.0+** deployment target
- A Bluesky account (create one at [bsky.app](https://bsky.app))
- An app password for your account (create in Settings → Advanced → App Passwords)

## Installation

### Using Swift Package Manager

1. **In Xcode:**
   - Open your project in Xcode
   - Go to File → Add Package Dependencies
   - Enter: `https://github.com/joshlacal/Petrel.git`
   - Click "Add Package"
   - Select your app target and click "Add Package"

2. **In Package.swift:**
   ```swift
   dependencies: [
       .package(url: "https://github.com/joshlacal/Petrel.git", from: "1.0.0")
   ],
   targets: [
       .target(
           name: "YourApp",
           dependencies: ["Petrel"]
       )
   ]
   ```

## Basic Setup

### Import and Initialize

```swift
import Petrel

// Configure OAuth (register your app with an authorization server)
let oauth = OAuthConfig(
    clientId: "YOUR_CLIENT_ID",
    redirectUri: "yourapp://oauth/callback",
    scope: "atproto app:bsky",
    // Optional hardening toggles (disabled by default for compatibility):
    // - require `iss` in callback and verify it matches the server issuer when supported
    requireIssInCallback: false,
    // - require that the DID's PDS metadata lists the same authorization server issuer used during auth
    enforcePDSAuthorizationBinding: false
)

// Create the client (namespace identifies your app's keychain sandbox)
let client = await ATProtoClient(
    baseURL: URL(string: "https://bsky.social")!,
    oauthConfig: oauth,
    namespace: "com.example.yourapp",
    userAgent: "YourApp/1.0"
)
```

### OAuth Security Hardening Options

Petrel follows the atproto OAuth profile (PKCE + PAR + DPoP). You can opt into stricter checks via `OAuthConfig`:

- `requireIssInCallback` (default: `false`): If the server declares support for the `iss` auth response parameter, require and verify it on callback.
- `enforcePDSAuthorizationBinding` (default: `false`): After exchanging the code and resolving the account DID → PDS, verify the PDS’s protected resource metadata includes the same authorization server issuer. Fails the flow if not.

These options help detect misconfiguration or phishing-style redirects at the cost of being stricter in edge migrations.

### Understanding the API Structure

Petrel mirrors the AT Protocol namespace structure. API calls follow this pattern:

```swift
// AT Protocol: com.atproto.repo.createRecord
// Petrel: client.com.atproto.repo.createRecord()

// Bluesky: app.bsky.feed.getTimeline
// Petrel: client.app.bsky.feed.getTimeline()
```

## Authentication

### OAuth Authentication

```swift
// Start OAuth flow (present this URL to the user)
do {
    let authorizationURL = try await client.startOAuthFlow(identifier: "yourhandle.bsky.social")
    print("Open this URL: \(authorizationURL)")
    
    // After authorization, your app receives the callback URL
    let callbackURL: URL = /* incoming callback URL from your app */
    try await client.handleOAuthCallback(url: callbackURL)
    print("OAuth authentication successful!")
    
} catch {
    print("OAuth failed: \(error)")
}
```

### Checking Authentication Status

```swift
let hasSession = await client.hasValidSession()
print("Has valid session: \(hasSession)")

let info = await client.getActiveAccountInfo()
print("Current DID: \(info.did ?? "-")  handle: \(info.handle ?? "-")")
```

### Handling OAuth callback (iOS/macOS)

On iOS, implement `application(_:open:options:)` (UIKit) or the SwiftUI `onOpenURL` handler to pass the callback URL to the client:

```swift
// AppDelegate.swift (UIKit)
func application(_ app: UIApplication,
                 open url: URL,
                 options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    Task { await handleOAuthCallback(url) }
    return true
}

private func handleOAuthCallback(_ url: URL) async {
    do {
        try await client.handleOAuthCallback(url: url)
    } catch {
        print("OAuth callback handling failed: \(error)")
    }
}
```

On macOS, use `NSApplicationDelegate.application(_:open:)` similarly to forward the URL to `client.handleOAuthCallback(url:)`.

## Making Your First API Calls

### Fetching a User Profile

```swift
// Get a user's profile (works without authentication)
do {
    let profile = try await client.app.bsky.actor.getProfile(
        AppBskyActorGetProfile.Parameters(actor: "alice.bsky.social")
    )
    
    print("Display Name: \(profile.displayName ?? "No name")")
    print("Bio: \(profile.description ?? "No bio")")
    print("Followers: \(profile.followersCount ?? 0)")
    print("Following: \(profile.followsCount ?? 0)")
    print("Posts: \(profile.postsCount ?? 0)")
    
} catch {
    print("Failed to fetch profile: \(error)")
}
```

### Getting Your Timeline

```swift
// Fetch your home timeline (requires authentication)
do {
    let timeline = try await client.app.bsky.feed.getTimeline(
        AppBskyFeedGetTimeline.Parameters(
            limit: 50,
            cursor: nil // Use cursor from previous response for pagination
        )
    )
    
    // Process each post in the timeline
    for item in timeline.feed {
        // The post record is wrapped in ATProtocolValueContainer
        // Use pattern matching to unwrap it
        if case .knownType(let record) = item.post.record,
           let post = record as? AppBskyFeedPost {
            // Now you can access all AppBskyFeedPost properties
            print("\(item.post.author.displayName ?? item.post.author.handle): \(post.text)")
            
            // Check for mentions, links, or hashtags
            if let facets = post.facets {
                for facet in facets {
                    print("  Facet at byte range: \(facet.index.byteStart)-\(facet.index.byteEnd)")
                }
            }
            
            // Check if post has media
            if let embed = post.embed {
                switch embed {
                case .appBskyEmbedImages(let images):
                    print("  Has \(images.images.count) image(s)")
                case .appBskyEmbedExternal(let external):
                    print("  Links to: \(external.external.uri)")
                default:
                    print("  Has other embed type")
                }
            }
        }
    }
    
    // Save cursor for next page
    let nextCursor = timeline.cursor
    
} catch {
    print("Failed to fetch timeline: \(error)")
}
```

### Searching for Users

```swift
do {
    let results = try await client.app.bsky.actor.searchActors(
        AppBskyActorSearchActors.Parameters(
            q: "swift developer",
            limit: 25
        )
    )
    
    for actor in results.actors {
        print("\(actor.handle) - \(actor.displayName ?? "")")
    }
    
} catch {
    print("Search failed: \(error)")
}
```

## Working with Posts

### Creating a Simple Post

```swift
do {
    // Create post content
    let post = AppBskyFeedPost(
        text: "Hello Bluesky! Posted from my Swift app using Petrel 🐦",
        createdAt: Date()
    )
    
    // Create the record
    let result = try await client.com.atproto.repo.createRecord(
        ComAtprotoRepoCreateRecord.Input(
            repo: authService.currentAccount!.did,
            collection: "app.bsky.feed.post",
            record: .appBskyFeedPost(post)
        )
    )
    
    print("Post created! URI: \(result.uri)")
    
} catch {
    print("Failed to create post: \(error)")
}
```

### Creating Posts with Rich Text

```swift
// Create post with mentions and hashtags
let text = "Hey @alice.bsky.social! Check out #SwiftLang and #Petrel"
let richText = RichText(text: text)

// Build facets (mentions, links, hashtags)
let facets = try await richText.buildFacets(client: client)

let post = AppBskyFeedPost(
    text: richText.text,
    facets: facets,
    createdAt: Date()
)
```

### Replying to a Post

```swift
// Create a reply
let reply = AppBskyFeedPost(
    text: "Great post! 👍",
    reply: ReplyRef(
        root: StrongRef(uri: rootPostUri, cid: rootPostCid),
        parent: StrongRef(uri: parentPostUri, cid: parentPostCid)
    ),
    createdAt: Date()
)

let result = try await client.com.atproto.repo.createRecord(
    ComAtprotoRepoCreateRecord.Input(
        repo: account.did,
        collection: "app.bsky.feed.post",
        record: .appBskyFeedPost(reply)
    )
)
```

### Liking a Post

```swift
let like = AppBskyFeedLike(
    subject: StrongRef(uri: postUri, cid: postCid),
    createdAt: Date()
)

try await client.com.atproto.repo.createRecord(
    ComAtprotoRepoCreateRecord.Input(
        repo: account.did,
        collection: "app.bsky.feed.like",
        record: .appBskyFeedLike(like)
    )
)
```

### Reposting

```swift
let repost = AppBskyFeedRepost(
    subject: StrongRef(uri: postUri, cid: postCid),
    createdAt: Date()
)

try await client.com.atproto.repo.createRecord(
    ComAtprotoRepoCreateRecord.Input(
        repo: account.did,
        collection: "app.bsky.feed.repost",
        record: .appBskyFeedRepost(repost)
    )
)
```

## Handling Media

### Uploading Images

```swift
do {
    // Load image data
    let imageURL = URL(fileURLWithPath: "path/to/image.jpg")
    let imageData = try Data(contentsOf: imageURL)
    
    // Upload to blob storage
    let uploadResult = try await client.com.atproto.repo.uploadBlob(imageData)
    
    // Create post with image
    let post = AppBskyFeedPost(
        text: "Check out this photo!",
        embed: .appBskyEmbedImages(AppBskyEmbedImages(
            images: [AppBskyEmbedImages.Image(
                image: uploadResult.blob,
                alt: "A beautiful sunset" // Alt text for accessibility
            )]
        )),
        createdAt: Date()
    )
    
    // Post it
    let result = try await client.com.atproto.repo.createRecord(
        ComAtprotoRepoCreateRecord.Input(
            repo: account.did,
            collection: "app.bsky.feed.post",
            record: .appBskyFeedPost(post)
        )
    )
    
} catch {
    print("Failed to upload image: \(error)")
}
```

### Multiple Images

```swift
// Upload multiple images (up to 4)
var images: [AppBskyEmbedImages.Image] = []

for imageURL in imageURLs {
    let data = try Data(contentsOf: imageURL)
    let blob = try await client.com.atproto.repo.uploadBlob(data)
    
    images.append(AppBskyEmbedImages.Image(
        image: blob.blob,
        alt: "Image description"
    ))
}

let post = AppBskyFeedPost(
    text: "Multiple images!",
    embed: .appBskyEmbedImages(AppBskyEmbedImages(images: images)),
    createdAt: Date()
)
```

## Error Handling

### Network Errors

```swift
do {
    let profile = try await client.app.bsky.actor.getProfile(
        AppBskyActorGetProfile.Parameters(actor: "user.bsky.social")
    )
} catch let error as NetworkError {
    switch error {
    case .invalidResponse:
        print("Invalid response from server")
    case .unauthorized:
        print("Authentication required or token expired")
    case .rateLimited:
        print("Rate limited - try again later")
    case .serverError(let code, let message):
        print("Server error \(code): \(message)")
    default:
        print("Network error: \(error)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

### Automatic Token Refresh

Petrel automatically handles token refresh, but you can monitor it:

```swift
// Token refresh happens automatically, but you can observe failures
do {
    let timeline = try await client.app.bsky.feed.getTimeline(
        AppBskyFeedGetTimeline.Parameters(limit: 20)
    )
} catch NetworkError.unauthorized {
    // Token refresh failed - user needs to log in again
    print("Session expired - please log in again")
}
```

## Best Practices

### 1. Use App Passwords
Never use your main account password. Always create app-specific passwords.

### 2. Handle Rate Limits
```swift
// Implement exponential backoff for rate limits
func fetchWithRetry<T>(_ operation: () async throws -> T) async throws -> T {
    var retries = 0
    var delay: TimeInterval = 1.0
    
    while retries < 3 {
        do {
            return try await operation()
        } catch NetworkError.rateLimited {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            delay *= 2
            retries += 1
        }
    }
    
    return try await operation()
}
```

### 3. Paginate Large Results
```swift
// Fetch all followers with pagination
var cursor: String? = nil
var allFollowers: [ProfileView] = []

repeat {
    let result = try await client.app.bsky.graph.getFollowers(
        AppBskyGraphGetFollowers.Parameters(
            actor: "user.bsky.social",
            limit: 100,
            cursor: cursor
        )
    )
    
    allFollowers.append(contentsOf: result.followers)
    cursor = result.cursor
    
} while cursor != nil
```

### 4. Cache Frequently Used Data
```swift
// Cache user profiles to reduce API calls
class ProfileCache {
    private var cache: [String: (profile: ProfileView, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    func getProfile(handle: String, client: ATProtoClient) async throws -> ProfileView {
        if let cached = cache[handle],
           Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
            return cached.profile
        }
        
        let profile = try await client.app.bsky.actor.getProfile(
            AppBskyActorGetProfile.Parameters(actor: handle)
        )
        
        cache[handle] = (profile, Date())
        return profile
    }
}
```

## Troubleshooting

### Common Issues

1. **"Invalid identifier or password"**
   - Ensure you're using an app password, not your main password
   - Check that your handle is correct (include .bsky.social)

2. **"Network connection lost"**
   - Check internet connectivity
   - Verify Bluesky services are operational

3. **"Rate limit exceeded"**
   - Implement backoff strategy
   - Reduce request frequency

4. **"Invalid token"**
   - Token may have expired
   - Re-authenticate the user

### Debug Logging

Enable detailed logging for debugging:

```swift
// In your app initialization
import OSLog

let logger = Logger(subsystem: "com.yourapp", category: "Petrel")

// Log API calls
logger.debug("Fetching profile for: \(handle)")
logger.error("API call failed: \(error.localizedDescription)")
```

## Next Steps

Now that you've learned the basics:

1. Explore the [API Reference](./API_REFERENCE.md) for complete documentation
2. Check out [Catbird](https://github.com/joshlacal/Catbird) for a real-world example
3. Read about [Advanced Features](./ADVANCED_FEATURES.md) like custom feeds and moderation
4. Join the Bluesky developer community for support

## Getting Help

- **Documentation**: [Full API Documentation](https://joshlacal.github.io/Petrel/documentation/petrel/)
- **Issues**: [GitHub Issues](https://github.com/joshlacal/Petrel/issues)
- **Bluesky Dev**: [atproto.com](https://atproto.com)

Happy coding with Petrel! 🐦
