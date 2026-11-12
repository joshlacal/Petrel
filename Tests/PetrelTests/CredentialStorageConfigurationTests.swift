#if os(Linux) || os(macOS) || os(iOS)
    import Crypto
    import Foundation
    @testable import Petrel
    import Testing
    import Synchronization

    @Suite("Instance-scoped encrypted credentials")
    struct CredentialStorageConfigurationTests {
        private let namespace = "blue.catbird.albatross"
        private let did = "did:plc:credential-storage-fixture"
        private let key = Data(repeating: 0x6B, count: 32)

        private func directory() -> URL {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".petrel-test-storage")
            return base.appendingPathComponent("petrel-instance-storage-\(UUID().uuidString)")
        }

        private func storage(at directory: URL, key: Data? = nil) throws -> KeychainStorage {
            try KeychainStorage(
                namespace: namespace,
                credentialStorage: .encryptedFiles(directory: directory, masterKey: key ?? self.key)
            )
        }

        private func session(_ token: String) -> Session {
            Session(accessToken: token, refreshToken: "refresh-\(token)", createdAt: Date(), expiresIn: 3600, tokenType: .bearer, did: did)
        }

        private func file(in directory: URL, key: String) -> URL {
            let name = Data("\(namespace).\(key)".utf8).base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "=", with: "")
            return directory.appendingPathComponent(name)
        }

        @Test("Existing AES-GCM combined files retain their filename and representation")
        func legacyFileCompatibility() async throws {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let expected = session("persisted-before-upgrade")
            let plaintext = try JSONEncoder().encode(expected)
            let combined = try #require(AES.GCM.seal(plaintext, using: SymmetricKey(data: key)).combined)
            let target = file(in: directory, key: "session.\(did)")
            try combined.write(to: target)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
            let reader = try storage(at: directory)
            #expect(try await reader.getSession(for: did)?.accessToken == expected.accessToken)
            #expect(try Data(contentsOf: target) == combined)
        }

        @Test("Session replacement survives reopening and deletion remains absent")
        func persistRefreshReopenDelete() async throws {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let writer = try storage(at: directory)
            try await writer.saveSession(session("first"), for: did)
            let reopened = try storage(at: directory)
            #expect(try await reopened.getSession(for: did)?.accessToken == "first")
            try await reopened.saveSession(session("refreshed"), for: did)
            let afterRefresh = try storage(at: directory)
            #expect(try await afterRefresh.getSession(for: did)?.refreshToken == "refresh-refreshed")
            try await afterRefresh.deleteSession(for: did)
            let afterDelete = try storage(at: directory)
            #expect(try await afterDelete.getSession(for: did) == nil)
        }

        @Test("Same namespace in different directories has isolated values, generations, and DPoP observers")
        func directoryIsolation() async throws {
            let firstDirectory = directory()
            let secondDirectory = directory()
            defer {
                try? FileManager.default.removeItem(at: firstDirectory)
                try? FileManager.default.removeItem(at: secondDirectory)
            }
            let first = try storage(at: firstDirectory)
            let second = try storage(at: secondDirectory)
            let firstScope = await first.accountScopeDID(for: did)
            let secondScope = await second.accountScopeDID(for: did)
            #expect(firstScope != secondScope)
            #expect(first.keyMutationHub !== second.keyMutationHub)
            let firstEvents = Mutex(0)
            let secondEvents = Mutex(0)
            await first.setAuthContinuityObserver { _ in firstEvents.withLock { $0 += 1 } }
            await second.setAuthContinuityObserver { _ in secondEvents.withLock { $0 += 1 } }
            let ticket = await first.beginAuthContinuityMutationForTesting()
            await first.endAuthContinuityMutationForTesting(ticket)
            #expect(firstEvents.withLock { $0 } == 2)
            #expect(secondEvents.withLock { $0 } == 0)
            let representation = P256.Signing.PrivateKey().x963Representation
            try await first.saveDPoPKeyRepresentation(representation, for: did)
            #expect(try await first.getDPoPKeyRepresentation(for: did) == representation)
            #expect(try await second.getDPoPKeyRepresentation(for: did) == nil)
            #expect(first.keyMutationHub.generation(for: did) == 1)
            #expect(second.keyMutationHub.generation(for: did) == 0)
            let secondGeneration = AccountMutationHub.shared.generation(for: secondScope)
            try await first.saveAccount(Account(did: did, handle: "first.invalid", pdsURL: URL(string: "https://first.invalid")!), for: did)
            #expect(AccountMutationHub.shared.generation(for: secondScope) == secondGeneration)
            #expect(try await second.getAccount(for: did) == nil)
            try await first.saveSession(session("first-directory"), for: did)
            try await second.saveSession(session("second-directory"), for: did)
            #expect(try await first.getSession(for: did)?.accessToken == "first-directory")
            #expect(try await second.getSession(for: did)?.accessToken == "second-directory")
            try await first.saveGatewaySession("first-gateway", for: did)
            try await second.saveGatewaySession("second-gateway", for: did)
            #expect(try await first.getGatewaySession(for: did) == "first-gateway")
            #expect(try await second.getGatewaySession(for: did) == "second-gateway")
            try await first.deleteSession(for: did)
            #expect(try await second.getSession(for: did)?.accessToken == "second-directory")
        }

        @Test("Reopened instances for one directory share mutation coordination")
        func sameDirectoryCoordination() async throws {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let first = try storage(at: directory)
            // Directory URL spellings with and without a trailing slash identify
            // the same on-disk backend and must share mutation coordination.
            let second = try storage(at: URL(fileURLWithPath: directory.path, isDirectory: true))
            #expect(await first.accountScopeDID(for: did) == second.accountScopeDID(for: did))
            #expect(first.keyMutationHub === second.keyMutationHub)
            try await first.saveGatewaySession("old", for: did)
            #expect(try await second.getGatewaySession(for: did) == "old")
            try await first.saveGatewaySession("new", for: did)
            #expect(try await second.getGatewaySession(for: did) == "new")
        }

        @Test("Wrong key fails closed even after a successful read from the same directory")
        func wrongKeyDoesNotUseAnotherInstancesCache() async throws {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let correct = try storage(at: directory)
            try await correct.saveSession(session("protected"), for: did)
            #expect(try await correct.getSession(for: did)?.accessToken == "protected")
            let target = file(in: directory, key: "session.\(did)")
            let before = try Data(contentsOf: target)
            #expect(throws: (any Error).self) {
                try storage(at: directory, key: Data(repeating: 0x31, count: 32))
            }
            #expect(try Data(contentsOf: target) == before)
            #expect(try await correct.getSession(for: did)?.accessToken == "protected")
        }

        @Test("Malformed explicit keys fail before a directory is created")
        func invalidKeyIsRejected() throws {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            #expect(throws: (any Error).self) {
                try CredentialStorageConfiguration.encryptedFiles(directory: directory, masterKey: Data(repeating: 1, count: 31))
            }
            #expect(!FileManager.default.fileExists(atPath: directory.path))
        }

        @Test("File storage rejects unsupported access groups")
        func accessGroupIsRejected() throws {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let configuration = try CredentialStorageConfiguration.encryptedFiles(directory: directory, masterKey: key)
            #expect(throws: (any Error).self) {
                try KeychainStorage(namespace: namespace, accessGroup: "test.group", credentialStorage: configuration)
            }
        }

        @Test("Default storage still routes through the process-wide platform backend")
        func platformDefaultUsesProcessBackend() async throws {
            try await withGroupAwareStorage {
                let namespace = "petrel.default.route.\(UUID().uuidString)"
                let implicit = KeychainStorage(namespace: namespace)
                let explicit = try KeychainStorage(namespace: namespace, credentialStorage: .platformDefault)
                try await implicit.saveSession(session("implicit"), for: did)
                #expect(try await explicit.getSession(for: did)?.accessToken == "implicit")
                #expect(await implicit.accountScopeDID(for: did) == AccountMutationHub.ScopeDID(namespace: namespace, did: did))
                #expect(await explicit.accountScopeDID(for: did) == AccountMutationHub.ScopeDID(namespace: namespace, did: did))
            }
        }

        @Test("Explicit files bypass the process-wide backend and its cache in both directions")
        func explicitBackendBypassesProcessBackend() async throws {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            try await withGroupAwareStorage {
                let platform = KeychainStorage(namespace: namespace)
                let files = try storage(at: directory)
                try await platform.saveSession(session("platform"), for: did)
                // The platform write populated KeychainManager's in-memory cache;
                // the explicit backend must not observe it.
                #expect(try await files.getSession(for: did) == nil)
                try await files.saveSession(session("files"), for: did)
                #expect(try await platform.getSession(for: did)?.accessToken == "platform")
                #expect(try await files.getSession(for: did)?.accessToken == "files")
                #expect(FileManager.default.fileExists(atPath: file(in: directory, key: "session.\(did)").path))
            }
        }

        @Test("Client construction with a wrong key fails before any login can overwrite credentials")
        func clientRejectsWrongKey() async throws {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            try await storage(at: directory).saveSession(session("protected"), for: did)
            let config = OAuthConfig(
                clientId: "https://client.example/client-metadata.json",
                redirectUri: "blue.catbird:/oauth/callback",
                scope: "atproto"
            )
            await #expect(throws: (any Error).self) {
                _ = try await ATProtoClient(
                    oauthConfig: config, namespace: namespace, authMode: .legacy,
                    credentialStorage: .encryptedFiles(directory: directory, masterKey: Data(repeating: 0x31, count: 32))
                )
            }
            _ = try await ATProtoClient(
                oauthConfig: config, namespace: namespace, authMode: .legacy,
                credentialStorage: .encryptedFiles(directory: directory, masterKey: key)
            )
            #expect(try await storage(at: directory).getSession(for: did)?.accessToken == "protected")
        }

        @Test("Default configuration retains the platform backend and original mutation hub")
        func platformDefaultRemainsUnchanged() throws {
            let original = KeychainStorage(namespace: "petrel-default-no-io")
            let explicit = try KeychainStorage(namespace: "petrel-default-no-io", credentialStorage: .platformDefault)
            #expect(CredentialStorageConfiguration.platformDefault.backend == nil)
            #expect(original.keyMutationHub === KeychainStorage.dpopKeyMutationHub)
            #expect(explicit.keyMutationHub === original.keyMutationHub)
        }
    }
#endif
