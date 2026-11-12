import Foundation
import Petrel

public enum PublicRepositoryEngineError: Error, Sendable, Equatable {
    case repositoryDIDMismatch
    case invalidRevision
    case revisionNotIncreasing
    case commitCIDMismatch
    case recordAlreadyExists
    case recordNotFound
    case recordCIDMismatch
    case record(PublicRepositoryDomainError)
    case mst(RepositoryMSTMutationError)
    case commit(PublicRepositoryCommitError)
    case relevantBlockBudgetExceeded
    case signingFailed
}

public enum PublicRepositoryMutationAction: Sendable, Equatable {
    case create
    case update
    case delete
}

public struct PublicRepositoryMutationRecordResult: Sendable, Equatable {
    public let action: PublicRepositoryMutationAction
    public let path: PublicRepositoryPath
    public let recordCID: CID?
    public let previousRecordCID: CID?

    public init(
        action: PublicRepositoryMutationAction,
        path: PublicRepositoryPath,
        recordCID: CID?,
        previousRecordCID: CID?
    ) {
        self.action = action
        self.path = path
        self.recordCID = recordCID
        self.previousRecordCID = previousRecordCID
    }
}

/// A completely prepared, immutable repository transaction. Instances can
/// only be produced by ``PublicRepositoryEngine`` after all domain, MST,
/// commit, and aggregate block invariants have succeeded.
public struct PreparedPublicRepositoryMutation: Sendable, Equatable {
    public let state: PublicRepositoryState
    public let baseCommitCID: CID
    public let sinceRevision: String
    public let signedCommit: PreparedPublicRepositorySignedCommit
    /// Control-plane generation of the signer that produced `signedCommit`.
    /// The final publication fence revalidates this durable-free fact before
    /// committing repository state or a firehose row.
    public let signingGeneration: UInt64
    public let recordResults: [PublicRepositoryMutationRecordResult]
    /// Raw blob CIDs that the resulting public records require to remain in
    /// the public namespace. Storage rechecks these inside its commit
    /// transaction so permissioned promotion cannot remove a last public
    /// reference between HTTP validation and repository publication.
    public let publicBlobCIDs: [CID]
    /// Typed metadata claims carried by the changed public records. Storage
    /// rechecks these against the same public blob rows at commit time.
    public let publicTypedBlobReferences: [PublicTypedBlobReference]
    /// Blocks to persist: the signed commit, every MST node that is in the
    /// new tree and was not in the previous one, and every created or updated
    /// record. Membership is decided by comparing the two trees, never by
    /// what the block source happened to contain.
    public let newBlocks: PublicRepositoryBlockMap
    /// Blocks for the commit's diff (the `blocks` CAR of a `#commit` firehose
    /// event): everything in ``newBlocks`` plus the unchanged MST nodes a
    /// consumer needs to verify the operations by inversion, as the sync
    /// specification requires. Feed these to `PublicFirehoseDiffCAR.build`.
    public let relevantBlocks: PublicRepositoryBlockMap
    /// MST root of the repository before this commit: the event's `prevData`.
    public let previousDataCID: CID
    /// The record operations in wire form, with the previous record CID for
    /// updates and deletes.
    public var operations: [RepositoryCommitOperation] {
        // The engine sets `recordCID` for every create and update and
        // `previousRecordCID` for every update and delete. Dropping a result
        // that lacked one would yield a diff that later fails inversion with
        // a misleading error, so a missing CID stops here instead.
        recordResults.map { result in
            switch (result.action, result.recordCID, result.previousRecordCID) {
            case let (.create, cid?, _):
                return .create(path: result.path, cid: cid)
            case let (.update, cid?, previous?):
                return .update(path: result.path, cid: cid, previous: previous)
            case let (.delete, _, previous?):
                return .delete(path: result.path, previous: previous)
            default:
                preconditionFailure("engine produced a \(result.action) result without its CIDs")
            }
        }
    }

