import Foundation
import PetrelCrypto

#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// A parsed IP address used for DNS and final-peer policy enforcement. The
/// value keeps network-order bytes, avoiding string-prefix classification bugs.
public enum OAuthIPAddress: Hashable, Sendable, Equatable, CustomStringConvertible {
    /// An IPv4 address in host byte order.
    case ipv4(UInt32)
    /// An IPv6 address as 16 network-order bytes.
    case ipv6(Data)

    /// Parses a textual IPv4 or IPv6 literal (brackets allowed), or returns `nil`.
    public init?(literal: String) {
        let input = literal.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        var ipv4 = in_addr()
        if input.withCString({ inet_pton(AF_INET, $0, &ipv4) }) == 1 {
            let bytes = [UInt8](Data(bytes: &ipv4, count: MemoryLayout<in_addr>.size))
            guard bytes.count == 4 else { return nil }
            self = .ipv4(
                (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) |
                    (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
            )
        } else {
            var ipv6 = in6_addr()
            guard input.withCString({ inet_pton(AF_INET6, $0, &ipv6) }) == 1 else { return nil }
            let bytes = Data(bytes: &ipv6, count: MemoryLayout<in6_addr>.size)
            guard bytes.count == 16 else { return nil }
            self = .ipv6(bytes)
        }
    }

    public var description: String {
        switch self {
        case let .ipv4(value):
            return "\((value >> 24) & 0xFF).\((value >> 16) & 0xFF).\((value >> 8) & 0xFF).\(value & 0xFF)"
        case let .ipv6(bytes):
            guard bytes.count == 16 else { return "[invalid IPv6]" }
            var raw = in6_addr()
            bytes.withUnsafeBytes { source in
                withUnsafeMutableBytes(of: &raw) { destination in destination.copyBytes(from: source) }
            }
            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            guard inet_ntop(AF_INET6, &raw, &buffer, socklen_t(buffer.count)) != nil else {
                return "[invalid IPv6]"
            }
            return String(
                decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
                as: UTF8.self
            )
        }
    }

    /// True for `127.0.0.0/8` and `::1`.
    public var isLoopback: Bool {
        switch self {
        case let .ipv4(value): OAuthPublicAddressPolicy.isLoopback(ipv4: value)
        case let .ipv6(bytes): OAuthPublicAddressPolicy.isLoopback(ipv6: bytes)
        }
    }

    /// True only for globally routable addresses. The intentional deny list
    /// includes private, loopback, link-local, CGNAT, documentation, multicast,
    /// and other reserved/special-purpose ranges rather than merely RFC1918.
    ///
    /// The table itself lives in ``OAuthPublicAddressPolicy`` because the AT
    /// handle verifier resolves attacker-selectable hostnames through the same
    /// boundary. Keeping two copies is how this one went on accepting 6to4
    /// after the handle copy stopped rejecting it in `b5f1610` (2026-07-27).
    public var isPublicInternetAddress: Bool {
        switch self {
        case let .ipv4(value):
            OAuthPublicAddressPolicy.isPublicInternetAddress(ipv4: value)
        case let .ipv6(bytes):
            OAuthPublicAddressPolicy.isPublicInternetAddress(ipv6: bytes)
        }
    }
}

/// Explicit, exact lab-address escape hatch. It is configuration, not an
/// implicit `localhost`/private-network relaxation.
public struct OAuthRemoteNetworkAllowlist: Sendable, Equatable {
    /// The permitted addresses.
    public let addresses: Set<OAuthIPAddress>

