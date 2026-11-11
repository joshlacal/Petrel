import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import Petrel
import PetrelFirehose

/// Events yielded by a live Jetstream subscription stream.
public enum JetstreamSubscriptionEvent: Sendable {
  case event(JetstreamEvent)
  /// The server sent an error frame. The stream then ends by throwing the matching
  /// `EventStreamError`, unless the error is `ConsumerTooSlow` and
  /// ``JetstreamSubscriptionConfiguration/reconnectsOnConsumerTooSlow`` is set.
  case streamError(name: String, message: String?)
}

/// Errors thrown by a Jetstream subscription when a connection is rejected.
public enum JetstreamSubscriptionError: Error, Sendable, Equatable {
  case connectionRejected(status: Int, error: String?, message: String?)
  /// `compression` was requested on the legacy `/subscribe` API without
  /// ``JetstreamSubscriptionConfiguration/legacyZstdDictionary``.
  case missingZstdDictionary
  /// ``JetstreamSubscription/updateOptions(_:)`` was called on a subscription that does not
  /// use the legacy `/subscribe` API, the only one with `options_update`.
  case optionsUpdateUnsupported
}

/// The two Jetstream WebSocket dialects.
public enum JetstreamAPIVersion: Sendable, Equatable {
  /// `/xrpc/network.bsky.jetstream.subscribeEvents`: sequence-number cursors, `kinds` filter,
  /// `{"$type":"message","payload":…}` envelopes, optional `zstdDictionary`.
  case v2
  /// The original `/subscribe` endpoint: `wantedCollections` / `wantedDids`, `time_us`
  /// cursors, `{"did","time_us","kind",…}` events, `compress`, `requireHello` and
  /// `options_update`.
  case v1
}

/// A subscriber-sourced `options_update` message of the legacy `/subscribe` API. It replaces
/// the filters of a live connection without reconnecting.
public struct JetstreamOptionsUpdate: Sendable, Equatable {
  /// Collection NSIDs or `prefix.*` wildcards; empty means all collections.
  public var wantedCollections: [String]
  /// Repo DIDs; empty means all repos.
  public var wantedDids: [String]
  /// Largest event payload the server should send; `0` means no limit.
  public var maxMessageSizeBytes: Int

  /// Creates an options update. The defaults subscribe to everything.
  public init(
    wantedCollections: [String] = [],
    wantedDids: [String] = [],
    maxMessageSizeBytes: Int = 0
  ) {
    self.wantedCollections = wantedCollections
    self.wantedDids = wantedDids
    self.maxMessageSizeBytes = maxMessageSizeBytes
  }

  /// The JSON text message sent to the server.
  func encoded() throws -> String {
    let object: [String: Any] = [
      "type": "options_update",
      "payload": [
        "wantedCollections": wantedCollections,
        "wantedDids": wantedDids,
        "maxMessageSizeBytes": maxMessageSizeBytes,
      ] as [String: Any],
    ]
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return String(decoding: data, as: UTF8.self)
  }
}

/// Configuration for connecting to a live Jetstream WebSocket stream.
public struct JetstreamSubscriptionConfiguration: Sendable {
  /// Base host URL (e.g. `https://jetstream.example.com` or `http://localhost:8080`), or the
  /// full legacy endpoint (`wss://jetstream.example.com/subscribe`).
  public var url: URL
  /// Predicate filters applied to the stream.
  public var filter: JetstreamFilter
  /// Inclusive resume position. `nil` starts at the live tip. A sequence number on the v2 API;
  /// a unix-microsecond timestamp (`time_us`) on the legacy API.
  public var cursor: Int64?
  /// Whether to negotiate dictionary-based zstd compression on the WebSocket.
  public var compression: Bool
  /// Persistent cursor storage for saving and restoring the last position.
  public var cursorStorage: (any FirehoseCursorStorage)?
  /// Reconnection backoff strategy.
  public var backoff: FirehoseBackoffConfiguration
  /// Factory for creating WebSocket sessions. Jetstream sends JSON as WebSocket text messages
  /// unless compression is on, so the transport must deliver text
  /// (`FirehoseWebSocketOptions.jetstream`).
  public var sessionFactory: any FirehoseWebSocketSessionFactory
  /// HTTP transport used for dictionary fetching and error probe classification.
  public var httpTransport: any JetstreamHTTPTransport
  /// Which dialect to speak. `nil` picks ``JetstreamAPIVersion/v1`` when the path of `url`
  /// ends in `/subscribe` and ``JetstreamAPIVersion/v2`` otherwise.
  public var apiVersion: JetstreamAPIVersion?
  /// Legacy API only: `maxMessageSizeBytes` connect parameter.
  public var maxMessageSizeBytes: Int?
  /// Legacy API only: connect with `requireHello=true` and send the filters as the first
  /// `options_update`, which keeps long DID lists out of the URL.
  public var requireHello = false
  /// Legacy API only: the zstd dictionary published in the Jetstream repository
  /// (`pkg/models/zstd_dictionary`). Required for `compression` on that API, which has no
  /// endpoint to fetch it from.
  public var legacyZstdDictionary: Data?
  /// Whether to reconnect from the cursor after a `ConsumerTooSlow` error frame instead of
  /// ending the stream.
  public var reconnectsOnConsumerTooSlow = false

