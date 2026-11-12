import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import PetrelCrypto
import XCTest

/// The client side of service auth, checked on the wire: what
/// `com.atproto.server.getServiceAuth` is asked, what comes back, and which
/// requests carry `atproto-proxy`.
final class ServiceAuthClientTests: XCTestCase {
    // NetworkService resolves the host before sending (its SSRF guard), so the
    // stubbed PDS needs a name that resolves, as in the other stubbed suites.
    private let pds = URL(string: "https://example.com")!
    private let account = "did:plc:abcdefghijklmnopqrstuvwx"
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override class func setUp() {
        super.setUp()
        NetworkService.setNetworkTestProtocolClasses([ServiceAuthStubURLProtocol.self])
    }

    override class func tearDown() {
        ServiceAuthStubURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses(nil)
        super.tearDown()
    }

    override func tearDown() {
        ServiceAuthStubURLProtocol.reset()
        super.tearDown()
    }

    /// What a PDS would return: a token signed with the account's key.
    private func issuedToken(
        audience: String,
        lexiconMethod: String?,
        lifetime: TimeInterval = 60
    ) async throws -> String {
        try await ServiceJWT.mint(
            issuer: account, audience: audience, lexiconMethod: lexiconMethod, signer: K256Keypair.generate(),
            now: now, lifetime: lifetime
        )
    }

