# Reading, verifying and updating an identity

Read a DID's history from a PLC directory, prove it, and rotate a key.

## Overview

Everything goes through ``PLCDirectoryClient``. With no arguments it talks
to `https://plc.directory`; pass a ``PLCClientConfiguration`` to use a
mirror or your own directory.

<!-- compile-example: plc-make-clients -->
```swift
import Foundation
import PetrelPLC

func makeClients() throws -> (publicDirectory: PLCDirectoryClient, mirror: PLCDirectoryClient) {
    let client = try PLCDirectoryClient()

    let mirror = try PLCDirectoryClient(
        configuration: .production(origin: URL(string: "https://plc.example.org")!)
    )
    return (client, mirror)
}
```

## Read a DID's history

The audit log is every operation the directory has accepted for an
identity, oldest first, including operations that were later nullified.

<!-- compile-example: plc-read-audit-log -->
```swift
import PetrelPLC

func readHistory(client: PLCDirectoryClient) async throws -> [PLCAuditEntry] {
    let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"

    let entries = try await client.getAuditLog(did: did)
    for entry in entries {
        switch entry.operation {
        case let .regularOperation(operation):
            // rotationKeys, verificationMethods, alsoKnownAs, services, prev
            _ = operation.alsoKnownAs
        case let .legacyCreateOperation(operation):
            // The pre-2023 genesis format: signingKey, recoveryKey, handle, service
            _ = operation.handle
        case .tombstoneOperation:
            // The identity was deactivated here
            break
        }
        _ = (entry.cid, entry.createdAt, entry.nullified)
    }
    return entries
}
```

The other read endpoints are one call each. None of them verifies anything;
they return what the directory said.

<!-- compile-example: plc-read-endpoints -->
```swift
import PetrelPLC

func readEndpoints(client: PLCDirectoryClient, did: String) async throws {
    let document = try await client.getDocument(did: did)       // GET /:did
    let data = try await client.getDocumentData(did: did)       // GET /:did/data
    let operations = try await client.getOperationLog(did: did) // GET /:did/log
    let last = try await client.getLastOperation(did: did)      // GET /:did/log/last
    _ = (document, data, operations, last)
}
```

A DID the directory does not know throws ``PetrelPLCError/notFound(did:)``.
A deactivated one throws ``PetrelPLCError/tombstoned(did:)`` for its
document and data, while its logs stay readable.

## Verify it

``PLCAuditLogVerifier`` checks a log without the network and without
trusting where the log came from:

<!-- compile-example: plc-verify-audit-log -->
```swift
import PetrelPLC

func verifyHistory(entries: [PLCAuditEntry], did: String) throws -> PLCVerifiedAuditLog {
    let log = try PLCAuditLogVerifier.verify(entries, did: did)

    let current = log.head                // the operation that defines the identity now
    let state = log.documentData          // rotation keys, handle, PDS; nil if tombstoned
    let signers = log.signers             // which rotation key signed each operation
    let nullified = log.entries.filter(\.nullified)
    _ = (current, state, signers, nullified)
    return log
}
```

Verification recomputes the CID of every operation, derives the DID from
the genesis operation (in the legacy `create` format when that is what the
identity has), verifies every signature against the rotation keys of the
operation it follows, and replays the recovery rules: an operation that
forks from an earlier one is valid only if it is signed by a rotation key
of strictly higher authority than the one that signed the first operation
it displaces, and is dated within 72 hours of it. The `nullified` flags of
the result are recomputed, not copied.

Signature encoding is enforced strictly, as the specification requires:
unpadded base64url with zero trailing bits, 64 bytes, low-S. A failure is
``PetrelPLCError/unauthorized(_:)``.

To fetch and verify in one step, and to get state that is proven rather
than asserted:

<!-- compile-example: plc-fetch-verified -->
```swift
import PetrelPLC

func fetchProven(client: PLCDirectoryClient, did: String) async throws -> PLCDocumentData {
    let verified = try await client.fetchVerifiedAuditLog(did: did)
    let provenState = try await client.fetchState(did: did)
    _ = verified.head
    return provenState
}
```

The one thing a log cannot prove is its timestamps. They are the
directory's assertion, and the recovery window is measured with them.

## Rotate a key

Updating an identity means submitting a new operation signed by one of its
current rotation keys. The client reads and verifies the log, builds the
next operation from the current state, signs it and submits it:

<!-- compile-example: plc-rotate-key -->
```swift
import PetrelCrypto
import PetrelPLC

func rotate(client: PLCDirectoryClient, did: String, storedPrivateKeyHex: String) async throws -> P256Keypair {
    let currentRotationKey = try K256Keypair(hex: storedPrivateKeyHex)
    let newRotationKey = P256Keypair.generate()

    var rotationKeys = try await client.fetchState(did: did).rotationKeys
    rotationKeys.insert(newRotationKey.didKey, at: 0)

    let operation = try await client.updateRotationKeys(
        did: did,
        signer: currentRotationKey,
        rotationKeys: rotationKeys
    )
    _ = try operation.cid
    return newRotationKey   // store its private key before relying on it
}
```

Rotation keys are listed in descending authority, so the new key now
outranks the others. Any `ATProtoSigner` works as `signer`: `K256Keypair`,
`P256Keypair`, a Secure Enclave key, or an `ATProtoExternalSigner` wrapping
a KMS or hardware token. The same shape covers the other updates:

