import Foundation
import Petrel
@testable import PetrelRepo
import XCTest

final class PublicRepositoryDomainTests: XCTestCase {
    private let collection = "app.bsky.feed.post"

    func testPetrelRecordConversionAddsAndBindsCollectionTypeWithoutJSON() throws {
        let value: ATProtocolValueContainer = .object([
            "text": .string("hello"),
            "count": .number(3),
            "enabled": .bool(true),
            "nested": .object(["value": .null]),
            "items": .array([.string("a"), .number(2)]),
        ])
        let record = try PublicRepositoryRecordCodec.publicRecord(
            from: value,
            collection: collection
        )
        XCTAssertEqual(record.fields["$type"], .string(collection))
        XCTAssertEqual(record.fields["text"], .string("hello"))
        XCTAssertEqual(record.fields["count"], .integer(3))
        XCTAssertEqual(record.fields["enabled"], .bool(true))
    }

    func testPetrelRecordConversionRejectsTypedUnknownAndUnsafeValues() {
        for value in [
            ATProtocolValueContainer.unknownType("app.example.unknown", .object([:])),
            ATProtocolValueContainer.decodeError("bad"),
            ATProtocolValueContainer.bigNumber("9007199254740992"),
        ] {
            XCTAssertThrowsError(try PublicRepositoryRecordCodec.publicRecord(
                from: value,
                collection: collection
            ))
        }
        XCTAssertThrowsError(try PublicRepositoryRecordCodec.publicRecord(
            from: .object(["$type": .string("app.other.record")]),
            collection: collection
        ))
        XCTAssertThrowsError(try PublicRepositoryRecordCodec.publicRecord(
            from: .object([
                "$type": .string("blob"),
                "ref": .object(["$link": .string("bafybeigdyrzt4q5x7wq6q3m3u4n4v6m4y4f5xq4z4q4w4q4w4q4w4q4w4q")]),
            ]),
            collection: collection
        ))
    }

    func testPetrelModernTypedBlobIsAcceptedAndRetainsRawReference() throws {
        let cid = CID.fromBlob(Data("typed-blob".utf8))
        let record = try PublicRepositoryRecordCodec.publicRecord(
            from: .object([
                "embed": .unknownType(
                    "blob",
                    .object([
                        "ref": .link(ATProtoLink(cid: cid)),
                        "mimeType": .string("image/png"),
                        "size": .number(10),
                    ])
                ),
            ]),
            collection: collection
        )
        XCTAssertEqual(record.fields["$type"], PublicRecordValue.string(collection))
        XCTAssertEqual(
            PublicRepositoryRecordCodec.publicBlobCIDs(in: record).map(\.string),
            [cid.string]
        )
        let path = try PublicRepositoryPath(collection: collection, recordKey: "typed-blob")
        XCTAssertNoThrow(try PublicRepositoryRecordCodec.prepare(record, for: path))
    }

    func testPetrelJSONDecoderPreservesModernTypedBlobForRepositoryCodec() throws {
        let cid = CID.fromBlob(Data("decoded-typed-blob".utf8))
        let json = try JSONSerialization.data(withJSONObject: [
            "embed": [
                "$type": "blob",
                "ref": ["$link": cid.string],
                "mimeType": "image/png",
                "size": 18,
            ],
        ])
        let value = try JSONDecoder().decode(ATProtocolValueContainer.self, from: json)
        guard case let .object(fields) = value,
              case let .unknownType(type, payload)? = fields["embed"] else {
            return XCTFail("Petrel must preserve an unregistered typed blob as unknownType")
        }
        XCTAssertEqual(type, "blob")
        guard case let .object(payloadFields) = payload,
              case let .link(link)? = payloadFields["ref"] else {
            return XCTFail("Petrel must preserve the blob ref as a CID link")
        }
        XCTAssertEqual(link.cid, cid)

        let record = try PublicRepositoryRecordCodec.publicRecord(
            from: value,
            collection: collection
        )
        XCTAssertEqual(
            PublicRepositoryRecordCodec.publicBlobCIDs(in: record).map(\.string),
            [cid.string]
        )
    }

