import Foundation
@testable import Petrel
import Testing

/// Loader for the official syntax vectors vendored under `Vectors/syntax`
/// (see `Vectors/syntax/SOURCE.md` for the upstream commit).
enum SyntaxVectors {
    /// Number of vectors in each upstream file. A file that is missing, truncated
    /// or silently skipped makes `everyFileIsLoadedInFull` fail.
    static let expectedCounts: [String: Int] = [
        "atidentifier_syntax_invalid": 22,
        "atidentifier_syntax_valid": 11,
        "aturi_syntax_invalid": 72,
        "aturi_syntax_valid": 23,
        "cid_syntax_invalid": 10,
        "cid_syntax_valid": 8,
        "datetime_parse_invalid": 7,
        "datetime_syntax_invalid": 45,
        "datetime_syntax_valid": 35,
        "did_syntax_invalid": 18,
        "did_syntax_valid": 24,
        "handle_syntax_invalid": 48,
        "handle_syntax_valid": 71,
        "language_parse_invalid": 4,
        "language_syntax_invalid": 7,
        "language_syntax_valid": 18,
        "nsid_syntax_invalid": 27,
        "nsid_syntax_valid": 25,
        "recordkey_syntax_invalid": 11,
        "recordkey_syntax_valid": 16,
        "tid_syntax_invalid": 9,
        "tid_syntax_valid": 4,
        "uri_syntax_invalid": 12,
        "uri_syntax_valid": 9,
    ]

    enum LoadError: Error {
        case missing(String)
    }

    /// Reads one vector file with the rule the reference suite uses: split on `\n`,
    /// skip empty lines and `#` comments, and never trim — several vectors differ
    /// from a valid value only by leading or trailing whitespace.
    static func load(_ name: String) throws -> [String] {
        guard let url = Bundle.module.url(
            forResource: name, withExtension: "txt", subdirectory: "Vectors/syntax"
        ) else {
            throw LoadError.missing(name)
        }
        let text = try String(decoding: Data(contentsOf: url), as: UTF8.self)
        return text.components(separatedBy: "\n").filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    /// Argument provider for parameterised tests. A load failure yields no cases
    /// here and is reported by `everyFileIsLoadedInFull`.
    static func cases(_ name: String) -> [String] {
        (try? load(name)) ?? []
    }

    /// Decodes a value from a JSON string, the path generated Lexicon models use.
    static func decode<T: Decodable>(_: T.Type, _ string: String) throws -> T {
        let json = try JSONEncoder().encode([string])
        return try JSONDecoder().decode([T].self, from: json)[0]
    }

    /// Encodes a value back to the JSON string it would be written as.
    static func encode<T: Encodable>(_ value: T) throws -> String {
        let json = try JSONEncoder().encode([value])
        return try JSONDecoder().decode([String].self, from: json)[0]
    }
}

@Suite("Official atproto syntax vectors")
struct SyntaxVectorTests {
    @Test("all 24 vector files are present and loaded in full")
    func everyFileIsLoadedInFull() throws {
        #expect(SyntaxVectors.expectedCounts.count == 24)
        var total = 0
        for (name, expected) in SyntaxVectors.expectedCounts.sorted(by: { $0.key < $1.key }) {
            let vectors = try SyntaxVectors.load(name)
            #expect(vectors.count == expected, "\(name).txt")
            total += vectors.count
        }
        #expect(total == 536)
    }

    // MARK: - DID

    @Test("did_syntax_valid", arguments: SyntaxVectors.cases("did_syntax_valid"))
    func didValid(_ vector: String) throws {
        #expect(DID.isValidDID(vector))
        #expect(try DID(didString: vector).didString() == vector)
        let decoded = try SyntaxVectors.decode(DID.self, vector)
        #expect(try SyntaxVectors.encode(decoded) == vector)
    }

    @Test("did_syntax_invalid", arguments: SyntaxVectors.cases("did_syntax_invalid"))
    func didInvalid(_ vector: String) {
        #expect(!DID.isValidDID(vector))
        #expect(throws: ATProtocolError.self) { try DID(didString: vector) }
        #expect(throws: (any Error).self) { try SyntaxVectors.decode(DID.self, vector) }
    }

    // MARK: - Handle

