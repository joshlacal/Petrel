import Foundation
@testable import PetrelLexicon
import Testing

extension Vectors {
    /// A catalog holding every document under `lexicon/catalog/`.
    static func catalog() throws -> LexiconCatalog {
        var catalog = LexiconCatalog()
        for file in try jsonFiles(in: "lexicon/catalog") {
            try catalog.add(json: data(file))
        }
        return catalog
    }
}

/// Runs every case of the official `atproto-interop-tests/lexicon` files.
@Suite("Lexicon: official interop vectors")
struct LexiconVectorTests {
    // MARK: Schemas

    @Test("lexicon-valid.json: every document parses and passes schema validation")
    func validLexiconsLoad() throws {
        let cases = try Vectors.cases("lexicon/lexicon-valid.json")
        #expect(cases.count == 3)
        for vector in cases {
            let name = try #require(vector["name"]?.string)
            let lexicon = try #require(vector["lexicon"])
            #expect(throws: Never.self, "lexicon-valid: \(name)") {
                let doc = try LexiconDoc(json: lexicon.source)
                // Encoding and decoding again yields the same model.
                #expect(try LexiconDoc(json: doc.jsonData()) == doc, "round trip: \(name)")
            }
        }
    }

    /// The reason each invalid document must be rejected for.
    static let invalidLexiconReasons: [String: LexiconSchemaError.Code] = [
        "invalid lexicon field": .unsupportedLexiconVersion,
        "invalid id field": .invalidNSID,
        "invalid NSID": .invalidNSID,
        "defined unknown": .typeNotAllowed,
        "defined ref": .typeNotAllowed,
        "non-main primary": .primaryNotMain,
        "record missing type object": .missingField,
    ]

    @Test("lexicon-invalid.json: every document is rejected, for the stated reason")
    func invalidLexiconsAreRejected() throws {
        let cases = try Vectors.cases("lexicon/lexicon-invalid.json")
        #expect(cases.count == 7)
        for vector in cases {
            let name = try #require(vector["name"]?.string)
            let lexicon = try #require(vector["lexicon"])
            let expected = try #require(Self.invalidLexiconReasons[name], "no expected reason recorded for vector: \(name)")
            do {
                _ = try LexiconDoc(json: lexicon.source)
                Issue.record("lexicon-invalid vector was accepted: \(name)")
            } catch let error as LexiconSchemaError {
                #expect(error.code == expected, "lexicon-invalid: \(name) rejected as \(error)")
            }
            // The catalog applies the same checks.
            var catalog = LexiconCatalog()
            #expect(throws: LexiconSchemaError.self, "lexicon-invalid via catalog: \(name)") {
                try catalog.add(json: lexicon.source)
            }
            #expect(catalog.nsids.isEmpty)
        }
    }

    @Test("lexicon/catalog: all five documents load into a catalog")
    func catalogLoads() throws {
        let files = try Vectors.jsonFiles(in: "lexicon/catalog")
        #expect(files.count == 5)
        let catalog = try Vectors.catalog()
        #expect(catalog.nsids == [
            "example.lexicon.permissionset",
            "example.lexicon.procedure",
            "example.lexicon.query",
            "example.lexicon.record",
            "example.lexicon.subscription",
        ])
        #expect(catalog.definition("example.lexicon.record")?.typeName == "record")
        #expect(catalog.definition("example.lexicon.record#main")?.typeName == "record")
        #expect(catalog.definition("example.lexicon.record#demoToken")?.typeName == "token")
        #expect(catalog.definition("#yo", relativeTo: "example.lexicon.subscription")?.typeName == "object")
        #expect(catalog.definition("example.lexicon.query")?.typeName == "query")
        #expect(catalog.definition("example.lexicon.procedure")?.typeName == "procedure")
        #expect(catalog.definition("example.lexicon.subscription")?.typeName == "subscription")
        #expect(catalog.definition("example.lexicon.permissionset")?.typeName == "permission-set")
        #expect(catalog.definition("example.lexicon.missing") == nil)

        // The only reference the five files do not satisfy among themselves
        // is the procedure's ref into app.bsky.actor.defs.
        let problems = catalog.referenceProblems()
        #expect(problems.map(\.code) == [.unresolvedReference])
        #expect(problems.first?.nsid == "example.lexicon.procedure")
        #expect(problems.first?.path == "/defs/main/input/schema/properties/preferences/ref")
    }

    @Test("lexicon/catalog: every document survives a model round trip")
    func catalogDocumentsRoundTrip() throws {
        for file in try Vectors.jsonFiles(in: "lexicon/catalog") {
            let source = try Vectors.data(file)
            let doc = try LexiconDoc(json: source)
            // The catalog files use no field the model drops, so the encoded
            // model is the same data-model value as the source.
            #expect(try doc.lexValue == LexValue(json: source), "model -> JSON differs from source: \(file)")
            let viaCodable = try JSONDecoder().decode(LexiconDoc.self, from: JSONEncoder().encode(doc))
            #expect(viaCodable == doc, "Codable round trip: \(file)")
        }
    }

    @Test("lexicon/catalog: the permission-set parses into grants")
    func catalogPermissionSet() throws {
        let catalog = try Vectors.catalog()
        guard case let .permissionSet(set)? = catalog.definition("example.lexicon.permissionset") else {
            Issue.record("permission-set definition missing")
            return
        }
        #expect(set.title == "Example for Moderation")
        #expect(set.titleLang == ["fr": "Example for Modération"])
        #expect(set.detailLang?.keys.sorted() == ["fr-FR"])
        #expect(set.permissions.count == 6)
        #expect(set.permissions[0].grant == .repo(
            collections: ["com.example.calendar.event", "com.example.calendar.rsvp"],
            actions: ["delete", "create"]
        ))
        #expect(set.permissions[3].grant == .rpc(methods: ["com.example.calendar.listEvents"], inheritAudience: false))
        // `lxm: ["*"]` is a valid schema but not a usable grant: wildcards are
        // not supported inside a permission set, so it must be ignored.
        #expect(set.permissions[4].resource == "rpc")
        #expect(set.permissions[4].grant == nil)
        #expect(set.permissions[5].grant == .rpc(methods: ["com.example.calendar.listEvents"], inheritAudience: true))
    }

    // MARK: Record data

    @Test("record-data-valid.json: every record validates against the catalog")
    func validRecordsValidate() throws {
        let catalog = try Vectors.catalog()
        let cases = try Vectors.cases("lexicon/record-data-valid.json")
        #expect(cases.count == 3)
        for vector in cases {
            let name = try #require(vector["name"]?.string)
            let recordKey = try #require(vector["rkey"]?.string)
            let data = try #require(vector["data"])
            let record = try LexValue.record(json: data.source)
            let collection = try #require(record.type, "record-data-valid: \(name) has no $type")
            #expect(throws: Never.self, "record-data-valid: \(name)") {
                try catalog.validateRecord(record, collection: collection, recordKey: recordKey)
            }
        }
    }

    /// Where, and why, each invalid record must fail: for each vector name,
    /// one complete list of expected issues per vector of that name, in file
    /// order (two vectors share the name "union inner invalid").
    static let invalidRecordReasons: [String: [[(path: String, code: LexiconValidationIssue.Code)]]] = [
        "missing required field": [[("/integer", .missingRequiredProperty)]],
        "invalid boolean field": [[("/boolean", .typeMismatch)]],
        "invalid integer field": [[("/integer", .typeMismatch)]],
        "invalid non-nullable string field": [[("/string", .nullNotAllowed)]],
        "invalid string field": [[("/string", .typeMismatch)]],
        "invalid bytes field": [[("/bytes", .typeMismatch)]],
        "invalid bytes: empty object": [[("/bytes", .typeMismatch)]],
        "invalid bytes: wrong type": [[("/bytes", .typeMismatch)]],
        "invalid cid-link field": [[("/cid-link", .typeMismatch)]],
        "invalid blob field": [[("/blob", .typeMismatch)]],
        "invalid blob: wrong type": [[("/blob", .blobMalformed)]],
        "invalid array": [[("/array", .typeMismatch)]],
        "invalid array element": [[("/array/0", .typeMismatch), ("/array/1", .typeMismatch)]],
        "object wrong data type": [[("/object", .typeMismatch)]],
        "object nested wrong data type": [[("/object/a", .typeMismatch)]],
        "invalid token ref type": [[("/ref", .typeMismatch)]],
        "invalid ref value": [[("/ref", .typeMismatch)]],
        "invalid string format handle": [[("/formats/handle", .stringFormatMismatch)]],
        "invalid string format did": [[("/formats/did", .stringFormatMismatch)]],
        "invalid string format atidentifier": [[("/formats/atidentifier", .stringFormatMismatch)]],
        "invalid string format nsid": [[("/formats/nsid", .stringFormatMismatch)]],
        "invalid string format aturi": [[("/formats/aturi", .stringFormatMismatch)]],
        "invalid string format cid": [[("/formats/cid", .stringFormatMismatch)]],
        "invalid string format datetime": [[("/formats/datetime", .stringFormatMismatch)]],
        "invalid string format language": [[("/formats/language", .stringFormatMismatch)]],
        "invalid string format uri": [[("/formats/uri", .stringFormatMismatch)]],
        "invalid string format tid": [[("/formats/tid", .stringFormatMismatch)]],
        "invalid string format recordkey": [[("/formats/recordkey", .stringFormatMismatch)]],
        "wrong const value": [[("/constInteger", .valueNotConst)]],
        "integer not in enum": [[("/enumInteger", .valueNotInEnum)]],
        "out of integer range": [[("/rangeInteger", .integerTooLarge)]],
        "string too short": [[("/lenString", .stringTooShort)]],
        "string too long": [[("/lenString", .stringTooLong)]],
        "string too short (graphemes)": [[("/graphemeString", .stringTooFewGraphemes)]],
        "string too long (graphemes)": [[("/graphemeString", .stringTooManyGraphemes)]],
        "out of enum string": [[("/enumString", .valueNotInEnum)]],
        "bytes too short": [[("/sizeBytes", .bytesTooShort)]],
        "bytes too long": [[("/sizeBytes", .bytesTooLong)]],
        "array too short": [[("/lenArray", .arrayTooShort)]],
        "array too long": [[("/lenArray", .arrayTooLong)]],
        "blob too large": [[("/sizeBlob/size", .blobTooLarge)]],
        "blob wrong type": [[("/acceptBlob/mimeType", .blobTypeNotAccepted)]],
        "open union wrong data type": [[("/union", .typeMismatch)]],
        "open union missing $type": [[("/union/$type", .missingTypeDiscriminator)]],
        "out of closed union": [[("/closedUnion/$type", .unionVariantNotAllowed)]],
        "union inner invalid": [[("/closedUnion/$type", .unionVariantNotAllowed)], [("/union/a", .typeMismatch)]],
        "unknown wrong type (bool)": [[("/unknown", .typeMismatch)]],
        "unknown wrong type (bytes)": [[("/unknown", .typeMismatch)]],
        "unknown wrong type (blob)": [[("/unknown", .typeMismatch)]],
    ]

    @Test("record-data-invalid.json: every record fails, at the stated path, for the stated reason")
    func invalidRecordsFail() throws {
        let catalog = try Vectors.catalog()
        let cases = try Vectors.cases("lexicon/record-data-invalid.json")
        #expect(cases.count == 50)
        var seen: [String: Int] = [:]
        for vector in cases {
            let name = try #require(vector["name"]?.string)
            let recordKey = try #require(vector["rkey"]?.string)
            let data = try #require(vector["data"])
            let occurrence = seen[name, default: 0]
            seen[name] = occurrence + 1
            let expectations = try #require(Self.invalidRecordReasons[name], "no expectation recorded for vector: \(name)")
            var expected = try #require(
                expectations.indices.contains(occurrence) ? expectations[occurrence] : nil,
                "no expectation recorded for occurrence \(occurrence) of vector: \(name)"
            ).map { "\($0.code.rawValue) at \($0.path)" }

            // Each of these is well-formed data-model JSON; it is the schema
            // that rejects it.
            let record = try LexValue.record(json: data.source)
            let collection = try #require(record.type, "record-data-invalid: \(name) has no $type")
            // Three vectors additionally omit the required `integer`
            // property, which is then reported too.
            if record["integer"] == nil, !expected.contains("missingRequiredProperty at /integer") {
                expected.append("missingRequiredProperty at /integer")
            }
            do {
                try catalog.validateRecord(record, collection: collection, recordKey: recordKey)
                Issue.record("record-data-invalid vector was accepted: \(name)")
            } catch let error as LexiconValidationError {
                // The vector fails for exactly the reason it was written to
                // test, and for nothing else.
                let actual = error.issues.map { "\($0.code.rawValue) at \($0.path)" }
                #expect(actual.sorted() == expected.sorted(), "record-data-invalid: \(name): \(error)")
            }
        }
        // Every recorded expectation was consumed by a vector.
        for (name, expectations) in Self.invalidRecordReasons {
            #expect(seen[name] == expectations.count, "expectation without a matching vector: \(name)")
        }
    }
}
