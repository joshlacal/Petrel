//
//  KeychainFailClosedTests.swift
//  PetrelTests
//
//  Storage reads that fail must not be reported as "nothing stored": every
//  destructive path downstream keys off absence.
//

import Foundation
@testable import Petrel
import Testing

private let failClosedDID = "did:plc:failclosed"

private func makeFailClosedAccount() -> Account {
    Account(did: failClosedDID, handle: "failclosed.example", pdsURL: URL(string: "https://pds.test")!)
}

private func makeFailClosedSession(refreshToken: String, createdAt: Date = Date()) -> Session {
    Session(
        accessToken: "access-\(refreshToken)",
        refreshToken: refreshToken,
        createdAt: createdAt,
        expiresIn: 3600,
        tokenType: .dpop,
        did: failClosedDID
    )
}

private func withBackend<T>(
    _ backend: InMemorySecureStorage,
    _ body: () async throws -> T
) async rethrows -> T {
    try await withSerializedStorageOverrideTest {
        KeychainManager._setStorageOverride(backend)
        defer { KeychainManager._setStorageOverride(nil) }
        return try await body()
    }
}

@Suite("Keychain reads fail closed", .serialized)
struct KeychainFailClosedTests {
    @Test("Orphan cleanup skips a DID whose account read fails")
    func orphanCleanupSkipsUnreadableAccount() async throws {
        let backend = InMemorySecureStorage()
        try await withBackend(backend) {
            let storage = KeychainStorage(namespace: "test.failclosed.orphan")
            let session = makeFailClosedSession(refreshToken: "rt-live")
            try await storage.saveAccountAndSession(
                makeFailClosedAccount(), session: session, for: failClosedDID
            )

            // The account is present but unreadable. Previously this looked exactly
            // like "account missing", and the repair deleted the live session.
            backend.failRetrieveMatching = { $0 == "account.\(failClosedDID)" }
            KeychainManager.clearCache()

            let result = await storage.validateAndRepairAuthenticationState()

            #expect(result.unreadableStates.contains(failClosedDID))
            #expect(!result.cleanedOrphanedSessions.contains(failClosedDID))

            backend.failRetrieveMatching = nil
            KeychainManager.clearCache()
            let survivor = try await storage.getSession(for: failClosedDID)
            #expect(survivor?.refreshToken == "rt-live", "A live session must survive an unreadable account")
        }
    }