    @Test("handle_syntax_valid", arguments: SyntaxVectors.cases("handle_syntax_valid"))
    func handleValid(_ vector: String) throws {
        #expect(Handle.isValidHandle(vector))
        let handle = try Handle(handleString: vector)
        #expect(handle.value == vector.lowercased())
        #expect(handle.wireValue == vector)
        let decoded = try SyntaxVectors.decode(Handle.self, vector)
        #expect(try SyntaxVectors.encode(decoded) == vector)
    }

    @Test("handle_syntax_invalid", arguments: SyntaxVectors.cases("handle_syntax_invalid"))
    func handleInvalid(_ vector: String) {
        #expect(!Handle.isValidHandle(vector))
        #expect(throws: ATProtocolError.self) { try Handle(handleString: vector) }
        #expect(throws: (any Error).self) { try SyntaxVectors.decode(Handle.self, vector) }
    }

    // MARK: - at-identifier

    @Test("atidentifier_syntax_valid", arguments: SyntaxVectors.cases("atidentifier_syntax_valid"))
    func atIdentifierValid(_ vector: String) throws {
        let identifier = try ATIdentifier(string: vector)
        #expect(identifier.wireValue == vector)
        switch identifier {
        case .did: #expect(vector.hasPrefix("did:"))
        case .handle: #expect(!vector.hasPrefix("did:"))
        }
        let decoded = try SyntaxVectors.decode(ATIdentifier.self, vector)
        #expect(try SyntaxVectors.encode(decoded) == vector)
    }

    @Test("atidentifier_syntax_invalid", arguments: SyntaxVectors.cases("atidentifier_syntax_invalid"))
    func atIdentifierInvalid(_ vector: String) {
        #expect(throws: ATProtocolError.self) { try ATIdentifier(string: vector) }
        #expect(throws: (any Error).self) { try SyntaxVectors.decode(ATIdentifier.self, vector) }
    }

    // MARK: - NSID

    @Test("nsid_syntax_valid", arguments: SyntaxVectors.cases("nsid_syntax_valid"))
    func nsidValid(_ vector: String) throws {
        #expect(NSID.isValidNSID(vector))
        #expect(try NSID(nsidString: vector).nsidString() == vector)
        let decoded = try SyntaxVectors.decode(NSID.self, vector)
        #expect(try SyntaxVectors.encode(decoded) == vector)
    }

    @Test("nsid_syntax_invalid", arguments: SyntaxVectors.cases("nsid_syntax_invalid"))
    func nsidInvalid(_ vector: String) {
        #expect(!NSID.isValidNSID(vector))
        #expect(throws: ATProtocolError.self) { try NSID(nsidString: vector) }
        #expect(throws: (any Error).self) { try SyntaxVectors.decode(NSID.self, vector) }
    }

    // MARK: - Record key

    @Test("recordkey_syntax_valid", arguments: SyntaxVectors.cases("recordkey_syntax_valid"))
    func recordKeyValid(_ vector: String) throws {
        #expect(RecordKey.isValidRecordKey(vector))
        #expect(try RecordKey(keyString: vector).value == vector)
        let decoded = try SyntaxVectors.decode(RecordKey.self, vector)
        #expect(try SyntaxVectors.encode(decoded) == vector)
    }

    @Test("recordkey_syntax_invalid", arguments: SyntaxVectors.cases("recordkey_syntax_invalid"))
    func recordKeyInvalid(_ vector: String) {
        #expect(!RecordKey.isValidRecordKey(vector))
        #expect(throws: ATProtocolError.self) { try RecordKey(keyString: vector) }
        #expect(throws: (any Error).self) { try SyntaxVectors.decode(RecordKey.self, vector) }
    }

    // MARK: - TID

    @Test("tid_syntax_valid", arguments: SyntaxVectors.cases("tid_syntax_valid"))
    func tidValid(_ vector: String) throws {
        #expect(TID.isValidTID(vector))
        #expect(TID.isValid(vector))
        let tid = try TID(tidString: vector)
        #expect(tid.toString() == vector)
        #expect(try TID(timestampMicros: tid.timestampMicros, clockID: tid.clockID).toString() == vector)
        let decoded = try SyntaxVectors.decode(TID.self, vector)
        #expect(try SyntaxVectors.encode(decoded) == vector)
    }

