import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel
import Testing

/// `IdentityDeadline` returns at the deadline without waiting for the request it started (the
/// system DNS query cannot be interrupted). That request must keep the transport's session
/// valid: when the deadline passed between the request's DNS step and its `dataTask` call and
/// the caller then dropped the transport, `deinit` invalidated the session under the request and
/// `dataTask` trapped ("Session invalidated", swift-corelibs-foundation on Linux; Darwin fails
/// the task quietly). The window is narrow, so this test aims many requests at it: each one's
/// DNS answer arrives at about its deadline, and its caller drops the transport at once. It
/// checks that every abandoned request still ends and releases its transport (the fix holds the
/// transport only for the request's lifetime, so it must not leak one).
///
/// Not run on Linux: there, cancelling a task while a `URLProtocol` test double is answering
/// traps inside swift-corelibs-foundation (`TaskRegistry.swift:118`) whether or not the session
/// is ever invalidated, so the double cannot tell a fixed build from a broken one.
@Suite("Hardened identity transport lifetime")
struct HardenedIdentityTransportLifetimeTests {
    #if canImport(FoundationNetworking)
        static let urlProtocolSurvivesCancellation = false
    #else
        static let urlProtocolSurvivesCancellation = true
    #endif

    @Test(
        "Requests that outlive their deadline keep their session after the caller drops the transport",
        .enabled(if: urlProtocolSurvivesCancellation)
    )
    func requestsOutlivingDeadlineKeepSession() async throws {
        try await withSerializedStorageOverrideTest {
            let host = "lexicon-lifetime.example.com"
            let timeout: TimeInterval = 0.02
            LifetimeURLProtocol.reset()
            NetworkService.setNetworkTestProtocolClasses([LifetimeURLProtocol.self])
            NetworkService.dnsResolverOverride = { queried in
                guard queried == host else { return nil }
                // A request makes two lookups (URL policy, then the connection's approved
                // addresses); jitter them so the second answer lands around the deadline.
                Thread.sleep(forTimeInterval: timeout * Double.random(in: 0.25 ... 0.6))
                return ["93.184.216.34"]
            }
            defer {
                NetworkService.setNetworkTestProtocolClasses(nil)
                NetworkService.dnsResolverOverride = nil
                LifetimeURLProtocol.reset()
            }

            let request = try IdentityHTTPRequest(
                url: #require(URL(string: "https://\(host)/xrpc/com.atproto.repo.getRecord")),
                accept: "application/json",
                timeout: timeout,
                maximumResponseBytes: 1024,
                followsRedirects: false
            )
            let released = WeakTransports()
            // Rounds as wide as NetworkService's DNS queue, so no lookup waits in line.
            for _ in 0 ..< 200 {
                await withTaskGroup(of: Void.self) { group in
                    for _ in 0 ..< 6 {
                        group.addTask {
                            // The only strong reference outside the request: dropped when `send` returns.
                            let transport = HardenedIdentityHTTPTransport()
                            released.add(transport)
                            _ = try? await transport.send(request)
                        }
                    }
                }
            }

            // Every abandoned request ends (against a valid session) and releases its transport.
            let deadline = Date().addingTimeInterval(10)
            while released.liveCount > 0, Date() < deadline {
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            #expect(released.liveCount == 0)
        }
    }
}

private final class WeakTransports: @unchecked Sendable {
    private struct Entry {
        weak var transport: HardenedIdentityHTTPTransport?
    }

    private let lock = NSLock()
    private var entries: [Entry] = []

    func add(_ transport: HardenedIdentityHTTPTransport) {
        lock.lock()
        entries.append(Entry(transport: transport))
        lock.unlock()
    }

    var liveCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count { $0.transport != nil }
    }
}

private final class LifetimeURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var count = 0

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    static func reset() {
        lock.lock()
        count = 0
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "lexicon-lifetime.example.com"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.count += 1
        Self.lock.unlock()
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
