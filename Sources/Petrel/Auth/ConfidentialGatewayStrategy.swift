//
//  ConfidentialGatewayStrategy.swift
//  Petrel
//
//  Created by Josh LaCalamito on 1/19/26.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import Logging

private let logger = Logger(label: "blue.catbird.Petrel.ConfidentialGatewayStrategy")

/// Session information returned by the gateway's /auth/session endpoint.
public struct GatewaySessionInfo: Codable, Sendable {
    public let did: String
    public let handle: String?
    public let active: Bool?
    public let granted_scopes: [String]?
}

private struct UpgradeStartRequest: Codable, Sendable {
    let additional_scopes: [String]
    let browser_nonce: String
}

private struct UpgradeStartResponse: Codable, Sendable {
    let authorization_url: String
}

private struct UpgradeExchangeRequest: Codable, Sendable {
    let code: String
    let browser_nonce: String
}

private struct UpgradeExchangeResponse: Codable, Sendable {
    let candidate_session_id: String
    let did: String
    let granted_scopes: [String]
}

private struct UpgradeCommitResponse: Codable, Sendable {
    let status: String
    let session_id: String
    let did: String
    let granted_scopes: [String]

    private enum CodingKeys: String, CodingKey {
        case status
        case session_id
        case candidate_session_id
        case did
        case granted_scopes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        if let sid = try container.decodeIfPresent(String.self, forKey: .session_id) {
            session_id = sid
        } else if let csid = try container.decodeIfPresent(String.self, forKey: .candidate_session_id) {
            session_id = csid
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.session_id,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing session_id or candidate_session_id")
            )
        }
        did = try container.decode(String.self, forKey: .did)
        granted_scopes = try container.decode([String].self, forKey: .granted_scopes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encode(session_id, forKey: .session_id)
        try container.encode(did, forKey: .did)
        try container.encode(granted_scopes, forKey: .granted_scopes)
    }
}

private struct PendingGatewayUpgradeState: Codable, Sendable {
    let oldSession: String
    let expectedDID: String
    let requestedScopes: [String]
    let priorScopes: [String]
    let browserNonce: String
    let callbackURL: URL
    var candidateSession: String?
    var candidateGrantedScopes: [String]?
}

private struct GatewayErrorResponse: Decodable {
    let error: String?
    let message: String?
}

enum UnauthorizedDisposition {
    case terminal(reason: String)
    case transient(reason: String)
}

func classifyUnauthorizedGatewayResponse(_ data: Data) -> UnauthorizedDisposition {
    if data.isEmpty {
        return .transient(reason: "empty_body")
    }

    let responseBody = String(data: data, encoding: .utf8) ?? ""
    let bodyLower = responseBody.lowercased()

    if bodyLower.contains("invalid token audience") {
        return .transient(reason: "invalid_audience")
    }

    let payload = try? JSONCoders.decode(GatewayErrorResponse.self, from: data)
    let errorCode = (payload?.error ?? "").lowercased()
    let message = (payload?.message ?? responseBody).lowercased()

    let terminalCodes: Set = [
        "expiredtoken",
        "invalidtoken",
        "session_expired",
        "invalid_session",
        "token_refresh_failed",
    ]

    if terminalCodes.contains(errorCode) {
        return .terminal(reason: errorCode)
    }

    if errorCode == "authenticationrequired",
       message.contains("missing authentication session")
    {
        return .terminal(reason: "authentication_required_missing_session")
    }

    if message.contains("session expired")
        || message.contains("invalid session")
        || message.contains("please log in again")
        || message.contains("token refresh rejected")
    {
        return .terminal(reason: "message_indicates_expiry")
    }

    let transientCodes: Set = [
        "temporarilyunavailable",
        "use_dpop_nonce",
        "upstream_error",
    ]

    if transientCodes.contains(errorCode)
        || message.contains("temporarily unavailable")
        || message.contains("please retry")
        || message.contains("timeout")
    {
        return .transient(reason: errorCode.isEmpty ? "transient_message" : errorCode)
    }

    return .transient(reason: "unknown_401")
}

