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

    private func key(_ headers: [String: String]) -> RequestDeduplicator.RequestKey? {
        RequestDeduplicator.RequestKey(from: request(headers), authIdentity: "did:plc:user")
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

    @Test("Per-request credentials and request ids do not split the key")
    func volatileHeadersDoNotSplitTheKey() {
        let first = key([
            "atproto-proxy": "did:web:api.bsky.app#bsky_appview",
            "Authorization": "DPoP token-1",
            "DPoP": "proof-1",
            "X-Catbird-Request-Id": "11111111-1111-1111-1111-111111111111",
        ])
        let second = key([
            "atproto-proxy": "did:web:api.bsky.app#bsky_appview",
            "Authorization": "DPoP token-1",
            "DPoP": "proof-2",
            "X-Catbird-Request-Id": "22222222-2222-2222-2222-222222222222",
        ])
        #expect(first != nil)
        #expect(first == second)
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
