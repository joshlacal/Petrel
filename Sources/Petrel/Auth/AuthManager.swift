//
//  AuthManager.swift
//  Petrel
//
//  Coordinator class that manages authentication strategies and provides
//  factory methods to create the appropriate strategy based on configuration.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Coordinator class that manages authentication strategies.
/// Holds a reference to the active strategy and forwards all AuthStrategy methods to it.
actor AuthManager: AuthStrategy, AuthContinuityProviding {
    // MARK: - Types

    /// Authentication mode determining which strategy to use.
    enum Mode: Equatable {
        /// Legacy password-based authentication (App Passwords).
        case legacy
        /// Public OAuth for mobile/native apps (PAR + PKCE + DPoP).
        case publicOAuth
        /// Confidential gateway authentication via Nest.
        case gateway
        /// Client Assertion Backend — DPoP-bound client assertions for confidential browser-based apps.
        case cab(backendURL: URL)
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
    private var authContinuity: AuthContinuityState
    private var authContinuityObserver: (@Sendable () async -> Void)?

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
        authContinuity = AuthContinuityState(mode: mode.authMode)

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

        // Invalidate before cancelling the old strategy because cancellation is
        // an actor suspension point and must not leave stale work authorized.
        await invalidateAuthContinuity()

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
        authContinuity.commitMode(mode.authMode)
        await notifyAuthContinuityMutation()
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

        case let .cab(backendURL):
            return CABOAuthStrategy(
                backendURL: backendURL,
                storage: storage,
                accountManager: accountManager,
                networkService: networkService,
                oauthConfig: oauthConfig,
                didResolver: didResolver
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
        if currentMode == .gateway {
            // The callback may install or replace an opaque gateway session.
            // Invalidate before the strategy performs its first await.
            await invalidateAuthContinuity()
        }
        do {
            let result = try await activeStrategy.handleOAuthCallback(url: url)
            if currentMode == .gateway {
                await notifyAuthContinuityMutation()
            }
            return result
        } catch {
            if currentMode == .gateway {
                await notifyAuthContinuityMutation()
            }
            throw error
        }
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
        await invalidateAuthContinuity()
        do {
            try await activeStrategy.logout()
            await notifyAuthContinuityMutation()
        } catch {
            await notifyAuthContinuityMutation()
            throw error
        }
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
        if currentMode == .gateway,
           let gatewayBaseURL,
           isTerminalGatewayUnauthorized(data: data, request: request, gatewayURL: gatewayBaseURL)
        {
            // The strategy will clear the local session. Change continuity
            // before forwarding across the actor boundary.
            await invalidateAuthContinuity()
        }
        do {
            let result = try await activeStrategy.handleUnauthorizedResponse(response, data: data, for: request)
            if currentMode == .gateway,
               let gatewayBaseURL,
               isTerminalGatewayUnauthorized(data: data, request: request, gatewayURL: gatewayBaseURL)
            {
                await notifyAuthContinuityMutation()
            }
            return result
        } catch {
            if currentMode == .gateway,
               let gatewayBaseURL,
               isTerminalGatewayUnauthorized(data: data, request: request, gatewayURL: gatewayBaseURL)
            {
                await notifyAuthContinuityMutation()
            }
            throw error
        }
    }

    func updateDPoPNonce(for url: URL, from headers: [String: String], did: String?, jkt: String?) async {
        await activeStrategy.updateDPoPNonce(for: url, from: headers, did: did, jkt: jkt)
    }

    // MARK: - Authentication Continuity

    func installAuthContinuityObserver(_ observer: @escaping @Sendable () async -> Void) async {
        authContinuityObserver = observer
        await storage.setAuthContinuityObserver { [weak self] in
            await self?.invalidateAuthContinuityForStorageMutation()
        }
    }

    private func invalidateAuthContinuity() async {
        authContinuity.invalidate()
        await notifyAuthContinuityMutation()
    }

    private func notifyAuthContinuityMutation() async {
        await authContinuityObserver?()
    }

    private func invalidateAuthContinuityForStorageMutation() async {
        authContinuity.invalidate()
        await notifyAuthContinuityMutation()
    }

    func authContinuitySnapshot() async -> AuthContinuitySnapshot {
        while true {
            let generation = authContinuity.generation
            let mode = authContinuity.mode
            let exhausted = authContinuity.isExhausted

            guard mode == .gateway, !exhausted else {
                return authContinuity.snapshot
            }

            // Use the versioned persistent selector rather than AccountManager's
            // separately cached DID. KeychainStorage encloses selector and
            // gateway-session mutations in NetworkService revision signals.
            let did = try? await storage.getCurrentDID()
            let session: String?
            if let did, !did.isEmpty {
                session = try? await storage.getGatewaySession(for: did)
            } else {
                session = nil
            }

            // Calls above can re-enter this actor. Retry rather than combining
            // observations from two authentication generations or modes.
            guard authContinuity.generation == generation,
                  authContinuity.mode == mode,
                  authContinuity.isExhausted == exhausted
            else {
                continue
            }

            let identity: GatewayAuthIdentity? = if let did, !did.isEmpty, let session {
                GatewayAuthIdentity(did: did, session: session)
            } else {
                nil
            }
            let previousGeneration = authContinuity.generation
            authContinuity.observeGatewayIdentity(identity)
            if authContinuity.generation != previousGeneration {
                await notifyAuthContinuityMutation()
            }
            return authContinuity.snapshot
        }
    }
}

private extension AuthManager.Mode {
    var authMode: AuthMode {
        switch self {
        case .legacy:
            .legacy
        case .publicOAuth:
            .publicOAuth
        case .gateway:
            .gateway
        case let .cab(backendURL):
            .cab(backendURL: backendURL)
        }
    }
}
