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

  let core: OAuthCore

  // Delegates
  private weak var progressDelegate: AuthProgressDelegate?
  private weak var failureDelegate: AuthFailureDelegate?

  // OAuth flow deduplication state
  private var oauthStartInProgress = false
  private var oauthStartTasks: [String: Task<URL, Error>] = [:]

  // MARK: - Initialization

  init(
    storage: KeychainStorage,
    accountManager: AccountManaging,
    networkService: NetworkService,
    oauthConfig: OAuthConfig,
    didResolver: DIDResolving
  ) {
    self.core = OAuthCore(
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
    await ensureRefreshClosure()

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
    let codeVerifier = await core.generateCodeVerifier()
    let codeChallenge = await core.generateCodeChallenge(from: codeVerifier)
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

    let authServerURL = try await core.resolveAuthServer(for: finalPDSURL)
    let metadata = try await core.fetchAuthorizationServerMetadata(authServerURL: authServerURL)

    let oauthConfig = await core.oauthConfig
    let (requestURI, parNonce) = try await core.pushAuthorizationRequest(
      codeChallenge: codeChallenge,
      identifier: nil,
      endpoint: metadata.pushedAuthorizationRequestEndpoint,
      authServerURL: authServerURL,
      state: stateToken,
      ephemeralKeyForFlow: ephemeralKey
    )

    var finalState = oauthState
    finalState.parResponseNonce = parNonce
    let storage = await core.storage
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

    guard let code = await core.extractAuthorizationCode(from: url),
          let stateToken = await core.extractState(from: url)
    else { throw AuthError.invalidCallbackURL }

    let storage = await core.storage
    guard let oauthState = try await storage.getOAuthState(for: stateToken) else {
      throw AuthError.invalidCallbackURL
    }

    guard let keyData = oauthState.ephemeralDPoPKey else { throw AuthError.dpopKeyError }
    let ephemeralKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)

    try await storage.deleteOAuthState(for: stateToken)

    guard let pdsURL = oauthState.targetPDSURL else { throw AuthError.invalidOAuthConfiguration }
    let authServerURL = try await core.resolveAuthServer(for: pdsURL)
    let metadata = try await core.fetchAuthorizationServerMetadata(authServerURL: authServerURL)

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
    let didResolver = await core.didResolver
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
    let accountManager = await core.accountManager
    try await accountManager.updateAccountFromStorage(did: did)
    try await accountManager.setCurrentAccount(did: did)
    let networkService = await core.networkService
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
    let accountManager = await core.accountManager
    guard let did = await accountManager.getCurrentAccount()?.did else { return }

    let storage = await core.storage
    // Revoke token if possible
    if let session = try? await storage.getSession(for: did),
       let refreshToken = session.refreshToken,
       let account = await accountManager.getAccount(did: did),
       let endpoint = account.authorizationServerMetadata?.revocationEndpoint
    {
      await core.revokeToken(refreshToken: refreshToken, endpoint: endpoint, did: did)
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
      let networkService = await core.networkService
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

  private func _startOAuthFlowImpl(identifier: String?, bskyAppViewDID: String?, bskyChatDID: String?) async throws -> URL {
    if oauthStartInProgress {
      try? await Task.sleep(nanoseconds: 100_000_000)
    }
    oauthStartInProgress = true
    defer { oauthStartInProgress = false }

    let didResolver = await core.didResolver
    let pdsURL: URL
    if let identifier {
      await emitProgress(.resolvingHandle(identifier))
      let did = try await didResolver.resolveHandleToDID(handle: identifier)
      pdsURL = try await didResolver.resolveDIDToPDSURL(did: did)
    } else {
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

    let oauthConfig = await core.oauthConfig
    let (requestURI, parNonce) = try await core.pushAuthorizationRequest(
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
    let storage = await core.storage
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

    let oauthConfig = await core.oauthConfig
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
      let networkService = await core.networkService
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

    let dpopProof = try await core.createDPoPProof(
      for: "POST",
      url: tokenEndpoint,
      type: .tokenRequest,
      did: nil,
      ephemeralKey: key,
      nonce: nonce
    )
    request.setValue(dpopProof, forHTTPHeaderField: "DPoP")

    do {
      let networkService = await core.networkService
      let (data, urlResponse) = try await networkService.request(request, skipTokenRefresh: true)

      guard let httpResponse = urlResponse as? HTTPURLResponse else {
        throw AuthError.invalidResponse
      }

      if (200 ..< 300).contains(httpResponse.statusCode) {
        return try JSONDecoder().decode(TokenResponse.self, from: data)
      } else if httpResponse.statusCode == 400 && nonce == nil {
        // Handle use_dpop_nonce error
        let dpopNonceHeader = await core.extractNonceFromHeaders(httpResponse.allHeaderFields)
        var isNonceError = false
        if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data),
           errorResponse.error == "use_dpop_nonce"
        {
          isNonceError = true
        }

        if isNonceError, let receivedNonce = dpopNonceHeader {
          let newDpopProof = try await core.createDPoPProof(
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

  // MARK: - Token Refresh (Strategy-Specific)

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
      let storage = await core.storage
      try await storage.saveAccountAndSession(account, session: newSession, for: account.did)
      await core.refreshCircuitBreaker.recordSuccess(for: account.did)
      return .refreshedSuccessfully
    } else {
      throw AuthError.tokenRefreshFailed
    }
  }

  private func performTokenRefresh(for did: String, session: Session) async throws -> (Data, HTTPURLResponse) {
    let accountManager = await core.accountManager
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

    let oauthConfig = await core.oauthConfig
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

    let networkService = await core.networkService
    let (data, response) = try await networkService.request(request, skipTokenRefresh: true)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw AuthError.invalidResponse
    }

    // Handle nonce mismatch with retry
    if httpResponse.statusCode == 400 {
      if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data),
         errorResponse.error == "use_dpop_nonce",
         let receivedNonce = await core.extractNonceFromHeaders(httpResponse.allHeaderFields)
      {
        // Update nonce and retry
        if let domain = endpointURL.host?.lowercased() {
          await core.updateDPoPNonceInternal(domain: domain, nonce: receivedNonce, for: did)
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
