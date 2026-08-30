import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
#if canImport(Compression)
    import Compression
#endif
import SwiftCBOR
@testable import Petrel
import Synchronization
import Testing

private actor Counter {
    var count = 0
    func increment() {
        count += 1
    }
    func get() -> Int {
        count
    }
}

private actor Flag {
    var value = false
    func setTrue() {
        value = true
    }
    func get() -> Bool {
        value
    }
}

@Suite("Network Performance Hygiene Tests", .serialized)
struct NetworkPerformanceHygieneTests {
    // MARK: - Task 8: RequestDeduplicator Tests

    @Test("RequestDeduplicator deduplicates concurrent GET requests under the same auth identity")
    func requestDeduplicatorCoalescesConcurrentGETsSameAuth() async throws {
        let deduplicator = RequestDeduplicator()
        let url = URL(string: "https://bsky.social/xrpc/app.bsky.actor.getProfile")!

        var request1 = URLRequest(url: url)
        request1.httpMethod = "GET"
        var request2 = URLRequest(url: url)
        request2.httpMethod = "GET"

        let counter = Counter()

        // Launch two concurrent requests for the exact same GET URL with the same auth identity
        async let first = deduplicator.deduplicate(request: request1, authIdentity: "did:plc:user1") {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("response".utf8), response)
        }

