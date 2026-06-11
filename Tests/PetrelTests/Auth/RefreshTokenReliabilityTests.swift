#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
@testable import Petrel
import Synchronization
import Testing

// MARK: - Test Doubles

/// In-memory SecureStorage with scriptable failures, for exercising the
/// refresh-persistence paths without touching the real keychain.
final class InMemorySecureStorage: SecureStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String: Data] = [:]

    /// Fail the next N store calls (any key), then succeed.
    var storeFailuresRemaining = 0
    /// Fail store calls whose (un-namespaced) key matches this predicate.
    var failStoreMatching: (@Sendable (String) -> Bool)?

    private func fullKey(_ key: String, _ namespace: String) -> String { "\(namespace)|\(key)" }

    func store(key: String, value: Data, namespace: String, accessGroup _: String?) throws {
        lock.lock()
        defer { lock.unlock() }
        if let matcher = failStoreMatching, matcher(key) {
            throw KeychainError.itemStoreError(status: -1)
        }
        if storeFailuresRemaining > 0 {
            storeFailuresRemaining -= 1
            throw KeychainError.itemStoreError(status: -1)
        }
        items[fullKey(key, namespace)] = value
    }

    func retrieve(key: String, namespace: String, accessGroup _: String?) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        guard let data = items[fullKey(key, namespace)] else {
            throw KeychainError.itemRetrievalError(status: -25300)
        }
        return data
    }

    func delete(key: String, namespace: String, accessGroup _: String?) throws {
        lock.lock()
        defer { lock.unlock() }
        items.removeValue(forKey: fullKey(key, namespace))
    }

    func deleteAll(namespace: String, accessGroup _: String?) throws {
        lock.lock()
        defer { lock.unlock() }
        items = items.filter { !$0.key.hasPrefix("\(namespace)|") }
    }

    func storeDPoPKey(_: P256.Signing.PrivateKey, keyTag _: String, accessGroup _: String?) throws {}

    func retrieveDPoPKey(keyTag _: String, accessGroup _: String?) throws -> P256.Signing.PrivateKey {
        throw KeychainError.itemRetrievalError(status: -25300)
    }

    func deleteDPoPKey(keyTag _: String, accessGroup _: String?) throws {}

    /// Plants raw bytes at a storage key, bypassing validation — used to simulate
    /// corrupted keychain entries.
    func plant(key: String, namespace: String, data: Data) {
        lock.lock()
        defer { lock.unlock() }
        items[fullKey(key, namespace)] = data
    }
}

/// Minimal AccountManaging mock: one fixed account, no side effects.
actor MockAccountManager: AccountManaging {
    private let account: Account

    init(account: Account) {
        self.account = account
    }

    func addAccount(_: Account) async throws {}
    func getAccount(did: String) async -> Account? { did == account.did ? account : nil }
    func updateAccountFromStorage(did _: String) async throws {}
    func removeAccount(did _: String) async throws {}
    func setCurrentAccount(did _: String) async throws {}
    func getCurrentAccount() async -> Account? { account }
    func listAccounts() async -> [Account] { [account] }
    func clearCurrentAccount() async {}
    func updateServiceDIDs(bskyAppViewDID _: String, bskyChatDID _: String) async throws {}
}

final class MockDIDResolver: DIDResolving, @unchecked Sendable {
    func resolveHandleToDID(handle _: String) async throws -> String { "did:plc:test" }
    func resolveDIDToPDSURL(did _: String) async throws -> URL { URL(string: "https://pds.test")! }
    func resolveDIDToHandleAndPDSURL(did _: String) async throws -> (String, URL) {
        ("test.example", URL(string: "https://pds.test")!)
    }
}

// MARK: - Fixtures

private let testDID = "did:plc:refreshreliability"

private func makeAccount() -> Account {
    Account(did: testDID, handle: "test.example", pdsURL: URL(string: "https://pds.test")!)
}

private func makeSession(refreshToken: String, createdAt: Date = Date(), expiresIn: TimeInterval = 3600) -> Session {
    Session(
        accessToken: "access-\(refreshToken)",
        refreshToken: refreshToken,
        createdAt: createdAt,
        expiresIn: expiresIn,
        tokenType: .dpop,
        did: testDID
    )
}

