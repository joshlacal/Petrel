import Foundation
import Petrel
import PetrelRepo
import Testing

/// Official `firehose/commit-proof-fixtures.json`, read from disk and run in
/// full. Each fixture names a tree, a set of adds and deletes, the roots
/// before and after, and the exact set of MST node CIDs a commit diff must
/// carry so that a consumer can invert the operations.
@Suite("Commit proof fixtures (sync v1.1 operation inversion)")
struct CommitProofFixtureTests {
    private struct Fixture: Decodable {
        let comment: String
        let leafValue: String
        let keys: [String]
        let adds: [String]
        let dels: [String]
        let rootBeforeCommit: String
        let rootAfterCommit: String
        let blocksInProof: [String]
    }

    private let options = RepositoryMSTOptions(keySyntax: .mstKey)

    private func fixtures() throws -> [Fixture] {
        try Vectors.decode([Fixture].self, "firehose/commit-proof-fixtures.json")
    }

    private func path(_ key: String) throws -> PublicRepositoryPath {
        try PublicRepositoryPath(mstKey: key, syntax: .mstKey)
    }

    /// Builds the fixture's "before" tree and applies its adds and deletes,
    /// keeping every block in one store.
    private func run(_ fixture: Fixture) async throws -> (
        before: CID, after: CID, tree: RepositoryMST, store: InMemoryRepositoryBlockStore
    ) {
        let leaf = try CID.parseBlessed(fixture.leafValue, kind: .dagCBOR)
        let store = InMemoryRepositoryBlockStore()
        var tree = try RepositoryMST.empty(options: options)
        for key in fixture.keys {
            tree = try await tree.adding(path: try path(key), recordCID: leaf)
        }
        let before = try await tree.materialized()
        try await store.put(before.newBlocks.orderedBlocks)

        var next = try RepositoryMST.load(rootCID: before.rootCID, blocks: store, options: options)
        for key in fixture.adds {
            next = try await next.adding(path: try path(key), recordCID: leaf)
        }
        for key in fixture.dels {
            next = try await next.deleting(path: try path(key))
        }
        let after = try await next.materialized()
        try await store.put(after.newBlocks.orderedBlocks)
        return (before.rootCID, after.rootCID, next, store)
    }

    private func operations(for fixture: Fixture, leaf: CID) throws -> [RepositoryCommitOperation] {
        var operations: [RepositoryCommitOperation] = []
        for key in fixture.adds {
            operations.append(.create(path: try path(key), cid: leaf))
        }
        for key in fixture.dels {
            operations.append(.delete(path: try path(key), previous: leaf))
        }
        return operations
    }

    @Test("the file holds the six upstream fixtures")
    func fixtureCount() throws {
        #expect(try fixtures().count == 6)
    }

    @Test("roots before and after the commit match")
    func roots() async throws {
        for fixture in try fixtures() {
            let result = try await run(fixture)
            #expect(result.before.string == fixture.rootBeforeCommit, "\(fixture.comment)")
            #expect(result.after.string == fixture.rootAfterCommit, "\(fixture.comment)")
        }
    }