  public init(
    url: URL,
    filter: JetstreamFilter = .init(),
    cursor: Int64? = nil,
    compression: Bool = false,
    cursorStorage: (any FirehoseCursorStorage)? = nil,
    backoff: FirehoseBackoffConfiguration = .init(),
    sessionFactory: any FirehoseWebSocketSessionFactory = URLSessionFirehoseWebSocketFactory(options: .jetstream),
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

  /// The dialect this configuration resolves to.
  public var resolvedAPIVersion: JetstreamAPIVersion {
    if let apiVersion { return apiVersion }
    let lastComponent = url.path.split(separator: "/").last
    return lastComponent == "subscribe" ? .v1 : .v2
  }
}

/// Filters that can change while connected (legacy `options_update`), plus the open sockets
/// to send the change to.
actor JetstreamLiveOptions {
  private(set) var filter: JetstreamFilter
  private(set) var maxMessageSizeBytes: Int?
  private var sessions: [ObjectIdentifier: any FirehoseWebSocketSession] = [:]
  /// Incremented by every ``apply(_:)``; a broadcast that is no longer the latest stops.
  private var version = 0
  /// Set while a broadcast or catch-up send is in flight. Sends happen one at a time, so
  /// every connection receives updates in the order they were applied.
  private var sending = false
  private var sendWaiters: [CheckedContinuation<Void, Never>] = []

  init(filter: JetstreamFilter, maxMessageSizeBytes: Int?) {
    self.filter = filter
    self.maxMessageSizeBytes = maxMessageSizeBytes
  }

  /// The filters and the `options_update` equivalent of them, read in one step so a
  /// connection URL never mixes old and new values.
  var snapshot: (filter: JetstreamFilter, maxMessageSizeBytes: Int?, update: JetstreamOptionsUpdate) {
    (filter, maxMessageSizeBytes, currentUpdate)
  }

  /// Adds an open connection to the set that ``apply(_:)`` updates.
  ///
  /// When the options changed while the connection was being opened (or it carries none),
  /// sends it the current ones, in order with any broadcast. Updates applied after this call
  /// reach the connection through ``apply(_:)``.
  ///
  /// - Parameter sent: The options the connection already carries (its URL query), or `nil`
  ///   when it carries none (`requireHello`).
  func register(
    _ session: any FirehoseWebSocketSession,
    id: ObjectIdentifier,
    connectedWith sent: JetstreamOptionsUpdate?
  ) async throws {
    sessions[id] = session
    guard currentUpdate != sent else { return }
    await acquireSending()
    defer { releaseSending() }
    // Read after acquiring: a broadcast that ran meanwhile may have changed the options.
    try await session.sendText(try currentUpdate.encoded())
  }

  func unregister(id: ObjectIdentifier) {
    sessions[id] = nil
  }

  /// Number of registered connections.
  var sessionCount: Int { sessions.count }

  var currentUpdate: JetstreamOptionsUpdate {
    .init(
      wantedCollections: filter.collections,
      wantedDids: filter.dids,
      maxMessageSizeBytes: maxMessageSizeBytes ?? 0
    )
  }

  /// Replaces the options and sends them to every registered connection.
  ///
  /// Broadcasts never interleave: a broadcast waits for the one in flight, and a broadcast
  /// superseded by a newer ``apply(_:)`` while waiting or sending stops, because the newer
  /// one sends the latest options to every connection.
  func apply(_ update: JetstreamOptionsUpdate) async throws {
    let text = try update.encoded()
    filter.collections = update.wantedCollections
    filter.dids = update.wantedDids
    maxMessageSizeBytes = update.maxMessageSizeBytes
    version += 1
    let myVersion = version
    await acquireSending()
    defer { releaseSending() }
    for session in sessions.values {
      guard version == myVersion else { return }
      try await session.sendText(text)
    }
  }

  private func acquireSending() async {
    while sending {
      await withCheckedContinuation { sendWaiters.append($0) }
    }
    sending = true
  }

  private func releaseSending() {
    sending = false
    let waiters = sendWaiters
    sendWaiters.removeAll()
    for waiter in waiters {
      waiter.resume()
    }
  }
}

/// Manages a live WebSocket subscription to a Jetstream service.
///
/// The stream reconnects with backoff and resumes from the last delivered position. It is
/// pull-based: a frame is read from the socket only when the consumer asks for the next
/// element. Cancelling the consuming task, or dropping the stream, closes the socket.
public final class JetstreamSubscription: Sendable {
  public let configuration: JetstreamSubscriptionConfiguration
  let liveOptions: JetstreamLiveOptions

