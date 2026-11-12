// This file adapts the immutable/lazy MST mutation algorithm from
// bluesky-social/atproto@3f6c96d5d2d25438bd40fa89d6ecc37865f8e354
// packages/repo/src/mst/{mst,util}.ts, used under the repository's
// MIT OR Apache-2.0 notice policy recorded in THIRD_PARTY_NOTICES.md.

import Foundation
import Petrel
import Synchronization

public enum RepositoryMSTMutationError: Error, Sendable, Equatable {
    case duplicateKey
    case missingKey
    case missingBlock
    case blockCIDMismatch
    case invalidNode
    case invalidLayer
    case nodeLimitExceeded
    case entryLimitExceeded
    case relevantBlockBudgetExceeded
}

/// The root CID of a tree and the MST node blocks that are new relative to
/// the tree it was loaded from.
///
/// "New" is decided by comparing trees, not by asking the block store what it
/// already holds: a node is new when it is in this tree and was not part of
/// the base tree. A store that happens to retain a block from older history
/// therefore cannot make a block disappear from a commit diff.
public struct MaterializedRepositoryMST: Sendable, Equatable {
    /// CID of the root node.
    public let rootCID: CID
    /// Node blocks present in this tree and absent from its base tree.
    public let newBlocks: PublicRepositoryBlockMap
}

/// One bounded, repository-native page. `visitedNodeCount` is intentionally
/// exposed so storage and adversarial tests can prove that pagination work is
/// a function of the requested page size and MST depth rather than repository
/// cardinality.
public struct RepositoryMSTPage: Sendable, Equatable {
    public let leaves: [RepositoryMSTLeaf]
    public let visitedNodeCount: Int

    public init(leaves: [RepositoryMSTLeaf], visitedNodeCount: Int) {
        self.leaves = leaves
        self.visitedNodeCount = visitedNodeCount
    }
}

/// An immutable repository MST. Loaded nodes retain only their CID and block
/// source until an operation reaches them; mutations replace just the nodes on
/// the affected search path.
public struct RepositoryMST: Sendable {
    private indirect enum Entry: Sendable {
        case leaf(RepositoryMSTLeaf)
        case tree(RepositoryMST)
    }
    private let blocks: any PublicRepositoryBlockSource
    private let pointer: CID?
    private var knownEntries: [Entry]?
    private var knownLayer: Int?
    private let limits: PublicRepositoryLimits
    private let options: RepositoryMSTOptions
    private let context: RepositoryMSTMutationContext
    private init(
        blocks: any PublicRepositoryBlockSource,
        pointer: CID?,
        entries: [Entry]?,
        layer: Int?,
        limits: PublicRepositoryLimits,
        options: RepositoryMSTOptions,
        context: RepositoryMSTMutationContext = RepositoryMSTMutationContext()
    ) {
        self.blocks = blocks
        self.pointer = pointer
        knownEntries = entries
        knownLayer = layer
        self.limits = limits
        self.options = options
        self.context = context
    }

    /// Opens the tree rooted at `rootCID` without reading any block. Nodes
    /// are fetched from `blocks` only when an operation reaches them, so a
    /// source holding just part of the tree (a proof, a commit diff) works
    /// for every operation that stays inside that part.
    ///
    /// - Parameters:
    ///   - rootCID: CID of the root node (a commit's `data`).
    ///   - blocks: Where node blocks are read from.
    ///   - limits: Bounds on nodes, entries per node and commit-diff size.
    ///   - options: Key syntax and leaf-link policy.
    public static func load(
        rootCID: CID,
        blocks: any PublicRepositoryBlockSource,
        limits: PublicRepositoryLimits = .standard,
        options: RepositoryMSTOptions = .strict
    ) throws -> Self {
        do {
            try PublicRepositoryCID.validate(rootCID)
        } catch {
            throw RepositoryMSTMutationError.blockCIDMismatch
        }
        let context = RepositoryMSTMutationContext()
        context.noteBase(rootCID)
        return Self(
            blocks: blocks,
            pointer: rootCID,
            entries: nil,
            layer: nil,
            limits: limits,
            options: options,
            context: context
        )
    }

