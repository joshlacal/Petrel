import Crypto
import Foundation
import Petrel
@testable import PetrelFirehose
import PetrelRepo
import PetrelStreamingTestSupport
import Testing

/// Official `firehose/commit-proof-fixtures.json` from bluesky-social/atproto-interop-tests,
/// loaded from disk and iterated in full.
///
/// Each fixture describes one repository commit: the MST keys before it, the keys it adds and
/// deletes, the MST root before and after, and the MST blocks a `#commit` event must carry so
/// a consumer can verify it against `prevData` ("blocksInProof"). The streaming layer's job is
/// to deliver exactly those bytes. So each fixture is turned into the `#commit` frame a relay
/// would send, pushed through `FirehoseSubscription`, and the delivered event is checked
/// against the fixture: operations, `prevData`, the commit's data root, and the block set of
/// the diff CAR.
///
/// The frame is produced without the library's own MST or frame encoder (the fixture keys are
/// synthetic and not valid collection NSIDs): a minimal MST builder below, validated here
/// against the fixtures' own roots, and the independent `TestDAGCBOR` encoder.
@Suite("Official firehose commit-proof vectors")
struct FirehoseCommitProofVectorTests {
  struct Fixture: Decodable, Sendable, CustomTestStringConvertible {
    let comment: String
    let leafValue: String
    let keys: [String]
    let adds: [String]
    let dels: [String]
    let rootBeforeCommit: String
    let rootAfterCommit: String
    let blocksInProof: [String]

    var testDescription: String { comment }
  }

  static let fixtures: [Fixture] = {
    guard let url = Bundle.module.url(
      forResource: "commit-proof-fixtures", withExtension: "json", subdirectory: "Vectors/firehose"
    ), let data = try? Data(contentsOf: url),
      let fixtures = try? JSONDecoder().decode([Fixture].self, from: data)
    else { return [] }
    return fixtures
  }()

  @Test("the vector file is present and complete")
  func vectorFileLoads() {
    #expect(Self.fixtures.count == 6)
    let allHaveProofs: Bool = Self.fixtures.allSatisfy { !$0.blocksInProof.isEmpty }
    #expect(allHaveProofs)
  }