  public init(configuration: JetstreamSubscriptionConfiguration) {
    self.configuration = configuration
    self.liveOptions = JetstreamLiveOptions(
      filter: configuration.filter,
      maxMessageSizeBytes: configuration.maxMessageSizeBytes
    )
  }

  /// Start streaming events from the Jetstream service.
  public func events() -> AsyncThrowingStream<JetstreamSubscriptionEvent, Error> {
    JetstreamSubscriptionRunner(configuration: configuration, liveOptions: liveOptions).makeStream()
  }

  /// Legacy `/subscribe` API: replaces the collection and DID filters of every open stream of
  /// this subscription by sending `options_update`, and uses them for later reconnects.
  ///
  /// - Throws: ``JetstreamSubscriptionError/optionsUpdateUnsupported`` on the v2 API.
  public func updateOptions(_ update: JetstreamOptionsUpdate) async throws {
    guard configuration.resolvedAPIVersion == .v1 else {
      throw JetstreamSubscriptionError.optionsUpdateUnsupported
    }
    try await liveOptions.apply(update)
  }
}

/// The only reference a stream holds to its runner. `AsyncThrowingStream(unfolding:)` releases
/// its closure, and with it this handle, when the consuming task is cancelled (also between
/// reads) or the stream is dropped.
final class JetstreamRunnerHandle: Sendable {
  private let runner: JetstreamSubscriptionRunner

  init(_ runner: JetstreamSubscriptionRunner) {
    self.runner = runner
  }

  func next() async throws -> JetstreamSubscriptionEvent? {
    try await runner.next()
  }

