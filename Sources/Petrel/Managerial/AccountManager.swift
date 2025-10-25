//
//  AccountManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/22/2025.
//

import Foundation

/// Protocol defining the interface for account management.
protocol AccountManaging: Actor {
    /// Adds a new account.
    /// - Parameter account: The account to add.
    func addAccount(_ account: Account) async throws

    /// Gets an account by DID.
    /// - Parameter did: The DID of the account to retrieve.
    /// - Returns: The account if found, or nil if not found.
    func getAccount(did: String) async -> Account?

    /// Updates the AccountManager's state to reflect an account that was saved directly to storage.
    /// This is used when an account is saved atomically with its session to maintain consistency.
    /// - Parameter did: The DID of the account to update from storage.
    func updateAccountFromStorage(did: String) async throws

    /// Removes an account by DID.
    /// - Parameter did: The DID of the account to remove.
    func removeAccount(did: String) async throws

    /// Sets the current active account.
    /// - Parameter did: The DID of the account to set as current.
    func setCurrentAccount(did: String) async throws

    /// Gets the current active account.
    /// - Returns: The current account if available, or nil if not.
    func getCurrentAccount() async -> Account?

    /// Lists all available accounts.
    /// - Returns: An array of accounts.
    func listAccounts() async -> [Account]

    /// Clears the current active account without removing any stored accounts.
    func clearCurrentAccount() async

    /// Updates the service DIDs for the current account.
    /// - Parameters:
    ///   - bskyAppViewDID: The new AppView DID
    ///   - bskyChatDID: The new Chat DID
    func updateServiceDIDs(bskyAppViewDID: String, bskyChatDID: String) async throws
}

