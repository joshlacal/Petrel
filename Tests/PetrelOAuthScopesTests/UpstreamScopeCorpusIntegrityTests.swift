import Foundation
import Testing
@testable import PetrelOAuthScopes

/// Checks that the golden corpus is present, pinned, and broad enough to be
/// worth driving the package against. These assert the fixture itself, not
/// the package: a corpus that silently stopped covering a class of input
/// would otherwise leave `UpstreamScopeConformanceTests` passing vacuously.
@Suite("The reference implementation corpus is pinned and complete")
struct UpstreamScopeCorpusIntegrityTests {
    let corpus: UpstreamScopeCorpus

    init() throws {
        corpus = try UpstreamScopeCorpus.load()
    }

    // MARK: - Provenance

    @Test
    func corpusIsPinnedToTheReferenceCommit() {
        #expect(corpus.referenceCommit == UpstreamScopeCorpus.pinnedReferenceCommit)
        #expect(corpus.referenceRepository == "https://github.com/bluesky-social/atproto")
        #expect(corpus.source == "packages/oauth/oauth-scopes")
    }

    /// The commit is a constant in the generator; `regenerate.sh` refuses to
    /// run against any other checkout. The fixture, the generator and this
    /// test target must name the same one.
    @Test
    func generatorPinsTheSameCommit() throws {
        let generator = try String(contentsOf: UpstreamScopeCorpus.generatorURL, encoding: .utf8)
        #expect(generator.contains("const REFERENCE_COMMIT = '\(UpstreamScopeCorpus.pinnedReferenceCommit)'"))
    }

    // MARK: - Coverage

    @Test
    func everySectionIsPopulated() {
        #expect(corpus.values.count >= 180)
        #expect(corpus.strings.count >= 8)
        #expect(corpus.matches.count >= 22)
        #expect(corpus.missing.count >= 9)
        #expect(corpus.includes.count >= 9)
        #expect(corpus.authority.count >= 21)
        #expect(corpus.didRefs.count >= 66)
        #expect(corpus.nsids.count >= 35)
        #expect(corpus.accepts.count >= 20)
        #expect(corpus.encoders.count >= 19)
        #expect(Set(corpus.values.map(\.input)).count == corpus.values.count, "duplicate value rows")
    }

    @Test
    func everyResourceHasAcceptedAndRejectedValues() {
        for prefix in ["account", "blob", "identity", "include", "repo", "rpc"] {
            let rows = corpus.values.filter { ScopeStringSyntax.isScopeString($0.input, for: prefix) }
            #expect(rows.contains { $0.parses }, "no accepted \(prefix) value")
            #expect(rows.contains { !$0.parses }, "no rejected \(prefix) value")
            #expect(rows.contains { $0.parses && $0.canonical != $0.input }, "no non-canonical \(prefix) value")
        }
        for literal in ["atproto", "transition:generic", "transition:email", "transition:chat.bsky"] {
            #expect(corpus.value(literal)?.canonical == literal)
        }
    }

    /// `space` is not a resource at the pinned commit, nor in the permission
    /// specification.
    @Test
    func spaceIsNotAResourceUpstream() throws {
        for row in corpus.values where ScopeStringSyntax.isScopeString(row.input, for: "space") {
            #expect(!row.parses)
            #expect(row.isAtprotoOauthScope == false)
        }
        #expect(corpus.values.contains { ScopeStringSyntax.isScopeString($0.input, for: "space") })
    }

    /// Each rejection the schema can produce, and a positive control for
    /// percent-decoding, must stay represented. Recognised by the shape of
    /// the input, so adding rows strengthens the corpus without an edit here.
    @Test
    func everyRejectionClassIsRepresented() {
        // A parameter given both positionally and by name (lib/parser.ts:124-127).
        let positionalKeys = [
            "account": "attr", "identity": "attr", "repo": "collection",
            "rpc": "lxm", "blob": "accept", "include": "nsid",
        ]
        let conflicts = corpus.values.filter { value in
            let input = value.input
            guard let questionMark = input.firstIndex(of: "?") else { return false }
            let head = input[..<questionMark]
            guard let colon = head.firstIndex(of: ":"), head.index(after: colon) < head.endIndex,
                  let key = positionalKeys[String(head[..<colon])]
            else { return false }
            return input[input.index(after: questionMark)...].split(separator: "&").contains { $0.hasPrefix("\(key)=") }
        }
        #expect(Set(conflicts.compactMap { $0.input.split(separator: ":").first.map(String.init) })
            == ["account", "identity", "repo", "rpc", "blob", "include"])
        #expect(conflicts.allSatisfy { !$0.parses })

