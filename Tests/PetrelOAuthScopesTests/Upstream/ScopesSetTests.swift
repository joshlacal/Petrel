import Testing
@testable import PetrelOAuthScopes

/// One-to-one port of `packages/oauth/oauth-scopes/src/scopes-set.test.ts`
/// (bluesky-social/atproto). Each test carries the name of its `it`.
///
/// `ScopesSet` is a mutable `Set<string>` with a `matches` method.
/// `ScopePermissions` is its immutable counterpart: the set is
/// `rawScopes`, and `matches('repo', …)` is `allowsRepo`. Adding and removing
/// are therefore expressed as building a new value.
@Suite("scopes-set.test.ts")
struct UpstreamScopesSetTests {
    @Test("should initialize with an empty set")
    func initializesEmpty() {
        let set = ScopePermissions(rawScopes: [])
        #expect(set.rawScopes.count == 0)
        #expect(ScopePermissions(scope: "").rawScopes.isEmpty)
    }

    @Test("should add scopes correctly")
    func addsScopes() {
        let set = ScopePermissions(rawScopes: Set<String>().union(["repo:read"]))
        #expect(set.rawScopes.count == 1)
        #expect(set.rawScopes.contains("repo:read"))
        #expect(!set.rawScopes.contains("repo:write"))
    }

    @Test("should remove scopes correctly")
    func removesScopes() {
        let initial = ScopePermissions(rawScopes: ["repo:read"])
        let set = ScopePermissions(rawScopes: initial.rawScopes.subtracting(["repo:read"]))
        #expect(set.rawScopes.count == 0)
        #expect(!set.rawScopes.contains("repo:read"))
    }

    @Test("should match included scopes")
    func matchesIncludedScopes() {
        let set = ScopePermissions(rawScopes: ["repo:com.example.foo"])
        #expect(set.allowsRepo(.init(collection: "com.example.foo", action: .create)))
        #expect(!set.allowsRepo(.init(collection: "com.example.bar", action: .create)))
    }

    @Test("should not match missing scopes")
    func doesNotMatchMissingScopes() {
        let set = ScopePermissions(rawScopes: ["repo:com.example.foo?action=create"])
        #expect(!set.allowsRepo(.init(collection: "com.example.foo", action: .delete)))
    }

    @Test("should not match invalid scopes")
    func doesNotMatchInvalidScopes() {
        let set = ScopePermissions(rawScopes: ["repo:not-a-valid-nsid"])
        #expect(!set.allowsRepo(.init(collection: "not-a-valid-nsid", action: .create)))
        // The value is kept, and recorded as one that did not parse.
        #expect(set.rawScopes == ["repo:not-a-valid-nsid"])
        #expect(set.rejected.keys.contains("repo:not-a-valid-nsid"))
    }
}
