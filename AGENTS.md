# Agent Guidelines for Petrel

Petrel is a Swift 6 SDK implementing the AT Protocol and Bluesky XRPC APIs for iOS, macOS, and Linux. The repository combines an automated code generator (`generator/`) that compiles Lexicon JSON schemas into strongly typed Swift and Kotlin models with a hand-written core networking and authentication layer (`Sources/Petrel/`).

## Quick Reference

| Task | Command |
|---|---|
| Build | `swift build` |
| Test | `swift test` |
| Test single suite | `swift test --filter <TestName>` |
| Regenerate code | `python3 run.py --manifest generator/manifests/petrel-core.json && swiftformat Sources/Petrel/Generated` |
| Format Swift | `swiftformat Sources/Petrel/Generated` |

## Repository Layout and Ownership

Never edit files in `Sources/Petrel/Generated/` by hand. The generator completely overwrites this directory on every run.

```
Petrel/
├── Sources/
│   ├── Petrel/
│   │   ├── Account/          # Account lifecycle management (AccountManager)
│   │   ├── Auth/             # Authentication strategies, Keychain, token refresh
│   │   ├── Client/           # Client extensions, debugging, and labeler helpers
│   │   ├── Core/             # Primitives: CID, DAG-CBOR, CAR, DID documents, RichText, TID
│   │   ├── Generated/        # GENERATED CODE — do not edit directly
│   │   │   ├── Client/       # ATProtoClient generated namespace extensions
│   │   │   └── Lexicons/     # Strongly typed Lexicon models and endpoint calls
│   │   └── Network/          # NetworkService actor, DID resolution, DPoP handling
│   └── PetrelLoad/           # Internal concurrency and load-testing executable
├── Tests/                    # Swift test suites
├── generator/                # Python Lexicon code generator (Swift + Kotlin)
│   ├── lexicons/             # Vendored AT Protocol Lexicon JSON schemas
│   ├── manifests/            # Generation manifests (petrel-core.json)
│   └── templates/            # Jinja2 templates for Swift and Kotlin output
├── kotlin/                   # Kotlin multiplatform generated code and runtime
└── Server/                   # Independent SPM package (petrel-cab-server)
```

### Hand-Written vs Generated Boundary

- `Sources/Petrel/Generated/`: Generated automatically from Lexicon schemas. If a generated type or method needs changes, edit the templates in `generator/templates/` or update schemas in `generator/lexicons/`, then regenerate.
- `Sources/Petrel/` (outside `Generated/`): Hand-written core library. Contains authentication coordinators, secure storage, network transport, DID resolution, and IPLD data structures.
- `Server/`: Independent Swift package (`petrel-cab-server`) implementing the Client Assertion Backend for confidential OAuth (`AuthMode.cab`). The Petrel SDK library must never depend on `Server/`. Build and test it separately with `cd Server && swift test`.

## Code Generation Pipeline

The generator reads Lexicon JSON schemas and produces Swift and Kotlin client code:
- **Entry point**: `run.py` (which delegates to `generator/main.py`).
- **Configuration**: Manifests in `generator/manifests/`. The core manifest is `generator/manifests/petrel-core.json`.
- **Swift output**: `Sources/Petrel/Generated/`.
- **Kotlin output**: `kotlin/src/main/kotlin/blue/catbird/petrel/generated/`.

To regenerate code from lexicons:
```bash
python3 run.py --manifest generator/manifests/petrel-core.json
swiftformat Sources/Petrel/Generated
```

You can limit generation to a single language using `--language swift` or `--language kotlin`. By default, `--manifest` emits both Swift and Kotlin (`--language both`).

### SwiftFormat Rules and Round-Trip Invariant

The committed generated Swift code is post-formatted with SwiftFormat. CI enforces that running the generator and SwiftFormat produces an empty diff (`jj diff` or `git diff`).