    @Test("tid_syntax_invalid", arguments: SyntaxVectors.cases("tid_syntax_invalid"))
    func tidInvalid(_ vector: String) {
        #expect(!TID.isValidTID(vector))
        #expect(!TID.isValid(vector))
        #expect(throws: ATProtocolError.self) { try TID(tidString: vector) }
        #expect(throws: (any Error).self) { try SyntaxVectors.decode(TID.self, vector) }
    }

    // MARK: - AT-URI

    /// Every vector is checked under both grammars: the specification's
    /// restricted syntax alone, and the default that also admits space URIs.
    @Test("aturi_syntax_valid", arguments: SyntaxVectors.cases("aturi_syntax_valid"))
    func atURIValid(_ vector: String) throws {
        #expect(ATProtocolURI.isValidATURI(vector, grammar: .restricted))
        #expect(ATProtocolURI.isValidATURI(vector))
        #expect(try ATProtocolURI(uriString: vector, grammar: .restricted).uriString() == vector)
        let uri = try ATProtocolURI(uriString: vector)
        #expect(uri.uriString() == vector)
        #expect(!uri.isSpace)
        let decoded = try SyntaxVectors.decode(ATProtocolURI.self, vector)
        #expect(try SyntaxVectors.encode(decoded) == vector)
    }

    @Test("aturi_syntax_invalid", arguments: SyntaxVectors.cases("aturi_syntax_invalid"))
    func atURIInvalid(_ vector: String) {
        #expect(!ATProtocolURI.isValidATURI(vector, grammar: .restricted))
        #expect(!ATProtocolURI.isValidATURI(vector))
        #expect(throws: ATProtocolError.self) { try ATProtocolURI(uriString: vector, grammar: .restricted) }
        #expect(throws: ATProtocolError.self) { try ATProtocolURI(uriString: vector) }
        #expect(throws: (any Error).self) { try SyntaxVectors.decode(ATProtocolURI.self, vector) }
    }

    // MARK: - datetime

    @Test("datetime_syntax_valid", arguments: SyntaxVectors.cases("datetime_syntax_valid"))
    func datetimeValid(_ vector: String) throws {
        #expect(ATProtocolDate.isValidDatetime(vector))
        let date = try ATProtocolDate(datetimeString: vector)
        #expect(date.iso8601String == vector)
        #expect(ATProtocolDate(iso8601String: vector) == date)
        let decoded = try SyntaxVectors.decode(ATProtocolDate.self, vector)
        #expect(try SyntaxVectors.encode(decoded) == vector)
        // The canonical form is itself a valid datetime for the same instant (to the millisecond).
        let normalized = try date.normalizedString()
        let reparsed = try ATProtocolDate(datetimeString: normalized)
        #expect(abs(reparsed.date.timeIntervalSince(date.date)) <= 0.0005)
        #expect(try ATProtocolDate.normalizeDatetime(vector) == normalized)
    }

    @Test("datetime_syntax_invalid", arguments: SyntaxVectors.cases("datetime_syntax_invalid"))
    func datetimeSyntaxInvalid(_ vector: String) {
        #expect(!ATProtocolDate.isValidDatetime(vector))
        #expect(ATProtocolDate(iso8601String: vector) == nil)
        #expect(throws: ATProtocolError.self) { try ATProtocolDate(datetimeString: vector) }
        #expect(throws: (any Error).self) { try SyntaxVectors.decode(ATProtocolDate.self, vector) }
    }

    @Test("datetime_parse_invalid", arguments: SyntaxVectors.cases("datetime_parse_invalid"))
    func datetimeParseInvalid(_ vector: String) {
        #expect(!ATProtocolDate.isValidDatetime(vector))
        #expect(ATProtocolDate(iso8601String: vector) == nil)
        #expect(throws: ATProtocolError.self) { try ATProtocolDate(datetimeString: vector) }
        #expect(throws: (any Error).self) { try SyntaxVectors.decode(ATProtocolDate.self, vector) }
    }

    // MARK: - language

    @Test("language_syntax_valid", arguments: SyntaxVectors.cases("language_syntax_valid"))
    func languageValid(_ vector: String) throws {
        #expect(LanguageTag.isValid(vector))
        #expect(LanguageTag.isWellFormed(vector))
        #expect(LanguageCodeContainer.isValidLanguageTag(vector))
        #expect(try LanguageTag(vector).rawValue == vector)
        #expect(try LanguageCodeContainer(validating: vector).languageTag == vector)
        let decoded = try SyntaxVectors.decode(LanguageCodeContainer.self, vector)
        #expect(decoded.tag != nil)
        #expect(try SyntaxVectors.encode(decoded) == vector)
    }

