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

The `ConnectionPolicyAdapter` protocol is `Sendable` and requires one method, `resolveConnectionURL(_:endpoint:)`. It receives the URL Petrel is about to connect to and the lexicon method name, and returns the URL to connect to instead:

<!-- compile-example: connection-policy-websocket-bypass -->
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

Create an adapter, such as `WebSocketProxyBypassAdapter(directStreamingHost: "bsky.network")` from the previous section, and set it on `ATProtoClient` with `setConnectionPolicyAdapter(_:)`:

<!-- compile-example: connection-policy-configure -->
```swift
import Foundation
import Petrel

func makeStreamingClient(adapter: any ConnectionPolicyAdapter) async -> ATProtoClient {
    let client = await ATProtoClient(
        baseURL: URL(string: "https://bsky.social")!
    )
    await client.setConnectionPolicyAdapter(adapter)
    return client
}
```

For authenticated clients initialized with OAuth, set the adapter after client initialization:

<!-- compile-example: connection-policy-configure-oauth -->
```swift
import Foundation
import Petrel

func makeAuthenticatedClient(adapter: any ConnectionPolicyAdapter) async throws -> ATProtoClient {
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
    await client.setConnectionPolicyAdapter(adapter)
    return client
}
```

Once configured, the adapter is consulted for both standard queries and streaming subscriptions. With `WebSocketProxyBypassAdapter`, only the subscription changes host:

<!-- compile-example: connection-policy-usage -->
```swift
import Foundation
import Petrel

func loadTimelineThenFollowFirehose(client: ATProtoClient) async throws {
    // An HTTP request: the adapter returns the URL unchanged, so it goes to the base URL.
    let (_, timeline) = try await client.app.bsky.feed.getTimeline(
        input: .init(limit: 25)
    )
    _ = timeline?.feed

    // A WebSocket subscription: the adapter rewrites the host to directStreamingHost.
    for try await message in try await client.com.atproto.sync.subscribeRepos(cursor: nil) {
        if case let .commit(commit) = message {
            _ = commit.ops
        }
    }
}
```

## Route specific namespaces

To divert specific lexicon namespaces to dedicated backend hosts, inspect the `endpoint` parameter in `resolveConnectionURL(_:endpoint:)`:

<!-- compile-example: connection-policy-namespace-routing -->
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

If your application uses private overlay lexicons (namespaces such as `com.example.private.*` that are served by your own infrastructure rather than the account's PDS), you can use this same pattern to direct those calls to your private infrastructure:

<!-- compile-example: connection-policy-private-overlay -->
```swift
import Foundation
import Petrel

public struct PrivateOverlayRoutingAdapter: ConnectionPolicyAdapter {
    public init() {}

    public func resolveConnectionURL(_ url: URL, endpoint: String?) async -> URL {
        // Route private overlay lexicon endpoints to custom infrastructure
        if let endpoint, endpoint.hasPrefix("com.example.private.") {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            components?.host = "private-api.example.com"
            return components?.url ?? url
        }

        return url
    }
}
```

## Remove the adapter

To restore default connection resolution, pass `nil` to `setConnectionPolicyAdapter(_:)`:

<!-- compile-example: connection-policy-remove -->
```swift
import Petrel

func restoreDefaultRouting(client: ATProtoClient) async {
    await client.setConnectionPolicyAdapter(nil)
}
```

## Runtime behavior

1. The adapter is invoked for every outgoing HTTP request and WebSocket connection before network dispatch.
2. The adapter receives the initial target `URL` and the lexicon method name as `endpoint` (e.g. `"com.atproto.sync.subscribeRepos"` or `"app.bsky.feed.getTimeline"`).
3. If the adapter returns an unchanged `URL`, Petrel connects to the original target. If the adapter returns a modified `URL`, Petrel dispatches the network connection to the new destination.
4. Authentication headers, DPoP proofs, and proxy headers continue to be constructed and applied to the request after destination resolution.
