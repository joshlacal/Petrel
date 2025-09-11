# Authentication

Learn how to authenticate with the AT Protocol using OAuth or legacy authentication methods.

## OAuth Authentication (Recommended)

OAuth is the preferred authentication method for production applications:

```swift
let oauth = OAuthConfig(
    clientId: "YOUR_CLIENT_ID",
    redirectUri: "yourapp://oauth/callback",
    scope: "atproto app:bsky"
)
let client = await ATProtoClient(oauthConfig: oauth, namespace: "com.example.yourapp")

// Start OAuth flow
let authURL = try await client.startOAuthFlow(identifier: "alice.bsky.social")

// Present authURL, receive callbackURL in your app
try await client.handleOAuthCallback(url: callbackURL)
```

## Legacy Authentication

Password-based flows are deprecated and not exposed by the public API. Use OAuth for production.

## Token Management

Petrel automatically handles token refresh using the `TokenRefreshCoordinator`. Tokens are securely stored in the keychain and refreshed as needed.

## Handling OAuth Callback in your App

On iOS, forward the redirect URI to the client from your app delegate or SwiftUI scene handler:

```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    Task { try? await client.handleOAuthCallback(url: url) }
    return true
}
```

On macOS, use the corresponding NSApplicationDelegate method to pass the URL to `client.handleOAuthCallback(url:)`.

## Next Steps

- Explore <doc:BasicUsage> to start making API calls
- Learn about <doc:TokenManagement> for advanced authentication scenarios
- Review <doc:OAuthFlow> for detailed OAuth implementation
