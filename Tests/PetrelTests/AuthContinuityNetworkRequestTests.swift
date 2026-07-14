import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import XCTest

final class AuthContinuityNetworkRequestTests: XCTestCase {
    private let baseURL = URL(string: "https://example.com")!

    override class func setUp() {
        super.setUp()
        NetworkService.setNetworkTestProtocolClasses([ExactAuthURLProtocol.self])
    }

    override class func tearDown() {
        NetworkService.setNetworkTestProtocolClasses(nil)
        super.tearDown()
    }

    func testExactResponseContentEncodingLookupIsCaseInsensitive() {
        let headerFields: [AnyHashable: Any] = ["cOnTeNt-EnCoDiNg": "br"]

        XCTAssertEqual(
            ContentDecoding.headerValue(named: "Content-Encoding", in: headerFields),
            "br"
        )
    }

    func testGeneratedEndpointUsesOnePreparedRequestWithoutRefresh() async throws {
        let fixture = await makeFixture()
        let result = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(
            matching: fixture.snapshot
        ) {
            try await fixture.client.com.atproto.server.describeServer()
        }

        assertPerformed(result, responseCode: 200)
        let requests = await fixture.transport.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer old-token")
        let refreshCount = await fixture.provider.refreshCount
        let prepareCount = await fixture.provider.prepareCount
        XCTAssertEqual(refreshCount, 0)
        XCTAssertEqual(prepareCount, 1)
    }

    func testProviderReplacesAllPreexistingCredentialHeaders() async throws {
        let fixture = await makeFixture()
        await fixture.client.networkService.setHeader(name: "Authorization", value: "Bearer attacker")
        await fixture.client.networkService.setHeader(name: "DPoP", value: "attacker-proof")
        await fixture.client.networkService.setHeader(name: "Cookie", value: "session=attacker")
        await fixture.client.networkService.setHeader(name: "Proxy-Authorization", value: "Basic attacker")

        let result = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            try await fixture.client.com.atproto.server.describeServer()
        }

