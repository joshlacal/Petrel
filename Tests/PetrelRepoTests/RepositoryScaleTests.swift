import Foundation
import Petrel
import PetrelCrypto
import PetrelRepo
import Testing

/// Repositories larger than the old fixed ceilings, and reads that used to
/// exhaust a cumulative budget.
@Suite("Repository scale and read budgets")
struct RepositoryScaleTests {
    private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    private let collection = "com.example.record"

    /// Writes a synthetic repository of `count` records straight to a CAR
    /// file: records, then the tree built bottom-up, then the signed commit.
    /// Nothing but the sorted key list is held in memory.
    private func writeSyntheticRepository(
        count: Int, to url: URL, signer: any ATProtoSigner
    ) async throws -> (commit: CID, data: CID) {
        var entries: [BulkMST.Entry] = []
        entries.reserveCapacity(count)
        var blocks: [PublicRepositoryBlock] = []
        blocks.reserveCapacity(count)
        for index in 0 ..< count {
            let path = try PublicRepositoryPath(
                collection: collection, recordKey: String(format: "r%07d", index)
            )
            let prepared = try PublicRepositoryRecordCodec.prepare(
                ["$type": .string(collection), "n": .integer(index)], for: path
            )
            entries.append(.init(path: path, recordCID: prepared.cid))
            blocks.append(.init(cid: prepared.cid, bytes: prepared.bytes))
        }
        // Keys are zero-padded, so generation order is key order.
        let data = try await BulkMST.build(entries) { blocks.append($0) }
        let commit = try await PublicRepositoryCommitCodec.prepare(
            did: did, revision: "3jzfcijpj2z2a", dataCID: data, signer: signer
        )
        let sink = try FileCARByteSink(url: url)
        _ = try await PublicRepositoryCAR.write(
            rootCID: commit.commitCID,
            blocks: ListStream([.init(cid: commit.commitCID, bytes: commit.signedCommitBytes)] + blocks),
            to: sink,
            limits: .networkScale
        )
        try await sink.synchronize()
        return (commit.commitCID, data)
    }

    @Test("a 250,000-record repository streams from disk, verifies, and enumerates")
    func quarterMillionRecords() async throws {
        let count = 250_000
        let scratch = try ScratchDirectory()
        let signer = K256Keypair.generate()
        let written = try await writeSyntheticRepository(
            count: count, to: scratch.file("large.car"), signer: signer
        )

        // The default limits read it, with blocks on disk rather than in RAM.
        let store = try FileRepositoryBlockStore(url: scratch.file("blocks"))
        let repository = try await Repository.open(
            carFile: scratch.file("large.car"),
            verification: .signingKey(signer.publicKey),
            store: store
        )
        #expect(repository.commit.cid == written.commit)
        #expect(repository.commit.dataCID == written.data)
        #expect(repository.statistics?.recordCount == count)
        #expect(try await store.blockCount() > count)

        // The conservative hosting preset still refuses it, by name: the
        // ceiling is a policy choice, no longer a property of the library.
        await #expect(throws: RepositoryError.tree(.recordLimitExceeded)) {
            try await Repository.open(
                commitCID: written.commit,
                store: store,
                verification: .signingKey(signer.publicKey),
                options: RepositoryOptions(limits: .standard)
            )
        }

