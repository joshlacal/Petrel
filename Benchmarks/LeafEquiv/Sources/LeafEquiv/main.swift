// LeafEquiv: release-mode differential harness for the leaf-scanner fast paths.
//
// Compares production Petrel (DID, Handle, NSID, RecordKey, ATProtocolURI, CID,
// base32, ATProtocolDate, LanguageCodeContainer) with verbatim copies of the
// previous implementations (LeafLegacyOracle.swift). No latency timing: the only
// performance numbers are deterministic counters (instructions retired via
// proc_pid_rusage) and call/coverage counts.
//
// Usage: LeafEquiv --fixtures <Benchmarks/JSON/Fixtures> [--interop <atproto/interop-test-files/syntax>]
//                  [--fuzz 300000] [--reps 20]
import Foundation
@_spi(LeafScanners) import Petrel
@_spi(LeafScanners) import PetrelCore
#if canImport(Darwin)
    import Darwin
#endif

let args = CommandLine.arguments
func option(_ name: String, _ fallback: String) -> String {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return fallback }
    return args[i + 1]
}

let fixtureDir = option("--fixtures", "")
let interopDir = option("--interop", "")
let fuzzN = Int(option("--fuzz", "300000"))!
let reps = Int(option("--reps", "20"))!

var rng = LeafSplitMix(state: 0xC0FFEE)
var failures = 0
var checks = 0
func report(_ label: String, _ input: String, _ detail: String = "") {
    failures += 1
    if failures <= 60 {
        print("MISMATCH [\(label)] input=\(input.debugDescription) \(detail)")
    }
}

@inline(__always) func same(_ label: String, _ input: String, _ a: String, _ b: String) {
    checks += 1
    if a != b { report(label, input, "new=\(a.debugDescription) legacy=\(b.debugDescription)") }
}

@inline(__always) func sameBool(_ label: String, _ input: String, _ a: Bool, _ b: Bool) {
    checks += 1
    if a != b { report(label, input, "new=\(a) legacy=\(b)") }
}

// MARK: - Outcome functions (production vs legacy)

func didOutcome(_ s: String) -> String {
    guard let did = try? DID(didString: s) else { return "throw" }
    return "\(did.method)|\(did.authority)|\(did.segments)|\(did.didString())|\(did.description)"
}

func legacyDIDOutcome(_ s: String) -> String {
    guard let parts = LeafLegacyOracle.parseDID(s) else { return "throw" }
    return "\(parts.method)|\(parts.authority)|\(parts.segments)|\(LeafLegacyOracle.didString(parts))|\(s)"
}

func handleOutcome(_ s: String) -> String {
    (try? Handle(handleString: s))?.value ?? "throw"
}

func legacyHandleOutcome(_ s: String) -> String {
    LeafLegacyOracle.handleValue(s) ?? "throw"
}

func atURIOutcome(_ s: String) -> String {
    do {
        let uri = try ATProtocolURI(uriString: s)
        return [uri.authority, uri.collection ?? "nil", uri.recordKey ?? "nil", "\(uri.isSpace)",
                uri.spaceDID ?? "nil", uri.spaceType ?? "nil", uri.skey ?? "nil", uri.authorDID ?? "nil",
                uri.uriString()].joined(separator: "|")
    } catch let ATProtocolError.invalidURI(message) {
        return "error: \(message)"
    } catch {
        return "unexpected: \(error)"
    }
}

func legacyATURIOutcome(_ s: String) -> String {
    do {
        let p = try LeafLegacyOracle.parseATURI(s)
        return [p.authority, p.collection ?? "nil", p.recordKey ?? "nil", "\(p.isSpace)",
                p.spaceDID ?? "nil", p.spaceType ?? "nil", p.skey ?? "nil", p.authorDID ?? "nil", s]
            .joined(separator: "|")
    } catch let error as LeafLegacyOracle.URIError {
        return "error: \(error.message)"
    } catch {
        return "unexpected: \(error)"
    }
}

func atIdentifierOutcome(_ s: String) -> String {
    guard let id = try? ATIdentifier(string: s) else { return "throw" }
    return "\(id.stringValue())|\(id.description)"
}

