import Foundation
import Petrel

/// Read access to blocks by CID. Returns `nil` for a block it does not hold.
public protocol PublicRepositoryBlockSource: Sendable {
    func block(for cid: CID) async throws -> Data?
}

/// One block: a CID and the bytes that hash to it.
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
    private let order: [CID]
    public let relevantByteCount: Int
    /// The immutable effective budget selected when this map was created.
    public let maximumRelevantBytes: Int

    public init(
        blocks: [PublicRepositoryBlock] = [],
        maximumRelevantBytes: Int = PublicRepositoryLimits.pinnedMaximumRelevantBlockBytes
    ) throws {
        guard (0...PublicRepositoryLimits.maximumPermittedCARBytes).contains(maximumRelevantBytes) else {
            throw PublicRepositoryDomainError.relevantBlockBudgetExceeded
        }
        var storage: [CID: Data] = [:]
        var order: [CID] = []
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
            order.append(block.cid)
            relevantByteCount = newCount
        }
        self.storage = storage
        self.order = order
        self.relevantByteCount = relevantByteCount
        self.maximumRelevantBytes = maximumRelevantBytes
    }

    public var count: Int { storage.count }
    public var cids: Set<CID> { Set(storage.keys) }

    /// The blocks in the order they were first added.
    public var orderedBlocks: [PublicRepositoryBlock] {
        order.compactMap { cid in
            storage[cid].map { PublicRepositoryBlock(cid: cid, bytes: $0) }
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage == rhs.storage && lhs.maximumRelevantBytes == rhs.maximumRelevantBytes
    }

    public func block(for cid: CID) -> Data? {
        storage[cid]
    }

    public func block(for cid: CID) async throws -> Data? {
        storage[cid]
    }

    public func adding(_ blocks: [PublicRepositoryBlock]) throws -> Self {
        try Self(blocks: orderedBlocks + blocks, maximumRelevantBytes: maximumRelevantBytes)
    }
}
