import Foundation
import Petrel
import PetrelCrypto
@testable import PetrelRepo
import Testing

/// The firehose event verifiers' own checks (future revisions, operation and
/// size bounds) and the identity-backed key resolvers they are meant to use.
///
/// Every time is fixed: the commits are signed at a set revision and the
/// verifier is handed `now`, so nothing depends on the machine's clock.
@Suite("Repository event verification")
struct RepositoryEventVerificationTests {
    private let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    private let posts = "app.bsky.feed.post"
    /// 2030-01-01T00:00:00Z: the time every test commit is signed at.
    private let signedAt = Date(timeIntervalSince1970: 1_893_456_000)

    private struct Event {
        let car: Data
        let commitCID: CID
        let revision: String
        let operations: [RepositoryCommitOperation]
        let previousDataCID: CID
        let commitBlock: PublicRepositoryBlock
    }

    /// A one-record `#commit` event, signed by `signer` at ``signedAt``.
    private func event(signer: K256Keypair, records: Int = 1) async throws -> Event {
        let empty = try await Repository.create(
            did: did, signer: signer,
            revision: try PublicRepositoryTID.next(after: nil, now: signedAt - 60)
        )
        let writes = try (0 ..< records).map { index in
            PublicRepositoryWrite.create(
                path: try PublicRepositoryPath(collection: posts, recordKey: "r\(index)"),
                record: .sample(posts, text: "\(index)")
            )
        }
        let result = try await empty.commit(
            writes, signer: signer, revision: try PublicRepositoryTID.next(after: nil, now: signedAt)
        )
        return Event(
            car: try await result.diffCAR(),
            commitCID: result.repository.commit.cid,
            revision: result.repository.commit.revision.value,
            operations: result.operations,
            previousDataCID: result.previousDataCID,
            commitBlock: PublicRepositoryBlock(
                cid: result.repository.commit.cid, bytes: result.repository.commit.bytes
            )
        )
    }

    private func verify(
        _ event: Event,
        keys: any RepositorySigningKeyResolver,
        limits: PublicRepositoryLimits = .standard,
        now: Date,
        skew: TimeInterval = 300
    ) async throws -> VerifiedRepositoryCommitDiff {
        try await RepositoryCommitDiff.verifyCommitEvent(
            blocks: event.car, commitCID: event.commitCID, did: did, revision: event.revision,
            operations: event.operations, previousDataCID: event.previousDataCID,
            keyResolver: keys, limits: limits, now: now, maximumClockSkew: skew
        )
    }

    // MARK: Future revisions (sync.mdx: reject a rev with a future timestamp)

