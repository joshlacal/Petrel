# ``PetrelRepo``

Read, verify and write AT Protocol repositories.

## Overview

An account's public data lives in a *repository*: a Merkle Search Tree (MST)
that maps record paths to records, and a signed *commit* over the tree's root.
Repositories travel as CAR archives. This module implements the
[repository](https://atproto.com/specs/repository),
[data model](https://atproto.com/specs/data-model) and
[sync](https://atproto.com/specs/sync) specifications for all three.

Start with ``Repository``. It opens a `com.atproto.sync.getRepo` export and
verifies it end to end, reads and enumerates records, builds and checks record
proofs, applies writes as new signed commits, and exports CAR archives. The
article <doc:Repositories> walks through each of those.

Commits are signed and verified on both curves the protocol blesses, P-256
and secp256k1, through the `ATProtoSigner` and `ATProtoPublicKey` types of
`PetrelCrypto`.

The types underneath ``Repository`` are public too, for programs that need a
piece of the machinery on its own: a firehose consumer verifying commit diffs
(``RepositoryCommitDiff``), a server answering `getRecord`
(``RepositoryMSTProof``), or a store that keeps blocks in a database
(``RepositoryBlockStore``).

## Topics

### Essentials

- <doc:Repositories>
- ``Repository``
- ``RepositoryRecord``
- ``RepositoryCommit``
- ``RepositoryOptions``
- ``RepositoryError``
- ``RepositoryLimitKind``

### Authenticating commits

- ``RepositoryCommitVerification``
- ``RepositorySigningKeyResolver``
- ``FixedRepositorySigningKey``
- ``ATProtoRepositoryCommitSigner``
- ``ATProtoRepositoryCommitVerifier``
- ``PublicRepositoryCommitCodec``
- ``LegacyRepositoryCommitV2``

### Writing

- ``PublicRepositoryWrite``
- ``PublicRecord``
- ``PublicRecordValue``
- ``PublicRepositoryPath``
- ``PublicRepositoryTID``
- ``RepositoryCommitResult``
- ``PublicRepositoryEngine``

### Proofs and commit diffs

- ``RepositoryRecordProof``
- ``VerifiedRecordProof``
- ``RepositoryMSTProof``
- ``RepositoryCommitDiff``
- ``RepositoryCommitOperation``

### Storage and CAR archives

- ``RepositoryBlockStore``
- ``InMemoryRepositoryBlockStore``
- ``FileRepositoryBlockStore``
- ``PublicRepositoryCAR``
- ``RepositoryCARBlockOrder``
- ``DataCARByteSource``
- ``FileCARByteSource``
- ``DataCARByteSink``
- ``FileCARByteSink``

### Limits and tolerance

- ``PublicRepositoryLimits``
- ``RepositoryReadPolicy``
- ``PublicRepositoryCID``

### The Merkle Search Tree

- ``RepositoryMST``
- ``RepositoryMSTWalker``
- ``RepositoryMSTCodec``
- ``RepositoryMSTOptions``
- ``RepositoryMSTValidation``
