#if os(Linux) || os(macOS) || os(iOS)
    #if canImport(CryptoKit)
        import CryptoKit
    #else
        import Crypto
    #endif
    import Foundation
    @testable import Petrel
    import Testing

    @Suite("File-encrypted secure storage")
    struct FileEncryptedStoreTests {
        private func withStore<T>(
            _ body: (FileEncryptedStore, URL, String) throws -> T
        ) throws -> T {
            let requestedDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("petrel-file-store-tests-\(UUID().uuidString)")
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
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("petrel-file-store-concurrency-\(UUID().uuidString)")
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
    }
#endif
