import Testing
@testable import PetrelOAuthScopes

/// One-to-one port of `packages/oauth/oauth-scopes/src/scope-permissions.test.ts`
/// (bluesky-social/atproto). Suites mirror its `describe` blocks and each test
/// carries the name of its `it`.
///
/// The class under test there, `ScopePermissions`, evaluates the granular
/// permissions only: a request is allowed when some granted value parses as a
/// permission of the resource and matches it (`scopes-set.ts:39-47`). Its
/// subclass `ScopePermissionsTransition` adds the `transition:` scopes, and is
/// the one the reference PDS constructs for every OAuth credential.
///
/// This package has one type, `ScopePermissions`, corresponding to the
/// subclass. So each test here asserts the original expectations against the
/// typed permissions (`Subject.allows…`, a parse and a `matches`), and then
/// states what `ScopePermissions` answers for the same requests:
///
///  - the same, in every test that grants no `transition:` scope;
///  - in the tests named 'should ignore "transition:…"', what
///    `ScopePermissionsTransition` answers, written out. Those are the
///    expectations of `scope-permissions-transition.test.ts`.
@Suite("scope-permissions.test.ts")
struct UpstreamScopePermissionsTests {
    /// A set of granted scopes, evaluated as the reference implementation's
    /// base `ScopePermissions` evaluates it. Each request is also put to this
    /// package's `ScopePermissions`, and both answers are kept.
    final class Subject {
        let scope: String
        private(set) var merged: [Bool] = []
        private var granular: [Bool] = []

        init(_ scope: String) {
            self.scope = scope
        }

        private func record<P: ScopePermission>(
            _: P.Type, _ target: P.Target, _ merged: (ScopePermissions) -> Bool
        ) -> Bool {
            let allowed = scope.split(separator: " ").contains {
                (try? P.parse(String($0)))?.matches(target) ?? false
            }
            granular.append(allowed)
            self.merged.append(merged(ScopePermissions(scope: scope)))
            return allowed
        }

        func allowsAccount(_ target: AccountPermission.Target) -> Bool {
            record(AccountPermission.self, target) { $0.allowsAccount(target) }
        }

        func allowsBlob(_ target: BlobPermission.Target) -> Bool {
            record(BlobPermission.self, target) { $0.allowsBlob(target) }
        }

        func allowsRepo(_ target: RepoPermission.Target) -> Bool {
            record(RepoPermission.self, target) { $0.allowsRepo(target) }
        }

        func allowsRpc(_ target: RpcPermission.Target) -> Bool {
            record(RpcPermission.self, target) { $0.allowsRPC(target) }
        }

        /// `ScopePermissions` gave the same answer to every request made.
        var scopePermissionsAgrees: Bool {
            !granular.isEmpty && granular == merged
        }
    }

    @Suite("allowsAccount")
    struct AllowsAccount {
        @Test("should properly allow \"account:email\"")
        func accountEmail() {
            let set = Subject("account:email")

            #expect(set.allowsAccount(.init(attr: .email, action: .read)))
            #expect(!set.allowsAccount(.init(attr: .email, action: .manage)))

            #expect(!set.allowsAccount(.init(attr: .repo, action: .read)))
            #expect(!set.allowsAccount(.init(attr: .repo, action: .manage)))

            #expect(!set.allowsAccount(.init(attr: .status, action: .read)))
            #expect(!set.allowsAccount(.init(attr: .status, action: .manage)))

            #expect(set.scopePermissionsAgrees)
        }

        @Test("should ignore \"transition:email\"")
        func ignoresTransitionEmail() {
            let set = Subject("transition:email")

            #expect(!set.allowsAccount(.init(attr: .email, action: .read)))
            #expect(!set.allowsAccount(.init(attr: .email, action: .manage)))

            // `ScopePermissions` honours it, for reading the email only.
            #expect(set.merged == [true, false])
        }
    }

