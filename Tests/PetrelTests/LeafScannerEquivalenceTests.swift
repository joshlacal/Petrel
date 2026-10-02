import Foundation
@_spi(LeafScanners) @testable import Petrel
@_spi(LeafScanners) import PetrelCore
import Testing

/// Differential tests for the byte-scanner fast paths of the hand-written leaf
/// types (DID, Handle, NSID, RecordKey, ATProtocolURI, CID/base32, ATProtocolDate,
/// LanguageCodeContainer) against verbatim copies of the previous implementations
/// in `LeafLegacyOracle`.
///
/// The fast paths must be outcome-identical: same accept/reject, same field
/// values, same error case and text, same `Date` bit pattern. Legacy quirks are
/// preserved on purpose (a trailing line terminator accepted by ICU's `$`; CID
/// lookalike characters folded by `uppercased()`/`lowercased()`); tightening them is
/// a separate decision.
///
/// The release harness `Benchmarks/LeafEquiv` runs the same comparisons at full
/// size (69,905 exhaustive strings, 300k fuzz rounds per type, 252k dates, the
/// official atproto syntax vectors and the fixture corpus).
@Suite("Leaf scanner equivalence")
struct LeafScannerEquivalenceTests {
    // MARK: Helpers

    /// Production outcome for an identifier string, as the legacy validators expose it.
    static func didOutcome(_ s: String) -> String {
        guard let did = try? DID(didString: s) else { return "throw" }
        return "\(did.method)|\(did.authority)|\(did.segments)|\(did.didString())"
    }

    static func legacyDIDOutcome(_ s: String) -> String {
        guard let parts = LeafLegacyOracle.parseDID(s) else { return "throw" }
        return "\(parts.method)|\(parts.authority)|\(parts.segments)|\(LeafLegacyOracle.didString(parts))"
    }

    static func atURIOutcome(_ s: String) -> String {
        do {
            let uri = try ATProtocolURI(uriString: s)
            return [
                uri.authority, uri.collection ?? "nil", uri.recordKey ?? "nil", "\(uri.isSpace)",
                uri.spaceDID ?? "nil", uri.spaceType ?? "nil", uri.skey ?? "nil", uri.authorDID ?? "nil",
                uri.uriString(),
            ].joined(separator: "|")
        } catch let ATProtocolError.invalidURI(message) {
            return "error: \(message)"
        } catch {
            return "unexpected: \(error)"
        }
    }

    static func legacyATURIOutcome(_ s: String) -> String {
        do {
            let p = try LeafLegacyOracle.parseATURI(s)
            return [
                p.authority, p.collection ?? "nil", p.recordKey ?? "nil", "\(p.isSpace)",
                p.spaceDID ?? "nil", p.spaceType ?? "nil", p.skey ?? "nil", p.authorDID ?? "nil", s,
            ].joined(separator: "|")
        } catch let error as LeafLegacyOracle.URIError {
            return "error: \(error.message)"
        } catch {
            return "unexpected: \(error)"
        }
    }

    static func cidOutcome(_ s: String) -> String {
        do {
            let cid = try CID.parse(s)
            return "\(cid.codec.rawValue)|\(cid.multihash.algorithm)|\(cid.multihash.length)|\(cid.multihash.digest.base64EncodedString())|\(cid.string)"
        } catch {
            return "error: \(error)"
        }
    }

    static func legacyCIDOutcome(_ s: String) -> String {
        do {
            let p = try LeafLegacyOracle.parseCID(s)
            return "\(p.codec)|\(p.algorithm)|\(p.length)|\(p.digest.base64EncodedString())|\(LeafLegacyOracle.cidString(p))"
        } catch {
            return "error: \(error)"
        }
    }

