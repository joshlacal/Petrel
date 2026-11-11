import Foundation
import PetrelOAuthScopes
import Testing

/// A scope set built from typed scopes, a scope string, and `covers` must all
/// tell the same story as the matchers.
@Suite("Scope sets: typed construction, scope strings and covers agree with the matchers")
struct ScopeSetConsistencyTests {
    // MARK: - Typed scopes are kept, not re-parsed

    @Test("a typed blob permission with `+` in a media type survives set construction")
    func typedBlobWithPlus() throws {
        let scope = try ATProtoScope.blob(accept: ["image/png", "image/svg+xml"])
        // The reference-compatible canonical form does not parse back…
        #expect(try scope.canonicalScopeString() == "blob?accept=image/png&accept=image/svg+xml")
        #expect(throws: ScopeParseError.self) { _ = try ATProtoScope.parse("blob?accept=image/png&accept=image/svg+xml") }

        // …so the set keeps the typed permission and serialises it parseably.
        let set = ATProtoScopeSet([.atproto, scope])
        #expect(set.rejected.isEmpty)
        #expect(set.scopes.count == 2)
        #expect(set.allowsBlob(.init(mime: "image/svg+xml")))
        #expect(set.allowsBlob(.init(mime: "image/png")))
        #expect(!set.allowsBlob(.init(mime: "image/gif")))
        #expect(set.scopeString == "atproto blob?accept=image/png&accept=image/svg%2Bxml")

        // What is sent to a server parses back to the same grant.
        let received = ATProtoScopeSet(scope: set.scopeString)
        #expect(received == set)
        #expect(received.rejected.isEmpty)
        #expect(received.allowsBlob(.init(mime: "image/svg+xml")))
        #expect(received.normalizedScopeString == set.scopeString)
    }

    @Test("a typed rpc audience containing `%` is not rewritten into another audience")
    func typedAudienceWithPercent() throws {
        let audience = "did:web:example.com#a%41"
        let scope = try ATProtoScope.rpc(lxm: ["app.bsky.feed.getFeed"], aud: audience)
        // Canonical form, as the reference writes it: `%41` would decode to `A`.
        #expect(try scope.canonicalScopeString() == "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%41")
        #expect(scope.scopeString == "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2541")

        let set = ATProtoScopeSet([scope])
        #expect(set.rejected.isEmpty)
        #expect(set.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: audience)))
        #expect(!set.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com#aA")))

        let received = ATProtoScopeSet(scope: set.scopeString)
        #expect(received.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: audience)))
        #expect(!received.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:example.com#aA")))
    }

    @Test("ordinary scopes still serialise to their canonical form")
    func ordinaryScopesAreCanonical() throws {
        let scopes: [ATProtoScope] = try [
            .atproto, .transitionGeneric,
            .repo(collections: ["app.bsky.feed.post"], actions: [.create]),
            .rpc(lxm: ["app.bsky.feed.getFeed"], aud: "did:web:api.example.com#svc"),
            .blob(accept: ["image/svg+xml"]), // positional: `+` is literal
            .account(attribute: .email, action: .manage),
            .identity(attribute: .handle),
            .include(nsid: "app.example.authBasic", aud: "did:web:api.example.com#svc"),
        ]
        for scope in scopes {
            #expect(scope.scopeString == (try scope.canonicalScopeString()))
        }
        #expect(ATProtoScopeSet(scopes).scopes.count == scopes.count)
        #expect(ATProtoScopeSet(scopes) == ATProtoScopeSet(scope: ATProtoScopeSet(scopes).scopeString))
    }

    @Test("a value the parser would refuse grants nothing and is reported, not dropped")
    func unserialisableValue() throws {
        // Assembled past the builders: every method on every service.
        let everything = ATProtoScope.rpc(RpcPermission(aud: .any, lxm: [.any]))
        #expect(everything.scopeString == nil)
        #expect(throws: ScopeParseError.self) { _ = try ATProtoScope.rpc(lxm: ["*"], aud: "*") }

        let set = ATProtoScopeSet([.atproto, everything])
        #expect(set.scopes.count == 1)
        #expect(set.unrecognized == ["rpc:*?aud=*"])
        #expect(set.rejected["rpc:*?aud=*"] != nil)
        #expect(!set.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:api.example.com#svc")))
        // The string a server would be sent still carries it, so the request fails loudly.
        #expect(set.scopeString == "atproto rpc:*?aud=*")
        #expect(ATProtoScopeSet(scope: set.scopeString) == set)
    }