func legacyATIdentifierOutcome(_ s: String) -> String {
    if s.starts(with: "did:") {
        guard LeafLegacyOracle.parseDID(s) != nil else { return "throw" }
        return "\(s)|\(s)"
    }
    guard let value = LeafLegacyOracle.handleValue(s) else { return "throw" }
    return "\(value)|\(value)"
}

func cidOutcome(_ s: String) -> String {
    do {
        let cid = try CID.parse(s)
        return "\(cid.codec.rawValue)|\(cid.multihash.algorithm)|\(cid.multihash.length)|\(cid.multihash.digest.base64EncodedString())|\(cid.string)"
    } catch {
        return "error: \(error)"
    }
}

func legacyCIDOutcome(_ s: String) -> String {
    do {
        let p = try LeafLegacyOracle.parseCID(s)
        return "\(p.codec)|\(p.algorithm)|\(p.length)|\(p.digest.base64EncodedString())|\(LeafLegacyOracle.cidString(p))"
    } catch {
        return "error: \(error)"
    }
}

func dateBits(_ s: String) -> String {
    guard let data = try? JSONEncoder().encode(s),
          let decoded = try? JSONDecoder().decode(ATProtocolDate.self, from: data)
    else { return "throw" }
    let viaInit = ATProtocolDate(iso8601String: s)?.date.timeIntervalSinceReferenceDate.bitPattern
    return "\(decoded.date.timeIntervalSinceReferenceDate.bitPattern)|\(viaInit.map(String.init) ?? "nil")|\(decoded.iso8601String)"
}

func legacyDateBits(_ s: String) -> String {
    guard let date = LeafLegacyOracle.parseDate(s) else { return "throw" }
    let bits = date.timeIntervalSinceReferenceDate.bitPattern
    return "\(bits)|\(bits)|\(s)"
}

func languageOutcome(_ s: String) -> String {
    guard let data = try? JSONEncoder().encode(s),
          let decoded = try? JSONDecoder().decode(LanguageCodeContainer.self, from: data)
    else { return "throw" }
    let lang = decoded.lang
    return "\(decoded.languageTag)|\(lang.minimalIdentifier)|\(lang.maximalIdentifier)|\(lang.languageCode?.identifier ?? "nil")|\(lang.region?.identifier ?? "nil")|\(lang.script?.identifier ?? "nil")"
}

func legacyLanguageOutcome(_ s: String) -> String {
    let lang = Locale.Language(identifier: s)
    return "\(s)|\(lang.minimalIdentifier)|\(lang.maximalIdentifier)|\(lang.languageCode?.identifier ?? "nil")|\(lang.region?.identifier ?? "nil")|\(lang.script?.identifier ?? "nil")"
}

func checkValidators(_ s: String, _ tag: String) {
    sameBool("did\(tag)", s, DID.isValidDID(s), LeafLegacyOracle.isValidDID(s))
    sameBool("handle\(tag)", s, Handle.isValidHandle(s), LeafLegacyOracle.isValidHandle(s))
    sameBool("nsid\(tag)", s, NSID.isValidNSID(s), LeafLegacyOracle.isValidNSID(s))
    sameBool("rkey\(tag)", s, RecordKey.isValidRecordKey(s), LeafLegacyOracle.isValidRecordKey(s))
}

// MARK: - Alphabets and mutation

let boundary: [String] = ["a", "z", "A", "Z", "0", "9", ".", "-", "_", ":", "%", "~", "/", "?", "#", "@", "+",
                          "\n", "\r\n", "\r", "\u{0B}", "\u{0C}", " ", "\t", "\u{0}", "é", "e\u{301}", "\u{301}",
                          "\u{212A}", "\u{131}", "\u{17F}", "\u{2028}", "\u{2029}", "\u{85}", "İ", "ß", "😀",
                          "d", "i", "b", "x", "n"]
let lowerAlnum = Array("abcdefghijklmnopqrstuvwxyz234567").map(String.init)

func randomString(_ alphabet: [String], maxLen: Int) -> String {
    let len = Int.random(in: 0 ... maxLen, using: &rng)
    var s = ""
    for _ in 0 ..< len { s += alphabet.randomElement(using: &rng)! }
    return s
}

