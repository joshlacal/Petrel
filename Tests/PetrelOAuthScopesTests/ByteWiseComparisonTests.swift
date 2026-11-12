import Foundation
import PetrelOAuthScopes
import Testing

/// Authorization compares bytes, not text.
///
/// Swift's `String ==` and `hasPrefix` work on Unicode canonical equivalence:
/// U+212A KELVIN SIGN equals `K`, and `e` + U+0301 equals `é`. The reference
/// implementation compares code units, and so must anything that decides
/// whether a request is allowed: two names that are different byte sequences
/// are different collections, methods, services and media types.
@Suite("Authorization comparisons are byte-wise")
struct ByteWiseComparisonTests {
    private static let kelvin = "\u{212A}" // canonically equivalent to "K"
    private static let fullwidthK = "\u{FF2B}" // compatibility equivalent only
    private static let combiningAcute = "\u{301}"

    // MARK: - repo

    @Test("repo: a collection that only looks like the granted one is not granted")
    func repoCollection() throws {
        let permission = try RepoPermission.parse("repo:com.example.Key")
        let set = ATProtoScopeSet(scope: "atproto repo:com.example.Key")
        #expect(permission.matches(.init(collection: "com.example.Key", action: .create)))
        #expect(set.allowsRepo(.init(collection: "com.example.Key", action: .create)))
        for lookalike in ["com.example.\(Self.kelvin)ey", "com.example.\(Self.fullwidthK)ey", "com.example.Key\(Self.combiningAcute)"] {
            #expect(lookalike != "com.example.Key" || lookalike.utf8.count != "com.example.Key".utf8.count)
            #expect(!permission.matches(.init(collection: lookalike, action: .create)), "\(Array(lookalike.utf8))")
            #expect(!set.allowsRepo(.init(collection: lookalike, action: .create)), "\(Array(lookalike.utf8))")
            #expect(throws: ScopeDenied.self) { try set.requireRepo(.init(collection: lookalike, action: .create)) }
        }
        // The values themselves compare the same way.
        #expect(CollectionParam.nsid("com.example.Key") != CollectionParam.nsid("com.example.\(Self.kelvin)ey"))
        #expect(Set([CollectionParam.nsid("com.example.Key"), .nsid("com.example.\(Self.kelvin)ey")]).count == 2)
    }

    @Test("repo: covers does not treat a lookalike collection as covered")
    func repoCovers() throws {
        let set = ATProtoScopeSet(scope: "atproto repo:com.example.Key")
        #expect(try set.covers(.repo(collections: ["com.example.Key"])))
        let lookalike = ATProtoScope.repo(RepoPermission(collection: [.nsid("com.example.\(Self.kelvin)ey")]))
        #expect(!set.covers(lookalike))
    }

    // MARK: - rpc

    @Test("rpc: a method or service that only looks like the granted one is not granted")
    func rpcMethodAndAudience() throws {
        let audience = "did:web:api.example.com#svcK"
        let permission = try RpcPermission.parse("rpc:com.example.getKey?aud=did:web:api.example.com%23svcK")
        let set = ATProtoScopeSet(scope: "atproto rpc:com.example.getKey?aud=did:web:api.example.com%23svcK")
        #expect(permission.matches(.init(lxm: "com.example.getKey", aud: audience)))
        #expect(set.allowsRPC(.init(lxm: "com.example.getKey", aud: audience)))

        for method in ["com.example.get\(Self.kelvin)ey", "com.example.get\(Self.fullwidthK)ey", "com.example.getKey\(Self.combiningAcute)"] {
            #expect(!permission.matches(.init(lxm: method, aud: audience)), "\(Array(method.utf8))")
            #expect(!set.allowsRPC(.init(lxm: method, aud: audience)), "\(Array(method.utf8))")
        }
        for service in ["did:web:api.example.com#svc\(Self.kelvin)", "did:web:api.example.com#svc\(Self.fullwidthK)", "\(audience)\(Self.combiningAcute)"] {
            #expect(!permission.matches(.init(lxm: "com.example.getKey", aud: service)), "\(Array(service.utf8))")
            #expect(!set.allowsRPC(.init(lxm: "com.example.getKey", aud: service)), "\(Array(service.utf8))")
        }
        #expect(LxmParam.nsid("com.example.getKey") != LxmParam.nsid("com.example.get\(Self.kelvin)ey"))
        #expect(AudParam.service(audience) != AudParam.service("did:web:api.example.com#svc\(Self.kelvin)"))
        #expect(Set([AudParam.service(audience), .service("did:web:api.example.com#svc\(Self.kelvin)")]).count == 2)
    }

