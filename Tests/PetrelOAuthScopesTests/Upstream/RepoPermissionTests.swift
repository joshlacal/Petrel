import Testing
@testable import PetrelOAuthScopes

/// One-to-one port of `packages/oauth/oauth-scopes/src/scopes/repo-permission.test.ts`
/// (bluesky-social/atproto). Suites mirror its `describe` blocks and each test
/// carries the name of its `it`.
///
/// `collection` is an array of strings there and an array of `CollectionParam`
/// here; the comparisons are on the string form.
@Suite("scopes/repo-permission.test.ts")
struct UpstreamRepoPermissionTests {
    static func fromString(_ scope: String) -> RepoPermission? {
        try? RepoPermission.parse(scope)
    }

    @Suite("static")
    struct Static {
        @Suite("fromString")
        struct FromString {
            @Test("should parse positional scope")
            func parsesPositionalScope() throws {
                let scope = try #require(fromString("repo:com.example.foo"))
                #expect(scope.collection.map(\.stringValue) == ["com.example.foo"])
                #expect(scope.action == [.create, .update, .delete])
            }

            @Test("should parse valid repo scope with multiple actions")
            func parsesMultipleActions() throws {
                let scope = try #require(fromString("repo:com.example.foo?action=create&action=update"))
                #expect(scope.collection.map(\.stringValue) == ["com.example.foo"])
                #expect(scope.action == [.create, .update])
            }

            @Test("should parse valid repo scope without actions (defaults to create, update, delete)")
            func defaultsToAllActions() throws {
                let scope = try #require(fromString("repo:com.example.foo"))
                #expect(scope.collection.map(\.stringValue) == ["com.example.foo"])
                #expect(scope.action == [.create, .update, .delete])
            }

            @Test("should allow wildcard collection with specific action")
            func wildcardCollectionWithAction() throws {
                let scope = try #require(fromString("repo:*?action=create"))
                #expect(scope.collection.map(\.stringValue) == ["*"])
                #expect(scope.action == [.create])
                #expect(scope.matches(.init(collection: "any.collection", action: .create)))
                #expect(!scope.matches(.init(collection: "any.collection", action: .update)))
            }

            @Test("should allow wildcard collection without actions")
            func wildcardCollectionWithoutActions() throws {
                let scope = try #require(fromString("repo:*"))
                #expect(scope.collection.map(\.stringValue) == ["*"])
                #expect(scope.action == [.create, .update, .delete])
                #expect(scope.matches(.init(collection: "any.collection", action: .create)))
                #expect(scope.matches(.init(collection: "any.collection", action: .update)))
                #expect(scope.matches(.init(collection: "any.collection", action: .delete)))
            }

            @Test("should ignore scopes with invalid collection names")
            func rejectsInvalidCollectionNames() {
                #expect(fromString("repo:foo bar") == nil)
                #expect(fromString("repo:.foo") == nil)
                #expect(fromString("repo:bar.") == nil)
            }

            @Test("should reject invalid action names")
            func rejectsInvalidActionNames() {
                #expect(fromString("repo:com.example.foo?action=invalid") == nil)
            }

            @Test("should return null for invalid repo scope")
            func rejectsInvalidRepoScope() {
                #expect(fromString("invalid") == nil)
                #expect(fromString("scope") == nil)
            }

            @Test("should return null for invalid rpc scope", arguments: [
                "repo:*?action=*",
                "invalid",
                "repo:invalid",
                "repo:com.example.foo?action=invalid",
                "repo?collection=invalid&action=invalid",
            ])
            func rejectsInvalidScope(invalid: String) {
                #expect(fromString(invalid) == nil)
            }
        }

        @Suite("scopeNeededFor")
        struct ScopeNeededFor {
            @Test("should return correct scope string for specific collection and action")
            func specificCollectionAndAction() throws {
                #expect(try RepoPermission.scopeNeeded(for: .init(collection: "com.example.foo", action: .create))
                    == "repo:com.example.foo?action=create")
            }

            @Test("should return scope that accepts all collections with specific action")
            func allCollections() throws {
                #expect(try RepoPermission.scopeNeeded(for: .init(collection: "*", action: .create))
                    == "repo:*?action=create")
            }

            @Test("ignores invalid options")
            func ignoresInvalidOptions() throws {
                // scopeNeededFor assumes valid input, so it does not validate
                // the collection.
                #expect(try RepoPermission.scopeNeeded(for: .init(collection: "invalid", action: .create))
                    == "repo:invalid?action=create")
            }
        }
    }

    @Suite("instance")
    struct Instance {
        @Suite("matches")
        struct Matches {
            @Test("should match create action")
            func matchesCreate() throws {
                let scope = try #require(fromString("repo:com.example.foo?action=create"))
                #expect(scope.matches(.init(collection: "com.example.foo", action: .create)))
            }

            @Test("should not match unspecified action")
            func doesNotMatchUnspecifiedAction() throws {
                let scope = try #require(fromString("repo:com.example.foo?action=create"))
                #expect(!scope.matches(.init(collection: "com.example.foo", action: .update)))
            }

            @Test("should match wildcard collection")
            func matchesWildcardCollection() throws {
                let scope = try #require(fromString("repo:*?action=create"))
                #expect(scope.matches(.init(collection: "com.example.bar", action: .create)))
            }

            @Test("should not match different action with wildcard collection")
            func wildcardCollectionDifferentAction() throws {
                let scope = try #require(fromString("repo:*?action=create"))
                #expect(!scope.matches(.init(collection: "com.example.bar", action: .delete)))
            }

            @Test("should match multiple actions")
            func matchesMultipleActions() throws {
                let scope = try #require(fromString("repo:com.example.foo?action=create&action=update"))
                #expect(scope.matches(.init(collection: "com.example.foo", action: .create)))
                #expect(scope.matches(.init(collection: "com.example.foo", action: .update)))
                #expect(!scope.matches(.init(collection: "com.example.foo", action: .delete)))
            }

            @Test("should default to \"create\", \"update\", and \"delete\" actions")
            func defaultsToAllActions() throws {
                let scope = try #require(fromString("repo:com.example.foo"))
                #expect(scope.matches(.init(collection: "com.example.foo", action: .create)))
                #expect(scope.matches(.init(collection: "com.example.foo", action: .update)))
                #expect(scope.matches(.init(collection: "com.example.foo", action: .delete)))
            }
        }

        @Suite("toString")
        struct ToString {
            @Test("should format repo scope correctly")
            func formats() throws {
                let scope = RepoPermission(collection: [.nsid("com.example.foo")], action: [.create, .update])
                #expect(try scope.canonicalScopeString() == "repo:com.example.foo?action=create&action=update")
            }
        }
    }

    @Suite("consistency")
    struct Consistency {
        @Test("should properly re-format", arguments: [
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
            (
                "repo?action=create&collection=com.example.foo&collection=com.example.bar",
                "repo?collection=com.example.bar&collection=com.example.foo&action=create"
            ),
        ])
        func reformats(input: String, expected: String) throws {
            #expect(try RepoPermission.parse(input).canonicalScopeString() == expected)
        }
    }
}
