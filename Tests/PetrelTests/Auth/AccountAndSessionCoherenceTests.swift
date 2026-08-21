//
//  AccountAndSessionCoherenceTests.swift
//  PetrelTests
//

import Foundation
@testable import Petrel
import Testing

private let testDID = "did:plc:coherencetest"
private let testDID2 = "did:plc:coherencetest2"

private func makeAccount(did: String = testDID, handle: String = "test.example") -> Account {
    Account(did: did, handle: handle, pdsURL: URL(string: "https://pds.test")!)
}

private func makeSession(
    refreshToken: String,
    createdAt: Date = Date(),
    expiresIn: TimeInterval = 3600,
    did: String = testDID
) -> Session {
    Session(
        accessToken: "access-\(refreshToken)",
        refreshToken: refreshToken,
        createdAt: createdAt,
        expiresIn: expiresIn,
        tokenType: .dpop,
        did: did
    )
}

private func withInMemoryBackend<T>(
    _ backend: InMemorySecureStorage,
    _ body: () async throws -> T
) async rethrows -> T {
    try await withSerializedStorageOverrideTest {
        KeychainManager._setStorageOverride(backend)
        defer { KeychainManager._setStorageOverride(nil) }
        return try await body()
    }
}

@Suite("Account and session coherence", .serialized)
struct AccountAndSessionCoherenceTests {

    @Test("Restart with stale primary and pending copy promotes on first getSession")
    func restartWithStalePrimaryPromotesPending() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let namespace = "test.coherence.restart"
            let storage1 = KeychainStorage(namespace: namespace)
            let oldSession = makeSession(refreshToken: "rt-stale", createdAt: Date(timeIntervalSinceNow: -600))
            let newSession = makeSession(refreshToken: "rt-promoted", createdAt: Date())

            // Plant old primary in backend and save pending session
            try await storage1.saveSession(oldSession, for: testDID)
            try await storage1.savePendingSession(newSession, for: testDID)

            // Clear in-memory cache to simulate fresh actor / restart
            KeychainManager.clearCache()

            // Fresh storage instance (simulating restart)
            let storage2 = KeychainStorage(namespace: namespace)
            let result = try await storage2.getSession(for: testDID)
            #expect(result?.refreshToken == "rt-promoted", "Pending session must be promoted over stale primary on first read after restart")

