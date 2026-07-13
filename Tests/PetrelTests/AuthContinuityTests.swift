import Foundation
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
        await storage.setAuthContinuityObserver {
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

private actor InterleavingContinuityProvider: AuthContinuityProviding {
    private var snapshot: AuthContinuitySnapshot
    private let gate: SnapshotInterleavingGate
    private var shouldPause = true
    private var observer: (@Sendable () async -> Void)?

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

    func replaceSnapshot(with replacement: AuthContinuitySnapshot) async {
        await observer?()
        snapshot = replacement
        await observer?()
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
