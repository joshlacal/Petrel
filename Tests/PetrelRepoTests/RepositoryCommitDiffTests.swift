import Foundation
import Petrel
import PetrelCrypto
import PetrelRepo
import Testing

/// What a commit's diff must contain (repository specification, "Repository
/// Diffs") and that a consumer holding only the diff can verify it.
@Suite("Commit diffs")
struct RepositoryCommitDiffTests {
    private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    private let collection = "app.bsky.feed.post"
    private let signer = K256Keypair.generate()

    private func path(_ key: String) throws -> PublicRepositoryPath {
        try PublicRepositoryPath(collection: collection, recordKey: key)
    }

    private func record(_ text: String) -> PublicRecord {
        .sample(collection, text: text)
    }

    /// Verifies `result` the way a firehose consumer would: from the diff's
    /// own CAR bytes, with no access to the repository.
    @discardableResult
    private func verifyAsConsumer(_ result: RepositoryCommitResult) async throws -> VerifiedRepositoryCommitDiff {
        let car = try await result.diffCAR()
        let received = InMemoryRepositoryBlockStore()
        let parsed = try await PublicRepositoryCAR.parseIncrementally(
            from: DataCARByteSource(car), to: StoreSink(store: received),
            limits: .networkScale, policy: .dataModel
        )
        #expect(parsed.rootCID == result.repository.commit.cid)
        return try await RepositoryCommitDiff.verify(
            commitCID: parsed.rootCID,
            operations: result.operations,
            previousDataCID: result.previousDataCID,
            blocks: received,
            keyResolver: FixedRepositorySigningKey(signer.publicKey),
            expectedDID: did,
            limits: .networkScale
        )
    }

    /// A repository with enough records to have several MST layers.
    private func base(count: Int = 400) async throws -> Repository {
        var repository = try await Repository.create(did: did, signer: signer)
        for start in stride(from: 0, to: count, by: 200) {
            let writes = try (start ..< min(start + 200, count)).map { index in
                PublicRepositoryWrite.create(
                    path: try path(String(format: "k%05d", index)), record: record("v\(index)")
                )
            }
            repository = try await repository.commit(writes, signer: signer).repository
        }
        return repository
    }

    @Test("creates, updates and deletes each produce a diff a stateless consumer can verify")
    func everyOperationKind() async throws {
        var repository = try await base()
        let batches: [[PublicRepositoryWrite]] = [
            [.create(path: try path("k00199x"), record: record("new"))],
            [.update(path: try path("k00010"), record: record("changed"), expectedRecordCID: nil)],
            [.delete(path: try path("k00300"), expectedRecordCID: nil)],
            [
                .create(path: try path("a-first"), record: record("first")),
                .create(path: try path("z-last"), record: record("last")),
                .update(path: try path("k00200"), record: record("changed too"), expectedRecordCID: nil),
                .delete(path: try path("k00000"), expectedRecordCID: nil),
                .delete(path: try path("k00399"), expectedRecordCID: nil),
            ],
        ]
        for batch in batches {
            let result = try await repository.commit(batch, signer: signer)
            let verified = try await verifyAsConsumer(result)
            #expect(verified.commit.descriptor.dataCID == result.repository.commit.dataCID)
            #expect(result.since == repository.revision)
            #expect(result.previousCommitCID == repository.commit.cid)
            // The diff is small: it does not grow with the repository.
            #expect(result.diffBlocks.count < 60)
            // Every new block is in the diff, and the commit leads it.
            #expect(Set(result.newBlocks.map(\.cid)).isSubset(of: Set(result.diffBlocks.map(\.cid))))
            #expect(result.diffBlocks.first?.cid == result.repository.commit.cid)
            repository = result.repository
        }
        #expect(try await repository.verify().recordCount == 400 + 3 - 3)
    }

    @Test("every single deletion and every single insertion in a small tree inverts")
    func exhaustiveSingleOperations() async throws {
        let repository = try await base(count: 60)
        for index in 0 ..< 60 {
            let deletion = try await repository.commit(
                [.delete(path: try path(String(format: "k%05d", index)), expectedRecordCID: nil)],
                signer: signer
            )
            try await verifyAsConsumer(deletion)
            let insertion = try await repository.commit(
                [.create(path: try path(String(format: "k%05d-", index)), record: record("i\(index)"))],
                signer: signer
            )
            try await verifyAsConsumer(insertion)
        }
    }

