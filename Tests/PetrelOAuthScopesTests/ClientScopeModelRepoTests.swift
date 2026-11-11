import PetrelOAuthScopes
import Testing

/// `repo` permissions: the vectors of `scopes/repo-permission.test.ts` of
/// `@atproto/oauth-scopes`, and NSID edge cases.
@Suite("Client scope model: repo permission")
struct ClientScopeModelRepoTests {
    // MARK: Parsing

    @Test("parses a positional scope")
    func positional() throws {
        let scope = try RepoPermission.parse("repo:com.example.foo")
        #expect(scope.collection == [.nsid("com.example.foo")])
        #expect(scope.action == [.create, .update, .delete])
        #expect(!scope.collection.contains(.any))
    }

    @Test("parses multiple actions")
    func multipleActions() throws {
        let scope = try RepoPermission.parse("repo:com.example.foo?action=create&action=update")
        #expect(scope.collection == [.nsid("com.example.foo")])
        #expect(scope.action == [.create, .update])
    }

    @Test("allows a wildcard collection with a specific action")
    func wildcardWithAction() throws {
        let scope = try RepoPermission.parse("repo:*?action=create")
        #expect(scope.collection == [.any])
        #expect(scope.action == [.create])
        #expect(scope.matches(.init(collection: "any.collection", action: .create)))
        #expect(!scope.matches(.init(collection: "any.collection", action: .update)))
    }

    @Test("allows a wildcard collection without actions")
    func wildcardWithoutActions() throws {
        let scope = try RepoPermission.parse("repo:*")
        #expect(scope.collection == [.any])
        #expect(scope.action == [.create, .update, .delete])
        #expect(scope.matches(.init(collection: "any.collection", action: .create)))
        #expect(scope.matches(.init(collection: "any.collection", action: .update)))
        #expect(scope.matches(.init(collection: "any.collection", action: .delete)))
    }

    static let invalid: [(String, ScopeParseError)] = [
        // Invalid collection names.
        ("repo:foo bar", .notAScopeToken("repo:foo bar")),
        ("repo:foo%20bar", .invalidPositionalValue(prefix: "repo", key: "collection", value: "foo bar")),
        ("repo:.foo", .invalidPositionalValue(prefix: "repo", key: "collection", value: ".foo")),
        ("repo:bar.", .invalidPositionalValue(prefix: "repo", key: "collection", value: "bar.")),
        ("repo:invalid", .invalidPositionalValue(prefix: "repo", key: "collection", value: "invalid")),
        ("repo:not-a-valid-nsid", .invalidPositionalValue(prefix: "repo", key: "collection", value: "not-a-valid-nsid")),
        ("repo:com.example", .invalidPositionalValue(prefix: "repo", key: "collection", value: "com.example")),
        ("repo:com..example", .invalidPositionalValue(prefix: "repo", key: "collection", value: "com..example")),
        ("repo:9com.example.foo", .invalidPositionalValue(prefix: "repo", key: "collection", value: "9com.example.foo")),
        ("repo:com.example.3foo", .invalidPositionalValue(prefix: "repo", key: "collection", value: "com.example.3foo")),
        ("repo:com.example.foo-bar", .invalidPositionalValue(prefix: "repo", key: "collection", value: "com.example.foo-bar")),
        ("repo:com.-example.foo", .invalidPositionalValue(prefix: "repo", key: "collection", value: "com.-example.foo")),
        ("repo:com.example-.foo", .invalidPositionalValue(prefix: "repo", key: "collection", value: "com.example-.foo")),
        ("repo:com.example.foo_bar", .invalidPositionalValue(prefix: "repo", key: "collection", value: "com.example.foo_bar")),
        ("repo:", .invalidPositionalValue(prefix: "repo", key: "collection", value: "")),
        ("repo:?action=create", .invalidPositionalValue(prefix: "repo", key: "collection", value: "")),
        ("repo?collection=", .invalidParameterValue(prefix: "repo", key: "collection", value: "")),
        ("repo?collection=com.example.foo&collection=nope", .invalidParameterValue(prefix: "repo", key: "collection", value: "nope")),
        // Wildcards.
        ("repo:com.example.*", .invalidPositionalValue(prefix: "repo", key: "collection", value: "com.example.*")),
        ("repo:**", .invalidPositionalValue(prefix: "repo", key: "collection", value: "**")),
        ("repo:*.example.foo", .invalidPositionalValue(prefix: "repo", key: "collection", value: "*.example.foo")),
        ("repo?collection=*&collection=com.*", .invalidParameterValue(prefix: "repo", key: "collection", value: "com.*")),
        // Invalid action names.
        ("repo:com.example.foo?action=invalid", .invalidParameterValue(prefix: "repo", key: "action", value: "invalid")),
        ("repo:*?action=*", .invalidParameterValue(prefix: "repo", key: "action", value: "*")),
        ("repo:com.example.foo?action=", .invalidParameterValue(prefix: "repo", key: "action", value: "")),
        ("repo:com.example.foo?action", .invalidParameterValue(prefix: "repo", key: "action", value: "")),
        ("repo:com.example.foo?action=Create", .invalidParameterValue(prefix: "repo", key: "action", value: "Create")),
        ("repo:com.example.foo?action=create&action=manage", .invalidParameterValue(prefix: "repo", key: "action", value: "manage")),
        // The collection is checked before the action.
        ("repo?collection=invalid&action=invalid", .invalidParameterValue(prefix: "repo", key: "collection", value: "invalid")),
        // Structure.
        ("invalid", .prefixMismatch(expected: "repo", actual: "invalid")),
        ("scope", .prefixMismatch(expected: "repo", actual: "scope")),
        ("repos:com.example.foo", .prefixMismatch(expected: "repo", actual: "repos:com.example.foo")),
        ("rep:com.example.foo", .prefixMismatch(expected: "repo", actual: "rep:com.example.foo")),
        ("Repo:com.example.foo", .prefixMismatch(expected: "repo", actual: "Repo:com.example.foo")),
        ("repo", .missingRequiredParameter(prefix: "repo", key: "collection")),
        ("repo?", .missingRequiredParameter(prefix: "repo", key: "collection")),
        ("repo?action=create", .missingRequiredParameter(prefix: "repo", key: "collection")),
        ("repo:com.example.foo?collection=com.example.bar", .positionalAndNamedConflict(prefix: "repo", key: "collection")),
        ("repo:com.example.foo?foo=bar", .unknownParameter(prefix: "repo", key: "foo")),
        ("repo:com.example.foo?Action=create", .unknownParameter(prefix: "repo", key: "Action")),
        ("repo:com.example.foo?aud=*", .unknownParameter(prefix: "repo", key: "aud")),
        ("", .prefixMismatch(expected: "repo", actual: "")),
    ]

