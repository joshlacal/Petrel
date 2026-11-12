import PetrelOAuthScopes
import Testing

/// `account` permissions: the vectors of `scopes/account-permission.test.ts`
/// of `@atproto/oauth-scopes`.
@Suite("Client scope model: account permission")
struct ClientScopeModelAccountTests {
    // MARK: Parsing

    @Test("parses valid scope strings")
    func parses() throws {
        let email = try AccountPermission.parse("account:email?action=read")
        #expect(email.attr == .email)
        #expect(email.action == [.read])

        let repo = try AccountPermission.parse("account:repo?action=manage")
        #expect(repo.attr == .repo)
        #expect(repo.action == [.manage])
    }

    @Test("defaults to the read action")
    func defaultsToRead() throws {
        let scope = try AccountPermission.parse("account:status")
        #expect(scope.attr == .status)
        #expect(scope.action == [.read])
        #expect(AccountPermission(attr: .email).action == [.read])
        #expect(try ATProtoScope.account(attribute: .email).scopeString == "account:email")
    }

    static let invalid: [(String, ScopeParseError)] = [
        ("account:invalid", .invalidPositionalValue(prefix: "account", key: "attr", value: "invalid")),
        ("account:Email", .invalidPositionalValue(prefix: "account", key: "attr", value: "Email")),
        // "Wildcard is not supported."
        ("account:*", .invalidPositionalValue(prefix: "account", key: "attr", value: "*")),
        ("account:", .invalidPositionalValue(prefix: "account", key: "attr", value: "")),
        ("account:email?action=invalid", .invalidParameterValue(prefix: "account", key: "action", value: "invalid")),
        ("account:email?action=", .invalidParameterValue(prefix: "account", key: "action", value: "")),
        ("account:email?action=create", .invalidParameterValue(prefix: "account", key: "action", value: "create")),
        ("account:email?action=*", .invalidParameterValue(prefix: "account", key: "action", value: "*")),
        ("invalid:email", .prefixMismatch(expected: "account", actual: "invalid:email")),
        ("account", .missingRequiredParameter(prefix: "account", key: "attr")),
        ("account?action=manage", .missingRequiredParameter(prefix: "account", key: "attr")),
        ("", .prefixMismatch(expected: "account", actual: "")),
        ("account:email?attr=repo", .positionalAndNamedConflict(prefix: "account", key: "attr")),
        ("account?attr=email&attr=repo", .repeatedSingleValuedParameter(prefix: "account", key: "attr")),
        ("account:email?foo=bar", .unknownParameter(prefix: "account", key: "foo")),
        ("account:email?attribute=repo", .unknownParameter(prefix: "account", key: "attribute")),
    ]

    @Test("rejects invalid scopes", arguments: invalid)
    func rejects(scope: String, error: ScopeParseError) {
        #expect(throws: error) { try AccountPermission.parse(scope) }
    }

    // MARK: Building (scopeNeededFor)

    /// (attribute, action, scope string)
    static let formatting: [(AccountAttribute, AccountAction, String)] = [
        (.email, .read, "account:email"),
        (.repo, .read, "account:repo"),
        (.status, .read, "account:status"),
        (.email, .manage, "account:email?action=manage"),
        (.repo, .manage, "account:repo?action=manage"),
        (.status, .manage, "account:status?action=manage"),
    ]

    @Test("formats every attribute and action", arguments: formatting)
    func formats(attribute: AccountAttribute, action: AccountAction, expected: String) throws {
        let permission = AccountPermission(attr: attribute, action: [action])
        #expect(try permission.canonicalScopeString() == expected)
        #expect(try ATProtoScope.account(attribute: attribute, action: action).scopeString == expected)
        #expect(try AccountPermission.scopeNeeded(for: .init(attr: attribute, action: action)) == expected)

        let parsed = try AccountPermission.parse(expected)
        #expect(parsed.attr == attribute)
        #expect(parsed.action == [action])
    }

    @Test("covers every attribute and action in the formatting vectors")
    func formattingVectorsAreExhaustive() {
        #expect(Self.formatting.count == AccountAttribute.allCases.count * AccountAction.allCases.count)
        #expect(AccountAttribute.allCases.map(\.rawValue) == ["email", "repo", "status"])
        #expect(AccountAction.allCases.map(\.rawValue) == ["read", "manage"])
    }

