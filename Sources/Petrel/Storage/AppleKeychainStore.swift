//
//  AppleKeychainStore.swift
//  Petrel
//
//  Apple platform keychain storage implementation
//

#if os(iOS) || os(macOS)

    import CryptoKit
    import Foundation
    import Security

    /// Secure storage implementation using Apple's Keychain Services
    final class AppleKeychainStore: SecureStorage {
        // MARK: - Platform-specific Configuration

        /// Returns the appropriate keychain accessibility for the current platform
        private static var defaultAccessibility: CFString {
            #if os(iOS)
                return kSecAttrAccessibleAfterFirstUnlock
            #elseif os(macOS)
                return kSecAttrAccessibleAfterFirstUnlock
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

        // MARK: - SecureStorage Implementation

        func store(key: String, value: Data, namespace: String) throws {
            let namespacedKey = "\(namespace).\(key)"

            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: namespacedKey,
                kSecValueData as String: value,
                kSecAttrAccessible as String: Self.defaultAccessibility,
            ]

            // Add platform-specific attributes
            query.merge(Self.platformSpecificAttributes()) { _, new in new }

            // Delete any existing item with the same key
            let deleteStatus = SecItemDelete(query as CFDictionary)
            if deleteStatus != errSecSuccess, deleteStatus != errSecItemNotFound {
                LogManager.logError(
                    "AppleKeychainStore - Failed to delete existing item for key \(namespacedKey). Status: \(deleteStatus)"
                )
                throw KeychainError.itemStoreError(status: Int(deleteStatus))
            }

            // Add the new item to the keychain
            let status = SecItemAdd(query as CFDictionary, nil)
            if status == errSecDuplicateItem {
                LogManager.logError("AppleKeychainStore - Duplicate item for key \(namespacedKey).")
                throw KeychainError.itemStoreError(status: Int(status))
            }
            guard status == errSecSuccess else {
                LogManager.logError(
                    "AppleKeychainStore - Failed to store item for key \(namespacedKey). Status: \(status)")
                throw KeychainError.itemStoreError(status: Int(status))
            }

            LogManager.logDebug("AppleKeychainStore - Successfully stored item for key \(namespacedKey).")
        }

        func retrieve(key: String, namespace: String) throws -> Data {
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
                LogManager.logError("AppleKeychainStore - Item not found for key \(namespacedKey).")
                throw KeychainError.itemRetrievalError(status: Int(status))
            }

            guard status == errSecSuccess else {
                LogManager.logError(
                    "AppleKeychainStore - Failed to retrieve item for key \(namespacedKey). Status: \(status)")
                throw KeychainError.itemRetrievalError(status: Int(status))
            }
            guard let data = item as? Data else {
                LogManager.logError("AppleKeychainStore - Data format error for key \(namespacedKey).")
                throw KeychainError.dataFormatError
            }

            LogManager.logDebug("AppleKeychainStore - Successfully retrieved item for key \(namespacedKey).")
            return data
        }

        func delete(key: String, namespace: String) throws {
            let namespacedKey = "\(namespace).\(key)"
            LogManager.logDebug("AppleKeychainStore: Attempting to delete key: \(namespacedKey)")

            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: namespacedKey,
            ]

            let status = SecItemDelete(query as CFDictionary)
            LogManager.logDebug("AppleKeychainStore: Delete status for key \(namespacedKey): \(status)")

            if status != errSecSuccess, status != errSecItemNotFound {
                LogManager.logError(
                    "AppleKeychainStore - Failed to delete item for key \(namespacedKey). Status: \(status)")
                throw KeychainError.itemStoreError(status: Int(status))
            }

            LogManager.logDebug(
                "AppleKeychainStore: Successfully deleted item for key \(namespacedKey). Status: \(status)")
        }

        func deleteAll(namespace: String) throws {
            // Handle generic passwords first
            let genericSuccess = try deleteGenericPasswords(withNamespacePrefix: namespace)

            // Then handle crypto keys
            let keysSuccess = try deleteCryptoKeys(withNamespacePrefix: namespace)

            guard genericSuccess, keysSuccess else {
                throw KeychainError.deletionError(status: -1)
            }
        }

        private func deleteGenericPasswords(withNamespacePrefix namespace: String) throws -> Bool {
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
                        LogManager.logInfo("AppleKeychainStore - Deleting keychain item: \(account)")

                        let deleteQuery: [String: Any] = [
                            kSecClass as String: kSecClassGenericPassword,
                            kSecAttrAccount as String: account,
                        ]

                        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
                        if deleteStatus != errSecSuccess {
                            LogManager.logError("AppleKeychainStore - Failed to delete item \(account): \(deleteStatus)")
                            allSucceeded = false
                        }
                    }
                }

                LogManager.logInfo("AppleKeychainStore - Deleted \(matchedCount) generic passwords from keychain for namespace: \(namespace)")
                return allSucceeded
            } else if status == errSecItemNotFound {
                LogManager.logInfo("AppleKeychainStore - No generic password items found in keychain for namespace: \(namespace)")
                return true
            } else {
                LogManager.logError("AppleKeychainStore - Failed to query generic password keychain items: \(status)")
                return false
            }
        }

        private func deleteCryptoKeys(withNamespacePrefix namespace: String) throws -> Bool {
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
                        LogManager.logInfo("AppleKeychainStore - Deleting key: \(tagString)")

                        let deleteQuery: [String: Any] = [
                            kSecClass as String: kSecClassKey,
                            kSecAttrApplicationTag as String: tagData,
                        ]

                        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
                        if deleteStatus != errSecSuccess {
                            LogManager.logError("AppleKeychainStore - Failed to delete key \(tagString): \(deleteStatus)")
                            allSucceeded = false
                        }
                    }
                }

                LogManager.logInfo("AppleKeychainStore - Deleted \(matchedCount) keys from keychain for namespace: \(namespace)")
                return allSucceeded
            } else if status == errSecItemNotFound {
                LogManager.logInfo("AppleKeychainStore - No key items found in keychain for namespace: \(namespace)")
                return true
            } else {
                LogManager.logError("AppleKeychainStore - Failed to query key keychain items: \(status)")
                return false
            }
        }

        // MARK: - DPoP Key Methods

        func storeDPoPKey(_ key: P256.Signing.PrivateKey, keyTag: String) throws {
            #if os(iOS)
                try storeDPoPKeyiOS(key, keyTag: keyTag)
            #elseif os(macOS)
                try storeDPoPKeymacOS(key, keyTag: keyTag)
            #endif
        }

        func retrieveDPoPKey(keyTag: String) throws -> P256.Signing.PrivateKey {
            #if os(iOS)
                return try retrieveDPoPKeyiOS(keyTag: keyTag)
            #elseif os(macOS)
                return try retrieveDPoPKeymacOS(keyTag: keyTag)
            #endif
        }

        func deleteDPoPKey(keyTag: String) throws {
            #if os(iOS)
                try deleteDPoPKeyiOS(keyTag: keyTag)
            #elseif os(macOS)
                try deleteDPoPKeymacOS(keyTag: keyTag)
            #endif
        }

        // MARK: - iOS DPoP Key Implementation

        #if os(iOS)
            private func storeDPoPKeyiOS(_ key: P256.Signing.PrivateKey, keyTag: String) throws {
                guard let tagData = keyTag.data(using: .utf8) else {
                    throw KeychainError.dataFormatError
                }

                var query: [String: Any] = [
                    kSecClass as String: kSecClassKey,
                    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                    kSecAttrKeySizeInBits as String: 256,
                    kSecAttrApplicationTag as String: tagData,
                    kSecValueData as String: key.x963Representation,
                    kSecAttrAccessible as String: Self.defaultAccessibility,
                ]

                // Delete any existing key first
                let deleteQuery: [String: Any] = [
                    kSecClass as String: kSecClassKey,
                    kSecAttrApplicationTag as String: tagData,
                ]

                let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
                LogManager.logDebug("AppleKeychainStore - iOS delete status: \(deleteStatus)")

                // Add the new key
                let status = SecItemAdd(query as CFDictionary, nil)
                if status == errSecDuplicateItem {
                    // Try update
                    let updateAttributes: [String: Any] = [
                        kSecValueData as String: key.x963Representation,
                    ]
                    let updateStatus = SecItemUpdate(deleteQuery as CFDictionary, updateAttributes as CFDictionary)
                    guard updateStatus == errSecSuccess else {
                        LogManager.logError("AppleKeychainStore - iOS update failed: \(updateStatus)")
                        throw KeychainError.itemStoreError(status: updateStatus)
                    }
                    LogManager.logDebug("AppleKeychainStore - iOS key updated for tag \(keyTag)")
                } else if status != errSecSuccess {
                    LogManager.logError("AppleKeychainStore - iOS add failed: \(status)")
                    throw KeychainError.itemStoreError(status: Int(status))
                } else {
                    LogManager.logDebug("AppleKeychainStore - iOS key added for tag \(keyTag)")
                }
            }

            private func retrieveDPoPKeyiOS(keyTag: String) throws -> P256.Signing.PrivateKey {
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
                    LogManager.logError("AppleKeychainStore - iOS failed to retrieve DPoP key for tag \(keyTag). Status: \(status)")
                    throw KeychainError.itemRetrievalError(status: Int(status))
                }

                do {
                    let key = try P256.Signing.PrivateKey(x963Representation: data)
                    LogManager.logDebug("AppleKeychainStore - iOS successfully retrieved DPoP key for tag \(keyTag)")
                    return key
                } catch {
                    LogManager.logError("AppleKeychainStore - iOS failed to reconstruct P256 key: \(error)")
                    throw KeychainError.unableToCreateKey
                }
            }

            private func deleteDPoPKeyiOS(keyTag: String) throws {
                guard let tagData = keyTag.data(using: .utf8) else {
                    throw KeychainError.dataFormatError
                }

                let query: [String: Any] = [
                    kSecClass as String: kSecClassKey,
                    kSecAttrApplicationTag as String: tagData,
                ]

                let status = SecItemDelete(query as CFDictionary)
                if status != errSecSuccess, status != errSecItemNotFound {
                    LogManager.logError("AppleKeychainStore - iOS failed to delete DPoP key for tag \(keyTag). Status: \(status)")
                    throw KeychainError.itemStoreError(status: Int(status))
                }

                LogManager.logDebug("AppleKeychainStore - iOS successfully deleted DPoP key for tag \(keyTag)")
            }
        #endif

        // MARK: - macOS DPoP Key Implementation

        #if os(macOS)
            private func storeDPoPKeymacOS(_ key: P256.Signing.PrivateKey, keyTag: String) throws {
                LogManager.logDebug("AppleKeychainStore - Storing DPoP key on macOS using SecKey approach for tag: \(keyTag)")

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
                    LogManager.logError("AppleKeychainStore - Failed to create SecKey from P256 data: \(errorDescription)")

                    // Fallback: store as generic password
                    LogManager.logDebug("AppleKeychainStore - Falling back to generic password storage for tag: \(keyTag)")
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
                    kSecAttrAccessible as String: Self.defaultAccessibility,
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
                        LogManager.logError("AppleKeychainStore - macOS SecKey update failed: \(updateStatus)")
                        // Fallback to password storage
                        try storeDPoPKeyAsPasswordmacOS(key, keyTag: keyTag)
                        return
                    }
                    LogManager.logDebug("AppleKeychainStore - macOS SecKey updated for tag \(keyTag)")
                } else if status != errSecSuccess {
                    LogManager.logError("AppleKeychainStore - macOS SecKey add failed: \(status)")
                    // Fallback to password storage
                    try storeDPoPKeyAsPasswordmacOS(key, keyTag: keyTag)
                    return
                } else {
                    LogManager.logDebug("AppleKeychainStore - macOS SecKey added for tag \(keyTag)")
                }
            }

            private func storeDPoPKeyAsPasswordmacOS(_ key: P256.Signing.PrivateKey, keyTag: String) throws {
                LogManager.logDebug("AppleKeychainStore - Storing DPoP key as password for tag: \(keyTag)")

                let passwordKey = "\(keyTag).password"
                try store(key: passwordKey, value: key.x963Representation, namespace: "dpopkeys")

                LogManager.logDebug("AppleKeychainStore - Successfully stored DPoP key as password for tag: \(keyTag)")
            }

            private func retrieveDPoPKeymacOS(keyTag: String) throws -> P256.Signing.PrivateKey {
                // First try to retrieve as SecKey
                if let key = try? retrieveDPoPKeyAsSecKeymacOS(keyTag: keyTag) {
                    return key
                }

                // Fallback: try to retrieve as password
                LogManager.logDebug("AppleKeychainStore - SecKey retrieval failed, trying password fallback for tag: \(keyTag)")
                return try retrieveDPoPKeyAsPasswordmacOS(keyTag: keyTag)
            }

            private func retrieveDPoPKeyAsSecKeymacOS(keyTag: String) throws -> P256.Signing.PrivateKey {
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
                    LogManager.logDebug("AppleKeychainStore - SecKey not found for tag \(keyTag). Status: \(status)")
                    throw KeychainError.itemRetrievalError(status: Int(status))
                }

                // Convert SecKey back to raw data
                var error: Unmanaged<CFError>?
                guard let keyData = SecKeyCopyExternalRepresentation(secKey as! SecKey, &error) else {
                    let errorDescription = error?.takeRetainedValue().localizedDescription ?? "unknown error"
                    LogManager.logError("AppleKeychainStore - Failed to extract data from SecKey: \(errorDescription)")
                    throw KeychainError.unableToCreateKey
                }

                do {
                    let key = try P256.Signing.PrivateKey(x963Representation: keyData as Data)
                    LogManager.logDebug("AppleKeychainStore - Successfully retrieved DPoP key as SecKey for tag \(keyTag)")
                    return key
                } catch {
                    LogManager.logError("AppleKeychainStore - Failed to reconstruct P256 key from SecKey data: \(error)")
                    throw KeychainError.unableToCreateKey
                }
            }

            private func retrieveDPoPKeyAsPasswordmacOS(keyTag: String) throws -> P256.Signing.PrivateKey {
                let passwordKey = "\(keyTag).password"

                do {
                    let data = try retrieve(key: passwordKey, namespace: "dpopkeys")
                    let key = try P256.Signing.PrivateKey(x963Representation: data)
                    LogManager.logDebug("AppleKeychainStore - Successfully retrieved DPoP key as password for tag \(keyTag)")
                    return key
                } catch {
                    LogManager.logError("AppleKeychainStore - Failed to retrieve DPoP key as password for tag \(keyTag): \(error)")
                    throw KeychainError.itemRetrievalError(status: Int(errSecItemNotFound))
                }
            }

            private func deleteDPoPKeymacOS(keyTag: String) throws {
                guard let tagData = keyTag.data(using: .utf8) else {
                    throw KeychainError.dataFormatError
                }

                // Try to delete SecKey
                let keyQuery: [String: Any] = [
                    kSecClass as String: kSecClassKey,
                    kSecAttrApplicationTag as String: tagData,
                ]
                let keyStatus = SecItemDelete(keyQuery as CFDictionary)
                LogManager.logDebug("AppleKeychainStore - macOS SecKey delete status: \(keyStatus)")

                // Try to delete password fallback
                let passwordKey = "\(keyTag).password"
                try? delete(key: passwordKey, namespace: "dpopkeys")
            }
        #endif
    }

#endif
