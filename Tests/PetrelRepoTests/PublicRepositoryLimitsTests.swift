import PetrelRepo
import XCTest

final class PublicRepositoryLimitsTests: XCTestCase {
    func testStandardFreezesPinnedAndSwanPolicyValues() {
        let limits = PublicRepositoryLimits.standard

        XCTAssertEqual(limits.maximumWrites, 200)
        XCTAssertEqual(limits.maximumRelevantBlockBytes, 2_000_000)
        XCTAssertEqual(limits.maximumRecordBlockBytes, 1_000_000)
        XCTAssertEqual(limits.maximumCARBytes, 512 * 1_024 * 1_024)
        XCTAssertEqual(limits.maximumCARBlocks, 1_000_000)
        XCTAssertEqual(limits.maximumMSTNodes, 500_000)
        XCTAssertEqual(limits.maximumMSTEntriesPerNode, 4_096)
        XCTAssertEqual(limits.maximumCBORNestingDepth, 64)
        XCTAssertGreaterThanOrEqual(
            limits.maximumCARBytes,
            PublicRepositoryLimits.requiredStreamingCARBytes
        )
    }

    func testCustomConstructionPreservesPinnedLimits() throws {
        let limits = try makeLimits(
            recordBytes: 123,
            carBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            carBlocks: 20,
            mstNodes: 10,
            entries: 8,
            depth: 4
        )

        XCTAssertEqual(limits.maximumWrites, PublicRepositoryLimits.pinnedMaximumWrites)
        XCTAssertEqual(
            limits.maximumRelevantBlockBytes,
            PublicRepositoryLimits.pinnedMaximumRelevantBlockBytes
        )
    }

    func testEveryInclusivePolicyBoundaryIsAccepted() {
        XCTAssertNoThrow(try makeLimits(
            recordBytes: 1,
            carBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            carBlocks: 1,
            mstNodes: 1,
            entries: 1,
            depth: 1
        ))
        XCTAssertNoThrow(try makeLimits(
            recordBytes: PublicRepositoryLimits.maximumPermittedRecordBlockBytes,
            carBytes: PublicRepositoryLimits.maximumPermittedCARBytes,
            carBlocks: PublicRepositoryLimits.maximumPermittedCARBlocks,
            mstNodes: PublicRepositoryLimits.maximumPermittedMSTNodes,
            entries: PublicRepositoryLimits.maximumPermittedMSTEntriesPerNode,
            depth: PublicRepositoryLimits.maximumPermittedCBORNestingDepth
        ))
    }

    func testZeroAndNegativePolicyValuesReject() {
        assertError(.maximumRecordBlockBytesOutOfRange) {
            _ = try makeLimits(recordBytes: 0)
        }
        assertError(.maximumCARBytesOutOfRange) {
            _ = try makeLimits(carBytes: -1)
        }
        assertError(.maximumCARBlocksOutOfRange) {
            _ = try makeLimits(carBlocks: 0, mstNodes: 1)
        }
        assertError(.maximumMSTNodesOutOfRange) {
            _ = try makeLimits(mstNodes: 0)
        }
        assertError(.maximumMSTEntriesPerNodeOutOfRange) {
            _ = try makeLimits(entries: 0)
        }
        assertError(.maximumCBORNestingDepthOutOfRange) {
            _ = try makeLimits(depth: 0)
        }
    }

    func testAboveCeilingAndOverflowScaleValuesReject() {
        assertError(.maximumRecordBlockBytesOutOfRange) {
            _ = try makeLimits(recordBytes: PublicRepositoryLimits.maximumPermittedRecordBlockBytes + 1)
        }
        assertError(.maximumCARBytesOutOfRange) {
            _ = try makeLimits(carBytes: PublicRepositoryLimits.maximumPermittedCARBytes + 1)
        }
        assertError(.maximumCARBlocksOutOfRange) {
            _ = try makeLimits(carBlocks: Int.max)
        }
        assertError(.maximumMSTNodesOutOfRange) {
            _ = try makeLimits(
                carBlocks: PublicRepositoryLimits.maximumPermittedCARBlocks,
                mstNodes: Int.max
            )
        }
        assertError(.maximumMSTEntriesPerNodeOutOfRange) {
            _ = try makeLimits(entries: Int.max)
        }
        assertError(.maximumCBORNestingDepthOutOfRange) {
            _ = try makeLimits(depth: Int.max)
        }
    }

    func testCARCannotBeConfiguredBelowRequiredStreamingCase() {
        assertError(.maximumCARBytesOutOfRange) {
            _ = try makeLimits(carBytes: PublicRepositoryLimits.requiredStreamingCARBytes - 1)
        }
    }

    func testMSTNodeBudgetCannotExceedTotalCARBlockBudget() {
        assertError(.mstNodesExceedCARBlocks) {
            _ = try makeLimits(carBlocks: 10, mstNodes: 11)
        }
    }

    private func makeLimits(
        recordBytes: Int = 1_000_000,
        carBytes: Int = 512 * 1_024 * 1_024,
        carBlocks: Int = 1_000_000,
        mstNodes: Int = 500_000,
        entries: Int = 4_096,
        depth: Int = 64
    ) throws -> PublicRepositoryLimits {
        try PublicRepositoryLimits(
            maximumRecordBlockBytes: recordBytes,
            maximumCARBytes: carBytes,
            maximumCARBlocks: carBlocks,
            maximumMSTNodes: mstNodes,
            maximumMSTEntriesPerNode: entries,
            maximumCBORNestingDepth: depth
        )
    }

    private func assertError(
        _ expected: PublicRepositoryLimitError,
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: () throws -> Void
    ) {
        XCTAssertThrowsError(try operation(), file: file, line: line) { error in
            XCTAssertEqual(error as? PublicRepositoryLimitError, expected, file: file, line: line)
        }
    }
}