Formatting behavior across packages:
- **Petrel (Core)**: Automatically picks up `Petrel/.swiftformat` (4-space indentation, `--tabwidth 4`, `--wraparguments before-first`). Always run `swiftformat Sources/Petrel/Generated` after regenerating.
- **Overlay packages** (such as `PetrelCatbird` for custom lexicons): Private overlay packages lack a `.swiftformat` configuration, so default SwiftFormat rules apply. Never pass `--config ../Petrel/.swiftformat` when formatting overlay packages; doing so rewraps enum case tuples and leaves files permanently dirty.
- **Kotlin output**: The generator emits finalized Kotlin code directly to `kotlin/src/main/kotlin/blue/catbird/petrel/generated/`. Kotlin output has no post-generation formatting pass.

## Release Versioning and Compatibility

Downstream packages consume Petrel using `.upToNextMinor(from:)`. Under this convention, **the minor version component is the API compatibility boundary**.

| Change | Version Bump | Example |
|---|---|---|
| Bug fix with no changes to any public declaration | **patch** | `0.2.0` → `0.2.1` |
| Lexicon regeneration or addition to `api-breakage-allowlist.txt` | **minor** | `0.2.1` → `0.3.0` |
| Deliberate redesign or breaking rewrite of hand-written API surface | **major** | `0.3.0` → `1.0.0` |

### Why Lexicon Regenerations Require a Minor Bump

Lexicon regenerations are minor version bumps even when schema changes appear strictly additive. Newly generated fields add parameters to memberwise initializers, change property optionality, and tighten string types into semantic types (such as `String` to `TID` or `ATIdentifier`). Because Swift memberwise initializers break source compatibility when new properties are added, consumers pinning with `.upToNextMinor(from:)` rely on minor bumps to prevent unexpected compilation failures during package resolution updates.

### Multi-Package Release Train

When tagging releases that span Petrel and dependent packages (such as custom lexicon overlays or consumer host applications), maintainers must:
1. Tag the new Petrel release.
2. Tag matching versions in dependent overlay packages that pin Petrel.
3. Update `Package.resolved` in downstream consumer applications.

## High-Level Architecture

### Authentication

Petrel supports multiple authentication strategies unified under the `AuthStrategy` protocol and coordinated by `actor AuthManager`:

- `actor AuthManager`: Manages the active authentication strategy, handles session state transitions, and coordinates credential persistence.
- `AuthMode`: Enum defining the authentication mechanism:
  - `.none`: Unauthenticated mode for public XRPC endpoints.
  - `.legacy`: Password-based authentication using App Passwords (`LegacyPasswordStrategy`).
  - `.publicOAuth`: Standard public OAuth with PAR (Pushed Authorization Requests), PKCE, and DPoP token binding (`PublicOAuthStrategy`). Recommended for native mobile and desktop clients.
  - `.gateway`: Confidential OAuth delegation via a backend gateway (`ConfidentialGatewayStrategy`).
  - `.cab(backendURL: URL)`: Client Assertion Backend mode using DPoP-bound assertions for confidential clients (`CABOAuthStrategy`).
- `struct OAuthConfig`: Configuration for OAuth flows. The `scope` parameter takes a single space-delimited string (for example, `scope: "atproto transition:generic"`), not an array.
- `actor TokenRefreshCoordinator`: Coordinates automatic token refresh with concurrency deduplication, exponential backoff, and DPoP key rotation.
- `KeychainManager` & `KeychainStorage`: Multi-platform secure storage. Uses Apple Keychain on iOS/macOS. On Linux, desktop environments use Secret Service (`LibSecretStore` via `CLibSecretShim`), falling back to AES-GCM encrypted file storage (`FileEncryptedStore`) in headless server environments.

### Networking and XRPC

