//
//  LibSecretStore.swift
//  Petrel
//
//  Linux desktop keyring storage using libsecret
//

#if os(Linux)

    import CLibSecretShim
    #if canImport(CryptoKit)
        import CryptoKit
    #else
        @preconcurrency import Crypto
    #endif
    import Foundation

    /// Secure storage implementation using libsecret (GNOME Keyring / KDE Wallet)
    /// Provides desktop-class keyring integration on Linux
    final class LibSecretStore: SecureStorage {
        private let schemaName = "org.petrel.credentials"

        /// Check if libsecret/Secret Service is available
        static func isAvailable() -> Bool {
            return secret_service_available()
        }

        func store(key: String, value: Data, namespace: String) throws {
            let namespacedKey = "\(namespace).\(key)"
            var errorMsg: UnsafeMutablePointer<CChar>?

            let success = value.withUnsafeBytes { buffer in
                secret_store_password_simple(
                    schemaName,
                    "key",
                    namespacedKey,
                    namespacedKey, // Use as label too
                    buffer.baseAddress?.assumingMemoryBound(to: CChar.self),
                    buffer.count,
                    &errorMsg
                )
            }

            if let error = errorMsg {
                let message = String(cString: error)
                free(error)
                LogManager.logError("LibSecretStore - Failed to store: \(message)")
                throw KeychainError.itemStoreError(status: -1)
            }

            guard success else {
                LogManager.logError("LibSecretStore - Failed to store key \(namespacedKey)")
                throw KeychainError.itemStoreError(status: -1)
            }

            LogManager.logDebug("LibSecretStore - Successfully stored key \(namespacedKey)")
        }

        func retrieve(key: String, namespace: String) throws -> Data {
            let namespacedKey = "\(namespace).\(key)"
            var length = 0
            var errorMsg: UnsafeMutablePointer<CChar>?

            guard let result = secret_lookup_password_simple(
                schemaName,
                "key",
                namespacedKey,
                &length,
                &errorMsg
            ) else {
                if let error = errorMsg {
                    let message = String(cString: error)
                    free(error)
                    LogManager.logError("LibSecretStore - Failed to retrieve: \(message)")
                    throw KeychainError.itemRetrievalError(status: -1)
                }
                LogManager.logDebug("LibSecretStore - Item not found: \(namespacedKey)")
                throw KeychainError.itemRetrievalError(status: Int(errSecItemNotFound))
            }

            defer { free(result) }
            let data = Data(bytes: result, count: length)
            LogManager.logDebug("LibSecretStore - Successfully retrieved key \(namespacedKey)")
            return data
        }

        func delete(key: String, namespace: String) throws {
            let namespacedKey = "\(namespace).\(key)"
            var errorMsg: UnsafeMutablePointer<CChar>?

            let success = secret_clear_password_simple(
                schemaName,
                "key",
                namespacedKey,
                &errorMsg
            )

            if let error = errorMsg {
                let message = String(cString: error)
                free(error)
                // Don't throw if item not found
                if !message.contains("not found") {
                    LogManager.logError("LibSecretStore - Failed to delete: \(message)")
                    throw KeychainError.deletionError(status: -1)
                }
            }

            LogManager.logDebug("LibSecretStore - Deleted key \(namespacedKey)")
        }

        func deleteAll(namespace: String) throws {
            // LibSecret doesn't have a bulk delete API
            // This would require enumerating all items, which is complex
            // For now, individual deletes are sufficient
            LogManager.logDebug("LibSecretStore - deleteAll not fully implemented for namespace: \(namespace)")
        }

        func storeDPoPKey(_ key: P256.Signing.PrivateKey, keyTag: String) throws {
            try store(key: keyTag, value: key.x963Representation, namespace: "dpopkeys")
        }

        func retrieveDPoPKey(keyTag: String) throws -> P256.Signing.PrivateKey {
            let data = try retrieve(key: keyTag, namespace: "dpopkeys")
            return try P256.Signing.PrivateKey(x963Representation: data)
        }

        func deleteDPoPKey(keyTag: String) throws {
            try delete(key: keyTag, namespace: "dpopkeys")
        }
    }

#endif
