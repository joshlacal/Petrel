import Foundation
import Testing
@testable import PetrelOAuthScopes

/// The `transition:` scopes, which `ScopePermissions` honours the way the
/// reference implementation's `ScopePermissionsTransition` does. The reference
/// PDS constructs that class for every OAuth credential
/// (`packages/pds/src/auth-verifier.ts:395`), so this is the behaviour of an
/// ordinary token and not of a legacy mode.
///
/// The one-to-one port of `scope-permissions-transition.test.ts` is in
/// `Upstream/`.
@Suite("transition: scopes stand in for the granular permissions")
struct OAuthScopesTransitionTests {
    private func permissions(_ scopes: String...) -> ScopePermissions {
        ScopePermissions(rawScopes: Set(scopes))
    }

    // MARK: repo (scope-permissions-transition.ts:46-52)

    @Test
    func transitionGenericAllowsAnyRepoWrite() {
        let p = permissions("atproto", "transition:generic")
        for action in RepoAction.allCases {
            #expect(p.allowsRepo(.init(collection: "app.bsky.feed.post", action: action)))
            #expect(p.allowsRepo(.init(collection: "com.example.anything", action: action)))
        }
    }

    /// `atproto` on its own grants no access to any resource.
    @Test
    func atprotoAloneGrantsNoRepoWrite() {
        let p = permissions("atproto")
        #expect(!p.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create)))
    }

    @Test
    func modernRepoGrantStillNarrows() {
        let p = permissions("atproto", "repo:app.bsky.feed.like?action=create")
        #expect(p.allowsRepo(.init(collection: "app.bsky.feed.like", action: .create)))
        #expect(!p.allowsRepo(.init(collection: "app.bsky.feed.post", action: .create)))
        #expect(!p.allowsRepo(.init(collection: "app.bsky.feed.like", action: .delete)))
    }

    // MARK: blob (scope-permissions-transition.ts:38-44)

    @Test
    func transitionGenericAllowsAnyBlobMime() {
        let p = permissions("atproto", "transition:generic")
        #expect(p.allowsBlob(.init(mime: "image/png")))
        #expect(p.allowsBlob(.init(mime: "video/mp4")))
    }

    @Test
    func atprotoAloneGrantsNoBlobUpload() {
        #expect(!permissions("atproto").allowsBlob(.init(mime: "image/png")))
    }

    // MARK: rpc (scope-permissions-transition.ts:54-70)

    @Test
    func transitionGenericAllowsNonChatRPCAndWildcard() {
        let p = permissions("atproto", "transition:generic")
        #expect(p.allowsRPC(.init(lxm: "*", aud: "did:web:api.bsky.app")))
        #expect(p.allowsRPC(.init(lxm: "app.bsky.feed.getTimeline", aud: "did:web:api.bsky.app")))
    }

    /// Direct messages are the one thing `transition:generic` does not reach.
    @Test
    func transitionGenericAloneCannotReachChat() {
        let p = permissions("atproto", "transition:generic")
        #expect(!p.allowsRPC(.init(lxm: "chat.bsky.convo.listConvos", aud: "did:web:api.bsky.chat")))
    }

    @Test
    func transitionChatBskyReachesChatAndNothingElse() {
        let p = permissions("atproto", "transition:chat.bsky")
        #expect(p.allowsRPC(.init(lxm: "chat.bsky.convo.listConvos", aud: "did:web:api.bsky.chat")))
        #expect(!p.allowsRPC(.init(lxm: "app.bsky.feed.getTimeline", aud: "did:web:api.bsky.app")))
    }

    @Test
    func bothTransitionScopesReachEverything() {
        let p = permissions("atproto", "transition:generic", "transition:chat.bsky")
        #expect(p.allowsRPC(.init(lxm: "chat.bsky.convo.listConvos", aud: "did:web:api.bsky.chat")))
        #expect(p.allowsRPC(.init(lxm: "app.bsky.feed.getTimeline", aud: "did:web:api.bsky.app")))
    }

    /// `chat.bsky.` is a dot-boundary prefix, so a lookalike NSID must not be
    /// swept into the chat arm — nor out of the generic one.
    @Test
    func chatPrefixIsDotBounded() {
        let p = permissions("atproto", "transition:generic")
        #expect(p.allowsRPC(.init(lxm: "chat.bskyfoo.convo.list", aud: "did:web:x")))
        #expect(!permissions("atproto", "transition:chat.bsky")
            .allowsRPC(.init(lxm: "chat.bskyfoo.convo.list", aud: "did:web:x")))
    }

    // MARK: account (scope-permissions-transition.ts:26-36)

    @Test
    func transitionEmailGrantsExactlyEmailRead() {
        let p = permissions("atproto", "transition:email")
        #expect(p.allowsAccount(.init(attr: .email, action: .read)))
        #expect(!p.allowsAccount(.init(attr: .email, action: .manage)))
        #expect(!p.allowsAccount(.init(attr: .repo, action: .read)))
        #expect(!p.allowsAccount(.init(attr: .status, action: .read)))
    }

    // MARK: identity

    /// No transition scope grants control over the account's identity.
    @Test
    func noTransitionScopeReachesIdentity() {
        let p = permissions("atproto", "transition:generic", "transition:chat.bsky", "transition:email")
        #expect(!p.allowsIdentity(.init(attr: .handle)))
        #expect(!p.allowsIdentity(.init(attr: .any)))
    }

    // MARK: base scope

    @Test
    func transitionScopesAreNotTheBaseScope() {
        #expect(!permissions("transition:generic").hasBaseATProtocolScope)
        #expect(permissions("atproto").hasBaseATProtocolScope)
        let all = permissions("atproto", "transition:generic", "transition:chat.bsky", "transition:email")
        #expect(all.hasTransitionGeneric && all.hasTransitionChatBsky && all.hasTransitionEmail)
        #expect(all.rejected.isEmpty)
    }

    // MARK: require*

    @Test
    func requireThrowsTheScopeThatWouldHaveSufficed() {
        let p = permissions("atproto")
        #expect(throws: ScopeDenied(needed: "repo:app.bsky.feed.post?action=create")) {
            try p.requireRepo(.init(collection: "app.bsky.feed.post", action: .create))
        }
        #expect(throws: ScopeDenied(needed: "blob:image/png")) {
            try p.requireBlob(.init(mime: "image/png"))
        }
        #expect(throws: ScopeDenied(needed: "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23bsky_fg")) {
            try p.requireRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com#bsky_fg"))
        }
        #expect(throws: ScopeDenied(needed: "account:email")) {
            try p.requireAccount(.init(attr: .email, action: .read))
        }
        #expect(throws: ScopeDenied(needed: "identity:handle")) {
            try p.requireIdentity(.init(attr: .handle))
        }
        #expect(throws: Never.self) {
            try permissions("atproto", "transition:generic")
                .requireRepo(.init(collection: "app.bsky.feed.post", action: .create))
        }
    }
}
