import Crypto
import Foundation
@testable import Petrel
import Testing
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
private final class OAuthBindingTestURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?
    private nonisolated(unsafe) static var requests: [URLRequest] = []

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        handler = nil
        requests.removeAll()
    }

    static func setHandler(_ newHandler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?) {
        lock.lock()
        defer { lock.unlock() }
        handler = newHandler
    }

    static func recordedRequests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let currentHandler = Self.handler
        Self.lock.unlock()

        guard let currentHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let (response, data) = currentHandler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeHTTPResponse(
    url: URL,
    statusCode: Int,
    headers: [String: String] = [:]
) -> HTTPURLResponse {
    var allHeaders = headers
    if allHeaders["Content-Type"] == nil {
        allHeaders["Content-Type"] = "application/json"
    }
    return HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: allHeaders
    )!
}

private let testPDSHost = "https://pds.strict.test"
private let testAliceDID = "did:plc:strictalice12345678901234"
private let testBobDID = "did:plc:strictbob98765432109876"

private func withOAuthBindingTransport<T>(
    _ backend: InMemorySecureStorage,
    handler: @escaping @Sendable (URLRequest) -> (HTTPURLResponse, Data),
    _ body: @escaping () async throws -> T
) async throws -> T {
    try await withSerializedStorageOverrideTest {
        KeychainManager._setStorageOverride(backend)
        OAuthBindingTestURLProtocol.reset()
        OAuthBindingTestURLProtocol.setHandler(handler)
        NetworkService.setNetworkTestProtocolClasses([OAuthBindingTestURLProtocol.self])
        let testDNS: @Sendable (String) -> [String]? = { host in
            if host == "localhost" || host == "127.0.0.1" || host == "::1" {
                return ["127.0.0.1"]
            }
            return ["93.184.216.34"]
        }
        NetworkService.dnsResolverOverride = testDNS
        defer {
            NetworkService.dnsResolverOverride = nil
            NetworkService.setNetworkTestProtocolClasses(nil)
            OAuthBindingTestURLProtocol.reset()
            KeychainManager._setStorageOverride(nil)
        }
        return try await body()
    }
}

private final class StrictMockDIDResolver: DIDResolving, @unchecked Sendable {
    var didToHandle: [String: String] = [testAliceDID: "alice.strict.test", testBobDID: "bob.strict.test"]
    var didToPDS: [String: URL] = [testAliceDID: URL(string: testPDSHost)!, testBobDID: URL(string: testPDSHost)!]
    var handleToDID: [String: String] = ["alice.strict.test": testAliceDID, "bob.strict.test": testBobDID]

    func resolveHandleToDID(handle: String) async throws -> String {
        guard let did = handleToDID[handle] else { throw NetworkError.requestFailed }
        return did
    }

    func resolveDIDToPDSURL(did: String) async throws -> URL {
        guard let pds = didToPDS[did] else { throw NetworkError.requestFailed }
        return pds
    }

    func resolveDIDToHandleAndPDSURL(did: String) async throws -> (String, URL) {
        guard let pds = didToPDS[did], let handle = didToHandle[did] else { throw NetworkError.requestFailed }
        return (handle, pds)
    }

    func resolveDIDDocument(did: String) async throws -> DIDDocument {
        throw NetworkError.requestFailed
    }
}