        async let second = deduplicator.deduplicate(request: request2, authIdentity: "did:plc:user1") {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 50_000_000)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("response".utf8), response)
        }

        let (res1, res2) = try await (first, second)
        #expect(res1.0 == Data("response".utf8))
        #expect(res2.0 == Data("response".utf8))
        // Only one work closure should have been executed
        let executed = await counter.get()
        #expect(executed == 1)
    }

    @Test("Finding 4 Regression: Concurrent GETs under different account identities must NOT coalesce")
    func requestDeduplicatorDoesNotCoalesceDifferentAccounts() async throws {
        let deduplicator = RequestDeduplicator()
        let url = URL(string: "https://bsky.social/xrpc/app.bsky.actor.getProfile")!

        var request1 = URLRequest(url: url)
        request1.httpMethod = "GET"
        var request2 = URLRequest(url: url)
        request2.httpMethod = "GET"

        let counter = Counter()

        // Launch two concurrent requests for the same URL but different accounts
        async let first = deduplicator.deduplicate(request: request1, authIdentity: "did:plc:accountA") {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 20_000_000)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("accountA_profile".utf8), response)
        }

        async let second = deduplicator.deduplicate(request: request2, authIdentity: "did:plc:accountB") {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 20_000_000)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("accountB_profile".utf8), response)
        }

        let (res1, res2) = try await (first, second)
        #expect(res1.0 == Data("accountA_profile".utf8))
        #expect(res2.0 == Data("accountB_profile".utf8))
        // Both work closures must execute independently - no cross-account response leak
        let executed = await counter.get()
        #expect(executed == 2)
    }

    @Test("Finding 4 Regression: Authenticated vs Unauthenticated concurrent GETs must NOT coalesce")
    func requestDeduplicatorDoesNotCoalesceAuthAndUnauth() async throws {
        let deduplicator = RequestDeduplicator()
        let url = URL(string: "https://bsky.social/xrpc/app.bsky.feed.getTimeline")!

        var request1 = URLRequest(url: url)
        request1.httpMethod = "GET"
        var request2 = URLRequest(url: url)
        request2.httpMethod = "GET"

        let counter = Counter()

        // One unauthenticated (nil authIdentity), one authenticated
        async let first = deduplicator.deduplicate(request: request1, authIdentity: nil) {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 20_000_000)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("public_feed".utf8), response)
        }

        async let second = deduplicator.deduplicate(request: request2, authIdentity: "did:plc:user1") {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 20_000_000)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("authed_feed".utf8), response)
        }

        let (res1, res2) = try await (first, second)
        #expect(res1.0 == Data("public_feed".utf8))
        #expect(res2.0 == Data("authed_feed".utf8))
        let executed = await counter.get()
        #expect(executed == 2)
    }

    @Test("Finding 1: RequestKey rejects lowercase 'get' and preserves exact case matching")
    func requestKeyRejectsLowercaseMethod() {
        let getKey = RequestDeduplicator.RequestKey(
            method: "GET",
            url: "https://bsky.social/xrpc/test",
            authIdentity: "did:plc:user1"
        )
        #expect(getKey != nil)
        #expect(getKey?.method == "GET")

        let lowerGetKey = RequestDeduplicator.RequestKey(
            method: "get",
            url: "https://bsky.social/xrpc/test",
            authIdentity: "did:plc:user1"
        )
        // Fixed code rejects non-exact lowercase method; old uppercasing code normalized and accepted it
        #expect(lowerGetKey == nil)
    }

    @Test("Finding 1: Distinct HTTP methods (HEAD vs GET) to same URL do not coalesce")
    func requestDeduplicatorDoesNotCoalesceDistinctMethods() async throws {
        let deduplicator = RequestDeduplicator()
        let url = URL(string: "https://bsky.social/xrpc/test")!

        var request1 = URLRequest(url: url)
        request1.httpMethod = "HEAD"

        var request2 = URLRequest(url: url)
        request2.httpMethod = "GET"

        let counter = Counter()

        async let first = deduplicator.deduplicate(request: request1, authIdentity: "did:plc:user1") {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 20_000_000)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("head".utf8), response)
        }

        async let second = deduplicator.deduplicate(request: request2, authIdentity: "did:plc:user1") {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 20_000_000)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("get".utf8), response)
        }

        let (res1, res2) = try await (first, second)
        #expect(res1.0 == Data("head".utf8))
        #expect(res2.0 == Data("get".utf8))
        let executed = await counter.get()
        #expect(executed == 2)
    }

    @Test("RequestDeduplicator does not deduplicate POST requests")
    func requestDeduplicatorDoesNotDeduplicatePOST() async throws {
        let deduplicator = RequestDeduplicator()
        let url = URL(string: "https://bsky.social/xrpc/com.atproto.repo.createRecord")!

        var request1 = URLRequest(url: url)
        request1.httpMethod = "POST"
        request1.httpBody = Data("{\"text\":\"hello\"}".utf8)

        var request2 = URLRequest(url: url)
        request2.httpMethod = "POST"
        request2.httpBody = Data("{\"text\":\"hello\"}".utf8)

        let counter = Counter()

        // Launch two concurrent POST requests with identical URLs and bodies
        async let first = deduplicator.deduplicate(request: request1) {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 20_000_000)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("post1".utf8), response)
        }

        async let second = deduplicator.deduplicate(request: request2) {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 20_000_000)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("post2".utf8), response)
        }

        let (res1, res2) = try await (first, second)
        #expect(res1.0 == Data("post1".utf8))
        #expect(res2.0 == Data("post2".utf8))
        // Both work closures must have executed
        let executed = await counter.get()
        #expect(executed == 2)
    }

    @Test("RequestDeduplicator isRequestInFlight behavior")
    func requestDeduplicatorInFlightStatus() async throws {
        let deduplicator = RequestDeduplicator()
        let getURL = URL(string: "https://bsky.social/xrpc/test")!
        var getReq = URLRequest(url: getURL)
        getReq.httpMethod = "GET"

        let postURL = URL(string: "https://bsky.social/xrpc/test")!
        var postReq = URLRequest(url: postURL)
        postReq.httpMethod = "POST"

        #expect(await deduplicator.isRequestInFlight(getReq) == false)
        #expect(await deduplicator.isRequestInFlight(postReq) == false)
    }

    // MARK: - Task 8: HardenedURLSessionDelegate Tests

    @Test("HardenedURLSessionDelegate performs default handling for TLS challenge")
    func hardenedDelegateTLSChallengeDefaultHandling() async throws {
        let delegate = HardenedURLSessionDelegate()
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let challenge = URLAuthenticationChallenge()
        let flag = Flag()
        delegate.urlSession(session, didReceive: challenge) { disposition, credential in
            #expect(disposition == .performDefaultHandling)
            #expect(credential == nil)
            Task {
                await flag.setTrue()
            }
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        let wasHandled = await flag.get()
        #expect(wasHandled == true)
    }

    // MARK: - Task 7: NetworkService URL Validation and SSRF Mitigation Tests

    @Test("NetworkService blocks private IP addresses and IPv4-mapped IPv6")
    func networkServiceBlocksPrivateIPs() async throws {
        let service = NetworkService(baseURL: URL(string: "https://bsky.social")!)

        let privateURLs = [
            "http://10.0.0.1/xrpc/test",
            "http://192.168.1.1/xrpc/test",
            "http://172.16.0.1/xrpc/test",
            "http://169.254.1.1/xrpc/test",
            "http://0.0.0.0/xrpc/test",
            "http://255.255.255.255/xrpc/test",
            "https://[::ffff:127.0.0.1]/xrpc/test",
            "https://[::ffff:7f00:1]/xrpc/test",
            "https://[::ffff:10.0.0.1]/xrpc/test"
        ]

        for urlString in privateURLs {
            do {
                _ = try await service.createURLRequest(
                    endpoint: urlString,
                    method: "GET",
                    headers: [:],
                    body: nil,
                    queryItems: nil
                )
                Issue.record("Expected securityViolation for \(urlString), but request creation succeeded")
            } catch let error as NetworkError {
                guard case .securityViolation = error else {
                    Issue.record("Expected .securityViolation for \(urlString), got \(error)")
                    continue
                }
            } catch {
                Issue.record("Unexpected error type for \(urlString): \(error)")
            }
        }
    }

    @Test("NetworkService creates request for legitimate hostnames")
    func networkServiceValidatesLegitimateHost() async throws {
        NetworkService.dnsResolverOverride = { host in
            if host == "bsky.social" {
                return ["104.244.42.1"]
            }
            return nil
        }
        defer {
            NetworkService.dnsResolverOverride = nil
        }

        let service = NetworkService(baseURL: URL(string: "https://bsky.social")!)

        let req1 = try await service.createURLRequest(
            endpoint: "https://bsky.social/xrpc/app.bsky.actor.getProfile",
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )
        #expect(req1.url?.host == "bsky.social")
    }

    @Test("Finding 2: In-flight DNS resolution cancellation propagates CancellationError promptly")
    func networkServiceCancellationPropagates() async throws {
        let service = NetworkService(baseURL: URL(string: "https://bsky.social")!)

        let cancellationHost = "cancellation-test.bsky.social"
        let enteredOperation = AsyncBarrier()

        NetworkService.dnsResolutionHook = { host, isCancelled in
            guard host == cancellationHost else { return }
            enteredOperation.signal()
            while !isCancelled() {
                Thread.sleep(forTimeInterval: 0.002)
            }
        }
        defer {
            NetworkService.dnsResolutionHook = nil
        }

        let task = Task {
            try await service.createURLRequest(
                endpoint: "https://\(cancellationHost)/xrpc/app.bsky.actor.getProfile",
                method: "GET",
                headers: [:],
                body: nil,
                queryItems: nil
            )
        }

        // Wait with a bounded timeout until the BlockOperation has actually been dequeued and started
        try await enteredOperation.waitUntilSignaled(timeoutNanoseconds: 5_000_000_000)

        let cancelStartTime = ContinuousClock.now

        // Cancel while the operation is actively running on dnsResolutionQueue
        task.cancel()

        // Assert that CancellationError reaches caller promptly (within 200ms) with a bounded race against a clock deadline
        let completionBarrier = AsyncBarrier()
        let resultHolder = Mutex<(result: Result<URLRequest, any Error>?, elapsed: Duration?)>((nil, nil))

        Task {
            do {
                let req = try await task.value
                resultHolder.withLock {
                    $0 = (.success(req), ContinuousClock.now - cancelStartTime)
                }
            } catch {
                resultHolder.withLock {
                    $0 = (.failure(error), ContinuousClock.now - cancelStartTime)
                }
            }
            completionBarrier.signal()
        }

        let completed = try await completionBarrier.wait(timeoutNanoseconds: 2_000_000_000)
        #expect(completed, "Timed out waiting for cancelled DNS resolution to complete")
        guard completed else { return }
        let (result, elapsed) = resultHolder.withLock { $0 }
        switch result {
        case .failure(is CancellationError):
            if let elapsed {
                #expect(elapsed < .milliseconds(200))
            }
        case .failure(let error):
            Issue.record("Expected CancellationError, but got: \(error)")
        case .success:
            Issue.record("Expected CancellationError, but task.value completed successfully")
        case nil:
            Issue.record("Task result was missing")
        }
    }

    // MARK: - Task N1: Byte Ceilings and Stream Bounds Tests

    @Test("ContentDecoding framing heuristic handles declared-gzip-but-already-decoded payloads and wire limits")
    func contentDecodingFramingHeuristic() throws {
        let limits = NetworkResponseLimits(
            maximumWireBytes: 1000,
            maximumDecodedBytes: 5000,
            maximumExpansionRatio: 10,
            maximumDiagnosticBytes: 100
        )

        // 1. Declared gzip but already decoded by URLSession (starts with ASCII '{') passes through unmodified
        let jsonText = #"{"status":"already-decoded"}"#
        let jsonData = Data(jsonText.utf8)
        let uncompressed = try ContentDecoding.decompressIfNeeded(jsonData, contentEncoding: "gzip", limits: limits)
        #expect(uncompressed == jsonData)

        // 2. Wire bytes exceeding limit throws responseLimitExceeded
        let oversizedWire = Data(repeating: 0x41, count: 1001)
        #expect(throws: NetworkError.self) {
            try ContentDecoding.decompressIfNeeded(oversizedWire, contentEncoding: nil, limits: limits)
        }

        // 3. Exact boundary equal for wire is admitted
        let exactWire = Data(repeating: 0x41, count: 1000)
        #expect(throws: Never.self) {
            let result = try ContentDecoding.decompressIfNeeded(exactWire, contentEncoding: nil, limits: limits)
            #expect(result.count == 1000)
        }
    }

    @Test("Step 7: WebSocket subscription stream drops overflow with typed error")
    func subscriptionStreamOverflowTermination() async throws {
        struct TestSubMessage: Codable, Sendable {
            let seq: Int
        }

        // Construct a valid ATProto WebSocket frame
        let headerCBOR: CBOR = .map([
            .utf8String("op"): .unsignedInt(1),
            .utf8String("t"): .utf8String("#commit")
        ])
        let payloadCBOR: CBOR = .map([
            .utf8String("seq"): .unsignedInt(42)
        ])
        let frameBytes = Data(headerCBOR.encode() + payloadCBOR.encode())

        final class MockOverflowWebSocketTask: WebSocketTaskProtocol, @unchecked Sendable {
            private let frameData: Data
            private let sentCount = Mutex<Int>(0)

            init(frameData: Data) {
                self.frameData = frameData
            }

            func resume() {}

            func receive() async throws -> URLSessionWebSocketTask.Message {
                let current = sentCount.withLock { count -> Int in
                    count += 1
                    return count
                }
                if current <= 1005 {
                    return .data(frameData)
                } else {
                    // Sleep to prevent infinite loop after buffer overflows
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    return .data(frameData)
                }
            }

            func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {}
        }

        NetworkService.dnsResolverOverride = { host in
            if host == "pds.example.com" {
                return ["93.184.216.34"]
            }
            return nil
        }
        NetworkService.webSocketTaskOverride = { _ in
            MockOverflowWebSocketTask(frameData: frameBytes)
        }
        defer {
            NetworkService.dnsResolverOverride = nil
            NetworkService.webSocketTaskOverride = nil
        }

        let service = NetworkService(baseURL: URL(string: "https://pds.example.com")!)
        let stream: AsyncThrowingStream<TestSubMessage, Error> = try await service.subscribe(
            endpoint: "com.atproto.sync.subscribeRepos",
            parameters: nil
        )
        var caughtOverflow = false
        do {
            for try await _ in stream {
                // Slow consumer to let the 1000-message producer buffer saturate and drop
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        } catch let error as NetworkError {
            if case .streamOverflow = error {
                caughtOverflow = true
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(caughtOverflow, "Expected NetworkService.subscribe to terminate throwing NetworkError.streamOverflow on drop")
    }
    @Test("Server-trust revalidation uses the delegate async resolver seam")
    func serverTrustRevalidationSeam() async throws {
        let url = URL(string: "https://pds.example.com/xrpc/test")!
        let cases: [(String, @Sendable (String) async throws -> [String], Bool)] = [
            ("matching approved addresses", { _ in ["93.184.216.34"] }, true),
            ("different public addresses with intersection", { _ in ["93.184.216.34", "93.184.216.35"] }, true),
            ("fully disjoint public addresses", { _ in ["93.184.216.35"] }, false),
            ("private rebinding", { _ in ["10.0.0.1"] }, false),
            ("resolver failure", { _ in throw URLError(.cannotFindHost) }, false)
        ]
        for (_, resolver, expected) in cases {
            let delegate = HardenedURLSessionDelegate(resolver: resolver)
            let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
            defer { session.invalidateAndCancel() }
            let task = session.dataTask(with: url)
            delegate.contextManager.register(task) { _ in }
            delegate.contextManager.setApprovedAddresses(["93.184.216.34"], for: task)
            #expect(await delegate.serverTrustIsApproved(for: task, host: "pds.example.com") == expected)
        }
    }
}
