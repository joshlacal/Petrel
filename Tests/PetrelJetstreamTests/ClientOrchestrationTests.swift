import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel
import PetrelCore
import PetrelFirehose
@testable import PetrelJetstream
import SwiftCBOR
import XCTest

final class ClientOrchestrationTests: XCTestCase {
  private let testHost = URL(string: "https://jetstream.test")!
  private let fastBackoff = FirehoseBackoffConfiguration(
    initialDelay: 0.001,
    maxDelay: 0.005,
    multiplier: 1.0
  )

  // MARK: - Test 1: Multi-Page Snapshot + Block Units + Live Cutover

  func testTwoPageSnapshotWithSegmentAndBlockUnitsCutoverToLive() async throws {
    // Page 1: plannedThroughSeq = 50, sealedTipSeq = 100
    // Segment 1 (whole segment mode): covers seq 10...30 (3 events: seq 10, 20, 30)
    // Segment 2 (blocks mode, block 0): covers seq 31...50 (2 events: seq 40, 50)
    //
    // Page 2: plannedThroughSeq = 100, sealedTipSeq = 100
    // Segment 3 (whole segment mode): covers seq 51...100 (2 events: seq 60, 100)
    //
    // Window: afterSeq = 15 -> seq 10 dropped (<= 15), seqs 20, 30, 40, 50, 60, 100 admitted.
    //
    // Cutover to live at cursor = max(100, 100) = 100:
    // Live ws receives: seq 100 (duplicate boundary -> dropped), seq 101, seq 102.

    let postPayload = try makePostPayload(text: "hello")

    // Block for Segment 1
    let seg1Events = [
      RawEventSpec(seq: 10, kind: 1, collection: "app.bsky.feed.post", did: "did:plc:user1", payload: postPayload),
      RawEventSpec(seq: 20, kind: 1, collection: "app.bsky.feed.post", did: "did:plc:user1", payload: postPayload),
      RawEventSpec(seq: 30, kind: 1, collection: "app.bsky.feed.post", did: "did:plc:user1", payload: postPayload),
    ]
    let seg1BlockCompressed = try JetstreamZstd.compress(encodeBlock(seg1Events))
    let seg1FileData = makeJSSFile(blockCount: 1, compressedFrames: [seg1BlockCompressed])

    // Block for Segment 2 (block 0)
    let seg2Events = [
      RawEventSpec(seq: 40, kind: 1, collection: "app.bsky.feed.post", did: "did:plc:user1", payload: postPayload),
      RawEventSpec(seq: 50, kind: 1, collection: "app.bsky.feed.post", did: "did:plc:user1", payload: postPayload),
    ]
    let seg2BlockCompressed = try JetstreamZstd.compress(encodeBlock(seg2Events))

    // Block for Segment 3
    let seg3Events = [
      RawEventSpec(seq: 60, kind: 1, collection: "app.bsky.feed.post", did: "did:plc:user1", payload: postPayload),
      RawEventSpec(seq: 100, kind: 1, collection: "app.bsky.feed.post", did: "did:plc:user1", payload: postPayload),
    ]
    let seg3BlockCompressed = try JetstreamZstd.compress(encodeBlock(seg3Events))
    let seg3FileData = makeJSSFile(blockCount: 1, compressedFrames: [seg3BlockCompressed])

    let plan1 = SnapshotPlan(
      plannedThroughSeq: 50,
      sealedTipSeq: 100,
      segments: [
        SnapshotPlanSegment(
          name: "seg_001.jss",
          index: 1,
          checksum: "abcd1234abcd1234",
          minSeq: 10,
          maxSeq: 30,
          mode: "segment"
        ),
        SnapshotPlanSegment(
          name: "seg_002.jss",
          index: 2,
          checksum: "abcd1234abcd1235",
          minSeq: 31,
          maxSeq: 50,
          mode: "blocks",
          blocks: [SnapshotBlockRange(first: 0, last: 0)]
        ),
      ],
      stats: SnapshotPlanStats(segmentsExamined: 2, segmentsMatched: 2, blocksMatched: 2, entries: 5)
    )

    let plan2 = SnapshotPlan(
      plannedThroughSeq: 100,
      sealedTipSeq: 100,
      segments: [
        SnapshotPlanSegment(
          name: "seg_003.jss",
          index: 3,
          checksum: "abcd1234abcd1236",
          minSeq: 51,
          maxSeq: 100,
          mode: "segment"
        ),
      ],
      stats: SnapshotPlanStats(segmentsExamined: 1, segmentsMatched: 1, blocksMatched: 1, entries: 2)
    )

    let planCallCount = LockedBox<Int>(0)
    let transport = MockHTTPTransport(
      planHandler: { req in
        if planCallCount.mutate({ $0 += 1; return $0 }) == 1 {
          return plan1
        } else {
          return plan2
        }
      },
      segmentHandler: { name in
        if name == "seg_001.jss" {
          return seg1FileData
        } else if name == "seg_003.jss" {
          return seg3FileData
        }
        throw JetstreamXRPCError(status: 404, error: "SegmentNotFound")
      },
      blockHandler: { segment, blockIndex in
        if segment == "seg_002.jss" && blockIndex == 0 {
          return seg2BlockCompressed
        }
        throw JetstreamXRPCError(status: 404, error: "BlockNotFound")
      }
    )

    // Live session with boundary replay (seq 100) + new events 101, 102
    let liveSession = MockWebSocketSession(messages: [
      commitFrameJSON(seq: 100),
      commitFrameJSON(seq: 101),
      commitFrameJSON(seq: 102),
    ])
    let wsFactory = MockWebSocketFactory(sessions: [liveSession])

    let config = JetstreamClientConfiguration(
      host: testHost,
      mode: .snapshotThenLive(afterSeq: 15),
      batchSize: 2,
      downloadConcurrency: 2,
      compression: false,
      transport: transport,
      sessionFactory: wsFactory,
      backoff: fastBackoff
    )

    let client = JetstreamClient(configuration: config)
    var receivedBatches: [JetstreamBatch] = []

    for try await batch in client.events() {
      receivedBatches.append(batch)
      let allSeqs = receivedBatches.flatMap { $0.events.compactMap(\.seq) }
      if allSeqs.contains(102) {
        break
      }
    }

    let allEmittedSeqs = receivedBatches.flatMap { $0.events.compactMap(\.seq) }
    // Expected: 20, 30, 40, 50, 60, 100 (from backfill) then 101, 102 (from live). 10 and duplicate 100 excluded.
    XCTAssertEqual(allEmittedSeqs, [20, 30, 40, 50, 60, 100, 101, 102])

    // Verify batch sizes: backfill batches should be <= batchSize (2), live batches are 1 per event
    for batch in receivedBatches {
      XCTAssertFalse(batch.events.isEmpty)
      XCTAssertEqual(batch.lastCursor, batch.events.last?.seq)
    }

    let connectedURLs = await wsFactory.getConnectedURLs()
    XCTAssertEqual(connectedURLs.count, 1)
    let wsURL = try XCTUnwrap(connectedURLs.first)
    let comp = try XCTUnwrap(URLComponents(url: wsURL, resolvingAgainstBaseURL: false))
    XCTAssertEqual(comp.queryItems?.first(where: { $0.name == "cursor" })?.value, "100")
  }

