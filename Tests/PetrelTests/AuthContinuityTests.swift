import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import XCTest

final class AuthContinuityTests: XCTestCase {
    private let did = "did:plc:authcontinuity"
    private let gatewayURL = URL(string: "https://gateway.example")!

    private func makeClient(namespace: String) async throws -> (ATProtoClient, KeychainStorage) {
        let storage = KeychainStorage(namespace: namespace)
        let client = try await ATProtoClient(
            oauthConfig: OAuthConfig(
                clientId: "https://client.example/client-metadata.json",
                redirectUri: "blue.catbird:/oauth/callback",
                scope: "atproto"
            ),
            namespace: namespace,
            authMode: .gateway,
            gatewayURL: gatewayURL
        )
        return (client, storage)
    }

    private func install(
        session: String,
        storage: KeychainStorage,
        client: ATProtoClient
    ) async throws {
        let account = Account(
            did: did,
            handle: "continuity.example",
            pdsURL: gatewayURL
        )
        try await storage.saveAccount(account, for: did)
        try await storage.saveGatewaySession(session, for: did)
        try await client.switchToAccount(did: did)
    }

    func testLifecycleTransitions() async throws {
        let namespace = "test.auth-continuity.lifecycle.\(UUID().uuidString)"
        let (client, storage) = try await makeClient(namespace: namespace)

        let initial = await client.authContinuitySnapshot()
        XCTAssertNil(initial.did)
        XCTAssertEqual(initial.mode, .gateway)

        try await install(session: "gateway-session-one", storage: storage, client: client)
        let installed = await client.authContinuitySnapshot()
        XCTAssertEqual(installed.did, did)
        XCTAssertEqual(installed.mode, .gateway)
        XCTAssertGreaterThan(installed.generation, initial.generation)

        try await storage.saveGatewaySession("gateway-session-two", for: did)
        let replaced = await client.authContinuitySnapshot()
        XCTAssertEqual(replaced.did, did)
        XCTAssertGreaterThan(replaced.generation, installed.generation)

        try await storage.deleteGatewaySession(for: did)
        let cleared = await client.authContinuitySnapshot()
        XCTAssertNil(cleared.did)
        XCTAssertGreaterThan(cleared.generation, replaced.generation)

        try await storage.saveGatewaySession("gateway-session-three", for: did)
        let reinstalled = await client.authContinuitySnapshot()
        XCTAssertEqual(reinstalled.did, did)
        XCTAssertGreaterThan(reinstalled.generation, cleared.generation)

        try await client.logout()
        let loggedOut = await client.authContinuitySnapshot()
        XCTAssertNil(loggedOut.did)
        XCTAssertGreaterThan(loggedOut.generation, reinstalled.generation)

        try await client.switchAuthMode(.legacy)
        let switched = await client.authContinuitySnapshot()
        XCTAssertNil(switched.did)
        XCTAssertEqual(switched.mode, .legacy)
        XCTAssertGreaterThan(switched.generation, loggedOut.generation)
    }

    func testSnapshotIsNonSecret() async throws {
        let namespace = "test.auth-continuity.nonsecret.\(UUID().uuidString)"
        let (client, storage) = try await makeClient(namespace: namespace)
        let secret = "gateway-session-super-secret"
        try await install(session: secret, storage: storage, client: client)

        let snapshot = await client.authContinuitySnapshot()
        let mirror = Mirror(reflecting: snapshot)
        let labels = Set(mirror.children.compactMap(\.label))
        let renderedValues = mirror.children.map { String(describing: $0.value) }.joined(separator: "|")

        XCTAssertEqual(labels, ["did", "mode", "generation"])
        XCTAssertFalse(renderedValues.contains(secret))
        XCTAssertFalse(renderedValues.lowercased().contains("token"))
        XCTAssertFalse(renderedValues.lowercased().contains("key"))
    }

    func testConcurrentReadsAndUpdates() async throws {
        let namespace = "test.auth-continuity.concurrent.\(UUID().uuidString)"
        let (client, storage) = try await makeClient(namespace: namespace)
        try await install(session: "gateway-session-initial", storage: storage, client: client)
        let initial = await client.authContinuitySnapshot()
        let expectedDID = did

        let observed = await withTaskGroup(of: AuthContinuitySnapshot.self) { group in
            for index in 0 ..< 24 {
                group.addTask {
                    if index.isMultiple(of: 3) {
                        try? await storage.saveGatewaySession("gateway-session-\(index)", for: expectedDID)
                    }
                    return await client.authContinuitySnapshot()
                }
            }

            var snapshots: [AuthContinuitySnapshot] = []
            for await snapshot in group {
                snapshots.append(snapshot)
            }
            return snapshots
        }

        let final = await client.authContinuitySnapshot()
        XCTAssertEqual(final.did, did)
        XCTAssertGreaterThan(final.generation, initial.generation)
        XCTAssertTrue(observed.allSatisfy { $0.generation >= initial.generation })
        XCTAssertTrue(observed.allSatisfy { $0.mode == .gateway })
    }

