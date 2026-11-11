import Foundation
import Petrel
import PetrelCrypto
import PetrelRepo
import Testing

/// Differential test against a repository exported from the network.
///
/// `Vectors/real-repo/repo.car` is an unmodified `com.atproto.sync.getRepo`
/// export of a public account, signed with secp256k1 by a production PDS.
/// `expected.json` holds facts about it computed by an independent Python
/// reader (`carstat.py`), and `diddoc.json` is the account's DID document.
/// See `Vectors/real-repo/README.md` for provenance.
@Suite("Real repository export (secp256k1, production PDS)")
struct RealRepositoryDifferentialTests {
    private struct Expected: Decodable {
        let did: String
        let rev: String
        let version: Int
        let commit: String
        let data: String
        let carBytes: Int
        let carSHA256: String
        let frames: Int
        let distinctBlocks: Int
        let records: Int
        let collections: [String: Int]
    }

    private func expected() throws -> Expected {
        try Vectors.decode(Expected.self, "real-repo/expected.json")
    }

    /// The signing key comes from the captured DID document, never from the
    /// archive being checked.
    private func signingKey() throws -> ATProtoPublicKey {
        let expected = try expected()
        return try Repository.signingKey(
            fromDIDDocument: try Vectors.data("real-repo/diddoc.json"), did: expected.did
        )
    }

    private func open(store: any RepositoryBlockStore = InMemoryRepositoryBlockStore()) async throws -> Repository {
        try await Repository.open(
            car: try Vectors.data("real-repo/repo.car"),
            verification: .signingKey(try signingKey()),
            expectedDID: try expected().did,
            store: store
        )
    }

