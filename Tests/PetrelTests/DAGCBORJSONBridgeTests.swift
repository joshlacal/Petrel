import Foundation
@testable import Petrel
import SwiftCBOR
import Testing

@Suite("DAG-CBOR JSON bridge tests")
struct DAGCBORJSONBridgeTests {
    @Test("Typed DAG-CBOR round-trip preserves links, bytes, nested values, and canonical bytes")
    func typedRoundTripIsLossless() throws {
        let fixture = try BridgeFixture.fixture()

        let encoded = try fixture.encodedDAGCBOR()
        let encodedItem = try #require(try CBOR.decode([UInt8](encoded)))
        let decoded = try BridgeFixture.decodedFromDAGCBOR(encoded)
        let ordinaryCIDJSON = try JSONEncoder().encode(fixture.directCID)

        guard case let .map(rootMap) = encodedItem,
              case let .map(blobMap)? = rootMap[.utf8String("blob")],
              case let .map(nestedMap)? = rootMap[.utf8String("nested")]
        else {
            #expect(Bool(false), "Expected the encoded fixture maps")
            return
        }

        #expect(isTag42(blobMap[.utf8String("ref")]))
        #expect(isTag42(rootMap[.utf8String("directCID")]))
        #expect(isTag42(nestedMap[.utf8String("link")]))
        #expect(try JSONDecoder().decode(String.self, from: ordinaryCIDJSON) == fixture.directCID.string)
        #expect(decoded == fixture)
        #expect(try decoded.encodedDAGCBOR() == encoded)
    }

    @Test("String-format CIDs remain CBOR strings while cid-links use tag 42")
    func stringFormatCIDAndCIDLinkRemainDistinct() throws {
        let cid = CID.fromDAGCBOR(Data("strong-ref".utf8))
        let uri = try ATProtocolURI(
            uriString: "at://did:plc:bridge/app.bsky.feed.post/record"
        )
        let strongRef = ComAtprotoRepoStrongRef(uri: uri, cid: cid)
        let encoded = try strongRef.encodedDAGCBOR()
        let encodedItem = try #require(try CBOR.decode([UInt8](encoded)))

        guard case let .map(map) = encodedItem else {
            #expect(Bool(false), "Expected an encoded StrongRef map")
            return
        }

        #expect(map[.utf8String("cid")] == .utf8String(cid.string))
    }

    @Test("Bridge retains null map keys and null array positions")
    func nullPlacementIsPreserved() throws {
        let emptyBoxedOptional = String?.none as Any
        let decodedNull = try DAGCBOR.decodeCBORItem(.null)
        let bridged = try DAGCBORJSONBridge.jsonCompatibleValue(from: [
            "mapNull": emptyBoxedOptional,
            "decodedNull": decodedNull,
            "array": ["before", emptyBoxedOptional, decodedNull, "after"],
        ])
        let object = try #require(bridged as? [String: Any])
        let array = try #require(object["array"] as? [Any])

        #expect(object.keys.contains("mapNull"))
        #expect(object["mapNull"] is NSNull)
        #expect(object["decodedNull"] is NSNull)
        #expect(array.count == 4)
        #expect(array[1] is NSNull)
        #expect(array[2] is NSNull)
    }

    @Test("Exact JSON numbers preserve the full UInt64 range")
    func exactUnsignedIntegersRemainExact() throws {
        let intMax = UInt64(Int.max)
        let uintMax = UInt64.max
        let data = try DAGCBORJSONBridge.jsonData(
            from: ["intMax": intMax, "uintMax": uintMax],
            unsignedIntegerPolicy: .exactJSONNumber
        )
        let decoded = try JSONDecoder().decode(UnsignedIntegerFixture.self, from: data)
        let jsonText = try #require(String(data: data, encoding: .utf8))

        #expect(decoded.intMax == intMax)
        #expect(decoded.uintMax == uintMax)
        #expect(jsonText.contains(String(intMax)))
        #expect(jsonText.contains(String(uintMax)))
        #expect(!jsonText.lowercased().contains("e+"))
    }

