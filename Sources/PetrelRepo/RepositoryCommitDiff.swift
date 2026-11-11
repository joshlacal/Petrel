import Foundation
import Petrel
import PetrelCrypto

/// One record operation of a commit, in the form the firehose carries it
/// (`com.atproto.sync.subscribeRepos#repoOp`).
public enum RepositoryCommitOperation: Sendable, Equatable {
    /// A record was created at `path` with CID `cid`.
    case create(path: PublicRepositoryPath, cid: CID)
    /// The record at `path` changed from `previous` to `cid`.
    case update(path: PublicRepositoryPath, cid: CID, previous: CID)
    /// The record at `path`, which had CID `previous`, was deleted.
    case delete(path: PublicRepositoryPath, previous: CID)

    /// The path the operation applies to.
    public var path: PublicRepositoryPath {
        switch self {
        case let .create(path, _), let .update(path, _, _), let .delete(path, _):
            return path
        }
    }

    /// The record CID after the operation; `nil` for a delete.
    public var recordCID: CID? {
        switch self {
        case let .create(_, cid), let .update(_, cid, _): return cid
        case .delete: return nil
        }
    }
}

/// Why a commit diff failed verification.
public enum RepositoryCommitDiffError: Error, Sendable, Equatable {
    /// The diff does not contain the commit block.
    case missingCommit
    /// The commit object or its signature is invalid.
    case commit(PublicRepositoryCommitError)
    /// The diff lacks an MST node needed to invert the operations. A
    /// conforming producer includes them (the covering proof); their absence
    /// makes the commit unverifiable, not valid.
    case incompleteProof
    /// An MST node in the diff is malformed.
    case invalidTree
    /// The tree does not hold what an operation says it should: a created or
    /// updated key is missing or maps to another CID, or a deleted key is
    /// still present.
    case operationMismatch(path: String)
    /// After inverting every operation the tree root is not `prevData`.
    case previousDataMismatch(computed: CID, expected: CID)
    /// A created or updated record's block is missing from the diff.
    case missingRecord(path: String)
    /// A record block in the diff is not valid for its path.
    case invalidRecord(path: String)
    /// The same path appears in more than one operation.
    case duplicatePath(path: String)
    /// The event's `blocks` field is not a well-formed CAR archive.
    case malformedBlocks(PublicRepositoryCARError)
    /// The CAR's first root is not the commit the event names.
    case rootMismatch(root: CID, commit: CID)
    /// The event's `rev` is not the revision inside the signed commit.
    case revisionMismatch(event: String, commit: String)
}

/// A commit diff that passed ``RepositoryCommitDiff/verify(commitCID:operations:previousDataCID:blocks:keyResolver:expectedDID:limits:policy:)``.
public struct VerifiedRepositoryCommitDiff: Sendable, Equatable {
    /// The verified commit.
    public let commit: VerifiedPublicRepositorySignedCommit
    /// The operations, as given.
    public let operations: [RepositoryCommitOperation]
    /// The MST root before the commit, as recomputed by inversion.
    public let previousDataCID: CID
}

/// Verification of commit diffs by operation inversion (sync v1.1).
///
/// A `#commit` firehose event carries a small CAR of blocks, a list of record
/// operations, and `prevData`: the MST root before the commit. A consumer
/// that does not hold the repository can still check that the operations are
/// exactly what changed: load the *new* tree from the diff's blocks, undo each
/// operation (delete what was created, restore what was updated or deleted),
/// and compare the resulting root with `prevData`. If they are equal, the
/// listed operations are the complete difference between the two trees.
///
/// This needs no state beyond the event itself, which is what makes it
/// practical on a live firehose.
public enum RepositoryCommitDiff {
    /// Inverts `operations` against the tree rooted at `dataCID` and checks
    /// the result against `previousDataCID`.
    ///
    /// Only the MST is examined: no signature, no record contents.
    ///
    /// - Parameters:
    ///   - dataCID: The MST root after the commit (`commit.data`).
    ///   - operations: The commit's operations. Each path may appear once.
    ///   - previousDataCID: The claimed MST root before the commit
    ///     (`prevData`).
    ///   - blocks: The diff's blocks. Only blocks reachable from `dataCID`
    ///     are consulted; anything else is ignored.
    ///   - limits: Bounds on nodes and entries per node.
    ///   - options: Key syntax and leaf-link policy.
    /// - Throws: ``RepositoryCommitDiffError``.
    public static func verifyInversion(
        dataCID: CID,
        operations: [RepositoryCommitOperation],
        previousDataCID: CID,
        blocks: any PublicRepositoryBlockSource,
        limits: PublicRepositoryLimits = .standard,
        options: RepositoryMSTOptions = .dataModel
    ) async throws {
        var paths = Set<PublicRepositoryPath>()
        for operation in operations {
            guard paths.insert(operation.path).inserted else {
                throw RepositoryCommitDiffError.duplicatePath(path: operation.path.mstKey)
            }
        }
        do {
            var tree = try RepositoryMST.load(
                rootCID: dataCID, blocks: blocks, limits: limits, options: options
            )
            // Undo in reverse so that inverting mirrors the order of
            // application.
            for operation in operations.reversed() {
                let key = operation.path.mstKey
                let lookup = try await tree.getWithTree(operation.path)
                tree = lookup.tree
                switch operation {
                case let .create(path, cid):
                    guard lookup.cid == cid else {
                        throw RepositoryCommitDiffError.operationMismatch(path: key)
                    }
                    tree = try await tree.deleting(path: path)
                case let .update(path, cid, previous):
                    guard lookup.cid == cid else {
                        throw RepositoryCommitDiffError.operationMismatch(path: key)
                    }
                    tree = try await tree.updating(path: path, recordCID: previous)
                case let .delete(path, previous):
                    guard lookup.cid == nil else {
                        throw RepositoryCommitDiffError.operationMismatch(path: key)
                    }
                    tree = try await tree.adding(path: path, recordCID: previous)
                }
            }
            let computed = try await tree.rootCID()
            guard computed == previousDataCID else {
                throw RepositoryCommitDiffError.previousDataMismatch(
                    computed: computed, expected: previousDataCID
                )
            }
        } catch let error as RepositoryCommitDiffError {
            throw error
        } catch RepositoryMSTMutationError.missingBlock {
            throw RepositoryCommitDiffError.incompleteProof
        } catch is RepositoryMSTMutationError {
            throw RepositoryCommitDiffError.invalidTree
        }
    }

