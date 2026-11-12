import Foundation
import Petrel
import PetrelCrypto
import PetrelLexicon
import PetrelOAuthScopes
import PetrelOAuthServer
import PetrelRepo

/// The network ``OAuthLexiconResolving``: all fifteen steps the protocol lists,
/// including the repository proof.
///
/// This ports the reference implementation's `LexResolver`
/// (`packages/lex/lex-resolver/src/lex-resolver.ts`):
///
/// 1. The NSID's authority domain is looked up as DNS `TXT _lexicon.<domain>`,
///    which must hold exactly one `did=` line.
/// 2. The DID document names the PDS and the `#atproto` signing key.
/// 3. `com.atproto.sync.getRecord` returns a CAR with the signed commit and the
///    Merkle search tree path to the `com.atproto.lexicon.schema/<nsid>` record.
/// 4. The commit must be for the resolved DID and signed by the document's key,
///    the record must be reachable from the signed `data` root, and the record
///    must be a valid Lexicon document whose `id` is the NSID.
///
/// The trust chain runs from DNS and the DID document through the commit
/// signature and tree membership to the record bytes. Nothing the PDS says is
/// trusted on its own.
///
/// Every network fetch, including `did:web` documents, goes through one
/// ``OAuthRemoteDocumentFetcher``. It enforces the server's outbound policy:
/// HTTPS, public addresses only, a pinned connection, no redirects, bounded time
/// and size. Its body limit must be at most
/// ``OAuthLexiconResolutionBudget/maximumCARBytes``, which bounds the parsing,
/// tree walking and signature work a response can cause.
///
/// Wrap it in ``CachingOAuthLexiconResolver`` for the specification's cache
/// lifetimes:
///
/// ```swift
/// let fetcher = OAuthRemoteDocumentFetcher(
///     policy: try OAuthRemoteFetchPolicy(), // 256 KiB body limit by default
///     transport: pinnedTransport
/// )
/// let lexicons = CachingOAuthLexiconResolver(
///     upstream: try AuthenticatedOAuthLexiconResolver(fetcher: fetcher),
///     cache: store
/// )
/// ```
public struct AuthenticatedOAuthLexiconResolver: OAuthLexiconResolving {
    private let dns: any IdentityDNSResolver
    private let authorities: any OAuthLexiconAuthorityResolving
    private let fetcher: OAuthRemoteDocumentFetcher
    private let authorityCache: OAuthLexiconAuthorityCache
    private let clock: any OAuthClock
    private let deadlines: Deadlines

    /// Per-step deadlines. Tests stretch them so a loaded machine cannot fail a
    /// fake that answers immediately.
    struct Deadlines: Sendable {
        var dns = OAuthLexiconResolutionBudget.dnsDeadlineSeconds
        var didDocument = OAuthLexiconResolutionBudget.didDocumentDeadlineSeconds
        var recordFetch = OAuthLexiconResolutionBudget.recordFetchDeadlineSeconds
    }

    /// The largest number of TXT answers read for one `_lexicon` name.
    static let maximumTXTRecords = 128

    /// Creates a resolver.
    ///
    /// - Parameters:
    ///   - fetcher: performs `com.atproto.sync.getRecord`, and by default the
    ///     DID document fetches too. Its policy's body limit must be at most
    ///     ``OAuthLexiconResolutionBudget/maximumCARBytes``.
    ///   - dns: looks up `_lexicon.<authority>`. Defaults to the system
    ///     resolver.
    ///   - authorities: resolves the authority DID (steps 5 and 6). Defaults to
    ///     an ``IdentityOAuthLexiconAuthorityResolver`` whose `IdentityResolver`
    ///     fetches through `fetcher`.
    ///   - clock: the time source for the authority cache.
    /// - Throws: ``OAuthLexiconResolverConfigurationError`` when the fetch
    ///   policy admits larger responses.
    public init(
        fetcher: OAuthRemoteDocumentFetcher,
        dns: any IdentityDNSResolver = SystemIdentityDNSResolver(),
        authorities: (any OAuthLexiconAuthorityResolving)? = nil,
        clock: any OAuthClock = SystemOAuthClock()
    ) throws {
        try self.init(
            fetcher: fetcher, dns: dns, authorities: authorities, clock: clock, deadlines: Deadlines()
        )
    }