        assertPerformed(result, responseCode: 200)
        let capturedRequest = await fixture.transport.requests.first
        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer old-token")
        XCTAssertNil(request.value(forHTTPHeaderField: "DPoP"))
        XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
        XCTAssertNil(request.value(forHTTPHeaderField: "Proxy-Authorization"))
    }

    func testOrdinaryRequestBehaviorResumesAfterScopeEnds() async throws {
        let fixture = await makeFixture()
        let scoped = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            try await fixture.client.com.atproto.server.describeServer()
        }
        assertPerformed(scoped, responseCode: 200)

        let ordinary = try await fixture.client.com.atproto.server.describeServer()
        XCTAssertEqual(ordinary.responseCode, 200)
        let requestCount = await fixture.transport.requests.count
        let refreshCount = await fixture.provider.refreshCount
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(refreshCount, 1)
    }

    func testPrepareGatedDriftSendsNothing() async throws {
        let prepareGate = AsyncGate(initiallyOpen: false)
        let fixture = await makeFixture(prepareGate: prepareGate)

        let task = Task {
            try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
                try await fixture.client.com.atproto.server.describeServer()
            }
        }
        await fixture.provider.waitForPrepare()
        await fixture.provider.mutate(token: "new-token")
        await prepareGate.open()

        let result = try await task.value
        assertContinuityChanged(result)
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 0)
    }

    func testProviderReplacementDuringPreparationSendsNothing() async throws {
        let prepareGate = AsyncGate(initiallyOpen: false)
        let fixture = await makeFixture(prepareGate: prepareGate)
        let replacement = ExactAuthProvider(
            snapshot: AuthContinuitySnapshot(did: "did:plc:replacement", mode: .gateway, generation: 1),
            token: "replacement-token",
            addAuthorization: true,
            preparedHeaders: [:],
            preparedURL: nil,
            prepareGate: nil
        )
        let task = Task {
            try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
                try await fixture.client.com.atproto.server.describeServer()
            }
        }
        await fixture.provider.waitForPrepare()
        await fixture.client.networkService.setAuthenticationProvider(replacement)
        await prepareGate.open()

        let result = try await task.value
        assertContinuityChanged(result)
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 0)
    }

    func testProviderSuppliedCookieFailsClosedBeforeLaunch() async throws {
        let fixture = await makeFixture(preparedHeaders: ["Cookie": "session=unexpected"])
        let result = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            try await fixture.client.com.atproto.server.describeServer()
        }

        assertContinuityChanged(result)
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 0)
    }

    func testCrossOriginRawRequestFailsBeforePreparingCredentials() async throws {
        let fixture = await makeFixture()
        let result = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            let request = URLRequest(url: URL(string: "https://example.org/xrpc/attacker")!)
            return try await fixture.client.networkService.performRequest(request)
        }

        assertContinuityChanged(result)
        let prepareCount = await fixture.provider.prepareCount
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(prepareCount, 0)
        XCTAssertEqual(requestCount, 0)
    }

    func testBaseURLDriftFailsBeforePreparingCredentials() async throws {
        let fixture = await makeFixture()
        let result = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            await fixture.client.networkService.setBaseURL(URL(string: "https://example.org")!)
            return try await fixture.client.com.atproto.server.describeServer()
        }

        assertContinuityChanged(result)
        let prepareCount = await fixture.provider.prepareCount
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(prepareCount, 0)
        XCTAssertEqual(requestCount, 0)
    }

    func testBaseURLDriftDuringPreparationSendsNothing() async throws {
        let prepareGate = AsyncGate(initiallyOpen: false)
        let fixture = await makeFixture(prepareGate: prepareGate)
        let task = Task {
            try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
                try await fixture.client.com.atproto.server.describeServer()
            }
        }
        await fixture.provider.waitForPrepare()
        try await fixture.client.networkService.setBaseURL(XCTUnwrap(URL(string: "https://example.org")))
        await prepareGate.open()

        let result = try await task.value
        assertContinuityChanged(result)
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 0)
    }

    func testBaseURLDriftWhileResponseHeldDiscardsResponse() async throws {
        let responseGate = AsyncGate(initiallyOpen: false)
        let fixture = await makeFixture(responseGate: responseGate)
        let task = Task {
            try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
                try await fixture.client.com.atproto.server.describeServer()
            }
        }
        await fixture.transport.waitForRequestCount(1)
        try await fixture.client.networkService.setBaseURL(XCTUnwrap(URL(string: "https://example.org")))
        await responseGate.open()

        let result = try await task.value
        assertContinuityChanged(result)
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 1)
    }

    func testProviderCannotRewritePreparedRequestOrigin() async throws {
        let fixture = try await makeFixture(preparedURL: XCTUnwrap(URL(string: "https://example.org/xrpc/attacker")))
        let result = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            try await fixture.client.com.atproto.server.describeServer()
        }

        assertContinuityChanged(result)
        let prepareCount = await fixture.provider.prepareCount
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(prepareCount, 1)
        XCTAssertEqual(requestCount, 0)
    }

    func testProviderCannotRewritePreparedRequestWithinSameOrigin() async throws {
        let fixture = try await makeFixture(
            preparedURL: XCTUnwrap(URL(string: "https://example.com/xrpc/com.atproto.server.createAccount?admin=true"))
        )
        let result = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            try await fixture.client.com.atproto.server.describeServer()
        }

        assertContinuityChanged(result)
        let prepareCount = await fixture.provider.prepareCount
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(prepareCount, 1)
        XCTAssertEqual(requestCount, 0)
    }

    func testResponseHeldDriftSendsOneOldAuthRequestThenDiscardsResponse() async throws {
        let responseGate = AsyncGate(initiallyOpen: false)
        let fixture = await makeFixture(responseGate: responseGate)

        let task = Task {
            try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
                try await fixture.client.com.atproto.server.describeServer()
            }
        }
        await fixture.transport.waitForRequestCount(1)
        await fixture.provider.mutate(token: "new-token")
        await responseGate.open()

        let result = try await task.value
        assertContinuityChanged(result)
        let requests = await fixture.transport.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer old-token")
    }

    func testExactScopeDoesNotReplay401NonceOrServerErrors() async throws {
        for status in [401, 500] {
            let fixture = await makeFixture(statusCode: status, headers: ["DPoP-Nonce": "do-not-store"])
            let result = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
                try await fixture.client.com.atproto.server.describeServer()
            }

            assertPerformed(result, responseCode: status)
            let requestCount = await fixture.transport.requests.count
            let refreshCount = await fixture.provider.refreshCount
            let unauthorizedCount = await fixture.provider.unauthorizedCount
            let nonceUpdateCount = await fixture.provider.nonceUpdateCount
            XCTAssertEqual(requestCount, 1)
            XCTAssertEqual(refreshCount, 0)
            XCTAssertEqual(unauthorizedCount, 0)
            XCTAssertEqual(nonceUpdateCount, 0)
        }
    }

    func testExactScopeDoesNotFollowRedirectOrCarryAuthorization() async throws {
        let fixture = await makeFixture(
            statusCode: 302,
            headers: ["Location": "https://redirect-target.example/xrpc/com.atproto.server.describeServer"]
        )
        let result = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            try await fixture.client.com.atproto.server.describeServer()
        }

        assertPerformed(result, responseCode: 302)
        let requests = await fixture.transport.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].url?.host, baseURL.host)
    }

    func testNoRedirectDelegateRejectsFoundationRedirectCallback() async throws {
        let delegate = HardenedURLSessionDelegate(allowsRedirects: false)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let originalURL = try XCTUnwrap(URL(string: "https://example.com/xrpc/original"))
        let redirectedURL = try XCTUnwrap(URL(string: "https://example.org/xrpc/redirected"))
        let task = session.dataTask(with: originalURL)
        let response = try XCTUnwrap(HTTPURLResponse(
            url: originalURL,
            statusCode: 302,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": redirectedURL.absoluteString]
        ))
        var redirectedRequest = URLRequest(url: redirectedURL)
        redirectedRequest.setValue("Bearer must-not-follow", forHTTPHeaderField: "Authorization")

        let acceptedRequest = await withCheckedContinuation { continuation in
            delegate.urlSession(
                session,
                task: task,
                willPerformHTTPRedirection: response,
                newRequest: redirectedRequest,
                completionHandler: { continuation.resume(returning: $0) }
            )
        }
        XCTAssertNil(acceptedRequest)
    }

    func testMissingAuthorizationFailsClosedBeforeLaunch() async throws {
        let fixture = await makeFixture(addAuthorization: false)
        let result = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            try await fixture.client.com.atproto.server.describeServer()
        }

        assertContinuityChanged(result)
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 0)
    }

    func testForeignNetworkServiceFailsClosedBeforeLaunch() async throws {
        let fixture = await makeFixture()
        let foreign = await makeFixture(host: "example.org")
        let foreignNetworkService = await foreign.client.networkService
        let result = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            let endpoint = ATProtoClient.Com.Atproto.Server(networkService: foreignNetworkService)
            return try await endpoint.describeServer()
        }

        assertContinuityChanged(result)
        let requestCount = await fixture.transport.requests.count
        let foreignRequestCount = await foreign.transport.requests.count
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(foreignRequestCount, 0)
    }

    func testMismatchedNestedScopeFailsWholeOperationClosed() async throws {
        let fixture = await makeFixture()
        let mismatched = AuthContinuitySnapshot(
            did: fixture.snapshot.did,
            mode: fixture.snapshot.mode,
            generation: fixture.snapshot.generation &+ 1
        )

        let result = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: mismatched) {
                try await fixture.client.com.atproto.server.describeServer()
            }
        }

        assertContinuityChanged(result)
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 0)
    }

    func testMatchingNestedScopePerformsExactlyOneRequest() async throws {
        let fixture = await makeFixture()
        let result = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
                try await fixture.client.com.atproto.server.describeServer()
            }
        }

        guard case let .performed(inner) = result else {
            return XCTFail("Expected outer scope to perform")
        }
        assertPerformed(inner, responseCode: 200)
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 1)
    }

    func testConcurrentScopeAcquisitionDoesNotOverwriteInstalledOwner() async throws {
        let heldSnapshotGate = AsyncGate(initiallyOpen: false)
        let secondOperationGate = AsyncGate(initiallyOpen: false)
        let secondOperationStarted = AsyncEvent()
        let fixture = await makeFixture()
        await fixture.provider.holdNextProviderSnapshot(on: heldSnapshotGate)

        let first = Task {
            try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
                try await fixture.client.com.atproto.server.describeServer()
            }
        }
        await fixture.provider.waitForHeldProviderSnapshot()

        let second = Task {
            try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
                await secondOperationStarted.signal()
                await secondOperationGate.wait()
                return try await fixture.client.com.atproto.server.describeServer()
            }
        }
        await secondOperationStarted.wait()

        await heldSnapshotGate.open()
        let firstResult = try await first.value
        assertContinuityChanged(firstResult)

        await secondOperationGate.open()
        let secondResult = try await second.value
        assertPerformed(secondResult, responseCode: 200)
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 1)
    }

    func testDestinationGenerationDriftDuringScopeAcquisitionFailsClosed() async throws {
        let heldSnapshotGate = AsyncGate(initiallyOpen: false)
        let fixture = await makeFixture()
        await fixture.provider.holdNextProviderSnapshot(on: heldSnapshotGate)

        let task = Task {
            try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
                try await fixture.client.com.atproto.server.describeServer()
            }
        }
        await fixture.provider.waitForHeldProviderSnapshot()
        await fixture.client.networkService.setBaseURL(baseURL)
        await heldSnapshotGate.open()

        let result = try await task.value
        assertContinuityChanged(result)
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 0)
    }

    func testZeroRequestClosureFailsClosedAndReleasesService() async throws {
        let fixture = await makeFixture()
        let empty = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            42
        }
        assertContinuityChanged(empty)

        let subsequent = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            try await fixture.client.com.atproto.server.describeServer()
        }
        assertPerformed(subsequent, responseCode: 200)
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 1)
    }

    func testEscapedInheritedTaskHeldBeforeLaunchCannotSendAfterScopeCleanup() async throws {
        let prepareGate = AsyncGate(initiallyOpen: false)
        let fixture = await makeFixture(prepareGate: prepareGate)
        let escaped = EscapedRequestTaskStore()

        let outer = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            let task = Task {
                try await fixture.client.com.atproto.server.describeServer()
            }
            await escaped.store(task)
            await fixture.provider.waitForPrepare()
            return 7
        }
        assertContinuityChanged(outer)
        await prepareGate.open()
        _ = try? await escaped.value()

        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 0)

        let subsequent = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            try await fixture.client.com.atproto.server.describeServer()
        }
        assertPerformed(subsequent, responseCode: 200)
        let finalCount = await fixture.transport.requests.count
        XCTAssertEqual(finalCount, 1)
    }

    func testEscapedInheritedTaskHeldAfterLaunchCannotCompleteScope() async throws {
        let responseGate = AsyncGate(initiallyOpen: false)
        let fixture = await makeFixture(responseGate: responseGate)
        let escaped = EscapedRequestTaskStore()

        let outer = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            let task = Task {
                try await fixture.client.com.atproto.server.describeServer()
            }
            await escaped.store(task)
            await fixture.transport.waitForRequestCount(1)
            return 7
        }
        assertContinuityChanged(outer)
        await responseGate.open()
        _ = try? await escaped.value()

        let firstCount = await fixture.transport.requests.count
        XCTAssertEqual(firstCount, 1)

        let subsequent = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            try await fixture.client.com.atproto.server.describeServer()
        }
        assertPerformed(subsequent, responseCode: 200)
        let finalCount = await fixture.transport.requests.count
        XCTAssertEqual(finalCount, 2)
    }

    func testStaleInheritedNestedScopeFailsAfterOwnerScopeEnds() async throws {
        let fixture = await makeFixture()
        let childGate = AsyncGate(initiallyOpen: false)
        let escaped = EscapedNestedScopeTaskStore()

        let outer = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            let task = Task {
                await childGate.wait()
                return try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
                    42
                }
            }
            await escaped.store(task)
            return try await fixture.client.com.atproto.server.describeServer()
        }
        assertPerformed(outer, responseCode: 200)
        await childGate.open()

        let stale = try await escaped.value()
        try assertContinuityChanged(XCTUnwrap(stale))
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 1)
    }

    func testInheritedTaskRemainsScoped() async throws {
        let fixture = await makeFixture()
        let result = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            try await Task {
                try await fixture.client.com.atproto.server.describeServer()
            }.value
        }

        assertPerformed(result, responseCode: 200)
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 1)
    }

    func testDetachedTaskCannotBypassActiveScope() async throws {
        let fixture = await makeFixture()
        let result = try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
            try await Task.detached {
                try await fixture.client.com.atproto.server.describeServer()
            }.value
        }

        assertContinuityChanged(result)
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 0)
    }

    func testCancellationBeforeLaunchSendsNothing() async {
        let prepareGate = AsyncGate(initiallyOpen: false)
        let fixture = await makeFixture(prepareGate: prepareGate)
        let task = Task {
            try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
                try await fixture.client.com.atproto.server.describeServer()
            }
        }
        await fixture.provider.waitForPrepare()
        task.cancel()
        await prepareGate.open()

        _ = try? await task.value
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 0)
    }

    func testCancellationAfterLaunchCannotUndoServerEffect() async {
        let responseGate = AsyncGate(initiallyOpen: false)
        let fixture = await makeFixture(responseGate: responseGate)
        let task = Task {
            try await fixture.client.performGeneratedRequestWithExactAuthContinuity(matching: fixture.snapshot) {
                try await fixture.client.com.atproto.server.describeServer()
            }
        }
        await fixture.transport.waitForRequestCount(1)
        task.cancel()
        await responseGate.open()

        _ = try? await task.value
        let requestCount = await fixture.transport.requests.count
        XCTAssertEqual(requestCount, 1)
    }

    private func makeFixture(
        host: String = "example.com",
        statusCode: Int = 200,
        headers: [String: String] = [:],
        addAuthorization: Bool = true,
        preparedHeaders: [String: String] = [:],
        preparedURL: URL? = nil,
        prepareGate: AsyncGate? = nil,
        responseGate: AsyncGate? = nil
    ) async -> Fixture {
        let url = URL(string: "https://\(host)")!
        let provider = ExactAuthProvider(
            snapshot: AuthContinuitySnapshot(did: "did:plc:exact", mode: .gateway, generation: 7),
            token: "old-token",
            addAuthorization: addAuthorization,
            preparedHeaders: preparedHeaders,
            preparedURL: preparedURL,
            prepareGate: prepareGate
        )
        let client = await ATProtoClient(baseURL: url)
        await client.networkService.setAuthenticationProvider(provider)
        let snapshot = await client.authContinuitySnapshot()
        let transport = ExactAuthTransport(statusCode: statusCode, headers: headers, responseGate: responseGate)
        ExactAuthURLProtocol.install(transport, forHost: host)
        return Fixture(client: client, provider: provider, transport: transport, snapshot: snapshot)
    }

    private func assertPerformed(
        _ result: AuthContinuityTransactionResult<(responseCode: Int, data: ComAtprotoServerDescribeServer.Output?)>,
        responseCode: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .performed(value) = result else {
            return XCTFail("Expected performed result", file: file, line: line)
        }
        XCTAssertEqual(value.responseCode, responseCode, file: file, line: line)
    }

    private func assertContinuityChanged<Value>(
        _ result: AuthContinuityTransactionResult<Value>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .continuityChanged = result else {
            return XCTFail("Expected continuityChanged", file: file, line: line)
        }
    }
}

