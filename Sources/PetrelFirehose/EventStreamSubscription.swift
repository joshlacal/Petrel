import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel

/// An element of an ``EventStreamSubscription``.
public enum EventStreamEvent<Message: Sendable>: Sendable {
  /// A decoded message and its sequence number, if the message type is sequenced.
  case message(Message, sequence: Int64?)
  /// The stream skipped from `expected - 1` to `received`; informational, the stream continues.
  case sequenceGap(expected: Int64, received: Int64)
  /// A frame that was skipped: unknown `op`, or a payload `Message` could not decode (which
  /// includes message types the lexicon gained after `Message` was generated).
  case ignoredFrame(EventStreamIgnoredFrame)
}

/// A resilient consumer for any Lexicon `subscription` endpoint, decoding into a generated
/// message union such as `ComAtprotoLabelSubscribeLabels.Message`.
///
/// It shares its connection handling with ``FirehoseSubscription``: reconnect with backoff,
/// cursor resume, sequence checks, keep-alive pings, and pull-based backpressure.
///
/// ```swift
/// let labels = EventStreamSubscription.labels(service: URL(string: "https://mod.bsky.app")!)
/// for try await event in labels.events() {
///   if case let .message(.labels(batch), _) = event { … }
/// }
/// ```
public final class EventStreamSubscription<Message: Decodable & Sendable>: Sendable {
  /// Connection settings. `url` is the full `wss://…/xrpc/<nsid>` URL.
  public let configuration: FirehoseSubscriptionConfiguration
  /// The subscription's Lexicon NSID, used to expand `#fragment` message types.
  public let nsid: String
  private let coordinator: EventStreamCursorCoordinator

  /// Creates a consumer for the subscription `nsid`.
  public init(nsid: String, configuration: FirehoseSubscriptionConfiguration) {
    self.nsid = nsid
    self.configuration = configuration
    self.coordinator = EventStreamCursorCoordinator(storage: configuration.cursorStorage)
  }

  /// Persists `sequence` as the cursor. It must be greater than the stored cursor.
  public func acknowledge(sequence: Int64) async throws {
    try await coordinator.acknowledge(sequence: sequence)
  }

  /// The last acknowledged cursor.
  public func currentCursor() async -> Int64? {
    await coordinator.currentCursor()
  }

  /// Connects and returns the messages as a pull-based `AsyncSequence`.
  public func events() -> AsyncThrowingStream<EventStreamEvent<Message>, any Error> {
    let nsid = nsid
    let pump = EventStreamPump<EventStreamEvent<Message>>(
      configuration: configuration.pumpConfiguration,
      coordinator: coordinator,
      decode: { try Self.step(for: $0, nsid: nsid) },
      makeGap: { .sequenceGap(expected: $0, received: $1) }
    )
    return pump.makeStream()
  }

  static func step(for data: Data, nsid: String) throws -> EventStreamStep<EventStreamEvent<Message>> {
    switch try ATProtoWebSocketFrameDecoder.decode(data, defaultLexicon: nsid) {
    case let .error(error):
      return .fail(error)
    case let .unknownOperation(operation):
      let ignored = EventStreamIgnoredFrame(
        operation: operation, type: nil, sequence: nil, reason: .unknownOperation
      )
      return .deliver(.ignoredFrame(ignored), sequence: nil)
    case let .message(frame):
      do {
        let message = try JSONCoders.decode(Message.self, from: frame.jsonData)
        return .deliver(.message(message, sequence: frame.sequence), sequence: frame.sequence)
      } catch {
        let ignored = EventStreamIgnoredFrame(
          operation: 1,
          type: frame.messageType,
          sequence: frame.sequence,
          reason: .undecodablePayload(String(describing: error))
        )
        return .deliver(.ignoredFrame(ignored), sequence: frame.sequence)
      }
    }
  }
}

/// A consumer of `com.atproto.label.subscribeLabels`, the label stream of a labeler service.
public typealias LabelSubscription = EventStreamSubscription<ComAtprotoLabelSubscribeLabels.Message>

public extension EventStreamSubscription where Message == ComAtprotoLabelSubscribeLabels.Message {
  /// Creates a label stream consumer for a labeler.
  ///
  /// - Parameters:
  ///   - service: The labeler's service endpoint (the `#atproto_labeler` entry of its DID
  ///     document), for example `https://mod.bsky.app`. `https` and `http` are mapped to
  ///     `wss` and `ws`.
  ///   - cursorStorage: Where the cursor is kept. An initial cursor of `0` replays every label
  ///     the labeler still has.
  ///   - backoff: Reconnection delays.
  ///   - sessionFactory: The WebSocket transport.
  ///   - autoAcknowledge: Whether the cursor is saved automatically once the consumer has
  ///     processed an element.
  static func labels(
    service: URL,
    cursorStorage: any FirehoseCursorStorage = InMemoryFirehoseCursorStorage(),
    backoff: FirehoseBackoffConfiguration = .init(),
    sessionFactory: any FirehoseWebSocketSessionFactory = URLSessionFirehoseWebSocketFactory(),
    autoAcknowledge: Bool = false
  ) -> LabelSubscription {
    let nsid = "com.atproto.label.subscribeLabels"
    return LabelSubscription(
      nsid: nsid,
      configuration: FirehoseSubscriptionConfiguration(
        url: FirehoseEndpoint.subscriptionURL(service: service, nsid: nsid),
        cursorStorage: cursorStorage,
        backoff: backoff,
        sessionFactory: sessionFactory,
        autoAcknowledge: autoAcknowledge
      )
    )
  }
}

public extension FirehoseSubscription {
  /// Creates a firehose consumer for a relay or PDS given its service endpoint, for example
  /// `https://bsky.network`. `https` and `http` are mapped to `wss` and `ws`.
  convenience init(
    service: URL,
    cursorStorage: any FirehoseCursorStorage = InMemoryFirehoseCursorStorage(),
    autoAcknowledge: Bool = false
  ) {
    self.init(
      url: FirehoseEndpoint.subscriptionURL(service: service, nsid: "com.atproto.sync.subscribeRepos"),
      cursorStorage: cursorStorage,
      autoAcknowledge: autoAcknowledge
    )
  }
}

enum FirehoseEndpoint {
  /// `https://host[/base]` → `wss://host[/base]/xrpc/<nsid>`.
  static func subscriptionURL(service: URL, nsid: String) -> URL {
    guard var components = URLComponents(url: service, resolvingAgainstBaseURL: false) else {
      return service
    }
    switch components.scheme?.lowercased() {
    case "https": components.scheme = "wss"
    case "http": components.scheme = "ws"
    default: break
    }
    let base = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    components.path = (base.isEmpty ? "" : "/" + base) + "/xrpc/" + nsid
    return components.url ?? service
  }
}
