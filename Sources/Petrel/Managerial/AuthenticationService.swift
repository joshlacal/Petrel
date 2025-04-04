//
//  AuthenticationService.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/24/24.
//

import Foundation

protocol TokenRefreshing: Actor {
    func refreshTokenIfNeeded() async throws -> Bool
}

protocol AuthenticationProvider: Sendable {
    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest
    func handleUnauthorizedResponse(_ response: HTTPURLResponse, data: Data, for request: URLRequest)
        async throws -> (Data, HTTPURLResponse)
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
    func handleUnauthorizedResponse(_ response: HTTPURLResponse, data: Data, for request: URLRequest)
        async throws -> (Data, HTTPURLResponse)

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
        Task {
            await self.subscribeToEvents()
        }
    }

    // MARK: - Event Subscription

    private func subscribeToEvents() async {
        let eventStream = await EventBus.shared.subscribe()
        for await event in eventStream {
            switch event {
            case .tokenExpired:
                // Attempt to refresh token when tokenExpired event is received
                Task {
                    do {
                        let refreshed = try await refreshTokenIfNeeded()
                        if refreshed {
                            LogManager.logInfo(
                                "AuthenticationService - Token refreshed successfully via EventBus.")
                        }
                    } catch {
                        LogManager.logError(
                            "AuthenticationService - Failed to refresh token via EventBus: \(error)")
                        // Publish authentication required event
                        await EventBus.shared.publish(.authenticationRequired)
                    }
                }
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

        // Determine if the request is to the token endpoint
        let authServerMetadata = await configurationManager.getAuthorizationServerMetadata()
        let isTokenEndpoint = authServerMetadata?.tokenEndpoint == request.url?.absoluteString

        switch authMethod {
        case .legacy:
            if let accessToken = await tokenManager.fetchAccessToken() {
                modifiedRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
        case .oauth:
            guard let accessToken = await tokenManager.fetchAccessToken() else {
                return request // If no access token, return the request as is
            }
            // Generate DPoP proof using OAuthManager
            let dpopProof =
                try await oauthManager?.generateDPoPProof(
                    for: modifiedRequest.httpMethod ?? "GET",
                    url: modifiedRequest.url?.absoluteString ?? "",
                    accessToken: isTokenEndpoint ? nil : accessToken // Pass nil for token endpoint
                ) ?? ""
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
    func handleUnauthorizedResponse(_ response: HTTPURLResponse, data: Data, for request: URLRequest)
        async throws -> (Data, HTTPURLResponse)
    {
        if let wwwAuthenticate = response.value(forHTTPHeaderField: "WWW-Authenticate"),
           wwwAuthenticate.contains("error=\"use_dpop_nonce\""),
           let newNonce = response.value(forHTTPHeaderField: "DPoP-Nonce"),
           let requestURL = request.url
        {
            LogManager.logInfo("Received use_dpop_nonce error, updating nonce and retrying")

            // Update the nonce for the request's domain
            await oauthManager?.updateDPoPNonce(for: requestURL, from: ["DPoP-Nonce": newNonce])

            // Prepare the request again with the updated nonce
            let retryRequest = try await prepareAuthenticatedRequest(request)
            LogManager.logRequest(retryRequest)

            // Perform the retry
            let (retryData, retryResponse) = try await networkManager.performRequest(retryRequest)

            if retryResponse.statusCode == 401 {
                // If the retry also fails, propagate the error
                LogManager.logError("Retry with updated DPoP nonce failed")
                throw NetworkError.authenticationRequired
            }

            return (retryData, retryResponse)
        } else if let wwwAuthenticate = response.value(forHTTPHeaderField: "WWW-Authenticate"),
                  wwwAuthenticate.contains("error=\"invalid_token\"")
        {
            // This could indicate an expired token, but we'll let the caller handle it
            LogManager.logError("Received invalid_token error")
            if try await refreshTokenIfNeeded() == true {
                // Retry the request with the new token
                let retryRequest = try await prepareAuthenticatedRequest(request)
                return try await networkManager.performRequest(retryRequest)
            } else {
                LogManager.logError("NetworkManager - Token refresh failed")
                throw NetworkError.authenticationRequired
            }
        } else {
            // If the error is not related to DPoP nonce or invalid token, propagate it
            LogManager.logError("Unexpected 401 error: \(String(data: data, encoding: .utf8) ?? "")")
            throw NetworkError.authenticationRequired
        }
    }

    private func startRefreshIfNotInProgress() -> Bool {
        guard !isRefreshing else { return false }
        isRefreshing = true
        return true
    }

    func refreshTokenIfNeeded() async throws -> Bool {
        guard await tokensExist() else {
            LogManager.logInfo("AuthenticationService - No tokens to refresh")
            return false
        }

        // Get the current access token and check if it's close to expiration
        if await tokenManager.fetchAccessToken() != nil {
            if await tokenManager.shouldRefreshTokens() {
                LogManager.logInfo("AuthenticationService - Access token near expiration, refreshing")
                return try await refreshTokens() // This now handles the locking
            }
        }

        return false
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
    
    public func startOAuthFlowForSignUp(pdsURL: URL) async throws -> URL {
        guard authMethod == AuthMethod.oauth, let oauthManager = oauthManager else {
            throw AuthenticationError.methodNotSupported
        }
        
        // Start OAuth flow without an identifier
        let authURL = try await oauthManager.startOAuthFlowForSignUp(pdsURL: pdsURL)
        await EventBus.shared.publish(.oauthFlowStarted(authURL))
        return authURL
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
            LogManager.logInfo("AuthenticationService - Handling OAuth callback")
            let (accessToken, refreshToken) = try await oauthManager.handleCallback(url: url)

            // Extract the DID from the token first
            guard let did = try? await extractDIDFromToken(accessToken) else {
                LogManager.logError("AuthenticationService - Failed to extract DID from access token")
                throw AuthenticationError.tokenMissingOrCorrupted
            }
            LogManager.logError("OAUTH_CALLBACK: Extracted DID from token: \(did)")

            // Resolve the PDS URL for this DID
            let pdsURL = try await didResolver.resolveDIDToPDSURL(did: did)
            LogManager.logError("OAUTH_CALLBACK: Resolved PDS URL for DID \(did): \(pdsURL)")

            // Save the tokens with the correct domain from the resolved PDS URL
            try await tokenManager.saveTokens(
                accessJwt: accessToken,
                refreshJwt: refreshToken,
                type: .dpop,
                domain: pdsURL.host // Use the resolved PDS URL's host instead of the current baseURL host
            )
            LogManager.logError(
                "OAUTH_CALLBACK: Saved tokens for DID \(did) with domain \(pdsURL.host ?? "unknown")")

            // Get the current handle
            let handle = await configurationManager.getHandle() ?? "unknown"

            // IMPORTANT: Before calling updateUserConfiguration, set the current DID in TokenManager
            // This ensures lastActiveDID is correctly set
            await tokenManager.setCurrentDID(did)
            LogManager.logError("OAUTH_CALLBACK: Set current DID in TokenManager to \(did)")

            // Update user configuration with the correct DID, handle, and service endpoint
            try await configurationManager.updateUserConfiguration(
                did: did,
                handle: handle,
                serviceEndpoint: pdsURL.absoluteString
            )

            // CRITICAL FIX: Use the DID-specific method to save the PDS URL
            // This ensures the PDS URL is saved with the correct DID even if configManager.did is currently set to a different value
            await configurationManager.updatePDSURL(pdsURL, forDID: did)
            LogManager.logError("OAUTH_CALLBACK: Saved PDS URL \(pdsURL) specifically for DID \(did)")

            // Update the NetworkManager's base URL to the resolved PDS URL
            await networkManager.updateBaseURL(pdsURL)

            // Publish events after successful authentication
            await EventBus.shared.publish(.baseURLUpdated(pdsURL))
            await EventBus.shared.publish(.pdsURLResolved(pdsURL))
            await EventBus.shared.publish(
                .oauthTokensReceived(accessToken: accessToken, refreshToken: refreshToken))

            LogManager.logInfo(
                "AuthenticationService - OAuth callback handled successfully. Tokens saved and user configuration updated."
            )
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

        // Atomic check-and-set for refresh state
        guard startRefreshIfNotInProgress() else {
            LogManager.logInfo("AuthenticationService - Refresh already in progress")
            return false
        }

        // Make sure we clear the flag when done
        defer { isRefreshing = false }

        do {
            switch authMethod {
            case .legacy:
                return try await refreshTokenIfNeededLegacy()
            case .oauth:
                return try await refreshOAuthTokens()
            }
        } catch {
            LogManager.logError("Token refresh failed: \(error)")
            throw error
        }
    }

    // MARK: - Legacy Authentication Methods

    /// Creates a new session using the provided identifier and password.
    ///
    /// - Parameters:
    ///   - identifier: The user's identifier (e.g., handle).
    ///   - password: The user's password.
    private func createSession(identifier: String, password: String) async throws {
        LogManager.logInfo(
            "AuthenticationService - Starting session creation for identifier: \(identifier)")

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
        LogManager.logDebug(
            "AuthenticationService - Received response with status code: \(response.statusCode)")

        guard response.statusCode == 200 else {
            LogManager.logError(
                "AuthenticationService - Failed to create session. Status code: \(response.statusCode)")
            throw NetworkError.requestFailed
        }

        // Decode the response
        let sessionOutput = try JSONDecoder().decode(
            ComAtprotoServerCreateSession.Output.self,
            from: data
        )
        LogManager.logInfo("AuthenticationService - Session created successfully. Tokens received.")

        // Save tokens with TokenType as `.bearer`
        try await tokenManager.saveTokens(
            accessJwt: sessionOutput.accessJwt,
            refreshJwt: sessionOutput.refreshJwt,
            type: .bearer,
            domain: configurationManager.baseURL.host
        )

        let baseURL = await configurationManager.baseURL.absoluteString
        // Update user configuration
        try await configurationManager.updateUserConfiguration(
            did: sessionOutput.did.didString(),
            handle: sessionOutput.handle.description,
            serviceEndpoint: sessionOutput.didDoc?.service.first?.serviceEndpoint ?? baseURL
        )

        LogManager.logInfo(
            "AuthenticationService - Tokens saved and user configuration updated successfully.")

        // Publish token updated event
        await EventBus.shared.publish(
            .tokensUpdated(accessToken: sessionOutput.accessJwt, refreshToken: sessionOutput.refreshJwt))
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
            LogManager.logError(
                "AuthenticationService - Refresh token has expired. User must re-authenticate.")
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
                await EventBus.shared.publish(
                    .tokensUpdated(accessToken: newAccessToken, refreshToken: newRefreshToken))
            }

            return true
        } else {
            LogManager.logError("AuthenticationService - Token refresh failed.")
            throw AuthenticationError.tokenRefreshFailed
        }
    }

    // MARK: - OAuth Authentication Methods

    private func refreshOAuthTokens() async throws -> Bool {
        guard let oauthManager = oauthManager,
              let refreshToken = await tokenManager.fetchRefreshToken()
        else {
            LogManager.logError(
                "AuthenticationService - Unable to refresh OAuth tokens: missing OAuth manager or refresh token"
            )
            throw AuthenticationError.tokenMissingOrCorrupted
        }

        do {
            LogManager.logInfo("AuthenticationService - Attempting to refresh OAuth tokens")
            let (newAccessToken, newRefreshToken) = try await oauthManager.refreshToken(
                refreshToken: refreshToken)

            // Get the domain from the current base URL
            let domain = await configurationManager.baseURL.host

            // Pass the domain when saving tokens
            try await tokenManager.saveTokens(
                accessJwt: newAccessToken,
                refreshJwt: newRefreshToken,
                type: .dpop,
                domain: domain
            )

            await EventBus.shared.publish(
                .tokensUpdated(accessToken: newAccessToken, refreshToken: newRefreshToken))
            LogManager.logInfo("AuthenticationService - OAuth tokens refreshed and saved successfully")
            return true
        } catch {
            LogManager.logError("AuthenticationService - Failed to refresh OAuth tokens: \(error)")
            throw error
        }
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

    private func handleUnauthorizedResponse(request: URLRequest, response: HTTPURLResponse) async
        -> URLRequest?
    {
        // Only process if this is an unauthorized response (401)
        guard response.statusCode == 401 else {
            return nil
        }

        // Get the DPoP nonce from the response headers if present
        if let headers = response.allHeaderFields as? [String: String],
           let url = response.url
        {
            // Fix ambiguous method call by specifying oauthManager
            await oauthManager?.updateDPoPNonce(for: url, from: headers)
        }

        // Attempt token refresh logic
        do {
            if try await refreshTokenIfNeeded() {
                // Get the fresh access token
                if let accessToken = await tokenManager.fetchAccessToken() {
                    // Clone the original request
                    var newRequest = request

                    // Generate a new DPoP proof with the updated nonce
                    if let url = newRequest.url?.absoluteString {
                        // Fix ambiguous method call by specifying oauthManager
                        let dpopProof = try await oauthManager?.generateDPoPProof(
                            for: newRequest.httpMethod ?? "GET",
                            url: url,
                            accessToken: accessToken
                        )

                        // Update the headers
                        newRequest.setValue(dpopProof, forHTTPHeaderField: "DPoP")
                        newRequest.setValue("DPoP \(accessToken)", forHTTPHeaderField: "Authorization")
                    }

                    return newRequest
                }
            }
        } catch {
            LogManager.logError("AuthenticationService - Failed to refresh token: \(error)")
        }

        return nil
    }

    // Other methods...

    private func processAuthenticatedResponse(response: HTTPURLResponse) async {
        // Update DPoP nonce if present
        if let url = response.url,
           let headers = response.allHeaderFields as? [String: String]
        {
            // Fix ambiguous method call by specifying oauthManager
            await oauthManager?.updateDPoPNonce(for: url, from: headers)
        }
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
