import Foundation
@testable import Petrel
import Testing

// Behaviour the line-based vector files cannot express (line terminators, length
// boundaries, typed errors) and the API around the validators.

/// Characters that must never be accepted before or after an otherwise valid value.
private let strayCharacters: [String] = [
    "\n", "\r", "\r\n", "\u{0B}", "\u{0C}", "\u{85}", "\u{2028}", "\u{2029}", " ", "\t", "\0", "\u{FEFF}",
]

private func decodeJSON<T: Decodable>(_: T.Type, _ string: String) throws -> T {
    try JSONDecoder().decode([T].self, from: JSONEncoder().encode([string]))[0]
}

private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
    try JSONDecoder().decode([String].self, from: JSONEncoder().encode([value]))[0]
}

@Suite("Identifier syntax: whitespace, line terminators and control characters")
struct IdentifierStrayCharacterTests {
    /// One valid value per format, with the validator and the `Decodable` path
    /// (the one generated Lexicon models use) for it.
    struct Format: Sendable, CustomTestStringConvertible {
        let name: String
        let valid: String
        let isValid: @Sendable (String) -> Bool
        let decodes: @Sendable (String) -> Bool

        var testDescription: String {
            name
        }
    }

    static let formats: [Format] = [
        Format(
            name: "did", valid: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
            isValid: { DID.isValidDID($0) && (try? DID(didString: $0)) != nil },
            decodes: { (try? decodeJSON(DID.self, $0)) != nil }
        ),
        Format(
            name: "handle", valid: "alice.example.com",
            isValid: { Handle.isValidHandle($0) && (try? Handle(handleString: $0)) != nil },
            decodes: { (try? decodeJSON(Handle.self, $0)) != nil }
        ),
        Format(
            name: "at-identifier (did)", valid: "did:web:example.com",
            isValid: { (try? ATIdentifier(string: $0)) != nil },
            decodes: { (try? decodeJSON(ATIdentifier.self, $0)) != nil }
        ),
        Format(
            name: "at-identifier (handle)", valid: "alice.example.com",
            isValid: { (try? ATIdentifier(string: $0)) != nil },
            decodes: { (try? decodeJSON(ATIdentifier.self, $0)) != nil }
        ),
        Format(
            name: "nsid", valid: "app.bsky.feed.post",
            isValid: { NSID.isValidNSID($0) && (try? NSID(nsidString: $0)) != nil },
            decodes: { (try? decodeJSON(NSID.self, $0)) != nil }
        ),
        Format(
            name: "record-key", valid: "self",
            isValid: { RecordKey.isValidRecordKey($0) && (try? RecordKey(keyString: $0)) != nil },
            decodes: { (try? decodeJSON(RecordKey.self, $0)) != nil }
        ),
        Format(
            name: "tid", valid: "3jzfcijpj2z2a",
            isValid: { TID.isValidTID($0) && (try? TID(tidString: $0)) != nil },
            decodes: { (try? decodeJSON(TID.self, $0)) != nil }
        ),
        Format(
            name: "at-uri (authority)", valid: "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz",
            isValid: { ATProtocolURI.isValidATURI($0) && (try? ATProtocolURI(uriString: $0)) != nil },
            decodes: { (try? decodeJSON(ATProtocolURI.self, $0)) != nil }
        ),
        Format(
            name: "at-uri (record)", valid: "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3jzfcijpj2z2a",
            isValid: { ATProtocolURI.isValidATURI($0) && (try? ATProtocolURI(uriString: $0)) != nil },
            decodes: { (try? decodeJSON(ATProtocolURI.self, $0)) != nil }
        ),
        Format(
            name: "at-uri (space record)",
            valid: "at://did:plc:asdf123/space/com.example.group/default/did:plc:user1/com.atproto.feed.post/abc123",
            isValid: { ATProtocolURI.isValidATURI($0) && (try? ATProtocolURI(uriString: $0)) != nil },
            decodes: { (try? decodeJSON(ATProtocolURI.self, $0)) != nil }
        ),
        Format(
            name: "space-ref", valid: "at://did:plc:asdf123/space/com.example.group/default",
            isValid: { (try? SpaceRef(uriString: $0)) != nil },
            decodes: { (try? decodeJSON(SpaceRef.self, $0)) != nil }
        ),
        Format(
            name: "datetime", valid: "1985-04-12T23:20:50.123Z",
            isValid: { ATProtocolDate.isValidDatetime($0) && ATProtocolDate(iso8601String: $0) != nil },
            decodes: { (try? decodeJSON(ATProtocolDate.self, $0)) != nil }
        ),
        Format(
            name: "language", valid: "pt-BR",
            isValid: { LanguageTag.isValid($0) && LanguageTag.isWellFormed($0) },
            decodes: { (try? decodeJSON(LanguageCodeContainer.self, $0)) != nil }
        ),
        Format(
            name: "uri", valid: "https://example.com/path",
            isValid: { URI.isValidURI($0) && (try? URI(validating: $0)) != nil },
            decodes: { (try? decodeJSON(URI.self, $0)) != nil }
        ),
        Format(
            name: "cid", valid: "bafyreidfayvfuwqa7qgahxgn2xrq2xrq2xrq2xrq2xrq2xrq2xrq2xrq2y",
            isValid: { CIDSyntax.isValid($0) },
            decodes: { CIDSyntax.isValid($0) }
        ),
    ]

    @Test("the base value of every format is valid", arguments: formats)
    func baseValueIsValid(_ format: Format) {
        #expect(format.isValid(format.valid))
        #expect(format.decodes(format.valid))
    }

    @Test("no format accepts a trailing stray character", arguments: formats)
    func trailingStrayCharacterIsRejected(_ format: Format) {
        for stray in strayCharacters {
            let candidate = format.valid + stray
            #expect(!format.isValid(candidate), "\(format.name) + \(stray.debugDescription)")
            #expect(!format.decodes(candidate), "\(format.name) + \(stray.debugDescription) via Decodable")
        }
    }

    @Test("no format accepts a leading stray character", arguments: formats)
    func leadingStrayCharacterIsRejected(_ format: Format) {
        for stray in strayCharacters {
            let candidate = stray + format.valid
            #expect(!format.isValid(candidate), "\(stray.debugDescription) + \(format.name)")
            #expect(!format.decodes(candidate), "\(stray.debugDescription) + \(format.name) via Decodable")
        }
    }

