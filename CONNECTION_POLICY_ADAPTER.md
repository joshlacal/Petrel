# Connection Policy Adapter

The Connection Policy Adapter allows client applications to control how the Petrel library resolves URLs for network connections. This is particularly useful for scenarios like:

- Bypassing HTTP proxies for WebSocket connections
- Routing specific endpoints to different services
- Supporting custom service endpoints that require direct connections

## Overview

WebSocket connections cannot be proxied using standard HTTP proxy mechanisms in the AT Protocol. If your application uses a proxy for regular HTTP requests but needs direct WebSocket connections (e.g., for firehose subscriptions or custom MLS endpoints), you can implement a `ConnectionPolicyAdapter` to control this routing.

## Usage

### 1. Implement the ConnectionPolicyAdapter Protocol

```swift
import Petrel

class WebSocketProxyBypass: ConnectionPolicyAdapter {
    private let directServiceURL: URL
    private let proxyServiceURL: URL
    
    init(directServiceURL: URL, proxyServiceURL: URL) {
        self.directServiceURL = directServiceURL
        self.proxyServiceURL = proxyServiceURL
    }
    
    func resolveConnectionURL(_ url: URL, endpoint: String?) async -> URL {
        // Bypass proxy for WebSocket connections
        if url.scheme == "wss" || url.scheme == "ws" {
            return convertToDirectURL(url)
        }
        
        // Bypass proxy for specific custom endpoints
        if let endpoint = endpoint, endpoint.hasPrefix("blue.catbird.mls") {
            return convertToDirectURL(url)
        }
        
        // Use proxy for all other HTTP requests
        return url
    }
    
    private func convertToDirectURL(_ url: URL) -> URL {
        // Replace the proxied host with the direct service host
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.host = directServiceURL.host
        components?.port = directServiceURL.port
        return components?.url ?? url
    }
}
```

### 2. Set the Adapter on Your Client

```swift
// Create your client
let client = ATProtoClient(pdsURL: yourPDSURL)

// Create and set your connection policy adapter
let adapter = WebSocketProxyBypass(
    directServiceURL: URL(string: "https://direct-service.example.com")!,
    proxyServiceURL: URL(string: "https://proxy.example.com")!
)

await client.networkService.setConnectionPolicyAdapter(adapter)
```

### 3. Use Your Client Normally

Once configured, the adapter will automatically be consulted for all network connections:

```swift
// WebSocket connections will use the direct URL
let firehoseStream = try await client.com.atproto.sync.subscribeRepos(
    parameters: SubscribeReposParameters()
)

// Regular HTTP requests will go through the proxy (or whatever your adapter decides)
let timeline = try await client.app.bsky.feed.getTimeline(
    parameters: GetTimelineParameters()
)
```

## Common Patterns

### Firehose Subscriptions (No Auth Required)

The firehose doesn't require authentication and is a WebSocket connection. Bypass any proxy:

```swift
func resolveConnectionURL(_ url: URL, endpoint: String?) async -> URL {
    if endpoint == "com.atproto.sync.subscribeRepos" {
        return directFirehoseURL(from: url)
    }
    return url
}
```

### Custom Service Endpoints

Route specific namespace prefixes to dedicated services:

```swift
func resolveConnectionURL(_ url: URL, endpoint: String?) async -> URL {
    // Route blue.catbird.mls.* endpoints to dedicated MLS service
    if let endpoint = endpoint, endpoint.hasPrefix("blue.catbird.mls") {
        return mlsServiceURL(from: url)
    }
    
    // Route chat.bsky.* endpoints to chat service
    if let endpoint = endpoint, endpoint.hasPrefix("chat.bsky") {
        return chatServiceURL(from: url)
    }
    
    return url
}
```

### Development/Testing Environments

Route requests differently based on environment:

```swift
class EnvironmentBasedAdapter: ConnectionPolicyAdapter {
    let isProduction: Bool
    
    func resolveConnectionURL(_ url: URL, endpoint: String?) async -> URL {
        if isProduction {
            return productionURL(from: url)
        } else {
            return stagingURL(from: url)
        }
    }
}
```

## Removing the Adapter

To remove the adapter and return to default behavior:

```swift
await client.networkService.setConnectionPolicyAdapter(nil)
```

## Notes

- The adapter is called for **both HTTP and WebSocket connections**
- The adapter receives the original URL and the endpoint name (e.g., "com.atproto.sync.subscribeRepos")
- Return the same URL to use default behavior, or return a modified URL to change the connection destination
- The adapter is `async` to allow for dynamic lookups if needed
- Security validation still applies after URL resolution