func isTerminalGatewayUnauthorized(data: Data, request: URLRequest, gatewayURL: URL) -> Bool {
    guard isRequestToGatewayOrigin(request, gatewayURL: gatewayURL) else { return false }
    if case .terminal = classifyUnauthorizedGatewayResponse(data) {
        return true
    }
    return false
}

private func isRequestToGatewayOrigin(_ request: URLRequest, gatewayURL: URL) -> Bool {
    guard let requestURL = request.url,
          requestURL.scheme?.lowercased() == gatewayURL.scheme?.lowercased(),
          requestURL.host?.lowercased() == gatewayURL.host?.lowercased()
    else {
        return false
    }

    return effectivePort(for: requestURL) == effectivePort(for: gatewayURL)
}

private func effectivePort(for url: URL) -> Int? {
    if let port = url.port {
        return port
    }
    switch url.scheme?.lowercased() {
    case "http":
        return 80
    case "https":
        return 443
    default:
        return nil
    }
}

/// Authentication strategy that delegates auth to a confidential gateway (Nest).
/// The gateway handles ATProto OAuth (PAR, PKCE, DPoP) and token management.
/// The client only stores a gateway session UUID and attaches it as a Bearer token.
actor ConfidentialGatewayStrategy: AuthStrategy {
    enum GatewayError: Error, LocalizedError {
        case missingSession
        case invalidCallbackURL
        case invalidGatewayURL
        case invalidSession
        case sessionExpired
        /// A 401 occurred from a non-gateway upstream while in gateway mode.
        /// This should not be treated as a gateway session expiration.
        case authenticationRequired
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .missingSession:
                return "No gateway session found. Please log in again."
            case .invalidCallbackURL:
                return "Invalid OAuth callback URL from gateway."
            case .invalidGatewayURL:
                return "Invalid gateway URL configuration."
            case .invalidSession:
                return "Gateway session is invalid."
            case .sessionExpired:
                return "Gateway session has expired. Please log in again."
            case .authenticationRequired:
                return "Authentication required."
            case let .networkError(error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }

    private let gatewayURL: URL
    private let storage: KeychainStorage
    private let accountManager: AccountManaging
    private let urlSession: URLSession

    private static let sessionKey = "gatewaySession"

    init(
        gatewayURL: URL,
        storage: KeychainStorage,
        accountManager: AccountManaging,
        urlSession: URLSession = .shared
    ) {
        self.gatewayURL = gatewayURL
        self.storage = storage
        self.accountManager = accountManager
        self.urlSession = urlSession
    }

    // MARK: - AuthStrategy

    func startOAuthFlow(
        identifier: String?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> URL {
        guard var components = URLComponents(url: gatewayURL, resolvingAgainstBaseURL: false) else {
            throw GatewayError.invalidGatewayURL
        }
        components.path = "/auth/login"
        if let identifier {
            components.queryItems = [URLQueryItem(name: "identifier", value: identifier)]
        }
        guard let url = components.url else {
            throw GatewayError.invalidGatewayURL
        }
        return url
    }

    func startOAuthFlowForSignUp(
        pdsURL: URL?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> URL {
        guard var components = URLComponents(url: gatewayURL, resolvingAgainstBaseURL: false) else {
            throw GatewayError.invalidGatewayURL
        }
        components.path = "/auth/login"
        if let pdsURL {
            components.queryItems = [URLQueryItem(name: "pds", value: pdsURL.absoluteString)]
        }
        guard let url = components.url else {
            throw GatewayError.invalidGatewayURL
        }
        return url
    }

    func handleOAuthCallback(url: URL) async throws -> (did: String, handle: String?, pdsURL: URL) {
        // Gateway sends session_id in URL fragment: catbird.blue/oauth/callback#session_id=<uuid>
        guard let fragment = url.fragment,
              let sessionId = parseSessionIdFromFragment(fragment)
        else {
            throw GatewayError.invalidCallbackURL
        }

        // Fetch session details from gateway to get DID and handle FIRST
        let sessionInfo = try await fetchSessionFromGateway(sessionId: sessionId)

        // Store the session ID keyed by DID (for multi-account support)
        try await saveGatewaySession(sessionId, for: sessionInfo.did)

        // Create and save an Account object so the AccountManager can track this user
        let account = Account(
            did: sessionInfo.did,
            handle: sessionInfo.handle,
            pdsURL: gatewayURL
        )
        LogManager.logInfo(
            "ConfidentialGatewayStrategy - Saving account for DID: \(sessionInfo.did), pdsURL: \(gatewayURL)"
        )
        try await storage.saveAccount(account, for: sessionInfo.did)

        // Update AccountManager with the new account and set it as current
        LogManager.logInfo(
            "ConfidentialGatewayStrategy - Setting current account to DID: \(sessionInfo.did)"
        )
        try await accountManager.updateAccountFromStorage(did: sessionInfo.did)
        try await accountManager.setCurrentAccount(did: sessionInfo.did)
        LogManager.logInfo(
            "ConfidentialGatewayStrategy - Account setup complete for DID: \(sessionInfo.did)"
        )

        return (did: sessionInfo.did, handle: sessionInfo.handle, pdsURL: gatewayURL)
    }

    func loginWithPassword(
        identifier: String,
        password: String,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> (did: String, handle: String?, pdsURL: URL) {
        // Gateway doesn't support password-based login directly
        throw AuthError.invalidOAuthConfiguration
    }

    func logout() async throws {
        logger.info("🚪 Gateway logout initiated")

        // Get the current account's DID for per-account session management
        guard let currentAccount = await accountManager.getCurrentAccount() else {
            logger.warning("🚪 No current account set, nothing to logout")
            return
        }
        let did = currentAccount.did

        // Best-effort call to gateway to invalidate session server-side
        if let session = try? await storage.getGatewaySession(for: did) {
            let logoutURL = gatewayURL.appendingPathComponent("auth/logout")
            logger.info(
                "🚪 Calling gateway logout for DID \(did.prefix(20))...: \(logoutURL.absoluteString)"
            )

            var request = URLRequest(url: logoutURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                let (data, response) = try await urlSession.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    logger.info("🚪 Gateway logout response: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        let body = String(data: data, encoding: .utf8) ?? "no body"
                        logger.warning("🚪 Gateway logout non-200: \(body)")
                    }
                }
            } catch {
                // Don't fail logout if gateway is unreachable
                logger.warning(
                    "🚪 Gateway logout request failed (continuing anyway): \(error.localizedDescription)"
                )
            }
        } else {
            logger.info(
                "🚪 No gateway session found for DID \(did.prefix(20))..., skipping gateway logout call"
            )
        }

        // Always clear local session for this account
        logger.info("🚪 Clearing local gateway session for DID \(did.prefix(20))...")
        try await storage.deleteGatewaySession(for: did)
        await accountManager.clearCurrentAccount()
        logger.info("🚪 Gateway logout complete")
    }

    func cancelOAuthFlow() async {}

    func tokensExist() async -> Bool {
        guard let currentAccount = await accountManager.getCurrentAccount() else {
            return false
        }
        return (try? await storage.getGatewaySession(for: currentAccount.did)) != nil
    }

    func setProgressDelegate(_ delegate: AuthProgressDelegate?) async {}

    func setFailureDelegate(_ delegate: AuthFailureDelegate?) async {}

    func attemptRecoveryFromServerFailures(for did: String?) async throws {}

    // MARK: - Gateway Scope Upgrade

    func startGatewayScopeUpgrade(
        requesting: Set<String>,
        for expectedDID: String,
        callbackURL: URL
    ) async throws -> URL {
        // Validate scopes
        guard !requesting.isEmpty, requesting.count <= 16 else {
            throw AuthError.invalidOAuthConfiguration
        }
        for scope in requesting {
            guard !scope.isEmpty, scope.count <= 128 else {
                throw AuthError.invalidOAuthConfiguration
            }
            guard !scope.contains(where: \.isWhitespace) else {
                throw AuthError.invalidOAuthConfiguration
            }
            guard !scope.contains("*") else {
                throw AuthError.invalidOAuthConfiguration
            }
        }

        // Validate expected DID and active account
        guard let oldSession = try await storage.getGatewaySession(for: expectedDID), !oldSession.isEmpty else {
            throw AuthError.invalidCredentials
        }
        if let currentAccount = await accountManager.getCurrentAccount(), currentAccount.did != expectedDID {
            throw AuthError.invalidCredentials
        }

        // Validate callback URL client-side binding
        try validateStartCallbackURL(callbackURL)

        // Generate 32 cryptographically random bytes -> 43-char base64url unpadded nonce
        var rng = SystemRandomNumberGenerator()
        var nonceBytes = [UInt8](repeating: 0, count: 32)
        for i in 0..<32 {
            nonceBytes[i] = rng.next()
        }
        let browserNonce = JWTBase64URL.encode(Data(nonceBytes))

        let sortedScopes = requesting.sorted()

        // Fetch prior scopes if available
        var priorScopes: [String] = []
        if let currentSessionInfo = try? await fetchSessionFromGateway(sessionId: oldSession),
           let granted = currentSessionInfo.granted_scopes {
            priorScopes = granted
        }

        // Send POST /auth/upgrade
        var request = URLRequest(url: gatewayURL.appendingPathComponent("auth/upgrade"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(oldSession)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let startReqBody = UpgradeStartRequest(additional_scopes: sortedScopes, browser_nonce: browserNonce)
        request.httpBody = try JSONCoders.encode(startReqBody)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw GatewayError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GatewayError.invalidSession
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw GatewayError.sessionExpired
            }
            throw GatewayError.invalidSession
        }

        let startResponse = try JSONCoders.decode(UpgradeStartResponse.self, from: data)
        guard let authURL = URL(string: startResponse.authorization_url) else {
            throw GatewayError.invalidGatewayURL
        }

        // Durably store pending upgrade state
        let pendingState = PendingGatewayUpgradeState(
            oldSession: oldSession,
            expectedDID: expectedDID,
            requestedScopes: sortedScopes,
            priorScopes: priorScopes,
            browserNonce: browserNonce,
            callbackURL: callbackURL,
            candidateSession: nil,
            candidateGrantedScopes: nil
        )
        let stateData = try JSONCoders.encode(pendingState)
        try await storage.savePendingGatewayUpgradeData(stateData, for: expectedDID)

        return authURL
    }

    func completeGatewayScopeUpgrade(
        callbackURL: URL,
        for expectedDID: String
    ) async throws -> Set<String> {
        guard let pendingData = try await storage.getPendingGatewayUpgradeData(for: expectedDID),
              var pendingState = try? JSONCoders.decode(PendingGatewayUpgradeState.self, from: pendingData)
        else {
            throw GatewayError.invalidSession
        }

        // Crash recovery: check if candidate was already promoted before crash
        if let candidateSession = pendingState.candidateSession,
           let currentSession = try? await storage.getGatewaySession(for: expectedDID),
           currentSession == candidateSession {
            try? await storage.deletePendingGatewayUpgradeData(for: expectedDID)
            return Set(pendingState.candidateGrantedScopes ?? [])
        }

        // Validate callback base URL
        guard isMatchingCallbackBase(candidate: callbackURL, baseline: pendingState.callbackURL) else {
            throw AuthError.invalidCallbackURL
        }

        // Parse query items
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw AuthError.invalidCallbackURL
        }

        if let queryItems = components.queryItems {
            if queryItems.contains(where: { $0.name == "error" }) {
                try? await storage.deletePendingGatewayUpgradeData(for: expectedDID)
                throw AuthError.cancelled
            }
        }

        let codeItems = components.queryItems?.filter { $0.name == "code" } ?? []
        guard codeItems.count == 1,
              let code = codeItems.first?.value,
              !code.isEmpty,
              code.count <= 512
        else {
            throw AuthError.invalidCallbackURL
        }

        // 1. Exchange for candidate if not yet present
        let candidateSession: String
        let candidateGrants: [String]

        if let existingCandidate = pendingState.candidateSession,
           let existingGrants = pendingState.candidateGrantedScopes {
            candidateSession = existingCandidate
            candidateGrants = existingGrants
        } else {
            var exchangeReq = URLRequest(url: gatewayURL.appendingPathComponent("auth/upgrade/exchange"))
            exchangeReq.httpMethod = "POST"
            exchangeReq.setValue("Bearer \(pendingState.oldSession)", forHTTPHeaderField: "Authorization")
            exchangeReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            exchangeReq.setValue("application/json", forHTTPHeaderField: "Accept")
            exchangeReq.setValue(gatewayOriginHeader(), forHTTPHeaderField: "Origin")

            let exchangeBody = UpgradeExchangeRequest(code: code, browser_nonce: pendingState.browserNonce)
            exchangeReq.httpBody = try JSONCoders.encode(exchangeBody)

            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await urlSession.data(for: exchangeReq)
            } catch {
                throw GatewayError.networkError(error)
            }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw GatewayError.invalidSession
            }
            let exchangeResp = try JSONCoders.decode(UpgradeExchangeResponse.self, from: data)

            // Validate candidate
            guard exchangeResp.did == expectedDID,
                  !exchangeResp.candidate_session_id.isEmpty,
                  exchangeResp.candidate_session_id != pendingState.oldSession
            else {
                throw GatewayError.invalidSession
            }

            let grantSet = Set(exchangeResp.granted_scopes)
            guard grantSet.contains("atproto"),
                  Set(pendingState.requestedScopes).isSubset(of: grantSet),
                  Set(pendingState.priorScopes).isSubset(of: grantSet)
            else {
                throw GatewayError.invalidSession
            }

            candidateSession = exchangeResp.candidate_session_id
            candidateGrants = exchangeResp.granted_scopes

            // Durably store candidate BEFORE commit
            pendingState.candidateSession = candidateSession
            pendingState.candidateGrantedScopes = candidateGrants
            let updatedData = try JSONCoders.encode(pendingState)
            try await storage.savePendingGatewayUpgradeData(updatedData, for: expectedDID)
        }

        // 2. Commit candidate
        var commitReq = URLRequest(url: gatewayURL.appendingPathComponent("auth/upgrade/commit"))
        commitReq.httpMethod = "POST"
        commitReq.setValue("Bearer \(candidateSession)", forHTTPHeaderField: "Authorization")
        commitReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        commitReq.setValue("application/json", forHTTPHeaderField: "Accept")
        commitReq.httpBody = Data("{}".utf8)

        let (commitData, commitResponse): (Data, URLResponse)
        do {
            (commitData, commitResponse) = try await urlSession.data(for: commitReq)
        } catch {
            throw GatewayError.networkError(error)
        }
        guard let httpCommitResp = commitResponse as? HTTPURLResponse, httpCommitResp.statusCode == 200 else {
            throw GatewayError.invalidSession
        }
        let commitResp = try JSONCoders.decode(UpgradeCommitResponse.self, from: commitData)

        guard commitResp.status.lowercased() == "committed",
              commitResp.session_id == candidateSession,
              commitResp.did == expectedDID
        else {
            throw GatewayError.invalidSession
        }
        let finalGrants = Set(commitResp.granted_scopes)
        guard finalGrants.contains("atproto"),
              Set(pendingState.requestedScopes).isSubset(of: finalGrants)
        else {
            throw GatewayError.invalidSession
        }

        // 3. CAS Promotion
        let casSuccess = try await storage.compareAndSwapGatewaySession(
            expectedOldSession: pendingState.oldSession,
            newSession: candidateSession,
            for: expectedDID
        )
        guard casSuccess else {
            throw GatewayError.invalidSession
        }

        // 4. Cleanup
        try await storage.deletePendingGatewayUpgradeData(for: expectedDID)

        return finalGrants
    }

    func fetchGrantedScopes(for did: String?) async throws -> Set<String> {
        let targetDID: String
        if let did, !did.isEmpty {
            targetDID = did
        } else if let currentAccount = await accountManager.getCurrentAccount() {
            targetDID = currentAccount.did
        } else {
            throw AuthError.noActiveAccount
        }

        guard let session = try await storage.getGatewaySession(for: targetDID), !session.isEmpty else {
            throw GatewayError.missingSession
        }

        let sessionInfo = try await fetchSessionFromGateway(sessionId: session)

        guard sessionInfo.did == targetDID else {
            throw GatewayError.invalidSession
        }
        if let active = sessionInfo.active {
            guard active else {
                throw GatewayError.invalidSession
            }
        }
        guard let grantedScopes = sessionInfo.granted_scopes, !grantedScopes.isEmpty else {
            throw GatewayError.invalidSession
        }
        let scopeSet = Set(grantedScopes)
        guard scopeSet.contains("atproto") else {
            throw GatewayError.invalidSession
        }

        return scopeSet
    }

    private func gatewayOriginHeader() -> String {
        let scheme = gatewayURL.scheme ?? "https"
        let host = gatewayURL.host ?? ""
        if let port = gatewayURL.port, port != 80 && port != 443 {
            return "\(scheme)://\(host):\(port)"
        }
        return "\(scheme)://\(host)"
    }

    private func isMatchingCallbackBase(candidate: URL, baseline: URL) -> Bool {
        guard candidate.scheme?.lowercased() == baseline.scheme?.lowercased(),
              candidate.host?.lowercased() == baseline.host?.lowercased(),
              effectivePort(for: candidate) == effectivePort(for: baseline)
        else {
            return false
        }
        let candidatePath = candidate.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let baselinePath = baseline.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return candidatePath == baselinePath
    }

    private func validateStartCallbackURL(_ url: URL) throws {
        guard let scheme = url.scheme?.lowercased() else {
            throw AuthError.invalidCallbackURL
        }
        let host = url.host?.lowercased() ?? ""
        guard !host.isEmpty else {
            throw AuthError.invalidCallbackURL
        }
        let isLoopback = host == "127.0.0.1" || host == "localhost" || host == "::1"
        guard scheme == "https" || (scheme == "http" && isLoopback) else {
            throw AuthError.invalidCallbackURL
        }
        guard url.user == nil && url.password == nil else {
            throw AuthError.invalidCallbackURL
        }
        guard url.query == nil && url.fragment == nil else {
            throw AuthError.invalidCallbackURL
        }
    }

    // MARK: - AuthenticationProvider

    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        let session = try await gatewaySession()
        LogManager.logInfo(
            "ConfidentialGatewayStrategy - Adding Bearer token to request: \(request.url?.absoluteString ?? "unknown")"
        )
        request.setValue("Bearer \(session)", forHTTPHeaderField: "Authorization")
        return request
    }

    func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (
        URLRequest, AuthContext
    ) {
        let authed = try await prepareAuthenticatedRequest(request)
        // For gateway auth, we don't have DID/JKT at request time - gateway handles it
        return (authed, AuthContext(did: nil, jkt: nil))
    }

    func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
        // Gateway manages token refresh automatically - client session is long-lived
        // But we need to verify the session actually exists for the current account
        guard let currentAccount = await accountManager.getCurrentAccount() else {
            logger.warning("refreshTokenIfNeeded: No current account set")
            throw GatewayError.missingSession
        }
        guard (try? await storage.getGatewaySession(for: currentAccount.did)) != nil else {
            logger.warning(
                "refreshTokenIfNeeded: No gateway session found for DID: \(currentAccount.did.prefix(20))..."
            )
            throw GatewayError.missingSession
        }
        return .stillValid
    }

    func handleUnauthorizedResponse(
        _ response: HTTPURLResponse, data: Data, for request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        // Only clear session if the 401 came from our gateway
        // 401s from other services (MLS, Bluesky API) shouldn't invalidate gateway session
        if isRequestToGatewayOrigin(request, gatewayURL: gatewayURL) {
            switch classifyUnauthorizedGatewayResponse(data) {
            case let .terminal(reason):
                logger.warning(
                    "Gateway returned terminal auth error (reason: \(reason)) - clearing local session"
                )
                await clearCurrentGatewaySession()
                throw GatewayError.sessionExpired

            case let .transient(reason):
                let bodyPreview = String((String(data: data, encoding: .utf8) ?? "").prefix(200))

                // A 401 on a proxied request was produced by the upstream service the
                // gateway forwarded to, not by the gateway session — which this branch
                // has just established is still valid. Collapsing it into
                // `authenticationRequired` discards the response body, so the caller is
                // told "log in again" instead of seeing its own protocol error. That
                // breaks the MLS device lifecycle outright: `DeviceNotRegistered` is
                // defined to start automatic enrollment, and logging in again never
                // enrolls a device, so the account cannot recover. Hand the response
                // back and let the caller decode it.
                //
                // This is the case the non-gateway branch below intends to cover; it is
                // unreachable for proxied traffic, which shares the gateway's origin.
                if request.value(forHTTPHeaderField: "atproto-proxy") != nil {
                    logger.warning(
                        "Upstream 401 on proxied request (reason: \(reason)) - returning body to caller. Body: \(bodyPreview)"
                    )
                    return (data, response)
                }

                logger.warning(
                    "Gateway returned transient 401 (reason: \(reason)) - preserving session. Body: \(bodyPreview)"
                )
                throw GatewayError.authenticationRequired
            }
        }

        // For non-gateway 401s, do NOT treat this as gateway session expiration.
        // Upstream services (e.g. MLS, bsky.chat) can return 401 for reasons unrelated
        // to the gateway session.
        logger.info(
            "Received 401 from non-gateway service: \(request.url?.absoluteString ?? "unknown")"
        )
        throw GatewayError.authenticationRequired
    }

    func updateDPoPNonce(for url: URL, from headers: [String: String], did: String?, jkt: String?)
        async
    {
        // Gateway handles DPoP nonces - client doesn't need to track them
    }

    // MARK: - Private Helpers

    private func clearCurrentGatewaySession() async {
        guard let currentAccount = await accountManager.getCurrentAccount() else {
            logger.warning("No current account available while clearing gateway session")
            return
        }

        do {
            try await storage.deleteGatewaySession(for: currentAccount.did)
        } catch {
            logger.error(
                "Failed to delete gateway session during 401 handling: \(error)"
            )
        }
    }

    /// Gets the gateway session for the current account
    private func gatewaySession() async throws -> String {
        // Get the current account's DID
        guard let currentAccount = await accountManager.getCurrentAccount() else {
            LogManager.logError("ConfidentialGatewayStrategy - No current account set!")
            throw GatewayError.missingSession
        }

        guard let session = try await storage.getGatewaySession(for: currentAccount.did) else {
            LogManager.logError(
                "ConfidentialGatewayStrategy - No gateway session found for DID: \(currentAccount.did.prefix(20))..."
            )
            throw GatewayError.missingSession
        }
        LogManager.logDebug(
            "ConfidentialGatewayStrategy - Found gateway session for \(currentAccount.did.prefix(20))...: \(session.prefix(8))..."
        )
        return session
    }

    private func saveGatewaySession(_ session: String, for did: String) async throws {
        try await storage.saveGatewaySession(session, for: did)
    }

    /// Parse session_id from URL fragment (e.g., "session_id=abc123&foo=bar")
    private func parseSessionIdFromFragment(_ fragment: String) -> String? {
        let pairs = fragment.split(separator: "&").map { $0.split(separator: "=", maxSplits: 1) }
        for pair in pairs where pair.count == 2 && pair[0] == "session_id" {
            return String(pair[1])
        }
        return nil
    }

    /// Fetch session details from gateway's /auth/session endpoint
    private func fetchSessionFromGateway(sessionId: String) async throws -> GatewaySessionInfo {
        var request = URLRequest(url: gatewayURL.appendingPathComponent("auth/session"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(sessionId)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw GatewayError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GatewayError.invalidSession
        }

        switch httpResponse.statusCode {
        case 200:
            do {
                return try JSONCoders.decode(GatewaySessionInfo.self, from: data)
            } catch {
                throw GatewayError.invalidSession
            }
        case 401:
            throw GatewayError.sessionExpired
        default:
            throw GatewayError.invalidSession
        }
    }
}
