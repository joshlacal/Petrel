import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Bluesky application helpers layered on top of the generated lexicon API.
///
/// `BskyAgent` is the Swift counterpart of the `app.bsky` conveniences on the
/// TypeScript `Agent`: posting, replying and quoting, likes, reposts, follows,
/// blocks and mutes, profile updates, parsed preferences with read-modify-write
/// setters, and labeler configuration. It is a lightweight `Sendable` value;
/// obtain one from ``ATProtoClient/bsky``.
///
/// ```swift
/// let post = try await client.bsky.post("Hello from Petrel")
/// try await client.bsky.like(post)
/// ```
///
/// Record writes go to the signed-in account's repository on its PDS.
/// `app.bsky.*` reads are proxied to the configured AppView, exactly as the
/// generated methods do.
public struct BskyAgent: Sendable {
    /// The DID of the Bluesky moderation service (`moderation.bsky.app`).
    ///
    /// It is the default "app labeler": its labels are requested with the
    /// `redact` flag on every helper request, as the official client does.
    public static let bskyLabelerDID: DID = {
        // The literal is a syntactically valid DID, so construction cannot fail.
        try! DID(didString: "did:plc:ar7c4by46qjdydhdevvrndac")
    }()

    /// The network service every helper request is sent through.
    public let networkService: NetworkService

    /// Labelers whose labels are always requested, with takedown (`redact`)
    /// capability. Defaults to the Bluesky moderation service.
    public var appLabelers: [DID]

    private let identity: Identity

    private enum Identity: Sendable {
        case client(ATProtoClient)
        case fixed(DID)
        case anonymous
    }

    /// Creates an agent that acts as the account signed in to `client`.
    public init(client: ATProtoClient, appLabelers: [DID] = [BskyAgent.bskyLabelerDID]) {
        networkService = client.networkService
        identity = .client(client)
        self.appLabelers = appLabelers
    }

    /// Creates an agent over a bare network service.
    ///
    /// Use this when authentication is handled outside ``ATProtoClient`` (for
    /// example a server-side service that injects its own
    /// ``AuthenticationProvider``).
    ///
    /// - Parameters:
    ///   - networkService: The service requests are sent through.
    ///   - did: The account the agent writes records as, or `nil` for a
    ///     read-only agent.
    ///   - appLabelers: Labelers always requested with the `redact` flag.
    public init(
        networkService: NetworkService,
        did: DID?,
        appLabelers: [DID] = [BskyAgent.bskyLabelerDID]
    ) {
        self.networkService = networkService
        identity = did.map(Identity.fixed) ?? .anonymous
        self.appLabelers = appLabelers
    }

    /// The DID of the account this agent acts as.
    ///
    /// - Throws: ``BskyAgentError/notAuthenticated`` when there is no signed-in account.
    public func did() async throws -> DID {
        switch identity {
        case let .fixed(did):
            return did
        case .anonymous:
            throw BskyAgentError.notAuthenticated
        case let .client(client):
            let (didString, _, _) = await client.getActiveAccountInfo()
            guard let didString else {
                throw BskyAgentError.notAuthenticated
            }
            do {
                return try DID(didString: didString)
            } catch {
                throw BskyAgentError.invalidResponse(
                    nsid: "session",
                    reason: "The active account DID is not a valid DID"
                )
            }
        }
    }

    /// The lock that serializes preference read-modify-write cycles for every
    /// agent sharing this agent's network service.
    var preferencesLock: BskyAsyncLock {
        BskyAsyncLockRegistry.shared.lock(for: networkService)
    }
}

public extension ATProtoClient {
    /// Bluesky application helpers for this client: posting, social graph
    /// verbs, preferences and labeler configuration.
    nonisolated var bsky: BskyAgent {
        BskyAgent(client: self)
    }
}

// MARK: - Errors

/// Errors thrown by the Bluesky helpers.
public enum BskyAgentError: Error, Sendable, Equatable, CustomStringConvertible {
    /// The operation needs a signed-in account and there is none.
    case notAuthenticated

    /// The server answered an XRPC call with an error status.
    ///
    /// - Parameters:
    ///   - nsid: The lexicon method that failed.
    ///   - status: The HTTP status code.
    ///   - error: The XRPC error name from the response body, when present.
    ///   - message: The human-readable message from the response body, when present.
    case xrpc(nsid: String, status: Int, error: String?, message: String?)

    /// The server answered successfully but the body could not be understood.
    case invalidResponse(nsid: String, reason: String)

