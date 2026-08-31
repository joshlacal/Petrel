//
//  HardenedURLSessionDelegate.swift
//  Petrel
//
//  Created by Josh LaCalamito on 9/16/24.
//

import Foundation
#if canImport(Security)
    import Security
#endif
#if canImport(Network)
    import Network
#endif
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

package final class HardenedURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate, @unchecked Sendable {
    private let maxRedirects = 5
    package let limits: NetworkResponseLimits
    package let allowsRedirects: Bool
    private let resolver: @Sendable (String) async throws -> [String]

    package init(
        allowsRedirects: Bool = true,
        limits: NetworkResponseLimits = .default,
        resolver: @escaping @Sendable (String) async throws -> [String] = { try await NetworkService.resolveHostIPsOffActor(host: $0) }
    ) {
        self.allowsRedirects = allowsRedirects
        self.limits = limits
        self.resolver = resolver
        super.init()
    }
    package final class TaskContextManager: @unchecked Sendable {
        private let lock = NSLock()
        private var taskContexts = [Int: TaskContext]()
        // ponytail: bounded FIFO/LRU list for task violation status, 128 max capacity; pruned at task finish or FIFO eviction
        private var securityViolatedTaskIDs = [Int]()
        private var limitExceededTaskIDs = [Int]()
        private let maxRetainedViolations = 128

        package func getContext(for task: URLSessionTask) -> TaskContext {
            lock.lock()
            defer { lock.unlock() }
            return taskContexts[task.taskIdentifier] ?? TaskContext()
        }

        package func register(_ task: URLSessionTask, completion: @escaping @Sendable (Result<(Data, URLResponse), Error>) -> Void) {
            lock.lock()
            defer { lock.unlock() }
            taskContexts[task.taskIdentifier] = TaskContext(completion: completion)
        }

        package func updateContext(for task: URLSessionTask, update: (inout TaskContext) -> Void) {
            lock.lock()
            defer { lock.unlock() }
            var context = taskContexts[task.taskIdentifier] ?? TaskContext()
            update(&context)
            taskContexts[task.taskIdentifier] = context
        }

        package func addWireBytes(_ count: Int, for task: URLSessionTask, limit: Int) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            var context = taskContexts[task.taskIdentifier] ?? TaskContext()
            context.wireBytesReceived += count
            if context.wireBytesReceived > limit {
                context.limitExceeded = true
                if !limitExceededTaskIDs.contains(task.taskIdentifier) {
                    limitExceededTaskIDs.append(task.taskIdentifier)
                    if limitExceededTaskIDs.count > maxRetainedViolations {
                        limitExceededTaskIDs.removeFirst()
                    }
                }
                taskContexts[task.taskIdentifier] = context
                return true
            }
            taskContexts[task.taskIdentifier] = context
            return false
        }

        package func recordSecurityViolation(for task: URLSessionTask) {
            lock.lock()
            if !securityViolatedTaskIDs.contains(task.taskIdentifier) {
                securityViolatedTaskIDs.append(task.taskIdentifier)
                if securityViolatedTaskIDs.count > maxRetainedViolations {
                    securityViolatedTaskIDs.removeFirst()
                }
            }
            var context = taskContexts[task.taskIdentifier] ?? TaskContext()
            context.securityViolation = true
            taskContexts[task.taskIdentifier] = context
            lock.unlock()
        }

        package func recordLimitExceeded(for task: URLSessionTask) {
            lock.lock()
            if !limitExceededTaskIDs.contains(task.taskIdentifier) {
                limitExceededTaskIDs.append(task.taskIdentifier)
                if limitExceededTaskIDs.count > maxRetainedViolations {
                    limitExceededTaskIDs.removeFirst()
                }
            }
            var context = taskContexts[task.taskIdentifier] ?? TaskContext()
            context.limitExceeded = true
            taskContexts[task.taskIdentifier] = context
            lock.unlock()
        }

        package func hasAnySecurityViolation() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return taskContexts.values.contains { $0.securityViolation }
        }

        package func hasAnyLimitExceeded() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return taskContexts.values.contains { $0.limitExceeded }
        }

        package func isSecurityViolation(for task: URLSessionTask) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return securityViolatedTaskIDs.contains(task.taskIdentifier) || (taskContexts[task.taskIdentifier]?.securityViolation ?? false)
        }

        package func isLimitExceeded(for task: URLSessionTask) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return limitExceededTaskIDs.contains(task.taskIdentifier) || (taskContexts[task.taskIdentifier]?.limitExceeded ?? false)
        }

        package func pruneCompletedTask(_ task: URLSessionTask) {
            lock.lock()
            securityViolatedTaskIDs.removeAll { $0 == task.taskIdentifier }
            limitExceededTaskIDs.removeAll { $0 == task.taskIdentifier }
            lock.unlock()
        }

        package func setApprovedAddresses(_ addresses: Set<String>, for task: URLSessionTask) {
            updateContext(for: task) { $0.approvedAddresses = addresses }
        }

        package func approveRedirect(_ addresses: Set<String>, for task: URLSessionTask) {
            updateContext(for: task) {
                $0.approvedAddresses = addresses
                $0.data.removeAll(keepingCapacity: false)
                $0.response = nil
                $0.wireBytesReceived = 0
            }
        }

        package func setResponse(_ response: URLResponse, for task: URLSessionTask) {
            updateContext(for: task) { $0.response = response }
        }
        package func append(_ data: Data, for task: URLSessionTask) {
            updateContext(for: task) { $0.data.append(data) }
        }

        package func finish(_ task: URLSessionTask, error: Error?) {
            lock.lock()
            let wasViolated = securityViolatedTaskIDs.contains(task.taskIdentifier)
            let wasLimitExceeded = limitExceededTaskIDs.contains(task.taskIdentifier)
            guard let context = taskContexts.removeValue(forKey: task.taskIdentifier) else {
                lock.unlock()
                return
            }
            let completion = context.completion
            let result: Result<(Data, URLResponse), Error>
            if context.securityViolation || wasViolated {
                result = .failure(NetworkError.securityViolation)
            } else if context.limitExceeded || wasLimitExceeded {
                result = .failure(NetworkError.responseLimitExceeded("Response limit exceeded"))
            } else if let error {
                result = .failure(error)
            } else if let response = context.response {
                result = .success((context.data, response))
            } else {
                result = .failure(NetworkError.invalidResponse(description: "Received no response"))
            }
            lock.unlock()
            completion?(result)
        }
    }

    package static func transportAddressesAreApproved(_ answers: [String], approved: Set<String>) -> Bool {
        let normalized = Set(answers.map { IPAddress.normalizeIPv4MappedIPv6($0) })
        return !normalized.isEmpty
            && !normalized.contains(where: IPAddress.isPrivateOrReservedAddress)
            && !normalized.isDisjoint(with: approved)
    }
    package struct TaskContext {
        var redirectCount = 0
        var wireBytesReceived = 0
        var limitExceeded = false
        var securityViolation = false
        var approvedAddresses: Set<String> = []
        var data = Data()
        var response: URLResponse?
        var completion: (@Sendable (Result<(Data, URLResponse), Error>) -> Void)? = nil
    }

    package let contextManager = TaskContextManager()

    // MARK: - URLSessionTaskDelegate

    package nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        guard allowsRedirects else {
            LogManager.logInfo("Rejected redirect for exact-auth request scope")
            completionHandler(nil)
            return
        }
        guard let targetURL = request.url else {
            completionHandler(nil)
            return
        }

        // Ensure target scheme is https/wss for remote traffic or http/ws for local
        let scheme = targetURL.scheme?.lowercased() ?? ""
        let isLocalTarget: Bool = {
            guard let host = targetURL.host?.lowercased() else { return false }
            return host == "localhost" || host == "127.0.0.1" || host == "::1"
        }()
        if (scheme == "http" || scheme == "ws") && !isLocalTarget {
            LogManager.logError("Rejected redirect to non-local cleartext scheme: \(scheme)")
            completionHandler(nil)
            return
        }
        guard scheme == "https" || scheme == "wss" || ((scheme == "http" || scheme == "ws") && isLocalTarget) else {
            LogManager.logError("Rejected redirect to unsafe scheme: \(scheme)")
            completionHandler(nil)
            return
        }

        guard let host = targetURL.host, !host.isEmpty else {
            completionHandler(nil)
            return
        }

        let originalURL = task.originalRequest?.url ?? response.url
        let isSameOrigin: Bool = {
            guard let orig = originalURL,
                  let origOrigin = ExactAuthRequestOrigin(orig),
                  let targetOrigin = ExactAuthRequestOrigin(targetURL)
            else {
                return false
            }
            return origOrigin == targetOrigin
        }()

        var redirectedRequest = request
        if !isSameOrigin {
            // Strip authentication and sensitive headers before cross-origin redirect
            let sensitiveHeaders = [
                "authorization", "dpop", "x-dpop", "dpop-nonce", "cookie", "atproto-proxy",
                "x-api-key", "x-auth-token", "proxy-authorization"
            ]
            for header in sensitiveHeaders {
                redirectedRequest.setValue(nil, forHTTPHeaderField: header)
            }
        }

        Task {
            let normalizedHost = host.lowercased()
            let approvedAddresses: Set<String>
            do {
                approvedAddresses = try await NetworkService.resolveApprovedAddresses(host: normalizedHost, isLocal: isLocalTarget)
            } catch {
                LogManager.logError("Rejected redirect to invalid/unresolvable host/IP: \(host)")
                completionHandler(nil)
                return
            }
            let context = self.contextManager.getContext(for: task)
            guard context.redirectCount < self.maxRedirects else {
                LogManager.logError("Exceeded maximum number of redirects (\(self.maxRedirects)) for request")
                completionHandler(nil)
                return
            }
            self.contextManager.approveRedirect(
                approvedAddresses,
                for: task
            )
            self.contextManager.updateContext(for: task) { context in
                context.redirectCount += 1
            }
            let count = self.contextManager.getContext(for: task).redirectCount
            LogManager.logInfo("Redirecting to: \(targetURL.path). Redirect count: \(count)")
            completionHandler(redirectedRequest)
        }
    }

    // MARK: - URLSessionDataDelegate

    package nonisolated func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        // Check Content-Length to enforce wire size limits before downloading
        if let httpResponse = response as? HTTPURLResponse,
           let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length").flatMap(Int.init),
           contentLength > limits.maximumWireBytes
        {
            LogManager.logError("Response Content-Length exceeds maximum limit of \(limits.maximumWireBytes) bytes")
            contextManager.recordLimitExceeded(for: dataTask)
            completionHandler(.cancel)
            return
        }
        contextManager.setResponse(response, for: dataTask)
        completionHandler(.allow)
    }

    package nonisolated func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        let exceeded = contextManager.addWireBytes(data.count, for: dataTask, limit: limits.maximumWireBytes)
        if exceeded {
            LogManager.logError("Wire bytes exceeded maximum limit of \(limits.maximumWireBytes) bytes")
            dataTask.cancel()
        } else {
            contextManager.append(data, for: dataTask)
        }
    }

    func serverTrustIsApproved(for task: URLSessionTask, host: String) async -> Bool {
        do {
            let answers = try await resolver(host)
            let approved = contextManager.getContext(for: task).approvedAddresses
            return Self.transportAddressesAreApproved(answers, approved: approved)
        } catch {
            return false
        }
    }

    // swift-corelibs-foundation does not support server-trust authentication
    // methods; transport rebinding is still enforced via task metrics on Linux.
    #if canImport(Darwin)
    package nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.serverTrust != nil,
              let host = task.currentRequest?.url?.host?.lowercased()
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        Task {
            guard await self.serverTrustIsApproved(for: task, host: host) else {
                self.contextManager.recordSecurityViolation(for: task)
                task.cancel()
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            completionHandler(.performDefaultHandling, nil)
        }
    }
    #endif

    package nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        completionHandler(.performDefaultHandling, nil)
    }

    // MARK: - URLSessionTaskDelegate

    package nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        // Inspect the actual remote address connected to by the transport (DNS rebinding defense)
        let isLocalTarget: Bool = {
            guard let host = task.originalRequest?.url?.host?.lowercased() else { return false }
            return host == "localhost" || host == "127.0.0.1" || host == "::1"
        }()

        for transactionMetric in metrics.transactionMetrics {
            if let remoteAddress = transactionMetric.remoteAddress {
                // Strip port or brackets if present (e.g. "127.0.0.1:443" or "[::1]:443")
                var cleaned = remoteAddress
                if cleaned.hasPrefix("[") && cleaned.contains("]") {
                    let parts = cleaned.dropFirst().split(separator: "]")
                    cleaned = String(parts.first ?? "")
                } else if let colonIndex = cleaned.firstIndex(of: ":"), !cleaned.contains("::") {
                    cleaned = String(cleaned[..<colonIndex])
                }
                let normalized = IPAddress.normalizeIPv4MappedIPv6(cleaned)
                if IPAddress.isPrivateOrReservedAddress(normalized) && !isLocalTarget {
                    LogManager.logError("Security violation: transport connected to private/reserved address: \(remoteAddress)")
                    self.contextManager.recordSecurityViolation(for: task)
                    task.cancel()
                    break
                }
            }
        }
    }

    package nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            LogManager.logError("Task completed with error: \(error.localizedDescription)")
        }
        contextManager.finish(task, error: error)
    }
}
