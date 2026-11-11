// The traversal invariants enforced here (layer arithmetic, key ordering,
// empty-node topology) are those of bluesky-social/atproto
// packages/repo/src/mst/mst.ts; see THIRD_PARTY_NOTICES.md.

import Foundation
import Petrel

/// What a full in-order walk of an MST found.
public struct RepositoryMSTWalkSummary: Sendable, Equatable {
    /// CID of the root node.
    public let rootCID: CID
    /// Layer of the root node (0 for a tree with only leaf-level keys).
    public let rootLayer: Int
    /// Number of MST nodes visited.
    public let nodeCount: Int
    /// Number of leaves (records) visited.
    public let recordCount: Int
}

/// An in-order, depth-first walk of an MST that verifies the tree as it goes.
///
/// Memory is proportional to the tree's depth (at most 129 nodes), not to the
/// number of records: nothing is accumulated, and each leaf is handed to the
/// caller in key order as it is reached. That is the difference from
/// ``RepositoryMSTValidation/validate(rootCID:blocks:limits:maximumReachableRepositoryBytes:policy:)``,
/// which returns every leaf at once.
///
/// For every node visited the walk checks: the block hashes to the CID that
/// referenced it; the node is canonical DAG-CBOR of the node schema; prefix
/// compression is minimal; every key has the depth its layer requires; child
/// nodes sit exactly one layer down; an empty node appears only as the lone
/// root or as an intermediate node with a left subtree; and keys are strictly
/// increasing across the whole tree. Together those make a repeated or cyclic
/// node impossible to hide: a subtree reachable twice would have to hold keys
/// inside two disjoint ranges.
public enum RepositoryMSTWalker {
    /// A half-open key range, `lower <= key < upper`, as raw key bytes.
    public struct KeyRange: Sendable, Equatable {
        /// Inclusive lower bound, or `nil` for the start of the tree.
        public var lower: Data?
        /// Exclusive upper bound, or `nil` for the end of the tree.
        public var upper: Data?

        /// Creates a range.
        public init(lower: Data? = nil, upper: Data? = nil) {
            self.lower = lower
            self.upper = upper
        }

        /// Every key.
        public static let all = KeyRange()

        /// Every key of one collection: `<collection>/` up to, but not
        /// including, `<collection>0` (`0` is the byte after `/`).
        public static func collection(_ collection: String) -> KeyRange {
            KeyRange(
                lower: Data("\(collection)/".utf8),
                upper: Data("\(collection)0".utf8)
            )
        }
    }

