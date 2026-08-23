// The single-key search follows the same node layout and descent rule as
// bluesky-social/atproto@3f6c96d5d2d25438bd40fa89d6ecc37865f8e354
// packages/repo/src/mst/mst.ts (`MST.get`), used under the repository's
// MIT OR Apache-2.0 notice policy recorded in THIRD_PARTY_NOTICES.md.
// The bounded work budget and the absent/unprovable distinction are
// Swan-specific hardening.

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
/// repository Swan owns rather than about proving a claim over bytes an
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
    /// - Parameter key: the canonical MST key, `<collection>/<record-key>`.
    public static func membership(
        rootCID: CID,
        key: String,
        blocks: any PublicRepositoryBlockSource,
        limits: PublicRepositoryLimits = .standard
    ) async throws -> CID? {
        try await membership(
            rootCID: rootCID,
            path: try path(forMSTKey: key),
            blocks: blocks,
            limits: limits
        )
    }

    /// Path-typed sibling of ``membership(rootCID:key:blocks:limits:)`` for
    /// callers that already hold a validated repository path.
    public static func membership(
        rootCID: CID,
        path: PublicRepositoryPath,
        blocks: any PublicRepositoryBlockSource,
        limits: PublicRepositoryLimits = .standard
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

            let node = try RepositoryMSTCodec.decode(bytes)
            guard node.entries.count <= limits.maximumMSTEntriesPerNode else {
                throw RepositoryMSTValidationError.entryLimitExceeded
            }
            // Reconstruction re-derives every key from its prefix compression
            // and enforces strictly increasing order within the node, so the
            // scan below can rely on both.
            let leaves = try RepositoryMSTCodec.reconstructedLeaves(from: node)
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
    static func path(forMSTKey key: String) throws -> PublicRepositoryPath {
        guard let separator = key.firstIndex(of: "/") else {
            throw RepositoryMSTValidationError.invalidPath
        }
        let path: PublicRepositoryPath
        do {
            path = try PublicRepositoryPath(
                collection: String(key[key.startIndex ..< separator]),
                recordKey: String(key[key.index(after: separator)...])
            )
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
}
