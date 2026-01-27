//
//  AccountSwitchCoordinator.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/8/25.
//

import Foundation

/// Actor that coordinates account switching operations across multiple components
/// to ensure atomicity and prevent race conditions during the switch process.
actor AccountSwitchCoordinator {
    // Singleton instance
    static let shared = AccountSwitchCoordinator()

    // Switch state
    private var isSwitchingAccounts = false
    private var waitingTasks: [CheckedContinuation<Void, Error>] = []

    private init() {}

    /// Checks if account switching is in progress.
    /// - Returns: True if account switching is currently in progress
    func isAccountSwitchInProgress() -> Bool {
        return isSwitchingAccounts
    }

    /// Begins an account switching operation, acquiring the lock.
    /// If another switch is in progress, this method will throw an error.
    ///
    /// - Parameter fromDID: The DID of the account being switched from
    /// - Parameter toDID: The DID of the account being switched to
    /// - Throws: AccountSwitchError.switchInProgress if another switch is already happening
    func beginAccountSwitch(fromDID: String?, toDID: String) throws {
        guard !isSwitchingAccounts else {
            throw AccountSwitchError.switchInProgress
        }

        isSwitchingAccounts = true
        LogManager.logInfo(
            "AccountSwitchCoordinator - Beginning account switch from \(fromDID ?? "nil") to \(toDID)")
    }

    /// Completes an account switching operation, releasing the lock.
    func completeAccountSwitch() {
        LogManager.logInfo("AccountSwitchCoordinator - Account switch completed")
        isSwitchingAccounts = false

        // Notify any waiting tasks that they can proceed
        let waiters = waitingTasks
        waitingTasks = []

        for continuation in waiters {
            continuation.resume()
        }
    }

    /// Handles an error during account switching by releasing the lock and cleaning up
    ///
    /// - Parameter error: The error that occurred during switching
    func handleSwitchError(_ error: Error) {
        LogManager.logError("AccountSwitchCoordinator - Account switch failed with error: \(error)")
        completeAccountSwitch()
    }

    /// Waits for any in-progress account switch to complete before proceeding
    ///
    /// - Throws: Error if waiting is interrupted
    func waitForSwitchToComplete() async throws {
        guard isSwitchingAccounts else {
            return // No need to wait if no switch is in progress
        }

        // Wait for the switch to complete
        try await withCheckedThrowingContinuation { continuation in
            waitingTasks.append(continuation)
        }
    }
}

/// Errors specific to account switching
enum AccountSwitchError: Error, LocalizedError {
    case switchInProgress
    case failedToSynchronizeState
    case failedToLoadMetadata
    case invalidDPoP

    var errorDescription: String? {
        switch self {
        case .switchInProgress:
            return "Another account switch is already in progress"
        case .failedToSynchronizeState:
            return "Failed to synchronize state across all components"
        case .failedToLoadMetadata:
            return "Failed to load or update account metadata"
        case .invalidDPoP:
            return "Invalid DPoP key binding detected"
        }
    }
}
