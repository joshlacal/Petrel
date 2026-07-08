#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
@testable import Petrel
import Synchronization
import Testing
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - Mock transport

/// URLProtocol that routes requests to a scriptable handler. One handler per
/// process at a time — suites using it must be `.serialized`.
final class MockURLProtocol: URLProtocol {
    private static let handlerStorage = Mutex<(@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?>(nil)

    static func setHandler(_ new: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?) {
        handlerStorage.withLock { $0 = new }
    }

    override static func canInit(with _: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handlerStorage.withLock({ $0 }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension URLRequest {
    /// URLSession moves `httpBody` into `httpBodyStream` before URLProtocol
    /// sees the request — read whichever is populated.
    var bodyBytes: Data? {
        if let body = httpBody { return body }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

// MARK: - Helpers

private func decodeProofPayload(_ compactJWS: String) throws -> [String: Any] {
    let parts = compactJWS.split(separator: ".")
    try #require(parts.count == 3)
    var payloadB64 = String(parts[1])
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    while payloadB64.count % 4 != 0 { payloadB64 += "=" }
    let payloadData = try #require(Data(base64Encoded: payloadB64))
    return try #require(try JSONSerialization.jsonObject(with: payloadData) as? [String: Any])
}

// MARK: - Tests

@Suite("CAB client assertion fetch", .serialized)
struct ClientAssertionFetchTests {
    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeStrategy(namespace: String, session: URLSession) -> CABOAuthStrategy {
        CABOAuthStrategy(
            backendURL: URL(string: "https://cab.example.com")!,
            storage: KeychainStorage(namespace: namespace),
            accountManager: MockAccountManager(
                account: Account(
                    did: "did:plc:test",
                    handle: "test.example",
                    pdsURL: URL(string: "https://pds.test")!
                )
            ),
            networkService: NetworkService(baseURL: URL(string: "https://pds.test")!),
            oauthConfig: OAuthConfig(
                clientId: "https://cab.example.com/oauth-client-metadata.json",
                redirectUri: "https://client.example/callback",
                scope: "atproto"
            ),
            didResolver: MockDIDResolver(),
            urlSession: session
        )
    }

    @Test("Posts aud form field and DPoP proof, decodes the response")
    func fetchSendsAudAndProof() async throws {
        let strategy = makeStrategy(namespace: "test.cab.fetch", session: makeMockSession())
        let captured = Mutex<[URLRequest]>([])
        MockURLProtocol.setHandler { request in
            captured.withLock { $0.append(request) }
            let body = #"{"client_id":"https://cab.example.com/oauth-client-metadata.json","client_assertion":"header.payload.sig"}"#
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!,
                Data(body.utf8)
            )
        }
        defer { MockURLProtocol.setHandler(nil) }

        let response = try await strategy.fetchClientAssertion(
            aud: "https://auth.pds.test",
            ephemeralKey: P256.Signing.PrivateKey()
        )

        #expect(response.clientAssertion == "header.payload.sig")
        #expect(response.clientId == "https://cab.example.com/oauth-client-metadata.json")

        let requests = captured.withLock { $0 }
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.url?.absoluteString == "https://cab.example.com/oauth/client-assertion")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "DPoP") != nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        let bodyString = String(data: request.bodyBytes ?? Data(), encoding: .utf8) ?? ""
        #expect(bodyString.hasPrefix("aud="))
        #expect(bodyString.contains("auth.pds.test"))
    }

    @Test("Retries exactly once on use_dpop_nonce, echoing the server nonce")
    func fetchRetriesOnNonceChallenge() async throws {
        let strategy = makeStrategy(namespace: "test.cab.nonce", session: makeMockSession())
        let captured = Mutex<[URLRequest]>([])
        MockURLProtocol.setHandler { request in
            let isFirst = captured.withLock { requests -> Bool in
                requests.append(request)
                return requests.count == 1
            }
            if isFirst {
                let error = #"{"error":"use_dpop_nonce","error_description":"nonce required"}"#
                return (
                    HTTPURLResponse(
                        url: request.url!, statusCode: 400, httpVersion: nil,
                        headerFields: ["DPoP-Nonce": "server-nonce-1", "Content-Type": "application/json"]
                    )!,
                    Data(error.utf8)
                )
            }
            let body = #"{"client_id":"cid","client_assertion":"a.b.c"}"#
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(body.utf8)
            )
        }
        defer { MockURLProtocol.setHandler(nil) }

        let response = try await strategy.fetchClientAssertion(
            aud: "https://auth.pds.test",
            ephemeralKey: P256.Signing.PrivateKey()
        )
        #expect(response.clientAssertion == "a.b.c")

        let requests = captured.withLock { $0 }
        try #require(requests.count == 2)
        let retryProof = try #require(requests[1].value(forHTTPHeaderField: "DPoP"))
        let payload = try decodeProofPayload(retryProof)
        #expect(payload["nonce"] as? String == "server-nonce-1")
        #expect(payload["htu"] as? String == "https://cab.example.com/oauth/client-assertion")
        #expect(payload["htm"] as? String == "POST")
    }

    @Test("A second nonce challenge is a hard, typed failure")
    func secondNonceChallengeFails() async throws {
        let strategy = makeStrategy(namespace: "test.cab.nonce2", session: makeMockSession())
        MockURLProtocol.setHandler { request in
            let error = #"{"error":"use_dpop_nonce"}"#
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 400, httpVersion: nil,
                    headerFields: ["DPoP-Nonce": "server-nonce-x"]
                )!,
                Data(error.utf8)
            )
        }
        defer { MockURLProtocol.setHandler(nil) }

        await #expect(throws: AuthError.clientAssertionBackendError(400, "use_dpop_nonce")) {
            _ = try await strategy.fetchClientAssertion(
                aud: "https://auth.pds.test",
                ephemeralKey: P256.Signing.PrivateKey()
            )
        }
    }

    @Test("Backend refusal surfaces as clientAssertionBackendError")
    func backendRefusalIsTyped() async throws {
        let strategy = makeStrategy(namespace: "test.cab.refusal", session: makeMockSession())
        MockURLProtocol.setHandler { request in
            let error = #"{"error":"access_denied","error_description":"device refused"}"#
            return (
                HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!,
                Data(error.utf8)
            )
        }
        defer { MockURLProtocol.setHandler(nil) }

        await #expect(throws: AuthError.clientAssertionBackendError(403, "access_denied")) {
            _ = try await strategy.fetchClientAssertion(
                aud: "https://auth.pds.test",
                ephemeralKey: P256.Signing.PrivateKey()
            )
        }
    }
}
