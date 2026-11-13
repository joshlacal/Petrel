# ``PetrelPLC``

Read, verify and write `did:plc` identities against a PLC directory.

## Overview

`did:plc` is the DID method most AT Protocol accounts use. An identity is a
log of signed operations held by a directory server; the DID is the hash of
the first operation, and each later operation names its predecessor and is
signed by one of the predecessor's rotation keys. The log is therefore
self-certifying: anyone can check it without trusting the directory.

`PetrelPLC` implements the
[did:plc specification](https://web.plc.directory/spec/v0.1/did-plc) (v0.3.0):

- **Read** every directory endpoint with ``PLCDirectoryClient``: the DID
  document, the identity's state, its operation log and audit log, its
  newest operation, and the directory-wide export.
- **Verify** an audit log offline with ``PLCAuditLogVerifier``: CIDs, the
  DID, every signature on both supported curves, and the 72-hour recovery
  rules.
- **Write** operations: build them, sign them with any `ATProtoSigner` from
  `PetrelCrypto` (K-256 or P-256, in memory or held elsewhere), and submit
  them.

Start with <doc:DirectoryOperations>.

Reading is lenient and writing is strict. The public directory holds
operations that today's rules would not admit — the deprecated `create`
format, repeated rotation keys, empty or non-ECDSA verification methods —
and all of them decode and verify. Operations you build are held to the
current rules, see ``PLCOperationLimits``.

### Checked against the public directory

The test suite verifies recorded operations of organisation, service and
test identities, among them a legacy `create` genesis, tombstones, and
recoveries in which a nullified operation is displaced. A larger run is
reproducible on demand rather than vendored: on 2026-11-11, 62,000
operations sampled from `https://plc.directory/export` between 2022 and
2026 all decoded and matched their CIDs, with none rejected; all 55,872
genesis operations among them hashed to their DIDs and carried valid
signatures (45,414 signatures by K-256 keys and 14,669 by P-256 keys
across the sample). `Tests/PetrelPLCTests/Vectors/plc-directory/README.md`
gives the command that repeats it.

Within Petrel, the module depends only on `PetrelCore` and `PetrelCrypto`, not
on the `Petrel` client. Changing an
identity through the account's PDS, for accounts that hold no rotation key
of their own, is in the separate `PetrelPLCPDS` product.

## Topics

### Essentials

- <doc:DirectoryOperations>
- ``PLCDirectoryClient``
- ``PLCClientConfiguration``
- ``PetrelPLCError``

### Operations

- ``PLCSignedOperation``
- ``PLCSignedRegularOperation``
- ``PLCSignedTombstoneOperation``
- ``PLCSignedLegacyCreateOperation``
- ``PLCUnsignedOperation``
- ``PLCUnsignedRegularOperation``
- ``PLCUnsignedTombstoneOperation``
- ``PLCService``
- ``PLCOperationCodec``
- ``PLCOperationLimits``

### Building updates

- ``PLCATProfile``
- ``PLCOperationDraft``

### Identity state and verification

- ``PLCDocumentData``
- ``PLCDIDDocument``
- ``PLCAuditEntry``
- ``PLCAuditLogVerifier``
- ``PLCVerifiedAuditLog``

### Bulk export

- ``PLCExportEntry``
- ``PLCExportCursor``
- ``PLCExportSequence``

### Transport

- ``PLCClient``
- ``PLCHTTPTransport``
- ``PLCHTTPRequest``
- ``PLCHTTPResponse``
- ``PLCHTTPMethod``
- ``URLSessionPLCTransport``
- ``PLCSubmitSuccessResponsePolicy``

### Identifiers

- ``AccountIdentifiers``