    /// Creates an allowlist.
    public init(addresses: Set<OAuthIPAddress> = []) {
        self.addresses = addresses
    }
}

/// The rules a remote document fetch must satisfy: HTTPS only, public addresses only, and bounded size and time.
public struct OAuthRemoteFetchPolicy: Sendable, Equatable {
    /// Whether `http://localhost` URLs that resolve to loopback are permitted.
    /// For development only.
    public let allowLoopbackDevelopment: Bool
    /// Addresses permitted in addition to the public internet, for
    /// deployments that fetch client documents from a known private host.
    public let networkAllowlist: OAuthRemoteNetworkAllowlist
    /// The largest response body accepted, in bytes.
    public let maximumBodyBytes: Int
    /// The time limit for DNS resolution and for the request.
    public let timeout: TimeInterval
    /// Whether the transport must report the address it connected to, and
    /// that address must appear in the DNS answers taken before and after the
    /// request. This closes the DNS-rebinding window between the address check
    /// and the connection. It defaults to true where the default transport can
    /// supply the proof (Apple platforms) and false elsewhere, where the
    /// before-and-after resolution check still applies.
    public let requiresConnectedPeerProof: Bool
    /// Whether the fetcher may use a transport whose
    /// ``OAuthRemoteTransport/pinsConnectionsToApprovedPeers`` is false.
    ///
    /// Such a transport resolves the host name again when it connects, so a
    /// host whose DNS answers change between the fetcher's check and the
    /// connection (DNS rebinding) can steer the request to a private address.
    /// The before-and-after resolution check and, where the transport reports
    /// it, the connected-peer check narrow that window but do not close it:
    /// the request has been sent by the time either runs. Leave this false
    /// unless outbound traffic is already confined to the public internet,
    /// for example by an egress proxy or firewall that refuses private ranges.
    public let allowsUnpinnedTransport: Bool

    /// The platform default for ``requiresConnectedPeerProof``.
    public static var defaultRequiresConnectedPeerProof: Bool {
        #if canImport(Darwin)
            true
        #else
            false
        #endif
    }

    /// Creates a policy.
    public init(
        allowLoopbackDevelopment: Bool = false,
        networkAllowlist: OAuthRemoteNetworkAllowlist = .init(),
        maximumBodyBytes: Int = 256 * 1024,
        timeout: TimeInterval = 5,
        requiresConnectedPeerProof: Bool = OAuthRemoteFetchPolicy.defaultRequiresConnectedPeerProof,
        allowsUnpinnedTransport: Bool = false
    ) throws {
        guard (1024 ... 1_048_576).contains(maximumBodyBytes), timeout > 0, timeout <= 30, timeout.isFinite else {
            throw OAuthServerError.malformed("OAuth remote fetch policy bounds are invalid")
        }
        self.allowLoopbackDevelopment = allowLoopbackDevelopment
        self.networkAllowlist = networkAllowlist
        self.maximumBodyBytes = maximumBodyBytes
        self.timeout = timeout
        self.requiresConnectedPeerProof = requiresConnectedPeerProof
        self.allowsUnpinnedTransport = allowsUnpinnedTransport
    }

    /// Checks the URL's scheme, credentials, fragment and any IP literal, and returns its host.
    public func validateURL(_ url: URL) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(), let host = components.host,
              components.user == nil, components.password == nil, components.fragment == nil else {
            throw OAuthServerError.unauthorized("OAuth remote URL is malformed")
        }
        // The localhost exception is an explicit development-only escape
        // hatch.  Local XRPC services commonly use a non-default port and a
        // method path; keeping the host literal still prevents it from
        // becoming a general private-network allowance.
        let localhostDevelopment = scheme == "http" && host == "localhost"
        guard scheme == "https" || (allowLoopbackDevelopment && localhostDevelopment) else {
            throw OAuthServerError.unauthorized("OAuth remote URL must use HTTPS")
        }
        if let literal = OAuthIPAddress(literal: host) {
            guard permits(literal, forHost: host) else {
                throw OAuthServerError.unauthorized("OAuth remote IP literal is not public")
            }
        }
        return host
    }

    /// Requires every resolved address of `host` to be permitted. One private answer among public ones refuses the host.
    public func validateResolved(_ addresses: [OAuthIPAddress], host: String) throws {
        guard !addresses.isEmpty, addresses.count <= 32,
              addresses.allSatisfy({ permits($0, forHost: host) }) else {
            throw OAuthServerError.unauthorized("OAuth remote host resolved to a forbidden address")
        }
    }

