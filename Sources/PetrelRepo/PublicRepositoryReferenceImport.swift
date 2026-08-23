import Foundation
import Petrel
import Crypto

public struct PublicRepositoryImportEnvelope: Sendable {
    public let requestID: String
    public let requestDigest: Data
    public let did: String
    public let rootCID: CID
    public let expectedExistingRootCID: CID?
    public let blocks: [PublicRepositoryBlock]
    public let referencedBlobs: [CID]
    public let blobPayloads: [PublicRepositoryBlock]
    public let signature: Data

    public init(did: String, rootCID: CID, expectedExistingRootCID: CID? = nil, blocks: [PublicRepositoryBlock], referencedBlobs: [CID] = [], blobPayloads: [PublicRepositoryBlock] = [], signature: Data, requestID: String, requestDigest: Data) throws {
        guard !requestID.isEmpty, requestID.utf8.count <= 512, !requestID.contains("\0"), requestDigest.count == 32 else {
            throw PublicRepositoryReferenceImportError.invalidBinding
        }
        self.requestID = requestID
        self.requestDigest = requestDigest
        self.did = did
        self.rootCID = rootCID
        if let expectedExistingRootCID { try PublicRepositoryCID.validate(expectedExistingRootCID) }
        self.expectedExistingRootCID = expectedExistingRootCID
        self.blocks = blocks
        self.referencedBlobs = referencedBlobs
        self.blobPayloads = blobPayloads
        self.signature = signature
    }

    public static func make(did: String, rootCID: CID, expectedExistingRootCID: CID? = nil, blocks: [PublicRepositoryBlock], referencedBlobs: [CID] = [], blobPayloads: [PublicRepositoryBlock] = [], signature: Data, requestID: String) throws -> Self {
        let provisional = try Self(did: did, rootCID: rootCID, expectedExistingRootCID: expectedExistingRootCID, blocks: blocks, referencedBlobs: referencedBlobs, blobPayloads: blobPayloads, signature: signature, requestID: requestID, requestDigest: Data(repeating: 0, count: 32))
        return try Self(did: did, rootCID: rootCID, expectedExistingRootCID: expectedExistingRootCID, blocks: blocks, referencedBlobs: referencedBlobs, blobPayloads: blobPayloads, signature: signature, requestID: requestID, requestDigest: PublicRepositoryReferenceImportVerifier.canonicalRequestDigest(for: provisional))
    }
}

public struct PublicRepositoryImportedState: Sendable, Equatable {
    public let did: String
    public let rootCID: CID
    public let blocks: [PublicRepositoryBlock]

    public init(did: String, rootCID: CID, blocks: [PublicRepositoryBlock]) {
        self.did = did
        self.rootCID = rootCID
        self.blocks = blocks
    }
}

public protocol PublicRepositoryImportCommitter: Sendable {
    /// False for adapters that have not yet been wired to durable storage.
    var isDurableTransactional: Bool { get }
    /// Implementations must atomically compare `expectedRootCID`, record the
    /// request digest, and either commit once or replay the same result for an
    /// identical `(requestID, requestDigest)`. A different digest for a reused
    /// request ID is a conflict; no partial blocks may remain visible.
    func commit(_ state: PublicRepositoryImportedState, requestID: String, requestDigest: Data, expectedRootCID: CID?) async throws -> PublicRepositoryImportedState
}

public protocol PublicRepositoryBlobResolver: Sendable {
    func containsBlob(_ cid: CID) async throws -> Bool
}

public enum PublicRepositoryReferenceImportError: Error, Sendable, Equatable {
    case invalidDID
    case invalidBinding
    case requestDigestMismatch
    case invalidRoot
    case blockLimitExceeded
    case byteLimitExceeded
    case duplicateBlockConflict
    case missingBlob(CID)
    case invalidSignature
    case conflictingRequestReuse
    case commitCASConflict
    case unassembled
}

/// Verifies an import completely before invoking the injected durable commit
/// boundary. No block, blob, or root is published on a failed preflight.
public struct PublicRepositoryReferenceImportVerifier: Sendable {
    public let maximumBlocks: Int
    public let maximumBytes: Int
    public let maximumReferencedBlobs: Int
    public let maximumReferenceBytes: Int