  deinit {
    let runner = runner
    Task { await runner.terminate() }
  }
}

actor JetstreamSubscriptionRunner {
  private let configuration: JetstreamSubscriptionConfiguration
  private let liveOptions: JetstreamLiveOptions
  private let apiVersion: JetstreamAPIVersion

  private var activeSession: (any FirehoseWebSocketSession)?
  private var dictionaryDecoder: JetstreamZstdDictionaryDecoder?
  private var cachedDictID: UInt32?

  private var currentDelay: TimeInterval?
  private var pendingDelay: TimeInterval?
  private var lastSeq: Int64?
  /// Legacy API: identities of the events seen at `lastSeq`. `time_us` is a timestamp, not an
  /// event identifier, and the server replays from the cursor inclusively, so an event at the
  /// resume timestamp is a duplicate only when it was already seen.
  private var legacyEventsAtLastSeq: Set<String> = []
  private var hasProcessedEvents = false
  private var hasRetriedUnknownDictionary = false
  private var initialCursor: Int64?
  private var loadedInitialCursor = false
  private var receivedFramesCount = 0
  private var connectURL: URL?

  /// Decoded frames not yet handed out. An entry without `event` only moves the cursor.
  private var pending: [(event: JetstreamSubscriptionEvent?, seq: Int64?)] = []
  /// Position of the last element handed out; saved once the consumer asks for more.
  private var unsavedCursor: Int64?
  private var terminalError: (any Error)?
  private var finished = false

  init(configuration: JetstreamSubscriptionConfiguration, liveOptions: JetstreamLiveOptions) {
    self.configuration = configuration
    self.liveOptions = liveOptions
    self.apiVersion = configuration.resolvedAPIVersion
  }

  deinit {
    // The consumer dropped the stream without cancelling: release the socket.
    if let activeSession {
      let liveOptions = liveOptions
      let id = ObjectIdentifier(self)
      Task {
        await liveOptions.unregister(id: id)
        await activeSession.close()
      }
    }
  }

  private var sessionID: ObjectIdentifier { ObjectIdentifier(self) }

  private func closeSession() async {
    guard let session = activeSession else { return }
    activeSession = nil
    await liveOptions.unregister(id: sessionID)
    await session.close()
  }

  private func finish() async {
    finished = true
    pending.removeAll()
    await closeSession()
  }

  private func saveCursor(_ seq: Int64) async {
    try? await configuration.cursorStorage?.saveCursor(seq)
  }

  /// The pull-based stream over this runner. The stream owns a handle whose release, when the
  /// consumer is cancelled or drops the stream, closes the socket even if something else still
  /// holds the runner.
  nonisolated func makeStream() -> AsyncThrowingStream<JetstreamSubscriptionEvent, any Error> {
    let handle = JetstreamRunnerHandle(self)
    return AsyncThrowingStream(unfolding: { try await handle.next() })
  }

  /// Ends the stream and closes the socket.
  func terminate() async {
    await finish()
  }

  func next() async throws -> JetstreamSubscriptionEvent? {
    if finished { return nil }
    // The consumer coming back for more means the previous element was processed.
    if let seq = unsavedCursor {
      unsavedCursor = nil
      await saveCursor(seq)
    }

    while true {
      while !pending.isEmpty {
        let entry = pending.removeFirst()
        guard let event = entry.event else {
          if let seq = entry.seq { await saveCursor(seq) }
          continue
        }
        unsavedCursor = entry.seq
        return event
      }
      if let terminalError {
        await finish()
        throw terminalError
      }
      if Task.isCancelled {
        await finish()
        return nil
      }
      if let delay = pendingDelay {
        pendingDelay = nil
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        continue
      }
      await step()
    }
  }

  private func scheduleRetry() {
    let delay = configuration.backoff.nextDelay(after: currentDelay)
    currentDelay = delay
    pendingDelay = configuration.backoff.jittered(delay)
  }

  /// One unit of work: connect if needed, then read and decode one frame.
  private func step() async {
    if !loadedInitialCursor {
      loadedInitialCursor = true
      initialCursor = configuration.cursor
      if initialCursor == nil, let storage = configuration.cursorStorage {
        initialCursor = try? await storage.loadCursor()
      }
      // A v2 cursor is a sequence number and the server replays from it inclusively, so
      // anything below it is a duplicate. A unix-microsecond cursor on the v2 API is not
      // comparable with sequence numbers and must not seed the duplicate filter.
      if let initialCursor, apiVersion == .v1 || initialCursor < Self.timestampCursorFloor {
        lastSeq = initialCursor - 1
      }
    }

    let session: any FirehoseWebSocketSession
    if let activeSession {
      session = activeSession
    } else {
      guard let opened = await connect() else { return }
      session = opened
    }

    let rawData: Data
    do {
      rawData = try await withTaskCancellationHandler {
        try await session.receiveMessage()
      } onCancel: {
        Task { await session.close() }
      }
    } catch {
      await connectionFailed(error)
      return
    }

    receivedFramesCount += 1
    hasRetriedUnknownDictionary = false
    currentDelay = nil

    guard !rawData.isEmpty else { return }

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
      await closeSession()
      scheduleRetry()
      return
    }

    let wireFrame: JetstreamWireFrame
    do {
      wireFrame = try apiVersion == .v1
        ? JetstreamWire.decodeLegacyFrame(frameData)
        : JetstreamWire.decodeFrame(frameData)
    } catch {
      return
    }

    switch wireFrame {
    case .skipped:
      return

    case let .error(name, message):
      // Streams are closed right after an error frame.
      await closeSession()
      pending.append((.streamError(name: name, message: message), nil))
      let error = EventStreamError(name: name, message: message)
      if case .consumerTooSlow = error, configuration.reconnectsOnConsumerTooSlow {
        scheduleRetry()
      } else {
        terminalError = error
      }

    case let .message(event):
      if let seq = event.seq {
        switch apiVersion {
        case .v2:
          // Sequence numbers are unique: anything at or below the last one was already seen.
          if let last = lastSeq, seq <= last { return }
        case .v1:
          let key = Self.legacyEventKey(event)
          if let last = lastSeq {
            if seq < last { return }
            if seq == last {
              guard legacyEventsAtLastSeq.insert(key).inserted else { return }
            } else {
              legacyEventsAtLastSeq = [key]
            }
          } else {
            legacyEventsAtLastSeq = [key]
          }
        }
        lastSeq = seq
        hasProcessedEvents = true
      }
      let filter = await liveOptions.filter
      if filter.matches(event) {
        pending.append((.event(event), event.seq))
      } else if event.seq != nil {
        pending.append((nil, event.seq))
      }
    }
  }

