/// A kind of scope with a resource name, a parameter schema, a parser and a
/// canonical form.
///
/// ``ScopePermission`` refines this with matching. The split exists because
/// ``IncludeScope`` stops here: it names a permission set and matches nothing
/// itself, exactly as the reference implementation's `IncludeScope` implements
/// neither `ResourcePermission` (`lib/resource-permission.ts:8`) nor
/// `Matchable`.
public protocol ScopeFamily: Sendable, Hashable {
    /// The resource name and the parameters it accepts.
    static var schema: ScopeParameterSchema { get }

    /// Builds the typed value from parameters ``schema`` has validated.
    init(parameters: ScopeParameterValues) throws(ScopeParseError)
    /// The parameter values this scope was built from.
    var scopeParameters: ScopeParameterValues { get }
}

extension ScopeFamily {
    /// The resource name, such as `repo`.
    public static var prefix: String { schema.prefix }

    /// Parses a scope string of this resource.
    ///
    /// - Throws: ``ScopeParseError`` naming the first rule the string breaks.
    public static func parse(_ scope: String) throws(ScopeParseError) -> Self {
        guard ScopeStringSyntax.isScopeString(scope, for: schema.prefix) else {
            throw .prefixMismatch(expected: schema.prefix, actual: scope)
        }
        return try Self(parameters: schema.parse(ScopeStringSyntax.parse(scope)))
    }

    /// The canonical scope string: positional form where possible, defaults
    /// omitted, lists normalised, parameters in schema order.
    public func canonicalScopeString() throws(ScopeParseError) -> String {
        try Self.schema.format(scopeParameters)
    }

    /// The canonical scope string with `+` and `%` left percent-encoded where
    /// un-escaping them would change how the string parses.
    func parseableScopeString() throws(ScopeParseError) -> String {
        try Self.schema.formatParseable(scopeParameters)
    }
}

/// What a scope grants, as the matchers see it, independent of how it was
/// written. Equal for two scopes exactly when every request one allows the
/// other allows too.
///
/// It is built from the same typed values the matchers read, never from a
/// scope string: a canonical string is not a faithful key. It is not a fixed
/// point (`blob?accept=a/b&accept=a/b` canonicalises to `blob?accept=a/b`,
/// which canonicalises to `blob:a/b`), and it can coincide for different
/// grants — an `rpc` audience ending `#svc&admin` and one ending
/// `#svc%26admin` both canonicalise to `…%23svc%26admin`. Redundant spellings
/// are folded the way the matchers fold them: a wildcard absorbs the specific
/// values beside it, `type/*` absorbs `type/subtype`, and `manage` absorbs
/// `read`.
struct ScopeMeaning: Hashable {
    private let resource: ScopeBytes
    /// Parameter name → the set of values it stands for, each tagged so that a
    /// wildcard can never equal a literal value spelled `*`.
    private let parameters: [String: Set<ScopeBytes>]

    private static let wildcard: ScopeBytes = [0]
    private static func value(_ string: String) -> ScopeBytes { [1] + string.utf8 }

    init(resource: String, parameters: [String: Set<ScopeBytes>] = [:]) {
        self.resource = resource.scopeBytes
        self.parameters = parameters
    }

    init(_ permission: RepoPermission) {
        let collections: Set<ScopeBytes> = permission.collection.contains(.any)
            ? [Self.wildcard]
            : Set(permission.collection.map { Self.value($0.stringValue) })
        self.init(resource: RepoPermission.prefix, parameters: [
            "collection": collections,
            "action": Set(permission.action.map { Self.value($0.rawValue) }),
        ])
    }

    init(_ permission: RpcPermission) {
        let methods: Set<ScopeBytes> = permission.lxm.contains(.any)
            ? [Self.wildcard]
            : Set(permission.lxm.map { Self.value($0.stringValue) })
        self.init(resource: RpcPermission.prefix, parameters: [
            "lxm": methods,
            "aud": [Self.audience(permission.aud)],
        ])
    }

