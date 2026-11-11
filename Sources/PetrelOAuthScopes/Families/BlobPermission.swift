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
    public init?(_ raw: String) {
        guard !raw.isEmpty, !raw.contains(" ") else { return nil }
        let parts = raw.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let type = String(parts[0]), subtype = String(parts[1])
        guard !type.isEmpty, !subtype.isEmpty else { return nil }
        if type == "*" {
            guard subtype == "*" else { return nil } // "*/subtype" is never valid
            self = .any
        } else if subtype == "*" {
            guard !type.contains("*") else { return nil }
            self = .type(type)
        } else {
            guard !type.contains("*"), !subtype.contains("*") else { return nil }
            self = .exact(type, subtype)
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
        guard !raw.isEmpty, !raw.contains(" "), !raw.contains("*") else { return nil }
        let parts = raw.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let type = String(parts[0]), subtype = String(parts[1])
        guard !type.isEmpty, !subtype.isEmpty else { return nil }
        self.type = type
        self.subtype = subtype
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
    public init(accept: [AcceptPattern]) {
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
    public func matches(_ target: Target) -> Bool {
        guard let concrete = ConcreteMime(target.mime) else { return false }
        return accept.contains { Self.covers($0, concrete) }
    }

    /// `matchesAcceptUnsafe`, `lib/mime.ts:35-43`. The reference
    /// implementation's `type/*` arm tests the prefix `type/`; comparing the
    /// parsed type is equivalent because `ConcreteMime` has exactly one `/`.
    private static func covers(_ pattern: AcceptPattern, _ mime: ConcreteMime) -> Bool {
        switch pattern {
        case .any: true
        case let .type(t): mime.type == t
        case let .exact(t, s): mime.type == t && mime.subtype == s
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
