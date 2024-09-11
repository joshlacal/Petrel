//
//  AuthenticationService.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/24/24.
//

import Foundation
internal import ZippyJSON

protocol OAuthHandling: Actor {
    func startOAuthFlow(identifier: String) async throws -> URL
    func handleOAuthCallback(url: URL) async throws
}

actor AuthenticationService {
    private var networkManager: NetworkManaging
    private var tokenManager: TokenManaging
    private var configurationManager: ConfigurationManaging
    private weak var oauthHandler: OAuthHandling?

    init(
        networkManager: NetworkManaging,
        tokenManager: TokenManaging,
        configurationManager: ConfigurationManaging
    ) {
        self.networkManager = networkManager
        self.tokenManager = tokenManager
        self.configurationManager = configurationManager
    }

    func setOAuthHandler(_ handler: OAuthHandling) {
        oauthHandler = handler
    }

    func createSession(identifier: String, password: String) async throws {
        LogManager.logInfo(
            "AuthenticationService - Starting session creation for identifier: \(identifier)")
        let endpoint = "/com.atproto.server.createSession"
        let body = try JSONEncoder().encode(
            ComAtprotoServerCreateSession.Input(identifier: identifier, password: password))
        let headers = ["Content-Type": "application/json"]
        let request = try await networkManager.createURLRequest(
            endpoint: endpoint, method: "POST", headers: headers, body: body, queryItems: nil
        )

        // Perform the request without applying middleware
        let (data, response) = try await networkManager.performRequest(
            request, retryCount: 0, duringInitialSetup: true
        )
        LogManager.logDebug(
            "AuthenticationService - Request performed, received status code: \(response.statusCode)")

        guard response.statusCode == 200 else {
            LogManager.logError(
                "AuthenticationService - Failed to create session, received status code: \(response.statusCode)"
            )
            throw NetworkError.requestFailed
        }
        let sessionOutput = try ZippyJSONDecoder().decode(
            ComAtprotoServerCreateSession.Output.self, from: data
        )
        LogManager.logInfo("AuthenticationService - Session created successfully, tokens received.")
        let currentEndpoint = await configurationManager.getServiceEndpoint()
        try await tokenManager.saveTokens(
            accessJwt: sessionOutput.accessJwt, refreshJwt: sessionOutput.refreshJwt
        )
        try await configurationManager.updateUserConfiguration(
            did: sessionOutput.did,
            serviceEndpoint: sessionOutput.didDoc?.service.first?.serviceEndpoint ?? currentEndpoint
        )

        LogManager.logInfo("AuthenticationService - Tokens saved successfully.")
    }

    func authenticateWithOAuth(identifier: String) async throws {
        guard let handler = oauthHandler else {
            throw AuthenticationError.oauthHandlerNotSet
        }

        let authorizationURL = try await handler.startOAuthFlow(identifier: identifier)
        // Here, you would typically open this URL in the user's browser or a web view
        // The app should then handle the callback URL
        print("Please authorize the app by opening this URL: \(authorizationURL)")
        // In a real app, you'd wait for the callback to be received
    }

    func handleOAuthCallback(url: URL) async throws {
        guard let handler = oauthHandler else {
            throw AuthenticationError.oauthHandlerNotSet
        }

        try await handler.handleOAuthCallback(url: url)
        // The handler has now updated its state with the new tokens
    }

    public enum AuthenticationError: Error {
        case tokenMissingOrCorrupted
        case tokenExpired
        case oauthHandlerNotSet
    }

    func refreshTokenIfNeeded() async throws -> Bool {
        LogManager.logInfo("AuthenticationService - Checking if token refresh is needed.")

        // Fetch tokens from token manager
        guard let refreshToken = await tokenManager.fetchRefreshToken() else {
            LogManager.logError("AuthenticationService - Refresh token is missing.")
            throw AuthenticationError.tokenMissingOrCorrupted
        }

        guard let accessToken = await tokenManager.fetchAccessToken() else {
            LogManager.logError(
                "AuthenticationService - Access token is missing, will attempt to refresh.")
            return try await attemptTokenRefresh(refreshToken: refreshToken)
        }

        // Decode tokens to check their validity and expiration
        let refreshPayload = await tokenManager.decodeJWT(token: refreshToken)
        let accessPayload = await tokenManager.decodeJWT(token: accessToken)

        // Check if the refresh token itself has expired
        if let refreshPayload = refreshPayload,
           refreshPayload.exp.value.timeIntervalSinceNow >= 0
        {
            // Refresh token is still valid, proceed to check access token
            if let accessPayload = accessPayload,
               accessPayload.exp.value.timeIntervalSinceNow < 0
            {
                // Access token has expired, refresh it
                LogManager.logInfo("AuthenticationService - Access token expired, attempting to refresh.")
                return try await attemptTokenRefresh(refreshToken: refreshToken)
            } else {
                // Access token is still valid
                LogManager.logInfo("AuthenticationService - Access token is still valid.")
                return false
            }
        } else {
            // Refresh token has expired, throw an error to signal re-authentication is needed
            LogManager.logError(
                "AuthenticationService - Refresh token has expired, user must re-authenticate.")
            throw AuthenticationError.tokenExpired
        }
    }

    private func attemptTokenRefresh(refreshToken: String) async throws -> Bool {
        if try await networkManager.refreshSessionToken(
            refreshToken: refreshToken, tokenManager: tokenManager
        ) {
            LogManager.logInfo("Tokens refreshed successfully.")
            return true
        }
        return false
    }

    //    func refreshTokenIfNeeded() async throws -> Bool {
    //        LogManager.logInfo("Attempting to refresh tokens due to server indication.")
    //        guard let refreshToken = await tokenManager.fetchRefreshToken() else {
    //            LogManager.logError("No refresh token available.")
    //            throw NetworkError.authenticationRequired // You can define this error to handle such cases.
    //        }
    //
    //        if await tokenManager.shouldRefreshTokens() {  // Decide based on previous logic or modify accordingly
    //            do {
    //                // Assume refreshTokenProcess() does the actual refreshing and handles updates
    //                if try await networkManager.refreshSessionToken(refreshToken: refreshToken, tokenManager: tokenManager) {
    //                    LogManager.logInfo("Tokens refreshed successfully.")
    //                    return true
    //                }
    //            } catch {
    //                LogManager.logError("Token refresh failed: \(error)")
    //                throw error
    //            }
    //        }
    //        return false
    //    }
}
