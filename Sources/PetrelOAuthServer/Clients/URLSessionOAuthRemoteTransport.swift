import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// The default ``OAuthRemoteTransport``, built on `URLSession`.
///
/// Each request runs on an ephemeral session with no cookies, credentials or
/// cache. Redirects are never followed (the profile requires the metadata
/// response to be an exact 200), the body is bounded while it streams, and on
/// Apple platforms the address the socket actually connected to is reported
/// from the task metrics so the fetcher can check it against the approved DNS
/// answers. `swift-corelibs-foundation` does not report a peer address; see
/// ``OAuthRemoteFetchPolicy/requiresConnectedPeerProof``.
public struct URLSessionOAuthRemoteTransport: OAuthRemoteTransport {
    /// Creates the transport.
    public init() {}

    public func get(
        url: URL,
        approvedPeers _: Set<OAuthIPAddress>,
        timeout: TimeInterval,
        maximumBodyBytes: Int
    ) async throws -> OAuthRemoteHTTPResponse {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.httpMaximumConnectionsPerHost = 1

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let delegate = Delegate(url: url, maximumBodyBytes: maximumBodyBytes)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let task = session.dataTask(with: request)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                delegate.install(continuation)
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }

    private final class Delegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        private let lock = NSLock()
        private let url: URL
        private let maximumBodyBytes: Int
        private var continuation: CheckedContinuation<OAuthRemoteHTTPResponse, Error>?
        private var body = Data()
        private var redirects = 0
        private var overflowed = false
        private var peer: OAuthIPAddress?

        init(url: URL, maximumBodyBytes: Int) {
            self.url = url
            self.maximumBodyBytes = maximumBodyBytes
        }

        func install(_ continuation: CheckedContinuation<OAuthRemoteHTTPResponse, Error>) {
            lock.lock()
            self.continuation = continuation
            lock.unlock()
        }

        func urlSession(
            _: URLSession,
            task _: URLSessionTask,
            willPerformHTTPRedirection _: HTTPURLResponse,
            newRequest _: URLRequest,
            completionHandler: @escaping @Sendable (URLRequest?) -> Void
        ) {
            lock.lock()
            redirects += 1
            lock.unlock()
            // Returning nil delivers the 3xx response itself, which the
            // fetcher then rejects as "not an exact 200".
            completionHandler(nil)
        }

        func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            lock.lock()
            if body.count + data.count > maximumBodyBytes {
                overflowed = true
                lock.unlock()
                dataTask.cancel()
                return
            }
            body.append(data)
            lock.unlock()
        }

        #if canImport(Darwin)
            func urlSession(_: URLSession, task _: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
                guard let address = metrics.transactionMetrics.last?.remoteAddress else { return }
                lock.lock()
                peer = OAuthIPAddress(literal: address)
                lock.unlock()
            }
        #endif

        func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
            lock.lock()
            let continuation = self.continuation
            self.continuation = nil
            let body = self.body
            let redirects = self.redirects
            let overflowed = self.overflowed
            let peer = self.peer
            lock.unlock()
            guard let continuation else { return }
            if overflowed {
                continuation.resume(throwing: OAuthServerError.unauthorized("OAuth remote document is too large"))
                return
            }
            if error != nil {
                continuation.resume(throwing: OAuthServerError.unavailable("OAuth remote fetch failed"))
                return
            }
            guard let response = task.response as? HTTPURLResponse else {
                continuation.resume(throwing: OAuthServerError.unavailable("OAuth remote fetch failed"))
                return
            }
            var headers: [String: [String]] = [:]
            for (name, value) in response.allHeaderFields {
                guard let name = name as? String, let value = value as? String else { continue }
                headers[name.lowercased(), default: []].append(value)
            }
            continuation.resume(returning: OAuthRemoteHTTPResponse(
                status: response.statusCode,
                headers: headers,
                body: body,
                responseURL: response.url ?? url,
                redirectCount: redirects,
                connectedPeerAddress: peer
            ))
        }
    }
}
