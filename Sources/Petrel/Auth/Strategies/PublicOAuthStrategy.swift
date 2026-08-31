//
//  PublicOAuthStrategy.swift
//  Petrel
//
//  Created by Josh LaCalamito on 1/19/26.
//

import Crypto
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Authentication strategy for public clients (e.g. mobile apps)
/// Handles:
/// - Pushed Authorization Requests (PAR)
/// - PKCE Flow
/// - DPoP Key Management & Signing
/// - Token Refresh with DPoP Replay Protection
/// - Automatic DPoP Nonce Handling
actor PublicOAuthStrategy: AuthStrategy {
    // MARK: - Properties

    let core: OAuthCore

    // Delegates
    private weak var progressDelegate: AuthProgressDelegate?
    private weak var failureDelegate: AuthFailureDelegate?

    // OAuth flow deduplication state
    private var oauthStartInProgress = false
    private var oauthStartTasks: [String: Task<(url: URL, state: String), Error>] = [:]
    private var inFlightOAuthStateTokens: Set<String> = []
    private var cancellationGeneration: UInt64 = 0
    private var deniedStateTokens: Set<String> = []

    private struct CanonicalOrigin: Equatable {
        let scheme: String
        let host: String
        let port: Int
    }

    private static func canonicalOrigin(of url: URL) -> CanonicalOrigin? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              !host.isEmpty
        else { return nil }
        let defaultPort = (scheme == "https" || scheme == "wss") ? 443 : (scheme == "http" || scheme == "ws") ? 80 : 0
        let effectivePort = components.port ?? defaultPort
        return CanonicalOrigin(scheme: scheme, host: host, port: effectivePort)
    }
    private static func matchesRedirectURI(callbackURL: URL, expectedRedirectURI: String) -> Bool {
        guard let expectedURL = URL(string: expectedRedirectURI),
              let callbackComps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let expectedComps = URLComponents(url: expectedURL, resolvingAgainstBaseURL: false)
        else {
            return false
        }
        guard let cbScheme = callbackComps.scheme?.lowercased(),
              let expScheme = expectedComps.scheme?.lowercased(),
              cbScheme == expScheme
        else {
            return false
        }
        let cbHost = callbackComps.host?.lowercased()
        let expHost = expectedComps.host?.lowercased()
        if cbHost != expHost {
            return false
        }
        if callbackComps.port != expectedComps.port {
            return false
        }
        let cbPath = callbackComps.path.isEmpty ? "/" : callbackComps.path
        let expPath = expectedComps.path.isEmpty ? "/" : expectedComps.path
        if cbPath != expPath {
            return false
        }
        return true
    }
    // MARK: - Initialization

    init(
        storage: KeychainStorage,
        accountManager: AccountManaging,
        networkService: NetworkService,
        oauthConfig: OAuthConfig,
        didResolver: DIDResolving
    ) {
        core = OAuthCore(
            storage: storage,
            accountManager: accountManager,
            networkService: networkService,
            oauthConfig: oauthConfig,
            didResolver: didResolver
        )
    }

    /// Must be called after init to wire up the strategy-specific refresh.
    private func setupRefreshClosure() async {
        await core.setPerformActualRefresh { [weak self] account, session in
            guard let self else { throw AuthError.tokenRefreshFailed }
            return try await self.performActualRefresh(for: account, session: session)
        }
    }

    // MARK: - AuthStrategy Implementation

    func startOAuthFlow(
        identifier: String?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> URL {
        try await startOAuthFlowWithState(
            identifier: identifier,
            bskyAppViewDID: bskyAppViewDID,
            bskyChatDID: bskyChatDID
        ).url
    }

    func startOAuthFlowWithState(
        identifier: String? = nil,
        bskyAppViewDID: String? = nil,
        bskyChatDID: String? = nil
    ) async throws -> (url: URL, state: String) {
        await ensureRefreshClosure()

        let key = identifier?.lowercased() ?? "__signup__"

        if let existing = oauthStartTasks[key] {
            return try await existing.value
        }

        let task = Task.detached(priority: .userInitiated) { [weak self] () throws -> (url: URL, state: String) in
            guard let self else { throw AuthError.invalidOAuthConfiguration }
            return try await self._startOAuthFlowImpl(
                identifier: identifier,
                bskyAppViewDID: bskyAppViewDID,
                bskyChatDID: bskyChatDID
            )
        }
        oauthStartTasks[key] = task
        defer { oauthStartTasks.removeValue(forKey: key) }
        return try await task.value
    }

    func startOAuthFlowForSignUp(
        pdsURL: URL?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> URL {
        let finalPDSURL = pdsURL ?? URL(string: "https://bsky.social")!

        let stateToken = UUID().uuidString
        let codeVerifier = await core.generateCodeVerifier()
        let codeChallenge = await core.generateCodeChallenge(from: codeVerifier)
        let ephemeralKey = P256.Signing.PrivateKey()

        let authServerURL = try await core.resolveAuthServer(for: finalPDSURL)
        let metadata = try await core.fetchAuthorizationServerMetadata(authServerURL: authServerURL)

        let jwk = try await core.createJWK(
                    from: P256.Signing.PrivateKey(rawRepresentation: ephemeralKey.rawRepresentation))
        let dpopJKT = try await core.calculateJWKThumbprint(jwk: jwk)

        let oauthConfig = core.oauthConfig
        let (requestURI, parNonce) = try await core.pushAuthorizationRequest(
            codeChallenge: codeChallenge,
            identifier: nil,
            endpoint: metadata.pushedAuthorizationRequestEndpoint,
            authServerURL: authServerURL,
            state: stateToken,
            ephemeralKeyRawRepresentation: ephemeralKey.rawRepresentation
        )

        let oauthState = OAuthState(
            stateToken: stateToken,
            codeVerifier: codeVerifier,
            createdAt: Date(),
            initialIdentifier: nil,
            targetPDSURL: finalPDSURL,
            ephemeralDPoPKey: ephemeralKey.rawRepresentation,
            parResponseNonce: parNonce,
            bskyAppViewDID: bskyAppViewDID,
            bskyChatDID: bskyChatDID,
            expectedIssuer: metadata.issuer,
            expectedPDSOrigin: finalPDSURL.absoluteString,
            expectedDID: nil,
            redirectURI: oauthConfig.redirectUri,
            dpopJKT: dpopJKT,
            tokenEndpoint: metadata.tokenEndpoint,
            authorizationEndpoint: metadata.authorizationEndpoint
        )
        let storage = core.storage
        let currentGen = cancellationGeneration
        inFlightOAuthStateTokens.insert(stateToken)
        do {
            try await storage.saveOAuthState(oauthState)
        } catch {
            inFlightOAuthStateTokens.remove(stateToken)
            throw error
        }

        if cancellationGeneration != currentGen || !inFlightOAuthStateTokens.contains(stateToken) {
            deniedStateTokens.insert(stateToken)
            _ = try? await storage.deleteOAuthState(for: stateToken)
            inFlightOAuthStateTokens.remove(stateToken)
            throw AuthError.cancelled
        }
        guard var components = URLComponents(string: metadata.authorizationEndpoint) else {
            throw AuthError.invalidOAuthConfiguration
        }
        components.queryItems = [
            URLQueryItem(name: "request_uri", value: requestURI),
            URLQueryItem(name: "client_id", value: oauthConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: oauthConfig.redirectUri),
        ]

        guard let url = components.url else { throw AuthError.authorizationFailed }
        return url
    }

    func handleOAuthCallback(url: URL) async throws -> (did: String, handle: String?, pdsURL: URL) {
        await emitProgress(.exchangingTokens)

        // Handle explicit provider error callback
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let items = comps.queryItems,
           items.contains(where: { $0.name == "error" }) {
            if let stateToken = await core.extractState(from: url) {
                deniedStateTokens.insert(stateToken)
                _ = try? await core.storage.consumeOAuthState(stateToken)
                _ = try? await core.storage.deleteOAuthState(for: stateToken)
                inFlightOAuthStateTokens.remove(stateToken)
            }
            throw AuthError.cancelled
        }

        guard let code = await core.extractAuthorizationCode(from: url),
              let stateToken = await core.extractState(from: url)
        else { throw AuthError.invalidCallbackURL }

        if deniedStateTokens.contains(stateToken) {
            throw AuthError.invalidCallbackURL
        }

        let oauthConfig = core.oauthConfig
        let storage = core.storage

        // Atomically consume state before any other checks or network calls
        let oauthState: OAuthState
        do {
            oauthState = try await storage.consumeOAuthState(stateToken)
            inFlightOAuthStateTokens.remove(stateToken)
        } catch {
            throw AuthError.invalidCallbackURL
        }

        // Fail-closed validation on initiating trust tuple (Finding A1-04, A1-R2-04)
        guard let expectedIssuer = oauthState.expectedIssuer,
              let parsedIssuer = URL(string: expectedIssuer),
              parsedIssuer.scheme != nil, parsedIssuer.host != nil,
              let expectedJKT = oauthState.dpopJKT,
              let persistedRedirectURI = oauthState.redirectURI,
              let expectedPDSOrigin = oauthState.expectedPDSOrigin,
              let expectedPDSOriginURL = URL(string: expectedPDSOrigin),
              expectedPDSOriginURL.scheme != nil, expectedPDSOriginURL.host != nil,
              let persistedTokenEndpoint = oauthState.tokenEndpoint,
              let parsedTokenEndpoint = URL(string: persistedTokenEndpoint),
              parsedTokenEndpoint.scheme != nil, parsedTokenEndpoint.host != nil
        else {
            throw AuthError.invalidCallbackURL
        }

        if oauthState.initialIdentifier != nil {
            guard oauthState.expectedDID != nil else {
                throw AuthError.invalidCallbackURL
            }
        }

        // Strict normalized redirect URI verification against persisted initiating redirect URI (Finding A1-05)
        guard Self.matchesRedirectURI(callbackURL: url, expectedRedirectURI: persistedRedirectURI) else {
            throw AuthError.invalidCallbackURL
        }

        let callbackIss = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "iss" })?
            .value

        if oauthConfig.requireIssInCallback {
            guard let callbackIss else { throw AuthError.invalidCallbackURL }
            guard callbackIss == expectedIssuer else { throw AuthError.invalidCallbackURL }
        } else if let callbackIss {
            guard callbackIss == expectedIssuer else { throw AuthError.invalidCallbackURL }
        }

        guard let keyData = oauthState.ephemeralDPoPKey else { throw AuthError.dpopKeyError }
        let ephemeralKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)

        let jwk = try await core.createJWK(
                    from: P256.Signing.PrivateKey(rawRepresentation: ephemeralKey.rawRepresentation))
        let thumbprint = try await core.calculateJWKThumbprint(jwk: jwk)
        guard thumbprint == expectedJKT else {
            throw AuthError.dpopKeyError
        }

        guard let pdsURL = oauthState.targetPDSURL else { throw AuthError.invalidOAuthConfiguration }

        let tokenEndpoint = persistedTokenEndpoint
        let authServerURL = parsedIssuer

        let tokenResponse = try await exchangeCodeForTokens(
            code: code,
            codeVerifier: oauthState.codeVerifier,
            tokenEndpoint: tokenEndpoint,
            authServerURL: authServerURL,
            ephemeralKey: ephemeralKey,
            initialNonce: oauthState.parResponseNonce,
            resourceURL: pdsURL
        )

        guard let did = tokenResponse.sub, !did.isEmpty else { throw AuthError.invalidResponse }
        guard tokenResponse.tokenType.lowercased() == "dpop" else {
            throw AuthError.invalidResponse
        }

        if let expectedDID = oauthState.expectedDID {
            guard did == expectedDID else {
                throw AuthError.invalidResponse
            }
        }

        // Resolve real PDS
        let didResolver = core.didResolver
        let (handle, actualPDS) = try await didResolver.resolveDIDToHandleAndPDSURL(did: did)

        // Enforce exact canonical-origin equality for flows initiated with an identifier (login/add-account/re-auth)
        if oauthState.initialIdentifier != nil {
            guard let actualOrigin = Self.canonicalOrigin(of: actualPDS),
                  let expectedOrigin = Self.canonicalOrigin(of: expectedPDSOriginURL),
                  actualOrigin == expectedOrigin
            else {
                throw AuthError.invalidOAuthConfiguration
            }
        }

        // For signup (initialIdentifier == nil) or when enforcePDSAuthorizationBinding is enabled,
        // enforce that the resolved PDS declares authorization servers matching the initiating issuer
        if oauthState.initialIdentifier == nil || oauthConfig.enforcePDSAuthorizationBinding {
            let protectedResource = try await core.fetchProtectedResourceMetadata(pdsURL: actualPDS)
            if let expectedIssuerURL = URL(string: expectedIssuer) {
                guard protectedResource.authorizationServers.contains(expectedIssuerURL) ||
                      protectedResource.authorizationServers.contains(authServerURL)
                else {
                    throw AuthError.invalidOAuthConfiguration
                }
            }
        }
        // Persist DPoP Key and invalidate any prior cached key for this DID
        try await storage.saveDPoPKeyRepresentation(ephemeralKey.x963Representation, for: did)
        await core.clearDPoPKeyCache(for: did)

        // The flow's ephemeral key is now this DID's DPoP key, so the nonces learned
        // during PAR/token exchange are still valid for it — hand them over instead of
        // re-learning each one through a wasted 400 on the first authenticated request.
        await core.transferOAuthFlowNonces(to: did)
        // Create Session
        let session = Session(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            createdAt: Date(),
            expiresIn: TimeInterval(tokenResponse.expiresIn),
            tokenType: .dpop,
            did: did,
            grantedScopes: tokenResponse.grantedScopes
        )

        let authMetadata = try? await core.fetchAuthorizationServerMetadata(authServerURL: authServerURL)

        // Create/Update Account
        let account = Account(
            did: did,
            handle: handle,
            pdsURL: actualPDS,
            protectedResourceMetadata: nil,
            authorizationServerMetadata: authMetadata,
            bskyAppViewDID: oauthState.bskyAppViewDID ?? "",
            bskyChatDID: oauthState.bskyChatDID ?? ""
        )

        try await storage.saveAccountAndSession(account, session: session, for: did)
        let accountManager = core.accountManager
        try await accountManager.updateAccountFromStorage(did: did)
        try await accountManager.setCurrentAccount(did: did)
        let networkService = core.networkService
        await networkService.setBaseURL(actualPDS)

        return (did: did, handle: account.handle, pdsURL: actualPDS)
    }

    func loginWithPassword(
        identifier: String,
        password: String,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> (did: String, handle: String?, pdsURL: URL) {
        throw AuthError.invalidOAuthConfiguration // PublicOAuthStrategy doesn't support password login
    }

    func logout() async throws {
        let accountManager = core.accountManager
        guard let did = await accountManager.getCurrentAccount()?.did else { return }

        let storage = core.storage
        // Revoke token if possible. A read failure leaves the refresh token valid
        // server-side, which is materially different from having no session at all.
        let session: Session?
        do {
            session = try await storage.getSession(for: did)
            if session == nil {
                LogManager.logInfo(
                    "PublicOAuthStrategy - No stored session for DID \(LogManager.logDID(did)) at logout; nothing to revoke"
                )
            }
        } catch {
            LogManager.logError(
                "PublicOAuthStrategy - Could not read the session for DID \(LogManager.logDID(did)) at logout (\(error)); skipping server-side revocation. The refresh token may remain valid."
            )
            session = nil
        }

        if let session,
           let refreshToken = session.refreshToken,
           let account = await accountManager.getAccount(did: did),
           let endpoint = account.authorizationServerMetadata?.revocationEndpoint
        {
            await core.revokeToken(refreshToken: refreshToken, endpoint: endpoint, did: did)
        }

        try await storage.deleteSession(for: did)
        try await storage.deleteDPoPKey(for: did)
        await core.clearDPoPKeyCache(for: did)
        // Every store `createDPoPProof` reads, or the next login inherits nonces bound
        // to the DPoP key just deleted. The in-memory clear is scoped to this DID, so a
        // second signed-in account keeps its cached nonces. OAuth flow nonces are keyed
        // by host rather than by account and belong to a flow in progress, so they are
        // deliberately untouched here.
        try await storage.saveDPoPNonces([:], for: did)
        try await storage.saveDPoPNoncesByJKT([:], for: did)
        await core.clearNonceCache(for: did)

        await accountManager.clearCurrentAccount()
    }

    func cancelOAuthFlow() async {
        cancellationGeneration &+= 1
        oauthStartTasks.values.forEach { $0.cancel() }
        oauthStartTasks.removeAll()
        oauthStartInProgress = false
        let storage = core.storage
        for token in inFlightOAuthStateTokens {
            deniedStateTokens.insert(token)
            do {
                try await storage.deleteOAuthState(for: token)
            } catch {
                LogManager.logWarning("Failed to delete OAuth state: \(error.localizedDescription)")
            }
        }
        inFlightOAuthStateTokens.removeAll()
    }

    func tokensExist() async -> Bool {
        await core.tokensExist()
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
            targetDID = await core.accountManager.getCurrentAccount()?.did
        }
        guard let did = targetDID else { return }
        await core.refreshCircuitBreaker.reset(for: did)
        _ = try await refreshTokenIfNeeded(forceRefresh: true)
    }

    // MARK: - AuthenticationProvider

    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        try await core.prepareAuthenticatedRequest(request)
    }

    func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (URLRequest, AuthContext) {
        try await core.prepareAuthenticatedRequestWithContext(request)
    }

    func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
        await ensureRefreshClosure()
        return try await core.refreshTokenIfNeeded()
    }

    func refreshTokenIfNeeded(forceRefresh: Bool) async throws -> TokenRefreshResult {
        await ensureRefreshClosure()
        return try await core.refreshTokenIfNeeded(forceRefresh: forceRefresh)
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
            let (newReq, _) = try await core.prepareAuthenticatedRequestWithContext(request)
            let networkService = core.networkService
            let result = try await networkService.request(newReq)
            guard let http = result.1 as? HTTPURLResponse else { throw AuthError.invalidResponse }
            return (result.0, http)
        default:
            throw AuthError.tokenRefreshFailed
        }
    }

    func updateDPoPNonce(for url: URL, from headers: [String: String], did: String?, jkt: String?) async {
        await core.updateDPoPNonce(for: url, from: headers, did: did, jkt: jkt)
    }

    // MARK: - Private Helpers (OAuth Flow)

    private var refreshClosureSet = false

    private func ensureRefreshClosure() async {
        if !refreshClosureSet {
            refreshClosureSet = true
            await setupRefreshClosure()
        }
    }

    private func _startOAuthFlowImpl(identifier: String?, bskyAppViewDID: String?, bskyChatDID: String?) async throws -> (url: URL, state: String) {
        if oauthStartInProgress {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        oauthStartInProgress = true
        defer { oauthStartInProgress = false }

        let didResolver = core.didResolver
        let pdsURL: URL
        let expectedDID: String?
        if let identifier {
            await emitProgress(.resolvingHandle(identifier))
            if identifier.hasPrefix("did:") {
                expectedDID = identifier
                pdsURL = try await didResolver.resolveDIDToPDSURL(did: identifier)
            } else {
                let did = try await didResolver.resolveHandleToDID(handle: identifier)
                expectedDID = did
                pdsURL = try await didResolver.resolveDIDToPDSURL(did: did)
            }
        } else {
            expectedDID = nil
            pdsURL = URL(string: "https://bsky.social")!
        }

        await emitProgress(.fetchingMetadata(url: pdsURL.absoluteString))
        let authServerURL = try await core.resolveAuthServer(for: pdsURL)
        let metadata = try await core.fetchAuthorizationServerMetadata(authServerURL: authServerURL)

        await emitProgress(.generatingParameters)
        let codeVerifier = await core.generateCodeVerifier()
        let codeChallenge = await core.generateCodeChallenge(from: codeVerifier)
        let stateToken = UUID().uuidString
        let ephemeralKey = P256.Signing.PrivateKey()

        let jwk = try await core.createJWK(
                    from: P256.Signing.PrivateKey(rawRepresentation: ephemeralKey.rawRepresentation))
        let dpopJKT = try await core.calculateJWKThumbprint(jwk: jwk)

        let oauthConfig = core.oauthConfig
        let (requestURI, parNonce) = try await core.pushAuthorizationRequest(
            codeChallenge: codeChallenge,
            identifier: identifier,
            endpoint: metadata.pushedAuthorizationRequestEndpoint,
            authServerURL: authServerURL,
            state: stateToken,
            ephemeralKeyRawRepresentation: ephemeralKey.rawRepresentation
        )

        let oauthState = OAuthState(
            stateToken: stateToken,
            codeVerifier: codeVerifier,
            createdAt: Date(),
            initialIdentifier: identifier,
            targetPDSURL: pdsURL,
            ephemeralDPoPKey: ephemeralKey.rawRepresentation,
            parResponseNonce: parNonce,
            bskyAppViewDID: bskyAppViewDID,
            bskyChatDID: bskyChatDID,
            expectedIssuer: metadata.issuer,
            expectedPDSOrigin: pdsURL.absoluteString,
            expectedDID: expectedDID,
            redirectURI: oauthConfig.redirectUri,
            dpopJKT: dpopJKT,
            tokenEndpoint: metadata.tokenEndpoint,
            authorizationEndpoint: metadata.authorizationEndpoint
        )
        let storage = core.storage
        let currentGen = cancellationGeneration
        inFlightOAuthStateTokens.insert(stateToken)
        do {
            try await storage.saveOAuthState(oauthState)
        } catch {
            inFlightOAuthStateTokens.remove(stateToken)
            throw error
        }

        if cancellationGeneration != currentGen || !inFlightOAuthStateTokens.contains(stateToken) {
            deniedStateTokens.insert(stateToken)
            _ = try? await storage.deleteOAuthState(for: stateToken)
            inFlightOAuthStateTokens.remove(stateToken)
            throw AuthError.cancelled
        }
        guard var components = URLComponents(string: metadata.authorizationEndpoint) else {
            throw AuthError.invalidOAuthConfiguration
        }
        components.queryItems = [
            URLQueryItem(name: "request_uri", value: requestURI),
            URLQueryItem(name: "client_id", value: oauthConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: oauthConfig.redirectUri),
        ]

        guard let url = components.url else { throw AuthError.authorizationFailed }
        return (url, stateToken)
    }

    // MARK: - Token Exchange (Strategy-Specific)

    private func exchangeCodeForTokens(
        code: String,
        codeVerifier: String,
        tokenEndpoint: String,
        authServerURL: URL,
        ephemeralKey: P256.Signing.PrivateKey?,
        initialNonce: String?,
        resourceURL: URL?
    ) async throws -> TokenResponse {
        guard let url = URL(string: tokenEndpoint) else {
            throw AuthError.invalidOAuthConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        let oauthConfig = core.oauthConfig
        var params: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": oauthConfig.redirectUri,
            "client_id": oauthConfig.clientId,
            "code_verifier": codeVerifier,
        ]
        if let resourceURL {
            params["resource"] = resourceURL.absoluteString
        }
        request.httpBody = await core.encodeFormData(params)

        if let key = ephemeralKey {
            return try await sendTokenRequestWithEphemeralKey(
                request: request,
                tokenEndpoint: tokenEndpoint,
                code: code,
                codeVerifier: codeVerifier,
                key: key,
                nonce: initialNonce
            )
        } else {
            // Fallback without DPoP (shouldn't happen in normal flow)
            let networkService = core.networkService
            let (data, urlResponse) = try await networkService.request(request, skipTokenRefresh: true)
            guard let httpResponse = urlResponse as? HTTPURLResponse,
                  (200 ..< 300).contains(httpResponse.statusCode)
            else {
                throw AuthError.tokenRefreshFailed
            }
            return try JSONCoders.decode(TokenResponse.self, from: data)
        }
    }

    private func sendTokenRequestWithEphemeralKey(
        request baseRequest: URLRequest,
        tokenEndpoint: String,
        code: String,
        codeVerifier: String,
        key: P256.Signing.PrivateKey,
        nonce: String?
    ) async throws -> TokenResponse {
        var request = baseRequest
        request.timeoutInterval = 30.0

        let dpopProof = try await core.createDPoPProof(
            for: "POST",
            url: tokenEndpoint,
            type: .tokenRequest,
            did: nil,
            ephemeralKeyRawRepresentation: key.rawRepresentation,
            nonce: nonce
        )
        request.setValue(dpopProof, forHTTPHeaderField: "DPoP")

        do {
            let networkService = core.networkService
            let (data, urlResponse) = try await networkService.request(request, skipTokenRefresh: true)

            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }

            if (200 ..< 300).contains(httpResponse.statusCode) {
                await recordFlowNonce(from: httpResponse, endpoint: tokenEndpoint, key: key)
                return try JSONCoders.decode(TokenResponse.self, from: data)
            } else if httpResponse.statusCode == 400 {
                // Handle use_dpop_nonce error. The PAR nonce carried in via `nonce` can
                // already have rotated by the time the code is exchanged, so this single
                // retry runs whether or not an initial nonce was supplied — gating it on
                // `nonce == nil` failed the login outright on a rotated PAR nonce.
                let dpopNonceHeader = await core.extractNonceFromHeaders(httpResponse.allHeaderFields)
                var isNonceError = false
                if let errorResponse = try? JSONCoders.decode(OAuthErrorResponse.self, from: data),
                   errorResponse.error == "use_dpop_nonce"
                {
                    isNonceError = true
                }

                if isNonceError, let receivedNonce = dpopNonceHeader {
                    // The flow's stored nonce is the one the server just rejected. Replace
                    // it now, or the callback hands that dead nonce to the new account and
                    // its first authenticated request pays for another challenge.
                    await core.recordOAuthFlowNonce(
                        receivedNonce,
                        for: tokenEndpoint,
                        ephemeralKeyRawRepresentation: key.rawRepresentation
                    )

                    let newDpopProof = try await core.createDPoPProof(
                        for: "POST",
                        url: tokenEndpoint,
                        type: .tokenRequest,
                        did: nil,
                        ephemeralKeyRawRepresentation: key.rawRepresentation,
                        nonce: receivedNonce
                    )

                    var retryRequest = baseRequest
                    retryRequest.setValue(newDpopProof, forHTTPHeaderField: "DPoP")

                    let (retryData, retryResponse) = try await networkService.request(retryRequest, skipTokenRefresh: true)
                    guard let retryHttpResponse = retryResponse as? HTTPURLResponse,
                          (200 ..< 300).contains(retryHttpResponse.statusCode)
                    else {
                        throw AuthError.tokenRefreshFailed
                    }
                    await recordFlowNonce(from: retryHttpResponse, endpoint: tokenEndpoint, key: key)
                    return try JSONCoders.decode(TokenResponse.self, from: retryData)
                } else {
                    throw AuthError.invalidCredentials
                }
            } else {
                throw AuthError.tokenRefreshFailed
            }
        } catch let error as NetworkError {
            throw AuthError.networkError(error)
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.tokenRefreshFailed
        }
    }

    /// Keeps the flow's nonce current from a token-endpoint response, so the callback
    /// hands the freshest nonce to the new account rather than a spent one.
    private func recordFlowNonce(
        from response: HTTPURLResponse,
        endpoint: String,
        key: P256.Signing.PrivateKey
    ) async {
        guard let nonce = await core.extractNonceFromHeaders(response.allHeaderFields) else { return }
        await core.recordOAuthFlowNonce(
            nonce, for: endpoint, ephemeralKeyRawRepresentation: key.rawRepresentation
        )
    }

    // MARK: - Token Refresh (Strategy-Specific)

    private func performActualRefresh(for account: Account, session: Session) async throws -> TokenRefreshResult {
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await performTokenRefresh(for: account.did, session: session)
        } catch let error as NetworkError {
            // Transport never reached a definitive answer: the refresh token may still be valid.
            await core.refreshCircuitBreaker.recordFailure(for: account.did, kind: .network)
            throw AuthError.networkError(error)
        }

        if (200 ..< 300).contains(response.statusCode) {
            let tokenResponse = try JSONCoders.decode(TokenResponse.self, from: data)
            let newSession = Session(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                createdAt: Date(),
                expiresIn: TimeInterval(tokenResponse.expiresIn),
                tokenType: session.tokenType,
                did: account.did,
                // Refresh responses restate the grant; the server may have reduced
                // it (e.g. the user revoked scopes), so persist the new set.
                grantedScopes: tokenResponse.grantedScopes
            )
            // The server has rotated the refresh token; persistence failures are handled
            // inside (retry + pending key + in-memory) and must not fail the refresh.
            await core.persistRefreshedSession(newSession, for: account)
            await core.refreshCircuitBreaker.recordSuccess(for: account.did)
            return .refreshedSuccessfully
        }

        // Distinguish a definitive rejection (token consumed/revoked — never retry it)
        // from transient server trouble (safe to retry with the same token).
        if response.statusCode == 400 || response.statusCode == 401,
           let errorResponse = try? JSONCoders.decode(OAuthErrorResponse.self, from: data),
           errorResponse.error == "invalid_grant"
        {
            LogManager.logError(
                "Token refresh definitively rejected (invalid_grant) for DID: \(LogManager.logDID(account.did))"
            )
            await core.refreshCircuitBreaker.recordFailure(for: account.did, kind: .invalidGrant)
            throw AuthError.invalidCredentials
        }

        let kind: RefreshCircuitBreaker.RefreshFailureKind = (500 ..< 600).contains(response.statusCode) ? .server : .other
        await core.refreshCircuitBreaker.recordFailure(for: account.did, kind: kind)
        throw AuthError.tokenRefreshFailed
    }

    private func performTokenRefresh(for did: String, session: Session) async throws -> (Data, HTTPURLResponse) {
        let accountManager = core.accountManager
        guard let account = await accountManager.getAccount(did: did),
              let metadata = account.authorizationServerMetadata,
              let refreshToken = session.refreshToken
        else {
            throw AuthError.tokenRefreshFailed
        }

        guard let endpointURL = URL(string: metadata.tokenEndpoint) else {
            throw AuthError.tokenRefreshFailed
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        let oauthConfig = core.oauthConfig
        let params = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": oauthConfig.clientId,
        ]
        request.httpBody = await core.encodeFormData(params)

        let proof = try await core.createDPoPProof(
            for: "POST", url: metadata.tokenEndpoint, type: .tokenRefresh, did: did
        )
        request.setValue(proof, forHTTPHeaderField: "DPoP")

        let networkService = core.networkService
        let (data, response) = try await networkService.request(request, skipTokenRefresh: true)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        // Handle nonce mismatch with retry
        if httpResponse.statusCode == 400 {
            if let errorResponse = try? JSONCoders.decode(OAuthErrorResponse.self, from: data),
               errorResponse.error == "use_dpop_nonce",
               let receivedNonce = await core.extractNonceFromHeaders(httpResponse.allHeaderFields)
            {
                // Retry only once the fresh nonce is in every store the proof reads —
                // otherwise the retry replays the nonce the server just rejected.
                guard let domain = endpointURL.host?.lowercased(),
                      await core.updateDPoPNonceInternal(domain: domain, nonce: receivedNonce, for: did)
                else {
                    LogManager.logError(
                        "Could not apply the server's fresh DPoP nonce for DID: \(LogManager.logDID(did)); skipping the refresh retry that would replay the stale nonce",
                        category: .authentication
                    )
                    return (data, httpResponse)
                }

                let retryProof = try await core.createDPoPProof(
                    for: "POST", url: metadata.tokenEndpoint, type: .tokenRefresh, did: did
                )
                var retryRequest = request
                retryRequest.setValue(retryProof, forHTTPHeaderField: "DPoP")

                let (retryData, retryResponse) = try await networkService.request(retryRequest, skipTokenRefresh: true)
                guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                    throw AuthError.invalidResponse
                }
                return (retryData, retryHttpResponse)
            }
        }

        return (data, httpResponse)
    }

    // MARK: - Progress Helpers

    private func emitProgress(_ event: AuthProgressEvent) async {
        await progressDelegate?.authenticationProgress(event)
    }
}
