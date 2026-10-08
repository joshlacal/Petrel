import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Petrel
import XCTest

/// Synthetic storage only. No provider requests, system keychain, or real accounts.
final class GatewaySessionFailureContextTests: XCTestCase {
    private let gateway = URL(string: "https://gateway.example")!
    private let alice = "did:plc:syntheticalice"
    private let bob = "did:plc:syntheticbob"

    private func withFixture(
        _ backend: InMemorySecureStorage = InMemorySecureStorage(),
        _ operation: (ATProtoClient, KeychainStorage, AccountManager, ConfidentialGatewayStrategy) async throws -> Void
    ) async throws {
        try await withSerializedStorageOverrideTest {
            KeychainManager._setStorageOverride(backend)
            defer { KeychainManager._setStorageOverride(nil) }
            let namespace = "test.scoped.gateway.failure.\(UUID().uuidString)"
            let client = try await ATProtoClient(
                oauthConfig: OAuthConfig(clientId: "https://client.example/client-metadata.json",
                                         redirectUri: "blue.catbird:/oauth/callback", scope: "atproto"),
                namespace: namespace, authMode: .gateway, gatewayURL: gateway
            )
            let storage = KeychainStorage(namespace: namespace)
            let accounts = await AccountManager(storage: storage)
            for did in [alice, bob] {
                try await storage.saveAccount(Account(did: did, handle: "synthetic.example", pdsURL: gateway), for: did)
                try await storage.saveGatewaySession("synthetic-token-\(did)", for: did)
            }
            try await accounts.setCurrentAccount(did: bob)
            let strategy = ConfidentialGatewayStrategy(gatewayURL: gateway, storage: storage, accountManager: accounts)
            try await operation(client, storage, accounts, strategy)
        }
    }

    private func prepared(_ strategy: ConfidentialGatewayStrategy) async throws -> (URLRequest, AuthContext) {
        let pair = try await strategy.prepareAuthenticatedRequestWithContext(
            URLRequest(url: gateway.appendingPathComponent("xrpc/app.bsky.actor.getProfile"))
        )
        pair.1.releaseAuthenticationLease()
        return pair
    }

