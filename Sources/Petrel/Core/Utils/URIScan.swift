//
//  URIScan.swift
//
//  Byte-level fast paths for decoding `URI` (lexicon `format: uri`) values.
//
//  Contract: every routine here either returns exactly what the legacy code path
//  returns, or declines (`nil`) so the caller runs that legacy code unchanged.
//  Only the "decided" direction needs an equivalence argument; anything unusual
//  (non-ASCII near the scheme, percent escapes, ports, userinfo, IDNA, IPv6...)
//  is routed to the original `String.range(of:options:)` / `URLComponents` code.
//
//  The scanners take `UnsafeBufferPointer<UInt8>` from
//  `utf8.withContiguousStorageIfAvailable`, which back-deploys to Petrel's
//  iOS 18 / macOS 15 floor (`String.utf8.span` needs iOS/macOS 26), so moving
//  them to `Span<UInt8>` later is mechanical.
//

import Foundation

enum URIScan {
    typealias Bytes = UnsafeBufferPointer<UInt8>

    /// The fields the legacy decoder read out of `URLComponents(string:)`:
    /// `scheme`, `host`, `path` (nil when empty), `query` and `fragment`.
    struct Parts: Equatable, Sendable {
        let scheme: String?
        let host: String?
        let path: String?
        let query: String?
        let fragment: String?
    }

    /// Outcome of the generic (non-`did:`, non-`at://`) branch of `URI` parsing.
    enum Generic: Equatable, Sendable {
        /// Empty, `//`-prefixed, or no RFC 3986 scheme: callers substitute the
        /// benign `https://invalid.invalid` placeholder.
        case invalid
        /// A scheme was detected. `nil` means `URLComponents(string:)` returned nil.
        case parts(Parts?)
    }

    // MARK: Trimming

