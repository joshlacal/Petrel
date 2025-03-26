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
    func setAuthenticatedState(_ authenticated: Bool) async // Add this
}

// MARK: - SessionManager Actor

actor SessionManager: SessionManaging {
    // MARK: - Properties

    private let tokenManager: TokenManaging
    private let middlewareService: MiddlewareServicing
    private let accountManager: AccountManaging
    private var lastSessionCheckTime: Date = .distantPast
    private let sessionCheckInterval: TimeInterval = 5 // 5 seconds
    private(set) var isAuthenticated: Bool = false
    private var isInitializing: Bool = false
    private var tokenCheckTask: Task<Void, Never>?

    // MARK: - Initialization

    init(tokenManager: TokenManaging, middlewareService: MiddlewareServicing, accountManager: AccountManaging) async {
        self.tokenManager = tokenManager
        self.middlewareService = middlewareService
        self.accountManager = accountManager

        // Load authentication state from Keychain
        isAuthenticated = await loadAuthenticatedState() ?? false

        // If we don't have a stored state, check token validity initially
        if !isAuthenticated {
            isAuthenticated = await tokenManager.hasValidTokens()
            // Save this initial state
            await setAuthenticatedState(isAuthenticated)
        }

        await subscribeToEvents()
        startPeriodicTokenCheck()
    }

    deinit {
        tokenCheckTask?.cancel()
    }

    private func subscribeToEvents() async {
        let eventStream = await EventBus.shared.subscribe()
        Task {
            for await event in eventStream {
                switch event {
                case .activeAccountChanged(let did):
                    // When account changes, reset internal state but rely on subsequent checks
                    // or explicit calls to set the correct state. Don't load from keychain here
                    // as it might be stale right after a switch before new state is saved.
                    isAuthenticated = false // Assume false until verified
                    LogManager.logDebug("SessionManager - Active account changed to \(did). Reset internal isAuthenticated to false, awaiting verification.")
                case .tokensCleared:
                    // Explicitly set to false on logout/token clear
                    await setAuthenticatedState(false) // This correctly sets internal state and saves false to Keychain
                    LogManager.logDebug("SessionManager - Set isAuthenticated to false due to tokensCleared event.")
                default:
                    break
                }
            }
        }
    }

    private func startPeriodicTokenCheck() {
        tokenCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                // Only perform checks if the manager believes it's authenticated
                if await self?.isAuthenticated == true {
                    do {
                        // Check token validity without side effects first
                        let stillValid = await self?.tokenManager.hasValidTokens() ?? false
                        if !stillValid {
                             LogManager.logInfo("SessionManager - Periodic check found invalid tokens. Setting state to false.")
                             await self?.setAuthenticatedState(false)
                             // Optionally publish authenticationRequired here if needed
                             // await EventBus.shared.publish(.authenticationRequired)
                        } else {
                            // If tokens seem valid, check if refresh is needed
                            let shouldRefresh = await self?.tokenManager.shouldRefreshTokens() ?? false
                            if shouldRefresh {
                                LogManager.logInfo("SessionManager - Periodic check suggests token refresh needed.")
                                try await self?.middlewareService.validateAndRefreshSession()
                            }
                        }
                    } catch {
                        LogManager.logError("SessionManager - Error during periodic session check/refresh: \(error)")
                        // Consider setting state to false on error
                        await self?.setAuthenticatedState(false)
                    }
                }
                // Sleep regardless of auth state
                try? await Task.sleep(nanoseconds: UInt64(60 * 1_000_000_000)) // Check every minute
            }
        }
    }

    // MARK: - SessionManaging Protocol Methods

    func hasValidSession() async -> Bool {
        let now = Date()
        // Use cached state if checked recently
        if now.timeIntervalSince(lastSessionCheckTime) < sessionCheckInterval {
            return isAuthenticated
        }

        lastSessionCheckTime = now

        // Perform a fresh check of token validity
        let hasValidTokens = await tokenManager.hasValidTokens()

        // If tokens are invalid, the session is definitely invalid.
        if !hasValidTokens {
            // If the internal state thought it was authenticated, log the discrepancy and update internal state.
            if isAuthenticated {
                 LogManager.logInfo("SessionManager - hasValidSession check found invalid tokens, but internal state was true. Updating internal state.") // Changed logWarning to logInfo
                 isAuthenticated = false
                 // Consider if saving 'false' to keychain is needed here or rely on periodic check/logout
            }
            return false
        } else {
            // Tokens are valid according to TokenManager.
            // Ensure internal state reflects this, but don't necessarily save to Keychain here.
            if !isAuthenticated {
                 LogManager.logInfo("SessionManager - hasValidSession check found valid tokens, updating internal state to true.")
                 isAuthenticated = true
                 // We *could* save true here, but explicit calls from Auth Service are preferred.
                 // await setAuthenticatedState(true)
            }
            return true
        }
        // Note: Removed the explicit setAuthenticatedState calls that overwrite Keychain state.
        // Internal isAuthenticated is updated based on token check for immediate consistency.
    }


    func isUserLoggedIn() async -> Bool {
        // Simply return the current internal state, which is updated by checks/events
        return isAuthenticated
    }

    func initializeIfNeeded() async throws {
        if isInitializing { return }

        isInitializing = true
        defer { isInitializing = false }

        do {
            // Use hasValidSession which performs a fresh check if needed
            let isValid = await self.hasValidSession()
            if isValid {
                await EventBus.shared.publish(.sessionInitialized)
                return
            }

            // If not valid, attempt refresh (validateAndRefreshSession might trigger tokenExpired event)
            try await middlewareService.validateAndRefreshSession()

            // Re-check validity after potential refresh attempt
            let refreshedSession = await self.hasValidSession()
            if refreshedSession {
                await EventBus.shared.publish(.sessionInitialized)
            } else {
                // If still not valid after refresh attempt, session is truly expired/invalid
                await EventBus.shared.publish(.sessionExpired)
                await EventBus.shared.publish(.authenticationRequired)
            }
        } catch {
            // If refresh attempt fails, session is invalid
            await setAuthenticatedState(false) // Ensure state is false on error
            await EventBus.shared.publish(.networkError(error))
            throw error
        }
    }

    // MARK: - Helper Methods

    private func getNamespace() async -> String {
        if let did = await accountManager.getActiveAccountDID() {
            return did
        }
        // Use a specific namespace for when no account is active,
        // distinct from any potential user DID.
        return "global_no_account"
    }

    // This method is now primarily called explicitly by AuthenticationService or on token failures/logout
    func setAuthenticatedState(_ authenticated: Bool) async {
        // Update internal state immediately
        let stateChanged = (isAuthenticated != authenticated)
        isAuthenticated = authenticated
        LogManager.logDebug("SessionManager - Internal isAuthenticated set to \(authenticated).")

        // Only update Keychain if the state actually changed
        if stateChanged {
            do {
                let data = Data([authenticated ? 1 : 0])
                let namespace = await getNamespace()
                try KeychainManager.store(
                    key: "isAuthenticated",
                    value: data,
                    namespace: namespace, // Use namespace for the *current* active account
                    accessibility: kSecAttrAccessibleAfterFirstUnlock
                )
                LogManager.logDebug("SessionManager - Saved authentication state (\(authenticated)) to Keychain for namespace \(namespace).")
            } catch {
                LogManager.logError("SessionManager - Failed to store authentication state in Keychain: \(error)")
            }
        } else {
             LogManager.logDebug("SessionManager - Authentication state already \(authenticated), no Keychain update needed.")
        }
    }


    private func loadAuthenticatedState() async -> Bool? {
        do {
            let namespace = await getNamespace()
            let data = try KeychainManager.retrieve(key: "isAuthenticated", namespace: namespace)
            if data.count > 0 {
                let authenticated = data[0] == 1
                LogManager.logDebug("SessionManager - Loaded authentication state (\(authenticated)) from Keychain for namespace \(namespace).")
                return authenticated
            }
            LogManager.logDebug("SessionManager - Found empty authentication state in Keychain for namespace \(namespace).")
            return nil // Treat empty data as not found
        } catch KeychainError.itemRetrievalError {
             LogManager.logDebug("SessionManager - No authentication state found in Keychain for namespace \(await getNamespace()).")
            return nil // Explicitly return nil if not found
        } catch {
            LogManager.logError("SessionManager - Error loading authentication state from Keychain: \(error)")
            return nil // Return nil on other errors
        }
    }

    // This might be better handled by listening to token refresh failure events if needed
    // private func handleTokenRefreshCompletion(_ result: Result<(accessToken: String, refreshToken: String), Error>) async {
    //     switch result {
    //     case .success:
    //         await setAuthenticatedState(true)
    //         await EventBus.shared.publish(.sessionInitialized)
    //     case let .failure(error):
    //         await setAuthenticatedState(false)
    //         await EventBus.shared.publish(.authenticationRequired)
    //         LogManager.logError("SessionManager - Token refresh failed: \(error)")
    //     }
    // }
}
