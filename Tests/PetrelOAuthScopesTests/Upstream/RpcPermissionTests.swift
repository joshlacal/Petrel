import Testing
@testable import PetrelOAuthScopes

/// One-to-one port of `packages/oauth/oauth-scopes/src/scopes/rpc-permission.test.ts`
/// (bluesky-social/atproto). Suites mirror its `describe` blocks and each test
/// carries the name of its `it`.
///
/// `aud` and `lxm` are strings there and `AudParam` / `LxmParam` here; the
/// comparisons are on the string form. The list of invalid scopes repeats
/// three entries in the original; each appears once here.
@Suite("scopes/rpc-permission.test.ts")
struct UpstreamRpcPermissionTests {
    static func fromString(_ scope: String) -> RpcPermission? {
        try? RpcPermission.parse(scope)
    }

    static func permission(_ aud: String, _ lxm: [String]) -> RpcPermission {
        RpcPermission(
            aud: aud == "*" ? .any : .service(aud),
            lxm: lxm.map { $0 == "*" ? .any : .nsid($0) }
        )
    }

    @Suite("static")
    struct Static {
        @Suite("fromString")
        struct FromString {
            @Test("should parse positional scope")
            func parsesPositionalScope() throws {
                let scope = try #require(fromString("rpc:com.example.service?aud=did:web:example.com%23service_id"))
                #expect(scope.aud.stringValue == "did:web:example.com#service_id")
                #expect(scope.lxm.map(\.stringValue) == ["com.example.service"])
            }

            @Test("should parse strings correctly")
            func parsesStrings() throws {
                let named = try #require(fromString("rpc?lxm=com.example.method1&aud=*"))
                #expect(named.aud == .any)
                #expect(named.lxm == [.nsid("com.example.method1")])

                let positional = try #require(fromString("rpc:com.example.method1?aud=*"))
                #expect(positional.aud == .any)
                #expect(positional.lxm == [.nsid("com.example.method1")])
            }

