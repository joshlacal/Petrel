# Run your own authorization server

Embed an AT Protocol OAuth authorization server in a Swift service, and protect that service's routes with the tokens it issues.

## Overview

A PDS has two OAuth jobs. As an *authorization server* it authenticates the account holder, shows what an application is asking for, and issues tokens. As a *resource server* it checks those tokens on every API request. This guide wires up both.

Every Swift snippet on this page is typechecked against the current API by the repository's documentation validator (`Scripts/validate-documentation.sh`). `DocumentationExampleTests` in the package's test suite runs the same server setup, with a stub transport in place of `PinnedNIOOAuthRemoteTransport`.

### 0. Add the packages

`PetrelOAuthServer` itself depends only on `PetrelOAuthScopes`, `PetrelCrypto` and swift-crypto, not on a web framework. `PinnedNIOOAuthRemoteTransport`, the pinned SwiftNIO transport for client-metadata fetches, lives in `PetrelOAuthServerNIO` (package trait `OAuthServerNIO`), while the Hummingbird adapter lives in `PetrelOAuthServerHummingbird` (package trait `OAuthServerHummingbird`, which also enables `OAuthServerNIO` and re-exports `PetrelOAuthServerNIO`). For a Hummingbird server, enable `OAuthServerHummingbird` and add both products:

<!-- compile-example: oauth-server-package-manifest -->
```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MyPDS",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/joshlacal/Petrel.git", from: "2.0.0", traits: ["OAuthServerHummingbird"]),
    ],
    targets: [
        .executableTarget(
            name: "MyPDS",
            dependencies: [
                .product(name: "PetrelOAuthServer", package: "Petrel"),
                .product(name: "PetrelOAuthServerHummingbird", package: "Petrel"),
            ]
        ),
    ]
)
```

Enabling a trait needs `swift-tools-version: 6.1` or later in your own manifest. Without the traits, the `PetrelOAuthServerNIO` and `PetrelOAuthServerHummingbird` modules still exist, but their types are unavailable and say how to enable them. Swift 6.2 and later do not fetch trait-gated dependencies when the traits are off; Swift 6.1 fetches them even then, but builds nothing from them.

If you use another web framework, enable `traits: ["OAuthServerNIO"]` and depend on `PetrelOAuthServer` and `PetrelOAuthServerNIO` to use `PinnedNIOOAuthRemoteTransport` without pulling in Hummingbird (or depend on `PetrelOAuthServer` alone and supply your own pinning ``OAuthRemoteTransport``).

### 1. Connect your accounts

The server owns the OAuth protocol and nothing about accounts. Tell it how to check a password and how to look an account up by DID:

<!-- compile-example: oauth-server-accounts -->
```swift
import PetrelOAuthServer

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

<!-- compile-example: oauth-server-create -->
```swift
import Foundation
import PetrelOAuthServer
import PetrelOAuthServerNIO

func makeServer(secret: Data, accounts: any OAuthAccountAuthenticating) throws -> OAuthAuthorizationServer {
    let store = InMemoryOAuthStore()
    // A transport that pins each connection to the approved DNS answers.
    let transport: any OAuthRemoteTransport = try PinnedNIOOAuthRemoteTransport()
    return try OAuthAuthorizationServer(
        configuration: OAuthAuthorizationServerConfiguration(
            issuer: URL(string: "https://pds.example.com")!,
            serverSecret: secret // 32 random bytes from your secret store
        ),
        store: store,
        accounts: accounts,
        clients: OAuthClientMetadataLoader(
            fetcher: OAuthRemoteDocumentFetcher(policy: OAuthRemoteFetchPolicy(), transport: transport),
            cache: store
        )
    )
}
```

The issuer is the origin clients reach the server at. Every endpoint URL, the `iss` response parameter and every DPoP check is derived from it, never from request headers, so the server behaves the same behind a reverse proxy.

Client metadata documents are fetched from URLs that clients choose, so the transport must connect only to the addresses the fetcher has checked are public. A transport that resolves the host name again itself can be steered to your internal network by a host whose DNS answers change between the check and the connection (DNS rebinding). ``OAuthRemoteDocumentFetcher`` therefore refuses a transport whose ``OAuthRemoteTransport/pinsConnectionsToApprovedPeers`` is false. `PinnedNIOOAuthRemoteTransport` connects to a literal approved address and then checks TLS for the URL's host name. `URLSession` cannot pin, so ``URLSessionOAuthRemoteTransport`` is usable only with ``OAuthRemoteFetchPolicy/allowsUnpinnedTransport``, and only where outbound traffic is already confined to the public internet.

``InMemoryOAuthStore`` loses sessions on restart. For production, implement the store protocols behind ``OAuthServerStore`` on your database; each method documents the transaction it must be.

Expired requests, codes, sessions and single-use markers are purged from the store automatically: ``OAuthAuthorizationServer/handle(_:)`` runs ``OAuthAuthorizationServer/purgeExpiredState()`` at most once per ``OAuthAuthorizationServerConfiguration/expiredStatePurgeInterval`` (five minutes by default). Set the interval to `nil` to run the purge from a scheduled job instead; then you must call `purgeExpiredState()` yourself, or the store grows without bound.

### 3. Route requests to it

The server is framework-agnostic. Register ``OAuthAuthorizationServer/routes`` with your framework and forward each request:

<!-- compile-example: oauth-server-handle -->
```swift
import PetrelOAuthServer