private struct Fixture {
    let client: ATProtoClient
    let provider: ExactAuthProvider
    let transport: ExactAuthTransport
    let snapshot: AuthContinuitySnapshot
}

private actor EscapedRequestTaskStore {
    typealias Response = (responseCode: Int, data: ComAtprotoServerDescribeServer.Output?)
    private var task: Task<Response, Error>?

    func store(_ task: Task<Response, Error>) {
        self.task = task
    }

    func value() async throws -> Response? {
        try await task?.value
    }
}

private actor EscapedNestedScopeTaskStore {
    private var task: Task<AuthContinuityTransactionResult<Int>, Error>?

    func store(_ task: Task<AuthContinuityTransactionResult<Int>, Error>) {
        self.task = task
    }

    func value() async throws -> AuthContinuityTransactionResult<Int>? {
        try await task?.value
    }
}

private actor ExactAuthProvider: AuthContinuityProviding {
    private var snapshot: AuthContinuitySnapshot
    private var token: String
    private let addAuthorization: Bool
    private let preparedHeaders: [String: String]
    private let preparedURL: URL?
    private let prepareGate: AsyncGate?
    private var providerSnapshotGate: AsyncGate?
    private var shouldHoldNextProviderSnapshot = false
    private let heldProviderSnapshotEvent = AsyncEvent()
    private var observer: (@Sendable () async -> Void)?
    private let prepareEvent = AsyncEvent()
    private(set) var refreshCount = 0
    private(set) var prepareCount = 0
    private(set) var unauthorizedCount = 0
    private(set) var nonceUpdateCount = 0

    init(
        snapshot: AuthContinuitySnapshot,
        token: String,
        addAuthorization: Bool,
        preparedHeaders: [String: String],
        preparedURL: URL?,
        prepareGate: AsyncGate?
    ) {
        self.snapshot = snapshot
        self.token = token
        self.addAuthorization = addAuthorization
        self.preparedHeaders = preparedHeaders
        self.preparedURL = preparedURL
        self.prepareGate = prepareGate
    }

    func installAuthContinuityObserver(_ observer: @escaping @Sendable () async -> Void) async {
        self.observer = observer
    }

    func authContinuitySnapshot() async -> AuthContinuitySnapshot {
        snapshot
    }

    func authContinuityProviderSnapshot() async -> AuthContinuityProviderSnapshot {
        if shouldHoldNextProviderSnapshot, let providerSnapshotGate {
            shouldHoldNextProviderSnapshot = false
            await heldProviderSnapshotEvent.signal()
            await providerSnapshotGate.wait()
        }
        return .stable(snapshot)
    }

    func holdNextProviderSnapshot(on gate: AsyncGate) {
        providerSnapshotGate = gate
        shouldHoldNextProviderSnapshot = true
    }

    func waitForHeldProviderSnapshot() async {
        await heldProviderSnapshotEvent.wait()
    }

    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        try await prepareAuthenticatedRequestWithContext(request).0
    }

    func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (URLRequest, AuthContext) {
        prepareCount += 1
        let capturedToken = token
        await prepareEvent.signal()
        if let prepareGate { await prepareGate.wait() }
        var prepared = request
        if addAuthorization {
            prepared.setValue("Bearer \(capturedToken)", forHTTPHeaderField: "Authorization")
        }
        for (name, value) in preparedHeaders {
            prepared.setValue(value, forHTTPHeaderField: name)
        }
        if let preparedURL {
            prepared.url = preparedURL
        }
        return (prepared, AuthContext(did: snapshot.did, jkt: nil))
    }

    func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
        refreshCount += 1
        return .stillValid
    }

    func handleUnauthorizedResponse(
        _ response: HTTPURLResponse,
        data: Data,
        for _: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        unauthorizedCount += 1
        return (data, response)
    }

    func updateDPoPNonce(for _: URL, from _: [String: String], did _: String?, jkt _: String?) async {
        nonceUpdateCount += 1
    }

    func waitForPrepare() async {
        await prepareEvent.wait()
    }

    func mutate(token: String) async {
        await observer?()
        self.token = token
        snapshot = AuthContinuitySnapshot(
            did: snapshot.did,
            mode: snapshot.mode,
            generation: snapshot.generation &+ 1
        )
    }
}

