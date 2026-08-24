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

    public init(
        did: String,
        handle: String? = nil,
        active: Bool? = nil,
        granted_scopes: [String]? = nil
    ) {
        self.did = did
        self.handle = handle
        self.active = active
        self.granted_scopes = granted_scopes
    }
}

private struct StrictAnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private struct UpgradeStartRequest: Encodable, Sendable {
    let additional_scopes: [String]
    let browser_nonce: String
}

private struct UpgradeStartResponse: Decodable, Sendable {
    let authorization_url: String

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case authorization_url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StrictAnyCodingKey.self)
        let allowed = Set(CodingKeys.allCases.map(\.rawValue))
        let present = Set(container.allKeys.map(\.stringValue))
        guard present.isSubset(of: allowed) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown keys in UpgradeStartResponse: \(present.subtracting(allowed))")
            )
        }
        guard let key = StrictAnyCodingKey(stringValue: "authorization_url") else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing key authorization_url"))
        }
        authorization_url = try container.decode(String.self, forKey: key)
    }
}

private struct UpgradeExchangeRequest: Encodable, Sendable {
    let code: String
    let browser_nonce: String
}

private struct UpgradeExchangeResponse: Decodable, Sendable {
    let candidate_session_id: String
    let did: String
    let granted_scopes: [String]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case candidate_session_id
        case did
        case granted_scopes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StrictAnyCodingKey.self)
        let allowed = Set(CodingKeys.allCases.map(\.rawValue))
        let present = Set(container.allKeys.map(\.stringValue))
        guard present.isSubset(of: allowed) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown keys in UpgradeExchangeResponse: \(present.subtracting(allowed))")
            )
        }
        guard let csidKey = StrictAnyCodingKey(stringValue: "candidate_session_id"),
              let didKey = StrictAnyCodingKey(stringValue: "did"),
              let scopesKey = StrictAnyCodingKey(stringValue: "granted_scopes")
        else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid keys"))
        }
        let rawCSID = try container.decode(String.self, forKey: csidKey)
        guard let uuid = UUID(uuidString: rawCSID) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [csidKey], debugDescription: "candidate_session_id is not a valid UUID: \(rawCSID)")
            )
        }
        candidate_session_id = uuid.uuidString.lowercased()
        did = try container.decode(String.self, forKey: didKey)
        granted_scopes = try container.decode([String].self, forKey: scopesKey)
    }
}

private enum CommitStatus: String, Decodable, Sendable {
    case committed
}

