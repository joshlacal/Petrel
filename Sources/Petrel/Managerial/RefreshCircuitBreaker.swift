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
        case nonceRecoverable // use_dpop_nonce: retried and typically succeeds
        case network // timeouts, connectivity
        case server // 5xx, unexpected server responses
        case invalidGrant // refresh token revoked/expired
        case invalidDPoPProof // wrong key, bad ath, htm/htu mismatch
        case metadataUnavailable // OAuth metadata endpoint unreachable
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
        var backoffExponent: Int = 0 // For exponential backoff
        var lastFailureKind: RefreshFailureKind? = nil
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
            // Check if enough time has passed to try again with exponential backoff
            if let lastFailure = info.lastFailureTime {
                let backoffInterval = calculateBackoffInterval(for: info)
                if Date().timeIntervalSince(lastFailure) >= backoffInterval {
                    // Transition to half-open state
                    var updatedInfo = info
                    updatedInfo.state = .halfOpen
                    updatedInfo.halfOpenTestInProgress = false
                    failureTracking[did] = updatedInfo

                    LogManager.logInfo(
                        "RefreshCircuitBreaker: Circuit transitioning to half-open for DID \(LogManager.logDID(did)) after \(Int(backoffInterval))s backoff"
                    )
                    return true
                }
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
        info.backoffExponent = 0 // Reset backoff on success
        info.lastFailureKind = nil

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
            info.backoffExponent = min(info.backoffExponent + 2, 6) // Faster escalation for serious failures
        case .metadataUnavailable:
            info.consecutiveFailures += 1 // Standard weight but longer backoff for server issues
            info.backoffExponent = min(info.backoffExponent + 1, 8) // Longer max backoff for server issues
        case .network, .server, .other:
            info.consecutiveFailures += 1
            info.backoffExponent = min(info.backoffExponent + 1, 5) // Standard escalation
        }
        info.lastFailureTime = Date()
        info.lastFailureKind = kind

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

    /// Calculates the backoff interval for a specific failure info
    /// Uses exponential backoff with jitter and different base intervals based on failure type
    private func calculateBackoffInterval(for info: FailureInfo) -> TimeInterval {
        let baseInterval: TimeInterval

        switch info.lastFailureKind {
        case .metadataUnavailable:
            baseInterval = 60.0 // 1 minute base for server issues
        case .invalidGrant, .invalidDPoPProof:
            baseInterval = 300.0 // 5 minutes base for serious auth issues
        case .network, .server:
            baseInterval = 30.0 // 30 seconds base for network issues
        default:
            baseInterval = resetInterval // Use default reset interval
        }

        let exponentialBackoff = baseInterval * pow(2.0, Double(min(info.backoffExponent, 6)))

        // Add jitter (±25%) to prevent thundering herd
        let jitter = Double.random(in: 0.75...1.25)
        let finalInterval = exponentialBackoff * jitter

        // Cap at reasonable maximums based on failure type
        let maxInterval: TimeInterval
        switch info.lastFailureKind {
        case .metadataUnavailable:
            maxInterval = 3600.0 // 1 hour max for server issues
        case .invalidGrant, .invalidDPoPProof:
            maxInterval = 7200.0 // 2 hours max for auth issues
        default:
            maxInterval = 1800.0 // 30 minutes max for others
        }

        return min(finalInterval, maxInterval)
    }

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
