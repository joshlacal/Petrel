import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

/// A handle host and a `did:web` host are chosen by whoever owns the identifier, so they are
/// untrusted. A `401` from one of them says nothing about the signed-in account: it must never
/// start a token refresh, never cause the request to be sent again with the account's
/// credentials, and never broadcast an automatic logout.
@Suite("Identity fetches never carry or trigger account authentication", .serialized)
struct DIDResolutionUnauthorizedHostTests {
    private let pdsURL = URL(string: "https://pds.account-host.com")!
    private static let hostileHost = "hostile-site.com"

    private func withTransport<T>(_ body: @escaping () async throws -> T) async throws -> T {
        try await withSerializedStorageOverrideTest {
            UnauthorizedHostURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses([UnauthorizedHostURLProtocol.self])
            NetworkService.dnsResolverOverride = { host in
                host == "localhost" ? ["127.0.0.1"] : ["104.244.42.1"]
            }
            // No test here may depend on live DNS.
            DIDResolutionService.dnsTXTResolverOverride = { _ in [] }
            defer {
                UnauthorizedHostURLProtocol.reset()
                NetworkService.setNetworkTestProtocolClasses(nil)
                NetworkService.dnsResolverOverride = nil
                DIDResolutionService.dnsTXTResolverOverride = nil
            }
            return try await LogoutProbe.$id.withValue(UUID()) {
                try await body()
            }
        }
    }

    private func signedInResolver(
        refreshSucceeds: Bool = true
    ) async -> (DIDResolutionService, LegacyShapedAuthProvider, NetworkService) {
        let provider = LegacyShapedAuthProvider(refreshSucceeds: refreshSucceeds)
        let networkService = NetworkService(baseURL: pdsURL, authService: provider)
        await provider.install(networkService: networkService)
        let resolver = await DIDResolutionService(networkService: networkService)
        return (resolver, provider, networkService)
    }