            let secondRead = try await storage2.getSession(for: testDID)
            #expect(secondRead?.refreshToken == "rt-promoted")
        }
    }

    @Test("Failed saveSession or saveAccountAndSession does not erase the pending marker")
    func failedSavePreservesPendingMarker() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let namespace = "test.coherence.failedsave"
            let storage = KeychainStorage(namespace: namespace)
            let oldSession = makeSession(refreshToken: "rt-old", createdAt: Date(timeIntervalSinceNow: -600))
            let newSession = makeSession(refreshToken: "rt-new", createdAt: Date())

            try await storage.saveSession(oldSession, for: testDID)
            try await storage.savePendingSession(newSession, for: testDID)

            // Attempt a stale write (createdAt older than existing session)
            let staleSession = makeSession(refreshToken: "rt-stale", createdAt: Date(timeIntervalSinceNow: -1200))
            try await storage.saveSession(staleSession, for: testDID)

            // getSession must still promote the pending newSession
            let result = try await storage.getSession(for: testDID)
            #expect(result?.refreshToken == "rt-new", "Pending marker must be preserved after refused stale write")
        }
    }

    @Test("Cross-instance account cache invalidation keeps multiple managers in sync")
    func crossInstanceAccountCacheInvalidation() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let namespace = "test.coherence.crossinstance"
            let storage = KeychainStorage(namespace: namespace)
            let managerA = await AccountManager(storage: storage)
            let managerB = await AccountManager(storage: storage)

            let account = makeAccount(handle: "original.handle")
            try await managerA.addAccount(account)

            // Manager B fetches and caches account
            let cachedB = await managerB.getAccount(did: account.did)
            #expect(cachedB?.handle == "original.handle")

            // Manager A updates account
            var updated = account
            updated.handle = "updated.handle"
            try await managerA.addAccount(updated)

            // Manager B must observe the update
            let freshB = await managerB.getAccount(did: account.did)
            #expect(freshB?.handle == "updated.handle", "Manager B must observe account update from Manager A")

            // Manager A removes account
            try await managerA.removeAccount(did: account.did)

            // Manager B must observe deletion
            let deletedB = await managerB.getAccount(did: account.did)
            #expect(deletedB == nil, "Manager B must observe account deletion from Manager A")
        }
    }
    @Test("Concurrent getAccount during account deletion does not repopulate the cache with stale data")
    func concurrentGetDuringDeletionDoesNotRepopulateCache() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let namespace = "test.coherence.deletionrace"
            let storage = KeychainStorage(namespace: namespace)
            let manager = await AccountManager(storage: storage)

            let account = makeAccount(handle: "to-delete.handle")
            try await manager.addAccount(account)

            // Ensure cached
            let initial = await manager.getAccount(did: account.did)
            #expect(initial != nil)

            // Concurrently delete and get
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await manager.removeAccount(did: account.did)
                }
                group.addTask {
                    await Task.yield()
                    _ = await manager.getAccount(did: account.did)
                }
                try await group.waitForAll()
            }

            // After deletion completes, cache must not contain the deleted account
            let finalAccount = await manager.getAccount(did: account.did)
            #expect(finalAccount == nil, "Account must be absent after deletion, regardless of concurrent read interleaving")
        }
    }

    @Test("Account switch does not permanently mark ineligible legacy migration as attempted")
    func accountSwitchPreservesLegacyMigrationEligibility() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let namespace = "test.coherence.switchmigration"
            let storage = KeychainStorage(namespace: namespace)
            let accountA = makeAccount(did: testDID, handle: "a.example")
            let accountB = makeAccount(did: testDID2, handle: "b.example")

            try await storage.saveAccount(accountA, for: testDID)
            try await storage.saveAccount(accountB, for: testDID2)
            try await storage.saveCurrentDID(testDID) // Account A is current

            // Plant legacy gateway session for account B (which is not current yet)
            backend.plant(key: "gatewaySession", namespace: namespace, data: Data("legacy-session-b".utf8))
            KeychainManager.clearCache()

            // Probing gateway session for B while A is current must report nil without marking B as attempted
            let ineligibleRead = try await storage.getGatewaySession(for: testDID2)
            #expect(ineligibleRead == nil, "B is not current, so legacy migration is ineligible")

            // Now switch active account to B
            try await storage.saveCurrentDID(testDID2)

            // Probing gateway session for B now that it is current MUST migrate and return the session
            let migratedRead = try await storage.getGatewaySession(for: testDID2)
            #expect(migratedRead == "legacy-session-b", "B must successfully migrate legacy session after becoming current account")
        }
    }

    @Test("Negative cache eliminates repeated syscalls for absent DPoP nonces")
    func negativeCacheForAbsentDPoPNonces() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let namespace = "test.coherence.nonces"
            let storage = KeychainStorage(namespace: namespace)

            // First read: absent in backend, caches negative result
            let nonces1 = try await storage.getDPoPNonces(for: testDID)
            #expect(nonces1 == nil)

            // Verify negative cache in KeychainManager avoids backend retrieve
            let nonces2 = try await storage.getDPoPNonces(for: testDID)
            #expect(nonces2 == nil)

            // Save nonces (invalidates negative cache)
            try await storage.saveDPoPNonces(["auth.example.com": "nonce-123"], for: testDID)

            // Read nonces (positive cache hit)
            let nonces3 = try await storage.getDPoPNonces(for: testDID)
            #expect(nonces3?["auth.example.com"] == "nonce-123")
        }
    }
}