func mutate(_ s: String) -> String {
    var chars = Array(s)
    for _ in 0 ..< Int.random(in: 1 ... 3, using: &rng) {
        let piece = Character(boundary.randomElement(using: &rng)!)
        switch Int.random(in: 0 ... 4, using: &rng) {
        case 0 where !chars.isEmpty: chars.remove(at: Int.random(in: 0 ..< chars.count, using: &rng))
        case 1: chars.insert(piece, at: Int.random(in: 0 ... chars.count, using: &rng))
        case 2 where !chars.isEmpty: chars[Int.random(in: 0 ..< chars.count, using: &rng)] = piece
        case 3: chars.append(piece)
        default: if !chars.isEmpty { chars[0] = piece }
        }
    }
    return String(chars)
}

// MARK: - A. Quirk probes

print("== A. Legacy quirks preserved (trailing line terminators, CID lookalikes)")
for probe in ["did:plc:abc\n", "did:plc:abc\r\n", "did:plc:abc\r", "did:plc:abc\u{0B}", "did:plc:abc\u{0C}",
              "did:plc:abc\u{2028}", "did:plc:abc\u{85}", "app.bsky.feed.post\n", "3kabc\n", "abc.test\n"]
{
    print("  \(probe.debugDescription): DID \(DID.isValidDID(probe))/\(LeafLegacyOracle.isValidDID(probe))"
        + " NSID \(NSID.isValidNSID(probe))/\(LeafLegacyOracle.isValidNSID(probe))"
        + " RKEY \(RecordKey.isValidRecordKey(probe))/\(LeafLegacyOracle.isValidRecordKey(probe))"
        + " HANDLE \(Handle.isValidHandle(probe))/\(LeafLegacyOracle.isValidHandle(probe))  (new/legacy)")
    checkValidators(probe, "-quirk")
}
let quirkURI = "at://did:plc:abc/app.bsky.feed.post/3kabc\n"
print("  AT-URI \(quirkURI.debugDescription): new=\(atURIOutcome(quirkURI).debugDescription)")
same("aturi-quirk", quirkURI, atURIOutcome(quirkURI), legacyATURIOutcome(quirkURI))
let canonicalCID = "bafyreigcxd76a5xqjzw2l6fq3u7d26hjtybdslqj2kxlzpvfyrvhycbr2a"
for (ascii, lookalike) in [("i", "\u{131}"), ("k", "\u{212A}"), ("s", "\u{17F}")] {
    guard let range = canonicalCID.dropFirst().range(of: ascii) else { continue }
    var s = canonicalCID
    s.replaceSubrange(range, with: lookalike)
    print("  CID lookalike \(lookalike.unicodeScalars.first!.properties.name ?? "?"): new=\(cidOutcome(s) == cidOutcome(canonicalCID) ? "accepted (same CID)" : cidOutcome(s)) fastPath=\(CIDScannerProbe.parsesOnFastPath(s))")
    same("cid-lookalike", s, cidOutcome(s), legacyCIDOutcome(s))
}

// MARK: - B. Exhaustive short strings

print("== B. Exhaustive: every string of length <= 4 over a 16-symbol boundary alphabet")
let small: [String] = ["a", "Z", "0", ".", "-", "_", ":", "%", "~", "\n", "\r\n", "é", "d", "i", "/", "\u{212A}"]
var exhaustive = 0
func enumerate(_ prefix: String, _ depth: Int) {
    exhaustive += 1
    for (tag, s) in [("", prefix), ("2", "did:" + prefix), ("3", "did:plc:" + prefix), ("4", prefix + ".com"),
                     ("5", "a." + prefix), ("6", "app.bsky." + prefix), ("7", prefix + ".b.c"),
                     ("8", "a." + prefix + ".c"), ("9", "x" + prefix), ("10", prefix + "z")]
    {
        checkValidators(s, "-ex\(tag)")
    }
    same("didparts-ex", "did:plc:" + prefix, didOutcome("did:plc:" + prefix), legacyDIDOutcome("did:plc:" + prefix))
    same("handlevalue-ex", prefix + ".Com", handleOutcome(prefix + ".Com"), legacyHandleOutcome(prefix + ".Com"))
    for s in ["at://did:plc:abc/" + prefix, "at://" + prefix + "/app.bsky.feed.post/x", "at://a.com/app.bsky.feed.post/" + prefix] {
        same("aturi-ex", s, atURIOutcome(s), legacyATURIOutcome(s))
    }
    if depth == 4 { return }
    for c in small { enumerate(prefix + c, depth + 1) }
}
enumerate("", 0)
print("  strings: \(exhaustive) (x10 validator templates, + DID parts, Handle value, 3 AT-URI templates)")