/// Actor responsible for managing user accounts.
actor AccountManager: AccountManaging {
    /// The storage layer for account data
    private let storage: KeychainStorage

    /// The current active DID
    private var currentDID: String?

    /// Whether to automatically switch to another account when the current one is removed.
    /// Defaults to true to preserve existing behavior. Can be toggled by higher-level services
    /// (e.g., AuthenticationService) to prevent unexpected account switching after logout.
    var autoSwitchOnRemoval: Bool = true

    /// Initializes a new AccountManager with the specified storage.
    /// - Parameter storage: The KeychainStorage instance to use for account data.
    init(storage: KeychainStorage) async {
        self.storage = storage

        // Attempt to load the last active DID
        do {
            currentDID = try await storage.getCurrentDID()
            LogManager.logInfo("AccountManager initialized with current DID: \(currentDID ?? "none")")

            // Perform startup recovery to detect and clean up inconsistent states
            await performStartupRecovery()
        } catch {
            LogManager.logError("AccountManager initialization - Failed to load current DID: \(error)")
        }
    }

    /// Performs startup recovery to detect and clean up inconsistent authentication states
    /// This method is called during initialization to ensure the authentication state is consistent
    private func performStartupRecovery() async {
        guard let did = currentDID, !did.isEmpty else {
            LogManager.logDebug("AccountManager - No current DID set, skipping startup recovery")
            return
        }

        LogManager.logDebug("AccountManager - Performing startup recovery for DID: \(LogManager.logDID(did))")

        // Check if the current DID has a corresponding account
        let account = await getAccount(did: did)
        var hasSession = false
        var hasDPoPKey = false

        // Check for session
        do {
            let session = try await storage.getSession(for: did)
            hasSession = session != nil
        } catch {
            LogManager.logDebug("AccountManager - Error checking session during startup recovery: \(error)")
            hasSession = false
        }

        // Check for DPoP key
        do {
            _ = try await storage.getDPoPKey(for: did)
            hasDPoPKey = true
        } catch {
            LogManager.logDebug("AccountManager - Error checking DPoP key during startup recovery: \(error)")
            hasDPoPKey = false
        }

        // Analyze the state and take corrective action
        if account == nil {
            LogManager.logError("AccountManager - Startup recovery detected inconsistent state: currentDID exists but no account found")

            // Log comprehensive state information
            LogManager.logAuthIncident(
                "StartupRecovery_InconsistentState",
                details: [
                    "did": LogManager.logDID(did),
                    "hasAccount": false,
                    "hasSession": hasSession,
                    "hasDPoPKey": hasDPoPKey,
                    "action": "clearing_inconsistent_state",
                ]
            )

            // Clear the inconsistent state
            await clearInconsistentAuthenticationState(for: did)

        } else if !hasSession {
            LogManager.logWarning("AccountManager - Startup recovery detected account without session", category: .authentication)

            LogManager.logAuthIncident(
                "StartupRecovery_MissingSession",
                details: [
                    "did": LogManager.logDID(did),
                    "hasAccount": true,
                    "hasSession": false,
                    "hasDPoPKey": hasDPoPKey,
                    "action": "warning_logged",
                ]
            )

        } else if !hasDPoPKey {
            LogManager.logWarning("AccountManager - Startup recovery detected account without DPoP key", category: .authentication)

            LogManager.logAuthIncident(
                "StartupRecovery_MissingDPoPKey",
                details: [
                    "did": LogManager.logDID(did),
                    "hasAccount": true,
                    "hasSession": hasSession,
                    "hasDPoPKey": false,
                    "action": "warning_logged",
                ]
            )

        } else {
            LogManager.logDebug("AccountManager - Startup recovery completed: authentication state appears consistent")

            LogManager.logAuthIncident(
                "StartupRecovery_StateHealthy",
                details: [
                    "did": LogManager.logDID(did),
                    "hasAccount": true,
                    "hasSession": hasSession,
                    "hasDPoPKey": hasDPoPKey,
                    "action": "no_action_needed",
                ]
            )
        }
    }

    // MARK: - AccountManaging Protocol Methods

    /// Adds a new account.
    /// - Parameter account: The account to add.
    func addAccount(_ account: Account) async throws {
        LogManager.logInfo("AccountManager - Adding account with DID: \(account.did)")
        try await storage.saveAccount(account, for: account.did)

        // If no current account is set, make this the current one
        if currentDID == nil {
            try await setCurrentAccount(did: account.did)
        }
    }

    /// Updates the AccountManager's state to reflect an account that was saved directly to storage.
    /// This is used when an account is saved atomically with its session to maintain consistency.
    /// - Parameter did: The DID of the account to update from storage.
    func updateAccountFromStorage(did: String) async throws {
        LogManager.logDebug("AccountManager - Updating internal state for DID from storage: \(did)")

        // Verify the account exists in storage
        guard let _ = try await storage.getAccount(for: did) else {
            LogManager.logError("AccountManager - Cannot update from storage, DID not found: \(did)")
            throw AccountError.accountNotFound
        }

        // Add the DID to accounts list if not already present (atomic save handles this)
        // This is mainly for consistency with the existing AccountManager state

        LogManager.logDebug("AccountManager - Successfully updated state for DID: \(did)")
    }

    /// Gets an account by DID.
    /// - Parameter did: The DID of the account to retrieve.
    /// - Returns: The account if found, or nil if not found.
    func getAccount(did: String) async -> Account? {
        do {
            return try await storage.getAccount(for: did)
        } catch {
            LogManager.logError("AccountManager - Failed to get account for DID \(did): \(error)")
            return nil
        }
    }

    /// Removes an account by DID.
    /// - Parameter did: The DID of the account to remove.
    func removeAccount(did: String) async throws {
        LogManager.logInfo("AccountManager - Removing account with DID: \(did)")

        // Delete the account from storage
        try await storage.deleteAccount(for: did)

        // If this was the current account, reset current DID
        if currentDID == did {
            currentDID = nil

            // Try to switch to another account if available, unless disabled
            let dids = try await storage.listAccountDIDs()
            if autoSwitchOnRemoval, let firstDID = dids.first {
                let previous = did
                try await setCurrentAccount(did: firstDID)
                LogManager.logWarning(
                    "🚨 CAT_AUTH_SWITCH: Auto-switched active account from \(LogManager.logDID(previous)) to \(LogManager.logDID(firstDID)) after removal.",
                    category: .authentication
                )
                LogManager.logAuthIncident(
                    "AccountAutoSwitchAfterRemoval",
                    details: [
                        "previousDid": previous,
                        "newDid": firstDID,
                        "autoSwitchOnRemoval": true,
                    ]
                )
                LogManager.logInfo("AccountManager - Switched to account with DID: \(firstDID)")
            } else {
                try await storage.saveCurrentDID("")
                LogManager.logInfo(
                    "AccountManager - Auto-switch disabled or no accounts left, cleared current DID"
                )
            }
        }

        // Delete related data
        try await storage.deleteSession(for: did)
        try await storage.deleteDPoPKey(for: did)
    }

    /// Sets the current active account.
    /// - Parameter did: The DID of the account to set as current.
    func setCurrentAccount(did: String) async throws {
        LogManager.logInfo("AccountManager - Setting current account to DID: \(did)")

        // Enhanced verification: Check account exists and validate its completeness
        guard let account = try await storage.getAccount(for: did) else {
            LogManager.logError("AccountManager - Cannot set current account, DID not found: \(did)")

            // Log this as an authentication incident for monitoring
            LogManager.logAuthIncident(
                "SetCurrentAccount_AccountNotFound",
                details: [
                    "did": LogManager.logDID(did),
                    "action": "setCurrentAccount_failed",
                ]
            )
            throw AccountError.accountNotFound
        }

        // Additional validation: Ensure the account has required fields
        guard !account.did.isEmpty else {
            LogManager.logError("AccountManager - Cannot set current account, account has invalid DID: \(did)")
            throw AccountError.invalidAccount
        }

        // Check if there's a session for this account (warn but don't fail)
        do {
            let session = try await storage.getSession(for: did)
            if session == nil {
                LogManager.logWarning(
                    "AccountManager - Setting account \(LogManager.logDID(did)) as current but no session exists. This may cause authentication issues.",
                    category: .authentication
                )

                // Log this as an authentication incident for monitoring
                LogManager.logAuthIncident(
                    "SetCurrentAccount_NoSession",
                    details: [
                        "did": LogManager.logDID(did),
                        "hasAccount": true,
                        "hasSession": false,
                    ]
                )
            }
        } catch {
            LogManager.logWarning("AccountManager - Failed to check session when setting current account for DID \(LogManager.logDID(did)): \(error)")
        }

        // Update the current DID in memory and storage atomically
        let previousDID = currentDID
        do {
            try await storage.saveCurrentDID(did)
            currentDID = did
            LogManager.logInfo("AccountManager - Successfully set current account to DID: \(LogManager.logDID(did))")

            if let previous = previousDID, previous != did {
                LogManager.logAuthIncident(
                    "CurrentAccountChanged",
                    details: [
                        "previousDid": LogManager.logDID(previous),
                        "newDid": LogManager.logDID(did),
                        "trigger": "setCurrentAccount",
                    ]
                )
            }
        } catch {
            LogManager.logError("AccountManager - Failed to save current DID to storage: \(error)")

            // Log this as an authentication incident for monitoring
            LogManager.logAuthIncident(
                "SetCurrentAccount_StorageFailed",
                details: [
                    "did": LogManager.logDID(did),
                    "error": error.localizedDescription,
                ]
            )
            throw AccountError.storageError
        }
    }

    /// Gets the current active account.
    /// - Returns: The current account if available, or nil if not.
    func getCurrentAccount() async -> Account? {
        guard let did = currentDID else {
            return nil
        }

        guard let account = await getAccount(did: did) else {
            LogManager.logError("AccountManager - Current DID \(did) exists but account not found in storage")

            // Enhanced cleanup: Clear the inconsistent state more aggressively
            await clearInconsistentAuthenticationState(for: did)
            return nil
        }

        // Validate that the account has a corresponding session
        do {
            let session = try await storage.getSession(for: did)
            if session == nil {
                LogManager.logWarning("AccountManager - Account \(LogManager.logDID(did)) exists but has no session token. This indicates an inconsistent authentication state.", category: .authentication)

                // Log this as an authentication incident for monitoring
                LogManager.logAuthIncident(
                    "InconsistentAuthState_MissingSession",
                    details: [
                        "did": LogManager.logDID(did),
                        "hasAccount": true,
                        "hasSession": false,
                    ]
                )
                // Don't clear the account automatically as it might be recoverable
                // Just log the inconsistency for monitoring purposes
            }
        } catch {
            LogManager.logError("AccountManager - Failed to check session for account \(LogManager.logDID(did)): \(error)")
        }

        return account
    }

    /// Clears inconsistent authentication state for a specific DID
    /// This method aggressively cleans up all traces of a DID that has a currentDID reference but no actual account
    private func clearInconsistentAuthenticationState(for did: String) async {
        LogManager.logError("AccountManager - Clearing inconsistent authentication state for DID: \(LogManager.logDID(did))")

        // Log this as an authentication incident for monitoring
        LogManager.logAuthIncident(
            "InconsistentAuthState_MissingAccount",
            details: [
                "did": LogManager.logDID(did),
                "hasAccount": false,
                "action": "clearing_state",
            ]
        )

        // Clear current DID
        currentDID = nil
        do {
            try await storage.saveCurrentDID("")
            LogManager.logDebug("AccountManager - Cleared currentDID from storage")
        } catch {
            LogManager.logError("AccountManager - Failed to clear currentDID from storage: \(error)")
        }

        // Clean up any orphaned session data
        do {
            try await storage.deleteSession(for: did)
            LogManager.logDebug("AccountManager - Cleaned up orphaned session for DID: \(LogManager.logDID(did))")
        } catch {
            LogManager.logDebug("AccountManager - No session to clean up for DID: \(LogManager.logDID(did)) or cleanup failed: \(error)")
        }

        // Clean up any orphaned DPoP keys
        do {
            try await storage.deleteDPoPKey(for: did)
            LogManager.logDebug("AccountManager - Cleaned up orphaned DPoP key for DID: \(LogManager.logDID(did))")
        } catch {
            LogManager.logDebug("AccountManager - No DPoP key to clean up for DID: \(LogManager.logDID(did)) or cleanup failed: \(error)")
        }

        // Clean up any DPoP nonces
        do {
            try await storage.saveDPoPNonces([:], for: did)
            try await storage.saveDPoPNoncesByJKT([:], for: did)
            LogManager.logDebug("AccountManager - Cleaned up DPoP nonces for DID: \(LogManager.logDID(did))")
        } catch {
            LogManager.logDebug("AccountManager - Failed to clean up DPoP nonces for DID: \(LogManager.logDID(did)): \(error)")
        }

        LogManager.logInfo("AccountManager - Completed cleanup of inconsistent authentication state for DID: \(LogManager.logDID(did))")
    }

    /// Lists all available accounts.
    /// - Returns: An array of accounts.
    func listAccounts() async -> [Account] {
        do {
            let dids = try await storage.listAccountDIDs()
            var accounts: [Account] = []

            for did in dids {
                if let account = await getAccount(did: did) {
                    accounts.append(account)
                }
            }

            return accounts
        } catch {
            LogManager.logError("AccountManager - Failed to list accounts: \(error)")
            return []
        }
    }

    /// Clears the current active account without removing any stored accounts.
    /// Useful when a logout should not implicitly switch to another account.
    /// Updates the service DIDs for the current account.
    /// - Parameters:
    ///   - bskyAppViewDID: The new AppView DID
    ///   - bskyChatDID: The new Chat DID
    func updateServiceDIDs(bskyAppViewDID: String, bskyChatDID: String) async throws {
        guard let did = currentDID else {
            LogManager.logError("AccountManager - Cannot update service DIDs: No active account")
            throw AccountError.noActiveAccount
        }

        guard var account = try await storage.getAccount(for: did) else {
            LogManager.logError("AccountManager - Cannot update service DIDs: Account not found for DID \(did)")
            throw AccountError.accountNotFound
        }

        // Update the DIDs
        account.bskyAppViewDID = bskyAppViewDID
        account.bskyChatDID = bskyChatDID

        // Save back to storage
        try await storage.saveAccount(account, for: did)

        LogManager.logInfo("AccountManager - Updated service DIDs for account \(LogManager.logDID(did)): bskyAppViewDID=\(bskyAppViewDID), bskyChatDID=\(bskyChatDID)")
    }

    func clearCurrentAccount() async {
        let previous = currentDID
        currentDID = nil
        do {
            try await storage.saveCurrentDID("")
            LogManager.logWarning(
                "🚪 CAT_AUTH_LOGOUT: Cleared current active account (was=\(LogManager.logDID(previous))) without switching",
                category: .authentication
            )
            LogManager.logAuthIncident(
                "LogoutClearedCurrentAccount",
                details: [
                    "previousDid": previous ?? "",
                ]
            )
        } catch {
            LogManager.logError("AccountManager - Failed to clear current DID: \(error)")
        }
    }
}

