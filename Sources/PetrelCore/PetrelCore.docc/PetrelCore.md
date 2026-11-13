# ``PetrelCore``

Content identifiers, deterministic DAG-CBOR, CAR v1 archive reading, and shared JSON coding for the AT Protocol.

## Overview

`PetrelCore` holds the data-model pieces that the rest of Petrel builds on.
It makes no network requests. Within Petrel it depends only on
`PetrelCrypto`, so a server component, command-line tool or storage layer
can compute CIDs, encode canonical DAG-CBOR and read CAR exports without
linking the generated Lexicon client.

`import Petrel` re-exports `PetrelCore`, so targets that already depend on
`Petrel` can use every type here without a second import.

<!-- compile-example: core-cid-and-car -->
```swift
import Foundation
import PetrelCore

func cidAndArchive(carData: Data) throws {
    // Canonical DAG-CBOR bytes, and the CID that addresses them.
    let bytes = try DAGCBOR.encodeValue(["text": "hello"])
    let cid = CID.fromDAGCBOR(bytes)
    let reparsed = try CID.parse(cid.string)
    assert(reparsed == cid)

    // A CAR v1 archive, such as a repository export.
    let archive = try CARReader(data: carData)
    for root in archive.roots {
        _ = try archive.decodeBlock(for: root)
    }
}
```

``CID/parse(_:)`` rejects a CID string that is not in canonical base32
spelling. ``CARReader`` checks every block's SHA-256 digest against its CID
when it opens the archive, and refuses conflicting duplicate blocks.

## Topics

### Content Addressing (CID & Multihash)

- ``CID``
- ``CIDCodec``
- ``Multihash``
- ``ATProtoLink``
- ``CIDAsLink``

### Deterministic DAG-CBOR & Ordered Maps

- ``DAGCBOR``
- ``DAGCBORError``
- ``DAGCBOREncodable``
- ``DAGCBORDecodable``
- ``DAGCBORCodable``
- ``OrderedCBORMap``

### CAR v1 Archives & JSON Coding

- ``CARReader``
- ``CARReaderError``
- ``JSONCoders``
