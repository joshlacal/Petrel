# Custom Lexicons and Overlay Packages

Compile your own `xyz.myapp.*` Lexicon schemas into strongly typed Swift 6 and Kotlin overlay packages without forking Petrel.

## Overview

The AT Protocol is an open application ecosystem — not just Bluesky. Whether you are building a status board (`xyz.statusphere.status`), a long-form publishing platform (`com.whtwnd.blog.entry`), a recipe index, or an encrypted messaging service, your app defines its own **Lexicon JSON schemas** while sharing Identity, OAuth, repositories, and `app.bsky` interoperability with the rest of the ATmosphere.

Petrel's code generator supports first-class **overlay packages** (`"kind": "overlay"`):

- Your custom `xyz.myapp.*` types live in their own lightweight Swift Package (`PetrelMyApp`) and/or Kotlin Gradle module that depends on upstream `Petrel`.
- Queries and procedures automatically extend ``ATProtoClient`` (`client.xyz.statusphere.getStatuses(input:)`), reusing Petrel's DPoP session, retry logic, and `atproto-proxy` routing.
- Calling `<OverlayName>Lexicons.register()` once at launch teaches ``ATProtocolValueContainer`` about your custom `$type` identifiers, so `com.atproto.repo.getRecord`, `listRecords`, `PetrelJetstream`, and `PetrelFirehose` automatically decode your custom records into typed Swift structs!

