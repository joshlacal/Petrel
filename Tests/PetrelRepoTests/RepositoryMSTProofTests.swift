import Crypto
import Foundation
import Petrel
@testable import PetrelRepo
import XCTest

final class RepositoryMSTProofTests: XCTestCase {
    // MARK: - the reason this walker exists

    /// The contrast that justifies the lane: one CAR, three walkers. The proof
    /// walk resolves the key; both full validators reject the same bytes
    /// because sibling subtrees are absent. The fourth assertion is the
    /// positive control — the full validators accept the SAME tree once every
    /// block is present, so their rejection is about the omitted siblings and
    /// not about a malformed fixture.
    func testProofWalkAcceptsWhatBothFullValidatorsReject() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder.build()

        let found = try await RepositoryMSTProof.membership(
            rootCID: fixture.mstRootCID,
            key: fixture.mstKey,
            blocks: fixture.proofBlocks
        )
        XCTAssertEqual(found, fixture.recordCID)

        await XCTAssertThrowsMSTProofError(.missingBlock) {
            try await RepositoryMSTValidation.validate(
                rootCID: fixture.mstRootCID,
                blocks: fixture.proofBlocks
            )
        }
        await XCTAssertThrowsMSTProofError(.missingBlock) {
            try await RepositoryMSTValidation.validateProjection(
                rootCID: fixture.mstRootCID,
                blocks: fixture.proofBlocks,
                projection: DiscardingProjectionSink()
            )
        }

