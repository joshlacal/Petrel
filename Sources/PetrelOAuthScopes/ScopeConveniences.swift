import Foundation

// Conveniences for code that builds and compares scopes, as an OAuth client
// does: typed builders, set construction, coverage checks, and an expansion
// that says why an entry was dropped.

/// The name an OAuth client knows a Lexicon permission set by.
public typealias ATProtoPermissionSet = LexiconPermissionSet
/// The error every scope parse failure is reported as.
public typealias ATProtoScopeError = ScopeParseError
/// `RpcPermission`, spelled the way the rest of Petrel spells RPC.
public typealias RPCPermission = RpcPermission

// MARK: - Building scopes

public extension ATProtoScope {
    /// Parses one scope string. Equivalent to ``parse(_:)``.
    init(_ string: String) throws(ScopeParseError) {
        self = try Self.parse(string)
    }

    /// The scope string to send to a server or store: a string that parses
    /// back to this scope.
    ///
    /// For almost every scope this is ``canonicalScopeString()``. The
    /// exception is a value containing `+` or `%` in a named parameter, where
    /// the canonical form — kept byte-identical with the reference
    /// implementation — would be read back as a different value or rejected
    /// (see <doc:ReferenceParity>). For those the `+` or `%` stays
    /// percent-encoded: `blob?accept=image/png&accept=image/svg%2Bxml` rather
    /// than the canonical `…&accept=image/svg+xml`.
    ///
    /// `nil` only for a value that no scope string describes: one assembled
    /// through a permission's own initializer from parts the parser would
    /// reject, such as an `rpc` permission for every method on every service.
    /// The builders (``repo(collections:actions:)`` and the others) parse
    /// what they build, so they never return such a value.
    var scopeString: String? {
        guard let canonical = try? canonicalScopeString() else { return nil }
        if (try? Self.parse(canonical))?.meaning == meaning { return canonical }
        guard let escaped = try? parseableScopeString(), (try? Self.parse(escaped))?.meaning == meaning else {
            return nil
        }
        return escaped
    }

    /// `repo:` — write access to record collections.
    ///
    /// - Parameters:
    ///   - collections: record-type NSIDs, or `["*"]` for every collection.
    ///   - actions: the permitted writes. All three by default.
    static func repo(
        collections: [String],
        actions: [RepoAction] = RepoAction.allCases
    ) throws(ScopeParseError) -> ATProtoScope {
        try build("repo", collections.map { ("collection", $0) } + actions.map { ("action", $0.rawValue) })
    }

    /// `rpc:` — calling methods on another service as the account.
    ///
    /// - Parameters:
    ///   - lxm: method NSIDs, or `["*"]` for every method.
    ///   - aud: the service, as a DID with a service fragment
    ///     (`did:web:api.example.com#svc`), or `*`. `lxm` and `aud` cannot both
    ///     be wildcards.
    static func rpc(lxm: [String], aud: String) throws(ScopeParseError) -> ATProtoScope {
        try build("rpc", lxm.map { ("lxm", $0) } + [("aud", aud)])
    }

    /// `blob:` — uploading media of the given MIME types (`image/*`, `*/*`,
    /// `video/mp4`).
    static func blob(accept: [String]) throws(ScopeParseError) -> ATProtoScope {
        try build("blob", accept.map { ("accept", $0) })
    }

    /// `account:` — reading or managing one account attribute.
    static func account(
        attribute: AccountAttribute,
        action: AccountAction = .read
    ) throws(ScopeParseError) -> ATProtoScope {
        try build("account", [("attr", attribute.rawValue), ("action", action.rawValue)])
    }

    /// `identity:` — changing the account's handle, or (`.any`) its whole
    /// identity.
    static func identity(attribute: IdentityAttribute) throws(ScopeParseError) -> ATProtoScope {
        try build("identity", [("attr", attribute.rawValue)])
    }

    /// `include:` — a named permission set, optionally with the audience its
    /// `inheritAud` RPC permissions take.
    static func include(nsid: String, aud: String? = nil) throws(ScopeParseError) -> ATProtoScope {
        try build("include", [("nsid", nsid)] + (aud.map { [("aud", $0)] } ?? []))
    }

    /// Serialises the parameters with every value percent-encoded and parses
    /// the result, so a builder accepts exactly what the parser accepts.
    private static func build(_ resource: String, _ parameters: [(String, String)]) throws(ScopeParseError) -> ATProtoScope {
        let query = parameters.map { "\($0.0)=\(encode($0.1))" }.joined(separator: "&")
        return try parse(query.isEmpty ? resource : "\(resource)?\(query)")
    }

    private static func encode(_ value: String) -> String {
        var output = ""
        for byte in value.utf8 {
            switch byte {
            case 0x30 ... 0x39, 0x41 ... 0x5A, 0x61 ... 0x7A, 0x2D, 0x2E, 0x5F, 0x7E, 0x2A:
                output.unicodeScalars.append(UnicodeScalar(byte))
            default:
                let hex = String(byte, radix: 16, uppercase: true)
                output += "%" + (hex.count == 1 ? "0" + hex : hex)
            }
        }
        return output
    }
}