    private func reject(_ pair: (URLRequest, AuthContext), through strategy: ConfidentialGatewayStrategy) async throws {
        let response = HTTPURLResponse(url: pair.0.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        _ = try await strategy.handleUnauthorizedResponse(
            response, data: Data(#"{"error":"invalid_session","message":"Session expired"}"#.utf8),
            for: pair.0, context: pair.1
        )
    }

    func testPreparedPrincipalStaysBoundToBearerAfterSelectionChanges() async throws {
        try await withFixture { _, storage, accounts, strategy in
            let pair = try await prepared(strategy)
            try await accounts.setCurrentAccount(did: alice)
            XCTAssertEqual(pair.1.did, bob)
            XCTAssertEqual(pair.0.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-token-\(bob)")
            let current = try await storage.getCurrentDID()
            XCTAssertEqual(current, alice)
        }
    }

    func testActualCurrentRejectionProducesProofAndReplacementInvalidatesIt() async throws {
        try await withFixture { client, storage, _, strategy in
            let pair = try await prepared(strategy)
            let proof: GatewaySessionFailureContext
            do {
                try await reject(pair, through: strategy)
                XCTFail("Expected a scoped rejection")
                return
            } catch let rejection as ScopedGatewaySessionRejection {
                proof = rejection.context
            }
            XCTAssertEqual(proof.did, bob)
            let removed = try await storage.getGatewaySession(for: bob)
            XCTAssertNil(removed)
            let valid = await client.isCurrentGatewaySessionFailure(proof)
            XCTAssertTrue(valid, "Current rejection must remain actionable")
            try await storage.saveGatewaySession("synthetic-fresh-bob", for: bob)
            let stale = await client.isCurrentGatewaySessionFailure(proof)
            XCTAssertFalse(stale, "Same DID is insufficient after a new credential")
            let otherScope = KeychainStorage(namespace: "unrelated-synthetic-scope")
            let wrongScope = await otherScope.isCurrentGatewaySessionFailure(proof)
            XCTAssertFalse(wrongScope)
        }
    }

    func testLateTargetResponseCannotDeleteRestoredSourceCredential() async throws {
        try await withFixture { _, storage, accounts, strategy in
            let pair = try await prepared(strategy)
            try await accounts.setCurrentAccount(did: alice)
            do {
                try await reject(pair, through: strategy)
                XCTFail("Expected stale response rejection")
            } catch let error as ConfidentialGatewayStrategy.GatewayError {
                guard case .authenticationRequired = error else { throw error }
            }
            let a = try await storage.getGatewaySession(for: alice)
            let b = try await storage.getGatewaySession(for: bob)
            XCTAssertEqual(a, "synthetic-token-\(alice)")
            XCTAssertEqual(b, "synthetic-token-\(bob)")
        }
    }

    func testSameDIDRotationBeforeResponseCannotProduceTerminalProof() async throws {
        try await withFixture { _, storage, _, strategy in
            let pair = try await prepared(strategy)
            try await storage.saveGatewaySession("synthetic-rotated-bob", for: bob)
            do {
                try await reject(pair, through: strategy)
                XCTFail("Expected stale response rejection")
            } catch let error as ConfidentialGatewayStrategy.GatewayError {
                guard case .authenticationRequired = error else { throw error }
            }
            let session = try await storage.getGatewaySession(for: bob)
            XCTAssertEqual(session, "synthetic-rotated-bob")
        }
    }

    func testStaleResponseDoesNotReadOtherAccountsPendingCandidate() async throws {
        try await withFixture { _, storage, accounts, strategy in
            let pair = try await prepared(strategy)
            try await accounts.setCurrentAccount(did: alice)
            let unreadablePending = Data("deliberately-not-a-pending-candidate".utf8)
            try await storage.savePendingGatewayUpgradeData(unreadablePending, for: alice)
            do {
                try await reject(pair, through: strategy)
                XCTFail("Expected stale response rejection")
            } catch let error as ConfidentialGatewayStrategy.GatewayError {
                guard case .authenticationRequired = error else { throw error }
            }
            let pending = try await storage.getPendingGatewayUpgradeData(for: alice)
            XCTAssertEqual(pending, unreadablePending)
            let session = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(session, "synthetic-token-\(alice)")
        }
    }

    func testQueuedProofBecomesInvalidWhenWorkingAccountIsRestored() async throws {
        try await withFixture { client, storage, accounts, _ in
            let proof = try await storage.recordGatewaySessionFailure(
                ifMatches: "synthetic-token-\(bob)", for: bob, deleteMatchingSession: true
            )
            let proofValue = try XCTUnwrap(proof)
            let initiallyValid = await client.isCurrentGatewaySessionFailure(proofValue)
            XCTAssertTrue(initiallyValid)
            try await accounts.setCurrentAccount(did: alice)
            let afterRollback = await client.isCurrentGatewaySessionFailure(proofValue)
            XCTAssertFalse(afterRollback)
        }
    }

    func testUnscopedResponseDoesNotRemoveCurrentCredential() async throws {
        try await withFixture { _, storage, _, strategy in
            let pair = try await prepared(strategy)
            let response = HTTPURLResponse(url: pair.0.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            do {
                _ = try await strategy.handleUnauthorizedResponse(
                    response, data: Data(#"{"error":"invalid_session"}"#.utf8), for: pair.0, context: nil
                )
                XCTFail("Expected non-destructive auth-required error")
            } catch let error as ConfidentialGatewayStrategy.GatewayError {
                guard case .authenticationRequired = error else { throw error }
            }
            let session = try await storage.getGatewaySession(for: bob)
            XCTAssertEqual(session, "synthetic-token-\(bob)")
        }
    }

    func testRetainedCandidateFailureProofAlsoExpiresOnCredentialChange() async throws {
        try await withFixture { client, storage, _, _ in
            let proof = try await storage.recordGatewaySessionFailure(
                ifMatches: "synthetic-token-\(bob)", for: bob, deleteMatchingSession: false
            )
            let proofValue = try XCTUnwrap(proof)
            let initiallyValid = await client.isCurrentGatewaySessionFailure(proofValue)
            XCTAssertTrue(initiallyValid)
            try await storage.saveGatewaySession("synthetic-new-candidate", for: bob)
            let afterPromotion = await client.isCurrentGatewaySessionFailure(proofValue)
            XCTAssertFalse(afterPromotion)
        }
    }
    func testExternalBearerRotationEvictsOnlyStaleCacheAndNextRequestUsesReplacement() async throws {
        let backend = InMemorySecureStorage()
        try await withFixture(backend) { _, storage, _, strategy in
            let pair = try await prepared(strategy)
            let namespace = await storage.namespace
            backend.plant(key: "gatewaySession.\(bob)", namespace: namespace,
                          data: Data("synthetic-external-replacement".utf8))
            let staleCache = try await storage.getGatewaySession(for: bob)
            XCTAssertEqual(staleCache, "synthetic-token-\(bob)", "The fixture must start with a stale actor cache")
            do {
                try await reject(pair, through: strategy)
                XCTFail("Expected nonterminal stale-response error")
            } catch let error as ConfidentialGatewayStrategy.GatewayError {
                guard case .authenticationRequired = error else { throw error }
            }
            let nextRequest = try await prepared(strategy)
            XCTAssertEqual(nextRequest.0.value(forHTTPHeaderField: "Authorization"),
                           "Bearer synthetic-external-replacement")
            let persisted = backend.peek(key: "gatewaySession.\(bob)", namespace: namespace)
            XCTAssertEqual(persisted, Data("synthetic-external-replacement".utf8))
            let source = try await storage.getGatewaySession(for: alice)
            XCTAssertEqual(source, "synthetic-token-\(alice)")
        }
    }

    func testFailureProofCreationBypassesStaleSelectorCache() async throws {
        let backend = InMemorySecureStorage()
        try await withFixture(backend) { _, storage, _, _ in
            let namespace = await storage.namespace
            let cached = try await storage.getCurrentDID()
            XCTAssertEqual(cached, bob)
            backend.plant(key: "currentDID", namespace: namespace, data: Data(alice.utf8))
            let stale = try await storage.getCurrentDID()
            XCTAssertEqual(stale, bob, "The fixture must prove the selector cache is stale")
            let proof = try await storage.recordGatewaySessionFailure(
                ifMatches: "synthetic-token-\(bob)", for: bob, deleteMatchingSession: true
            )
            XCTAssertNil(proof)
            XCTAssertEqual(backend.peek(key: "gatewaySession.\(bob)", namespace: namespace),
                           Data("synthetic-token-\(bob)".utf8))
        }
    }

    func testFailureProofValidationBypassesStaleSelectorCache() async throws {
        let backend = InMemorySecureStorage()
        try await withFixture(backend) { client, storage, _, _ in
            let namespace = await storage.namespace
            let proof = try await storage.recordGatewaySessionFailure(
                ifMatches: "synthetic-token-\(bob)", for: bob, deleteMatchingSession: false
            )
            let value = try XCTUnwrap(proof)
            let current = await client.isCurrentGatewaySessionFailure(value)
            XCTAssertTrue(current)
            backend.plant(key: "currentDID", namespace: namespace, data: Data(alice.utf8))
            let stale = try await storage.getCurrentDID()
            XCTAssertEqual(stale, bob, "The fixture must prove the selector cache is stale")
            let afterExternalSwitch = await client.isCurrentGatewaySessionFailure(value)
            XCTAssertFalse(afterExternalSwitch)
            XCTAssertEqual(backend.peek(key: "gatewaySession.\(bob)", namespace: namespace),
                           Data("synthetic-token-\(bob)".utf8))
        }
    }

}