  @Test("each commit proof survives the firehose: frame, subscription, diff CAR", arguments: fixtures)
  func commitProofIsDelivered(fixture: Fixture) async throws {
    let leaf = try CID.parse(fixture.leafValue)
    let keysAfter = fixture.keys.filter { !fixture.dels.contains($0) } + fixture.adds

    // The test-side MST must reproduce the fixture's roots before it is used for anything.
    let before = TestMST(keys: fixture.keys, value: leaf)
    let after = TestMST(keys: keysAfter, value: leaf)
    #expect(before.root?.string == fixture.rootBeforeCommit)
    #expect(after.root?.string == fixture.rootAfterCommit)
    let rootBefore = try #require(before.root)
    let rootAfter = try #require(after.root)

    // The proof blocks all belong to the tree after the commit.
    let proofCIDs = try fixture.blocksInProof.map(CID.parse)
    let proofBlocks = try proofCIDs.map { cid in
      PublicRepositoryBlock(cid: cid, bytes: try #require(after.blocks[cid], "proof block \(cid.string) is not in the tree"))
    }

    // An (unsigned) commit object pointing at the new root, and the diff CAR around it.
    let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    let rev = "3lon5dzeaihj2"
    let commitBytes = TestDAGCBOR.map([
      ("did", .text(did)), ("version", .unsigned(3)), ("data", .link(rootAfter.bytes)),
      ("rev", .text(rev)), ("prev", .null), ("sig", .bytes(Data(repeating: 0, count: 64))),
    ]).encoded
    let commitCID = CID.fromDAGCBOR(commitBytes)
    let car = try await PublicFirehoseDiffCAR.build(
      commitCID: commitCID,
      commitBytes: commitBytes,
      newBlocks: try PublicRepositoryBlockMap(blocks: proofBlocks)
    )

    let operations: [TestDAGCBOR] = fixture.adds.map { key in
      .map([("action", .text("create")), ("path", .text(key)), ("cid", .link(leaf.bytes))])
    } + fixture.dels.map { key in
      .map([("action", .text("delete")), ("path", .text(key)), ("cid", .null), ("prev", .link(leaf.bytes))])
    }
    let frame = TestDAGCBOR.messageFrame(type: "#commit", payload: [
      ("seq", .unsigned(1)), ("rebase", .bool(false)), ("tooBig", .bool(false)),
      ("repo", .text(did)), ("commit", .link(commitCID.bytes)), ("rev", .text(rev)),
      ("since", .null), ("blocks", .bytes(car)), ("ops", .array(operations)),
      ("blobs", .array([])), ("prevData", .link(rootBefore.bytes)),
      ("time", .text("2026-08-08T12:00:00.000Z")),
    ])

    // Through the consumer.
    let subscription = FirehoseSubscription(
      url: URL(string: "wss://relay.example/xrpc/com.atproto.sync.subscribeRepos")!,
      sessionFactory: ScriptedWebSocketFactory(sessions: [ScriptedWebSocketSession(messages: [frame])])
    )
    var delivered: RelayCommitEvent?
    for try await event in subscription.events() {
      if case let .event(.commit(commit)) = event {
        delivered = commit
      } else {
        Issue.record("unexpected \(event)")
      }
      break
    }
    let commit = try #require(delivered)

    #expect(commit.commitCID == commitCID)
    #expect(commit.prevDataCID?.string == fixture.rootBeforeCommit)
    let creates: [RelayRepoOp] = commit.ops.filter { $0.action == .create }
    let deletes: [RelayRepoOp] = commit.ops.filter { $0.action == .delete }
    let createdPaths: [String] = creates.map(\.path)
    let deletedPaths: [String] = deletes.map(\.path)
    #expect(createdPaths == fixture.adds)
    #expect(deletedPaths == fixture.dels)
    let createsCarryLeaf: Bool = creates.allSatisfy { $0.cid == leaf && $0.prev == nil }
    let deletesCarryPrev: Bool = deletes.allSatisfy { $0.cid == nil && $0.prev == leaf }
    #expect(createsCarryLeaf)
    #expect(deletesCarryPrev)

    // The delivered `blocks` are a CAR rooted at the commit, holding the commit plus exactly
    // the fixture's proof blocks, each of which hashes to its CID.
    let reader = try CARReader(data: commit.blocks)
    #expect(reader.roots == [commitCID])
    let deliveredBlocks: Set<Data> = Set(reader.rawBlockIndex.keys)
    var expectedBlocks: Set<Data> = Set(proofCIDs.map(\.bytes))
    expectedBlocks.insert(commitCID.bytes)
    #expect(deliveredBlocks == expectedBlocks)
    for cid in proofCIDs {
      let bytes = try reader.rawBlockData(for: cid)
      #expect(CID.fromDAGCBOR(bytes) == cid)
    }
    // The commit block in the CAR points at the fixture's root after the commit.
    let deliveredCommit = try reader.rawBlockData(for: commitCID)
    #expect(deliveredCommit == commitBytes)
    var rootLink = Data([0x00] as [UInt8])
    rootLink.append(rootAfter.bytes)
    let pointsAtRootAfter: Bool = deliveredCommit.range(of: rootLink) != nil
    #expect(pointsAtRootAfter)
  }
}

/// A minimal Merkle Search Tree builder (atproto repository spec), used only to turn fixture
/// keys into node blocks. It is checked against the fixtures' `rootBeforeCommit` and
/// `rootAfterCommit` in every test case.
struct TestMST {
  private(set) var blocks: [CID: Data] = [:]
  private(set) var root: CID?

  init(keys: [String], value: CID) {
    let sorted = keys.sorted { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }
    guard !sorted.isEmpty else { return }
    let top = sorted.map(Self.layer).max() ?? 0
    root = build(sorted[...], layer: top, value: value)
  }

  /// Leading zero bits of SHA-256(key), counted in 2-bit chunks.
  static func layer(of key: String) -> Int {
    var zeros = 0
    for byte in SHA256.hash(data: Data(key.utf8)) {
      if byte == 0 {
        zeros += 8
        continue
      }
      zeros += byte.leadingZeroBitCount
      break
    }
    return zeros / 2
  }

  private mutating func build(_ keys: ArraySlice<String>, layer: Int, value: CID) -> CID? {
    guard !keys.isEmpty else { return nil }
    var leaves: [String] = []
    var subtrees: [CID?] = []
    var run = keys.startIndex
    for index in keys.indices where Self.layer(of: keys[index]) == layer {
      subtrees.append(build(keys[run ..< index], layer: layer - 1, value: value))
      leaves.append(keys[index])
      run = index + 1
    }
    subtrees.append(build(keys[run ..< keys.endIndex], layer: layer - 1, value: value))

    var entries: [TestDAGCBOR] = []
    var previous: [UInt8] = []
    for (offset, key) in leaves.enumerated() {
      let bytes = Array(key.utf8)
      var shared = 0
      while shared < previous.count, shared < bytes.count, previous[shared] == bytes[shared] {
        shared += 1
      }
      entries.append(.map([
        ("k", .bytes(Data(bytes[shared...]))),
        ("p", .unsigned(UInt64(shared))),
        ("t", subtrees[offset + 1].map { .link($0.bytes) } ?? .null),
        ("v", .link(value.bytes)),
      ]))
      previous = bytes
    }
    let node = TestDAGCBOR.map([
      ("e", .array(entries)),
      ("l", subtrees[0].map { .link($0.bytes) } ?? .null),
    ]).encoded
    let cid = CID.fromDAGCBOR(node)
    blocks[cid] = node
    return cid
  }
}
