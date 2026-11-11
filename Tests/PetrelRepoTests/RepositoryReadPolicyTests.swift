import Foundation
import Petrel
import PetrelCrypto
import PetrelRepo
import Testing

/// What the two read policies accept. `dataModel` enforces what the
/// specifications require of a reader; `strict` adds what a hosting service
/// enforces on write.
@Suite("Read policy: tolerant by specification, strict on request")
struct RepositoryReadPolicyTests {
    private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    private let collection = "com.example.record"
    private let signer = K256Keypair.generate()
    private var verification: RepositoryCommitVerification { .signingKey(signer.publicKey) }
    private let strict = RepositoryOptions(limits: .networkScale, policy: .strict)

    // MARK: Building archives by hand

    private func text(_ value: String) -> [UInt8] {
        let utf8 = Array(value.utf8)
        return (utf8.count < 24 ? [0x60 + UInt8(utf8.count)] : [0x78, UInt8(utf8.count)]) + utf8
    }

    /// `{"$type": type, "v": <value bytes>}` in canonical order (`v` first).
    private func recordBytes(type: String, value: [UInt8]) -> Data {
        Data([0xa2] + text("v") + value + text("$type") + text(type))
    }

    private func frame(cid: [UInt8], body: Data) -> Data {
        PublicRepositoryCAR.canonicalUnsignedVarint(UInt64(cid.count + body.count)) + Data(cid) + body
    }

    private func header(roots: [[UInt8]]) -> Data {
        var bytes: [UInt8] = [0xa2] + text("roots") + [0x80 + UInt8(roots.count)]
        for root in roots {
            bytes += [0xd8, 0x2a, 0x58, UInt8(root.count + 1), 0x00] + root
        }
        bytes += text("version") + [0x01]
        return PublicRepositoryCAR.canonicalUnsignedVarint(UInt64(bytes.count)) + Data(bytes)
    }

    /// A signed one-record repository whose record block is `record`, plus
    /// the pieces needed to assemble variations of its archive.
    private func repository(
        record: Data, leafCID: CID? = nil, key: String = "self"
    ) async throws -> (commit: PublicRepositoryBlock, node: PublicRepositoryBlock, record: PublicRepositoryBlock) {
        let recordBlock = PublicRepositoryBlock(cid: CID.fromDAGCBOR(record), bytes: record)
        let path = try PublicRepositoryPath(collection: collection, recordKey: key)
        var node: PublicRepositoryBlock?
        _ = try await BulkMST.build(
            [.init(path: path, recordCID: leafCID ?? recordBlock.cid)],
            options: .dataModel
        ) { node = $0 }
        let root = try #require(node)
        let commit = try await PublicRepositoryCommitCodec.prepare(
            did: did, revision: "3jzfcijpj2z2a", dataCID: root.cid, signer: signer
        )
        return (.init(cid: commit.commitCID, bytes: commit.signedCommitBytes), root, recordBlock)
    }

    private func archive(_ blocks: [PublicRepositoryBlock], extraRoots: [[UInt8]] = [], extraFrames: [Data] = []) -> Data {
        var car = header(roots: [Array(blocks[0].cid.bytes)] + extraRoots)
        for block in blocks {
            car += frame(cid: Array(block.cid.bytes), body: block.bytes)
        }
        for extra in extraFrames { car += extra }
        return car
    }

    // MARK: Record content

