import Foundation
import Petrel
import PetrelCrypto
@testable import PetrelRepo
import Testing

/// A commit must never leave a repository that its own options refuse to
/// verify, export or reopen. Every whole-repository limit those paths
/// enforce is checked on the new tree before the commit is signed.
@Suite("Repository commit limits")
struct RepositoryCommitLimitTests {
    private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    private let posts = "app.bsky.feed.post"

    private func path(_ key: String) throws -> PublicRepositoryPath {
        try PublicRepositoryPath(collection: posts, recordKey: key)
    }

    private func create(_ key: String) throws -> PublicRepositoryWrite {
        .create(path: try path(key), record: .sample(posts, text: key))
    }

    private func delete(_ key: String) throws -> PublicRepositoryWrite {
        .delete(path: try path(key), expectedRecordCID: nil)
    }

    private func options(
        records: Int = 1_000, mstNodes: Int = 1_000, carBlocks: Int = 1_000,
        blockBytes: Int = 1_000_000, policy: RepositoryReadPolicy = .dataModel
    ) throws -> RepositoryOptions {
        RepositoryOptions(limits: try PublicRepositoryLimits(
            maximumRecordBlockBytes: blockBytes,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: carBlocks,
            maximumMSTNodes: mstNodes,
            maximumMSTEntriesPerNode: 64,
            maximumCBORNestingDepth: 64,
            maximumRepositoryRecords: records
        ), policy: policy)
    }

    /// Everything a successful commit must leave readable under `options`.
    private func expectReadable(_ repository: Repository, signer: K256Keypair) async throws {
        let statistics = try await repository.verify()
        let car = try await repository.exportCAR()
        let reopened = try await Repository.open(
            car: car, verification: .signingKey(signer.publicKey), options: repository.options
        )
        #expect(reopened.statistics == statistics)
        // The tracked footprint is exact, not an estimate.
        let footprint = try #require(repository.footprint)
        #expect(footprint.records == statistics.recordCount)
        #expect(footprint.mstNodes == statistics.mstNodeCount)
        #expect(repository.statistics?.mstNodeCount == statistics.mstNodeCount)
        #expect(try footprint.exportedByteCount(commit: repository.commit) == car.count)
    }

    @Test("Codex repro: 18, 17, 19 under maximumMSTNodes 2 refuses the third-node tree unsigned")
    func mstNodeLimit() async throws {
        let signer = K256Keypair.generate()
        let options = try options(mstNodes: 2)
        let store = InMemoryRepositoryBlockStore()
        var repository = try await Repository.create(did: did, signer: signer, store: store, options: options)
        repository = try await repository.commit([try create("18")], signer: signer).repository
        try await expectReadable(repository, signer: signer)
        repository = try await repository.commit([try create("17")], signer: signer).repository
        try await expectReadable(repository, signer: signer)

        let storedBefore = try await store.storedCIDs().count
        let counting = CountingSigner(signer)
        await #expect(throws: RepositoryError.limitExceeded(.mstNodes, limit: 2)) {
            try await repository.commit([try self.create("19")], signer: counting)
        }
        #expect(counting.signatures == 0)
        #expect(try await store.storedCIDs().count == storedBefore)
        try await expectReadable(repository, signer: signer)

        // The same refusal when the repository was opened without a walk.
        let unwalked = try await Repository.open(
            commitCID: repository.commit.cid, store: store,
            verification: .signingKey(signer.publicKey), options: options, verifiesTree: false
        )
        await #expect(throws: RepositoryError.limitExceeded(.mstNodes, limit: 2)) {
            try await unwalked.commit([try self.create("19")], signer: signer)
        }
    }

    @Test("records and CAR blocks are checked on the resulting tree, deletes included")
    func recordAndBlockLimits() async throws {
        let signer = K256Keypair.generate()
        let store = InMemoryRepositoryBlockStore()
        let records = try options(records: 2)
        let one = try await Repository.create(did: did, signer: signer, store: store, options: records)
            .commit([try create("a")], signer: signer).repository
        await #expect(throws: RepositoryError.limitExceeded(.records, limit: 2)) {
            try await one.commit([try self.create("b"), try self.create("c")], signer: signer)
        }
        let full = try await one.commit([try create("b")], signer: signer).repository
        try await expectReadable(full, signer: signer)
        let swapped = try await full.commit([try delete("a"), try create("c")], signer: signer).repository
        try await expectReadable(swapped, signer: signer)

        // An export holds the commit, every node and every record. Reopen a
        // two-record repository with a block budget it fills exactly: one
        // more record needs at least one more block.
        let wide = try options()
        let two = try await Repository.create(did: did, signer: signer, options: wide)
            .commit([try create("a"), try create("b")], signer: signer).repository
        let nodes = try await two.verify().mstNodeCount
        let budget = 1 + nodes + 2
        let tight = try options(mstNodes: budget, carBlocks: budget)
        let exact = try await Repository.open(
            commitCID: two.commit.cid, store: two.store,
            verification: .signingKey(signer.publicKey), options: tight
        )
        try await expectReadable(exact, signer: signer)
        await #expect(throws: RepositoryError.limitExceeded(.carBlocks, limit: budget)) {
            try await exact.commit([try self.create("c")], signer: signer)
        }
    }

    @Test("a long mixed history stays exactly tracked and readable at every step")
    func trackedThroughHistory() async throws {
        let signer = K256Keypair.generate()
        var repository = try await Repository.create(did: did, signer: signer, options: options(mstNodes: 12))
        var live: [String] = []
        var refused = 0
        for step in 0 ..< 120 {
            let key = String(format: "k%05d", (step * 7_919) % 10_007)
            let victim = step % 3 == 2 ? live.first : nil
            var writes = [try create(key)]
            if let victim { writes.append(try delete(victim)) }
            do {
                repository = try await repository.commit(writes, signer: signer).repository
                live.append(key)
                if victim != nil { live.removeFirst() }
            } catch RepositoryError.limitExceeded(.mstNodes, limit: 12) {
                refused += 1
            }
            try await expectReadable(repository, signer: signer)
        }
        #expect(refused > 0, "the history should reach the node limit")
        #expect(refused < 120, "and still make progress")
    }
}

