# Getting Started

Install Petrel, run a public query, sign in, and publish a post.

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

func signInWithLoopback(handle: String) async throws -> ATProtoClient {
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

## Before you ship

The loopback client is for development only. A released app publishes a client metadata document and uses its URL as the client ID. <doc:OAuthClient> shows how to build the document, and covers scopes, app passwords and account status.

## Where to go next

- <doc:ArchitectureAndMentalModel> explains DIDs, the PDS, relays and AppViews.
- <doc:XRPCClient> covers typed and untyped calls, paging and errors.
- <doc:ReadingFeedsAndThreads>, <doc:BlueskyPosting>, <doc:BlueskyModeration> and <doc:BlueskyPreferences> cover the Bluesky helpers.
- <doc:LexiconTypesInSwift> and <doc:CustomLexicons> cover the generated API and how to generate one for your own Lexicons.
- [`Examples/`](https://github.com/joshlacal/Petrel/tree/main/Examples) has runnable packages: `LoopbackOAuthSwiftUI`, `StatusphereOverlay` and `JetstreamLiveCLI`.