    /// The empty tree: one node with no entries.
    public static func empty(
        limits: PublicRepositoryLimits = .standard,
        options: RepositoryMSTOptions = .strict
    ) throws -> Self {
        let bytes = PublicRepositoryGenesisCodec.canonicalEmptyMST
        let cid = CID.fromDAGCBOR(bytes)
        let source = try PublicRepositoryBlockMap(
            blocks: [.init(cid: cid, bytes: bytes)],
            maximumRelevantBytes: limits.maximumRelevantBlockBytes
        )
        let context = RepositoryMSTMutationContext()
        context.noteBase(cid)
        return Self(
            blocks: source,
            pointer: cid,
            entries: [],
            layer: 0,
            limits: limits,
            options: options,
            context: context
        )
    }

    public func get(_ path: PublicRepositoryPath) async throws -> CID? {
        let (cid, _) = try await getWithTree(path)
        return cid
    }

    public func getWithTree(_ path: PublicRepositoryPath) async throws -> (cid: CID?, tree: Self) {
        var copy = self
        let cid = try await copy.getMutating(path)
        return (cid, copy)
    }

    private mutating func getMutating(_ path: PublicRepositoryPath) async throws -> CID? {
        let (entries, _) = try await loadNode()
        let index = firstLeafIndex(notLessThan: path, in: entries)
        if case let .leaf(leaf)? = entry(at: index, in: entries), leaf.path == path {
            return leaf.recordCID
        }
        if case let .tree(subtree)? = entry(at: index - 1, in: entries) {
            var child = subtree
            let cid = try await child.getMutating(path)
            knownEntries?[index - 1] = .tree(child)
            return cid
        }
        return nil
    }

    public func adding(path: PublicRepositoryPath, recordCID: CID) async throws -> Self {
        try validateRecordCID(recordCID)
        var copy = self
        return try await copy.add(path: path, recordCID: recordCID, knownDepth: nil)
    }

    public func updating(path: PublicRepositoryPath, recordCID: CID) async throws -> Self {
        try validateRecordCID(recordCID)
        var copy = self
        let (entries, _) = try await copy.loadNode()
        let index = firstLeafIndex(notLessThan: path, in: entries)
        if case let .leaf(found)? = entry(at: index, in: entries), found.path == path {
            return try copy.replacing(
                entryAt: index,
                with: .leaf(.init(path: path, recordCID: recordCID)),
                in: entries
            )
        }
        if case let .tree(subtree)? = entry(at: index - 1, in: entries) {
            let updated = try await subtree.updating(path: path, recordCID: recordCID)
            return try copy.replacing(entryAt: index - 1, with: .tree(updated), in: entries)
        }
        throw RepositoryMSTMutationError.missingKey
    }

    public func deleting(path: PublicRepositoryPath) async throws -> Self {
        var copy = self
        var deleted = try await copy.deleteRecursively(path: path)
        return try await deleted.trimmingTop()
    }

    public func listed() async throws -> [RepositoryMSTLeaf] {
        var result: [RepositoryMSTLeaf] = []
        var copy = self
        try await copy.appendLeaves(to: &result)
        return result
    }

    /// Returns at most `limit` leaves from one collection without materializing
    /// the repository or consulting a secondary SQL index.
    ///
    /// The pinned TypeScript actor-store contract is descending by default
    /// (`key < cursor`) and ascending when `reverse` is true (`key > cursor`).
    /// Child subtrees are pruned using the adjacent MST leaf bounds, so a
    /// missing collection or a small page cannot degenerate into a full scan.
    public func page(
        collection: String,
        limit: Int,
        cursor: String?,
        reverse: Bool
    ) async throws -> RepositoryMSTPage {
        guard (1...100).contains(limit) else {
            throw RepositoryMSTMutationError.entryLimitExceeded
        }
        _ = try PublicRepositoryPath(
            collection: collection,
            recordKey: cursor ?? "validation"
        )

        let collectionPrefix = Data("\(collection)/".utf8)
        var collectionUpperBound = collectionPrefix
        guard let separator = collectionUpperBound.popLast(),
              separator == UInt8(ascii: "/") else {
            throw RepositoryMSTMutationError.invalidNode
        }
        collectionUpperBound.append(separator + 1)

        let lowerBound: Data
        let upperBound: Data
        if let cursor {
            let cursorKey = Data("\(collection)/\(cursor)".utf8)
            if reverse {
                lowerBound = cursorKey
                upperBound = collectionUpperBound
            } else {
                lowerBound = collectionPrefix
                upperBound = cursorKey
            }
        } else {
            lowerBound = collectionPrefix
            upperBound = collectionUpperBound
        }

        // An MST has at most 129 layers (0...128). A range page can reach one
        // search path per emitted leaf plus the two boundary paths. This
        // ceiling is deliberately independent of total repository size.
        let maximumVisitedNodes = min(
            limits.maximumMSTNodes,
            (limit + 2) * 129
        )
        let budget = RepositoryMSTPageTraversalBudget(
            maximumVisitedNodes: maximumVisitedNodes
        )
        var leaves: [RepositoryMSTLeaf] = []
        var copy = self
        try await copy.appendPageLeaves(
            lowerBound: lowerBound,
            upperBound: upperBound,
            reverse: reverse,
            inheritedLowerBound: nil,
            inheritedUpperBound: nil,
            limit: limit,
            budget: budget,
            to: &leaves
        )
        return RepositoryMSTPage(
            leaves: leaves,
            visitedNodeCount: budget.visitedNodeCount
        )
    }

