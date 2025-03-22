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
            //            await configManager.waitForInitialization()

            if let savedPDSURL = await configManager.getPDSURL() {
                LogManager.logInfo("ATProtoClient - Using saved PDS URL: \(savedPDSURL)")
                self.baseURL = savedPDSURL
                await updateAllComponentsWithNewURL(savedPDSURL)
            } else {
                LogManager.logDebug(
                    "ATProtoClient - No saved PDS URL found, using default: \(baseURL)")
            }

            //            _ = try await getSession()
            //            // Then initialize the OAuth state
            try await authenticationService.initializeOAuthState()

            // First, try to refresh the token if needed
            if try await authenticationService.refreshTokenIfNeeded() {
                LogManager.logInfo("Token refreshed successfully")
            }

            // Attempt to make a simple authenticated request to verify everything is working
            do {
                let _ = try await com.atproto.server.describeServer()
                LogManager.logInfo("Client state initialized successfully")
            } catch {
                LogManager.logError("Failed to initialize client state: \(error)")
                throw error
            }

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
            did: sessionInfo.did,
            handle: sessionInfo.handle,
            serviceEndpoint: endpoint
        )

        did = sessionInfo.did
        handle = sessionInfo.handle

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
        // Clear session and tokens first
        try await middlewareService.clearSession()
        try await tokenManager.deleteTokens()

        // Clear DPoP state
        await authenticationService.deleteDPoPKey()

        // Clear any other OAuth-related state
        try KeychainManager.delete(key: "codeVerifier", namespace: namespace)
        try KeychainManager.delete(key: "state", namespace: namespace)
        try KeychainManager.delete(key: "isAuthenticated", namespace: namespace)

        // Notify delegate that authentication is required
        await authDelegate?.authenticationRequired(client: self)
    }

    // MARK: - Utility Functions

    /// Resolves a user's handle to their DID.
    ///
    /// - Parameter handle: The user's handle.
    /// - Returns: The resolved DID.
    public func resolveHandleToDID(handle: String) async throws -> String {
        let input = ComAtprotoIdentityResolveHandle.Parameters(handle: handle)
        let (responseCode, data) = try await com.atproto.identity.resolveHandle(input: input)
        guard responseCode == 200, let did = data?.did else {
            throw APIError.invalidPDSURL
        }
        return did
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
            return try await getSession().handle
        }
        return handle
    }

    /// Retrieves the current user's DID.
    ///
    /// - Returns: The user's DID, if available.
    public func getDid() async throws -> String {
        guard let did = await configManager.getDID() else {
            return try await getSession().did
        }

        return did
    }

    /// Refreshes the access token if necessary.
    ///
    /// - Returns: A boolean indicating whether the refresh was successful.
    public func refreshToken() async throws -> Bool {
        let refreshed = try await authenticationService.refreshTokenIfNeeded()
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
    public func getContentLabelers(from response: HTTPURLResponse) async -> [(did: String, redact: Bool)] {
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
            //            // Add cases for additional events as needed
            default:
                break
            }
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

            public lazy var set: Set = .init(networkManager: self.networkManager)

            public final class Set: @unchecked Sendable {
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

            public lazy var actor: Actor = .init(networkManager: self.networkManager)

            public final class Actor: @unchecked Sendable {
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
