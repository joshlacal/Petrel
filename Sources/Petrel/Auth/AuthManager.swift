//
//  AuthManager.swift
//  Petrel
//
//  Coordinator class that manages authentication strategies and provides
//  factory methods to create the appropriate strategy based on configuration.
//

import Foundation

/// Coordinator class that manages authentication strategies.
/// Holds a reference to the active strategy and forwards all AuthStrategy methods to it.
actor AuthManager: AuthStrategy {
    // MARK: - Types

    /// Authentication mode determining which strategy to use.
    enum Mode: Sendable {
        /// Legacy password-based authentication (App Passwords).
        case legacy
        /// Public OAuth for mobile/native apps (PAR + PKCE + DPoP).
        case publicOAuth
        /// Confidential gateway authentication via Nest.
        case gateway
    }

    /// Error types specific to AuthManager.
    enum ManagerError: Error, LocalizedError {
        case gatewayURLRequired
        case strategyCreationFailed

        var errorDescription: String? {
            switch self {
            case .gatewayURLRequired:
                return "Gateway mode requires a gatewayBaseURL"
            case .strategyCreationFailed:
                return "Failed to create authentication strategy"
            }
        }
    }

    // MARK: - Properties

    private var activeStrategy: AuthStrategy
    private let storage: KeychainStorage
    private let accountManager: AccountManaging
    private let networkService: NetworkService
    private let oauthConfig: OAuthConfig
    private let didResolver: DIDResolving
    private let gatewayBaseURL: URL?

    /// The current authentication mode.
    private(set) var currentMode: Mode

    // MARK: - Initialization

    /// Creates an AuthManager with the specified mode and dependencies.
    /// - Parameters:
    ///   - mode: The authentication mode to use.
    ///   - storage: Keychain storage for persisting credentials.
    ///   - accountManager: Manager for account state.
    ///   - networkService: Network service for API calls.
    ///   - oauthConfig: OAuth configuration for public OAuth flow.
    ///   - didResolver: Resolver for DID and handle lookups.
    ///   - gatewayBaseURL: Base URL for gateway mode (required if mode is .gateway).
    /// - Throws: `ManagerError.gatewayURLRequired` if gateway mode is requested without a URL.
    init(
        mode: Mode,
        storage: KeychainStorage,
        accountManager: AccountManaging,
        networkService: NetworkService,
        oauthConfig: OAuthConfig,
        didResolver: DIDResolving,
        gatewayBaseURL: URL? = nil
    ) throws {
        self.storage = storage
        self.accountManager = accountManager
        self.networkService = networkService
        self.oauthConfig = oauthConfig
        self.didResolver = didResolver
        self.gatewayBaseURL = gatewayBaseURL
        currentMode = mode

        activeStrategy = try Self.createStrategy(
            mode: mode,
            storage: storage,
            accountManager: accountManager,
            networkService: networkService,
            oauthConfig: oauthConfig,
            didResolver: didResolver,
            gatewayBaseURL: gatewayBaseURL
        )
    }

    // MARK: - Mode Switching

    /// Switches to a different authentication mode.
    /// - Parameter mode: The new authentication mode.
    /// - Throws: `ManagerError.gatewayURLRequired` if gateway mode is requested without a URL.
    func switchMode(_ mode: Mode) async throws {
        guard mode != currentMode else { return }

        // Cancel any ongoing OAuth flow before switching
        await activeStrategy.cancelOAuthFlow()

        activeStrategy = try Self.createStrategy(
            mode: mode,
            storage: storage,
            accountManager: accountManager,
            networkService: networkService,
            oauthConfig: oauthConfig,
            didResolver: didResolver,
            gatewayBaseURL: gatewayBaseURL
        )
        currentMode = mode
    }

    // MARK: - Strategy Factory

    private static func createStrategy(
        mode: Mode,
        storage: KeychainStorage,
        accountManager: AccountManaging,
        networkService: NetworkService,
        oauthConfig: OAuthConfig,
        didResolver: DIDResolving,
        gatewayBaseURL: URL?
    ) throws -> AuthStrategy {
        switch mode {
        case .legacy:
            return LegacyPasswordStrategy(
                storage: storage,
                accountManager: accountManager,
                networkService: networkService,
                didResolver: didResolver
            )

        case .publicOAuth:
            return PublicOAuthStrategy(
                storage: storage,
                accountManager: accountManager,
                networkService: networkService,
                oauthConfig: oauthConfig,
                didResolver: didResolver
            )

        case .gateway:
            guard let gatewayURL = gatewayBaseURL else {
                throw ManagerError.gatewayURLRequired
            }
            return ConfidentialGatewayStrategy(
                gatewayURL: gatewayURL,
                storage: storage,
                accountManager: accountManager
            )
        }
    }

    // MARK: - AuthStrategy Forwarding

    func startOAuthFlow(
        identifier: String?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> URL {
        try await activeStrategy.startOAuthFlow(
            identifier: identifier,
            bskyAppViewDID: bskyAppViewDID,
            bskyChatDID: bskyChatDID
        )
    }

    func startOAuthFlowForSignUp(
        pdsURL: URL?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> URL {
        try await activeStrategy.startOAuthFlowForSignUp(
            pdsURL: pdsURL,
            bskyAppViewDID: bskyAppViewDID,
            bskyChatDID: bskyChatDID
        )
    }

    func handleOAuthCallback(url: URL) async throws -> (did: String, handle: String?, pdsURL: URL) {
        try await activeStrategy.handleOAuthCallback(url: url)
    }

    func loginWithPassword(
        identifier: String,
        password: String,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> (did: String, handle: String?, pdsURL: URL) {
        try await activeStrategy.loginWithPassword(
            identifier: identifier,
            password: password,
            bskyAppViewDID: bskyAppViewDID,
            bskyChatDID: bskyChatDID
        )
    }

    func logout() async throws {
        try await activeStrategy.logout()
    }

    func cancelOAuthFlow() async {
        await activeStrategy.cancelOAuthFlow()
    }

    func tokensExist() async -> Bool {
        await activeStrategy.tokensExist()
    }

    func setProgressDelegate(_ delegate: AuthProgressDelegate?) async {
        await activeStrategy.setProgressDelegate(delegate)
    }

    func setFailureDelegate(_ delegate: AuthFailureDelegate?) async {
        await activeStrategy.setFailureDelegate(delegate)
    }

    func attemptRecoveryFromServerFailures(for did: String?) async throws {
        try await activeStrategy.attemptRecoveryFromServerFailures(for: did)
    }

    // MARK: - AuthenticationProvider Forwarding

    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        try await activeStrategy.prepareAuthenticatedRequest(request)
    }

    func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (URLRequest, AuthContext) {
        try await activeStrategy.prepareAuthenticatedRequestWithContext(request)
    }

    func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
        try await activeStrategy.refreshTokenIfNeeded()
    }

    func handleUnauthorizedResponse(
        _ response: HTTPURLResponse,
        data: Data,
        for request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        try await activeStrategy.handleUnauthorizedResponse(response, data: data, for: request)
    }

    func updateDPoPNonce(for url: URL, from headers: [String: String], did: String?, jkt: String?) async {
        await activeStrategy.updateDPoPNonce(for: url, from: headers, did: did, jkt: jkt)
    }
}
