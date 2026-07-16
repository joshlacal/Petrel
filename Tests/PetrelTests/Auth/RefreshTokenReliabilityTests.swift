#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Synchronization
import Testing

// MARK: - Test Doubles

/// In-memory SecureStorage with scriptable failures, for exercising the
/// refresh-persistence paths without touching the real keychain.
final class InMemorySecureStorage: SecureStorage, @unchecked Sendable {
    enum Operation {
        case retrieve
        case delete
    }

    private let lock = NSLock()
    private var items: [String: Data] = [:]
    private var operationObserver: (@Sendable (Operation, String) -> Void)?

    /// Fail the next N store calls (any key), then succeed.
    var storeFailuresRemaining = 0
    /// Fail store calls whose (un-namespaced) key matches this predicate.
    var failStoreMatching: (@Sendable (String) -> Bool)?

    private func fullKey(_ key: String, _ namespace: String) -> String {
        "\(namespace)|\(key)"
    }

    func store(key: String, value: Data, namespace: String, accessGroup _: String?) throws {
        lock.lock()
        defer { lock.unlock() }
        if let matcher = failStoreMatching, matcher(key) {
            throw KeychainError.itemStoreError(status: -1)
        }
        if storeFailuresRemaining > 0 {
            storeFailuresRemaining -= 1
            throw KeychainError.itemStoreError(status: -1)
        }
        items[fullKey(key, namespace)] = value
    }

    func retrieve(key: String, namespace: String, accessGroup _: String?) throws -> Data {
        lock.lock()
        let data = items[fullKey(key, namespace)]
        let observer = operationObserver
        lock.unlock()
        observer?(.retrieve, key)
        guard let data else {
            throw KeychainError.itemRetrievalError(status: -25300)
        }
        return data
    }

    func delete(key: String, namespace: String, accessGroup _: String?) throws {
        lock.lock()
        items.removeValue(forKey: fullKey(key, namespace))
        let observer = operationObserver
        lock.unlock()
        observer?(.delete, key)
    }

    func deleteAll(namespace: String, accessGroup _: String?) throws {
        lock.lock()
        defer { lock.unlock() }
        items = items.filter { !$0.key.hasPrefix("\(namespace)|") }
    }

    func storeDPoPKey(_: P256.Signing.PrivateKey, keyTag _: String, accessGroup _: String?) throws {}

    func retrieveDPoPKey(keyTag _: String, accessGroup _: String?) throws -> P256.Signing.PrivateKey {
        throw KeychainError.itemRetrievalError(status: -25300)
    }

    func deleteDPoPKey(keyTag _: String, accessGroup _: String?) throws {}

    /// Plants raw bytes at a storage key, bypassing validation — used to simulate
    /// corrupted keychain entries.
    func plant(key: String, namespace: String, data: Data) {
        lock.lock()
        defer { lock.unlock() }
        items[fullKey(key, namespace)] = data
    }

    func setOperationObserver(_ observer: (@Sendable (Operation, String) -> Void)?) {
        lock.lock()
        defer { lock.unlock() }
        operationObserver = observer
    }
}

/// Minimal AccountManaging mock: one fixed account, no side effects.
actor MockAccountManager: AccountManaging {
    private let account: Account

    init(account: Account) {
        self.account = account
    }

    func addAccount(_: Account) async throws {}
    func getAccount(did: String) async -> Account? {
        did == account.did ? account : nil
    }

    func updateAccountFromStorage(did _: String) async throws {}
    func removeAccount(did _: String) async throws {}
    func setCurrentAccount(did _: String) async throws {}
    func getCurrentAccount() async -> Account? {
        account
    }

    func listAccounts() async -> [Account] {
        [account]
    }

    func clearCurrentAccount() async {}
    func updateServiceDIDs(bskyAppViewDID _: String, bskyChatDID _: String) async throws {}
}

final class MockDIDResolver: DIDResolving, @unchecked Sendable {
    func resolveHandleToDID(handle _: String) async throws -> String {
        "did:plc:test"
    }

    func resolveDIDToPDSURL(did _: String) async throws -> URL {
        URL(string: "https://pds.test")!
    }

    func resolveDIDToHandleAndPDSURL(did _: String) async throws -> (String, URL) {
        ("test.example", URL(string: "https://pds.test")!)
    }
}

