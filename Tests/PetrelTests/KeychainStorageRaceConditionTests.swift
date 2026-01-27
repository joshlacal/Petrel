//
//  KeychainStorageRaceConditionTests.swift
//  PetrelTests
//
//  Created by Claude on September 20, 2025.
//

import CryptoKit
@testable import Petrel
import XCTest

final class KeychainStorageRaceConditionTests: XCTestCase {
    var keychainStorage: KeychainStorage!
    let testNamespace = "test.keychain.raceCondition"
    let testDID = "did:plc:test123456789"

    override func setUp() async throws {
        try await super.setUp()
        keychainStorage = KeychainStorage(namespace: testNamespace)

        // Clean up any existing test data
        try? await keychainStorage.deleteAccount(for: testDID)
        try? await keychainStorage.deleteSession(for: testDID)
        try? await keychainStorage.deleteGatewaySession(for: testDID)
    }

    override func tearDown() async throws {
        // Clean up test data
        try? await keychainStorage.deleteAccount(for: testDID)
        try? await keychainStorage.deleteSession(for: testDID)
        try? await keychainStorage.deleteGatewaySession(for: testDID)
        try await super.tearDown()
    }

    // MARK: - Atomic Save Tests

    func testAtomicAccountSessionSave() async throws {
        let account = createTestAccount()
        let session = createTestSession()

        // Test atomic save
        try await keychainStorage.saveAccountAndSession(account, session: session, for: testDID)

        // Verify both were saved
        let retrievedAccount = try await keychainStorage.getAccount(for: testDID)
        let retrievedSession = try await keychainStorage.getSession(for: testDID)

        XCTAssertNotNil(retrievedAccount)
        XCTAssertNotNil(retrievedSession)
        XCTAssertEqual(retrievedAccount?.did, testDID)
        XCTAssertEqual(retrievedSession?.did, testDID)
        XCTAssertEqual(retrievedSession?.accessToken, session.accessToken)
    }

    // MARK: - Race Condition Simulation Tests

    func testSessionValidationDetectsInconsistentState() async throws {
        let account = createTestAccount()
        let session = createTestSession()

        // Simulate race condition: save account but not session
        try await keychainStorage.saveAccount(account, for: testDID)
        // Intentionally NOT saving session to simulate race condition

        // Run validation
        let result = await keychainStorage.validateAndRepairAuthenticationState()

        // Should detect inconsistent state
        XCTAssertTrue(result.hasIssues)
        XCTAssertTrue(result.inconsistentStates.contains(testDID))
        XCTAssertTrue(result.cleanedOrphanedAccounts.contains(testDID))

        // Account should be cleaned up since session couldn't be recovered
        let retrievedAccount = try await keychainStorage.getAccount(for: testDID)
        XCTAssertNil(retrievedAccount)
    }

    func testSessionRecoveryFromTemporaryLocation() async throws {
        let session = createTestSession()

        // Manually place session in temporary location (simulating interrupted save)
        let tempKey = "\(testNamespace).session.temp.\(testDID)"
        let sessionData = try JSONEncoder().encode(session)
        try KeychainManager.store(key: tempKey, value: sessionData, namespace: testNamespace)

        // Add account to accounts list so validation finds it
        let accountDIDs = [testDID]
        let accountDIDsKey = "\(testNamespace).accountDIDs"
        let accountDIDsData = try JSONEncoder().encode(accountDIDs)
        try KeychainManager.store(key: accountDIDsKey, value: accountDIDsData, namespace: testNamespace)

        // Run validation - should recover session
        let result = await keychainStorage.validateAndRepairAuthenticationState()

        // Should have recovered the session
        XCTAssertTrue(result.recoveredSessions.contains(testDID))

        // Session should now be available at the correct location
        let retrievedSession = try await keychainStorage.getSession(for: testDID)
        XCTAssertNotNil(retrievedSession)
        XCTAssertEqual(retrievedSession?.accessToken, session.accessToken)
    }

    func testSessionRecoveryFromBackupLocation() async throws {
        let session = createTestSession()

        // Manually place session in backup location (simulating interrupted save)
        let backupKey = "\(testNamespace).session.backup.\(testDID)"
        let sessionData = try JSONEncoder().encode(session)
        try KeychainManager.store(key: backupKey, value: sessionData, namespace: testNamespace)

        // Add account to accounts list so validation finds it
        let accountDIDs = [testDID]
        let accountDIDsKey = "\(testNamespace).accountDIDs"
        let accountDIDsData = try JSONEncoder().encode(accountDIDs)
        try KeychainManager.store(key: accountDIDsKey, value: accountDIDsData, namespace: testNamespace)

        // Run validation - should recover session
        let result = await keychainStorage.validateAndRepairAuthenticationState()

        // Should have recovered the session
        XCTAssertTrue(result.recoveredSessions.contains(testDID))

        // Session should now be available at the correct location
        let retrievedSession = try await keychainStorage.getSession(for: testDID)
        XCTAssertNotNil(retrievedSession)
        XCTAssertEqual(retrievedSession?.accessToken, session.accessToken)
    }