    @Test("rpc: the chat.bsky. prefix is a byte prefix, so a combining mark cannot hide it")
    func chatPrefix() {
        let generic = ATProtoScopeSet(scope: "atproto transition:generic")
        let chat = ATProtoScopeSet(scope: "atproto transition:chat.bsky")
        let audience = "did:web:api.bsky.chat#bsky_chat"
        #expect(!generic.allowsRPC(.init(lxm: "chat.bsky.convo.getConvo", aud: audience)))
        #expect(chat.allowsRPC(.init(lxm: "chat.bsky.convo.getConvo", aud: audience)))

        // "." followed by a combining mark is one character to Swift, so a
        // text prefix test says this does not begin with "chat.bsky." and
        // transition:generic would let it through. As bytes, it does.
        let disguised = "chat.bsky.\(Self.combiningAcute)convo.getConvo"
        #expect(!disguised.hasPrefix("chat.bsky."))
        #expect(!generic.allowsRPC(.init(lxm: disguised, aud: audience)))
        #expect(chat.allowsRPC(.init(lxm: disguised, aud: audience)))
        // And a lookalike of the prefix is not the prefix.
        #expect(!chat.allowsRPC(.init(lxm: "chat.bs\(Self.fullwidthK)y.convo.getConvo", aud: audience)))
        #expect(generic.allowsRPC(.init(lxm: "chat.bs\(Self.fullwidthK)y.convo.getConvo", aud: audience)))
    }

