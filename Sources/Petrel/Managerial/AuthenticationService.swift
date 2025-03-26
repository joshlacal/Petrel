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
    func handleUnauthorizedResponse(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws -> (Data, HTTPURLResponse)
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
    func handleUnauthorizedResponse(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws -> (Data, HTTPURLResponse)

    /// Deletes the DPoP key used for OAuth authentication.
    ///
    /// This is typically used during logout or when the DPoP key needs to be regenerated.
    func deleteDPoPKey() async

    /// Checks whether authentication tokens exist for the active account.
    ///
    /// - Returns: `true` if both access and refresh tokens exist; otherwise, `false`.
    func tokensExist() async -> Bool

    /// Refreshes the authentication token if needed for the active account.
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
    private let accountManager: AccountManaging // Added
    private let sessionManager: SessionManaging
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
    ///   - accountManager: The account manager for handling multiple accounts.
    ///   - oauthConfig: The OAuth configuration (required for OAuth authentication).
    ///   - didResolver: The DID resolver for resolving decentralized identifiers.
    init(
        authMethod: AuthMethod,
        networkManager: NetworkManaging,
        tokenManager: TokenManaging,
        configurationManager: ConfigurationManaging,
        accountManager: AccountManaging, // Added
        oauthConfig: OAuthConfiguration? = nil,
        didResolver: DIDResolving,
        sessionManager: SessionManaging
    ) async {
        self.authMethod = authMethod
        self.networkManager = networkManager
        self.tokenManager = tokenManager
        self.configurationManager = configurationManager
        self.accountManager = accountManager // Added
        self.oauthConfig = oauthConfig
        self.didResolver = didResolver
        self.sessionManager = sessionManager

        if authMethod == .oauth, let oauthConfig = oauthConfig {
            oauthManager = await OAuthManager(
                oauthConfig: oauthConfig,
                networkManager: networkManager,
                configurationManager: configurationManager,
                tokenManager: tokenManager,
                didResolver: didResolver,
                accountManager: accountManager // Pass AccountManager
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
                            LogManager.logInfo("AuthenticationService - Token refreshed successfully via EventBus.")
                        }
                    } catch {
                        LogManager.logError("AuthenticationService - Failed to refresh token via EventBus: \(error)")
                        // Publish authentication required event
                        await EventBus.shared.publish(.authenticationRequired)
                    }
                }
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
            let dpopProof = try await oauthManager?.generateDPoPProof(
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
    func handleUnauthorizedResponse(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
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
        if let accessToken = await tokenManager.fetchAccessToken() {
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

            // Extract DID from token FIRST
            let did = try await extractDIDFromToken(accessToken)
            
            // Get handle from config (set during startOAuthFlow)
            let handle = await configurationManager.getHandle()
            
            // Resolve PDS URL
            let pdsURL = try await didResolver.resolveDIDToPDSURL(did: did)

            // Create AccountData
            let accountData = AccountData(did: did, handle: handle, pdsURL: pdsURL, isActive: false) // Start as inactive
            
            // Add/Update account in AccountManager BEFORE switching
            try await accountManager.addOrUpdateAccount(accountData)
            
            // Save the tokens BEFORE switching the active account
            // This ensures tokens are saved under the correct (potentially new) namespace
            // Temporarily switch context for saving tokens if needed, or ensure TokenManager uses the provided DID
            // Let's assume TokenManager can save for a specific DID without switching the global active one yet.
            // If not, we need a way to save tokens for a specific DID.
            // For now, let's switch first, then save, accepting the potential race condition was the issue.
            
            // Switch to the newly authenticated account - THIS TRIGGERS STATE RELOAD
            try await accountManager.switchAccount(to: did)
            
            // NOW save the tokens. TokenManager will use the *newly active* DID as namespace.
            try await tokenManager.saveTokens(
                accessJwt: accessToken,
                refreshJwt: refreshToken,
                type: .dpop,
                domain: pdsURL.host // Use PDS URL host as domain
            )

            // Update user configuration (this might be redundant now, handled by AccountManager/ConfigManager listening to events)
            // Ensure config manager updates for the *now active* account
            try await configurationManager.updateUserConfiguration(did: did, handle: handle ?? "", serviceEndpoint: pdsURL.absoluteString)
            await networkManager.updateBaseURL(pdsURL) // Ensure network manager uses the correct PDS

            // Publish events
            await EventBus.shared.publish(.baseURLUpdated(pdsURL)) // Maybe redundant if ATProtoClient handles this on account switch
            await EventBus.shared.publish(.pdsURLResolved(pdsURL)) // Maybe redundant
            await EventBus.shared.publish(.oauthTokensReceived(accessToken: accessToken, refreshToken: refreshToken))

            // Explicitly set session state to authenticated AFTER tokens are saved and account switched
            await sessionManager.setAuthenticatedState(true)

            LogManager.logInfo("AuthenticationService - OAuth callback handled successfully. Account \(did) added/updated and activated. Tokens saved. Session state set to true.")
        } catch {
            LogManager.logError("Failed to handle OAuth callback: \(error)")
            // Publish OAuth flow failed event
            await EventBus.shared.publish(.oauthFlowFailed(error))
            throw error
        }
    }

    public func logout() async throws {
        guard let activeDID = await accountManager.getActiveAccountDID() else {
            LogManager.logInfo("AuthenticationService - Logout called but no active account.")
            return // No active account to log out
        }

        LogManager.logInfo("AuthenticationService - Logging out account: \(activeDID)")

        // Clear tokens for the active account
        try await tokenManager.deleteTokens()

        // Delete DPoP key if OAuth
        if authMethod == .oauth {
            await oauthManager?.deleteDPoPKey()
        }

        // Remove the account from the manager
        // This will also trigger a switch to another account if available
        do {
            try await accountManager.removeAccount(did: activeDID)
            LogManager.logInfo("AuthenticationService - Account \(activeDID) removed.")
        } catch AccountManagerError.cannotRemoveLastAccount {
            // If it's the last account, don't remove it, just clear its state
            LogManager.logInfo("AuthenticationService - Last account logged out. Clearing state but keeping account entry.")
            // Tokens and DPoP key already cleared.
            // Optionally clear other Keychain data associated with this DID if needed.
            // We might need a method in AccountManager to just deactivate without removing.
            // For now, leaving the inactive account entry might be acceptable.
        } catch {
            LogManager.logError("AuthenticationService - Failed to remove account \(activeDID): \(error)")
            throw error // Propagate other errors
        }
        
        // Publish logout succeeded event
        await EventBus.shared.publish(.logoutSucceeded)
    }

    func tokensExist() async -> Bool {
        // Relies on TokenManager which is now account-aware
        return await tokenManager.hasAnyTokens()
    }

    func initializeOAuthState() async throws {
        if authMethod == .oauth {
            try await oauthManager?.initializeDPoPState()
        }
    }

    func refreshTokens() async throws -> Bool {
        // If tokens don't exist for the active account, return false
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
        LogManager.logInfo("AuthenticationService - Starting legacy session creation for identifier: \(identifier)")

        let endpoint = "/com.atproto.server.createSession"
        let body = try JSONEncoder().encode(
            ComAtprotoServerCreateSession.Input(identifier: identifier, password: password)
        )
        let headers = ["Content-Type": "application/json"]

        // Use a temporary base URL for the initial login request if needed
        // Or ensure NetworkManager uses the correct one before this call
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
        let sessionOutput = try JSONDecoder().decode(
            ComAtprotoServerCreateSession.Output.self,
            from: data
        )
        LogManager.logInfo("AuthenticationService - Session created successfully. Tokens received.")

        let did = sessionOutput.did
        let handle = sessionOutput.handle
        let baseURL = await configurationManager.baseURL.absoluteString // Get current base URL for fallback
        let pdsURLString = sessionOutput.didDoc?.service.first?.serviceEndpoint ?? baseURL
        guard let pdsURL = URL(string: pdsURLString) else {
             LogManager.logError("AuthenticationService - Invalid PDS URL from session: \(pdsURLString)")
             throw AuthenticationError.invalidCredentials // Or a more specific error
        }

        // Create AccountData
        let accountData = AccountData(did: did, handle: handle, pdsURL: pdsURL, isActive: false) // Start as inactive
        
        // Add/Update account in AccountManager BEFORE switching
        try await accountManager.addOrUpdateAccount(accountData)
        
        // Switch to the newly authenticated account - THIS TRIGGERS STATE RELOAD
        try await accountManager.switchAccount(to: did)

        // NOW save the tokens. TokenManager will use the *newly active* DID as namespace.
        try await tokenManager.saveTokens(
            accessJwt: sessionOutput.accessJwt,
            refreshJwt: sessionOutput.refreshJwt,
            type: .bearer,
            domain: pdsURL.host // Use PDS URL host as domain
        )

        // Update configuration (might be redundant if config manager listens to account change)
        // Ensure config manager updates for the *now active* account
        try await configurationManager.updateUserConfiguration(
            did: did,
            handle: handle,
            serviceEndpoint: pdsURL.absoluteString
        )
        await networkManager.updateBaseURL(pdsURL) // Ensure network manager uses the correct PDS

        LogManager.logInfo("AuthenticationService - Account \(did) added/updated and activated. Tokens saved.")

        // Explicitly set session state to authenticated AFTER tokens are saved and account switched
        await sessionManager.setAuthenticatedState(true)
        LogManager.logInfo("AuthenticationService - Session state set to true after legacy login.")

        // Publish token updated event
        await EventBus.shared.publish(.tokensUpdated(accessToken: sessionOutput.accessJwt, refreshToken: sessionOutput.refreshJwt))
    }

    /// Checks if the token needs to be refreshed and attempts to refresh it if necessary.
    ///
    /// - Returns: A boolean indicating whether the token was refreshed.
    /// - Throws: `AuthenticationError` if token refresh fails.
    private func refreshTokenIfNeededLegacy() async throws -> Bool {
        LogManager.logInfo("AuthenticationService - Checking if legacy token refresh is needed.")

        // Fetch tokens for the active account
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
        LogManager.logInfo("AuthenticationService - Attempting to refresh legacy tokens.")

        // Perform token refresh via NetworkManager
        let success = try await networkManager.refreshLegacySessionToken(
            refreshToken: refreshToken,
            tokenManager: tokenManager // TokenManager will save tokens for the active account
        )

        if success {
            LogManager.logInfo("AuthenticationService - Legacy tokens refreshed successfully.")

            // Fetch updated tokens (for the active account)
            if let newAccessToken = await tokenManager.fetchAccessToken(),
               let newRefreshToken = await tokenManager.fetchRefreshToken()
            {
                // Publish token updated event
                await EventBus.shared.publish(.tokensUpdated(accessToken: newAccessToken, refreshToken: newRefreshToken))
            }

            return true
        } else {
            LogManager.logError("AuthenticationService - Legacy token refresh failed.")
            throw AuthenticationError.tokenRefreshFailed
        }
    }

    // MARK: - OAuth Authentication Methods

    private func refreshOAuthTokens() async throws -> Bool {
        guard let oauthManager = oauthManager,
              let refreshToken = await tokenManager.fetchRefreshToken() // Fetches for active account
        else {
            LogManager.logError("AuthenticationService - Unable to refresh OAuth tokens: missing OAuth manager or refresh token")
            throw AuthenticationError.tokenMissingOrCorrupted
        }

        do {
            LogManager.logInfo("AuthenticationService - Attempting to refresh OAuth tokens")
            let (newAccessToken, newRefreshToken) = try await oauthManager.refreshToken(refreshToken: refreshToken)

            // Get the domain from the current base URL (should be PDS URL for the active account)
            let domain = await configurationManager.baseURL.host

            // Save tokens (for the active account)
            try await tokenManager.saveTokens(
                accessJwt: newAccessToken,
                refreshJwt: newRefreshToken,
                type: .dpop,
                domain: domain
            )

            await EventBus.shared.publish(.tokensUpdated(accessToken: newAccessToken, refreshToken: newRefreshToken))
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
