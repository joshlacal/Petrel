import Foundation
import PetrelOAuthScopes
import Testing

/// Every scope string this module writes for a client to send must read back,
/// byte for byte, as the permission it was written for. Two things have
/// broken that before: comparing values as Swift `String`s, which merges
/// canonically equivalent but different byte sequences (`é` and `e` + U+0301,
/// U+212A KELVIN SIGN and `K`), and writing a literal `%` or `+` unescaped, so
/// that `#svc%41` reads back as `#svcA`.
@Suite("Scope strings round-trip losslessly, compared by bytes")
struct ScopeLosslessRoundTripTests {
    // MARK: Adversarial values

    /// Media types and patterns: `+`, `%`, a literal escape, upper case,
    /// precomposed and decomposed accents, the Kelvin sign.
    static let mimes = [
        "image/png", "IMAGE/PNG", "image/svg+xml", "text/a%41", "text/a%2541", "text/a%",
        "é/*", "e\u{301}/png", "é/png", "e\u{301}/*", "image/\u{212A}tx", "image/ktx", "image/*", "*/*",
    ]

    /// Services: a literal escape, an escaped escape, `+`, a bare `%`, `&`.
    static let auds = [
        "did:web:example.com#svc", "did:web:example.com#svc%41", "did:web:example.com#svc%2541",
        "did:web:example.com#svc+x", "did:web:example.com#svc%", "did:web:example.com#svc&admin",
        "did:plc:abcdefghijklmnopqrstuvwx#atproto_labeler",
    ]

    static let methods = ["com.example.method", "app.bsky.feed.getFeed", "chat.bsky.convo.getLog"]
    static let collections = ["app.bsky.feed.post", "com.example.record"]

    /// Every typed scope the builders accept from the values above.
    static func generatedScopes() -> [ATProtoScope] {
        var scopes: [ATProtoScope] = []
        for a in mimes {
            if let s = try? ATProtoScope.blob(accept: [a]) { scopes.append(s) }
            for b in mimes where !a.utf8.elementsEqual(b.utf8) {
                if let s = try? ATProtoScope.blob(accept: [a, b]) { scopes.append(s) }
            }
        }
        for aud in auds + ["*"] {
            for lxm in methods + ["*"] {
                if let s = try? ATProtoScope.rpc(lxm: [lxm], aud: aud) { scopes.append(s) }
            }
            if let s = try? ATProtoScope.rpc(lxm: methods, aud: aud) { scopes.append(s) }
        }
        for c in collections + ["*"] {
            for actions in [RepoAction.allCases, [.create], [.update, .delete]] {
                if let s = try? ATProtoScope.repo(collections: [c], actions: actions) { scopes.append(s) }
            }
        }
        if let s = try? ATProtoScope.repo(collections: collections, actions: [.create]) { scopes.append(s) }
        return scopes
    }

    // MARK: Property: parse(scopeString(x)) is x

    @Test("every generated scope has a scope string, and it reads back as the same permission")
    func generatedScopesRoundTrip() throws {
        let scopes = Self.generatedScopes()
        #expect(scopes.count > 100, "the generator should build a substantial corpus")
        for scope in scopes {
            let string = try #require(scope.scopeString, "no scope string for \(scope)")
            let reparsed = try ATProtoScope.parse(string)
            // A fixed point after one step, compared as bytes. Not always at
            // once: like the reference, the canonical form drops duplicates
            // after choosing between positional and named form, so
            // `blob(accept: ["image/png", "IMAGE/PNG"])` is written
            // `blob?accept=image/png`, which then reads back as `blob:image/png`.
            // Both strings are the same grant, which is checked below.
            let again = try #require(reparsed.scopeString)
            let third = try #require(try ATProtoScope.parse(again).scopeString)
            #expect(third.utf8.elementsEqual(again.utf8), "\(string) → \(again) → \(third)")
            // The same grant, both ways round.
            let typed = ATProtoScopeSet([.atproto, scope])
            let parsed = ATProtoScopeSet(scope: "atproto \(string)")
            #expect(typed.unrecognized.isEmpty && parsed.unrecognized.isEmpty, "\(string)")
            #expect(typed.covers(parsed) && parsed.covers(typed), "\(string)")
            Self.expectSameAnswers(typed, parsed, label: string)
        }
    }