    /// A combining mark attaches to the preceding character, so a `Character`-level
    /// check can be fooled where a byte-level one cannot. (The generic `uri` format
    /// is the one exception: it tolerates non-ASCII characters by design.)
    @Test("no ASCII-only format accepts a combining mark", arguments: formats.filter { $0.name != "uri" })
    func combiningMarkIsRejected(_ format: Format) {
        let candidate = format.valid + "\u{301}"
        #expect(!format.isValid(candidate))
        #expect(!format.decodes(candidate))
    }
}

@Suite("Identifier syntax: typed errors")
struct IdentifierTypedErrorTests {
    private func expectError(
        _ matches: (ATProtocolError) -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ body: () throws -> Void
    ) {
        do {
            try body()
            Issue.record("expected an error", sourceLocation: sourceLocation)
        } catch let error as ATProtocolError {
            #expect(matches(error), "unexpected case: \(error)", sourceLocation: sourceLocation)
            #expect(!error.message.isEmpty, sourceLocation: sourceLocation)
            #expect(error.errorDescription == error.message, sourceLocation: sourceLocation)
        } catch {
            Issue.record("expected ATProtocolError, got \(error)", sourceLocation: sourceLocation)
        }
    }

    @Test("each format reports its own error case")
    func eachFormatHasItsOwnCase() {
        expectError({ if case .invalidDID = $0 { true } else { false } }) { _ = try DID(didString: "did:METHOD:val") }
        expectError({ if case .invalidHandle = $0 { true } else { false } }) { _ = try Handle(handleString: "nodots") }
        expectError({ if case .invalidDID = $0 { true } else { false } }) { _ = try ATIdentifier(string: "did:x") }
        expectError({ if case .invalidHandle = $0 { true } else { false } }) { _ = try ATIdentifier(string: "@a.b") }
        expectError({ if case .invalidNSID = $0 { true } else { false } }) { _ = try NSID(nsidString: "com.example") }
        expectError({ if case .invalidRecordKey = $0 { true } else { false } }) { _ = try RecordKey(keyString: "..") }
        expectError({ if case .invalidTID = $0 { true } else { false } }) { _ = try TID(tidString: "zzzzzzzzzzzzz") }
        expectError({ if case .invalidURI = $0 { true } else { false } }) {
            _ = try ATProtocolURI(uriString: "at://did:plc:asdf123/")
        }
        expectError({ if case .invalidURI = $0 { true } else { false } }) { _ = try URI(validating: "example.com") }
        expectError({ if case .invalidDatetime = $0 { true } else { false } }) {
            _ = try ATProtocolDate(datetimeString: "1985-04-12")
        }
        expectError({ if case .invalidLanguage = $0 { true } else { false } }) { _ = try LanguageTag("ja-") }
        expectError({ if case .invalidCID = $0 { true } else { false } }) { try CIDSyntax.validate("noop") }
    }

