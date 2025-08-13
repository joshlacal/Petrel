# Petrel

A comprehensive Swift library for the AT Protocol and Bluesky social network, featuring automatic code generation, modern Swift concurrency, and robust authentication.

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%2B%20%7C%20macOS%2014%2B-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Overview

Petrel provides a complete Swift implementation of the AT Protocol APIs, enabling developers to build native iOS and macOS applications that interact with Bluesky and other AT Protocol-based services. The library features:

- 🚀 **Automatic Code Generation** - Swift types and networking code generated from official Lexicon specifications
- ⚡ **Modern Swift Concurrency** - Built with async/await and actors for thread-safe operations
- 🔐 **Robust Authentication** - Support for OAuth 2.0 and legacy authentication with automatic token refresh
- 📦 **Type-Safe APIs** - Strongly typed request/response models with compile-time safety
- 🛡️ **Secure Storage** - Credentials stored securely in the system keychain
- 🎯 **Comprehensive Coverage** - Full implementation of Bluesky APIs including feeds, posts, profiles, and more

## Installation

### Swift Package Manager

Add Petrel to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/joshlacal/Petrel.git", from: "1.0.0")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: ["Petrel"]
)
```

### Xcode

1. In Xcode, go to File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/joshlacal/Petrel.git`
3. Choose your version requirements
4. Add Petrel to your target

## Quick Start

### Basic Usage (Unauthenticated)

```swift
import Petrel

// Create a client
let client = ATProtoClient()

// Fetch a user's profile
let profile = try await client.app.bsky.actor.getProfile(
    AppBskyActorGetProfile.Parameters(actor: "alice.bsky.social")
)

print("Name: \(profile.displayName ?? "")")
print("Bio: \(profile.description ?? "")")
print("Followers: \(profile.followersCount ?? 0)")
```

### Authenticated Usage

```swift
import Petrel

// Create authentication service
let authService = AuthenticationService()

// Authenticate with password (use app passwords!)
let account = try await authService.authenticateWithPassword(
    identifier: "alice.bsky.social",
    password: "your-app-password"
)

// Create authenticated client
let client = ATProtoClient(authenticationService: authService)

// Create a post
let post = AppBskyFeedPost(
    text: "Hello from Petrel! 🐦",
    createdAt: Date()
)

let result = try await client.com.atproto.repo.createRecord(
    ComAtprotoRepoCreateRecord.Input(
        repo: account.did,
        collection: "app.bsky.feed.post",
        record: .appBskyFeedPost(post)
    )
)

print("Post created: \(result.uri)")
```

### OAuth Authentication (Recommended)

```swift
// Start OAuth flow
let authURL = try await authService.startOAuthAuthentication(
    identifier: "alice.bsky.social"
)

// Open authURL in browser or web view
// ... 

// Handle callback after user authorization
let account = try await authService.handleOAuthCallback(
    callbackURL: receivedCallbackURL
)
```

## Core Features

### 🔄 Automatic Token Refresh

Petrel automatically handles token expiration and refresh:

```swift
// Tokens are automatically refreshed when needed
let timeline = try await client.app.bsky.feed.getTimeline(
    AppBskyFeedGetTimeline.Parameters(limit: 50)
)
```

### 📝 Rich Text Support

Create posts with mentions, links, and hashtags:

```swift
let richText = RichText(text: "Hello @alice.bsky.social! Check out #Petrel")
let facets = try await richText.buildFacets(client: client)

let post = AppBskyFeedPost(
    text: richText.text,
    facets: facets,
    createdAt: Date()
)
```

### 🖼️ Media Upload

Upload images and videos:

```swift
// Upload image
let imageData = try Data(contentsOf: imageURL)
let blob = try await client.com.atproto.repo.uploadBlob(imageData)

// Create post with image
let post = AppBskyFeedPost(
    text: "Check out this photo!",
    embed: .appBskyEmbedImages(AppBskyEmbedImages(
        images: [AppBskyEmbedImages.Image(
            image: blob.blob,
            alt: "Description of image"
        )]
    )),
    createdAt: Date()
)
```

### 🔍 Search and Discovery

```swift
// Search for users
let searchResults = try await client.app.bsky.actor.searchActors(
    AppBskyActorSearchActors.Parameters(q: "swift developer")
)

// Get suggested follows
let suggestions = try await client.app.bsky.actor.getSuggestions(
    AppBskyActorGetSuggestions.Parameters(limit: 20)
)
```

### 💬 Social Interactions

```swift
// Like a post
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

// Follow a user
let follow = AppBskyGraphFollow(
    subject: userDid,
    createdAt: Date()
)

try await client.com.atproto.repo.createRecord(
    ComAtprotoRepoCreateRecord.Input(
        repo: account.did,
        collection: "app.bsky.graph.follow",
        record: .appBskyGraphFollow(follow)
    )
)
```

## Architecture

### Code Generation

Petrel uses automated code generation from official AT Protocol Lexicon JSON files:

```bash
# Regenerate Swift code from latest Lexicons
cd Petrel
python Generator/main.py
```

Generated files are placed in `Sources/Petrel/Generated/` with a 1:1 mapping:
- `app.bsky.feed.post` → `AppBskyFeedPost.swift`
- `com.atproto.repo.createRecord` → `ComAtprotoRepoCreateRecord.swift`

### API Structure

APIs are organized using namespace properties on the main client:

```swift
client.app.bsky.feed.getTimeline()     // app.bsky.feed.getTimeline
client.com.atproto.repo.createRecord() // com.atproto.repo.createRecord
```

### Thread Safety

Petrel uses Swift's actor model for thread-safe operations:

```swift
// ATProtoClient is an actor - all operations are thread-safe
await client.app.bsky.feed.getTimeline(...)
```

## Documentation

- [Getting Started Guide](./GETTING_STARTED.md) - Detailed setup and first steps
- [API Reference](./API_REFERENCE.md) - Complete API documentation
- [Contributing Guide](./CONTRIBUTING.md) - How to contribute to Petrel
- [DocC Documentation](https://joshlacal.github.io/Petrel/documentation/petrel/) - Full API documentation

## Example App

Check out [Catbird](https://github.com/joshlacal/Catbird), a full-featured iOS client for Bluesky built with Petrel, to see the library in action.

## Requirements

- iOS 17.0+ / macOS 14.0+
- Xcode 16.0+
- Swift 6.0+

## Dependencies

- [jose-swift](https://github.com/beatt83/jose-swift.git) - JWT and DPoP support
- [SwiftCBOR](https://github.com/valpackett/SwiftCBOR.git) - CBOR encoding/decoding
- [AsyncDNSResolver](https://github.com/apple/swift-async-dns-resolver) - Async DNS resolution

## Contributing

We welcome contributions! Please see our [Contributing Guide](./CONTRIBUTING.md) for details on:

- Setting up your development environment
- Code generation workflow
- Testing guidelines
- Pull request process

## License

Petrel is available under the MIT license. See the [LICENSE](./LICENSE) file for details.

## Acknowledgments

- The [Bluesky](https://bsky.social) team for creating AT Protocol
- The Swift community for excellent open-source packages
- Contributors and users of Petrel

---

Made with ❤️ for the Bluesky community
