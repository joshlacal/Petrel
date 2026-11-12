import Foundation
import Network

/// Ephemeral `127.0.0.1` HTTP listener capturing a single AT Protocol OAuth loopback redirect
/// (`http://127.0.0.1:<port>/callback?code=...&state=...&iss=...`).
public actor LoopbackCallbackServer {
    public enum ServerError: LocalizedError, Sendable, Equatable {
        case invalidPort(Int)
        case malformedHTTPRequest
        case cancelledBeforeCallback

        public var errorDescription: String? {
            switch self {
            case let .invalidPort(port):
                return "Invalid TCP loopback port: \(port)"
            case .malformedHTTPRequest:
                return "Loopback listener received an unrecognized HTTP request."
            case .cancelledBeforeCallback:
                return "Loopback OAuth listener stopped before receiving a callback."
            }
        }
    }

    private let port: UInt16
    private let expectedPath: String
    private var listener: NWListener?
    private var activeGate: CallbackGate?

    public init(port: Int = 8765, expectedPath: String = "/callback") throws {
        guard let validPort = UInt16(exactly: port), validPort > 0 else {
            throw ServerError.invalidPort(port)
        }
        self.port = validPort
        self.expectedPath = expectedPath.hasPrefix("/") ? expectedPath : "/" + expectedPath
    }

    /// Indicates whether the loopback TCP listener is currently bound and awaiting a redirect.
    public var isListening: Bool {
        activeGate?.isReady == true
    }

    /// Starts listening on `127.0.0.1:<port>` and suspends until the authorization server redirects
    /// the user's browser back with `?code=...&state=...&iss=...`.
    public func waitForCallback() async throws -> URL {
        try Task.checkCancellation()

        if let previousGate = activeGate {
            activeGate = nil
            previousGate.resume(throwing: ServerError.cancelledBeforeCallback)
        }
        if let previousListener = listener {
            listener = nil
            previousListener.cancel()
        }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredLocalEndpoint = .hostPort(
            host: "127.0.0.1",
            port: NWEndpoint.Port(rawValue: port)!
        )

        let nwListener = try NWListener(using: parameters)
        let gate = CallbackGate()
        listener = nwListener
        activeGate = gate

        let port = self.port
        let expectedPath = self.expectedPath

        defer {
            if activeGate === gate {
                activeGate = nil
            }
            if listener === nwListener {
                listener = nil
            }
            nwListener.cancel()
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                gate.attach(continuation)
                if Task.isCancelled {
                    gate.resume(throwing: CancellationError())
                    nwListener.cancel()
                    return
                }

                nwListener.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        gate.markReady()
                    case let .failed(error):
                        gate.resume(throwing: error)
                        nwListener.cancel()
                    case .cancelled:
                        gate.resume(throwing: ServerError.cancelledBeforeCallback)
                    default:
                        break
                    }
                }

                nwListener.newConnectionHandler = { connection in
                    Self.handleConnection(
                        connection,
                        listener: nwListener,
                        gate: gate,
                        port: port,
                        expectedPath: expectedPath
                    )
                }

                nwListener.start(queue: .global(qos: .userInitiated))
            }
        } onCancel: {
            gate.resume(throwing: CancellationError())
            nwListener.cancel()
        }
    }

    public func stop() {
        let gate = activeGate
        let currentListener = listener
        activeGate = nil
        listener = nil
        gate?.resume(throwing: ServerError.cancelledBeforeCallback)
        currentListener?.cancel()
    }

    private static let maxRequestBytes = 16_384

    private static func handleConnection(
        _ connection: NWConnection,
        listener nwListener: NWListener,
        gate: CallbackGate,
        port: UInt16,
        expectedPath: String
    ) {
        let connectionQueue = DispatchQueue(label: "petrel.loopback.connection")
        connection.start(queue: connectionQueue)
        receiveRequestLine(
            on: connection,
            accumulated: Data(),
            listener: nwListener,
            gate: gate,
            port: port,
            expectedPath: expectedPath
        )
    }

    private static func receiveRequestLine(
        on connection: NWConnection,
        accumulated: Data,
        listener nwListener: NWListener,
        gate: CallbackGate,
        port: UInt16,
        expectedPath: String
    ) {
        let remainingAllowance = maxRequestBytes + 1 - accumulated.count
        guard remainingAllowance > 0 else {
            sendBadRequestAndClose(connection)
            return
        }

        connection.receive(minimumIncompleteLength: 1, maximumLength: remainingAllowance) { chunk, _, isComplete, error in
            if error != nil {
                connection.cancel()
                return
            }

            var buffer = accumulated
            if let chunk, !chunk.isEmpty {
                buffer.append(chunk)
            }

            if let newlineIndex = buffer.firstIndex(of: 0x0A) {
                var requestLineBytes = buffer[..<newlineIndex]
                if requestLineBytes.last == 0x0D {
                    requestLineBytes = requestLineBytes.dropLast()
                }
                guard requestLineBytes.count <= maxRequestBytes,
                      let callbackURL = extractCallbackURL(
                          fromRequestLine: Data(requestLineBytes),
                          port: port,
                          expectedPath: expectedPath
                      )
                else {
                    sendBadRequestAndClose(connection)
                    return
                }

                let okResponse = httpResponse(
                    status: "200 OK",
                    body: """
                    <!doctype html>
                    <html lang="en">
                    <head><meta charset="utf-8"><title>Signed In</title></head>
                    <body style="font-family: -apple-system, sans-serif; padding: 3rem; text-align: center;">
                      <h2>Signed in with AT Protocol OAuth</h2>
                      <p>You can close this browser tab and return to LoopbackOAuthSwiftUI.</p>
                    </body>
                    </html>
                    """
                )
                connection.send(content: okResponse, completion: .contentProcessed { _ in
                    gate.resume(returning: callbackURL)
                    connection.cancel()
                    nwListener.cancel()
                })
                return
            }

            if buffer.count > maxRequestBytes {
                sendBadRequestAndClose(connection)
                return
            }

            if isComplete {
                if buffer.isEmpty {
                    connection.cancel()
                } else {
                    sendBadRequestAndClose(connection)
                }
                return
            }

            receiveRequestLine(
                on: connection,
                accumulated: buffer,
                listener: nwListener,
                gate: gate,
                port: port,
                expectedPath: expectedPath
            )
        }
    }

    private static func sendBadRequestAndClose(_ connection: NWConnection) {
        let badResponse = httpResponse(
            status: "400 Bad Request",
            body: "<h1>Invalid OAuth Callback</h1><p>Missing expected callback path.</p>"
        )
        connection.send(content: badResponse, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func extractCallbackURL(
        fromRequestLine requestLineData: Data,
        port: UInt16,
        expectedPath: String
    ) -> URL? {
        guard let requestLine = String(data: requestLineData, encoding: .utf8) else {
            return nil
        }
        let parts = requestLine.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0] == "GET",
              parts[2].hasPrefix("HTTP/")
        else {
            return nil
        }
        let target = String(parts[1])
        guard !target.contains("#") else {
            return nil
        }
        let pathPart = target.prefix { $0 != "?" }
        guard pathPart == expectedPath else {
            return nil
        }
        return URL(string: "http://127.0.0.1:\(port)\(target)")
    }

    private static func httpResponse(status: String, body: String) -> Data {
        let bodyBytes = Data(body.utf8)
        let header = [
            "HTTP/1.1 \(status)",
            "Content-Type: text/html; charset=utf-8",
            "Content-Length: \(bodyBytes.count)",
            "Connection: close",
            "",
            "",
        ].joined(separator: "\r\n")
        return Data(header.utf8) + bodyBytes
    }
}

private final class CallbackGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, any Error>?
    private var pendingResult: Result<URL, any Error>?
    private var completed = false
    private var ready = false

    init() {}

    var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return ready && !completed
    }

    func markReady() {
        lock.lock()
        if !completed {
            ready = true
        }
        lock.unlock()
    }

    func attach(_ continuation: CheckedContinuation<URL, any Error>) {
        lock.lock()
        if let result = pendingResult {
            pendingResult = nil
            lock.unlock()
            continuation.resume(with: result)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func resume(returning url: URL) {
        resume(with: .success(url))
    }

    func resume(throwing error: any Error) {
        resume(with: .failure(error))
    }

    private func resume(with result: Result<URL, any Error>) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        ready = false
        if let pending = continuation {
            continuation = nil
            lock.unlock()
            pending.resume(with: result)
        } else {
            pendingResult = result
            lock.unlock()
        }
    }
}
