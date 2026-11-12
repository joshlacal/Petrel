import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

// MARK: - Per-call options

/// A labeler a request asks the service to apply, sent in `atproto-accept-labelers`.
public struct XRPCLabeler: Sendable, Equatable, Hashable {
    /// The labeler's DID.
    public let did: String
    /// Whether the service should redact content this labeler takes down.
    public let redact: Bool

    /// Creates a labeler preference.
    public init(did: String, redact: Bool = false) {
        self.did = did
        self.redact = redact
    }

    /// The header value for a list of labelers: `did:plc:a;redact, did:plc:b`.
    public static func headerValue(for labelers: [XRPCLabeler]) -> String {
        labelers.map { $0.redact ? "\($0.did);redact" : $0.did }.joined(separator: ", ")
    }

    /// Parses an `atproto-accept-labelers` or `atproto-content-labelers` header value.
    public static func parse(headerValue: String) -> [XRPCLabeler] {
        headerValue.split(separator: ",").compactMap { entry in
            let parts = entry.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let did = parts.first, !did.isEmpty else { return nil }
            return XRPCLabeler(did: did, redact: parts.dropFirst().contains("redact"))
        }
    }
}

/// Options that apply to one XRPC call instead of to the whole client.
///
/// Pass them to the untyped calls (``NetworkService/xrpcQuery(_:parameters:options:)``),
/// or wrap any generated call in ``NetworkService/withCallOptions(_:operation:)``:
///
/// ```swift
/// let options = XRPCCallOptions(
///     proxy: "did:web:api.example.com#my_appview",
///     acceptLabelers: [XRPCLabeler(did: "did:plc:ar7c4by46qjdydhdevvrndac", redact: true)]
/// )
/// let (_, timeline) = try await NetworkService.withCallOptions(options) {
///     try await client.app.bsky.feed.getTimeline(input: .init())
/// }
/// ```
public struct XRPCCallOptions: Sendable, Equatable {
    /// Extra request headers. They override the client-wide headers of the same name.
    public var headers: [String: String]
    /// The service to proxy the call to through the PDS, as a DID service reference
    /// (`did:web:api.example.com#my_appview`), sent as `atproto-proxy`. `nil` keeps the
    /// client's routing for the endpoint's namespace.
    public var proxy: String?
    /// Labelers for this call, sent as `atproto-accept-labelers`. `nil` keeps the
    /// client-wide header.
    public var acceptLabelers: [XRPCLabeler]?
    /// Send the call to this service (its `/xrpc/<nsid>` endpoint) instead of the client's
    /// base URL. Credentials are attached only where the client's security policy allows
    /// them for that origin.
    public var service: URL?

    /// Creates call options.
    public init(
        headers: [String: String] = [:],
        proxy: String? = nil,
        acceptLabelers: [XRPCLabeler]? = nil,
        service: URL? = nil
    ) {
        self.headers = headers
        self.proxy = proxy
        self.acceptLabelers = acceptLabelers
        self.service = service
    }

    /// The headers these options put on a request, layered over `base`.
    func requestHeaders(over base: [String: String]?) -> [String: String]? {
        // Header names are case-insensitive, so each layer replaces any earlier
        // spelling of the same name instead of sitting next to it.
        var merged = base ?? [:]
        for name in headers.keys.sorted() {
            merged.setHTTPHeader(name, headers[name])
        }
        if let proxy {
            merged.setHTTPHeader("atproto-proxy", proxy)
        }
        if let acceptLabelers {
            merged.setHTTPHeader("atproto-accept-labelers", XRPCLabeler.headerValue(for: acceptLabelers))
        }
        return merged.isEmpty ? base : merged
    }
}

// MARK: - Response metadata

/// What a service said about a response besides its body.
public struct XRPCResponseMetadata: Sendable, Equatable {
    /// The HTTP status code.
    public let statusCode: Int
    /// The response headers, keyed by lowercased header name.
    public let headers: [String: String]

    /// Creates response metadata.
    public init(statusCode: Int, headers: [String: String]) {
        self.statusCode = statusCode
        self.headers = headers
    }

    /// The rate-limit state from the `ratelimit-*` headers, when the service sent them.
    public var rateLimit: XRPCRateLimit? {
        XRPCRateLimit(headers: headers)
    }

    /// The labelers whose labels the service applied (`atproto-content-labelers`).
    public var contentLabelers: [XRPCLabeler] {
        headers["atproto-content-labelers"].map(XRPCLabeler.parse(headerValue:)) ?? []
    }

    /// The repository revision the service had indexed when it answered (`atproto-repo-rev`).
    public var repoRev: String? {
        headers["atproto-repo-rev"]
    }
}

