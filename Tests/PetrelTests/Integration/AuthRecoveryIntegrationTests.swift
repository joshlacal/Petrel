//
//  AuthRecoveryIntegrationTests.swift
//  Petrel
//
//  Integration tests for the full auth recovery flow.
//

import Foundation
@testable import Petrel
import Testing

@Suite("Auth Recovery Integration Tests")
struct AuthRecoveryIntegrationTests {
    @Test("Full recovery flow: circuit opens, user resets, refresh succeeds")
    func fullRecoveryFlow() async {
        // Setup
        let breaker = RefreshCircuitBreaker()
        let did = "did:plc:integration-test"

        // 1. Simulate failures opening circuit (need 3 failures)
        await breaker.recordFailure(for: did, kind: .network)
        await breaker.recordFailure(for: did, kind: .network)
        await breaker.recordFailure(for: did, kind: .network)

        // Verify circuit is open
        let isOpen = await breaker.getState(for: did)
        #expect(isOpen == .open)

        // 2. User requests recovery (reset)
        await breaker.reset(for: did)

        // 3. Verify circuit is closed
        let isClosed = await breaker.getState(for: did)
        #expect(isClosed == .closed)

        // 4. Verify refresh is allowed
        let canRefresh = await breaker.canAttemptRefresh(for: did)
        #expect(canRefresh == true)
    }

    @Test("Session recovery restores missing session from backup")
    func sessionRecoveryFromBackup() async throws {
        let storage = KeychainStorage(namespace: "test.session.recovery.\(UUID().uuidString)")
        let did = "did:plc:session-recovery-\(UUID().uuidString)"

        // Create and save session to backup
        let originalSession = Session(
            accessToken: "original-access-token",
            refreshToken: "original-refresh-token",
            createdAt: Date(),
            expiresIn: 3600,
            tokenType: .dpop,
            did: did
        )
        try await storage.saveSessionBackup(originalSession, for: did)

        // Primary session should not exist (we only saved to backup)
        let primarySession = try await storage.getSession(for: did)
        #expect(primarySession == nil)

        // Recover from backup
        let recovered = try await storage.recoverSessionFromBackup(for: did)
        #expect(recovered != nil)
        #expect(recovered?.did == did)
        #expect(recovered?.accessToken == "original-access-token")

        // Cleanup
        try? await storage.deleteSession(for: did)
        try? await storage.deleteSessionBackup(for: did)
    }

    @Test("Circuit breaker allows refresh after time-based recovery to half-open")
    func circuitBreakerHalfOpenRecovery() async {
        let breaker = RefreshCircuitBreaker()
        let did = "did:plc:half-open-test"

        // Open the circuit
        await breaker.recordFailure(for: did, kind: .network)
        await breaker.recordFailure(for: did, kind: .network)
        await breaker.recordFailure(for: did, kind: .network)

        let initialState = await breaker.getState(for: did)
        #expect(initialState == .open)

        // Use forceHalfOpen to simulate time-based recovery
        let transitioned = await breaker.forceHalfOpen(for: did)
        #expect(transitioned == true)

        let halfOpenState = await breaker.getState(for: did)
        #expect(halfOpenState == .halfOpen)

        // Should allow one refresh attempt in half-open state
        let canRefresh = await breaker.canAttemptRefresh(for: did)
        #expect(canRefresh == true)
    }

    @Test("Successful refresh closes circuit from half-open state")
    func successfulRefreshClosesCircuit() async {
        let breaker = RefreshCircuitBreaker()
        let did = "did:plc:success-test"

        // Open the circuit
        await breaker.recordFailure(for: did, kind: .network)
        await breaker.recordFailure(for: did, kind: .network)
        await breaker.recordFailure(for: did, kind: .network)

        // Force to half-open
        _ = await breaker.forceHalfOpen(for: did)

        // Record success (simulates successful refresh)
        await breaker.recordSuccess(for: did)

        // Circuit should now be closed
        let finalState = await breaker.getState(for: did)
        #expect(finalState == .closed)

        // Should allow refresh
        let canRefresh = await breaker.canAttemptRefresh(for: did)
        #expect(canRefresh == true)
    }
}
