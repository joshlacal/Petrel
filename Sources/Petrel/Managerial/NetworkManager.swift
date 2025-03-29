//
//  NetworkManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/21/24.
//

import Foundation

// MARK: - NetworkManaging Protocol

/// Protocol defining the interface for NetworkManager.
protocol NetworkManaging: Actor {
    func setAuthenticationProvider(_ provider: AuthenticationProvider)
    func setAuthorizationServerMetadata(_ metadata: AuthorizationServerMetadata)

    func setProtectedResourceMetadata(_ metadata: ProtectedResourceMetadata)

    /// Notifies the network manager that the base URL has been updated
    func updateBaseURL(_ newBaseURL: URL) async

    /// Performs a network request.
    ///
    /// - Parameter request: The URLRequest to perform.
    /// - Returns: A tuple containing the response data and HTTPURLResponse.
    func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)

    /// Creates a URLRequest with the given parameters.
    ///
    /// - Parameters:
    ///   - endpoint: The API endpoint.
    ///   - method: The HTTP method (e.g., GET, POST).
    ///   - headers: Additional HTTP headers.
    ///   - body: The HTTP body data.
    ///   - queryItems: URL query parameters.
    /// - Returns: A configured URLRequest.
    func createURLRequest(
        endpoint: String,
        method: String,
        headers: [String: String],
        body: Data?,
        queryItems: [URLQueryItem]?
    ) async throws -> URLRequest

    /// Refreshes the session token using a provided refresh token and token manager.
    ///
    /// - Parameters:
    ///   - refreshToken: The refresh token used to obtain new access and refresh tokens.
    ///   - tokenManager: The token manager responsible for storing the new tokens.
    /// - Returns: A boolean indicating whether the token refresh was successful.
    /// - Throws: Throws an error if the token refresh fails.
    func refreshLegacySessionToken(refreshToken: String, tokenManager: TokenManaging) async throws -> Bool

    func setHeader(name: String, value: String)
    func getHeader(name: String) -> String?
    func removeHeader(name: String)
    func clearHeaders()

    // ATProto-specific header methods
    func setUserAgent(_ userAgent: String)
    func setProxyHeader(did: String, service: String)
    func setAcceptLabelers(_ labelers: [(did: String, redact: Bool)])
    func extractContentLabelers(from response: HTTPURLResponse) -> [(did: String, redact: Bool)]
}

// MARK: - NetworkManager Actor

