//
//  RequestDeduplicator.swift
//  Petrel
//
//  Created by Assistant on 7/29/25.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Actor responsible for deduplicating concurrent identical network requests
/// to prevent multiple simultaneous calls to the same endpoint.
actor RequestDeduplicator {
    // MARK: - Types

    /// Key for identifying unique requests
    private struct RequestKey: Hashable {
        let method: String
        let url: String
        let bodyHash: Int?

        init(from request: URLRequest) {
            method = request.httpMethod ?? "GET"
            url = request.url?.absoluteString ?? ""
            bodyHash = request.httpBody?.hashValue
        }
    }

    /// Represents an in-flight request
    private struct InFlightRequest {
        let task: Task<(Data, URLResponse), Error>
        let startTime: Date
    }

    // MARK: - Properties

    /// Map of currently in-flight requests
    private var inFlightRequests: [RequestKey: InFlightRequest] = [:]

    /// Maximum time to keep a request in the deduplication cache (30 seconds)
    private let maxRequestAge: TimeInterval = 30.0

    /// Cleanup task for expired requests
    private var cleanupTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        // Cleanup task will be started on first use
    }

    deinit {
        cleanupTask?.cancel()
    }

    // MARK: - Public Methods

    /// Deduplicates a network request, ensuring only one instance of identical requests
    /// executes at a time. Subsequent identical requests wait for the first to complete.
    /// - Parameters:
    ///   - request: The URLRequest to deduplicate
    ///   - work: The async work to perform if this is the first request
    /// - Returns: The result of the network request
    func deduplicate(
        request: URLRequest,
        work: @escaping @Sendable () async throws -> (Data, URLResponse)
    ) async throws -> (Data, URLResponse) {
        // Start cleanup task on first use if needed
        if cleanupTask == nil {
            cleanupTask = Task {
                while !Task.isCancelled {
                    // Wait 30 seconds between cleanup runs
                    try? await Task.sleep(nanoseconds: 30_000_000_000)

                    await cleanupExpiredRequests()
                }
            }
        }

        let key = RequestKey(from: request)

        // Check if there's already an in-flight request
        if let existing = inFlightRequests[key] {
            // If the request is too old, remove it and proceed with a new one
            if Date().timeIntervalSince(existing.startTime) > maxRequestAge {
                LogManager.logDebug(
                    "RequestDeduplicator: Existing request for \(key.url) is too old, creating new request"
                )
                inFlightRequests.removeValue(forKey: key)
            } else {
                // Wait for the existing request to complete
                LogManager.logDebug(
                    "RequestDeduplicator: Found existing request for \(key.url), waiting for completion"
                )
                return try await existing.task.value
            }
        }

        // Create a new task for this request
        let task = Task<(Data, URLResponse), Error> {
            do {
                let result = try await work()
                // Remove from in-flight map after completion
                await self.removeInFlightRequest(for: key)
                return result
            } catch {
                // Remove from in-flight map after failure
                await self.removeInFlightRequest(for: key)
                throw error
            }
        }

        // Store the task as in-flight
        let inFlightRequest = InFlightRequest(task: task, startTime: Date())
        inFlightRequests[key] = inFlightRequest

        LogManager.logDebug(
            "RequestDeduplicator: Starting new request for \(key.url) (total in-flight: \(inFlightRequests.count))"
        )

        // Await and return the result
        return try await task.value
    }

    /// Checks if a request matching the given URLRequest is currently in flight
    /// - Parameter request: The request to check
    /// - Returns: True if an identical request is in progress
    func isRequestInFlight(_ request: URLRequest) -> Bool {
        let key = RequestKey(from: request)
        if let existing = inFlightRequests[key] {
            // Check if it's not expired
            return Date().timeIntervalSince(existing.startTime) <= maxRequestAge
        }
        return false
    }

    /// Cancels all in-flight requests (useful for cleanup scenarios)
    func cancelAllRequests() {
        LogManager.logInfo("RequestDeduplicator: Canceling all \(inFlightRequests.count) in-flight requests")
        for (_, request) in inFlightRequests {
            request.task.cancel()
        }
        inFlightRequests.removeAll()
    }

    // MARK: - Private Methods

    /// Removes an in-flight request from tracking
    private func removeInFlightRequest(for key: RequestKey) {
        inFlightRequests.removeValue(forKey: key)
        LogManager.logDebug(
            "RequestDeduplicator: Removed completed request for \(key.url) (remaining: \(inFlightRequests.count))"
        )
    }

    /// Removes expired requests from the in-flight map
    private func cleanupExpiredRequests() {
        let now = Date()
        var expiredCount = 0

        for (key, request) in inFlightRequests {
            if now.timeIntervalSince(request.startTime) > maxRequestAge {
                inFlightRequests.removeValue(forKey: key)
                request.task.cancel()
                expiredCount += 1
            }
        }

        if expiredCount > 0 {
            LogManager.logInfo(
                "RequestDeduplicator: Cleaned up \(expiredCount) expired requests (remaining: \(inFlightRequests.count))"
            )
        }
    }
}
