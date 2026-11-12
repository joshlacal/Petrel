// The single-key search follows the same node layout and descent rule as
// bluesky-social/atproto@3f6c96d5d2d25438bd40fa89d6ecc37865f8e354
// packages/repo/src/mst/mst.ts (`MST.get`), used under the repository's
// MIT OR Apache-2.0 notice policy recorded in THIRD_PARTY_NOTICES.md.
// The bounded work budget and the absent/unprovable distinction are
// additions.

import Foundation
import Petrel

/// Membership proof over an MST whose sibling subtrees are legitimately absent.
///
/// This exists because neither full validator can be used for a proof CAR.
/// `RepositoryMSTValidation.validate` and `.validateProjection` are both
/// whole-tree walks — `validateProjection`'s own doc comment says it "performs
/// the same strict validation as `validate`" — and both route every node fetch
/// through a `requiredBlock` helper that throws `.missingBlock` when a block is
/// absent. A single-record proof CAR contains only the commit, the root→key MST
/// path, and the record; every sibling subtree is legitimately missing. Handed
/// such a CAR, both validators reject a perfectly good proof.
///
/// `RepositoryMST.get(_:)` is closer — it is already a lazy single-key descent
/// that throws on a missing block — but it carries no node budget at all
/// (`RepositoryMST` bounds entries per node and bounds *page* traversal, not a
/// point lookup), recurses instead of iterating, and reports through
/// `RepositoryMSTMutationError`, whose vocabulary is about mutating a
/// repository the caller owns rather than about proving a claim over bytes an
/// untrusted PDS chose. The walk below is the same descent under a bounded,
/// iterative loop in the validation error domain.
public enum RepositoryMSTProof {
    /// Walks ONLY the path from `rootCID` to `key`, tolerating absent sibling
    /// subtrees.
    ///
    /// Returns the record CID `key` maps to, or `nil` if `key` is **provably**
    /// absent — meaning the walk reached the exact gap where the key would sit
    /// and the subtree pointer for that gap is null in a node whose bytes hash
    /// to a CID reachable from the caller-supplied root. Every other outcome
    /// throws. In particular a missing block throws `.missingBlock` and never
    /// degrades to `nil`: callers consume `nil` as a proof failure, and an
    /// attacker who picks which blocks to omit must not be able to steer the
    /// difference between "the authority does not declare this" and "I withheld
    /// the evidence."
    ///
    /// What the walk establishes, and what it does not:
    ///
    /// - Every node on the path is re-hashed and checked against the CID that
    ///   referenced it, so the path is bound to `rootCID` — which the caller is
    ///   expected to have taken from a signature-verified `commit.data`, not
    ///   from the response. A record block sitting unlinked in the CAR
    ///   satisfies nothing here; only reachability from `rootCID` does. That is
    ///   the whole point of the membership step.
    /// - The record block itself is NOT fetched or decoded. Returning a CID is
    ///   the membership claim; checking that the bytes behind it are a
    ///   `com.atproto.lexicon.schema` record is a separate, later step, and
    ///   keeping them separate is what lets a caller distinguish "not in the
    ///   tree" from "in the tree, wrong `$type`".
    /// - Whole-tree well-formedness (per-layer leaf depth, the layer-decrement
    ///   invariant the full validators enforce) is deliberately NOT checked. A
    ///   proof CAR carries too little of the tree to establish it, and a
    ///   partial version of that check would reject legitimate proofs without
    ///   buying a security property: a malformed tree can only hide a key from
    ///   the search, and a hidden key resolves to `nil`, which is a refusal.
    ///
    /// Bounded by the SAME `PublicRepositoryLimits` the full validators use —
    /// `maximumMSTNodes` and `maximumMSTEntriesPerNode`. There is deliberately
    /// no second MST budget: two budgets that can drift apart is a worse
    /// outcome than either number.
    ///
    /// - Parameters:
    ///   - rootCID: The MST root, taken from a verified commit's `data`.
    ///   - key: The canonical MST key, `<collection>/<record-key>`.
    ///   - blocks: The blocks of the proof (or of the whole repository).
    ///   - limits: Bounds on nodes visited and entries per node.
    ///   - options: Key syntax and leaf-link policy.
    public static func membership(
        rootCID: CID,
        key: String,
        blocks: any PublicRepositoryBlockSource,
        limits: PublicRepositoryLimits = .standard,
        options: RepositoryMSTOptions = .strict
    ) async throws -> CID? {
        try await membership(
            rootCID: rootCID,
            path: try path(forMSTKey: key, syntax: options.keySyntax),
            blocks: blocks,
            limits: limits,
            options: options
        )
    }

