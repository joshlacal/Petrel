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

    // Removed namespace property
    // private let namespace: String

    public var baseURL: URL
    private var pdsURL: URL?
    private let configManager: ConfigurationManaging
    private let sessionManager: SessionManaging
    private var networkManager: NetworkManaging
    private let tokenManager: TokenManaging
    private let middlewareService: MiddlewareService
    private let oauthConfig: OAuthConfiguration
    private var authenticationService: AuthenticationService
    private let accountManager: AccountManaging // Added

    private(set) var initState: InitializationState = .uninitialized
    private var _authDelegate: AuthenticationDelegate?

    // User-related properties (now primarily managed by AccountManager/ConfigManager)
    // private var did: String? // Can get from accountManager or configManager
    // private var handle: String? // Can get from accountManager or configManager

    private var authorizationServerURL: URL

    // MARK: - Authentication

    private var selectedAuthMethod: AuthMethod

    // MARK: - Initialization

    /// Initializes the ATProtoClient with the specified authentication method.
    ///
    /// - Parameters:
    ///   - authMethod: The authentication method to use (`.legacy` or `.oauth`).
    ///   - oauthConfig: Configuration for OAuth authentication.
    ///   - baseURL: The initial base URL (will be updated based on active account).
    ///   - environment: The client environment (production or testing).
    ///   - userAgent: Optional user agent string.
    public init(
        authMethod: AuthMethod,
        oauthConfig: OAuthConfiguration,
        baseURL: URL = URL(string: "https://bsky.social")!,
        // Removed namespace parameter
        // namespace: String,
        environment: ClientEnvironment,
        userAgent: String? = nil
    ) async {
        LogManager.logDebug(
            "ATProtoClient - Initializing with baseURL: \(baseURL)")
        self.oauthConfig = oauthConfig
        // self.namespace = namespace // Removed
        self.baseURL = baseURL
        authorizationServerURL = baseURL
        selectedAuthMethod = authMethod

        // Instantiate AccountManager first
        accountManager = await AccountManager()

        // Pass accountManager to other managers
        configManager = await ConfigurationManager(baseURL: baseURL, accountManager: accountManager)
        tokenManager = await TokenManager(accountManager: accountManager)
        networkManager = await NetworkManager(
            baseURL: baseURL, configurationManager: configManager, tokenManager: tokenManager
        )
        middlewareService = await MiddlewareService(tokenManager: tokenManager)
        sessionManager = await SessionManager(
            tokenManager: tokenManager, middlewareService: middlewareService, accountManager: accountManager
        )
        let didResolutionService = await DIDResolutionService(networkManager: networkManager)
        authenticationService = await AuthenticationService(
            authMethod: authMethod,
            networkManager: networkManager,
            tokenManager: tokenManager,
            configurationManager: configManager,
            accountManager: accountManager, // Pass accountManager
            oauthConfig: oauthConfig,
            didResolver: didResolutionService,
            sessionManager: sessionManager
            // Removed namespace parameter
        )

        // Set user agent if provided
        if let userAgent = userAgent {
            await networkManager.setUserAgent(userAgent)
        }

        do {
            LogManager.logDebug("ATProtoClient - Managers initialized.")

            await networkManager.setAuthenticationProvider(authenticationService)
            await middlewareService.setSessionManager(sessionManager)

            // Load initial state based on potentially active account
            if let activeDID = await accountManager.getActiveAccountDID(),
               let activeAccount = await accountManager.getAccount(did: activeDID),
               let savedPDSURL = activeAccount.pdsURL
            {
                LogManager.logInfo("ATProtoClient - Using saved PDS URL for active account \(activeDID): \(savedPDSURL)")
                self.baseURL = savedPDSURL
                await updateAllComponentsWithNewURL(savedPDSURL)
            } else {
                LogManager.logDebug(
                    "ATProtoClient - No active account or PDS URL found, using default: \(baseURL)")
            }

            // Initialize OAuth state if needed
            try await authenticationService.initializeOAuthState()

            // Attempt initial token refresh if tokens exist
            if await tokenManager.hasAnyTokens() {
                if try await authenticationService.refreshTokenIfNeeded() {
                    LogManager.logInfo("Token refreshed successfully during initialization.")
                }
            }

            // Attempt to make a simple authenticated request to verify everything is working
            // Only if there's an active session
            if await sessionManager.hasValidSession() {
                do {
                    let _ = try await com.atproto.server.describeServer()
                    LogManager.logInfo("Client state verified successfully with describeServer call.")
                } catch {
                    LogManager.logError("Failed to verify client state with describeServer: \(error)")
                    // Don't throw here, allow initialization to complete but log the issue
                }
            } else {
                LogManager.logInfo("No active session found during initialization.")
            }

        } catch {
            LogManager.logError("ATProtoClient - Error during initialization: \(error)")
            await EventBus.shared.publish(.initializationFailed(error))
            // Consider how to handle initialization failure - maybe set a failed state
        }

        // Subscribe to account changes to update baseURL
        await subscribeToAccountChanges()

        // Start event subscriptions for managers AFTER they are fully initialized
        await configManager.startEventSubscription()
        // Add calls for other managers if they also need post-init event subscriptions
        // await tokenManager.startEventSubscription() // Example if TokenManager had one
        // await sessionManager.startEventSubscription() // Example if SessionManager had one

        // Publish an initialization completed event
        await EventBus.shared.publish(.initializationCompleted)
        LogManager.logInfo("ATProtoClient - Initialization complete.")
    }

    // MARK: - Initialization Helper Methods

    private func subscribeToAccountChanges() async {
        let eventStream = await EventBus.shared.subscribe()
        Task {
            for await event in eventStream {
                if case let .activeAccountChanged(did) = event {
                    LogManager.logInfo("ATProtoClient - Active account changed to \(did)")
                    if let account = await accountManager.getAccount(did: did),
                       let newPDSURL = account.pdsURL
                    {
                        await updateAllComponentsWithNewURL(newPDSURL)
                    } else {
                        // Handle case where new active account has no PDS URL?
                        // Maybe revert to default or log an error.
                        LogManager.logError("ATProtoClient - Switched to account \(did) with no PDS URL.")
                        // Consider reverting to default baseURL or handling appropriately
                        // await updateAllComponentsWithNewURL(URL(string: "https://bsky.social")!)
                    }
                }
            }
        }
    }

    private func publishInitializationStarted() async {
        await EventBus.shared.publish(.initializationStarted)
    }

    private func updateAllComponentsWithNewURL(_ newURL: URL) async {
        LogManager.logInfo("ATProtoClient - Updating all components with new URL: \(newURL)")

        baseURL = newURL
        pdsURL = newURL // Keep pdsURL updated as well
        await configManager.updatePDSURL(newURL) // ConfigManager now manages its own PDS/base URL state per account
        await networkManager.updateBaseURL(newURL)

        LogManager.logInfo("ATProtoClient - Base URL updated to: \(newURL)")
    }

    // getSession is less relevant now as state is managed per account
    // Keep it for potential direct use, but ensure it uses the active account context
    private func getSession() async throws -> ComAtprotoServerGetSession.Output {
        LogManager.logDebug("ATProtoClient - getSession called. Fetching for active account.")
        // This call implicitly uses the active account's tokens via NetworkManager/AuthProvider
        let sessionResponse = try await com.atproto.server.getSession()

        guard let sessionInfo = sessionResponse.data else {
            LogManager.logError("ATProtoClient - Failed to get session info from response.")
            throw APIError.invalidResponse // Or a more specific error
        }

        // Update the current account's data if needed (handle might change)
        if let currentDID = await accountManager.getActiveAccountDID() {
            if var account = await accountManager.getAccount(did: currentDID) {
                account.handle = sessionInfo.handle
                // Update PDS URL if it changed (though unlikely via getSession)
                if let serviceEndpoint = sessionInfo.didDoc?.service.first?.serviceEndpoint,
                   let serviceURL = URL(string: serviceEndpoint),
                   account.pdsURL != serviceURL
                {
                    account.pdsURL = serviceURL
                    await updateAllComponentsWithNewURL(serviceURL) // Update client state if PDS changed
                }
                try await accountManager.addOrUpdateAccount(account)
            }
        } else {
            LogManager.logDebug("ATProtoClient - getSession called without an active account.")
            // This case should ideally not happen if getSession requires authentication
        }

        return sessionInfo
    }

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

    // MARK: - Account Management Methods (New)

    /// Switches the active account.
    /// - Parameter did: The DID of the account to switch to.
    public func switchAccount(to did: String) async throws {
        LogManager.logInfo("ATProtoClient - Attempting to switch account to: \(did)")
        try await accountManager.switchAccount(to: did)
        // Event .activeAccountChanged will trigger state reloading in managers and ATProtoClient
    }

    /// Lists the DIDs of all managed accounts.
    /// - Returns: An array of DID strings.
    public func listAccounts() async -> [String] {
        return await accountManager.listAccountDIDs()
    }

    /// Gets the DID of the currently active account.
    /// - Returns: The active account's DID, or nil if none is active.
    public func getActiveAccountDID() async -> String? {
        return await accountManager.getActiveAccountDID()
    }

    /// Removes an account from the manager.
    /// - Parameter did: The DID of the account to remove.
    public func removeAccount(did: String) async throws {
        try await accountManager.removeAccount(did: did)
    }

    // MARK: - OAuth Flow Methods

    /// Starts the OAuth flow by obtaining the authorization URL.
    ///
    /// - Parameter identifier: The user's identifier.
    /// - Returns: The authorization URL to be presented to the user.
    public func startOAuthFlow(identifier: String) async throws -> URL {
        let authURL = try await authenticationService.startOAuthFlow(identifier: identifier)
        // Publish OAuth flow started event
        await EventBus.shared.publish(.oauthFlowStarted(authURL))
        return authURL
    }

    /// Handles the OAuth callback by processing the redirect URL.
    ///
    /// - Parameter url: The callback URL containing authorization data.
    public func handleOAuthCallback(url: URL) async throws {
        try await authenticationService.handleOAuthCallback(url: url)
        // Account switching and state updates are handled within AuthenticationService now
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
        // Account switching and state updates are handled within AuthenticationService now
        // Publish token updated event (already done in AuthenticationService)
    }

    // MARK: - Logout Method

    public func logout() async throws {
        // Delegate logout logic entirely to AuthenticationService
        try await authenticationService.logout()
        // AuthenticationService handles clearing tokens, DPoP keys, and removing/switching accounts.
        // It also publishes .logoutSucceeded

        // Optionally, notify delegate if needed, though logout might imply this
        // await authDelegate?.authenticationRequired(client: self) // Or a specific logout notification
    }

    // MARK: - Utility Functions

    /// Resolves a user's handle to their DID.
    ///
    /// - Parameter handle: The user's handle.
    /// - Returns: The resolved DID.
    public func resolveHandleToDID(handle: String) async throws -> String {
        // This is a general utility, doesn't need account context directly
        let didResolutionService = await DIDResolutionService(networkManager: networkManager)
        return try await didResolutionService.resolveHandleToDID(handle: handle)
    }

    /// Resolves a DID to the user's PDS URL by fetching their DID document.
    ///
    /// - Parameter did: The user's DID.
    /// - Returns: The PDS URL.
    public func resolveDIDToPDSURL(did: String) async throws -> URL {
        // This is a general utility, doesn't need account context directly
        let didResolutionService = await DIDResolutionService(networkManager: networkManager)
        let serviceURL = try await didResolutionService.resolveDIDToPDSURL(did: did)

        // Update internal pdsURL if resolving for the active user? Or rely on configManager?
        // Let's rely on configManager updating based on account switching.
        // If this DID matches the active DID, we could potentially update baseURL here too,
        // but the event-driven update in subscribeToAccountChanges is likely better.
        // if did == await accountManager.getActiveAccountDID() {
        //     await updateAllComponentsWithNewURL(serviceURL)
        // }

        // Publish PDS URL updated event (maybe redundant if configManager does it)
        // await EventBus.shared.publish(.baseURLUpdated(serviceURL))
        return serviceURL
    }

    private func updateNetworkManagerBaseURL() async {
        // This might be less relevant now, baseURL is updated on account switch
        if let activeDID = await accountManager.getActiveAccountDID(),
           let account = await accountManager.getAccount(did: activeDID),
           let pdsURL = account.pdsURL
        {
            await networkManager.updateBaseURL(pdsURL)
        } else {
            // Fallback or handle error if no active account/PDS URL
            LogManager.logDebug("ATProtoClient - updateNetworkManagerBaseURL called without active PDS URL.")
        }
    }

    /// Retrieves the current active user's handle.
    ///
    /// - Returns: The user's handle, if available.
    public func getHandle() async -> String? {
        // Get handle associated with the active account
        guard let activeDID = await accountManager.getActiveAccountDID(),
              let account = await accountManager.getAccount(did: activeDID)
        else {
            return nil
        }
        return account.handle
    }

    /// Retrieves the current active user's DID.
    ///
    /// - Returns: The user's DID, if available.
    public func getDid() async -> String? {
        // Simply return the active DID from accountManager
        return await accountManager.getActiveAccountDID()
    }

    /// Refreshes the access token if necessary for the active account.
    ///
    /// - Returns: A boolean indicating whether the refresh was successful.
    public func refreshToken() async throws -> Bool {
        // AuthenticationService handles refresh for the active account
        return try await authenticationService.refreshTokenIfNeeded()
    }

    /// Checks if the current session is valid for the active account.
    ///
    /// - Returns: A boolean indicating whether the session is valid.
    public func hasValidSession() async -> Bool {
        // SessionManager is now account-aware
        return await sessionManager.hasValidSession()
    }

    /// Initializes the session by fetching metadata and validating tokens for the active account.
    public func initializeSession() async throws {
        LogManager.logDebug("ATProtoClient - Initializing session.")
        do {
            // Base URL should be set based on active account during init or switch
            // Fetching metadata might need context or be generic? Assuming generic for now.
            // try await tokenManager.fetchAuthServerMetadataAndJWKS(baseURL: baseURL)
            // LogManager.logDebug("ATProtoClient - Authorization Server Metadata and JWKS fetched.")

            try await sessionManager.initializeIfNeeded() // SessionManager is account-aware
            LogManager.logDebug("ATProtoClient - SessionManager initialized.")

            let isValid = await hasValidSession()
            if isValid {
                LogManager.logInfo("ATProtoClient - Session is valid after initialization.")
                await EventBus.shared.publish(.sessionInitialized)
            } else {
                LogManager.logError("ATProtoClient - Session is invalid after initialization.")
                await EventBus.shared.publish(.sessionExpired)
            }
        } catch {
            LogManager.logError("ATProtoClient - Failed to initialize session: \(error)")
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
    public func getContentLabelers(from response: HTTPURLResponse) async -> [(did: String, redact: Bool)] {
        return await networkManager.extractContentLabelers(from: response)
    }

    // MARK: - SessionDelegate Protocol Methods (Now handled internally or via events)

    // func sessionRequiresReauthentication(sessionManager: SessionManager) async throws {
    //     await EventBus.shared.publish(.authenticationRequired)
    // }

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

            public lazy var team: Team = .init(networkManager: self.networkManager)

            public final class Team: @unchecked Sendable {
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

            public lazy var moderation: Moderation = .init(networkManager: self.networkManager)

            public final class Moderation: @unchecked Sendable {
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

            public lazy var embed: Embed = .init(networkManager: self.networkManager)

            public final class Embed: @unchecked Sendable {
                let networkManager: NetworkManaging
                init(networkManager: NetworkManaging) {
                    self.networkManager = networkManager
                }
            }

            public lazy var video: Video = .init(networkManager: self.networkManager)

            public final class Video: @unchecked Sendable {
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

            public lazy var moderation: Moderation = .init(networkManager: self.networkManager)

            public final class Moderation: @unchecked Sendable {
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

            public lazy var label: Label = .init(networkManager: self.networkManager)

            public final class Label: @unchecked Sendable {
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