    private func respond(token: String) {
        ServiceAuthStubURLProtocol.respond { _ in (200, Data(#"{"token":"\#(token)"}"#.utf8)) }
    }

    private func query(_ request: URLRequest) -> [String: String] {
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: getServiceAuth

    func testGetServiceAuthTokenSendsAudienceMethodAndExpiry() async throws {
        let audience = try ATProtoServiceReference("did:web:video.example.com#video_service")
        let method = "com.atproto.repo.uploadBlob"
        respond(token: try await issuedToken(audience: audience.description, lexiconMethod: method, lifetime: 1800))
        let client = await ATProtoClient(baseURL: pds)

        let token = try await client.getServiceAuthToken(
            audience: audience, lexiconMethod: method, lifetime: 30 * 60, now: now
        )

        let request = try XCTUnwrap(ServiceAuthStubURLProtocol.requests.first)
        XCTAssertEqual(ServiceAuthStubURLProtocol.requests.count, 1)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.host, "example.com")
        XCTAssertEqual(request.url?.path, "/xrpc/com.atproto.server.getServiceAuth")
        XCTAssertEqual(query(request), [
            "aud": "did:web:video.example.com#video_service",
            "lxm": "com.atproto.repo.uploadBlob",
            "exp": "1700001800",
        ])
        // The token request itself is for the PDS, not proxied anywhere.
        XCTAssertNil(request.value(forHTTPHeaderField: "atproto-proxy"))

        XCTAssertEqual(token.issuer, account)
        XCTAssertEqual(token.audience, "did:web:video.example.com#video_service")
        XCTAssertEqual(token.lexiconMethod, method)
        XCTAssertEqual(token.expiresAt, now.addingTimeInterval(1800))
        XCTAssertEqual(token.authorizationHeaderValue, "Bearer \(token.token)")
        XCTAssertFalse(token.isExpired(at: now))
        XCTAssertTrue(token.isExpired(at: now.addingTimeInterval(1800)))
        XCTAssertTrue(token.isExpired(at: now.addingTimeInterval(1700), margin: 120))
    }

    func testGetServiceAuthTokenWithoutMethodOrLifetimeOmitsThem() async throws {
        let audience = try ATProtoServiceReference("did:web:feed.example.com#bsky_fg")
        respond(token: try await issuedToken(audience: audience.description, lexiconMethod: nil))
        let client = await ATProtoClient(baseURL: pds)

        let token = try await client.getServiceAuthToken(audience: audience, lexiconMethod: nil)

        let request = try XCTUnwrap(ServiceAuthStubURLProtocol.requests.first)
        XCTAssertEqual(query(request), ["aud": "did:web:feed.example.com#bsky_fg"])
        // A method-less token is readable, and reported as such.
        XCTAssertNil(token.lexiconMethod)
        XCTAssertEqual(token.inspection.effectiveKeyID, "#atproto")
    }

    func testGetServiceAuthTokenAcceptsABareDIDAudienceFromAnOlderPDS() async throws {
        // A PDS that strips the service fragment still names the right service.
        let audience = try ATProtoServiceReference("did:web:feed.example.com#bsky_fg")
        respond(token: try await issuedToken(
            audience: "did:web:feed.example.com", lexiconMethod: "app.bsky.feed.getFeedSkeleton"
        ))
        let client = await ATProtoClient(baseURL: pds)
        let token = try await client.getServiceAuthToken(
            audience: audience, lexiconMethod: "app.bsky.feed.getFeedSkeleton"
        )
        XCTAssertEqual(token.audience, "did:web:feed.example.com")
    }

    func testGetServiceAuthTokenRefusesATokenForSomethingElse() async throws {
        let audience = try ATProtoServiceReference("did:web:feed.example.com#bsky_fg")
        let method = "app.bsky.feed.getFeedSkeleton"
        let client = await ATProtoClient(baseURL: pds)

        // Another service.
        respond(token: try await issuedToken(audience: "did:web:other.example.com#bsky_fg", lexiconMethod: method))
        await assertThrows(ServiceAuthRequestError.unexpectedClaims("audience is did:web:other.example.com#bsky_fg")) {
            try await client.getServiceAuthToken(audience: audience, lexiconMethod: method)
        }
        // Another service type on the same DID.
        respond(token: try await issuedToken(audience: "did:web:feed.example.com#atproto_labeler", lexiconMethod: method))
        await assertThrows(
            ServiceAuthRequestError.unexpectedClaims("audience is did:web:feed.example.com#atproto_labeler")
        ) {
            try await client.getServiceAuthToken(audience: audience, lexiconMethod: method)
        }
        // Another endpoint, or none.
        respond(token: try await issuedToken(audience: audience.description, lexiconMethod: "com.atproto.repo.createRecord"))
        await assertThrows(
            ServiceAuthRequestError.unexpectedClaims("lexicon method is com.atproto.repo.createRecord")
        ) {
            try await client.getServiceAuthToken(audience: audience, lexiconMethod: method)
        }
        respond(token: try await issuedToken(audience: audience.description, lexiconMethod: nil))
        await assertThrows(ServiceAuthRequestError.unexpectedClaims("lexicon method is absent")) {
            try await client.getServiceAuthToken(audience: audience, lexiconMethod: method)
        }
    }

    func testGetServiceAuthTokenReportsFailures() async throws {
        let audience = try ATProtoServiceReference("did:web:feed.example.com#bsky_fg")
        let client = await ATProtoClient(baseURL: pds)

        // Not a JWT.
        respond(token: "not-a-token")
        do {
            _ = try await client.getServiceAuthToken(audience: audience, lexiconMethod: nil)
            XCTFail("expected an error")
        } catch let error as ServiceAuthRequestError {
            guard case .invalidToken = error else { return XCTFail("\(error)") }
        }

        // The endpoint's declared error surfaces as a typed XRPC error.
        ServiceAuthStubURLProtocol.respond { _ in
            (400, Data(#"{"error":"BadExpiration","message":"expiration is in past"}"#.utf8))
        }
        do {
            _ = try await client.getServiceAuthToken(audience: audience, lexiconMethod: nil, lifetime: 60)
            XCTFail("expected an error")
        } catch let error as ATProtoError<ComAtprotoServerGetServiceAuth.Error> {
            XCTAssertEqual(error.error, .badExpiration)
        } catch {
            XCTAssertFalse(error is ServiceAuthRequestError, "\(error)")
            XCTAssertTrue(String(describing: error).contains("BadExpiration"), "\(error)")
        }

        // Arguments that are not sent at all.
        let before = ServiceAuthStubURLProtocol.requests.count
        await assertThrows(ServiceAuthRequestError.invalidRequest("lexicon method is not an NSID")) {
            try await client.getServiceAuthToken(audience: audience, lexiconMethod: "getFeedSkeleton")
        }
        for lifetime: TimeInterval in [0, -5, .infinity, .nan, 100_000] {
            await assertThrows(
                ServiceAuthRequestError.invalidRequest("lifetime must be between one second and one day")
            ) {
                try await client.getServiceAuthToken(audience: audience, lexiconMethod: nil, lifetime: lifetime)
            }
        }
        XCTAssertEqual(ServiceAuthStubURLProtocol.requests.count, before)
    }

    // MARK: Service proxying

    func testProxiedNamespacesCarryTheAtprotoProxyHeaderOnTheWire() async throws {
        ServiceAuthStubURLProtocol.respond { _ in (200, Data("{}".utf8)) }
        let client = await ATProtoClient(baseURL: pds)
        let appView = try ATProtoServiceReference("did:web:appview.example.com#bsky_appview")
        let labeler = try ATProtoServiceReference(did: "did:web:labeler.example.com", serviceID: "#atproto_labeler")

        try await client.setServiceProxy(appView, for: "app.bsky")
        // One endpoint routed apart from the rest of its namespace.
        try await client.setServiceProxy(labeler, for: "com.atproto.label.queryLabels")

        _ = try? await client.app.bsky.actor.getProfile(
            input: AppBskyActorGetProfile.Parameters(actor: ATIdentifier(string: "alice.example.com"))
        )
        _ = try? await client.com.atproto.label.queryLabels(
            input: ComAtprotoLabelQueryLabels.Parameters(uriPatterns: ["at://did:plc:abcdefghijklmnopqrstuvwx/*"])
        )
        _ = try? await client.com.atproto.server.describeServer()
        _ = try? await client.app.bsky.actor.getPreferences(input: AppBskyActorGetPreferences.Parameters())

        let proxyByPath = Dictionary(
            ServiceAuthStubURLProtocol.requests.map {
                ($0.url?.lastPathComponent ?? "", $0.value(forHTTPHeaderField: "atproto-proxy"))
            },
            uniquingKeysWith: { first, _ in first }
        )
        XCTAssertEqual(proxyByPath.count, 4)
        XCTAssertEqual(proxyByPath["app.bsky.actor.getProfile"], "did:web:appview.example.com#bsky_appview")
        XCTAssertEqual(proxyByPath["com.atproto.label.queryLabels"], "did:web:labeler.example.com#atproto_labeler")
        // Unmapped: straight to the PDS.
        XCTAssertEqual(proxyByPath["com.atproto.server.describeServer"], .some(nil))
        // Preferences live on the PDS and are never proxied.
        XCTAssertEqual(proxyByPath["app.bsky.actor.getPreferences"], .some(nil))
        // Every request went to the PDS host: proxying is a header, not a redirect.
        XCTAssertEqual(Set(ServiceAuthStubURLProtocol.requests.compactMap { $0.url?.host }), ["example.com"])

        let profileProxy = await client.serviceProxy(for: "app.bsky.actor.getProfile")
        XCTAssertEqual(profileProxy, appView)
        let labelsProxy = await client.serviceProxy(for: "com.atproto.label.queryLabels")
        XCTAssertEqual(labelsProxy, labeler)
        let serverProxy = await client.serviceProxy(for: "com.atproto.server.describeServer")
        XCTAssertNil(serverProxy)
    }

    func testProxyTargetNeedsAServiceIdentifier() async throws {
        let client = await ATProtoClient(baseURL: pds)
        let bare = try ATProtoServiceReference("did:web:appview.example.com")
        await assertThrows(
            PetrelCryptoError.invalidIdentifier("atproto-proxy needs a service identifier (did#service)")
        ) {
            try await client.setServiceProxy(bare, for: "app.bsky")
        }
        let proxy = await client.serviceProxy(for: "app.bsky.actor.getProfile")
        XCTAssertNil(proxy)
    }

    func testServiceReferenceParsingAndFormatting() throws {
        let appView = try ATProtoServiceReference("did:web:api.bsky.app#bsky_appview")
        XCTAssertEqual(appView.did, "did:web:api.bsky.app")
        XCTAssertEqual(appView.serviceID, ATProtoServiceReference.bskyAppViewServiceID)
        XCTAssertEqual(appView.description, "did:web:api.bsky.app#bsky_appview")
        XCTAssertEqual(try appView.proxyHeaderValue(), "did:web:api.bsky.app#bsky_appview")
        XCTAssertEqual(ATProtoServiceReference.proxyHeaderName, "atproto-proxy")
        XCTAssertEqual(
            try ATProtoServiceReference(did: "did:plc:abcdefghijklmnopqrstuvwx", serviceID: "atproto_labeler"),
            try ATProtoServiceReference("did:plc:abcdefghijklmnopqrstuvwx#atproto_labeler")
        )
        let bare = try ATProtoServiceReference("did:plc:abcdefghijklmnopqrstuvwx")
        XCTAssertNil(bare.serviceID)
        XCTAssertEqual(bare.description, "did:plc:abcdefghijklmnopqrstuvwx")
        XCTAssertThrowsError(try bare.proxyHeaderValue())

        for invalid in [
            "", "api.bsky.app", "https://api.bsky.app", "did:web:api.bsky.app#", "did:web:api.bsky.app#a#b",
            "did:web:api.bsky.app#has space", "did:web:api.bsky.app:path#bsky_appview", "#bsky_appview",
        ] {
            XCTAssertThrowsError(try ATProtoServiceReference(invalid), invalid)
        }
        XCTAssertThrowsError(try ATProtoServiceReference(did: "did:web:api.bsky.app", serviceID: ""))
        XCTAssertThrowsError(try ATProtoServiceReference(did: "api.bsky.app", serviceID: "bsky_appview"))

        // The same reference configures a receiving service's audience check.
        let audience = ServiceAuthAudience.service(appView, acceptBareDID: true)
        XCTAssertTrue(audience.accepts("did:web:api.bsky.app#bsky_appview"))
        XCTAssertTrue(audience.accepts("did:web:api.bsky.app"))
        XCTAssertFalse(audience.accepts("did:web:api.bsky.app#bsky_chat"))
        XCTAssertFalse(ServiceAuthAudience.service(appView).accepts("did:web:api.bsky.app"))
    }

    private func assertThrows<E: Error & Equatable>(
        _ expected: E,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> some Any
    ) async {
        do {
            _ = try await body()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch let error as E {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("expected \(expected), got \(error)", file: file, line: line)
        }
    }
}

/// Answers every request from a closure and records what was sent.
final class ServiceAuthStubURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?
    private nonisolated(unsafe) static var recorded: [URLRequest] = []

    static var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    static func respond(_ handler: @escaping @Sendable (URLRequest) -> (Int, Data)) {
        lock.withLock { self.handler = handler }
    }

    static func reset() {
        lock.withLock {
            handler = nil
            recorded = []
        }
    }

    override class func canInit(with _: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let handler = Self.lock.withLock { () -> (@Sendable (URLRequest) -> (Int, Data))? in
            Self.recorded.append(request)
            return Self.handler
        }
        guard let handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        let (status, body) = handler(request)
        guard let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