        let validated = try await RepositoryMSTValidation.validate(
            rootCID: fixture.mstRootCID,
            blocks: fixture.fullRepositoryBlocks
        )
        XCTAssertEqual(validated.rootCID, fixture.mstRootCID)
        XCTAssertTrue(validated.leaves.contains { $0.path == fixture.recordPath })
        XCTAssertLessThan(
            fixture.pathNodeCIDs.count,
            validated.reachableMSTBlocks.count,
            "the proof CAR must carry strictly fewer nodes than the whole tree"
        )
    }

    func testProofWalkAgreesWithItselfOverTheWholeTree() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder.build()
        let found = try await RepositoryMSTProof.membership(
            rootCID: fixture.mstRootCID,
            key: fixture.mstKey,
            blocks: fixture.fullRepositoryBlocks
        )
        XCTAssertEqual(found, fixture.recordCID)
    }

    // MARK: - membership, not mere presence

    /// Step 12's whole point. The record block IS in the CAR; nothing under
    /// `commit.data` links it.
    func testUnlinkedRecordBlockDoesNotSatisfyMembership() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder
            .build(.recordPresentButUnlinked)

        let present = try await fixture.proofBlocks.block(for: fixture.recordCID)
        XCTAssertNotNil(present, "the vector requires the orphan block to be present")

        let found = try await RepositoryMSTProof.membership(
            rootCID: fixture.mstRootCID,
            key: fixture.mstKey,
            blocks: fixture.proofBlocks
        )
        XCTAssertNil(found)
    }

    // MARK: - provably absent vs. cannot tell

    /// A withheld path node must never read as absence. An attacker who picks
    /// which blocks to omit would otherwise choose the answer.
    func testWithheldPathNodeThrowsRatherThanReportingAbsence() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder
            .build(.omittedPathNode)
        await XCTAssertThrowsMSTProofError(.missingBlock) {
            try await RepositoryMSTProof.membership(
                rootCID: fixture.mstRootCID,
                key: fixture.mstKey,
                blocks: fixture.proofBlocks
            )
        }
    }

    func testAbsentKeyInACompleteTreeIsProvablyAbsent() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder.build()
        let found = try await RepositoryMSTProof.membership(
            rootCID: fixture.mstRootCID,
            key: "com.atproto.lexicon.schema/com.example.absent.auth",
            blocks: fixture.fullRepositoryBlocks
        )
        XCTAssertNil(found)
    }

    func testMalformedKeyIsRefusedRatherThanReportedAbsent() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder.build()
        for key in ["no-separator", "com.atproto.lexicon.schema/", "/rkey", "a/b/c"] {
            await XCTAssertThrowsMSTProofError(.invalidPath) {
                try await RepositoryMSTProof.membership(
                    rootCID: fixture.mstRootCID,
                    key: key,
                    blocks: fixture.fullRepositoryBlocks
                )
            }
        }
    }

    // MARK: - bounds

    /// The node budget is the SAME `PublicRepositoryLimits` the full validators
    /// take; there is no second MST budget to drift.
    func testWalkIsBoundedByTheSharedMSTNodeBudget() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder.build()
        let tight = try PublicRepositoryLimits(
            maximumRecordBlockBytes: 1_000_000,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: 1,
            maximumMSTNodes: 1,
            maximumMSTEntriesPerNode: PublicRepositoryLimits
                .maximumPermittedMSTEntriesPerNode,
            maximumCBORNestingDepth: 64
        )
        await XCTAssertThrowsMSTProofError(.nodeLimitExceeded) {
            try await RepositoryMSTProof.membership(
                rootCID: fixture.mstRootCID,
                key: fixture.mstKey,
                blocks: fixture.proofBlocks,
                limits: tight
            )
        }
    }

    func testWalkIsBoundedByTheSharedEntriesPerNodeBudget() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder.build()
        let tight = try PublicRepositoryLimits(
            maximumRecordBlockBytes: 1_000_000,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: 1_000,
            maximumMSTNodes: 1_000,
            maximumMSTEntriesPerNode: 1,
            maximumCBORNestingDepth: 64
        )
        await XCTAssertThrowsMSTProofError(.entryLimitExceeded) {
            try await RepositoryMSTProof.membership(
                rootCID: fixture.mstRootCID,
                key: fixture.mstKey,
                blocks: fixture.proofBlocks,
                limits: tight
            )
        }
    }

    func testNodeBytesThatDoNotHashToTheirCIDAreRefused() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder.build()
        var storage: [CID: Data] = [:]
        for cid in fixture.pathNodeCIDs {
            storage[cid] = try await fixture.proofBlocks.block(for: cid)
        }
        // Swap the root's bytes for another node's: both are canonical MST
        // nodes, so only the hash binding catches the substitution.
        storage[fixture.mstRootCID] = storage[fixture.pathNodeCIDs[1]]

        await XCTAssertThrowsMSTProofError(.blockCIDMismatch) {
            try await RepositoryMSTProof.membership(
                rootCID: fixture.mstRootCID,
                key: fixture.mstKey,
                blocks: ProofTestBlockSource(storage)
            )
        }
    }

    // MARK: - the fixture builder, exercised as P2-E and P2-G will

    /// The whole chain over the CAR bytes: parse, verify the commit against the
    /// DID-document key, walk the MST, read the record. This is steps 8-13 of
    /// §5.7.4 minus the network.
    func testValidProofCARSupportsTheFullChain() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder.build()
        let parsed = try await parseCAR(fixture.carBytes)

        XCTAssertEqual(parsed.rootCID, fixture.commitCID)
        let commitBytes = try XCTUnwrap(parsed.blocks[parsed.rootCID])
        let commit = try await PublicRepositoryCommitCodec.verify(
            signedCommitBytes: commitBytes,
            expectedCommitCID: parsed.rootCID,
            verifier: fixture.documentVerifier
        )
        XCTAssertEqual(commit.descriptor.did, fixture.requestedDID)
        XCTAssertEqual(commit.descriptor.dataCID, fixture.mstRootCID)

        let recordCID = try await RepositoryMSTProof.membership(
            rootCID: commit.descriptor.dataCID,
            key: "\(fixture.collection)/\(fixture.nsid)",
            blocks: ProofTestBlockSource(parsed.blocks)
        )
        XCTAssertEqual(recordCID, fixture.recordCID)

        let recordBytes = try XCTUnwrap(parsed.blocks[try XCTUnwrap(recordCID)])
        XCTAssertNoThrow(
            try RepositoryMSTValidation.validateRecordBlock(
                recordBytes, for: fixture.recordPath
            )
        )
    }

    func testTwoRootCARIsRefusedByTheParser() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder.build(.twoCARRoots)
        XCTAssertEqual(fixture.carRootCIDs.count, 2)
        do {
            _ = try await parseCAR(fixture.carBytes)
            XCTFail("expected a two-root CAR to be refused")
        } catch let error as PublicRepositoryCARError {
            XCTAssertEqual(error, .invalidRootCount)
        }
    }

    /// The single most important vector in Phase 2. The substitute commit is
    /// GENUINELY valid under its own repository's key — a resolver that takes
    /// the key from the response passes every cryptographic check and is caught
    /// only by `commit.did == did`.
    func testCrossRepositorySubstitutionIsConvincingButWrongDID() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder
            .build(.crossRepositorySubstitution)

        XCTAssertNotEqual(fixture.commitDID, fixture.requestedDID)

        let selfSigned = try await PublicRepositoryCommitCodec.verify(
            signedCommitBytes: fixture.commitBytes,
            expectedCommitCID: fixture.commitCID,
            verifier: fixture.commitVerifier
        )
        XCTAssertEqual(selfSigned.descriptor.did, fixture.commitDID)

        // The lexicon really is at the expected rkey in the substitute repo,
        // so nothing downstream of the DID check would notice.
        let recordCID = try await RepositoryMSTProof.membership(
            rootCID: fixture.mstRootCID,
            key: fixture.mstKey,
            blocks: fixture.proofBlocks
        )
        XCTAssertEqual(recordCID, fixture.recordCID)

        await XCTAssertThrowsCommitError(.invalidSignature) {
            try await PublicRepositoryCommitCodec.verify(
                signedCommitBytes: fixture.commitBytes,
                expectedCommitCID: fixture.commitCID,
                verifier: fixture.documentVerifier
            )
        }
    }

    func testFlippedSignatureByteFailsTheCryptographicCheckNotTheShapeCheck() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder
            .build(.flippedCommitSignatureByte)

        // Structurally impeccable: canonical CBOR, matching CID, low-S
        // signature. Only the cryptographic check separates it from a real one.
        let structural = try PublicRepositoryCommitCodec.structurallyValidate(
            signedCommitBytes: fixture.commitBytes,
            expectedCommitCID: fixture.commitCID
        )
        XCTAssertEqual(structural.descriptor.did, fixture.requestedDID)

        await XCTAssertThrowsCommitError(.invalidSignature) {
            try await PublicRepositoryCommitCodec.verify(
                signedCommitBytes: fixture.commitBytes,
                expectedCommitCID: fixture.commitCID,
                verifier: fixture.documentVerifier
            )
        }
    }

    func testCommitSignedWithAKeyTheDocumentDoesNotNameIsRefused() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder
            .build(.commitSignedWithUnnamedKey)

        XCTAssertNotEqual(fixture.documentPublicKeyX963, fixture.commitPublicKeyX963)
        // A real signature — just not by the key the document names.
        _ = try await PublicRepositoryCommitCodec.verify(
            signedCommitBytes: fixture.commitBytes,
            expectedCommitCID: fixture.commitCID,
            verifier: fixture.commitVerifier
        )
        await XCTAssertThrowsCommitError(.invalidSignature) {
            try await PublicRepositoryCommitCodec.verify(
                signedCommitBytes: fixture.commitBytes,
                expectedCommitCID: fixture.commitCID,
                verifier: fixture.documentVerifier
            )
        }
    }

    /// Membership is not a type check, deliberately: the walk finds the record
    /// and the `$type` step is what refuses it. Collapsing the two would make
    /// "not in the tree" and "wrong lexicon" indistinguishable.
    func testRecordTypeMismatchIsReachableButRefusedByTheTypeCheck() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder
            .build(.recordTypeMismatch("app.bsky.feed.post"))

        let recordCID = try await RepositoryMSTProof.membership(
            rootCID: fixture.mstRootCID,
            key: fixture.mstKey,
            blocks: fixture.proofBlocks
        )
        XCTAssertEqual(recordCID, fixture.recordCID)

        XCTAssertThrowsError(
            try RepositoryMSTValidation.validateRecordBlock(
                fixture.recordBytes, for: fixture.recordPath
            )
        )
    }

    func testLexiconIDMismatchProducesADecodableRecordWithTheWrongID() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder
            .build(.lexiconIDMismatch("com.example.other.auth"))

        let decoded = try RepositoryMSTValidation.decodeRecordBlock(
            fixture.recordBytes, for: fixture.recordPath
        )
        guard case let .object(fields) = decoded,
              case let .string(id)? = fields["id"] else {
            return XCTFail("expected a decodable lexicon document")
        }
        XCTAssertEqual(id, "com.example.other.auth")
        XCTAssertNotEqual(id, fixture.nsid)
    }

    func testProofCARCarriesOnlyTheCommitPathAndRecord() async throws {
        let fixture = try await PublicRepositoryProofFixtureBuilder.build()
        let parsed = try await parseCAR(fixture.carBytes)
        let expected = Set([fixture.commitCID, fixture.recordCID])
            .union(fixture.pathNodeCIDs)
        XCTAssertEqual(Set(parsed.blocks.keys), expected)
        XCTAssertGreaterThanOrEqual(fixture.pathNodeCIDs.count, 2)
        XCTAssertEqual(fixture.pathNodeCIDs.first, fixture.mstRootCID)
    }

    // MARK: - helpers

    private func parseCAR(_ bytes: Data) async throws -> (rootCID: CID, blocks: [CID: Data]) {
        let sink = CollectingCARFrameSink()
        let result = try await PublicRepositoryCAR.parseIncrementally(
            from: SingleShotCARByteSource(bytes),
            to: sink
        )
        return (result.rootCID, await sink.blocks)
    }
}

