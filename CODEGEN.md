# Lexicon code generation (`petrel-gen`)

`petrel-gen` compiles AT Protocol Lexicon JSON schemas into Swift 6 and Kotlin code. Petrel
uses it for its own generated API, and you can use it to build an overlay package: a separate
module that adds types and client methods for your own namespace (for example
`xyz.statusphere.*`) on top of `Petrel`. You do not need a checkout of the Petrel repository;
the core Lexicons are bundled with the tool.

## Install

Requires Python 3.10 or later.

```bash
uv tool install "git+https://github.com/joshlacal/Petrel.git@2.0.0"
# or
pipx install "git+https://github.com/joshlacal/Petrel.git@2.0.0"

petrel-gen --version
petrel-gen info
```

## Quick start

```bash
mkdir PetrelStatusphere && cd PetrelStatusphere
petrel-gen init --namespace xyz.statusphere --name PetrelStatusphere
petrel-gen inspect lexicons/xyz/statusphere/status.json
petrel-gen generate --manifest petrel-manifest.json
swiftformat Sources/PetrelStatusphere/Generated
```

`init` creates `Package.swift`, `petrel-manifest.json`, a `Makefile`, a starter schema at
`lexicons/xyz/statusphere/status.json`, a hand-written module file under
`Sources/PetrelStatusphere/` (never overwritten), and a Kotlin Gradle project under `kotlin/`.
Add more schemas under `lexicons/` and run `generate` again.

`generate` writes Swift to `Sources/PetrelStatusphere/Generated/` (one file per Lexicon, an
`ATProtoClient` extension that adds `client.xyz.statusphere`, and a
`PetrelStatusphereLexicons.register()` function) and Kotlin to the configured Kotlin output.

## Using an overlay

Call `register()` once at startup so records returned inside `ATProtocolValueContainer`
(for example from `com.atproto.repo.getRecord`) decode to your types:

```swift
import Petrel
import PetrelStatusphere

PetrelStatusphereLexicons.register()

func readStatus(client: ATProtoClient, userDID: DID, rkey: RecordKey) async throws {
    let (code, output) = try await client.com.atproto.repo.getRecord(
        input: .init(
            repo: .did(userDID),
            collection: try NSID(nsidString: XyzStatusphereStatus.typeIdentifier),
            rkey: rkey
        )
    )
    if code == 200, case .knownType(let value) = output?.value,
       let status = value as? XyzStatusphereStatus {
        print(status.status)
    }
}
```

Queries and procedures in your namespace appear on the client, for example
`client.xyz.statusphere.getStatuses(input:)`. The
[StatusphereOverlay](Examples/StatusphereOverlay/README.md) example is a complete package.

## CLI reference

### `petrel-gen init`

Scaffolds an overlay package.

| Option | Default | Description |
| :-- | :-- | :-- |
| `--namespace <prefix>` | required | NSID prefix, at least two segments (`xyz.statusphere`). |
| `--name <Name>` | derived from `--namespace` | Swift module name and registration prefix. |
| `--dir <path>` | `.` | Directory to scaffold into. |
| `--sample-record <leaf>` | `status` | Leaf name of the starter record schema. |
| `--no-sample` | | Create an empty `lexicons/` directory. |
| `--petrel-version <ver>` | `2.0.0` | Version used in `.upToNextMinor(from:)`. |
| `--petrel-path <path>` | | Depend on a local Petrel checkout with `.package(path:)`. |
| `--force` | | Overwrite existing scaffold files. |

### `petrel-gen generate`

Generates code for every schema in the manifest's `lexicons.emit`.

| Option | Default | Description |
| :-- | :-- | :-- |
| `--manifest <file>` | `petrel-manifest.json` | Manifest path. |
| `--language {swift,kotlin,both}` | `both` | Languages to emit (of those configured in the manifest). |
| `--stdout` | | Print generated files instead of writing them. |
| `--check` | | Exit non-zero if files on disk differ from what would be generated. Does not write. |
| `--no-format` | | Skip formatting Swift output with the pinned SwiftFormat. |

`--stdout` and `--check` are mutually exclusive.

### `petrel-gen inspect <file>`

Validates one Lexicon file (`-` reads stdin) and previews the result.

| Option | Description |
| :-- | :-- |
| `--language {summary,swift,kotlin,both}` | Output mode. Default: summary. |
| `--stdout` | Print generated code (Swift and Kotlin unless `--language` is set). |
| `--overlay` | Render code as an overlay would (`import Petrel`). |
| `--json` | Print inspection metadata as JSON. |
| `--no-core-refs` | Do not load the bundled core Lexicons for `ref` resolution. |

