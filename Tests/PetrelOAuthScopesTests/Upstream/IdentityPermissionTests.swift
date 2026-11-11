import Testing
@testable import PetrelOAuthScopes

/// One-to-one port of `packages/oauth/oauth-scopes/src/scopes/identity-permission.test.ts`
/// (bluesky-social/atproto). Suites mirror its `describe` blocks and each test
/// carries the name of its `it`.
@Suite("scopes/identity-permission.test.ts")
struct UpstreamIdentityPermissionTests {
    static func fromString(_ scope: String) -> IdentityPermission? {
        try? IdentityPermission.parse(scope)
    }

    @Suite("static")
    struct Static {
        @Suite("fromString")
        struct FromString {
            @Test("should parse positional scope")
            func parsesPositionalScope() throws {
                let scope = try #require(fromString("identity:handle"))
                #expect(scope.attr == .handle)
            }

            @Test("should parse valid identity scope with wildcard attribute")
            func parsesWildcardAttribute() throws {
                let scope = try #require(fromString("identity:*"))
                #expect(scope.attr == .any)
                #expect(scope.attr.rawValue == "*")
            }

            @Test("should return null for invalid identity scope")
            func rejectsInvalidIdentityScope() {
                #expect(fromString("invalid") == nil)
                #expect(fromString("identity:invalid") == nil)
            }

            @Test("should return null for invalid rpc scope", arguments: [
                "identity:*?action=*",
                "identity:*?action=manage",
                "identity:*?action=submit",
                "invalid",
                "identity:invalid",
                "identity:handle?action=invalid",
                "identity?attribute=invalid&action=invalid",
            ])
            func rejectsInvalidScope(invalid: String) {
                #expect(fromString(invalid) == nil)
            }
        }

        @Suite("scopeNeededFor")
        struct ScopeNeededFor {
            @Test("should return correct scope string for specific attribute and action")
            func specificAttribute() throws {
                #expect(try IdentityPermission.scopeNeeded(for: .init(attr: .handle)) == "identity:handle")
            }

            @Test("should return scope that accepts all attributes with specific action")
            func allAttributes() throws {
                #expect(try IdentityPermission.scopeNeeded(for: .init(attr: .any)) == "identity:*")
            }
        }
    }

    @Suite("instance")
    struct Instance {
        @Suite("matches")
        struct Matches {
            @Test("should match default attribute and action")
            func matchesDefaultAttribute() throws {
                let scope = try #require(fromString("identity:handle"))
                #expect(scope.matches(.init(attr: .handle)))
                #expect(!scope.matches(.init(attr: .any)))
            }

            @Test("should match wildcard attribute with specific action")
            func matchesWildcardAttribute() throws {
                let scope = try #require(fromString("identity:*"))
                #expect(scope.matches(.init(attr: .any)))
                #expect(scope.matches(.init(attr: .handle)))
            }
        }

        @Suite("toString")
        struct ToString {
            @Test("should format scope with default action")
            func formatsHandle() throws {
                #expect(try IdentityPermission(.handle).canonicalScopeString() == "identity:handle")
            }

            @Test("should format wildcard attribute with default action")
            func formatsWildcard() throws {
                #expect(try IdentityPermission(.any).canonicalScopeString() == "identity:*")
            }
        }
    }
}