    /// Fully verifies a commit diff: signature, operations, record blocks.
    ///
    /// In order:
    /// 1. the commit block is present, canonical, and signed by the key the
    ///    resolver returns for its DID (with one refresh-and-retry);
    /// 2. the operations invert to `previousDataCID`
    ///    (``verifyInversion(dataCID:operations:previousDataCID:blocks:limits:options:)``);
    /// 3. every created or updated record's block is present, hashes to the
    ///    CID in the operation, and is a valid record under `policy`.
    ///
    /// - Parameters:
    ///   - commitCID: The commit CID named by the event.
    ///   - operations: The event's operations.
    ///   - previousDataCID: The event's `prevData`.
    ///   - blocks: The blocks of the event's CAR.
    ///   - keyResolver: Looks up the account's signing key.
    ///   - expectedDID: If given, the commit must be for this DID.
    ///   - limits: Bounds on nodes, entries and record size.
    ///   - policy: How strictly record content is checked.
    /// - Throws: ``RepositoryCommitDiffError``.
    public static func verify(
        commitCID: CID,
        operations: [RepositoryCommitOperation],
        previousDataCID: CID,
        blocks: any PublicRepositoryBlockSource,
        keyResolver: any RepositorySigningKeyResolver,
        expectedDID: String? = nil,
        limits: PublicRepositoryLimits = .standard,
        policy: RepositoryReadPolicy = .dataModel
    ) async throws -> VerifiedRepositoryCommitDiff {
        guard let commitBytes = try await blocks.block(for: commitCID) else {
            throw RepositoryCommitDiffError.missingCommit
        }
        let commit: VerifiedPublicRepositorySignedCommit
        do {
            commit = try await PublicRepositoryCommitCodec.verify(
                signedCommitBytes: commitBytes,
                expectedCommitCID: commitCID,
                keyResolver: keyResolver,
                expectedDID: expectedDID
            )
        } catch let error as PublicRepositoryCommitError {
            throw RepositoryCommitDiffError.commit(error)
        }

        try await verifyInversion(
            dataCID: commit.descriptor.dataCID,
            operations: operations,
            previousDataCID: previousDataCID,
            blocks: blocks,
            limits: limits,
            options: policy.mstOptions
        )

        for operation in operations {
            guard let cid = operation.recordCID, cid.blessedKind == .dagCBOR else { continue }
            let key = operation.path.mstKey
            guard let bytes = try await blocks.block(for: cid) else {
                throw RepositoryCommitDiffError.missingRecord(path: key)
            }
            guard cid.matchesContent(bytes) else {
                throw RepositoryCommitDiffError.invalidRecord(path: key)
            }
            do {
                try RepositoryMSTValidation.validateRecordBlock(
                    bytes, for: operation.path, limits: limits, policy: policy
                )
            } catch {
                throw RepositoryCommitDiffError.invalidRecord(path: key)
            }
        }
        return VerifiedRepositoryCommitDiff(
            commit: commit,
            operations: operations,
            previousDataCID: previousDataCID
        )
    }

    // MARK: Firehose events

