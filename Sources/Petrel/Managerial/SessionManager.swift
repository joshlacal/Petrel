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
    func clearSession() async throws
}

// MARK: - SessionManager Actor

actor SessionManager: SessionManaging {
    
    // MARK: - Properties
    
    private let tokenManager: TokenManaging
    private let middlewareService: MiddlewareServicing
    private var lastSessionCheckTime: Date = .distantPast
    private let sessionCheckInterval: TimeInterval = 5 // 5 seconds
    private(set) var isAuthenticated: Bool = false
    private var isInitializing: Bool = false
    
    // MARK: - Initialization
    
    init(tokenManager: TokenManaging, middlewareService: MiddlewareServicing) async {
        self.tokenManager = tokenManager
        self.middlewareService = middlewareService

//            await self.subscribeToEvents()
    }
    
    // MARK: - Event Subscription
    
    private func subscribeToEvents() async {
        let eventStream = await EventBus.shared.subscribe()
        for await event in eventStream {
            switch event {
//            case .tokensUpdated:
//                Task { try await self.initializeIfNeeded() }
//            case .tokenRefreshCompleted(let result):
//                await self.handleTokenRefreshCompletion(result)
//            case .authenticationRequired:
//                await self.setAuthenticatedState(false)
//            case .networkError(let error):
//                LogManager.logError("SessionManager - Received networkError event: \(error)")
            default:
                break
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
                // Instead of publishing an event, just return false
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

    func clearSession() async throws {
        try await middlewareService.clearSession()
        await EventBus.shared.publish(.sessionExpired)
    }
    
    // MARK: - Helper Methods
    
    private func setAuthenticatedState(_ authenticated: Bool) async {
        self.isAuthenticated = authenticated
        await MainActor.run {
            UserDefaults.standard.set(authenticated, forKey: "isAuthenticated")
            UserDefaults.standard.synchronize()
        }
    }
    
    private func handleTokenRefreshCompletion(_ result: Result<(accessToken: String, refreshToken: String), Error>) async {
        switch result {
        case .success:
            await setAuthenticatedState(true)
            await EventBus.shared.publish(.sessionInitialized)
        case .failure(let error):
            await setAuthenticatedState(false)
            await EventBus.shared.publish(.authenticationRequired)
            LogManager.logError("SessionManager - Token refresh failed: \(error)")
        }
    }
}
