//
//  KeychainManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 11/20/23.
//

import CryptoKit
import Foundation
import Security

enum KeychainError: Error, LocalizedError {
    case itemStoreError(status: OSStatus)
    case itemRetrievalError(status: OSStatus)
    case dataFormatError
    case unableToCreateKey
    case deletionError(status: OSStatus)

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
        switch self {
        case let .itemStoreError(status) where status == errSecDuplicateItem:
            return "An item with this key already exists in the keychain."
        case let .itemStoreError(status) where status == errSecAuthFailed:
            return "Authentication failed while accessing keychain."
        case let .itemRetrievalError(status) where status == errSecItemNotFound:
            return "The requested item was not found in the keychain."
        case let .itemRetrievalError(status) where status == errSecAuthFailed:
            return "Authentication failed while accessing keychain."
        case .dataFormatError:
            return "The stored keychain data cannot be decoded or is missing required fields."
        case .unableToCreateKey:
            return "The cryptographic key data from keychain is invalid or corrupted."
        case let .deletionError(status) where status == errSecAuthFailed:
            return "Authentication failed while accessing keychain."
        default:
            return "Keychain operation failed due to system restrictions or device state."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case let .itemStoreError(status) where status == errSecAuthFailed,
             .itemRetrievalError(let status) where status == errSecAuthFailed,
             .deletionError(let status) where status == errSecAuthFailed:
            return "Please unlock your device and ensure the app has keychain access."
        case let .itemRetrievalError(status) where status == errSecItemNotFound:
            return "You may need to log in again to restore your credentials."
        case .dataFormatError, .unableToCreateKey:
            return "Please log out and log back in to reset your stored credentials."
        case let .itemStoreError(status) where status == errSecDuplicateItem:
            return "Please restart the app or log out and log back in."
        default:
            return "Try restarting the app. If the problem persists, you may need to log out and log back in."
        }
    }
}

enum KeychainManager {
    // MARK: - Platform-specific Configuration

    /// Returns the appropriate keychain accessibility for the current platform
    private static var defaultAccessibility: CFString {
        #if os(iOS)
            return kSecAttrAccessibleAfterFirstUnlock
        #elseif os(macOS)
            return kSecAttrAccessibleWhenUnlocked
        #endif
    }

    /// Returns platform-specific keychain query attributes
    private static func platformSpecificAttributes() -> [String: Any] {
        var attributes: [String: Any] = [:]

        #if os(macOS)
            // Disable iCloud sync for app-specific keychain items on macOS
            attributes[kSecAttrSynchronizable as String] = false
        #endif

        return attributes
    }

    // MARK: - Cache