### `petrel-gen info`

Prints the version, the path to the bundled core Lexicons and the core namespace roots.
`--json` prints the same as JSON.

Inside the Petrel repository, `python3 run.py --manifest generator/manifests/petrel-core.json`
still works.

## SwiftPM plugins

- `PetrelCodegenPlugin` (verb `petrel-codegen`) runs `petrel-gen` with `petrel-manifest.json`.
  It looks for the generator in this order: the `PETREL_GEN` environment variable,
  `petrel-gen` on `PATH`, then `PETREL_PYTHON` or `python3` running the generator in the
  Petrel package checkout (needs `jinja2`, `aiofiles` and `orjson`). Arguments after `--` are
  passed to `petrel-gen generate`.
- `PetrelLexgen` (verb `petrel-lexgen`) reads `lexgen.json` by default and installs its own
  Python environment in the plugin work directory on first run, so it needs network access.
  Options: `--manifest <path>`, `--python <path>`, `--verbose`.

```bash
swift package plugin --allow-writing-to-package-directory petrel-codegen
swift package plugin --allow-writing-to-package-directory petrel-codegen -- --check

swift package --allow-writing-to-package-directory --allow-network-connections all:443 \
    petrel-lexgen
```

In Xcode, right-click the package in the Project Navigator and choose the plugin.

The scaffolded `Makefile` has `generate`, `format-swift` and `check` targets.

## Manifest reference

Overlay manifest written by `init`:

```json
{
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

Petrel's own manifest is `generator/manifests/petrel-core.json` (`kind: "core"`).

| Field | Type | Description |
| :-- | :-- | :-- |
| `package.kind` | `"core"`, `"overlay"`, `"app-intents"` | `core` emits the root client and value container. `overlay` emits a module that imports `Petrel`, extends existing namespaces and generates `<Name>Lexicons.register()`. `app-intents` runs the Swift-only App Intents generator. |
| `package.name` | string | Module name; used in generated file names and the registration type. |
| `package.core_namespace_roots` | string[] | Single-segment roots that `Petrel` owns even without emitting Lexicons under them, so overlays extend them instead of redeclaring them. Overlays inherit the bundled roots when omitted. |
| `lexicons.emit` | string[] | Directories scanned for schemas to generate. |
| `lexicons.reference` | string[] | Schemas loaded for `ref` resolution only. Required for overlays. `@petrel/core-lexicons` (also `petrel:core-lexicons`, `@bundled`) means the bundled core set. `emit` wins over `reference` for the same ID. |
| `lexicons.exclude_namespaces` | string[] | NSID prefixes to skip. |
| `swift.output` | string | Swift output directory. Stale files with the generated header are removed; other files are left alone. |
| `swift.emit_server_contracts` | bool or string[] | Emit server handler protocols and strict input decoding, for all endpoints or those under the listed prefixes. Default `false`. |
| `swift.emit_xrpc_error_parsing` | bool or string[] | Parse generic XRPC error bodies into thrown errors for endpoints that declare no `errors`. Endpoints that declare `errors` always get a typed error enum. Default `false`. |
| `kotlin.output` | string | Kotlin output directory. |

Omit `swift` or `kotlin` to generate only the other language.

## Formatting

Generation is deterministic: regenerating unchanged schemas and formatting must produce no
diff. CI pins SwiftFormat 0.61.1; other versions can wrap differently.

- Petrel core: `swiftformat Sources/Petrel/Generated`, which picks up Petrel's `.swiftformat`.
- Overlays: `swiftformat Sources/<Name>/Generated` with default rules. Do not pass Petrel's
  `.swiftformat`; it rewraps output and leaves files dirty after every regeneration.
- Kotlin: do not reformat. The generator's output is final.

## Versioning

Depend on Petrel with `.upToNextMinor(from: "2.0.0")`. Every Lexicon regeneration is a minor
release, because added optional fields change generated initializers, and tightened formats
or `required` lists change property types and optionality. Patch releases contain no public
declaration changes.

When releasing across Petrel, overlays and an app: tag the new Petrel minor release, bump
each overlay's `.upToNextMinor(from:)`, regenerate, format and tag it, then update the app's
`Package.resolved` so everything resolves to the same Petrel minor line.