    /// Encodes every node this lineage created and returns the root CID with
    /// the node blocks that are new relative to the base tree.
    ///
    /// The total size of the new blocks is bounded by
    /// `limits.maximumRelevantBlockBytes`, the commit-diff budget. Raise that
    /// limit for bulk construction.
    public func materialized() async throws -> MaterializedRepositoryMST {
        var collector = NewBlockCollector(
            maximumNodes: limits.maximumMSTNodes,
            maximumBytes: limits.maximumRelevantBlockBytes
        )
        var copy = self
        let root = try await copy.collectNewBlocks(into: &collector)
        let map: PublicRepositoryBlockMap
        do {
            map = try PublicRepositoryBlockMap(
                blocks: collector.blocks,
                maximumRelevantBytes: limits.maximumRelevantBlockBytes
            )
        } catch PublicRepositoryDomainError.relevantBlockBudgetExceeded {
            throw RepositoryMSTMutationError.relevantBlockBudgetExceeded
        } catch {
            throw error
        }
        return MaterializedRepositoryMST(rootCID: root, newBlocks: map)
    }

    /// The CID of the root node, encoding whatever this lineage changed.
    ///
    /// Unlike ``materialized()`` this is not bounded by the commit-diff
    /// budget and returns no blocks. It reads no block that the operations so
    /// far did not already reach, which is what lets an operation-inversion
    /// check run over a partial tree.
    public func rootCID() async throws -> CID {
        var collector = NewBlockCollector(
            maximumNodes: limits.maximumMSTNodes,
            maximumBytes: Int.max
        )
        var copy = self
        return try await copy.collectNewBlocks(into: &collector)
    }

    /// The node blocks a consumer needs to verify, and to invert, an
    /// operation on `path` against this tree: the search path for the key and
    /// the paths to its nearest neighbour on each side.
    ///
    /// This is the "covering proof" of the sync specification and matches the
    /// reference implementation's `MST.getCoveringProof`. Call it on the tree
    /// *after* the commit, once per created, updated or deleted path.
    public func coveringProof(for path: PublicRepositoryPath) async throws -> [PublicRepositoryBlock] {
        try await coveringProof(for: [path])
    }

    /// The union of ``coveringProof(for:)-(PublicRepositoryPath)`` over
    /// several paths, without duplicates, in first-visited order.
    public func coveringProof(for paths: [PublicRepositoryPath]) async throws -> [PublicRepositoryBlock] {
        var collector = NewBlockCollector(
            maximumNodes: limits.maximumMSTNodes,
            maximumBytes: Int.max,
            collectsEverything: true
        )
        var copy = self
        let root = try await copy.collectNewBlocks(into: &collector)
        let overlay = RepositoryOverlayBlockSource(
            overlay: Dictionary(
                collector.blocks.map { ($0.cid, $0.bytes) },
                uniquingKeysWith: { first, _ in first }
            ),
            base: blocks
        )
        var seen = Set<CID>()
        var result: [PublicRepositoryBlock] = []
        for path in paths {
            let proof: [PublicRepositoryBlock]
            do {
                proof = try await RepositoryMSTProof.coveringProof(
                    rootCID: root,
                    path: path,
                    blocks: overlay,
                    limits: limits,
                    options: options
                )
            } catch let error as RepositoryMSTValidationError {
                throw error == .missingBlock
                    ? RepositoryMSTMutationError.missingBlock
                    : RepositoryMSTMutationError.invalidNode
            }
            for block in proof where seen.insert(block.cid).inserted {
                result.append(block)
            }
        }
        return result
    }

