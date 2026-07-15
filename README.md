# Petrel

**A Swift and Kotlin SDK for the [AT Protocol](https://atproto.com) and [Bluesky](https://bsky.app).**

Petrel generates strongly-typed clients from the official atproto lexicons — every endpoint, record type, and union in `com.atproto.*`, `app.bsky.*`, and `chat.bsky.*` is available as native Swift (actor-based, async/await, Swift 6 strict concurrency) and Kotlin (coroutines, kotlinx.serialization).

| | |
|---|---|
| **Swift** | Swift 6 package; iOS 18+ / macOS 15+ / Linux |
| **Kotlin** | JVM 17 module (`kotlin/`), Ktor + kotlinx.serialization |
| **Auth** | Public OAuth (PAR + PKCE + DPoP), confidential gateway/BFF mode, client-assertion backend, legacy app passwords |
| **License** | MIT |

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/joshlacal/Petrel.git", .upToNextMinor(from: "0.2.0"))
]
```

### Kotlin

The Kotlin package lives in `kotlin/` and is consumable today via a Gradle [composite build](https://docs.gradle.org/current/userguide/composite_builds.html) or `publishToMavenLocal`; Maven Central publication is planned.

## Quick start (Swift)

```swift
import Petrel

let oauth = OAuthConfig(
    clientId: "https://yourapp.example/oauth/client-metadata.json",
    redirectUri: "yourapp://oauth/callback",
    scope: "atproto transition:generic"
)

let client = try await ATProtoClient(
    oauthConfig: oauth,
    namespace: "com.example.yourapp",   // keychain namespace for this app's sessions
    userAgent: "YourApp/1.0"
)

// OAuth sign-in
let authURL = try await client.startOAuthFlow(identifier: "yourhandle.bsky.social")
// … present authURL (ASWebAuthenticationSession), receive callbackURL …
try await client.handleOAuthCallback(url: callbackURL)

// Strongly-typed endpoints, mirroring lexicon namespaces
let profile = try await client.app.bsky.actor.getProfile(
    AppBskyActorGetProfile.Parameters(actor: "alice.bsky.social")
)
```

Unauthenticated (public endpoints only):

```swift
let client = await ATProtoClient(baseURL: ATProtoClient.defaultBaseURL)
```

## Quick start (Kotlin)

```kotlin
val client = ATProtoClient(networkService)
val timeline = client.app.bsky.feed.getTimeline(AppBskyFeedGetTimelineParameters(limit = 50))
```

## Token & session behavior worth knowing

- Refresh tokens are single-use and rotate on every refresh. Petrel serializes concurrent refreshes (single-flight per account), never retries a definitively-consumed token, retries transient failures safely, and survives keychain write failures without losing the rotated session.
- Sessions are stored in the platform keychain, default accessibility `afterFirstUnlockThisDeviceOnly` (configurable via `KeychainAccessibility`).
- A circuit breaker with exponential backoff paces refresh attempts after repeated failures.

## Extending with custom lexicons

The generator supports **overlay packages**: keep your own lexicon namespaces in a separate package generated against the public core, without forking Petrel. See `generator/manifests/` and `KOTLIN_GENERATOR.md`.

```bash
# From an activated release environment and a clean checkout
Scripts/regenerate-generated.sh
```

## Documentation

- [GETTING_STARTED.md](GETTING_STARTED.md) — full setup and auth flows
- [API_REFERENCE.md](API_REFERENCE.md) — API overview
- [STRUCTURE.md](STRUCTURE.md) — repository layout
- [KOTLIN_GENERATOR.md](KOTLIN_GENERATOR.md) — Kotlin generation details

## License

MIT — see [LICENSE](LICENSE).