    /// Whether a connection to `address` on behalf of `host` is allowed.
    public func permits(_ address: OAuthIPAddress, forHost host: String) -> Bool {
        if networkAllowlist.addresses.contains(address) { return true }
        if allowLoopbackDevelopment && host == "localhost" && address.isLoopback { return true }
        return address.isPublicInternetAddress
    }
}

/// Compatibility surface for existing call sites. Unlike the old permissive
/// helper, `allowLoopbackDevelopment` only enables literal `http://localhost`
/// and never makes `127.0.0.1` or `::1` client metadata URLs acceptable.
public enum OAuthRemoteURLPolicy {
    /// Validates a URL against the default policy.
    public static func validate(_ url: URL, allowLoopbackDevelopment: Bool = false) throws {
        let policy = try OAuthRemoteFetchPolicy(allowLoopbackDevelopment: allowLoopbackDevelopment)
        _ = try policy.validateURL(url)
    }
}

/// Resolves a hostname to every address it currently maps to.
public protocol OAuthHostnameResolving: Sendable {
    func resolve(host: String) async throws -> [OAuthIPAddress]
}

/// Bounds blocking `getaddrinfo` work independently of async request
/// cancellation. A timed-out caller cannot cancel the libc call, so its lease
/// is released only when that blocking operation actually returns. This
/// prevents repeated DNS timeouts from accumulating an unbounded dispatch
/// backlog after the higher-level remote-fetch permit has been released.
final class OAuthBlockingDNSAdmission: @unchecked Sendable {
    static let shared = OAuthBlockingDNSAdmission(maximumOutstanding: 4)

    private let lock = NSLock()
    private let maximumOutstanding: Int
    private var outstanding = 0

    init(maximumOutstanding: Int) {
        precondition(maximumOutstanding > 0)
        self.maximumOutstanding = maximumOutstanding
    }

    func acquire() throws -> OAuthBlockingDNSLease {
        lock.lock()
        guard outstanding < maximumOutstanding else {
            lock.unlock()
            throw OAuthServerError.unavailable(
                "OAuth DNS resolver capacity is exhausted"
            )
        }
        outstanding += 1
        lock.unlock()
        return OAuthBlockingDNSLease(admission: self)
    }

    fileprivate func release() {
        lock.lock()
        precondition(outstanding > 0)
        outstanding -= 1
        lock.unlock()
    }

    var outstandingCountForTesting: Int {
        lock.lock()
        defer { lock.unlock() }
        return outstanding
    }
}

final class OAuthBlockingDNSLease: @unchecked Sendable {
    private let lock = NSLock()
    private var admission: OAuthBlockingDNSAdmission?

    fileprivate init(admission: OAuthBlockingDNSAdmission) {
        self.admission = admission
    }

    func release() {
        lock.lock()
        let held = admission
        admission = nil
        lock.unlock()
        held?.release()
    }

    deinit {
        release()
    }
}

/// Races DNS resolution against the same deadline used by the transport.
/// `getaddrinfo` does not expose a cancellation handle on every supported
/// platform, so this intentionally does not await a cancelled resolver task:
/// an unresponsive resolver cannot hold the caller past policy.timeout before
/// any network connection is attempted. The completion box is lock-protected
/// because it bridges that detached resolver work back to structured async
/// code exactly once.
private final class OAuthDNSResolutionDeadline: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<[OAuthIPAddress], Error>?
    private var result: Result<[OAuthIPAddress], Error>?

    func install(_ continuation: CheckedContinuation<[OAuthIPAddress], Error>) {
        lock.lock()
        if let result {
            lock.unlock()
            resume(continuation, with: result)
        } else {
            self.continuation = continuation
            lock.unlock()
        }
    }

    func complete(_ result: Result<[OAuthIPAddress], Error>) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        self.result = result
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        if let continuation {
            resume(continuation, with: result)
        }
    }

    private func resume(
        _ continuation: CheckedContinuation<[OAuthIPAddress], Error>,
        with result: Result<[OAuthIPAddress], Error>
    ) {
        switch result {
        case let .success(addresses):
            continuation.resume(returning: addresses)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }
}

