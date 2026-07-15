import Foundation
@testable import Petrel
import SwiftCBOR
import Testing

@Suite("ATProtocolValueContainer decoding")
struct ATProtocolValueContainerDecodingTests {
    @Test("Top-level primitive and null values decode by shape")
    func topLevelPrimitivesDecodeByShape() {
        #expect(decodeJSON("null") == .null)
        #expect(decodeJSON("true") == .bool(true))
        #expect(decodeJSON("1") == .number(1))
        #expect(decodeJSON(#""value""#) == .string("value"))
    }

    @Test("Top-level and nested primitive/null arrays preserve every position")
    func primitiveAndNullArraysPreservePositions() {
        let expectedArray = ATProtocolValueContainer.array([
            .number(1),
            .null,
            .bool(true),
            .string("after"),
            .array([.number(2), .null]),
        ])

        #expect(decodeJSON(#"[1,null,true,"after",[2,null]]"#) == expectedArray)
        #expect(
            decodeJSON(#"{"nullValue":null,"values":[1,null,true,"after",[2,null]]}"#)
                == .object([
                    "nullValue": .null,
                    "values": expectedArray,
                ])
        )
    }

    @Test("DAG-CBOR primitive, null, and array roots round-trip byte-identically")
    func dagCBORPrimitiveAndArrayRootsRoundTrip() throws {
        let originals: [ATProtocolValueContainer] = [
            .null,
            .bool(true),
            .number(1),
            .string("value"),
            .array([
                .number(1),
                .null,
                .bool(true),
                .string("after"),
                .array([.number(2), .null]),
            ]),
        ]

        for original in originals {
            let encoded = try original.encodedDAGCBOR()
            let decoded = try ATProtocolValueContainer.decodedFromDAGCBOR(encoded)

            #expect(decoded == original)
            #expect(try decoded.encodedDAGCBOR() == encoded)
        }
    }

    @Test("Only signed 64-bit integers are accepted as generic numeric values")
    func genericNumericValuesEnforceSignedIntegerRange() throws {
        let intMaxCBOR = try DAGCBOR.encodeValue(UInt64(Int.max))
        let intMaxValue = try ATProtocolValueContainer.decodedFromDAGCBOR(intMaxCBOR)
        #expect(intMaxValue == .number(Int.max))
        #expect(try intMaxValue.encodedDAGCBOR() == intMaxCBOR)

        for unsignedValue in [UInt64(Int.max) + 1, UInt64.max] {
            let encoded = try DAGCBOR.encodeValue(unsignedValue)
            expectOutOfRangeUnsignedIntegerError {
                try ATProtocolValueContainer.decodedFromDAGCBOR(encoded)
            }
        }

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(
                ATProtocolValueContainer.self,
                from: Data("1.5".utf8)
            )
        }

