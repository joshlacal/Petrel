import PetrelOAuthScopes
import Testing

/// The `ATProtoScope` enum: static scopes, dispatch by resource, builders and
/// canonical forms.
@Suite("Client scope model: ATProtoScope")
struct ClientScopeModelScopeTests {
    // MARK: Static scopes

    @Test("parses the atproto scope")
    func atproto() throws {
        #expect(try ATProtoScope("atproto") == .atproto)
        #expect(try ATProtoScope.parse("atproto") == .atproto)
        #expect(try ATProtoScope.atproto.canonicalScopeString() == "atproto")
        #expect(ATProtoScope.atproto.scopeString == "atproto")
    }

    /// (scope string, value)
    static let transitions: [(String, ATProtoScope)] = [
        ("transition:generic", .transitionGeneric),
        ("transition:chat.bsky", .transitionChatBsky),
        ("transition:email", .transitionEmail),
    ]

    @Test("parses the transitional scopes", arguments: transitions)
    func transition(string: String, expected: ATProtoScope) throws {
        #expect(try ATProtoScope(string) == expected)
        #expect(try expected.canonicalScopeString() == string)
        #expect(ClientScopeModelTestSupport.resource(of: expected) == "transition")
    }

    static let invalidStatic: [(String, ScopeParseError)] = [
        // The static scopes are literals.
        ("atproto:", .unknownPrefix("atproto:")),
        ("atproto:foo", .unknownPrefix("atproto:foo")),
        ("atproto?", .unknownPrefix("atproto?")),
        ("atproto?x=y", .unknownPrefix("atproto?x=y")),
        ("transition", .unknownPrefix("transition")),
        ("transition:", .unknownPrefix("transition:")),
        ("transition:foo", .unknownPrefix("transition:foo")),
        ("transition:Generic", .unknownPrefix("transition:Generic")),
        ("transition:generic?", .unknownPrefix("transition:generic?")),
        ("transition:generic?x=1", .unknownPrefix("transition:generic?x=1")),
        ("transition:chat.bsky.convo", .unknownPrefix("transition:chat.bsky.convo")),
        ("transition:chat", .unknownPrefix("transition:chat")),
        ("transition?name=generic", .unknownPrefix("transition?name=generic")),
        ("transition:%67eneric", .unknownPrefix("transition:%67eneric")),
        // Scope names are case-sensitive.
        ("ATPROTO", .unknownPrefix("ATPROTO")),
        ("Atproto", .unknownPrefix("Atproto")),
        ("atproto2", .unknownPrefix("atproto2")),
        ("Transition:generic", .unknownPrefix("Transition:generic")),
        // Scopes of other OAuth profiles.
        ("openid", .unknownPrefix("openid")),
        ("profile", .unknownPrefix("profile")),
        ("email", .unknownPrefix("email")),
        ("offline_access", .unknownPrefix("offline_access")),
        ("https://example.com/scope", .unknownPrefix("https://example.com/scope")),
        (":foo", .unknownPrefix(":foo")),
        ("?x=y", .unknownPrefix("?x=y")),
    ]

    @Test("rejects malformed static scopes and unknown resources", arguments: invalidStatic)
    func rejectsStatic(string: String, error: ScopeParseError) {
        #expect(throws: error) { try ATProtoScope(string) }
    }

    // MARK: Dispatch

    @Test("dispatches on the resource name")
    func dispatch() throws {
        guard case let .repo(repo) = try ATProtoScope("repo:com.example.foo?action=create") else {
            Issue.record("not a repo scope")
            return
        }
        #expect(repo.collection == [.nsid("com.example.foo")])
        #expect(repo.action == [.create])

        guard case let .rpc(rpc) = try ATProtoScope("rpc:com.example.method?aud=did:web:example.com%23svc") else {
            Issue.record("not an rpc scope")
            return
        }
        #expect(rpc.lxm == [.nsid("com.example.method")])
        #expect(rpc.aud == .service("did:web:example.com#svc"))

        guard case let .blob(blob) = try ATProtoScope("blob:image/*") else {
            Issue.record("not a blob scope")
            return
        }
        #expect(blob.accept == [.type("image")])

        guard case let .account(account) = try ATProtoScope("account:email?action=manage") else {
            Issue.record("not an account scope")
            return
        }
        #expect(account.attr == .email)
        #expect(account.action == [.manage])

        guard case let .identity(identity) = try ATProtoScope("identity:handle") else {
            Issue.record("not an identity scope")
            return
        }
        #expect(identity.attr == .handle)

        guard case let .include(include) = try ATProtoScope("include:com.example.auth?aud=did:web:example.com%23svc") else {
            Issue.record("not an include scope")
            return
        }
        #expect(include.nsid == "com.example.auth")
        #expect(include.aud == .service("did:web:example.com#svc"))
    }