    /// Verifies a `#commit` event of `com.atproto.sync.subscribeRepos` from
    /// its own fields, with no repository state.
    ///
    /// On top of ``verify(commitCID:operations:previousDataCID:blocks:keyResolver:expectedDID:limits:policy:)``
    /// this checks the event envelope against what was signed: the CAR's
    /// first root is the event's `commit`, the commit is for the event's
    /// `repo`, and its revision is the event's `rev`.
    ///
    /// - Parameters:
    ///   - car: The event's `blocks`.
    ///   - commitCID: The event's `commit`.
    ///   - did: The event's `repo`.
    ///   - revision: The event's `rev`.
    ///   - operations: The event's `ops`, with `prev` for updates and deletes.
    ///   - previousDataCID: The event's `prevData`.
    ///   - keyResolver: Looks up the account's signing key; asked again with
    ///     a refresh if the signature does not verify.
    ///   - limits: Bounds on the archive, the tree and record size.
    ///   - policy: How strictly record content is checked.
    /// - Throws: ``RepositoryCommitDiffError``.
    public static func verifyCommitEvent(
        blocks car: Data,
        commitCID: CID,
        did: String,
        revision: String,
        operations: [RepositoryCommitOperation],
        previousDataCID: CID,
        keyResolver: any RepositorySigningKeyResolver,
        limits: PublicRepositoryLimits = .standard,
        policy: RepositoryReadPolicy = .dataModel
    ) async throws -> VerifiedRepositoryCommitDiff {
        let store = try await loadEventBlocks(car, commitCID: commitCID, limits: limits)
        let verified = try await verify(
            commitCID: commitCID,
            operations: operations,
            previousDataCID: previousDataCID,
            blocks: store,
            keyResolver: keyResolver,
            expectedDID: did,
            limits: limits,
            policy: policy
        )
        try requireRevision(revision, of: verified.commit)
        return verified
    }

    /// Verifies a `#sync` event: a signed commit that restates an account's
    /// current repository head, sent when a consumer should resynchronize.
    ///
    /// The event carries only the commit block. This checks that the block
    /// is present and is the CAR's root, that it is a canonical commit
    /// signed by the key of the event's `did`, and that its revision is the
    /// event's `rev`. The returned commit's `data` is the tree root to fetch
    /// and verify against.
    ///
    /// - Parameters:
    ///   - car: The event's `blocks`.
    ///   - did: The event's `did`.
    ///   - revision: The event's `rev`.
    ///   - keyResolver: Looks up the account's signing key.
    ///   - limits: Bounds on the archive.
    /// - Throws: ``RepositoryCommitDiffError``.
    public static func verifySyncEvent(
        blocks car: Data,
        did: String,
        revision: String,
        keyResolver: any RepositorySigningKeyResolver,
        limits: PublicRepositoryLimits = .standard
    ) async throws -> VerifiedPublicRepositorySignedCommit {
        let store = InMemoryRepositoryBlockStore()
        let parsed: PublicRepositoryCARParseResult
        do {
            parsed = try await PublicRepositoryCAR.load(
                from: DataCARByteSource(car), into: store, limits: limits, policy: .dataModel
            )
        } catch let error as PublicRepositoryCARError {
            throw RepositoryCommitDiffError.malformedBlocks(error)
        }
        guard let commitBytes = try await store.block(for: parsed.rootCID) else {
            throw RepositoryCommitDiffError.missingCommit
        }
        let commit: VerifiedPublicRepositorySignedCommit
        do {
            commit = try await PublicRepositoryCommitCodec.verify(
                signedCommitBytes: commitBytes,
                expectedCommitCID: parsed.rootCID,
                keyResolver: keyResolver,
                expectedDID: did
            )
        } catch let error as PublicRepositoryCommitError {
            throw RepositoryCommitDiffError.commit(error)
        }
        try requireRevision(revision, of: commit)
        return commit
    }

    private static func loadEventBlocks(
        _ car: Data,
        commitCID: CID,
        limits: PublicRepositoryLimits
    ) async throws -> InMemoryRepositoryBlockStore {
        let store = InMemoryRepositoryBlockStore()
        let parsed: PublicRepositoryCARParseResult
        do {
            // Extra roots and unrelated blocks in a diff are to be ignored.
            parsed = try await PublicRepositoryCAR.load(
                from: DataCARByteSource(car), into: store, limits: limits, policy: .dataModel
            )
        } catch let error as PublicRepositoryCARError {
            throw RepositoryCommitDiffError.malformedBlocks(error)
        }
        guard parsed.rootCID == commitCID else {
            throw RepositoryCommitDiffError.rootMismatch(root: parsed.rootCID, commit: commitCID)
        }
        return store
    }

    private static func requireRevision(
        _ revision: String,
        of commit: VerifiedPublicRepositorySignedCommit
    ) throws {
        guard commit.descriptor.revision.value == revision else {
            throw RepositoryCommitDiffError.revisionMismatch(
                event: revision, commit: commit.descriptor.revision.value
            )
        }
    }
}