    /// Both sets answer every probe built from the adversarial values alike.
    static func expectSameAnswers(_ a: ATProtoScopeSet, _ b: ATProtoScopeSet, label: String) {
        for mime in mimes where !mime.utf8.contains(0x2A) {
            let t = BlobPermission.Target(mime: mime)
            #expect(a.allowsBlob(t) == b.allowsBlob(t), "\(label) blob \(mime)")
        }
        for aud in auds {
            for lxm in methods {
                let t = RpcPermission.Target(lxm: lxm, aud: aud)
                #expect(a.allowsRPC(t) == b.allowsRPC(t), "\(label) rpc \(lxm) \(aud)")
            }
        }
        for c in collections {
            for action in RepoAction.allCases {
                let t = RepoPermission.Target(collection: c, action: action)
                #expect(a.allowsRepo(t) == b.allowsRepo(t), "\(label) repo \(c)")
            }
        }
    }

    // MARK: Property: scopeNeeded(t) covers t

    @Test("the scope a denial names covers the request that was denied")
    func scopeNeededCoversTarget() throws {
        // Only services a scope can name: `#svc%` is not a valid audience, so
        // no scope grants it and there is nothing a denial could name.
        for aud in Self.auds where (try? ATProtoScope.rpc(lxm: ["*"], aud: aud)) != nil {
            for lxm in Self.methods {
                let target = RpcPermission.Target(lxm: lxm, aud: aud)
                let needed = try RpcPermission.scopeNeeded(for: target)
                #expect(ATProtoScopeSet(scope: "atproto \(needed)").allowsRPC(target), "\(needed) for \(aud)")
                let denied = #expect(throws: ScopeDenied.self) {
                    try ATProtoScopeSet(scope: "atproto").requireRPC(target)
                }
                #expect(denied.map { ATProtoScopeSet(scope: "atproto \($0.needed)").allowsRPC(target) } == true)
            }
        }
        for mime in Self.mimes where !mime.utf8.contains(0x2A) {
            let target = BlobPermission.Target(mime: mime)
            let needed = try BlobPermission.scopeNeeded(for: target)
            #expect(ATProtoScopeSet(scope: "atproto \(needed)").allowsBlob(target), "\(needed) for \(mime)")
        }
        for c in Self.collections {
            for action in RepoAction.allCases {
                let target = RepoPermission.Target(collection: c, action: action)
                let needed = try RepoPermission.scopeNeeded(for: target)
                #expect(ATProtoScopeSet(scope: "atproto \(needed)").allowsRepo(target), "\(needed)")
            }
        }
    }

    // MARK: The reported cases

    @Test("a literal %41 in an audience is not read back as A")
    func literalEscapeInAudience() throws {
        let target = RpcPermission.Target(lxm: "com.example.method", aud: "did:web:example.com#svc%41")
        let needed = try RpcPermission.scopeNeeded(for: target)
        #expect(needed == "rpc:com.example.method?aud=did:web:example.com%23svc%2541")
        #expect(!ATProtoScopeSet(scope: "atproto \(needed)")
            .allowsRPC(.init(lxm: "com.example.method", aud: "did:web:example.com#svcA")))
    }

    @Test("a type wildcard does not absorb a pattern whose type is only canonically equivalent")
    func wildcardAbsorptionIsByteWise() throws {
        let scope = try ATProtoScope.blob(accept: ["é/*", "e\u{301}/png"])
        let string = try #require(scope.scopeString)
        let set = ATProtoScopeSet([.atproto, scope])
        #expect(set.unrecognized.isEmpty)
        #expect(set.allowsBlob(.init(mime: "e\u{301}/png")))
        #expect(set.allowsBlob(.init(mime: "é/gif")))
        #expect(!set.allowsBlob(.init(mime: "e\u{301}/gif")))
        #expect(ATProtoScopeSet(scope: "atproto \(string)").allowsBlob(.init(mime: "e\u{301}/png")))
    }
}
