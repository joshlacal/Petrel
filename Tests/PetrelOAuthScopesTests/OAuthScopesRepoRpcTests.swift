import Foundation
import Testing
@testable import PetrelOAuthScopes

/// `repo:` and `rpc:` through the typed API: parsed values, matching and
/// canonical form. The one-to-one ports of `scopes/repo-permission.test.ts` and
/// `scopes/rpc-permission.test.ts` are in `Upstream/`.
@Suite("repo: / rpc: families")
struct OAuthScopesRepoRpcTests {
    // MARK: repo

    @Test
    func repoParsesCollectionAndDefaultsAction() throws {
        let a = try RepoPermission.parse("repo:com.example.foo")
        #expect(a.collection == [.nsid("com.example.foo")])
        #expect(a.action == [.create, .update, .delete])

        let b = try RepoPermission.parse("repo:com.example.foo?action=create&action=update")
        #expect(b.action == [.create, .update])

        let star = try RepoPermission.parse("repo:*")
        #expect(star.collection == [.any])
        #expect(star.action == [.create, .update, .delete])
    }

    @Test
    func repoRejectsMalformedCollectionOrAction() {
        for scope in ["repo:foo bar", "repo:.foo", "repo:bar.", "repo:com.example.foo?action=invalid",
                      "invalid", "scope", "repo:*?action=*", "repo:invalid",
                      "repo?collection=invalid&action=invalid"] {
            #expect(throws: ScopeParseError.self) { try RepoPermission.parse(scope) }
        }
    }

    @Test
    func repoMatchingRequiresBothActionAndCollectionMembership() throws {
        let star = try RepoPermission.parse("repo:*?action=create")
        #expect(star.matches(.init(collection: "com.example.bar", action: .create)))
        #expect(!star.matches(.init(collection: "com.example.bar", action: .delete)))

        let concrete = try RepoPermission.parse("repo:com.example.foo?action=create")
        #expect(concrete.matches(.init(collection: "com.example.foo", action: .create)))
        #expect(!concrete.matches(.init(collection: "com.example.foo", action: .update)))
        #expect(!concrete.matches(.init(collection: "com.example.bar", action: .create)))
    }

    @Test
    func repoCanonicalisation() throws {
        let vectors: [(String, String)] = [
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
            // Pins THREE rules at once: two collections means no positional
            // collapse; the collection list is SORTED; `collection` still
            // precedes `action` (schema-declaration order, not alphabetical).
            ("repo?action=create&collection=com.example.foo&collection=com.example.bar",
             "repo?collection=com.example.bar&collection=com.example.foo&action=create"),
        ]
        for (input, expected) in vectors {
            let parsed = try RepoPermission.parse(input)
            #expect(try parsed.canonicalScopeString() == expected)
        }
    }

    @Test
    func repoScopeNeededDoesNotValidateItsInput() throws {
        #expect(try RepoPermission.scopeNeeded(for: .init(collection: "com.example.foo", action: .create))
            == "repo:com.example.foo?action=create")
        // scopes/repo-permission.test.ts:106-116 — malformed input still formats.
        #expect(try RepoPermission.scopeNeeded(for: .init(collection: "invalid", action: .create))
            == "repo:invalid?action=create")
    }

    // MARK: rpc

    @Test
    func rpcParsesAudAndLxm() throws {
        let a = try RpcPermission.parse("rpc:com.example.service?aud=did:web:example.com%23service_id")
        #expect(a.aud == .service("did:web:example.com#service_id"))
        #expect(a.lxm == [.nsid("com.example.service")])

        let b = try RpcPermission.parse("rpc?lxm=com.example.method1&aud=*")
        #expect(b.aud == .any)
        #expect(b.lxm == [.nsid("com.example.method1")])

        let c = try RpcPermission.parse("rpc?aud=*&lxm=com.example.method1&lxm=com.example.method2")
        #expect(c.lxm == [.nsid("com.example.method1"), .nsid("com.example.method2")])
    }

    @Test
    func rpcRejectsMissingRequiredFieldsAndForbiddenCombination() {
        for scope in [
            "rpc?aud=did:web:example.com%23service_id", // no lxm
            "rpc:?aud=did:web:example.com%23service_id", // empty positional: present-but-invalid, not absent
            "rpc:com.example.method1", // no aud
            "rpc:com.example.method1?aud=did:web:example.com&lxm=com.example.method2", // positional + named conflict
            "rpc?aud=*&lxm=*", "rpc:*?aud=*", // any-aud + any-lxm forbidden
            "rpc?aud=did:web:example.com", // no lxm
            "rpc?lxm=com.example.method1", // no aud
            "rpc:com.example.service", // no aud
            "rpc:com.example.service?aud=invalid",
            "rpc:invalid", "rpc?lxm=invalid",
            "rpc:foo.bar.baz?aud=did:web", // bare did:web, no '#'
            "rpc:com.example.service?aud=did:plc:111%23service_id", // wrong plc length/charset
            "rpc:com.example.service?aud=did:foo:bar", // no '#' AND method not plc/web
            "notrpc:com.example.service?aud=*",
        ] {
            #expect(throws: ScopeParseError.self) { try RpcPermission.parse(scope) }
        }
    }

    @Test
    func rpcMatchingIsExactStringOnBothDimensions() throws {
        let wildcardLxm = try RpcPermission.parse("rpc:*?aud=did:web:example.com%23service_id")
        #expect(wildcardLxm.matches(.init(lxm: "com.example.anyMethod", aud: "did:web:example.com#service_id")))

        let scoped = try RpcPermission.parse("rpc:com.example.service?aud=did:web:example.com%23service_id")
        #expect(!scoped.matches(.init(lxm: "com.example.service", aud: "did:example:456#service_id")))
    }

    @Test
    func rpcFormat() throws {
        let permission = RpcPermission(aud: .service("did:web:example.com#service_id"),
                                        lxm: [.any, .nsid("com.example.method1")])
        #expect(try permission.canonicalScopeString() == "rpc:*?aud=did:web:example.com%23service_id")
    }

    @Test
    func rpcCanonicalisation() throws {
        let vectors: [(String, String)] = [
            ("rpc:com.example.service?aud=did:web:example.com%23service_id",
             "rpc:com.example.service?aud=did:web:example.com%23service_id"),
            ("rpc:com.example.service?aud=did:web:example.com#service_id",
             "rpc:com.example.service?aud=did:web:example.com%23service_id"),
            ("rpc?lxm=com.example.method1&lxm=com.example.method2&aud=*",
             "rpc?lxm=com.example.method1&lxm=com.example.method2&aud=*"),
            ("rpc?lxm=com.example.method1&lxm=com.example.method2&lxm=*&aud=did:web:example.com%23service_id",
             "rpc:*?aud=did:web:example.com%23service_id"),
            ("rpc?aud=did:web:example.com%23foo&lxm=com.example.service",
             "rpc:com.example.service?aud=did:web:example.com%23foo"),
            ("rpc?lxm=com.example.method1&aud=did:web:example.com#foo",
             "rpc:com.example.method1?aud=did:web:example.com%23foo"),
            ("rpc?lxm=com.example.method1&aud=did:web:example.com%23bar",
             "rpc:com.example.method1?aud=did:web:example.com%23bar"),
            // An empty pair is skipped, as `URLSearchParams` does.
            ("rpc:com.example.method1?&aud=*", "rpc:com.example.method1?aud=*"),
        ]
        for (input, expected) in vectors {
            let parsed = try RpcPermission.parse(input)
            #expect(try parsed.canonicalScopeString() == expected)
        }
    }
}