// MARK: - Building and reading sets

extension ATProtoScopeSet: ExpressibleByArrayLiteral {
    /// Creates a set from typed scopes.
    ///
    /// The scopes are kept as given — nothing is serialised and parsed again,
    /// so what the set grants is exactly what the values say. ``rawScopes``
    /// holds each scope's ``ATProtoScope/scopeString``, which parses back to
    /// it, so `ATProtoScopeSet(scopes)` equals
    /// `ATProtoScopeSet(scope: ATProtoScopeSet(scopes).scopeString)` and
    /// grants the same.
    ///
    /// A value that no scope string describes (see
    /// ``ATProtoScope/scopeString``) grants nothing and is recorded in
    /// ``rejected`` with the parser's reason. Its canonical form, when it has
    /// one, is kept in ``rawScopes`` — so ``scopeString`` carries it and a
    /// server refuses it — exactly as if that string had arrived in a token.
    public init(_ scopes: [ATProtoScope]) {
        var rawScopes = Set<String>()
        var grants: [(string: String, scope: ATProtoScope)] = []
        var rejected: [String: ScopeParseError] = [:]
        for scope in scopes {
            if let string = scope.scopeString {
                if rawScopes.insert(string).inserted {
                    grants.append((string, scope))
                }
                continue
            }
            guard let canonical = try? scope.canonicalScopeString() else {
                let label = String(describing: scope)
                rejected[label] = .notAScopeToken(label)
                continue
            }
            do {
                // Reads back as some other scope: never let that stand in for this one.
                _ = try ATProtoScope.parse(canonical)
                rejected[canonical] = .notAScopeToken(canonical)
            } catch {
                rawScopes.insert(canonical)
                rejected[canonical] = error
            }
        }
        // The same order `init(rawScopes:)` produces: by scope string.
        self.init(
            rawScopes: rawScopes,
            grants: grants.sorted { $0.string < $1.string }.map(\.scope),
            rejected: rejected
        )
    }

    public init(arrayLiteral elements: ATProtoScope...) {
        self.init(elements)
    }

    /// Parses a space-delimited scope value and fails on the first token that
    /// is not a recognised scope, where ``init(scope:)`` records it in
    /// ``rejected`` and carries on.
    public init(strict scope: String) throws(ScopeParseError) {
        let tokens = scope.split(separator: " ").map(String.init)
        for token in tokens {
            _ = try ATProtoScope.parse(token)
        }
        self.init(rawScopes: Set(tokens))
    }

    /// The scope strings that did not parse, sorted. They grant nothing.
    public var unrecognized: [String] {
        rejected.keys.sorted()
    }

    /// The parsed scopes, in a stable order.
    public var scopes: [ATProtoScope] {
        grants
    }

    /// The set as a space-delimited `scope` value: the strings exactly as they
    /// were given, sorted.
    public var scopeString: String {
        rawScopes.sorted().joined(separator: " ")
    }

    /// The set as a space-delimited `scope` value with every recognised scope
    /// written as its ``ATProtoScope/scopeString`` — the canonical form, except
    /// where that would not parse back to the same scope — duplicates removed
    /// and sorted. Unrecognised strings are kept as they are.
    public var normalizedScopeString: String {
        Set(rawScopes.map { raw in (try? ATProtoScope.parse(raw))?.scopeString ?? raw })
            .sorted().joined(separator: " ")
    }

    /// True when the set contains `atproto`.
    public var includesAtproto: Bool { hasBaseATProtocolScope }

