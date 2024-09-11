//
//  Middleware.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/21/24.
//

import Foundation
import os
internal import ZippyJSON

protocol NetworkMiddleware: Actor {
    func prepare(request: URLRequest) async throws -> URLRequest
    func handle(response: HTTPURLResponse, data: Data, request: URLRequest) async throws -> (
        HTTPURLResponse, Data
    )
}

actor AuthenticationMiddleware: NetworkMiddleware {
    private var middlewareService: MiddlewareService
    private var configurationManager: ConfigurationManaging

    init(middlewareService: MiddlewareService, configurationManager: ConfigurationManaging) {
        self.middlewareService = middlewareService
        self.configurationManager = configurationManager
    }

    func prepare(request: URLRequest) async throws -> URLRequest {
        LogManager.logDebug(
            "AuthenticationMiddleware - Preparing request for URL: \(request.url?.absoluteString ?? "unknown")"
        )
        var modifiedRequest = request
        // Check if the request is for refreshing session
        if request.url?.pathComponents.contains("com.atproto.server.refreshSession") == true {
            // This is a refresh session request, fetch and set the refresh token
            do {
                let refreshToken = try await middlewareService.getRefreshToken()
                modifiedRequest.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")
                LogManager.logDebug("Refresh token fetched and applied: \(refreshToken.prefix(10))...")
            } catch {
                LogManager.logError("AuthenticationMiddleware - Error fetching refresh token: \(error)")
                throw error
            }
        } else {
            // For other requests, ensure the session is valid and set the access token
            if !(await middlewareService.isSessionValid()) {
                try await middlewareService.validateAndRefreshSession()
            }
            let token = try await middlewareService.getAccessToken()
            modifiedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            LogManager.logDebug("Access token fetched and applied: \(token.prefix(10))...")
        }

        LogManager.logDebug(
            "Headers after setting Authorization: \(modifiedRequest.allHTTPHeaderFields ?? [:])")
        return modifiedRequest
    }

    func handle(response: HTTPURLResponse, data: Data, request: URLRequest) async throws -> (
        HTTPURLResponse, Data
    ) {
        LogManager.logDebug(
            "AuthenticationMiddleware - Handling response with status code: \(response.statusCode)")

        if response.statusCode == 401 {
            LogManager.logDebug(
                "AuthenticationMiddleware - 401 Unauthorized response received, attempting to refresh token."
            )
            try await middlewareService.validateAndRefreshSession()

            // Fetch the refreshed access token and retry the request
            let refreshedToken = try await middlewareService.getAccessToken()
            var retryRequest = request
            retryRequest.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")

            // Perform the request again with the refreshed token
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            return (retryResponse as! HTTPURLResponse, retryData)
        } else if response.statusCode == 200 {
            if request.url?.pathComponents.contains("com.atproto.server.refreshSession") == true {
                // If this is a successful response to a refresh session, parse the new tokens from the response
                try await handleRefreshSessionResponse(data: data)
            } else if request.url?.pathComponents.contains("com.atproto.server.createAccount") == true {
                // If this is a successful response to account creation, save the tokens and user info
                try await handleCreateAccountResponse(data: data)
            } else if request.url?.pathComponents.contains("com.atproto.server.createSession") == true {
                try await handleCreateSessionResponse(data: data)
            }
        }

        return (response, data)
    }

    private func handleRefreshSessionResponse(data: Data) async throws {
        do {
            let decoder = ZippyJSONDecoder()
            let refreshSessionOutput = try decoder.decode(
                ComAtprotoServerRefreshSession.Output.self, from: data
            )
            let currentEndpoint = await configurationManager.getServiceEndpoint()
            try await middlewareService.updateTokens(
                accessJwt: refreshSessionOutput.accessJwt, refreshJwt: refreshSessionOutput.refreshJwt
            )
            try await configurationManager.updateUserConfiguration(
                did: refreshSessionOutput.did,
                serviceEndpoint: refreshSessionOutput.didDoc?.service.first?.serviceEndpoint
                    ?? currentEndpoint
            )
        } catch {
            LogManager.logError("Failed to parse or update tokens after refresh: \(error)")
            throw error
        }
    }

    private func handleCreateAccountResponse(data: Data) async throws {
        do {
            let decoder = ZippyJSONDecoder()
            let createAccountOutput = try decoder.decode(
                ComAtprotoServerCreateAccount.Output.self, from: data
            )
            try await middlewareService.updateTokens(
                accessJwt: createAccountOutput.accessJwt, refreshJwt: createAccountOutput.refreshJwt
            )

            guard let serviceEndpoint = createAccountOutput.didDoc?.service.first?.serviceEndpoint else {
                throw NetworkError.noData
            }

            try await configurationManager.updateUserConfiguration(
                did: createAccountOutput.did,
                serviceEndpoint: serviceEndpoint
            )
            LogManager.logDebug(
                "Account created and tokens saved for user: \(createAccountOutput.handle)")
        } catch {
            LogManager.logError("Failed to parse or save account creation data: \(error)")
            throw error
        }
    }

    private func handleCreateSessionResponse(data: Data) async throws {
        do {
            let decoder = ZippyJSONDecoder()
            let createSessionOutput = try decoder.decode(
                ComAtprotoServerCreateSession.Output.self, from: data
            )
            try await middlewareService.updateTokens(
                accessJwt: createSessionOutput.accessJwt, refreshJwt: createSessionOutput.refreshJwt
            )

            guard let serviceEndpoint = createSessionOutput.didDoc?.service.first?.serviceEndpoint else {
                throw NetworkError.noData
            }

            try await configurationManager.updateUserConfiguration(
                did: createSessionOutput.did,
                serviceEndpoint: serviceEndpoint
            )
            LogManager.logDebug(
                "Session created and tokens saved for user: \(createSessionOutput.handle)")
        } catch {
            LogManager.logError("Failed to parse or save session creation data: \(error)")
            throw error
        }
    }
}

actor LoggingMiddleware: NetworkMiddleware {
    func prepare(request: URLRequest) -> URLRequest {
        // Log the request
        print("Request URL: \(request.url?.absoluteString ?? "Unknown URL")")
        print("HTTP Method: \(request.httpMethod ?? "No Method")")
        return request
    }

    func handle(response: HTTPURLResponse, data: Data, request _: URLRequest) -> (HTTPURLResponse, Data) {
        // Log the response
        print("Response Status Code: \(response.statusCode)")
        return (response, data)
    }
}
