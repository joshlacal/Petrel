//
//  OAuthCore.swift
//  Petrel
//
//  Extracted from PublicOAuthStrategy to enable reuse by CABOAuthStrategy.
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

/// Shared OAuth machinery (DPoP, PKCE, nonce tracking, metadata fetching,
/// refresh coordination with deduplication & circuit breaking).
///
/// Strategy actors (PublicOAuthStrategy, CABOAuthStrategy) compose an
/// instance of this actor and delegate common work to it while keeping
/// strategy-specific token exchange / refresh logic in their own actors.
actor OAuthCore {
  // MARK: - Dependencies

  let storage: KeychainStorage
  let accountManager: AccountManaging
  let networkService: NetworkService
  let oauthConfig: OAuthConfig
  let didResolver: DIDResolving

  // MARK: - Shared State

  var refreshCoordinators: [String: TokenRefreshCoordinator] = [:]
  let refreshCircuitBreaker = RefreshCircuitBreaker()
  var noncesByThumbprint: [String: [String: String]] = [:]
  var usedRefreshTokens: Set<String> = []
  var activeRefreshTasks: [String: Task<TokenRefreshResult, Error>] = [:]
  var oauthFlowNonces: [String: String] = [:]
  var ambiguousRefreshUntil: [String: Date] = [:]
  var nextRefreshResourceOverride: String?

  /// Strategy-specific refresh implementation.
  /// Set by the owning strategy after init via `setPerformActualRefresh`.
  var performActualRefresh: (@Sendable (Account, Session) async throws -> TokenRefreshResult)?

  func setPerformActualRefresh(_ closure: @escaping @Sendable (Account, Session) async throws -> TokenRefreshResult) {
    self.performActualRefresh = closure
  }

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

  // MARK: - PKCE Helpers

  func generateCodeVerifier() -> String {
    let data = Data((0 ..< 32).map { _ in UInt8.random(in: 0 ... 255) })
    return base64URLEncode(data)
  }

  func generateCodeChallenge(from verifier: String) -> String {
    let data = Data(verifier.utf8)
    let hash = SHA256.hash(data: data)
    return base64URLEncode(Data(hash))
  }

  // MARK: - Encoding Helpers

  func base64URLEncode(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  func encodeFormData(_ params: [String: String]) -> Data {
    let queryItems = params.map { key, value in
      let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
      let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
      return "\(escapedKey)=\(escapedValue)"
    }
    return queryItems.joined(separator: "&").data(using: .utf8) ?? Data()
  }

  // MARK: - URL Helpers

  func extractAuthorizationCode(from url: URL) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?
      .first(where: { $0.name == "code" })?
      .value
  }

  func extractState(from url: URL) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?
      .first(where: { $0.name == "state" })?
      .value
  }

  func extractNonceFromHeaders(_ headers: [AnyHashable: Any]) -> String? {
    for (key, value) in headers {
      if let keyString = key as? String,
         keyString.caseInsensitiveCompare("DPoP-Nonce") == .orderedSame
      {
        return value as? String
      }
    }
    return nil
  }

  func canonicalHTU(_ url: URL) -> String {
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

  func calculateATH(from token: String) -> String {
    let tokenData = Data(token.utf8)
    let hash = SHA256.hash(data: tokenData)
    return base64URLEncode(Data(hash))
  }

  // MARK: - JWK & Crypto Helpers

  func createJWK(from privateKey: P256.Signing.PrivateKey) throws -> JWK {
    let publicKey = privateKey.publicKey
    let x = publicKey.x963Representation.dropFirst().prefix(32)
    let y = publicKey.x963Representation.suffix(32)
    return JWK(keyType: .ellipticCurve, curve: .p256, x: x, y: y)
  }

  func calculateJWKThumbprint(jwk: JWK) throws -> String {
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

  // MARK: - DPoP Proof Creation

  func createDPoPProof(
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

  func getOrCreateDPoPKey(for did: String) async throws -> P256.Signing.PrivateKey {
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

  func updateDPoPNonceInternal(domain: String, nonce: String, for did: String) async {
    do {
      var nonces = try await storage.getDPoPNonces(for: did) ?? [:]
      nonces[domain] = nonce
      try await storage.saveDPoPNonces(nonces, for: did)
    } catch {}
  }

  // MARK: - Metadata Fetching

  func resolveAuthServer(for pdsURL: URL) async throws -> URL {
    do {
      let metadata = try await fetchProtectedResourceMetadata(pdsURL: pdsURL)
      if let server = metadata.authorizationServers.first { return server }
    } catch {}
    return pdsURL
  }

  func fetchProtectedResourceMetadata(pdsURL: URL) async throws -> ProtectedResourceMetadata {
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

  func fetchAuthorizationServerMetadata(authServerURL: URL) async throws -> AuthorizationServerMetadata {
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

  func pushAuthorizationRequest(
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

  func revokeToken(refreshToken: String, endpoint: String, did: String) async {
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

  // MARK: - AuthenticationProvider Methods

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

  // MARK: - Refresh Coordination

  func tokensExist() async -> Bool {
    guard let did = await accountManager.getCurrentAccount()?.did else { return false }
    return (try? await storage.getSession(for: did)) != nil
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

    guard let performRefresh = performActualRefresh else {
      throw AuthError.tokenRefreshFailed
    }

    let task = Task<TokenRefreshResult, Error> {
      try await performRefresh(account, session)
    }
    activeRefreshTasks[did] = task
    defer { activeRefreshTasks.removeValue(forKey: did) }

    return try await task.value
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

struct OAuthErrorResponse: Decodable {
  let error: String
  let errorDescription: String?

  enum CodingKeys: String, CodingKey {
    case error
    case errorDescription = "error_description"
  }
}
