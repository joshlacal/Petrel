//
//  KeychainStorage.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/22/2025.
//

#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
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
        KeychainManager.configureDefaultAccessGroup(accessGroup)
    }

    // MARK: - Account Management

    /// Saves an account to the keychain.
    /// - Parameters:
    ///   - account: The account to save
    ///   - did: The DID of the account
    public func saveAccount(_ account: Account, for did: String) async throws {
        let key = makeKey("account", did: did)
        let data = try JSONEncoder().encode(account)
        try await KeychainManager.storeAsync(key: key, value: data, namespace: namespace)

        // Add to the accounts list if not already present
        try await addToAccountsList(did)
    }

    /// Atomically saves both account and session data to prevent inconsistent authentication states.
    /// This method ensures that either both account and session are saved successfully, or neither is saved.
    /// - Parameters:
    ///   - account: The account to save
    ///   - session: The session to save
    ///   - did: The DID associated with both account and session
    func saveAccountAndSession(_ account: Account, session: Session, for did: String) async throws {
        let accountKey = makeKey("account", did: did)
        let sessionKey = makeKey("session", did: did)
        let tempAccountKey = makeKey("account.temp", did: did)
        let tempSessionKey = makeKey("session.temp", did: did)
        let backupAccountKey = makeKey("account.backup", did: did)
        let backupSessionKey = makeKey("session.backup", did: did)

        let accountData = try JSONEncoder().encode(account)
        let sessionData = try JSONEncoder().encode(session)

        LogManager.logDebug("Starting atomic account+session save for DID: \(LogManager.logDID(did))")

        do {
            // Step 1: Create backups of existing data if they exist
            if let existingAccountData = try? KeychainManager.retrieve(
                key: accountKey, namespace: namespace
            ) {
                try KeychainManager.store(
                    key: backupAccountKey, value: existingAccountData, namespace: namespace
                )
                LogManager.logDebug("Account backup created for DID: \(LogManager.logDID(did))")
            }

            if let existingSessionData = try? KeychainManager.retrieve(
                key: sessionKey, namespace: namespace
            ) {
                try KeychainManager.store(
                    key: backupSessionKey, value: existingSessionData, namespace: namespace
                )
                LogManager.logDebug("Session backup created for DID: \(LogManager.logDID(did))")
            }

            // Step 2: Save both to temporary locations first
            try KeychainManager.store(key: tempAccountKey, value: accountData, namespace: namespace)
            LogManager.logDebug("Account saved to temporary location for DID: \(LogManager.logDID(did))")

            try KeychainManager.store(key: tempSessionKey, value: sessionData, namespace: namespace)
            LogManager.logDebug("Session saved to temporary location for DID: \(LogManager.logDID(did))")

            // Step 3: Atomic move both to final locations
            try KeychainManager.store(key: accountKey, value: accountData, namespace: namespace)
            LogManager.logDebug("Account moved to final location for DID: \(LogManager.logDID(did))")

            try KeychainManager.store(key: sessionKey, value: sessionData, namespace: namespace)
            LogManager.logDebug("Session moved to final location for DID: \(LogManager.logDID(did))")

            // Step 4: Verify both saves were successful by reading them back
            let verificationAccountData = try KeychainManager.retrieve(
                key: accountKey, namespace: namespace
            )
            let verificationSessionData = try KeychainManager.retrieve(
                key: sessionKey, namespace: namespace
            )

            let verifiedAccount = try JSONDecoder().decode(Account.self, from: verificationAccountData)
            let verifiedSession = try JSONDecoder().decode(Session.self, from: verificationSessionData)

            // Basic verification that both have required fields
            guard !verifiedAccount.did.isEmpty, !verifiedSession.accessToken.isEmpty else {
                throw KeychainError.dataFormatError
            }

            LogManager.logDebug(
                "Account+session save verification successful for DID: \(LogManager.logDID(did))"
            )

            // Step 5: Add to accounts list if not already present
            try await addToAccountsList(did)

            // Step 6: Cleanup temporary and backup files
            try? KeychainManager.delete(key: tempAccountKey, namespace: namespace)
            try? KeychainManager.delete(key: tempSessionKey, namespace: namespace)
            try? KeychainManager.delete(key: backupAccountKey, namespace: namespace)
            try? KeychainManager.delete(key: backupSessionKey, namespace: namespace)

            LogManager.logDebug(
                "Account+session saved atomically and verified for DID: \(LogManager.logDID(did))"
            )

        } catch {
            LogManager.logError(
                "Atomic account+session save failed for DID: \(LogManager.logDID(did)), error: \(error)"
            )

            // Recovery: Attempt to restore from backups if final saves failed
            if let backupAccountData = try? KeychainManager.retrieve(
                key: backupAccountKey, namespace: namespace
            ) {
                do {
                    try KeychainManager.store(key: accountKey, value: backupAccountData, namespace: namespace)
                    LogManager.logDebug("Account restored from backup for DID: \(LogManager.logDID(did))")
                } catch {
                    LogManager.logError(
                        "Failed to restore account backup for DID: \(LogManager.logDID(did)), error: \(error)"
                    )
                }
            }

            if let backupSessionData = try? KeychainManager.retrieve(
                key: backupSessionKey, namespace: namespace
            ) {
                do {
                    try KeychainManager.store(key: sessionKey, value: backupSessionData, namespace: namespace)
                    LogManager.logDebug("Session restored from backup for DID: \(LogManager.logDID(did))")
                } catch {
                    LogManager.logError(
                        "Failed to restore session backup for DID: \(LogManager.logDID(did)), error: \(error)"
                    )
                }
            }

            // Cleanup temporary files in error case
            try? KeychainManager.delete(key: tempAccountKey, namespace: namespace)
            try? KeychainManager.delete(key: tempSessionKey, namespace: namespace)
            try? KeychainManager.delete(key: backupAccountKey, namespace: namespace)
            try? KeychainManager.delete(key: backupSessionKey, namespace: namespace)

            throw error
        }
    }

    /// Retrieves an account from the keychain.
    /// - Parameter did: The DID of the account to retrieve
    /// - Returns: The account if found, or nil if not found
    public func getAccount(for did: String) async throws -> Account? {
        let key = makeKey("account", did: did)
        do {
            let data = try await KeychainManager.retrieveAsync(key: key, namespace: namespace)
            return try JSONDecoder().decode(Account.self, from: data)
        } catch {
            return nil
        }
    }

    /// Deletes an account from the keychain.
    /// - Parameter did: The DID of the account to delete
    public func deleteAccount(for did: String) async throws {
        let key = makeKey("account", did: did)
        try await KeychainManager.deleteAsync(key: key, namespace: namespace)

        // Remove from the accounts list
        try await removeFromAccountsList(did)
    }

    /// Lists all account DIDs stored in the keychain.
    /// - Returns: An array of DIDs
    public func listAccountDIDs() async throws -> [String] {
        let key = makeKey("accountDIDs")
        do {
            let data = try await KeychainManager.retrieveAsync(key: key, namespace: namespace)
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
        try await KeychainManager.storeAsync(key: key, value: data, namespace: namespace)
    }

    /// Retrieves the current DID from the keychain.
    /// - Returns: The current DID if found, or nil if not found
    public func getCurrentDID() async throws -> String? {
        let key = makeKey("currentDID")
        do {
            let data = try await KeychainManager.retrieveAsync(key: key, namespace: namespace)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    // MARK: - Gateway Session

    /// Saves the gateway session for a specific account (per-DID storage for multi-account support)
    func saveGatewaySession(_ session: String, for did: String) async throws {
        let key = makeKey("gatewaySession", did: did)
        let data = session.data(using: .utf8) ?? Data()
        try await KeychainManager.storeAsync(key: key, value: data, namespace: namespace)
        LogManager.logDebug("KeychainStorage - Saved gateway session for DID: \(did.prefix(20))...")
    }

    /// Retrieves the gateway session for a specific account
    func getGatewaySession(for did: String) async throws -> String? {
        let key = makeKey("gatewaySession", did: did)
        do {
            let data = try await KeychainManager.retrieveAsync(key: key, namespace: namespace)
            LogManager.logDebug("KeychainStorage - Retrieved gateway session for DID: \(did.prefix(20))...")
            return String(data: data, encoding: .utf8)
        } catch {
            if let migratedSession = await migrateLegacyGatewaySessionIfNeeded(for: did) {
                return migratedSession
            }
            return nil
        }
    }

    /// Deletes the gateway session for a specific account
    func deleteGatewaySession(for did: String) async throws {
        let key = makeKey("gatewaySession", did: did)
        try await KeychainManager.deleteAsync(key: key, namespace: namespace)
        LogManager.logDebug("KeychainStorage - Deleted gateway session for DID: \(did.prefix(20))...")
    }

    private func shouldMigrateLegacyGatewaySession(for did: String) async -> Bool {
        guard !did.isEmpty else { return false }

        if let currentDID = try? await getCurrentDID(), !currentDID.isEmpty {
            return currentDID == did
        }

        if let dids = try? await listAccountDIDs(), dids.count == 1, dids.first == did {
            return true
        }

        return false
    }

    private func migrateLegacyGatewaySessionIfNeeded(for did: String) async -> String? {
        guard await shouldMigrateLegacyGatewaySession(for: did) else { return nil }

        if let legacySession = try? await getGatewaySession(), !legacySession.isEmpty {
            LogManager.logInfo(
                "KeychainStorage - Migrating legacy gateway session to per-DID storage for DID: \(did.prefix(20))..."
            )
            try? await saveGatewaySession(legacySession, for: did)
            try? await deleteGatewaySession()
            return legacySession
        }

        if let data = try? await KeychainManager.retrieveAsync(
            key: "gatewaySession",
            namespace: "catbird.gateway"
        ),
            let session = String(data: data, encoding: .utf8),
            !session.isEmpty
        {
            LogManager.logInfo(
                "KeychainStorage - Migrating global gateway session to per-DID storage for DID: \(did.prefix(20))..."
            )
            try? await saveGatewaySession(session, for: did)
            try? await KeychainManager.deleteAsync(key: "gatewaySession", namespace: "catbird.gateway")
            return session
        }

        return nil
    }

    /// Legacy single-session methods for backward compatibility during migration
    @available(*, deprecated, message: "Use saveGatewaySession(_:for:) for multi-account support")
    func saveGatewaySession(_ session: String) async throws {
        let key = makeKey("gatewaySession")
        let data = session.data(using: .utf8) ?? Data()
        try await KeychainManager.storeAsync(key: key, value: data, namespace: namespace)
    }

    @available(*, deprecated, message: "Use getGatewaySession(for:) for multi-account support")
    func getGatewaySession() async throws -> String? {
        let key = makeKey("gatewaySession")
        do {
            let data = try await KeychainManager.retrieveAsync(key: key, namespace: namespace)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    @available(*, deprecated, message: "Use deleteGatewaySession(for:) for multi-account support")
    func deleteGatewaySession() async throws {
        let key = makeKey("gatewaySession")
        try await KeychainManager.deleteAsync(key: key, namespace: namespace)
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

        // Validate session before attempting to save
        guard !session.accessToken.isEmpty else {
            LogManager.logError(
                "Attempted to save invalid session with empty access token for DID: \(LogManager.logDID(did))"
            )
            throw KeychainError.dataFormatError
        }

        let data: Data
        do {
            data = try JSONEncoder().encode(session)
        } catch {
            LogManager.logError(
                "Failed to encode session for DID: \(LogManager.logDID(did)), error: \(error)"
            )
            throw KeychainError.dataFormatError
        }

        LogManager.logDebug("Starting session save for DID: \(LogManager.logDID(did))")

        // Enhanced atomic save operation with comprehensive error handling
        do {
            // Step 1: Create backup of existing session if it exists
            if let existingData = try? KeychainManager.retrieve(key: key, namespace: namespace) {
                do {
                    try KeychainManager.store(key: backupKey, value: existingData, namespace: namespace)
                    LogManager.logDebug("Session backup created for DID: \(LogManager.logDID(did))")
                } catch {
                    LogManager.logWarning(
                        "Failed to create session backup for DID: \(LogManager.logDID(did)), continuing without backup: \(error)"
                    )
                }
            }

            // Step 2: Save to temporary location first
            do {
                try KeychainManager.store(key: tempKey, value: data, namespace: namespace)
                LogManager.logDebug(
                    "Session saved to temporary location for DID: \(LogManager.logDID(did))"
                )
            } catch {
                LogManager.logError(
                    "Failed to save session to temporary location for DID: \(LogManager.logDID(did)): \(error)"
                )
                throw SessionSaveError.temporarySaveFailed(underlying: error)
            }

            // Step 3: Atomic move to final location
            do {
                try KeychainManager.store(key: key, value: data, namespace: namespace)
                LogManager.logDebug("Session moved to final location for DID: \(LogManager.logDID(did))")
            } catch {
                LogManager.logError(
                    "Failed to save session to final location for DID: \(LogManager.logDID(did)): \(error)"
                )
                throw SessionSaveError.finalSaveFailed(underlying: error)
            }

            // Step 4: Verify the save was successful by reading it back
            do {
                let verificationData = try KeychainManager.retrieve(key: key, namespace: namespace)
                let verifiedSession = try JSONDecoder().decode(Session.self, from: verificationData)

                // Comprehensive verification that the session has required fields
                guard !verifiedSession.accessToken.isEmpty,
                      verifiedSession.did == session.did,
                      abs(verifiedSession.createdAt.timeIntervalSince(session.createdAt)) < 1.0
                else {
                    throw SessionSaveError.verificationFailed(
                        "Session verification failed: stored session doesn't match expected values"
                    )
                }

                LogManager.logDebug(
                    "Session save verification successful for DID: \(LogManager.logDID(did))"
                )
            } catch let SessionSaveError.verificationFailed(message) {
                LogManager.logError(
                    "Session verification failed for DID: \(LogManager.logDID(did)): \(message)"
                )
                throw SessionSaveError.verificationFailed(message)
            } catch {
                LogManager.logError(
                    "Session verification error for DID: \(LogManager.logDID(did)): \(error)"
                )
                throw SessionSaveError.verificationFailed("Could not verify saved session: \(error)")
            }

            // Step 5: Cleanup temporary files
            try? KeychainManager.delete(key: tempKey, namespace: namespace)
            try? KeychainManager.delete(key: backupKey, namespace: namespace)

            LogManager.logDebug(
                "Session saved atomically and verified for DID: \(LogManager.logDID(did))"
            )

        } catch let sessionSaveError as SessionSaveError {
            LogManager.logError(
                "Session save failed for DID: \(LogManager.logDID(did)): \(sessionSaveError)"
            )
            await handleSessionSaveFailure(
                sessionSaveError, key: key, tempKey: tempKey, backupKey: backupKey, did: did
            )
            throw sessionSaveError
        } catch {
            LogManager.logError(
                "Unexpected session save error for DID: \(LogManager.logDID(did)): \(error)"
            )
            await handleSessionSaveFailure(
                SessionSaveError.unexpectedError(error), key: key, tempKey: tempKey, backupKey: backupKey,
                did: did
            )
            throw SessionSaveError.unexpectedError(error)
        }
    }

    /// Handles session save failures with appropriate recovery actions
    private func handleSessionSaveFailure(
        _ error: SessionSaveError, key: String, tempKey: String, backupKey: String, did: String
    ) async {
        switch error {
        case .temporarySaveFailed:
            // If we can't even save to temp, just cleanup and fail
            try? KeychainManager.delete(key: tempKey, namespace: namespace)
            try? KeychainManager.delete(key: backupKey, namespace: namespace)

        case .finalSaveFailed, .verificationFailed, .unexpectedError:
            // For final save or verification failures, attempt recovery from backup
            if let backupData = try? KeychainManager.retrieve(key: backupKey, namespace: namespace) {
                do {
                    try KeychainManager.store(key: key, value: backupData, namespace: namespace)
                    LogManager.logInfo(
                        "Session restored from backup after save failure for DID: \(LogManager.logDID(did))"
                    )
                } catch {
                    LogManager.logError(
                        "Failed to restore session backup for DID: \(LogManager.logDID(did)): \(error)"
                    )
                }
            }

            // Always cleanup temporary files in error cases
            try? KeychainManager.delete(key: tempKey, namespace: namespace)
            try? KeychainManager.delete(key: backupKey, namespace: namespace)
        }
    }

    /// Errors that can occur during session save operations
    enum SessionSaveError: Error, LocalizedError {
        case temporarySaveFailed(underlying: Error)
        case finalSaveFailed(underlying: Error)
        case verificationFailed(String)
        case unexpectedError(Error)

        var errorDescription: String? {
            switch self {
            case let .temporarySaveFailed(underlying):
                return "Failed to save session to temporary location: \(underlying.localizedDescription)"
            case let .finalSaveFailed(underlying):
                return "Failed to save session to final location: \(underlying.localizedDescription)"
            case let .verificationFailed(message):
                return "Session verification failed: \(message)"
            case let .unexpectedError(underlying):
                return "Unexpected session save error: \(underlying.localizedDescription)"
            }
        }

        var failureReason: String? {
            switch self {
            case .temporarySaveFailed:
                return "The keychain may be temporarily unavailable or the device may be locked."
            case .finalSaveFailed:
                return "The keychain operation failed during the final save step."
            case .verificationFailed:
                return "The saved session data could not be verified or was corrupted."
            case .unexpectedError:
                return "An unexpected error occurred during the save operation."
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .temporarySaveFailed, .finalSaveFailed:
                return
                    "Please ensure your device is unlocked and try again. If the problem persists, you may need to restart the app."
            case .verificationFailed:
                return
                    "The authentication state may be corrupted. Please try logging out and logging back in."
            case .unexpectedError:
                return "Please try the operation again. If the problem persists, contact support."
            }
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
            let data = try await KeychainManager.retrieveAsync(key: key, namespace: namespace)
            return try JSONDecoder().decode(Session.self, from: data)
        } catch {
            LogManager.logDebug(
                "Failed to retrieve session from primary location for DID: \(LogManager.logDID(did)), attempting recovery"
            )

            // Try to recover from temporary location if primary failed
            if let tempData = try? await KeychainManager.retrieveAsync(key: tempKey, namespace: namespace) {
                do {
                    let session = try JSONDecoder().decode(Session.self, from: tempData)
                    LogManager.logDebug(
                        "Session recovered from temporary location for DID: \(LogManager.logDID(did))"
                    )

                    // Try to restore to primary location
                    try? await KeychainManager.storeAsync(key: key, value: tempData, namespace: namespace)
                    try? await KeychainManager.deleteAsync(key: tempKey, namespace: namespace)

                    return session
                } catch {
                    LogManager.logError(
                        "Failed to decode session from temporary location for DID: \(LogManager.logDID(did))"
                    )
                }
            }

            // Try to recover from backup location if primary and temp failed
            if let backupData = try? await KeychainManager.retrieveAsync(key: backupKey, namespace: namespace) {
                do {
                    let session = try JSONDecoder().decode(Session.self, from: backupData)
                    LogManager.logDebug(
                        "Session recovered from backup location for DID: \(LogManager.logDID(did))"
                    )

                    // Try to restore to primary location
                    try? await KeychainManager.storeAsync(key: key, value: backupData, namespace: namespace)
                    try? await KeychainManager.deleteAsync(key: backupKey, namespace: namespace)

                    return session
                } catch {
                    LogManager.logError(
                        "Failed to decode session from backup location for DID: \(LogManager.logDID(did))"
                    )
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
            LogManager.logDebug(
                "Successfully saved DPoP key to Keychain for DID \(LogManager.logDID(did))"
            )
        } catch {
            LogManager.logError(
                "Failed to save DPoP key to Keychain (error: \(error)). This will likely cause authentication issues."
            )
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
            LogManager.logDebug(
                "DPoP key not found in Keychain for DID: \(did). A new key will be generated if needed."
            )
            return nil
        } catch let KeychainError.itemRetrievalError(status) {
            // For any other keychain retrieval error (e.g., errSecAuthFailed while device locked),
            // do NOT rotate the DPoP key. Propagate the error so callers can treat this as transient.
            LogManager.logError(
                "Keychain retrieval error for DPoP key (status=\(status)) for DID: \(did). Will NOT rotate key."
            )
            throw KeychainError.itemRetrievalError(status: status)
        } catch {
            // Unknown error — propagate so callers can avoid key rotation
            LogManager.logError(
                "Failed to retrieve DPoP key from Keychain (error: \(error)). Will NOT rotate key."
            )
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
    ///   ///   - did: The DID associated with these nonces
    public func saveDPoPNoncesByJKT(_ noncesByJKT: [String: [String: String]], for did: String)
        async throws
    {
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

    // MARK: - Session Integrity Validation

    /// Validates the integrity of authentication state and fixes inconsistencies.
    /// This method should be called at app startup to detect and repair race condition damage.
    /// - Returns: A summary of any issues found and fixed
    func validateAndRepairAuthenticationState() async -> AuthStateValidationResult {
        var result = AuthStateValidationResult()

        do {
            let accountDIDs = try await listAccountDIDs()
            LogManager.logDebug("Validating authentication state for \(accountDIDs.count) accounts")

            for did in accountDIDs {
                let accountExists = try (await getAccount(for: did)) != nil
                let sessionExists = try (await getSession(for: did)) != nil
                let gatewaySessionExists = (try? await getGatewaySession(for: did)) != nil
                let hasAuthSession = sessionExists || gatewaySessionExists

                if accountExists && !hasAuthSession {
                    LogManager.logWarning(
                        "Inconsistent auth state detected for DID \(LogManager.logDID(did)): account exists but session missing"
                    )
                    result.inconsistentStates.append(did)

                    // Attempt to recover session from temporary/backup locations
                    if try await recoverSessionFromBackup(for: did) {
                        result.recoveredSessions.append(did)
                        LogManager.logInfo(
                            "Successfully recovered session from backup for DID \(LogManager.logDID(did))"
                        )
                    } else {
                        // If recovery fails, remove the orphaned account to force re-authentication
                        try await deleteAccount(for: did)
                        result.cleanedOrphanedAccounts.append(did)
                        LogManager.logInfo(
                            "Removed orphaned account for DID \(LogManager.logDID(did)) - user will need to re-authenticate"
                        )
                    }
                } else if !accountExists && sessionExists {
                    LogManager.logWarning(
                        "Orphaned session detected for DID \(LogManager.logDID(did)): session exists but account missing"
                    )
                    try await deleteSession(for: did)
                    result.cleanedOrphanedSessions.append(did)
                    LogManager.logInfo("Removed orphaned session for DID \(LogManager.logDID(did))")
                } else if !accountExists && gatewaySessionExists {
                    LogManager.logWarning(
                        "Orphaned gateway session detected for DID \(LogManager.logDID(did)): session exists but account missing"
                    )
                    try? await deleteGatewaySession(for: did)
                    result.cleanedOrphanedSessions.append(did)
                    LogManager.logInfo("Removed orphaned gateway session for DID \(LogManager.logDID(did))")
                }
            }

            // Clean up any temporary files that might have been left behind
            try await cleanupTemporaryFiles()

            LogManager.logInfo("Authentication state validation complete: \(result.summary)")

        } catch {
            LogManager.logError("Failed to validate authentication state: \(error)")
            result.validationError = error
        }

        return result
    }

    /// Attempts to recover a missing session from temporary or backup locations
    /// - Parameter did: The DID for which to recover the session
    /// - Returns: True if recovery was successful, false otherwise
    private func recoverSessionFromBackup(for did: String) async throws -> Bool {
        let sessionKey = makeKey("session", did: did)
        let tempSessionKey = makeKey("session.temp", did: did)
        let backupSessionKey = makeKey("session.backup", did: did)

        // Try temporary location first
        if let tempData = try? KeychainManager.retrieve(key: tempSessionKey, namespace: namespace) {
            do {
                let session = try JSONDecoder().decode(Session.self, from: tempData)
                guard !session.accessToken.isEmpty else { return false }

                try KeychainManager.store(key: sessionKey, value: tempData, namespace: namespace)
                try? KeychainManager.delete(key: tempSessionKey, namespace: namespace)

                LogManager.logDebug(
                    "Session recovered from temporary location for DID: \(LogManager.logDID(did))"
                )
                return true
            } catch {
                LogManager.logDebug("Failed to decode session from temporary location: \(error)")
            }
        }

        // Try backup location
        if let backupData = try? KeychainManager.retrieve(key: backupSessionKey, namespace: namespace) {
            do {
                let session = try JSONDecoder().decode(Session.self, from: backupData)
                guard !session.accessToken.isEmpty else { return false }

                try KeychainManager.store(key: sessionKey, value: backupData, namespace: namespace)
                try? KeychainManager.delete(key: backupSessionKey, namespace: namespace)

                LogManager.logDebug(
                    "Session recovered from backup location for DID: \(LogManager.logDID(did))"
                )
                return true
            } catch {
                LogManager.logDebug("Failed to decode session from backup location: \(error)")
            }
        }

        return false
    }

    /// Cleans up temporary and backup files that might have been left behind from interrupted operations
    private func cleanupTemporaryFiles() async throws {
        let accountDIDs = try await listAccountDIDs()

        for did in accountDIDs {
            // Clean up temporary files
            try? KeychainManager.delete(key: makeKey("session.temp", did: did), namespace: namespace)
            try? KeychainManager.delete(key: makeKey("account.temp", did: did), namespace: namespace)
            try? KeychainManager.delete(key: makeKey("session.backup", did: did), namespace: namespace)
            try? KeychainManager.delete(key: makeKey("account.backup", did: did), namespace: namespace)
        }

        LogManager.logDebug("Cleaned up temporary keychain files")
    }

    /// Result of authentication state validation
    struct AuthStateValidationResult {
        var inconsistentStates: [String] = []
        var recoveredSessions: [String] = []
        var cleanedOrphanedAccounts: [String] = []
        var cleanedOrphanedSessions: [String] = []
        var validationError: Error?

        var hasIssues: Bool {
            return !inconsistentStates.isEmpty || !cleanedOrphanedAccounts.isEmpty
                || !cleanedOrphanedSessions.isEmpty || validationError != nil
        }

        var summary: String {
            var parts: [String] = []
            if !inconsistentStates.isEmpty {
                parts.append("\(inconsistentStates.count) inconsistent states")
            }
            if !recoveredSessions.isEmpty {
                parts.append("\(recoveredSessions.count) sessions recovered")
            }
            if !cleanedOrphanedAccounts.isEmpty {
                parts.append("\(cleanedOrphanedAccounts.count) orphaned accounts cleaned")
            }
            if !cleanedOrphanedSessions.isEmpty {
                parts.append("\(cleanedOrphanedSessions.count) orphaned sessions cleaned")
            }
            if let error = validationError {
                parts.append("validation error: \(error)")
            }
            return parts.isEmpty ? "no issues found" : parts.joined(separator: ", ")
        }
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