- `public actor NetworkService`: Implements `NetworkServiceProtocol`. Handles HTTP request construction, query parameter serialization, header injection, DPoP proof generation, and automatic retry on HTTP 401 token expiration.
- **Service DID routing**: The network service automatically routes requests to appropriate service DIDs (for example, adding `atproto-proxy` headers for `app.bsky` AppView and `chat.bsky` Chat endpoints). Endpoints declared in `neverProxyEndpoints` (such as `app.bsky.actor.getPreferences`) bypass proxy routing and talk directly to the user's PDS.
- `DIDResolving` & `actor DIDResolutionService`: Resolves handles and DIDs to PDS base URLs. Supports HTTP resolution via `com.atproto.identity.resolveHandle`, HTTPS well-known lookups (`/.well-known/atproto-did`), and DNS TXT lookups (`_atproto.<handle>`).
- `DIDDocument`, `Service`, `VerificationMethod`: Strongly typed models representing W3C DID documents in `DIDDocHandler.swift`.

### Core Data Primitives

- `struct CID`: Content Identifiers for IPLD blocks. Implements multihash parsing and DAG-CBOR encoding tag 42 (`$link`).
- `actor TIDGenerator`: Generates monotonic sortable timestamp identifiers (TIDs) for repository records.
- `struct SpaceRef`: Identifiers for permissioned space data (`at://{spaceDid}/space/{spaceType}/{skey}`).
- `CARReader`, `CARRepository`, `MSTTraverser`: Primitives for reading and verifying IPLD Content Addressable Archives (CAR) and Merkle Search Trees (MST).
- `RichText`: Utilities for parsing and applying Bluesky rich text facets (mentions, links, tags) to `AttributedString`.

## XRPC API Conventions and Calling Shapes

Generated XRPC endpoints are organized as hierarchical properties on `ATProtoClient`:
- `client.app.bsky...`: Bluesky application lexicons.
- `client.com.atproto...`: Core AT Protocol lexicons (repository, identity, server, sync).
- `client.chat.bsky...`: Bluesky chat lexicons.

### Calling Conventions

1. **Labeled `input:` argument**: Endpoints with parameters or request bodies require an `input:` argument label. Endpoints without parameters or bodies take no arguments.
2. **Strongly typed values**: Parameter structs do not accept raw `String` literals for semantic types. Construct instances of `ATIdentifier`, `Handle`, `DID`, `NSID`, `URI`, or `ATProtocolURI`.
3. **Return values**:
   - Endpoints with an output schema return `(responseCode: Int, data: Output?)`.
   - Endpoints with no output schema (e.g. `com.atproto.server.deleteSession`) return `Int` (the HTTP status code).

### Usage Example

```swift
import Foundation
import Petrel

// Initialize an unauthenticated client for public XRPC queries
let client = await ATProtoClient(baseURL: ATProtoClient.defaultBaseURL)

// Construct typed parameters
let actor = try ATIdentifier(string: "atproto.com")
let (responseCode, profile) = try await client.app.bsky.actor.getProfile(
    input: AppBskyActorGetProfile.Parameters(actor: actor)
)

if responseCode == 200, let profile {
    // Handle is a typed struct; access its string value via .description
    print("Profile handle: \(profile.handle.description)")
}
```

### Authenticated Client Initialization

```swift
let oauthConfig = OAuthConfig(
    clientId: "https://example.com/oauth/client-metadata.json",
    redirectUri: "https://example.com/oauth/callback",
    scope: "atproto transition:generic"
)

let client = try await ATProtoClient(
    oauthConfig: oauthConfig,
    namespace: "com.example.app",
    authMode: .publicOAuth
)
```

## Error Handling

Petrel categorizes errors into three layers:
- `NetworkError`: Low-level network transport, connectivity, URL formatting, and HTTP status code errors.
- `APIError`: Client-side state issues such as expired tokens, uninitialized services, or calling authenticated methods on an unauthenticated client.
- `ATProtoError<ErrorType>`: Strongly typed Lexicon error responses parsed from server payloads via `ATProtoErrorParser`.

## Coding Style

- **Indentation**: 4 spaces, matching `Petrel/.swiftformat` (`--indent 4`, `--tabwidth 4`, `--wraparguments before-first`).
- **Concurrency**: Swift 6 strict concurrency (`.swiftLanguageMode(.v6)`). Use actor isolation for stateful components, async/await for asynchronous operations, and verify `Sendable` conformance across boundary types.