    /// Path-typed sibling of ``membership(rootCID:key:blocks:limits:options:)`` for
    /// callers that already hold a validated repository path.
    public static func membership(
        rootCID: CID,
        path: PublicRepositoryPath,
        blocks: any PublicRepositoryBlockSource,
        limits: PublicRepositoryLimits = .standard,
        options: RepositoryMSTOptions = .strict
    ) async throws -> CID? {
        do {
            try PublicRepositoryCID.validate(rootCID)
        } catch {
            throw RepositoryMSTValidationError.unsupportedCID
        }

        let targetKey = Data(path.mstKey.utf8)
        var nodeCID = rootCID
        var lowerBound: Data?
        var upperBound: Data?
        var visited = Set<CID>()

        while true {
            try Task.checkCancellation()
            guard visited.insert(nodeCID).inserted else {
                throw RepositoryMSTValidationError.repeatedNode
            }
            guard visited.count <= limits.maximumMSTNodes else {
                throw RepositoryMSTValidationError.nodeLimitExceeded
            }

            // A block the source cannot produce is the one outcome that must
            // never look like an answer. See the `nil` contract above.
            guard let bytes = try await blocks.block(for: nodeCID) else {
                throw RepositoryMSTValidationError.missingBlock
            }
            do {
                try PublicRepositoryCID.validate(nodeCID, blockBytes: bytes)
            } catch PublicRepositoryDomainError.unsupportedCID {
                throw RepositoryMSTValidationError.unsupportedCID
            } catch {
                throw RepositoryMSTValidationError.blockCIDMismatch
            }

            let node = try RepositoryMSTCodec.decode(bytes, options: options)
            guard node.entries.count <= limits.maximumMSTEntriesPerNode else {
                throw RepositoryMSTValidationError.entryLimitExceeded
            }
            // Reconstruction re-derives every key from its prefix compression
            // and enforces strictly increasing order within the node, so the
            // scan below can rely on both.
            let leaves = try RepositoryMSTCodec.reconstructedLeaves(from: node, options: options)
            let leafKeys = leaves.map { Data($0.path.mstKey.utf8) }
            for leafKey in leafKeys {
                guard isInside(leafKey, lower: lowerBound, upper: upperBound) else {
                    throw RepositoryMSTValidationError.subtreeOutOfRange
                }
            }

            var index = 0
            while index < leafKeys.count,
                  leafKeys[index].lexicographicallyPrecedes(targetKey) {
                index += 1
            }
            if index < leafKeys.count, leafKeys[index] == targetKey {
                return leaves[index].recordCID
            }

            // The key is not in this node, so it can only live in the subtree
            // covering the gap it would occupy.
            let subtreeCID: CID?
            let nextLowerBound: Data?
            let nextUpperBound: Data?
            if index == 0 {
                subtreeCID = node.leftTreeCID
                nextLowerBound = lowerBound
                nextUpperBound = leafKeys.first ?? upperBound
            } else {
                subtreeCID = leaves[index - 1].rightTreeCID
                nextLowerBound = leafKeys[index - 1]
                nextUpperBound = index < leafKeys.count ? leafKeys[index] : upperBound
            }

            // Provably absent: the gap the key would occupy has no subtree, in
            // a node whose bytes are bound to the root by hash.
            guard let subtreeCID else { return nil }
            nodeCID = subtreeCID
            lowerBound = nextLowerBound
            upperBound = nextUpperBound
        }
    }

    /// Parses a canonical `<collection>/<record-key>` MST key.
    ///
    /// The round-trip check refuses any key whose canonical form differs from
    /// the input, so a caller cannot search for a key that no well-formed node
    /// could ever contain and read the resulting `nil` as absence.
    static func path(
        forMSTKey key: String,
        syntax: RepositoryMSTKeySyntax = .repositoryPath
    ) throws -> PublicRepositoryPath {
        let path: PublicRepositoryPath
        do {
            path = try PublicRepositoryPath(mstKey: key, syntax: syntax)
        } catch {
            throw RepositoryMSTValidationError.invalidPath
        }
        guard path.mstKey == key else {
            throw RepositoryMSTValidationError.invalidPath
        }
        return path
    }

    private static func isInside(_ key: Data, lower: Data?, upper: Data?) -> Bool {
        if let lower, !lower.lexicographicallyPrecedes(key) { return false }
        if let upper, !key.lexicographicallyPrecedes(upper) { return false }
        return true
    }

    // MARK: Producing proofs

    /// The MST node blocks on the search path from `rootCID` to `path`: the
    /// blocks a `com.atproto.sync.getRecord` response must carry, besides the
    /// commit and the record itself.
    ///
    /// The path is the same whether or not the key is present, so the result
    /// is an inclusion proof for a key that exists and an exclusion proof for
    /// one that does not. Matches the reference implementation's
    /// `MST.cidsForPath`.
    ///
    /// - Returns: The node blocks from the root downwards, and the record CID
    ///   the key maps to (`nil` if absent).
    public static func pathBlocks(
        rootCID: CID,
        path: PublicRepositoryPath,
        blocks: any PublicRepositoryBlockSource,
        limits: PublicRepositoryLimits = .standard,
        options: RepositoryMSTOptions = .strict
    ) async throws -> (nodes: [PublicRepositoryBlock], recordCID: CID?) {
        let target = path.mstKeyBytes
        var nodes: [PublicRepositoryBlock] = []
        var next: CID? = rootCID
        while let cid = next {
            let node = try await ProofNode.load(cid, blocks: blocks, limits: limits, options: options)
            try guardDepth(nodes.count)
            nodes.append(node.block)
            let index = node.firstLeafIndex(notLessThan: target)
            if case let .leaf(key, recordCID)? = node.item(at: index), key == target {
                return (nodes, recordCID)
            }
            if case let .tree(child)? = node.item(at: index - 1) {
                next = child
            } else {
                next = nil
            }
        }
        return (nodes, nil)
    }

