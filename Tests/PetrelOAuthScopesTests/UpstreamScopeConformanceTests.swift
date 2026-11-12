import Foundation
import Testing
@testable import PetrelOAuthScopes

/// Drives this package against every section of the golden corpus generated
/// from the reference implementation (`UpstreamScopeCorpus`).
///
/// No expectation here is hand-written. Rows on which this package
/// deliberately differs are listed in `UpstreamScopeDivergence` and asserted
/// as differences, so that neither a silent fix nor a silent regression goes
/// unnoticed.
@Suite("Conformance with the reference implementation's @atproto/oauth-scopes")
struct UpstreamScopeConformanceTests {
    let corpus: UpstreamScopeCorpus

    init() throws {
        corpus = try UpstreamScopeCorpus.load()
    }

    private func canonical(_ scope: String) -> String? {
        try? ATProtoScope.parse(scope).canonicalScopeString()
    }

    // MARK: - values

    @Test("every value parses, or is rejected, as the reference implementation decides")
    func valuesParseAndCanonicaliseAsUpstreamDoes() {
        for value in corpus.values where !UpstreamScopeDivergence.rejectedValues.contains(value.input) {
            #expect(
                canonical(value.input) == value.canonical,
                "canonical form of \(value.input.debugDescription)"
            )
        }
    }

    @Test("the listed divergences are rejected here and accepted by the reference implementation")
    func valueDivergencesAreExactlyTheListedOnes() throws {
        for input in UpstreamScopeDivergence.rejectedValues {
            let row = try #require(corpus.value(input), "corpus row missing: \(input)")
            #expect(row.parses)
            #expect(canonical(input) == nil)
            // Inert in the reference implementation: it matches no media type.
            let patterns = try #require(row.canonical).dropFirst("blob:".count)
            #expect(corpus.accepts.contains { $0.input == patterns && $0.isAccept && !$0.isMime })
        }
    }

    @Test("a malformed escape in a positional is an error, where the reference implementation throws")
    func malformedPositionalEscapesAreRejected() {
        let rows = corpus.values.filter { $0.threw != nil }
        #expect(!rows.isEmpty)
        for row in rows {
            #expect(throws: ScopeParseError.malformedPercentEncoding(row.input)) {
                try ATProtoScope.parse(row.input)
            }
        }
    }

    @Test("canonical forms parse back to themselves wherever they do in the reference implementation")
    func canonicalFormsAreStableWhereUpstreamSaysTheyAre() throws {
        for value in corpus.values where value.roundTripStable == true {
            guard !UpstreamScopeDivergence.rejectedValues.contains(value.input) else { continue }
            let expected = try #require(value.canonical)
            #expect(canonical(expected) == expected, "canonical form of \(value.input.debugDescription)")
        }
    }

    /// The reference implementation's serialiser un-escapes `+` and `%` in a
    /// query, and does not move a de-duplicated single `accept` to the
    /// positional, so a few canonical forms do not parse back to themselves.
    /// This package reproduces each one.
    @Test("canonical forms that do not round-trip in the reference implementation do not round-trip here")
    func unstableCanonicalFormsAreReproduced() throws {
        let unstable = corpus.values.filter { $0.roundTripStable == false }
        #expect(!unstable.isEmpty)
        for value in unstable {
            let expected = try #require(value.canonical)
            #expect(canonical(value.input) == expected)
            #expect(canonical(expected) != expected, "\(value.input.debugDescription) should not round-trip")
        }
    }

    // MARK: - strings

    /// `normalizeAtprotoOauthScope` is split, normalise each value, drop the
    /// ones that do not parse, sort, join (`atproto-oauth-scope.ts:52-59`). The
    /// per-value step is `ATProtoScope`; the rest is composed here.
    @Test("whole scope strings normalise as normalizeAtprotoOauthScope does")
    func wholeScopeStringNormalisation() {
        for row in corpus.strings {
            let normalized = row.input.split(separator: " ", omittingEmptySubsequences: false)
                .compactMap { canonical(String($0)) }
                .sorted()
                .joined(separator: " ")
            #expect(normalized == row.normalized, "normalisation of \(row.input.debugDescription)")
        }
    }

    @Test("a value that does not parse is kept verbatim, recorded as rejected, and grants nothing")
    func unparseableValuesAreRetainedAndInert() throws {
        let row = try #require(corpus.strings.first { $0.input == "atproto notafamily:whatever" })
        #expect(row.normalized == "atproto")

        let permissions = ScopePermissions(scope: row.input)
        #expect(permissions.rawScopes == ["atproto", "notafamily:whatever"])
        #expect(permissions.rejected == ["notafamily:whatever": .unknownPrefix("notafamily:whatever")])
        #expect(permissions.hasBaseATProtocolScope)
        #expect(ScopePermissions(scope: "notafamily:whatever") != ScopePermissions(scope: ""))
        #expect(!ScopePermissions(scope: "notafamily:whatever").hasBaseATProtocolScope)
    }

    /// The reference implementation keeps a repeated value
    /// (`atproto atproto`); `ScopePermissions` holds a set.
    @Test("a repeated scope value is held once")
    func repeatedValuesCollapse() throws {
        let row = try #require(corpus.strings.first { $0.input == "atproto atproto" })
        #expect(row.normalized == "atproto atproto")
        #expect(ScopePermissions(scope: row.input).rawScopes == ["atproto"])
    }

    // MARK: - matches

    @Test("ScopePermissions allows what ScopePermissionsTransition allows, for every grant")
    func matchOutcomesAgreeWithScopePermissionsTransition() {
        for (name, grant) in corpus.orderedGrants {
            let permissions = ScopePermissions(scope: grant.scope)
            let outcomes = grant.transition
            for outcome in outcomes.repo {
                guard let expected = outcome.allowed, let action = RepoAction(rawValue: outcome.arg.action)
                else { Issue.record("\(name): unusable repo row \(outcome.arg)"); continue }
                #expect(
                    permissions.allowsRepo(.init(collection: outcome.arg.collection, action: action)) == expected,
                    "\(name): repo \(outcome.arg)"
                )
            }
            for outcome in outcomes.blob {
                guard let expected = outcome.allowed
                else { Issue.record("\(name): unusable blob row \(outcome.arg)"); continue }
                #expect(permissions.allowsBlob(.init(mime: outcome.arg.mime)) == expected, "\(name): blob \(outcome.arg)")
            }
            for outcome in outcomes.rpc {
                guard let expected = outcome.allowed
                else { Issue.record("\(name): unusable rpc row \(outcome.arg)"); continue }
                #expect(
                    permissions.allowsRPC(.init(lxm: outcome.arg.lxm, aud: outcome.arg.aud)) == expected,
                    "\(name): rpc \(outcome.arg)"
                )
            }
            for outcome in outcomes.identity {
                guard let expected = outcome.allowed, let attr = IdentityAttribute(rawValue: outcome.arg.attr)
                else { Issue.record("\(name): unusable identity row \(outcome.arg)"); continue }
                #expect(permissions.allowsIdentity(.init(attr: attr)) == expected, "\(name): identity \(outcome.arg)")
            }
            for outcome in outcomes.account {
                guard let expected = outcome.allowed,
                      let attr = AccountAttribute(rawValue: outcome.arg.attr),
                      let action = AccountAction(rawValue: outcome.arg.action)
                else { Issue.record("\(name): unusable account row \(outcome.arg)"); continue }
                #expect(
                    permissions.allowsAccount(.init(attr: attr, action: action)) == expected,
                    "\(name): account \(outcome.arg)"
                )
            }
        }
    }

    /// The reference implementation's base class ignores the `transition:`
    /// scopes: a request is allowed when some granted value parses as a
    /// permission of the resource and matches (`scopes-set.ts:39-47`,
    /// `:104-117`). That is exactly a parse and a `matches` on the typed
    /// permissions, which is how it is evaluated here.
    @Test("the typed permissions match what ScopePermissions allows without transition scopes")
    func granularMatchOutcomesAgreeWithScopePermissions() {
        func granted<P: ScopePermission>(_: P.Type, _ scope: String, _ target: P.Target) -> Bool {
            scope.split(separator: " ").contains { (try? P.parse(String($0)))?.matches(target) ?? false }
        }
        for (name, grant) in corpus.orderedGrants {
            let outcomes = grant.granular
            for outcome in outcomes.repo {
                guard let expected = outcome.allowed, let action = RepoAction(rawValue: outcome.arg.action)
                else { Issue.record("\(name): unusable repo row \(outcome.arg)"); continue }
                #expect(
                    granted(RepoPermission.self, grant.scope, .init(collection: outcome.arg.collection, action: action))
                        == expected,
                    "\(name): repo \(outcome.arg)"
                )
            }
            for outcome in outcomes.blob {
                guard let expected = outcome.allowed
                else { Issue.record("\(name): unusable blob row \(outcome.arg)"); continue }
                #expect(
                    granted(BlobPermission.self, grant.scope, .init(mime: outcome.arg.mime)) == expected,
                    "\(name): blob \(outcome.arg)"
                )
            }
            for outcome in outcomes.rpc {
                guard let expected = outcome.allowed
                else { Issue.record("\(name): unusable rpc row \(outcome.arg)"); continue }
                #expect(
                    granted(RpcPermission.self, grant.scope, .init(lxm: outcome.arg.lxm, aud: outcome.arg.aud)) == expected,
                    "\(name): rpc \(outcome.arg)"
                )
            }
            for outcome in outcomes.identity {
                guard let expected = outcome.allowed, let attr = IdentityAttribute(rawValue: outcome.arg.attr)
                else { Issue.record("\(name): unusable identity row \(outcome.arg)"); continue }
                #expect(
                    granted(IdentityPermission.self, grant.scope, .init(attr: attr)) == expected,
                    "\(name): identity \(outcome.arg)"
                )
            }
            for outcome in outcomes.account {
                guard let expected = outcome.allowed,
                      let attr = AccountAttribute(rawValue: outcome.arg.attr),
                      let action = AccountAction(rawValue: outcome.arg.action)
                else { Issue.record("\(name): unusable account row \(outcome.arg)"); continue }
                #expect(
                    granted(AccountPermission.self, grant.scope, .init(attr: attr, action: action)) == expected,
                    "\(name): account \(outcome.arg)"
                )
            }
        }
    }

    // MARK: - missing

    @Test("a denial names the scope ScopeMissingError names")
    func deniedRequestsNameTheSameScope() throws {
        let permissions = ScopePermissions(scope: "atproto")
        for row in corpus.missing {
            let needed: String
            switch row.resource {
            case "repo":
                let action = try #require(RepoAction(rawValue: row.arg["action"] ?? ""))
                needed = try RepoPermission.scopeNeeded(
                    for: .init(collection: #require(row.arg["collection"]), action: action)
                )
                #expect(throws: ScopeDenied(needed: row.scope)) {
                    try permissions.requireRepo(.init(collection: row.arg["collection"] ?? "", action: action))
                }
            case "blob":
                needed = try BlobPermission.scopeNeeded(for: .init(mime: #require(row.arg["mime"])))
                #expect(throws: ScopeDenied(needed: row.scope)) {
                    try permissions.requireBlob(.init(mime: row.arg["mime"] ?? ""))
                }
            case "rpc":
                let target = try RpcPermission.Target(lxm: #require(row.arg["lxm"]), aud: #require(row.arg["aud"]))
                needed = try RpcPermission.scopeNeeded(for: target)
                #expect(throws: ScopeDenied(needed: row.scope)) { try permissions.requireRPC(target) }
            case "identity":
                let attr = try #require(IdentityAttribute(rawValue: row.arg["attr"] ?? ""))
                needed = try IdentityPermission.scopeNeeded(for: .init(attr: attr))
                #expect(throws: ScopeDenied(needed: row.scope)) {
                    try permissions.requireIdentity(.init(attr: attr))
                }
            case "account":
                let attr = try #require(AccountAttribute(rawValue: row.arg["attr"] ?? ""))
                let action = try #require(AccountAction(rawValue: row.arg["action"] ?? ""))
                needed = try AccountPermission.scopeNeeded(for: .init(attr: attr, action: action))
                #expect(throws: ScopeDenied(needed: row.scope)) {
                    try permissions.requireAccount(.init(attr: attr, action: action))
                }
            default:
                Issue.record("unknown resource \(row.resource)")
                continue
            }
            #expect(needed == row.scope, "\(row.resource) \(row.arg)")
        }
    }

    // MARK: - includes

    @Test("include: scopes expand to the scopes toScopes returns")
    func includeExpansionMatchesUpstream() throws {
        for row in corpus.includes {
            let expected = try #require(row.scopes, "\(row.name) threw upstream: \(row.threw ?? "")")
            let include = try IncludeScope.parse(row.scope)
            #expect(try include.expandToScopeStrings(row.permissionSet) == expected, "\(row.name)")
        }
    }

    @Test("namespace authority is decided as isParentAuthorityOf decides it")
    func namespaceAuthorityMatchesUpstream() {
        for row in corpus.authority {
            #expect(
                IncludeScope(nsid: row.nsid).isParentAuthorityOf(row.other) == row.isParentAuthority,
                "\(row.nsid) over \(row.other.debugDescription)"
            )
        }
    }

    // MARK: - validators

    @Test("isAtprotoDidRefAbsolute truth table")
    func atprotoDIDRefTruthTable() {
        for row in corpus.didRefs where !UpstreamScopeDivergence.rejectedDIDRefs.contains(row.input) {
            #expect(
                AtprotoSyntax.isValidAtprotoDIDRefAbsolute(row.input) == row.isAtprotoDidRefAbsolute,
                "\(row.input.debugDescription)"
            )
        }
        for input in UpstreamScopeDivergence.rejectedDIDRefs {
            #expect(corpus.didRefs.contains { $0.input == input && $0.isAtprotoDidRefAbsolute })
            #expect(!AtprotoSyntax.isValidAtprotoDIDRefAbsolute(input))
        }
    }

    @Test("isNsid truth table")
    func nsidTruthTable() {
        for row in corpus.nsids {
            #expect(AtprotoSyntax.isValidNSID(row.input) == row.isNsid, "\(row.input.debugDescription)")
        }
    }

    @Test("isAccept and isMime truth tables")
    func acceptAndMimeTruthTables() {
        for row in corpus.accepts {
            #expect((ConcreteMime(row.input) != nil) == row.isMime, "isMime(\(row.input.debugDescription))")
            if UpstreamScopeDivergence.rejectedAccepts.contains(row.input) {
                #expect(row.isAccept && !row.isMime)
                #expect(AcceptPattern(row.input) == nil)
            } else {
                #expect((AcceptPattern(row.input) != nil) == row.isAccept, "isAccept(\(row.input.debugDescription))")
            }
        }
    }

    // MARK: - encoders

    @Test("both serialisers match their JavaScript counterparts byte for byte")
    func encodersMatchJavaScript() {
        for row in corpus.encoders {
            #expect(ScopeStringSyntax.encodeURIComponent(row.raw) == row.encodeURIComponent, "\(row.raw.debugDescription)")
            #expect(ScopeStringSyntax.encodeFormComponent(row.raw) == row.urlSearchParams, "\(row.raw.debugDescription)")
        }
    }

    /// `encodeURIComponent` (positional) and `URLSearchParams` (query) differ,
    /// which is why there are two encoders and not one.
    @Test("the two serialisers disagree where the JavaScript ones do")
    func theTwoEncodersDisagree() {
        let disagreements = Set(corpus.encoders.filter { $0.encodeURIComponent != $0.urlSearchParams }.map(\.raw))
        #expect(disagreements.isSuperset(of: ["a~b", "a b"]))
        for raw in disagreements {
            #expect(ScopeStringSyntax.encodeURIComponent(raw) != ScopeStringSyntax.encodeFormComponent(raw))
        }
    }
}