    fileprivate init(
        state: PublicRepositoryState,
        baseCommitCID: CID,
        sinceRevision: String,
        signedCommit: PreparedPublicRepositorySignedCommit,
        signingGeneration: UInt64,
        recordResults: [PublicRepositoryMutationRecordResult],
        publicBlobCIDs: [CID],
        publicTypedBlobReferences: [PublicTypedBlobReference],
        newBlocks: PublicRepositoryBlockMap,
        relevantBlocks: PublicRepositoryBlockMap,
        previousDataCID: CID
    ) {
        self.state = state
        self.baseCommitCID = baseCommitCID
        self.sinceRevision = sinceRevision
        self.signedCommit = signedCommit
        self.signingGeneration = signingGeneration
        self.recordResults = recordResults
        self.publicBlobCIDs = publicBlobCIDs
        self.publicTypedBlobReferences = publicTypedBlobReferences
        self.newBlocks = newBlocks
        self.relevantBlocks = relevantBlocks
        self.previousDataCID = previousDataCID
    }
}

/// The finished tree of a mutation, before its commit is signed.
struct UnsignedPublicRepositoryMutation {
    /// The new MST root.
    let rootCID: CID
    /// MST nodes in the new tree and not in the previous one.
    let newNodes: PublicRepositoryBlockMap
    /// Created and updated record blocks.
    let recordBlocks: [PublicRepositoryBlock]
    /// One result per write, with the previous record CID.
    let recordResults: [PublicRepositoryMutationRecordResult]
    /// Exact size of the signed commit block that will follow.
    let commitByteCount: Int
}

/// Applies record writes to a repository and produces the next signed commit.
public enum PublicRepositoryEngine {
    /// Applies `batch` on top of `currentState` and signs the result.
    ///
    /// Nothing is written: the returned value carries the new state and the
    /// blocks to persist. An empty batch (``PublicRepositoryWriteBatch/empty(expectedCommitCID:)``)
    /// produces a commit over the unchanged tree, which is what an account
    /// publishes after rotating its signing key.
    ///
    /// - Parameters:
    ///   - repositoryDID: The account DID; must match `currentState`.
    ///   - currentState: The repository head the writes apply to.
    ///   - blocks: Source of the current tree's blocks.
    ///   - revision: The new `rev`; must be greater than the current one.
    ///   - batch: The writes.
    ///   - limits: Write-count, block-size and commit-diff bounds.
    ///   - signer: Signs the commit, on either curve.
    ///   - signingGeneration: Caller-defined key generation tag, carried
    ///     through to the result unchanged.
    ///   - mstOptions: How the existing tree is read. Pass
    ///     ``RepositoryMSTOptions/dataModel`` to write on top of a repository
    ///     whose leaves use non-blessed record links; new records always get
    ///     blessed CIDs.
    public static func apply(
        repositoryDID: String,
        currentState: PublicRepositoryState,
        blocks: any PublicRepositoryBlockSource,
        revision: String,
        batch: PublicRepositoryWriteBatch,
        limits: PublicRepositoryLimits = .standard,
        signer: any PublicRepositoryCommitSigner,
        signingGeneration: UInt64 = 1,
        mstOptions: RepositoryMSTOptions = .strict
    ) async throws -> PreparedPublicRepositoryMutation {
        try await apply(
            repositoryDID: repositoryDID,
            currentState: currentState,
            blocks: blocks,
            revision: revision,
            batch: batch,
            limits: limits,
            signer: signer,
            signingGeneration: signingGeneration,
            mstOptions: mstOptions,
            beforeSigning: { _ in }
        )
    }

