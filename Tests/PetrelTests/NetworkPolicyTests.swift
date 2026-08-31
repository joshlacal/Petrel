#if canImport(Compression)
    import Compression
#endif
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Synchronization
import Testing

@Suite("Network Policy, Recipient, Bounds and Logging Tests", .serialized)
struct NetworkPolicyTests {
    @Test("Step 1: Recipient and destination exact-origin enforcement")
    func recipientAndDestinationEnforcement() async throws {
        // Test RequestSecurityPolicy and ExactAuthRequestOrigin
        let httpsURL = URL(string: "https://example.com:443/xrpc/test")!
        let origin = try #require(ExactAuthRequestOrigin(httpsURL))
        #expect(origin.scheme == "https")
        #expect(origin.host == "example.com")
        #expect(origin.effectivePort == 443)

        // WSS URL should normalize to https scheme and port 443 for origin equality
        let wssURL = URL(string: "wss://example.com/xrpc/app.bsky.notification.subscribe")!
        let wssOrigin = try #require(ExactAuthRequestOrigin(wssURL))
        #expect(wssOrigin.scheme == "https")
        #expect(wssOrigin.host == "example.com")
        #expect(wssOrigin.effectivePort == 443)
        #expect(wssOrigin == origin)

        let authedPolicy = RequestSecurityPolicy.authenticated(recipient: origin)
        if case let .authenticated(rec) = authedPolicy {
            #expect(rec == origin)
        } else {
            Issue.record("Expected authenticated policy with origin")
        }

        let unauthedPolicy = RequestSecurityPolicy.unauthenticated
        if case .unauthenticated = unauthedPolicy {
            #expect(true)
        } else {
            Issue.record("Expected unauthenticated policy")
        }

        // Reject cleartext HTTP / WS for non-loopback
        let httpURL = URL(string: "http://example.com/xrpc/test")!
        #expect(ExactAuthRequestOrigin(httpURL) == nil)
        let wsURL = URL(string: "ws://example.com/xrpc/test")!
        #expect(ExactAuthRequestOrigin(wsURL) == nil)

        #expect(IPAddress.isPrivateOrReservedAddress("127.0.0.1") == true)
        #expect(IPAddress.isPrivateOrReservedAddress("10.0.0.1") == true)
        #expect(IPAddress.isPrivateOrReservedAddress("169.254.1.1") == true)
        #expect(IPAddress.isPrivateOrReservedAddress("::ffff:127.0.0.1") == true)
        #expect(IPAddress.isPrivateOrReservedAddress("::ffff:10.0.0.1") == true)
        #expect(IPAddress.isPrivateOrReservedAddress("::ffff:169.254.1.1") == true)
        #expect(IPAddress.isPrivateOrReservedAddress("::ffff:7f00:1") == true)
        #expect(IPAddress.isPrivateOrReservedAddress("::1") == true)
        #expect(IPAddress.isPrivateOrReservedAddress("fe80::1") == true)
        #expect(IPAddress.isPrivateOrReservedAddress("fc00::1") == true)
        #expect(IPAddress.isPrivateOrReservedAddress("93.184.216.34") == false)
    }

