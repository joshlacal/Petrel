/// A component of account configuration an `account:` permission can name
/// (`scopes/account-permission.ts:7-12`). There is no wildcard.
public enum AccountAttribute: String, Sendable, Hashable, CaseIterable {
    /// The account email address and its verification status.
    case email
    /// The whole repository, as imported from a CAR file.
    case repo
    /// The hosting status of the account.
    case status
}

/// The degree of control an `account:` permission grants
/// (`scopes/account-permission.ts:14-15`).
public enum AccountAction: String, Sendable, Hashable, CaseIterable {
    /// Read the attribute.
    case read
    /// Change the attribute. Includes ``read``.
    case manage
}

/// An `account:` permission: control over the hosting details of the account,
/// such as `account:email` or `account:repo?action=manage`.
///
/// Port of `AccountPermission`, `scopes/account-permission.ts:22-78`.
public struct AccountPermission: ScopePermission {
    /// The account attribute. Positional, required, single-valued.
    public let attr: AccountAttribute
    /// The granted actions. Optional, defaulting to `read`
    /// (`scopes/account-permission.ts:49-54`); never empty.
    public let action: [AccountAction]

    private let parameters: ScopeParameterValues

    /// Creates a permission for `attr`.
    public init(attr: AccountAttribute, action: [AccountAction] = [.read]) {
        self.attr = attr
        self.action = action
        var values = ScopeParameterValues()
        values.set("attr", [attr.rawValue])
        values.set("action", action.map(\.rawValue))
        self.parameters = values
    }

    /// Builds the permission from parameters ``schema`` has validated.
    public init(parameters: ScopeParameterValues) throws(ScopeParseError) {
        guard let attrRaw = parameters.single("attr"), let attr = AccountAttribute(bytewise: attrRaw) else {
            throw .missingRequiredParameter(prefix: Self.schema.prefix, key: "attr")
        }
        let actionRaw = parameters.multiple("action")
        let action = actionRaw.compactMap(AccountAction.init(bytewise:))
        guard action.count == actionRaw.count, !action.isEmpty else {
            throw .invalidParameterValue(prefix: Self.schema.prefix, key: "action", value: actionRaw.joined(separator: ","))
        }
        self.attr = attr
        self.action = action
        self.parameters = parameters
    }

    /// The parameter values this permission was built from.
    public var scopeParameters: ScopeParameterValues { parameters }

    /// The parameters of the `account` resource
    /// (`scopes/account-permission.ts:41-57`).
    public static let schema = ScopeParameterSchema(
        prefix: "account",
        positionalKey: "attr",
        parameters: [
            .init(key: "attr", arity: .single, isRequired: true,
                  validate: { AccountAttribute(bytewise: $0) != nil }),
            // No `normalize`: the reference implementation declares none for
            // this parameter (`scopes/account-permission.ts:49-54`), so the
            // canonical form keeps the actions in the order they were written.
            // `account:email?action=manage&action=read` is its own canonical
            // form; sorting the actions here would change those bytes.
            .init(key: "action", arity: .multiple,
                  defaultValue: [AccountAction.read.rawValue],
                  validate: { AccountAction(bytewise: $0) != nil }),
        ]
    )

    /// An attempt to act on an account attribute.
    public struct Target: Sendable, Hashable {
        /// The attribute acted on.
        public let attr: AccountAttribute
        /// The action attempted.
        public let action: AccountAction

        /// Creates a target.
        public init(attr: AccountAttribute, action: AccountAction) {
            self.attr = attr
            self.action = action
        }
    }

    /// Whether this permission covers `target`
    /// (`scopes/account-permission.ts:30-35`). `manage` includes `read`; a
    /// `read` permission never covers a `manage` request.
    public func matches(_ target: Target) -> Bool {
        guard attr == target.attr else { return false }
        return action.contains(.manage) || action.contains(target.action)
    }

    /// The narrowest `account:` scope that covers `target`
    /// (`scopes/account-permission.ts:72-77`).
    ///
    /// The string is the canonical form, except that a `+` or `%` in a value
    /// stays percent-encoded, so it parses back to a scope covering `target`
    /// (the reference's canonical form would read a literal `%41` as `A`),
    /// whenever any scope can grant `target`; see ``grantingScope(for:)``.
    public static func scopeNeeded(for target: Target) throws(ScopeParseError) -> String {
        var values = ScopeParameterValues()
        values.set("attr", [target.attr.rawValue])
        values.set("action", [target.action.rawValue])
        return try schema.formatParseable(values)
    }
}
