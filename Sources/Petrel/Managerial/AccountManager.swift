//
//  AccountManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/22/2025.
//

import Foundation

/// Protocol defining the interface for account management.
public protocol AccountManaging: Actor {
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
}

/// Actor responsible for managing user accounts.
public actor AccountManager: AccountManaging {
    /// The storage layer for account data
    private let storage: KeychainStorage

    /// The current active DID
    private var currentDID: String?

    /// Initializes a new AccountManager with the specified storage.
    /// - Parameter storage: The KeychainStorage instance to use for account data.
    public init(storage: KeychainStorage) async {
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
    public func addAccount(_ account: Account) async throws {
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
    public func getAccount(did: String) async -> Account? {
        do {
            return try await storage.getAccount(for: did)
        } catch {
            LogManager.logError("AccountManager - Failed to get account for DID \(did): \(error)")
            return nil
        }
    }

    /// Removes an account by DID.
    /// - Parameter did: The DID of the account to remove.
    public func removeAccount(did: String) async throws {
        LogManager.logInfo("AccountManager - Removing account with DID: \(did)")

        // Delete the account from storage
        try await storage.deleteAccount(for: did)

        // If this was the current account, reset current DID
        if currentDID == did {
            currentDID = nil

            // Try to switch to another account if available
            let dids = try await storage.listAccountDIDs()
            if let firstDID = dids.first {
                try await setCurrentAccount(did: firstDID)
                LogManager.logInfo("AccountManager - Switched to account with DID: \(firstDID)")
            } else {
                try await storage.saveCurrentDID("")
                LogManager.logInfo("AccountManager - No accounts left, cleared current DID")
            }
        }

        // Delete related data
        try await storage.deleteSession(for: did)
        try await storage.deleteDPoPKey(for: did)
    }

    /// Sets the current active account.
    /// - Parameter did: The DID of the account to set as current.
    public func setCurrentAccount(did: String) async throws {
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
    public func getCurrentAccount() async -> Account? {
        guard let did = currentDID else {
            return nil
        }

        return await getAccount(did: did)
    }

    /// Lists all available accounts.
    /// - Returns: An array of accounts.
    public func listAccounts() async -> [Account] {
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
}

/// Errors that can occur during account operations.
public enum AccountError: Error {
    case accountNotFound
    case accountExists
    case invalidAccount
    case storageError
}
