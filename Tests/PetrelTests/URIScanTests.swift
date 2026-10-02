import Foundation
@testable import Petrel
import Testing

/// Equivalence tests for the `URI` decode fast paths in `URIScan`.
///
/// Every fast path must return exactly what the code it shortcuts returned, so the
/// oracles below are verbatim copies of the pre-fast-path implementation. The URL
/// split (`simpleHTTP`) is compared against `URLComponents` of the platform running
/// the tests, so running this suite on each CI platform (iOS, macOS, Linux) is what
/// establishes that equality there.
@Suite("URI scan fast paths")
struct URIScanTests {
    // MARK: Oracles (verbatim legacy code)

    struct Fields: Equatable, CustomStringConvertible {
        var scheme: String
        var authority: String
        var path: String?
        var query: String?
        var fragment: String?
        var isDID: Bool
        var originalString: String?

        init(scheme: String, authority: String, path: String?, query: String?, fragment: String?, isDID: Bool, originalString: String?) {
            self.scheme = scheme
            self.authority = authority
            self.path = path
            self.query = query
            self.fragment = fragment
            self.isDID = isDID
            self.originalString = originalString
        }

        init(_ uri: URI) {
            self.init(
                scheme: uri.scheme,
                authority: uri.authority,
                path: uri.path,
                query: uri.query,
                fragment: uri.fragment,
                isDID: uri.isDID,
                originalString: uri.originalString
            )
        }

        var description: String {
            "(\(scheme.debugDescription), \(authority.debugDescription), \(String(describing: path)), \(String(describing: query)), \(String(describing: fragment)), did=\(isDID), \(String(describing: originalString)))"
        }
    }

    enum Legacy {
        static func detectScheme(in s: String) -> String? {
            let pattern = "^[A-Za-z][A-Za-z0-9+.-]*:"
            return s.range(of: pattern, options: .regularExpression).map { _ in String(s.prefix { $0 != ":" }) }
        }

        /// The generic branch shared by both initializers; `defaultScheme` is "" for
        /// `init(from:)` and "https" for `init(uriString:)`.
        static func generic(_ raw: String, defaultScheme: String) -> Fields {
            if raw.isEmpty || raw.hasPrefix("//") || detectScheme(in: raw) == nil {
                return Fields(
                    scheme: "https",
                    authority: "invalid.invalid",
                    path: nil,
                    query: nil,
                    fragment: nil,
                    isDID: false,
                    originalString: raw.isEmpty ? nil : raw
                )
            }
            let comps = URLComponents(string: raw)
            return Fields(
                scheme: comps?.scheme ?? defaultScheme,
                authority: comps?.host ?? "",
                path: comps?.path.isEmpty ?? true ? nil : comps?.path,
                query: comps?.query,
                fragment: comps?.fragment,
                isDID: false,
                originalString: raw
            )
        }

        /// Pre-fast-path `URI.init(from:)` for a JSON string value.
        static func decode(_ string: String) throws -> Fields {
            let raw = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.starts(with: "did:") {
                let components = raw.split(separator: ":")
                guard components.count >= 3 else { throw URI.URIError.invalidDID }
                return Fields(
                    scheme: String(components[0]),
                    authority: String(components[1]),
                    path: components.count > 2 ? components.dropFirst(2).joined(separator: ":") : nil,
                    query: nil,
                    fragment: nil,
                    isDID: true,
                    originalString: raw
                )
            } else if raw.starts(with: "at://") {
                let afterPrefix = raw.dropFirst(5)
                var authority: String, path: String?
                if let slashIndex = afterPrefix.firstIndex(of: "/") {
                    authority = String(afterPrefix[..<slashIndex])
                    let rem = String(afterPrefix[slashIndex...])
                    path = rem.isEmpty ? nil : rem
                } else {
                    authority = String(afterPrefix)
                    path = nil
                }
                return Fields(
                    scheme: "at",
                    authority: authority,
                    path: path,
                    query: nil,
                    fragment: nil,
                    isDID: false,
                    originalString: raw
                )
            }
            return generic(raw, defaultScheme: "")
        }

        /// Pre-fast-path generic branch of `URI.init(uriString:)`.
        static func constructGeneric(_ string: String) -> Fields {
            generic(string.trimmingCharacters(in: .whitespacesAndNewlines), defaultScheme: "https")
        }
    }

    // MARK: Generators

