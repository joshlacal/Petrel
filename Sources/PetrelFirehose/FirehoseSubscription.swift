import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel

/// Durable storage for the cursor of one event stream.
///
/// The cursor is the sequence number of the last event the application has finished
/// processing. A subscription loads it before every connection attempt and sends it as the
/// `cursor` query parameter.
public protocol FirehoseCursorStorage: Sendable {
  func loadCursor() async throws -> Int64?
  func saveCursor(_ cursor: Int64) async throws
}

public actor InMemoryFirehoseCursorStorage: FirehoseCursorStorage {
  private var cursor: Int64?

  /// - Parameter initialCursor: `nil` starts at the live tip; `0` asks the server for the
  ///   oldest event it still has.
  public init(initialCursor: Int64? = nil) {
    self.cursor = initialCursor
  }

  public func loadCursor() async -> Int64? {
    cursor
  }

  public func saveCursor(_ cursor: Int64) async {
    self.cursor = cursor
  }
}

public struct FirehoseBackoffConfiguration: Sendable, Equatable {
  public var initialDelay: TimeInterval
  public var maxDelay: TimeInterval
  public var multiplier: Double
  /// Random spread applied to each delay, as a fraction of it (`0.25` waits between 75% and
  /// 125% of the computed delay). Keeps a fleet of consumers from reconnecting in lockstep
  /// after a relay restart. `0` disables jitter.
  public var jitter: Double = 0.25

  public init(
    initialDelay: TimeInterval = 0.5,
    maxDelay: TimeInterval = 30.0,
    multiplier: Double = 2.0
  ) {
    self.initialDelay = initialDelay
    self.maxDelay = maxDelay
    self.multiplier = multiplier
  }

  /// The deterministic exponential schedule, before jitter.
  public func nextDelay(after currentDelay: TimeInterval?) -> TimeInterval {
    guard let currentDelay else { return initialDelay }
    return min(maxDelay, currentDelay * multiplier)
  }

  /// Applies ``jitter`` to a delay produced by ``nextDelay(after:)``.
  public func jittered(_ delay: TimeInterval) -> TimeInterval {
    guard jitter > 0, delay > 0 else { return delay }
    let spread = min(jitter, 1)
    return delay * Double.random(in: (1 - spread) ... (1 + spread))
  }
}

public enum FirehoseSubscriptionEvent: Sendable, Equatable {
  /// A decoded `#commit`, `#sync`, `#identity`, `#account` or `#info` message.
  case event(RelayEvent)
  /// The stream skipped from `expected - 1` to `received`. Sequence numbers may legally contain
  /// gaps, so this is informational: the event with sequence `received` follows, and the
  /// stream continues. A consumer that needs every event can treat it as a prompt to resync.
  case sequenceGap(expected: Int64, received: Int64)
  /// A frame that was skipped: unknown `op`, unknown `t` (including the deprecated
  /// `#handle`, `#migrate` and `#tombstone`), or a payload that did not match its schema.
  case ignoredFrame(EventStreamIgnoredFrame)
}

public enum FirehoseSubscriptionError: Error, Sendable, Equatable {
  /// A WebSocket text message arrived on a binary event stream.
  case unsupportedMessageFormat
  case connectionClosed
  /// The server sent the same sequence number twice within one connection.
  case duplicateSequence(Int64)
  /// A sequence number lower than one already seen, or an acknowledgement that would move the
  /// cursor backwards.
  case cursorRegression(expected: Int64, received: Int64)
  /// No longer produced: the stream applies backpressure instead of overflowing.
  case resynchronizationRequired
  case storageFailure
  /// No longer produced: acknowledgements may skip sequence numbers.
  case unacknowledgedSequenceGap
  /// The server answered the WebSocket upgrade with an HTTP error. `429` and `5xx` other than
  /// `501` are retried with backoff (honouring `Retry-After`); anything else ends the stream.
  case upgradeRejected(status: Int, retryAfter: TimeInterval?)
  /// The platform's `URLSession` cannot open WebSockets (Linux with a libcurl built without
  /// WebSocket support). Supply a ``FirehoseWebSocketSessionFactory`` of your own.
  case webSocketTransportUnavailable(String)
  /// The server sent a message larger than the transport's `maximumMessageSize`.
  case frameTooLarge
  /// The transport cannot send messages to the server.
  case sendingUnsupported
}

public struct FirehoseSubscriptionConfiguration: Sendable {
  /// Full subscription URL, for example
  /// `wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos`.
  public var url: URL
  public var cursorStorage: any FirehoseCursorStorage
  public var backoff: FirehoseBackoffConfiguration
  public var sessionFactory: any FirehoseWebSocketSessionFactory
  /// Unused. The stream reads from the socket only when the consumer asks for the next
  /// element, so there is no buffer to bound. Kept for source compatibility.
  public var bufferLimit: Int
  /// When true, the cursor is saved automatically after the consumer has taken an event and
  /// comes back for the next one. When false, call
  /// ``FirehoseSubscription/acknowledge(sequence:)``.
  public var autoAcknowledge: Bool
  /// Whether to reconnect from the cursor after a `ConsumerTooSlow` error frame instead of
  /// ending the stream with `EventStreamError.consumerTooSlow`.
  public var reconnectsOnConsumerTooSlow = false

