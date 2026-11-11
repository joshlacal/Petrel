import Foundation
import Petrel

/// A Lexicon string `format`.
///
/// The eleven formats of Lexicon version 1 are available as static members.
/// Any other name can still be represented (so a schema that uses a newer or
/// experimental format can be loaded when the caller opts in through
/// ``LexiconSchemaOptions/allowUnknownStringFormats``); ``isStandard`` tells
/// the two apart.
public struct LexStringFormat: RawRepresentable, Sendable, Hashable, CustomStringConvertible {
    /// The format name as written in a Lexicon document.
    public let rawValue: String

    /// Creates a format from its name.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// `at-identifier`: a DID or a handle.
    public static let atIdentifier = LexStringFormat(rawValue: "at-identifier")
    /// `at-uri`: an AT-URI.
    public static let atURI = LexStringFormat(rawValue: "at-uri")
    /// `cid`: a CID in string form.
    public static let cid = LexStringFormat(rawValue: "cid")
    /// `datetime`: an RFC 3339 / ISO 8601 / WHATWG intersecting timestamp.
    public static let datetime = LexStringFormat(rawValue: "datetime")
    /// `did`: a DID.
    public static let did = LexStringFormat(rawValue: "did")
    /// `handle`: a handle.
    public static let handle = LexStringFormat(rawValue: "handle")
    /// `nsid`: a Namespaced Identifier.
    public static let nsid = LexStringFormat(rawValue: "nsid")
    /// `tid`: a Timestamp Identifier.
    public static let tid = LexStringFormat(rawValue: "tid")
    /// `record-key`: a record key of the general ("any") syntax.
    public static let recordKey = LexStringFormat(rawValue: "record-key")
    /// `uri`: a generic RFC 3986 URI of at most 8 KiB.
    public static let uri = LexStringFormat(rawValue: "uri")
    /// `language`: a well-formed BCP 47 language tag.
    public static let language = LexStringFormat(rawValue: "language")

    /// The formats defined by Lexicon version 1.
    public static let standard: [LexStringFormat] = [
        .atIdentifier, .atURI, .cid, .datetime, .did, .handle, .nsid, .tid, .recordKey, .uri, .language,
    ]

    /// `true` for one of the formats defined by Lexicon version 1.
    public var isStandard: Bool {
        LexStringFormat.standard.contains(self)
    }

    /// A single-line, human-readable rendering.
    public var description: String {
        rawValue
    }

    /// Checks a string against this format.
    ///
    /// Per the specification the check is syntactic and as permissive as the
    /// identifier syntax allows: any DID method passes `did`, any well-formed
    /// tag passes `language`. A format that is not ``isStandard`` places no
    /// constraint on the string and always returns `true`.
    public func isValid(_ string: String) -> Bool {
        switch self {
        case .atIdentifier:
            return LexSyntax.isATIdentifier(string) && (try? ATIdentifier(string: string)) != nil
        case .atURI:
            return LexSyntax.isATURI(string) && (try? ATProtocolURI(uriString: string)) != nil
        case .cid:
            return LexSyntax.isCIDString(string)
        case .datetime:
            return LexSyntax.isDatetime(string)
        case .did:
            return LexSyntax.isDID(string) && (try? DID(didString: string)) != nil
        case .handle:
            return LexSyntax.isHandle(string) && (try? Handle(handleString: string)) != nil
        case .nsid:
            return LexSyntax.isNSID(string) && (try? NSID(nsidString: string)) != nil
        case .tid:
            return LexSyntax.isTID(string) && (try? TID(tidString: string)) != nil
        case .recordKey:
            return LexSyntax.isRecordKey(string) && (try? RecordKey(keyString: string)) != nil
        case .uri:
            return LexSyntax.isURI(string)
        case .language:
            return LexSyntax.isLanguageTag(string)
        default:
            return true
        }
    }
}

/// Spec-exact syntax rules for the Lexicon string formats.
///
/// These are byte scanners rather than regular expressions: they have no
/// shared mutable state, behave identically on Darwin and Linux, and each one
/// is checked against every line of the matching file in
/// `atproto-interop-tests/syntax`.
enum LexSyntax {
    // MARK: Character classes

