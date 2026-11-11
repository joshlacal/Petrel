import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import PetrelCore
import PetrelCrypto

/// The HTTP methods a PLC directory is spoken to with.
public enum PLCHTTPMethod: String, Sendable, Equatable {
    /// Every read endpoint.
    case get = "GET"
    /// `POST /:did`, submitting an operation.
    case post = "POST"
}

/// One request to a PLC directory, as handed to a ``PLCHTTPTransport``.
public struct PLCHTTPRequest: Sendable, Equatable {
    /// The HTTP method.
    public let method: PLCHTTPMethod
    /// The absolute request URL.
    public let url: URL
    /// Request headers, with lower-case names.
    public let headers: [String: String]
    /// The request body, if any.
    public let body: Data?
    /// Seconds the whole exchange may take.
    public let timeout: TimeInterval
    /// The transport must fail, without buffering more, once the response
    /// body exceeds this many bytes.
    public let maximumResponseBytes: Int

    /// Creates a request.
    public init(
        method: PLCHTTPMethod,
        url: URL,
        headers: [String: String],
        body: Data?,
        timeout: TimeInterval,
        maximumResponseBytes: Int
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.timeout = timeout
        self.maximumResponseBytes = maximumResponseBytes
    }
}

/// A directory's response, as returned by a ``PLCHTTPTransport``.
public struct PLCHTTPResponse: Sendable, Equatable {
    /// The HTTP status code.
    public let status: Int
    /// Response headers. Names are lower-cased by the initializer.
    public let headers: [String: String]
    /// The response body.
    public let body: Data
    /// The URL the response came from. ``PLCDirectoryClient`` refuses a
    /// response whose final URL is not the requested one.
    public let finalURL: URL?
    /// How many redirects were followed. ``PLCDirectoryClient`` refuses any
    /// response that was redirected; a transport should not follow them.
    public let redirectCount: Int

    /// Creates a response. Header names are lower-cased.
    public init(
        status: Int,
        headers: [String: String],
        body: Data,
        finalURL: URL? = nil,
        redirectCount: Int = 0
    ) {
        self.status = status
        self.headers = headers.reduce(into: [String: String]()) { result, entry in
            result[entry.key.lowercased()] = entry.value
        }
        self.body = body
        self.finalURL = finalURL
        self.redirectCount = redirectCount
    }
}

/// The HTTP stack under a ``PLCDirectoryClient``.
///
/// ``URLSessionPLCTransport`` is the default. Implement this to use another
/// HTTP client, to add instrumentation, or to stub the network in tests. An
/// implementation must honor ``PLCHTTPRequest/timeout`` and
/// ``PLCHTTPRequest/maximumResponseBytes``, must not follow redirects, and
/// returns non-success statuses as responses rather than throwing.
public protocol PLCHTTPTransport: Sendable {
    /// Performs one request and returns the response, whatever its status.
    func execute(_ request: PLCHTTPRequest) async throws -> PLCHTTPResponse
}

/// Validation applied only to a successful `POST /:did` response.
///
/// The compatibility case is deliberately named after the one pinned package
/// whose Express handler uses `sendStatus(200)`. It is not a general
/// `text/plain` allowance and cannot be selected for a production origin.
public enum PLCSubmitSuccessResponsePolicy: String, Sendable, Equatable {
    /// Any `2xx`. Against a production origin the submit is then confirmed
    /// by reading the audit log back.
    case strict
    /// Exactly the reference server's `200 OK` plain-text acknowledgement,
    /// taken as final. Laboratory origins only.
    case didPLCServer001 = "did-plc-server-0.0.1"
}

final class PLCRequestContext: @unchecked Sendable {
    let maximumResponseBytes: Int
    private let lock = NSLock()
    private var accumulatedData: Data
    private var response: HTTPURLResponse?
    private var exceededBound = false
    private var isTaskCancelled = false
    private var continuation: CheckedContinuation<PLCHTTPResponse, any Error>?
    private weak var task: URLSessionDataTask?

    var acceptedBytes: Int {
        lock.withLock { accumulatedData.count }
    }

