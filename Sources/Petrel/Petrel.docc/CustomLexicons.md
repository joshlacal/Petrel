# Generating Code for Your Own Lexicons

Turn Lexicon JSON files into the same typed Swift API Petrel ships for
`com.atproto` and `app.bsky`.

## Overview

Point Petrel's generator at a directory of Lexicon files and it writes, into
your package:

- a Swift type for every record and object, with JSON and DAG-CBOR coding;
- a method on ``ATProtoClient`` for every query, procedure and subscription,
  under the NSID's namespace (`client.com.example.pins.listPins`);
- typed error enums, token constants, permission sets, and a registration call
  that lets your types decode inside Petrel's untyped values.

The generated code lives in your module and imports `Petrel`; nothing in Petrel
is regenerated or replaced.

## Write a manifest

Put your Lexicons in the package and describe the run in `lexgen.json`:

```json
{
  "package": { "kind": "overlay", "name": "Pins" },
  "lexicons": { "emit": ["lexicons"], "reference": ["petrel:core"] },
  "swift": { "output": "Sources/Pins/Generated" }
}
```

- `package.kind` is `overlay`: generate on top of Petrel instead of generating
  Petrel itself. `package.name` names the registration type (`PinsLexicons`).
- `lexicons.emit` lists the directories to generate code for.
- `lexicons.reference` lists Lexicons to resolve refs against without
  generating them. `petrel:core` is the set bundled with Petrel, so
  `{"type": "ref", "ref": "com.atproto.repo.strongRef"}` resolves to Petrel's
  `ComAtprotoRepoStrongRef`.
- `swift.output` is where the sources go. On each run the generator deletes
  the Swift files there that carry its generated-file header but that it no
  longer writes; other files are left alone.

All paths are relative to the package directory.

## Run the generator

Petrel ships the generator as the SwiftPM command plugin `PetrelLexgen`.
From a package that depends on Petrel:

```sh
swift package --allow-writing-to-package-directory --allow-network-connections all:443 \
    petrel-lexgen --manifest lexgen.json
```

`--manifest` defaults to `lexgen.json`; `--verbose` prints the generator's
output. The plugin needs Python 3 on `PATH` (or `--python <path>`). On first use
it creates a virtual environment in its own work directory and installs the
generator's three Python dependencies (jinja2, aiofiles, orjson) into it, which
is what the network permission is for; later runs need no network.

Without the plugin, run the generator from a Petrel checkout:

```sh
python3 -m pip install -r /path/to/Petrel/generator/requirements.txt
cd /path/to/YourPackage
python3 /path/to/Petrel/run.py --manifest lexgen.json --language swift
```

Commit the generated sources. Regenerate when a Lexicon changes; the output is
deterministic, so the diff shows exactly what changed.

### Other ways to run it

- `petrel-gen` is the same generator as a standalone command, with the core
  Lexicons bundled, so it needs no Petrel checkout. Install it with
  `pipx install "git+https://github.com/joshlacal/Petrel.git@2.0.0"`.
  `petrel-gen init --namespace com.example.pins --name Pins` scaffolds a
  package with a `petrel-manifest.json`, and
  `petrel-gen generate --manifest petrel-manifest.json --language swift` runs
  it. `--language` is `swift`, `kotlin` or `both`; Kotlin also needs a
  `"kotlin": {"output": …}` entry in the manifest. `--check` verifies that the
  sources on disk are current without writing anything.
- The `PetrelCodegenPlugin` command plugin runs an installed `petrel-gen`:
  `swift package --allow-writing-to-package-directory petrel-codegen`. Its
  manifest defaults to `petrel-manifest.json`.

## Depend on Petrel

The generated sources go in a target of your own that depends on `Petrel`:

<!-- compile-example: overlay-package-manifest -->
```swift
// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PetrelStatusphere",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "PetrelStatusphere",
            targets: ["PetrelStatusphere"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/joshlacal/Petrel.git",
            .upToNextMinor(from: "2.0.0")
        ),
    ],
    targets: [
        .target(
            name: "PetrelStatusphere",
            dependencies: [
                .product(name: "Petrel", package: "Petrel"),
            ]
        ),
    ]
)
```

## Use the generated API

For example, the `PetrelOzone` product (`tools.ozone.*`, generated from `generator/manifests/petrel-ozone.json`) registers its decoders once at startup and exposes typed namespaces and errors directly on `ATProtoClient`:

