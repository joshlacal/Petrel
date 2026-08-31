//
//  AccountAndSessionCoherenceTests.swift
//  PetrelTests
//

import Foundation
@testable import Petrel
import Synchronization
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
    did: String = testDID,
    accessToken: String = "test-access-token"
) -> Session {
    Session(
        accessToken: accessToken,
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

private final class TestAsyncGate: @unchecked Sendable {
    private let lock = NSLock()
    private var isOpened = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func open() {
        let toResume: [CheckedContinuation<Void, Never>] = lock.withLock {
            isOpened = true
            let list = continuations
            continuations.removeAll()
            return list
        }
        for c in toResume { c.resume() }
    }

    func wait() async {
        let shouldWait: Bool = lock.withLock {
            !isOpened
        }
        if shouldWait {
            await withCheckedContinuation { continuation in
                lock.withLock {
                    if isOpened {
                        continuation.resume()
                    } else {
                        continuations.append(continuation)
                    }
                }
            }
        }
    }
}

@Suite("Account and session coherence", .serialized)
struct AccountAndSessionCoherenceTests {

    @Test("Restart with stale primary and pending copy promotes on first getSession via cold actor probe")
    func restartWithStalePrimaryPromotesPending() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let namespace = "test.coherence.restart"
            let oldSession = makeSession(refreshToken: "rt-stale", createdAt: Date(timeIntervalSinceNow: -600))
            let newSession = makeSession(refreshToken: "rt-promoted", createdAt: Date())

            // Plant old primary AND pending copy directly in backend without calling savePendingSession,
            // so process-wide pendingSessionKnownGenerations is NOT populated.
            let oldData = try JSONEncoder().encode(oldSession)
            let newData = try JSONEncoder().encode(newSession)
            backend.plant(key: "session.\(testDID)", namespace: namespace, data: oldData)
            backend.plant(key: "session.pending.\(testDID)", namespace: namespace, data: newData)
            KeychainManager.clearCache()

            // Fresh storage instance (simulating restart): checkedPendingDIDs is empty on this actor
            let storage = KeychainStorage(namespace: namespace)
            let result = try await storage.getSession(for: testDID)
            #expect(result?.refreshToken == "rt-promoted", "Pending session must be promoted over stale primary on first read after actor init")

            // Second read serves the promoted session from memory/primary
            let secondRead = try await storage.getSession(for: testDID)
            #expect(secondRead?.refreshToken == "rt-promoted")
        }
    }

    @Test("Failed saveSession or saveAccountAndSession does not erase the pending marker")
    func failedSavePreservesPendingMarker() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let namespace = "test.coherence.failedsave"
            let storage1 = KeychainStorage(namespace: namespace)
            let storage2 = KeychainStorage(namespace: namespace)
            let oldSession = makeSession(refreshToken: "rt-old", createdAt: Date(timeIntervalSinceNow: -600))
            let newSession = makeSession(refreshToken: "rt-new", createdAt: Date())

            try await storage1.saveSession(oldSession, for: testDID)
            // Prime storage2's one-shot probe before saving the pending copy, so storage2 has checked pending
            // and cached oldSession as primary.
            let primed = try await storage2.getSession(for: testDID)
            #expect(primed?.refreshToken == "rt-old")

            try await storage1.savePendingSession(newSession, for: testDID)
            // 1. Attempt a stale write (refused before write)
            let staleSession = makeSession(refreshToken: "rt-stale", createdAt: Date(timeIntervalSinceNow: -1200))
            try await storage1.saveSession(staleSession, for: testDID)

            // 2. Attempt a throwing standalone saveSession (failing during temporary save)
            let freshSession1 = makeSession(refreshToken: "rt-fresh1")
            backend.failStoreMatching = { key in key.contains("session.temp") }
            await #expect(throws: (any Error).self) {
                try await storage1.saveSession(freshSession1, for: testDID)
            }
            backend.failStoreMatching = nil

            // 3. Attempt a throwing saveAccountAndSession (failing during temporary save)
            let freshSession2 = makeSession(refreshToken: "rt-fresh2")
            backend.failStoreMatching = { key in key.contains("session.temp") }
            await #expect(throws: (any Error).self) {
                try await storage1.saveAccountAndSession(makeAccount(), session: freshSession2, for: testDID)
            }
            backend.failStoreMatching = nil

            // Reading through storage2 must STILL find and promote the pending newSession because the shared marker is preserved.
            // (If the marker had been erroneously cleared, storage2's primed state would skip the pending probe and return oldSession).
            let result = try await storage2.getSession(for: testDID)
            #expect(result?.refreshToken == "rt-new", "Pending marker must be preserved across stale, throwing saveSession, and failed saveAccountAndSession")
        }
    }
    @Test("Cross-instance account cache invalidation keeps multiple managers in sync")
    func crossInstanceAccountCacheInvalidation() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let namespace = "test.coherence.crossinstance"
            // Use TWO separate storage actor instances
            let storageA = KeychainStorage(namespace: namespace)
            let storageB = KeychainStorage(namespace: namespace)
            let managerA = await AccountManager(storage: storageA)
            let managerB = await AccountManager(storage: storageB)

            let account = makeAccount(handle: "original.handle")
            try await managerA.addAccount(account)

            // Manager B fetches and caches account
            let cachedB = await managerB.getAccount(did: account.did)
            #expect(cachedB?.handle == "original.handle")

            // Manager A updates account
            var updated = account
            updated.handle = "updated.handle"
            try await managerA.addAccount(updated)

            // Manager B must observe the update across storage instances
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

            let initial = await manager.getAccount(did: account.did)
            #expect(initial != nil)

            let deletionStarted = TestAsyncGate()
            let deletionContinue = DispatchSemaphore(value: 0)

            backend.beforeDelete = { key in
                if key == "account.\(account.did)" {
                    deletionStarted.open()
                    deletionContinue.wait()
                }
            }
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await manager.removeAccount(did: account.did)
                }
                group.addTask {
                    await deletionStarted.wait()
                    // Concurrently fetch account while deletion is suspended inside backend
                    _ = await manager.getAccount(did: account.did)
                    deletionContinue.signal()
                }
                try await group.waitForAll()
            }
            backend.beforeDelete = nil
            // After deletion finishes, cache must NOT contain the deleted account
            let finalAccount = await manager.getAccount(did: account.did)
            #expect(finalAccount == nil, "Account must be absent after deletion, even if read raced the deletion")
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

            let retrievalCounter = Mutex<Int>(0)
            backend.setOperationObserver { op, key in
                if op == .retrieve && key.hasPrefix("dpopNonces") {
                    retrievalCounter.withLock { $0 += 1 }
                }
            }

            // 1. First read: absent in backend, queries backend (retrievalCount becomes 1), caches negative entry
            let nonces1 = try await storage.getDPoPNonces(for: testDID)
            #expect(nonces1 == nil)
            #expect(retrievalCounter.withLock { $0 } == 1, "First read of absent nonce must query backend once")

            // 2. Second read: negative cache hit, 0 backend retrievals (retrievalCount remains 1)
            let nonces2 = try await storage.getDPoPNonces(for: testDID)
            #expect(nonces2 == nil)
            #expect(retrievalCounter.withLock { $0 } == 1, "Second read must hit negative cache with 0 backend queries")

            // 3. Save nonces (invalidates negative cache and populates positive cache)
            try await storage.saveDPoPNonces(["auth.example.com": "nonce-123"], for: testDID)

            // 4. Read nonces (positive cache hit, 0 backend retrievals)
            let nonces3 = try await storage.getDPoPNonces(for: testDID)
            #expect(nonces3?["auth.example.com"] == "nonce-123")
            #expect(retrievalCounter.withLock { $0 } == 1, "Read of stored nonce must hit positive cache with 0 backend queries")
        }
    }

    @Test("Concurrent getGatewaySession during in-flight migration does not duplicate migration probes")
    func concurrentGatewaySessionReadDuringMigrationDoesNotDuplicateProbes() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let namespace = "test.coherence.concurrentmigration"
            let storage1 = KeychainStorage(namespace: namespace)
            let storage2 = KeychainStorage(namespace: namespace)
            let account = makeAccount(did: testDID, handle: "migration.test")

            try await storage1.saveAccount(account, for: testDID)
            try await storage1.saveCurrentDID(testDID)

            // Plant legacy gateway session in backend
            backend.plant(key: "gatewaySession", namespace: namespace, data: Data("legacy-secret-session".utf8))
            KeychainManager.clearCache()

            let storeStarted = TestAsyncGate()
            let storeContinue = DispatchSemaphore(value: 0)

            backend.beforeStore = { key in
                if key == "gatewaySession.\(testDID)" {
                    storeStarted.open()
                    storeContinue.wait()
                }
            }

            var storage2Result: String??
            try await withThrowingTaskGroup(of: String??.self) { group in
                group.addTask {
                    let res1 = try await storage1.getGatewaySession(for: testDID)
                    #expect(res1 == "legacy-secret-session")
                    return nil
                }
                group.addTask {
                    await storeStarted.wait()
                    // While storage1 is persisting the migrated session (active claim in flight),
                    // storage2 calls getGatewaySession. It must NOT start a concurrent migration attempt.
                    let res2 = try await storage2.getGatewaySession(for: testDID)
                    storeContinue.signal()
                    return .some(res2)
                }
                for try await result in group {
                    if let observed = result { storage2Result = observed }
                }
            }
            backend.beforeStore = nil

            // While migration was in flight, storage2 saw the in-flight claim and returned nil
            #expect(storage2Result == .some(nil), "Concurrent read while migration is in-flight must respect active claim and return nil")

            // After storage1 commits migration to per-DID storage, subsequent reads on storage2 return the migrated session
            let postMigrationRead = try await storage2.getGatewaySession(for: testDID)
            #expect(postMigrationRead == "legacy-secret-session", "Subsequent read retrieves the migrated per-DID session")
        }
    }
}
