# Working with Repositories

Read an exported repository, check a record proof, and make a signed commit.

## Overview

Every example on this page is compiled and run by
`Tests/PetrelRepoTests/RepositoryDocumentationTests.swift`, which also checks
that the code here matches the code there.

Add the product to your target and import it:

```swift
import PetrelCrypto
import PetrelRepo
```

## Read a repository

`com.atproto.sync.getRepo` returns an account's whole repository as a CAR
archive. ``Repository/open(car:verification:expectedDID:store:options:)``
parses it, checks the commit signature against the account's signing key, and
verifies the whole tree and every record before returning.

The signing key comes from the account's DID document. Take it from there,
never from the archive you are checking:

```swift
let key = try Repository.signingKey(fromDIDDocument: didDocument, did: did)
let repo = try await Repository.open(
    car: car,
    verification: .signingKey(key),
    expectedDID: did
)
let recordCount = repo.statistics?.recordCount ?? 0
let revision = repo.revision.value
```

If you resolve identities through a cache, pass
``RepositoryCommitVerification/keyResolver(_:)`` instead: a signature that
does not verify triggers one refreshed lookup before the commit is refused,
which is what a consumer needs after a key rotation.

Look up one record, or walk a collection in record-key order:

```swift
if let profile = try await repo.record(collection: "app.bsky.actor.profile", recordKey: "self") {
    let json = try profile.json()          // the data model's JSON form
    let value = try profile.record()       // a typed data-model value
    let cid = profile.cid                  // CID of the record block
    profileSummary = (json.count, value.type, cid.string)
}

var postKeys: [String] = []
try await repo.forEachRecord(collection: "app.bsky.feed.post") { post in
    postKeys.append(post.recordKey)
}
```

``Repository/forEachRecord(collection:_:)`` reads only the part of the tree
that covers the collection and holds one record at a time.

### Large repositories

The specification expects repositories of millions of records. To read one
without holding it in memory, open it from a file into a
``FileRepositoryBlockStore``. Blocks stay on disk; memory is used for an index
of block locations and for the tree's depth.

```swift
let store = try FileRepositoryBlockStore(url: scratchDirectory.appendingPathComponent("blocks"))
let large = try await Repository.open(
    carFile: exportedFile,
    verification: .signingKey(key),
    store: store
)
let sink = try FileCARByteSink(url: scratchDirectory.appendingPathComponent("copy.car"))
try await large.exportCAR(to: sink)
```

The default limits (``PublicRepositoryLimits/networkScale``) admit 20 million
records. Pass ``RepositoryOptions`` to tighten them, or to switch from the
tolerant ``RepositoryReadPolicy/dataModel`` policy to
``RepositoryReadPolicy/strict``.

The same limits bound writes. ``Repository/commit(_:signer:revision:expectedCommitCID:)``
measures the tree it is about to sign and throws
``RepositoryError/limitExceeded(_:limit:)`` instead of signing a commit whose
repository would have more records or MST nodes than allowed, or whose export
would break the CAR block or byte budget.

## Verify a record proof

`com.atproto.sync.getRecord` returns a small CAR: the signed commit, the MST
nodes on the path to one key, and the record. That is enough to prove the
record is in the account's repository at that commit, without downloading the
repository.

```swift
let proof = try await Repository.verifyRecordProof(
    car: proofCAR,
    did: did,
    collection: "app.bsky.actor.profile",
    recordKey: "self",
    verification: .signingKey(key)
)
if let record = proof.record {
    provenCID = record.cid
} else {
    // The proof shows there is no record at this path in this commit.
    provenCID = nil
}
```

A proof with a node missing throws. It is never read as "no such record".

To serve proofs, build them from a repository you hold:

```swift
let built = try await repo.recordProof(collection: "app.bsky.actor.profile", recordKey: "self")
let responseBody = try await built.car()
```

## Make a commit

Create a repository, or open an existing one, and apply writes. Each call to
``Repository/commit(_:signer:revision:expectedCommitCID:)`` signs one new
commit and returns a `Repository` positioned at it. Any `ATProtoSigner` works:
an in-memory `K256Keypair` or `P256Keypair`, a Secure Enclave key, or an
`ATProtoExternalSigner` in front of a key service.

```swift
let signer = K256Keypair.generate()
let mine = try await Repository.create(did: "did:plc:ewvi7nxzyoun6zhxrhs64oiz", signer: signer)

let post: PublicRecord = [
    "$type": .string("app.bsky.feed.post"),
    "text": .string("Hello from Petrel"),
    "createdAt": .string("2026-11-11T12:00:00.000Z"),
]
let path = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "3lon5dzeaihj2")
let result = try await mine.commit([.create(path: path, record: post)], signer: signer)

let head = result.repository            // the repository at the new commit
let export = try await head.exportCAR() // a getRepo response body
```

Revisions are allocated for you and always increase. Records can also be
built from JSON with `PublicRecord(json:)`.

### Publish and verify the commit's diff

The result carries everything a `#commit` firehose event needs: the
operations, the previous tree root (`prevData`), and a CAR of the blocks that
changed plus the unchanged MST nodes a consumer needs to check the operations.

```swift
let blocks = try await result.diffCAR()     // the event's `blocks`
let operations = result.operations          // the event's `ops`
let previousData = result.previousDataCID   // the event's `prevData`
```

A consumer verifies such an event without holding the repository: it undoes
each operation against the tree in the diff and checks that the root it
arrives at is `prevData`.

```swift
let diffStore = InMemoryRepositoryBlockStore()
let parsed = try await PublicRepositoryCAR.load(from: DataCARByteSource(blocks), into: diffStore)
let received = try await Repository.open(
    commitCID: parsed.rootCID,
    store: diffStore,
    verification: .signingKey(signer.publicKey),
    verifiesTree: false                     // a diff holds only part of the tree
)
try await RepositoryCommitDiff.verifyInversion(
    dataCID: received.commit.dataCID,
    operations: operations,
    previousDataCID: previousData,
    blocks: diffStore
)
```

``RepositoryCommitDiff/verify(commitCID:operations:previousDataCID:blocks:keyResolver:expectedDID:limits:policy:)``
does both steps, and checks the record blocks, in one call.

On a firehose, hand the event's fields straight to
``RepositoryCommitDiff/verifyCommitEvent(blocks:commitCID:did:revision:operations:previousDataCID:keyResolver:limits:policy:)``
for a `#commit` event, or to
``RepositoryCommitDiff/verifySyncEvent(blocks:did:revision:keyResolver:limits:)``
for a `#sync` event. Both also check that the event's `repo`/`did`, `rev` and
`commit` are the ones inside the signed commit. Supply a
``RepositorySigningKeyResolver`` backed by DID resolution; a signature that
fails against a cached key is retried once against a refreshed one.