    init(_ permission: BlobPermission) {
        let accept: Set<ScopeBytes>
        if permission.accept.contains(.any) {
            accept = [Self.wildcard]
        } else {
            let types = Set(permission.accept.compactMap { pattern -> ScopeBytes? in
                if case let .type(type) = pattern { return type.scopeBytes }
                return nil
            })
            accept = Set(permission.accept.compactMap { pattern -> ScopeBytes? in
                switch pattern {
                case .any: nil
                case let .type(type): [2] + type.utf8
                case let .exact(type, subtype):
                    // Already granted by `type/*` beside it.
                    types.contains(type.scopeBytes) ? nil : Self.value("\(type)/\(subtype)")
                }
            })
        }
        self.init(resource: BlobPermission.prefix, parameters: ["accept": accept])
    }

    init(_ permission: AccountPermission) {
        // `manage` includes `read`.
        let actions: Set<ScopeBytes> = permission.action.contains(.manage)
            ? [Self.value(AccountAction.manage.rawValue)]
            : Set(permission.action.map { Self.value($0.rawValue) })
        self.init(resource: AccountPermission.prefix, parameters: [
            "attr": [Self.value(permission.attr.rawValue)],
            "action": actions,
        ])
    }

    init(_ permission: IdentityPermission) {
        self.init(resource: IdentityPermission.prefix, parameters: [
            "attr": [permission.attr == .any ? Self.wildcard : Self.value(permission.attr.rawValue)],
        ])
    }

    init(_ include: IncludeScope) {
        var parameters: [String: Set<ScopeBytes>] = ["nsid": [Self.value(include.nsid)]]
        if let aud = include.aud {
            parameters["aud"] = [Self.audience(aud)]
        }
        self.init(resource: IncludeScope.prefix, parameters: parameters)
    }

    private static func audience(_ aud: AudParam) -> ScopeBytes {
        switch aud {
        case .any: wildcard
        case let .service(service): value(service)
        }
    }
}

/// A scope that grants access to a resource (`repo:`, `rpc:`, `blob:`,
/// `account:`, `identity:`) and can therefore answer whether it covers a
/// request.
public protocol ScopePermission: ScopeFamily {
    /// What a request asks for.
    associatedtype Target: Sendable

    /// Whether this permission covers `target`.
    func matches(_ target: Target) -> Bool
    /// The narrowest scope string that would cover `target`, for the message
    /// of a denial (`scopes-set.ts:49-57`). Total over `Target`: like the
    /// reference, it formats a target no scope can grant (a collection that
    /// is not an NSID, a service without a fragment), and the result then
    /// does not parse. Use ``grantingScope(for:)`` where the string will be
    /// requested or acted on.
    static func scopeNeeded(for target: Target) throws(ScopeParseError) -> String
}

public extension ScopePermission {
    /// The narrowest scope string that grants `target`: ``scopeNeeded(for:)``,
    /// checked to parse back as a permission of this family that covers
    /// `target`.
    ///
    /// Use this where the string will be requested or stored — an
    /// authorization server naming the scope a client should ask for, say,
    /// when `target` comes from a request it does not control.
    ///
    /// - Throws: the parse error when the string does not parse (no scope can
    ///   name `target`, such as a service ending in a bare `%`), or
    ///   ``ScopeParseError/forbiddenParameterCombination(prefix:detail:)``
    ///   when it parses but does not cover `target` (a media type that is not
    ///   a concrete `type/subtype`).
    static func grantingScope(for target: Target) throws(ScopeParseError) -> String {
        let string = try scopeNeeded(for: target)
        let permission = try parse(string)
        guard permission.matches(target) else {
            throw .forbiddenParameterCombination(
                prefix: schema.prefix, detail: "no scope grants this request; \(string) would not cover it"
            )
        }
        return string
    }
}

/// Any scope value an AT Protocol authorization server understands.
///
/// ``parse(_:)`` dispatches on the resource name. The reference implementation
/// tries each resource's parser in turn (`atproto-oauth-scope.ts:61-79`); the
/// result is the same because ``ScopeStringSyntax/isScopeString(_:for:)``
/// makes the resource names disjoint, and a failure here says which rule was
/// broken rather than being `null`.
public enum ATProtoScope: Sendable, Hashable {
    /// `atproto`, the scope every AT Protocol session requires.
    case atproto
    /// `transition:email`.
    case transitionEmail
    /// `transition:generic`.
    case transitionGeneric
    /// `transition:chat.bsky`.
    case transitionChatBsky
    /// An `account:` permission.
    case account(AccountPermission)
    /// A `blob:` permission.
    case blob(BlobPermission)
    /// An `identity:` permission.
    case identity(IdentityPermission)
    /// An `include:` reference to a permission set.
    case include(IncludeScope)
    /// A `repo:` permission.
    case repo(RepoPermission)
    /// An `rpc:` permission.
    case rpc(RpcPermission)

