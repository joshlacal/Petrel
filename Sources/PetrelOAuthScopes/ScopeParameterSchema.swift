/// One parameter a resource declares.
///
/// The order of declaration in ``ScopeParameterSchema/parameters`` is the
/// canonical serialisation order (`lib/parser.ts:54`), which is why the schema
/// holds an array and not a dictionary.
public struct ScopeParameter: Sendable {
    /// Whether a parameter takes one value or a list.
    public enum Arity: Sendable, Hashable {
        /// Exactly one value; repeating the parameter is an error.
        case single
        /// One or more values, given by repeating the parameter.
        case multiple
    }

    /// The parameter name.
    public let key: String
    /// Whether the parameter takes one value or a list.
    public let arity: Arity
    /// Whether a scope without this parameter is invalid.
    public let isRequired: Bool
    /// The value used when the parameter is omitted. `nil` means there is no
    /// default: an omitted parameter stays absent (`include`'s `aud`).
    public let defaultValue: [String]?
    /// Whether a single value is acceptable for this parameter.
    public let validate: @Sendable (String) -> Bool
    /// Reduces a list of values to its canonical representation. Applied
    /// before the comparison with the default and before serialisation
    /// (`lib/parser.ts:61-64`).
    public let normalize: @Sendable ([String]) -> [String]

    /// Declares a parameter.
    public init(
        key: String,
        arity: Arity,
        isRequired: Bool = false,
        defaultValue: [String]? = nil,
        normalize: @escaping @Sendable ([String]) -> [String] = { $0 },
        validate: @escaping @Sendable (String) -> Bool
    ) {
        self.key = key
        self.arity = arity
        self.isRequired = isRequired
        self.defaultValue = defaultValue
        self.normalize = normalize
        self.validate = validate
    }
}

/// The parsed, validated and defaulted parameter values of one scope.
///
/// Each value records whether it was written in the scope or supplied by the
/// schema's default. Canonical serialisation cannot carry that distinction,
/// because it omits a value equal to its default: `repo:a.b.c` and
/// `repo:a.b.c?action=create&action=update&action=delete` have the same
/// canonical form. Nothing in the matching rules depends on it; it is there for
/// a caller that needs to tell the two apart, such as a consent screen.
public struct ScopeParameterValues: Sendable, Hashable {
    /// Where a parameter's value came from.
    public enum Provenance: Sendable, Hashable {
        /// The parameter appeared in the scope, by name or positionally.
        case stated
        /// The parameter was absent and ``ScopeParameter/defaultValue``
        /// supplied it.
        case defaulted
    }

    private struct Slot: Sendable, Hashable {
        let values: [String]
        let provenance: Provenance
    }

    private var storage: [String: Slot]

    /// Creates an empty set of values.
    public init() { self.storage = [:] }

    /// The first value for `key`, or `nil` when the parameter is absent.
    public func single(_ key: String) -> String? { storage[key]?.values.first }
    /// Every value for `key`; empty when the parameter is absent.
    public func multiple(_ key: String) -> [String] { storage[key]?.values ?? [] }
    /// Whether the parameter has a value, stated or defaulted.
    public func has(_ key: String) -> Bool { storage[key] != nil }

    /// Whether the parameter was written in the scope rather than defaulted.
    public func wasStated(_ key: String) -> Bool { storage[key]?.provenance == .stated }

    /// Where the value for `key` came from, or `nil` when the parameter is
    /// absent.
    public func provenance(for key: String) -> Provenance? { storage[key]?.provenance }

    /// Every parameter that was written in the scope.
    public var statedKeys: Set<String> {
        Set(storage.compactMap { $0.value.provenance == .stated ? $0.key : nil })
    }

    /// Sets the values for `key`.
    public mutating func set(_ key: String, _ values: [String], _ provenance: Provenance = .stated) {
        storage[key] = Slot(values: values, provenance: provenance)
    }
}

/// The parameters one resource accepts, and the rules for reading and writing
/// them. Port of `Parser`, `lib/parser.ts:39-160`.
public struct ScopeParameterSchema: Sendable {
    /// The resource name, such as `repo`.
    public let prefix: String
    /// The parameter that may also be written as the `:positional` segment.
    public let positionalKey: String?
    /// The parameters, in canonical serialisation order.
    public let parameters: [ScopeParameter]

    /// Declares the parameters of a resource.
    public init(prefix: String, positionalKey: String? = nil, parameters: [ScopeParameter]) {
        self.prefix = prefix
        self.positionalKey = positionalKey
        self.parameters = parameters
    }

    private var keys: Set<String> { Set(parameters.map(\.key)) }

    // MARK: parse