    /// Whether everything `needed` describes is granted by this set.
    ///
    /// A client uses this to decide whether a session it already holds is
    /// enough for an operation, or whether it must ask for more.
    ///
    /// The answer agrees with the matchers. For a need that names only
    /// concrete things — collections, methods with a service, media types,
    /// attributes — it is `true` exactly when ``allowsRepo(_:)``,
    /// ``allowsRPC(_:)``, ``allowsBlob(_:)``, ``allowsAccount(_:)`` or
    /// ``allowsIdentity(_:)`` allows every one of them, transition scopes
    /// included. For a need with a wildcard it is `true` only when the grant
    /// is at least that wide, so that everything the wildcard could stand for
    /// would be allowed:
    ///
    /// - any collection: `repo:*` for the action, or `transition:generic`;
    /// - a method on any service (`aud=*`): an `rpc` grant for the method with
    ///   `aud=*`, or the transition scope that covers the method, since
    ///   transition scopes are not tied to a service;
    /// - any method on a service: an `rpc:*` grant for that service, or
    ///   `transition:generic` together with `transition:chat.bsky`, since
    ///   neither alone covers every method;
    /// - `type/*` or `*/*`: a `blob` grant with that pattern or `*/*`, or
    ///   `transition:generic`.
    ///
    /// An `include:` is covered only by the same `include:`, because what it
    /// expands to is not known here.
    public func covers(_ needed: ATProtoScope) -> Bool {
        switch needed {
        case .atproto:
            return hasBaseATProtocolScope
        case .transitionGeneric:
            return hasTransitionGeneric
        case .transitionEmail:
            return hasTransitionEmail
        case .transitionChatBsky:
            return hasTransitionChatBsky
        case let .include(include):
            return grants.contains {
                guard case let .include(grant) = $0 else { return false }
                return grant.meaning == include.meaning
            }
        case let .repo(permission):
            return permission.action.allSatisfy { action in
                permission.collection.allSatisfy { collection in
                    switch collection {
                    case let .nsid(nsid):
                        return allowsRepo(.init(collection: nsid, action: action))
                    case .any:
                        return hasTransitionGeneric || grants.contains {
                            guard case let .repo(grant) = $0 else { return false }
                            return grant.collection.contains(.any) && grant.action.contains(action)
                        }
                    }
                }
            }
        case let .rpc(permission):
            return permission.lxm.allSatisfy { lxm in
                switch (lxm, permission.aud) {
                case let (.nsid(method), .service(audience)):
                    return allowsRPC(.init(lxm: method, aud: audience))
                case let (.nsid(method), .any):
                    // Transition scopes allow a method on every service.
                    if hasTransitionGeneric, !method.hasPrefix("chat.bsky.") { return true }
                    if hasTransitionChatBsky, method.hasPrefix("chat.bsky.") { return true }
                    return grants.contains {
                        guard case let .rpc(grant) = $0 else { return false }
                        return grant.aud == .any && (grant.lxm.contains(.any) || grant.lxm.contains(lxm))
                    }
                case (.any, _):
                    // Every method: the two transition scopes together, or a
                    // wildcard grant for this audience.
                    if hasTransitionGeneric, hasTransitionChatBsky { return true }
                    return grants.contains {
                        guard case let .rpc(grant) = $0 else { return false }
                        return grant.lxm.contains(.any) && (grant.aud == .any || grant.aud == permission.aud)
                    }
                }
            }
        case let .blob(permission):
            return permission.accept.allSatisfy { pattern in
                switch pattern {
                case let .exact(type, subtype):
                    return allowsBlob(.init(mime: "\(type)/\(subtype)"))
                case .any, .type:
                    return hasTransitionGeneric || grants.contains {
                        guard case let .blob(grant) = $0 else { return false }
                        return grant.accept.contains(.any) || grant.accept.contains(pattern)
                    }
                }
            }
        case let .account(permission):
            return permission.action.allSatisfy { allowsAccount(.init(attr: permission.attr, action: $0)) }
        case let .identity(permission):
            return allowsIdentity(.init(attr: permission.attr))
        }
    }

    /// Whether every recognised scope of `needed` is covered by this set.
    public func covers(_ needed: ATProtoScopeSet) -> Bool {
        needed.grants.allSatisfy(covers)
    }
}

// MARK: - Expansion with reasons

public extension IncludeScope {
    /// Why a permission-set entry contributed nothing.
    enum ExpansionRejectionReason: Sendable, Equatable {
        /// The entry names a resource that may not appear in a permission set
        /// (anything but `repo` and `rpc`), or an `rpc` entry fixes its own
        /// audience.
        case notAllowedInPermissionSet
        /// The entry does not parse as its resource: an unknown or malformed
        /// parameter, a wildcard, or an `inheritAud` with nothing to inherit.
        case invalidPermission
        /// The entry reaches outside the namespace the set has authority over.
        case outsideNamespaceAuthority
    }

    /// One dropped entry of a permission set.
    struct ExpansionRejection: Sendable, Equatable {
        /// The entry's position in the set's `permissions`.
        public let index: Int
        /// The entry.
        public let permission: LexiconPermission
        /// Why it was dropped.
        public let reason: ExpansionRejectionReason
    }

    /// Expands a permission set like ``expand(_:)`` and also reports each entry
    /// that was ignored and why. The granted permissions are identical to
    /// those of ``expand(_:)``.
    func expansion(
        of set: LexiconPermissionSet
    ) -> (permissions: [IncludedPermission], rejections: [ExpansionRejection]) {
        var permissions: [IncludedPermission] = []
        var rejections: [ExpansionRejection] = []
        for (index, entry) in set.permissions.enumerated() {
            guard let syntax = lexSyntax(for: entry) else {
                rejections.append(.init(index: index, permission: entry, reason: .notAllowedInPermissionSet))
                continue
            }
            guard let permission = IncludedPermission(syntax) else {
                rejections.append(.init(index: index, permission: entry, reason: .invalidPermission))
                continue
            }
            guard isAllowed(permission) else {
                rejections.append(.init(index: index, permission: entry, reason: .outsideNamespaceAuthority))
                continue
            }
            permissions.append(permission)
        }
        return (permissions, rejections)
    }
}
