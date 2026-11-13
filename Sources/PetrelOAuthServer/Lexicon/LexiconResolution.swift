import Foundation

// Lexicon resolution for `include:` permission sets: the resolver protocol,
// its result types, and the budget that bounds the resolutions of one request.
//
// The protocol is declared here so that the authorization server core can call
// it. The network resolver — DNS `_lexicon` TXT record, DID document,
// `com.atproto.sync.getRecord`, repository proof — is
// `AuthenticatedOAuthLexiconResolver` in the `PetrelOAuthServerLexicon`
// product, which keeps PetrelRepo and the identity layer out of this target.
//
// Reference implementation: `packages/lex/lex-resolver/src/lex-resolver.ts`.

// MARK: - OAuthLexiconDocument

/// What the `main` definition of an authenticated `com.atproto.lexicon.schema`
/// record turned out to be.
///
/// The reference implementation rejects an `include:` whose document is not a
/// permission set (`packages/oauth/oauth-provider/src/lexicon/lexicon-manager.ts:69-72`,
/// "Lexicon document is not a permission set"), so the distinction has to
/// survive resolution.
public enum OAuthLexiconDocument: Sendable, Equatable {
    /// `defs.main` is a permission set.
    case permissionSet(LexiconPermissionSet)
    /// The record is authentic and schema-valid, but `defs.main` is absent or
    /// is some other kind of definition. This is a successful resolution: the
    /// document was established as belonging to the authority's signed
    /// repository, and fetching it again would establish the same thing. The
    /// caller decides what it means; for an `include:` it is `invalid_scope`.
    case other
}

// MARK: - OAuthLexiconResolution

/// The outcome of one resolution attempt, including the negative one.
public enum OAuthLexiconResolution: Sendable, Equatable {
    /// The document was fetched and its proof verified. The three values
    /// mirror `LexResolverResult` (`lex-resolver.ts:37-44`): `lexicon`, `uri`
    /// and `cid`.
    ///
    /// `sourceURI` is `at://<did>/com.atproto.lexicon.schema/<nsid>`. Its DID
    /// is the authority the DNS TXT record selected, which the NSID alone does
    /// not determine once that record changes.
    ///
    /// `verifiedCID` is the CID the Merkle search tree lookup resolved to
    /// (`lex-resolver.ts:545`): the content address the proof ended at, and
    /// the one value that ties the document to the signed commit.
    case resolved(OAuthLexiconDocument, sourceURI: String, verifiedCID: String)

    /// The resolver failed in an expected way: one of the conditions
    /// ``OAuthLexiconResolverFailure`` lists. This is the reference
    /// implementation's `LexResolverError` branch
    /// (`packages/oauth/oauth-provider/src/lexicon/lexicon-getter.ts:19-27`),
    /// and it may be cached.
    ///
    /// Anything else — a programming error, a cancellation, a storage fault —
    /// is thrown, not reported as this case. Reporting an arbitrary error as
    /// `unresolvable` would cache "this lexicon does not exist" on the
    /// strength of a bug.
    case unresolvable
}

/// The closed set of ways resolution can fail that mean "the authority's
/// document could not be established". These are the conditions the reference
/// implementation wraps in `LexResolverError`
/// (`packages/lex/lex-resolver/src/lex-resolver-error.ts:41-77`).
///
/// A resolver throws one of these from its steps and converts only these into
/// ``OAuthLexiconResolution/unresolvable``; every other error propagates.
///
/// None of these is an "ignored entry". The permission specification has a
/// resolver ignore individual declarations inside a permission set that it
/// does not understand; a failure here means there is no authenticated set to
/// ignore entries of. If a proof failure were handled like an ignored entry,
/// the host serving the record could choose which of a user's requested
/// permissions survive by corrupting proofs selectively.
///
/// ## Cancellation is not a failure
///
/// Every case here may be cached as a negative result: it says the authority
/// could not be reached or its document could not be authenticated.
/// Cancellation says neither. When a group of resolutions shares a deadline
/// and one slow authority exhausts it, the others are cancelled, and caching
/// those cancellations would let one authority make the others' permission
/// sets unavailable. So there is deliberately no `cancelled` case: a resolver
/// checks `Task.isCancelled` and rethrows `CancellationError`, whatever error
/// the interrupted operation surfaced.
public enum OAuthLexiconResolverFailure: Error, Sendable, Equatable {
    // Steps 1-4: selecting the authority.

