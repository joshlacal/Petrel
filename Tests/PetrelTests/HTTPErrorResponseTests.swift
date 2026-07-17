import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import XCTest

final class HTTPErrorResponseTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        NetworkService.setNetworkTestProtocolClasses([HTTPErrorResponseURLProtocol.self])
    }

    override class func tearDown() {
        HTTPErrorResponseURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses(nil)
        super.tearDown()
    }

    override func tearDown() {
        HTTPErrorResponseURLProtocol.reset()
        super.tearDown()
    }

    func testNamedPathReturnsSuccessfulResponse() async throws {
        let body = Data(#"{"ok":true}"#.utf8)
        HTTPErrorResponseURLProtocol.install(.response(statusCode: 200, body: body))
        let networkService = NetworkService(baseURL: baseURL)

        let (data, response) = try await networkService
            .performRequestReturningHTTPErrorResponses(
                request(path: "success"),
                skipTokenRefresh: false
            )

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(data, body)
        XCTAssertEqual(HTTPErrorResponseURLProtocol.requestCount, 1)
    }

    func testNamedPathReturns400Response() async throws {
        let body = Data(#"{"error":"BadRequest"}"#.utf8)
        HTTPErrorResponseURLProtocol.install(.response(statusCode: 400, body: body))
        let networkService = NetworkService(baseURL: baseURL)

        let (data, response) = try await networkService
            .performRequestReturningHTTPErrorResponses(
                request(path: "bad-request"),
                skipTokenRefresh: false
            )

        XCTAssertEqual(response.statusCode, 400)
        XCTAssertEqual(data, body)
        XCTAssertEqual(HTTPErrorResponseURLProtocol.requestCount, 1)
    }

    func testNamedPathReturns402Through499Response() async throws {
        let body = Data(#"{"error":"DestinationExists"}"#.utf8)
        HTTPErrorResponseURLProtocol.install(.response(statusCode: 409, body: body))
        let networkService = NetworkService(baseURL: baseURL)

        let (data, response) = try await networkService
            .performRequestReturningHTTPErrorResponses(
                request(path: "conflict"),
                skipTokenRefresh: false
            )

        XCTAssertEqual(response.statusCode, 409)
        XCTAssertEqual(data, body)
        XCTAssertEqual(HTTPErrorResponseURLProtocol.requestCount, 1)
    }

    func testNamedPathPreservesPolicyThrough401AuthenticationRetry() async throws {
        let unauthorizedBody = Data(#"{"error":"Unauthorized"}"#.utf8)
        let finalBody = Data(#"{"error":"DestinationExists"}"#.utf8)
        HTTPErrorResponseURLProtocol.install([
            .response(statusCode: 401, body: unauthorizedBody),
            .response(statusCode: 409, body: finalBody),
        ])
        let provider = HTTPErrorResponseAuthProvider()
        let networkService = NetworkService(baseURL: baseURL, authService: provider)
        await provider.install(networkService: networkService)

        let (data, response) = try await networkService
            .performRequestReturningHTTPErrorResponses(
                request(path: "unauthorized"),
                skipTokenRefresh: false
            )

        XCTAssertEqual(response.statusCode, 409)
        XCTAssertEqual(data, finalBody)
        let refreshCount = await provider.refreshCount
        let prepareCount = await provider.prepareCount
        let unauthorizedCount = await provider.unauthorizedCount
        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(prepareCount, 2)
        XCTAssertEqual(unauthorizedCount, 1)
        XCTAssertEqual(HTTPErrorResponseURLProtocol.requestCount, 2)

        HTTPErrorResponseURLProtocol.install(
            .response(statusCode: 409, body: finalBody)
        )
        do {
            _ = try await networkService.performRequest(
                request(path: "after-auth-retry"),
                skipTokenRefresh: false
            )
            XCTFail("Expected the nested preserving scope to be restored")
        } catch let NetworkError.responseError(statusCode) {
            XCTAssertEqual(statusCode, 409)
        } catch {
            XCTFail("Expected NetworkError.responseError, got \(error)")
        }
    }

    func testNamedPolicyDoesNotApplyToAuthenticationSubrequests() async {
        HTTPErrorResponseURLProtocol.install([
            .response(
                statusCode: 401,
                body: Data(#"{"error":"Unauthorized"}"#.utf8)
            ),
            .response(
                statusCode: 409,
                body: Data(#"{"error":"AuthSubrequestConflict"}"#.utf8)
            ),
        ])
        let provider = HTTPErrorResponseAuthProvider(
            retryURL: baseURL.appendingPathComponent("oauth/token")
        )
        let networkService = NetworkService(baseURL: baseURL, authService: provider)
        await provider.install(networkService: networkService)

        do {
            _ = try await networkService
                .performRequestReturningHTTPErrorResponses(
                    request(path: "protected-resource"),
                    skipTokenRefresh: false
                )
            XCTFail("Expected the auth subrequest to keep strict status handling")
        } catch NetworkError.authenticationRequired {
            // The auth provider's strict 409 failure is mapped by the existing
            // 401 pipeline, rather than leaking the opt-in response policy.
        } catch {
            XCTFail("Expected NetworkError.authenticationRequired, got \(error)")
        }
        XCTAssertEqual(HTTPErrorResponseURLProtocol.requestCount, 2)
    }

    func testNamedPolicyDoesNotApplyWhenAuthenticationSubrequestChangesOnlyMethod() async {
        HTTPErrorResponseURLProtocol.install([
            .response(
                statusCode: 401,
                body: Data(#"{"error":"Unauthorized"}"#.utf8)
            ),
            .response(
                statusCode: 409,
                body: Data(#"{"error":"AuthSubrequestConflict"}"#.utf8)
            ),
        ])
        let provider = HTTPErrorResponseAuthProvider(retryMethod: "POST")
        let networkService = NetworkService(baseURL: baseURL, authService: provider)
        await provider.install(networkService: networkService)

        do {
            _ = try await networkService
                .performRequestReturningHTTPErrorResponses(
                    request(path: "protected-resource-method"),
                    skipTokenRefresh: false
                )
            XCTFail("Expected the method-distinct auth subrequest to remain strict")
        } catch NetworkError.authenticationRequired {
            // The TaskLocal policy is keyed by both method and URL.
        } catch {
            XCTFail("Expected NetworkError.authenticationRequired, got \(error)")
        }
        XCTAssertEqual(HTTPErrorResponseURLProtocol.requestCount, 2)
    }

    func testNamedPolicyDoesNotBleedToDifferentServiceWithSameRequestIdentity() async {
        HTTPErrorResponseURLProtocol.install([
            .response(
                statusCode: 401,
                body: Data(#"{"error":"Unauthorized"}"#.utf8)
            ),
            .response(
                statusCode: 409,
                body: Data(#"{"error":"NestedServiceConflict"}"#.utf8)
            ),
        ])
        let secondaryNetworkService = NetworkService(baseURL: baseURL)
        let provider = HTTPErrorResponseAuthProvider(
            retryNetworkService: secondaryNetworkService
        )
        let primaryNetworkService = NetworkService(
            baseURL: baseURL,
            authService: provider
        )
        await provider.install(networkService: primaryNetworkService)

        do {
            _ = try await primaryNetworkService
                .performRequestReturningHTTPErrorResponses(
                    request(path: "same-request-identity"),
                    skipTokenRefresh: false
                )
            XCTFail("Expected the secondary service's ordinary request to remain strict")
        } catch NetworkError.authenticationRequired {
            // Request policy belongs to both the initiating service and request.
        } catch {
            XCTFail("Expected NetworkError.authenticationRequired, got \(error)")
        }
        XCTAssertEqual(HTTPErrorResponseURLProtocol.requestCount, 2)
    }

    func testNamedPathReturnsFinal5xxAfterExistingRetries() async throws {
        let body = Data(#"{"error":"ServerError"}"#.utf8)
        HTTPErrorResponseURLProtocol.install(.response(statusCode: 503, body: body))
        let networkService = NetworkService(baseURL: baseURL)

        let (data, response) = try await networkService
            .performRequestReturningHTTPErrorResponses(
                request(path: "server-error"),
                skipTokenRefresh: false
            )

        XCTAssertEqual(response.statusCode, 503)
        XCTAssertEqual(data, body)
        XCTAssertEqual(HTTPErrorResponseURLProtocol.requestCount, 3)
    }

    func testNamedPathDoesNotConvertTransportErrorsIntoHTTPResponses() async {
        HTTPErrorResponseURLProtocol.install(.failure(URLError(.cancelled)))
        let networkService = NetworkService(baseURL: baseURL)

        do {
            _ = try await networkService.performRequestReturningHTTPErrorResponses(
                request(path: "cancelled"),
                skipTokenRefresh: false
            )
            XCTFail("Expected the transport error to propagate")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .cancelled)
        } catch {
            XCTFail("Expected URLError.cancelled, got \(error)")
        }
        XCTAssertEqual(HTTPErrorResponseURLProtocol.requestCount, 1)
    }

    func testExistingPathStillThrowsFor409() async {
        HTTPErrorResponseURLProtocol.install(
            .response(
                statusCode: 409,
                body: Data(#"{"error":"DestinationExists"}"#.utf8)
            )
        )
        let networkService = NetworkService(baseURL: baseURL)

        do {
            _ = try await networkService.performRequest(
                request(path: "legacy-conflict"),
                skipTokenRefresh: false
            )
            XCTFail("Expected the existing path to preserve its throwing behavior")
        } catch let NetworkError.responseError(statusCode) {
            XCTAssertEqual(statusCode, 409)
        } catch {
            XCTFail("Expected NetworkError.responseError, got \(error)")
        }
        XCTAssertEqual(HTTPErrorResponseURLProtocol.requestCount, 1)
    }

    func testConcurrentNamedAndExistingPathsDoNotSharePolicy() async {
        HTTPErrorResponseURLProtocol.install(
            .response(
                statusCode: 409,
                body: Data(#"{"error":"DestinationExists"}"#.utf8)
            )
        )
        let networkService = NetworkService(baseURL: baseURL)
        let namedRequest = request(path: "concurrent-named")
        let existingRequest = request(path: "concurrent-existing")

        async let named = Self.namedOutcome(
            networkService,
            request: namedRequest
        )
        async let existing = Self.existingOutcome(
            networkService,
            request: existingRequest
        )

        let outcomes = await (named, existing)
        XCTAssertEqual(outcomes.0, .returned(statusCode: 409))
        XCTAssertEqual(outcomes.1, .threwResponseError(statusCode: 409))
        XCTAssertEqual(HTTPErrorResponseURLProtocol.requestCount, 2)
    }

    private let baseURL = URL(string: "https://example.com")!

    private func request(path: String) -> URLRequest {
        URLRequest(url: baseURL.appendingPathComponent(path))
    }

    private static func namedOutcome(
        _ networkService: NetworkService,
        request: URLRequest
    ) async -> HTTPErrorResponseOutcome {
        do {
            let (_, response) = try await networkService
                .performRequestReturningHTTPErrorResponses(
                    request,
                    skipTokenRefresh: false
                )
            return .returned(statusCode: response.statusCode)
        } catch {
            return .otherError
        }
    }

    private static func existingOutcome(
        _ networkService: NetworkService,
        request: URLRequest
    ) async -> HTTPErrorResponseOutcome {
        do {
            let (_, response) = try await networkService.performRequest(
                request,
                skipTokenRefresh: false
            )
            return .returned(statusCode: response.statusCode)
        } catch let NetworkError.responseError(statusCode) {
            return .threwResponseError(statusCode: statusCode)
        } catch {
            return .otherError
        }
    }
}

private enum HTTPErrorResponseOutcome: Equatable {
    case returned(statusCode: Int)
    case threwResponseError(statusCode: Int)
    case otherError
}

private enum HTTPErrorResponseStubResult {
    case response(statusCode: Int, body: Data)
    case failure(URLError)
}

private actor HTTPErrorResponseAuthProvider: AuthenticationProvider {
    private var networkService: NetworkService?
    private let retryURL: URL?
    private let retryMethod: String?
    private let retryNetworkService: NetworkService?
    private(set) var refreshCount = 0
    private(set) var prepareCount = 0
    private(set) var unauthorizedCount = 0

    init(
        retryURL: URL? = nil,
        retryMethod: String? = nil,
        retryNetworkService: NetworkService? = nil
    ) {
        self.retryURL = retryURL
        self.retryMethod = retryMethod
        self.retryNetworkService = retryNetworkService
    }

    func install(networkService: NetworkService) {
        self.networkService = networkService
    }

    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        try await prepareAuthenticatedRequestWithContext(request).0
    }

    func prepareAuthenticatedRequestWithContext(
        _ request: URLRequest
    ) async throws -> (URLRequest, AuthContext) {
        prepareCount += 1
        var prepared = request
        prepared.setValue("Bearer test-token", forHTTPHeaderField: "Authorization")
        return (prepared, AuthContext(did: "did:plc:test", jkt: nil))
    }

    func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
        refreshCount += 1
        return .stillValid
    }

    func handleUnauthorizedResponse(
        _: HTTPURLResponse,
        data _: Data,
        for request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        unauthorizedCount += 1
        guard let requestNetworkService = retryNetworkService ?? networkService else {
            throw URLError(.resourceUnavailable)
        }
        var retryRequest = request
        if let retryURL {
            retryRequest.url = retryURL
        }
        if let retryMethod {
            retryRequest.httpMethod = retryMethod
        }
        let (data, response) = try await requestNetworkService.request(
            retryRequest,
            skipTokenRefresh: true,
            additionalHeaders: nil
        )
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, response)
    }

    func updateDPoPNonce(
        for _: URL,
        from _: [String: String],
        did _: String?,
        jkt _: String?
    ) async {}
}

private final class HTTPErrorResponseURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var results: [HTTPErrorResponseStubResult] = []
    private nonisolated(unsafe) static var recordedRequestCount = 0

    static var requestCount: Int {
        lock.withLock { recordedRequestCount }
    }

    static func install(_ result: HTTPErrorResponseStubResult) {
        install([result])
    }

    static func install(_ results: [HTTPErrorResponseStubResult]) {
        lock.withLock {
            self.results = results
            recordedRequestCount = 0
        }
    }

    static func reset() {
        lock.withLock {
            results = []
            recordedRequestCount = 0
        }
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let result = Self.lock.withLock { () -> HTTPErrorResponseStubResult? in
            guard !Self.results.isEmpty else { return nil }
            let index = min(Self.recordedRequestCount, Self.results.count - 1)
            Self.recordedRequestCount += 1
            return Self.results[index]
        }
        guard let result else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        switch result {
        case let .response(statusCode, body):
            guard let url = request.url,
                  let response = HTTPURLResponse(
                      url: url,
                      statusCode: statusCode,
                      httpVersion: "HTTP/1.1",
                      headerFields: ["Content-Type": "application/json"]
                  )
            else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
