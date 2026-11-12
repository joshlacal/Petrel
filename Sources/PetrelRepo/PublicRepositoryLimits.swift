/// Resource limits for reading, verifying and writing repositories.
///
/// Every value is policy, chosen by the application that embeds Petrel. None
/// is a protocol constant except the two firehose-facing defaults
/// (``pinnedMaximumWrites`` and ``pinnedMaximumRelevantBlockBytes``), and even
/// those can be raised for bulk work such as an import or a migration.
///
/// Three presets cover the common cases:
///
/// - ``networkScale``: what the ``Repository`` type uses. Sized for the
///   repository specification's expectation of "single-digit millions" of
///   records per account, with room to spare.
/// - ``standard``: a conservative policy for a service that hosts accounts and
///   wants a small, fixed bound on any one of them (100,000 records). It is the
///   default of the lower-level `PublicRepository*` functions for
///   compatibility with existing callers.
/// - A custom policy from ``init(maximumRecordBlockBytes:maximumCARBytes:maximumCARBlocks:maximumMSTNodes:maximumMSTEntriesPerNode:maximumCBORNestingDepth:maximumRepositoryRecords:maximumWrites:maximumRelevantBlockBytes:)``,
///   bounded only by the `maximumPermitted…` ceilings below, which exist to
///   keep size arithmetic reviewable rather than to restrict use.
public struct PublicRepositoryLimits: Sendable, Equatable {
    /// Maximum writes in one `com.atproto.repo.applyWrites` request in the
    /// reference implementation. The default for ``maximumWrites``.
    public static let pinnedMaximumWrites = 200

    /// Maximum size of the `blocks` field of a `#commit` firehose event
    /// (`com.atproto.sync.subscribeRepos`). The default for
    /// ``maximumRelevantBlockBytes``.
    public static let pinnedMaximumRelevantBlockBytes = 2_000_000

    /// The smallest CAR byte budget a policy may set.
    public static let requiredStreamingCARBytes = 256 * 1_024 * 1_024

    /// The record ceiling of the conservative ``standard`` preset.
    public static let standardMaximumRepositoryRecords = 100_000

    /// A conservative policy for a hosting service: 100,000 records,
    /// 1,000,000 CAR blocks, 500,000 MST nodes, 512 MiB of CAR.
    ///
    /// Use ``networkScale`` (or a custom policy) to read arbitrary accounts
    /// from the network.
    public static let standard = try! PublicRepositoryLimits(
        maximumRecordBlockBytes: 1_000_000,
        maximumCARBytes: 512 * 1_024 * 1_024,
        maximumCARBlocks: 1_000_000,
        maximumMSTNodes: 500_000,
        maximumMSTEntriesPerNode: 4_096,
        maximumCBORNestingDepth: 64
    )

    /// A policy sized for any account on the network: 20,000,000 records,
    /// 64,000,000 CAR blocks, 32,000,000 MST nodes and 64 GiB of CAR.
    ///
    /// The repository specification expects implementations to handle
    /// "single-digit millions" of records. These bounds sit above that so the
    /// limit is never what stops a legitimate repository, while still giving a
    /// hostile input a finite amount of work. Pair it with a
    /// ``FileRepositoryBlockStore`` so memory use follows the block index and
    /// not the archive size.
    public static let networkScale = try! PublicRepositoryLimits(
        maximumRecordBlockBytes: 2_000_000,
        maximumCARBytes: 64 * 1_024 * 1_024 * 1_024,
        maximumCARBlocks: 64_000_000,
        maximumMSTNodes: 32_000_000,
        maximumMSTEntriesPerNode: 4_096,
        maximumCBORNestingDepth: 64,
        maximumRepositoryRecords: 20_000_000
    )

    /// Maximum record writes in one commit.
    public let maximumWrites: Int
    /// Maximum total bytes of the blocks one commit adds (its diff).
    public let maximumRelevantBlockBytes: Int
    /// Maximum size of any single block (record or MST node).
    public let maximumRecordBlockBytes: Int
    /// Maximum size of a CAR archive, and of a repository's reachable blocks.
    public let maximumCARBytes: Int
    /// Maximum number of block frames in a CAR archive.
    public let maximumCARBlocks: Int
    /// Maximum number of MST nodes in one repository.
    public let maximumMSTNodes: Int
    /// Maximum number of entries in one MST node.
    public let maximumMSTEntriesPerNode: Int
    /// Maximum nesting depth of a record's DAG-CBOR.
    public let maximumCBORNestingDepth: Int
    /// Maximum number of records in one repository.
    public let maximumRepositoryRecords: Int

