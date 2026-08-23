import Foundation
import Petrel

public protocol FirehoseCursorStorage: Sendable {
  func loadCursor() async throws -> Int64?
  func saveCursor(_ cursor: Int64) async throws
}

public actor InMemoryFirehoseCursorStorage: FirehoseCursorStorage {
  private var cursor: Int64?

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

  public init(
    initialDelay: TimeInterval = 0.5,
    maxDelay: TimeInterval = 30.0,
    multiplier: Double = 2.0
  ) {
    self.initialDelay = initialDelay
    self.maxDelay = maxDelay
    self.multiplier = multiplier
  }

  public func nextDelay(after currentDelay: TimeInterval?) -> TimeInterval {
    guard let currentDelay else { return initialDelay }
    return min(maxDelay, currentDelay * multiplier)
  }
}

public enum FirehoseSubscriptionEvent: Sendable, Equatable {
  case event(RelayEvent)
  case sequenceGap(expected: Int64, received: Int64)
}

public protocol FirehoseWebSocketSession: Sendable {
  func receiveMessage() async throws -> Data
  func close() async
}

public protocol FirehoseWebSocketSessionFactory: Sendable {
  func makeSession(url: URL) async throws -> any FirehoseWebSocketSession
}

public final class URLSessionFirehoseWebSocketSession: FirehoseWebSocketSession, @unchecked Sendable {
  private let task: URLSessionWebSocketTask

  public init(task: URLSessionWebSocketTask) {
    self.task = task
    self.task.resume()
  }

  public func receiveMessage() async throws -> Data {
    let message = try await task.receive()
    switch message {
    case let .data(data):
      return data
    case let .string(text):
      return Data(text.utf8)
    @unknown default:
      throw FirehoseSubscriptionError.unsupportedMessageFormat
    }
  }

  public func close() async {
    task.cancel(with: .normalClosure, reason: nil)
  }
}

public struct URLSessionFirehoseWebSocketFactory: FirehoseWebSocketSessionFactory {
  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public func makeSession(url: URL) async throws -> any FirehoseWebSocketSession {
    let task = session.webSocketTask(with: url)
    return URLSessionFirehoseWebSocketSession(task: task)
  }
}

public enum FirehoseSubscriptionError: Error, Sendable, Equatable {
  case unsupportedMessageFormat
  case connectionClosed
}

public struct FirehoseSubscriptionConfiguration: Sendable {
  public var url: URL
  public var cursorStorage: any FirehoseCursorStorage
  public var backoff: FirehoseBackoffConfiguration
  public var sessionFactory: any FirehoseWebSocketSessionFactory

  public init(
    url: URL,
    cursorStorage: any FirehoseCursorStorage = InMemoryFirehoseCursorStorage(),
    backoff: FirehoseBackoffConfiguration = .init(),
    sessionFactory: any FirehoseWebSocketSessionFactory = URLSessionFirehoseWebSocketFactory()
  ) {
    self.url = url
    self.cursorStorage = cursorStorage
    self.backoff = backoff
    self.sessionFactory = sessionFactory
  }
}

public final class FirehoseSubscription: Sendable {
  public let configuration: FirehoseSubscriptionConfiguration

  public init(configuration: FirehoseSubscriptionConfiguration) {
    self.configuration = configuration
  }

  public init(
    url: URL,
    cursorStorage: any FirehoseCursorStorage = InMemoryFirehoseCursorStorage(),
    backoff: FirehoseBackoffConfiguration = .init(),
    sessionFactory: any FirehoseWebSocketSessionFactory = URLSessionFirehoseWebSocketFactory()
  ) {
    self.configuration = FirehoseSubscriptionConfiguration(
      url: url,
      cursorStorage: cursorStorage,
      backoff: backoff,
      sessionFactory: sessionFactory
    )
  }

  public func events() -> AsyncStream<FirehoseSubscriptionEvent> {
    AsyncStream { continuation in
      let runner = FirehoseSubscriptionRunner(configuration: configuration)
      let task = Task {
        await runner.run(continuation: continuation)
      }
      continuation.onTermination = { _ in
        task.cancel()
        Task {
          await runner.stop()
        }
      }
    }
  }
}

private actor FirehoseSubscriptionRunner {
  private let configuration: FirehoseSubscriptionConfiguration
  private var activeSession: (any FirehoseWebSocketSession)?

  init(configuration: FirehoseSubscriptionConfiguration) {
    self.configuration = configuration
  }

  func stop() async {
    await activeSession?.close()
    activeSession = nil
  }

  private func setActiveSession(_ session: (any FirehoseWebSocketSession)?) {
    self.activeSession = session
  }

  func run(continuation: AsyncStream<FirehoseSubscriptionEvent>.Continuation) async {
    var currentDelay: TimeInterval?
    var lastSequence: Int64?

    while !Task.isCancelled {
      let cursor = try? await configuration.cursorStorage.loadCursor()
      if lastSequence == nil, let cursor {
        lastSequence = cursor
      }
      let connectURL = Self.urlWithCursor(configuration.url, cursor: cursor)

      do {
        let session = try await configuration.sessionFactory.makeSession(url: connectURL)
        setActiveSession(session)

        while !Task.isCancelled {
          let data = try await session.receiveMessage()
          currentDelay = nil

          let event = try RelayFrameDecoder.decode(data)
          if let seq = event.sequence {
            if let last = lastSequence, seq > last + 1 {
              continuation.yield(.sequenceGap(expected: last + 1, received: seq))
            }
            lastSequence = seq
            try? await configuration.cursorStorage.saveCursor(seq)
          }
          continuation.yield(.event(event))
        }
      } catch {
        await stop()
        if Task.isCancelled { break }
        let delay = configuration.backoff.nextDelay(after: currentDelay)
        currentDelay = delay
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
    }
    await stop()
    continuation.finish()
  }

  private static func urlWithCursor(_ baseURL: URL, cursor: Int64?) -> URL {
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
