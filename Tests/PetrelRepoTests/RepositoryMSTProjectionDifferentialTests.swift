import Foundation
import Petrel
@testable import PetrelRepo
import XCTest

final class RepositoryMSTProjectionDifferentialTests: XCTestCase {
    func testEmptyMultiLayerAndSharedRecordProjectionMatchesMaterializingValidator() async throws {
        let emptyBytes = PublicRepositoryGenesisCodec.canonicalEmptyMST
        let emptyCID = CID.fromDAGCBOR(emptyBytes)
        try await assertEquivalent(
            root: emptyCID, source: DifferentialBlockSource([emptyCID: emptyBytes])
        )

        var tree = try RepositoryMST.empty()
        var storage: [CID: Data] = [:]
        let shared = try PublicRepositoryRecordCodec.prepare(
            PublicRecord([
                "$type": .string("com.example.record"),
                "text": .string("shared"),
            ]),
            for: try PublicRepositoryPath(
                collection: "com.example.record", recordKey: "seed"
            )
        )
        storage[shared.cid] = shared.bytes
        for index in 0 ..< 96 {
            let path = try PublicRepositoryPath(
                collection: "com.example.record",
                recordKey: String(format: "record-%03d", index)
            )
            tree = try await tree.adding(path: path, recordCID: shared.cid)
        }
        let materialized = try await tree.materialized()
        for cid in materialized.newBlocks.cids {
            storage[cid] = try await materialized.newBlocks.block(for: cid)
        }
        let full = try await assertEquivalent(
            root: materialized.rootCID,
            source: DifferentialBlockSource(storage)
        )
        XCTAssertEqual(full.recordCount, 96)
        XCTAssertEqual(full.recordBlockCount, 1)
        XCTAssertGreaterThan(full.mstBlockCount, 1)
    }

