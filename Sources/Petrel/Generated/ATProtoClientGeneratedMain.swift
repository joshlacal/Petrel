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
enum APIError: String, Error, LocalizedError {
  case expiredToken = "ExpiredToken"
  case invalidToken
  case invalidResponse
  case methodNotSupported
  case authorizationFailed
  case invalidPDSURL
  case serviceNotInitialized = "AuthenticationService not initialized"

  var errorDescription: String? {
    switch self {
    case .expiredToken:
      return "Authentication token has expired."
    case .invalidToken:
      return "Authentication token is invalid."
    case .invalidResponse:
      return "Server returned an invalid response."
    case .methodNotSupported:
      return "The requested operation is not supported."
    case .authorizationFailed:
      return "Authorization failed."
    case .invalidPDSURL:
      return "Personal Data Server URL is invalid."
    case .serviceNotInitialized:
      return "Authentication service is not initialized."
    }
  }

  var failureReason: String? {
    switch self {
    case .expiredToken:
      return "Your session has timed out for security reasons."
    case .invalidToken:
      return "The authentication credentials are corrupted or malformed."
    case .invalidResponse:
      return "The server response does not match the expected format."
    case .methodNotSupported:
      return "This feature is not available with the current server configuration."
    case .authorizationFailed:
      return "The server rejected your authentication credentials."
    case .invalidPDSURL:
      return "The Personal Data Server address cannot be reached or is misconfigured."
    case .serviceNotInitialized:
      return "The app's authentication system has not been properly set up."
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .expiredToken:
      return "Please log out and log back in to refresh your session."
    case .invalidToken:
      return "Please log out and log back in to restore your credentials."
    case .invalidResponse:
      return
        "Please try again. If the problem persists, check your internet connection or contact support."
    case .methodNotSupported:
      return "Please update the app or contact support for assistance."
    case .authorizationFailed:
      return "Check your login credentials and try again."
    case .invalidPDSURL:
      return "Please check your server settings or contact your service provider."
    case .serviceNotInitialized:
      return "Please restart the app. If the problem persists, contact support."
    }
  }
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
    case (.failed(let error1), .failed(let error2)):
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

  // Readiness gate to avoid races during app activation / URL callbacks
  private var isReady: Bool = false
  private var pendingOAuthCallbacks: [URL] = []

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
  public init(
    baseURL: URL = URL(string: "https://bsky.social")!,
    oauthConfig: OAuthConfig,
    namespace: String,
    userAgent: String? = nil
  ) async {
    // Initialize storage first
    storage = KeychainStorage(namespace: namespace)

    // Initialize account manager
    accountManager = await AccountManager(storage: storage)

    // Initialize network service first with nil authService
    networkService = NetworkService(baseURL: baseURL)

    if let userAgent = userAgent {
      await networkService.setUserAgent(userAgent)
    }
    // Create DID resolver
    self.didResolver = await DIDResolutionService(networkService: networkService)

    // Initialize auth service after networkService and didResolver
    authService = AuthenticationService(
      storage: storage,
      accountManager: accountManager,
      networkService: networkService,
      oauthConfig: oauthConfig,
      didResolver: self.didResolver
    )

    // Now set the authentication provider on the network service
    await networkService.setAuthenticationProvider(authService)

    // Try to initialize from stored account
    await initializeFromStoredAccount()

    // Mark client ready and drain any pending OAuth callbacks saved during early startup
    await markReady()
  }

  // MARK: - Initialization Helpers