private func makeCore(storage: KeychainStorage) async -> OAuthCore {
    let config = OAuthConfig(
        clientId: "test-client",
        redirectUri: "test://callback",
        scope: "atproto"
    )
    return OAuthCore(
        storage: storage,
        accountManager: MockAccountManager(account: makeAccount()),
        networkService: NetworkService(baseURL: URL(string: "https://pds.test")!),
        oauthConfig: config,
        didResolver: MockDIDResolver()
    )
}

/// Runs `body` with an injected in-memory storage backend, always restoring the
/// platform default afterwards.
private func withInMemoryBackend<T>(
    _ backend: InMemorySecureStorage,
    _ body: () async throws -> T
) async rethrows -> T {
    KeychainManager._setStorageOverride(backend)
    defer { KeychainManager._setStorageOverride(nil) }
    return try await body()
}

// MARK: - Tests

@Suite("Refresh token reliability", .serialized)
struct RefreshTokenReliabilityTests {
    // The core "expires early" regression: a refresh that fails for transient
    // reasons (timeout, offline, 5xx) must not permanently poison the refresh
    // token in-process.
    @Test("Transient refresh failure does not burn the refresh token")
    func transientFailureDoesNotBurnToken() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let storage = KeychainStorage(namespace: "test.refresh.transient")
            let core = await makeCore(storage: storage)
            let account = makeAccount()
            let session = makeSession(refreshToken: "rt-transient")
            try await storage.saveAccountAndSession(account, session: session, for: testDID)

            let callCount = Mutex(0)
            await core.setPerformActualRefresh { _, _ in
                let attempt = callCount.withLock { $0 += 1; return $0 }
                if attempt == 1 {
                    throw AuthError.networkError(NetworkError.requestFailed)
                }
                return .refreshedSuccessfully
            }

