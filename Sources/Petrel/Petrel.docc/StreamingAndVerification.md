# Streaming and Verification

Choose between Jetstream and the firehose, and see which Petrel module verifies repositories and `did:plc` identities.

## Overview

The `Petrel` client covers request/response XRPC. Four separate products cover the rest of
the data path:

| Product | What it does | Trust |
| :--- | :--- | :--- |
| `PetrelJetstream` | Consumes Jetstream, a JSON re-publication of repository events, filtered by collection and DID on the server; backfills from an archive on hosts that publish one | You trust the Jetstream host |
| `PetrelFirehose` | Consumes `com.atproto.sync.subscribeRepos` (the binary firehose of a relay or PDS) and any other Lexicon subscription | Events are delivered, not authenticated; you verify the ones you trust with one call |
| `PetrelRepo` | Reads, verifies and writes repositories: CAR files, Merkle Search Trees, signed commits, record proofs and commit diffs | Verifies signatures and tree structure |
| `PetrelPLC` | Reads the `did:plc` directory and verifies an identity's audit log offline | Verifies the operation chain from genesis |

Each product has its own documentation with the full API; this article shows where each
fits. Add the products you need next to `Petrel` in your package manifest and import them
separately.

## Jetstream: filtered JSON

Use Jetstream when you need a few collections and can trust the host's translation, as a
bot, feed generator or small indexer usually can. `JetstreamSubscription` is pull-based,
reconnects with backoff and resumes from the last delivered position:

<!-- compile-example: streaming-jetstream -->
```swift
import Foundation
import Petrel
import PetrelJetstream

func printNewPosts(limit: Int) async throws {
    let subscription = JetstreamSubscription(configuration: .init(
        url: URL(string: "https://jetstream2.us-east.bsky.network")!,
        filter: JetstreamFilter(kinds: [.commit], collections: ["app.bsky.feed.post"])
    ))

    var seen = 0
    for try await element in subscription.events() {
        switch element {
        case let .event(.commit(commit)):
            guard commit.operation == .create,
                  let post = commit.decodedRecord()?.decoded(AppBskyFeedPost.self)
            else { continue }
            print("\(commit.did): \(post.text)")
            seen += 1
            if seen >= limit { return }
        case .event, .streamError:
            break
        case .ignoredFrame:
            break    // a frame the subscription could not use; the stream continues
        }
    }
}
```

Frames the subscription cannot use arrive as `JetstreamSubscriptionEvent.ignoredFrame(_:)`
instead of being dropped silently. A cursor storage that throws ends the stream with
`JetstreamSubscriptionError.cursorStorageFailure(operation:message:)` rather than skipping
or losing a position. `JetstreamClient` adds archive backfill followed by the live stream.
The `PetrelJetstream` documentation covers both, the v2 and legacy Jetstream APIs, and
compression.

## The firehose

The firehose carries signed commits and the changed blocks as a CAR file. Petrel's
consumer delivers those events without verifying them. `RelayCommitEvent.records()`
checks each block against the CID the operation names before decoding it, which
detects a corrupted block but proves nothing about who signed the commit:

<!-- compile-example: streaming-firehose -->
```swift
import Foundation
import Petrel
import PetrelFirehose

func printFirehosePosts(limit: Int) async throws {
    let subscription = FirehoseSubscription(
        service: URL(string: "https://bsky.network")!,
        cursorStorage: InMemoryFirehoseCursorStorage(),   // use durable storage in production
        autoAcknowledge: true
    )

    var seen = 0
    for try await element in subscription.events() {
        guard case let .event(.commit(commit)) = element else { continue }
        for operation in try commit.records() where operation.action == .create {
            if let post = operation.record?.decoded(AppBskyFeedPost.self) {
                print("\(commit.repo): \(post.text)")
                seen += 1
                if seen >= limit { return }
            }
        }
    }
}
```

To authenticate an event, call `verify(keyResolver:)` on it before trusting its operations.
For a `#commit` event this checks the signature against the account's signing key, the
revision, the operations against `prevData` by MST inversion, and every record block;
`RelaySyncEvent` has the same method for `#sync` events. Both are thin wrappers over
`RepositoryCommitDiff` in `PetrelRepo`. Petrel does not run them for you on the stream: you
choose which events to verify and supply the key resolver, usually
`CachingServiceAuthKeyResolver(upstream: IdentityResolver())`:

<!-- compile-example: streaming-firehose-verify -->
```swift
import Petrel
import PetrelCrypto
import PetrelFirehose
import PetrelRepo

func verifyFirehoseCommit(_ commit: RelayCommitEvent) async throws {
    let keys = CachingServiceAuthKeyResolver(upstream: IdentityResolver())
    let verified = try await commit.verify(keyResolver: keys)
    print("Verified commit \(verified.commit.commitCID) with \(verified.operations.count) ops")
}
```

`PetrelFirehose` also reads any other subscription, such as
`com.atproto.label.subscribeLabels`, with `EventStreamSubscription`, and the generated
subscription methods on ``ATProtoClient`` (see <doc:XRPCClient>) are available for simple
cases. The `PetrelFirehose` documentation covers cursors, reconnection, backpressure and what
ends a stream.

## Repositories

`PetrelRepo` works with whole repositories: it opens a `getRepo` export and verifies its
commit signature and tree, checks record proofs, and creates signed commits whose diffs are
ready to publish as firehose events. Any `ATProtoSigner` from `PetrelCrypto` can sign:

<!-- compile-example: streaming-repo-commit -->
```swift
import Foundation
import PetrelCrypto
import PetrelRepo

func createRepository() async throws -> Data {
    let signer = K256Keypair.generate()
    let repository = try await Repository.create(did: "did:plc:ewvi7nxzyoun6zhxrhs64oiz", signer: signer)

    let post: PublicRecord = [
        "$type": .string("app.bsky.feed.post"),
        "text": .string("Hello from Petrel"),
        "createdAt": .string("2026-11-12T10:30:00.000Z"),
    ]
    let path = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "3lon5dzeaihj2")
    let result = try await repository.commit([.create(path: path, record: post)], signer: signer)

    return try await result.repository.exportCAR()   // a getRepo response body
}
```

The `PetrelRepo` documentation covers reading large repositories, record proofs and
verifying a commit diff.

## `did:plc` identities

``IdentityResolver`` resolves a DID document and checks the handle in both directions (see
<doc:Identity>), trusting the PLC directory's answer for a `did:plc` document. When that is
not enough, `PetrelPLC` verifies the identity's audit log itself: every operation's CID, the
DID as the hash of the genesis operation, every signature against the rotation keys in force,
and the 72-hour recovery rules:

<!-- compile-example: streaming-plc -->
```swift
import Foundation
import PetrelPLC

func verifiedPDSEndpoint(did: String) async throws -> String? {
    let directory = try PLCDirectoryClient()
    // Reads the identity's data and its audit log, verifies the log, and throws
    // PetrelPLCError.unauthorized if the two disagree.
    let state = try await directory.fetchState(did: did)
    return state.pdsEndpoint
}

func verifyAuditLogOffline(auditLogJSON: Data, did: String) throws -> PLCVerifiedAuditLog {
    try PLCAuditLogVerifier.verify(json: auditLogJSON, did: did)
}
```

The `PetrelPLC` documentation covers reading, rotating keys and recovery.

## Next Steps

- Resolve handles and DIDs in <doc:Identity>.
- Verify incoming service-auth tokens in your own service in <doc:ServiceAuthentication>.
- See how the modules map to the protocol in <doc:ArchitectureAndMentalModel>.