    @Test("deleting the key that holds the top layer still ships the new root")
    func trimmedRoot() async throws {
        // Find a key at depth >= 1 so that it alone forms the top layer above
        // depth-0 neighbours; deleting it trims the root down to an existing
        // child node. That node is not new to the block store, but it is the
        // root of the new tree and a consumer cannot verify without it.
        var high: String?
        var lows: [String] = []
        var candidate = 0
        while high == nil || lows.count < 6 {
            let key = String(format: "t%05d", candidate)
            candidate += 1
            let depth = try path(key).keyDepth
            if depth >= 1, high == nil {
                high = key
            } else if depth == 0, lows.count < 6 {
                lows.append(key)
            }
        }
        let top = try #require(high)
        var repository = try await Repository.create(did: did, signer: signer)
        repository = try await repository.commit(
            try (lows + [top]).map { .create(path: try path($0), record: record($0)) }, signer: signer
        ).repository

        let result = try await repository.commit(
            [.delete(path: try path(top), expectedRecordCID: nil)], signer: signer
        )
        let newRoot = result.repository.commit.dataCID
        #expect(result.diffBlocks.contains { $0.cid == newRoot })
        try await verifyAsConsumer(result)
    }

    @Test("a record re-created after deletion is in the diff even though the store still holds it")
    func recreatedRecordIsIncluded() async throws {
        let repository = try await base(count: 20)
        let original = try #require(try await repository.record(collection: collection, recordKey: "k00007"))

        let deleted = try await repository.commit(
            [.delete(path: try path("k00007"), expectedRecordCID: nil)], signer: signer
        )
        // The store keeps history, so the record block is still there.
        #expect(try await repository.store.contains(original.cid))

        let recreated = try await deleted.repository.commit(
            [.create(path: try path("k00007"), record: try original.record())], signer: signer
        )
        #expect(recreated.diffBlocks.contains { $0.cid == original.cid })
        #expect(recreated.newBlocks.contains { $0.cid == original.cid })
        // The tree is back to an earlier shape: its nodes existed in history
        // but not in the previous commit, so they are in the diff too.
        #expect(recreated.repository.commit.dataCID == repository.commit.dataCID)
        #expect(recreated.diffBlocks.contains { $0.cid == repository.commit.dataCID })
        try await verifyAsConsumer(recreated)
    }

    @Test("a record moved to a new path in one commit is in the diff")
    func movedRecordIsIncluded() async throws {
        let repository = try await base(count: 20)
        let original = try #require(try await repository.record(collection: collection, recordKey: "k00003"))
        let moved = try await repository.commit(
            [
                .delete(path: try path("k00003"), expectedRecordCID: original.cid),
                .create(path: try path("moved"), record: try original.record()),
            ],
            signer: signer
        )
        #expect(moved.diffBlocks.contains { $0.cid == original.cid })
        try await verifyAsConsumer(moved)
    }