    /// An argument passed to a helper is not acceptable (the message says why).
    case invalidInput(String)

    /// A compare-and-swap write kept losing to concurrent writers.
    case swapRetriesExhausted(attempts: Int)

    /// The video service could not process an uploaded video.
    case videoProcessingFailed(jobId: String, error: String?, message: String?)

    /// The video service did not finish processing an uploaded video in time.
    case videoProcessingTimedOut(jobId: String)

    public var description: String {
        switch self {
        case .notAuthenticated:
            return "Not signed in"
        case let .xrpc(nsid, status, error, message):
            let detail = [error, message].compactMap { $0 }.joined(separator: ": ")
            return "\(nsid) failed with HTTP \(status)" + (detail.isEmpty ? "" : " (\(detail))")
        case let .invalidResponse(nsid, reason):
            return "\(nsid) returned an unusable response: \(reason)"
        case let .invalidInput(reason):
            return "Invalid input: \(reason)"
        case let .swapRetriesExhausted(attempts):
            return "Record changed concurrently on each of \(attempts) attempts"
        case let .videoProcessingFailed(jobId, error, message):
            let detail = [error, message].compactMap { $0 }.joined(separator: ": ")
            return "Video job \(jobId) failed" + (detail.isEmpty ? "" : " (\(detail))")
        case let .videoProcessingTimedOut(jobId):
            return "Video job \(jobId) did not finish in time"
        }
    }

    /// The XRPC error name, when this is a server error that carried one.
    public var xrpcErrorName: String? {
        if case let .xrpc(_, _, error, _) = self { return error }
        return nil
    }
}

// MARK: - Per-call options

/// A service a single request should be proxied to through the PDS
/// (the `atproto-proxy` header).
///
/// Proxying is chosen per call. Nothing is written to the client's shared
/// headers, so concurrent calls to different services cannot interfere.
public struct ServiceProxy: Sendable, Hashable, CustomStringConvertible {
    /// The DID of the service.
    public let did: DID
    /// The service identifier inside the service's DID document, without the `#`.
    public let serviceID: String

    /// Creates a proxy target.
    /// - Parameters:
    ///   - did: The DID of the service.
    ///   - serviceID: The DID-document service identifier, without the `#`.
    /// - Throws: ``BskyAgentError/invalidInput(_:)`` when `serviceID` is not a
    ///   plain fragment identifier.
    public init(did: DID, serviceID: String) throws {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        guard !serviceID.isEmpty, serviceID.unicodeScalars.allSatisfy(allowed.contains) else {
            throw BskyAgentError.invalidInput("Service identifier must be a plain fragment such as bsky_chat")
        }
        self.did = did
        self.serviceID = serviceID
    }

    private init(unchecked did: DID, serviceID: String) {
        self.did = did
        self.serviceID = serviceID
    }

    /// The Bluesky chat service (`did:web:api.bsky.chat#bsky_chat`).
    public static let bskyChat: ServiceProxy = {
        ServiceProxy(unchecked: try! DID(didString: "did:web:api.bsky.chat"), serviceID: "bsky_chat")
    }()

    /// The Bluesky AppView (`did:web:api.bsky.app#bsky_appview`).
    public static let bskyAppView: ServiceProxy = {
        ServiceProxy(unchecked: try! DID(didString: "did:web:api.bsky.app"), serviceID: "bsky_appview")
    }()

    /// A chat service other than Bluesky's.
    public static func chat(_ did: DID) -> ServiceProxy {
        ServiceProxy(unchecked: did, serviceID: "bsky_chat")
    }

    /// A labeler's moderation service (`#atproto_labeler`), the target for reports.
    public static func labeler(_ did: DID) -> ServiceProxy {
        ServiceProxy(unchecked: did, serviceID: "atproto_labeler")
    }

    /// The `atproto-proxy` header value, `<did>#<serviceID>`.
    public var headerValue: String {
        "\(did.didString())#\(serviceID)"
    }

    public var description: String {
        headerValue
    }
}

/// Options that apply to one helper request only.
public struct BskyCallOptions: Sendable {
    /// Proxy this request to a specific service instead of the default for its namespace.
    public var proxy: ServiceProxy?

    /// Replace the labelers requested for this request. `nil` keeps the
    /// client's configured labelers; an empty array asks for no labels.
    public var acceptLabelers: [AcceptedLabeler]?

    /// Extra HTTP headers for this request.
    public var headers: [String: String]

