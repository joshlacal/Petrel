import Foundation
@testable import PetrelOAuthScopes
import Testing

/// The ten scope strings where the permission specification's text and the
/// reference implementation (`@atproto/oauth-scopes`) disagree. Petrel follows
/// the reference in every one, and this suite pins each to the value the
/// reference produced (read from the generated fixture, never written here).
@Suite("Reference parity: where the spec text and the reference differ")
struct ReferenceParityTests {
    /// The inputs, with the reason the specification text would suggest a
    /// different answer.
    static let cases: [(input: String, specReading: String)] = [
        ("account:email?action=manage&action=read", "action is described as a single string"),
        ("account:email?action=read&action=manage", "action is described as a single string"),
        ("account:email?action=read&action=read", "action is described as a single string"),
        ("rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a+b", "+ is not a reserved character in the scope syntax"),
        ("blob?accept=image/svg+xml", "+ is not a reserved character in the scope syntax"),
        ("rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2Bb", "a canonical form would keep %2B"),
        ("blob?accept=image/svg%2Bxml&accept=image/png", "a canonical form would keep %2B"),
        ("rpc:app.bsky.feed.getFeed?aud=did:web:localhost%253A8080%23svc", "a canonical form would keep %25"),
        ("rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2541", "a canonical form would keep %25"),
        ("blob?accept=image/png&accept=image/png", "a single accept could use the positional form"),
    ]

    @Test("Petrel gives the reference implementation's answer", arguments: cases.map(\.input))
    func followsTheReference(input: String) throws {
        let corpus = try UpstreamScopeCorpus.load()
        let reference = try #require(corpus.value(input), "\(input) is not in the generated fixture")
        let parsed = try? ATProtoScope.parse(input)
        #expect((parsed != nil) == (reference.isAtprotoOauthScope == true), "accept/reject for \(input)")
        if let parsed {
            #expect(try parsed.canonicalScopeString() == reference.canonical, "canonical form of \(input)")
        }
    }

    @Test("the cases are what the documentation says: three accepted, two rejected, five canonical forms")
    func shape() throws {
        let corpus = try UpstreamScopeCorpus.load()
        let references = try Self.cases.map { try #require(corpus.value($0.input)) }
        #expect(references.filter { $0.isAtprotoOauthScope != true }.map(\.input) == [
            "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a+b",
            "blob?accept=image/svg+xml",
        ])
        #expect(Self.cases.count == 10)
    }
}