    func testRefreshStyleReplacementInvalidates() async throws {
        let namespace = "test.auth-continuity.refresh.\(UUID().uuidString)"
        let (client, storage) = try await makeClient(namespace: namespace)
        try await install(session: "gateway-session-before-refresh", storage: storage, client: client)
        let before = await client.authContinuitySnapshot()

        // Persistence is a security boundary: even an equal-value rewrite must
        // advance continuity so an unobserved A→B→A sequence cannot compare equal.
        try await storage.saveGatewaySession("gateway-session-before-refresh", for: did)
        let sameSession = await client.authContinuitySnapshot()
        XCTAssertEqual(sameSession.did, before.did)
        XCTAssertGreaterThan(sameSession.generation, before.generation)

        // Models a future gateway refresh path replacing the opaque session while
        // retaining the same principal and ATProtoClient instance.
        try await storage.saveGatewaySession("gateway-session-after-refresh", for: did)
        let after = await client.authContinuitySnapshot()

        XCTAssertEqual(after.did, before.did)
        XCTAssertGreaterThan(after.generation, before.generation)
    }

    func testRoundTripStorageMutationsAdvancePublicGeneration() async throws {
        let namespace = "test.auth-continuity.round-trip.\(UUID().uuidString)"
        let (client, storage) = try await makeClient(namespace: namespace)
        try await install(session: "gateway-session-a", storage: storage, client: client)
        let beforeSessionRoundTrip = await client.authContinuitySnapshot()

        try await storage.saveGatewaySession("gateway-session-b", for: did)
        try await storage.saveGatewaySession("gateway-session-a", for: did)
        let afterSessionRoundTrip = await client.authContinuitySnapshot()

        XCTAssertEqual(afterSessionRoundTrip.did, beforeSessionRoundTrip.did)
        XCTAssertGreaterThan(afterSessionRoundTrip.generation, beforeSessionRoundTrip.generation)

        let otherDID = "did:plc:authcontinuity-other"
        try await storage.saveGatewaySession("gateway-session-other", for: otherDID)
        let beforeDIDRoundTrip = await client.authContinuitySnapshot()

        try await storage.saveCurrentDID(otherDID)
        try await storage.saveCurrentDID(did)
        let afterDIDRoundTrip = await client.authContinuitySnapshot()

        XCTAssertEqual(afterDIDRoundTrip.did, beforeDIDRoundTrip.did)
        XCTAssertGreaterThan(afterDIDRoundTrip.generation, beforeDIDRoundTrip.generation)
    }

