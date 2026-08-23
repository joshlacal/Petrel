import Foundation

/// Hard event invariants for complete firehose frames. These match the AT
/// Protocol sync subscription limits with Swan's stricter operation semantics
/// layered on top.
public enum FirehoseFrameLimits {
  public static let maximumFrameBytes = 5_000_000
  public static let maximumCommitBlocksBytes = 2_000_000
  public static let maximumSyncBlocksBytes = 10_000
  public static let maximumOps = 200
  public static let maximumSequence: Int64 = 9_007_199_254_740_991

  /// `1 <= seq <= maximumSequence`. The exhausted sentinel
  /// (`maximumSequence + 1`) is only valid in `firehose_meta.next_seq`, never
  /// on an event.
  public static func validateSequence(_ seq: Int64) throws {
    guard seq >= 1, seq <= maximumSequence else {
      throw FirehoseFrameEncoderError.sequenceOutOfRange
    }
  }
}

public enum FirehoseFrameEncoderError: Error, Equatable, Sendable {
  case sequenceOutOfRange
  case tooManyOperations(Int)
  case blocksTooLarge(actual: Int, maximum: Int)
  case frameTooLarge(Int)
  case invalidCID(String)
  case invalidOperation(index: Int, reason: String)
  case invalidAccountStatus
}