/// Internal rather than file-private because every caller that holds a lease
/// or an admission permit across hostname resolution needs this deadline. The
/// authenticated pipethrough is one of them: it resolves a request-selected
/// service hostname while holding a proxy lease.
func resolveOAuthHostname(
    _ resolver: any OAuthHostnameResolving,
    host: String,
    timeout: TimeInterval
) async throws -> [OAuthIPAddress] {
    let completion = OAuthDNSResolutionDeadline()
    let resolutionTask = Task { @Sendable in
        do {
            completion.complete(.success(try await resolver.resolve(host: host)))
        } catch {
            completion.complete(.failure(error))
        }
    }
    let timeoutNanoseconds = UInt64((timeout * 1_000_000_000).rounded(.up))
    let timeoutTask = Task { @Sendable in
        do {
            try await Task.sleep(nanoseconds: timeoutNanoseconds)
        } catch {
            return
        }
        // Record the deadline's own outcome *before* cancelling the resolve,
        // because `complete` is first-wins. Cancelling first lets the resolver's
        // own `CancellationError` land first whenever cancellation propagates
        // faster than this task's next statement, and that raw error then
        // escapes an API whose contract is a typed `OAuthServerError`. It is a race
        // that a fast machine almost always wins and a loaded x86_64 does not:
        // the deadline test failed on the amd64 gate with `CancellationError`
        // while passing on arm64. Completing first makes the outcome the same
        // on every machine.
        completion.complete(.failure(OAuthServerError.unavailable("OAuth DNS resolution timed out")))
        resolutionTask.cancel()
    }
    defer {
        resolutionTask.cancel()
        timeoutTask.cancel()
    }
    return try await withTaskCancellationHandler(
        operation: {
            try await withCheckedThrowingContinuation { continuation in
                completion.install(continuation)
            }
        },
        onCancel: {
            // Same ordering rule, opposite intent: the caller was cancelled, so
            // `CancellationError` is the correct answer and has to be recorded
            // before the deadline task gets a chance to record `unavailable`.
            completion.complete(.failure(CancellationError()))
            resolutionTask.cancel()
            timeoutTask.cancel()
        }
    )
}

/// System DNS is kept behind this protocol so tests can simulate private A/AAAA
/// answers and a future hardened connector can share the exact resolution path.
public struct SystemOAuthHostnameResolver: OAuthHostnameResolving {
    /// Concurrent, with ``OAuthBlockingDNSAdmission`` as the sole bound on how
    /// many blocking `getaddrinfo` calls may be outstanding. A serial queue
    /// made those four permits unreachable — three permit holders would sit
    /// behind one unresponsive lookup — so a single blackholed nameserver
    /// stalled every OAuth, did:web, and pipethrough resolution in the
    /// process. The worst case is now four blocked dispatch threads instead
    /// of one, which is exactly what the admission limit is sized for.
    private static let queue = DispatchQueue(
        label: "petrel.oauth-server.dns",
        qos: .utility,
        attributes: .concurrent
    )

    /// Creates the resolver.
    public init() {}