    @Test("an error message names the reason without echoing an oversized input")
    func errorMessageIsBounded() {
        let huge = "at://did:plc:asdf123/com.atproto.feed.post/" + String(repeating: "o", count: 8200)
        do {
            _ = try ATProtocolURI(uriString: huge)
            Issue.record("expected an error")
        } catch let error as ATProtocolError {
            #expect(error.message.contains("8192"))
            #expect(error.message.count < 300)
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test("decoding a malformed datetime, uri or language reports the coding path")
    func decodingErrorsCarryContext() {
        struct Record: Decodable {
            let createdAt: ATProtocolDate?
            let link: URI?
            let lang: LanguageCodeContainer?
        }
        for json in [
            #"{"createdAt":"1985-04-12T23:20:50.123z"}"#,
            #"{"link":"not a uri"}"#,
            #"{"lang":"ja-"}"#,
        ] {
            do {
                _ = try JSONDecoder().decode(Record.self, from: Data(json.utf8))
                Issue.record("expected \(json) to fail")
            } catch let DecodingError.dataCorrupted(context) {
                #expect(context.codingPath.count == 1)
                #expect(context.underlyingError is ATProtocolError)
            } catch {
                Issue.record("unexpected error \(error)")
            }
        }
    }
}

@Suite("DID")
struct DIDSyntaxTests {
    @Test("length limit is 2048 bytes")
    func lengthBoundary() {
        let atLimit = "did:plc:" + String(repeating: "a", count: 2040)
        #expect(atLimit.utf8.count == 2048)
        #expect(DID.isValidDID(atLimit))
        #expect(!DID.isValidDID(atLimit + "a"))
    }

    @Test("parts round-trip, including empty segments")
    func partsRoundTrip() throws {
        let did = try DID(didString: "did:method::::val")
        #expect(did.method == "method")
        #expect(did.authority == "")
        #expect(did.segments == ["", "", "val"])
        #expect(did.methodSpecificIdentifier == ":::val")
        #expect(did.didString() == "did:method::::val")

        let built = try DID(method: "plc", identifier: "ewvi7nxzyoun6zhxrhs64oiz")
        #expect(built.didString() == "did:plc:ewvi7nxzyoun6zhxrhs64oiz")
        #expect(built == (try DID(didString: "did:plc:ewvi7nxzyoun6zhxrhs64oiz")))
        #expect(throws: ATProtocolError.self) { try DID(method: "PLC", identifier: "x") }
    }

    @Test("DIDs are case-sensitive and never normalized")
    func caseSensitive() throws {
        let upper = try DID(didString: "did:web:Example.COM")
        let lower = try DID(didString: "did:web:example.com")
        #expect(upper != lower)
        #expect(upper.didString() == "did:web:Example.COM")
    }

    @Test("percent-encoding is not validated, as the specification allows")
    func percentEncodingNotValidated() {
        #expect(DID.isValidDID("did:method:val%zz"))
        #expect(!DID.isValidDID("did:method:val%"))
    }

    @Test("atproto supports did:plc and hostname-level did:web only", arguments: [
        ("did:plc:ewvi7nxzyoun6zhxrhs64oiz", DID.AtprotoMethod.plc as DID.AtprotoMethod?),
        ("did:web:example.com", .web),
        ("did:web:sub.example.co.uk", .web),
        ("did:web:localhost", .web),
        ("did:web:localhost%3A8080", .web),
        // Unsupported method: valid DID syntax, not usable for an atproto account.
        ("did:key:zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn6N", nil),
        ("did:method:val", nil),
        // did:plc must be exactly 24 base32 characters.
        ("did:plc:short", nil),
        ("did:plc:ewvi7nxzyoun6zhxrhs64oi1", nil),
        ("did:plc:EWVI7NXZYOUN6ZHXRHS64OIZ", nil),
        // did:web: no path segments, port only on localhost, handle TLD rules.
        ("did:web:example.com:user:alice", nil),
        ("did:web:example.com%3A443", nil),
        ("did:web:example.com%3A443:user", nil),
        ("did:web:localhost%3Aabc", nil),
        ("did:web:localhost:path", nil),
        ("did:web:example.arpa", nil),
        ("did:web:laptop.local", nil),
        ("did:web:example.123", nil),
        ("did:web:127.0.0.1", nil),
        ("did:web:nodots", nil),
    ])
    func atprotoMethods(_ string: String, _ expected: DID.AtprotoMethod?) throws {
        let did = try DID(didString: string)
        #expect(did.atprotoMethod == expected)
        #expect(did.isAtprotoDID == (expected != nil))
        #expect(DID.isValidAtprotoDID(string) == (expected != nil))
    }

    @Test("localhost did:web can be refused outside development")
    func localhostIsOptional() {
        #expect(DID.isValidAtprotoDID("did:web:localhost%3A8080", allowLocalhost: true))
        #expect(!DID.isValidAtprotoDID("did:web:localhost%3A8080", allowLocalhost: false))
        #expect(!DID.isValidAtprotoDID("did:web:localhost", allowLocalhost: false))
        #expect(DID.isValidAtprotoDID("did:web:example.com", allowLocalhost: false))
        #expect(!DID.isValidAtprotoDID("not a did"))
    }
}

@Suite("Handle")
struct HandleSyntaxTests {
    @Test("length limits: 253 bytes overall, 63 per label")
    func lengthBoundaries() {
        let label63 = String(repeating: "a", count: 63)
        #expect(Handle.isValidHandle("\(label63).test"))
        #expect(!Handle.isValidHandle("\(label63)a.test"))

        let atLimit = [label63, label63, label63, String(repeating: "a", count: 56), "test"].joined(separator: ".")
        #expect(atLimit.utf8.count == 253)
        #expect(Handle.isValidHandle(atLimit))
        #expect(!Handle.isValidHandle("a" + atLimit))
    }

    @Test("normalizes to lower case but re-encodes the handle as written")
    func normalizationKeepsWireValue() throws {
        let handle = try Handle(handleString: "Alice.Example.COM")
        #expect(handle.value == "alice.example.com")
        #expect(handle.description == "alice.example.com")
        #expect(handle.wireValue == "Alice.Example.COM")
        #expect(handle == (try Handle(handleString: "alice.example.com")))
        #expect(handle.hashValue == (try Handle(handleString: "alice.example.com")).hashValue)

        let decoded = try decodeJSON(Handle.self, "Alice.Example.COM")
        #expect(try encodeJSON(decoded) == "Alice.Example.COM")
        #expect(try decoded.toCBORValue() as? String == "Alice.Example.COM")

        let identifier = try decodeJSON(ATIdentifier.self, "Alice.Example.COM")
        #expect(identifier.stringValue() == "alice.example.com")
        #expect(try encodeJSON(identifier) == "Alice.Example.COM")
    }

    @Test("Unicode look-alikes of ASCII letters are rejected")
    func unicodeLookalikes() {
        for candidate in ["\u{212A}elvin.com", "ｊohn.test", "jo\u{200D}hn.test", "İstanbul.com", "john.test\u{0}"] {
            #expect(!Handle.isValidHandle(candidate), "\(candidate.debugDescription)")
        }
    }

    @Test("reserved top-level domains are valid syntax but flagged as policy")
    func reservedTLDs() throws {
        for reserved in ["laptop.local", "site.onion", "a.arpa", "x.invalid", "x.localhost", "x.internal", "x.alt", "x.example"] {
            let handle = try Handle(handleString: reserved)
            #expect(handle.hasDisallowedTLD, "\(reserved)")
        }
        #expect(try !Handle(handleString: "dev.test").hasDisallowedTLD)
        // Policy applies to the normalized handle, whatever case it was written in.
        #expect(try Handle(handleString: "SRI-NIC.ARPA").hasDisallowedTLD)
    }

    @Test("the invalid-handle sentinel is typed")
    func sentinel() throws {
        #expect(Handle.invalidSentinel.value == "handle.invalid")
        #expect(Handle.invalidSentinel.value == Handle.invalid)
        #expect(Handle.invalidSentinel.isInvalidSentinel)
        #expect(try Handle(handleString: "HANDLE.INVALID").isInvalidSentinel)
        #expect(try !Handle(handleString: "alice.example.com").isInvalidSentinel)
    }
}

@Suite("NSID")
struct NSIDSyntaxTests {
    @Test("length limits: 317 bytes overall, 63 per segment")
    func lengthBoundaries() {
        let segment63 = String(repeating: "a", count: 63)
        #expect(NSID.isValidNSID("com.\(segment63).foo"))
        #expect(!NSID.isValidNSID("com.\(segment63)a.foo"))
        #expect(NSID.isValidNSID("com.example.\(segment63)"))
        #expect(!NSID.isValidNSID("com.example.\(segment63)a"))

        let atLimit = (["com"] + Array(repeating: segment63, count: 4) + [String(repeating: "a", count: 57)])
            .joined(separator: ".")
        #expect(atLimit.utf8.count == 317)
        #expect(NSID.isValidNSID(atLimit))
        #expect(!NSID.isValidNSID("c" + atLimit))
    }

    @Test("the name segment is letters and digits, starting with a letter")
    func nameSegment() {
        #expect(NSID.isValidNSID("com.example.fooBar2"))
        #expect(!NSID.isValidNSID("com.example.3"))
        #expect(!NSID.isValidNSID("com.example.foo-bar"))
        #expect(!NSID.isValidNSID("com.example.foo.*"))
        #expect(!NSID.isValidNSID("1com.example.foo"))
        #expect(NSID.isValidNSID("com.1example.foo"))
    }

    @Test("splits into authority and name, and can be built from them")
    func parts() throws {
        let nsid = try NSID(nsidString: "app.bsky.feed.getAuthorFeed")
        #expect(nsid.authority == "app.bsky.feed")
        #expect(nsid.name == "getAuthorFeed")
        #expect(nsid.nsidString() == "app.bsky.feed.getAuthorFeed")

        let built = try NSID(authority: "app.bsky.feed", name: "post")
        #expect(built.nsidString() == "app.bsky.feed.post")
        #expect(throws: ATProtocolError.self) { try NSID(authority: "app", name: "post") }
        #expect(throws: ATProtocolError.self) { try NSID(authority: "app.bsky", name: "feed-post") }
    }

    @Test("the authority is case-insensitive, the name is case-sensitive")
    func caseRules() throws {
        let written = try NSID(nsidString: "COM.Example.fooBar")
        let lower = try NSID(nsidString: "com.example.fooBar")
        let otherName = try NSID(nsidString: "com.example.foobar")

        #expect(written.nsidString() == "COM.Example.fooBar")
        #expect(written.normalized.nsidString() == "com.example.fooBar")
        #expect(written.isEqual(to: lower))
        #expect(!lower.isEqual(to: otherName))
        #expect(lower != otherName)
        #expect(lower.hashValue != otherName.hashValue)
    }
}

@Suite("Record key")
struct RecordKeySyntaxTests {
    @Test("length limit is 512 bytes; dot and dot-dot are reserved")
    func boundaries() {
        #expect(RecordKey.isValidRecordKey(String(repeating: "a", count: 512)))
        #expect(!RecordKey.isValidRecordKey(String(repeating: "a", count: 513)))
        #expect(!RecordKey.isValidRecordKey(""))
        #expect(!RecordKey.isValidRecordKey("."))
        #expect(!RecordKey.isValidRecordKey(".."))
        #expect(RecordKey.isValidRecordKey("..."))
        #expect(RecordKey.isValidRecordKey("a.b"))
        #expect(RecordKey.isValidRecordKey("~._:-"))
    }

    @Test("record keys are case-sensitive and stored as written")
    func caseSensitive() throws {
        #expect(try RecordKey(keyString: "Self") != RecordKey(keyString: "self"))
        #expect(try RecordKey(keyString: "Self").value == "Self")
    }
}

@Suite("TID")
struct TIDSyntaxTests {
    @Test("the first character may be any of 234567abcdefghij", arguments: Array("234567abcdefghij"))
    func validFirstCharacters(_ first: Character) throws {
        let string = String(first) + "222222222222"
        #expect(TID.isValidTID(string))
        #expect(try TID(tidString: string).toString() == string)
    }

    @Test("the first character may not be k through z", arguments: Array("klmnopqrstuvwxyz"))
    func invalidFirstCharacters(_ first: Character) {
        let string = String(first) + "222222222222"
        #expect(!TID.isValidTID(string))
        #expect(throws: ATProtocolError.self) { try TID(tidString: string) }
    }

    @Test("decodes the timestamp and clock identifier fields")
    func fields() throws {
        let tid = try TID(tidString: "3jzfcijpj2z2a")
        #expect(tid.timestampMicros == 1_688_137_381_887_007)
        #expect(tid.clockID == 6)
        #expect(abs(tid.date.timeIntervalSince1970 - 1_688_137_381.887007) < 0.001)

        let zero = try TID(tidString: "2222222222222")
        #expect(zero.timestampMicros == 0)
        #expect(zero.clockID == 0)

        let top = try TID(tidString: "3zzzzzzzzzzzz")
        #expect(top.timestampMicros == 2_251_799_813_685_247)
        #expect(top.clockID == 1023)
    }

    @Test("builds from parts and rejects out-of-range parts")
    func fromParts() throws {
        let tid = try TID(timestampMicros: 1_700_000_000_000_000, clockID: 7)
        #expect(tid.toString() == "3ke6kg3wk222b")
        #expect(tid.timestampMicros == 1_700_000_000_000_000)
        #expect(tid.clockID == 7)
        #expect(try TID(tidString: "3ke6kg3wk222b") == tid)

        #expect(throws: ATProtocolError.self) { try TID(timestampMicros: 1 << 53, clockID: 0) }
        #expect(throws: ATProtocolError.self) { try TID(timestampMicros: 0, clockID: 1024) }
        #expect(try TID(timestampMicros: (1 << 53) - 1, clockID: 1023).toString() == "bzzzzzzzzzzzz")
    }

    @Test("order agrees between values and strings")
    func ordering() throws {
        let strings = ["2222222222222", "3jzfcijpj2z2a", "3ke6kg3wk222b", "3zzzzzzzzzzzz", "7777777777777", "bzzzzzzzzzzzz", "j777777777777"]
        let tids = try strings.map { try TID(tidString: $0) }
        #expect(tids.sorted().map { $0.toString() } == strings.sorted())
        #expect(tids.sorted() == tids)
    }
}

@Suite("AT-URI")
struct ATURISyntaxTests {
    @Test("the longest valid parts are accepted; anything over 8192 bytes is rejected")
    func lengthBoundary() {
        let prefix = "at://did:plc:asdf123/com.atproto.feed.post/"
        let longDID = "did:plc:" + String(repeating: "a", count: 2040)
        #expect(ATProtocolURI.isValidATURI("at://\(longDID)/com.atproto.feed.post/" + String(repeating: "o", count: 512)))
        #expect(!ATProtocolURI.isValidATURI(prefix + String(repeating: "o", count: 8192)))
        #expect(!ATProtocolURI.isValidATURI(prefix + String(repeating: "o", count: 513)))
    }

    @Test("a trailing slash or empty segment is rejected and never read as 'absent'", arguments: [
        "at://",
        "at:///",
        "at:///com.example.foo",
        "at://did:plc:abc/",
        "at://did:plc:abc//",
        "at://did:plc:abc/com.example.foo/",
        "at://did:plc:abc//com.example.foo",
        "at://did:plc:abc/com.example.foo//",
        "at://did:plc:abc/com.example.foo/self/",
    ])
    func emptySegments(_ string: String) {
        #expect(!ATProtocolURI.isValidATURI(string))
        #expect(!ATProtocolURI.isValidATURI(string, grammar: .restricted))
        #expect(throws: ATProtocolError.self) { try ATProtocolURI(uriString: string) }
    }

    @Test("query strings and fragments are not part of the Lexicon form", arguments: [
        "at://did:plc:abc?q=1",
        "at://did:plc:abc#frag",
        "at://did:plc:abc/com.example.foo?q=1",
        "at://did:plc:abc/com.example.foo/self#/frag",
        "at://did:plc:abc/com.example.foo/self?q=1",
    ])
    func queryAndFragment(_ string: String) {
        #expect(!ATProtocolURI.isValidATURI(string))
    }

    @Test("parts are exposed as strings and as typed values")
    func typedParts() throws {
        let uri = try ATProtocolURI(uriString: "at://alice.example.com/app.bsky.feed.post/3jzfcijpj2z2a")
        #expect(uri.authority == "alice.example.com")
        #expect(uri.authorityIdentifier == (try ATIdentifier(string: "alice.example.com")))
        #expect(uri.collectionNSID == (try NSID(nsidString: "app.bsky.feed.post")))
        #expect(uri.rkey == (try RecordKey(keyString: "3jzfcijpj2z2a")))
        #expect(uri.authorDID == nil)

        let bare = try ATProtocolURI(uriString: "at://did:plc:abc")
        #expect(bare.collection == nil)
        #expect(bare.collectionNSID == nil)
        #expect(bare.rkey == nil)
        #expect(bare.authorDID == "did:plc:abc")
        if case .did = bare.authorityIdentifier {} else { Issue.record("expected a DID authority") }
    }

    @Test("can be built from typed parts")
    func builder() throws {
        let did = try ATIdentifier(string: "did:plc:ewvi7nxzyoun6zhxrhs64oiz")
        let collection = try NSID(nsidString: "app.bsky.feed.post")
        let key = try RecordKey(keyString: "3jzfcijpj2z2a")

        #expect(try ATProtocolURI(authority: did).uriString() == "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz")
        #expect(
            try ATProtocolURI(authority: did, collection: collection).uriString()
                == "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post"
        )
        #expect(
            try ATProtocolURI(authority: did, collection: collection, recordKey: key).uriString()
                == "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3jzfcijpj2z2a"
        )
        #expect(throws: ATProtocolError.self) { try ATProtocolURI(authority: did, recordKey: key) }
    }