    /// ``apply(repositoryDID:currentState:blocks:revision:batch:limits:signer:signingGeneration:mstOptions:)``
    /// with a check that runs on the finished tree before the signer is
    /// called. Throwing from `beforeSigning` aborts the write unsigned.
    static func apply(
        repositoryDID: String,
        currentState: PublicRepositoryState,
        blocks: any PublicRepositoryBlockSource,
        revision: String,
        batch: PublicRepositoryWriteBatch,
        limits: PublicRepositoryLimits,
        signer: any PublicRepositoryCommitSigner,
        signingGeneration: UInt64,
        mstOptions: RepositoryMSTOptions,
        beforeSigning: (UnsignedPublicRepositoryMutation) async throws -> Void
    ) async throws -> PreparedPublicRepositoryMutation {
        guard repositoryDID == currentState.did else {
            throw PublicRepositoryEngineError.repositoryDIDMismatch
        }
        guard signingGeneration > 0 else {
            throw PublicRepositoryEngineError.signingFailed
        }
        let proposedRevision: PublicRepositoryTID
        let currentRevision: PublicRepositoryTID
        do {
            proposedRevision = try PublicRepositoryTID(revision)
            currentRevision = try PublicRepositoryTID(currentState.revision)
        } catch {
            throw PublicRepositoryEngineError.invalidRevision
        }
        guard currentRevision < proposedRevision else {
            throw PublicRepositoryEngineError.revisionNotIncreasing
        }
        if let expectedCommitCID = batch.expectedCommitCID,
           expectedCommitCID != currentState.commitCID {
            throw PublicRepositoryEngineError.commitCIDMismatch
        }
        var tree: RepositoryMST
        do {
            tree = try RepositoryMST.load(
                rootCID: currentState.dataCID,
                blocks: blocks,
                limits: limits,
                options: mstOptions
            )
        } catch let error as RepositoryMSTMutationError {
            throw PublicRepositoryEngineError.mst(error)
        } catch {
            throw PublicRepositoryEngineError.mst(.invalidNode)
        }

        var preparedRecordBlocks: [PublicRepositoryBlock] = []
        var recordResults: [PublicRepositoryMutationRecordResult] = []
        var publicBlobCIDsByString: [String: CID] = [:]
        var publicTypedBlobReferences: [PublicTypedBlobReference] = []
        for write in batch.writes {
            let currentRecordCID: CID?
            do {
                let lookup = try await tree.getWithTree(write.path)
                currentRecordCID = lookup.cid
                tree = lookup.tree
            } catch let error as RepositoryMSTMutationError {
                throw PublicRepositoryEngineError.mst(error)
            } catch {
                throw PublicRepositoryEngineError.mst(.invalidNode)
            }

            switch write {
            case let .create(path, record):
                guard currentRecordCID == nil else {
                    throw PublicRepositoryEngineError.recordAlreadyExists
                }
                let prepared = try prepare(record, for: path, limits: limits)
                for cid in PublicRepositoryRecordCodec.publicBlobCIDs(in: record) {
                    publicBlobCIDsByString[cid.string] = cid
                }
                do {
                    let typedReferences = try PublicRepositoryRecordCodec
                        .publicTypedBlobReferences(in: record)
                    publicTypedBlobReferences.append(contentsOf: typedReferences)
                } catch let error as PublicRepositoryDomainError {
                    throw PublicRepositoryEngineError.record(error)
                } catch {
                    throw PublicRepositoryEngineError.record(.invalidRecordType)
                }
                do {
                    tree = try await tree.adding(path: path, recordCID: prepared.cid)
                } catch let error as RepositoryMSTMutationError {
                    throw PublicRepositoryEngineError.mst(error)
                } catch {
                    throw PublicRepositoryEngineError.mst(.invalidNode)
                }
                preparedRecordBlocks.append(.init(cid: prepared.cid, bytes: prepared.bytes))
                recordResults.append(.init(
                    action: .create,
                    path: path,
                    recordCID: prepared.cid,
                    previousRecordCID: nil
                ))

            case let .update(path, record, expectedRecordCID):
                guard let currentRecordCID else {
                    throw PublicRepositoryEngineError.recordNotFound
                }
                if let expectedRecordCID, expectedRecordCID != currentRecordCID {
                    throw PublicRepositoryEngineError.recordCIDMismatch
                }
                let prepared = try prepare(record, for: path, limits: limits)
                for cid in PublicRepositoryRecordCodec.publicBlobCIDs(in: record) {
                    publicBlobCIDsByString[cid.string] = cid
                }
                do {
                    let typedReferences = try PublicRepositoryRecordCodec
                        .publicTypedBlobReferences(in: record)
                    publicTypedBlobReferences.append(contentsOf: typedReferences)
                } catch let error as PublicRepositoryDomainError {
                    throw PublicRepositoryEngineError.record(error)
                } catch {
                    throw PublicRepositoryEngineError.record(.invalidRecordType)
                }
                do {
                    tree = try await tree.updating(path: path, recordCID: prepared.cid)
                } catch let error as RepositoryMSTMutationError {
                    throw PublicRepositoryEngineError.mst(error)
                } catch {
                    throw PublicRepositoryEngineError.mst(.invalidNode)
                }
                preparedRecordBlocks.append(.init(cid: prepared.cid, bytes: prepared.bytes))
                recordResults.append(.init(
                    action: .update,
                    path: path,
                    recordCID: prepared.cid,
                    previousRecordCID: currentRecordCID
                ))

            case let .delete(path, expectedRecordCID):
                guard let currentRecordCID else {
                    throw PublicRepositoryEngineError.recordNotFound
                }
                if let expectedRecordCID, expectedRecordCID != currentRecordCID {
                    throw PublicRepositoryEngineError.recordCIDMismatch
                }
                do {
                    tree = try await tree.deleting(path: path)
                } catch let error as RepositoryMSTMutationError {
                    throw PublicRepositoryEngineError.mst(error)
                } catch {
                    throw PublicRepositoryEngineError.mst(.invalidNode)
                }
                recordResults.append(.init(
                    action: .delete,
                    path: path,
                    recordCID: nil,
                    previousRecordCID: currentRecordCID
                ))
            }
        }

        let materialized: MaterializedRepositoryMST
        do {
            materialized = try await tree.materialized()
        } catch let error as RepositoryMSTMutationError {
            if error == .relevantBlockBudgetExceeded {
                throw PublicRepositoryEngineError.relevantBlockBudgetExceeded
            }
            throw PublicRepositoryEngineError.mst(error)
        } catch {
            throw PublicRepositoryEngineError.mst(.invalidNode)
        }

        // Every created or updated record belongs to the commit, whether or
        // not the store already holds identical bytes from earlier history.
        // The sync specification requires a diff to carry all of them.
        var transactionBlocks: [PublicRepositoryBlock] = preparedRecordBlocks
        for cid in materialized.newBlocks.cids {
            guard let bytes = try await materialized.newBlocks.block(for: cid) else {
                throw PublicRepositoryEngineError.mst(.missingBlock)
            }
            transactionBlocks.append(.init(cid: cid, bytes: bytes))
        }

        let preCommitBlocks = try makeBlockMap(transactionBlocks, limits: limits)
        let commitByteCount: Int
        do {
            commitByteCount = try PublicRepositoryCommitCodec.preflightSignedCommitByteCount(
                did: repositoryDID,
                revision: revision,
                dataCID: materialized.rootCID,
                currentRevision: currentState.revision,
                signingAlgorithm: signer.signingAlgorithm
            )
        } catch let error as PublicRepositoryCommitError {
            throw PublicRepositoryEngineError.commit(error)
        } catch {
            throw PublicRepositoryEngineError.commit(.invalidSchema)
        }
        guard preCommitBlocks.relevantByteCount
            <= limits.maximumRelevantBlockBytes - commitByteCount else {
            throw PublicRepositoryEngineError.relevantBlockBudgetExceeded
        }

        try await beforeSigning(UnsignedPublicRepositoryMutation(
            rootCID: materialized.rootCID,
            newNodes: materialized.newBlocks,
            recordBlocks: preparedRecordBlocks,
            recordResults: recordResults,
            commitByteCount: commitByteCount
        ))

        let signedCommit: PreparedPublicRepositorySignedCommit
        do {
            signedCommit = try await PublicRepositoryCommitCodec.prepare(
                did: repositoryDID,
                revision: revision,
                dataCID: materialized.rootCID,
                currentRevision: currentState.revision,
                signer: signer
            )
        } catch let error as PublicRepositoryCommitError {
            throw PublicRepositoryEngineError.commit(error)
        } catch {
            throw PublicRepositoryEngineError.signingFailed
        }

        let commitBlock = PublicRepositoryBlock(
            cid: signedCommit.commitCID,
            bytes: signedCommit.signedCommitBytes
        )
        let newBlocks = try makeBlockMap(transactionBlocks + [commitBlock], limits: limits)

        // The covering proof: for each written path, the nodes of the *new*
        // tree on the path to the key and to its neighbour on each side.
        let coveringBlocks: [PublicRepositoryBlock]
        do {
            coveringBlocks = try await tree.coveringProof(for: batch.writes.map(\.path))
        } catch let error as RepositoryMSTMutationError {
            throw PublicRepositoryEngineError.mst(error)
        } catch {
            throw PublicRepositoryEngineError.mst(.invalidNode)
        }
        let relevantBlocks: PublicRepositoryBlockMap
        do {
            // Bounded by the archive ceiling rather than the commit-diff
            // budget: the budget above already bounds what this commit adds,
            // and the firehose frame encoder enforces the event size.
            relevantBlocks = try PublicRepositoryBlockMap(
                blocks: transactionBlocks + [commitBlock] + coveringBlocks,
                maximumRelevantBytes: PublicRepositoryLimits.maximumPermittedCARBytes
            )
        } catch let error as PublicRepositoryDomainError {
            throw PublicRepositoryEngineError.record(error)
        }
        let newState: PublicRepositoryState
        do {
            newState = try PublicRepositoryState(
                did: repositoryDID,
                revision: revision,
                commitCID: signedCommit.commitCID,
                dataCID: materialized.rootCID
            )
        } catch {
            throw PublicRepositoryEngineError.commit(.invalidSchema)
        }
        return PreparedPublicRepositoryMutation(
            state: newState,
            baseCommitCID: currentState.commitCID,
            sinceRevision: currentState.revision,
            signedCommit: signedCommit,
            signingGeneration: signingGeneration,
            recordResults: recordResults,
            publicBlobCIDs: publicBlobCIDsByString.keys.sorted().compactMap {
                publicBlobCIDsByString[$0]
            },
            publicTypedBlobReferences: publicTypedBlobReferences,
            newBlocks: newBlocks,
            relevantBlocks: relevantBlocks,
            previousDataCID: currentState.dataCID
        )
    }

    private static func prepare(
        _ record: PublicRecord,
        for path: PublicRepositoryPath,
        limits: PublicRepositoryLimits
    ) throws -> PreparedPublicRecord {
        do {
            return try PublicRepositoryRecordCodec.prepare(record, for: path, limits: limits)
        } catch let error as PublicRepositoryDomainError {
            throw PublicRepositoryEngineError.record(error)
        } catch {
            throw PublicRepositoryEngineError.record(.invalidRecordType)
        }
    }

    private static func makeBlockMap(
        _ blocks: [PublicRepositoryBlock],
        limits: PublicRepositoryLimits
    ) throws -> PublicRepositoryBlockMap {
        do {
            return try PublicRepositoryBlockMap(
                blocks: blocks,
                maximumRelevantBytes: limits.maximumRelevantBlockBytes
            )
        } catch PublicRepositoryDomainError.relevantBlockBudgetExceeded {
            throw PublicRepositoryEngineError.relevantBlockBudgetExceeded
        } catch let error as PublicRepositoryDomainError {
            throw PublicRepositoryEngineError.record(error)
        } catch {
            throw PublicRepositoryEngineError.record(.duplicateBlockConflict)
        }
    }
}
