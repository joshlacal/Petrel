import Foundation
@testable import PetrelOAuthScopes

/// Typed decoding of `Fixtures/upstream-oauth-scopes.json`, a corpus produced
/// by running the reference implementation's own `@atproto/oauth-scopes`
/// (bluesky-social/atproto) at ``pinnedReferenceCommit``. See
/// `UpstreamGoldens/regenerate.sh`.
///
/// The corpus is the oracle for the scope grammar: where a comment in this
/// package and the corpus disagree about what a scope string parses or
/// canonicalises to, the corpus is right.
///
/// No expectation that reaches an assertion through this type is hand-written.
/// Each is decoded from the JSON, so regenerating the corpus changes what the
/// tests assert with no Swift edit.
struct UpstreamScopeCorpus: Decodable, Sendable {
    /// The reference implementation commit the corpus was generated at.
    static let pinnedReferenceCommit = "0e1042e65d5df27030849167773728b84d469182"

    let referenceRepository: String
    let referenceCommit: String
    let source: String
    let values: [Value]
    let strings: [ScopeString]
    let matches: [String: Grant]
    let missing: [Missing]
    let includes: [Include]
    let authority: [Authority]
    let didRefs: [DIDRef]
    let nsids: [NSIDRow]
    let accepts: [AcceptRow]
    let encoders: [Encoder]

    /// One scope value through `normalizeAtprotoOauthScopeValue`.
    struct Value: Decodable, Sendable {
        let input: String
        /// `isAtprotoOauthScope(input)`; `nil` when that call threw.
        let isAtprotoOauthScope: Bool?
        /// The canonical form, or `nil` when the value was rejected.
        let canonical: String?
        /// The message, when the reference implementation threw instead of
        /// returning `null`: `decodeURIComponent`'s `URIError` on a malformed
        /// escape in a positional.
        let threw: String?
        /// `normalize(canonical) == canonical`; `nil` when the value was
        /// rejected.
        let roundTripStable: Bool?

        var parses: Bool { canonical != nil }
    }

    /// A whole scope string through `normalizeAtprotoOauthScope`.
    struct ScopeString: Decodable, Sendable {
        let input: String
        let normalized: String
    }

    /// `allows*` outcomes for one set of granted scopes.
    struct Grant: Decodable, Sendable {
        let scope: String
        /// `ScopePermissions`: granular permissions only.
        let granular: Outcomes
        /// `ScopePermissionsTransition`: with the `transition:` scopes applied.
        let transition: Outcomes
    }

    struct Outcomes: Decodable, Sendable {
        let repo: [Outcome<RepoArg>]
        let blob: [Outcome<BlobArg>]
        let rpc: [Outcome<RPCArg>]
        let identity: [Outcome<IdentityArg>]
        let account: [Outcome<AccountArg>]

        var allAllowed: [Bool?] {
            repo.map(\.allowed) + blob.map(\.allowed) + rpc.map(\.allowed)
                + identity.map(\.allowed) + account.map(\.allowed)
        }
    }

    struct Outcome<Argument: Decodable & Sendable>: Decodable, Sendable {
        let arg: Argument
        /// `nil` when the call threw instead of returning a boolean.
        let allowed: Bool?
        let threw: String?
    }

    struct RepoArg: Decodable, Sendable {
        let action: String
        let collection: String
    }

    struct BlobArg: Decodable, Sendable {
        let mime: String
    }

    struct RPCArg: Decodable, Sendable {
        let aud: String
        let lxm: String
    }

    struct IdentityArg: Decodable, Sendable {
        let attr: String
    }

    struct AccountArg: Decodable, Sendable {
        let attr: String
        let action: String
    }

    /// The scope a `ScopeMissingError` names for a denied request.
    struct Missing: Decodable, Sendable {
        let resource: String
        let arg: [String: String]
        let scope: String
    }

    /// `IncludeScope.fromString(scope).toScopes(permissionSet)`.
    struct Include: Decodable, Sendable {
        let name: String
        let scope: String
        let permissionSet: LexiconPermissionSet
        let scopes: [String]?
        let threw: String?
    }

    /// `new IncludeScope(nsid).isParentAuthorityOf(other)`.
    struct Authority: Decodable, Sendable {
        let nsid: String
        let other: String
        let isParentAuthority: Bool
    }

    struct DIDRef: Decodable, Sendable {
        let input: String
        let isAtprotoDidRefAbsolute: Bool
    }

    struct NSIDRow: Decodable, Sendable {
        let input: String
        let isNsid: Bool
    }

    struct AcceptRow: Decodable, Sendable {
        let input: String
        let isAccept: Bool
        let isMime: Bool
    }

    /// `encodeURIComponent` against `URLSearchParams`, per input.
    struct Encoder: Decodable, Sendable {
        let raw: String
        let encodeURIComponent: String
        let urlSearchParams: String
    }

    /// Grants in a stable order; `matches` is a JSON object.
    var orderedGrants: [(name: String, grant: Grant)] {
        matches.keys.sorted().map { (name: $0, grant: matches[$0]!) }
    }

    func value(_ input: String) -> Value? {
        values.first { $0.input == input }
    }
}

extension UpstreamScopeCorpus {
    struct MissingFixture: Error {}

    private static let loaded = Result { () throws -> UpstreamScopeCorpus in
        guard let url = Bundle.module.url(
            forResource: "upstream-oauth-scopes", withExtension: "json", subdirectory: "Fixtures"
        ) else { throw MissingFixture() }
        return try JSONDecoder().decode(UpstreamScopeCorpus.self, from: Data(contentsOf: url))
    }

    /// The corpus from the test bundle.
    static func load() throws -> UpstreamScopeCorpus {
        try loaded.get()
    }

    /// The generator script, beside the fixture in the source tree.
    static var generatorURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("UpstreamGoldens/generate.mjs")
    }
}

/// Rows where this package deliberately answers differently from the reference
/// implementation. Each is asserted as a divergence by
/// `UpstreamScopeConformanceTests`, in both directions, so an entry that stops
/// being true fails.
enum UpstreamScopeDivergence {
    /// Accept patterns the reference implementation's `isAccept` allows and
    /// `AcceptPattern` rejects: a `*` inside the type of a `type/*` pattern.
    /// No media type can match one (`isMime` forbids `*`), so nothing is
    /// granted or denied differently; the only effect is that such a `blob:`
    /// scope is invalid here instead of valid and inert. It is not one of the
    /// forms the permission specification lists for `accept`.
    static let rejectedAccepts: Set<String> = ["im*ge/*", "*a/*"]

    /// The scope values that follow from ``rejectedAccepts``.
    static let rejectedValues: Set<String> = ["blob:im*ge/*", "blob:*a/*"]

    /// DID references the reference implementation accepts and
    /// `AtprotoSyntax` rejects: a `did:web` host that percent-decodes to
    /// non-ASCII text, which the WHATWG URL parser would run through IDNA.
    static let rejectedDIDRefs: Set<String> = ["did:web:%C3%A9xample.com#svc"]
}
