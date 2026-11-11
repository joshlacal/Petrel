import Foundation
import Petrel
import PetrelCore
@testable import PetrelLexicon
import Testing

@Suite("LexValue: strict parsing and serialization")
struct LexValueTests {
    private func code(_ json: String, options: LexValue.ParseOptions = .standard) -> LexValueError.Code? {
        do {
            _ = try LexValue(jsonString: json, options: options)
            return nil
        } catch let error as LexValueError {
            return error.code
        } catch {
            Issue.record("unexpected error type: \(error)")
            return nil
        }
    }

    // MARK: JSON numbers

    @Test("integers: the full signed 64-bit range parses, one past it does not")
    func integerRange() throws {
        #expect(try LexValue(jsonString: "9223372036854775807") == .integer(.max))
        #expect(try LexValue(jsonString: "-9223372036854775808") == .integer(.min))
        #expect(code("9223372036854775808") == .integerOutOfRange)
        #expect(code("-9223372036854775809") == .integerOutOfRange)
    }

    @Test("numbers: fractions and exponents are accepted only when they are integers")
    func integerLikeNumbers() throws {
        #expect(try LexValue(jsonString: "123.0") == .integer(123))
        #expect(try LexValue(jsonString: "1e3") == .integer(1000))
        #expect(try LexValue(jsonString: "-2.50e1") == .integer(-25))
        #expect(code("123.456") == .floatNotAllowed)
        #expect(code("1e-1") == .floatNotAllowed)
        #expect(code("1e400") == .integerOutOfRange)
        #expect(code("1e30") == .integerOutOfRange)
    }

    @Test("numbers: integrality is decided on the decimal digits, never through a lossy Double")
    func integerLikeNumbersAreExact() throws {
        // Each of these rounds to a whole Double, but none is a whole number.
        for literal in [
            "1.0000000000000001", "1.00000000000000001", "9007199254740990.5", "1e-9999", "-1e-9999",
            "12345678901234567.25e1", "1e-99999999999999999999",
        ] {
            #expect(code(literal) == .floatNotAllowed, "\(literal)")
        }
        // Exact whole numbers in any spelling keep every digit, across the full
        // signed 64-bit range that plain integer syntax accepts.
        let exact: [(String, Int64)] = [
            ("9007199254740993.0", 9_007_199_254_740_993), ("9007199254740993e0", 9_007_199_254_740_993),
            ("0e-9999", 0), ("-0.0", 0), ("0.000e99999999999999999999", 0), ("1.50e1", 15), ("12300e-2", 123),
            ("9.223372036854775807e18", .max), ("-9.223372036854775808e18", .min),
        ]
        for (literal, value) in exact {
            #expect(try LexValue(jsonString: literal) == .integer(value), "\(literal)")
        }
        // Whole, but outside the signed 64-bit range.
        for literal in ["9.223372036854775808e18", "-9.223372036854775809e18", "1e19", "1e99999999999999999999"] {
            #expect(code(literal) == .integerOutOfRange, "\(literal)")
        }
    }

    @Test("numbers: malformed literals are rejected", arguments: ["01", "-", "1.", ".5", "+1", "1e", "0x10", "NaN", "Infinity"])
    func malformedNumbers(literal: String) {
        #expect(code(literal) == .malformedJSON)
    }

    // MARK: JSON structure

    @Test("syntax errors are rejected", arguments: [
        "", "{", "[1,]", "{\"a\":1,}", "{\"a\" 1}", "{a:1}", "[1 2]", "tru", "nul", "\"abc", "{} {}", "'a'",
        "\"\\x\"", "\"\\ud800\"", "\"\\udc00\"", "\"\\ud800\\u0041\"", "\"line\nbreak\"",
    ])
    func malformedJSON(text: String) {
        #expect(code(text) == .malformedJSON)
    }

    @Test("duplicate keys are rejected, with the key's path")
    func duplicateKeys() {
        #expect(throws: LexValueError(.duplicateKey, path: "/a/b", "object repeats the key \"b\"")) {
            try LexValue(jsonString: #"{"a":{"b":1,"b":2}}"#)
        }
    }

