import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel

/// One open WebSocket connection, as seen by the event-stream consumers.
///
/// This is the transport seam of `PetrelFirehose` and `PetrelJetstream`. The package ships a
/// `URLSession` implementation (``URLSessionFirehoseWebSocketSession``). On Linux,
/// `URLSessionWebSocketTask` only works when the system libcurl was built with WebSocket
/// support, which the Swift 6.1 Ubuntu 22.04 and 24.04 images are not; there, supply your own
/// conformance backed by a WebSocket client of your choice.
public protocol FirehoseWebSocketSession: Sendable {
  /// Waits for the next message and returns its payload.
  ///
  /// The consumer calls this once per element it hands out, so a transport that reads from the
  /// socket only when asked gives the stream end-to-end backpressure.
  func receiveMessage() async throws -> Data
  /// Closes the connection. Must make a pending ``receiveMessage()`` return or throw.
  func close() async
  /// Sends a text message to the server. Only Jetstream's `options_update` uses this.
  func sendText(_ text: String) async throws
}

public extension FirehoseWebSocketSession {
  /// Default for transports that are receive-only.
  func sendText(_: String) async throws {
    throw FirehoseSubscriptionError.sendingUnsupported
  }
}

/// Opens WebSocket connections for the event-stream consumers.
public protocol FirehoseWebSocketSessionFactory: Sendable {
  /// Opens a connection to `url` (`wss://`, or `ws://` for loopback hosts).
  func makeSession(url: URL) async throws -> any FirehoseWebSocketSession
  /// Opens a connection to `url`, offering `subprotocols` in `Sec-WebSocket-Protocol`.
  func makeSession(url: URL, subprotocols: [String]) async throws -> any FirehoseWebSocketSession
}

public extension FirehoseWebSocketSessionFactory {
  /// Default for transports without subprotocol negotiation: the offer is dropped.
  func makeSession(url: URL, subprotocols _: [String]) async throws -> any FirehoseWebSocketSession {
    try await makeSession(url: url)
  }
}

/// Settings of the `URLSession` WebSocket transport.
public struct FirehoseWebSocketOptions: Sendable, Equatable {
  /// What to do with a WebSocket text message.
  public enum TextFrameHandling: Sendable, Equatable {
    /// Fail with ``FirehoseSubscriptionError/unsupportedMessageFormat``. Event streams with
    /// CBOR framing are binary-only.
    case reject
    /// Deliver the UTF-8 bytes of the text. Jetstream sends JSON as text messages unless
    /// compression is negotiated.
    case utf8Data
  }

  /// Largest message the transport accepts. `URLSessionWebSocketTask` defaults to 1 MiB,
  /// which is below the 5 MB frame limit of the sync specification.
  public var maximumMessageSize: Int
  /// How text messages are handled.
  public var textFrames: TextFrameHandling
  /// Extra HTTP headers for the upgrade request, for endpoints that require authentication.
  public var additionalHeaders: [String: String]
  /// Interval between keep-alive pings; `nil` disables them. A ping that is not answered by
  /// the next interval closes the connection so the consumer reconnects.
  public var pingInterval: TimeInterval?

  /// Creates transport options. The defaults suit CBOR event streams.
  public init(
    maximumMessageSize: Int = FirehoseFrameLimits.maximumFrameBytes,
    textFrames: TextFrameHandling = .reject,
    additionalHeaders: [String: String] = [:],
    pingInterval: TimeInterval? = 30
  ) {
    self.maximumMessageSize = maximumMessageSize
    self.textFrames = textFrames
    self.additionalHeaders = additionalHeaders
    self.pingInterval = pingInterval
  }

  /// Options for Jetstream: JSON arrives as text messages.
  public static let jetstream = FirehoseWebSocketOptions(textFrames: .utf8Data)
}

/// `URLSessionWebSocketTask` is internally thread-safe, but FoundationNetworking does not
/// annotate it as Sendable on Linux.
private struct WebSocketTaskBox: @unchecked Sendable {
  let task: URLSessionWebSocketTask
}

private final class PongTracker: @unchecked Sendable {
  private let lock = NSLock()
  private var awaitingPong = false

  /// Marks a ping as sent. Returns false when the previous ping is still unanswered.
  func beginPing() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    if awaitingPong { return false }
    awaitingPong = true
    return true
  }

  func pongReceived() {
    lock.lock()
    awaitingPong = false
    lock.unlock()
  }
}

public final class URLSessionFirehoseWebSocketSession: FirehoseWebSocketSession, @unchecked Sendable {
  private let task: URLSessionWebSocketTask
  private let delegate: HardenedURLSessionDelegate?
  private let textFrames: FirehoseWebSocketOptions.TextFrameHandling
  private let keepAlive: Task<Void, Never>?

  public convenience init(task: URLSessionWebSocketTask) {
    self.init(task: task, delegate: nil, options: FirehoseWebSocketOptions(pingInterval: nil))
  }

  package convenience init(task: URLSessionWebSocketTask, delegate: HardenedURLSessionDelegate?) {
    self.init(task: task, delegate: delegate, options: FirehoseWebSocketOptions(pingInterval: nil))
  }

  package init(
    task: URLSessionWebSocketTask,
    delegate: HardenedURLSessionDelegate?,
    options: FirehoseWebSocketOptions
  ) {
    self.task = task
    self.delegate = delegate
    self.textFrames = options.textFrames
    task.maximumMessageSize = options.maximumMessageSize
    task.resume()
    if let interval = options.pingInterval, interval > 0 {
      self.keepAlive = Self.startKeepAlive(WebSocketTaskBox(task: task), interval: interval)
    } else {
      self.keepAlive = nil
    }
  }

