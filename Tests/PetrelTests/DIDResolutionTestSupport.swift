import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import Petrel

/// An ``IdentityHTTPTransport`` that answers from a route table and records what it was asked.
final class MockIdentityHTTP: IdentityHTTPTransport, @unchecked Sendable {
    typealias Handler = @Sendable (IdentityHTTPRequest) async throws -> IdentityHTTPResponse

    private let lock = NSLock()
    private var routes: [(fragment: String, handler: Handler)] = []
    private var recorded: [IdentityHTTPRequest] = []

    /// Every request received, in order.
    var requests: [IdentityHTTPRequest] { lock.withLock { recorded } }

    /// The number of requests whose URL contains `fragment`.
    func requestCount(containing fragment: String) -> Int {
        requests.filter { $0.url.absoluteString.contains(fragment) }.count
    }

    /// Answers requests whose URL contains `fragment`. A later route for the same fragment wins.
    func on(_ fragment: String, _ handler: @escaping Handler) {
        lock.withLock { routes.insert((fragment, handler), at: 0) }
    }

    func on(_ fragment: String, status: Int = 200, body: String) {
        on(fragment) { _ in IdentityHTTPResponse(statusCode: status, body: Data(body.utf8)) }
    }

    /// Makes requests whose URL contains `fragment` fail in transit.
    func fail(_ fragment: String) {
        on(fragment) { request in
            throw IdentityError.transport(url: request.url.absoluteString, reason: "connection reset")
        }
    }

    func send(_ request: IdentityHTTPRequest) async throws -> IdentityHTTPResponse {
        let handler = lock.withLock { () -> Handler? in
            recorded.append(request)
            return routes.first { request.url.absoluteString.contains($0.fragment) }?.handler
        }
        guard let handler else {
            throw IdentityError.transport(url: request.url.absoluteString, reason: "no route in test")
        }
        return try await handler(request)
    }
}

/// An ``IdentityDNSResolver`` that answers from a table and records what it was asked.
final class MockIdentityDNS: IdentityDNSResolver, @unchecked Sendable {
    struct LookupFailure: Error {}

    private let lock = NSLock()
    private var records: [String: [String]] = [:]
    private var failing: Set<String> = []
    private var delays: [String: UInt64] = [:]
    private var hanging: Set<String> = []
    private var cancelled: [String] = []
    private var recorded: [String] = []

    /// Every name queried, in order.
    var queries: [String] { lock.withLock { recorded } }

    /// Every hanging lookup that was cancelled, in order.
    var cancelledQueries: [String] { lock.withLock { cancelled } }

    func set(_ name: String, _ values: [String]) {
        lock.withLock {
            records[name] = values
            failing.remove(name)
        }
    }

    /// Makes the lookup of `name` fail in transit.
    func fail(_ name: String) {
        lock.withLock { _ = failing.insert(name) }
    }

    /// Makes the lookup of `name` take this long before answering.
    func delay(_ name: String, seconds: Double) {
        lock.withLock { delays[name] = UInt64(seconds * 1_000_000_000) }
    }

    /// Makes the lookup of `name` never answer: it returns only by being cancelled, which is
    /// recorded in ``cancelledQueries``.
    func hang(_ name: String) {
        lock.withLock { _ = hanging.insert(name) }
    }

    /// Waits until the hanging lookup of `name` has been cancelled. Bounded by the caller's
    /// test time limit, not by a wall-clock assertion.
    func waitUntilCancelled(_ name: String) async throws {
        while !cancelledQueries.contains(name) {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    func queryTXT(name: String) async throws -> [String] {
        let (values, fails, delay, hangs) = lock.withLock { () -> ([String], Bool, UInt64?, Bool) in
            recorded.append(name)
            return (records[name] ?? [], failing.contains(name), delays[name], hanging.contains(name))
        }
        if hangs {
            do {
                while true {
                    try await Task.sleep(nanoseconds: 3_600_000_000_000)
                }
            } catch {
                lock.withLock { cancelled.append(name) }
                throw error
            }
        }
        if let delay {
            try await Task.sleep(nanoseconds: delay)
        }
        if fails { throw LookupFailure() }
        return values
    }
}

/// A clock a test moves by hand.
final class IdentityTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_800_000_000)

    var now: Date { lock.withLock { current } }

    func advance(by seconds: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(seconds) }
    }
}

enum IdentityFixtures {
    /// A DID document as the PLC directory or a `did:web` host would serve it.
    static func document(
        did: String,
        handles: [String] = [],
        pds: String? = "https://pds.example.com",
        verificationMethods: [[String: String]] = [],
        services: [[String: String]] = []
    ) -> String {
        var allServices = services
        if let pds {
            allServices.insert(
                ["id": "#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": pds], at: 0
            )
        }
        let object: [String: Any] = [
            "@context": ["https://www.w3.org/ns/did/v1"],
            "id": did,
            "alsoKnownAs": handles.map { "at://\($0)" },
            "verificationMethod": verificationMethods,
            "service": allServices,
        ]
        // Force-unwrap: the object is built from strings and arrays of strings only.
        return String(data: try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), encoding: .utf8)!
    }

    /// The lines of a vendored interop vector file, without comments and blank lines. Lines are
    /// not trimmed: leading and trailing whitespace is part of some invalid vectors.
    static func vectorLines(_ name: String) throws -> [String] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Vectors/identity") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    /// The contents of a vendored interop JSON vector file.
    static func vectorJSON(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Vectors/identity") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}

extension IdentityResolver.Options {
    /// The library defaults, except a timeout no CI stall can outlast. The resolver bounds
    /// each DNS query with a real deadline even when a test double answers it, and runners
    /// have frozen test processes for 87 to 129 s; tests about timeouts set their own.
    static var stubbed: Self {
        Self(timeout: 5 * 60)
    }
}

extension IdentityResolver {
    /// A resolver wired to test doubles and, optionally, a hand-moved clock.
    static func forTesting(
        http: MockIdentityHTTP,
        dns: MockIdentityDNS,
        options: Options = .stubbed,
        cache: (any IdentityCache)? = nil,
        clock: IdentityTestClock? = nil
    ) -> IdentityResolver {
        let now: @Sendable () -> Date
        if let clock {
            now = { clock.now }
        } else {
            now = { Date() }
        }
        return IdentityResolver(options: options, cache: cache, httpTransport: http, dnsResolver: dns, now: now)
    }
}
