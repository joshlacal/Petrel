import Testing
@testable import PetrelOAuthScopes

/// One-to-one port of `packages/oauth/oauth-scopes/src/lib/syntax.test.ts`
/// (bluesky-social/atproto). Suites mirror its `describe` blocks and each test
/// carries the name of its `it`.
///
/// `isScopeStringFor(value, prefix)` is `ScopeStringSyntax.isScopeString(_:for:)`.
@Suite("lib/syntax.test.ts")
struct UpstreamSyntaxTests {
    static func isScopeStringFor(_ value: String, _ prefix: String) -> Bool {
        ScopeStringSyntax.isScopeString(value, for: prefix)
    }

    @Suite("isScopeStringFor")
    struct IsScopeStringFor {
        @Suite("exact match")
        struct ExactMatch {
            @Test("should return true for exact match")
            func exact() {
                #expect(isScopeStringFor("prefix", "prefix"))
            }

            @Test("should return false for different prefix")
            func different() {
                #expect(!isScopeStringFor("prefix", "differentResource"))
            }
        }

        @Suite("with positional parameter")
        struct WithPositionalParameter {
            @Test("should return true for exact match with positional parameter")
            func exact() {
                #expect(isScopeStringFor("prefix:positional", "prefix"))
            }

            @Test("should return false for different prefix with positional parameter")
            func different() {
                #expect(!isScopeStringFor("differentResource:positional", "prefix"))
            }
        }

        @Suite("with named parameters")
        struct WithNamedParameters {
            @Test("should return true for exact match with named parameters")
            func exact() {
                #expect(isScopeStringFor("prefix?param=value", "prefix"))
            }

            @Test("should return false for different prefix with named parameters")
            func different() {
                #expect(!isScopeStringFor("prefix", "prefi"))
                #expect(!isScopeStringFor("prefix:pos", "prefi"))
                #expect(!isScopeStringFor("prefix?param=value", "prefi"))
                #expect(!isScopeStringFor("prefix", "fix"))
                #expect(!isScopeStringFor("prefix:pos", "fix"))
                #expect(!isScopeStringFor("prefix?param=value", "fix"))
                #expect(!isScopeStringFor("differentResource?param=value", "prefix"))
            }
        }
    }
}
