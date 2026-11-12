/// Why a scope string was rejected.
///
/// The reference implementation has no error type for this layer: every
/// failure is `return null`, and `lib/parser.ts:98-100` notes that a reason
/// could be added. This enum is that reason.
///
/// ``description`` never echoes the scope string itself, which is chosen by the
/// client; the associated values carry it for structured logging.
public enum ScopeParseError: Error, Sendable, Hashable, CustomStringConvertible {
    /// The string is not an RFC 6749 `scope-token`.
    case notAScopeToken(String)
    /// The positional segment contains a `%` that does not introduce a valid
    /// percent-encoded UTF-8 sequence.
    case malformedPercentEncoding(String)
    /// The string names no resource this module knows.
    case unknownPrefix(String)
    /// The string was handed to the parser of a different resource.
    case prefixMismatch(expected: String, actual: String)
    /// A parameter the resource does not define.
    case unknownParameter(prefix: String, key: String)
    /// A single-valued parameter given more than once.
    case repeatedSingleValuedParameter(prefix: String, key: String)
    /// The positional parameter given both positionally and by name.
    case positionalAndNamedConflict(prefix: String, key: String)
    /// A multi-valued parameter with no values.
    case emptyMultiValuedParameter(prefix: String, key: String)
    /// A named parameter whose value the resource does not allow.
    case invalidParameterValue(prefix: String, key: String, value: String)
    /// A positional value the resource does not allow.
    case invalidPositionalValue(prefix: String, key: String, value: String)
    /// A required parameter that is absent.
    case missingRequiredParameter(prefix: String, key: String)
    /// Parameters that are each valid but may not be combined.
    case forbiddenParameterCombination(prefix: String, detail: String)
    /// The string exceeds a length limit.
    case scopeTooLong(bytes: Int, limit: Int)

    /// An operator-facing reason that names the resource and parameter but not
    /// the offending value.
    public var description: String {
        switch self {
        case .notAScopeToken: "not a valid RFC 6749 scope-token"
        case .malformedPercentEncoding: "malformed percent-encoding in scope"
        case .unknownPrefix: "unknown scope prefix"
        case let .prefixMismatch(expected, actual: _): "scope does not name prefix \"\(expected)\""
        case let .unknownParameter(prefix, key): "unknown parameter \"\(key)\" for \"\(prefix)\""
        case let .repeatedSingleValuedParameter(prefix, key):
            "parameter \"\(key)\" for \"\(prefix)\" repeated, but is single-valued"
        case let .positionalAndNamedConflict(prefix, key):
            "parameter \"\(key)\" for \"\(prefix)\" given both positionally and by name"
        case let .emptyMultiValuedParameter(prefix, key):
            "parameter \"\(key)\" for \"\(prefix)\" is empty"
        case let .invalidParameterValue(prefix, key, value: _):
            "invalid value for parameter \"\(key)\" of \"\(prefix)\""
        case let .invalidPositionalValue(prefix, key, value: _):
            "invalid positional value for parameter \"\(key)\" of \"\(prefix)\""
        case let .missingRequiredParameter(prefix, key):
            "missing required parameter \"\(key)\" for \"\(prefix)\""
        case let .forbiddenParameterCombination(prefix, detail):
            "forbidden parameter combination for \"\(prefix)\": \(detail)"
        case let .scopeTooLong(bytes, limit):
            "scope is \(bytes) bytes, over the \(limit)-byte limit"
        }
    }
}