    /// Constructs a policy.
    ///
    /// - Parameters:
    ///   - maximumRecordBlockBytes: Largest single block, `1...maximumPermittedRecordBlockBytes`.
    ///   - maximumCARBytes: Largest archive, `requiredStreamingCARBytes...maximumPermittedCARBytes`.
    ///   - maximumCARBlocks: Most block frames, `1...maximumPermittedCARBlocks`.
    ///   - maximumMSTNodes: Most MST nodes, `1...maximumPermittedMSTNodes`; not above `maximumCARBlocks`.
    ///   - maximumMSTEntriesPerNode: Most entries per node, `1...maximumPermittedMSTEntriesPerNode`.
    ///   - maximumCBORNestingDepth: Deepest record nesting, `1...maximumPermittedCBORNestingDepth`.
    ///   - maximumRepositoryRecords: Most records, `1...maximumPermittedRepositoryRecords`.
    ///     Defaults to ``standardMaximumRepositoryRecords``.
    ///   - maximumWrites: Most writes per commit, `1...maximumPermittedWrites`.
    ///   - maximumRelevantBlockBytes: Largest commit diff, `1...maximumPermittedCARBytes`.
    /// - Throws: ``PublicRepositoryLimitError`` naming the value out of range.
    public init(
        maximumRecordBlockBytes: Int,
        maximumCARBytes: Int,
        maximumCARBlocks: Int,
        maximumMSTNodes: Int,
        maximumMSTEntriesPerNode: Int,
        maximumCBORNestingDepth: Int,
        maximumRepositoryRecords: Int = Self.standardMaximumRepositoryRecords,
        maximumWrites: Int = Self.pinnedMaximumWrites,
        maximumRelevantBlockBytes: Int = Self.pinnedMaximumRelevantBlockBytes
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
        guard (1...Self.maximumPermittedWrites).contains(maximumWrites) else {
            throw PublicRepositoryLimitError.maximumWritesOutOfRange
        }
        guard (1...Self.maximumPermittedCARBytes).contains(maximumRelevantBlockBytes) else {
            throw PublicRepositoryLimitError.maximumRelevantBlockBytesOutOfRange
        }

        self.maximumRepositoryRecords = maximumRepositoryRecords
        self.maximumWrites = maximumWrites
        self.maximumRelevantBlockBytes = maximumRelevantBlockBytes
        self.maximumRecordBlockBytes = maximumRecordBlockBytes
        self.maximumCARBytes = maximumCARBytes
        self.maximumCARBlocks = maximumCARBlocks
        self.maximumMSTNodes = maximumMSTNodes
        self.maximumMSTEntriesPerNode = maximumMSTEntriesPerNode
        self.maximumCBORNestingDepth = maximumCBORNestingDepth
    }

    // The ceilings below bound what a policy may ask for. They are far above
    // any real repository and exist so that sums of counts and sizes stay
    // well inside `Int` on every supported (64-bit) platform.

    /// Ceiling for ``maximumRecordBlockBytes``.
    public static let maximumPermittedRecordBlockBytes = 16 * 1_024 * 1_024
    /// Ceiling for ``maximumCARBytes`` and ``maximumRelevantBlockBytes``.
    public static let maximumPermittedCARBytes = 1_024 * 1_024 * 1_024 * 1_024
    /// Ceiling for ``maximumCARBlocks``.
    public static let maximumPermittedCARBlocks = 1_000_000_000
    /// Ceiling for ``maximumMSTNodes``.
    public static let maximumPermittedMSTNodes = 500_000_000
    /// Ceiling for ``maximumMSTEntriesPerNode``.
    public static let maximumPermittedMSTEntriesPerNode = 4_096
    /// Ceiling for ``maximumCBORNestingDepth``.
    public static let maximumPermittedCBORNestingDepth = 64
    /// Ceiling for ``maximumRepositoryRecords``.
    public static let maximumPermittedRepositoryRecords = 1_000_000_000
    /// Ceiling for ``maximumWrites``.
    public static let maximumPermittedWrites = 1_000_000

    /// A conservative encoded ceiling for one canonical repository MST node.
    /// Each entry can carry at most one complete 1,024-byte key suffix plus
    /// two fixed-width CID links and canonical map/integer framing. The small
    /// node allowance covers the outer map, entry array, and left-tree link.
    public static let maximumCanonicalMSTBlockBytes =
        64 + maximumPermittedMSTEntriesPerNode
            * (PublicRepositoryPath.maximumMSTKeyBytes + 128)

    /// An upper bound on any block a storage layer should expect to persist
    /// under the default record and commit-diff sizes.
    public static let maximumPersistedBlockBytes = max(
        1_000_000,
        pinnedMaximumRelevantBlockBytes,
        maximumCanonicalMSTBlockBytes
    )
}

/// Why a ``PublicRepositoryLimits`` value could not be constructed.
public enum PublicRepositoryLimitError: Error, Sendable, Equatable {
    case maximumRecordBlockBytesOutOfRange
    case maximumCARBytesOutOfRange
    case maximumCARBlocksOutOfRange
    case maximumMSTNodesOutOfRange
    case mstNodesExceedCARBlocks
    case maximumMSTEntriesPerNodeOutOfRange
    case maximumCBORNestingDepthOutOfRange
    case maximumRepositoryRecordsOutOfRange
    case maximumWritesOutOfRange
    case maximumRelevantBlockBytesOutOfRange
}
