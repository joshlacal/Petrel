# Petrel

Petrel is a Swift 6 SDK for the [AT Protocol](https://atproto.com) and
[Bluesky](https://bsky.app). It gives apps a typed XRPC client generated from the
upstream Lexicon schemas (`com.atproto.*`, `app.bsky.*`, `chat.bsky.*`, `tools.ozone.*`),
OAuth sign-in with PAR, PKCE and DPoP, and Bluesky helpers for posting, moderation and
preferences. For servers and tools it ships the protocol pieces as separate SwiftPM products:
identifiers, identity resolution, keys and signatures, service auth, repositories and MSTs,
firehose and Jetstream streaming, PLC operations, runtime Lexicon validation, and an
embeddable OAuth authorization server.

Petrel runs the official
[bluesky-social/atproto-interop-tests](https://github.com/bluesky-social/atproto-interop-tests)
vectors (syntax, crypto, data-model, mst, firehose and lexicon) in CI on macOS and Linux.

| | |
|---|---|
| **Version** | 2.0.0 |
| **Swift** | Swift 6.1 or later (`swift-tools-version: 6.1`) |
| **Platforms** | macOS 15+, iOS 18+, tvOS 18+, Linux (see [LINUX_SUPPORT.md](LINUX_SUPPORT.md)) |
| **License** | MIT |
| **Maintainer** | [@josh.uno](https://bsky.app/profile/josh.uno) on Bluesky |

## Installation

Add Petrel to your package and depend on the products you need:

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

Regenerating the bundled Lexicons is released as a minor version, and it can change
generated initializers. If you need source stability across updates, use
`.upToNextMinor(from: "2.0.0")` instead of `from: "2.0.0"`.

On Linux the `Petrel` product links `libsecret`; install `libsecret-1-dev`,
`libglib2.0-dev` and `pkg-config` first. [LINUX_SUPPORT.md](LINUX_SUPPORT.md) lists
everything that behaves differently there.

The repository also contains a Kotlin generator backend. Kotlin publication and
Kotlin/Swift parity are outside the `2.0.0` SPM release gate.

## What Petrel covers

The ten rows below are the capability columns of [atproto.com/sdks](https://atproto.com/sdks).
Each row names the product to import, the guide, and the main tests.

| Capability | Import | Guide | Tests | Limits |
| :-- | :-- | :-- | :-- | :-- |
| Identifiers | `Petrel` | [Identifiers](Sources/Petrel/Petrel.docc/Identifiers.md) | [SyntaxVectorTests](Tests/PetrelTests/SyntaxVectorTests.swift): every `syntax/*` vector, valid and invalid | `ATProtocolURI` also accepts the Spaces-alpha form `at://<did>/space/…` by default, as the TypeScript Spaces branch does; pass `grammar: .restricted` to accept only the published grammar. |
| Bluesky helpers | `Petrel` (`client.bsky`) | [Posting](Sources/Petrel/Petrel.docc/BlueskyPosting.md), [Moderation](Sources/Petrel/Petrel.docc/BlueskyModeration.md), [Preferences](Sources/Petrel/Petrel.docc/BlueskyPreferences.md) | [ModerationBehaviorsTests](Tests/PetrelTests/ModerationBehaviorsTests.swift): behaviour tables ported from the TypeScript SDK | Label signatures are not verified. |
| Lexicon | `Petrel`, `PetrelLexicon` | [XRPC client](Sources/Petrel/Petrel.docc/XRPCClient.md), [Custom Lexicons](Sources/Petrel/Petrel.docc/CustomLexicons.md), [Runtime validation](Sources/PetrelLexicon/PetrelLexicon.docc/RuntimeValidation.md) | [LexiconVectorTests](Tests/PetrelLexiconTests/LexiconVectorTests.swift): `lexicon/*` and `data-model/*` vectors | Values decoded through Swift `Codable` keep Foundation's 38-significant-digit limit for numbers; `LexValue(json:)` reads the text and rejects what it cannot represent. |
| Identity | `Petrel` | [Identity](Sources/Petrel/Petrel.docc/Identity.md) | [DIDResolutionBidirectionalTests](Tests/PetrelTests/DIDResolutionBidirectionalTests.swift) | |
| Streaming | `PetrelFirehose`, `PetrelJetstream` | [Event streams](Sources/PetrelFirehose/PetrelFirehose.docc/EventStreams.md), [Jetstream](Sources/PetrelJetstream/PetrelJetstream.docc/Jetstream.md) | [FirehoseCommitProofVectorTests](Tests/PetrelFirehoseTests/FirehoseCommitProofVectorTests.swift) | On Linux, WebSocket connections need a libcurl with WebSocket support, which Ubuntu 22.04 lacks; you can plug in your own WebSocket client (see [LINUX_SUPPORT.md](LINUX_SUPPORT.md)). The firehose client does not verify events on its own; call `verify(keyResolver:)` on each event you need to trust. |
| Service auth | `PetrelCrypto` | [Service auth](Sources/PetrelCrypto/PetrelCrypto.docc/ServiceAuth.md) | [ServiceAuthVerifierTests](Tests/PetrelCryptoTests/ServiceAuthVerifierTests.swift) | |
| Crypto | `PetrelCrypto` | [Cryptography](Sources/PetrelCrypto/PetrelCrypto.docc/Cryptography.md) | [ATProtoCryptoInteropTests](Tests/PetrelTests/ATProtoCryptoInteropTests.swift): every `crypto/*` vector | |
| Repo | `PetrelRepo` | [Repositories](Sources/PetrelRepo/PetrelRepo.docc/Repositories.md) | [RepositoryInteropVectorTests](Tests/PetrelRepoTests/RepositoryInteropVectorTests.swift) (`mst/*` vectors), [RealRepositoryDifferentialTests](Tests/PetrelRepoTests/RealRepositoryDifferentialTests.swift) (a real exported repository checked against an independent reader) | |
| PLC | `PetrelPLC` | [Directory operations](Sources/PetrelPLC/PetrelPLC.docc/DirectoryOperations.md) | [PLCCorpusTests](Tests/PetrelPLCTests/PLCCorpusTests.swift): operations recorded from plc.directory | |
| OAuth server | `PetrelOAuthServer`, `PetrelOAuthServerLexicon`, `PetrelOAuthServerHummingbird` | [Run your own authorization server](Sources/PetrelOAuthServer/PetrelOAuthServer.docc/RunYourOwnAuthorizationServer.md), [Conformance map](Sources/PetrelOAuthServer/PetrelOAuthServer.docc/ConformanceMap.md) | The TypeScript reference client runs against it ([harness](Server/Scripts/ts-client-interop/README.md), [workflow](.github/workflows/oauth-server.yml)) | The `prompt` parameter is not handled yet. There is no built-in "connected apps" page; the API to build one exists. |

The other products are `PetrelCore` (CID, DAG-CBOR, CAR reading), `PetrelOAuthScopes`
(the OAuth permission grammar shared by client and server), `PetrelPLCPDS` (PLC updates
coordinated with a PDS) and `PetrelOzone` (generated `tools.ozone.*` bindings).

## Quick starts

Every Swift code block in this README, in [GETTING_STARTED.md](GETTING_STARTED.md) and in
the DocC catalogs under `Sources/` is extracted and typechecked in CI by
`Scripts/validate-documentation.sh`.

### Read public data

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

Generated methods mirror the Lexicon namespace (`app.bsky.actor.getProfile` is
`client.app.bsky.actor.getProfile(input:)`) and return `(responseCode, data)`.

### Sign in with OAuth and post

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

// 1. Send the user to the authorization page.
func beginSignIn(client: ATProtoClient, handle: String) async throws -> URL {
    try await client.startOAuthFlow(identifier: handle)
}

// 2. When the browser redirects back to your app, finish sign-in and post.
func finishSignInAndPost(client: ATProtoClient, callbackURL: URL) async throws {
    try await client.handleOAuthCallback(url: callbackURL)
    let post = try await client.bsky.post("Hello from Petrel! https://atproto.com #atproto")
    print(post.uri)
}
```

`client.bsky` detects links, mentions and hashtags and writes their facets with UTF-8
byte offsets. The client signs requests with the session's DPoP key and refreshes tokens on
its own. Your app must serve its OAuth client metadata at `clientId`;
`OAuthConfig.clientMetadataDocument(applicationType:clientName:)` builds that document.
[GETTING_STARTED.md](GETTING_STARTED.md) covers local development, SwiftUI and errors.

### Resolve an identity

<!-- compile-example: readme-identity -->
```swift
import Petrel

func resolve() async throws {
    let resolver = IdentityResolver()
    let identity = try await resolver.resolveIdentity("atproto.com")
    print(identity.did, identity.handle)
    if let pds = identity.pdsEndpoint {
        print("PDS:", pds)
    }
}
```

A handle resolves to a DID only when the link holds in both directions: the handle's domain
names the DID (DNS TXT or HTTPS well-known), and the DID document (`did:plc` or `did:web`)
claims the handle.

### Verify a service JWT

<!-- compile-example: readme-service-auth -->
```swift
import Petrel
import PetrelCrypto

/// Create once at startup and share across requests, so the key cache and
/// the replay store see every request.
let serviceAuth = ServiceAuthVerifier(
    audience: .service(did: "did:web:feed.example.com", id: "bsky_fg"),
    keyResolver: CachingServiceAuthKeyResolver(upstream: IdentityResolver()),
    replayStore: InMemoryServiceAuthReplayStore()
)

func authenticate(authorizationHeader: String?) async throws -> String {
    let caller = try await serviceAuth.verify(
        authorizationHeader: authorizationHeader,
        method: .exactly("app.bsky.feed.getFeedSkeleton")
    )
    return caller.issuer
}
```

The verifier checks the signature against the issuer's key from its DID document, and the
audience, expiry, method binding and replay. `ServiceJWT` creates tokens.

### Read a repository CAR

<!-- compile-example: readme-repo -->
```swift
import Foundation
import PetrelRepo

func openRepository(car: Data, didDocument: Data, did: String) async throws {
    let key = try Repository.signingKey(fromDIDDocument: didDocument, did: did)
    let repo = try await Repository.open(
        car: car,
        verification: .signingKey(key),
        expectedDID: did
    )
    print(repo.revision.value, repo.statistics?.recordCount ?? 0)
}
```

`Repository.open` checks the commit signature and verifies every MST node and record before
it returns. Take the signing key from the account's DID document, not from the archive.

### Subscribe to Jetstream

<!-- compile-example: readme-jetstream -->
```swift
import Foundation
import PetrelJetstream

func tailPosts() async throws {
    let subscription = JetstreamSubscription(configuration: .init(
        url: URL(string: "https://jetstream2.us-east.bsky.network")!,
        filter: JetstreamFilter(kinds: [.commit], collections: ["app.bsky.feed.post"])
    ))
    for try await element in subscription.events() {
        if case let .event(.commit(commit)) = element {
            print(commit.did, commit.collection, commit.rkey)
        }
    }
}
```

The subscription reconnects with backoff and resumes from the last delivered cursor. Frames
it cannot use are reported as `.ignoredFrame` rather than dropped silently. For the binary
firehose (`com.atproto.sync.subscribeRepos`) use `PetrelFirehose`.

## Running an authorization server

`PetrelOAuthServer` is an embeddable AT Protocol OAuth authorization server: server and
protected-resource metadata, PAR, the authorization endpoint with consent, the token
endpoint (authorization code and refresh with rotation), PKCE S256, DPoP with server nonces
and replay protection, client metadata discovery, `private_key_jwt`, permission scopes,
revocation and JWKS. It has no HTTP framework dependency; you route requests to it.

- `PetrelOAuthServerLexicon` resolves `include:` permission sets: it finds the Lexicon's
  authority through DNS, fetches the record with its repository proof, and verifies it before
  use.
- `PetrelOAuthServerHummingbird` is a [Hummingbird](https://github.com/hummingbird-project/hummingbird)
  adapter plus `PinnedNIOOAuthRemoteTransport`, the transport that connects only to the
  addresses it has approved when the server fetches client metadata. It is built only when you
  enable the package trait `OAuthServerHummingbird`:

<!-- compile-example: readme-oauth-server-package-manifest -->
```swift
// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "YourServer",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(
            url: "https://github.com/joshlacal/Petrel.git",
            from: "2.0.0",
            traits: ["OAuthServerHummingbird"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "YourServer",
            dependencies: [
                .product(name: "PetrelOAuthServer", package: "Petrel"),
                .product(name: "PetrelOAuthServerLexicon", package: "Petrel"),
                .product(name: "PetrelOAuthServerHummingbird", package: "Petrel"),
            ]
        ),
    ]
)
```

Enabling a trait needs `swift-tools-version: 6.1` or later in your manifest. Apps that do not
enable the trait build none of the server networking packages. Swift 6.2 and later do not
fetch them at all; Swift 6.1 fetches them and records them in `Package.resolved`, but does not
build them. The guide is
[Run your own authorization server](Sources/PetrelOAuthServer/PetrelOAuthServer.docc/RunYourOwnAuthorizationServer.md),
and [ConformanceMap](Sources/PetrelOAuthServer/PetrelOAuthServer.docc/ConformanceMap.md)
maps each specification requirement to code and tests.

## Documentation

- [GETTING_STARTED.md](GETTING_STARTED.md): installation, public calls, OAuth, posting and errors.
- DocC catalogs, one per product: [Petrel](Sources/Petrel/Petrel.docc/Petrel.md),
  [PetrelCore](Sources/PetrelCore/PetrelCore.docc/PetrelCore.md),
  [PetrelCrypto](Sources/PetrelCrypto/PetrelCrypto.docc/PetrelCrypto.md),
  [PetrelRepo](Sources/PetrelRepo/PetrelRepo.docc/PetrelRepo.md),
  [PetrelFirehose](Sources/PetrelFirehose/PetrelFirehose.docc/PetrelFirehose.md),
  [PetrelJetstream](Sources/PetrelJetstream/PetrelJetstream.docc/PetrelJetstream.md),
  [PetrelPLC](Sources/PetrelPLC/PetrelPLC.docc/PetrelPLC.md),
  [PetrelPLCPDS](Sources/PetrelPLCPDS/PetrelPLCPDS.docc/PetrelPLCPDS.md),
  [PetrelLexicon](Sources/PetrelLexicon/PetrelLexicon.docc/PetrelLexicon.md),
  [PetrelOAuthScopes](Sources/PetrelOAuthScopes/PetrelOAuthScopes.docc/PetrelOAuthScopes.md),
  [PetrelOAuthServer](Sources/PetrelOAuthServer/PetrelOAuthServer.docc/PetrelOAuthServer.md),
  [PetrelOAuthServerLexicon](Sources/PetrelOAuthServerLexicon/PetrelOAuthServerLexicon.docc/PetrelOAuthServerLexicon.md),
  [PetrelOzone](Sources/PetrelOzone/PetrelOzone.docc/PetrelOzone.md).
- [docs/Spaces.md](docs/Spaces.md): Petrel's support for the AT Protocol Spaces alpha (permissioned data).
- [CHANGELOG.md](CHANGELOG.md): changes, including source-breaking ones, per release.
- [SECURITY.md](SECURITY.md): how to report a vulnerability.
- [LINUX_SUPPORT.md](LINUX_SUPPORT.md): what differs on Linux.
- [STRUCTURE.md](STRUCTURE.md): how the repository is laid out.
- [KOTLIN_GENERATOR.md](KOTLIN_GENERATOR.md): the Kotlin generator backend (not part of this release).

## Password sign-in

`AuthMode.legacy` and `loginWithPassword` remain public for existing app-password
integrations. Use an app password, never an account's main password, and prefer OAuth for new
applications.

## License

MIT. See [LICENSE](LICENSE).