> Tip: A complete, runnable overlay package lives in [`Examples/StatusphereOverlay`](https://github.com/joshlacal/Petrel/tree/main/Examples/StatusphereOverlay). Run `swift run StatusphereCLI --demo` inside that directory to see custom record encoding, CID hashing, and dynamic `$type` decoding in action.

---

## Step 1: Author Your Custom Lexicons

Place your Lexicon `.json` files in a directory tree matching your NSID segments — for example, `lexicons/xyz/statusphere/status.json`:

```json
{
  "lexicon": 1,
  "id": "xyz.statusphere.status",
  "defs": {
    "main": {
      "type": "record",
      "description": "A single emoji status broadcast to the ATmosphere.",
      "key": "tid",
      "record": {
        "type": "object",
        "required": ["status", "createdAt"],
        "properties": {
          "status": {
            "type": "string",
            "minLength": 1,
            "maxGraphemes": 5,
            "maxLength": 32
          },
          "mood": {
            "type": "string",
            "knownValues": [
              "xyz.statusphere.defs#shipping",
              "xyz.statusphere.defs#caffeinated",
              "xyz.statusphere.defs#exploring"
            ]
          },
          "createdAt": {
            "type": "string",
            "format": "datetime"
          }
        }
      }
    }
  }
}
```

You can include custom `query` and `procedure` schemas in the same folder (for example, `lexicons/xyz/statusphere/getStatuses.json`). If a custom schema references standard `com.atproto.*` or `app.bsky.*` types (such as `com.atproto.repo.strongRef` or `app.bsky.actor.defs#profileViewBasic`), declare Petrel's core lexicon directory (`generator/lexicons`) under `"lexicons.reference"` in Step 2 so the generator resolves cross-package types without re-emitting them.

---

## Step 2: Create `petrel-manifest.json`

Create a `petrel-manifest.json` file with `"kind": "overlay"` under `"package"` (paths are resolved relative to the directory containing `petrel-manifest.json` when using `petrel-gen generate`):

```json
{
  "$comment": "Overlay manifest for custom xyz.statusphere.* lexicons.",
  "package": {
    "kind": "overlay",
    "name": "PetrelStatusphere"
  },
  "lexicons": {
    "emit": ["lexicons"],
    "reference": ["@petrel/core-lexicons"]
  },
  "swift": {
    "output": "Sources/PetrelStatusphere/Generated"
  },
  "kotlin": {
    "output": "kotlin/src/main/kotlin/xyz/statusphere/petrel/generated"
  }
}
```

| Manifest Field | Purpose |
| :--- | :--- |
| `package.kind` | `"overlay"` tells Petrel to `import Petrel`, extend `ATProtoClient`, and emit `<Name>Lexicons.register()` instead of duplicating core runtime files. |
| `package.name` | Name of your generated Swift target and registration enum (`PetrelStatusphereLexicons.register()`). |
| `lexicons.emit` | Directories of custom `.json` Lexicons to emit into your overlay package. |
| `lexicons.reference` | Upstream Lexicon schemas (`"@petrel/core-lexicons"`, `"petrel:core"`, or `generator/lexicons`) referenced by your schemas that already exist in `Petrel` and must not be duplicated. |
| `swift.output` / `kotlin.output` | Output directories for generated Swift 6 and Kotlin source trees. |

---

## Step 3: Run the Code Generator

You can generate your overlay using the standalone `petrel-gen` CLI (bundled with all core ATProto reference lexicons, so no Petrel git clone is required), the SwiftPM command plugins (`PetrelCodegenPlugin` or `PetrelLexgen`), or `run.py` inside a Petrel checkout:

```bash
# Option A: Standalone petrel-gen CLI (Swift, Kotlin, or both)
pipx install "git+https://github.com/joshlacal/Petrel.git@2.0.0"
petrel-gen init --namespace xyz.statusphere --name PetrelStatusphere
petrel-gen generate --manifest petrel-manifest.json --language both
swiftformat Sources/PetrelStatusphere/Generated

# Option B: SwiftPM command plugin (zero network calls; uses installed petrel-gen)
swift package plugin --allow-writing-to-package-directory petrel-codegen

# Option C: Inside a Petrel repository checkout
python3 run.py --manifest Examples/StatusphereOverlay/petrel-manifest.json --language swift
swiftformat Examples/StatusphereOverlay/Sources/PetrelStatusphere/Generated
```

For `PetrelStatusphere`, the generator emits:

- `Sources/PetrelStatusphere/Generated/Lexicons/Xyz/Statusphere/XyzStatusphereStatus.swift` (`struct XyzStatusphereStatus: ATProtocolCodable, ATProtocolValue`)
- `Sources/PetrelStatusphere/Generated/Lexicons/Xyz/Statusphere/XyzStatusphereGetStatuses.swift` (`enum XyzStatusphereGetStatuses` + `ATProtoClient.Xyz.Statusphere.getStatuses(input:)`)
- `Sources/PetrelStatusphere/Generated/Client/ATProtoClient+PetrelStatusphere.swift` (`client.xyz.statusphere` namespace tree)
- `Sources/PetrelStatusphere/Generated/Client/PetrelStatusphereLexicons.swift` (`PetrelStatusphereLexicons.register()`)

---

## Step 4: Wire Up Your Overlay `Package.swift`

Add `Petrel` as a dependency of your overlay package and expose your overlay library target to your app or server:

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

---

## Step 5: Register, Write, and Decode Custom Records

Every generated record conforms to `ATProtocolCodable` and `ATProtocolValue`, with `static let typeIdentifier` set to its Lexicon NSID.

At application startup, register your overlay's `$type` decoders (generated as `<OverlayName>Lexicons.register()`, which calls ``ATProtocolValueContainer/registerDecoder(forType:as:)`` for each custom schema). Once registered, any ``ATProtocolValueContainer`` — whether from `com.atproto.repo.getRecord`, `listRecords`, `PetrelJetstream`, or `PetrelFirehose` — automatically decodes `"$type": "xyz.statusphere.status"` payloads into your concrete Swift struct!

<!-- compile-example: overlay-record-roundtrip -->
```swift
import Foundation
import Petrel

/// Representative struct matching what Petrel generates for `xyz.statusphere.status`.
struct XyzStatusphereStatus: ATProtocolCodable, ATProtocolValue {
    static let typeIdentifier = "xyz.statusphere.status"

    let status: String
    let mood: String?
    let createdAt: ATProtocolDate

    func isEqual(to other: any ATProtocolValue) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }

    func toCBORValue() throws -> Any {
        var map = OrderedCBORMap()
        map = map.adding(key: "$type", value: Self.typeIdentifier)
        map = map.adding(key: "status", value: try status.toCBORValue())
        if let mood {
            map = map.adding(key: "mood", value: try mood.toCBORValue())
        }
        map = map.adding(key: "createdAt", value: try createdAt.toCBORValue())
        return map
    }
}

func publishCustomStatusRecord(client: ATProtoClient, accountDID: DID) async throws {
    let record = XyzStatusphereStatus(
        status: "🚀",
        mood: "xyz.statusphere.defs#shipping",
        createdAt: ATProtocolDate(date: Date())
    )

    // Write the custom record to the user's PDS repository:
    let (_, output) = try await client.com.atproto.repo.createRecord(
        input: .init(
            repo: .did(accountDID),
            collection: try NSID(nsidString: XyzStatusphereStatus.typeIdentifier),
            rkey: RecordKey(keyString: await TIDGenerator.next()),
            record: .knownType(record)
        )
    )

    if let uri = output?.uri, let cid = output?.cid {
        print("Published custom record \(uri.uriString()) (CID \(cid.string))")
    }
}
```

### Registering Custom `$type` Decoders for Dynamic Streams

Generated overlays emit `PetrelStatusphereLexicons.register()`, which registers each generated `ATProtocolValue` type with ``ATProtocolValueContainer/registerDecoder(forType:as:)`` idempotently. After registration, JSON and DAG-CBOR payloads carrying `"$type": "xyz.statusphere.status"` hydrate directly via `.decoded(_:)`:

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

---

## OAuth Scopes for Custom Collections

When signing users into an app that writes custom `xyz.myapp.*` records, request least-privilege repository scopes via `ATProtoScopeSet` instead of broad `transition:generic` permissions whenever the user's PDS supports granular ATProto permissions:

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

## Next Steps

- See <doc:CustomLexicons> for the `PetrelLexgen` plugin reference and Lexicon v1 construct table.
- Explore [`Examples/StatusphereOverlay`](https://github.com/joshlacal/Petrel/tree/main/Examples/StatusphereOverlay) for a complete working overlay manifest, generated Swift package, and CLI demo.
- Stream your custom collection in real time across the entire ATmosphere with `JetstreamFilter(collections: ["xyz.statusphere.status"])` in <doc:StreamingAndVerification>.
