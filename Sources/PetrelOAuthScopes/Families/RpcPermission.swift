/// A method an `rpc:` permission covers (`scopes/rpc-permission.ts:15-17`).
public enum LxmParam: Sendable, Hashable, Comparable {
    /// `*`: every method.
    case any
    /// One method, by NSID.
    case nsid(String)

    /// The value as it is written in a scope.
    public var stringValue: String {
        switch self {
        case .any: "*"
        case let .nsid(value): value
        }
    }

    /// Two methods are equal when they are the same bytes; Unicode
    /// equivalence plays no part.
    public static func == (lhs: LxmParam, rhs: LxmParam) -> Bool {
        switch (lhs, rhs) {
        case (.any, .any): true
        case let (.nsid(a), .nsid(b)): a.isByteEqual(to: b)
        default: false
        }
    }

    /// Hashes the bytes, consistently with `==`.
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .any: hasher.combine(0 as UInt8)
        case let .nsid(value): hasher.combine(1 as UInt8); hasher.combine(value.scopeBytes)
        }
    }

    /// Orders values by ``stringValue``.
    public static func < (lhs: LxmParam, rhs: LxmParam) -> Bool {
        lhs.stringValue < rhs.stringValue
    }
}

/// The service an `rpc:` permission is restricted to
/// (`scopes/rpc-permission.ts:18-20`).
public enum AudParam: Sendable, Hashable {
    /// `*`: every service.
    case any
    /// One service: a `did:plc` or `did:web` DID followed by a mandatory
    /// service fragment, such as `did:web:api.example.com#svc_appview`
    /// (``AtprotoSyntax/isValidAtprotoDIDRefAbsolute(_:)``).
    case service(String)

    /// The value as it is written in a scope, before percent-encoding.
    public var stringValue: String {
        switch self {
        case .any: "*"
        case let .service(value): value
        }
    }

    /// Two services are equal when they are the same bytes; Unicode
    /// equivalence plays no part.
    public static func == (lhs: AudParam, rhs: AudParam) -> Bool {
        switch (lhs, rhs) {
        case (.any, .any): true
        case let (.service(a), .service(b)): a.isByteEqual(to: b)
        default: false
        }
    }

    /// Hashes the bytes, consistently with `==`.
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .any: hasher.combine(0 as UInt8)
        case let .service(value): hasher.combine(1 as UInt8); hasher.combine(value.scopeBytes)
        }
    }
}

/// An `rpc:` permission: the ability to make authenticated requests to remote
/// services, whether proxied or through a service auth token, such as
/// `rpc:app.example.moderation.createReport?aud=*`.
///
/// Port of `RpcPermission`, `scopes/rpc-permission.ts:27-90`.
public struct RpcPermission: ScopePermission {
    /// The audience. Required, single-valued, with no default: a scope
    /// without `aud` is rejected (`scopes/rpc-permission.test.ts:58-63`).
    public let aud: AudParam
    /// The methods. Positional, required; never empty when parsed.
    public let lxm: [LxmParam]

    private let parameters: ScopeParameterValues

    /// Creates a permission for `lxm` on `aud`.
    ///
    /// Any audience together with any method is not a valid permission, but
    /// that rule is applied when parsing (as in the reference implementation,
    /// `scopes/rpc-permission.ts:78-79`), not by this initializer.
    public init(aud: AudParam, lxm: [LxmParam]) {
        self.aud = aud
        self.lxm = lxm
        var values = ScopeParameterValues()
        values.set("lxm", lxm.map(\.stringValue))
        values.set("aud", [aud.stringValue])
        self.parameters = values
    }

    /// Builds the permission from parameters ``schema`` has validated.
    ///
    /// - Throws: ``ScopeParseError/forbiddenParameterCombination(prefix:detail:)``
    ///   for a wildcard `aud` together with a wildcard `lxm`.
    public init(parameters: ScopeParameterValues) throws(ScopeParseError) {
        let lxmRaw = parameters.multiple("lxm")
        guard !lxmRaw.isEmpty else {
            throw .emptyMultiValuedParameter(prefix: Self.schema.prefix, key: "lxm")
        }
        let lxm = lxmRaw.map { $0.isByteEqual(to: "*") ? LxmParam.any : .nsid($0) }
        guard let audRaw = parameters.single("aud") else {
            throw .missingRequiredParameter(prefix: Self.schema.prefix, key: "aud")
        }
        let aud: AudParam = audRaw.isByteEqual(to: "*") ? .any : .service(audRaw)
        // scopes/rpc-permission.ts:78-79 — `rpc:*?aud=*` is forbidden: a
        // permission must be restricted by at least one of the two.
        if case .any = aud, lxm.contains(.any) {
            throw .forbiddenParameterCombination(
                prefix: Self.schema.prefix, detail: "aud=* and lxm=* together"
            )
        }
        self.aud = aud
        self.lxm = lxm
        self.parameters = parameters
    }

    /// The parameter values this permission was built from.
    public var scopeParameters: ScopeParameterValues { parameters }

    /// The parameters of the `rpc` resource
    /// (`scopes/rpc-permission.ts:47-66`).
    public static let schema = ScopeParameterSchema(
        prefix: "rpc",
        positionalKey: "lxm",
        parameters: [
            // scopes/rpc-permission.ts:54-57 — a list containing `*` is just
            // `*`; otherwise duplicates are dropped and the list is sorted.
            .init(key: "lxm", arity: .multiple, isRequired: true,
                  normalize: { $0.containsBytes(of: "*") && $0.count > 1 ? ["*"] : Array(Set($0)).sorted() },
                  validate: { $0.isByteEqual(to: "*") || AtprotoSyntax.isValidNSID($0) }),
            // scopes/rpc-permission.ts:19-20 — `*` or an atproto DID with a
            // service fragment. A DID of another method, or one without a
            // fragment, is not an audience.
            .init(key: "aud", arity: .single, isRequired: true,
                  validate: { $0.isByteEqual(to: "*") || AtprotoSyntax.isValidAtprotoDIDRefAbsolute($0) }),
        ]
    )

    /// An attempt to call a method on a service.
    public struct Target: Sendable, Hashable {
        /// The NSID of the method.
        public let lxm: String
        /// The service: a DID with a service fragment.
        public let aud: String
        /// Creates a target.
        public init(lxm: String, aud: String) {
            self.lxm = lxm
            self.aud = aud
        }
    }

    /// Whether this permission covers `target`
    /// (`scopes/rpc-permission.ts:35-41`). Both dimensions compare whole
    /// strings; there is no prefix matching on `lxm`.
    public func matches(_ target: Target) -> Bool {
        switch aud {
        case .any: break
        case let .service(s): guard s.isByteEqual(to: target.aud) else { return false }
        }
        if lxm.contains(.any) { return true }
        return lxm.contains(.nsid(target.lxm))
    }

    /// The narrowest `rpc:` scope that covers `target`
    /// (`scopes/rpc-permission.ts:84-89`). The target is not validated.
    public static func scopeNeeded(for target: Target) throws(ScopeParseError) -> String {
        var values = ScopeParameterValues()
        values.set("lxm", [target.lxm])
        values.set("aud", [target.aud])
        return try schema.format(values)
    }
}