    @inline(__always) private static func isAlpha(_ byte: UInt8) -> Bool {
        (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A)
    }

    @inline(__always) private static func isLower(_ byte: UInt8) -> Bool {
        byte >= 0x61 && byte <= 0x7A
    }

    @inline(__always) private static func isDigit(_ byte: UInt8) -> Bool {
        byte >= 0x30 && byte <= 0x39
    }

    @inline(__always) private static func isAlnum(_ byte: UInt8) -> Bool {
        isAlpha(byte) || isDigit(byte)
    }

    private static let hyphen = UInt8(ascii: "-")
    private static let dot = UInt8(ascii: ".")
    private static let colon = UInt8(ascii: ":")

    /// A DNS-style label: 1–63 of `[A-Za-z0-9-]`, not starting or ending with
    /// a hyphen.
    private static func isLabel(_ label: ArraySlice<UInt8>) -> Bool {
        guard let first = label.first, let last = label.last, label.count <= 63 else { return false }
        guard first != hyphen, last != hyphen else { return false }
        return label.allSatisfy { isAlnum($0) || $0 == hyphen }
    }

    // MARK: Handle

    /// `^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$`,
    /// at most 253 characters.
    static func isHandle(_ string: String) -> Bool {
        let bytes = Array(string.utf8)
        guard !bytes.isEmpty, bytes.count <= 253 else { return false }
        let labels = bytes.split(separator: dot, omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        for label in labels where !isLabel(label) {
            return false
        }
        guard let tld = labels.last, let first = tld.first else { return false }
        return isAlpha(first)
    }

    // MARK: DID

    /// `^did:[a-z]+:[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-]$`, at most 2048 characters.
    static func isDID(_ string: String) -> Bool {
        let bytes = Array(string.utf8)
        guard bytes.count <= 2048, bytes.starts(with: Array("did:".utf8)) else { return false }
        var index = 4
        let methodStart = index
        while index < bytes.count, isLower(bytes[index]) {
            index += 1
        }
        guard index > methodStart, index < bytes.count, bytes[index] == colon else { return false }
        index += 1
        guard index < bytes.count else { return false }
        for byte in bytes[index...] {
            guard isAlnum(byte) || byte == dot || byte == UInt8(ascii: "_") || byte == colon
                || byte == UInt8(ascii: "%") || byte == hyphen
            else {
                return false
            }
        }
        guard let last = bytes.last else { return false }
        return last != colon && last != UInt8(ascii: "%")
    }

    static func isATIdentifier(_ string: String) -> Bool {
        string.hasPrefix("did:") ? isDID(string) : isHandle(string)
    }

    // MARK: NSID

    /// Authority segments (two or more labels, the first starting with a
    /// letter) followed by a name of `[a-zA-Z][a-zA-Z0-9]{0,62}`; at most 317
    /// characters.
    static func isNSID(_ string: String) -> Bool {
        let bytes = Array(string.utf8)
        guard !bytes.isEmpty, bytes.count <= 317 else { return false }
        let segments = bytes.split(separator: dot, omittingEmptySubsequences: false)
        guard segments.count >= 3 else { return false }
        for segment in segments.dropLast() where !isLabel(segment) {
            return false
        }
        guard let first = segments.first?.first, isAlpha(first) else { return false }
        guard let name = segments.last, let nameFirst = name.first, name.count <= 63 else { return false }
        return isAlpha(nameFirst) && name.allSatisfy(isAlnum)
    }

    // MARK: TID

    /// `^[234567abcdefghij][234567abcdefghijklmnopqrstuvwxyz]{12}$`.
    static func isTID(_ string: String) -> Bool {
        let bytes = Array(string.utf8)
        guard bytes.count == 13 else { return false }
        func isBase32Sortable(_ byte: UInt8) -> Bool {
            (byte >= UInt8(ascii: "2") && byte <= UInt8(ascii: "7")) || isLower(byte)
        }
        guard isBase32Sortable(bytes[0]), bytes[0] <= UInt8(ascii: "j") else { return false }
        return bytes.allSatisfy(isBase32Sortable)
    }

    // MARK: Record key

    /// `^[a-zA-Z0-9_~.:-]{1,512}$`, excluding `.` and `..`.
    static func isRecordKey(_ string: String) -> Bool {
        let bytes = Array(string.utf8)
        guard !bytes.isEmpty, bytes.count <= 512, string != ".", string != ".." else { return false }
        return bytes.allSatisfy { byte in
            isAlnum(byte) || byte == UInt8(ascii: "_") || byte == UInt8(ascii: "~") || byte == dot
                || byte == colon || byte == hyphen
        }
    }

    // MARK: AT-URI

    /// AT-URI in its strict Lexicon form: `at://<did-or-handle>` optionally
    /// followed by `/<nsid>` and `/<record-key>`, optionally followed by a
    /// `#/json/pointer` fragment. No trailing slash, no query, at most 8 KiB.
    static func isATURI(_ string: String) -> Bool {
        let bytes = Array(string.utf8)
        guard bytes.count <= 8192, bytes.starts(with: Array("at://".utf8)) else { return false }
        let allowed = Set("._~:@!$&'()*+,;=%/\\[]#?-".utf8)
        guard bytes.allSatisfy({ isAlnum($0) || allowed.contains($0) }) else { return false }
        var rest = bytes[5...]
        var fragment: ArraySlice<UInt8>?
        if let hash = rest.firstIndex(of: UInt8(ascii: "#")) {
            fragment = rest[(hash + 1)...]
            rest = rest[..<hash]
        }
        guard !rest.contains(UInt8(ascii: "?")) else { return false }
        let parts = rest.split(separator: UInt8(ascii: "/"), omittingEmptySubsequences: false)
        guard (1 ... 3).contains(parts.count), parts.allSatisfy({ !$0.isEmpty }) else { return false }
        guard isATIdentifier(String(decoding: parts[0], as: UTF8.self)) else { return false }
        if parts.count >= 2, !isNSID(String(decoding: parts[1], as: UTF8.self)) {
            return false
        }
        if parts.count == 3, !isRecordKey(String(decoding: parts[2], as: UTF8.self)) {
            return false
        }
        if let fragment {
            return isJSONPointerFragment(Array(fragment))
        }
        return true
    }

    /// `^\/[a-zA-Z0-9._~:@!$&')(*+,;=%[\]/-]*$` with well-formed
    /// percent-encoding that decodes to UTF-8.
    private static func isJSONPointerFragment(_ bytes: [UInt8]) -> Bool {
        guard bytes.first == UInt8(ascii: "/") else { return false }
        let allowed = Set("._~:@!$&')(*+,;=%[]/-".utf8)
        guard bytes.allSatisfy({ isAlnum($0) || allowed.contains($0) }) else { return false }
        var decoded = [UInt8]()
        var index = 0
        while index < bytes.count {
            if bytes[index] == UInt8(ascii: "%") {
                guard index + 2 < bytes.count,
                      let high = hexValue(bytes[index + 1]), let low = hexValue(bytes[index + 2])
                else {
                    return false
                }
                decoded.append(high << 4 | low)
                index += 3
            } else {
                decoded.append(bytes[index])
                index += 1
            }
        }
        return String(validatingUTF8Bytes: decoded) != nil
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case UInt8(ascii: "0") ... UInt8(ascii: "9"): return byte - UInt8(ascii: "0")
        case UInt8(ascii: "a") ... UInt8(ascii: "f"): return byte - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A") ... UInt8(ascii: "F"): return byte - UInt8(ascii: "A") + 10
        default: return nil
        }
    }

