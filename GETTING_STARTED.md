# Getting started with Petrel

This page covers installing Petrel, making a first query and signing in. The
[Getting Started article](https://joshlacal.github.io/Petrel/documentation/petrel/gettingstarted)
in the documentation goes further: loopback OAuth for development, posting, and error handling.

## Install

Petrel needs Swift 6.1 or later and runs on macOS 15+, iOS 18+, tvOS 18+ and Linux.

<!-- compile-example: guide-package-manifest -->
```swift
// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    dependencies: [
        .package(url: "https://github.com/joshlacal/Petrel.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: [
                .product(name: "Petrel", package: "Petrel"),
            ]
        ),
    ]
)
```

On Linux, install `libsecret-1-dev`, `libglib2.0-dev` and `pkg-config` first, and see
[LINUX_SUPPORT.md](LINUX_SUPPORT.md).

## Make a first query

Public Bluesky data needs no account. Point an `ATProtoClient` at the public AppView:

<!-- compile-example: guide-public-profile -->
```swift
import Foundation
import Petrel

func printProfileAndPosts(handle: String) async throws {
    let client = await ATProtoClient(baseURL: URL(string: "https://public.api.bsky.app")!)
    let actor = try ATIdentifier(string: handle)

    let (profileCode, profile) = try await client.app.bsky.actor.getProfile(
        input: .init(actor: actor)
    )
    if profileCode == 200, let profile {
        print(profile.displayName ?? profile.handle.description, profile.did)
    }

    let (feedCode, feed) = try await client.app.bsky.feed.getAuthorFeed(
        input: .init(actor: actor, limit: 10)
    )
    if feedCode == 200, let feed {
        for item in feed.feed {
            if let post = item.post.record.decoded(AppBskyFeedPost.self) {
                print("-", post.text)
            }
        }
    }
}
```

Each Lexicon method is a method on its namespace (`app.bsky.feed.getAuthorFeed` is
`client.app.bsky.feed.getAuthorFeed(input:)`) and returns `(responseCode, data)`. Fields that
can hold any record are `ATProtocolValueContainer`; `decoded(_:)` returns the typed value.

## Sign in

A production client serves its OAuth client metadata at an `https://` URL, which is its
client ID, and uses a custom-scheme redirect URI made from that domain reversed. Generate the
metadata with `clientMetadataDocument(applicationType:clientName:)`.

<!-- compile-example: guide-oauth -->
```swift
import AuthenticationServices
import Foundation
import Petrel
import SwiftUI

let productionOAuth = OAuthConfig(
    clientId: "https://app.example.com/oauth-client-metadata.json",
    redirectUri: "com.example.app:/oauth/callback",
    scope: "atproto transition:generic"
)

func clientMetadataJSON() throws -> Data {
    let document = try productionOAuth.clientMetadataDocument(
        applicationType: .native,
        clientName: "My App"
    )
    return try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys])
}

struct SignInView: View {
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    let client: ATProtoClient
    @State private var handle = ""

    var body: some View {
        HStack {
            TextField("alice.bsky.social", text: $handle)
            Button("Sign In") {
                Task {
                    do {
                        let url = try await client.startOAuthFlow(identifier: handle)
                        let callback = try await webAuthenticationSession.authenticate(
                            using: url,
                            callback: .customScheme("com.example.app"),
                            additionalHeaderFields: [:]
                        )
                        try await client.handleOAuthCallback(url: callback)
                    } catch {
                        print("Sign-in failed:", error)
                    }
                }
            }
        }
    }
}
```

Create the client with `ATProtoClient(oauthConfig: productionOAuth, namespace: ...)`. The
client binds tokens to a DPoP key and refreshes them for you.

## Next steps

- [Getting Started](https://joshlacal.github.io/Petrel/documentation/petrel/gettingstarted):
  development sign-in, posting with `client.bsky`, errors.
- [Signing in](Sources/Petrel/Petrel.docc/OAuthClient.md): OAuth flows, scopes, confidential clients, sign-out.
- [XRPC client](Sources/Petrel/Petrel.docc/XRPCClient.md): error types, pagination, request options.
- [Examples/](Examples/README.md): runnable sample packages.

The repository also contains a Kotlin generator backend; Kotlin publication is
outside this SPM release gate.
