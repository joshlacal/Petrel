//
//  NetworkService.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/22/2025.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
#if canImport(Network)
    import Network
#endif
#if canImport(Compression)
    import Compression
#endif

public enum RequestSecurityPolicy: Sendable, Equatable {
    case unauthenticated
    case authenticated(recipient: ExactAuthRequestOrigin)
}

public struct NetworkResponseLimits: Sendable, Equatable {
    public let maximumWireBytes: Int
    public let maximumDecodedBytes: Int
    public let maximumExpansionRatio: Int
    public let maximumDiagnosticBytes: Int

    public init(
        maximumWireBytes: Int = 10 * 1024 * 1024,
        maximumDecodedBytes: Int = 10 * 1024 * 1024,
        maximumExpansionRatio: Int = 20,
        maximumDiagnosticBytes: Int = 8 * 1024
    ) {
        self.maximumWireBytes = maximumWireBytes
        self.maximumDecodedBytes = maximumDecodedBytes
        self.maximumExpansionRatio = maximumExpansionRatio
        self.maximumDiagnosticBytes = maximumDiagnosticBytes
    }

    public static let `default` = NetworkResponseLimits()
}

public protocol WebSocketTaskProtocol: Sendable {
    func resume()
    func receive() async throws -> URLSessionWebSocketTask.Message
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
}

extension URLSessionWebSocketTask: WebSocketTaskProtocol {}

/// Response body decoding and decompression.
/// HardenedURLSessionDelegate receives raw wire data chunks for wire-byte accounting,
/// and response decoding is handled centrally in executeDataTask via ContentDecoding.normalizeResponse.
enum ContentDecoding {
    static func headerValue(named name: String, in headerFields: [AnyHashable: Any]) -> String? {
        for (key, value) in headerFields {
            if let keyString = key as? String,
               keyString.caseInsensitiveCompare(name) == .orderedSame,
               let valueString = value as? String
            {
                return valueString
            }
        }
        return nil
    }

    /// Normalize response bytes exactly once. URLSession may already decode a body while retaining
    /// its header, so only attempt a codec when the payload is framed (or is not recognizable text).
    static func decompressIfNeeded(_ data: Data, contentEncoding: String?, limits: NetworkResponseLimits = .default) throws -> Data {
        guard data.count <= limits.maximumWireBytes else {
            throw NetworkError.responseLimitExceeded("Wire bytes exceeded limit")
        }
        let encoding = contentEncoding?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !encoding.isEmpty && encoding != "identity" else {
            guard data.count <= limits.maximumDecodedBytes else {
                throw NetworkError.responseLimitExceeded("Decoded bytes exceeded limit")
            }
            return data
        }

        let looksUnencoded = data.first == 0x7B || data.first == 0x5B || data.first == 0x22
            || data.first == 0x20 || data.first == 0x09 || data.first == 0x0A || data.first == 0x0D
        let framed = encoding == "gzip" ? data.starts(with: [0x1F, 0x8B]) : !looksUnencoded
        guard framed else {
            guard data.count <= limits.maximumDecodedBytes else {
                throw NetworkError.responseLimitExceeded("Decoded bytes exceeded limit")
            }
            return data
        }

        let decoded: Data?
        switch encoding {
        case "gzip": decoded = try decompressGzip(data, limits: limits)
        case "deflate": decoded = try decompressDeflate(data, limits: limits)
        case "br": decoded = try decompressBrotli(data, limits: limits)
        default:
            throw NetworkError.invalidResponse(description: "Unsupported Content-Encoding: \(encoding)")
        }
        guard let decoded else {
            throw NetworkError.invalidResponse(description: "Invalid \(encoding) response")
        }
        guard decoded.count <= limits.maximumDecodedBytes,
              data.isEmpty || Double(decoded.count) / Double(data.count) <= Double(limits.maximumExpansionRatio)
        else {
            throw NetworkError.responseLimitExceeded("Decoded response exceeds limits")
        }
        return decoded
    }

    static func normalizeResponse(_ data: Data, response: URLResponse, limits: NetworkResponseLimits) throws -> Data {
        let encoding = (response as? HTTPURLResponse).flatMap {
            headerValue(named: "Content-Encoding", in: $0.allHeaderFields)
        }
        return try decompressIfNeeded(data, contentEncoding: encoding, limits: limits)
    }


    #if canImport(Compression)
    private static func decompressAlgorithm(_ data: Data, algorithm: compression_algorithm, limits: NetworkResponseLimits) throws -> Data? {
        guard !data.isEmpty else { return data }
        let maxAllowedDecoded = min(limits.maximumDecodedBytes, data.count * limits.maximumExpansionRatio)
        var outputSize = min(max(data.count * 4, 65536), maxAllowedDecoded)
        var outputData = Data(count: outputSize)

        for _ in 0 ..< 6 {
            let result = data.withUnsafeBytes { sourceBuffer -> Int in
                guard let sourcePtr = sourceBuffer.baseAddress else { return 0 }
                return outputData.withUnsafeMutableBytes { destBuffer -> Int in
                    guard let destPtr = destBuffer.baseAddress else { return 0 }
                    return compression_decode_buffer(
                        destPtr.assumingMemoryBound(to: UInt8.self),
                        outputSize,
                        sourcePtr.assumingMemoryBound(to: UInt8.self),
                        data.count,
                        nil,
                        algorithm
                    )
                }
            }

            if result > 0, result < outputSize {
                outputData.count = result
                if outputData.count > limits.maximumDecodedBytes {
                    throw NetworkError.responseLimitExceeded("Decoded bytes (\(outputData.count)) exceeded limit (\(limits.maximumDecodedBytes))")
                }
                if data.count > 0 && (Double(outputData.count) / Double(data.count) > Double(limits.maximumExpansionRatio)) {
                    throw NetworkError.responseLimitExceeded("Decompression expansion ratio (\(outputData.count)/\(data.count)) exceeded limit (\(limits.maximumExpansionRatio)x)")
                }
                return outputData
            } else if result == outputSize {
                let nextSize = outputSize * 2
                if nextSize > maxAllowedDecoded {
                    throw NetworkError.responseLimitExceeded("Decoded bytes exceeded limit during decompression")
                }
                outputSize = nextSize
                outputData = Data(count: outputSize)
            } else {
                break
            }
        }
        return nil
    }

    private static func decompressBrotli(_ data: Data, limits: NetworkResponseLimits) throws -> Data? {
        try decompressAlgorithm(data, algorithm: COMPRESSION_BROTLI, limits: limits)
    }

    private static func decompressZlib(_ data: Data, limits: NetworkResponseLimits) throws -> Data? {
        try decompressAlgorithm(data, algorithm: COMPRESSION_ZLIB, limits: limits)
    }
    private static func decompressDeflate(_ data: Data, limits: NetworkResponseLimits) throws -> Data? {
        if let raw = try decompressAlgorithm(data, algorithm: COMPRESSION_ZLIB, limits: limits) { return raw }
        guard data.count > 6 else { return nil }
        return try decompressAlgorithm(Data(data.dropFirst(2).dropLast(4)), algorithm: COMPRESSION_ZLIB, limits: limits)
    }

    private static func decompressGzip(_ data: Data, limits: NetworkResponseLimits) throws -> Data? {
        guard data.count >= 18, data[0] == 0x1f, data[1] == 0x8b, data[2] == 8 else { return nil }
        var index = 10
        let flags = data[3]
        if flags & 4 != 0 {
            guard index + 2 <= data.count else { return nil }
            let length = Int(data[index]) | Int(data[index + 1]) << 8
            index += 2 + length
        }
        if flags & 8 != 0 { while index < data.count && data[index] != 0 { index += 1 }; index += 1 }
        if flags & 16 != 0 { while index < data.count && data[index] != 0 { index += 1 }; index += 1 }
        if flags & 2 != 0 { index += 2 }
        guard index < data.count - 8 else { return nil }
        return try decompressAlgorithm(Data(data[index ..< data.count - 8]), algorithm: COMPRESSION_ZLIB, limits: limits)
    }
    #else
    private static func decompressBrotli(_ data: Data, limits: NetworkResponseLimits) throws -> Data? {
        nil
    }

    private static func decompressZlib(_ data: Data, limits: NetworkResponseLimits) throws -> Data? {
        nil
    }
    #endif
}

/// Allows client apps to control connection routing (e.g., bypassing proxy for WebSockets)
public protocol ConnectionPolicyAdapter: Sendable {
    /// Resolves the actual URL to connect to
    /// - Parameters:
    ///   - url: The original target URL
    ///   - endpoint: The API endpoint being called (e.g., "com.atproto.sync.subscribeRepos")
    /// - Returns: The URL to actually connect to (may be same, or modified to bypass proxy)
    func resolveConnectionURL(_ url: URL, endpoint: String?) async -> URL
}

/// An internal lease representing exclusive access to authentication lifecycle state while a request is in flight.
public final class AuthenticationRequestLease: @unchecked Sendable {
    private let onRelease: (@Sendable () -> Void)?
    private let lock = NSLock()
    private var isReleased = false

    init(onRelease: @escaping @Sendable () -> Void) {
        self.onRelease = onRelease
    }

    public func release() {
        let shouldNotify: Bool = lock.withLock {
            if !isReleased {
                isReleased = true
                return true
            }
            return false
        }
        if shouldNotify {
            onRelease?()
        }
    }

    deinit {
        release()
    }
}

/// Protocol for authentication providers
public struct AuthContext: Sendable {
    let did: String?
    let jkt: String?
    let lease: AuthenticationRequestLease?

    init(did: String?, jkt: String?, lease: AuthenticationRequestLease? = nil) {
        self.did = did
        self.jkt = jkt
        self.lease = lease
    }

    func releaseAuthenticationLease() {
        lease?.release()
    }
}
/// An internal container carrying a prepared streaming URLRequest and its authentication lifecycle lease.
public struct PreparedStreamingRequest: Sendable {
    public let request: URLRequest
    let authContext: AuthContext?

    init(request: URLRequest, authContext: AuthContext? = nil) {
        self.request = request
        self.authContext = authContext
    }

    public func releaseAuthenticationLease() {
        authContext?.releaseAuthenticationLease()
    }
}


public protocol AuthenticationProvider: Sendable {
    /// Prepares a request with authentication headers
    /// - Parameter request: The original request
    /// - Returns: The authenticated request
    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest

    /// Prepares a request with authentication headers and returns auth context (DID + DPoP JKT)
    /// - Parameter request: The original request
    /// - Returns: The authenticated request and its associated auth context
    func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (URLRequest, AuthContext)

    /// Refreshes the authentication token if needed
    /// - Returns: A boolean indicating whether refresh was needed
    func refreshTokenIfNeeded() async throws -> TokenRefreshResult

    /// Handles a 401 unauthorized response
    /// - Parameters:
    ///   - response: The unauthorized response
    ///   - data: The response data
    ///   - request: The original request
    /// - Returns: A tuple with new data and response after handling
    func handleUnauthorizedResponse(_ response: HTTPURLResponse, data: Data, for request: URLRequest)
        async throws -> (Data, HTTPURLResponse)

    /// Updates the DPoP nonce for a URL, optionally scoped to a specific DID and DPoP key thumbprint (JKT)
    /// - Parameters:
    ///   - url: The URL to update the nonce for
    ///   - headers: The headers containing the nonce
    ///   - did: Optional DID that was used to authenticate the request
    ///   - jkt: Optional JWK thumbprint (key id) for DPoP key used to sign the request
    func updateDPoPNonce(for url: URL, from headers: [String: String], did: String?, jkt: String?) async
}

/// Protocol defining the interface for network services.
protocol NetworkServiceProtocol: Sendable {
    /// Performs a network request with the provided URLRequest.
    /// - Parameter request: The URLRequest to perform.
    /// - Parameter skipTokenRefresh: Whether to skip token refresh (to avoid circular dependencies).
    /// - Parameter additionalHeaders: Optional additional headers to include with this specific request.
    /// - Returns: A tuple containing the response data and URLResponse.
    func request(_ request: URLRequest, skipTokenRefresh: Bool, additionalHeaders: [String: String]?) async throws -> (Data, URLResponse)