    @Test("invalid UTF-8 is rejected instead of repaired")
    func invalidUTF8() {
        let bytes = Data([UInt8(ascii: "\""), 0xC3, 0x28, UInt8(ascii: "\"")])
        #expect(throws: LexValueError.self) { try LexValue(json: bytes) }
    }

    @Test("string escapes decode, including surrogate pairs")
    func stringEscapes() throws {
        let value = try LexValue(jsonString: #""a\"\\\/\b\f\n\r\t\u00e9\ud83d\ude00""#)
        #expect(value == .string("a\"\\/\u{08}\u{0C}\n\r\t\u{E9}\u{1F600}"))
    }

    @Test("nesting beyond the limit is rejected, at the limit it parses")
    func depthLimit() throws {
        let options = LexValue.ParseOptions(maximumDepth: 4)
        let atLimit = String(repeating: "[", count: 4) + String(repeating: "]", count: 4)
        let pastLimit = String(repeating: "[", count: 5) + String(repeating: "]", count: 5)
        #expect(throws: Never.self) { try LexValue(jsonString: atLimit, options: options) }
        #expect(code(pastLimit, options: options) == .depthLimitExceeded)
        let deep = String(repeating: "[", count: 100_000)
        #expect(code(deep) == .depthLimitExceeded)
    }

    @Test("a leading byte-order mark and surrounding whitespace are tolerated")
    func bomAndWhitespace() throws {
        let data = Data([0xEF, 0xBB, 0xBF]) + Data(" \n\t{ \"a\" : [ 1 , 2 ] } \r\n".utf8)
        #expect(try LexValue(json: data) == ["a": [1, 2]])
    }

    // MARK: $type, $link, $bytes, blob

    @Test("$type must be a non-empty string wherever it appears")
    func typeField() throws {
        #expect(code(#"{"$type":null}"#) == .invalidType)
        #expect(code(#"{"$type":1}"#) == .invalidType)
        #expect(code(#"{"$type":""}"#) == .invalidType)
        #expect(code(#"{"a":[{"$type":true}]}"#) == .invalidType)
        #expect(try LexValue(jsonString: #"{"$type":"com.example.thing"}"#).type == "com.example.thing")
    }

    @Test("$link: only {\"$link\": <blessed CID>} is a link")
    func links() throws {
        let cid = "bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a"
        let value = try LexValue(jsonString: #"{"$link":"\#(cid)"}"#)
        #expect(value.cidValue?.string == cid)
        #expect(code(#"{"$link":"\#(cid)","x":1}"#) == .malformedLink)
        #expect(code(#"{"$link":1}"#) == .malformedLink)
        #expect(code(#"{"$link":""}"#) == .invalidCID)
        // Upper-case base32 is not the canonical multibase 'b' encoding.
        #expect(code(#"{"$link":"b\#(cid.dropFirst().uppercased())"}"#) == .invalidCID)
        // CIDv0.
        #expect(code(#"{"$link":"QmbWqxBEKC3P8tqsKc98xmWNzrzDtRLMiMPL8wBuTGsMnR"}"#) == .invalidCID)
    }

    @Test("$link: a CID outside the blessed set is rejected unless allowed")
    func unblessedLinks() throws {
        // CIDv1, dag-pb codec, sha-256: well-formed but not blessed.
        let dagPB = CID(codec: .dagPB, multihash: Multihash.sha256(Data("x".utf8))).string
        #expect(code(#"{"$link":"\#(dagPB)"}"#) == .invalidCID)
        let lenient = LexValue.ParseOptions(requireBlessedCIDs: false)
        #expect(try LexValue(jsonString: #"{"$link":"\#(dagPB)"}"#, options: lenient).cidValue?.codec == .dagPB)
    }

    @Test("$bytes: base64 with optional padding; anything else is rejected")
    func bytes() throws {
        #expect(try LexValue(jsonString: #"{"$bytes":"aGVsbG8="}"#) == .bytes(Data("hello".utf8)))
        #expect(try LexValue(jsonString: #"{"$bytes":"aGVsbG8"}"#) == .bytes(Data("hello".utf8)))
        #expect(try LexValue(jsonString: #"{"$bytes":""}"#) == .bytes(Data()))
        #expect(code(#"{"$bytes":"aGVsbG8=","x":1}"#) == .malformedBytes)
        #expect(code(#"{"$bytes":[1]}"#) == .malformedBytes)
        #expect(code(#"{"$bytes":"a"}"#) == .malformedBytes)
        #expect(code(#"{"$bytes":"aGVs*G8"}"#) == .malformedBytes)
        #expect(code(#"{"$bytes":"aGVsbG8=="}"#) == .malformedBytes)
        // base64url is a different alphabet.
        #expect(code(#"{"$bytes":"-_-_"}"#) == .malformedBytes)
    }

    @Test("blob: the typed shape is enforced; the raw codec is opt-in")
    func blobs() throws {
        let raw = "bafkreiccldh766hwcnuxnf2wh6jgzepf2nlu2lvcllt63eww5p6chi4ity"
        let cbor = "bafyreiclp443lavogvhj3d2ob2cxbfuscni2k5jk7bebjzg7khl3esabwq"
        func blob(ref: String, mime: String = #""image/png""#, size: String = "10") -> String {
            #"{"$type":"blob","ref":{"$link":"\#(ref)"},"mimeType":\#(mime),"size":\#(size)}"#
        }
        #expect(try LexValue(jsonString: blob(ref: raw)).blobRef?.size == 10)
        #expect(code(blob(ref: raw, mime: #""""#)) == .malformedBlob)
        #expect(code(blob(ref: raw, mime: "5")) == .malformedBlob)
        #expect(code(blob(ref: raw, size: "-1")) == .malformedBlob)
        #expect(code(blob(ref: raw, size: #""10""#)) == .malformedBlob)
        #expect(code(#"{"$type":"blob","ref":"\#(raw)","mimeType":"image/png","size":1}"#) == .malformedBlob)

        // The blob spec asks for the raw codec, but the official
        // record-data-valid vector references a dag-cbor CID, so that check
        // is an option rather than the default.
        #expect(try LexValue(jsonString: blob(ref: cbor)).blobRef?.hasRawCodec == false)
        #expect(code(blob(ref: cbor), options: .init(requireRawBlobCIDs: true)) == .malformedBlob)
        #expect(code(blob(ref: raw), options: .init(requireRawBlobCIDs: true)) == nil)
    }

    @Test("record(json:) requires an object at the top level")
    func recordRequiresObject() {
        for text in ["\"blah\"", "1", "[]", "null", "true"] {
            #expect(throws: LexValueError.self, "top-level \(text)") { try LexValue.record(json: Data(text.utf8)) }
        }
        #expect(throws: Never.self) { try LexValue.record(json: Data("{}".utf8)) }
    }

    // MARK: Serialization

    @Test("JSON output is deterministic and escapes control characters")
    func jsonOutput() throws {
        let value: LexValue = ["b": [true, nil, -3], "a": "q\"\\\n\u{01}é😀", "c": .bytes(Data([0xFB, 0xFF])), "d": [:]]
        let text = value.jsonString()
        #expect(text == #"{"a":"q\"\\\n\u0001é😀","b":[true,null,-3],"c":{"$bytes":"+/8"},"d":{}}"#)
        #expect(try LexValue(jsonString: text) == value)
    }

    @Test("Codable: LexValue decodes through JSONDecoder with the same rules")
    func codable() throws {
        let json = Data(#"{"n":1,"s":"x","b":{"$bytes":"aGk"},"l":{"$link":"bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a"},"a":[null,false]}"#.utf8)
        let strict = try LexValue(json: json)
        let decoded = try JSONDecoder().decode(LexValue.self, from: json)
        #expect(decoded == strict)
        let reencoded = try JSONEncoder().encode(decoded)
        #expect(try LexValue(json: reencoded) == strict)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LexValue.self, from: Data(#"{"a":1.5}"#.utf8))
        }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LexValue.self, from: Data(#"{"$type":""}"#.utf8))
        }
    }

    // MARK: DAG-CBOR

    private func cborCode(_ bytes: [UInt8]) -> LexValueError.Code? {
        do {
            _ = try LexValue(dagCBOR: Data(bytes))
            return nil
        } catch let error as LexValueError {
            return error.code
        } catch {
            Issue.record("unexpected error type: \(error)")
            return nil
        }
    }

    @Test("DAG-CBOR: scalars and containers decode")
    func cborDecodes() throws {
        #expect(try LexValue(dagCBOR: Data([0x00])) == 0)
        #expect(try LexValue(dagCBOR: Data([0x18, 0x18])) == 24)
        #expect(try LexValue(dagCBOR: Data([0x20])) == -1)
        #expect(try LexValue(dagCBOR: Data([0x3B, 0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])) == .integer(.min))
        #expect(try LexValue(dagCBOR: Data([0xF5])) == true)
        #expect(try LexValue(dagCBOR: Data([0xF6])) == nil)
        #expect(try LexValue(dagCBOR: Data([0x62, 0x68, 0x69])) == "hi")
        #expect(try LexValue(dagCBOR: Data([0x42, 0x01, 0x02])) == .bytes(Data([1, 2])))
        #expect(try LexValue(dagCBOR: Data([0xA2, 0x61, 0x61, 0x01, 0x62, 0x62, 0x62, 0x80])) == ["a": 1, "bb": []])
    }

    @Test("DAG-CBOR: non-canonical and out-of-model encodings are rejected")
    func cborStrictness() {
        #expect(cborCode([]) == .malformedCBOR)
        #expect(cborCode([0x18, 0x17]) == .malformedCBOR, "over-long integer")
        #expect(cborCode([0x19, 0x00, 0xFF]) == .malformedCBOR, "over-long integer")
        #expect(cborCode([0x1B, 0x80, 0, 0, 0, 0, 0, 0, 0]) == .integerOutOfRange)
        #expect(cborCode([0x3B, 0x80, 0, 0, 0, 0, 0, 0, 0]) == .integerOutOfRange)
        #expect(cborCode([0xFB, 0x3F, 0xF0, 0, 0, 0, 0, 0, 0]) == .floatNotAllowed)
        #expect(cborCode([0xF9, 0x3C, 0x00]) == .floatNotAllowed)
        #expect(cborCode([0xF7]) == .malformedCBOR, "undefined")
        #expect(cborCode([0x9F, 0x01, 0xFF]) == .malformedCBOR, "indefinite array")
        #expect(cborCode([0x5F, 0x41, 0x01, 0xFF]) == .malformedCBOR, "indefinite bytes")
        #expect(cborCode([0x00, 0x00]) == .malformedCBOR, "trailing bytes")
        #expect(cborCode([0x62, 0x68]) == .malformedCBOR, "truncated string")
        #expect(cborCode([0x62, 0xC3, 0x28]) == .malformedCBOR, "invalid UTF-8")
        #expect(cborCode([0xA1, 0x01, 0x02]) == .malformedCBOR, "integer map key")
        #expect(cborCode([0xA2, 0x61, 0x62, 0x01, 0x61, 0x61, 0x02]) == .malformedCBOR, "unsorted keys")
        #expect(cborCode([0xA2, 0x61, 0x61, 0x01, 0x61, 0x61, 0x02]) == .malformedCBOR, "duplicate keys")
        #expect(cborCode([0xA2, 0x62, 0x61, 0x61, 0x01, 0x61, 0x62, 0x02]) == .malformedCBOR, "longer key first")
        #expect(cborCode([0xC1, 0x00]) == .malformedCBOR, "tag other than 42")
        #expect(cborCode([0xD8, 0x2A, 0x61, 0x61]) == .malformedLink, "tag 42 over a text string")
        #expect(cborCode([0xD8, 0x2A, 0x42, 0x01, 0x71]) == .malformedLink, "tag 42 without the 0x00 prefix")
        #expect(cborCode([0xD8, 0x2A, 0x43, 0x00, 0x01, 0x71]) == .invalidCID, "truncated CID")
        #expect(cborCode([0x9A, 0xFF, 0xFF, 0xFF, 0xFF]) == .malformedCBOR, "array length past the input")
    }

    @Test("DAG-CBOR and JSON: nesting at the limit decodes, one level more is refused, and neither overflows the stack")
    func nestingLimits() throws {
        let limit = LexValue.ParseOptions.standard.maximumDepth
        #expect(limit == 128)

        /// [[[ ... 0 ... ]]]
        func cborArrays(_ depth: Int) -> Data {
            Data(Array(repeating: UInt8(0x81), count: depth) + [0x00])
        }
        #expect(throws: Never.self) { try LexValue(dagCBOR: cborArrays(limit)) }
        #expect(cborCode(Array(cborArrays(limit + 1))) == .depthLimitExceeded)
        #expect(cborCode(Array(cborArrays(1_000_000))) == .depthLimitExceeded)

        // {"a":{"a": ... 0 ... }}
        func cborMaps(_ depth: Int) -> Data {
            Data(Array(repeating: [UInt8(0xA1), 0x61, 0x61], count: depth).flatMap { $0 } + [0x00])
        }
        #expect(throws: Never.self) { try LexValue(dagCBOR: cborMaps(limit)) }
        #expect(cborCode(Array(cborMaps(limit + 1))) == .depthLimitExceeded)

        func jsonObjects(_ depth: Int) -> String {
            String(repeating: #"{"a":"#, count: depth) + "0" + String(repeating: "}", count: depth)
        }
        let deepest = try LexValue(jsonString: jsonObjects(limit))
        #expect(code(jsonObjects(limit + 1)) == .depthLimitExceeded)
        // The deepest accepted value survives every recursive operation.
        #expect(try LexValue(jsonString: deepest.jsonString()) == deepest)
        #expect(try LexValue(dagCBOR: deepest.dagCBOR()) == deepest)
        #expect(throws: Never.self) { try deepest.checkDataModel() }
        #expect(deepest.hashValue == deepest.hashValue)
    }

    @Test("DAG-CBOR: $type and blob rules apply, and JSON-only keys are refused")
    func cborDataModelRules() throws {
        // {"$type": ""}
        #expect(cborCode([0xA1, 0x65, 0x24, 0x74, 0x79, 0x70, 0x65, 0x60]) == .invalidType)
        // {"$link": "x"} and {"$bytes": "x"} are JSON spellings, not CBOR ones.
        #expect(cborCode([0xA1, 0x65, 0x24, 0x6C, 0x69, 0x6E, 0x6B, 0x61, 0x78]) == .malformedLink)
        #expect(cborCode([0xA1, 0x66, 0x24, 0x62, 0x79, 0x74, 0x65, 0x73, 0x61, 0x78]) == .malformedBytes)
        // A blob whose size is a string.
        let bad: LexValue = ["$type": "blob", "mimeType": "a/b", "size": "1"]
        #expect(throws: LexValueError.self) { try LexValue(dagCBOR: bad.dagCBOR()) }
    }

    @Test("DAG-CBOR: map keys are written length-first, then bytewise")
    func cborKeyOrder() throws {
        let value: LexValue = ["bb": 1, "a": 2, "c": 3, "aaa": 4]
        let encoded = try value.dagCBOR()
        #expect(Array(encoded) == [0xA4, 0x61, 0x61, 0x02, 0x61, 0x63, 0x03, 0x62, 0x62, 0x62, 0x01, 0x63, 0x61, 0x61, 0x61, 0x04])
        #expect(try LexValue(dagCBOR: encoded) == value)
    }

    @Test("DAG-CBOR: integer widths are minimal across the whole range")
    func cborIntegerWidths() throws {
        let samples: [Int64] = [0, 23, 24, 255, 256, 65535, 65536, 4_294_967_295, 4_294_967_296, .max, -1, -24, -25, -256, -257, .min]
        for sample in samples {
            let encoded = try LexValue.integer(sample).dagCBOR()
            #expect(try LexValue(dagCBOR: encoded) == .integer(sample), "round trip of \(sample)")
        }
        #expect(try Array(LexValue.integer(23).dagCBOR()) == [0x17])
        #expect(try Array(LexValue.integer(24).dagCBOR()) == [0x18, 0x18])
        #expect(try Array(LexValue.integer(-25).dagCBOR()) == [0x38, 0x18])
        #expect(try Array(LexValue.integer(65536).dagCBOR()) == [0x1A, 0x00, 0x01, 0x00, 0x00])
    }

    // MARK: Swift-built values and bridges

    @Test("checkDataModel catches reserved keys and malformed blobs in Swift-built values")
    func checkDataModel() {
        #expect(throws: Never.self) { try (["a": [1, "x", nil]] as LexValue).checkDataModel() }
        #expect(throws: LexValueError.self) { try (["x": ["$link": "abc"]] as LexValue).checkDataModel() }
        #expect(throws: LexValueError.self) { try (["x": ["$bytes": "abc"]] as LexValue).checkDataModel() }
        #expect(throws: LexValueError.self) { try (["$type": ""] as LexValue).checkDataModel() }
        #expect(throws: LexValueError.self) { try (["$type": "blob", "size": 1] as LexValue).checkDataModel() }
    }

    @Test("blob references: construction, legacy form, and collection")
    func blobRefs() throws {
        let cid = CID.fromBlob(Data("image".utf8))
        let blob = try LexBlobRef(ref: cid, mimeType: "image/png", size: 5)
        #expect(blob.value.blobRef == blob)
        #expect(!blob.isLegacy)
        #expect(throws: LexValueError.self) { try LexBlobRef(ref: cid, mimeType: "", size: 5) }
        #expect(throws: LexValueError.self) { try LexBlobRef(ref: cid, mimeType: "image/png", size: -1) }

        let legacy = try #require(LexBlobRef(legacyFields: ["cid": .string(cid.string), "mimeType": "image/png"]))
        #expect(legacy.isLegacy)
        #expect(legacy.size == nil)
        #expect(legacy.value == ["cid": .string(cid.string), "mimeType": "image/png"])
        #expect(LexBlobRef(legacyFields: ["cid": .string(cid.string), "mimeType": "image/png", "size": 1]) == nil)

        let nested: LexValue = ["images": [["image": blob.value], ["image": blob.value]], "avatar": blob.value]
        #expect(nested.blobRefs.count == 3)
    }

    @Test("bridge: a generated Petrel record becomes a strict LexValue")
    func bridgeFromGeneratedRecord() throws {
        let post = AppBskyFeedPost(
            text: "hello",
            tags: ["swift"],
            createdAt: ATProtocolDate(date: Date(timeIntervalSince1970: 1_700_000_000))
        )
        let value = try LexValue(encoding: post)
        #expect(value.type == "app.bsky.feed.post")
        #expect(value["text"] == "hello")
        #expect(value["tags"] == ["swift"])
        #expect(value["createdAt"]?.stringValue?.hasPrefix("2023-11-14T22:13:20") == true)
    }

    @Test("bridge: ATProtocolValueContainer data the data model forbids is caught")
    func bridgeFromValueContainer() throws {
        let good = ATProtocolValueContainer.object(["a": .number(1), "b": .array([.string("x"), .null])])
        #expect(try LexValue(good) == ["a": 1, "b": ["x", nil]])

        // The container happily holds a $type that is not a string.
        let bad = ATProtocolValueContainer.object(["$type": .number(1)])
        #expect(throws: LexValueError.self) { try LexValue(bad) }
    }

    @Test("bridge: a value that can not be encoded reports encodingFailed")
    func bridgeEncodingFailure() {
        #expect(throws: LexValueError.self) { try LexValue(encoding: Double.nan) }
        #expect(throws: LexValueError.self) { try LexValue(encoding: ["a": 1.5]) }
    }
}