    init(maximumResponseBytes: Int, continuation: CheckedContinuation<PLCHTTPResponse, any Error>) {
        self.maximumResponseBytes = maximumResponseBytes
        self.accumulatedData = Data()
        self.accumulatedData.reserveCapacity(min(maximumResponseBytes, 1_048_576))
        self.continuation = continuation
    }

    func attachTask(_ task: URLSessionDataTask) {
        lock.withLock {
            self.task = task
            if isTaskCancelled || exceededBound {
                task.cancel()
            }
        }
    }

    func didReceiveResponse(_ response: URLResponse) -> URLSession.ResponseDisposition {
        lock.withLock {
            guard let httpResponse = response as? HTTPURLResponse else {
                return .allow
            }
            self.response = httpResponse
            if httpResponse.expectedContentLength > Int64(maximumResponseBytes) && httpResponse.expectedContentLength != -1 {
                self.exceededBound = true
                self.task?.cancel()
                return .cancel
            }
            return .allow
        }
    }

    func didReceiveData(_ data: Data) {
        lock.withLock {
            guard !exceededBound && !isTaskCancelled else { return }
            let remaining = maximumResponseBytes - accumulatedData.count
            guard remaining >= 0, data.count <= remaining else {
                exceededBound = true
                task?.cancel()
                return
            }
            accumulatedData.append(data)
        }
    }

    func didCancelTask() {
        lock.withLock {
            isTaskCancelled = true
            task?.cancel()
        }
    }
    func didComplete(error: (any Error)?) {
        let (continuationToResume, result) = lock.withLock { () -> (CheckedContinuation<PLCHTTPResponse, any Error>?, Result<PLCHTTPResponse, any Error>) in
            guard let continuation = self.continuation else {
                return (nil, .failure(PetrelPLCError.unavailable("PLC HTTP request failed")))
            }
            self.continuation = nil

            if isTaskCancelled {
                return (continuation, .failure(CancellationError()))
            }

            if exceededBound {
                return (continuation, .failure(PetrelPLCError.unavailable("PLC HTTP response exceeded its bound")))
            }

            if let error = error {
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    if isTaskCancelled {
                        return (continuation, .failure(CancellationError()))
                    }
                    if exceededBound {
                        return (continuation, .failure(PetrelPLCError.unavailable("PLC HTTP response exceeded its bound")))
                    }
                }
                return (continuation, .failure(PetrelPLCError.unavailable("PLC HTTP request failed")))
            }

            guard let httpResponse = self.response else {
                return (continuation, .failure(PetrelPLCError.unavailable("PLC HTTP request failed")))
            }

            guard accumulatedData.count <= maximumResponseBytes else {
                return (continuation, .failure(PetrelPLCError.unavailable("PLC HTTP response exceeded its bound")))
            }

            var headers = [String: String]()
            for (key, value) in httpResponse.allHeaderFields {
                if let keyString = key as? String, let valueString = value as? String {
                    let name = keyString.lowercased()
                    if headers[name] == nil {
                        headers[name] = valueString
                    } else {
                        headers[name, default: ""].append(",\(valueString)")
                    }
                }
            }

            let response = PLCHTTPResponse(
                status: httpResponse.statusCode,
                headers: headers,
                body: accumulatedData,
                finalURL: httpResponse.url,
                redirectCount: 0
            )
            return (continuation, .success(response))
        }

        if let continuation = continuationToResume {
            switch result {
            case let .success(response):
                continuation.resume(returning: response)
            case let .failure(error):
                continuation.resume(throwing: error)
            }
        }
    }
}

private final class ContextHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var context: PLCRequestContext?
    private var task: URLSessionDataTask?
    private var isCancelled = false

    func set(context: PLCRequestContext, task: URLSessionDataTask) {
        lock.withLock {
            self.context = context
            self.task = task
            if isCancelled {
                context.didCancelTask()
                task.cancel()
            }
        }
    }

    func cancel() {
        lock.withLock {
            isCancelled = true
            context?.didCancelTask()
            task?.cancel()
        }
    }
}

