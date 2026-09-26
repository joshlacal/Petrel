#if os(macOS)

    import Foundation
    import Security
    import Synchronization
    import Testing
    @testable import Petrel

    /// F68: a macOS runtime-fixture launch keeps keychain items in its own profile, never in the
    /// user's login keychain, and separate launches share nothing.
    @Suite("Fixture launch keychain (F68)")
    struct FixtureKeychainTests {
        /// Stands in for Security: records any call that escapes the fixture store and answers as
        /// an empty keychain, so a regression is observed without touching the login keychain.
        final class SecurityCalls: Sendable {
            let names = Mutex<[String]>([])

            var functions: KeychainSecItem.SystemFunctions {
                .init(
                    add: { _, _ in self.names.withLock { $0.append("SecItemAdd") }; return errSecSuccess },
                    copyMatching: { _, _ in self.names.withLock { $0.append("SecItemCopyMatching") }; return errSecItemNotFound },
                    update: { _, _ in self.names.withLock { $0.append("SecItemUpdate") }; return errSecItemNotFound },
                    delete: { _ in self.names.withLock { $0.append("SecItemDelete") }; return errSecItemNotFound }
                )
            }
        }

        /// A fixture launch config (0600) naming a fresh profile directory.
        static func fixtureConfig(profile: String? = nil) throws -> (config: URL, profile: URL) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("petrel-f68-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let profileURL = root.appendingPathComponent("profile")
            let config = root.appendingPathComponent("config.json")
            let json = try JSONSerialization.data(withJSONObject: ["profile": profile ?? profileURL.path])
            #expect(FileManager.default.createFile(atPath: config.path, contents: json, attributes: [.posixPermissions: 0o600]))
            return (config, profileURL)
        }

        /// Runs `body` as a process launched with `config` would: its own store read from disk,
        /// the platform keychain backend, and no reads cached from another launch.
        static func asLaunch<T>(_ config: URL, security: SecurityCalls, _ body: () async throws -> T) async throws -> T {
            FixtureLaunch.setTestKeychain(FixtureKeychain(configPath: config.path))
            KeychainSecItem.setSystemForTesting(security.functions)
            KeychainManager._setStorageOverride(AppleKeychainStore())
            defer {
                KeychainManager._setStorageOverride(nil)
                KeychainSecItem.setSystemForTesting(nil)
                FixtureLaunch.setTestKeychain(nil)
            }
            return try await body()
        }

        @Test("A fixture launch keeps every keychain item in its profile and never calls Security")
        func itemsStayInProfile() async throws {
            try await withSerializedStorageOverrideTest {
                let (config, profile) = try Self.fixtureConfig()
                let security = SecurityCalls()
                try await Self.asLaunch(config, security: security) {
                    let storage = KeychainStorage(namespace: "blue.catbird", accessGroup: "TEAM.blue.catbird.shared")
                    try await storage.saveCurrentDID("did:web:alice.request-fixture.example")
                    #expect(try await storage.getCurrentDID() == "did:web:alice.request-fixture.example")

                    try KeychainManager.store(key: "session", value: Data("s1".utf8), namespace: "blue.catbird")
                    #expect(try KeychainManager.retrieve(key: "session", namespace: "blue.catbird", bypassCache: true) == Data("s1".utf8))
                    try KeychainManager.delete(key: "session", namespace: "blue.catbird")
                    #expect(throws: (any Error).self) {
                        try KeychainManager.retrieve(key: "session", namespace: "blue.catbird", bypassCache: true)
                    }

                    // The MLS layer's key-class items, identified by application tag.
                    let tag = Data("mls.signature.alice".utf8)
                    let keyQuery: [String: Any] = [kSecClass as String: kSecClassKey, kSecAttrApplicationTag as String: tag]
                    var add = keyQuery
                    add[kSecValueData as String] = Data([1, 2, 3])
                    #expect(KeychainSecItem.add(add as CFDictionary, nil) == errSecSuccess)
                    #expect(KeychainSecItem.add(add as CFDictionary, nil) == errSecDuplicateItem)
                    var read = keyQuery
                    read[kSecReturnData as String] = true
                    var result: CFTypeRef?
                    #expect(KeychainSecItem.copyMatching(read as CFDictionary, &result) == errSecSuccess)
                    #expect(result as? Data == Data([1, 2, 3]))
                }

                #expect(security.names.withLock { $0 } == [])
                let file = profile.appendingPathComponent(FixtureLaunch.keychainFileName)
                let mode = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int
                #expect(mode == 0o600)
            }
        }

        @Test("Separate fixture launches share no current DID, and a relaunch finds its own")
        func launchesAreIsolated() async throws {
            try await withSerializedStorageOverrideTest {
                let first = try Self.fixtureConfig().config
                let second = try Self.fixtureConfig().config
                let security = SecurityCalls()
                let storage = KeychainStorage(namespace: "blue.catbird")

                try await Self.asLaunch(first, security: security) {
                    try await storage.saveCurrentDID("did:web:alice.request-fixture.example")
                }
                try await Self.asLaunch(second, security: security) {
                    #expect(try await storage.getCurrentDID() == nil)
                    try await storage.saveCurrentDID("did:web:bob.request-fixture.example")
                }
                let relaunched = try await Self.asLaunch(first, security: security) {
                    try await storage.getCurrentDID()
                }
                #expect(relaunched == "did:web:alice.request-fixture.example")
                #expect(security.names.withLock { $0 } == [])
            }
        }

        @Test("An unusable fixture config fails closed instead of reaching the login keychain")
        func unusableConfigFailsClosed() async throws {
            try await withSerializedStorageOverrideTest {
                let (config, _) = try Self.fixtureConfig(profile: "relative/profile")
                let security = SecurityCalls()
                try await Self.asLaunch(config, security: security) {
                    #expect(FixtureLaunch.keychain?.fileURL == nil)
                    #expect(throws: (any Error).self) {
                        try KeychainManager.store(key: "session", value: Data("s1".utf8), namespace: "blue.catbird")
                    }
                }
                #expect(security.names.withLock { $0 } == [])
            }
        }
    }

#endif
