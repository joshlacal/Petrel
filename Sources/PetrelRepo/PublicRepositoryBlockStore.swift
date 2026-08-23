import Foundation
import Petrel

public protocol PublicRepositoryBlockSource: Sendable {
    func block(for cid: CID) async throws -> Data?
}

public struct PublicRepositoryBlock: Sendable, Equatable {
    public let cid: CID
    public let bytes: Data

    public init(cid: CID, bytes: Data) {
        self.cid = cid
        self.bytes = bytes
    }
}

/// Immutable, verified new blocks keyed by CID.
public struct PublicRepositoryBlockMap: Sendable, Equatable, PublicRepositoryBlockSource {
    private let storage: [CID: Data]
    public let relevantByteCount: Int
    /// The immutable effective budget selected when this map was created.
    public let maximumRelevantBytes: Int

    public init(
        blocks: [PublicRepositoryBlock] = [],
        maximumRelevantBytes: Int = PublicRepositoryLimits.pinnedMaximumRelevantBlockBytes
    ) throws {
        guard (0...PublicRepositoryLimits.pinnedMaximumRelevantBlockBytes).contains(maximumRelevantBytes) else {
            throw PublicRepositoryDomainError.relevantBlockBudgetExceeded
        }
        var storage: [CID: Data] = [:]
        var relevantByteCount = 0
        for block in blocks {
            if let existing = storage[block.cid] {
                guard existing == block.bytes else {
                    throw PublicRepositoryDomainError.duplicateBlockConflict
                }
                continue
            }
            try PublicRepositoryCID.validate(block.cid, blockBytes: block.bytes)
            let (newCount, overflow) = relevantByteCount.addingReportingOverflow(block.bytes.count)
            guard !overflow, newCount <= maximumRelevantBytes else {
                throw PublicRepositoryDomainError.relevantBlockBudgetExceeded
            }
            storage[block.cid] = block.bytes
            relevantByteCount = newCount
        }
        self.storage = storage
        self.relevantByteCount = relevantByteCount
        self.maximumRelevantBytes = maximumRelevantBytes
    }

    public var count: Int { storage.count }
    public var cids: Set<CID> { Set(storage.keys) }

    public func block(for cid: CID) -> Data? {
        storage[cid]
    }

    public func block(for cid: CID) async throws -> Data? {
        storage[cid]
    }

    public func adding(_ blocks: [PublicRepositoryBlock]) throws -> Self {
        let existing = storage.map { PublicRepositoryBlock(cid: $0.key, bytes: $0.value) }
        return try Self(blocks: existing + blocks, maximumRelevantBytes: maximumRelevantBytes)
    }
}