    @Test("normalization lower-cases the handle and the NSID authority, nothing else")
    func normalization() throws {
        let written = try ATProtocolURI(uriString: "at://Alice.Example.COM/COM.Example.fooBar/Self")
        #expect(written.uriString() == "at://Alice.Example.COM/COM.Example.fooBar/Self")
        #expect(!written.isNormalized)

        let normalized = written.normalized()
        #expect(normalized.uriString() == "at://alice.example.com/com.example.fooBar/Self")
        #expect(normalized.isNormalized)
        #expect(normalized.normalized() == normalized)

        // A DID authority is case-sensitive and is left alone.
        let did = try ATProtocolURI(uriString: "at://did:web:Example.COM/com.example.foo/self")
        #expect(did.isNormalized)
        #expect(did.normalized().uriString() == "at://did:web:Example.COM/com.example.foo/self")
    }

    @Test("isEqual distinguishes URIs that differ only in an omitted part")
    func equality() throws {
        let record = try ATProtocolURI(uriString: "at://did:plc:abc/com.example.foo/self")
        let collection = try ATProtocolURI(uriString: "at://did:plc:abc/com.example.foo")
        #expect(!record.isEqual(to: collection))
        #expect(record.isEqual(to: try ATProtocolURI(uriString: "at://did:plc:abc/com.example.foo/self")))
    }
}

