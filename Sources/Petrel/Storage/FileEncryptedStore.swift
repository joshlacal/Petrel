//
//  FileEncryptedStore.swift
//  Petrel
//
//  File-based encrypted storage for Linux servers and fallback
//

#if os(Linux) || os(macOS) || os(iOS)

    import Crypto
    import Foundation
    #if canImport(Darwin)
        import Darwin
    #elseif canImport(Glibc)
        import Glibc
    #endif

    /// Secure storage implementation using AES-GCM encrypted files
    /// Suitable for server environments and as a fallback when system keyring is unavailable
    final class FileEncryptedStore: SecureStorage {
        /// Immutable key bytes kept outside general-purpose collection storage.
        /// The allocation is explicitly cleared before release. Keeping only its
        /// integer address and length as stored state also avoids transferring a
        /// non-Sendable CryptoKit value across the `SecureStorage` boundary.
        private final class ZeroizingMasterKey: Sendable {
            private let address: UInt
            private let count: Int

            init(copying key: SymmetricKey) throws {
                let copy = try key.withUnsafeBytes { bytes -> (address: UInt, count: Int) in
                    guard let source = bytes.baseAddress, !bytes.isEmpty else {
                        throw FileEncryptedStoreError.invalidConfiguration
                    }
                    let allocation = UnsafeMutableRawPointer.allocate(
                        byteCount: bytes.count,
                        alignment: MemoryLayout<UInt8>.alignment
                    )
                    allocation.copyMemory(from: source, byteCount: bytes.count)
                    return (UInt(bitPattern: allocation), bytes.count)
                }
                address = copy.address
                count = copy.count
            }

            deinit {
                guard let allocation = UnsafeMutableRawPointer(bitPattern: address) else { return }
                #if canImport(Darwin)
                    _ = memset_s(allocation, count, 0, count)
                #elseif canImport(Glibc)
                    explicit_bzero(allocation, count)
                #else
                    allocation.initializeMemory(as: UInt8.self, repeating: 0, count: count)
                #endif
                allocation.deallocate()
            }

            func seal(_ plaintext: Data) throws -> AES.GCM.SealedBox {
                let key = SymmetricKey(data: bytes)
                return try AES.GCM.seal(plaintext, using: key)
            }

            func open(_ box: AES.GCM.SealedBox) throws -> Data {
                let key = SymmetricKey(data: bytes)
                return try AES.GCM.open(box, using: key)
            }

            private var bytes: UnsafeRawBufferPointer {
                UnsafeRawBufferPointer(
                    start: UnsafeRawPointer(bitPattern: address),
                    count: count
                )
            }
        }

        private let storageDirectory: URL
        private let masterKey: ZeroizingMasterKey

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
                    URL(
                        fileURLWithPath: ProcessInfo.processInfo.environment["PETREL_SECRETS_DIR"] ??
                            NSHomeDirectory() + "/.petrel-secrets"
                    )
            #endif

            self.storageDirectory = directory

            // Get or create master key from environment or generate
            if let key = masterKey {
                self.masterKey = try ZeroizingMasterKey(copying: key)
            } else if let keyB64 = ProcessInfo.processInfo.environment["PETREL_MASTER_KEY"] {
                guard let keyData = Data(base64Encoded: keyB64) else {
                    throw FileEncryptedStoreError.invalidConfiguration
                }
                self.masterKey = try ZeroizingMasterKey(copying: SymmetricKey(data: keyData))
            } else {
                // Generate and warn
                let generatedKey = SymmetricKey(size: .bits256)
                let keyB64 = generatedKey.withUnsafeBytes { Data($0).base64EncodedString() }
                self.masterKey = try ZeroizingMasterKey(copying: generatedKey)
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

        func store(key: String, value: Data, namespace: String, accessGroup: String?) throws {
            let sealed = try masterKey.seal(value)
            guard let combined = sealed.combined else {
                throw FileEncryptedStoreError.encryptionFailed
            }
            try combined.write(to: fileURL(for: key, namespace: namespace))
            LogManager.logDebug("FileEncryptedStore: Stored key \(namespace).\(key)")
        }

        func retrieve(key: String, namespace: String, accessGroup: String?) throws -> Data {
            let url = fileURL(for: key, namespace: namespace)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw KeychainError.itemRetrievalError(status: Int(errSecItemNotFound))
            }
            let combined = try Data(contentsOf: url)
            let box = try AES.GCM.SealedBox(combined: combined)
            let decrypted = try masterKey.open(box)
            LogManager.logDebug("FileEncryptedStore: Retrieved key \(namespace).\(key)")
            return decrypted
        }

        /// A secret that is already absent satisfies a delete; anything else — a
        /// permission failure, a read-only volume — leaves the secret on disk and must
        /// reach the caller rather than be reported as a successful wipe.
        private func isFileNotFound(_ error: any Error) -> Bool {
            if let cocoaError = error as? CocoaError {
                return cocoaError.code == .fileNoSuchFile
            }
            let nsError = error as NSError
            return nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError
        }

        func delete(key: String, namespace: String, accessGroup: String?) throws {
            let url = fileURL(for: key, namespace: namespace)
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                guard isFileNotFound(error) else {
                    LogManager.logError(
                        "FileEncryptedStore: Failed to delete key \(namespace).\(key): \(error)"
                    )
                    throw error
                }
                LogManager.logDebug("FileEncryptedStore: No stored value for key \(namespace).\(key)")
                return
            }
            LogManager.logDebug("FileEncryptedStore: Deleted key \(namespace).\(key)")
        }

        func deleteAll(namespace: String, accessGroup: String?) throws {
            let files = try FileManager.default.contentsOfDirectory(
                at: storageDirectory,
                includingPropertiesForKeys: nil
            )
            var deletedCount = 0
            var failures: [any Error] = []
            for file in files {
                // Decode filename to check namespace
                let filename = file.lastPathComponent
                    .replacingOccurrences(of: "_", with: "/")
                    .replacingOccurrences(of: "-", with: "+")
                if let decoded = Data(base64Encoded: filename + "=="), // Add padding back
                   let namespacedKey = String(data: decoded, encoding: .utf8),
                   namespacedKey.hasPrefix("\(namespace).")
                {
                    do {
                        try FileManager.default.removeItem(at: file)
                        deletedCount += 1
                    } catch {
                        // Keep going so one unremovable file cannot strand the rest of the
                        // namespace, then fail once every remaining secret has been attempted.
                        guard isFileNotFound(error) else {
                            failures.append(error)
                            continue
                        }
                    }
                }
            }
            if let firstFailure = failures.first {
                LogManager.logError("""
                FileEncryptedStore: Deleted \(deletedCount) items for namespace \(namespace) but \
                \(failures.count) could not be removed. First failure: \(firstFailure)
                """)
                throw firstFailure
            }
            LogManager.logInfo("FileEncryptedStore: Deleted \(deletedCount) items for namespace: \(namespace)")
        }

        func storeDPoPKeyRepresentation(
            _ representation: Data,
            keyTag: String,
            accessGroup: String?
        ) throws {
            try store(key: keyTag, value: representation, namespace: "dpopkeys", accessGroup: accessGroup)
        }

        func retrieveDPoPKeyRepresentation(keyTag: String, accessGroup: String?) throws -> Data {
            try retrieve(key: keyTag, namespace: "dpopkeys", accessGroup: accessGroup)
        }

        func deleteDPoPKey(keyTag: String, accessGroup: String?) throws {
            try delete(key: keyTag, namespace: "dpopkeys", accessGroup: accessGroup)
        }
    }

#endif
