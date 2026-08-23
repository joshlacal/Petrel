/// Resource limits shared by the public repository mutation and import paths.
///
/// `maximumWrites` and `maximumRelevantBlockBytes` are frozen interoperability
/// bounds from the pinned atproto implementation. The remaining values are
/// explicit Swan hostile-input policy and may only be tightened or enlarged
/// within the documented construction bounds.
public struct PublicRepositoryLimits: Sendable, Equatable {
    /// Pinned maximum writes in one atomic repository request.
    public static let pinnedMaximumWrites = 200

    /// Pinned maximum aggregate bytes in new/relevant commit blocks.
    public static let pinnedMaximumRelevantBlockBytes = 2_000_000

    /// The acceptance suite requires a 256 MiB CAR to stream successfully.
    public static let requiredStreamingCARBytes = 256 * 1_024 * 1_024

    /// The largest live record count a repository may present.
    ///
    /// This is not a work budget like the others: it is the number the *read*
    /// surface already enforces. `PublicRepositoryReadLimits`
    /// `.maximumGenerationIndexEntries` refuses generation admission — and
    /// therefore `getRecord`, `listRecords`, `getLatestCommit` and `getRepo` —
    /// for any account whose record index exceeds it. Validating an import
    /// against a smaller number than that would refuse repositories Swan can
    /// serve; validating against a larger one would let an import produce a
    /// repository nobody can read. The two must stay equal, which
    /// `PublicRepositoryRecordCeilingTests` pins across the module boundary.
    public static let standardMaximumRepositoryRecords = 100_000

    /// Initial Swan hostile-import policy.
    public static let standard = try! PublicRepositoryLimits(
        maximumRecordBlockBytes: 1_000_000,
        maximumCARBytes: 512 * 1_024 * 1_024,
        maximumCARBlocks: 1_000_000,
        maximumMSTNodes: 500_000,
        maximumMSTEntriesPerNode: 4_096,
        maximumCBORNestingDepth: 64
    )

    public let maximumWrites: Int
    public let maximumRelevantBlockBytes: Int
    public let maximumRecordBlockBytes: Int
    public let maximumCARBytes: Int
    public let maximumCARBlocks: Int
    public let maximumMSTNodes: Int
    public let maximumMSTEntriesPerNode: Int
    public let maximumCBORNestingDepth: Int
    public let maximumRepositoryRecords: Int

    /// Constructs a bounded Swan policy while preserving the pinned protocol
    /// limits. Custom policies can reduce most work budgets; the CAR byte
    /// budget cannot fall below the required 256 MiB streaming acceptance
    /// case.
    ///
    /// `maximumRepositoryRecords` is defaulted rather than required so that
    /// the durable import-session rows, which persist the six work budgets
    /// they were opened with and know nothing about a seventh, keep
    /// reconstructing a policy that carries the standard ceiling.
    public init(
        maximumRecordBlockBytes: Int,
        maximumCARBytes: Int,
        maximumCARBlocks: Int,
        maximumMSTNodes: Int,
        maximumMSTEntriesPerNode: Int,
        maximumCBORNestingDepth: Int,
        maximumRepositoryRecords: Int = Self.standardMaximumRepositoryRecords
    ) throws {
        guard (1...Self.maximumPermittedRecordBlockBytes).contains(maximumRecordBlockBytes) else {
            throw PublicRepositoryLimitError.maximumRecordBlockBytesOutOfRange
        }
        guard (Self.requiredStreamingCARBytes...Self.maximumPermittedCARBytes).contains(maximumCARBytes) else {
            throw PublicRepositoryLimitError.maximumCARBytesOutOfRange
        }
        guard (1...Self.maximumPermittedCARBlocks).contains(maximumCARBlocks) else {
            throw PublicRepositoryLimitError.maximumCARBlocksOutOfRange
        }
        guard (1...Self.maximumPermittedMSTNodes).contains(maximumMSTNodes) else {
            throw PublicRepositoryLimitError.maximumMSTNodesOutOfRange
        }
        guard maximumMSTNodes <= maximumCARBlocks else {
            throw PublicRepositoryLimitError.mstNodesExceedCARBlocks
        }
        guard (1...Self.maximumPermittedMSTEntriesPerNode).contains(maximumMSTEntriesPerNode) else {
            throw PublicRepositoryLimitError.maximumMSTEntriesPerNodeOutOfRange
        }
        guard (1...Self.maximumPermittedCBORNestingDepth).contains(maximumCBORNestingDepth) else {
            throw PublicRepositoryLimitError.maximumCBORNestingDepthOutOfRange
        }
        guard (1...Self.maximumPermittedRepositoryRecords)
            .contains(maximumRepositoryRecords) else {
            throw PublicRepositoryLimitError.maximumRepositoryRecordsOutOfRange
        }

        self.maximumRepositoryRecords = maximumRepositoryRecords
        maximumWrites = Self.pinnedMaximumWrites
        maximumRelevantBlockBytes = Self.pinnedMaximumRelevantBlockBytes
        self.maximumRecordBlockBytes = maximumRecordBlockBytes
        self.maximumCARBytes = maximumCARBytes
        self.maximumCARBlocks = maximumCARBlocks
        self.maximumMSTNodes = maximumMSTNodes
        self.maximumMSTEntriesPerNode = maximumMSTEntriesPerNode
        self.maximumCBORNestingDepth = maximumCBORNestingDepth
    }

    /// A finite ceiling keeps frame-count arithmetic and operational policy
    /// reviewable even on 64-bit platforms where `Int.max` is much larger.
    public static let maximumPermittedRecordBlockBytes = 1_000_000
    public static let maximumPermittedCARBytes = 4 * 1_024 * 1_024 * 1_024
    public static let maximumPermittedCARBlocks = 1_000_000
    public static let maximumPermittedMSTNodes = 500_000
    public static let maximumPermittedMSTEntriesPerNode = 4_096
    public static let maximumPermittedCBORNestingDepth = 64
    /// The public read surface refuses anything above the standard ceiling, so
    /// a policy may only tighten this, never raise it.
    public static let maximumPermittedRepositoryRecords =
        standardMaximumRepositoryRecords

    /// A conservative encoded ceiling for one canonical repository MST node.
    /// Each entry can carry at most one complete 1,024-byte key suffix plus
    /// two fixed-width CID links and canonical map/integer framing. The small
    /// node allowance covers the outer map, entry array, and left-tree link.
    public static let maximumCanonicalMSTBlockBytes =
        64 + maximumPermittedMSTEntriesPerNode
            * (PublicRepositoryPath.maximumMSTKeyBytes + 128)

    /// No authenticated repository block can legitimately exceed this value:
    /// records have their own smaller limit, locally/imported relevant blocks
    /// obey the pinned aggregate budget, and canonical MST nodes obey the
    /// structural bound above. SQLite uses this before materializing a BLOB.
    public static let maximumPersistedBlockBytes = max(
        maximumPermittedRecordBlockBytes,
        pinnedMaximumRelevantBlockBytes,
        maximumCanonicalMSTBlockBytes
    )
}

public enum PublicRepositoryLimitError: Error, Sendable, Equatable {
    case maximumRecordBlockBytesOutOfRange
    case maximumCARBytesOutOfRange
    case maximumCARBlocksOutOfRange
    case maximumMSTNodesOutOfRange
    case mstNodesExceedCARBlocks
    case maximumMSTEntriesPerNodeOutOfRange
    case maximumCBORNestingDepthOutOfRange
    case maximumRepositoryRecordsOutOfRange
}
