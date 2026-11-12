import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import XCTest

/// Wire behaviour of generated XRPC calls, exercised through the real `NetworkService`
/// pipeline against a stubbed transport.
///
/// XCTest rather than Swift Testing: the stub is installed through the process-wide
/// `NetworkService.setNetworkTestProtocolClasses`, which the suites sharing it serialise
/// on by running as XCTest classes.
final class GeneratedXRPCCallTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        NetworkService.setNetworkTestProtocolClasses([XRPCStubURLProtocol.self])
    }

    override class func tearDown() {
        XRPCStubURLProtocol.reset()
        NetworkService.setNetworkTestProtocolClasses(nil)
        super.tearDown()
    }

    override func tearDown() {
        XRPCStubURLProtocol.reset()
        super.tearDown()
    }

    private let baseURL = URL(string: "https://example.com")!

    private func client() -> ATProtoClient.App {
        ATProtoClient.App(networkService: NetworkService(baseURL: baseURL))
    }

    private func atproto() -> ATProtoClient.Com.Atproto {
        ATProtoClient.Com(networkService: NetworkService(baseURL: baseURL)).atproto
    }

    // MARK: - Error envelope (lex-3)

    /// `app.bsky.feed.getTimeline` declares no errors. The server's envelope must still reach
    /// the caller, with the status code and headers.
    func testEndpointWithoutDeclaredErrorsThrowsTheEnvelope() async throws {
        XRPCStubURLProtocol.install(
            status: 400,
            body: #"{"error":"InvalidRequest","message":"limit must be at most 100"}"#
        )

        do {
            _ = try await client().bsky.feed.getTimeline(input: .init(limit: 500))
            XCTFail("a 400 response must throw")
        } catch let error as ATProtoXRPCError {
            XCTAssertEqual(error.error, "InvalidRequest")
            XCTAssertEqual(error.message, "limit must be at most 100")
            XCTAssertEqual(error.statusCode, 400)
            XCTAssertEqual(error.headers["content-type"], "application/json")
        }
    }

    /// Statuses 402-499 used to surface as a bare `NetworkError.responseError(statusCode:)`.
    func testRateLimitResponseCarriesTheEnvelopeAndRateLimitHeaders() async throws {
        XRPCStubURLProtocol.install(
            status: 429,
            body: #"{"error":"RateLimitExceeded","message":"Rate Limit Exceeded"}"#,
            headers: [
                "RateLimit-Limit": "3000",
                "RateLimit-Remaining": "0",
                "RateLimit-Reset": "1767225600",
                "RateLimit-Policy": "3000;w=300",
                "Retry-After": "42",
            ]
        )

        do {
            _ = try await client().bsky.feed.getTimeline(input: .init())
            XCTFail("a 429 response must throw")
        } catch let error as ATProtoXRPCError {
            XCTAssertEqual(error.error, "RateLimitExceeded")
            XCTAssertEqual(error.statusCode, 429)
            XCTAssertEqual(
                error.rateLimit,
                XRPCRateLimit(
                    limit: 3000,
                    remaining: 0,
                    reset: Date(timeIntervalSince1970: 1_767_225_600),
                    policy: "3000;w=300"
                )
            )
            XCTAssertEqual(error.retryAfter, 42)
        }
    }

    /// `com.atproto.repo.getRecord` declares `RecordNotFound`: a declared name is thrown typed.
    func testDeclaredErrorIsThrownTyped() async throws {
        XRPCStubURLProtocol.install(
            status: 400,
            body: #"{"error":"RecordNotFound","message":"Could not locate record"}"#
        )

        do {
            _ = try await atproto().repo.getRecord(input: getRecordParameters())
            XCTFail("a 400 response must throw")
        } catch let error as ATProtoError<ComAtprotoRepoGetRecord.Error> {
            XCTAssertEqual(error.error, .recordNotFound)
            XCTAssertEqual(error.message, "Could not locate record")
            XCTAssertEqual(error.statusCode, 400)
        }
    }

    /// The same endpoint answering with a name its Lexicon does not declare used to return
    /// `(400, nil)`; the envelope must not be dropped.
    func testUndeclaredErrorOnAnEndpointWithDeclaredErrorsThrowsTheEnvelope() async throws {
        XRPCStubURLProtocol.install(
            status: 403,
            body: #"{"error":"AccountTakedown","message":"Account has been taken down"}"#
        )

        do {
            _ = try await atproto().repo.getRecord(input: getRecordParameters())
            XCTFail("a 403 response must throw")
        } catch let error as ATProtoXRPCError {
            XCTAssertEqual(error.error, "AccountTakedown")
            XCTAssertEqual(error.message, "Account has been taken down")
            XCTAssertEqual(error.statusCode, 403)
        }
    }

    /// A gateway that answers with HTML still produces a typed error: no envelope to quote,
    /// so the status is the error and the body text is the message.
    func testNonEnvelopeErrorBodyIsReportedWithItsStatus() async throws {
        XRPCStubURLProtocol.install(
            status: 404,
            body: "<html>not here</html>",
            headers: ["Content-Type": "text/html"]
        )

        do {
            _ = try await client().bsky.feed.getTimeline(input: .init())
            XCTFail("a 404 response must throw")
        } catch let error as ATProtoXRPCError {
            XCTAssertEqual(error.error, "HTTP 404")
            XCTAssertEqual(error.message, "<html>not here</html>")
            XCTAssertEqual(error.statusCode, 404)
        }
    }

    func testEmptyErrorBodyIsReportedWithItsStatus() async throws {
        XRPCStubURLProtocol.install(status: 403, body: "")

        do {
            _ = try await client().bsky.feed.getTimeline(input: .init())
            XCTFail("a 403 response must throw")
        } catch let error as ATProtoXRPCError {
            XCTAssertEqual(error.error, "HTTP 403")
            XCTAssertNil(error.message)
        }
    }

    /// A procedure without an output schema returns only the status code, and must throw the
    /// envelope too.
    func testProcedureWithoutOutputThrowsTheEnvelope() async throws {
        XRPCStubURLProtocol.install(
            status: 400,
            body: #"{"error":"InvalidRequest","message":"Input/handle must be a valid handle"}"#
        )

        do {
            _ = try await atproto().identity.updateHandle(
                input: .init(handle: Handle(handleString: "alice.test"))
            )
            XCTFail("a 400 response must throw")
        } catch let error as ATProtoXRPCError {
            XCTAssertEqual(error.error, "InvalidRequest")
            XCTAssertEqual(error.statusCode, 400)
        }
    }

    /// A 2xx body that does not match the output schema used to come back as `(200, nil)`.
    func testUndecodableSuccessBodyThrows() async throws {
        XRPCStubURLProtocol.install(status: 200, body: #"{"feed":"not an array"}"#)

        do {
            _ = try await client().bsky.feed.getTimeline(input: .init())
            XCTFail("an undecodable 200 response must throw")
        } catch let error as XRPCResponseDecodingError {
            XCTAssertEqual(error.endpoint, "app.bsky.feed.getTimeline")
            XCTAssertEqual(error.statusCode, 200)
            XCTAssertTrue(error.underlying is DecodingError)
        }
    }

    func testSuccessReturnsTheStatusAndDecodedBody() async throws {
        XRPCStubURLProtocol.install(status: 200, body: #"{"feed":[],"cursor":"abc"}"#)

        let (status, output) = try await client().bsky.feed.getTimeline(input: .init())

        XCTAssertEqual(status, 200)
        XCTAssertEqual(output?.cursor, "abc")
        XCTAssertEqual(output?.feed.count, 0)
    }

    /// HTTP/2 servers send lowercase header names, and swift-corelibs-foundation does not
    /// canonicalize `allHeaderFields`, so an exact-case `"Content-Type"` lookup missed them.
    func testQueryAcceptsALowercaseContentTypeHeader() async throws {
        XRPCStubURLProtocol.install(
            status: 200,
            body: #"{"feed":[],"cursor":"abc"}"#,
            headers: ["content-type": "application/json; charset=utf-8"]
        )

        let (status, output) = try await client().bsky.feed.getTimeline(input: .init())

        XCTAssertEqual(status, 200)
        XCTAssertEqual(output?.cursor, "abc")
    }

    func testProcedureAcceptsALowercaseContentTypeHeader() async throws {
        XRPCStubURLProtocol.install(status: 200, body: "{}", headers: ["content-type": "application/json"])

        let (status, output) = try await client().bsky.feed.sendInteractions(input: .init(interactions: []))

        XCTAssertEqual(status, 200)
        XCTAssertNotNil(output)
    }

    /// swift-corelibs-foundation title-cases every response header name
    /// (`Atproto-Content-Labelers`), so an exact lowercase lookup found nothing on Linux.
    func testContentLabelersHeaderIsReadWhateverItsCase() async throws {
        let service = NetworkService(baseURL: baseURL)
        for name in ["atproto-content-labelers", "Atproto-Content-Labelers", "ATPROTO-CONTENT-LABELERS"] {
            let response = try XCTUnwrap(HTTPURLResponse(
                url: baseURL,
                statusCode: 200,
                httpVersion: "HTTP/2",
                headerFields: [name: "did:plc:alpha;redact, did:plc:beta"]
            ))
            let labelers = await service.extractContentLabelers(from: response)
            XCTAssertEqual(labelers.map(\.did), ["did:plc:alpha", "did:plc:beta"], name)
            XCTAssertEqual(labelers.map(\.redact), [true, false], name)
        }
    }

    func testLowercaseContentTypeIsStillCheckedAgainstTheOutputEncoding() async throws {
        XRPCStubURLProtocol.install(status: 200, body: "<html></html>", headers: ["content-type": "text/html"])

        do {
            _ = try await client().bsky.feed.getTimeline(input: .init())
            XCTFail("a text/html body must not be decoded as JSON")
        } catch let NetworkError.invalidContentType(expected, actual) {
            XCTAssertEqual(expected, "application/json")
            XCTAssertEqual(actual, "text/html")
        }
    }

    // MARK: - Query string (v-2)

    /// `URLComponents` leaves `+` literal; servers that parse the query as form data read it
    /// as a space.
    func testPlusIsPercentEncodedInQueryValues() async throws {
        XRPCStubURLProtocol.install(status: 200, body: #"{"posts":[]}"#)

        _ = try await client().bsky.feed.searchPosts(
            input: .init(q: "c++ & 1+1=2", since: "2026-01-01T00:00:00+01:00", cursor: "a+b/c==")
        )

        let query = try XCTUnwrap(XRPCStubURLProtocol.lastRequest?.url?.query(percentEncoded: true))
        XCTAssertFalse(query.contains("+"), "literal '+' left in \(query)")
        XCTAssertTrue(query.contains("q=c%2B%2B%20%26%201%2B1%3D2"), query)
        XCTAssertTrue(query.contains("since=2026-01-01T00:00:00%2B01:00"), query)
        XCTAssertTrue(query.contains("cursor=a%2Bb/c%3D%3D"), query)

        // What a form-decoding server reads back.
        let items = URLComponents(string: "https://example.com/?" + query)?.queryItems ?? []
        XCTAssertEqual(items.first { $0.name == "q" }?.value, "c++ & 1+1=2")
        XCTAssertEqual(items.first { $0.name == "cursor" }?.value, "a+b/c==")
    }

    // MARK: - Blob upload (lex-5, bsky-6)

    private let blobResponse = """
    {"blob":{"$type":"blob","ref":{"$link":"bafkreihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"},\
    "mimeType":"application/octet-stream","size":256}}
    """

    /// A 1x1 PNG carrying a `tEXt` chunk, the kind of metadata an upload must not leak.
    private func pngWithTextChunk(_ text: String) throws -> Data {
        let png = try XCTUnwrap(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="))
        func crc32(_ bytes: [UInt8]) -> UInt32 {
            var crc: UInt32 = 0xFFFF_FFFF
            for byte in bytes {
                crc ^= UInt32(byte)
                for _ in 0 ..< 8 {
                    crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
                }
            }
            return ~crc
        }
        func bigEndian(_ value: UInt32) -> [UInt8] {
            [UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
        }
        let typeAndData = Array("tEXt".utf8) + Array("Comment".utf8) + [0] + Array(text.utf8)
        let chunk = bigEndian(UInt32(typeAndData.count - 4)) + typeAndData + bigEndian(crc32(typeAndData))
        // Signature (8 bytes) + IHDR chunk (25 bytes), then the new chunk, then the rest.
        return png.prefix(33) + Data(chunk) + png.dropFirst(33)
    }

    /// The default removes image metadata, in the image's own format and under the
    /// caller's Content-Type. No pixel is re-encoded.
    func testUploadBlobStripsImageMetadataByDefault() async throws {
        let secret = "GPS 37.7749,-122.4194"
        let png = try pngWithTextChunk(secret)
        XCTAssertNotNil(png.range(of: Data(secret.utf8)))
        XRPCStubURLProtocol.install(status: 200, body: blobResponse)

        _ = try await atproto().repo.uploadBlob(data: png, mimeType: "image/png")

        let request = try XCTUnwrap(XRPCStubURLProtocol.lastRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "image/png")
        let body = try XCTUnwrap(XRPCStubURLProtocol.lastBody)
        XCTAssertNil(body.range(of: Data(secret.utf8)), "the metadata was uploaded")
        XCTAssertNil(body.range(of: Data("tEXt".utf8)))
        XCTAssertEqual(body.prefix(8), png.prefix(8), "still a PNG")
        // Everything but the metadata chunk is byte-identical: nothing was re-encoded.
        XCTAssertEqual(body, try pngWithoutTextChunk(png))
    }

    private func pngWithoutTextChunk(_ png: Data) throws -> Data {
        let start = try XCTUnwrap(png.range(of: Data("tEXt".utf8))).lowerBound - 4
        let length = png[start ..< start + 4].reduce(0) { ($0 << 8) | Int($1) }
        return png.prefix(upTo: start) + png.suffix(from: start + 12 + length)
    }

    /// `stripMetadata: false` sends the caller's bytes, metadata included.
    func testUploadBlobSendsTheBodyUntouchedWhenNotStripping() async throws {
        let png = try pngWithTextChunk("keep me")
        XRPCStubURLProtocol.install(status: 200, body: blobResponse)

        _ = try await atproto().repo.uploadBlob(data: png, mimeType: "image/png", stripMetadata: false)

        XCTAssertEqual(XRPCStubURLProtocol.lastBody, png)
    }

    /// A body that is not an image is opaque: with the default it goes out byte for byte,
    /// under the caller's Content-Type.
    func testUploadBlobSendsNonImageBodiesUntouched() async throws {
        let mp4 = Data([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70]) + Data(repeating: 0xAB, count: 256)
        let octets = Data((0 ... 255).map { UInt8($0) })

        for (data, mimeType) in [(mp4, "video/mp4"), (octets, "application/octet-stream"), (octets, "text/vtt")] {
            XRPCStubURLProtocol.install(status: 200, body: blobResponse)

            let (status, output) = try await atproto().repo.uploadBlob(data: data, mimeType: mimeType)

            XCTAssertEqual(status, 200)
            XCTAssertNotNil(output?.blob)
            let request = try XCTUnwrap(XRPCStubURLProtocol.lastRequest)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), mimeType)
            XCTAssertEqual(XRPCStubURLProtocol.lastBody, data, "\(mimeType) body was modified")
        }
    }

    /// Fail closed: an image whose metadata cannot be removed is not uploaded.
    func testUploadBlobRefusesAnImageItCannotStrip() async throws {
        // A PNG signature followed by bytes that are not chunks.
        let broken = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) + Data((0 ..< 64).map { UInt8($0) })
        XRPCStubURLProtocol.install(status: 200, body: blobResponse)

        do {
            _ = try await atproto().repo.uploadBlob(data: broken, mimeType: "image/png")
            XCTFail("an image that cannot be stripped must not be uploaded")
        } catch NetworkError.metadataStrippingFailed {}
        XCTAssertNil(XRPCStubURLProtocol.lastRequest)

        // The caller can still choose to send exactly these bytes.
        _ = try await atproto().repo.uploadBlob(data: broken, mimeType: "image/png", stripMetadata: false)
        XCTAssertEqual(XRPCStubURLProtocol.lastBody, broken)
    }

    // MARK: - Untyped calls (lex-7)

    func testUntypedQuerySendsParametersAndReturnsBodyAndHeaders() async throws {
        XRPCStubURLProtocol.install(
            status: 200,
            body: #"{"$type":"com.example.widget.defs#thing","name":"left","count":2}"#,
            headers: ["atproto-repo-rev": "3lqz2zlqr5c2x", "atproto-content-labelers": "did:plc:labeler1;redact, did:plc:labeler2"]
        )

        let response = try await NetworkService(baseURL: baseURL).xrpcQuery(
            "com.example.widget.getThing",
            parameters: [
                URLQueryItem(name: "id", value: "3jwdwj2ctlk26"),
                URLQueryItem(name: "tag", value: "a+b"),
                URLQueryItem(name: "tag", value: "c"),
            ]
        )

        let request = try XCTUnwrap(XRPCStubURLProtocol.lastRequest)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/xrpc/com.example.widget.getThing")
        XCTAssertEqual(request.url?.query(percentEncoded: true), "id=3jwdwj2ctlk26&tag=a%2Bb&tag=c")

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.metadata.repoRev, "3lqz2zlqr5c2x")
        XCTAssertEqual(
            response.metadata.contentLabelers,
            [XRPCLabeler(did: "did:plc:labeler1", redact: true), XRPCLabeler(did: "did:plc:labeler2")]
        )
        guard case let .unknownType(type, .object(fields)) = try response.json() else {
            return XCTFail("expected an untyped object with its $type")
        }
        XCTAssertEqual(type, "com.example.widget.defs#thing")
        XCTAssertEqual(fields["name"], .string("left"))
        XCTAssertEqual(fields["count"], .number(2))

        struct Thing: Decodable, Equatable {
            let name: String
            let count: Int
        }
        XCTAssertEqual(try response.decode(Thing.self), Thing(name: "left", count: 2))
    }

    func testUntypedProcedureSendsJSONAndBinaryBodies() async throws {
        let service = NetworkService(baseURL: baseURL)

        XRPCStubURLProtocol.install(status: 200, body: #"{"ok":true}"#)
        _ = try await service.xrpcProcedure(
            "com.example.widget.createThing",
            body: .json(encoding: ["name": "left"])
        )
        var request = try XCTUnwrap(XRPCStubURLProtocol.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/xrpc/com.example.widget.createThing")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(XRPCStubURLProtocol.lastBody, Data(#"{"name":"left"}"#.utf8))

        let bytes = Data([0x00, 0xFF, 0x7F, 0x80])
        XRPCStubURLProtocol.install(status: 200, body: "")
        let response = try await service.xrpcProcedure(
            "com.example.widget.uploadThing",
            parameters: [URLQueryItem(name: "name", value: "left.bin")],
            body: .bytes(bytes, contentType: "application/x-widget")
        )
        request = try XCTUnwrap(XRPCStubURLProtocol.lastRequest)
        XCTAssertEqual(request.url?.query, "name=left.bin")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-widget")
        XCTAssertEqual(XRPCStubURLProtocol.lastBody, bytes)
        XCTAssertEqual(response.body, Data())
    }

    func testUntypedCallThrowsTheErrorEnvelope() async throws {
        XRPCStubURLProtocol.install(status: 400, body: #"{"error":"ThingNotFound","message":"no such thing"}"#)

        do {
            _ = try await NetworkService(baseURL: baseURL).xrpcQuery("com.example.widget.getThing")
            XCTFail("a 400 response must throw")
        } catch let error as ATProtoXRPCError {
            XCTAssertEqual(error.error, "ThingNotFound")
            XCTAssertEqual(error.message, "no such thing")
            XCTAssertEqual(error.statusCode, 400)
        }
    }

    func testUntypedCallRejectsAnythingThatIsNotAnNSID() async throws {
        XRPCStubURLProtocol.install(status: 200, body: "{}")

        for invalid in ["getThing", "com.example/../../admin", "com.example.get thing", ""] {
            do {
                _ = try await NetworkService(baseURL: baseURL).xrpcQuery(invalid)
                XCTFail("'\(invalid)' is not an NSID and must be rejected")
            } catch is ATProtoXRPCError {
                XCTFail("'\(invalid)' reached the network")
            } catch {}
        }
        XCTAssertNil(XRPCStubURLProtocol.lastRequest)
    }

    // MARK: - Per-call options and response metadata (lex-8)

    func testCallOptionsSetHeadersProxyAndLabelersForOneUntypedCall() async throws {
        let service = NetworkService(baseURL: baseURL)
        await service.setServiceDID("did:web:api.example.com#default_appview", for: "com.example")
        XRPCStubURLProtocol.install(status: 200, body: "{}")

        _ = try await service.xrpcQuery(
            "com.example.widget.getThing",
            options: XRPCCallOptions(
                headers: ["X-Widget-Trace": "abc"],
                proxy: "did:web:other.example.com#widget_view",
                acceptLabelers: [XRPCLabeler(did: "did:plc:labeler1", redact: true), XRPCLabeler(did: "did:plc:labeler2")]
            )
        )
        var request = try XCTUnwrap(XRPCStubURLProtocol.lastRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Widget-Trace"), "abc")
        XCTAssertEqual(request.value(forHTTPHeaderField: "atproto-proxy"), "did:web:other.example.com#widget_view")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "atproto-accept-labelers"),
            "did:plc:labeler1;redact, did:plc:labeler2"
        )

        // Without options the next call falls back to the client's routing and sends none
        // of the per-call headers.
        XRPCStubURLProtocol.install(status: 200, body: "{}")
        _ = try await service.xrpcQuery("com.example.widget.getThing")
        request = try XCTUnwrap(XRPCStubURLProtocol.lastRequest)
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Widget-Trace"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "atproto-proxy"), "did:web:api.example.com#default_appview")
        XCTAssertNil(request.value(forHTTPHeaderField: "atproto-accept-labelers"))
    }

    /// Header names are case-insensitive. Layers merged by exact spelling kept both
    /// `atproto-proxy` and `Atproto-Proxy`, and which one URLRequest ended up sending
    /// depended on dictionary iteration order.
    func testCallOptionHeadersReplaceBaseHeadersWhateverTheirCase() {
        let merged = XRPCCallOptions(headers: ["Atproto-Proxy": "did:web:caller.example#svc"])
            .requestHeaders(over: ["atproto-proxy": "did:web:default.example#svc", "X-Other": "kept"])
        XCTAssertEqual(merged, ["Atproto-Proxy": "did:web:caller.example#svc", "X-Other": "kept"])

        let withFields = XRPCCallOptions(
            headers: ["ATPROTO-PROXY": "did:web:header.example#svc", "Atproto-Accept-Labelers": "did:plc:old"],
            proxy: "did:web:field.example#svc",
            acceptLabelers: [XRPCLabeler(did: "did:plc:new")]
        ).requestHeaders(over: nil)
        XCTAssertEqual(withFields, ["atproto-proxy": "did:web:field.example#svc", "atproto-accept-labelers": "did:plc:new"])
    }

    func testCallerProxyHeaderInAnyCaseWinsOverDefaultRouting() async throws {
        let service = NetworkService(baseURL: baseURL)
        await service.setServiceDID("did:web:api.example.com#default_appview", for: "com.example")
        for spelling in ["atproto-proxy", "Atproto-Proxy", "ATPROTO-PROXY"] {
            XRPCStubURLProtocol.install(status: 200, body: "{}")
            _ = try await service.xrpcQuery(
                "com.example.widget.getThing",
                options: XRPCCallOptions(headers: [spelling: "did:web:other.example.com#widget_view"])
            )
            let request = try XCTUnwrap(XRPCStubURLProtocol.lastRequest)
            XCTAssertEqual(request.value(forHTTPHeaderField: "atproto-proxy"), "did:web:other.example.com#widget_view", spelling)
        }
    }

    func testServiceWideHeadersAreKeyedCaseInsensitively() async throws {
        let service = NetworkService(baseURL: baseURL)
        for attempt in 0 ..< 8 {
            await service.setHeader(name: "X-Widget-Client", value: "first-\(attempt)")
            await service.setHeader(name: "x-widget-client", value: "second-\(attempt)")
            let stored = await service.getHeader(name: "X-WIDGET-CLIENT")
            XCTAssertEqual(stored, "second-\(attempt)")

            XRPCStubURLProtocol.install(status: 200, body: "{}")
            _ = try await service.xrpcQuery("com.example.widget.getThing")
            let request = try XCTUnwrap(XRPCStubURLProtocol.lastRequest)
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-widget-client"), "second-\(attempt)")
        }
        await service.removeHeader(name: "X-WIDGET-CLIENT")
        let removed = await service.getHeader(name: "x-widget-client")
        XCTAssertNil(removed)
    }

    /// The explicit options of an untyped call win over an enclosing scope as a whole: an
    /// explicit `atproto-proxy` header beats a scoped `proxy`, though both name the same header.
    func testExplicitProxyHeaderBeatsAScopedProxyOption() async throws {
        let service = NetworkService(baseURL: baseURL)
        for spelling in ["atproto-proxy", "Atproto-Proxy"] {
            XRPCStubURLProtocol.install(status: 200, body: "{}")
            _ = try await NetworkService.withCallOptions(XRPCCallOptions(proxy: "did:web:scoped.example.com#svc")) {
                try await service.xrpcQuery(
                    "com.example.widget.getThing",
                    options: XRPCCallOptions(headers: [spelling: "did:web:explicit.example.com#svc"])
                )
            }
            let request = try XCTUnwrap(XRPCStubURLProtocol.lastRequest)
            XCTAssertEqual(request.value(forHTTPHeaderField: "atproto-proxy"), "did:web:explicit.example.com#svc", spelling)
        }
    }

    func testExplicitLabelersHeaderBeatsScopedLabelersOption() async throws {
        let service = NetworkService(baseURL: baseURL)
        XRPCStubURLProtocol.install(status: 200, body: "{}")
        _ = try await NetworkService.withCallOptions(
            XRPCCallOptions(acceptLabelers: [XRPCLabeler(did: "did:plc:scoped")])
        ) {
            try await service.xrpcQuery(
                "com.example.widget.getThing",
                options: XRPCCallOptions(headers: ["Atproto-Accept-Labelers": "did:plc:explicit"])
            )
        }
        let request = try XCTUnwrap(XRPCStubURLProtocol.lastRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "atproto-accept-labelers"), "did:plc:explicit")
    }

    /// The reverse still holds: an explicit typed option beats a scoped header.
    func testExplicitProxyOptionBeatsAScopedProxyHeader() async throws {
        let service = NetworkService(baseURL: baseURL)
        XRPCStubURLProtocol.install(status: 200, body: "{}")
        _ = try await NetworkService.withCallOptions(XRPCCallOptions(headers: ["atproto-proxy": "did:web:scoped.example.com#svc"])) {
            try await service.xrpcQuery(
                "com.example.widget.getThing",
                options: XRPCCallOptions(proxy: "did:web:explicit.example.com#svc")
            )
        }
        let request = try XCTUnwrap(XRPCStubURLProtocol.lastRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "atproto-proxy"), "did:web:explicit.example.com#svc")
    }

    func testExplicitOptionHeadersReplaceScopedOnesWhateverTheirCase() async throws {
        let service = NetworkService(baseURL: baseURL)
        XRPCStubURLProtocol.install(status: 200, body: "{}")
        _ = try await NetworkService.withCallOptions(XRPCCallOptions(headers: ["x-widget-trace": "scoped"])) {
            try await service.xrpcQuery(
                "com.example.widget.getThing",
                options: XRPCCallOptions(headers: ["X-Widget-Trace": "explicit"])
            )
        }
        let request = try XCTUnwrap(XRPCStubURLProtocol.lastRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-widget-trace"), "explicit")
    }

    func testServiceOptionSendsOneCallToAnotherService() async throws {
        XRPCStubURLProtocol.install(status: 200, body: "{}")

        _ = try await NetworkService(baseURL: baseURL).xrpcQuery(
            "com.example.widget.getThing",
            options: XRPCCallOptions(service: URL(string: "https://example.org")!)
        )

        let url = try XCTUnwrap(XRPCStubURLProtocol.lastRequest?.url)
        XCTAssertEqual(url.host, "example.org")
        XCTAssertEqual(url.path, "/xrpc/com.example.widget.getThing")
    }

    func testCallOptionsScopeAppliesToGeneratedCalls() async throws {
        XRPCStubURLProtocol.install(status: 200, body: #"{"feed":[]}"#)
        let client = client()

        _ = try await NetworkService.withCallOptions(
            XRPCCallOptions(
                headers: ["X-Widget-Trace": "abc"],
                acceptLabelers: [XRPCLabeler(did: "did:plc:labeler1")]
            )
        ) {
            try await client.bsky.feed.getTimeline(input: .init())
        }

        let request = try XCTUnwrap(XRPCStubURLProtocol.lastRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Widget-Trace"), "abc")
        XCTAssertEqual(request.value(forHTTPHeaderField: "atproto-accept-labelers"), "did:plc:labeler1")
    }

    func testResponseMetadataOfAGeneratedCallIsReadable() async throws {
        XRPCStubURLProtocol.install(
            status: 200,
            body: #"{"feed":[]}"#,
            headers: [
                "RateLimit-Limit": "3000",
                "RateLimit-Remaining": "2999",
                "RateLimit-Reset": "1767225600",
                "atproto-repo-rev": "3lqz2zlqr5c2x",
                "atproto-content-labelers": "did:plc:labeler1;redact",
            ]
        )
        let client = client()

        let (result, metadata) = try await NetworkService.withResponseMetadata {
            try await client.bsky.feed.getTimeline(input: .init())
        }

        XCTAssertEqual(result.responseCode, 200)
        XCTAssertEqual(metadata?.statusCode, 200)
        XCTAssertEqual(metadata?.rateLimit?.remaining, 2999)
        XCTAssertEqual(metadata?.repoRev, "3lqz2zlqr5c2x")
        XCTAssertEqual(metadata?.contentLabelers, [XRPCLabeler(did: "did:plc:labeler1", redact: true)])
    }

    // MARK: - Retries (lex-18)

    /// A procedure may have been applied before a gateway failed; sending it again could
    /// apply it twice.
    func testProcedureIsNotRetriedOnAServerError() async throws {
        XRPCStubURLProtocol.install(status: 502, body: #"{"error":"UpstreamFailure"}"#)

        do {
            _ = try await NetworkService(baseURL: baseURL).xrpcProcedure(
                "com.example.widget.createThing",
                body: .json(encoding: ["name": "left"])
            )
            XCTFail("a 502 response must throw")
        } catch let error as ATProtoXRPCError {
            XCTAssertEqual(error.error, "UpstreamFailure")
            XCTAssertEqual(error.statusCode, 502)
        }
        XCTAssertEqual(XRPCStubURLProtocol.requestCount, 1)
    }

    /// XRPC specification: 501 means the endpoint is not implemented; do not retry.
    func testNotImplementedIsNotRetried() async throws {
        XRPCStubURLProtocol.install(status: 501, body: #"{"error":"MethodNotImplemented"}"#)

        do {
            _ = try await NetworkService(baseURL: baseURL).xrpcQuery("com.example.widget.getThing")
            XCTFail("a 501 response must throw")
        } catch let error as ATProtoXRPCError {
            XCTAssertEqual(error.error, "MethodNotImplemented")
        }
        XCTAssertEqual(XRPCStubURLProtocol.requestCount, 1)
    }

    /// A query is safe to repeat; the delay is the one the server asks for.
    func testQueryIsRetriedOnAServerErrorHonouringRetryAfter() async throws {
        XRPCStubURLProtocol.install(status: 503, body: #"{"error":"NotEnoughResources"}"#, headers: ["Retry-After": "0"])
        let delays = RecordedRetryDelays()
        NetworkService.retryDelayObserver = { delays.append($0) }
        defer { NetworkService.retryDelayObserver = nil }

        do {
            _ = try await NetworkService(baseURL: baseURL).xrpcQuery("com.example.widget.getThing")
            XCTFail("a 503 response must throw")
        } catch let error as ATProtoXRPCError {
            XCTAssertEqual(error.statusCode, 503)
            XCTAssertEqual(error.retryAfter, 0)
        }
        XCTAssertEqual(XRPCStubURLProtocol.requestCount, 3)
        // Exponential backoff alone would have waited about 2 s, then 4 s. (Read from the
        // request loop rather than timed, so a stalled CI runner cannot fail it.)
        XCTAssertEqual(delays.values, [0, 0])
    }

    // MARK: - Helpers

    private func getRecordParameters() throws -> ComAtprotoRepoGetRecord.Parameters {
        try ComAtprotoRepoGetRecord.Parameters(
            repo: ATIdentifier(string: "did:plc:ewvi7nxzyoun6zhxrhs64oiz"),
            collection: NSID(nsidString: "app.bsky.feed.post"),
            rkey: RecordKey(keyString: "3jwdwj2ctlk26")
        )
    }

    // MARK: - Generic headers (lex-20)

    /// A generic SDK must not send one app's headers. Only `User-Agent` identifies the client.
    func testNoAppSpecificHeadersAreSentByDefault() async throws {
        XRPCStubURLProtocol.install(status: 200, body: #"{"feed":[]}"#)
        let service = NetworkService(baseURL: baseURL)
        await service.setUserAgent("ExampleApp/1.0")

        _ = try await ATProtoClient.App(networkService: service).bsky.feed.getTimeline(input: .init())

        let request = try XCTUnwrap(XRPCStubURLProtocol.lastRequest)
        let names = (request.allHTTPHeaderFields ?? [:]).keys.map { $0.lowercased() }
        XCTAssertFalse(names.contains { $0.hasPrefix("x-catbird") }, "unexpected headers: \(names)")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "ExampleApp/1.0")
    }

    /// An app that correlates requests with its own gateway opts in with a header name.
    func testRequestIDHeaderIsOptInAndFreshPerRequest() async throws {
        XRPCStubURLProtocol.install(status: 200, body: #"{"feed":[]}"#)
        let service = NetworkService(baseURL: baseURL)
        let feed = ATProtoClient.App(networkService: service).bsky.feed
        await service.setRequestIDHeader(name: "X-Request-Id")

        _ = try await feed.getTimeline(input: .init())
        let first = try XCTUnwrap(XRPCStubURLProtocol.lastRequest?.value(forHTTPHeaderField: "X-Request-Id"))
        _ = try await feed.getTimeline(input: .init(limit: 2))
        let second = try XCTUnwrap(XRPCStubURLProtocol.lastRequest?.value(forHTTPHeaderField: "X-Request-Id"))
        XCTAssertNotNil(UUID(uuidString: first))
        XCTAssertNotEqual(first, second)

        await service.setRequestIDHeader(name: nil)
        _ = try await feed.getTimeline(input: .init())
        XCTAssertNil(XRPCStubURLProtocol.lastRequest?.value(forHTTPHeaderField: "X-Request-Id"))
    }

    // MARK: - Status handling (r-3, r-12)

    /// A client with no session that gets a 401 sees the server's error, not a generic
    /// "authentication required".
    func testUnauthenticated401CarriesTheEnvelope() async throws {
        XRPCStubURLProtocol.install(
            status: 401,
            body: #"{"error":"AuthMissing","message":"Authentication Required"}"#
        )

        do {
            _ = try await client().bsky.feed.getTimeline(input: .init())
            XCTFail("a 401 response must throw")
        } catch let error as ATProtoXRPCError {
            XCTAssertEqual(error.error, "AuthMissing")
            XCTAssertEqual(error.message, "Authentication Required")
            XCTAssertEqual(error.statusCode, 401)
        }
        XCTAssertEqual(XRPCStubURLProtocol.requestCount, 1)
    }

    /// A status outside 2xx/4xx/5xx still reaches the typed error path with its body.
    func testUnexpectedStatusCarriesTheEnvelope() async throws {
        XRPCStubURLProtocol.install(status: 600, body: #"{"error":"Weird","message":"odd gateway"}"#)

        do {
            _ = try await client().bsky.feed.getTimeline(input: .init())
            XCTFail("a 600 response must throw")
        } catch let error as ATProtoXRPCError {
            XCTAssertEqual(error.error, "Weird")
            XCTAssertEqual(error.statusCode, 600)
        }
    }

    // MARK: - Request bodies

    /// XRPC requires a Content-Type on every body. An empty one is refused before sending.
    func testProcedureBodyWithoutContentTypeIsRefusedBeforeSending() async throws {
        XRPCStubURLProtocol.install(status: 200, body: "{}")
        let service = NetworkService(baseURL: baseURL)

        for contentType in ["", "  ", "octet-stream"] {
            do {
                _ = try await service.xrpcProcedure(
                    "com.example.upload",
                    body: .bytes(Data([1, 2, 3]), contentType: contentType)
                )
                XCTFail("content type \"\(contentType)\" must be refused")
            } catch let NetworkError.badRequest(description) {
                XCTAssertTrue(description.contains("Content-Type"), description)
            }
        }
        XCTAssertEqual(XRPCStubURLProtocol.requestCount, 0)
    }
}

/// Answers every request with one canned response and records what was sent.
final class XRPCStubURLProtocol: URLProtocol {
    private struct Stub {
        let status: Int
        let body: Data
        let headers: [String: String]
    }

    private static let lock = NSLock()
    private nonisolated(unsafe) static var stub: Stub?
    private nonisolated(unsafe) static var recordedRequest: URLRequest?
    private nonisolated(unsafe) static var recordedBody: Data?
    private nonisolated(unsafe) static var recordedRequestCount = 0

    static var lastRequest: URLRequest? {
        lock.withLock { recordedRequest }
    }

    /// How many requests reached the transport since the last `install`.
    static var requestCount: Int {
        lock.withLock { recordedRequestCount }
    }

    /// The request body as it reached the transport.
    static var lastBody: Data? {
        lock.withLock { recordedBody }
    }

    static func install(status: Int, body: String, headers: [String: String] = [:]) {
        var merged = ["Content-Type": "application/json"]
        for (name, value) in headers {
            merged.setHTTPHeader(name, value)
        }
        lock.withLock {
            stub = Stub(status: status, body: Data(body.utf8), headers: merged)
            recordedRequest = nil
            recordedBody = nil
            recordedRequestCount = 0
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
            Self.recordedRequestCount += 1
            return Self.stub
        }
        guard let stub,
              let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: stub.status,
                  httpVersion: "HTTP/1.1",
                  headerFields: stub.headers
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

private final class RecordedRetryDelays: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Double] = []

    func append(_ delay: Double) {
        lock.lock()
        recorded.append(delay)
        lock.unlock()
    }

    var values: [Double] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }
}