    // MARK: Matching

    /// (scope, attribute, action, matches)
    static let matching: [(String, AccountAttribute, AccountAction, Bool)] = [
        // read action
        ("account:email?action=read", .email, .read, true),
        // manage action
        ("account:repo?action=manage", .repo, .manage, true),
        // unspecified action
        ("account:email?action=read", .email, .manage, false),
        // different attribute
        ("account:email?action=read", .repo, .read, false),
        // default to "read"
        ("account:email", .email, .read, true),
        ("account:email", .email, .manage, false),
        // all valid attributes
        ("account:status?action=read", .status, .read, true),
        // "manage" includes "read"
        ("account:email?action=manage", .email, .read, true),
        ("account:email?action=manage", .email, .manage, true),
        ("account:email?action=manage", .repo, .read, false),
        ("account:email?action=manage", .status, .manage, false),
        ("account:status?action=manage", .status, .read, true),
        ("account:repo", .repo, .manage, false),
        // A repeated action (reference parity).
        ("account:email?action=read&action=manage", .email, .manage, true),
        ("account:email?action=read&action=read", .email, .manage, false),
    ]

    @Test("matches", arguments: matching)
    func matches(scope: String, attribute: AccountAttribute, action: AccountAction, expected: Bool) throws {
        #expect(try AccountPermission.parse(scope).matches(.init(attr: attribute, action: action)) == expected)
        #expect(ATProtoScopeSet(scope: scope).allowsAccount(.init(attr: attribute, action: action)) == expected)
    }

    // MARK: Consistency

    /// (input, canonical form)
    static let consistency: [(String, String)] = [
        ("account:email", "account:email"),
        ("account:email?action=manage", "account:email?action=manage"),
        ("account:repo", "account:repo"),
        ("account:repo?action=manage", "account:repo?action=manage"),
        ("account:status", "account:status"),
        ("account:status?action=manage", "account:status?action=manage"),
        // Beyond the reference vectors.
        ("account:email?action=read", "account:email"),
        ("account?attr=email", "account:email"),
        ("account?action=manage&attr=repo", "account:repo?action=manage"),
        ("account?attr=status&action=read", "account:status"),
        ("account:email?", "account:email"),
    ]

    @Test("re-formats to the canonical form", arguments: consistency)
    func reformats(input: String, expected: String) throws {
        #expect(try AccountPermission.parse(input).canonicalScopeString() == expected)
    }

    @Test("the canonical form is a fixed point and grants the same access", arguments: consistency)
    func roundTrips(input: String, expected: String) throws {
        let scope = try AccountPermission.parse(input)
        let reparsed = try AccountPermission.parse(expected)
        #expect(try reparsed.canonicalScopeString() == expected)
        #expect(reparsed.attr == scope.attr)
        #expect(reparsed.action == scope.action)
    }

    // MARK: Reference parity

    /// The specification describes `action` as a single string. The reference
    /// implementation takes a list, so a repeated `action` is accepted, kept
    /// in the order written, and only a list equal to the default is elided.
    /// (input, actions, canonical form)
    static let repeatedActions: [(String, [AccountAction], String)] = [
        ("account:email?action=manage&action=read", [.manage, .read], "account:email?action=manage&action=read"),
        ("account:email?action=read&action=manage", [.read, .manage], "account:email?action=read&action=manage"),
        ("account:email?action=read&action=read", [.read, .read], "account:email"),
        ("account:email?action=manage&action=manage", [.manage, .manage], "account:email?action=manage"),
    ]

    @Test("accepts a repeated action", arguments: repeatedActions)
    func repeatedAction(input: String, actions: [AccountAction], canonical: String) throws {
        let scope = try AccountPermission.parse(input)
        #expect(scope.attr == .email)
        #expect(scope.action == actions)
        #expect(try scope.canonicalScopeString() == canonical)
        #expect(scope.matches(.init(attr: .email, action: .read)))
        #expect(scope.matches(.init(attr: .email, action: .manage)) == actions.contains(.manage))
    }
}
