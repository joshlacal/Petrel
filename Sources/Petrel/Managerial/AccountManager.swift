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
        } catch {
            LogManager.logError("AccountManager initialization - Failed to load current DID: \(error)")
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

        // Verify the account exists
        guard let _ = try await storage.getAccount(for: did) else {
            LogManager.logError("AccountManager - Cannot set current account, DID not found: \(did)")
            throw AccountError.accountNotFound
        }

        // Update the current DID in memory and storage
        currentDID = did
        try await storage.saveCurrentDID(did)
    }

    /// Gets the current active account.
    /// - Returns: The current account if available, or nil if not.
    func getCurrentAccount() async -> Account? {
        guard let did = currentDID else {
            return nil
        }

        guard let account = await getAccount(did: did) else {
            LogManager.logError("AccountManager - Current DID \(did) exists but account not found in storage")
            // Clear the current DID if the account doesn't exist
            currentDID = nil
            try? await storage.saveCurrentDID("")
            return nil
        }

        // Validate that the account has a corresponding session
        do {
            let session = try await storage.getSession(for: did)
            if session == nil {
                LogManager.logWarning("AccountManager - Account \(LogManager.logDID(did)) exists but has no session token. This indicates an inconsistent authentication state.", category: .authentication)
                // Don't clear the account automatically as it might be recoverable
                // Just log the inconsistency for monitoring purposes
            }
        } catch {
            LogManager.logError("AccountManager - Failed to check session for account \(LogManager.logDID(did)): \(error)")
        }

        return account
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
        }
    }
}
