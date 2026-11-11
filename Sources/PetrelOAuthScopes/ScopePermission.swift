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

    /// What this scope grants, independent of how it was written.
    var meaning: ScopeMeaning {
        ScopeMeaning(resource: Self.schema.prefix, parameters: Self.schema.meaning(of: scopeParameters))
    }
}

/// What a scope grants, independent of how it was written: the resource and
/// the normalised values of its parameters. Equal for two scopes exactly when
/// they are the same grant.
struct ScopeMeaning: Hashable {
    let resource: ScopeBytes
    /// Parameter name → the set of its normalised values, as bytes.
    let parameters: [String: Set<ScopeBytes>]

    init(resource: String, parameters: [String: Set<ScopeBytes>]) {
        self.resource = resource.scopeBytes
        self.parameters = parameters
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
    /// of a denial (`scopes-set.ts:49-57`). Total over `Target`.
    static func scopeNeeded(for target: Target) throws(ScopeParseError) -> String
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
    /// What this scope grants, independent of how it was written.
    var meaning: ScopeMeaning {
        switch self {
        case .atproto: ScopeMeaning(resource: "atproto", parameters: [:])
        case .transitionEmail: ScopeMeaning(resource: "transition:email", parameters: [:])
        case .transitionGeneric: ScopeMeaning(resource: "transition:generic", parameters: [:])
        case .transitionChatBsky: ScopeMeaning(resource: "transition:chat.bsky", parameters: [:])
        case let .account(p): p.meaning
        case let .blob(p): p.meaning
        case let .identity(p): p.meaning
        case let .include(s): s.meaning
        case let .repo(p): p.meaning
        case let .rpc(p): p.meaning
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
