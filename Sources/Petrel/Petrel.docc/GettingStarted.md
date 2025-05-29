# Getting Started

Learn how to integrate Petrel into your Swift project and make your first API calls.

## Installation

Add Petrel to your Swift package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/joshlacal/Petrel.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["Petrel"]
)
```

## Basic Setup

Import Petrel and create a client instance:

```swift
import Petrel

// Create an unauthenticated client
let client = ATProtoClient()

// Fetch a user's profile
let profile = try await client.app.bsky.actor.getProfile(
    AppBskyActorGetProfile.Parameters(actor: "alice.bsky.social")
)
print("Display name: \(profile.displayName ?? "No display name")")
```

## Next Steps

- Learn about <doc:Authentication> to access protected endpoints
- Explore <doc:BasicUsage> for common operations
- Review <doc:ErrorHandling> for robust error management