    func testTerminalGatewayUnauthorizedClassification() throws {
        let gatewayRequest = URLRequest(url: gatewayURL.appendingPathComponent("xrpc/example"))
        let otherRequest = try URLRequest(url: XCTUnwrap(URL(string: "https://pds.example/xrpc/example")))
        let wrongPortRequest = try URLRequest(url: XCTUnwrap(URL(string: "https://gateway.example:8443/xrpc/example")))
        let wrongSchemeRequest = try URLRequest(url: XCTUnwrap(URL(string: "http://gateway.example/xrpc/example")))
        let terminal = Data(#"{"error":"invalid_session"}"#.utf8)
        let transient = Data(#"{"error":"temporarilyUnavailable"}"#.utf8)

        XCTAssertTrue(isTerminalGatewayUnauthorized(
            data: terminal,
            request: gatewayRequest,
            gatewayURL: gatewayURL
        ))
        XCTAssertFalse(isTerminalGatewayUnauthorized(
            data: transient,
            request: gatewayRequest,
            gatewayURL: gatewayURL
        ))
        XCTAssertFalse(isTerminalGatewayUnauthorized(
            data: terminal,
            request: otherRequest,
            gatewayURL: gatewayURL
        ))
        XCTAssertFalse(isTerminalGatewayUnauthorized(
            data: terminal,
            request: wrongPortRequest,
            gatewayURL: gatewayURL
        ))
        XCTAssertFalse(isTerminalGatewayUnauthorized(
            data: terminal,
            request: wrongSchemeRequest,
            gatewayURL: gatewayURL
        ))
    }

    func testUnauthorizedResponseContinuityWiring() async throws {
        let namespace = "test.auth-continuity.unauthorized.\(UUID().uuidString)"
        let storage = KeychainStorage(namespace: namespace)
        let account = Account(did: did, handle: "continuity.example", pdsURL: gatewayURL)
        let accountManager = MockAccountManager(account: account)
        try await storage.saveGatewaySession("gateway-session", for: did)
        let manager = try AuthManager(
            mode: .gateway,
            storage: storage,
            accountManager: accountManager,
            networkService: NetworkService(baseURL: gatewayURL),
            oauthConfig: OAuthConfig(
                clientId: "https://client.example/client-metadata.json",
                redirectUri: "blue.catbird:/oauth/callback",
                scope: "atproto"
            ),
            didResolver: MockDIDResolver(),
            gatewayBaseURL: gatewayURL
        )
        let requestURL = gatewayURL.appendingPathComponent("xrpc/example")
        let request = URLRequest(url: requestURL)
        let response = try XCTUnwrap(HTTPURLResponse(
            url: requestURL,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        ))

        let before = await manager.authContinuitySnapshot()
        let transient = Data(#"{"error":"temporarilyUnavailable"}"#.utf8)
        do {
            _ = try await manager.handleUnauthorizedResponse(response, data: transient, for: request)
            XCTFail("Expected transient gateway authentication error")
        } catch {
            XCTAssertTrue(error is ConfidentialGatewayStrategy.GatewayError)
        }
        let afterTransient = await manager.authContinuitySnapshot()
        XCTAssertEqual(afterTransient, before)

        let terminal = Data(#"{"error":"invalid_session"}"#.utf8)
        do {
            _ = try await manager.handleUnauthorizedResponse(response, data: terminal, for: request)
            XCTFail("Expected terminal gateway authentication error")
        } catch {
            XCTAssertTrue(error is ConfidentialGatewayStrategy.GatewayError)
        }
        let after = await manager.authContinuitySnapshot()
        XCTAssertNil(after.did)
        XCTAssertGreaterThan(after.generation, before.generation)
    }

    func testSwitchModeNeverAuthorizesNewModeUnderOldContinuity() async throws {
        let namespace = "test.auth-continuity.switch-mode-ordering.\(UUID().uuidString)"
        let storage = KeychainStorage(namespace: namespace)
        let network = NetworkService(baseURL: gatewayURL)
        let account = Account(did: did, handle: "continuity.example", pdsURL: gatewayURL)
        let manager = try AuthManager(
            mode: .gateway,
            storage: storage,
            accountManager: MockAccountManager(account: account),
            networkService: network,
            oauthConfig: OAuthConfig(
                clientId: "https://client.example/client-metadata.json",
                redirectUri: "blue.catbird:/oauth/callback",
                scope: "atproto"
            ),
            didResolver: MockDIDResolver(),
            gatewayBaseURL: gatewayURL
        )
        await network.setAuthenticationProvider(manager)
        let expectedValue = await network.authContinuitySnapshot()
        let expected = try XCTUnwrap(expectedValue)
        let probe = SwitchModeObserverProbe()

        // Replace NetworkService's observer with a deliberately re-entrant one.
        // If switchMode publishes the strategy/currentMode before committing the
        // continuity mode, its second notification can still authorize `expected`.
        await manager.installAuthContinuityObserver {
            let invocation = await probe.beginInvocation()
            guard invocation > 1 else { return }

            let exposedMode = await manager.currentMode
            let exposedSnapshot = await manager.authContinuitySnapshot()
            let transaction = await network.performWithExactAuthContinuity(matching: expected) {
                true
            }
            await probe.recordReentrantObservation(
                mode: exposedMode,
                snapshot: exposedSnapshot,
                transaction: transaction
            )
        }

        try await manager.switchMode(.legacy)

        let invocationCount = await probe.invocationCount
        let reentrantObservation = await probe.reentrantObservation
        XCTAssertEqual(invocationCount, 1)
        XCTAssertNil(reentrantObservation)
        let final = await manager.authContinuitySnapshot()
        let currentMode = await manager.currentMode
        XCTAssertEqual(final.mode, AuthMode.legacy)
        XCTAssertEqual(currentMode, AuthManager.Mode.legacy)
    }

    func testExactTransactionRejectsProviderWhilePreSignalIsPending() async throws {
        let namespace = "test.auth-continuity.pending-pre-signal.\(UUID().uuidString)"
        let storage = KeychainStorage(namespace: namespace)
        let network = NetworkService(baseURL: gatewayURL)
        let account = Account(did: did, handle: "continuity.example", pdsURL: gatewayURL)
        let manager = try AuthManager(
            mode: .gateway,
            storage: storage,
            accountManager: MockAccountManager(account: account),
            networkService: network,
            oauthConfig: OAuthConfig(
                clientId: "https://client.example/client-metadata.json",
                redirectUri: "blue.catbird:/oauth/callback",
                scope: "atproto"
            ),
            didResolver: MockDIDResolver(),
            gatewayBaseURL: gatewayURL
        )
        let gate = SnapshotInterleavingGate()
        let provider = HeldPreSignalContinuityProvider(provider: manager, gate: gate)
        await network.setAuthenticationProvider(provider)
        let beforeValue = await network.authContinuitySnapshot()
        let before = try XCTUnwrap(beforeValue)

        let switchTask = Task { try await manager.switchMode(.legacy) }
        await gate.waitUntilCaptured()

        // The observer has advanced NetworkService's revision, while the held
        // provider mutation has not yet changed its DID/mode/strategy state.
        let pendingValue = await network.authContinuitySnapshot()
        let pending = try XCTUnwrap(pendingValue)
        let callbackRan = LockedContinuityFlag()
        let transaction = await network.performWithExactAuthContinuity(matching: pending) {
            callbackRan.set()
            return true
        }

        await gate.releaseSnapshot()
        try await switchTask.value

        XCTAssertNotEqual(pending, before)
        XCTAssertEqual(pending.generation, UInt64.max)
        XCTAssertFalse(callbackRan.value)
        if case .performed = transaction {
            XCTFail("A pending provider mutation must never authorize a callback")
        }

        let afterValue = await network.authContinuitySnapshot()
        let after = try XCTUnwrap(afterValue)
        XCTAssertEqual(after.mode, .legacy)
        let stableTransaction = await network.performWithExactAuthContinuity(matching: after) { true }
        guard case let .performed(value) = stableTransaction else {
            return XCTFail("The completed mutation should expose a stable exact snapshot")
        }
        XCTAssertTrue(value)
    }

    func testOverlappingStorageMutationTicketsRemainPendingUntilAllComplete() async throws {
        let namespace = "test.auth-continuity.overlapping-storage.\(UUID().uuidString)"
        let storage = KeychainStorage(namespace: namespace)
        let network = NetworkService(baseURL: gatewayURL)
        let account = Account(did: did, handle: "continuity.example", pdsURL: gatewayURL)
        let manager = try AuthManager(
            mode: .gateway,
            storage: storage,
            accountManager: MockAccountManager(account: account),
            networkService: network,
            oauthConfig: OAuthConfig(
                clientId: "https://client.example/client-metadata.json",
                redirectUri: "blue.catbird:/oauth/callback",
                scope: "atproto"
            ),
            didResolver: MockDIDResolver(),
            gatewayBaseURL: gatewayURL
        )
        await network.setAuthenticationProvider(manager)
        _ = await network.authContinuitySnapshot()
        let first = UUID()
        let second = UUID()

        await manager.handleAuthContinuityStorageMutation(.willMutate(first))
        await manager.handleAuthContinuityStorageMutation(.willMutate(second))
        await manager.handleAuthContinuityStorageMutation(.didMutate(UUID()))
        await manager.handleAuthContinuityStorageMutation(.didMutate(first))

        let stillPendingValue = await network.authContinuitySnapshot()
        let stillPending = try XCTUnwrap(stillPendingValue)
        XCTAssertEqual(stillPending.generation, UInt64.max)
        let rejected = await network.performWithExactAuthContinuity(matching: stillPending) { true }
        if case .performed = rejected {
            XCTFail("Completing one ticket must not clear another pending mutation")
        }

        await manager.handleAuthContinuityStorageMutation(.didMutate(second))
        let stableValue = await network.authContinuitySnapshot()
        let stable = try XCTUnwrap(stableValue)
        XCTAssertNotEqual(stable.generation, UInt64.max)
        let accepted = await network.performWithExactAuthContinuity(matching: stable) { true }
        guard case let .performed(value) = accepted else {
            return XCTFail("Completing every ticket should restore stable snapshots")
        }
        XCTAssertTrue(value)
    }

    func testLateObserverInvalidatesOnUnknownStorageCompletion() async throws {
        let namespace = "test.auth-continuity.late-storage-observer.\(UUID().uuidString)"
        let storage = KeychainStorage(namespace: namespace)
        let account = Account(did: did, handle: "continuity.example", pdsURL: gatewayURL)
        try await storage.saveAccount(account, for: did)
        try await storage.saveCurrentDID(did)
        try await storage.saveGatewaySession("gateway-session-before-refresh", for: did)

        let network = NetworkService(baseURL: gatewayURL)
        let manager = try AuthManager(
            mode: .gateway,
            storage: storage,
            accountManager: MockAccountManager(account: account),
            networkService: network,
            oauthConfig: OAuthConfig(
                clientId: "https://client.example/client-metadata.json",
                redirectUri: "blue.catbird:/oauth/callback",
                scope: "atproto"
            ),
            didResolver: MockDIDResolver(),
            gatewayBaseURL: gatewayURL
        )
        await network.setAuthenticationProvider(manager)
        let beforeValue = await network.authContinuitySnapshot()
        let before = try XCTUnwrap(beforeValue)
        XCTAssertEqual(before.did, did)
        let callbackRan = LockedContinuityFlag()

        // Simulate joining the mutation hub after `.willMutate`: this manager
        // receives only the completion ticket for a same-DID session refresh.
        await manager.handleAuthContinuityStorageMutation(.didMutate(UUID()))
        let transaction = await network.performWithExactAuthContinuity(matching: before) {
            callbackRan.set()
            return true
        }

        XCTAssertFalse(callbackRan.value)
        if case .performed = transaction {
            XCTFail("An unknown storage completion must invalidate a late observer's lease")
        }
        let afterValue = await network.authContinuitySnapshot()
        let after = try XCTUnwrap(afterValue)
        XCTAssertGreaterThan(after.generation, before.generation)
    }

    func testObserverRegisteredMidWriteImmediatelySeesPendingTicket() async throws {
        let namespace = "test.auth-continuity.mid-write-registration.\(UUID().uuidString)"
        let mutationStorage = KeychainStorage(namespace: namespace)
        let account = Account(did: did, handle: "continuity.example", pdsURL: gatewayURL)
        try await mutationStorage.saveAccount(account, for: did)
        try await mutationStorage.saveCurrentDID(did)
        try await mutationStorage.saveGatewaySession("gateway-session-before-refresh", for: did)

        // Begin before this manager's storage instance installs its observer.
        let ticket = await mutationStorage.beginAuthContinuityMutationForTesting()
        let managerStorage = KeychainStorage(namespace: namespace)
        let network = NetworkService(baseURL: gatewayURL)
        let manager = try AuthManager(
            mode: .gateway,
            storage: managerStorage,
            accountManager: MockAccountManager(account: account),
            networkService: network,
            oauthConfig: OAuthConfig(
                clientId: "https://client.example/client-metadata.json",
                redirectUri: "blue.catbird:/oauth/callback",
                scope: "atproto"
            ),
            didResolver: MockDIDResolver(),
            gatewayBaseURL: gatewayURL
        )
        await network.setAuthenticationProvider(manager)

        let pendingValue = await network.authContinuitySnapshot()
        let pending = try XCTUnwrap(pendingValue)
        let callbackRan = LockedContinuityFlag()
        let transaction = await network.performWithExactAuthContinuity(matching: pending) {
            callbackRan.set()
            return true
        }
        await mutationStorage.endAuthContinuityMutationForTesting(ticket)

        XCTAssertEqual(pending.generation, UInt64.max)
        XCTAssertFalse(callbackRan.value)
        if case .performed = transaction {
            XCTFail("A manager registered mid-write must not authorize exact work")
        }
        let stableValue = await network.authContinuitySnapshot()
        let stable = try XCTUnwrap(stableValue)
        XCTAssertNotEqual(stable.generation, UInt64.max)
        let stableTransaction = await network.performWithExactAuthContinuity(matching: stable) { true }
        guard case let .performed(value) = stableTransaction else {
            return XCTFail("Completing the replayed ticket should restore stable snapshots")
        }
        XCTAssertTrue(value)
    }

    func testCompletionRacingObserverReplayPreservesWillBeforeDid() async throws {
        let namespace = "test.auth-continuity.replay-completion-race.\(UUID().uuidString)"
        let mutationStorage = KeychainStorage(namespace: namespace)
        let account = Account(did: did, handle: "continuity.example", pdsURL: gatewayURL)
        try await mutationStorage.saveAccount(account, for: did)
        try await mutationStorage.saveCurrentDID(did)
        try await mutationStorage.saveGatewaySession("gateway-session", for: did)
        let firstTicket = await mutationStorage.beginAuthContinuityMutationForTesting()
        let secondTicket = await mutationStorage.beginAuthContinuityMutationForTesting()

        let managerStorage = KeychainStorage(namespace: namespace)
        let network = NetworkService(baseURL: gatewayURL)
        let manager = try AuthManager(
            mode: .gateway,
            storage: managerStorage,
            accountManager: MockAccountManager(account: account),
            networkService: network,
            oauthConfig: OAuthConfig(
                clientId: "https://client.example/client-metadata.json",
                redirectUri: "blue.catbird:/oauth/callback",
                scope: "atproto"
            ),
            didResolver: MockDIDResolver(),
            gatewayBaseURL: gatewayURL
        )
        let gate = SnapshotInterleavingGate()
        let provider = HeldPreSignalContinuityProvider(provider: manager, gate: gate)
        let installationTask = Task { await network.setAuthenticationProvider(provider) }
        await gate.waitUntilCaptured()

        let completionFinished = DispatchSemaphore(value: 0)
        let completionTask = Task {
            await mutationStorage.endAuthContinuityMutationForTesting(secondTicket)
            completionFinished.signal()
        }
        let completedWhileReplayHeld = await waitForContinuitySemaphore(
            completionFinished,
            timeout: .now() + 0.05
        )

        await gate.releaseSnapshot()
        await installationTask.value
        await completionTask.value

        XCTAssertFalse(completedWhileReplayHeld)
        let stillPendingValue = await network.authContinuitySnapshot()
        let stillPending = try XCTUnwrap(stillPendingValue)
        XCTAssertEqual(stillPending.generation, UInt64.max)

        await mutationStorage.endAuthContinuityMutationForTesting(firstTicket)
        let stableValue = await network.authContinuitySnapshot()
        let stable = try XCTUnwrap(stableValue)
        XCTAssertNotEqual(stable.generation, UInt64.max)
        let transaction = await network.performWithExactAuthContinuity(matching: stable) { true }
        guard case let .performed(value) = transaction else {
            return XCTFail("Ordered replay completion must not leave a stale pending ticket")
        }
        XCTAssertTrue(value)
    }

    func testPendingSentinelCannotBecomeStableLeaseAtRevisionExhaustion() async throws {
        let network = NetworkService(baseURL: gatewayURL)
        let stable = AuthContinuitySnapshot(did: nil, mode: .gateway, generation: 7)
        let provider = ControllablePendingContinuityProvider(stableSnapshot: stable)
        await network.setAuthenticationProvider(provider)
        _ = await network.authContinuitySnapshot()
        await network.setAuthContinuityRevisionForTesting(.max - 1)

        await provider.beginPendingMutation()
        let pendingValue = await network.authContinuitySnapshot()
        let pending = try XCTUnwrap(pendingValue)
        XCTAssertEqual(pending.generation, UInt64.max)
        XCTAssertNil(pending.did)
        XCTAssertEqual(pending.mode, .gateway)

        // Complete to the exact same public DID/mode tuple. Only reserving .max
        // and marking the public clock exhausted can keep this from matching.
        await provider.completePendingMutation()

        let callbackRan = LockedContinuityFlag()
        let transaction = await network.performWithExactAuthContinuity(matching: pending) {
            callbackRan.set()
            return true
        }
        XCTAssertFalse(callbackRan.value)
        if case .performed = transaction {
            XCTFail("The reserved pending sentinel must never become a stable lease")
        }
        let exhaustedValue = await network.authContinuitySnapshot()
        let exhausted = try XCTUnwrap(exhaustedValue)
        XCTAssertEqual(exhausted.generation, UInt64.max)
        XCTAssertNil(exhausted.did)
    }

    func testGenerationExhaustionFailsClosed() {
        var state = AuthContinuityState(
            mode: .gateway,
            generation: .max,
            observedGatewayIdentity: .init(did: did, session: "secret")
        )

        state.invalidate()
        let first = state.snapshot
        state.invalidate()
        let second = state.snapshot

        XCTAssertEqual(first, AuthContinuitySnapshot(did: nil, mode: .gateway, generation: .max))
        XCTAssertEqual(second, first)
        XCTAssertTrue(state.isExhausted)
    }

    func testNetworkSnapshotRetriesWhenReplacementCompletesDuringProviderAwait() async {
        let gate = SnapshotInterleavingGate()
        let old = AuthContinuitySnapshot(did: did, mode: .gateway, generation: 7)
        let new = AuthContinuitySnapshot(
            did: "did:plc:authcontinuity-replacement",
            mode: .gateway,
            generation: 8
        )
        let provider = InterleavingContinuityProvider(snapshot: old, gate: gate)
        let network = NetworkService(baseURL: gatewayURL)
        await network.setAuthenticationProvider(provider)

        let result = await withTaskGroup(of: AuthContinuitySnapshot?.self) { group in
            group.addTask {
                await network.authContinuitySnapshot()
            }
            group.addTask {
                await gate.waitUntilCaptured()
                await provider.replaceSnapshot(with: new)
                await gate.releaseSnapshot()
                return nil
            }

            var observed: AuthContinuitySnapshot?
            for await value in group where value != nil {
                observed = value
            }
            return observed
        }

        XCTAssertEqual(result?.did, new.did)
        XCTAssertEqual(result?.mode, new.mode)
        XCTAssertGreaterThan(result?.generation ?? 0, 1)
    }

    func testNetworkSnapshotRetriesWhenProviderChangesDuringObserverInstall() async {
        let gate = SnapshotInterleavingGate()
        let old = AuthContinuitySnapshot(did: did, mode: .gateway, generation: 7)
        let new = AuthContinuitySnapshot(
            did: "did:plc:authcontinuity-replacement",
            mode: .gateway,
            generation: 8
        )
        let oldProvider = InstallInterleavingContinuityProvider(snapshot: old, installGate: gate)
        let newProvider = InstallInterleavingContinuityProvider(snapshot: new)
        let network = NetworkService(baseURL: gatewayURL, authService: oldProvider)

        let result = await withTaskGroup(of: AuthContinuitySnapshot?.self) { group in
            group.addTask {
                await network.authContinuitySnapshot()
            }
            group.addTask {
                await gate.waitUntilCaptured()
                await network.setAuthenticationProvider(newProvider)
                await gate.releaseSnapshot()
                return nil
            }

            var observed: AuthContinuitySnapshot?
            for await value in group where value != nil {
                observed = value
            }
            return observed
        }

        XCTAssertEqual(result?.did, new.did)
        XCTAssertEqual(result?.mode, new.mode)
        XCTAssertGreaterThan(result?.generation ?? 0, 0)
    }

    func testExactTransactionRejectsMutationAfterProviderSnapshot() async {
        let gate = SnapshotInterleavingGate()
        let old = AuthContinuitySnapshot(did: did, mode: .gateway, generation: 7)
        let new = AuthContinuitySnapshot(
            did: "did:plc:authcontinuity-mutated",
            mode: .gateway,
            generation: 8
        )
        let provider = InterleavingContinuityProvider(snapshot: old, gate: gate)
        let network = NetworkService(baseURL: gatewayURL)
        await network.setAuthenticationProvider(provider)
        let expected = AuthContinuitySnapshot(did: did, mode: .gateway, generation: 1)
        let callbackRan = LockedContinuityFlag()

        let transaction = Task {
            await network.performWithExactAuthContinuity(matching: expected) {
                callbackRan.set()
                return true
            }
        }
        await gate.waitUntilCaptured()
        let mutation = Task { await provider.replaceSnapshot(with: new) }
        await provider.waitUntilReplacementPreSignaled()
        await gate.releaseSnapshot()
        _ = await mutation.value

        switch await transaction.value {
        case .continuityChanged:
            break
        case .performed:
            XCTFail("A changed generation must not enter the callback")
        }
        XCTAssertFalse(callbackRan.value)
    }

    func testExactTransactionBlocksMutationUntilSynchronousCallbackReturns() async throws {
        let snapshot = AuthContinuitySnapshot(did: did, mode: .gateway, generation: 7)
        let provider = InstallInterleavingContinuityProvider(snapshot: snapshot)
        let network = NetworkService(baseURL: gatewayURL)
        await network.setAuthenticationProvider(provider)
        let expectedValue = await network.authContinuitySnapshot()
        let expected = try XCTUnwrap(expectedValue)
        let callbackEntered = DispatchSemaphore(value: 0)
        let releaseCallback = DispatchSemaphore(value: 0)
        let replacementStarted = DispatchSemaphore(value: 0)
        let mutationFinished = DispatchSemaphore(value: 0)

        let transaction = Task.detached {
            await network.performWithExactAuthContinuity(matching: expected) {
                callbackEntered.signal()
                releaseCallback.wait()
                return false
            }
        }
        _ = await waitForContinuitySemaphore(callbackEntered)
        let replacement = InstallInterleavingContinuityProvider(snapshot: snapshot)
        let replacementTask = Task.detached {
            replacementStarted.signal()
            await network.setAuthenticationProvider(replacement)
            mutationFinished.signal()
        }
        _ = await waitForContinuitySemaphore(replacementStarted)
        let changedWhileCallbackHeld = await waitForContinuitySemaphore(
            mutationFinished,
            timeout: .now() + 0.05
        )
        XCTAssertFalse(changedWhileCallbackHeld)
        releaseCallback.signal()

        switch await transaction.value {
        case let .performed(result):
            XCTAssertFalse(result)
        case .continuityChanged:
            XCTFail("The callback owned the continuity lease first")
        }
        _ = await waitForContinuitySemaphore(mutationFinished)
        _ = await replacementTask.value
        let stale = await network.performWithExactAuthContinuity(matching: expected) { true }
        if case .performed = stale {
            XCTFail("The old generation must fail after provider replacement")
        }
    }

    func testSettingSameProviderDoesNotReinstallContinuityObserver() async {
        let snapshot = AuthContinuitySnapshot(did: did, mode: .gateway, generation: 7)
        let provider = InstallInterleavingContinuityProvider(snapshot: snapshot)
        let network = NetworkService(baseURL: gatewayURL)

        await network.setAuthenticationProvider(provider)
        let before = await network.authContinuitySnapshot()
        await network.setAuthenticationProvider(provider)
        let after = await network.authContinuitySnapshot()

        let installCount = await provider.installCount
        XCTAssertEqual(installCount, 1)
        XCTAssertEqual(after, before)
    }

    func testProviderReplacementAdvancesPublicGenerationWhenSnapshotsMatch() async throws {
        let providerSnapshot = AuthContinuitySnapshot(did: did, mode: .gateway, generation: 7)
        let firstProvider = InstallInterleavingContinuityProvider(snapshot: providerSnapshot)
        let secondProvider = InstallInterleavingContinuityProvider(snapshot: providerSnapshot)
        let network = NetworkService(baseURL: gatewayURL)

        await network.setAuthenticationProvider(firstProvider)
        let beforeValue = await network.authContinuitySnapshot()
        let before = try XCTUnwrap(beforeValue)

        await network.setAuthenticationProvider(secondProvider)
        let afterValue = await network.authContinuitySnapshot()
        let after = try XCTUnwrap(afterValue)

        XCTAssertEqual(after.did, before.did)
        XCTAssertEqual(after.mode, before.mode)
        XCTAssertGreaterThan(after.generation, before.generation)
    }

    func testKeychainSecurityMutationsSignalBeforeAndAfterPersistence() async throws {
        let namespace = "test.auth-continuity.signals.\(UUID().uuidString)"
        let storage = KeychainStorage(namespace: namespace)
        let recorder = ContinuitySignalRecorder()
        await storage.setAuthContinuityObserver { _ in
            await recorder.record()
        }

        try await storage.saveCurrentDID(did)
        let afterCurrentDID = await recorder.count
        XCTAssertEqual(afterCurrentDID, 2)

        try await storage.saveGatewaySession("gateway-session", for: did)
        let afterSessionSave = await recorder.count
        XCTAssertEqual(afterSessionSave, 4)

        try await storage.deleteGatewaySession(for: did)
        let afterSessionDelete = await recorder.count
        XCTAssertEqual(afterSessionDelete, 6)
    }
}

private actor SnapshotInterleavingGate {
    private var didCapture = false
    private var captureWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func captureAndWaitForRelease() async {
        didCapture = true
        let waiters = captureWaiters
        captureWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func waitUntilCaptured() async {
        if didCapture { return }
        await withCheckedContinuation { continuation in
            captureWaiters.append(continuation)
        }
    }

    func releaseSnapshot() {
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

private actor ContinuitySignalRecorder {
    private(set) var count = 0

    func record() {
        count += 1
    }
}

private actor SwitchModeObserverProbe {
    struct Observation {
        let mode: AuthManager.Mode
        let snapshot: AuthContinuitySnapshot
        let transactionWasAuthorized: Bool
    }

    private(set) var invocationCount = 0
    private(set) var reentrantObservation: Observation?

    func beginInvocation() -> Int {
        invocationCount += 1
        return invocationCount
    }

    func recordReentrantObservation(
        mode: AuthManager.Mode,
        snapshot: AuthContinuitySnapshot,
        transaction: AuthContinuityTransactionResult<Bool>
    ) {
        let transactionWasAuthorized = switch transaction {
        case let .performed(value): value
        case .continuityChanged: false
        }
        reentrantObservation = Observation(
            mode: mode,
            snapshot: snapshot,
            transactionWasAuthorized: transactionWasAuthorized
        )
    }
}

private final class LockedContinuityFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false

    var value: Bool {
        lock.withLock { flag }
    }

    func set() {
        lock.withLock { flag = true }
    }
}

private func waitForContinuitySemaphore(
    _ semaphore: DispatchSemaphore,
    timeout: DispatchTime? = nil
) async -> Bool {
    await withCheckedContinuation { continuation in
        DispatchQueue.global().async {
            let result: DispatchTimeoutResult
            if let timeout {
                result = semaphore.wait(timeout: timeout)
            } else {
                semaphore.wait()
                result = .success
            }
            continuation.resume(returning: result == .success)
        }
    }
}

private actor InterleavingContinuityProvider: AuthContinuityProviding {
    private var snapshot: AuthContinuitySnapshot
    private let gate: SnapshotInterleavingGate
    private var shouldPause = true
    private var observer: (@Sendable () async -> Void)?
    private var replacementWasPreSignaled = false
    private var replacementPreSignaledContinuation: CheckedContinuation<Void, Never>?

    init(snapshot: AuthContinuitySnapshot, gate: SnapshotInterleavingGate) {
        self.snapshot = snapshot
        self.gate = gate
    }

    func installAuthContinuityObserver(_ observer: @escaping @Sendable () async -> Void) async {
        self.observer = observer
    }

    func authContinuitySnapshot() async -> AuthContinuitySnapshot {
        let captured = snapshot
        if shouldPause {
            shouldPause = false
            await gate.captureAndWaitForRelease()
        }
        return captured
    }

    func authContinuityProviderSnapshot() async -> AuthContinuityProviderSnapshot {
        .stable(await authContinuitySnapshot())
    }

    func replaceSnapshot(with replacement: AuthContinuitySnapshot) async {
        await observer?()
        replacementWasPreSignaled = true
        replacementPreSignaledContinuation?.resume()
        replacementPreSignaledContinuation = nil
        snapshot = replacement
        await observer?()
    }

    func waitUntilReplacementPreSignaled() async {
        guard !replacementWasPreSignaled else { return }
        await withCheckedContinuation { continuation in
            replacementPreSignaledContinuation = continuation
        }
    }

    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        request
    }

    func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (URLRequest, AuthContext) {
        (request, AuthContext(did: nil, jkt: nil))
    }

    func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
        .stillValid
    }

    func handleUnauthorizedResponse(
        _ response: HTTPURLResponse,
        data: Data,
        for _: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        (data, response)
    }

    func updateDPoPNonce(for _: URL, from _: [String: String], did _: String?, jkt _: String?) async {}
}

private actor InstallInterleavingContinuityProvider: AuthContinuityProviding {
    private let snapshot: AuthContinuitySnapshot
    private let installGate: SnapshotInterleavingGate?
    private(set) var installCount = 0

    init(snapshot: AuthContinuitySnapshot, installGate: SnapshotInterleavingGate? = nil) {
        self.snapshot = snapshot
        self.installGate = installGate
    }

    func installAuthContinuityObserver(_: @escaping @Sendable () async -> Void) async {
        installCount += 1
        if let installGate {
            await installGate.captureAndWaitForRelease()
        }
    }

    func authContinuitySnapshot() async -> AuthContinuitySnapshot {
        snapshot
    }

    func authContinuityProviderSnapshot() async -> AuthContinuityProviderSnapshot {
        .stable(snapshot)
    }

    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        request
    }

    func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (URLRequest, AuthContext) {
        (request, AuthContext(did: nil, jkt: nil))
    }

    func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
        .stillValid
    }

    func handleUnauthorizedResponse(
        _ response: HTTPURLResponse,
        data: Data,
        for _: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        (data, response)
    }

    func updateDPoPNonce(for _: URL, from _: [String: String], did _: String?, jkt _: String?) async {}
}

private actor HeldPreSignalContinuityProvider: AuthContinuityProviding {
    private let provider: any AuthContinuityProviding
    private let gate: SnapshotInterleavingGate
    private var hasHeldSignal = false

    init(provider: any AuthContinuityProviding, gate: SnapshotInterleavingGate) {
        self.provider = provider
        self.gate = gate
    }

    func installAuthContinuityObserver(_ observer: @escaping @Sendable () async -> Void) async {
        await provider.installAuthContinuityObserver { [weak self] in
            await observer()
            await self?.holdFirstSignal()
        }
    }

    private func holdFirstSignal() async {
        guard !hasHeldSignal else { return }
        hasHeldSignal = true
        await gate.captureAndWaitForRelease()
    }

    func authContinuitySnapshot() async -> AuthContinuitySnapshot {
        await provider.authContinuitySnapshot()
    }

    func authContinuityProviderSnapshot() async -> AuthContinuityProviderSnapshot {
        await provider.authContinuityProviderSnapshot()
    }

    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        try await provider.prepareAuthenticatedRequest(request)
    }

    func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (URLRequest, AuthContext) {
        try await provider.prepareAuthenticatedRequestWithContext(request)
    }

    func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
        try await provider.refreshTokenIfNeeded()
    }