    // MARK: CID (string format)

    /// The generic CID string syntax: 8–256 characters of `[a-zA-Z0-9+=]`,
    /// excluding CIDv0 (`Qm…`). This is deliberately a syntax check only: the
    /// `cid` format admits any multibase encoding, unlike a `cid-link`, which
    /// must be a blessed CID.
    static func isCIDString(_ string: String) -> Bool {
        let bytes = Array(string.utf8)
        guard (8 ... 256).contains(bytes.count), !string.hasPrefix("Qm") else { return false }
        return bytes.allSatisfy { isAlnum($0) || $0 == UInt8(ascii: "+") || $0 == UInt8(ascii: "=") }
    }

    // MARK: URI

    /// RFC 3986 `scheme ":" hier-part` with a non-empty remainder free of
    /// whitespace and control characters; at most 8 KiB (8192 bytes).
    static func isURI(_ string: String) -> Bool {
        let bytes = Array(string.utf8)
        guard bytes.count <= 8192, let first = bytes.first, isAlpha(first) else { return false }
        guard let separator = bytes.firstIndex(of: colon) else { return false }
        for byte in bytes[..<separator] {
            guard isAlnum(byte) || byte == UInt8(ascii: "+") || byte == hyphen || byte == dot else { return false }
        }
        let rest = bytes[(separator + 1)...]
        guard !rest.isEmpty else { return false }
        for scalar in string.unicodeScalars where scalar.properties.isWhitespace || scalar.value < 0x20 || scalar.value == 0x7F {
            return false
        }
        return true
    }