@Suite("AT-URI: permissioned-data space grammar")
struct SpaceURISyntaxTests {
    private static let space = "at://did:plc:asdf123/space/com.example.group/default"
    private static let record = space + "/did:plc:user1/com.atproto.feed.post/abc123"

    @Test("a space and a record in a space parse with every part validated")
    func validForms() throws {
        let space = try ATProtocolURI(uriString: Self.space)
        #expect(space.isSpace)
        #expect(space.spaceDID == "did:plc:asdf123")
        #expect(space.spaceType == "com.example.group")
        #expect(space.skey == "default")
        #expect(space.authorDID == nil)
        #expect(space.collection == nil)
        #expect(space.recordKey == nil)
        #expect(space.spaceRef?.uriString() == Self.space)

        let record = try ATProtocolURI(uriString: Self.record)
        #expect(record.isSpace)
        #expect(record.authorDID == "did:plc:user1")
        #expect(record.collection == "com.atproto.feed.post")
        #expect(record.recordKey == "abc123")
        #expect(record.spaceRef?.uriString() == Self.space)
        #expect(record.uriString() == Self.record)
    }

    @Test("the specification grammar alone rejects space URIs")
    func restrictedGrammarRejectsSpaces() {
        for string in [Self.space, Self.record] {
            #expect(ATProtocolURI.isValidATURI(string))
            #expect(!ATProtocolURI.isValidATURI(string, grammar: .restricted))
            #expect(throws: ATProtocolError.self) { try ATProtocolURI(uriString: string, grammar: .restricted) }
        }
    }

    @Test("anything other than the two exact shapes is rejected", arguments: [
        // Marker alone, or missing parts.
        "at://did:plc:x/space",
        "at://did:plc:x/space/",
        "at://did:plc:x/space/com.example.t",
        "at://did:plc:x/space/com.example.t/",
        // A record needs author, collection and key together.
        "at://did:plc:x/space/com.example.t/k/did:plc:user1",
        "at://did:plc:x/space/com.example.t/k/did:plc:user1/com.example.c",
        "at://did:plc:x/space/com.example.t/k/did:plc:user1/com.example.c/r/extra",
        // Authority must be a DID.
        "at://handle.example.com/space/com.example.t/k",
        "at://handle.example.com/space//////",
        // Every part is validated against its own grammar.
        "at://did:plc:x/space/short/k",
        "at://did:plc:x/space/com.example.t/..",
        "at://did:plc:x/space/com.example.t/k/not-a-did/com.example.c/r",
        "at://did:plc:x/space/com.example.t/k/did:plc:user1/not_an_nsid/r",
        "at://did:plc:x/space/com.example.t/k/did:plc:user1/com.example.c/..",
        "at://did:plc:x/space/com.example.t/k/user.example.com/com.example.c/r",
        // Empty segments, whitespace, query, fragment, line terminators.
        "at://did:plc:x/space//k",
        "at://did:plc:x/space/com.example.t//did:plc:user1/com.example.c/r",
        "at://did:plc:x/space/ a b?c=d#frag\n",
        "at://did:plc:x/space/com.example.t/k?c=d",
        "at://did:plc:x/space/com.example.t/k#frag",
        "at://did:plc:x/space/com.example.t/k\n",
        "at://did:plc:x/space/not an nsid/!!/x/y/z/extra/more",
    ])
    func malformedSpaceURIs(_ string: String) {
        #expect(!ATProtocolURI.isValidATURI(string))
        #expect(throws: ATProtocolError.self) { try ATProtocolURI(uriString: string) }
        #expect(throws: (any Error).self) { try decodeJSON(ATProtocolURI.self, string) }
    }

    @Test("normalization applies to the space type and the record collection")
    func normalization() throws {
        let written = try ATProtocolURI(
            uriString: "at://did:plc:asdf123/space/COM.Example.group/Default/did:plc:user1/COM.atproto.feed.post/Abc"
        )
        #expect(
            written.normalized().uriString()
                == "at://did:plc:asdf123/space/com.example.group/Default/did:plc:user1/com.atproto.feed.post/Abc"
        )
    }

    @Test("isEqual distinguishes two spaces under one authority")
    func equality() throws {
        let one = try ATProtocolURI(uriString: "at://did:plc:asdf123/space/com.example.group/one")
        let two = try ATProtocolURI(uriString: "at://did:plc:asdf123/space/com.example.group/two")
        #expect(!one.isEqual(to: two))
    }
}