    /// Vectors the validator must reject. Two of them (`JA`, `jaja`) match the
    /// RFC 5646 §2.1 grammar and are rejected only by the stricter rule the
    /// vector suite adds (lowercase 2–3 letter primary subtag); record decoding
    /// applies the grammar alone, as the reference implementation does.
    @Test("language_syntax_invalid", arguments: SyntaxVectors.cases("language_syntax_invalid"))
    func languageSyntaxInvalid(_ vector: String) {
        #expect(!LanguageTag.isValid(vector))
        #expect(!LanguageCodeContainer.isValidLanguageTag(vector))
        #expect(throws: ATProtocolError.self) { try LanguageTag(vector) }
        #expect(throws: ATProtocolError.self) { try LanguageCodeContainer(validating: vector) }

        let grammarOnlyExceptions: Set<String> = ["JA", "jaja"]
        if grammarOnlyExceptions.contains(vector) {
            #expect(LanguageTag.isWellFormed(vector))
        } else {
            #expect(!LanguageTag.isWellFormed(vector))
            #expect(throws: (any Error).self) { try SyntaxVectors.decode(LanguageCodeContainer.self, vector) }
        }
    }

    /// Well-formed tags that are not valid because a variant or extension
    /// singleton repeats: the validator rejects them, while a record carrying one
    /// still decodes (the specification says clients ignore such tags) and
    /// reports no parsed tag.
    @Test("language_parse_invalid", arguments: SyntaxVectors.cases("language_parse_invalid"))
    func languageParseInvalid(_ vector: String) throws {
        #expect(!LanguageTag.isValid(vector))
        #expect(!LanguageCodeContainer.isValidLanguageTag(vector))
        #expect(throws: ATProtocolError.self) { try LanguageTag(vector) }
        #expect(throws: ATProtocolError.self) { try LanguageCodeContainer(validating: vector) }

        #expect(LanguageTag.isWellFormed(vector))
        let decoded = try SyntaxVectors.decode(LanguageCodeContainer.self, vector)
        #expect(decoded.tag == nil)
        #expect(try SyntaxVectors.encode(decoded) == vector)
    }

    // MARK: - uri

    @Test("uri_syntax_valid", arguments: SyntaxVectors.cases("uri_syntax_valid"))
    func uriValid(_ vector: String) throws {
        #expect(URI.isValidURI(vector))
        let uri = try URI(validating: vector)
        #expect(uri.isValid())
        #expect(uri.uriString() == vector)
        #expect(URI(vector) != nil)
        #expect(URI(uriString: vector).isValid())
        let decoded = try SyntaxVectors.decode(URI.self, vector)
        #expect(decoded.isValid())
        #expect(decoded.uriString() == vector)
        #expect(try SyntaxVectors.encode(decoded) == vector)
    }

    @Test("uri_syntax_invalid", arguments: SyntaxVectors.cases("uri_syntax_invalid"))
    func uriInvalid(_ vector: String) {
        #expect(!URI.isValidURI(vector))
        #expect(throws: ATProtocolError.self) { try URI(validating: vector) }
        #expect(URI(vector) == nil)
        #expect(throws: (any Error).self) { try SyntaxVectors.decode(URI.self, vector) }

        // The non-validating initialiser keeps the string as given, reports it
        // invalid, and refuses to encode it — it is never replaced by a placeholder.
        let unchecked = URI(uriString: vector)
        #expect(!unchecked.isValid())
        #expect(unchecked.uriString() == vector)
        #expect(throws: (any Error).self) { try SyntaxVectors.encode(unchecked) }
    }

    // MARK: - cid

    @Test("cid_syntax_valid", arguments: SyntaxVectors.cases("cid_syntax_valid"))
    func cidValid(_ vector: String) throws {
        #expect(CIDSyntax.isValid(vector))
        try CIDSyntax.validate(vector)
    }

    @Test("cid_syntax_invalid", arguments: SyntaxVectors.cases("cid_syntax_invalid"))
    func cidInvalid(_ vector: String) {
        #expect(!CIDSyntax.isValid(vector))
        #expect(throws: ATProtocolError.self) { try CIDSyntax.validate(vector) }
    }
}