    // MARK: Language

    private static let grandfatheredTags: Set<String> = [
        "en-GB-oed", "i-ami", "i-bnn", "i-default", "i-enochian", "i-hak", "i-klingon", "i-lux", "i-mingo",
        "i-navajo", "i-pwn", "i-tao", "i-tay", "i-tsu", "sgn-BE-FR", "sgn-BE-NL", "sgn-CH-DE",
        "art-lojban", "cel-gaulish", "no-bok", "no-nyn", "zh-guoyu", "zh-hakka", "zh-min", "zh-min-nan", "zh-xiang",
    ]

    /// A well-formed BCP 47 (RFC 5646 §2.1) language tag.
    ///
    /// Two deliberate narrowings, both required by the official
    /// `language_syntax_invalid.txt` vectors: the primary language subtag must
    /// be a lower-case two- or three-letter code (`JA` is rejected), and the
    /// reserved four-letter and unregistered five-to-eight-letter primary
    /// subtags are rejected (`jaja`). Repeated variants or extension singletons
    /// are "well-formed but not valid" and pass, as in `@atproto/syntax`.
    static func isLanguageTag(_ string: String) -> Bool {
        if grandfatheredTags.contains(string) {
            return true
        }
        let bytes = Array(string.utf8)
        guard !bytes.isEmpty else { return false }
        let subtags = bytes.split(separator: hyphen, omittingEmptySubsequences: false).map(Array.init)
        guard subtags.allSatisfy({ (1 ... 8).contains($0.count) && $0.allSatisfy(isAlnum) }) else { return false }

        func isPrivateUseMarker(_ subtag: [UInt8]) -> Bool {
            subtag == [UInt8(ascii: "x")] || subtag == [UInt8(ascii: "X")]
        }

        // privateuse = "x" 1*("-" (1*8alphanum))
        if isPrivateUseMarker(subtags[0]) {
            return subtags.count >= 2
        }

        guard (2 ... 3).contains(subtags[0].count), subtags[0].allSatisfy(isLower) else { return false }
        var index = 1

        // extlang = 3ALPHA *2("-" 3ALPHA)
        var extlangs = 0
        while extlangs < 3, index < subtags.count, subtags[index].count == 3, subtags[index].allSatisfy(isAlpha) {
            index += 1
            extlangs += 1
        }
        // script = 4ALPHA
        if index < subtags.count, subtags[index].count == 4, subtags[index].allSatisfy(isAlpha) {
            index += 1
        }
        // region = 2ALPHA / 3DIGIT
        if index < subtags.count {
            let subtag = subtags[index]
            if (subtag.count == 2 && subtag.allSatisfy(isAlpha)) || (subtag.count == 3 && subtag.allSatisfy(isDigit)) {
                index += 1
            }
        }
        // variant = 5*8alphanum / (DIGIT 3alphanum)
        while index < subtags.count {
            let subtag = subtags[index]
            guard (5 ... 8).contains(subtag.count) || (subtag.count == 4 && isDigit(subtag[0])) else { break }
            index += 1
        }
        // extension = singleton 1*("-" (2*8alphanum))
        while index < subtags.count, subtags[index].count == 1, !isPrivateUseMarker(subtags[index]) {
            index += 1
            var parts = 0
            while index < subtags.count, (2 ... 8).contains(subtags[index].count) {
                index += 1
                parts += 1
            }
            guard parts >= 1 else { return false }
        }
        // privateuse
        if index < subtags.count, isPrivateUseMarker(subtags[index]) {
            return index + 1 < subtags.count
        }
        return index == subtags.count
    }