    func testTypedBlobRejectsWrongShapeAndMIME() throws {
        let cid = CID.fromBlob(Data("typed-blob-invalid".utf8))
        let base: [String: ATProtocolValueContainer] = [
            "$type": .string("blob"),
            "ref": .object(["$link": .string(cid.string)]),
            "mimeType": .string("image/png"),
            "size": .number(10),
        ]
        for (key, value) in [
            ("extra", ATProtocolValueContainer.bool(true)),
            ("mimeType", .string("not a mime type")),
            ("size", .number(-1)),
        ] {
            var fields = base
            fields[key] = value
            XCTAssertThrowsError(try PublicRepositoryRecordCodec.publicRecord(
                from: .object(fields), collection: collection
            ))
        }
    }

    func testPathAcceptsPinnedBoundarySyntax() throws {
        let longCollection = String(repeating: "a", count: 63)
            + "." + Array(repeating: String(repeating: "b", count: 63), count: 3).joined(separator: ".")
            + "." + String(repeating: "c", count: 61)
        XCTAssertEqual(longCollection.utf8.count, 317)
        let path = try PublicRepositoryPath(
            collection: longCollection,
            recordKey: String(repeating: "z", count: 512)
        )
        XCTAssertEqual(path.mstKey, "\(longCollection)/\(String(repeating: "z", count: 512))")
        XCTAssertLessThanOrEqual(path.mstKey.utf8.count, 1_024)
    }

    func testPathRejectsHostileNSIDs() {
        for invalid in [
            "com.example",
            "1com.example.record",
            "com..example.record",
            "com.-example.record",
            "com.example-.record",
            "com.example.some-name",
            "com.exa_mple.record",
            "com.example." + String(repeating: "x", count: 64),
        ] {
            XCTAssertThrowsError(try PublicRepositoryPath(collection: invalid, recordKey: "ok")) {
                XCTAssertEqual($0 as? PublicRepositoryDomainError, .invalidCollection)
            }
        }
    }

    func testPathRejectsHostileRecordKeysAndCountsCompleteKeyBytes() throws {
        for invalid in ["", ".", "..", "bad/key", "bad%key", "space key", String(repeating: "x", count: 513)] {
            XCTAssertThrowsError(try PublicRepositoryPath(collection: collection, recordKey: invalid)) {
                XCTAssertEqual($0 as? PublicRepositoryDomainError, .invalidRecordKey)
            }
        }

        let maximumCollection = String(repeating: "a", count: 63)
            + "." + Array(repeating: String(repeating: "b", count: 63), count: 3).joined(separator: ".")
            + "." + String(repeating: "c", count: 61)
        let boundary = try PublicRepositoryPath(
            collection: maximumCollection,
            recordKey: String(repeating: "r", count: 512)
        )
        XCTAssertEqual(boundary.mstKey.utf8.count, 830)
    }

    func testTIDValidatesExactAlphabetLeadingRangeAndLexicalOrder() throws {
        let first = try PublicRepositoryTID("2222222222222")
        let second = try PublicRepositoryTID("2222222222223")
        XCTAssertLessThan(first, second)
        XCTAssertEqual(try PublicRepositoryTID("jzzzzzzzzzzzz").description, "jzzzzzzzzzzzz")

        for invalid in [
            "222222222222",
            "22222222222222",
            "k222222222222",
            "1222222222222",
            "2222222222220",
            "222222222222I",
        ] {
            XCTAssertThrowsError(try PublicRepositoryTID(invalid)) {
                XCTAssertEqual($0 as? PublicRepositoryDomainError, .invalidRevision)
            }
        }
    }