    static func expectValidatorsAgree(_ s: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(DID.isValidDID(s) == LeafLegacyOracle.isValidDID(s), "DID \(s.debugDescription)", sourceLocation: sourceLocation)
        #expect(Handle.isValidHandle(s) == LeafLegacyOracle.isValidHandle(s), "Handle \(s.debugDescription)", sourceLocation: sourceLocation)
        #expect(NSID.isValidNSID(s) == LeafLegacyOracle.isValidNSID(s), "NSID \(s.debugDescription)", sourceLocation: sourceLocation)
        #expect(RecordKey.isValidRecordKey(s) == LeafLegacyOracle.isValidRecordKey(s), "RecordKey \(s.debugDescription)", sourceLocation: sourceLocation)
    }

    // MARK: Identifier validators

    static let boundarySymbols: [String] = [
        "a", "Z", "0", ".", "-", "_", ":", "%", "~", "\n", "\r\n", "é", "d", "i", "/", "\u{212A}",
    ]

    @Test("Validators agree on every short string over a boundary alphabet, in ten templates")
    func exhaustiveShortStrings() {
        var mismatches: [String] = []
        func check(_ s: String) {
            if DID.isValidDID(s) != LeafLegacyOracle.isValidDID(s) { mismatches.append("DID \(s.debugDescription)") }
            if Handle.isValidHandle(s) != LeafLegacyOracle.isValidHandle(s) { mismatches.append("Handle \(s.debugDescription)") }
            if NSID.isValidNSID(s) != LeafLegacyOracle.isValidNSID(s) { mismatches.append("NSID \(s.debugDescription)") }
            if RecordKey.isValidRecordKey(s) != LeafLegacyOracle.isValidRecordKey(s) { mismatches.append("RKEY \(s.debugDescription)") }
        }
        var count = 0
        func enumerate(_ prefix: String, _ depth: Int) {
            count += 1
            for template in [prefix, "did:" + prefix, "did:plc:" + prefix, prefix + ".com", "a." + prefix,
                             "app.bsky." + prefix, prefix + ".b.c", "a." + prefix + ".c"]
            {
                check(template)
            }
            if depth == 3 { return }
            for symbol in Self.boundarySymbols {
                enumerate(prefix + symbol, depth + 1)
            }
        }
        enumerate("", 0)
        #expect(count == 4369)
        #expect(mismatches.isEmpty, "\(mismatches.prefix(20))")
    }

