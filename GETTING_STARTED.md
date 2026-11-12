# Getting started with Petrel

This guide takes you from adding Petrel to a package to reading public data, signing a user
in with OAuth, posting, and handling errors. It covers the `Petrel` product, the client most
apps use. The [README](README.md) lists the other products and links their guides.

Every Swift code block in this file is extracted and typechecked by
`Scripts/validate-documentation.sh` in CI.

## 1. Install

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

On Linux, install `libsecret-1-dev`, `libglib2.0-dev` and `pkg-config` before building, and
read [LINUX_SUPPORT.md](LINUX_SUPPORT.md): credentials are stored in the desktop keyring or in
encrypted files instead of the Keychain, and event-stream WebSockets depend on the system
libcurl.

The repository also contains a Kotlin generator backend; Kotlin publication is
outside this SPM release gate.

## 2. Read public data

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

Two conventions run through the generated API:

1. Each Lexicon method is a method on the matching namespace: `app.bsky.feed.getAuthorFeed`
   is `client.app.bsky.feed.getAuthorFeed(input:)`. Methods with an output return
   `(responseCode: Int, data: Output?)`.
2. Fields that can hold any record, such as `post.record`, are `ATProtocolValueContainer`.
   `decoded(_:)` returns the typed value when the record is of that type.

## 3. Sign in during development

The OAuth profile lets a client running on your machine sign in without publishing client
metadata. `OAuthConfig.loopback(port:path:scope:)` builds that configuration; your app
listens on `http://127.0.0.1:<port><path>` for the redirect and passes the URL it receives to
`handleOAuthCallback(url:)`. Not every authorization server supports this exception.

<!-- compile-example: guide-loopback-oauth -->
```swift
import Foundation
import Petrel

func startDevelopmentSignIn(handle: String) async throws -> (ATProtoClient, URL?) {
    let config = OAuthConfig.loopback(port: 8765, scope: "atproto transition:generic")
    let client = try await ATProtoClient(oauthConfig: config, namespace: "dev.example.myapp")

    // Sessions persist between launches under `namespace`.
    if await client.hasValidSession() {
        return (client, nil)
    }

    // Resolves the handle to its PDS and authorization server, sends a pushed
    // authorization request with PKCE, and returns the URL to open.
    let authorizationURL = try await client.startOAuthFlow(identifier: handle)
    return (client, authorizationURL)
}
```

## 4. Sign in in production

A production client publishes its client metadata at an `https://` URL, which is its client
ID. For an iOS or macOS app:

1. Pick the URL you will serve the metadata from, for example
   `https://app.example.com/oauth-client-metadata.json`.
2. Use a redirect URI with a custom scheme made from that domain reversed
   (`com.example.app:/oauth/callback`) and register the scheme in your app.
3. Generate the metadata document with `clientMetadataDocument(applicationType:clientName:)`
   and serve it at the client ID URL.

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

Create the client with `ATProtoClient(oauthConfig: productionOAuth, namespace: ...)`. After
sign-in the client binds tokens to a DPoP key, retries with the server's DPoP nonce when asked,
and refreshes tokens once even when several tasks need a refresh at the same time. The
[Authentication](Sources/Petrel/Petrel.docc/Authentication.md) and
[OAuth client](Sources/Petrel/Petrel.docc/OAuthClient.md) articles cover scopes, confidential
clients and sign-out.

## 5. Post with `client.bsky`

Every Lexicon method is available under `client.app.bsky` and `client.com.atproto`.
`client.bsky` adds the Bluesky conveniences on top: it builds rich-text facets with UTF-8 byte
offsets, fills in reply references, uploads images and strips their metadata (EXIF, GPS) by
default.

<!-- compile-example: guide-bsky-posting -->
```swift
import Foundation
import Petrel

func postWithImageAndReply(client: ATProtoClient, jpeg: Data) async throws {
    // Check a draft before publishing it.
    var draft = RichText(text: "Trying @bsky.app with Petrel https://atproto.com #swiftlang")
    await draft.detectFacets { handle in
        try await client.bsky.resolveHandle(handle)
    }
    guard !draft.exceedsPostLimits else {
        print("Too long: \(draft.graphemeLength) graphemes")
        return
    }

    let root = try await client.bsky.post(
        draft.text,
        images: [PostImage(data: jpeg, mimeType: "image/jpeg", alt: "A petrel over the sea")]
    )

    let reply = try await client.bsky.reply(to: root, "And a follow-up in the thread.")
    try await client.bsky.like(root)
    _ = reply
}
```

More in [Posting](Sources/Petrel/Petrel.docc/BlueskyPosting.md),
[Moderation](Sources/Petrel/Petrel.docc/BlueskyModeration.md) and
[Preferences](Sources/Petrel/Petrel.docc/BlueskyPreferences.md).

## 6. Handle errors

<!-- compile-example: guide-error-handling -->
```swift
import Petrel

func loadTimeline(client: ATProtoClient) async {
    do {
        let (_, timeline) = try await client.app.bsky.feed.getTimeline(input: .init(limit: 30))
        print("Loaded \(timeline?.feed.count ?? 0) posts")
    } catch let error as AccountStatusError {
        print("The account is not active:", error.status)
    } catch let error as ATProtoXRPCError {
        print("The server answered \(error.statusCode) \(error.error)")
    } catch NetworkError.authenticationRequired {
        print("Sign in again")
    } catch {
        print("Request failed:", error)
    }
}
```

The [XRPC client](Sources/Petrel/Petrel.docc/XRPCClient.md) article describes the error types,
decoding, pagination and request options.

## Runnable starter projects

The [`Examples/`](Examples/README.md) directory contains self-contained Swift 6 packages you can build and run directly:

- [`Examples/LoopbackOAuthSwiftUI`](Examples/LoopbackOAuthSwiftUI): macOS and iOS SwiftUI app with loopback OAuth (`127.0.0.1`), `WebAuthenticationSession`, timeline loading and `RichText` posting.
- [`Examples/StatusphereOverlay`](Examples/StatusphereOverlay): custom `xyz.statusphere.*` Lexicon overlay package (`swift run StatusphereCLI --demo`).
- [`Examples/JetstreamLiveCLI`](Examples/JetstreamLiveCLI): live Jetstream CLI tailing `app.bsky.feed.post` or custom collections (`swift run JetstreamLiveCLI --limit 5`).

## Where to go next

- [Architecture and mental model](Sources/Petrel/Petrel.docc/ArchitectureAndMentalModel.md):
  DIDs and handles, repositories, relays, AppViews and how Petrel maps onto them.
- [Rosetta Stone](Sources/Petrel/Petrel.docc/RosettaStone.md): how each Lexicon construct
  appears in Swift.
- [Custom Lexicons](Sources/Petrel/Petrel.docc/CustomLexicons.md) and
  [Custom Lexicons and overlay packages](Sources/Petrel/Petrel.docc/CustomLexiconsAndOverlays.md):
  generating typed Swift and Kotlin overlay packages (`petrel-lexgen` and `petrel-gen`).
- [Streaming and verification](Sources/Petrel/Petrel.docc/StreamingAndVerification.md):
  Jetstream, the firehose, repositories and PLC together.
