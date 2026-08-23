import Foundation
import Petrel

/// Encodes complete firehose frames: canonical DAG-CBOR header object
/// concatenated with canonical DAG-CBOR body object. Petrel's DAG-CBOR
/// encoder performs canonical map-key ordering itself, so the source entry
/// order is not a wire contract.
public enum FirehoseFrameEncoder {
  public static func commitFrame(
    seq: Int64,
    material: PublicFirehoseCommitMaterial,
    diffCAR: Data
  ) throws -> Data {
    try FirehoseFrameLimits.validateSequence(seq)
    guard diffCAR.count <= FirehoseFrameLimits.maximumCommitBlocksBytes else {
      throw FirehoseFrameEncoderError.blocksTooLarge(
        actual: diffCAR.count,
        maximum: FirehoseFrameLimits.maximumCommitBlocksBytes
      )
    }
    let ops = try encodeOps(material.ops)

    var sinceValue: Any = NSNull()
    if let since = material.since {
      sinceValue = since
    }

    var entries: [(key: String, value: Any)] = [
      ("seq", seq),
      ("rebase", false),
      ("tooBig", false),
      ("repo", material.did),
      ("commit", try link(material.commitCID)),
      ("rev", material.rev),
      ("since", sinceValue),
      ("blocks", diffCAR),
      ("ops", ops),
      ("blobs", [Any]()),
      ("time", material.time),
    ]
    if let prevDataCID = material.prevDataCID {
      entries.append(("prevData", try link(prevDataCID)))
    }
    return try frame(
      header: OrderedCBORMap(entries: [
        (key: "op", value: 1),
        (key: "t", value: "#commit"),
      ]),
      body: OrderedCBORMap(entries: entries)
    )
  }

  public static func syncFrame(
    seq: Int64,
    material: PublicFirehoseSyncMaterial,
    commitCAR: Data
  ) throws -> Data {
    try FirehoseFrameLimits.validateSequence(seq)
    guard commitCAR.count <= FirehoseFrameLimits.maximumSyncBlocksBytes else {
      throw FirehoseFrameEncoderError.blocksTooLarge(
        actual: commitCAR.count,
        maximum: FirehoseFrameLimits.maximumSyncBlocksBytes
      )
    }
    return try frame(
      header: OrderedCBORMap(entries: [
        (key: "op", value: 1),
        (key: "t", value: "#sync"),
      ]),
      body: OrderedCBORMap(entries: [
        ("seq", seq),
        ("did", material.did),
        ("blocks", commitCAR),
        ("rev", material.rev),
        ("time", material.time),
      ])
    )
  }

  public static func identityFrame(
    seq: Int64,
    material: PublicFirehoseIdentityMaterial
  ) throws -> Data {
    try FirehoseFrameLimits.validateSequence(seq)
    var entries: [(key: String, value: Any)] = [
      ("seq", seq),
      ("did", material.did),
      ("time", material.time),
    ]
    if let handle = material.handle {
      entries.append(("handle", handle))
    }
    return try frame(
      header: OrderedCBORMap(entries: [
        (key: "op", value: 1),
        (key: "t", value: "#identity"),
      ]),
      body: OrderedCBORMap(entries: entries)
    )
  }

  public static func accountFrame(
    seq: Int64,
    material: PublicFirehoseAccountMaterial
  ) throws -> Data {
    try FirehoseFrameLimits.validateSequence(seq)
    guard material.active == (material.status == nil) else {
      throw FirehoseFrameEncoderError.invalidAccountStatus
    }
    var entries: [(key: String, value: Any)] = [
      ("seq", seq),
      ("did", material.did),
      ("time", material.time),
      ("active", material.active),
    ]
    if let status = material.status {
      entries.append(("status", status.rawValue))
    }
    return try frame(
      header: OrderedCBORMap(entries: [
        (key: "op", value: 1),
        (key: "t", value: "#account"),
      ]),
      body: OrderedCBORMap(entries: entries)
    )
  }

  public static func infoFrame(name: String, message: String?) throws -> Data {
    var entries: [(key: String, value: Any)] = [("name", name)]
    if let message {
      entries.append(("message", message))
    }
    return try frame(
      header: OrderedCBORMap(entries: [
        (key: "op", value: 1),
        (key: "t", value: "#info"),
      ]),
      body: OrderedCBORMap(entries: entries)
    )
  }

  public static func errorFrame(error: String, message: String?) throws -> Data {
    var entries: [(key: String, value: Any)] = [("error", error)]
    if let message {
      entries.append(("message", message))
    }
    return try frame(
      header: OrderedCBORMap(entries: [
        (key: "op", value: -1),
      ]),
      body: OrderedCBORMap(entries: entries)
    )
  }

  private static func encodeOps(_ ops: [PublicFirehoseRepoOp]) throws -> [Any] {
    guard ops.count <= FirehoseFrameLimits.maximumOps else {
      throw FirehoseFrameEncoderError.tooManyOperations(ops.count)
    }
    var result: [Any] = []
    for (index, op) in ops.enumerated() {
      switch op.action {
      case .create:
        guard op.cid != nil, op.prev == nil else {
          throw FirehoseFrameEncoderError.invalidOperation(
            index: index,
            reason: "create requires cid and no prev"
          )
        }
      case .update:
        guard op.cid != nil, op.prev != nil else {
          throw FirehoseFrameEncoderError.invalidOperation(
            index: index,
            reason: "update requires cid and prev"
          )
        }
      case .delete:
        guard op.cid == nil, op.prev != nil else {
          throw FirehoseFrameEncoderError.invalidOperation(
            index: index,
            reason: "delete requires no cid and a prev"
          )
        }
      }

      let cidValue: Any
      if let cid = op.cid {
        cidValue = try link(cid)
      } else {
        cidValue = NSNull()
      }

      var entries: [(key: String, value: Any)] = [
        ("cid", cidValue),
        ("path", op.path),
        ("action", op.action.rawValue),
      ]
      if let prev = op.prev {
        entries.append(("prev", try link(prev)))
      }
      result.append(OrderedCBORMap(entries: entries))
    }
    return result
  }

  private static func link(_ string: String) throws -> ATProtoLink {
    do {
      return ATProtoLink(cid: try CID.parse(string))
    } catch {
      throw FirehoseFrameEncoderError.invalidCID(string)
    }
  }

  private static func frame(header: OrderedCBORMap, body: OrderedCBORMap) throws -> Data {
    let headerBytes = try DAGCBOR.encodeValue(header)
    let bodyBytes = try DAGCBOR.encodeValue(body)
    let frame = headerBytes + bodyBytes
    guard frame.count <= FirehoseFrameLimits.maximumFrameBytes else {
      throw FirehoseFrameEncoderError.frameTooLarge(frame.count)
    }
    return frame
  }
}
