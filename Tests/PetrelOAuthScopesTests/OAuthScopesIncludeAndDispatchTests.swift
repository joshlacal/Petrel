import Foundation
import Testing
@testable import PetrelOAuthScopes

/// Parsing and formatting of `include:` scopes, and `ATProtoScope`, which
/// dispatches a scope value to its resource. Expansion of an include is in
/// `OAuthScopesIncludeExpansionTests`.
@Suite("include: scopes and the ATProtoScope dispatcher")
struct OAuthScopesIncludeAndDispatchTests {
    // MARK: include

    @Test
    func includeParsesPositionalNsidWithNoAud() throws {
        let scope = try IncludeScope.parse("include:com.example.bar")
        #expect(scope.nsid == "com.example.bar")
        #expect(scope.aud == nil)
    }

    @Test
    func includeParsesAudInBothRawAndPercentEncodedForm() throws {
        let a = try IncludeScope.parse("include:com.example.baz?aud=did:web:example.com%23my_service")
        #expect(a.aud == .service("did:web:example.com#my_service"))
        // A bare `#` in a query string is a literal, not a fragment delimiter.
        let b = try IncludeScope.parse("include:com.example.baz?aud=did:web:example.com#my_service")
        #expect(b.aud == .service("did:web:example.com#my_service"))
    }

    @Test
    func includeAcceptsNamedFormOfThePositionalKeyInAnyOrder() throws {
        let a = try IncludeScope.parse("include?nsid=com.example.baz")
        #expect(a.nsid == "com.example.baz")
        let b = try IncludeScope.parse("include?aud=did:web:example.com%23my_service&nsid=com.example.baz")
        #expect(b.nsid == "com.example.baz" && b.aud == .service("did:web:example.com#my_service"))
    }

    @Test
    func includeRejectsAllSeventeenUpstreamVectors() {
        // scopes/include-scope.test.ts:64-87 (18 entries, one repeated).
        let rejects = [
            "", "repo:com.example.baz", "include", "include#", "include:", "include:#", "include:&",
            "include:com..example", "include:com", "include:com.example", "include:9com.example.foo",
            "include:com.example.-bar", "include:invalid^nsid", "include:nsid",
            "include:com.example.baz?aud=", "include:com.example.baz?aud=did:web:example.com",
            "include:com.example.baz?aud=invalid^did",
        ]
        #expect(rejects.count == 17)
        for scope in rejects {
            #expect(throws: ScopeParseError.self) { try IncludeScope.parse(scope) }
        }
    }

    @Test
    func includeFormat() throws {
        #expect(try IncludeScope(nsid: "com.example.foo").canonicalScopeString() == "include:com.example.foo")
        #expect(try IncludeScope(nsid: "com.example.foo", aud: .service("did:web:example.com#my_service"))
            .canonicalScopeString() == "include:com.example.foo?aud=did:web:example.com%23my_service")
    }

    // MARK: dispatcher

    @Test
    func dispatcherRoutesTransitionAndAtprotoLiteralsWithoutFamilyLookup() throws {
        #expect(try ATProtoScope.parse("atproto") == .atproto)
        #expect(try ATProtoScope.parse("transition:email") == .transitionEmail)
        #expect(try ATProtoScope.parse("transition:generic") == .transitionGeneric)
        #expect(try ATProtoScope.parse("transition:chat.bsky") == .transitionChatBsky)
    }

    @Test
    func dispatcherRoutesEachPrefixToItsFamily() throws {
        guard case .account = try ATProtoScope.parse("account:email") else { Issue.record("expected .account"); return }
        guard case .blob = try ATProtoScope.parse("blob:image/png") else { Issue.record("expected .blob"); return }
        guard case .identity = try ATProtoScope.parse("identity:handle") else { Issue.record("expected .identity"); return }
        guard case .include = try ATProtoScope.parse("include:com.example.foo") else { Issue.record("expected .include"); return }
        guard case .repo = try ATProtoScope.parse("repo:com.example.foo") else { Issue.record("expected .repo"); return }
        guard case .rpc = try ATProtoScope.parse("rpc:com.example.method?aud=*") else { Issue.record("expected .rpc"); return }
    }

    @Test
    func spaceIsNotAResource() {
        // `space` is not defined by the permission specification.
        #expect(throws: ScopeParseError.unknownPrefix("space:com.example.type")) {
            try ATProtoScope.parse("space:com.example.type")
        }
    }

    @Test
    func dispatcherRejectsUnknownPrefix() {
        #expect(throws: ScopeParseError.self) { try ATProtoScope.parse("openid") }
        #expect(throws: ScopeParseError.self) { try ATProtoScope.parse("nonsense:whatever") }
    }

    @Test
    func dispatcherPrefixesAreDisjointSoSuperstringsDoNotMisroute() {
        // A resource name that merely starts with a known one is not routed to
        // it.
        #expect(throws: ScopeParseError.self) { try ATProtoScope.parse("identityfoo:bar") }
    }

    @Test
    func dispatcherCanonicalScopeStringRoundTripsEveryCase() throws {
        for scope in ["atproto", "transition:email", "transition:generic", "transition:chat.bsky",
                      "account:email", "blob:image/png", "identity:handle", "include:com.example.foo",
                      "repo:com.example.foo", "rpc:com.example.method?aud=*"] {
            let parsed = try ATProtoScope.parse(scope)
            #expect(try parsed.canonicalScopeString() == scope)
        }
    }
}