    @Test("rpc: covers does not treat a lookalike method or service as covered")
    func rpcCovers() throws {
        let set = ATProtoScopeSet(scope: "atproto rpc:com.example.getKey?aud=* rpc:com.example.other?aud=did:web:api.example.com%23svcK")
        #expect(try set.covers(.rpc(lxm: ["com.example.getKey"], aud: "*")))
        #expect(!set.covers(.rpc(RpcPermission(aud: .any, lxm: [.nsid("com.example.get\(Self.kelvin)ey")]))))
        #expect(!set.covers(.rpc(RpcPermission(
            aud: .service("did:web:api.example.com#svc\(Self.kelvin)"), lxm: [.nsid("com.example.other")]
        ))))
        // A wildcard-method need against a per-service grant compares the services byte-wise too.
        let wide = ATProtoScopeSet(scope: "atproto rpc:*?aud=did:web:api.example.com%23svcK")
        #expect(wide.covers(.rpc(RpcPermission(aud: .service("did:web:api.example.com#svcK"), lxm: [.any]))))
        #expect(!wide.covers(.rpc(RpcPermission(aud: .service("did:web:api.example.com#svc\(Self.kelvin)"), lxm: [.any]))))
    }

    // MARK: - blob

    @Test("blob: only ASCII letters are case-folded, and media types are compared as bytes")
    func blobMime() throws {
        let set = ATProtoScopeSet(scope: "atproto blob:image/kpg")
        #expect(set.allowsBlob(.init(mime: "image/kpg")))
        #expect(set.allowsBlob(.init(mime: "IMAGE/KPG")))
        // KELVIN SIGN lower-cases to "k" under Unicode case mapping. It is not "K".
        #expect("image/\(Self.kelvin)pg".lowercased() == "image/kpg")
        #expect(!set.allowsBlob(.init(mime: "image/\(Self.kelvin)pg")))
        #expect(!set.allowsBlob(.init(mime: "image/\(Self.fullwidthK)pg")))
        #expect(!set.covers(.blob(BlobPermission(accept: [try #require(AcceptPattern("image/\(Self.kelvin)pg"))]))))

        // Precomposed and decomposed "é" are equal as text and different as bytes.
        let precomposed = try BlobPermission.parse("blob:image/%C3%A9")
        #expect(precomposed.matches(.init(mime: "image/\u{E9}")))
        #expect(!precomposed.matches(.init(mime: "image/e\(Self.combiningAcute)")))
        #expect(!ATProtoScopeSet(scope: "blob:image/%C3%A9").allowsBlob(.init(mime: "image/e\(Self.combiningAcute)")))
        #expect(AcceptPattern("image/\u{E9}") != AcceptPattern("image/e\(Self.combiningAcute)"))
        // A type wildcard compares its type the same way.
        #expect(!ATProtoScopeSet(scope: "blob:kind/*").allowsBlob(.init(mime: "\(Self.kelvin)ind/png")))
        #expect(ATProtoScopeSet(scope: "blob:kind/*").allowsBlob(.init(mime: "KIND/png")))
    }

    // MARK: - account, identity, static scopes

    @Test("account and identity: attribute and action names are matched as bytes")
    func accountAndIdentity() {
        // No lookalike of these lower-case names is equal to them even as
        // text; these pin that a non-ASCII spelling is never accepted.
        for scope in [
            "account:emai\u{FF4C}", "account:email?action=\u{FF52}ead", "account:%EF%BD%85mail",
            "identity:\u{FF48}andle", "identity:handle\(Self.combiningAcute)",
            "repo:com.example.thing?action=creat\u{FF45}",
        ] {
            #expect(throws: ScopeParseError.self) { _ = try ATProtoScope.parse(scope) }
        }
        #expect(throws: ScopeParseError.self) { _ = try AccountPermission.parse("account:email?action=manage\(Self.combiningAcute)") }
    }

    @Test("the fixed scope names are matched as bytes")
    func staticScopes() {
        for scope in ["atproto\(Self.combiningAcute)", "transition:generic\(Self.combiningAcute)", "transition:chat.bs\(Self.fullwidthK)y"] {
            #expect(throws: ScopeParseError.self) { _ = try ATProtoScope.parse(scope) }
            let set = ATProtoScopeSet(rawScopes: [scope])
            #expect(!set.hasBaseATProtocolScope)
            #expect(!set.hasTransitionGeneric)
            #expect(!set.hasTransitionChatBsky)
            #expect(set.unrecognized.count == 1)
        }
    }

    // MARK: - include

    @Test("include: namespace authority and include equality are byte-wise")
    func include() throws {
        let include = try IncludeScope.parse("include:com.example.Key.auth")
        #expect(include.isParentAuthorityOf("com.example.Key.post"))
        #expect(!include.isParentAuthorityOf("com.example.\(Self.kelvin)ey.post"))
        #expect(!include.isParentAuthorityOf("com.example.\(Self.fullwidthK)ey.post"))

        // A permission-set entry naming a lookalike collection grants nothing.
        let set = LexiconPermissionSet(permissions: [
            LexiconPermission(resource: "repo", fields: ["collection": .list([.string("com.example.Key.post")])]),
            LexiconPermission(resource: "repo", fields: ["collection": .list([.string("com.example.\(Self.kelvin)ey.post")])]),
        ])
        #expect(include.expand(set).count == 1)

        // An include is covered only by the byte-identical include.
        let granted = ATProtoScopeSet(scope: "atproto include:com.example.Key.auth?aud=did:web:api.example.com%23svcK")
        #expect(try granted.covers(.include(nsid: "com.example.Key.auth", aud: "did:web:api.example.com#svcK")))
        #expect(!granted.covers(.include(IncludeScope(
            nsid: "com.example.Key.auth", aud: .service("did:web:api.example.com#svc\(Self.kelvin)")
        ))))
        #expect(!granted.covers(.include(IncludeScope(nsid: "com.example.\(Self.kelvin)ey.auth", aud: .service("did:web:api.example.com#svcK")))))
    }

    // MARK: - covers and unrecognized scopes

    @Test("covers: a scope that cannot be parsed is covered only by the identical string")
    func coversUnrecognized() {
        let granted = ATProtoScopeSet(scope: "atproto transition:generic future:thing")
        // The same unrecognised string is held: nothing more to ask for.
        #expect(granted.covers(ATProtoScopeSet(scope: "atproto future:thing")))
        // A different one is not known to be granted, so it is not covered —
        // however much else the session holds.
        #expect(!granted.covers(ATProtoScopeSet(scope: "atproto future:other")))
        #expect(!granted.covers(ATProtoScopeSet(scope: "future:thing?x=1")))
        #expect(!ATProtoScopeSet(scope: "atproto transition:generic").covers(ATProtoScopeSet(scope: "atproto future:thing")))
        // An invalid spelling of a known resource is unrecognised too.
        #expect(!granted.covers(ATProtoScopeSet(scope: "repo:not-an-nsid")))
        // Identical means identical bytes.
        #expect(!ATProtoScopeSet(rawScopes: ["future:K"]).covers(ATProtoScopeSet(rawScopes: ["future:\(Self.kelvin)"])))
        #expect(ATProtoScopeSet(rawScopes: ["future:\(Self.kelvin)"]).covers(ATProtoScopeSet(rawScopes: ["future:\(Self.kelvin)"])))
        // Recognised scopes are still decided by what they grant.
        #expect(granted.covers(ATProtoScopeSet(scope: "atproto repo:app.bsky.feed.post?action=create")))
    }

    // MARK: - permission sets with unusable field values

    @Test(
        "a permission-set entry with a null or object field is ignored; the rest of the set stands",
        arguments: [
            // An rpc entry may only name the wildcard audience, and null is not it.
            (#"{"type":"permission","resource":"rpc","aud":null,"lxm":["com.example.calendar.listEvents"]}"#,
             IncludeScope.ExpansionRejectionReason.notAllowedInPermissionSet),
            (#"{"type":"permission","resource":"rpc","lxm":null,"inheritAud":true}"#, .invalidPermission),
            (#"{"type":"permission","resource":"repo","collection":["com.example.calendar.rsvp"],"action":null}"#, .invalidPermission),
            (#"{"type":"permission","resource":"repo","collection":[{"nsid":"com.example.calendar.rsvp"}]}"#, .invalidPermission),
            (#"{"type":"permission","resource":"repo","collection":["com.example.calendar.rsvp"],"nested":{"a":1}}"#, .invalidPermission),
            (#"{"type":"permission","resource":"repo","collection":null}"#, .invalidPermission),
        ]
    )
    func unusableFieldValue(_ entry: String, reason: IncludeScope.ExpansionRejectionReason) throws {
        let json = """
        {"type":"permission-set","permissions":[
          {"type":"permission","resource":"repo","collection":["com.example.calendar.event"]},
          \(entry)
        ]}
        """
        let set = try JSONDecoder().decode(LexiconPermissionSet.self, from: Data(json.utf8))
        #expect(set.permissions.count == 2)
        let include = try IncludeScope.parse("include:com.example.calendar.auth?aud=did:web:api.example.com%23svc")
        let (permissions, rejections) = include.expansion(of: set)
        #expect(permissions == include.expand(set))
        #expect(try permissions.map { try $0.canonicalScopeString() } == ["repo:com.example.calendar.event"])
        #expect(rejections.map(\.index) == [1])
        #expect(rejections.first?.reason == reason)
    }
}
