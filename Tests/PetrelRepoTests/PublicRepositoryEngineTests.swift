import Crypto
import Foundation
import Petrel
import PetrelCrypto
@testable import PetrelRepo
import XCTest

final class PublicRepositoryEngineTests: XCTestCase {
    private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    private let firstRevision = "3jzfcijpj2z22"
    private let secondRevision = "3jzfcijpj2z2a"

    func testCreateProducesOneAtomicValidatedRepositoryMutation() async throws {
        let fixture = try makeEmptyFixture()
        let path = try path("first")
        let record = post("hello")
        let expectedRecord = try PublicRepositoryRecordCodec.prepare(record, for: path)
        let signer = CountingEngineSigner(key: fixture.key)
        let batch = try PublicRepositoryWriteBatch(writes: [
            .create(path: path, record: record),
        ])

        let result = try await PublicRepositoryEngine.apply(
            repositoryDID: did,
            currentState: fixture.state,
            blocks: fixture.blocks,
            revision: secondRevision,
            batch: batch,
            signer: signer
        )

        XCTAssertEqual(result.state.did, did)
        XCTAssertEqual(result.state.revision, secondRevision)
        XCTAssertEqual(result.state.commitCID, result.signedCommit.commitCID)
        XCTAssertEqual(result.state.dataCID, result.signedCommit.descriptor.dataCID)
        XCTAssertEqual(
            expectedRecord.cid.string,
            "bafyreicl5wcgzaefpu23bimapxa4lj7kbx7dczrtbmh6haqztpqkjk6uza"
        )
        XCTAssertEqual(
            result.state.dataCID.string,
            "bafyreifl6vqomncvtquboa2gmvjyhnwgq7lyakyp7zj5hwjwmvjlmhyg5e"
        )
        XCTAssertEqual(result.recordResults, [
            PublicRepositoryMutationRecordResult(
                action: .create,
                path: path,
                recordCID: expectedRecord.cid,
                previousRecordCID: nil
            ),
        ])
        XCTAssertEqual(result.baseCommitCID, fixture.state.commitCID)
        XCTAssertEqual(result.sinceRevision, fixture.state.revision)
        XCTAssertTrue(result.publicBlobCIDs.isEmpty)
        XCTAssertTrue(result.publicTypedBlobReferences.isEmpty)
        let signerCallCount = await signer.callCount
        XCTAssertEqual(signerCallCount, 1)
        XCTAssertEqual(
            result.newBlocks.cids,
            [expectedRecord.cid, result.state.dataCID, result.state.commitCID]
        )
        let returnedRecordBlock = try await result.newBlocks.block(for: expectedRecord.cid)
        let returnedCommitBlock = try await result.newBlocks.block(for: result.state.commitCID)
        XCTAssertEqual(returnedRecordBlock, expectedRecord.bytes)
        XCTAssertEqual(returnedCommitBlock, result.signedCommit.signedCommitBytes)

        let combined = try fixture.blocks.adding(result.newBlocks.blocks)
        let validation = try await RepositoryMSTValidation.validate(
            rootCID: result.state.dataCID,
            blocks: combined
        )
        XCTAssertEqual(validation.leaves, [
            RepositoryMSTLeaf(path: path, recordCID: expectedRecord.cid),
        ])
        let verified = try await PublicRepositoryCommitCodec.verify(
            signedCommitBytes: result.signedCommit.signedCommitBytes,
            expectedCommitCID: result.state.commitCID,
            verifier: P256PublicRepositoryCommitVerifier(publicKey: fixture.key.publicKey)
        )
        XCTAssertEqual(verified.descriptor.dataCID, result.state.dataCID)
        XCTAssertEqual(fixture.state.dataCID, PublicRepositoryGenesisCodec.canonicalEmptyMSTCIDValue)
        XCTAssertEqual(fixture.blocks.count, 2)
    }