    @Test("A session write is refused when the stored session cannot be read")
    func staleCheckFailsClosedOnReadError() async throws {
        let backend = InMemorySecureStorage()
        try await withBackend(backend) {
            let storage = KeychainStorage(namespace: "test.failclosed.stalecheck")
            let stored = makeFailClosedSession(refreshToken: "rt-stored")
            try await storage.saveAccountAndSession(
                makeFailClosedAccount(), session: stored, for: failClosedDID
            )

            // The freshness comparison cannot be made, so the write must not land —
            // and the caller must be told, so it can fall back to a pending write.
            backend.failRetrieveMatching = { $0 == "session.\(failClosedDID)" }
            KeychainManager.clearCache()

            await #expect(throws: (any Error).self) {
                try await storage.saveSession(
                    makeFailClosedSession(refreshToken: "rt-blind"), for: failClosedDID
                )
            }

            backend.failRetrieveMatching = nil
            KeychainManager.clearCache()
            let after = try await storage.getSession(for: failClosedDID)
            #expect(after?.refreshToken == "rt-stored", "The unverifiable write must not have overwritten anything")
        }
    }

    @Test("A stored session that cannot be decoded may still be replaced")
    func staleCheckAllowsReplacingUndecodableSession() async throws {
        let backend = InMemorySecureStorage()
        try await withBackend(backend) {
            let namespace = "test.failclosed.corruptprimary"
            let storage = KeychainStorage(namespace: namespace)
            try await storage.saveAccount(makeFailClosedAccount(), for: failClosedDID)
            backend.plant(
                key: "session.\(failClosedDID)", namespace: namespace, data: Data("garbage".utf8)
            )
            KeychainManager.clearCache()

            // Unusable to every reader, so overwriting it is the repair path.
            try await storage.saveSession(
                makeFailClosedSession(refreshToken: "rt-repaired"), for: failClosedDID
            )

            let after = try await storage.getSession(for: failClosedDID)
            #expect(after?.refreshToken == "rt-repaired")
        }
    }

    @Test("Deleting a session reports copies that survived")
    func deleteSessionThrowsOnPartialFailure() async throws {
        let backend = InMemorySecureStorage()
        try await withBackend(backend) {
            let storage = KeychainStorage(namespace: "test.failclosed.delete")
            let session = makeFailClosedSession(refreshToken: "rt-logout")
            try await storage.saveAccountAndSession(
                makeFailClosedAccount(), session: session, for: failClosedDID
            )
            try await storage.saveSessionBackup(session, for: failClosedDID)

            // The backup survives logout; getSession would promote it back, so the
            // caller must not be told the logout completed.
            backend.failDeleteMatching = { $0 == "session.backup.\(failClosedDID)" }

            await #expect(throws: (any Error).self) {
                try await storage.deleteSession(for: failClosedDID)
            }

            backend.failDeleteMatching = nil
            KeychainManager.clearCache()
            let resurrected = try await storage.getSession(for: failClosedDID)
            #expect(
                resurrected?.refreshToken == "rt-logout",
                "The surviving backup is exactly what the thrown error warns about"
            )
        }
    }

    @Test("Deleting a session that was never stored succeeds")
    func deleteSessionToleratesAbsence() async throws {
        let backend = InMemorySecureStorage()
        try await withBackend(backend) {
            let storage = KeychainStorage(namespace: "test.failclosed.deleteabsent")
            try await storage.deleteSession(for: failClosedDID)
        }
    }

    @Test("An unreadable session is reported as an error, not as no session")
    func getSessionReportsReadFailure() async throws {
        let backend = InMemorySecureStorage()
        try await withBackend(backend) {
            let storage = KeychainStorage(namespace: "test.failclosed.getsession")
            try await storage.saveAccountAndSession(
                makeFailClosedAccount(),
                session: makeFailClosedSession(refreshToken: "rt-unreadable"),
                for: failClosedDID
            )

            backend.failRetrieveMatching = { $0.hasPrefix("session") }
            KeychainManager.clearCache()

            await #expect(throws: (any Error).self) {
                try await storage.getSession(for: failClosedDID)
            }
        }
    }

    @Test("A session that is genuinely absent still reads as nil")
    func getSessionReturnsNilWhenAbsent() async throws {
        let backend = InMemorySecureStorage()
        try await withBackend(backend) {
            let storage = KeychainStorage(namespace: "test.failclosed.absent")
            let session = try await storage.getSession(for: failClosedDID)
            #expect(session == nil)
        }
    }

    @Test("An unreadable account list is an error, not an empty list")
    func listAccountDIDsReportsReadFailure() async throws {
        let backend = InMemorySecureStorage()
        try await withBackend(backend) {
            let storage = KeychainStorage(namespace: "test.failclosed.didlist")
            try await storage.saveAccount(makeFailClosedAccount(), for: failClosedDID)

            backend.failRetrieveMatching = { $0 == "accountDIDs" }
            KeychainManager.clearCache()

            await #expect(throws: (any Error).self) {
                try await storage.listAccountDIDs()
            }
        }
    }

    @Test("A gateway session that cannot be read is not migrated over")
    func gatewaySessionReadFailureSkipsLegacyMigration() async throws {
        let backend = InMemorySecureStorage()
        try await withBackend(backend) {
            let namespace = "test.failclosed.gateway"
            let storage = KeychainStorage(namespace: namespace)
            try await storage.saveAccount(makeFailClosedAccount(), for: failClosedDID)
            try await storage.saveCurrentDID(failClosedDID)
            try await storage.saveGatewaySession("per-did-session", for: failClosedDID)
            // A stale legacy copy that migration would otherwise promote.
            backend.plant(key: "gatewaySession", namespace: namespace, data: Data("legacy-session".utf8))

            backend.failRetrieveMatching = { $0 == "gatewaySession.\(failClosedDID)" }
            KeychainManager.clearCache()

            await #expect(throws: (any Error).self) {
                try await storage.getGatewaySession(for: failClosedDID)
            }

            backend.failRetrieveMatching = nil
            KeychainManager.clearCache()
            let current = try await storage.getGatewaySession(for: failClosedDID)
            #expect(current == "per-did-session", "The unreadable session must not have been replaced by the legacy copy")
        }
    }

    @Test("Legacy gateway migration keeps the source until the new copy is verified")
    func legacyGatewayMigrationKeepsSourceOnSaveFailure() async throws {
        let backend = InMemorySecureStorage()
        try await withBackend(backend) {
            let namespace = "test.failclosed.gatewaymigrate"
            let storage = KeychainStorage(namespace: namespace)
            try await storage.saveAccount(makeFailClosedAccount(), for: failClosedDID)
            try await storage.saveCurrentDID(failClosedDID)
            backend.plant(key: "gatewaySession", namespace: namespace, data: Data("legacy-session".utf8))
            KeychainManager.clearCache()

            // The per-DID write fails, so deleting the legacy copy would lose the session.
            backend.failStoreMatching = { $0 == "gatewaySession.\(failClosedDID)" }

            let migrated = try await storage.getGatewaySession(for: failClosedDID)
            #expect(migrated == "legacy-session")

            backend.failStoreMatching = nil
            KeychainManager.clearCache()
            let stillThere = try await storage.getGatewaySession(for: failClosedDID)
            #expect(stillThere == "legacy-session", "The legacy copy must survive a failed migration")
        }
    }
}
