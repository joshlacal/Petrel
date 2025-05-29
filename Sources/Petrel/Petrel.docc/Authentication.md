# Authentication

Learn how to authenticate with the AT Protocol using OAuth or legacy authentication methods.

## OAuth Authentication (Recommended)

OAuth is the preferred authentication method for production applications:

```swift
let authService = AuthenticationService()

// Start OAuth flow
let authURL = try await authService.startOAuthAuthentication(
    identifier: "alice.bsky.social"
)

// Open authURL in browser/web view
// Handle the callback URL after user authorizes

// Complete authentication
let account = try await authService.handleOAuthCallback(
    callbackURL: callbackURL
)

// Create authenticated client
let client = ATProtoClient(authenticationService: authService)
```

## Legacy Authentication

For development or testing purposes, you can use password-based authentication:

```swift
let authService = AuthenticationService()

let account = try await authService.authenticateWithPassword(
    identifier: "alice.bsky.social",
    password: "your-app-password"
)

let client = ATProtoClient(authenticationService: authService)
```

> Important: Always use app passwords, not your main account password.

## Token Management

Petrel automatically handles token refresh using the `TokenRefreshCoordinator`. Tokens are securely stored in the keychain and refreshed as needed.

## Next Steps

- Explore <doc:BasicUsage> to start making API calls
- Learn about <doc:TokenManagement> for advanced authentication scenarios
- Review <doc:OAuthFlow> for detailed OAuth implementation