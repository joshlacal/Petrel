import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
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

    @Test("Finding 3: Non-idempotent or non-GET/HEAD HTTP methods are not deduplicated")
    func requestDeduplicatorPreservesMethodCase() async throws {
        let deduplicator = RequestDeduplicator()
        let url = URL(string: "https://bsky.social/xrpc/test")!

        var request1 = URLRequest(url: url)
        request1.httpMethod = "PATCH"
        var request2 = URLRequest(url: url)
        request2.httpMethod = "PATCH"

        let counter = Counter()

        async let first = deduplicator.deduplicate(request: request1) {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 20_000_000)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("1".utf8), response)
        }

        async let second = deduplicator.deduplicate(request: request2) {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 20_000_000)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("2".utf8), response)
        }

        let (res1, res2) = try await (first, second)
        #expect(res1.0 == Data("1".utf8))
        #expect(res2.0 == Data("2".utf8))
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

    @Test("NetworkService blocks private and loopback IP addresses")
    func networkServiceBlocksPrivateIPs() async throws {
        let service = NetworkService(baseURL: URL(string: "https://bsky.social")!)

        let privateURLs = [
            "http://127.0.0.1/xrpc/test",
            "http://10.0.0.1/xrpc/test",
            "http://192.168.1.1/xrpc/test",
            "http://172.16.0.1/xrpc/test",
            "http://169.254.1.1/xrpc/test",
            "http://0.0.0.0/xrpc/test",
            "http://255.255.255.255/xrpc/test"
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

    @Test("Finding 3: In-flight DNS resolution cancellation propagates CancellationError promptly")
    func networkServiceCancellationPropagates() async throws {
        let service = NetworkService(baseURL: URL(string: "https://bsky.social")!)

        let enteredResolution = Flag()
        let cancellationHost = "cancellation-test.bsky.social"

        NetworkService.dnsResolutionHook = { host in
            guard host == cancellationHost else { return }
            await enteredResolution.setTrue()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000)
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

        // Wait until DNS resolution is actively in-flight
        while !(await enteredResolution.get()) {
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        // Cancel while in-flight
        task.cancel()

        // Assert that CancellationError is thrown to the caller promptly
        do {
            _ = try await task.value
            Issue.record("Expected CancellationError, but task.value completed successfully")
        } catch is CancellationError {
            // Success: CancellationError propagated promptly to caller
        } catch {
            Issue.record("Expected CancellationError, but got: \(error)")
        }
    }
}