    func testRepositoryCIDBoundaryAcceptsOnlyBlessedTuple() throws {
        let bytes = Data([0xa1, 0x61, 0x78, 0x01])
        let cid = CID.fromDAGCBOR(bytes)
        XCTAssertNoThrow(try PublicRepositoryCID.validate(cid))
        XCTAssertNoThrow(try PublicRepositoryCID.validate(cid, blockBytes: bytes))

        let raw = CID.fromBlob(bytes)
        XCTAssertThrowsError(try PublicRepositoryCID.validate(raw)) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .unsupportedCID)
        }
        let wrongHash = CID(
            codec: .dagCBOR,
            multihash: Multihash(algorithm: Multihash.sha1Code, length: 20, digest: Data(repeating: 0, count: 20))
        )
        XCTAssertThrowsError(try PublicRepositoryCID.validate(wrongHash)) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .unsupportedCID)
        }
        XCTAssertThrowsError(try PublicRepositoryCID.validate(cid, blockBytes: Data([0]))) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .blockCIDMismatch)
        }
    }

    func testRecordCodecRequiresMatchingTopLevelType() throws {
        let path = try PublicRepositoryPath(collection: collection, recordKey: "3k2")
        let valid: PublicRecord = [
            "$type": .string(collection),
            "text": .string("hello"),
            "langs": .array([.string("en")]),
            "replyCount": .integer(0),
            "facets": .null,
            "enabled": .bool(true),
        ]
        let prepared = try PublicRepositoryRecordCodec.prepare(valid, for: path)
        XCTAssertEqual(prepared.cid, CID.fromDAGCBOR(prepared.bytes))
        XCTAssertEqual(prepared.bytes, try PublicRepositoryRecordCodec.prepare(valid, for: path).bytes)

        for invalid in [
            PublicRecord(["text": .string("missing")]),
            PublicRecord(["$type": .integer(1)]),
            PublicRecord(["$type": .string("app.bsky.feed.like")]),
        ] {
            XCTAssertThrowsError(try PublicRepositoryRecordCodec.prepare(invalid, for: path)) {
                XCTAssertEqual($0 as? PublicRepositoryDomainError, .invalidRecordType)
            }
        }
    }

    func testRecordEncodingIsCanonicalIndependentOfObjectInsertionOrder() throws {
        let path = try PublicRepositoryPath(collection: collection, recordKey: "canonical")
        let a = PublicRecord([
            "zz": .integer(1),
            "$type": .string(collection),
            "a": .string("short"),
        ])
        let b = PublicRecord([
            "a": .string("short"),
            "$type": .string(collection),
            "zz": .integer(1),
        ])
        XCTAssertEqual(
            try PublicRepositoryRecordCodec.prepare(a, for: path),
            try PublicRepositoryRecordCodec.prepare(b, for: path)
        )
    }

    func testRecordEncodingMatchesIndependentCanonicalWireVector() throws {
        let path = try PublicRepositoryPath(collection: collection, recordKey: "vector")
        let prepared = try PublicRepositoryRecordCodec.prepare(
            PublicRecord([
                "$type": .string(collection),
                "text": .string("hello"),
            ]),
            for: path
        )
        XCTAssertEqual(
            prepared.bytes.map { String(format: "%02x", $0) }.joined(),
            "a264746578746568656c6c6f652474797065726170702e62736b792e666565642e706f7374"
        )
        XCTAssertEqual(prepared.cid.string, "bafyreicl5wcgzaefpu23bimapxa4lj7kbx7dczrtbmh6haqztpqkjk6uza")
    }

    func testRecordDictionaryLiteralDuplicateKeysUseLastValueWithoutTrapping() throws {
        let record: PublicRecord = [
            "$type": .string("wrong.collection"),
            "$type": .string(collection),
            "text": .string("first"),
            "text": .string("last"),
        ]
        XCTAssertEqual(record.fields["$type"], .string(collection))
        XCTAssertEqual(record.fields["text"], .string("last"))
        let path = try PublicRepositoryPath(collection: collection, recordKey: "duplicate-literal")
        XCTAssertNoThrow(try PublicRepositoryRecordCodec.prepare(record, for: path))
    }

    func testRecordCodecEnforcesDepthSizeAndEmbeddedLinkValidity() throws {
        let path = try PublicRepositoryPath(collection: collection, recordKey: "limits")
        let tinyLimits = try PublicRepositoryLimits(
            maximumRecordBlockBytes: 32,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: 10,
            maximumMSTNodes: 5,
            maximumMSTEntriesPerNode: 5,
            maximumCBORNestingDepth: 2
        )
        let tooLarge = PublicRecord([
            "$type": .string(collection),
            "text": .string(String(repeating: "x", count: 100)),
        ])
        XCTAssertThrowsError(try PublicRepositoryRecordCodec.prepare(tooLarge, for: path, limits: tinyLimits)) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .recordTooLarge)
        }

        let tooDeep = PublicRecord([
            "$type": .string(collection),
            "nested": .array([.object(["more": .array([.null])])]),
        ])
        XCTAssertThrowsError(try PublicRepositoryRecordCodec.prepare(tooDeep, for: path, limits: tinyLimits)) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .recordNestingTooDeep)
        }

        let invalidLink = CID(
            codec: .dagPB,
            multihash: Multihash.sha256(Data([1]))
        )
        let linked = PublicRecord([
            "$type": .string(collection),
            "subject": .link(invalidLink),
        ])
        XCTAssertThrowsError(try PublicRepositoryRecordCodec.prepare(linked, for: path)) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .invalidRecordLink)
        }

        let wrongHashLength = CID(
            codec: .raw,
            multihash: Multihash(
                algorithm: Multihash.sha256Code,
                length: 31,
                digest: Data(repeating: 0, count: 31)
            )
        )
        XCTAssertThrowsError(try PublicRepositoryRecordCodec.prepare(
            PublicRecord(["$type": .string(collection), "blob": .link(wrongHashLength)]),
            for: path
        )) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .invalidRecordLink)
        }

        let validRawLink = CID.fromBlob(Data("blob".utf8))
        XCTAssertNoThrow(try PublicRepositoryRecordCodec.prepare(
            PublicRecord(["$type": .string(collection), "blob": .link(validRawLink)]),
            for: path
        ))
    }

    func testPublicBlobCIDProjectionOnlyReturnsDeduplicatedRawLinks() throws {
        let raw = CID.fromBlob(Data("blob".utf8))
        let dagCBOR = CID.fromDAGCBOR(Data([0xa0]))
        let record = PublicRecord([
            "$type": .string(collection),
            "one": .link(raw),
            "nested": .object([
                "same": .link(raw),
                "record": .link(dagCBOR),
            ]),
            "many": .array([.link(raw), .string("not-a-link")]),
        ])

        XCTAssertEqual(
            PublicRepositoryRecordCodec.publicBlobCIDs(in: record).map(\.string),
            [raw.string]
        )
    }

    func testRecordCodecEnforcesInclusiveSignedSafeIntegerRange() throws {
        let path = try PublicRepositoryPath(collection: collection, recordKey: "integers")
        let boundaries = PublicRecord([
            "$type": .string(collection),
            "minimum": .integer(PublicRepositoryRecordCodec.minimumSafeInteger),
            "maximum": .integer(PublicRepositoryRecordCodec.maximumSafeInteger),
        ])
        XCTAssertNoThrow(try PublicRepositoryRecordCodec.prepare(boundaries, for: path))

        for invalid in [
            PublicRepositoryRecordCodec.minimumSafeInteger - 1,
            PublicRepositoryRecordCodec.maximumSafeInteger + 1,
            Int.min,
            Int.max,
        ] {
            XCTAssertThrowsError(try PublicRepositoryRecordCodec.prepare(
                PublicRecord(["$type": .string(collection), "value": .integer(invalid)]),
                for: path
            )) {
                XCTAssertEqual($0 as? PublicRepositoryDomainError, .invalidRecordInteger)
            }
        }
    }

    func testBlockMapRejectsMismatchAndConflictingDuplicates() throws {
        let bytes = Data([0xa0])
        let cid = CID.fromDAGCBOR(bytes)
        let map = try PublicRepositoryBlockMap(blocks: [
            .init(cid: cid, bytes: bytes),
            .init(cid: cid, bytes: bytes),
        ])
        XCTAssertEqual(map.count, 1)
        XCTAssertEqual(map.relevantByteCount, 1)
        XCTAssertEqual(map.block(for: cid), bytes)

        XCTAssertThrowsError(try PublicRepositoryBlockMap(blocks: [
            .init(cid: cid, bytes: bytes),
            .init(cid: cid, bytes: Data([0xa1])),
        ])) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .duplicateBlockConflict)
        }
        XCTAssertThrowsError(try PublicRepositoryBlockMap(blocks: [
            .init(cid: cid, bytes: Data([0xa1])),
        ])) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .blockCIDMismatch)
        }
    }

    func testBlockMapUsesUniqueRelevantBytesAndCheckedBudget() throws {
        let first = Data([0xa0])
        let second = Data([0x80])
        let blocks = [
            PublicRepositoryBlock(cid: CID.fromDAGCBOR(first), bytes: first),
            PublicRepositoryBlock(cid: CID.fromDAGCBOR(second), bytes: second),
        ]
        XCTAssertThrowsError(try PublicRepositoryBlockMap(blocks: blocks, maximumRelevantBytes: 1)) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .relevantBlockBudgetExceeded)
        }
    }

    func testBlockMapFreezesPinnedOrStricterBudgetWithoutWidening() throws {
        let empty = try PublicRepositoryBlockMap(blocks: [], maximumRelevantBytes: 0)
        XCTAssertEqual(empty.maximumRelevantBytes, 0)
        let oneByte = Data([0xa0])
        let oneBlock = PublicRepositoryBlock(cid: CID.fromDAGCBOR(oneByte), bytes: oneByte)
        XCTAssertThrowsError(try empty.adding([oneBlock])) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .relevantBlockBudgetExceeded)
        }

        let pinnedBytes = Data(repeating: 0, count: PublicRepositoryLimits.pinnedMaximumRelevantBlockBytes)
        let pinned = try PublicRepositoryBlockMap(
            blocks: [.init(cid: CID.fromDAGCBOR(pinnedBytes), bytes: pinnedBytes)],
            maximumRelevantBytes: PublicRepositoryLimits.pinnedMaximumRelevantBlockBytes
        )
        XCTAssertEqual(pinned.relevantByteCount, PublicRepositoryLimits.pinnedMaximumRelevantBlockBytes)
        XCTAssertEqual(pinned.maximumRelevantBytes, PublicRepositoryLimits.pinnedMaximumRelevantBlockBytes)

        XCTAssertThrowsError(try PublicRepositoryBlockMap(
            blocks: [],
            maximumRelevantBytes: PublicRepositoryLimits.pinnedMaximumRelevantBlockBytes + 1
        )) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .relevantBlockBudgetExceeded)
        }

        let strict = try PublicRepositoryBlockMap(blocks: [oneBlock], maximumRelevantBytes: 1)
        let secondBytes = Data([0x80])
        let secondBlock = PublicRepositoryBlock(cid: CID.fromDAGCBOR(secondBytes), bytes: secondBytes)
        XCTAssertThrowsError(try strict.adding([secondBlock])) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .relevantBlockBudgetExceeded)
        }
        XCTAssertEqual(strict.maximumRelevantBytes, 1)
        XCTAssertEqual(strict.relevantByteCount, 1)
    }

    func testBatchPreflightRejectsEmptyTooManyDuplicateAndMalformedCAS() throws {
        let path = try PublicRepositoryPath(collection: collection, recordKey: "a")
        let record = PublicRecord(["$type": .string(collection)])
        XCTAssertThrowsError(try PublicRepositoryWriteBatch(writes: [])) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .emptyWriteBatch)
        }
        XCTAssertThrowsError(try PublicRepositoryWriteBatch(writes: [
            .create(path: path, record: record),
            .delete(path: path, expectedRecordCID: nil),
        ])) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .duplicateWritePath)
        }
        XCTAssertThrowsError(try PublicRepositoryWriteBatch(
            writes: Array(repeating: .create(path: path, record: record), count: 201)
        )) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .tooManyWrites)
        }

        let unsupported = CID.fromBlob(Data([1]))
        XCTAssertThrowsError(try PublicRepositoryWriteBatch(
            writes: [.update(path: path, record: record, expectedRecordCID: unsupported)]
        )) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .unsupportedCID)
        }
        XCTAssertThrowsError(try PublicRepositoryWriteBatch(
            writes: [.create(path: path, record: record)],
            expectedCommitCID: unsupported
        )) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .unsupportedCID)
        }
    }

    func testStateValidatesDIDTIDAndRepositoryCIDs() throws {
        let cid = CID.fromDAGCBOR(Data([0xa0]))
        XCTAssertNoThrow(try PublicRepositoryState(
            did: "did:plc:abcdefghijklmnopqrstuvwxyz",
            revision: "2222222222222",
            commitCID: cid,
            dataCID: cid
        ))
        XCTAssertThrowsError(try PublicRepositoryState(
            did: "not a did",
            revision: "2222222222222",
            commitCID: cid,
            dataCID: cid
        )) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .invalidDID)
        }
    }

    // MARK: - Repository-wide record ceiling

    /// The node cap and the entries-per-node cap bound one block each; neither
    /// bounds the aggregate leaf set a validly signed repository can present.
    /// `reachableBytes` already caps the whole walk at the CAR budget, so this
    /// was never an unbounded allocation — but without a leaf ceiling an
    /// import can still produce a repository whose record count the public
    /// read path refuses, which is a repository nobody can read.
    func testValidationRefusesMoreLeavesThanTheRepositoryRecordCeiling() async throws {
        let tree = try makeFlatTree(recordCount: 3)

        let ceilingOfTwo = try limits(maximumRepositoryRecords: 2)
        await assertRecordLimitExceeded {
            _ = try await RepositoryMSTValidation.validate(
                rootCID: tree.rootCID, blocks: tree.source, limits: ceilingOfTwo
            )
        }
        await assertRecordLimitExceeded {
            _ = try await RepositoryMSTValidation.validateProjection(
                rootCID: tree.rootCID,
                blocks: tree.source,
                projection: DiscardingProjectionSink(),
                limits: ceilingOfTwo
            )
        }

        let ceilingOfThree = try limits(maximumRepositoryRecords: 3)
        let validated = try await RepositoryMSTValidation.validate(
            rootCID: tree.rootCID, blocks: tree.source, limits: ceilingOfThree
        )
        XCTAssertEqual(validated.leaves.count, 3, "exactly at the ceiling still validates")
        let projected = try await RepositoryMSTValidation.validateProjection(
            rootCID: tree.rootCID,
            blocks: tree.source,
            projection: DiscardingProjectionSink(),
            limits: ceilingOfThree
        )
        XCTAssertEqual(projected.recordCount, 3)
    }

    func testStandardPolicyCarriesTheDocumentedRecordCeiling() throws {
        XCTAssertEqual(PublicRepositoryLimits.standard.maximumRepositoryRecords, 100_000)
        XCTAssertThrowsError(try limits(maximumRepositoryRecords: 0)) {
            XCTAssertEqual(
                $0 as? PublicRepositoryLimitError,
                .maximumRepositoryRecordsOutOfRange
            )
        }
    }

    // MARK: - Codec depth accounting

    /// `prepare` advances depth through objects; the conversion phase feeding
    /// it did not, so the package-public conversion API accepted documents its
    /// own encoder would refuse. Both halves must agree on 64 accepted / 65
    /// refused — the same bound `RepositoryRecordBlockValidator` applies to
    /// every stored block, so nothing already durable can be refused by this.
    func testRecordConversionAndEncodingAgreeOnObjectNestingDepth() throws {
        let path = try PublicRepositoryPath(collection: collection, recordKey: "nesting")

        let atCeiling = try PublicRepositoryRecordCodec.publicRecord(
            from: Self.nestedObjectContainer(levels: 64),
            collection: collection
        )
        XCTAssertNoThrow(try PublicRepositoryRecordCodec.prepare(atCeiling, for: path))

        XCTAssertThrowsError(try PublicRepositoryRecordCodec.publicRecord(
            from: Self.nestedObjectContainer(levels: 65),
            collection: collection
        )) {
            XCTAssertEqual($0 as? PublicRepositoryDomainError, .recordNestingTooDeep)
        }
    }

    // MARK: - Helpers

    /// `levels` counts the record object itself, matching `encodeObject`'s
    /// depth-1 entry point.
    private static func nestedObjectContainer(levels: Int) -> ATProtocolValueContainer {
        var value = ATProtocolValueContainer.object([:])
        for _ in 1 ..< levels {
            value = .object(["a": value])
        }
        return value
    }

    private func limits(maximumRepositoryRecords: Int) throws -> PublicRepositoryLimits {
        try PublicRepositoryLimits(
            maximumRecordBlockBytes: 1_000_000,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: 32,
            maximumMSTNodes: 16,
            maximumMSTEntriesPerNode: 16,
            maximumCBORNestingDepth: 64,
            maximumRepositoryRecords: maximumRepositoryRecords
        )
    }

    private func assertRecordLimitExceeded(
        _ operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("expected recordLimitExceeded", file: file, line: line)
        } catch {
            XCTAssertEqual(
                error as? RepositoryMSTValidationError,
                .recordLimitExceeded,
                file: file, line: line
            )
        }
    }

    /// A single layer-0 node holding `recordCount` leaves. Record keys are
    /// filtered to key-depth 0 so the whole repository fits in one node and the
    /// test exercises the aggregate ceiling rather than tree topology.
    private func makeFlatTree(
        recordCount: Int
    ) throws -> (rootCID: CID, source: DomainTestBlockSource) {
        var leaves: [RepositoryMSTLeaf] = []
        var storage: [CID: Data] = [:]
        var candidate = 0
        while leaves.count < recordCount {
            defer { candidate += 1 }
            let path = try PublicRepositoryPath(
                collection: collection,
                recordKey: String(format: "leaf%06d", candidate)
            )
            guard RepositoryMSTCodec.keyDepth(for: path) == 0 else { continue }
            let bytes = try PublicRepositoryRecordCodec.prepare(
                PublicRecord([
                    "$type": .string(collection),
                    "text": .string(path.recordKey),
                ]),
                for: path
            ).bytes
            let recordCID = CID.fromDAGCBOR(bytes)
            storage[recordCID] = bytes
            leaves.append(RepositoryMSTLeaf(path: path, recordCID: recordCID))
        }
        leaves.sort { $0.path.mstKey < $1.path.mstKey }
        let nodeBytes = try RepositoryMSTCodec.encode(
            try RepositoryMSTCodec.node(leaves: leaves)
        )
        let rootCID = CID.fromDAGCBOR(nodeBytes)
        storage[rootCID] = nodeBytes
        return (rootCID, DomainTestBlockSource(storage: storage))
    }
}

private struct DomainTestBlockSource: PublicRepositoryBlockSource {
    let storage: [CID: Data]

    func block(for cid: CID) async throws -> Data? { storage[cid] }
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
