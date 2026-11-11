import Foundation

/// The lexical decomposition of a scope string:
///
///     scope = prefix [ ":" positional ] [ "?" query ]
///
/// The positional runs to the first `?`, and everything after that first `?`
/// is one query string, so a later `?` belongs to the value it appears in
/// (`lib/syntax-string.test.ts:34-41`). A `#` is likewise a literal: this is a
/// query string, not a URL, and has no fragment
/// (`scopes/include-scope.test.ts:31-40`).
///
/// Port of `ScopeStringSyntax`, `lib/syntax-string.ts:7-76`, in the reference
/// implementation's `@atproto/oauth-scopes`.
public struct ScopeStringSyntax: Sendable, Hashable {
    /// The resource name: everything before the first `:` or `?`.
    public let prefix: String
    /// The positional segment, percent-decoded. `nil` means there is no `:`
    /// segment; `""` is legal and distinct, so `"my-res:"` has an empty
    /// positional (`lib/syntax-string.test.ts:14-17`). That distinction is why
    /// `"rpc:?aud=…"` is rejected for an invalid (empty) `lxm` rather than for
    /// a missing one (`scopes/rpc-permission.test.ts:49-56`).
    public let positional: String?
    /// The named parameters, decoded, in the order written.
    public let parameters: ScopeParameterBag

    /// Assembles a syntax value from already-decoded parts.
    public init(prefix: String, positional: String? = nil, parameters: ScopeParameterBag = .init()) {
        self.prefix = prefix
        self.positional = positional
        self.parameters = parameters
    }

    // MARK: parse

    /// Splits `scope` into prefix, positional and parameters
    /// (`lib/syntax-string.ts:44-75`).
    ///
    /// This is deliberately permissive: it knows nothing about any resource,
    /// and accepts, for instance, a positional together with a named parameter
    /// of the same meaning. ``ScopeParameterSchema/parse(_:)`` applies the
    /// rules.
    ///
    /// - Throws: ``ScopeParseError/notAScopeToken(_:)`` when `scope` is not an
    ///   RFC 6749 `scope-token`, and
    ///   ``ScopeParseError/malformedPercentEncoding(_:)`` when the positional
    ///   segment cannot be percent-decoded.
    public static func parse(_ scope: String) throws(ScopeParseError) -> ScopeStringSyntax {
        guard ScopeToken.isScopeToken(scope) else { throw .notAScopeToken(scope) }

        let bytes = Array(scope.utf8)
        let questionIdx = bytes.firstIndex(of: 0x3f) // "?"
        let colonIdx = bytes.firstIndex(of: 0x3a) // ":"

        // `minIdx`, lib/util.ts:5-9 — the smaller of the two, ignoring "absent".
        let prefixEnd: Int? = switch (colonIdx, questionIdx) {
        case (nil, nil): nil
        case let (value?, nil): value
        case let (nil, value?): value
        case let (a?, b?): Swift.min(a, b)
        }

        guard let prefixEnd else {
            return ScopeStringSyntax(prefix: scope)
        }

        let prefix = String(decoding: bytes[..<prefixEnd], as: UTF8.self)

        // lib/syntax-string.ts:58-66: a positional exists only when `:` precedes `?`.
        var positional: String?
        if let colonIdx {
            if let questionIdx {
                if colonIdx < questionIdx {
                    positional = try decodeURIComponent(bytes[(colonIdx + 1)..<questionIdx], in: scope)
                }
            } else {
                positional = try decodeURIComponent(bytes[(colonIdx + 1)...], in: scope)
            }
        }

        // lib/syntax-string.ts:68-72: an empty query (`"x?"`) yields no parameters.
        var parameters = ScopeParameterBag()
        if let questionIdx, questionIdx < bytes.count - 1 {
            parameters = parseQueryString(bytes[(questionIdx + 1)...])
        }

        return ScopeStringSyntax(prefix: prefix, positional: positional, parameters: parameters)
    }

    /// `application/x-www-form-urlencoded` parsing with `URLSearchParams`
    /// semantics: split on `&`, split each pair on the first `=`, decode `+`
    /// as SPACE and `%XX` bytewise. A pair with no `=` has an empty value, and
    /// an empty pair (as in `a=1&&b=2`) is skipped. Never throws.
    private static func parseQueryString(_ bytes: ArraySlice<UInt8>) -> ScopeParameterBag {
        var bag = ScopeParameterBag()
        for pair in bytes.split(separator: 0x26, omittingEmptySubsequences: true) { // "&"
            let split = pair.split(separator: 0x3d, maxSplits: 1, omittingEmptySubsequences: false) // "="
            let key = decodeFormComponent(split[0])
            let value = split.count > 1 ? decodeFormComponent(split[1]) : ""
            bag.append(key: key, value: value)
        }
        return bag
    }

