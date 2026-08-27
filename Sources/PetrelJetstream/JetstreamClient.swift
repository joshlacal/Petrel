//
// JetstreamClient.swift
// Petrel
//
// Hand-written Jetstream v2 orchestrating client.
// Note: Lexicon codegen is not used for Jetstream v2 because ATProto generator templates
// assume authenticated PDS-bound firehose framing rather than unauthenticated proposal-0015
// JSON framing on independent Jetstream relays.
//

import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel
import PetrelFirehose

// MARK: - Mode

/// Operating mode for the Jetstream client.
public enum JetstreamMode: Sendable, Equatable {
  /// Stream live events directly from WebSocket, skipping archive backfill.
  case live(cursor: Int64? = nil)
  /// Backfill matching archive segments/blocks up to the sealed tip, then cut over to live.
  case snapshotThenLive(afterSeq: Int64 = 0)
  /// Backfill archive segments/blocks within the sequence window, then finish.
  case snapshotOnly(afterSeq: Int64 = 0, beforeSeq: Int64? = nil)
}

// MARK: - Batch

/// A batch of decoded Jetstream events delivered to the consumer.
public struct JetstreamBatch: Sendable {
  /// Decoded events in ascending sequence order.
  public let events: [JetstreamEvent]
  /// Highest sequence number in the batch (or the active cursor if the batch contains only info events).
  public let lastCursor: Int64

  public init(events: [JetstreamEvent], lastCursor: Int64) {
    self.events = events
    self.lastCursor = lastCursor
  }
}

// MARK: - Configuration

/// Configuration for the Jetstream v2 orchestrating client.
public struct JetstreamClientConfiguration: Sendable {
  /// Base host URL for the Jetstream service (e.g. `https://jetstream.example.com`).
  public var host: URL
  /// Client execution mode.
  public var mode: JetstreamMode
  /// Event filter predicates.
  public var filter: JetstreamFilter
  /// Maximum events per batch during archive backfill.
  public var batchSize: Int
  /// Maximum concurrent HTTP segment/block downloads.
  public var downloadConcurrency: Int
  /// Whether to use zstd dictionary compression on the live WebSocket stream.
  public var compression: Bool
  /// Raw API key for Bluesky-hosted metered replay HTTP endpoints
  /// (`Authorization: Bearer <key>`); the live websocket needs no key.
  public var apiKey: String?
  /// Persistent cursor storage for saving and resuming progress.
  public var cursorStorage: (any FirehoseCursorStorage)?
  /// HTTP transport used for XRPC requests and downloads.
  public var transport: any JetstreamHTTPTransport
  /// Factory for creating WebSocket connections.
  public var sessionFactory: any FirehoseWebSocketSessionFactory
  /// Reconnection and retry backoff configuration.
  public var backoff: FirehoseBackoffConfiguration

  public init(
    host: URL,
    mode: JetstreamMode = .snapshotThenLive(),
    filter: JetstreamFilter = .init(),
    batchSize: Int = 64,
    downloadConcurrency: Int = 4,
    compression: Bool = false,
    apiKey: String? = nil,
    cursorStorage: (any FirehoseCursorStorage)? = nil,
    transport: any JetstreamHTTPTransport = URLSessionJetstreamHTTPTransport(),
    sessionFactory: any FirehoseWebSocketSessionFactory = URLSessionFirehoseWebSocketFactory(),
    backoff: FirehoseBackoffConfiguration = .init()
  ) {
    self.host = host
    self.mode = mode
    self.apiKey = apiKey
    self.filter = filter
    self.batchSize = batchSize
    self.downloadConcurrency = downloadConcurrency
    self.compression = compression
    self.cursorStorage = cursorStorage
    self.transport = transport
    self.sessionFactory = sessionFactory
    self.backoff = backoff
  }
}

// MARK: - JetstreamClient

/// High-level Jetstream v2 client orchestrating snapshot backfill, columnar block decoding,
/// and live WebSocket streaming with seamless cutover.
public final class JetstreamClient: Sendable {
  public let configuration: JetstreamClientConfiguration

  public init(configuration: JetstreamClientConfiguration) {
    self.configuration = configuration
  }

  /// Returns an async throwing stream yielding batches of Jetstream events.
  public func events() -> AsyncThrowingStream<JetstreamBatch, Error> {
    AsyncThrowingStream { continuation in
      let runner = JetstreamClientRunner(configuration: configuration)
      let task = Task {
        await runner.run(continuation: continuation)
      }
      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }
}

// MARK: - Internal Runner

private enum WorkUnit: Sendable {
  case segment(name: String, checksum: String)
  case blockRange(segment: String, first: Int, last: Int)
}

private enum DownloadedUnit: Sendable {
  case segmentFile(URL)
  case blockFrames([Data])
}

private struct CompactedSegmentError: Error {}

/// Mutable backfill progress, confined to `JetstreamClientRunner`. A reference
/// type so batching state can be shared across the processing call chain
/// without overlapping `inout` exclusivity.
private final class BackfillState {
  var lastProcessed: Int64
  var currentBatch: [JetstreamEvent] = []