func serveMetadata(server: OAuthAuthorizationServer) async -> OAuthHTTPResponse {
    await server.handle(
        OAuthHTTPRequest(method: "GET", path: "/.well-known/oauth-authorization-server")
    )
}
```

With Hummingbird, `PetrelOAuthServerHummingbird` does this in one call. Use its `OAuthServerRequestContext` so the client's address reaches your account authenticator (for limiting sign-in attempts); Hummingbird's `BasicRequestContext` does not carry it. Behind reverse proxies, pass `clientAddress: .forwardedFor(trustedProxies:)` (an `OAuthClientAddressPolicy`) so `X-Forwarded-For` is read only from the proxies you name:

<!-- compile-example: oauth-server-hummingbird -->
```swift
import Foundation
import Hummingbird
import PetrelOAuthServer
import PetrelOAuthServerHummingbird

func makeRouter(server: OAuthAuthorizationServer, publicOrigin: URL) -> Router<OAuthServerRequestContext> {
    let router = Router(context: OAuthServerRequestContext.self)
    OAuthServerHummingbird.addRoutes(to: router, server: server)

    // A protected route: see step 4.
    let verifier = OAuthResourceServerVerifier(authorizationServer: server)
    router.get("/xrpc/com.atproto.server.getSession") { request, _ -> Response in
        switch await OAuthServerHummingbird.authenticate(request, verifier: verifier, publicOrigin: publicOrigin) {
        case let .failure(challenge):
            return challenge.response
        case let .success(grant):
            return Response(status: .ok, body: ResponseBody(byteBuffer: ByteBuffer(string: grant.subject)))
        }
    }
    return router
}
```

### 4. Protect your API

Create a verifier that shares the server's stores, authenticate each request, then check the scope the request needs:

<!-- compile-example: oauth-server-protect -->
```swift
import Foundation
import PetrelOAuthServer

func createPost(
    verifier: OAuthResourceServerVerifier,
    requestURL: URL,
    requestHeaders: OAuthHTTPHeaders
) async -> OAuthHTTPResponse {
    do {
        let grant = try await verifier.authenticate(method: "POST", url: requestURL, headers: requestHeaders)
        try grant.requireRepo(collection: "app.bsky.feed.post", action: .create)
        // grant.subject is the account DID. Serve the request.
        return OAuthHTTPResponse(status: 200, headers: OAuthHTTPHeaders([("DPoP-Nonce", verifier.currentNonce())]))
    } catch {
        return verifier.challenge(for: error) // 401 or 403 with WWW-Authenticate: DPoP and a fresh nonce
    }
}
```

Build the verifier once with `OAuthResourceServerVerifier(authorizationServer: server)`. Send `verifier.currentNonce()` in a `DPoP-Nonce` header on successful responses too, as above, so clients always hold a current nonce.

A resource server deployed apart from the authorization server uses signed access tokens instead: configure the server with `accessTokenFormat: .signedJWT(key)`, and build the verifier from the keys published at `/oauth/jwks`. Signed access tokens live at most 15 minutes, because a stateless resource server checks only the signature and cannot see a revocation. To rotate the signing key, keep the old public key in ``OAuthAuthorizationServerConfiguration/retiringAccessTokenKeys`` for at least one access-token lifetime: it stays in the JWKS and its tokens keep verifying.

### 5. Try it

The repository ships a runnable example with one demo account, in the separate `Server/` package:

```bash
cd Server
swift run petrel-oauth-server-example --port 8787
```

It accepts any `http://localhost` development client, which is how the profile lets applications under development sign in without publishing a metadata document.

## Going further

- **Your own pages.** Implement ``OAuthInterfaceRendering`` to replace the built-in sign-in and consent pages. The server keeps control of the flow, the form targets and the security headers.
- **Permission sets.** To accept `include:` scopes, pass `lexiconResolver:` an `AuthenticatedOAuthLexiconResolver` from the `PetrelOAuthServerLexicon` product, wrapped in ``CachingOAuthLexiconResolver``. It proves each set came from its authority's signed repository. Without a resolver, a request that names a permission set is refused with `invalid_scope`.
- **Trusted clients.** A client's self-declared name and logo are shown only for the `client_id` values in ``OAuthAuthorizationServerConfiguration/trustedClientIDs``.
- **Session management.** ``OAuthAuthorizationServer/sessions(subject:)``, ``OAuthAuthorizationServer/revokeSession(id:subject:)`` and ``OAuthAuthorizationServer/revokeAllSessions(subject:)`` list and revoke an account's sessions. The server serves no "connected applications" page and no route for these: that page is the host's job, behind its own account sign-in and CSRF protection, and must always pass the subject of the signed-in account.

## Limits

- The `prompt` authorization request parameter (`none`, `login`, `consent`, `select_account`) is not handled. A request that carries it is processed as if it were absent.
