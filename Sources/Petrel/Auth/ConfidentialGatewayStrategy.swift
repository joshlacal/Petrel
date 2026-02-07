//
//  ConfidentialGatewayStrategy.swift
//  Petrel
//
//  Created by Josh LaCalamito on 1/19/26.
//

import Foundation
import os.log

private let logger = Logger(
    subsystem: "blue.catbird.Petrel", category: "ConfidentialGatewayStrategy"
)

/// Session information returned by the gateway's /auth/session endpoint.
public struct GatewaySessionInfo: Codable, Sendable {
    public let did: String
    public let handle: String?
    public let active: Bool?
}

private struct GatewayErrorResponse: Decodable {
    let error: String?
    let message: String?
}

private enum UnauthorizedDisposition {
    case terminal(reason: String)
    case transient(reason: String)
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
        if let host = request.url?.host,
           let gatewayHost = gatewayURL.host,
           host == gatewayHost
        {
            switch classifyUnauthorizedGatewayResponse(data) {
            case let .terminal(reason):
                logger.warning(
                    "Gateway returned terminal auth error (reason: \(reason, privacy: .public)) - clearing local session"
                )
                await clearCurrentGatewaySession()
                throw GatewayError.sessionExpired

            case let .transient(reason):
                let bodyPreview = String((String(data: data, encoding: .utf8) ?? "").prefix(200))
                logger.warning(
                    "Gateway returned transient 401 (reason: \(reason, privacy: .public)) - preserving session. Body: \(bodyPreview, privacy: .public)"
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

    private func classifyUnauthorizedGatewayResponse(_ data: Data) -> UnauthorizedDisposition {
        if data.isEmpty {
            return .transient(reason: "empty_body")
        }

        let responseBody = String(data: data, encoding: .utf8) ?? ""
        let bodyLower = responseBody.lowercased()

        if bodyLower.contains("invalid token audience") {
            return .transient(reason: "invalid_audience")
        }

        let payload = try? JSONDecoder().decode(GatewayErrorResponse.self, from: data)
        let errorCode = (payload?.error ?? "").lowercased()
        let message = (payload?.message ?? responseBody).lowercased()

        let terminalCodes: Set<String> = [
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

        let transientCodes: Set<String> = [
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

    private func clearCurrentGatewaySession() async {
        guard let currentAccount = await accountManager.getCurrentAccount() else {
            logger.warning("No current account available while clearing gateway session")
            return
        }

        do {
            try await storage.deleteGatewaySession(for: currentAccount.did)
        } catch {
            logger.error(
                "Failed to delete gateway session during 401 handling: \(error, privacy: .public)"
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
                return try JSONDecoder().decode(GatewaySessionInfo.self, from: data)
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
