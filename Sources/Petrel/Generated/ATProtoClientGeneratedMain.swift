//
//  ATProtoClientGeneratedMain.swift
//  Petrel
//
//  Created by Josh LaCalamito on 1/19/24.
//

import Foundation

// MARK: - Authentication Method Enum

/// Enum to represent the available authentication methods.
public enum AuthMethod: Sendable {
    case legacy
    case oauth
}

// MARK: - API Error Enum

enum APIError: String, Error {
    case expiredToken = "ExpiredToken"
    case invalidToken
    case invalidResponse
    case methodNotSupported
    case authorizationFailed
    case invalidPDSURL
    case serviceNotInitialized = "AuthenticationService not initialized"
}

// MARK: - OAuth Configuration Struct

public struct OAuthConfiguration: Sendable {
    public let clientId: String
    public let redirectUri: String
    public let scope: String

    public init(clientId: String, redirectUri: String, scope: String) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.scope = scope
    }

    public var redirectUriScheme: String {
        return URL(string: redirectUri)?.scheme ?? ""
    }
}

// MARK: - Initialization State Enum

enum InitializationState {
    case uninitialized
    case initializing
    case ready
    case failed(Error)
}

// MARK: - Client Environment Enum

public enum ClientEnvironment: Sendable {
    case production
    case testing
}

// MARK: - ATProtoClient Actor