    /// Resolves `host` with the system resolver.
    public func resolve(host: String) async throws -> [OAuthIPAddress] {
        if let literal = OAuthIPAddress(literal: host) { return [literal] }
        let admission = try OAuthBlockingDNSAdmission.shared.acquire()
        return try await withCheckedThrowingContinuation { continuation in
            Self.queue.async {
                defer { admission.release() }
                var hints = addrinfo()
                hints.ai_flags = AI_ADDRCONFIG
                hints.ai_family = AF_UNSPEC
                #if os(Linux)
                hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
                #else
                hints.ai_socktype = SOCK_STREAM
                #endif
                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(host, nil, &hints, &result)
                guard status == 0, let result else {
                    continuation.resume(throwing: OAuthServerError.unavailable("OAuth DNS resolution failed"))
                    return
                }
                defer { freeaddrinfo(result) }
                var values = Set<OAuthIPAddress>()
                var cursor: UnsafeMutablePointer<addrinfo>? = result
                while let current = cursor {
                    defer { cursor = current.pointee.ai_next }
                    guard let socketAddress = current.pointee.ai_addr else { continue }
                    switch Int32(current.pointee.ai_family) {
                    case AF_INET:
                        var address = socketAddress.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                        let bytes = [UInt8](Data(bytes: &address, count: MemoryLayout<in_addr>.size))
                        guard bytes.count == 4 else { continue }
                        values.insert(.ipv4(
                            (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) |
                                (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
                        ))
                    case AF_INET6:
                        var address = socketAddress.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee.sin6_addr }
                        let bytes = Data(bytes: &address, count: MemoryLayout<in6_addr>.size)
                        guard bytes.count == 16 else { continue }
                        values.insert(.ipv6(bytes))
                    default:
                        continue
                    }
                }
                continuation.resume(returning: values.sorted { $0.description < $1.description })
            }
        }
    }
}

/// What a transport observed for one GET.
public struct OAuthRemoteHTTPResponse: Sendable {
    /// The HTTP status code.
    public let status: Int
    /// Header names are lowercased by the AHC adapter. Fakes may provide any
    /// case; the fetcher canonicalizes them before validation.
    public let headers: [String: [String]]
    /// The response body.
    public let body: Data
    /// The URL that produced the response.
    public let responseURL: URL
    /// How many redirects the server attempted. Any value above zero is refused.
    public let redirectCount: Int
    /// A hardened connector should report the actual peer address here. AHC's
    /// high-level API currently cannot, so its adapter returns nil (documented
    /// in `AsyncHTTPClientOAuthTransport`).
    public let connectedPeerAddress: OAuthIPAddress?

    /// Creates a response.
    public init(
        status: Int,
        headers: [String: [String]],
        body: Data,
        responseURL: URL,
        redirectCount: Int = 0,
        connectedPeerAddress: OAuthIPAddress? = nil
    ) {
        self.status = status
        self.headers = headers
        self.body = body
        self.responseURL = responseURL
        self.redirectCount = redirectCount
        self.connectedPeerAddress = connectedPeerAddress
    }
}

/// Performs the GET for a remote document.
///
/// A transport used in production must connect only to a member of
/// `approvedPeers` and say so through ``pinsConnectionsToApprovedPeers``;
/// `PinnedNIOOAuthRemoteTransport` in the `PetrelOAuthServerHummingbird`
/// library of Petrel's `Server` package is one. ``URLSessionOAuthRemoteTransport``
/// cannot pin, and the fetcher refuses it unless the policy sets
/// ``OAuthRemoteFetchPolicy/allowsUnpinnedTransport``.
public protocol OAuthRemoteTransport: Sendable {
    /// True when every connection goes to a literal address from
    /// `approvedPeers`, with no name resolution of its own. Defaults to false.
    var pinsConnectionsToApprovedPeers: Bool { get }

    /// `approvedPeers` is the exact, policy-checked result of the DNS lookup
    /// immediately preceding this request. A production transport must select
    /// a literal member of this set before any HTTP bytes are sent.
    func get(
        url: URL,
        approvedPeers: Set<OAuthIPAddress>,
        timeout: TimeInterval,
        maximumBodyBytes: Int
    ) async throws -> OAuthRemoteHTTPResponse
}

extension OAuthRemoteTransport {
    /// A transport pins only if it says so.
    public var pinsConnectionsToApprovedPeers: Bool { false }
}