    @Test("Trailing line terminators keep the legacy (ICU `$`) answer")
    func trailingLineTerminatorQuirk() {
        let terminators = ["\n", "\r", "\r\n", "\u{0B}", "\u{0C}", "\u{85}", "\u{2028}", "\u{2029}", "\n\n", " \n"]
        for terminator in terminators {
            for base in ["did:plc:abc", "did:web:example.com", "app.bsky.feed.post", "3kabc", "self", "abc.test", "a.b.c"] {
                Self.expectValidatorsAgree(base + terminator)
                Self.expectValidatorsAgree(terminator + base)
            }
            #expect(Self.atURIOutcome("at://did:plc:abc/app.bsky.feed.post/3kabc" + terminator)
                == Self.legacyATURIOutcome("at://did:plc:abc/app.bsky.feed.post/3kabc" + terminator))
            #expect(Self.atURIOutcome("at://did:plc:abc" + terminator + "/app.bsky.feed.post/3kabc")
                == Self.legacyATURIOutcome("at://did:plc:abc" + terminator + "/app.bsky.feed.post/3kabc"))
            #expect(Self.atURIOutcome("at://did:plc:abc/app.bsky.feed.post" + terminator)
                == Self.legacyATURIOutcome("at://did:plc:abc/app.bsky.feed.post" + terminator))
            #expect(Self.didOutcome("did:plc:abc" + terminator) == Self.legacyDIDOutcome("did:plc:abc" + terminator))
        }
        // The documented quirk itself is preserved (not tightened) by this change.
        #expect(DID.isValidDID("did:plc:abc\n"))
        #expect(NSID.isValidNSID("app.bsky.feed.post\n"))
        #expect(RecordKey.isValidRecordKey("3kabc\r\n"))
        #expect((try? ATProtocolURI(uriString: "at://did:plc:abc/app.bsky.feed.post/3kabc\n"))?.recordKey == "3kabc\n")
        #expect(LeafScan.didVerdict("did:plc:abc\n") == .undecided)
    }

    @Test("Length boundaries")
    func lengthBoundaries() {
        for n in [62, 63, 64, 252, 253, 254, 316, 317, 318, 511, 512, 513, 2047, 2048, 2049] {
            let run = String(repeating: "a", count: n)
            Self.expectValidatorsAgree(run)
            Self.expectValidatorsAgree("did:plc:" + String(repeating: "a", count: max(n - 8, 1)))
            Self.expectValidatorsAgree("a." + run + ".c")
            Self.expectValidatorsAgree("a.b." + run)
            Self.expectValidatorsAgree(run + ".com")
            Self.expectValidatorsAgree(String(repeating: "ab.", count: n / 3) + "com")
        }
    }

    @Test("Seeded fuzz: validators, DID components and Handle values agree")
    func fuzzValidators() {
        var rng = LeafSplitMix(state: 0x5EED_1EAF)
        let alphabet = Self.boundarySymbols + Array("abcdefghijklmnopqrstuvwxyz234567ABC-").map(String.init)
            + ["\u{0B}", "\u{0C}", " ", "\t", "\u{0}", "e\u{301}", "\u{301}", "İ", "ß", "😀", "\u{2028}", "\u{85}"]
        func randomString(_ maxLength: Int) -> String {
            let length = Int.random(in: 0 ... maxLength, using: &rng)
            return (0 ..< length).map { _ in alphabet.randomElement(using: &rng)! }.joined()
        }
        var mismatches: [String] = []
        for _ in 0 ..< 20000 {
            let did = "did:" + ["plc", "web", "key", "a", "", "PLC"].randomElement(using: &rng)! + ":" + randomString(24)
            let handle = (0 ..< Int.random(in: 1 ... 4, using: &rng)).map { _ in randomString(10) }.joined(separator: ".")
            let nsid = (0 ..< Int.random(in: 1 ... 5, using: &rng)).map { _ in randomString(8) }.joined(separator: ".")
            for s in [did, handle, nsid, randomString(16)] {
                if DID.isValidDID(s) != LeafLegacyOracle.isValidDID(s)
                    || Handle.isValidHandle(s) != LeafLegacyOracle.isValidHandle(s)
                    || NSID.isValidNSID(s) != LeafLegacyOracle.isValidNSID(s)
                    || RecordKey.isValidRecordKey(s) != LeafLegacyOracle.isValidRecordKey(s)
                {
                    mismatches.append(s.debugDescription)
                }
                if Self.didOutcome(s) != Self.legacyDIDOutcome(s) { mismatches.append("did-parts \(s.debugDescription)") }
                if (try? Handle(handleString: s))?.value != LeafLegacyOracle.handleValue(s) {
                    mismatches.append("handle-value \(s.debugDescription)")
                }
            }
        }
        #expect(mismatches.isEmpty, "\(mismatches.prefix(20))")
    }

    @Test("Handle value lowercases only when needed and matches the legacy value")
    func handleValue() throws {
        for s in ["alice.bsky.social", "Alice.Bsky.Social", "A.ISI.EDU", "xn--ls8h.test", "john.test"] {
            #expect(try Handle(handleString: s).value == LeafLegacyOracle.handleValue(s))
        }
        // KELVIN SIGN folds to "k" under lowercased(), but the regex on the original rejects it.
        #expect(!Handle.isValidHandle("\u{212A}.com"))
        #expect(!LeafLegacyOracle.isValidHandle("\u{212A}.com"))
    }

    // MARK: DID layout, equality and hashing

    @Test("DID keeps only the original string and derives identical components")
    func didLazyComponents() throws {
        let samples = ["did:plc:z72i7hdynmk6r22z27h6tvur", "did:web:example.com", "did:web:example.com%3A8080:u:alice",
                       "did:method::.", "did:a:b:c:d:e", "did:plc:abc\n", "did:key:zQ3sh"]
        for s in samples {
            let did = try DID(didString: s)
            let parts = try #require(LeafLegacyOracle.parseDID(s))
            #expect(did.method == parts.method)
            #expect(did.authority == parts.authority)
            #expect(did.segments == parts.segments)
            #expect(did.didString() == LeafLegacyOracle.didString(parts))
            #expect(did.didString() == s)
            #expect(did.description == s)
        }
        #expect(MemoryLayout<DID>.size == MemoryLayout<String>.size)

        let a = try DID(didString: "did:plc:abc")
        let b = try DID(didString: "did:plc:abc")
        let c = try DID(didString: "did:plc:abd")
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
        #expect(a != c)
        #expect(a.isEqual(to: b))
        #expect(!a.isEqual(to: c))
        #expect(Set([a, b, c]).count == 2)
    }

    // MARK: ATProtocolURI

    @Test("AT-URI fuzz: fields, authorDID and error text agree")
    func fuzzATURI() {
        var rng = LeafSplitMix(state: 0xA7_0121)
        let lower = Array("abcdefghijklmnopqrstuvwxyz234567").map(String.init)
        let collections = ["app.bsky.feed.post", "app.bsky.graph.follow", "com.example.fooBar", "space", "", "a.b",
                           "a.b.c-d", "app.bsky.feed.post2x", "app.bsky.feed.posu", "app.bsky.graph.blocks"]
        func randomString(_ alphabet: [String], _ maxLength: Int) -> String {
            let length = Int.random(in: 0 ... maxLength, using: &rng)
            return (0 ..< length).map { _ in alphabet.randomElement(using: &rng)! }.joined()
        }
        var mismatches: [String] = []
        for _ in 0 ..< 20000 {
            var s = "at://"
            switch Int.random(in: 0 ..< 4, using: &rng) {
            case 0: s += "did:plc:" + randomString(lower, 24)
            case 1: s += randomString(lower, 8) + "." + randomString(lower + ["-", "A"], 6)
            case 2: s += "did:web:" + randomString(lower + [".", ":", "%"], 12)
            default: s += randomString(Self.boundarySymbols + lower, 10)
            }
            for i in 0 ..< Int.random(in: 0 ... 4, using: &rng) {
                s += "/"
                s += i == 0 ? collections.randomElement(using: &rng)! : randomString(lower + [".", "~", ":", "_", "-", "\n", "é"], 14)
            }
            if Int.random(in: 0 ..< 6, using: &rng) == 0 {
                s += Self.boundarySymbols.randomElement(using: &rng)!
            }
            if Self.atURIOutcome(s) != Self.legacyATURIOutcome(s) { mismatches.append(s.debugDescription) }
        }
        #expect(mismatches.isEmpty, "\(mismatches.prefix(20))")
    }

    @Test("Interned collections are value-identical, including same-length near misses")
    func internedCollections() {
        let literals = ["app.bsky.feed.post", "app.bsky.feed.like", "app.bsky.feed.repost", "app.bsky.graph.follow",
                        "app.bsky.graph.block", "app.bsky.graph.list", "app.bsky.graph.listitem", "app.bsky.feed.generator",
                        "app.bsky.feed.threadgate", "app.bsky.feed.postgate", "app.bsky.actor.profile",
                        "app.bsky.graph.starterpack", "app.bsky.labeler.service", "app.bsky.graph.listblock",
                        "app.bsky.graph.verification"]
        for literal in literals {
            var nearMisses = [literal, literal + "s", String(literal.dropLast()), String(literal.dropLast()) + "x",
                              literal.uppercased(), "x" + literal.dropFirst()]
            nearMisses.append(String(literal.prefix(literal.count - 1)) + "Z")
            for collection in nearMisses {
                for s in ["at://did:plc:abc/\(collection)/3kabc", "at://alice.test/\(collection)", "at://did:plc:abc/\(collection)/"] {
                    #expect(Self.atURIOutcome(s) == Self.legacyATURIOutcome(s), "\(s)")
                }
            }
            #expect(LeafScannerProbe.atURIUsesFastPath("at://did:plc:abc/\(literal)/3kabc"))
        }
    }

    @Test("Space URIs and malformed AT-URIs keep the legacy path")
    func atURILegacyShapes() {
        let samples = [
            "at://did:plc:abc/space/com.example.space/skey",
            "at://did:plc:abc/space/com.example.space/skey/did:plc:def/app.bsky.feed.post/3k",
            "at://did:plc:abc/app.bsky.feed.post/3k/extra", "at://", "at:///", "at://did:plc:abc//3k",
            "at://did//rkey", "at://alice.test/", "at://alice.test", "at://not_a_handle/x.y.z", "at://did:plc:abc/./3k",
            "at://did:plc:abc/app.bsky.feed.post/.", "at://did:plc:abc/app.bsky.feed.post/..", "AT://did:plc:abc",
            "at://did:plc:abc/app.bsky.feed.p\u{301}ost/3k", "at://did:plc:é/app.bsky.feed.post/3k",
        ]
        for s in samples {
            #expect(Self.atURIOutcome(s) == Self.legacyATURIOutcome(s), "\(s.debugDescription)")
        }
    }

    // MARK: CID and base32

    @Test("CID fuzz: values, errors and canonical strings agree; lookalikes still accepted via the legacy path")
    func fuzzCID() {
        var rng = LeafSplitMix(state: 0xC1D)
        var mismatches: [String] = []
        for _ in 0 ..< 20000 {
            let length = [32, 32, 32, 20, 64, 0, 1, 65].randomElement(using: &rng)!
            var bytes: [UInt8] = [0x01, [0x55, 0x71, 0x70, 0x78, 0x00, 0x12].randomElement(using: &rng)!,
                                  [0x12, 0x13, 0xB2].randomElement(using: &rng)!, UInt8(truncatingIfNeeded: length)]
            for _ in 0 ..< length { bytes.append(UInt8.random(in: 0 ... 255, using: &rng)) }
            if Int.random(in: 0 ..< 10, using: &rng) == 0 { bytes.removeLast(min(bytes.count, Int.random(in: 0 ... 3, using: &rng))) }
            if Int.random(in: 0 ..< 20, using: &rng) == 0 { bytes[0] = UInt8.random(in: 0 ... 3, using: &rng) }
            var s = "b" + LeafLegacyOracle.base32Encode(Data(bytes))
            switch Int.random(in: 0 ..< 10, using: &rng) {
            case 0: s = s.uppercased()
            case 1: s = "b" + s.dropFirst().uppercased()
            case 2: s += String("abcdefghijklmnopqrstuvwxyz234567".randomElement(using: &rng)!)
            case 3:
                // Case-folding lookalikes that the legacy uppercased()/lowercased() round trip accepts.
                let lookalikes: [(Character, Character)] = [("i", "\u{131}"), ("k", "\u{212A}"), ("s", "\u{17F}")]
                let (ascii, lookalike) = lookalikes.randomElement(using: &rng)!
                if let index = s.dropFirst().firstIndex(of: ascii) { s.replaceSubrange(index ... index, with: String(lookalike)) }
            case 4:
                let inserts: [Character] = ["!", "1", "8", "=", "\n", "é"]
                s.insert(inserts.randomElement(using: &rng)!, at: s.index(s.startIndex, offsetBy: min(5, s.count)))
            case 5: s = String(s.prefix(Int.random(in: 0 ... s.count, using: &rng)))
            default: break
            }
            if Self.cidOutcome(s) != Self.legacyCIDOutcome(s) { mismatches.append(s.debugDescription) }
            if base32Decode(s) != LeafLegacyOracle.base32Decode(s) { mismatches.append("decode \(s.debugDescription)") }
            if base32Encode(Data(bytes)) != LeafLegacyOracle.base32Encode(Data(bytes)) { mismatches.append("encode \(bytes)") }
        }
        #expect(mismatches.isEmpty, "\(mismatches.prefix(20))")
    }

    @Test("CID lookalike characters are accepted exactly as before (not on the fast path)")
    func cidLookalikes() throws {
        let canonical = "bafyreigcxd76a5xqjzw2l6fq3u7d26hjtybdslqj2kxlzpvfyrvhycbr2a"
        for (ascii, lookalike) in [("i", "\u{131}"), ("k", "\u{212A}"), ("s", "\u{17F}")] {
            guard let range = canonical.dropFirst().range(of: ascii) else { continue }
            var s = canonical
            s.replaceSubrange(range, with: lookalike)
            #expect(Self.cidOutcome(s) == Self.legacyCIDOutcome(s), "\(s)")
            #expect(!CIDScannerProbe.parsesOnFastPath(s))
            #expect(try CID.parse(s) == CID.parse(canonical))
        }
        #expect(base32Decode("\u{212A}a") == LeafLegacyOracle.base32Decode("\u{212A}a"))
        #expect(base32Decode("") == nil)
        #expect(base32Encode(Data()) == "")
    }

    @Test("CID.bytes and CID.string are unchanged for every codec and digest length")
    func cidEncoding() throws {
        var rng = LeafSplitMix(state: 0xB17E5)
        for codec in [CIDCodec.raw, .dagPB, .dagCBOR, .gitRaw, .identity] {
            for length in [1, 20, 31, 32, 33, 64] {
                let digest = Data((0 ..< length).map { _ in UInt8.random(in: 0 ... 255, using: &rng) })
                let cid = CID(codec: codec, multihash: Multihash(algorithm: 0x12, length: UInt8(length), digest: digest))
                let legacyBytes = Data([0x01, codec.rawValue]) + (Data([0x12, UInt8(length)]) + digest)
                #expect(cid.bytes == legacyBytes)
                #expect(cid.string == "b" + LeafLegacyOracle.base32Encode(legacyBytes).lowercased())
                // Both parsers reject strings outside 10...100 characters (a 1-byte digest
                // encodes to 9, a 64-byte digest to 110).
                #expect(Self.cidOutcome(cid.string) == Self.legacyCIDOutcome(cid.string))
                if (10 ... 100).contains(cid.string.utf8.count) {
                    #expect(try CID.parse(cid.string) == cid)
                }
            }
        }
    }

    // MARK: ATProtocolDate

    static func decodeDate(_ s: String) -> ATProtocolDate? {
        try? JSONDecoder().decode(ATProtocolDate.self, from: Data("\"\(s)\"".utf8))
    }

    @Test("Date fast path is bit-identical to Foundation for every day 1970...2199")
    func dateSweep() throws {
        var rng = LeafSplitMix(state: 0xDA7E)
        let fractions = ["", ".0", ".1", ".12", ".123", ".301", ".999", ".1234", ".12345", ".123456", ".1234567",
                         ".72094284", ".720942844", ".999999999", ".000000001", ".5"]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        var day = try #require(calendar.date(from: DateComponents(year: 1970, month: 1, day: 1)))
        let end = try #require(calendar.date(from: DateComponents(year: 2200, month: 1, day: 1)))
        var checked = 0
        var fast = 0
        var mismatches: [String] = []
        while day < end {
            let c = calendar.dateComponents([.year, .month, .day], from: day)
            var fraction = fractions.randomElement(using: &rng)!
            if Bool.random(using: &rng), !fraction.isEmpty {
                fraction = "." + String((1 ..< fraction.count).map { _ in "0123456789".randomElement(using: &rng)! })
            }
            let s = String(format: "%04d-%02d-%02dT%02d:%02d:%02d%@Z", c.year!, c.month!, c.day!,
                           Int.random(in: 0 ... 23, using: &rng), Int.random(in: 0 ... 59, using: &rng),
                           Int.random(in: 0 ... 59, using: &rng), fraction)
            let legacy = LeafLegacyOracle.parseDate(s)
            let decoded = Self.decodeDate(s)
            if decoded?.date.timeIntervalSinceReferenceDate.bitPattern != legacy?.timeIntervalSinceReferenceDate.bitPattern {
                mismatches.append(s)
            }
            if LeafScannerProbe.dateUsesFastPath(s) { fast += 1 }
            checked += 1
            day = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        }
        #expect(checked == 84006)
        #expect(fast == checked)
        #expect(mismatches.isEmpty, "\(mismatches.prefix(20))")
    }

    @Test("Non-canonical and invalid datetimes take the Foundation path with identical results")
    func dateEdgeShapes() {
        let samples = [
            "2024-02-29T12:00:00.000Z", "2023-02-29T12:00:00.000Z", "2024-02-30T00:00:00Z", "2024-04-31T00:00:00Z",
            "2024-13-01T00:00:00Z", "2024-00-10T00:00:00Z", "2024-01-00T00:00:00Z", "2024-01-01T24:00:00Z",
            "2024-01-01T23:60:00Z", "2016-12-31T23:59:60Z", "2024-01-01t00:00:00Z", "2024-01-01T00:00:00z",
            "2024-01-01T00:00:00.1234567890Z", "2024-01-01T00:00:00.123456789012Z", "2024-01-01T00:00:00+00:00",
            "2024-01-01T00:00:00.123+05:30", "2024-01-01T00:00:00.123-0800", "1969-12-31T23:59:59.999Z",
            "1970-01-01T00:00:00.000Z", "2199-12-31T23:59:59.999999999Z", "2200-01-01T00:00:00Z", "0001-01-01T00:00:00Z",
            "2024-01-01T00:00:00.Z", "2024-01-01T00:00:00", "2024-01-01 00:00:00Z", "2024-01-01T00:00:00.000Zjunk",
            "12024-01-01T00:00:00Z", "2024-1-01T00:00:00Z", "2024-01-01T0:00:00Z", "", "not a date",
            "2024-01-01T00:00:00.12\u{301}3Z", "２０２４-01-01T00:00:00Z",
        ]
        for s in samples {
            let legacy = LeafLegacyOracle.parseDate(s)
            let decoded = Self.decodeDate(s)
            #expect(decoded?.date.timeIntervalSinceReferenceDate.bitPattern == legacy?.timeIntervalSinceReferenceDate.bitPattern,
                    "\(s.debugDescription)")
            #expect((ATProtocolDate(iso8601String: s) == nil) == (legacy == nil), "\(s.debugDescription)")
            if let decoded {
                #expect(decoded.iso8601String == s)
            }
        }
    }

    @Test("Formatting a non-wire date is unchanged")
    func dateFormatting() {
        var rng = LeafSplitMix(state: 0xF0A7)
        for _ in 0 ..< 2000 {
            let date = Date(timeIntervalSinceReferenceDate: Double.random(in: -1e9 ... 2e9, using: &rng))
            #expect(ATProtocolDate(date: date).iso8601String == LeafLegacyOracle.formattedDate(date))
        }
    }

    // MARK: LanguageCodeContainer

    @Test("Lazy lang equals the eagerly built Locale.Language", arguments: [
        "en", "en-US", "pt-BR", "zh-Hans", "zh-Hant-TW", "es-419", "ja", "sr-Latn", "x-private", "i-klingon",
        "und", "", "EN", "en_US", "not a tag", "de-CH-1901",
    ])
    func lazyLanguage(_ tag: String) throws {
        let decoded = try JSONDecoder().decode(LanguageCodeContainer.self, from: Data("\"\(tag)\"".utf8))
        let eager = Locale.Language(identifier: tag)
        #expect(decoded.lang == eager)
        #expect(decoded.lang.languageCode == eager.languageCode)
        #expect(decoded.lang.minimalIdentifier == eager.minimalIdentifier)
        #expect(decoded.languageTag == tag)
        #expect(LanguageCodeContainer(languageCode: tag).lang == eager)
        #expect(LanguageCodeContainer(languageCode: tag) == decoded)

        let explicit = LanguageCodeContainer(lang: eager)
        #expect(explicit.lang == eager)
        #expect(explicit.languageTag == (eager.languageCode?.identifier ?? eager.minimalIdentifier))

        var mutated = decoded
        mutated.lang = Locale.Language(identifier: "fr")
        #expect(mutated.languageTag == "fr")
        #expect(mutated.lang == Locale.Language(identifier: "fr"))
        #expect(MemoryLayout<LanguageCodeContainer>.size <= 24)
    }
}
