//
//  TokenRefreshCoordinator.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/23/25.
//
//

import Foundation

/// Actor responsible for coordinating and serializing token refresh operations
/// to prevent race conditions with single-use refresh tokens.
actor TokenRefreshCoordinator {
    // MARK: - Properties

    /// Task representing the currently executing refresh operation, if any.
    /// This task *always* produces `RefreshResult`.
    private var refreshTask: Task<RefreshResult, Error>?

    /// Queue of continuations waiting for the single `refreshTask` to complete.
    /// Each continuation knows how to transform the final `RefreshResult` into the type `T` its caller expects.
    private var waitingContinuations: [any TypedContinuation] = []

    /// Last successful refresh result and timestamp (optional, for potential future debouncing/caching logic)
    private var lastRefreshResult: (result: RefreshResult, timestamp: Date)?

    // MARK: - Helper Protocols/Structs for Type Erasure

    /// Protocol defining the interface for resuming a type-erased continuation.
    private protocol TypedContinuation: Sendable {
        /// Resumes the underlying continuation with the final result of the refresh operation.
        /// The implementation is responsible for transforming the `RefreshResult` into the expected type `T`.
        func resume(with result: Result<RefreshResult, Error>)
    }

    /// Concrete implementation of TypedContinuation, holding the actual continuation and the transformation logic.
    private struct AnyTypedContinuation<T: Sendable>: TypedContinuation {
        private let continuation: CheckedContinuation<T, Error>
        private let expectedType: T.Type

        init(_ continuation: CheckedContinuation<T, Error>) {
            self.continuation = continuation
            expectedType = T.self
        }

        func resume(with result: Result<RefreshResult, Error>) {
            switch result {
            case let .success(refreshResult):
                // Attempt to provide the type the caller originally expected (T)
                if T.self == RefreshResult.self, let typedResult = refreshResult as? T {
                    // If caller expected RefreshResult, provide it directly
                    continuation.resume(returning: typedResult)
                } else if T.self == (Data, HTTPURLResponse).self,
                          let tupleResult = (refreshResult.originalResponse.0, refreshResult.originalResponse.1) as? T
                {
                    // If caller expected the raw tuple, provide it from the stored response
                    continuation.resume(returning: tupleResult)
                } else {
                    // This indicates a potential design issue or unexpected caller type T.
                    // The coordinator is primarily designed to return RefreshResult or the raw tuple.
                    LogManager.logError(
                        "TokenRefreshCoordinator: Failed to transform RefreshResult into expected type \(T.self). This type might not be supported."
                    )
                    continuation.resume(throwing: RefreshError.invalidState)
                }
            case let .failure(error):
                // Propagate the error directly
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Core Refresh Result and Error Types

    /// Represents the successfully decoded result of a refresh operation.
    /// Includes the original network response for flexibility.
    struct RefreshResult: Sendable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: TimeInterval
        let refreshedAt: Date
        // Store the original network response to enable returning it to callers expecting the raw tuple
        let originalResponse: (Data, HTTPURLResponse)

        // Note: Custom Decodable initializer is removed as we will decode manually
        // after checking the status code in the main refresh logic.

        /// Checks if the token is likely still valid (more than 30 seconds remaining).
        var isStillValid: Bool {
            let now = Date()
            return now.timeIntervalSince(refreshedAt) + 30 < expiresIn
        }
    }

    /// Custom errors related to the token refresh process and coordination.
    enum RefreshError: Error, LocalizedError {
        case invalidState // e.g., coordinator released, unexpected function return type
        case refreshFunctionError(Error) // Error from the provided refresh function itself
        case invalidGrant(String?) // Specific OAuth error: token revoked or invalid
        case dpopError(String?) // Specific DPoP error: nonce or proof invalid
        case networkError(Int, String?) // General HTTP error
        case decodingError(Error, String?) // Failed to decode success or error response
        case alreadyInProgress
        case refreshTooFrequent

        var errorDescription: String? {
            switch self {
            case .invalidState:
                return "TokenRefreshCoordinator: Invalid internal state."
            case let .refreshFunctionError(underlying):
                return "TokenRefreshCoordinator: The provided refresh function failed: \(underlying.localizedDescription)"
            case let .invalidGrant(description):
                return "TokenRefreshCoordinator: Invalid refresh token: \(description ?? "No details provided by server")."
            case let .dpopError(description):
                return "TokenRefreshCoordinator: DPoP error during refresh: \(description ?? "No details provided by server")."
            case let .networkError(code, details):
                return "TokenRefreshCoordinator: Network error (\(code)) during refresh: \(details ?? "No details provided by server")."
            case let .decodingError(error, context):
                return "TokenRefreshCoordinator: Failed to decode refresh response (\(context ?? "N/A")): \(error.localizedDescription)"
            case .alreadyInProgress:
                return "TokenRefreshCoordinator: Refresh operation is already in progress."
            case .refreshTooFrequent:
                return "TokenRefreshCoordinator: Refresh operation was attempted too frequently."
            }
        }
    }

    /// Structure to decode OAuth error responses.
    private struct OAuthErrorResponse: Decodable {
        let error: String
        let errorDescription: String?

        enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
        }
    }

    // MARK: - Public API

    /// Coordinates a token refresh operation. Ensures only one refresh happens concurrently.
    /// All callers wait for the single refresh operation to complete.
    ///
    /// - Parameter refreshFunction: An async closure that performs the *actual* network request
    ///   for token refresh and **must** return `(Data, HTTPURLResponse)`.
    /// - Returns: The type `T` requested by the caller. This is typically either `RefreshResult`
    ///   (for internal use or direct token access) or `(Data, HTTPURLResponse)` (for callers
    ///   needing the raw response, like the initial network layer).
    /// - Throws: `RefreshError` or other errors propagated from the `refreshFunction`.
    func coordinateRefresh<T: Sendable>(
        performing refreshFunction: @escaping @Sendable () async throws -> (Data, HTTPURLResponse)
    ) async throws -> T {
        // Use a continuation to suspend the caller until the refresh completes.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            // Create a type-erased wrapper for the continuation.
            let typedContinuation = AnyTypedContinuation<T>(continuation)

            // Check if a refresh is already in progress.
            if refreshTask != nil {
                LogManager.logInfo(
                    "TokenRefreshCoordinator: Refresh already in progress for \(T.self), adding to \(waitingContinuations.count) waiters."
                )
                // If yes, just add this caller's continuation to the queue and return.
                // It will be resumed when the existing task finishes.
                waitingContinuations.append(typedContinuation)
            } else {
                LogManager.logInfo("TokenRefreshCoordinator: Starting new refresh operation for \(T.self).")
                // If no, start a *new* refresh task.
                // Add the *current* caller's continuation to the queue first.
                waitingContinuations.append(typedContinuation)

                // Create the single, shared Task that performs the refresh.
                // This task *always* produces `RefreshResult`.
                let newRefreshTask = Task<RefreshResult, Error> {
                    do {
                        // 1. Execute the provided network function
                        LogManager.logDebug("TokenRefreshCoordinator: Executing refreshFunction...")
                        let (data, response) = try await refreshFunction()
                        LogManager.logDebug(
                            "TokenRefreshCoordinator: refreshFunction returned status \(response.statusCode)."
                        )

                        // 2. Check HTTP Status Code
                        if (200 ..< 300).contains(response.statusCode) {
                            // Success: Decode the raw data as our internal `RefreshResult`
                            do {
                                // Manually decode here
                                let decoder = JSONDecoder()
                                let tokenResponse = try decoder.decode(TokenResponse.self, from: data)

                                let result = RefreshResult(
                                    accessToken: tokenResponse.accessToken,
                                    refreshToken: tokenResponse.refreshToken,
                                    expiresIn: TimeInterval(tokenResponse.expiresIn),
                                    refreshedAt: Date(), // Mark refresh time *now*
                                    originalResponse: (data, response) // Store the raw tuple
                                )

                                // Update internal cache (optional step)
                                await self.updateLastResult(result)
                                LogManager.logDebug("TokenRefreshCoordinator: Refresh successful, decoded RefreshResult.")
                                return result

                            } catch {
                                LogManager.logError(
                                    "TokenRefreshCoordinator: Failed to decode successful refresh response: \(error)", category: .authentication
                                )
                                // If decoding fails on a 2xx response, it's a critical error.
                                throw RefreshError.decodingError(error, "Decoding 2xx response")
                            }
                        } else {
                            // Failure: Attempt to decode as OAuth error, otherwise create generic network error.
                            LogManager.logDebug(
                                "TokenRefreshCoordinator: Refresh request failed with status \(response.statusCode)."
                            )
                            throw createErrorFromResult(data: data, response: response)
                        }
                    } catch let knownError as RefreshError {
                        // Re-throw RefreshErrors directly
                        LogManager.logError("TokenRefreshCoordinator: Refresh task failed with RefreshError: \(knownError)")
                        throw knownError
                    } catch let urlError as URLError {
                        // Wrap URLErrors
                        LogManager.logError("TokenRefreshCoordinator: Refresh task failed with URLError: \(urlError)")
                        throw RefreshError.networkError(urlError.code.rawValue, urlError.localizedDescription)
                    } catch {
                        // Wrap any other errors from the refreshFunction
                        LogManager.logError(
                            "TokenRefreshCoordinator: Refresh task failed with unexpected error from refreshFunction: \(error)"
                        )
                        throw RefreshError.refreshFunctionError(error)
                    }
                } // End of Task<RefreshResult, Error> body

                // Store the new task so subsequent callers will wait on it.
                self.refreshTask = newRefreshTask

                // Start a detached Task to await the completion of the *newRefreshTask*
                // and then call `completeRefresh` to resume all waiting continuations.
                // This ensures `completeRefresh` runs *after* the task finishes.
                Task.detached { [weak self] in
                    // Await the task's completion to get its Result
                    _ = await newRefreshTask.result // We only care that it finished, the result is handled in completeRefresh
                    // Now call completeRefresh, passing the task itself for verification
                    await self?.completeRefresh(for: newRefreshTask)
                }
            } // End else (start new refresh task)
        } // End withCheckedThrowingContinuation
    }

    /// Creates a specific `RefreshError` based on HTTP status code and data.
    private func createErrorFromResult(data: Data, response: HTTPURLResponse) -> RefreshError {
        let statusCode = response.statusCode
        LogManager.logError(
            "TokenRefreshCoordinator: Creating error for status \(statusCode)", category: .authentication
        )
        // Capture relevant auth headers for diagnostics (filtered, non-sensitive)
        if let wwwAuth = response.value(forHTTPHeaderField: "WWW-Authenticate") {
            LogManager.logDebug(
                "TokenRefreshCoordinator: WWW-Authenticate=\(wwwAuth)",
                category: .authentication
            )
        }
        if let dpopNonce = response.value(forHTTPHeaderField: "DPoP-Nonce") {
            LogManager.logDebug(
                "TokenRefreshCoordinator: DPoP-Nonce present (length=\(dpopNonce.count))",
                category: .authentication
            )
        }

        // Try decoding as standard OAuth error first
        if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
            LogManager.logError(
                "TokenRefreshCoordinator: Decoded OAuth error: \(errorResponse.error) - \(errorResponse.errorDescription ?? "no server description")"
            )
            switch errorResponse.error {
            case "invalid_grant":
                LogManager.logAuthIncident(
                    "RefreshInvalidGrant",
                    details: [
                        "status": statusCode,
                        "error": errorResponse.error,
                        "desc": errorResponse.errorDescription ?? "",
                    ]
                )
                return .invalidGrant(errorResponse.errorDescription)
            case "use_dpop_nonce", "invalid_dpop_proof":
                return .dpopError(errorResponse.errorDescription)
            default:
                // Treat other known OAuth errors as specific network errors, including description
                return .networkError(
                    statusCode, "\(errorResponse.error): \(errorResponse.errorDescription ?? "Unknown error")"
                )
            }
        } else {
            // If not a standard OAuth error, return a generic network error
            return .networkError(statusCode, "HTTP Error: \(statusCode)")
        }
    }

    /// Updates the internal cache of the last successful result.
    private func updateLastResult(_ result: RefreshResult) {
        lastRefreshResult = (result, Date())
        LogManager.logInfo("TokenRefreshCoordinator: Updated last successful refresh result cache.")
    }

    /// Called *after* a refresh task completes to resume all waiting continuations.
    /// - Parameter completedTask: The task that just finished. Used to prevent race conditions
    ///   if a new refresh started *very* quickly after this one finished but before
    ///   `completeRefresh` could clear `self.refreshTask`.
    private func completeRefresh(for completedTask: Task<RefreshResult, Error>) async {
        // Ensure this completion logic is for the *correct* task currently stored.
        // If self.refreshTask is nil or refers to a *different* task, it means a new
        // refresh has already started, and we should let *that* task's completion handle resumption.
        guard refreshTask == completedTask else {
            LogManager.logDebug(
                "TokenRefreshCoordinator: completeRefresh called for an outdated or already cleared task. Ignoring."
            )
            return
        }

        // Get the result (success or failure) of the completed task.
        let taskResult = await completedTask.result // Result<RefreshResult, Error>

        // --- Critical Section Start ---
        // Clear the shared task reference *now* so new calls can start a new refresh.
        refreshTask = nil

        // Atomically grab the current list of waiters and clear the shared list.
        let continuationsToResume = waitingContinuations
        waitingContinuations = []
        // --- Critical Section End ---

        LogManager.logInfo(
            "TokenRefreshCoordinator: Refresh task \(completedTask) completed (\(taskResult.isSuccess ? "Success" : "Failure")). Resuming \(continuationsToResume.count) waiting tasks."
        )

        // Resume all waiting continuations with the final result.
        // The AnyTypedContinuation wrapper handles transforming RefreshResult -> T.
        for continuation in continuationsToResume {
            continuation.resume(with: taskResult)
        }
    }
}

// MARK: - Result Extension Helper

extension Result {
    /// Helper property to check if a Result is .success.
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
