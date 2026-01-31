// SessionRecoveryTests.swift
// Petrel

import Foundation
@testable import Petrel
import Testing

@Suite("Session Recovery Tests")
struct SessionRecoveryTests {
    @Test("saveSessionBackup and recoverSessionFromBackup work correctly")
    func sessionRecoveryFromBackup() async throws {
        // Setup: Create a storage with test namespace
        let storage = KeychainStorage(namespace: "test.recovery")
        let did = "did:plc:recovery-test"

        let testSession = Session(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token",
            createdAt: Date(),
            expiresIn: 3600,
            tokenType: .dpop,
            did: did
        )

        // Save session to backup location
        try await storage.saveSessionBackup(testSession, for: did)

        // Attempt recovery
        let recovered = try await storage.recoverSessionFromBackup(for: did)

        #expect(recovered != nil)
        #expect(recovered?.did == did)
        #expect(recovered?.accessToken == "test-access-token")
        #expect(recovered?.refreshToken == "test-refresh-token")

        // Cleanup
        try await storage.deleteSession(for: did)
        try await storage.deleteSessionBackup(for: did)
    }

    @Test("recoverSessionFromBackup returns nil when no backup exists")
    func recoveryReturnsNilWhenNoBackup() async throws {
        let storage = KeychainStorage(namespace: "test.recovery.empty")
        let did = "did:plc:nonexistent"

        let recovered = try await storage.recoverSessionFromBackup(for: did)

        #expect(recovered == nil)
    }

    @Test("recoverSessionFromBackup falls back to temp location")
    func recoveryFallsBackToTemp() async throws {
        let storage = KeychainStorage(namespace: "test.recovery.temp")
        let did = "did:plc:temp-test"

        let testSession = Session(
            accessToken: "temp-access-token",
            refreshToken: "temp-refresh-token",
            createdAt: Date(),
            expiresIn: 3600,
            tokenType: .dpop,
            did: did
        )

        // Save session to temp location (simulating interrupted save)
        try await storage.saveSessionToTemp(testSession, for: did)

        // Attempt recovery - should find it in temp location
        let recovered = try await storage.recoverSessionFromBackup(for: did)

        #expect(recovered != nil)
        #expect(recovered?.did == did)
        #expect(recovered?.accessToken == "temp-access-token")

        // Cleanup
        try await storage.deleteSessionTemp(for: did)
    }
}
