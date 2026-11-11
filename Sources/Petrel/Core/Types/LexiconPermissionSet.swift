import Foundation

/// One permission inside a `permission-set` Lexicon.
///
/// A permission names a resource (`repo`, `rpc`, …) and the parameters that narrow it.
/// Parameters are kept as written in the Lexicon, keyed by name, with scalar values
/// stored as one-element arrays. Resources this version of Petrel does not know are
/// preserved too; the permission specification asks consumers to ignore, not reject,
/// what they do not recognise.
public struct LexiconPermission: Sendable, Equatable, Hashable {
    /// The resource type: `repo`, `rpc`, or a later addition.
    public let resource: String
    /// The parameters of the permission (`collection`, `action`, `lxm`, `aud`, …).
    public let parameters: [String: [String]]
    /// `rpc` only: the audience comes from the `include:` scope that requests the set.
    public let inheritAud: Bool

    /// Creates a permission.
    public init(resource: String, parameters: [String: [String]] = [:], inheritAud: Bool = false) {
        self.resource = resource
        self.parameters = parameters
        self.inheritAud = inheritAud
    }

    /// `repo`: the record collections (NSIDs) the permission covers.
    public var collections: [String] { parameters["collection"] ?? [] }

    /// `repo`: the allowed record operations. Empty means all of create, update, delete.
    public var actions: [String] { parameters["action"] ?? [] }

    /// `rpc`: the endpoints (NSIDs) the permission covers.
    public var methods: [String] { parameters["lxm"] ?? [] }

    /// `rpc`: the fixed audience, when the permission does not inherit one.
    public var audience: String? { parameters["aud"]?.first }
}

/// A `permission-set` Lexicon: a named bundle of permissions with user-facing text.
///
/// Generated permission-set lexicons expose one as `permissionSet`. Request it during OAuth
/// with ``includeScope(audience:)``:
///
/// ```swift
/// let scope = "atproto " + AppBskyAuthCreatePosts.permissionSet.includeScope()
/// ```
public struct LexiconPermissionSet: Sendable, Equatable, Hashable {
    /// The NSID of the permission set.
    public let nsid: String
    /// Short title shown to the user, in the Lexicon's default language.
    public let title: String?
    /// Translations of ``title`` keyed by BCP-47 language tag (`title:<lang>` in the Lexicon).
    public let titleLang: [String: String]
    /// Longer description shown to the user.
    public let detail: String?
    /// Translations of ``detail`` keyed by BCP-47 language tag (`detail:<lang>` in the Lexicon).
    public let detailLang: [String: String]
    /// The permissions the set grants.
    public let permissions: [LexiconPermission]

    /// Creates a permission set.
    public init(
        nsid: String,
        title: String? = nil,
        titleLang: [String: String] = [:],
        detail: String? = nil,
        detailLang: [String: String] = [:],
        permissions: [LexiconPermission]
    ) {
        self.nsid = nsid
        self.title = title
        self.titleLang = titleLang
        self.detail = detail
        self.detailLang = detailLang
        self.permissions = permissions
    }

    /// The OAuth scope string that requests this permission set: `include:<nsid>`, with
    /// `?aud=<audience>` when an audience is given.
    ///
    /// - Parameter audience: The service the set's `rpc` permissions with `inheritAud`
    ///   apply to, as a DID service reference such as `did:web:api.example.com#svc_appview`.
    ///   Required when ``requiresAudience`` is true; without it those permissions are ignored.
    public func includeScope(audience: String? = nil) -> String {
        guard let audience else { return "include:\(nsid)" }
        // Scope strings are printable non-whitespace ASCII; `#`, `&`, `=`, `?`, `%` and `+`
        // would be read as syntax inside a parameter value.
        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!$'()*,-./:;@_~"
        )
        let encoded = audience.addingPercentEncoding(withAllowedCharacters: allowed) ?? audience
        return "include:\(nsid)?aud=\(encoded)"
    }

    /// Whether any `rpc` permission takes its audience from the `include:` scope.
    public var requiresAudience: Bool {
        permissions.contains { $0.resource == "rpc" && $0.inheritAud }
    }

    /// The title in `language`, falling back to the primary subtag and then the default title.
    public func title(for language: String) -> String? {
        Self.localized(titleLang, language: language) ?? title
    }

    /// The detail text in `language`, falling back to the primary subtag and then the default.
    public func detail(for language: String) -> String? {
        Self.localized(detailLang, language: language) ?? detail
    }

    private static func localized(_ table: [String: String], language: String) -> String? {
        if let exact = table[language] { return exact }
        let primary = language.split(separator: "-").first.map(String.init) ?? language
        return table[primary]
    }
}