    struct SplitMix: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    /// Scalars chosen to sit on every boundary the scanners care about: scheme
    /// characters, ':', '/', whitespace and line terminators (ASCII and Unicode),
    /// combining marks that fuse with a preceding ':' or letter, CR LF, NUL,
    /// non-ASCII letters, emoji and ZWJ.
    static let boundaryScalars: [String] = [
        "a", "Z", "h", "t", "p", "s", "0", "9", "+", "-", ".", ":", "/", "?", "#", "@", "%", "2", "F",
        "[", "]", "_", "~", " ", "\t", "\n", "\r", "\r\n", "\u{0B}", "\u{0C}", "\u{00}", "\u{85}", "\u{A0}",
        "\u{2028}", "\u{3000}", "\u{301}", "\u{20DD}", "\u{200D}", "é", "e\u{301}", "日", "🐦", "K", "\u{212A}",
    ]

    static let corpusPieces: [[String]] = [
        ["", " ", "  ", "\n", "\t", "\u{A0}", "\u{2028}", "\u{301}"],
        ["https", "http", "HTTPS", "Http", "ftp", "mailto", "a+b-c.d", "1http", "h\u{301}ttps", "ht tp", "é", "", "did", "at"],
        ["://", ":", ":/", ":///", ":\u{301}//", "\u{301}://", "//", ":\r\n//", ""],
        ["", "user@", "user:pw@", "@", "us%40er@"],
        [
            "example.com",
            "a.b.c",
            "EXAMPLE.com",
            "xn--bcher-kva.example",
            "bücher.example",
            "[::1]",
            "[2001:db8::1]",
            "1.2.3.4",
            "a-.com",
            "-a.com",
            "a..b",
            "a.",
            "",
            "plc",
            "日本.jp",
            "ex ample.com",
        ],
        ["", ":8443", ":", ":0", ":99999", ":abc"],
        ["", "/", "/x", "/a/b/c", "/a%2Fb", "/caf\u{E9}", "/日本", "/🐦", "/a b", "/%zz", "/~user/(x)", "/a:b@c", "/a;b=c,d", "/\u{301}"],
        ["", "?", "?q=1", "?q=a%26b&n=1", "?x=%e6%97%a5", "?a=b+c", "?a?b", "?日本"],
        ["", "#", "#top", "#a?b", "#a#b", "#sec%20one", "#日本"],
        ["", " ", "  ", "\n", "\r\n", "\u{A0}", "\u{3000}", "\u{301}"],
    ]

    static func corpus(count: Int, seed: UInt64) -> [String] {
        var rng = SplitMix(state: seed)
        var result: [String] = []
        result.reserveCapacity(count)
        for _ in 0 ..< count {
            var s = corpusPieces.map { $0.randomElement(using: &rng)! }.joined()
            // Mutate some inputs further: insert / delete / replace one boundary scalar.
            if Int.random(in: 0 ..< 3, using: &rng) == 0, !s.isEmpty {
                var scalars = Array(s.unicodeScalars)
                let at = Int.random(in: 0 ..< scalars.count, using: &rng)
                let insert = Array(boundaryScalars.randomElement(using: &rng)!.unicodeScalars)
                switch Int.random(in: 0 ..< 3, using: &rng) {
                case 0: scalars.insert(contentsOf: insert, at: at)
                case 1: scalars.remove(at: at)
                default: scalars.replaceSubrange(at ... at, with: insert)
                }
                var rebuilt = String.UnicodeScalarView()
                rebuilt.append(contentsOf: scalars)
                s = String(rebuilt)
            }
            result.append(s)
        }
        return result
    }

    // MARK: Tests

    @Test("schemeMatch agrees with the legacy regex on every string of up to 3 boundary scalars, plus colon variants")
    func schemeMatchExhaustive() {
        let alphabet = Self.boundaryScalars
        var strings = [""]
        var frontier = [""]
        for _ in 0 ..< 3 {
            frontier = frontier.flatMap { prefix in alphabet.map { prefix + $0 } }
            strings += frontier
        }
        // Length-4 strings that end in ':' plus one more scalar exercise the post-colon rule.
        strings += alphabet.flatMap { a in ["h", "Z", "a"].flatMap { b in alphabet.map { c in b + ":" + a + c } } }
        var decided = 0, mismatches: [String] = []
        for s in strings {
            let legacy = Legacy.detectScheme(in: s) != nil
            let fast: Bool?? = s.utf8.withContiguousStorageIfAvailable(URIScan.schemeMatch)
            guard let answer = fast ?? nil else { continue }
            decided += 1
            if answer != legacy {
                mismatches.append(s.debugDescription)
            }
        }
        #expect(mismatches.isEmpty, "schemeMatch disagrees with legacy on \(mismatches.prefix(20))")
        #expect(decided > strings.count / 2)
    }