    // MARK: Mutation

    private mutating func add(
        path: PublicRepositoryPath,
        recordCID: CID,
        knownDepth: Int?
    ) async throws -> Self {
        let keyDepth = knownDepth ?? path.keyDepth
        let (entries, layer) = try await loadNode()
        let leaf = Entry.leaf(.init(path: path, recordCID: recordCID))

        if keyDepth == layer {
            let index = firstLeafIndex(notLessThan: path, in: entries)
            if case let .leaf(found)? = entry(at: index, in: entries), found.path == path {
                throw RepositoryMSTMutationError.duplicateKey
            }
            if case let .tree(subtree)? = entry(at: index - 1, in: entries) {
                var child = subtree
                let split = try await child.split(around: path)
                var replacement: [Entry] = []
                if let left = split.left { replacement.append(.tree(left)) }
                replacement.append(leaf)
                if let right = split.right { replacement.append(.tree(right)) }
                var updated = Array(entries[..<(index - 1)])
                updated.append(contentsOf: replacement)
                updated.append(contentsOf: entries[index...])
                return try newTree(updated, layer: layer)
            }
            var updated = entries
            updated.insert(leaf, at: index)
            return try newTree(updated, layer: layer)
        }

        if keyDepth < layer {
            let index = firstLeafIndex(notLessThan: path, in: entries)
            if case let .tree(subtree)? = entry(at: index - 1, in: entries) {
                var child = subtree
                let updated = try await child.add(
                    path: path,
                    recordCID: recordCID,
                    knownDepth: keyDepth
                )
                return try replacing(entryAt: index - 1, with: .tree(updated), in: entries)
            }
            var child = Self(
                blocks: blocks,
                pointer: nil,
                entries: [],
                layer: layer - 1,
                limits: limits,
                options: options,
                context: context
            )
            let updatedChild = try await child.add(
                path: path,
                recordCID: recordCID,
                knownDepth: keyDepth
            )
            var updated = entries
            updated.insert(.tree(updatedChild), at: index)
            return try newTree(updated, layer: layer)
        }

        let split = try await split(around: path)
        var left = split.left
        var right = split.right
        let extraLayers = keyDepth - layer
        if extraLayers > 1 {
            for _ in 1 ..< extraLayers {
                if let current = left { left = try current.parent() }
                if let current = right { right = try current.parent() }
            }
        }
        var rootEntries: [Entry] = []
        if let left { rootEntries.append(.tree(left)) }
        rootEntries.append(leaf)
        if let right { rootEntries.append(.tree(right)) }
        return try Self(
            blocks: blocks,
            pointer: nil,
            entries: rootEntries,
            layer: keyDepth,
            limits: limits,
            options: options,
            context: context
        ).checked()
    }

    private mutating func deleteRecursively(path: PublicRepositoryPath) async throws -> Self {
        let (entries, _) = try await loadNode()
        let index = firstLeafIndex(notLessThan: path, in: entries)
        if case let .leaf(found)? = entry(at: index, in: entries), found.path == path {
            if case let .tree(left)? = entry(at: index - 1, in: entries),
               case let .tree(right)? = entry(at: index + 1, in: entries) {
                var leftCopy = left
                let merged = try await leftCopy.appendingMerge(right)
                var updated = Array(entries[..<(index - 1)])
                updated.append(.tree(merged))
                if index + 2 < entries.count {
                    updated.append(contentsOf: entries[(index + 2)...])
                }
                return try newTree(updated)
            }
            var updated = entries
            updated.remove(at: index)
            return try newTree(updated)
        }

        if case let .tree(subtree)? = entry(at: index - 1, in: entries) {
            var child = subtree
            let updatedSubtree = try await child.deleteRecursively(path: path)
            var updatedChild = updatedSubtree
            let (childEntries, _) = try await updatedChild.loadNode()
            if childEntries.isEmpty {
                var updated = entries
                updated.remove(at: index - 1)
                return try newTree(updated)
            }
            return try replacing(entryAt: index - 1, with: .tree(updatedSubtree), in: entries)
        }
        throw RepositoryMSTMutationError.missingKey
    }

