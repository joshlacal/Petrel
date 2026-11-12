import Testing
@testable import PetrelOAuthScopes

/// One-to-one port of `packages/oauth/oauth-scopes/src/scopes/blob-permission.test.ts`
/// (bluesky-social/atproto). Suites mirror its `describe` blocks and each test
/// carries the name of its `it`.
///
/// `accept` is an array of strings there and an array of `AcceptPattern` here;
/// the comparisons are on the string form.
@Suite("scopes/blob-permission.test.ts")
struct UpstreamBlobPermissionTests {
    static func fromString(_ scope: String) -> BlobPermission? {
        try? BlobPermission.parse(scope)
    }

    static func permission(_ accept: String...) throws -> BlobPermission {
        BlobPermission(accept: try accept.map { try #require(AcceptPattern($0)) })
    }

    @Suite("static")
    struct Static {
        @Suite("fromString")
        struct FromString {
            @Test("should parse positional scope")
            func parsesPositionalScope() throws {
                let scope = try #require(fromString("blob:image/png"))
                #expect(scope.accept.map(\.stringValue) == ["image/png"])
            }

            @Test("should parse valid blob scope with multiple accept parameters")
            func parsesMultipleAccept() throws {
                let scope = try #require(fromString("blob?accept=image/png&accept=image/jpeg"))
                #expect(scope.accept.map(\.stringValue) == ["image/png", "image/jpeg"])
            }

            @Test("should reject blob scope without accept")
            func rejectsWithoutAccept() {
                #expect(fromString("blob") == nil)
            }

            @Test("should return null for invalid rpc scope", arguments: [
                "invalid",
                "scope",
                "blob:invalid",
                "blob?accept=invalid-mime",
                "blob?accept=invalid",
                "blob:*/**",
                "blob:*/png",
            ])
            func rejectsInvalidScope(invalid: String) {
                #expect(fromString(invalid) == nil)
            }
        }

        @Suite("scopeNeededFor")
        struct ScopeNeededFor {
            @Test("should return correct scope string for specific MIME type")
            func specificMimeType() throws {
                #expect(try BlobPermission.scopeNeeded(for: .init(mime: "image/png")) == "blob:image/png")
            }

            @Test("should return scope that accepts all MIME types")
            func anotherMimeType() throws {
                #expect(try BlobPermission.scopeNeeded(for: .init(mime: "application/json")) == "blob:application/json")
            }
        }
    }

    @Suite("instance")
    struct Instance {
        @Suite("matches")
        struct Matches {
            @Test("should match exact MIME type")
            func matchesExact() throws {
                let scope = try #require(fromString("blob:image/png"))
                #expect(scope.matches(.init(mime: "image/png")))
            }

            @Test("should match wildcard MIME type")
            func matchesWildcard() throws {
                let scope = try #require(fromString("blob:*/*"))
                #expect(scope.matches(.init(mime: "image/jpeg")))
                #expect(scope.matches(.init(mime: "application/json")))
            }

            @Test("should match subtype wildcard MIME type")
            func matchesSubtypeWildcard() throws {
                let scope = try #require(fromString("blob:image/*"))
                #expect(scope.matches(.init(mime: "image/gif")))
            }

            @Test("should not match different MIME type")
            func doesNotMatchDifferent() throws {
                let scope = try #require(fromString("blob:image/png"))
                #expect(!scope.matches(.init(mime: "image/jpeg")))
            }

            @Test("should match multiple accept values")
            func matchesMultiple() throws {
                let scope = try #require(fromString("blob?accept=image/png&accept=image/jpeg"))
                #expect(scope.matches(.init(mime: "image/png")))
                #expect(scope.matches(.init(mime: "image/jpeg")))
                #expect(!scope.matches(.init(mime: "image/gif")))
            }
        }

        @Suite("toString")
        struct ToString {
            @Test("should format scope with accept parameter")
            func formatsAccept() throws {
                #expect(try permission("image/png", "image/jpeg").canonicalScopeString()
                    == "blob?accept=image/jpeg&accept=image/png")
            }

            @Test("should strip redundant accept parameters")
            func stripsRedundant() throws {
                #expect(try permission("*/*", "image/*").canonicalScopeString() == "blob:*/*")
                #expect(try permission("*/*", "image/png").canonicalScopeString() == "blob:*/*")
                #expect(try permission("image/*", "image/png").canonicalScopeString() == "blob:image/*")
            }

            @Test("should use positional format for single accept")
            func positionalForSingle() throws {
                #expect(try permission("image/png").canonicalScopeString() == "blob:image/png")
                #expect(try permission("image/*").canonicalScopeString() == "blob:image/*")
                #expect(try permission("*/*").canonicalScopeString() == "blob:*/*")
            }

            @Test("should use query format for multiple accepts")
            func queryForMultiple() throws {
                #expect(try permission("image/png", "image/jpeg").canonicalScopeString()
                    == "blob?accept=image/jpeg&accept=image/png")
            }
        }
    }
}