    @Test("trimmingWhitespaceAndNewlines equals Foundation trimming")
    func trimmingEquivalence() {
        var mismatches: [String] = []
        for s in Self.corpus(count: 20000, seed: 7) {
            if URIScan.trimmingWhitespaceAndNewlines(s) != s.trimmingCharacters(in: .whitespacesAndNewlines) {
                mismatches.append(s.debugDescription)
            }
        }
        #expect(mismatches.isEmpty, "trimming mismatches: \(mismatches.prefix(20))")
    }

    @Test("simpleHTTP split equals URLComponents on generated eligible URLs")
    func simpleHTTPMatchesURLComponents() {
        var rng = SplitMix(state: 42)
        let ldh = Array("abcdefghijklmnopqrstuvwxyz0123456789-")
        let pchar = Array("abcXYZ019-._~!$&'()*+,;=:@/")
        let qchar = pchar + ["?"]
        func random(_ alphabet: [Character], _ maxLength: Int, min: Int = 0) -> String {
            String((0 ..< Int.random(in: min ... maxLength, using: &rng)).map { _ in alphabet.randomElement(using: &rng)! })
        }
        var eligible = 0, mismatches: [String] = []
        for _ in 0 ..< 40000 {
            let labels = (0 ..< Int.random(in: 1 ... 4, using: &rng)).map { _ in random(ldh, 10, min: 1) }
            var s = (Bool.random(using: &rng) ? "https://" : "http://") + labels.joined(separator: ".")
            switch Int.random(in: 0 ..< 6, using: &rng) {
            case 0: break
            case 1: s += "/"
            default: s += "/" + random(pchar, 24)
            }
            if Int.random(in: 0 ..< 3, using: &rng) == 0 {
                s += "?" + random(qchar, 12)
            }
            if Int.random(in: 0 ..< 5, using: &rng) == 0 {
                s += "#" + random(qchar, 8)
            }
            guard let simple = s.utf8.withContiguousStorageIfAvailable(URIScan.simpleHTTP) ?? nil else { continue }
            eligible += 1
            if simple != URIScan.componentsParts(s) {
                mismatches.append(s)
            }
        }
        #expect(eligible > 20000)
        #expect(mismatches.isEmpty, "simpleHTTP differs from URLComponents for \(mismatches.prefix(20))")
    }

    @Test("URI decoding and construction equal the legacy implementation field for field")
    func uriFieldsMatchLegacy() throws {
        var mismatches: [String] = []
        var inputs = Self.corpus(count: 30000, seed: 20_260_930)
        inputs += [
            "https://example.com/x", "https://example.com:8443/x", "https://user@example.com/x",
            "https://ja.wikipedia.org/wiki/日本", "https://example.com/caf\u{E9}", "https://example.com/?q=a%26b",
            "https://example.com/a%2Fb", " https://example.com/item ", "not a uri", "//example.com", "did:web:example.com::x",
            "did:plc:abc", "did:x", "at://did:plc:abc/app.bsky.feed.post/3k", "mailto:a@b.c", "HTTPS://Example.COM",
            "https:", "https:/x", "https:///x", "https://example.com/?", "https://example.com#", "", " ", "h\u{301}ttps://x",
            "https:\u{301}//x", "https://[::1]:80/x", "https://xn--bcher-kva.example/", "https://example.com/a b",
        ]
        for input in inputs {
            let data = try JSONEncoder().encode([input])
            let legacy = Result { try Legacy.decode(input) }
            let current = Result { try JSONDecoder().decode([URI].self, from: data)[0] }
            switch (legacy, current) {
            case let (.success(a), .success(b)) where a == Fields(b):
                break
            case (.failure, .failure):
                break
            default:
                mismatches.append("decode \(input.debugDescription): legacy \(legacy) current \(current.map(Fields.init))")
            }
            let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.starts(with: "did:"), !raw.starts(with: "at://") {
                let constructed = Fields(URI(uriString: input))
                let expected = Legacy.constructGeneric(input)
                if constructed != expected {
                    mismatches.append("construct \(input.debugDescription): legacy \(expected) current \(constructed)")
                }
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.count) mismatches: \(mismatches.prefix(10))")
    }

    @Test("parseGeneric takes the byte fast path for every URI shape in the benchmark corpus")
    func fastPathCoverage() {
        let common = [
            "https://images.example.test/avatar/7/bafkreiabc.jpg",
            "https://example.test/articles/1?source=feed&lang=en",
            "https://cdn.bsky.app/img/avatar/plain/did:plc:abc/bafkrei@jpeg",
            "http://example.test/",
        ]
        for s in common {
            let simple = s.utf8.withContiguousStorageIfAvailable(URIScan.simpleHTTP) ?? nil
            #expect(simple != nil, "\(s) should take the simple split")
            #expect(simple == URIScan.componentsParts(s))
        }
    }
}
