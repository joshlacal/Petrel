//
//  MiddlewareService.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/24/24.
//

import Foundation

protocol MiddlewareServicing: Actor {
    // MARK: - Session Validation and Refreshing

    /// Determines whether tokens should be refreshed.
    ///
    /// - Returns: A boolean indicating if token refresh is necessary.
    func shouldRefreshTokens() async -> Bool

    /// Checks if the current session is valid.
    ///
    /// - Returns: A boolean indicating whether the session is valid.
    func isSessionValid() async -> Bool

    /// Validates the session and attempts to refresh it if necessary.
    ///
    /// - Throws: `NetworkError.authenticationRequired` if session validation or refreshing fails.
    func validateAndRefreshSession() async throws

    // MARK: - Token Management

    /// Retrieves the current access token, refreshing the session if the token is expired.
    ///
    /// - Returns: The valid access token as a `String`.
    /// - Throws: `NetworkError.authenticationRequired` if token retrieval or session refreshing fails.
    func getAccessToken() async throws -> String

    /// Retrieves the current refresh token.
    ///
    /// - Returns: The refresh token as a `String`.
    /// - Throws: `NetworkError.authenticationRequired` if token retrieval fails.
    func getRefreshToken() async throws -> String

    // MARK: - Session Management

    /// Clears the current session, including tokens and session data.
    ///
    /// - Throws: `NetworkError.authenticationRequired` if session clearing fails.
    func clearSession() async throws

    // MARK: - Configuration Methods

    /// Sets the session manager responsible for handling user sessions.
    ///
    /// - Parameter sessionManager: An object conforming to `SessionManaging`.
    func setSessionManager(_ sessionManager: SessionManaging)
}

actor MiddlewareService: MiddlewareServicing {
    // MARK: - Properties

    private var sessionManager: SessionManaging?
    private let tokenManager: TokenManaging

    // MARK: - Initialization

    init(
        tokenManager: TokenManaging
    ) async {
        self.tokenManager = tokenManager

        // Subscribe to relevant events
//            await self.subscribeToEvents()
    }

    // MARK: - Session Validation and Refreshing

    func shouldRefreshTokens() async -> Bool {
        await tokenManager.shouldRefreshTokens()
    }

    /// Checks if the current session is valid.
    ///
    /// - Returns: A boolean indicating whether the session is valid.
    func isSessionValid() async -> Bool {
        guard let sessionManager = sessionManager else {
            LogManager.logError("MiddlewareService - SessionManager is not set.")
            return false
        }
        return await sessionManager.isUserLoggedIn()
    }

    /// Validates the session and attempts to refresh it if necessary.
    ///
    /// - Throws: An error if session validation or refreshing fails.
    func validateAndRefreshSession() async throws {
        guard let sessionManager = sessionManager else {
            LogManager.logError("MiddlewareService - SessionManager is not set.")
            throw NetworkError.authenticationRequired
        }

        if await tokenManager.shouldRefreshTokens() {
            LogManager.logDebug("MiddlewareService - Token refresh needed.")
            await EventBus.shared.publish(.tokenExpired)
        } else {
            LogManager.logDebug("MiddlewareService - Session is valid, no refresh needed.")
        }
    }

    // MARK: - Token Management

    /// Retrieves the current access token, refreshing the session if the token is expired.
    ///
    /// - Returns: The valid access token.
    /// - Throws: An error if token retrieval or session refreshing fails.
    func getAccessToken() async throws -> String {
        LogManager.logDebug("MiddlewareService - Fetching access token.")

        guard let token = await tokenManager.fetchAccessToken() else {
            LogManager.logInfo("MiddlewareService - Access token not available, publishing tokenExpired event.")
            await EventBus.shared.publish(.tokenExpired)
            throw NetworkError.authenticationRequired
        }

        if await tokenManager.shouldRefreshTokens() {
            LogManager.logInfo("MiddlewareService - Token refresh needed, publishing tokenExpired event.")
            await EventBus.shared.publish(.tokenExpired)
            throw NetworkError.authenticationRequired
        }

        LogManager.logDebug("MiddlewareService - Access token fetched successfully.")
        return token
    }

    /// Retrieves the current refresh token.
    ///
    /// - Returns: The refresh token.
    /// - Throws: An error if token retrieval fails.
    func getRefreshToken() async throws -> String {
        LogManager.logDebug("MiddlewareService - Fetching refresh token.")

        guard let token = await tokenManager.fetchRefreshToken() else {
            LogManager.logError("MiddlewareService - No refresh token available.")
            throw NetworkError.authenticationRequired
        }

        LogManager.logDebug("MiddlewareService - Refresh token fetched successfully.")
        return token
    }

    // MARK: - Helper Methods

    /// Clears the current session.
    ///
    /// - Throws: An error if session clearing fails.
    func clearSession() async throws {
        LogManager.logInfo("MiddlewareService - Clearing session.")
        try await tokenManager.deleteTokens()
        guard let sessionManager = sessionManager else {
            LogManager.logError("MiddlewareService - SessionManager is not set.")
            throw NetworkError.authenticationRequired
        }
//        try await sessionManager.clearSession()
        LogManager.logInfo("MiddlewareService - Session cleared successfully.")

        // Publish sessionExpired event
        await EventBus.shared.publish(.sessionExpired)
    }

    // MARK: - Event Subscription

    private func subscribeToEvents() async {
        let eventStream = await EventBus.shared.subscribe()
        for await event in eventStream {
            switch event {
//            case .tokensUpdated(let accessToken, let refreshToken):
//                // Handle token updates if needed
//                LogManager.logDebug("MiddlewareService - Received tokensUpdated event.")
//                // Possibly perform additional actions, like updating headers
//
//            case .tokenExpired:
//                // Handle token expired event by initiating session refresh
//                LogManager.logInfo("MiddlewareService - Received tokenExpired event. Initiating session refresh.")
//                Task {
//                    do {
//                        try await validateAndRefreshSession()
//                    } catch {
//                        LogManager.logError("MiddlewareService - Failed to refresh session: \(error)")
//                        // Optionally publish an authentication required event
//                        await EventBus.shared.publish(.authenticationRequired)
//                    }
//                }
//
//            case .sessionExpired:
//                // Handle session expired event if needed
//                LogManager.logInfo("MiddlewareService - Received sessionExpired event.")

            default:
                break
            }
        }
    }

    // MARK: - Configuration Methods

    func setSessionManager(_ sessionManager: SessionManaging) {
        self.sessionManager = sessionManager
    }
}
