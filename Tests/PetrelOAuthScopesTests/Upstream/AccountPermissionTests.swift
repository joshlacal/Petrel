import Testing
@testable import PetrelOAuthScopes

/// One-to-one port of `packages/oauth/oauth-scopes/src/scopes/account-permission.test.ts`
/// (bluesky-social/atproto). Suites mirror its `describe` blocks and each test
/// carries the name of its `it`.
///
/// `fromString` returning `null` is `parse` throwing; `toString` is
/// `canonicalScopeString`; `scopeNeededFor` is `scopeNeeded(for:)`.
@Suite("scopes/account-permission.test.ts")
struct UpstreamAccountPermissionTests {
    static func fromString(_ scope: String) -> AccountPermission? {
        try? AccountPermission.parse(scope)
    }

    @Suite("static")
    struct Static {
        @Suite("fromString")
        struct FromString {
            @Test("should parse valid scope strings")
            func parsesValidScopeStrings() throws {
                let scope1 = try #require(fromString("account:email?action=read"))
                #expect(scope1.attr == .email)
                #expect(scope1.action == [.read])

                let scope2 = try #require(fromString("account:repo?action=manage"))
                #expect(scope2.attr == .repo)
                #expect(scope2.action == [.manage])
            }

            @Test("should parse scope without action (defaults to read)")
            func defaultsToRead() throws {
                let scope = try #require(fromString("account:status"))
                #expect(scope.attr == .status)
                #expect(scope.action == [.read])
            }

            @Test("should reject invalid attribute names")
            func rejectsInvalidAttributeNames() {
                #expect(fromString("account:invalid") == nil)
            }

            @Test("should reject invalid action names")
            func rejectsInvalidActionNames() {
                #expect(fromString("account:email?action=invalid") == nil)
            }

            @Test("should reject malformed scope strings")
            func rejectsMalformedScopeStrings() {
                #expect(fromString("invalid:email") == nil)
                #expect(fromString("account") == nil)
                #expect(fromString("") == nil)
                #expect(fromString("account:") == nil)
            }
        }

        @Suite("scopeNeededFor")
        struct ScopeNeededFor {
            @Test("should return correct scope string for read actions")
            func readActions() throws {
                #expect(try AccountPermission.scopeNeeded(for: .init(attr: .email, action: .read)) == "account:email")
                #expect(try AccountPermission.scopeNeeded(for: .init(attr: .repo, action: .read)) == "account:repo")
                #expect(try AccountPermission.scopeNeeded(for: .init(attr: .status, action: .read)) == "account:status")
            }

            @Test("should return correct scope string for manage actions")
            func manageActions() throws {
                #expect(try AccountPermission.scopeNeeded(for: .init(attr: .email, action: .manage))
                    == "account:email?action=manage")
                #expect(try AccountPermission.scopeNeeded(for: .init(attr: .repo, action: .manage))
                    == "account:repo?action=manage")
                #expect(try AccountPermission.scopeNeeded(for: .init(attr: .status, action: .manage))
                    == "account:status?action=manage")
            }
        }
    }

    @Suite("instance")
    struct Instance {
        @Suite("matches")
        struct Matches {
            @Test("should match read action")
            func matchesRead() throws {
                let scope = try #require(fromString("account:email?action=read"))
                #expect(scope.matches(.init(attr: .email, action: .read)))
            }

            @Test("should match manage action")
            func matchesManage() throws {
                let scope = try #require(fromString("account:repo?action=manage"))
                #expect(scope.matches(.init(attr: .repo, action: .manage)))
            }

            @Test("should not match unspecified action")
            func doesNotMatchUnspecifiedAction() throws {
                let scope = try #require(fromString("account:email?action=read"))
                #expect(!scope.matches(.init(attr: .email, action: .manage)))
            }

            @Test("should not match different attribute")
            func doesNotMatchDifferentAttribute() throws {
                let scope = try #require(fromString("account:email?action=read"))
                #expect(!scope.matches(.init(attr: .repo, action: .read)))
            }

            @Test("should default to \"read\" action")
            func defaultsToReadAction() throws {
                let scope = try #require(fromString("account:email"))
                #expect(scope.matches(.init(attr: .email, action: .read)))
                #expect(!scope.matches(.init(attr: .email, action: .manage)))
            }

            @Test("should work with all valid attributes")
            func worksWithAllValidAttributes() throws {
                let emailScope = try #require(fromString("account:email?action=read"))
                let repoScope = try #require(fromString("account:repo?action=manage"))
                let statusScope = try #require(fromString("account:status?action=read"))

                #expect(emailScope.matches(.init(attr: .email, action: .read)))
                #expect(repoScope.matches(.init(attr: .repo, action: .manage)))
                #expect(statusScope.matches(.init(attr: .status, action: .read)))
            }

            @Test("should allow read when \"manage\" action is specified")
            func manageAllowsRead() throws {
                let scope = try #require(fromString("account:email?action=manage"))
                #expect(scope.matches(.init(attr: .email, action: .read)))
            }
        }

        @Suite("toString")
        struct ToString {
            @Test("should format scope with explicit action")
            func explicitAction() throws {
                let scope = AccountPermission(attr: .email, action: [.manage])
                #expect(try scope.canonicalScopeString() == "account:email?action=manage")
            }

            @Test("should format scope with default action")
            func defaultAction() throws {
                let scope = AccountPermission(attr: .repo, action: [.read])
                #expect(try scope.canonicalScopeString() == "account:repo")
            }

            @Test("should format all attributes correctly")
            func allAttributes() throws {
                #expect(try AccountPermission(attr: .email, action: [.read]).canonicalScopeString() == "account:email")
                #expect(try AccountPermission(attr: .repo, action: [.read]).canonicalScopeString() == "account:repo")
                #expect(try AccountPermission(attr: .status, action: [.read]).canonicalScopeString() == "account:status")
                #expect(try AccountPermission(attr: .email, action: [.manage]).canonicalScopeString()
                    == "account:email?action=manage")
            }
        }
    }

    @Test("should maintain consistency between toString and fromString", arguments: [
        "account:email",
        "account:email?action=manage",
        "account:repo",
        "account:repo?action=manage",
        "account:status",
        "account:status?action=manage",
    ])
    func consistency(scope: String) throws {
        #expect(try AccountPermission.parse(scope).canonicalScopeString() == scope)
    }
}
