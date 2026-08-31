#if os(macOS) || os(iOS)
    #if canImport(CryptoKit)
        import CryptoKit
    #else
        import Crypto
    #endif
    import Foundation
    @testable import Petrel
    import Testing

    @Suite("File-encrypted secure storage deletion")
    struct FileEncryptedStoreDeletionTests {
        private static func createSafeTestDirectory(prefix: String) -> URL {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".petrel-test-storage")
            let dir = base.appendingPathComponent("\(prefix)-\(UUID().uuidString)")
            return dir
        }

        private func withStore<T>(
            _ body: (FileEncryptedStore, URL, String) throws -> T
        ) throws -> T {
            let directory = Self.createSafeTestDirectory(prefix: "petrel-file-store-delete-tests")
            let namespace = "petrel-file-store-delete-test-\(UUID().uuidString)"
            let store = try FileEncryptedStore(
                storageDirectory: directory,
                masterKey: SymmetricKey(size: .bits256)
            )
            defer {
                // Restore write permission first: a failure test may have removed it.
                try? FileManager.default.setAttributes(
                    [.posixPermissions: 0o700],
                    ofItemAtPath: directory.path
                )
                try? FileManager.default.removeItem(at: directory)
            }
            return try body(store, directory, namespace)
        }

        private func denyWrites(to directory: URL) throws {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o500],
                ofItemAtPath: directory.path
            )
        }

        @Test("Deleting a stored value removes it")
        func deleteRemovesStoredValue() throws {
            try withStore { store, _, namespace in
                try store.store(
                    key: "token",
                    value: Data("private value".utf8),
                    namespace: namespace,
                    accessGroup: nil
                )

                try store.delete(key: "token", namespace: namespace, accessGroup: nil)

                #expect(throws: KeychainError.self) {
                    try store.retrieve(key: "token", namespace: namespace, accessGroup: nil)
                }
            }
        }

        @Test("Deleting a value that was never stored succeeds")
        func deleteToleratesMissingValue() throws {
            try withStore { store, _, namespace in
                try store.delete(key: "missing", namespace: namespace, accessGroup: nil)
            }
        }

        @Test("A delete that cannot remove the secret throws")
        func deleteSurfacesRemovalFailure() throws {
            try withStore { store, directory, namespace in
                try store.store(
                    key: "token",
                    value: Data("private value".utf8),
                    namespace: namespace,
                    accessGroup: nil
                )
                try denyWrites(to: directory)

                #expect(throws: (any Error).self) {
                    try store.delete(key: "token", namespace: namespace, accessGroup: nil)
                }
                // The secret is still readable, which is exactly why the throw matters.
                let survivor = try store.retrieve(key: "token", namespace: namespace, accessGroup: nil)
                #expect(survivor == Data("private value".utf8))
            }
        }

        @Test("Deleting a namespace removes every value in it")
        func deleteAllRemovesNamespace() throws {
            try withStore { store, _, namespace in
                let otherNamespace = "petrel-file-store-other-\(UUID().uuidString)"
                for key in ["one", "two"] {
                    try store.store(
                        key: key,
                        value: Data(key.utf8),
                        namespace: namespace,
                        accessGroup: nil
                    )
                }
                try store.store(
                    key: "kept",
                    value: Data("kept".utf8),
                    namespace: otherNamespace,
                    accessGroup: nil
                )

                try store.deleteAll(namespace: namespace, accessGroup: nil)

                for key in ["one", "two"] {
                    #expect(throws: KeychainError.self) {
                        try store.retrieve(key: key, namespace: namespace, accessGroup: nil)
                    }
                }
                let kept = try store.retrieve(key: "kept", namespace: otherNamespace, accessGroup: nil)
                #expect(kept == Data("kept".utf8))
            }
        }

        @Test("A namespace wipe that removes nothing throws instead of reporting success")
        func deleteAllSurfacesRemovalFailure() throws {
            try withStore { store, directory, namespace in
                for key in ["one", "two"] {
                    try store.store(
                        key: key,
                        value: Data(key.utf8),
                        namespace: namespace,
                        accessGroup: nil
                    )
                }
                try denyWrites(to: directory)

                #expect(throws: (any Error).self) {
                    try store.deleteAll(namespace: namespace, accessGroup: nil)
                }
            }
        }
    }
#endif
