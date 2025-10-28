# Legacy Authentication (App Password) Support

Petrel now supports both OAuth and legacy password-based authentication methods.

## Overview

Petrel supports two authentication methods:

1. **OAuth** (recommended): Modern, secure authentication using OAuth 2.0 with DPoP
2. **Legacy/Password Authentication**: Traditional username/password authentication using app passwords

## Using Legacy Authentication (App Passwords)

### Example

```swift
import Petrel

// Initialize the client
let client = await ATProtoClient(
    baseURL: URL(string: "https://bsky.social")!,
    oauthConfig: yourOAuthConfig,  // Still required for the client initialization
    namespace: "your.app.namespace"
)

// Authenticate with app password
do {
    try await client.loginWithPassword(
        identifier: "user.bsky.social",  // Your handle or email
        password: "your-app-password-here"  // Use an app password, not your main password!
    )
    
    // After successful login, you can use the client normally
    let did = try await client.getDid()
    print("Logged in as: \(did)")
    
} catch {
    print("Login failed: \(error)")
}
```

### Important Security Notes

1. **Always use App Passwords**: Never use your main account password. Generate app passwords from your account settings.
2. **Token Storage**: Access and refresh tokens are stored securely in the Keychain.
3. **Token Refresh**: Legacy sessions automatically refresh using `com.atproto.server.refreshSession`.
4. **Token Type**: Legacy sessions use Bearer tokens (not DPoP like OAuth).

## Differences Between OAuth and Legacy Auth

| Feature | OAuth | Legacy/Password |
|---------|-------|-----------------|
| Security | High (DPoP tokens) | Medium (Bearer tokens) |
| Setup | Requires OAuth callback | Simple username/password |
| Token Type | DPoP | Bearer |
| Refresh Method | OAuth token refresh | com.atproto.server.refreshSession |
| Recommended For | Production apps | Testing, scripts, personal use |

## When to Use Each Method

### Use OAuth When:
- Building production applications
- You need the highest security
- Your app supports web-based authentication flows
- You're deploying to app stores

### Use Legacy Auth When:
- Building CLI tools or scripts
- Quick testing and development
- Personal automation tools
- The OAuth callback flow is impractical

## Implementation Details

### Legacy Authentication Flow

1. Resolve handle to DID and PDS URL
2. Call `com.atproto.server.createSession` with credentials
3. Store access and refresh JWT tokens
4. Create account and session in local storage
5. Set Bearer token for subsequent requests

### Token Refresh

Legacy sessions automatically refresh their tokens when they expire using the `com.atproto.server.refreshSession` endpoint. This happens transparently when you make API calls.

### Code Organization

- **Login**: `ATProtoClient.loginWithPassword()`
- **Session Creation**: `ComAtprotoServerCreateSession`
- **Token Refresh**: `ComAtprotoServerRefreshSession`
- **Authentication Headers**: Bearer tokens are automatically added to requests

## Migration from OAuth to Legacy Auth

If you have an existing OAuth-authenticated session, you can switch to legacy auth by:

1. Logging out of the current session: `await client.logout()`
2. Logging in with password: `await client.loginWithPassword(...)`

## Migration from Legacy Auth to OAuth

To upgrade from legacy auth to OAuth:

1. Log out: `await client.logout()`
2. Start OAuth flow: `let url = try await client.startOAuthFlow(identifier: "user.bsky.social")`
3. Complete OAuth callback: `try await client.handleOAuthCallback(url: callbackURL)`

## Example: CLI Tool

```swift
import Foundation
import Petrel

@main
struct MyCLITool {
    static func main() async {
        let client = await ATProtoClient(
            baseURL: URL(string: "https://bsky.social")!,
            oauthConfig: OAuthConfig(
                clientId: "http://localhost",
                redirectUri: "http://localhost/callback"
            ),
            namespace: "com.example.mycli"
        )
        
        print("Enter your handle:")
        guard let handle = readLine() else { return }
        
        print("Enter your app password:")
        guard let password = readLine() else { return }
        
        do {
            try await client.loginWithPassword(
                identifier: handle,
                password: password
            )
            
            print("✅ Login successful!")
            
            // Use the client
            let profile = try await client.app.bsky.actor.getProfile(
                actor: handle
            )
            
            print("Display name: \(profile.data?.displayName ?? "N/A")")
            
        } catch {
            print("❌ Login failed: \(error)")
        }
    }
}
```

## Troubleshooting

### "Invalid credentials" error
- Make sure you're using an app password, not your main password
- Verify the handle is correct (e.g., "user.bsky.social" not "@user.bsky.social")
- Check that the app password hasn't been revoked

### Tokens expiring frequently
- Legacy tokens typically expire after 1 hour
- The library automatically refreshes them, but check your network connection
- If refresh fails, you'll need to log in again

### Session not persisting
- Ensure your namespace is unique to your app
- Check Keychain permissions on iOS/macOS
- Verify the app has proper entitlements for Keychain access

## API Reference

### `loginWithPassword(identifier:password:bskyAppViewDID:bskyChatDID:)`

Authenticates using legacy password-based authentication.

**Parameters:**
- `identifier`: User handle (e.g., "user.bsky.social") or email
- `password`: App password (not main account password)
- `bskyAppViewDID`: Optional custom AppView DID (defaults to Bluesky's)
- `bskyChatDID`: Optional custom Chat DID (defaults to Bluesky's)

**Throws:**
- `AuthError.invalidCredentials`: Invalid username or password
- `AuthError.handleNotFound`: Handle doesn't exist
- `AuthError.invalidResponse`: Server returned unexpected response
- `AuthError.networkError`: Network connection failed

**Returns:** Nothing on success. Account information is stored internally.

**Example:**
```swift
try await client.loginWithPassword(
    identifier: "alice.bsky.social",
    password: "abcd-1234-efgh-5678"
)
```
