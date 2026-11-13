# Getting Started

Install Petrel 2.0, run a public XRPC query, sign in locally with loopback OAuth, sign in from SwiftUI with `WebAuthenticationSession`, and generate your production client metadata.

## Installation

Add Petrel `2.0.0` to your `Package.swift`. Petrel needs Swift 6.1 or later and supports macOS 15, iOS 18 and tvOS 18 or later, plus Linux (see `LINUX_SUPPORT.md` in the repository):

<!-- compile-example: package-manifest -->
```swift
// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "YourApp",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    dependencies: [
        .package(
            url: "https://github.com/joshlacal/Petrel.git",
            .upToNextMinor(from: "2.0.0")
        ),
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: [
                .product(name: "Petrel", package: "Petrel"),
            ]
        ),
    ]
)
```

## Query a public endpoint

Public Bluesky AppView endpoints need no account or API key. Point an unauthenticated ``ATProtoClient`` at `https://public.api.bsky.app` and call any `app.bsky.*` query:

<!-- compile-example: getting-started-basic -->
```swift
import Foundation
import Petrel

func fetchProfileExample() async throws {
    let client = await ATProtoClient(
        baseURL: URL(string: "https://public.api.bsky.app")!
    )
    let actor = try ATIdentifier(string: "bsky.app")
    let (responseCode, profile) = try await client.app.bsky.actor.getProfile(
        input: .init(actor: actor)
    )

    if responseCode == 200, let profile {
        print("@\(profile.handle.description) — \(profile.displayName ?? "No name")")
        print("Followers: \(profile.followersCount ?? 0)")
    }
}
```

## Sign in during development with loopback OAuth

A production atproto OAuth client is identified by the `https` URL of a client metadata document it publishes. During development you can skip publishing one: ``OAuthConfig/loopback(port:path:scope:)`` uses the profile's localhost exception, with the same PAR, PKCE and DPoP flow and a redirect to `http://127.0.0.1`. It works only as a public client, and only with authorization servers that support the exception:

<!-- compile-example: getting-started-loopback-oauth -->
```swift
import Foundation
import Petrel

func signInWithZeroDeployLoopback(handle: String) async throws -> ATProtoClient {
    // The atproto OAuth localhost exception:
    //   clientId    -> "http://localhost?redirect_uri=http%3A%2F%2F127.0.0.1%3A8765%2Fcallback&scope=..."
    //   redirectUri -> "http://127.0.0.1:8765/callback"
    let oauth = OAuthConfig.loopback(
        port: 8765,
        path: "/callback",
        scope: "atproto transition:generic"
    )

    let client = try await ATProtoClient(
        oauthConfig: oauth,
        namespace: "dev.local.quickstart"
    )

    // Reuse a stored session if this namespace is already signed in:
    if await client.hasValidSession() {
        return client
    }

    let authURL = try await client.startOAuthFlow(identifier: handle)
    print("Authorize in browser: \(authURL)")
    return client
}
```

## Sign in from SwiftUI and post

On iOS and macOS, pair ``ATProtoClient/startOAuthFlow(identifier:bskyAppViewDID:bskyChatDID:)`` with SwiftUI's `@Environment(\.webAuthenticationSession)` (backed by `ASWebAuthenticationSession`), then publish a post with the Bluesky helpers on ``ATProtoClient/bsky``:

<!-- compile-example: getting-started-swiftui-auth -->
```swift
import AuthenticationServices
import Petrel
import SwiftUI

struct QuickstartSignInButton: View {
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    let client: ATProtoClient
    let handle: String

    var body: some View {
        Button("Sign in with AT Protocol") {
            Task {
                do {
                    let authURL = try await client.startOAuthFlow(identifier: handle)
                    let callbackURL = try await webAuthenticationSession.authenticate(
                        using: authURL,
                        callback: .customScheme("com.example.yourapp"),
                        additionalHeaderFields: [:]
                    )
                    try await client.handleOAuthCallback(url: callbackURL)

                    // Links, @mentions and #hashtags in the text become facets:
                    let post = try await client.bsky.post(
                        "Hello from Petrel 2.0! https://atproto.com #atproto"
                    )
                    print("Published \(post.uri.uriString())")
                } catch {
                    print("Sign-in or post failed: \(error)")
                }
            }
        }
    }
}
```

## Publish client metadata for production

Before you ship, ask ``OAuthConfig`` to check your configuration (including that a custom redirect scheme is the client ID's hostname in reverse-domain order) and build the client metadata document to serve at the client ID URL:

<!-- compile-example: getting-started-client-metadata -->
```swift
import Foundation
import Petrel

func buildProductionClientMetadata() throws -> Data {
    let config = OAuthConfig(
        clientId: "https://yourapp.example.com/oauth-client-metadata.json",
        redirectUri: "com.example.yourapp:/oauth/callback",
        scope: "atproto transition:generic"
    )
    try config.validate()

    let document = try config.clientMetadataDocument(
        applicationType: .native,
        clientName: "YourApp"
    )
    return try JSONSerialization.data(
        withJSONObject: document,
        options: [.prettyPrinted, .sortedKeys]
    )
}
```

Serve those bytes at `https://yourapp.example.com/oauth-client-metadata.json` with `Content-Type: application/json`, register `com.example.yourapp` under `CFBundleURLTypes` in `Info.plist` (or the equivalent for your platform). The client then works with any PDS whose authorization server follows the atproto OAuth profile.

## Next Steps

- Learn how DIDs, PDS repositories, relays, AppViews and `AuthMode` fit together in <doc:ArchitectureAndMentalModel>.
- Make typed and untyped calls, page through results and handle errors in <doc:XRPCClient>.
- Post, moderate and edit preferences with the Bluesky helpers in <doc:BlueskyPosting>, <doc:BlueskyModeration> and <doc:BlueskyPreferences>.
- Look up how a Lexicon construct maps to Swift in <doc:RosettaStone>.
- Dive deeper into OAuth scopes, confidential backends, and account hosting status in <doc:Authentication> and <doc:OAuthClient>.
