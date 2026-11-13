# Schema-First Lexicon Code Generation (`petrel-gen`)

`petrel-gen` is Petrel's schema-first compiler for the [AT Protocol](https://atproto.com) (**Lexicon** JSON schemas → strict **Swift 6** and **Kotlin** client/server code). It compiles upstream `com.atproto.*`, `app.bsky.*`, `chat.bsky.*`, and `site.standard.*` schemas inside Petrel itself, and lets external ATmosphere builders generate standalone **overlay packages** for custom namespaces (such as `xyz.statusphere.*`) without cloning or forking the Petrel repository.

Every `petrel-gen` wheel ships with all **440 core AT Protocol reference lexicons** bundled inside package data (`@petrel/core-lexicons`). You can scaffold a new Swift 6 + Kotlin overlay package in an empty directory, reference upstream types like `com.atproto.repo.strongRef` or `app.bsky.richtext.facet`, and emit deterministic, production-ready code in under 60 seconds.

---

## Table of Contents

1. [Why Schema-First Codegen Wins](#why-schema-first-codegen-wins)
2. [60-Second Custom Lexicon Overlay Quickstart (`xyz.statusphere.status`)](#60-second-custom-lexicon-overlay-quickstart-xyzstatuspherestatus)
3. [Using Your Generated Overlay in Swift 6 & Kotlin](#using-your-generated-overlay-in-swift-6--kotlin)
4. [`petrel-gen` CLI Reference](#petrel-gen-cli-reference)
5. [Xcode & SwiftPM Command Plugin (`PetrelCodegenPlugin`)](#xcode--swiftpm-command-plugin-petrelcodegenplugin)
6. [Complete `petrel-manifest.json` Reference](#complete-petrel-manifestjson-reference)
7. [SwiftFormat & Deterministic Output Rules](#swiftformat--deterministic-output-rules)
8. [Versioning Contract (`.upToNextMinor`) & Release Train](#versioning-contract-uptonextminor--release-train)

---

## Why Schema-First Codegen Wins

In the AT Protocol, every record stored in a user's **PDS** (Personal Data Server — the signed repository hosting a user's records), every **XRPC** endpoint (Cross-System RPC — ATProto's typed HTTP query and procedure layer), and every event stream frame is defined by a **Lexicon** JSON schema identified by an **NSID** (Namespace Identifier, reverse-DNS names such as `app.bsky.feed.post` or `xyz.statusphere.status`).

Hand-writing `Codable` structs looks tempting for a single endpoint, then breaks down across real ATProto requirements. Compiling directly from Lexicon JSON gives you six guarantees for free:

| Capability | Hand-Written `Codable` | `petrel-gen` Schema Compiler |
|---|---|---|
| **Dual Wire Fidelity (JSON + DAG-CBOR)** | Breaks on binary repository signing; misses `"$type"` discriminators or tag-42 **CID** (Content Identifier) links. | Emits both `Codable` JSON codecs and deterministic `toCBORValue()` (**DAG-CBOR** via `OrderedCBORMap`) so records hash and sign identically across PDS repos and Firehose CAR blocks. |
| **Swift 6 Strict Concurrency** | Manual `Sendable` audits and actor isolation boilerplate. | Every generated model, union, parameter struct, and `ATProtoClient` namespace tree is `Sendable` and compiles cleanly under `.swiftLanguageMode(.v6)`. |
| **Semantic Primitives** | Raw `String` values allow handles, DIDs, and URIs to be mixed up at call sites. | Enforces validated wrapper types (`DID`, `Handle`, `ATIdentifier`, `ATProtocolURI`, `ATProtocolDate`, `CID`, `TID`, `NSID`, `RecordKey`). |
| **Forward-Compatible Decoding** | One unexpected union variant or malformed optional field crashes decoding for an entire feed. | Malformed optional fields read as `nil` on their typed property while retaining their raw wire value in `extraFields` on record and object types (`Output` types have no `extraFields`; `ATProtoDecoding.strictJSONDecoder()` rejects malformed fields when strict validation is wanted); open unions preserve unknown future `$type` variants via `.unexpected(ATProtocolValueContainer)` for lossless JSON & DAG-CBOR re-encoding. |
| **Recursive Graph Safety** | Recursive schemas (e.g., nested thread replies or embedded records) fail to compile in Swift value types. | Tarjan strongly-connected-component cycle detection (`CycleDetector`) automatically emits `indirect enum` unions and `@Indirect` property boxing only where needed. |
| **Cross-Platform Parity** | Separate iOS and Android model layers drift over time. | One manifest emits both **Swift 6** (`Sources/.../Generated`) and **Kotlin** (`@Serializable data class`, `sealed interface` unions, and `suspend` XRPC client extensions). |

---

## 60-Second Custom Lexicon Overlay Quickstart (`xyz.statusphere.status`)

You do **not** need a checkout of the Petrel repository to build a custom Lexicon overlay package.

### 1. Install `petrel-gen`

Requires Python 3.10+ (`uv` or `pipx` recommended so `petrel-gen` is available globally on your `PATH`):

```bash
# Using uv (recommended)
uv tool install "git+https://github.com/joshlacal/Petrel.git@2.0.0"

# Or using pipx
pipx install "git+https://github.com/joshlacal/Petrel.git@2.0.0"

# Or inside a Python virtual environment
python3 -m venv .venv && .venv/bin/pip install "git+https://github.com/joshlacal/Petrel.git@2.0.0"
```

Verify the installation and bundled reference schemas:

```bash
petrel-gen --version
# petrel-gen 2.0.0

petrel-gen info
# petrel-gen 2.0.0
# Bundled core lexicons: 440 schemas
# Bundled lexicon token: @petrel/core-lexicons
# Core namespace roots:  blue
```

### 2. Scaffold the Overlay Package

Create an empty directory and run `petrel-gen init`:

```bash
mkdir PetrelStatusphere && cd PetrelStatusphere
petrel-gen init --namespace xyz.statusphere --name PetrelStatusphere
```

`petrel-gen init` creates a complete, self-contained Swift 6 + Kotlin overlay layout:

```text
PetrelStatusphere/
├── .gitignore
├── Makefile
├── Package.swift                                        # Pins Petrel with .upToNextMinor(from: "2.0.0")
├── petrel-manifest.json                                 # Overlay manifest using @petrel/core-lexicons
├── lexicons/
│   └── xyz/statusphere/status.json                      # Starter xyz.statusphere.status record schema
├── Sources/
│   └── PetrelStatusphere/
│       └── PetrelStatusphereOverlay.swift               # Hand-written module anchor (never overwritten)
└── kotlin/
    ├── build.gradle.kts                                 # Kotlin JVM + kotlinx.serialization build config
    ├── settings.gradle.kts
    └── src/main/kotlin/blue/catbird/petrel/generated/
```

### 3. Inspect Your Schema (Optional)

Preview how `petrel-gen` maps your Lexicon JSON before writing any files to disk:

```bash
petrel-gen inspect lexicons/xyz/statusphere/status.json
```

```text
Lexicon:         xyz.statusphere.status
Primary Type:    record (key: tid)
Swift Symbol:    XyzStatusphereStatus  ->  Lexicons/Xyz/Statusphere/XyzStatusphereStatus.swift
Kotlin Symbol:   XyzStatusphereStatus  ->  lexicons/xyz/statusphere/XyzStatusphereStatus.kt
Client Path:     client.xyz.statusphere.status
Definitions:     main
Fields:
  - [record] status: string (required)
  - [record] message: string (optional)
  - [record] createdAt: string (datetime) (required)
```

Want to add a custom XRPC query too? Drop `lexicons/xyz/statusphere/getStatuses.json` alongside `status.json`:

```json
{
  "lexicon": 1,
  "id": "xyz.statusphere.getStatuses",
  "defs": {
    "main": {
      "type": "query",
      "description": "Fetch recent status updates indexed by a Statusphere AppView.",
      "parameters": {
        "type": "params",
        "properties": {
          "limit": { "type": "integer", "minimum": 1, "maximum": 100, "default": 25 },
          "cursor": { "type": "string" }
        }
      },
      "output": {
        "encoding": "application/json",
        "schema": {
          "type": "object",
          "required": ["statuses"],
          "properties": {
            "cursor": { "type": "string" },
            "statuses": {
              "type": "array",
              "items": { "type": "ref", "ref": "xyz.statusphere.status" }
            }
          }
        }
      }
    }
  }
}
```

### 4. Generate Swift 6 + Kotlin Overlay Code

```bash
petrel-gen generate --manifest petrel-manifest.json
```

If you have [SwiftFormat 0.61.1](#swiftformat--deterministic-output-rules) installed for Swift builds, format the generated Swift directory using **default** SwiftFormat rules:

```bash
swiftformat Sources/PetrelStatusphere/Generated
```

Your overlay now contains:

- **Swift 6 (`Sources/PetrelStatusphere/Generated/`)**:
  - `Lexicons/Xyz/Statusphere/XyzStatusphereStatus.swift` — `public struct XyzStatusphereStatus: ATProtocolCodable, ATProtocolValue`
  - `Lexicons/Xyz/Statusphere/XyzStatusphereGetStatuses.swift` — `Parameters`, `Output`, and `ATProtoClient.Xyz.Statusphere.getStatuses(input:)`
  - `Client/ATProtoClient+PetrelStatusphere.swift` — extends `ATProtoClient` with `client.xyz.statusphere`
  - `Client/PetrelStatusphereLexicons.swift` — `PetrelStatusphereLexicons.register()` startup hook
- **Kotlin (`kotlin/src/main/kotlin/blue/catbird/petrel/generated/`)**:
  - `lexicons/xyz/statusphere/XyzStatusphereStatus.kt` — `@Serializable data class XyzStatusphereStatus`
  - `lexicons/xyz/statusphere/XyzStatusphereGetStatuses.kt` — `XyzStatusphereGetStatusesParameters`, `XyzStatusphereGetStatusesOutput`, and `suspend fun XyzStatusphereNamespace.getStatuses(...)`
  - `client/PetrelStatusphereNamespaces.kt` — `val ATProtoClient.xyz: XyzNamespace`

---

## Using Your Generated Overlay in Swift 6 & Kotlin

### Registering Overlay Decoders at Startup (Swift)

Core repository endpoints such as `com.atproto.repo.getRecord` and `com.atproto.repo.listRecords` return heterogeneous records inside `ATProtocolValueContainer`. Call `<PackageName>Lexicons.register()` **once at application startup** so Petrel decodes your custom `$type` payloads into strongly typed Swift structs instead of `.unknownType`:

```swift
import Foundation
import Petrel
import PetrelStatusphere

// 1. Register custom overlay decoders once during app launch:
PetrelStatusphereLexicons.register()

// 2. Write a typed xyz.statusphere.status record to an authenticated PDS:
func publishStatus(client: ATProtoClient, userDID: DID) async throws {
    let statusRecord = XyzStatusphereStatus(
        status: "🚀",
        message: "Shipping custom ATmosphere lexicons with Petrel 2.0",
        createdAt: ATProtocolDate(date: Date())
    )

    let input = ComAtprotoRepoCreateRecord.Input(
        repo: .did(userDID),
        collection: try NSID(nsidString: XyzStatusphereStatus.typeIdentifier),
        record: .knownType(statusRecord)
    )

    let (responseCode, created) = try await client.com.atproto.repo.createRecord(input: input)
    if responseCode == 200, let created {
        print("Published status at \(created.uri)")
    }
}

// 3. Read back a custom record and pattern-match the registered type:
func readStatus(client: ATProtoClient, userDID: DID, rkey: RecordKey) async throws {
    let params = ComAtprotoRepoGetRecord.Parameters(
        repo: .did(userDID),
        collection: try NSID(nsidString: XyzStatusphereStatus.typeIdentifier),
        rkey: rkey
    )
    let (code, output) = try await client.com.atproto.repo.getRecord(input: params)
    if code == 200,
       case .knownType(let value) = output?.value,
       let status = value as? XyzStatusphereStatus
    {
        print("Current status: \(status.status) — \(status.message ?? "")")
    }
}
```

If your overlay also defines XRPC queries or procedures (like `xyz.statusphere.getStatuses`), they attach directly onto `ATProtoClient`:

```swift
let (code, data) = try await client.xyz.statusphere.getStatuses(
    input: .init(limit: 25)
)
```

### Calling Your Overlay from Kotlin

```kotlin
import blue.catbird.petrel.client.ATProtoClient
import blue.catbird.petrel.core.types.ATProtocolDate
import blue.catbird.petrel.generated.*
import java.time.Instant

val record = XyzStatusphereStatus(
    status = "🚀",
    message = "Shared Lexicon schema across Swift 6 and Kotlin",
    createdAt = ATProtocolDate(Instant.now().toString())
)

// Custom XRPC queries attach via generated extension properties on ATProtoClient:
val response = client.xyz.statusphere.getStatuses(
    XyzStatusphereGetStatusesParameters(limit = 25)
)
```

---

## `petrel-gen` CLI Reference

### `petrel-gen init`

Scaffolds a new overlay project with `petrel-manifest.json`, `Package.swift`, Kotlin Gradle config, `Makefile`, and a starter Lexicon schema.

```bash
petrel-gen init --namespace <nsid-prefix> [options]
```

| Option | Default | Description |
|---|---|---|
| `--namespace <prefix>` | *(required)* | Dotted NSID prefix (minimum 2 segments, e.g. `xyz.statusphere`, `blue.myorg`). |
| `--name <PackageName>` | Derived from `--namespace` | Swift target/product name & registration prefix (e.g. `PetrelStatusphere`). |
| `--dir <path>` | `.` | Directory to scaffold into (created if absent). |
| `--sample-record <leaf>` | `status` | Starter record schema leaf (`<namespace>.<leaf>`). |
| `--no-sample` | `false` | Create an empty `lexicons/` directory with no starter `.json` file. |
| `--petrel-version <ver>` | `2.0.0` | Baseline version emitted in `.upToNextMinor(from: "<ver>")`. |
| `--petrel-path <path>` | *(none)* | Emit `.package(path: "<path>")` in `Package.swift` for local monorepo testing. |
| `--force` | `false` | Overwrite existing scaffold files if already present. |

### `petrel-gen generate`

Compiles all Lexicon JSON schemas in `lexicons.emit` according to a manifest.

```bash
petrel-gen generate [--manifest petrel-manifest.json] [--language {swift,kotlin,both}] [--stdout | --check] [--no-format]
```

| Option | Default | Description |
|---|---|---|
| `--manifest <file>` | `petrel-manifest.json` | Path to the JSON generation manifest. |
| `--language <lang>` | `both` | Limit emission to `swift`, `kotlin`, or `both` (for languages configured in the manifest). |
| `--stdout` | `false` | Render all generated Swift/Kotlin files to `stdout` without touching disk. |
| `--check` | `false` | Verify generated directories on disk match current schemas byte-for-byte after formatting staged Swift output with pinned SwiftFormat `0.61.1` (exits `1` in CI if stale). |
| `--no-format` | `false` | Skip running pinned SwiftFormat `0.61.1` on generated or `--check`-staged Swift outputs. |

### `petrel-gen inspect`

Validates a single Lexicon `.json` file (or `-` from `stdin`) against bundled core ATProto schemas and previews generated code or metadata.

```bash
# Human-readable summary card
petrel-gen inspect lexicons/xyz/statusphere/status.json

# Emit pure Swift 6 overlay code to stdout
petrel-gen inspect lexicons/xyz/statusphere/status.json --language swift --overlay

# Emit pure Kotlin overlay code to stdout
petrel-gen inspect lexicons/xyz/statusphere/status.json --language kotlin --overlay

# Emit structured JSON metadata for scripts/tooling
petrel-gen inspect lexicons/xyz/statusphere/status.json --json
```

### `petrel-gen info`

Prints `petrel-gen` version, the filesystem path to the 440 bundled core lexicons, and core-owned namespace roots (`--json` supported).

> **Backwards Compatibility (`run.py`)**: Inside the Petrel repository itself, `python3 run.py --manifest generator/manifests/petrel-core.json` and `python3 generator/main.py ...` remain 100% supported and unchanged.

---

## Xcode & SwiftPM Command Plugins (`PetrelCodegenPlugin` & `PetrelLexgen`)

Petrel ships two Swift Package Manager command plugins so Swift developers can regenerate overlay code directly through `swift package` or Xcode:

- **`PetrelCodegenPlugin` (`petrel-codegen`)**: Zero-network wrapper around `petrel-gen` (resolving `PETREL_GEN`, `petrel-gen` on `PATH`, or a pre-provisioned `PETREL_PYTHON` environment) for Swift 6 + Kotlin overlays (`petrel-manifest.json`).
- **`PetrelLexgen` (`petrel-lexgen`)**: Self-bootstrapping Swift-focused plugin (`lexgen.json` by default) that provisions its own isolated Python virtual environment inside SwiftPM's plugin work directory on first run (`--allow-network-connections all:443`).

### Terminal Usage

From any package directory that depends on `Petrel` and contains a `petrel-manifest.json`:

```bash
# Generate all outputs configured in petrel-manifest.json
swift package plugin --allow-writing-to-package-directory petrel-codegen

# Forward flags to petrel-gen (e.g., Swift-only or CI drift check)
swift package plugin --allow-writing-to-package-directory petrel-codegen -- --language swift
swift package plugin --allow-writing-to-package-directory petrel-codegen -- --check
```

### Xcode Integration

1. Open your overlay package or Xcode project that depends on `Petrel`.
2. Right-click your package in Xcode's **Project Navigator**.
3. Select **PetrelCodegenPlugin** (`petrel-codegen`).
4. Click **Allow Command to Change Files** when prompted.

`PetrelCodegenPlugin` resolves the generator runtime in this order:
1. `PETREL_GEN` environment variable (if set to an executable path).
2. `petrel-gen` on `PATH` (e.g., installed via `uv tool install` or `pipx`).
3. `PETREL_PYTHON` or `python3` invoking the `generator/cli.py` bundled inside SwiftPM's `Petrel` package checkout (when `jinja2`, `aiofiles`, and `orjson` are installed).

### `Makefile` & CI Gate

Every package scaffolded by `petrel-gen init` also includes a zero-config `Makefile`:

```makefile
make generate       # Runs petrel-gen generate --manifest petrel-manifest.json
make format-swift   # Formats Sources/<Package>/Generated with default SwiftFormat
make check          # Fails CI if generated outputs are out of sync with lexicons/
```

---

## Complete `petrel-manifest.json` Reference

### Overlay Manifest Example (`kind: "overlay"`)

Used by external apps and domain packages (such as `PetrelStatusphere` or `PetrelNotes`):

```json
{
  "$comment": "Overlay manifest for PetrelStatusphere (xyz.statusphere.*).",
  "package": {
    "kind": "overlay",
    "name": "PetrelStatusphere",
    "core_namespace_roots": ["blue"]
  },
  "lexicons": {
    "emit": ["lexicons"],
    "reference": ["@petrel/core-lexicons"],
    "exclude_namespaces": ["tools.ozone"]
  },
  "swift": {
    "output": "Sources/PetrelStatusphere/Generated",
    "emit_server_contracts": false,
    "emit_xrpc_error_parsing": false
  },
  "kotlin": {
    "output": "kotlin/src/main/kotlin/blue/catbird/petrel/generated"
  }
}
```

### Core Manifest Example (`kind: "core"`)

Used only by `Petrel` itself (`generator/manifests/petrel-core.json`):

```json
{
  "package": {
    "kind": "core",
    "name": "Petrel",
    "core_namespace_roots": ["blue"]
  },
  "lexicons": {
    "emit": ["generator/lexicons"],
    "reference": [],
    "exclude_namespaces": ["tools.ozone", "internal.bsky"]
  },
  "swift": {
    "output": "Sources/Petrel/Generated",
    "emit_server_contracts": [
      "com.atproto.space",
      "com.atproto.memberspace",
      "com.atproto.managedspace",
      "com.atproto.personalspace"
    ],
    "emit_xrpc_error_parsing": [
      "com.atproto.space",
      "com.atproto.memberspace",
      "com.atproto.managedspace",
      "com.atproto.personalspace"
    ]
  },
  "kotlin": {
    "output": "kotlin/src/main/kotlin/blue/catbird/petrel/generated"
  }
}
```

### Manifest Schema Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `package.kind` | `"core" \| "overlay" \| "app-intents"` | Yes | **`"core"`** emits the root `ATProtoClient+Generated.swift`, `ATProtocolValueContainer.swift`, and `ATProtoClientGenerated.kt`. **`"overlay"`** emits a separate module that imports `Petrel`, extends `ATProtoClient` namespaces without redeclaring core nodes, and generates `<Name>Lexicons.register()`. **`"app-intents"`** runs the curated Apple `AppIntents` generator (Swift-only). |
| `package.name` | `string` | Yes | UpperCamelCase module name (e.g. `"PetrelStatusphere"`). Controls generated filenames (`ATProtoClient+<Name>.swift`, `<Name>Lexicons.swift`, `<Name>Namespaces.kt`) and registration enum symbol. |
| `package.core_namespace_roots` | `string[]` | Optional | Lowercase Swift-safe single-segment namespace roots owned by `Petrel` core even when core emits no lexicons under them (currently `["blue"]`). Ensures multiple independent overlays (`blue.notes.*`, `blue.moji.*`) emit `public extension ATProtoClient.Blue` rather than colliding `public struct Blue` declarations. When using `petrel-gen generate`, overlays automatically inherit bundled core roots (`["blue"]`) even if omitted. |
| `lexicons.emit` | `string[]` | Yes | Directories recursively scanned for `.json` Lexicon schemas whose Swift/Kotlin code will be written to `output`. |
| `lexicons.reference` | `string[]` | Required for `"overlay"` | Directories of `.json` Lexicon schemas loaded for cross-package `ref` resolution, cycle detection, and knowing which `ATProtoClient` namespaces already exist in `Petrel` (`app`, `chat`, `com`, `site`). Pass **`"@petrel/core-lexicons"`** (aliases: `"petrel:core-lexicons"`, `"@bundled"`) to use the 440 core schemas bundled inside `petrel-gen` with zero local Petrel checkout. If a lexicon ID exists in both `emit` and `reference`, `emit` shadows `reference`. |
| `lexicons.exclude_namespaces` | `string[]` | Optional | NSID prefixes skipped during both `emit` and `reference` loading (e.g. `["tools.ozone", "internal.bsky"]`). |
| `swift` | `object` | Optional | Omit if generating Kotlin only; include to configure Swift 6 output. |
| `swift.output` | `string` | If `swift` set | Target directory for generated Swift files. Managed as an atomic projection: stale files carrying the exact `// Generated by Petrel. DO NOT EDIT.` header are cleaned up automatically, while hand-written files are never deleted. |
| `swift.emit_server_contracts` | `bool \| string[]` | Optional (`false`) | When `true` (or matching an NSID prefix list), emits server-side XRPC handler contracts (`public static let endpointDescriptor` and `public protocol ServerHandler` with `func handle(parameters:input:) async throws -> Output`) and upgrades input-reachable optional fields from client-lenient `decodeIfPresent` to strict presence-aware server decoding (rejecting malformed values and invalid `null`s). |
| `swift.emit_xrpc_error_parsing` | `bool \| string[]` | Optional (`false`) | Endpoints that declare an `errors` array in their Lexicon *always* emit a typed `Error` enum and parse non-2xx payloads via `ATProtoErrorParser.parse(...)`. Enabling `emit_xrpc_error_parsing` (`true` or NSID prefixes) opts endpoints **without** declared Lexicon `errors` into `performRequestReturningHTTPErrorResponses` + `ATProtoErrorParser.parseGeneric(...)` so generic XRPC `{ error, message }` payloads are thrown as typed errors rather than returning `(responseCode, nil)`. |
| `kotlin` | `object` | Optional | Omit if generating Swift only; include to configure Kotlin output. |
| `kotlin.output` | `string` | If `kotlin` set | Target directory for generated Kotlin `@Serializable` models and `*Namespaces.kt` client extensions (`// Generated by Petrel (Kotlin). DO NOT EDIT.`). |

---

## SwiftFormat & Deterministic Output Rules

Petrel enforces a **byte-stable round-trip invariant**: regenerating from unchanged Lexicon schemas and formatting must produce an empty `jj diff` / `git diff`.

### Pinned Version: SwiftFormat `0.61.1`

CI pins [`nicklockwood/SwiftFormat@0.61.1`](https://github.com/nicklockwood/SwiftFormat/releases/tag/0.61.1). Newer or older SwiftFormat versions may wrap multiline initializers or enum cases differently and create spurious diffs.

### Critical Distinction: Core vs Overlay Formatting

| Target | Formatter Command | Why |
|---|---|---|
| **Petrel Core** (`Sources/Petrel/Generated`) | `swiftformat Sources/Petrel/Generated` *(inside Petrel repo)* | Automatically reads `Petrel/.swiftformat` (`--indent 4 --tabwidth 4 --wraparguments before-first --wrapcollections before-first`). |
| **Overlay Packages** (`Sources/<Overlay>/Generated`) | `swiftformat Sources/<Overlay>/Generated` *(inside overlay repo, **no** `.swiftformat`)* | Overlay packages intentionally use **default SwiftFormat rules**. **Never** pass `--config ../Petrel/.swiftformat` when formatting an overlay package — doing so rewraps enum associated-value tuples and leaves files permanently dirty across regenerations. |
| **Kotlin Output** (`kotlin/.../generated`) | **None** *(do not run `ktlint` or `spotless`)* | `KotlinCodeGenerator` emits finalized, deterministic Kotlin source directly from its Jinja2 templates (`test_kotlin_strict_ref_byte_stability.py`). |

---

## Versioning Contract (`.upToNextMinor`) & Release Train

Downstream applications and overlay packages **must** consume Petrel using `.upToNextMinor(from:)`:

```swift
dependencies: [
    .package(
        url: "https://github.com/joshlacal/Petrel.git",
        .upToNextMinor(from: "2.0.0")
    ),
]
```

### Why the Minor Version Is the API Compatibility Boundary

In schema-generated Swift SDKs, **every Lexicon regeneration requires a minor version bump** — even when upstream AT Protocol schema changes appear purely additive:

1. **Swift memberwise initializers**: Adding a new optional property to a Lexicon object adds a parameter to the generated `public init(...)`, changing its source signature for positional or full-initializer callers.
2. **Semantic type tightening**: Upstream schemas periodically refine raw `string` fields by adding `"format": "tid"`, `"format": "at-identifier"`, or `"knownValues"`, tightening the Swift property type from `String` to `TID`, `ATIdentifier`, or a typed enum.
3. **Optionality refinements**: Tightening or relaxing `required` arrays alters Swift optionality (`T` vs `T?`).

Pinning with `.upToNextMinor(from: "2.0.0")` allows automatic uptake of bug-fix patch releases (`2.0.x`) while guaranteeing `swift package update` never pulls a source-changing Lexicon regeneration (`2.1.0`) until your overlay or app explicitly opts in.

| Change Scope | Version Bump | Example |
|---|---|---|
| Bug fix in networking, auth, or runtime with **zero** changes to public declarations | **Patch** | `2.0.0` → `2.0.1` |
| **Any Lexicon regeneration**, new generated endpoints/fields, or allowlisted API evolution | **Minor** | `2.0.1` → `2.1.0` |
| Deliberate architectural redesign or breaking rewrite of hand-written core APIs | **Major** | `2.1.0` → `3.0.0` |

### Multi-Package Release Train

When shipping a Lexicon or SDK update across `Petrel`, one or more overlay packages (such as `PetrelStatusphere` or `PetrelNotes`), and a host application:

1. **Regenerate & Tag `Petrel`**: Run core codegen + `swiftformat Sources/Petrel/Generated`, verify all tests pass, and tag the new minor release (e.g. `2.1.0`).
2. **Update & Tag Overlay Packages**: Bump `.upToNextMinor(from: "2.1.0")` in each overlay's `Package.swift`, run `petrel-gen generate --manifest petrel-manifest.json`, format with default `swiftformat`, and tag a matching release.
3. **Resolve in Host Applications**: Update `Package.resolved` in your iOS/macOS/Linux host apps so the core SDK and all overlays resolve to the same `Petrel` minor line.
