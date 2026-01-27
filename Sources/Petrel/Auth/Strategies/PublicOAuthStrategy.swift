//
//  PublicOAuthStrategy.swift
//  Petrel
//
//  Created by Josh LaCalamito on 1/19/26.
//

#if canImport(CryptoKit)
    import CryptoKit
#else
    @preconcurrency import Crypto
#endif
import Foundation
import JSONWebAlgorithms
import JSONWebKey
import JSONWebSignature

/// Authentication strategy for public clients (e.g. mobile apps)
/// Handles:
/// - Pushed Authorization Requests (PAR)
/// - PKCE Flow
/// - DPoP Key Management & Signing
/// - Token Refresh with DPoP Replay Protection
/// - Automatic DPoP Nonce Handling
actor PublicOAuthStrategy: AuthStrategy {
    // MARK: - Properties

    private let storage: KeychainStorage
    private let accountManager: AccountManaging
    private let networkService: NetworkService
    private let oauthConfig: OAuthConfig
    private let didResolver: DIDResolving
    private var refreshCoordinators: [String: TokenRefreshCoordinator] = [:]
    private let refreshCircuitBreaker = RefreshCircuitBreaker()

    // Delegates
    private weak var progressDelegate: AuthProgressDelegate?
    private weak var failureDelegate: AuthFailureDelegate?

    // State
    private var oauthStartInProgress = false
    private var oauthStartTasks: [String: Task<URL, Error>] = [:]
    private var oauthFlowNonces: [String: String] = [:]
    private var noncesByThumbprint: [String: [String: String]] = [:]
    private var ambiguousRefreshUntil: [String: Date] = [:]
    private var usedRefreshTokens: Set<String> = []
    private var activeRefreshTasks: [String: Task<TokenRefreshResult, Error>] = [:]

    /// One-shot override for refresh
    private var nextRefreshResourceOverride: String?

    // MARK: - Initialization

    init(
        storage: KeychainStorage,
        accountManager: AccountManaging,
        networkService: NetworkService,
        oauthConfig: OAuthConfig,
        didResolver: DIDResolving
    ) {
        self.storage = storage
        self.accountManager = accountManager
        self.networkService = networkService
        self.oauthConfig = oauthConfig
        self.didResolver = didResolver
    }

    // MARK: - AuthStrategy Implementation

    func startOAuthFlow(
        identifier: String?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> URL {
        let key = identifier?.lowercased() ?? "__signup__"

        if let existing = oauthStartTasks[key] {
            return try await existing.value
        }

        let task = Task.detached(priority: .userInitiated) { [weak self] () throws -> URL in
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
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        let ephemeralKey = P256.Signing.PrivateKey()

        let oauthState = OAuthState(
            stateToken: stateToken,
            codeVerifier: codeVerifier,
            createdAt: Date(),
            initialIdentifier: nil,
            targetPDSURL: finalPDSURL,
            ephemeralDPoPKey: ephemeralKey.rawRepresentation,
            parResponseNonce: nil,
            bskyAppViewDID: bskyAppViewDID,
            bskyChatDID: bskyChatDID
        )

        let authServerURL = try await resolveAuthServer(for: finalPDSURL)
        let metadata = try await fetchAuthorizationServerMetadata(authServerURL: authServerURL)

        let (requestURI, parNonce) = try await pushAuthorizationRequest(
            codeChallenge: codeChallenge,
            identifier: nil,
            endpoint: metadata.pushedAuthorizationRequestEndpoint,
            authServerURL: authServerURL,
            state: stateToken,
            ephemeralKeyForFlow: ephemeralKey
        )

        var finalState = oauthState
        finalState.parResponseNonce = parNonce
        try await storage.saveOAuthState(finalState)

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

        guard let code = extractAuthorizationCode(from: url),
              let stateToken = extractState(from: url)
        else { throw AuthError.invalidCallbackURL }

        guard let oauthState = try await storage.getOAuthState(for: stateToken) else {
            throw AuthError.invalidCallbackURL
        }

        guard let keyData = oauthState.ephemeralDPoPKey else { throw AuthError.dpopKeyError }
        let ephemeralKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)

        try await storage.deleteOAuthState(for: stateToken)

        guard let pdsURL = oauthState.targetPDSURL else { throw AuthError.invalidOAuthConfiguration }
        let authServerURL = try await resolveAuthServer(for: pdsURL)
        let metadata = try await fetchAuthorizationServerMetadata(authServerURL: authServerURL)

        let tokenResponse = try await exchangeCodeForTokens(
            code: code,
            codeVerifier: oauthState.codeVerifier,
            tokenEndpoint: metadata.tokenEndpoint,
            authServerURL: authServerURL,
            ephemeralKey: ephemeralKey,
            initialNonce: oauthState.parResponseNonce,
            resourceURL: pdsURL
        )

        guard let did = tokenResponse.sub else { throw AuthError.invalidResponse }

        // Resolve real PDS
        let (handle, actualPDS) = try await didResolver.resolveDIDToHandleAndPDSURL(did: did)

        // Persist DPoP Key
        try await storage.saveDPoPKey(ephemeralKey, for: did)

        // Create Session
        let session = Session(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            createdAt: Date(),
            expiresIn: TimeInterval(tokenResponse.expiresIn),
            tokenType: .dpop,
            did: did
        )

        // Create/Update Account
        let account = Account(
            did: did,
            handle: handle ?? oauthState.initialIdentifier,
            pdsURL: actualPDS,
            protectedResourceMetadata: nil,
            authorizationServerMetadata: metadata,
            bskyAppViewDID: oauthState.bskyAppViewDID ?? "",
            bskyChatDID: oauthState.bskyChatDID ?? ""
        )

        try await storage.saveAccountAndSession(account, session: session, for: did)
        try await accountManager.updateAccountFromStorage(did: did)
        try await accountManager.setCurrentAccount(did: did)
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
        guard let did = await accountManager.getCurrentAccount()?.did else { return }

        // Revoke token if possible
        if let session = try? await storage.getSession(for: did),
           let refreshToken = session.refreshToken,
           let account = await accountManager.getAccount(did: did),
           let endpoint = account.authorizationServerMetadata?.revocationEndpoint
        {
            await revokeToken(refreshToken: refreshToken, endpoint: endpoint, did: did)
        }

        try await storage.deleteSession(for: did)
        try await storage.deleteDPoPKey(for: did)
        try await storage.saveDPoPNonces([:], for: did)

        await accountManager.clearCurrentAccount()
    }

    func cancelOAuthFlow() async {
        oauthStartTasks.values.forEach { $0.cancel() }
        oauthStartTasks.removeAll()
        oauthStartInProgress = false
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
        guard let did = targetDID else { return }
        await refreshCircuitBreaker.reset(for: did)
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
        let isTokenEndpoint = account.authorizationServerMetadata?.tokenEndpoint == request.url?.absoluteString
        let type: DPoPProofType = isTokenEndpoint ? .tokenRequest : .resourceAccess

        // Generate DPoP
        let proof = try await createDPoPProof(
            for: request.httpMethod ?? "GET",
            url: request.url?.absoluteString ?? "",
            type: type,
            accessToken: isTokenEndpoint ? nil : session.accessToken,
            did: account.did
        )
        req.setValue(proof, forHTTPHeaderField: "DPoP")

        if !isTokenEndpoint {
            req.setValue("DPoP \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        // Get JKT for context
        let key = try await getOrCreateDPoPKey(for: account.did)
        let jwk = try createJWK(from: key)
        let thumbprint = try calculateJWKThumbprint(jwk: jwk)

        return (req, AuthContext(did: account.did, jkt: thumbprint))
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

        if let task = activeRefreshTasks[did] { return try await task.value }

        guard let refreshToken = session.refreshToken else { throw AuthError.tokenRefreshFailed }
        if usedRefreshTokens.contains(refreshToken) { throw AuthError.tokenRefreshFailed }

        // Circuit breaker check
        guard await refreshCircuitBreaker.canAttemptRefresh(for: did) else { throw AuthError.tokenRefreshFailed }

        // Check expiry
        if !forceRefresh && !session.isExpiringSoon { return .stillValid }

        usedRefreshTokens.insert(refreshToken)

        let task = Task<TokenRefreshResult, Error> {
            try await performActualRefresh(for: account, session: session)
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
        guard let domain = url.host?.lowercased() else { return }

        // Extract nonce case-insensitively
        var nonce: String?
        for (key, value) in headers {
            if key.caseInsensitiveCompare("DPoP-Nonce") == .orderedSame {
                nonce = value
                break
            }
        }
        guard let nonce else { return }

        var targetDID = did
        if targetDID == nil {
            targetDID = await accountManager.getCurrentAccount()?.did
        }
        guard let resolvedDID = targetDID else { return }

        // Update persistent store
        var nonces = (try? await storage.getDPoPNonces(for: resolvedDID)) ?? [:]
        nonces[domain] = nonce
        try? await storage.saveDPoPNonces(nonces, for: resolvedDID)

        if let jkt {
            var jktNonces = (try? await storage.getDPoPNoncesByJKT(for: resolvedDID)) ?? [:]
            var domainMap = jktNonces[jkt] ?? [:]
            domainMap[domain] = nonce
            jktNonces[jkt] = domainMap
            try? await storage.saveDPoPNoncesByJKT(jktNonces, for: resolvedDID)

            // Update memory
            var memMap = noncesByThumbprint[jkt] ?? [:]
            memMap[domain] = nonce
            noncesByThumbprint[jkt] = memMap
        }
    }

    // MARK: - Private Helpers (OAuth Flow)

    private func _startOAuthFlowImpl(identifier: String?, bskyAppViewDID: String?, bskyChatDID: String?) async throws -> URL {
        if oauthStartInProgress {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        oauthStartInProgress = true
        defer { oauthStartInProgress = false }

        let pdsURL: URL
        if let identifier {
            await emitProgress(.resolvingHandle(identifier))
            let did = try await didResolver.resolveHandleToDID(handle: identifier)
            pdsURL = try await didResolver.resolveDIDToPDSURL(did: did)
        } else {
            pdsURL = URL(string: "https://bsky.social")!
        }

        await emitProgress(.fetchingMetadata(url: pdsURL.absoluteString))
        let authServerURL = try await resolveAuthServer(for: pdsURL)
        let metadata = try await fetchAuthorizationServerMetadata(authServerURL: authServerURL)

        await emitProgress(.generatingParameters)
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        let stateToken = UUID().uuidString
        let ephemeralKey = P256.Signing.PrivateKey()

        let (requestURI, parNonce) = try await pushAuthorizationRequest(
            codeChallenge: codeChallenge,
            identifier: identifier,
            endpoint: metadata.pushedAuthorizationRequestEndpoint,
            authServerURL: authServerURL,
            state: stateToken,
            ephemeralKeyForFlow: ephemeralKey
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
            bskyChatDID: bskyChatDID
        )
        try await storage.saveOAuthState(oauthState)

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

    private func resolveAuthServer(for pdsURL: URL) async throws -> URL {
        do {
            let metadata = try await fetchProtectedResourceMetadata(pdsURL: pdsURL)
            if let server = metadata.authorizationServers.first { return server }
        } catch {}
        return pdsURL
    }

    // MARK: - PAR (Pushed Authorization Request)

    private func pushAuthorizationRequest(
        codeChallenge: String,
        identifier: String?,
        endpoint: String,
        authServerURL: URL,
        state: String,
        ephemeralKeyForFlow: P256.Signing.PrivateKey?
    ) async throws -> (requestURI: String, parNonce: String?) {
        var parameters: [String: String] = [
            "client_id": oauthConfig.clientId,
            "redirect_uri": oauthConfig.redirectUri,
            "response_type": "code",
            "code_challenge_method": "S256",
            "code_challenge": codeChallenge,
            "state": state,
            "scope": oauthConfig.scope,
        ]

        if let identifier = identifier {
            parameters["login_hint"] = identifier
        }

        let body = encodeFormData(parameters)

        guard let endpointURL = URL(string: endpoint) else {
            throw AuthError.invalidOAuthConfiguration
        }
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // DPoP Proof Generation
        var proofKey: P256.Signing.PrivateKey?
        let dpopProof: String

        if let providedKey = ephemeralKeyForFlow {
            proofKey = providedKey
            dpopProof = try await createDPoPProof(
                for: "POST", url: endpoint, type: .authorization, ephemeralKey: providedKey
            )
        } else {
            let tempKey = P256.Signing.PrivateKey()
            proofKey = tempKey
            dpopProof = try await createDPoPProof(
                for: "POST", url: endpoint, type: .authorization, ephemeralKey: tempKey
            )
        }
        request.setValue(dpopProof, forHTTPHeaderField: "DPoP")

        let (data, response) = try await networkService.request(request)

        guard let httpResponse = response as? HTTPURLResponse else { throw AuthError.invalidResponse }

        if (200 ... 299).contains(httpResponse.statusCode) {
            guard let parResponse = try? JSONDecoder().decode(PARResponse.self, from: data) else {
                throw AuthError.invalidResponse
            }
            let requestURI = parResponse.requestURI
            let parNonce = extractNonceFromHeaders(httpResponse.allHeaderFields)
            return (requestURI, parNonce)
        } else if httpResponse.statusCode == 400 {
            let dpopNonceHeader = extractNonceFromHeaders(httpResponse.allHeaderFields)
            var isNonceError = false
            if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data),
               errorResponse.error == "use_dpop_nonce"
            {
                isNonceError = true
            }

            if isNonceError, let receivedNonce = dpopNonceHeader, let key = proofKey {
                // Retry with nonce
                var retryRequest = request
                let retryProof = try await createDPoPProof(
                    for: "POST", url: endpoint, type: .authorization, ephemeralKey: key, nonce: receivedNonce
                )
                retryRequest.setValue(retryProof, forHTTPHeaderField: "DPoP")

                let (retryData, retryResponse) = try await networkService.request(retryRequest)
                guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                    throw AuthError.invalidResponse
                }

                if (200 ... 299).contains(retryHttpResponse.statusCode) {
                    guard let parResponse = try? JSONDecoder().decode(PARResponse.self, from: retryData) else {
                        throw AuthError.invalidResponse
                    }
                    let parNonce = extractNonceFromHeaders(retryHttpResponse.allHeaderFields)
                    return (parResponse.requestURI, parNonce)
                } else {
                    throw AuthError.authorizationFailed
                }
            } else {
                throw AuthError.authorizationFailed
            }
        } else {
            throw AuthError.authorizationFailed
        }
    }

    // MARK: - Token Exchange

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
        request.httpBody = encodeFormData(params)

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
            let (data, urlResponse) = try await networkService.request(request, skipTokenRefresh: true)
            guard let httpResponse = urlResponse as? HTTPURLResponse,
                  (200 ..< 300).contains(httpResponse.statusCode)
            else {
                throw AuthError.tokenRefreshFailed
            }
            return try JSONDecoder().decode(TokenResponse.self, from: data)
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

        let dpopProof = try await createDPoPProof(
            for: "POST",
            url: tokenEndpoint,
            type: .tokenRequest,
            did: nil,
            ephemeralKey: key,
            nonce: nonce
        )
        request.setValue(dpopProof, forHTTPHeaderField: "DPoP")

        do {
            let (data, urlResponse) = try await networkService.request(request, skipTokenRefresh: true)

            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }

            if (200 ..< 300).contains(httpResponse.statusCode) {
                return try JSONDecoder().decode(TokenResponse.self, from: data)
            } else if httpResponse.statusCode == 400 && nonce == nil {
                // Handle use_dpop_nonce error
                let dpopNonceHeader = extractNonceFromHeaders(httpResponse.allHeaderFields)
                var isNonceError = false
                if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data),
                   errorResponse.error == "use_dpop_nonce"
                {
                    isNonceError = true
                }

                if isNonceError, let receivedNonce = dpopNonceHeader {
                    let newDpopProof = try await createDPoPProof(
                        for: "POST",
                        url: tokenEndpoint,
                        type: .tokenRequest,
                        did: nil,
                        ephemeralKey: key,
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
                    return try JSONDecoder().decode(TokenResponse.self, from: retryData)
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

    // MARK: - Metadata Fetching

    private func fetchProtectedResourceMetadata(pdsURL: URL) async throws -> ProtectedResourceMetadata {
        let endpoint = "\(pdsURL.absoluteString)/.well-known/oauth-protected-resource"
        guard let endpointURL = URL(string: endpoint) else {
            throw AuthError.invalidOAuthConfiguration
        }
        let request = URLRequest(url: endpointURL)

        let maxRetries = 3
        var lastError: Error?
        for attempt in 1 ... maxRetries {
            do {
                let (data, _) = try await networkService.request(request)
                return try JSONDecoder().decode(ProtectedResourceMetadata.self, from: data)
            } catch {
                lastError = error
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt - 1)) * 0.1
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw lastError ?? AuthError.networkError(NetworkError.requestFailed)
    }

    private func fetchAuthorizationServerMetadata(authServerURL: URL) async throws -> AuthorizationServerMetadata {
        let endpoint = "\(authServerURL.absoluteString)/.well-known/oauth-authorization-server"
        guard let endpointURL = URL(string: endpoint) else {
            throw AuthError.invalidOAuthConfiguration
        }
        let request = URLRequest(url: endpointURL)

        let maxRetries = 3
        var lastError: Error?
        for attempt in 1 ... maxRetries {
            do {
                let (data, _) = try await networkService.request(request)
                return try JSONDecoder().decode(AuthorizationServerMetadata.self, from: data)
            } catch {
                lastError = error
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt - 1)) * 0.1
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw lastError ?? AuthError.networkError(NetworkError.requestFailed)
    }

    // MARK: - Token Refresh

    private func performActualRefresh(for account: Account, session: Session) async throws -> TokenRefreshResult {
        let (data, response) = try await performTokenRefresh(for: account.did, session: session)

        if (200 ..< 300).contains(response.statusCode) {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            let newSession = Session(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                createdAt: Date(),
                expiresIn: TimeInterval(tokenResponse.expiresIn),
                tokenType: session.tokenType,
                did: account.did
            )
            try await storage.saveAccountAndSession(account, session: newSession, for: account.did)
            await refreshCircuitBreaker.recordSuccess(for: account.did)
            return .refreshedSuccessfully
        } else {
            throw AuthError.tokenRefreshFailed
        }
    }

    private func performTokenRefresh(for did: String, session: Session) async throws -> (Data, HTTPURLResponse) {
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

        let params = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": oauthConfig.clientId,
        ]
        request.httpBody = encodeFormData(params)

        let proof = try await createDPoPProof(
            for: "POST", url: metadata.tokenEndpoint, type: .tokenRefresh, did: did
        )
        request.setValue(proof, forHTTPHeaderField: "DPoP")

        let (data, response) = try await networkService.request(request, skipTokenRefresh: true)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        // Handle nonce mismatch with retry
        if httpResponse.statusCode == 400 {
            if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data),
               errorResponse.error == "use_dpop_nonce",
               let receivedNonce = extractNonceFromHeaders(httpResponse.allHeaderFields)
            {
                // Update nonce and retry
                if let domain = endpointURL.host?.lowercased() {
                    await updateDPoPNonceInternal(domain: domain, nonce: receivedNonce, for: did)
                }

                let retryProof = try await createDPoPProof(
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

    private func revokeToken(refreshToken: String, endpoint: String, did: String) async {
        guard let url = URL(string: endpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let params = ["token": refreshToken, "client_id": oauthConfig.clientId]
        request.httpBody = encodeFormData(params)

        if let proof = try? await createDPoPProof(for: "POST", url: endpoint, type: .tokenRequest, did: did) {
            request.setValue(proof, forHTTPHeaderField: "DPoP")
        }

        _ = try? await networkService.request(request)
    }

    // MARK: - DPoP Proof Creation

    private func createDPoPProof(
        for method: String,
        url: String,
        type: DPoPProofType,
        accessToken: String? = nil,
        did: String? = nil,
        ephemeralKey: P256.Signing.PrivateKey? = nil,
        nonce: String? = nil
    ) async throws -> String {
        var targetDID: String? = did
        if targetDID == nil {
            targetDID = await accountManager.getCurrentAccount()?.did
        }

        let privateKey: P256.Signing.PrivateKey
        if let key = ephemeralKey {
            privateKey = key
        } else if let currentDID = targetDID {
            privateKey = try await getOrCreateDPoPKey(for: currentDID)
        } else {
            throw AuthError.noActiveAccount
        }

        let jwk = try createJWK(from: privateKey)
        let keyThumbprint = try calculateJWKThumbprint(jwk: jwk)

        var ath: String?
        if type == .resourceAccess, let token = accessToken {
            ath = calculateATH(from: token)
        }

        // Determine nonce to use
        let finalNonce: String?
        if let explicitNonce = nonce {
            finalNonce = explicitNonce
        } else if did == nil && ephemeralKey != nil, let urlObject = URL(string: url), let domain = urlObject.host?.lowercased() {
            finalNonce = oauthFlowNonces[domain]
        } else if let targetDID = targetDID, let urlObject = URL(string: url), let domain = urlObject.host?.lowercased() {
            // Multi-layer nonce retrieval
            if let jktNonce = noncesByThumbprint[keyThumbprint]?[domain] {
                finalNonce = jktNonce
            } else if let persistedJktNonces = try? await storage.getDPoPNoncesByJKT(for: targetDID),
                      let jktPersistentNonce = persistedJktNonces[keyThumbprint]?[domain]
            {
                finalNonce = jktPersistentNonce
            } else if let storedNonces = try? await storage.getDPoPNonces(for: targetDID),
                      let didNonce = storedNonces[domain]
            {
                finalNonce = didNonce
            } else {
                finalNonce = nil
            }
        } else {
            finalNonce = nil
        }

        // Canonicalize HTU
        let htuValue: String
        if let urlObj = URL(string: url) {
            htuValue = canonicalHTU(urlObj)
        } else {
            htuValue = url
        }

        let payload = DPoPPayload(
            jti: "\(UUID().uuidString)-\(UInt64.random(in: 0 ... UInt64.max))",
            htm: method,
            htu: htuValue,
            iat: Int(Date().timeIntervalSince1970),
            exp: Int(Date().timeIntervalSince1970) + 120,
            ath: ath,
            nonce: finalNonce
        )

        let jwtPayloadData = try JSONEncoder().encode(payload)

        let header = DefaultJWSHeaderImpl(
            algorithm: .ES256,
            jwk: jwk, type: "dpop+jwt"
        )
        let headerData = try JSONEncoder().encode(header)
        let headerBase64 = headerData.base64URLEscaped()

        let signingInput = "\(headerBase64).\(base64URLEncode(jwtPayloadData))"
        let signatureData = try privateKey.signature(for: Data(signingInput.utf8))
        let signatureBase64 = base64URLEncode(signatureData.rawRepresentation)

        return "\(headerBase64).\(base64URLEncode(jwtPayloadData)).\(signatureBase64)"
    }

    private func getOrCreateDPoPKey(for did: String) async throws -> P256.Signing.PrivateKey {
        do {
            if let existingKey = try await storage.getDPoPKey(for: did) {
                return existingKey
            }
        } catch {
            throw AuthError.dpopKeyError
        }

        // Check if this is an OAuth session that requires a specific key
        if let session = try? await storage.getSession(for: did), session.tokenType == .dpop {
            throw AuthError.dpopKeyError
        }

        let newKey = P256.Signing.PrivateKey()
        try await storage.saveDPoPKey(newKey, for: did)
        return newKey
    }

    private func updateDPoPNonceInternal(domain: String, nonce: String, for did: String) async {
        do {
            var nonces = try await storage.getDPoPNonces(for: did) ?? [:]
            nonces[domain] = nonce
            try await storage.saveDPoPNonces(nonces, for: did)
        } catch {}
    }

    // MARK: - JWK & Crypto Helpers

    private func createJWK(from privateKey: P256.Signing.PrivateKey) throws -> JWK {
        let publicKey = privateKey.publicKey
        let x = publicKey.x963Representation.dropFirst().prefix(32)
        let y = publicKey.x963Representation.suffix(32)
        return JWK(keyType: .ellipticCurve, curve: .p256, x: x, y: y)
    }

    private func calculateJWKThumbprint(jwk: JWK) throws -> String {
        let canonicalJWK: [String: String] = [
            "crv": "P-256",
            "kty": "EC",
            "x": jwk.x?.base64URLEscaped() ?? "",
            "y": jwk.y?.base64URLEscaped() ?? "",
        ]
        let jsonString = "{\"crv\":\"P-256\",\"kty\":\"EC\",\"x\":\"\(canonicalJWK["x"]!)\",\"y\":\"\(canonicalJWK["y"]!)\"}"
        let jsonData = Data(jsonString.utf8)
        let hash = SHA256.hash(data: jsonData)
        return Data(hash).base64URLEscaped()
    }

    private func calculateATH(from token: String) -> String {
        let tokenData = Data(token.utf8)
        let hash = SHA256.hash(data: tokenData)
        return base64URLEncode(Data(hash))
    }

    private func canonicalHTU(_ url: URL) -> String {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        comps.scheme = comps.scheme?.lowercased()
        comps.host = comps.host?.lowercased()
        if (comps.scheme == "https" && comps.port == 443) || (comps.scheme == "http" && comps.port == 80) {
            comps.port = nil
        }
        if comps.path.isEmpty { comps.path = "/" }
        comps.fragment = nil
        comps.query = nil
        return comps.string ?? url.absoluteString
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        let data = Data((0 ..< 32).map { _ in UInt8.random(in: 0 ... 255) })
        return base64URLEncode(data)
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return base64URLEncode(Data(hash))
    }

    // MARK: - Encoding Helpers

    private func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func encodeFormData(_ params: [String: String]) -> Data {
        let queryItems = params.map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }
        return queryItems.joined(separator: "&").data(using: .utf8) ?? Data()
    }

    // MARK: - URL Helpers

    private func extractAuthorizationCode(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value
    }

    private func extractState(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "state" })?
            .value
    }

    private func extractNonceFromHeaders(_ headers: [AnyHashable: Any]) -> String? {
        for (key, value) in headers {
            if let keyString = key as? String,
               keyString.caseInsensitiveCompare("DPoP-Nonce") == .orderedSame
            {
                return value as? String
            }
        }
        return nil
    }

    // MARK: - Progress Helpers

    private func emitProgress(_ event: AuthProgressEvent) async {
        await progressDelegate?.authenticationProgress(event)
    }
}

// MARK: - Supporting Types

private struct DPoPPayload: Encodable {
    let jti: String
    let htm: String
    let htu: String
    let iat: Int
    let exp: Int?
    let ath: String?
    let nonce: String?
}

private struct PARResponse: Decodable {
    let requestURI: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case requestURI = "request_uri"
        case expiresIn = "expires_in"
    }
}

private struct OAuthErrorResponse: Decodable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}
