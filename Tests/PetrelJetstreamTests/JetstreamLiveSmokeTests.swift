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
  private static let postFilter = JetstreamFilter(kinds: [.commit], dids: [], collections: ["app.bsky.feed.post"])
  private static let backoff = FirehoseBackoffConfiguration(initialDelay: 0.5, maxDelay: 5.0, multiplier: 2.0)

  private static func isPostCreate(_ event: JetstreamEvent) -> JetstreamCommitEvent? {
    if case let .commit(commit) = event, commit.operation != .delete, commit.recordJSON != nil {
      return commit
    }
    return nil
  }

  /// Runs `search` until it returns a create/update commit, or 30 seconds have passed.
  /// Any thrown error (a rejected connection included) fails the test: a smoke test that
  /// tolerates rejection passes vacuously.
  private func firstPostCommit(
    file: StaticString = #filePath, line: UInt = #line,
    _ search: @escaping @Sendable () async throws -> JetstreamCommitEvent?
  ) async throws -> JetstreamCommitEvent? {
    let consumer = Task { try await search() }
    let timeout = Task {
      try await Task.sleep(nanoseconds: 30_000_000_000)
      consumer.cancel()
    }
    defer { timeout.cancel() }
    let commit = try await consumer.value
    XCTAssertNotNil(commit, "No create/update commit within 30 s", file: file, line: line)
    if let commit {
      XCTAssertEqual(commit.collection, "app.bsky.feed.post", file: file, line: line)
      XCTAssertNotNil(commit.decodedRecord(), "Expected the record to decode", file: file, line: line)
      XCTAssertGreaterThan(commit.seq, 0, file: file, line: line)
    }
    return commit
  }

  /// Live integration test against an active Jetstream host, through `JetstreamClient` with
  /// its default transport and no compression (production then sends WebSocket TEXT frames).
  ///
  /// `JETSTREAM_SMOKE_URL` is either a base host (v2 API) or a full legacy endpoint ending in
  /// `/subscribe`, e.g. `wss://jetstream2.us-east.bsky.network/subscribe`.
  func testLiveStreamReceivesCommitWithDecodableRecord() async throws {
    guard let smokeURLString = ProcessInfo.processInfo.environment["JETSTREAM_SMOKE_URL"],
      let smokeURL = URL(string: smokeURLString)
    else {
      throw XCTSkip("JETSTREAM_SMOKE_URL environment variable not set; skipping live smoke test")
    }

    let client = JetstreamClient(configuration: JetstreamClientConfiguration(
      host: smokeURL,
      mode: .live(),
      filter: Self.postFilter,
      batchSize: 10,
      compression: false,
      backoff: Self.backoff
    ))
    _ = try await firstPostCommit {
      for try await batch in client.events() {
        if let commit = batch.events.lazy.compactMap(Self.isPostCreate).first {
          return commit
        }
      }
      return nil
    }
  }

  /// The v2 API on `JETSTREAM_SMOKE_V2_URL` (a base host such as
  /// `https://jetstream2.us-east.bsky.network`), once uncompressed (TEXT frames) and once with
  /// the server's zstd dictionary (BINARY frames).
  func testLiveV2StreamUncompressedAndCompressed() async throws {
    guard let smokeURLString = ProcessInfo.processInfo.environment["JETSTREAM_SMOKE_V2_URL"],
      let smokeURL = URL(string: smokeURLString)
    else {
      throw XCTSkip("JETSTREAM_SMOKE_V2_URL environment variable not set; skipping live smoke test")
    }

    for compression in [false, true] {
      let subscription = JetstreamSubscription(configuration: .init(
        url: smokeURL, filter: Self.postFilter, compression: compression, backoff: Self.backoff
      ))
      XCTAssertEqual(subscription.configuration.resolvedAPIVersion, .v2)
      let commit = try await firstPostCommit {
        for try await element in subscription.events() {
          if case let .event(event) = element, let commit = Self.isPostCreate(event) {
            return commit
          }
        }
        return nil
      }
      // v2 cursors are sequence numbers, far below unix-microsecond timestamps.
      XCTAssertLessThan(commit?.seq ?? 0, 1_000_000_000_000_000, "compression: \(compression)")
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