    /// Decodes one query-string component the way `URLSearchParams` does
    /// (`lib/syntax-string.ts:71`): lossily. A malformed `%` sequence survives
    /// as literal bytes and invalid UTF-8 becomes U+FFFD.
    ///
    /// The two decoders are intentionally not symmetric, because the
    /// reference implementation's are not:
    ///
    ///     positional -> decodeURIComponent(...)   throws on a malformed `%`
    ///     query      -> new URLSearchParams(...)  never throws
    ///
    /// A malformed escape in a query value is left for the parameter's own
    /// validator to reject.
    private static func decodeFormComponent(_ bytes: ArraySlice<UInt8>) -> String {
        let folded = bytes.map { $0 == 0x2b ? 0x20 : $0 }[...] // "+" -> SP
        return lossyPercentDecode(folded)
    }

    /// Decodes the positional segment the way `decodeURIComponent` does
    /// (`lib/syntax-string.ts:62-64`): strictly. There is no `+` folding
    /// outside a query string.
    private static func decodeURIComponent(
        _ bytes: ArraySlice<UInt8>, in scope: String
    ) throws(ScopeParseError) -> String {
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        var index = bytes.startIndex
        while index < bytes.endIndex {
            let byte = bytes[index]
            if byte == 0x25 { // "%"
                let high = bytes.index(index, offsetBy: 1, limitedBy: bytes.endIndex - 1)
                let low = bytes.index(index, offsetBy: 2, limitedBy: bytes.endIndex - 1)
                guard let high, let low,
                      let hi = hexValue(bytes[high]), let lo = hexValue(bytes[low])
                else { throw .malformedPercentEncoding(scope) }
                out.append(hi << 4 | lo)
                index = bytes.index(index, offsetBy: 3)
            } else {
                out.append(byte)
                index = bytes.index(after: index)
            }
        }
        guard let decoded = String(bytes: out, encoding: .utf8) else {
            throw .malformedPercentEncoding(scope)
        }
        return decoded
    }

    private static func lossyPercentDecode(_ bytes: ArraySlice<UInt8>) -> String {
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        var index = bytes.startIndex
        while index < bytes.endIndex {
            let byte = bytes[index]
            if byte == 0x25,
               let high = bytes.index(index, offsetBy: 1, limitedBy: bytes.endIndex - 1),
               let low = bytes.index(index, offsetBy: 2, limitedBy: bytes.endIndex - 1),
               let hi = hexValue(bytes[high]), let lo = hexValue(bytes[low]) {
                out.append(hi << 4 | lo)
                index = bytes.index(index, offsetBy: 3)
            } else {
                // A literal `%`, or a truncated or non-hexadecimal escape,
                // passes through verbatim, as in `URLSearchParams`.
                out.append(byte)
                index = bytes.index(after: index)
            }
        }
        // `String(decoding:as:)` substitutes U+FFFD, matching the URL
        // Standard's "UTF-8 decode without BOM". Never nil.
        return String(decoding: out, as: UTF8.self)
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 0x30...0x39: byte - 0x30
        case 0x41...0x46: byte - 0x41 + 10
        case 0x61...0x66: byte - 0x61 + 10
        default: nil
        }
    }

    // MARK: prefix matching

    /// Whether `value` is a scope string for the resource `prefix`: equal to
    /// it, or the prefix followed by `:` or `?`. A longer resource name that
    /// merely starts with `prefix` does not qualify, so `"identityfoo:x"` is
    /// not an `identity` scope. Port of `isScopeStringFor`,
    /// `lib/syntax.ts:18-35`.
    public static func isScopeString(_ value: String, for prefix: String) -> Bool {
        let value = Array(value.utf8), prefix = Array(prefix.utf8)
        guard value.count > prefix.count else { return value == prefix }
        let next = value[prefix.count]
        guard next == 0x3a || next == 0x3f else { return false }
        return value.starts(with: prefix)
    }
}

// MARK: - Canonical serialiser

extension ScopeStringSyntax {
    /// The canonical scope string for these parts
    /// (`toString`, `lib/syntax-string.ts:30-42`).
    ///
    /// The positional is encoded with `encodeURIComponent` and the query with
    /// the `application/x-www-form-urlencoded` serialiser. They are different
    /// encoders and stay different: SPACE is `%20` in a positional and `+` in a
    /// query, and `~` is literal in a positional and `%7E` in a query.
    ///
    /// - Throws: ``ScopeParseError/notAScopeToken(_:)`` when the result is not
    ///   an RFC 6749 `scope-token`.
    public func canonicalString() throws(ScopeParseError) -> String {
        var scope = prefix
        if let positional {
            scope += ":" + Self.normalizeAllowedChars(Self.encodeURIComponent(positional))
        }
        if !parameters.isEmpty {
            let query = parameters.entries
                .map { Self.encodeFormComponent($0.key) + "=" + Self.encodeFormComponent($0.value) }
                .joined(separator: "&")
            scope += "?" + Self.normalizeAllowedChars(query)
        }
        guard ScopeToken.isScopeToken(scope) else { throw .notAScopeToken(scope) }
        return scope
    }