/// Collects the metadata of the last response seen inside a
/// ``NetworkService/withResponseMetadata(_:)`` scope.
// @unchecked Sendable: all mutable state is read and written only under `lock`.
final class XRPCResponseMetadataCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var latest: XRPCResponseMetadata?

    func record(_ response: HTTPURLResponse) {
        let metadata = XRPCResponseMetadata(
            statusCode: response.statusCode,
            headers: ATProtoErrorParser.headerFields(of: response)
        )
        lock.withLock { latest = metadata }
    }

    var metadata: XRPCResponseMetadata? {
        lock.withLock { latest }
    }
}

// MARK: - Untyped calls

/// The body of an untyped XRPC procedure call.
public enum XRPCBody: Sendable, Equatable {
    /// JSON bytes, sent as `application/json`.
    case json(Data)
    /// Arbitrary bytes with their MIME type, sent untouched.
    case bytes(Data, contentType: String)

    /// A JSON body encoded from any `Encodable` value, for example an
    /// ``ATProtocolValueContainer``, a generated Lexicon type, or a dictionary.
    public static func json(encoding value: some Encodable) throws -> XRPCBody {
        try .json(JSONEncoder().encode(value))
    }

    var data: Data {
        switch self {
        case let .json(data), let .bytes(data, _): data
        }
    }

    var contentType: String {
        switch self {
        case .json: "application/json"
        case let .bytes(_, contentType): contentType
        }
    }
}

/// The response of an untyped XRPC call. Only 2xx responses are returned; anything else is
/// thrown as ``ATProtoXRPCError``.
public struct XRPCResponse: Sendable, Equatable {
    /// The HTTP status code and response headers.
    public let metadata: XRPCResponseMetadata
    /// The response body, exactly as received.
    public let body: Data

    /// Creates a response value.
    public init(metadata: XRPCResponseMetadata, body: Data) {
        self.metadata = metadata
        self.body = body
    }

    /// The HTTP status code.
    public var statusCode: Int { metadata.statusCode }

    /// The response headers, keyed by lowercased header name.
    public var headers: [String: String] { metadata.headers }

    /// The body as untyped atproto data. Objects whose `$type` names a generated (or
    /// registered) Lexicon type decode as that type.
    public func json() throws -> ATProtocolValueContainer {
        try decode(ATProtocolValueContainer.self)
    }

    /// The body decoded as `type`.
    public func decode<T: Decodable>(_ type: T.Type = T.self, using decoder: JSONDecoder = JSONDecoder()) throws -> T {
        try decoder.decode(type, from: body)
    }
}

public extension NetworkService {
    /// Runs `operation` with `options` applied to every XRPC request it sends through a
    /// `NetworkService`: generated calls, untyped calls and raw `performRequest` calls alike.
    /// Generated subscriptions take them too: `service` is the host the WebSocket connects
    /// to, `proxy` routes the subscription through the PDS, and headers and labelers are
    /// sent on the upgrade request.
    ///
    /// The options apply to this task and its child tasks until `operation` returns.
    static func withCallOptions<T: Sendable>(
        _ options: XRPCCallOptions,
        operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        try await $scopedCallOptions.withValue(options) {
            try await operation()
        }
    }

    /// Runs `operation` and returns, next to its result, the status code and headers of the
    /// last response a `NetworkService` received inside it.
    ///
    /// Generated calls return the decoded body only; this is how to read what else the
    /// service said — rate-limit state, `atproto-content-labelers`, `atproto-repo-rev`:
    ///
    /// ```swift
    /// let (result, metadata) = try await NetworkService.withResponseMetadata {
    ///     try await client.app.bsky.feed.getTimeline(input: .init())
    /// }
    /// let remaining = metadata?.rateLimit?.remaining
    /// ```
    ///
    /// When the call throws, the same information is on the thrown ``ATProtoXRPCError``.
    static func withResponseMetadata<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async rethrows -> (value: T, metadata: XRPCResponseMetadata?) {
        let collector = XRPCResponseMetadataCollector()
        let value = try await $responseMetadataCollector.withValue(collector) {
            try await operation()
        }
        return (value, collector.metadata)
    }