@Suite("Scope conveniences for clients")
struct ScopeConvenienceTests {
    @Test("typed builders produce the canonical scope strings")
    func builders() throws {
        #expect(try ATProtoScope.repo(collections: ["app.bsky.feed.post"]).scopeString == "repo:app.bsky.feed.post")
        #expect(try ATProtoScope.repo(collections: ["app.bsky.feed.post"], actions: [.create]).scopeString
            == "repo:app.bsky.feed.post?action=create")
        #expect(try ATProtoScope.repo(collections: ["*"], actions: [.delete]).scopeString == "repo:*?action=delete")
        #expect(try ATProtoScope.rpc(lxm: ["app.bsky.feed.getFeed"], aud: "did:web:api.example.com#svc").scopeString
            == "rpc:app.bsky.feed.getFeed?aud=did:web:api.example.com%23svc")
        #expect(try ATProtoScope.blob(accept: ["image/*", "video/mp4"]).scopeString == "blob?accept=image/*&accept=video/mp4")
        #expect(try ATProtoScope.account(attribute: .email).scopeString == "account:email")
        #expect(try ATProtoScope.account(attribute: .repo, action: .manage).scopeString == "account:repo?action=manage")
        #expect(try ATProtoScope.identity(attribute: .handle).scopeString == "identity:handle")
        #expect(try ATProtoScope.include(nsid: "app.example.authBasic", aud: "did:web:api.example.com#svc").scopeString
            == "include:app.example.authBasic?aud=did:web:api.example.com%23svc")
        #expect(try ATProtoScope("atproto") == .atproto)
    }

    @Test("builders refuse what the parser refuses")
    func builderValidation() {
        #expect(throws: ScopeParseError.self) { _ = try ATProtoScope.repo(collections: ["not an nsid"]) }
        #expect(throws: ScopeParseError.self) { _ = try ATProtoScope.repo(collections: ["com.example.*"]) }
        #expect(throws: ScopeParseError.self) { _ = try ATProtoScope.repo(collections: []) }
        #expect(throws: ScopeParseError.self) { _ = try ATProtoScope.rpc(lxm: ["*"], aud: "*") }
        #expect(throws: ScopeParseError.self) { _ = try ATProtoScope.rpc(lxm: ["app.example.get"], aud: "did:web:no-fragment.example") }
        #expect(throws: ScopeParseError.self) { _ = try ATProtoScope.blob(accept: ["image"]) }
        #expect(throws: ScopeParseError.self) { _ = try ATProtoScope.include(nsid: "nope") }
    }

    @Test("sets: array literal, strict and lenient parsing, scope strings")
    func sets() throws {
        let literal: ATProtoScopeSet = try [.atproto, .repo(collections: ["app.bsky.feed.post"], actions: [.create])]
        #expect(literal.includesAtproto)
        #expect(literal.scopeString == "atproto repo:app.bsky.feed.post?action=create")
        #expect(literal.scopes.count == 2)

        let lenient = ATProtoScopeSet(scope: "atproto future:thing repo?collection=app.bsky.feed.post&action=create")
        #expect(lenient.unrecognized == ["future:thing"])
        #expect(lenient.scopeString == "atproto future:thing repo?collection=app.bsky.feed.post&action=create")
        #expect(lenient.normalizedScopeString == "atproto future:thing repo:app.bsky.feed.post?action=create")
        #expect(throws: ScopeParseError.self) { _ = try ATProtoScopeSet(strict: "atproto future:thing") }
        #expect(try ATProtoScopeSet(strict: "atproto transition:generic").unrecognized.isEmpty)
        // The two names are one type.
        let alias: ScopePermissions = lenient
        #expect(alias == lenient)
    }

    @Test("covers: concrete needs, wildcard needs, and transition scopes")
    func covers() throws {
        let granted = ATProtoScopeSet(scope:
            "atproto repo:app.bsky.feed.post repo:app.bsky.feed.like?action=create "
                + "rpc:app.bsky.feed.getFeed?aud=did:web:api.example.com%23svc blob:image/* account:email")
        #expect(granted.covers(.atproto))
        #expect(try granted.covers(.repo(collections: ["app.bsky.feed.post"], actions: [.create, .delete])))
        #expect(try granted.covers(.repo(collections: ["app.bsky.feed.like"], actions: [.create])))
        #expect(try !granted.covers(.repo(collections: ["app.bsky.feed.like"], actions: [.delete])))
        #expect(try !granted.covers(.repo(collections: ["app.bsky.feed.post", "app.bsky.graph.follow"])))
        #expect(try !granted.covers(.repo(collections: ["*"])), "a wildcard need is not met by concrete grants")
        #expect(try granted.covers(.rpc(lxm: ["app.bsky.feed.getFeed"], aud: "did:web:api.example.com#svc")))
        #expect(try !granted.covers(.rpc(lxm: ["app.bsky.feed.getFeed"], aud: "did:web:other.example.com#svc")))
        #expect(try !granted.covers(.rpc(lxm: ["app.bsky.feed.getFeed"], aud: "*")))
        #expect(try granted.covers(.blob(accept: ["image/png"])))
        #expect(try granted.covers(.blob(accept: ["image/*"])))
        #expect(try !granted.covers(.blob(accept: ["*/*"])))
        #expect(try granted.covers(.account(attribute: .email)))
        #expect(try !granted.covers(.account(attribute: .email, action: .manage)))
        #expect(try !granted.covers(.identity(attribute: .handle)))
        #expect(try !granted.covers(.include(nsid: "app.example.authBasic")))

        let wide = ATProtoScopeSet(scope: "atproto repo:* rpc:*?aud=did:web:api.example.com%23svc blob:*/* identity:*")
        #expect(try wide.covers(.repo(collections: ["*"], actions: [.delete])))
        #expect(try wide.covers(.rpc(lxm: ["*"], aud: "did:web:api.example.com#svc")))
        #expect(try wide.covers(.blob(accept: ["*/*"])))
        #expect(try wide.covers(.identity(attribute: .handle)))
        #expect(wide.covers(granted) == false, "account:email is not in the wide set")

        let legacy = ATProtoScopeSet(scope: "atproto transition:generic")
        #expect(try legacy.covers(.repo(collections: ["*"])))
        #expect(try legacy.covers(.blob(accept: ["*/*"])))
        #expect(try legacy.covers(.rpc(lxm: ["app.bsky.feed.getFeed"], aud: "did:web:api.example.com#svc")))
        #expect(try !legacy.covers(.rpc(lxm: ["chat.bsky.convo.getConvo"], aud: "did:web:api.bsky.chat#bsky_chat")))
        #expect(try !legacy.covers(.account(attribute: .email)))
        #expect(legacy.covers(ATProtoScopeSet(scope: "atproto transition:generic")))
        #expect(!legacy.covers(ATProtoScopeSet(scope: "atproto transition:email")))
    }

    @Test("expansion reports why each ignored entry was dropped, and grants what expand grants")
    func expansionReasons() throws {
        guard case let .include(include) = try ATProtoScope.include(nsid: "app.example.authBasic") else {
            Issue.record("not an include")
            return
        }
        let set = LexiconPermissionSet(permissions: [
            LexiconPermission(type: "permission", resource: "repo", fields: ["collection": .list([.string("app.example.post")])]),
            LexiconPermission(type: "permission", resource: "blob", fields: ["accept": .list([.string("*/*")])]),
            LexiconPermission(type: "permission", resource: "repo", fields: ["collection": .list([.string("com.other.thing")])]),
            LexiconPermission(type: "permission", resource: "repo", fields: ["collection": .list([.string("app.example.x")]), "extra": .string("y")]),
            LexiconPermission(type: "permission", resource: "rpc", fields: ["lxm": .list([.string("app.example.get")]), "aud": .string("did:web:a.example#s")]),
        ])
        let (permissions, rejections) = include.expansion(of: set)
        #expect(permissions == include.expand(set))
        #expect(permissions.count == 1)
        #expect(rejections.map(\.index) == [1, 2, 3, 4])
        #expect(rejections.map(\.reason) == [
            .notAllowedInPermissionSet, .outsideNamespaceAuthority, .invalidPermission, .notAllowedInPermissionSet,
        ])
    }
}