    /// A scope string for these parts that is guaranteed to parse back to
    /// them.
    ///
    /// It is ``canonicalString()`` except that the two un-escapings the
    /// canonical form inherits from the reference implementation and that do
    /// not survive a re-parse are left out: a `%` stays `%25` everywhere, and
    /// a `+` stays `%2B` in the query (in the positional segment a raw `+` is
    /// literal, so it is kept). For parts containing neither character the two
    /// strings are byte-identical.
    ///
    /// - Throws: ``ScopeParseError/notAScopeToken(_:)`` when the result is not
    ///   an RFC 6749 `scope-token`.
    func parseableString() throws(ScopeParseError) -> String {
        var scope = prefix
        if let positional {
            scope += ":" + Self.unescape(Self.encodeURIComponent(positional), ["%3A", "%2F", "%2B", "%2C", "%40"])
        }
        if !parameters.isEmpty {
            let query = parameters.entries
                .map { Self.encodeFormComponent($0.key) + "=" + Self.encodeFormComponent($0.value) }
                .joined(separator: "&")
            scope += "?" + Self.unescape(query, ["%3A", "%2F", "%2C", "%40"])
        }
        guard ScopeToken.isScopeToken(scope) else { throw .notAScopeToken(scope) }
        return scope
    }

    /// Replaces each of `escapes` (upper-case `%XX`) with the character it
    /// encodes. `%25` is never among them, so an un-escaped character can
    /// never combine with a following pair into a new escape.
    private static func unescape(_ value: String, _ escapes: [String]) -> String {
        var out = ""
        var index = value.startIndex
        while index < value.endIndex {
            if value[index] == "%", let end = value.index(index, offsetBy: 3, limitedBy: value.endIndex) {
                let triplet = String(value[index ..< end])
                if escapes.contains(triplet), let byte = UInt8(triplet.dropFirst(), radix: 16) {
                    out.unicodeScalars.append(Unicode.Scalar(byte))
                } else {
                    out += triplet
                }
                index = end
            } else {
                out.append(value[index])
                index = value.index(after: index)
            }
        }
        return out
    }

    /// JavaScript `encodeURIComponent`: leaves A-Z a-z 0-9 and `-_.!~*'()`
    /// unencoded.
    static func encodeURIComponent(_ value: String) -> String {
        percentEncode(
            value,
            unreserved: Set(
                "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()".utf8
            )
        )
    }

    /// The `application/x-www-form-urlencoded` serialiser as
    /// `URLSearchParams` implements it: A-Z a-z 0-9 and `*-._` are left
    /// unencoded and SPACE becomes `+`. Foundation's `addingPercentEncoding`
    /// would emit `%20`, which is not byte-identical to the reference
    /// implementation's canonical form.
    static func encodeFormComponent(_ value: String) -> String {
        var out = ""
        for byte in value.utf8 {
            if byte == 0x20 { out += "+" } else if Self.formUnreserved.contains(byte) {
                out.unicodeScalars.append(Unicode.Scalar(byte))
            } else {
                out += String(format: "%%%02X", byte)
            }
        }
        return out
    }

    private static let formUnreserved: Set<UInt8> = Set(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789*-._".utf8
    )

    private static func percentEncode(_ value: String, unreserved: Set<UInt8>) -> String {
        var out = ""
        for byte in value.utf8 {
            if unreserved.contains(byte) {
                out.unicodeScalars.append(Unicode.Scalar(byte))
            } else {
                out += String(format: "%%%02X", byte)
            }
        }
        return out
    }

    /// `normalizeURIComponent`, `lib/syntax-string.ts:104-132`: un-escapes
    /// exactly `: / + , @ %` and nothing else. `?` and `&` are never
    /// un-escaped, since that would change how the query parses
    /// (`lib/syntax-string.ts:83-84`).
    ///
    /// Two consequences are inherited from the reference implementation, and
    /// reproduced so that canonical forms stay byte-identical with it. Both
    /// concern a query value, and with the parameters defined today are
    /// reachable only through an `aud` or a multi-valued `blob` `accept`:
    ///
    ///  - a literal `+` is serialised as `%2B` and then un-escaped to a raw
    ///    `+`, which parses back as SPACE;
    ///  - a literal `%` is serialised as `%25` and then un-escaped to a raw
    ///    `%`, which parses back as the start of an escape.
    ///
    /// For such a value the canonical form does not parse back to the same
    /// scope.
    static func normalizeAllowedChars(_ value: String) -> String {
        var out = value
        for (encoded, raw) in [("%3A", ":"), ("%2F", "/"), ("%2B", "+"), ("%2C", ","), ("%40", "@"), ("%25", "%")] {
            out = out.replacingOccurrences(of: encoded, with: raw)
        }
        return out
    }
}
