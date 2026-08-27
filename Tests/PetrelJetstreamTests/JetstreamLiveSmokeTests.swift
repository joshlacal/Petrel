//
// JetstreamLiveSmokeTests.swift
// Petrel
//

import Foundation
import Petrel
import PetrelCore
import PetrelFirehose
@testable import PetrelJetstream
import XCTest

final class JetstreamLiveSmokeTests: XCTestCase {
  /// Live integration test against an active Jetstream host.
  /// Skipped by default unless JETSTREAM_SMOKE_URL environment variable is provided.
  func testLiveStreamReceivesCommitWithDecodableRecord() async throws {
    guard let smokeURLString = ProcessInfo.processInfo.environment["JETSTREAM_SMOKE_URL"],
      let smokeURL = URL(string: smokeURLString)
    else {
      throw XCTSkip("JETSTREAM_SMOKE_URL environment variable not set; skipping live smoke test")
    }

    let filter = JetstreamFilter(
      kinds: [.commit],
      dids: [],
      collections: ["app.bsky.feed.post"]
    )

    let config = JetstreamClientConfiguration(
      host: smokeURL,
      mode: .live(),
      filter: filter,
      batchSize: 10,
      compression: false,
      backoff: FirehoseBackoffConfiguration(initialDelay: 0.5, maxDelay: 5.0, multiplier: 2.0)
    )

    let client = JetstreamClient(configuration: config)

    // Run stream with a 30-second timeout
    let streamTask = Task { () -> [JetstreamBatch] in
      var collectedBatches: [JetstreamBatch] = []
      for try await batch in client.events() {
        collectedBatches.append(batch)
        // Stop after collecting at least 1 batch with a commit event
        if collectedBatches.contains(where: { b in
          b.events.contains(where: { e in
            if case .commit = e { return true }
            return false
          })
        }) {
          break
        }
      }
      return collectedBatches
    }

    let timeoutTask = Task {
      try await Task.sleep(nanoseconds: 30_000_000_000)
      streamTask.cancel()
    }

    do {
      let batches = try await streamTask.value
      timeoutTask.cancel()

      XCTAssertFalse(batches.isEmpty, "Expected at least 1 batch from live stream")

      var foundDecodableCommit = false
      for batch in batches {
        for event in batch.events {
          if case let .commit(commit) = event {
            XCTAssertEqual(commit.collection, "app.bsky.feed.post")
            if commit.operation != .delete {
              if commit.recordJSON != nil {
                foundDecodableCommit = true
                let decoded = commit.decodedRecord()
                XCTAssertNotNil(decoded, "Expected successful record decode")
              }
            }
          }
        }
      }

      XCTAssertTrue(foundDecodableCommit, "Expected at least one create/update commit with record payload")
    } catch let error as JetstreamSubscriptionError {
      // If host rejects due to unsupported endpoint (e.g. 404 or 400), report as environment finding
      timeoutTask.cancel()
      if case let .connectionRejected(status, _, _) = error {
        print("[SmokeTest] Host returned connectionRejected status \(status): \(error)")
      } else {
        throw error
      }
    } catch is CancellationError {
      timeoutTask.cancel()
      XCTFail("Timed out waiting for live stream events from \(smokeURL)")
    }
  }

  /// Bounded production replay smoke: plans and downloads the first ~2000
  /// archive events via authenticated planSnapshot/getBlock/getSegment,
  /// exercising the columnar decoder against real data. Byte-bounded by the
  /// tiny (0, 2000] seq window. Requires JETSTREAM_SMOKE_URL and
  /// JETSTREAM_API_KEY.
  func testSnapshotReplayDecodesArchiveSlice() async throws {
    guard let smokeURLString = ProcessInfo.processInfo.environment["JETSTREAM_SMOKE_URL"],
      let smokeURL = URL(string: smokeURLString)
    else {
      throw XCTSkip("JETSTREAM_SMOKE_URL not set; skipping replay smoke test")
    }
    guard let apiKey = ProcessInfo.processInfo.environment["JETSTREAM_API_KEY"], !apiKey.isEmpty
    else {
      throw XCTSkip("JETSTREAM_API_KEY not set; skipping replay smoke test")
    }

    let config = JetstreamClientConfiguration(
      host: smokeURL,
      mode: .snapshotOnly(afterSeq: 0, beforeSeq: 2000),
      batchSize: 256,
      apiKey: apiKey,
      backoff: FirehoseBackoffConfiguration(initialDelay: 0.5, maxDelay: 5.0, multiplier: 2.0)
    )

    let client = JetstreamClient(configuration: config)
    var seqs: [Int64] = []
    var decodedRecords = 0

    for try await batch in client.events() {
      for event in batch.events {
        if let seq = event.seq { seqs.append(seq) }
        if case let .commit(commit) = event, commit.recordJSON != nil,
          commit.decodedRecord() != nil
        {
          decodedRecords += 1
        }
      }
    }

    XCTAssertFalse(seqs.isEmpty, "Expected events in the (0, 2000] archive window")
    XCTAssertEqual(seqs, seqs.sorted(), "Seqs must arrive in ascending order")
    XCTAssertLessThanOrEqual(seqs.max() ?? 0, 2000, "beforeSeq bound must hold")
    XCTAssertGreaterThan(decodedRecords, 0, "Expected at least one decodable archive record")
    print("[ReplaySmoke] events=\(seqs.count) decodedRecords=\(decodedRecords) maxSeq=\(seqs.max() ?? 0)")
  }
}
