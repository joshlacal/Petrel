import Foundation
import Petrel
import PetrelRepo
import Testing

/// The depth-bounded walker is what `Repository` verifies trees with, so it
/// has to refuse every malformed topology the in-memory validator refuses.
/// Trees here are assembled node by node from keys whose depth is known:
/// the official `example_keys.txt` keys carry their depth as their second
/// character (`C2/014073` is at depth 2).
@Suite("MST walker: verification with depth-bounded memory")
struct RepositoryMSTWalkerTests {
    private let options = RepositoryMSTOptions(keySyntax: .mstKey)
    private let leaf = CID.fromDAGCBOR(Data("leaf".utf8))

    /// The example keys, grouped by depth and sorted.
    private func keys(depth: Int) throws -> [String] {
        let text = String(decoding: try Vectors.data("mst/example_keys.txt"), as: UTF8.self)
        return text.split(separator: "\n").map(String.init)
            .filter { $0.dropFirst().first == Character(String(depth)) }
            .sorted()
    }

    private func path(_ key: String) throws -> PublicRepositoryPath {
        try PublicRepositoryPath(mstKey: key, syntax: .mstKey)
    }

    /// Encodes one node and stores it. `entries` are (key, right subtree).
    private func node(
        _ store: InMemoryRepositoryBlockStore,
        left: CID? = nil,
        _ entries: [(String, CID?)]
    ) async throws -> CID {
        let leaves = try entries.map {
            RepositoryMSTLeaf(path: try path($0.0), recordCID: leaf, rightTreeCID: $0.1)
        }
        let bytes = try RepositoryMSTCodec.encode(
            RepositoryMSTCodec.node(leaves: leaves, leftTreeCID: left, options: options), options: options
        )
        let cid = CID.fromDAGCBOR(bytes)
        try await store.put(.init(cid: cid, bytes: bytes))
        return cid
    }

    private func walk(
        _ root: CID,
        _ store: any PublicRepositoryBlockSource,
        limits: PublicRepositoryLimits = .networkScale,
        range: RepositoryMSTWalker.KeyRange = .all
    ) async throws -> (summary: RepositoryMSTWalkSummary, keys: [String]) {
        var keys: [String] = []
        let summary = try await RepositoryMSTWalker.walk(
            rootCID: root, blocks: store, limits: limits, options: options, range: range
        ) { leaf in
            keys.append(leaf.path.mstKey)
            return true
        }
        return (summary, keys)
    }

