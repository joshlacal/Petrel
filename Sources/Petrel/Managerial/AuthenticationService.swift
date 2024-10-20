//
//  AuthenticationService.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/24/24.
//

import Foundation
import ZippyJSON

protocol TokenRefreshing: Actor {
    func refreshTokenIfNeeded() async throws -> Bool
}

protocol AuthenticationProvider: Sendable {
    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest
    func handleUnauthorizedResponse(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws -> (HTTPURLResponse, Data)
    func refreshTokenIfNeeded() async throws -> Bool
    func updateDPoPNonce(for url: URL, from headers: [String: String]) async
}

protocol AuthenticationServicing: Actor, TokenRefreshing, AuthenticationProvider {
    // MARK: - Authentication Methods

    /// Logs in a user using the provided identifier and password.
    ///
    /// - Parameters:
    ///   - identifier: The user's identifier (e.g., username or email).
    ///   - password: The user's password.
    /// - Throws: `AuthenticationError` if the login process fails.
    func login(identifier: String, password: String) async throws

    /// Initiates the OAuth authentication flow for the given identifier.
    ///
    /// - Parameter identifier: The user's identifier initiating the OAuth flow.
    /// - Returns: A `URL` to which the user should be redirected to complete OAuth authentication.
    /// - Throws: `AuthenticationError` if the OAuth flow cannot be started.
    func startOAuthFlow(identifier: String) async throws -> URL

    /// Handles the OAuth callback by processing the provided URL.
    ///
    /// - Parameter url: The callback URL received after OAuth authentication.
    /// - Throws: `AuthenticationError` if handling the OAuth callback fails.
    func handleOAuthCallback(url: URL) async throws

    /// Logs out the current user, clearing all session and token data.
    ///
    /// - Throws: `NetworkError` if the logout process fails.
    func logout() async throws

    // MARK: - Token Management

    /// Prepares an authenticated `URLRequest` by adding necessary authentication headers.
    ///
    /// - Parameter request: The original `URLRequest` to be authenticated.
    /// - Returns: A modified `URLRequest` with added authentication headers.
    /// - Throws: `OAuthError` or `NetworkError` if authentication headers cannot be added.
    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest

    /// Handles a `401 Unauthorized` HTTP response by updating the DPoP nonce and retrying the original request.
    ///
    /// - Parameters:
    ///   - response: The original `HTTPURLResponse` received.
    ///   - data: The data received with the original response.
    ///   - request: The original `URLRequest` that was made.
    /// - Returns: A tuple containing the new `HTTPURLResponse` and `Data` after retrying the request.
    /// - Throws: `NetworkError.authenticationRequired` if the retry also fails or if the error is not related to DPoP nonce.
    func handleUnauthorizedResponse(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws -> (HTTPURLResponse, Data)

    /// Deletes the DPoP key used for OAuth authentication.
    ///
    /// This is typically used during logout or when the DPoP key needs to be regenerated.
    func deleteDPoPKey() async

    /// Checks whether authentication tokens exist.
    ///
    /// - Returns: `true` if both access and refresh tokens exist; otherwise, `false`.
    func tokensExist() async -> Bool

    /// Refreshes the authentication token if needed.
    ///
    /// - Returns: `true` if the token was refreshed successfully; otherwise, `false`.
    /// - Throws: `AuthenticationError` if the token refresh process fails.
    func refreshTokenIfNeeded() async throws -> Bool
}

/// Actor responsible for handling both legacy and OAuth authentication flows.
actor AuthenticationService: Authenticator, TokenRefreshing, AuthenticationServicing {
    // MARK: - Properties

    private(set) var authMethod: AuthMethod
    private let networkManager: NetworkManaging
    private let tokenManager: TokenManaging
    private let configurationManager: ConfigurationManaging
    private let oauthConfig: OAuthConfiguration?
    private let didResolver: DIDResolving
    private var oauthManager: OAuthManager?
    private var isRefreshing = false
    private var lastRefreshTime: Date = .distantPast

    // MARK: - Initialization

    /// Initializes the AuthenticationService with required dependencies.
    ///
    /// - Parameters:
    ///   - authMethod: The authentication method to use (legacy or OAuth).
    ///   - networkManager: The network manager for performing requests.
    ///   - tokenManager: The token manager for handling token storage and retrieval.
    ///   - configurationManager: The configuration manager for user settings.
    ///   - oauthConfig: The OAuth configuration (required for OAuth authentication).
    ///   - didResolver: The DID resolver for resolving decentralized identifiers.
    ///   - namespace: The namespace used for token storage and other services.
    init(
        authMethod: AuthMethod,
        networkManager: NetworkManaging,
        tokenManager: TokenManaging,
        configurationManager: ConfigurationManaging,
        oauthConfig: OAuthConfiguration? = nil,
        didResolver: DIDResolving,
        namespace: String
    ) async {
        self.authMethod = authMethod
        self.networkManager = networkManager
        self.tokenManager = tokenManager
        self.configurationManager = configurationManager
        self.oauthConfig = oauthConfig
        self.didResolver = didResolver

        if authMethod == .oauth, let oauthConfig = oauthConfig {
            oauthManager = await OAuthManager(
                oauthConfig: oauthConfig,
                networkManager: networkManager,
                configurationManager: configurationManager,
                tokenManager: tokenManager,
                didResolver: didResolver,
                namespace: namespace
            )
        }

        // Subscribe to relevant events
//            await self.subscribeToEvents()
    }

    // MARK: - Event Subscription

    private func subscribeToEvents() async {
        let eventStream = await EventBus.shared.subscribe()
        for await event in eventStream {
            switch event {
//            case .tokenExpired:
//                // Attempt to refresh token when tokenExpired event is received
//                Task {
//                    do {
//                        let refreshed = try await refreshTokenIfNeeded()
//                        if refreshed {
//                            LogManager.logInfo("AuthenticationService - Token refreshed successfully via EventBus.")
//                        }
//                    } catch {
//                        LogManager.logError("AuthenticationService - Failed to refresh token via EventBus: \(error)")
//                        // Publish authentication required event
//                        await EventBus.shared.publish(.authenticationRequired)
//                    }
//                }
//
//            case .authenticationRequired:
//                // Handle authentication required event if needed
//                LogManager.logInfo("AuthenticationService - Received authenticationRequired event.")
//                // Possibly initiate re-authentication or notify UI
//
            default:
                break
            }
        }
    }

    func updateDPoPNonce(for url: URL, from headers: [String: String]) async {
        await oauthManager?.updateDPoPNonce(for: url, from: headers)
    }

    func deleteDPoPKey() async {
        await oauthManager?.deleteDPoPKey()
    }

    /// Prepares an authenticated request by adding necessary headers.
    ///
    /// - Parameter request: The original URLRequest.
    /// - Returns: A modified URLRequest with authentication headers.
    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request

        switch authMethod {
        case .legacy:
            if let accessToken = await tokenManager.fetchAccessToken() {
                modifiedRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
        case .oauth:
            guard let accessToken = await tokenManager.fetchAccessToken() else {
                return request // If no access token, let's just return the request and hope this is an unauthenticated request
            }
            // Generate DPoP proof using OAuthManager
            let dpopProof = try await oauthManager?.generateDPoPProof(for: modifiedRequest.httpMethod ?? "GET", url: modifiedRequest.url?.absoluteString ?? "", accessToken: accessToken) ?? ""
            modifiedRequest.setValue("DPoP \(accessToken)", forHTTPHeaderField: "Authorization")
            modifiedRequest.setValue(dpopProof, forHTTPHeaderField: "DPoP")
        }

        return modifiedRequest
    }

    /// Handles a 401 Unauthorized response by updating the DPoP nonce and retrying the request.
    ///
    /// - Parameters:
    ///   - response: The HTTPURLResponse received.
    ///   - data: The data received.
    ///   - request: The original URLRequest that was made.
    /// - Returns: A tuple containing the new HTTPURLResponse and Data.
    func handleUnauthorizedResponse(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws -> (HTTPURLResponse, Data) {
        if let wwwAuthenticate = response.value(forHTTPHeaderField: "WWW-Authenticate"),
           wwwAuthenticate.contains("error=\"use_dpop_nonce\""),
           let newNonce = response.value(forHTTPHeaderField: "DPoP-Nonce"),
           let requestURL = request.url
        {
            LogManager.logInfo("Received use_dpop_nonce error, updating nonce and retrying")

            // Update the nonce for the request's domain
            await oauthManager?.updateDPoPNonce(for: requestURL, from: ["DPoP-Nonce": newNonce])

            // Prepare the request again with the updated nonce
            var retryRequest = try await prepareAuthenticatedRequest(request)
            LogManager.logRequest(retryRequest)

            // Perform the retry
            let (retryData, retryResponse) = try await networkManager.performRequest(retryRequest)

            guard let retryHTTPResponse = retryResponse as? HTTPURLResponse else {
                throw NetworkError.requestFailed
            }

            if retryHTTPResponse.statusCode == 401 {
                // If the retry also fails, propagate the error
                LogManager.logError("Retry with updated DPoP nonce failed")
                throw NetworkError.authenticationRequired
            }

            return (retryHTTPResponse, retryData)
        } else if let wwwAuthenticate = response.value(forHTTPHeaderField: "WWW-Authenticate"),
                  wwwAuthenticate.contains("error=\"invalid_token\"")
        {
            // This could indicate an expired token, but we'll let the caller handle it
            LogManager.logError("Received invalid_token error")
            throw NetworkError.authenticationRequired
        } else {
            // If the error is not related to DPoP nonce or invalid token, propagate it
            LogManager.logError("Unexpected 401 error: \(String(data: data, encoding: .utf8) ?? "")")
            throw NetworkError.authenticationRequired
        }
    }

//    func refreshTokenIfNeeded() async throws -> Bool {
//        guard await tokensExist() else {
//            LogManager.logInfo("AuthenticationService - No tokens to refresh")
//            return false
//        }
//
//        if let accessToken = await tokenManager.fetchAccessToken() {
//            if await tokenManager.isTokenExpired(token: accessToken) {
//                LogManager.logInfo("AuthenticationService - Access token expired, refreshing")
//                return try await refreshTokens()
//            }
//            return false // Token is still valid
//        } else {
//            LogManager.logInfo("AuthenticationService - No access token, attempting refresh")
//            return try await refreshTokens()
//        }
//    }

    func refreshTokenIfNeeded() async throws -> Bool {
        guard await tokensExist() else {
            return false
        }

        // Prevent concurrent refreshes and limit refresh frequency
        guard !isRefreshing && Date().timeIntervalSince(lastRefreshTime) > 5 else {
            return false
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let refreshed = try await performTokenRefresh()
            if refreshed {
                lastRefreshTime = Date()
            }
            return refreshed
        } catch {
            throw AuthenticationError.tokenRefreshFailed
        }
    }

    private func performTokenRefresh() async throws -> Bool {
        if authMethod == .oauth {
            return try await refreshOAuthTokens()
        } else {
            return try await refreshTokenIfNeededLegacy()
        }
    }

    // MARK: - Authenticator Protocol Methods

    public func login(identifier: String, password: String) async throws {
        guard authMethod == AuthMethod.legacy else {
            throw AuthenticationError.methodNotSupported
        }
        try await createSession(identifier: identifier, password: password)
    }

    public func startOAuthFlow(identifier: String) async throws -> URL {
        guard authMethod == AuthMethod.oauth, let oauthManager = oauthManager else {
            throw AuthenticationError.methodNotSupported
        }
        await configurationManager.updateHandle(identifier)
        let authURL = try await oauthManager.startOAuthFlow(identifier: identifier)
        // Publish OAuth flow started event
        await EventBus.shared.publish(.oauthFlowStarted(authURL))
        return authURL
    }

    public func handleOAuthCallback(url: URL) async throws {
        guard authMethod == AuthMethod.oauth, let oauthManager = oauthManager else {
            throw AuthenticationError.methodNotSupported
        }

        do {
            let (accessToken, refreshToken) = try await oauthManager.handleCallback(url: url)

            // Save the tokens
            try await tokenManager.saveTokens(accessJwt: accessToken, refreshJwt: refreshToken, type: .dpop)

            // Update user configuration
            if let did = try? await extractDIDFromToken(accessToken), let handle = await configurationManager.getHandle() {
                let pdsURL = try await didResolver.resolveDIDToPDSURL(did: did)
                try await configurationManager.updateUserConfiguration(did: did, handle: handle, serviceEndpoint: pdsURL.absoluteString)

                // Store the PDS URL in the ConfigurationManager
                await configurationManager.updatePDSURL(pdsURL)
                await networkManager.updateBaseURL(pdsURL)

                // Update the NetworkManager's base URL to the PDS URL
                await EventBus.shared.publish(.baseURLUpdated(pdsURL))

                // Publish PDS URL resolved event
                await EventBus.shared.publish(.pdsURLResolved(pdsURL))
            }

            // Publish OAuth tokens received event
            await EventBus.shared.publish(.oauthTokensReceived(accessToken: accessToken, refreshToken: refreshToken))

            LogManager.logInfo("AuthenticationService - OAuth callback handled successfully. Tokens saved and user configuration updated.")
        } catch {
            LogManager.logError("Failed to handle OAuth callback: \(error)")
            // Publish OAuth flow failed event
            await EventBus.shared.publish(.oauthFlowFailed(error))
            throw error
        }
    }

    public func logout() async throws {
        switch authMethod {
        case .legacy:
            try await tokenManager.deleteTokens()
            // Additional logout steps if necessary
            // Publish logout succeeded event
            await EventBus.shared.publish(.logoutSucceeded)
        case .oauth:
            try await tokenManager.deleteTokens()
            // Additional OAuth-specific logout steps if necessary
            // Publish logout succeeded event
            await EventBus.shared.publish(.logoutSucceeded)
        }
    }

    func tokensExist() async -> Bool {
        let accessToken = await tokenManager.fetchAccessToken()
        let refreshToken = await tokenManager.fetchRefreshToken()

        return accessToken != nil && refreshToken != nil
    }

//    func refreshTokenIfNeeded() async throws -> Bool {
//        guard await tokensExist() else {
//            LogManager.logInfo("AuthenticationService - No tokens to refresh")
//            return false
//        }
//
//        if let accessToken = await tokenManager.fetchAccessToken() {
//            if await tokenManager.isTokenExpired(token: accessToken) {
//                LogManager.logInfo("AuthenticationService - Access token expired, refreshing")
//                return try await refreshTokens()
//            }
//            return false // Token is still valid
//        } else {
//            LogManager.logInfo("AuthenticationService - No access token, attempting refresh")
//            return try await refreshTokens()
//        }
//    }

//    func refreshTokenIfNeeded() async throws -> Bool {
//        guard await tokensExist() else {
//            LogManager.logInfo("AuthenticationService - No tokens to refresh")
//            return false
//        }
//
//        if let accessToken = await tokenManager.fetchAccessToken() {
//            if await tokenManager.isTokenExpired(token: accessToken) {
//                LogManager.logInfo("AuthenticationService - Access token expired, refreshing")
//                return try await refreshTokens()
//            }
//            return false // Token is still valid
//        } else {
//            LogManager.logInfo("AuthenticationService - No access token, attempting refresh")
//            return try await refreshTokens()
//        }
//    }

    func initializeOAuthState() async throws {
        if authMethod == .oauth {
            try await oauthManager?.initializeDPoPState()
        }
    }

    func refreshTokens() async throws -> Bool {
        // If tokens don't exist, return false (no refresh needed/possible)
        guard await tokensExist() else {
            return false
        }

        switch authMethod {
        case .legacy:
            return try await refreshTokenIfNeededLegacy()
        case .oauth:
            return try await refreshOAuthTokens()
        }
    }

    // MARK: - Legacy Authentication Methods

    /// Creates a new session using the provided identifier and password.
    ///
    /// - Parameters:
    ///   - identifier: The user's identifier (e.g., handle).
    ///   - password: The user's password.
    private func createSession(identifier: String, password: String) async throws {
        LogManager.logInfo("AuthenticationService - Starting session creation for identifier: \(identifier)")

        let endpoint = "/com.atproto.server.createSession"
        let body = try JSONEncoder().encode(
            ComAtprotoServerCreateSession.Input(identifier: identifier, password: password)
        )
        let headers = ["Content-Type": "application/json"]

        let request = try await networkManager.createURLRequest(
            endpoint: endpoint,
            method: "POST",
            headers: headers,
            body: body,
            queryItems: nil
        )

        // Perform the network request
        let (data, response) = try await networkManager.performRequest(request)
        LogManager.logDebug("AuthenticationService - Received response with status code: \(response.statusCode)")

        guard response.statusCode == 200 else {
            LogManager.logError("AuthenticationService - Failed to create session. Status code: \(response.statusCode)")
            throw NetworkError.requestFailed
        }

        // Decode the response
        let sessionOutput = try ZippyJSONDecoder().decode(
            ComAtprotoServerCreateSession.Output.self,
            from: data
        )
        LogManager.logInfo("AuthenticationService - Session created successfully. Tokens received.")

        // Save tokens with TokenType as `.bearer`
        try await tokenManager.saveTokens(
            accessJwt: sessionOutput.accessJwt,
            refreshJwt: sessionOutput.refreshJwt,
            type: .bearer
        )

        let baseURL = await configurationManager.baseURL.absoluteString
        // Update user configuration
        try await configurationManager.updateUserConfiguration(
            did: sessionOutput.did,
            handle: sessionOutput.handle,
            serviceEndpoint: sessionOutput.didDoc?.service.first?.serviceEndpoint ?? baseURL
        )

        LogManager.logInfo("AuthenticationService - Tokens saved and user configuration updated successfully.")

        // Publish token updated event
        await EventBus.shared.publish(.tokensUpdated(accessToken: sessionOutput.accessJwt, refreshToken: sessionOutput.refreshJwt))
    }

    /// Checks if the token needs to be refreshed and attempts to refresh it if necessary.
    ///
    /// - Returns: A boolean indicating whether the token was refreshed.
    /// - Throws: `AuthenticationError` if token refresh fails.
    private func refreshTokenIfNeededLegacy() async throws -> Bool {
        LogManager.logInfo("AuthenticationService - Checking if token refresh is needed.")

        // Fetch tokens from token manager
        guard let refreshToken = await tokenManager.fetchRefreshToken() else {
            LogManager.logError("AuthenticationService - Refresh token is missing.")
            throw AuthenticationError.tokenMissingOrCorrupted
        }

        guard let accessToken = await tokenManager.fetchAccessToken() else {
            LogManager.logError("AuthenticationService - Access token is missing. Attempting to refresh.")
            return try await attemptLegacyTokenRefresh(refreshToken: refreshToken)
        }

        // Decode tokens to check validity and expiration
        guard let refreshPayload = await tokenManager.decodeJWT(token: refreshToken),
              let accessPayload = await tokenManager.decodeJWT(token: accessToken)
        else {
            LogManager.logError("AuthenticationService - Failed to decode tokens.")
            throw AuthenticationError.tokenMissingOrCorrupted
        }

        let currentDate = Date()

        // Check if refresh token is still valid
        if let refreshExp = refreshPayload.exp, refreshExp > currentDate {
            // Refresh token is valid; check access token
            if let accessExp = accessPayload.exp {
                if accessExp < currentDate {
                    // Access token has expired; attempt to refresh
                    LogManager.logInfo("AuthenticationService - Access token expired. Attempting to refresh.")
                    return try await attemptLegacyTokenRefresh(refreshToken: refreshToken)
                } else {
                    // Access token is still valid
                    LogManager.logInfo("AuthenticationService - Access token is still valid.")
                    return false
                }
            } else {
                // Missing access token expiration; assume expired
                LogManager.logError("AuthenticationService - Access token expiration date is missing.")
                return try await attemptLegacyTokenRefresh(refreshToken: refreshToken)
            }
        } else {
            // Refresh token has expired
            LogManager.logError("AuthenticationService - Refresh token has expired. User must re-authenticate.")
            throw AuthenticationError.tokenExpired
        }
    }

    /// Attempts to refresh the access token using the legacy endpoint and provided refresh token.
    ///
    /// - Parameter refreshToken: The refresh token.
    /// - Returns: A boolean indicating whether the token refresh was successful.
    /// - Throws: An error if the token refresh fails.
    private func attemptLegacyTokenRefresh(refreshToken: String) async throws -> Bool {
        LogManager.logInfo("AuthenticationService - Attempting to refresh tokens.")

        // Perform token refresh via NetworkManager
        let success = try await networkManager.refreshLegacySessionToken(
            refreshToken: refreshToken,
            tokenManager: tokenManager
        )

        if success {
            LogManager.logInfo("AuthenticationService - Tokens refreshed successfully.")

            // Fetch updated tokens
            if let newAccessToken = await tokenManager.fetchAccessToken(),
               let newRefreshToken = await tokenManager.fetchRefreshToken()
            {
                // Publish token updated event
                await EventBus.shared.publish(.tokensUpdated(accessToken: newAccessToken, refreshToken: newRefreshToken))
            }

            return true
        } else {
            LogManager.logError("AuthenticationService - Token refresh failed.")
            throw AuthenticationError.tokenRefreshFailed
        }
    }

    // MARK: - OAuth Authentication Methods

//    private func refreshTokenIfNeededOAuth() async throws -> Bool {
//        LogManager.logInfo("AuthenticationService - Checking if OAuth token refresh is needed.")
//
//        guard let refreshToken = await tokenManager.fetchRefreshToken() else {
//            LogManager.logInfo("AuthenticationService - No refresh token available. OAuth flow may not have been completed.")
//            return false // Return false instead of throwing an error
//        }
//
//        guard let oauthManager = oauthManager else {
//            throw AuthenticationError.methodNotSupported
//        }
//
//        do {
//            let (newAccessToken, newRefreshToken) = try await oauthManager.refreshToken(refreshToken: refreshToken)
//            try await tokenManager.saveTokens(accessJwt: newAccessToken, refreshJwt: newRefreshToken, type: .dpop)
//            LogManager.logInfo("AuthenticationService - OAuth token refreshed successfully.")
//
//            // Publish token updated event
//            await EventBus.shared.publish(.tokensUpdated(accessToken: newAccessToken, refreshToken: newRefreshToken))
//
//            return true
//        } catch {
//            LogManager.logError("AuthenticationService - OAuth token refresh failed: \(error)")
//            throw AuthenticationError.tokenRefreshFailed
//        }
//    }

//    private func refreshTokenIfNeededOAuth() async throws -> Bool {
//        guard let oauthManager = oauthManager,
//              let refreshToken = await tokenManager.fetchRefreshToken() else {
//            throw AuthenticationError.tokenMissingOrCorrupted
//        }
//
//        do {
//            LogManager.logInfo("AuthenticationService - Refreshing OAuth tokens to update DPoP proof")
//            let (newAccessToken, newRefreshToken) = try await oauthManager.refreshToken(refreshToken: refreshToken)
//            try await tokenManager.saveTokens(accessJwt: newAccessToken, refreshJwt: newRefreshToken, type: .dpop)
//            LogManager.logInfo("AuthenticationService - OAuth tokens refreshed successfully")
//            await EventBus.shared.publish(.tokensUpdated(accessToken: newAccessToken, refreshToken: newRefreshToken))
//            return true
//        } catch {
//            LogManager.logError("AuthenticationService - OAuth token refresh failed: \(error)")
//            throw AuthenticationError.tokenRefreshFailed
//        }
//    }

    private func refreshOAuthTokens() async throws -> Bool {
        guard let oauthManager = oauthManager,
              let refreshToken = await tokenManager.fetchRefreshToken()
        else {
            throw AuthenticationError.tokenMissingOrCorrupted
        }

        let (newAccessToken, newRefreshToken) = try await oauthManager.refreshToken(refreshToken: refreshToken)
        try await tokenManager.saveTokens(accessJwt: newAccessToken, refreshJwt: newRefreshToken, type: .dpop)
        await EventBus.shared.publish(.tokensUpdated(accessToken: newAccessToken, refreshToken: newRefreshToken))
        return true
    }

    // MARK: - Utility Methods

    /// Extracts the DID from the access token.
    ///
    /// - Parameter token: The access token.
    /// - Returns: The extracted DID.
    private func extractDIDFromToken(_ token: String) async throws -> String {
        // Decode the JWT to extract the 'sub' claim which should contain the DID
        guard let payload = await tokenManager.decodeJWT(token: token),
              let did = payload.sub,
              did.starts(with: "did:")
        else {
            LogManager.logError("AuthenticationService - 'sub' claim is missing or invalid in token.")
            throw AuthenticationError.tokenMissingOrCorrupted
        }
        LogManager.logDebug("AuthenticationService - Extracted DID from token: \(did)")
        return did
    }
}

// MARK: - Error Definitions

public enum AuthenticationError: Error {
    case methodNotSupported
    case invalidCredentials
    case tokenRefreshFailed
    case invalidOAuthConfiguration
    case tokenMissingOrCorrupted
    case tokenExpired
}