    func testHostileSchemaAndCIDMismatchProduceSameErrorCategory() async {
        let malformed = Data([0xa0])
        let malformedCID = CID.fromDAGCBOR(malformed)
        await assertSameFailure(
            root: malformedCID,
            source: DifferentialBlockSource([malformedCID: malformed])
        )
        let validCID = CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST)
        await assertSameFailure(
            root: validCID,
            source: DifferentialBlockSource([validCID: Data([0xa0])])
        )
    }

    func testHostileMissingRecordSchemaAndEveryTraversalBudgetMatch() async throws {
        let missingRoot = CID.fromDAGCBOR(Data([0xa0]))
        await assertSameFailure(
            root: missingRoot, source: DifferentialBlockSource([:])
        )

        let pathA = try PublicRepositoryPath(
            collection: "com.example.record", recordKey: "a"
        )
        let pathB = try PublicRepositoryPath(
            collection: "com.example.record", recordKey: "b"
        )
        let recordA = try PublicRepositoryRecordCodec.prepare(
            PublicRecord([
                "$type": .string("com.example.record"),
                "value": .string("a"),
            ]), for: pathA
        )
        let recordB = try PublicRepositoryRecordCodec.prepare(
            PublicRecord([
                "$type": .string("com.example.record"),
                "value": .string("b"),
            ]), for: pathB
        )
        let nodeBytes = try RepositoryMSTCodec.encode(try RepositoryMSTCodec.node(
            leaves: [
                .init(path: pathA, recordCID: recordA.cid),
                .init(path: pathB, recordCID: recordB.cid),
            ]
        ))
        let nodeCID = CID.fromDAGCBOR(nodeBytes)
        await assertSameFailure(
            root: nodeCID,
            source: DifferentialBlockSource([nodeCID: nodeBytes])
        )
        await assertSameFailure(
            root: nodeCID,
            source: DifferentialBlockSource([
                nodeCID: nodeBytes,
                recordA.cid: recordA.bytes,
                recordB.cid: Data([0xa0]),
            ])
        )

        let storage = DifferentialBlockSource([
            nodeCID: nodeBytes,
            recordA.cid: recordA.bytes,
            recordB.cid: recordB.bytes,
        ])
        let entryLimited = try PublicRepositoryLimits(
            maximumRecordBlockBytes: 1_000_000,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: 10,
            maximumMSTNodes: 10,
            maximumMSTEntriesPerNode: 1,
            maximumCBORNestingDepth: 64
        )
        await assertSameFailure(
            root: nodeCID, source: storage, limits: entryLimited
        )
        let depthLimited = try PublicRepositoryLimits(
            maximumRecordBlockBytes: 1_000_000,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: 10,
            maximumMSTNodes: 10,
            maximumMSTEntriesPerNode: 4_096,
            maximumCBORNestingDepth: 2
        )
        await assertSameFailure(
            root: nodeCID, source: storage, limits: depthLimited
        )
        await assertSameFailure(
            root: nodeCID,
            source: storage,
            maximumReachableRepositoryBytes: nodeBytes.count + recordA.bytes.count
        )
    }

    @discardableResult
    private func assertEquivalent(
        root: CID,
        source: DifferentialBlockSource
    ) async throws -> ValidatedPublicRepositoryProjection {
        let materialized = try await RepositoryMSTValidation.validate(
            rootCID: root, blocks: source
        )
        let sink = DifferentialProjectionSink()
        let projected = try await RepositoryMSTValidation.validateProjection(
            rootCID: root, blocks: source, projection: sink
        )
        let snapshot = await sink.snapshot()
        XCTAssertEqual(projected.rootLayer, materialized.rootLayer)
        XCTAssertEqual(projected.mstBlockCount, materialized.reachableMSTBlocks.count)
        XCTAssertEqual(projected.recordBlockCount, materialized.reachableRecordCIDs.count)
        XCTAssertEqual(projected.recordCount, materialized.leaves.count)
        XCTAssertEqual(
            projected.reachableRepositoryByteCount,
            materialized.reachableRepositoryByteCount
        )
        XCTAssertEqual(snapshot.mst, Set(materialized.reachableMSTBlocks.keys))
        XCTAssertEqual(snapshot.records, materialized.reachableRecordCIDs)
        XCTAssertEqual(
            snapshot.index,
            Dictionary(uniqueKeysWithValues: materialized.leaves.map {
                ($0.path, $0.recordCID)
            })
        )
        return projected
    }

    private func assertSameFailure(
        root: CID,
        source: DifferentialBlockSource,
        limits: PublicRepositoryLimits = .standard,
        maximumReachableRepositoryBytes: Int? = nil
    ) async {
        let first: RepositoryMSTValidationError?
        do {
            _ = try await RepositoryMSTValidation.validate(
                rootCID: root, blocks: source, limits: limits,
                maximumReachableRepositoryBytes: maximumReachableRepositoryBytes
            )
            first = nil
        } catch {
            first = error as? RepositoryMSTValidationError
        }
        let second: RepositoryMSTValidationError?
        do {
            _ = try await RepositoryMSTValidation.validateProjection(
                rootCID: root, blocks: source,
                projection: DifferentialProjectionSink(),
                limits: limits,
                maximumReachableRepositoryBytes: maximumReachableRepositoryBytes
            )
            second = nil
        } catch {
            second = error as? RepositoryMSTValidationError
        }
        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }
}

private struct DifferentialBlockSource: PublicRepositoryBlockSource {
    let storage: [CID: Data]
    init(_ storage: [CID: Data]) { self.storage = storage }
    func block(for cid: CID) async throws -> Data? { storage[cid] }
}

private actor DifferentialProjectionSink: PublicRepositoryReachableProjectionSink {
    private var mst = Set<CID>()
    private var records = Set<CID>()
    private var index: [PublicRepositoryPath: CID] = [:]

    func recordReachableBlock(
        cid: CID,
        kind: PublicRepositoryReachableBlockKind
    ) async throws {
        switch kind {
        case .mst: mst.insert(cid)
        case .record: records.insert(cid)
        }
    }

    func recordRepositoryIndex(
        path: PublicRepositoryPath,
        recordCID: CID
    ) async throws {
        index[path] = recordCID
    }

    func snapshot() -> (
        mst: Set<CID>,
        records: Set<CID>,
        index: [PublicRepositoryPath: CID]
    ) {
        (mst, records, index)
    }
}