private actor ExactAuthTransport {
    private let statusCode: Int
    private let headers: [String: String]
    private let responseGate: AsyncGate?
    private let requestEvent = AsyncEvent()
    private(set) var requests: [URLRequest] = []

    init(statusCode: Int, headers: [String: String], responseGate: AsyncGate?) {
        self.statusCode = statusCode
        self.headers = headers
        self.responseGate = responseGate
    }

    func handle(_ request: URLRequest, protocolInstance: ExactAuthURLProtocol) async {
        requests.append(request)
        await requestEvent.signal()
        if let responseGate { await responseGate.wait() }
        guard !Task.isCancelled, let url = request.url else { return }
        var responseHeaders = headers
        responseHeaders["Content-Type"] = responseHeaders["Content-Type"] ?? "application/json"
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: responseHeaders
        )!
        let body = Data(#"{"availableUserDomains":["example"],"did":"did:web:example"}"#.utf8)
        protocolInstance.client?.urlProtocol(protocolInstance, didReceive: response, cacheStoragePolicy: .notAllowed)
        protocolInstance.client?.urlProtocol(protocolInstance, didLoad: body)
        protocolInstance.client?.urlProtocolDidFinishLoading(protocolInstance)
    }

    func waitForRequestCount(_ count: Int) async {
        while requests.count < count {
            await requestEvent.wait()
        }
    }
}

