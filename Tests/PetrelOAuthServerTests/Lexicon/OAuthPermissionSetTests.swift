import Foundation
@testable import PetrelOAuthServer
import Testing

/// A resolver whose documents tests can swap, counting lookups.
final class MutableLexiconResolver: OAuthLexiconResolving, @unchecked Sendable {
    private let lock = NSLock()
    private var documents: [String: OAuthLexiconDocument]
    private var lookups = 0
    private var failing = false

    init(_ documents: [String: OAuthLexiconDocument] = [:]) {
        self.documents = documents
    }

    func set(_ nsid: String, _ document: OAuthLexiconDocument?) {
        lock.lock()
        documents[nsid] = document
        lock.unlock()
    }

    func setFailing(_ value: Bool) {
        lock.lock()
        failing = value
        lock.unlock()
    }

    var lookupCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return lookups
    }

    func resolve(_ nsid: String) async throws -> OAuthLexiconResolution {
        guard let document = lookup(nsid) else { return .unresolvable }
        return .resolved(document, sourceURI: "at://did:plc:authority/com.atproto.lexicon.schema/\(nsid)", verifiedCID: "bafy")
    }

    private func lookup(_ nsid: String) -> OAuthLexiconDocument? {
        lock.lock()
        defer { lock.unlock() }
        lookups += 1
        return failing ? nil : documents[nsid]
    }
}

@Suite("Permission sets: include: scopes end to end")
struct OAuthPermissionSetTests {
    static let setNSID = "app.example.authBasic"
    static let audience = "did:web:api.example.com#svc"
    static let includeScope = "include:app.example.authBasic?aud=did:web:api.example.com%23svc"

    static func basicSet(extraCollection: String? = nil) -> LexiconPermissionSet {
        var collections: [LexiconValue] = [.string("app.example.post")]
        if let extraCollection { collections.append(.string(extraCollection)) }
        return LexiconPermissionSet(
            permissions: [
                LexiconPermission(type: "permission", resource: "repo", fields: ["collection": .list(collections)]),
                LexiconPermission(type: "permission", resource: "rpc", fields: [
                    "lxm": .list([.string("app.example.getFeed")]), "inheritAud": .bool(true),
                ]),
                LexiconPermission(type: "permission", resource: "rpc", fields: [
                    "lxm": .list([.string("app.example.getProfile")]), "aud": .string("*"),
                ]),
                // Each of the following must be ignored, not granted and not fatal.
                LexiconPermission(type: "permission", resource: "repo", fields: ["collection": .list([.string("com.other.thing")])]),
                LexiconPermission(type: "permission", resource: "repo", fields: ["collection": .list([.string("*")])]),
                LexiconPermission(type: "permission", resource: "blob", fields: ["accept": .list([.string("*/*")])]),
                LexiconPermission(type: "permission", resource: "account", fields: ["attr": .string("email")]),
                LexiconPermission(type: "permission", resource: "future", fields: [:]),
                LexiconPermission(type: "permission", resource: "rpc", fields: [
                    "lxm": .list([.string("app.example.getThing")]), "aud": .string("did:web:fixed.example.com#x"),
                ]),
                LexiconPermission(type: "permission", resource: "repo", fields: [
                    "collection": .list([.string("app.example.like")]), "unexpected": .string("value"),
                ]),
            ],
            title: "Example basics",
            detail: "Post and read your feed",
            titleLang: ["fr": "Bases d'Example"]
        )
    }

    private func harness(_ resolver: (any OAuthLexiconResolving)?) throws -> TestServer {
        try TestServer(lexiconResolver: resolver, webClientScopes: ["atproto", Self.includeScope, "include:app.example.other"])
    }

