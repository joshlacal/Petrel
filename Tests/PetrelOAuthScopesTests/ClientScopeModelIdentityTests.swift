import PetrelOAuthScopes
import Testing

/// `identity` permissions: the vectors of `scopes/identity-permission.test.ts`
/// of `@atproto/oauth-scopes`.
@Suite("Client scope model: identity permission")
struct ClientScopeModelIdentityTests {
    // MARK: Parsing

    @Test("parses a positional scope")
    func positional() throws {
        #expect(try IdentityPermission.parse("identity:handle").attr == .handle)
    }

    @Test("parses the wildcard attribute")
    func wildcard() throws {
        #expect(try IdentityPermission.parse("identity:*").attr == .any)
        #expect(IdentityAttribute.any.rawValue == "*")
        #expect(IdentityAttribute.allCases.map(\.rawValue) == ["handle", "*"])
    }

    static let invalid: [(String, ScopeParseError)] = [
        ("invalid", .prefixMismatch(expected: "identity", actual: "invalid")),
        ("identity:invalid", .invalidPositionalValue(prefix: "identity", key: "attr", value: "invalid")),
        ("identity:Handle", .invalidPositionalValue(prefix: "identity", key: "attr", value: "Handle")),
        ("identity:", .invalidPositionalValue(prefix: "identity", key: "attr", value: "")),
        ("identity:**", .invalidPositionalValue(prefix: "identity", key: "attr", value: "**")),
        ("identity:did", .invalidPositionalValue(prefix: "identity", key: "attr", value: "did")),
        // identity has no action parameter.
        ("identity:*?action=*", .unknownParameter(prefix: "identity", key: "action")),
        ("identity:*?action=manage", .unknownParameter(prefix: "identity", key: "action")),
        ("identity:*?action=submit", .unknownParameter(prefix: "identity", key: "action")),
        ("identity:handle?action=invalid", .unknownParameter(prefix: "identity", key: "action")),
        ("identity?attribute=invalid&action=invalid", .unknownParameter(prefix: "identity", key: "attribute")),
        ("identity", .missingRequiredParameter(prefix: "identity", key: "attr")),
        ("identity?", .missingRequiredParameter(prefix: "identity", key: "attr")),
        ("identity:handle?attr=*", .positionalAndNamedConflict(prefix: "identity", key: "attr")),
        ("identity?attr=handle&attr=*", .repeatedSingleValuedParameter(prefix: "identity", key: "attr")),
    ]

    @Test("rejects invalid scopes", arguments: invalid)
    func rejects(scope: String, error: ScopeParseError) {
        #expect(throws: error) { try IdentityPermission.parse(scope) }
    }

    // MARK: Building (scopeNeededFor)

    @Test("builds the scope needed for an attribute")
    func scopeNeededFor() throws {
        #expect(try ATProtoScope.identity(attribute: .handle).scopeString == "identity:handle")
        #expect(try ATProtoScope.identity(attribute: .any).scopeString == "identity:*")
        #expect(try IdentityPermission.scopeNeeded(for: .init(attr: .handle)) == "identity:handle")
        #expect(try IdentityPermission.scopeNeeded(for: .init(attr: .any)) == "identity:*")
    }

    // MARK: Matching

    @Test("a handle permission matches the handle only")
    func matchesHandle() throws {
        let scope = try IdentityPermission.parse("identity:handle")
        #expect(scope.matches(.init(attr: .handle)))
        #expect(!scope.matches(.init(attr: .any)))
    }

    @Test("the wildcard permission matches everything")
    func matchesWildcard() throws {
        let scope = try IdentityPermission.parse("identity:*")
        #expect(scope.matches(.init(attr: .any)))
        #expect(scope.matches(.init(attr: .handle)))
    }

    // MARK: Formatting

    @Test("formats")
    func formats() throws {
        #expect(try IdentityPermission(.handle).canonicalScopeString() == "identity:handle")
        #expect(try IdentityPermission(.any).canonicalScopeString() == "identity:*")
    }

    /// (input, canonical form)
    static let consistency: [(String, String)] = [
        ("identity:handle", "identity:handle"),
        ("identity:*", "identity:*"),
        ("identity:*?", "identity:*"),
        ("identity?attr=handle", "identity:handle"),
        ("identity?attr=*", "identity:*"),
        ("identity:%2A", "identity:*"),
    ]

    @Test("re-formats to the canonical form", arguments: consistency)
    func reformats(input: String, expected: String) throws {
        #expect(try IdentityPermission.parse(input).canonicalScopeString() == expected)
    }

    @Test("the canonical form is a fixed point and grants the same access", arguments: consistency)
    func roundTrips(input: String, expected: String) throws {
        let scope = try IdentityPermission.parse(input)
        let reparsed = try IdentityPermission.parse(expected)
        #expect(try reparsed.canonicalScopeString() == expected)
        #expect(reparsed.attr == scope.attr)
    }
}