    /// Step 1: not a syntactically valid NSID.
    case invalidNSID
    /// Step 2: the DNS TXT lookup failed (`lex-resolver.ts:354-359`).
    case dnsUnavailable
    /// Step 3: no `did=` line ("No DID found in DNS TXT records").
    case noAuthorityDIDInTXT
    /// Step 3: more than one `did=` line ("Multiple DIDs found in DNS TXT
    /// records"). The first one is not used.
    case multipleAuthorityDIDsInTXT
    /// Step 3: the text after `did=` is not a DID.
    case invalidAuthorityDIDInTXT

    // Steps 5-6: the DID document.

    /// Step 5: the DID document could not be resolved (`lex-resolver.ts:427-432`),
    /// or the DID is of a method the resolver does not accept.
    case authorityDocumentUnavailable
    /// Step 6: the DID document has no PDS endpoint or no `atproto` signing
    /// key (`lex-resolver.ts:434-439`).
    case authorityDocumentIncomplete

    // Step 7: the fetch.

    /// The `com.atproto.sync.getRecord` request failed
    /// (`lex-resolver.ts:465-469`), ran past its deadline, or returned more
    /// than ``OAuthLexiconResolutionBudget/maximumCARBytes``.
    case recordFetchFailed

    // Steps 8-13: the proof.

    /// Step 8: the CAR does not have exactly one root.
    case carRootCountInvalid
    /// Step 9: the root block is not a repository commit.
    case commitDecodeFailed
    /// Step 10: `commit.did` is not the resolved DID (`lex-resolver.ts:533-535`,
    /// "Invalid repo did"). This is a commit from another repository.
    case commitDIDMismatch
    /// Step 11: the signature does not verify under the key in the DID
    /// document (`lex-resolver.ts:537-541`, "Invalid signature on commit").
    case commitSignatureInvalid
    /// Step 12: the record is not reachable from `commit.data` through the
    /// Merkle search tree (`lex-resolver.ts:543-546`, "Record not found in
    /// proof"). A proof with a missing node is reported the same way as proven
    /// absence, so that omitting blocks cannot select between two outcomes.
    case recordNotInProof
    /// Step 13: the record's `$type` is not `com.atproto.lexicon.schema`
    /// (`lex-resolver.ts:548-553`, "Invalid record type"), or the record does
    /// not decode.
    case recordTypeMismatch

    // Steps 14-15: the document.

    /// Step 14: the record is not a valid Lexicon document
    /// (`lex-resolver.ts:472-477`).
    case documentSchemaInvalid
    /// Step 15: the document's `id` is not the record key
    /// (`lex-resolver.ts:480-485`).
    case documentIDMismatch
}

// MARK: - OAuthLexiconResolving