private struct ProofTestBlockSource: PublicRepositoryBlockSource {
    private let storage: [CID: Data]

    init(_ storage: [CID: Data]) {
        self.storage = storage
    }

    func block(for cid: CID) async throws -> Data? {
        storage[cid]
    }
}

private struct DiscardingProjectionSink: PublicRepositoryReachableProjectionSink {
    func recordReachableBlock(
        cid _: CID,
        kind _: PublicRepositoryReachableBlockKind
    ) async throws {}

    func recordRepositoryIndex(
        path _: PublicRepositoryPath,
        recordCID _: CID
    ) async throws {}
}

private actor SingleShotCARByteSource: PublicRepositoryCARByteSource {
    private let bytes: Data
    private var offset = 0

    init(_ bytes: Data) {
        self.bytes = bytes
    }

    func read(maximumBytes: Int) async throws -> Data? {
        guard offset < bytes.count else { return nil }
        let count = min(maximumBytes, bytes.count - offset)
        defer { offset += count }
        return bytes.subdata(in: offset ..< offset + count)
    }
}

private actor CollectingCARFrameSink: PublicRepositoryCARFrameSink {
    private(set) var blocks: [CID: Data] = [:]

    func receiveHeader(rootCID _: CID, receivedByteCount _: Int) async throws {}

    func receiveBlock(
        _ block: PublicRepositoryBlock,
        receivedByteCount _: Int,
        frameCount _: Int
    ) async throws {
        blocks[block.cid] = block.bytes
    }
}

private func XCTAssertThrowsMSTProofError<T>(
    _ expected: RepositoryMSTValidationError,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ expression: () async throws -> T
) async {
    do {
        _ = try await expression()
        XCTFail("expected \(expected)", file: file, line: line)
    } catch {
        XCTAssertEqual(
            error as? RepositoryMSTValidationError, expected,
            file: file, line: line
        )
    }
}

private func XCTAssertThrowsCommitError<T>(
    _ expected: PublicRepositoryCommitError,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ expression: () async throws -> T
) async {
    do {
        _ = try await expression()
        XCTFail("expected \(expected)", file: file, line: line)
    } catch {
        XCTAssertEqual(
            error as? PublicRepositoryCommitError, expected,
            file: file, line: line
        )
    }
}