/// Applies the complete local policy around a single GET. It intentionally has
/// no cache: only a domain loader can know that a fetched JSON body was fully
/// validated before retaining it.
public struct OAuthRemoteDocumentFetcher: Sendable {
    /// The policy every fetch is held to.
    public let policy: OAuthRemoteFetchPolicy
    private let resolver: any OAuthHostnameResolving
    private let transport: any OAuthRemoteTransport

    /// Creates a fetcher.
    ///
    /// - Parameters:
    ///   - policy: bounds scheme, address range, size, and timeout for every fetch.
    ///   - resolver: resolves hostnames to candidate IP addresses before and after transport access.
    ///   - transport: performs the GET. It must pin its connection to
    ///     the approved addresses (``OAuthRemoteTransport/pinsConnectionsToApprovedPeers``)
    ///     unless `policy` sets ``OAuthRemoteFetchPolicy/allowsUnpinnedTransport``;
    ///     otherwise every fetch fails before any network access.
    public init(
        policy: OAuthRemoteFetchPolicy,
        resolver: any OAuthHostnameResolving = SystemOAuthHostnameResolver(),
        transport: any OAuthRemoteTransport
    ) {
        self.policy = policy
        self.resolver = resolver
        self.transport = transport
    }

    /// Fetches a JSON document: HTTPS, public addresses only, no redirects, exact status 200, a JSON content type, well-formed JSON without duplicate members, within the size and time limits.
    public func fetchJSON(from url: URL) async throws -> Data {
        try Task.checkCancellation()
        return try await fetchJSONWithoutAdmission(from: url)
    }

    /// Fetches a document without requiring a JSON content type. Every other
    /// rule (HTTPS, public addresses, no redirects, exact 200, size and time
    /// bounds) still applies.
    public func fetchBytes(from url: URL) async throws -> Data {
        try Task.checkCancellation()
        return try await fetchBytesWithoutAdmission(from: url)
    }

    /// The complete network-and-policy core shared by `fetchJSON` and
    /// `fetchBytes`: URL policy was already checked by the caller before
    /// admission; this performs DNS preflight, the transport GET, DNS
    /// postflight, the exact-URL/no-redirect/200 check, the dual-answer-set
    /// peer proof, header canonicalization, the content-length cross-check,
    /// and the body-size cap. It deliberately does not interpret the body —
    /// content-type and payload-syntax checks are the caller's job, because
    /// they differ between a JSON document and a binary payload like a CAR.
    fileprivate func fetchValidatedResponse(from url: URL) async throws
        -> (body: Data, headers: [String: [String]])
    {
        guard transport.pinsConnectionsToApprovedPeers || policy.allowsUnpinnedTransport else {
            throw OAuthServerError.unavailable(
                "OAuth remote transport does not pin connections to the approved addresses; "
                    + "use a pinning transport or set OAuthRemoteFetchPolicy.allowsUnpinnedTransport"
            )
        }
        let host = try policy.validateURL(url)
        let preflightPeers = Set(try await resolveOAuthHostname(
            resolver, host: host, timeout: policy.timeout
        ))
        try policy.validateResolved(Array(preflightPeers), host: host)
        let response: OAuthRemoteHTTPResponse
        do {
            response = try await transport.get(
                url: url,
                approvedPeers: preflightPeers,
                timeout: policy.timeout,
                maximumBodyBytes: policy.maximumBodyBytes
            )
        } catch let error as OAuthServerError {
            throw error
        } catch {
            throw OAuthServerError.unavailable("OAuth remote fetch failed")
        }
        // Resolve again after the request, then require the observed socket
        // peer to be in *both* answer sets. A transport without a peer proof
        // is not a valid remote-document transport.
        let postflightPeers = Set(try await resolveOAuthHostname(
            resolver, host: host, timeout: policy.timeout
        ))
        try policy.validateResolved(Array(postflightPeers), host: host)
        guard response.redirectCount == 0,
              response.responseURL.absoluteString == url.absoluteString,
              response.status == 200 else {
            throw OAuthServerError.unauthorized("OAuth remote document did not return exact HTTP 200")
        }
        if let peer = response.connectedPeerAddress {
            guard preflightPeers.contains(peer),
                  postflightPeers.contains(peer),
                  policy.permits(peer, forHost: host)
            else {
                throw OAuthServerError.unauthorized("OAuth remote peer was not in both approved DNS answer sets")
            }
        } else if policy.requiresConnectedPeerProof {
            throw OAuthServerError.unauthorized("OAuth remote transport did not prove its connected peer")
        }
        let headers = response.headers.reduce(into: [String: [String]]()) { output, item in
            output[item.key.lowercased(), default: []].append(contentsOf: item.value)
        }
        if let lengths = headers["content-length"] {
            guard lengths.count == 1, let declared = strictDecimal(lengths[0]),
                  declared <= policy.maximumBodyBytes, declared == response.body.count else {
                throw OAuthServerError.unauthorized("OAuth remote document content length is invalid")
            }
        }
        guard !response.body.isEmpty, response.body.count <= policy.maximumBodyBytes else {
            throw OAuthServerError.unauthorized("OAuth remote document body is out of bounds")
        }
        return (response.body, headers)
    }