    @Test("Step 2 & 4: Redirect credential stripping, DNS validation and cross-origin refusal")
    func redirectCredentialStripping() async throws {
        try await withSerializedStorageOverrideTest {
            NetworkService.dnsResolverOverride = { host in
                if host == "pds.example.com" || host == "attacker.example.com" {
                    return ["93.184.216.34"]
                } else if host == "private-redirect.example.com" {
                    return ["10.0.0.1"]
                }
                return nil
            }
            defer {
                NetworkService.dnsResolverOverride = nil
            }

        let delegate = HardenedURLSessionDelegate()
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        var origRequest = URLRequest(url: URL(string: "https://pds.example.com/xrpc/test")!)
        origRequest.setValue("Bearer secret_token", forHTTPHeaderField: "Authorization")
        origRequest.setValue("DPoP secret_dpop", forHTTPHeaderField: "DPoP")
        origRequest.setValue("cookie_val", forHTTPHeaderField: "Cookie")
        origRequest.setValue("did:plc:123", forHTTPHeaderField: "atproto-proxy")

        let task = session.dataTask(with: origRequest)

        let redirectResponse = HTTPURLResponse(
            url: URL(string: "https://pds.example.com/xrpc/test")!,
            statusCode: 302,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": "https://attacker.example.com/xrpc/test"]
        )!

        var targetRequest = URLRequest(url: URL(string: "https://attacker.example.com/xrpc/test")!)
        targetRequest.setValue("Bearer secret_token", forHTTPHeaderField: "Authorization")
        targetRequest.setValue("DPoP secret_dpop", forHTTPHeaderField: "DPoP")
        targetRequest.setValue("cookie_val", forHTTPHeaderField: "Cookie")
        targetRequest.setValue("did:plc:123", forHTTPHeaderField: "atproto-proxy")

        let redirectedBarrier = AsyncBarrier()
        let finalHolder = Mutex<URLRequest?>(nil)

        delegate.urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: redirectResponse,
            newRequest: targetRequest
        ) { req in
            finalHolder.withLock { $0 = req }
            redirectedBarrier.signal()
        }

        try await redirectedBarrier.waitUntilSignaled(timeoutNanoseconds: 2_000_000_000)
        let redirected = try #require(finalHolder.withLock { $0 })
        #expect(redirected.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(redirected.value(forHTTPHeaderField: "DPoP") == nil)
        #expect(redirected.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(redirected.value(forHTTPHeaderField: "atproto-proxy") == nil)

        // 2. Redirect to a hostname resolving to private IP must be refused (nil)
        let privateRedirectResp = HTTPURLResponse(
            url: URL(string: "https://pds.example.com/xrpc/test")!,
            statusCode: 302,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": "https://private-redirect.example.com/xrpc/test"]
        )!
        let privateTargetReq = URLRequest(url: URL(string: "https://private-redirect.example.com/xrpc/test")!)
        let privateBarrier = AsyncBarrier()
        let privateHolder = Mutex<URLRequest?>(nil)
        delegate.urlSession(
            session,
            task: session.dataTask(with: origRequest),
            willPerformHTTPRedirection: privateRedirectResp,
            newRequest: privateTargetReq
        ) { req in
            privateHolder.withLock { $0 = req }
            privateBarrier.signal()
        }
        try await privateBarrier.waitUntilSignaled(timeoutNanoseconds: 2_000_000_000)
        #expect(privateHolder.withLock { $0 } == nil)

        // 3. Cleartext redirect to remote destination must be refused (nil)
        let cleartextOrig = HTTPURLResponse(
            url: URL(string: "http://a.example/test")!,
            statusCode: 302,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": "http://b.example/test"]
        )!
        let cleartextReq = URLRequest(url: URL(string: "http://b.example/test")!)
        let barrier2 = AsyncBarrier()
        let holder2 = Mutex<URLRequest?>(nil)
        delegate.urlSession(
            session,
            task: session.dataTask(with: URLRequest(url: URL(string: "http://a.example/test")!)),
            willPerformHTTPRedirection: cleartextOrig,
            newRequest: cleartextReq
        ) { req in
            holder2.withLock { $0 = req }
            barrier2.signal()
        }
        #expect(holder2.withLock { $0 } == nil)
        }
    }
    @Test("Step 3 & N1-N3 & N1-M4: Remote cleartext is rejected, loopback cleartext is admitted, private IPs rejected")
    func cleartextAndLoopbackValidation() async throws {
        let service = NetworkService(baseURL: URL(string: "https://pds.example.com")!)
        // Remote http is rejected
        await #expect(throws: NetworkError.self) {
            let remoteHTTPReq = URLRequest(url: URL(string: "http://remote.example.com/xrpc/test")!)
            _ = try await service.request(remoteHTTPReq)
        }
        // Loopback http is permitted for local development
        try await withSerializedStorageOverrideTest {
            NetworkService.dnsResolverOverride = { host in
                if host == "localhost" {
                    return ["127.0.0.1"]
                }
                return nil
            }
            defer {
                NetworkService.dnsResolverOverride = nil
            }
            let localService = NetworkService(baseURL: URL(string: "http://localhost:8080")!)
            let localReq = try await localService.createURLRequest(
                endpoint: "test",
                method: "GET",
                headers: [:],
                body: nil,
                queryItems: nil
            )
            #expect(localReq.url != nil)
        }
        await #expect(throws: NetworkError.self) {
            let privateReq = URLRequest(url: URL(string: "http://10.0.0.1/xrpc/test")!)
            _ = try await service.request(privateReq)
        }
    }

    @Test("Step 3 & N1-C3: prepareStreamingRequest validates destination against private IP")
    func prepareStreamingRequestValidation() async throws {
        NetworkService.dnsResolverOverride = { host in
            if host == "internal.evil.example" {
                return ["10.0.0.1"]
            }
            return nil
        }
        defer {
            NetworkService.dnsResolverOverride = nil
        }
        let service = NetworkService(baseURL: URL(string: "https://pds.example.com")!)
        let req = URLRequest(url: URL(string: "https://internal.evil.example/xrpc/com.atproto.sync.subscribeRepos")!)
        await #expect(throws: NetworkError.self) {
            _ = try await service.prepareStreamingRequest(req)
        }
    }

    // MARK: - Step 5 & 6: URLProtocol-backed Transport Scenarios
    private func withPolicyTransport<T>(
        dnsResolver: @escaping @Sendable (String) -> [String]? = { host in
            if host == "localhost" || host == "127.0.0.1" || host == "::1" {
                return ["127.0.0.1"]
            }
            return ["93.184.216.34"]
        },
        _ body: @escaping () async throws -> T
    ) async throws -> T {
        try await withSerializedStorageOverrideTest {
            PolicyTestURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses([PolicyTestURLProtocol.self])
            NetworkService.dnsResolverOverride = dnsResolver
            defer {
                PolicyTestURLProtocol.reset()
                NetworkService.setNetworkTestProtocolClasses(nil)
                NetworkService.dnsResolverOverride = nil
            }
            return try await body()
        }
    }


    @Test("Transport scenario (a): Real gzip-framed 200 response decodes to expected JSON")
    func transportGzipResponseDecoding() async throws {
        try await withPolicyTransport {
            let expectedJSON = #"{"status":"ok","message":"hello"}"#
            let uncompressedData = Data(expectedJSON.utf8)
            let gzipData = makeGzipPayload(uncompressedData)

            PolicyTestURLProtocol.register(host: "pds.example.com") { req in
                let response = HTTPURLResponse(
                    url: req.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: [
                        "Content-Type": "application/json",
                        "Content-Encoding": "gzip",
                        "Content-Length": "\(gzipData.count)"
                    ]
                )!
                return (response, gzipData)
            }

            let service = NetworkService(baseURL: URL(string: "https://pds.example.com")!)
            let request = URLRequest(url: URL(string: "https://pds.example.com/xrpc/test")!)
            let (data, response) = try await service.performRequest(request)
            #expect(response.statusCode == 200)
            #expect(data == uncompressedData)
        }
    }

    @Test("Transport scenario (b): Oversized Content-Length header cancels before download and throws responseLimitExceeded")
    func transportOversizedContentLengthCancellation() async throws {
        try await withPolicyTransport {
            PolicyTestURLProtocol.register(host: "pds.example.com") { req in
                let response = HTTPURLResponse(
                    url: req.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: [
                        "Content-Type": "application/json",
                        "Content-Length": "20971520" // 20 MB (exceeds default 10 MB limit)
                    ]
                )!
                return (response, Data())
            }

            let service = NetworkService(baseURL: URL(string: "https://pds.example.com")!)
            let request = URLRequest(url: URL(string: "https://pds.example.com/xrpc/test")!)
            do {
                _ = try await service.performRequest(request)
                Issue.record("Expected NetworkError.responseLimitExceeded")
            } catch let NetworkError.responseLimitExceeded(msg) {
                #expect(msg.contains("exceeded") || msg.contains("limit"))
            } catch {
                Issue.record("Expected responseLimitExceeded, got \(error)")
            }
        }
    }

    @Test("Transport scenario (c): Chunked response with no Content-Length succeeds and is bounded by wire ceiling")
    func transportChunkedResponseStreamingBound() async throws {
        try await withPolicyTransport {
            // 1. Small chunked payload with no Content-Length header succeeds
            let validBody = Data(#"{"chunked":true}"#.utf8)
            PolicyTestURLProtocol.register(host: "pds.example.com") { req in
                let response = HTTPURLResponse(
                    url: req.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: [
                        "Content-Type": "application/json",
                        "Transfer-Encoding": "chunked"
                    ]
                )!
                return (response, validBody)
            }

            let service = NetworkService(baseURL: URL(string: "https://pds.example.com")!)
            let request = URLRequest(url: URL(string: "https://pds.example.com/xrpc/test")!)
            let (data, response) = try await service.performRequest(request)
            #expect(response.statusCode == 200)
            #expect(data == validBody)

            // 2. Large chunked payload exceeding wire limit (10MB) fails with responseLimitExceeded
            let oversizedBody = Data(repeating: 0x41, count: 11 * 1024 * 1024)
            PolicyTestURLProtocol.register(host: "oversized.example.com") { req in
                let response = HTTPURLResponse(
                    url: req.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: [
                        "Content-Type": "application/octet-stream",
                        "Transfer-Encoding": "chunked"
                    ]
                )!
                return (response, oversizedBody)
            }

            let oversizedReq = URLRequest(url: URL(string: "https://oversized.example.com/xrpc/test")!)
            do {
                _ = try await service.performRequest(oversizedReq)
                Issue.record("Expected NetworkError.responseLimitExceeded")
            } catch let NetworkError.responseLimitExceeded(msg) {
                #expect(msg.contains("exceeded") || msg.contains("limit") || msg.contains("Wire"))
            } catch {
                Issue.record("Expected responseLimitExceeded, got \(error)")
            }
        }
    }

    @Test("Transport scenario (d): Same-origin redirect completes with approved target addresses and retained credentials")
    func transportSameOriginRedirectPreservesCredentialsAndApprovesTarget() async throws {
        try await withPolicyTransport {
            let finalBody = Data(#"{"step":2}"#.utf8)
            PolicyTestURLProtocol.register(host: "pds.example.com") { req in
                if req.url?.path == "/xrpc/step1" {
                    let redirectResp = HTTPURLResponse(
                        url: req.url!,
                        statusCode: 302,
                        httpVersion: "HTTP/1.1",
                        headerFields: ["Location": "https://pds.example.com/xrpc/step2"]
                    )!
                    return (redirectResp, Data())
                } else {
                    let successResp = HTTPURLResponse(
                        url: req.url!,
                        statusCode: 200,
                        httpVersion: "HTTP/1.1",
                        headerFields: ["Content-Type": "application/json"]
                    )!
                    return (successResp, finalBody)
                }
            }

            let service = NetworkService(baseURL: URL(string: "https://pds.example.com")!)
            var req = URLRequest(url: URL(string: "https://pds.example.com/xrpc/step1")!)
            req.setValue("Bearer secret_token", forHTTPHeaderField: "Authorization")
            req.setValue("DPoP proof_token", forHTTPHeaderField: "DPoP")
            req.setValue("session=abc", forHTTPHeaderField: "Cookie")

            let (data, response) = try await service.performRequest(req)
            #expect(response.statusCode == 200)
            #expect(data == finalBody)

            let captured = PolicyTestURLProtocol.requests
            #expect(captured.count == 2)
            let secondReq = try #require(captured.last)
            #expect(secondReq.url?.path == "/xrpc/step2")
            #expect(secondReq.value(forHTTPHeaderField: "Authorization") == "Bearer secret_token")
            #expect(secondReq.value(forHTTPHeaderField: "DPoP") == "DPoP proof_token")
            #expect(secondReq.value(forHTTPHeaderField: "Cookie") == "session=abc")
        }
    }

    @Test("Transport scenario (e): Cross-origin redirect completes with Authorization, DPoP, and Cookie stripped")
    func transportCrossOriginRedirectStripsCredentials() async throws {
        try await withPolicyTransport {
            let finalBody = Data(#"{"redirected":true}"#.utf8)
            PolicyTestURLProtocol.register(host: "pds.example.com") { req in
                let redirectResp = HTTPURLResponse(
                    url: req.url!,
                    statusCode: 302,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Location": "https://cdn.example.com/xrpc/target"]
                )!
                return (redirectResp, Data())
            }
            PolicyTestURLProtocol.register(host: "cdn.example.com") { req in
                let successResp = HTTPURLResponse(
                    url: req.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (successResp, finalBody)
            }

            let service = NetworkService(baseURL: URL(string: "https://pds.example.com")!)
            var req = URLRequest(url: URL(string: "https://pds.example.com/xrpc/step1")!)
            req.setValue("Bearer secret_token", forHTTPHeaderField: "Authorization")
            req.setValue("DPoP proof_token", forHTTPHeaderField: "DPoP")
            req.setValue("session=abc", forHTTPHeaderField: "Cookie")

            let (data, response) = try await service.performRequest(req)
            #expect(response.statusCode == 200)
            #expect(data == finalBody)

            let captured = PolicyTestURLProtocol.requests
            #expect(captured.count == 2)
            let secondReq = try #require(captured.last)
            #expect(secondReq.url?.host == "cdn.example.com")
            #expect(secondReq.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(secondReq.value(forHTTPHeaderField: "DPoP") == nil)
            #expect(secondReq.value(forHTTPHeaderField: "Cookie") == nil)
        }
    }

    @Test("Credential attachment proceeds unauthenticated on AuthError.noActiveAccount across all request methods")
    func noActiveAccountCredentialAttachmentFallback() async throws {
        try await withPolicyTransport {
            PolicyTestURLProtocol.register(host: "pds.example.com") { req in
                let resp = HTTPURLResponse(
                    url: req.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (resp, Data(#"{"unauthenticated":true}"#.utf8))
            }

            final class NoActiveAccountAuthProvider: AuthenticationProvider, @unchecked Sendable {
                func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
                    throw AuthError.noActiveAccount
                }
                func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (URLRequest, AuthContext) {
                    throw AuthError.noActiveAccount
                }
                func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
                    throw AuthError.noActiveAccount
                }
                func handleUnauthorizedResponse(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
                    throw AuthError.noActiveAccount
                }
                func updateDPoPNonce(for url: URL, from headers: [String: String], did: String?, jkt: String?) async {}
            }

            let provider = NoActiveAccountAuthProvider()
            let service = NetworkService(baseURL: URL(string: "https://pds.example.com")!, authService: provider)

            // 1. request(_:) proceeds unauthenticated
            let simpleReq = URLRequest(url: URL(string: "https://pds.example.com/xrpc/test")!)
            let (data1, resp1) = try await service.request(simpleReq)
            #expect((resp1 as? HTTPURLResponse)?.statusCode == 200)
            #expect(!data1.isEmpty)

            // 2. performRequest(_:) proceeds unauthenticated
            let (data2, resp2) = try await service.performRequest(simpleReq)
            #expect(resp2.statusCode == 200)
            #expect(!data2.isEmpty)

            // 3. prepareStreamingRequest proceeds unauthenticated (no auth headers, nil authContext)
            let streamingPrep = try await service.prepareStreamingRequest(simpleReq)
            #expect(streamingPrep.request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(streamingPrep.authContext == nil)
        }
    }

    @Test("Step 7 & N1-N1 & N1-N2: WebSocket subscription admitted for wss and requires auth for authorized origin")
    func subscriptionWSSAdmission() async throws {
        let service = NetworkService(baseURL: URL(string: "https://pds.example.com")!)
        NetworkService.dnsResolverOverride = { host in
            if host == "pds.example.com" {
                return ["93.184.216.34"]
            }
            return nil
        }
        defer {
            NetworkService.dnsResolverOverride = nil
        }
        let policy = await service.determineSecurityPolicy(for: URL(string: "wss://pds.example.com/xrpc/com.atproto.sync.subscribeRepos")!)
        if case let .authenticated(recipient) = policy {
            #expect(recipient.host == "pds.example.com")
            #expect(recipient.scheme == "https")
        } else {
            Issue.record("Expected authenticated policy for authorized origin WebSocket subscription")
        }
    }

    @Test("Step 8 & N1-N5: LogManager sanitizes userinfo, fragments, handles, tokens, and query values")
    func logManagerQuerySanitization() {
        let url = URL(string: "https://user:password@alice.bsky.social/oauth/authorize?response_type=code&client_id=myclient&code=secret123&state=xyz789&handle=alice.bsky.social&email=alice@example.com#access_token=token123")!
        let sanitized = LogManager.sanitizeURLForLogging(url)
        #expect(!sanitized.contains("user"))
        #expect(!sanitized.contains("password"))
        #expect(!sanitized.contains("secret123"))
        #expect(!sanitized.contains("xyz789"))
        #expect(!sanitized.contains("alice@example.com"))
        #expect(!sanitized.contains("token123"))
        #expect(!sanitized.contains("#"))
        #expect(!sanitized.contains("alice.bsky.social"))
        #expect(sanitized.contains("response_type"))
        #expect(sanitized.contains("client_id"))
        #expect(sanitized.hasPrefix("/oauth/authorize"))

        let didURL = URL(string: "https://plc.directory/did:plc:12345/data?limit=50&cursor=abc&secret=hush")!
        let sanitizedDID = LogManager.sanitizeURLForLogging(didURL)
        #expect(!sanitizedDID.contains("plc.directory"))
        #expect(!sanitizedDID.contains("50"))
        #expect(!sanitizedDID.contains("abc"))
        #expect(!sanitizedDID.contains("hush"))
        #expect(sanitizedDID.contains("limit"))
        #expect(sanitizedDID.contains("cursor"))
        #expect(sanitizedDID.hasPrefix("/did:plc:12345/data"))
    }

    // URLSessionTask(Transaction)Metrics.init() is unsupported on macOS (deprecated
    // 10.15, fatalErrors at runtime), so the stub-based rebinding test only exists
    // on platforms where the initializer works.
    #if canImport(Darwin) && !os(macOS)
    @Test("DNS answer change causes request failure (SSRF / TOCTOU mitigation)")
    func dnsRebindingRejection() async throws {
        let delegate = HardenedURLSessionDelegate()
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let task = session.dataTask(with: URLRequest(url: URL(string: "https://rebinding.example.com/xrpc/test")!))

        // Simulate metrics collection with connection to private address (DNS rebinding at connection time)
        final class StubTransactionMetrics: URLSessionTaskTransactionMetrics, @unchecked Sendable {
            private let stubRemoteAddress: String?
            init(remoteAddress: String?) {
                self.stubRemoteAddress = remoteAddress
                super.init()
            }
            override var remoteAddress: String? { stubRemoteAddress }
        }

        final class StubTaskMetrics: URLSessionTaskMetrics, @unchecked Sendable {
            private let stubTransactions: [URLSessionTaskTransactionMetrics]
            init(transactions: [URLSessionTaskTransactionMetrics]) {
                self.stubTransactions = transactions
                super.init()
            }
            override var transactionMetrics: [URLSessionTaskTransactionMetrics] { stubTransactions }
        }

        let metrics = StubTaskMetrics(transactions: [StubTransactionMetrics(remoteAddress: "127.0.0.1:443")])
        delegate.urlSession(session, task: task, didFinishCollecting: metrics)

        let isViolation = delegate.contextManager.isSecurityViolation(for: task)
        #expect(isViolation, "Expected connection to 127.0.0.1 to be flagged as security violation")
        #expect(delegate.contextManager.hasAnySecurityViolation())
    }
    #endif
    @Test("Transport DNS resolver rejects public-to-private rebinding")
    func transportResolverRejectsPrivateRebinding() {
        let approved: Set<String> = ["93.184.216.34"]
        #expect(!HardenedURLSessionDelegate.transportAddressesAreApproved(["10.0.0.1"], approved: approved))
    }

    @Test("Transport DNS resolver rejects public-to-different-public rebinding (disjoint)")
    func transportResolverRejectsDisjointPublicRebinding() {
        let approved: Set<String> = ["93.184.216.34"]
        #expect(!HardenedURLSessionDelegate.transportAddressesAreApproved(["198.51.100.7"], approved: approved))
    }

    @Test("Transport DNS resolver accepts intersecting public address rotation")
    func transportResolverAcceptsIntersectingPublicRotation() {
        let approved: Set<String> = ["93.184.216.34", "93.184.216.35"]
        #expect(HardenedURLSessionDelegate.transportAddressesAreApproved(["93.184.216.35", "93.184.216.36"], approved: approved))
    }
}

private func makeGzipPayload(_ uncompressed: Data) -> Data {
    #if canImport(Compression)
    var compressedBuffer = Data(count: uncompressed.count + 64)
    let compressedSize = compressedBuffer.withUnsafeMutableBytes { dst in
        uncompressed.withUnsafeBytes { src in
            compression_encode_buffer(
                dst.baseAddress!.assumingMemoryBound(to: UInt8.self),
                dst.count,
                src.baseAddress!.assumingMemoryBound(to: UInt8.self),
                src.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
    }
    let rawDeflate = compressedBuffer.prefix(compressedSize)
    var gzipData = Data([0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03])
    gzipData.append(rawDeflate)
    let size = UInt32(uncompressed.count).littleEndian
    let crc: UInt32 = 0
    withUnsafeBytes(of: crc) { gzipData.append(contentsOf: $0) }
    withUnsafeBytes(of: size) { gzipData.append(contentsOf: $0) }
    return gzipData
    #else
    return uncompressed
    #endif
}

private final class PolicyTestURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) async -> (HTTPURLResponse, Data)?
    private static let lock = NSLock()
    private nonisolated(unsafe) static var handlers: [String: Handler] = [:]
    private nonisolated(unsafe) static var capturedRequests: [URLRequest] = []

    static func reset() {
        lock.withLock {
            handlers.removeAll()
            capturedRequests.removeAll()
        }
    }

    static func register(host: String, handler: @escaping Handler) {
        lock.withLock {
            handlers[host] = handler
        }
    }

    static var requests: [URLRequest] {
        lock.withLock { capturedRequests }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        lock.withLock {
            guard let host = request.url?.host else { return false }
            return handlers[host] != nil
        }
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.withLock {
            Self.capturedRequests.append(request)
        }
        guard let host = request.url?.host,
              let handler = Self.lock.withLock({ Self.handlers[host] })
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }

        let box = UncheckedSendableBox(self)
        Task {
            let proto = box.value
            if let (response, data) = await handler(proto.request) {
                if (300 ..< 400).contains(response.statusCode),
                   let location = response.allHeaderFields["Location"] as? String,
                   let redirectURL = URL(string: location, relativeTo: proto.request.url)
                {
                    var redirectReq = proto.request
                    redirectReq.url = redirectURL
                    proto.client?.urlProtocol(proto, wasRedirectedTo: redirectReq, redirectResponse: response)
                    return
                }
                proto.client?.urlProtocol(proto, didReceive: response, cacheStoragePolicy: .notAllowed)
                proto.client?.urlProtocol(proto, didLoad: data)
                proto.client?.urlProtocolDidFinishLoading(proto)
            } else {
                proto.client?.urlProtocol(proto, didFailWithError: URLError(.badServerResponse))
            }
        }
    }

    override func stopLoading() {}
}

// Older toolchains require the explicit conformance for strict-concurrency;
// newer SDKs mark URLProtocol's inherited Sendable unavailable and warn on it.
#if compiler(<6.2)
extension PolicyTestURLProtocol: @unchecked Sendable {}
#endif

/// Carries a non-Sendable value across a task boundary in tests where the
/// URLProtocol machinery guarantees exclusive access.
private final class UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
