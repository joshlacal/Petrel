//
//  KeychainManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 11/20/23.
//

#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
#if os(iOS) || os(macOS)
    import Security
#endif

enum KeychainError: Error, LocalizedError {
    case itemStoreError(status: Int)
    case itemRetrievalError(status: Int)
    case dataFormatError
    case unableToCreateKey
    case deletionError(status: Int)

    var errorDescription: String? {
        switch self {
        case let .itemStoreError(status):
            return "Failed to store item in keychain (Status: \(status))."
        case let .itemRetrievalError(status):
            return "Failed to retrieve item from keychain (Status: \(status))."
        case .dataFormatError:
            return "Keychain data is corrupted or in an invalid format."
        case .unableToCreateKey:
            return "Failed to create cryptographic key from keychain data."
        case let .deletionError(status):
            return "Failed to delete item from keychain (Status: \(status))."
        }
    }

    var failureReason: String? {
        #if os(iOS) || os(macOS)
            switch self {
            case let .itemStoreError(status) where status == Int(errSecDuplicateItem):
                return "An item with this key already exists in the keychain."
            case let .itemStoreError(status) where status == Int(errSecAuthFailed):
                return "Authentication failed while accessing keychain."
            case let .itemRetrievalError(status) where status == Int(errSecItemNotFound):
                return "The requested item was not found in the keychain."
            case let .itemRetrievalError(status) where status == Int(errSecAuthFailed):
                return "Authentication failed while accessing keychain."
            case .dataFormatError:
                return "The stored keychain data cannot be decoded or is missing required fields."
            case .unableToCreateKey:
                return "The cryptographic key data from keychain is invalid or corrupted."
            case let .deletionError(status) where status == Int(errSecAuthFailed):
                return "Authentication failed while accessing keychain."
            default:
                return "Keychain operation failed due to system restrictions or device state."
            }
        #else
            switch self {
            case .itemRetrievalError:
                return "The requested item was not found."
            case .dataFormatError:
                return "The stored data cannot be decoded or is missing required fields."
            case .unableToCreateKey:
                return "The cryptographic key data is invalid or corrupted."
            default:
                return "Storage operation failed."
            }
        #endif
    }

    var recoverySuggestion: String? {
        #if os(iOS) || os(macOS)
            switch self {
            case let .itemStoreError(status) where status == Int(errSecAuthFailed),
                 .itemRetrievalError(let status) where status == Int(errSecAuthFailed),
                 .deletionError(let status) where status == Int(errSecAuthFailed):
                return "Please unlock your device and ensure the app has keychain access."
            case let .itemRetrievalError(status) where status == Int(errSecItemNotFound):
                return "You may need to log in again to restore your credentials."
            case .dataFormatError, .unableToCreateKey:
                return "Please log out and log back in to reset your stored credentials."
            case let .itemStoreError(status) where status == Int(errSecDuplicateItem):
                return "Please restart the app or log out and log back in."
            default:
                return "Try restarting the app. If the problem persists, you may need to log out and log back in."
            }
        #else
            return "Try restarting the app. If the problem persists, you may need to log out and log back in."
        #endif
    }
}

enum KeychainManager {
    // MARK: - Storage Backend

    /// The secure storage backend used by this manager
    private static let storage: SecureStorage = {
        #if os(iOS) || os(macOS)
            return AppleKeychainStore()
        #elseif os(Linux)
            return createLinuxStorage()
        #else
            #error("Unsupported platform")
        #endif
    }()

    #if os(Linux)
        /// Create appropriate storage backend for Linux
        private static func createLinuxStorage() -> SecureStorage {
            // Try libsecret first (desktop environment)
            if LibSecretStore.isAvailable() {
                LogManager.logInfo("KeychainManager - Using libsecret for secure storage (desktop Linux)")
                return LibSecretStore()
            }

            // Fallback to encrypted file storage (server/headless)
            LogManager.logInfo("KeychainManager - Using file-encrypted storage (libsecret not available)")
            do {
                return try FileEncryptedStore()
            } catch {
                LogManager.logError("KeychainManager - Failed to initialize FileEncryptedStore: \(error)")
                fatalError("Unable to initialize secure storage on Linux: \(error)")
            }
        }
    #endif

    // MARK: - Cache