    public init(
        maximumBlocks: Int = 100_000,
        maximumBytes: Int = 512 * 1_024 * 1_024,
        maximumReferencedBlobs: Int = 100_000,
        maximumReferenceBytes: Int = 8 * 1_024 * 1_024
    ) throws {
        guard maximumBlocks > 0, maximumBytes > 0,
              maximumReferencedBlobs > 0, maximumReferenceBytes > 0 else {
            throw PublicRepositoryReferenceImportError.blockLimitExceeded
        }
        self.maximumBlocks = maximumBlocks
        self.maximumBytes = maximumBytes
        self.maximumReferencedBlobs = maximumReferencedBlobs
        self.maximumReferenceBytes = maximumReferenceBytes
    }

    public static func canonicalRequestDigest(for envelope: PublicRepositoryImportEnvelope) -> Data {
        var bytes = Data("swan.repo.import.v1\0".utf8)
        func append(_ data: Data) { var n = UInt64(data.count).bigEndian; bytes.append(Data(bytes: &n, count: 8)); bytes.append(data) }
        let normalizedDID = (try? DID(didString: envelope.did)).map { String(describing: $0) } ?? envelope.did
        append(Data(normalizedDID.utf8)); append(Data(envelope.rootCID.bytes)); append(envelope.signature)
        if let expected = envelope.expectedExistingRootCID { append(Data([1])); append(Data(expected.bytes)) } else { append(Data([0])) }
        for block in envelope.blocks.sorted(by: { $0.cid.description < $1.cid.description }) { append(Data(block.cid.bytes)); append(block.bytes) }
        for cid in envelope.referencedBlobs.sorted(by: { $0.description < $1.description }) { append(Data(cid.bytes)) }
        for block in envelope.blobPayloads.sorted(by: { $0.cid.description < $1.cid.description }) { append(Data(block.cid.bytes)); append(block.bytes) }
        return Data(SHA256.hash(data: bytes))
    }

    public protocol FullRepositoryImportVerifier: Sendable {
        var isAssembled: Bool { get }
        func verifyAndStage(_ envelope: PublicRepositoryImportEnvelope) async throws -> PublicRepositoryImportedState
    }