    /// Parses one scope value.
    ///
    /// - Throws: ``ScopeParseError/unknownPrefix(_:)`` when the value names no
    ///   known resource, or the error of the resource's own parser.
    public static func parse(_ scope: String) throws(ScopeParseError) -> ATProtoScope {
        // Byte comparisons: a string literal pattern would match by Unicode
        // canonical equivalence.
        if scope.isByteEqual(to: "atproto") { return .atproto }
        if scope.isByteEqual(to: "transition:email") { return .transitionEmail }
        if scope.isByteEqual(to: "transition:generic") { return .transitionGeneric }
        if scope.isByteEqual(to: "transition:chat.bsky") { return .transitionChatBsky }
        if ScopeStringSyntax.isScopeString(scope, for: AccountPermission.prefix) {
            return .account(try AccountPermission.parse(scope))
        }
        if ScopeStringSyntax.isScopeString(scope, for: BlobPermission.prefix) {
            return .blob(try BlobPermission.parse(scope))
        }
        if ScopeStringSyntax.isScopeString(scope, for: IdentityPermission.prefix) {
            return .identity(try IdentityPermission.parse(scope))
        }
        if ScopeStringSyntax.isScopeString(scope, for: IncludeScope.prefix) {
            return .include(try IncludeScope.parse(scope))
        }
        if ScopeStringSyntax.isScopeString(scope, for: RepoPermission.prefix) {
            return .repo(try RepoPermission.parse(scope))
        }
        if ScopeStringSyntax.isScopeString(scope, for: RpcPermission.prefix) {
            return .rpc(try RpcPermission.parse(scope))
        }
        throw .unknownPrefix(scope)
    }

    /// The canonical scope string
    /// (`normalizeAtprotoOauthScopeValue`, `atproto-oauth-scope.ts:61-79`).
    public func canonicalScopeString() throws(ScopeParseError) -> String {
        switch self {
        case .atproto: "atproto"
        case .transitionEmail: "transition:email"
        case .transitionGeneric: "transition:generic"
        case .transitionChatBsky: "transition:chat.bsky"
        case let .account(p): try p.canonicalScopeString()
        case let .blob(p): try p.canonicalScopeString()
        case let .identity(p): try p.canonicalScopeString()
        case let .include(s): try s.canonicalScopeString()
        case let .repo(p): try p.canonicalScopeString()
        case let .rpc(p): try p.canonicalScopeString()
        }
    }
}

extension ATProtoScope {
    /// What this scope grants, as the matchers see it. Two scopes with equal
    /// meanings allow exactly the same requests.
    var meaning: ScopeMeaning {
        switch self {
        case .atproto: ScopeMeaning(resource: "atproto")
        case .transitionEmail: ScopeMeaning(resource: "transition:email")
        case .transitionGeneric: ScopeMeaning(resource: "transition:generic")
        case .transitionChatBsky: ScopeMeaning(resource: "transition:chat.bsky")
        case let .account(p): ScopeMeaning(p)
        case let .blob(p): ScopeMeaning(p)
        case let .identity(p): ScopeMeaning(p)
        case let .include(s): ScopeMeaning(s)
        case let .repo(p): ScopeMeaning(p)
        case let .rpc(p): ScopeMeaning(p)
        }
    }

    /// The canonical scope string with `+` and `%` left percent-encoded where
    /// un-escaping them would change how the string parses. Equal to
    /// ``canonicalScopeString()`` for every other value.
    func parseableScopeString() throws(ScopeParseError) -> String {
        switch self {
        case .atproto, .transitionEmail, .transitionGeneric, .transitionChatBsky:
            try canonicalScopeString()
        case let .account(p): try p.parseableScopeString()
        case let .blob(p): try p.parseableScopeString()
        case let .identity(p): try p.parseableScopeString()
        case let .include(s): try s.parseableScopeString()
        case let .repo(p): try p.parseableScopeString()
        case let .rpc(p): try p.parseableScopeString()
        }
    }
}
