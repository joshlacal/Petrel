//
//  ATProtoSyntax.swift
//
//  Byte-level validators for the AT Protocol identifier grammars.
//
//  Every grammar here is ASCII-only, so validation runs over UTF-8 bytes. That
//  rules out a class of bugs regular expressions invite: `$` matching before a
//  final line terminator, `Character`-level checks treating "\r\n" as one ASCII
//  character, and Unicode look-alikes slipping through case-insensitive classes.
//

import Foundation

// MARK: - Byte classes

enum SyntaxByte {
    static let percent: UInt8 = 0x25
    static let plus: UInt8 = 0x2B
    static let hyphen: UInt8 = 0x2D
    static let dot: UInt8 = 0x2E
    static let slash: UInt8 = 0x2F
    static let colon: UInt8 = 0x3A
    static let equals: UInt8 = 0x3D
    static let underscore: UInt8 = 0x5F
    static let tilde: UInt8 = 0x7E

    @inline(__always) static func isLower(_ byte: UInt8) -> Bool {
        byte >= 0x61 && byte <= 0x7A
    }

    @inline(__always) static func isUpper(_ byte: UInt8) -> Bool {
        byte >= 0x41 && byte <= 0x5A
    }

    @inline(__always) static func isAlpha(_ byte: UInt8) -> Bool {
        isLower(byte) || isUpper(byte)
    }

    @inline(__always) static func isDigit(_ byte: UInt8) -> Bool {
        byte >= 0x30 && byte <= 0x39
    }

    @inline(__always) static func isAlphanumeric(_ byte: UInt8) -> Bool {
        isAlpha(byte) || isDigit(byte)
    }
}

/// Runs `body` over the UTF-8 bytes of `string` without copying when the string
/// has contiguous storage (the common case).
@inline(__always)
func withSyntaxBytes<Result>(
    _ string: String,
    _ body: (UnsafeBufferPointer<UInt8>) -> Result
) -> Result {
    if let result = string.utf8.withContiguousStorageIfAvailable(body) {
        return result
    }
    return Array(string.utf8).withUnsafeBufferPointer(body)
}

/// Quotes an input for an error message, shortened so that an 8 KB rejected
/// value does not end up verbatim in logs.
func syntaxExcerpt(_ input: String) -> String {
    let limit = 80
    guard input.count > limit else { return "\"\(input)\"" }
    return "\"\(input.prefix(limit))…\" (\(input.utf8.count) bytes)"
}

// MARK: - Grammar scanners

/// Each scanner returns `nil` when the input is valid, or the reason it is not.
enum ATProtoSyntax {
    // MARK: DID

    /// https://atproto.com/specs/did — "DID Identifier Syntax".
    static func didFailure(_ did: String) -> String? {
        withSyntaxBytes(did) { bytes -> String? in
            let count = bytes.count
            guard count <= 2048 else { return "longer than 2048 characters" }
            guard count >= 4, bytes[0] == 0x64, bytes[1] == 0x69, bytes[2] == 0x64,
                  bytes[3] == SyntaxByte.colon
            else {
                return "must start with lowercase \"did:\""
            }

            var index = 4
            while index < count, SyntaxByte.isLower(bytes[index]) {
                index += 1
            }
            guard index > 4 else { return "method must be one or more lowercase letters" }
            guard index < count, bytes[index] == SyntaxByte.colon else {
                return "method must be lowercase letters followed by \":\""
            }
            index += 1
            guard index < count else { return "method-specific identifier is empty" }

            while index < count {
                let byte = bytes[index]
                guard SyntaxByte.isAlphanumeric(byte) || byte == SyntaxByte.dot
                    || byte == SyntaxByte.underscore || byte == SyntaxByte.colon
                    || byte == SyntaxByte.percent || byte == SyntaxByte.hyphen
                else {
                    return "contains a character outside A-Z a-z 0-9 . _ : % -"
                }
                index += 1
            }

            let last = bytes[count - 1]
            guard last != SyntaxByte.colon, last != SyntaxByte.percent else {
                return "must not end in \":\" or \"%\""
            }
            return nil
        }
    }

    // MARK: Handle

    /// https://atproto.com/specs/handle — "Handle Identifier Syntax".
    static func handleFailure(_ handle: String) -> String? {
        withSyntaxBytes(handle) { bytes -> String? in
            let count = bytes.count
            guard count > 0 else { return "is empty" }
            guard count <= 253 else { return "longer than 253 characters" }

            var labelCount = 0
            var labelStart = 0
            var lastLabelStart = 0
            for index in 0 ... count {
                if index == count || bytes[index] == SyntaxByte.dot {
                    let length = index - labelStart
                    guard length >= 1 else { return "has an empty label" }
                    guard length <= 63 else { return "has a label longer than 63 characters" }
                    guard bytes[labelStart] != SyntaxByte.hyphen, bytes[index - 1] != SyntaxByte.hyphen else {
                        return "has a label that starts or ends with a hyphen"
                    }
                    labelCount += 1
                    lastLabelStart = labelStart
                    labelStart = index + 1
                } else {
                    let byte = bytes[index]
                    guard SyntaxByte.isAlphanumeric(byte) || byte == SyntaxByte.hyphen else {
                        return "contains a character outside A-Z a-z 0-9 . -"
                    }
                }
            }

            guard labelCount >= 2 else { return "needs at least two labels" }
            guard SyntaxByte.isAlpha(bytes[lastLabelStart]) else {
                return "top-level domain must start with a letter"
            }
            return nil
        }
    }