    init(
        fetcher: OAuthRemoteDocumentFetcher,
        dns: any IdentityDNSResolver,
        authorities: (any OAuthLexiconAuthorityResolving)?,
        clock: any OAuthClock,
        deadlines: Deadlines
    ) throws {
        guard fetcher.policy.maximumBodyBytes <= OAuthLexiconResolutionBudget.maximumCARBytes else {
            throw OAuthLexiconResolverConfigurationError.fetchPolicyTooPermissive(
                maximumBodyBytes: fetcher.policy.maximumBodyBytes
            )
        }
        self.fetcher = fetcher
        self.dns = dns
        self.authorities = authorities ?? IdentityOAuthLexiconAuthorityResolver(
            identity: IdentityResolver(httpTransport: OAuthRemoteIdentityHTTPTransport(fetcher: fetcher))
        )
        self.clock = clock
        self.deadlines = deadlines
        authorityCache = OAuthLexiconAuthorityCache()
    }

    /// Resolves and authenticates the Lexicon schema `nsid`.
    ///
    /// - Returns: `.resolved` with the document, its `at://` URI and the CID the
    ///   proof ended at, or `.unresolvable` for any failure listed in
    ///   ``OAuthLexiconResolverFailure``.
    /// - Throws: `CancellationError`, and nothing else.
    public func resolve(_ nsid: String) async throws -> OAuthLexiconResolution {
        do {
            return try await performResolution(nsid)
        } catch is OAuthLexiconResolverFailure {
            try Task.checkCancellation()
            return .unresolvable
        }
    }

    /// Runs the fifteen steps, throwing the ``OAuthLexiconResolverFailure``
    /// that stopped them. Exposed for tests and diagnostics.
    func performResolution(_ nsid: String) async throws -> OAuthLexiconResolution {
        // Step 1.
        let domain: String
        do {
            domain = try LexiconAuthority.domain(for: nsid)
        } catch {
            throw OAuthLexiconResolverFailure.invalidNSID
        }
        // Steps 2-6.
        let (did, authority) = try await resolveAuthority(domain: domain)
        // Step 4: the collection is fixed.
        let path: PublicRepositoryPath
        do {
            path = try PublicRepositoryPath(collection: lexiconSchemaCollection, recordKey: nsid)
        } catch {
            try Self.classify(error, as: .invalidNSID)
        }
        let sourceURI = LexiconAuthority.recordURI(did: did, nsid: nsid)
        // Step 7.
        let car = try await fetchProofCAR(pds: authority.pdsEndpoint, did: did, nsid: nsid)
        // Steps 8-13.
        let (recordCID, recordBytes) = try await verifyRecordProof(
            car: car, did: did, path: path, key: authority.signingKey
        )
        // Steps 14-15.
        let document = try Self.decodeDocument(recordBytes, nsid: nsid)
        return .resolved(document, sourceURI: sourceURI, verifiedCID: recordCID.string)
    }

    // MARK: - Failure classification

    /// Reports `failure` for `error`, unless the task was cancelled. A
    /// cancelled step often surfaces as some other error (the fetcher wraps
    /// it), and reporting it as a failure would let a caller cache "this
    /// lexicon does not resolve" for an NSID that never failed.
    private static func classify(_ error: any Error, as failure: OAuthLexiconResolverFailure) throws -> Never {
        if error is CancellationError { throw CancellationError() }
        try Task.checkCancellation()
        if let known = error as? OAuthLexiconResolverFailure { throw known }
        throw failure
    }