    @Test("a #commit whose rev is beyond the clock skew is refused before any key lookup")
    func commitInFuture() async throws {
        let signer = K256Keypair.generate()
        let event = try await event(signer: signer)
        let keys = CountingKeys(signer.publicKey)

        // Exactly at the skew, and anywhere inside it, is accepted.
        _ = try await verify(event, keys: keys, now: signedAt)
        _ = try await verify(event, keys: keys, now: signedAt - 300)
        let lookups = keys.lookups

        await #expect(throws: RepositoryCommitDiffError.revisionInFuture(revision: event.revision)) {
            _ = try await self.verify(event, keys: keys, now: self.signedAt - 301)
        }
        await #expect(throws: RepositoryCommitDiffError.revisionInFuture(revision: event.revision)) {
            _ = try await self.verify(event, keys: keys, now: self.signedAt - 3_600)
        }
        #expect(keys.lookups == lookups, "a future event never reaches the resolver")

        // The skew is the caller's: one hour of tolerance admits it.
        _ = try await verify(event, keys: keys, now: signedAt - 3_600, skew: 3_600)
    }

    @Test("a #sync whose rev is beyond the clock skew is refused before any key lookup")
    func syncInFuture() async throws {
        let signer = K256Keypair.generate()
        let event = try await event(signer: signer)
        let car = try await PublicRepositoryCAR.encode(rootCID: event.commitCID, blocks: [event.commitBlock])
        let keys = CountingKeys(signer.publicKey)

        let commit = try await RepositoryCommitDiff.verifySyncEvent(
            blocks: car, did: did, revision: event.revision, keyResolver: keys, now: signedAt
        )
        #expect(commit.descriptor.revision.value == event.revision)
        let lookups = keys.lookups
        await #expect(throws: RepositoryCommitDiffError.revisionInFuture(revision: event.revision)) {
            _ = try await RepositoryCommitDiff.verifySyncEvent(
                blocks: car, did: self.did, revision: event.revision, keyResolver: keys,
                now: self.signedAt - 3_600
            )
        }
        #expect(keys.lookups == lookups)
    }

    // MARK: Event bounds (sync.mdx: at most 200 ops, blocks at most 2,000,000 bytes)

    @Test("operations and blocks over the event limits are refused before any key lookup")
    func eventBounds() async throws {
        let signer = K256Keypair.generate()
        let event = try await event(signer: signer, records: 2)
        let keys = CountingKeys(signer.publicKey)
        _ = try await verify(event, keys: keys, now: signedAt)
        let lookups = keys.lookups

        let oneWrite = try PublicRepositoryLimits(
            maximumRecordBlockBytes: 1_000_000,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: 1_000, maximumMSTNodes: 1_000, maximumMSTEntriesPerNode: 64,
            maximumCBORNestingDepth: 64, maximumWrites: 1
        )
        await #expect(throws: RepositoryCommitDiffError.tooManyOperations(count: 2, limit: 1)) {
            _ = try await self.verify(event, keys: keys, limits: oneWrite, now: self.signedAt)
        }
        let smallBlocks = try PublicRepositoryLimits(
            maximumRecordBlockBytes: 1_000_000,
            maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
            maximumCARBlocks: 1_000, maximumMSTNodes: 1_000, maximumMSTEntriesPerNode: 64,
            maximumCBORNestingDepth: 64, maximumRelevantBlockBytes: 100
        )
        await #expect(throws: RepositoryCommitDiffError.blocksTooLarge(byteCount: event.car.count, limit: 100)) {
            _ = try await self.verify(event, keys: keys, limits: smallBlocks, now: self.signedAt)
        }
        #expect(keys.lookups == lookups)
        #expect(PublicRepositoryLimits.standard.maximumWrites == 200)
        #expect(PublicRepositoryLimits.standard.maximumRelevantBlockBytes == 2_000_000)
    }

    // MARK: Identity-backed key resolution

    @Test("an IdentityResolver, cached and throttled, resolves the key a #commit is verified with")
    func identityResolverVerifiesEvents() async throws {
        let signer = K256Keypair.generate()
        let event = try await event(signer: signer)
        let directory = PLCDirectoryStub(did: did, key: signer.publicKey)
        let identity = IdentityResolver(httpTransport: directory)
        let keys = CachingServiceAuthKeyResolver(upstream: identity)

        let verified = try await verify(event, keys: keys, now: signedAt)
        #expect(verified.commit.descriptor.did == did)
        _ = try await verify(event, keys: keys, now: signedAt)
        #expect(directory.fetches == 1, "the second event is served from the cache")

        // A key the account does not publish is refused.
        let impostor = try await self.event(signer: K256Keypair.generate())
        await #expect(throws: RepositoryCommitDiffError.commit(.invalidSignature)) {
            _ = try await self.verify(impostor, keys: keys, now: self.signedAt)
        }
    }

    @Test("a rotated key is picked up by the one forced refresh after a signature fails")
    func identityResolverFollowsRotation() async throws {
        let old = K256Keypair.generate()
        let new = K256Keypair.generate()
        let directory = PLCDirectoryStub(did: did, key: old.publicKey)
        let identity = IdentityResolver(httpTransport: directory)

        _ = try await verify(try await event(signer: old), keys: identity, now: signedAt)
        #expect(directory.fetches == 1)

        // The account rotates; the resolver's cached document still has the old key.
        directory.publish(new.publicKey)
        _ = try await verify(try await event(signer: new), keys: identity, now: signedAt)
        #expect(directory.fetches == 2, "exactly one forced refresh")
    }
}

/// Answers with one key and counts lookups.
private final class CountingKeys: RepositorySigningKeyResolver, @unchecked Sendable {
    private let key: ATProtoPublicKey
    private let lock = NSLock()
    private var count = 0

    init(_ key: ATProtoPublicKey) { self.key = key }

    var lookups: Int { lock.withLock { count } }

    func signingKey(for _: String, forceRefresh _: Bool) async throws -> ATProtoPublicKey {
        lock.withLock { count += 1 }
        return key
    }
}

/// A PLC directory that serves one DID document and counts fetches.
private final class PLCDirectoryStub: IdentityHTTPTransport, @unchecked Sendable {
    private let did: String
    private let lock = NSLock()
    private var key: ATProtoPublicKey
    private var count = 0

    init(did: String, key: ATProtoPublicKey) {
        self.did = did
        self.key = key
    }

    var fetches: Int { lock.withLock { count } }

    func publish(_ key: ATProtoPublicKey) { lock.withLock { self.key = key } }

    func send(_ request: IdentityHTTPRequest) async throws -> IdentityHTTPResponse {
        let key = lock.withLock { () -> ATProtoPublicKey in
            count += 1
            return self.key
        }
        guard request.url.absoluteString == "https://plc.directory/\(did)" else {
            return IdentityHTTPResponse(statusCode: 404, body: Data())
        }
        let document: [String: Any] = [
            "@context": ["https://www.w3.org/ns/did/v1", "https://w3id.org/security/multikey/v1"],
            "id": did,
            "alsoKnownAs": ["at://alice.example.com"],
            "verificationMethod": [[
                "id": "\(did)#atproto",
                "type": "Multikey",
                "controller": did,
                "publicKeyMultibase": String(key.didKey.dropFirst("did:key:".count)),
            ]],
            "service": [[
                "id": "#atproto_pds",
                "type": "AtprotoPersonalDataServer",
                "serviceEndpoint": "https://pds.example.com",
            ]],
        ]
        return IdentityHTTPResponse(
            statusCode: 200, body: try JSONSerialization.data(withJSONObject: document)
        )
    }
}
