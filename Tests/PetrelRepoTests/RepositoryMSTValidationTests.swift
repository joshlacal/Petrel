import Foundation
import Petrel
@testable import PetrelRepo
import XCTest

final class RepositoryMSTValidationTests: XCTestCase {
    func testDirectRecordDecoderPreservesATDataModelWithoutJSONRoundTrip() throws {
        let path = try PublicRepositoryPath(
            collection: "app.bsky.feed.post", recordKey: "direct"
        )
        let linkedCID = CID.fromDAGCBOR(Data("linked".utf8))
        let bytesValue = Data([0x00, 0x7f, 0xff])
        let prepared = try PublicRepositoryRecordCodec.prepare(
            [
                "$type": .string(path.collection),
                "minimum": .integer(PublicRepositoryRecordCodec.minimumSafeInteger),
                "maximum": .integer(PublicRepositoryRecordCodec.maximumSafeInteger),
                "bytes": .bytes(bytesValue),
                "link": .link(linkedCID),
                "nested": .object([
                    "array": .array([.bool(true), .null, .integer(-1)]),
                ]),
            ],
            for: path
        )

        guard case let .object(value) =
                try RepositoryMSTValidation.decodeRecordBlock(
                    prepared.bytes, for: path
                ) else {
            return XCTFail("expected direct object")
        }
        XCTAssertEqual(value["minimum"], .number(
            PublicRepositoryRecordCodec.minimumSafeInteger
        ))
        XCTAssertEqual(value["maximum"], .number(
            PublicRepositoryRecordCodec.maximumSafeInteger
        ))
        guard case let .bytes(decodedBytes)? = value["bytes"] else {
            return XCTFail("expected bytes")
        }
        XCTAssertEqual(decodedBytes.data, bytesValue)
        guard case let .link(decodedLink)? = value["link"] else {
            return XCTFail("expected link")
        }
        XCTAssertEqual(decodedLink.cid, linkedCID)
        guard case let .object(nested)? = value["nested"],
              case let .array(array)? = nested["array"] else {
            return XCTFail("expected nested values")
        }
        XCTAssertEqual(array, [.bool(true), .null, .number(-1)])

        var floatRecord = Data([0xa2, 0x65])
        floatRecord.append(Data("$type".utf8))
        floatRecord.append(0x72)
        floatRecord.append(Data(path.collection.utf8))
        floatRecord.append(0x65)
        floatRecord.append(Data("float".utf8))
        floatRecord.append(contentsOf: [
            0xfb, 0x3f, 0xf8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        ])
        XCTAssertThrowsError(
            try RepositoryMSTValidation.decodeRecordBlock(
                floatRecord, for: path
            )
        )
        let wideInteger = try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
            (key: "$type", value: path.collection),
            (key: "wide", value: UInt64(
                PublicRepositoryRecordCodec.maximumSafeInteger + 1
            )),
        ]))
        XCTAssertThrowsError(
            try RepositoryMSTValidation.decodeRecordBlock(
                wideInteger, for: path
            )
        )
    }

    func testDirectRecordDecoderRejectsImpossibleContainerCountsBeforeAllocation() throws {
        let path = try PublicRepositoryPath(
            collection: "app.bsky.feed.post", recordKey: "hostile-count"
        )

        // A definite-length map claiming Int.max pairs with no payload must
        // fail before Dictionary.reserveCapacity sees the declared count.
        let impossibleMap = Data([
            0xbb, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        ])
        XCTAssertThrowsError(
            try RepositoryMSTValidation.decodeRecordBlock(
                impossibleMap, for: path
            )
        ) { error in
            XCTAssertEqual(
                error as? RepositoryMSTValidationError,
                .invalidRecordBlock
            )
        }

        // The top-level map is plausible, but its nested array declares the
        // same impossible count with no elements.
        var impossibleArray = Data([0xa2, 0x65])
        impossibleArray.append(Data("$type".utf8))
        impossibleArray.append(0x72)
        impossibleArray.append(Data(path.collection.utf8))
        impossibleArray.append(0x65)
        impossibleArray.append(Data("array".utf8))
        impossibleArray.append(contentsOf: [
            0x9b, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        ])
        XCTAssertThrowsError(
            try RepositoryMSTValidation.decodeRecordBlock(
                impossibleArray, for: path
            )
        ) { error in
            XCTAssertEqual(
                error as? RepositoryMSTValidationError,
                .invalidRecordBlock
            )
        }

        // This array has enough one-byte values to meet the byte-derived
        // lower bound, so its rejection exercises the explicit 65,536-item
        // container ceiling before Array.reserveCapacity can run.
        var overCeilingArray = Data([0xa2, 0x65])
        overCeilingArray.append(Data("$type".utf8))
        overCeilingArray.append(0x72)
        overCeilingArray.append(Data(path.collection.utf8))
        overCeilingArray.append(0x65)
        overCeilingArray.append(Data("array".utf8))
        overCeilingArray.append(contentsOf: [0x9a, 0x00, 0x01, 0x00, 0x01])
        overCeilingArray.append(Data(repeating: 0xf6, count: 65_537))
        XCTAssertThrowsError(
            try RepositoryMSTValidation.decodeRecordBlock(
                overCeilingArray, for: path
            )
        ) { error in
            XCTAssertEqual(
                error as? RepositoryMSTValidationError,
                .invalidRecordBlock
            )
        }

        // This canonical map has a complete payload for every entry. `$type`
        // precedes the fixed-width keys, which then sort lexicographically,
        // so removing the explicit map ceiling would make this record decode.
        var overCeilingMap = Data([0xba, 0x00, 0x01, 0x00, 0x01, 0x65])
        overCeilingMap.append(Data("$type".utf8))
        overCeilingMap.append(0x72)
        overCeilingMap.append(Data(path.collection.utf8))
        for index in 0 ..< 65_536 {
            overCeilingMap.append(0x65)
            overCeilingMap.append(Data(String(format: "%05d", index).utf8))
            overCeilingMap.append(0xf6)
        }

        // Prove that the same canonical shape decodes at the exact ceiling;
        // the hostile map below differs only by its final valid entry.
        var maximumValidMap = overCeilingMap
        maximumValidMap.removeLast(7)
        maximumValidMap.replaceSubrange(1 ..< 5, with: [0x00, 0x01, 0x00, 0x00])
        guard case let .object(maximumValidValue) = try RepositoryMSTValidation.decodeRecordBlock(
            maximumValidMap, for: path
        ) else {
            return XCTFail("expected canonical map at the container ceiling")
        }
        XCTAssertEqual(maximumValidValue.count, 65_536)
        XCTAssertEqual(maximumValidValue["65534"], .null)

        XCTAssertThrowsError(
            try RepositoryMSTValidation.decodeRecordBlock(
                overCeilingMap, for: path
            )
        ) { error in
            XCTAssertEqual(
                error as? RepositoryMSTValidationError,
                .invalidRecordBlock
            )
        }
    }

    func testDirectRecordDecoderAcceptsOrdinaryMapAndArrayCounts() throws {
        let path = try PublicRepositoryPath(
            collection: "app.bsky.feed.post", recordKey: "ordinary-count"
        )

        // This is a minimal ordinary record with a two-pair top-level map and
        // a two-element nested array. Both declared counts are exactly backed
        // by their encoded contents and must continue to decode.
        var record = Data([0xa2, 0x65])
        record.append(Data("$type".utf8))
        record.append(0x72)
        record.append(Data(path.collection.utf8))
        record.append(0x65)
        record.append(Data("array".utf8))
        record.append(contentsOf: [0x82, 0xf4, 0xf6])

        guard case let .object(value) = try RepositoryMSTValidation.decodeRecordBlock(
            record, for: path
        ), case let .array(array)? = value["array"] else {
            return XCTFail("expected ordinary object with array")
        }
        XCTAssertEqual(array, [.bool(false), .null])
    }

    func testValidatesCanonicalEmptyRepository() async throws {
        let bytes = PublicRepositoryGenesisCodec.canonicalEmptyMST
        let cid = CID.fromDAGCBOR(bytes)
        let source = try PublicRepositoryBlockMap(blocks: [.init(cid: cid, bytes: bytes)])

        let validated = try await RepositoryMSTValidation.validate(rootCID: cid, blocks: source)
        XCTAssertEqual(validated.rootLayer, 0)
        XCTAssertTrue(validated.leaves.isEmpty)
        XCTAssertEqual(validated.reachableMSTBlocks, [cid: bytes])
        XCTAssertTrue(validated.reachableRecordCIDs.isEmpty)
    }

    func testRejectsMissingAndCIDMismatchedRootBlocks() async throws {
        let root = CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST)
        let empty = try PublicRepositoryBlockMap()
        await XCTAssertThrowsMSTError(.missingBlock) {
            try await RepositoryMSTValidation.validate(rootCID: root, blocks: empty)
        }

        let mismatch = TestBlockSource(storage: [root: Data([0xa0])])
        await XCTAssertThrowsMSTError(.blockCIDMismatch) {
            try await RepositoryMSTValidation.validate(rootCID: root, blocks: mismatch)
        }
    }

    func testRejectsNonCanonicalAndMalformedNodeSchemas() async throws {
        // Same logical empty map, but keys are not in canonical order.
        let nonCanonical = Data([0xa2, 0x61, 0x6c, 0xf6, 0x61, 0x65, 0x80])
        await assertRootRejected(nonCanonical, as: .nonCanonicalNode)

        await assertRootRejected(Data([0xa1, 0x61, 0x65, 0x80]), as: .invalidNodeSchema)
        await assertRootRejected(Data([0xa3, 0x61, 0x65, 0x80, 0x61, 0x6c, 0xf6, 0x61, 0x78, 0xf6]), as: .invalidNodeSchema)

        let wrongTypes = try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
            (key: "e", value: "not-an-array"),
            (key: "l", value: NSNull()),
        ]))
        await assertRootRejected(wrongTypes, as: .invalidNodeSchema)

        let valueCID = CID.fromDAGCBOR(Data([0xa0]))
        let malformedEntries: [(OrderedCBORMap, RepositoryMSTValidationError)] = [
            (OrderedCBORMap(entries: [
                (key: "p", value: 0),
                (key: "k", value: Data("app.bsky.feed.post/0".utf8)),
                (key: "v", value: ATProtoLink(cid: valueCID)),
            ]), .invalidEntrySchema),
            (OrderedCBORMap(entries: [
                (key: "p", value: "zero"),
                (key: "k", value: Data("app.bsky.feed.post/0".utf8)),
                (key: "v", value: ATProtoLink(cid: valueCID)),
                (key: "t", value: NSNull()),
            ]), .invalidNodeSchema),
            (OrderedCBORMap(entries: [
                (key: "p", value: 0),
                (key: "k", value: Data("app.bsky.feed.post/0".utf8)),
                (key: "v", value: ATProtoLink(cid: valueCID)),
                (key: "t", value: NSNull()),
                (key: "x", value: NSNull()),
            ]), .invalidEntrySchema),
        ]
        for (malformedEntry, expected) in malformedEntries {
            let bytes = try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
                (key: "e", value: [malformedEntry] as [Any]),
                (key: "l", value: NSNull()),
            ]))
            await assertRootRejected(bytes, as: expected)
        }

        let recordCID = CID.fromDAGCBOR(Data([0xa0]))
        let emptySuffix = RepositoryMSTNode(leftTreeCID: nil, entries: [
            .init(prefixLength: 0, keySuffix: Data(), valueCID: recordCID, rightTreeCID: nil),
        ])
        await assertRootRejected(try unsafeNodeBytes(emptySuffix), as: .invalidPrefixCompression)

        let nonMinimal = RepositoryMSTNode(leftTreeCID: nil, entries: [
            .init(
                prefixLength: 0,
                keySuffix: Data("app.bsky.feed.post/0".utf8),
                valueCID: recordCID,
                rightTreeCID: nil
            ),
            .init(
                prefixLength: 0,
                keySuffix: Data("app.bsky.feed.post/2".utf8),
                valueCID: recordCID,
                rightTreeCID: nil
            ),
        ])
        await assertRootRejected(try unsafeNodeBytes(nonMinimal), as: .invalidPrefixCompression)
    }

    func testRejectsDuplicateKeysUnsupportedRootAndUnsupportedLinks() async throws {
        let path = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "0")
        let record = try recordBytes(for: path)
        let recordCID = CID.fromDAGCBOR(record)
        let duplicate = RepositoryMSTNode(leftTreeCID: nil, entries: [
            .init(prefixLength: 0, keySuffix: Data(path.mstKey.utf8), valueCID: recordCID, rightTreeCID: nil),
            .init(prefixLength: path.mstKey.utf8.count, keySuffix: Data("x".utf8), valueCID: recordCID, rightTreeCID: nil),
        ])
        // Make the reconstructed second key equal by retaining the complete
        // prior key and supplying an empty suffix.
        let duplicateBytes = try unsafeNodeBytes(RepositoryMSTNode(leftTreeCID: nil, entries: [
            duplicate.entries[0],
            .init(
                prefixLength: path.mstKey.utf8.count,
                keySuffix: Data(),
                valueCID: recordCID,
                rightTreeCID: nil
            ),
        ]))
        await assertRootRejected(duplicateBytes, as: .invalidPrefixCompression)

        let rawRoot = CID.fromBlob(Data([0xa0]))
        let source = TestBlockSource(storage: [rawRoot: Data([0xa0])])
        await XCTAssertThrowsMSTError(.unsupportedCID) {
            try await RepositoryMSTValidation.validate(rootCID: rawRoot, blocks: source)
        }

        let rawValue = CID.fromBlob(Data("raw".utf8))
        let unsupportedLink = RepositoryMSTNode(leftTreeCID: nil, entries: [
            .init(prefixLength: 0, keySuffix: Data(path.mstKey.utf8), valueCID: rawValue, rightTreeCID: nil),
        ])
        await assertRootRejected(try unsafeNodeBytes(unsupportedLink), as: .invalidCIDLink)
    }

    func testValidatesCanonicalDepthGapAndRejectsRangeLayerAndEmptyTopology() async throws {
        let rootPath = try path(withDepth: 2)
        let lowerDepthZero = try path(withDepth: 0, upperBound: rootPath.mstKey)
        let higherDepthZero = try path(withDepth: 0, lowerBound: rootPath.mstKey)
        let rootRecord = try recordBytes(for: rootPath, text: "root")
        let childRecord = try recordBytes(for: lowerDepthZero, text: "child")
        let rootRecordCID = CID.fromDAGCBOR(rootRecord)
        let childRecordCID = CID.fromDAGCBOR(childRecord)

        let child = try RepositoryMSTCodec.node(leaves: [
            .init(path: lowerDepthZero, recordCID: childRecordCID),
        ])
        let childBytes = try RepositoryMSTCodec.encode(child)
        let childCID = CID.fromDAGCBOR(childBytes)
        let bridge = RepositoryMSTNode(leftTreeCID: childCID, entries: [])
        let bridgeBytes = try RepositoryMSTCodec.encode(bridge)
        let bridgeCID = CID.fromDAGCBOR(bridgeBytes)
        let root = try RepositoryMSTCodec.node(
            leaves: [.init(path: rootPath, recordCID: rootRecordCID)],
            leftTreeCID: bridgeCID
        )
        let rootBytes = try RepositoryMSTCodec.encode(root)
        let rootCID = CID.fromDAGCBOR(rootBytes)
        let validSource = TestBlockSource(storage: [
            rootCID: rootBytes,
            bridgeCID: bridgeBytes,
            childCID: childBytes,
            rootRecordCID: rootRecord,
            childRecordCID: childRecord,
        ])
        let validated = try await RepositoryMSTValidation.validate(rootCID: rootCID, blocks: validSource)
        XCTAssertEqual(validated.rootLayer, 2)
        XCTAssertEqual(validated.leaves.map(\.path), [lowerDepthZero, rootPath])

        let wrongLayerRoot = try RepositoryMSTCodec.node(
            leaves: [.init(path: rootPath, recordCID: rootRecordCID)],
            leftTreeCID: childCID
        )
        try await assertTreeRejected(
            wrongLayerRoot,
            records: [childCID: childBytes, rootRecordCID: rootRecord, childRecordCID: childRecord],
            as: .invalidLayer
        )

        let outOfRangeRecord = try recordBytes(for: higherDepthZero)
        let outOfRangeCID = CID.fromDAGCBOR(outOfRangeRecord)
        let outOfRangeChild = try RepositoryMSTCodec.node(leaves: [
            .init(path: higherDepthZero, recordCID: outOfRangeCID),
        ])
        let outBytes = try RepositoryMSTCodec.encode(outOfRangeChild)
        let outCID = CID.fromDAGCBOR(outBytes)
        let rangeRoot = try RepositoryMSTCodec.node(
            leaves: [.init(path: rootPath, recordCID: rootRecordCID)],
            leftTreeCID: outCID
        )
        try await assertTreeRejected(
            rangeRoot,
            records: [outCID: outBytes, rootRecordCID: rootRecord, outOfRangeCID: outOfRangeRecord],
            as: .invalidLayer
        )

        let rangeRootPath = try path(withDepth: 1)
        let rangeChildPath = try path(withDepth: 0, lowerBound: rangeRootPath.mstKey)
        let rangeRootRecord = try recordBytes(for: rangeRootPath)
        let rangeChildRecord = try recordBytes(for: rangeChildPath)
        let rangeRootRecordCID = CID.fromDAGCBOR(rangeRootRecord)
        let rangeChildRecordCID = CID.fromDAGCBOR(rangeChildRecord)
        let rangeChild = try RepositoryMSTCodec.node(leaves: [
            .init(path: rangeChildPath, recordCID: rangeChildRecordCID),
        ])
        let rangeChildBytes = try RepositoryMSTCodec.encode(rangeChild)
        let rangeChildCID = CID.fromDAGCBOR(rangeChildBytes)
        let properLayerWrongRange = try RepositoryMSTCodec.node(
            leaves: [.init(path: rangeRootPath, recordCID: rangeRootRecordCID)],
            leftTreeCID: rangeChildCID
        )
        try await assertTreeRejected(
            properLayerWrongRange,
            records: [
                rangeChildCID: rangeChildBytes,
                rangeRootRecordCID: rangeRootRecord,
            ],
            as: .subtreeOutOfRange
        )

        let invalidEmptyRoot = RepositoryMSTNode(leftTreeCID: childCID, entries: [])
        try await assertTreeRejected(
            invalidEmptyRoot,
            records: [childCID: childBytes, childRecordCID: childRecord],
            as: .invalidEmptyTopology
        )

        let depthOne = try path(withDepth: 1)
        let depthOneRecord = try recordBytes(for: depthOne)
        let depthOneRecordCID = CID.fromDAGCBOR(depthOneRecord)
        let emptyCID = CID.fromDAGCBOR(PublicRepositoryGenesisCodec.canonicalEmptyMST)
        let bottomEmptyRoot = try RepositoryMSTCodec.node(
            leaves: [.init(path: depthOne, recordCID: depthOneRecordCID)],
            leftTreeCID: emptyCID
        )
        try await assertTreeRejected(
            bottomEmptyRoot,
            records: [
                emptyCID: PublicRepositoryGenesisCodec.canonicalEmptyMST,
                depthOneRecordCID: depthOneRecord,
            ],
            as: .invalidEmptyTopology
        )
    }

    func testRejectsMismatchedOversizedAndInvalidRecordBlocks() async throws {
        let path = try path(withDepth: 0)
        let valid = try recordBytes(for: path)
        let cid = CID.fromDAGCBOR(valid)
        let node = try RepositoryMSTCodec.node(leaves: [.init(path: path, recordCID: cid)])
        let nodeBytes = try RepositoryMSTCodec.encode(node)
        let nodeCID = CID.fromDAGCBOR(nodeBytes)

        let mismatch = TestBlockSource(storage: [nodeCID: nodeBytes, cid: Data([0xa0])])
        await XCTAssertThrowsMSTError(.recordBlockCIDMismatch) {
            try await RepositoryMSTValidation.validate(rootCID: nodeCID, blocks: mismatch)
        }

        let tiny = try PublicRepositoryLimits(
            maximumRecordBlockBytes: 1,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: 2,
            maximumMSTNodes: 1,
            maximumMSTEntriesPerNode: 1,
            maximumCBORNestingDepth: 64
        )
        let validSource = TestBlockSource(storage: [nodeCID: nodeBytes, cid: valid])
        await XCTAssertThrowsMSTError(.recordBlockTooLarge) {
            try await RepositoryMSTValidation.validate(rootCID: nodeCID, blocks: validSource, limits: tiny)
        }

        let wrongType = try PublicRepositoryRecordCodec.prepare(
            PublicRecord(["$type": .string("app.bsky.feed.like")]),
            for: PublicRepositoryPath(collection: "app.bsky.feed.like", recordKey: "x")
        ).bytes
        let wrongTypeCID = CID.fromDAGCBOR(wrongType)
        let wrongTypeNode = try RepositoryMSTCodec.node(leaves: [.init(path: path, recordCID: wrongTypeCID)])
        try await assertTreeRejected(wrongTypeNode, records: [wrongTypeCID: wrongType], as: .invalidRecordBlock)
    }

    func testRejectsCBORNestingPolicyBelowNodeSchemaDepth() async throws {
        let shallow = try PublicRepositoryLimits(
            maximumRecordBlockBytes: 100,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: 1,
            maximumMSTNodes: 1,
            maximumMSTEntriesPerNode: 1,
            maximumCBORNestingDepth: 2
        )
        let bytes = PublicRepositoryGenesisCodec.canonicalEmptyMST
        let cid = CID.fromDAGCBOR(bytes)
        let source = TestBlockSource(storage: [cid: bytes])
        await XCTAssertThrowsMSTError(.cborDepthLimitExceeded) {
            try await RepositoryMSTValidation.validate(rootCID: cid, blocks: source, limits: shallow)
        }
    }

    func testRecordParserRejectsHostileCanonicalityAndDataModelValues() async throws {
        let path = try path(withDepth: 0)
        let typeValue = cborText(path.collection)

        try await assertInvalidRecord(
            recordMap([("text", cborText("missing type"))]),
            for: path
        )
        try await assertInvalidRecord(
            recordMap([("$type", cborText("app.bsky.feed.like"))]),
            for: path
        )
        try await assertInvalidRecord(
            recordMap([("$type", typeValue), ("$type", typeValue)], preserveOrder: true),
            for: path
        )
        try await assertInvalidRecord(
            recordMap([("$type", typeValue), ("a", Data([0xf6]))], preserveOrder: true),
            for: path
        )

        // Both keys have five UTF-8 bytes and `$type` canonically precedes
        // `value`. The values themselves exercise the strict data model.
        try await assertInvalidRecord(
            recordMap([
                ("$type", typeValue),
                ("value", Data([0x1b, 0x00, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])),
            ]),
            for: path
        )
        try await assertInvalidRecord(
            recordMap([("$type", typeValue), ("value", Data([0xfa, 0, 0, 0, 0]))]),
            for: path
        )
        try await assertInvalidRecord(
            recordMap([("$type", typeValue), ("value", Data([0xf7]))]),
            for: path
        )
        try await assertInvalidRecord(
            recordMap([("$type", typeValue), ("value", Data([0x18, 0x01]))]),
            for: path
        )

        var malformedCID = CID.fromBlob(Data("blob".utf8)).bytes
        malformedCID[malformedCID.startIndex] = 0x02
        let malformedLink = Data([0xd8, 0x2a, 0x58, 0x25, 0x00]) + malformedCID
        try await assertInvalidRecord(
            recordMap([("$type", typeValue), ("value", malformedLink)]),
            for: path
        )
    }

    func testRecordParserNestingBoundaryIsInclusive() async throws {
        let path = try path(withDepth: 0)
        let accepted = try PublicRepositoryRecordCodec.prepare(
            PublicRecord([
                "$type": .string(path.collection),
                "nested": .array([.array([.null])]),
            ]),
            for: path,
            limits: try limitsWithDepth(3)
        ).bytes
        _ = try await validateSingleRecord(accepted, for: path, limits: try limitsWithDepth(3))

        let tooDeep = try PublicRepositoryRecordCodec.prepare(
            PublicRecord([
                "$type": .string(path.collection),
                "nested": .array([.array([.array([.null])])]),
            ]),
            for: path,
            limits: try limitsWithDepth(4)
        ).bytes
        await XCTAssertThrowsMSTError(.invalidRecordBlock) {
            try await validateSingleRecord(tooDeep, for: path, limits: try limitsWithDepth(3))
        }
    }

    func testRejectsBadPrefixUnsortedAndWrongLayer() async throws {
        let path0 = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "0")
        let path2 = try PublicRepositoryPath(collection: "app.bsky.feed.post", recordKey: "2")
        let recordA = try recordBytes(for: path0, text: "a")
        let recordB = try recordBytes(for: path2, text: "b")
        let cidA = CID.fromDAGCBOR(recordA)
        let cidB = CID.fromDAGCBOR(recordB)
        let badPrefix = RepositoryMSTNode(leftTreeCID: nil, entries: [
            .init(prefixLength: 1, keySuffix: Data(path0.mstKey.utf8), valueCID: cidA, rightTreeCID: nil),
        ])
        await assertRootRejected(try unsafeNodeBytes(badPrefix), as: .invalidPrefixCompression)

        let unsorted = RepositoryMSTNode(leftTreeCID: nil, entries: [
            .init(prefixLength: 0, keySuffix: Data(path2.mstKey.utf8), valueCID: cidB, rightTreeCID: nil),
            .init(
                prefixLength: path2.mstKey.utf8.count - 1,
                keySuffix: Data("0".utf8),
                valueCID: cidA,
                rightTreeCID: nil
            ),
        ])
        await assertRootRejected(try unsafeNodeBytes(unsorted), as: .keysNotStrictlyIncreasing)

        let depthOne = try path(withDepth: 1)
        let wrongLayer = try RepositoryMSTCodec.node(leaves: [
            .init(path: path0, recordCID: cidA, rightTreeCID: nil),
            .init(path: depthOne, recordCID: cidB, rightTreeCID: nil),
        ])
        try await assertTreeRejected(wrongLayer, records: [cidA: recordA, cidB: recordB], as: .leafLayerMismatch)
    }

    func testRejectsMissingRecordAndRepeatedNode() async throws {
        let rootPath = try path(withDepth: 1)
        let childPath = try path(withDepth: 0, excluding: [rootPath])
        let record = try recordBytes(for: rootPath)
        let recordCID = CID.fromDAGCBOR(record)
        let child = try RepositoryMSTCodec.node(leaves: [.init(path: childPath, recordCID: recordCID)])
        let childBytes = try RepositoryMSTCodec.encode(child)
        let childCID = CID.fromDAGCBOR(childBytes)
        let root = try RepositoryMSTCodec.node(
            leaves: [.init(path: rootPath, recordCID: recordCID, rightTreeCID: childCID)],
            leftTreeCID: childCID
        )
        let rootBytes = try RepositoryMSTCodec.encode(root)
        let rootCID = CID.fromDAGCBOR(rootBytes)

        let source = TestBlockSource(storage: [rootCID: rootBytes, childCID: childBytes, recordCID: record])
        await XCTAssertThrowsMSTError(.repeatedNode) {
            try await RepositoryMSTValidation.validate(rootCID: rootCID, blocks: source)
        }

        let single = try RepositoryMSTCodec.node(leaves: [.init(path: childPath, recordCID: recordCID)])
        let singleBytes = try RepositoryMSTCodec.encode(single)
        try await assertTreeRejected(single, records: [:], as: .missingRecordBlock)
        XCTAssertFalse(singleBytes.isEmpty)
    }

    func testEnforcesNodeEntryAndReachableRepositoryByteBudgetsAtBoundary() async throws {
        let path = try path(withDepth: 0)
        let record = try recordBytes(for: path)
        let recordCID = CID.fromDAGCBOR(record)
        let node = try RepositoryMSTCodec.node(leaves: [.init(path: path, recordCID: recordCID)])
        let nodeBytes = try RepositoryMSTCodec.encode(node)
        let nodeCID = CID.fromDAGCBOR(nodeBytes)
        let source = TestBlockSource(storage: [nodeCID: nodeBytes, recordCID: record])

        let exact = try limits(nodes: 1, entries: 1)
        _ = try await RepositoryMSTValidation.validate(rootCID: nodeCID, blocks: source, limits: exact)
        _ = try await RepositoryMSTValidation.validate(
            rootCID: nodeCID,
            blocks: source,
            limits: exact,
            maximumReachableRepositoryBytes: nodeBytes.count + record.count
        )

        let noNodes = try limits(nodes: 1, entries: 1)
        await XCTAssertThrowsMSTError(.nodeLimitExceeded) {
            try await RepositoryMSTValidation.validate(
                rootCID: nodeCID,
                blocks: source,
                limits: noNodes,
                maximumMSTNodesOverride: 0
            )
        }
        await XCTAssertThrowsMSTError(.entryLimitExceeded) {
            try await RepositoryMSTValidation.validate(
                rootCID: nodeCID,
                blocks: source,
                limits: exact,
                maximumMSTEntriesPerNodeOverride: 0
            )
        }
        await XCTAssertThrowsMSTError(.reachableRepositoryByteLimitExceeded) {
            try await RepositoryMSTValidation.validate(
                rootCID: nodeCID,
                blocks: source,
                limits: exact,
                maximumReachableRepositoryBytes: nodeBytes.count + record.count - 1
            )
        }
    }

    func testFullRepositoryTraversalIsNotLimitedByMutationByteBudget() async throws {
        var paths: [PublicRepositoryPath] = []
        while paths.count < 3 {
            paths.append(try path(withDepth: 0, excluding: Set(paths)))
        }
        paths.sort { $0.mstKey < $1.mstKey }

        var leaves: [RepositoryMSTLeaf] = []
        var storage: [CID: Data] = [:]
        for (index, path) in paths.enumerated() {
            let record = try PublicRepositoryRecordCodec.prepare(
                PublicRecord([
                    "$type": .string(path.collection),
                    "text": .string(String(repeating: Character(String(index)), count: 740_000)),
                ]),
                for: path
            ).bytes
            let cid = CID.fromDAGCBOR(record)
            storage[cid] = record
            leaves.append(.init(path: path, recordCID: cid))
        }
        let node = try RepositoryMSTCodec.node(leaves: leaves)
        let nodeBytes = try RepositoryMSTCodec.encode(node)
        let nodeCID = CID.fromDAGCBOR(nodeBytes)
        storage[nodeCID] = nodeBytes
        let source = TestBlockSource(storage: storage)

        let validated = try await RepositoryMSTValidation.validate(rootCID: nodeCID, blocks: source)
        XCTAssertGreaterThan(
            validated.reachableRepositoryByteCount,
            PublicRepositoryLimits.pinnedMaximumRelevantBlockBytes
        )

        _ = try await RepositoryMSTValidation.validate(
            rootCID: nodeCID,
            blocks: source,
            maximumReachableRepositoryBytes: validated.reachableRepositoryByteCount
        )
        await XCTAssertThrowsMSTError(.reachableRepositoryByteLimitExceeded) {
            try await RepositoryMSTValidation.validate(
                rootCID: nodeCID,
                blocks: source,
                maximumReachableRepositoryBytes: validated.reachableRepositoryByteCount - 1
            )
        }
        await XCTAssertThrowsMSTError(.invalidReachableRepositoryByteBudget) {
            try await RepositoryMSTValidation.validate(
                rootCID: nodeCID,
                blocks: source,
                maximumReachableRepositoryBytes: PublicRepositoryLimits.standard.maximumCARBytes + 1
            )
        }
    }

    private func assertRootRejected(
        _ bytes: Data,
        as expected: RepositoryMSTValidationError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let cid = CID.fromDAGCBOR(bytes)
        let source = TestBlockSource(storage: [cid: bytes])
        await XCTAssertThrowsMSTError(expected, file: file, line: line) {
            try await RepositoryMSTValidation.validate(rootCID: cid, blocks: source)
        }
    }

    private func assertTreeRejected(
        _ node: RepositoryMSTNode,
        records: [CID: Data],
        as expected: RepositoryMSTValidationError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let bytes = try RepositoryMSTCodec.encode(node)
        let cid = CID.fromDAGCBOR(bytes)
        let source = TestBlockSource(storage: records.merging([cid: bytes]) { first, _ in first })
        await XCTAssertThrowsMSTError(expected, file: file, line: line) {
            try await RepositoryMSTValidation.validate(rootCID: cid, blocks: source)
        }
    }

    private func unsafeNodeBytes(_ node: RepositoryMSTNode) throws -> Data {
        let entries: [Any] = node.entries.map { entry in
            OrderedCBORMap(entries: [
                (key: "p", value: UInt64(entry.prefixLength)),
                (key: "k", value: entry.keySuffix),
                (key: "v", value: ATProtoLink(cid: entry.valueCID)),
                (key: "t", value: entry.rightTreeCID.map { ATProtoLink(cid: $0) } ?? NSNull()),
            ])
        }
        return try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
            (key: "l", value: node.leftTreeCID.map { ATProtoLink(cid: $0) } ?? NSNull()),
            (key: "e", value: entries),
        ]))
    }

    private func path(
        withDepth depth: Int,
        excluding: Set<PublicRepositoryPath> = [],
        lowerBound: String? = nil,
        upperBound: String? = nil
    ) throws -> PublicRepositoryPath {
        for index in 0 ..< 100_000 {
            let candidate = try PublicRepositoryPath(
                collection: "app.bsky.feed.post",
                recordKey: String(index)
            )
            let key = candidate.mstKey
            if RepositoryMSTCodec.keyDepth(for: candidate) == depth,
               !excluding.contains(candidate),
               lowerBound.map({ key > $0 }) ?? true,
               upperBound.map({ key < $0 }) ?? true {
                return candidate
            }
        }
        XCTFail("could not find path at depth \(depth)")
        throw PublicRepositoryDomainError.invalidRecordKey
    }

    private func limits(nodes: Int, entries: Int) throws -> PublicRepositoryLimits {
        try PublicRepositoryLimits(
            maximumRecordBlockBytes: 1_000_000,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: max(nodes, 1),
            maximumMSTNodes: max(nodes, 1),
            maximumMSTEntriesPerNode: max(entries, 1),
            maximumCBORNestingDepth: 64
        )
    }

    private func recordBytes(for path: PublicRepositoryPath, text: String = "record") throws -> Data {
        try PublicRepositoryRecordCodec.prepare(
            PublicRecord([
                "$type": .string(path.collection),
                "text": .string(text),
            ]),
            for: path
        ).bytes
    }

    private func assertInvalidRecord(_ bytes: Data, for path: PublicRepositoryPath) async throws {
        await XCTAssertThrowsMSTError(.invalidRecordBlock) {
            try await validateSingleRecord(bytes, for: path)
        }
    }

    private func validateSingleRecord(
        _ bytes: Data,
        for path: PublicRepositoryPath,
        limits: PublicRepositoryLimits = .standard
    ) async throws -> ValidatedPublicRepositoryMST {
        let recordCID = CID.fromDAGCBOR(bytes)
        let node = try RepositoryMSTCodec.node(leaves: [.init(path: path, recordCID: recordCID)])
        let nodeBytes = try RepositoryMSTCodec.encode(node)
        let nodeCID = CID.fromDAGCBOR(nodeBytes)
        return try await RepositoryMSTValidation.validate(
            rootCID: nodeCID,
            blocks: TestBlockSource(storage: [nodeCID: nodeBytes, recordCID: bytes]),
            limits: limits
        )
    }

    private func limitsWithDepth(_ depth: Int) throws -> PublicRepositoryLimits {
        try PublicRepositoryLimits(
            maximumRecordBlockBytes: 1_000_000,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: 2,
            maximumMSTNodes: 1,
            maximumMSTEntriesPerNode: 1,
            maximumCBORNestingDepth: depth
        )
    }

    private func recordMap(
        _ entries: [(String, Data)],
        preserveOrder: Bool = false
    ) -> Data {
        let ordered = preserveOrder ? entries : entries.sorted {
            let lhs = Data($0.0.utf8)
            let rhs = Data($1.0.utf8)
            return lhs.count == rhs.count ? lhs.lexicographicallyPrecedes(rhs) : lhs.count < rhs.count
        }
        precondition(ordered.count < 24)
        var result = Data([0xa0 | UInt8(ordered.count)])
        for (key, value) in ordered {
            result.append(cborText(key))
            result.append(value)
        }
        return result
    }

    private func cborText(_ value: String) -> Data {
        let bytes = Data(value.utf8)
        precondition(bytes.count < 24)
        return Data([0x60 | UInt8(bytes.count)]) + bytes
    }

    func testValidatedMSTRetainsFirstReadBytesFromNonRepeatableSource() async throws {
        let path = try PublicRepositoryPath(
            collection: "app.bsky.feed.post", recordKey: "0"
        )
        let record = try recordBytes(for: path)
        let recordCID = CID.fromDAGCBOR(record)
        let node = try RepositoryMSTCodec.node(leaves: [
            .init(path: path, recordCID: recordCID),
        ])
        let nodeBytes = try RepositoryMSTCodec.encode(node)
        let rootCID = CID.fromDAGCBOR(nodeBytes)

        let unstableSource = NonRepeatableBlockSource(
            initial: [
                rootCID: nodeBytes,
                recordCID: record,
            ],
            subsequent: [
                rootCID: nil,
                recordCID: record,
            ]
        )

        let validated = try await RepositoryMSTValidation.validate(
            rootCID: rootCID,
            blocks: unstableSource
        )
        XCTAssertEqual(validated.reachableMSTBlocks[rootCID], nodeBytes)
        XCTAssertEqual(validated.leaves.map(\.path), [path])
    }
}

private struct TestBlockSource: PublicRepositoryBlockSource {
    let storage: [CID: Data]

    func block(for cid: CID) async throws -> Data? {
        storage[cid]
    }
}

private actor NonRepeatableBlockSource: PublicRepositoryBlockSource {
    private var storage: [CID: Data]
    private let subsequent: [CID: Data?]
    private var readCount: [CID: Int] = [:]

    init(initial: [CID: Data], subsequent: [CID: Data?]) {
        self.storage = initial
        self.subsequent = subsequent
    }

    func block(for cid: CID) async throws -> Data? {
        let count = readCount[cid, default: 0]
        readCount[cid] = count + 1
        if count == 0 {
            return storage[cid]
        }
        if let override = subsequent[cid] {
            return override
        }
        return storage[cid]
    }
}

private func XCTAssertThrowsMSTError<T>(
    _ expected: RepositoryMSTValidationError,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ expression: () async throws -> T
) async {
    do {
        _ = try await expression()
        XCTFail("expected \(expected)", file: file, line: line)
    } catch {
        XCTAssertEqual(error as? RepositoryMSTValidationError, expected, file: file, line: line)
    }
}
