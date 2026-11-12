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
/// transport only for the request's lifetime, so it must not leak one). Under load this test
/// also caught requests that never ended at all; `requestCancelledBeforeStartReturns` pins
/// that cause down.
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
            // A request that never ends holds its transport forever, so the wait is woken by
            // each release and only gives up, to fail rather than hang, long after it should
            // have finished.
            let allReleased = await released.waitUntilAllReleased(atMost: 300)
            #expect(allReleased, "\(released.liveCount) transports still held by unfinished requests")
        }
    }

    /// The race behind the flaky test above, made deterministic. A deadline (or any caller)
    /// can cancel a request after its data task is created but before
    /// `withTaskCancellationHandler` is entered; the handler then cancels the task before its
    /// operation runs. URLSession reports a task cancelled before `resume()` as complete, on its
    /// own queue. If that report arrived before the task was registered with the delegate it was
    /// dropped, the continuation was never resumed, and the request (and whatever it held, such
    /// as its transport) hung forever. The hook below forces that order every time.
    @Test("A request cancelled before its data task starts still returns")
    func requestCancelledBeforeStartReturns() async throws {
        try await withSerializedStorageOverrideTest {
            let delegate = HardenedURLSessionDelegate(allowsRedirects: false, limits: .default)
            let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
            defer { session.invalidateAndCancel() }
            NetworkService.dataTaskCreatedHook = { task, taskSession in
                guard taskSession === session else { return }
                // The caller is cancelled before the cancellation handler is installed...
                withUnsafeCurrentTask { $0?.cancel() }
                // ...and URLSession has already delivered the cancelled task's completion.
                // (Bounded only so a platform that defers the report cannot hang the test.)
                task.cancel()
                let giveUp = Date().addingTimeInterval(300)
                while task.state != .completed, Date() < giveUp {
                    Thread.sleep(forTimeInterval: 0.001)
                }
                taskSession.delegateQueue.addOperations([BlockOperation {}], waitUntilFinished: true)
            }
            defer { NetworkService.dataTaskCreatedHook = nil }

            // An address literal: no DNS lookup, and the task is cancelled before it connects.
            let request = try URLRequest(url: #require(URL(string: "https://93.184.216.34/")))
            let returned = Completion()
            let call = Task {
                defer { returned.signal() }
                return try await NetworkService.executeDataTask(request, using: session, delegate: delegate)
            }
            let didReturn = await returned.wait(atMost: 300)
            #expect(didReturn, "executeDataTask never returned after its task was cancelled")
            guard didReturn else {
                call.cancel()
                return
            }
            await #expect(throws: (any Error).self) { try await call.value }
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

    /// Waits until every added transport has been released, rechecking each time any transport
    /// is deinitialized. Returns `false` if `seconds` pass first.
    func waitUntilAllReleased(atMost seconds: TimeInterval) async -> Bool {
        let (releases, continuation) = AsyncStream<Void>.makeStream()
        HardenedIdentityHTTPTransport.deinitHook = { continuation.yield() }
        defer { HardenedIdentityHTTPTransport.deinitHook = nil }
        let ceiling = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            continuation.finish()
        }
        defer { ceiling.cancel() }
        // A release before the hook was installed is already reflected in the count.
        if liveCount == 0 { return true }
        for await _ in releases where liveCount == 0 {
            return true
        }
        return liveCount == 0
    }
}

/// A one-shot signal that can be awaited with an upper bound.
private final class Completion: @unchecked Sendable {
    private let lock = NSLock()
    private var isSignalled = false
    private var waiter: CheckedContinuation<Bool, Never>?

    func signal() {
        lock.lock()
        isSignalled = true
        let waiter = self.waiter
        self.waiter = nil
        lock.unlock()
        waiter?.resume(returning: true)
    }

    func wait(atMost seconds: TimeInterval) async -> Bool {
        let ceiling = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            self.timeOut()
        }
        defer { ceiling.cancel() }
        return await withCheckedContinuation { continuation in
            lock.lock()
            if isSignalled {
                lock.unlock()
                continuation.resume(returning: true)
            } else {
                waiter = continuation
                lock.unlock()
            }
        }
    }

    private func timeOut() {
        lock.lock()
        let waiter = self.waiter
        self.waiter = nil
        lock.unlock()
        waiter?.resume(returning: false)
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
