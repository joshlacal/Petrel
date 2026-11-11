//
//  IdentityTransport.swift
//  Petrel
//

#if !canImport(Darwin)
    import AsyncDNSResolver
#endif
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import Synchronization

// MARK: - HTTP

/// One `GET` an ``IdentityResolver`` needs: a handle's `/.well-known/atproto-did`, a DID
/// document, or a `com.atproto.identity.resolveHandle` query.
public struct IdentityHTTPRequest: Sendable, Equatable {
    /// The URL to fetch.
    public var url: URL
    /// The `Accept` header value.
    public var accept: String
    /// The time allowed for the whole exchange, in seconds.
    public var timeout: TimeInterval
    /// The largest response body, in bytes, that may be returned.
    public var maximumResponseBytes: Int
    /// Whether HTTP redirects are followed. Handle lookups follow a bounded number of
    /// redirects; DID document fetches do not follow any.
    public var followsRedirects: Bool

    /// Creates a request.
    public init(
        url: URL,
        accept: String,
        timeout: TimeInterval,
        maximumResponseBytes: Int,
        followsRedirects: Bool
    ) {
        self.url = url
        self.accept = accept
        self.timeout = timeout
        self.maximumResponseBytes = maximumResponseBytes
        self.followsRedirects = followsRedirects
    }
}

/// The answer to an ``IdentityHTTPRequest``.
public struct IdentityHTTPResponse: Sendable, Equatable {
    /// The HTTP status code of the final response.
    public var statusCode: Int
    /// The response body, already decompressed.
    public var body: Data

    /// Creates a response.
    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }
}

/// Performs the HTTP requests of an ``IdentityResolver``.
///
/// Handle hosts and `did:web` hosts are chosen by whoever owns the identifier, so every
/// destination is untrusted. An implementation must:
///
/// - send no credentials, cookies or account-specific headers, and never retry a request with
///   credentials after a `401`;
/// - return any status code as a response rather than throwing, so the resolver can tell "not
///   found" from failure;
/// - enforce `maximumResponseBytes` and `timeout`;
/// - refuse destinations that resolve to private, loopback or reserved addresses, unless it is
///   deliberately built for a closed network.
///
/// ``HardenedIdentityHTTPTransport`` is the default. Supply your own to route lookups through a
/// different HTTP client or a test double.
public protocol IdentityHTTPTransport: Sendable {
    /// Performs `request` and returns the final response.
    func send(_ request: IdentityHTTPRequest) async throws -> IdentityHTTPResponse
}

/// The default ``IdentityHTTPTransport``: a `URLSession` that holds no credentials and applies
/// Petrel's network policy to every hop.
///
/// - The session is ephemeral, with no cookie storage, credential storage or cache, and adds no
///   headers beyond `Accept` and an optional `User-Agent`.
/// - Before connecting, and again before each redirect, the host is resolved and rejected if any
///   address is private, loopback, link-local or otherwise reserved. Cleartext `http` is allowed
///   only to `localhost`, `127.0.0.1` and `::1`.
/// - At most five redirects are followed, and only when the request asks for them.
/// - The response is cut off at `maximumResponseBytes`, on the wire and after decompression.
public final class HardenedIdentityHTTPTransport: IdentityHTTPTransport {
    private let userAgent: String?
    private let redirectingSession: URLSession
    private let redirectingDelegate: HardenedURLSessionDelegate
    private let directSession: URLSession
    private let directDelegate: HardenedURLSessionDelegate

    /// Creates the transport.
    /// - Parameter userAgent: An optional `User-Agent` header value.
    public init(userAgent: String? = nil) {
        self.userAgent = userAgent
        (redirectingSession, redirectingDelegate) = Self.makeSession(allowsRedirects: true)
        (directSession, directDelegate) = Self.makeSession(allowsRedirects: false)
    }

    deinit {
        // URLSession keeps its delegate alive until it is invalidated.
        redirectingSession.finishTasksAndInvalidate()
        directSession.finishTasksAndInvalidate()
    }

