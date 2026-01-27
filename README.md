# Petrel — ATProto Swift Client

Petrel is a Swift client for the AT Protocol and Bluesky APIs. The primary entrypoint you use is `ATProtoClient` — it encapsulates authentication, networking, and all generated endpoints. You do not need to interact with internal services.

Quick start:

```swift
import Petrel

let oauth = OAuthConfig(
    clientId: "YOUR_CLIENT_ID",
    redirectUri: "yourapp://oauth/callback",
    scope: "atproto app:bsky"
)

let client = await ATProtoClient(
    baseURL: URL(string: "https://bsky.social")!,
    oauthConfig: oauth,
    namespace: "com.example.yourapp",
    userAgent: "YourApp/1.0"
)

// Start OAuth and handle callback
let authURL = try await client.startOAuthFlow(identifier: "yourhandle.bsky.social")
// … present authURL to the user, receive `callbackURL` in your app …
try await client.handleOAuthCallback(url: callbackURL)

// Call generated endpoints
let profile = try await client.app.bsky.actor.getProfile(
    AppBskyActorGetProfile.Parameters(actor: "alice.bsky.social")
)
```

See GETTING_STARTED.md for full usage.