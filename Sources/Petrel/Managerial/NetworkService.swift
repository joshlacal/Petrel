//
//  NetworkService.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/22/2025.
//

import Darwin
import Foundation
import Network

/// Protocol for authentication providers
struct AuthContext: Sendable {
    let did: String?
    let jkt: String?
}

protocol AuthenticationProvider: Sendable {
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
}

/// Class responsible for handling network operations.
actor NetworkService: NetworkServiceProtocol {
    // MARK: - Properties

    private(set) var baseURL: URL
    private var authProvider: AuthenticationProvider?
    private var headers: [String: String] = [:]
    private let session: URLSession
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    private let maxRetries = 3
    private var userAgent: String?
    private(set) var protectedResourceMetadata: ProtectedResourceMetadata?
    private(set) var authorizationServerMetadata: AuthorizationServerMetadata?
    private let requestDeduplicator = RequestDeduplicator()

    /// Maps lexicon namespace prefixes to their service DIDs
    /// Example: "app.bsky" -> "did:web:api.bsky.app#bsky_appview"
    ///          "chat.bsky" -> "did:web:api.bsky.chat#bsky_chat"
    private var serviceDIDMapping: [String: String] = [:]

    /// Endpoints that should always use the default AppView DID (for preferences stored on PDS)
    private let alwaysDefaultAppViewEndpoints: Set<String> = [
        "app.bsky.actor.getPreferences",
        "app.bsky.actor.putPreferences",
    ]

    // MARK: - Initialization

    /// Initializes a new NetworkService with the specified base URL and authentication service.
    /// - Parameters:
    ///   - baseURL: The base URL for API requests.
    ///   - authService: The authentication service to use for authenticated requests.
    init(baseURL: URL, authService: AuthenticationProvider? = nil) {
        self.baseURL = baseURL
        authProvider = authService

        // Configure URL session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpShouldSetCookies = false

        // Add standard headers
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "X-Requested-With": "XMLHttpRequest",
        ]

        config.httpMaximumConnectionsPerHost = 5
        config.httpShouldUsePipelining = true

        // Create a session with a delegate for enhanced security
        let sessionDelegate = HardenedURLSessionDelegate()
        session = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)

        // Set JSON encoder settings
        jsonEncoder.keyEncodingStrategy = .useDefaultKeys
        jsonEncoder.dateEncodingStrategy = .iso8601

        // Set JSON decoder settings
        jsonDecoder.keyDecodingStrategy = .useDefaultKeys
        jsonDecoder.dateDecodingStrategy = .iso8601

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
    func setBaseURL(_ url: URL) async {
        baseURL = url
        LogManager.logInfo("Network Service - Base URL updated to: \(url)")
    }

    /// Sets a custom header for all requests.
    /// - Parameters:
    ///   - name: The header name.
    ///   - value: The header value.
    func setHeader(name: String, value: String) async {
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
    func removeHeader(name: String) async {
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
    func setUserAgent(_ userAgent: String) async {
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
    func setServiceDID(_ serviceDID: String, for namespace: String) async {
        serviceDIDMapping[namespace] = serviceDID
        LogManager.logDebug("Network Service - Set service DID '\(serviceDID)' for namespace '\(namespace)'")
    }

    /// Gets the service DID for a given endpoint, if configured
    /// - Parameter endpoint: The full endpoint (e.g., "app.bsky.feed.getTimeline")
    /// - Returns: The service DID if one is configured for this endpoint's namespace, nil otherwise
    func getServiceDID(for endpoint: String) async -> String? {
        // Special case: preferences endpoints always use default AppView DID
        if alwaysDefaultAppViewEndpoints.contains(endpoint) {
            // Return the app.bsky service DID (default AppView)
            return serviceDIDMapping["app.bsky"]
        }

        // Find the matching namespace prefix
        // Try longest match first (e.g., "chat.bsky" before "chat")
        let sortedPrefixes = serviceDIDMapping.keys.sorted { $0.count > $1.count }
        for prefix in sortedPrefixes {
            if endpoint.hasPrefix(prefix + ".") || endpoint == prefix {
                return serviceDIDMapping[prefix]
            }
        }

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
    func setAuthenticationProvider(_ provider: AuthenticationProvider) {
        authProvider = provider
    }

    enum EndpointType {
        case authorizationServer
        case protectedResource
        case other
    }

    func determineEndpointTypeAndAuthRequirement(for url: URL) -> (EndpointType, Bool) {
        if let authServerMetadata = authorizationServerMetadata,
           url.absoluteString.hasPrefix(authServerMetadata.issuer)
        {
            // Check if it's a token endpoint or other auth-related endpoint
            if url.absoluteString == authServerMetadata.tokenEndpoint
                || url.absoluteString == authServerMetadata.authorizationEndpoint
                || url.absoluteString == authServerMetadata.pushedAuthorizationRequestEndpoint
            {
                return (.authorizationServer, false) // Auth server endpoints typically don't need authentication
            } else {
                return (.authorizationServer, true) // Other auth server endpoints might need authentication
            }
        } else if let protectedResourceMetadata = protectedResourceMetadata,
                  url.absoluteString.hasPrefix(protectedResourceMetadata.resource.absoluteString)
        {
            return (.protectedResource, true) // Protected resources always need authentication
        } else {
            return (.other, false) // Default to not requiring authentication for other endpoints
        }
    }

    /// Performs a network request, determining authentication requirement based on endpoint type.
    /// - Parameter request: The URLRequest to perform.
    /// - Returns: A tuple containing the response data and URLResponse.
    /// - Note: This is a simplified version. For retries and advanced handling, use `request(_:skipTokenRefresh:)`.
    func request(_ request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else {
            throw NetworkError.invalidURL
        }

        let (_, requiresAuth) = determineEndpointTypeAndAuthRequirement(for: url)
        var requestToSend = request
        var authCtx_simple: AuthContext? = nil

        if requiresAuth {
            guard let authProvider = authProvider else {
                LogManager.logDebug(
                    "Authentication required for \(url.absoluteString) but no auth provider is set.")
                throw NetworkError.authenticationRequired
            }
            do {
                // Ensure token is fresh before preparing the request
                _ = try await authProvider.refreshTokenIfNeeded()
                let (authed, ctx) = try await authProvider.prepareAuthenticatedRequestWithContext(request)
                requestToSend = authed
                authCtx_simple = ctx
                LogManager.logDebug("Prepared authenticated request for: \(url.absoluteString)")
            } catch {
                LogManager.logError(
                    "Failed to prepare authenticated request for \(url.absoluteString): \(error)")
                // Propagate the specific authentication error or a generic one
                if error is AuthError {
                    throw error
                } else {
                    throw NetworkError.authenticationFailed
                }
            }
        } else {
            LogManager.logDebug("No authentication required for: \(url.absoluteString)")
        }

        // Perform the request using the internal session
        do {
            LogManager.logRequest(requestToSend)
            let (data, response) = try await session.data(for: requestToSend)
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
                    "Request to \(url.absoluteString) failed with status code: \(httpResponse.statusCode)")
                // Consider throwing a more specific error based on status code if needed here
                // For simplicity, just returning the response for now, letting caller handle.
            }
            return (data, response)
        } catch {
            LogManager.logError("Network request failed for \(url.absoluteString): \(error)")
            throw NetworkError.requestFailed // Or map to a more specific error
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
        let currentRequest = request
        var retryCount = 0

        while retryCount < maxRetries {
            var requestToSend = currentRequest
            var requiresAuth = false // Determine based on URL or context
            var authCtx: AuthContext? = nil

            // Determine if authentication is needed (simplified example)
            if let url = requestToSend.url,
               !url.absoluteString.contains("/.well-known/")
               && !url.absoluteString.contains("plc.directory")
               && !url.absoluteString.contains("/oauth/")
            {
                requiresAuth = true
            }

            // Add Authentication if required and provider exists
            if requiresAuth, let authProvider = authProvider {
                do {
                    // Attempt to refresh token first if not skipped
                    if !skipTokenRefresh {
                        _ = try await authProvider.refreshTokenIfNeeded()
                    }
                    let (authed, ctx) = try await authProvider.prepareAuthenticatedRequestWithContext(requestToSend)
                    requestToSend = authed
                    authCtx = ctx
                    LogManager.logDebug(
                        "Prepared authenticated request for: \(requestToSend.url?.absoluteString ?? "Unknown URL")"
                    )
                } catch AuthError.noActiveAccount {
                    LogManager.logError(
                        "No active account for authenticated request: \(requestToSend.url?.absoluteString ?? "Unknown URL"). Proceeding without authentication."
                    )
                    // Allow request to proceed without auth headers if no account exists
                } catch {
                    LogManager.logError("Network Service - Failed to prepare authenticated request: \(error)")
                    throw NetworkError.authenticationFailed
                }
            } else if requiresAuth {
                LogManager.logError(
                    "Authentication required but no provider set for: \(requestToSend.url?.absoluteString ?? "Unknown URL")"
                )
                // Decide whether to throw an error or allow the request without auth
                // throw NetworkError.authenticationProviderMissing
            }

            // Add custom headers
            for (name, value) in headers {
                requestToSend.setValue(value, forHTTPHeaderField: name)
            }

            // Add additional headers for this specific request
            if let additionalHeaders = additionalHeaders {
                for (name, value) in additionalHeaders {
                    requestToSend.setValue(value, forHTTPHeaderField: name)
                }
            }
            if let userAgent = userAgent {
                requestToSend.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            }

            // Perform the request with deduplication
            do {
                LogManager.logRequest(requestToSend)

                let request = requestToSend

                // Use deduplicator for non-refresh requests to prevent concurrent identical calls
                let (data, response) = if !skipTokenRefresh {
                    try await requestDeduplicator.deduplicate(request: request) { @Sendable in
                        return try await self.session.data(for: request)
                    }
                } else {
                    // Skip deduplication for refresh requests to avoid circular dependencies
                    try await session.data(for: requestToSend)
                }

                // Get data and ensure we have a valid HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    // Handle non-HTTP responses
                    LogManager.logError(
                        "Network Service - Received non-HTTP response for \(requestToSend.url?.absoluteString ?? "Unknown URL")"
                    )
                    throw NetworkError.invalidResponse
                }

                // Log the response
                LogManager.logResponse(httpResponse, data: data) // *** STORE NONCE IMMEDIATELY AFTER RECEIVING RESPONSE ***
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
                    return (data, httpResponse)

                case 401:
                    // Handle unauthorized (401)
                    guard let authProvider = authProvider, let url = requestToSend.url else {
                        LogManager.logError(
                            "Network Service - Received 401 but no auth provider or URL for \(requestToSend.url?.absoluteString ?? "Unknown URL")"
                        )
                        throw NetworkError.authenticationRequired // Cannot handle 401 without provider/URL
                    }

                    LogManager.logInfo(
                        "Network Service - Received 401 for \(url.absoluteString). Analyzing response."
                    )

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

                    if let errorResponse = try? jsonDecoder.decode(OAuthErrorResponse.self, from: data),
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
                                "Network Service - 401 error is 'use_dpop_nonce' (found in WWW-Authenticate).")
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
                                "Network Service - Nonce storage completed, proceeding with retry.")
                        }

                        // Limit nonce-based retry strictly to one attempt
                        if retryCount >= 1 {
                            LogManager.logError("Network Service - Already retried once for use_dpop_nonce; aborting further retries.")
                            throw NetworkError.maxRetryAttemptsReached
                        }
                        retryCount = 1
                        LogManager.logInfo(
                            "Network Service - Retrying request (\(retryCount)/\(maxRetries)) after storing DPoP nonce for \(url.absoluteString)."
                        )

                        continue // Continue to the next iteration of the while loop
                    } else if !skipTokenRefresh {
                        // If it's NOT a nonce error, and we're allowed to refresh, attempt standard token refresh via handleUnauthorizedResponse
                        LogManager.logInfo(
                            "Network Service - Attempting standard token refresh/handling for 401 on \(url.absoluteString)."
                        )
                        // If the 401 is due to invalid audience, set a one-shot resource override
                        do {
                            struct OAuthErrorResponse: Decodable { let error: String; let errorDescription: String?; enum CodingKeys: String, CodingKey { case error; case errorDescription = "error_description" } }
                            var isInvalidAudience = false
                            // First try JSON body (authorization server style)
                            if let err = try? jsonDecoder.decode(OAuthErrorResponse.self, from: data) {
                                let desc = err.errorDescription?.lowercased() ?? ""
                                isInvalidAudience = (err.error == "invalid_audience") || (err.error == "invalid_token" && desc.contains("invalid audience"))
                            }
                            // Also try WWW-Authenticate header from resource server
                            if !isInvalidAudience, let www = httpResponse.value(forHTTPHeaderField: "WWW-Authenticate")?.lowercased() {
                                // Example: DPoP error="invalid_token", error_description="invalid audience"
                                if www.contains("error=\"invalid_token\""), www.contains("invalid audience") { isInvalidAudience = true }
                                if www.contains("error=\"invalid_audience\"") { isInvalidAudience = true }
                            }
                            if isInvalidAudience, let scheme = url.scheme, let host = url.host {
                                let resource = "\(scheme)://\(host)"
                                LogManager.logInfo("Network Service - Preparing one-shot refresh for resource: \(resource)")
                                if let svc = self.authProvider as? AuthenticationService {
                                    await svc.setNextRefreshResourceOverride(resource)
                                }
                            }
                        }
                        do {
                            // Use the authProvider's handler (which should attempt refresh)
                            let (retryData, retryResponse) = try await authProvider.handleUnauthorizedResponse(
                                httpResponse, data: data, for: requestToSend
                            )
                            LogManager.logInfo(
                                "Network Service - Successfully handled non-nonce 401 via authProvider.")
                            return (retryData, retryResponse) // Return the result of the successful handling
                        } catch {
                            LogManager.logError(
                                "Network Service - authProvider failed to handle non-nonce 401: \(error). Giving up."
                            )
                            throw NetworkError.authenticationRequired // Throw if handling fails
                        }
                    } else {
                        // Is NOT a nonce error, but we are skipping token refresh (e.g., during refresh itself)
                        LogManager.logError(
                            "Network Service - Received non-nonce 401 but skipping refresh for \(url.absoluteString). Cannot proceed."
                        )
                        throw NetworkError.authenticationRequired // Cannot handle this 401
                    }

                // Return 400 responses to the caller for specific handling (like initial DPoP nonce during token exchange)
                case 400:
                    LogManager.logError(
                        "Network Service - Received 400 Bad Request for \(requestToSend.url?.absoluteString ?? "Unknown URL"). Returning to caller for specific handling."
                    )
                    return (data, httpResponse) // Return data and response for caller inspection

                case 402 ..< 500: // Other client errors
                    LogManager.logError(
                        "Network Service - Client error \(httpResponse.statusCode) for \(requestToSend.url?.absoluteString ?? "Unknown URL")"
                    )
                    throw NetworkError.responseError(statusCode: httpResponse.statusCode)

                case 500 ..< 600:
                    // Server errors - may be worth retrying
                    LogManager.logError(
                        "Network Service - Server error \(httpResponse.statusCode) for \(requestToSend.url?.absoluteString ?? "Unknown URL"). Retry \(retryCount + 1)/\(maxRetries)."
                    )
                    retryCount += 1
                    if retryCount >= maxRetries {
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
                        "Network Service - Unexpected status code \(httpResponse.statusCode) for \(requestToSend.url?.absoluteString ?? "Unknown URL")"
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
            "Network Service - Max retry attempts reached for \(currentRequest.url?.absoluteString ?? "Unknown URL")."
        )
        throw NetworkError.maxRetryAttemptsReached
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
            LogManager.logError("Network Service - Decoding error: \(error)")
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
            LogManager.logError("Network Service - Decoding error: \(error)")
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
    func createURLRequest(
        endpoint: String,
        method: String,
        headers: [String: String],
        body: Data?,
        queryItems: [URLQueryItem]?
    ) async throws -> URLRequest {
        // Construct the URL
        let url: URL
        if endpoint.lowercased().starts(with: "http") {
            // Absolute URL
            guard let absoluteURL = URL(string: endpoint) else {
                throw NetworkError.invalidURL
            }
            url = absoluteURL
        } else {
            // Relative endpoint to base URL
            let xrpcPath = endpoint.starts(with: "/") ? "xrpc\(endpoint)" : "xrpc/\(endpoint)"
            url = baseURL.appendingPathComponent(xrpcPath)
        }

        // Add query items if provided
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        if let queryItems = queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let finalURL = components?.url else {
            throw NetworkError.invalidURL
        }

        // Validate URL for security
        if !validateURL(finalURL) {
            LogManager.logError("Security validation failed for URL: \(finalURL). This may be due to DNS resolution to private IP ranges or network configuration issues.")
            throw NetworkError.securityViolation
        }

        // Create the request
        var request = URLRequest(url: finalURL)
        request.httpMethod = method

        // Add custom headers
        for (key, value) in self.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add request-specific headers
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
    func performRequest(_ request: URLRequest, skipTokenRefresh: Bool, additionalHeaders: [String: String]? = nil) async throws -> (
        Data, HTTPURLResponse
    ) {
        let (data, response) = try await self.request(request, skipTokenRefresh: skipTokenRefresh, additionalHeaders: additionalHeaders)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        return (data, httpResponse)
    }

    /// Performs a network request (protocol compatibility method)
    /// - Parameters:
    ///   - request: The URLRequest to perform.
    ///   - skipTokenRefresh: Whether to skip token refresh.
    /// - Returns: A tuple containing the response data and HTTPURLResponse.
    func performRequest(_ request: URLRequest, skipTokenRefresh: Bool) async throws -> (
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

    /// Validates the URL for security.
    /// - Parameter url: The URL to validate.
    /// - Returns: A boolean indicating whether the URL is valid.
    private func validateURL(_ url: URL) -> Bool {
        // Ensure only http or https schemes are allowed
        guard url.scheme == "https" || url.scheme == "http" else {
            LogManager.logError("Invalid URL scheme: \(url.scheme ?? "nil")")
            return false
        }

        // Resolve host and block private / loopback / link-local / unique-local ranges to mitigate SSRF
        guard let host = url.host, !host.isEmpty else { return false }

        // Quick check: if host is a literal IP, validate directly; otherwise resolve DNS
        let ips: [String]
        if IPv4Address(host) != nil || IPv6Address(host) != nil {
            ips = [host]
        } else {
            ips = resolveHostIPs(host: host)
        }

        if ips.isEmpty {
            LogManager.logError("Failed to resolve host: \(host)")
            return false
        }

        for ip in ips {
            if isPrivateOrReserved(ip: ip) {
                LogManager.logError("Blocked request to private/reserved IP: \(ip) for host \(host)")
                return false
            }
        }

        return true
    }

    // MARK: - SSRF Hardeners

    private func resolveHostIPs(host: String) -> [String] {
        var results: [String] = []
        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
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
                        let ip = String(cString: hostBuffer)
                        results.append(ip)
                    }
                }
                ptr = ai.ai_next
            }
            freeaddrinfo(head)
        }
        return results
    }

    private func isPrivateOrReserved(ip: String) -> Bool {
        // IPv4 checks
        if let v4 = IPv4Address(ip) {
            let octets = v4.rawValue
            let a = Int(octets[0])
            let b = Int(octets[1])

            // 10.0.0.0/8
            if a == 10 { return true }
            // 172.16.0.0/12 (172.16.0.0 - 172.31.255.255)
            if a == 172 && (16 ... 31).contains(b) { return true }
            // 192.168.0.0/16
            if a == 192 && b == 168 { return true }
            // 127.0.0.0/8 loopback
            if a == 127 { return true }
            // 169.254.0.0/16 link-local
            if a == 169 && b == 254 { return true }
            // 0.0.0.0/8 and 255.255.255.255 broadcast-like
            if a == 0 || a == 255 { return true }
        }

        // IPv6 checks
        if let v6 = IPv6Address(ip) {
            let bytes = v6.rawValue
            // ::1 loopback
            if bytes == Data(repeating: 0, count: 15) + Data([1]) { return true }
            // fe80::/10 link-local (1111 1110 10 ..)
            if (bytes[0] == 0xFE) && ((bytes[1] & 0xC0) == 0x80) { return true }
            // fc00::/7 unique local
            if (bytes[0] & 0xFE) == 0xFC { return true }
        }

        return false
    }
}

// Extension to help with task value extraction
extension Task where Success == Never, Failure == Never {
    // Use sleep(0) instead of recursively calling Task.yield()
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