    @Test("duplicates and equivalent spellings collapse")
    func duplicates() throws {
        let post = try ATProtoScope.repo(collections: ["app.bsky.feed.post"])
        let spelledOut = try ATProtoScope.parse("repo?collection=app.bsky.feed.post&action=create&action=update&action=delete")
        let set = ATProtoScopeSet([post, spelledOut, post])
        #expect(set.scopes.count == 1)
        #expect(set.scopeString == "repo:app.bsky.feed.post")
    }

    // MARK: - Media type case

    @Test("media types are compared without regard to case, in the matcher and in covers alike")
    func mimeCase() throws {
        let upper = ATProtoScopeSet(scope: "atproto blob:IMAGE/PNG")
        #expect(upper.rejected.isEmpty)
        #expect(upper.normalizedScopeString == "atproto blob:image/png")
        // The matcher and covers give the same answer.
        #expect(upper.allowsBlob(.init(mime: "image/png")))
        #expect(upper.allowsBlob(.init(mime: "IMAGE/PNG")))
        #expect(upper.allowsBlob(.init(mime: "Image/Png")))
        #expect(try upper.covers(.blob(accept: ["image/png"])))
        #expect(try upper.covers(.blob(accept: ["IMAGE/PNG"])))
        #expect(!upper.allowsBlob(.init(mime: "image/gif")))
        #expect(try !upper.covers(.blob(accept: ["image/gif"])))

        // Canonicalising a permission never changes what it matches.
        for spelling in ["blob:IMAGE/PNG", "blob:image/png", "blob:Image/*", "blob?accept=VIDEO/MP4&accept=text/html"] {
            let original = ATProtoScopeSet(scope: spelling)
            let canonical = ATProtoScopeSet(scope: original.normalizedScopeString)
            for mime in ["image/png", "IMAGE/PNG", "image/gif", "video/mp4", "Video/MP4", "text/html", "text/plain"] {
                #expect(original.allowsBlob(.init(mime: mime)) == canonical.allowsBlob(.init(mime: mime)), "\(spelling) vs \(mime)")
            }
        }
        // A type wildcard, any case.
        #expect(ATProtoScopeSet(scope: "blob:IMAGE/*").allowsBlob(.init(mime: "image/webp")))
        #expect(try ATProtoScopeSet(scope: "blob:IMAGE/*").covers(.blob(accept: ["image/*"])))
    }

    @Test("covers is decided by what a scope grants, not by how it is spelled")
    func coversIsNotSpelling() throws {
        // Same canonical string as the grant, and genuinely the same grant.
        let grant = ATProtoScopeSet(scope: "atproto repo?collection=app.bsky.feed.post&action=create")
        #expect(try grant.covers(.repo(collections: ["app.bsky.feed.post"], actions: [.create])))
        #expect(try !grant.covers(.repo(collections: ["app.bsky.feed.post"], actions: [.create, .delete])))

        // An include is covered only by the same include, however it was written.
        let included = ATProtoScopeSet(scope: "atproto include:app.example.authBasic?aud=did:web:api.example.com%23svc")
        #expect(try included.covers(.include(nsid: "app.example.authBasic", aud: "did:web:api.example.com#svc")))
        #expect(try !included.covers(.include(nsid: "app.example.authBasic")))
        #expect(try !included.covers(.include(nsid: "app.example.authOther", aud: "did:web:api.example.com#svc")))
        #expect(try !ATProtoScopeSet(scope: "atproto transition:generic").covers(.include(nsid: "app.example.authBasic")))
    }

    // MARK: - Transition scopes and wildcard audiences