// MARK: - C. Fuzz

print("== C. Fuzz: \(fuzzN) rounds per type (SplitMix64 seed 0xC0FFEE)")
let didMethods = ["plc", "web", "key", "a", "", "PLC", "p1c"]
for _ in 0 ..< fuzzN {
    let did = "did:" + didMethods.randomElement(using: &rng)! + ":" + randomString(lowerAlnum + boundary, maxLen: 30)
    let labels = (0 ..< Int.random(in: 1 ... 4, using: &rng)).map { _ in randomString(lowerAlnum + ["-", "A", "Z", "0"], maxLen: 12) }
    let handle = labels.joined(separator: ".")
    let nsid = (0 ..< Int.random(in: 1 ... 5, using: &rng)).map { _ in randomString(lowerAlnum + ["-", "A", "0"], maxLen: 10) }.joined(separator: ".")
    let rkey = randomString(lowerAlnum + [".", "_", ":", "~", "-", "A"], maxLen: 16)
    for (tag, s) in [("did", did), ("did-m", mutate(did)), ("handle", handle), ("handle-m", mutate(handle)),
                     ("nsid", nsid), ("nsid-m", mutate(nsid)), ("rkey", rkey), ("rkey-m", mutate(rkey))]
    {
        checkValidators(s, "-\(tag)")
    }
    same("didparts", did, didOutcome(did), legacyDIDOutcome(did))
    same("handlevalue", handle, handleOutcome(handle), legacyHandleOutcome(handle))
    if Int.random(in: 0 ..< 200, using: &rng) == 0 {
        let long = String(repeating: "a", count: Int.random(in: 60 ... 70, using: &rng))
        checkValidators(long + ".com", "-len1")
        checkValidators("a." + long + ".c", "-len2")
        checkValidators("a.b." + long, "-len3")
        let huge = String(repeating: "a", count: Int.random(in: 240 ... 520, using: &rng))
        checkValidators(huge, "-len4")
        checkValidators(huge + ".com", "-len5")
        checkValidators("did:plc:" + String(repeating: "a", count: Int.random(in: 2030 ... 2050, using: &rng)), "-len6")
    }
}
print("  validators: \(fuzzN) rounds x 8 strings x 4 validators, + DID parts + Handle value")

var atFast = 0
let collections = ["app.bsky.feed.post", "app.bsky.graph.follow", "com.example.fooBar", "space", "", "a.b", "a.b.c-d",
                   "app.bsky.feed.post2x", "app.bsky.feed.posu", "app.bsky.graph.blocks", "app.bsky.graph.verification"]
for _ in 0 ..< fuzzN {
    var s = "at://"
    switch Int.random(in: 0 ..< 5, using: &rng) {
    case 0: s += "did:plc:" + randomString(lowerAlnum, maxLen: 24)
    case 1: s += randomString(lowerAlnum, maxLen: 8) + "." + randomString(lowerAlnum + ["-"], maxLen: 6)
    case 2: s += mutate("did:plc:abcdefghijklmnopqrstuvwx")
    case 3: s += "did:web:" + randomString(lowerAlnum + [".", ":", "%"], maxLen: 12)
    default: s += randomString(boundary + lowerAlnum, maxLen: 10)
    }
    for i in 0 ..< Int.random(in: 0 ... 4, using: &rng) {
        s += "/"
        if i == 0 {
            s += Bool.random(using: &rng) ? collections.randomElement(using: &rng)! : mutate(collections.randomElement(using: &rng)!)
        } else {
            s += Bool.random(using: &rng) ? randomString(lowerAlnum + [".", "~", ":", "_", "-"], maxLen: 14) : mutate("3kabcdefghij2")
        }
    }
    if Int.random(in: 0 ..< 5, using: &rng) == 0 { s = mutate(s) }
    if LeafScannerProbe.atURIUsesFastPath(s) { atFast += 1 }
    same("aturi", s, atURIOutcome(s), legacyATURIOutcome(s))
}
print("  AT-URI: \(fuzzN) inputs, fast path taken for \(atFast)")

