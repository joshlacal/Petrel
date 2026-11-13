import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - Event stream parsing

/// One event of a `text/event-stream` body (WHATWG HTML, "Server-sent events").
struct ServerSentEvent: Sendable, Equatable {
    /// The `event` field, or `"message"` when the event has none.
    var type: String
    /// The `data` lines of the event, joined with `"\n"`.
    var data: String
    /// The last `id` the stream set, at the time of this event.
    var lastEventID: String
}

/// Reads a `text/event-stream` body byte by byte, as the WHATWG event-stream
/// interpretation describes it.
///
/// Lines end at CR, LF or CRLF (also when CR and LF arrive in different chunks). A line
/// is decoded as UTF-8 only once it is complete, so a multi-byte character split across
/// chunks is read whole. A line or an event larger than `maximumEventBytes` fails the
/// stream instead of growing without bound.
struct ServerSentEventParser {
    static let defaultMaximumEventBytes = 8 * 1024 * 1024

    private let maximumEventBytes: Int
    private var line: [UInt8] = []
    private var afterCarriageReturn = false
    private var atStreamStart = true
    private var data = ""
    private var dataBytes = 0
    private var hasData = false
    private var eventType = ""
    private var lastEventID = ""

    init(maximumEventBytes: Int = Self.defaultMaximumEventBytes) {
        self.maximumEventBytes = maximumEventBytes
    }

    /// Feeds the next chunk of the body and returns the events it completes.
    mutating func consume<Bytes: Sequence>(_ bytes: Bytes) throws -> [ServerSentEvent] where Bytes.Element == UInt8 {
        var events: [ServerSentEvent] = []
        for byte in bytes {
            if afterCarriageReturn {
                afterCarriageReturn = false
                if byte == 0x0A { continue } // the LF of a CRLF
            }
            switch byte {
            case 0x0D:
                afterCarriageReturn = true
                if let event = try endLine() { events.append(event) }
            case 0x0A:
                if let event = try endLine() { events.append(event) }
            default:
                line.append(byte)
                guard line.count <= maximumEventBytes else { throw Self.tooLarge(maximumEventBytes) }
            }
        }
        return events
    }

    private mutating func endLine() throws -> ServerSentEvent? {
        var bytes = line[...]
        line.removeAll(keepingCapacity: true)
        if atStreamStart {
            atStreamStart = false
            if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { bytes = bytes.dropFirst(3) }
        }
        if bytes.isEmpty { return dispatch() }
        if bytes.first == UInt8(ascii: ":") { return nil } // a comment (often a keep-alive)

        let field: String
        var value: ArraySlice<UInt8>
        if let colon = bytes.firstIndex(of: UInt8(ascii: ":")) {
            field = String(decoding: bytes[..<colon], as: UTF8.self)
            value = bytes[bytes.index(after: colon)...]
            if value.first == UInt8(ascii: " ") { value = value.dropFirst() }
        } else {
            field = String(decoding: bytes, as: UTF8.self)
            value = []
        }

        switch field {
        case "event":
            eventType = String(decoding: value, as: UTF8.self)
        case "data":
            dataBytes += value.count + 1
            guard dataBytes <= maximumEventBytes else { throw Self.tooLarge(maximumEventBytes) }
            data += String(decoding: value, as: UTF8.self)
            data += "\n"
            hasData = true
        case "id":
            if !value.contains(0) { lastEventID = String(decoding: value, as: UTF8.self) }
        default:
            break // `retry` and unknown fields do not affect what a client receives
        }
        return nil
    }

    private mutating func dispatch() -> ServerSentEvent? {
        defer {
            data = ""
            dataBytes = 0
            hasData = false
            eventType = ""
        }
        guard hasData else { return nil }
        if data.hasSuffix("\n") { data.removeLast() }
        return ServerSentEvent(type: eventType.isEmpty ? "message" : eventType, data: data, lastEventID: lastEventID)
    }

    private static func tooLarge(_ limit: Int) -> NetworkError {
        .invalidResponse(description: "Server-sent event exceeds \(limit) bytes")
    }
}

// MARK: - Transport

/// Streams the events of one `text/event-stream` response.
///
/// It uses a data task with a delegate rather than `URLSession.bytes(for:)`, which
/// swift-corelibs-foundation does not have, so the same code runs on Linux. Redirects
/// are refused: the request was security-checked for its own host, not for wherever a
/// redirect would send it (and its credentials).
enum ServerSentEventTransport {
    /// How long the connection may sit without receiving a byte. Event-stream servers
    /// send comment lines as keep-alives well inside this.
    static let idleTimeout: TimeInterval = 24 * 60 * 60