    /// (scope string, resource name)
    static let resources: [(String, String)] = [
        ("atproto", "atproto"),
        ("transition:email", "transition"),
        ("repo:*", "repo"),
        ("rpc:com.example.method?aud=*", "rpc"),
        ("blob:*/*", "blob"),
        ("account:email", "account"),
        ("identity:*", "identity"),
        ("include:com.example.auth", "include"),
    ]

    @Test("parses to the case of its resource", arguments: resources)
    func resource(string: String, expected: String) throws {
        #expect(try ClientScopeModelTestSupport.resource(of: ATProtoScope(string)) == expected)
    }

    @Test("a resource parser refuses the scopes of every other resource", arguments: resources)
    func resourceParsersAreExclusive(string: String, resource: String) {
        let mismatch = { (expected: String) in
            ScopeParseError.prefixMismatch(expected: expected, actual: string)
        }
        if resource != "repo" {
            #expect(throws: mismatch("repo")) { try RepoPermission.parse(string) }
        }
        if resource != "rpc" {
            #expect(throws: mismatch("rpc")) { try RpcPermission.parse(string) }
        }
        if resource != "blob" {
            #expect(throws: mismatch("blob")) { try BlobPermission.parse(string) }
        }
        if resource != "account" {
            #expect(throws: mismatch("account")) { try AccountPermission.parse(string) }
        }
        if resource != "identity" {
            #expect(throws: mismatch("identity")) { try IdentityPermission.parse(string) }
        }
        if resource != "include" {
            #expect(throws: mismatch("include")) { try IncludeScope.parse(string) }
        }
    }

    // MARK: Builders

