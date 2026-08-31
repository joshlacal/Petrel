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
        internal struct Operations: @unchecked Sendable {
            let copyMatching: (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
            let update: (CFDictionary, CFDictionary) -> OSStatus
            let add: (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
            let delete: (CFDictionary) -> OSStatus
            let isLive: Bool

            init(
                copyMatching: @escaping (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus,
                update: @escaping (CFDictionary, CFDictionary) -> OSStatus,
                add: @escaping (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus,
                delete: @escaping (CFDictionary) -> OSStatus,
                isLive: Bool = false
            ) {
                self.copyMatching = copyMatching
                self.update = update
                self.add = add
                self.delete = delete
                self.isLive = isLive
            }

            static let live = Operations(
                copyMatching: { SecItemCopyMatching($0, $1) },
                update: { SecItemUpdate($0, $1) },
                add: { SecItemAdd($0, $1) },
                delete: { SecItemDelete($0) },
                isLive: true
            )
        }

        private let operations: Operations
        private let defaultAccessGroup: String?
        private let resolvedDefaultAccessGroupCache = Mutex<String?>(nil)

        init(operations: Operations = .live, defaultAccessGroup: String? = nil) {
            self.operations = operations
            self.defaultAccessGroup = defaultAccessGroup
        }

        /// Resolves the default team-prefixed access group for the current process via entitlement or probe
        private func resolveDefaultAccessGroup() -> String? {
            if let cached = resolvedDefaultAccessGroupCache.withLock({ $0 }), !cached.isEmpty {
                return cached
            }

            #if os(macOS) || targetEnvironment(macCatalyst)
                if operations.isLive,
                   let task = SecTaskCreateFromSelf(nil),
                   let value = SecTaskCopyValueForEntitlement(task, "keychain-access-groups" as CFString, nil),
                   let groups = value as? [String],
                   let first = groups.first, !first.isEmpty {
                    resolvedDefaultAccessGroupCache.withLock { $0 = first }
                    return first
                }
            #endif

            // Live-keychain default access group probe:
            // This probe emits queries without `kSecAttrAccessGroup` intentionally so Keychain Services
            // assigns the system-determined default access group for the calling application.
            // The probe item uses a unique UUID-based account name, requests attribute-only return
            // (kSecReturnAttributes: true, no secret payload), and is immediately deleted.
            let probeAccount = "petrel.defaultGroupProbe.\(UUID().uuidString)"
            let probeData = Data([0])
            var addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: probeAccount,
                kSecValueData as String: probeData,
                kSecAttrAccessible as String: KeychainAccessibility.afterFirstUnlockThisDeviceOnly.cfValue,
            ]
            #if os(macOS)
                addQuery[kSecUseDataProtectionKeychain as String] = true
            #endif
            let status = operations.add(addQuery as CFDictionary, nil)
            guard status == errSecSuccess || status == errSecDuplicateItem else {
                return nil
            }

            var matchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: probeAccount,
                kSecReturnAttributes as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            #if os(macOS)
                matchQuery[kSecUseDataProtectionKeychain as String] = true
            #endif
            var item: CFTypeRef?
            let matchStatus = operations.copyMatching(matchQuery as CFDictionary, &item)

            var deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: probeAccount,
            ]
            #if os(macOS)
                deleteQuery[kSecUseDataProtectionKeychain as String] = true
            #endif
            let deleteStatus = operations.delete(deleteQuery as CFDictionary)
            if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
                LogManager.logWarning("AppleKeychainStore - Failed to delete probe item \(probeAccount): \(deleteStatus)")
            }

            if matchStatus == errSecSuccess,
               let attrs = item as? [String: Any],
               let group = attrs[kSecAttrAccessGroup as String] as? String,
               !group.isEmpty {
                resolvedDefaultAccessGroupCache.withLock { $0 = group }
                return group
            }
            return nil
        }

        // MARK: - Platform-specific Configuration

        /// Process-wide accessibility setting, configurable via
        /// `KeychainManager.configureAccessibility(_:)`. Items written before a
        /// change keep their old attribute until the next write.
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

        /// Returns access group attributes (explicit group or resolved default group).
        /// Fails closed with KeychainError.storageUnavailable if no access group can be resolved.
        private func accessGroupAttributes(_ accessGroup: String?) throws -> [String: Any] {
            if let accessGroup, !accessGroup.isEmpty {
                return [kSecAttrAccessGroup as String: accessGroup]
            }
            if let defaultGroup = defaultAccessGroup, !defaultGroup.isEmpty {
                return [kSecAttrAccessGroup as String: defaultGroup]
            }
            if let resolved = resolveDefaultAccessGroup(), !resolved.isEmpty {
                return [kSecAttrAccessGroup as String: resolved]
            }
            throw KeychainError.storageUnavailable("Could not resolve default keychain access group")
        }

        // MARK: - SecureStorage Implementation

        func store(key: String, value: Data, namespace: String, accessGroup: String?) throws {
            let namespacedKey = "\(namespace).\(key)"

            // Search attributes only: kSecAttrAccessible must NOT scope the
            // update, or items written under a previous accessibility setting
            // never match.
            let searchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: namespacedKey,
            ]
            .merging(Self.platformSpecificAttributes()) { _, new in new }
            .merging(try accessGroupAttributes(accessGroup)) { _, new in new }

            let updateAttributes: [String: Any] = [
                kSecValueData as String: value,
                kSecAttrAccessible as String: Self.defaultAccessibility,
            ]

            let updateStatus = operations.update(
                searchQuery as CFDictionary, updateAttributes as CFDictionary
            )
            if updateStatus == errSecSuccess {
                LogManager.logDebug("AppleKeychainStore - Successfully updated item for key \(namespacedKey).")
                return
            }
            guard updateStatus == errSecItemNotFound else {
                LogManager.logError(
                    "AppleKeychainStore - Failed to update item for key \(namespacedKey). Status: \(updateStatus)"
                )
                throw KeychainError.itemStoreError(status: Int(updateStatus))
            }

            var addQuery = searchQuery
            addQuery[kSecValueData as String] = value
            addQuery[kSecAttrAccessible as String] = Self.defaultAccessibility
            let addStatus = operations.add(addQuery as CFDictionary, nil)
            if addStatus == errSecSuccess {
                LogManager.logDebug("AppleKeychainStore - Successfully stored item for key \(namespacedKey).")
                return
            }
            guard addStatus == errSecDuplicateItem else {
                LogManager.logError(
                    "AppleKeychainStore - Failed to store item for key \(namespacedKey). Status: \(addStatus)"
                )
                throw KeychainError.itemStoreError(status: Int(addStatus))
            }

            let retryStatus = operations.update(
                searchQuery as CFDictionary, updateAttributes as CFDictionary
            )
            guard retryStatus == errSecSuccess else {
                LogManager.logError(
                    "AppleKeychainStore - Duplicate item for key \(namespacedKey); update fallback failed. Status: \(retryStatus)"
                )
                throw KeychainError.itemStoreError(status: Int(retryStatus))
            }
            LogManager.logDebug(
                "AppleKeychainStore - Updated existing item for key \(namespacedKey) after duplicate add."
            )
        }

        func retrieve(key: String, namespace: String, accessGroup: String?) throws -> Data {
            let namespacedKey = "\(namespace).\(key)"

            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: namespacedKey,
                kSecReturnData as String: kCFBooleanTrue!,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ].merging(try accessGroupAttributes(accessGroup)) { _, new in new }

            var item: CFTypeRef?
            let status = operations.copyMatching(query as CFDictionary, &item)

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
            ].merging(try accessGroupAttributes(accessGroup)) { _, new in new }

            let status = operations.delete(query as CFDictionary)
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
            ].merging(try accessGroupAttributes(accessGroup)) { _, new in new }

            var result: AnyObject?
            let status = operations.copyMatching(query as CFDictionary, &result)

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
                        ].merging(try accessGroupAttributes(accessGroup)) { _, new in new }

                        let deleteStatus = operations.delete(deleteQuery as CFDictionary)
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
            ].merging(try accessGroupAttributes(accessGroup)) { _, new in new }

            var result: AnyObject?
            let status = operations.copyMatching(query as CFDictionary, &result)

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
                        ].merging(try accessGroupAttributes(accessGroup)) { _, new in new }

                        let deleteStatus = operations.delete(deleteQuery as CFDictionary)
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
                query.merge(try accessGroupAttributes(accessGroup)) { _, new in new }

                // Delete any existing key first
                let deleteQuery: [String: Any] = [
                    kSecClass as String: kSecClassKey,
                    kSecAttrApplicationTag as String: tagData,
                ].merging(try accessGroupAttributes(accessGroup)) { _, new in new }

                let deleteStatus = operations.delete(deleteQuery as CFDictionary)
                LogManager.logDebug("AppleKeychainStore - iOS delete status: \(deleteStatus)")

                // Add the new key
                let status = operations.add(query as CFDictionary, nil)
                if status == errSecDuplicateItem {
                    // Try update
                    let updateAttributes: [String: Any] = [
                        kSecValueData as String: representation,
                    ]
                    let updateStatus = operations.update(
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
                ].merging(try accessGroupAttributes(accessGroup)) { _, new in new }

                var item: CFTypeRef?
                let status = operations.copyMatching(query as CFDictionary, &item)

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
                ].merging(try accessGroupAttributes(accessGroup)) { _, new in new }

                let status = operations.delete(query as CFDictionary)
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
                ].merging(try accessGroupAttributes(accessGroup)) { _, new in new }

                let status = operations.add(query as CFDictionary, nil)
                if status == errSecDuplicateItem {
                    // Try update
                    let updateQuery: [String: Any] = [
                        kSecClass as String: kSecClassKey,
                        kSecAttrApplicationTag as String: tagData,
                    ].merging(try accessGroupAttributes(accessGroup)) { _, new in new }
                    let updateAttributes: [String: Any] = [
                        kSecValueRef as String: secKey,
                    ]
                    let updateStatus = operations.update(
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
                ].merging(try accessGroupAttributes(accessGroup)) { _, new in new }

                var item: CFTypeRef?
                let status = operations.copyMatching(query as CFDictionary, &item)

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

                // Both representations are live key material — retrieval reads either — so
                // attempt both deletions independently and only then report the first
                // failure; a SecKey failure must not strand the password fallback.
                var firstFailure: (any Error)?

                let keyQuery: [String: Any] = [
                    kSecClass as String: kSecClassKey,
                    kSecAttrApplicationTag as String: tagData,
                ].merging(try accessGroupAttributes(accessGroup)) { _, new in new }
                let keyStatus = operations.delete(keyQuery as CFDictionary)
                LogManager.logDebug("AppleKeychainStore - macOS SecKey delete status: \(keyStatus)")
                if keyStatus != errSecSuccess, keyStatus != errSecItemNotFound {
                    LogManager.logError(
                        "AppleKeychainStore - Failed to delete macOS SecKey for tag \(keyTag). Status: \(keyStatus)"
                    )
                    firstFailure = KeychainError.deletionError(status: Int(keyStatus))
                }

                // Delete password fallback (tolerates a missing item)
                let passwordKey = "\(keyTag).password"
                do {
                    try delete(key: passwordKey, namespace: "dpopkeys", accessGroup: accessGroup)
                } catch {
                    LogManager.logError(
                        "AppleKeychainStore - Failed to delete password fallback for tag \(keyTag): \(error)"
                    )
                    if firstFailure == nil {
                        firstFailure = error
                    }
                }

                if let firstFailure {
                    throw firstFailure
                }
            }
        #endif
    }

#endif