    @Test("transition scopes cover a method on any service, as allowsRPC does")
    func transitionCoversAnyAudience() throws {
        let generic = ATProtoScopeSet(scope: "atproto transition:generic")
        #expect(generic.allowsRPC(.init(lxm: "app.bsky.feed.getFeed", aud: "did:web:anything.example#svc")))
        #expect(try generic.covers(.rpc(lxm: ["app.bsky.feed.getFeed"], aud: "*")))
        #expect(try generic.covers(.rpc(lxm: ["app.bsky.feed.getFeed", "com.example.other.method"], aud: "*")))
        // Chat is the one thing transition:generic does not reach.
        #expect(try !generic.covers(.rpc(lxm: ["chat.bsky.convo.getConvo"], aud: "*")))
        #expect(try !generic.covers(.rpc(lxm: ["app.bsky.feed.getFeed", "chat.bsky.convo.getConvo"], aud: "*")))
        // Every method on one service includes chat methods.
        #expect(try !generic.covers(.rpc(lxm: ["*"], aud: "did:web:api.example.com#svc")))

        let chat = ATProtoScopeSet(scope: "atproto transition:chat.bsky")
        #expect(chat.allowsRPC(.init(lxm: "chat.bsky.convo.getConvo", aud: "did:web:api.bsky.chat#bsky_chat")))
        #expect(try chat.covers(.rpc(lxm: ["chat.bsky.convo.getConvo"], aud: "*")))
        #expect(try chat.covers(.rpc(lxm: ["chat.bsky.convo.getConvo"], aud: "did:web:api.bsky.chat#bsky_chat")))
        #expect(try !chat.covers(.rpc(lxm: ["app.bsky.feed.getFeed"], aud: "*")))
        #expect(try !chat.covers(.rpc(lxm: ["*"], aud: "did:web:api.bsky.chat#bsky_chat")))

        let both = ATProtoScopeSet(scope: "atproto transition:generic transition:chat.bsky")
        #expect(try both.covers(.rpc(lxm: ["app.bsky.feed.getFeed", "chat.bsky.convo.getConvo"], aud: "*")))
        #expect(try both.covers(.rpc(lxm: ["*"], aud: "did:web:api.example.com#svc")))

        // Without a transition scope a wildcard audience needs a wildcard-audience grant.
        let narrow = ATProtoScopeSet(scope: "atproto rpc:app.bsky.feed.getFeed?aud=did:web:api.example.com%23svc")
        #expect(try !narrow.covers(.rpc(lxm: ["app.bsky.feed.getFeed"], aud: "*")))
        let anyAudience = ATProtoScopeSet(scope: "atproto rpc:app.bsky.feed.getFeed?aud=*")
        #expect(try anyAudience.covers(.rpc(lxm: ["app.bsky.feed.getFeed"], aud: "*")))
        #expect(try anyAudience.covers(.rpc(lxm: ["app.bsky.feed.getFeed"], aud: "did:web:api.example.com#svc")))
    }

    // MARK: - The property

    /// Every scope string the reference implementation accepts, less the few
    /// Petrel deliberately rejects (`UpstreamScopeDivergence`).
    private static func referenceScopes(_ corpus: UpstreamScopeCorpus) -> [String] {
        corpus.values
            .filter { $0.isAtprotoOauthScope == true && (try? ATProtoScope.parse($0.input)) != nil }
            .map(\.input)
    }

    /// Scope sets a need is checked against: every valid scope of the
    /// reference corpus on its own, each transition scope, and combinations.
    private static func grantSets(_ corpus: UpstreamScopeCorpus) -> [ATProtoScopeSet] {
        var sets = referenceScopes(corpus).map { ATProtoScopeSet(scope: "atproto \($0)") }
        sets += [
            "atproto", "atproto transition:generic", "atproto transition:chat.bsky", "atproto transition:email",
            "atproto transition:generic transition:chat.bsky transition:email",
            "atproto repo:* blob:*/* identity:* rpc:*?aud=did:web:api.example.com%23svc",
            "atproto rpc:app.bsky.feed.getFeed?aud=* rpc:chat.bsky.convo.getConvo?aud=*",
        ].map(ATProtoScopeSet.init(scope:))
        return sets
    }

    /// What `needed` asks for, as targets for the matchers: its concrete
    /// values as they are, and each wildcard replaced by several things it
    /// stands for.
    private static func targets(of needed: ATProtoScope) -> (concrete: Bool, allowed: (ATProtoScopeSet) -> Bool)? {
        let sampleCollections = ["app.bsky.feed.post", "com.example.sample.record"]
        let sampleMethods = ["app.bsky.feed.getFeed", "chat.bsky.convo.getConvo", "com.example.sample.method"]
        let sampleAudiences = ["did:web:api.example.com#svc", "did:web:sample.example#other"]
        switch needed {
        case let .repo(permission):
            let concrete = !permission.collection.contains(.any)
            let collections = permission.collection.flatMap { $0 == .any ? sampleCollections : [$0.stringValue] }
            return (concrete, { set in
                permission.action.allSatisfy { action in
                    collections.allSatisfy { set.allowsRepo(.init(collection: $0, action: action)) }
                }
            })
        case let .rpc(permission):
            let concrete = !permission.lxm.contains(.any) && permission.aud != .any
            let methods = permission.lxm.flatMap { $0 == .any ? sampleMethods : [$0.stringValue] }
            let audiences = permission.aud == .any ? sampleAudiences : [permission.aud.stringValue]
            return (concrete, { set in
                methods.allSatisfy { method in audiences.allSatisfy { set.allowsRPC(.init(lxm: method, aud: $0)) } }
            })
        case let .blob(permission):
            let concrete = permission.accept.allSatisfy { if case .exact = $0 { true } else { false } }
            let mimes = permission.accept.flatMap { pattern -> [String] in
                switch pattern {
                case .any: ["image/png", "video/mp4", "application/x-sample"]
                case let .type(type): ["\(type)/png", "\(type)/x-sample"]
                case let .exact(type, subtype): ["\(type)/\(subtype)"]
                }
            }
            return (concrete, { set in mimes.allSatisfy { set.allowsBlob(.init(mime: $0)) } })
        case let .account(permission):
            return (true, { set in
                permission.action.allSatisfy { set.allowsAccount(.init(attr: permission.attr, action: $0)) }
            })
        case let .identity(permission):
            let attributes = permission.attr == .any ? IdentityAttribute.allCases : [permission.attr]
            return (permission.attr != .any, { set in attributes.allSatisfy { set.allowsIdentity(.init(attr: $0)) } })
        case .atproto, .transitionGeneric, .transitionEmail, .transitionChatBsky, .include:
            return nil
        }
    }

