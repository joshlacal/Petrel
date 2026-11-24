# Signing In

Sign users in with atproto OAuth, request only the permissions you need, sign in bots with app passwords, and handle deactivated, suspended and taken-down accounts.

## Overview

Petrel implements the client side of the [atproto OAuth profile](https://atproto.com/specs/oauth): pushed authorization requests (PAR), PKCE, per-session DPoP keys with server nonces, verified token responses, single-use refresh tokens and revocation. It models [permission scopes](https://atproto.com/specs/permission) as types and reports [account hosting status](https://atproto.com/specs/account) as typed values and errors.

A sign-in has three steps: start a flow to get an authorization URL, show that URL in a browser, and pass the redirect back to the client.

<!-- compile-example: oauth-authentication -->
```swift
import Foundation
import Petrel

func signIn(redirectURL: URL) async throws {
    let config = OAuthConfig(
        clientId: "https://app.example.com/oauth-client-metadata.json",
        redirectUri: "com.example.app:/callback",
        scope: "atproto transition:generic"
    )
    let client = try await ATProtoClient(oauthConfig: config, namespace: "com.example.app")

    // 1. Start the flow and open the URL in a browser.
    let authorizationURL = try await client.startOAuthFlow(identifier: "alice.example.com")
    _ = authorizationURL

    // 2. The user approves; your app receives the redirect.
    try await client.handleOAuthCallback(url: redirectURL)

    // 3. Authenticated requests are DPoP-signed and refreshed automatically.
    let (_, session) = try await client.com.atproto.server.getSession()
    _ = session
}
```

Starting the flow resolves the handle to a DID (verifying the handle both ways), reads the PDS from the DID document, and follows the PDS's protected-resource metadata to its authorization server. The callback is accepted only if it carries the `state` of a flow this client started, arrives at the configured redirect URI, and names the same issuer. The token response is accepted only if it is DPoP-bound, includes the `atproto` scope, and its `sub` is the DID the flow was started for. Tokens that fail a check are revoked, not stored.

### Publish client metadata

An atproto OAuth client is identified by the `https` URL of a JSON document it publishes. ``OAuthConfig`` checks a configuration against the profile's rules and builds that document:

<!-- compile-example: oauth-client-metadata -->
```swift
import Foundation
import Petrel

func generateClientMetadataJSON() throws -> Data {
    let config = OAuthConfig(
        clientId: "https://app.example.com/oauth-client-metadata.json",
        redirectUri: "com.example.app:/callback",
        scope: "atproto transition:generic"
    )
    try config.validate()

    let metadata = try config.clientMetadataDocument(applicationType: .native, clientName: "Example")
    let json = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
    // Serve `json` at the client ID URL with HTTP 200 and Content-Type: application/json.
    return json
}
```

A native app's custom redirect scheme must be the client ID's hostname in reverse-domain order, followed by `:/` and a path. Register that scheme in your app (`CFBundleURLTypes` in `Info.plist` on Apple platforms).

During development you can skip publishing: ``OAuthConfig/loopback(port:path:scope:)`` uses the profile's localhost exception. See <doc:GettingStarted>.

### Show the authorization URL

In SwiftUI, use `@Environment(\.webAuthenticationSession)` as <doc:GettingStarted> does. In UIKit or AppKit, or when you need the session's other options, wrap `ASWebAuthenticationSession`:

<!-- compile-example: oauth-aswebauth-session -->
```swift
import AuthenticationServices
import Foundation
import Petrel

@MainActor
final class NativeOAuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let anchor: ASPresentationAnchor

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }

    func signIn(client: ATProtoClient, identifier: String, callbackScheme: String) async throws {
        let authURL = try await client.startOAuthFlow(identifier: identifier)
        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callback: .customScheme(callbackScheme)
            ) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: AuthError.invalidCallbackURL)
                }
            }
            session.presentationContextProvider = self
            session.start()
        }
        try await client.handleOAuthCallback(url: callbackURL)
    }
}
```

If the redirect reaches your app another way, such as `onOpenURL` or an app delegate, forward it to ``ATProtoClient/handleOAuthCallback(url:)``:

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

### Sign in from a hosting provider

When the user knows their provider but not their handle, or is creating an account, start from the provider's PDS or entryway URL instead:

<!-- compile-example: oauth-client-server-login -->
```swift
import Foundation
import Petrel

func startProviderLogin(client: ATProtoClient) async throws -> URL {
    try await client.startOAuthFlow(server: URL(string: "https://bsky.social")!)
}
```

No account is bound to such a flow in advance, so after the token exchange Petrel resolves the returned account's DID document and requires that account's own PDS to name the authorization server that issued the tokens.

### What Petrel checks about servers

Before anything is sent to an authorization server, its metadata is fetched (HTTP 200 only, no redirects, `application/json` only) and validated. A server is refused with ``OAuthMetadataError`` when:

- its `issuer` is not the origin its metadata was fetched from, or is not a plain `https` origin;
- an endpoint is not an `https` URL;
- it does not declare PKCE `S256`, DPoP `ES256`, the `atproto` scope, the `code` response type, the `authorization_code` and `refresh_token` grants, or the client-authentication method this client uses;
- it does not require pushed authorization requests, does not return the `iss` callback parameter, or does not support client ID metadata documents;
- the PDS's protected-resource metadata does not name exactly one authorization server, or names a different `resource` than the PDS itself.

### Ask for permissions

Build scopes from types instead of strings. `ATProtoScope` and `ATProtoScopeSet` come from the `PetrelOAuthScopes` module, which Petrel re-exports. `ATProtoScope` parses and formats every scope the permission specification defines, and rejects invalid ones:

<!-- compile-example: oauth-client-typed-scopes -->
```swift
import Petrel

func buildScopedConfig() throws -> OAuthConfig {
    let scopes = try ATProtoScopeSet([
        .atproto,
        .repo(collections: ["app.bsky.feed.post"], actions: [.create]),
        .rpc(lxm: ["app.bsky.feed.getTimeline"], aud: "did:web:api.bsky.app#bsky_appview"),
    ])
    return OAuthConfig(
        clientId: "https://app.example.com/oauth-client-metadata.json",
        redirectUri: "com.example.app:/callback",
        scopes: scopes
    )
}
```

The user may grant less than you asked for. Check what the session actually holds:

<!-- compile-example: oauth-client-granted-scopes -->
```swift
import Petrel

func canCreatePosts(client: ATProtoClient) async -> Bool {
    let granted = await client.grantedScopes()
    return granted.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create))
}
```

To ask for more later, send the signed-in account through the flow again. The current session keeps working until the new one replaces it:

<!-- compile-example: oauth-client-upgrade-scopes -->
```swift
import Foundation
import Petrel

func requestAdditionalScopes(client: ATProtoClient) async throws -> URL {
    let wanted = try ATProtoScopeSet([
        .atproto,
        .repo(collections: ["app.bsky.feed.post"], actions: [.create]),
    ])
    // Open upgradeURL, then pass the redirect to handleOAuthCallback(url:)
    return try await client.requestScopes(wanted)
}
```

Permission sets are requested with `include:` scopes. `IncludeScope.expand(_:)` shows what a published permission set would grant, and `expansion(of:)` also says why an entry was ignored.

### Confidential clients

A server-side app that holds its own client-authentication key signs `private_key_jwt` assertions in process. Publish the key's public half in the client metadata and install the signer before starting a flow:

<!-- compile-example: oauth-client-confidential -->
```swift
import Petrel

func configureConfidentialClient(
    config: OAuthConfig,
    client: ATProtoClient
) async throws -> [String: Any] {
    let key = try OAuthClientAssertionKey.generate(keyID: "key-1")
    let metadata = try config.clientMetadataDocument(
        applicationType: .web,
        confidentialKeys: [key]
    )

    try await client.useClientAssertionSigner(key)
    return metadata
}
```

Implement ``OAuthClientAssertionSigner`` yourself to keep the key in a KMS or HSM.

### Other authentication modes

``AuthMode`` selects how a client authenticates. The XRPC call sites are the same in every mode.

| Mode | Keys live | Use it for |
| :--- | :--- | :--- |
| `.none` (`ATProtoClient(baseURL:)`) | nowhere | Public queries, such as `https://public.api.bsky.app` |
| `.publicOAuth` (default) | DPoP key in the client's secure storage | Native apps that talk to the user's PDS directly |
| `.cab(backendURL:)` | DPoP key on the device, client-assertion key on your backend | Confidential clients that still talk to the PDS directly |
| `.gateway(_:)` | on your backend | Apps that send every request through a confidential OAuth gateway, configured with ``GatewayConfiguration`` |
| `.legacy` | session tokens in the client's secure storage | App-password sign-in |

### Sign in with an app password

`loginWithPassword` creates a legacy session for scripts, bots and servers that do not offer OAuth. Create the client with ``AuthMode/legacy`` and pass an app password, never the account's main password. Prefer OAuth for anything a person signs in to interactively.

<!-- compile-example: oauth-legacy-password -->
```swift
import Petrel

func signInWithAppPassword(identifier: String, appPassword: String) async throws -> ATProtoClient {
    let client = try await ATProtoClient(
        oauthConfig: OAuthConfig.loopback(port: 8765),
        namespace: "com.example.cli",
        authMode: .legacy
    )
    _ = try await client.loginWithPassword(identifier: identifier, password: appPassword)
    return client
}
```

### Tokens and storage

Petrel refreshes access tokens before they expire and when a server rejects one as expired. Refresh tokens are single-use, so concurrent calls share one refresh. Tokens and DPoP keys are stored under the client's `namespace`: in the keychain on Apple platforms, and in libsecret or an encrypted file on Linux. ``CredentialStorageConfiguration`` selects the storage for one client.

### Sign out

<!-- compile-example: oauth-client-logout -->
```swift
import Petrel

func signOutExamples(client: ATProtoClient, otherDID: String) async throws {
    try await client.logout()                     // revokes the session, then deletes it locally
    try await client.removeAccount(did: otherDID) // the same, for any stored account
}
```

Both revoke the session at the authorization server before removing local state, and still complete locally when the server cannot be reached.

### Account status

A deactivated account can still hold a session, so that it can be reactivated. Ask the PDS:

<!-- compile-example: oauth-client-account-status -->
```swift
import Petrel

func checkDeactivatedAccount(client: ATProtoClient) async throws -> Bool {
    let status = try await client.fetchAccountStatus()
    return !status.isActive && status.reason == .deactivated
}
```

When a server refuses a request because the account is taken down, suspended or deactivated, the request throws ``AccountStatusError`` rather than an authentication error, and the session is left in place:

<!-- compile-example: oauth-client-account-status-error -->
```swift
import Petrel

func inspectSessionWithStatusError(client: ATProtoClient) async throws {
    do {
        _ = try await client.com.atproto.server.getSession()
    } catch let error as AccountStatusError {
        // error.status.reason is .takendown, .suspended or .deactivated
        print("Account status reason: \(String(describing: error.status.reason))")
    }
}
```

``AccountStatus`` keeps the `active` flag and the status string separate, and preserves status strings it does not recognise, because the specification allows new ones to be added.

## Topics

### Configuration

- ``OAuthConfig``
- ``OAuthConfigurationError``
- ``OAuthMetadataError``

### Confidential clients

- ``OAuthClientAssertionSigner``
- ``OAuthClientAssertionKey``
- ``OAuthClientAssertionError``

### Account status

- ``AccountStatus``
- ``AccountStatusError``
- ``AuthFactorTokenRequiredError``