@Suite("Generic URI")
struct GenericURISyntaxTests {
    @Test("length limit is 8192 bytes")
    func lengthBoundary() throws {
        let atLimit = "https://example.com/" + String(repeating: "x", count: 8192 - 20)
        #expect(atLimit.utf8.count == URI.maximumLength)
        #expect(URI.isValidURI(atLimit))
        #expect(!URI.isValidURI(atLimit + "x"))
        #expect(try decodeJSON(URI.self, atLimit).uriString() == atLimit)
        #expect(throws: (any Error).self) { try decodeJSON(URI.self, atLimit + "x") }
    }

    @Test("any RFC 3986 scheme is accepted, with or without an authority", arguments: [
        "https://example.com",
        "HTTPS://EXAMPLE.COM/",
        "wss://example.com:443/socket",
        "ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
        "dns:example.com",
        "mailto:alice@example.com",
        "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
        "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3jzfcijpj2z2a",
        "file:///etc/hosts",
        "urn:isbn:0451450523",
        "a+b-c.d:rest",
        "https://example.com/caf\u{E9}",
    ])
    func validURIs(_ string: String) throws {
        #expect(URI.isValidURI(string))
        let uri = try decodeJSON(URI.self, string)
        #expect(uri.isValid())
        #expect(uri.uriString() == string)
        #expect(try encodeJSON(uri) == string)
        #expect(uri.asQueryItem(name: "uri")?.value == string)
    }

    @Test("strings that are not URIs are rejected", arguments: [
        "", " ", "example.com", "//example.com", "://example.com", "http:", "http://", "1http://example.com",
        "+http://example.com", "ht tp://example.com", "https://example.com/a b", "https://example.com/a\tb",
        "https://example.com/a\u{A0}b", "https://example.com/\u{7F}", "https://example.com/\u{1}", "héllo://example.com",
    ])
    func invalidURIs(_ string: String) {
        #expect(!URI.isValidURI(string))
        #expect(throws: ATProtocolError.self) { try URI(validating: string) }
        #expect(throws: DecodingError.self) { try decodeJSON(URI.self, string) }
    }

    @Test("components are read from the string without changing it")
    func components() throws {
        let uri = try URI(validating: "https://user@example.com:8443/a%2Fb?q=a%26b#frag")
        #expect(uri.scheme == "https")
        #expect(uri.authority == "example.com")
        #expect(uri.path == "/a%2Fb")
        #expect(uri.query == "q=a%26b")
        #expect(uri.fragment == "frag")
        #expect(!uri.isDID)
        #expect(uri.url?.absoluteString == "https://user@example.com:8443/a%2Fb?q=a%26b#frag")

        let did = try URI(validating: "did:plc:ewvi7nxzyoun6zhxrhs64oiz")
        #expect(did.isDID)
        #expect(did.scheme == "did")
        #expect(did.authority == "plc")
        #expect(did.path == "ewvi7nxzyoun6zhxrhs64oiz")
        #expect(did.url == nil)

        let at = try URI(validating: "at://alice.example.com/app.bsky.feed.post/3jzfcijpj2z2a")
        #expect(at.scheme == "at")
        #expect(at.authority == "alice.example.com")
        #expect(at.path == "/app.bsky.feed.post/3jzfcijpj2z2a")

        let dns = try URI(validating: "dns:example.com")
        #expect(dns.scheme == "dns")
        #expect(dns.authority == "")
        #expect(dns.path == "example.com")

        let ipv6 = try URI(validating: "http://[::1]:8080/x")
        #expect(ipv6.authority == "[::1]")
    }

    @Test("a URI without a host is still sent as a query parameter")
    func hostlessQueryItem() throws {
        for string in ["dns:example.com", "content-type:text/plan", "microsoft.windows.camera:thing", "go://?Mercedes%20Benz"] {
            let uri = try URI(validating: string)
            #expect(uri.asQueryItem(name: "uri") == URLQueryItem(name: "uri", value: string))
        }
    }
}

@Suite("Datetime")
struct DatetimeSyntaxTests {
    @Test("parses to the right instant", arguments: [
        ("1970-01-01T00:00:00Z", 0.0),
        ("1970-01-01T00:00:00.000Z", 0.0),
        ("1985-04-12T23:20:50.123Z", 482_196_050.123),
        ("1985-04-12T23:20:50.123+00:00", 482_196_050.123),
        ("1985-04-12T16:20:50.123-07:00", 482_196_050.123),
        ("1985-04-13T01:05:50.123+01:45", 482_196_050.123),
        ("2024-02-29T12:00:00Z", 1_709_208_000.0),
        ("0001-01-01T00:00:00Z", -62_135_596_800.0),
        ("0000-01-01T00:00:00Z", -62_167_219_200.0),
        ("9999-12-31T23:59:59Z", 253_402_300_799.0),
        ("1969-12-31T23:59:59.5Z", -0.5),
    ])
    func instants(_ string: String, _ expected: Double) throws {
        let date = try ATProtocolDate(datetimeString: string)
        #expect(abs(date.date.timeIntervalSince1970 - expected) < 0.0005)
    }

    @Test("rejects values that look right but name no real instant", arguments: [
        "1985-02-30T00:00:00Z", // 30 February
        "1985-04-31T00:00:00Z", // 31 April
        "2023-02-29T00:00:00Z", // not a leap year
        "1900-02-29T00:00:00Z", // century, not a leap year
        "1985-04-12T24:00:00Z", // hour 24
        "1985-04-12T23:60:00Z", // minute 60
        "1985-04-12T23:59:60Z", // leap second: not accepted
        "1985-04-12T23:20:50+24:00", // offset hour
        "1985-04-12T23:20:50+01:60", // offset minute
        "1985-04-12T23:20:50-00:00", // negative zero
        "9999-12-31T23:59:59-00:01", // year 10000 in UTC
        "0000-01-01T00:00:00+00:01", // year -1 in UTC
    ])
    func semanticallyInvalid(_ string: String) {
        #expect(!ATProtocolDate.isValidDatetime(string))
        #expect(throws: ATProtocolError.self) { try ATProtocolDate(datetimeString: string) }
        #expect(throws: DecodingError.self) { try decodeJSON(ATProtocolDate.self, string) }
    }