var cidFast = 0
var base32Fast = 0
for _ in 0 ..< fuzzN {
    let len = [32, 32, 32, 20, 64, 0, 1, 65].randomElement(using: &rng)!
    var bytes: [UInt8] = [0x01, [0x55, 0x71, 0x70, 0x78, 0x00, 0x12].randomElement(using: &rng)!,
                          [0x12, 0x13, 0xB2].randomElement(using: &rng)!, UInt8(truncatingIfNeeded: len)]
    for _ in 0 ..< len { bytes.append(UInt8.random(in: 0 ... 255, using: &rng)) }
    if Int.random(in: 0 ..< 10, using: &rng) == 0 { bytes.removeLast(min(bytes.count, Int.random(in: 0 ... 3, using: &rng))) }
    if Int.random(in: 0 ..< 20, using: &rng) == 0 { bytes[0] = UInt8.random(in: 0 ... 3, using: &rng) }
    var s = "b" + LeafLegacyOracle.base32Encode(Data(bytes))
    switch Int.random(in: 0 ..< 10, using: &rng) {
    case 0: s = s.uppercased()
    case 1: s = "b" + s.dropFirst().uppercased()
    case 2: s = mutate(s)
    case 3: s += String(lowerAlnum.randomElement(using: &rng)!)
    case 4:
        let pairs: [(Character, String)] = [("i", "\u{131}"), ("k", "\u{212A}"), ("s", "\u{17F}"), ("a", "\u{0430}")]
        let (ascii, lookalike) = pairs.randomElement(using: &rng)!
        if let index = s.dropFirst().firstIndex(of: ascii) { s.replaceSubrange(index ... index, with: lookalike) }
    default: break
    }
    if CIDScannerProbe.parsesOnFastPath(s) { cidFast += 1 }
    same("cid", s, cidOutcome(s), legacyCIDOutcome(s))
    let body = String(s.dropFirst())
    if CIDScannerProbe.base32DecodesOnFastPath(body) { base32Fast += 1 }
    checks += 2
    if base32Decode(body) != LeafLegacyOracle.base32Decode(body) { report("base32Decode", body) }
    if base32Encode(Data(bytes)) != LeafLegacyOracle.base32Encode(Data(bytes)) { report("base32Encode", "\(bytes)") }
}
print("  CID: \(fuzzN) inputs, fast path accepted \(cidFast); base32Decode fast path accepted \(base32Fast)")

print("== C2. Dates: every day 1970-01-01...2199-12-31 x 3 random times and fraction shapes (bit-exact), + \(fuzzN) mutants")
var dateChecked = 0
var dateFast = 0
let fractions = ["", ".0", ".1", ".12", ".123", ".301", ".999", ".1234", ".12345", ".123456", ".720942", ".1234567",
                 ".72094284", ".720942844", ".999999999", ".000000001", ".5"]
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "UTC")!
var day = calendar.date(from: DateComponents(year: 1970, month: 1, day: 1))!
let endDay = calendar.date(from: DateComponents(year: 2200, month: 1, day: 1))!
var dateSamples: [String] = []
while day < endDay {
    let c = calendar.dateComponents([.year, .month, .day], from: day)
    for _ in 0 ..< 3 {
        var frac = fractions.randomElement(using: &rng)!
        if Bool.random(using: &rng), !frac.isEmpty {
            frac = "." + String((1 ..< frac.count).map { _ in "0123456789".randomElement(using: &rng)! })
        }
        let s = String(format: "%04d-%02d-%02dT%02d:%02d:%02d%@Z", c.year!, c.month!, c.day!,
                       Int.random(in: 0 ... 23, using: &rng), Int.random(in: 0 ... 59, using: &rng),
                       Int.random(in: 0 ... 59, using: &rng), frac)
        if LeafScannerProbe.dateUsesFastPath(s) { dateFast += 1 }
        same("date", s, dateBits(s), legacyDateBits(s))
        dateChecked += 1
        if dateSamples.count < 4096, Int.random(in: 0 ..< 32, using: &rng) == 0 { dateSamples.append(s) }
    }
    day = calendar.date(byAdding: .day, value: 1, to: day)!
}
print("  exhaustive-day dates: \(dateChecked), fast path \(dateFast)")
let dateAlphabet = ["0", "1", "2", "9", "-", ":", "T", "t", "Z", "z", ".", "+", " ", "\n", "5", "6", "3"]
var dateMutantFast = 0
for _ in 0 ..< fuzzN {
    var s = dateSamples.randomElement(using: &rng)!
    switch Int.random(in: 0 ..< 4, using: &rng) {
    case 0: s = mutate(s)
    case 1:
        var chars = Array(s)
        chars[Int.random(in: 0 ..< chars.count, using: &rng)] = Character(dateAlphabet.randomElement(using: &rng)!)
        s = String(chars)
    case 2: s = String(s.dropLast()) + ["+00:00", "-08:00", "+0530", "Z", "z", "", "ZZ"].randomElement(using: &rng)!
    default:
        // Field-boundary values: month/day/hour/minute/second edges.
        var chars = Array(s)
        let positions = [5, 8, 11, 14, 17]
        let p = positions.randomElement(using: &rng)!
        let value = ["00", "01", "12", "13", "23", "24", "28", "29", "30", "31", "32", "59", "60", "99"].randomElement(using: &rng)!
        chars[p] = value.first!
        chars[p + 1] = value.last!
        s = String(chars)
    }
    if LeafScannerProbe.dateUsesFastPath(s) { dateMutantFast += 1 }
    same("date-mutant", s, dateBits(s), legacyDateBits(s))
}
print("  date mutants: \(fuzzN), fast path \(dateMutantFast)")

