import Foundation
import Petrel
import PetrelRepo

public enum PublicFirehoseDiffCARError: Error, Sendable, Equatable {
  case missingBlock(CID)
}

/// Deterministic CAR construction for firehose `blocks` payloads.
///
/// `build` emits the commit block first, then every remaining new block in
/// ascending CID-string order, rooted at the commit CID. The reference
/// event-stream contract for `#commit.blocks` is a diff CAR; `commitOnly`
/// emits exactly the commit block for `#sync`.
public enum PublicFirehoseDiffCAR {
  public static func build(
    commitCID: CID,
    commitBytes: Data,
    newBlocks: PublicRepositoryBlockMap
  ) async throws -> Data {
    let remaining = newBlocks.cids
      .filter { $0 != commitCID }
      .sorted { $0.string < $1.string }
    let collector = PublicFirehoseCARCollector()
    let stream = PublicFirehoseDiffCARBlockStream(
      commit: PublicRepositoryBlock(cid: commitCID, bytes: commitBytes),
      orderedCIDs: remaining,
      source: newBlocks
    )
    _ = try await PublicRepositoryCAR.write(
      rootCID: commitCID,
      blocks: stream,
      to: collector
    )
    return await collector.collected()
  }

  public static func commitOnly(
    commitCID: CID,
    commitBytes: Data
  ) async throws -> Data {
    let collector = PublicFirehoseCARCollector()
    let stream = PublicFirehoseDiffCARBlockStream(
      commit: PublicRepositoryBlock(cid: commitCID, bytes: commitBytes),
      orderedCIDs: [],
      source: try PublicRepositoryBlockMap()
    )
    _ = try await PublicRepositoryCAR.write(
      rootCID: commitCID,
      blocks: stream,
      to: collector
    )
    return await collector.collected()
  }
}

/// Internal so the diff-CAR tests can prove the typed missing-block error.
/// Production code only reaches it through `PublicFirehoseDiffCAR`.
actor PublicFirehoseDiffCARBlockStream: PublicRepositoryCARBlockStream {
  private let commit: PublicRepositoryBlock
  private let orderedCIDs: [CID]
  private let source: any PublicRepositoryBlockSource
  private var index = 0
  private var emittedCommit = false

  init(
    commit: PublicRepositoryBlock,
    orderedCIDs: [CID],
    source: any PublicRepositoryBlockSource
  ) {
    self.commit = commit
    self.orderedCIDs = orderedCIDs
    self.source = source
  }

  func nextBlock() async throws -> PublicRepositoryBlock? {
    if !emittedCommit {
      emittedCommit = true
      return commit
    }
    guard index < orderedCIDs.count else { return nil }
    let cid = orderedCIDs[index]
    defer { index += 1 }
    guard let bytes = try await source.block(for: cid) else {
      throw PublicFirehoseDiffCARError.missingBlock(cid)
    }
    return PublicRepositoryBlock(cid: cid, bytes: bytes)
  }
}

private actor PublicFirehoseCARCollector: PublicRepositoryCARByteSink {
  private var data = Data()

  func write(_ bytes: Data) async throws {
    data.append(bytes)
  }

  func collected() -> Data {
    data
  }
}