    @Test("accepts leap days and offsets that stay inside years 0000-9999", arguments: [
        "2024-02-29T23:59:59Z",
        "2000-02-29T00:00:00Z",
        "0000-01-01T00:00:00-00:01",
        "9999-12-31T23:59:59+00:01",
        "1985-04-12T23:20:50+23:59",
    ])
    func semanticallyValid(_ string: String) {
        #expect(ATProtocolDate.isValidDatetime(string))
    }

    @Test("at most 64 characters")
    func lengthBoundary() {
        let fraction = String(repeating: "1", count: 64 - "1985-04-12T23:20:50.Z".count)
        let atLimit = "1985-04-12T23:20:50.\(fraction)Z"
        #expect(atLimit.count == 64)
        #expect(ATProtocolDate.isValidDatetime(atLimit))
        #expect(!ATProtocolDate.isValidDatetime("1985-04-12T23:20:50.\(fraction)1Z"))
    }

    @Test("a Date is written at millisecond precision in UTC, rounded")
    func formatting() throws {
        #expect(ATProtocolDate(date: Date(timeIntervalSince1970: 0)).iso8601String == "1970-01-01T00:00:00.000Z")
        #expect(
            ATProtocolDate(date: Date(timeIntervalSince1970: 482_196_050.123)).iso8601String
                == "1985-04-12T23:20:50.123Z"
        )
        // 0.301 is not exactly representable; truncation would give .300.
        #expect(
            ATProtocolDate(date: Date(timeIntervalSince1970: 1_700_000_000.301)).iso8601String
                == "2023-11-14T22:13:20.301Z"
        )
        // Rounding carries into the seconds field.
        #expect(
            ATProtocolDate(date: Date(timeIntervalSince1970: 1_700_000_000.9996)).iso8601String
                == "2023-11-14T22:13:21.000Z"
        )
        #expect(ATProtocolDate(date: Date(timeIntervalSince1970: -0.5)).iso8601String == "1969-12-31T23:59:59.500Z")
        #expect(
            ATProtocolDate(date: Date(timeIntervalSince1970: -62_167_219_200)).iso8601String
                == "0000-01-01T00:00:00.000Z"
        )

        let now = ATProtocolDate(date: Date())
        #expect(ATProtocolDate.isValidDatetime(now.iso8601String))
        #expect(try encodeJSON(now) == now.iso8601String)
    }

    @Test("a decoded value re-encodes its wire string, and normalizes on request")
    func wireStringIsKept() throws {
        let decoded = try decodeJSON(ATProtocolDate.self, "1985-04-12T23:20:50.120000+01:00")
        #expect(decoded.iso8601String == "1985-04-12T23:20:50.120000+01:00")
        #expect(try encodeJSON(decoded) == "1985-04-12T23:20:50.120000+01:00")
        #expect(try decoded.normalizedString() == "1985-04-12T22:20:50.120Z")
        #expect(decoded.isRepresentable)
    }

    @Test("a Date outside years 0000-9999 is refused rather than written in another form")
    func outOfRangeDates() {
        let far = Date(timeIntervalSince1970: 253_402_300_800) // 10000-01-01T00:00:00Z
        let ancient = Date(timeIntervalSince1970: -62_167_219_201) // one second before year 0000

        for date in [far, ancient, Date(timeIntervalSince1970: .infinity), Date(timeIntervalSince1970: .nan)] {
            #expect(throws: ATProtocolError.self) { try ATProtocolDate(validating: date) }
            let unchecked = ATProtocolDate(date: date)
            #expect(!unchecked.isRepresentable)
            #expect(!ATProtocolDate.isValidDatetime(unchecked.iso8601String))
            #expect(throws: (any Error).self) { try encodeJSON(unchecked) }
            #expect(throws: ATProtocolError.self) { try unchecked.toCBORValue() }
            #expect(throws: ATProtocolError.self) { try unchecked.normalizedString() }
        }
        #expect(ATProtocolDate(date: far).iso8601String == "+010000-01-01T00:00:00.000Z")
        #expect(ATProtocolDate(date: ancient).iso8601String == "-000001-12-31T23:59:59.000Z")
        #expect(throws: Never.self) { try ATProtocolDate(validating: Date()) }
    }

    @Test("normalizeDatetime converts near-misses to the canonical form", arguments: [
        ("1985-04-12T23:20:50.123Z", "1985-04-12T23:20:50.123Z"),
        ("1985-04-12T23:20:50Z", "1985-04-12T23:20:50.000Z"),
        ("1985-04-12T23:20:50.1235678912345Z", "1985-04-12T23:20:50.124Z"),
        ("1985-04-12T23:20:50.123+07:00", "1985-04-12T16:20:50.123Z"),
        ("1985-04-12T23:20:50.123", "1985-04-12T23:20:50.123Z"), // no timezone: read as UTC
        ("1985-04-12T23:20:50", "1985-04-12T23:20:50.000Z"),
        ("1985-04-12t23:20:50.123z", "1985-04-12T23:20:50.123Z"),
        ("1985-04-12 23:20:50.123Z", "1985-04-12T23:20:50.123Z"),
        ("1985-04-12_23:20:50.123Z", "1985-04-12T23:20:50.123Z"),
        ("1985-04-12T23:20:50.123-00:00", "1985-04-12T23:20:50.123Z"),
        ("1985-04-12T23:20:50.123+0000", "1985-04-12T23:20:50.123Z"),
        ("1985-04-12T23:20:50.123+0700", "1985-04-12T16:20:50.123Z"),
        ("1985-04-12T23:20:50.123+00", "1985-04-12T23:20:50.123Z"),
        ("1985-04-12T23:20Z", "1985-04-12T23:20:00.000Z"),
        ("1985-04-12", "1985-04-12T00:00:00.000Z"),
        ("  1985-04-12T23:20:50.123Z\n", "1985-04-12T23:20:50.123Z"),
    ])
    func normalize(_ input: String, _ expected: String) throws {
        let normalized = try ATProtocolDate.normalizeDatetime(input)
        #expect(normalized == expected)
        #expect(ATProtocolDate.isValidDatetime(normalized))
        #expect(ATProtocolDate.normalizeDatetimeAlways(input) == expected)
    }

    @Test("normalizeDatetime still refuses what cannot be read", arguments: [
        "", "yesterday", "1985-13-12T23:20:50Z", "1985-02-30", "1985-04-12T25:00:00Z", "12/04/1985",
        "1985-04-12T23:20:50.123Z trailing", "0000-01-01T00:00:00+01:00",
    ])
    func normalizeRejects(_ input: String) {
        #expect(throws: ATProtocolError.self) { try ATProtocolDate.normalizeDatetime(input) }
        #expect(ATProtocolDate.normalizeDatetimeAlways(input) == "1970-01-01T00:00:00.000Z")
    }
}