    /// Same result as `s.trimmingCharacters(in: .whitespacesAndNewlines)`.
    ///
    /// That character set contains only U+0009–U+000D, U+0020 and non-ASCII
    /// scalars. When the first and last UTF-8 bytes are printable ASCII
    /// (0x21–0x7E) the first and last scalars are those bytes, so nothing can be
    /// trimmed and `s` is returned as-is, without Foundation's scan and copy.
    @inline(__always)
    static func trimmingWhitespaceAndNewlines(_ s: String) -> String {
        let utf8 = s.utf8
        if let first = utf8.first, let last = utf8.last,
           isPrintableASCII(first), isPrintableASCII(last)
        {
            return s
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Generic URI branch

    /// Classifies and splits a trimmed, non-`did:`, non-`at://` string exactly as
    /// the legacy `raw.isEmpty || raw.hasPrefix("//") || detectScheme(raw) == nil`
    /// test followed by `URLComponents(string: raw)` did.
    static func parseGeneric(_ raw: String) -> Generic {
        if raw.isEmpty {
            return .invalid
        }
        let decided: Generic?? = raw.utf8.withContiguousStorageIfAvailable { u -> Generic? in
            switch schemeMatch(u) {
            case .some(false):
                return .invalid
            case .some(true):
                if let simple = simpleHTTP(u) {
                    return .parts(simple)
                }
                return .parts(componentsParts(raw))
            case .none:
                return nil
            }
        }
        if let decided = decided ?? nil {
            return decided
        }
        if raw.hasPrefix("//") || legacyDetectScheme(raw) == nil {
            return .invalid
        }
        return .parts(componentsParts(raw))
    }

    /// The original `URLComponents` read-out (one parse, each getter read once).
    static func componentsParts(_ raw: String) -> Parts? {
        guard let comps = URLComponents(string: raw) else { return nil }
        let path = comps.path
        return Parts(
            scheme: comps.scheme,
            host: comps.host,
            path: path.isEmpty ? nil : path,
            query: comps.query,
            fragment: comps.fragment
        )
    }

    /// The original scheme detector, kept verbatim for the inputs `schemeMatch`
    /// defers on. Note `String.range(of:options: .regularExpression)` builds its
    /// regex on every call; this is now reached only for non-ASCII scheme
    /// candidates and non-contiguous (bridged) strings.
    static func legacyDetectScheme(_ s: String) -> String? {
        // scheme = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." ) ':'
        let pattern = "^[A-Za-z][A-Za-z0-9+.-]*:"
        return s.range(of: pattern, options: .regularExpression).map { _ in String(s.prefix { $0 != ":" }) }
    }

    /// Byte evaluation of the legacy `^[A-Za-z][A-Za-z0-9+.-]*:` test.
    ///
    /// - Returns: `true`/`false` when the answer is the same under scalar
    ///   (ICU) and grapheme-cluster (Swift `Regex`) matching, `nil` otherwise.
    ///
    /// Every byte examined before the decision is ASCII, and ASCII scalars always
    /// start a new grapheme cluster after an ASCII letter/digit/`+.-`, so each
    /// examined byte is a whole `Character`. The scan defers (`nil`) on a
    /// non-ASCII byte inside the candidate scheme, and on a non-ASCII byte right
    /// after the `:` (a combining mark there would fuse the colon into a
    /// multi-scalar `Character` that a grapheme-semantic regex does not match).
    static func schemeMatch(_ u: Bytes) -> Bool? {
        guard let first = u.first else { return false }
        guard first < 0x80 else { return nil }
        guard isAlpha(first) else { return false }
        var i = 1
        let n = u.count
        while i < n {
            let b = u[i]
            if b == 0x3A {
                if i + 1 < n, u[i + 1] >= 0x80 {
                    return nil
                }
                return true
            }
            if b >= 0x80 {
                return nil
            }
            guard isAlnum(b) || b == 0x2B || b == 0x2E || b == 0x2D else { return false }
            i += 1
        }
        return false
    }

    // MARK: Simple http(s) split

    /// Splits a "boring" `http://` / `https://` URL by bytes, producing the same
    /// `Parts` that `URLComponents(string:)` reports for it, or returns nil so the
    /// caller uses `URLComponents`.
    ///
    /// Eligible input only: lowercase LDH host labels (1–63 bytes, no leading or
    /// trailing `-`, no `xn--` A-label), so no userinfo, port, IPv6 literal or IDNA
    /// decoding; path, query and fragment bytes drawn from unreserved, sub-delims,
    /// `:`, `@`, `/` (and `?` after the path) with no `%`, so the getters'
    /// percent-decoding is the identity. Equality with `URLComponents` is checked
    /// by `URIScanTests` on every platform the tests run on.
    static func simpleHTTP(_ u: Bytes) -> Parts? {
        let n = u.count
        var p: Int
        let scheme: String
        if n > 8, u[0] == 0x68, u[1] == 0x74, u[2] == 0x74, u[3] == 0x70, u[4] == 0x73,
           u[5] == 0x3A, u[6] == 0x2F, u[7] == 0x2F
        {
            p = 8
            scheme = "https"
        } else if n > 7, u[0] == 0x68, u[1] == 0x74, u[2] == 0x74, u[3] == 0x70,
                  u[4] == 0x3A, u[5] == 0x2F, u[6] == 0x2F
        {
            p = 7
            scheme = "http"
        } else {
            return nil
        }

        let hostStart = p
        var labelStart = p
        while p < n, u[p] != 0x2F, u[p] != 0x3F, u[p] != 0x23 {
            let b = u[p]
            if b == 0x2E {
                guard isSimpleLabel(u, labelStart, p) else { return nil }
                labelStart = p + 1
            } else {
                guard isLower(b) || isDigit(b) || b == 0x2D else { return nil }
            }
            p += 1
        }
        guard p > hostStart, isSimpleLabel(u, labelStart, p) else { return nil }
        let hostEnd = p

        let pathStart = p
        while p < n, u[p] != 0x3F, u[p] != 0x23 {
            guard isPathByte(u[p]) else { return nil }
            p += 1
        }
        let pathEnd = p

        var query: String?
        if p < n, u[p] == 0x3F {
            p += 1
            let start = p
            while p < n, u[p] != 0x23 {
                guard isPathByte(u[p]) || u[p] == 0x3F else { return nil }
                p += 1
            }
            query = string(u, start, p)
        }
        var fragment: String?
        if p < n, u[p] == 0x23 {
            p += 1
            let start = p
            while p < n {
                guard isPathByte(u[p]) || u[p] == 0x3F else { return nil }
                p += 1
            }
            fragment = string(u, start, p)
        }
        return Parts(
            scheme: scheme,
            host: string(u, hostStart, hostEnd),
            path: pathEnd > pathStart ? string(u, pathStart, pathEnd) : nil,
            query: query,
            fragment: fragment
        )
    }

    // MARK: Byte classes

    @inline(__always) private static func isPrintableASCII(_ b: UInt8) -> Bool {
        b &- 0x21 < 0x5E
    }

    @inline(__always) private static func isLower(_ b: UInt8) -> Bool {
        b &- 0x61 < 26
    }

    @inline(__always) private static func isUpper(_ b: UInt8) -> Bool {
        b &- 0x41 < 26
    }

    @inline(__always) private static func isAlpha(_ b: UInt8) -> Bool {
        isLower(b) || isUpper(b)
    }

    @inline(__always) private static func isDigit(_ b: UInt8) -> Bool {
        b &- 0x30 < 10
    }

    @inline(__always) private static func isAlnum(_ b: UInt8) -> Bool {
        isAlpha(b) || isDigit(b)
    }

    /// unreserved / sub-delims / ":" / "@" / "/" — deliberately without "%".
    @inline(__always) private static func isPathByte(_ b: UInt8) -> Bool {
        if isAlnum(b) {
            return true
        }
        switch b {
        case 0x2D, 0x2E, 0x5F, 0x7E, // - . _ ~
             0x21, 0x24, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x3B, 0x3D, // ! $ & ' ( ) * + , ; =
             0x3A, 0x40, 0x2F: // : @ /
            return true
        default:
            return false
        }
    }

    /// A host label of 1–63 bytes with no leading/trailing '-' and no `xn--` prefix.
    @inline(__always) private static func isSimpleLabel(_ u: Bytes, _ start: Int, _ end: Int) -> Bool {
        let length = end - start
        guard length >= 1, length <= 63, u[start] != 0x2D, u[end - 1] != 0x2D else { return false }
        if length >= 4, u[start] == 0x78, u[start + 1] == 0x6E, u[start + 2] == 0x2D, u[start + 3] == 0x2D {
            return false
        }
        return true
    }

    @inline(__always) private static func string(_ u: Bytes, _ start: Int, _ end: Int) -> String {
        String(decoding: Bytes(rebasing: u[start ..< end]), as: UTF8.self)
    }
}