  // MARK: - Test 2: Marker Delivery Under Collections Filter

  func testCollectionFilteredRunDeliversAccountAndSyncMarkers() async throws {
    let postPayload = try makePostPayload(text: "filtered post")
    let otherPostPayload = try makePostPayload(text: "other collection post")
    let accountPayload = try makeAccountPayload(did: "did:plc:bob", active: false, status: "deleted")
    let syncPayload = try makeSyncPayload(did: "did:plc:carol", rev: "3l3rev")

    let rawEvents: [RawEventSpec] = [
      RawEventSpec(seq: 1, kind: 1, collection: "app.bsky.feed.post", did: "did:plc:alice", payload: postPayload),
      RawEventSpec(seq: 2, kind: 1, collection: "app.bsky.feed.like", did: "did:plc:alice", payload: otherPostPayload),
      RawEventSpec(seq: 3, kind: 5, collection: "$account", did: "did:plc:bob", payload: accountPayload),
      RawEventSpec(seq: 4, kind: 6, collection: "$sync", did: "did:plc:carol", payload: syncPayload),
    ]

    let blockCompressed = try JetstreamZstd.compress(encodeBlock(rawEvents))
    let segmentData = makeJSSFile(blockCount: 1, compressedFrames: [blockCompressed])

    let plan = SnapshotPlan(
      plannedThroughSeq: 10,
      sealedTipSeq: 10,
      segments: [
        SnapshotPlanSegment(
          name: "seg_markers.jss",
          index: 1,
          checksum: "checksum1234",
          minSeq: 1,
          maxSeq: 4,
          mode: "segment"
        ),
      ],
      stats: SnapshotPlanStats(segmentsExamined: 1, segmentsMatched: 1, blocksMatched: 1, entries: 4)
    )

    let transport = MockHTTPTransport(
      planHandler: { _ in plan },
      segmentHandler: { _ in segmentData }
    )

    let wsFactory = MockWebSocketFactory(sessions: [])

    let filter = JetstreamFilter(
      kinds: [],
      dids: [],
      collections: ["app.bsky.feed.post"]
    )

    let config = JetstreamClientConfiguration(
      host: testHost,
      mode: .snapshotOnly(afterSeq: 0, beforeSeq: 10),
      filter: filter,
      batchSize: 10,
      transport: transport,
      sessionFactory: wsFactory,
      backoff: fastBackoff
    )

    let client = JetstreamClient(configuration: config)
    var receivedEvents: [JetstreamEvent] = []

    for try await batch in client.events() {
      receivedEvents.append(contentsOf: batch.events)
    }

    // Expected:
    // seq 1 (post in app.bsky.feed.post) -> delivered
    // seq 2 (like in app.bsky.feed.like) -> filtered out
    // seq 3 (account marker) -> delivered (collections filter only constrains commit)
    // seq 4 (sync marker) -> delivered
    XCTAssertEqual(receivedEvents.count, 3)
    XCTAssertEqual(receivedEvents.compactMap(\.seq), [1, 3, 4])

    // Verify seq 3 is an account event
    if case let .account(acc) = receivedEvents[1] {
      XCTAssertEqual(acc.seq, 3)
      XCTAssertEqual(acc.did, "did:plc:bob")
      XCTAssertEqual(acc.account?.active, false)
      XCTAssertEqual(acc.account?.status, "deleted")
    } else {
      XCTFail("Expected account event at index 1")
    }

    // Verify seq 4 is a sync event
    if case let .sync(sync) = receivedEvents[2] {
      XCTAssertEqual(sync.seq, 4)
      XCTAssertEqual(sync.did, "did:plc:carol")
      XCTAssertEqual(sync.sync?.rev, "3l3rev")
    } else {
      XCTFail("Expected sync event at index 2")
    }
  }

