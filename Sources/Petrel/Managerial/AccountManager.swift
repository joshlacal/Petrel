//
//  AccountManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 3/26/25.
//

import Foundation

/// Structure to hold data specific to a single user account.
struct AccountData: Codable, Sendable {
    let did: String
    var handle: String?
    var pdsURL: URL?
    var isActive: Bool = false
    // Add other account-specific details as needed, e.g., profile info
}

/// Error types specific to account management operations
enum AccountManagerError: Error {
    case accountNotFound
    case noActiveAccount
    case accountAlreadyExists
    case invalidAccountData
    case keychainError(Error)
    case cannotRemoveLastAccount
}

/// Protocol defining the interface for managing multiple user accounts.
protocol AccountManaging: Actor {
    /// Retrieves the DID of the currently active account.
    /// - Returns: The DID string of the active account, or nil if no account is active.
    func getActiveAccountDID() async -> String?

    /// Switches the active account to the one specified by the DID.
    /// - Parameter did: The DID of the account to make active.
    /// - Throws: An error if the account with the given DID doesn't exist.
    func switchAccount(to did: String) async throws

    /// Adds or updates an account's data. If an account with the same DID exists, it's updated.
    /// - Parameter accountData: The `AccountData` to add or update.
    func addOrUpdateAccount(_ accountData: AccountData) async throws

    /// Removes an account identified by its DID.
    /// - Parameter did: The DID of the account to remove.
    /// - Throws: An error if the account cannot be removed (e.g., trying to remove the last account).
    func removeAccount(did: String) async throws

    /// Retrieves the data for a specific account.
    /// - Parameter did: The DID of the account to retrieve.
    /// - Returns: The `AccountData` for the specified account, or nil if not found.
    func getAccount(did: String) async -> AccountData?

    /// Retrieves data for all managed accounts.
    /// - Returns: An array of `AccountData` for all accounts.
    func getAllAccounts() async -> [AccountData]

    /// Retrieves the DIDs of all managed accounts.
    /// - Returns: An array of DID strings.
    func listAccountDIDs() async -> [String]

    /// Clears all account data, including Keychain entries associated with each account.
    func clearAllAccounts() async throws
}