    @Suite("allowsBlob")
    struct AllowsBlob {
        @Test("should allow any mime with \"blob:*/*\"")
        func anyMime() {
            let set = Subject("blob:*/*")
            #expect(set.allowsBlob(.init(mime: "image/png")))
            #expect(set.allowsBlob(.init(mime: "application/json")))
            #expect(set.scopePermissionsAgrees)
        }

        @Test("should only allow images with \"blob:image/*\"")
        func imagesOnly() {
            let set = Subject("blob:image/*")
            #expect(set.allowsBlob(.init(mime: "image/png")))
            #expect(!set.allowsBlob(.init(mime: "application/json")))
            #expect(set.scopePermissionsAgrees)
        }

        @Test("should ignore invalid scope \"blob:*\"")
        func ignoresBlobStar() {
            let set = Subject("blob:*")
            #expect(!set.allowsBlob(.init(mime: "image/png")))
            #expect(!set.allowsBlob(.init(mime: "application/json")))
            #expect(set.scopePermissionsAgrees)
        }

        @Test("should ignore invalid scope \"blob:/image\"")
        func ignoresBlobSlashImage() {
            let set = Subject("blob:/image")
            #expect(!set.allowsBlob(.init(mime: "image/png")))
            #expect(!set.allowsBlob(.init(mime: "application/json")))
            #expect(set.scopePermissionsAgrees)
        }

        @Test("should ignore \"transition:generic\"")
        func ignoresTransitionGeneric() {
            let set = Subject("transition:generic")
            #expect(!set.allowsBlob(.init(mime: "image/png")))
            #expect(!set.allowsBlob(.init(mime: "application/json")))

            // `ScopePermissions` honours it, for any media type.
            #expect(set.merged == [true, true])
        }
    }

    @Suite("allowsRepo")
    struct AllowsRepo {
        @Test("should allow any repo action with \"repo:*\"")
        func anyRepoAction() {
            let set = Subject("repo:*")
            #expect(set.allowsRepo(.init(collection: "com.example.foo", action: .create)))
            #expect(set.allowsRepo(.init(collection: "com.example.foo", action: .update)))
            #expect(set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .delete)))
            #expect(set.scopePermissionsAgrees)
        }

        @Test("should allow specific repo actions")
        func specificRepoActions() {
            let set = Subject("repo:*?action=create")
            #expect(set.allowsRepo(.init(collection: "com.example.foo", action: .create)))
            #expect(set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create)))

            // Control

            #expect(!set.allowsRepo(.init(collection: "com.example.foo", action: .update)))
            #expect(!set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .delete)))
            #expect(set.scopePermissionsAgrees)
        }

        @Test("should allow specific repo collection & actions")
        func specificCollectionAndActions() {
            let set = Subject("repo:com.example.foo?action=create")
            #expect(set.allowsRepo(.init(collection: "com.example.foo", action: .create)))

            // Control

            #expect(!set.allowsRepo(.init(collection: "com.example.foo", action: .update)))
            #expect(!set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .delete)))
            #expect(!set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create)))
            #expect(set.scopePermissionsAgrees)
        }

        @Test("should ignore transition:generic")
        func ignoresTransitionGeneric() {
            let set = Subject("transition:generic")
            #expect(!set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create)))
            #expect(!set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .delete)))
            #expect(!set.allowsRepo(.init(collection: "com.example.foo", action: .create)))
            #expect(!set.allowsRepo(.init(collection: "com.example.foo", action: .update)))

            // `ScopePermissions` honours it, for any collection and action.
            #expect(set.merged == [true, true, true, true])
        }
    }

    @Suite("allowsRpc")
    struct AllowsRpc {
        @Test("should ignore \"rpc:*?lxm=*\"")
        func ignoresInvalidRpc() {
            let set = Subject("rpc:*?lxm=*")
            #expect(!set.allowsRpc(.init(lxm: "com.example.method", aud: "did:web:example.com")))
            #expect(!set.allowsRpc(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com")))
            #expect(set.scopePermissionsAgrees)
        }

