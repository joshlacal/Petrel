import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

/// Counts transport executions across concurrent test tasks.
private actor ExecutionCount {
    private var value = 0
    func increment() { value += 1 }
    func get() -> Int { value }
}

/// One-shot gate: `wait()` suspends until `open()`; no clock involved.
private actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }
}

/// Concurrent identical GETs share one transport task. Calls that differ in a header the
/// service answers by (`atproto-proxy`, `atproto-accept-labelers`, any caller header) are
/// not identical, so they must not share a response.
@Suite("Request deduplication is partitioned by request headers")
struct RequestDeduplicatorHeaderTests {
    static let url = URL(string: "https://pds.example.com/xrpc/app.bsky.feed.getTimeline")!

    private func request(_ headers: [String: String]) -> URLRequest {
        var request = URLRequest(url: Self.url)
        request.httpMethod = "GET"
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }

    private func key(
        _ headers: [String: String],
        ignoring ignoredHeaders: Set<String> = []
    ) -> RequestDeduplicator.RequestKey? {
        RequestDeduplicator.RequestKey(
            from: request(headers), authIdentity: "did:plc:user", ignoringHeaders: ignoredHeaders
        )
    }

    @Test("Different atproto-proxy, labelers or caller headers give different keys")
    func responseAffectingHeadersSplitTheKey() {
        let base = key(["atproto-proxy": "did:web:api.bsky.app#bsky_appview"])
        #expect(base != nil)
        #expect(base != key(["atproto-proxy": "did:web:other.example.com#bsky_appview"]))
        #expect(base != key([:]))
        #expect(key(["atproto-accept-labelers": "did:plc:a"]) != key(["atproto-accept-labelers": "did:plc:b"]))
        #expect(key(["X-Widget-Variant": "a"]) != key(["X-Widget-Variant": "b"]))
    }

    @Test("Per-request credentials and the configured request-id header do not split the key")
    func volatileHeadersDoNotSplitTheKey() {
        let ignored: Set<String> = ["x-request-id"]
        let first = key([
            "atproto-proxy": "did:web:api.bsky.app#bsky_appview",
            "Authorization": "DPoP token-1",
            "DPoP": "proof-1",
            "X-Request-Id": "11111111-1111-1111-1111-111111111111",
        ], ignoring: ignored)
        let second = key([
            "atproto-proxy": "did:web:api.bsky.app#bsky_appview",
            "Authorization": "DPoP token-1",
            "DPoP": "proof-2",
            "X-Request-Id": "22222222-2222-2222-2222-222222222222",
        ], ignoring: ignored)
        #expect(first != nil)
        #expect(first == second)
    }

    @Test("Ignored header names are matched without regard to case")
    func ignoredHeaderNamesAreCaseInsensitive() {
        let first = key(["X-Trace": "a"], ignoring: ["X-TRACE"])
        let second = key(["x-trace": "b"], ignoring: ["X-TRACE"])
        #expect(first == second)
    }

    @Test("A request-id-like header that was not configured is an ordinary caller header")
    func unconfiguredRequestIDHeaderSplitsTheKey() {
        #expect(key(["X-Request-Id": "a"]) != key(["X-Request-Id": "b"]))
        #expect(key(["X-Catbird-Request-Id": "a"]) != key(["X-Catbird-Request-Id": "b"]))
    }

    @Test("Concurrent identical calls that differ only in the configured request id share one request")
    func configuredRequestIDHeaderDoesNotDefeatDeduplication() async throws {
        let deduplicator = RequestDeduplicator()
        let executed = ExecutionCount()
        let gate = AsyncGate()
        let work: @Sendable () async throws -> (Data, URLResponse) = {
            await executed.increment()
            await gate.wait()
            let response = HTTPURLResponse(url: Self.url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("shared".utf8), response)
        }
        let first = request(["X-Request-Id": "11111111-1111-1111-1111-111111111111"])
        let second = request(["X-Request-Id": "22222222-2222-2222-2222-222222222222"])
        let ignored: Set<String> = ["X-Request-Id"]
        async let a = deduplicator.deduplicate(request: first, authIdentity: "did:plc:user", ignoringHeaders: ignored, work: work)
        var spins = 0
        while await executed.get() == 0, spins < 1_000_000 { spins += 1; await Task.yield() }
        #expect(await deduplicator.isRequestInFlight(second, authIdentity: "did:plc:user", ignoringHeaders: ignored))
        let joined = ExecutionCount()
        async let b = deduplicator.deduplicate(
            request: second, authIdentity: "did:plc:user", ignoringHeaders: ignored,
            onJoinExisting: { Task { await joined.increment() } }, work: work
        )
        spins = 0
        while await joined.get() == 0, spins < 1_000_000 { spins += 1; await Task.yield() }
        #expect(await joined.get() == 1)
        await gate.open()
        let (ra, rb) = try await (a, b)
        #expect(ra.0 == Data("shared".utf8))
        #expect(rb.0 == Data("shared".utf8))
        #expect(await executed.get() == 1)
    }

    @Test("Header names are compared without regard to case")
    func headerNameCaseDoesNotSplitTheKey() {
        #expect(key(["Atproto-Proxy": "did:web:x#y"]) == key(["atproto-proxy": "did:web:x#y"]))
    }

    @Test("Concurrent calls with different proxies each send their own request")
    func concurrentCallsWithDifferentProxiesDoNotCoalesce() async throws {
        let deduplicator = RequestDeduplicator()
        let executed = ExecutionCount()
        let work: @Sendable (String) async throws -> (Data, URLResponse) = { body in
            await executed.increment()
            try? await Task.sleep(nanoseconds: 30_000_000)
            let response = HTTPURLResponse(url: Self.url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        }
        let appview = request(["atproto-proxy": "did:web:api.bsky.app#bsky_appview"])
        let other = request(["atproto-proxy": "did:web:other.example.com#bsky_appview"])

        async let first = deduplicator.deduplicate(request: appview, authIdentity: "did:plc:user") {
            try await work("appview")
        }
        async let second = deduplicator.deduplicate(request: other, authIdentity: "did:plc:user") {
            try await work("other")
        }
        let (a, b) = try await (first, second)

        #expect(a.0 == Data("appview".utf8))
        #expect(b.0 == Data("other".utf8))
        #expect(await executed.get() == 2)
    }
}