print("== C3. Language tags")
var languageTags = ["en", "en-US", "en-GB", "pt-BR", "zh-Hans", "zh-Hant-TW", "zh-Hans-CN", "es-419", "ja", "sr-Latn",
                    "x-private", "i-klingon", "und", "", "EN", "en_US", "not a tag", "de-CH-1901", "sgn-BE-FR",
                    "az-Latn-x-latn", "zh-min-nan", "ar-u-nu-latn"]
for _ in 0 ..< 2000 {
    languageTags.append(randomString(["en", "-", "US", "Hans", "x", "419", "_", "zh", "a", "Z", "1"], maxLen: 5))
}
for tag in languageTags {
    same("language", tag, languageOutcome(tag), legacyLanguageOutcome(tag))
}
print("  tags: \(languageTags.count)")

// MARK: - D. Official atproto syntax vectors

if !interopDir.isEmpty {
    print("== D. Official atproto interop syntax vectors: \(interopDir)")
    let files = (try? FileManager.default.contentsOfDirectory(atPath: interopDir))?.filter { $0.hasSuffix(".txt") }.sorted() ?? []
    var vectorCount = 0
    for file in files {
        guard let text = try? String(contentsOfFile: interopDir + "/" + file, encoding: .utf8) else { continue }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
        var agree = 0
        for line in lines {
            vectorCount += 1
            let before = failures
            switch file.split(separator: "_").first.map(String.init) ?? "" {
            case "did":
                checkValidators(line, "-interop")
                same("interop-did", line, didOutcome(line), legacyDIDOutcome(line))
            case "handle":
                checkValidators(line, "-interop")
                same("interop-handle", line, handleOutcome(line), legacyHandleOutcome(line))
            case "nsid", "recordkey":
                checkValidators(line, "-interop")
            case "aturi":
                same("interop-aturi", line, atURIOutcome(line), legacyATURIOutcome(line))
            case "atidentifier":
                same("interop-atid", line, atIdentifierOutcome(line), legacyATIdentifierOutcome(line))
            case "datetime":
                same("interop-date", line, dateBits(line), legacyDateBits(line))
            case "language":
                same("interop-lang", line, languageOutcome(line), legacyLanguageOutcome(line))
            default:
                break
            }
            if failures == before { agree += 1 }
        }
        print("  \(file): \(lines.count) vectors, new == legacy for \(agree)")
    }
    print("  total vectors: \(vectorCount)")
}

// MARK: - E. Fixture coverage and equivalence

struct Bucket { var n = 0; var fast = 0 }
var buckets: [String: Bucket] = [:]
var fixtureValues: [String: [String]] = [:]
func bump(_ key: String, _ fast: Bool) {
    var b = buckets[key, default: Bucket()]
    b.n += 1
    if fast { b.fast += 1 }
    buckets[key] = b
}

