import Foundation
import Petrel
@testable import PetrelRepo
import XCTest

final class RepositoryMSTMutationTests: XCTestCase {
    func testEmptyTreeAddGetListAndMaterialize() async throws {
        let source = CountingBlockSource([
            PublicRepositoryGenesisCodec.canonicalEmptyMSTCIDValue:
                PublicRepositoryGenesisCodec.canonicalEmptyMST,
        ])
        let path = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "0")
        let record = try preparedRecord(path: path, text: "zero")
        let base = try RepositoryMST.load(
            rootCID: PublicRepositoryGenesisCodec.canonicalEmptyMSTCIDValue,
            blocks: source
        )

        let originalValue = try await base.get(path)
        XCTAssertNil(originalValue)
        let updated = try await base.adding(path: path, recordCID: record.cid)
        let unchangedValue = try await base.get(path)
        let updatedValue = try await updated.get(path)
        let listed = try await updated.listed()
        XCTAssertNil(unchangedValue)
        XCTAssertEqual(updatedValue, record.cid)
        XCTAssertEqual(listed, [
            RepositoryMSTLeaf(path: path, recordCID: record.cid),
        ])

        let materialized = try await updated.materialized()
        XCTAssertNotEqual(materialized.rootCID, PublicRepositoryGenesisCodec.canonicalEmptyMSTCIDValue)
        XCTAssertEqual(materialized.newBlocks.count, 1)
        let rootBytes = try await materialized.newBlocks.block(for: materialized.rootCID)
        XCTAssertEqual(
            rootBytes,
            try RepositoryMSTCodec.encode(
                RepositoryMSTCodec.node(leaves: [.init(path: path, recordCID: record.cid)])
            )
        )
    }

    func testDuplicateAddAndMissingUpdateDeleteDoNotAlterPriorTree() async throws {
        let path = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "0")
        let other = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "missing")
        let record = try preparedRecord(path: path, text: "original")
        let replacement = try preparedRecord(path: path, text: "replacement")
        let base = try RepositoryMST.empty()
        let tree = try await base.adding(path: path, recordCID: record.cid)
        let before = try await tree.materialized()

        await assertMutationError(.duplicateKey) {
            _ = try await tree.adding(path: path, recordCID: replacement.cid)
        }
        await assertMutationError(.missingKey) {
            _ = try await tree.updating(path: other, recordCID: replacement.cid)
        }
        await assertMutationError(.missingKey) {
            _ = try await tree.deleting(path: other)
        }

        let valueAfterFailures = try await tree.get(path)
        let projectionAfterFailures = try await tree.materialized()
        XCTAssertEqual(valueAfterFailures, record.cid)
        XCTAssertEqual(projectionAfterFailures, before)
    }

    func testUpdateDeleteAndReAddRestoreDeterministicRoots() async throws {
        let path = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "90")
        let original = try preparedRecord(path: path, text: "one")
        let replacement = try preparedRecord(path: path, text: "two")
        let initial = try await RepositoryMST.empty().adding(path: path, recordCID: original.cid)
        let initialRoot = try await initial.materialized().rootCID

        let updated = try await initial.updating(path: path, recordCID: replacement.cid)
        let updatedValue = try await updated.get(path)
        let updatedRoot = try await updated.materialized().rootCID
        XCTAssertEqual(updatedValue, replacement.cid)
        XCTAssertNotEqual(updatedRoot, initialRoot)

        let deleted = try await updated.deleting(path: path)
        let deletedRoot = try await deleted.materialized().rootCID
        let deletedList = try await deleted.listed()
        XCTAssertEqual(
            deletedRoot,
            PublicRepositoryGenesisCodec.canonicalEmptyMSTCIDValue
        )
        XCTAssertEqual(deletedList, [])

        let restored = try await deleted.adding(path: path, recordCID: original.cid)
        let restoredRoot = try await restored.materialized().rootCID
        XCTAssertEqual(restoredRoot, initialRoot)
    }

    func testLoadedTreeIsLazyAndReadsOnlySearchPath() async throws {
        let paths = try ["0", "18", "90", "2", "54"].map {
            try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: $0)
        }
        var tree = try RepositoryMST.empty()
        var records: [CID: Data] = [:]
        var expected: [PublicRepositoryPath: CID] = [:]
        for path in paths {
            let record = try preparedRecord(path: path, text: path.recordKey)
            records[record.cid] = record.bytes
            expected[path] = record.cid
            tree = try await tree.adding(path: path, recordCID: record.cid)
        }
        let built = try await tree.materialized()
        let allBlocks = built.newBlocks.blocks.merging(records) { left, _ in left }
        let source = CountingBlockSource(allBlocks)
        let loaded = try RepositoryMST.load(rootCID: built.rootCID, blocks: source)

        let loadedValue = try await loaded.get(paths[0])
        let readCount = await source.readCount
        XCTAssertEqual(loadedValue, expected[paths[0]])
        XCTAssertLessThan(readCount, built.newBlocks.count)
    }

    func testPinnedTypeScriptSplitMergeDepthGapAndRootTrimRoots() async throws {
        let cid = try CID.parse("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
        let collection = "com.example.record"
        func path(_ key: String) throws -> PublicRepositoryPath {
            try PublicRepositoryPath(collection: collection, recordKey: key)
        }

        var trim = try RepositoryMST.empty()
        for key in [
            "3jqfcqzm3fn2j", "3jqfcqzm3fo2j", "3jqfcqzm3fp2j",
            "3jqfcqzm3fs2j", "3jqfcqzm3ft2j", "3jqfcqzm3fu2j",
        ] {
            trim = try await trim.adding(path: path(key), recordCID: cid)
        }
        let trimLayerOneRoot = try await trim.materialized().rootCID
        XCTAssertEqual(
            trimLayerOneRoot.string,
            "bafyreifnqrwbk6ffmyaz5qtujqrzf5qmxf7cbxvgzktl4e3gabuxbtatv4"
        )
        trim = try await trim.deleting(path: path("3jqfcqzm3fs2j"))
        let trimmedRoot = try await trim.materialized().rootCID
        XCTAssertEqual(
            trimmedRoot.string,
            "bafyreie4kjuxbwkhzg2i5dljaswcroeih4dgiqq6pazcmunwt2byd725vi"
        )

        var split = try RepositoryMST.empty()
        for key in [
            "3jqfcqzm3fo2j", "3jqfcqzm3fp2j", "3jqfcqzm3fr2j",
            "3jqfcqzm3fs2j", "3jqfcqzm3ft2j", "3jqfcqzm3fz2j",
            "3jqfcqzm4fc2j", "3jqfcqzm4fd2j", "3jqfcqzm4ff2j",
            "3jqfcqzm4fg2j", "3jqfcqzm4fh2j",
        ] {
            split = try await split.adding(path: path(key), recordCID: cid)
        }
        let beforeSplit = try await split.materialized().rootCID
        XCTAssertEqual(
            beforeSplit.string,
            "bafyreiettyludka6fpgp33stwxfuwhkzlur6chs4d2v4nkmq2j3ogpdjem"
        )
        split = try await split.adding(path: path("3jqfcqzm3fx2j"), recordCID: cid)
        let splitRoot = try await split.materialized().rootCID
        XCTAssertEqual(
            splitRoot.string,
            "bafyreid2x5eqs4w4qxvc5jiwda4cien3gw2q6cshofxwnvv7iucrmfohpm"
        )
        split = try await split.deleting(path: path("3jqfcqzm3fx2j"))
        let mergedRoot = try await split.materialized().rootCID
        XCTAssertEqual(mergedRoot, beforeSplit)

        var gap = try RepositoryMST.empty()
        gap = try await gap.adding(path: path("3jqfcqzm3ft2j"), recordCID: cid)
        gap = try await gap.adding(path: path("3jqfcqzm3fz2j"), recordCID: cid)
        let levelZero = try await gap.materialized().rootCID
        XCTAssertEqual(
            levelZero.string,
            "bafyreidfcktqnfmykz2ps3dbul35pepleq7kvv526g47xahuz3rqtptmky"
        )
        gap = try await gap.adding(path: path("3jqfcqzm3fx2j"), recordCID: cid)
        let levelTwoRoot = try await gap.materialized().rootCID
        XCTAssertEqual(
            levelTwoRoot.string,
            "bafyreiavxaxdz7o7rbvr3zg2liox2yww46t7g6hkehx4i4h3lwudly7dhy"
        )
        gap = try await gap.deleting(path: path("3jqfcqzm3fx2j"))
        let restoredLevelZero = try await gap.materialized().rootCID
        XCTAssertEqual(restoredLevelZero, levelZero)
    }

    func testPinnedTypeScriptAddUpdateDeleteRootAndBytes() async throws {
        let path = try PublicRepositoryPath(
            collection: "com.example.record",
            recordKey: "3jqfcqzm3fo2j"
        )
        let original = try CID.parse("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
        let replacement = try CID.parse("bafyreie5737gdxlw5i64vzichcalba3z2v5n6icifvx5xytvske7mr3hpm")
        var tree = try RepositoryMST.empty()
        tree = try await tree.adding(path: path, recordCID: original)
        let added = try await tree.materialized()
        let addedBytes = try await added.newBlocks.block(for: added.rootCID)
        XCTAssertEqual(added.rootCID.string, "bafyreibj4lsc3aqnrvphp5xmrnfoorvru4wynt6lwidqbm2623a6tatzdu")
        XCTAssertEqual(
            addedBytes,
            Data(mstHex: "a2616581a4616b5820636f6d2e6578616d706c652e7265636f72642f336a716663717a6d33666f326a6170006174f66176d82a582500017112209d156bc3f3a520066252c708a9361fd3d089223842500e3713d404fdccb33cef616cf6")
        )

        tree = try await tree.updating(path: path, recordCID: replacement)
        let updated = try await tree.materialized()
        let updatedBytes = try await updated.newBlocks.block(for: updated.rootCID)
        XCTAssertEqual(updated.rootCID.string, "bafyreibewzxvsw2qqvqti3bv3bstab6bpbehbj7n3cy2w6btw7mvdvzcmi")
        XCTAssertEqual(
            updatedBytes,
            Data(mstHex: "a2616581a4616b5820636f6d2e6578616d706c652e7265636f72642f336a716663717a6d33666f326a6170006174f66176d82a582500017112209dfefe61dd76ea3dcae5023880b08379d57adf20482d6fdbe2759289f647677b616cf6")
        )

        tree = try await tree.deleting(path: path)
        let deleted = try await tree.materialized()
        XCTAssertEqual(deleted.rootCID.string, PublicRepositoryGenesisCodec.canonicalEmptyMSTCID)
        XCTAssertEqual(PublicRepositoryGenesisCodec.canonicalEmptyMST, Data(mstHex: "a2616580616cf6"))
    }

    func testMutationEnforcesEntryAndNewNodeBudgets() async throws {
        let entryLimited = try PublicRepositoryLimits(
            maximumRecordBlockBytes: 1_000,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: 10,
            maximumMSTNodes: 10,
            maximumMSTEntriesPerNode: 1,
            maximumCBORNestingDepth: 8
        )
        let first = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "0")
        let second = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "2")
        XCTAssertEqual(RepositoryMSTCodec.keyDepth(for: first), 0)
        XCTAssertEqual(RepositoryMSTCodec.keyDepth(for: second), 0)
        let cid = try preparedRecord(path: first, text: "value").cid
        let one = try await RepositoryMST.empty(limits: entryLimited)
            .adding(path: first, recordCID: cid)
        await assertMutationError(.entryLimitExceeded) {
            _ = try await one.adding(path: second, recordCID: cid)
        }

        let nodeLimited = try PublicRepositoryLimits(
            maximumRecordBlockBytes: 1_000,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: 1,
            maximumMSTNodes: 1,
            maximumMSTEntriesPerNode: 10,
            maximumCBORNestingDepth: 8
        )
        let low = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "0")
        let high = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "90")
        XCTAssertEqual(RepositoryMSTCodec.keyDepth(for: high), 3)
        var depthGap = try RepositoryMST.empty(limits: nodeLimited)
        depthGap = try await depthGap.adding(path: low, recordCID: cid)
        depthGap = try await depthGap.adding(path: high, recordCID: cid)
        await assertMutationError(.nodeLimitExceeded) {
            _ = try await depthGap.materialized()
        }
    }

    func testLoadedMutationCollectsOnlyReplacedPathAndValidatesWithBaseSource() async throws {
        let paths = try ["0", "2", "18", "54", "90", "128", "129"].map {
            try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: $0)
        }
        var tree = try RepositoryMST.empty()
        var recordBlocks: [CID: Data] = [:]
        for path in paths {
            let record = try preparedRecord(path: path, text: path.recordKey)
            recordBlocks[record.cid] = record.bytes
            tree = try await tree.adding(path: path, recordCID: record.cid)
        }
        let base = try await tree.materialized()
        let baseSource = CountingBlockSource(base.newBlocks.blocks.merging(recordBlocks) { left, _ in left })
        let loaded = try RepositoryMST.load(rootCID: base.rootCID, blocks: baseSource)
        let replacement = try preparedRecord(path: paths[0], text: "replacement")
        let updated = try await loaded.updating(path: paths[0], recordCID: replacement.cid)
        await baseSource.resetReads()
        let changed = try await updated.materialized()
        let materializationReads = await baseSource.readCIDs

        XCTAssertLessThan(changed.newBlocks.count, base.newBlocks.count)
        XCTAssertEqual(materializationReads.count, changed.newBlocks.count)
        XCTAssertEqual(Set(materializationReads), changed.newBlocks.cids)
        var combined = base.newBlocks.blocks
        combined.merge(changed.newBlocks.blocks) { _, new in new }
        combined.merge(recordBlocks) { old, _ in old }
        combined[replacement.cid] = replacement.bytes
        let validated = try await RepositoryMSTValidation.validate(
            rootCID: changed.rootCID,
            blocks: CountingBlockSource(combined)
        )
        XCTAssertEqual(validated.rootCID, changed.rootCID)
        XCTAssertEqual(validated.leaves.count, paths.count)
    }

    func testLoadedRootCanSplitIntoNewHigherLayers() async throws {
        let low = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "0")
        let high = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "90")
        XCTAssertEqual(RepositoryMSTCodec.keyDepth(for: low), 0)
        XCTAssertEqual(RepositoryMSTCodec.keyDepth(for: high), 3)
        let record = try preparedRecord(path: low, text: "value")
        let baseTree = try await RepositoryMST.empty().adding(path: low, recordCID: record.cid)
        let base = try await baseTree.materialized()
        let source = CountingBlockSource(base.newBlocks.blocks)
        let loaded = try RepositoryMST.load(rootCID: base.rootCID, blocks: source)

        let split = try await loaded.adding(path: high, recordCID: record.cid)
        let splitRoot = try await split.materialized().rootCID
        var direct = try RepositoryMST.empty()
        direct = try await direct.adding(path: low, recordCID: record.cid)
        direct = try await direct.adding(path: high, recordCID: record.cid)
        let directRoot = try await direct.materialized().rootCID
        XCTAssertEqual(splitRoot, directRoot)
    }

    private func preparedRecord(path: PublicRepositoryPath, text: String) throws -> PreparedPublicRecord {
        try PublicRepositoryRecordCodec.prepare(
            PublicRecord(["$type": .string(path.collection), "text": .string(text)]),
            for: path
        )
    }

    private func assertMutationError(
        _ expected: RepositoryMSTMutationError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("expected \(expected)")
        } catch {
            XCTAssertEqual(error as? RepositoryMSTMutationError, expected)
        }
    }

    func testDeepEmptyNodeChainLayerDiscoveryIsBounded() async throws {
        // Build a chain of 130 empty MST nodes where child is left pointer
        var storage: [CID: Data] = [:]
        let emptyNode = try RepositoryMSTCodec.encode(RepositoryMSTCodec.node(leaves: []))
        let emptyCID = CID.fromDAGCBOR(emptyNode)
        storage[emptyCID] = emptyNode

        var currentCID = emptyCID
        for _ in 0 ..< 130 {
            let node = try RepositoryMSTCodec.encode(RepositoryMSTCodec.node(leaves: [], leftTreeCID: currentCID))
            let cid = CID.fromDAGCBOR(node)
            storage[cid] = node
            currentCID = cid
        }

        let source = CountingBlockSource(storage)
        let tree = try RepositoryMST.load(rootCID: currentCID, blocks: source)
        let path = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "0")

        // Looking up or mutating should fail with typed budget/layer error instead of exhausting call stack
        do {
            _ = try await tree.get(path)
            XCTFail("Expected layer discovery failure")
        } catch let error as RepositoryMSTMutationError {
            XCTAssertTrue(error == .invalidLayer || error == .relevantBlockBudgetExceeded || error == .nodeLimitExceeded)
        }
    }

    func testTransactionWideNodeExhaustionFailsBeforeStackExhaustion() async throws {
        // Build a multi-node tree
        var records: [(PublicRepositoryPath, PreparedPublicRecord)] = []
        for i in 0 ..< 20 {
            let path = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "\(i)")
            let rec = try preparedRecord(path: path, text: "\(i)")
            records.append((path, rec))
        }

        var tree = try RepositoryMST.empty()
        for (p, r) in records {
            tree = try await tree.adding(path: p, recordCID: r.cid)
        }

        let materialized = try await tree.materialized()
        // Ensure the tree actually has > 2 blocks
        XCTAssertGreaterThan(materialized.newBlocks.blocks.count, 2)

        let source = CountingBlockSource(materialized.newBlocks.blocks)

        let customLimits = try PublicRepositoryLimits(
            maximumRecordBlockBytes: 1_000_000,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: 10,
            maximumMSTNodes: 2,
            maximumMSTEntriesPerNode: 10,
            maximumCBORNestingDepth: 64
        )

        var loadedTree = try RepositoryMST.load(rootCID: materialized.rootCID, blocks: source, limits: customLimits)

        // Mutating loaded tree with very tight node limit (maximumMSTNodes = 2) should exceed node limit during traversal
        let newPath = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "999")
        let newRec = try preparedRecord(path: newPath, text: "999")

        do {
            loadedTree = try await loadedTree.adding(path: newPath, recordCID: newRec.cid)
            _ = try await loadedTree.materialized()
            XCTFail("Expected nodeLimitExceeded error")
        } catch let error as RepositoryMSTMutationError {
            XCTAssertEqual(error, .nodeLimitExceeded)
        }
    }
}
private actor CountingBlockSource: PublicRepositoryBlockSource {
    private let storage: [CID: Data]
    private(set) var readCount = 0
    private(set) var readCIDs: [CID] = []

    init(_ storage: [CID: Data]) {
        self.storage = storage
    }

    func block(for cid: CID) async throws -> Data? {
        readCount += 1
        readCIDs.append(cid)
        return storage[cid]
    }

    func resetReads() {
        readCount = 0
        readCIDs = []
    }
}

private extension PublicRepositoryGenesisCodec {
    static var canonicalEmptyMSTCIDValue: CID {
        CID.fromDAGCBOR(canonicalEmptyMST)
    }
}

private extension PublicRepositoryBlockMap {
    var blocks: [CID: Data] {
        Dictionary(uniqueKeysWithValues: cids.compactMap { cid in
            block(for: cid).map { (cid, $0) }
        })
    }
}

private extension Data {
    init(mstHex: String) {
        precondition(mstHex.count.isMultiple(of: 2))
        var bytes: [UInt8] = []
        bytes.reserveCapacity(mstHex.count / 2)
        var index = mstHex.startIndex
        while index < mstHex.endIndex {
            let end = mstHex.index(index, offsetBy: 2)
            bytes.append(UInt8(mstHex[index ..< end], radix: 16)!)
            index = end
        }
        self.init(bytes)
    }
}
