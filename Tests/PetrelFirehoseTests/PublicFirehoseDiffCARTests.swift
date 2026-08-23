import Foundation
import Petrel
import PetrelRepo
import XCTest
@testable import PetrelFirehose

final class PublicFirehoseDiffCARTests: XCTestCase {
  private func syntheticBlock(_ seed: UInt8) -> PublicRepositoryBlock {
    let bytes = Data([seed, seed + 1, seed + 2, seed + 3])
    return PublicRepositoryBlock(cid: CID.fromDAGCBOR(bytes), bytes: bytes)
  }

  private func parseCAR(
    _ car: Data
  ) async throws -> (roots: [CID], blocks: [(cid: CID, bytes: Data)]) {
    let sink = FirehoseCARRecordingSink()
    _ = try await PublicRepositoryCAR.parseIncrementally(
      from: FirehoseCARDataSource(data: car),
      to: sink
    )
    return await sink.result()
  }

  func testRepeatedBuildsAreByteIdentical() async throws {
    let commit = syntheticBlock(0x10)
    let extra = [syntheticBlock(0x30), syntheticBlock(0x20), syntheticBlock(0x40)]
    let map = try PublicRepositoryBlockMap(blocks: extra)
    let first = try await PublicFirehoseDiffCAR.build(
      commitCID: commit.cid,
      commitBytes: commit.bytes,
      newBlocks: map
    )
    let second = try await PublicFirehoseDiffCAR.build(
      commitCID: commit.cid,
      commitBytes: commit.bytes,
      newBlocks: map
    )
    XCTAssertEqual(first, second)
  }

  func testCARRootIsCommitCID() async throws {
    let commit = syntheticBlock(0x10)
    let extra = [syntheticBlock(0x30), syntheticBlock(0x20)]
    let map = try PublicRepositoryBlockMap(blocks: extra)
    let car = try await PublicFirehoseDiffCAR.build(
      commitCID: commit.cid,
      commitBytes: commit.bytes,
      newBlocks: map
    )
    let parsed = try await parseCAR(car)
    XCTAssertEqual(parsed.roots, [commit.cid])
  }

  func testCommitBlockIsFirstAndRemainingSortedByCIDString() async throws {
    let commit = syntheticBlock(0x10)
    let unsorted = [syntheticBlock(0x40), syntheticBlock(0x20), syntheticBlock(0x30)]
    let map = try PublicRepositoryBlockMap(blocks: unsorted)
    let car = try await PublicFirehoseDiffCAR.build(
      commitCID: commit.cid,
      commitBytes: commit.bytes,
      newBlocks: map
    )
    let parsed = try await parseCAR(car)
    XCTAssertEqual(parsed.blocks.count, 4)
    XCTAssertEqual(parsed.blocks[0].cid, commit.cid)
    XCTAssertEqual(parsed.blocks[0].bytes, commit.bytes)
    let remaining = parsed.blocks.dropFirst().map(\.cid)
    XCTAssertEqual(remaining, remaining.sorted { $0.string < $1.string })
    XCTAssertEqual(
      remaining.map(\.string),
      unsorted.map(\.cid.string).sorted()
    )
  }

  func testMissingBlockProducesTypedError() async throws {
    let commit = syntheticBlock(0x10)
    let missing = syntheticBlock(0x50)
    let stream = PublicFirehoseDiffCARBlockStream(
      commit: PublicRepositoryBlock(cid: commit.cid, bytes: commit.bytes),
      orderedCIDs: [missing.cid],
      source: FirehoseEmptyBlockSource()
    )
    let first = try await stream.nextBlock()
    XCTAssertEqual(first?.cid, commit.cid)
    do {
      _ = try await stream.nextBlock()
      XCTFail("expected missingBlock")
    } catch let error as PublicFirehoseDiffCARError {
      XCTAssertEqual(error, .missingBlock(missing.cid))
    }
  }

  func testCommitOnlyContainsExactlyTheCommitBlock() async throws {
    let commit = syntheticBlock(0x10)
    let car = try await PublicFirehoseDiffCAR.commitOnly(
      commitCID: commit.cid,
      commitBytes: commit.bytes
    )
    let parsed = try await parseCAR(car)
    XCTAssertEqual(parsed.roots, [commit.cid])
    XCTAssertEqual(parsed.blocks.count, 1)
    XCTAssertEqual(parsed.blocks[0].cid, commit.cid)
    XCTAssertEqual(parsed.blocks[0].bytes, commit.bytes)
  }

  func testSyntheticBlocksAreValidDAGCBORCIDs() {
    for seed in UInt8(0) ... 9 {
      let block = syntheticBlock(seed)
      XCTAssertNoThrow(try PublicRepositoryCID.validate(block.cid, blockBytes: block.bytes))
    }
  }
}

private actor FirehoseCARDataSource: PublicRepositoryCARByteSource {
  private let data: Data
  private var offset = 0

  init(data: Data) {
    self.data = data
  }

  func read(maximumBytes: Int) async throws -> Data? {
    guard offset < data.count else { return nil }
    let end = min(data.count, offset + maximumBytes)
    let result = Data(data[offset ..< end])
    offset = end
    return result
  }
}

private actor FirehoseCARRecordingSink: PublicRepositoryCARFrameSink {
  private var roots: [CID] = []
  private var blocks: [(cid: CID, bytes: Data)] = []

  func receiveHeader(rootCID: CID, receivedByteCount: Int) async throws {
    roots.append(rootCID)
  }

  func receiveBlock(
    _ block: PublicRepositoryBlock,
    receivedByteCount: Int,
    frameCount: Int
  ) async throws {
    blocks.append((block.cid, block.bytes))
  }

  func result() -> (roots: [CID], blocks: [(cid: CID, bytes: Data)]) {
    (roots, blocks)
  }
}

private struct FirehoseEmptyBlockSource: PublicRepositoryBlockSource {
  func block(for cid: CID) async throws -> Data? {
    nil
  }
}