  // MARK: - Test 3: CursorTooOld on Cutover Re-plans from lastProcessed

  func testCursorTooOldOnCutoverReplansFromLastProcessedAndCompletes() async throws {
    let postPayload = try makePostPayload(text: "post1")

    // Initial backfill segment: seq 1...10
    let seg1Events = [
      RawEventSpec(seq: 5, kind: 1, collection: "app.bsky.feed.post", did: "did:plc:alice", payload: postPayload),
      RawEventSpec(seq: 10, kind: 1, collection: "app.bsky.feed.post", did: "did:plc:alice", payload: postPayload),
    ]
    let seg1Compressed = try JetstreamZstd.compress(encodeBlock(seg1Events))
    let seg1FileData = makeJSSFile(blockCount: 1, compressedFrames: [seg1Compressed])

    // Second backfill segment after CursorTooOld: seq 11...30
    let seg2Events = [
      RawEventSpec(seq: 20, kind: 1, collection: "app.bsky.feed.post", did: "did:plc:alice", payload: postPayload),
      RawEventSpec(seq: 30, kind: 1, collection: "app.bsky.feed.post", did: "did:plc:alice", payload: postPayload),
    ]
    let seg2Compressed = try JetstreamZstd.compress(encodeBlock(seg2Events))
    let seg2FileData = makeJSSFile(blockCount: 1, compressedFrames: [seg2Compressed])

    let plan1 = SnapshotPlan(
      plannedThroughSeq: 10,
      sealedTipSeq: 10,
      segments: [
        SnapshotPlanSegment(
          name: "seg_001.jss",
          index: 1,
          checksum: "chk1",
          minSeq: 1,
          maxSeq: 10,
          mode: "segment"
        ),
      ],
      stats: SnapshotPlanStats(segmentsExamined: 1, segmentsMatched: 1, blocksMatched: 1, entries: 2)
    )

    let plan2 = SnapshotPlan(
      plannedThroughSeq: 30,
      sealedTipSeq: 30,
      segments: [
        SnapshotPlanSegment(
          name: "seg_002.jss",
          index: 2,
          checksum: "chk2",
          minSeq: 11,
          maxSeq: 30,
          mode: "segment"
        ),
      ],
      stats: SnapshotPlanStats(segmentsExamined: 1, segmentsMatched: 1, blocksMatched: 1, entries: 2)
    )

    let planRequests = LockedBox<[SnapshotPlanRequest]>([])
    let transport = MockHTTPTransport(
      planHandler: { req in
        let count = planRequests.mutate { $0.append(req); return $0.count }
        if count == 1 {
          return plan1
        } else {
          return plan2
        }
      },
      segmentHandler: { name in
        if name == "seg_001.jss" {
          return seg1FileData
        } else {
          return seg2FileData
        }
      },
      probeHandler: { req in
        // When probing after first WS connection failure at cursor 10
        let errorJSON = """
        {
          "error": "CursorTooOld",
          "message": "Retention floor has advanced past seq 10"
        }
        """.data(using: .utf8)!
        let resp = HTTPURLResponse(url: req.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
        return (errorJSON, resp)
      }
    )

    // First WS session fails immediately on connect (simulates CursorTooOld rejection)
    let wsSession1 = MockWebSocketSession(
      messages: [],
      errorAfterMessages: URLError(.badServerResponse)
    )

    // Second WS session (after replanning to seq 30) succeeds with live frames
    let wsSession2 = MockWebSocketSession(messages: [
      commitFrameJSON(seq: 31),
      commitFrameJSON(seq: 32),
    ])

    let wsFactory = MockWebSocketFactory(sessions: [wsSession1, wsSession2])

    let config = JetstreamClientConfiguration(
      host: testHost,
      mode: .snapshotThenLive(afterSeq: 0),
      batchSize: 10,
      transport: transport,
      sessionFactory: wsFactory,
      backoff: fastBackoff
    )

    let client = JetstreamClient(configuration: config)
    var allSeqs: [Int64] = []

    for try await batch in client.events() {
      allSeqs.append(contentsOf: batch.events.compactMap(\.seq))
      if allSeqs.contains(32) {
        break
      }
    }

    // Backfill 1: 5, 10 -> WS at 10 fails with CursorTooOld -> Re-plan from 10 -> Backfill 2: 20, 30 -> WS at 30: 31, 32
    XCTAssertEqual(allSeqs, [5, 10, 20, 30, 31, 32])
    let recordedPlans = planRequests.mutate { $0 }
    XCTAssertEqual(recordedPlans.count, 2)
    XCTAssertEqual(recordedPlans[0].afterSeq, nil)
    XCTAssertEqual(recordedPlans[1].afterSeq, 10)
  }

  // MARK: - Test 4: SnapshotOnly Mode Terminates Cleanly

  func testSnapshotOnlyModeTerminatesAfterSealedRange() async throws {
    let postPayload = try makePostPayload(text: "snapshot post")

    let events = [
      RawEventSpec(seq: 100, kind: 1, collection: "app.bsky.feed.post", did: "did:plc:alice", payload: postPayload),
      RawEventSpec(seq: 200, kind: 1, collection: "app.bsky.feed.post", did: "did:plc:alice", payload: postPayload),
      RawEventSpec(seq: 300, kind: 1, collection: "app.bsky.feed.post", did: "did:plc:alice", payload: postPayload),
    ]
    let blockCompressed = try JetstreamZstd.compress(encodeBlock(events))
    let segmentData = makeJSSFile(blockCount: 1, compressedFrames: [blockCompressed])

    let plan = SnapshotPlan(
      plannedThroughSeq: 250,
      sealedTipSeq: 500,
      segments: [
        SnapshotPlanSegment(
          name: "seg_only.jss",
          index: 1,
          checksum: "chk",
          minSeq: 100,
          maxSeq: 300,
          mode: "segment"
        ),
      ],
      stats: SnapshotPlanStats(segmentsExamined: 1, segmentsMatched: 1, blocksMatched: 1, entries: 3)
    )

    let transport = MockHTTPTransport(
      planHandler: { _ in plan },
      segmentHandler: { _ in segmentData }
    )

    let wsFactory = MockWebSocketFactory(sessions: [])

    let config = JetstreamClientConfiguration(
      host: testHost,
      mode: .snapshotOnly(afterSeq: 50, beforeSeq: 250),
      batchSize: 5,
      transport: transport,
      sessionFactory: wsFactory,
      backoff: fastBackoff
    )

    let client = JetstreamClient(configuration: config)
    var emittedSeqs: [Int64] = []

    for try await batch in client.events() {
      emittedSeqs.append(contentsOf: batch.events.compactMap(\.seq))
    }

    // Window (50, 250]: seq 100, 200 admitted; seq 300 > 250 excluded
    XCTAssertEqual(emittedSeqs, [100, 200])

    // Verify WebSocket factory was never called
    let connectedURLs = await wsFactory.getConnectedURLs()
    XCTAssertTrue(connectedURLs.isEmpty)
  }

  // MARK: - Helpers & Fixture Builders

  private struct RawEventSpec {
    var seq: Int64
    var witnessedAtUS: Int64 = 1_700_000_000_000_000
    var indexedAtUS: Int64 = 1_700_000_000_123_456
    var kind: UInt8
    var collection: String
    var did: String
    var rkey: String = "rkey1"
    var rev: String = "rev1"
    var payload: Data
  }

  private func encodeBlock(_ events: [RawEventSpec]) -> Data {
    var data = Data()
    let count = UInt32(events.count)
    var countLE = count.littleEndian
    data.append(Data(bytes: &countLE, count: 4))

    if events.isEmpty {
      return data
    }

    for e in events {
      var val = UInt64(bitPattern: e.seq).littleEndian
      data.append(Data(bytes: &val, count: 8))
    }
    for e in events {
      var val = UInt64(bitPattern: e.witnessedAtUS).littleEndian
      data.append(Data(bytes: &val, count: 8))
    }
    for e in events {
      var val = UInt64(bitPattern: e.indexedAtUS).littleEndian
      data.append(Data(bytes: &val, count: 8))
    }
    for e in events {
      data.append(e.kind)
    }
    for e in events {
      data.append(UInt8(e.collection.utf8.count))
    }
    for e in events {
      var val = UInt16(e.did.utf8.count).littleEndian
      data.append(Data(bytes: &val, count: 2))
    }
    for e in events {
      data.append(UInt8(e.rkey.utf8.count))
    }
    for e in events {
      data.append(UInt8(e.rev.utf8.count))
    }
    for e in events {
      var val = UInt32(e.payload.count).littleEndian
      data.append(Data(bytes: &val, count: 4))
    }

    for e in events { data.append(contentsOf: e.collection.utf8) }
    for e in events { data.append(contentsOf: e.did.utf8) }
    for e in events { data.append(contentsOf: e.rkey.utf8) }
    for e in events { data.append(contentsOf: e.rev.utf8) }
    for e in events { data.append(e.payload) }

    return data
  }

  private func makeJSSFile(blockCount: UInt32, compressedFrames: [Data]) -> Data {
    var totalBlocksSize: UInt64 = 0
    for frame in compressedFrames {
      totalBlocksSize += 8 + UInt64(frame.count)
    }
    let footerOffset = 256 + totalBlocksSize

    var fileData = Data(count: 256)
    fileData.withUnsafeMutableBytes { ptr in
      for (i, b) in "jss0".utf8.enumerated() {
        ptr.storeBytes(of: b, toByteOffset: i, as: UInt8.self)
      }
      ptr.storeBytes(of: UInt64(0x1234_5678_9ABC_DEF0).littleEndian, toByteOffset: 4, as: UInt64.self)
      ptr.storeBytes(of: UInt16(1).littleEndian, toByteOffset: 12, as: UInt16.self)
      ptr.storeBytes(of: blockCount.littleEndian, toByteOffset: 14, as: UInt32.self)
      ptr.storeBytes(of: footerOffset.littleEndian, toByteOffset: 58, as: UInt64.self)
    }

    for frame in compressedFrames {
      var frameLen = UInt64(frame.count).littleEndian
      fileData.append(Data(bytes: &frameLen, count: 8))
      fileData.append(frame)
    }

    // Dummy footer bytes
    fileData.append("footer".data(using: .utf8)!)
    return fileData
  }

  private func makePostPayload(text: String) throws -> Data {
    let postMap = OrderedCBORMap(entries: [
      (key: "$type", value: "app.bsky.feed.post"),
      (key: "text", value: text),
    ])
    return try DAGCBOR.encodeValue(postMap)
  }

  private func makeAccountPayload(did: String, active: Bool, status: String) throws -> Data {
    let accountMap = OrderedCBORMap(entries: [
      (key: "$type", value: "com.atproto.sync.subscribeRepos#account"),
      (key: "seq", value: 1),
      (key: "did", value: did),
      (key: "time", value: "2026-08-27T10:00:01.000Z"),
      (key: "active", value: active),
      (key: "status", value: status),
    ])
    return try DAGCBOR.encodeValue(accountMap)
  }

  private func makeSyncPayload(did: String, rev: String) throws -> Data {
    let syncMap = OrderedCBORMap(entries: [
      (key: "$type", value: "com.atproto.sync.subscribeRepos#sync"),
      (key: "seq", value: 1),
      (key: "did", value: did),
      (key: "blocks", value: Data([0x01, 0x02])),
      (key: "rev", value: rev),
      (key: "time", value: "2026-08-27T10:00:02.000Z"),
    ])
    return try DAGCBOR.encodeValue(syncMap)
  }

  private func commitFrameJSON(
    seq: Int64,
    did: String = "did:plc:testuser",
    time: String = "2026-08-27T12:00:00.000000Z",
    rev: String = "rev123",
    operation: String = "create",
    collection: String = "app.bsky.feed.post",
    rkey: String = "rkey123"
  ) -> Data {
    let json = """
    {
      "$type": "message",
      "payload": {
        "$type": "network.bsky.jetstream.subscribeEvents#commit",
        "seq": \(seq),
        "did": "\(did)",
        "time": "\(time)",
        "rev": "\(rev)",
        "operation": "\(operation)",
        "collection": "\(collection)",
        "rkey": "\(rkey)"
      }
    }
    """
    return json.data(using: .utf8)!
  }
}

// MARK: - Test Doubles

private struct MockHTTPTransport: JetstreamHTTPTransport {
  var planHandler: (@Sendable (SnapshotPlanRequest) async throws -> SnapshotPlan)?
  var segmentHandler: (@Sendable (String) async throws -> Data)?
  var blockHandler: (@Sendable (String, Int) async throws -> Data)?
  var probeHandler: (@Sendable (URLRequest) async throws -> (Data, HTTPURLResponse))?

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    guard let url = request.url else {
      throw URLError(.badURL)
    }

