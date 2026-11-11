/// A media type pattern a `blob:` permission accepts: `*/*`, `type/*` or
/// `type/subtype`.
///
/// The reference implementation's `isAccept` (`lib/mime.ts:23-28`) also
/// accepts a `*` inside the type when the subtype is `*`, as in `im*ge/*`. No
/// media type can match such a pattern (`lib/mime.ts:17-19` and `:39-40`), and
/// it is not a "MIME type or partial MIME type glob pattern" in the sense of
/// the permission specification, so it is rejected here.
public enum AcceptPattern: Sendable, Equatable, Hashable, Comparable {
    /// `*/*`: every media type.
    case any
    /// `type/*`: every subtype of one type. Holds the type, such as `image`.
    case type(String)
    /// `type/subtype`: one media type.
    case exact(String, String)

    /// The pattern as it is written in a scope.
    public var stringValue: String {
        switch self {
        case .any: "*/*"
        case let .type(t): "\(t)/*"
        case let .exact(t, s): "\(t)/\(s)"
        }
    }

    /// Parses a pattern (`lib/mime.ts:3-13`, `:23-28`): exactly one `/` with a
    /// non-empty part on each side, no SPACE, and `*` only as the whole of a
    /// part, where a `*` type requires a `*` subtype.
    ///
    /// The pattern is held with its ASCII letters in lower case. Media type
    /// names are case-insensitive (RFC 6838 §4.2) and the canonical scope
    /// string lower-cases them (`scopes/blob-permission.ts:46`), so
    /// `blob:IMAGE/PNG` and `blob:image/png` are the same permission: they
    /// canonicalise alike and they match alike. See
    /// ``BlobPermission/matches(_:)``.
    ///
    /// Only `A`–`Z` are folded. Unicode case mapping would turn U+212A KELVIN
    /// SIGN into `k` and so make a different byte sequence match.
    public init?(_ raw: String) {
        let bytes = Array(raw.asciiLowercased.utf8)
        guard !bytes.isEmpty, !bytes.contains(0x20) else { return nil }
        let parts = bytes.split(separator: 0x2F, omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        let type = String(decoding: parts[0], as: UTF8.self), subtype = String(decoding: parts[1], as: UTF8.self)
        let star: [UInt8] = [0x2A]
        if parts[0].elementsEqual(star) {
            guard parts[1].elementsEqual(star) else { return nil } // "*/subtype" is never valid
            self = .any
        } else if parts[1].elementsEqual(star) {
            guard !parts[0].contains(0x2A) else { return nil }
            self = .type(type)
        } else {
            guard !parts[0].contains(0x2A), !parts[1].contains(0x2A) else { return nil }
            self = .exact(type, subtype)
        }
    }

    /// Two patterns are equal when they are the same bytes; Unicode
    /// equivalence plays no part.
    public static func == (lhs: AcceptPattern, rhs: AcceptPattern) -> Bool {
        switch (lhs, rhs) {
        case (.any, .any): true
        case let (.type(a), .type(b)): a.isByteEqual(to: b)
        case let (.exact(a, c), .exact(b, d)): a.isByteEqual(to: b) && c.isByteEqual(to: d)
        default: false
        }
    }

    /// Hashes the bytes, consistently with `==`.
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .any: hasher.combine(0 as UInt8)
        case let .type(type): hasher.combine(1 as UInt8); hasher.combine(type.scopeBytes)
        case let .exact(type, subtype):
            hasher.combine(2 as UInt8); hasher.combine(type.scopeBytes); hasher.combine(subtype.scopeBytes)
        }
    }

    /// The pattern with the ASCII letters of its parts lower-cased; nothing
    /// else is changed.
    var asciiFolded: AcceptPattern {
        switch self {
        case .any: .any
        case let .type(t): .type(t.asciiLowercased)
        case let .exact(t, s): .exact(t.asciiLowercased, s.asciiLowercased)
        }
    }

    /// Orders patterns by ``stringValue``.
    public static func < (lhs: AcceptPattern, rhs: AcceptPattern) -> Bool {
        lhs.stringValue < rhs.stringValue
    }
}

/// A media type with no wildcard: `type/subtype` (`isMime`,
/// `lib/mime.ts:17-19`).
public struct ConcreteMime: Sendable, Hashable {
    /// The part before `/`.
    public let type: String
    /// The part after `/`.
    public let subtype: String

    /// Parses `raw`, or returns `nil` when it is not exactly one `/` between
    /// two non-empty parts, or contains SPACE or `*`.
    public init?(_ raw: String) {
        let bytes = Array(raw.utf8)
        guard !bytes.isEmpty, !bytes.contains(0x20), !bytes.contains(0x2A) else { return nil }
        let parts = bytes.split(separator: 0x2F, omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        self.type = String(decoding: parts[0], as: UTF8.self)
        self.subtype = String(decoding: parts[1], as: UTF8.self)
    }
}

/// A `blob:` permission: the ability to upload media files of the accepted
/// types, such as `blob:*/*` or `blob?accept=video/*&accept=text/html`.
///
/// Port of `BlobPermission`, `scopes/blob-permission.ts:21-73`, with the
/// matcher of `lib/mime.ts`.
public struct BlobPermission: ScopePermission {
    /// The accepted media type patterns. Positional, required, with no
    /// default: a bare `blob` is rejected
    /// (`scopes/blob-permission.test.ts:20-23`). Never empty when parsed.
    public let accept: [AcceptPattern]