@Suite("Language tag")
struct LanguageTagSyntaxTests {
    @Test("parses subtags")
    func subtags() throws {
        let tag = try LanguageTag("hy-Latn-IT-arevela")
        #expect(tag.language == "hy")
        #expect(tag.script == "Latn")
        #expect(tag.region == "IT")
        #expect(tag.variants == ["arevela"])
        #expect(tag.extensions.isEmpty)
        #expect(tag.privateUse == nil)
        #expect(!tag.isGrandfathered)
        #expect(tag.description == "hy-Latn-IT-arevela")

        let full = try LanguageTag("zh-cmn-Hans-CN-u-co-pinyin-t-en-x-one-two")
        #expect(full.language == "zh")
        #expect(full.extendedLanguages == ["cmn"])
        #expect(full.script == "Hans")
        #expect(full.region == "CN")
        #expect(full.extensions == ["u-co-pinyin", "t-en"])
        #expect(full.privateUse == "x-one-two")

        let numeric = try LanguageTag("es-419")
        #expect(numeric.region == "419")

        let variants = try LanguageTag("sl-rozaj-biske-1994")
        #expect(variants.variants == ["rozaj", "biske", "1994"])

        let grandfathered = try LanguageTag("i-klingon")
        #expect(grandfathered.isGrandfathered)
        #expect(grandfathered.language == nil)

        let privateOnly = try LanguageTag("x-whatever")
        #expect(privateOnly.language == nil)
        #expect(privateOnly.privateUse == "x-whatever")
    }

    @Test("ill-formed tags are rejected at both levels", arguments: [
        "", "-", "en-", "-en", "en--US", "en_US", "e", "1", "12", "en-toolongsubtag", "en-US-", "en-a", "en-x",
        "x", "x-", "en-Latn-Latn", "en-US-GB", "de-419-DE", "en-abcd-efgh", "not a language", "en US",
        "en-u", "en-u-x-a",
    ])
    func illFormed(_ string: String) {
        #expect(!LanguageTag.isWellFormed(string))
        #expect(!LanguageTag.isValid(string))
        #expect(throws: ATProtocolError.self) { try LanguageTag(string) }
        #expect(throws: DecodingError.self) { try decodeJSON(LanguageCodeContainer.self, string) }
    }

    @Test("well-formed is the grammar; valid adds the primary-subtag and no-repeat rules", arguments: [
        "JA", "En-us", "jaja", "abcde", "de-DE-1901-1901", "en-a-foo-A-bar",
    ])
    func wellFormedButNotValid(_ string: String) throws {
        #expect(LanguageTag.isWellFormed(string))
        #expect(!LanguageTag.isValid(string))
        #expect(throws: ATProtocolError.self) { try LanguageTag(string) }
        // A record carrying such a tag still decodes and round-trips; it just has no parsed tag.
        let decoded = try decodeJSON(LanguageCodeContainer.self, string)
        #expect(decoded.tag == nil)
        #expect(decoded.isWellFormed)
        #expect(try encodeJSON(decoded) == string)
    }

    @Test("everything after the primary subtag is case-insensitive", arguments: [
        "en-us", "en-LATN-us", "zh-HANT", "I-DEFAULT", "sgn-be-nl", "en-U-CO-PHONEBK", "X-FR-ch",
    ])
    func caseInsensitive(_ string: String) {
        #expect(LanguageTag.isWellFormed(string))
        #expect(LanguageTag.isValid(string))
    }

    @Test("the container keeps the tag as written and refuses to encode a non-tag")
    func container() throws {
        let valid = try LanguageCodeContainer(validating: "pt-BR")
        #expect(valid.languageTag == "pt-BR")
        #expect(valid.tag?.region == "BR")
        #expect(try encodeJSON(valid) == "pt-BR")

        #expect(throws: ATProtocolError.self) { try LanguageCodeContainer(validating: "not a language") }

        let unchecked = LanguageCodeContainer(languageCode: "not a language")
        #expect(unchecked.languageTag == "not a language")
        #expect(!unchecked.isWellFormed)
        #expect(unchecked.tag == nil)
        #expect(throws: (any Error).self) { try encodeJSON(unchecked) }
        #expect(throws: ATProtocolError.self) { try unchecked.toCBORValue() }

        let fromLocale = LanguageCodeContainer(lang: Locale.Language(identifier: "en"))
        #expect(try encodeJSON(fromLocale) == "en")
    }
}

@Suite("CID string syntax")
struct CIDSyntaxTests {
    @Test("length limits: 8 to 256 characters")
    func lengthBoundaries() {
        #expect(!CIDSyntax.isValid("bafybei"))
        #expect(CIDSyntax.isValid("bafybeig"))
        #expect(CIDSyntax.isValid("b" + String(repeating: "a", count: 255)))
        #expect(!CIDSyntax.isValid("b" + String(repeating: "a", count: 256)))
        #expect(!CIDSyntax.isValid(""))
    }

    @Test("CIDv0 is rejected; other multibase encodings are accepted")
    func encodings() {
        #expect(!CIDSyntax.isValid("QmbWqxBEKC3P8tqsKc98xmWNzrzDtRLMiMPL8wBuTGsMnR"))
        #expect(!CIDSyntax.isValid("QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"))
        #expect(CIDSyntax.isValid("zdj7WWeQ43G6JJvLWQWZpyHuAMq6uYWRjkBXFad11vE2LHhQ7"))
        #expect(CIDSyntax.isValid("mBcDxtdWx0aWhhc2g+"))
        #expect(CIDSyntax.isValid("f017012202c5f688262e0ece8569aa6f94d60aad55ca8d9d83734e4a7430d0cff6588ec2b"))
    }

    /// The syntax check is a separate tier from the CID decoder, which accepts
    /// only the forms repositories use. This pins both sides of that boundary.
    @Test("syntax validation is wider than CID.parse and does not change it")
    func separateFromDecoder() throws {
        let base32 = "bafyreidfayvfuwqa7qgahxgn2xrq2xrq2xrq2xrq2xrq2xrq2xrq2xrq2y"
        #expect(CIDSyntax.isValid(base32))
        #expect(throws: Never.self) { try CID.parse(base32) }

        let base58 = "zdj7WWeQ43G6JJvLWQWZpyHuAMq6uYWRjkBXFad11vE2LHhQ7"
        #expect(CIDSyntax.isValid(base58))
        #expect(throws: (any Error).self) { try CID.parse(base58) }
    }
}
