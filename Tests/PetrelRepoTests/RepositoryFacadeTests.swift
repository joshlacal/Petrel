import Foundation
import Petrel
import PetrelCrypto
import PetrelRepo
import Testing

/// The `Repository` type end to end on repositories built in the test.
@Suite("Repository")
struct RepositoryFacadeTests {
    private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    private let posts = "app.bsky.feed.post"
    private let likes = "app.bsky.feed.like"

    private func path(_ collection: String, _ key: String) throws -> PublicRepositoryPath {
        try PublicRepositoryPath(collection: collection, recordKey: key)
    }

    private func create(_ collection: String, _ key: String, _ text: String) throws -> PublicRepositoryWrite {
        .create(path: try path(collection, key), record: .sample(collection, text: text))
    }

    /// A repository with `count` posts and a few likes, committed in batches.
    private func populated(
        signer: any ATProtoKeypair, count: Int = 300, store: any RepositoryBlockStore = InMemoryRepositoryBlockStore()
    ) async throws -> Repository {
        var repository = try await Repository.create(did: did, signer: signer, store: store)
        var writes: [PublicRepositoryWrite] = []
        for index in 0 ..< count {
            writes.append(try create(posts, String(format: "post%05d", index), "post \(index)"))
        }
        for index in 0 ..< 5 {
            writes.append(try create(likes, "like\(index)", "like \(index)"))
        }
        for batch in stride(from: 0, to: writes.count, by: 150) {
            repository = try await repository.commit(
                Array(writes[batch ..< min(batch + 150, writes.count)]), signer: signer
            ).repository
        }
        return repository
    }

