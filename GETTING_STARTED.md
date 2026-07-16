# Getting Started with Petrel 0.2

This guide covers the Swift Package Manager product shipped by the `0.2.0`
release candidate. Kotlin sources live in this repository, but Kotlin
publication and parity are outside this SPM release gate.

## Requirements

- Swift 6.0 or newer
- Xcode 16.0 or newer for Apple-platform development
- iOS 18.0+ or macOS 15.0+ deployment target
- Linux is supported by the Swift package's Linux release lane

## Add the package

In Xcode, use **File → Add Package Dependencies** and enter
`https://github.com/joshlacal/Petrel.git`. For a package manifest, add the
dependency and Petrel product explicitly:

<!-- compile-example: guide-package-manifest -->
```swift
// swift-tools-version: 6.0

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
            .upToNextMinor(from: "0.2.0")
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

## Call a public endpoint

Create the unauthenticated client with a base URL. Lexicon identifiers use
Petrel's validated wrapper types, and generated endpoint methods use the
`input:` label. Responses contain `responseCode` and optional `data`.

<!-- compile-example: guide-public-profile -->
```swift
import Petrel

func fetchProfile() async throws {
    let client = await ATProtoClient(baseURL: ATProtoClient.defaultBaseURL)
    let actor = try ATIdentifier(string: "alice.bsky.social")
    let response = try await client.app.bsky.actor.getProfile(
        input: AppBskyActorGetProfile.Parameters(actor: actor)
    )

    guard (200 ... 299).contains(response.responseCode),
          let profile = response.data else {
        print("Profile was unavailable (HTTP \(response.responseCode))")
        return
    }
    print(profile.displayName ?? profile.handle.description)
}
```

## Authenticate with OAuth

OAuth with PAR, PKCE, and DPoP is the preferred production path. Host client
metadata for your application, register its redirect URI, and use a unique
keychain namespace.

<!-- compile-example: guide-oauth -->
```swift
import Foundation
import Petrel

func authenticate(callbackURL: URL) async throws {
    let config = OAuthConfig(
        clientId: "https://yourapp.example/oauth/client-metadata.json",
        redirectUri: "com.example.yourapp:/oauth/callback",
        scope: "atproto transition:generic"
    )
    let client = try await ATProtoClient(
        oauthConfig: config,
        namespace: "com.example.yourapp"
    )

    let authorizationURL = try await client.startOAuthFlow(
        identifier: "alice.bsky.social"
    )
    print("Present \(authorizationURL) with your authentication session")

    // Forward the redirect received by your app to the same client instance.
    try await client.handleOAuthCallback(url: callbackURL)
}
```

On SwiftUI platforms, forward the incoming URL from `onOpenURL`. UIKit and
AppKit applications can forward it from their application delegate. Preserve
the client instance that started the flow so it can validate the callback.

## Legacy app-password authentication

The public API still exposes `AuthMode.legacy` and `loginWithPassword` for
compatibility. Use a Bluesky app password, never the account's primary
password. OAuth is preferred for new production applications.

## Generated API conventions

- Namespace traversal mirrors the lexicon ID. For example,
  `app.bsky.actor.getProfile` is available through
  `client.app.bsky.actor.getProfile(input:)`.
- Identifier fields use types such as `ATIdentifier`, `DID`, and `Handle`
  rather than arbitrary strings.
- Endpoint results retain the HTTP status as `responseCode`; decoded success
  data is optional because a response may be unsuccessful or undecodable.
- Calls are asynchronous and can throw transport, authentication, or decoding
  errors.

## Validation and next steps

Every Swift example in this guide, the README, and the DocC tutorials is
extracted and compiled with warnings as errors by
`Scripts/validate-documentation.sh`. Continue with the DocC Getting Started and
Authentication articles for the same checked API surface, and consult
[API_REFERENCE.md](API_REFERENCE.md) for namespace orientation.