  /// Attempts to initialize the client from a stored account.
  private func initializeFromStoredAccount() async {
    if let account = await accountManager.getCurrentAccount() {
      // Update the network service base URL
      await networkService.setBaseURL(account.pdsURL)

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

  // MARK: - Readiness Gating

  private func markReady() async {
    isReady = true
    // Drain any callbacks queued in memory during initialization
    if !pendingOAuthCallbacks.isEmpty {
      let callbacks = pendingOAuthCallbacks
      pendingOAuthCallbacks.removeAll()
      for url in callbacks {
        LogManager.logInfo("Draining queued in-memory OAuth callback after readiness")
        do { try await handleOAuthCallback(url: url) } catch {
          LogManager.logError("Queued OAuth callback failed: \(error)")
        }
      }
    }
    // Also drain any persisted callback captured before process readiness
    await drainPendingOAuthCallbackIfAny()
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

  #if DEBUG
    /// Simulates an ambiguous refresh timeout for the current account. Testing hook.
    public func simulateAmbiguousRefreshTimeout(durationSeconds: TimeInterval = 900) async {
      if let did = await accountManager.getCurrentAccount()?.did {
        await authService.markAmbiguousRefresh(for: did, durationSeconds: durationSeconds)
      }
    }
  #endif

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
  public func startSignUpFlow(pdsURL: URL = URL(string: "https://bsky.social")!) async throws -> URL
  {
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

  /// Starts the OAuth flow for authentication.
  /// - Parameter identifier: The user identifier (handle), optional for sign-up.
  /// - Returns: The authorization URL to present to the user.
  public func startOAuthFlow(identifier: String? = nil) async throws -> URL {
    return try await authService.startOAuthFlow(identifier: identifier)
  }

  /// Handles the OAuth callback URL after user authentication.
  /// - Parameter url: The callback URL received from the authorization server.
  public func handleOAuthCallback(url: URL) async throws {
    // If client isn't ready yet, queue the callback and return; it will be processed on readiness
    if !isReady {
      pendingOAuthCallbacks.append(url)
      LogManager.logInfo("Queued OAuth callback until client is ready")
      return
    }
    // Get account info from auth service
    let accountInfo = try await authService.handleOAuthCallback(url: url)

    // Store it temporarily for immediate access
    justAuthenticatedAccount = accountInfo
    LogManager.logInfo("🔍 DEBUG: Stored temporary account info: \(accountInfo.did)")

    // After successful authentication, reinitialize the client state
    await initializeFromStoredAccount()
  }

  /// Drain a pending OAuth callback captured during early startup, if present.
  private func drainPendingOAuthCallbackIfAny() async {
    if let pending = OAuthCallbackBuffer.take() {
      LogManager.logInfo("Processing pending OAuth callback captured during startup")
      do { try await handleOAuthCallback(url: pending) } catch {
        LogManager.logError("Processing pending OAuth callback failed: \(error)")
      }
    }
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
    LogManager.logInfo("🔍 DEBUG: getActiveAccountInfo called")

    // Check temporary storage first (for immediate access after OAuth)
    if let tempAccount = justAuthenticatedAccount {
      LogManager.logInfo("🔍 DEBUG: Found temporary account: \(tempAccount.did)")

      // Always try AccountManager first, but don't clear temp storage yet
      if let account = await accountManager.getCurrentAccount(), account.did == tempAccount.did {
        LogManager.logInfo(
          "🔍 DEBUG: AccountManager ready, using AccountManager but keeping temp storage")
        // Don't clear temp storage yet - let it persist for multiple calls during OAuth completion
        return (did: account.did, handle: account.handle, pdsURL: account.pdsURL)
      } else {
        LogManager.logInfo("🔍 DEBUG: AccountManager not ready, using temp account")
        // AccountManager not ready yet, return temp account
        return (did: tempAccount.did, handle: tempAccount.handle, pdsURL: tempAccount.pdsURL)
      }
    } else {
      LogManager.logInfo("🔍 DEBUG: No temporary account found")
    }

    // Fall back to normal AccountManager query
    LogManager.logInfo("🔍 DEBUG: Falling back to AccountManager query")
    if let account = await accountManager.getCurrentAccount() {
      LogManager.logInfo("🔍 DEBUG: AccountManager returned account: \(account.did)")
      return (did: account.did, handle: account.handle, pdsURL: account.pdsURL)
    } else {
      LogManager.logInfo("🔍 DEBUG: AccountManager returned nil - this is the problem!")
      return (did: nil, handle: nil, pdsURL: nil)
    }
  }

  /// Clears temporary account storage after OAuth completion
  public func clearTemporaryAccountStorage() async {
    LogManager.logInfo("🔍 DEBUG: Clearing temporary account storage")
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

    // Update network service base URL
    if let account = await accountManager.getAccount(did: did) {
      await networkService.setBaseURL(account.pdsURL)
    }
  }

  /// Removes an account.
  /// - Parameter did: The DID of the account to remove.
  public func removeAccount(did: String) async throws {
    try await accountManager.removeAccount(did: did)
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

  /// Sets the user agent for all requests.
  /// - Parameter userAgent: The user agent string.
  public func setUserAgent(_ userAgent: String) async {
    await networkService.setHeader(name: "User-Agent", value: userAgent)
  }

  // MARK: - Generated API Namespaced Classes

  public lazy var app: App = {
    return App(networkService: self.networkService)
  }()

  public final class App: @unchecked Sendable {
    internal let networkService: NetworkService
    internal init(networkService: NetworkService) {
      self.networkService = networkService
    }

    public lazy var bsky: Bsky = {
      return Bsky(networkService: self.networkService)
    }()

    public final class Bsky: @unchecked Sendable {
      internal let networkService: NetworkService
      internal init(networkService: NetworkService) {
        self.networkService = networkService
      }

      public lazy var video: Video = {
        return Video(networkService: self.networkService)
      }()

      public final class Video: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var bookmark: Bookmark = {
        return Bookmark(networkService: self.networkService)
      }()

      public final class Bookmark: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var embed: Embed = {
        return Embed(networkService: self.networkService)
      }()

      public final class Embed: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var notification: Notification = {
        return Notification(networkService: self.networkService)
      }()

      public final class Notification: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var unspecced: Unspecced = {
        return Unspecced(networkService: self.networkService)
      }()

      public final class Unspecced: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var graph: Graph = {
        return Graph(networkService: self.networkService)
      }()

      public final class Graph: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var feed: Feed = {
        return Feed(networkService: self.networkService)
      }()

      public final class Feed: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var actor: Actor = {
        return Actor(networkService: self.networkService)
      }()

      public final class Actor: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var richtext: Richtext = {
        return Richtext(networkService: self.networkService)
      }()

      public final class Richtext: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var labeler: Labeler = {
        return Labeler(networkService: self.networkService)
      }()

      public final class Labeler: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }
    }
  }

  public lazy var chat: Chat = {
    return Chat(networkService: self.networkService)
  }()

  public final class Chat: @unchecked Sendable {
    internal let networkService: NetworkService
    internal init(networkService: NetworkService) {
      self.networkService = networkService
    }

    public lazy var bsky: Bsky = {
      return Bsky(networkService: self.networkService)
    }()

    public final class Bsky: @unchecked Sendable {
      internal let networkService: NetworkService
      internal init(networkService: NetworkService) {
        self.networkService = networkService
      }

      public lazy var convo: Convo = {
        return Convo(networkService: self.networkService)
      }()

      public final class Convo: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var moderation: Moderation = {
        return Moderation(networkService: self.networkService)
      }()

      public final class Moderation: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var actor: Actor = {
        return Actor(networkService: self.networkService)
      }()

      public final class Actor: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }
    }
  }

  public lazy var com: Com = {
    return Com(networkService: self.networkService)
  }()

  public final class Com: @unchecked Sendable {
    internal let networkService: NetworkService
    internal init(networkService: NetworkService) {
      self.networkService = networkService
    }

    public lazy var atproto: Atproto = {
      return Atproto(networkService: self.networkService)
    }()

    public final class Atproto: @unchecked Sendable {
      internal let networkService: NetworkService
      internal init(networkService: NetworkService) {
        self.networkService = networkService
      }

      public lazy var temp: Temp = {
        return Temp(networkService: self.networkService)
      }()

      public final class Temp: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var identity: Identity = {
        return Identity(networkService: self.networkService)
      }()

      public final class Identity: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var admin: Admin = {
        return Admin(networkService: self.networkService)
      }()

      public final class Admin: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var server: Server = {
        return Server(networkService: self.networkService)
      }()

      public final class Server: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var label: Label = {
        return Label(networkService: self.networkService)
      }()

      public final class Label: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var sync: Sync = {
        return Sync(networkService: self.networkService)
      }()

      public final class Sync: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var repo: Repo = {
        return Repo(networkService: self.networkService)
      }()

      public final class Repo: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var lexicon: Lexicon = {
        return Lexicon(networkService: self.networkService)
      }()

      public final class Lexicon: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }

      public lazy var moderation: Moderation = {
        return Moderation(networkService: self.networkService)
      }()

      public final class Moderation: @unchecked Sendable {
        internal let networkService: NetworkService
        internal init(networkService: NetworkService) {
          self.networkService = networkService
        }

      }
    }
  }

}
