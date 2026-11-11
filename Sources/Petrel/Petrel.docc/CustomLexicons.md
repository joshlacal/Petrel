# Generating Code for Your Own Lexicons

Turn Lexicon JSON files into the same typed Swift API Petrel ships for
`com.atproto` and `app.bsky`.

## Overview

Petrel's generator is not limited to the Lexicons bundled with it. Point it at a
directory of Lexicon files and it writes, into your package:

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
- `swift.output` is where the sources go. The directory is owned by the
  generator: files it did not write are removed.

All paths are relative to the package directory.

## Run the generator

Petrel ships the generator as a SwiftPM command plugin. From your package:

```sh
swift package --allow-writing-to-package-directory --allow-network-connections all:443 \
    petrel-lexgen --manifest lexgen.json
```

The plugin needs Python 3 on `PATH` (or `--python <path>`). On first use it
installs the generator's three Python dependencies into its own work directory,
which is what the network permission is for; later runs need no network.

Without the plugin, run the generator from a Petrel checkout:

```sh
python3 -m pip install -r /path/to/Petrel/generator/requirements.txt
cd /path/to/YourPackage
python3 /path/to/Petrel/run.py --manifest lexgen.json --language swift
```

Commit the generated sources. Regenerate when a Lexicon changes; the output is
deterministic, so the diff shows exactly what changed.

## Use the generated API

```swift
import Petrel

// Once, at startup: lets Pins types decode inside untyped data such as the
// `value` of com.atproto.repo.getRecord.
PinsLexicons.register()

let (_, output) = try await client.com.example.pins.listPins(
    input: .init(actor: ATIdentifier(string: "alice.example.com"), limit: 10)
)
let notes = output?.pins.compactMap(\.record.note) ?? []

do {
    _ = try await client.com.example.pins.listPins(input: parameters)
} catch let error as ATProtoError<ComExamplePinsListPins.Error> {
    // .actorNotFound, as declared in the Lexicon
}
```

Calls behave exactly like Petrel's own; see <doc:XRPCClient>.

## What the generator supports

Every part of Lexicon version 1:

| Lexicon | Swift |
|---|---|
| `record` | struct with `typeIdentifier` and `recordKeyType`; writes `$type` |
| `object` (named or inline) | struct; inline objects become nested structs |
| `query`, `procedure` | async method; `Parameters`, `Input`, `Output`, `Error` |
| `subscription` | method returning `AsyncThrowingStream<Message, Error>` |
| `permission-set` | `permissionSet` constant with `includeScope(audience:)` |
| `token` | string constant holding `nsid#name` |
| `union` | enum; open unions add `.unexpected`, closed unions do not |
| `ref` | the referenced type, across Lexicons and into `petrel:core` |
| `string` | `String`, or a typed value for each `format` (`DID`, `Handle`, `ATProtocolURI`, `CIDString`, `ATProtocolDate`, …); `enum` and named `knownValues` become types |
| `integer`, `boolean`, `bytes`, `cid-link`, `blob`, `unknown`, `array` | `Int`, `Bool`, `Bytes`, `ATProtoLink`, `Blob`, `ATProtocolValueContainer`, `[T]` |
| `required`, `nullable` | non-optional, optional, and `ATProtoNullable<T>?` for optional and nullable |

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