  /// Opens a connection. Returns `nil` after scheduling a retry or recording a terminal error.
  private func connect() async -> (any FirehoseWebSocketSession)? {
    if configuration.compression, dictionaryDecoder == nil {
      do {
        if apiVersion == .v1 {
          guard let dictionary = configuration.legacyZstdDictionary else {
            terminalError = JetstreamSubscriptionError.missingZstdDictionary
            return nil
          }
          dictionaryDecoder = try JetstreamZstdDictionaryDecoder(dictionary: dictionary)
        } else {
          let (dictData, dictID) = try await loadDictionary()
          dictionaryDecoder = try JetstreamZstdDictionaryDecoder(dictionary: dictData)
          cachedDictID = dictID
        }
      } catch {
        scheduleRetry()
        return nil
      }
    }

    let connectCursor: Int64?
    if hasProcessedEvents, let lastSeq {
      connectCursor = lastSeq
    } else {
      connectCursor = initialCursor
    }

    let options = await liveOptions.snapshot
    let filter = options.filter
    let url: URL?
    switch apiVersion {
    case .v2:
      url = Self.buildWebSocketURL(
        baseURL: configuration.url,
        filter: filter,
        cursor: connectCursor,
        zstdDictionaryID: configuration.compression ? cachedDictID : nil
      )
    case .v1:
      url = Self.buildLegacyWebSocketURL(
        baseURL: configuration.url,
        filter: configuration.requireHello ? JetstreamFilter() : filter,
        cursor: connectCursor,
        compress: configuration.compression,
        maxMessageSizeBytes: options.maxMessageSizeBytes,
        requireHello: configuration.requireHello
      )
    }
    guard let url else {
      terminalError = JetstreamSubscriptionError.connectionRejected(
        status: 0,
        error: "InvalidRequest",
        message: "Failed to construct connect URL"
      )
      return nil
    }
    connectURL = url
    receivedFramesCount = 0

    do {
      // Proposal 0015 names the JSON encoding of the v2 API `xrpc.v1.json`.
      let session = try await configuration.sessionFactory.makeSession(
        url: url,
        subprotocols: apiVersion == .v2 ? ["xrpc.v1.json"] : []
      )
      if Task.isCancelled {
        await session.close()
        return nil
      }
      activeSession = session
      // `options_update` sent while the connection was being opened found no session to
      // reach, and the URL (or, with `requireHello`, nothing) carries the options from
      // before it: send whatever the connection is still missing.
      try await liveOptions.register(
        session,
        id: sessionID,
        // v2 has no options_update; its options never change, so nothing is ever sent.
        connectedWith: apiVersion == .v1 && configuration.requireHello ? nil : options.update
      )
      return session
    } catch {
      await connectionFailed(error)
      return nil
    }
  }

  /// Handles a failed connect or receive: classify, then retry or end the stream.
  private func connectionFailed(_ error: any Error) async {
    await closeSession()
    if Task.isCancelled { return }
    switch error {
    case let FirehoseSubscriptionError.upgradeRejected(status, retryAfter):
      if status == 429 || (status >= 500 && status != 501) {
        scheduleRetry()
        if let retryAfter, let delay = pendingDelay {
          pendingDelay = max(delay, retryAfter)
        }
        return
      }
    case FirehoseSubscriptionError.connectionClosed:
      break
    case is FirehoseSubscriptionError:
      // Transport misconfiguration (text frames rejected, no WebSocket support, oversized
      // message): retrying cannot help.
      terminalError = error
      return
    default:
      break
    }
    if receivedFramesCount == 0, let connectURL {
      if let rejection = await probeClassification(connectURL: connectURL, upgradeError: error) {
        terminalError = rejection
        return
      }
    }
    scheduleRetry()
  }