public actor ATProtoClient: AuthenticationDelegate, DIDResolving {
    // MARK: - Properties

    private let namespace: String

    public var baseURL: URL
    private var pdsURL: URL?
    private let configManager: ConfigurationManaging
    private let sessionManager: SessionManaging
    private var networkManager: NetworkManaging
    private let tokenManager: TokenManaging
    private let middlewareService: MiddlewareService
    private let oauthConfig: OAuthConfiguration
    private var authenticationService: AuthenticationService

    private(set) var initState: InitializationState = .uninitialized
    //    public weak var authDelegate: AuthenticationDelegate?
    private var _authDelegate: AuthenticationDelegate?

    // User-related properties
    private var did: String?
    private var handle: String?

    private var authorizationServerURL: URL

    // MARK: - Authentication

    private var selectedAuthMethod: AuthMethod

    // MARK: - Initialization

    /// Initializes the ATProtoClient with the specified authentication method.
    ///
    /// - Parameters:
    ///   - authMethod: The authentication method to use (`.legacy` or `.oauth`).
    ///   - oauthConfig: Configuration for OAuth authentication.
    ///   - baseURL: The base URL for the AT Protocol service.
    ///   - environment: The client environment (production or testing).
    ///   - namespace: The namespace for the client.
    ///   - userAgent: Optional user agent string.

    public init(
        authMethod: AuthMethod,
        oauthConfig: OAuthConfiguration,
        baseURL: URL = URL(string: "https://bsky.social")!,
        namespace: String,
        environment: ClientEnvironment,
        userAgent: String? = nil
    ) async {
        LogManager.logDebug(
            "ATProtoClient - Initializing with baseURL: \(baseURL), namespace: \(namespace)")

        self.oauthConfig = oauthConfig
        self.namespace = namespace
        self.baseURL = baseURL
        authorizationServerURL = baseURL
        selectedAuthMethod = authMethod

        configManager = await ConfigurationManager(baseURL: baseURL, namespace: namespace)
        tokenManager = await TokenManager(namespace: namespace)
        networkManager = await NetworkManager(
            baseURL: baseURL, configurationManager: configManager, tokenManager: tokenManager
        )
        middlewareService = await MiddlewareService(tokenManager: tokenManager)
        sessionManager = await SessionManager(
            tokenManager: tokenManager, middlewareService: middlewareService, namespace: namespace
        )
        let didResolutionService = await DIDResolutionService(networkManager: networkManager)
        authenticationService = await AuthenticationService(
            authMethod: authMethod,
            networkManager: networkManager,
            tokenManager: tokenManager,
            configurationManager: configManager,
            oauthConfig: oauthConfig, didResolver: didResolutionService,
            namespace: namespace
        )

        // Set user agent if provided
        if let userAgent = userAgent {
            await networkManager.setUserAgent(userAgent)
        }

        do {
            // Initialize TokenManager first
            LogManager.logDebug("ATProtoClient - TokenManager initialized.")

            await networkManager.setAuthenticationProvider(authenticationService)
            await middlewareService.setSessionManager(sessionManager)

            if let savedPDSURL = await configManager.getPDSURL() {
                LogManager.logInfo("ATProtoClient - Using saved PDS URL: \(savedPDSURL)")
                self.baseURL = savedPDSURL
                await updateAllComponentsWithNewURL(savedPDSURL)
            } else {
                LogManager.logDebug(
                    "ATProtoClient - No saved PDS URL found, using default: \(baseURL)")
            }

            try await authenticationService.initializeOAuthState()

            // Load DID
            did = await configManager.getDID()
            handle = await configManager.getHandle()

            // IMPORTANT: Verify and correct PDS URL if needed
            if did != nil {
                LogManager.logInfo(
                    "ATProtoClient - Current DID found, verifying PDS URL matches network record")
                await verifyAndCorrectPDSURL()
            }

            // First, try to refresh the token if needed
            if try await authenticationService.refreshTokenIfNeeded() {
                LogManager.logInfo("Token refreshed successfully")
            }

            // Attempt to make a simple authenticated request to verify everything is working
            let _ = try await com.atproto.server.describeServer()
            LogManager.logInfo("Client state initialized successfully")

        } catch {
            LogManager.logError("ATProtoClient - Failed to fetch session: \(error)")
            await EventBus.shared.publish(.authenticationFailed(error))
        }

        // Publish an initialization completed event
        await EventBus.shared.publish(.initializationCompleted)
    }

    // MARK: - Initialization Helper Methods

    private func publishInitializationStarted() async {
        await EventBus.shared.publish(.initializationStarted)
    }

    private func updateAllComponentsWithNewURL(_ newURL: URL) async {
        LogManager.logInfo("ATProtoClient - Updating all components with new URL: \(newURL)")

        baseURL = newURL
        pdsURL = newURL
        await configManager.updatePDSURL(newURL)
        await networkManager.updateBaseURL(newURL)

        LogManager.logInfo("ATProtoClient - Base URL updated to: \(newURL)")
    }

    // Modify other methods that might change the PDS URL to use updatePDSURL
    private func getSession() async throws -> ComAtprotoServerGetSession.Output {
        let sessionResponse = try await com.atproto.server.getSession()

        guard let sessionInfo = sessionResponse.data,
              let endpoint = sessionInfo.didDoc?.service.first?.serviceEndpoint,
              let serviceURL = URL(string: endpoint)
        else {
            throw APIError.authorizationFailed
        }

        // Update PDS URL
        await updateAllComponentsWithNewURL(serviceURL)

        try await configManager.updateUserConfiguration(
            did: sessionInfo.did.didString(),
            handle: sessionInfo.handle.description,
            serviceEndpoint: endpoint
        )

        did = sessionInfo.did.didString()
        handle = sessionInfo.handle.description

        return sessionInfo
    }

    //    private func completeInitialization(authMethod: AuthMethod, oauthConfig: OAuthConfiguration) async {
    //        // Publish an initialization completed event
    //    }
    //
    //    private func setupPostInit() async {
    //        await middlewareService.setSessionManager(sessionManager)
    //        // Publish configuration updated event if needed
    //    }

    //    private func getAuthenticationService() throws -> AuthenticationService {
    //        guard let authService = authenticationService else {
    //            LogManager.logError("AuthenticationService not initialized")
    //            throw APIError.serviceNotInitialized
    //        }
    //        return authService
    //    }

    // MARK: - Authentication Delegate Protocol Methods

    /// Notifies when authentication is required.
    ///
    /// - Parameter client: The ATProtoClient instance requiring authentication.
    public func authenticationRequired(client: ATProtoClient) async {
        // Publish an authentication required event
        await EventBus.shared.publish(.authenticationRequired)
    }

    // Allows setting from main actor
    @MainActor public func setAuthenticationDelegate(_ delegate: AuthenticationDelegate) {
        Task { @MainActor in
            await setAuthDelegateOnActor(delegate)
        }
    }

    // Internal method that runs on the actor
    private func setAuthDelegateOnActor(_ delegate: AuthenticationDelegate) {
        _authDelegate = delegate
    }

    // Access via computed property
    var authDelegate: AuthenticationDelegate? {
        _authDelegate
    }

    private func refreshOrRequireAuth() async {
        do {
            let refreshed = try await refreshToken()
            if !refreshed {
                await _authDelegate?.authenticationRequired(client: self)
            }
        } catch {
            await _authDelegate?.authenticationRequired(client: self)
        }
    }

    // MARK: - OAuth Flow Methods

    /// Starts the OAuth flow for account creation
    /// - Parameter pdsURL: The PDS URL to use (defaults to bsky.social)
    /// - Returns: The authorization URL to present to the user
    public func startSignUpFlow(pdsURL: URL = URL(string: "https://bsky.social")!) async throws -> URL {
        // This will call a modified version of the startOAuthFlow that doesn't require an identifier
        return try await startOAuthFlow(identifier: nil, pdsURL: pdsURL)
    }

    /// Starts the OAuth flow by obtaining the authorization URL.
    ///
    /// - Parameters:
    ///   - identifier: The user's identifier (optional for sign-up flow)
    ///   - pdsURL: The PDS URL to use (required when identifier is nil)
    /// - Returns: The authorization URL to be presented to the user.
    public func startOAuthFlow(identifier: String? = nil, pdsURL: URL? = nil) async throws -> URL {
        let authURL: URL
        if let identifier = identifier {
            // Existing login flow with identifier
            authURL = try await authenticationService.startOAuthFlow(identifier: identifier)
        } else {
            // New sign-up flow without identifier
            guard let pdsURL = pdsURL else {
                throw AuthenticationError.invalidOAuthConfiguration
            }
            authURL = try await authenticationService.startOAuthFlowForSignUp(pdsURL: pdsURL)
        }

        // Publish OAuth flow started event
        await EventBus.shared.publish(.oauthFlowStarted(authURL))
        return authURL
    }

    /// Handles the OAuth callback by processing the redirect URL.
    ///
    /// - Parameter url: The callback URL containing authorization data.
    public func handleOAuthCallback(url: URL) async throws {
        try await authenticationService.handleOAuthCallback(url: url)
        // Publish OAuth callback received event

        // After successful OAuth, save the PDS URL
        if let pdsURL = await configManager.getPDSURL() {
            await configManager.updatePDSURL(pdsURL)
        }

        await EventBus.shared.publish(.oauthCallbackReceived(url))
    }

    // MARK: - Login Method

    /// Logs in the user using the specified identifier and password.
    ///
    /// - Parameters:
    ///   - identifier: The user's identifier (e.g., handle).
    ///   - password: The user's password.
    public func login(identifier: String, password: String) async throws {
        try await authenticationService.login(identifier: identifier, password: password)

        // After login, set DID and handle
        did = try await resolveHandleToDID(handle: identifier)
        handle = identifier

        // Publish token updated event
        if let accessToken = await tokenManager.fetchAccessToken(),
           let refreshToken = await tokenManager.fetchRefreshToken()
        {
            await EventBus.shared.publish(
                .tokensUpdated(accessToken: accessToken, refreshToken: refreshToken))
        }
    }

    // MARK: - Logout Method

    public func logout() async throws {
        LogManager.logInfo("ATProtoClient - Attempting logout")
        LogManager.logError("LOGOUT_DEBUG: Value of self.did right before guard: \(String(describing: did))")

        // Get the current DID either from memory or from lastActiveDID in Keychain
        var effectiveDID = did
        if effectiveDID == nil {
            LogManager.logError("LOGOUT_DEBUG: self.did is nil, trying to fetch lastActiveDID as fallback")
            // Attempt to grab the last known DID from Keychain for proper cleanup
            effectiveDID = await TokenManager.getLastActiveDID(namespace: namespace)
            if let recoveredDID = effectiveDID {
                LogManager.logError("LOGOUT_DEBUG: Found fallback DID from lastActiveDID: \(recoveredDID)")
            } else {
                LogManager.logError("LOGOUT_DEBUG: No fallback DID found in lastActiveDID either.")
            }
        }

        guard let currentDID = effectiveDID else {
            LogManager.logError("LOGOUT_DEBUG: No DID available (not even fallback). Using generic cleanup only.")
            // Attempt legacy cleanup just in case
            try? await tokenManager.deleteTokens()

            // Even without a specific DID, explicitly clear the lastActiveDID
            LogManager.logError("LOGOUT_DEBUG: Explicitly clearing lastActiveDID")
            await TokenManager.clearLastActiveDID(namespace: namespace)

            // Clear any client state
            did = nil
            handle = nil
            pdsURL = nil

            await authDelegate?.authenticationRequired(client: self)
            return
        }

        LogManager.logError("LOGOUT_DEBUG: Using DID for logout: \(currentDID)")

        // 1. Clear session state first (in-memory)
        try await middlewareService.clearSession()

        // 2. Delete tokens specific to the current DID from TokenManager & Keychain
        LogManager.logError("LOGOUT: Attempting to delete tokens for DID: \(currentDID)")
        try await tokenManager.deleteTokensForDID(currentDID)
        LogManager.logError("LOGOUT: Finished deleting tokens for DID: \(currentDID)")

        // 3. Delete DPoP bindings specific to the current DID
        LogManager.logError("LOGOUT: Clearing DPoP bindings for DID: \(currentDID)")
        await tokenManager.clearDPoPBindingsForDID(currentDID)
        LogManager.logError("LOGOUT: Finished clearing DPoP bindings")

        // 4. Delete the DPoP key pair associated with the current session/DID
        LogManager.logError("LOGOUT: Deleting DPoP key")
        await authenticationService.deleteDPoPKey()
        LogManager.logError("LOGOUT: Finished deleting DPoP key")

        // 5. Clean up OAuth-related state
        LogManager.logError("LOGOUT: Cleaning up OAuth state")
        try? KeychainManager.delete(key: "codeVerifier", namespace: namespace)
        try? KeychainManager.delete(key: "state", namespace: namespace)
        try? KeychainManager.delete(key: "isAuthenticated", namespace: namespace)
        LogManager.logError("LOGOUT: Finished cleaning up OAuth state")

        // 6. Clear the last active DID by removing the account
        LogManager.logError("LOGOUT: About to call removeAccount for DID: \(currentDID)")
        do {
            try await removeAccount(did: currentDID)
            LogManager.logError("LOGOUT: Account successfully removed during logout")
        } catch {
            LogManager.logError("LOGOUT: Failed to remove account during logout: \(error)")
            // Force clear settings anyway
            await configManager.clearSettings()
            LogManager.logError("LOGOUT: Attempting to manually clear lastActiveDID")
            await TokenManager.clearLastActiveDID(namespace: namespace)

            // Also explicitly clear DID-specific handles
            try? KeychainManager.delete(key: "handle.\(currentDID)", namespace: namespace)
            try? KeychainManager.delete(key: "pdsURL.\(currentDID)", namespace: namespace)
            try? KeychainManager.delete(key: "protectedResourceMetadata.\(currentDID)", namespace: namespace)
            try? KeychainManager.delete(key: "authorizationServerMetadata.\(currentDID)", namespace: namespace)
            try? KeychainManager.delete(key: "currentAuthorizationServer.\(currentDID)", namespace: namespace)

            LogManager.logError("LOGOUT: Manual lastActiveDID clearing completed")
        }

        // 7. Check if any accounts remain
        let remainingAccounts = await listAccounts()
        LogManager.logError("LOGOUT: Remaining accounts after processing: \(remainingAccounts.count)")

        // 8. Double check that lastActiveDID is cleared if no accounts remain
        if remainingAccounts.isEmpty {
            await configManager.clearSettings()

            LogManager.logError("LOGOUT: No accounts remaining, ensuring lastActiveDID is cleared.")
            // If no accounts are left, clear the last active DID marker one more time just to be sure
            await TokenManager.clearLastActiveDID(namespace: namespace)
            LogManager.logError("LOGOUT: Finished clearing lastActiveDID again")

            // Reset client state
            did = nil
            handle = nil
            pdsURL = nil
            LogManager.logError("LOGOUT: Reset client state to nil")
        } else {
            LogManager.logInfo("ATProtoClient - \(remainingAccounts.count) accounts remain.")
            // Try to switch to another account if available
            if let firstAccount = remainingAccounts.first {
                do {
                    _ = try await switchToAccount(did: firstAccount)
                    LogManager.logInfo("ATProtoClient - Switched to fallback account: \(firstAccount)")
                } catch {
                    LogManager.logError("ATProtoClient - Failed to switch to fallback account: \(error)")
                    // Reset client state on failure
                    did = nil
                    handle = nil
                    pdsURL = nil
                }
            }
        }

        // 9. Notify delegate that authentication is required
        await authDelegate?.authenticationRequired(client: self)
        await EventBus.shared.publish(.authenticationRequired)
        LogManager.logError("LOGOUT: Logout complete for DID: \(currentDID)")
    }

    public func nukeEverything() async {
        LogManager.logInfo("ATProtoClient - Complete keychain reset requested")

        // Reset all in-memory state
        did = nil
        handle = nil
        pdsURL = nil

        // Clear all keychain items
        let success = KeychainManager.nukeAllKeychainItems(forNamespace: namespace)

        // Reset configuration manager
        await configManager.clearSettings()

        // Reset token manager state
        await TokenManager.clearLastActiveDID(namespace: namespace)

        // Clear any session state
        try? await middlewareService.clearSession()

        // Notify that authentication is required
        await authDelegate?.authenticationRequired(client: self)
        await EventBus.shared.publish(.authenticationRequired)

        LogManager.logInfo("ATProtoClient - Keychain reset complete, success: \(success)")
    }

    // MARK: - Utility Functions

    /// Resolves a user's handle to their DID.
    ///
    /// - Parameter handle: The user's handle.
    /// - Returns: The resolved DID.
    public func resolveHandleToDID(handle: String) async throws -> String {
        let input = try ComAtprotoIdentityResolveHandle.Parameters(handle: Handle(handleString: handle))
        let (responseCode, data) = try await com.atproto.identity.resolveHandle(input: input)
        guard responseCode == 200, let did = data?.did else {
            throw APIError.invalidPDSURL
        }
        return did.didString()
    }

    /// Resolves a DID to the user's PDS URL by fetching their DID document.
    ///
    /// - Parameter did: The user's DID.
    /// - Returns: The PDS URL.
    public func resolveDIDToPDSURL(did: String) async throws -> URL {
        let didDocURL = "https://plc.directory/\(did)"
        let request = try await networkManager.createURLRequest(
            endpoint: didDocURL,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )
        let (data, _) = try await networkManager.performRequest(request)
        let didDocument = try JSONDecoder().decode(DIDDocument.self, from: data)

        guard
            let serviceURLString = didDocument.service.first(where: {
                $0.type == "AtprotoPersonalDataServer"
            })?.serviceEndpoint,
            let serviceURL = URL(string: serviceURLString)
        else {
            throw APIError.invalidPDSURL
        }

        pdsURL = serviceURL
        // Publish PDS URL updated event
        await EventBus.shared.publish(.baseURLUpdated(serviceURL))
        return serviceURL
    }

    private func updateNetworkManagerBaseURL() async {
        if let pdsURL = pdsURL {
            await EventBus.shared.publish(.baseURLUpdated(pdsURL))
        }
    }

    /// Retrieves the current user's handle.
    ///
    /// - Returns: The user's handle, if available.
    public func getHandle() async throws -> String {
        guard let handle = await configManager.getHandle() else {
            if selectedAuthMethod == .legacy {
                return try await getSession().handle.description
            } else {
                // For OAuth, we should throw an error instead of calling getSession
                throw APIError.authorizationFailed
            }
        }
        return handle
    }

    public func getDid() async throws -> String {
        guard let did = await configManager.getDID() else {
            if selectedAuthMethod == .legacy {
                return try await getSession().did.didString()
            } else {
                // For OAuth, we should throw an error instead of calling getSession
                throw APIError.authorizationFailed
            }
        }
        return did
    }

    /// Refreshes the access token if necessary.
    ///
    /// - Returns: A boolean indicating whether the refresh was successful.
    public func refreshToken() async throws -> Bool {
        let refreshed = try await authenticationService.refreshTokenIfNeeded() // Store the result
        if refreshed {
            if let accessToken = await tokenManager.fetchAccessToken(),
               let refreshToken = await tokenManager.fetchRefreshToken()
            {
                await EventBus.shared.publish(
                    .tokensUpdated(accessToken: accessToken, refreshToken: refreshToken))
            }
        }
        return refreshed
    }

    /// Refreshes the token if needed based on expiration time.
    ///
    /// - Returns: A boolean indicating whether the token was refreshed.
    /// - Throws: An error if the token refresh fails.
    @discardableResult
    public func refreshTokenIfNeeded() async throws -> Bool {
        return try await authenticationService.refreshTokenIfNeeded()
    }

    /// Checks if the current session is valid, attempting a token refresh if not.
    ///
    /// - Returns: A boolean indicating whether the session is valid.
    public func hasValidSession() async -> Bool {
        do {
            let hasValidTokens = await tokenManager.hasValidTokens()
            if !hasValidTokens {
                await refreshOrRequireAuth()
                return false
            }
            return true
        } catch {
            await refreshOrRequireAuth()
            return false
        }
    }

    /// Initializes the session by fetching metadata and validating tokens.
    public func initializeSession() async throws {
        LogManager.logDebug("ATProtoClient - Initializing session.")
        do {
            await baseURL = configManager.getPDSURL() ?? baseURL
            try await tokenManager.fetchAuthServerMetadataAndJWKS(baseURL: baseURL)
            LogManager.logDebug("ATProtoClient - Authorization Server Metadata and JWKS fetched.")

            try await sessionManager.initializeIfNeeded()
            LogManager.logDebug("ATProtoClient - SessionManager initialized.")

            let isValid = await hasValidSession()
            if isValid {
                did = await configManager.getDID()
                handle = await configManager.getHandle()
                pdsURL = await configManager.getPDSURL()
                if let pdsURL = pdsURL {
                    await EventBus.shared.publish(.baseURLUpdated(pdsURL))
                    LogManager.logInfo(
                        "ATProtoClient - Updated NetworkManager base URL to PDS URL: \(pdsURL)")
                }
                // Publish session initialized event
                await EventBus.shared.publish(.sessionInitialized)
            } else {
                LogManager.logError("ATProtoClient - Session is invalid after initialization.")
                // Publish session expired event
                await EventBus.shared.publish(.sessionExpired)
            }
        } catch {
            LogManager.logError("ATProtoClient - Failed to initialize session: \(error)")
            // Publish network error event
            await EventBus.shared.publish(.networkError(error))
            throw error
        }
    }

    // MARK: - Header Management

    /// Sets the user agent for all requests from this client
    /// - Parameter userAgent: The user agent string
    public func setUserAgent(_ userAgent: String) async {
        await networkManager.setUserAgent(userAgent)
    }

    /// Sets a custom header for all requests from this client
    /// - Parameters:
    ///   - name: Header name
    ///   - value: Header value
    public func setHeader(name: String, value: String) async {
        await networkManager.setHeader(name: name, value: value)
    }

    /// Removes a custom header
    /// - Parameter name: Header name to remove
    public func removeHeader(name: String) async {
        await networkManager.removeHeader(name: name)
    }

    /// Clears all custom headers
    public func clearHeaders() async {
        await networkManager.clearHeaders()
    }

    // MARK: - ATProto-Specific Headers

    /// Sets the labeler service to receive moderation reports
    /// - Parameter did: The DID of the labeler service
    public func setReportLabeler(did: String) async {
        await networkManager.setProxyHeader(did: did, service: "atproto_labeler")
    }

    /// Clears any previously set report labeler
    public func clearReportLabeler() async {
        await networkManager.removeHeader(name: "atproto-proxy")
    }

    /// Sets which labelers to subscribe to for content labels
    /// - Parameter labelers: Array of tuples containing labeler DIDs and redaction flags
    public func setAcceptLabelers(_ labelers: [(did: String, redact: Bool)]) async {
        await networkManager.setAcceptLabelers(labelers)
    }

    /// Sets the chat service for proxying
    /// - Parameter did: The DID of the chat service
    public func setChatService(did: String) async {
        await networkManager.setProxyHeader(did: did, service: "bsky_chat")
    }

    /// Extracts content labelers from a response
    /// - Parameter response: The HTTP response
    /// - Returns: Array of tuples containing labeler DIDs and redaction flags
    public func getContentLabelers(from response: HTTPURLResponse) async -> [(
        did: String, redact: Bool
    )] {
        return await networkManager.extractContentLabelers(from: response)
    }

    // MARK: - SessionDelegate Protocol Methods

    /// Notifies that the session requires reauthentication.
    ///
    /// - Parameter sessionManager: The session manager requiring reauthentication.
    func sessionRequiresReauthentication(sessionManager: SessionManager) async throws {
        // Publish an authentication required event
        await EventBus.shared.publish(.authenticationRequired)
    }

    // MARK: - Event Subscription

    private func subscribeToEvents() async {
        let eventStream = await EventBus.shared.subscribe()
        for await event in eventStream {
            switch event {
            //            case .tokensUpdated(accessToken: let accessToken, refreshToken: let refreshToken):
            //                // Handle token refreshed event
            //                LogManager.logDebug("ATProtoClient - Received tokenRefreshed event.")
            //                // Update internal state if necessary
            ////                self.baseURL = await configManager.getPDSURL() ?? self.baseURL
            //            case .sessionExpired:
            //                // Handle session expired event
            //                LogManager.logInfo("ATProtoClient - Session expired. Requiring authentication.")
            //                await authDelegate?.authenticationRequired(client: self)
            //            case .networkError(let error):
            //                // Handle network errors
            //                LogManager.logError("ATProtoClient - Network error occurred: \(error)")
            //            case .baseURLUpdated(let newURL):
            //                if self.baseURL != newURL {
            //                    LogManager.logInfo("ATProtoClient - Configuration updated with new URL: \(newURL)")
            //                    self.baseURL = newURL
            //                }
            //            case .authenticationRequired:
            //                LogManager.logInfo("ATProtoClient - Authentication required event received.")
            //                await handleAuthenticationError()
            //            case .oauthFlowStarted(let url):
            //                // Handle OAuth flow started
            //                LogManager.logInfo("ATProtoClient - OAuth flow started with URL: \(url)")
            //            case .oauthCallbackReceived(let url):
            //                // Handle OAuth callback received
            //                LogManager.logInfo("ATProtoClient - OAuth callback received with URL: \(url)")
            //            case .tokensUpdated(let accessToken, let refreshToken):
            //                // Handle token updated event
            //                LogManager.logInfo("ATProtoClient - Tokens updated.")
            //                // Update internal state or notify other components if necessary
            //            case .requestCompleted(let request, let data, let response):
            //                // Handle request completed event
            //                LogManager.logDebug("ATProtoClient - Request completed: \(request.url?.absoluteString ?? "") with status: \(response.statusCode)")
            default:
                break
            }
        }
    }

    // MARK: - Multi-Account Management

    /// Lists all the accounts (DIDs) that have stored tokens
    ///
    /// - Returns: An array of DIDs representing stored accounts
    public func listAccounts() async -> [String] {
        let accounts = await tokenManager.listStoredDIDs()
        LogManager.logInfo("ATProtoClient - Listed \(accounts.count) stored accounts")
        return accounts
    }

    /// Switches to a different user account
    ///
    /// - Parameter did: The DID of the account to switch to
    /// - Throws: AuthenticationError if the account cannot be switched
    /// - Returns: True if the switch was successful
    public func switchToAccount(did: String) async throws -> Bool {
        LogManager.logInfo("ATProtoClient - Switching to account with DID: \(did)")
        LogManager.logError("SWITCH_ACC: START - Switching ATProtoClient state to DID: \(did)")

        // 1. Load tokens for the specified DID
        let accessToken = await tokenManager.fetchAccessToken(did: did)
        let refreshToken = await tokenManager.fetchRefreshToken(did: did)

        guard accessToken != nil || refreshToken != nil else {
            LogManager.logError("ATProtoClient - No tokens found for DID: \(did)")
            LogManager.logError("SWITCH_ACC: No tokens found for DID: \(did)")
            throw AuthenticationError.tokenMissingOrCorrupted
        }

        // 2. Update the current DID in TokenManager
        await tokenManager.setCurrentDID(did)
        LogManager.logError("SWITCH_ACC: TokenManager current DID set to: \(did)")

        // NEW: Store as the last active DID
        await TokenManager.storeLastActiveDID(did, namespace: namespace)

        // 3. Switch account in ConfigurationManager
        LogManager.logError("SWITCH_ACC: Calling configManager.switchToAccount(did: \(did))")
        let configSuccess = await configManager.switchToAccount(did: did)
        LogManager.logError("SWITCH_ACC: configManager.switchToAccount returned: \(configSuccess)")

        guard configSuccess else {
            LogManager.logError("ATProtoClient - Failed to load configuration for DID: \(did)")
            LogManager.logError("SWITCH_ACC: Configuration switch failed in ConfigManager.")
            throw AuthenticationError.tokenMissingOrCorrupted
        }

        // --- CRITICAL VERIFICATION ---
        let pdsURLFromConfig = await configManager.getPDSURL()
        LogManager.logError(
            "SWITCH_ACC: PDS URL retrieved *after* config switch: \(pdsURLFromConfig?.absoluteString ?? "nil")"
        )
        // --- END CRITICAL VERIFICATION ---

        // 4. Update NetworkManager with new PDS URL
        if let pdsURL = pdsURLFromConfig {
            LogManager.logError("SWITCH_ACC: Updating NetworkManager baseURL to: \(pdsURL)")
            await networkManager.updateBaseURL(pdsURL)

            // Also update ATProtoClient's own baseURL/pdsURL state
            baseURL = pdsURL
            self.pdsURL = pdsURL
            LogManager.logError("SWITCH_ACC: ATProtoClient baseURL/pdsURL updated to: \(pdsURL)")
            await EventBus.shared.publish(.baseURLUpdated(pdsURL))
        } else {
            LogManager.logError(
                "SWITCH_ACC: No PDS URL returned from configManager after switch! Using default.")
            // Handle default case
            await networkManager.updateBaseURL(URL(string: "https://bsky.social")!)
            baseURL = URL(string: "https://bsky.social")!
            pdsURL = nil
        }

        // 5. Store current user information in ATProtoClient actor
        self.did = did
        handle = await configManager.getHandle()
        LogManager.logError(
            "SWITCH_ACC: ATProtoClient internal state updated: did=\(self.did ?? "nil"), handle=\(handle ?? "nil")"
        )

        // 6. Initialize services if needed (DPoP key loading for new DID)
        LogManager.logError("SWITCH_ACC: Initializing Auth Service State (DPoP)")
        try await authenticationService.initializeOAuthState()

        // 7. Attempt a token refresh if needed
        LogManager.logError("SWITCH_ACC: Attempting refresh token if needed")
        try await refreshTokenIfNeeded()

        // 8. Publish account switched event
        await EventBus.shared.publish(.accountSwitched(did: did))

        LogManager.logError("SWITCH_ACC: END - Successfully switched to account: \(did)")
        LogManager.logInfo("ATProtoClient - Successfully switched to account: \(did)")
        return true
    }

    /// Adds a new account by performing OAuth authentication
    ///
    /// - Parameter identifier: The user identifier (handle) for the new account
    /// - Returns: The authorization URL to present to the user
    public func addAccount(identifier: String) async throws -> URL {
        // Save the current state before starting OAuth flow for a new account
        let currentDID = did

        // Start OAuth flow for the new account
        let authURL = try await startOAuthFlow(identifier: identifier)

        // When OAuth callback happens, the new account will become the active one
        // Store the previous active account to handle restoring if needed
        Task {
            if let currentDID = currentDID {
                await TokenManager.storeLastActiveDID(currentDID, namespace: namespace)
            }
        }

        return authURL
    }

    /// Removes an account and all associated data
    ///
    /// - Parameter did: The DID of the account to remove
    /// - Throws: Error if the removal fails
    public func removeAccount(did: String) async throws {
        LogManager.logInfo("ATProtoClient - Removing account with DID: \(did)")
        LogManager.logError("REMOVE_ACCOUNT: Starting removal for DID: \(did)")

        // Check if this is the current account
        let isCurrent = self.did == did
        LogManager.logError("REMOVE_ACCOUNT: Is current account: \(isCurrent)")

        // 1. Delete tokens specific to this DID
        LogManager.logError("REMOVE_ACCOUNT: Attempting to delete tokens for DID: \(did)")
        try await tokenManager.deleteTokensForDID(did)
        LogManager.logError("REMOVE_ACCOUNT: Finished deleting tokens for DID: \(did)")

        // 2. Delete DPoP bindings specific to this DID
        LogManager.logError("REMOVE_ACCOUNT: Clearing DPoP bindings for DID: \(did)")
        await tokenManager.clearDPoPBindingsForDID(did)
        LogManager.logError("REMOVE_ACCOUNT: Finished clearing DPoP bindings")

        // 3. Delete configuration data for this DID
        LogManager.logError("REMOVE_ACCOUNT: Attempting to remove config for DID: \(did)")
        try await configManager.removeAccount(did: did)
        LogManager.logError("REMOVE_ACCOUNT: Finished removing config for DID: \(did)")

        // 4. Delete the DPoP key pair if this is the current account
        if isCurrent {
            LogManager.logError("REMOVE_ACCOUNT: Deleting DPoP key for current account")
            await authenticationService.deleteDPoPKey()
            LogManager.logError("REMOVE_ACCOUNT: Finished deleting DPoP key")
        }

        // 5. Check if any accounts remain
        let remainingAccounts = await listAccounts()
        LogManager.logError("REMOVE_ACCOUNT: Remaining accounts after deletion attempt: \(remainingAccounts)")

        if remainingAccounts.isEmpty {
            LogManager.logError("REMOVE_ACCOUNT: No accounts remaining. ATTEMPTING TO CLEAR lastActiveDID.")
            // If no accounts are left, clear the last active DID marker
            await TokenManager.clearLastActiveDID(namespace: namespace)
            LogManager.logError("REMOVE_ACCOUNT: FINISHED attempting to clear lastActiveDID.")

            // Also clear any handles associated with this DID
            try? KeychainManager.delete(key: "handle.\(did)", namespace: namespace)

            // Explicitly force clear all related items
            try? KeychainManager.delete(key: "pdsURL.\(did)", namespace: namespace)
            try? KeychainManager.delete(key: "protectedResourceMetadata.\(did)", namespace: namespace)
            try? KeychainManager.delete(key: "authorizationServerMetadata.\(did)", namespace: namespace)
            try? KeychainManager.delete(key: "currentAuthorizationServer.\(did)", namespace: namespace)

            LogManager.logError("REMOVE_ACCOUNT: Cleared all settings")
            await configManager.clearSettings()
            LogManager.logError("REMOVE_ACCOUNT: Finished clearing settings")

            // Reset client state
            self.did = nil
            handle = nil
            pdsURL = nil
            LogManager.logError("REMOVE_ACCOUNT: Reset client state to nil")

            // Notify that we need authentication
            await EventBus.shared.publish(.accountRemoved(did: did))
            await EventBus.shared.publish(.authenticationRequired)
        } else if isCurrent {
            LogManager.logError("REMOVE_ACCOUNT: This was the current account, \(remainingAccounts.count) remain.")
            // Try to switch to another account if available
            if let firstAccount = remainingAccounts.first {
                do {
                    LogManager.logError("REMOVE_ACCOUNT: Attempting to switch to fallback account: \(firstAccount)")
                    _ = try await switchToAccount(did: firstAccount)
                    LogManager.logInfo("ATProtoClient - Switched to fallback account: \(firstAccount)")
                } catch {
                    LogManager.logError("REMOVE_ACCOUNT: Failed to switch to fallback account: \(error)")
                    // Reset client state on failure
                    self.did = nil
                    handle = nil
                    pdsURL = nil
                    LogManager.logError("REMOVE_ACCOUNT: Reset client state after failed switch")

                    // Notify that we need authentication
                    await EventBus.shared.publish(.accountRemoved(did: did))
                    await EventBus.shared.publish(.authenticationRequired)
                }
            }
        } else {
            LogManager.logError("REMOVE_ACCOUNT: This was not the current account. Just notifying removal.")
            // Just notify that account was removed
            await EventBus.shared.publish(.accountRemoved(did: did))
        }

        LogManager.logError("REMOVE_ACCOUNT: Successfully completed removal of account: \(did)")
    }

    /// Returns information about the currently active account
    ///
    /// - Returns: A tuple containing the DID, handle, and PDS URL of the active account
    public func getActiveAccountInfo() async -> (did: String?, handle: String?, pdsURL: URL?) {
        return (did: did, handle: handle, pdsURL: pdsURL)
    }

    // MARK: - PDS URL Validation and Self-Healing

    /// Verifies that the current PDS URL is correct for the given DID by resolving it from the network
    /// If there's a mismatch, updates all components with the correct URL
    private func verifyAndCorrectPDSURL() async {
        LogManager.logInfo(
            "ATProtoClient - Verifying PDS URL matches the correct one for the current DID")

        guard let currentDID = did else {
            LogManager.logInfo("ATProtoClient - No current DID available, skipping PDS URL verification")
            return
        }

        do {
            // Get the current PDS URL from config
            let configPDSURL = await configManager.getPDSURL()
            LogManager.logInfo(
                "ATProtoClient - Current PDS URL from config: \(configPDSURL?.absoluteString ?? "nil")")

            // Resolve the DID to get the actual PDS URL from the network
            let resolvedPDSURL = try await resolveDIDToPDSURL(did: currentDID)
            LogManager.logInfo("ATProtoClient - Resolved PDS URL from network: \(resolvedPDSURL)")

            // Compare the URLs and update if different
            if configPDSURL != resolvedPDSURL {
                LogManager.logError("ATProtoClient - PDS URL MISMATCH DETECTED!")
                LogManager.logError("ATProtoClient - Config had: \(configPDSURL?.absoluteString ?? "nil")")
                LogManager.logError("ATProtoClient - Network resolved: \(resolvedPDSURL)")
                LogManager.logError("ATProtoClient - Correcting PDS URL to match network resolution")

                // Update all components with the correct URL
                await updateAllComponentsWithNewURL(resolvedPDSURL)

                // IMPORTANT: Update the stored configuration to prevent future mismatches
                await configManager.updatePDSURL(resolvedPDSURL)

                LogManager.logInfo("ATProtoClient - PDS URL corrected successfully")
            } else {
                LogManager.logInfo("ATProtoClient - PDS URL verification successful, URLs match")
            }
        } catch {
            LogManager.logError("ATProtoClient - Error verifying PDS URL: \(error)")
        }
    }

    // MARK: - Generated Classes

    public lazy var tools: Tools = .init(networkManager: self.networkManager)

    public final class Tools: @unchecked Sendable {
        let networkManager: NetworkManaging
        init(networkManager: NetworkManaging) {
            self.networkManager = networkManager
        }

        public lazy var ozone: Ozone = .init(networkManager: self.networkManager)

        public final class Ozone: @unchecked Sendable {
            let networkManager: NetworkManaging
            init(networkManager: NetworkManaging) {
                self.networkManager = networkManager
            }

            public lazy var signature: Signature = .init(networkManager: self.networkManager)

            public final class Signature: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var server: Server = .init(networkManager: self.networkManager)

            public final class Server: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var team: Team = .init(networkManager: self.networkManager)

            public final class Team: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var communication: Communication = .init(networkManager: self.networkManager)

            public final class Communication: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var set: Set = .init(networkManager: self.networkManager)

            public final class Set: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var setting: Setting = .init(networkManager: self.networkManager)

            public final class Setting: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var moderation: Moderation = .init(networkManager: self.networkManager)

            public final class Moderation: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }
        }
    }

    public lazy var app: App = .init(networkManager: self.networkManager)

    public final class App: @unchecked Sendable {
        let networkManager: NetworkManaging
        init(networkManager: NetworkManaging) {
            self.networkManager = networkManager
        }

        public lazy var bsky: Bsky = .init(networkManager: self.networkManager)

        public final class Bsky: @unchecked Sendable {
            let networkManager: NetworkManaging
            init(networkManager: NetworkManaging) {
                self.networkManager = networkManager
            }

            public lazy var video: Video = .init(networkManager: self.networkManager)

            public final class Video: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var embed: Embed = .init(networkManager: self.networkManager)

            public final class Embed: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var notification: Notification = .init(networkManager: self.networkManager)

            public final class Notification: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var unspecced: Unspecced = .init(networkManager: self.networkManager)

            public final class Unspecced: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var graph: Graph = .init(networkManager: self.networkManager)

            public final class Graph: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var feed: Feed = .init(networkManager: self.networkManager)

            public final class Feed: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var richtext: Richtext = .init(networkManager: self.networkManager)

            public final class Richtext: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var actor: Actor = .init(networkManager: self.networkManager)

            public final class Actor: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var labeler: Labeler = .init(networkManager: self.networkManager)

            public final class Labeler: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }
        }
    }

    public lazy var chat: Chat = .init(networkManager: self.networkManager)

    public final class Chat: @unchecked Sendable {
        let networkManager: NetworkManaging
        init(networkManager: NetworkManaging) {
            self.networkManager = networkManager
        }

        public lazy var bsky: Bsky = .init(networkManager: self.networkManager)

        public final class Bsky: @unchecked Sendable {
            let networkManager: NetworkManaging
            init(networkManager: NetworkManaging) {
                self.networkManager = networkManager
            }

            public lazy var convo: Convo = .init(networkManager: self.networkManager)

            public final class Convo: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var actor: Actor = .init(networkManager: self.networkManager)

            public final class Actor: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var moderation: Moderation = .init(networkManager: self.networkManager)

            public final class Moderation: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }
        }
    }

    public lazy var com: Com = .init(networkManager: self.networkManager)

    public final class Com: @unchecked Sendable {
        let networkManager: NetworkManaging
        init(networkManager: NetworkManaging) {
            self.networkManager = networkManager
        }

        public lazy var atproto: Atproto = .init(networkManager: self.networkManager)

        public final class Atproto: @unchecked Sendable {
            let networkManager: NetworkManaging
            init(networkManager: NetworkManaging) {
                self.networkManager = networkManager
            }

            public lazy var temp: Temp = .init(networkManager: self.networkManager)

            public final class Temp: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var identity: Identity = .init(networkManager: self.networkManager)

            public final class Identity: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var admin: Admin = .init(networkManager: self.networkManager)

            public final class Admin: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var server: Server = .init(networkManager: self.networkManager)

            public final class Server: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var label: Label = .init(networkManager: self.networkManager)

            public final class Label: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var sync: Sync = .init(networkManager: self.networkManager)

            public final class Sync: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var lexicon: Lexicon = .init(networkManager: self.networkManager)

            public final class Lexicon: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var repo: Repo = .init(networkManager: self.networkManager)

            public final class Repo: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var moderation: Moderation = .init(networkManager: self.networkManager)

            public final class Moderation: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }
        }
    }
}