    @Test("the covering proof is exactly blocksInProof")
    func coveringProof() async throws {
        for fixture in try fixtures() {
            let result = try await run(fixture)
            let paths = try (fixture.adds + fixture.dels).map(path)
            let proof = try await result.tree.coveringProof(for: paths)
            #expect(
                Set(proof.map(\.cid.string)) == Set(fixture.blocksInProof),
                "\(fixture.comment)"
            )
            // The same set through the block-source entry point.
            var viaSource = Set<String>()
            for path in paths {
                for block in try await RepositoryMSTProof.coveringProof(
                    rootCID: result.after, path: path, blocks: result.store, options: options
                ) {
                    viaSource.insert(block.cid.string)
                }
            }
            #expect(viaSource == Set(fixture.blocksInProof), "\(fixture.comment)")
        }
    }

    @Test("the operations invert to the previous root using only the proof blocks")
    func inversion() async throws {
        for fixture in try fixtures() {
            let result = try await run(fixture)
            let leaf = try CID.parseBlessed(fixture.leafValue, kind: .dagCBOR)
            // A consumer holds only the blocks named by the fixture.
            let proofOnly = InMemoryRepositoryBlockStore()
            for cid in fixture.blocksInProof {
                let parsed = try CID.parseBlessed(cid, kind: .dagCBOR)
                let bytes = try #require(try await result.store.block(for: parsed))
                try await proofOnly.put(.init(cid: parsed, bytes: bytes))
            }
            let operations = try operations(for: fixture, leaf: leaf)

            try await RepositoryCommitDiff.verifyInversion(
                dataCID: result.after,
                operations: operations,
                previousDataCID: result.before,
                blocks: proofOnly,
                options: options
            )

            // A wrong `prevData` is refused.
            await #expect(throws: RepositoryCommitDiffError.self, "\(fixture.comment)") {
                try await RepositoryCommitDiff.verifyInversion(
                    dataCID: result.after,
                    operations: operations,
                    previousDataCID: result.after,
                    blocks: proofOnly,
                    options: options
                )
            }

            // An operation list that omits one change is refused: the
            // inverted root no longer equals `prevData`.
            if operations.count > 1 {
                await #expect(throws: RepositoryCommitDiffError.self, "\(fixture.comment)") {
                    try await RepositoryCommitDiff.verifyInversion(
                        dataCID: result.after,
                        operations: Array(operations.dropLast()),
                        previousDataCID: result.before,
                        blocks: proofOnly,
                        options: options
                    )
                }
            }
        }
    }

    @Test("a proof with a block missing never verifies wrongly: it succeeds only if the block was not needed")
    func incompleteProof() async throws {
        for fixture in try fixtures() {
            let result = try await run(fixture)
            let leaf = try CID.parseBlessed(fixture.leafValue, kind: .dagCBOR)
            let operations = try operations(for: fixture, leaf: leaf)
            var refused = 0
            for omitted in fixture.blocksInProof {
                let partial = InMemoryRepositoryBlockStore()
                for cid in fixture.blocksInProof where cid != omitted {
                    let parsed = try CID.parseBlessed(cid, kind: .dagCBOR)
                    let bytes = try #require(try await result.store.block(for: parsed))
                    try await partial.put(.init(cid: parsed, bytes: bytes))
                }
                do {
                    // The covering proof is a superset of what one particular
                    // inversion reads, so some omissions go unnoticed. That
                    // is sound: the root was still recomputed from hashed
                    // blocks and compared with `prevData`.
                    try await RepositoryCommitDiff.verifyInversion(
                        dataCID: result.after,
                        operations: operations,
                        previousDataCID: result.before,
                        blocks: partial,
                        options: options
                    )
                } catch let error as RepositoryCommitDiffError {
                    // The only acceptable failure is "cannot tell": never a
                    // mismatch, never a claim about what the tree holds.
                    #expect(error == .incompleteProof, "\(fixture.comment) without \(omitted)")
                    refused += 1
                }
            }
            // The new root, at least, is always needed.
            #expect(refused >= 1, "\(fixture.comment)")
        }
    }

    @Test("the bottom-up oracle builds the same roots as incremental mutation")
    func independentBuilderAgrees() async throws {
        for fixture in try fixtures() {
            let leaf = try CID.parseBlessed(fixture.leafValue, kind: .dagCBOR)
            let beforeKeys = fixture.keys.sorted()
            let afterKeys = Set(fixture.keys).union(fixture.adds).subtracting(fixture.dels).sorted()
            let beforeEntries = try beforeKeys.map { BulkMST.Entry(path: try path($0), recordCID: leaf) }
            let afterEntries = try afterKeys.map { BulkMST.Entry(path: try path($0), recordCID: leaf) }
            let before = try await BulkMST.build(beforeEntries, options: options) { _ in }
            let after = try await BulkMST.build(afterEntries, options: options) { _ in }
            #expect(before.string == fixture.rootBeforeCommit, "\(fixture.comment)")
            #expect(after.string == fixture.rootAfterCommit, "\(fixture.comment)")
        }
    }
}
