# ``PetrelPLC``

Read, verify and write `did:plc` identities against a PLC directory.

## Overview

`did:plc` is the DID method most AT Protocol accounts use. An identity is a
log of signed operations held by a directory server; the DID is the hash of
the first operation, and each later operation names its predecessor and is
signed by one of the predecessor's rotation keys. The log is therefore
self-certifying: anyone can check it without trusting the directory.

`PetrelPLC` implements the [did:plc specification](https://web.plc.directory/spec/v0.1/did-plc) (v0.3.0). Use
``PLCDirectoryClient`` to read every directory endpoint,
``PLCAuditLogVerifier`` to verify an audit log offline (CIDs, signatures on
both curves, the 72-hour recovery rules), and any `ATProtoSigner` from
`PetrelCrypto` to sign operations you build. Start with
<doc:DirectoryOperations>.

Reading is lenient and writing is strict. The public directory holds
operations that today's rules would not admit — the deprecated `create`
format, repeated rotation keys, empty or non-ECDSA verification methods —
and all of them decode and verify. Operations you build are held to the
current rules, see ``PLCOperationLimits``.

The module depends only on `PetrelCore` and `PetrelCrypto`. To change an
identity through the account's PDS, use `PetrelPLCPDS`.

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
