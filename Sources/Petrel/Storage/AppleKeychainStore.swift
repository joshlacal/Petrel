//
//  AppleKeychainStore.swift
//  Petrel
//
//  Apple platform keychain storage implementation
//

#if os(iOS) || os(macOS)

    import Foundation
    import Security
    import Synchronization

    extension KeychainAccessibility {
        var cfValue: CFString {
            switch self {
            case .afterFirstUnlockThisDeviceOnly: return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            case .afterFirstUnlock: return kSecAttrAccessibleAfterFirstUnlock
            case .whenUnlockedThisDeviceOnly: return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            }
        }
    }

    /// Secure storage implementation using Apple's Keychain Services
    final class AppleKeychainStore: SecureStorage {
        // MARK: - Platform-specific Configuration

        /// Process-wide accessibility setting, configurable via
        /// `KeychainManager.configureAccessibility(_:)`. Items written before a
        /// change keep their old attribute until the next write (store is
        /// delete+add, so any rewrite applies the current setting).
        private static let accessibilityState = Mutex<KeychainAccessibility>(.afterFirstUnlockThisDeviceOnly)

        static func configureAccessibility(_ accessibility: KeychainAccessibility) {
            accessibilityState.withLock { $0 = accessibility }
        }

        /// Returns the configured keychain accessibility for new writes
        private static var defaultAccessibility: CFString {
            accessibilityState.withLock { $0 }.cfValue
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

        /// Returns access group attributes when provided
        private static func accessGroupAttributes(_ accessGroup: String?) -> [String: Any] {
            guard let accessGroup, !accessGroup.isEmpty else { return [:] }
            return [kSecAttrAccessGroup as String: accessGroup]
        }

        // MARK: - SecureStorage Implementation

        func store(key: String, value: Data, namespace: String, accessGroup: String?) throws {
            let namespacedKey = "\(namespace).\(key)"

            // Search attributes only: kSecAttrAccessible must NOT scope the
            // delete/update, or items written under a previous accessibility
            // setting never match and the add below collides (-25299).
            let searchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: namespacedKey,
            ]
            .merging(Self.platformSpecificAttributes()) { _, new in new }
            .merging(Self.accessGroupAttributes(accessGroup)) { _, new in new }

            var addQuery = searchQuery
            addQuery[kSecValueData as String] = value
            addQuery[kSecAttrAccessible as String] = Self.defaultAccessibility

            // Delete any existing item with the same key
            let deleteStatus = SecItemDelete(searchQuery as CFDictionary)
            if deleteStatus != errSecSuccess, deleteStatus != errSecItemNotFound {
                LogManager.logError(
                    "AppleKeychainStore - Failed to delete existing item for key \(namespacedKey). Status: \(deleteStatus)"
                )
                throw KeychainError.itemStoreError(status: Int(deleteStatus))
            }

            // Add the new item to the keychain
            let status = SecItemAdd(addQuery as CFDictionary, nil)
            if status == errSecDuplicateItem {
                // Cross-process race or an item the delete could not match:
                // update in place, migrating value and accessibility.
                let updateAttributes: [String: Any] = [
                    kSecValueData as String: value,
                    kSecAttrAccessible as String: Self.defaultAccessibility,
                ]
                let updateStatus = SecItemUpdate(
                    searchQuery as CFDictionary, updateAttributes as CFDictionary
                )
                guard updateStatus == errSecSuccess else {
                    LogManager.logError(
                        "AppleKeychainStore - Duplicate item for key \(namespacedKey); update fallback failed. Status: \(updateStatus)"
                    )
                    throw KeychainError.itemStoreError(status: Int(updateStatus))
                }
                LogManager.logDebug(
                    "AppleKeychainStore - Updated existing item for key \(namespacedKey) after duplicate add."
                )
                return
            }
            guard status == errSecSuccess else {
                LogManager.logError(
                    "AppleKeychainStore - Failed to store item for key \(namespacedKey). Status: \(status)"
                )
                throw KeychainError.itemStoreError(status: Int(status))
            }

            LogManager.logDebug("AppleKeychainStore - Successfully stored item for key \(namespacedKey).")
        }

        func retrieve(key: String, namespace: String, accessGroup: String?) throws -> Data {
            let namespacedKey = "\(namespace).\(key)"

            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: namespacedKey,
                kSecReturnData as String: kCFBooleanTrue!,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ].merging(Self.accessGroupAttributes(accessGroup)) { _, new in new }

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)

            if status == errSecItemNotFound {
                // Item not found is expected in many cases (e.g., gateway mode doesn't use regular sessions)
                // Log at debug level to avoid spamming logs
                LogManager.logDebug("AppleKeychainStore - Item not found for key \(namespacedKey).")
                throw KeychainError.itemRetrievalError(status: Int(status))
            }

            guard status == errSecSuccess else {
                LogManager.logError(
                    "AppleKeychainStore - Failed to retrieve item for key \(namespacedKey). Status: \(status)"
                )
                throw KeychainError.itemRetrievalError(status: Int(status))
            }
            guard let data = item as? Data else {
                LogManager.logError("AppleKeychainStore - Data format error for key \(namespacedKey).")
                throw KeychainError.dataFormatError
            }

            LogManager.logDebug(
                "AppleKeychainStore - Successfully retrieved item for key \(namespacedKey)."
            )
            return data
        }

        func delete(key: String, namespace: String, accessGroup: String?) throws {
            let namespacedKey = "\(namespace).\(key)"
            LogManager.logDebug("AppleKeychainStore: Attempting to delete key: \(namespacedKey)")

            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: namespacedKey,
            ].merging(Self.accessGroupAttributes(accessGroup)) { _, new in new }

            let status = SecItemDelete(query as CFDictionary)
            LogManager.logDebug("AppleKeychainStore: Delete status for key \(namespacedKey): \(status)")

            if status != errSecSuccess, status != errSecItemNotFound {
                LogManager.logError(
                    "AppleKeychainStore - Failed to delete item for key \(namespacedKey). Status: \(status)"
                )
                throw KeychainError.itemStoreError(status: Int(status))
            }

            LogManager.logDebug(
                "AppleKeychainStore: Successfully deleted item for key \(namespacedKey). Status: \(status)"
            )
        }

        func deleteAll(namespace: String, accessGroup: String?) throws {
            // Handle generic passwords first
            let genericSuccess = try deleteGenericPasswords(
                withNamespacePrefix: namespace,
                accessGroup: accessGroup
            )

            // Then handle crypto keys
            let keysSuccess = try deleteCryptoKeys(
                withNamespacePrefix: namespace,
                accessGroup: accessGroup
            )

            guard genericSuccess, keysSuccess else {
                throw KeychainError.deletionError(status: -1)
            }
        }

        private func deleteGenericPasswords(
            withNamespacePrefix namespace: String,
            accessGroup: String?
        ) throws -> Bool {
            // Query to get all generic passwords
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecMatchLimit as String: kSecMatchLimitAll,
                kSecReturnAttributes as String: true,
            ].merging(Self.accessGroupAttributes(accessGroup)) { _, new in new }

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
                        ].merging(Self.accessGroupAttributes(accessGroup)) { _, new in new }

                        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
                        if deleteStatus != errSecSuccess {
                            LogManager.logError(
                                "AppleKeychainStore - Failed to delete item \(account): \(deleteStatus)"
                            )
                            allSucceeded = false
                        }
                    }
                }

                LogManager.logInfo(
                    "AppleKeychainStore - Deleted \(matchedCount) generic passwords from keychain for namespace: \(namespace)"
                )
                return allSucceeded
            } else if status == errSecItemNotFound {
                LogManager.logInfo(
                    "AppleKeychainStore - No generic password items found in keychain for namespace: \(namespace)"
                )
                return true
            } else {
                LogManager.logError(
                    "AppleKeychainStore - Failed to query generic password keychain items: \(status)"
                )
                return false
            }
        }

        private func deleteCryptoKeys(
            withNamespacePrefix namespace: String,
            accessGroup: String?
        ) throws -> Bool {
            // Query to get all keys
            let query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecMatchLimit as String: kSecMatchLimitAll,
                kSecReturnAttributes as String: true,
            ].merging(Self.accessGroupAttributes(accessGroup)) { _, new in new }

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
                        ].merging(Self.accessGroupAttributes(accessGroup)) { _, new in new }

                        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
                        if deleteStatus != errSecSuccess {
                            LogManager.logError(
                                "AppleKeychainStore - Failed to delete key \(tagString): \(deleteStatus)"
                            )
                            allSucceeded = false
                        }
                    }
                }

                LogManager.logInfo(
                    "AppleKeychainStore - Deleted \(matchedCount) keys from keychain for namespace: \(namespace)"
                )
                return allSucceeded
            } else if status == errSecItemNotFound {
                LogManager.logInfo(
                    "AppleKeychainStore - No key items found in keychain for namespace: \(namespace)"
                )
                return true
            } else {
                LogManager.logError("AppleKeychainStore - Failed to query key keychain items: \(status)")
                return false
            }
        }

        // MARK: - DPoP Key Methods

        func storeDPoPKeyRepresentation(
            _ representation: Data,
            keyTag: String,
            accessGroup: String?
        ) throws {
            #if os(iOS)
                try storeDPoPKeyRepresentationiOS(
                    representation,
                    keyTag: keyTag,
                    accessGroup: accessGroup
                )
            #elseif os(macOS)
                try storeDPoPKeyRepresentationmacOS(
                    representation,
                    keyTag: keyTag,
                    accessGroup: accessGroup
                )
            #endif
        }

        func retrieveDPoPKeyRepresentation(keyTag: String, accessGroup: String?) throws -> Data {
            #if os(iOS)
                return try retrieveDPoPKeyRepresentationiOS(keyTag: keyTag, accessGroup: accessGroup)
            #elseif os(macOS)
                return try retrieveDPoPKeyRepresentationmacOS(keyTag: keyTag, accessGroup: accessGroup)
            #endif
        }

        func deleteDPoPKey(keyTag: String, accessGroup: String?) throws {
            #if os(iOS)
                try deleteDPoPKeyiOS(keyTag: keyTag, accessGroup: accessGroup)
            #elseif os(macOS)
                try deleteDPoPKeymacOS(keyTag: keyTag, accessGroup: accessGroup)
            #endif
        }

        // MARK: - iOS DPoP Key Implementation

        #if os(iOS)
            private func storeDPoPKeyRepresentationiOS(
                _ representation: Data,
                keyTag: String,
                accessGroup: String?
            ) throws {
                guard let tagData = keyTag.data(using: .utf8) else {
                    throw KeychainError.dataFormatError
                }

                var query: [String: Any] = [
                    kSecClass as String: kSecClassKey,
                    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                    kSecAttrKeySizeInBits as String: 256,
                    kSecAttrApplicationTag as String: tagData,
                    kSecValueData as String: representation,
                    kSecAttrAccessible as String: Self.defaultAccessibility,
                ]
                query.merge(Self.accessGroupAttributes(accessGroup)) { _, new in new }

                // Delete any existing key first
                let deleteQuery: [String: Any] = [
                    kSecClass as String: kSecClassKey,
                    kSecAttrApplicationTag as String: tagData,
                ].merging(Self.accessGroupAttributes(accessGroup)) { _, new in new }

                let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
                LogManager.logDebug("AppleKeychainStore - iOS delete status: \(deleteStatus)")

                // Add the new key
                let status = SecItemAdd(query as CFDictionary, nil)
                if status == errSecDuplicateItem {
                    // Try update
                    let updateAttributes: [String: Any] = [
                        kSecValueData as String: representation,
                    ]
                    let updateStatus = SecItemUpdate(
                        deleteQuery as CFDictionary, updateAttributes as CFDictionary
                    )
                    guard updateStatus == errSecSuccess else {
                        LogManager.logError("AppleKeychainStore - iOS update failed: \(updateStatus)")
                        throw KeychainError.itemStoreError(status: Int(updateStatus))
                    }
                    LogManager.logDebug("AppleKeychainStore - iOS key updated for tag \(keyTag)")
                } else if status != errSecSuccess {
                    LogManager.logError("AppleKeychainStore - iOS add failed: \(status)")
                    throw KeychainError.itemStoreError(status: Int(status))
                } else {
                    LogManager.logDebug("AppleKeychainStore - iOS key added for tag \(keyTag)")
                }
            }

            private func retrieveDPoPKeyRepresentationiOS(
                keyTag: String,
                accessGroup: String?
            ) throws -> Data {
                guard let tagData = keyTag.data(using: .utf8) else {
                    throw KeychainError.dataFormatError
                }

                let query: [String: Any] = [
                    kSecClass as String: kSecClassKey,
                    kSecAttrApplicationTag as String: tagData,
                    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                    kSecReturnData as String: kCFBooleanTrue!,
                    kSecMatchLimit as String: kSecMatchLimitOne,
                ].merging(Self.accessGroupAttributes(accessGroup)) { _, new in new }

                var item: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &item)

                guard status == errSecSuccess, let data = item as? Data else {
                    LogManager.logError(
                        "AppleKeychainStore - iOS failed to retrieve DPoP key for tag \(keyTag). Status: \(status)"
                    )
                    throw KeychainError.itemRetrievalError(status: Int(status))
                }

                LogManager.logDebug(
                    "AppleKeychainStore - iOS successfully retrieved DPoP key representation for tag \(keyTag)"
                )
                return data
            }

            private func deleteDPoPKeyiOS(
                keyTag: String,
                accessGroup: String?
            ) throws {
                guard let tagData = keyTag.data(using: .utf8) else {
                    throw KeychainError.dataFormatError
                }

                let query: [String: Any] = [
                    kSecClass as String: kSecClassKey,
                    kSecAttrApplicationTag as String: tagData,
                ].merging(Self.accessGroupAttributes(accessGroup)) { _, new in new }

                let status = SecItemDelete(query as CFDictionary)
                if status != errSecSuccess, status != errSecItemNotFound {
                    LogManager.logError(
                        "AppleKeychainStore - iOS failed to delete DPoP key for tag \(keyTag). Status: \(status)"
                    )
                    throw KeychainError.itemStoreError(status: Int(status))
                }

                LogManager.logDebug(
                    "AppleKeychainStore - iOS successfully deleted DPoP key for tag \(keyTag)"
                )
            }
        #endif

        // MARK: - macOS DPoP Key Implementation

        #if os(macOS)
            private func storeDPoPKeyRepresentationmacOS(
                _ representation: Data,
                keyTag: String,
                accessGroup: String?
            ) throws {
                LogManager.logDebug(
                    "AppleKeychainStore - Storing DPoP key on macOS using SecKey approach for tag: \(keyTag)"
                )

                // First, try to delete any existing key (multiple approaches)
                try? deleteDPoPKeymacOS(keyTag: keyTag, accessGroup: accessGroup)

                // Convert CryptoKit key to SecKey
                let keyData = representation
                let attributes: [String: Any] = [
                    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                    kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                    kSecAttrKeySizeInBits as String: 256,
                ]

                var error: Unmanaged<CFError>?
                guard
                    let secKey = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, &error)
                else {
                    let errorDescription = error?.takeRetainedValue().localizedDescription ?? "unknown error"
                    LogManager.logError(
                        "AppleKeychainStore - Failed to create SecKey from P256 data: \(errorDescription)"
                    )

                    // Fallback: store as generic password
                    LogManager.logDebug(
                        "AppleKeychainStore - Falling back to generic password storage for tag: \(keyTag)"
                    )
                    try storeDPoPKeyRepresentationAsPasswordmacOS(
                        representation,
                        keyTag: keyTag,
                        accessGroup: accessGroup
                    )
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
                ].merging(Self.accessGroupAttributes(accessGroup)) { _, new in new }

                let status = SecItemAdd(query as CFDictionary, nil)
                if status == errSecDuplicateItem {
                    // Try update
                    let updateQuery: [String: Any] = [
                        kSecClass as String: kSecClassKey,
                        kSecAttrApplicationTag as String: tagData,
                    ].merging(Self.accessGroupAttributes(accessGroup)) { _, new in new }
                    let updateAttributes: [String: Any] = [
                        kSecValueRef as String: secKey,
                    ]
                    let updateStatus = SecItemUpdate(
                        updateQuery as CFDictionary, updateAttributes as CFDictionary
                    )
                    guard updateStatus == errSecSuccess else {
                        LogManager.logError("AppleKeychainStore - macOS SecKey update failed: \(updateStatus)")
                        // Fallback to password storage
                        try storeDPoPKeyRepresentationAsPasswordmacOS(
                            representation,
                            keyTag: keyTag,
                            accessGroup: accessGroup
                        )
                        return
                    }
                    LogManager.logDebug("AppleKeychainStore - macOS SecKey updated for tag \(keyTag)")
                } else if status != errSecSuccess {
                    LogManager.logError("AppleKeychainStore - macOS SecKey add failed: \(status)")
                    // Fallback to password storage
                    try storeDPoPKeyRepresentationAsPasswordmacOS(
                        representation,
                        keyTag: keyTag,
                        accessGroup: accessGroup
                    )
                    return
                } else {
                    LogManager.logDebug("AppleKeychainStore - macOS SecKey added for tag \(keyTag)")
                }
            }

            private func storeDPoPKeyRepresentationAsPasswordmacOS(
                _ representation: Data,
                keyTag: String,
                accessGroup: String?
            ) throws {
                LogManager.logDebug("AppleKeychainStore - Storing DPoP key as password for tag: \(keyTag)")

                let passwordKey = "\(keyTag).password"
                try store(
                    key: passwordKey,
                    value: representation,
                    namespace: "dpopkeys",
                    accessGroup: accessGroup
                )

                LogManager.logDebug(
                    "AppleKeychainStore - Successfully stored DPoP key as password for tag: \(keyTag)"
                )
            }

            private func retrieveDPoPKeyRepresentationmacOS(
                keyTag: String,
                accessGroup: String?
            ) throws -> Data {
                // First try to retrieve as SecKey
                if let representation = try? retrieveDPoPKeyRepresentationAsSecKeymacOS(
                    keyTag: keyTag,
                    accessGroup: accessGroup
                ) {
                    return representation
                }

                // Fallback: try to retrieve as password
                LogManager.logDebug(
                    "AppleKeychainStore - SecKey retrieval failed, trying password fallback for tag: \(keyTag)"
                )
                return try retrieveDPoPKeyRepresentationAsPasswordmacOS(
                    keyTag: keyTag,
                    accessGroup: accessGroup
                )
            }

            private func retrieveDPoPKeyRepresentationAsSecKeymacOS(
                keyTag: String,
                accessGroup: String?
            ) throws -> Data {
                guard let tagData = keyTag.data(using: .utf8) else {
                    throw KeychainError.dataFormatError
                }

                let query: [String: Any] = [
                    kSecClass as String: kSecClassKey,
                    kSecAttrApplicationTag as String: tagData,
                    kSecReturnRef as String: kCFBooleanTrue!,
                    kSecMatchLimit as String: kSecMatchLimitOne,
                ].merging(Self.accessGroupAttributes(accessGroup)) { _, new in new }

                var item: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &item)

                guard status == errSecSuccess, let secKey = item else {
                    LogManager.logDebug(
                        "AppleKeychainStore - SecKey not found for tag \(keyTag). Status: \(status)"
                    )
                    throw KeychainError.itemRetrievalError(status: Int(status))
                }

                // Convert SecKey back to raw data
                var error: Unmanaged<CFError>?
                guard let keyData = SecKeyCopyExternalRepresentation(secKey as! SecKey, &error) else {
                    let errorDescription = error?.takeRetainedValue().localizedDescription ?? "unknown error"
                    LogManager.logError(
                        "AppleKeychainStore - Failed to extract data from SecKey: \(errorDescription)"
                    )
                    throw KeychainError.unableToCreateKey
                }

                LogManager.logDebug(
                    "AppleKeychainStore - Successfully retrieved DPoP key representation as SecKey for tag \(keyTag)"
                )
                return keyData as Data
            }

            private func retrieveDPoPKeyRepresentationAsPasswordmacOS(
                keyTag: String,
                accessGroup: String?
            ) throws -> Data {
                let passwordKey = "\(keyTag).password"

                do {
                    let data = try retrieve(
                        key: passwordKey,
                        namespace: "dpopkeys",
                        accessGroup: accessGroup
                    )
                    LogManager.logDebug(
                        "AppleKeychainStore - Successfully retrieved DPoP key representation as password for tag \(keyTag)"
                    )
                    return data
                } catch {
                    LogManager.logError(
                        "AppleKeychainStore - Failed to retrieve DPoP key as password for tag \(keyTag): \(error)"
                    )
                    throw KeychainError.itemRetrievalError(status: Int(errSecItemNotFound))
                }
            }

            private func deleteDPoPKeymacOS(
                keyTag: String,
                accessGroup: String?
            ) throws {
                guard let tagData = keyTag.data(using: .utf8) else {
                    throw KeychainError.dataFormatError
                }

                // Try to delete SecKey
                let keyQuery: [String: Any] = [
                    kSecClass as String: kSecClassKey,
                    kSecAttrApplicationTag as String: tagData,
                ].merging(Self.accessGroupAttributes(accessGroup)) { _, new in new }
                let keyStatus = SecItemDelete(keyQuery as CFDictionary)
                LogManager.logDebug("AppleKeychainStore - macOS SecKey delete status: \(keyStatus)")

                // Try to delete password fallback
                let passwordKey = "\(keyTag).password"
                try? delete(key: passwordKey, namespace: "dpopkeys", accessGroup: accessGroup)
            }
        #endif
    }

#endif
