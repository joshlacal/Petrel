// RefreshCircuitBreakerTests.swift
// Petrel

import Foundation
@testable import Petrel
import Testing

@Suite("RefreshCircuitBreaker Tests")
struct RefreshCircuitBreakerTests {

    @Test("Reset for DID clears failure tracking and allows refresh")
    func testResetForDIDAllowsRefresh() async {
        let breaker = RefreshCircuitBreaker()
        let did = "did:plc:test123"

        // Record enough failures to open circuit
        await breaker.recordFailure(for: did, kind: .invalidGrant) // +2
        await breaker.recordFailure(for: did, kind: .network)      // +1 = 3, circuit opens

        // Verify circuit is open
        let canRefreshBeforeReset = await breaker.canAttemptRefresh(for: did)
        #expect(canRefreshBeforeReset == false)

        // Reset the circuit
        await breaker.reset(for: did)

        // Verify circuit is now closed and allows refresh
        let canRefreshAfterReset = await breaker.canAttemptRefresh(for: did)
        #expect(canRefreshAfterReset == true)

        // Verify state is closed
        let state = await breaker.getState(for: did)
        #expect(state == .closed)
    }

    @Test("forceHalfOpen transitions open circuit to half-open for recovery test")
    func testForceHalfOpenTransition() async {
        let breaker = RefreshCircuitBreaker()
        let did = "did:plc:test456"

        // Open the circuit
        await breaker.recordFailure(for: did, kind: .invalidGrant)
        await breaker.recordFailure(for: did, kind: .network)

        // Verify circuit is open
        let initialState = await breaker.getState(for: did)
        #expect(initialState == .open)

        // Force transition to half-open
        let transitioned = await breaker.forceHalfOpen(for: did)
        #expect(transitioned == true)

        // Verify state is now half-open
        let newState = await breaker.getState(for: did)
        #expect(newState == .halfOpen)

        // Should now allow one refresh attempt
        let canRefresh = await breaker.canAttemptRefresh(for: did)
        #expect(canRefresh == true)
    }
}