    // MARK: - Steps 2-6

    private func resolveAuthority(domain: String) async throws -> (String, OAuthLexiconAuthority) {
        if let cached = await authorityCache.value(for: domain, now: clock.now()) {
            return (cached.did, cached.authority)
        }
        let did = try await resolveAuthorityDID(domain: domain)
        let authority: OAuthLexiconAuthority
        do {
            authority = try await OAuthLexiconDeadline.run(
                seconds: deadlines.didDocument,
                onExpiry: OAuthLexiconResolverFailure.authorityDocumentUnavailable
            ) { [authorities] in
                try await authorities.resolveAuthority(did: did)
            }
        } catch OAuthLexiconAuthorityError.documentIncomplete {
            throw OAuthLexiconResolverFailure.authorityDocumentIncomplete
        } catch {
            try Self.classify(error, as: .authorityDocumentUnavailable)
        }
        await authorityCache.store(domain: domain, did: did, authority: authority, now: clock.now())
        return (did, authority)
    }

    /// Steps 2 and 3. Exactly one `did=` line; two identical lines are still
    /// two (`lex-resolver.ts:507-519`). Under "first wins" or deduplication,
    /// whoever can add a TXT record would decide the authority by answer order.
    private func resolveAuthorityDID(domain: String) async throws -> String {
        let records: [String]
        do {
            records = try await OAuthLexiconDeadline.run(
                seconds: deadlines.dns,
                onExpiry: OAuthLexiconResolverFailure.dnsUnavailable
            ) { [dns] in
                try await dns.queryTXT(name: "_lexicon.\(domain)")
            }
        } catch {
            try Self.classify(error, as: .dnsUnavailable)
        }
        guard records.count <= Self.maximumTXTRecords else {
            throw OAuthLexiconResolverFailure.dnsUnavailable
        }
        let lines = records.filter { $0.hasPrefix("did=") }
        guard let line = lines.first else {
            throw OAuthLexiconResolverFailure.noAuthorityDIDInTXT
        }
        guard lines.count == 1 else {
            throw OAuthLexiconResolverFailure.multipleAuthorityDIDsInTXT
        }
        let value = String(line.dropFirst("did=".count))
        guard (try? DID(didString: value)) != nil else {
            throw OAuthLexiconResolverFailure.invalidAuthorityDIDInTXT
        }
        return value
    }

    // MARK: - Step 7

    /// `com.atproto.sync.getRecord`, never `com.atproto.repo.getRecord`: only
    /// the former returns the signed commit and the tree path that tie the
    /// record to the authority's key.
    private func fetchProofCAR(pds: URL, did: String, nsid: String) async throws -> Data {
        guard var components = URLComponents(url: pds, resolvingAgainstBaseURL: false) else {
            throw OAuthLexiconResolverFailure.authorityDocumentIncomplete
        }
        var path = components.percentEncodedPath
        if path.hasSuffix("/") { path.removeLast() }
        components.percentEncodedPath = path + "/xrpc/com.atproto.sync.getRecord"
        components.fragment = nil
        components.queryItems = [
            URLQueryItem(name: "did", value: did),
            URLQueryItem(name: "collection", value: lexiconSchemaCollection),
            URLQueryItem(name: "rkey", value: nsid),
        ]
        guard let url = components.url else {
            throw OAuthLexiconResolverFailure.authorityDocumentIncomplete
        }
        let bytes: Data
        do {
            bytes = try await OAuthLexiconDeadline.run(
                seconds: deadlines.recordFetch,
                onExpiry: OAuthLexiconResolverFailure.recordFetchFailed
            ) { [fetcher] in
                try await fetcher.fetchBytes(from: url)
            }
        } catch {
            try Self.classify(error, as: .recordFetchFailed)
        }
        // The fetcher's policy already caps this (checked at construction);
        // the CPU spent below is what the cap protects, so assert it here too.
        guard !bytes.isEmpty, bytes.count <= OAuthLexiconResolutionBudget.maximumCARBytes else {
            throw OAuthLexiconResolverFailure.recordFetchFailed
        }
        return bytes
    }