    private mutating func split(around path: PublicRepositoryPath) async throws -> (left: Self?, right: Self?) {
        let (entries, currentLayer) = try await loadNode()
        let index = firstLeafIndex(notLessThan: path, in: entries)
        var leftEntries = Array(entries[..<index])
        var rightEntries = Array(entries[index...])

        if case let .tree(boundary)? = leftEntries.last {
            leftEntries.removeLast()
            var boundaryCopy = boundary
            let splitBoundary = try await boundaryCopy.split(around: path)
            if let left = splitBoundary.left { leftEntries.append(.tree(left)) }
            if let right = splitBoundary.right { rightEntries.insert(.tree(right), at: 0) }
        }

        let left = leftEntries.isEmpty ? nil : try newTree(leftEntries, layer: currentLayer)
        let right = rightEntries.isEmpty ? nil : try newTree(rightEntries, layer: currentLayer)
        return (left, right)
    }

    private mutating func appendingMerge(_ other: Self) async throws -> Self {
        var otherCopy = other
        let (_, selfLayer) = try await loadNode()
        let (_, otherLayer) = try await otherCopy.loadNode()
        guard selfLayer == otherLayer else {
            throw RepositoryMSTMutationError.invalidLayer
        }
        let (selfEntries, _) = try await loadNode()
        let (otherEntries, _) = try await otherCopy.loadNode()
        var leftEntries = selfEntries
        var rightEntries = otherEntries
        if case let .tree(leftBoundary)? = leftEntries.last,
           case let .tree(rightBoundary)? = rightEntries.first {
            leftEntries.removeLast()
            rightEntries.removeFirst()
            var leftCopy = leftBoundary
            let merged = try await leftCopy.appendingMerge(rightBoundary)
            return try newTree(leftEntries + [.tree(merged)] + rightEntries)
        }
        return try newTree(leftEntries + rightEntries)
    }

    private mutating func trimmingTop() async throws -> Self {
        let (entries, _) = try await loadNode()
        if entries.count == 1, case let .tree(child) = entries[0] {
            var childCopy = child
            return try await childCopy.trimmingTop()
        }
        return self
    }

    private func parent() throws -> Self {
        guard let layer = knownLayer, layer < 128 else {
            throw RepositoryMSTMutationError.invalidLayer
        }
        return try Self(
            blocks: blocks,
            pointer: nil,
            entries: [.tree(self)],
            layer: layer + 1,
            limits: limits,
            options: options,
            context: context
        ).checked()
    }
    // MARK: Loading and encoding
    private mutating func loadNode(discoveryDepth: Int = 0) async throws -> (entries: [Entry], layer: Int) {
        guard discoveryDepth <= 128 else {
            throw RepositoryMSTMutationError.invalidLayer
        }
        if let knownEntries, let knownLayer {
            return (knownEntries, knownLayer)
        }
        if let knownEntries {
            let l = try await computeLayer(from: knownEntries, discoveryDepth: discoveryDepth)
            knownLayer = l
            return (knownEntries, l)
        }
        guard let pointer else {
            throw RepositoryMSTMutationError.missingBlock
        }
        // Reads are bounded by the number of distinct nodes, never by a
        // running byte total: looking the same key up twice must cost the
        // same as looking it up once.
        try context.visit(pointer, limits: limits)
        guard let bytes = try await blocks.block(for: pointer) else {
            throw RepositoryMSTMutationError.missingBlock
        }
        do {
            try PublicRepositoryCID.validate(pointer, blockBytes: bytes)
        } catch {
            throw RepositoryMSTMutationError.blockCIDMismatch
        }
        let node: RepositoryMSTNode
        do {
            node = try RepositoryMSTCodec.decode(bytes, options: options)
        } catch {
            throw RepositoryMSTMutationError.invalidNode
        }
        let leaves: [RepositoryMSTLeaf]
        do {
            leaves = try RepositoryMSTCodec.reconstructedLeaves(from: node, options: options)
        } catch {
            throw RepositoryMSTMutationError.invalidNode
        }
        if let left = node.leftTreeCID { context.noteBase(left) }
        for leaf in leaves {
            if let right = leaf.rightTreeCID { context.noteBase(right) }
        }
        let inferredLayer = leaves.first.map(\.path.keyDepth)
        let childLayer = knownLayer.map { $0 - 1 } ?? inferredLayer.map { $0 - 1 }
        var result: [Entry] = []
        if let left = node.leftTreeCID {
            result.append(.tree(Self(
                blocks: blocks,
                pointer: left,
                entries: nil,
                layer: childLayer,
                limits: limits,
                options: options,
                context: context
            )))
        }
        for leaf in leaves {
            result.append(.leaf(.init(path: leaf.path, recordCID: leaf.recordCID)))
            if let right = leaf.rightTreeCID {
                result.append(.tree(Self(
                    blocks: blocks,
                    pointer: right,
                    entries: nil,
                    layer: childLayer,
                    limits: limits,
                    options: options,
                    context: context
                )))
            }
        }
        guard result.count <= limits.maximumMSTEntriesPerNode * 2 + 1 else {
            throw RepositoryMSTMutationError.entryLimitExceeded
        }
        let resolvedLayer: Int
        if let knownLayer {
            guard (0 ... 128).contains(knownLayer) else {
                throw RepositoryMSTMutationError.invalidLayer
            }
            resolvedLayer = knownLayer
        } else if let inferredLayer {
            guard (0 ... 128).contains(inferredLayer) else {
                throw RepositoryMSTMutationError.invalidLayer
            }
            resolvedLayer = inferredLayer
        } else {
            resolvedLayer = try await computeLayer(from: result, discoveryDepth: discoveryDepth)
        }
        knownEntries = result
        knownLayer = resolvedLayer
        return (result, resolvedLayer)
    }

