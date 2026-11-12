import Foundation
import Petrel

/// One record-level operation of a `#commit`, with the record decoded from the commit's
/// `blocks` when it is present there.
public struct RelayRecordOperation: Sendable {
  /// Whether the record was created, updated or deleted.
  public let action: RelayRepoAction
  /// The collection NSID part of the operation path.
  public let collection: String
  /// The record key part of the operation path.
  public let recordKey: String
  /// CID of the record after the operation; `nil` for deletes.
  public let cid: CID?
  /// The record, for creates and updates whose block is in the commit's diff CAR. `nil` for
  /// deletes and for records the producer left out of `blocks`.
  public let record: ATProtocolValueContainer?

  /// `at://<repo>/<collection>/<rkey>` for the repository that emitted the commit.
  public func uri(repo: String) -> String {
    "at://\(repo)/\(collection)/\(recordKey)"
  }
}

public extension RelayCommitEvent {
  /// Decodes the records this commit created or updated.
  ///
  /// `blocks` is a CAR "slice" holding the commit, the changed MST nodes and the new record
  /// blocks. Each record block is checked against the CID named by its operation before it is
  /// decoded. This does not verify the commit signature or the MST; it only pairs operations
  /// with their record bytes.
  ///
  /// - Throws: ``RelayVerifierError/invalidRepositoryCAR`` when `blocks` is not a readable CAR
  ///   or a record block does not match its CID, and the DAG-CBOR decoding error when a
  ///   record block is not a valid record.
  func records() throws -> [RelayRecordOperation] {
    let reader: CARReader?
    if blocks.isEmpty {
      reader = nil
    } else {
      do {
        reader = try CARReader(data: blocks)
      } catch {
        throw RelayVerifierError.invalidRepositoryCAR
      }
    }
    return try ops.map { op in
      let parts = op.path.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
      guard parts.count == 2 else { throw RelayVerifierError.invalidRepositoryOperation }
      var record: ATProtocolValueContainer?
      if let cid = op.cid, let reader, let bytes = try? reader.rawBlockData(for: cid) {
        guard CID.fromDAGCBOR(bytes) == cid else {
          throw RelayVerifierError.invalidRepositoryCAR
        }
        record = try ATProtocolValueContainer.decodedFromDAGCBOR(bytes)
      }
      return RelayRecordOperation(
        action: op.action,
        collection: String(parts[0]),
        recordKey: String(parts[1]),
        cid: op.cid,
        record: record
      )
    }
  }
}