    @Test("a 64-bit integer in a record: read by default, refused when strict")
    func wideInteger() async throws {
        // 2^60
        let parts = try await repository(
            record: recordBytes(type: collection, value: [0x1b, 0x10, 0, 0, 0, 0, 0, 0, 0])
        )
        let car = archive([parts.commit, parts.node, parts.record])
        let opened = try await Repository.open(car: car, verification: verification)
        let record = try #require(try await opened.record(collection: collection, recordKey: "self"))
        #expect(try record.record().fields["v"] == .integer(1 << 60))
        // Bytes are retained exactly, so a re-export is identical.
        #expect(try await opened.exportCAR(order: .stored) == car)

        await #expect(throws: RepositoryError.invalidRecord(path: "\(collection)/self")) {
            try await Repository.open(car: car, verification: self.verification, options: self.strict)
        }
    }

    @Test("a non-blessed link inside a record does not sink the repository")
    func nonBlessedLinkInRecord() async throws {
        let digest = [UInt8](repeating: 3, count: 64)
        let sha512: [UInt8] = [0x01, 0x71, 0x13, 0x40] + digest
        let parts = try await repository(
            record: recordBytes(type: collection, value: [0xd8, 0x2a, 0x58, UInt8(sha512.count + 1), 0x00] + sha512)
        )
        let car = archive([parts.commit, parts.node, parts.record])
        let opened = try await Repository.open(car: car, verification: verification)
        #expect(opened.statistics?.recordCount == 1)
        let record = try #require(try await opened.record(collection: collection, recordKey: "self"))
        guard case let .link(cid)? = try record.record().fields["v"] else {
            Issue.record("expected a link")
            return
        }
        #expect(Array(cid.bytes) == sha512)
        #expect(try await opened.exportCAR(order: .stored) == car)

        await #expect(throws: RepositoryError.invalidRecord(path: "\(collection)/self")) {
            try await Repository.open(car: car, verification: self.verification, options: self.strict)
        }
    }

    @Test("a link in a format the CID type cannot hold: the repository imports and exports; only that value is unreadable")
    func unrepresentableLinkInRecord() async throws {
        // CIDv1 with a two-byte codec varint.
        let exotic: [UInt8] = [0x01, 0xa9, 0x02, 0x12, 0x20] + [UInt8](repeating: 4, count: 32)
        let parts = try await repository(
            record: recordBytes(type: collection, value: [0xd8, 0x2a, 0x58, UInt8(exotic.count + 1), 0x00] + exotic)
        )
        let car = archive([parts.commit, parts.node, parts.record])
        let opened = try await Repository.open(car: car, verification: verification)
        #expect(opened.statistics?.recordCount == 1)
        let record = try #require(try await opened.record(collection: collection, recordKey: "self"))
        #expect(record.bytes == parts.record.bytes)
        #expect(throws: RepositoryMSTValidationError.unsupportedRecordLink) { try record.value() }
        #expect(try await opened.exportCAR(order: .stored) == car)
        #expect(try await opened.exportCAR(order: .streamable).count == car.count)
    }

    @Test("$type: must be a non-empty string always; must equal the collection only when strict")
    func recordType() async throws {
        let other = try await repository(record: recordBytes(type: "com.example.other", value: [0x01]))
        let otherCAR = archive([other.commit, other.node, other.record])
        let opened = try await Repository.open(car: otherCAR, verification: verification)
        #expect(try await opened.record(collection: collection, recordKey: "self")?.record().type == "com.example.other")
        await #expect(throws: RepositoryError.invalidRecord(path: "\(collection)/self")) {
            try await Repository.open(car: otherCAR, verification: self.verification, options: self.strict)
        }

        // No `$type`, an empty one, and one that is not a string are never
        // records.
        let invalid: [Data] = [
            Data([0xa1] + text("v") + [0x01]),
            recordBytes(type: "", value: [0x01]),
            Data([0xa2] + text("v") + [0x01] + text("$type") + [0x01]),
            Data([0x81, 0x01]),
        ]
        for record in invalid {
            let parts = try await repository(record: record)
            let car = archive([parts.commit, parts.node, parts.record])
            await #expect(throws: RepositoryError.invalidRecord(path: "\(collection)/self")) {
                try await Repository.open(car: car, verification: self.verification)
            }
        }
    }

    // MARK: Leaf links

    @Test("a leaf that links its record through a non-blessed CID is retained, listed, and re-exported")
    func nonBlessedLeafLink() async throws {
        let foreign = CID(
            codec: .dagCBOR,
            multihash: Multihash(algorithm: Multihash.sha512Code, length: 64, digest: Data(repeating: 5, count: 64))
        )
        let parts = try await repository(record: recordBytes(type: collection, value: [0x01]), leafCID: foreign)
        // The record block cannot be included: nothing can hash to that CID
        // here. The archive is the commit and the tree.
        let car = archive([parts.commit, parts.node])
        let opened = try await Repository.open(car: car, verification: verification)
        #expect(opened.statistics?.recordCount == 1)
        #expect(opened.statistics?.unverifiableRecordCount == 1)
        #expect(try await opened.recordCID(collection: collection, recordKey: "self") == foreign)
        var listed: [CID] = []
        try await opened.forEachRecordReference { _, cid in listed.append(cid) }
        #expect(listed == [foreign])
        await #expect(throws: RepositoryError.unsupportedRecordCID(path: "\(collection)/self")) {
            try await opened.record(collection: self.collection, recordKey: "self")
        }
        #expect(try await opened.exportCAR(order: .stored) == car)
        // The exact link survives a write elsewhere in the tree.
        let written = try await opened.commit(
            [.create(
                path: try PublicRepositoryPath(collection: collection, recordKey: "other"),
                record: .sample(collection, text: "x")
            )],
            signer: signer
        )
        #expect(try await written.repository.recordCID(collection: collection, recordKey: "self") == foreign)

        await #expect(throws: RepositoryError.tree(.invalidCIDLink)) {
            try await Repository.open(car: car, verification: self.verification, options: self.strict)
        }
    }

    @Test("links between MST nodes and to the tree root are always required to be blessed")
    func structuralLinksStayStrict() async throws {
        let parts = try await repository(record: recordBytes(type: collection, value: [0x01]))
        // A node whose left-subtree link is a raw-codec CID.
        let raw = CID.fromBlob(Data("x".utf8))
        let node = Data([0xa2, 0x61, 0x65, 0x80, 0x61, 0x6c, 0xd8, 0x2a, 0x58, 0x25, 0x00] + Array(raw.bytes))
        for options in [RepositoryMSTOptions.strict, .dataModel] {
            #expect(throws: RepositoryMSTValidationError.invalidCIDLink) {
                try RepositoryMSTCodec.decode(node, options: options)
            }
        }
        // A commit whose `data` is not blessed DAG-CBOR is not a commit.
        #expect(throws: PublicRepositoryCommitError.invalidDataCID) {
            try PublicRepositoryCommitDescriptor(did: did, revision: "3jzfcijpj2z2a", dataCID: raw)
        }
        // And an archive whose first root is not a blessed commit CID fails
        // under either policy.
        var car = header(roots: [Array(raw.bytes)])
        car += frame(cid: Array(parts.commit.cid.bytes), body: parts.commit.bytes)
        for options in [RepositoryOptions.default, strict] {
            await #expect(throws: RepositoryError.car(.invalidRootCID)) {
                try await Repository.open(car: car, verification: self.verification, options: options)
            }
        }
    }

    // MARK: CAR framing

    @Test("additional roots: reported and ignored by default, refused when strict")
    func additionalRoots() async throws {
        let parts = try await repository(record: recordBytes(type: collection, value: [0x01]))
        let blocks = [parts.commit, parts.node, parts.record]
        let second = CID.fromDAGCBOR(Data("second root".utf8))
        let car = archive(blocks, extraRoots: [Array(second.bytes), Array(CID.fromBlob(Data("b".utf8)).bytes)])

        let opened = try await Repository.open(car: car, verification: verification)
        #expect(opened.commit.cid == parts.commit.cid)
        #expect(opened.statistics?.recordCount == 1)
        let parsed = try await PublicRepositoryCAR.parseIncrementally(
            from: DataCARByteSource(car), to: DiscardingSink(), limits: .networkScale, policy: .dataModel
        )
        #expect(parsed.additionalRootCIDs == [second, CID.fromBlob(Data("b".utf8))])

        await #expect(throws: RepositoryError.car(.invalidRootCount)) {
            try await Repository.open(car: car, verification: self.verification, options: self.strict)
        }
        // No roots at all is malformed under either policy.
        var rootless = header(roots: [])
        rootless += frame(cid: Array(parts.commit.cid.bytes), body: parts.commit.bytes)
        for options in [RepositoryOptions.default, strict] {
            await #expect(throws: RepositoryError.car(.invalidRootCount)) {
                try await Repository.open(car: rootless, verification: self.verification, options: options)
            }
        }
    }

    @Test("blocks that are not repository blocks: skipped by default, refused when strict")
    func foreignBlocks() async throws {
        let parts = try await repository(record: recordBytes(type: collection, value: [0x01]))
        let blocks = [parts.commit, parts.node, parts.record]
        let blob = Data("a blob that happens to be in the archive".utf8)
        let foreign = [
            // A raw (blob) block.
            frame(cid: Array(CID.fromBlob(blob).bytes), body: blob),
            // A dag-pb block under SHA-512.
            frame(cid: [0x01, 0x70, 0x13, 0x40] + [UInt8](repeating: 8, count: 64), body: Data([0x0a, 0x00])),
            // A CIDv0 block.
            frame(cid: [0x12, 0x20] + [UInt8](repeating: 8, count: 32), body: Data([0x0a, 0x00])),
            // An unlinked DAG-CBOR block (ignored at the tree level).
            frame(cid: Array(CID.fromDAGCBOR(Data([0xa0])).bytes), body: Data([0xa0])),
        ]
        let car = archive(blocks, extraFrames: foreign)
        let opened = try await Repository.open(car: car, verification: verification)
        #expect(opened.statistics?.recordCount == 1)
        let parsed = try await PublicRepositoryCAR.parseIncrementally(
            from: DataCARByteSource(car), to: DiscardingSink(), limits: .networkScale, policy: .dataModel
        )
        #expect(parsed.frameCount == 4)
        #expect(parsed.ignoredFrameCount == 3)
        // The canonical export drops everything unreachable.
        let reexported = try await opened.exportCAR(order: .streamable)
        #expect(reexported == archive(blocks))

        await #expect(throws: RepositoryError.car(.invalidBlockCID)) {
            try await Repository.open(car: car, verification: self.verification, options: self.strict)
        }

        // A frame that does not begin with a CID at all is malformed under
        // either policy, as is a repository block with the wrong bytes.
        let garbage = archive(blocks, extraFrames: [frame(cid: [0xff, 0xff, 0xff, 0xff], body: Data([0x00]))])
        var mismatched = archive([parts.commit, parts.node])
        mismatched += frame(cid: Array(parts.record.cid.bytes), body: parts.record.bytes + Data([0x00]))
        await #expect(throws: RepositoryError.car(.invalidBlockCID)) {
            try await Repository.open(car: garbage, verification: self.verification)
        }
        await #expect(throws: RepositoryError.car(.blockBodyLimitExceeded)) {
            try await Repository.open(car: garbage, verification: self.verification, options: self.strict)
        }
        for options in [RepositoryOptions.default, strict] {
            await #expect(throws: RepositoryError.car(.blockCIDMismatch)) {
                try await Repository.open(car: mismatched, verification: self.verification, options: options)
            }
        }
    }

    @Test("duplicate and reordered blocks are accepted; a missing one is not")
    func orderAndDuplicates() async throws {
        let parts = try await repository(record: recordBytes(type: collection, value: [0x01]))
        // Records first, commit last, the tree node twice.
        var car = header(roots: [Array(parts.commit.cid.bytes)])
        for block in [parts.record, parts.node, parts.node, parts.commit, parts.record] {
            car += frame(cid: Array(block.cid.bytes), body: block.bytes)
        }
        for options in [RepositoryOptions.default, strict] {
            let opened = try await Repository.open(car: car, verification: verification, options: options)
            #expect(opened.statistics?.recordCount == 1)
            #expect(try await opened.store.blockCount() == 3)
        }
        await #expect(throws: RepositoryError.missingRecordBlock(path: "\(collection)/self")) {
            try await Repository.open(
                car: self.archive([parts.commit, parts.node]), verification: self.verification
            )
        }
        await #expect(throws: RepositoryError.tree(.missingBlock)) {
            try await Repository.open(
                car: self.archive([parts.commit, parts.record]), verification: self.verification
            )
        }
        await #expect(throws: RepositoryError.missingCommit) {
            try await Repository.open(
                car: self.header(roots: [Array(parts.commit.cid.bytes)])
                    + self.frame(cid: Array(parts.node.cid.bytes), body: parts.node.bytes),
                verification: self.verification
            )
        }
    }
}

private actor DiscardingSink: PublicRepositoryCARFrameSink {
    func receiveHeader(rootCID _: CID, receivedByteCount _: Int) async throws {}
    func receiveBlock(_: PublicRepositoryBlock, receivedByteCount _: Int, frameCount _: Int) async throws {}
}