            // First attempt fails transiently.
            await #expect(throws: AuthError.self) {
                try await core.refreshTokenIfNeeded(forceRefresh: true)
            }

            // Second attempt must reach the refresh implementation again with the
            // same token — before the fix it threw tokenRefreshFailed immediately.
            let result = try await core.refreshTokenIfNeeded(forceRefresh: true)
            #expect(result == .refreshedSuccessfully)
            #expect(callCount.withLock { $0 } == 2, "Refresh implementation should be retried after a transient failure")
        }
    }

    @Test("Definitive invalid_grant burns the refresh token")
    func invalidGrantBurnsToken() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let storage = KeychainStorage(namespace: "test.refresh.invalidgrant")
            let core = await makeCore(storage: storage)
            let account = makeAccount()
            let session = makeSession(refreshToken: "rt-burned")
            try await storage.saveAccountAndSession(account, session: session, for: testDID)

            let callCount = Mutex(0)
            await core.setPerformActualRefresh { _, _ in
                callCount.withLock { $0 += 1 }
                throw AuthError.invalidCredentials
            }

            await #expect(throws: AuthError.self) {
                try await core.refreshTokenIfNeeded(forceRefresh: true)
            }

            // Replay of a definitively-rejected token must be refused without
            // another network attempt.
            await #expect(throws: AuthError.self) {
                try await core.refreshTokenIfNeeded(forceRefresh: true)
            }
            #expect(callCount.withLock { $0 } == 1, "A definitively rejected token must not be retried")
        }
    }

    // The rotation-loss bug: server rotates the (single-use) refresh token, then the
    // keychain write fails. The new session must survive in memory and via the
    // pending key, and be promoted on the next read.
    @Test("Keychain write failure after refresh preserves the rotated session")
    func keychainWriteFailurePreservesRotatedSession() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let storage = KeychainStorage(namespace: "test.refresh.persistfail")
            let core = await makeCore(storage: storage)
            let account = makeAccount()
            let oldSession = makeSession(refreshToken: "rt-old", createdAt: Date(timeIntervalSinceNow: -600))
            try await storage.saveAccountAndSession(account, session: oldSession, for: testDID)

            // Fail every session write except the single-write pending key.
            backend.failStoreMatching = { key in
                key.contains("session") && !key.contains("session.pending")
            }

            let newSession = makeSession(refreshToken: "rt-new")
            await core.persistRefreshedSession(newSession, for: account)

            // The running process must see the new session immediately.
            let current = await core.currentSession(for: testDID)
            #expect(current?.refreshToken == "rt-new", "In-memory session must reflect the rotated token")

            // Keychain recovers (e.g. device unlocked): the pending copy must win
            // over the stale primary and be promoted.
            backend.failStoreMatching = nil
            let recovered = try await storage.getSession(for: testDID)
            #expect(recovered?.refreshToken == "rt-new", "Pending session must be promoted over the stale primary")

            let promoted = try await storage.getSession(for: testDID)
            #expect(promoted?.refreshToken == "rt-new")
        }
    }

    @Test("Stale write cannot overwrite a newer stored session")
    func staleWriteIsRefused() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let storage = KeychainStorage(namespace: "test.refresh.stalewrite")
            let account = makeAccount()
            let newer = makeSession(refreshToken: "rt-newer", createdAt: Date())
            let older = makeSession(refreshToken: "rt-older", createdAt: Date(timeIntervalSinceNow: -3600))

            try await storage.saveAccountAndSession(account, session: newer, for: testDID)
            // Both save paths must refuse the stale overwrite.
            try await storage.saveSession(older, for: testDID)
            try await storage.saveAccountAndSession(account, session: older, for: testDID)

            let stored = try await storage.getSession(for: testDID)
            #expect(stored?.refreshToken == "rt-newer", "Newest session must win over interleaved stale writes")
        }
    }

    @Test("Concurrent saves converge on the newest session")
    func concurrentSavesConverge() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let storage = KeychainStorage(namespace: "test.refresh.concurrent")
            let account = makeAccount()
            let base = Date()
            let sessions = (0 ..< 8).map { i in
                makeSession(refreshToken: "rt-\(i)", createdAt: base.addingTimeInterval(TimeInterval(i)))
            }

            try await withThrowingTaskGroup(of: Void.self) { group in
                for (index, session) in sessions.enumerated().shuffled() {
                    group.addTask {
                        if index % 2 == 0 {
                            try await storage.saveAccountAndSession(account, session: session, for: testDID)
                        } else {
                            try await storage.saveSession(session, for: testDID)
                        }
                    }
                }
                try await group.waitForAll()
            }

            let stored = try await storage.getSession(for: testDID)
            #expect(stored?.refreshToken == "rt-7", "After arbitrary interleaving the newest session must be stored")
        }
    }

    @Test("Stale backup cannot resurrect an old session")
    func staleBackupDoesNotResurrect() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let namespace = "test.refresh.backup"
            let storage = KeychainStorage(namespace: namespace)
            let account = makeAccount()
            let newer = makeSession(refreshToken: "rt-current", createdAt: Date())
            let older = makeSession(refreshToken: "rt-rotated-away", createdAt: Date(timeIntervalSinceNow: -3600))

            try await storage.saveAccountAndSession(account, session: newer, for: testDID)
            // Orphaned backup from a crashed earlier save.
            try await storage.saveSessionBackup(older, for: testDID)

            // Healthy primary: the backup must be ignored.
            let stored = try await storage.getSession(for: testDID)
            #expect(stored?.refreshToken == "rt-current")

            // Corrupt the primary: recovery may use the backup (only readable copy)…
            // (plant bypasses KeychainManager, so its write-through cache must be cleared)
            backend.plant(key: "session.\(testDID)", namespace: namespace, data: Data("garbage".utf8))
            KeychainManager.clearCache()
            let recovered = try await storage.getSession(for: testDID)
            #expect(recovered?.refreshToken == "rt-rotated-away", "Backup is the only readable copy here")

            // …but a newer pending copy must always beat an older backup.
            backend.plant(key: "session.\(testDID)", namespace: namespace, data: Data("garbage".utf8))
            KeychainManager.clearCache()
            try await storage.saveSessionBackup(older, for: testDID)
            try await storage.savePendingSession(newer, for: testDID)
            let pendingWins = try await storage.getSession(for: testDID)
            #expect(pendingWins?.refreshToken == "rt-current", "Newer pending session must beat an older backup")
        }
    }

    @Test("Logout removes pending and backup session copies")
    func logoutClearsAllSessionCopies() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let storage = KeychainStorage(namespace: "test.refresh.logout")
            let account = makeAccount()
            let session = makeSession(refreshToken: "rt-gone")

            try await storage.saveAccountAndSession(account, session: session, for: testDID)
            try await storage.saveSessionBackup(session, for: testDID)
            try await storage.savePendingSession(session, for: testDID)

            try await storage.deleteSession(for: testDID)

            let resurrected = try await storage.getSession(for: testDID)
            #expect(resurrected == nil, "No recovery path may resurrect a deleted session")
        }
    }
}