    func testMixedUpdateDeleteAndCreateUsesOneEvolvingTreeInCallerOrder() async throws {
        let fixture = try makeEmptyFixture()
        let originalPath = try path("original")
        let deletedPath = try path("deleted")
        let first = try await apply(
            fixture: fixture,
            revision: secondRevision,
            writes: [
                .create(path: originalPath, record: post("one")),
                .create(path: deletedPath, record: post("gone")),
            ]
        )
        let base = try fixture.blocks.adding(first.newBlocks.blocks)
        let originalCID = first.recordResults[0].recordCID!
        let deletedCID = first.recordResults[1].recordCID!
        let createdPath = try path("created")
        let signer = CountingEngineSigner(key: fixture.key)
        let batch = try PublicRepositoryWriteBatch(
            writes: [
                .update(path: originalPath, record: post("two"), expectedRecordCID: originalCID),
                .delete(path: deletedPath, expectedRecordCID: deletedCID),
                .create(path: createdPath, record: post("three")),
            ],
            expectedCommitCID: first.state.commitCID
        )

        let result = try await PublicRepositoryEngine.apply(
            repositoryDID: did,
            currentState: first.state,
            blocks: base,
            revision: "3jzfcijpj2z2b",
            batch: batch,
            signer: signer
        )

        XCTAssertEqual(result.recordResults.map(\.action), [.update, .delete, .create])
        XCTAssertEqual(result.recordResults[0].previousRecordCID, originalCID)
        XCTAssertEqual(result.recordResults[1].previousRecordCID, deletedCID)
        XCTAssertNil(result.recordResults[1].recordCID)
        XCTAssertNil(result.recordResults[2].previousRecordCID)
        let combined = try base.adding(result.newBlocks.blocks)
        let validation = try await RepositoryMSTValidation.validate(
            rootCID: result.state.dataCID,
            blocks: combined
        )
        XCTAssertEqual(validation.leaves.map(\.path), [createdPath, originalPath])
        let signerCallCount = await signer.callCount
        XCTAssertEqual(signerCallCount, 1)
    }

    func testCommitAndRecordCompareAndSwapMatrix() async throws {
        let fixture = try makeEmptyFixture()
        let recordPath = try path("cas")
        let first = try await apply(
            fixture: fixture,
            revision: secondRevision,
            writes: [.create(path: recordPath, record: post("one"))]
        )
        let base = try fixture.blocks.adding(first.newBlocks.blocks)
        let currentCID = first.recordResults[0].recordCID!

        let successfulSigner = CountingEngineSigner(key: fixture.key)
        let success = try await PublicRepositoryEngine.apply(
            repositoryDID: did,
            currentState: first.state,
            blocks: base,
            revision: "3jzfcijpj2z2b",
            batch: try PublicRepositoryWriteBatch(
                writes: [.update(path: recordPath, record: post("two"), expectedRecordCID: currentCID)],
                expectedCommitCID: first.state.commitCID
            ),
            signer: successfulSigner
        )
        XCTAssertEqual(success.recordResults[0].previousRecordCID, currentCID)

        let wrongCID = PublicRepositoryGenesisCodec.canonicalEmptyMSTCIDValue
        await assertEngineFailure(
            .commitCIDMismatch,
            fixture: fixture,
            state: first.state,
            blocks: base,
            revision: "3jzfcijpj2z2b",
            batch: try PublicRepositoryWriteBatch(
                writes: [.update(path: recordPath, record: post("two"), expectedRecordCID: currentCID)],
                expectedCommitCID: wrongCID
            )
        )
        await assertEngineFailure(
            .recordCIDMismatch,
            fixture: fixture,
            state: first.state,
            blocks: base,
            revision: "3jzfcijpj2z2b",
            batch: try PublicRepositoryWriteBatch(writes: [
                .delete(path: recordPath, expectedRecordCID: wrongCID),
            ])
        )
    }

