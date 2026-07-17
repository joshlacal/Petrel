# Petrel

Petrel is a Swift 6 SDK for the [AT Protocol](https://atproto.com) and
[Bluesky](https://bsky.app). It generates strongly typed, actor-based APIs from
the upstream `com.atproto.*`, `app.bsky.*`, and `chat.bsky.*` lexicons.

The `0.2.0` package release is scoped to the Swift Package Manager product.
The repository also contains Kotlin generator output, but Kotlin publication
and Kotlin/Swift parity are outside the `0.2.0` SPM release gate.

| | |
|---|---|
| **Swift** | Swift 6; iOS 18+, macOS 15+, and Linux |
| **Auth** | OAuth with PAR, PKCE, and DPoP; gateway/CAB modes; legacy app-password compatibility |
| **API shape** | Async generated namespace methods returning `(responseCode, data)` |
| **License** | MIT |

## Installation

Add Petrel to a Swift package:

<!-- compile-example: readme-package-manifest -->
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

## OAuth quick start

OAuth is the recommended authentication mode for production applications. The
client metadata URL and redirect URI below must describe your own registered
application.

<!-- compile-example: readme-oauth -->
```swift
import Foundation
import Petrel

func signIn(callbackURL: URL) async throws -> ATProtoClient {
    let config = OAuthConfig(
        clientId: "https://yourapp.example/oauth/client-metadata.json",
        redirectUri: "com.example.yourapp:/oauth/callback",
        scope: "atproto transition:generic"
    )
    let client = try await ATProtoClient(
        oauthConfig: config,
        namespace: "com.example.yourapp",
        userAgent: "YourApp/1.0"
    )

    let authorizationURL = try await client.startOAuthFlow(
        identifier: "alice.bsky.social"
    )
    print("Open \(authorizationURL)")

    // Present authorizationURL, then pass the received redirect URL here.
    try await client.handleOAuthCallback(url: callbackURL)
    return client
}
```

## Public endpoint quick start

Unauthenticated clients can call public endpoints. Generated calls accept a
labeled `input` value and return the HTTP response code plus optional decoded
data.

<!-- compile-example: readme-public-profile -->
```swift
import Petrel

func printPublicProfile() async throws {
    let client = await ATProtoClient(baseURL: ATProtoClient.defaultBaseURL)
    let actor = try ATIdentifier(string: "alice.bsky.social")
    let response = try await client.app.bsky.actor.getProfile(
        input: .init(actor: actor)
    )

    if let profile = response.data {
        print(profile.displayName ?? profile.handle.description)
    } else {
        print("Profile request returned HTTP \(response.responseCode)")
    }
}
```

## Authentication compatibility

Petrel publicly retains `AuthMode.legacy` and `loginWithPassword` for existing
app-password integrations. That path is legacy compatibility: use an app
password rather than a primary account password, and prefer OAuth for new
production applications.

## Documentation

- [Getting Started](GETTING_STARTED.md) covers installation, public calls, and OAuth.
- [Release candidate notes](docs/releases/0.2.0.md) define the `0.2.0` gate and remaining publication prerequisites.
- [Kotlin generator notes](KOTLIN_GENERATOR.md) describe repository tooling that is outside this SPM release gate.

The release contract typechecks exactly these four launch documents: README,
Getting Started, and the two DocC tutorials. It does not certify every Markdown file
elsewhere in the repository.

## License

MIT — see [LICENSE](LICENSE).
