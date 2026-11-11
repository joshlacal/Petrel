import Foundation

// The JSON representation of permissions: the types a `permission-set`
// definition in a Lexicon schema decodes into (`lib/lexicon.ts:6-21`).

// MARK: - LexiconValue

/// The value of one field of a permission in JSON: a string, number or boolean
/// (`ParamValue`, `lib/syntax.ts:1`), or an array of those (`lib/lexicon.ts:9`).
///
/// Whether a value is a scalar or an array is part of the value. A scalar and
/// a one-element array are not interchangeable: a scalar where an array is
/// required makes the whole entry invalid (`lib/syntax-lexicon.ts:45-50`,
/// `lib/parser.ts:121-122`). Treating the scalar `"collection": "a.b.c"` as
/// `["a.b.c"]` would turn an entry the reference implementation ignores
/// (`scopes/include-scope.test.ts:493-507`) into a `repo:` grant.
public enum LexiconValue: Sendable, Equatable {
    /// A JSON string.
    case string(String)
    /// A JSON number.
    case number(Double)
    /// A JSON boolean.
    case bool(Bool)
    /// A JSON array.
    case list([LexiconValue])

    /// The text a parameter validator sees for a scalar. `nil` for an array,
    /// which every caller treats as "invalid", never as "absent".
    ///
    /// A number is rendered without converting it to `Int` unless it is an
    /// integer `Double` can represent exactly: the value comes from an
    /// untrusted document, and `Int(1e300)` would trap. No parameter defined
    /// today accepts numeric text, so a numeric field is rejected either way.
    var scalarText: String? {
        switch self {
        case let .string(value):
            return value
        case let .number(value):
            guard value.isFinite else { return nil }
            // 2^53: above it `Double` cannot represent consecutive integers.
            if value == value.rounded(), value.magnitude < 9_007_199_254_740_992 {
                return String(Int(value))
            }
            return String(value)
        case let .bool(value):
            return value ? "true" : "false"
        case .list:
            return nil
        }
    }
}

extension LexiconValue: Decodable {
    /// Decodes a string, number, boolean or array of those. JSON `null` is
    /// none of them and fails the decode; see ``LexiconPermission``.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard !container.decodeNil() else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "null is not a lexicon permission parameter value"
            )
        }
        // Bool before Double: `inheritAud: true` is a boolean and must not
        // decode as the number 1 (`scopes/include-scope.ts:90` compares with
        // `=== true`).
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([LexiconValue].self) {
            self = .list(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "not a string, number, boolean, or array of those"
            )
        }
    }
}

// MARK: - LexiconPermission

/// One permission as it is written in a permission set
/// (`lib/lexicon.ts:6-10`), for example
/// `{"type": "permission", "resource": "repo", "collection": ["com.example.post"]}`.
///
/// `type` and `resource` are the two reserved keys. ``fields`` holds every
/// other key, and so never contains either of them.
///
/// Decoding is stricter than the reference implementation in one respect. A
/// field that is `null`, an object, or otherwise not a ``LexiconValue`` makes
/// the reference implementation ignore that entry; here it fails the decode of
/// the whole document. The result grants strictly less, never more.
public struct LexiconPermission: Sendable, Equatable {
    /// `"permission"` in a well-formed document (`lib/lexicon.ts:7`). Kept as
    /// decoded and not enforced: expansion dispatches on ``resource`` alone
    /// (`scopes/include-scope.ts:68-102`), as the reference implementation
    /// does.
    public let type: String
    /// The resource name, such as `repo` or `rpc`.
    public let resource: String
    /// Every field other than `type` and `resource`.
    public let fields: [String: LexiconValue]

    /// Creates a permission entry.
    public init(type: String = "permission", resource: String, fields: [String: LexiconValue]) {
        self.type = type
        self.resource = resource
        self.fields = fields
    }
}

extension LexiconPermission: Decodable {
    private struct DynamicKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue _: Int) { nil }
    }

    /// Decodes a JSON object with string `type` and `resource` keys.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        self.type = try container.decode(String.self, forKey: DynamicKey(stringValue: "type"))
        self.resource = try container.decode(String.self, forKey: DynamicKey(stringValue: "resource"))
        var fields: [String: LexiconValue] = [:]
        for key in container.allKeys where key.stringValue != "type" && key.stringValue != "resource" {
            fields[key.stringValue] = try container.decode(LexiconValue.self, forKey: key)
        }
        self.fields = fields
    }
}

// MARK: - LexiconPermissionSet

/// A permission set: the `main` definition of a Lexicon schema whose type is
/// `permission-set` (`lib/lexicon.ts:14-21`).
///
/// The localised `title:lang` and `detail:lang` maps (`lib/lexicon.ts:18`,
/// `:20`) are display text for the consent screen and grant nothing.
public struct LexiconPermissionSet: Sendable, Equatable, Decodable {
    /// `"permission-set"` in a well-formed document (`lib/lexicon.ts:15`).
    /// Kept as decoded so that a resolver can tell a permission set from
    /// another kind of definition; expansion does not check it.
    public let type: String
    /// The permissions in the set, in document order.
    public let permissions: [LexiconPermission]
    /// A short human-readable name for the set.
    public let title: String?
    /// A human-readable description of what the set allows.
    public let detail: String?
    /// Localised titles keyed by BCP 47 language tag (`title:lang`).
    public let titleLang: [String: String]
    /// Localised descriptions keyed by BCP 47 language tag (`detail:lang`).
    public let detailLang: [String: String]

    /// Creates a permission set.
    public init(
        type: String = "permission-set",
        permissions: [LexiconPermission],
        title: String? = nil,
        detail: String? = nil,
        titleLang: [String: String] = [:],
        detailLang: [String: String] = [:]
    ) {
        self.type = type
        self.permissions = permissions
        self.title = title
        self.detail = detail
        self.titleLang = titleLang
        self.detailLang = detailLang
    }

    private enum CodingKeys: String, CodingKey {
        case type, permissions, title, detail
        case titleLang = "title:lang"
        case detailLang = "detail:lang"
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = try values.decode(String.self, forKey: .type)
        permissions = try values.decode([LexiconPermission].self, forKey: .permissions)
        title = try values.decodeIfPresent(String.self, forKey: .title)
        detail = try values.decodeIfPresent(String.self, forKey: .detail)
        // Display text only: a malformed localisation map is ignored rather
        // than failing a document whose permissions are well formed.
        titleLang = (try? values.decodeIfPresent([String: String].self, forKey: .titleLang)) ?? [:]
        detailLang = (try? values.decodeIfPresent([String: String].self, forKey: .detailLang)) ?? [:]
    }

    /// The title in the first of `languages` the set is localised for, falling
    /// back to the unlocalised title. Tags match exactly or by primary subtag
    /// (`pt-BR` falls back to `pt`).
    public func localizedTitle(for languages: [String]) -> String? {
        Self.localized(titleLang, languages) ?? title
    }

    /// The description in the first of `languages` the set is localised for,
    /// falling back to the unlocalised description.
    public func localizedDetail(for languages: [String]) -> String? {
        Self.localized(detailLang, languages) ?? detail
    }

    private static func localized(_ values: [String: String], _ languages: [String]) -> String? {
        guard !values.isEmpty else { return nil }
        let lowered = Dictionary(values.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { first, _ in first })
        for language in languages {
            let tag = language.lowercased()
            if let exact = lowered[tag] { return exact }
            if let primary = tag.split(separator: "-").first, let match = lowered[String(primary)] { return match }
        }
        return nil
    }
}