  public init(
    url: URL,
    cursorStorage: any FirehoseCursorStorage = InMemoryFirehoseCursorStorage(),
    backoff: FirehoseBackoffConfiguration = .init(),
    sessionFactory: any FirehoseWebSocketSessionFactory = URLSessionFirehoseWebSocketFactory(),
    bufferLimit: Int = 1000,
    autoAcknowledge: Bool = false
  ) {
    self.url = url
    self.cursorStorage = cursorStorage
    self.backoff = backoff
    self.sessionFactory = sessionFactory
    self.bufferLimit = bufferLimit
    self.autoAcknowledge = autoAcknowledge
  }

  var pumpConfiguration: EventStreamPumpConfiguration {
    .init(
      url: url,
      cursorStorage: cursorStorage,
      backoff: backoff,
      sessionFactory: sessionFactory,
      autoAcknowledge: autoAcknowledge,
      reconnectsOnConsumerTooSlow: reconnectsOnConsumerTooSlow
    )
  }
}

/// A resilient consumer of `com.atproto.sync.subscribeRepos` (the firehose of a relay or PDS).
///
/// The stream reconnects with exponential backoff and resumes from the cursor. It ends by
/// throwing when continuing would be wrong: an error frame such as `FutureCursor`
/// (`EventStreamError`), invalid framing or CBOR (``RelayVerifierError``), a
/// duplicate or decreasing sequence number, or an upgrade response that must not be retried.
public final class FirehoseSubscription: Sendable {
  public let configuration: FirehoseSubscriptionConfiguration
  private let coordinator: EventStreamCursorCoordinator

  public init(configuration: FirehoseSubscriptionConfiguration) {
    self.configuration = configuration
    self.coordinator = EventStreamCursorCoordinator(storage: configuration.cursorStorage)
  }

  public convenience init(
    url: URL,
    cursorStorage: any FirehoseCursorStorage = InMemoryFirehoseCursorStorage(),
    backoff: FirehoseBackoffConfiguration = .init(),
    sessionFactory: any FirehoseWebSocketSessionFactory = URLSessionFirehoseWebSocketFactory(),
    bufferLimit: Int = 1000,
    autoAcknowledge: Bool = false
  ) {
    self.init(
      configuration: FirehoseSubscriptionConfiguration(
        url: url,
        cursorStorage: cursorStorage,
        backoff: backoff,
        sessionFactory: sessionFactory,
        bufferLimit: bufferLimit,
        autoAcknowledge: autoAcknowledge
      )
    )
  }

  /// Persists `sequence` as the cursor. It must be greater than the stored cursor; it does not
  /// have to be the next integer, because sequence numbers may contain gaps.
  public func acknowledge(sequence: Int64) async throws {
    try await coordinator.acknowledge(sequence: sequence)
  }

  public func acknowledge(_ event: RelayEvent) async throws {
    guard let seq = event.sequence else { return }
    try await acknowledge(sequence: seq)
  }

  public func currentCursor() async -> Int64? {
    await coordinator.currentCursor()
  }

  /// Connects and returns the events as an `AsyncSequence`.
  ///
  /// The stream is pull-based: a frame is read from the socket only when the consumer asks for
  /// the next element, so a slow consumer slows the connection instead of overflowing a
  /// buffer. Cancelling the consuming task, or dropping the stream, closes the socket.
  public func events() -> AsyncThrowingStream<FirehoseSubscriptionEvent, any Error> {
    let pump = EventStreamPump<FirehoseSubscriptionEvent>(
      configuration: configuration.pumpConfiguration,
      coordinator: coordinator,
      decode: Self.step(for:),
      makeGap: { .sequenceGap(expected: $0, received: $1) }
    )
    return pump.makeStream()
  }

  static func step(for data: Data) throws -> EventStreamStep<FirehoseSubscriptionEvent> {
    // Framing and CBOR failures are hard errors that drop the connection.
    let parsed = try RelayFrameDecoder.parse(data)
    let frame: RelayFrame
    do {
      frame = try RelayFrameDecoder.decode(parsed, mode: .lenient)
    } catch let error as RelayVerifierError where parsed.operation == 1 {
      // One event that does not match its schema must not stall the stream: reconnecting at
      // the same cursor would replay it forever. Report it and move on.
      let ignored = EventStreamIgnoredFrame(
        operation: parsed.operation,
        type: parsed.type,
        sequence: parsed.sequence,
        reason: .undecodablePayload(error.rawValue)
      )
      return .deliver(.ignoredFrame(ignored), sequence: parsed.sequence)
    }
    switch frame {
    case let .event(.error(error)):
      return .fail(EventStreamError(name: error.error, message: error.message))
    case let .event(event):
      return .deliver(.event(event), sequence: event.sequence)
    case let .ignored(ignored):
      return .deliver(.ignoredFrame(ignored), sequence: ignored.sequence)
    }
  }
}
