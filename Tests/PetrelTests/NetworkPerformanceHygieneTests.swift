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

@Suite("Network Performance Hygiene Tests")
struct NetworkPerformanceHygieneTests {
    // MARK: - Task 8: RequestDeduplicator Tests

    @Test("RequestDeduplicator deduplicates concurrent GET requests")
    func requestDeduplicatorCoalescesConcurrentGETs() async throws {
        let deduplicator = RequestDeduplicator()
        let url = URL(string: "https://bsky.social/xrpc/app.bsky.actor.getProfile")!

        var request1 = URLRequest(url: url)
        request1.httpMethod = "GET"
        var request2 = URLRequest(url: url)
        request2.httpMethod = "GET"

        let counter = Counter()

        // Launch two concurrent requests for the exact same GET URL
        async let first = deduplicator.deduplicate(request: request1) {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("response".utf8), response)
        }

        async let second = deduplicator.deduplicate(request: request2) {
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

    @Test("NetworkService validates and caches legitimate hostnames")
    func networkServiceValidatesAndCachesHost() async throws {
        let service = NetworkService(baseURL: URL(string: "https://bsky.social")!)

        // First call: resolves host and caches result
        let req1 = try await service.createURLRequest(
            endpoint: "https://bsky.social/xrpc/app.bsky.actor.getProfile",
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )
        #expect(req1.url?.host == "bsky.social")

        // Second call: served from host validation cache
        let req2 = try await service.createURLRequest(
            endpoint: "https://bsky.social/xrpc/app.bsky.feed.getTimeline",
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )
        #expect(req2.url?.host == "bsky.social")
    }
}