/// Actor responsible for managing multiple user accounts, their data, and the active session.
actor AccountManager: AccountManaging {
    // MARK: - Properties

    private var accounts: [String: AccountData] = [:] // Keyed by DID
    private var activeAccountDID: String?

    private let accountsKeychainKey = "managedAccounts" // Key for storing the list of account DIDs
    private let activeAccountKeychainKey = "activeAccountDID" // Key for storing the active DID
    private let accountDataKeychainPrefix = "accountData." // Prefix for storing individual account data

    // MARK: - Initialization
    
    init() async {
        LogManager.logDebug(">>> AccountManager.init STARTING")
        await loadAccounts()
        LogManager.logDebug("<<< AccountManager.init FINISHED")
    }

    // MARK: - Private Methods
    
    private func loadAccounts() async {
        LogManager.logDebug(">>> AccountManager.loadAccounts STARTING")
        do {
            // Load the list of managed accounts
            LogManager.logDebug("AccountManager - Attempting to load managed accounts list...")
            if let accountsData = try? KeychainManager.retrieve(key: accountsKeychainKey, namespace: "accounts") {
                let dids = try JSONDecoder().decode([String].self, from: accountsData)

                // Load each account's data
                for did in dids {
                    if let accountData = try? KeychainManager.retrieve(key: "\(accountDataKeychainPrefix)\(did)", namespace: "accounts") {
                        if let account = try? JSONDecoder().decode(AccountData.self, from: accountData) {
                            accounts[did] = account
                        }
                    }
                }
            }

            // Load active account DID
            if let activeDidData = try? KeychainManager.retrieve(key: activeAccountKeychainKey, namespace: "accounts"),
               let activeDid = String(data: activeDidData, encoding: .utf8)
            {
                activeAccountDID = activeDid
            }

            LogManager.logInfo("AccountManager - Loaded \(accounts.count) accounts")
        } catch {
            LogManager.logError("AccountManager - Failed to load accounts: \(error)")
        }
        LogManager.logDebug("<<< AccountManager.loadAccounts FINISHED")
    }

    private func saveManagedAccountList() async throws {
        let dids = Array(accounts.keys)
        let data = try JSONEncoder().encode(dids)
        try KeychainManager.store(key: accountsKeychainKey, value: data, namespace: "accounts")
        LogManager.logInfo("AccountManager - Saved managed accounts list with \(dids.count) accounts")
    }

    private func saveAccountData(_ accountData: AccountData) async throws {
        let data = try JSONEncoder().encode(accountData)
        try KeychainManager.store(key: "\(accountDataKeychainPrefix)\(accountData.did)", value: data, namespace: "accounts")
        LogManager.logInfo("AccountManager - Saved data for account: \(accountData.did)")
    }

    private func saveActiveAccountDID(_ did: String) async throws {
        guard let data = did.data(using: .utf8) else {
            throw AccountManagerError.invalidAccountData
        }
        try KeychainManager.store(key: activeAccountKeychainKey, value: data, namespace: "accounts")
        LogManager.logInfo("AccountManager - Saved active account DID: \(did)")
    }

    // MARK: - AccountManaging Protocol Methods

    func getActiveAccountDID() async -> String? {
        return activeAccountDID
    }

    func switchAccount(to did: String) async throws {
        guard accounts[did] != nil else {
            LogManager.logError("AccountManager - Attempted to switch to non-existent account: \(did)")
            throw AccountManagerError.accountNotFound
        }

        let previousActiveDID = activeAccountDID
        activeAccountDID = did

        // Update isActive flags
        if let previousDID = previousActiveDID {
            accounts[previousDID]?.isActive = false
        }
        accounts[did]?.isActive = true

        // Persist the new active DID
        try await saveActiveAccountDID(did)

        // Save account data to persist isActive flag changes
        if let previousAccount = accounts[previousActiveDID ?? ""] {
            try await saveAccountData(previousAccount)
        }
        if let newActiveAccount = accounts[did] {
            try await saveAccountData(newActiveAccount)
        }

        LogManager.logInfo("AccountManager - Switched active account to: \(did)")
        await EventBus.shared.publish(.activeAccountChanged(did: did))
    }

    func addOrUpdateAccount(_ accountData: AccountData) async throws {
        let did = accountData.did
        let isNewAccount = accounts[did] == nil
        accounts[did] = accountData

        // Persist the account data
        try await saveAccountData(accountData)
        try await saveManagedAccountList()

        if isNewAccount {
            LogManager.logInfo("AccountManager - Added new account: \(did)")
            // If this is the first account, make it active
            if accounts.count == 1 {
                try await switchAccount(to: did)
            }
        } else {
            LogManager.logInfo("AccountManager - Updated account: \(did)")
        }
    }

    func removeAccount(did: String) async throws {
        guard accounts.count > 1 || did != activeAccountDID else {
            throw AccountManagerError.cannotRemoveLastAccount
        }

        // If removing active account, switch to another account first
        if did == activeAccountDID {
            if let newActiveDID = accounts.keys.first(where: { $0 != did }) {
                try await switchAccount(to: newActiveDID)
            }
        }

        accounts.removeValue(forKey: did)

        // Remove account data from keychain
        try KeychainManager.delete(key: "\(accountDataKeychainPrefix)\(did)", namespace: "accounts")
        try await saveManagedAccountList()

        LogManager.logInfo("AccountManager - Removed account: \(did)")
    }

    func getAccount(did: String) async -> AccountData? {
        return accounts[did]
    }

    func getAllAccounts() async -> [AccountData] {
        return Array(accounts.values)
    }

    func listAccountDIDs() async -> [String] {
        return Array(accounts.keys)
    }

    func clearAllAccounts() async throws {
        // Remove all account data from keychain
        for did in accounts.keys {
            try KeychainManager.delete(key: "\(accountDataKeychainPrefix)\(did)", namespace: "accounts")
        }

        // Clear managed accounts list and active account
        try KeychainManager.delete(key: accountsKeychainKey, namespace: "accounts")
        try KeychainManager.delete(key: activeAccountKeychainKey, namespace: "accounts")

        accounts.removeAll()
        activeAccountDID = nil

        LogManager.logInfo("AccountManager - Cleared all accounts")
    }
}