    /// Performs a GET request to the specified endpoint.
    /// - Parameters:
    ///   - endpoint: The API endpoint path.
    ///   - queryItems: Optional query parameters.
    ///   - requiresAuth: Whether the request requires authentication.
    ///   - additionalHeaders: Optional additional headers to include with this specific request.
    /// - Returns: The decoded response data.
    func get<T: Decodable & Sendable>(
        endpoint: String,
        queryItems: [URLQueryItem]?,
        requiresAuth: Bool,
        additionalHeaders: [String: String]?
    ) async throws -> T

    /// Performs a POST request to the specified endpoint.
    /// - Parameters:
    ///   - endpoint: The API endpoint path.
    ///   - body: The request body to send.
    ///   - requiresAuth: Whether the request requires authentication.
    ///   - additionalHeaders: Optional additional headers to include with this specific request.
    /// - Returns: The decoded response data.
    func post<T: Decodable & Sendable, B: Encodable & Sendable>(
        endpoint: String,
        body: B?,
        requiresAuth: Bool,
        additionalHeaders: [String: String]?
    ) async throws -> T

    /// Sets the base URL for API requests.
    /// - Parameter url: The new base URL.
    func setBaseURL(_ url: URL) async

    /// Sets a custom header for all requests.
    /// - Parameters:
    ///   - name: The header name.
    ///   - value: The header value.
    func setHeader(name: String, value: String) async

    /// Gets the value of a custom header
    /// - Parameter name: Header name
    /// - Returns: Header value if it exists
    func getHeader(name: String) async -> String?

    /// Removes a custom header
    /// - Parameter name: Header name to remove
    func removeHeader(name: String) async

    /// Clears all custom headers
    func clearHeaders() async

    /// Sets the User-Agent header
    /// - Parameter userAgent: The user agent string
    func setUserAgent(_ userAgent: String) async

    /// Sets the atproto-proxy header for directing requests to specific services
    /// - Parameters:
    ///   - did: The DID of the target service
    ///   - service: The service identifier
    func setProxyHeader(did: String, service: String) async

    /// Sets the atproto-accept-labelers header with proper formatting
    /// - Parameter labelers: Array of tuples containing labeler DIDs and redaction flags
    func setAcceptLabelers(_ labelers: [(did: String, redact: Bool)]) async

    /// Extracts the content labelers from a response header
    /// - Parameter response: The HTTP response
    /// - Returns: Array of tuples containing labeler DIDs and redaction flags
    func extractContentLabelers(from response: HTTPURLResponse) async -> [(did: String, redact: Bool)]

    /// Sets the service DID for a given lexicon namespace prefix
    /// - Parameters:
    ///   - serviceDID: The service DID (e.g., "did:web:api.bsky.app#bsky_appview")
    ///   - namespace: The lexicon namespace prefix (e.g., "app.bsky", "chat.bsky")
    func setServiceDID(_ serviceDID: String, for namespace: String) async

    /// Gets the service DID for a given endpoint, if configured
    /// - Parameter endpoint: The full endpoint (e.g., "app.bsky.feed.getTimeline")
    /// - Returns: The service DID if one is configured for this endpoint's namespace, nil otherwise
    func getServiceDID(for endpoint: String) async -> String?

    /// Sets the authentication provider for authenticated requests
    /// - Parameter provider: The authentication provider
    func setAuthenticationProvider(_ provider: any AuthenticationProvider) async

    /// Sets the connection policy adapter for controlling connection routing
    /// - Parameter adapter: The connection policy adapter
    func setConnectionPolicyAdapter(_ adapter: (any ConnectionPolicyAdapter)?) async

    /// Creates a URLRequest with the specified parameters (compatibility method)
    /// - Parameters:
    ///   - endpoint: The API endpoint path.
    ///   - method: The HTTP method (GET, POST, etc.).
    ///   - headers: Additional HTTP headers.
    ///   - body: The HTTP body data.
    ///   - queryItems: Optional query parameters.
    /// - Returns: The configured URLRequest.
    func createURLRequest(
        endpoint: String,
        method: String,
        headers: [String: String],
        body: Data?,
        queryItems: [URLQueryItem]?
    ) async throws -> URLRequest

    /// Performs a network request (compatibility method)
    /// - Parameters:
    ///   - request: The URLRequest to perform.
    ///   - skipTokenRefresh: Whether to skip token refresh.
    /// - Returns: A tuple containing the response data and HTTPURLResponse.
    func performRequest(_ request: URLRequest, skipTokenRefresh: Bool) async throws -> (
        Data, HTTPURLResponse
    )

    /// Performs a network request (compatibility method)
    /// - Parameter request: The URLRequest to perform.
    /// - Returns: A tuple containing the response data and HTTPURLResponse.
    func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)

    /// Subscribe to a WebSocket event stream
    /// - Parameters:
    ///   - endpoint: The subscription endpoint
    ///   - parameters: Optional query parameters
    /// - Returns: An async throwing stream of decoded messages
    func subscribe<Message: Codable & Sendable>(
        endpoint: String,
        parameters: (any Parametrizable)?
    ) async throws -> AsyncThrowingStream<Message, Error>
}

