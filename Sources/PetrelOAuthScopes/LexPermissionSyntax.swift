// The two representations of a permission — a scope string and a JSON object
// in a permission set — behind one interface, so that one schema validates
// both. Port of `lib/syntax.ts:41-47` and `lib/syntax-lexicon.ts:9-55`.

// MARK: - The abstract syntax interface

/// The result of looking up a multi-valued parameter, the counterpart of
/// ``ScopeParameterBag/SingleLookup``.
public enum ScopeMultiLookup: Sendable, Hashable {
    /// The key does not appear.
    case absent
    /// The key appears but its value is not a list
    /// (`lib/syntax-lexicon.ts:48`). This makes the whole permission invalid
    /// (`lib/parser.ts:121-122`); it is neither "absent" nor a one-element
    /// list.
    case rejected
    /// The values, in order.
    case values([String])
}

/// A permission in some concrete representation, as the schema reads it
/// (`ScopeSyntax`, `lib/syntax.ts:41-47`).
///
/// ``ScopeParameterSchema/parse(_:)`` is generic over this, so every rule
/// applies identically to a scope string and to a permission-set entry.
public protocol ScopeSyntax: Sendable {
    /// The resource name.
    var prefix: String { get }
    /// The positional segment, if the representation has one.
    var positional: String? { get }
    /// The names of the parameters that are present. The schema rejects any
    /// it does not declare (`lib/parser.ts:105-107`).
    func keys() -> [String]
    /// Looks up a single-valued parameter.
    func getSingle(_ key: String) -> ScopeParameterBag.SingleLookup
    /// Looks up a multi-valued parameter.
    func getMulti(_ key: String) -> ScopeMultiLookup
}

extension ScopeStringSyntax: ScopeSyntax {
    /// The distinct parameter names, in order of first appearance.
    public func keys() -> [String] { parameters.orderedKeys() }

    /// Looks up a single-valued parameter; repeating it is
    /// ``ScopeParameterBag/SingleLookup/repeated(_:)``.
    public func getSingle(_ key: String) -> ScopeParameterBag.SingleLookup {
        parameters.single(key)
    }

    /// Looks up a multi-valued parameter. A query string cannot express
    /// "present but not a list", so this never returns
    /// ``ScopeMultiLookup/rejected``.
    public func getMulti(_ key: String) -> ScopeMultiLookup {
        guard let values = parameters.multiple(key) else { return .absent }
        return .values(values)
    }
}

// MARK: - LexPermissionSyntax

/// A permission-set entry read as a ``ScopeSyntax``. Port of
/// `LexPermissionSyntax`, `lib/syntax-lexicon.ts:9-55`.
///
/// The entry is read directly, without first being rendered as a scope string
/// and parsed back.
public struct LexPermissionSyntax: Sendable, ScopeSyntax {
    /// The entry being read.
    public let permission: LexiconPermission

    /// Wraps a permission-set entry.
    public init(permission: LexiconPermission) {
        self.permission = permission
    }

    /// The entry's `resource` (`lib/syntax-lexicon.ts:14-16`).
    public var prefix: String { permission.resource }

    /// Always `nil`: a JSON permission has no positional form
    /// (`lib/syntax-lexicon.ts:18-20`).
    public var positional: String? { nil }

    /// A field by name, with the reserved `type` and `resource` keys hidden
    /// (`lib/syntax-lexicon.ts:22-31`). Without that, every entry would carry
    /// two parameters no schema declares.
    private func get(_ key: String) -> LexiconValue? {
        if key == "type" { return nil }
        if key == "resource" { return nil }
        return permission.fields[key]
    }

    /// The entry's field names, without `type` and `resource`
    /// (`lib/syntax-lexicon.ts:33-37`).
    public func keys() -> [String] {
        permission.fields.keys.filter { get($0) != nil }
    }

    /// Looks up a single-valued parameter (`lib/syntax-lexicon.ts:39-43`). An
    /// array where one value is required is
    /// ``ScopeParameterBag/SingleLookup/repeated(_:)``, which the schema
    /// rejects.
    public func getSingle(_ key: String) -> ScopeParameterBag.SingleLookup {
        switch get(key) {
        case .none:
            return .absent
        case .some(.list):
            return .repeated([])
        case let .some(value):
            return value.scalarText.map { .present($0) } ?? .absent
        }
    }

    /// Looks up a multi-valued parameter (`lib/syntax-lexicon.ts:45-50`). A
    /// scalar where an array is required is ``ScopeMultiLookup/rejected``.
    ///
    /// So is an array containing an array. The reference implementation
    /// passes the nested array to the parameter's validator, which rejects it
    /// (`lib/parser.ts:132-134`); the outcome is the same.
    public func getMulti(_ key: String) -> ScopeMultiLookup {
        switch get(key) {
        case .none:
            return .absent
        case let .some(.list(items)):
            let texts = items.compactMap(\.scalarText)
            return texts.count == items.count ? .values(texts) : .rejected
        case .some:
            // A scalar where an array is required: not a one-element list.
            return .rejected
        }
    }

    /// The result type of ``getMulti(_:)``.
    public typealias MultiLookup = ScopeMultiLookup
}