  /// Asks the endpoint over plain HTTP why the WebSocket upgrade failed. Jetstream validates
  /// the query before upgrading, so a parameter error comes back as a `400` with details, while
  /// a healthy endpoint answers `426 Upgrade Required`.
  ///
  /// Returns the terminal rejection, or `nil` when the failure looks transient.
  private func probeClassification(
    connectURL: URL,
    upgradeError: any Error
  ) async -> JetstreamSubscriptionError? {
    var upgradeStatus: Int?
    if case let FirehoseSubscriptionError.upgradeRejected(status, _) = upgradeError {
      upgradeStatus = status
    }
    guard let probeURL = Self.httpProbeURL(from: connectURL) else {
      return upgradeStatus.map { .connectionRejected(status: $0, error: nil, message: nil) }
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
        } else if status != 426, let text = String(data: probeData.prefix(512), encoding: .utf8) {
          // The legacy API answers in plain text, e.g. "subscribe: invalid cursor".
          let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
          errorMessage = trimmed.isEmpty ? nil : trimmed
        }

        if let err = errorName, ["CursorTooOld", "UnknownZstdDictionary", "InvalidRequest"].contains(err) {
          if err == "UnknownZstdDictionary", !hasRetriedUnknownDictionary, apiVersion == .v2 {
            hasRetriedUnknownDictionary = true
            dictionaryDecoder = nil
            cachedDictID = nil
            return nil
          }
          return .connectionRejected(status: status, error: errorName, message: errorMessage)
        }
        // 426 Upgrade Required is what a healthy endpoint answers to a plain GET, and 408 /
        // 429 ask for a retry; none of them says the subscription request is wrong.
        if (400 ... 499).contains(status), ![408, 426, 429].contains(status) {
          return .connectionRejected(status: status, error: errorName, message: errorMessage)
        }
      }
    } catch {
      // Probe request failed -> treat as transient
    }
    if let upgradeStatus, (400 ... 499).contains(upgradeStatus), ![408, 426, 429].contains(upgradeStatus) {
      return .connectionRejected(status: upgradeStatus, error: nil, message: nil)
    }
    return nil
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

  /// What makes a legacy event distinct from another one with the same `time_us`.
  static func legacyEventKey(_ event: JetstreamEvent) -> String {
    switch event {
    case let .commit(commit):
      return "commit \(commit.did) \(commit.rev) \(commit.operation.rawValue) \(commit.collection) \(commit.rkey)"
    case let .identity(identity):
      return "identity \(identity.did) \(identity.identity.map { String($0.seq) } ?? "-")"
    case let .account(account):
      return "account \(account.did) \(account.account.map { String($0.seq) } ?? "-")"
    case let .sync(sync):
      return "sync \(sync.did) \(sync.sync.map { String($0.seq) } ?? "-")"
    case let .info(info):
      return "info \(info.name)"
    }
  }

  /// Sequence numbers are far below this; unix-microsecond timestamps have been above it
  /// since 2001.
  static let timestampCursorFloor: Int64 = 1_000_000_000_000_000

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

  /// Legacy `/subscribe` URL. `kinds` has no server-side parameter there and is applied to
  /// the decoded events instead.
  static func buildLegacyWebSocketURL(
    baseURL: URL,
    filter: JetstreamFilter,
    cursor: Int64?,
    compress: Bool,
    maxMessageSizeBytes: Int?,
    requireHello: Bool
  ) -> URL? {
    guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
      return nil
    }
    if components.scheme == "https" {
      components.scheme = "wss"
    } else if components.scheme == "http" {
      components.scheme = "ws"
    }

    var segments = components.path.split(separator: "/").map(String.init)
    if segments.last != "subscribe" {
      segments.append("subscribe")
    }
    components.path = "/" + segments.joined(separator: "/")

    var queryItems: [URLQueryItem] = []
    for collection in filter.collections {
      queryItems.append(URLQueryItem(name: "wantedCollections", value: collection))
    }
    for did in filter.dids {
      queryItems.append(URLQueryItem(name: "wantedDids", value: did))
    }
    if let cursor {
      queryItems.append(URLQueryItem(name: "cursor", value: String(cursor)))
    }
    if compress {
      queryItems.append(URLQueryItem(name: "compress", value: "true"))
    }
    if let maxMessageSizeBytes {
      queryItems.append(URLQueryItem(name: "maxMessageSizeBytes", value: String(maxMessageSizeBytes)))
    }
    if requireHello {
      queryItems.append(URLQueryItem(name: "requireHello", value: "true"))
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
