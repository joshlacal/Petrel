//
//  LegacyPasswordStrategy.swift
//  Petrel
//
//  Created by Josh LaCalamito on 1/19/26.
//

import Foundation

/// Authentication strategy for legacy username/password authentication (App Passwords).
/// Handles:
/// - DID resolution and session creation via `com.atproto.server.createSession`
/// - Bearer token session management
/// - Token refresh via `com.atproto.server.refreshSession`
actor LegacyPasswordStrategy: AuthStrategy {
    // MARK: - Properties

    private let storage: KeychainStorage
    private let accountManager: AccountManaging
    private let networkService: NetworkService
    private let didResolver: DIDResolving
    private let refreshCircuitBreaker = RefreshCircuitBreaker()

    // Delegates
    private weak var progressDelegate: AuthProgressDelegate?
    private weak var failureDelegate: AuthFailureDelegate?

    // State
    private var lastRefreshAttempt: [String: Date] = [:]
    private var lastSuccessfulRefresh: [String: Date] = [:]
    private let minimumRefreshInterval: TimeInterval = 0.5
    private let minimumRefreshIntervalAfterSuccess: TimeInterval = 30.0
    private var usedRefreshTokens: Set<String> = []
    private var activeRefreshTasks: [String: Task<TokenRefreshResult, Error>] = [:]

    // MARK: - Initialization

    init(
        storage: KeychainStorage,
        accountManager: AccountManaging,
        networkService: NetworkService,
        didResolver: DIDResolving
    ) {
        self.storage = storage
        self.accountManager = accountManager
        self.networkService = networkService
        self.didResolver = didResolver
    }

    // MARK: - AuthStrategy Implementation

    func startOAuthFlow(
        identifier: String?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> URL {
        throw AuthError.invalidOAuthConfiguration // Legacy strategy doesn't support OAuth
    }

    func startOAuthFlowForSignUp(
        pdsURL: URL?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> URL {
        throw AuthError.invalidOAuthConfiguration // Legacy strategy doesn't support OAuth
    }

    func handleOAuthCallback(url: URL) async throws -> (did: String, handle: String?, pdsURL: URL) {
        throw AuthError.invalidOAuthConfiguration // Legacy strategy doesn't support OAuth
    }

    func loginWithPassword(
        identifier: String,
        password: String,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> (did: String, handle: String?, pdsURL: URL) {
        LogManager.logInfo(
            "Starting legacy password authentication for identifier: \(identifier)",
            category: .authentication
        )

        // Resolve handle to DID and PDS URL
        await emitProgress(.resolvingHandle(identifier))
        
        LogManager.logError("[E2E-TRACE] Resolving handle to DID: \(identifier)", category: .authentication)
        let did: String
        do {
            did = try await didResolver.resolveHandleToDID(handle: identifier)
            LogManager.logError("[E2E-TRACE] DID resolved: \(did)", category: .authentication)
        } catch {
            LogManager.logError("[E2E-TRACE] DID resolution FAILED: \(error)", category: .authentication)
            throw error
        }
        
        let pdsURL: URL
        do {
            pdsURL = try await didResolver.resolveDIDToPDSURL(did: did)
            LogManager.logError("[E2E-TRACE] PDS URL resolved: \(pdsURL.absoluteString)", category: .authentication)
        } catch {
            LogManager.logError("[E2E-TRACE] PDS URL resolution FAILED: \(error)", category: .authentication)
            throw error
        }

        LogManager.logInfo(
            "Resolved identifier to DID: \(LogManager.logDID(did)), PDS: \(pdsURL.absoluteString)",
            category: .authentication
        )

        // Create session using com.atproto.server.createSession
        await emitProgress(.creatingSession)

        let sessionInput = ComAtprotoServerCreateSession.Input(
            identifier: identifier,
            password: password
        )

        // Temporarily update network service to point to the user's PDS
        let originalBaseURL = await networkService.baseURL
        await networkService.setBaseURL(pdsURL)

        // Make direct HTTP call to createSession to avoid token refresh loop
        // (The generated client calls performRequest with skipTokenRefresh=false which
        // tries to refresh before the request, causing failures when re-logging in)
        LogManager.logError("[E2E-TRACE] Calling createSession DIRECTLY on PDS: \(pdsURL.absoluteString)", category: .authentication)
        let (responseCode, sessionOutput): (Int, ComAtprotoServerCreateSession.Output?)
        do {
            let createSessionURL = pdsURL.appendingPathComponent("xrpc/com.atproto.server.createSession")
            var request = URLRequest(url: createSessionURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = try JSONEncoder().encode(sessionInput)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            responseCode = httpResponse.statusCode
            
            if responseCode == 200 {
                sessionOutput = try JSONDecoder().decode(ComAtprotoServerCreateSession.Output.self, from: data)
            } else {
                // Log error response body for debugging
                if let errorBody = String(data: data, encoding: .utf8) {
                    LogManager.logError("[E2E-TRACE] createSession error response: \(errorBody)", category: .authentication)
                }
                sessionOutput = nil
            }
            LogManager.logError("[E2E-TRACE] createSession returned code: \(responseCode)", category: .authentication)
        } catch {
            LogManager.logError("[E2E-TRACE] createSession THREW: \(error)", category: .authentication)
            await networkService.setBaseURL(originalBaseURL)
            throw error
        }

        // Restore original base URL
        await networkService.setBaseURL(originalBaseURL)

        guard responseCode == 200, let output = sessionOutput else {
            LogManager.logError("Failed to create session: HTTP \(responseCode)", category: .authentication)
            throw AuthError.invalidCredentials
        }

        LogManager.logInfo(
            "Successfully created legacy session for DID: \(LogManager.logDID(output.did.description))",
            category: .authentication
        )

        // Create session object with legacy tokens (JWT-based, not DPoP)
        // Parse actual expiration from the JWT token
        let actualExpiresIn = parseJWTExpiration(output.accessJwt) ?? 3600 // Fallback to 1 hour
        LogManager.logError("[E2E-TRACE] JWT parsed expiresIn: \(actualExpiresIn) seconds", category: .authentication)
        
        let newSession = Session(
            accessToken: output.accessJwt,
            refreshToken: output.refreshJwt,
            createdAt: Date(),
            expiresIn: actualExpiresIn,
            tokenType: .bearer, // Legacy auth uses Bearer tokens, not DPoP
            did: output.did.description
        )

        // Create or update account
        var account = await accountManager.getAccount(did: output.did.description)
        let isNewAccount = account == nil

        if isNewAccount {
            account = Account(
                did: output.did.description,
                handle: output.handle.description,
                pdsURL: pdsURL,
                protectedResourceMetadata: nil,
                authorizationServerMetadata: nil,
                bskyAppViewDID: bskyAppViewDID ?? "did:web:api.bsky.app#bsky_appview",
                bskyChatDID: bskyChatDID ?? "did:web:api.bsky.chat#bsky_chat"
            )
        } else {
            account?.handle = output.handle.description
            account?.pdsURL = pdsURL
            if let appViewDID = bskyAppViewDID {
                account?.bskyAppViewDID = appViewDID
            }
            if let chatDID = bskyChatDID {
                account?.bskyChatDID = chatDID
            }
        }

        guard let finalAccount = account else {
            LogManager.logError("Failed to create account for legacy auth")
            throw AuthError.invalidResponse
        }

        // Save session and account
        try await storage.saveAccountAndSession(finalAccount, session: newSession, for: output.did.description)

        // Update account manager
        try await accountManager.updateAccountFromStorage(did: output.did.description)
        try await accountManager.setCurrentAccount(did: output.did.description)

        // Update network service
        await networkService.setBaseURL(finalAccount.pdsURL)

        // Reset circuit breaker for this DID since we have a fresh valid session
        await refreshCircuitBreaker.reset(for: output.did.description)

        LogManager.logInfo(
            "Legacy authentication completed successfully for DID: \(LogManager.logDID(output.did.description))",
            category: .authentication
        )

        return (did: output.did.description, handle: finalAccount.handle, pdsURL: finalAccount.pdsURL)
    }

    func logout() async throws {
        guard let did = await accountManager.getCurrentAccount()?.did else { return }

        try await storage.deleteSession(for: did)
        await accountManager.clearCurrentAccount()
    }

    func cancelOAuthFlow() async {
        // No-op for legacy strategy
    }

    func tokensExist() async -> Bool {
        guard let did = await accountManager.getCurrentAccount()?.did else { return false }
        return (try? await storage.getSession(for: did)) != nil
    }

    func setProgressDelegate(_ delegate: AuthProgressDelegate?) async {
        progressDelegate = delegate
    }

    func setFailureDelegate(_ delegate: AuthFailureDelegate?) async {
        failureDelegate = delegate
    }

    func attemptRecoveryFromServerFailures(for did: String?) async throws {
        var targetDID = did
        if targetDID == nil {
            targetDID = await accountManager.getCurrentAccount()?.did
        }
        guard let resolvedDID = targetDID else { return }
        await refreshCircuitBreaker.reset(for: resolvedDID)
        _ = try await refreshTokenIfNeeded(forceRefresh: true)
    }

    // MARK: - AuthenticationProvider

    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        return try await prepareAuthenticatedRequestWithContext(request).0
    }

    func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (URLRequest, AuthContext) {
        guard let account = await accountManager.getCurrentAccount(),
              let session = try? await storage.getSession(for: account.did)
        else {
            throw AuthError.noActiveAccount
        }

        var req = request
        // Legacy auth uses Bearer tokens
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        // AuthContext for legacy doesn't have a JKT (no DPoP)
        return (req, AuthContext(did: account.did, jkt: nil))
    }

    func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
        try await refreshTokenIfNeeded(forceRefresh: false)
    }

    func refreshTokenIfNeeded(forceRefresh: Bool) async throws -> TokenRefreshResult {
        guard let account = await accountManager.getCurrentAccount(),
              let session = try? await storage.getSession(for: account.did)
        else {
            throw AuthError.noActiveAccount
        }

        let did = account.did

        // Check for existing refresh task
        if let existingTask = activeRefreshTasks[did] {
            return try await existingTask.value
        }

        guard let refreshToken = session.refreshToken else {
            throw AuthError.tokenRefreshFailed
        }

        // Check refresh token replay prevention
        if usedRefreshTokens.contains(refreshToken) {
            LogManager.logError(
                "🚨 REPLAY ATTACK PREVENTED: Refresh token already used for DID: \(LogManager.logDID(did))"
            )
            usedRefreshTokens.remove(refreshToken)
            throw AuthError.tokenRefreshFailed
        }

        // Check circuit breaker
        guard await refreshCircuitBreaker.canAttemptRefresh(for: did) else {
            LogManager.logError(
                "RefreshCircuitBreaker: Circuit is OPEN for DID \(LogManager.logDID(did)). Refusing refresh attempt.",
                category: .authentication
            )
            if let delegate = failureDelegate {
                await delegate.handleCircuitBreakerOpen(did: did)
            }
            throw AuthError.tokenRefreshFailed
        }

        // Rate limiting check
        let now = Date()
        if let lastSuccess = lastSuccessfulRefresh[did] {
            let timeSinceSuccess = now.timeIntervalSince(lastSuccess)
            if timeSinceSuccess < minimumRefreshIntervalAfterSuccess && !forceRefresh {
                return .stillValid
            }
        }

        if let lastAttempt = lastRefreshAttempt[did] {
            let timeSinceLastAttempt = now.timeIntervalSince(lastAttempt)
            if timeSinceLastAttempt < minimumRefreshInterval {
                if forceRefresh {
                    let waitSeconds = minimumRefreshInterval - timeSinceLastAttempt
                    try? await Task.sleep(nanoseconds: UInt64(max(0, waitSeconds) * 1_000_000_000))
                } else {
                    return .skippedDueToRateLimit
                }
            }
        }

        // Check if token is still valid
        if !forceRefresh && !session.isExpiringSoon {
            lastSuccessfulRefresh[did] = Date()
            await refreshCircuitBreaker.recordSuccess(for: did)
            return .stillValid
        }

        usedRefreshTokens.insert(refreshToken)

        let task = Task<TokenRefreshResult, Error> {
            try await performLegacyTokenRefresh(for: did)
        }
        activeRefreshTasks[did] = task
        defer { activeRefreshTasks.removeValue(forKey: did) }

        return try await task.value
    }

    func handleUnauthorizedResponse(
        _ response: HTTPURLResponse,
        data: Data,
        for request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        guard response.statusCode == 401 else { return (data, response) }

        let result = try await refreshTokenIfNeeded(forceRefresh: true)

        switch result {
        case .refreshedSuccessfully:
            let (newReq, _) = try await prepareAuthenticatedRequestWithContext(request)
            let result = try await networkService.request(newReq)
            guard let http = result.1 as? HTTPURLResponse else { throw AuthError.invalidResponse }
            return (result.0, http)
        default:
            throw AuthError.tokenRefreshFailed
        }
    }

    func updateDPoPNonce(for url: URL, from headers: [String: String], did: String?, jkt: String?) async {
        // No-op for legacy strategy - Bearer tokens don't use DPoP
    }

    // MARK: - Private Helpers

    private func performLegacyTokenRefresh(for did: String) async throws -> TokenRefreshResult {
        LogManager.logInfo("🔄 performLegacyTokenRefresh: Starting legacy refresh for DID: \(LogManager.logDID(did))")

        // Get the session and account
        guard let session = try? await storage.getSession(for: did),
              let refreshToken = session.refreshToken
        else {
            LogManager.logError(
                "performLegacyTokenRefresh: No session or refresh token found for DID: \(LogManager.logDID(did))"
            )
            throw AuthError.tokenRefreshFailed
        }

        guard let account = await accountManager.getAccount(did: did) else {
            LogManager.logError(
                "performLegacyTokenRefresh: Could not retrieve account for DID: \(LogManager.logDID(did))"
            )
            throw AuthError.tokenRefreshFailed
        }

        LogManager.logDebug("performLegacyTokenRefresh: Using PDS: \(account.pdsURL.absoluteString)")

        // Temporarily update network service to point to the user's PDS
        let originalBaseURL = await networkService.baseURL
        await networkService.setBaseURL(account.pdsURL)

        // Create a URLRequest for the refresh endpoint
        let endpoint = "\(account.pdsURL.absoluteString)/xrpc/com.atproto.server.refreshSession"
        guard let url = URL(string: endpoint) else {
            await networkService.setBaseURL(originalBaseURL)
            LogManager.logError("performLegacyTokenRefresh: Invalid endpoint URL: \(endpoint)")
            throw AuthError.invalidOAuthConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")

        do {
            LogManager.logDebug("performLegacyTokenRefresh: Sending refresh request to \(endpoint)")
            let (data, response) = try await networkService.request(request, skipTokenRefresh: true)

            // Restore original base URL
            await networkService.setBaseURL(originalBaseURL)

            guard let httpResponse = response as? HTTPURLResponse else {
                LogManager.logError("performLegacyTokenRefresh: Response was not HTTPURLResponse")
                throw AuthError.invalidResponse
            }

            // Log response status for debugging
            if (200 ..< 300).contains(httpResponse.statusCode) {
                LogManager.logInfo("✅ performLegacyTokenRefresh: Success (HTTP \(httpResponse.statusCode))")

                // Parse the refresh response
                let refreshResponse = try JSONDecoder().decode(LegacyRefreshSessionResponse.self, from: data)

                // Parse actual expiration from the refreshed JWT
                let actualExpiresIn = parseJWTExpiration(refreshResponse.accessJwt) ?? 3600
                LogManager.logError("[E2E-TRACE] Refreshed JWT expiresIn: \(actualExpiresIn) seconds", category: .authentication)
                
                // Create new session with updated tokens
                let newSession = Session(
                    accessToken: refreshResponse.accessJwt,
                    refreshToken: refreshResponse.refreshJwt,
                    createdAt: Date(),
                    expiresIn: actualExpiresIn,
                    tokenType: .bearer,
                    did: did
                )

                // Update account handle if changed
                var updatedAccount = account
                updatedAccount.handle = refreshResponse.handle

                // Save updated session
                try await storage.saveAccountAndSession(updatedAccount, session: newSession, for: did)
                try await accountManager.updateAccountFromStorage(did: did)

                // Record success
                lastSuccessfulRefresh[did] = Date()
                lastRefreshAttempt[did] = Date()
                await refreshCircuitBreaker.recordSuccess(for: did)

                return .refreshedSuccessfully
            } else {
                let responsePreview = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8>"
                LogManager.logError(
                    "❌ performLegacyTokenRefresh: Failed (HTTP \(httpResponse.statusCode)). Response: \(responsePreview)"
                )

                // Record failure
                lastRefreshAttempt[did] = Date()
                await refreshCircuitBreaker.recordFailure(for: did, kind: .invalidGrant)

                throw AuthError.tokenRefreshFailed
            }
        } catch {
            // Restore original base URL on error
            await networkService.setBaseURL(originalBaseURL)
            LogManager.logError("performLegacyTokenRefresh: Network error: \(error.localizedDescription)")

            // Record failure
            lastRefreshAttempt[did] = Date()
            await refreshCircuitBreaker.recordFailure(for: did, kind: .network)

            throw error
        }
    }

    private func emitProgress(_ event: AuthProgressEvent) async {
        await progressDelegate?.authenticationProgress(event)
    }
    
    /// Parse expiration time from a JWT access token
    /// Returns the number of seconds until expiration, or nil if parsing fails
    private func parseJWTExpiration(_ jwt: String) -> TimeInterval? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        
        var base64 = String(parts[1])
        // Add padding if needed
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        // Replace URL-safe characters
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")
        
        guard let data = Data(base64Encoded: base64) else { return nil }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let exp = json["exp"] as? TimeInterval,
               let iat = json["iat"] as? TimeInterval {
                let expiresIn = exp - iat
                return expiresIn > 0 ? expiresIn : nil
            }
        } catch {
            LogManager.logError("[E2E-TRACE] Failed to parse JWT: \(error)", category: .authentication)
        }
        return nil
    }
}

// MARK: - Response Models

/// Response model for legacy `com.atproto.server.refreshSession`
private struct LegacyRefreshSessionResponse: Codable {
    let accessJwt: String
    let refreshJwt: String
    let handle: String
    let did: String
}