    // Thread-safe caches with automatic memory management
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
        accessibility: CFString? = nil
    ) throws {
        let namespacedKey = "\(namespace).\(key)"

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: namespacedKey,
            kSecValueData as String: value,
            kSecAttrAccessible as String: accessibility ?? defaultAccessibility,
        ]

        // Add platform-specific attributes
        query.merge(platformSpecificAttributes()) { _, new in new }

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
        LogManager.logDebug("KEYCHAIN_MANAGER: Attempting to delete key: \(namespacedKey)")

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: namespacedKey,
        ]

        let status = SecItemDelete(query as CFDictionary)
        LogManager.logDebug("KEYCHAIN_MANAGER: Delete status for key \(namespacedKey): \(status)")

        if status != errSecSuccess, status != errSecItemNotFound {
            LogManager.logError(
                "KeychainManager - Failed to delete item for key \(namespacedKey). Status: \(status)")
            throw KeychainError.itemStoreError(status: status)
        }

        // Remove from cache
        dataCache.removeObject(forKey: namespacedKey as NSString)

        LogManager.logDebug(
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
        #if os(iOS)
            try storeDPoPKeyiOS(key, keyTag: keyTag)
        #elseif os(macOS)
            try storeDPoPKeymacOS(key, keyTag: keyTag)
        #endif

        // Update cache
        dpopKeyCache.setObject(CachedDPoPKey(key: key), forKey: keyTag as NSString)
    }

    /// iOS-specific DPoP key storage using kSecClassKey (works fine on iOS)
    #if os(iOS)
        private static func storeDPoPKeyiOS(_ key: P256.Signing.PrivateKey, keyTag: String) throws {
            guard let tagData = keyTag.data(using: .utf8) else {
                throw KeychainError.dataFormatError
            }

            var query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits as String: 256,
                kSecAttrApplicationTag as String: tagData,
                kSecValueData as String: key.x963Representation,
                kSecAttrAccessible as String: defaultAccessibility,
            ]

            // Delete any existing key first
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tagData,
            ]

            let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
            LogManager.logDebug("KeychainManager - iOS delete status: \(deleteStatus)")

            // Add the new key
            let status = SecItemAdd(query as CFDictionary, nil)
            if status == errSecDuplicateItem {
                // Try update
                let updateAttributes: [String: Any] = [
                    kSecValueData as String: key.x963Representation,
                ]
                let updateStatus = SecItemUpdate(deleteQuery as CFDictionary, updateAttributes as CFDictionary)
                guard updateStatus == errSecSuccess else {
                    LogManager.logError("KeychainManager - iOS update failed: \(updateStatus)")
                    throw KeychainError.itemStoreError(status: updateStatus)
                }
                LogManager.logDebug("KeychainManager - iOS key updated for tag \(keyTag)")
            } else if status != errSecSuccess {
                LogManager.logError("KeychainManager - iOS add failed: \(status)")
                throw KeychainError.itemStoreError(status: status)
            } else {
                LogManager.logDebug("KeychainManager - iOS key added for tag \(keyTag)")
            }
        }
    #endif

    /// macOS-specific DPoP key storage using SecKey conversion
    #if os(macOS)
        private static func storeDPoPKeymacOS(_ key: P256.Signing.PrivateKey, keyTag: String) throws {
            LogManager.logDebug("KeychainManager - Storing DPoP key on macOS using SecKey approach for tag: \(keyTag)")

            // First, try to delete any existing key (multiple approaches)
            try? deleteDPoPKeymacOS(keyTag: keyTag)

            // Convert CryptoKit key to SecKey
            let keyData = key.x963Representation
            let attributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                kSecAttrKeySizeInBits as String: 256,
            ]

            var error: Unmanaged<CFError>?
            guard let secKey = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error) else {
                let errorDescription = error?.takeRetainedValue().localizedDescription ?? "unknown error"
                LogManager.logError("KeychainManager - Failed to create SecKey from P256 data: \(errorDescription)")

                // Fallback: store as generic password
                LogManager.logDebug("KeychainManager - Falling back to generic password storage for tag: \(keyTag)")
                try storeDPoPKeyAsPasswordmacOS(key, keyTag: keyTag)
                return
            }

            // Store SecKey in keychain
            guard let tagData = keyTag.data(using: .utf8) else {
                throw KeychainError.dataFormatError
            }

            let query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tagData,
                kSecValueRef as String: secKey,
                kSecAttrAccessible as String: defaultAccessibility,
                kSecAttrSynchronizable as String: false,
            ]

            let status = SecItemAdd(query as CFDictionary, nil)
            if status == errSecDuplicateItem {
                // Try update
                let updateQuery: [String: Any] = [
                    kSecClass as String: kSecClassKey,
                    kSecAttrApplicationTag as String: tagData,
                ]
                let updateAttributes: [String: Any] = [
                    kSecValueRef as String: secKey,
                ]
                let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
                guard updateStatus == errSecSuccess else {
                    LogManager.logError("KeychainManager - macOS SecKey update failed: \(updateStatus)")
                    // Fallback to password storage
                    try storeDPoPKeyAsPasswordmacOS(key, keyTag: keyTag)
                    return
                }
                LogManager.logDebug("KeychainManager - macOS SecKey updated for tag \(keyTag)")
            } else if status != errSecSuccess {
                LogManager.logError("KeychainManager - macOS SecKey add failed: \(status)")
                // Fallback to password storage
                try storeDPoPKeyAsPasswordmacOS(key, keyTag: keyTag)
                return
            } else {
                LogManager.logDebug("KeychainManager - macOS SecKey added for tag \(keyTag)")
            }
        }

        /// Fallback: Store DPoP key as generic password on macOS
        private static func storeDPoPKeyAsPasswordmacOS(_ key: P256.Signing.PrivateKey, keyTag: String) throws {
            LogManager.logDebug("KeychainManager - Storing DPoP key as password for tag: \(keyTag)")

            let passwordKey = "\(keyTag).password"
            try store(key: passwordKey, value: key.x963Representation, namespace: "dpopkeys")

            LogManager.logDebug("KeychainManager - Successfully stored DPoP key as password for tag: \(keyTag)")
        }

        /// Helper to delete existing macOS keys (tries multiple approaches)
        private static func deleteDPoPKeymacOS(keyTag: String) throws {
            guard let tagData = keyTag.data(using: .utf8) else {
                throw KeychainError.dataFormatError
            }

            // Try to delete SecKey
            let keyQuery: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tagData,
            ]
            let keyStatus = SecItemDelete(keyQuery as CFDictionary)
            LogManager.logDebug("KeychainManager - macOS SecKey delete status: \(keyStatus)")

            // Try to delete password fallback
            let passwordKey = "\(keyTag).password"
            try? delete(key: passwordKey, namespace: "dpopkeys")
        }
    #endif

    /// Retrieves a DPoP private key from the keychain with a specified key tag.
    static func retrieveDPoPKey(keyTag: String) throws -> P256.Signing.PrivateKey {
        // Check cache first
        if let cachedKey = dpopKeyCache.object(forKey: keyTag as NSString) {
            LogManager.logDebug("KeychainManager - Retrieved DPoP key from cache for tag \(keyTag).")
            return cachedKey.key
        }

        let key: P256.Signing.PrivateKey

        #if os(iOS)
            key = try retrieveDPoPKeyiOS(keyTag: keyTag)
        #elseif os(macOS)
            key = try retrieveDPoPKeymacOS(keyTag: keyTag)
        #endif

        // Update cache
        dpopKeyCache.setObject(CachedDPoPKey(key: key), forKey: keyTag as NSString)
        return key
    }

    /// iOS-specific DPoP key retrieval
    #if os(iOS)
        private static func retrieveDPoPKeyiOS(keyTag: String) throws -> P256.Signing.PrivateKey {
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

            guard status == errSecSuccess, let data = item as? Data else {
                LogManager.logError("KeychainManager - iOS failed to retrieve DPoP key for tag \(keyTag). Status: \(status)")
                throw KeychainError.itemRetrievalError(status: status)
            }

            do {
                let key = try P256.Signing.PrivateKey(x963Representation: data)
                LogManager.logDebug("KeychainManager - iOS successfully retrieved DPoP key for tag \(keyTag)")
                return key
            } catch {
                LogManager.logError("KeychainManager - iOS failed to reconstruct P256 key: \(error)")
                throw KeychainError.unableToCreateKey
            }
        }
    #endif

    /// macOS-specific DPoP key retrieval
    #if os(macOS)
        private static func retrieveDPoPKeymacOS(keyTag: String) throws -> P256.Signing.PrivateKey {
            // First try to retrieve as SecKey
            if let key = try? retrieveDPoPKeyAsSecKeymacOS(keyTag: keyTag) {
                return key
            }

            // Fallback: try to retrieve as password
            LogManager.logDebug("KeychainManager - SecKey retrieval failed, trying password fallback for tag: \(keyTag)")
            return try retrieveDPoPKeyAsPasswordmacOS(keyTag: keyTag)
        }

        /// Retrieve DPoP key as SecKey on macOS
        private static func retrieveDPoPKeyAsSecKeymacOS(keyTag: String) throws -> P256.Signing.PrivateKey {
            guard let tagData = keyTag.data(using: .utf8) else {
                throw KeychainError.dataFormatError
            }

            let query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tagData,
                kSecReturnRef as String: kCFBooleanTrue!,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)

            guard status == errSecSuccess, let secKey = item else {
                LogManager.logDebug("KeychainManager - SecKey not found for tag \(keyTag). Status: \(status)")
                throw KeychainError.itemRetrievalError(status: status)
            }

            // Convert SecKey back to raw data
            var error: Unmanaged<CFError>?
            guard let keyData = SecKeyCopyExternalRepresentation(secKey as! SecKey, &error) else {
                let errorDescription = error?.takeRetainedValue().localizedDescription ?? "unknown error"
                LogManager.logError("KeychainManager - Failed to extract data from SecKey: \(errorDescription)")
                throw KeychainError.unableToCreateKey
            }

            do {
                let key = try P256.Signing.PrivateKey(x963Representation: keyData as Data)
                LogManager.logDebug("KeychainManager - Successfully retrieved DPoP key as SecKey for tag \(keyTag)")
                return key
            } catch {
                LogManager.logError("KeychainManager - Failed to reconstruct P256 key from SecKey data: \(error)")
                throw KeychainError.unableToCreateKey
            }
        }

        /// Retrieve DPoP key as password on macOS (fallback)
        private static func retrieveDPoPKeyAsPasswordmacOS(keyTag: String) throws -> P256.Signing.PrivateKey {
            let passwordKey = "\(keyTag).password"

            do {
                let data = try retrieve(key: passwordKey, namespace: "dpopkeys")
                let key = try P256.Signing.PrivateKey(x963Representation: data)
                LogManager.logDebug("KeychainManager - Successfully retrieved DPoP key as password for tag \(keyTag)")
                return key
            } catch {
                LogManager.logError("KeychainManager - Failed to retrieve DPoP key as password for tag \(keyTag): \(error)")
                throw KeychainError.itemRetrievalError(status: errSecItemNotFound)
            }
        }
    #endif

    /// Deletes a DPoP private key from the keychain with a specified key tag.
    static func deleteDPoPKey(keyTag: String) throws {
        #if os(iOS)
            try deleteDPoPKeyiOS(keyTag: keyTag)
        #elseif os(macOS)
            try deleteDPoPKeymacOS(keyTag: keyTag)
        #endif

        // Remove from cache
        dpopKeyCache.removeObject(forKey: keyTag as NSString)
    }

    /// iOS-specific DPoP key deletion
    #if os(iOS)
        private static func deleteDPoPKeyiOS(keyTag: String) throws {
            guard let tagData = keyTag.data(using: .utf8) else {
                throw KeychainError.dataFormatError
            }

            let query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tagData,
            ]

            let status = SecItemDelete(query as CFDictionary)
            if status != errSecSuccess, status != errSecItemNotFound {
                LogManager.logError("KeychainManager - iOS failed to delete DPoP key for tag \(keyTag). Status: \(status)")
                throw KeychainError.itemStoreError(status: status)
            }

            LogManager.logDebug("KeychainManager - iOS successfully deleted DPoP key for tag \(keyTag)")
        }
    #endif

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