    private func computeLayer(from entries: [Entry], discoveryDepth: Int = 0) async throws -> Int {
        for entry in entries {
            if case let .leaf(leaf) = entry {
                return leaf.path.keyDepth
            }
        }
        // Iterative layer discovery with depth bounding to prevent stack exhaustion on chains of empty nodes
        var currentEntries = entries
        var accumulatedDepth = discoveryDepth
        while accumulatedDepth <= 128 {
            var foundTree: Self?
            for entry in currentEntries {
                if case let .leaf(leaf) = entry {
                    return leaf.path.keyDepth + (accumulatedDepth - discoveryDepth)
                }
                if case let .tree(child) = entry, foundTree == nil {
                    foundTree = child
                }
            }
            guard var child = foundTree else {
                return accumulatedDepth - discoveryDepth
            }
            accumulatedDepth += 1
            guard accumulatedDepth <= 128 else {
                throw RepositoryMSTMutationError.invalidLayer
            }
            let (childEntries, _) = try await child.loadNode(discoveryDepth: accumulatedDepth)
            currentEntries = childEntries
        }
        throw RepositoryMSTMutationError.invalidLayer
    }

    private mutating func collectNewBlocks(into collector: inout NewBlockCollector) async throws -> CID {
        // A node that still has its pointer is an untouched part of the base
        // tree, whether or not it has been read: every mutation builds a new
        // node without one. It contributes no new blocks and must not be
        // fetched merely to rediscover that, which is also what lets this run
        // over a partial tree. This is the stored-pointer short-circuit of
        // the reference implementation.
        if let pointer {
            return pointer
        }
        let (resolvedEntries, _) = try await loadNode()
        var leaves: [RepositoryMSTLeaf] = []
        var leftTreeCID: CID?
        var index = 0
        if case var .tree(left)? = resolvedEntries.first {
            leftTreeCID = try await left.collectNewBlocks(into: &collector)
            index = 1
        }
        while index < resolvedEntries.count {
            guard case let .leaf(leaf) = resolvedEntries[index] else {
                throw RepositoryMSTMutationError.invalidNode
            }
            var rightTreeCID: CID?
            if index + 1 < resolvedEntries.count, case var .tree(right) = resolvedEntries[index + 1] {
                rightTreeCID = try await right.collectNewBlocks(into: &collector)
                index += 1
            }
            leaves.append(.init(path: leaf.path, recordCID: leaf.recordCID, rightTreeCID: rightTreeCID))
            index += 1
        }
        guard leaves.count <= limits.maximumMSTEntriesPerNode else {
            throw RepositoryMSTMutationError.entryLimitExceeded
        }
        let node: RepositoryMSTNode
        let bytes: Data
        do {
            node = try RepositoryMSTCodec.node(
                leaves: leaves,
                leftTreeCID: leftTreeCID,
                options: options
            )
            bytes = try RepositoryMSTCodec.encodeUnchecked(node)
        } catch {
            throw RepositoryMSTMutationError.invalidNode
        }
        let cid = CID.fromDAGCBOR(bytes)
        // A rebuilt node is new unless the base tree already contained it
        // (for example a delete followed by a re-create in one batch). That is
        // a comparison of trees. Whether the block store happens to hold the
        // bytes from older history is irrelevant and is not consulted.
        if !collector.collectsEverything, context.isBase(cid) {
            return cid
        }
        try collector.add(cid: cid, bytes: bytes)
        return cid
    }

