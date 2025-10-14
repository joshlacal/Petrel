# Service DID Configuration

## Overview

Petrel now supports configurable service DIDs for all Bluesky and AT Protocol services. This allows you to route requests to custom AppView or Chat service instances while maintaining backward compatibility with the default Bluesky infrastructure.

## Default Configuration

By default, Petrel routes requests to the standard Bluesky services:

- **app.bsky.*** endpoints → `did:web:api.bsky.app#bsky_appview`
- **chat.bsky.*** endpoints → `did:web:api.bsky.chat#bsky_chat`

## Configuring Custom Service DIDs

You can configure custom service DIDs when initializing the ATProtoClient:

```swift
let client = await ATProtoClient(
    baseURL: URL(string: "https://bsky.social")!,
    oauthConfig: oauthConfig,
    namespace: "com.example.myapp",
    bskyAppViewDID: "did:web:custom.appview.example#custom_appview",
    bskyChatDID: "did:web:custom.chat.example#custom_chat"
)
```

## Special Cases

### Preferences Endpoints

The following endpoints **always** use the default Bluesky AppView DID, regardless of custom configuration:

- `app.bsky.actor.getPreferences`
- `app.bsky.actor.putPreferences`

This is because the PDS stores Bluesky preferences locally and redirects these requests to the standard AppView service.

## How It Works

1. When a request is made to any `app.bsky.*` or `chat.bsky.*` endpoint, the NetworkService determines the appropriate service DID
2. If a service DID is configured for the endpoint's namespace, it's added as an `atproto-proxy` header
3. The PDS routes the request to the specified service using the proxy header

## Implementation Details

### NetworkService Methods

```swift
// Set a service DID for a namespace
await networkService.setServiceDID("did:web:api.bsky.app#bsky_appview", for: "app.bsky")

// Get the service DID for a specific endpoint
let serviceDID = await networkService.getServiceDID(for: "app.bsky.feed.getTimeline")
```

### Namespace Matching

The service DID mapping uses prefix matching with longest-match-first logic:

- `"chat.bsky.convo.listConvos"` matches `"chat.bsky"` → returns chat service DID
- `"app.bsky.feed.getTimeline"` matches `"app.bsky"` → returns AppView service DID
- `"com.atproto.repo.createRecord"` has no match → returns `nil` (no proxy header added)

## Use Cases

### Custom AppView Instance

If you're running your own AppView instance for testing or development:

```swift
let client = await ATProtoClient(
    baseURL: URL(string: "https://bsky.social")!,
    oauthConfig: oauthConfig,
    namespace: "com.example.myapp",
    bskyAppViewDID: "did:web:dev.appview.mycompany.com#my_appview"
)
```

### Custom Chat Service

For a custom chat/DM service implementation:

```swift
let client = await ATProtoClient(
    baseURL: URL(string: "https://bsky.social")!,
    oauthConfig: oauthConfig,
    namespace: "com.example.myapp",
    bskyChatDID: "did:web:chat.myservice.com#custom_chat"
)
```

## Migration Guide

Existing code continues to work without changes. The default service DIDs match the current behavior:

```swift
// Before - hardcoded chat DID in generator
// (Old code works exactly the same)

// After - configurable with same defaults
let client = await ATProtoClient(
    baseURL: URL(string: "https://bsky.social")!,
    oauthConfig: oauthConfig,
    namespace: "com.example.myapp"
    // bskyAppViewDID and bskyChatDID use defaults
)
```

## Testing

Run the service DID mapping tests:

```bash
swift test --filter ServiceDIDMappingTests
```