    @Test("for every scope of the reference corpus, covers agrees with the matchers")
    func coversAgreesWithMatchers() throws {
        let corpus = try UpstreamScopeCorpus.load()
        let needs = try Self.referenceScopes(corpus).map { try ATProtoScope.parse($0) }
            + Self.clientCorpus.map { try ATProtoScope.parse($0) }
        let sets = Self.grantSets(corpus)
        var checkedConcrete = 0, checkedWildcard = 0, covered = 0

        for needed in needs {
            guard let (concrete, allowed) = Self.targets(of: needed) else { continue }
            for set in sets {
                let covers = set.covers(needed)
                if covers { covered += 1 }
                if concrete {
                    // Exact: covers ⇔ every target the scope names is allowed.
                    #expect(covers == allowed(set), "\(String(describing: needed.scopeString)) against \(set.scopeString)")
                    checkedConcrete += 1
                } else if covers {
                    // Sound: whatever the wildcard stands for is allowed.
                    #expect(allowed(set), "\(String(describing: needed.scopeString)) against \(set.scopeString)")
                    checkedWildcard += 1
                }
            }
        }
        // The property was actually exercised, in both directions.
        #expect(checkedConcrete > 5000)
        #expect(checkedWildcard > 50)
        #expect(covered > 300)
    }

    @Test("for every scope of the reference corpus, scopeString parses back to the same scope")
    func scopeStringRoundTrips() throws {
        let corpus = try UpstreamScopeCorpus.load()
        let inputs = Self.referenceScopes(corpus) + Self.clientCorpus
        var escaped = 0
        for input in inputs {
            let scope = try ATProtoScope.parse(input)
            let canonical = try scope.canonicalScopeString()
            guard let string = scope.scopeString else {
                Issue.record("\(input) has no scope string (canonical \(canonical))")
                continue
            }
            if string != canonical { escaped += 1 }
            // Read back, it is the same grant: each covers the other.
            let readBack = try ATProtoScope.parse(string)
            #expect(ATProtoScopeSet([scope]).covers(readBack), "\(input) → \(string)")
            #expect(ATProtoScopeSet([readBack]).covers(scope), "\(input) → \(string)")
            // A set built from the typed scope and one parsed from its string grant alike.
            let typed = ATProtoScopeSet([scope])
            #expect(typed.rejected.isEmpty, "\(input)")
            #expect(typed.scopes.count == 1, "\(input)")
            #expect(ATProtoScopeSet(scope: typed.scopeString).rejected.isEmpty, "\(input)")
        }
        // The corpus contains values whose canonical form is not their scope string.
        #expect(escaped >= 3)
    }

    /// Scopes a client is likely to build, beyond the reference corpus.
    private static let clientCorpus = [
        "repo:app.bsky.feed.post", "repo:app.bsky.feed.post?action=create", "repo:*?action=delete",
        "repo?collection=app.bsky.feed.post&collection=app.bsky.feed.like&action=create&action=delete",
        "rpc:app.bsky.feed.getFeed?aud=did:web:api.example.com%23svc", "rpc:app.bsky.feed.getFeed?aud=*",
        "rpc:chat.bsky.convo.getConvo?aud=did:web:api.bsky.chat%23bsky_chat", "rpc:chat.bsky.convo.getConvo?aud=*",
        "rpc:*?aud=did:web:api.example.com%23svc",
        "rpc?lxm=app.bsky.feed.getFeed&lxm=chat.bsky.convo.getConvo&aud=*",
        "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2541",
        "blob:*/*", "blob:image/*", "blob:image/png", "blob:IMAGE/PNG", "blob:image/svg+xml",
        "blob?accept=image/png&accept=image/svg%2Bxml", "blob?accept=video/*&accept=text/html",
        "account:email", "account:email?action=manage", "account:repo?action=manage", "account:status",
        "identity:handle", "identity:*",
    ]
}
