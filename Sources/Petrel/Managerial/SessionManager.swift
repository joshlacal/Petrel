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
        
        startPeriodicTokenCheck()
    }

    deinit {
        tokenCheckTask?.cancel()
    }

    private func startPeriodicTokenCheck() {
        tokenCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                if await self?.isAuthenticated == true {
                    do {
                        let shouldRefresh = await self?.tokenManager.shouldRefreshTokens() ?? false
                        if shouldRefresh {
                            try await self?.middlewareService.validateAndRefreshSession()
                        }
                    } catch {
                        LogManager.logError("Failed to refresh session: \(error)")
                    }
                }
                try? await Task.sleep(nanoseconds: UInt64(60 * 1_000_000_000)) // Check every minute
            }
        }
    }

    // MARK: - SessionManaging Protocol Methods

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

    func isUserLoggedIn() async -> Bool {
        return await hasValidSession()
    }

    func initializeIfNeeded() async throws {
        if isInitializing { return }

        isInitializing = true
        defer { isInitializing = false }

        do {
            let hasValidSession = await self.hasValidSession()
            if hasValidSession {
                await EventBus.shared.publish(.sessionInitialized)
                return
            }

            try await middlewareService.validateAndRefreshSession()

            let refreshedSession = await self.hasValidSession()
            if refreshedSession {
                await EventBus.shared.publish(.sessionInitialized)
            } else {
                await EventBus.shared.publish(.sessionExpired)
                await EventBus.shared.publish(.authenticationRequired)
            }
        } catch {
            await EventBus.shared.publish(.networkError(error))
            throw error
        }
    }

    // MARK: - Helper Methods

    private func setAuthenticatedState(_ authenticated: Bool) async {
        isAuthenticated = authenticated
        
        do {
            // Convert boolean to Data and store in Keychain
            let data = Data([authenticated ? 1 : 0])
            try KeychainManager.store(
                key: "isAuthenticated",
                value: data,
                namespace: namespace,
                accessibility: kSecAttrAccessibleAfterFirstUnlock
            )
            LogManager.logDebug("SessionManager - Saved authentication state to Keychain: \(authenticated)")
        } catch {
            LogManager.logError("SessionManager - Failed to store authentication state in Keychain: \(error)")
        }
    }
    
    private func loadAuthenticatedState() async -> Bool? {
        do {
            let data = try KeychainManager.retrieve(key: "isAuthenticated", namespace: namespace)
            if data.count > 0 {
                let authenticated = data[0] == 1
                LogManager.logDebug("SessionManager - Loaded authentication state from Keychain: \(authenticated)")
                return authenticated
            }
            return nil
        } catch {
            LogManager.logDebug("SessionManager - No authentication state found in Keychain: \(error)")
            return nil
        }
    }

    private func handleTokenRefreshCompletion(_ result: Result<(accessToken: String, refreshToken: String), Error>) async {
        switch result {
        case .success:
            await setAuthenticatedState(true)
            await EventBus.shared.publish(.sessionInitialized)
        case let .failure(error):
            await setAuthenticatedState(false)
            await EventBus.shared.publish(.authenticationRequired)
            LogManager.logError("SessionManager - Token refresh failed: \(error)")
        }
    }
}