        // Point lookups at both ends and in the middle.
        for index in [0, 1, count / 2, count - 1] {
            let record = try #require(
                try await repository.record(collection: collection, recordKey: String(format: "r%07d", index))
            )
            #expect(try record.record().fields["n"] == .integer(index))
        }
        #expect(try await repository.record(collection: collection, recordKey: "r9999999") == nil)

        // A write on top of it touches a handful of blocks.
        let result = try await repository.commit(
            [.create(
                path: try PublicRepositoryPath(collection: collection, recordKey: "r0125000x"),
                record: ["$type": .string(collection), "n": .integer(-1)]
            )],
            signer: signer
        )
        #expect(result.newBlocks.count < 24)
        #expect(result.repository.statistics?.recordCount == count + 1)
        let diff = InMemoryRepositoryBlockStore()
        try await diff.put(result.diffBlocks)
        _ = try await RepositoryCommitDiff.verify(
            commitCID: result.repository.commit.cid,
            operations: result.operations,
            previousDataCID: result.previousDataCID,
            blocks: diff,
            keyResolver: FixedRepositorySigningKey(signer.publicKey),
            limits: .networkScale
        )
    }

    @Test("limits are configurable up to the ceilings and report what is out of range")
    func configurableLimits() throws {
        #expect(PublicRepositoryLimits.standard.maximumRepositoryRecords == 100_000)
        #expect(PublicRepositoryLimits.networkScale.maximumRepositoryRecords == 20_000_000)
        #expect(PublicRepositoryLimits.networkScale.maximumWrites == 200)
        #expect(PublicRepositoryLimits.networkScale.maximumRelevantBlockBytes == 2_000_000)

        let custom = try PublicRepositoryLimits(
            maximumRecordBlockBytes: 4_000_000,
            maximumCARBytes: 512 * 1_024 * 1_024 * 1_024,
            maximumCARBlocks: 900_000_000,
            maximumMSTNodes: 400_000_000,
            maximumMSTEntriesPerNode: 4_096,
            maximumCBORNestingDepth: 64,
            maximumRepositoryRecords: 500_000_000,
            maximumWrites: 50_000,
            maximumRelevantBlockBytes: 1_000_000_000
        )
        #expect(custom.maximumRepositoryRecords == 500_000_000)
        #expect(custom.maximumWrites == 50_000)

        func limits(records: Int = 1, writes: Int = 1, diff: Int = 1) throws -> PublicRepositoryLimits {
            try PublicRepositoryLimits(
                maximumRecordBlockBytes: 1_000_000,
                maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
                maximumCARBlocks: 10,
                maximumMSTNodes: 10,
                maximumMSTEntriesPerNode: 10,
                maximumCBORNestingDepth: 10,
                maximumRepositoryRecords: records,
                maximumWrites: writes,
                maximumRelevantBlockBytes: diff
            )
        }
        #expect(throws: PublicRepositoryLimitError.maximumRepositoryRecordsOutOfRange) {
            try limits(records: PublicRepositoryLimits.maximumPermittedRepositoryRecords + 1)
        }
        #expect(throws: PublicRepositoryLimitError.maximumRepositoryRecordsOutOfRange) {
            try limits(records: 0)
        }
        #expect(throws: PublicRepositoryLimitError.maximumWritesOutOfRange) {
            try limits(writes: 0)
        }
        #expect(throws: PublicRepositoryLimitError.maximumRelevantBlockBytesOutOfRange) {
            try limits(diff: PublicRepositoryLimits.maximumPermittedCARBytes + 1)
        }
    }

    @Test("a bulk commit larger than the firehose defaults works once the limits are raised")
    func bulkCommit() async throws {
        let signer = P256Keypair.generate()
        let writes = try (0 ..< 1_000).map { index in
            PublicRepositoryWrite.create(
                path: try PublicRepositoryPath(collection: collection, recordKey: String(format: "b%05d", index)),
                record: ["$type": .string(collection), "n": .integer(index)]
            )
        }
        let defaults = try await Repository.create(did: did, signer: signer)
        await #expect(throws: RepositoryError.invalidWrites(.tooManyWrites)) {
            try await defaults.commit(writes, signer: signer)
        }

        let bulkLimits = try PublicRepositoryLimits(
            maximumRecordBlockBytes: 1_000_000,
            maximumCARBytes: 1_024 * 1_024 * 1_024,
            maximumCARBlocks: 1_000_000,
            maximumMSTNodes: 500_000,
            maximumMSTEntriesPerNode: 4_096,
            maximumCBORNestingDepth: 64,
            maximumRepositoryRecords: 1_000_000,
            maximumWrites: 10_000,
            maximumRelevantBlockBytes: 64 * 1_024 * 1_024
        )
        let bulk = try await Repository.create(
            did: did, signer: signer, options: RepositoryOptions(limits: bulkLimits)
        )
        let result = try await bulk.commit(writes, signer: signer)
        #expect(try await result.repository.verify().recordCount == 1_000)
    }

    @Test("repeated reads of a loaded tree cost the same every time")
    func repeatedReadsDoNotExhaustABudget() async throws {
        // A 50,000-leaf tree: its nodes total well over the 2 MB commit-diff
        // budget that reads used to be charged against.
        let leaf = CID.fromDAGCBOR(Data("leaf".utf8))
        var entries: [BulkMST.Entry] = []
        for index in 0 ..< 50_000 {
            entries.append(.init(
                path: try PublicRepositoryPath(collection: collection, recordKey: String(format: "k%06d", index)),
                recordCID: leaf
            ))
        }
        let store = InMemoryRepositoryBlockStore()
        let root = try await BulkMST.build(entries) { try await store.put($0) }
        #expect(await store.storedByteCount > 2_000_000)

        let tree = try RepositoryMST.load(rootCID: root, blocks: store)
        let target = entries[31_337].path
        // Each lookup reads about 20 KB of nodes, so a cumulative 2 MB
        // budget would be spent after roughly a hundred of them.
        for _ in 0 ..< 2_000 {
            #expect(try await tree.get(target) == leaf)
        }
        let listed = try await tree.listed()
        #expect(listed.count == 50_000)
        #expect(listed.map(\.path.mstKey) == entries.map(\.path.mstKey))
        // And again, on the same value.
        #expect(try await tree.listed().count == 50_000)

        // The incremental algorithm and the bottom-up oracle agree on a
        // tree with many layers.
        var incremental = try RepositoryMST.empty()
        for entry in entries.prefix(2_000) {
            incremental = try await incremental.adding(path: entry.path, recordCID: entry.recordCID)
        }
        let oracle = try await BulkMST.build(Array(entries.prefix(2_000))) { _ in }
        #expect(try await incremental.rootCID() == oracle)
    }
}

private actor ListStream: PublicRepositoryCARBlockStream {
    private var blocks: [PublicRepositoryBlock]
    private var index = 0

    init(_ blocks: [PublicRepositoryBlock]) {
        self.blocks = blocks
    }

    func nextBlock() async throws -> PublicRepositoryBlock? {
        guard index < blocks.count else { return nil }
        defer { index += 1 }
        return blocks[index]
    }
}
