import Foundation
import Petrel

/// A whole-repository bound that a commit is checked against.
public enum RepositoryLimitKind: Sendable, Equatable {
    /// ``PublicRepositoryLimits/maximumRepositoryRecords``.
    case records
    /// ``PublicRepositoryLimits/maximumMSTNodes``.
    case mstNodes
    /// ``PublicRepositoryLimits/maximumCARBlocks``, counted on the
    /// repository's streamable export.
    case carBlocks
    /// ``PublicRepositoryLimits/maximumCARBytes``, counted on the
    /// repository's streamable export.
    case carBytes
    /// ``PublicRepositoryLimits/maximumRecordBlockBytes``, applied to every
    /// block a commit writes: records, MST nodes and the commit itself.
    case blockBytes
}

/// The exact size of a repository as the read paths measure it: what
/// `verify()` counts and what a streamable `exportCAR()` writes.
///
/// Tracked across commits so each commit is checked against the limits in
/// time proportional to what it changes, not to the repository's size.
struct RepositoryFootprint: Sendable, Equatable {
    /// Leaves in the tree.
    var records: Int
    /// MST nodes in the tree.
    var mstNodes: Int
    /// Leaves whose link is a blessed DAG-CBOR CID. A streamable export
    /// writes one record block for each, and skips the others.
    var exportedRecords: Int
    /// CAR-framed bytes of every MST node and exported record block. The
    /// header and the commit block are added by ``exportedByteCount(commit:)``.
    var framedBlockBytes: Int

    /// The empty tree of a new repository: one node, no records.
    static func empty(rootCID: CID, rootByteCount: Int) -> Self {
        Self(records: 0, mstNodes: 1, exportedRecords: 0,
             framedBlockBytes: framedSize(cid: rootCID, byteCount: rootByteCount))
    }

    /// Bytes one block occupies in a CAR archive: length varint, CID, body.
    static func framedSize(cid: CID, byteCount: Int) -> Int {
        let frame = cid.bytes.count + byteCount
        return PublicRepositoryCAR.canonicalUnsignedVarint(UInt64(frame)).count + frame
    }

    /// Bytes of the CAR header naming `rootCID`, length prefix included.
    static func headerSize(rootCID: CID) throws -> Int {
        let header = try DAGCBOR.encodeValue(OrderedCBORMap(entries: [
            (key: "roots", value: [ATProtoLink(cid: rootCID)]),
            (key: "version", value: 1),
        ]))
        return PublicRepositoryCAR.canonicalUnsignedVarint(UInt64(header.count)).count + header.count
    }

    /// Size of the streamable export of this tree under `commit`.
    func exportedByteCount(commit: RepositoryCommit) throws -> Int {
        try exportedByteCount(commitCID: commit.cid, commitByteCount: commit.bytes.count)
    }

    func exportedByteCount(commitCID: CID, commitByteCount: Int) throws -> Int {
        try Self.headerSize(rootCID: commitCID)
            + Self.framedSize(cid: commitCID, byteCount: commitByteCount)
            + framedBlockBytes
    }

    /// Throws ``RepositoryError/limitExceeded(_:limit:)`` for the first
    /// whole-repository limit this footprint breaks.
    ///
    /// - Parameters:
    ///   - commitCID: A CID of the same shape as the commit that will head
    ///     the tree. Every repository commit CID has the same length.
    ///   - commitByteCount: Exact size of that commit block.
    func check(
        _ limits: PublicRepositoryLimits, commitCID: CID, commitByteCount: Int
    ) throws {
        guard records <= limits.maximumRepositoryRecords else {
            throw RepositoryError.limitExceeded(.records, limit: limits.maximumRepositoryRecords)
        }
        guard mstNodes <= limits.maximumMSTNodes else {
            throw RepositoryError.limitExceeded(.mstNodes, limit: limits.maximumMSTNodes)
        }
        guard 1 + mstNodes + exportedRecords <= limits.maximumCARBlocks else {
            throw RepositoryError.limitExceeded(.carBlocks, limit: limits.maximumCARBlocks)
        }
        guard try exportedByteCount(commitCID: commitCID, commitByteCount: commitByteCount)
            <= limits.maximumCARBytes else {
            throw RepositoryError.limitExceeded(.carBytes, limit: limits.maximumCARBytes)
        }
    }
}
