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
    public let newBlocks: PublicRepositoryBlockMap

    fileprivate init(
        state: PublicRepositoryState,
        baseCommitCID: CID,
        sinceRevision: String,
        signedCommit: PreparedPublicRepositorySignedCommit,
        signingGeneration: UInt64,
        recordResults: [PublicRepositoryMutationRecordResult],
        publicBlobCIDs: [CID],
        publicTypedBlobReferences: [PublicTypedBlobReference],
        newBlocks: PublicRepositoryBlockMap
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
    }
}

public enum PublicRepositoryEngine {
    public static func apply(
        repositoryDID: String,
        currentState: PublicRepositoryState,
        blocks: any PublicRepositoryBlockSource,
        revision: String,
        batch: PublicRepositoryWriteBatch,
        limits: PublicRepositoryLimits = .standard,
        signer: any PublicRepositoryCommitSigner,
        signingGeneration: UInt64 = 1
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
        guard signer.signingAlgorithm == .p256 else {
            throw PublicRepositoryEngineError.commit(.unsupportedSigningAlgorithm)
        }

        var tree: RepositoryMST
        do {
            tree = try RepositoryMST.load(
                rootCID: currentState.dataCID,
                blocks: blocks,
                limits: limits
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

        var transactionBlocks: [PublicRepositoryBlock] = []
        for recordBlock in preparedRecordBlocks {
            if let existing = try await block(recordBlock.cid, from: blocks) {
                guard existing == recordBlock.bytes else {
                    throw PublicRepositoryEngineError.record(.blockCIDMismatch)
                }
            } else {
                transactionBlocks.append(recordBlock)
            }
        }
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

        let newBlocks = try makeBlockMap(
            transactionBlocks + [
                .init(cid: signedCommit.commitCID, bytes: signedCommit.signedCommitBytes),
            ],
            limits: limits
        )
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
            newBlocks: newBlocks
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

    private static func block(
        _ cid: CID,
        from source: any PublicRepositoryBlockSource
    ) async throws -> Data? {
        do {
            return try await source.block(for: cid)
        } catch let error as PublicRepositoryEngineError {
            throw error
        } catch {
            throw PublicRepositoryEngineError.mst(.missingBlock)
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