    fileprivate func fetchJSONWithoutAdmission(from url: URL) async throws
        -> Data
    {
        let (body, headers) = try await fetchValidatedResponse(from: url)
        guard let contentType = headers["content-type"], contentType.count == 1,
              isJSONContentType(contentType[0]) else {
            throw OAuthServerError.unauthorized("OAuth remote document has non-JSON content type")
        }
        // The duplicate-member scanner also verifies complete JSON syntax. Keep
        // the bytes unmodified so metadata/JWKS decoders see exactly what was
        // validated and any caller can bind an audit hash if needed.
        do {
            try StrictJSON.validate(body)
        } catch {
            throw OAuthServerError.malformed("OAuth remote document is not valid JSON")
        }
        return body
    }

    /// Bytes path for binary payloads (e.g. a CAR file). Shares every network
    /// control with `fetchJSONWithoutAdmission` through `fetchValidatedResponse`
    /// and intentionally skips the JSON-only checks — content-type-is-JSON and
    /// `StrictJSON.validate` — which do not apply to a non-JSON body.
    fileprivate func fetchBytesWithoutAdmission(from url: URL) async throws
        -> Data
    {
        try await fetchValidatedResponse(from: url).body
    }

    /// `application/json` or any RFC 6839 `+json` structured-syntax suffix.
    ///
    /// The suffix declares that the payload is JSON, and the protection was
    /// never the media-type string: the bytes are validated as JSON either
    /// way, and the caller's decoder decides what they may mean.
    private func isJSONContentType(_ value: String) -> Bool {
        // Keep empty pieces: an empty or ";"-only value must be refused, and
        // splitting it with empty pieces omitted yields no first element.
        let mediaType = (value.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if mediaType == "application/json" { return true }
        guard mediaType.hasSuffix("+json"), mediaType.utf8.count <= 127,
              let slash = mediaType.firstIndex(of: "/"),
              slash != mediaType.startIndex else {
            return false
        }
        let subtype = mediaType[mediaType.index(after: slash)...]
        return subtype.count > "+json".count
            && !subtype.contains("/")
            && mediaType.utf8.allSatisfy({ $0 > 0x20 && $0 < 0x7F })
    }

    private func strictDecimal(_ value: String) -> Int? {
        guard !value.isEmpty, value.utf8.allSatisfy({ (48 ... 57).contains($0) }) else { return nil }
        return Int(value)
    }
}

/// A bounded POST transport for service-to-service control-plane traffic.
/// This is separate from `OAuthRemoteTransport` so existing metadata fetch
/// fakes cannot accidentally gain a request-body capability.