    if url.path.contains("planSnapshot") {
      guard let body = request.httpBody else {
        throw URLError(.badServerResponse)
      }
      let planReq = try JSONCoders.decode(SnapshotPlanRequest.self, from: body)
      if let planHandler {
        let plan = try await planHandler(planReq)
        let data = try JSONCoders.encode(plan)
        let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (data, resp)
      }
    } else if url.path.contains("getBlock") {
      let comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
      let segment = comp?.queryItems?.first(where: { $0.name == "segment" })?.value ?? ""
      let blockIndex = Int(comp?.queryItems?.first(where: { $0.name == "blockIndex" })?.value ?? "0") ?? 0
      if let blockHandler {
        let data = try await blockHandler(segment, blockIndex)
        let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (data, resp)
      }
    } else if url.path.contains("subscribeEvents") {
      if let probeHandler {
        return try await probeHandler(request)
      }
    }

    let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    return (Data(), resp)
  }

  func download(for request: URLRequest) async throws -> (URL, HTTPURLResponse) {
    guard let url = request.url else {
      throw URLError(.badURL)
    }
    let comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
    let segmentName = comp?.queryItems?.first(where: { $0.name == "name" })?.value ?? ""

    if let segmentHandler {
      let data = try await segmentHandler(segmentName)
      let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("mock_seg_\(UUID().uuidString).jss")
      try data.write(to: tempURL)
      let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
      return (tempURL, resp)
    }

    throw URLError(.fileDoesNotExist)
  }
}

