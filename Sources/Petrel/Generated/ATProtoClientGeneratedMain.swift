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

/// Errors that can occur during API operations
enum APIError: String, Error {
    case expiredToken = "ExpiredToken"
    case invalidToken
    case invalidResponse
    case methodNotSupported
    case authorizationFailed
    case invalidPDSURL
    case serviceNotInitialized = "AuthenticationService not initialized"
}

// MARK: - Initialization State Enum

/// States for the initialization process
enum InitializationState: Equatable {
    static func == (lhs: InitializationState, rhs: InitializationState) -> Bool {
        switch (lhs, rhs) {
        case (.uninitialized, .uninitialized):
            return true
        case (.initializing, .initializing):
            return true
        case (.ready, .ready):
            return true
        case let (.failed(error1), .failed(error2)):
            return error1.localizedDescription == error2.localizedDescription
        default:
            return false
        }
    }

    case uninitialized
    case initializing
    case ready
    case failed(Error)
}

// MARK: - Client Environment Enum

/// Defines the environment for the client
public enum ClientEnvironment: Sendable {
    case production
    case testing
}

// MARK: - Authentication Delegate

/// Delegate protocol for authentication events.
public protocol AuthenticationDelegate: AnyObject, Sendable {
    /// Called when authentication is required.
    /// - Parameter client: The ATProtoClient that requires authentication.
    func authenticationRequired(client: ATProtoClient)
}

// MARK: - ATProtoClient Actor