    private mutating func appendLeaves(to result: inout [RepositoryMSTLeaf]) async throws {
        let (entries, _) = try await loadNode()
        for entry in entries {
            switch entry {
            case let .leaf(leaf):
                result.append(leaf)
            case let .tree(child):
                var childCopy = child
                try await childCopy.appendLeaves(to: &result)
            }
        }
    }

    private mutating func appendPageLeaves(
        lowerBound: Data,
        upperBound: Data,
        reverse: Bool,
        inheritedLowerBound: Data?,
        inheritedUpperBound: Data?,
        limit: Int,
        budget: RepositoryMSTPageTraversalBudget,
        to result: inout [RepositoryMSTLeaf]
    ) async throws {
        guard result.count < limit else { return }
        try Task.checkCancellation()
        if let pointer {
            try budget.visit(pointer)
        }
        let (entries, _) = try await loadNode()

        var lowerByIndex = Array<Data?>(repeating: nil, count: entries.count)
        var previous = inheritedLowerBound
        for index in entries.indices {
            lowerByIndex[index] = previous
            if case let .leaf(leaf) = entries[index] {
                previous = leaf.path.mstKeyBytes
            }
        }
        var upperByIndex = Array<Data?>(repeating: nil, count: entries.count)
        var next = inheritedUpperBound
        for index in entries.indices.reversed() {
            upperByIndex[index] = next
            if case let .leaf(leaf) = entries[index] {
                next = leaf.path.mstKeyBytes
            }
        }

        let orderedIndices = reverse
            ? Array(entries.indices)
            : Array(entries.indices.reversed())
        for index in orderedIndices {
            guard result.count < limit else { return }
            switch entries[index] {
            case let .leaf(leaf):
                let key = leaf.path.mstKeyBytes
                if RepositoryMSTCodec.lexicographicallyPrecedes(key, upperBound),
                   RepositoryMSTCodec.lexicographicallyPrecedes(lowerBound, key) {
                    result.append(leaf)
                }
            case let .tree(child):
                let subtreeLower = lowerByIndex[index]
                let subtreeUpper = upperByIndex[index]
                let isBeforeUpper = subtreeLower.map {
                    RepositoryMSTCodec.lexicographicallyPrecedes($0, upperBound)
                } ?? true
                let isAfterLower = subtreeUpper.map {
                    RepositoryMSTCodec.lexicographicallyPrecedes(lowerBound, $0)
                } ?? true
                guard isBeforeUpper, isAfterLower else { continue }
                var childCopy = child
                try await childCopy.appendPageLeaves(
                    lowerBound: lowerBound,
                    upperBound: upperBound,
                    reverse: reverse,
                    inheritedLowerBound: subtreeLower,
                    inheritedUpperBound: subtreeUpper,
                    limit: limit,
                    budget: budget,
                    to: &result
                )
            }
        }
    }

    private func newTree(_ entries: [Entry], layer: Int? = nil) throws -> Self {
        try Self(
            blocks: blocks,
            pointer: nil,
            entries: entries,
            layer: layer ?? knownLayer,
            limits: limits,
            options: options,
            context: context
        ).checked()
    }

    private func checked() throws -> Self {
        guard let entries = knownEntries else { return self }
        let leafCount = entries.reduce(into: 0) { count, entry in
            if case .leaf = entry { count += 1 }
        }
        guard leafCount <= limits.maximumMSTEntriesPerNode else {
            throw RepositoryMSTMutationError.entryLimitExceeded
        }
        var previousWasTree = false
        for entry in entries {
            let isTree: Bool
            if case .tree = entry { isTree = true } else { isTree = false }
            guard !(previousWasTree && isTree) else {
                throw RepositoryMSTMutationError.invalidNode
            }
            previousWasTree = isTree
        }
        return self
    }

