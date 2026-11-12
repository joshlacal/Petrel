import Foundation
import PetrelFirehose

/// An in-memory `FirehoseWebSocketSession` that plays back a script. Once the script is
/// exhausted, `receiveMessage()` waits until the session is closed, like an idle socket.
public actor ScriptedWebSocketSession: FirehoseWebSocketSession {
  public enum Step: Sendable {
    case message(Data)
    case failure(any Error)
  }

  private var steps: [Step]
  public private(set) var isClosed = false
  /// Number of messages handed to the consumer so far.
  public private(set) var deliveredCount = 0
  /// Text messages the consumer sent.
  public private(set) var sentTexts: [String] = []
  private var closeWaiters: [CheckedContinuation<Void, Never>] = []

  public init(_ steps: [Step]) {
    self.steps = steps
  }

  public init(messages: [Data], then failure: (any Error)? = nil) {
    self.steps = messages.map(Step.message) + (failure.map { [Step.failure($0)] } ?? [])
  }

  public func receiveMessage() async throws -> Data {
    if isClosed { throw FirehoseSubscriptionError.connectionClosed }
    if !steps.isEmpty {
      switch steps.removeFirst() {
      case let .message(data):
        deliveredCount += 1
        return data
      case let .failure(error):
        throw error
      }
    }
    await waitForClose()
    throw FirehoseSubscriptionError.connectionClosed
  }

  public func sendText(_ text: String) async throws {
    sentTexts.append(text)
  }

  public func close() {
    isClosed = true
    let waiters = closeWaiters
    closeWaiters.removeAll()
    for waiter in waiters {
      waiter.resume()
    }
  }

  public func waitForClose() async {
    if isClosed { return }
    await withCheckedContinuation { closeWaiters.append($0) }
  }
}

/// Hands out scripted sessions (or connection failures) in order and records what the
/// consumer asked for.
public actor ScriptedWebSocketFactory: FirehoseWebSocketSessionFactory {
  public enum Outcome: Sendable {
    case session(ScriptedWebSocketSession)
    case failure(any Error)
  }

  private var outcomes: [Outcome]
  public private(set) var connectedURLs: [URL] = []
  public private(set) var offeredSubprotocols: [[String]] = []

  public init(_ outcomes: [Outcome]) {
    self.outcomes = outcomes
  }

  public init(sessions: [ScriptedWebSocketSession]) {
    self.outcomes = sessions.map(Outcome.session)
  }

  public func makeSession(url: URL) async throws -> any FirehoseWebSocketSession {
    try await makeSession(url: url, subprotocols: [])
  }

  public func makeSession(url: URL, subprotocols: [String]) async throws -> any FirehoseWebSocketSession {
    connectedURLs.append(url)
    offeredSubprotocols.append(subprotocols)
    guard !outcomes.isEmpty else {
      // Nothing left to script: behave like a connection that stays idle.
      return ScriptedWebSocketSession([])
    }
    switch outcomes.removeFirst() {
    case let .session(session): return session
    case let .failure(error): throw error
    }
  }

  /// The `cursor` query value of each connection attempt, in order.
  public var cursors: [String?] {
    connectedURLs.map { url in
      URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?.first(where: { $0.name == "cursor" })?.value
    }
  }
}