<!-- compile-example: custom-lexicons-overlay-usage -->
```swift
import Petrel
import PetrelOzone

func inspectOzoneEvent(
    client: ATProtoClient,
    templateInput: ToolsOzoneCommunicationCreateTemplate.Input
) async throws {
    // Once, at startup: lets overlay types decode inside untyped data such as
    // the `value` of com.atproto.repo.getRecord.
    PetrelOzoneLexicons.register()

    let (_, event) = try await client.tools.ozone.moderation.getEvent(
        input: .init(id: 42)
    )
    _ = event?.createdBy

    do {
        _ = try await client.tools.ozone.communication.createTemplate(input: templateInput)
    } catch let error as ATProtoError<ToolsOzoneCommunicationCreateTemplate.Error> {
        switch error.error {
        case .duplicateTemplateName:
            break
        }
    }
}
```

Calls behave exactly like Petrel's own; see <doc:XRPCClient>.

### Register your record types

`register()` calls ``ATProtocolValueContainer/registerDecoder(forType:as:)`` for
each generated type. Until a `$type` is registered, a value of that type inside
untyped data stays untyped: the `value` of `getRecord`, or a record from
`PetrelJetstream` or `PetrelFirehose`. After registration, `decoded(_:)` returns
your struct. The example registers one hand-written type the same way:

<!-- compile-example: overlay-dynamic-decoding -->
```swift
import Foundation
import Petrel

struct DemoCustomStatus: ATProtocolCodable, ATProtocolValue {
    static let typeIdentifier = "xyz.statusphere.demoStatus"
    let status: String
    let createdAt: ATProtocolDate

    func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }

    func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map = map.adding(key: "$type", value: Self.typeIdentifier)
        map = map.adding(key: "status", value: status)
        map = map.adding(key: "createdAt", value: try createdAt.toCBORValue())
        return map
    }
}

func decodeCustomRecordFromWireJSON() throws -> DemoCustomStatus? {
    // Generated overlays call this for every custom record in `<Overlay>Lexicons.register()`:
    ATProtocolValueContainer.registerDecoder(
        forType: DemoCustomStatus.typeIdentifier,
        as: DemoCustomStatus.self
    )

    let wireJSON = Data("""
    {
      "$type": "xyz.statusphere.demoStatus",
      "status": "✨",
      "createdAt": "2026-11-12T10:30:00.000Z"
    }
    """.utf8)

    let container = try JSONCoders.decode(ATProtocolValueContainer.self, from: wireJSON)
    return container.decoded(DemoCustomStatus.self)
}
```

### Request scopes for your collections

Ask for the collections and endpoints you use instead of `transition:generic`
(see <doc:OAuthClient>):

<!-- compile-example: overlay-oauth-scopes -->
```swift
import Petrel

func buildStatusphereOAuthConfig() throws -> OAuthConfig {
    let scopes = try ATProtoScopeSet([
        .atproto,
        .repo(collections: ["xyz.statusphere.status"], actions: [.create, .update, .delete]),
        .rpc(
            lxm: ["xyz.statusphere.getStatuses"],
            aud: "did:web:api.statusphere.example#statusphere_appview"
        ),
    ])

    return OAuthConfig(
        clientId: "https://statusphere.example/oauth-client-metadata.json",
        redirectUri: "example.statusphere:/oauth/callback",
        scopes: scopes
    )
}
```

## What the generator supports

The generator handles every part of Lexicon version 1. <doc:LexiconTypesInSwift>
lists the Swift type for each construct.

NSIDs of any length map to nested namespaces
(`fm.example.alpha.feed.getPlay` is `client.fm.example.alpha.feed.getPlay`).
Names that are not Swift identifiers are adapted and keep their wire spelling:
`com.my-site` is `client.com.mySite`, a property `created-at` is `createdAt`.

Value constraints (`maxLength`, `maxGraphemes`, `minimum`, integer `enum`,
`const`, blob `accept` and `maxSize`) are not part of the Swift types. Add
`"lexicon_documents": {"output": "Sources/Pins/Schemas", "type": "PinsLexiconDocuments", "access": "public"}`
under `swift` to also emit your Lexicons as JSON constants, and load them into a
`LexiconCatalog` from the `PetrelLexicon` product to validate data against them.

## A complete, tested example

The Petrel repository builds and tests a module generated this way on every CI
run: `Tests/LexiconFixture` holds the Lexicons (including the official interop
catalog), the manifest and the generated sources, and
`Tests/PetrelLexiconFixtureTests` exercises them. The `PetrelOzone` product
(`tools.ozone.*`) is generated the same way, from
`generator/manifests/petrel-ozone.json`.

[`Examples/StatusphereOverlay`](https://github.com/joshlacal/Petrel/tree/main/Examples/StatusphereOverlay)
is a smaller package to copy from: one record, one query and a command-line demo.