    @Test("A 401 from a handle host's /.well-known/atproto-did does not refresh, resend with credentials, or log out")
    func wellKnownUnauthorizedDoesNotTouchAccountAuth() async throws {
        try await withTransport {
            // The account's own PDS cannot resolve the handle, so the resolver goes direct.
            UnauthorizedHostURLProtocol.installRoute(matching: "com.atproto.identity.resolveHandle") { _ in
                (404, Data(#"{"error":"HandleNotFound"}"#.utf8), ["Content-Type": "application/json"])
            }
            UnauthorizedHostURLProtocol.installRoute(matching: "\(Self.hostileHost)/.well-known/atproto-did") { _ in
                (401, Data("give me your token".utf8), ["Content-Type": "text/plain", "WWW-Authenticate": "Bearer"])
            }
            let logouts = await LogoutRecorder.observing()
            let (resolver, provider, _) = await signedInResolver()

            await #expect(throws: (any Error).self) {
                try await resolver.resolveHandleToDID(handle: "mallory.\(Self.hostileHost)")
            }

            let hostile = UnauthorizedHostURLProtocol.requests(toHost: "mallory.\(Self.hostileHost)")
            #expect(hostile.count == 1, "the well-known request must be sent exactly once, got \(hostile.count)")
            #expect(hostile.allSatisfy { !$0.carriesCredentials }, "no request to the handle host may carry credentials")
            #expect(await provider.unauthorizedCount == 0, "a 401 from a handle host must not enter the session 401 path")
            #expect(await provider.forcedRefreshCount == 0, "a 401 from a handle host must not force a token refresh")
            try await logouts.settle()
            #expect(logouts.count == 0, "a 401 from a handle host must not broadcast an automatic logout")
        }
    }

    @Test("A 401 from a did:web host's did.json does not refresh, resend with credentials, or log out")
    func didWebUnauthorizedDoesNotTouchAccountAuth() async throws {
        try await withTransport {
            UnauthorizedHostURLProtocol.installRoute(matching: "\(Self.hostileHost)/.well-known/did.json") { _ in
                (401, Data(#"{"error":"AuthenticationRequired"}"#.utf8), ["Content-Type": "application/json"])
            }
            let logouts = await LogoutRecorder.observing()
            let (resolver, provider, _) = await signedInResolver()

            await #expect(throws: (any Error).self) {
                try await resolver.resolveDIDToPDSURL(did: "did:web:\(Self.hostileHost)")
            }

            let hostile = UnauthorizedHostURLProtocol.requests(toHost: Self.hostileHost)
            #expect(hostile.count == 1, "the DID document request must be sent exactly once, got \(hostile.count)")
            #expect(hostile.allSatisfy { !$0.carriesCredentials }, "no request to the did:web host may carry credentials")
            #expect(await provider.unauthorizedCount == 0)
            #expect(await provider.forcedRefreshCount == 0)
            try await logouts.settle()
            #expect(logouts.count == 0)
        }
    }

    @Test("A failed refresh after a 401 from a did:web host cannot log the account out")
    func didWebUnauthorizedWithFailingRefreshDoesNotLogOut() async throws {
        try await withTransport {
            UnauthorizedHostURLProtocol.installRoute(matching: "\(Self.hostileHost)/.well-known/did.json") { _ in
                (401, Data(), [:])
            }
            let logouts = await LogoutRecorder.observing()
            let (resolver, provider, _) = await signedInResolver(refreshSucceeds: false)

            await #expect(throws: (any Error).self) {
                try await resolver.resolveDIDToPDSURL(did: "did:web:\(Self.hostileHost)")
            }

            #expect(await provider.unauthorizedCount == 0)
            try await logouts.settle()
            #expect(logouts.count == 0, "an untrusted host must not be able to trigger an automatic logout")
        }
    }

    @Test("Identity requests carry no account, proxy, or product headers")
    func identityRequestsCarryOnlyNeutralHeaders() async throws {
        try await withTransport {
            let document = """
            {"id":"did:web:\(Self.hostileHost)","alsoKnownAs":[],"service":[{"id":"#atproto_pds",\
            "type":"AtprotoPersonalDataServer","serviceEndpoint":"https://pds.account-host.com"}]}
            """
            UnauthorizedHostURLProtocol.installRoute(matching: "\(Self.hostileHost)/.well-known/did.json") { _ in
                (200, Data(document.utf8), ["Content-Type": "application/json"])
            }
            let (resolver, _, networkService) = await signedInResolver()
            await networkService.setProxyHeader(did: "did:web:api.bsky.app", service: "bsky_appview")
            await networkService.setAcceptLabelers([(did: "did:plc:ar7c4by46qjdydhdevvrndac", redact: false)])

            let pds = try await resolver.resolveDIDToPDSURL(did: "did:web:\(Self.hostileHost)")
            #expect(pds.absoluteString == "https://pds.account-host.com")

            let hostile = UnauthorizedHostURLProtocol.requests(toHost: Self.hostileHost)
            #expect(hostile.count == 1)
            for request in hostile {
                #expect(!request.carriesCredentials)
                let names = Set(request.headers.keys.map { $0.lowercased() })
                #expect(names.isDisjoint(with: ["atproto-proxy", "atproto-accept-labelers", "x-requested-with"]))
                #expect(!names.contains { $0.hasPrefix("x-catbird") })
            }
        }
    }

    @Test("NetworkService: a third-party request without credentials carries no client-wide, correlation or session default headers")
    func networkServiceSendsThirdPartiesNothingAboutTheClient() async throws {
        try await withTransport {
            UnauthorizedHostURLProtocol.installRoute(matching: "third-party.com/resource") { _ in
                (200, Data(#"{"ok":true}"#.utf8), ["Content-Type": "application/json"])
            }
            let provider = LegacyShapedAuthProvider(refreshSucceeds: true)
            let networkService = NetworkService(baseURL: pdsURL, authService: provider)
            await provider.install(networkService: networkService)
            await networkService.setUserAgent("ExampleApp/1.0")
            await networkService.setHeader(name: "X-App-Token", value: "app-wide-secret")
            await networkService.setHeader(name: "Authorization", value: "Bearer app-wide-credential")
            await networkService.setProxyHeader(did: "did:web:api.bsky.app", service: "bsky_appview")
            await networkService.setAcceptLabelers([(did: "did:plc:ar7c4by46qjdydhdevvrndac", redact: false)])

            // Both ways a request is built: by the caller, and by createURLRequest, which
            // copies the client-wide headers into the request itself.
            _ = try await networkService.performRequest(URLRequest(url: URL(string: "https://third-party.com/resource")!))
            let built = try await networkService.createURLRequest(
                endpoint: "https://third-party.com/resource", method: "GET", headers: [:], body: nil, queryItems: nil
            )
            _ = try await networkService.performRequest(built)
            // And the non-retrying path the OAuth metadata fetches use.
            _ = try await networkService.request(built)

            let sent = UnauthorizedHostURLProtocol.requests(toHost: "third-party.com")
            #expect(sent.count == 3)
            for request in sent {
                let names = Set(request.headers.keys.map { $0.lowercased() })
                #expect(!request.carriesCredentials)
                #expect(names.isDisjoint(with: ["atproto-proxy", "atproto-accept-labelers", "x-requested-with", "x-app-token"]))
                #expect(!names.contains { $0.hasPrefix("x-") }, "\(names)")
                #expect(request.headers.first { $0.key.lowercased() == "user-agent" }?.value == "ExampleApp/1.0")
                #expect(request.headers.first { $0.key.lowercased() == "accept" }?.value == "application/json")
            }
        }
    }

    @Test("NetworkService: requests to the client's own service keep the client-wide headers")
    func networkServiceKeepsHeadersForOwnService() async throws {
        try await withTransport {
            UnauthorizedHostURLProtocol.installRoute(matching: "pds.account-host.com/xrpc/com.example.query") { _ in
                (200, Data(#"{"ok":true}"#.utf8), ["Content-Type": "application/json"])
            }
            let provider = LegacyShapedAuthProvider(refreshSucceeds: true)
            let networkService = NetworkService(baseURL: pdsURL, authService: provider)
            await provider.install(networkService: networkService)
            await networkService.setHeader(name: "X-App-Token", value: "app-wide-value")
            await networkService.setAcceptLabelers([(did: "did:plc:ar7c4by46qjdydhdevvrndac", redact: false)])

            _ = try await networkService.performRequest(
                URLRequest(url: pdsURL.appendingPathComponent("xrpc/com.example.query"))
            )

            let sent = UnauthorizedHostURLProtocol.requests(toHost: "pds.account-host.com")
            #expect(sent.count == 1)
            let names = Set(sent.flatMap { $0.headers.keys.map { $0.lowercased() } })
            #expect(names.isSuperset(of: ["authorization", "x-app-token", "atproto-accept-labelers"]))
        }
    }

    @Test("NetworkService: a 401 from a third-party origin that was sent no credentials never reaches the session 401 path")
    func networkServiceGatesUnauthorizedPathOnCredentials() async throws {
        try await withTransport {
            UnauthorizedHostURLProtocol.installRoute(matching: "third-party.com/resource") { _ in
                (401, Data(#"{"error":"InvalidToken"}"#.utf8), ["Content-Type": "application/json"])
            }
            let logouts = await LogoutRecorder.observing()
            let provider = LegacyShapedAuthProvider(refreshSucceeds: true)
            let networkService = NetworkService(baseURL: pdsURL, authService: provider)
            await provider.install(networkService: networkService)

            do {
                _ = try await networkService.performRequest(URLRequest(url: URL(string: "https://third-party.com/resource")!))
                Issue.record("Expected the 401 to be thrown")
            } catch let NetworkError.responseError(statusCode) {
                #expect(statusCode == 401)
            }

            let sent = UnauthorizedHostURLProtocol.requests(toHost: "third-party.com")
            #expect(sent.count == 1)
            #expect(sent.allSatisfy { !$0.carriesCredentials })
            #expect(await provider.unauthorizedCount == 0)
            try await logouts.settle()
            #expect(logouts.count == 0)
        }
    }

    @Test("NetworkService: a 401 from a third-party origin with no auth provider does not broadcast a logout")
    func networkServiceWithoutProviderDoesNotBroadcastLogout() async throws {
        try await withTransport {
            UnauthorizedHostURLProtocol.installRoute(matching: "third-party.com/resource") { _ in
                (401, Data(), [:])
            }
            let logouts = await LogoutRecorder.observing()
            let networkService = NetworkService(baseURL: pdsURL)

            await #expect(throws: NetworkError.self) {
                try await networkService.performRequest(URLRequest(url: URL(string: "https://third-party.com/resource")!))
            }
            try await logouts.settle()
            #expect(logouts.count == 0)
        }
    }

    @Test("Control: a failed refresh after a 401 on an authenticated request does broadcast a logout, and the recorder sees it")
    func recorderSeesRealLogout() async throws {
        try await withTransport {
            UnauthorizedHostURLProtocol.installRoute(matching: "pds.account-host.com/xrpc/com.example.protected") { _ in
                (401, Data(#"{"error":"ExpiredToken"}"#.utf8), ["Content-Type": "application/json"])
            }
            let logouts = await LogoutRecorder.observing()
            let provider = LegacyShapedAuthProvider(refreshSucceeds: false)
            let networkService = NetworkService(baseURL: pdsURL, authService: provider)
            await provider.install(networkService: networkService)

            await #expect(throws: NetworkError.self) {
                try await networkService.performRequest(
                    URLRequest(url: pdsURL.appendingPathComponent("xrpc/com.example.protected"))
                )
            }
            try await logouts.settle()
            #expect(logouts.count == 1)
            #expect(await provider.unauthorizedCount == 1)
        }
    }

    @Test("NetworkService: a 401 from the client's own service origin still reaches the auth provider")
    func networkServiceKeepsOwnOriginBehaviour() async throws {
        try await withTransport {
            // A path the policy sends no credentials to, but on the client's own service. A
            // loopback http development PDS depends on this 401 reaching the provider.
            UnauthorizedHostURLProtocol.installRoute(matching: "pds.account-host.com/custom/path") { request in
                request.value(forHTTPHeaderField: "Authorization") == nil
                    ? (401, Data(#"{"error":"AuthMissing"}"#.utf8), ["Content-Type": "application/json"])
                    : (200, Data(#"{"ok":true}"#.utf8), ["Content-Type": "application/json"])
            }
            let provider = LegacyShapedAuthProvider(refreshSucceeds: true)
            let networkService = NetworkService(baseURL: pdsURL, authService: provider)
            await provider.install(networkService: networkService)

            let (_, response) = try await networkService.performRequest(
                URLRequest(url: pdsURL.appendingPathComponent("custom/path"))
            )
            #expect(response.statusCode == 200)
            #expect(await provider.unauthorizedCount == 1)
        }
    }

    @Test("NetworkService: a 401 for a request that did carry the account's credentials still refreshes")
    func networkServiceStillRefreshesAuthenticatedRequests() async throws {
        try await withTransport {
            let attempts = LogoutRecorder()
            UnauthorizedHostURLProtocol.installRoute(matching: "pds.account-host.com/xrpc/com.example.protected") { _ in
                attempts.record()
                return attempts.count == 1
                    ? (401, Data(#"{"error":"ExpiredToken"}"#.utf8), ["Content-Type": "application/json"])
                    : (200, Data(#"{"ok":true}"#.utf8), ["Content-Type": "application/json"])
            }
            let provider = LegacyShapedAuthProvider(refreshSucceeds: true)
            let networkService = NetworkService(baseURL: pdsURL, authService: provider)
            await provider.install(networkService: networkService)

            let (_, response) = try await networkService.performRequest(
                URLRequest(url: pdsURL.appendingPathComponent("xrpc/com.example.protected"))
            )
            #expect(response.statusCode == 200)
            #expect(await provider.unauthorizedCount == 1)
        }
    }
}

// MARK: - Support

/// Marks the tasks of one test. `NetworkService` broadcasts a logout from a `Task` it creates
/// while handling the request, and such a task inherits task-local values, so an observer can
/// tell this test's broadcasts from those of suites running in parallel.
private enum LogoutProbe {
    @TaskLocal static var id: UUID?
}

private final class LogoutRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func record() { lock.withLock { value += 1 } }
    var count: Int { lock.withLock { value } }

    /// A recorder that counts the automatic logouts broadcast on behalf of the current test.
    static func observing() async -> LogoutRecorder {
        let recorder = LogoutRecorder()
        let probe = LogoutProbe.id
        await AuthEventBroadcaster.shared.addObserver { event in
            if case .autoLogoutTriggered = event, probe != nil, LogoutProbe.id == probe {
                recorder.record()
            }
        }
        return recorder
    }

    /// Gives a broadcast that was started in an unstructured task time to be delivered.
    func settle() async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
    }
}

/// Mirrors what `LegacyPasswordStrategy` does on a 401: force a refresh, attach the bearer token
/// to whatever request it was handed, and send it again.
private actor LegacyShapedAuthProvider: AuthenticationProvider {
    private var networkService: NetworkService?
    private let refreshSucceeds: Bool
    private(set) var unauthorizedCount = 0
    private(set) var forcedRefreshCount = 0

    init(refreshSucceeds: Bool) {
        self.refreshSucceeds = refreshSucceeds
    }

    func install(networkService: NetworkService) {
        self.networkService = networkService
    }

    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        try await prepareAuthenticatedRequestWithContext(request).0
    }

    func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (URLRequest, AuthContext) {
        var prepared = request
        prepared.setValue("Bearer account-access-token", forHTTPHeaderField: "Authorization")
        return (prepared, AuthContext(did: "did:plc:identityprobeaccount", jkt: nil))
    }

    func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
        .stillValid
    }

    func handleUnauthorizedResponse(
        _: HTTPURLResponse,
        data _: Data,
        for request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        unauthorizedCount += 1
        forcedRefreshCount += 1
        guard refreshSucceeds, let networkService else {
            throw AuthError.tokenRefreshFailed
        }
        let (prepared, _) = try await prepareAuthenticatedRequestWithContext(request)
        let (data, response) = try await networkService.request(prepared)
        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
        return (data, http)
    }

    func updateDPoPNonce(for _: URL, from _: [String: String], did _: String?, jkt _: String?) async {}
}

private final class UnauthorizedHostURLProtocol: URLProtocol {
    typealias RouteHandler = @Sendable (URLRequest) -> (statusCode: Int, body: Data, headers: [String: String])

    struct Recorded: Sendable {
        let url: URL
        let headers: [String: String]

        var carriesCredentials: Bool {
            headers.keys.contains { name in
                ["authorization", "dpop", "cookie", "proxy-authorization"].contains(name.lowercased())
            }
        }
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var routes: [(matcher: String, handler: RouteHandler)] = []
    private nonisolated(unsafe) static var recorded: [Recorded] = []

    static func installRoute(matching: String, handler: @escaping RouteHandler) {
        lock.withLock { routes.append((matcher: matching, handler: handler)) }
    }

    static func reset() {
        lock.withLock {
            routes.removeAll()
            recorded.removeAll()
        }
    }

    static func requests(toHost host: String) -> [Recorded] {
        lock.withLock { recorded.filter { $0.url.host == host } }
    }

    override class func canInit(with _: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let handler = Self.lock.withLock { () -> RouteHandler? in
            Self.recorded.append(Recorded(url: url, headers: request.allHTTPHeaderFields ?? [:]))
            return Self.routes.first(where: { url.absoluteString.contains($0.matcher) })?.handler
        }
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        let (statusCode, body, headers) = handler(request)
        guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

#if compiler(<6.2)
    extension UnauthorizedHostURLProtocol: @unchecked Sendable {}
#endif
