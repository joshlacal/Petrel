# Run your own authorization server

Embed an AT Protocol OAuth authorization server in a Swift service, and protect that service's routes with the tokens it issues.

## Overview

A PDS has two OAuth jobs. As an *authorization server* it authenticates the account holder, shows what an application is asking for, and issues tokens. As a *resource server* it checks those tokens on every API request. This guide wires up both.

The code below is compiled and run by `DocumentationExampleTests` in the package's test suite.

### 1. Connect your accounts

The server owns the OAuth protocol and nothing about accounts. Tell it how to check a password and how to look an account up by DID:

```swift
struct MyAccounts: OAuthAccountAuthenticating {
    func signIn(identifier: String, password: String, context: OAuthSignInContext) async throws -> OAuthSignInResult {
        guard identifier == "alice.example.com", password == "correct horse" else { return .rejected }
        return .authenticated(OAuthAccount(did: "did:plc:alice", handle: "alice.example.com"))
    }

    func account(did: String) async throws -> OAuthAccount? {
        did == "did:plc:alice" ? OAuthAccount(did: did, handle: "alice.example.com") : nil
    }
}
```

`account(did:)` is consulted before every code and token is issued, so returning `nil` for a deactivated account stops its sessions from refreshing. To require a second factor, return `.secondFactorRequired` from `signIn` and implement `verifySecondFactor`.

### 2. Create the server

```swift
let store = InMemoryOAuthStore()
// A transport that pins each connection to the approved DNS answers,
// such as PinnedNIOOAuthRemoteTransport from PetrelOAuthServerHummingbird.
let transport: any OAuthRemoteTransport = PinnedNIOOAuthRemoteTransport()
let server = try OAuthAuthorizationServer(
    configuration: OAuthAuthorizationServerConfiguration(
        issuer: URL(string: "https://pds.example.com")!,
        serverSecret: secret // 32 random bytes from your secret store
    ),
    store: store,
    accounts: MyAccounts(),
    clients: OAuthClientMetadataLoader(
        fetcher: OAuthRemoteDocumentFetcher(policy: OAuthRemoteFetchPolicy(), transport: transport),
        cache: store
    )
)
```

The issuer is the origin clients reach the server at. Every endpoint URL, the `iss` response parameter and every DPoP check is derived from it, never from request headers, so the server behaves the same behind a reverse proxy.

Client metadata documents are fetched from URLs that clients choose, so the transport must connect only to the addresses the fetcher has checked are public. A transport that resolves the host name again itself can be steered to your internal network by a host whose DNS answers change between the check and the connection (DNS rebinding). ``OAuthRemoteDocumentFetcher`` therefore refuses a transport whose ``OAuthRemoteTransport/pinsConnectionsToApprovedPeers`` is false. `URLSession` cannot pin, so ``URLSessionOAuthRemoteTransport`` is usable only with ``OAuthRemoteFetchPolicy/allowsUnpinnedTransport``, and only where outbound traffic is already confined to the public internet.

``InMemoryOAuthStore`` loses sessions on restart. For production, implement the store protocols behind ``OAuthServerStore`` on your database; each method documents the transaction it must be.

### 3. Route requests to it

The server is framework-agnostic. Register ``OAuthAuthorizationServer/routes`` with your framework and forward each request:

```swift
let response = await server.handle(
    OAuthHTTPRequest(method: "GET", path: "/.well-known/oauth-authorization-server")
)
```

With Hummingbird, the `PetrelOAuthServerHummingbird` target in the repository's `Server/` package does this in one call:

```swift
OAuthServerHummingbird.addRoutes(to: router, server: server)
```

### 4. Protect your API

Create a verifier that shares the server's stores, authenticate each request, then check the scope the request needs:

```swift
let verifier = OAuthResourceServerVerifier(authorizationServer: server)

do {
    let grant = try await verifier.authenticate(method: "POST", url: requestURL, headers: requestHeaders)
    try grant.requireRepo(collection: "app.bsky.feed.post", action: .create)
    // grant.subject is the account DID. Serve the request.
} catch {
    return verifier.challenge(for: error) // 401 or 403 with WWW-Authenticate: DPoP and a fresh nonce
}
```

Send `verifier.currentNonce()` in a `DPoP-Nonce` header on successful responses too, so clients always hold a current nonce.

A resource server deployed apart from the authorization server uses signed access tokens instead: configure the server with `accessTokenFormat: .signedJWT(key)`, and build the verifier from the keys published at `/oauth/jwks`.

### 5. Try it

The repository ships a runnable example with one demo account:

```
cd Server
swift run petrel-oauth-server-example --port 8787
```

It accepts any `http://localhost` development client, which is how the profile lets applications under development sign in without publishing a metadata document.

## Going further

- **Your own pages.** Implement ``OAuthInterfaceRendering`` to replace the built-in sign-in and consent pages. The server keeps control of the flow, the form targets and the security headers.
- **Permission sets.** Pass a ``OAuthLexiconResolving`` (wrapped in ``CachingOAuthLexiconResolver``) to accept `include:` scopes. Without one, a request that names a permission set is refused with `invalid_scope`.
- **Trusted clients.** A client's self-declared name and logo are shown only for the `client_id` values in ``OAuthAuthorizationServerConfiguration/trustedClientIDs``.
- **Session management.** ``OAuthAuthorizationServer`` lists and revokes an account's sessions, for a "connected applications" page.
