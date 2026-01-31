//
//  HardenedURLSessionDelegate.swift
//  Petrel
//
//  Created by Josh LaCalamito on 9/16/24.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

final class HardenedURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate, @unchecked Sendable {
    private let maxRedirects = 5
    private let maxResponseSize = 10 * 1024 * 1024 // 10 MB

    private actor TaskContextManager {
        private var taskContexts = [URLSessionTask: TaskContext]()

        func getContext(for task: URLSessionTask) -> TaskContext {
            taskContexts[task] ?? TaskContext()
        }

        func updateContext(for task: URLSessionTask, update: @Sendable (inout TaskContext) -> Void) {
            var context = taskContexts[task] ?? TaskContext()
            update(&context)
            taskContexts[task] = context
        }

        func removeContext(for task: URLSessionTask) {
            taskContexts[task] = nil
        }
    }

    private struct TaskContext: Sendable {
        var redirectCount = 0
        var receivedData = Data()
    }

    private let contextManager = TaskContextManager()

    // MARK: - URLSessionTaskDelegate

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        let requestURLString = request.url?.absoluteString ?? "unknown URL"

        Task {
            let context = await self.contextManager.getContext(for: task)
            var shouldRedirect = false
            if context.redirectCount >= maxRedirects {
                LogManager.logError("Exceeded maximum number of redirects (\(maxRedirects)) for request to \(requestURLString)")
            } else {
                await self.contextManager.updateContext(for: task) { context in
                    context.redirectCount += 1
                }
                LogManager.logInfo("Redirecting to: \(requestURLString). Redirect count: \(context.redirectCount)")
                shouldRedirect = true
            }
            await MainActor.run {
                completionHandler(shouldRedirect ? request : nil)
            }
        }
    }

    // MARK: - URLSessionDataDelegate

    // NOTE: We intentionally do NOT implement urlSession(_:dataTask:didReceive:)
    // Implementing that method causes URLSession to bypass automatic Content-Encoding
    // decompression (gzip, br, deflate). By not implementing it, URLSession handles
    // data accumulation AND decompression automatically.
    //
    // Size limiting is handled via:
    // 1. URLSessionConfiguration.timeoutIntervalForResource
    // 2. Checking Content-Length in didReceive(response:) below

    nonisolated func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
    ) {
        // Check Content-Length to enforce size limits before downloading
        if let httpResponse = response as? HTTPURLResponse,
           let contentLengthString = httpResponse.allHeaderFields["Content-Length"] as? String,
           let contentLength = Int(contentLengthString),
           contentLength > maxResponseSize
        {
            LogManager.logError("Response Content-Length (\(contentLength) bytes) exceeds maximum limit of \(maxResponseSize) bytes")
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    // MARK: - URLSessionDelegate

    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        Task {
            guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                  let serverTrust = challenge.protectionSpace.serverTrust
            else {
                LogManager.logError("Authentication challenge is not for server trust.")
                completionHandler(.performDefaultHandling, nil)
                return
            }

            // Enforce HTTPS Scheme
            guard challenge.protectionSpace.protocol == "https" else {
                LogManager.logError("Connection is not over HTTPS. Protocol: \(challenge.protectionSpace.protocol ?? "nil")")
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }

            // Optional: Restrict to allowed hostnames (uncomment and customize if needed)
            /*
             let allowedHostnames: Set<String> = [
                 "bsky.social",
                 // Add other pre-trusted hostnames here
             ]
             let host = challenge.protectionSpace.host.lowercased()
             if !allowedHostnames.contains(host) {
                 LogManager.logError("Host \(host) is not in the list of allowed hostnames.")
                 completionHandler(.cancelAuthenticationChallenge, nil)
                 return
             }
             */

            // Evaluate server trust
            let policy = SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)
            SecTrustSetPolicies(serverTrust, policy)

            var error: CFError?
            let isServerTrustValid = SecTrustEvaluateWithError(serverTrust, &error)

            if isServerTrustValid {
                // Proceed with the connection
                let credential = URLCredential(trust: serverTrust)
                LogManager.logInfo("Server trust evaluation succeeded for host: \(challenge.protectionSpace.host)")
                completionHandler(.useCredential, credential)
            } else {
                // Server trust evaluation failed
                LogManager.logError("Server trust evaluation failed for host: \(challenge.protectionSpace.host). Error: \(error?.localizedDescription ?? "Unknown error")")
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        }
    }

    // MARK: - URLSessionTaskDelegate

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task {
            if let error = error {
                LogManager.logError("Task \(task.taskIdentifier) completed with error: \(error.localizedDescription)")
            } else {
                LogManager.logInfo("Task \(task.taskIdentifier) completed successfully.")
            }
            await self.contextManager.removeContext(for: task)
        }
    }
}