        let fractionalCBOR = Data(CBOR.double(1.5).encode())
        #expect(throws: DAGCBORError.self) {
            try ATProtocolValueContainer.decodedFromDAGCBOR(fractionalCBOR)
        }
    }

    @Test("Exact DAG-JSON link and bytes objects recover semantic cases")
    func exactSpecialObjectsPreserveDAGCBORWireForms() throws {
        let cid = CID.fromDAGCBOR(Data("value-container-link".utf8))
        let link = ATProtoLink(cid: cid)
        let bytes = Bytes(data: Data([0x00, 0x7F, 0xFF]))
        let original = ATProtocolValueContainer.object([
            "link": .link(link),
            "bytes": .bytes(bytes),
        ])
        let encoded = try original.encodedDAGCBOR()

        let decoded = try ATProtocolValueContainer.decodedFromDAGCBOR(encoded)

        guard case let .object(object) = decoded else {
            Issue.record("Expected a decoded object root")
            return
        }
        #expect(linkCID(in: object["link"]) == cid)
        #expect(bytesData(in: object["bytes"]) == bytes.data)
        #expect(try decoded.encodedDAGCBOR() == encoded)
    }

    @Test("Exact bytes objects accept padded and unpadded RFC 4648 base64")
    func exactBytesObjectsAcceptPaddedAndUnpaddedBase64() throws {
        let validValues: [(encoded: String, expected: Data)] = [
            ("Zg==", Data("f".utf8)),
            ("Zg", Data("f".utf8)),
            ("Zm8=", Data("fo".utf8)),
            ("Zm8", Data("fo".utf8)),
            ("Zm9v", Data("foo".utf8)),
            ("+/8=", Data([0xFB, 0xFF])),
            ("+/8", Data([0xFB, 0xFF])),
        ]

        for value in validValues {
            let decoded = try JSONDecoder().decode(
                ATProtocolValueContainer.self,
                from: Data(#"{"$bytes":"\#(value.encoded)"}"#.utf8)
            )
            #expect(bytesData(in: decoded) == value.expected)

            let directBytes = try JSONDecoder().decode(
                Bytes.self,
                from: Data(#"{"$bytes":"\#(value.encoded)"}"#.utf8)
            )
            #expect(directBytes.data == value.expected)
        }

        let malformedValues = [
            "Z",
            "Zg=",
            "Zg===",
            "Zg=A",
            "====",
            "Zh==",
            "Zh",
            "Zm9=",
            "Zm9",
            "Z=g=",
            "Zg*=",
            "Zg ==",
        ]
        for malformed in malformedValues {
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(
                    ATProtocolValueContainer.self,
                    from: Data(#"{"$bytes":"\#(malformed)"}"#.utf8)
                )
            }
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(
                    Bytes.self,
                    from: Data(#"{"$bytes":"\#(malformed)"}"#.utf8)
                )
            }
        }
    }

    @Test("Special-object lookalikes with extra keys remain generic objects")
    func specialObjectLookalikesRemainGeneric() throws {
        let decoded = try JSONDecoder().decode(
            ATProtocolValueContainer.self,
            from: Data(
                #"{"link":{"$link":"not-a-cid","extra":true},"bytes":{"$bytes":"not-base64!","extra":true}}"#.utf8
            )
        )

        #expect(decoded == .object([
            "link": .object([
                "$link": .string("not-a-cid"),
                "extra": .bool(true),
            ]),
            "bytes": .object([
                "$bytes": .string("not-base64!"),
                "extra": .bool(true),
            ]),
        ]))
    }

    @Test("Malformed exact link and bytes objects are rejected")
    func malformedExactSpecialObjectsAreRejected() {
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(
                ATProtocolValueContainer.self,
                from: Data(#"{"$link":"not-a-cid"}"#.utf8)
            )
        }
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(
                ATProtocolValueContainer.self,
                from: Data(#"{"$bytes":"not-base64!"}"#.utf8)
            )
        }
    }

    @Test("Unknown typed values recurse through nulls, arrays, links, bytes, and nested types")
    func unknownTypedValuesRecurseLosslessly() throws {
        let type = "com.example.unknown#record"
        let nestedType = "com.example.unknown#nested"
        let cid = CID.fromDAGCBOR(Data("unknown-value-link".utf8))
        let link = ATProtoLink(cid: cid)
        let bytes = Bytes(data: Data([0x01, 0x02, 0x03]))
        let original = ATProtocolValueContainer.unknownType(type, .object([
            "$type": .string(type),
            "nullValue": .null,
            "values": .array([
                .string("before"),
                .null,
                .link(link),
                .bytes(bytes),
                .string("after"),
            ]),
            "nested": .unknownType(nestedType, .object([
                "$type": .string(nestedType),
                "flag": .bool(true),
            ])),
        ]))
        let encoded = try original.encodedDAGCBOR()

        let decoded = try ATProtocolValueContainer.decodedFromDAGCBOR(encoded)

        guard case let .unknownType(decodedType, .object(object)) = decoded,
              case let .array(values)? = object["values"]
        else {
            Issue.record("Expected a recursively decoded unknown type")
            return
        }
        #expect(decodedType == type)
        #expect(object["$type"] == .string(type))
        #expect(object["nullValue"] == .null)
        #expect(values.count == 5)
        if values.count == 5 {
            #expect(values[0] == .string("before"))
            #expect(values[1] == .null)
            #expect(linkCID(in: values[2]) == cid)
            #expect(bytesData(in: values[3]) == bytes.data)
            #expect(values[4] == .string("after"))
        }
        guard case let .unknownType(decodedNestedType, .object(nestedObject))? = object["nested"] else {
            Issue.record("Expected the nested typed object to retain its discriminator")
            return
        }
        #expect(decodedNestedType == nestedType)
        #expect(nestedObject["flag"] == .bool(true))
        #expect(try decoded.encodedDAGCBOR() == encoded)
    }

    @Test("Known typed values retain generated decoder dispatch")
    func knownTypedValuesRetainGeneratedDispatch() throws {
        let decoded = try JSONDecoder().decode(
            ATProtocolValueContainer.self,
            from: Data(
                #"{"$type":"app.bsky.feed.post","text":"typed value","createdAt":"2026-07-15T12:00:00.000Z"}"#.utf8
            )
        )

        guard case let .knownType(value) = decoded,
              let post = value as? AppBskyFeedPost
        else {
            Issue.record("Expected generated AppBskyFeedPost dispatch")
            return
        }
        #expect(post.text == "typed value")
    }

    @Test("Known typed dispatch falls back to raw values when typed decoding loses wire data")
    func knownTypedDispatchPreservesFutureAndMalformedFields() throws {
        let type = AppBskyFeedPost.typeIdentifier
        let futurePost = ATProtocolValueContainer.object([
            "$type": .string(type),
            "text": .string("future value"),
            "createdAt": .string("2026-07-15T12:00:00.000Z"),
            "future": .object(["enabled": .bool(true)]),
        ])
        let futurePostCBOR = try futurePost.encodedDAGCBOR()

        let decodedTopLevel = try ATProtocolValueContainer.decodedFromDAGCBOR(futurePostCBOR)
        guard case let .unknownType(decodedType, .object(decodedObject)) = decodedTopLevel else {
            Issue.record("Expected a raw fallback for a top-level known type with future fields")
            return
        }
        #expect(decodedType == type)
        #expect(decodedObject["future"] == .object(["enabled": .bool(true)]))
        #expect(try decodedTopLevel.encodedDAGCBOR() == futurePostCBOR)

        let nestedRoot = ATProtocolValueContainer.object(["post": futurePost])
        let nestedCBOR = try nestedRoot.encodedDAGCBOR()
        let decodedNestedRoot = try ATProtocolValueContainer.decodedFromDAGCBOR(nestedCBOR)
        guard case let .object(nestedObject) = decodedNestedRoot,
              case let .unknownType(nestedType, .object(nestedPost))? = nestedObject["post"]
        else {
            Issue.record("Expected a raw fallback for a nested known type with future fields")
            return
        }
        #expect(nestedType == type)
        #expect(nestedPost["future"] == .object(["enabled": .bool(true)]))
        #expect(try decodedNestedRoot.encodedDAGCBOR() == nestedCBOR)

        let malformedPost = ATProtocolValueContainer.object([
            "$type": .string(type),
            "text": .string("malformed optional value"),
            "createdAt": .string("2026-07-15T12:00:00.000Z"),
            "langs": .string("not-an-array"),
        ])
        let malformedCBOR = try malformedPost.encodedDAGCBOR()
        let decodedMalformed = try ATProtocolValueContainer.decodedFromDAGCBOR(malformedCBOR)
        guard case let .unknownType(malformedType, .object(malformedObject)) = decodedMalformed else {
            Issue.record("Expected malformed known fields to fall back to their raw object")
            return
        }
        #expect(malformedType == type)
        #expect(malformedObject["langs"] == .string("not-an-array"))
        #expect(try decodedMalformed.encodedDAGCBOR() == malformedCBOR)
    }

    @Test("Link and bytes cases satisfy same-value Equatable and Hashable contracts")
    func linkAndBytesEqualityAndHashing() {
        let link = ATProtocolValueContainer.link(
            ATProtoLink(cid: CID.fromDAGCBOR(Data("equatable-link".utf8)))
        )
        let bytes = ATProtocolValueContainer.bytes(
            Bytes(data: Data([0x00, 0x7F, 0xFF]))
        )

        #expect(link == link)
        #expect(bytes == bytes)
        #expect(Set([link, link]).count == 1)
        #expect(Set([bytes, bytes]).count == 1)
    }
}

private func decodeJSON(_ json: String) -> ATProtocolValueContainer? {
    try? JSONDecoder().decode(
        ATProtocolValueContainer.self,
        from: Data(json.utf8)
    )
}

private func linkCID(in value: ATProtocolValueContainer?) -> CID? {
    guard case let .link(link)? = value else { return nil }
    return link.cid
}

private func bytesData(in value: ATProtocolValueContainer?) -> Data? {
    guard case let .bytes(bytes)? = value else { return nil }
    return bytes.data
}

private func expectOutOfRangeUnsignedIntegerError(
    _ operation: () throws -> ATProtocolValueContainer
) {
    do {
        _ = try operation()
        Issue.record("Expected an out-of-range unsigned integer decoding error")
    } catch DecodingError.dataCorrupted(_) {
        // Foundation may reject the out-of-range JSON token before the custom
        // decoder can attach its more specific signed-range description.
    } catch {
        Issue.record("Expected DecodingError.dataCorrupted, got \(error)")
    }
}