if !fixtureDir.isEmpty {
    print("== E. Fixture coverage (fast path = definitive byte answer, no legacy fallback)")
    let files = (try? FileManager.default.contentsOfDirectory(atPath: fixtureDir))?.filter { $0.hasSuffix(".json") && $0 != "manifest.json" }.sorted() ?? []
    func walk(_ v: Any, key: String?, parent: [String: Any]?) {
        if let d = v as? [String: Any] {
            for (k, x) in d { walk(x, key: k, parent: d) }
        } else if let a = v as? [Any] {
            for x in a { walk(x, key: key, parent: parent) }
        } else if let str = v as? String, let key {
            switch key {
            case "did", "src":
                bump("DID", LeafScannerProbe.didVerdict(str) != .undecided)
                fixtureValues["DID", default: []].append(str)
                same("fx-did", str, didOutcome(str), legacyDIDOutcome(str))
            case "handle":
                bump("Handle", LeafScannerProbe.handleVerdict(str) != .undecided)
                fixtureValues["Handle", default: []].append(str)
                same("fx-handle", str, handleOutcome(str), legacyHandleOutcome(str))
            case "cid", "$link":
                bump("CID", CIDScannerProbe.parsesOnFastPath(str))
                fixtureValues["CID", default: []].append(str)
                same("fx-cid", str, cidOutcome(str), legacyCIDOutcome(str))
            case "createdAt", "indexedAt", "cts":
                bump("Date", LeafScannerProbe.dateUsesFastPath(str))
                fixtureValues["Date", default: []].append(str)
                same("fx-date", str, dateBits(str), legacyDateBits(str))
            case "langs":
                bump("Language", true)
                fixtureValues["Language", default: []].append(str)
                same("fx-lang", str, languageOutcome(str), legacyLanguageOutcome(str))
            default:
                let isLinkFacet = (parent?["$type"] as? String) == "app.bsky.richtext.facet#link"
                let isLabel = parent?["val"] != nil && parent?["src"] != nil
                if ["uri", "following", "like", "repost", "followedBy", "blocking"].contains(key), str.hasPrefix("at://"),
                   !isLinkFacet, !isLabel
                {
                    bump("ATURI", LeafScannerProbe.atURIUsesFastPath(str))
                    fixtureValues["ATURI", default: []].append(str)
                    same("fx-aturi", str, atURIOutcome(str), legacyATURIOutcome(str))
                }
            }
        }
    }
    for file in files {
        guard let data = FileManager.default.contents(atPath: fixtureDir + "/" + file),
              let root = try? JSONSerialization.jsonObject(with: data)
        else { continue }
        walk(root, key: nil, parent: nil)
    }
    for (k, v) in buckets.sorted(by: { $0.key < $1.key }) {
        print("  \(k): \(v.n) values, fast path definitive for \(v.fast)")
    }
}

// MARK: - F. Instruction counts (deterministic counter, no wall-clock timing)

