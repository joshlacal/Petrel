import Foundation
import Petrel
import PetrelCore
import Testing

@Suite("Dynamic value key decoding")
struct ATProtocolValueContainerKeyDecodingTests {
    private typealias Value = ATProtocolValueContainer

    private func decode(_ json: String, using decoder: JSONDecoder = JSONDecoder()) throws -> Value {
        try decoder.decode(Value.self, from: Data(json.utf8))
    }

    @Test("Snake-case strategy applies recursively to dynamic object keys")
    func snakeCaseKeys() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let result = try decode(
            #"{"outer_value":{"display_name":"name","null_value":null},"array_values":[{"inner_count":7},null],"empty_object":{}}"#,
            using: decoder
        )
        #expect(result == .object([
            "outerValue": .object(["displayName": .string("name"), "nullValue": .null]),
            "arrayValues": .array([.object(["innerCount": .number(7)]), .null]),
            "emptyObject": .object([:]),
        ]))
    }

    @Test("Custom key mapping feeds both raw traversal and type discovery")
    func customMappedKeys() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .custom { path in
            let wireKey = path.last?.stringValue ?? ""
            let mapped: String
            if wireKey == "wire_type" {
                mapped = "$type"
            } else if wireKey.hasPrefix("wire_") {
                mapped = String(wireKey.dropFirst(5))
            } else {
                mapped = wireKey
            }
            return DynamicValueTestCodingKey(stringValue: mapped)
        }
        let raw: Value = .object([
            "$type": .string("example.tests.future"),
            "payload": .array([.object(["name": .string("kept"), "nil": .null])]),
        ])
        let result = try decode(
            #"{"wire_type":"example.tests.future","wire_payload":[{"wire_name":"kept","wire_nil":null}]}"#,
            using: decoder
        )
        #expect(result == .unknownType("example.tests.future", raw))
        guard case let .unknownType(type, inner) = result else {
            Issue.record("Mapped $type must still enter unknown-type dispatch")
            return
        }
        #expect(type == "example.tests.future")
        #expect(inner == raw)
    }

    @Test("Special objects require exactly one key including null-valued siblings")
    func exactSpecialObjectsAndLookalikes() throws {
        let cid = CID.fromDAGCBOR(Data("cached-key-test".utf8))
        #expect(try decode(#"{"$link":"\#(cid.string)"}"#) == .link(ATProtoLink(cid: cid)))
        #expect(try decode(#"{"$bytes":"AAH/"}"#) == .bytes(Bytes(data: Data([0, 1, 255]))))
        #expect(try decode(#"{"$bytes":"not-base64!","extra":null}"#) == .object([
            "$bytes": .string("not-base64!"), "extra": .null,
        ]))
        #expect(try decode(#"{"$link":"not-a-cid","extra":true}"#) == .object([
            "$link": .string("not-a-cid"), "extra": .bool(true),
        ]))
        #expect(try decode(#"{"ordinary":null}"#) == .object(["ordinary": .null]))
        for json in [#"{"$bytes":"not-base64!"}"#, #"{"$link":"not-a-cid"}"#] {
            #expect(throws: (any Error).self) { try decode(json) }
        }
    }

    @Test("Heterogeneous arrays retain null positions and signed integer boundaries")
    func mixedArrayAndNumericBounds() throws {
        let json = #"[null,true,false,"text",-9223372036854775808,9223372036854775807,[],{},[null,{"present":null}]]"#
        let expected: Value = .array([
            .null, .bool(true), .bool(false), .string("text"),
            .number(Int.min), .number(Int.max), .array([]), .object([:]),
            .array([.null, .object(["present": .null])]),
        ])
        #expect(try decode(json) == expected)
        #expect(try decode(#"{"values":\#(json),"present":null}"#) == .object([
            "values": expected, "present": .null,
        ]))
        // Test dynamic containers directly, rather than a typed numeric probe.
        for number in ["9223372036854775808", "-9223372036854775809", "18446744073709551615", "1.5"] {
            for document in [number, "[null,\(number)]", "{\"value\":\(number)}"] {
                #expect(throws: (any Error).self) { try decode(document) }
            }
        }
    }

    @Test("In-memory child decoding preserves known and unknown semantic cases")
    func inMemorySemanticCases() throws {
        let known = try decode(
            #"{"$type":"app.bsky.feed.post","text":"kept","createdAt":"2026-07-15T12:00:00.000Z"}"#
        )
        guard case let .knownType(knownValue) = known, knownValue is AppBskyFeedPost else {
            Issue.record("Test setup requires generated AppBskyFeedPost dispatch")
            return
        }
        let unknown: Value = .unknownType("example.tests.future", .object([
            "$type": .string("example.tests.future"), "present": .null,
            "nested": .array([.number(Int.max), .bool(false)]),
        ]))
        let bytes: Value = .bytes(Bytes(data: Data([0, 127, 255])))
        let link: Value = .link(ATProtoLink(cid: CID.fromDAGCBOR(Data("in-memory".utf8))))
        let values: [Value] = [known, unknown, .null, bytes, link]
        let original: Value = .object([
            "known": known, "unknown": unknown, "values": .array(values),
        ])
        let decoded = try Value(from: ATProtocolValueContainerDecoder(value: original))
        #expect(decoded == original)
        #expect(try Value(from: ATProtocolValueContainerDecoder(value: .array(values))) == .array(values))
        guard case let .object(object) = decoded,
              case let .knownType(typed)? = object["known"],
              case let .unknownType(type, raw)? = object["unknown"] else {
            Issue.record("In-memory keyed decode must retain the semantic enum cases")
            return
        }
        #expect((typed as? AppBskyFeedPost)?.text == "kept")
        #expect(type == "example.tests.future")
        guard case let .object(rawObject) = raw else {
            Issue.record("Unknown raw object must remain an object")
            return
        }
        #expect(rawObject["present"] == .null)
        #expect(rawObject["absent"] == nil)
    }
}

private struct DynamicValueTestCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