/// Actor responsible for managing network requests and handling authentication.
actor NetworkManager: NetworkManaging {
    // MARK: - Properties

    private var baseURL: URL
    private var authorizationServerMetadata: AuthorizationServerMetadata?
    private var protectedResourceMetadata: ProtectedResourceMetadata?

    private let configurationManager: ConfigurationManaging
    private let maxRetryLimit: Int = 3

    private var middlewares: [NetworkMiddleware] = []
    private var isMiddlewareConfigured = false
    private var customHeaders: [String: String] = [:]
    private var userAgent: String?
    private var tokenManager: TokenManaging

    // Custom URLSession with hardened configuration
    private let session: URLSession
    private var accessTokenContinuation: CheckedContinuation<String, Error>?
    private var authProvider: AuthenticationProvider?

    enum EndpointType {
        case authorizationServer
        case protectedResource
        case other
    }

    func setAuthorizationServerMetadata(_ metadata: AuthorizationServerMetadata) {
        authorizationServerMetadata = metadata
    }

    func setProtectedResourceMetadata(_ metadata: ProtectedResourceMetadata) {
        protectedResourceMetadata = metadata
    }

    func determineEndpointTypeAndAuthRequirement(for url: URL) -> (EndpointType, Bool) {
        if let authServerMetadata = authorizationServerMetadata,
           url.absoluteString.hasPrefix(authServerMetadata.issuer)
        {
            // Check if it's a token endpoint or other auth-related endpoint
            if url.absoluteString == authServerMetadata.tokenEndpoint ||
                url.absoluteString == authServerMetadata.authorizationEndpoint ||
                url.absoluteString == authServerMetadata.pushedAuthorizationRequestEndpoint
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

    // MARK: - Initialization

    /// Initializes the NetworkManager with the specified base URL and configuration manager.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for the API.
    ///   - configurationManager: The ConfigurationManaging instance.
    init(baseURL: URL, configurationManager: ConfigurationManaging, tokenManager: TokenManaging) async {
        self.baseURL = baseURL
        self.configurationManager = configurationManager
        self.tokenManager = tokenManager

        // Initialize the custom URLSession
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = 30.0 // 30 seconds
        sessionConfiguration.timeoutIntervalForResource = 60.0 // 60 seconds
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfiguration.httpShouldSetCookies = false
        sessionConfiguration.httpAdditionalHeaders = [
            "X-Requested-With": "XMLHttpRequest",
            "Accept": "application/json",
        ]
        sessionConfiguration.httpMaximumConnectionsPerHost = 5
        sessionConfiguration.httpShouldUsePipelining = true

        // Initialize the custom delegate for security features
        let sessionDelegate = HardenedURLSessionDelegate()
        session = URLSession(configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: nil)

        // Subscribe to relevant events
//            await self.subscribeToEvents()
        LogManager.logDebug("Network Manager initialized")
    }

    // MARK: - Event Subscription

    private func subscribeToEvents() async {
        let eventStream = await EventBus.shared.subscribe()
        for await event in eventStream {
            switch event {
//            case .accessTokenFetched(let result):
//                handleAccessTokenResponse(result)
//            case .tokenRefreshCompleted(let result):
//                switch result {
//                case .success(let tokens):
//                    // Update stored tokens if needed
//                    LogManager.logInfo("Tokens refreshed successfully")
//                case .failure(let error):
//                    LogManager.logError("Token refresh failed: \(error)")
//                }
//            case .tokenExpired:
//                // Handle token expiration, possibly by triggering a refresh
//                LogManager.logInfo("Token expired, initiating refresh")
//                await EventBus.shared.publish(.tokenRefreshStarted)
//
//            case .authenticationRequired:
//                // Handle authentication required (e.g., pause requests, notify UI)
//                LogManager.logInfo("NetworkManager - Received authenticationRequired event.")
//
//            case .logMessage(let level, let message):
//                // Handle log messages if centralized logging is desired
//                // For example, send logs to a remote server or display in a debugging console
//                print("Log [\(level)]: \(message)")

            default:
                break
            }
        }
    }

    func setAuthenticationProvider(_ provider: AuthenticationProvider) {
        authProvider = provider
    }

    private func handleAccessTokenResponse(_ result: Result<String, Error>) {
        if let continuation = accessTokenContinuation {
            continuation.resume(with: result)
            accessTokenContinuation = nil
        }
    }

    private func fetchAccessToken() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            accessTokenContinuation = continuation
            Task {
                await EventBus.shared.publish(.accessTokenRequested)
            }
        }
    }

    // MARK: - BaseURLUpdateDelegate Protocol Method

    /// Updates the base URL when required.
    ///
    /// - Parameter newBaseURL: The new base URL to update.
    func updateBaseURL(_ newBaseURL: URL) async {
        baseURL = newBaseURL
        LogManager.logInfo("NetworkManager - Base URL updated to: \(newBaseURL)")
        // Optionally, you can reset or reconfigure session/middleware here
    }

    // MARK: - Header Management

    /// Sets a custom header to be included in all requests
    /// - Parameters:
    ///   - name: Header name
    ///   - value: Header value
    func setHeader(name: String, value: String) {
        LogManager.logDebug("NetworkManager - Setting header: \(name) = \(value)")
        customHeaders[name] = value
    }

    /// Gets the value of a custom header
    /// - Parameter name: Header name
    /// - Returns: Header value if it exists
    func getHeader(name: String) -> String? {
        return customHeaders[name]
    }

    /// Removes a custom header
    /// - Parameter name: Header name to remove
    func removeHeader(name: String) {
        LogManager.logDebug("NetworkManager - Removing header: \(name)")
        customHeaders.removeValue(forKey: name)
    }

    /// Clears all custom headers
    func clearHeaders() {
        LogManager.logDebug("NetworkManager - Clearing all custom headers")
        customHeaders.removeAll()
    }

    // MARK: - ATProto-Specific Headers

    /// Sets the User-Agent header
    /// - Parameter userAgent: The user agent string
    func setUserAgent(_ userAgent: String) {
        self.userAgent = userAgent
        setHeader(name: "User-Agent", value: userAgent)
    }

    /// Sets the atproto-proxy header for directing requests to specific services
    /// - Parameters:
    ///   - did: The DID of the target service
    ///   - service: The service identifier
    func setProxyHeader(did: String, service: String) {
        setHeader(name: "atproto-proxy", value: "\(did)#\(service)")
    }

    /// Sets the atproto-accept-labelers header with proper formatting
    /// - Parameter labelers: Array of tuples containing labeler DIDs and redaction flags
    func setAcceptLabelers(_ labelers: [(did: String, redact: Bool)]) {
        // Format according to RFC-8941 structured syntax
        let headerValue = labelers.map { labeler -> String in
            if labeler.redact {
                return "\(labeler.did);redact"
            } else {
                return labeler.did
            }
        }.joined(separator: ", ")

        if !headerValue.isEmpty {
            setHeader(name: "atproto-accept-labelers", value: headerValue)
        } else {
            // If empty, remove the header
            removeHeader(name: "atproto-accept-labelers")
        }
    }

    /// Extracts the content labelers from a response header
    /// - Parameter response: The HTTP response
    /// - Returns: Array of tuples containing labeler DIDs and redaction flags
    func extractContentLabelers(from response: HTTPURLResponse) -> [(did: String, redact: Bool)] {
        guard let contentLabelers = response.allHeaderFields["atproto-content-labelers"] as? String else {
            return []
        }

        return parseLabelerHeader(contentLabelers)
    }

    /// Helper to parse a labeler header value according to RFC-8941
    /// - Parameter header: The header value to parse
    /// - Returns: Array of tuples containing labeler DIDs and redaction flags
    private func parseLabelerHeader(_ header: String) -> [(did: String, redact: Bool)] {
        let components = header.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        return components.compactMap { component in
            let parts = component.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let did = parts.first, !did.isEmpty else { return nil }

            // Check if redact parameter is present
            let redact = parts.count > 1 && parts.contains("redact")

            return (did: String(did), redact: redact)
        }
    }

    // MARK: - Perform Request

    /// Performs a network request, applying authentication headers and handling token refresh if necessary.
    ///
    /// - Parameter request: The URLRequest to perform.
    /// - Returns: A tuple containing the response data and HTTPURLResponse.
    func performRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var currentRequest = request
        var retryCount = 0
        let maxRetries = 3

        while retryCount < maxRetries {
            do {
                // Always attempt to refresh tokens for OAuth
                if await tokenManager.hasAnyTokens() && authProvider is OAuthManager {
                    _ = try await authProvider?.refreshTokenIfNeeded()
                }

                // Prepare the authenticated request
                currentRequest = try await authProvider?.prepareAuthenticatedRequest(currentRequest) ?? currentRequest

                LogManager.logRequest(currentRequest)
                let (data, response) = try await session.data(for: currentRequest)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.requestFailed
                }
                LogManager.logResponse(httpResponse, data: data)

                if httpResponse.statusCode == 401 {
                    // Handle 401 errors, including DPoP nonce updates
                    if let authProvider = authProvider {
                        do {
                            let (retryData, retryResponse) = try await authProvider.handleUnauthorizedResponse(httpResponse, data: data, for: currentRequest)
                            LogManager.logResponse(retryResponse, data: retryData)
                            return (retryData, retryResponse)
                        } catch {
                            if retryCount == maxRetries - 1 {
                                throw error
                            }
                            retryCount += 1
                            continue
                        }
                    } else {
                        throw NetworkError.authenticationRequired
                    }
                }

                return (data, httpResponse)
            } catch {
                if retryCount == maxRetries - 1 {
                    throw error
                }
                retryCount += 1
                LogManager.logError("NetworkManager - Retry \(retryCount) due to error: \(error)")
            }
        }

        throw NetworkError.maxRetryAttemptsReached
    }

    /// Applies all configured middlewares to the given request.
    ///
    /// - Parameter request: The original URLRequest.
    /// - Returns: The modified URLRequest after passing through all middlewares.
    /// - Throws: An error if any middleware processing fails.
    private func applyMiddlewares(to request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        for middleware in middlewares {
            modifiedRequest = try await middleware.prepare(request: modifiedRequest)
        }
        return modifiedRequest
    }

    /// Applies all configured middlewares' handle methods to the response.
    ///
    /// - Parameters:
    ///   - response: The HTTPURLResponse received.
    ///   - data: The data received.
    ///   - request: The original URLRequest.
    /// - Returns: A tuple containing the possibly modified response and data.
    /// - Throws: An error if any middleware processing fails.
    private func applyMiddlewaresHandle(to response: HTTPURLResponse, data: Data, request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var currentResponse = response
        var currentData = data

        for middleware in middlewares {
            (currentResponse, currentData) = try await middleware.handle(response: currentResponse, data: currentData, request: request)
        }

        return (currentData, currentResponse)
    }

    // MARK: - Middleware Management

    /// Adds a middleware to the NetworkManager.
    ///
    /// - Parameter middleware: The middleware to add.
    func addMiddleware(_ middleware: NetworkMiddleware) async {
        middlewares.append(middleware)
    }

    /// Removes a middleware from the NetworkManager.
    ///
    /// - Parameter middleware: The middleware to remove.
    func removeMiddleware(_ middleware: NetworkMiddleware) async {
        middlewares.removeAll { $0 === middleware }
    }

    // MARK: - Create URLRequest

    /// Creates a URLRequest with the specified parameters.
    ///
    /// - Parameters:
    ///   - endpoint: The API endpoint.
    ///   - method: The HTTP method (e.g., GET, POST).
    ///   - headers: Additional HTTP headers.
    ///   - body: The HTTP body data.
    ///   - queryItems: URL query parameters.
    /// - Returns: A configured URLRequest.
    func createURLRequest(endpoint: String, method: String, headers: [String: String], body: Data?, queryItems: [URLQueryItem]?) async throws -> URLRequest {
        var url: URL
        if endpoint.lowercased().starts(with: "http://") || endpoint.lowercased().starts(with: "https://") {
            guard let endpointURL = URL(string: endpoint) else {
                throw NetworkError.invalidURL
            }
            url = endpointURL
        } else {
            let (endpointType, _) = determineEndpointTypeAndAuthRequirement(for: baseURL.appendingPathComponent(endpoint))
            switch endpointType {
            case .authorizationServer:
                if let issuer = authorizationServerMetadata?.issuer,
                   let issuerURL = URL(string: issuer)
                {
                    url = issuerURL.appendingPathComponent("xrpc").appendingPathComponent(endpoint)
                } else {
                    url = baseURL.appendingPathComponent("xrpc").appendingPathComponent(endpoint)
                }
            case .protectedResource:
                url = protectedResourceMetadata?.resource.appendingPathComponent("xrpc").appendingPathComponent(endpoint) ?? baseURL.appendingPathComponent("xrpc").appendingPathComponent(endpoint)
            case .other:
                url = baseURL.appendingPathComponent("xrpc").appendingPathComponent(endpoint)
            }
        }

        if let queryItems = queryItems, !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            components?.queryItems = queryItems
            url = components?.url ?? url
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        // Apply custom headers first
        for (key, value) in customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Then apply request-specific headers (which may override custom headers)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Set User-Agent if we have one and it wasn't specified in headers
        if let userAgent = userAgent, request.value(forHTTPHeaderField: "User-Agent") == nil {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }

        request.httpBody = body

        return request
    }

    // MARK: - Refresh Session Token

    /// Refreshes the session token using a provided refresh token and token manager.
    ///
    /// - Parameters:
    ///   - refreshToken: The refresh token used to obtain new access and refresh tokens.
    ///   - tokenManager: The token manager responsible for storing the new tokens.
    /// - Returns: A boolean indicating whether the token refresh was successful.
    /// - Throws: Throws an error if the token refresh fails.
    func refreshLegacySessionToken(refreshToken: String, tokenManager: TokenManaging) async throws -> Bool {
        let endpoint = "/xrpc/com.atproto.server.refreshSession"
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")

        // Perform the network request
        let (responseData, response) = try await performRequest(request)

        LogManager.logDebug("NetworkManager - Received response for token refresh with status code: \(response.statusCode)")

        if response.statusCode == 200 {
            let decoder = JSONDecoder()
            guard let tokenResponse = try? decoder.decode(ComAtprotoServerRefreshSession.Output.self, from: responseData) else {
                throw NetworkError.decodingError
            }

            // Get domain from the base URL
            let domain = baseURL.host

            // Pass domain when saving tokens
            try await tokenManager.saveTokens(
                accessJwt: tokenResponse.accessJwt,
                refreshJwt: tokenResponse.refreshJwt,
                type: .bearer,
                domain: domain
            )

            // Update user configuration with the new DID and service endpoint
            try await configurationManager.updateUserConfiguration(
                did: tokenResponse.did.didString(),
                handle: tokenResponse.handle.description,
                serviceEndpoint: tokenResponse.didDoc?.service.first?.serviceEndpoint ?? baseURL.absoluteString
            )

            // Publish token updated event
            await EventBus.shared.publish(.tokensUpdated(accessToken: tokenResponse.accessJwt, refreshToken: tokenResponse.refreshJwt))

            return true
        } else if response.statusCode == 401 {
            LogManager.logError("NetworkManager - Refresh token is invalid or expired")
            return false
        } else {
            LogManager.logError("NetworkManager - Failed to refresh token with status code: \(response.statusCode)")
            throw NetworkError.responseError(statusCode: response.statusCode)
        }
    }

    // MARK: - Utility Methods

    /// Validates the URL for security.
    ///
    /// - Parameter url: The URL to validate.
    /// - Returns: A boolean indicating whether the URL is valid.
    func validateURL(_ url: URL) -> Bool {
        // Ensure only http or https schemes are allowed
        guard url.scheme == "https" || url.scheme == "http" else {
            LogManager.logError("Invalid URL scheme: \(url.scheme ?? "nil")")
            return false
        }

        // Check for IP addresses that shouldn't be accessed
        if let host = url.host {
            let privateIPRanges = [
                "10.0.0.0/8",
                "172.16.0.0/12",
                "192.168.0.0/16",
                "127.0.0.0/8",
                "169.254.0.0/16",
            ]

            for range in privateIPRanges {
                if IPAddress(host)?.isInRange(range) == true {
                    LogManager.logError("Attempted access to private IP range: \(host)")
                    return false
                }
            }
        }

        // Additional validation checks can be added here

        return true
    }

    /// Sanitizes the input by removing or escaping potentially harmful characters.
    ///
    /// - Parameter input: The input string to sanitize.
    /// - Returns: The sanitized string, or nil if sanitization fails.
    func sanitizeInput(_ input: String) -> String? {
        // Remove or escape potentially harmful characters
        return input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }

    /// Validates the Content-Type of the HTTP response.
    ///
    /// - Parameters:
    ///   - response: The HTTPURLResponse to validate.
    ///   - expectedTypes: An array of expected Content-Type strings.
    /// - Returns: A boolean indicating whether the Content-Type is valid.
    func validateContentType(_ response: HTTPURLResponse, expectedTypes: [String]) throws {
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            LogManager.logError("Missing Content-Type header")
            throw NetworkError.badRequest(description: "Missing Content-Type header")
        }
        // Check if any of the expected types are contained within the Content-Type header
        let isValid = expectedTypes.contains { contentType.lowercased().contains($0.lowercased()) }
        if !isValid {
            LogManager.logError("Invalid Content-Type: \(contentType). Expected: \(expectedTypes.joined(separator: ", "))")
            throw NetworkError.badRequest(description: "Invalid Content-Type: \(contentType). Expected: \(expectedTypes.joined(separator: ", "))")
        }
    }

    /// Handles network errors by logging appropriate messages.
    ///
    /// - Parameter error: The error to handle.
    func handleNetworkError(_ error: Error) {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                LogManager.logError("Network Error: Request timed out")
            case .notConnectedToInternet:
                LogManager.logError("Network Error: No internet connection")
            case .cannotFindHost:
                LogManager.logError("Network Error: Cannot find host")
            case .cannotConnectToHost:
                LogManager.logError("Network Error: Cannot connect to host")
            case .dnsLookupFailed:
                LogManager.logError("Network Error: DNS lookup failed")
            case .networkConnectionLost:
                LogManager.logError("Network Error: Network connection lost")
            default:
                LogManager.logError("Network Error: \(urlError.localizedDescription)")
            }
        } else if let apiError = error as? APIError {
            switch apiError {
            case .expiredToken:
                LogManager.logError("API Error: Token has expired. Attempting to refresh the token.")
            case .invalidToken:
                LogManager.logError("API Error: Token is invalid. Possible tampering detected.")
            case .invalidResponse:
                LogManager.logError("API Error: Received an invalid response from the authentication server.")
            case .invalidPDSURL:
                LogManager.logError("API Error: The provided PDS URL is invalid or malformed.")
            case .authorizationFailed:
                LogManager.logError("API Error: Authorization failed. Check client credentials and permissions.")
            case .methodNotSupported:
                LogManager.logError("API Error: Method not supported.")
            case .serviceNotInitialized:
                LogManager.logError("API Error: AuthenticationService not initialized.")
            }
        } else {
            LogManager.logError("Unexpected Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Access Token Retrieval

    // MARK: - Helper Methods

    /// Handles a failed request by logging and publishing network error events.
    ///
    /// - Parameter error: The error encountered during the request.
    func handleFailedRequest(_ error: Error) {
        handleNetworkError(error)
        // Optionally, publish a network error event
        Task {
            await EventBus.shared.publish(.networkError(error))
        }
    }
}