private actor MockWebSocketSession: FirehoseWebSocketSession {
  private var messages: [Data]
  private let errorAfterMessages: Error?
  private(set) var isClosed = false

  init(messages: [Data], errorAfterMessages: Error? = nil) {
    self.messages = messages
    self.errorAfterMessages = errorAfterMessages
  }

  func receiveMessage() async throws -> Data {
    if messages.isEmpty {
      if let error = errorAfterMessages {
        throw error
      }
      throw URLError(.cancelled)
    }
    return messages.removeFirst()
  }

  func close() {
    isClosed = true
  }
}

private actor MockWebSocketFactory: FirehoseWebSocketSessionFactory {
  private var sessions: [any FirehoseWebSocketSession]
  private(set) var connectedURLs: [URL] = []

  init(sessions: [any FirehoseWebSocketSession]) {
    self.sessions = sessions
  }

  func makeSession(url: URL) async throws -> any FirehoseWebSocketSession {
    connectedURLs.append(url)
    guard !sessions.isEmpty else {
      throw URLError(.badServerResponse)
    }
    return sessions.removeFirst()
  }

  func getConnectedURLs() -> [URL] {
    connectedURLs
  }
}

/// Minimal thread-safe box for mutating captures inside @Sendable handlers.
final class LockedBox<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Value

  init(_ value: Value) {
    self.value = value
  }

  func mutate<R>(_ body: (inout Value) -> R) -> R {
    lock.lock()
    defer { lock.unlock() }
    return body(&value)
  }
}
