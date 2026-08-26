import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel
import PetrelFirehose

/// Events yielded by a live Jetstream subscription stream.
public enum JetstreamSubscriptionEvent: Sendable {
  case event(JetstreamEvent)
  case streamError(name: String, message: String?)
}

/// Errors thrown by a Jetstream subscription when a connection is rejected.
public enum JetstreamSubscriptionError: Error, Sendable, Equatable {
  case connectionRejected(status: Int, error: String?, message: String?)
}

/// Configuration for connecting to a live Jetstream v2 WebSocket stream.
public struct JetstreamSubscriptionConfiguration: Sendable {
  /// Base host URL (e.g. `https://jetstream.example.com` or `http://localhost:8080`).
  public var url: URL
  /// Predicate filters applied to the stream.
  public var filter: JetstreamFilter
  /// Inclusive resume sequence number. `nil` starts at the live tip.
  public var cursor: Int64?
  /// Whether to negotiate dictionary-based zstd compression on the WebSocket.
  public var compression: Bool
  /// Persistent cursor storage for saving and restoring the last sequence number.
  public var cursorStorage: (any FirehoseCursorStorage)?
  /// Reconnection backoff strategy.
  public var backoff: FirehoseBackoffConfiguration
  /// Factory for creating WebSocket sessions.
  public var sessionFactory: any FirehoseWebSocketSessionFactory
  /// HTTP transport used for dictionary fetching and error probe classification.
  public var httpTransport: any JetstreamHTTPTransport

  public init(
    url: URL,
    filter: JetstreamFilter = .init(),
    cursor: Int64? = nil,
    compression: Bool = false,
    cursorStorage: (any FirehoseCursorStorage)? = nil,
    backoff: FirehoseBackoffConfiguration = .init(),
    sessionFactory: any FirehoseWebSocketSessionFactory = URLSessionFirehoseWebSocketFactory(),
    httpTransport: any JetstreamHTTPTransport = URLSessionJetstreamHTTPTransport()
  ) {
    self.url = url
    self.filter = filter
    self.cursor = cursor
    self.compression = compression
    self.cursorStorage = cursorStorage
    self.backoff = backoff
    self.sessionFactory = sessionFactory
    self.httpTransport = httpTransport
  }
}

/// Manages a live WebSocket subscription to a Jetstream v2 service.
public final class JetstreamSubscription: Sendable {
  public let configuration: JetstreamSubscriptionConfiguration

  public init(configuration: JetstreamSubscriptionConfiguration) {
    self.configuration = configuration
  }

