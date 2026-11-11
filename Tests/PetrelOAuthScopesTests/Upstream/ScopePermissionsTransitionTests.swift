import Testing
@testable import PetrelOAuthScopes

/// One-to-one port of
/// `packages/oauth/oauth-scopes/src/scope-permissions-transition.test.ts`
/// (bluesky-social/atproto). Suites mirror its `describe` blocks and each test
/// carries the name of its `it`.
///
/// `ScopePermissionsTransition` is `ScopePermissions` here.
@Suite("scope-permissions-transition.test.ts")
struct UpstreamScopePermissionsTransitionTests {
    @Suite("allowsAccount")
    struct AllowsAccount {
        @Test("should allow account:email with transition:email")
        func transitionEmail() {
            let set = ScopePermissions(scope: "transition:email account:repo")
            #expect(set.allowsAccount(.init(attr: .email, action: .read)))
            #expect(!set.allowsAccount(.init(attr: .email, action: .manage)))

            #expect(set.allowsAccount(.init(attr: .repo, action: .read)))
            #expect(!set.allowsAccount(.init(attr: .repo, action: .manage)))

            #expect(!set.allowsAccount(.init(attr: .status, action: .read)))
            #expect(!set.allowsAccount(.init(attr: .status, action: .manage)))
        }
    }

    @Suite("allowsBlob")
    struct AllowsBlob {
        @Test("should allow blob with transition:generic")
        func transitionGeneric() {
            let set = ScopePermissions(scope: "transition:generic")
            #expect(set.allowsBlob(.init(mime: "foo/bar")))
        }
    }

    @Suite("allowsRepo")
    struct AllowsRepo {
        @Test("should allow repo with transition:generic")
        func transitionGeneric() {
            let set = ScopePermissions(scope: "transition:generic")
            #expect(set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create)))
            #expect(set.allowsRepo(.init(collection: "app.bsky.feed.post", action: .delete)))
            #expect(set.allowsRepo(.init(collection: "com.example.foo", action: .create)))
            #expect(set.allowsRepo(.init(collection: "com.example.foo", action: .update)))
        }
    }

    @Suite("allowsRpc")
    struct AllowsRpc {
        @Test("should allow rpc with transition:generic")
        func transitionGeneric() {
            let set = ScopePermissions(scope: "transition:generic")
            #expect(set.allowsRPC(.init(lxm: "app.bsky.feed.post", aud: "did:web:example.com")))
            #expect(set.allowsRPC(.init(lxm: "com.example.foo", aud: "did:web:example.com")))
            #expect(set.allowsRPC(.init(lxm: "*", aud: "did:web:example.com")))
        }

        @Test("should allow chat.bsky.* methods with \"transition:chat.bsky\"")
        func transitionChatBsky() {
            let set = ScopePermissions(scope: "transition:chat.bsky")
            #expect(set.allowsRPC(.init(lxm: "chat.bsky.message.send", aud: "did:web:example.com")))
            #expect(set.allowsRPC(.init(lxm: "chat.bsky.conversation.get", aud: "did:web:example.com")))

            // Control

            #expect(!set.allowsRPC(.init(lxm: "app.bsky.feed.post", aud: "did:web:example.com")))
            #expect(!set.allowsRPC(.init(lxm: "com.example.foo", aud: "did:web:example.com")))
            #expect(!set.allowsRPC(.init(lxm: "*", aud: "did:web:example.com")))
        }

        @Test("should reject chat methods with \"transition:generic\"")
        func transitionGenericRejectsChat() {
            let set = ScopePermissions(scope: "transition:generic")

            #expect(!set.allowsRPC(.init(lxm: "chat.bsky.message.send", aud: "did:web:example.com")))
            #expect(!set.allowsRPC(.init(lxm: "chat.bsky.conversation.get", aud: "did:web:example.com")))

            // Control

            #expect(set.allowsRPC(.init(lxm: "app.bsky.feed.post", aud: "did:web:example.com")))
            #expect(set.allowsRPC(.init(lxm: "com.example.foo", aud: "did:web:example.com")))
        }
    }
}