/// Resolves the NSID of a Lexicon schema to its authenticated document.
///
/// A conforming type performs all fifteen steps below, **including the proof
/// (steps 8 to 13)**. A resolver that fetches the record and skips the proof
/// turns whatever an HTTP response says into the permissions an OAuth grant
/// expands to, which is privilege escalation by lying in a response body. An
/// implementation without the proof does not partially conform to this
/// protocol; it does not conform.
///
/// 1. Parse the NSID and take its authority, the reversed domain name.
/// 2. Look up DNS `TXT _lexicon.<authority>`.
/// 3. Keep the values starting `did=`, and require exactly one. None is a
///    failure and so is more than one.
/// 4. Form `at://<did>/com.atproto.lexicon.schema/<nsid>`. The collection is
///    fixed; no caller supplies it.
/// 5. Resolve the DID document, reading both the PDS endpoint and the
///    `atproto` verification method from that one document.
/// 6. Fail if either is missing.
/// 7. Call `com.atproto.sync.getRecord` on the PDS named by the DID document,
///    never on a host a caller supplied, and take the CAR it returns.
/// 8. **Proof:** the CAR has exactly one root. A second root could carry
///    another commit past a reader that takes the first.
/// 9. **Proof:** the root block decodes as a commit, before anything in it is
///    trusted.
/// 10. **Proof:** `commit.did` is the DID resolved in step 3, not one the
///     response supplied. Otherwise a correctly signed commit of someone
///     else's repository would pass.
/// 11. **Proof:** the commit signature verifies under the key from the DID
///     document, never a key from the response.
/// 12. **Proof:** the record is reachable from `commit.data` through the
///     Merkle search tree. A block that is merely present in the CAR proves
///     nothing.
/// 13. **Proof:** the record's `$type` is `com.atproto.lexicon.schema`.
/// 14. The record is a valid Lexicon document.
/// 15. The document's `id` equals the record key. Otherwise a validly signed
///     schema for a different NSID could be stored under the expected key.
///
/// Trust runs from the DID document, through the commit signature and Merkle
/// search tree membership, to the record bytes. It never comes from the server
/// having returned something.
public protocol OAuthLexiconResolving: Sendable {
    /// Resolves and authenticates the Lexicon schema `nsid`.
    ///
    /// - Returns: ``OAuthLexiconResolution/resolved(_:sourceURI:verifiedCID:)``,
    ///   or ``OAuthLexiconResolution/unresolvable`` for a failure listed in
    ///   ``OAuthLexiconResolverFailure``.
    /// - Throws: any other error, including `CancellationError`.
    func resolve(_ nsid: String) async throws -> OAuthLexiconResolution
}

// MARK: - Budget

/// A kind of NSID that one request resolves as a group.
public enum OAuthLexiconResolutionPopulation: Sendable, Equatable {
    /// The NSIDs of the request's `include:` scopes.
    case includes

    /// The largest number of distinct NSIDs one request may resolve.
    public var maximumDistinctNSIDs: Int {
        switch self {
        case .includes: return OAuthLexiconResolutionBudget.maximumIncludeNSIDs
        }
    }
}

/// Limits on the work one request can cause by naming permission sets.
///
/// These bound what the server does after it has accepted the request's bytes.
/// A scope such as `include:com.example.authFull` is short on the wire, and
/// resolving and expanding it is not; a limit on request size alone does not
/// bound it.
///
/// The limits cover CPU as well as time. Parsing a CAR, verifying a commit
/// signature and walking a Merkle search tree are not network operations, and
/// a deadline on the network does not bound them; a limit on the size of the
/// response does.
public enum OAuthLexiconResolutionBudget: Sendable {
    /// The largest number of distinct `include:` NSIDs in one request.
    public static let maximumIncludeNSIDs = 4

    /// The deadline for one DNS TXT lookup. Deadlines apply per step, not per
    /// include.
    public static let dnsDeadlineSeconds: Double = 2
    /// The deadline for resolving one DID document.
    public static let didDocumentDeadlineSeconds: Double = 3
    /// The deadline for one `com.atproto.sync.getRecord` request.
    public static let recordFetchDeadlineSeconds: Double = 5

    /// The deadline for all of one request's resolutions together. Resolutions
    /// run concurrently under this single deadline.
    public static let groupDeadlineSeconds: Double = 10

    /// The largest CAR a resolver accepts from `com.atproto.sync.getRecord`.
    ///
    /// The proof of a single record is one commit block and one path through
    /// the Merkle search tree, a few kibibytes. The cap bounds the parsing,
    /// tree-walking and signature work a response can cause.
    public static let maximumCARBytes = 256 * 1_024

