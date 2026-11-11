import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel

/// What the pump needs to know about one decoded frame.
struct EventStreamStep<Output: Sendable>: Sendable {
  /// Element to hand to the consumer; `nil` when the frame produces none.
  var output: Output?
  /// Sequence number the frame carries, if any.
  var sequence: Int64?
  /// Set for an error frame (`op: -1`).
  var error: EventStreamError?

  static func deliver(_ output: Output, sequence: Int64?) -> Self {
    .init(output: output, sequence: sequence, error: nil)
  }

  static func fail(_ error: EventStreamError) -> Self {
    .init(output: nil, sequence: nil, error: error)
  }
}

struct EventStreamPumpConfiguration: Sendable {
  var url: URL
  var cursorStorage: any FirehoseCursorStorage
  var backoff: FirehoseBackoffConfiguration
  var sessionFactory: any FirehoseWebSocketSessionFactory
  var autoAcknowledge: Bool
  var reconnectsOnConsumerTooSlow: Bool
}

/// Persists the acknowledged cursor for one subscription and keeps it monotonic.
actor EventStreamCursorCoordinator {
  private let storage: any FirehoseCursorStorage
  private var lastPersistedCursor: Int64?

  init(storage: any FirehoseCursorStorage) {
    self.storage = storage
  }

  func initializeCursor(_ cursor: Int64?) {
    if lastPersistedCursor == nil {
      lastPersistedCursor = cursor
    }
  }

  /// Sequence numbers may contain arbitrary gaps, so any greater value is accepted.
  func acknowledge(sequence: Int64) async throws {
    if let last = lastPersistedCursor {
      guard sequence > last else {
        throw FirehoseSubscriptionError.cursorRegression(expected: last + 1, received: sequence)
      }
    }
    try await save(sequence)
  }

  /// Used by automatic acknowledgement, where a stale sequence is not an error.
  func advance(to sequence: Int64) async throws {
    if let last = lastPersistedCursor, sequence <= last { return }
    try await save(sequence)
  }

  private func save(_ sequence: Int64) async throws {
    do {
      try await storage.saveCursor(sequence)
      lastPersistedCursor = sequence
    } catch {
      throw FirehoseSubscriptionError.storageFailure
    }
  }

  func currentCursor() -> Int64? {
    lastPersistedCursor
  }
}

/// The only reference a stream holds to its pump. `AsyncThrowingStream(unfolding:)` releases
/// its closure, and with it this handle, when the consuming task is cancelled (also between
/// reads) or the stream is dropped.
final class EventStreamPumpHandle<Output: Sendable>: Sendable {
  private let pump: EventStreamPump<Output>

  init(_ pump: EventStreamPump<Output>) {
    self.pump = pump
  }

  func next() async throws -> Output? {
    try await pump.next()
  }

  deinit {
    let pump = pump
    Task { await pump.terminate() }
  }
}