    public func verifyAndCommit(
        _ envelope: PublicRepositoryImportEnvelope,
        committer: any PublicRepositoryImportCommitter,
        fullVerifier: any FullRepositoryImportVerifier,
        existingBlobResolver: (any PublicRepositoryBlobResolver)? = nil,
        verifySignature: @escaping @Sendable (String, CID, Data) throws -> Bool
    ) async throws -> PublicRepositoryImportedState {
        guard committer.isDurableTransactional else { throw PublicRepositoryReferenceImportError.unassembled }
        guard fullVerifier.isAssembled else { throw PublicRepositoryReferenceImportError.unassembled }
        guard envelope.requestDigest == Self.canonicalRequestDigest(for: envelope) else { throw PublicRepositoryReferenceImportError.requestDigestMismatch }
        guard (try? DID(didString: envelope.did)) != nil else { throw PublicRepositoryReferenceImportError.invalidDID }
        try PublicRepositoryCID.validate(envelope.rootCID)
        guard envelope.referencedBlobs.count <= maximumReferencedBlobs else {
            throw PublicRepositoryReferenceImportError.blockLimitExceeded
        }
        var referenceBytes = 0
        for blob in envelope.referencedBlobs {
            try PublicRepositoryCID.validate(blob)
            let (next, overflow) = referenceBytes.addingReportingOverflow(blob.bytes.count)
            guard !overflow, next <= maximumReferenceBytes else {
                throw PublicRepositoryReferenceImportError.byteLimitExceeded
            }
            referenceBytes = next
        }
        let referencedBlobSet = Set(envelope.referencedBlobs)
        guard referencedBlobSet.count == envelope.referencedBlobs.count else {
            throw PublicRepositoryReferenceImportError.duplicateBlockConflict
        }
        guard envelope.blobPayloads.allSatisfy({ referencedBlobSet.contains($0.cid) }) else { throw PublicRepositoryReferenceImportError.invalidBinding }
        guard envelope.blocks.count + envelope.blobPayloads.count <= maximumBlocks else { throw PublicRepositoryReferenceImportError.blockLimitExceeded }
        var totalBytes = 0
        for block in envelope.blocks {
            let (next, overflow) = totalBytes.addingReportingOverflow(block.bytes.count)
            guard !overflow, next <= maximumBytes else { throw PublicRepositoryReferenceImportError.byteLimitExceeded }
            totalBytes = next
        }
        for block in envelope.blobPayloads {
            let (next, overflow) = totalBytes.addingReportingOverflow(block.bytes.count)
            guard !overflow, next <= maximumBytes else { throw PublicRepositoryReferenceImportError.byteLimitExceeded }
            totalBytes = next
        }
        guard try verifySignature(envelope.did, envelope.rootCID, envelope.signature) else { throw PublicRepositoryReferenceImportError.invalidSignature }

        var byCID: [CID: Data] = [:]
        for block in envelope.blocks {
            try PublicRepositoryCID.validate(block.cid, blockBytes: block.bytes)
            if let existing = byCID[block.cid], existing != block.bytes { throw PublicRepositoryReferenceImportError.duplicateBlockConflict }
            byCID[block.cid] = block.bytes
        }
        for block in envelope.blobPayloads {
            try PublicRepositoryCID.validate(block.cid, blockBytes: block.bytes)
            if let existing = byCID[block.cid], existing != block.bytes { throw PublicRepositoryReferenceImportError.duplicateBlockConflict }
            byCID[block.cid] = block.bytes
        }
        guard byCID[envelope.rootCID] != nil else { throw PublicRepositoryReferenceImportError.invalidRoot }
        for blob in Set(envelope.referencedBlobs) where byCID[blob] == nil {
            guard try await existingBlobResolver?.containsBlob(blob) == true else {
                throw PublicRepositoryReferenceImportError.missingBlob(blob)
            }
        }
        _ = byCID
        let state = try await fullVerifier.verifyAndStage(envelope)
        guard state.did == envelope.did, state.rootCID == envelope.rootCID else { throw PublicRepositoryReferenceImportError.invalidBinding }
        guard !state.blocks.isEmpty, state.blocks.contains(where: { $0.cid == envelope.rootCID }), state.blocks.count <= maximumBlocks else { throw PublicRepositoryReferenceImportError.invalidRoot }
        var stagedBytes = 0
        for block in state.blocks {
            try PublicRepositoryCID.validate(block.cid, blockBytes: block.bytes)
            let (next, overflow) = stagedBytes.addingReportingOverflow(block.bytes.count)
            guard !overflow, next <= maximumBytes else { throw PublicRepositoryReferenceImportError.byteLimitExceeded }
            stagedBytes = next
        }
        return try await committer.commit(state, requestID: envelope.requestID, requestDigest: envelope.requestDigest, expectedRootCID: envelope.expectedExistingRootCID)
    }
}

/// A small actor model used by focused contract tests and local acceptance.
/// Real SQLite adapters must provide the same atomic request-digest/CAS
/// behavior inside their transaction; this model is not production storage.
actor InMemoryPublicRepositoryImportCommitter: PublicRepositoryImportCommitter {
    let isDurableTransactional = false
    private var currentRootCID: CID?
    private var requests: [String: (digest: Data, state: PublicRepositoryImportedState)] = [:]

    public init(currentRootCID: CID? = nil) { self.currentRootCID = currentRootCID }

    public func commit(_ state: PublicRepositoryImportedState, requestID: String, requestDigest: Data, expectedRootCID: CID?) async throws -> PublicRepositoryImportedState {
        guard requestDigest.count == 32 else { throw PublicRepositoryReferenceImportError.invalidBinding }
        if let prior = requests[requestID] {
            guard prior.digest == requestDigest else { throw PublicRepositoryReferenceImportError.conflictingRequestReuse }
            return prior.state
        }
        if let expectedRootCID, currentRootCID != expectedRootCID { throw PublicRepositoryReferenceImportError.commitCASConflict }
        requests[requestID] = (requestDigest, state)
        currentRootCID = state.rootCID
        return state
    }

    public func rootCID() -> CID? { currentRootCID }
}