    // MARK: - Steps 8-13

    /// `verifyRecordProof` (`lex-resolver.ts:522-556`), in the same order.
    /// `commit.did` is compared before the signature is checked, so a commit
    /// from another repository is refused by the equality itself.
    private func verifyRecordProof(
        car: Data,
        did: String,
        path: PublicRepositoryPath,
        key: ATProtoPublicKey
    ) async throws -> (CID, Data) {
        // Step 8. The parser accepts only the canonical one-root header, so a
        // second root fails the parse instead of being ignored.
        let sink = ProofCARSink()
        let parsed: PublicRepositoryCARParseResult
        do {
            parsed = try await PublicRepositoryCAR.parseIncrementally(
                from: ProofCARByteSource(bytes: car), to: sink
            )
        } catch {
            try Self.classify(error, as: .carRootCountInvalid)
        }
        let blocks: PublicRepositoryBlockMap
        do {
            blocks = try await sink.blockMap()
        } catch {
            try Self.classify(error, as: .carRootCountInvalid)
        }
        guard let commitBytes = try await blocks.block(for: parsed.rootCID) else {
            throw OAuthLexiconResolverFailure.commitDecodeFailed
        }

        // Step 9: structure before trust.
        let structural: StructurallyValidatedPublicRepositorySignedCommit
        do {
            structural = try PublicRepositoryCommitCodec.structurallyValidate(
                signedCommitBytes: commitBytes, expectedCommitCID: parsed.rootCID
            )
        } catch {
            try Self.classify(error, as: .commitDecodeFailed)
        }

        // Step 10: the resolved DID, not one the response chose.
        guard structural.descriptor.did == did else {
            throw OAuthLexiconResolverFailure.commitDIDMismatch
        }

        // Step 11: the key from the DID document.
        let verified: VerifiedPublicRepositorySignedCommit
        do {
            verified = try await PublicRepositoryCommitCodec.verify(
                signedCommitBytes: commitBytes,
                expectedCommitCID: parsed.rootCID,
                verifier: OAuthLexiconCommitVerifier(publicKey: key)
            )
        } catch {
            try Self.classify(error, as: .commitSignatureInvalid)
        }

        // Step 12: reachable from the signed `data` root. Proven absence (nil)
        // and a withheld node (throws) get the same answer, so that omitting
        // blocks cannot choose between them.
        let recordCID: CID?
        do {
            recordCID = try await RepositoryMSTProof.membership(
                rootCID: verified.descriptor.dataCID, path: path, blocks: blocks
            )
        } catch {
            try Self.classify(error, as: .recordNotInProof)
        }
        guard let recordCID, let recordBytes = try await blocks.block(for: recordCID) else {
            throw OAuthLexiconResolverFailure.recordNotInProof
        }

        // Step 13. The parser has already checked the bytes against the CID.
        let record: LexValue
        do {
            record = try LexValue(dagCBOR: recordBytes)
        } catch {
            try Self.classify(error, as: .recordTypeMismatch)
        }
        guard record.type == lexiconSchemaCollection else {
            throw OAuthLexiconResolverFailure.recordTypeMismatch
        }
        return (recordCID, recordBytes)
    }

    // MARK: - Steps 14-15