/// Pull-based event-stream consumer shared by every subscription type in this module.
///
/// Each call to ``next()`` reads at most as many frames from the socket as it takes to produce
/// one element, so a slow consumer slows the socket instead of filling a buffer. The pump owns
/// reconnection with backoff, cursor resume, duplicate/regression checks, sequence-gap
/// reporting and error-frame handling; the `decode` closure owns the wire format.
actor EventStreamPump<Output: Sendable> {
  private let configuration: EventStreamPumpConfiguration
  private let coordinator: EventStreamCursorCoordinator
  private let decode: @Sendable (Data) throws -> EventStreamStep<Output>
  private let makeGap: @Sendable (_ expected: Int64, _ received: Int64) -> Output

  private var session: (any FirehoseWebSocketSession)?
  /// Decoded frames not yet handed out. An entry without `output` is a skipped frame that
  /// only moves the cursor.
  private var pending: [(output: Output?, sequence: Int64?)] = []
  /// Highest sequence seen on the wire, or the cursor the connection resumed from.
  private var watermark: Int64?
  /// Sequence of the last element handed out; persisted once the consumer asks for more.
  private var unacknowledged: Int64?
  private var awaitingFirstSequence = true
  private var currentDelay: TimeInterval?
  private var pendingDelay: TimeInterval?
  private var finished = false

  init(
    configuration: EventStreamPumpConfiguration,
    coordinator: EventStreamCursorCoordinator,
    decode: @escaping @Sendable (Data) throws -> EventStreamStep<Output>,
    makeGap: @escaping @Sendable (_ expected: Int64, _ received: Int64) -> Output
  ) {
    self.configuration = configuration
    self.coordinator = coordinator
    self.decode = decode
    self.makeGap = makeGap
  }

  deinit {
    // The consumer dropped the stream without cancelling: release the socket.
    if let session {
      Task { await session.close() }
    }
  }

  /// The pull-based stream over this pump. The stream owns a handle whose release, when the
  /// consumer is cancelled or drops the stream, closes the socket even if something else still
  /// holds the pump.
  nonisolated func makeStream() -> AsyncThrowingStream<Output, any Error> {
    let handle = EventStreamPumpHandle(self)
    return AsyncThrowingStream(unfolding: { try await handle.next() })
  }

  /// Ends the stream and closes the socket.
  func terminate() async {
    await finish()
  }

  func next() async throws -> Output? {
    if finished { return nil }
    do {
      // The consumer coming back for more is the signal that everything handed out so far
      // was processed; only now may the cursor move past it.
      if let sequence = unacknowledged {
        unacknowledged = nil
        try await autoAcknowledge(sequence)
      }
      while true {
        while !pending.isEmpty {
          let entry = pending.removeFirst()
          guard let output = entry.output else {
            // A skipped frame: everything before it was processed, so the cursor may pass it.
            if let sequence = entry.sequence {
              try await autoAcknowledge(sequence)
            }
            continue
          }
          unacknowledged = entry.sequence
          return output
        }
        if Task.isCancelled {
          await finish()
          return nil
        }
        if let delay = pendingDelay {
          pendingDelay = nil
          try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        let data: Data
        do {
          let session = try await connectIfNeeded()
          data = try await receive(from: session)
        } catch {
          await closeSession()
          if Task.isCancelled || error is CancellationError {
            await finish()
            return nil
          }
          guard let delay = retryDelay(after: error) else {
            throw error
          }
          pendingDelay = delay
          continue
        }
        currentDelay = nil
        // Decode and sequence failures are never retried: reconnecting at the same cursor
        // would replay the same frame.
        try await handle(data)
      }
    } catch {
      let cancelled = Task.isCancelled || error is CancellationError
      await finish()
      if cancelled { return nil }
      throw error
    }
  }

  private func autoAcknowledge(_ sequence: Int64) async throws {
    guard configuration.autoAcknowledge else { return }
    try await coordinator.advance(to: sequence)
  }

  private func finish() async {
    finished = true
    pending.removeAll()
    await closeSession()
  }

  private func closeSession() async {
    guard let current = session else { return }
    session = nil
    await current.close()
  }

  private func connectIfNeeded() async throws -> any FirehoseWebSocketSession {
    if let session { return session }
    let persisted: Int64?
    do {
      persisted = try await configuration.cursorStorage.loadCursor()
    } catch {
      throw FirehoseSubscriptionError.storageFailure
    }
    await coordinator.initializeCursor(persisted)
    // Resume from the acknowledged cursor (at-least-once). Without one, resume from the last
    // sequence seen in this process so a reconnect does not silently skip events.
    let resume = persisted ?? watermark
    watermark = resume
    awaitingFirstSequence = true
    let url = Self.urlWithCursor(configuration.url, cursor: resume)
    let opened = try await configuration.sessionFactory.makeSession(url: url)
    if Task.isCancelled {
      await opened.close()
      throw CancellationError()
    }
    session = opened
    return opened
  }

  private func receive(from session: any FirehoseWebSocketSession) async throws -> Data {
    try await withTaskCancellationHandler {
      try await session.receiveMessage()
    } onCancel: {
      Task { await session.close() }
    }
  }

  private func handle(_ data: Data) async throws {
    let step = try decode(data)
    if let error = step.error {
      // "Streams should be closed immediately following … receiving an error frame."
      await closeSession()
      if case .consumerTooSlow = error, configuration.reconnectsOnConsumerTooSlow {
        pendingDelay = nextBackoff()
        return
      }
      throw error
    }
    if let sequence = step.sequence {
      try FirehoseFrameLimits.validateSequence(sequence)
      if let last = watermark {
        if sequence == last, awaitingFirstSequence {
          // Cursor resume is inclusive ("greater-or-equal"): the event at the cursor was
          // already processed, so the replayed copy is dropped.
          awaitingFirstSequence = false
          return
        }
        if sequence == last {
          throw FirehoseSubscriptionError.duplicateSequence(sequence)
        }
        if sequence < last {
          throw FirehoseSubscriptionError.cursorRegression(expected: last + 1, received: sequence)
        }
        // Gaps are legal ("may contain arbitrary gaps"), so they are reported, not fatal.
        // Cursor 0 asks for the oldest available event, so the first one is never a gap.
        if sequence > last + 1, last != 0 {
          pending.append((makeGap(last + 1, sequence), nil))
        }
      }
      awaitingFirstSequence = false
      watermark = sequence
    }
    if step.output != nil || step.sequence != nil {
      pending.append((step.output, step.sequence))
    }
  }

  private func nextBackoff() -> TimeInterval {
    let delay = configuration.backoff.nextDelay(after: currentDelay)
    currentDelay = delay
    return configuration.backoff.jittered(delay)
  }

  /// Returns the delay before the next connection attempt, or `nil` when `error` is terminal.
  private func retryDelay(after error: any Error) -> TimeInterval? {
    switch error {
    case FirehoseSubscriptionError.connectionClosed:
      return nextBackoff()
    case let FirehoseSubscriptionError.upgradeRejected(status, retryAfter):
      // Event-stream spec: 429 and 5xx are retried after a delay, 501 is not; other 4xx
      // responses mean the request itself is wrong.
      guard status == 429 || (status >= 500 && status != 501) else { return nil }
      return max(nextBackoff(), retryAfter ?? 0)
    case is URLError,
         NetworkError.requestFailed:
      return nextBackoff()
    case is FirehoseSubscriptionError,
         is FirehoseFrameEncoderError,
         is EventStreamError,
         is RelayVerifierError,
         is NetworkError,
         is DecodingError:
      return nil
    default:
      return nextBackoff()
    }
  }

  static func urlWithCursor(_ baseURL: URL, cursor: Int64?) -> URL {
    guard let cursor else { return baseURL }
    guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      return baseURL
    }
    var items = components.queryItems ?? []
    items.removeAll(where: { $0.name == "cursor" })
    items.append(URLQueryItem(name: "cursor", value: String(cursor)))
    components.queryItems = items
    return components.url ?? baseURL
  }
}
