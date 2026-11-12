/// A single RFC 6749 section 3.3 `scope-token`:
///
///     scope-token = 1*( %x21 / %x23-5B / %x5D-7E )
///
/// SPACE terminates a token, and `"` and `\` are excluded so that a scope
/// survives being carried inside a quoted string. Every canonical form this
/// module emits passes through ``isScopeToken(_:)``, so a value interpolated
/// into a scope can never smuggle in a second, space-separated scope.
public struct ScopeToken: Sendable, Hashable, CustomStringConvertible {
    /// The token, verbatim.
    public let rawValue: String

    /// Wraps `rawValue`, or returns `nil` when it is not a `scope-token`.
    public init?(_ rawValue: String) {
        guard Self.isScopeToken(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    /// Whether `value` is a non-empty run of `scope-token` characters.
    public static func isScopeToken(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { byte in
            byte == 0x21 || (0x23...0x5b).contains(byte) || (0x5d...0x7e).contains(byte)
        }
    }

    /// The token, verbatim.
    public var description: String { rawValue }
}
