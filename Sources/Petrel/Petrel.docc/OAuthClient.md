# OAuth Client, Permissions and Account Status

Sign users in with atproto OAuth, ask for exactly the permissions you need, and find out when an account is deactivated, suspended or taken down.

## Overview

Petrel implements the client side of the [atproto OAuth profile](https://atproto.com/specs/oauth): identity-first and server-first login, pushed authorization requests (PAR), PKCE, per-session DPoP keys with server nonces, verified token responses, single-use refresh tokens and revocation. It also models [permission scopes](https://atproto.com/specs/permission) as types, and reports [account hosting status](https://atproto.com/specs/account) as typed values and errors.

### Publish client metadata

An atproto OAuth client is identified by the `https` URL of a JSON document it publishes. ``OAuthConfig`` can check a configuration against the profile's rules and build that document for you:

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

A native app's custom redirect scheme must be the client ID's hostname in reverse-domain order, followed by `:/` and a path. During development you can skip publishing anything by using the profile's localhost exception:

<!-- compile-example: oauth-client-loopback -->
```swift
import Petrel

func loopbackConfigExample() -> OAuthConfig {
    let config = OAuthConfig.loopback(port: 8765, scope: "atproto transition:generic")
    // config.redirectUri == "http://127.0.0.1:8765/callback"
    return config
}
```

### Sign in with a handle or DID

<!-- compile-example: oauth-client-handle-login -->
```swift
import Foundation
import Petrel

func signInWithHandle(config: OAuthConfig, redirectURL: URL) async throws {
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

Starting the flow resolves the handle to a DID (verifying the handle both ways), reads the PDS from the DID document, and follows the PDS's protected-resource metadata to its authorization server. The callback is accepted only if it carries the `state` of a flow this client started, arrives at the configured redirect URI, and names the same issuer; the token response is accepted only if it is DPoP-bound, includes the `atproto` scope, and its `sub` is the DID the flow was started for. Tokens that fail a check are revoked, not stored.

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

Build scopes from types instead of strings. `ATProtoScope` and `ATProtoScopeSet` come from the `PetrelOAuthScopes` module, which Petrel re-exports; it is the same grammar Petrel's OAuth server uses, and it is held to the reference implementation's accept-or-reject decisions and canonical forms. `ATProtoScope` parses and formats every scope the permission specification defines, and rejects invalid ones:

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

Implement ``OAuthClientAssertionSigner`` yourself to keep the key in a KMS or HSM. An app whose key lives on a backend it talks to uses `AuthMode.cab(backendURL:)` instead.

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