private struct UpgradeCommitResponse: Decodable, Sendable {
    let status: CommitStatus
    let session_id: String
    let did: String
    let granted_scopes: [String]

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case status
        case session_id
        case did
        case granted_scopes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StrictAnyCodingKey.self)
        let allowed = Set(CodingKeys.allCases.map(\.rawValue))
        let present = Set(container.allKeys.map(\.stringValue))
        guard present.isSubset(of: allowed) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown keys in UpgradeCommitResponse: \(present.subtracting(allowed))")
            )
        }
        guard let statusKey = StrictAnyCodingKey(stringValue: "status"),
              let sidKey = StrictAnyCodingKey(stringValue: "session_id"),
              let didKey = StrictAnyCodingKey(stringValue: "did"),
              let scopesKey = StrictAnyCodingKey(stringValue: "granted_scopes")
        else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid keys"))
        }
        status = try container.decode(CommitStatus.self, forKey: statusKey)
        let rawSID = try container.decode(String.self, forKey: sidKey)
        guard let uuid = UUID(uuidString: rawSID) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [sidKey], debugDescription: "session_id is not a valid UUID: \(rawSID)")
            )
        }
        session_id = uuid.uuidString.lowercased()
        did = try container.decode(String.self, forKey: didKey)
        granted_scopes = try container.decode([String].self, forKey: scopesKey)
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
    public static let permissionCallbackURL = URL(string: "https://catbird.blue/oauth/permission-callback")!
    public static let permissionCallbackOrigin = "https://catbird.blue"
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
        guard sessionInfo.active != false else {
            throw GatewayError.invalidSession
        }

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

    func attemptRecoveryFromServerFailures(for did: String?) async throws {
        let targetDID: String
        if let did, !did.isEmpty {
            targetDID = did
        } else if let currentAccount = await accountManager.getCurrentAccount() {
            targetDID = currentAccount.did
        } else {
            return
        }

        guard let recovery = try await recoverablePendingCandidate(for: targetDID) else {
            return
        }
        // A durable candidate makes recovery mandatory; never authorize the old anchor.
        guard let currentAccount = await accountManager.getCurrentAccount(), currentAccount.did == targetDID else {
            throw AuthError.invalidCredentials
        }
        guard let keychainCurrentDID = try await storage.getCurrentDID(), keychainCurrentDID == targetDID else {
            throw AuthError.invalidCredentials
        }
        let (pendingState, candidateSession, candidateGrants) = recovery
        guard let currentSession = try await storage.getGatewaySession(for: targetDID), !currentSession.isEmpty else {
            throw GatewayError.missingSession
        }

        if currentSession == candidateSession {
            try await storage.deletePendingGatewayUpgradeData(for: targetDID)
            return
        }

        guard currentSession == pendingState.oldSession else {
            throw GatewayError.invalidSession
        }

        // Retry candidate commit + CAS + cleanup.
        _ = try await commitAndPromoteCandidate(
            pendingState: pendingState,
            candidateSession: candidateSession,
            candidateGrants: candidateGrants,
            for: targetDID
        )
    }

    private func recoverablePendingCandidate(
        for did: String
    ) async throws -> (PendingGatewayUpgradeState, String, [String])? {
        guard let pendingData = try await storage.getPendingGatewayUpgradeData(for: did) else {
            return nil
        }
        let pendingState = try JSONCoders.decode(PendingGatewayUpgradeState.self, from: pendingData)
        guard pendingState.expectedDID == did,
              let candidateSession = pendingState.candidateSession,
              let candidateGrants = pendingState.candidateGrantedScopes,
              !candidateSession.isEmpty
        else {
            return nil
        }
        return (pendingState, candidateSession, candidateGrants)
    }

    // MARK: - Gateway Scope Upgrade

    func startGatewayScopeUpgrade(
        requesting: Set<String>,
        for expectedDID: String,
        callbackURL: URL = ConfidentialGatewayStrategy.permissionCallbackURL
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

        // Validate active identity strictly
        guard !expectedDID.isEmpty else {
            throw AuthError.invalidCredentials
        }
        guard let currentAccount = await accountManager.getCurrentAccount(), currentAccount.did == expectedDID else {
            throw AuthError.invalidCredentials
        }
        guard let keychainCurrentDID = try await storage.getCurrentDID(), keychainCurrentDID == expectedDID else {
            throw AuthError.invalidCredentials
        }
        guard let oldSession = try await storage.getGatewaySession(for: expectedDID), !oldSession.isEmpty else {
            throw AuthError.invalidCredentials
        }
        guard UUID(uuidString: oldSession) != nil else {
            throw AuthError.invalidCredentials
        }

        // Validate exact callback URL
        guard Self.isExactPermissionCallbackBase(callbackURL),
              URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.query == nil
        else {
            throw AuthError.invalidCallbackURL
        }

        // Authoritatively fetch prior session info (throwing, no try?)
        let currentSessionInfo = try await fetchSessionFromGateway(sessionId: oldSession)
        guard currentSessionInfo.active != false else {
            throw GatewayError.invalidSession
        }
        guard currentSessionInfo.did == expectedDID else {
            throw GatewayError.invalidSession
        }
        guard let granted = currentSessionInfo.granted_scopes, !granted.isEmpty else {
            throw GatewayError.invalidSession
        }
        let priorScopeSet = Set(granted)
        guard priorScopeSet.contains("atproto") else {
            throw GatewayError.invalidSession
        }
        let priorScopes = granted.sorted()

        // Generate 32 cryptographically random bytes -> 43-char base64url unpadded nonce
        var rng = SystemRandomNumberGenerator()
        var nonceBytes = [UInt8](repeating: 0, count: 32)
        for i in 0..<32 {
            nonceBytes[i] = rng.next()
        }
        let browserNonce = JWTBase64URL.encode(Data(nonceBytes))

        let sortedScopes = requesting.sorted()

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

    private func commitAndPromoteCandidate(
        pendingState: PendingGatewayUpgradeState,
        candidateSession: String,
        candidateGrants: [String],
        for expectedDID: String
    ) async throws -> Set<String> {
        let requiredScopes = Set(pendingState.priorScopes).union(Set(pendingState.requestedScopes))

        // 1. Commit candidate
        var commitReq = URLRequest(url: gatewayURL.appendingPathComponent("auth/upgrade/commit"))
        commitReq.httpMethod = "POST"
        commitReq.setValue("Bearer \(candidateSession)", forHTTPHeaderField: "Authorization")
        commitReq.setValue("application/json", forHTTPHeaderField: "Accept")
        commitReq.httpBody = nil

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

        guard commitResp.status == .committed,
              commitResp.session_id == candidateSession,
              commitResp.did == expectedDID
        else {
            throw GatewayError.invalidSession
        }
        let finalGrants = Set(commitResp.granted_scopes)
        guard finalGrants.contains("atproto"),
              requiredScopes.isSubset(of: finalGrants)
        else {
            throw GatewayError.invalidSession
        }

        // 2. CAS Promotion
        let casSuccess = try await storage.compareAndSwapGatewaySession(
            expectedOldSession: pendingState.oldSession,
            newSession: candidateSession,
            for: expectedDID
        )
        guard casSuccess else {
            throw GatewayError.invalidSession
        }

        // 3. Cleanup
        try await storage.deletePendingGatewayUpgradeData(for: expectedDID)

        return finalGrants
    }

    func completeGatewayScopeUpgrade(
        callbackURL: URL,
        for expectedDID: String
    ) async throws -> Set<String> {
        // Validate active identity strictly
        guard !expectedDID.isEmpty else {
            throw AuthError.invalidCredentials
        }
        guard let currentAccount = await accountManager.getCurrentAccount(), currentAccount.did == expectedDID else {
            throw AuthError.invalidCredentials
        }
        guard let keychainCurrentDID = try await storage.getCurrentDID(), keychainCurrentDID == expectedDID else {
            throw AuthError.invalidCredentials
        }
        guard let pendingData = try await storage.getPendingGatewayUpgradeData(for: expectedDID),
              var pendingState = try? JSONCoders.decode(PendingGatewayUpgradeState.self, from: pendingData)
        else {
            throw GatewayError.invalidSession
        }

        guard pendingState.expectedDID == expectedDID else {
            throw AuthError.invalidCredentials
        }
        guard Self.isExactPermissionCallbackBase(pendingState.callbackURL) else {
            throw AuthError.invalidCallbackURL
        }

        guard let currentSession = try await storage.getGatewaySession(for: expectedDID), !currentSession.isEmpty else {
            throw AuthError.invalidCredentials
        }

        if let candidateSession = pendingState.candidateSession,
           currentSession == candidateSession {
            try await storage.deletePendingGatewayUpgradeData(for: expectedDID)
            return Set(pendingState.candidateGrantedScopes ?? [])
        }

        // If current is any third session, fail before network
        guard currentSession == pendingState.oldSession else {
            throw GatewayError.invalidSession
        }

        // If candidate already persisted, skip callback/code parsing and commit/promote directly
        if let candidateSession = pendingState.candidateSession,
           let candidateGrants = pendingState.candidateGrantedScopes {
            return try await commitAndPromoteCandidate(
                pendingState: pendingState,
                candidateSession: candidateSession,
                candidateGrants: candidateGrants,
                for: expectedDID
            )
        }

        // Validate callback base URL
        guard Self.isExactPermissionCallbackBase(callbackURL) else {
            throw AuthError.invalidCallbackURL
        }

        // Parse query items
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw AuthError.invalidCallbackURL
        }

        let queryItems = components.queryItems ?? []
        if queryItems.isEmpty {
            throw AuthError.invalidCallbackURL
        }

        if queryItems.contains(where: { $0.name == "error" }) {
            throw AuthError.cancelled
        }

        let codeItems = queryItems.filter { $0.name == "code" }
        // /auth/upgrade/exchange retries require Nest to return a short-lived,
        // idempotent receipt keyed by old bearer + code + nonce.
        guard codeItems.count == 1,
              let code = codeItems.first?.value,
              !code.isEmpty,
              code.count <= 512,
              queryItems.count == 1
        else {
            throw AuthError.invalidCallbackURL
        }

        let requiredScopes = Set(pendingState.priorScopes).union(Set(pendingState.requestedScopes))

        // Exchange for candidate
        var exchangeReq = URLRequest(url: gatewayURL.appendingPathComponent("auth/upgrade/exchange"))
        exchangeReq.httpMethod = "POST"
        exchangeReq.setValue("Bearer \(pendingState.oldSession)", forHTTPHeaderField: "Authorization")
        exchangeReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        exchangeReq.setValue("application/json", forHTTPHeaderField: "Accept")
        exchangeReq.setValue(Self.permissionCallbackOrigin, forHTTPHeaderField: "Origin")

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
              requiredScopes.isSubset(of: grantSet)
        else {
            throw GatewayError.invalidSession
        }

        let candidateSession = exchangeResp.candidate_session_id
        let candidateGrants = exchangeResp.granted_scopes

        // Durably store candidate BEFORE commit
        pendingState.candidateSession = candidateSession
        pendingState.candidateGrantedScopes = candidateGrants
        let updatedData = try JSONCoders.encode(pendingState)
        try await storage.savePendingGatewayUpgradeData(updatedData, for: expectedDID)

        return try await commitAndPromoteCandidate(
            pendingState: pendingState,
            candidateSession: candidateSession,
            candidateGrants: candidateGrants,
            for: expectedDID
        )
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
        guard sessionInfo.active != false else {
            throw GatewayError.invalidSession
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

    private static func isExactPermissionCallbackBase(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        guard components.scheme?.lowercased() == "https" else { return false }
        guard components.host?.lowercased() == "catbird.blue" else { return false }
        guard components.path == "/oauth/permission-callback" else { return false }
        guard components.user == nil && components.password == nil else { return false }
        if let port = components.port, port != 443 { return false }
        guard components.fragment == nil else { return false }
        return true
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
        guard let currentAccount = await accountManager.getCurrentAccount() else {
            logger.warning("refreshTokenIfNeeded: No current account set")
            throw GatewayError.missingSession
        }

        if let recovery = try await recoverablePendingCandidate(for: currentAccount.did) {
            let candidateSession = recovery.1
            try await attemptRecoveryFromServerFailures(for: currentAccount.did)
            guard let session = try await storage.getGatewaySession(for: currentAccount.did),
                  session == candidateSession
            else {
                throw GatewayError.invalidSession
            }
            return .stillValid
        }

        guard let session = try await storage.getGatewaySession(for: currentAccount.did),
              !session.isEmpty
        else {
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
                if let account = await accountManager.getCurrentAccount(),
                   let recovery = try await recoverablePendingCandidate(for: account.did)
                {
                    // A recoverable candidate owns the old anchor until CAS succeeds.
                    try await attemptRecoveryFromServerFailures(for: account.did)
                    guard let session = try await storage.getGatewaySession(for: account.did),
                          session == recovery.1
                    else {
                        throw GatewayError.invalidSession
                    }
                    throw GatewayError.authenticationRequired
                }
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
        try await attemptRecoveryFromServerFailures(for: currentAccount.did)
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