    // MARK: NSID

    /// https://atproto.com/specs/nsid — "NSID Syntax".
    static func nsidFailure(_ nsid: String) -> String? {
        withSyntaxBytes(nsid) { bytes -> String? in
            let count = bytes.count
            guard count > 0 else { return "is empty" }
            guard count <= 317 else { return "longer than 317 characters" }

            var segmentCount = 0
            var segmentStart = 0
            var lastSegmentStart = 0
            for index in 0 ... count {
                if index == count || bytes[index] == SyntaxByte.dot {
                    let length = index - segmentStart
                    guard length >= 1 else { return "has an empty segment" }
                    guard length <= 63 else { return "has a segment longer than 63 characters" }
                    guard bytes[segmentStart] != SyntaxByte.hyphen, bytes[index - 1] != SyntaxByte.hyphen else {
                        return "has a segment that starts or ends with a hyphen"
                    }
                    segmentCount += 1
                    lastSegmentStart = segmentStart
                    segmentStart = index + 1
                } else {
                    let byte = bytes[index]
                    guard SyntaxByte.isAlphanumeric(byte) || byte == SyntaxByte.hyphen else {
                        return "contains a character outside A-Z a-z 0-9 . -"
                    }
                }
            }

            guard segmentCount >= 3 else { return "needs at least three segments" }
            guard SyntaxByte.isAlpha(bytes[0]) else {
                return "first segment must start with a letter"
            }
            // The specification text caps the domain authority at 253 characters, but
            // the official nsid_syntax_valid vectors include a 317-character NSID whose
            // authority is longer, and the reference implementation enforces only the
            // 317 total. The vectors are followed here.
            guard SyntaxByte.isAlpha(bytes[lastSegmentStart]) else {
                return "name segment must start with a letter"
            }
            for index in lastSegmentStart ..< count where !SyntaxByte.isAlphanumeric(bytes[index]) {
                return "name segment must contain only letters and digits"
            }
            return nil
        }
    }

    // MARK: Record key

    /// https://atproto.com/specs/record-key — "Record Key Syntax".
    static func recordKeyFailure(_ key: String) -> String? {
        withSyntaxBytes(key) { bytes -> String? in
            let count = bytes.count
            guard count >= 1 else { return "is empty" }
            guard count <= 512 else { return "longer than 512 characters" }
            for byte in bytes {
                guard SyntaxByte.isAlphanumeric(byte) || byte == SyntaxByte.dot
                    || byte == SyntaxByte.hyphen || byte == SyntaxByte.underscore
                    || byte == SyntaxByte.colon || byte == SyntaxByte.tilde
                else {
                    return "contains a character outside A-Z a-z 0-9 . - _ : ~"
                }
            }
            if count <= 2, bytes.allSatisfy({ $0 == SyntaxByte.dot }) {
                return "must not be \".\" or \"..\""
            }
            return nil
        }
    }

    // MARK: TID

    /// The base32-sortable alphabet, in value order.
    static let tidAlphabet: [UInt8] = Array("234567abcdefghijklmnopqrstuvwxyz".utf8)

    /// Value of one base32-sortable character, or `nil` if the byte is outside the alphabet.
    @inline(__always) static func tidDigit(_ byte: UInt8) -> UInt64? {
        switch byte {
        case 0x32 ... 0x37: return UInt64(byte - 0x32)
        case 0x61 ... 0x7A: return UInt64(byte - 0x61) + 6
        default: return nil
        }
    }

    /// https://atproto.com/specs/tid — "TID Syntax". Returns the decoded 64-bit value.
    static func tidValue(_ tid: String) -> Result<UInt64, SyntaxFailure> {
        withSyntaxBytes(tid) { bytes -> Result<UInt64, SyntaxFailure> in
            guard bytes.count == 13 else { return .failure("must be exactly 13 characters") }
            var value: UInt64 = 0
            for byte in bytes {
                guard let digit = tidDigit(byte) else {
                    return .failure("contains a character outside 234567abcdefghijklmnopqrstuvwxyz")
                }
                value = value << 5 | digit
            }
            // 13 characters carry 65 bits, so the first may only use its low four.
            guard let first = tidDigit(bytes[0]), first < 16 else {
                return .failure("first character must be one of 234567abcdefghij")
            }
            return .success(value)
        }
    }

