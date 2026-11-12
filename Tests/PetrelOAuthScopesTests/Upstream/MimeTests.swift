import Testing
@testable import PetrelOAuthScopes

/// One-to-one port of `packages/oauth/oauth-scopes/src/lib/mime.test.ts`
/// (bluesky-social/atproto). Suites mirror its `describe` blocks and each test
/// carries the name of its `it`.
///
/// `isAccept(x)` is `AcceptPattern(x) != nil` and `isMime(x)` is
/// `ConcreteMime(x) != nil`. `matchesAccept` and `matchesAnyAccept` are
/// `BlobPermission.matches` on a permission holding those patterns.
@Suite("lib/mime.test.ts")
struct UpstreamMimeTests {
    static func isAccept(_ value: String) -> Bool { AcceptPattern(value) != nil }
    static func isMime(_ value: String) -> Bool { ConcreteMime(value) != nil }

    static func matchesAnyAccept(_ acceptable: [String], _ mime: String) throws -> Bool {
        BlobPermission(accept: try acceptable.map { try #require(AcceptPattern($0)) }).matches(.init(mime: mime))
    }

    static func matchesAccept(_ accept: String, _ mime: String) throws -> Bool {
        try matchesAnyAccept([accept], mime)
    }

    @Suite("isAccept")
    struct IsAccept {
        @Test("should return true for valid MIME types")
        func valid() {
            #expect(isAccept("image/png"))
            #expect(isAccept("application/json"))
            #expect(isAccept("text/html"))
            #expect(isAccept("image/*"))
            #expect(isAccept("*/*"))
        }

        @Test("should return false for invalid MIME types")
        func invalid() {
            #expect(!isAccept("image//png"))
            #expect(!isAccept("/png"))
            #expect(!isAccept("image/"))
            #expect(!isAccept("image/**"))
            #expect(!isAccept("*/png"))
            #expect(!isAccept("*"))
            #expect(!isAccept("image/png/extra"))
        }
    }

    @Suite("isMime")
    struct IsMime {
        @Test("should return true for valid MIME types")
        func valid() {
            #expect(isMime("image/png"))
            #expect(isMime("application/json"))
        }

        @Test("should return false for invalid MIME types")
        func invalid() {
            #expect(!isMime("image/*"))
            #expect(!isMime("*/*"))
            #expect(!isMime("image/png/extra"))
            #expect(!isMime("*/mime"))
            #expect(!isMime("/png"))
            #expect(!isMime("image/"))
            #expect(!isMime("image"))
            #expect(!isMime("image/ png"))
            #expect(!isMime("image//png"))
        }
    }

    @Suite("matchesAccept")
    struct MatchesAccept {
        @Test("should match exact MIME type")
        func exact() throws {
            #expect(try matchesAccept("image/png", "image/png"))
        }

        @Test("should match wildcard MIME type")
        func wildcard() throws {
            #expect(try matchesAccept("image/*", "image/jpeg"))
        }

        @Test("should match subtype wildcard MIME type")
        func subtypeWildcard() throws {
            #expect(try matchesAccept("image/*", "image/gif"))
        }

        @Test("should not match different MIME type")
        func different() throws {
            #expect(try !matchesAccept("image/png", "image/jpeg"))
        }

        @Test("should not match different wildcard MIME type")
        func differentWildcard() throws {
            #expect(try !matchesAccept("image/*", "text/html"))
        }

        @Test("should match any MIME type with *")
        func any() throws {
            #expect(try matchesAccept("*/*", "application/json"))
        }

        @Test("should not match invalid MIME type")
        func invalid() throws {
            #expect(try !matchesAccept("image/png", "*/mime"))
            #expect(try !matchesAccept("image/png", "image"))
            #expect(try !matchesAccept("image/*", "image//png"))
            #expect(try !matchesAccept("image/*", "image/ png"))
            #expect(try !matchesAccept("*/*", "image/"))
            #expect(try !matchesAccept("*/*", "/mime"))
        }
    }

    @Suite("matchesAnyAccept")
    struct MatchesAnyAccept {
        @Test("should return true if any accept matches")
        func anyMatches() throws {
            let accepts = ["image/png", "application/json"]
            #expect(try matchesAnyAccept(accepts, "image/png"))
            #expect(try matchesAnyAccept(accepts, "application/json"))
        }

        @Test("should return false if no accept matches")
        func noneMatches() throws {
            let accepts = ["image/png", "application/json"]
            #expect(try !matchesAnyAccept(accepts, "text/html"))
        }

        @Test("should handle empty accepts array")
        func emptyAccepts() throws {
            #expect(try !matchesAnyAccept([], "image/png"))
        }

        @Test("should handle single accept")
        func singleAccept() throws {
            let accepts = ["image/*"]
            #expect(try matchesAnyAccept(accepts, "image/jpeg"))
            #expect(try !matchesAnyAccept(accepts, "text/html"))
        }
    }
}