    func testAllPreSignFailuresInvokeSignerZeroTimesAndPreserveBase() async throws {
        let fixture = try makeEmptyFixture()
        let existing = try path("existing")
        let missing = try path("missing")
        let first = try await apply(
            fixture: fixture,
            revision: secondRevision,
            writes: [.create(path: existing, record: post("one"))]
        )
        let base = try fixture.blocks.adding(first.newBlocks.blocks)
        let invalid = PublicRecord(["$type": .string("app.bsky.feed.like"), "text": .string("secret")])
        let cases: [(PublicRepositoryEngineError, String, PublicRepositoryWriteBatch, String)] = [
            (
                .repositoryDIDMismatch,
                "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa",
                try PublicRepositoryWriteBatch(writes: [.delete(path: existing, expectedRecordCID: nil)]),
                "3jzfcijpj2z2b"
            ),
            (
                .revisionNotIncreasing,
                did,
                try PublicRepositoryWriteBatch(writes: [.delete(path: existing, expectedRecordCID: nil)]),
                secondRevision
            ),
            (
                .invalidRevision,
                did,
                try PublicRepositoryWriteBatch(writes: [.delete(path: existing, expectedRecordCID: nil)]),
                "invalid"
            ),
            (
                .recordAlreadyExists,
                did,
                try PublicRepositoryWriteBatch(writes: [.create(path: existing, record: post("again"))]),
                "3jzfcijpj2z2b"
            ),
            (
                .recordNotFound,
                did,
                try PublicRepositoryWriteBatch(writes: [.update(path: missing, record: post("no"), expectedRecordCID: nil)]),
                "3jzfcijpj2z2b"
            ),
            (
                .record(.invalidRecordType),
                did,
                try PublicRepositoryWriteBatch(writes: [.update(path: existing, record: invalid, expectedRecordCID: nil)]),
                "3jzfcijpj2z2b"
            ),
        ]
        for (expected, repositoryDID, batch, revision) in cases {
            let signer = CountingEngineSigner(key: fixture.key)
            do {
                _ = try await PublicRepositoryEngine.apply(
                    repositoryDID: repositoryDID,
                    currentState: first.state,
                    blocks: base,
                    revision: revision,
                    batch: batch,
                    signer: signer
                )
                XCTFail("expected \(expected)")
            } catch {
                XCTAssertEqual(error as? PublicRepositoryEngineError, expected)
            }
            let callCount = await signer.callCount
            XCTAssertEqual(callCount, 0)
            XCTAssertEqual(first.state.dataCID, first.signedCommit.descriptor.dataCID)
            XCTAssertEqual(base.count, fixture.blocks.count + first.newBlocks.count)
        }
    }

    func testIdenticalRecordBytesAreDeduplicatedAcrossPaths() async throws {
        let fixture = try makeEmptyFixture()
        let firstPath = try path("a")
        let secondPath = try path("b")
        let identical = post("same")
        let expected = try PublicRepositoryRecordCodec.prepare(identical, for: firstPath)

        let result = try await apply(
            fixture: fixture,
            revision: secondRevision,
            writes: [
                .create(path: firstPath, record: identical),
                .create(path: secondPath, record: identical),
            ]
        )

        XCTAssertEqual(result.recordResults.map(\.recordCID), [expected.cid, expected.cid])
        XCTAssertEqual(
            result.newBlocks.cids.filter { $0 == expected.cid }.count,
            1
        )
        let combined = try fixture.blocks.adding(result.newBlocks.blocks)
        let validation = try await RepositoryMSTValidation.validate(
            rootCID: result.state.dataCID,
            blocks: combined
        )
        XCTAssertEqual(validation.leaves.map(\.recordCID), [expected.cid, expected.cid])
    }

    func testDeletingLastRecordReturnsOnlyNewCommitAndCanonicalEmptyRoot() async throws {
        let fixture = try makeEmptyFixture()
        let recordPath = try path("last")
        let first = try await apply(
            fixture: fixture,
            revision: secondRevision,
            writes: [.create(path: recordPath, record: post("one"))]
        )
        let base = try fixture.blocks.adding(first.newBlocks.blocks)
        let signer = CountingEngineSigner(key: fixture.key)
        let result = try await PublicRepositoryEngine.apply(
            repositoryDID: did,
            currentState: first.state,
            blocks: base,
            revision: "3jzfcijpj2z2b",
            batch: try PublicRepositoryWriteBatch(writes: [
                .delete(path: recordPath, expectedRecordCID: first.recordResults[0].recordCID),
            ]),
            signer: signer
        )

        XCTAssertEqual(result.state.dataCID, PublicRepositoryGenesisCodec.canonicalEmptyMSTCIDValue)
        XCTAssertEqual(result.newBlocks.cids, [result.state.commitCID])
        XCTAssertEqual(result.recordResults[0].previousRecordCID, first.recordResults[0].recordCID)
        XCTAssertNil(result.recordResults[0].recordCID)
        XCTAssertFalse(result.newBlocks.cids.contains(first.state.dataCID))
        XCTAssertFalse(result.newBlocks.cids.contains(first.recordResults[0].recordCID!))
    }