/// Errors that can occur during account operations.
enum AccountError: Error, LocalizedError {
    case accountNotFound
    case accountExists
    case invalidAccount
    case storageError
    case noActiveAccount

    var errorDescription: String? {
        switch self {
        case .accountNotFound:
            return "Account not found."
        case .accountExists:
            return "Account already exists."
        case .invalidAccount:
            return "Invalid account data."
        case .storageError:
            return "Failed to store account information."
        case .noActiveAccount:
            return "No active account."
        }
    }

    var failureReason: String? {
        switch self {
        case .accountNotFound:
            return "The requested account does not exist in the local storage."
        case .accountExists:
            return "An account with the same identifier is already stored."
        case .invalidAccount:
            return "The account data is missing required fields or contains invalid values."
        case .storageError:
            return "Unable to save account data to secure storage."
        case .noActiveAccount:
            return "No active account is currently selected."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .accountNotFound:
            return "Please ensure the account handle is correct and try logging in again."
        case .accountExists:
            return "You may need to log out of the existing account first, or use a different handle."
        case .invalidAccount:
            return "Please check your login credentials and try again."
        case .storageError:
            return "Check that you have sufficient storage space and try again. If the problem persists, restart the app."
        case .noActiveAccount:
            return "Please log in to an account first."
        }
    }
}