    /// Thread-safe caches with automatic memory management
    private nonisolated(unsafe) static let dataCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 100
        return cache
    }()

    private nonisolated(unsafe) static var dpopKeyCache: NSCache<NSString, CachedDPoPKey> = {
        let cache = NSCache<NSString, CachedDPoPKey>()
        cache.countLimit = 100
        return cache
    }()

    private nonisolated(unsafe) static var defaultAccessGroup: String?

    static func configureDefaultAccessGroup(_ accessGroup: String?) {
        if defaultAccessGroup != accessGroup {
            clearCache()
        }
        defaultAccessGroup = accessGroup
        LogManager.logDebug(
            "KeychainManager - Default access group set to \(accessGroup ?? "nil")"
        )
    }

    private static let itemNotFoundStatus: Int = {
        #if os(iOS) || os(macOS)
            return Int(errSecItemNotFound)
        #else
            return -25300
        #endif
    }()

    private static func resolvedAccessGroup(_ accessGroup: String?) -> String? {
        let group = accessGroup ?? defaultAccessGroup
        return (group?.isEmpty == true) ? nil : group
    }

    private static func accessGroupAttributes(_ accessGroup: String?) -> [String: Any] {
        guard let accessGroup, !accessGroup.isEmpty else { return [:] }
        return [kSecAttrAccessGroup as String: accessGroup]
    }

    private static func isItemNotFound(_ error: Error) -> Bool {
        guard case let KeychainError.itemRetrievalError(status) = error else { return false }
        return status == itemNotFoundStatus
    }

    /// Wrapper class for P256.Signing.PrivateKey to make it cacheable
    private final class CachedDPoPKey: NSObject, @unchecked Sendable {
        let key: P256.Signing.PrivateKey

        init(key: P256.Signing.PrivateKey) {
            self.key = key
            super.init()
        }
    }

    /// Configure cache limits
    static func configureCaches(countLimit: Int = 100) {
        dataCache.countLimit = countLimit
        dpopKeyCache.countLimit = countLimit
    }

    // MARK: - Cache Management

    /// Clears all cached items
    static func clearCache() {
        dataCache.removeAllObjects()
        dpopKeyCache.removeAllObjects()
        LogManager.logDebug("KeychainManager - Cache cleared.")
    }

    /// Clears cached items for a specific namespace
    static func clearCache(forNamespace namespace: String) {
        // Since NSCache doesn't support partial clearing based on key prefix,
        // we need a separate approach for namespace-specific clearing

        // Get all keychain items for the namespace and remove them from cache
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]

        var result: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let items = result as? [[String: Any]] {
            for item in items {
                if let account = item[kSecAttrAccount as String] as? String,
                   account.hasPrefix("\(namespace).")
                {
                    // Remove from data cache
                    dataCache.removeObject(forKey: account as NSString)
                }
            }
        }

        // Do the same for DPoP keys
        let keysQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]

        status = SecItemCopyMatching(keysQuery as CFDictionary, &result)

        if status == errSecSuccess, let items = result as? [[String: Any]] {
            for item in items {
                if let tagData = item[kSecAttrApplicationTag as String] as? Data,
                   let tagString = String(data: tagData, encoding: .utf8),
                   tagString.hasPrefix("\(namespace).")
                {
                    // Remove from dpop key cache
                    dpopKeyCache.removeObject(forKey: tagString as NSString)
                }
            }
        }

        LogManager.logDebug("KeychainManager - Cache cleared for namespace: \(namespace).")
    }

    // MARK: - Generic Data Methods

    static func deleteExplicitKey(_ exactKey: String, accessGroup: String? = nil) throws {
        let resolvedAccessGroup = resolvedAccessGroup(accessGroup)
        // This is used for direct key deletion - use the namespace approach
        let parts = exactKey.split(separator: ".", maxSplits: 1)
        if parts.count == 2 {
            try storage.delete(
                key: String(parts[1]),
                namespace: String(parts[0]),
                accessGroup: resolvedAccessGroup
            )
        } else {
            try storage.delete(key: exactKey, namespace: "", accessGroup: resolvedAccessGroup)
        }

        // Remove from cache
        dataCache.removeObject(forKey: exactKey as NSString)
    }

    /// Stores data in the keychain with a specified key and namespace.
    static func store(
        key: String,
        value: Data,
        namespace: String,
        accessibility: CFString? = nil,
        accessGroup: String? = nil
    ) throws {
        let resolvedAccessGroup = resolvedAccessGroup(accessGroup)
        try storage.store(
            key: key,
            value: value,
            namespace: namespace,
            accessGroup: resolvedAccessGroup
        )

        // Update cache
        let namespacedKey = "\(namespace).\(key)"
        dataCache.setObject(value as NSData, forKey: namespacedKey as NSString)

        LogManager.logDebug("KeychainManager - Successfully stored item for key \(namespace).\(key).")
    }

    /// Retrieves data from the keychain for a specified key and namespace.
    static func retrieve(
        key: String,
        namespace: String,
        accessGroup: String? = nil
    ) throws -> Data {
        let namespacedKey = "\(namespace).\(key)"

        // Check cache first
        if let cachedData = dataCache.object(forKey: namespacedKey as NSString) {
            LogManager.logDebug("KeychainManager - Retrieved item from cache for key \(namespacedKey).")
            return cachedData as Data
        }

        let resolvedAccessGroup = resolvedAccessGroup(accessGroup)

        if let resolvedAccessGroup {
            do {
                let data = try storage.retrieve(
                    key: key,
                    namespace: namespace,
                    accessGroup: resolvedAccessGroup
                )
                dataCache.setObject(data as NSData, forKey: namespacedKey as NSString)
                LogManager.logDebug("KeychainManager - Successfully retrieved item for key \(namespacedKey).")
                return data
            } catch {
                if !isItemNotFound(error) {
                    throw error
                }
            }

            let legacyData = try storage.retrieve(
                key: key,
                namespace: namespace,
                accessGroup: nil
            )

            dataCache.setObject(legacyData as NSData, forKey: namespacedKey as NSString)

            do {
                try storage.store(
                    key: key,
                    value: legacyData,
                    namespace: namespace,
                    accessGroup: resolvedAccessGroup
                )
                try? storage.delete(
                    key: key,
                    namespace: namespace,
                    accessGroup: nil
                )
                LogManager.logInfo(
                    "KeychainManager - Migrated item to access group \(resolvedAccessGroup) for key \(namespacedKey)."
                )
            } catch {
                LogManager.logWarning(
                    "KeychainManager - Failed to migrate item to access group \(resolvedAccessGroup) for key \(namespacedKey): \(error)"
                )
            }

            LogManager.logDebug("KeychainManager - Successfully retrieved item for key \(namespacedKey).")
            return legacyData
        }

        let data = try storage.retrieve(key: key, namespace: namespace, accessGroup: nil)

        // Store in cache
        dataCache.setObject(data as NSData, forKey: namespacedKey as NSString)

        LogManager.logDebug("KeychainManager - Successfully retrieved item for key \(namespacedKey).")
        return data
    }

    static func storeObject<T: Encodable>(
        _ object: T,
        key: String,
        namespace: String,
        accessGroup: String? = nil
    ) throws {
        let data = try JSONEncoder().encode(object)
        try store(key: key, value: data, namespace: namespace, accessGroup: accessGroup)
    }

    static func retrieveObject<T: Decodable>(
        key: String,
        namespace: String,
        accessGroup: String? = nil
    ) throws -> T {
        let data = try retrieve(key: key, namespace: namespace, accessGroup: accessGroup)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Deletes data from the keychain for a specified key and namespace.
    static func delete(
        key: String,
        namespace: String,
        accessGroup: String? = nil
    ) throws {
        let resolvedAccessGroup = resolvedAccessGroup(accessGroup)
        try storage.delete(key: key, namespace: namespace, accessGroup: resolvedAccessGroup)
        if resolvedAccessGroup != nil {
            try? storage.delete(key: key, namespace: namespace, accessGroup: nil)
        }

        // Remove from cache
        let namespacedKey = "\(namespace).\(key)"
        dataCache.removeObject(forKey: namespacedKey as NSString)

        LogManager.logDebug("KeychainManager: Successfully deleted item for key \(namespacedKey).")
    }

    static func nukeAllKeychainItems(
        forNamespace namespace: String,
        accessGroup: String? = nil
    ) -> Bool {
        do {
            let resolvedAccessGroup = resolvedAccessGroup(accessGroup)
            try storage.deleteAll(namespace: namespace, accessGroup: resolvedAccessGroup)
            if resolvedAccessGroup != nil {
                try? storage.deleteAll(namespace: namespace, accessGroup: nil)
            }

            // Clear cache for this namespace
            clearCache(forNamespace: namespace)

            LogManager.logInfo("KeychainManager - Successfully nuked all items for namespace: \(namespace)")
            return true
        } catch {
            LogManager.logError("KeychainManager - Failed to nuke items for namespace \(namespace): \(error)")
            return false
        }
    }

    // MARK: - DPoP Key Methods

    /// Stores a DPoP private key in the keychain with a specified key tag.
    static func storeDPoPKey(
        _ key: P256.Signing.PrivateKey,
        keyTag: String,
        accessGroup: String? = nil
    ) throws {
        let resolvedAccessGroup = resolvedAccessGroup(accessGroup)
        try storage.storeDPoPKey(key, keyTag: keyTag, accessGroup: resolvedAccessGroup)

        // Update cache
        dpopKeyCache.setObject(CachedDPoPKey(key: key), forKey: keyTag as NSString)
    }

    /// Retrieves a DPoP private key from the keychain with a specified key tag.
    static func retrieveDPoPKey(
        keyTag: String,
        accessGroup: String? = nil
    ) throws -> P256.Signing.PrivateKey {
        // Check cache first
        if let cachedKey = dpopKeyCache.object(forKey: keyTag as NSString) {
            LogManager.logDebug("KeychainManager - Retrieved DPoP key from cache for tag \(keyTag).")
            return cachedKey.key
        }

        let resolvedAccessGroup = resolvedAccessGroup(accessGroup)

        if let resolvedAccessGroup {
            do {
                let key = try storage.retrieveDPoPKey(
                    keyTag: keyTag,
                    accessGroup: resolvedAccessGroup
                )
                dpopKeyCache.setObject(CachedDPoPKey(key: key), forKey: keyTag as NSString)
                return key
            } catch {
                if !isItemNotFound(error) {
                    throw error
                }
            }

            let legacyKey = try storage.retrieveDPoPKey(
                keyTag: keyTag,
                accessGroup: nil
            )

            dpopKeyCache.setObject(CachedDPoPKey(key: legacyKey), forKey: keyTag as NSString)

            do {
                try storage.storeDPoPKey(
                    legacyKey,
                    keyTag: keyTag,
                    accessGroup: resolvedAccessGroup
                )
                try? storage.deleteDPoPKey(keyTag: keyTag, accessGroup: nil)
                LogManager.logInfo(
                    "KeychainManager - Migrated DPoP key to access group \(resolvedAccessGroup) for tag \(keyTag)."
                )
            } catch {
                LogManager.logWarning(
                    "KeychainManager - Failed to migrate DPoP key to access group \(resolvedAccessGroup) for tag \(keyTag): \(error)"
                )
            }

            return legacyKey
        }

        let key = try storage.retrieveDPoPKey(keyTag: keyTag, accessGroup: nil)

        // Update cache
        dpopKeyCache.setObject(CachedDPoPKey(key: key), forKey: keyTag as NSString)
        return key
    }

    /// Deletes a DPoP private key from the keychain with a specified key tag.
    static func deleteDPoPKey(keyTag: String, accessGroup: String? = nil) throws {
        let resolvedAccessGroup = resolvedAccessGroup(accessGroup)
        try storage.deleteDPoPKey(keyTag: keyTag, accessGroup: resolvedAccessGroup)
        if resolvedAccessGroup != nil {
            try? storage.deleteDPoPKey(keyTag: keyTag, accessGroup: nil)
        }

        // Remove from cache
        dpopKeyCache.removeObject(forKey: keyTag as NSString)
    }

    /// Stores a DPoP private key in the keychain within a specified namespace.
    /// Legacy support for existing code.
    static func storeDPoPKey(
        _ key: P256.Signing.PrivateKey,
        namespace: String,
        accessGroup: String? = nil
    ) throws {
        let tagString = "\(namespace).dpopkeypair"
        try storeDPoPKey(key, keyTag: tagString, accessGroup: accessGroup)
    }

    /// Retrieves a DPoP private key from the keychain within a specified namespace.
    /// Legacy support for existing code.
    static func retrieveDPoPKey(
        namespace: String,
        accessGroup: String? = nil
    ) throws -> P256.Signing.PrivateKey {
        let tagString = "\(namespace).dpopkeypair"
        return try retrieveDPoPKey(keyTag: tagString, accessGroup: accessGroup)
    }

    /// Deletes a DPoP private key from the keychain within a specified namespace.
    /// Legacy support for existing code.
    static func deleteDPoPKey(namespace: String, accessGroup: String? = nil) throws {
        let tagString = "\(namespace).dpopkeypair"
        try deleteDPoPKey(keyTag: tagString, accessGroup: accessGroup)
    }

    /// Deletes DPoP key bindings from the keychain for a specified namespace.
    static func deleteDPoPKeyBindings(namespace: String, accessGroup: String? = nil) throws {
        let bindingsKey = "\(namespace).dpopKeyBindings"
        let resolvedAccessGroup = resolvedAccessGroup(accessGroup)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: bindingsKey,
        ].merging(Self.accessGroupAttributes(resolvedAccessGroup)) { _, new in new }

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            LogManager.logError(
                "KeychainManager - Failed to delete DPoP key bindings for namespace \(namespace). Status: \(status)"
            )
            throw KeychainError.itemStoreError(status: Int(status))
        }

        // Remove from cache
        dataCache.removeObject(forKey: bindingsKey as NSString)

        LogManager.logDebug(
            "KeychainManager - Successfully deleted DPoP key bindings for namespace \(namespace)."
        )
    }

    /// Deletes DPoP key bindings for a specific DID
    static func deleteDPoPKeyBindingsForDID(
        namespace: String,
        did: String,
        accessGroup: String? = nil
    ) throws {
        let bindingsKey = "\(namespace).dpopKeyBindings.\(did)"
        let resolvedAccessGroup = resolvedAccessGroup(accessGroup)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: bindingsKey,
        ].merging(Self.accessGroupAttributes(resolvedAccessGroup)) { _, new in new }

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            LogManager.logError(
                "KeychainManager - Failed to delete DPoP key bindings for DID \(did). Status: \(status)"
            )
            throw KeychainError.itemStoreError(status: Int(status))
        }

        // Remove from cache
        dataCache.removeObject(forKey: bindingsKey as NSString)

        LogManager.logDebug("KeychainManager - Successfully deleted DPoP key bindings for DID \(did).")
    }

    // MARK: - Initialization

    /// Call this at app startup
    static func initialize() {
        configureCaches()
    }

    // MARK: - Async Wrappers for CLI/Actor Safety

    /// Async wrapper for retrieve that offloads the blocking Security framework call to a background thread.
    /// This prevents blocking actor executors when called from within actors.
    static func retrieveAsync(
        key: String,
        namespace: String,
        accessGroup: String? = nil
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try retrieve(key: key, namespace: namespace, accessGroup: accessGroup)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Async wrapper for store that offloads the blocking Security framework call to a background thread.
    static func storeAsync(
        key: String,
        value: Data,
        namespace: String,
        accessibility: CFString? = nil,
        accessGroup: String? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try store(key: key, value: value, namespace: namespace, accessibility: accessibility, accessGroup: accessGroup)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Async wrapper for delete that offloads the blocking Security framework call to a background thread.
    static func deleteAsync(
        key: String,
        namespace: String,
        accessGroup: String? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try delete(key: key, namespace: namespace, accessGroup: accessGroup)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Async wrapper for retrieveDPoPKey that offloads the blocking Security framework call to a background thread.
    static func retrieveDPoPKeyAsync(
        keyTag: String,
        accessGroup: String? = nil
    ) async throws -> P256.Signing.PrivateKey {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let key = try retrieveDPoPKey(keyTag: keyTag, accessGroup: accessGroup)
                    continuation.resume(returning: key)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Async wrapper for storeDPoPKey that offloads the blocking Security framework call to a background thread.
    static func storeDPoPKeyAsync(
        _ key: P256.Signing.PrivateKey,
        keyTag: String,
        accessGroup: String? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try storeDPoPKey(key, keyTag: keyTag, accessGroup: accessGroup)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Async wrapper for deleteDPoPKey that offloads the blocking Security framework call to a background thread.
    static func deleteDPoPKeyAsync(
        keyTag: String,
        accessGroup: String? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try deleteDPoPKey(keyTag: keyTag, accessGroup: accessGroup)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Gateway Session Management

    /// Saves the gateway session ID
    static func saveGatewaySession(_ session: String) throws {
        guard let data = session.data(using: .utf8) else {
            throw KeychainError.dataFormatError
        }
        try store(key: "gatewaySession", value: data, namespace: "catbird.gateway")
    }

    /// Retrieves the gateway session ID
    static func getGatewaySession() throws -> String? {
        do {
            let data = try retrieve(key: "gatewaySession", namespace: "catbird.gateway")
            return String(data: data, encoding: .utf8)
        } catch {
            if isItemNotFound(error) {
                return nil
            }
            throw error
        }
    }

    /// Deletes the gateway session ID
    static func deleteGatewaySession() throws {
        try delete(key: "gatewaySession", namespace: "catbird.gateway")
    }
}