            @Test("should render strings correctly")
            func rendersStrings() throws {
                #expect(try permission("did:web:example.com#service_id", ["com.example.service"]).canonicalScopeString()
                    == "rpc:com.example.service?aud=did:web:example.com%23service_id")
                #expect(try permission("*", ["com.example.method1"]).canonicalScopeString()
                    == "rpc:com.example.method1?aud=*")
                #expect(
                    try permission("did:web:example.com#service_id", ["com.example.method1", "com.example.method2"])
                        .canonicalScopeString()
                        == "rpc?lxm=com.example.method1&lxm=com.example.method2&aud=did:web:example.com%23service_id"
                )
            }

            @Test("should reject scopes without lxm")
            func rejectsWithoutLxm() {
                #expect(fromString("rpc?aud=did:web:example.com%23service_id") == nil)
                #expect(fromString("rpc:?aud=did:web:example.com%23service_id") == nil)
            }

            @Test("should reject scopes without aud")
            func rejectsWithoutAud() {
                #expect(fromString("rpc?lxm=com.example.method1") == nil)
                #expect(fromString("rpc:com.example.method1") == nil)
            }

            @Test("should reject scopes with lxm in both positional and query form")
            func rejectsLxmInBothForms() {
                #expect(fromString("rpc:com.example.method1?aud=did:web:example.com&lxm=com.example.method2") == nil)
            }

            @Test("should parse valid rpc scope with multiple lxm")
            func parsesMultipleLxm() throws {
                let scope = try #require(fromString("rpc?aud=*&lxm=com.example.method1&lxm=com.example.method2"))
                #expect(scope.aud.stringValue == "*")
                #expect(scope.lxm.map(\.stringValue) == ["com.example.method1", "com.example.method2"])
            }

            @Test("should reject rpc scope without lxm")
            func rejectsRpcScopeWithoutLxm() {
                #expect(fromString("rpc?aud=did:web:example.com") == nil)
            }

            @Test("should reject rpc scope without aud")
            func rejectsRpcScopeWithoutAud() {
                #expect(fromString("rpc?lxm=com.example.method1") == nil)
            }

            @Test("should reject any aud/any lxm")
            func rejectsAnyAudAnyLxm() {
                #expect(fromString("rpc?aud=*&lxm=*") == nil)
                #expect(fromString("rpc:*?aud=*") == nil)
            }

            @Test("should reject missing aud")
            func rejectsMissingAud() {
                #expect(fromString("rpc:com.example.service") == nil)
            }

            @Test("should reject invalid aud")
            func rejectsInvalidAud() {
                #expect(fromString("rpc:com.example.service?aud=invalid") == nil)
            }

            @Test("should reject invalid lxm")
            func rejectsInvalidLxm() {
                #expect(fromString("rpc:invalid") == nil)
                #expect(fromString("rpc?lxm=invalid") == nil)
            }

            @Test("should return null for invalid rpc scope", arguments: [
                "rpc:*",
                "invalid",
                "rpc:invalid",
                "rpc:invalid?aud=did:web:example.com",
                "rpc:invalid?aud=did:web:example.com%23service_id",
                "rpc:foo.bar",
                "rpc:com.example.service?aud=did:web:example.com%23service_id&invalid=param",
                "rpc:foo.bar.baz?aud=did:web",
                "rpc:foo.bar.baz?aud=did:web%23service_id",
                "rpc:foo.bar.baz?aud=did:plc:111",
                "rpc:foo.bar.baz?aud=did:plc:111%23service_id",
                "rpc:foo.bar.baz?aud=did:foo:bar",
                "rpc:foo.bar.baz?aud=did:foo:bar%23service_id",
                "rpc:foo.bar.baz?aud=did:web:example.com%23service_id&lxm=foo.bar.baz",
                "rpc:foo.bar.baz?aud=invalid",
                "rpc:com.example.service?aud=invalid",
                "notrpc:com.example.service?aud=did:web:example.com%23service_id",
                "rpc?lxm=invalid&aud=invalid",
            ])
            func rejectsInvalidScope(invalid: String) {
                #expect(fromString(invalid) == nil)
            }
        }

        @Suite("scopeNeededFor")
        struct ScopeNeededFor {
            @Test("should return correct scope string for specific lxm and aud")
            func specificLxmAndAud() throws {
                #expect(
                    try RpcPermission.scopeNeeded(
                        for: .init(lxm: "com.example.service", aud: "did:web:example.com#service_id")
                    ) == "rpc:com.example.service?aud=did:web:example.com%23service_id"
                )
            }

            @Test("should return scope that accepts all aud with specific lxm")
            func allAud() throws {
                #expect(try RpcPermission.scopeNeeded(for: .init(lxm: "com.example.method1", aud: "*"))
                    == "rpc:com.example.method1?aud=*")
            }
        }
    }

    @Suite("instance")
    struct Instance {
        @Suite("matches")
        struct Matches {
            @Test("should match exact lxm and aud")
            func matchesExact() throws {
                let scope = try #require(fromString("rpc:com.example.service?aud=did:web:example.com%23service_id"))
                #expect(scope.matches(.init(lxm: "com.example.service", aud: "did:web:example.com#service_id")))
            }

            @Test("should not match different lxm")
            func doesNotMatchDifferentLxm() throws {
                let scope = try #require(fromString("rpc:com.example.service?aud=did:web:example.com%23service_id"))
                #expect(!scope.matches(.init(lxm: "com.example.OtherService", aud: "did:web:example.com#service_id")))
            }

            @Test("should not match different aud")
            func doesNotMatchDifferentAud() throws {
                let scope = try #require(fromString("rpc:com.example.service?aud=did:web:example.com%23service_id"))
                #expect(!scope.matches(.init(lxm: "com.example.service", aud: "did:example:456#service_id")))
            }

            @Test("should match wildcard aud")
            func matchesWildcardAud() throws {
                let scope = try #require(fromString("rpc:com.example.method1?aud=*"))
                #expect(scope.matches(.init(lxm: "com.example.method1", aud: "did:web:example.com#service_id")))
            }

            @Test("should match wildcard lxm")
            func matchesWildcardLxm() throws {
                let scope = try #require(fromString("rpc:*?aud=did:web:example.com%23service_id"))
                #expect(scope.matches(.init(lxm: "com.example.method1", aud: "did:web:example.com#service_id")))
            }

            @Test("should not match different lxm with wildcard aud")
            func wildcardLxmMatchesAnyMethod() throws {
                // The name is the original's; the assertion, also the
                // original's, is that a wildcard `lxm` matches another method.
                let scope = try #require(fromString("rpc:*?aud=did:web:example.com%23service_id"))
                #expect(scope.matches(.init(lxm: "com.example.anyMethod", aud: "did:web:example.com#service_id")))
            }
        }

        @Suite("toString")
        struct ToString {
            @Test("should format scope with lxm and aud")
            func formatsLxmAndAud() throws {
                #expect(try permission("did:web:example.com#service_id", ["com.example.service"]).canonicalScopeString()
                    == "rpc:com.example.service?aud=did:web:example.com%23service_id")
            }

            @Test("should format scope with wildcard aud")
            func formatsWildcardAud() throws {
                #expect(try permission("*", ["com.example.method1"]).canonicalScopeString()
                    == "rpc:com.example.method1?aud=*")
            }

            @Test("should format scope with wildcard lxm")
            func formatsWildcardLxm() throws {
                #expect(try permission("did:web:example.com#service_id", ["*"]).canonicalScopeString()
                    == "rpc:*?aud=did:web:example.com%23service_id")
            }

            @Test("simplifies lxm if one of them is \"*\"")
            func simplifiesLxm() throws {
                #expect(try permission("did:web:example.com#service_id", ["*", "com.example.method1"])
                    .canonicalScopeString() == "rpc:*?aud=did:web:example.com%23service_id")
            }
        }
    }

    @Suite("consistency")
    struct Consistency {
        @Test("should properly re-format", arguments: [
            (
                "rpc:com.example.service?aud=did:web:example.com%23service_id",
                "rpc:com.example.service?aud=did:web:example.com%23service_id"
            ),
            (
                "rpc:com.example.service?aud=did:web:example.com#service_id",
                "rpc:com.example.service?aud=did:web:example.com%23service_id"
            ),
            (
                "rpc?lxm=com.example.method1&lxm=com.example.method2&aud=*",
                "rpc?lxm=com.example.method1&lxm=com.example.method2&aud=*"
            ),
            (
                "rpc?lxm=com.example.method1&lxm=com.example.method2&lxm=*&aud=did:web:example.com%23service_id",
                "rpc:*?aud=did:web:example.com%23service_id"
            ),
            (
                "rpc?aud=did:web:example.com%23foo&lxm=com.example.service",
                "rpc:com.example.service?aud=did:web:example.com%23foo"
            ),
            (
                "rpc?lxm=com.example.method1&aud=did:web:example.com#foo",
                "rpc:com.example.method1?aud=did:web:example.com%23foo"
            ),
            (
                "rpc?lxm=com.example.method1&aud=did:web:example.com%23bar",
                "rpc:com.example.method1?aud=did:web:example.com%23bar"
            ),
            ("rpc:com.example.method1?&aud=*", "rpc:com.example.method1?aud=*"),
        ])
        func reformats(input: String, expected: String) throws {
            #expect(try RpcPermission.parse(input).canonicalScopeString() == expected)
        }
    }
}