  /// Start streaming events from the Jetstream service.
  public func events() -> AsyncThrowingStream<JetstreamSubscriptionEvent, Error> {
    AsyncThrowingStream { continuation in
      let runner = JetstreamSubscriptionRunner(configuration: configuration)
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

private actor JetstreamSubscriptionRunner {
  private let configuration: JetstreamSubscriptionConfiguration
  private var activeSession: (any FirehoseWebSocketSession)?
  private var dictionaryDecoder: JetstreamZstdDictionaryDecoder?
  private var cachedDictID: UInt32?

  init(configuration: JetstreamSubscriptionConfiguration) {
    self.configuration = configuration
  }

  func stop() async {
    await activeSession?.close()
    activeSession = nil
  }

  private func setActiveSession(_ session: (any FirehoseWebSocketSession)?) {
    self.activeSession = session
  }

  func run(continuation: AsyncThrowingStream<JetstreamSubscriptionEvent, Error>.Continuation) async {
    var currentDelay: TimeInterval?
    var lastSeq: Int64?
    var hasProcessedEvents = false
    var hasRetriedUnknownDictionary = false

    // Load initial cursor if not explicitly configured
    var initialCursor = configuration.cursor
    if initialCursor == nil, let storage = configuration.cursorStorage {
      initialCursor = try? await storage.loadCursor()
    }
    if let initialCursor {
      lastSeq = initialCursor - 1
    }

    while !Task.isCancelled {
      // 1. Prepare dictionary if compression is enabled
      if configuration.compression && dictionaryDecoder == nil {
        do {
          let (dictData, dictID) = try await loadDictionary()
          self.dictionaryDecoder = try JetstreamZstdDictionaryDecoder(dictionary: dictData)
          self.cachedDictID = dictID
        } catch {
          if Task.isCancelled { break }
          let delay = configuration.backoff.nextDelay(after: currentDelay)
          currentDelay = delay
          try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
          continue
        }
      }

      // 2. Determine wire connect cursor
      let connectCursor: Int64?
      if hasProcessedEvents, let lastSeq {
        connectCursor = lastSeq
      } else {
        connectCursor = initialCursor
      }

      guard let connectURL = Self.buildWebSocketURL(
        baseURL: configuration.url,
        filter: configuration.filter,
        cursor: connectCursor,
        zstdDictionaryID: configuration.compression ? cachedDictID : nil
      ) else {
        continuation.finish(throwing: JetstreamSubscriptionError.connectionRejected(
          status: 0,
          error: "InvalidRequest",
          message: "Failed to construct connect URL"
        ))
        return
      }

      var receivedFramesCount = 0

      do {
        let session = try await configuration.sessionFactory.makeSession(url: connectURL)
        setActiveSession(session)

        sessionLoop: while !Task.isCancelled {
          let rawData: Data
          do {
            rawData = try await session.receiveMessage()
          } catch {
            if receivedFramesCount == 0 {
              if await probeClassification(
                connectURL: connectURL,
                continuation: continuation,
                hasRetriedUnknownDictionary: &hasRetriedUnknownDictionary
              ) {
                return
              }
            }
            break sessionLoop
          }

          receivedFramesCount += 1
          hasRetriedUnknownDictionary = false
          currentDelay = nil

          guard !rawData.isEmpty else { continue }

          let frameData: Data
          do {
            if rawData.first == 0x7B {
              frameData = rawData
            } else if let decoder = dictionaryDecoder {
              frameData = try decoder.decompress(rawData)
            } else {
              frameData = (try? JetstreamZstd.decompress(rawData)) ?? rawData
            }
          } catch {
            break sessionLoop
          }

          let wireFrame: JetstreamWireFrame
          do {
            wireFrame = try JetstreamWire.decodeFrame(frameData)
          } catch {
            continue
          }

          switch wireFrame {
          case .skipped:
            continue

          case let .error(name, message):
            continuation.yield(.streamError(name: name, message: message))
            break sessionLoop

          case let .message(event):
            if let seq = event.seq {
              if let last = lastSeq, seq <= last {
                // Drop duplicate / already-seen sequence number
                continue
              }
              lastSeq = seq
              hasProcessedEvents = true
              try? await configuration.cursorStorage?.saveCursor(seq)
            }
            if configuration.filter.matches(event) {
              continuation.yield(.event(event))
            }
          }
        }
      } catch {
        if receivedFramesCount == 0 {
          if await probeClassification(
            connectURL: connectURL,
            continuation: continuation,
            hasRetriedUnknownDictionary: &hasRetriedUnknownDictionary
          ) {
            return
          }
        }
      }

      await stop()
      if Task.isCancelled { break }
      let delay = configuration.backoff.nextDelay(after: currentDelay)
      currentDelay = delay
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    await stop()
    continuation.finish()
  }

  private func probeClassification(
    connectURL: URL,
    continuation: AsyncThrowingStream<JetstreamSubscriptionEvent, Error>.Continuation,
    hasRetriedUnknownDictionary: inout Bool
  ) async -> Bool {
    guard let probeURL = Self.httpProbeURL(from: connectURL) else {
      return false
    }
    do {
      var probeRequest = URLRequest(url: probeURL)
      probeRequest.httpMethod = "GET"
      let (probeData, probeResponse) = try await configuration.httpTransport.data(for: probeRequest)
      let status = probeResponse.statusCode
      if status >= 400 {
        var errorName: String?
        var errorMessage: String?
        if let json = try? JSONSerialization.jsonObject(with: probeData) as? [String: Any] {
          errorName = json["error"] as? String
          errorMessage = json["message"] as? String
        }

        if let err = errorName, ["CursorTooOld", "UnknownZstdDictionary", "InvalidRequest"].contains(err) {
          if err == "UnknownZstdDictionary" && !hasRetriedUnknownDictionary {
            hasRetriedUnknownDictionary = true
            self.dictionaryDecoder = nil
            self.cachedDictID = nil
            return false
          }
          await stop()
          continuation.finish(throwing: JetstreamSubscriptionError.connectionRejected(
            status: status,
            error: errorName,
            message: errorMessage
          ))
          return true
        } else if (400...499).contains(status) {
          await stop()
          continuation.finish(throwing: JetstreamSubscriptionError.connectionRejected(
            status: status,
            error: nil,
            message: nil
          ))
          return true
        }
      }
    } catch {
      // Probe request failed -> treat as transient
    }
    return false
  }

  private func loadDictionary(id: UInt32? = nil) async throws -> (data: Data, id: UInt32?) {
    guard let url = Self.dictionaryURL(baseURL: configuration.url, id: id) else {
      throw JetstreamZstdError.dictionaryLoadFailed
    }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    let (data, response) = try await configuration.httpTransport.data(for: request)
    guard response.statusCode == 200 else {
      throw JetstreamZstdError.dictionaryLoadFailed
    }
    let dictID = JetstreamZstd.dictionaryID(of: data) ?? id
    return (data, dictID)
  }

  static func buildWebSocketURL(
    baseURL: URL,
    filter: JetstreamFilter,
    cursor: Int64?,
    zstdDictionaryID: UInt32?
  ) -> URL? {
    guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      return nil
    }
    if components.scheme == "https" {
      components.scheme = "wss"
    } else if components.scheme == "http" {
      components.scheme = "ws"
    }

    let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let xrpcPath = "xrpc/network.bsky.jetstream.subscribeEvents"
    components.path = basePath.isEmpty ? "/" + xrpcPath : "/" + basePath + "/" + xrpcPath

    var queryItems: [URLQueryItem] = []
    for kind in filter.kinds {
      queryItems.append(URLQueryItem(name: "kinds", value: kind.rawValue))
    }
    for did in filter.dids {
      queryItems.append(URLQueryItem(name: "dids", value: did))
    }
    for collection in filter.collections {
      queryItems.append(URLQueryItem(name: "collections", value: collection))
    }
    if let cursor {
      queryItems.append(URLQueryItem(name: "cursor", value: String(cursor)))
    }
    if let zstdDictionaryID {
      queryItems.append(URLQueryItem(name: "zstdDictionary", value: String(zstdDictionaryID)))
    }

    components.queryItems = queryItems.isEmpty ? nil : queryItems
    return components.url
  }

  static func httpProbeURL(from wsURL: URL) -> URL? {
    guard var components = URLComponents(url: wsURL, resolvingAgainstBaseURL: false) else {
      return nil
    }
    if components.scheme == "wss" {
      components.scheme = "https"
    } else if components.scheme == "ws" {
      components.scheme = "http"
    }
    return components.url
  }

  static func dictionaryURL(baseURL: URL, id: UInt32?) -> URL? {
    guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      return nil
    }
    if components.scheme == "wss" {
      components.scheme = "https"
    } else if components.scheme == "ws" {
      components.scheme = "http"
    }
    let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let xrpcPath = "xrpc/network.bsky.jetstream.getZstdDictionary"
    components.path = basePath.isEmpty ? "/" + xrpcPath : "/" + basePath + "/" + xrpcPath
    if let id {
      components.queryItems = [URLQueryItem(name: "id", value: String(id))]
    } else {
      components.queryItems = nil
    }
    return components.url
  }
}