    @Test("builders produce the canonical scope")
    func builders() throws {
        #expect(
            try ATProtoScope.repo(collections: ["app.bsky.feed.post", "app.bsky.feed.like"], actions: [.create, .delete]).scopeString
                == "repo?collection=app.bsky.feed.like&collection=app.bsky.feed.post&action=create&action=delete"
        )
        #expect(try ATProtoScope.repo(collections: ["*"]).scopeString == "repo:*")
        #expect(
            try ATProtoScope.rpc(lxm: ["app.bsky.feed.getTimeline"], aud: "did:web:api.bsky.app#bsky_appview").scopeString
                == "rpc:app.bsky.feed.getTimeline?aud=did:web:api.bsky.app%23bsky_appview"
        )
        #expect(try ATProtoScope.blob(accept: ["image/*", "video/mp4"]).scopeString == "blob?accept=image/*&accept=video/mp4")
        #expect(try ATProtoScope.account(attribute: .email).scopeString == "account:email")
        #expect(try ATProtoScope.account(attribute: .repo, action: .manage).scopeString == "account:repo?action=manage")
        #expect(try ATProtoScope.identity(attribute: .any).scopeString == "identity:*")
        #expect(
            try ATProtoScope.include(nsid: "app.bsky.authFull", aud: "did:web:api.bsky.app#bsky_appview").scopeString
                == "include:app.bsky.authFull?aud=did:web:api.bsky.app%23bsky_appview"
        )
    }

    // MARK: Canonical form

    @Test("the canonical form is a fixed point", arguments: ClientScopeModelTestSupport.validScopes)
    func roundTrip(input: String, canonical: String) throws {
        let scope = try ATProtoScope(input)
        #expect(try scope.canonicalScopeString() == canonical)

        let reparsed = try ATProtoScope(canonical)
        #expect(try reparsed.canonicalScopeString() == canonical)
        #expect(ClientScopeModelTestSupport.resource(of: reparsed) == ClientScopeModelTestSupport.resource(of: scope))
    }

    @Test("the round-trip corpus covers every kind of scope")
    func roundTripCorpusIsComplete() throws {
        let resources = try Set(ClientScopeModelTestSupport.validScopes.map {
            try ClientScopeModelTestSupport.resource(of: ATProtoScope($0.0))
        })
        #expect(resources == ["atproto", "transition", "repo", "rpc", "blob", "account", "identity", "include"])
        #expect(ClientScopeModelTestSupport.validScopes.count > 80)
    }

    @Test("equal access has equal canonical forms, different access does not")
    func canonicalEquality() throws {
        let canonical = ClientScopeModelTestSupport.canonical
        #expect(try canonical("repo?collection=com.example.b&collection=com.example.a") == canonical("repo?collection=com.example.a&collection=com.example.b"))
        #expect(try canonical("repo:com.example.a?action=delete&action=create") == canonical("repo:com.example.a?action=create&action=delete"))
        #expect(try canonical("repo:com.example.a") != canonical("repo:com.example.a?action=create"))
        #expect(try canonical("rpc:com.example.a?aud=*") != canonical("rpc:com.example.a?aud=did:web:example.com%23svc"))
        #expect(try canonical("account:email") != canonical("account:email?action=manage"))
        #expect(try canonical("include:com.example.auth") != canonical("include:com.example.auth?aud=did:web:example.com%23svc"))
        #expect(ATProtoScope.atproto != .transitionGeneric)
    }

    // MARK: Reference parity

    /// The ten scope strings where the reference implementation and a literal
    /// reading of the specification answer differently (`ReferenceParity.md`).
    /// This module follows the reference implementation in each.
    /// (input, canonical form)
    static let parityAccepted: [(String, String)] = [
        // `action` may be repeated.
        ("account:email?action=manage&action=read", "account:email?action=manage&action=read"),
        ("account:email?action=read&action=manage", "account:email?action=read&action=manage"),
        ("account:email?action=read&action=read", "account:email"),
        // An escaped "+" or "%" of a parameter value is written back bare.
        (
            "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2Bb",
            "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a+b"
        ),
        ("blob?accept=image/svg%2Bxml&accept=image/png", "blob?accept=image/png&accept=image/svg+xml"),
        (
            "rpc:app.bsky.feed.getFeed?aud=did:web:localhost%253A8080%23svc",
            "rpc:app.bsky.feed.getFeed?aud=did:web:localhost%3A8080%23svc"
        ),
        (
            "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2541",
            "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%41"
        ),
        // A repeated value stays in the named form.
        ("blob?accept=image/png&accept=image/png", "blob?accept=image/png"),
    ]

    @Test("reference parity: accepted, with the reference canonical form", arguments: parityAccepted)
    func parityAccepts(input: String, canonical: String) throws {
        let scope = try ATProtoScope(input)
        #expect(try scope.canonicalScopeString() == canonical)
        // `scopeString` is the form that reads back to the same access.
        let readable = try #require(scope.scopeString)
        #expect(ATProtoScopeSet(scope: readable).covers(scope))
        #expect(try ATProtoScopeSet([scope]).covers(ATProtoScope(readable)))
    }

    /// "+" in a parameter value is a space.
    static let parityRejected: [(String, ScopeParseError)] = [
        (
            "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a+b",
            .invalidParameterValue(prefix: "rpc", key: "aud", value: "did:web:example.com#a b")
        ),
        (
            "blob?accept=image/svg+xml",
            .invalidParameterValue(prefix: "blob", key: "accept", value: "image/svg xml")
        ),
    ]

    @Test("reference parity: rejected", arguments: parityRejected)
    func parityRejects(input: String, error: ScopeParseError) {
        #expect(throws: error) { try ATProtoScope(input) }
        #expect(ATProtoScopeSet(scope: input).rejected == [input: error])
    }

    // DIFFERENCE 5: `==` on scopes is structural: it compares the values as
    // written, including their order and whether a parameter was stated or
    // defaulted. Two scopes granting the same access can be unequal; compare
    // canonical strings to ask whether they grant the same access.
    @Test("== compares scopes as written")
    func structuralEquality() throws {
        #expect(try ATProtoScope("repo:com.example.a") == ATProtoScope("repo:com.example.a"))
        #expect(try ATProtoScope("repo?collection=com.example.a") == ATProtoScope("repo:com.example.a"))
        #expect(
            try ATProtoScope("repo?collection=com.example.b&collection=com.example.a")
                != ATProtoScope("repo?collection=com.example.a&collection=com.example.b")
        )
        #expect(
            try ATProtoScope("repo:com.example.a?action=create&action=update&action=delete")
                != ATProtoScope("repo:com.example.a")
        )
        #expect(try ATProtoScope("blob:IMAGE/PNG") != ATProtoScope("blob:image/png"))
        #expect(try ATProtoScope("account:email?action=read") != ATProtoScope("account:email"))
    }
}