final class PLCSessionDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var contexts = [Int: PLCRequestContext]()
    private var lastRecordedAcceptedBytes: Int = 0

    var lastAcceptedBytes: Int {
        lock.withLock { lastRecordedAcceptedBytes }
    }

    func register(context: PLCRequestContext, for task: URLSessionDataTask) {
        lock.withLock {
            contexts[task.taskIdentifier] = context
        }
        context.attachTask(task)
    }

    func unregister(task: URLSessionTask) {
        lock.withLock {
            if let ctx = contexts.removeValue(forKey: task.taskIdentifier) {
                lastRecordedAcceptedBytes = ctx.acceptedBytes
            }
        }
    }
    private func context(for task: URLSessionTask) -> PLCRequestContext? {
        lock.withLock {
            contexts[task.taskIdentifier]
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        // Disallow redirects by passing nil
        completionHandler(nil)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        guard let context = context(for: dataTask) else {
            completionHandler(.allow)
            return
        }
        let disposition = context.didReceiveResponse(response)
        completionHandler(disposition)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        context(for: dataTask)?.didReceiveData(data)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        let ctx = context(for: task)
        unregister(task: task)
        ctx?.didComplete(error: error)
    }
}

/// The default transport: an ephemeral `URLSession` with no cache, no
/// redirect following, and a hard bound on the response body that is
/// enforced while the body streams in.
public final class URLSessionPLCTransport: PLCHTTPTransport, @unchecked Sendable {
    private let session: URLSession
    let delegate: PLCSessionDelegate
    private let maximumTimeout: TimeInterval

    var lastAcceptedBytes: Int {
        delegate.lastAcceptedBytes
    }

    deinit {
        session.invalidateAndCancel()
    }

    /// - Parameter maximumTimeout: The longest ``PLCHTTPRequest/timeout``
    ///   this transport will accept, at most 30 seconds.
    public convenience init(maximumTimeout: TimeInterval = 10) throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = maximumTimeout
        configuration.timeoutIntervalForResource = maximumTimeout
        try self.init(maximumTimeout: maximumTimeout, configuration: configuration)
    }

    init(maximumTimeout: TimeInterval = 10, configuration: URLSessionConfiguration) throws {
        guard maximumTimeout > 0, maximumTimeout <= 30, maximumTimeout.isFinite else {
            throw PetrelPLCError.malformed("PLC HTTP transport timeout is invalid")
        }
        self.maximumTimeout = maximumTimeout
        let delegate = PLCSessionDelegate()
        self.delegate = delegate
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }
    /// Performs the request.
    ///
    /// - Throws: ``PetrelPLCError/malformed(_:)`` for a request outside the
    ///   transport's bounds (timeout, response limit, or a body over 32 KiB);
    ///   ``PetrelPLCError/unavailable(_:)`` when the exchange fails or the
    ///   response exceeds its bound; `CancellationError` when cancelled.
    public func execute(_ request: PLCHTTPRequest) async throws -> PLCHTTPResponse {
        guard request.timeout > 0,
              request.timeout <= maximumTimeout,
              request.timeout.isFinite,
              (1 ... PLCClientConfiguration.maximumResponseBytesCeiling)
              .contains(request.maximumResponseBytes),
              request.body?.count ?? 0 <= 32 * 1_024 else {
            throw PetrelPLCError.malformed("PLC HTTP request bounds are invalid")
        }

        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        if let body = request.body {
            urlRequest.httpBody = body
        }
        urlRequest.timeoutInterval = request.timeout

        let contextHolder = ContextHolder()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let context = PLCRequestContext(
                    maximumResponseBytes: request.maximumResponseBytes,
                    continuation: continuation
                )
                let task = session.dataTask(with: urlRequest)
                delegate.register(context: context, for: task)
                contextHolder.set(context: context, task: task)
                task.resume()
            }
        } onCancel: {
            contextHolder.cancel()
        }
    }
}

/// The former name of ``URLSessionPLCTransport``.
public typealias AsyncHTTPClientPLCTransport = URLSessionPLCTransport