    @Test("create, write, read, export and re-open on both curves")
    func lifecycleOnBothCurves() async throws {
        let signers: [any ATProtoKeypair] = [K256Keypair.generate(), P256Keypair.generate()]
        for signer in signers {
            let empty = try await Repository.create(did: did, signer: signer)
            #expect(empty.statistics?.recordCount == 0)
            #expect(empty.commit.dataCID.string == PublicRepositoryGenesisCodec.canonicalEmptyMSTCID)
            #expect(try await empty.collections().isEmpty)

            let repository = try await populated(signer: signer)
            #expect(repository.did == did)
            #expect(try await repository.collections() == [likes, posts])
            #expect(try await repository.records(collection: likes).map(\.recordKey)
                == ["like0", "like1", "like2", "like3", "like4"])

            let record = try #require(try await repository.record(collection: posts, recordKey: "post00042"))
            #expect(try record.record() == PublicRecord.sample(posts, text: "post 42"))
            #expect(try await repository.recordCID(collection: posts, recordKey: "post00042") == record.cid)
            #expect(try await repository.record(collection: posts, recordKey: "missing") == nil)

            // Every export order re-opens to the same verified repository.
            for order in [RepositoryCARBlockOrder.streamable, .breadthFirst, .stored] {
                let car = try await repository.exportCAR(order: order)
                let reopened = try await Repository.open(
                    car: car, verification: .signingKey(signer.publicKey), expectedDID: did
                )
                #expect(reopened.commit.cid == repository.commit.cid, "\(order)")
                #expect(reopened.statistics?.recordCount == 305, "\(order)")
                #expect(reopened.commit.isSignatureVerified)
            }
            // A different key does not open it; skipping the check is explicit.
            let car = try await repository.exportCAR()
            await #expect(throws: RepositoryError.commit(.invalidSignature)) {
                try await Repository.open(car: car, verification: .signingKey(K256Keypair.generate().publicKey))
            }
            let unauthenticated = try await Repository.open(car: car, verification: .unauthenticated)
            #expect(!unauthenticated.commit.isSignatureVerified)
            #expect(unauthenticated.statistics?.recordCount == 305)
        }
    }

    @Test("the streamable export is the specification's pre-order: commit, then each node before its entries")
    func streamableOrder() async throws {
        let signer = K256Keypair.generate()
        let repository = try await populated(signer: signer, count: 120)
        let car = try await repository.exportCAR(order: .streamable)

        // Read the frames back in file order.
        let frames = FrameRecorder()
        _ = try await PublicRepositoryCAR.parseIncrementally(
            from: DataCARByteSource(car), to: frames, limits: .networkScale, policy: .dataModel
        )
        let order = await frames.cids
        #expect(order.first == repository.commit.cid)
        #expect(order.dropFirst().first == repository.commit.dataCID)

        // Walking the tree and consuming blocks strictly in file order must
        // never need a block that has not been seen yet: that is what makes
        // the order streamable.
        var position: [CID: Int] = [:]
        for (index, cid) in order.enumerated() where position[cid] == nil { position[cid] = index }
        var cursor = 1
        try await RepositoryMSTWalker.walk(
            rootCID: repository.commit.dataCID,
            blocks: repository.store,
            onNode: { block in
                #expect(position[block.cid] == cursor)
                cursor += 1
            },
            onLeaf: { leaf in
                #expect(position[leaf.recordCID] == cursor)
                cursor += 1
                return true
            }
        )
        #expect(cursor == order.count)
    }

    @Test("revisions always increase, even when the clock does not")
    func revisionsAreMonotonic() async throws {
        let signer = P256Keypair.generate()
        var repository = try await Repository.create(did: did, signer: signer)
        var previous = repository.revision
        for index in 0 ..< 50 {
            repository = try await repository.commit(
                [try create(posts, "rev\(index)", "x")], signer: signer
            ).repository
            #expect(previous < repository.revision)
            previous = repository.revision
        }
        // A revision that does not increase is refused.
        await #expect(throws: RepositoryError.write(.revisionNotIncreasing)) {
            try await repository.commit(
                [try create(posts, "late", "x")], signer: signer, revision: previous
            )
        }
    }

    @Test("TID allocation never repeats or goes backwards under a frozen or regressing clock")
    func tidAllocation() throws {
        let frozen = Date(timeIntervalSince1970: 1_700_000_000)
        var previous = try PublicRepositoryTID.next(after: nil, now: frozen, clockID: 5)
        #expect(previous.microsecondsSinceEpoch == 1_700_000_000_000_000)
        #expect(previous.clockID == 5)
        #expect(previous.date == frozen)
        var seen = Set<String>([previous.value])
        var violations = 0
        for step in 0 ..< 100_000 {
            // The clock is frozen for most calls and steps backwards on some.
            let now = step % 7 == 0 ? frozen.addingTimeInterval(-3_600) : frozen
            let next = try PublicRepositoryTID.next(after: previous, now: now)
            if !(previous < next) || !seen.insert(next.value).inserted { violations += 1 }
            previous = next
        }
        #expect(violations == 0)
        #expect(seen.count == 100_001)
        #expect(previous.microsecondsSinceEpoch > 1_700_000_000_000_000)
        // When the clock moves forward again, so does the timestamp.
        let later = try PublicRepositoryTID.next(after: previous, now: frozen.addingTimeInterval(60))
        #expect(later.microsecondsSinceEpoch == 1_700_000_060_000_000)

        // Field round trip and the spec's leading-character rule.
        let parsed = try PublicRepositoryTID("3jzfcijpj2z2a")
        let rebuilt = try PublicRepositoryTID(
            microsecondsSinceEpoch: parsed.microsecondsSinceEpoch, clockID: parsed.clockID
        )
        #expect(rebuilt == parsed)
        #expect(try PublicRepositoryTID("bzzzzzzzzzzzz").microsecondsSinceEpoch == (1 << 53) - 1)
        #expect(try PublicRepositoryTID("bzzzzzzzzzzzz").clockID == 1_023)
        #expect(throws: PublicRepositoryDomainError.invalidRevision) {
            try PublicRepositoryTID(microsecondsSinceEpoch: 1 << 53, clockID: 0)
        }
        #expect(throws: PublicRepositoryDomainError.invalidRevision) {
            try PublicRepositoryTID(microsecondsSinceEpoch: 0, clockID: 1_024)
        }

        // Revisions from the future are flagged, with a drift allowance.
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let ahead = try PublicRepositoryTID.next(after: nil, now: now.addingTimeInterval(3_600))
        #expect(ahead.isInFuture(comparedTo: now))
        #expect(!ahead.isInFuture(comparedTo: now, tolerance: 7_200))
        #expect(!previous.isInFuture(comparedTo: now))
    }

    @Test("an empty commit re-signs the unchanged tree (signing-key rotation)")
    func emptyCommit() async throws {
        let oldKey = K256Keypair.generate()
        let newKey = P256Keypair.generate()
        let repository = try await populated(signer: oldKey, count: 20)
        let result = try await repository.commit([], signer: newKey)
        #expect(result.operations.isEmpty)
        #expect(result.repository.commit.dataCID == repository.commit.dataCID)
        #expect(result.repository.commit.cid != repository.commit.cid)
        #expect(result.repository.revision > repository.revision)
        #expect(result.newBlocks.map(\.cid) == [result.repository.commit.cid])

        let car = try await result.repository.exportCAR()
        _ = try await Repository.open(car: car, verification: .signingKey(newKey.publicKey))
        await #expect(throws: RepositoryError.commit(.invalidSignature)) {
            try await Repository.open(car: car, verification: .signingKey(oldKey.publicKey))
        }
    }

    @Test("compare-and-swap on the head commit and on record CIDs")
    func compareAndSwap() async throws {
        let signer = K256Keypair.generate()
        let first = try await populated(signer: signer, count: 3)
        let second = try await first.commit([try create(posts, "extra", "x")], signer: signer).repository

        // `first` is stale: writing against it with a swap check fails.
        await #expect(throws: RepositoryError.write(.commitCIDMismatch)) {
            try await second.commit(
                [try create(posts, "other", "x")], signer: signer, expectedCommitCID: first.commit.cid
            )
        }
        let stale = CID.fromDAGCBOR(Data("stale".utf8))
        await #expect(throws: RepositoryError.write(.recordCIDMismatch)) {
            try await second.commit(
                [.delete(path: try path(posts, "extra"), expectedRecordCID: stale)], signer: signer
            )
        }
        await #expect(throws: RepositoryError.write(.recordAlreadyExists)) {
            try await second.commit([try create(posts, "extra", "again")], signer: signer)
        }
        await #expect(throws: RepositoryError.write(.recordNotFound)) {
            try await second.commit(
                [.delete(path: try path(posts, "nope"), expectedRecordCID: nil)], signer: signer
            )
        }
        await #expect(throws: RepositoryError.invalidWrites(.duplicateWritePath)) {
            try await second.commit(
                [try create(posts, "dup", "a"), try create(posts, "dup", "b")], signer: signer
            )
        }
        // A failed write leaves the head where it was.
        #expect(try await second.verify().recordCount == 9)
    }

    @Test("a commit that would exceed maximumRepositoryRecords is refused before anything is signed or stored")
    func commitRespectsRecordLimit() async throws {
        let signer = K256Keypair.generate()
        let options = RepositoryOptions(limits: try PublicRepositoryLimits(
            maximumRecordBlockBytes: 1_000_000,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: 1_000,
            maximumMSTNodes: 1_000,
            maximumMSTEntriesPerNode: 64,
            maximumCBORNestingDepth: 64,
            maximumRepositoryRecords: 2
        ))
        let store = InMemoryRepositoryBlockStore()
        let empty = try await Repository.create(did: did, signer: signer, store: store, options: options)
        let one = try await empty.commit([try create(posts, "a", "a")], signer: signer).repository

        // Known count (statistics carried from create).
        await #expect(throws: RepositoryError.limitExceeded(.records, limit: 2)) {
            try await one.commit(
                [try self.create(self.posts, "b", "b"), try self.create(self.posts, "c", "c")], signer: signer
            )
        }
        // Unknown count: reopened without walking the tree.
        let reopened = try await Repository.open(
            commitCID: one.commit.cid, store: store, verification: .signingKey(signer.publicKey),
            options: options, verifiesTree: false
        )
        #expect(reopened.statistics == nil)
        await #expect(throws: RepositoryError.limitExceeded(.records, limit: 2)) {
            try await reopened.commit(
                [try self.create(self.posts, "b", "b"), try self.create(self.posts, "c", "c")], signer: signer
            )
        }
        // Reaching the limit exactly is fine, and a delete makes room again.
        let full = try await reopened.commit([try create(posts, "b", "b")], signer: signer).repository
        #expect(try await full.verify().recordCount == 2)
        let swapped = try await full.commit(
            [.delete(path: try path(posts, "a"), expectedRecordCID: nil), try create(posts, "c", "c")],
            signer: signer
        ).repository
        #expect(try await swapped.verify().recordCount == 2)
    }

    @Test("a record proof serializes under the repository's own limits")
    func recordProofCarriesRepositoryLimits() async throws {
        // 1.5 MB: allowed by networkScale (2 MB blocks), refused by standard (1 MB).
        let signer = K256Keypair.generate()
        var repository = try await Repository.create(did: did, signer: signer)
        let large: PublicRecord = ["$type": .string(posts), "text": .string(String(repeating: "x", count: 1_500_000))]
        repository = try await repository.commit(
            [.create(path: try path(posts, "large"), record: large)], signer: signer
        ).repository

        let proof = try await repository.recordProof(collection: posts, recordKey: "large")
        let proven = try await Repository.verifyRecordProof(
            car: try await proof.car(), did: did, collection: posts, recordKey: "large",
            verification: .signingKey(signer.publicKey)
        )
        #expect(try proven.record?.record() == large)
        // An explicit, tighter policy still applies when asked for.
        await #expect(throws: PublicRepositoryCARError.self) {
            try await proof.car(limits: .standard)
        }
    }

    @Test("record proofs: inclusion and exclusion, built and verified")
    func recordProofs() async throws {
        let signer = K256Keypair.generate()
        let repository = try await populated(signer: signer)
        let verification = RepositoryCommitVerification.signingKey(signer.publicKey)

        let inclusion = try await repository.recordProof(collection: posts, recordKey: "post00123")
        #expect(inclusion.recordCID != nil)
        #expect(inclusion.blocks.first?.cid == repository.commit.cid)
        // A proof is a small fraction of the repository.
        #expect(inclusion.blocks.count < 12)
        let proven = try await Repository.verifyRecordProof(
            car: try await inclusion.car(), did: did,
            collection: posts, recordKey: "post00123", verification: verification
        )
        #expect(try proven.record?.record() == PublicRecord.sample(posts, text: "post 123"))

        let exclusion = try await repository.recordProof(collection: posts, recordKey: "post00123x")
        #expect(exclusion.recordCID == nil)
        let absent = try await Repository.verifyRecordProof(
            car: try await exclusion.car(), did: did,
            collection: posts, recordKey: "post00123x", verification: verification
        )
        #expect(absent.record == nil)

        // Removing any MST node from an exclusion proof must not turn into
        // a different answer: it has to throw.
        for index in exclusion.blocks.indices.dropFirst() {
            var blocks = exclusion.blocks
            blocks.remove(at: index)
            let car = try await PublicRepositoryCAR.encode(rootCID: exclusion.commitCID, blocks: blocks)
            await #expect(throws: RepositoryError.tree(.missingBlock)) {
                try await Repository.verifyRecordProof(
                    car: car, did: self.did, collection: self.posts,
                    recordKey: "post00123x", verification: verification
                )
            }
        }
        // An inclusion proof with the record block removed is incomplete.
        let withoutRecord = try await PublicRepositoryCAR.encode(
            rootCID: inclusion.commitCID, blocks: Array(inclusion.blocks.dropLast())
        )
        await #expect(throws: RepositoryError.missingRecordBlock(path: "\(posts)/post00123")) {
            try await Repository.verifyRecordProof(
                car: withoutRecord, did: self.did, collection: self.posts,
                recordKey: "post00123", verification: verification
            )
        }
    }

    @Test("the file-backed store holds a repository across a restart")
    func fileBackedStore() async throws {
        let scratch = try ScratchDirectory()
        let signer = K256Keypair.generate()
        let head: CID
        do {
            let store = try FileRepositoryBlockStore(url: scratch.file("blocks"))
            let repository = try await populated(signer: signer, store: store)
            head = repository.commit.cid
            #expect(try await store.blockCount() > 305)
        }
        // A new store object over the same file rebuilds its index.
        let reopenedStore = try FileRepositoryBlockStore(url: scratch.file("blocks"))
        let repository = try await Repository.open(
            commitCID: head, store: reopenedStore,
            verification: .signingKey(signer.publicKey), expectedDID: did
        )
        #expect(repository.statistics?.recordCount == 305)
        // And it keeps accepting writes.
        let next = try await repository.commit([try create(posts, "after-restart", "x")], signer: signer)
        #expect(try await next.repository.verify().recordCount == 306)
    }

    @Test("an in-memory archive and a file give the same repository")
    func openFromFile() async throws {
        let scratch = try ScratchDirectory()
        let signer = P256Keypair.generate()
        let repository = try await populated(signer: signer, count: 40)
        let sink = try FileCARByteSink(url: scratch.file("repo.car"))
        try await repository.exportCAR(to: sink)
        try await sink.synchronize()

        let fromFile = try await Repository.open(
            carFile: scratch.file("repo.car"),
            verification: .keyResolver(FixedRepositorySigningKey(signer.publicKey)),
            store: try FileRepositoryBlockStore(url: scratch.file("blocks"))
        )
        #expect(fromFile.commit.cid == repository.commit.cid)
        let expected = try await repository.verify()
        #expect(fromFile.statistics == expected)
    }
}

/// Records the CID of every frame in file order.
private actor FrameRecorder: PublicRepositoryCARFrameSink {
    private(set) var cids: [CID] = []

    func receiveHeader(rootCID _: CID, receivedByteCount _: Int) async throws {}

    func receiveBlock(_ block: PublicRepositoryBlock, receivedByteCount _: Int, frameCount _: Int) async throws {
        cids.append(block.cid)
    }
}