    private func replacing(entryAt index: Int, with entry: Entry, in entries: [Entry]) throws -> Self {
        var updated = entries
        updated[index] = entry
        return try newTree(updated)
    }

    private func firstLeafIndex(notLessThan path: PublicRepositoryPath, in entries: [Entry]) -> Int {
        entries.firstIndex {
            if case let .leaf(leaf) = $0 {
                return !RepositoryMSTCodec.lexicographicallyPrecedes(leaf.path.mstKeyBytes, path.mstKeyBytes)
            }
            return false
        } ?? entries.count
    }

    private func entry(at index: Int, in entries: [Entry]) -> Entry? {
        entries.indices.contains(index) ? entries[index] : nil
    }

    private func validateRecordCID(_ cid: CID) throws {
        // Restoring a deleted leaf during operation inversion has to put back
        // exactly the link that was there, blessed or not.
        if options.allowsNonBlessedLeafLinks { return }
        do {
            try PublicRepositoryCID.validate(cid)
        } catch {
            throw RepositoryMSTMutationError.blockCIDMismatch
        }
    }
}

/// Reads from an in-memory overlay first, then from a base source.
struct RepositoryOverlayBlockSource: PublicRepositoryBlockSource {
    let overlay: [CID: Data]
    let base: any PublicRepositoryBlockSource

    func block(for cid: CID) async throws -> Data? {
        if let bytes = overlay[cid] { return bytes }
        return try await base.block(for: cid)
    }
}

/// Shared by every tree value derived from one `load`/`empty` call.
///
/// Tracks two things: which base-tree nodes have been read (to bound distinct
/// node reads) and which CIDs are known to belong to the base tree (to tell a
/// rebuilt-but-identical node from a new one). The state is behind a mutex,
/// so the `Sendable` conformance is checked by the compiler.
final class RepositoryMSTMutationContext: Sendable {
    private struct State {
        var loadedNodes = Set<CID>()
        var baseNodes = Set<CID>()
    }

    private let state = Mutex(State())

    init() {}

    func visit(_ cid: CID, limits: PublicRepositoryLimits) throws {
        try state.withLock { state in
            state.baseNodes.insert(cid)
            guard state.loadedNodes.insert(cid).inserted else { return }
            guard state.loadedNodes.count <= limits.maximumMSTNodes else {
                throw RepositoryMSTMutationError.nodeLimitExceeded
            }
        }
    }

    func noteBase(_ cid: CID) {
        state.withLock { _ = $0.baseNodes.insert(cid) }
    }

    func isBase(_ cid: CID) -> Bool {
        state.withLock { $0.baseNodes.contains(cid) }
    }
}

private final class RepositoryMSTPageTraversalBudget: @unchecked Sendable {
    private let maximumVisitedNodes: Int
    private var visited = Set<CID>()

    init(maximumVisitedNodes: Int) {
        self.maximumVisitedNodes = maximumVisitedNodes
    }

    var visitedNodeCount: Int { visited.count }

    func visit(_ cid: CID) throws {
        guard visited.insert(cid).inserted else {
            throw RepositoryMSTMutationError.invalidNode
        }
        guard visited.count <= maximumVisitedNodes else {
            throw RepositoryMSTMutationError.nodeLimitExceeded
        }
    }
}

private struct NewBlockCollector {
    let maximumNodes: Int
    let maximumBytes: Int
    /// When set, a rebuilt node is collected even if the base tree already
    /// contained an identical one, so the result holds every node this
    /// lineage encoded.
    var collectsEverything = false
    var blocks: [PublicRepositoryBlock] = []
    var cids = Set<CID>()
    var byteCount = 0

    mutating func add(cid: CID, bytes: Data) throws {
        guard cids.insert(cid).inserted else { return }
        guard blocks.count < maximumNodes else {
            throw RepositoryMSTMutationError.nodeLimitExceeded
        }
        let (next, overflow) = byteCount.addingReportingOverflow(bytes.count)
        guard !overflow, next <= maximumBytes else {
            throw RepositoryMSTMutationError.relevantBlockBudgetExceeded
        }
        blocks.append(.init(cid: cid, bytes: bytes))
        byteCount = next
    }
}
