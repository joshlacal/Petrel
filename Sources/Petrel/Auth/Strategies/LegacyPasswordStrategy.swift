//
//  LegacyPasswordStrategy.swift
//  Petrel
//
//  Created by Josh LaCalamito on 1/19/26.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Authentication strategy for app-password sessions (`com.atproto.server.*Session`).
///
/// - Signs in with a handle, a DID or an email address, optionally with an
///   email auth-factor token, against the account's own PDS.
/// - Uses Bearer tokens; refreshes with `refreshSession` and ends the session
///   with `deleteSession` on logout.
/// - Reports takedown, suspension and deactivation as ``AccountStatusError``
///   and keeps the hosting status the server returned.
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
    /// The hosting status each account's server last reported, by DID.
    private var accountStatuses: [String: AccountStatus] = [:]

    /// The hosting status `did`'s server reported at sign-in or the last refresh.
    func lastKnownAccountStatus(for did: String) -> AccountStatus? {
        accountStatuses[did]
    }

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
        try await loginWithPassword(
            identifier: identifier,
            password: password,
            authFactorToken: nil,
            bskyAppViewDID: bskyAppViewDID,
            bskyChatDID: bskyChatDID
        )
    }

    /// Signs in with an app password (or account password).
    ///
    /// - Parameters:
    ///   - identifier: A handle, a DID, or the account's email address. A handle
    ///     or DID is resolved to its PDS and the session is created there; an
    ///     email address cannot be resolved, so the session is created at the
    ///     service this client was configured with.
    ///   - password: The app password.
    ///   - authFactorToken: The emailed sign-in code, when the server asked for
    ///     one by failing a first attempt with ``AuthFactorTokenRequiredError``.
    func loginWithPassword(
        identifier: String,
        password: String,
        authFactorToken: String?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> (did: String, handle: String?, pdsURL: URL) {
        await emitProgress(.resolvingHandle(identifier))

        // Work out which server to ask, and which account it must answer for.
        let expectedDID: String?
        let loginServer: URL
        if identifier.hasPrefix("did:") {
            expectedDID = identifier
            loginServer = try await didResolver.resolveDIDToPDSURL(did: identifier)
        } else if identifier.contains("@") {
            expectedDID = nil
            loginServer = await networkService.baseURL
        } else {
            let did = try await didResolver.resolveHandleToDID(handle: identifier)
            expectedDID = did
            loginServer = try await didResolver.resolveDIDToPDSURL(did: did)
        }

        await emitProgress(.creatingSession)

        var request = URLRequest(url: loginServer.appendingPathComponent("xrpc/com.atproto.server.createSession"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONCoders.encode(
            ComAtprotoServerCreateSession.Input(
                identifier: identifier, password: password, authFactorToken: authFactorToken
            )
        )

        // Sent with no credentials of any signed-in account, and never redirected.
        let (data, response) = try await networkService.executeUnauthenticatedRequest(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            LogManager.logError(
                "createSession failed with HTTP \(httpResponse.statusCode)", category: .authentication
            )
            throw Self.sessionError(status: httpResponse.statusCode, body: data)
        }
        let output = try JSONCoders.decode(ComAtprotoServerCreateSession.Output.self, from: data)
        let did = output.did.description

        // The server must have signed in the account that was asked for.
        if let expectedDID, did != expectedDID {
            LogManager.logError(
                "createSession returned a session for a different account than the one requested; discarding it",
                category: .authentication
            )
            await deleteServerSession(refreshToken: output.refreshJwt, pdsURL: loginServer)
            throw AuthError.invalidResponse
        }

        // An email sign-in went to the configured service, which may be an
        // entryway: the account's own PDS comes from its DID document.
        let pdsURL = expectedDID == nil
            ? try await didResolver.resolveDIDToPDSURL(did: did)
            : loginServer

        let status = AccountStatus(active: output.active, status: output.status)
        accountStatuses[did] = status

        let newSession = Session(
            accessToken: output.accessJwt,
            refreshToken: output.refreshJwt,
            createdAt: Date(),
            expiresIn: Self.jwtLifetime(output.accessJwt),
            tokenType: .bearer, // app-password sessions use Bearer tokens, not DPoP
            did: did
        )

        var account = await accountManager.getAccount(did: did) ?? Account(
            did: did,
            handle: output.handle.description,
            pdsURL: pdsURL,
            protectedResourceMetadata: nil,
            authorizationServerMetadata: nil,
            bskyAppViewDID: bskyAppViewDID ?? "did:web:api.bsky.app#bsky_appview",
            bskyChatDID: bskyChatDID ?? "did:web:api.bsky.chat#bsky_chat"
        )
        account.handle = output.handle.description
        account.pdsURL = pdsURL
        // An app-password session has no authorization server.
        account.authorizationServerMetadata = nil
        if let bskyAppViewDID {
            account.bskyAppViewDID = bskyAppViewDID
        }
        if let bskyChatDID {
            account.bskyChatDID = bskyChatDID
        }

        try await storage.saveAccountAndSession(account, session: newSession, for: did)
        try await accountManager.updateAccountFromStorage(did: did)
        try await accountManager.setCurrentAccount(did: did)
        await networkService.setBaseURL(account.pdsURL)

        // A fresh valid session supersedes any earlier refresh failures.
        await refreshCircuitBreaker.reset(for: did)

        LogManager.logInfo(
            "App-password sign-in completed for DID: \(LogManager.logDID(did)) (\(status))",
            category: .authentication
        )
        return (did: did, handle: account.handle, pdsURL: account.pdsURL)
    }

    /// Maps a failed `createSession` / `refreshSession` response to a typed error.
    static func sessionError(status: Int, body: Data) -> Error {
        let xrpcError = try? JSONDecoder().decode(XRPCErrorBody.self, from: body)
        if let xrpcError {
            if let statusError = AccountStatusError(xrpcErrorName: xrpcError.error, message: xrpcError.message) {
                return statusError
            }
            if xrpcError.error == "AuthFactorTokenRequired" {
                return AuthFactorTokenRequiredError()
            }
        }
        switch status {
        case 401:
            return AuthError.invalidCredentials
        case 429:
            return AuthError.rateLimited
        default:
            return AuthError.serverError(
                status, xrpcError.map { [$0.error, $0.message].compactMap { $0 }.joined(separator: ": ") }
            )
        }
    }

    func logout() async throws {
        guard let did = await accountManager.getCurrentAccount()?.did else { return }

        await revokeSession(for: did)

        try await storage.deleteSession(for: did)
        accountStatuses.removeValue(forKey: did)
        await accountManager.clearCurrentAccount()
    }

    /// Ends `did`'s session at its PDS (`com.atproto.server.deleteSession`),
    /// leaving local state untouched.
    /// - Returns: `true` only when the server confirmed.
    @discardableResult
    func revokeSession(for did: String) async -> Bool {
        guard let session = try? await storage.getSession(for: did),
              session.tokenType == .bearer,
              let refreshToken = session.refreshToken,
              let account = await accountManager.getAccount(did: did)
        else {
            return false
        }
        return await deleteServerSession(refreshToken: refreshToken, pdsURL: account.pdsURL)
    }

    @discardableResult
    private func deleteServerSession(refreshToken: String, pdsURL: URL) async -> Bool {
        var request = URLRequest(url: pdsURL.appendingPathComponent("xrpc/com.atproto.server.deleteSession"))
        request.httpMethod = "POST"
        // deleteSession is authorized by the refresh token, not the access token.
        request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await networkService.executeAuthProtocolRequest(request)
            guard response.statusCode == 200 else {
                LogManager.logError(
                    "deleteSession was refused with HTTP \(response.statusCode); the session may remain valid",
                    category: .authentication
                )
                return false
            }
            return true
        } catch {
            LogManager.logError(
                "deleteSession failed (\(error)); the session may remain valid", category: .authentication
            )
            return false
        }
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

        do {
            return try await task.value
        } catch {
            // Only a definitive rejection spends the token; after a transport or
            // server failure the same refresh token is still the valid one.
            if (error as? AuthError) != .invalidCredentials, !(error is AccountStatusError) {
                usedRefreshTokens.remove(refreshToken)
            }
            throw error
        }
    }

    func handleUnauthorizedResponse(
        _ response: HTTPURLResponse,
        data: Data,
        for request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        guard response.statusCode == 401 else { return (data, response) }

        // A takedown, suspension or deactivation is not an expired token.
        if let statusError = AccountStatusError(xrpcErrorBody: data) {
            if let did = await accountManager.getCurrentAccount()?.did {
                accountStatuses[did] = statusError.status
            }
            throw statusError
        }

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
        guard let session = try? await storage.getSession(for: did),
              let refreshToken = session.refreshToken,
              let account = await accountManager.getAccount(did: did)
        else {
            LogManager.logError(
                "No session, refresh token or account for DID: \(LogManager.logDID(did)); cannot refresh"
            )
            throw AuthError.tokenRefreshFailed
        }

        var request = URLRequest(
            url: account.pdsURL.appendingPathComponent("xrpc/com.atproto.server.refreshSession")
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // refreshSession is authorized by the refresh token. It is sent as built,
        // straight to the account's PDS: the shared base URL is left alone and the
        // access token is never substituted for it.
        request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")

        lastRefreshAttempt[did] = Date()
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await networkService.executeAuthProtocolRequest(request)
        } catch {
            await refreshCircuitBreaker.recordFailure(for: did, kind: .network)
            throw (error as? NetworkError).map(AuthError.networkError) ?? error
        }

        guard (200 ..< 300).contains(response.statusCode) else {
            LogManager.logError("refreshSession failed with HTTP \(response.statusCode)", category: .authentication)
            if (500 ..< 600).contains(response.statusCode) {
                await refreshCircuitBreaker.recordFailure(for: did, kind: .server)
                throw AuthError.tokenRefreshFailed
            }
            await refreshCircuitBreaker.recordFailure(for: did, kind: .invalidGrant)
            let error = Self.sessionError(status: response.statusCode, body: data)
            if let statusError = error as? AccountStatusError {
                accountStatuses[did] = statusError.status
                throw statusError
            }
            // Any other 4xx means the refresh token is no longer good.
            throw AuthError.invalidCredentials
        }

        let refreshed = try JSONCoders.decode(LegacyRefreshSessionResponse.self, from: data)
        guard refreshed.did == did else {
            LogManager.logError(
                "refreshSession returned a session for a different account; discarding it", category: .authentication
            )
            await refreshCircuitBreaker.recordFailure(for: did, kind: .invalidGrant)
            throw AuthError.invalidCredentials
        }
        accountStatuses[did] = AccountStatus(active: refreshed.active, status: refreshed.status)

        let newSession = Session(
            accessToken: refreshed.accessJwt,
            refreshToken: refreshed.refreshJwt,
            createdAt: Date(),
            expiresIn: Self.jwtLifetime(refreshed.accessJwt),
            tokenType: .bearer,
            did: did
        )
        var updatedAccount = account
        updatedAccount.handle = refreshed.handle

        try await storage.saveAccountAndSession(updatedAccount, session: newSession, for: did)
        try await accountManager.updateAccountFromStorage(did: did)

        lastSuccessfulRefresh[did] = Date()
        await refreshCircuitBreaker.recordSuccess(for: did)
        return .refreshedSuccessfully
    }

    private func emitProgress(_ event: AuthProgressEvent) async {
        await progressDelegate?.authenticationProgress(event)
    }

    /// Lifetime assumed for an access JWT whose `exp`/`iat` cannot be read. The
    /// PDS issues two-hour app-password access tokens; assuming less only costs
    /// an earlier refresh.
    static let assumedAccessTokenLifetime: TimeInterval = 3600

    /// The lifetime (`exp` − `iat`) of an app-password access JWT.
    static func jwtLifetime(_ jwt: String) -> TimeInterval {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return assumedAccessTokenLifetime }

        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64),
              let claims = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let exp = claims["exp"] as? TimeInterval,
              let iat = claims["iat"] as? TimeInterval,
              exp > iat
        else {
            return assumedAccessTokenLifetime
        }
        return exp - iat
    }
}

// MARK: - Response Models

/// Response model for `com.atproto.server.refreshSession`.
private struct LegacyRefreshSessionResponse: Codable {
    let accessJwt: String
    let refreshJwt: String
    let handle: String
    let did: String
    let active: Bool?
    let status: String?
}
