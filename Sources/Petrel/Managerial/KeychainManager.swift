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

enum KeychainManager {
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
        LogManager.logDebug("KeychainManager - Successfully stored item for key \(namespacedKey).")
    }

    /// Retrieves data from the keychain for a specified key and namespace.
    static func retrieve(key: String, namespace: String) throws -> Data {
        let namespacedKey = "\(namespace).\(key)"

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
        LogManager.logError(
            "KEYCHAIN_MANAGER: Successfully deleted item for key \(namespacedKey). Status: \(status)")
    }

    static func nukeAllKeychainItems(forNamespace namespace: String) -> Bool {
        // Get all items in the keychain for your app
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: namespace,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let items = result as? [[String: Any]] {
            var allSucceeded = true

            // Log what we're about to delete
            LogManager.logInfo("KeychainManager - Nuking \(items.count) items from keychain for namespace: \(namespace)")

            // Delete each item individually
            for item in items {
                if let account = item[kSecAttrAccount as String] as? String {
                    LogManager.logInfo("KeychainManager - Deleting keychain item: \(account)")

                    let deleteQuery: [String: Any] = [
                        kSecClass as String: kSecClassGenericPassword,
                        kSecAttrService as String: namespace,
                        kSecAttrAccount as String: account,
                    ]

                    let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
                    if deleteStatus != errSecSuccess {
                        LogManager.logError("KeychainManager - Failed to delete item \(account): \(deleteStatus)")
                        allSucceeded = false
                    }
                }
            }

            return allSucceeded
        } else if status == errSecItemNotFound {
            // No items found, technically a success
            LogManager.logInfo("KeychainManager - No items found in keychain for namespace: \(namespace)")
            return true
        } else {
            // Something went wrong with the query
            LogManager.logError("KeychainManager - Failed to query keychain items: \(status)")
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
        LogManager.logDebug("KeychainManager - Successfully stored DPoP key for tag \(keyTag).")
    }

    /// Retrieves a DPoP private key from the keychain with a specified key tag.
    static func retrieveDPoPKey(keyTag: String) throws -> P256.Signing.PrivateKey {
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
        LogManager.logDebug("KeychainManager - Successfully deleted DPoP key bindings for DID \(did).")
    }
}