    @Test("CAR unsigned policy stringifies only values above Int.max")
    func carUnsignedIntegerPolicyUsesExactBoundary() throws {
        let throughIntMax = UInt64(Int.max)
        let aboveIntMax = throughIntMax + 1
        let root = OrderedCBORMap(entries: [
            (key: "throughIntMax", value: throughIntMax),
            (key: "aboveIntMax", value: aboveIntMax),
            (key: "uintMax", value: UInt64.max),
        ])

        let decoded = try CARRepository.decodeRecordCBOR(DAGCBOR.encodeValue(root))

        guard case let .object(rootObject) = decoded else {
            #expect(Bool(false), "Expected a CAR object root")
            return
        }
        #expect(rootObject["throughIntMax"] == .number(Int.max))
        #expect(rootObject["aboveIntMax"] == .string(String(aboveIntMax)))
        #expect(rootObject["uintMax"] == .string(String(UInt64.max)))
    }

    @Test("CAR decoding bridges nested links and bytes in maps and arrays")
    func carNestedLinksAndBytesUseSharedBridge() throws {
        let cid = CID.fromDAGCBOR(Data("car-link".utf8))
        let bytes = Data([0x00, 0x7F, 0xFF])
        let link = try ATProtoLink(cid: cid).toCBORValue()
        let nested = OrderedCBORMap(entries: [
            (key: "link", value: link),
            (key: "bytes", value: bytes),
            (key: "array", value: [link, bytes]),
        ])
        let root = OrderedCBORMap(entries: [
            (key: "directLink", value: link),
            (key: "directBytes", value: bytes),
            (key: "nested", value: nested),
        ])

        let encodedRoot = try DAGCBOR.encodeValue(root)
        let decoded = try CARRepository.decodeRecordCBOR(encodedRoot)

        guard case let .object(rootObject) = decoded,
              case let .object(nestedObject)? = rootObject["nested"],
              case let .array(nestedArray)? = nestedObject["array"]
        else {
            #expect(Bool(false), "Expected nested CAR objects")
            return
        }

        #expect(linkCID(in: rootObject["directLink"]) == cid)
        #expect(bytesData(in: rootObject["directBytes"]) == bytes)
        #expect(linkCID(in: nestedObject["link"]) == cid)
        #expect(bytesData(in: nestedObject["bytes"]) == bytes)
        #expect(nestedArray.count == 2)
        if nestedArray.count == 2 {
            #expect(linkCID(in: nestedArray[0]) == cid)
            #expect(bytesData(in: nestedArray[1]) == bytes)
        }
        #expect(try decoded.encodedDAGCBOR() == encodedRoot)

        let nestedPrimitiveArray: [Any] = ["nested", NSNull()]
        let arrayRoot: [Any] = [
            "primitive",
            1,
            true,
            NSNull(),
            nestedPrimitiveArray,
            link,
            bytes,
        ]
        let decodedArrayRoot = try CARRepository.decodeRecordCBOR(
            DAGCBOR.encodeValue(arrayRoot)
        )
        guard case let .array(decodedArray) = decodedArrayRoot else {
            #expect(Bool(false), "Expected a CAR array root")
            return
        }
        #expect(decodedArray.count == 7)
        if decodedArray.count == 7 {
            #expect(Array(decodedArray.prefix(5)) == [
                .string("primitive"),
                .number(1),
                .bool(true),
                .null,
                .array([.string("nested"), .null]),
            ])
            #expect(linkCID(in: decodedArray[5]) == cid)
            #expect(bytesData(in: decodedArray[6]) == bytes)
        }
        #expect(try decodedArrayRoot.encodedDAGCBOR() == DAGCBOR.encodeValue(arrayRoot))
    }

    @Test("CAR decoding preserves null-valued map keys")
    func carMapNullUsesSharedBridge() throws {
        let root = OrderedCBORMap(entries: [
            (key: "nullValue", value: NSNull()),
        ])

        let decoded = try CARRepository.decodeRecordCBOR(DAGCBOR.encodeValue(root))

        guard case let .object(rootObject) = decoded else {
            #expect(Bool(false), "Expected a CAR object root")
            return
        }
        #expect(rootObject["nullValue"] == .null)
    }

    @Test("CAR decoding rejects malformed exact link and bytes objects")
    func carMalformedSpecialObjectsAreRejected() throws {
        let malformedLink = OrderedCBORMap(entries: [
            (key: "$link", value: "not-a-cid"),
        ])
        let malformedBytes = OrderedCBORMap(entries: [
            (key: "$bytes", value: "not-base64!"),
        ])

        #expect(throws: (any Error).self) {
            try CARRepository.decodeRecordCBOR(DAGCBOR.encodeValue(malformedLink))
        }
        #expect(throws: (any Error).self) {
            try CARRepository.decodeRecordCBOR(DAGCBOR.encodeValue(malformedBytes))
        }

        let genericObject = OrderedCBORMap(entries: [
            (key: "$link", value: "not-a-cid"),
            (key: "extra", value: true),
        ])
        let decoded = try CARRepository.decodeRecordCBOR(DAGCBOR.encodeValue(genericObject))
        #expect(decoded == .object([
            "$link": .string("not-a-cid"),
            "extra": .bool(true),
        ]))
    }

    @Test("CAR unknown typed objects recurse through every JSON value shape")
    func carUnknownTypedObjectsUseRecursiveFallback() throws {
        let type = "com.example.unknown#record"
        let cid = CID.fromDAGCBOR(Data("unknown-type-link".utf8))
        let bytes = Data([0x00, 0x7F, 0xFF])
        let link = try ATProtoLink(cid: cid).toCBORValue()
        let nestedArray: [Any] = ["nested", NSNull()]
        let values: [Any] = ["scalar", 1, true, NSNull(), nestedArray, link, bytes]
        let root = OrderedCBORMap(entries: [
            (key: "$type", value: type),
            (key: "nullValue", value: NSNull()),
            (key: "values", value: values),
        ])
        let encoded = try DAGCBOR.encodeValue(root)

        let decoded = try CARRepository.decodeRecordCBOR(encoded)

        guard case let .unknownType(decodedType, .object(object)) = decoded,
              case let .array(decodedValues)? = object["values"]
        else {
            #expect(Bool(false), "Expected a recursively decoded unknown type")
            return
        }
        #expect(decodedType == type)
        #expect(object["$type"] == .string(type))
        #expect(object["nullValue"] == .null)
        #expect(decodedValues.count == 7)
        if decodedValues.count == 7 {
            #expect(Array(decodedValues.prefix(5)) == [
                .string("scalar"),
                .number(1),
                .bool(true),
                .null,
                .array([.string("nested"), .null]),
            ])
            #expect(linkCID(in: decodedValues[5]) == cid)
            #expect(bytesData(in: decodedValues[6]) == bytes)
        }
        #expect(try decoded.encodedDAGCBOR() == encoded)
    }

    @Test("CAR known typed objects retain generated decoder dispatch")
    func carKnownTypedObjectsUseGeneratedDecoder() throws {
        let root = OrderedCBORMap(entries: [
            (key: "$type", value: "app.bsky.feed.post"),
            (key: "text", value: "typed CAR record"),
            (key: "createdAt", value: "2026-07-15T12:00:00.000Z"),
        ])
        let encoded = try DAGCBOR.encodeValue(root)

        let decoded = try CARRepository.decodeRecordCBOR(encoded)

        guard case let .knownType(value) = decoded,
              let post = value as? AppBskyFeedPost
        else {
            #expect(Bool(false), "Expected generated AppBskyFeedPost dispatch")
            return
        }
        #expect(post.text == "typed CAR record")
        #expect(try decoded.encodedDAGCBOR() == encoded)
    }

    @Test("CAR registered object definitions retain their external discriminator")
    func carRegisteredObjectDefinitionsRetainDiscriminator() throws {
        let type = "com.atproto.repo.strongRef"
        let cid = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let root = OrderedCBORMap(entries: [
            (key: "$type", value: type),
            (key: "uri", value: "at://did:plc:example/app.bsky.feed.post/test"),
            (key: "cid", value: cid),
        ])
        let encoded = try DAGCBOR.encodeValue(root)

        let decoded = try CARRepository.decodeRecordCBOR(encoded)

        guard case let .knownType(value) = decoded,
              let strongRef = value as? ComAtprotoRepoStrongRef
        else {
            Issue.record("Expected CAR StrongRef to use generated decoder dispatch")
            return
        }
        #expect(strongRef.cid.string == cid)
        #expect(try decoded.encodedDAGCBOR() == encoded)
    }

    @Test("Negative integer boundary decodes as Int64.min")
    func negativeIntegerBoundarySucceeds() throws {
        let decoded = try DAGCBOR.decodeCBORItem(.negativeInt(UInt64(Int64.max)))

        #expect(decoded as? Int64 == Int64.min)
    }

    @Test("Negative integer above Int64 boundary throws typed decoding error")
    func negativeIntegerAboveBoundaryIsRejected() {
        do {
            _ = try DAGCBOR.decodeCBORItem(.negativeInt(UInt64(Int64.max) + 1))
            #expect(Bool(false), "Expected a typed DAG-CBOR decoding error")
        } catch let error as DAGCBORError {
            guard case let .decodingFailed(message) = error else {
                #expect(Bool(false), "Expected DAGCBORError.decodingFailed, got \(error)")
                return
            }
            #expect(message.contains("Int64"))
        } catch {
            #expect(Bool(false), "Expected DAGCBORError.decodingFailed, got \(error)")
        }
    }
    @Test("OrderedCBORMap mutating builder preserves exact ordering, duplicate keys, and byte-for-byte identical CBOR output")
    func orderedCBORMapMutatingBuilder() throws {
        var mapAppend = OrderedCBORMap(minimumCapacity: 5)
        mapAppend.append(key: "z_key", value: "z_value")
        mapAppend.append(key: "a_key", value: 123)
        mapAppend.append(key: "dup_key", value: "first")
        mapAppend.append(key: "dup_key", value: "second")
        mapAppend.append(key: "m_key", value: ["sub": "item"])

        var mapAdding = OrderedCBORMap()
        mapAdding = mapAdding.adding(key: "z_key", value: "z_value")
        mapAdding = mapAdding.adding(key: "a_key", value: 123)
        mapAdding = mapAdding.adding(key: "dup_key", value: "first")
        mapAdding = mapAdding.adding(key: "dup_key", value: "second")
        mapAdding = mapAdding.adding(key: "m_key", value: ["sub": "item"])

        #expect(mapAppend.entries.count == 5)
        #expect(mapAdding.entries.count == 5)
        #expect(mapAppend.entries.map { $0.key } == ["z_key", "a_key", "dup_key", "dup_key", "m_key"])
        #expect(mapAdding.entries.map { $0.key } == ["z_key", "a_key", "dup_key", "dup_key", "m_key"])

        let cborAppendData = try mapAppend.encodedDAGCBOR()
        let cborAddingData = try mapAdding.encodedDAGCBOR()
        #expect(cborAppendData == cborAddingData)
        #expect(!cborAppendData.isEmpty)
    }

    // MARK: - Encoded CBOR Preflight and Bounds (F14)

    @Test("CBOR nesting depth 64 succeeds and 65 throws before allocation")
    func cborDepthLimitsEnforced() throws {
        // Build nested arrays: depth 64 vs depth 65
        var data64 = Data()
        for _ in 0 ..< 64 {
            data64.append(0x81) // Array of 1 element
        }
        data64.append(0x00) // Unsigned int 0

        #expect(throws: Never.self) {
            _ = try DAGCBOR.decodeCBORPreflight(data64)
        }

        var data65 = Data()
        for _ in 0 ..< 65 {
            data65.append(0x81) // Array of 1 element
        }
        data65.append(0x00)

        #expect(throws: DAGCBORError.self) {
            _ = try DAGCBOR.decodeCBORPreflight(data65)
        }
    }

    @Test("Huge declared cardinality in tiny input fails preflight without allocation")
    func hugeDeclaredCardinalityFailsPreflight() throws {
        // A map declaring UInt64.max pairs in just 9 bytes
        let hostileMap = Data([0xbb, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff])
        #expect(throws: DAGCBORError.self) {
            _ = try DAGCBOR.decodeCBORPreflight(hostileMap)
        }

        // An array declaring Int.max elements in 9 bytes
        let hostileArray = Data([0x9b, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff])
        #expect(throws: DAGCBORError.self) {
            _ = try DAGCBOR.decodeCBORPreflight(hostileArray)
        }
    }

    @Test("CBOR with unconsumed trailing bytes fails preflight")
    func unconsumedTrailingBytesFailPreflight() throws {
        let validCBOR = Data([0x01]) // Unsigned int 1
        let withTrailing = validCBOR + Data([0x02])
        #expect(throws: DAGCBORError.self) {
            _ = try DAGCBOR.decodeCBORPreflight(withTrailing)
        }
    }

    @Test("Map with duplicate or noncanonical unsorted keys fails preflight")
    func duplicateOrUnsortedMapKeysFailPreflight() throws {
        // Map with 2 keys: "z" then "a" (unsorted in DAG-CBOR)
        let unsortedMap = Data([
            0xa2, // map of 2 pairs
            0x61, 0x7a, 0x01, // "z": 1
            0x61, 0x61, 0x02, // "a": 2
        ])
        #expect(throws: DAGCBORError.self) {
            _ = try DAGCBOR.decodeCBORPreflight(unsortedMap)
        }

        // Map with duplicate keys "a" then "a"
        let duplicateMap = Data([
            0xa2, // map of 2 pairs
            0x61, 0x61, 0x01, // "a": 1
            0x61, 0x61, 0x02, // "a": 2
        ])
        #expect(throws: DAGCBORError.self) {
            _ = try DAGCBOR.decodeCBORPreflight(duplicateMap)
        }
    }

    private func isTag42(_ item: CBOR?) -> Bool {
        guard case let .tagged(tag, _) = item else { return false }
        return tag.rawValue == 42
    }

    private func linkCID(in value: ATProtocolValueContainer?) -> CID? {
        guard case let .link(link)? = value else { return nil }
        return link.cid
    }

    private func bytesData(in value: ATProtocolValueContainer?) -> Data? {
        guard case let .bytes(bytes)? = value else { return nil }
        return bytes.data
    }
}

