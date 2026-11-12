import Foundation

/// A client's validated metadata together with the key set it authenticates
/// with (inline `jwks`, or the document fetched from `jwks_uri`).
public struct OAuthResolvedClientMetadata: Sendable, Equatable, Codable {
    /// The validated metadata document.
    public let metadata: OAuthClientMetadata
    /// The client's keys, or `nil` for a public client.
    public let keySet: OAuthJSONWebKeySet?

    /// Creates a resolved client.
    public init(metadata: OAuthClientMetadata, keySet: OAuthJSONWebKeySet?) {
        self.metadata = metadata
        self.keySet = keySet
    }
}

/// Turns a `client_id` into validated client metadata.
///
/// The authorization server depends on this protocol, so a host can replace
/// discovery entirely (a fixed registry, a database of pre-registered
/// clients). ``OAuthClientMetadataLoader`` is the standard implementation.
public protocol OAuthClientResolving: Sendable {
    /// Resolves a client.
    ///
    /// - Parameters:
    ///   - clientID: the `client_id` URL presented by the client.
    ///   - revalidate: when true, cached metadata is ignored and the documents
    ///     are fetched again. Used before trusting a confidential client's key
    ///     at refresh, so a key removed from the JWKS stops working promptly.
    ///   - now: the evaluation instant, for cache expiry.
    func resolve(clientID: URL, revalidate: Bool, now: Date) async throws -> OAuthResolvedClientMetadata
}

/// Resolves clients as the AT Protocol OAuth profile specifies: the
/// `client_id` is the URL of a metadata document, except for the
/// `http://localhost` development form, whose metadata is derived from the
/// `client_id` itself without any request.
///
/// Fetches go through an ``OAuthRemoteDocumentFetcher`` (HTTPS only, public
/// addresses only, no redirects, exact status 200, JSON content type, bounded
/// size and time). Results are cached for `cacheLifetime`, and concurrent
/// loads of the same client share one fetch.
public actor OAuthClientMetadataLoader: OAuthClientResolving {
    private let fetcher: OAuthRemoteDocumentFetcher
    private let cache: any OAuthClientMetadataCacheStore
    private let cacheLifetime: TimeInterval
    private let allowsLoopbackClients: Bool
    private var inFlight: [String: Task<OAuthResolvedClientMetadata, Error>] = [:]
    private static let maximumConcurrentFetches = 16

    /// Creates a loader.
    ///
    /// - Parameters:
    ///   - fetcher: the hardened document fetcher.
    ///   - cache: where validated documents are kept.
    ///   - cacheLifetime: seconds a document is served from cache, 5 through
    ///     900. Short, so a changed JWKS takes effect quickly.
    ///   - allowsLoopbackClients: whether `http://localhost` development
    ///     clients are accepted. The profile encourages supporting them, also
    ///     in production.
    public init(
        fetcher: OAuthRemoteDocumentFetcher,
        cache: any OAuthClientMetadataCacheStore,
        cacheLifetime: TimeInterval = 300,
        allowsLoopbackClients: Bool = true
    ) throws {
        guard cacheLifetime >= 5, cacheLifetime <= 900, cacheLifetime.isFinite else {
            throw OAuthServerError.malformed("OAuth metadata cache lifetime is out of bounds")
        }
        self.fetcher = fetcher
        self.cache = cache
        self.cacheLifetime = cacheLifetime
        self.allowsLoopbackClients = allowsLoopbackClients
    }

    public func resolve(
        clientID: URL,
        revalidate: Bool = false,
        now: Date = Date()
    ) async throws -> OAuthResolvedClientMetadata {
        try Task.checkCancellation()
        if OAuthClientMetadata.isLoopbackDevelopmentClientID(clientID) {
            guard allowsLoopbackClients else {
                throw OAuthServerError.unauthorized("loopback development clients are disabled")
            }
            return try OAuthResolvedClientMetadata(
                metadata: OAuthClientMetadata.loopbackDevelopmentMetadata(clientID: clientID),
                keySet: nil
            )
        }
        try OAuthClientMetadata.validateStandardClientID(clientID)
        let key = clientID.absoluteString

        if !revalidate, let cached = try? await cache.cachedClientMetadata(clientID: key, now: now),
           cached.clientID == key,
           let resolved = try? JSONDecoder().decode(OAuthResolvedClientMetadata.self, from: cached.document),
           resolved.metadata.clientID.absoluteString == key
        {
            return resolved
        }

        let flightKey = revalidate ? "revalidate:\(key)" : key
        if let flight = inFlight[flightKey] {
            return try await flight.value
        }
        guard inFlight.count < Self.maximumConcurrentFetches else {
            throw OAuthServerError.unavailable("OAuth client metadata fetch capacity is exhausted")
        }
        let fetcher = self.fetcher
        let cache = self.cache
        let cacheLifetime = self.cacheLifetime
        let flight = Task<OAuthResolvedClientMetadata, Error> {
            let resolved = try await Self.fetchAndValidate(clientID: clientID, fetcher: fetcher)
            if let document = try? JSONEncoder().encode(resolved) {
                try? await cache.cacheClientMetadata(
                    OAuthCachedClientMetadata(
                        clientID: key,
                        document: document,
                        expiresAt: now.addingTimeInterval(cacheLifetime)
                    ),
                    now: now
                )
            }
            return resolved
        }
        inFlight[flightKey] = flight
        defer { inFlight.removeValue(forKey: flightKey) }
        return try await flight.value
    }

    private static func fetchAndValidate(
        clientID: URL,
        fetcher: OAuthRemoteDocumentFetcher
    ) async throws -> OAuthResolvedClientMetadata {
        let metadata = try await OAuthClientMetadata.decodeValidated(
            fetcher.fetchJSON(from: clientID),
            responseURL: clientID
        )
        let keySet: OAuthJSONWebKeySet?
        if let inline = metadata.jwks {
            keySet = inline
        } else if let jwksURI = metadata.jwksURI {
            keySet = try await OAuthJSONWebKeySet.decodeValidated(fetcher.fetchJSON(from: jwksURI))
        } else {
            keySet = nil
        }
        return OAuthResolvedClientMetadata(metadata: metadata, keySet: keySet)
    }
}

/// A fixed table of clients, for tests and for deployments that pre-register
/// their clients instead of discovering them.
///
/// Loopback development clients are still derived from their `client_id` when
/// `allowsLoopbackClients` is true.
public struct StaticOAuthClientResolver: OAuthClientResolving {
    private let clients: [String: OAuthResolvedClientMetadata]
    private let allowsLoopbackClients: Bool

    /// Creates a resolver over `clients`, keyed by their `client_id`.
    public init(_ clients: [OAuthResolvedClientMetadata], allowsLoopbackClients: Bool = true) {
        self.clients = Dictionary(
            clients.map { ($0.metadata.clientID.absoluteString, $0) },
            uniquingKeysWith: { _, last in last }
        )
        self.allowsLoopbackClients = allowsLoopbackClients
    }

    public func resolve(clientID: URL, revalidate _: Bool, now _: Date) async throws -> OAuthResolvedClientMetadata {
        if OAuthClientMetadata.isLoopbackDevelopmentClientID(clientID) {
            guard allowsLoopbackClients else {
                throw OAuthServerError.unauthorized("loopback development clients are disabled")
            }
            return try OAuthResolvedClientMetadata(
                metadata: OAuthClientMetadata.loopbackDevelopmentMetadata(clientID: clientID),
                keySet: nil
            )
        }
        guard let client = clients[clientID.absoluteString] else {
            throw OAuthServerError.unauthorized("OAuth client is not registered")
        }
        return client
    }
}
