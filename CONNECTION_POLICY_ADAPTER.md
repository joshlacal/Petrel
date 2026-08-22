# Connection policy adapter

The `ConnectionPolicyAdapter` protocol lets you control how `ATProtoClient` resolves destination URLs for XRPC HTTP requests and WebSocket streams.

## Problem and routing model

In the AT Protocol architecture, an account's primary network host is its Personal Data Server (PDS). By default, `ATProtoClient` directs XRPC requests to the configured base URL (or account PDS) and attaches `atproto-proxy` headers for downstream services like the Bluesky AppView or Chat service.

This default routing model is insufficient in several operational scenarios:

1. **WebSocket proxy bypass**: Standard HTTP reverse proxies frequently buffer, degrade, or reject long-lived WebSocket connections. Subscriptions like the repository firehose (`com.atproto.sync.subscribeRepos`) require direct connections to streaming hosts without passing through an HTTP proxy layer.
2. **Dedicated service redirection**: Specialized namespaces or private overlay lexicons (such as dedicated messaging delivery services or custom media processing backends) may reside on distinct hosts rather than the PDS.
3. **Environment switching**: Development, staging, and testing environments need dynamic URL substitution without re-instantiating the client or rebuilding authentication state.

`ConnectionPolicyAdapter` intercepts the target URL and endpoint identifier before Petrel establishes a connection, returning either the original URL or a rewritten destination.

## Implement the adapter protocol

The `ConnectionPolicyAdapter` protocol requires one method:

```swift
public protocol ConnectionPolicyAdapter: Sendable {
    func resolveConnectionURL(_ url: URL, endpoint: String?) async -> URL
}
```

Implement the protocol to inspect the incoming URL and endpoint string, returning the resolved destination `URL`:

```swift
import Foundation
import Petrel

public final class WebSocketProxyBypassAdapter: ConnectionPolicyAdapter, Sendable {
    private let directStreamingHost: String

    public init(directStreamingHost: String) {
        self.directStreamingHost = directStreamingHost
    }

    public func resolveConnectionURL(_ url: URL, endpoint: String?) async -> URL {
        // Bypass proxy only for WebSocket connections
        guard url.scheme == "wss" || url.scheme == "ws" else {
            return url
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.host = directStreamingHost
        return components?.url ?? url
    }
}
```

## Configure the client

Set the adapter on `ATProtoClient` using `setConnectionPolicyAdapter(_:)`:

```swift
import Foundation
import Petrel

let client = await ATProtoClient(
    baseURL: URL(string: "https://bsky.social")!
)

let adapter = WebSocketProxyBypassAdapter(directStreamingHost: "bsky.network")
await client.setConnectionPolicyAdapter(adapter)
```

For authenticated clients initialized with OAuth, set the adapter after client initialization:

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
    namespace: "com.example.app"
)

let adapter = WebSocketProxyBypassAdapter(directStreamingHost: "bsky.network")
await client.setConnectionPolicyAdapter(adapter)
```

Once configured, the adapter automatically resolves URLs for both streaming subscriptions and standard queries:

```swift
// WebSocket subscription resolves via the adapter to directStreamingHost
let messages = try await client.com.atproto.sync.subscribeRepos(cursor: nil)

// Standard HTTP requests resolve through the default base URL
let (responseCode, timeline) = try await client.app.bsky.feed.getTimeline(
    input: AppBskyFeedGetTimeline.Parameters(limit: 25)
)
```

## Route specific namespaces

To divert specific lexicon namespaces to dedicated backend hosts, inspect the `endpoint` parameter in `resolveConnectionURL(_:endpoint:)`:

```swift
import Foundation
import Petrel

public final class NamespaceRoutingAdapter: ConnectionPolicyAdapter, Sendable {
    private let chatServiceHost: String

    public init(chatServiceHost: String) {
        self.chatServiceHost = chatServiceHost
    }

    public func resolveConnectionURL(_ url: URL, endpoint: String?) async -> URL {
        // Route chat.bsky.* endpoints to a dedicated chat host
        if let endpoint, endpoint.hasPrefix("chat.bsky.") {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            components?.host = chatServiceHost
            return components?.url ?? url
        }

        return url
    }
}
```

If your application uses private overlay lexicons (such as proprietary service extensions like `blue.catbird.mls.*` that are not part of standard AT Protocol lexicon distributions), you can use this same pattern to direct those calls to your private infrastructure:

```swift
public func resolveConnectionURL(_ url: URL, endpoint: String?) async -> URL {
    // Route private overlay lexicon endpoints to custom infrastructure
    if let endpoint, endpoint.hasPrefix("blue.catbird.mls.") {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.host = "mls.example.internal"
        return components?.url ?? url
    }

    return url
}
```

## Remove the adapter

To restore default connection resolution, pass `nil` to `setConnectionPolicyAdapter(_:)`:

```swift
await client.setConnectionPolicyAdapter(nil)
```

## Runtime behavior

1. The adapter is invoked for every outgoing HTTP request and WebSocket connection before network dispatch.
2. The adapter receives the initial target `URL` and the lexicon method name as `endpoint` (e.g. `"com.atproto.sync.subscribeRepos"` or `"app.bsky.feed.getTimeline"`).
3. If the adapter returns an unchanged `URL`, Petrel connects to the original target. If the adapter returns a modified `URL`, Petrel dispatches the network connection to the new destination.
4. Authentication headers, DPoP proofs, and proxy headers continue to be constructed and applied to the request after destination resolution.
