//
//  NetworkManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/21/24.
//

import Foundation
internal import ZippyJSON

protocol NetworkManaging: Actor, BaseURLUpdateDelegate {
    func performRequest(_ request: URLRequest, retryCount: Int, duringInitialSetup: Bool) async throws
        -> (Data, HTTPURLResponse)
    func createURLRequest(
        endpoint: String, method: String, headers: [String: String], body: Data?,
        queryItems: [URLQueryItem]?
    ) async throws -> URLRequest
    func refreshSessionToken(refreshToken: String, tokenManager: TokenManaging) async throws -> Bool
    func setMiddlewareService(middlewareService: MiddlewareService) async
}

public actor NetworkManager: NetworkManaging, BaseURLUpdateDelegate {
    private var baseURL: URL
    private let configurationManager: ConfigurationManaging
    private let maxRetryLimit: Int = 3

    private var middlewares: [NetworkMiddleware] = []
    var middlewareService: MiddlewareService?
    private var isMiddlewareConfigured = false
    
    var oauthManager: OAuthManager?

    init(baseURL: URL, configurationManager: ConfigurationManaging) {
        self.baseURL = baseURL
        self.configurationManager = configurationManager
    }

    func setOAuthManager(oauthManager: OAuthManager) {
        self.oauthManager = oauthManager
    }
    
    func setMiddlewareService(middlewareService: MiddlewareService) {
        self.middlewareService = middlewareService
        configureMiddlewares()
        isMiddlewareConfigured = true
    }

    func baseURLDidUpdate(_ newBaseURL: URL) async {
        baseURL = newBaseURL
    }

    private func configureMiddlewares() {
        if let middlewareService = middlewareService {
            let authMiddleware = AuthenticationMiddleware(
                middlewareService: middlewareService, configurationManager: configurationManager
            )
            let loggingMiddleware = LoggingMiddleware()
            middlewares.append(loggingMiddleware)
            middlewares.append(authMiddleware)
        } else {
            // Handle the case where middlewareService is nil, maybe log an error or set up a fallback
            print("Error: MiddlewareService is nil")
        }
    }

    public func createURLRequest(
        endpoint: String, method: String, headers: [String: String], body: Data?,
        queryItems: [URLQueryItem]?
    ) async throws -> URLRequest {
        var url = baseURL.appendingPathComponent("xrpc").appendingPathComponent(endpoint)
        if let queryItems = queryItems, !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            if let urlFromComponents = components?.url {
                url = urlFromComponents
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        for (headerField, headerValue) in headers {
            request.setValue(headerValue, forHTTPHeaderField: headerField)
        }

        if let authHeader = headers["Authorization"] {
            LogManager.logDebug("Using Authorization Header: \(authHeader.prefix(30))")
        }

        // Set the body if provided and ensure correct Content-Type
        if let body = body {
            request.httpBody = body
            if headers["Content-Type"] == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        request.httpBody = body

        return request
    }

    public func performRequest(
        _ request: URLRequest, retryCount: Int = 0, duringInitialSetup: Bool = false
    ) async throws -> (Data, HTTPURLResponse) {
        while !isMiddlewareConfigured {
            await Task.yield()
        }

        LogManager.logDebug(
            "NetworkManager - Preparing to perform request to \(request.url?.absoluteString ?? "unknown URL") with retryCount: \(retryCount)"
        )
        LogManager.logRequest(request)

        // Apply middleware conditionally
        var modifiedRequest = request
        if !duringInitialSetup {
            for middleware in middlewares {
                LogManager.logDebug("Applying middleware: \(type(of: middleware))")
                modifiedRequest = try await middleware.prepare(request: modifiedRequest)
            }
        } else {
            LogManager.logDebug("Skipping middleware during initial setup.")
        }
        LogManager.logDebug(
            "NetworkManager - Middleware modified request to \(request.url?.absoluteString ?? "unknown URL") with retryCount: \(retryCount)"
        )
        LogManager.logRequest(modifiedRequest)

        do {
            // Perform the actual network request
            let (data, response) = try await URLSession.shared.data(for: modifiedRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.requestFailed
            }

            LogManager.logDebug(
                "NetworkManager - Received HTTP response with status code: \(httpResponse.statusCode) from \(httpResponse.url?.absoluteString ?? "unknown URL")"
            )
            LogManager.logResponse(httpResponse, data: data)

            // Process the response through each middleware
            var finalData = data
            var finalResponse = httpResponse
            for middleware in middlewares.reversed() {
                (finalResponse, finalData) = try await middleware.handle(
                    response: finalResponse, data: finalData, request: modifiedRequest
                )
                LogManager.logDebug(
                    "NetworkManager - Middleware \(type(of: middleware)) processed the response.")
            }
            LogManager.logResponse(finalResponse, data: finalData)

            // Retry logic for 401 Unauthorized response
            if finalResponse.statusCode == 401 && retryCount < maxRetryLimit {
                LogManager.logDebug(
                    "NetworkManager - Received 401 status, attempting to retry request. Retry attempt: \(retryCount + 1)"
                )
                return try await performRequest(modifiedRequest, retryCount: retryCount + 1) // Ensuring modifiedRequest is used for retry
            }

            LogManager.logDebug(
                "NetworkManager - Request to \(finalResponse.url?.absoluteString ?? "unknown URL") completed successfully with status code \(finalResponse.statusCode)"
            )
            return (finalData, finalResponse)
        } catch {
            LogManager.logError(
                "NetworkManager - Request to \(modifiedRequest.url?.absoluteString ?? "unknown URL") failed with error: \(error.localizedDescription)"
            )
            throw error
        }
    }
    
    func performRequestWithDPoP(endpoint: String, method: String, headers: [String: String], body: Data?, queryItems: [URLQueryItem]?) async throws -> (Data, HTTPURLResponse) {
        guard let oauthManager = self.oauthManager else {
            throw NetworkError.oauthManagerNotSet
        }
        
        var retries = 0
        while retries < 3 {
            do {
                let dpopProof = try await oauthManager.createDPoPProof(for: method, url: endpoint)
                var updatedHeaders = headers
                updatedHeaders["DPoP"] = dpopProof
                
                let request = try await createURLRequest(
                    endpoint: endpoint,
                    method: method,
                    headers: updatedHeaders,
                    body: body,
                    queryItems: queryItems
                )
                
                let (data, response) = try await performRequest(request, retryCount: 0, duringInitialSetup: false)
                
                await oauthManager.updateDPoPNonce(from: response.allHeaderFields as? [String: String] ?? [:])
                    
                if response.statusCode == 401 {
                        // Token might be expired, try to refresh
                        if retries == 0 {
                            try await middlewareService?.validateAndRefreshSession()
                            retries += 1
                            continue
                        }
                    }
                
                return (data, response)
            } catch {
                if retries >= 2 {
                    throw error
                }
                retries += 1
            }
        }
        throw NetworkError.maxRetryAttemptsReached
    }
    
    func refreshSessionToken(refreshToken: String, tokenManager: TokenManaging) async throws -> Bool {
        let endpoint = "/xrpc/com.atproto.server.refreshSession"
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")

        // Perform the network request
        let (responseData, response) = try await performRequest(
            request, retryCount: 0, duringInitialSetup: true
        )

        LogManager.logDebug(
            "NetworkManager - Received response for token refresh with status code: \(response.statusCode)"
        )

        if response.statusCode == 200 {
            // Decode the response using your specific output structure
            let decoder = ZippyJSONDecoder()
            guard
                let tokenResponse = try? decoder.decode(
                    ComAtprotoServerRefreshSession.Output.self, from: responseData
                )
            else {
                throw NetworkError.decodingError
            }

            // Update stored tokens using the token manager
            try await tokenManager.saveTokens(
                accessJwt: tokenResponse.accessJwt, refreshJwt: tokenResponse.refreshJwt
            )
            try await configurationManager.updateUserConfiguration(
                did: tokenResponse.did,
                serviceEndpoint: tokenResponse.didDoc?.service.first?.serviceEndpoint
                    ?? baseURL.absoluteString
            )
            return true
        } else if response.statusCode == 401 {
            LogManager.logError("NetworkManager - Refresh token is invalid or expired")
            return false
        } else {
            LogManager.logError(
                "NetworkManager - Failed to refresh token with status code: \(response.statusCode)")

            throw NetworkError.responseError(statusCode: response.statusCode)
        }
    }

    private func prepareRequestWithMiddleware(_ request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        // Assume middleware array
        for middleware in middlewares {
            modifiedRequest = try await middleware.prepare(request: modifiedRequest)
        }
        return modifiedRequest
    }
}