/// The app-password strategy must send `createSession` to the account's own PDS
/// with no credentials of the currently signed-in account attached.
///
/// The OAuth callback and binding checks that used to live in this file are
/// covered — against a server whose token endpoint works — by
/// `OAuthFlowConformanceTests` and `OAuthMetadataValidationTests`.
@Suite("Legacy password strategy request isolation", .serialized)
struct OAuthStrictBindingTests {
    @Test("A1-R2-02: LegacyPasswordStrategy createSession sends unauthenticated exact-origin request without bearer tokens")
    func testLegacyPasswordCreateSessionUnauthenticatedExactOrigin() async throws {
        let backend = InMemorySecureStorage()
        let pdsA = "https://pds-a.strict.test"
        let pdsB = "https://pds-b.strict.test"
        let pdsBURL = URL(string: pdsB)!

        let handler: @Sendable (URLRequest) -> (HTTPURLResponse, Data) = { req in
            let url = req.url!
            if url.path.contains("createSession") {
                let sessionOutput = """
                {
                    "did": "did:plc:bob-pds-b",
                    "handle": "bob.pds-b.test",
                    "accessJwt": "jwt-for-bob",
                    "refreshJwt": "refresh-for-bob"
                }
                """
                return (makeHTTPResponse(url: url, statusCode: 200), Data(sessionOutput.utf8))
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data("{}".utf8))
        }

        try await withOAuthBindingTransport(backend, handler: handler) {
            let namespace = "test.legacy.unauthenticated_pds_b"
            let storage = KeychainStorage(namespace: namespace)
            let accountManager = await AccountManager(storage: storage)
            let networkService = NetworkService(baseURL: URL(string: pdsA)!)

            // Set up active account A with a legacy Bearer token
            let accountA = Account(
                did: "did:plc:alice-pds-a",
                handle: "alice.pds-a.test",
                pdsURL: URL(string: pdsA)!
            )
            try await storage.saveAccount(accountA, for: accountA.did)
            let sessionA = Session(
                accessToken: "secret-bearer-token-for-account-a",
                refreshToken: "refresh-a",
                createdAt: Date(),
                expiresIn: 3600,
                tokenType: .bearer,
                did: accountA.did
            )
            try await storage.saveSession(sessionA, for: accountA.did)
            try await accountManager.setCurrentAccount(did: accountA.did)

            let didResolver = StrictMockDIDResolver()
            didResolver.didToPDS["did:plc:bob-pds-b"] = pdsBURL
            didResolver.handleToDID["bob.pds-b.test"] = "did:plc:bob-pds-b"

            let legacyStrategy = LegacyPasswordStrategy(
                storage: storage,
                accountManager: accountManager,
                networkService: networkService,
                didResolver: didResolver
            )

            _ = try await legacyStrategy.loginWithPassword(identifier: "bob.pds-b.test", password: "password123", bskyAppViewDID: nil, bskyChatDID: nil)

            // Find the createSession request
            let recorded = OAuthBindingTestURLProtocol.recordedRequests()
            let createSessionReq = recorded.first { $0.url?.path.contains("createSession") == true }
            guard let req = createSessionReq else {
                Issue.record("Missing createSession request")
                return
            }
            #expect(req.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(req.value(forHTTPHeaderField: "DPoP") == nil)
            #expect(req.value(forHTTPHeaderField: "Cookie") == nil)
            #expect(req.value(forHTTPHeaderField: "Proxy-Authorization") == nil)
            #expect(req.value(forHTTPHeaderField: "atproto-proxy") == nil)

            // Test that cross-origin redirect on createSession is not followed and fails
            OAuthBindingTestURLProtocol.reset()
            OAuthBindingTestURLProtocol.setHandler { req in
                let url = req.url!
                if url.path.contains("createSession") {
                    return (makeHTTPResponse(url: url, statusCode: 302, headers: ["Location": "https://evil.test/hijack"]), Data())
                }
                return (makeHTTPResponse(url: url, statusCode: 200), Data("{}".utf8))
            }
            await #expect(throws: (any Error).self) {
                try await legacyStrategy.loginWithPassword(identifier: "bob.pds-b.test", password: "password123", bskyAppViewDID: nil, bskyChatDID: nil)
            }
            let redirectedRequests = OAuthBindingTestURLProtocol.recordedRequests()
            #expect(!redirectedRequests.contains { $0.url?.host == "evil.test" }, "Cross-origin redirect must not be followed")
        }
    }
}

// Older toolchains require the explicit conformance for strict-concurrency;
// newer SDKs mark URLProtocol's inherited Sendable unavailable and warn on it.
#if compiler(<6.2)
extension OAuthBindingTestURLProtocol: @unchecked Sendable {}
#endif
