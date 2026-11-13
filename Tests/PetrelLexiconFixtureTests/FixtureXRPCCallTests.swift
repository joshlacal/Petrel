import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import PetrelLexiconFixture
import XCTest

/// Calls generated for third-party lexicons, sent through the real `NetworkService`
/// pipeline to a stubbed transport.
///
/// XCTest rather than Swift Testing: the stub is installed through the process-wide
/// `NetworkService.setNetworkTestProtocolClasses`.
final class FixtureXRPCCallTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        NetworkService.setNetworkTestProtocolClasses([FixtureStubURLProtocol.self])
    }

    override class func tearDown() {
        FixtureStubURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses(nil)
        super.tearDown()
    }

    override func tearDown() {
        FixtureStubURLProtocol.reset()
        super.tearDown()
    }

    private func service() -> NetworkService {
        NetworkService(baseURL: URL(string: "https://example.com")!)
    }

    private let gadgetJSON = """
    {"$type":"com.example.widget.defs#gadget","id":"3jwdwj2ctlk26","meta":{"label":"left"},\
    "head":{"$link":"bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a"}}
    """

    private func sentJSON() throws -> NSDictionary {
        let body = try XCTUnwrap(FixtureStubURLProtocol.lastBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? NSDictionary)
    }

    // MARK: - text/event-stream queries (re-audit r-6)

    func testEventStreamQueryDecodesEachEventAndSendsTheParameterDefault() async throws {
        FixtureStubURLProtocol.install(
            status: 200,
            body: "data: {\"seq\":1,\"note\":\"caf\u{E9}\"}\n\n: keep-alive\n\ndata: not json\n\ndata: {\"seq\":2}\n\n",
            contentType: "text/event-stream"
        )

        let stream = try await ATProtoClient.Com(networkService: service()).example.widget.watchTicks(input: .init())
        var ticks: [ComExampleWidgetWatchTicks.Output] = []
        for try await tick in stream {
            ticks.append(tick)
        }

        // The undecodable event is skipped; the others arrive in order.
        XCTAssertEqual(ticks.map(\.seq), [1, 2])
        XCTAssertEqual(ticks.first?.note, "caf\u{E9}")
        let request = try XCTUnwrap(FixtureStubURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.path, "/xrpc/com.example.widget.watchTicks")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "text/event-stream")
        let items = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first { $0.name == "since" }?.value, "0")
    }

    func testEventStreamQueryRejectsAnotherContentType() async throws {
        FixtureStubURLProtocol.install(status: 200, body: "data: {\"seq\":1}\n\n")

        let stream = try await ATProtoClient.Com(networkService: service()).example.widget.watchTicks(input: .init())
        do {
            for try await _ in stream {}
            XCTFail("a JSON response is not an event stream")
        } catch let error as NetworkError {
            guard case .invalidContentType = error else {
                return XCTFail("expected invalidContentType, got \(error)")
            }
        }
    }

    // MARK: - NSIDs of any depth (lex-6)

    func testThreeSegmentNSIDIsCallableOnItsAuthorityNamespace() async throws {
        FixtureStubURLProtocol.install(status: 200, body: #"{"ok":true}"#)

        let (status, output) = try await ATProtoClient.Com(networkService: service()).example.getRoot()

        XCTAssertEqual(status, 200)
        XCTAssertEqual(output?.ok, true)
        XCTAssertEqual(FixtureStubURLProtocol.lastRequest?.url?.path, "/xrpc/com.example.getRoot")
        XCTAssertEqual(FixtureStubURLProtocol.lastRequest?.httpMethod, "GET")
    }

    func testFiveSegmentNSIDIsCallableAndSendsParametersUnderTheirWireNames() async throws {
        FixtureStubURLProtocol.install(status: 200, body: gadgetJSON)

        let (_, gadget) = try await ATProtoClient.Fm(networkService: service()).example.alpha.feed.getPlay(
            input: .init(
                play: ATProtocolURI(uriString: "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/com.example.widget.note/3jwdwj2ctlk26"),
                maxAge: 5,
                default: true,
                tags: ["a+b", "c"]
            )
        )

        XCTAssertEqual(gadget?.meta.label, "left")
        let url = try XCTUnwrap(FixtureStubURLProtocol.lastRequest?.url)
        XCTAssertEqual(url.path, "/xrpc/fm.example.alpha.feed.getPlay")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        // `max-age` is not a Swift identifier and `default` is a keyword; both go out as written.
        XCTAssertEqual(items.first { $0.name == "max-age" }?.value, "5")
        XCTAssertEqual(items.first { $0.name == "default" }?.value, "true")
        XCTAssertEqual(items.filter { $0.name == "tags" }.map(\.value), ["a+b", "c"])
        XCTAssertNil(items.first { $0.name == "maxAge" })
    }

    func testDeclaredErrorOfAThirdPartyEndpointIsTyped() async throws {
        FixtureStubURLProtocol.install(status: 400, body: #"{"error":"PlayNotFound","message":"gone"}"#)

        do {
            _ = try await ATProtoClient.Fm(networkService: service()).example.alpha.feed.getPlay(
                input: .init(play: ATProtocolURI(uriString: "at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/com.example.widget.note/3jwdwj2ctlk26"))
            )
            XCTFail("a 400 response must throw")
        } catch let error as ATProtoError<FmExampleAlphaFeedGetPlay.Error> {
            XCTAssertEqual(error.error, .playNotFound)
            XCTAssertEqual(error.message, "gone")
        }
    }

    // MARK: - Request and response bodies (v-1, lex-10)

    /// Seven segments, one hyphenated and one starting with a digit. The input schema is a
    /// `ref`: the body is the referenced object itself, not `{"data": {...}}`.
    func testRefInputIsSentUnwrappedAndUnionOutputIsDecoded() async throws {
        FixtureStubURLProtocol.install(status: 200, body: gadgetJSON)

        let (_, output) = try await ATProtoClient.Io(networkService: service())
            .mySite._4ever.deep.nested.ns.submitThing(input: .init(name: "widget", count: 2))

        guard case let .comExampleWidgetDefsGadget(gadget)? = output else {
            return XCTFail("expected the gadget variant of the union output, got \(String(describing: output))")
        }
        XCTAssertEqual(gadget.id.description, "3jwdwj2ctlk26")

        let request = try XCTUnwrap(FixtureStubURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.path, "/xrpc/io.my-site.4ever.deep.nested.ns.submitThing")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(try sentJSON(), ["name": "widget", "count": 2])
    }

    func testUnionOutputKeepsAVariantItDoesNotKnow() async throws {
        FixtureStubURLProtocol.install(status: 200, body: #"{"$type":"com.example.widget.defs#sprocket","teeth":12}"#)

        let (_, output) = try await ATProtoClient.Io(networkService: service())
            .mySite._4ever.deep.nested.ns.submitThing(input: .init(name: "widget"))

        guard case let .unexpected(container)? = output, case let .unknownType(type, _) = container else {
            return XCTFail("expected an unexpected variant, got \(String(describing: output))")
        }
        XCTAssertEqual(type, "com.example.widget.defs#sprocket")
    }

    func testUnionInputCarriesTheTypeOfItsVariant() async throws {
        FixtureStubURLProtocol.install(status: 200, body: "")

        let note = try ComExampleWidgetNote(
            text: "hi",
            createdAt: XCTUnwrap(ATProtocolDate(iso8601String: "2026-07-15T12:00:00.000Z"))
        )
        let status = try await ATProtoClient.Com(networkService: service()).example.widget.submitUnion(input: .init(note))

        XCTAssertEqual(status, 200)
        XCTAssertEqual(
            try sentJSON(),
            ["$type": "com.example.widget.note", "text": "hi", "created-at": "2026-07-15T12:00:00.000Z"]
        )
    }

    /// The body is not an image, so the default metadata stripping leaves it alone.
    func testWildcardBodyIsSentUntouchedWithQueryParameters() async throws {
        let blob = """
        {"blob":{"$type":"blob","ref":{"$link":"bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"},\
        "mimeType":"application/x-widget","size":4}}
        """
        FixtureStubURLProtocol.install(status: 200, body: blob)
        let bytes = Data([0x00, 0xFF, 0x10, 0x80])

        let (_, output) = try await ATProtoClient.Com(networkService: service()).example.widget.uploadThing(
            data: bytes,
            mimeType: "application/x-widget",
            params: .init(name: "left.widget")
        )

        XCTAssertEqual(output?.blob.mimeType, "application/x-widget")
        let request = try XCTUnwrap(FixtureStubURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.query, "name=left.widget")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-widget")
        XCTAssertEqual(FixtureStubURLProtocol.lastBody, bytes)
    }

    // MARK: - Subscriptions (streaming audit X-1)

    private func frame(header: [String: Any], payload: [String: Any]) throws -> Data {
        try DAGCBOR.encodeValue(header) + DAGCBOR.encodeValue(payload)
    }

    func testSubscriptionDecodesDeclaredMessageTypes() async throws {
        let data = try frame(header: ["op": 1, "t": "#deleted"], payload: ["seq": 7])

        let message = try await service().decodeSubscriptionFrame(
            data,
            as: ComExampleWidgetSubscribeThings.Message.self,
            endpoint: "com.example.widget.subscribeThings"
        )

        guard case let .deleted(deleted)? = message else {
            return XCTFail("expected a #deleted message, got \(String(describing: message))")
        }
        XCTAssertEqual(deleted.seq, 7)
        XCTAssertEqual(
            ComExampleWidgetSubscribeThings.Message.knownMessageTypes,
            ["com.example.widget.subscribeThings#created", "com.example.widget.subscribeThings#deleted"]
        )
    }

    /// The event-stream specification: clients ignore frames with a type they do not know.
    func testSubscriptionSkipsMessageTypesTheLexiconDoesNotDeclare() async throws {
        let data = try frame(header: ["op": 1, "t": "#renamed"], payload: ["seq": 8, "to": "x"])

        let message = try await service().decodeSubscriptionFrame(
            data,
            as: ComExampleWidgetSubscribeThings.Message.self,
            endpoint: "com.example.widget.subscribeThings"
        )

        XCTAssertNil(message)
    }

    /// ... and frames whose header carries an operation other than 1 (message) or -1 (error).
    func testSubscriptionSkipsUnknownFrameOperations() async throws {
        let data = try frame(header: ["op": 2, "t": "#deleted"], payload: ["seq": 9])

        let message = try await service().decodeSubscriptionFrame(
            data,
            as: ComExampleWidgetSubscribeThings.Message.self,
            endpoint: "com.example.widget.subscribeThings"
        )

        XCTAssertNil(message)
    }

    /// An error frame (`op: -1`) ends the stream with a typed error.
    func testSubscriptionErrorFrameThrowsATypedError() async throws {
        let data = try frame(header: ["op": -1], payload: ["error": "FutureCursor", "message": "cursor 99 is ahead"])

        do {
            _ = try await service().decodeSubscriptionFrame(
                data,
                as: ComExampleWidgetSubscribeThings.Message.self,
                endpoint: "com.example.widget.subscribeThings"
            )
            XCTFail("an error frame must throw")
        } catch let error as EventStreamError {
            XCTAssertEqual(error, .futureCursor(message: "cursor 99 is ahead"))
            // The name is the one the Lexicon declares.
            XCTAssertEqual(ComExampleWidgetSubscribeThings.Error(rawValue: error.name), .futureCursor)
        }
    }

    func testSubscriptionStillRejectsAMalformedDeclaredMessage() async throws {
        let data = try frame(header: ["op": 1, "t": "#deleted"], payload: ["seq": "not a number"])

        do {
            _ = try await service().decodeSubscriptionFrame(
                data,
                as: ComExampleWidgetSubscribeThings.Message.self,
                endpoint: "com.example.widget.subscribeThings"
            )
            XCTFail("a declared message that does not match its schema must throw")
        } catch is DecodingError {}
    }
}

/// Answers every request with one canned response and records what was sent.
final class FixtureStubURLProtocol: URLProtocol {
    private struct Stub {
        let status: Int
        let body: Data
        let contentType: String
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var stub: Stub?
    private nonisolated(unsafe) static var recordedRequest: URLRequest?
    private nonisolated(unsafe) static var recordedBody: Data?

    static var lastRequest: URLRequest? {
        lock.withLock { recordedRequest }
    }

    static var lastBody: Data? {
        lock.withLock { recordedBody }
    }

    static func install(status: Int, body: String, contentType: String = "application/json") {
        lock.withLock {
            stub = Stub(status: status, body: Data(body.utf8), contentType: contentType)
            recordedRequest = nil
            recordedBody = nil
        }
    }

    static func reset() {
        lock.withLock {
            stub = nil
            recordedRequest = nil
            recordedBody = nil
        }
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.read)
        let stub = Self.lock.withLock { () -> Stub? in
            Self.recordedRequest = request
            Self.recordedBody = body
            return Self.stub
        }
        guard let stub,
              let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: stub.status,
                  httpVersion: "HTTP/1.1",
                  headerFields: ["Content-Type": stub.contentType]
              )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func read(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 16384)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
