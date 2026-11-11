import Foundation
import PetrelCore
@testable import PetrelLexicon
import Testing

/// One targeted test per constraint, on small hand-written schemas.
@Suite("Lexicon: constraint enforcement")
struct LexiconConstraintTests {
    /// A catalog with one document, `com.example.test`, whose `main` is an
    /// object with the given properties.
    static func catalog(
        properties: String,
        required: [String] = [],
        nullable: [String] = [],
        extraDefs: String = ""
    ) throws -> LexiconCatalog {
        let requiredJSON = required.map { "\"\($0)\"" }.joined(separator: ",")
        let nullableJSON = nullable.map { "\"\($0)\"" }.joined(separator: ",")
        let json = """
        {"lexicon":1,"id":"com.example.test","defs":{
          "main":{"type":"object","required":[\(requiredJSON)],"nullable":[\(nullableJSON)],"properties":{\(properties)}}
          \(extraDefs.isEmpty ? "" : "," + extraDefs)
        }}
        """
        var catalog = LexiconCatalog()
        try catalog.add(json: Data(json.utf8))
        return catalog
    }

    /// The issues `value` raises against `com.example.test`.
    static func issues(_ catalog: LexiconCatalog, _ value: LexValue, options: LexiconValidationOptions = .standard) -> [LexiconValidationIssue] {
        do {
            try catalog.validate(value, againstDef: "com.example.test", options: options)
            return []
        } catch let error as LexiconValidationError {
            return error.issues
        } catch {
            Issue.record("unexpected error: \(error)")
            return []
        }
    }

    static func codes(_ catalog: LexiconCatalog, _ value: LexValue, options: LexiconValidationOptions = .standard) -> [LexiconValidationIssue.Code] {
        issues(catalog, value, options: options).map(\.code)
    }

    // MARK: Objects