    /// Creates per-call options.
    public init(
        proxy: ServiceProxy? = nil,
        acceptLabelers: [AcceptedLabeler]? = nil,
        headers: [String: String] = [:]
    ) {
        self.proxy = proxy
        self.acceptLabelers = acceptLabelers
        self.headers = headers
    }
}

// MARK: - XRPC core

/// The raw outcome of a successful helper request.
struct BskyXRPCResponse: Sendable {
    let status: Int
    let data: Data
    let headers: [String: String]

    func json(nsid: String) throws -> BskyJSON {
        do {
            return try BskyJSON.parse(data)
        } catch {
            throw BskyAgentError.invalidResponse(nsid: nsid, reason: "Body is not JSON")
        }
    }

    func decode<T: Decodable>(_ type: T.Type, nsid: String) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw BskyAgentError.invalidResponse(nsid: nsid, reason: "Body does not match the lexicon output")
        }
    }

    /// The error an unsuccessful response stands for.
    func error(nsid: String) -> BskyAgentError {
        let payload = try? BskyJSON.parse(data)
        return .xrpc(
            nsid: nsid,
            status: status,
            error: payload?["error"]?.stringValue,
            message: payload?["message"]?.stringValue
        )
    }

    /// Labelers the server reports having applied (`atproto-content-labelers`).
    var contentLabelers: [AcceptedLabeler] {
        guard let value = headers.first(where: { $0.key.lowercased() == "atproto-content-labelers" })?.value else {
            return []
        }
        return AcceptedLabeler.parseHeader(value)
    }
}

extension BskyAgent {
    /// Sends one XRPC request and returns the body of a 2xx response.
    ///
    /// Every helper goes through here so that proxying and labeler selection
    /// are decided per request and server errors surface as
    /// ``BskyAgentError/xrpc(nsid:status:error:message:)``.
    func xrpc(
        _ method: String,
        _ nsid: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        contentType: String = "application/json",
        options: BskyCallOptions = BskyCallOptions(),
        service: URL? = nil
    ) async throws -> BskyXRPCResponse {
        let response = try await xrpcAnyStatus(
            method, nsid, query: query, body: body, contentType: contentType, options: options, service: service
        )
        guard (200 ... 299).contains(response.status) else {
            throw response.error(nsid: nsid)
        }
        return response
    }

    /// Sends one XRPC request and returns the response whatever its status.
    ///
    /// - Parameter service: Send the request to this service directly instead
    ///   of to the PDS. No `atproto-proxy` header is added in that case.
    func xrpcAnyStatus(
        _ method: String,
        _ nsid: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        contentType: String = "application/json",
        options: BskyCallOptions = BskyCallOptions(),
        service: URL? = nil
    ) async throws -> BskyXRPCResponse {
        var requestHeaders = ["Accept": "application/json"]
        if body != nil {
            requestHeaders["Content-Type"] = contentType
        }

        let request = try await networkService.createURLRequest(
            endpoint: service.map { $0.appendingPathComponent("xrpc").appendingPathComponent(nsid).absoluteString } ?? nsid,
            method: method,
            headers: requestHeaders,
            body: body,
            queryItems: query.isEmpty ? nil : query
        )

        var perCall = options.headers
        if let proxy = options.proxy {
            perCall["atproto-proxy"] = proxy.headerValue
        } else if service == nil, let serviceDID = await networkService.getServiceDID(for: nsid) {
            perCall["atproto-proxy"] = serviceDID
        }
        if let labelers = options.acceptLabelers {
            perCall["atproto-accept-labelers"] = AcceptedLabeler.headerValue(for: labelers)
        }

        let (data, response) = try await networkService.performRequestReturningHTTPErrorResponses(
            request,
            skipTokenRefresh: false,
            additionalHeaders: perCall.isEmpty ? nil : perCall
        )

        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key] = value
            }
        }
        return BskyXRPCResponse(status: response.statusCode, data: data, headers: headers)
    }

    /// Sends a JSON procedure call.
    func xrpcProcedure(
        _ nsid: String,
        body: BskyJSON?,
        options: BskyCallOptions = BskyCallOptions()
    ) async throws -> BskyXRPCResponse {
        try await xrpc("POST", nsid, body: body?.serialized(), options: options)
    }

    /// Sends a query call.
    func xrpcQuery(
        _ nsid: String,
        query: [URLQueryItem] = [],
        options: BskyCallOptions = BskyCallOptions(),
        service: URL? = nil
    ) async throws -> BskyXRPCResponse {
        try await xrpc("GET", nsid, query: query, options: options, service: service)
    }
}