    /// Encodes a 64-bit value as 13 base32-sortable characters.
    static func tidString(_ value: UInt64) -> String {
        var bytes = [UInt8](repeating: 0x32, count: 13)
        var remaining = value
        var index = 12
        while index >= 0 {
            bytes[index] = tidAlphabet[Int(remaining & 0x1F)]
            remaining >>= 5
            index -= 1
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    // MARK: CID (string form)

    /// Syntax-level check for the Lexicon `cid` string format, matching the
    /// official `cid_syntax_*` vectors: 8–256 characters from `A-Z a-z 0-9 + =`,
    /// and not a CIDv0 (`Qm…`, 46 base58btc characters).
    static func cidFailure(_ cid: String) -> String? {
        withSyntaxBytes(cid) { bytes -> String? in
            let count = bytes.count
            guard count >= 8 else { return "shorter than 8 characters" }
            guard count <= 256 else { return "longer than 256 characters" }
            for byte in bytes {
                guard SyntaxByte.isAlphanumeric(byte) || byte == SyntaxByte.plus || byte == SyntaxByte.equals else {
                    return "contains a character outside A-Z a-z 0-9 + ="
                }
            }
            if count == 46, bytes[0] == 0x51, bytes[1] == 0x6D {
                return "CIDv0 (\"Qm…\") is not supported"
            }
            return nil
        }
    }

    // MARK: Generic URI

    /// Syntax-level check for the Lexicon `uri` string format: an RFC 3986 scheme,
    /// a colon, and a non-empty remainder with no whitespace or control
    /// characters, at most 8 KB in total.
    static func uriFailure(_ uri: String) -> String? {
        guard uri.utf8.count <= 8192 else { return "longer than 8192 bytes" }

        let scalars = uri.unicodeScalars
        var index = scalars.startIndex
        guard index < scalars.endIndex, isASCIIAlpha(scalars[index]) else {
            return "must start with a scheme (a letter, then letters, digits, \"+\", \"-\" or \".\")"
        }
        index = scalars.index(after: index)
        while index < scalars.endIndex, scalars[index] != ":" {
            let scalar = scalars[index]
            guard isASCIIAlpha(scalar) || isASCIIDigit(scalar) || scalar == "+" || scalar == "-" || scalar == "."
            else {
                return "scheme contains a character other than a letter, digit, \"+\", \"-\" or \".\""
            }
            index = scalars.index(after: index)
        }
        guard index < scalars.endIndex else { return "has no scheme" }
        index = scalars.index(after: index) // the colon

        var remainder = scalars[index...]
        for scalar in remainder {
            guard !scalar.properties.isWhitespace, scalar != "\u{FEFF}",
                  scalar.properties.generalCategory != .control
            else {
                return "contains whitespace or a control character"
            }
        }
        if remainder.starts(with: "//".unicodeScalars) {
            remainder = remainder.dropFirst(2)
        }
        guard !remainder.isEmpty else { return "has nothing after the scheme" }
        return nil
    }

    @inline(__always) private static func isASCIIAlpha(_ scalar: Unicode.Scalar) -> Bool {
        (scalar.value >= 0x41 && scalar.value <= 0x5A) || (scalar.value >= 0x61 && scalar.value <= 0x7A)
    }

    @inline(__always) private static func isASCIIDigit(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 0x30 && scalar.value <= 0x39
    }
}

/// A validation failure carrying its reason; expressible by a string literal
/// (with interpolation) so scanners can write `.failure("reason")`.
struct SyntaxFailure: Error, ExpressibleByStringInterpolation {
    let reason: String

    init(stringLiteral value: String) {
        reason = value
    }
}

// MARK: - CID string syntax

/// Syntax-level validation of the Lexicon `cid` string format.
///
/// This answers "is this string shaped like a CID?" the way the official
/// `cid_syntax_valid.txt` / `cid_syntax_invalid.txt` interop vectors define it:
/// 8 to 256 characters drawn from `A-Z a-z 0-9 + =`, excluding CIDv0 (`Qm…`).
/// Any multibase encoding passes, so base32 (`b…`), base58btc (`z…`), base64
/// (`m…`), base16 (`f…`) and base8 (`7…`) are all accepted.
///
/// It is deliberately separate from ``CID/parse(_:)``, which decodes a CID and
/// accepts only the forms AT Protocol repositories use (CIDv1, base32, known
/// codecs). Use `CIDSyntax` to validate a `format: cid` string field, and
/// `CID.parse` when the bytes are needed.
public enum CIDSyntax {
    /// Whether `string` has valid Lexicon `cid` string syntax.
    public static func isValid(_ string: String) -> Bool {
        ATProtoSyntax.cidFailure(string) == nil
    }

    /// Throws ``ATProtocolError/invalidCID(_:)`` unless `string` has valid
    /// Lexicon `cid` string syntax.
    public static func validate(_ string: String) throws {
        if let reason = ATProtoSyntax.cidFailure(string) {
            throw ATProtocolError.invalidCID("Invalid CID string \(syntaxExcerpt(string)): \(reason)")
        }
    }
}