    /// Validates `syntax` against this schema and applies defaults
    /// (`lib/parser.ts:101-160`). Every `return null` there is a typed error
    /// here.
    ///
    /// The method is generic over ``ScopeSyntax`` just as the reference
    /// implementation's is, so a scope string and a permission-set entry
    /// (``LexPermissionSyntax``) reach each rule — unknown parameter, repeated
    /// single value, non-array list, empty list, invalid value, missing
    /// required parameter — through this one body.
    public func parse(_ syntax: some ScopeSyntax) throws(ScopeParseError) -> ScopeParameterValues {
        guard syntax.prefix.isByteEqual(to: prefix) else {
            throw .prefixMismatch(expected: prefix, actual: syntax.prefix)
        }

        // lib/parser.ts:105-107 — a parameter the schema does not declare
        // invalidates the whole scope. This is why `identity:*?action=manage`
        // is rejected: `identity` has no `action`.
        let declared = keys
        for key in syntax.keys() where !declared.contains(key) {
            throw .unknownParameter(prefix: prefix, key: key)
        }

        var result = ScopeParameterValues()
        for parameter in parameters {
            let named: [String]?
            switch parameter.arity {
            case .single:
                switch syntax.getSingle(parameter.key) {
                case .absent:
                    named = nil
                case let .present(value):
                    named = [value]
                case .repeated:
                    // lib/parser.ts:121-122, reached from
                    // lib/syntax-string.ts:21 (a repeated parameter) or
                    // lib/syntax-lexicon.ts:41 (an array where one value is
                    // required).
                    throw .repeatedSingleValuedParameter(prefix: prefix, key: parameter.key)
                }
            case .multiple:
                switch syntax.getMulti(parameter.key) {
                case .absent:
                    named = nil
                case let .values(values):
                    named = values
                case .rejected:
                    // lib/parser.ts:121-122, reached from
                    // lib/syntax-lexicon.ts:48 — present, but not an array.
                    // Unreachable from a scope string. Wrapping the scalar in
                    // a one-element list instead would turn an entry the
                    // reference implementation ignores into a grant.
                    throw .invalidParameterValue(
                        prefix: prefix, key: parameter.key, value: "<not an array>"
                    )
                }
            }

            if let named {
                // lib/parser.ts:124-127 — the positional and the named form of
                // one parameter are mutually exclusive. Enforced here and not
                // by the lexer, which is permissive
                // (lib/syntax-string.test.ts:106-112).
                if parameter.key == positionalKey, syntax.positional != nil {
                    throw .positionalAndNamedConflict(prefix: prefix, key: parameter.key)
                }
                // lib/parser.ts:131 — an empty list is invalid.
                guard !named.isEmpty else {
                    throw .emptyMultiValuedParameter(prefix: prefix, key: parameter.key)
                }
                // lib/parser.ts:132-138
                for value in named where !parameter.validate(value) {
                    throw .invalidParameterValue(prefix: prefix, key: parameter.key, value: value)
                }
                result.set(parameter.key, named, .stated)
            } else if parameter.key == positionalKey, let positional = syntax.positional {
                // lib/parser.ts:142-151
                guard parameter.validate(positional) else {
                    throw .invalidPositionalValue(prefix: prefix, key: parameter.key, value: positional)
                }
                result.set(parameter.key, [positional], .stated)
            } else if parameter.isRequired {
                // lib/parser.ts:152-153
                throw .missingRequiredParameter(prefix: prefix, key: parameter.key)
            } else if let defaultValue = parameter.defaultValue {
                // lib/parser.ts:155 — with no default the parameter stays absent.
                result.set(parameter.key, defaultValue, .defaulted)
            }
        }
        return result
    }

    // MARK: format

    /// Serialises `values` to the canonical scope string
    /// (`lib/parser.ts:50-96`).
    public func format(_ values: ScopeParameterValues) throws(ScopeParseError) -> String {
        try syntax(for: values).canonicalString()
    }

    /// Serialises `values` like ``format(_:)`` but with every `+` and `%` of a
    /// value left percent-encoded, so that the result always parses back to
    /// the same parameters. Identical to ``format(_:)`` for values containing
    /// neither character.
    func formatParseable(_ values: ScopeParameterValues) throws(ScopeParseError) -> String {
        try syntax(for: values).parseableString()
    }

    /// The normalised positional and named parameters of `values`, in
    /// canonical order (`lib/parser.ts:50-96`).
    private func syntax(for values: ScopeParameterValues) -> ScopeStringSyntax {
        var bag = ScopeParameterBag()
        var positional: String?

        for parameter in parameters { // declaration order is canonical order
            guard values.has(parameter.key) else { continue } // lib/parser.ts:57
            let normalized = parameter.normalize(values.multiple(parameter.key))

            // lib/parser.ts:66-76 — an optional value equal to its default is
            // omitted. `arrayParamEquals` (:169-176) ignores order and
            // duplicates, so the comparison is between sets.
            if !parameter.isRequired, let defaultValue = parameter.defaultValue,
               Set(defaultValue) == Set(normalized) {
                continue
            }

            switch parameter.arity {
            case .single:
                guard let value = normalized.first else { continue }
                if parameter.key == positionalKey { positional = value } else {
                    bag.set(key: parameter.key, value: value)
                }
            case .multiple:
                if parameter.key == positionalKey, normalized.count == 1 {
                    positional = normalized[0] // lib/parser.ts:79-80
                } else {
                    var seen = Set<ScopeBytes>() // lib/parser.ts:82-84: drop duplicates,
                    for value in normalized where seen.insert(value.scopeBytes).inserted {
                        bag.append(key: parameter.key, value: value) // keep order
                    }
                }
            }
        }

        return ScopeStringSyntax(prefix: prefix, positional: positional, parameters: bag)
    }
}