    @Test("a permission set is expanded into the effective grant; the client still sees what it asked for")
    func expansion() async throws {
        let resolver = MutableLexiconResolver([Self.setNSID: .permissionSet(Self.basicSet())])
        let harness = try harness(resolver)
        let client = try TestClient(harness)
        let tokens = try await client.signIn(scope: "atproto \(Self.includeScope)")
        #expect(tokens.scope == "atproto \(Self.includeScope)")

        let verifier = OAuthResourceServerVerifier(authorizationServer: harness.server)
        let grant = try await authenticate(verifier, client, token: tokens.accessToken)
        #expect(grant.permissions.rawScopes == [
            "atproto",
            "repo:app.example.post",
            "rpc:app.example.getFeed?aud=did:web:api.example.com%23svc",
            "rpc:app.example.getProfile?aud=*",
        ])
        try grant.requireRepo(collection: "app.example.post", action: .create)
        try grant.requireRPC(lxm: "app.example.getFeed", aud: Self.audience)
        try grant.requireRPC(lxm: "app.example.getProfile", aud: "did:web:anything.example#y")
        // inheritAud took the include's audience and no other.
        #expect(throws: OAuthResourceAuthorizationFailure.self) {
            try grant.requireRPC(lxm: "app.example.getFeed", aud: "did:web:elsewhere.example#svc")
        }
        // Namespace authority, wildcards, non-repo/rpc resources, fixed audiences
        // and entries with unexpected fields were all ignored.
        for collection in ["com.other.thing", "app.example.like", "app.bsky.feed.post"] {
            #expect(throws: OAuthResourceAuthorizationFailure.self) {
                try grant.requireRepo(collection: collection, action: .create)
            }
        }
        #expect(throws: OAuthResourceAuthorizationFailure.self) { try grant.requireBlob(mime: "image/png") }
        #expect(throws: OAuthResourceAuthorizationFailure.self) { try grant.requireAccount(attr: .email, action: .read) }
        #expect(throws: OAuthResourceAuthorizationFailure.self) {
            try grant.requireRPC(lxm: "app.example.getThing", aud: "did:web:fixed.example.com#x")
        }
    }

    @Test("the consent page shows the set's title, localised, and the permissions inside it")
    func consentDescription() async throws {
        let resolver = MutableLexiconResolver([Self.setNSID: .permissionSet(Self.basicSet())])
        let harness = try harness(resolver)
        let client = try TestClient(harness)
        let requestURI = try await client.pushRequest(scope: "atproto \(Self.includeScope)")
        let browser = TestBrowser(harness)
        await browser.open(requestURI: requestURI, clientID: client.clientID)
        let consent = await harness.post(
            OAuthAuthorizationServer.Path.signIn,
            [("csrf", browser.csrf), ("identifier", "alice.test"), ("password", "alice-password")],
            headers: [
                ("Cookie", browser.cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")),
                ("Accept-Language", "fr-CA, en;q=0.5"),
            ]
        )
        #expect(consent.text.contains("Bases d&#39;Example"))
        #expect(consent.text.contains("Post and read your feed"))
        #expect(consent.text.contains("app.example.post"))

        let summary = OAuthScopeDescription.summarize(
            requestedScopes: ["atproto", Self.includeScope], permissionSets: [Self.setNSID: Self.basicSet()]
        )
        #expect(summary.count == 1)
        #expect(summary.first?.kind == .permissionSet)
        #expect(summary.first?.title == "Example basics")
        #expect(summary.first?.details.count == 4)
    }

    @Test("a set that cannot be resolved, or is not a permission set, fails the request at PAR", arguments: [
        "unresolvable", "not a permission set", "no resolver", "too many sets",
    ])
    func unresolvable(scenario: String) async throws {
        let resolver = MutableLexiconResolver(["app.example.other": .other])
        let harness = try scenario == "no resolver" ? harness(nil) : harness(resolver)
        let client = try TestClient(harness)
        var scope = "atproto \(Self.includeScope)"
        if scenario == "not a permission set" { scope = "atproto include:app.example.other" }
        if scenario == "too many sets" {
            let many = (1 ... 5).map { "include:app.example.set\($0)" }
            try harness.clients.register(.init(
                metadata: OAuthClientMetadata(
                    clientID: #require(URL(string: "https://many.example.test/c.json")),
                    redirectURIs: [#require(URL(string: "https://many.example.test/cb"))],
                    grantTypes: ["authorization_code"], responseTypes: ["code"],
                    scopes: Set(["atproto"] + many), dpopBoundAccessTokens: true
                ),
                keySet: nil
            ))
            let manyClient = try TestClient(harness, clientID: "https://many.example.test/c.json", redirectURI: "https://many.example.test/cb")
            let response = try await manyClient.send(
                OAuthAuthorizationServer.Path.pushedAuthorizationRequest,
                manyClient.parFields(scope: (["atproto"] + many).joined(separator: " "))
            )
            #expect(response.oauthError == "invalid_scope")
            return
        }
        let response = try await client.send(
            OAuthAuthorizationServer.Path.pushedAuthorizationRequest, client.parFields(scope: scope)
        )
        #expect(response.status == 400)
        #expect(response.oauthError == "invalid_scope", "\(scenario): \(response.text)")
    }

    @Test("refresh re-derives the grant from the published set, and keeps the old grant if resolution fails")
    func refreshRederivation() async throws {
        let resolver = MutableLexiconResolver([Self.setNSID: .permissionSet(Self.basicSet())])
        let harness = try harness(resolver)
        let client = try TestClient(harness)
        var tokens = try await client.signIn(scope: "atproto \(Self.includeScope)")
        let verifier = OAuthResourceServerVerifier(authorizationServer: harness.server)

        // The publisher adds a record type to the set.
        resolver.set(Self.setNSID, .permissionSet(Self.basicSet(extraCollection: "app.example.reply")))
        // The existing access token keeps its fixed permissions.
        var grant = try await authenticate(verifier, client, token: tokens.accessToken)
        #expect(throws: OAuthResourceAuthorizationFailure.self) {
            try grant.requireRepo(collection: "app.example.reply", action: .create)
        }
        // After a refresh the session has the updated permissions.
        tokens = try await client.refresh(#require(tokens.refreshToken)).decode(OAuthTokenResponse.self)
        grant = try await authenticate(verifier, client, token: tokens.accessToken)
        try grant.requireRepo(collection: "app.example.reply", action: .create)
        #expect(tokens.scope == "atproto \(Self.includeScope)")

        // Resolution starts failing: the session is not broken and keeps its grant.
        resolver.setFailing(true)
        let response = try await client.refresh(#require(tokens.refreshToken))
        #expect(response.status == 200)
        grant = try await authenticate(verifier, client, token: response.decode(OAuthTokenResponse.self).accessToken)
        try grant.requireRepo(collection: "app.example.reply", action: .create)
    }

    @Test("the cache serves fresh sets, refreshes stale ones, survives outages until expiry, and bounds failures")
    func caching() async throws {
        let upstream = MutableLexiconResolver([Self.setNSID: .permissionSet(Self.basicSet())])
        let clock = TestClock()
        let resolver = CachingOAuthLexiconResolver(upstream: upstream, cache: InMemoryOAuthStore(), clock: clock)
        func isResolved() async throws -> Bool {
            if case .resolved = try await resolver.resolve(Self.setNSID) { return true }
            return false
        }
        #expect(try await isResolved())
        #expect(try await isResolved())
        #expect(upstream.lookupCount == 1, "fresh entries are served from cache")

        clock.advance(24 * 60 * 60 + 1)
        #expect(try await isResolved())
        #expect(upstream.lookupCount == 2, "a stale entry is re-resolved")

        // An outage: the stale value keeps being used, and the upstream is not hammered.
        upstream.setFailing(true)
        clock.advance(24 * 60 * 60 + 1)
        #expect(try await isResolved())
        #expect(try await isResolved())
        #expect(upstream.lookupCount == 3)
        clock.advance(5 * 60 + 1)
        #expect(try await isResolved())
        #expect(upstream.lookupCount == 4)

        // Past 90 days without a successful resolution the set is no longer usable.
        clock.advance(91 * 24 * 60 * 60)
        #expect(try await !isResolved())

        // A set that never resolved is negative-cached briefly.
        let before = upstream.lookupCount
        if case .resolved = try await resolver.resolve("app.example.missing") { Issue.record("resolved") }
        if case .resolved = try await resolver.resolve("app.example.missing") { Issue.record("resolved") }
        #expect(upstream.lookupCount == before + 1)
        // Recovery is picked up after the negative lifetime.
        upstream.setFailing(false)
        upstream.set("app.example.missing", .permissionSet(Self.basicSet()))
        clock.advance(5 * 60 + 1)
        if case .unresolvable = try await resolver.resolve("app.example.missing") { Issue.record("still unresolvable") }
    }
}