/// The main client for interacting with the AT Protocol.
public actor ATProtoClient {
    // MARK: - Properties

    /// The network service used for all API requests.
    private let networkService: NetworkService

    /// The authentication service handling OAuth and token management.
    private let authService: AuthenticationService

    /// The account manager for handling multiple accounts.
    private let accountManager: AccountManager

    /// The DID resolver for resolving DIDs to handles and PDS URLs.
    private let didResolver: DIDResolving

    /// The storage layer for persistent data.
    private let storage: KeychainStorage

    /// The delegate for authentication events.
    private weak var authDelegate: AuthenticationDelegate?

    /// Temporary storage for account info after OAuth callback
    private var justAuthenticatedAccount: (did: String, handle: String?, pdsURL: URL)?

    /// Namespaces for the AT Protocol APIs.

    // MARK: - Initialization

    /// Initializes a new ATProtoClient with the specified configuration.
    /// - Parameters:
    ///   - baseURL: The base URL for API requests (default: bsky.social).
    ///   - oauthConfig: The OAuth configuration.
    ///   - namespace: The namespace for storage.
    ///   - userAgent: Optional user agent string for requests.
    ///   - didResolver: Optional custom DID resolver implementation.
    ///   - bskyAppViewDID: Optional custom Bluesky AppView service DID (default: did:web:api.bsky.app#bsky_appview).
    ///   - bskyChatDID: Optional custom Bluesky Chat service DID (default: did:web:api.bsky.chat#bsky_chat).
    public init(
        baseURL: URL = URL(string: "https://bsky.social")!,
        oauthConfig: OAuthConfig,
        namespace: String,
        userAgent: String? = nil,
        didResolver: DIDResolving? = nil,
        bskyAppViewDID: String = "did:web:api.bsky.app#bsky_appview",
        bskyChatDID: String = "did:web:api.bsky.chat#bsky_chat"
    ) async {
        // Initialize storage first
        storage = KeychainStorage(namespace: namespace)

        // Initialize account manager
        accountManager = await AccountManager(storage: storage)

        // Initialize network service first with nil authService
        networkService = NetworkService(baseURL: baseURL)

        // Configure service DIDs
        LogManager.logInfo("ATProtoClient - Initializing with bskyAppViewDID: \(bskyAppViewDID), bskyChatDID: \(bskyChatDID)")
        await networkService.setServiceDID(bskyAppViewDID, for: "app.bsky")
        await networkService.setServiceDID(bskyChatDID, for: "chat.bsky")

        if let userAgent = userAgent {
            await networkService.setUserAgent(userAgent)
        }
        // Create or use provided DID resolver before using it
        if let providedResolver = didResolver {
            self.didResolver = providedResolver
        } else {
            self.didResolver = await DIDResolutionService(networkService: networkService)
        }

        // Initialize auth service after networkService and didResolver
        authService = AuthenticationService(
            storage: storage,
            accountManager: accountManager,
            networkService: networkService,
            oauthConfig: oauthConfig,
            didResolver: self.didResolver
        )

        // Disable silent auto-switch on logout to avoid confusing UX in multi-account scenarios.
        // Catbird handles prompting and account selection explicitly.
        await authService.setAutoSwitchOnLogout(false)

        // Now set the authentication provider on the network service
        await networkService.setAuthenticationProvider(authService)

        // Validate and repair authentication state before initialization
        await validateAuthenticationState()

        // Try to initialize from stored account
        await initializeFromStoredAccount()
    }

    // MARK: - Initialization Helpers

    /// Validates and repairs authentication state to prevent race condition issues.
    private func validateAuthenticationState() async {
        let validationResult = await storage.validateAndRepairAuthenticationState()

        if validationResult.hasIssues {
            LogManager.logInfo("Authentication state validation completed: \(validationResult.summary)")

            // If we had to clean up orphaned accounts, notify the delegate
            if !validationResult.cleanedOrphanedAccounts.isEmpty {
                LogManager.logWarning("Cleaned up \(validationResult.cleanedOrphanedAccounts.count) orphaned accounts due to race condition. Users may need to re-authenticate.")
            }
        } else {
            LogManager.logDebug("Authentication state validation: no issues found")
        }
    }

    /// Attempts to initialize the client from a stored account.
    private func initializeFromStoredAccount() async {
        if let account = await accountManager.getCurrentAccount() {
            // Update the network service base URL
            await networkService.setBaseURL(account.pdsURL)
            
            // Load and apply service DIDs from stored account
            LogManager.logInfo("ATProtoClient - Loading service DIDs from stored account: bskyAppViewDID=\(account.bskyAppViewDID), bskyChatDID=\(account.bskyChatDID)")
            await networkService.setServiceDID(account.bskyAppViewDID, for: "app.bsky")
            await networkService.setServiceDID(account.bskyChatDID, for: "chat.bsky")

            // Check for interrupted refresh operations
            await handleAppStartup()

            // Check if tokens need refreshing
            do {
                _ = try await authService.refreshTokenIfNeeded()
            } catch let error as AuthError where error == .dpopKeyError {
                // If it's a DPoP error, let's try one more explicit refresh
                // This is a fallback in case we just need a fresh nonce
                LogManager.logInfo("Attempting one final explicit token refresh after DPoP error")
                do {
                    _ = try await authService.refreshTokenIfNeeded()
                } catch {
                    LogManager.logError("Final explicit refresh failed: \(error)")
                    authDelegate?.authenticationRequired(client: self)
                }
            } catch {
                // If refresh fails, trigger authentication required
                authDelegate?.authenticationRequired(client: self)
            }
        }
    }

    /// Handles application startup tasks like checking for interrupted token refresh
    private func handleAppStartup() async {
        // Check for interrupted refresh operations
        await authService.handleAppStartup()
    }

    /// Call this method when your app becomes active to check token refresh state
    public func applicationDidBecomeActive() {
        Task {
            await handleAppStartup()
        }
    }

    // MARK: - Account Information Methods

    /// Gets the DID (Decentralized Identifier) of the current active account.
    /// - Returns: The DID string of the current account
    public func getDid() async throws -> String {
        let (did, _, _) = await getActiveAccountInfo()
        guard let did = did else {
            throw APIError.serviceNotInitialized
        }
        return did
    }

    /// Gets the handle of the current active account.
    /// - Returns: The handle string of the current account
    public func getHandle() async throws -> String {
        let (_, handle, _) = await getActiveAccountInfo()
        guard let handle = handle else {
            throw APIError.serviceNotInitialized
        }
        return handle
    }

    /// Checks if the current session is valid.
    /// - Returns: Boolean indicating whether the session is valid
    public func hasValidSession() async -> Bool {
        let (did, _, _) = await getActiveAccountInfo()
        if did == nil {
            return false
        }

        do {
            let result = try await authService.refreshTokenIfNeeded()
            // Token is valid if it was refreshed or still valid (not just rate limited)
            return result != .skippedDueToRateLimit
        } catch {
            return false
        }
    }

    /// Refreshes the access token if needed.
    /// - Returns: Boolean indicating whether token was refreshed
    /// - Throws: Error if token refresh fails
    public func refreshToken() async throws -> Bool {
        let result = try await authService.refreshTokenIfNeeded()
        // Return true if token was actually refreshed
        return result == .refreshedSuccessfully
    }

    // MARK: - Moderation Methods

    /// Sets the labeler service to receive moderation reports
    /// - Parameter did: The DID of the labeler service
    public func setReportLabeler(did: String) async {
        await networkService.setHeader(name: "atproto-proxy", value: "\(did)#atproto_labeler")
    }

    /// Clears any previously set report labeler
    public func clearReportLabeler() async {
        await networkService.removeHeader(name: "atproto-proxy")
    }

    // MARK: - Authentication Flow Methods

    /// Starts the OAuth flow for account creation
    /// - Parameter pdsURL: The PDS URL to use (defaults to bsky.social)
    /// - Returns: The authorization URL to present to the user
    public func startSignUpFlow(pdsURL: URL = URL(string: "https://bsky.social")!) async throws -> URL {
        return try await authService.startOAuthFlowForSignUp(pdsURL: pdsURL)
    }

    // MARK: - Property Access

    /// Gets the base URL of the current service
    public var baseURL: URL {
        get async {
            if let account = await accountManager.getCurrentAccount() {
                return account.pdsURL
            } else {
                return await networkService.baseURL
            }
        }
    }

    // MARK: - Authentication Methods

    /// Sets the authentication delegate.
    /// - Parameter delegate: The delegate to set.
    public func setAuthenticationDelegate(_ delegate: AuthenticationDelegate) {
        authDelegate = delegate
    }

    /// Sets the authentication progress delegate.
    /// - Parameter delegate: The delegate to receive progress updates.
    public func setAuthProgressDelegate(_ delegate: AuthProgressDelegate?) async {
        await authService.setProgressDelegate(delegate)
    }

    /// Sets the authentication failure delegate.
    /// - Parameter delegate: The delegate to handle catastrophic failures.
    public func setFailureDelegate(_ delegate: AuthFailureDelegate?) async {
        await authService.setFailureDelegate(delegate)
    }

    /// Attempts to recover from catastrophic auth failures by resetting circuit breakers.
    /// Should be called when network connectivity is restored.
    /// - Parameter did: The DID to attempt recovery for, or nil for current account
    public func attemptRecoveryFromServerFailures(for did: String? = nil) async throws {
        try await authService.attemptRecoveryFromServerFailures(for: did)
    }

    /// Starts the OAuth flow for authentication.
    /// - Parameter identifier: The user identifier (handle), optional for sign-up.
    /// - Returns: The authorization URL to present to the user.
    public func startOAuthFlow(identifier: String? = nil, bskyAppViewDID: String? = nil, bskyChatDID: String? = nil) async throws -> URL {
        return try await authService.startOAuthFlow(identifier: identifier, bskyAppViewDID: bskyAppViewDID, bskyChatDID: bskyChatDID)
    }

    /// Handles the OAuth callback URL after user authentication.
    /// - Parameter url: The callback URL received from the authorization server.
    public func handleOAuthCallback(url: URL) async throws {
        // Get account info from auth service
        let accountInfo = try await authService.handleOAuthCallback(url: url)

        // Store it temporarily for immediate access
        justAuthenticatedAccount = accountInfo
        LogManager.logDebug("Stored temporary account info: \(accountInfo.did)")

        // After successful authentication, reinitialize the client state
        await initializeFromStoredAccount()
    }

    /// Logs out the current user.
    public func logout() async throws {
        try await authService.logout()
    }

    /// Cancels any ongoing OAuth authentication flows.
    public func cancelOAuthFlow() async {
        await authService.cancelOAuthFlow()
    }

    // MARK: - Account Management

    /// Gets the current account information.
    /// - Returns: A tuple containing the DID, handle, and PDS URL of the current account.
    public func getActiveAccountInfo() async -> (did: String?, handle: String?, pdsURL: URL?) {
        LogManager.logDebug("getActiveAccountInfo called")

        // Check temporary storage first (for immediate access after OAuth)
        if let tempAccount = justAuthenticatedAccount {
            LogManager.logDebug("Found temporary account: \(tempAccount.did)")

            // Always try AccountManager first, but don't clear temp storage yet
            if let account = await accountManager.getCurrentAccount(), account.did == tempAccount.did {
                LogManager.logDebug("AccountManager ready, using AccountManager but keeping temp storage")
                // Don't clear temp storage yet - let it persist for multiple calls during OAuth completion
                return (did: account.did, handle: account.handle, pdsURL: account.pdsURL)
            } else {
                LogManager.logDebug("AccountManager not ready, using temp account")
                // AccountManager not ready yet, return temp account
                return (did: tempAccount.did, handle: tempAccount.handle, pdsURL: tempAccount.pdsURL)
            }
        } else {
            LogManager.logDebug("No temporary account found")
        }

        // Fall back to normal AccountManager query
        LogManager.logDebug("Falling back to AccountManager query")
        if let account = await accountManager.getCurrentAccount() {
            LogManager.logDebug("AccountManager returned account: \(account.did)")
            return (did: account.did, handle: account.handle, pdsURL: account.pdsURL)
        } else {
            LogManager.logWarning("AccountManager returned nil - authentication state may be inconsistent")
            return (did: nil, handle: nil, pdsURL: nil)
        }
    }

    /// Clears temporary account storage after OAuth completion
    public func clearTemporaryAccountStorage() async {
        LogManager.logDebug("Clearing temporary account storage")
        justAuthenticatedAccount = nil
    }

    /// Lists all available accounts.
    /// - Returns: An array of accounts.
    public func listAccounts() async -> [Account] {
        return await accountManager.listAccounts()
    }

    /// Switches to the specified account.
    /// - Parameter did: The DID of the account to switch to.
    public func switchToAccount(did: String) async throws {
        try await accountManager.setCurrentAccount(did: did)

        // Update network service base URL and service DIDs
        if let account = await accountManager.getAccount(did: did) {
            await networkService.setBaseURL(account.pdsURL)
            
            // Load and apply service DIDs from account
            LogManager.logInfo("ATProtoClient - Loading service DIDs from account: bskyAppViewDID=\(account.bskyAppViewDID), bskyChatDID=\(account.bskyChatDID)")
            await networkService.setServiceDID(account.bskyAppViewDID, for: "app.bsky")
            await networkService.setServiceDID(account.bskyChatDID, for: "chat.bsky")
        }
    }

    /// Removes an account.
    /// - Parameter did: The DID of the account to remove.
    public func removeAccount(did: String) async throws {
        try await accountManager.removeAccount(did: did)
    }
    
    /// Updates the service DID mappings for app.bsky and chat.bsky namespaces.
    /// Use this to change the AppView or Chat service after client initialization.
    /// - Parameters:
    ///   - bskyAppViewDID: The new Bluesky AppView service DID
    ///   - bskyChatDID: The new Bluesky Chat service DID
    public func updateServiceDIDs(bskyAppViewDID: String, bskyChatDID: String) async {
        LogManager.logInfo("ATProtoClient - Updating service DIDs: bskyAppViewDID=\(bskyAppViewDID), bskyChatDID=\(bskyChatDID)")
        await networkService.setServiceDID(bskyAppViewDID, for: "app.bsky")
        await networkService.setServiceDID(bskyChatDID, for: "chat.bsky")
    }
    
    /// Updates the service DIDs for the current account and persists them.
    /// This is the primary method for changing service DIDs after login.
    /// - Parameters:
    ///   - bskyAppViewDID: The new Bluesky AppView service DID
    ///   - bskyChatDID: The new Bluesky Chat service DID
    public func updateAndPersistServiceDIDs(bskyAppViewDID: String, bskyChatDID: String) async throws {
        // Update NetworkService mappings
        await updateServiceDIDs(bskyAppViewDID: bskyAppViewDID, bskyChatDID: bskyChatDID)
        
        // Persist to account storage
        try await accountManager.updateServiceDIDs(bskyAppViewDID: bskyAppViewDID, bskyChatDID: bskyChatDID)
        
        LogManager.logInfo("ATProtoClient - Service DIDs updated and persisted for current account")
    }
    
    /// Gets the current account information including service DIDs.
    /// - Returns: The current account if available, or nil if not authenticated.
    public func getCurrentAccount() async -> Account? {
        return await accountManager.getCurrentAccount()
    }

    // MARK: - DID Resolution

    /// Resolves a handle to a DID.
    /// - Parameter handle: The handle to resolve.
    /// - Returns: The resolved DID.
    public func resolveHandleToDID(handle: String) async throws -> String {
        return try await didResolver.resolveHandleToDID(handle: handle)
    }

    /// Resolves a DID to a PDS URL.
    /// - Parameter did: The DID to resolve.
    /// - Returns: The resolved PDS URL.
    public func resolveDIDToPDSURL(did: String) async throws -> URL {
        return try await didResolver.resolveDIDToPDSURL(did: did)
    }

    // MARK: - Header Management

    /// Sets a custom header for all requests.
    /// - Parameters:
    ///   - name: The header name.
    ///   - value: The header value.
    public func setHeader(name: String, value: String) async {
        await networkService.setHeader(name: name, value: value)
    }

    /// Removes a custom header.
    /// - Parameter name: The header name to remove.
    public func removeHeader(name: String) async {
        await networkService.removeHeader(name: name)
    }

    /// Sets the user agent for all requests.
    /// - Parameter userAgent: The user agent string.
    public func setUserAgent(_ userAgent: String) async {
        await networkService.setHeader(name: "User-Agent", value: userAgent)
    }

    // MARK: - Generated API Namespaced Classes

    public lazy var app: App = .init(networkService: self.networkService)

    public final class App: @unchecked Sendable {
        let networkService: NetworkService
        init(networkService: NetworkService) {
            self.networkService = networkService
        }

        public lazy var bsky: Bsky = .init(networkService: self.networkService)

        public final class Bsky: @unchecked Sendable {
            let networkService: NetworkService
            init(networkService: NetworkService) {
                self.networkService = networkService
            }

            public lazy var video: Video = .init(networkService: self.networkService)

            public final class Video: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var bookmark: Bookmark = .init(networkService: self.networkService)

            public final class Bookmark: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var embed: Embed = .init(networkService: self.networkService)

            public final class Embed: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var notification: Notification = .init(networkService: self.networkService)

            public final class Notification: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var unspecced: Unspecced = .init(networkService: self.networkService)

            public final class Unspecced: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var graph: Graph = .init(networkService: self.networkService)

            public final class Graph: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var feed: Feed = .init(networkService: self.networkService)

            public final class Feed: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var richtext: Richtext = .init(networkService: self.networkService)

            public final class Richtext: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var actor: Actor = .init(networkService: self.networkService)

            public final class Actor: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var labeler: Labeler = .init(networkService: self.networkService)

            public final class Labeler: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }
        }
    }

    public lazy var chat: Chat = .init(networkService: self.networkService)

    public final class Chat: @unchecked Sendable {
        let networkService: NetworkService
        init(networkService: NetworkService) {
            self.networkService = networkService
        }

        public lazy var bsky: Bsky = .init(networkService: self.networkService)

        public final class Bsky: @unchecked Sendable {
            let networkService: NetworkService
            init(networkService: NetworkService) {
                self.networkService = networkService
            }

            public lazy var convo: Convo = .init(networkService: self.networkService)

            public final class Convo: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var actor: Actor = .init(networkService: self.networkService)

            public final class Actor: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var moderation: Moderation = .init(networkService: self.networkService)

            public final class Moderation: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }
        }
    }

    public lazy var com: Com = .init(networkService: self.networkService)

    public final class Com: @unchecked Sendable {
        let networkService: NetworkService
        init(networkService: NetworkService) {
            self.networkService = networkService
        }

        public lazy var atproto: Atproto = .init(networkService: self.networkService)

        public final class Atproto: @unchecked Sendable {
            let networkService: NetworkService
            init(networkService: NetworkService) {
                self.networkService = networkService
            }

            public lazy var temp: Temp = .init(networkService: self.networkService)

            public final class Temp: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var identity: Identity = .init(networkService: self.networkService)

            public final class Identity: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var admin: Admin = .init(networkService: self.networkService)

            public final class Admin: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var label: Label = .init(networkService: self.networkService)

            public final class Label: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var server: Server = .init(networkService: self.networkService)

            public final class Server: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var lexicon: Lexicon = .init(networkService: self.networkService)

            public final class Lexicon: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var sync: Sync = .init(networkService: self.networkService)

            public final class Sync: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var repo: Repo = .init(networkService: self.networkService)

            public final class Repo: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }

            public lazy var moderation: Moderation = .init(networkService: self.networkService)

            public final class Moderation: @unchecked Sendable {
                let networkService: NetworkService
                init(networkService: NetworkService) {
                    self.networkService = networkService
                }
            }
        }
    }
}
