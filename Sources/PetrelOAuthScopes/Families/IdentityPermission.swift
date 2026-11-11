/// An aspect of the account's network identity an `identity:` permission can
/// name (`scopes/identity-permission.ts:7-8`).
public enum IdentityAttribute: String, Sendable, Hashable, CaseIterable {
    /// The handle, including its registration in the DID document.
    case handle
    /// `*`: full control over the DID document and handle.
    case any = "*"
}

/// An `identity:` permission: control over the account's DID document and
/// handle, such as `identity:handle`.
///
/// Port of `IdentityPermission`, `scopes/identity-permission.ts:14-54`.
public struct IdentityPermission: ScopePermission {
    /// The identity attribute. Positional, required, single-valued. It is the
    /// only parameter: `identity:*?action=manage` is invalid because `action`
    /// is not a parameter of this resource.
    public let attr: IdentityAttribute

    private let parameters: ScopeParameterValues

    /// Creates a permission for `attr`.
    public init(_ attr: IdentityAttribute) {
        self.attr = attr
        var values = ScopeParameterValues()
        values.set("attr", [attr.rawValue])
        self.parameters = values
    }

    /// Builds the permission from parameters ``schema`` has validated.
    public init(parameters: ScopeParameterValues) throws(ScopeParseError) {
        guard let attrRaw = parameters.single("attr"), let attr = IdentityAttribute(bytewise: attrRaw) else {
            throw .missingRequiredParameter(prefix: Self.schema.prefix, key: "attr")
        }
        self.attr = attr
        self.parameters = parameters
    }

    /// The parameter values this permission was built from.
    public var scopeParameters: ScopeParameterValues { parameters }

    /// The parameters of the `identity` resource
    /// (`scopes/identity-permission.ts:27-37`).
    public static let schema = ScopeParameterSchema(
        prefix: "identity",
        positionalKey: "attr",
        parameters: [
            .init(key: "attr", arity: .single, isRequired: true,
                  validate: { IdentityAttribute(bytewise: $0) != nil }),
        ]
    )

    /// An attempt to change part of the account's identity.
    public struct Target: Sendable, Hashable {
        /// The attribute acted on.
        public let attr: IdentityAttribute
        /// Creates a target.
        public init(attr: IdentityAttribute) { self.attr = attr }
    }

    /// Whether this permission covers `target`
    /// (`scopes/identity-permission.ts:19-21`). A `*` permission covers every
    /// request, but a `handle` permission does not cover a `*` request.
    public func matches(_ target: Target) -> Bool {
        attr == .any || attr == target.attr
    }

    /// The narrowest `identity:` scope that covers `target`
    /// (`scopes/identity-permission.ts:51-53`).
    public static func scopeNeeded(for target: Target) throws(ScopeParseError) -> String {
        var values = ScopeParameterValues()
        values.set("attr", [target.attr.rawValue])
        return try schema.format(values)
    }
}
