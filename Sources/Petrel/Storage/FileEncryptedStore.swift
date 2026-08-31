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

        internal struct Operations: @unchecked Sendable {
            let rename: (String, String) -> Int32
            let unlink: (String) -> Int32

            static let live = Operations(
                rename: {
                    #if canImport(Darwin)
                        return Darwin.rename($0, $1)
                    #elseif canImport(Glibc)
                        return Glibc.rename($0, $1)
                    #endif
                },
                unlink: {
                    #if canImport(Darwin)
                        return Darwin.unlink($0)
                    #elseif canImport(Glibc)
                        return Glibc.unlink($0)
                    #endif
                }
            )
        }

        private let storageDirectory: URL
        private let masterKey: ZeroizingMasterKey
        private let operations: Operations
        private let logSink: (@Sendable (String) -> Void)?
        enum FileEncryptedStoreError: Error, LocalizedError, Equatable {
            case encryptionFailed
            case decryptionFailed
            case invalidConfiguration
            case insecureDirectoryPath
            case insecurePermissions
            case missingMasterKey

            var errorDescription: String? {
                switch self {
                case .encryptionFailed:
                    return "Failed to encrypt data"
                case .decryptionFailed:
                    return "Failed to decrypt data"
                case .invalidConfiguration:
                    return "Invalid storage configuration"
                case .insecureDirectoryPath:
                    return "Storage directory path is insecure (e.g. temporary directory or symlink)"
                case .insecurePermissions:
                    return "Storage directory or file permissions are insecure (must be owner-only 0700/0600)"
                case .missingMasterKey:
                    return "Missing protected master key for file-encrypted storage"
                }
            }
        }

        init(
            storageDirectory: URL? = nil,
            masterKey: SymmetricKey? = nil,
            operations: Operations = .live,
            logSink: (@Sendable (String) -> Void)? = nil
        ) throws {
            self.operations = operations
            self.logSink = logSink
            // Resolve directory
            let directory: URL
            #if os(Linux)
                if let envDir = ProcessInfo.processInfo.environment["PETREL_SECRETS_DIR"], !envDir.isEmpty {
                    directory = URL(fileURLWithPath: envDir)
                } else if let home = ProcessInfo.processInfo.environment["HOME"], !home.isEmpty {
                    directory = URL(fileURLWithPath: home).appendingPathComponent(".petrel-secrets")
                } else {
                    throw FileEncryptedStoreError.invalidConfiguration
                }
            #else
                if let storageDirectory = storageDirectory {
                    directory = storageDirectory
                } else if let envDir = ProcessInfo.processInfo.environment["PETREL_SECRETS_DIR"], !envDir.isEmpty {
                    directory = URL(fileURLWithPath: envDir)
                } else {
                    directory = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".petrel-secrets")
                }
            #endif

            let standardizedPath = directory.standardizedFileURL.path

            // Resolve canonical path and check ancestors for symlinks / temporary paths
            let canonicalPath: String
            if let resolved = realpath(standardizedPath, nil) {
                canonicalPath = String(cString: resolved)
                free(resolved)
            } else {
                // If path does not exist yet, resolve the closest existing ancestor
                var current = standardizedPath
                while !FileManager.default.fileExists(atPath: current) && current != "/" && !current.isEmpty {
                    current = (current as NSString).deletingLastPathComponent
                }
                if let resolved = realpath(current, nil) {
                    let resolvedAncestor = String(cString: resolved)
                    free(resolved)
                    let suffix = String(standardizedPath.dropFirst(current.count))
                    canonicalPath = resolvedAncestor + suffix
                } else {
                    canonicalPath = standardizedPath
                }
            }

            let tempPrefixes = ["/tmp", "/private/tmp", "/var/tmp"]
            for prefix in tempPrefixes {
                if standardizedPath == prefix || standardizedPath.hasPrefix(prefix + "/") ||
                   canonicalPath == prefix || canonicalPath.hasPrefix(prefix + "/") {
                    throw FileEncryptedStoreError.insecureDirectoryPath
                }
            }

            // Check every existing path component along the path for symlinks
            var pathToCheck = ""
            for component in directory.pathComponents {
                if component == "/" {
                    pathToCheck = "/"
                    continue
                }
                pathToCheck = (pathToCheck as NSString).appendingPathComponent(component)
                var componentStat = stat()
                if lstat(pathToCheck, &componentStat) == 0 {
                    if (componentStat.st_mode & S_IFMT) == S_IFLNK {
                        throw FileEncryptedStoreError.insecureDirectoryPath
                    }
                }
            }

            self.storageDirectory = directory

            // Key provisioning: masterKey or PETREL_MASTER_KEY environment variable.
            // No ephemeral key generation or secret logging allowed.
            if let key = masterKey {
                self.masterKey = try ZeroizingMasterKey(copying: key)
            } else if let keyB64 = ProcessInfo.processInfo.environment["PETREL_MASTER_KEY"], !keyB64.isEmpty {
                guard let keyData = Data(base64Encoded: keyB64) else {
                    throw FileEncryptedStoreError.invalidConfiguration
                }
                self.masterKey = try ZeroizingMasterKey(copying: SymmetricKey(data: keyData))
            } else {
                throw FileEncryptedStoreError.missingMasterKey
            }

            // Verify existing directory or create owner-only directory (0700)
            var pathStat = stat()
            if lstat(standardizedPath, &pathStat) == 0 {
                if (pathStat.st_mode & S_IFMT) == S_IFLNK {
                    throw FileEncryptedStoreError.insecureDirectoryPath
                }
                if (pathStat.st_mode & S_IFMT) != S_IFDIR {
                    throw FileEncryptedStoreError.insecureDirectoryPath
                }
                if pathStat.st_uid != getuid() {
                    throw FileEncryptedStoreError.insecurePermissions
                }
                if (pathStat.st_mode & 0o077) != 0 {
                    _ = chmod(standardizedPath, 0o700)
                    var updatedStat = stat()
                    if stat(standardizedPath, &updatedStat) != 0 || (updatedStat.st_mode & 0o077) != 0 {
                        throw FileEncryptedStoreError.insecurePermissions
                    }
                }
            } else {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
                _ = chmod(standardizedPath, 0o700)
                var newStat = stat()
                if lstat(standardizedPath, &newStat) != 0 || (newStat.st_mode & S_IFMT) == S_IFLNK || newStat.st_uid != getuid() || (newStat.st_mode & 0o077) != 0 {
                    throw FileEncryptedStoreError.insecurePermissions
                }
            }

            let infoMsg = "FileEncryptedStore: Using storage directory: \(directory.path)"
            logSink?(infoMsg)
            LogManager.logInfo(infoMsg)
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
            let targetURL = fileURL(for: key, namespace: namespace)
            let tempURL = storageDirectory.appendingPathComponent(".tmp.\(UUID().uuidString)")

            // Write temporary file with owner-only 0600 permissions
            try combined.write(to: tempURL, options: .atomic)
            _ = chmod(tempURL.path, 0o600)

            if operations.rename(tempURL.path, targetURL.path) != 0 {
                _ = operations.unlink(tempURL.path)
                throw FileEncryptedStoreError.encryptionFailed
            }

            _ = chmod(targetURL.path, 0o600)
            var fileStat = stat()
            if lstat(targetURL.path, &fileStat) != 0 || (fileStat.st_mode & S_IFMT) == S_IFLNK || fileStat.st_uid != getuid() || (fileStat.st_mode & 0o077) != 0 {
                _ = operations.unlink(targetURL.path)
                throw FileEncryptedStoreError.insecurePermissions
            }

            logSink?("FileEncryptedStore: Stored key \(namespace).\(key)")
            LogManager.logDebug("FileEncryptedStore: Stored key \(namespace).\(key)")
        }

        func retrieve(key: String, namespace: String, accessGroup: String?) throws -> Data {
            let url = fileURL(for: key, namespace: namespace)
            var fileStat = stat()
            guard lstat(url.path, &fileStat) == 0 else {
                throw KeychainError.itemRetrievalError(status: Int(errSecItemNotFound))
            }
            guard (fileStat.st_mode & S_IFMT) != S_IFLNK,
                  fileStat.st_uid == getuid(),
                  (fileStat.st_mode & 0o077) == 0 else {
                throw FileEncryptedStoreError.insecurePermissions
            }
            let combined = try Data(contentsOf: url)
            let box = try AES.GCM.SealedBox(combined: combined)
            let decrypted = try masterKey.open(box)
            logSink?("FileEncryptedStore: Retrieved key \(namespace).\(key)")
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
            logSink?("FileEncryptedStore: Deleted key \(namespace).\(key)")
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