    /// The node blocks needed to verify, and to invert, one operation on
    /// `path` against the tree rooted at `rootCID`: the search path for the
    /// key, plus the paths to the keys immediately to its left and right.
    ///
    /// A consumer that holds only these blocks can delete the key (or put it
    /// back) and recompute the root, because a delete may merge the two
    /// neighbouring subtrees and an insert may split them. Matches the
    /// reference implementation's `MST.getCoveringProof`.
    ///
    /// Call it on the tree as it is *after* the commit.
    public static func coveringProof(
        rootCID: CID,
        path: PublicRepositoryPath,
        blocks: any PublicRepositoryBlockSource,
        limits: PublicRepositoryLimits = .standard,
        options: RepositoryMSTOptions = .strict
    ) async throws -> [PublicRepositoryBlock] {
        let target = path.mstKeyBytes
        var seen = Set<CID>()
        var result: [PublicRepositoryBlock] = []
        func add(_ block: PublicRepositoryBlock) {
            if seen.insert(block.cid).inserted { result.append(block) }
        }
        func load(_ cid: CID, depth: Int) async throws -> ProofNode {
            try guardDepth(depth)
            return try await ProofNode.load(cid, blocks: blocks, limits: limits, options: options)
        }

        // The key itself. A search that ends in a node with no subtree for
        // the key's gap does not contribute that last node here; the two
        // sibling walks below always include it.
        var visited: [PublicRepositoryBlock] = []
        var next: CID? = rootCID
        while let cid = next {
            let node = try await load(cid, depth: visited.count)
            let index = node.firstLeafIndex(notLessThan: target)
            if case let .leaf(key, _)? = node.item(at: index), key == target {
                visited.append(node.block)
                next = nil
            } else if case let .tree(child)? = node.item(at: index - 1) {
                visited.append(node.block)
                next = child
            } else {
                next = nil
            }
        }
        visited.forEach(add)

        // The left neighbour: at every level, the subtree just before the
        // position the key occupies or would occupy.
        var depth = 0
        next = rootCID
        while let cid = next {
            let node = try await load(cid, depth: depth)
            depth += 1
            add(node.block)
            let index = node.firstLeafIndex(notLessThan: target)
            if case let .tree(child)? = node.item(at: index - 1) {
                next = child
            } else {
                next = nil
            }
        }

        // The right neighbour.
        depth = 0
        next = rootCID
        while let cid = next {
            let node = try await load(cid, depth: depth)
            depth += 1
            add(node.block)
            let index = node.firstLeafIndex(notLessThan: target)
            next = nil
            switch node.item(at: index) ?? node.item(at: index - 1) {
            case nil:
                break
            case let .tree(child)?:
                next = child
            case let .leaf(key, _)?:
                let neighbour = key == target ? node.item(at: index + 1) : node.item(at: index - 1)
                if case let .tree(child)? = neighbour {
                    next = child
                }
            }
        }
        return result
    }

    private static func guardDepth(_ depth: Int) throws {
        // A well-formed tree has at most 129 layers; a longer descent is a
        // cycle or a chain of empty nodes.
        guard depth <= 129 else {
            throw RepositoryMSTValidationError.invalidLayer
        }
    }
}

/// One decoded MST node as an interleaved list of subtrees and leaves, the
/// shape the reference implementation's proof walks are written against.
private struct ProofNode {
    enum Item {
        case tree(CID)
        case leaf(key: Data, recordCID: CID)
    }

    let block: PublicRepositoryBlock
    let items: [Item]

    static func load(
        _ cid: CID,
        blocks: any PublicRepositoryBlockSource,
        limits: PublicRepositoryLimits,
        options: RepositoryMSTOptions
    ) async throws -> ProofNode {
        guard cid.blessedKind == .dagCBOR else {
            throw RepositoryMSTValidationError.unsupportedCID
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
        var items: [Item] = []
        if let left = node.leftTreeCID { items.append(.tree(left)) }
        for leaf in try RepositoryMSTCodec.reconstructedLeaves(from: node, options: options) {
            items.append(.leaf(key: leaf.path.mstKeyBytes, recordCID: leaf.recordCID))
            if let right = leaf.rightTreeCID { items.append(.tree(right)) }
        }
        return ProofNode(block: .init(cid: cid, bytes: bytes), items: items)
    }

    /// Index of the first leaf whose key is `>= key`, or `items.count`.
    func firstLeafIndex(notLessThan key: Data) -> Int {
        items.firstIndex {
            if case let .leaf(leafKey, _) = $0 {
                return !RepositoryMSTCodec.lexicographicallyPrecedes(leafKey, key)
            }
            return false
        } ?? items.count
    }

    func item(at index: Int) -> Item? {
        items.indices.contains(index) ? items[index] : nil
    }
}