  deinit {
    keepAlive?.cancel()
  }

  /// Pings on an interval. Besides keeping idle streams (labelers, small PDS firehoses,
  /// narrowly filtered Jetstream) from being reaped by intermediaries, an unanswered ping is
  /// the only way to notice a peer that vanished without closing the connection.
  private static func startKeepAlive(_ box: WebSocketTaskBox, interval: TimeInterval) -> Task<Void, Never> {
    let tracker = PongTracker()
    return Task.detached {
      while !Task.isCancelled {
        do {
          try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        } catch {
          return
        }
        guard box.task.state == .running else { return }
        guard tracker.beginPing() else {
          box.task.cancel(with: .goingAway, reason: nil)
          return
        }
        box.task.sendPing { error in
          if error == nil {
            tracker.pongReceived()
          }
        }
      }
    }
  }

  public func receiveMessage() async throws -> Data {
    do {
      let message = try await task.receive()
      switch message {
      case let .data(data):
        return data
      case let .string(text):
        guard textFrames == .utf8Data else {
          throw FirehoseSubscriptionError.unsupportedMessageFormat
        }
        return Data(text.utf8)
      @unknown default:
        throw FirehoseSubscriptionError.unsupportedMessageFormat
      }
    } catch let error as FirehoseSubscriptionError {
      throw error
    } catch {
      if let delegate {
        if delegate.contextManager.isSecurityViolation(for: task) {
          delegate.contextManager.pruneCompletedTask(task)
          throw NetworkError.securityViolation
        }
        if delegate.contextManager.isLimitExceeded(for: task) {
          delegate.contextManager.pruneCompletedTask(task)
          throw NetworkError.responseLimitExceeded("Response limit exceeded")
        }
        delegate.contextManager.pruneCompletedTask(task)
      }
      throw Self.classify(error, response: task.response)
    }
  }

  /// Turns transport failures the consumer must not blindly retry into typed errors.
  static func classify(_ error: any Error, response: URLResponse?) -> any Error {
    if let http = response as? HTTPURLResponse, http.statusCode != 101 {
      var retryAfter: TimeInterval?
      if let value = http.value(forHTTPHeaderField: "Retry-After"),
         let seconds = TimeInterval(value.trimmingCharacters(in: .whitespaces)),
         seconds >= 0 {
        retryAfter = seconds
      }
      return FirehoseSubscriptionError.upgradeRejected(status: http.statusCode, retryAfter: retryAfter)
    }
    if let urlError = error as? URLError, urlError.code == .unsupportedURL {
      // swift-corelibs-foundation reports "WebSockets not supported by libcurl" this way.
      return FirehoseSubscriptionError.webSocketTransportUnavailable(urlError.localizedDescription)
    }
    let nsError = error as NSError
    if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(EMSGSIZE) {
      return FirehoseSubscriptionError.frameTooLarge
    }
    return error
  }

  public func sendText(_ text: String) async throws {
    try await task.send(.string(text))
  }

  public func close() async {
    keepAlive?.cancel()
    task.cancel(with: .normalClosure, reason: nil)
  }
}

/// URLSession is internally thread-safe/reference-safe, but Swift FoundationNetworking 6.1 lacks Sendable annotation on Linux.
public struct URLSessionFirehoseWebSocketFactory: FirehoseWebSocketSessionFactory, @unchecked Sendable {
  private let session: URLSession
  private let delegate: HardenedURLSessionDelegate?
  /// Transport settings applied to every connection this factory opens.
  public var options: FirehoseWebSocketOptions

  public init() {
    self.init(options: FirehoseWebSocketOptions())
  }

  public init(session: URLSession) {
    self.session = session
    self.delegate = session.delegate as? HardenedURLSessionDelegate
    self.options = FirehoseWebSocketOptions()
  }

  public init(limits: NetworkResponseLimits) {
    self.init(options: FirehoseWebSocketOptions(), limits: limits)
  }

  /// Creates a factory with explicit transport settings.
  public init(options: FirehoseWebSocketOptions, limits: NetworkResponseLimits = .default) {
    let delegate = HardenedURLSessionDelegate(allowsRedirects: false, limits: limits)
    let config = URLSessionConfiguration.ephemeral
    // URLSession applies the request timeout to WebSocket tasks as an idle-receive timeout.
    // A quiet stream is healthy, so liveness is left to the keep-alive ping.
    config.timeoutIntervalForRequest = Self.idleTimeout
    self.delegate = delegate
    self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    self.options = options
  }

  static let idleTimeout: TimeInterval = 600

  public func makeSession(url: URL) async throws -> any FirehoseWebSocketSession {
    try await makeSession(url: url, subprotocols: [])
  }

  public func makeSession(url: URL, subprotocols: [String]) async throws -> any FirehoseWebSocketSession {
    if !(try await NetworkService.validateURL(url)) {
      throw NetworkError.securityViolation
    }
    var request = URLRequest(url: url)
    for (name, value) in options.additionalHeaders {
      request.setValue(value, forHTTPHeaderField: name)
    }
    if !subprotocols.isEmpty {
      request.setValue(subprotocols.joined(separator: ", "), forHTTPHeaderField: "Sec-WebSocket-Protocol")
    }
    let task = session.webSocketTask(with: request)
    let host = url.host?.lowercased() ?? ""
    let isLocal = host == "localhost" || host == "127.0.0.1" || host == "::1"
    if let delegate {
      let addresses = try await NetworkService.resolveApprovedAddresses(host: host, isLocal: isLocal)
      delegate.contextManager.setApprovedAddresses(addresses, for: task)
    }
    return URLSessionFirehoseWebSocketSession(task: task, delegate: delegate, options: options)
  }
}