    @Test("rejects invalid scopes", arguments: invalid)
    func rejects(scope: String, error: ScopeParseError) {
        #expect(throws: error) { try RepoPermission.parse(scope) }
    }

    @Test(
        "accepts NSID edge cases",
        arguments: [
            "com.example.foo",
            "COM.Example.fooBar",
            "com.3example.foo",
            "com.ex-ample.foo",
            "a.b.c",
            "com.example.sub.domain.deep.recordName",
            "com.example.foo2",
        ]
    )
    func validNSID(_ nsid: String) throws {
        let scope = try ClientScopeModelTestSupport.repo([nsid])
        #expect(scope.collection == [.nsid(nsid)])
        #expect(try scope.canonicalScopeString() == "repo:" + nsid)
        #expect(try RepoPermission.parse("repo:" + nsid).collection == [.nsid(nsid)])
        #expect(AtprotoSyntax.isValidNSID(nsid))
    }

    @Test("enforces NSID length limits")
    func nsidLength() throws {
        let invalid = { (value: String) in
            ScopeParseError.invalidParameterValue(prefix: "repo", key: "collection", value: value)
        }
        let label63 = String(repeating: "a", count: 63)
        let label64 = String(repeating: "a", count: 64)
        #expect(try ClientScopeModelTestSupport.repo(["com.\(label63).foo"]).collection == [.nsid("com.\(label63).foo")])
        #expect(throws: invalid("com.\(label64).foo")) {
            try ATProtoScope.repo(collections: ["com.\(label64).foo"])
        }
        #expect(throws: invalid("com.example.\(label64)")) {
            try ATProtoScope.repo(collections: ["com.example.\(label64)"])
        }
        // 317 characters at most: 5 labels of 63 characters and 4 dots is 319.
        let tooLong = Array(repeating: label63, count: 5).joined(separator: ".")
        #expect(tooLong.count == 319)
        #expect(throws: invalid(tooLong)) {
            try ATProtoScope.repo(collections: [tooLong])
        }
        let longest = Array(repeating: label63, count: 4).joined(separator: ".") + "." + String(repeating: "a", count: 61)
        #expect(longest.count == 317)
        #expect(try ClientScopeModelTestSupport.repo([longest]).collection == [.nsid(longest)])
    }

    // MARK: Building (scopeNeededFor)

    @Test("builds the scope needed for a collection and action")
    func scopeNeededFor() throws {
        #expect(
            try ATProtoScope.repo(collections: ["com.example.foo"], actions: [.create]).scopeString
                == "repo:com.example.foo?action=create"
        )
        #expect(try ATProtoScope.repo(collections: ["*"], actions: [.create]).scopeString == "repo:*?action=create")
        #expect(try ATProtoScope.repo(collections: ["com.example.foo"]).scopeString == "repo:com.example.foo")
        #expect(
            try RepoPermission.scopeNeeded(for: .init(collection: "com.example.foo", action: .create))
                == "repo:com.example.foo?action=create"
        )
    }

    @Test("refuses to build a scope from invalid values")
    func buildValidates() {
        #expect(throws: ScopeParseError.invalidParameterValue(prefix: "repo", key: "collection", value: "invalid")) {
            try ATProtoScope.repo(collections: ["invalid"], actions: [.create])
        }
        #expect(throws: ScopeParseError.invalidParameterValue(prefix: "repo", key: "collection", value: "com.example.*")) {
            try ATProtoScope.repo(collections: ["com.example.*"])
        }
        #expect(throws: ScopeParseError.missingRequiredParameter(prefix: "repo", key: "collection")) {
            try ATProtoScope.repo(collections: [])
        }
    }

    // DIFFERENCE 6: an empty `actions` list is the same as leaving `action`
    // out of the scope string, which means every action.
    @Test("building with no actions allows every action")
    func buildWithoutActions() throws {
        let scope = try ClientScopeModelTestSupport.repo(["com.example.foo"], [])
        #expect(scope.action == [.create, .update, .delete])
        #expect(try scope.canonicalScopeString() == "repo:com.example.foo")
    }

    // DIFFERENCE 7: the memberwise initializers of the permission types do
    // not validate; only the builders on `ATProtoScope` and `parse` do.
    @Test("memberwise initializers take values as given")
    func memberwiseDoesNotValidate() throws {
        let scope = RepoPermission(collection: [.nsid("invalid")], action: [.create])
        #expect(try scope.canonicalScopeString() == "repo:invalid?action=create")
        #expect(throws: ScopeParseError.invalidPositionalValue(prefix: "repo", key: "collection", value: "invalid")) {
            try RepoPermission.parse("repo:invalid?action=create")
        }
    }

    /// See DIFFERENCE 4: values are kept as given, the canonical form sorts
    /// and de-duplicates.
    @Test("canonicalises when formatting")
    func canonicalForm() throws {
        let scope = try ClientScopeModelTestSupport.repo(
            ["com.example.foo", "com.example.bar", "com.example.foo"],
            [.delete, .create, .delete]
        )
        #expect(scope.collection == [.nsid("com.example.foo"), .nsid("com.example.bar"), .nsid("com.example.foo")])
        #expect(scope.action == [.delete, .create, .delete])
        #expect(
            try scope.canonicalScopeString()
                == "repo?collection=com.example.bar&collection=com.example.foo&action=create&action=delete"
        )

        let wildcard = try ClientScopeModelTestSupport.repo(["com.example.foo", "*"])
        #expect(wildcard.collection == [.nsid("com.example.foo"), .any])
        #expect(try wildcard.canonicalScopeString() == "repo:*")
    }

    // MARK: Matching

    @Test("matches the create action")
    func matchesCreate() throws {
        let scope = try RepoPermission.parse("repo:com.example.foo?action=create")
        #expect(scope.matches(.init(collection: "com.example.foo", action: .create)))
    }

    @Test("does not match an unspecified action")
    func doesNotMatchOtherAction() throws {
        let scope = try RepoPermission.parse("repo:com.example.foo?action=create")
        #expect(!scope.matches(.init(collection: "com.example.foo", action: .update)))
    }

    @Test("matches a wildcard collection")
    func matchesWildcard() throws {
        let scope = try RepoPermission.parse("repo:*?action=create")
        #expect(scope.matches(.init(collection: "com.example.bar", action: .create)))
    }

    @Test("does not match a different action with a wildcard collection")
    func wildcardDoesNotMatchOtherAction() throws {
        let scope = try RepoPermission.parse("repo:*?action=create")
        #expect(!scope.matches(.init(collection: "com.example.bar", action: .delete)))
    }

    @Test("matches multiple actions")
    func matchesMultipleActions() throws {
        let scope = try RepoPermission.parse("repo:com.example.foo?action=create&action=update")
        #expect(scope.matches(.init(collection: "com.example.foo", action: .create)))
        #expect(scope.matches(.init(collection: "com.example.foo", action: .update)))
        #expect(!scope.matches(.init(collection: "com.example.foo", action: .delete)))
    }

    @Test("defaults to the create, update and delete actions")
    func matchesDefaultActions() throws {
        let scope = try RepoPermission.parse("repo:com.example.foo")
        #expect(scope.matches(.init(collection: "com.example.foo", action: .create)))
        #expect(scope.matches(.init(collection: "com.example.foo", action: .update)))
        #expect(scope.matches(.init(collection: "com.example.foo", action: .delete)))
    }

    @Test("matches collections exactly")
    func matchesExactly() throws {
        let scope = try RepoPermission.parse("repo?collection=com.example.foo&collection=com.example.Key")
        #expect(scope.matches(.init(collection: "com.example.foo", action: .create)))
        #expect(scope.matches(.init(collection: "com.example.Key", action: .create)))
        #expect(!scope.matches(.init(collection: "com.example.bar", action: .create)))
        #expect(!scope.matches(.init(collection: "com.example.foo.bar", action: .create)))
        #expect(!scope.matches(.init(collection: "com.example", action: .create)))
        #expect(!scope.matches(.init(collection: "com.example.Foo", action: .create)))
        // A wildcard request is only satisfied by a wildcard permission.
        #expect(!scope.matches(.init(collection: "*", action: .create)))
    }

    // DIFFERENCE 8 (resolved in the shared target): values are compared as
    // bytes, as the reference implementation compares code units. Swift's own
    // string equality is Unicode canonical equivalence, under which U+212A
    // KELVIN SIGN equals "K"; a collection spelled with it is a different
    // collection and is not matched by a permission for the ASCII spelling.
    @Test("compares collections byte-wise, not under Unicode canonical equivalence")
    func doesNotMatchCanonicallyEquivalent() throws {
        let scope = try RepoPermission.parse("repo:com.example.Key")
        #expect("com.example.\u{212A}ey" == "com.example.Key") // equal as Swift strings
        #expect(!AtprotoSyntax.isValidNSID("com.example.\u{212A}ey"))
        #expect(scope.matches(.init(collection: "com.example.Key", action: .create)))
        #expect(!scope.matches(.init(collection: "com.example.\u{212A}ey", action: .create)))
        #expect(!ATProtoScopeSet(scope: "repo:com.example.Key").allowsRepo(.init(collection: "com.example.\u{212A}ey", action: .create)))
    }

    // MARK: Formatting

    @Test("formats a scope")
    func formats() throws {
        let scope = RepoPermission(collection: [.nsid("com.example.foo")], action: [.create, .update])
        #expect(try scope.canonicalScopeString() == "repo:com.example.foo?action=create&action=update")
    }

    /// (input, canonical form)
    static let consistency: [(String, String)] = [
        ("repo:com.example.foo", "repo:com.example.foo"),
        ("repo:com.example.foo?action=create", "repo:com.example.foo?action=create"),
        ("repo:com.example.foo?action=create&action=update", "repo:com.example.foo?action=create&action=update"),
        ("repo:*?action=create&action=update&action=delete", "repo:*"),
        ("repo:com.example.foo?action=create&action=update&action=delete", "repo:com.example.foo"),
        ("repo:*?action=create", "repo:*?action=create"),
        ("repo:*?action=update", "repo:*?action=update"),
        ("repo?collection=*&action=update", "repo:*?action=update"),
        ("repo?collection=*&collection=com.example.foo&action=update", "repo:*?action=update"),
        ("repo?collection=*", "repo:*"),
        ("repo?collection=*&action=create&action=update&action=delete", "repo:*"),
        ("repo?collection=*&collection=com.example.foo", "repo:*"),
        ("repo?action=create&collection=com.example.foo", "repo:com.example.foo?action=create"),
        ("repo?collection=com.example.foo&action=create&action=update&action=delete", "repo:com.example.foo"),
        ("repo?action=create&collection=com.example.foo&collection=com.example.bar", "repo?collection=com.example.bar&collection=com.example.foo&action=create"),
        // Beyond the reference vectors.
        ("repo:com.example.foo?action=delete&action=create", "repo:com.example.foo?action=create&action=delete"),
        ("repo:com.example.foo?action=create&action=create", "repo:com.example.foo?action=create"),
        ("repo?collection=com.example.foo&collection=com.example.foo", "repo:com.example.foo"),
        ("repo:com.example.foo?", "repo:com.example.foo"),
        ("repo:com%2Eexample%2Efoo", "repo:com.example.foo"),
        ("repo:%2A", "repo:*"),
        ("repo:com.example.foo?%61ction=%63reate", "repo:com.example.foo?action=create"),
    ]

    @Test("re-formats to the canonical form", arguments: consistency)
    func reformats(input: String, expected: String) throws {
        #expect(try RepoPermission.parse(input).canonicalScopeString() == expected)
    }

    @Test("the canonical form is a fixed point and grants the same access", arguments: consistency)
    func roundTrips(input: String, expected: String) throws {
        let scope = try RepoPermission.parse(input)
        let reparsed = try RepoPermission.parse(expected)
        #expect(try reparsed.canonicalScopeString() == expected)
        #expect(Set(reparsed.action) == Set(scope.action))
        #expect(reparsed.collection.contains(.any) == scope.collection.contains(.any))
        if !scope.collection.contains(.any) {
            #expect(Set(reparsed.collection) == Set(scope.collection))
        }
    }
}