    /// The age at which a cached document is refreshed: five minutes, the
    /// reference implementation's `LEXICON_REFRESH_FREQUENCY`
    /// (`packages/oauth/oauth-provider/src/constants.ts:78`). A document older
    /// than this is fetched again; if that fails, the cached one is still used.
    public static let refreshThresholdSeconds: Double = 5 * 60

    /// The age, measured from the last successful resolution, past which a
    /// cached document is no longer used and the permission set counts as
    /// unresolved.
    ///
    /// The permissions of a session are recomputed when its tokens are
    /// refreshed. Without an upper bound, a permission set that its publisher
    /// has since narrowed would keep granting the wider permissions for as
    /// long as the resolver could not reach the authority. Twenty-four hours
    /// is the bound the permission specification gives for the lifetime of a
    /// stale cache entry.
    public static let hardExpirySeconds: Double = 24 * 60 * 60
}

/// A request exceeded ``OAuthLexiconResolutionBudget``.
///
/// Both cases are properties of the request, not of any authority. The caller
/// chooses the OAuth error code: `invalid_scope` when the scope is requested,
/// `invalid_request` when a token is issued.
public enum OAuthLexiconResolutionBudgetError: Error, Sendable, Equatable {
    /// The request names more distinct NSIDs than the population allows.
    case tooManyDistinctNSIDs(OAuthLexiconResolutionPopulation, requested: Int)
    /// The resolutions did not all finish within
    /// ``OAuthLexiconResolutionBudget/groupDeadlineSeconds``.
    case groupDeadlineExceeded
}

public extension OAuthLexiconResolving {
    /// Resolves every NSID in `nsids` concurrently, under the limits of
    /// ``OAuthLexiconResolutionBudget``.
    ///
    /// Duplicates are removed before the count is checked: the limit is on
    /// distinct NSIDs.
    ///
    /// - Throws: ``OAuthLexiconResolutionBudgetError`` when the request is
    ///   over a limit. That is thrown rather than reported as
    ///   ``OAuthLexiconResolution/unresolvable`` so that it is never cached
    ///   against an NSID.
    func resolveAll(
        _ nsids: some Sequence<String>,
        population: OAuthLexiconResolutionPopulation
    ) async throws -> [String: OAuthLexiconResolution] {
        let distinct = Array(Set(nsids)).sorted()
        guard distinct.count <= population.maximumDistinctNSIDs else {
            throw OAuthLexiconResolutionBudgetError.tooManyDistinctNSIDs(
                population, requested: distinct.count
            )
        }
        guard !distinct.isEmpty else { return [:] }
        return try await OAuthLexiconDeadline.run(
            seconds: OAuthLexiconResolutionBudget.groupDeadlineSeconds,
            onExpiry: OAuthLexiconResolutionBudgetError.groupDeadlineExceeded
        ) { [self] in
            try await withThrowingTaskGroup(
                of: (String, OAuthLexiconResolution).self
            ) { group in
                for nsid in distinct {
                    group.addTask { (nsid, try await self.resolve(nsid)) }
                }
                var results: [String: OAuthLexiconResolution] = [:]
                for try await (nsid, resolution) in group {
                    results[nsid] = resolution
                }
                return results
            }
        }
    }
}

// MARK: - Deadline

/// A wall-clock deadline for one step or one group of resolutions.
public enum OAuthLexiconDeadline: Sendable {
    /// Runs `operation`, throwing `expiry` if it has not finished after
    /// `seconds`.
    ///
    /// When the deadline passes the operation is cancelled, so that it does
    /// not keep a network read running past the deadline that was meant to
    /// bound it.
    public static func run<T: Sendable>(
        seconds: Double,
        onExpiry expiry: any Error,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await oauthRaceWithDeadline(
            seconds: seconds,
            onExpiry: expiry,
            operation: operation
        )
    }
}