    private func expectRefused(
        _ expected: RepositoryMSTValidationError,
        _ root: CID,
        _ store: any PublicRepositoryBlockSource,
        limits: PublicRepositoryLimits = .networkScale,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        await #expect(throws: expected, sourceLocation: sourceLocation) {
            try await self.walk(root, store, limits: limits)
        }
    }

    @Test("a well-formed three-layer tree is walked in key order")
    func wellFormed() async throws {
        let d0 = try keys(depth: 0), d1 = try keys(depth: 1), d2 = try keys(depth: 2)
        // Pick one depth-2 key M and depth-1/0 keys on either side of it.
        let top = d2[d2.count / 2]
        let midLeft = d1[0]
        let lowLeft = d0.filter { $0 > midLeft && $0 < top }.prefix(3)
        let lowRight = d0.filter { $0 > top }.prefix(3)

        let store = InMemoryRepositoryBlockStore()
        let bottomLeft = try await node(store, lowLeft.map { ($0, nil) })
        let bottomRight = try await node(store, lowRight.map { ($0, nil) })
        let middleLeft = try await node(store, [(midLeft, bottomLeft)])
        // The right side skips a layer: an empty layer-1 node above layer 0.
        let middleRight = try await node(store, left: bottomRight, [])
        let root = try await node(store, left: middleLeft, [(top, middleRight)])

        let result = try await walk(root, store)
        let expected = [midLeft] + lowLeft + [top] + lowRight
        #expect(result.keys == expected)
        #expect(result.keys == result.keys.sorted())
        #expect(result.summary.rootLayer == 2)
        #expect(result.summary.nodeCount == 5)
        #expect(result.summary.recordCount == 8)

        // The bottom-up oracle builds the same root from the same keys.
        let oracle = try await BulkMST.build(
            try expected.sorted().map { BulkMST.Entry(path: try path($0), recordCID: leaf) },
            options: options
        ) { _ in }
        #expect(oracle == root)

        // Early exit stops reading.
        var seen = 0
        let partial = try await RepositoryMSTWalker.walk(
            rootCID: root, blocks: store, options: options
        ) { _ in
            seen += 1
            return seen < 2
        }
        #expect(seen == 2)
        #expect(partial.nodeCount < 5)
    }

    @Test("keys at the wrong depth for their node are refused")
    func wrongLayer() async throws {
        let d0 = try keys(depth: 0), d1 = try keys(depth: 1)
        let store = InMemoryRepositoryBlockStore()
        // A depth-1 key sitting among depth-0 keys in one node.
        let mixed = ([d0[0], d0[1], d1[0]]).sorted()
        await expectRefused(.leafLayerMismatch, try await node(store, mixed.map { ($0, nil) }), store)

        // A child that is two layers below its parent instead of one.
        let d2 = try keys(depth: 2)
        let top = try #require(d2.last)
        let below = d0.filter { $0 < top }.prefix(2)
        let child = try await node(store, below.map { ($0, nil) })
        await expectRefused(.invalidLayer, try await node(store, left: child, [(top, nil)]), store)

        // A layer-0 node that claims a subtree.
        let stray = try await node(store, [(d0[5], nil)])
        let lowWithChild = try await node(store, [(d0[0], nil), (d0[9], stray)])
        await expectRefused(.invalidLayer, lowWithChild, store)
    }

    @Test("a subtree holding keys outside its slot is refused")
    func subtreeOutOfRange() async throws {
        let d0 = try keys(depth: 0), d1 = try keys(depth: 1)
        let store = InMemoryRepositoryBlockStore()
        let pivot = d1[d1.count / 2]
        let after = try #require(d0.first { $0 > pivot })
        let before = try #require(d0.last { $0 < pivot })
        // A key greater than the pivot in the pivot's left subtree...
        let wrongLeft = try await node(store, [(after, nil)])
        await expectRefused(.subtreeOutOfRange, try await node(store, left: wrongLeft, [(pivot, nil)]), store)
        // ...and one smaller than it in its right subtree.
        let wrongRight = try await node(store, [(before, nil)])
        await expectRefused(.subtreeOutOfRange, try await node(store, [(pivot, wrongRight)]), store)

        // The same subtree linked from two slots cannot satisfy both ranges.
        let shared = try await node(store, [(before, nil)])
        await #expect(throws: RepositoryMSTValidationError.self) {
            try await self.walk(try await self.node(store, left: shared, [(pivot, shared)]), store)
        }
    }

    @Test("empty nodes are allowed only where the specification allows them")
    func emptyTopology() async throws {
        let d0 = try keys(depth: 0), d1 = try keys(depth: 1)
        let store = InMemoryRepositoryBlockStore()
        // The lone empty root is the empty repository.
        let empty = try await node(store, [])
        #expect(empty.string == PublicRepositoryGenesisCodec.canonicalEmptyMSTCID)
        let result = try await walk(empty, store)
        #expect(result.keys.isEmpty)
        #expect(result.summary.rootCID == empty)
        #expect(result.summary.rootLayer == 0)
        #expect(result.summary.nodeCount == 1)
        #expect(result.summary.recordCount == 0)

        // A root with no entries that points at a subtree is not canonical.
        let child = try await node(store, [(d0[0], nil)])
        await expectRefused(.invalidEmptyTopology, try await node(store, left: child, []), store)
        // An empty node with no subtree, hanging off a real one.
        await expectRefused(.invalidEmptyTopology, try await node(store, left: empty, [(d1[3], nil)]), store)
        // An empty intermediate node at layer 0 (below a layer-1 parent it
        // would have to be at layer 0, where nothing can hang below it).
        let hollow = try await node(store, left: child, [])
        await expectRefused(.invalidEmptyTopology, try await node(store, left: hollow, [(d1[3], nil)]), store)
    }

    @Test("missing, substituted and malformed node blocks are refused")
    func brokenBlocks() async throws {
        let d0 = try keys(depth: 0), d1 = try keys(depth: 1)
        let store = InMemoryRepositoryBlockStore()
        let pivot = try #require(d1.last)
        let child = try await node(store, d0.filter { $0 < pivot }.prefix(4).map { ($0, nil) })
        let root = try await node(store, left: child, [(pivot, nil)])
        #expect(try await walk(root, store).keys.count == 5)

        struct Tampering: PublicRepositoryBlockSource {
            let base: InMemoryRepositoryBlockStore
            let target: CID
            let replacement: Data?
            func block(for cid: CID) async throws -> Data? {
                if cid == target { return replacement }
                return try await base.block(for: cid)
            }
        }
        await #expect(throws: RepositoryMSTValidationError.missingBlock) {
            try await self.walk(root, Tampering(base: store, target: child, replacement: nil))
        }
        let otherBytes = try #require(try await store.block(for: root))
        await #expect(throws: RepositoryMSTValidationError.blockCIDMismatch) {
            try await self.walk(root, Tampering(base: store, target: child, replacement: otherBytes))
        }
        // Not a node at all (a record-shaped map), stored under its own CID.
        let notANode = Data([0xa1, 0x61, 0x78, 0x01])
        try await store.put(.init(cid: CID.fromDAGCBOR(notANode), bytes: notANode))
        await #expect(throws: RepositoryMSTValidationError.self) {
            try await self.walk(CID.fromDAGCBOR(notANode), store)
        }
        // A root CID that is not a blessed DAG-CBOR CID is never fetched.
        await #expect(throws: RepositoryMSTValidationError.unsupportedCID) {
            try await self.walk(CID.fromBlob(Data("x".utf8)), store)
        }
    }

    @Test("node, entry and record limits are enforced during the walk")
    func limits() async throws {
        let d0 = try keys(depth: 0), d1 = try keys(depth: 1)
        let store = InMemoryRepositoryBlockStore()
        let pivot = try #require(d1.last)
        let child = try await node(store, d0.filter { $0 < pivot }.prefix(6).map { ($0, nil) })
        let root = try await node(store, left: child, [(pivot, nil)])

        func limits(nodes: Int = 10, entries: Int = 10, records: Int = 10) throws -> PublicRepositoryLimits {
            try PublicRepositoryLimits(
                maximumRecordBlockBytes: 1_000_000,
                maximumCARBytes: PublicRepositoryLimits.requiredStreamingCARBytes,
                maximumCARBlocks: 100,
                maximumMSTNodes: nodes,
                maximumMSTEntriesPerNode: entries,
                maximumCBORNestingDepth: 16,
                maximumRepositoryRecords: records
            )
        }
        #expect(try await walk(root, store, limits: limits()).keys.count == 7)
        #expect(try await walk(root, store, limits: limits(nodes: 2, entries: 6, records: 7)).keys.count == 7)
        await #expect(throws: RepositoryMSTValidationError.nodeLimitExceeded) {
            try await self.walk(root, store, limits: limits(nodes: 1))
        }
        await #expect(throws: RepositoryMSTValidationError.entryLimitExceeded) {
            try await self.walk(root, store, limits: limits(entries: 5))
        }
        await #expect(throws: RepositoryMSTValidationError.recordLimitExceeded) {
            try await self.walk(root, store, limits: limits(records: 6))
        }
    }

    @Test("a ranged walk yields exactly the keys in range and skips subtrees outside it")
    func rangedWalk() async throws {
        // Many keys across three "collections" (the letter prefixes).
        var all: [String] = []
        for depth in 0 ... 3 { all += try keys(depth: depth) }
        all.sort()
        let store = InMemoryRepositoryBlockStore()
        let root = try await BulkMST.build(
            try all.map { BulkMST.Entry(path: try path($0), recordCID: leaf) }, options: options
        ) { try await store.put($0) }

        let full = try await walk(root, store)
        #expect(full.keys == all)

        for prefix in ["A0", "M2", "Z1", "C3", "Q9"] {
            let ranged = try await walk(root, store, range: .collection(prefix))
            #expect(ranged.keys == all.filter { $0.hasPrefix(prefix + "/") }, "\(prefix)")
            #expect(ranged.summary.nodeCount <= full.summary.nodeCount)
        }
        // A narrow range reads only a few nodes of a large tree.
        let narrow = try await walk(root, store, range: .collection("M2"))
        #expect(narrow.summary.nodeCount < full.summary.nodeCount)

        let lower = Data("F".utf8), upper = Data("H".utf8)
        let between = try await walk(root, store, range: .init(lower: lower, upper: upper))
        #expect(between.keys == all.filter { $0 >= "F" && $0 < "H" })
    }
}