    /// - Parameters:
    ///   - protocolClasses: `URLProtocol` classes for the session (tests stub the network
    ///     with them), or `nil` for the system's.
    static func events(
        for request: URLRequest,
        protocolClasses: [AnyClass]? = nil,
        onResponse: @escaping @Sendable () -> Void = {}
    ) -> AsyncThrowingStream<ServerSentEvent, Error> {
        AsyncThrowingStream { continuation in
            let delegate = Delegate(continuation: continuation, onResponse: onResponse)
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = idleTimeout
            // Finite on purpose: swift-corelibs-foundation converts these to integers. A
            // stream that should outlive a week reconnects.
            configuration.timeoutIntervalForResource = 7 * idleTimeout
            if let protocolClasses {
                configuration.protocolClasses = protocolClasses
            }
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            let task = session.dataTask(with: request)
            continuation.onTermination = { _ in
                task.cancel()
                session.invalidateAndCancel()
            }
            task.resume()
        }
    }

    private final class Delegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        private let lock = NSLock()
        private var parser = ServerSentEventParser()
        private var finished = false
        private let continuation: AsyncThrowingStream<ServerSentEvent, Error>.Continuation
        private let onResponse: @Sendable () -> Void

        init(
            continuation: AsyncThrowingStream<ServerSentEvent, Error>.Continuation,
            onResponse: @escaping @Sendable () -> Void
        ) {
            self.continuation = continuation
            self.onResponse = onResponse
        }

        private func finish(throwing error: Error?) {
            lock.lock()
            let alreadyFinished = finished
            finished = true
            lock.unlock()
            guard !alreadyFinished else { return }
            continuation.finish(throwing: error)
        }

        func urlSession(
            _: URLSession,
            task _: URLSessionTask,
            willPerformHTTPRedirection _: HTTPURLResponse,
            newRequest _: URLRequest,
            completionHandler: @escaping @Sendable (URLRequest?) -> Void
        ) {
            completionHandler(nil)
        }

        func urlSession(
            _: URLSession,
            dataTask _: URLSessionDataTask,
            didReceive response: URLResponse,
            completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
        ) {
            onResponse()
            guard let http = response as? HTTPURLResponse else {
                finish(throwing: NetworkError.invalidResponse(description: "Non-HTTP response"))
                completionHandler(.cancel)
                return
            }
            guard http.statusCode == 200 else {
                finish(throwing: NetworkError.serverError(code: http.statusCode, message: "Event stream connection failed"))
                completionHandler(.cancel)
                return
            }
            let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""
            let essence = contentType.split(separator: ";", maxSplits: 1).first.map(String.init) ?? ""
            guard essence.trimmingCharacters(in: .whitespaces).lowercased() == "text/event-stream" else {
                finish(throwing: NetworkError.invalidContentType(
                    expected: "text/event-stream",
                    actual: contentType.isEmpty ? "nil" : contentType
                ))
                completionHandler(.cancel)
                return
            }
            completionHandler(.allow)
        }

        func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            lock.lock()
            guard !finished else {
                lock.unlock()
                return
            }
            let events: [ServerSentEvent]
            do {
                events = try parser.consume(data)
            } catch {
                lock.unlock()
                finish(throwing: error)
                dataTask.cancel()
                return
            }
            for event in events {
                continuation.yield(event)
            }
            lock.unlock()
        }

        func urlSession(_ session: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
            // An event not ended by a blank line when the body ends is discarded (WHATWG).
            finish(throwing: error)
            session.finishTasksAndInvalidate()
        }
    }
}

// MARK: - Generated event-stream queries

public extension NetworkService {
    /// Sends a prepared `text/event-stream` query and decodes each event's data as JSON.
    ///
    /// Generated XRPC queries whose output encoding is `text/event-stream` call this. The
    /// request goes through ``prepareStreamingRequest(_:additionalHeaders:)`` (URL
    /// security check, credentials, client headers), and its authentication lease is
    /// released as soon as the response headers arrive. An event whose data does not
    /// decode as `Output` is logged and skipped.
    ///
    /// - Parameters:
    ///   - request: The request from ``createURLRequest(endpoint:method:headers:body:queryItems:)``.
    ///   - additionalHeaders: Headers for this request only (`atproto-proxy`).
    ///   - endpoint: The NSID, for log messages.
    ///   - outputType: The type of each event's JSON data.
    func serverSentEvents<Output: Decodable & Sendable>(
        _ request: URLRequest,
        additionalHeaders: [String: String]? = nil,
        endpoint: String,
        as outputType: Output.Type
    ) async throws -> AsyncThrowingStream<Output, Error> {
        let prepared = try await prepareStreamingRequest(request, additionalHeaders: additionalHeaders)
        #if DEBUG
            let protocolClasses = Self.getNetworkTestProtocolClasses()
        #else
            let protocolClasses: [AnyClass]? = nil
        #endif
        let events = ServerSentEventTransport.events(for: prepared.request, protocolClasses: protocolClasses) {
            prepared.releaseAuthenticationLease()
        }
        return AsyncThrowingStream { continuation in
            let consumer = Task {
                defer { prepared.releaseAuthenticationLease() }
                do {
                    let decoder = JSONDecoder()
                    for try await event in events {
                        do {
                            try continuation.yield(decoder.decode(outputType, from: Data(event.data.utf8)))
                        } catch {
                            LogManager.logError("Failed to decode server-sent event for \(endpoint): \(error)")
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in consumer.cancel() }
        }
    }
}
