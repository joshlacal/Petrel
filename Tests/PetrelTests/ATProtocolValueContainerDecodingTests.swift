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

    @Test("Registered top-level object definitions preserve their external discriminator")
    func registeredTopLevelObjectsPreserveExternalDiscriminator() throws {
        let type = "com.atproto.repo.strongRef"
        let cid = "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
        let original = ATProtocolValueContainer.object([
            "$type": .string(type),
            "uri": .string("at://did:plc:example/app.bsky.feed.post/test"),
            "cid": .string(cid),
        ])
        let encoded = try original.encodedDAGCBOR()

        let decoded = try ATProtocolValueContainer.decodedFromDAGCBOR(encoded)

        guard case let .knownType(value) = decoded,
              let strongRef = value as? ComAtprotoRepoStrongRef
        else {
            Issue.record("Expected generated ComAtprotoRepoStrongRef dispatch")
            return
        }
        #expect(strongRef.uri.description == "at://did:plc:example/app.bsky.feed.post/test")
        #expect(strongRef.cid.string == cid)
        #expect(try decoded.encodedDAGCBOR() == encoded)

        let jsonData = try JSONEncoder().encode(decoded)
        let rawJSONObject = try JSONSerialization.jsonObject(with: jsonData)
        let jsonObject = try #require(rawJSONObject as? [String: Any])
        #expect(jsonObject["$type"] as? String == type)
        #expect(jsonObject["uri"] as? String == "at://did:plc:example/app.bsky.feed.post/test")
        #expect(jsonObject["cid"] as? String == cid)

        let jsonRoundTrip = try JSONDecoder().decode(
            ATProtocolValueContainer.self,
            from: jsonData
        )
        guard case let .knownType(jsonValue) = jsonRoundTrip,
              jsonValue is ComAtprotoRepoStrongRef
        else {
            Issue.record("Expected JSON re-encoding to retain StrongRef dispatch")
            return
        }
    }

    @Test("Typed dispatch tolerates explicit nulls and unknown extra fields")
    func typedDispatchToleratesNullsAndUnknownFields() throws {
        // Modeled on a live third-party record (post 3mr3i2my2vt2r) that carries
        // explicit nulls for absent optional fields, unknown extra fields, and
        // nanosecond-precision createdAt. A strict byte-equality re-encode check
        // demoted it to .unknownType, blanking the post in clients.
        let json = #"""
        {
            "$type": "app.bsky.feed.post",
            "allow": [],
            "createdAt": "2026-07-20T14:13:03.720942844Z",
            "embed": {
                "$type": "app.bsky.embed.images",
                "captions": [],
                "external": null,
                "images": [
                    {
                        "alt": "alt text",
                        "aspectRatio": {"height": 1350, "width": 1080},
                        "image": {
                            "$type": "blob",
                            "ref": {"$link": "bafkreic5mujznnhxwdlidm5wlffhgpwtaav5seoicro2ijgay4gwvy74ua"},
                            "mimeType": "image/jpeg",
                            "size": 327266
                        }
                    }
                ],
                "record": null,
                "video": null
            },
            "facets": [
                {
                    "features": [
                        {
                            "$type": "app.bsky.richtext.facet#mention",
                            "did": "did:plc:mrvatd2g4xdzxlcdam3ljnxc",
                            "tag": null,
                            "uri": null
                        }
                    ],
                    "index": {"byteEnd": 41, "byteStart": 18}
                }
            ],
            "hiddenReplies": [],
            "text": "We're endorsing @amyactonoh.bsky.social for Ohio Governor"
        }
        """#

        let decoded = try JSONDecoder().decode(
            ATProtocolValueContainer.self,
            from: Data(json.utf8)
        )

        guard case let .knownType(value) = decoded,
              let post = value as? AppBskyFeedPost
        else {
            Issue.record("Expected AppBskyFeedPost dispatch despite nulls/unknown fields, got \(decoded)")
            return
        }
        #expect(post.text.hasPrefix("We're endorsing"))
        guard case let .appBskyEmbedImages(images)? = post.embed else {
            Issue.record("Expected images embed to survive typed dispatch")
            return
        }
        #expect(images.images.count == 1)
        #expect(post.facets?.count == 1)
    }

    @Test("Typed dispatch tolerates meaningful unknown fields like via")
    func typedDispatchToleratesViaField() throws {
        // Modeled on a live Witchsky record (post 3mr7xawjq3k26): third-party
        // clients stamp a non-lexicon `via` field on posts. Clients must ignore
        // unknown fields, not tombstone the whole post.
        let json = #"""
        {
            "$type": "app.bsky.feed.post",
            "createdAt": "2026-07-22T08:55:40.287Z",
            "langs": ["en"],
            "reply": {
                "parent": {
                    "cid": "bafyreifxe4xz3d6bcj47ctgoq7tnifjzrcqsnfcqghzcte7pfssbhzuoee",
                    "uri": "at://did:plc:nbfjoeficjzf3pejpontvril/app.bsky.feed.post/3mr7x2qbras2k"
                },
                "root": {
                    "cid": "bafyreifxe4xz3d6bcj47ctgoq7tnifjzrcqsnfcqghzcte7pfssbhzuoee",
                    "uri": "at://did:plc:nbfjoeficjzf3pejpontvril/app.bsky.feed.post/3mr7x2qbras2k"
                }
            },
            "text": "oh hey so i'm not just bad",
            "via": "Witchsky Web App"
        }
        """#

        let decoded = try JSONDecoder().decode(
            ATProtocolValueContainer.self,
            from: Data(json.utf8)
        )

        guard case let .knownType(value) = decoded,
              let post = value as? AppBskyFeedPost
        else {
            Issue.record("Expected AppBskyFeedPost dispatch despite via field, got \(decoded)")
            return
        }
        #expect(post.text == "oh hey so i'm not just bad")
        #expect(post.reply != nil)
    }

    @Test("Typed dispatch still demotes when a shared field diverges")
    func typedDispatchStillDemotesOnFieldDivergence() throws {
        // A record whose typed decode fails (text is not a string) must still
        // demote to .unknownType, retaining the raw object losslessly.
        let json = #"{"$type":"app.bsky.feed.post","text":42,"createdAt":"2026-07-15T12:00:00.000Z"}"#

        let decoded = try JSONDecoder().decode(
            ATProtocolValueContainer.self,
            from: Data(json.utf8)
        )

        guard case let .unknownType(type, .object(raw)) = decoded else {
            Issue.record("Expected demotion to unknownType for malformed record")
            return
        }
        #expect(type == "app.bsky.feed.post")
        #expect(raw["text"] == .number(42))
    }

    @Test("Direct object definitions remain unframed when embedded normally")
    func directObjectDefinitionsRemainUnframed() throws {
        let strongRef = try ComAtprotoRepoStrongRef(
            uri: ATProtocolURI(
                uriString: "at://did:plc:example/app.bsky.feed.post/test"
            ),
            cid: CID.parse(
                "bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
            )
        )

        let jsonData = try JSONEncoder().encode(strongRef)
        let rawJSONObject = try JSONSerialization.jsonObject(with: jsonData)
        let jsonObject = try #require(rawJSONObject as? [String: Any])
        #expect(jsonObject["$type"] == nil)

        let rawCBORValue = try strongRef.toCBORValue()
        let cborValue = try #require(rawCBORValue as? OrderedCBORMap)
        #expect(!cborValue.entries.contains(where: { $0.key == "$type" }))
    }

    @Test("Registered top-level object definitions tolerate unknown future fields")
    func registeredTopLevelObjectsTolerateFutureFields() throws {
        let type = "com.atproto.repo.strongRef"
        let original = ATProtocolValueContainer.object([
            "$type": .string(type),
            "uri": .string("at://did:plc:example/app.bsky.feed.post/test"),
            "cid": .string("bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"),
            "future": .object(["enabled": .bool(true)]),
        ])
        let encoded = try original.encodedDAGCBOR()

        let decoded = try ATProtocolValueContainer.decodedFromDAGCBOR(encoded)

        guard case let .knownType(value) = decoded,
              let strongRef = value as? ComAtprotoRepoStrongRef
        else {
            Issue.record("Expected typed dispatch to ignore the unknown future field")
            return
        }
        #expect(strongRef.uri.description == "at://did:plc:example/app.bsky.feed.post/test")
    }

    @Test("Custom typed dictionary objects receive their external discriminator")
    func customTypedDictionaryObjectsReceiveExternalDiscriminator() throws {
        let container = ATProtocolValueContainer.knownType(
            DictionaryBackedTypedValue(value: "fixture")
        )

        let rawValue = try container.toCBORValue()
        let object = try #require(rawValue as? [String: Any])

        #expect(
            object["$type"] as? String ==
                DictionaryBackedTypedValue.typeIdentifier
        )
        #expect(object["value"] as? String == "fixture")
        _ = try container.encodedDAGCBOR()
    }

    @Test("Custom ordered objects reject duplicate external discriminators")
    func customOrderedObjectsRejectDuplicateDiscriminators() {
        for trailingType in [
            DuplicateDiscriminatorTypedValue.typeIdentifier,
            "com.example.mismatched",
        ] {
            let container = ATProtocolValueContainer.knownType(
                DuplicateDiscriminatorTypedValue(trailingType: trailingType)
            )

            #expect(throws: DAGCBORError.self) {
                try container.toCBORValue()
            }
        }
    }

    @Test("Known typed dispatch tolerates future fields and lenient optional degradation")
    func knownTypedDispatchToleratesFutureAndLenientFields() throws {
        let type = AppBskyFeedPost.typeIdentifier
        let futurePost = ATProtocolValueContainer.object([
            "$type": .string(type),
            "text": .string("future value"),
            "createdAt": .string("2026-07-15T12:00:00.000Z"),
            "future": .object(["enabled": .bool(true)]),
        ])
        let futurePostCBOR = try futurePost.encodedDAGCBOR()

        let decodedTopLevel = try ATProtocolValueContainer.decodedFromDAGCBOR(futurePostCBOR)
        guard case let .knownType(topValue) = decodedTopLevel,
              let topPost = topValue as? AppBskyFeedPost
        else {
            Issue.record("Expected typed dispatch to ignore the top-level future field")
            return
        }
        #expect(topPost.text == "future value")

        let nestedRoot = ATProtocolValueContainer.object(["post": futurePost])
        let nestedCBOR = try nestedRoot.encodedDAGCBOR()
        let decodedNestedRoot = try ATProtocolValueContainer.decodedFromDAGCBOR(nestedCBOR)
        guard case let .object(nestedObject) = decodedNestedRoot,
              case let .knownType(nestedValue)? = nestedObject["post"],
              nestedValue is AppBskyFeedPost
        else {
            Issue.record("Expected typed dispatch to ignore the nested future field")
            return
        }

        // The generated decoder is lenient on langs (malformed value degrades to
        // nil) and the dropped key is tolerated like an unknown field: the post
        // renders without its language tags rather than tombstoning entirely.
        let malformedPost = ATProtocolValueContainer.object([
            "$type": .string(type),
            "text": .string("malformed optional value"),
            "createdAt": .string("2026-07-15T12:00:00.000Z"),
            "langs": .string("not-an-array"),
        ])
        let malformedCBOR = try malformedPost.encodedDAGCBOR()
        let decodedMalformed = try ATProtocolValueContainer.decodedFromDAGCBOR(malformedCBOR)
        guard case let .knownType(malformedValue) = decodedMalformed,
              let malformedTyped = malformedValue as? AppBskyFeedPost
        else {
            Issue.record("Expected lenient typed dispatch for a malformed optional field")
            return
        }
        #expect(malformedTyped.text == "malformed optional value")
        #expect(malformedTyped.langs == nil)
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

private struct DictionaryBackedTypedValue: ATProtocolValue {
    static let typeIdentifier = "com.example.dictionaryBacked"

    let value: String

    func isEqual(to other: any ATProtocolValue) -> Bool {
        self == other as? Self
    }

    func toCBORValue() throws -> Any {
        ["value": value]
    }
}

private struct DuplicateDiscriminatorTypedValue: ATProtocolValue {
    static let typeIdentifier = "com.example.duplicateDiscriminator"

    let trailingType: String

    func isEqual(to other: any ATProtocolValue) -> Bool {
        self == other as? Self
    }

    func toCBORValue() throws -> Any {
        OrderedCBORMap(entries: [
            (key: "$type", value: Self.typeIdentifier),
            (key: "$type", value: trailingType),
            (key: "value", value: "fixture"),
        ])
    }
}
