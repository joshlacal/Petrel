import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
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

/// URLSession is internally thread-safe/reference-safe, but Swift FoundationNetworking 6.1 lacks Sendable annotation on Linux.
public struct URLSessionFirehoseWebSocketFactory: FirehoseWebSocketSessionFactory, @unchecked Sendable {
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
  case duplicateSequence(Int64)
  case cursorRegression(expected: Int64, received: Int64)
  case resynchronizationRequired
  case storageFailure
  case unacknowledgedSequenceGap
}

public struct FirehoseSubscriptionConfiguration: Sendable {
  public var url: URL
  public var cursorStorage: any FirehoseCursorStorage
  public var backoff: FirehoseBackoffConfiguration
  public var sessionFactory: any FirehoseWebSocketSessionFactory
  public var bufferLimit: Int
  public var autoAcknowledge: Bool

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
}

private actor FirehoseSubscriptionCoordinator {
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

  func acknowledge(sequence: Int64) async throws {
    if let last = lastPersistedCursor {
      guard sequence > last else {
        throw FirehoseSubscriptionError.cursorRegression(expected: last + 1, received: sequence)
      }
      guard sequence == last + 1 else {
        throw FirehoseSubscriptionError.unacknowledgedSequenceGap
      }
    }
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

public final class FirehoseSubscription: Sendable {
  public let configuration: FirehoseSubscriptionConfiguration
  private let coordinator: FirehoseSubscriptionCoordinator

  public init(configuration: FirehoseSubscriptionConfiguration) {
    self.configuration = configuration
    self.coordinator = FirehoseSubscriptionCoordinator(storage: configuration.cursorStorage)
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

  public func events() -> AsyncThrowingStream<FirehoseSubscriptionEvent, any Error> {
    AsyncThrowingStream(bufferingPolicy: .bufferingOldest(configuration.bufferLimit)) { continuation in
      let runner = FirehoseSubscriptionRunner(configuration: configuration, coordinator: coordinator)
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
  private let coordinator: FirehoseSubscriptionCoordinator
  private var activeSession: (any FirehoseWebSocketSession)?

  init(
    configuration: FirehoseSubscriptionConfiguration,
    coordinator: FirehoseSubscriptionCoordinator
  ) {
    self.configuration = configuration
    self.coordinator = coordinator
  }

  func stop() async {
    await activeSession?.close()
    activeSession = nil
  }

  private func setActiveSession(_ session: (any FirehoseWebSocketSession)?) {
    self.activeSession = session
  }

  func run(continuation: AsyncThrowingStream<FirehoseSubscriptionEvent, any Error>.Continuation) async {
    var currentDelay: TimeInterval?
    var lastDeliveredSequence: Int64?

    while !Task.isCancelled {
      let cursor: Int64?
      do {
        cursor = try await configuration.cursorStorage.loadCursor()
      } catch {
        continuation.finish(throwing: FirehoseSubscriptionError.storageFailure)
        return
      }

      await coordinator.initializeCursor(cursor)
      lastDeliveredSequence = cursor
      let connectURL = Self.urlWithCursor(configuration.url, cursor: cursor)

      do {
        let session = try await configuration.sessionFactory.makeSession(url: connectURL)
        setActiveSession(session)

        while !Task.isCancelled {
          let data = try await session.receiveMessage()
          currentDelay = nil

          let event = try RelayFrameDecoder.decode(data)
          if let seq = event.sequence {
            try FirehoseFrameLimits.validateSequence(seq)
            if let last = lastDeliveredSequence {
              if seq == last {
                await stop()
                continuation.finish(throwing: FirehoseSubscriptionError.duplicateSequence(seq))
                return
              }
              if seq < last {
                await stop()
                continuation.finish(throwing: FirehoseSubscriptionError.cursorRegression(expected: last + 1, received: seq))
                return
              }
              if seq > last + 1 {
                let gapResult = continuation.yield(.sequenceGap(expected: last + 1, received: seq))
                await stop()
                if case .terminated = gapResult {
                  return
                }
                continuation.finish(throwing: FirehoseSubscriptionError.resynchronizationRequired)
                return
              }
            }
            lastDeliveredSequence = seq
            if configuration.autoAcknowledge {
              try await coordinator.acknowledge(sequence: seq)
            }
          }

          let eventResult = continuation.yield(.event(event))
          switch eventResult {
          case .enqueued:
            break
          case .dropped:
            await stop()
            continuation.finish(throwing: FirehoseSubscriptionError.resynchronizationRequired)
            return
          case .terminated:
            await stop()
            return
          @unknown default:
            break
          }
        }
      } catch {
        await stop()
        if Task.isCancelled { break }
        switch error {
        case FirehoseSubscriptionError.duplicateSequence,
             FirehoseSubscriptionError.cursorRegression,
             FirehoseSubscriptionError.resynchronizationRequired,
             FirehoseSubscriptionError.storageFailure,
             FirehoseSubscriptionError.unacknowledgedSequenceGap:
          continuation.finish(throwing: error)
          return
        default:
          break
        }
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
