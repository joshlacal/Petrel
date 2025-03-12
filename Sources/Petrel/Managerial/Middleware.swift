//
//  Middleware.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/21/24.
//

import Foundation
import os


protocol NetworkMiddleware: Actor {
    /// Prepares the request by adding necessary modifications (e.g., authentication headers).
    ///
    /// - Parameter request: The original URLRequest.
    /// - Returns: A modified URLRequest.
    func prepare(request: URLRequest) async throws -> URLRequest

    /// Handles the response, performing any necessary actions based on the response status.
    ///
    /// - Parameters:
    ///   - response: The HTTPURLResponse received.
    ///   - data: The data received.
    ///   - request: The original URLRequest.
    /// - Returns: A tuple containing the possibly modified response and data.
    func handle(response: HTTPURLResponse, data: Data, request: URLRequest) async throws -> (HTTPURLResponse, Data)
}

actor AuthenticationMiddleware: NetworkMiddleware {
    private var authenticationService: AuthenticationService
    private var isRetrying: Bool = false
    private let whitelistedEndpoints: [String]

    init(authenticationService: AuthenticationService) async {
        self.authenticationService = authenticationService
        whitelistedEndpoints = [
            "/xrpc/com.atproto.server.describeServer",
            "/.well-known/oauth-authorization-server",
            // Add other necessary endpoints
        ]
    }

    func prepare(request: URLRequest) async throws -> URLRequest {
        guard let url = request.url else {
            throw NetworkError.invalidURL
        }

        // Check if the endpoint is whitelisted
        if whitelistedEndpoints.contains(where: { url.path.hasSuffix($0) }) {
            return request
        }

        // Check if tokens exist
        if await authenticationService.tokensExist() {
            // Tokens exist, proceed with normal flow
            return try await authenticationService.prepareAuthenticatedRequest(request)
        } else {
            // No tokens, allow request without authentication
            return request
        }
    }

    func handle(response: HTTPURLResponse, data: Data, request: URLRequest) async throws -> (HTTPURLResponse, Data) {
        if response.statusCode == 401 {
            // Avoid infinite retry loops
            guard !isRetrying else {
                throw NetworkError.authenticationRequired
            }

            // Delegate response handling to AuthenticationService
            do {
                isRetrying = true
                let (retryResponse, retryData) = try await authenticationService.handleUnauthorizedResponse(response, data: data, for: request)
                isRetrying = false
                return (retryData, retryResponse)
            } catch {
                isRetrying = false
                throw error
            }
        }

        // For all other responses, proceed as is
        return (response, data)
    }

    private func subscribeToEvents() async {
        let eventStream = await EventBus.shared.subscribe()
        for await event in eventStream {
            switch event {
//        case .tokensUpdated(let accessToken, let refreshToken):
//            // Handle token updates if needed
//            LogManager.logDebug("AuthenticationMiddleware - Received tokensUpdated event.")
//            // Possibly perform additional actions, like updating headers or caches
//
//        case .authenticationRequired:
//            // Handle authentication required event if needed
//            LogManager.logInfo("AuthenticationMiddleware - Received authenticationRequired event.")
//            // Possibly notify UI or trigger re-authentication flow

            default:
                break
            }
        }
    }
}

// MARK: - LoggingMiddleware Actor

actor LoggingMiddleware: NetworkMiddleware {
    // MARK: - Initialization

    init() async {
        // Subscribe to log message events if you choose to centralize logging
//        await self.subscribeToEvents()
    }

    // MARK: - NetworkMiddleware Protocol Methods

    func prepare(request: URLRequest) async throws -> URLRequest {
        // Option 1: Continue using LogManager for logging
        LogManager.logInfo("LoggingMiddleware - Request URL: \(request.url?.absoluteString ?? "Unknown URL")")
        LogManager.logInfo("LoggingMiddleware - HTTP Method: \(request.httpMethod ?? "No Method")")
        if let headers = request.allHTTPHeaderFields {
            LogManager.logInfo("LoggingMiddleware - Headers: \(headers)")
        }
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            LogManager.logInfo("LoggingMiddleware - Body: \(bodyString)")
        }
        return request

        // Option 2: Publish log events via EventBus
        /*
         var logMessage = "LoggingMiddleware - Request URL: \(request.url?.absoluteString ?? "Unknown URL")\n"
         logMessage += "HTTP Method: \(request.httpMethod ?? "No Method")\n"
         if let headers = request.allHTTPHeaderFields {
             logMessage += "Headers: \(headers)\n"
         }
         if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
             logMessage += "Body: \(bodyString)"
         }
         await EventBus.shared.publish(.logMessage(level: .debug, message: logMessage))
         return request
         */
    }

    func handle(response: HTTPURLResponse, data: Data, request: URLRequest) async throws -> (HTTPURLResponse, Data) {
        // Option 1: Continue using LogManager for logging
        LogManager.logInfo("LoggingMiddleware - Response Status Code: \(response.statusCode)")
        if let headers = response.allHeaderFields as? [String: Any] {
            LogManager.logInfo("LoggingMiddleware - Response Headers: \(headers)")
        }
        if let responseBody = String(data: data, encoding: .utf8) {
            LogManager.logInfo("LoggingMiddleware - Response Body: \(responseBody)")
        }
        return (response, data)

        // Option 2: Publish log events via EventBus
        /*
         var logMessage = "LoggingMiddleware - Response Status Code: \(response.statusCode)\n"
         if let headers = response.allHeaderFields as? [String: Any] {
             logMessage += "Response Headers: \(headers)\n"
         }
         if let responseBody = String(data: data, encoding: .utf8) {
             logMessage += "Response Body: \(responseBody)"
         }
         await EventBus.shared.publish(.logMessage(level: .debug, message: logMessage))
         return (response, data)
         */
    }

    // MARK: - Event Subscription (Optional)

    private func subscribeToEvents() async {
        let eventStream = await EventBus.shared.subscribe()
        for await event in eventStream {
            switch event {
            case let .logMessage(level, message):
                // Handle log messages if you choose to centralize logging
                // For example, send logs to a remote server or display in a debugging console
                print("Log [\(level)]: \(message)")

            default:
                break
            }
        }
    }
}