    func testMissingBaseMSTMapsToTypedFailureBeforeSigning() async throws {
        let fixture = try makeEmptyFixture()
        let signer = CountingEngineSigner(key: fixture.key)
        let onlyCommit = try PublicRepositoryBlockMap(blocks: fixture.blocks.blocks.filter {
            $0.cid == fixture.state.commitCID
        })
        do {
            _ = try await PublicRepositoryEngine.apply(
                repositoryDID: did,
                currentState: fixture.state,
                blocks: onlyCommit,
                revision: secondRevision,
                batch: try PublicRepositoryWriteBatch(writes: [
                    .create(path: try path("missing-root"), record: post("one")),
                ]),
                signer: signer
            )
            XCTFail("expected missing root")
        } catch {
            XCTAssertEqual(error as? PublicRepositoryEngineError, .mst(.missingBlock))
        }
        let callCount = await signer.callCount
        XCTAssertEqual(callCount, 0)
    }

    func testAggregateRelevantByteOverflowFailsBeforeSigning() async throws {
        let fixture = try makeEmptyFixture()
        let firstPath = try path("large-a")
        let secondPath = try path("large-b")
        let largeA = post(String(repeating: "a", count: 999_800))
        let largeB = post(String(repeating: "b", count: 999_800))
        let signer = CountingEngineSigner(key: fixture.key)
        let batch = try PublicRepositoryWriteBatch(writes: [
            .create(path: firstPath, record: largeA),
            .create(path: secondPath, record: largeB),
        ])

        do {
            _ = try await PublicRepositoryEngine.apply(
                repositoryDID: did,
                currentState: fixture.state,
                blocks: fixture.blocks,
                revision: secondRevision,
                batch: batch,
                signer: signer
            )
            XCTFail("expected relevant-byte overflow")
        } catch {
            XCTAssertEqual(error as? PublicRepositoryEngineError, .relevantBlockBudgetExceeded)
        }
        let callCount = await signer.callCount
        XCTAssertEqual(callCount, 0)
        XCTAssertEqual(fixture.blocks.count, 2)
    }

    func testUnsupportedAndThrowingSignersMapToTypedErrors() async throws {
        let fixture = try makeEmptyFixture()
        let recordPath = try path("signer")
        let batch = try PublicRepositoryWriteBatch(writes: [
            .create(path: recordPath, record: post("one")),
        ])
        let unsupported = UnsupportedEngineSigner()
        do {
            _ = try await PublicRepositoryEngine.apply(
                repositoryDID: did,
                currentState: fixture.state,
                blocks: fixture.blocks,
                revision: secondRevision,
                batch: batch,
                signer: unsupported
            )
            XCTFail("expected unsupported signer")
        } catch {
            XCTAssertEqual(
                error as? PublicRepositoryEngineError,
                .commit(.unsupportedSigningAlgorithm)
            )
        }
        let unsupportedCount = await unsupported.count()
        XCTAssertEqual(unsupportedCount, 0)

        let throwing = ThrowingEngineSigner()
        do {
            _ = try await PublicRepositoryEngine.apply(
                repositoryDID: did,
                currentState: fixture.state,
                blocks: fixture.blocks,
                revision: secondRevision,
                batch: batch,
                signer: throwing
            )
            XCTFail("expected signing failure")
        } catch {
            XCTAssertEqual(error as? PublicRepositoryEngineError, .signingFailed)
        }
        let throwingCount = await throwing.count()
        XCTAssertEqual(throwingCount, 1)
    }