extension RepositoryCommitLimitTests {
    @Test("Codex repro: depth-zero keys under maximumRecordBlockBytes 256 refuse the oversized MST node unsigned")
    func mstBlockSizeLimit() async throws {
        let signer = K256Keypair.generate()
        let options = try options(blockBytes: 256)
        let store = InMemoryRepositoryBlockStore()
        var repository = try await Repository.create(did: did, signer: signer, store: store, options: options)
        var refusedKey: String?
        for key in ["0", "1", "2", "4", "5", "6", "7", "8"] {
            let storedBefore = try await store.storedCIDs().count
            let counting = CountingSigner(signer)
            do {
                repository = try await repository.commit([try create(key)], signer: counting).repository
            } catch RepositoryError.limitExceeded(.blockBytes, limit: 256) {
                #expect(counting.signatures == 0)
                #expect(try await store.storedCIDs().count == storedBefore)
                refusedKey = key
                break
            }
            // Every accepted commit stays exportable and provable.
            try await expectReadable(repository, signer: signer)
            let proof = try await repository.recordProof(collection: posts, recordKey: key)
            _ = try await proof.car()
        }
        #expect(refusedKey != nil, "one node holding all eight keys exceeds 256 bytes")
        try await expectReadable(repository, signer: signer)
    }

    @Test("create refuses a first commit its own limits could not export")
    func createChecksLimits() async throws {
        let signer = K256Keypair.generate()
        // The signed commit block alone is larger than 64 bytes.
        let store = InMemoryRepositoryBlockStore()
        await #expect(throws: RepositoryError.limitExceeded(.blockBytes, limit: 64)) {
            try await Repository.create(
                did: self.did, signer: signer, store: store, options: try self.options(blockBytes: 64)
            )
        }
        #expect(try await store.storedCIDs().isEmpty)
        // An export of an empty repository is two blocks: commit and root.
        await #expect(throws: RepositoryError.limitExceeded(.carBlocks, limit: 1)) {
            try await Repository.create(
                did: self.did, signer: signer, options: try self.options(mstNodes: 1, carBlocks: 1)
            )
        }
        let minimal = try await Repository.create(
            did: did, signer: signer, options: try options(mstNodes: 1, carBlocks: 2)
        )
        try await expectReadable(minimal, signer: signer)
    }

    @Test("a record the repository's own read policy refuses is not committed")
    func recordReadPolicy() async throws {
        let signer = K256Keypair.generate()
        let repository = try await Repository.create(did: did, signer: signer, options: options(policy: .strict))
        // The strict policy caps containers at 65,536 elements; the writer
        // has no such cap, and 70,000 zeros fit the block budget.
        let wide: PublicRecord = [
            "$type": .string(posts),
            "values": .array(Array(repeating: .integer(0), count: 70_000)),
        ]
        let path = try path("wide")
        let counting = CountingSigner(signer)
        await #expect(throws: RepositoryError.invalidRecord(path: path.mstKey)) {
            try await repository.commit([.create(path: path, record: wide)], signer: counting)
        }
        #expect(counting.signatures == 0)
        // The same record is fine under the data-model policy.
        let tolerant = try await Repository.create(did: did, signer: signer, options: options())
        let written = try await tolerant.commit([.create(path: path, record: wide)], signer: signer).repository
        try await expectReadable(written, signer: signer)
    }
}

/// Counts signatures so a test can prove a refused commit was never signed.
private final class CountingSigner: ATProtoSigner, @unchecked Sendable {
    private let base: K256Keypair
    private let lock = NSLock()
    private var count = 0

    init(_ base: K256Keypair) { self.base = base }

    var curve: ATProtoKeyCurve { base.curve }

    var signatures: Int {
        lock.withLock { count }
    }

    func sign(_ message: Data) async throws -> Data {
        lock.withLock { count += 1 }
        return try base.sign(message)
    }
}