<!-- compile-example: plc-other-updates -->
```swift
import PetrelCrypto
import PetrelPLC

func otherUpdates(
    client: PLCDirectoryClient,
    did: String,
    newRotationKey: any ATProtoSigner,
    repositoryKey: K256Keypair
) async throws {
    try await client.updateHandle(did: did, signer: newRotationKey, handle: "alice.example.com")
    try await client.updatePDS(did: did, signer: newRotationKey, endpoint: "https://pds.example.com")
    try await client.updateAtprotoKey(did: did, signer: newRotationKey, signingKey: repositoryKey.didKey)
    try await client.update(did: did, signer: newRotationKey) { draft in
        draft.alsoKnownAs.append("https://alice.example.com")
    }
}
```

If the directory refuses an operation, ``PetrelPLCError/rejected(status:message:)``
carries its explanation. A success status is not taken on trust either: the
client reads the audit log back, verifies it, and requires the newest valid
operation to be the one it sent. If that read fails the error is
``PetrelPLCError/submittedButUnconfirmed(cid:reason:)`` — the operation is
probably registered, so check before sending it again.

### Recover from an unwanted operation

For 72 hours after an operation, a rotation key of higher authority than
the one that signed it can undo it by forking the log from the operation
before it. Build the fork with ``PLCOperationCodec/update(after:_:)`` from
the entry to return to, and submit it:

<!-- compile-example: plc-recover -->
```swift
import PetrelCrypto
import PetrelPLC

// Undo the newest operation with a rotation key of higher authority.
func undoLastOperation(client: PLCDirectoryClient, did: String, newRotationKey: any ATProtoSigner) async throws {
    let history = try await client.fetchVerifiedAuditLog(did: did)
    let lastGood = history.activeEntries[history.activeEntries.count - 2].operation

    let recovery = try await PLCOperationCodec.sign(
        .regular(PLCOperationCodec.update(after: lastGood) { _ in }),
        with: newRotationKey
    )
    try await client.submit(did: did, operation: recovery)
}
```

### Create and deactivate

<!-- compile-example: plc-create-and-tombstone -->
```swift
import PetrelCrypto
import PetrelPLC

func createAndDeactivate(client: PLCDirectoryClient) async throws {
    let repositoryKey = K256Keypair.generate()
    let rotationKey = K256Keypair.generate()

    let created = try await client.createDID(
        handle: "alice.example.com",
        signingKey: repositoryKey.didKey,
        rotationKeys: [rotationKey.didKey],
        pdsEndpoint: "https://pds.example.com",
        signer: rotationKey
    )
    // created.did is derived from the signed genesis operation.

    try await client.tombstone(did: created.did, signer: rotationKey)
}
```

### Sign somewhere else

When the private key cannot be reached through `ATProtoSigner` — an
air-gapped machine, a ceremony — take the bytes to be signed, sign them
elsewhere, and attach the result:

<!-- compile-example: plc-sign-offline -->
```swift
import Foundation
import PetrelPLC

func changeHandleOffline(
    client: PLCDirectoryClient,
    did: String,
    offlineSigner: (Data) throws -> Data
) async throws {
    let current = try await client.fetchVerifiedAuditLog(did: did).head

    let unsigned = try PLCUnsignedOperation.regular(
        PLCOperationCodec.updateHandle(after: current.operation, handle: "alice.example.org")
    )
    let bytesToSign = try unsigned.signingDAGCBOR
    let signature = try offlineSigner(bytesToSign)   // 64 bytes r || s, low-S
    let signed = try PLCOperationCodec.attach(signature: signature, to: unsigned)
    try await client.submit(did: did, operation: signed)
}
```

## Follow the whole directory

`GET /export` lists every operation of every identity. The client pages
through it on demand:

<!-- compile-example: plc-export -->
```swift
import PetrelPLC

func followDirectory(client: PLCDirectoryClient) async throws -> PLCExportCursor {
    var cursor = PLCExportCursor.sequence(0)
    for try await entry in client.exportSequence(after: cursor) {
        // entry.did, entry.operation, entry.cid, entry.createdAt, entry.sequence
        cursor = entry.cursor
    }
    // Reached the newest operation. Resume later from `cursor`.
    return cursor
}
```

Each entry's CID is checked against its operation as it is decoded. The
WebSocket feed at `/export/stream` sends the same objects, one per message;
decode them with ``PLCExportEntry/init(jsonLine:)``.

## What is checked when

| | Reading | Writing |
|---|---|---|
| Operation formats | `plc_operation`, `plc_tombstone`, legacy `create` | `plc_operation`, `plc_tombstone` |
| Field structure | exact field sets | exact field sets |
| Rotation keys | any list | 1–5, distinct, P-256 or K-256 |
| Verification methods | any map | at most 10, each a syntactically valid `did:key` of any key type |
| Size | bounded only by the response limit | 7,500 DAG-CBOR bytes |
| Signature encoding | strict | strict |

``PLCOperationLimits/referenceDirectory`` tightens the write column to what
the reference directory server accepts today (4,000 bytes, at most 10
aliases and services). Set it as
``PLCClientConfiguration/operationLimits`` to have such operations refused
before they are sent.