    /// Walks the tree in key order.
    ///
    /// - Parameters:
    ///   - rootCID: CID of the root node (a commit's `data`).
    ///   - blocks: Where node blocks are read from.
    ///   - limits: Bounds on nodes, entries per node and records.
    ///   - options: Key syntax and leaf-link policy.
    ///   - range: Restrict the walk to these keys. Subtrees that cannot
    ///     intersect the range are not read, so a ranged walk verifies only
    ///     the nodes it touches and its summary counts only those.
    ///   - onNode: Called with each MST node block when it is first reached,
    ///     before any of its entries. Together with `onLeaf` this yields the
    ///     pre-order the specification describes for streamable CAR files.
    ///   - onLeaf: Called once per leaf in increasing key order. Return
    ///     `false` to stop the walk early.
    /// - Returns: Counts for the part of the tree that was walked.
    /// - Throws: ``RepositoryMSTValidationError``, or whatever `onLeaf` or the
    ///   block source throws.
    @discardableResult
    public static func walk(
        rootCID: CID,
        blocks: any PublicRepositoryBlockSource,
        limits: PublicRepositoryLimits = .networkScale,
        options: RepositoryMSTOptions = .dataModel,
        range: KeyRange = .all,
        onNode: ((PublicRepositoryBlock) async throws -> Void)? = nil,
        onLeaf: (RepositoryMSTLeaf) async throws -> Bool
    ) async throws -> RepositoryMSTWalkSummary {
        guard rootCID.blessedKind == .dagCBOR else {
            throw RepositoryMSTValidationError.unsupportedCID
        }

        struct Frame {
            let leaves: [RepositoryMSTLeaf]
            let leftTreeCID: CID?
            let layer: Int
            let lower: Data?
            let upper: Data?
            /// Next step: 0 = left subtree, then for leaf `i`: `2i + 1` emits
            /// the leaf and `2i + 2` descends into its right subtree.
            var step = 0
        }

        var nodeCount = 0
        var recordCount = 0
        var previousKey: Data?

        func load(
            _ cid: CID, expectedLayer: Int?, isRoot: Bool, lower: Data?, upper: Data?
        ) async throws -> Frame {
            nodeCount += 1
            guard nodeCount <= limits.maximumMSTNodes else {
                throw RepositoryMSTValidationError.nodeLimitExceeded
            }
            guard let bytes = try await blocks.block(for: cid) else {
                throw RepositoryMSTValidationError.missingBlock
            }
            guard cid.matchesContent(bytes) else {
                throw RepositoryMSTValidationError.blockCIDMismatch
            }
            let node = try RepositoryMSTCodec.decode(bytes, options: options)
            guard node.entries.count <= limits.maximumMSTEntriesPerNode else {
                throw RepositoryMSTValidationError.entryLimitExceeded
            }
            let leaves = try RepositoryMSTCodec.reconstructedLeaves(from: node, options: options)
            let layer: Int
            if let first = leaves.first {
                layer = first.path.keyDepth
                guard (0 ... 128).contains(layer),
                      expectedLayer == nil || expectedLayer == layer else {
                    throw RepositoryMSTValidationError.invalidLayer
                }
                guard leaves.allSatisfy({ $0.path.keyDepth == layer }) else {
                    throw RepositoryMSTValidationError.leafLayerMismatch
                }
                guard layer > 0 || (node.leftTreeCID == nil
                    && leaves.allSatisfy { $0.rightTreeCID == nil }) else {
                    throw RepositoryMSTValidationError.invalidLayer
                }
            } else if isRoot {
                guard node.leftTreeCID == nil else {
                    throw RepositoryMSTValidationError.invalidEmptyTopology
                }
                layer = 0
            } else {
                guard let expectedLayer, expectedLayer > 0, node.leftTreeCID != nil else {
                    throw RepositoryMSTValidationError.invalidEmptyTopology
                }
                layer = expectedLayer
            }
            if let onNode {
                try await onNode(PublicRepositoryBlock(cid: cid, bytes: bytes))
            }
            return Frame(
                leaves: leaves, leftTreeCID: node.leftTreeCID, layer: layer,
                lower: lower, upper: upper
            )
        }

        /// Whether a subtree whose keys lie strictly between `lower` and
        /// `upper` can contain a key of the requested range.
        func intersects(lower: Data?, upper: Data?) -> Bool {
            if let rangeUpper = range.upper, let lower,
               !RepositoryMSTCodec.lexicographicallyPrecedes(lower, rangeUpper) {
                return false
            }
            if let rangeLower = range.lower, let upper,
               !RepositoryMSTCodec.lexicographicallyPrecedes(rangeLower, upper) {
                return false
            }
            return true
        }

        let root = try await load(rootCID, expectedLayer: nil, isRoot: true, lower: nil, upper: nil)
        let rootLayer = root.layer
        var stack = [root]

        walking: while var frame = stack.popLast() {
            try Task.checkCancellation()
            let step = frame.step
            frame.step += 1
            let leafCount = frame.leaves.count
            guard step <= 2 * leafCount else { continue }
            stack.append(frame)

            let childCID: CID?
            let childLower: Data?
            let childUpper: Data?
            if step == 0 {
                childCID = frame.leftTreeCID
                childLower = frame.lower
                childUpper = frame.leaves.first?.path.mstKeyBytes ?? frame.upper
            } else if step % 2 == 1 {
                let leaf = frame.leaves[(step - 1) / 2]
                let key = leaf.path.mstKeyBytes
                if let lower = frame.lower,
                   !RepositoryMSTCodec.lexicographicallyPrecedes(lower, key) {
                    throw RepositoryMSTValidationError.subtreeOutOfRange
                }
                if let upper = frame.upper,
                   !RepositoryMSTCodec.lexicographicallyPrecedes(key, upper) {
                    throw RepositoryMSTValidationError.subtreeOutOfRange
                }
                if let previousKey,
                   !RepositoryMSTCodec.lexicographicallyPrecedes(previousKey, key) {
                    throw RepositoryMSTValidationError.keysNotStrictlyIncreasing
                }
                previousKey = key
                if let rangeUpper = range.upper,
                   !RepositoryMSTCodec.lexicographicallyPrecedes(key, rangeUpper) {
                    // In-order: every later key is beyond the range too.
                    break walking
                }
                if let rangeLower = range.lower,
                   RepositoryMSTCodec.lexicographicallyPrecedes(key, rangeLower) {
                    continue
                }
                recordCount += 1
                guard recordCount <= limits.maximumRepositoryRecords else {
                    throw RepositoryMSTValidationError.recordLimitExceeded
                }
                guard try await onLeaf(leaf) else { break walking }
                continue
            } else {
                let index = step / 2 - 1
                childCID = frame.leaves[index].rightTreeCID
                childLower = frame.leaves[index].path.mstKeyBytes
                childUpper = index + 1 < leafCount
                    ? frame.leaves[index + 1].path.mstKeyBytes
                    : frame.upper
            }

            guard let childCID, intersects(lower: childLower, upper: childUpper) else { continue }
            stack.append(try await load(
                childCID, expectedLayer: frame.layer - 1, isRoot: false,
                lower: childLower, upper: childUpper
            ))
        }

        return RepositoryMSTWalkSummary(
            rootCID: rootCID,
            rootLayer: rootLayer,
            nodeCount: nodeCount,
            recordCount: recordCount
        )
    }
}
