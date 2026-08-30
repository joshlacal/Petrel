// This file adapts the immutable/lazy MST mutation algorithm from
// bluesky-social/atproto@3f6c96d5d2d25438bd40fa89d6ecc37865f8e354
// packages/repo/src/mst/{mst,util}.ts, used under the repository's
// MIT OR Apache-2.0 notice policy recorded in THIRD_PARTY_NOTICES.md.

import Foundation
import Petrel

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

public struct MaterializedRepositoryMST: Sendable, Equatable {
    public let rootCID: CID
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
    private let context: RepositoryMSTMutationContext
    private init(
        blocks: any PublicRepositoryBlockSource,
        pointer: CID?,
        entries: [Entry]?,
        layer: Int?,
        limits: PublicRepositoryLimits,
        context: RepositoryMSTMutationContext = RepositoryMSTMutationContext()
    ) {
        self.blocks = blocks
        self.pointer = pointer
        knownEntries = entries
        knownLayer = layer
        self.limits = limits
        self.context = context
    }

    public static func load(
        rootCID: CID,
        blocks: any PublicRepositoryBlockSource,
        limits: PublicRepositoryLimits = .standard
    ) throws -> Self {
        do {
            try PublicRepositoryCID.validate(rootCID)
        } catch {
            throw RepositoryMSTMutationError.blockCIDMismatch
        }
        let context = RepositoryMSTMutationContext()
        return Self(
            blocks: blocks,
            pointer: rootCID,
            entries: nil,
            layer: nil,
            limits: limits,
            context: context
        )
    }

    public static func empty(limits: PublicRepositoryLimits = .standard) throws -> Self {
        let bytes = PublicRepositoryGenesisCodec.canonicalEmptyMST
        let cid = CID.fromDAGCBOR(bytes)
        let source = try PublicRepositoryBlockMap(
            blocks: [.init(cid: cid, bytes: bytes)],
            maximumRelevantBytes: limits.maximumRelevantBlockBytes
        )
        let context = RepositoryMSTMutationContext()
        return Self(
            blocks: source,
            pointer: cid,
            entries: [],
            layer: 0,
            limits: limits,
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

    public func materialized() async throws -> MaterializedRepositoryMST {
        var collector = NewBlockCollector(limits: limits)
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
        try context.visit(pointer, limits: limits)
        guard let bytes = try await blocks.block(for: pointer) else {
            throw RepositoryMSTMutationError.missingBlock
        }
        try context.recordBytes(bytes.count, limits: limits)
        do {
            try PublicRepositoryCID.validate(pointer, blockBytes: bytes)
        } catch {
            throw RepositoryMSTMutationError.blockCIDMismatch
        }
        let node: RepositoryMSTNode
        do {
            node = try RepositoryMSTCodec.decode(bytes)
        } catch {
            throw RepositoryMSTMutationError.invalidNode
        }
        let leaves: [RepositoryMSTLeaf]
        do {
            leaves = try RepositoryMSTCodec.reconstructedLeaves(from: node)
        } catch {
            throw RepositoryMSTMutationError.invalidNode
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
        // A CID-only node is an untouched subtree loaded from the immutable
        // base source. Its pointer is already the complete persisted
        // projection, so do not fetch/decode it merely to rediscover that it
        // contributes no new blocks. This is the same stored-pointer
        // short-circuit used by the pinned TypeScript implementation.
        if let pointer, knownEntries == nil {
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
            node = try RepositoryMSTCodec.node(leaves: leaves, leftTreeCID: leftTreeCID)
            bytes = try RepositoryMSTCodec.encodeUnchecked(node)
        } catch {
            throw RepositoryMSTMutationError.invalidNode
        }
        let cid = CID.fromDAGCBOR(bytes)
        if let existing = try await blocks.block(for: cid) {
            guard existing == bytes else {
                throw RepositoryMSTMutationError.blockCIDMismatch
            }
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
        do {
            try PublicRepositoryCID.validate(cid)
        } catch {
            throw RepositoryMSTMutationError.blockCIDMismatch
        }
    }
}

final class RepositoryMSTMutationContext: @unchecked Sendable {
    private var loadedNodes = Set<CID>()
    private var byteCount = 0
    init() {}

    func visit(_ cid: CID, limits: PublicRepositoryLimits) throws {
        guard loadedNodes.insert(cid).inserted else {
            return
        }
        guard loadedNodes.count <= limits.maximumMSTNodes else {
            throw RepositoryMSTMutationError.nodeLimitExceeded
        }
    }

    func recordBytes(_ count: Int, limits: PublicRepositoryLimits) throws {
        let (next, overflow) = byteCount.addingReportingOverflow(count)
        guard !overflow, next <= limits.maximumRelevantBlockBytes else {
            throw RepositoryMSTMutationError.relevantBlockBudgetExceeded
        }
        byteCount = next
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
    let limits: PublicRepositoryLimits
    var blocks: [PublicRepositoryBlock] = []
    var cids = Set<CID>()
    var byteCount = 0

    mutating func add(cid: CID, bytes: Data) throws {
        guard cids.insert(cid).inserted else { return }
        guard blocks.count < limits.maximumMSTNodes else {
            throw RepositoryMSTMutationError.nodeLimitExceeded
        }
        let (next, overflow) = byteCount.addingReportingOverflow(bytes.count)
        guard !overflow, next <= limits.maximumRelevantBlockBytes else {
            throw RepositoryMSTMutationError.relevantBlockBudgetExceeded
        }
        blocks.append(.init(cid: cid, bytes: bytes))
        byteCount = next
    }
}