        @Test("should allow constraining \"lxm\"")
        func constrainsLxm() {
            let set = Subject("rpc:app.bsky.feed.getFeed?aud=*")
            #expect(set.allowsRpc(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com")))
            #expect(set.allowsRpc(.init(lxm: "app.bsky.feed.getFeed", aud: "did:plc:blahbla")))

            // Control

            #expect(!set.allowsRpc(.init(lxm: "com.example.method", aud: "did:web:example.com")))
            #expect(set.scopePermissionsAgrees)
        }

        @Test("should allow constraining \"aud\"")
        func constrainsAud() {
            let set = Subject("rpc:*?aud=did:web:example.com%23foo")
            #expect(set.allowsRpc(.init(lxm: "com.example.method", aud: "did:web:example.com#foo")))
            #expect(set.allowsRpc(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com#foo")))

            // Control

            // invalid aud (wrong service id)
            #expect(!set.allowsRpc(.init(lxm: "com.example.method", aud: "did:web:bar.com#foo")))
            // invalid aud (no service id)
            #expect(!set.allowsRpc(.init(lxm: "com.example.method", aud: "did:web:example.com")))
            #expect(set.scopePermissionsAgrees)
        }

        @Test("should allow constraining \"lxm\" and \"aud\"")
        func constrainsLxmAndAud() {
            let set = Subject("rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23foo")
            #expect(set.allowsRpc(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com#foo")))

            // Control

            #expect(!set.allowsRpc(.init(lxm: "com.example.method", aud: "did:web:example.com")))
            #expect(!set.allowsRpc(.init(lxm: "app.bsky.feed.getFeed", aud: "did:plc:blahbla")))
            #expect(set.scopePermissionsAgrees)
        }

        @Test("should ignore \"transition:generic\"")
        func ignoresTransitionGeneric() {
            let set = Subject("transition:generic")
            #expect(!set.allowsRpc(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com")))
            #expect(!set.allowsRpc(.init(lxm: "com.example.method", aud: "did:web:example.com")))

            // `ScopePermissions` honours it, for any method outside `chat.bsky`.
            #expect(set.merged == [true, true])
        }

        @Test("should ignore \"transition:chat.bsky\"")
        func ignoresTransitionChatBsky() {
            let set = Subject("transition:chat.bsky")
            #expect(!set.allowsRpc(.init(lxm: "chat.bsky.message.send", aud: "did:web:example.com")))
            #expect(!set.allowsRpc(.init(lxm: "chat.bsky.conversation.get", aud: "did:web:example.com")))

            // Control

            #expect(!set.allowsRpc(.init(lxm: "app.bsky.feed.post", aud: "did:web:example.com")))
            #expect(!set.allowsRpc(.init(lxm: "com.example.foo", aud: "did:web:example.com")))

            // `ScopePermissions` honours it, for methods inside `chat.bsky` only.
            #expect(set.merged == [true, true, false, false])
        }
    }

    /// `assertRpc` throws `ScopeMissingError`; `requireRPC` throws
    /// `ScopeDenied`.
    @Suite("assertRpc combined-aud")
    struct AssertRpcCombinedAud {
        @Test("allows did#serviceId aud when scope grants the same combined form")
        func allowsCombinedForm() {
            let set = ScopePermissions(scope: "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23bsky_appview")
            #expect(throws: Never.self) {
                try set.requireRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com#bsky_appview"))
            }
        }

        @Test("rejects bare-DID aud when scope grants a combined form")
        func rejectsBareDID() {
            let set = ScopePermissions(scope: "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23bsky_appview")
            #expect(throws: ScopeDenied(needed: "rpc:app.bsky.feed.getFeed?aud=did:web:example.com")) {
                try set.requireRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com"))
            }
        }

        @Test("allows wildcard aud against a combined-form match")
        func allowsWildcardAud() {
            let set = ScopePermissions(scope: "rpc:app.bsky.feed.getFeed?aud=*")
            #expect(throws: Never.self) {
                try set.requireRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com#bsky_appview"))
            }
        }
    }
}
