# Petrel repository structure

Petrel is one Swift package (`Package.swift`, swift-tools 6.1, iOS 18 / macOS 15 / tvOS 18 /
Linux) that ships several library products, plus a nested server package, a Python code
generator and generated Kotlin bindings.

## Top-level layout

```
Petrel/
├── Package.swift              # Root Swift package: library products below
├── Sources/                   # One directory per Swift target
├── Tests/                     # One test target per product, plus release consumers
├── Plugins/PetrelLexgen/      # `swift package petrel-lexgen` command plugin
├── Server/                    # Nested Swift package (Hummingbird/NIO), not a root dependency
├── generator/                 # Python Lexicon code generator (Swift + Kotlin)
├── kotlin/                    # Generated Kotlin bindings and runtime (Gradle)
├── Examples/                  # Example programs
├── Scripts/                   # CI, release and maintenance scripts (Scripts/tests: their tests)
├── docs/                      # Release notes, API-compatibility reviews, protocol contracts
├── tools/ref-client/          # TypeScript reference client used for interop checks
└── atproto/                   # Git submodule (atproto fork); not needed to build or test
```

## Library products (root package)

| Product | Directory | What it is |
|---|---|---|
| `Petrel` | `Sources/Petrel` | The client SDK: `ATProtoClient`, generated XRPC API, authentication (OAuth, app passwords, gateway, CAB), identity resolution, service auth, Bluesky helpers, credential storage. Re-exports `PetrelCore`, `PetrelCrypto` and `PetrelOAuthScopes`. |
| `PetrelCore` | `Sources/PetrelCore` | Data model: CID, DAG-CBOR, DAG-JSON bridge, CAR reading. |
| `PetrelCrypto` | `Sources/PetrelCrypto` | P-256 and K-256 keys, signing and low-S verification, `did:key` encoding, service-auth JWTs. |
| `PetrelRepo` | `Sources/PetrelRepo` | Repositories: the `Repository` type (open, verify, edit, export), MST, commits signed on both curves, CAR import/export, proofs, commit diffs. The MST code adapts the atproto reference implementation; see `THIRD_PARTY_NOTICES.md`. |
| `PetrelFirehose` | `Sources/PetrelFirehose` | Event-stream (firehose, labeler, any Lexicon subscription) consumer with commit verification. |
| `PetrelJetstream` | `Sources/PetrelJetstream` | Jetstream consumer, including zstd-compressed streams. |
| `PetrelPLC` | `Sources/PetrelPLC` | `did:plc` operations, audit-log verification, PLC directory client. |
| `PetrelPLCPDS` | `Sources/PetrelPLCPDS` | Changing a `did:plc` identity through the account's PDS. |
| `PetrelOAuthScopes` | `Sources/PetrelOAuthScopes` | The OAuth scope and permission grammar shared by clients and servers. |
| `PetrelOAuthServer` | `Sources/PetrelOAuthServer` | Framework-agnostic OAuth authorization server and resource-server verifier. |
| `PetrelOAuthServerLexicon` | `Sources/PetrelOAuthServerLexicon` | Authenticated Lexicon resolver for `include:` permission sets (DNS, DID document, signed-repository proof). |
| `PetrelOzone` | `Sources/PetrelOzone` | Generated `tools.ozone` moderation-service API. |
| `PetrelLexicon` | `Sources/PetrelLexicon` | Runtime Lexicon schemas: parsing, data validation, network resolution. |

Other root targets: `PetrelLoad` (executable load/concurrency harness), `CLibSecret` and
`CLibSecretShim` (libsecret bridge, Linux only), `CPetrelBLAKE3` (vendored BLAKE3 C sources),
`FirehoseDemo` (example executable in `Examples/`) and the `PetrelLexgen` plugin.

Each product has a DocC catalog at `Sources/<Product>/<Product>.docc`.

## Inside `Sources/Petrel`

- `Client/`: `ATProtoClient` extensions (XRPC, identity, labelers, debugging).
- `Auth/`: `AuthManager`, strategies (`Strategies/`), OAuth (`OAuth/`), token refresh (`Token/`),
  permissioned-space credentials (`Space/`).
- `Identity/`: handle and DID resolution with bidirectional verification and caching.
- `ServiceAuth/`: verifying inter-service JWTs against the issuer's DID document.
- `Network/`: `NetworkService`, hardened transport, SSRF address checks, request deduplication.
- `Storage/`: `SecureStorage` backends (Apple Keychain, libsecret, encrypted files) and
  `CredentialStorageConfiguration`.
- `Helpers/`: Bluesky helpers (`BskyAgent`, rich text, moderation, preferences, labels).
- `Core/`: syntax types (DID, handle, NSID, AT-URI, TID, record key, datetime, language), CAR
  helpers, utilities such as `ImageMetadataStripper`.
- `Account/`: multi-account management and logging.
- `Generated/`: generated Lexicon types and `ATProtoClient` namespaces. Never edit by hand; see
  below.

## Tests

`Tests/<Product>Tests` per product, `Tests/PetrelStreamingTestSupport` (shared fixtures),
`Tests/LexiconFixture` and `Tests/PetrelLexiconFixtureTests` (generator output fixture),
`Tests/ReleaseConsumers` (packages that consume Petrel by URL or with two overlays, used by the
release gate) and `Tests/ReleaseScripts` (shell tests of release scripts). Official atproto
interop vectors are vendored under `Tests/<Target>/Vectors/`.

## `Server/` package

A separate package so the root package never depends on Hummingbird or NIO:

- `PetrelOAuthServerHummingbird`: HTTP adapter for `PetrelOAuthServer`, including the
  address-pinning NIO transport used for client-metadata fetches.
- `petrel-oauth-server-example`: runnable example authorization server.
- `PetrelCABServerCore`, `petrel-cab-server`, `petrel-cab-demo`: the Client Assertion Backend
  for confidential OAuth clients (`AuthMode.cab`).

Build and test it with `cd Server && swift test`.

## Code generation

`run.py` drives `generator/`, configured by manifests in `generator/manifests/`
(`petrel-core.json` for this package). Vendored Lexicons live in `generator/lexicons/`. Swift
output goes to `Sources/Petrel/Generated`, Kotlin output to
`kotlin/src/main/kotlin/blue/catbird/petrel/generated/`.

```bash
python3 run.py --manifest generator/manifests/petrel-core.json
swiftformat Sources/Petrel/Generated   # SwiftFormat 0.61.1, as pinned in CI
```

CI regenerates and requires an empty diff.