    private let parameters: ScopeParameterValues

    /// Creates a permission accepting `accept`.
    ///
    /// The ASCII letters of each pattern are lower-cased, as
    /// ``AcceptPattern/init(_:)`` does for a parsed pattern, so a pattern
    /// built from the enum cases (`.exact("IMAGE", "PNG")`) is the same
    /// permission as its parsed spelling and matches the same uploads.
    public init(accept: [AcceptPattern]) {
        let accept = accept.map(\.asciiFolded)
        self.accept = accept
        var values = ScopeParameterValues()
        values.set("accept", accept.map(\.stringValue))
        self.parameters = values
    }

    /// Builds the permission from parameters ``schema`` has validated.
    public init(parameters: ScopeParameterValues) throws(ScopeParseError) {
        let raw = parameters.multiple("accept")
        let accept = raw.compactMap(AcceptPattern.init)
        guard accept.count == raw.count, !accept.isEmpty else {
            throw .invalidParameterValue(prefix: Self.schema.prefix, key: "accept", value: raw.joined(separator: ","))
        }
        self.accept = accept
        self.parameters = parameters
    }

    /// The parameter values this permission was built from.
    public var scopeParameters: ScopeParameterValues { parameters }

    /// The parameters of the `blob` resource
    /// (`scopes/blob-permission.ts:34-53`).
    public static let schema = ScopeParameterSchema(
        prefix: "blob",
        positionalKey: "accept",
        parameters: [
            .init(key: "accept", arity: .multiple, isRequired: true,
                  normalize: Self.normalizeAccept,
                  validate: { AcceptPattern($0) != nil }),
        ]
    )

    /// An attempt to upload a blob.
    public struct Target: Sendable, Hashable {
        /// The declared media type of the blob.
        public let mime: String
        /// Creates a target.
        public init(mime: String) { self.mime = mime }
    }

    /// Whether this permission covers an upload of `target.mime`
    /// (`matchesAnyAccept`, `lib/mime.ts:66-71`).
    ///
    /// The requested media type is checked first: unless it is itself a
    /// concrete `type/subtype`, nothing matches it, not even `*/*`
    /// (`lib/mime.test.ts:67-74`).
    ///
    /// The comparison ignores the case of ASCII letters, on both sides, and is
    /// otherwise byte-for-byte. The reference implementation compares the
    /// strings exactly as written, while its canonical form lower-cases the
    /// pattern, so there a permission can stop matching, or start matching,
    /// when it is canonicalised. Here a permission means the same before and
    /// after: see <doc:ReferenceParity>.
    public func matches(_ target: Target) -> Bool {
        guard let concrete = ConcreteMime(target.mime.asciiLowercased) else { return false }
        return accept.contains { Self.covers($0, concrete) }
    }

    /// `matchesAcceptUnsafe`, `lib/mime.ts:35-43`. The reference
    /// implementation's `type/*` arm tests the prefix `type/`; comparing the
    /// parsed type is equivalent because `ConcreteMime` has exactly one `/`.
    private static func covers(_ pattern: AcceptPattern, _ mime: ConcreteMime) -> Bool {
        switch pattern {
        case .any: true
        case let .type(t): mime.type.isByteEqual(to: t)
        case let .exact(t, s): mime.type.isByteEqual(to: t) && mime.subtype.isByteEqual(to: s)
        }
    }

    /// The canonical list of patterns (`scopes/blob-permission.ts:41-49`,
    /// `:75-105`):
    ///
    ///  1. a list containing `*/*` is just `*/*`;
    ///  2. otherwise every value is lowercased, each `type/subtype` already
    ///     covered by a `type/*` in the list is dropped, and the rest is
    ///     sorted.
    ///
    /// Duplicates are removed afterwards, by
    /// ``ScopeParameterSchema/format(_:)``.
    static let normalizeAccept: @Sendable ([String]) -> [String] = { given in
        let lowered = given.map { $0.lowercased() }
        if lowered.contains("*/*") { return ["*/*"] }
        let parsed = lowered.map { (raw: $0, pattern: AcceptPattern($0)) }
        let typeWildcards = Set(parsed.compactMap { entry -> String? in
            if case let .type(t)? = entry.pattern { return t }
            return nil
        })
        return parsed
            .filter { entry in
                if case let .exact(t, _)? = entry.pattern, typeWildcards.contains(t) { return false }
                return true
            }
            .map(\.raw)
            .sorted()
    }

    /// The narrowest `blob:` scope that covers `target`
    /// (`scopes/blob-permission.ts:68-72`). The media type is not validated:
    /// a malformed one still yields a scope string, which then matches
    /// nothing.
    public static func scopeNeeded(for target: Target) throws(ScopeParseError) -> String {
        var values = ScopeParameterValues()
        values.set("accept", [target.mime])
        return try schema.format(values)
    }
}