  init(lastProcessed: Int64) {
    self.lastProcessed = lastProcessed
  }
}

private actor JetstreamClientRunner {
  private let configuration: JetstreamClientConfiguration
  private let xrpcClient: JetstreamXRPCClient

  init(configuration: JetstreamClientConfiguration) {
    self.configuration = configuration
    self.xrpcClient = JetstreamXRPCClient(
      host: configuration.host,
      transport: configuration.transport,
      apiKey: configuration.apiKey
    )
  }

  func run(continuation: AsyncThrowingStream<JetstreamBatch, Error>.Continuation) async {
    do {
      switch configuration.mode {
      case let .live(cursor):
        try await runLiveOnly(initialCursor: cursor, continuation: continuation)

      case let .snapshotOnly(afterSeq, beforeSeq):
        _ = try await runSnapshotBackfill(
          initialAfterSeq: afterSeq,
          targetBeforeSeq: beforeSeq,
          isSnapshotOnly: true,
          continuation: continuation
        )
        continuation.finish()

      case let .snapshotThenLive(afterSeq):
        var currentAfterSeq = afterSeq
        var consecutiveZeroProgressCount = 0

        while !Task.isCancelled {
          let (sealedTip, lastProcessed) = try await runSnapshotBackfill(
            initialAfterSeq: currentAfterSeq,
            targetBeforeSeq: nil,
            isSnapshotOnly: false,
            continuation: continuation
          )

          let cutoverCursor = max(sealedTip, lastProcessed)

          do {
            try await runLiveTail(
              cursor: cutoverCursor,
              continuation: continuation
            )
            // Live tail completed normally or was cancelled
            break
          } catch let failure as LiveTailFailure {
            guard case let .connectionRejected(status, errName, _) = failure.underlying,
              errName == "CursorTooOld" || (status == 400 && errName == nil)
            else {
              throw failure.underlying
            }
            // Re-plan from the furthest position actually delivered.
            let resumeSeq = max(failure.lastCursor, lastProcessed)
            // Guard against infinite zero-progress re-planning loops.
            if resumeSeq == currentAfterSeq {
              consecutiveZeroProgressCount += 1
            } else {
              consecutiveZeroProgressCount = 0
            }
            if consecutiveZeroProgressCount >= 2 {
              throw failure.underlying
            }
            currentAfterSeq = resumeSeq
            continue
          }
        }
        continuation.finish()
      }
    } catch {
      if !Task.isCancelled {
        continuation.finish(throwing: error)
      } else {
        continuation.finish()
      }
    }
  }

  // MARK: - Live Only Mode

  private func runLiveOnly(
    initialCursor: Int64?,
    continuation: AsyncThrowingStream<JetstreamBatch, Error>.Continuation
  ) async throws {
    let subConfig = JetstreamSubscriptionConfiguration(
      url: configuration.host,
      filter: configuration.filter,
      cursor: initialCursor,
      compression: configuration.compression,
      cursorStorage: configuration.cursorStorage,
      backoff: configuration.backoff,
      sessionFactory: configuration.sessionFactory,
      httpTransport: configuration.transport
    )

    let subscription = JetstreamSubscription(configuration: subConfig)
    var lastCursor = initialCursor ?? 0

    for try await event in subscription.events() {
      if Task.isCancelled { break }
      switch event {
      case let .event(jetstreamEvent):
        if let seq = jetstreamEvent.seq {
          lastCursor = seq
        }
        // ponytail: per-event live batches; coalesce if throughput demands
        continuation.yield(JetstreamBatch(events: [jetstreamEvent], lastCursor: lastCursor))
      case .streamError:
        // Subscription reconnects automatically; ignore terminal streamError notification
        break
      }
    }
    continuation.finish()
  }

  // MARK: - Live Tail Cutover

  /// Wraps a subscription failure during the live tail, carrying the last
  /// cursor position actually delivered so re-planning resumes from progress.
  private struct LiveTailFailure: Error {
    let lastCursor: Int64
    let underlying: JetstreamSubscriptionError
  }

  private func runLiveTail(
    cursor: Int64,
    continuation: AsyncThrowingStream<JetstreamBatch, Error>.Continuation
  ) async throws {
    let subConfig = JetstreamSubscriptionConfiguration(
      url: configuration.host,
      filter: configuration.filter,
      cursor: cursor,
      compression: configuration.compression,
      cursorStorage: configuration.cursorStorage,
      backoff: configuration.backoff,
      sessionFactory: configuration.sessionFactory,
      httpTransport: configuration.transport
    )

    let subscription = JetstreamSubscription(configuration: subConfig)
    var lastCursor = cursor

    do {
      for try await event in subscription.events() {
        if Task.isCancelled { break }
        switch event {
        case let .event(jetstreamEvent):
          if let seq = jetstreamEvent.seq {
            if seq <= cursor {
              // Drop boundary seq already processed during backfill
              continue
            }
            lastCursor = seq
            // ponytail: per-event live batches; coalesce if throughput demands
            continuation.yield(JetstreamBatch(events: [jetstreamEvent], lastCursor: lastCursor))
            try? await configuration.cursorStorage?.saveCursor(seq)
          } else {
            continuation.yield(JetstreamBatch(events: [jetstreamEvent], lastCursor: lastCursor))
          }
        case .streamError:
          break
        }
      }
    } catch let error as JetstreamSubscriptionError {
      throw LiveTailFailure(lastCursor: lastCursor, underlying: error)
    }
  }

  // MARK: - Snapshot Backfill

  /// Runs archive snapshot backfill. Returns (sealedTipSeq, lastProcessed).
  private func runSnapshotBackfill(
    initialAfterSeq: Int64,
    targetBeforeSeq: Int64?,
    isSnapshotOnly: Bool,
    continuation: AsyncThrowingStream<JetstreamBatch, Error>.Continuation
  ) async throws -> (sealedTip: Int64, lastProcessed: Int64) {
    var currentAfterSeq = initialAfterSeq
    var pinnedS: Int64?
    let state = BackfillState(lastProcessed: initialAfterSeq)

    var replanAttempts = 0
    while !Task.isCancelled {
      let request = SnapshotPlanRequest(
        filter: configuration.filter,
        afterSeq: currentAfterSeq > 0 ? currentAfterSeq : nil,
        beforeSeq: pinnedS ?? targetBeforeSeq
      )

      let plan: SnapshotPlan
      do {
        plan = try await xrpcClient.planSnapshot(request)
      } catch {
        throw error
      }

      if pinnedS == nil {
        if let targetBeforeSeq {
          pinnedS = min(plan.sealedTipSeq, targetBeforeSeq)
        } else {
          pinnedS = plan.sealedTipSeq
        }
      }

      guard let effectiveLimit = pinnedS else {
        break
      }

      // If window is already covered or empty
      if currentAfterSeq >= effectiveLimit {
        break
      }

      // Build ordered work units for this plan page
      var workUnits: [WorkUnit] = []
      for segment in plan.segments {
        if segment.mode == "segment" {
          workUnits.append(.segment(name: segment.name, checksum: segment.checksum))
        } else if segment.mode == "blocks", let blocks = segment.blocks {
          for range in blocks {
            workUnits.append(.blockRange(segment: segment.name, first: range.first, last: range.last))
          }
        }
      }

      // Download and process work units in strict order with bounded concurrency
      do {
        try await processWorkUnits(
          workUnits,
          initialAfterSeq: initialAfterSeq,
          effectiveLimit: effectiveLimit,
          state: state,
          continuation: continuation
        )
      } catch is CompactedSegmentError {
        // Segment was compacted away mid-plan -> re-plan once from lastProcessed
        replanAttempts += 1
        if replanAttempts > 1 && currentAfterSeq == state.lastProcessed {
          throw JetstreamXRPCError(
            status: 404,
            error: "SegmentNotFound",
            message: "Segment compacted away and re-planning made no progress"
          )
        }
        currentAfterSeq = state.lastProcessed
        continue
      }

      currentAfterSeq = plan.plannedThroughSeq
      if plan.plannedThroughSeq >= effectiveLimit {
        break
      }
    }

    await flushBatch(state, continuation: continuation)
    return (pinnedS ?? initialAfterSeq, state.lastProcessed)
  }

  private func flushBatch(
    _ state: BackfillState,
    continuation: AsyncThrowingStream<JetstreamBatch, Error>.Continuation
  ) async {
    guard !state.currentBatch.isEmpty else { return }
    continuation.yield(JetstreamBatch(events: state.currentBatch, lastCursor: state.lastProcessed))
    try? await configuration.cursorStorage?.saveCursor(state.lastProcessed)
    state.currentBatch.removeAll(keepingCapacity: true)
  }

  // MARK: - Work Unit Processing

  private func processWorkUnits(
    _ units: [WorkUnit],
    initialAfterSeq: Int64,
    effectiveLimit: Int64,
    state: BackfillState,
    continuation: AsyncThrowingStream<JetstreamBatch, Error>.Continuation
  ) async throws {
    guard !units.isEmpty else { return }

    let totalUnits = units.count
    let concurrency = max(1, configuration.downloadConcurrency)

    try await withThrowingTaskGroup(of: (Int, DownloadedUnit).self) { group in
      var nextSubmitIndex = 0
      var nextProcessIndex = 0
      var downloadedBuffer: [Int: DownloadedUnit] = [:]

      // Initial window fill
      while nextSubmitIndex < min(concurrency, totalUnits) {
        let index = nextSubmitIndex
        let unit = units[index]
        group.addTask {
          let downloaded = try await self.downloadWorkUnitWithRetry(unit)
          return (index, downloaded)
        }
        nextSubmitIndex += 1
      }

      while let (completedIndex, downloadedUnit) = try await group.next() {
        downloadedBuffer[completedIndex] = downloadedUnit

        // Submit next task if available
        if nextSubmitIndex < totalUnits {
          let index = nextSubmitIndex
          let unit = units[index]
          group.addTask {
            let downloaded = try await self.downloadWorkUnitWithRetry(unit)
            return (index, downloaded)
          }
          nextSubmitIndex += 1
        }

        // Process completed units in strict sequence
        while let nextUnit = downloadedBuffer.removeValue(forKey: nextProcessIndex) {
          try await processDownloadedUnit(
            nextUnit,
            initialAfterSeq: initialAfterSeq,
            effectiveLimit: effectiveLimit,
            state: state,
            continuation: continuation
          )
          // Flush partial batch at each work unit boundary
          await flushBatch(state, continuation: continuation)
          nextProcessIndex += 1
        }
      }
    }
  }

  private func processDownloadedUnit(
    _ unit: DownloadedUnit,
    initialAfterSeq: Int64,
    effectiveLimit: Int64,
    state: BackfillState,
    continuation: AsyncThrowingStream<JetstreamBatch, Error>.Continuation
  ) async throws {
    switch unit {
    case let .segmentFile(fileURL):
      defer {
        try? FileManager.default.removeItem(at: fileURL)
      }
      let reader = try SegmentFileReader(fileURL: fileURL)
      defer {
        reader.close()
      }
      while let blockEvents = try reader.nextBlock() {
        try await processBlockEvents(
          blockEvents,
          initialAfterSeq: initialAfterSeq,
          effectiveLimit: effectiveLimit,
          state: state,
          continuation: continuation
        )
      }

    case let .blockFrames(frames):
      for frame in frames {
        let blockEvents = try SegmentBlockDecoder.decodeFrame(frame)
        try await processBlockEvents(
          blockEvents,
          initialAfterSeq: initialAfterSeq,
          effectiveLimit: effectiveLimit,
          state: state,
          continuation: continuation
        )
      }
    }
  }

  private func processBlockEvents(
    _ events: [SegmentEvent],
    initialAfterSeq: Int64,
    effectiveLimit: Int64,
    state: BackfillState,
    continuation: AsyncThrowingStream<JetstreamBatch, Error>.Continuation
  ) async throws {
    for event in events {
      let seq = event.seq
      // Admission condition: within target window, strictly monotonic, and matches filter
      if seq > initialAfterSeq && seq <= effectiveLimit && seq > state.lastProcessed {
        guard let jetstreamEvent = event.toJetstreamEvent() else {
          continue
        }
        if configuration.filter.matches(jetstreamEvent) {
          state.currentBatch.append(jetstreamEvent)
          state.lastProcessed = seq
          if state.currentBatch.count >= configuration.batchSize {
            await flushBatch(state, continuation: continuation)
          }
        } else {
          // Even if filtered out, advance lastProcessed to maintain monotonic sequence tracking
          state.lastProcessed = seq
        }
      }
    }
  }

  // MARK: - Unit Download with Retry

  private func downloadWorkUnitWithRetry(_ unit: WorkUnit) async throws -> DownloadedUnit {
    var attempts = 0
    var currentDelay: TimeInterval?

    while true {
      attempts += 1
      do {
        switch unit {
        case let .segment(name, _):
          let tempURL = try await xrpcClient.getSegment(name: name)
          return .segmentFile(tempURL)

        case let .blockRange(segment, first, last):
          var frames: [Data] = []
          for blockIndex in first...last {
            let frame = try await xrpcClient.getBlock(segment: segment, blockIndex: blockIndex)
            frames.append(frame)
          }
          return .blockFrames(frames)
        }
      } catch let error as JetstreamXRPCError where error.error == "SegmentNotFound" {
        throw CompactedSegmentError()
      } catch {
        if attempts >= 3 {
          throw error
        }
        let delay = configuration.backoff.nextDelay(after: currentDelay)
        currentDelay = delay
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
    }
  }
}