    /// Calls a query (HTTP GET) by NSID, without a generated type.
    ///
    /// Authentication, DPoP, token refresh, retries and the client's service routing apply
    /// exactly as for generated calls.
    ///
    /// ```swift
    /// let response = try await client.networkService.xrpcQuery(
    ///     "com.example.widget.getThing",
    ///     parameters: [URLQueryItem(name: "id", value: "3jwdwj2ctlk26")]
    /// )
    /// let thing = try response.json()
    /// ```
    ///
    /// - Parameters:
    ///   - nsid: The NSID of the query.
    ///   - parameters: The query parameters. Repeat a name for an array parameter.
    ///   - options: Headers, proxying, labelers and service for this call.
    /// - Throws: ``ATProtoXRPCError`` for a non-2xx response, `ATProtocolError` for an
    ///   invalid NSID, `NetworkError` for transport failures.
    func xrpcQuery(
        _ nsid: String,
        parameters: [URLQueryItem] = [],
        options: XRPCCallOptions = XRPCCallOptions()
    ) async throws -> XRPCResponse {
        try await xrpcCall(nsid, method: "GET", parameters: parameters, body: nil, options: options)
    }

    /// Calls a procedure (HTTP POST) by NSID, without a generated type.
    ///
    /// ```swift
    /// let response = try await client.networkService.xrpcProcedure(
    ///     "com.example.widget.createThing",
    ///     body: .json(encoding: ["name": "left"])
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - nsid: The NSID of the procedure.
    ///   - parameters: The query parameters, for procedures that declare any.
    ///   - body: The request body: JSON, or bytes with their MIME type. `nil` sends none.
    ///   - options: Headers, proxying, labelers and service for this call.
    /// - Throws: ``ATProtoXRPCError`` for a non-2xx response, `ATProtocolError` for an
    ///   invalid NSID, `NetworkError` for transport failures.
    func xrpcProcedure(
        _ nsid: String,
        parameters: [URLQueryItem] = [],
        body: XRPCBody? = nil,
        options: XRPCCallOptions = XRPCCallOptions()
    ) async throws -> XRPCResponse {
        try await xrpcCall(nsid, method: "POST", parameters: parameters, body: body, options: options)
    }

    private func xrpcCall(
        _ nsid: String,
        method: String,
        parameters: [URLQueryItem],
        body: XRPCBody?,
        options: XRPCCallOptions
    ) async throws -> XRPCResponse {
        // Reject anything that is not an NSID before it becomes part of a URL path.
        let endpoint = try NSID(nsidString: nsid).description

        var headers: [String: String] = [:]
        if let body {
            headers["Content-Type"] = body.contentType
        }

        // An explicit options argument wins over an enclosing withCallOptions scope.
        var effective = Self.scopedCallOptions ?? XRPCCallOptions()
        for name in options.headers.keys.sorted() {
            effective.headers.setHTTPHeader(name, options.headers[name])
        }
        // The explicit options win over the scope as a whole. A header the explicit options
        // set by hand (atproto-proxy, atproto-accept-labelers) displaces the scope's typed
        // option for the same header, which would otherwise be written over it.
        if options.proxy == nil, options.headers.hasHTTPHeader("atproto-proxy") {
            effective.proxy = nil
        }
        if options.acceptLabelers == nil, options.headers.hasHTTPHeader("atproto-accept-labelers") {
            effective.acceptLabelers = nil
        }
        effective.proxy = options.proxy ?? effective.proxy
        effective.acceptLabelers = options.acceptLabelers ?? effective.acceptLabelers
        effective.service = options.service ?? effective.service
        // A caller's own atproto-proxy header, in any spelling, is routing too;
        // default routing must not replace it.
        if effective.proxy == nil, !effective.headers.hasHTTPHeader("atproto-proxy") {
            effective.proxy = await getServiceDID(for: endpoint)
        }

        return try await Self.$scopedCallOptions.withValue(effective) {
            let request = try await self.createURLRequest(
                endpoint: endpoint,
                method: method,
                headers: headers,
                body: body?.data,
                queryItems: parameters.isEmpty ? nil : parameters
            )
            let (data, response) = try await self.performRequestReturningHTTPErrorResponses(
                request,
                skipTokenRefresh: false,
                additionalHeaders: nil
            )
            guard (200 ... 299).contains(response.statusCode) else {
                throw ATProtoErrorParser.xrpcError(data: data, response: response)
            }
            return XRPCResponse(
                metadata: XRPCResponseMetadata(
                    statusCode: response.statusCode,
                    headers: ATProtoErrorParser.headerFields(of: response)
                ),
                body: data
            )
        }
    }
}

extension Dictionary where Key == String, Value == String {
    /// Whether a header with this name is present, ignoring case.
    func hasHTTPHeader(_ name: String) -> Bool {
        keys.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Sets a header, first removing every entry whose name matches ignoring case,
    /// so the dictionary never holds two spellings of one header.
    mutating func setHTTPHeader(_ name: String, _ value: String?) {
        let matching = keys.filter { $0.caseInsensitiveCompare(name) == .orderedSame }
        for key in matching {
            removeValue(forKey: key)
        }
        if let value {
            self[name] = value
        }
    }
}