/// Class responsible for handling network operations.
public actor NetworkService: NetworkServiceProtocol {
    // MARK: - Properties

    public private(set) var baseURL: URL
    public let limits: NetworkResponseLimits
    private var authProvider: AuthenticationProvider?
    private var headers: [String: String] = [:]
    nonisolated package let sessionDelegate: HardenedURLSessionDelegate
    nonisolated package let exactAuthSessionDelegate: HardenedURLSessionDelegate
    nonisolated package let session: URLSession
    private let exactAuthSession: URLSession
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    private let maxRetries = 3
    private var userAgent: String?
    private(set) var protectedResourceMetadata: ProtectedResourceMetadata?
    private(set) var authorizationServerMetadata: AuthorizationServerMetadata?
    private let requestDeduplicator = RequestDeduplicator()
    private static let dnsResolutionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.joshlacalamito.Petrel.DNSResolution"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 6
        return queue
    }()
    #if DEBUG
        package nonisolated(unsafe) static var dnsResolutionHook: (@Sendable (String, @Sendable () -> Bool) -> Void)?
        package nonisolated(unsafe) static var dnsResolverOverride: (@Sendable (String) -> [String]?)?
        package nonisolated(unsafe) static var webSocketTaskOverride: (@Sendable (URLRequest) -> any WebSocketTaskProtocol)?
    #endif
    private var authContinuityRevision: UInt64 = 0
    private var authContinuityRevisionExhausted = false
    private var authContinuityObserverProviderID: ObjectIdentifier?
    private var authContinuityObserverInstallation: (
        providerID: ObjectIdentifier,
        revision: UInt64,
        task: Task<Void, Never>
    )?
    nonisolated let exactAuthRequestScopeServiceID = UUID()
    private var activeExactAuthRequestScope: ExactAuthGeneratedRequestScope?
    private var exactAuthDestinationGeneration = UUID()

    private struct HTTPErrorResponseRequestIdentity: Equatable {
        let networkService: ObjectIdentifier
        let method: String
        let url: String?

        init(networkService: NetworkService, request: URLRequest) {
            self.networkService = ObjectIdentifier(networkService)
            method = request.httpMethod ?? "GET"
            url = request.url?.absoluteString
        }
    }

    /// Scoped by `performRequestReturningHTTPErrorResponses` so an awaited auth
    /// retry on the same service, with the same method and URL, uses the same
    /// terminal-status policy without changing the authentication-provider
    /// contract. Other services and auth subrequests keep strict status
    /// handling. Detached work intentionally does not inherit this
    /// request-scoped behavior.
    @TaskLocal private static var terminalHTTPErrorResponseRequest:
        HTTPErrorResponseRequestIdentity? = nil

    #if DEBUG
        private nonisolated(unsafe) static var networkTestProtocolClasses: [AnyClass]?
        private static let networkTestProtocolClassesLock = NSLock()

        static func setNetworkTestProtocolClasses(_ classes: [AnyClass]?) {
            networkTestProtocolClassesLock.withLock {
                networkTestProtocolClasses = classes
            }
        }
    #endif

    /// When true, all xrpc requests require auth and go through the gateway
    /// Gateway handles OAuth/DPoP - client just sends Bearer token
    private(set) var gatewayMode: Bool = false

    /// Maps lexicon namespace prefixes to their service DIDs
    /// Example: "app.bsky" -> "did:web:api.bsky.app#bsky_appview"
    ///          "chat.bsky" -> "did:web:api.bsky.chat#bsky_chat"
    private var serviceDIDMapping: [String: String] = [:]

    /// Optional adapter for controlling connection routing (e.g., bypassing proxy for WebSockets)
    private var connectionPolicyAdapter: (any ConnectionPolicyAdapter)?

    /// Retrieves authentication continuity without exposing provider secrets.
    func authContinuitySnapshot() async -> AuthContinuitySnapshot? {
        while true {
            let revision = authContinuityRevision
            guard let provider = authProvider as? any AuthContinuityProviding else {
                return nil
            }

            guard await installAuthContinuityObserverIfNeeded(for: provider, at: revision) else {
                continue
            }

            let providerSnapshot = await provider.authContinuityProviderSnapshot()
            guard isCurrentAuthContinuityProvider(provider, at: revision) else {
                continue
            }

            if case let .mutationPending(mode) = providerSnapshot {
                return AuthContinuitySnapshot(did: nil, mode: mode, generation: .max)
            }
            guard case let .stable(snapshot) = providerSnapshot else {
                return nil
            }

            if authContinuityRevisionExhausted {
                return AuthContinuitySnapshot(did: nil, mode: snapshot.mode, generation: .max)
            }
            // NetworkService owns the public continuity clock so provider
            // replacement and provider-internal mutations share one monotonic,
            // collision-free generation domain.
            return AuthContinuitySnapshot(
                did: snapshot.did,
                mode: snapshot.mode,
                generation: revision
            )
        }
    }

    func performWithExactAuthContinuity<Value: Sendable>(
        matching expected: AuthContinuitySnapshot,
        _ operation: @Sendable () -> Value
    ) async -> AuthContinuityTransactionResult<Value> {
        while true {
            let revision = authContinuityRevision
            guard let provider = authProvider as? any AuthContinuityProviding else {
                return .continuityChanged
            }
            guard await installAuthContinuityObserverIfNeeded(for: provider, at: revision) else {
                continue
            }

            let providerState = await provider.authContinuityProviderSnapshot()
            guard isCurrentAuthContinuityProvider(provider, at: revision) else {
                continue
            }
            guard case let .stable(providerSnapshot) = providerState else {
                return .continuityChanged
            }
            guard !authContinuityRevisionExhausted else {
                return .continuityChanged
            }
            let current = AuthContinuitySnapshot(
                did: providerSnapshot.did,
                mode: providerSnapshot.mode,
                generation: revision
            )
            guard current == expected else {
                return .continuityChanged
            }

            // Deliberately synchronous: actor isolation is the continuity lease.
            return .performed(operation())
        }
    }

    func beginExactAuthGeneratedRequestScope(
        id: UUID,
        expected: AuthContinuitySnapshot,
        state: ExactAuthGeneratedRequestScopeState
    ) async -> ExactAuthGeneratedRequestScope? {
        guard activeExactAuthRequestScope == nil,
              let origin = ExactAuthRequestOrigin(baseURL)
        else {
            state.failContinuity()
            return nil
        }
        let destinationGeneration = exactAuthDestinationGeneration
        guard await exactAuthSnapshot(matching: expected) != nil,
              activeExactAuthRequestScope == nil,
              ExactAuthRequestOrigin(baseURL) == origin,
              exactAuthDestinationGeneration == destinationGeneration
        else {
            state.failContinuity()
            return nil
        }
        let scope = ExactAuthGeneratedRequestScope(
            id: id,
            expected: expected,
            networkServiceID: exactAuthRequestScopeServiceID,
            origin: origin,
            destinationGeneration: destinationGeneration,
            state: state
        )
        activeExactAuthRequestScope = scope
        return scope
    }

    func endExactAuthGeneratedRequestScope(_ scope: ExactAuthGeneratedRequestScope) {
        guard activeExactAuthRequestScope?.id == scope.id else { return }
        activeExactAuthRequestScope = nil
    }

    func isExactAuthGeneratedRequestScopeActive(_ scope: ExactAuthGeneratedRequestScope) -> Bool {
        isActiveExactAuthRequestScope(scope)
    }

    private func installAuthContinuityObserverIfNeeded(
        for provider: any AuthContinuityProviding,
        at revision: UInt64
    ) async -> Bool {
        let providerID = ObjectIdentifier(provider)
        if authContinuityObserverProviderID == providerID {
            return isCurrentAuthContinuityProvider(provider, at: revision)
        }

        let installationTask: Task<Void, Never>
        if let installation = authContinuityObserverInstallation,
           installation.providerID == providerID,
           installation.revision == revision
        {
            installationTask = installation.task
        } else {
            let observer: @Sendable () async -> Void = { [weak self] in
                await self?.markAuthContinuityMutation()
            }
            installationTask = Task {
                await provider.installAuthContinuityObserver(observer)
            }
            authContinuityObserverInstallation = (providerID, revision, installationTask)
        }
        await installationTask.value

        guard isCurrentAuthContinuityProvider(provider, at: revision) else {
            clearAuthContinuityObserverInstallation(providerID: providerID, revision: revision)
            return false
        }
        authContinuityObserverProviderID = providerID
        clearAuthContinuityObserverInstallation(providerID: providerID, revision: revision)
        return true
    }

    private func clearAuthContinuityObserverInstallation(
        providerID: ObjectIdentifier,
        revision: UInt64
    ) {
        guard authContinuityObserverInstallation?.providerID == providerID,
              authContinuityObserverInstallation?.revision == revision
        else {
            return
        }
        authContinuityObserverInstallation = nil
    }

    private func isCurrentAuthContinuityProvider(
        _ provider: any AuthContinuityProviding,
        at revision: UInt64
    ) -> Bool {
        guard authContinuityRevision == revision,
              let currentProvider = authProvider as? any AuthContinuityProviding
        else {
            return false
        }
        return currentProvider === provider
    }

    private func exactAuthProvider(
        matching expected: AuthContinuitySnapshot
    ) async -> (provider: any AuthContinuityProviding, revision: UInt64)? {
        let revision = authContinuityRevision
        guard let provider = authProvider as? any AuthContinuityProviding,
              await installAuthContinuityObserverIfNeeded(for: provider, at: revision),
              await exactAuthSnapshot(
                  for: provider,
                  at: revision,
                  matching: expected
              )
        else {
            return nil
        }
        return (provider, revision)
    }

    private func exactAuthSnapshot(
        matching expected: AuthContinuitySnapshot
    ) async -> AuthContinuitySnapshot? {
        guard await exactAuthProvider(matching: expected) != nil else { return nil }
        return expected
    }

    private func exactAuthSnapshot(
        for provider: any AuthContinuityProviding,
        at revision: UInt64,
        matching expected: AuthContinuitySnapshot
    ) async -> Bool {
        guard !authContinuityRevisionExhausted,
              isCurrentAuthContinuityProvider(provider, at: revision)
        else {
            return false
        }
        let providerState = await provider.authContinuityProviderSnapshot()
        guard isCurrentAuthContinuityProvider(provider, at: revision),
              case let .stable(providerSnapshot) = providerState
        else {
            return false
        }
        return AuthContinuitySnapshot(
            did: providerSnapshot.did,
            mode: providerSnapshot.mode,
            generation: revision
        ) == expected
    }

    private func markAuthContinuityMutation() {
        guard !authContinuityRevisionExhausted else { return }
        guard authContinuityRevision < .max - 1 else {
            authContinuityRevision = .max
            authContinuityRevisionExhausted = true
            return
        }
        authContinuityRevision += 1
    }

    #if DEBUG
        func setAuthContinuityRevisionForTesting(_ revision: UInt64) {
            authContinuityRevision = revision
            authContinuityRevisionExhausted = revision == .max
        }
    #endif

    /// Endpoints that go directly to PDS and should never be proxied
    private let neverProxyEndpoints: Set<String> = [
        "app.bsky.actor.getPreferences",
        "app.bsky.actor.putPreferences",
    ]

    // MARK: - Initialization

    /// Initializes a new NetworkService with the specified base URL and authentication service.
    /// - Parameters:
    ///   - baseURL: The base URL for API requests.
    ///   - authService: The authentication service to use for authenticated requests.
    ///   - limits: Network response limits for wire/decoded bytes and expansion ratios.
    public init(baseURL: URL, authService: AuthenticationProvider? = nil, limits: NetworkResponseLimits = .default) {
        self.baseURL = baseURL
        self.authProvider = authService
        self.limits = limits

        // Configure URL session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120.0
        config.timeoutIntervalForResource = 604_800 // 1 week
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpShouldSetCookies = false

        // Add standard headers
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "X-Requested-With": "XMLHttpRequest",
        ]

        config.httpMaximumConnectionsPerHost = 5
        #if DEBUG
            config.protocolClasses = Self.networkTestProtocolClassesLock.withLock {
                Self.networkTestProtocolClasses
            }
        #endif

        // Create a session with a delegate for enhanced security
        let sessionDelegate = HardenedURLSessionDelegate(allowsRedirects: true, limits: limits)
        self.sessionDelegate = sessionDelegate
        session = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
        let exactConfig = URLSessionConfiguration.ephemeral
        exactConfig.timeoutIntervalForRequest = config.timeoutIntervalForRequest
        exactConfig.timeoutIntervalForResource = config.timeoutIntervalForResource
        exactConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        exactConfig.httpShouldSetCookies = false
        exactConfig.httpCookieStorage = nil
        exactConfig.urlCredentialStorage = nil
        exactConfig.urlCache = nil
        exactConfig.httpMaximumConnectionsPerHost = 1
        #if DEBUG
            exactConfig.protocolClasses = Self.networkTestProtocolClassesLock.withLock {
                Self.networkTestProtocolClasses
            }
        #endif
        let exactAuthDelegate = HardenedURLSessionDelegate(allowsRedirects: false, limits: limits)
        self.exactAuthSessionDelegate = exactAuthDelegate
        exactAuthSession = URLSession(
            configuration: exactConfig,
            delegate: exactAuthDelegate,
            delegateQueue: nil
        )

        LogManager.logDebug("Network Service initialized")
    }

    // MARK: - NetworkServiceProtocol Methods

    func setProtectedResourceMetadata(_ metadata: ProtectedResourceMetadata) {
        protectedResourceMetadata = metadata
        LogManager.logInfo("Network Service - Protected Resource Metadata updated")
    }

    func setAuthorizationServerMetadata(_ metadata: AuthorizationServerMetadata) {
        authorizationServerMetadata = metadata
        LogManager.logInfo("Network Service - Authorization Server Metadata updated")
    }

    /// Sets the base URL for API requests.
    /// - Parameter url: The new base URL.
    public func setBaseURL(_ url: URL) async {
        exactAuthDestinationGeneration = UUID()
        baseURL = url
        LogManager.logInfo("Network Service - Base URL updated to: \(LogManager.sanitizeURLForLogging(url))")
    }
    public func setGatewayMode(_ enabled: Bool) async {
        gatewayMode = enabled
        LogManager.logInfo("🔍 [GATEWAY DEBUG] setGatewayMode called with: \(enabled)")
    }

    /// Sets a custom header for all requests.
    /// - Parameters:
    ///   - name: The header name.
    ///   - value: The header value.
    public func setHeader(name: String, value: String) async {
        LogManager.logSensitiveValue(value, label: "Network Service - Setting header: \(name)", category: .network)
        headers[name] = value
    }

    /// Gets the value of a custom header
    /// - Parameter name: Header name
    /// - Returns: Header value if it exists
    func getHeader(name: String) async -> String? {
        return headers[name]
    }

    /// Removes a custom header
    /// - Parameter name: Header name to remove
    public func removeHeader(name: String) async {
        LogManager.logDebug("Network Service - Removing header: \(name)")
        headers.removeValue(forKey: name)
    }

    /// Clears all custom headers
    func clearHeaders() async {
        LogManager.logDebug("Network Service - Clearing all custom headers")
        headers.removeAll()
    }

    /// Sets the User-Agent header
    /// - Parameter userAgent: The user agent string
    public func setUserAgent(_ userAgent: String) async {
        self.userAgent = userAgent
        await setHeader(name: "User-Agent", value: userAgent)
    }

    /// Sets the atproto-proxy header for directing requests to specific services
    /// - Parameters:
    ///   - did: The DID of the target service
    ///   - service: The service identifier
    func setProxyHeader(did: String, service: String) async {
        await setHeader(name: "atproto-proxy", value: "\(did)#\(service)")
    }

    /// Sets the atproto-accept-labelers header with proper formatting
    /// - Parameter labelers: Array of tuples containing labeler DIDs and redaction flags
    func setAcceptLabelers(_ labelers: [(did: String, redact: Bool)]) async {
        // Format according to RFC-8941 structured syntax
        let headerValue = labelers.map { labeler -> String in
            if labeler.redact {
                return "\(labeler.did);redact"
            } else {
                return labeler.did
            }
        }.joined(separator: ", ")

        if !headerValue.isEmpty {
            await setHeader(name: "atproto-accept-labelers", value: headerValue)
        } else {
            // If empty, remove the header
            await removeHeader(name: "atproto-accept-labelers")
        }
    }

    /// Sets the service DID for a given lexicon namespace prefix
    /// - Parameters:
    ///   - serviceDID: The service DID (e.g., "did:web:api.bsky.app#bsky_appview")
    ///   - namespace: The lexicon namespace prefix (e.g., "app.bsky", "chat.bsky")
    public func setServiceDID(_ serviceDID: String, for namespace: String) async {
        serviceDIDMapping[namespace] = serviceDID
        LogManager.logInfo("Network Service - Set service DID '\(serviceDID)' for namespace '\(namespace)'")
        LogManager.logDebug("Network Service - Current service DID mappings: \(serviceDIDMapping)")
    }

    /// Gets the service DID for a given endpoint, if configured
    /// - Parameter endpoint: The full endpoint (e.g., "app.bsky.feed.getTimeline")
    /// - Returns: The service DID if one is configured for this endpoint's namespace, nil otherwise
    public func getServiceDID(for endpoint: String) async -> String? {
        // Special case: preferences endpoints go directly to PDS, never proxied
        if neverProxyEndpoints.contains(endpoint) {
            LogManager.logDebug("Network Service - getServiceDID for preferences endpoint '\(endpoint)': nil (PDS direct)")
            return nil
        }

        // Find the matching namespace prefix
        // Try longest match first (e.g., "chat.bsky" before "chat")
        let sortedPrefixes = serviceDIDMapping.keys.sorted { $0.count > $1.count }
        for prefix in sortedPrefixes {
            if endpoint.hasPrefix(prefix + ".") || endpoint == prefix {
                let did = serviceDIDMapping[prefix]
                LogManager.logDebug("Network Service - getServiceDID for '\(endpoint)' matched prefix '\(prefix)': \(did ?? "nil")")
                return did
            }
        }

        LogManager.logDebug("Network Service - getServiceDID for '\(endpoint)': No matching prefix found")
        return nil
    }

    /// Extracts the content labelers from a response header
    /// - Parameter response: The HTTP response
    /// - Returns: Array of tuples containing labeler DIDs and redaction flags
    nonisolated func extractContentLabelers(from response: HTTPURLResponse) async -> [(
        did: String, redact: Bool
    )] {
        guard let contentLabelers = response.allHeaderFields["atproto-content-labelers"] as? String
        else {
            return []
        }

        return parseLabelerHeader(contentLabelers)
    }

    /// Sets the authentication provider for authenticated requests
    /// - Parameter provider: The authentication provider
    public func setAuthenticationProvider(_ provider: AuthenticationProvider) async {
        await requestDeduplicator.cancelAllRequests()
        if let continuityProvider = provider as? any AuthContinuityProviding,
           let currentProvider = authProvider as? any AuthContinuityProviding,
           currentProvider === continuityProvider
        {
            let revision = authContinuityRevision
            _ = await installAuthContinuityObserverIfNeeded(for: continuityProvider, at: revision)
            return
        }

        markAuthContinuityMutation()
        authProvider = provider
        authContinuityObserverProviderID = nil
        if let continuityProvider = provider as? any AuthContinuityProviding {
            let revision = authContinuityRevision
            _ = await installAuthContinuityObserverIfNeeded(for: continuityProvider, at: revision)
        }
    }

    /// Sets the connection policy adapter for controlling connection routing
    /// - Parameter adapter: The connection policy adapter
    public func setConnectionPolicyAdapter(_ adapter: (any ConnectionPolicyAdapter)?) {
        exactAuthDestinationGeneration = UUID()
        connectionPolicyAdapter = adapter
        LogManager.logInfo("Network Service - Connection policy adapter \(adapter == nil ? "removed" : "set")")
    }

    enum EndpointType {
        case authorizationServer
        case protectedResource
        case other
    }

    func determineSecurityPolicy(for url: URL) -> RequestSecurityPolicy {
        guard let origin = ExactAuthRequestOrigin(url) else {
            // Non-HTTPS or invalid URL -> unauthenticated
            return .unauthenticated
        }

        // Public discovery endpoints are always unauthenticated
        let path = url.path
        if path.hasPrefix("/.well-known/") || path.hasPrefix("/oauth/") || url.host?.lowercased() == "plc.directory" {
            return .unauthenticated
        }

        // In gateway mode, xrpc requests targeting the authorized gateway origin require auth
        if gatewayMode {
            if path.contains("/xrpc/") {
                if let baseOrigin = ExactAuthRequestOrigin(baseURL), origin == baseOrigin {
                    return .authenticated(recipient: origin)
                }
            }
            return .unauthenticated
        }

        // Standard OAuth mode - check metadata match
        if let authServerMetadata = authorizationServerMetadata,
           let authServerURL = URL(string: authServerMetadata.issuer),
           let authOrigin = ExactAuthRequestOrigin(authServerURL),
           origin == authOrigin
        {
            if url.absoluteString == authServerMetadata.tokenEndpoint
                || url.absoluteString == authServerMetadata.authorizationEndpoint
                || url.absoluteString == authServerMetadata.pushedAuthorizationRequestEndpoint
            {
                return .unauthenticated
            } else {
                return .authenticated(recipient: origin)
            }
        } else if let protectedResourceMetadata = protectedResourceMetadata,
                  let resOrigin = ExactAuthRequestOrigin(protectedResourceMetadata.resource),
                  origin == resOrigin
        {
            return .authenticated(recipient: origin)
        } else if let baseOrigin = ExactAuthRequestOrigin(baseURL), origin == baseOrigin, path.contains("/xrpc/") {
            return .authenticated(recipient: origin)
        } else {
            return .unauthenticated
        }
    }

    func determineEndpointTypeAndAuthRequirement(for url: URL) -> (EndpointType, Bool) {
        let policy = determineSecurityPolicy(for: url)
        switch policy {
        case .unauthenticated:
            return (.other, false)
        case .authenticated:
            return (.protectedResource, true)
        }
    }

    func request(_ request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else {
            throw NetworkError.invalidURL
        }
        if !(try await validateURL(url)) {
            LogManager.logError("Security validation failed for URL: \(LogManager.sanitizeURLForLogging(url))")
            throw NetworkError.securityViolation
        }
        let policy = determineSecurityPolicy(for: url)
        var authCtx_simple: AuthContext? = nil
        defer {
            authCtx_simple?.releaseAuthenticationLease()
        }
        let (requestToSend, authedCtx) = try await attachCredentialsIfAuthorized(request, policy: policy)
        authCtx_simple = authedCtx
        // Perform the request using the internal session
        do {
            LogManager.logRequest(requestToSend)
            let (data, response) = try await executeDataTask(requestToSend, using: session, delegate: sessionDelegate)
            authCtx_simple?.releaseAuthenticationLease()

            if let httpResponse = response as? HTTPURLResponse {
                LogManager.logResponse(httpResponse, data: data)

                // Immediately capture and store DPoP-Nonce (case-insensitive) before any status handling
                if let authProvider = authProvider, let url = requestToSend.url {
                    var foundNonce: String? = nil
                    for (key, value) in httpResponse.allHeaderFields {
                        if let keyString = key as? String,
                           keyString.caseInsensitiveCompare("DPoP-Nonce") == .orderedSame
                        {
                            foundNonce = value as? String
                            break
                        }
                    }

                    if let nonce = foundNonce {
                        LogManager.logSensitiveValue(
                            nonce,
                            label: "Network Service (simple) - Storing nonce from status \(httpResponse.statusCode) for \(url.host ?? "N/A")",
                            category: .network
                        )
                        await authProvider.updateDPoPNonce(
                            for: url,
                            from: ["DPoP-Nonce": nonce],
                            did: authCtx_simple?.did,
                            jkt: authCtx_simple?.jkt
                        )
                    }
                }
            }
            // Basic check for HTTP errors, more detailed handling is in the other request method
            if let httpResponse = response as? HTTPURLResponse,
               !(200 ..< 300).contains(httpResponse.statusCode)
            {
                LogManager.logDebug(
                    "Request to \(LogManager.sanitizeURLForLogging(url)) failed with status code: \(httpResponse.statusCode)"
                )
            }
            return (data, response)
        } catch {
            if let netError = error as? NetworkError {
                throw netError
            }
            LogManager.logError("Network request failed for \(LogManager.sanitizeURLForLogging(url)): \(error)")
            throw NetworkError.requestFailed
        }
    }

    /// Performs a network request with the provided URLRequest.
    /// - Parameter request: The URLRequest to perform.
    /// - Parameter skipTokenRefresh: Whether to skip token refresh.
    /// - Parameter additionalHeaders: Optional additional headers to include with this specific request.
    /// - Returns: A tuple containing the response data and URLResponse.
    func request(_ request: URLRequest, skipTokenRefresh: Bool = false, additionalHeaders: [String: String]? = nil) async throws -> (
        Data, URLResponse
    ) {
        guard let requestURL = request.url else {
            throw NetworkError.invalidURL
        }
        // One final policy gate: validate URL before any send (including exact auth continuity)
        if !(try await validateURL(requestURL)) {
            LogManager.logError("Security validation failed for URL: \(LogManager.sanitizeURLForLogging(requestURL))")
            throw NetworkError.securityViolation
        }

        if let scope = ExactAuthGeneratedRequestScopeContext.current {
            return try await requestWithExactAuthContinuity(
                request,
                additionalHeaders: additionalHeaders,
                scope: scope
            )
        }
        if let activeExactAuthRequestScope {
            activeExactAuthRequestScope.state.failContinuity()
            throw ExactAuthGeneratedRequestContinuityError()
        }

        let currentRequest = request
        let returnsTerminalHTTPErrorResponses =
            Self.terminalHTTPErrorResponseRequest ==
            HTTPErrorResponseRequestIdentity(
                networkService: self,
                request: currentRequest
            )

        let policy = determineSecurityPolicy(for: requestURL)

        var retryCount = 0

        while retryCount < maxRetries {
            var requestToSend = currentRequest
            var authCtx: AuthContext? = nil
            defer {
                authCtx?.releaseAuthenticationLease()
            }

            let (authedRequest, authedCtx) = try await attachCredentialsIfAuthorized(
                requestToSend,
                policy: policy,
                skipTokenRefresh: skipTokenRefresh
            )
            requestToSend = authedRequest
            authCtx = authedCtx

            // Add custom headers
            for (name, value) in headers {
                requestToSend.setValue(value, forHTTPHeaderField: name)
            }

            // Add additional headers for this specific request
            if let additionalHeaders = additionalHeaders {
                for (name, value) in additionalHeaders {
                    // If we're not targeting the PDS host, do not attach atproto-proxy
                    if name.lowercased() == "atproto-proxy",
                       let h = requestToSend.url?.host,
                       h != baseURL.host
                    {
                        // Skip proxy header for direct-to-service requests
                        continue
                    }
                    requestToSend.setValue(value, forHTTPHeaderField: name)
                    if name == "atproto-proxy" {
                        LogManager.logInfo("Network Service - Setting atproto-proxy header: \(value) for endpoint: \(requestToSend.url?.path ?? "unknown")")
                    }
                }
            }
            if let userAgent = userAgent {
                requestToSend.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            }

            // Generate request ID for end-to-end correlation with BFF
            let requestId = UUID().uuidString
            requestToSend.setValue(requestId, forHTTPHeaderField: "X-Catbird-Request-Id")
            if let ua = userAgent {
                requestToSend.setValue(ua, forHTTPHeaderField: "X-Catbird-Client")
            }

            // Log structured request shape for BFF debugging
            let requestStartTime = Date()
            if let url = requestToSend.url {
                let bodySize = requestToSend.httpBody?.count ?? 0
                #if DEBUG
                    let bodyShape = requestToSend.httpBody.flatMap { LogManager.jsonShape(from: $0) }
                #else
                    let bodyShape: String? = nil
                #endif
                LogManager.logStructuredRequest(
                    requestId: requestId,
                    method: requestToSend.httpMethod ?? "GET",
                    url: url,
                    bodySize: bodySize,
                    bodyShape: bodyShape,
                    gatewayMode: gatewayMode
                )
            }

            // Perform the request with deduplication
            do {
                LogManager.logRequest(requestToSend)

                let request = requestToSend

                // Use deduplicator for non-refresh requests to prevent concurrent identical calls
                let authIdentity = authCtx?.did ?? request.value(forHTTPHeaderField: "Authorization")
                let (data, response) = if !skipTokenRefresh {
                    try await requestDeduplicator.deduplicate(request: request, authIdentity: authIdentity) { @Sendable in
                        return try await self.executeDataTask(request, using: self.session, delegate: self.sessionDelegate)
                    }
                } else {
                    // Skip deduplication for refresh requests to avoid circular dependencies
                    try await executeDataTask(requestToSend, using: session, delegate: sessionDelegate)
                }
                authCtx?.releaseAuthenticationLease()

                // Get data and ensure we have a valid HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    LogManager.logError(
                        "Network Service - Received non-HTTP response for \(requestToSend.url.map { LogManager.sanitizeURLForLogging($0) } ?? "Unknown URL")"
                    )
                    throw NetworkError.invalidResponse(description: "Received non-HTTP response")
                }
                // executeDataTask has already applied the shared response pipeline.
                let decompressedData = data
                // Log structured response shape for BFF debugging
                let elapsedMs = Int(Date().timeIntervalSince(requestStartTime) * 1000)
                #if DEBUG
                    let responseShape = LogManager.jsonShape(from: decompressedData)
                #else
                    let responseShape: String? = nil
                #endif
                LogManager.logStructuredResponse(
                    requestId: requestId,
                    status: httpResponse.statusCode,
                    elapsedMs: elapsedMs,
                    bodySize: decompressedData.count,
                    bodyShape: responseShape
                )

                // Log the response
                LogManager.logResponse(httpResponse, data: decompressedData) // *** STORE NONCE IMMEDIATELY AFTER RECEIVING RESPONSE ***
                // This ensures the nonce is stored *before* any retry logic based on status code.
                if let authProvider = authProvider, let url = requestToSend.url {
                    // Look for DPoP-Nonce header with case-insensitive matching
                    var foundNonce: String? = nil

                    // Iterate through headers and compare keys case-insensitively
                    for (key, value) in httpResponse.allHeaderFields {
                        if let keyString = key as? String, // Make sure key is a String
                           keyString.caseInsensitiveCompare("DPoP-Nonce") == .orderedSame
                        { // Case-insensitive compare
                            foundNonce = value as? String // Get the value if key matches
                            LogManager.logDebug("Network Service - Found nonce with header name: \(keyString)")
                            break // Stop searching once found
                        }
                    }

                    if let nonce = foundNonce {
                        LogManager.logSensitiveValue(
                            nonce,
                            label: "Network Service - Storing nonce from \(httpResponse.statusCode) response for \(url.host ?? "N/A")",
                            category: .network
                        )

                        // Create a header dictionary with the expected case for the key
                        let nonceHeaders = ["DPoP-Nonce": nonce]

                        // Pass the found nonce to the auth provider, scoping to DID and JKT
                        await authProvider.updateDPoPNonce(
                            for: url,
                            from: nonceHeaders,
                            did: authCtx?.did,
                            jkt: authCtx?.jkt
                        )

                        LogManager.logDebug(
                            "Network Service - Nonce storage complete for \(url.host ?? "N/A")", category: .network
                        )
                    } else {
                        LogManager.logDebug(
                            "Network Service - No DPoP-Nonce header found in \(httpResponse.statusCode) response."
                        )
                    }
                } else if skipTokenRefresh {
                    LogManager.logDebug("Network Service - Skipping automatic nonce update because skipTokenRefresh is true.")
                }

                // Handle response based on status code
                switch httpResponse.statusCode {
                case 200 ..< 300:
                    // Success - just return the data and response
                    return (decompressedData, httpResponse)

                case 401:
                    // Handle unauthorized (401)
                    guard let authProvider = authProvider, let url = requestToSend.url else {
                        LogManager.logError(
                            "Network Service - Received 401 but no auth provider or URL for \(requestToSend.url.map { LogManager.sanitizeURLForLogging($0) } ?? "Unknown URL")"
                        )
                        let autoLogoutDID = authCtx?.did ?? ""
                        // Broadcast auto-logout event so UI can redirect to reauth
                        Task {
                            await AuthEventBroadcaster.shared.broadcast(.autoLogoutTriggered(did: autoLogoutDID, reason: "401_no_auth_provider_or_url"))
                        }
                        throw NetworkError.authenticationRequired // Cannot handle 401 without provider/URL
                    }

                    LogManager.logInfo("Network Service - Received 401 for \(LogManager.sanitizeURLForLogging(url)). Analyzing response.")

                    // In gateway mode, don't try to handle DPoP nonce errors - gateway should handle them
                    // Just delegate to the auth provider's handleUnauthorizedResponse
                    if gatewayMode {
                        LogManager.logInfo("Network Service - Gateway mode: delegating 401 to auth provider")
                        do {
                            let (retryData, retryResponse) = try await authProvider.handleUnauthorizedResponse(
                                httpResponse, data: decompressedData, for: requestToSend
                            )
                            return (retryData, retryResponse)
                        } catch let gatewayError as ConfidentialGatewayStrategy.GatewayError {
                            LogManager.logError(
                                "Network Service - Gateway mode: auth provider returned gateway error: \(gatewayError)"
                            )

                            let reason: String? = {
                                switch gatewayError {
                                case .sessionExpired:
                                    return "gateway_session_expired"
                                case .invalidSession:
                                    return "gateway_invalid_session"
                                case .missingSession:
                                    return "gateway_missing_session"
                                case .authenticationRequired,
                                     .invalidCallbackURL,
                                     .invalidGatewayURL,
                                     .networkError,
                                     .upgradeTemporarilyUnavailable:
                                    return nil
                                }
                            }()

                            if let reason {
                                let autoLogoutDID = authCtx?.did ?? ""
                                Task {
                                    await AuthEventBroadcaster.shared.broadcast(.autoLogoutTriggered(did: autoLogoutDID, reason: reason))
                                }
                            }
                            throw NetworkError.authenticationRequired
                        } catch {
                            LogManager.logError("Network Service - Gateway mode: auth provider failed to handle 401: \(error)")
                            // Unknown gateway auth failure - still signal auto-logout as a fallback.
                            let autoLogoutDID = authCtx?.did ?? ""
                            Task {
                                await AuthEventBroadcaster.shared.broadcast(.autoLogoutTriggered(did: autoLogoutDID, reason: "gateway_401_unhandled_unknown"))
                            }
                            throw NetworkError.authenticationRequired
                        }
                    }

                    // Nonce was already stored above, before the switch statement.

                    // 2. Check if it's specifically a 'use_dpop_nonce' error
                    var isNonceError = false
                    // Attempt to decode the standard OAuth error response structure
                    // Need to define OAuthErrorResponse struct or import it if defined elsewhere
                    struct OAuthErrorResponse: Decodable {
                        let error: String
                        let errorDescription: String?
                        enum CodingKeys: String, CodingKey {
                            case error
                            case errorDescription = "error_description"
                        }
                    }

                    if let errorResponse = try? jsonDecoder.decode(OAuthErrorResponse.self, from: decompressedData),
                       errorResponse.error == "use_dpop_nonce"
                    {
                        isNonceError = true
                        LogManager.logInfo("Network Service - 401 error is 'use_dpop_nonce'.")
                    } else {
                        // Also check WWW-Authenticate header (though Bluesky uses response body)
                        let responseHeaders = httpResponse.allHeaderFields as? [String: String] ?? [:]
                        if let wwwAuth = responseHeaders["WWW-Authenticate"],
                           wwwAuth.lowercased().contains("error=\"use_dpop_nonce\"")
                        {
                            isNonceError = true
                            LogManager.logInfo(
                                "Network Service - 401 error is 'use_dpop_nonce' (found in WWW-Authenticate)."
                            )
                        } else {
                            LogManager.logInfo(
                                "Network Service - 401 error is NOT 'use_dpop_nonce'. Will attempt standard token refresh."
                            )
                        }
                    }

                    // 3. Handle based on error type
                    if isNonceError {
                        LogManager.logInfo("METRIC dpop_nonce_retry_total origin=protected_resource jkt=\(authCtx?.jkt ?? "unknown")")
                        // If it's a nonce error, make sure nonce is stored properly before retrying
                        let responseHeaders = httpResponse.allHeaderFields as? [String: String] ?? [:]
                        if let nonce = responseHeaders["DPoP-Nonce"] {
                            // Explicitly store the nonce again, to be double-sure
                            LogManager.logSensitiveValue(
                                nonce,
                                label: "Network Service - Re-storing nonce for domain \(url.host?.lowercased() ?? "unknown") before retry",
                                category: .network
                            )

                            // Store the nonce specifically for this retry, using DID/JKT captured for this request if present
                            await authProvider.updateDPoPNonce(
                                for: url,
                                from: responseHeaders,
                                did: authCtx?.did,
                                jkt: authCtx?.jkt
                            )

                            LogManager.logInfo(
                                "Network Service - Nonce storage completed, proceeding with retry."
                            )
                        }

                        // Limit nonce-based retry strictly to one attempt
                        if retryCount >= 1 {
                            LogManager.logError("Network Service - Already retried once for use_dpop_nonce; aborting further retries.")
                            throw NetworkError.maxRetryAttemptsReached
                        }
                        retryCount = 1
                        LogManager.logInfo(
                            "Network Service - Retrying request (\(retryCount)/\(maxRetries)) after storing DPoP nonce for \(LogManager.sanitizeURLForLogging(url))."
                        )

                        continue // Continue to the next iteration of the while loop
                    } else if !skipTokenRefresh {
                        // If it's NOT a nonce error, and we're allowed to refresh, attempt standard token refresh via handleUnauthorizedResponse
                        LogManager.logInfo(
                            "Network Service - Attempting standard token refresh/handling for 401 on \(LogManager.sanitizeURLForLogging(url))."
                        )
                        do {
                            // Use the authProvider's handler (which should attempt refresh)
                            let (retryData, retryResponse) = try await authProvider.handleUnauthorizedResponse(
                                httpResponse, data: decompressedData, for: requestToSend
                            )
                            LogManager.logInfo(
                                "Network Service - Successfully handled non-nonce 401 via authProvider."
                            )
                            return (retryData, retryResponse) // Return the result of the successful handling
                        } catch {
                            LogManager.logError(
                                "Network Service - authProvider failed to handle non-nonce 401: \(error). Giving up."
                            )
                            let autoLogoutDID = authCtx?.did ?? ""
                            // Broadcast auto-logout event so UI can redirect to reauth
                            Task {
                                await AuthEventBroadcaster.shared.broadcast(.autoLogoutTriggered(did: autoLogoutDID, reason: "401_token_refresh_failed"))
                            }
                            throw NetworkError.authenticationRequired // Throw if handling fails
                        }
                    } else {
                        // Is NOT a nonce error, but we are skipping token refresh (e.g., during refresh itself)
                        LogManager.logError("Network Service - Received non-nonce 401 but skipping refresh for \(LogManager.sanitizeURLForLogging(url)). Cannot proceed.")
                        let autoLogoutDID = authCtx?.did ?? ""
                        // Broadcast auto-logout event so UI can redirect to reauth
                        Task {
                            await AuthEventBroadcaster.shared.broadcast(.autoLogoutTriggered(did: autoLogoutDID, reason: "401_skip_refresh"))
                        }
                        throw NetworkError.authenticationRequired // Cannot handle this 401
                    }
                // Handle 400 responses - check for ExpiredToken error which needs token refresh
                case 400:
                    let maxDiag = NetworkResponseLimits.default.maximumDiagnosticBytes
                    let diagData = decompressedData.prefix(maxDiag)
                    let responseBody = String(data: diagData, encoding: .utf8) ?? "<binary data>"
                    let truncatedSuffix = decompressedData.count > maxDiag ? "... [truncated to \(maxDiag) bytes]" : ""
                    let redactedBody = (responseBody.count > 500 ? String(responseBody.prefix(500)) + "..." : responseBody) + truncatedSuffix
                    LogManager.logError(
                        "Network Service - 400 Bad Request for \(requestToSend.url.map { LogManager.sanitizeURLForLogging($0) } ?? "Unknown URL")"
                    )
                    LogManager.logError(
                        "Network Service - 400 Response body: \(redactedBody)"
                    )

                    // Check if this is an ExpiredToken error that needs refresh
                    if responseBody.contains("ExpiredToken"), let authProvider = authProvider, !skipTokenRefresh {
                        LogManager.logError(
                            "Network Service - 400 ExpiredToken detected, attempting token refresh for \(requestToSend.url.map { LogManager.sanitizeURLForLogging($0) } ?? "Unknown URL")"
                        )

                        // Attempt token refresh
                        do {
                            let refreshResult = try await authProvider.refreshTokenIfNeeded()
                            LogManager.logError(
                                "Network Service - Token refresh result after ExpiredToken: \(refreshResult)"
                            )

                            // Retry the request with the new token
                            retryCount += 1
                            if retryCount < maxRetries {
                                LogManager.logError(
                                    "Network Service - Retrying request after ExpiredToken refresh (attempt \(retryCount)/\(maxRetries))"
                                )
                                continue // Go to next iteration of the while loop
                            }
                        } catch {
                            LogManager.logError(
                                "Network Service - Token refresh failed after ExpiredToken: \(error)"
                            )
                        }
                    }

                    // Log request headers (redact auth)
                    if let headers = requestToSend.allHTTPHeaderFields {
                        let redactedHeaders = headers.mapValues { value -> String in
                            if value.lowercased().contains("bearer") || value.lowercased().contains("dpop") {
                                return "<REDACTED>"
                            }
                            return value
                        }
                        LogManager.logError(
                            "Network Service - 400 Request headers: \(redactedHeaders)"
                        )
                    }
                    return (decompressedData, httpResponse) // Return data and response for caller inspection

                case 402 ..< 500: // Other client errors
                    LogManager.logError(
                        "Network Service - Client error \(httpResponse.statusCode) for \(requestToSend.url.map { LogManager.sanitizeURLForLogging($0) } ?? "Unknown URL")"
                    )
                    if returnsTerminalHTTPErrorResponses {
                        return (decompressedData, httpResponse)
                    }
                    throw NetworkError.responseError(statusCode: httpResponse.statusCode)

                case 500 ..< 600:
                    // Server errors - may be worth retrying
                    LogManager.logError(
                        "Network Service - Server error \(httpResponse.statusCode) for \(requestToSend.url.map { LogManager.sanitizeURLForLogging($0) } ?? "Unknown URL"). Retry \(retryCount + 1)/\(maxRetries)."
                    )
                    retryCount += 1
                    if retryCount >= maxRetries {
                        if returnsTerminalHTTPErrorResponses {
                            return (decompressedData, httpResponse)
                        }
                        throw NetworkError.responseError(statusCode: httpResponse.statusCode)
                    }

                    // Enhanced exponential backoff with jitter
                    let baseDelay = min(pow(2.0, Double(retryCount)), 8.0) // Cap at 8 seconds
                    let jitter = Double.random(in: 0.8 ... 1.2) // Add ±20% jitter
                    let delaySeconds = baseDelay * jitter

                    LogManager.logInfo(
                        "Network Service - Waiting \(String(format: "%.1f", delaySeconds))s before retry \(retryCount)/\(maxRetries)"
                    )
                    try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                    continue // Go to next iteration of the while loop

                default:
                    LogManager.logError(
                        "Network Service - Unexpected status code \(httpResponse.statusCode) for \(requestToSend.url.map { LogManager.sanitizeURLForLogging($0) } ?? "Unknown URL")"
                    )
                    throw NetworkError.requestFailed
                }

            } catch let error as URLError
                where error.code == .timedOut || error.code == .cannotFindHost
                || error.code == .cannotConnectToHost || error.code == .networkConnectionLost
            {
                LogManager.logDebug(
                    "Network Service - Network error: \(error.localizedDescription). Retry \(retryCount + 1)/\(maxRetries)."
                )
                retryCount += 1
                if retryCount >= maxRetries {
                    LogManager.logError("Network Service - Max retries reached for network error.")
                    throw NetworkError.requestFailed // Or map specific URLError codes
                }

                // Enhanced exponential backoff for network errors with jitter
                let baseDelay = min(pow(2.0, Double(retryCount)), 10.0) // Cap at 10 seconds for network errors
                let jitter = Double.random(in: 0.7 ... 1.3) // Add ±30% jitter for network errors
                let delaySeconds = baseDelay * jitter

                LogManager.logInfo(
                    "Network Service - Waiting \(String(format: "%.1f", delaySeconds))s before network retry \(retryCount)/\(maxRetries)"
                )
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                continue // Go to next iteration
            } catch {
                // Handle other errors
                LogManager.logError("Network Service - Unhandled error during request: \(error)")
                throw error // Rethrow other errors
            }
        }

        // If loop finishes without returning/throwing (e.g., max retries for 5xx errors)
        LogManager.logError(
            "Network Service - Max retry attempts reached for \(currentRequest.url.map { LogManager.sanitizeURLForLogging($0) } ?? "Unknown URL")."
        )
        throw NetworkError.maxRetryAttemptsReached
    }

    private func requestWithExactAuthContinuity(
        _ request: URLRequest,
        additionalHeaders: [String: String]?,
        scope: ExactAuthGeneratedRequestScope
    ) async throws -> (Data, URLResponse) {
        guard let boundURL = request.url else {
            scope.state.failContinuity()
            throw ExactAuthGeneratedRequestContinuityError()
        }
        guard try await validateURL(boundURL) else {
            scope.state.failContinuity()
            throw NetworkError.securityViolation
        }
        guard isActiveExactAuthRequestScope(scope),
              ExactAuthRequestOrigin(boundURL) == scope.origin,
              request.httpBodyStream == nil,
              !Task.isCancelled,
              let captured = await exactAuthProvider(matching: scope.expected)
        else {
            scope.state.failContinuity()
            throw ExactAuthGeneratedRequestContinuityError()
        }

        var requestToPrepare = request
        for field in ["Authorization", "DPoP", "Cookie", "Proxy-Authorization"] {
            requestToPrepare.setValue(nil, forHTTPHeaderField: field)
        }
        for (name, value) in headers {
            guard !Self.isCredentialHeader(name) else { continue }
            requestToPrepare.setValue(value, forHTTPHeaderField: name)
        }
        if let additionalHeaders {
            for (name, value) in additionalHeaders {
                guard !Self.isCredentialHeader(name) else { continue }
                if name.lowercased() == "atproto-proxy",
                   requestToPrepare.url?.host != baseURL.host
                {
                    continue
                }
                requestToPrepare.setValue(value, forHTTPHeaderField: name)
            }
        }
        if let userAgent {
            requestToPrepare.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            requestToPrepare.setValue(userAgent, forHTTPHeaderField: "X-Catbird-Client")
        }
        requestToPrepare.setValue(UUID().uuidString, forHTTPHeaderField: "X-Catbird-Request-Id")

        let prepared: URLRequest
        var authCtx: AuthContext? = nil
        defer {
            authCtx?.releaseAuthenticationLease()
        }
        do {
            let (preparedRequest, context) = try await captured.provider.prepareAuthenticatedRequestWithContext(requestToPrepare)
            prepared = preparedRequest
            authCtx = context
        } catch {
            scope.state.failContinuity()
            throw ExactAuthGeneratedRequestContinuityError()
        }

        guard !Task.isCancelled,
              isActiveExactAuthRequestScope(scope),
              prepared.url?.absoluteString == boundURL.absoluteString,
              prepared.httpMethod == request.httpMethod,
              prepared.httpBody == request.httpBody,
              prepared.httpBodyStream == nil,
              let authorization = prepared.value(forHTTPHeaderField: "Authorization"),
              !authorization.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              prepared.value(forHTTPHeaderField: "Cookie") == nil,
              prepared.value(forHTTPHeaderField: "Proxy-Authorization") == nil,
              await exactAuthSnapshot(
                  for: captured.provider,
                  at: captured.revision,
                  matching: scope.expected
              ),
              scope.state.claimLaunch()
        else {
            scope.state.failContinuity()
            throw ExactAuthGeneratedRequestContinuityError()
        }

        let (data, response) = try await executeDataTask(prepared, using: exactAuthSession, delegate: exactAuthSessionDelegate)
        authCtx?.releaseAuthenticationLease()
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse(description: "Received non-HTTP response")
        }

        guard await exactAuthSnapshot(
            for: captured.provider,
            at: captured.revision,
            matching: scope.expected
        ),
            isActiveExactAuthRequestScope(scope),
            httpResponse.url?.absoluteString == boundURL.absoluteString,
            scope.state.completeResponse()
        else {
            scope.state.failContinuity()
            throw ExactAuthGeneratedRequestContinuityError()
        }
        return (data, httpResponse)
    }
    private func executeDataTask(
        _ request: URLRequest,
        using targetSession: URLSession,
        delegate: HardenedURLSessionDelegate
    ) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        guard let url = request.url, let host = url.host?.lowercased() else {
            throw NetworkError.invalidURL
        }
        let isLocal = host == "localhost" || host == "127.0.0.1" || host == "::1"
        let addresses = try await Self.resolveApprovedAddresses(host: host, isLocal: isLocal)
        let task = targetSession.dataTask(with: request)
        let rawResult: (Data, URLResponse) = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                delegate.contextManager.register(task) { result in
                    continuation.resume(with: result)
                }
                delegate.contextManager.setApprovedAddresses(addresses, for: task)
                task.resume()
                if Task.isCancelled {
                    task.cancel()
                }
            }
        } onCancel: {
            task.cancel()
        }
        return (
            try ContentDecoding.normalizeResponse(rawResult.0, response: rawResult.1, limits: delegate.limits),
            rawResult.1
        )
    }
    private func isActiveExactAuthRequestScope(_ scope: ExactAuthGeneratedRequestScope) -> Bool {
        guard scope.networkServiceID == exactAuthRequestScopeServiceID,
              activeExactAuthRequestScope?.id == scope.id,
              activeExactAuthRequestScope?.expected == scope.expected,
              activeExactAuthRequestScope?.origin == scope.origin,
              activeExactAuthRequestScope?.destinationGeneration == scope.destinationGeneration,
              exactAuthDestinationGeneration == scope.destinationGeneration,
              ExactAuthRequestOrigin(baseURL) == scope.origin
        else {
            return false
        }
        return true
    }

    private nonisolated static func isCredentialHeader(_ name: String) -> Bool {
        switch name.lowercased() {
        case "authorization", "dpop", "cookie", "proxy-authorization":
            return true
        default:
            return false
        }
    }

    /// Performs a GET request to the specified endpoint.
    /// - Parameters:
    ///   - endpoint: The API endpoint path.
    ///   - queryItems: Optional query parameters.
    ///   - requiresAuth: Whether the request requires authentication.
    ///   - additionalHeaders: Optional additional headers to include with this specific request.
    /// - Returns: The decoded response data.
    func get<T: Decodable & Sendable>(
        endpoint: String,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = true,
        additionalHeaders: [String: String]? = nil
    ) async throws -> T {
        let urlRequest = try await createURLRequest(
            endpoint: endpoint,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: queryItems
        )

        let (data, _) = try await request(urlRequest, additionalHeaders: additionalHeaders)

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            // DIAGNOSTIC: Log raw response bytes to debug ANSI escape code issue
            let hexPrefix = data.prefix(40).map { String(format: "%02x", $0) }.joined(separator: " ")
            let stringPrefix = String(data: data.prefix(200), encoding: .utf8) ?? "<non-UTF8>"
            LogManager.logError("Network Service - GET Decoding error for \(endpoint)")
            LogManager.logError("  First 40 bytes (hex): \(hexPrefix)")
            LogManager.logError("  First 200 chars: \(stringPrefix)")
            LogManager.logError("  Decode error: \(error)")
            throw NetworkError.decodingError
        }
    }

    /// Performs a POST request to the specified endpoint.
    /// - Parameters:
    ///   - endpoint: The API endpoint path.
    ///   - body: The request body to send.
    ///   - requiresAuth: Whether the request requires authentication.
    ///   - additionalHeaders: Optional additional headers to include with this specific request.
    /// - Returns: The decoded response data.
    func post<T: Decodable & Sendable, B: Encodable & Sendable>(
        endpoint: String,
        body: B? = nil,
        requiresAuth: Bool = true,
        additionalHeaders: [String: String]? = nil
    ) async throws -> T {
        var bodyData: Data? = nil
        if let body = body {
            bodyData = try jsonEncoder.encode(body)
        }

        let urlRequest = try await createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: [:],
            body: bodyData,
            queryItems: nil
        )

        let (data, _) = try await request(urlRequest, additionalHeaders: additionalHeaders)

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            // DIAGNOSTIC: Log raw response bytes to debug ANSI escape code issue
            let hexPrefix = data.prefix(40).map { String(format: "%02x", $0) }.joined(separator: " ")
            let stringPrefix = String(data: data.prefix(200), encoding: .utf8) ?? "<non-UTF8>"
            LogManager.logError("Network Service - POST Decoding error for \(endpoint)")
            LogManager.logError("  First 40 bytes (hex): \(hexPrefix)")
            LogManager.logError("  First 200 chars: \(stringPrefix)")
            LogManager.logError("  Decode error: \(error)")
            throw NetworkError.decodingError
        }
    }

    // MARK: - Compatibility Methods

    /// Creates a URLRequest with the specified parameters (compatibility method)
    /// - Parameters:
    ///   - endpoint: The API endpoint path.
    ///   - method: The HTTP method (GET, POST, etc.).
    ///   - headers: Additional HTTP headers.
    ///   - body: The HTTP body data.
    ///   - queryItems: Optional query parameters.
    /// - Returns: The configured URLRequest.
    public func createURLRequest(
        endpoint: String,
        method: String,
        headers: [String: String],
        body: Data?,
        queryItems: [URLQueryItem]?
    ) async throws -> URLRequest {
        // Construct the URL
        let url: URL
        var components: URLComponents?
        if endpoint.lowercased().starts(with: "http") {
            // Absolute URL
            guard let absoluteURL = URL(string: endpoint) else {
                throw NetworkError.invalidURL
            }
            url = absoluteURL
            components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        } else {
            // Relative endpoint to base URL
            let xrpcPath = endpoint.starts(with: "/") ? "xrpc\(endpoint)" : "xrpc/\(endpoint)"
            url = baseURL.appendingPathComponent(xrpcPath)
            components = URLComponents(url: url, resolvingAgainstBaseURL: true)

            // NOTE: Service DIDs (e.g., app.bsky -> did:web:api.bsky.app#bsky_appview) are
            // used for the atproto-proxy header, NOT for changing the request host.
            // Requests should always go to the user's PDS with the service DID in the header.
            // The PDS will proxy the request to the appropriate service.
        }

        // Add query items if provided
        if let queryItems = queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let finalURL = components?.url else {
            throw NetworkError.invalidURL
        }

        // Apply connection policy adapter if set (e.g., for bypassing proxy for WebSockets)
        let resolvedURL: URL
        if let adapter = connectionPolicyAdapter {
            resolvedURL = await adapter.resolveConnectionURL(finalURL, endpoint: endpoint)
            if resolvedURL != finalURL {
                LogManager.logInfo("Network Service - Connection policy adapter resolved URL: \(LogManager.sanitizeURLForLogging(finalURL)) -> \(LogManager.sanitizeURLForLogging(resolvedURL))")
            }
        } else {
            resolvedURL = finalURL
        }

        // Validate URL for security
        if !(try await validateURL(resolvedURL)) {
            LogManager.logError("Security validation failed for URL: \(LogManager.sanitizeURLForLogging(resolvedURL)). This may be due to DNS resolution to private IP ranges or network configuration issues.")
            throw NetworkError.securityViolation
        }

        // Create the request
        var request = URLRequest(url: resolvedURL)
        request.httpMethod = method

        // Let URLSession negotiate transparent decoding or wire transfer;
        // executeDataTask normalizes the response through ContentDecoding.normalizeResponse.
        // Add custom headers
        for (key, value) in self.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add request-specific headers (will be filtered later based on host)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add user agent if available
        if let userAgent = userAgent, request.value(forHTTPHeaderField: "User-Agent") == nil {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }

        // Add body if provided
        if let body = body {
            request.httpBody = body
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        return request
    }

    /// Performs a network request (compatibility method)
    /// - Parameters:
    ///   - request: The URLRequest to perform.
    ///   - skipTokenRefresh: Whether to skip token refresh.
    ///   - additionalHeaders: Optional additional headers to include with this specific request.
    /// - Returns: A tuple containing the response data and HTTPURLResponse.
    public func performRequest(_ request: URLRequest, skipTokenRefresh: Bool, additionalHeaders: [String: String]? = nil) async throws -> (
        Data, HTTPURLResponse
    ) {
        let (data, response) = try await self.request(request, skipTokenRefresh: skipTokenRefresh, additionalHeaders: additionalHeaders)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse(description: "Response is not an HTTP response")
        }
        return (data, httpResponse)
    }

    /// Performs a request while returning terminal HTTP error responses to the
    /// caller for structured endpoint-error parsing.
    ///
    /// This follows the same validation, authentication, DPoP nonce, token
    /// refresh, and retry pipeline as `performRequest`. Successful responses
    /// and status 400 are returned as before. Statuses 402 through 499 are
    /// returned after authentication handling, and 5xx responses are returned
    /// only after the existing retry budget is exhausted. A 401 remains owned
    /// by the authentication pipeline; any awaited built-in authentication
    /// retry inherits this terminal-status policy. Transport, cancellation,
    /// validation, and authentication failures still throw.
    ///
    /// - Parameters:
    ///   - request: The URL request to perform.
    ///   - skipTokenRefresh: Whether to skip token refresh.
    ///   - additionalHeaders: Optional headers for this request.
    /// - Returns: The response body and final HTTP response.
    public func performRequestReturningHTTPErrorResponses(
        _ request: URLRequest,
        skipTokenRefresh: Bool,
        additionalHeaders: [String: String]? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let identity = HTTPErrorResponseRequestIdentity(
            networkService: self,
            request: request
        )
        return try await Self.$terminalHTTPErrorResponseRequest.withValue(identity) {
            try await self.performRequest(
                request,
                skipTokenRefresh: skipTokenRefresh,
                additionalHeaders: additionalHeaders
            )
        }
    }

    /// Performs a network request (protocol compatibility method)
    /// - Parameters:
    ///   - request: The URLRequest to perform.
    ///   - skipTokenRefresh: Whether to skip token refresh.
    /// - Returns: A tuple containing the response data and HTTPURLResponse.
    public func performRequest(_ request: URLRequest, skipTokenRefresh: Bool) async throws -> (
        Data, HTTPURLResponse
    ) {
        try await performRequest(request, skipTokenRefresh: skipTokenRefresh, additionalHeaders: nil)
    }

    /// Performs a network request (compatibility method)
    /// - Parameter request: The URLRequest to perform.
    /// - Returns: A tuple containing the response data and HTTPURLResponse.
    nonisolated func performRequest(_ request: URLRequest) async throws -> (
        Data, HTTPURLResponse
    ) {
        try await performRequest(request, skipTokenRefresh: false)
    }

    // MARK: - Server-Sent Events (SSE) Support

    /// Prepares an authenticated URLRequest for streaming (SSE, WebSocket, etc.)
    /// - Parameters:
    ///   - request: The original URLRequest
    ///   - additionalHeaders: Optional additional headers (e.g., atproto-proxy)
    /// - Returns: PreparedStreamingRequest containing the URLRequest and its authentication lease
    func prepareStreamingRequest(
        _ request: URLRequest,
        additionalHeaders: [String: String]? = nil
    ) async throws -> PreparedStreamingRequest {
        guard let url = request.url else {
            throw NetworkError.invalidURL
        }

        if !(try await validateURL(url)) {
            LogManager.logError("Security validation failed for streaming URL: \(LogManager.sanitizeURLForLogging(url))")
            throw NetworkError.securityViolation
        }

        let policy = determineSecurityPolicy(for: url)
        let (authedRequest, authCtx) = try await attachCredentialsIfAuthorized(request, policy: policy)
        var finalRequest = authedRequest

        // Add custom headers
        for (name, value) in headers {
            finalRequest.setValue(value, forHTTPHeaderField: name)
        }

        // Add additional headers for this specific request
        if let additionalHeaders = additionalHeaders {
            for (name, value) in additionalHeaders {
                // If we're not targeting the PDS host, do not attach atproto-proxy
                if name.lowercased() == "atproto-proxy",
                   let h = finalRequest.url?.host,
                   h != baseURL.host
                {
                    // Skip proxy header for direct-to-service requests
                    continue
                }
                finalRequest.setValue(value, forHTTPHeaderField: name)
                if name == "atproto-proxy" {
                    LogManager.logInfo("Setting atproto-proxy header for streaming: \(value)")
                }
            }
        }

        // Add user agent
        if let userAgent = userAgent {
            finalRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }

        return PreparedStreamingRequest(request: finalRequest, authContext: authCtx)
    }

    // MARK: - WebSocket Subscription Support

    /// Subscribe to a WebSocket event stream
    /// - Parameters:
    ///   - endpoint: The subscription endpoint
    ///   - parameters: Optional query parameters
    /// - Returns: An async throwing stream of decoded messages
    public func subscribe<Message: Codable & Sendable>(
        endpoint: String,
        parameters: (any Parametrizable)?
    ) async throws -> AsyncThrowingStream<Message, Error> {
        // Build WebSocket URL
        var urlComponents = URLComponents()
        urlComponents.scheme = "wss"

        // Resolve service DID with strongest signal first (full endpoint),
        // then fall back to the three-part namespace (e.g., blue.catbird.mls)
        let fullEndpoint = endpoint
        let threePartNamespace = endpoint.split(separator: ".").prefix(3).joined(separator: ".")

        var resolvedDID = await getServiceDID(for: fullEndpoint)
        if resolvedDID == nil {
            resolvedDID = await getServiceDID(for: String(threePartNamespace))
        }

        if let did = resolvedDID, let serviceHost = extractHostFromDID(did) {
            // Prefer connecting directly to the service host for WS
            urlComponents.host = serviceHost
        } else {
            // Fallback to the PDS host (baseURL)
            urlComponents.host = baseURL.host
        }

        urlComponents.path = "/xrpc/\(endpoint)"

        // Add query parameters if provided
        if let params = parameters {
            urlComponents.queryItems = params.asQueryItems()
        }

        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }

        // Apply connection policy adapter if set (e.g., for direct WebSocket connections bypassing proxy)
        let resolvedURL: URL
        if let adapter = connectionPolicyAdapter {
            resolvedURL = await adapter.resolveConnectionURL(url, endpoint: endpoint)
            if resolvedURL != url {
                LogManager.logInfo("Network Service - Connection policy adapter resolved WebSocket URL: \(LogManager.sanitizeURLForLogging(url)) -> \(LogManager.sanitizeURLForLogging(resolvedURL))")
            }
        } else {
            resolvedURL = url
        }

        // Validate WebSocket URL for security
        if !(try await validateURL(resolvedURL)) {
            LogManager.logError("Security validation failed for WebSocket URL: \(LogManager.sanitizeURLForLogging(resolvedURL))")
            throw NetworkError.securityViolation
        }

        // Create URLRequest to add auth headers and optional proxy header
        var request = URLRequest(url: resolvedURL)

        // If we are connecting via the PDS host, attach atproto-proxy so the PDS can forward
        if resolvedURL.host == baseURL.host, let did = resolvedDID {
            request.setValue(did, forHTTPHeaderField: "atproto-proxy")
            LogManager.logInfo("Network Service - Setting atproto-proxy header: \(did) for endpoint: \(resolvedURL.path)")
        }
        var authCtx: AuthContext? = nil
        defer {
            authCtx?.releaseAuthenticationLease()
        }
        let policy = determineSecurityPolicy(for: resolvedURL)
        let (authedRequest, authedCtx) = try await attachCredentialsIfAuthorized(request, policy: policy)
        request = authedRequest
        authCtx = authedCtx
        let webSocketTask: any WebSocketTaskProtocol = {
            #if DEBUG
            if let override = Self.webSocketTaskOverride {
                return override(request)
            }
            #endif
            return session.webSocketTask(with: request)
        }()
        let websocketHost = resolvedURL.host?.lowercased() ?? ""
        let websocketIsLocal = websocketHost == "localhost" || websocketHost == "127.0.0.1" || websocketHost == "::1"
        let websocketAddresses = try await Self.resolveApprovedAddresses(host: websocketHost, isLocal: websocketIsLocal)
        if let urlSessionTask = webSocketTask as? URLSessionTask {
            sessionDelegate.contextManager.setApprovedAddresses(websocketAddresses, for: urlSessionTask)
        }
        webSocketTask.resume()

        // Create bounded async throwing stream with buffer size 1000
        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1000)) { continuation in
            Task {
                do {
                    while !Task.isCancelled {
                        let message = try await webSocketTask.receive()

                        switch message {
                        case let .data(data):
                            do {
                                let decodedMessage = try self.decodeSubscriptionFrame(data, as: Message.self, endpoint: endpoint)
                                let yieldResult = continuation.yield(decodedMessage)
                                switch yieldResult {
                                case .enqueued:
                                    break
                                case .dropped:
                                    LogManager.logError("Subscription stream dropped messages due to full buffer - terminating with overflow")
                                    continuation.finish(throwing: NetworkError.streamOverflow)
                                    webSocketTask.cancel(with: .goingAway, reason: nil)
                                    return
                                case .terminated:
                                    webSocketTask.cancel(with: .goingAway, reason: nil)
                                    return
                                @unknown default:
                                    LogManager.logError("Unknown yield result on subscription stream - terminating")
                                    continuation.finish(throwing: NetworkError.invalidResponse(description: "Unknown stream yield result"))
                                    webSocketTask.cancel(with: .goingAway, reason: nil)
                                    return
                                }
                            } catch {
                                LogManager.logError("Failed to decode WebSocket frame: \(error)")
                                continuation.finish(throwing: error)
                                webSocketTask.cancel(with: .goingAway, reason: nil)
                                return
                            }

                        case let .string(text):
                            LogManager.logError("Received unexpected text frame on subscription: \(text.utf8.count) bytes")
                            continuation.finish(throwing: NetworkError.invalidResponse(description: "Unexpected text frame received on binary WebSocket subscription"))
                            webSocketTask.cancel(with: .goingAway, reason: nil)
                            return

                        @unknown default:
                            LogManager.logError("Received unknown WebSocket message type")
                            continuation.finish(throwing: NetworkError.invalidResponse(description: "Unknown WebSocket message type"))
                            webSocketTask.cancel(with: .goingAway, reason: nil)
                            return
                        }
                    }
                } catch {
                    if let urlSessionTask = webSocketTask as? URLSessionTask {
                        if self.sessionDelegate.contextManager.isSecurityViolation(for: urlSessionTask) {
                            self.sessionDelegate.contextManager.pruneCompletedTask(urlSessionTask)
                            LogManager.logError("WebSocket terminated due to security violation")
                            continuation.finish(throwing: NetworkError.securityViolation)
                            return
                        }
                        if self.sessionDelegate.contextManager.isLimitExceeded(for: urlSessionTask) {
                            self.sessionDelegate.contextManager.pruneCompletedTask(urlSessionTask)
                            LogManager.logError("WebSocket terminated due to response limit exceeded")
                            continuation.finish(throwing: NetworkError.responseLimitExceeded("Response limit exceeded"))
                            return
                        }
                        self.sessionDelegate.contextManager.pruneCompletedTask(urlSessionTask)
                    }
                    if let urlError = error as? URLError, urlError.code == .cancelled {
                        LogManager.logInfo("WebSocket connection closed")
                        continuation.finish()
                    } else {
                        LogManager.logError("WebSocket error: \(error)")
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { @Sendable _ in
                webSocketTask.cancel(with: .goingAway, reason: nil)
                LogManager.logDebug("WebSocket task cancelled")
            }
        }
    }
    /// Decode a subscription WebSocket frame containing two DAG-CBOR objects
    private func decodeSubscriptionFrame<Message: Codable & Sendable>(
        _ data: Data,
        as messageType: Message.Type,
        endpoint: String
    ) throws -> Message {
        let decoded = try ATProtoWebSocketFrameDecoder.decodeFrame(data, defaultLexicon: endpoint)
        do {
            return try jsonDecoder.decode(Message.self, from: decoded.jsonData)
        } catch {
            LogManager.logError("Failed to decode JSON payload (\(decoded.jsonData.count) bytes) for message type: \(decoded.messageType)")
            throw error
        }
    }

    // MARK: - Helper Methods

    /// Helper to parse a labeler header value according to RFC-8941
    /// - Parameter header: The header value to parse
    /// - Returns: Array of tuples containing labeler DIDs and redaction flags
    private nonisolated func parseLabelerHeader(_ header: String) -> [(did: String, redact: Bool)] {
        let components = header.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        return components.compactMap { component in
            let parts = component.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let did = parts.first, !did.isEmpty else { return nil }

            // Check if redact parameter is present
            let redact = parts.count > 1 && parts.contains("redact")

            return (did: String(did), redact: redact)
        }
    }

    /// Extract hostname from a DID (e.g., "did:web:mls.catbird.blue#atproto_mls" -> "mls.catbird.blue", or nested path "did:web:evil.example:a:b" -> "evil.example")
    /// - Parameter did: The DID string
    /// - Returns: The hostname if extractable, nil otherwise
    private func extractHostFromDID(_ did: String) -> String? {
        guard did.hasPrefix("did:web:") else { return nil }
        let withoutPrefix = did.dropFirst("did:web:".count)
        let withoutFragment = withoutPrefix.split(separator: "#").first ?? withoutPrefix[...]
        // did:web separates authority and path components with colons ':'
        // e.g. did:web:example.com:user:alice -> authority is example.com
        let segments = withoutFragment.split(separator: ":", omittingEmptySubsequences: false)
        guard let rawAuthority = segments.first else { return nil }
        let rawAuthorityStr = String(rawAuthority)
        // Handle percent-encoded port (e.g. host%3A8080)
        let authorityParts = rawAuthorityStr.components(separatedBy: "%3A")
        guard let hostSegment = authorityParts.first, !hostSegment.isEmpty else { return nil }
        let host = hostSegment.removingPercentEncoding ?? hostSegment
        return host.isEmpty ? nil : host
    }

    private func validateURL(_ url: URL) async throws -> Bool {
        try await Self.validateURL(url)
    }

    /// Validates the URL for security.
    /// - Parameter url: The URL to validate.
    /// - Returns: A boolean indicating whether the URL is valid.
    package static func validateURL(_ url: URL) async throws -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            LogManager.logError("Missing URL scheme")
            return false
        }

        guard let host = url.host, !host.isEmpty else { return false }
        let normalizedHost = host.lowercased()

        let isLocalTarget = normalizedHost == "localhost" || normalizedHost == "127.0.0.1" || normalizedHost == "::1"

        // Remote traffic requires HTTPS or WSS. HTTP and WS are only permitted for verified loopback targets.
        if scheme == "http" || scheme == "ws" {
            guard isLocalTarget else {
                LogManager.logError("Rejected cleartext scheme (\(scheme)) for remote host: \(host)")
                return false
            }
        } else if scheme != "https" && scheme != "wss" {
            LogManager.logError("Invalid URL scheme: \(scheme)")
            return false
        }

        _ = try await Self.resolveApprovedAddresses(host: normalizedHost, isLocal: isLocalTarget)
        return true
    }

    /// Resolves and validates host IP addresses against private and reserved ranges.
    /// Returns the set of approved normalized IP addresses, or throws `NetworkError.securityViolation`.
    package static func resolveApprovedAddresses(host: String, isLocal: Bool) async throws -> Set<String> {
        let normalizedHost = host.lowercased()
        let rawAddresses: [String]
        #if canImport(Network)
            if IPv4Address(normalizedHost) != nil || IPv6Address(normalizedHost) != nil {
                rawAddresses = [normalizedHost]
            } else {
                rawAddresses = try await resolveHostIPsOffActor(host: normalizedHost)
            }
        #else
            let isIPv4 = normalizedHost.split(separator: ".").count == 4 && normalizedHost.allSatisfy { $0.isNumber || $0 == "." }
            let isIPv6 = normalizedHost.contains(":")
            if isIPv4 || isIPv6 {
                rawAddresses = [normalizedHost]
            } else {
                rawAddresses = try await resolveHostIPsOffActor(host: normalizedHost)
            }
        #endif
        let addresses = Set(rawAddresses.map { IPAddress.normalizeIPv4MappedIPv6($0) })
        guard !addresses.isEmpty else {
            throw NetworkError.requestFailed
        }
        if isLocal {
            guard addresses.allSatisfy({ $0 == "127.0.0.1" || $0 == "::1" }) else {
                throw NetworkError.securityViolation
            }
        } else {
            guard !addresses.contains(where: IPAddress.isPrivateOrReservedAddress) else {
                throw NetworkError.securityViolation
            }
        }
        return addresses
    }

    /// Attaches credentials to a request if authorized by policy and provider is available.
    /// If policy is `.authenticated` and the target matches recipient origin, credentials are attached.
    /// If no active account is currently signed in (`AuthError.noActiveAccount`), the request proceeds unauthenticated.
    private func attachCredentialsIfAuthorized(
        _ request: URLRequest,
        policy: RequestSecurityPolicy,
        skipTokenRefresh: Bool = false
    ) async throws -> (URLRequest, AuthContext?) {
        guard let url = request.url else {
            return (request, nil)
        }
        let requiresAuth: Bool
        switch policy {
        case .unauthenticated:
            requiresAuth = false
        case let .authenticated(recipient):
            if let origin = ExactAuthRequestOrigin(url), origin == recipient {
                requiresAuth = true
            } else {
                requiresAuth = false
            }
        }
        guard requiresAuth else {
            LogManager.logDebug("No authentication required for: \(LogManager.sanitizeURLForLogging(url))")
            return (request, nil)
        }
        guard let authProvider = authProvider else {
            LogManager.logDebug("Authentication required but no auth provider set for: \(LogManager.sanitizeURLForLogging(url))")
            return (request, nil)
        }

        do {
            if !skipTokenRefresh {
                _ = try await authProvider.refreshTokenIfNeeded()
            }
            let (authed, ctx) = try await authProvider.prepareAuthenticatedRequestWithContext(request)
            LogManager.logDebug("Prepared authenticated request for: \(LogManager.sanitizeURLForLogging(url))")
            return (authed, ctx)
        } catch AuthError.noActiveAccount {
            LogManager.logError("No active account for authenticated request: \(LogManager.sanitizeURLForLogging(url)). Proceeding without authentication.")
            return (request, nil)
        } catch {
            LogManager.logError("Failed to prepare authenticated request for \(LogManager.sanitizeURLForLogging(url)): \(error)")
            if let authErr = error as? AuthError {
                throw authErr
            }
            throw NetworkError.authenticationFailed
        }
    }

    static func resolveHostIPsOffActor(host: String) async throws -> [String] {
        try Task.checkCancellation()

        final class ResolutionState: @unchecked Sendable {
            private let lock = NSLock()
            private var continuation: CheckedContinuation<[String], Error>?
            private weak var operation: Operation?
            private var isFinished = false

            func attach(continuation cont: CheckedContinuation<[String], Error>, operation op: Operation) {
                lock.lock()
                defer { lock.unlock() }
                if isFinished {
                    cont.resume(throwing: CancellationError())
                    op.cancel()
                } else {
                    self.continuation = cont
                    self.operation = op
                }
            }

            func finish(with ips: [String]) {
                lock.lock()
                guard !isFinished else {
                    lock.unlock()
                    return
                }
                isFinished = true
                let cont = continuation
                continuation = nil
                operation = nil
                lock.unlock()
                cont?.resume(returning: ips)
            }

            func cancel() {
                lock.lock()
                guard !isFinished else {
                    lock.unlock()
                    return
                }
                isFinished = true
                let cont = continuation
                continuation = nil
                let op = operation
                operation = nil
                lock.unlock()
                op?.cancel()
                cont?.resume(throwing: CancellationError())
            }
        }

        let state = ResolutionState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let operation = BlockOperation()
                operation.addExecutionBlock { [weak operation] in
                    guard let operation, !operation.isCancelled else { return }

                    #if DEBUG
                        if let hook = dnsResolutionHook {
                            hook(host) { operation.isCancelled }
                        }
                    #endif

                    guard !operation.isCancelled else { return }
                    let ips = resolveHostIPs(host: host)
                    guard !operation.isCancelled else { return }
                    state.finish(with: ips)
                }
                state.attach(continuation: continuation, operation: operation)
                dnsResolutionQueue.addOperation(operation)
            }
        } onCancel: {
            state.cancel()
        }
    }

    // MARK: - SSRF Hardeners

    private static func resolveHostIPs(host: String) -> [String] {
        #if DEBUG
            if let override = dnsResolverOverride, let ips = override(host) {
                return ips
            }
        #endif
        var results: [String] = []
        var hints = addrinfo()
        hints.ai_flags = AI_ADDRCONFIG
        hints.ai_family = AF_UNSPEC
        #if os(Linux)
            hints.ai_socktype = Int32(SOCK_STREAM.rawValue)
        #else
            hints.ai_socktype = SOCK_STREAM
        #endif
        var res: UnsafeMutablePointer<addrinfo>? = nil
        let status = getaddrinfo(host, nil, &hints, &res)
        if status == 0, let head = res {
            var ptr: UnsafeMutablePointer<addrinfo>? = head
            while let ai = ptr?.pointee {
                if let sa = ai.ai_addr {
                    var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(
                        sa,
                        socklen_t(ai.ai_addrlen),
                        &hostBuffer,
                        socklen_t(hostBuffer.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    ) == 0 {
                        let bytes = hostBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
                        let ip = String(decoding: bytes, as: UTF8.self)
                        results.append(ip)
                    }
                }
                ptr = ai.ai_next
            }
            freeaddrinfo(head)
        }
        return results
    }

}

/// Extension to help with task value extraction
extension Task where Success == Never, Failure == Never {
    /// Use sleep(0) instead of recursively calling Task.yield()
    static func yield() async {
        try? await Task.sleep(nanoseconds: 0)
    }
}

extension Result {
    var success: Success? {
        guard case let .success(value) = self else { return nil }
        return value
    }

    var failure: Failure? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}
