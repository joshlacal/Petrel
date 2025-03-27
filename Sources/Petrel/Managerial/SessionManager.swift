//
//  SessionManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/21/24.
//

import Foundation

// MARK: - SessionManaging Protocol

protocol SessionManaging: Actor {
    func hasValidSession() async -> Bool
    func isUserLoggedIn() async -> Bool
    func initializeIfNeeded() async throws

    // Add new methods for multi-account support
    func hasValidSessionForDID(_ did: String) async -> Bool
    func setAuthenticatedStateForDID(_ did: String, authenticated: Bool) async
    func isAnyUserLoggedIn() async -> Bool
    func switchToDID(_ did: String) async throws -> Bool
    func getCurrentActiveDID() async -> String?

    // Add delegate method for notifying about DID switching
    func setDelegate(_ delegate: SessionManagerDelegate?) async
}

// MARK: - SessionManagerDelegate Protocol

protocol SessionManagerDelegate: AnyObject, Sendable {
    func didSwitchToDID(_ did: String) async
    func sessionInitialized() async
    func authenticationRequired() async
    func sessionExpired() async
    func networkError(_ error: Error) async
}

// MARK: - SessionManager Actor

actor SessionManager: SessionManaging {
    // MARK: - Properties

    private let tokenManager: TokenManaging
    private let middlewareService: MiddlewareServicing
    private let namespace: String
    private var lastSessionCheckTime: Date = .distantPast
    private let sessionCheckInterval: TimeInterval = 5 // 5 seconds
    private(set) var isAuthenticated: Bool = false
    private var isInitializing: Bool = false
    private var tokenCheckTask: Task<Void, Never>?

    // Multi-account support
    private var didToSessionMap: [String: Bool] = [:] // Track authentication state per DID
    private var didLastCheckTime: [String: Date] = [:] // Track last check time per DID

    // Delegate for notifications instead of EventBus
    private weak var delegate: SessionManagerDelegate?

    // MARK: - Initialization

    init(tokenManager: TokenManaging, middlewareService: MiddlewareServicing, namespace: String) async {
        self.tokenManager = tokenManager
        self.middlewareService = middlewareService
        self.namespace = namespace

        // Load authentication state from Keychain
        isAuthenticated = await loadAuthenticatedState() ?? false

        // If we don't have a stored state, check token validity
        if !isAuthenticated {
            isAuthenticated = await tokenManager.hasValidTokens()
            // Save this initial state
            await setAuthenticatedState(isAuthenticated)
        }

        // Load authentication states for all DIDs
        await loadSessionStatesForAllAccounts()

        startPeriodicTokenCheck()
    }

    deinit {
        tokenCheckTask?.cancel()
    }

    // Load session state for all known DIDs
    private func loadSessionStatesForAllAccounts() async {
        let dids = await tokenManager.listStoredDIDs()
        for did in dids {
            let key = "isAuthenticated.\(did)"
            do {
                let data = try KeychainManager.retrieve(key: key, namespace: namespace)
                if data.count > 0, data[0] == 1 {
                    didToSessionMap[did] = true
                } else {
                    didToSessionMap[did] = false
                }
                LogManager.logDebug(
                    "SessionManager - Loaded authentication state for DID \(did): \(didToSessionMap[did] ?? false)"
                )
            } catch {
                // If there's no stored state, check token validity for this DID
                let hasValidToken = await tokenManager.fetchAccessToken(did: did) != nil
                didToSessionMap[did] = hasValidToken
                LogManager.logDebug(
                    "SessionManager - No stored authentication state for DID \(did), using token validity: \(hasValidToken)"
                )
            }
        }
    }

    private func startPeriodicTokenCheck() {
        tokenCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }

                if await self.isAuthenticated {
                    // Check if token is close to expiration
                    if await self.tokenManager.shouldRefreshTokens() {
                        // Instead of publishing to EventBus, notify delegate
                        if let delegate = await self.delegate {
                            await delegate.sessionExpired()
                        }
                    }
                }

                // Also check tokens for all DIDs periodically
                let dids = Array(await self.didToSessionMap.keys)
                for did in dids where await self.didToSessionMap[did] == true {
                    // Check if this DID's token needs refreshing
                    if let token = await self.tokenManager.fetchAccessToken(did: did),
                       await self.tokenManager.isTokenCloseToExpiration(token: token)
                    {
                        // Notify via delegate if provided
                        LogManager.logInfo("SessionManager - Token for DID \(did) is close to expiration")
                    }
                }

                try? await Task.sleep(nanoseconds: UInt64(60 * 1_000_000_000)) // Check every minute
            }
        }
    }

    // MARK: - SessionManaging Protocol Methods

    func setDelegate(_ delegate: SessionManagerDelegate?) async {
        self.delegate = delegate
    }

    func hasValidSession() async -> Bool {
        let now = Date()
        if now.timeIntervalSince(lastSessionCheckTime) < sessionCheckInterval {
            return isAuthenticated
        }

        lastSessionCheckTime = now

        do {
            let hasValidTokens = await tokenManager.hasValidTokens()
            if !hasValidTokens {
                await setAuthenticatedState(false)
                return false
            }
            await setAuthenticatedState(true)
            return true
        } catch {
            await setAuthenticatedState(false)
            return false
        }
    }

    // Check if a specific account has a valid session
    func hasValidSessionForDID(_ did: String) async -> Bool {
        let now = Date()
        // If we've checked recently, use cached value
        if let lastCheck = didLastCheckTime[did],
           now.timeIntervalSince(lastCheck) < sessionCheckInterval,
           let isValid = didToSessionMap[did]
        {
            return isValid
        }

        // Update last check time
        didLastCheckTime[did] = now

        // Check tokens for this specific DID
        if let token = await tokenManager.fetchAccessToken(did: did) {
            let isValid = await !tokenManager.isTokenExpired(token: token)
            didToSessionMap[did] = isValid
            return isValid
        } else {
            didToSessionMap[did] = false
            return false
        }
    }

    // Set authenticated state for a specific DID
    func setAuthenticatedStateForDID(_ did: String, authenticated: Bool) async {
        // Update in-memory map
        didToSessionMap[did] = authenticated
        didLastCheckTime[did] = Date()

        do {
            // Convert boolean to Data and store in Keychain with DID-specific key
            let data = Data([authenticated ? 1 : 0])
            try KeychainManager.store(
                key: "isAuthenticated.\(did)",
                value: data,
                namespace: namespace
            )
            LogManager.logDebug(
                "SessionManager - Saved authentication state for DID \(did) to Keychain: \(authenticated)")
        } catch {
            LogManager.logError(
                "SessionManager - Failed to store authentication state for DID \(did) in Keychain: \(error)"
            )
        }
    }

    func isUserLoggedIn() async -> Bool {
        return await hasValidSession()
    }

    // Check if any user is logged in
    func isAnyUserLoggedIn() async -> Bool {
        // Check if any DID has a valid session
        for did in didToSessionMap.keys {
            if await hasValidSessionForDID(did) {
                return true
            }
        }

        // Fallback to regular check
        return await hasValidSession()
    }

    // Get the current active DID
    func getCurrentActiveDID() async -> String? {
        return await tokenManager.getCurrentDID()
    }

    // Switch the active DID and initialize its session
    func switchToDID(_ did: String) async throws -> Bool {
        // Check if this DID has a valid session
        if await !hasValidSessionForDID(did) {
            LogManager.logError("SessionManager - Cannot switch to DID \(did): No valid session")
            return false
        }

        // Set as current DID in token manager
        await tokenManager.setCurrentDID(did)

        // Load token data for this DID
        isAuthenticated = true
        await setAuthenticatedState(true)

        // Initialize session if needed
        try await initializeIfNeeded()

        LogManager.logInfo("SessionManager - Switched to DID \(did)")

        // Notify delegate instead of using EventBus
        if let delegate = delegate {
            await delegate.didSwitchToDID(did)
        }

        return true
    }

    func initializeIfNeeded() async throws {
        if isInitializing { return }

        isInitializing = true
        defer { isInitializing = false }

        do {
            let hasValidSession = await self.hasValidSession()
            if hasValidSession {
                // Notify delegate instead of using EventBus
                if let delegate = delegate {
                    await delegate.sessionInitialized()
                }
                return
            }

            try await middlewareService.validateAndRefreshSession()

            let refreshedSession = await self.hasValidSession()
            if refreshedSession {
                // Notify delegate instead of using EventBus
                if let delegate = delegate {
                    await delegate.sessionInitialized()
                }
            } else {
                // Notify delegate instead of using EventBus
                if let delegate = delegate {
                    await delegate.authenticationRequired()
                }
            }
        } catch {
            // Notify delegate instead of using EventBus
            if let delegate = delegate {
                await delegate.networkError(error)
            }
            throw error
        }
    }

    // MARK: - Helper Methods

    private func setAuthenticatedState(_ authenticated: Bool) async {
        isAuthenticated = authenticated

        // If we have a current DID, update its state too
        if let did = await tokenManager.getCurrentDID() {
            await setAuthenticatedStateForDID(did, authenticated: authenticated)
        }

        do {
            // Convert boolean to Data and store in Keychain
            let data = Data([authenticated ? 1 : 0])
            try KeychainManager.store(
                key: "isAuthenticated",
                value: data,
                namespace: namespace,
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
            LogManager.logDebug(
                "SessionManager - Saved authentication state to Keychain: \(authenticated)")
        } catch {
            LogManager.logError(
                "SessionManager - Failed to store authentication state in Keychain: \(error)")
        }
    }

    private func loadAuthenticatedState() async -> Bool? {
        do {
            let data = try KeychainManager.retrieve(key: "isAuthenticated", namespace: namespace)
            if data.count > 0 {
                return data[0] == 1
            }
            return nil
        } catch { // Reintroduce catch block to handle potential KeychainError
            LogManager.logDebug("SessionManager - No authentication state found in Keychain: \(error)")
            return nil
        }
    }

    private func handleTokenRefreshCompletion(
        _ result: Result<(accessToken: String, refreshToken: String), Error>
    ) async {
        switch result {
        case .success:
            await setAuthenticatedState(true)
            // Notify delegate instead of using EventBus
            if let delegate = delegate {
                await delegate.sessionInitialized()
            }
        case let .failure(error):
            await setAuthenticatedState(false)
            // Notify delegate instead of using EventBus
            if let delegate = delegate {
                await delegate.authenticationRequired()
            }
            LogManager.logError("SessionManager - Token refresh failed: \(error)")
        }
    }
}
