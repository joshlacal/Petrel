/// A record operation a `repo:` permission can allow
/// (`scopes/repo-permission.ts:15-20`). There is no wildcard action:
/// `repo:*?action=*` is rejected.
public enum RepoAction: String, Sendable, Hashable, CaseIterable {
    /// Create a record.
    case create
    /// Replace an existing record.
    case update
    /// Delete a record.
    case delete
}

/// Every repository action, in canonical order. This is the default for a
/// `repo:` permission that names no action.
public let REPO_ACTIONS: [RepoAction] = [.create, .update, .delete]

/// A record type a `repo:` permission covers
/// (`scopes/repo-permission.ts:23-25`).
public enum CollectionParam: Sendable, Hashable, Comparable {
    /// `*`: every collection.
    case any
    /// One collection, by NSID.
    case nsid(String)

    /// The value as it is written in a scope.
    public var stringValue: String {
        switch self {
        case .any: "*"
        case let .nsid(value): value
        }
    }

    /// Orders values by ``stringValue``.
    public static func < (lhs: CollectionParam, rhs: CollectionParam) -> Bool {
        lhs.stringValue < rhs.stringValue
    }
}

/// A `repo:` permission: write access to records in the account's public
/// repository, such as `repo:app.example.profile` or `repo:*?action=delete`.
///
/// Port of `RepoPermission`, `scopes/repo-permission.ts:32-101`.
public struct RepoPermission: ScopePermission {
    /// The collections. Positional, required, with no default; never empty
    /// when parsed.
    public let collection: [CollectionParam]
    /// The allowed operations. Optional, defaulting to all three
    /// (`scopes/repo-permission.ts:67-71`).
    public let action: [RepoAction]

    private let parameters: ScopeParameterValues

    /// Creates a permission for `collection`.
    public init(collection: [CollectionParam], action: [RepoAction] = REPO_ACTIONS) {
        self.collection = collection
        self.action = action
        var values = ScopeParameterValues()
        values.set("collection", collection.map(\.stringValue))
        values.set("action", action.map(\.rawValue))
        self.parameters = values
    }

    /// Builds the permission from parameters ``schema`` has validated.
    public init(parameters: ScopeParameterValues) throws(ScopeParseError) {
        let collectionRaw = parameters.multiple("collection")
        guard !collectionRaw.isEmpty else {
            throw .emptyMultiValuedParameter(prefix: Self.schema.prefix, key: "collection")
        }
        self.collection = collectionRaw.map { $0 == "*" ? .any : .nsid($0) }
        let actionRaw = parameters.multiple("action")
        let action = actionRaw.compactMap(RepoAction.init(rawValue:))
        guard action.count == actionRaw.count else {
            throw .invalidParameterValue(prefix: Self.schema.prefix, key: "action", value: actionRaw.joined(separator: ","))
        }
        self.action = action
        self.parameters = parameters
    }

    /// The parameter values this permission was built from.
    public var scopeParameters: ScopeParameterValues { parameters }

    /// The parameters of the `repo` resource
    /// (`scopes/repo-permission.ts:52-80`).
    public static let schema = ScopeParameterSchema(
        prefix: "repo",
        positionalKey: "collection",
        parameters: [
            // Declared first, so `collection` precedes `action` in the
            // canonical form.
            .init(key: "collection", arity: .multiple, isRequired: true,
                  // scopes/repo-permission.ts:59-65 — a list containing `*` is
                  // just `*`; otherwise duplicates are dropped and the list is
                  // sorted.
                  normalize: { $0.contains("*") && $0.count > 1 ? ["*"] : Array(Set($0)).sorted() },
                  validate: { $0 == "*" || AtprotoSyntax.isValidNSID($0) }),
            .init(key: "action", arity: .multiple,
                  defaultValue: REPO_ACTIONS.map(\.rawValue),
                  // scopes/repo-permission.ts:72-76 — the actions in canonical
                  // order, so `action=delete&action=create` is written
                  // `action=create&action=delete`.
                  normalize: { given in RepoAction.allCases.map(\.rawValue).filter(given.contains) },
                  validate: { RepoAction(rawValue: $0) != nil }),
        ]
    )

    /// An attempt to write a record.
    public struct Target: Sendable, Hashable {
        /// The NSID of the record's collection.
        public let collection: String
        /// The operation attempted.
        public let action: RepoAction
        /// Creates a target.
        public init(collection: String, action: RepoAction) {
            self.collection = collection
            self.action = action
        }
    }

    /// Whether this permission covers `target`
    /// (`scopes/repo-permission.ts:40-46`). A collection matches when it is
    /// listed or when `*` is; partial wildcards such as `com.example.*` do not
    /// exist.
    public func matches(_ target: Target) -> Bool {
        guard action.contains(target.action) else { return false }
        if collection.contains(.any) { return true }
        return collection.contains(.nsid(target.collection))
    }

    /// The narrowest `repo:` scope that covers `target`
    /// (`scopes/repo-permission.ts:95-100`), such as
    /// `repo:com.example.foo?action=create`. The collection is not validated
    /// (`scopes/repo-permission.test.ts:106-116`).
    public static func scopeNeeded(for target: Target) throws(ScopeParseError) -> String {
        var values = ScopeParameterValues()
        values.set("collection", [target.collection])
        values.set("action", [target.action.rawValue])
        return try schema.format(values)
    }
}