    func handleUnauthorizedResponse(
        _ response: HTTPURLResponse,
        data: Data,
        for request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        try await provider.handleUnauthorizedResponse(response, data: data, for: request)
    }

    func updateDPoPNonce(for url: URL, from headers: [String: String], did: String?, jkt: String?) async {
        await provider.updateDPoPNonce(for: url, from: headers, did: did, jkt: jkt)
    }
}

private actor ControllablePendingContinuityProvider: AuthContinuityProviding {
    private let stableSnapshot: AuthContinuitySnapshot
    private var isPending = false
    private var observer: (@Sendable () async -> Void)?

    init(stableSnapshot: AuthContinuitySnapshot) {
        self.stableSnapshot = stableSnapshot
    }

    func installAuthContinuityObserver(_ observer: @escaping @Sendable () async -> Void) async {
        self.observer = observer
    }

    func beginPendingMutation() async {
        isPending = true
        await observer?()
    }

    func completePendingMutation() {
        isPending = false
    }

    func authContinuitySnapshot() async -> AuthContinuitySnapshot {
        stableSnapshot
    }

    func authContinuityProviderSnapshot() async -> AuthContinuityProviderSnapshot {
        if isPending {
            return .mutationPending(mode: stableSnapshot.mode)
        }
        return .stable(stableSnapshot)
    }

    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        request
    }

    func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (URLRequest, AuthContext) {
        (request, AuthContext(did: nil, jkt: nil))
    }

    func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
        .stillValid
    }

    func handleUnauthorizedResponse(
        _ response: HTTPURLResponse,
        data: Data,
        for _: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        (data, response)
    }

    func updateDPoPNonce(for _: URL, from _: [String: String], did _: String?, jkt _: String?) async {}
}
