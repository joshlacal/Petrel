import Foundation
import Petrel
@testable import PetrelLexicon
import Testing

/// Runs every line of the official `atproto-interop-tests/syntax` files
/// through the Lexicon string-format validators.
@Suite("String formats: official syntax vectors")
struct StringFormatVectorTests {
    /// format, file stem, expected number of valid lines, expected number of invalid lines.
    static let files: [(format: LexStringFormat, stem: String, valid: Int, invalid: Int)] = [
        (.atIdentifier, "atidentifier", 11, 22),
        (.atURI, "aturi", 23, 72),
        (.cid, "cid", 8, 10),
        (.datetime, "datetime", 35, 45),
        (.did, "did", 24, 18),
        (.handle, "handle", 71, 48),
        (.nsid, "nsid", 25, 27),
        (.recordKey, "recordkey", 16, 11),
        (.tid, "tid", 4, 9),
        (.uri, "uri", 9, 12),
        (.language, "language", 18, 7),
    ]

    @Test("every standard format has a vector file")
    func everyFormatIsCovered() {
        #expect(Set(Self.files.map(\.format)) == Set(LexStringFormat.standard))
        #expect(LexStringFormat.standard.count == 11)
    }

    @Test("*_syntax_valid.txt: every line is accepted")
    func validLinesAreAccepted() throws {
        for file in Self.files {
            let lines = try Vectors.lines("syntax/\(file.stem)_syntax_valid.txt")
            #expect(lines.count == file.valid, "\(file.stem)_syntax_valid.txt: expected \(file.valid) data lines, found \(lines.count)")
            for line in lines {
                #expect(file.format.isValid(line), "\(file.stem)_syntax_valid.txt: rejected \"\(line.prefix(120))\"")
            }
        }
    }

    @Test("*_syntax_invalid.txt: every line is rejected")
    func invalidLinesAreRejected() throws {
        for file in Self.files {
            let lines = try Vectors.lines("syntax/\(file.stem)_syntax_invalid.txt")
            #expect(lines.count == file.invalid, "\(file.stem)_syntax_invalid.txt: expected \(file.invalid) data lines, found \(lines.count)")
            for line in lines {
                #expect(!file.format.isValid(line), "\(file.stem)_syntax_invalid.txt: accepted \"\(line.prefix(120))\"")
            }
        }
    }

    @Test("datetime_parse_invalid.txt: syntactically plausible but impossible datetimes are rejected")
    func impossibleDatetimesAreRejected() throws {
        let lines = try Vectors.lines("syntax/datetime_parse_invalid.txt")
        #expect(lines.count == 7)
        for line in lines {
            #expect(!LexStringFormat.datetime.isValid(line), "datetime_parse_invalid.txt: accepted \"\(line)\"")
        }
    }

    @Test("language_parse_invalid.txt: well-formed tags pass the Lexicon format")
    func wellFormedButNotValidLanguageTagsPass() throws {
        // These repeat a variant or an extension singleton. RFC 5646 calls
        // them "well-formed" but not "valid"; the Lexicon specification only
        // requires well-formedness, and @atproto/syntax's isValidLanguage
        // accepts them for the same reason.
        let lines = try Vectors.lines("syntax/language_parse_invalid.txt")
        #expect(lines.count == 4)
        for line in lines {
            #expect(LexStringFormat.language.isValid(line), "language_parse_invalid.txt: rejected well-formed \"\(line)\"")
        }
    }

    @Test("an unknown format places no constraint on the string")
    func unknownFormatAcceptsAnything() {
        let format = LexStringFormat(rawValue: "space-ref")
        #expect(!format.isStandard)
        #expect(format.isValid("anything at all"))
    }

    @Test("uri: the 8 KiB limit is exact")
    func uriLengthLimit() {
        let prefix = "https://example.com/"
        let atLimit = prefix + String(repeating: "x", count: 8192 - prefix.utf8.count)
        #expect(atLimit.utf8.count == 8192)
        #expect(LexStringFormat.uri.isValid(atLimit))
        #expect(!LexStringFormat.uri.isValid(atLimit + "x"))
    }

    @Test("datetime: calendar and range edges")
    func datetimeEdges() {
        #expect(LexStringFormat.datetime.isValid("2024-02-29T00:00:00Z"))
        #expect(!LexStringFormat.datetime.isValid("2023-02-29T00:00:00Z"))
        #expect(!LexStringFormat.datetime.isValid("2024-04-31T00:00:00Z"))
        #expect(LexStringFormat.datetime.isValid("9999-12-31T23:59:59Z"))
        #expect(!LexStringFormat.datetime.isValid("9999-12-31T23:59:59-00:01"))
        #expect(LexStringFormat.datetime.isValid("0000-01-01T01:00:00+01:00"))
        #expect(!LexStringFormat.datetime.isValid("0000-01-01T00:59:59+01:00"))
    }

    /// `LexStringFormat.isValid` runs the spec-exact rule and then Petrel's
    /// own syntax type. That is only sound while the Petrel type accepts
    /// everything the specification accepts, which this test pins against
    /// every `*_syntax_valid.txt` line.
    ///
    /// The other direction is not pinned: where a Petrel type is more lenient
    /// than the specification (on the base this was written against,
    /// `ATProtocolURI` accepts trailing slashes and empty path segments), the
    /// spec-exact rule in front of it rejects the input, which
    /// `invalidLinesAreRejected` proves line by line.
    @Test("Petrel syntax types accept every spec-valid vector, so delegating to them never rejects valid data")
    func petrelSyntaxTypesAcceptValidVectors() throws {
        let checks: [(stem: String, accepts: @Sendable (String) -> Bool)] = [
            ("atidentifier", { (try? ATIdentifier(string: $0)) != nil }),
            ("aturi", { (try? ATProtocolURI(uriString: $0)) != nil }),
            ("did", { (try? DID(didString: $0)) != nil }),
            ("handle", { (try? Handle(handleString: $0)) != nil }),
            ("nsid", { (try? NSID(nsidString: $0)) != nil }),
            ("recordkey", { (try? RecordKey(keyString: $0)) != nil }),
            ("tid", { (try? TID(tidString: $0)) != nil }),
        ]
        for check in checks {
            let lines = try Vectors.lines("syntax/\(check.stem)_syntax_valid.txt")
            #expect(!lines.isEmpty)
            for line in lines {
                #expect(check.accepts(line), "Petrel's \(check.stem) type rejects the spec-valid \"\(line.prefix(80))\"")
            }
        }
    }
}