    // MARK: - Error Handling Tests

    func testSessionSaveWithInvalidData() async throws {
        let invalidSession = Session(
            accessToken: "", // Invalid empty token
            refreshToken: "refresh123",
            createdAt: Date(),
            expiresIn: 3600,
            tokenType: "Bearer",
            did: testDID
        )

        // Should throw error for invalid session
        do {
            try await keychainStorage.saveSession(invalidSession, for: testDID)
            XCTFail("Should have thrown error for invalid session")
        } catch {
            XCTAssertTrue(error is KeychainError)
        }
    }

    func testOrphanedSessionCleanup() async throws {
        let session = createTestSession()

        // Save session without account (simulating orphaned state)
        try await keychainStorage.saveSession(session, for: testDID)

        // Run validation
        let result = await keychainStorage.validateAndRepairAuthenticationState()

        // Should have cleaned up orphaned session
        XCTAssertTrue(result.cleanedOrphanedSessions.contains(testDID))

        // Session should be gone
        let retrievedSession = try await keychainStorage.getSession(for: testDID)
        XCTAssertNil(retrievedSession)
    }

    func testGatewaySessionPreventsAccountCleanup() async throws {
        let account = createTestAccount()

        // Save account without standard session, but with gateway session
        try await keychainStorage.saveAccount(account, for: testDID)
        try await keychainStorage.saveGatewaySession("gateway-session-123", for: testDID)

        let result = await keychainStorage.validateAndRepairAuthenticationState()

        // Gateway session should count as a valid auth session
        XCTAssertFalse(result.cleanedOrphanedAccounts.contains(testDID))
        let retrievedAccount = try await keychainStorage.getAccount(for: testDID)
        XCTAssertNotNil(retrievedAccount)
    }

    func testLegacyGatewaySessionMigration() async throws {
        let account = createTestAccount()

        try await keychainStorage.saveAccount(account, for: testDID)
        try await keychainStorage.saveGatewaySession("legacy-gateway-session")

        let migrated = try await keychainStorage.getGatewaySession(for: testDID)
        XCTAssertEqual(migrated, "legacy-gateway-session")

        let legacy = try await keychainStorage.getGatewaySession()
        XCTAssertNil(legacy)
    }

    // MARK: - Concurrency Tests

    func testConcurrentAtomicSaves() async throws {
        let account = createTestAccount()
        let sessions = (1 ... 5).map { i in
            Session(
                accessToken: "token\(i)",
                refreshToken: "refresh\(i)",
                createdAt: Date(),
                expiresIn: 3600,
                tokenType: "Bearer",
                did: testDID
            )
        }

        // Perform concurrent atomic saves
        await withTaskGroup(of: Void.self) { group in
            for session in sessions {
                group.addTask {
                    try? await self.keychainStorage.saveAccountAndSession(account, session: session, for: self.testDID)
                }
            }
        }

        // Should have ended up with one consistent state
        let retrievedAccount = try await keychainStorage.getAccount(for: testDID)
        let retrievedSession = try await keychainStorage.getSession(for: testDID)

        XCTAssertNotNil(retrievedAccount)
        XCTAssertNotNil(retrievedSession)
        XCTAssertEqual(retrievedAccount?.did, testDID)
        XCTAssertEqual(retrievedSession?.did, testDID)

        // Session should be one of the ones we tried to save
        let sessionTokens = sessions.map { $0.accessToken }
        XCTAssertTrue(try sessionTokens.contains(XCTUnwrap(retrievedSession?.accessToken)))
    }

    // MARK: - Helper Methods

    private func createTestAccount() -> Account {
        return Account(
            did: testDID,
            handle: "test.example.com",
            pdsURL: URL(string: "https://pds.example.com")!
        )
    }

    private func createTestSession() -> Session {
        return Session(
            accessToken: "test_access_token_123",
            refreshToken: "test_refresh_token_456",
            createdAt: Date(),
            expiresIn: 3600,
            tokenType: "Bearer",
            did: testDID
        )
    }
}