    private static func makeSession(allowsRedirects: Bool) -> (URLSession, HardenedURLSessionDelegate) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        #if DEBUG
            if let testClasses = NetworkService.getNetworkTestProtocolClasses() {
                configuration.protocolClasses = testClasses
            }
        #endif
        let delegate = HardenedURLSessionDelegate(allowsRedirects: allowsRedirects, limits: .default)
        #if DEBUG && canImport(Network) && canImport(Security)
            if let fixture = delegate.fixtureTransport {
                // A debug fixture transport that cannot configure a session leaves it unable to
                // reach fixture hosts; requests then fail closed in `send`.
                try? fixture.configure(configuration)
            }
        #endif
        return (URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil), delegate)
    }

    public func send(_ request: IdentityHTTPRequest) async throws -> IdentityHTTPResponse {
        let url = request.url
        let urlString = url.absoluteString
        #if DEBUG && canImport(Network) && canImport(Security)
            let permittedByFixture = DebugFixtureTransport.current?.permits(url) == true
        #else
            let permittedByFixture = false
        #endif
        var urlRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = request.timeout
        urlRequest.httpShouldHandleCookies = false
        urlRequest.setValue(request.accept, forHTTPHeaderField: "Accept")
        if let userAgent {
            urlRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        let limits = NetworkResponseLimits(
            maximumWireBytes: request.maximumResponseBytes,
            maximumDecodedBytes: request.maximumResponseBytes
        )
        let session = request.followsRedirects ? redirectingSession : directSession
        let delegate = request.followsRedirects ? redirectingDelegate : directDelegate
        let prepared = urlRequest

        do {
            return try await IdentityDeadline.run(seconds: request.timeout, describing: "GET \(urlString)") {
                // IdentityDeadline returns at the limit without waiting for this closure. Keep the
                // transport alive until the request ends: its deinit invalidates the session, and
                // creating a task on an invalidated session traps.
                defer { withExtendedLifetime(self) {} }
                if !permittedByFixture {
                    guard try await NetworkService.validateURL(url) else {
                        throw IdentityError.blockedByNetworkPolicy(url: urlString)
                    }
                }
                let (data, response) = try await NetworkService.executeDataTask(
                    prepared, using: session, delegate: delegate, limits: limits
                )
                guard let http = response as? HTTPURLResponse else {
                    throw IdentityError.transport(url: urlString, reason: "The response was not an HTTP response.")
                }
                guard data.count <= request.maximumResponseBytes else {
                    throw IdentityError.responseTooLarge(url: urlString)
                }
                return IdentityHTTPResponse(statusCode: http.statusCode, body: data)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as IdentityError {
            throw error
        } catch NetworkError.securityViolation {
            throw IdentityError.blockedByNetworkPolicy(url: urlString)
        } catch NetworkError.responseLimitExceeded {
            throw IdentityError.responseTooLarge(url: urlString)
        } catch let error as URLError where error.code == .cancelled {
            // URLSession reports a task cancelled by the hardened delegate (a refused redirect
            // or an oversized body) and one cancelled by the caller the same way.
            if Task.isCancelled { throw CancellationError() }
            throw IdentityError.transport(url: urlString, reason: "The request was cancelled by the network policy.")
        } catch let error as URLError where error.code == .timedOut {
            throw IdentityError.timedOut("GET \(urlString)")
        } catch {
            throw IdentityError.transport(url: urlString, reason: String(describing: error))
        }
    }
}

// MARK: - DNS

/// Looks up DNS TXT records for an ``IdentityResolver``.
///
/// Handle resolution queries `_atproto.<handle>`. ``SystemIdentityDNSResolver`` is the default;
/// supply your own to use DNS over HTTPS, a recursive resolver of your choice, or a test double.
public protocol IdentityDNSResolver: Sendable {
    /// Returns the value of every TXT record at `name`, each with its character-strings joined.
    ///
    /// Return an empty array when the name does not exist or has no TXT records. Throw only when
    /// the lookup itself failed (timeout, refused connection), so the resolver can tell "no
    /// record" from "could not ask".
    func queryTXT(name: String) async throws -> [String]
}

/// The default ``IdentityDNSResolver``, using the platform's resolver configuration: the system
/// resolver (`dnssd`) on Apple platforms and `c-ares` on Linux.
public struct SystemIdentityDNSResolver: IdentityDNSResolver {
    /// Creates the resolver.
    public init() {}

    public func queryTXT(name: String) async throws -> [String] {
        #if DEBUG
            if let override = Self.testOverride.withLock({ $0 }) {
                return try await override(name)
            }
        #endif
        #if canImport(Darwin)
            return try await SystemDNSTXTQuery.run(name: name)
        #else
            do {
                let resolver = try AsyncDNSResolver()
                return try await resolver.queryTXT(name: name).map(\.txt)
            } catch let error as AsyncDNSResolver.Error {
                if Self.meansNoRecord(error) {
                    return []
                }
                throw error
            }
        #endif
    }

    #if !canImport(Darwin)
        /// Whether the c-ares error reports that the name or record type does not exist, as
        /// opposed to a lookup that could not be completed.
        static func meansNoRecord(_ error: AsyncDNSResolver.Error) -> Bool {
            guard let cAres = error.source as? CAresError else { return false }
            // ARES_ENODATA (1) and ARES_ENOTFOUND (4).
            return cAres.code == 1 || cAres.code == 4
        }
    #endif

    #if DEBUG
        /// Replaces the system lookup in tests so no test depends on live DNS.
        package static let testOverride = Mutex<(@Sendable (String) async throws -> [String])?>(nil)
    #endif
}

/// An ``IdentityDNSResolver`` backed by a closure.
struct ClosureIdentityDNSResolver: IdentityDNSResolver {
    let lookup: @Sendable (String) async throws -> [String]

    func queryTXT(name: String) async throws -> [String] {
        try await lookup(name)
    }
}

// MARK: - Deadline

/// Runs an operation against a wall-clock limit.
enum IdentityDeadline {
    private final class Race<T: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<T, Error>?
        private var result: Result<T, Error>?

        /// Hands over the continuation, or resumes it at once if the race is already decided.
        func install(_ continuation: CheckedContinuation<T, Error>) {
            lock.lock()
            if let result {
                lock.unlock()
                continuation.resume(with: result)
            } else {
                self.continuation = continuation
                lock.unlock()
            }
        }

        /// Records the first result; later ones are dropped.
        func finish(_ result: Result<T, Error>) {
            lock.lock()
            guard self.result == nil else {
                lock.unlock()
                return
            }
            self.result = result
            let continuation = self.continuation
            self.continuation = nil
            lock.unlock()
            continuation?.resume(with: result)
        }
    }

    /// Returns the operation's result, or throws ``IdentityError/timedOut(_:)`` once `seconds`
    /// have passed.
    ///
    /// The operation is cancelled when the limit passes or the caller is cancelled, but the
    /// caller does not wait for it to notice: the system DNS query on Apple platforms blocks a
    /// thread and ignores cancellation, and must not be able to hold a resolution past its limit.
    static func run<T: Sendable>(
        seconds: TimeInterval,
        describing what: String,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try Task.checkCancellation()
        let race = Race<T>()
        let work = Task {
            do {
                try race.finish(.success(await operation()))
            } catch {
                race.finish(.failure(error))
            }
        }
        let timer = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(max(seconds, 0) * 1_000_000_000))
            } catch {
                return
            }
            race.finish(.failure(IdentityError.timedOut(what)))
            work.cancel()
        }
        defer { timer.cancel() }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                race.install(continuation)
            }
        } onCancel: {
            work.cancel()
            race.finish(.failure(CancellationError()))
        }
    }
}
