//
//  FileEncryptedStore.swift
//  Petrel
//
//  File-based encrypted storage for Linux servers and fallback
//

#if os(Linux) || os(macOS) || os(iOS)

    #if canImport(CryptoKit)
    import CryptoKit
    #else
    @preconcurrency import Crypto
    #endif
    import Foundation

    /// Secure storage implementation using AES-GCM encrypted files
    /// Suitable for server environments and as a fallback when system keyring is unavailable
    final class FileEncryptedStore: SecureStorage {
        private let storageDirectory: URL
        private let masterKey: SymmetricKey

        enum FileEncryptedStoreError: Error, LocalizedError {
            case encryptionFailed
            case decryptionFailed
            case invalidConfiguration

            var errorDescription: String? {
                switch self {
                case .encryptionFailed:
                    return "Failed to encrypt data"
                case .decryptionFailed:
                    return "Failed to decrypt data"
                case .invalidConfiguration:
                    return "Invalid storage configuration"
                }
            }
        }

        init(storageDirectory: URL? = nil, masterKey: SymmetricKey? = nil) throws {
            // Default to ~/.petrel-secrets or environment variable
            let directory: URL
            #if os(Linux)
                if let envDir = ProcessInfo.processInfo.environment["PETREL_SECRETS_DIR"] {
                    directory = URL(fileURLWithPath: envDir)
                } else if let home = ProcessInfo.processInfo.environment["HOME"] {
                    directory = URL(fileURLWithPath: home).appendingPathComponent(".petrel-secrets")
                } else {
                    directory = URL(fileURLWithPath: "/tmp/.petrel-secrets")
                }
            #else
                directory = storageDirectory ??
                    URL(fileURLWithPath: ProcessInfo.processInfo.environment["PETREL_SECRETS_DIR"] ??
                        NSHomeDirectory() + "/.petrel-secrets")
            #endif

            self.storageDirectory = directory

            // Get or create master key from environment or generate
            if let key = masterKey {
                self.masterKey = key
            } else if let keyB64 = ProcessInfo.processInfo.environment["PETREL_MASTER_KEY"] {
                guard let keyData = Data(base64Encoded: keyB64) else {
                    throw FileEncryptedStoreError.invalidConfiguration
                }
                self.masterKey = SymmetricKey(data: keyData)
            } else {
                // Generate and warn
                self.masterKey = SymmetricKey(size: .bits256)
                let keyB64 = self.masterKey.withUnsafeBytes { Data($0).base64EncodedString() }
                LogManager.logWarning("""
                FileEncryptedStore: Generated ephemeral master key. Secrets will be lost on restart.
                Set PETREL_MASTER_KEY environment variable to persist secrets across restarts.
                Base64 key: \(keyB64)
                """)
            }

            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            LogManager.logInfo("FileEncryptedStore: Using storage directory: \(directory.path)")
        }

        private func fileURL(for key: String, namespace: String) -> URL {
            let namespacedKey = "\(namespace).\(key)"
            let filename = namespacedKey.data(using: .utf8)!.base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "=", with: "")
            return storageDirectory.appendingPathComponent(filename)
        }

        func store(key: String, value: Data, namespace: String) throws {
            let sealed = try AES.GCM.seal(value, using: masterKey)
            guard let combined = sealed.combined else {
                throw FileEncryptedStoreError.encryptionFailed
            }
            try combined.write(to: fileURL(for: key, namespace: namespace))
            LogManager.logDebug("FileEncryptedStore: Stored key \(namespace).\(key)")
        }

        func retrieve(key: String, namespace: String) throws -> Data {
            let url = fileURL(for: key, namespace: namespace)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw KeychainError.itemRetrievalError(status: Int(errSecItemNotFound))
            }
            let combined = try Data(contentsOf: url)
            let box = try AES.GCM.SealedBox(combined: combined)
            let decrypted = try AES.GCM.open(box, using: masterKey)
            LogManager.logDebug("FileEncryptedStore: Retrieved key \(namespace).\(key)")
            return decrypted
        }

        func delete(key: String, namespace: String) throws {
            let url = fileURL(for: key, namespace: namespace)
            try? FileManager.default.removeItem(at: url)
            LogManager.logDebug("FileEncryptedStore: Deleted key \(namespace).\(key)")
        }

        func deleteAll(namespace: String) throws {
            let files = try FileManager.default.contentsOfDirectory(
                at: storageDirectory,
                includingPropertiesForKeys: nil
            )
            var deletedCount = 0
            for file in files {
                // Decode filename to check namespace
                let filename = file.lastPathComponent
                    .replacingOccurrences(of: "_", with: "/")
                    .replacingOccurrences(of: "-", with: "+")
                if let decoded = Data(base64Encoded: filename + "=="), // Add padding back
                   let namespacedKey = String(data: decoded, encoding: .utf8),
                   namespacedKey.hasPrefix("\(namespace).")
                {
                    try? FileManager.default.removeItem(at: file)
                    deletedCount += 1
                }
            }
            LogManager.logInfo("FileEncryptedStore: Deleted \(deletedCount) items for namespace: \(namespace)")
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
