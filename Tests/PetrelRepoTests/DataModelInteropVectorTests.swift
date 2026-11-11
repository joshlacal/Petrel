import Foundation
import Petrel
import PetrelRepo
import Testing

/// Official `data-model/` vectors from bluesky-social/atproto-interop-tests,
/// read from disk and run in full, plus byte-level negative vectors for the
/// strict DAG-CBOR decoders.
@Suite("Data model interop vectors and strict DAG-CBOR decoding")
struct DataModelInteropVectorTests {
    // MARK: data-model-fixtures.json (JSON -> DAG-CBOR -> CID)

    @Test("fixtures: JSON encodes to the exact DAG-CBOR bytes and CID, and decodes back")
    func fixtures() throws {
        let fixtures = try RawJSON.elements(ofArray: Vectors.data("data-model/data-model-fixtures.json"))
        #expect(fixtures.count == 3)
        for (index, fixture) in fixtures.enumerated() {
            // The `json` member is handed to the parser byte for byte.
            let json = try #require(try RawJSON.member("json", of: fixture))
            let expectedBase64 = try RawJSON.string(try #require(try RawJSON.member("cbor_base64", of: fixture)))
            let expectedCID = try RawJSON.string(try #require(try RawJSON.member("cid", of: fixture)))
            let padding = String(repeating: "=", count: (4 - expectedBase64.count % 4) % 4)
            let expectedBytes = try #require(Data(base64Encoded: expectedBase64 + padding))

            let value = try PublicRecordValue(json: json)
            let encoded = try value.dagCBOR()
            #expect(encoded == expectedBytes, "fixture \(index): DAG-CBOR bytes")
            #expect(CID.fromDAGCBOR(encoded).string == expectedCID, "fixture \(index): CID")
            #expect(try CID.parseBlessed(expectedCID, kind: .dagCBOR).matchesContent(expectedBytes))

            // The official bytes pass the generic strict scanner and decode
            // to the same value under both read policies.
            try DAGCBOR.decodeCBORPreflight(expectedBytes)
            #expect(try PublicRecordValue(dagCBOR: expectedBytes, policy: .dataModel) == value)
            #expect(try PublicRecordValue(dagCBOR: expectedBytes, policy: .strict) == value)

            // JSON -> value -> JSON -> value is stable.
            #expect(try PublicRecordValue(json: value.jsonData()) == value, "fixture \(index): JSON round trip")
        }
    }

    // MARK: data-model-valid.json / data-model-invalid.json

    /// The vectors wrap each case in an object whose single key says what it
    /// is: `rcrd` is a record, anything else is a plain data-model value.
    /// Each case is parsed from the file's own bytes, so `123.0` reaches the
    /// parser as `123.0`.
    private func parse(_ wrapper: Data) throws {
        for (kind, json) in try RawJSON.members(ofObject: wrapper) {
            if kind == "rcrd" {
                let record = try PublicRecord(json: json)
                // A valid record must also encode as DAG-CBOR.
                _ = try PublicRecordValue.object(record.fields).dagCBOR()
            } else {
                _ = try PublicRecordValue(json: json).dagCBOR()
            }
        }
    }

    private func cases(_ file: String) throws -> [(note: String, json: Data)] {
        try RawJSON.elements(ofArray: Vectors.data(file)).map { element in
            let note = try RawJSON.string(try #require(try RawJSON.member("note", of: element)))
            return (note, try #require(try RawJSON.member("json", of: element)))
        }
    }

    @Test("valid: every case parses and encodes")
    func valid() throws {
        let cases = try cases("data-model/data-model-valid.json")
        #expect(cases.count == 5)
        #expect(cases.contains { String(decoding: $0.json, as: UTF8.self).contains("123.0") })
        for entry in cases {
            #expect(throws: Never.self, "\(entry.note)") { try parse(entry.json) }
        }
    }

    @Test("invalid: every case is refused")
    func invalid() throws {
        let cases = try cases("data-model/data-model-invalid.json")
        #expect(cases.count == 12)
        for entry in cases {
            guard entry.json.first == UInt8(ascii: "{") else {
                // "top-level not an object": refused as a record.
                #expect(throws: RepositoryRecordJSONError.invalidRecord, "\(entry.note)") {
                    try PublicRecord(json: entry.json)
                }
                continue
            }
            #expect(throws: RepositoryRecordJSONError.self, "\(entry.note)") { try parse(entry.json) }
        }
    }

    @Test("an integer-like float is the integer; any other float is refused")
    func floats() throws {
        #expect(try PublicRecordValue(json: Data("123.0".utf8)) == .integer(123))
        #expect(try PublicRecordValue(json: Data("1e3".utf8)) == .integer(1_000))
        #expect(try PublicRecordValue(json: Data("-0.0".utf8)) == .integer(0))
        for text in ["123.456", "1e-1", "1e400", "0.1"] {
            #expect(throws: RepositoryRecordJSONError.nonIntegerNumber, "\(text)") {
                try PublicRecordValue(json: Data(text.utf8))
            }
        }
    }

    @Test("the JSON parser is strict")
    func strictJSON() {
        let malformed = [
            "", "{", "[1,]", "{\"a\":1,}", "01", "1 2", "nul", "\"unterminated",
            "\"bad \\x escape\"", "\"lone \\ud800 surrogate\"", "{\"a\" 1}", "[1 2]", "+1", ".5",
        ]
        for text in malformed {
            #expect(throws: RepositoryRecordJSONError.malformedJSON, "\(text)") {
                try PublicRecordValue(json: Data(text.utf8))
            }
        }
        #expect(throws: RepositoryRecordJSONError.duplicateKey("a")) {
            try PublicRecordValue(json: Data("{\"a\":1,\"a\":2}".utf8))
        }
        #expect(throws: RepositoryRecordJSONError.nestingTooDeep) {
            try PublicRecordValue(json: Data("[[[[1]]]]".utf8), maximumDepth: 3)
        }
    }

    // MARK: Strict DAG-CBOR decoding

    /// One malformed encoding of a map, and why it is malformed.
    private struct Hostile {
        let name: String
        let bytes: [UInt8]
    }

    /// `{"a": <value bytes>}` with a correct map header and key.
    private static func mapWithValue(_ value: [UInt8]) -> [UInt8] {
        [0xa1, 0x61, 0x61] + value
    }

    private static let hostile: [Hostile] = [
        // Floats: DAG-CBOR in atproto has no floating-point values at all.
        Hostile(name: "float16", bytes: mapWithValue([0xf9, 0x3c, 0x00])),
        Hostile(name: "float32", bytes: mapWithValue([0xfa, 0x3f, 0x80, 0x00, 0x00])),
        Hostile(name: "float64", bytes: mapWithValue([0xfb, 0x3f, 0xf0, 0, 0, 0, 0, 0, 0])),
        // Simple values other than false, true and null.
        Hostile(name: "undefined", bytes: mapWithValue([0xf7])),
        Hostile(name: "simple(16)", bytes: mapWithValue([0xf0])),
        // Indefinite lengths.
        Hostile(name: "indefinite array", bytes: mapWithValue([0x9f, 0x01, 0xff])),
        Hostile(name: "indefinite map", bytes: [0xbf, 0x61, 0x61, 0x01, 0xff]),
        Hostile(name: "indefinite byte string", bytes: mapWithValue([0x5f, 0x41, 0x00, 0xff])),
        Hostile(name: "indefinite text string", bytes: mapWithValue([0x7f, 0x61, 0x61, 0xff])),
        // Integers and lengths not in their shortest form.
        Hostile(name: "uint 1 in one extra byte", bytes: mapWithValue([0x18, 0x01])),
        Hostile(name: "uint 255 in two bytes", bytes: mapWithValue([0x19, 0x00, 0xff])),
        Hostile(name: "uint 65535 in four bytes", bytes: mapWithValue([0x1a, 0x00, 0x00, 0xff, 0xff])),
        Hostile(name: "uint 2^32-1 in eight bytes", bytes: mapWithValue([0x1b, 0, 0, 0, 0, 0xff, 0xff, 0xff, 0xff])),
        Hostile(name: "negative -1 in one extra byte", bytes: mapWithValue([0x38, 0x00])),
        Hostile(name: "text length in one extra byte", bytes: mapWithValue([0x78, 0x01, 0x61])),
        Hostile(name: "array length in one extra byte", bytes: mapWithValue([0x98, 0x00])),
        Hostile(name: "map length in one extra byte", bytes: [0xb8, 0x01, 0x61, 0x61, 0x01]),
        // Map keys.
        Hostile(name: "keys not sorted (b before a)", bytes: [0xa2, 0x61, 0x62, 0x01, 0x61, 0x61, 0x02]),
        Hostile(name: "longer key before shorter", bytes: [0xa2, 0x62, 0x61, 0x61, 0x01, 0x61, 0x62, 0x02]),
        Hostile(name: "duplicate key", bytes: [0xa2, 0x61, 0x61, 0x01, 0x61, 0x61, 0x02]),
        Hostile(name: "integer key", bytes: [0xa1, 0x01, 0x01]),
        Hostile(name: "byte-string key", bytes: [0xa1, 0x41, 0x61, 0x01]),
        // Tags.
        Hostile(name: "tag 1 (epoch time)", bytes: mapWithValue([0xc1, 0x01])),
        Hostile(name: "tag 43", bytes: mapWithValue([0xd8, 0x2b, 0x41, 0x00])),
        Hostile(name: "tag 42 over text", bytes: mapWithValue([0xd8, 0x2a, 0x61, 0x61])),
        Hostile(name: "tag 42 over an integer", bytes: mapWithValue([0xd8, 0x2a, 0x01])),
        Hostile(name: "tag 42 without the 0x00 prefix", bytes: mapWithValue(
            [0xd8, 0x2a, 0x58, 0x24, 0x01, 0x71, 0x12, 0x20] + [UInt8](repeating: 7, count: 32)
        )),
        Hostile(name: "tag 42 with only the 0x00 prefix", bytes: mapWithValue([0xd8, 0x2a, 0x41, 0x00])),
        Hostile(name: "tag 42 with a truncated CID", bytes: mapWithValue(
            [0xd8, 0x2a, 0x45, 0x00, 0x01, 0x71, 0x12, 0x20]
        )),
        Hostile(name: "tag 42 with bytes that are not a CID", bytes: mapWithValue(
            [0xd8, 0x2a, 0x45, 0x00, 0xff, 0xff, 0xff, 0xff]
        )),
        // Framing.
        Hostile(name: "trailing byte", bytes: mapWithValue([0x01]) + [0x00]),
        Hostile(name: "truncated value", bytes: [0xa1, 0x61, 0x61]),
        Hostile(name: "truncated text", bytes: mapWithValue([0x65, 0x61])),
        Hostile(name: "text that is not UTF-8", bytes: mapWithValue([0x62, 0xc3, 0x28])),
        Hostile(name: "top level is an array", bytes: [0x81, 0x01]),
        Hostile(name: "empty input", bytes: []),
    ]

    /// Cases the generic scanner cannot see because it does not materialize
    /// values (it checks structure, not UTF-8 or CID contents) or because it
    /// accepts any top-level item.
    private static let scannerBlindSpots: Set<String> = [
        "tag 42 with a truncated CID",
        "tag 42 with bytes that are not a CID",
        "text that is not UTF-8",
        "top level is an array",
    ]

    @Test("the repository value decoder refuses every malformed encoding, under both policies")
    func hostileValueDecoder() {
        for hostile in Self.hostile {
            for policy in [RepositoryReadPolicy.dataModel, .strict] {
                #expect(throws: (any Error).self, "\(hostile.name)") {
                    try PublicRecordValue(dagCBOR: Data(hostile.bytes), policy: policy)
                }
            }
        }
    }

    @Test("the generic DAG-CBOR scanner refuses every malformed encoding it is responsible for")
    func hostileGenericScanner() {
        for hostile in Self.hostile where !Self.scannerBlindSpots.contains(hostile.name) {
            #expect(throws: (any Error).self, "\(hostile.name)") {
                try DAGCBOR.decodeCBORPreflight(Data(hostile.bytes))
            }
        }
    }

    @Test("the record block decoder refuses the same encodings inside a record")
    func hostileRecordDecoder() throws {
        let path = try PublicRepositoryPath(collection: "com.example.blah", recordKey: "self")
        // {"$type": "com.example.blah", "a": <value>}; `a` sorts before `$type`.
        let type = Array("com.example.blah".utf8)
        let typeEntry: [UInt8] = [0x65] + Array("$type".utf8) + [0x70] + type
        func record(_ value: [UInt8]) -> Data {
            Data([0xa2, 0x61, 0x61] + value + typeEntry)
        }
        // The frame itself is sound.
        _ = try RepositoryMSTValidation.decodeRecordBlock(record([0x01]), for: path, policy: .dataModel)

        let values: [(String, [UInt8])] = [
            ("float64", [0xfb, 0x3f, 0xf0, 0, 0, 0, 0, 0, 0]),
            ("indefinite array", [0x9f, 0x01, 0xff]),
            ("non-minimal uint", [0x18, 0x01]),
            ("tag 43", [0xd8, 0x2b, 0x41, 0x00]),
            ("tag 42 over text", [0xd8, 0x2a, 0x61, 0x61]),
            ("undefined", [0xf7]),
        ]
        for (name, value) in values {
            for policy in [RepositoryReadPolicy.dataModel, .strict] {
                #expect(throws: RepositoryMSTValidationError.invalidRecordBlock, "\(name)") {
                    try RepositoryMSTValidation.decodeRecordBlock(record(value), for: path, policy: policy)
                }
            }
        }
    }

    // MARK: What the read policy changes, and what it does not

    @Test("integers: 64-bit under the data-model policy, 53-bit under the strict one")
    func integerRange() throws {
        // {"a": 2^53}
        let above53 = Data([0xa1, 0x61, 0x61, 0x1b, 0x00, 0x20, 0, 0, 0, 0, 0, 0])
        #expect(try PublicRecordValue(dagCBOR: above53, policy: .dataModel)
            == .object(["a": .integer(9_007_199_254_740_992)]))
        #expect(throws: RepositoryMSTValidationError.invalidRecordBlock) {
            try PublicRecordValue(dagCBOR: above53, policy: .strict)
        }
        // {"a": Int64.max} and {"a": Int64.min}
        let max64 = Data([0xa1, 0x61, 0x61, 0x1b, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff])
        let min64 = Data([0xa1, 0x61, 0x61, 0x3b, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff])
        #expect(try PublicRecordValue(dagCBOR: max64) == .object(["a": .integer(Int(Int64.max))]))
        #expect(try PublicRecordValue(dagCBOR: min64) == .object(["a": .integer(Int(Int64.min))]))
        // One past either end is outside the data model under every policy.
        let above64 = Data([0xa1, 0x61, 0x61, 0x1b, 0x80, 0, 0, 0, 0, 0, 0, 0])
        let below64 = Data([0xa1, 0x61, 0x61, 0x3b, 0x80, 0, 0, 0, 0, 0, 0, 0])
        for bytes in [above64, below64] {
            #expect(throws: RepositoryMSTValidationError.invalidRecordBlock) {
                try PublicRecordValue(dagCBOR: bytes, policy: .dataModel)
            }
        }
        // The writer stays within the recommended range.
        #expect(throws: PublicRepositoryDomainError.invalidRecordInteger) {
            try PublicRecordValue.object(["a": .integer(9_007_199_254_740_992)]).dagCBOR()
        }
    }

    @Test("links inside a value: blessed only when strict, any well-formed CID otherwise, kept verbatim")
    func linkPolicy() throws {
        func link(_ cid: [UInt8]) -> Data {
            Data([0xa1, 0x61, 0x61, 0xd8, 0x2a, 0x58, UInt8(cid.count + 1), 0x00] + cid)
        }
        let digest = [UInt8](repeating: 9, count: 32)
        let sha512 = [0x01, 0x71, 0x13, 0x40] + [UInt8](repeating: 9, count: 64)
        let dagPB: [UInt8] = [0x01, 0x70, 0x12, 0x20] + digest
        // blake3 (0x1e) is a single-byte hash code `CID` can hold.
        let blake3: [UInt8] = [0x01, 0x71, 0x1e, 0x20] + digest
        for cid in [sha512, dagPB, blake3] {
            let decoded = try PublicRecordValue(dagCBOR: link(cid), policy: .dataModel)
            guard case let .object(fields) = decoded, case let .link(parsed)? = fields["a"] else {
                Issue.record("expected a link")
                continue
            }
            #expect(Array(parsed.bytes) == cid, "the CID is retained byte for byte")
            #expect(!parsed.isBlessed)
            #expect(throws: RepositoryMSTValidationError.invalidRecordBlock) {
                try PublicRecordValue(dagCBOR: link(cid), policy: .strict)
            }
        }

        // A CID `CID` cannot represent at all: CIDv1 with a two-byte codec
        // varint (0x0129 = dag-json). A record holding it is valid, so it does
        // not fail an import; only turning it into a value does.
        let multiByteCodec: [UInt8] = [0x01, 0xa9, 0x02, 0x12, 0x20] + digest
        let path = try PublicRepositoryPath(collection: "com.example.blah", recordKey: "self")
        let type = Array("com.example.blah".utf8)
        // {"a": link, "$type": "com.example.blah"}, assembled in steps so
        // the type checker has nothing to search.
        var recordBytes: [UInt8] = [0xa2, 0x61, 0x61, 0xd8, 0x2a, 0x58]
        recordBytes.append(UInt8(multiByteCodec.count + 1))
        recordBytes.append(0x00)
        recordBytes.append(contentsOf: multiByteCodec)
        recordBytes.append(0x65)
        recordBytes.append(contentsOf: Array("$type".utf8))
        recordBytes.append(0x70)
        recordBytes.append(contentsOf: type)
        let record = Data(recordBytes)
        try RepositoryMSTValidation.validateRecordBlock(record, for: path, policy: .dataModel)
        #expect(throws: RepositoryMSTValidationError.unsupportedRecordLink) {
            try RepositoryMSTValidation.decodeRecordBlock(record, for: path, policy: .dataModel)
        }
        #expect(throws: RepositoryMSTValidationError.invalidRecordBlock) {
            try RepositoryMSTValidation.validateRecordBlock(record, for: path, policy: .strict)
        }
    }
}