    @Test("the DID document yields a secp256k1 signing key")
    func signingKeyFromDIDDocument() throws {
        let key = try signingKey()
        #expect(key.curve == .k256)
        #expect(key.multikey == "zQ3shunBKsXixLxKtC5qeSG9E4J5RkGN57im31pcTzbNQnm5w")
        #expect(throws: RepositoryError.signingKeyNotFound) {
            try Repository.signingKey(
                fromDIDDocument: try Vectors.data("real-repo/diddoc.json"),
                did: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa"
            )
        }
    }

    @Test("root, revision, signature and record count match the independent reader")
    func verifiesAgainstOracle() async throws {
        let expected = try expected()
        let repository = try await open()

        #expect(repository.did == expected.did)
        #expect(repository.revision.value == expected.rev)
        #expect(repository.commit.cid.string == expected.commit)
        #expect(repository.commit.dataCID.string == expected.data)
        #expect(repository.commit.previousCommitCID == nil)
        #expect(repository.commit.isSignatureVerified)
        #expect(expected.version == 3)

        let statistics = try #require(repository.statistics)
        #expect(statistics.recordCount == expected.records)
        #expect(statistics.recordCount == 1_868)
        #expect(statistics.unverifiableRecordCount == 0)
        #expect(try await repository.store.blockCount() == expected.distinctBlocks)
        // Every block is the commit, an MST node, or a record: nothing else.
        #expect(1 + statistics.mstNodeCount + statistics.recordCount == expected.distinctBlocks)
    }

    @Test("every collection has the record count the independent reader found")
    func collectionCounts() async throws {
        let expected = try expected()
        let repository = try await open()
        #expect(try await repository.collections() == expected.collections.keys.sorted())

        var counts: [String: Int] = [:]
        var previousKey: String?
        try await repository.forEachRecord { record in
            counts[record.collection, default: 0] += 1
            // Enumeration is in key order and every record decodes.
            if let previousKey { #expect(previousKey < record.path.mstKey) }
            previousKey = record.path.mstKey
            let value = try record.record()
            #expect(value.type == record.collection)
            #expect(CID.fromDAGCBOR(record.bytes) == record.cid)
        }
        #expect(counts == expected.collections)

        // Ranged enumeration reads one collection and agrees.
        for (collection, count) in expected.collections {
            #expect(try await repository.records(collection: collection).count == count, "\(collection)")
        }
        #expect(try await repository.records(collection: "com.example.absent").isEmpty)
    }

    @Test("the depth-bounded walker and the in-memory validator agree leaf for leaf")
    func walkerAgreesWithValidator() async throws {
        let repository = try await open()
        var walked: [(String, CID)] = []
        let summary = try await RepositoryMSTWalker.walk(
            rootCID: repository.commit.dataCID, blocks: repository.store
        ) { leaf in
            walked.append((leaf.path.mstKey, leaf.recordCID))
            return true
        }
        for policy in [RepositoryReadPolicy.dataModel, .strict] {
            let validated = try await RepositoryMSTValidation.validate(
                rootCID: repository.commit.dataCID,
                blocks: repository.store,
                limits: .networkScale,
                policy: policy
            )
            #expect(validated.leaves.map(\.path.mstKey) == walked.map(\.0))
            #expect(validated.leaves.map(\.recordCID) == walked.map(\.1))
            #expect(validated.reachableMSTBlocks.count == summary.nodeCount)
            #expect(validated.rootLayer == summary.rootLayer)
        }
        // A third, independent construction of the same tree: rebuild it
        // bottom-up from the leaves and compare roots.
        let rebuilt = try await BulkMST.build(
            try walked.map { BulkMST.Entry(path: try PublicRepositoryPath(mstKey: $0.0), recordCID: $0.1) }
        ) { _ in }
        #expect(rebuilt == repository.commit.dataCID)
        // And a fourth: insert the leaves one at a time, in a shuffled order.
        var incremental = try RepositoryMST.empty(limits: .networkScale)
        for (key, cid) in walked.shuffled() {
            incremental = try await incremental.adding(path: try PublicRepositoryPath(mstKey: key), recordCID: cid)
        }
        #expect(try await incremental.rootCID() == repository.commit.dataCID)
    }

    @Test("the commit signature is the account's: any other key is refused")
    func signatureIsChecked() async throws {
        let car = try Vectors.data("real-repo/repo.car")
        for wrong in [K256Keypair.generate().publicKey, P256Keypair.generate().publicKey] {
            await #expect(throws: RepositoryError.commit(.invalidSignature)) {
                try await Repository.open(car: car, verification: .signingKey(wrong))
            }
        }
        await #expect(throws: RepositoryError.self) {
            try await Repository.open(
                car: car,
                verification: .signingKey(try signingKey()),
                expectedDID: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa"
            )
        }
        // The low-level, protocol-typed path used by the firehose agrees.
        let imported = try await PublicRepositoryCAR.importRepository(
            from: DataCARByteSource(car),
            verifier: ATProtoRepositoryCommitVerifier(publicKey: try signingKey()),
            limits: .networkScale,
            policy: .dataModel
        )
        #expect(imported.repository.leaves.count == 1_868)
        #expect(imported.signedCommit.signingAlgorithm == .secp256k1)
    }

    @Test("re-serialising the imported blocks reproduces the export byte for byte")
    func byteIdenticalRoundTrip() async throws {
        let expected = try expected()
        let original = try Vectors.data("real-repo/repo.car")
        #expect(original.count == expected.carBytes)

        let repository = try await open()
        let rewritten = try await repository.exportCAR(order: .stored)
        #expect(rewritten == original)

        // The same through a file-backed store and a file sink.
        let scratch = try ScratchDirectory()
        let store = try FileRepositoryBlockStore(url: scratch.file("blocks"))
        let onDisk = try await Repository.open(
            carFile: try Vectors.url("real-repo/repo.car"),
            verification: .signingKey(try signingKey()),
            store: store
        )
        let sink = try FileCARByteSink(url: scratch.file("out.car"))
        let written = try await onDisk.exportCAR(to: sink, order: .stored)
        try await sink.synchronize()
        #expect(written.byteCount == original.count)
        #expect(written.blockCount == expected.frames)
        #expect(try Data(contentsOf: scratch.file("out.car")) == original)
    }

    @Test("canonical exports contain exactly the reachable blocks and re-import to the same repository")
    func canonicalExports() async throws {
        let expected = try expected()
        let repository = try await open()
        let key = try signingKey()
        for order in [RepositoryCARBlockOrder.streamable, .breadthFirst] {
            let exported = try await repository.exportCAR(order: order)
            // This export has no unreachable or duplicate blocks, so both
            // orders are permutations of the original and the same size.
            #expect(exported.count == expected.carBytes, "\(order)")
            let reopened = try await Repository.open(car: exported, verification: .signingKey(key))
            #expect(reopened.commit == repository.commit, "\(order)")
            #expect(reopened.statistics == repository.statistics, "\(order)")
            #expect(try await reopened.store.blockCount() == expected.distinctBlocks, "\(order)")
        }
    }

    @Test("the strict (hosting-service) policy also accepts this repository")
    func strictPolicyAccepts() async throws {
        let repository = try await Repository.open(
            car: try Vectors.data("real-repo/repo.car"),
            verification: .signingKey(try signingKey()),
            options: RepositoryOptions(limits: .standard, policy: .strict)
        )
        #expect(repository.statistics?.recordCount == 1_868)
    }

    @Test("a server-issued inclusion proof verifies, and matches the proof built locally")
    func inclusionProof() async throws {
        let expected = try expected()
        let proofCAR = try Vectors.data("real-repo/record-proof-present.car")
        let verified = try await Repository.verifyRecordProof(
            car: proofCAR,
            did: expected.did,
            collection: "app.bsky.actor.profile",
            recordKey: "self",
            verification: .signingKey(try signingKey())
        )
        #expect(verified.commit.cid.string == expected.commit)
        let record = try #require(verified.record)

        // The full repository holds the same record under the same CID.
        let repository = try await open()
        let local = try #require(
            try await repository.record(collection: "app.bsky.actor.profile", recordKey: "self")
        )
        #expect(local == record)
        #expect(try record.record().type == "app.bsky.actor.profile")
        #expect(try PublicRecord(json: record.json()) == record.record())

        // The proof Petrel builds carries the same blocks the PDS sent.
        let built = try await repository.recordProof(collection: "app.bsky.actor.profile", recordKey: "self")
        #expect(built.recordCID == record.cid)
        let serverBlocks = InMemoryRepositoryBlockStore()
        _ = try await PublicRepositoryCAR.parseIncrementally(
            from: DataCARByteSource(proofCAR),
            to: BlockCollector(store: serverBlocks),
            limits: .networkScale,
            policy: .dataModel
        )
        #expect(Set(built.blocks.map(\.cid)) == Set(try await serverBlocks.storedCIDs()))
        // And it verifies in its own right.
        let reverified = try await Repository.verifyRecordProof(
            car: try await built.car(),
            did: expected.did,
            collection: "app.bsky.actor.profile",
            recordKey: "self",
            verification: .signingKey(try signingKey())
        )
        #expect(reverified.record == record)
    }

    @Test("a server-issued exclusion proof proves absence, and cannot be used for another key")
    func exclusionProof() async throws {
        let expected = try expected()
        let proofCAR = try Vectors.data("real-repo/record-proof-absent.car")
        let key = try signingKey()
        let verified = try await Repository.verifyRecordProof(
            car: proofCAR,
            did: expected.did,
            collection: "app.bsky.actor.profile",
            recordKey: "doesnotexist",
            verification: .signingKey(key)
        )
        #expect(verified.record == nil)
        #expect(verified.commit.cid.string == expected.commit)

        // The proof for one key says nothing about a key elsewhere in the
        // tree: the path to it is not in the archive, so verification
        // throws instead of reporting "absent".
        await #expect(throws: RepositoryError.tree(.missingBlock)) {
            try await Repository.verifyRecordProof(
                car: proofCAR,
                did: expected.did,
                collection: "app.bsky.feed.post",
                recordKey: "3jzfcijpj2z2a",
                verification: .signingKey(key)
            )
        }
        // Nor is it accepted for another account or under another key.
        await #expect(throws: RepositoryError.self) {
            try await Repository.verifyRecordProof(
                car: proofCAR,
                did: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa",
                collection: "app.bsky.actor.profile",
                recordKey: "doesnotexist",
                verification: .signingKey(key)
            )
        }
        await #expect(throws: RepositoryError.commit(.invalidSignature)) {
            try await Repository.verifyRecordProof(
                car: proofCAR,
                did: expected.did,
                collection: "app.bsky.actor.profile",
                recordKey: "doesnotexist",
                verification: .signingKey(K256Keypair.generate().publicKey)
            )
        }
    }

    @Test("corrupting any single byte of the export is detected")
    func corruptionIsDetected() async throws {
        let original = try Vectors.data("real-repo/repo.car")
        let key = try signingKey()
        // Offsets spread across the header, the commit, MST nodes and
        // records. Flipping a byte must never yield a repository.
        var generator = SystemRandomNumberGenerator()
        var offsets = [0, 1, 20, 58, 59, 60, 100, original.count - 1]
        for _ in 0 ..< 24 { offsets.append(Int.random(in: 0 ..< original.count, using: &generator)) }
        for offset in offsets {
            var corrupted = original
            corrupted[offset] ^= 0x01
            await #expect(throws: (any Error).self, "offset \(offset)") {
                try await Repository.open(car: corrupted, verification: .signingKey(key))
            }
        }
        // Truncation at a frame boundary loses blocks the tree needs.
        await #expect(throws: (any Error).self) {
            try await Repository.open(
                car: original.prefix(original.count / 2), verification: .signingKey(key)
            )
        }
    }

    @Test("writing on top of the real repository produces a verifiable commit and diff")
    func commitOnTopOfRealRepository() async throws {
        let repository = try await open()
        let signer = K256Keypair.generate()
        let result = try await repository.commit(
            [
                .create(
                    path: try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "3zzzzzzzzzzzz"),
                    record: [
                        "$type": .string("app.bsky.feed.post"),
                        "text": .string("written by a test"),
                        "createdAt": .string("2026-11-11T00:00:00.000Z"),
                    ]
                ),
                .delete(
                    path: try PublicRepositoryPath(collection: "app.bsky.actor.profile", recordKey: "self"),
                    expectedRecordCID: nil
                ),
            ],
            signer: signer
        )
        #expect(result.repository.revision > repository.revision)
        #expect(result.previousDataCID == repository.commit.dataCID)

        // A consumer that holds nothing but the diff verifies it.
        let diff = InMemoryRepositoryBlockStore()
        try await diff.put(result.diffBlocks)
        let verified = try await RepositoryCommitDiff.verify(
            commitCID: result.repository.commit.cid,
            operations: result.operations,
            previousDataCID: result.previousDataCID,
            blocks: diff,
            keyResolver: FixedRepositorySigningKey(signer.publicKey),
            expectedDID: repository.did,
            limits: .networkScale
        )
        #expect(verified.commit.descriptor.dataCID == result.repository.commit.dataCID)

        // The new head verifies in full and has one record more, one less.
        let statistics = try await result.repository.verify()
        #expect(statistics.recordCount == 1_868)
        #expect(try await result.repository.record(collection: "app.bsky.actor.profile", recordKey: "self") == nil)
        #expect(try await result.repository.record(collection: "app.bsky.feed.post", recordKey: "3zzzzzzzzzzzz") != nil)
    }
}

/// Collects parsed frames into a store.
private actor BlockCollector: PublicRepositoryCARFrameSink {
    private let store: InMemoryRepositoryBlockStore

    init(store: InMemoryRepositoryBlockStore) {
        self.store = store
    }

    func receiveHeader(rootCID _: CID, receivedByteCount _: Int) async throws {}

    func receiveBlock(_ block: PublicRepositoryBlock, receivedByteCount _: Int, frameCount _: Int) async throws {
        try await store.put(block)
    }
}