    @Test("a diff is refused when it lies about what changed")
    func tamperedDiffsAreRefused() async throws {
        let repository = try await base(count: 50)
        let result = try await repository.commit(
            [
                .create(path: try path("added"), record: record("added")),
                .delete(path: try path("k00025"), expectedRecordCID: nil),
            ],
            signer: signer
        )
        let blocks = InMemoryRepositoryBlockStore()
        try await blocks.put(result.diffBlocks)
        let resolver = FixedRepositorySigningKey(signer.publicKey)
        let commitCID = result.repository.commit.cid
        func verify(
            operations: [RepositoryCommitOperation]? = nil,
            previous: CID? = nil,
            from source: any PublicRepositoryBlockSource
        ) async throws {
            _ = try await RepositoryCommitDiff.verify(
                commitCID: commitCID,
                operations: operations ?? result.operations,
                previousDataCID: previous ?? result.previousDataCID,
                blocks: source,
                keyResolver: resolver,
                limits: .networkScale
            )
        }
        try await verify(from: blocks)

        // An operation left out.
        await #expect(throws: RepositoryCommitDiffError.self) {
            try await verify(operations: [result.operations[0]], from: blocks)
        }
        // An operation that did not happen.
        let phantom = RepositoryCommitOperation.create(
            path: try path("phantom"), cid: CID.fromDAGCBOR(Data("x".utf8))
        )
        // (Refused either as a mismatch or, when the diff does not cover the
        // phantom key's part of the tree, as an incomplete proof.)
        await #expect(throws: RepositoryCommitDiffError.self) {
            try await verify(operations: result.operations + [phantom], from: blocks)
        }
        // A create that claims the wrong record CID.
        let wrongCID = RepositoryCommitOperation.create(
            path: try path("added"), cid: CID.fromDAGCBOR(Data("y".utf8))
        )
        await #expect(throws: RepositoryCommitDiffError.operationMismatch(path: "\(collection)/added")) {
            try await verify(operations: [wrongCID, result.operations[1]], from: blocks)
        }
        // A delete that claims the wrong previous CID changes the inverted root.
        let wrongPrevious = RepositoryCommitOperation.delete(
            path: try path("k00025"), previous: CID.fromDAGCBOR(Data("z".utf8))
        )
        await #expect(throws: RepositoryCommitDiffError.self) {
            try await verify(operations: [result.operations[0], wrongPrevious], from: blocks)
        }
        // The wrong `prevData`.
        await #expect(throws: RepositoryCommitDiffError.self) {
            try await verify(previous: result.repository.commit.dataCID, from: blocks)
        }
        // The same path twice.
        await #expect(throws: RepositoryCommitDiffError.duplicatePath(path: "\(collection)/added")) {
            try await verify(operations: result.operations + [result.operations[0]], from: blocks)
        }

        // A diff without its commit, without the created record, or signed
        // by someone else.
        let createdCID = try #require(result.operations[0].recordCID)
        for (omitted, expected) in [
            (commitCID, RepositoryCommitDiffError.missingCommit),
            (createdCID, RepositoryCommitDiffError.missingRecord(path: "\(collection)/added")),
        ] {
            let partial = InMemoryRepositoryBlockStore()
            try await partial.put(result.diffBlocks.filter { $0.cid != omitted })
            await #expect(throws: expected) { try await verify(from: partial) }
        }
        await #expect(throws: RepositoryCommitDiffError.commit(.invalidSignature)) {
            _ = try await RepositoryCommitDiff.verify(
                commitCID: commitCID,
                operations: result.operations,
                previousDataCID: result.previousDataCID,
                blocks: blocks,
                keyResolver: FixedRepositorySigningKey(K256Keypair.generate().publicKey),
                limits: .networkScale
            )
        }

        // Extra, unrelated blocks in a diff are ignored, as the
        // specification requires.
        let padded = InMemoryRepositoryBlockStore()
        try await padded.put(result.diffBlocks)
        let unrelated = Data([0xa1, 0x61, 0x78, 0x01])
        try await padded.put(PublicRepositoryBlock(cid: CID.fromDAGCBOR(unrelated), bytes: unrelated))
        try await verify(from: padded)
    }

    @Test("a #commit event verifies from its own fields, and its envelope is bound to the signed commit")
    func commitEvent() async throws {
        let repository = try await base(count: 40)
        let result = try await repository.commit(
            [
                .create(path: try path("event"), record: record("event")),
                .delete(path: try path("k00020"), expectedRecordCID: nil),
            ],
            signer: signer
        )
        let car = try await result.diffCAR()
        let commitCID = result.repository.commit.cid
        let revision = result.repository.revision.value
        let resolver = FixedRepositorySigningKey(signer.publicKey)
        func verify(
            car eventCAR: Data? = nil, commit: CID? = nil, did: String? = nil,
            revision eventRevision: String? = nil,
            resolver eventResolver: (any RepositorySigningKeyResolver)? = nil
        ) async throws {
            _ = try await RepositoryCommitDiff.verifyCommitEvent(
                blocks: eventCAR ?? car,
                commitCID: commit ?? commitCID,
                did: did ?? self.did,
                revision: eventRevision ?? revision,
                operations: result.operations,
                previousDataCID: result.previousDataCID,
                keyResolver: eventResolver ?? resolver,
                limits: .networkScale
            )
        }
        try await verify(car: car)

        // An event that names another account, another revision or another
        // commit than the one that was signed.
        await #expect(throws: RepositoryCommitDiffError.commit(.invalidDID)) {
            try await verify(did: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa")
        }
        await #expect(throws: RepositoryCommitDiffError.revisionMismatch(
            event: repository.revision.value, commit: revision
        )) {
            try await verify(revision: repository.revision.value)
        }
        await #expect(throws: RepositoryCommitDiffError.rootMismatch(
            root: commitCID, commit: repository.commit.cid
        )) {
            try await verify(commit: repository.commit.cid)
        }
        await #expect(throws: RepositoryCommitDiffError.commit(.invalidSignature)) {
            try await verify(resolver: FixedRepositorySigningKey(K256Keypair.generate().publicKey))
        }
        // Blocks that are not a CAR, or a CAR cut short.
        await #expect(throws: RepositoryCommitDiffError.self) {
            try await verify(car: Data("not a car".utf8))
        }
        await #expect(throws: RepositoryCommitDiffError.self) {
            try await verify(car: car.prefix(car.count - 7))
        }
    }

    @Test("a #sync event verifies its commit block, DID and revision")
    func syncEvent() async throws {
        let repository = try await base(count: 10)
        let commit = repository.commit
        // A #sync event's blocks hold just the signed commit.
        let car = try await PublicRepositoryCAR.encode(
            rootCID: commit.cid, blocks: [.init(cid: commit.cid, bytes: commit.bytes)]
        )
        let resolver = FixedRepositorySigningKey(signer.publicKey)
        let verified = try await RepositoryCommitDiff.verifySyncEvent(
            blocks: car, did: did, revision: commit.revision.value, keyResolver: resolver
        )
        #expect(verified.commitCID == commit.cid)
        #expect(verified.descriptor.dataCID == commit.dataCID)

        await #expect(throws: RepositoryCommitDiffError.commit(.invalidDID)) {
            try await RepositoryCommitDiff.verifySyncEvent(
                blocks: car, did: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa",
                revision: commit.revision.value, keyResolver: resolver
            )
        }
        await #expect(throws: RepositoryCommitDiffError.revisionMismatch(
            event: "3jzfcijpj2z2a", commit: commit.revision.value
        )) {
            try await RepositoryCommitDiff.verifySyncEvent(
                blocks: car, did: self.did, revision: "3jzfcijpj2z2a", keyResolver: resolver
            )
        }
        await #expect(throws: RepositoryCommitDiffError.commit(.invalidSignature)) {
            try await RepositoryCommitDiff.verifySyncEvent(
                blocks: car, did: self.did, revision: commit.revision.value,
                keyResolver: FixedRepositorySigningKey(P256Keypair.generate().publicKey)
            )
        }
        // A CAR whose root names a block it does not contain.
        let tree = try #require(try await repository.store.block(for: commit.dataCID))
        let rootless = try await PublicRepositoryCAR.encode(
            rootCID: commit.cid, blocks: [.init(cid: commit.dataCID, bytes: tree)]
        )
        await #expect(throws: RepositoryCommitDiffError.missingCommit) {
            try await RepositoryCommitDiff.verifySyncEvent(
                blocks: rootless, did: self.did, revision: commit.revision.value, keyResolver: resolver
            )
        }
        // A root that is not a commit at all.
        let notACommit = try await PublicRepositoryCAR.encode(
            rootCID: commit.dataCID, blocks: [.init(cid: commit.dataCID, bytes: tree)]
        )
        await #expect(throws: RepositoryCommitDiffError.self) {
            try await RepositoryCommitDiff.verifySyncEvent(
                blocks: notACommit, did: self.did, revision: commit.revision.value, keyResolver: resolver
            )
        }
    }

    @Test("the low-level engine reports new blocks by tree difference and carries the covering proof")
    func engineResult() async throws {
        let repository = try await base(count: 30)
        let state = try PublicRepositoryState(
            did: did,
            revision: repository.revision.value,
            commitCID: repository.commit.cid,
            dataCID: repository.commit.dataCID
        )
        let mutation = try await PublicRepositoryEngine.apply(
            repositoryDID: did,
            currentState: state,
            blocks: repository.store,
            revision: try PublicRepositoryTID.next(after: repository.revision).value,
            batch: try PublicRepositoryWriteBatch(writes: [
                .update(path: try path("k00015"), record: record("changed"), expectedRecordCID: nil),
            ]),
            signer: ATProtoRepositoryCommitSigner(signer)
        )
        #expect(mutation.previousDataCID == repository.commit.dataCID)
        #expect(mutation.newBlocks.cids.isSubset(of: mutation.relevantBlocks.cids))
        #expect(mutation.relevantBlocks.count >= mutation.newBlocks.count)
        guard case let .update(_, cid, previous) = try #require(mutation.operations.first) else {
            Issue.record("expected an update operation")
            return
        }
        #expect(cid == mutation.recordResults[0].recordCID)
        #expect(previous == mutation.recordResults[0].previousRecordCID)
        try await RepositoryCommitDiff.verifyInversion(
            dataCID: mutation.state.dataCID,
            operations: mutation.operations,
            previousDataCID: mutation.previousDataCID,
            blocks: mutation.relevantBlocks
        )
    }
}

private actor StoreSink: PublicRepositoryCARFrameSink {
    private let store: InMemoryRepositoryBlockStore

    init(store: InMemoryRepositoryBlockStore) {
        self.store = store
    }

    func receiveHeader(rootCID _: CID, receivedByteCount _: Int) async throws {}

    func receiveBlock(_ block: PublicRepositoryBlock, receivedByteCount _: Int, frameCount _: Int) async throws {
        try await store.put(block)
    }
}