        // A single-valued parameter given more than once
        // (lib/syntax-string.ts:18-23, lib/parser.ts:121-122).
        let singleValued: Set<String> = ["attr", "aud", "nsid"]
        let repeats = corpus.values.filter { value in
            guard let questionMark = value.input.firstIndex(of: "?") else { return false }
            let keys = value.input[value.input.index(after: questionMark)...]
                .split(separator: "&")
                .compactMap { $0.split(separator: "=").first.map(String.init) }
                .filter(singleValued.contains)
            return Set(keys).count < keys.count
        }
        #expect(repeats.count >= 5)
        #expect(repeats.allSatisfy { !$0.parses })

        // Percent-escaped positionals: at least one decodes and round-trips,
        // and at least one makes the reference implementation throw.
        let escaped = corpus.values.filter { ($0.input.split(separator: "?").first ?? "").contains("%") }
        #expect(escaped.contains { $0.parses && $0.roundTripStable == true })
        #expect(escaped.contains { $0.threw != nil })

        // An unknown parameter, a missing required one, an empty query.
        #expect(corpus.value("identity:*?action=manage")?.parses == false)
        #expect(corpus.value("rpc:app.bsky.feed.getFeed")?.parses == false)
        #expect(corpus.value("identity:*?")?.canonical == "identity:*")
    }

    // MARK: - Internal consistency

    /// `isAtprotoOauthScope` and "the normaliser returned a value" are two
    /// predicates in the reference implementation. They agree on every row
    /// where neither throws.
    @Test
    func recognitionAndParseabilityAgree() {
        for value in corpus.values {
            if value.threw != nil {
                #expect(value.isAtprotoOauthScope == nil && !value.parses, "\(value.input.debugDescription)")
            } else {
                #expect(value.isAtprotoOauthScope == value.parses, "\(value.input.debugDescription)")
            }
        }
    }

    /// The canonical forms that do not parse back to themselves, by name. A
    /// new one is a change in the reference implementation worth reading
    /// before this list is extended.
    @Test
    func roundTripInstabilityIsEnumerated() {
        let unstable = corpus.values.filter { $0.parses && $0.roundTripStable == false }.map(\.input)
        #expect(Set(unstable) == [
            // `+` in a query value is written `%2B`, un-escaped to `+`, and
            // read back as SPACE.
            "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2Bb",
            "blob?accept=image/svg%2Bxml&accept=image/png",
            // `%` in a query value is written `%25`, un-escaped to `%`, and
            // read back as the start of an escape.
            "rpc:app.bsky.feed.getFeed?aud=did:web:example.com%23a%2541",
            "rpc:app.bsky.feed.getFeed?aud=did:web:localhost%253A8080%23svc",
            // A repeated `accept` is de-duplicated after the choice between
            // positional and named form has been made.
            "blob?accept=image/png&accept=image/png",
        ])
    }

    /// Canonical serialisation omits a parameter equal to its default, so the
    /// canonical form cannot say whether the default was written out.
    @Test
    func canonicalFormOmitsDefaults() {
        #expect(corpus.value("repo:app.example.profile?action=create&action=update&action=delete")?.canonical
            == "repo:app.example.profile")
        #expect(corpus.value("account:email?action=read")?.canonical == "account:email")
    }

    // MARK: - matches

    @Test
    func matchOutcomesAreAUsableOracle() {
        let transition = corpus.orderedGrants.flatMap { $0.grant.transition.allAllowed }
        let granular = corpus.orderedGrants.flatMap { $0.grant.granular.allAllowed }
        #expect(!transition.contains(nil) && !granular.contains(nil), "an allows* call threw")
        #expect(transition.contains(true) && transition.contains(false))
        #expect(granular.contains(true) && granular.contains(false))
        // The two classes differ exactly on grants that carry a `transition:` scope.
        for (name, grant) in corpus.orderedGrants {
            let differs = grant.transition.allAllowed != grant.granular.allAllowed
            #expect(differs == grant.scope.contains("transition:"), "\(name)")
        }
        // No grant-less set allows anything.
        #expect(corpus.matches["atprotoOnly"]?.transition.allAllowed.allSatisfy { $0 == false } == true)
        #expect(corpus.matches["empty"]?.transition.allAllowed.allSatisfy { $0 == false } == true)
        #expect(corpus.matches["unparseable"]?.transition.allAllowed.allSatisfy { $0 == false } == true)
    }

    @Test
    func includesCoverTheSpecificationExampleAndEveryIgnoredCase() {
        let names = Set(corpus.includes.map(\.name))
        #expect(names.isSuperset(of: [
            "specExample", "specExampleWithoutAudience", "wildcardsAreNotAllowedInASet",
            "inheritAudAndAudTogether", "resourcesThatMayNotAppearInASet",
            "unexpectedNamesAndValues", "namespaceAuthority", "namespaceAuthorityOneLevelUp",
        ]))
        #expect(corpus.includes.allSatisfy { $0.threw == nil })
        #expect(corpus.includes.contains { $0.scopes?.isEmpty == true })
        #expect(corpus.includes.contains { ($0.scopes?.count ?? 0) > 1 })
    }
}
