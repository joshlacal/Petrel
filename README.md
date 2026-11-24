# Petrel

Petrel is a Swift 6 SDK for the [AT Protocol](https://atproto.com) and
[Bluesky](https://bsky.app). It provides a typed XRPC client generated from the upstream
Lexicon schemas, OAuth sign-in (PAR, PKCE, DPoP), Bluesky helpers for posting, moderation and
preferences, and separate SwiftPM products for identity, cryptography, repositories,
event streams, PLC and an embeddable OAuth authorization server.

- Swift 6.1 or later. macOS 15+, iOS 18+, tvOS 18+, Linux ([LINUX_SUPPORT.md](LINUX_SUPPORT.md)).
- Documentation: [joshlacal.github.io/Petrel](https://joshlacal.github.io/Petrel/documentation/petrel/)
- License: MIT. Maintainer: [@josh.uno](https://bsky.app/profile/josh.uno) on Bluesky.

CI runs the
[bluesky-social/atproto-interop-tests](https://github.com/bluesky-social/atproto-interop-tests)
vectors (syntax, crypto, data-model, mst, firehose, lexicon) on macOS and Linux.

## Install

<!-- compile-example: readme-package-manifest -->
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
        .package(url: "https://github.com/joshlacal/Petrel.git", from: "2.0.0"),
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

Lexicon regenerations ship as minor versions and can change generated initializers. For
source stability, use `.upToNextMinor(from: "2.0.0")`. On Linux, install
`libsecret-1-dev`, `libglib2.0-dev` and `pkg-config` first.

## Example

<!-- compile-example: readme-public-profile -->
```swift
import Foundation
import Petrel

func fetchPublicProfile() async throws {
    let client = await ATProtoClient(baseURL: URL(string: "https://public.api.bsky.app")!)
    let actor = try ATIdentifier(string: "bsky.app")
    let (responseCode, profile) = try await client.app.bsky.actor.getProfile(
        input: .init(actor: actor)
    )
    if responseCode == 200, let profile {
        print(profile.displayName ?? profile.handle.description)
    }
}
```

Generated methods mirror the Lexicon namespace and return `(responseCode, data)`.

To sign in with OAuth and post:

<!-- compile-example: readme-oauth -->
```swift
import Foundation
import Petrel

func makeClient() async throws -> ATProtoClient {
    let oauth = OAuthConfig(
        clientId: "https://app.example.com/oauth-client-metadata.json",
        redirectUri: "com.example.app:/oauth/callback",
        scope: "atproto transition:generic"
    )
    return try await ATProtoClient(oauthConfig: oauth, namespace: "com.example.app")
}

// Open this URL in a browser.
func beginSignIn(client: ATProtoClient, handle: String) async throws -> URL {
    try await client.startOAuthFlow(identifier: handle)
}

// Call this with the redirect URL your app receives.
func finishSignInAndPost(client: ATProtoClient, callbackURL: URL) async throws {
    try await client.handleOAuthCallback(url: callbackURL)
    let post = try await client.bsky.post("Hello from Petrel! https://atproto.com #atproto")
    print(post.uri)
}
```

Your app must serve its client metadata at `clientId`;
`OAuthConfig.clientMetadataDocument(applicationType:clientName:)` builds it.

## Products

| Product | Purpose |
| :-- | :-- |
| `Petrel` | XRPC client, OAuth client, identity resolution, Bluesky helpers |
| `PetrelCore` | CID, DAG-CBOR, CAR reading |
| `PetrelCrypto` | Keys, signatures, service auth JWTs |
| `PetrelRepo` | Repositories and MSTs |
| `PetrelFirehose` | `com.atproto.sync.subscribeRepos` client |
| `PetrelJetstream` | Jetstream client |
| `PetrelPLC` | PLC operations |
| `PetrelPLCPDS` | PLC updates coordinated with a PDS |
| `PetrelLexicon` | Runtime Lexicon validation |
| `PetrelOAuthScopes` | OAuth permission grammar |
| `PetrelOAuthServer` | Embeddable OAuth authorization server |
| `PetrelOAuthServerLexicon` | `include:` permission-set resolution for the server |
| `PetrelOAuthServerNIO`, `PetrelOAuthServerHummingbird` | Server transports, behind the `OAuthServerNIO` and `OAuthServerHummingbird` package traits |
| `PetrelOzone` | Generated `tools.ozone.*` bindings |

## SDK capabilities

The rows follow the capability columns of [atproto.com/sdks](https://atproto.com/sdks).

| Capability | Product | Guide | Tests | Limits |
| :-- | :-- | :-- | :-- | :-- |
| Identifiers | `Petrel` | [Identifiers](Sources/Petrel/Petrel.docc/Identifiers.md) | [SyntaxVectorTests](Tests/PetrelTests/SyntaxVectorTests.swift) | `ATProtocolURI` accepts the Spaces alpha form `at://<did>/space/…` by default; pass `grammar: .restricted` for the published grammar only. |
| Bluesky helpers | `Petrel` | [Posting](Sources/Petrel/Petrel.docc/BlueskyPosting.md), [Moderation](Sources/Petrel/Petrel.docc/BlueskyModeration.md), [Preferences](Sources/Petrel/Petrel.docc/BlueskyPreferences.md) | [ModerationBehaviorsTests](Tests/PetrelTests/ModerationBehaviorsTests.swift) | Label signatures are not verified. |
| Lexicon | `Petrel`, `PetrelLexicon` | [XRPC client](Sources/Petrel/Petrel.docc/XRPCClient.md), [Custom Lexicons](Sources/Petrel/Petrel.docc/CustomLexicons.md), [Runtime validation](Sources/PetrelLexicon/PetrelLexicon.docc/RuntimeValidation.md) | [LexiconVectorTests](Tests/PetrelLexiconTests/LexiconVectorTests.swift) | Numbers decoded through `Codable` keep Foundation's 38-digit limit; `LexValue(json:)` rejects what it cannot represent. |
| Identity | `Petrel` | [Identity](Sources/Petrel/Petrel.docc/Identity.md) | [DIDResolutionBidirectionalTests](Tests/PetrelTests/DIDResolutionBidirectionalTests.swift) | |
| Streaming | `PetrelFirehose`, `PetrelJetstream` | [Event streams](Sources/PetrelFirehose/PetrelFirehose.docc/EventStreams.md), [Jetstream](Sources/PetrelJetstream/PetrelJetstream.docc/Jetstream.md) | [FirehoseCommitProofVectorTests](Tests/PetrelFirehoseTests/FirehoseCommitProofVectorTests.swift) | Firehose events are not verified unless you call `verify(keyResolver:)`. Linux WebSockets need a libcurl with WebSocket support. |
| Service auth | `PetrelCrypto` | [Service auth](Sources/PetrelCrypto/PetrelCrypto.docc/ServiceAuth.md) | [ServiceAuthVerifierTests](Tests/PetrelCryptoTests/ServiceAuthVerifierTests.swift) | |
| Crypto | `PetrelCrypto` | [Cryptography](Sources/PetrelCrypto/PetrelCrypto.docc/Cryptography.md) | [ATProtoCryptoInteropTests](Tests/PetrelTests/ATProtoCryptoInteropTests.swift) | |
| Repo | `PetrelRepo` | [Repositories](Sources/PetrelRepo/PetrelRepo.docc/Repositories.md) | [RepositoryInteropVectorTests](Tests/PetrelRepoTests/RepositoryInteropVectorTests.swift), [RealRepositoryDifferentialTests](Tests/PetrelRepoTests/RealRepositoryDifferentialTests.swift) | |
| PLC | `PetrelPLC` | [Directory operations](Sources/PetrelPLC/PetrelPLC.docc/DirectoryOperations.md) | [PLCCorpusTests](Tests/PetrelPLCTests/PLCCorpusTests.swift) | |
| OAuth server | `PetrelOAuthServer` | [Run your own authorization server](Sources/PetrelOAuthServer/PetrelOAuthServer.docc/RunYourOwnAuthorizationServer.md), [Conformance map](Sources/PetrelOAuthServer/PetrelOAuthServer.docc/ConformanceMap.md) | [TypeScript client interop](Server/Scripts/ts-client-interop/README.md) | The `prompt` parameter is not handled. No built-in connected-apps page. |

## More

- [GETTING_STARTED.md](GETTING_STARTED.md): install, first query, sign-in.
- [CODEGEN.md](CODEGEN.md): the `petrel-gen` CLI and custom Lexicon overlay packages.
- [Examples/](Examples/README.md): runnable sample packages.
- [docs/Spaces.md](docs/Spaces.md): Spaces alpha support.
- [CHANGELOG.md](CHANGELOG.md), [SECURITY.md](SECURITY.md), [STRUCTURE.md](STRUCTURE.md),
  [KOTLIN_GENERATOR.md](KOTLIN_GENERATOR.md).

The repository also contains a Kotlin generator backend. Kotlin publication and
Kotlin/Swift parity are outside the `2.0.0` SPM release gate.

Password sign-in (`AuthMode.legacy`, `loginWithPassword`) remains for existing app-password
integrations. Use an app password, not the account password, and prefer OAuth.

## License

MIT. See [LICENSE](LICENSE).
