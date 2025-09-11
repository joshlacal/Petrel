//
//  RefreshCircuitBreaker.swift
//  Petrel
//
//  Created by Assistant on 7/29/25.
//

import Foundation

/// Actor responsible for implementing circuit breaker pattern for token refresh operations
/// to prevent cascade failures when refresh operations repeatedly fail.
actor RefreshCircuitBreaker {
    // Classify refresh failures for better breaker decisions
    enum RefreshFailureKind {
        case nonceRecoverable      // use_dpop_nonce: retried and typically succeeds
        case network               // timeouts, connectivity
        case server                // 5xx, unexpected server responses
        case invalidGrant          // refresh token revoked/expired
        case invalidDPoPProof      // wrong key, bad ath, htm/htu mismatch
        case other
    }
    // MARK: - Types

    /// Circuit breaker states
    enum State {
        case closed // Normal operation
        case open // Failures exceeded threshold, blocking requests
        case halfOpen // Testing if service recovered
    }

    /// Tracks failure information for a specific DID
    private struct FailureInfo {
        var consecutiveFailures: Int = 0
        var lastFailureTime: Date?
        var state: State = .closed
        var halfOpenTestInProgress: Bool = false
    }

    // MARK: - Properties

    /// Failure tracking per DID
    private var failureTracking: [String: FailureInfo] = [:]

    /// Maximum consecutive failures before opening circuit
    private let maxConsecutiveFailures = 3

    /// Time to wait before attempting recovery (5 minutes)
    private let resetInterval: TimeInterval = 300

    /// Time to wait in half-open state before closing circuit (30 seconds)
    private let halfOpenTimeout: TimeInterval = 30

    /// Cleanup task for expired failure records
    private var cleanupTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        // Cleanup task will be started on first use
    }

    deinit {
        cleanupTask?.cancel()
    }

    // MARK: - Public Methods

    /// Checks if refresh attempts should be allowed for the given DID
    /// - Parameter did: The DID to check
    /// - Returns: True if refresh can be attempted, false if circuit is open
    func canAttemptRefresh(for did: String) -> Bool {
        // Start cleanup task on first use if needed
        if cleanupTask == nil {
            cleanupTask = Task {
                while !Task.isCancelled {
                    // Run cleanup every 10 minutes
                    try? await Task.sleep(nanoseconds: 600_000_000_000)

                    await cleanupStaleRecords()
                }
            }
        }

        let info = failureTracking[did] ?? FailureInfo()

        switch info.state {
        case .closed:
            return true

        case .open:
            // Check if enough time has passed to try again
            if let lastFailure = info.lastFailureTime,
               Date().timeIntervalSince(lastFailure) >= resetInterval
            {
                // Transition to half-open state
                var updatedInfo = info
                updatedInfo.state = .halfOpen
                updatedInfo.halfOpenTestInProgress = false
                failureTracking[did] = updatedInfo

                LogManager.logInfo(
                    "RefreshCircuitBreaker: Circuit transitioning to half-open for DID \(LogManager.logDID(did))"
                )
                return true
            }
            return false

        case .halfOpen:
            // Only allow one test request in half-open state
            if info.halfOpenTestInProgress {
                return false
            }

            // Mark test as in progress
            var updatedInfo = info
            updatedInfo.halfOpenTestInProgress = true
            failureTracking[did] = updatedInfo
            return true
        }
    }

    /// Records a successful refresh operation
    /// - Parameter did: The DID that succeeded
    func recordSuccess(for did: String) {
        guard var info = failureTracking[did] else { return }

        let previousState = info.state
        info.consecutiveFailures = 0
        info.lastFailureTime = nil
        info.state = .closed
        info.halfOpenTestInProgress = false

        if previousState != .closed {
            LogManager.logInfo(
                "RefreshCircuitBreaker: Circuit closed for DID \(LogManager.logDID(did)) after successful refresh"
            )
        }

        failureTracking[did] = info
    }

    /// Records a failed refresh operation with classification.
    /// - Parameters:
    ///   - did: The DID that failed
    ///   - kind: Failure classification
    func recordFailure(for did: String, kind: RefreshFailureKind = .other) {
        var info = failureTracking[did] ?? FailureInfo()

        switch kind {
        case .nonceRecoverable:
            // Do not count recoverable nonce rotations toward opening the circuit
            break
        case .invalidGrant, .invalidDPoPProof:
            info.consecutiveFailures += 2 // heavier weight for serious failures
        case .network, .server, .other:
            info.consecutiveFailures += 1
        }
        info.lastFailureTime = Date()

        switch info.state {
        case .closed:
            if info.consecutiveFailures >= maxConsecutiveFailures {
                info.state = .open
                LogManager.logError(
                    "RefreshCircuitBreaker: Circuit opened for DID \(LogManager.logDID(did)) after \(info.consecutiveFailures) consecutive failures",
                    category: .authentication
                )
                LogManager.logInfo("METRIC circuit_open_total reason=refresh_failures did=\(LogManager.logDID(did))")
            } else {
                LogManager.logInfo(
                    "RefreshCircuitBreaker: Recorded failure \(info.consecutiveFailures)/\(maxConsecutiveFailures) for DID \(LogManager.logDID(did))"
                )
            }

        case .halfOpen:
            // Test failed, go back to open
            info.state = .open
            info.halfOpenTestInProgress = false
            LogManager.logError(
                "RefreshCircuitBreaker: Circuit re-opened for DID \(LogManager.logDID(did)) after half-open test failed",
                category: .authentication
            )

        case .open:
            // Already open, just update failure count
            LogManager.logDebug(
                "RefreshCircuitBreaker: Additional failure recorded for already-open circuit (DID: \(LogManager.logDID(did)))"
            )
        }

        failureTracking[did] = info
    }

    /// Gets the current state of the circuit breaker for a DID
    /// - Parameter did: The DID to check
    /// - Returns: The current circuit state
    func getState(for did: String) -> State {
        let info = failureTracking[did] ?? FailureInfo()
        return info.state
    }

    /// Resets the circuit breaker for a specific DID
    /// - Parameter did: The DID to reset
    func reset(for did: String) {
        failureTracking.removeValue(forKey: did)
        LogManager.logInfo(
            "RefreshCircuitBreaker: Reset circuit for DID \(LogManager.logDID(did))"
        )
    }

    /// Resets all circuit breakers
    func resetAll() {
        let count = failureTracking.count
        failureTracking.removeAll()
        LogManager.logInfo(
            "RefreshCircuitBreaker: Reset all \(count) circuits"
        )
    }

    // MARK: - Private Methods

    /// Removes failure records that haven't been updated in a long time
    private func cleanupStaleRecords() {
        let now = Date()
        let staleThreshold: TimeInterval = 3600 // 1 hour
        var removedCount = 0

        for (did, info) in failureTracking {
            if let lastFailure = info.lastFailureTime,
               now.timeIntervalSince(lastFailure) > staleThreshold,
               info.state == .closed
            {
                failureTracking.removeValue(forKey: did)
                removedCount += 1
            }
        }

        if removedCount > 0 {
            LogManager.logDebug(
                "RefreshCircuitBreaker: Cleaned up \(removedCount) stale records"
            )
        }
    }
}