private struct BridgeFixture: ATProtocolCodable, Equatable {
    let blob: Blob
    let bytes: Bytes
    let directCID: CID
    let nested: NestedFixture
    let nullMapValue: String?
    let nullArray: [String?]

    static func fixture() throws -> BridgeFixture {
        let cid = CID.fromDAGCBOR(Data("bridge-link".utf8))
        return BridgeFixture(
            blob: Blob(
                type: "blob",
                ref: ATProtoLink(cid: cid),
                mimeType: "image/png",
                size: 3
            ),
            bytes: Bytes(data: Data([0x00, 0x7F, 0xFF])),
            directCID: cid,
            nested: NestedFixture(
                link: cid,
                map: ["key": "value"],
                array: ["first", "second"]
            ),
            nullMapValue: nil,
            nullArray: ["before", nil, "after"]
        )
    }

    func toCBORValue() throws -> Any {
        let nestedMap = try OrderedCBORMap(entries: [
            (key: "link", value: ATProtoLink(cid: nested.link).toCBORValue()),
            (key: "map", value: nested.map),
            (key: "array", value: nested.array),
        ])
        return try OrderedCBORMap(entries: [
            (key: "blob", value: blob.toCBORValue()),
            (key: "bytes", value: bytes.toCBORValue()),
            (key: "directCID", value: ATProtoLink(cid: directCID).toCBORValue()),
            (key: "nested", value: nestedMap),
            (key: "nullMapValue", value: nullMapValue as Any),
            (key: "nullArray", value: nullArray.map { $0 as Any }),
        ])
    }
}

private struct NestedFixture: Codable, Equatable {
    let link: CID
    let map: [String: String]
    let array: [String]
}

private struct UnsignedIntegerFixture: Decodable {
    let intMax: UInt64
    let uintMax: UInt64
}
