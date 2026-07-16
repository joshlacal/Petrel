# Authentication

Learn how to authenticate with the AT Protocol using OAuth or legacy authentication methods.

## OAuth Authentication (Recommended)

OAuth is the preferred authentication method for production applications:

<!-- compile-example: oauth-authentication -->
```swift
import Foundation
import Petrel

func authenticateExample(callbackURL: URL) async throws {
    let oauth = OAuthConfig(
        clientId: "https://yourapp.example.com/oauth-client-metadata.json",
        redirectUri: "com.example.yourapp:/oauth/callback",
        scope: "atproto transition:generic"
    )
    let client = try await ATProtoClient(
        oauthConfig: oauth,
        namespace: "com.example.yourapp"
    )

    let authURL = try await client.startOAuthFlow(identifier: "alice.bsky.social")
    print("Open this URL: \(authURL)")

    // Present authURL, receive callbackURL in your app, then continue the flow.
    try await client.handleOAuthCallback(url: callbackURL)
}
```

## Legacy Authentication

Petrel still exposes legacy password authentication through the public
``AuthMode/legacy`` mode and `loginWithPassword`. This compatibility path is
intended for Bluesky app passwords, never a primary account password. Prefer
OAuth for new production applications.

## Token Management

Petrel automatically handles token refresh using the `TokenRefreshCoordinator`. Tokens are securely stored in the keychain and refreshed as needed.

## Handling OAuth Callback in your App

On iOS, forward the redirect URI to the client from your app delegate or SwiftUI scene handler:

<!-- compile-example: oauth-callback -->
```swift
import Foundation
import Petrel

func handleOAuthCallbackExample(url: URL, client: ATProtoClient) {
    Task {
        do {
            try await client.handleOAuthCallback(url: url)
        } catch {
            print("OAuth callback failed: \(error)")
        }
    }
}
```

Call this helper from the corresponding iOS scene or application delegate, or from the macOS application delegate.

## Next Steps

- Return to <doc:GettingStarted> to make API calls with ``ATProtoClient``.