    /// Step 14: the record is a valid Lexicon document
    /// (`lexiconDocumentSchema`, `lex-resolver.ts:472-477`). Step 15: its `id`
    /// is the record key (`:480-485`); otherwise a validly signed schema for a
    /// different NSID, stored under this key, would pass every proof.
    static func decodeDocument(_ recordBytes: Data, nsid: String) throws -> OAuthLexiconDocument {
        let record: LexValue
        let document: LexiconDoc
        do {
            record = try LexValue(dagCBOR: recordBytes)
            document = try LexiconDoc(record, options: .strict)
        } catch {
            try classify(error, as: .documentSchemaInvalid)
        }
        guard document.id == nsid else {
            throw OAuthLexiconResolverFailure.documentIDMismatch
        }
        guard case .permissionSet = document.main, let main = record["defs"]?["main"] else {
            // Authentic and valid, but not a permission set: a success that
            // grants nothing (`lexicon-manager.ts:69-72` decides what it means).
            return .other
        }
        do {
            let set = try JSONDecoder().decode(LexiconPermissionSet.self, from: main.jsonData())
            return .permissionSet(set)
        } catch {
            try classify(error, as: .documentSchemaInvalid)
        }
    }
}

/// A resolver was configured in a way that would remove one of its limits.
public enum OAuthLexiconResolverConfigurationError: Error, Sendable, Equatable {
    /// The fetcher's policy admits responses larger than
    /// ``OAuthLexiconResolutionBudget/maximumCARBytes``. That cap bounds the CPU
    /// a proof can cost, and the fetcher is what enforces it.
    case fetchPolicyTooPermissive(maximumBodyBytes: Int)
}

// MARK: - CAR plumbing

/// Feeds an in-memory, already size-bounded CAR to the streaming parser, so the
/// proof goes through the same framing rules as any repository import.
private actor ProofCARByteSource: PublicRepositoryCARByteSource {
    private let bytes: Data
    private var offset: Int

    init(bytes: Data) {
        self.bytes = bytes
        offset = bytes.startIndex
    }

    func read(maximumBytes: Int) async throws -> Data? {
        guard offset < bytes.endIndex else { return nil }
        let end = min(bytes.endIndex, offset + max(1, maximumBytes))
        defer { offset = end }
        return Data(bytes[offset ..< end])
    }
}

/// Collects the parsed blocks. Each one has had its CID checked against its
/// bytes by the parser.
private actor ProofCARSink: PublicRepositoryCARFrameSink {
    private var collected: [PublicRepositoryBlock] = []

    func receiveHeader(rootCID _: CID, receivedByteCount _: Int) async throws {}

    func receiveBlock(_ block: PublicRepositoryBlock, receivedByteCount _: Int, frameCount _: Int) async throws {
        collected.append(block)
    }

    func blockMap() throws -> PublicRepositoryBlockMap {
        try PublicRepositoryBlockMap(
            blocks: collected, maximumRelevantBytes: OAuthLexiconResolutionBudget.maximumCARBytes
        )
    }
}

// MARK: - Authority cache

/// Steps 1-6 keyed by authority domain, so several sets under one authority
/// share one DNS and DID lookup. It caches the DID document's PDS and key, never
/// a proof: every resolution verifies the proof again under the key the
/// document currently names.
private actor OAuthLexiconAuthorityCache {
    struct Entry: Sendable {
        let did: String
        let authority: OAuthLexiconAuthority
        let storedAt: Date
    }

    private static let capacity = 256
    private var entries: [String: Entry] = [:]

    func value(for domain: String, now: Date) -> Entry? {
        guard let entry = entries[domain] else { return nil }
        let age = now.timeIntervalSince(entry.storedAt)
        guard age >= 0, age < OAuthLexiconResolutionBudget.refreshThresholdSeconds else {
            entries[domain] = nil
            return nil
        }
        return entry
    }

    func store(domain: String, did: String, authority: OAuthLexiconAuthority, now: Date) {
        if entries[domain] == nil, entries.count >= Self.capacity,
           let oldest = entries.min(by: { $0.value.storedAt < $1.value.storedAt })?.key
        {
            // Evict rather than stop caching: naming many authorities must not
            // turn the cache off for everyone.
            entries[oldest] = nil
        }
        entries[domain] = Entry(did: did, authority: authority, storedAt: now)
    }
}