    @Test("required, nullable and absent are three different things")
    func requiredAndNullable() throws {
        let catalog = try Self.catalog(
            properties: #""r":{"type":"integer"},"n":{"type":"string"},"o":{"type":"boolean"}"#,
            required: ["r"],
            nullable: ["n"]
        )
        #expect(Self.codes(catalog, ["r": 1]) == [])
        #expect(Self.codes(catalog, ["r": 1, "n": nil]) == [])
        #expect(Self.codes(catalog, ["r": 1, "n": "x", "o": false]) == [])
        #expect(Self.issues(catalog, [:]) == [
            LexiconValidationIssue(path: "/r", code: .missingRequiredProperty, message: "required property \"r\" is missing"),
        ])
        // null is not "absent": a required, non-nullable property set to null fails.
        #expect(Self.codes(catalog, ["r": nil]) == [.nullNotAllowed])
        #expect(Self.codes(catalog, ["r": 1, "o": nil]) == [.nullNotAllowed])
        // Falsy values are present values.
        #expect(Self.codes(catalog, ["r": 0, "n": "", "o": false]) == [])
    }

    @Test("properties the schema does not define are ignored")
    func extraPropertiesIgnored() throws {
        let catalog = try Self.catalog(properties: #""a":{"type":"integer"}"#)
        #expect(Self.codes(catalog, ["a": 1, "zzz": ["anything": [1, 2, nil]], "$unknown": true]) == [])
    }

    @Test("a non-object where an object is expected is a type mismatch")
    func objectTypeMismatch() throws {
        let catalog = try Self.catalog(properties: #""a":{"type":"integer"}"#)
        for value: LexValue in [1, "x", [1], true, .bytes(Data())] {
            #expect(Self.codes(catalog, value) == [.typeMismatch], "\(value.kind)")
        }
        #expect(Self.codes(catalog, nil) == [.nullNotAllowed])
    }

    @Test("every issue is reported, in a stable order, with JSON-pointer paths")
    func collectsAllIssues() throws {
        let catalog = try Self.catalog(
            properties: #""a":{"type":"integer","maximum":1},"b":{"type":"string","maxLength":1},"c~/d":{"type":"array","items":{"type":"boolean"}}"#,
            required: ["a"]
        )
        let found = Self.issues(catalog, ["a": 5, "b": "xyz", "c~/d": [true, 3]])
        #expect(found.map(\.path) == ["/a", "/b", "/c~0~1d/1"])
        #expect(found.map(\.code) == [.integerTooLarge, .stringTooLong, .typeMismatch])
    }

    @Test("maximumIssues caps the report")
    func issueCap() throws {
        let catalog = try Self.catalog(properties: #""a":{"type":"array","items":{"type":"integer"}}"#)
        let value: LexValue = ["a": .array(Array(repeating: "x", count: 500))]
        #expect(Self.issues(catalog, value).count == 64)
        #expect(Self.issues(catalog, value, options: .init(maximumIssues: 3)).count == 3)
    }

    // MARK: Strings

    @Test("string length is counted in UTF-8 bytes")
    func stringByteLength() throws {
        let catalog = try Self.catalog(properties: #""s":{"type":"string","minLength":3,"maxLength":6}"#)
        #expect(Self.codes(catalog, ["s": "abc"]) == [])
        #expect(Self.codes(catalog, ["s": "ab"]) == [.stringTooShort])
        #expect(Self.codes(catalog, ["s": "abcdef"]) == [])
        #expect(Self.codes(catalog, ["s": "abcdefg"]) == [.stringTooLong])
        // "éé" is 2 characters but 4 bytes; "😀😀" is 2 characters but 8 bytes.
        #expect(Self.codes(catalog, ["s": "éé"]) == [])
        #expect(Self.codes(catalog, ["s": "é"]) == [.stringTooShort])
        #expect(Self.codes(catalog, ["s": "😀😀"]) == [.stringTooLong])
    }

    @Test("grapheme length counts user-perceived characters")
    func stringGraphemeLength() throws {
        let catalog = try Self.catalog(properties: #""s":{"type":"string","minGraphemes":2,"maxGraphemes":3}"#)
        // A family emoji is 7 scalars and 25 bytes but one grapheme.
        let family = "👨‍👩‍👧‍👧"
        #expect(family.unicodeScalars.count == 7)
        #expect(family.utf8.count == 25)
        #expect(Self.codes(catalog, ["s": .string(family)]) == [.stringTooFewGraphemes])
        #expect(Self.codes(catalog, ["s": .string(family + family)]) == [])
        #expect(Self.codes(catalog, ["s": .string(family + family + family + family)]) == [.stringTooManyGraphemes])
        // Combining marks and flags.
        #expect(Self.codes(catalog, ["s": "e\u{301}e\u{301}"]) == [])
        #expect(Self.codes(catalog, ["s": "🇩🇪"]) == [.stringTooFewGraphemes])
    }

    @Test("enum is closed, const is exact, knownValues never rejects")
    func stringEnumConstKnownValues() throws {
        let catalog = try Self.catalog(properties: """
        "e":{"type":"string","enum":["a","b"]},
        "c":{"type":"string","const":"only"},
        "k":{"type":"string","knownValues":["x","y"]}
        """)
        #expect(Self.codes(catalog, ["e": "a", "c": "only", "k": "x"]) == [])
        #expect(Self.codes(catalog, ["e": "c"]) == [.valueNotInEnum])
        #expect(Self.codes(catalog, ["e": "A"]) == [.valueNotInEnum])
        #expect(Self.codes(catalog, ["c": "other"]) == [.valueNotConst])
        #expect(Self.codes(catalog, ["k": "something else entirely"]) == [])
    }

    @Test("every string format is enforced", arguments: [
        ("did", "did:plc:ewvi7nxzyoun6zhxrhs64oiz", "did:plc"),
        ("handle", "alice.example.com", "alice"),
        ("at-identifier", "alice.example.com", "alice@example.com"),
        ("nsid", "com.example.fooBar", "com.example"),
        ("at-uri", "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/com.example.post/3jzfcijpj2z2a", "https://example.com"),
        ("cid", "bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a", "not a cid"),
        ("datetime", "1985-04-12T23:20:50.123Z", "1985-04-12"),
        ("language", "pt-BR", "not-a-language-tag-"),
        ("uri", "https://example.com/a?b#c", "no scheme"),
        ("tid", "3jzfcijpj2z2a", "3jzfcijpj2z2"),
        ("record-key", "self", "a/b"),
    ])
    func stringFormats(format: String, valid: String, invalid: String) throws {
        let catalog = try Self.catalog(properties: #""s":{"type":"string","format":"\#(format)"}"#)
        #expect(Self.codes(catalog, ["s": .string(valid)]) == [], "\(format): \(valid)")
        #expect(Self.codes(catalog, ["s": .string(invalid)]) == [.stringFormatMismatch], "\(format): \(invalid)")
        #expect(Self.codes(catalog, ["s": 1]) == [.typeMismatch])
    }

    // MARK: Integers and booleans

    @Test("integer minimum, maximum, enum and const")
    func integers() throws {
        let catalog = try Self.catalog(properties: """
        "r":{"type":"integer","minimum":-2,"maximum":2},
        "e":{"type":"integer","enum":[1,3]},
        "c":{"type":"integer","const":7}
        """)
        #expect(Self.codes(catalog, ["r": -2, "e": 3, "c": 7]) == [])
        #expect(Self.codes(catalog, ["r": 2]) == [])
        #expect(Self.codes(catalog, ["r": -3]) == [.integerTooSmall])
        #expect(Self.codes(catalog, ["r": 3]) == [.integerTooLarge])
        #expect(Self.codes(catalog, ["e": 2]) == [.valueNotInEnum])
        #expect(Self.codes(catalog, ["c": 8]) == [.valueNotConst])
        #expect(Self.codes(catalog, ["r": "1"]) == [.typeMismatch])
        #expect(Self.codes(catalog, ["r": true]) == [.typeMismatch])
    }

    @Test("boolean const")
    func booleans() throws {
        let catalog = try Self.catalog(properties: #""t":{"type":"boolean","const":true},"b":{"type":"boolean"}"#)
        #expect(Self.codes(catalog, ["t": true, "b": false]) == [])
        #expect(Self.codes(catalog, ["t": false]) == [.valueNotConst])
        #expect(Self.codes(catalog, ["b": 0]) == [.typeMismatch])
        #expect(Self.codes(catalog, ["b": "true"]) == [.typeMismatch])
    }

    // MARK: Bytes, links, arrays

    @Test("bytes length is counted in raw bytes")
    func bytes() throws {
        let catalog = try Self.catalog(properties: #""b":{"type":"bytes","minLength":2,"maxLength":3}"#)
        #expect(Self.codes(catalog, ["b": .bytes(Data([1, 2]))]) == [])
        #expect(Self.codes(catalog, ["b": .bytes(Data([1]))]) == [.bytesTooShort])
        #expect(Self.codes(catalog, ["b": .bytes(Data([1, 2, 3, 4]))]) == [.bytesTooLong])
        #expect(Self.codes(catalog, ["b": "AQI="]) == [.typeMismatch])
    }

    @Test("cid-link requires a link, not a CID string")
    func cidLink() throws {
        let catalog = try Self.catalog(properties: #""l":{"type":"cid-link"}"#)
        let cid = CID.fromDAGCBOR(Data([0xA0]))
        #expect(Self.codes(catalog, ["l": .cidLink(cid)]) == [])
        #expect(Self.codes(catalog, ["l": .string(cid.string)]) == [.typeMismatch])
    }

    @Test("array length and items; nested arrays report element paths")
    func arrays() throws {
        let catalog = try Self.catalog(properties: """
        "a":{"type":"array","minLength":1,"maxLength":2,"items":{"type":"string","maxLength":2}},
        "n":{"type":"array","items":{"type":"array","items":{"type":"integer"}}}
        """)
        #expect(Self.codes(catalog, ["a": ["x"]]) == [])
        #expect(Self.codes(catalog, ["a": []]) == [.arrayTooShort])
        #expect(Self.codes(catalog, ["a": ["x", "y", "z"]]) == [.arrayTooLong])
        #expect(Self.issues(catalog, ["a": ["ok", "too long"]]).map(\.path) == ["/a/1"])
        #expect(Self.codes(catalog, ["a": [nil]]) == [.nullNotAllowed])
        #expect(Self.issues(catalog, ["n": [[1], [2, "x"]]]).map(\.path) == ["/n/1/1"])
    }

    // MARK: Blobs

    private func blob(mime: String, size: Int64, codec: CIDCodec = .raw) -> LexValue {
        let cid = CID(codec: codec, multihash: Multihash.sha256(Data("blob".utf8)))
        return ["$type": "blob", "ref": .cidLink(cid), "mimeType": .string(mime), "size": .integer(size)]
    }

    @Test("blob accept globs and maxSize")
    func blobConstraints() throws {
        let catalog = try Self.catalog(properties: """
        "img":{"type":"blob","accept":["image/*","application/pdf"],"maxSize":100},
        "any":{"type":"blob","accept":["*/*"]},
        "free":{"type":"blob"}
        """)
        #expect(Self.codes(catalog, ["img": blob(mime: "image/png", size: 100)]) == [])
        #expect(Self.codes(catalog, ["img": blob(mime: "IMAGE/JPEG", size: 1)]) == [])
        #expect(Self.codes(catalog, ["img": blob(mime: "application/pdf", size: 1)]) == [])
        #expect(Self.codes(catalog, ["img": blob(mime: "application/pdfx", size: 1)]) == [.blobTypeNotAccepted])
        #expect(Self.codes(catalog, ["img": blob(mime: "imagex/png", size: 1)]) == [.blobTypeNotAccepted])
        #expect(Self.codes(catalog, ["img": blob(mime: "text/plain", size: 1)]) == [.blobTypeNotAccepted])
        #expect(Self.codes(catalog, ["img": blob(mime: "image/png", size: 101)]) == [.blobTooLarge])
        #expect(Self.codes(catalog, ["img": blob(mime: "text/plain", size: 101)]) == [.blobTypeNotAccepted, .blobTooLarge])
        #expect(Self.codes(catalog, ["any": blob(mime: "x-custom/anything", size: 1_000_000)]) == [])
        #expect(Self.codes(catalog, ["free": blob(mime: "x-custom/anything", size: 0)]) == [])
        #expect(Self.codes(catalog, ["free": ["mimeType": "a/b"]]) == [.blobMalformed])
        #expect(Self.codes(catalog, ["free": "blob"]) == [.typeMismatch])
    }

    @Test("legacy {cid, mimeType} blobs are read where a blob is expected, unless disabled")
    func legacyBlobs() throws {
        let catalog = try Self.catalog(properties: #""img":{"type":"blob","accept":["image/*"],"maxSize":10}"#)
        let cid = CID.fromBlob(Data("x".utf8)).string
        let legacy: LexValue = ["img": ["cid": .string(cid), "mimeType": "image/png"]]
        // Size is unknown for a legacy blob, so maxSize can not be checked.
        #expect(Self.codes(catalog, legacy) == [])
        #expect(Self.codes(catalog, legacy, options: .init(allowLegacyBlobs: false)) == [.blobMalformed])
        #expect(Self.codes(catalog, ["img": ["cid": .string(cid), "mimeType": "text/plain"]]) == [.blobTypeNotAccepted])
        #expect(Self.codes(catalog, ["img": ["cid": "nope", "mimeType": "image/png"]]) == [.blobMalformed])
    }

    @Test("requireRawBlobCIDs enforces the blob specification's codec")
    func rawBlobCodec() throws {
        let catalog = try Self.catalog(properties: #""b":{"type":"blob"}"#)
        let cbor = blob(mime: "a/b", size: 1, codec: .dagCBOR)
        #expect(Self.codes(catalog, ["b": cbor]) == [])
        #expect(Self.issues(catalog, ["b": cbor], options: .init(requireRawBlobCIDs: true)).map(\.path) == ["/b/ref"])
        #expect(Self.codes(catalog, ["b": blob(mime: "a/b", size: 1)], options: .init(requireRawBlobCIDs: true)) == [])
    }

    // MARK: unknown, token

    @Test("unknown accepts any plain object and nothing else")
    func unknown() throws {
        let catalog = try Self.catalog(properties: #""u":{"type":"unknown"}"#, nullable: [])
        #expect(Self.codes(catalog, ["u": [:]]) == [])
        #expect(Self.codes(catalog, ["u": ["$type": "com.example.whatever", "x": [1, nil]]]) == [])
        for value: LexValue in [1, "x", true, [1], .bytes(Data([1])), .cidLink(CID.fromDAGCBOR(Data([0xA0]))), blob(mime: "a/b", size: 1)] {
            #expect(Self.codes(catalog, ["u": value]) == [.typeMismatch], "unknown given \(value.kind)")
        }
        #expect(Self.codes(catalog, ["u": nil]) == [.nullNotAllowed])
    }

    @Test("a token is not data")
    func token() throws {
        var catalog = LexiconCatalog()
        try catalog.add(json: Data(#"{"lexicon":1,"id":"com.example.tokens","defs":{"red":{"type":"token"}}}"#.utf8))
        #expect(throws: LexiconValidationError.self) {
            try catalog.validate("com.example.tokens#red", againstDef: "com.example.tokens#red")
        }
        do {
            try catalog.validate(["a": 1], againstDef: "com.example.tokens#red")
        } catch let error as LexiconValidationError {
            #expect(error.first.code == .tokenIsNotData)
        }
    }

    // MARK: refs and unions

    static let refDefs = """
    "leaf":{"type":"object","required":["n"],"properties":{"n":{"type":"integer"}}},
    "other":{"type":"object","properties":{"s":{"type":"string"}}},
    "name":{"type":"string","maxLength":3},
    "list":{"type":"array","items":{"type":"ref","ref":"#leaf"}},
    "tok":{"type":"token"}
    """

    @Test("refs resolve locally and globally, to objects and to non-objects")
    func refs() throws {
        let catalog = try Self.catalog(
            properties: """
            "local":{"type":"ref","ref":"#leaf"},
            "global":{"type":"ref","ref":"com.example.test#leaf"},
            "scalar":{"type":"ref","ref":"#name"},
            "many":{"type":"ref","ref":"#list"}
            """,
            extraDefs: Self.refDefs
        )
        #expect(Self.codes(catalog, ["local": ["n": 1], "global": ["n": 2], "scalar": "abc", "many": [["n": 3]]]) == [])
        #expect(Self.issues(catalog, ["local": [:]]).map(\.path) == ["/local/n"])
        #expect(Self.issues(catalog, ["global": ["n": "x"]]).map(\.path) == ["/global/n"])
        #expect(Self.codes(catalog, ["scalar": "abcd"]) == [.stringTooLong])
        #expect(Self.issues(catalog, ["many": [["n": 1], [:]]]).map(\.path) == ["/many/1/n"])
        // An object reached through a ref does not need a $type.
        #expect(Self.codes(catalog, ["local": ["n": 1, "$type": "com.example.test#leaf"]]) == [])
    }

    @Test("a ref to a Lexicon that is not in the catalog is reported, not ignored")
    func missingRef() throws {
        let catalog = try Self.catalog(properties: #""x":{"type":"ref","ref":"com.example.absent#thing"}"#)
        let found = Self.issues(catalog, ["x": ["a": 1]])
        #expect(found.map(\.code) == [.unresolvedReference])
        #expect(found.first?.path == "/x")
        // Nothing to report when the property is absent.
        #expect(Self.codes(catalog, [:]) == [])
        #expect(catalog.referenceProblems().map(\.code) == [.unresolvedReference])
    }

    @Test("open union: known variants are validated, unknown ones pass, $type is required")
    func openUnion() throws {
        let catalog = try Self.catalog(
            properties: ##""u":{"type":"union","refs":["#leaf","com.example.test#other"]}"##,
            extraDefs: Self.refDefs
        )
        #expect(Self.codes(catalog, ["u": ["$type": "com.example.test#leaf", "n": 1]]) == [])
        #expect(Self.issues(catalog, ["u": ["$type": "com.example.test#leaf"]]).map(\.path) == ["/u/n"])
        #expect(Self.codes(catalog, ["u": ["$type": "com.example.test#other", "s": 1]]) == [.typeMismatch])
        #expect(Self.codes(catalog, ["u": ["$type": "org.future.thing#new", "whatever": true]]) == [])
        #expect(Self.codes(catalog, ["u": ["n": 1]]) == [.missingTypeDiscriminator])
        #expect(Self.codes(catalog, ["u": ["$type": 5, "n": 1]]) == [.missingTypeDiscriminator])
        #expect(Self.codes(catalog, ["u": "com.example.test#leaf"]) == [.typeMismatch])
        // A local "#leaf" is not a valid $type in data: it is always absolute.
        #expect(Self.codes(catalog, ["u": ["$type": "#leaf", "n": "not checked"]]) == [])
    }

    @Test("closed union: only the listed variants are allowed")
    func closedUnion() throws {
        let catalog = try Self.catalog(
            properties: ##""u":{"type":"union","closed":true,"refs":["#leaf"]}"##,
            extraDefs: Self.refDefs
        )
        #expect(Self.codes(catalog, ["u": ["$type": "com.example.test#leaf", "n": 1]]) == [])
        #expect(Self.codes(catalog, ["u": ["$type": "com.example.test#other"]]) == [.unionVariantNotAllowed])
        #expect(Self.codes(catalog, ["u": ["$type": "org.future.thing#new"]]) == [.unionVariantNotAllowed])
        #expect(Self.codes(catalog, ["u": ["$type": "not a reference"]]) == [.unionVariantNotAllowed])
    }

    @Test("union $type: main is written without #main, and both spellings of a ref match")
    func unionMainNormalisation() throws {
        var catalog = LexiconCatalog()
        try catalog.add(json: Data(#"""
        {"lexicon":1,"id":"com.example.thing","defs":{"main":{"type":"object","required":["n"],"properties":{"n":{"type":"integer"}}}}}
        """#.utf8))
        try catalog.add(json: Data(#"""
        {"lexicon":1,"id":"com.example.holder","defs":{"main":{"type":"object","properties":{
          "bare":{"type":"union","closed":true,"refs":["com.example.thing"]},
          "suffixed":{"type":"union","closed":true,"refs":["com.example.thing#main"]}
        }}}}
        """#.utf8))
        func codes(_ value: LexValue) -> [LexiconValidationIssue.Code] {
            do {
                try catalog.validate(value, againstDef: "com.example.holder")
                return []
            } catch let error as LexiconValidationError {
                return error.issues.map(\.code)
            } catch {
                return []
            }
        }
        #expect(codes(["bare": ["$type": "com.example.thing", "n": 1]]) == [])
        #expect(codes(["suffixed": ["$type": "com.example.thing", "n": 1]]) == [])
        #expect(codes(["suffixed": ["$type": "com.example.thing"]]) == [.missingRequiredProperty])
        // The specification forbids "#main" in a $type.
        #expect(codes(["bare": ["$type": "com.example.thing#main", "n": 1]]) == [.invalidTypeDiscriminator])
    }

    @Test("a ref to a record keeps the $type discriminator")
    func refToRecord() throws {
        var catalog = LexiconCatalog()
        try catalog.add(json: Data(#"""
        {"lexicon":1,"id":"com.example.rec","defs":{"main":{"type":"record","key":"tid","record":{"type":"object","required":["n"],"properties":{"n":{"type":"integer"}}}}}}
        """#.utf8))
        try catalog.add(json: Data(#"""
        {"lexicon":1,"id":"com.example.wrap","defs":{"main":{"type":"object","properties":{"r":{"type":"ref","ref":"com.example.rec"}}}}}
        """#.utf8))
        #expect(throws: Never.self) {
            try catalog.validate(["r": ["$type": "com.example.rec", "n": 1]], againstDef: "com.example.wrap")
        }
        #expect(throws: LexiconValidationError(LexiconValidationIssue(
            path: "/r/$type",
            code: .missingTypeDiscriminator,
            message: "must include \"$type\": \"com.example.rec\""
        ))) {
            try catalog.validate(["r": ["n": 1]], againstDef: "com.example.wrap")
        }
    }

    // MARK: Records

    static func recordCatalog(key: String = "tid") throws -> LexiconCatalog {
        var catalog = LexiconCatalog()
        try catalog.add(json: Data(#"""
        {"lexicon":1,"id":"com.example.note","defs":{"main":{"type":"record","key":"\#(key)","record":{
          "type":"object","required":["text"],"properties":{"text":{"type":"string","maxGraphemes":5}}}}}}
        """#.utf8))
        return catalog
    }

    @Test("validateRecord requires an object whose $type is the collection")
    func recordType() throws {
        let catalog = try Self.recordCatalog()
        func codes(_ value: LexValue, collection: String = "com.example.note") -> [LexiconValidationIssue.Code] {
            do {
                try catalog.validateRecord(value, collection: collection)
                return []
            } catch let error as LexiconValidationError {
                return error.issues.map(\.code)
            } catch {
                Issue.record("unexpected error: \(error)")
                return []
            }
        }
        #expect(codes(["$type": "com.example.note", "text": "hi"]) == [])
        #expect(codes(["text": "hi"]) == [.missingTypeDiscriminator])
        #expect(codes(["$type": "com.example.other", "text": "hi"]) == [.invalidTypeDiscriminator])
        #expect(codes(["$type": "com.example.note#main", "text": "hi"]) == [.invalidTypeDiscriminator])
        #expect(codes(["$type": "com.example.note", "text": "too long!"]) == [.stringTooManyGraphemes])
        #expect(codes("not an object") == [.typeMismatch])
        // The collection may be written with an explicit #main; the data may not.
        #expect(codes(["$type": "com.example.note", "text": "hi"], collection: "com.example.note#main") == [])
    }

    @Test("validateRecord distinguishes an unknown Lexicon from invalid data")
    func recordCatalogErrors() throws {
        let catalog = try Self.catalog(properties: #""a":{"type":"integer"}"#)
        #expect(throws: LexiconCatalogError.definitionNotFound("com.example.absent")) {
            try catalog.validateRecord(["$type": "com.example.absent"], collection: "com.example.absent")
        }
        #expect(throws: LexiconCatalogError.definitionTypeMismatch(reference: "com.example.test", expected: ["record"], actual: "object")) {
            try catalog.validateRecord(["$type": "com.example.test"], collection: "com.example.test")
        }
        #expect(throws: LexiconCatalogError.invalidReference("not an nsid")) {
            try catalog.validateRecord([:], collection: "not an nsid")
        }
    }

    @Test("record keys are checked against the key type", arguments: [
        ("tid", "3jzfcijpj2z2a", "self"),
        ("nsid", "com.example.thing", "self"),
        ("any", "anything-goes_1.2:3~", "a/b"),
        ("literal:self", "self", "other"),
    ])
    func recordKeys(key: String, valid: String, invalid: String) throws {
        let catalog = try Self.recordCatalog(key: key)
        let record: LexValue = ["$type": "com.example.note", "text": "hi"]
        #expect(throws: Never.self) { try catalog.validateRecord(record, collection: "com.example.note", recordKey: valid) }
        do {
            try catalog.validateRecord(record, collection: "com.example.note", recordKey: invalid)
            Issue.record("record key \(invalid) accepted for key type \(key)")
        } catch let error as LexiconValidationError {
            #expect(error.issues.map(\.code) == [.recordKeyMismatch])
        }
    }

    @Test("deeply nested data is cut off at the limit, and no depth overflows the stack")
    func depthLimit() throws {
        var catalog = LexiconCatalog()
        try catalog.add(json: Data(##"""
        {"lexicon":1,"id":"com.example.tree","defs":{"main":{"type":"object","properties":{
          "child":{"type":"ref","ref":"#main"},
          "list":{"type":"array","items":{"type":"ref","ref":"#main"}},
          "leaf":{"type":"integer"}}}}}
        """##.utf8))
        func nested(_ depth: Int, leaf: LexValue) -> LexValue {
            var value: LexValue = ["leaf": leaf]
            for level in 0 ..< depth {
                value = level % 2 == 0 ? ["child": value] : ["list": [value]]
            }
            return value
        }
        let deep = nested(300, leaf: "not an integer")
        do {
            try catalog.validate(deep, againstDef: "com.example.tree")
            Issue.record("expected a depth error")
        } catch let error as LexiconValidationError {
            #expect(error.issues.map(\.code) == [.depthLimitExceeded])
        }
        // With the limit raised the walk reaches the bottom, and reports the
        // problem it finds there with its full path.
        do {
            try catalog.validate(deep, againstDef: "com.example.tree", options: .init(maximumDepth: 1000))
            Issue.record("expected the leaf to be rejected")
        } catch let error as LexiconValidationError {
            #expect(error.issues.map(\.code) == [.typeMismatch])
            #expect(error.first.path.hasSuffix("/child/leaf"))
            #expect(error.first.path.split(separator: "/").count == 451)
        }
        #expect(throws: Never.self) {
            try catalog.validate(nested(300, leaf: 1), againstDef: "com.example.tree", options: .init(maximumDepth: 1000))
        }
    }

    @Test("a very long array is validated without queueing every element")
    func longArray() throws {
        let catalog = try Self.catalog(properties: #""a":{"type":"array","items":{"type":"integer","maximum":5}}"#)
        var items = Array(repeating: LexValue.integer(1), count: 200_000)
        #expect(Self.codes(catalog, ["a": .array(items)]) == [])
        items[199_999] = 9
        #expect(Self.issues(catalog, ["a": .array(items)]).map(\.path) == ["/a/199999"])
    }
}