private final class AsyncLatch: @unchecked Sendable {
    private let lock = NSLock()
    private var signaled = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func signal() {
        lock.lock()
        guard !signaled else {
            lock.unlock()
            return
        }
        signaled = true
        let currentWaiters = waiters
        waiters.removeAll()
        lock.unlock()
        currentWaiters.forEach { $0.resume() }
    }

    func wait() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if signaled {
                lock.unlock()
                continuation.resume()
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }
}

private final class RefreshStorageObserver: @unchecked Sendable {
    let refreshCleared = AsyncLatch()
    let postClearSessionLookup = AsyncLatch()

    private let lock = NSLock()
    private let did: String
    private var didClearRefresh = false

    init(did: String) {
        self.did = did
    }

    func observe(_ operation: InMemorySecureStorage.Operation, key: String) {
        let signals = lock.withLock { () -> (refreshCleared: Bool, sessionLookup: Bool) in
            switch operation {
            case .delete where key == "refresh.inProgress.\(did)":
                didClearRefresh = true
                return (true, false)
            case .retrieve where didClearRefresh && key == "session.pending.\(did)":
                return (false, true)
            default:
                return (false, false)
            }
        }
        if signals.refreshCleared {
            refreshCleared.signal()
        }
        if signals.sessionLookup {
            postClearSessionLookup.signal()
        }
    }
}