private final class ExactAuthURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var transports: [String: ExactAuthTransport] = [:]
    private var loadingTask: Task<Void, Never>?

    static func install(_ transport: ExactAuthTransport, forHost host: String) {
        lock.withLock { transports[host] = transport }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        lock.withLock { transports[request.url?.host ?? ""] != nil }
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let host = request.url?.host,
              let transport = Self.lock.withLock({ Self.transports[host] })
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let box = ExactAuthURLProtocolBox(protocolInstance: self, request: request)
        loadingTask = Task {
            await transport.handle(box.request, protocolInstance: box.protocolInstance)
        }
    }

    override func stopLoading() {
        loadingTask?.cancel()
        loadingTask = nil
        client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
    }
}

private final class ExactAuthURLProtocolBox: @unchecked Sendable {
    let protocolInstance: ExactAuthURLProtocol
    let request: URLRequest

    init(protocolInstance: ExactAuthURLProtocol, request: URLRequest) {
        self.protocolInstance = protocolInstance
        self.request = request
    }
}

private actor AsyncEvent {
    private var signaled = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func signal() {
        signaled = true
        let current = waiters
        waiters.removeAll()
        current.forEach { $0.resume() }
    }

    func wait() async {
        if signaled {
            signaled = false
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }
}

private actor AsyncGate {
    private var isOpen: Bool
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(initiallyOpen: Bool) {
        isOpen = initiallyOpen
    }

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let current = waiters
        waiters.removeAll()
        current.forEach { $0.resume() }
    }
}
