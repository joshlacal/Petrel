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
import Synchronization

package final class HardenedURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate, @unchecked Sendable {
    #if DEBUG && canImport(Network) && canImport(Security)
    let fixtureTransport = DebugFixtureTransport.current
    #endif
    private let maxRedirects = 5
    package let limits: NetworkResponseLimits
    package let allowsRedirects: Bool
    private let resolver: @Sendable (String) async throws -> [String]

    package init(
        allowsRedirects: Bool = true,
        limits: NetworkResponseLimits = .default,
        resolver: @escaping @Sendable (String) async throws -> [String] = { try await NetworkService.resolveHostIPsOffActor(host: $0) }
    ) {
        #if DEBUG && canImport(Network) && canImport(Security)
        self.allowsRedirects = fixtureTransport == nil && allowsRedirects
        #else
        self.allowsRedirects = allowsRedirects
        #endif
        self.limits = limits
        self.resolver = resolver
        super.init()
    }
    /// Per-task transport state, guarded by one `Mutex`.
    ///
    /// Every mutation happens in place through the dictionary's `_modify` accessor
    /// (`taskContexts[id, default: TaskContext()]`), so the accumulated response `Data` stays
    /// uniquely referenced and `append` is amortised O(chunk). The previous copy-out/append/write-back
    /// shape copied the whole accumulated body on every `didReceive data` chunk (quadratic in body
    /// size) while holding the session-wide lock.
    package final class TaskContextManager: Sendable {
        private struct State {
            var taskContexts = [Int: TaskContext]()
            // ponytail: bounded FIFO/LRU list for task violation status, 128 max capacity; pruned at task finish or FIFO eviction
            var securityViolatedTaskIDs = [Int]()
            var limitExceededTaskIDs = [Int]()
        }

        private let state = Mutex(State())
        private static let maxRetainedViolations = 128

        package init() {}

        package func getContext(for task: URLSessionTask) -> TaskContext {
            let id = task.taskIdentifier
            return state.withLock { $0.taskContexts[id] ?? TaskContext() }
        }

        package func register(_ task: URLSessionTask, completion: @escaping @Sendable (Result<(Data, URLResponse), Error>) -> Void) {
            let id = task.taskIdentifier
            state.withLock { $0.taskContexts[id] = TaskContext(completion: completion) }
        }

        package func updateContext(for task: URLSessionTask, update: (inout TaskContext) -> Void) {
            let id = task.taskIdentifier
            state.withLock { update(&$0.taskContexts[id, default: TaskContext()]) }
        }

        package func addWireBytes(_ count: Int, for task: URLSessionTask, limit: Int) -> Bool {
            let id = task.taskIdentifier
            return state.withLock { state in
                let exceeded = Self.countWireBytes(count, into: &state.taskContexts[id, default: TaskContext()], limit: limit)
                if exceeded {
                    Self.retainLimitExceeded(id, in: &state)
                }
                return exceeded
            }
        }

        /// One `didReceive data` chunk: wire-limit accounting and the in-place append, in a single
        /// critical section. Returns `true` when the wire limit is exceeded; the chunk is then not
        /// appended (the same outcome as `addWireBytes` followed by `append` only when not exceeded).
        package func receive(_ chunk: Data, for task: URLSessionTask, limit: Int) -> Bool {
            let id = task.taskIdentifier
            return state.withLock { state in
                let exceeded = Self.accumulate(chunk, into: &state.taskContexts[id, default: TaskContext()], limit: limit)
                if exceeded {
                    Self.retainLimitExceeded(id, in: &state)
                }
                return exceeded
            }
        }

        private static func countWireBytes(_ count: Int, into context: inout TaskContext, limit: Int) -> Bool {
            context.wireBytesReceived += count
            if context.wireBytesReceived > limit {
                context.limitExceeded = true
                return true
            }
            return false
        }

        private static func accumulate(_ chunk: Data, into context: inout TaskContext, limit: Int) -> Bool {
            if countWireBytes(chunk.count, into: &context, limit: limit) {
                return true
            }
            context.data.append(chunk)
            return false
        }

        private static func retainLimitExceeded(_ id: Int, in state: inout State) {
            if !state.limitExceededTaskIDs.contains(id) {
                state.limitExceededTaskIDs.append(id)
                if state.limitExceededTaskIDs.count > maxRetainedViolations {
                    state.limitExceededTaskIDs.removeFirst()
                }
            }
        }

        private static func retainSecurityViolation(_ id: Int, in state: inout State) {
            if !state.securityViolatedTaskIDs.contains(id) {
                state.securityViolatedTaskIDs.append(id)
                if state.securityViolatedTaskIDs.count > maxRetainedViolations {
                    state.securityViolatedTaskIDs.removeFirst()
                }
            }
        }

        package func recordSecurityViolation(for task: URLSessionTask) {
            let id = task.taskIdentifier
            state.withLock { state in
                Self.retainSecurityViolation(id, in: &state)
                state.taskContexts[id, default: TaskContext()].securityViolation = true
            }
        }

        package func recordLimitExceeded(for task: URLSessionTask) {
            let id = task.taskIdentifier
            state.withLock { state in
                Self.retainLimitExceeded(id, in: &state)
                state.taskContexts[id, default: TaskContext()].limitExceeded = true
            }
        }

        package func hasAnySecurityViolation() -> Bool {
            state.withLock { $0.taskContexts.values.contains { $0.securityViolation } }
        }

        package func hasAnyLimitExceeded() -> Bool {
            state.withLock { $0.taskContexts.values.contains { $0.limitExceeded } }
        }

        package func isSecurityViolation(for task: URLSessionTask) -> Bool {
            let id = task.taskIdentifier
            return state.withLock { $0.securityViolatedTaskIDs.contains(id) || ($0.taskContexts[id]?.securityViolation ?? false) }
        }

        package func isLimitExceeded(for task: URLSessionTask) -> Bool {
            let id = task.taskIdentifier
            return state.withLock { $0.limitExceededTaskIDs.contains(id) || ($0.taskContexts[id]?.limitExceeded ?? false) }
        }

        package func pruneCompletedTask(_ task: URLSessionTask) {
            let id = task.taskIdentifier
            state.withLock { state in
                state.securityViolatedTaskIDs.removeAll { $0 == id }
                state.limitExceededTaskIDs.removeAll { $0 == id }
            }
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
            let id = task.taskIdentifier
            let outcome: (completion: (@Sendable (Result<(Data, URLResponse), Error>) -> Void)?, result: Result<(Data, URLResponse), Error>)? = state.withLock { state in
                let wasViolated = state.securityViolatedTaskIDs.contains(id)
                let wasLimitExceeded = state.limitExceededTaskIDs.contains(id)
                guard let context = state.taskContexts.removeValue(forKey: id) else {
                    return nil
                }
                let result: Result<(Data, URLResponse), Error>
                if context.securityViolation || wasViolated {
                    result = .failure(NetworkError.securityViolation)
                } else if context.limitExceeded || wasLimitExceeded {
                    result = .failure(NetworkError.responseLimitExceeded("Response limit exceeded"))
                } else if let error {
                    result = .failure(error)
                } else if let response = context.response {
                    // The context was removed from the dictionary, so this Data is uniquely owned.
                    result = .success((context.data, response))
                } else {
                    result = .failure(NetworkError.invalidResponse(description: "Received no response"))
                }
                return (context.completion, result)
            }
            guard let outcome else { return }
            outcome.completion?(outcome.result)
        }
    }

    package static func transportAddressesAreApproved(_ answers: [String], approved: Set<String>) -> Bool {
        let normalized = Set(answers.map { IPAddress.normalizeIPv4MappedIPv6($0) })
        return !normalized.isEmpty
            && !normalized.contains(where: IPAddress.isPrivateOrReservedAddress)
            && !normalized.isDisjoint(with: approved)
    }
    package struct TaskContext: Sendable {
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
        let exceeded = contextManager.receive(data, for: dataTask, limit: limits.maximumWireBytes)
        if exceeded {
            LogManager.logError("Wire bytes exceeded maximum limit of \(limits.maximumWireBytes) bytes")
            dataTask.cancel()
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
        #if DEBUG && canImport(Network) && canImport(Security)
        if let fixture = fixtureTransport {
            guard let url = task.originalRequest?.url, fixture.permits(url),
                  url.host == challenge.protectionSpace.host,
                  let trust = challenge.protectionSpace.serverTrust,
                  fixture.evaluate(trust, hostname: challenge.protectionSpace.host) else {
                contextManager.recordSecurityViolation(for: task)
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            completionHandler(.useCredential, URLCredential(trust: trust))
            return
        }
        #endif
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
        #if DEBUG && canImport(Network) && canImport(Security)
        // Server trust arrives here, not at the task-level handler, whenever this session-level
        // method exists. A fixture session must evaluate against the fixture CA or it fails -1202.
        if let fixture = fixtureTransport {
            guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                  let trust = challenge.protectionSpace.serverTrust,
                  fixture.evaluate(trust, hostname: challenge.protectionSpace.host)
            else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            completionHandler(.useCredential, URLCredential(trust: trust))
            return
        }
        #endif
        completionHandler(.performDefaultHandling, nil)
    }

    // MARK: - URLSessionTaskDelegate

    package nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        #if DEBUG && canImport(Network) && canImport(Security)
        if let fixture = fixtureTransport {
            guard let url = task.originalRequest?.url, fixture.permits(url),
                  metrics.transactionMetrics.allSatisfy({ metric in
                      metric.remoteAddress.map { IPAddress.normalizeIPv4MappedIPv6($0) == "127.0.0.1" } ?? true
                  }) else {
                contextManager.recordSecurityViolation(for: task)
                task.cancel()
                return
            }
            return
        }
        #endif
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
