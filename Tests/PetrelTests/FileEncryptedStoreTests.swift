#if os(Linux) || os(macOS) || os(iOS)
    #if canImport(CryptoKit)
        import CryptoKit
    #else
        import Crypto
    #endif
    import Foundation
    import Synchronization
    @testable import Petrel
    import Testing

    @Suite("File-encrypted secure storage")
    struct FileEncryptedStoreTests {
        private static func createSafeTestDirectory(prefix: String) -> URL {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".petrel-test-storage")
            let dir = base.appendingPathComponent("\(prefix)-\(UUID().uuidString)")
            return dir
        }

        private func withStore<T>(
            _ body: (FileEncryptedStore, URL, String) throws -> T
        ) throws -> T {
            let requestedDirectory = Self.createSafeTestDirectory(prefix: "petrel-file-store-tests")
            let namespace = "petrel-file-store-test-\(UUID().uuidString)"
            let store = try FileEncryptedStore(
                storageDirectory: requestedDirectory,
                masterKey: SymmetricKey(size: .bits256)
            )
            let directory = effectiveDirectory(requestedDirectory)
            defer {
                for key in ["token", "missing"] {
                    try? FileManager.default.removeItem(
                        at: storedFileURL(in: directory, key: key, namespace: namespace)
                    )
                }
                try? FileManager.default.removeItem(at: requestedDirectory)
            }
            return try body(store, directory, namespace)
        }
        private func effectiveDirectory(_ requestedDirectory: URL) -> URL {
            #if os(Linux)
                // Linux currently resolves the configured/default secrets directory even
                // when tests supply storageDirectory. Mirror that selection without
                // mutating process-wide environment shared by concurrently running tests.
                if let configured = ProcessInfo.processInfo.environment["PETREL_SECRETS_DIR"] {
                    return URL(fileURLWithPath: configured)
                }
                if let home = ProcessInfo.processInfo.environment["HOME"] {
                    return URL(fileURLWithPath: home).appendingPathComponent(".petrel-secrets")
                }
                return URL(fileURLWithPath: "/tmp/.petrel-secrets")
            #else
                return requestedDirectory
            #endif
        }

        private func storedFileURL(in directory: URL, key: String, namespace: String) -> URL {
            let filename = Data("\(namespace).\(key)".utf8).base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "=", with: "")
            return directory.appendingPathComponent(filename)
        }

        @Test("Encrypted values round-trip")
        func roundTrip() throws {
            try withStore { store, _, namespace in
                let expected = Data("private value".utf8)
                try store.store(key: "token", value: expected, namespace: namespace, accessGroup: nil)

                let actual = try store.retrieve(key: "token", namespace: namespace, accessGroup: nil)

                #expect(actual == expected)
            }
        }

        @Test("Missing values report item not found")
        func missingValue() throws {
            _ = try withStore { store, _, namespace in
                #expect(throws: KeychainError.self) {
                    try store.retrieve(key: "missing", namespace: namespace, accessGroup: nil)
                }
            }
        }

        @Test("Corrupt ciphertext fails closed")
        func corruptCiphertext() throws {
            try withStore { store, directory, namespace in
                try store.store(
                    key: "token",
                    value: Data("private value".utf8),
                    namespace: namespace,
                    accessGroup: nil
                )
                let file = storedFileURL(in: directory, key: "token", namespace: namespace)
                try Data([0x00, 0x01, 0x02]).write(to: file)

                #expect(throws: (any Error).self) {
                    try store.retrieve(key: "token", namespace: namespace, accessGroup: nil)
                }
            }
        }

        @Test("One zeroizing master key supports concurrent operations")
        func concurrentRoundTrips() async throws {
            let directory = Self.createSafeTestDirectory(prefix: "petrel-file-store-concurrency")
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try FileEncryptedStore(
                storageDirectory: directory,
                masterKey: SymmetricKey(size: .bits256)
            )
            let namespace = "petrel-file-store-concurrency-\(UUID().uuidString)"
            let effectiveDirectory = effectiveDirectory(directory)
            defer {
                for index in 0 ..< 32 {
                    try? FileManager.default.removeItem(
                        at: storedFileURL(
                            in: effectiveDirectory,
                            key: "token-\(index)",
                            namespace: namespace
                        )
                    )
                }
                try? FileManager.default.removeItem(at: directory)
            }

            try await withThrowingTaskGroup(of: Bool.self) { group in
                for index in 0 ..< 32 {
                    group.addTask {
                        let key = "token-\(index)"
                        let expected = Data("private-value-\(index)".utf8)
                        try store.store(key: key, value: expected, namespace: namespace, accessGroup: nil)
                        return try store.retrieve(key: key, namespace: namespace, accessGroup: nil) == expected
                    }
                }
                for try await matched in group {
                    #expect(matched)
                }
            }
        }

        @Test("Missing master key throws instead of generating ephemeral key")
        func missingMasterKeyThrows() throws {
            let directory = Self.createSafeTestDirectory(prefix: "petrel-missing-key-test")
            defer { try? FileManager.default.removeItem(at: directory) }

            #expect(throws: FileEncryptedStore.FileEncryptedStoreError.self) {
                try FileEncryptedStore(storageDirectory: directory, masterKey: nil)
            }
        }

        @Test("Temporary directory paths are rejected")
        func temporaryDirectoryRejected() throws {
            let tmpDir = URL(fileURLWithPath: "/tmp/petrel-insecure-\(UUID().uuidString)")
            #expect(throws: FileEncryptedStore.FileEncryptedStoreError.self) {
                try FileEncryptedStore(storageDirectory: tmpDir, masterKey: SymmetricKey(size: .bits256))
            }
        }

        @Test("Symlink storage directory paths are rejected")
        func symlinkDirectoryRejected() throws {
            let targetDir = Self.createSafeTestDirectory(prefix: "petrel-symlink-target")
            let symlinkDir = Self.createSafeTestDirectory(prefix: "petrel-symlink-link")
            try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
            defer {
                try? FileManager.default.removeItem(at: symlinkDir)
                try? FileManager.default.removeItem(at: targetDir)
            }
            try FileManager.default.createSymbolicLink(at: symlinkDir, withDestinationURL: targetDir)

            #expect(throws: FileEncryptedStore.FileEncryptedStoreError.self) {
                try FileEncryptedStore(storageDirectory: symlinkDir, masterKey: SymmetricKey(size: .bits256))
            }
        }

        @Test("Storage directory and files enforce owner-only permissions")
        func permissionsEnforced() throws {
            try withStore { store, directory, namespace in
                try store.store(key: "token", value: Data("secret".utf8), namespace: namespace, accessGroup: nil)
                let file = storedFileURL(in: directory, key: "token", namespace: namespace)

                var dirStat = stat()
                #expect(stat(directory.path, &dirStat) == 0)
                #expect(dirStat.st_uid == getuid())
                #expect((dirStat.st_mode & 0o777) == 0o700)

                var fileStat = stat()
                #expect(stat(file.path, &fileStat) == 0)
                #expect(fileStat.st_uid == getuid())
                #expect((fileStat.st_mode & 0o777) == 0o600)
            }
        }

        @Test("LogManager and logSink output do not contain master key material")
        func noKeyMaterialInLogs() throws {
            let rawKey = SymmetricKey(size: .bits256)
            let rawKeyData = rawKey.withUnsafeBytes { Data($0) }
            let keyB64 = rawKeyData.base64EncodedString()

            var capturedMessages: [String] = []
            let lock = Mutex<[String]>([])
            let sink: @Sendable (String) -> Void = { message in
                lock.withLock { $0.append(message) }
            }

            let directory = Self.createSafeTestDirectory(prefix: "petrel-log-check")
            defer { try? FileManager.default.removeItem(at: directory) }

            let store = try FileEncryptedStore(storageDirectory: directory, masterKey: rawKey, logSink: sink)
            try store.store(key: "secretKey", value: Data("sensitiveValue".utf8), namespace: "test", accessGroup: nil)
            _ = try store.retrieve(key: "secretKey", namespace: "test", accessGroup: nil)

            capturedMessages = lock.withLock { $0 }
            #expect(!capturedMessages.isEmpty, "Log messages must be captured")
            for message in capturedMessages {
                #expect(!message.contains(keyB64), "Log message contains raw base64 master key: \(message)")
            }
        }

        @Test("Atomic write replacement leaves prior ciphertext intact if write fails")
        func atomicWriteReplacement() throws {
            let directory = Self.createSafeTestDirectory(prefix: "petrel-atomic-write-tests")
            let namespace = "petrel-atomic-test-\(UUID().uuidString)"
            let masterKey = SymmetricKey(size: .bits256)
            defer { try? FileManager.default.removeItem(at: directory) }

            let failingOperations = FileEncryptedStore.Operations(
                rename: { _, _ in -1 },
                unlink: {
                    #if canImport(Darwin)
                        return Darwin.unlink($0)
                    #elseif canImport(Glibc)
                        return Glibc.unlink($0)
                    #endif
                }
            )

            let liveStore = try FileEncryptedStore(storageDirectory: directory, masterKey: masterKey)
            let initialValue = Data("initial-secret-data".utf8)
            try liveStore.store(key: "atomicItem", value: initialValue, namespace: namespace, accessGroup: nil)
            let targetFile = storedFileURL(in: directory, key: "atomicItem", namespace: namespace)

            #expect(try liveStore.retrieve(key: "atomicItem", namespace: namespace, accessGroup: nil) == initialValue)

            // Inject failure into rename during replacement write
            let failingStore = try FileEncryptedStore(
                storageDirectory: directory,
                masterKey: masterKey,
                operations: failingOperations
            )

            #expect(throws: FileEncryptedStore.FileEncryptedStoreError.encryptionFailed) {
                try failingStore.store(key: "atomicItem", value: Data("new-secret-data".utf8), namespace: namespace, accessGroup: nil)
            }

            // Prior ciphertext remains intact and decryptable
            #expect(try liveStore.retrieve(key: "atomicItem", namespace: namespace, accessGroup: nil) == initialValue)

            // Check that no lingering .tmp files exist in directory
            let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            let tmpFiles = contents.filter { $0.hasPrefix(".tmp.") }
            #expect(tmpFiles.isEmpty)

            // Verify target file permissions remain 0600
            var fileStat = stat()
            #expect(lstat(targetFile.path, &fileStat) == 0)
            #expect((fileStat.st_mode & 0o777) == 0o600)
        }

        @Test("Retrieve fails closed with insecurePermissions when file is group or world accessible")
        func retrieveInsecurePermissionsRejected() throws {
            try withStore { store, directory, namespace in
                try store.store(key: "token", value: Data("secret".utf8), namespace: namespace, accessGroup: nil)
                let file = storedFileURL(in: directory, key: "token", namespace: namespace)

                // Chmod file to 0644 (group/world readable)
                #expect(chmod(file.path, 0o644) == 0)

                #expect(throws: FileEncryptedStore.FileEncryptedStoreError.insecurePermissions) {
                    _ = try store.retrieve(key: "token", namespace: namespace, accessGroup: nil)
                }
            }
        }
    }
#endif
