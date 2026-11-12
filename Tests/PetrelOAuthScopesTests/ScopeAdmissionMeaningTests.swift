import Foundation
import PetrelOAuthScopes
import Testing

/// Decisions about scopes are made on what the scopes grant, never on how
/// they are spelled: not on canonical strings, which can coincide for
/// different grants, and not on `String` equality.
@Suite("Scope admission and identity are decided by meaning")
struct ScopeAdmissionMeaningTests {
    // MARK: - The reported case

    @Test("two audiences with one canonical string are not one declared scope")
    func canonicalCollisionIsNotAdmitted() throws {
        let declared = "rpc:com.example.method?aud=did:web:example.com%23svc%26admin"
        let requested = "rpc:com.example.method?aud=did:web:example.com%23svc%2526admin"

        // The premise: different services, one canonical string.
        let declaredScope = try RpcPermission.parse(declared)
        let requestedScope = try RpcPermission.parse(requested)
        #expect(declaredScope.aud == .service("did:web:example.com#svc&admin"))
        #expect(requestedScope.aud == .service("did:web:example.com#svc%26admin"))
        #expect(try declaredScope.canonicalScopeString() == requestedScope.canonicalScopeString())
        // The declared permission does not allow the requested audience.
        #expect(!declaredScope.matches(.init(lxm: "com.example.method", aud: "did:web:example.com#svc%26admin")))

        #expect(throws: OAuthScopeAdmissionError.notRegistered) {
            _ = try OAuthScopeAdmissionPolicy.admit(requested: ["atproto", requested], declaredBy: ["atproto", declared])
        }
        #expect(!OAuthScopeAdmissionPolicy.isDeclared([requested], by: [declared]))
        // And the other way round.
        #expect(!OAuthScopeAdmissionPolicy.isDeclared([declared], by: [requested]))
        // Each is of course declared by itself.
        #expect(try OAuthScopeAdmissionPolicy.admit(requested: ["atproto", requested], declaredBy: ["atproto", requested])
            == ["atproto", requested])
    }

    @Test("a different spelling of the same grant is still admitted, as written")
    func spellingsOfOneGrantAreAdmitted() throws {
        let pairs = [
            ("repo:app.bsky.feed.post?action=create", "repo?collection=app.bsky.feed.post&action=create"),
            ("repo:app.bsky.feed.post", "repo:app.bsky.feed.post?action=create&action=update&action=delete"),
            ("repo:*", "repo?collection=*&collection=app.bsky.feed.post"),
            ("blob:image/*", "blob?accept=image/png&accept=image/*"),
            ("blob:image/png", "blob:IMAGE/PNG"),
            ("blob:image/png", "blob?accept=image/png&accept=image/png"),
            ("account:email?action=manage", "account:email?action=read&action=manage"),
            ("rpc:app.bsky.feed.getFeed?aud=did:web:api.example.com%23svc", "rpc?lxm=app.bsky.feed.getFeed&aud=did:web:api.example.com%23svc"),
            ("rpc:*?aud=did:web:api.example.com%23svc", "rpc?lxm=*&lxm=app.bsky.feed.getFeed&aud=did:web:api.example.com%23svc"),
            ("include:app.example.authBasic?aud=did:web:api.example.com%23svc", "include?nsid=app.example.authBasic&aud=did:web:api.example.com%23svc"),
        ]
        for (declared, requested) in pairs {
            #expect(try OAuthScopeAdmissionPolicy.admit(requested: ["atproto", requested], declaredBy: ["atproto", declared])
                == ["atproto", requested], "\(requested) against \(declared)")
            #expect(OAuthScopeAdmissionPolicy.isDeclared([declared], by: [requested]), "\(declared) against \(requested)")
        }
    }

    @Test("a narrower, wider or merely similar scope is not the declared one")
    func differentGrantsAreNotAdmitted() {
        let pairs = [
            ("repo:app.bsky.feed.post", "repo:app.bsky.feed.post?action=create"), // narrower
            ("repo:app.bsky.feed.post?action=create", "repo:app.bsky.feed.post"), // wider
            ("repo:app.bsky.feed.post", "repo:*"),
            ("blob:image/*", "blob:image/png"),
            ("blob:image/png", "blob:image/*"),
            ("account:email", "account:email?action=manage"),
            ("account:email?action=manage", "account:email"),
            ("identity:*", "identity:handle"),
            ("rpc:app.bsky.feed.getFeed?aud=*", "rpc:app.bsky.feed.getFeed?aud=did:web:api.example.com%23svc"),
            ("rpc:app.bsky.feed.getFeed?aud=did:web:api.example.com%23svc", "rpc:app.bsky.feed.getFeed?aud=did:web:api.example.com%23other"),
            ("include:app.example.authBasic", "include:app.example.authBasic?aud=did:web:api.example.com%23svc"),
            ("transition:generic", "repo:app.bsky.feed.post"), // a transition scope is not a declaration of granular ones
            ("transition:generic", "transition:chat.bsky"),
        ]
        for (declared, requested) in pairs {
            #expect(throws: OAuthScopeAdmissionError.notRegistered, "\(requested) against \(declared)") {
                _ = try OAuthScopeAdmissionPolicy.admit(requested: ["atproto", requested], declaredBy: ["atproto", declared])
            }
        }
    }

    @Test("an unparseable scope is declared only by the identical bytes")
    func unparseableScopes() throws {
        #expect(OAuthScopeAdmissionPolicy.isDeclared(["future:thing"], by: ["future:thing"]))
        #expect(!OAuthScopeAdmissionPolicy.isDeclared(["future:thing"], by: ["future:other"]))
        #expect(!OAuthScopeAdmissionPolicy.isDeclared(["future:K"], by: ["future:\u{212A}"]))
        // A declared scope that does not parse vouches for nothing else and
        // does not get in the way of the ones that do.
        #expect(try OAuthScopeAdmissionPolicy.admit(
            requested: ["atproto", "repo:app.bsky.feed.post"],
            declaredBy: ["atproto", "future:thing", "repo:app.bsky.feed.post"]
        ) == ["atproto", "repo:app.bsky.feed.post"])
        // Ignored unknown scopes are dropped from the grant, not admitted.
        #expect(try OAuthScopeAdmissionPolicy.admit(
            requested: ["atproto", "future:thing"], declaredBy: ["atproto"], unknownScopes: .ignore
        ) == ["atproto"])
        #expect(throws: OAuthScopeAdmissionError.self) {
            _ = try OAuthScopeAdmissionPolicy.admit(requested: ["atproto", "future:thing"], declaredBy: ["atproto", "future:thing"])
        }
    }

    // MARK: - The property

    private static let extraScopes = [
        "rpc:com.example.method?aud=did:web:example.com%23svc%26admin",
        "rpc:com.example.method?aud=did:web:example.com%23svc%2526admin",
        "rpc:com.example.method?aud=did:web:example.com%23a%2541",
        "rpc:com.example.method?aud=did:web:example.com%23aA",
        "rpc:com.example.method?aud=did:web:localhost%253A8080%23svc",
        "blob?accept=image/png&accept=image/svg%2Bxml", "blob:image/svg+xml", "blob:IMAGE/PNG",
        "repo:app.bsky.feed.post", "repo:app.bsky.feed.post?action=create", "repo:*?action=delete",
        "rpc:app.bsky.feed.getFeed?aud=*", "rpc:*?aud=did:web:api.example.com%23svc",
        "account:email", "account:email?action=manage", "account:email?action=read&action=manage",
        "identity:handle", "identity:*", "include:app.example.authBasic",
    ]

    /// What `scope` asks for, as concrete requests for the matchers, with each
    /// wildcard replaced by several things it stands for.
    private static func allowed(_ scope: ATProtoScope, by set: ATProtoScopeSet) -> Bool? {
        switch scope {
        case let .repo(permission):
            let collections = permission.collection.flatMap {
                $0 == .any ? ["app.bsky.feed.post", "com.example.sample.record"] : [$0.stringValue]
            }
            return permission.action.allSatisfy { action in
                collections.allSatisfy { set.allowsRepo(.init(collection: $0, action: action)) }
            }
        case let .rpc(permission):
            let methods = permission.lxm.flatMap {
                $0 == .any ? ["app.bsky.feed.getFeed", "chat.bsky.convo.getConvo"] : [$0.stringValue]
            }
            let audiences = permission.aud == .any
                ? ["did:web:api.example.com#svc", "did:web:sample.example#other"] : [permission.aud.stringValue]
            return methods.allSatisfy { method in audiences.allSatisfy { set.allowsRPC(.init(lxm: method, aud: $0)) } }
        case let .blob(permission):
            let mimes = permission.accept.flatMap { pattern -> [String] in
                switch pattern {
                case .any: ["image/png", "video/mp4"]
                case let .type(type): ["\(type)/png", "\(type)/x-sample"]
                case let .exact(type, subtype): ["\(type)/\(subtype)"]
                }
            }
            return mimes.allSatisfy { set.allowsBlob(.init(mime: $0)) }
        case let .account(permission):
            return permission.action.allSatisfy { set.allowsAccount(.init(attr: permission.attr, action: $0)) }
        case let .identity(permission):
            let attributes = permission.attr == .any ? IdentityAttribute.allCases : [permission.attr]
            return attributes.allSatisfy { set.allowsIdentity(.init(attr: $0)) }
        case .atproto, .transitionGeneric, .transitionEmail, .transitionChatBsky, .include:
            return nil
        }
    }

    @Test("for every pair of scopes, admission implies the declared scope allows what the requested one asks for")
    func admissionImpliesCoverage() throws {
        let corpus = try UpstreamScopeCorpus.load()
        let scopes = corpus.values
            .filter { $0.isAtprotoOauthScope == true && (try? ATProtoScope.parse($0.input)) != nil }
            .map(\.input) + Self.extraScopes
        var admittedPairs = 0, admittedDistinctStrings = 0, refused = 0

        for declared in scopes {
            // Only what `declared` itself grants: no base scope, no transition
            // scope standing in.
            let declaredSet = ATProtoScopeSet(rawScopes: [declared])
            for requested in scopes {
                let admitted = OAuthScopeAdmissionPolicy.isDeclared([requested], by: [declared])
                // `admit` agrees with `isDeclared`.
                let viaAdmit = (try? OAuthScopeAdmissionPolicy.admit(
                    requested: ["atproto", requested], declaredBy: ["atproto", declared]
                )) != nil
                #expect(viaAdmit == (admitted || requested == "atproto"), "\(requested) against \(declared)")
                guard admitted else { refused += 1; continue }
                admittedPairs += 1
                if requested != declared { admittedDistinctStrings += 1 }

                let requestedScope = try ATProtoScope.parse(requested)
                // Everything the requested scope asks for, the declared scope allows…
                if let allowed = Self.allowed(requestedScope, by: declaredSet) {
                    #expect(allowed, "\(requested) admitted against \(declared)")
                }
                #expect(declaredSet.covers(requestedScope), "\(requested) admitted against \(declared)")
                // …and admission is symmetric: they are the same grant.
                #expect(ATProtoScopeSet(rawScopes: [requested]).covers(try ATProtoScope.parse(declared)),
                        "\(declared) against \(requested)")
            }
        }
        // The property was exercised: many pairs, including differently
        // spelled ones, and far more refusals than admissions.
        #expect(admittedPairs >= scopes.count)
        #expect(admittedDistinctStrings > 20)
        #expect(refused > admittedPairs * 10)
    }

    // MARK: - Tokenizer

    @Test("the tokenizer's duplicate check is on bytes, and equivalent spellings are not duplicates")
    func tokenizer() throws {
        #expect(throws: OAuthScopeAdmissionError.duplicateScope) {
            _ = try OAuthScopeTokenizer.tokenize("atproto repo:app.bsky.feed.post repo:app.bsky.feed.post")
        }
        // Two spellings of one grant are two tokens.
        #expect(try OAuthScopeTokenizer.tokenize("atproto repo:app.bsky.feed.post repo?collection=app.bsky.feed.post").count == 3)
        // A non-ASCII lookalike is reported as what it is, not as a duplicate of the ASCII token.
        #expect(throws: OAuthScopeAdmissionError.notAScopeToken) {
            _ = try OAuthScopeTokenizer.tokenize("repo:com.example.Key repo:com.example.\u{212A}ey")
        }
        #expect(throws: OAuthScopeAdmissionError.forbiddenScope) { _ = try OAuthScopeTokenizer.tokenize("atproto openid") }
    }

    // MARK: - Set identity

    @Test("scope sets are equal only when they hold the same bytes")
    func setEquality() {
        let ascii = ATProtoScopeSet(rawScopes: ["repo:com.example.Key"])
        let kelvin = ATProtoScopeSet(rawScopes: ["repo:com.example.\u{212A}ey"])
        // Equal as Swift strings; only one of them is a grant.
        #expect("repo:com.example.Key" == "repo:com.example.\u{212A}ey")
        #expect(ascii.rejected.isEmpty)
        #expect(kelvin.rejected.count == 1)
        #expect(ascii != kelvin)
        #expect(Set([ascii, kelvin]).count == 2)
        #expect(ascii == ATProtoScopeSet(scope: "repo:com.example.Key"))
        #expect(ascii.hashValue == ATProtoScopeSet(scope: "repo:com.example.Key").hashValue)
        // Identity of contents, not of grant: two spellings are unequal sets that cover each other.
        let positional = ATProtoScopeSet(scope: "atproto repo:*")
        let named = ATProtoScopeSet(scope: "atproto repo?collection=*")
        #expect(positional != named)
        #expect(positional.covers(named) && named.covers(positional))
    }

    @Test("a scope value is split and de-duplicated on bytes, whatever order the tokens come in")
    func scopeValueSplitting() {
        let ascii = "repo:com.example.Key", kelvin = "repo:com.example.\u{212A}ey"
        // A `Set<String>` holds one of the two; which must not depend on order.
        for value in ["atproto \(ascii) \(kelvin)", "atproto \(kelvin) \(ascii)"] {
            let set = ATProtoScopeSet(scope: value)
            #expect(set.rawScopes.count == 2)
            #expect(set.rawScopes.contains { Array($0.utf8) == Array(ascii.utf8) }, "\(value)")
            #expect(set.allowsRepo(.init(collection: "com.example.Key", action: .create)))
            #expect(set == ATProtoScopeSet(scope: "atproto \(ascii)"))
        }
        #expect(ATProtoScopeSet(scope: "atproto \(kelvin)").allowsRepo(.init(collection: "com.example.Key", action: .create)) == false)

        // SPACE followed by a combining mark is one `Character`, and not a
        // space; the value still splits at the space byte.
        let glued = ATProtoScopeSet(scope: "atproto \u{301}repo:* transition:email")
        #expect(glued.hasBaseATProtocolScope)
        #expect(glued.hasTransitionEmail)
        #expect(glued.unrecognized.count == 1)
        #expect(!glued.allowsRepo(.init(collection: "com.example.Key", action: .create)))
        #expect(throws: ScopeParseError.self) { _ = try ATProtoScopeSet(strict: "atproto \u{301}repo:*") }
        #expect(throws: OAuthScopeAdmissionError.notAScopeToken) {
            _ = try OAuthScopeTokenizer.tokenize("atproto \u{301}repo:*")
        }
        // Repeated spaces separate nothing.
        #expect(ATProtoScopeSet(scope: " atproto  repo:*  ").rawScopes == ["atproto", "repo:*"])
    }

    @Test("a scope string to send is ASCII, so comparing those strings compares bytes")
    func scopeStringsAreASCII() throws {
        let corpus = try UpstreamScopeCorpus.load()
        var checked = 0
        for input in corpus.values.map(\.input) + Self.extraScopes + ["blob:image/\u{E9}", "blob?accept=image/%C3%A9"] {
            guard let scope = try? ATProtoScope.parse(input), let string = scope.scopeString else { continue }
            #expect(string.utf8.allSatisfy { $0 > 0x20 && $0 < 0x7F }, "\(input) → \(string)")
            checked += 1
        }
        #expect(checked > 50)
    }

    // MARK: - Include expansion

    @Test("an expanded rpc permission is stored as a string that reads back as the inherited audience")
    func expansionRoundTripsAudience() throws {
        // The include's audience ends `#svc%26admin` (a literal percent sign).
        let include = try IncludeScope.parse("include:com.example.calendar.auth?aud=did:web:example.com%23svc%2526admin")
        #expect(include.aud == .service("did:web:example.com#svc%26admin"))
        let set = LexiconPermissionSet(permissions: [
            LexiconPermission(resource: "rpc", fields: [
                "lxm": .list([.string("com.example.calendar.listEvents")]), "inheritAud": .bool(true),
            ]),
            LexiconPermission(resource: "repo", fields: ["collection": .list([.string("com.example.calendar.event")])]),
        ])

        let permissions = include.expand(set)
        #expect(permissions.count == 2)
        let strings = try include.expandToScopeStrings(set)
        #expect(strings == [
            "rpc:com.example.calendar.listEvents?aud=did:web:example.com%23svc%2526admin",
            "repo:com.example.calendar.event",
        ])
        // The reference's canonical string for the same permission names another service when read back.
        let canonical = try permissions[0].canonicalScopeString()
        #expect(canonical == "rpc:com.example.calendar.listEvents?aud=did:web:example.com%23svc%26admin")
        #expect(try RpcPermission.parse(canonical).aud == .service("did:web:example.com#svc&admin"))

        // What a resource server derives from the stored grant is what the include inherited.
        let granted = ATProtoScopeSet(rawScopes: Set(strings))
        #expect(granted.rejected.isEmpty)
        #expect(granted.allowsRPC(.init(lxm: "com.example.calendar.listEvents", aud: "did:web:example.com#svc%26admin")))
        #expect(!granted.allowsRPC(.init(lxm: "com.example.calendar.listEvents", aud: "did:web:example.com#svc&admin")))
        #expect(try permissions.map { try $0.scopeString() } == strings)
        #expect(granted.covers(permissions[0].scope) && granted.covers(permissions[1].scope))
    }

    @Test("for ordinary permission sets the expanded strings are the reference's canonical strings")
    func expansionIsCanonicalOtherwise() throws {
        let corpus = try UpstreamScopeCorpus.load()
        for row in corpus.includes {
            guard let include = try? IncludeScope.parse(row.scope) else { continue }
            let permissions = include.expand(row.permissionSet)
            #expect(try include.expandToScopeStrings(row.permissionSet) == permissions.map { try $0.canonicalScopeString() })
        }
    }
}