private actor AuthenticationRefreshTransport {
    enum Response {
        case invalidGrant
        case serverFailure
        case unauthorized
        case refreshSuccess
        case conflict
    }

    private let responses: [Response]
    private var requestCount = 0
    private var requestWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private var releasePermits = 0
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    init(responses: [Response]) {
        self.responses = responses
    }

    func waitForRequestCount(_ count: Int) async {
        guard requestCount < count else { return }
        await withCheckedContinuation { continuation in
            requestWaiters.append((count, continuation))
        }
    }

    func releaseNextRequest() {
        if let continuation = releaseWaiters.first {
            releaseWaiters.removeFirst()
            continuation.resume()
        } else {
            releasePermits += 1
        }
    }

    func observedRequestCount() -> Int {
        requestCount
    }

    func handle(_ box: AuthenticationRefreshURLProtocolBox) async {
        let responseIndex = requestCount
        requestCount += 1
        let readyWaiters = requestWaiters.filter { requestCount >= $0.count }
        requestWaiters.removeAll { requestCount >= $0.count }
        readyWaiters.forEach { $0.continuation.resume() }

        if releasePermits > 0 {
            releasePermits -= 1
        } else {
            await withCheckedContinuation { releaseWaiters.append($0) }
        }

        guard !Task.isCancelled else { return }
        guard responseIndex < responses.count else {
            box.protocolInstance.client?.urlProtocol(
                box.protocolInstance,
                didFailWithError: URLError(.badServerResponse)
            )
            return
        }

        switch responses[responseIndex] {
        case .invalidGrant:
            let response = HTTPURLResponse(
                url: box.request.url!,
                statusCode: 400,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(#"{"error":"invalid_grant","error_description":"refresh token rejected"}"#.utf8)
            box.protocolInstance.client?.urlProtocol(
                box.protocolInstance,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            box.protocolInstance.client?.urlProtocol(box.protocolInstance, didLoad: data)
            box.protocolInstance.client?.urlProtocolDidFinishLoading(box.protocolInstance)
        case .serverFailure:
            let response = HTTPURLResponse(
                url: box.request.url!,
                statusCode: 400,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = Data(#"{"error":"temporarily_unavailable","error_description":"refresh unavailable"}"#.utf8)
            box.protocolInstance.client?.urlProtocol(
                box.protocolInstance,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            box.protocolInstance.client?.urlProtocol(box.protocolInstance, didLoad: data)
            box.protocolInstance.client?.urlProtocolDidFinishLoading(box.protocolInstance)
        case .unauthorized:
            respond(
                to: box,
                statusCode: 401,
                data: Data(#"{"error":"ExpiredToken"}"#.utf8)
            )
        case .refreshSuccess:
            respond(
                to: box,
                statusCode: 200,
                data: Data(
                    #"{"accessJwt":"access-refreshed","refreshJwt":"refresh-refreshed","handle":"test.example","did":"did:plc:refreshreliability"}"#.utf8
                )
            )
        case .conflict:
            respond(
                to: box,
                statusCode: 409,
                data: Data(#"{"error":"DestinationExists"}"#.utf8)
            )
        }
    }

    private func respond(
        to box: AuthenticationRefreshURLProtocolBox,
        statusCode: Int,
        data: Data
    ) {
        let response = HTTPURLResponse(
            url: box.request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        box.protocolInstance.client?.urlProtocol(
            box.protocolInstance,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        box.protocolInstance.client?.urlProtocol(box.protocolInstance, didLoad: data)
        box.protocolInstance.client?.urlProtocolDidFinishLoading(box.protocolInstance)
    }
}

private final class AuthenticationRefreshURLProtocol: URLProtocol {
    struct Installation {
        let host: String
        let transport: AuthenticationRefreshTransport
    }

    private static let installation = Mutex<Installation?>(nil)
    private var loadingTask: Task<Void, Never>?

    static func install(host: String, transport: AuthenticationRefreshTransport) {
        installation.withLock { $0 = Installation(host: host, transport: transport) }
    }

    static func uninstall() {
        installation.withLock { $0 = nil }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        installation.withLock { $0?.host == request.url?.host }
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let transport = Self.installation.withLock({ $0?.transport }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let box = AuthenticationRefreshURLProtocolBox(protocolInstance: self, request: request)
        loadingTask = Task {
            await transport.handle(box)
        }
    }

    override func stopLoading() {
        loadingTask?.cancel()
        loadingTask = nil
    }
}

private final class AuthenticationRefreshURLProtocolBox: @unchecked Sendable {
    let protocolInstance: AuthenticationRefreshURLProtocol
    let request: URLRequest

    init(protocolInstance: AuthenticationRefreshURLProtocol, request: URLRequest) {
        self.protocolInstance = protocolInstance
        self.request = request
    }
}

// MARK: - Fixtures

private let testDID = "did:plc:refreshreliability"

private func makeAccount() -> Account {
    Account(did: testDID, handle: "test.example", pdsURL: URL(string: "https://pds.test")!)
}

private func makeSession(
    refreshToken: String,
    createdAt: Date = Date(),
    expiresIn: TimeInterval = 3600,
    tokenType: TokenType = .dpop
) -> Session {
    Session(
        accessToken: "access-\(refreshToken)",
        refreshToken: refreshToken,
        createdAt: createdAt,
        expiresIn: expiresIn,
        tokenType: tokenType,
        did: testDID
    )
}

private func makeCore(storage: KeychainStorage) async -> OAuthCore {
    let config = OAuthConfig(
        clientId: "test-client",
        redirectUri: "test://callback",
        scope: "atproto"
    )
    return OAuthCore(
        storage: storage,
        accountManager: MockAccountManager(account: makeAccount()),
        networkService: NetworkService(baseURL: URL(string: "https://pds.test")!),
        oauthConfig: config,
        didResolver: MockDIDResolver()
    )
}

private func makeAuthenticationService(
    storage: KeychainStorage,
    transport: AuthenticationRefreshTransport,
    host: String
) -> AuthenticationService {
    makeAuthenticationServiceFixture(
        storage: storage,
        transport: transport,
        host: host
    ).service
}

private func makeAuthenticationServiceFixture(
    storage: KeychainStorage,
    transport: AuthenticationRefreshTransport,
    host: String
) -> (service: AuthenticationService, networkService: NetworkService) {
    let account = Account(
        did: testDID,
        handle: "test.example",
        pdsURL: URL(string: "https://\(host)")!
    )
    NetworkService.setNetworkTestProtocolClasses([AuthenticationRefreshURLProtocol.self])
    let networkService = NetworkService(baseURL: account.pdsURL)
    AuthenticationRefreshURLProtocol.install(host: host, transport: transport)
    let service = AuthenticationService(
        storage: storage,
        accountManager: MockAccountManager(account: account),
        networkService: networkService,
        oauthConfig: OAuthConfig(
            clientId: "test-client",
            redirectUri: "test://callback",
            scope: "atproto"
        ),
        didResolver: MockDIDResolver()
    )
    return (service, networkService)
}

/// Runs `body` with an injected in-memory storage backend, always restoring the
/// platform default afterwards.
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

// MARK: - Tests

@Suite("Refresh token reliability", .serialized)
struct RefreshTokenReliabilityTests {
    @Test("Named HTTP error path survives AuthenticationService 401 refresh retry")
    func namedHTTPErrorPathSurvivesAuthenticationServiceRetry() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let host = "typed-error-auth-\(UUID().uuidString.lowercased()).example"
            let storage = KeychainStorage(
                namespace: "test.refresh.authentication.typed-error"
            )
            let session = makeSession(
                refreshToken: "refresh-original",
                tokenType: .bearer
            )
            let transport = AuthenticationRefreshTransport(
                responses: [.unauthorized, .refreshSuccess, .conflict]
            )
            defer {
                AuthenticationRefreshURLProtocol.uninstall()
                NetworkService.setNetworkTestProtocolClasses(nil)
            }

            try await storage.saveAccountAndSession(
                makeAccount(),
                session: session,
                for: testDID
            )
            let fixture = makeAuthenticationServiceFixture(
                storage: storage,
                transport: transport,
                host: host
            )
            await fixture.networkService.setAuthenticationProvider(fixture.service)
            let request = URLRequest(
                url: URL(string: "https://\(host)/xrpc/blue.moji.test")!
            )
            let operation = Task {
                try await fixture.networkService
                    .performRequestReturningHTTPErrorResponses(
                        request,
                        skipTokenRefresh: false
                    )
            }

            for requestCount in 1 ... 3 {
                await transport.waitForRequestCount(requestCount)
                await transport.releaseNextRequest()
            }

            let (data, response) = try await operation.value
            let storedSession = try await storage.getSession(for: testDID)
            let requestCount = await transport.observedRequestCount()
            #expect(response.statusCode == 409)
            #expect(
                String(decoding: data, as: UTF8.self) ==
                    #"{"error":"DestinationExists"}"#
            )
            #expect(storedSession?.accessToken == "access-refreshed")
            #expect(requestCount == 3)
        }
    }

    @Test("AuthenticationService propagates refresh task failures")
    func authenticationServicePropagatesRefreshTaskFailure() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let host = "refresh-failure-\(UUID().uuidString.lowercased()).example"
            let namespace = "test.refresh.authentication.failure"
            let storage = KeychainStorage(namespace: namespace)
            let session = makeSession(refreshToken: "rt-auth-failure", tokenType: .bearer)
            let transport = AuthenticationRefreshTransport(responses: [.serverFailure])
            let storageObserver = RefreshStorageObserver(did: testDID)
            backend.setOperationObserver { operation, key in
                storageObserver.observe(operation, key: key)
            }
            defer {
                backend.setOperationObserver(nil)
                AuthenticationRefreshURLProtocol.uninstall()
                NetworkService.setNetworkTestProtocolClasses(nil)
            }

            try await storage.saveAccountAndSession(makeAccount(), session: session, for: testDID)
            let service = makeAuthenticationService(storage: storage, transport: transport, host: host)
            let refresh = Task {
                try await service.refreshTokenIfNeeded(forceRefresh: true)
            }

            await transport.waitForRequestCount(1)
            await transport.releaseNextRequest()
            let result = await refresh.result
            await storageObserver.refreshCleared.wait()

            switch result {
            case let .success(unexpectedResult):
                Issue.record("Refresh failure returned early as \(unexpectedResult) instead of throwing")
            case let .failure(error):
                #expect(error as? AuthError == .tokenRefreshFailed)
            }
        }
    }

    @Test("AuthenticationService returns the completed refresh task result")
    func authenticationServiceReturnsCompletedRefreshTaskResult() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let host = "refresh-result-\(UUID().uuidString.lowercased()).example"
            let namespace = "test.refresh.authentication.result"
            let storage = KeychainStorage(namespace: namespace)
            let session = makeSession(refreshToken: "rt-auth-result", tokenType: .bearer)
            let transport = AuthenticationRefreshTransport(responses: [.invalidGrant])
            let storageObserver = RefreshStorageObserver(did: testDID)
            backend.setOperationObserver { operation, key in
                storageObserver.observe(operation, key: key)
            }
            defer {
                backend.setOperationObserver(nil)
                AuthenticationRefreshURLProtocol.uninstall()
                NetworkService.setNetworkTestProtocolClasses(nil)
            }

            try await storage.saveAccountAndSession(makeAccount(), session: session, for: testDID)
            let service = makeAuthenticationService(storage: storage, transport: transport, host: host)
            let refresh = Task {
                try await service.refreshTokenIfNeeded(forceRefresh: true)
            }

            await transport.waitForRequestCount(1)
            KeychainManager.clearCache()
            await transport.releaseNextRequest()
            let result = try await refresh.value
            await storageObserver.refreshCleared.wait()
            await storageObserver.postClearSessionLookup.wait()

            #expect(result == .stillValid, "Refresh did not preserve the task's transient-safe result")
        }
    }

    /// The core "expires early" regression: a refresh that fails for transient
    /// reasons (timeout, offline, 5xx) must not permanently poison the refresh
    /// token in-process.
    @Test("Transient refresh failure does not burn the refresh token")
    func transientFailureDoesNotBurnToken() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let storage = KeychainStorage(namespace: "test.refresh.transient")
            let core = await makeCore(storage: storage)
            let account = makeAccount()
            let session = makeSession(refreshToken: "rt-transient")
            try await storage.saveAccountAndSession(account, session: session, for: testDID)

            let callCount = Mutex(0)
            await core.setPerformActualRefresh { _, _ in
                let attempt = callCount.withLock { $0 += 1; return $0 }
                if attempt == 1 {
                    throw AuthError.networkError(NetworkError.requestFailed)
                }
                return .refreshedSuccessfully
            }

            // First attempt fails transiently.
            await #expect(throws: AuthError.self) {
                try await core.refreshTokenIfNeeded(forceRefresh: true)
            }

            // Second attempt must reach the refresh implementation again with the
            // same token — before the fix it threw tokenRefreshFailed immediately.
            let result = try await core.refreshTokenIfNeeded(forceRefresh: true)
            #expect(result == .refreshedSuccessfully)
            #expect(callCount.withLock { $0 } == 2, "Refresh implementation should be retried after a transient failure")
        }
    }

    @Test("Definitive invalid_grant burns the refresh token")
    func invalidGrantBurnsToken() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let storage = KeychainStorage(namespace: "test.refresh.invalidgrant")
            let core = await makeCore(storage: storage)
            let account = makeAccount()
            let session = makeSession(refreshToken: "rt-burned")
            try await storage.saveAccountAndSession(account, session: session, for: testDID)

            let callCount = Mutex(0)
            await core.setPerformActualRefresh { _, _ in
                callCount.withLock { $0 += 1 }
                throw AuthError.invalidCredentials
            }

            await #expect(throws: AuthError.self) {
                try await core.refreshTokenIfNeeded(forceRefresh: true)
            }

            // Replay of a definitively-rejected token must be refused without
            // another network attempt.
            await #expect(throws: AuthError.self) {
                try await core.refreshTokenIfNeeded(forceRefresh: true)
            }
            #expect(callCount.withLock { $0 } == 1, "A definitively rejected token must not be retried")
        }
    }

    /// The rotation-loss bug: server rotates the (single-use) refresh token, then the
    /// keychain write fails. The new session must survive in memory and via the
    /// pending key, and be promoted on the next read.
    @Test("Keychain write failure after refresh preserves the rotated session")
    func keychainWriteFailurePreservesRotatedSession() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let storage = KeychainStorage(namespace: "test.refresh.persistfail")
            let core = await makeCore(storage: storage)
            let account = makeAccount()
            let oldSession = makeSession(refreshToken: "rt-old", createdAt: Date(timeIntervalSinceNow: -600))
            try await storage.saveAccountAndSession(account, session: oldSession, for: testDID)

            // Fail every session write except the single-write pending key.
            backend.failStoreMatching = { key in
                key.contains("session") && !key.contains("session.pending")
            }

            let newSession = makeSession(refreshToken: "rt-new")
            await core.persistRefreshedSession(newSession, for: account)

            // The running process must see the new session immediately.
            let current = await core.currentSession(for: testDID)
            #expect(current?.refreshToken == "rt-new", "In-memory session must reflect the rotated token")

            // Keychain recovers (e.g. device unlocked): the pending copy must win
            // over the stale primary and be promoted.
            backend.failStoreMatching = nil
            let recovered = try await storage.getSession(for: testDID)
            #expect(recovered?.refreshToken == "rt-new", "Pending session must be promoted over the stale primary")

            let promoted = try await storage.getSession(for: testDID)
            #expect(promoted?.refreshToken == "rt-new")
        }
    }

    @Test("Stale write cannot overwrite a newer stored session")
    func staleWriteIsRefused() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let storage = KeychainStorage(namespace: "test.refresh.stalewrite")
            let account = makeAccount()
            let newer = makeSession(refreshToken: "rt-newer", createdAt: Date())
            let older = makeSession(refreshToken: "rt-older", createdAt: Date(timeIntervalSinceNow: -3600))

            try await storage.saveAccountAndSession(account, session: newer, for: testDID)
            // Both save paths must refuse the stale overwrite.
            try await storage.saveSession(older, for: testDID)
            try await storage.saveAccountAndSession(account, session: older, for: testDID)

            let stored = try await storage.getSession(for: testDID)
            #expect(stored?.refreshToken == "rt-newer", "Newest session must win over interleaved stale writes")
        }
    }

    @Test("Concurrent saves converge on the newest session")
    func concurrentSavesConverge() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let storage = KeychainStorage(namespace: "test.refresh.concurrent")
            let account = makeAccount()
            let base = Date()
            let sessions = (0 ..< 8).map { i in
                makeSession(refreshToken: "rt-\(i)", createdAt: base.addingTimeInterval(TimeInterval(i)))
            }

            try await withThrowingTaskGroup(of: Void.self) { group in
                for (index, session) in sessions.enumerated().shuffled() {
                    group.addTask {
                        if index % 2 == 0 {
                            try await storage.saveAccountAndSession(account, session: session, for: testDID)
                        } else {
                            try await storage.saveSession(session, for: testDID)
                        }
                    }
                }
                try await group.waitForAll()
            }

            let stored = try await storage.getSession(for: testDID)
            #expect(stored?.refreshToken == "rt-7", "After arbitrary interleaving the newest session must be stored")
        }
    }

    @Test("Stale backup cannot resurrect an old session")
    func staleBackupDoesNotResurrect() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let namespace = "test.refresh.backup"
            let storage = KeychainStorage(namespace: namespace)
            let account = makeAccount()
            let newer = makeSession(refreshToken: "rt-current", createdAt: Date())
            let older = makeSession(refreshToken: "rt-rotated-away", createdAt: Date(timeIntervalSinceNow: -3600))

            try await storage.saveAccountAndSession(account, session: newer, for: testDID)
            // Orphaned backup from a crashed earlier save.
            try await storage.saveSessionBackup(older, for: testDID)

            // Healthy primary: the backup must be ignored.
            let stored = try await storage.getSession(for: testDID)
            #expect(stored?.refreshToken == "rt-current")

            // Corrupt the primary: recovery may use the backup (only readable copy)…
            // (plant bypasses KeychainManager, so its write-through cache must be cleared)
            backend.plant(key: "session.\(testDID)", namespace: namespace, data: Data("garbage".utf8))
            KeychainManager.clearCache()
            let recovered = try await storage.getSession(for: testDID)
            #expect(recovered?.refreshToken == "rt-rotated-away", "Backup is the only readable copy here")

            // …but a newer pending copy must always beat an older backup.
            backend.plant(key: "session.\(testDID)", namespace: namespace, data: Data("garbage".utf8))
            KeychainManager.clearCache()
            try await storage.saveSessionBackup(older, for: testDID)
            try await storage.savePendingSession(newer, for: testDID)
            let pendingWins = try await storage.getSession(for: testDID)
            #expect(pendingWins?.refreshToken == "rt-current", "Newer pending session must beat an older backup")
        }
    }

    @Test("Logout removes pending and backup session copies")
    func logoutClearsAllSessionCopies() async throws {
        let backend = InMemorySecureStorage()
        try await withInMemoryBackend(backend) {
            let storage = KeychainStorage(namespace: "test.refresh.logout")
            let account = makeAccount()
            let session = makeSession(refreshToken: "rt-gone")

            try await storage.saveAccountAndSession(account, session: session, for: testDID)
            try await storage.saveSessionBackup(session, for: testDID)
            try await storage.savePendingSession(session, for: testDID)

            try await storage.deleteSession(for: testDID)

            let resurrected = try await storage.getSession(for: testDID)
            #expect(resurrected == nil, "No recovery path may resurrect a deleted session")
        }
    }
}