    // MARK: Datetime

    /// `YYYY-MM-DDTHH:MM:SS[.fraction](Z|±HH:MM)`: the intersection of RFC
    /// 3339, ISO 8601 and WHATWG. Upper-case `T` and `Z`, at most 64
    /// characters, no `-00:00`, calendar-valid, and not before year 0000 or
    /// after year 9999 once normalised to UTC.
    static func isDatetime(_ string: String) -> Bool {
        let bytes = Array(string.utf8)
        guard bytes.count >= 20, bytes.count <= 64 else { return false }

        func number(_ range: Range<Int>) -> Int? {
            var value = 0
            for index in range {
                guard index < bytes.count, isDigit(bytes[index]) else { return nil }
                value = value * 10 + Int(bytes[index] - 0x30)
            }
            return value
        }

        guard let year = number(0 ..< 4), bytes[4] == hyphen,
              let month = number(5 ..< 7), bytes[7] == hyphen,
              let day = number(8 ..< 10), bytes[10] == UInt8(ascii: "T"),
              let hour = number(11 ..< 13), bytes[13] == colon,
              let minute = number(14 ..< 16), bytes[16] == colon,
              let second = number(17 ..< 19)
        else {
            return false
        }
        guard (1 ... 12).contains(month), hour <= 23, minute <= 59, second <= 60 else { return false }
        guard day >= 1, day <= daysInMonth(month, year: year) else { return false }

        var index = 19
        if index < bytes.count, bytes[index] == dot {
            index += 1
            let fractionStart = index
            while index < bytes.count, isDigit(bytes[index]) {
                index += 1
            }
            guard index > fractionStart else { return false }
        }
        guard index < bytes.count else { return false }

        var offsetMinutes = 0
        if bytes[index] == UInt8(ascii: "Z") {
            guard index + 1 == bytes.count else { return false }
        } else {
            let sign = bytes[index]
            guard sign == UInt8(ascii: "+") || sign == hyphen, index + 6 == bytes.count,
                  let offsetHour = number(index + 1 ..< index + 3), bytes[index + 3] == colon,
                  let offsetMinute = number(index + 4 ..< index + 6),
                  offsetHour <= 23, offsetMinute <= 59
            else {
                return false
            }
            offsetMinutes = offsetHour * 60 + offsetMinute
            if sign == hyphen {
                // "-00:00" is RFC 3339's "unknown offset", which ISO 8601 forbids.
                guard offsetMinutes != 0 else { return false }
                offsetMinutes = -offsetMinutes
            }
        }

        // Normalise to UTC and require the result to stay within years 0000–9999.
        let localMinutes = daysFromCivil(year: year, month: month, day: day) * 1440 + hour * 60 + minute
        let utcMinutes = localMinutes - offsetMinutes
        let lowerBound = daysFromCivil(year: 0, month: 1, day: 1) * 1440
        let upperBound = daysFromCivil(year: 10000, month: 1, day: 1) * 1440
        return utcMinutes >= lowerBound && utcMinutes < upperBound
    }

    private static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    private static func daysInMonth(_ month: Int, year: Int) -> Int {
        switch month {
        case 2: return isLeapYear(year) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    /// Days since 1970-01-01 in the proleptic Gregorian calendar.
    private static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let adjustedYear = month <= 2 ? year - 1 : year
        let era = (adjustedYear >= 0 ? adjustedYear : adjustedYear - 399) / 400
        let yearOfEra = adjustedYear - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }
}
