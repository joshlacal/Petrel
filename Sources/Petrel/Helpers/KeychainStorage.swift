//
//  KeychainStorage.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/22/2025.
//

import CryptoKit
import Foundation

/// A centralized storage layer for securely storing all persistent data using the keychain.
public actor KeychainStorage {
    let namespace: String
    private let accessGroup: String?

    /// Initializes a new KeychainStorage instance.
    /// - Parameters:
    ///   - namespace: A unique identifier for this application's keychain items
    ///   - accessGroup: Optional access group for keychain sharing between apps
    public init(namespace: String, accessGroup: String? = nil) {
        self.namespace = namespace
        self.accessGroup = accessGroup
    }

    // MARK: - Account Management

    /// Saves an account to the keychain.
    /// - Parameters:
    ///   - account: The account to save
    ///   - did: The DID of the account
    public func saveAccount(_ account: Account, for did: String) async throws {
        let key = makeKey("account", did: did)
        let data = try JSONEncoder().encode(account)
        try KeychainManager.store(key: key, value: data, namespace: namespace)

        // Add to the accounts list if not already present
        try await addToAccountsList(did)
    }

    /// Retrieves an account from the keychain.
    /// - Parameter did: The DID of the account to retrieve
    /// - Returns: The account if found, or nil if not found
    public func getAccount(for did: String) async throws -> Account? {
        let key = makeKey("account", did: did)
        do {
            let data = try KeychainManager.retrieve(key: key, namespace: namespace)
            return try JSONDecoder().decode(Account.self, from: data)
        } catch {
            return nil
        }
    }

    /// Deletes an account from the keychain.
    /// - Parameter did: The DID of the account to delete
    public func deleteAccount(for did: String) async throws {
        let key = makeKey("account", did: did)
        try KeychainManager.delete(key: key, namespace: namespace)

        // Remove from the accounts list
        try await removeFromAccountsList(did)
    }

    /// Lists all account DIDs stored in the keychain.
    /// - Returns: An array of DIDs
    public func listAccountDIDs() async throws -> [String] {
        let key = makeKey("accountDIDs")
        do {
            let data = try KeychainManager.retrieve(key: key, namespace: namespace)
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            return []
        }
    }

    /// Saves the current DID to the keychain.
    /// - Parameter did: The DID to save as current
    public func saveCurrentDID(_ did: String) async throws {
        let key = makeKey("currentDID")
        let data = did.data(using: .utf8) ?? Data()
        try KeychainManager.store(key: key, value: data, namespace: namespace)
    }

    /// Retrieves the current DID from the keychain.
    /// - Returns: The current DID if found, or nil if not found
    public func getCurrentDID() async throws -> String? {
        let key = makeKey("currentDID")
        do {
            let data = try KeychainManager.retrieve(key: key, namespace: namespace)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    // MARK: - Session Management

    /// Saves a session to the keychain.
    /// - Parameters:
    ///   - session: The session to save
    ///   - did: The DID associated with the session
    public func saveSession(_ session: Session, for did: String) async throws {
        let key = makeKey("session", did: did)
        let tempKey = makeKey("session.temp", did: did)
        let backupKey = makeKey("session.backup", did: did)
        let data = try JSONEncoder().encode(session)

        // Improved atomic save operation with better error handling and recovery
        do {
            // Step 1: Create backup of existing session if it exists
            if let existingData = try? KeychainManager.retrieve(key: key, namespace: namespace) {
                try KeychainManager.store(key: backupKey, value: existingData, namespace: namespace)
                LogManager.logDebug("Session backup created for DID: \(did)")
            }

            // Step 2: Save to temporary location first
            try KeychainManager.store(key: tempKey, value: data, namespace: namespace)
            LogManager.logDebug("Session saved to temporary location for DID: \(did)")

            // Step 3: Atomic move to final location
            try KeychainManager.store(key: key, value: data, namespace: namespace)
            LogManager.logDebug("Session moved to final location for DID: \(did)")

            // Step 4: Verify the save was successful by reading it back
            let verificationData = try KeychainManager.retrieve(key: key, namespace: namespace)
            let verifiedSession = try JSONDecoder().decode(Session.self, from: verificationData)
            
            // Basic verification that the session has required fields
            guard !verifiedSession.accessToken.isEmpty else {
                throw KeychainError.dataFormatError
            }
            
            LogManager.logDebug("Session save verification successful for DID: \(did)")

            // Step 5: Cleanup temporary files
            try? KeychainManager.delete(key: tempKey, namespace: namespace)
            try? KeychainManager.delete(key: backupKey, namespace: namespace)
            
            LogManager.logDebug("Session saved atomically and verified for DID: \(did)")
            
        } catch {
            LogManager.logError("Session save failed for DID: \(did), error: \(error)")
            
            // Recovery: Attempt to restore from backup if final save failed
            if let backupData = try? KeychainManager.retrieve(key: backupKey, namespace: namespace) {
                do {
                    try KeychainManager.store(key: key, value: backupData, namespace: namespace)
                    LogManager.logDebug("Session restored from backup for DID: \(did)")
                } catch {
                    LogManager.logError("Failed to restore session backup for DID: \(did), error: \(error)")
                }
            }
            
            // Cleanup temporary files in error case
            try? KeychainManager.delete(key: tempKey, namespace: namespace)
            try? KeychainManager.delete(key: backupKey, namespace: namespace)
            
            throw error
        }
    }

    /// Retrieves a session from the keychain.
    /// - Parameter did: The DID associated with the session to retrieve
    /// - Returns: The session if found, or nil if not found
    public func getSession(for did: String) async throws -> Session? {
        let key = makeKey("session", did: did)
        let tempKey = makeKey("session.temp", did: did)
        let backupKey = makeKey("session.backup", did: did)
        
        do {
            let data = try KeychainManager.retrieve(key: key, namespace: namespace)
            return try JSONDecoder().decode(Session.self, from: data)
        } catch {
            LogManager.logDebug("Failed to retrieve session from primary location for DID: \(LogManager.logDID(did)), attempting recovery")
            
            // Try to recover from temporary location if primary failed
            if let tempData = try? KeychainManager.retrieve(key: tempKey, namespace: namespace) {
                do {
                    let session = try JSONDecoder().decode(Session.self, from: tempData)
                    LogManager.logDebug("Session recovered from temporary location for DID: \(LogManager.logDID(did))")
                    
                    // Try to restore to primary location
                    try? KeychainManager.store(key: key, value: tempData, namespace: namespace)
                    try? KeychainManager.delete(key: tempKey, namespace: namespace)
                    
                    return session
                } catch {
                    LogManager.logError("Failed to decode session from temporary location for DID: \(LogManager.logDID(did))")
                }
            }
            
            // Try to recover from backup location if primary and temp failed
            if let backupData = try? KeychainManager.retrieve(key: backupKey, namespace: namespace) {
                do {
                    let session = try JSONDecoder().decode(Session.self, from: backupData)
                    LogManager.logDebug("Session recovered from backup location for DID: \(LogManager.logDID(did))")
                    
                    // Try to restore to primary location
                    try? KeychainManager.store(key: key, value: backupData, namespace: namespace)
                    try? KeychainManager.delete(key: backupKey, namespace: namespace)
                    
                    return session
                } catch {
                    LogManager.logError("Failed to decode session from backup location for DID: \(LogManager.logDID(did))")
                }
            }
            
            return nil
        }
    }

    /// Deletes a session from the keychain.
    /// - Parameter did: The DID associated with the session to delete
    public func deleteSession(for did: String) async throws {
        let key = makeKey("session", did: did)
        try KeychainManager.delete(key: key, namespace: namespace)
    }

    // MARK: - DPoP Key Management

    /// Saves a DPoP key to the keychain.
    /// - Parameters:
    ///   - key: The private key to save
    ///   - did: The DID associated with the key
    public func saveDPoPKey(_ key: P256.Signing.PrivateKey, for did: String) async throws {
        let keyTag = makeKey("dpopKey", did: did)
        do {
            try KeychainManager.storeDPoPKey(key, keyTag: keyTag)
            LogManager.logDebug("Successfully saved DPoP key to Keychain for DID \(LogManager.logDID(did))")
        } catch {
            LogManager.logError("Failed to save DPoP key to Keychain (error: \(error)). This will likely cause authentication issues.")
            throw error // Re-throw so the calling code can handle this properly
        }
    }

    /// Retrieves a DPoP key from the keychain.
    /// - Parameter did: The DID associated with the key to retrieve
    /// - Returns: The private key if found, or nil if not found
    public func getDPoPKey(for did: String) async throws -> P256.Signing.PrivateKey? {
        let keyTag = makeKey("dpopKey", did: did)
        do {
            return try KeychainManager.retrieveDPoPKey(keyTag: keyTag)
        } catch let KeychainError.itemRetrievalError(status) where status == errSecItemNotFound {
            LogManager.logDebug("DPoP key not found in Keychain for DID: \(did). A new key will be generated if needed.")
            return nil
        } catch let KeychainError.itemRetrievalError(status) {
            // For any other keychain retrieval error (e.g., errSecAuthFailed while device locked),
            // do NOT rotate the DPoP key. Propagate the error so callers can treat this as transient.
            LogManager.logError("Keychain retrieval error for DPoP key (status=\(status)) for DID: \(did). Will NOT rotate key.")
            throw KeychainError.itemRetrievalError(status: status)
        } catch {
            // Unknown error — propagate so callers can avoid key rotation
            LogManager.logError("Failed to retrieve DPoP key from Keychain (error: \(error)). Will NOT rotate key.")
            throw error
        }
    }

    /// Deletes a DPoP key from the keychain.
    /// - Parameter did: The DID associated with the key to delete
    public func deleteDPoPKey(for did: String) async throws {
        let keyTag = makeKey("dpopKey", did: did)
        try KeychainManager.deleteDPoPKey(keyTag: keyTag)
    }

    // MARK: - DPoP Nonce Management

    /// Saves DPoP nonces to the keychain.
    /// - Parameters:
    ///   - nonces: The nonces to save, keyed by domain
    ///   - did: The DID associated with the nonces
    public func saveDPoPNonces(_ nonces: [String: String], for did: String) async throws {
        let key = makeKey("dpopNonces", did: did)
        let data = try JSONEncoder().encode(nonces)
        try KeychainManager.store(key: key, value: data, namespace: namespace)
    }

    /// Retrieves DPoP nonces from the keychain.
    /// - Parameter did: The DID associated with the nonces to retrieve
    /// - Returns: The nonces if found, or nil if not found
    public func getDPoPNonces(for did: String) async throws -> [String: String]? {
        let key = makeKey("dpopNonces", did: did)
        do {
            let data = try KeychainManager.retrieve(key: key, namespace: namespace)
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            return nil
        }
    }

    /// Saves DPoP nonces scoped by JKT (key thumbprint) to the keychain.
    /// - Parameters:
    ///   - noncesByJKT: Mapping of JKT -> (domain -> nonce)
    ///   - did: The DID associated with these nonces
    public func saveDPoPNoncesByJKT(_ noncesByJKT: [String: [String: String]], for did: String) async throws {
        let key = makeKey("dpopNoncesByJKT", did: did)
        let data = try JSONEncoder().encode(noncesByJKT)
        try KeychainManager.store(key: key, value: data, namespace: namespace)
    }

    /// Retrieves DPoP nonces scoped by JKT (key thumbprint) from the keychain.
    /// - Parameter did: The DID associated with these nonces
    /// - Returns: Mapping of JKT -> (domain -> nonce) if found
    public func getDPoPNoncesByJKT(for did: String) async throws -> [String: [String: String]]? {
        let key = makeKey("dpopNoncesByJKT", did: did)
        do {
            let data = try KeychainManager.retrieve(key: key, namespace: namespace)
            return try JSONDecoder().decode([String: [String: String]].self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - OAuth State Management

    /// Saves an OAuth state to the keychain.
    /// - Parameter state: The OAuth state to save
    public func saveOAuthState(_ state: OAuthState) async throws {
        let key = makeKey("oauthState", stateToken: state.stateToken)
        let data = try JSONEncoder().encode(state)
        try KeychainManager.store(key: key, value: data, namespace: namespace)
    }

    /// Retrieves an OAuth state from the keychain.
    /// - Parameter stateToken: The state token associated with the OAuth state to retrieve
    /// - Returns: The OAuth state if found, or nil if not found
    public func getOAuthState(for stateToken: String) async throws -> OAuthState? {
        let key = makeKey("oauthState", stateToken: stateToken)
        do {
            let data = try KeychainManager.retrieve(key: key, namespace: namespace)
            return try JSONDecoder().decode(OAuthState.self, from: data)
        } catch {
            return nil
        }
    }

    /// Deletes an OAuth state from the keychain.
    /// - Parameter stateToken: The state token associated with the OAuth state to delete
    public func deleteOAuthState(for stateToken: String) async throws {
        let key = makeKey("oauthState", stateToken: stateToken)
        try KeychainManager.delete(key: key, namespace: namespace)
    }

    // MARK: - Helper Methods

    /// Creates a keychain key with the given base and optional DID.
    /// - Parameters:
    ///   - base: The base key name
    ///   - did: Optional DID to associate with the key
    ///   - stateToken: Optional state token to associate with the key
    /// - Returns: A formatted key string
    private func makeKey(_ base: String, did: String? = nil, stateToken: String? = nil) -> String {
        if let did = did {
            return "\(base).\(did)"
        } else if let stateToken = stateToken {
            return "\(base).\(stateToken)"
        } else {
            return base
        }
    }

    /// Adds a DID to the accounts list.
    /// - Parameter did: The DID to add
    private func addToAccountsList(_ did: String) async throws {
        let key = makeKey("accountDIDs")
        var dids = try await listAccountDIDs()

        if !dids.contains(did) {
            dids.append(did)
            let data = try JSONEncoder().encode(dids)
            try KeychainManager.store(key: key, value: data, namespace: namespace)
        }
    }

    /// Removes a DID from the accounts list.
    /// - Parameter did: The DID to remove
    private func removeFromAccountsList(_ did: String) async throws {
        let key = makeKey("accountDIDs")
        var dids = try await listAccountDIDs()

        dids.removeAll { $0 == did }
        let data = try JSONEncoder().encode(dids)
        try KeychainManager.store(key: key, value: data, namespace: namespace)
    }
}