    private func apply(
        fixture: (
            key: P256.Signing.PrivateKey,
            state: PublicRepositoryState,
            blocks: PublicRepositoryBlockMap
        ),
        revision: String,
        writes: [PublicRepositoryWrite]
    ) async throws -> PreparedPublicRepositoryMutation {
        try await PublicRepositoryEngine.apply(
            repositoryDID: did,
            currentState: fixture.state,
            blocks: fixture.blocks,
            revision: revision,
            batch: try PublicRepositoryWriteBatch(writes: writes),
            signer: CountingEngineSigner(key: fixture.key)
        )
    }

    private func assertEngineFailure(
        _ expected: PublicRepositoryEngineError,
        fixture: (
            key: P256.Signing.PrivateKey,
            state: PublicRepositoryState,
            blocks: PublicRepositoryBlockMap
        ),
        state: PublicRepositoryState,
        blocks: PublicRepositoryBlockMap,
        revision: String,
        batch: PublicRepositoryWriteBatch,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let signer = CountingEngineSigner(key: fixture.key)
        do {
            _ = try await PublicRepositoryEngine.apply(
                repositoryDID: did,
                currentState: state,
                blocks: blocks,
                revision: revision,
                batch: batch,
                signer: signer
            )
            XCTFail("expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? PublicRepositoryEngineError, expected, file: file, line: line)
        }
        let callCount = await signer.callCount
        XCTAssertEqual(callCount, 0, file: file, line: line)
    }

    private func makeEmptyFixture() throws -> (
        key: P256.Signing.PrivateKey,
        state: PublicRepositoryState,
        blocks: PublicRepositoryBlockMap
    ) {
        let key = try P256.Signing.PrivateKey(rawRepresentation: Data(repeating: 7, count: 32))
        let genesis = try PublicRepositoryGenesisCodec.create(
            did: did,
            revision: firstRevision,
            signingKey: key
        )
        return (
            key,
            try PublicRepositoryState(
                did: did,
                revision: firstRevision,
                commitCID: genesis.commitCID,
                dataCID: genesis.emptyMSTCID
            ),
            try PublicRepositoryBlockMap(blocks: [
                .init(cid: genesis.commitCID, bytes: genesis.signedCommit),
                .init(cid: genesis.emptyMSTCID, bytes: genesis.emptyMST),
            ])
        )
    }

    private func path(_ key: String, collection: String = "app.bsky.feed.post") throws -> PublicRepositoryPath {
        try PublicRepositoryPath(collection: collection, recordKey: key)
    }

    private func post(_ text: String) -> PublicRecord {
        PublicRecord([
            "$type": .string("app.bsky.feed.post"),
            "text": .string(text),
        ])
    }
}

private actor CountingEngineSigner: PublicRepositoryCommitSigner {
    let signingAlgorithm: PublicRepositorySigningAlgorithm = .p256
    private let key: P256.Signing.PrivateKey
    private(set) var callCount = 0

    init(key: P256.Signing.PrivateKey) {
        self.key = key
    }

    func sign(unsignedCommitBytes: Data) async throws -> Data {
        callCount += 1
        return try P256WireSignature.sign(unsignedCommitBytes, using: key)
    }
}

private actor UnsupportedEngineSigner: PublicRepositoryCommitSigner {
    let signingAlgorithm: PublicRepositorySigningAlgorithm = .secp256k1
    private var callCount = 0

    func sign(unsignedCommitBytes _: Data) async throws -> Data {
        callCount += 1
        return Data(repeating: 0, count: 64)
    }

    func count() -> Int { callCount }
}

private actor ThrowingEngineSigner: PublicRepositoryCommitSigner {
    enum Failure: Error { case failed }

    let signingAlgorithm: PublicRepositorySigningAlgorithm = .p256
    private var callCount = 0

    func sign(unsignedCommitBytes _: Data) async throws -> Data {
        callCount += 1
        throw Failure.failed
    }

    func count() -> Int { callCount }
}

private extension PublicRepositoryGenesisCodec {
    static var canonicalEmptyMSTCIDValue: CID {
        CID.fromDAGCBOR(canonicalEmptyMST)
    }
}

private extension PublicRepositoryBlockMap {
    var blocks: [PublicRepositoryBlock] {
        cids.compactMap { cid in
            block(for: cid).map { PublicRepositoryBlock(cid: cid, bytes: $0) }
        }
    }
}
