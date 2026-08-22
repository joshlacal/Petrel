# Service DID configuration

In the AT Protocol architecture, a user account's primary endpoint is its Personal Data Server (PDS). Downstream services—such as the Bluesky AppView (`app.bsky.*`) for social feeds and threads, or the Chat service (`chat.bsky.*`) for direct messaging—are independent infrastructure components.

When a client sends an XRPC request targeting a downstream service, it routes the request to the account's PDS and attaches an `atproto-proxy` HTTP header containing the target service's Decentralized Identifier (DID) and service fragment (for example, `did:web:api.bsky.app#bsky_appview`). The PDS verifies the request authentication and reverse-proxies the call to the specified service.

Petrel manages this routing automatically and allows you to configure custom service DIDs when connecting to alternative AppView or Chat backends.

## Default configuration

By default, Petrel routes downstream namespaces to the standard Bluesky infrastructure:

| Lexicon namespace | Default service DID | Destination service |
|---|---|---|
| `app.bsky.*` | `did:web:api.bsky.app#bsky_appview` | Bluesky AppView |
| `chat.bsky.*` | `did:web:api.bsky.chat#bsky_chat` | Bluesky Chat Service |
| `com.atproto.*` | `nil` (no proxy header) | User PDS |

## Configure custom service DIDs

To direct `app.bsky.*` or `chat.bsky.*` requests to custom service deployments, supply the service DIDs during `ATProtoClient` initialization:

```swift
import Foundation
import Petrel

let oauthConfig = OAuthConfig(
    clientId: "https://example.com/oauth/client-metadata.json",
    redirectUri: "https://example.com/oauth/callback",
    scope: "atproto transition:generic"
)

let client = try await ATProtoClient(
    baseURL: URL(string: "https://bsky.social")!,
    oauthConfig: oauthConfig,
    namespace: "com.example.myapp",
    bskyAppViewDID: "did:web:custom.appview.example#custom_appview",
    bskyChatDID: "did:web:custom.chat.example#custom_chat"
)
```

## Special cases and routing behavior

### Preferences endpoints

The following endpoints bypass service DID resolution and are never proxied:

- `app.bsky.actor.getPreferences`
- `app.bsky.actor.putPreferences`

These endpoints are defined in `NetworkService` under `neverProxyEndpoints`. Calling `getServiceDID(for:)` on either endpoint returns `nil`. Because user account preferences are stored directly on the PDS, Petrel transmits these requests straight to the PDS host with no `atproto-proxy` header.

### Namespace prefix matching

When Petrel evaluates an endpoint to determine whether to attach an `atproto-proxy` header, it uses longest-prefix matching against the configured mappings:

1. `"chat.bsky.convo.listConvos"` matches `"chat.bsky"` → returns the configured chat service DID.
2. `"app.bsky.feed.getTimeline"` matches `"app.bsky"` → returns the configured AppView service DID.
3. `"com.atproto.repo.createRecord"` matches no entry → returns `nil` (sent directly to PDS with no proxy header).

## Dynamic runtime updates

To update service DIDs after client initialization, use the client's configuration methods:

```swift
// Update a single namespace mapping
await client.setServiceDID("did:web:custom.appview.example#custom_appview", for: "app.bsky")

// Update both AppView and Chat service DIDs in memory
await client.updateServiceDIDs(
    bskyAppViewDID: "did:web:custom.appview.example#custom_appview",
    bskyChatDID: "did:web:custom.chat.example#custom_chat"
)

// Update and persist service DIDs to the active account record in storage
try await client.updateServiceDIDsForCurrentAccount(
    bskyAppViewDID: "did:web:custom.appview.example#custom_appview",
    bskyChatDID: "did:web:custom.chat.example#custom_chat"
)
```

## Verify configuration

To run the unit tests covering service DID mapping, longest-prefix resolution, and preferences endpoint exclusions:

```bash
swift test --filter ServiceDIDMappingTests
```