#if canImport(Darwin)
    func instructionsRetired() -> UInt64 {
        var info = rusage_info_v4()
        let rc = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(getpid(), RUSAGE_INFO_V4, $0)
            }
        }
        return rc == 0 ? info.ri_instructions : 0
    }

    @inline(never) func sink<T>(_ value: T) { withExtendedLifetime(value) {} }

    func measure(_ label: String, _ values: [String], legacy: (String) -> Void, new: (String) -> Void) {
        guard !values.isEmpty else { return }
        // Warm caches/lazy statics first.
        for v in values { legacy(v); new(v) }
        let calls = values.count * reps
        let l0 = instructionsRetired()
        for _ in 0 ..< reps { for v in values { legacy(v) } }
        let l1 = instructionsRetired()
        for _ in 0 ..< reps { for v in values { new(v) } }
        let n1 = instructionsRetired()
        let legacyPer = Double(l1 - l0) / Double(calls)
        let newPer = Double(n1 - l1) / Double(calls)
        print("  " + label.padding(toLength: 38, withPad: " ", startingAt: 0)
            + String(format: "calls=%7d  legacy=%9.0f  new=%8.0f instr/call  (%.1fx fewer)",
                     calls, legacyPer, newPer, legacyPer / max(newPer, 1)))
    }

    print("== F. Instructions retired per call over the fixture values (proc_pid_rusage; \(reps) reps)")
    let dids = fixtureValues["DID"] ?? []
    let handles = fixtureValues["Handle"] ?? []
    let atURIs = fixtureValues["ATURI"] ?? []
    let cids = fixtureValues["CID"] ?? []
    let dates = fixtureValues["Date"] ?? []
    let langs = fixtureValues["Language"] ?? []
    measure("DID.isValidDID", dids, legacy: { sink(LeafLegacyOracle.isValidDID($0)) }, new: { sink(DID.isValidDID($0)) })
    measure("DID(didString:)", dids, legacy: { sink(LeafLegacyOracle.parseDID($0)) }, new: { sink(try? DID(didString: $0)) })
    let parsedDIDs = dids.compactMap { try? DID(didString: $0) }
    let legacyDIDParts = dids.compactMap { LeafLegacyOracle.parseDID($0) }
    if !parsedDIDs.isEmpty {
        let l0 = instructionsRetired()
        for _ in 0 ..< reps { for p in legacyDIDParts { sink(LeafLegacyOracle.didString(p)) } }
        let l1 = instructionsRetired()
        for _ in 0 ..< reps { for d in parsedDIDs { sink(d.didString()) } }
        let n1 = instructionsRetired()
        let calls = Double(parsedDIDs.count * reps)
        print("  " + "DID.didString()".padding(toLength: 38, withPad: " ", startingAt: 0)
            + String(format: "calls=%7d  legacy=%9.0f  new=%8.0f instr/call",
                     parsedDIDs.count * reps, Double(l1 - l0) / calls, Double(n1 - l1) / calls))
    }
    measure("Handle.isValidHandle", handles, legacy: { sink(LeafLegacyOracle.isValidHandle($0)) }, new: { sink(Handle.isValidHandle($0)) })
    measure("Handle(handleString:)", handles, legacy: { sink(LeafLegacyOracle.handleValue($0)) }, new: { sink(try? Handle(handleString: $0)) })
    measure("ATProtocolURI(uriString:)", atURIs, legacy: { sink(try? LeafLegacyOracle.parseATURI($0)) }, new: { sink(try? ATProtocolURI(uriString: $0)) })
    measure("CID.parse", cids, legacy: { sink(try? LeafLegacyOracle.parseCID($0)) }, new: { sink(try? CID.parse($0)) })
    let parsedCIDs = cids.compactMap { try? CID.parse($0) }
    let legacyCIDParts = cids.compactMap { try? LeafLegacyOracle.parseCID($0) }
    if !parsedCIDs.isEmpty {
        let l0 = instructionsRetired()
        for _ in 0 ..< reps { for p in legacyCIDParts { sink(LeafLegacyOracle.cidString(p)) } }
        let l1 = instructionsRetired()
        for _ in 0 ..< reps { for c in parsedCIDs { sink(c.string) } }
        let n1 = instructionsRetired()
        let calls = Double(parsedCIDs.count * reps)
        print("  " + "CID.string".padding(toLength: 38, withPad: " ", startingAt: 0)
            + String(format: "calls=%7d  legacy=%9.0f  new=%8.0f instr/call",
                     parsedCIDs.count * reps, Double(l1 - l0) / calls, Double(n1 - l1) / calls))
    }
    measure("ATProtocolDate parse", dates, legacy: { sink(LeafLegacyOracle.parseDate($0)) }, new: { sink(ATProtocolDate(iso8601String: $0)) })
    measure("LanguageCodeContainer(languageCode:)", langs,
            legacy: { sink(Locale.Language(identifier: $0)) },
            new: { sink(LanguageCodeContainer(languageCode: $0)) })
#endif

// MARK: - G. Layout

print("== G. MemoryLayout sizes")
print("  DID \(MemoryLayout<DID>.size) B (was 56), LanguageCodeContainer \(MemoryLayout<LanguageCodeContainer>.size) B (was 112), ATProtocolURI \(MemoryLayout<ATProtocolURI>.size) B (unchanged layout), CID \(MemoryLayout<CID>.size) B, ATProtocolDate \(MemoryLayout<ATProtocolDate>.size) B")

print("== Checks: \(checks)")
print(failures == 0 ? "ALL EQUIVALENT" : "FAILURES: \(failures)")
exit(failures == 0 ? 0 : 1)
