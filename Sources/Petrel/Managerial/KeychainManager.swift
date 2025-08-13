//
//  KeychainManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 11/20/23.
//

import CryptoKit
import Foundation
import Security

enum KeychainError: Error {
    case itemStoreError(status: OSStatus)
    case itemRetrievalError(status: OSStatus)
    case dataFormatError
    case unableToCreateKey
    case deletionError(status: OSStatus)
}

final class KeychainManager {
    // MARK: - Cache

    // Thread-safe caches with automatic memory management
    nonisolated(unsafe) private static let dataCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = 100
        return cache
    }()

    nonisolated(unsafe) private static var dpopKeyCache: NSCache<NSString, CachedDPoPKey> = {
        let cache = NSCache<NSString, CachedDPoPKey>()
        cache.countLimit = 100
        return cache
    }()

    // Wrapper class for P256.Signing.PrivateKey to make it cacheable
    private final class CachedDPoPKey: NSObject, @unchecked Sendable {
        let key: P256.Signing.PrivateKey

        init(key: P256.Signing.PrivateKey) {
            self.key = key
            super.init()
        }
    }

    // Configure cache limits
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

    static func deleteExplicitKey(_ exactKey: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: exactKey,
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            throw KeychainError.deletionError(status: status)
        }

        // Remove from cache
        dataCache.removeObject(forKey: exactKey as NSString)
    }

    /// Stores data in the keychain with a specified key and namespace.
    static func store(
        key: String,
        value: Data,
        namespace: String,
        accessibility: CFString = kSecAttrAccessibleAfterFirstUnlock
    ) throws {
        let namespacedKey = "\(namespace).\(key)"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: namespacedKey,
            kSecValueData as String: value,
            kSecAttrAccessible as String: accessibility,
        ]

        // Delete any existing item with the same key
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess, deleteStatus != errSecItemNotFound {
            LogManager.logError(
                "KeychainManager - Failed to delete existing item for key \(namespacedKey). Status: \(deleteStatus)"
            )
            throw KeychainError.itemStoreError(status: deleteStatus)
        }

        // Add the new item to the keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            LogManager.logError("KeychainManager - Duplicate item for key \(namespacedKey).")
            throw KeychainError.itemStoreError(status: status)
        }
        guard status == errSecSuccess else {
            LogManager.logError(
                "KeychainManager - Failed to store item for key \(namespacedKey). Status: \(status)")
            throw KeychainError.itemStoreError(status: status)
        }

        // Update cache
        dataCache.setObject(value as NSData, forKey: namespacedKey as NSString)

        LogManager.logDebug("KeychainManager - Successfully stored item for key \(namespacedKey).")
    }

    /// Retrieves data from the keychain for a specified key and namespace.
    static func retrieve(key: String, namespace: String) throws -> Data {
        let namespacedKey = "\(namespace).\(key)"

        // Check cache first
        if let cachedData = dataCache.object(forKey: namespacedKey as NSString) {
            LogManager.logDebug("KeychainManager - Retrieved item from cache for key \(namespacedKey).")
            return cachedData as Data
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: namespacedKey,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            LogManager.logError("KeychainManager - Item not found for key \(namespacedKey).")
            throw KeychainError.itemRetrievalError(status: status)
        }

        guard status == errSecSuccess else {
            LogManager.logError(
                "KeychainManager - Failed to retrieve item for key \(namespacedKey). Status: \(status)")
            throw KeychainError.itemRetrievalError(status: status)
        }
        guard let data = item as? Data else {
            LogManager.logError("KeychainManager - Data format error for key \(namespacedKey).")
            throw KeychainError.dataFormatError
        }

        // Store in cache
        dataCache.setObject(data as NSData, forKey: namespacedKey as NSString)

        LogManager.logDebug("KeychainManager - Successfully retrieved item for key \(namespacedKey).")
        return data
    }

    static func storeObject<T: Encodable>(_ object: T, key: String, namespace: String) throws {
        let data = try JSONEncoder().encode(object)
        try store(key: key, value: data, namespace: namespace)
    }

    static func retrieveObject<T: Decodable>(key: String, namespace: String) throws -> T {
        let data = try retrieve(key: key, namespace: namespace)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Deletes data from the keychain for a specified key and namespace.
    static func delete(key: String, namespace: String) throws {
        let namespacedKey = "\(namespace).\(key)"
        LogManager.logError("KEYCHAIN_MANAGER: Attempting to delete key: \(namespacedKey)")

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: namespacedKey,
        ]

        let status = SecItemDelete(query as CFDictionary)
        LogManager.logError("KEYCHAIN_MANAGER: Delete status for key \(namespacedKey): \(status)")

        if status != errSecSuccess, status != errSecItemNotFound {
            LogManager.logError(
                "KeychainManager - Failed to delete item for key \(namespacedKey). Status: \(status)")
            throw KeychainError.itemStoreError(status: status)
        }

        // Remove from cache
        dataCache.removeObject(forKey: namespacedKey as NSString)

        LogManager.logError(
            "KEYCHAIN_MANAGER: Successfully deleted item for key \(namespacedKey). Status: \(status)")
    }

    static func nukeAllKeychainItems(forNamespace namespace: String) -> Bool {
        // Handle generic passwords first
        let genericSuccess = nukeGenericPasswords(withNamespacePrefix: namespace)

        // Then handle crypto keys
        let keysSuccess = nukeCryptoKeys(withNamespacePrefix: namespace)

        // Clear cache for this namespace
        clearCache(forNamespace: namespace)

        return genericSuccess && keysSuccess
    }

    private static func nukeGenericPasswords(withNamespacePrefix namespace: String) -> Bool {
        // Query to get all generic passwords
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let items = result as? [[String: Any]] {
            var allSucceeded = true
            var matchedCount = 0

            // Filter and delete items that match our namespace
            for item in items {
                if let account = item[kSecAttrAccount as String] as? String,
                   account.hasPrefix("\(namespace).")
                {
                    matchedCount += 1
                    LogManager.logInfo("KeychainManager - Deleting keychain item: \(account)")

                    let deleteQuery: [String: Any] = [
                        kSecClass as String: kSecClassGenericPassword,
                        kSecAttrAccount as String: account,
                    ]

                    let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
                    if deleteStatus != errSecSuccess {
                        LogManager.logError("KeychainManager - Failed to delete item \(account): \(deleteStatus)")
                        allSucceeded = false
                    }

                    // Remove from cache
                    dataCache.removeObject(forKey: account as NSString)
                }
            }

            LogManager.logInfo("KeychainManager - Nuked \(matchedCount) generic passwords from keychain for namespace: \(namespace)")
            return allSucceeded
        } else if status == errSecItemNotFound {
            LogManager.logInfo("KeychainManager - No generic password items found in keychain for namespace: \(namespace)")
            return true
        } else {
            LogManager.logError("KeychainManager - Failed to query generic password keychain items: \(status)")
            return false
        }
    }

    private static func nukeCryptoKeys(withNamespacePrefix namespace: String) -> Bool {
        // Query to get all keys
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let items = result as? [[String: Any]] {
            var allSucceeded = true
            var matchedCount = 0

            // Filter and delete keys
            for item in items {
                // For keys, check the application tag
                if let tagData = item[kSecAttrApplicationTag as String] as? Data,
                   let tagString = String(data: tagData, encoding: .utf8),
                   tagString.hasPrefix("\(namespace).")
                {
                    matchedCount += 1
                    LogManager.logInfo("KeychainManager - Deleting key: \(tagString)")

                    let deleteQuery: [String: Any] = [
                        kSecClass as String: kSecClassKey,
                        kSecAttrApplicationTag as String: tagData,
                    ]

                    let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
                    if deleteStatus != errSecSuccess {
                        LogManager.logError("KeychainManager - Failed to delete key \(tagString): \(deleteStatus)")
                        allSucceeded = false
                    }

                    // Remove from cache
                    dpopKeyCache.removeObject(forKey: tagString as NSString)
                }
            }

            LogManager.logInfo("KeychainManager - Nuked \(matchedCount) keys from keychain for namespace: \(namespace)")
            return allSucceeded
        } else if status == errSecItemNotFound {
            LogManager.logInfo("KeychainManager - No key items found in keychain for namespace: \(namespace)")
            return true
        } else {
            LogManager.logError("KeychainManager - Failed to query key keychain items: \(status)")
            return false
        }
    }

    // MARK: - DPoP Key Methods

    /// Stores a DPoP private key in the keychain with a specified key tag.
    static func storeDPoPKey(_ key: P256.Signing.PrivateKey, keyTag: String) throws {
        guard let tagData = keyTag.data(using: .utf8) else {
            throw KeychainError.dataFormatError
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrApplicationTag as String: tagData,
            kSecValueData as String: key.x963Representation,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        // Delete any existing key with the same tag
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess, deleteStatus != errSecItemNotFound {
            LogManager.logError(
                "KeychainManager - Failed to delete existing DPoP key for tag \(keyTag). Status: \(deleteStatus)"
            )
            throw KeychainError.itemStoreError(status: deleteStatus)
        }

        // Add the new key to the keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            LogManager.logError(
                "KeychainManager - Failed to store DPoP key for tag \(keyTag). Status: \(status)")
            throw KeychainError.itemStoreError(status: status)
        }

        // Update cache
        dpopKeyCache.setObject(CachedDPoPKey(key: key), forKey: keyTag as NSString)

        LogManager.logDebug("KeychainManager - Successfully stored DPoP key for tag \(keyTag).")
    }

    /// Retrieves a DPoP private key from the keychain with a specified key tag.
    static func retrieveDPoPKey(keyTag: String) throws -> P256.Signing.PrivateKey {
        // Check cache first
        if let cachedKey = dpopKeyCache.object(forKey: keyTag as NSString) {
            LogManager.logDebug("KeychainManager - Retrieved DPoP key from cache for tag \(keyTag).")
            return cachedKey.key
        }

        guard let tagData = keyTag.data(using: .utf8) else {
            throw KeychainError.dataFormatError
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            LogManager.logError("KeychainManager - DPoP key not found for tag \(keyTag).")
            throw KeychainError.itemRetrievalError(status: status)
        }

        guard status == errSecSuccess else {
            LogManager.logError(
                "KeychainManager - Failed to retrieve DPoP key for tag \(keyTag). Status: \(status)")
            throw KeychainError.itemRetrievalError(status: status)
        }
        guard let keyData = item as? Data else {
            LogManager.logError("KeychainManager - DPoP key data format error for tag \(keyTag).")
            throw KeychainError.dataFormatError
        }

        do {
            let privateKey = try P256.Signing.PrivateKey(x963Representation: keyData)

            // Store in cache
            dpopKeyCache.setObject(CachedDPoPKey(key: privateKey), forKey: keyTag as NSString)

            LogManager.logDebug("KeychainManager - Successfully retrieved DPoP key for tag \(keyTag).")
            return privateKey
        } catch {
            LogManager.logError(
                "KeychainManager - Unable to create P256.Signing.PrivateKey from data for tag \(keyTag). Error: \(error)"
            )
            throw KeychainError.unableToCreateKey
        }
    }

    /// Deletes a DPoP private key from the keychain with a specified key tag.
    static func deleteDPoPKey(keyTag: String) throws {
        guard let tagData = keyTag.data(using: .utf8) else {
            throw KeychainError.dataFormatError
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            LogManager.logError(
                "KeychainManager - Failed to delete DPoP key for tag \(keyTag). Status: \(status)")
            throw KeychainError.itemStoreError(status: status)
        }

        // Remove from cache
        dpopKeyCache.removeObject(forKey: keyTag as NSString)

        LogManager.logDebug("KeychainManager - Successfully deleted DPoP key for tag \(keyTag).")
    }

    /// Stores a DPoP private key in the keychain within a specified namespace.
    /// Legacy support for existing code.
    static func storeDPoPKey(_ key: P256.Signing.PrivateKey, namespace: String) throws {
        let tagString = "\(namespace).dpopkeypair"
        try storeDPoPKey(key, keyTag: tagString)
    }

    /// Retrieves a DPoP private key from the keychain within a specified namespace.
    /// Legacy support for existing code.
    static func retrieveDPoPKey(namespace: String) throws -> P256.Signing.PrivateKey {
        let tagString = "\(namespace).dpopkeypair"
        return try retrieveDPoPKey(keyTag: tagString)
    }

    /// Deletes a DPoP private key from the keychain within a specified namespace.
    /// Legacy support for existing code.
    static func deleteDPoPKey(namespace: String) throws {
        let tagString = "\(namespace).dpopkeypair"
        try deleteDPoPKey(keyTag: tagString)
    }

    /// Deletes DPoP key bindings from the keychain for a specified namespace.
    static func deleteDPoPKeyBindings(namespace: String) throws {
        let bindingsKey = "\(namespace).dpopKeyBindings"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: bindingsKey,
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            LogManager.logError(
                "KeychainManager - Failed to delete DPoP key bindings for namespace \(namespace). Status: \(status)"
            )
            throw KeychainError.itemStoreError(status: status)
        }

        // Remove from cache
        dataCache.removeObject(forKey: bindingsKey as NSString)

        LogManager.logDebug(
            "KeychainManager - Successfully deleted DPoP key bindings for namespace \(namespace).")
    }

    /// Deletes DPoP key bindings for a specific DID
    static func deleteDPoPKeyBindingsForDID(namespace: String, did: String) throws {
        let bindingsKey = "\(namespace).dpopKeyBindings.\(did)"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: bindingsKey,
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            LogManager.logError(
                "KeychainManager - Failed to delete DPoP key bindings for DID \(did). Status: \(status)")
            throw KeychainError.itemStoreError(status: status)
        }

        // Remove from cache
        dataCache.removeObject(forKey: bindingsKey as NSString)

        LogManager.logDebug("KeychainManager - Successfully deleted DPoP key bindings for DID \(did).")
    }

    // MARK: - Initialization

    // Call this at app startup
    static func initialize() {
        configureCaches()
    }
}
