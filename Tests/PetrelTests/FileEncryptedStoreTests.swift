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
            _ body: (FileEncryptedStore, URL) throws -> T
        ) throws -> T {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("petrel-file-store-tests-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try FileEncryptedStore(
                storageDirectory: directory,
                masterKey: SymmetricKey(size: .bits256)
            )
            return try body(store, directory)
        }

        @Test("Encrypted values round-trip")
        func roundTrip() throws {
            try withStore { store, _ in
                let expected = Data("private value".utf8)
                try store.store(key: "token", value: expected, namespace: "test", accessGroup: nil)

                let actual = try store.retrieve(key: "token", namespace: "test", accessGroup: nil)

                #expect(actual == expected)
            }
        }

        @Test("Missing values report item not found")
        func missingValue() throws {
            _ = try withStore { store, _ in
                #expect(throws: KeychainError.self) {
                    try store.retrieve(key: "missing", namespace: "test", accessGroup: nil)
                }
            }
        }

        @Test("Corrupt ciphertext fails closed")
        func corruptCiphertext() throws {
            try withStore { store, directory in
                try store.store(
                    key: "token",
                    value: Data("private value".utf8),
                    namespace: "test",
                    accessGroup: nil
                )
                let file = try #require(
                    FileManager.default.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: nil
                    ).first
                )
                try Data([0x00, 0x01, 0x02]).write(to: file)

                #expect(throws: (any Error).self) {
                    try store.retrieve(key: "token", namespace: "test", accessGroup: nil)
                }
            }
        }
    }
#endif
