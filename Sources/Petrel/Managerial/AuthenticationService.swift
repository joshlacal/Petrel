//
//  AuthenticationService.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/22/2025.
//

import CryptoKit
import Foundation
import JSONWebAlgorithms
import JSONWebKey
import JSONWebSignature

/// Progress event types that can occur during authentication
public enum AuthProgressEvent: Sendable {
    case resolvingHandle(String)
    case fetchingMetadata(url: String)
    case generatingParameters
    case exchangingTokens
    case creatingSession
    case retrying(operation: String, attempt: Int, maxAttempts: Int)
}

/// Delegate protocol for receiving authentication progress updates
public protocol AuthProgressDelegate: AnyObject, Sendable {
    /// Called when authentication progress is updated
    /// - Parameter event: The progress event that occurred
    func authenticationProgress(_ event: AuthProgressEvent) async
}

/// Protocol defining the interface for authentication services.
protocol AuthServiceProtocol: Actor {
    /// Starts the OAuth flow for an existing user.
    /// - Parameter identifier: The user identifier (handle).
    /// - Returns: The authorization URL to present to the user.
    func startOAuthFlow(identifier: String?) async throws -> URL

    /// Handles the OAuth callback URL after user authentication.
    /// - Parameter url: The callback URL received from the authorization server.
    /// - Returns: Account information (DID, handle, PDS URL) for the authenticated user
    func handleOAuthCallback(url: URL) async throws -> (did: String, handle: String?, pdsURL: URL)

    /// Logs out the current user, invalidating their session.
    func logout() async throws

    /// Cancels any ongoing OAuth authentication flows.
    func cancelOAuthFlow() async

    /// Indicates whether authentication tokens exist for the current account.
    /// - Returns: True if tokens exist, false otherwise.
    func tokensExist() async -> Bool

    /// Refreshes the authentication token if needed.
    /// - Returns: Result indicating whether token was refreshed, still valid, or skipped
    func refreshTokenIfNeeded() async throws -> TokenRefreshResult

    /// Refreshes the authentication token if needed.
    /// - Parameter forceRefresh: If true, forces a refresh regardless of calculated expiry time
    /// - Returns: Result indicating whether token was refreshed, still valid, or skipped
    func refreshTokenIfNeeded(forceRefresh: Bool) async throws -> TokenRefreshResult

    /// Prepares an authenticated request by adding necessary authentication headers.
    /// - Parameter request: The original request to authenticate.
    /// - Returns: The request with authentication headers added.
    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest

    /// Sets the authentication progress delegate
    /// - Parameter delegate: The delegate to receive progress updates
    func setProgressDelegate(_ delegate: AuthProgressDelegate?) async
}

/// Result of a token refresh attempt
public enum TokenRefreshResult: Sendable {
    case refreshedSuccessfully // Token was actually refreshed
    case stillValid // Token is still valid, no refresh needed
    case skippedDueToRateLimit // Refresh was skipped due to rate limiting
}

/// Errors that can occur during authentication.
public enum AuthError: Error, LocalizedError, Equatable {
    case noActiveAccount
    case invalidCredentials
    case invalidHandle(String)
    case handleNotFound(String)
    case serverUnavailable(String)
    case invalidOAuthConfiguration
    case tokenRefreshFailed
    case authorizationFailed
    case invalidCallbackURL
    case dpopKeyError
    case networkError(Error)
    case invalidResponse
    case cancelled
    case timeout
    case rateLimited
    case serverError(Int, String?)
    case serviceMaintenance

    public var errorDescription: String? {
        switch self {
        case .noActiveAccount:
            return "No active account found. Please sign in to continue."
        case .invalidCredentials:
            return "The username or password you entered is incorrect. Please try again."
        case let .invalidHandle(handle):
            return "The handle '\(handle)' is not valid. Please check the format and try again."
        case let .handleNotFound(handle):
            return "The handle '\(handle)' could not be found. Please check the spelling and try again."
        case let .serverUnavailable(server):
            return "The server '\(server)' is currently unavailable. Please try again later."
        case .invalidOAuthConfiguration:
            return "Authentication configuration error. Please contact support if this continues."
        case .tokenRefreshFailed:
            return "Your session has expired. Please sign in again."
        case .authorizationFailed:
            return "Authentication failed. Please check your credentials and try again."
        case .invalidCallbackURL:
            return "Authentication callback failed. Please try signing in again."
        case .dpopKeyError:
            return "Security key error occurred during authentication. Please try again."
        case let .networkError(error):
            return "Network connection error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received an invalid response from the server. Please try again."
        case .cancelled:
            return "Authentication was cancelled."
        case .timeout:
            return "Authentication timed out. Please check your connection and try again."
        case .rateLimited:
            return "Too many authentication attempts. Please wait a moment and try again."
        case let .serverError(code, message):
            if let message = message {
                return "Server error (\(code)): \(message)"
            } else {
                return "Server error occurred (code \(code)). Please try again."
            }
        case .serviceMaintenance:
            return "The service is temporarily under maintenance. Please try again later."
        }
    }

    public var failureReason: String? {
        switch self {
        case .noActiveAccount:
            return "No authentication credentials are available."
        case .invalidCredentials:
            return "The provided credentials do not match any known account."
        case let .invalidHandle(handle):
            return "Handle '\(handle)' does not follow the expected format."
        case let .handleNotFound(handle):
            return "No account exists with the handle '\(handle)'."
        case let .serverUnavailable(server):
            return "Server '\(server)' is not responding or is temporarily offline."
        case let .networkError(error):
            return "Network connectivity issue: \(error.localizedDescription)"
        case .timeout:
            return "The authentication request took too long to complete."
        case .rateLimited:
            return "Authentication rate limit exceeded."
        default:
            return nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .noActiveAccount, .tokenRefreshFailed:
            return "Please sign in with your username and password."
        case .invalidCredentials:
            return "Double-check your username and password, then try again."
        case .invalidHandle, .handleNotFound:
            return "Verify the handle format (e.g., username.bsky.social) and spelling."
        case .serverUnavailable, .serviceMaintenance:
            return "Wait a few minutes and try again, or check service status."
        case .networkError, .timeout:
            return "Check your internet connection and try again."
        case .rateLimited:
            return "Wait a few minutes before attempting to sign in again."
        case .serverError:
            return "If this continues, please contact support."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }

    public static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.noActiveAccount, .noActiveAccount),
             (.invalidCredentials, .invalidCredentials),
             (.invalidOAuthConfiguration, .invalidOAuthConfiguration),
             (.tokenRefreshFailed, .tokenRefreshFailed),
             (.authorizationFailed, .authorizationFailed),
             (.invalidCallbackURL, .invalidCallbackURL),
             (.dpopKeyError, .dpopKeyError),
             (.networkError, .networkError),
             (.invalidResponse, .invalidResponse),
             (.cancelled, .cancelled),
             (.timeout, .timeout),
             (.rateLimited, .rateLimited),
             (.serviceMaintenance, .serviceMaintenance):
            return true
        case let (.invalidHandle(lhs), .invalidHandle(rhs)):
            return lhs == rhs
        case let (.handleNotFound(lhs), .handleNotFound(rhs)):
            return lhs == rhs
        case let (.serverUnavailable(lhs), .serverUnavailable(rhs)):
            return lhs == rhs
        case let (.serverError(lhsCode, lhsMsg), .serverError(rhsCode, rhsMsg)):
            return lhsCode == rhsCode && lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

/// Actor responsible for handling authentication operations.
actor AuthenticationService: AuthServiceProtocol, AuthenticationProvider {
    // MARK: - Properties

    /// Delegate for authentication progress updates
    private weak var progressDelegate: AuthProgressDelegate?

    /// Prevents concurrent OAuth start flows from stepping on each other
    /// and causing request cancellations (-999). When true, subsequent callers
    /// will wait until the in‑flight start completes and then proceed.
    private var oauthStartInProgress = false

    /// Single-flight registry for startOAuthFlow tasks keyed by identifier (or signup key when nil)
    private var oauthStartTasks: [String: Task<URL, Error>] = [:]

    /// Normalized key for a given identifier
    private func flowKey(for identifier: String?) -> String {
        identifier?.lowercased() ?? "__signup__"
    }

    /// Sets the authentication progress delegate
    /// - Parameter delegate: The delegate to receive progress updates
    func setProgressDelegate(_ delegate: AuthProgressDelegate?) async {
        progressDelegate = delegate
    }

    /// Emits a progress update to the delegate
    /// - Parameter event: The progress event to emit
    private func emitProgress(_ event: AuthProgressEvent) async {
        await progressDelegate?.authenticationProgress(event)
    }

    // MARK: - OAuth Callback Handling

    func handleOAuthCallback(url: URL) async throws -> (
        did: String, handle: String?, pdsURL: URL
    ) {
        LogManager.logInfo("Handling OAuth callback", category: .authentication)
        await emitProgress(.exchangingTokens)

        // 1. Extract code and state
        guard let code = extractAuthorizationCode(from: url),
              let stateToken = extractState(from: url)
        else {
            LogManager.logError("Callback URL missing code or state", category: .authentication)
            throw AuthError.invalidCallbackURL
        }
        LogManager.logDebug("Extracted authorization code and state token", category: .authentication)

        // 2. Retrieve OAuthState using the stateToken
        guard let oauthState = try await storage.getOAuthState(for: stateToken) else {
            LogManager.logError(
                "No matching OAuth state found for state token", category: .authentication
            )
            // It's possible the state was already used or expired.
            throw AuthError.invalidCallbackURL // Or a more specific state error
        }
        LogManager.logDebug("Successfully retrieved OAuth state", category: .authentication)

        // 3. Extract necessary info from oauthState
        let codeVerifier = oauthState.codeVerifier
        // Using _ to explicitly show we're reading but not using this variable
        _ = oauthState.targetPDSURL
        // Removed duplicate declarations of codeVerifier and pdsURL
        let initialNonce = oauthState.parResponseNonce

        // --- Get ephemeral key directly from OAuthState ---
        guard let keyData = oauthState.ephemeralDPoPKey else {
            LogManager.logError(
                "Ephemeral DPoP key data missing in retrieved OAuth state", category: .authentication
            )
            try? await storage.deleteOAuthState(for: stateToken)
            throw AuthError.dpopKeyError
        }

        let privateKey: P256.Signing.PrivateKey
        do {
            privateKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)
            LogManager.logDebug(
                "Successfully deserialized ephemeral DPoP key from OAuth state", category: .authentication
            )
            // Log that we're using the key for token exchange
            LogManager.logDebug(
                "Using deserialized ephemeral key for token exchange", category: .authentication
            )
        } catch {
            LogManager.logError(
                "Failed to deserialize ephemeral DPoP key: \(error)", category: .authentication
            )
            try? await storage.deleteOAuthState(for: stateToken)
            throw AuthError.dpopKeyError
        }

        LogManager.logDebug(
            "Token exchange nonce status: \(initialNonce != nil ? "present" : "none")",
            category: .authentication
        )
        // --- End Key Retrieval ---

        // 4. Delete the OAuthState *after* successfully retrieving all needed info
        do {
            try await storage.deleteOAuthState(for: stateToken)
            LogManager.logDebug("Successfully deleted OAuth state", category: .authentication)
        } catch {
            LogManager.logError("Failed to delete OAuth state: \(error)", category: .authentication)
            // Decide if you should proceed or throw. Proceeding might be okay if token exchange works,
            // but it leaves stale data. Throwing might be safer.
            throw AuthError.networkError(error)
        }

        // 3. Fetch Authorization Server Metadata (needed for token endpoint)
        // We stored the targetPDSURL in the OAuthState
        guard let pdsURL = oauthState.targetPDSURL else {
            LogManager.logError("Missing target PDS URL in OAuth state", category: .authentication)
            throw AuthError.invalidOAuthConfiguration // Or a more specific state error
        }
        LogManager.logDebug("Retrieved target PDS URL from OAuth state", category: .authentication)

        // Try to fetch protected resource metadata first (as per OAuth spec)
        let authServerURL: URL
        do {
            let metadata = try await fetchProtectedResourceMetadata(pdsURL: pdsURL)
            if let foundAuthServerURL = metadata.authorizationServers.first {
                authServerURL = foundAuthServerURL
                LogManager.logDebug(
                    "Found authorization server from protected resource metadata: \(authServerURL)")
            } else {
                // Protected resource metadata exists but has no auth servers listed
                LogManager.logError("Protected resource metadata has no authorization servers")
                throw AuthError.invalidOAuthConfiguration
            }
        } catch {
            // If protected resource metadata fetch fails (e.g., 404),
            // fall back to treating the URL as the authorization server itself
            LogManager.logDebug(
                "Could not fetch protected resource metadata from \(pdsURL), treating it as authorization server"
            )
            authServerURL = pdsURL
        }

        let authServerMetadata = try await fetchAuthorizationServerMetadata(
            authServerURL: authServerURL)
        let tokenEndpoint = authServerMetadata.tokenEndpoint
        LogManager.logDebug("Retrieved token endpoint", category: .authentication)

        // 4. Exchange code for tokens directly
        // Pass the extracted codeVerifier and the ephemeralKey

        // Add debug logging to show the key thumbprint
        let jwk = try createJWK(from: privateKey)
        _ = try calculateJWKThumbprint(jwk: jwk)
        LogManager.logDebug("Using ephemeral key for token exchange", category: .authentication)

        let tokenResponse = try await exchangeCodeForTokens(
            code: code,
            codeVerifier: codeVerifier, // Use the verifier from the state
            tokenEndpoint: tokenEndpoint,
            authServerURL: authServerURL, // Pass the auth server URL for DPoP proof
            ephemeralKey: privateKey, // Pass the ephemeral key
            initialNonce: initialNonce,
            resourceURL: pdsURL
        )

        // 5. Process Token Response
        guard let did = tokenResponse.sub else {
            LogManager.logError("Token response is missing 'sub' (DID)", category: .authentication)
            throw AuthError.invalidResponse // Or a more specific error
        }
        LogManager.logInfo(
            "Successfully exchanged code for tokens. Received DID: \(LogManager.logDID(did))",
            category: .authentication
        )

        // Resolve DID to get the actual PDS URL and handle (for signup flows, the account may live on a different PDS)
        let actualPDSURL: URL
        var resolvedHandle: String?
        do {
            // Use the new resolver method to get both PDS URL and handle in one call
            let (handle, pds) = try await didResolver.resolveDIDToHandleAndPDSURL(did: did)
            actualPDSURL = pds
            resolvedHandle = handle
            LogManager.logInfo(
                "Resolved DID to actual PDS: \(actualPDSURL.absoluteString) and handle: \(handle ?? "N/A")", category: .authentication
            )

            // Update pdsURL to use the resolved PDS instead of the signup PDS
            if actualPDSURL != pdsURL {
                LogManager.logInfo(
                    "Account PDS differs from signup PDS. Using actual PDS: \(actualPDSURL.absoluteString) instead of signup PDS: \(pdsURL.absoluteString)",
                    category: .authentication
                )
                // We'll use actualPDSURL for the account, but keep using pdsURL for this OAuth session
            }
        } catch {
            LogManager.logError(
                "Failed to resolve DID to PDS URL or handle, using signup PDS as fallback: \(error)",
                category: .authentication
            )
            actualPDSURL = pdsURL // Fallback to signup PDS
            resolvedHandle = nil
        }

        // Transfer any OAuth flow nonces to this new DID
        if !oauthFlowNonces.isEmpty {
            var didNonces = try await storage.getDPoPNonces(for: did) ?? [:]

            // Copy OAuth nonces to the confirmed DID's nonce storage
            for (domain, nonce) in oauthFlowNonces {
                didNonces[domain] = nonce
                LogManager.logDebug(
                    "Transferred nonce for domain \(domain) to DID", category: .authentication
                )
            }

            try await storage.saveDPoPNonces(didNonces, for: did)
            oauthFlowNonces = [:] // Clear memory store
            LogManager.logInfo("Transferred OAuth flow nonces to DID", category: .authentication)
        }

        // Determine token type based on response
        let tokenType: TokenType = (tokenResponse.tokenType.lowercased() == "dpop") ? .dpop : .bearer
        LogManager.logDebug("Determined token type: \(tokenType.rawValue)")

        // 6. Create Session with clock skew protection
        await emitProgress(.creatingSession)

        let adjustedExpiresIn = applyClockSkewProtection(to: tokenResponse.expiresIn)
        let newSession = Session(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            createdAt: Date(), // Use current time
            expiresIn: adjustedExpiresIn,
            tokenType: tokenType,
            did: did
        )
        LogManager.logDebug("Created new session for DID: \(did)")

        // 7. Create or Update Account
        // Check if account exists, otherwise create a new one
        var account = await accountManager.getAccount(did: did)
        let isNewAccount = account == nil

        // Try to fetch protected resource metadata for the account
        // This might have already been fetched earlier, but we need it for account creation
        let protectedResourceMetadata: ProtectedResourceMetadata?
        do {
            protectedResourceMetadata = try await fetchProtectedResourceMetadata(pdsURL: pdsURL)
            LogManager.logDebug("Successfully fetched protected resource metadata for account")
        } catch {
            LogManager.logDebug(
                "Could not fetch protected resource metadata for account (will use nil): \(error)")
            protectedResourceMetadata = nil
        }

        if isNewAccount {
            LogManager.logDebug("Creating new account for DID: \(did)")
            account = Account(
                did: did,
                handle: resolvedHandle ?? oauthState.initialIdentifier, // Use resolved handle, fallback to state
                pdsURL: actualPDSURL, // Use the resolved actual PDS URL, not the signup PDS
                protectedResourceMetadata: protectedResourceMetadata, // Store fetched metadata (may be nil)
                authorizationServerMetadata: authServerMetadata // Store fetched metadata
            )
        } else {
            LogManager.logDebug("Updating existing account for DID: \(did)")
            // Update existing account details if necessary
            account?.pdsURL = actualPDSURL // Ensure PDS URL is up-to-date with resolved actual PDS
            let existingHandle = account?.handle
            account?.handle = resolvedHandle ?? oauthState.initialIdentifier ?? existingHandle // Update handle if provided
            account?.protectedResourceMetadata = protectedResourceMetadata // Update metadata
            account?.authorizationServerMetadata = authServerMetadata // Update metadata
        }

        guard let finalAccount = account else {
            LogManager.logError("Failed to create or update account for DID: \(did)")
            throw AuthError.invalidResponse // Or a more specific internal error
        }

        // --- DPoP Key Handling ---
        // CRITICAL FIX: Save the ephemeral key as the persistent DPoP key for this user
        // This ensures the same key used in token exchange is used for subsequent API calls
        do {
            try await storage.saveDPoPKey(privateKey, for: did)
            LogManager.logInfo(
                "Stored the ephemeral DPoP key used in token exchange as the active key for DID",
                category: .authentication
            )
        } catch {
            LogManager.logError(
                "Failed to save the active DPoP key for DID after token exchange: \(error)",
                category: .authentication
            )
            throw AuthError.dpopKeyError
        }
        // --- End DPoP Key Handling ---

        // 8. Save Session and Account
        try await storage.saveSession(newSession, for: did)
        LogManager.logDebug("Saved session for DID: \(did)")
        try await accountManager.addAccount(finalAccount) // Changed from addOrUpdateAccount to add(account:)
        LogManager.logDebug("Added/Updated account in AccountManager for DID: \(did)")
        try await accountManager.setCurrentAccount(did: did) // Set as current account
        // Immediately point NetworkService at the resolved PDS to avoid early API calls hitting default base URL
        await networkService.setBaseURL(finalAccount.pdsURL)

        // Reset circuit breaker for fresh start after successful OAuth
        await refreshCircuitBreaker.reset(for: did)

        // Log successful OAuth completion
        LogManager.logInfo(
            "🎉 TOKEN_LIFECYCLE: OAuth flow completed successfully for DID \(LogManager.logDID(did)) "
                + "(token_type=\(tokenType.rawValue), expires_in=\(Int(adjustedExpiresIn))s)",
            category: .authentication
        )

        // 9. Store DPoP key binding if applicable
        if tokenType == .dpop, let jkt = tokenResponse.dpopJkt {
            // Use the ephemeral key retrieved from the OAuthState
            // Safely unwrap the ephemeralDPoPKey
            guard let ephemeralDPoPKeyData = oauthState.ephemeralDPoPKey else {
                LogManager.logError("DPoP key data is nil in oauth state for DID: \(did)")
                throw AuthError.dpopKeyError
            }
            let privateKey = try P256.Signing.PrivateKey(rawRepresentation: ephemeralDPoPKeyData)
            let jwk = try createJWK(from: privateKey)
            let thumbprint = try calculateJWKThumbprint(jwk: jwk)

            // Verify the thumbprint matches the jkt from the server
            if thumbprint == jkt {
                LogManager.logDebug("DPoP JKT matches calculated thumbprint for DID: \(did)")
                // Optionally store the binding, though the key itself is stored securely
            } else {
                LogManager.logError(
                    "DPoP JKT mismatch! Server: \(jkt), Calculated: \(thumbprint) for DID: \(did)")
                // This indicates a potential security issue or misconfiguration.
                // Depending on policy, you might want to invalidate the session.
                // For now, just log the error. Consider throwing AuthError.dpopKeyError here.
                throw AuthError.dpopKeyError
            }
        }

        // Return account information for immediate access
        return (did: did, handle: finalAccount.handle, pdsURL: finalAccount.pdsURL)
    }

    func logout() async throws {
        LogManager.logInfo("Starting logout process.")
        guard let did = await accountManager.getCurrentAccount()?.did else {
            LogManager.logDebug("Logout called but no active account found.")
            // No active user, nothing to log out.
            return
        }

        LogManager.logInfo(
            "Logging out account with DID: \(LogManager.logDID(did))", category: .authentication
        )

        // 1. Attempt to revoke token (optional but good practice)
        if let account = await accountManager.getAccount(did: did),
           let session = try? await storage.getSession(for: did),
           let refreshToken = session.refreshToken,
           let revocationEndpoint = account.authorizationServerMetadata?.revocationEndpoint
        {
            LogManager.logDebug("Attempting to revoke token at: \(revocationEndpoint)")
            await revokeToken(refreshToken: refreshToken, endpoint: revocationEndpoint, did: did)
            // Continue logout even if revocation fails
        } else {
            LogManager.logDebug(
                "Could not attempt token revocation for DID \(did) - missing session, token, or revocation endpoint."
            )
        }

        // 2. Delete local session data
        do {
            try await storage.deleteSession(for: did)
            LogManager.logDebug("Deleted session for DID: \(did)")
        } catch {
            LogManager.logError("Failed to delete session for DID \(did): \(error)")
            // Continue logout process
        }

        // 3. Delete DPoP key
        do {
            try await storage.deleteDPoPKey(for: did)
            LogManager.logDebug("Deleted DPoP key for DID: \(did)")
        } catch {
            LogManager.logError("Failed to delete DPoP key for DID \(did): \(error)")
            // Continue logout process
        }

        // 4. Delete DPoP nonces
        do {
            // Saving empty nonces effectively deletes them
            try await storage.saveDPoPNonces([:], for: did)
            try await storage.saveDPoPNoncesByJKT([:], for: did)
            LogManager.logDebug("Deleted DPoP nonces for DID: \(did)")
        } catch {
            LogManager.logError("Failed to delete DPoP nonces for DID \(did): \(error)")
            // Continue logout process
        }

        // Clear in-memory JKT-scoped nonce cache
        noncesByThumbprint = [:]

        // 5. Update Account Manager State
        // Remove the account entirely or just clear the current user?
        // Let's remove the account for a full logout effect.
        // `removeAccount` handles switching to another account if available.
        do {
            try await accountManager.removeAccount(did: did)
            LogManager.logInfo("Removed account and updated current account status.")
            // If another account is now current, immediately align networking state
            if let newAccount = await accountManager.getCurrentAccount() {
                // Ensure subsequent API calls target the correct protected resource
                await networkService.setBaseURL(newAccount.pdsURL)
                // Clear any per-request headers carried from the previous account
                await networkService.clearHeaders()
            }
        } catch {
            LogManager.logError(
                "Failed during account removal/switching after logout for DID \(did): \(error)")
            // At this point, local data is cleared, but account manager state might be inconsistent.
            // Consider just clearing currentDID as a fallback?
            // try? await accountManager.setCurrentAccount(did: "") // Or handle more gracefully
        }

        // Reset circuit breaker state for this DID
        await refreshCircuitBreaker.reset(for: did)

        // Log logout completion
        LogManager.logInfo(
            "🚪 TOKEN_LIFECYCLE: Logout completed for DID \(LogManager.logDID(did)) "
                + "(session_cleared=true, account_removed=true, circuit_reset=true)",
            category: .authentication
        )
    }

    // MARK: - Audience Override (one-shot)

    /// Optionally override the OAuth Resource Indicator for the next refresh only.
    /// This helps recover from an "invalid audience" 401 by minting a token for the
    /// specific protected resource that produced the failure.
    private var nextRefreshResourceOverride: String?

    func setNextRefreshResourceOverride(_ resource: String) async {
        nextRefreshResourceOverride = resource
        LogManager.logInfo(
            "AuthenticationService: Next refresh will use resource override: \(resource)")
    }

    /// Attempts to revoke a refresh token at the authorization server.
    /// - Parameters:
    ///   - refreshToken: The refresh token to revoke.
    ///   - endpoint: The URL of the revocation endpoint.
    ///   - did: The DID associated with the token (for DPoP proof).
    private func revokeToken(refreshToken: String, endpoint: String, did: String) async {
        guard let endpointURL = URL(string: endpoint) else {
            LogManager.logError("Invalid revocation endpoint URL: \(endpoint)")
            return
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let parameters: [String: String] = [
            "token": refreshToken,
            "token_type_hint": "refresh_token",
            "client_id": oauthConfig.clientId, // Client ID might be required // FIX: Use self.oauthConfig
        ]
        request.httpBody = encodeFormData(parameters)

        // Add DPoP proof if required by the server for revocation
        // The spec is sometimes ambiguous here, but adding it might be necessary.
        // Using .tokenRequest type for now, consider adding a specific .tokenRevocation if needed.
        do {
            let dpopProof = try await createDPoPProof(
                for: "POST", url: endpoint, type: .tokenRequest, did: did
            )
            request.setValue(dpopProof, forHTTPHeaderField: "DPoP")
        } catch {
            LogManager.logError("Failed to create DPoP proof for token revocation: \(error)")
            // Decide if revocation should proceed without DPoP or fail here
            // Let's not proceed without DPoP if creation failed, as the server might require it.
            return
        }

        do {
            let (_, response) = try await networkService.request(request)
            if let httpResponse = response as? HTTPURLResponse,
               (200 ... 299).contains(httpResponse.statusCode)
            {
                LogManager.logInfo("Successfully revoked token for DID: \(did)")
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                LogManager.logDebug(
                    "Token revocation request failed or returned non-2xx status: \(statusCode) for DID: \(did)"
                )
                // Log response body if available for debugging
                // let responseBody = String(data: data, encoding: .utf8) ?? "No body"
                // LogManager.logDebug("Revocation failure response body: \(responseBody)")
            }
        } catch {
            LogManager.logError("Network error during token revocation for DID \(did): \(error)")
        }
    }

    func handleUnauthorizedResponse(
        _ response: HTTPURLResponse, data: Data, for request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        // Check if the response is unauthorized (401)
        guard response.statusCode == 401 else {
            return (data, response)
        }

        // Attempt to refresh the token
        let did = await accountManager.getCurrentAccount()?.did
        guard let did = did else {
            throw AuthError.noActiveAccount as Error
        }

        // Force refresh the token on 401 - ignore calculated expiry since server rejected our token
        LogManager.logInfo("🚨 Received 401 unauthorized - attempting token refresh")
        let refreshResult = try await refreshTokenIfNeeded(forceRefresh: true)

        // Only retry if we ACTUALLY refreshed the token
        switch refreshResult {
        case .refreshedSuccessfully:
            LogManager.logInfo("Token was refreshed successfully, retrying request")
            var newRequest = request
            if (try? await storage.getSession(for: did)) != nil {
                // Prepare the authenticated request with the new token
                newRequest = try await prepareAuthenticatedRequest(newRequest)

                // Perform the request
                let result = try await networkService.request(newRequest)

                if let httpResponse = result.1 as? HTTPURLResponse {
                    return (result.0, httpResponse)
                } else {
                    throw AuthError.invalidResponse as Error
                }
            } else {
                throw AuthError.tokenRefreshFailed as Error
            }

        case .stillValid:
            // Token is supposedly still valid, but we got a 401
            // This shouldn't happen, but if it does, don't retry to avoid loops
            LogManager.logError("Token reported as still valid but got 401. Not retrying to avoid loop.")
            throw AuthError.tokenRefreshFailed as Error

        case .skippedDueToRateLimit:
            // Refresh was skipped due to rate limiting
            // Don't retry with the same token - it will just fail again
            LogManager.logError("Token refresh skipped due to rate limiting. Cannot retry request.")
            throw AuthError.tokenRefreshFailed as Error
        }
    }

    func updateDPoPNonce(
        for url: URL, from headers: [String: String], did: String?, jkt: String?
    ) async {
        guard let domain = url.host?.lowercased(), let nonce = headers["DPoP-Nonce"] else {
            return
        }

        // ENHANCED: Synchronize in-memory and persistent storage atomically
        let resolvedDID: String? =
            (did?.isEmpty == false) ? did : await accountManager.getCurrentAccount()?.did
        
        // First update in-memory stores
        if let jkt, !jkt.isEmpty {
            var domainMap = noncesByThumbprint[jkt] ?? [:]
            domainMap[domain] = nonce
            noncesByThumbprint[jkt] = domainMap
            LogManager.logDebug("Updated in-memory JKT-scoped nonce: jkt=\(jkt), domain=\(domain)")
        }

        // Then update persistent storage
        if let resolvedDID {
            await updateDPoPNonce(domain: domain, nonce: nonce, for: resolvedDID)

            // Persist JKT-scoped nonces for this DID as well
            if let jkt, !jkt.isEmpty {
                do {
                    var persisted = (try? await storage.getDPoPNoncesByJKT(for: resolvedDID)) ?? [:]
                    var doms = persisted[jkt] ?? [:]
                    doms[domain] = nonce
                    persisted[jkt] = doms
                    try await storage.saveDPoPNoncesByJKT(persisted, for: resolvedDID)
                    LogManager.logDebug("Persisted JKT-scoped nonce: did=\(LogManager.logDID(resolvedDID)), jkt=\(jkt), domain=\(domain)")
                } catch {
                    LogManager.logError("Failed to persist JKT-scoped nonce: \(error)")
                }
            }
        }
    }

    // MARK: - Properties

    private let storage: KeychainStorage
    private let accountManager: AccountManaging
    private let networkService: NetworkService
    private let oauthConfig: OAuthConfig
    private let didResolver: DIDResolving
    private let refreshCoordinator = TokenRefreshCoordinator()
    private let refreshCircuitBreaker = RefreshCircuitBreaker()
    // Simple in-memory store for OAuth flow nonces (independent of any account)
    private var oauthFlowNonces: [String: String] = [:]
    // JKT-scoped nonces (key thumbprint -> domain -> nonce)
    private var noncesByThumbprint: [String: [String: String]] = [:]
    // Track last refresh attempt time per DID for rate limiting
    private var lastRefreshAttempt: [String: Date] = [:]
    private var lastSuccessfulRefresh: [String: Date] = [:]
    private let minimumRefreshInterval: TimeInterval = 0.5 // 500ms between attempts
    private let minimumRefreshIntervalAfterSuccess: TimeInterval = 30.0 // 30 seconds after successful refresh
    // Track ambiguous refresh timeouts where server may have rotated tokens but client didn't receive them
    private var ambiguousRefreshUntil: [String: Date] = [:]

    // Test hook: mark ambiguous refresh state for a DID (internal)
    func markAmbiguousRefresh(for did: String, durationSeconds: TimeInterval = 900) async {
        ambiguousRefreshUntil[did] = Date().addingTimeInterval(durationSeconds)
        LogManager.logInfo(
            "[TEST] Marked ambiguous refresh until for DID: \(LogManager.logDID(did)) for \(Int(durationSeconds))s"
        )
    }

    // MARK: - Initialization

    /// Initializes a new AuthenticationService with the specified dependencies.
    /// - Parameters:
    ///   - storage: The secure storage for tokens and keys.
    ///   - accountManager: The account manager.
    ///   - networkService: The network service for making HTTP requests.
    ///   - oauthConfig: The OAuth configuration.
    ///   - didResolver: The DID resolver for resolving DIDs to PDS URLs.
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

    // MARK: - OAuth Flow

    /// Starts the OAuth flow for an existing user.
    /// - Parameter identifier: The user identifier (handle), optional if signing up.
    /// - Returns: The authorization URL to present to the user.
    func startOAuthFlow(identifier: String? = nil) async throws -> URL {
        // Coalesce concurrent calls per-identifier and decouple from caller cancellation
        let key = flowKey(for: identifier)

        if let existing = oauthStartTasks[key] {
            LogManager.logInfo(
                "OAuth start already in progress for key=\(key), joining existing task",
                category: .authentication
            )
            return try await existing.value
        }

        // Run flow on a detached root task so user-initiated cancellation of the caller
        // does not cancel underlying URLSession tasks (prevents -999 cancellations).
        let task = Task.detached(priority: .userInitiated) { [weak self] () throws -> URL in
            guard let self else { throw AuthError.invalidOAuthConfiguration }
            return try await self._startOAuthFlowImpl(identifier: identifier)
        }
        oauthStartTasks[key] = task
        defer { oauthStartTasks.removeValue(forKey: key) }
        return try await task.value
    }

    /// Cancels any ongoing OAuth authentication flows.
    func cancelOAuthFlow() async {
        LogManager.logInfo("Cancelling all OAuth flows", category: .authentication)

        // Cancel all running OAuth tasks
        for (key, task) in oauthStartTasks {
            LogManager.logDebug("Cancelling OAuth task for key: \(key)", category: .authentication)
            task.cancel()
        }

        // Clear the tasks dictionary
        oauthStartTasks.removeAll()

        // Reset the global flag
        oauthStartInProgress = false
    }

    /// Internal implementation of the OAuth start flow. Kept actor-isolated; invoked from a detached task
    /// to shield underlying URLSession operations from parent Task cancellation.
    private func _startOAuthFlowImpl(identifier: String?) async throws -> URL {
        // Gate concurrent starts globally to keep legacy protection too
        if oauthStartInProgress {
            LogManager.logInfo(
                "OAuth start already in progress (global), waiting for completion",
                category: .authentication
            )
            while oauthStartInProgress {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }

        oauthStartInProgress = true
        defer { oauthStartInProgress = false }
        let pdsURL: URL
        var did: String?

        // Check for cancellation at the start
        try Task.checkCancellation()

        // For sign-up flow (no identifier), use default PDS URL
        if let identifier = identifier {
            await emitProgress(.resolvingHandle(identifier))

            // Check for cancellation before network operations
            try Task.checkCancellation()

            // Resolve handle to DID and DID to PDS URL
            did = try await didResolver.resolveHandleToDID(handle: identifier)
            guard let resolvedDID = did else {
                throw AuthError.invalidCredentials
            }

            try Task.checkCancellation()

            pdsURL = try await didResolver.resolveDIDToPDSURL(did: resolvedDID)
        } else {
            // Use default PDS URL for sign-up
            guard let defaultURL = URL(string: "https://bsky.social") else {
                throw AuthError.invalidOAuthConfiguration
            }
            pdsURL = defaultURL
        }

        // Check for cancellation before metadata fetch
        try Task.checkCancellation()

        // Try to fetch protected resource metadata first (as per OAuth spec)
        await emitProgress(.fetchingMetadata(url: pdsURL.absoluteString))

        let authServerURL: URL
        do {
            let metadata = try await fetchProtectedResourceMetadata(pdsURL: pdsURL)
            if let foundAuthServerURL = metadata.authorizationServers.first {
                authServerURL = foundAuthServerURL
                LogManager.logDebug(
                    "Found authorization server from protected resource metadata: \(authServerURL)")
            } else {
                // Protected resource metadata exists but has no auth servers listed
                LogManager.logError("Protected resource metadata has no authorization servers")
                throw AuthError.invalidOAuthConfiguration
            }
        } catch {
            // If protected resource metadata fetch fails (e.g., 404),
            // fall back to treating the URL as the authorization server itself
            LogManager.logDebug(
                "Could not fetch protected resource metadata from \(pdsURL), treating it as authorization server"
            )
            authServerURL = pdsURL
        }

        // Fetch Authorization Server Metadata
        let authServerMetadata = try await fetchAuthorizationServerMetadata(
            authServerURL: authServerURL)

        // Generate PKCE code verifier and challenge
        await emitProgress(.generatingParameters)

        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Generate state token
        let stateToken = UUID().uuidString

        // Generate an ephemeral key for this OAuth session
        let ephemeralKey = P256.Signing.PrivateKey()

        // Removed caching of the key

        // Add debug logging for key tracking
        LogManager.logDebug("Generated ephemeral DPoP key for OAuth session", category: .authentication)

        // Create Pushed Authorization Request (PAR)
        let parEndpoint = authServerMetadata.pushedAuthorizationRequestEndpoint
        let (requestURI, parNonce) = try await pushAuthorizationRequest( // <-- Capture parNonce
            codeChallenge: codeChallenge,
            identifier: identifier,
            endpoint: parEndpoint,
            authServerURL: authServerURL,
            state: stateToken,
            ephemeralKeyForFlow: ephemeralKey // <-- Re-add Parameter Pass
        )

        let oauthState = OAuthState(
            stateToken: stateToken,
            codeVerifier: codeVerifier,
            createdAt: Date(),
            initialIdentifier: identifier,
            targetPDSURL: pdsURL,
            ephemeralDPoPKey: ephemeralKey.rawRepresentation,
            parResponseNonce: parNonce
        )
        try await storage.saveOAuthState(oauthState)
        LogManager.logDebug(
            "Saved OAuth state with PAR nonce status: \(parNonce != nil ? "present" : "none")",
            category: .authentication
        )

        // Build Authorization URL
        guard var components = URLComponents(string: authServerMetadata.authorizationEndpoint) else {
            throw AuthError.invalidOAuthConfiguration
        }
        components.queryItems = [
            URLQueryItem(name: "request_uri", value: requestURI),
            URLQueryItem(name: "client_id", value: oauthConfig.clientId), // FIX: Use self.oauthConfig
            URLQueryItem(name: "redirect_uri", value: oauthConfig.redirectUri), // FIX: Use self.oauthConfig
        ]

        guard let authorizationURL = components.url else {
            throw AuthError.authorizationFailed as Error
        }

        return authorizationURL
    }

    /// Starts the OAuth flow for a new account signup (without requiring a handle)
    /// - Parameter pdsURL: The PDS URL to use for sign-up
    /// - Returns: The authorization URL to present to the user
    func startOAuthFlowForSignUp(pdsURL: URL? = nil)
        async throws -> URL
    {
        // Use provided URL or default to bsky.social
        let finalPDSURL: URL
        if let providedURL = pdsURL {
            finalPDSURL = providedURL
        } else {
            guard let defaultURL = URL(string: "https://bsky.social") else {
                throw AuthError.invalidOAuthConfiguration
            }
            finalPDSURL = defaultURL
        }

        // Create a special OAuth state for sign-up
        let stateToken = UUID().uuidString
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // *** NEW: Generate ephemeral key for sign-up PAR ***
        let ephemeralKey = P256.Signing.PrivateKey()
        LogManager.logDebug("Generated ephemeral DPoP key for sign-up OAuth session")

        // Create OAuth state for a sign-up flow (no identifier)
        // *** MODIFIED: Store key data initially ***
        let oauthState = OAuthState(
            stateToken: stateToken,
            codeVerifier: codeVerifier,
            createdAt: Date(),
            initialIdentifier: nil,
            targetPDSURL: finalPDSURL,
            ephemeralDPoPKey: ephemeralKey.rawRepresentation,
            parResponseNonce: nil // Initialize explicitly as nil, will update after PAR
        )
        // Save the initial state (optional, but good practice if PAR fails before nonce is known)
        // try await storage.saveOAuthState(oauthState) // Consider if needed

        // Try to fetch protected resource metadata first (as per OAuth spec)
        let authServerURL: URL
        do {
            let protectedResourceMetadata = try await fetchProtectedResourceMetadata(pdsURL: finalPDSURL)
            if let foundAuthServerURL = protectedResourceMetadata.authorizationServers.first {
                authServerURL = foundAuthServerURL
                LogManager.logDebug(
                    "Found authorization server from protected resource metadata: \(authServerURL)")
            } else {
                // Protected resource metadata exists but has no auth servers listed
                LogManager.logError("Protected resource metadata has no authorization servers")
                throw AuthError.invalidOAuthConfiguration
            }
        } catch {
            // If protected resource metadata fetch fails (e.g., 404),
            // fall back to treating the URL as the authorization server itself
            LogManager.logDebug(
                "Could not fetch protected resource metadata from \(finalPDSURL), treating it as authorization server"
            )
            authServerURL = finalPDSURL
        }

        let authServerMetadata = try await fetchAuthorizationServerMetadata(
            authServerURL: authServerURL)

        // Create PAR request without login_hint (this is the key difference for signup)
        let parEndpoint = authServerMetadata.pushedAuthorizationRequestEndpoint
        // *** MODIFIED: Capture both values from the tuple ***
        let (requestURI, parNonce) = try await pushAuthorizationRequestForSignUp(
            codeChallenge: codeChallenge,
            endpoint: parEndpoint,
            authServerURL: authServerURL,
            state: stateToken,
            ephemeralKey: ephemeralKey // <-- Pass the key to sign the PAR request
        )

        // *** MODIFIED: Update and save OAuthState *with* the nonce and ensure key data is present ***
        var finalOauthState = oauthState // Create mutable copy
        finalOauthState.parResponseNonce = parNonce // Add the nonce
        // Ensure key data is set (redundant if initial save is removed, but safe)
        finalOauthState.ephemeralDPoPKey = ephemeralKey.rawRepresentation
        try await storage.saveOAuthState(finalOauthState) // Save the complete state
        LogManager.logDebug(
            "Saved OAuth state for sign-up with PAR nonce status: \(parNonce != nil ? "present" : "none")",
            category: .authentication
        )
        // Build authorization URL
        guard var components = URLComponents(string: authServerMetadata.authorizationEndpoint) else {
            throw AuthError.invalidOAuthConfiguration
        }
        components.queryItems = [
            URLQueryItem(name: "request_uri", value: requestURI),
            URLQueryItem(name: "client_id", value: oauthConfig.clientId), // FIX: Use self.oauthConfig
            URLQueryItem(name: "redirect_uri", value: oauthConfig.redirectUri), // FIX: Use self.oauthConfig
        ]

        guard let authorizationURL = components.url else {
            throw AuthError.authorizationFailed as Error
        }

        return authorizationURL
    }

    /// Pushes an authorization request to the PAR endpoint specifically for sign-up flows (without login_hint)
    /// - Parameters:
    ///   - codeChallenge: The PKCE code challenge
    ///   - endpoint: The PAR endpoint
    ///   - authServerURL: The authorization server URL
    ///   - state: The state token
    ///   - ephemeralKey: The ephemeral key generated for this sign-up flow.
    /// - Returns: A tuple containing the request URI and the DPoP nonce from the response header, if present.
    private func pushAuthorizationRequestForSignUp(
        codeChallenge: String,
        endpoint: String,
        authServerURL: URL,
        state: String,
        ephemeralKey: P256.Signing.PrivateKey // <-- ADD Parameter
    ) async throws -> (requestURI: String, parNonce: String?) { // <-- MODIFIED Return Type
        let parameters: [String: String] = [
            "client_id": oauthConfig.clientId, // FIX: Use self.oauthConfig
            "redirect_uri": oauthConfig.redirectUri, // FIX: Use self.oauthConfig
            "response_type": "code",
            "code_challenge_method": "S256",
            "code_challenge": codeChallenge,
            "state": state,
            "scope": oauthConfig.scope, // FIX: Use self.oauthConfig // Ensure scope is included
        ]

        let body = encodeFormData(parameters)

        guard let endpointURL = URL(string: endpoint) else {
            throw AuthError.invalidOAuthConfiguration
        }
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // --- DPoP Proof Generation (using ephemeral key as no account exists yet) ---
        LogManager.logInfo("No active account for Sign-Up PAR, using provided ephemeral DPoP key.")
        // Use the key passed into the function
        let dpopProof = try await createDPoPProof(
            for: "POST", url: endpoint, type: .authorization, ephemeralKey: ephemeralKey
        ) // Use passed key
        request.setValue(dpopProof, forHTTPHeaderField: "DPoP")
        // --- End DPoP Proof Generation ---

        // Send the request using the network service
        let (data, response) = try await networkService.request(request)

        guard let httpResponse = response as? HTTPURLResponse else { throw AuthError.invalidResponse }

        // Check if initial request succeeded
        if (200 ... 299).contains(httpResponse.statusCode) {
            guard let parResponse = try? JSONDecoder().decode(PARResponse.self, from: data) else {
                throw AuthError.invalidResponse
            }
            let requestURI = parResponse.requestURI

            // *** FIX: Extract nonce case-insensitively ***
            var parNonce: String? = nil
            for (key, value) in httpResponse.allHeaderFields {
                if let keyString = key as? String,
                   keyString.caseInsensitiveCompare("DPoP-Nonce") == .orderedSame
                {
                    parNonce = value as? String
                    break
                }
            }
            // *** End Fix ***

            // *** MODIFIED: Return BOTH URI and Nonce ***
            return (requestURI, parNonce)
        }
        // Check if it's a 400 error potentially requiring a nonce
        else if httpResponse.statusCode == 400 {
            let dpopNonceHeader = httpResponse.allHeaderFields["dpop-nonce"] as? String
            var isNonceError = false
            // Decode error response to check if it's 'use_dpop_nonce'
            if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data),
               errorResponse.error == "use_dpop_nonce"
            {
                isNonceError = true
            }

            if isNonceError, let receivedNonce = dpopNonceHeader {
                LogManager.logInfo(
                    "Received use_dpop_nonce error on Sign-Up PAR. Retrying with received nonce",
                    category: .authentication
                )
                var retryRequest = request // Create a mutable copy for retry
                // Use the same ephemeral key for the retry proof
                let retryProof = try await createDPoPProof(
                    for: "POST", url: endpoint, type: .authorization, ephemeralKey: ephemeralKey,
                    nonce: receivedNonce
                )
                retryRequest.setValue(retryProof, forHTTPHeaderField: "DPoP")

                let (retryData, retryResponse) = try await networkService.request(retryRequest)
                guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                    throw AuthError.invalidResponse
                }

                if (200 ... 299).contains(retryHttpResponse.statusCode) {
                    // *** Success on Retry: Extract URI and Nonce ***
                    guard let parResponse = try? JSONDecoder().decode(PARResponse.self, from: retryData)
                    else { throw AuthError.invalidResponse }
                    let requestURI = parResponse.requestURI
                    let parNonce = retryHttpResponse.value(forHTTPHeaderField: "dpop-nonce") // Get nonce from retry response
                    if let nonce = parNonce {
                        LogManager.logDebug(
                            "Captured DPoP Nonce from successful Sign-Up PAR retry response: \(nonce)")
                    } else {
                        LogManager.logDebug(
                            "No DPoP Nonce found in successful Sign-Up PAR retry response header.")
                    }
                    return (requestURI, parNonce) // Return URI and Nonce from retry
                } else {
                    // Retry failed
                    let errorDetails = String(data: retryData, encoding: .utf8) ?? "No details"
                    LogManager.logError(
                        "Sign-Up PAR retry failed with status code \(retryHttpResponse.statusCode). Response: \(errorDetails)"
                    )
                    throw AuthError.authorizationFailed // Indicate PAR failure
                }
            } else {
                // Non-retryable 400 error
                let errorDetails = String(data: data, encoding: .utf8) ?? "No details"
                LogManager.logError(
                    "Sign-Up PAR failed with status code 400 (Non-retryable). Response: \(errorDetails)")
                throw AuthError.authorizationFailed // Indicate PAR failure
            }
        }
        // Handle other non-2xx, non-400 status codes
        else {
            let errorDetails = String(data: data, encoding: .utf8) ?? "No details"
            LogManager.logError(
                "Sign-Up PAR failed with status code \(httpResponse.statusCode). Response: \(errorDetails)"
            )
            throw AuthError.authorizationFailed // Indicate PAR failure
        }
    }

    /// Pushes an authorization request to the PAR endpoint.
    /// - Parameters:
    ///   - codeChallenge: The PKCE code challenge.
    ///   - identifier: The user identifier (optional for sign-up).
    ///   - endpoint: The PAR endpoint.
    ///   - authServerURL: The authorization server URL.
    ///   - state: The state token.
    /// - Returns: A tuple containing the request URI and the DPoP nonce from the response header, if present.
    private func pushAuthorizationRequest(
        codeChallenge: String,
        identifier: String?,
        endpoint: String,
        authServerURL: URL,
        state: String,
        ephemeralKeyForFlow: P256.Signing.PrivateKey? = nil // <-- Re-add Parameter
    ) async throws -> (requestURI: String, parNonce: String?) { // <-- MODIFIED Return Type
        var parameters: [String: String] = [
            "client_id": oauthConfig.clientId, // FIX: Use self.oauthConfig
            "redirect_uri": oauthConfig.redirectUri, // FIX: Use self.oauthConfig
            "response_type": "code",
            "code_challenge_method": "S256",
            "code_challenge": codeChallenge,
            "state": state,
            "scope": oauthConfig.scope, // FIX: Use self.oauthConfig // Ensure scope is included
        ]

        // Add login_hint if identifier is provided (for sign-in, not sign-up)
        if let identifier = identifier {
            parameters["login_hint"] = identifier
        }

        // Encode the parameters
        let body = encodeFormData(parameters)

        // Create the request
        guard let endpointURL = URL(string: endpoint) else {
            throw AuthError.invalidOAuthConfiguration
        }
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // --- DPoP Proof Generation ---
        let currentDID = await accountManager.getCurrentAccount()?.did
        var proofKey: P256.Signing.PrivateKey? = nil // Variable to hold the key used for proof AND retry
        let dpopProof: String

        // ** ALWAYS prioritize the key generated FOR THIS SPECIFIC FLOW if provided **
        if let providedKey = ephemeralKeyForFlow {
            LogManager.logInfo("Using provided ephemeral DPoP key for PAR flow.")
            proofKey = providedKey // Keep track for potential retry
            dpopProof = try await createDPoPProof(
                for: "POST", url: endpoint, type: .authorization, ephemeralKey: providedKey
            )
        }
        // Only use persistent key if NO ephemeral key was provided for the flow
        // (Should only happen if called from a context other than startOAuthFlow/startSignUpFlow)
        else if let did = currentDID {
            LogManager.logDebug(
                "No ephemeral key provided for PAR, but active account (\(did)) found. Using persistent key (unusual for standard flow)."
            )
            proofKey = try await getOrCreateDPoPKey(for: did)
            dpopProof = try await createDPoPProof(
                for: "POST", url: endpoint, type: .authorization, did: did
            )
        } else {
            // Fallback: Should not happen if startOAuthFlow always provides a key
            LogManager.logError(
                "No active account and no ephemeral key provided for PAR. Generating temporary key (unexpected)."
            ) // Changed logWarning to logError
            let tempKey = P256.Signing.PrivateKey()
            proofKey = tempKey
            dpopProof = try await createDPoPProof(
                for: "POST", url: endpoint, type: .authorization, ephemeralKey: tempKey
            )
        }
        request.setValue(dpopProof, forHTTPHeaderField: "DPoP")
        // --- End DPoP Proof Generation ---

        // Send the request using the network service
        let (data, response) = try await networkService.request(request)

        guard let httpResponse = response as? HTTPURLResponse else { throw AuthError.invalidResponse }

        // Check if initial request succeeded
        if (200 ... 299).contains(httpResponse.statusCode) {
            guard let parResponse = try? JSONDecoder().decode(PARResponse.self, from: data) else {
                throw AuthError.invalidResponse
            }
            let requestURI = parResponse.requestURI
            // *** NEW: Extract the nonce from the SUCCESSFUL response header ***
            var parNonce: String? = nil
            for (key, value) in httpResponse.allHeaderFields {
                if let keyString = key as? String,
                   keyString.caseInsensitiveCompare("DPoP-Nonce") == .orderedSame
                {
                    parNonce = value as? String
                    break
                }
            }
            // *** End Fix ***

            // *** MODIFIED: Return BOTH URI and Nonce ***
            return (requestURI, parNonce)
        }
        // Check if it's a 400 error potentially requiring a nonce
        else if httpResponse.statusCode == 400 {
            let dpopNonceHeader = httpResponse.allHeaderFields["dpop-nonce"] as? String
            var isNonceError = false
            // Decode error response to check if it's 'use_dpop_nonce'
            if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data),
               errorResponse.error == "use_dpop_nonce"
            {
                isNonceError = true
            }

            if isNonceError, let receivedNonce = dpopNonceHeader {
                LogManager.logInfo(
                    "Received use_dpop_nonce error on PAR. Retrying with received nonce",
                    category: .authentication
                )
                var retryRequest = request // Create a mutable copy for retry
                // Use the same ephemeral key for the retry proof
                let retryProof = try await createDPoPProof(
                    for: "POST", url: endpoint, type: .authorization, ephemeralKey: proofKey,
                    nonce: receivedNonce
                )
                retryRequest.setValue(retryProof, forHTTPHeaderField: "DPoP")

                let (retryData, retryResponse) = try await networkService.request(retryRequest)
                guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                    throw AuthError.invalidResponse
                }

                if (200 ... 299).contains(retryHttpResponse.statusCode) {
                    // *** Success on Retry: Extract URI and Nonce ***
                    guard let parResponse = try? JSONDecoder().decode(PARResponse.self, from: retryData)
                    else { throw AuthError.invalidResponse }
                    let requestURI = parResponse.requestURI
                    let parNonce = retryHttpResponse.value(forHTTPHeaderField: "dpop-nonce") // Get nonce from retry response
                    if let nonce = parNonce {
                        LogManager.logDebug(
                            "Captured DPoP Nonce from successful Sign-Up PAR retry response: \(nonce)")
                    } else {
                        LogManager.logDebug(
                            "No DPoP Nonce found in successful Sign-Up PAR retry response header.")
                    }
                    return (requestURI, parNonce) // Return URI and Nonce from retry
                } else {
                    // Retry failed
                    let errorDetails = String(data: retryData, encoding: .utf8) ?? "No details"
                    LogManager.logError(
                        "Sign-Up PAR retry failed with status code \(retryHttpResponse.statusCode). Response: \(errorDetails)"
                    )
                    throw AuthError.authorizationFailed // Indicate PAR failure
                }
            } else {
                // Non-retryable 400 error
                let errorDetails = String(data: data, encoding: .utf8) ?? "No details"
                LogManager.logError(
                    "Sign-Up PAR failed with status code 400 (Non-retryable). Response: \(errorDetails)")
                throw AuthError.authorizationFailed // Indicate PAR failure
            }
        }
        // Handle other non-2xx, non-400 status codes
        else {
            let errorDetails = String(data: data, encoding: .utf8) ?? "No details"
            LogManager.logError(
                "Sign-Up PAR failed with status code \(httpResponse.statusCode). Response: \(errorDetails)"
            )
            throw AuthError.authorizationFailed // Indicate PAR failure
        }
    }

    // MARK: - Token Management

    /// Indicates whether authentication tokens exist for the current account.
    /// - Returns: True if tokens exist, false otherwise.
    func tokensExist() async -> Bool {
        guard let account = await accountManager.getCurrentAccount(),
              let session = try? await storage.getSession(for: account.did)
        else {
            return false
        }

        return session.accessToken.isEmpty == false
    }

    /// Refreshes the authentication token if needed.
    /// - Parameter forceRefresh: If true, forces a refresh regardless of calculated expiry time
    /// - Returns: Result indicating whether token was refreshed, still valid, or skipped
    func refreshTokenIfNeeded(forceRefresh: Bool = false) async throws -> TokenRefreshResult {
        // Get current account and session
        guard let account = await accountManager.getCurrentAccount(),
              let session = try? await storage.getSession(for: account.did)
        else {
            throw AuthError.noActiveAccount
        }

        let did = account.did

        // Check circuit breaker first
        guard await refreshCircuitBreaker.canAttemptRefresh(for: did) else {
            LogManager.logError(
                "RefreshCircuitBreaker: Circuit is OPEN for DID \(LogManager.logDID(did)). Refusing refresh attempt.",
                category: .authentication
            )
            throw AuthError.tokenRefreshFailed
        }

        // Smart rate limiting check
        let now = Date()

        // Check if we recently had a successful refresh
        if let lastSuccess = lastSuccessfulRefresh[did] {
            let timeSinceSuccess = now.timeIntervalSince(lastSuccess)
            if timeSinceSuccess < minimumRefreshIntervalAfterSuccess && !forceRefresh {
                LogManager.logDebug(
                    "Token was successfully refreshed \(timeSinceSuccess)s ago for DID \(LogManager.logDID(did)). Skipping refresh (minimum interval after success: \(minimumRefreshIntervalAfterSuccess)s).",
                    category: .authentication
                )
                return .stillValid // Token was recently refreshed
            }
        }

        // Check minimum interval between attempts
        if let lastAttempt = lastRefreshAttempt[did] {
            let timeSinceLastAttempt = now.timeIntervalSince(lastAttempt)
            if timeSinceLastAttempt < minimumRefreshInterval {
                if forceRefresh {
                    // For forced refresh (e.g., 401 handling), wait just enough to honor the minimum interval,
                    // then proceed. This prevents immediate failures while still avoiding tight retry loops.
                    let waitSeconds = minimumRefreshInterval - timeSinceLastAttempt
                    LogManager.logDebug(
                        "Forced refresh requested \(String(format: "%.3f", timeSinceLastAttempt))s after last attempt for DID \(LogManager.logDID(did)). Waiting \(String(format: "%.3f", waitSeconds))s to avoid thrash.",
                        category: .authentication
                    )
                    try? await Task.sleep(nanoseconds: UInt64(max(0, waitSeconds) * 1_000_000_000))
                } else {
                    LogManager.logDebug(
                        "Token refresh attempted too soon for DID \(LogManager.logDID(did)). Last attempt was \(timeSinceLastAttempt)s ago. Minimum interval is \(minimumRefreshInterval)s.",
                        category: .authentication
                    )
                    // Don't count this as a failure - just skip it
                    return .skippedDueToRateLimit // Signal that we skipped due to rate limiting
                }
            }
        }

        // DON'T record attempt time here - only after successful refresh
        // This prevents race conditions where parallel requests see an attempt
        // but the refresh hasn't actually completed yet

        // Log token lifecycle event
        LogManager.logInfo(
            "🔄 TOKEN_LIFECYCLE: Refresh attempt started for DID \(LogManager.logDID(did)) "
                + "(force=\(forceRefresh), session_expires_soon=\(session.isExpiringSoon), "
                + "expires_in=\(Int(session.expiresIn))s, created=\(Int(Date().timeIntervalSince(session.createdAt)))s ago)",
            category: .authentication
        )
        LogManager.logInfo("METRIC token_refresh_attempts_total did=\(LogManager.logDID(did))")

        // Validate current token state before proceeding
        guard validateTokenState(session) else {
            LogManager.logError(
                "Token state validation failed for DID \(LogManager.logDID(did)). Token appears corrupted.",
                category: .authentication
            )
            // Record failure and attempt cleanup
            await refreshCircuitBreaker.recordFailure(for: did)
            try await logout() // Clean up corrupted state
            throw AuthError.tokenRefreshFailed
        }

        // Check if token is still valid (restore this check to avoid unnecessary refreshes)
        if !forceRefresh && !session.isExpiringSoon {
            LogManager.logDebug("Token for DID: \(did) is not expiring soon, skipping refresh")
            // Record this as a successful "refresh" (token is still valid)
            lastSuccessfulRefresh[did] = Date()
            await refreshCircuitBreaker.recordSuccess(for: did)
            return .stillValid // Token is still valid
        }

        if forceRefresh {
            LogManager.logInfo("🔄 Force refresh requested - bypassing expiry check for DID: \(did)")
        }

        // Set in-progress flag to handle app termination during refresh
        // This helps detect and recover from incomplete refresh operations
        try await markRefreshInProgress(for: did, inProgress: true)

        // Use the coordinator to prevent concurrent refreshes
        do {
            // The coordinator expects a function returning the raw response data and response object
            let (refreshData, _): (Data, HTTPURLResponse) =
                try await refreshCoordinator.coordinateRefresh(
                    performing: { () async throws -> (Data, HTTPURLResponse) in
                        // Perform the token refresh call
                        let (data, response) = try await self.performTokenRefresh(for: account.did)

                        // Return the raw response - the coordinator will handle type checking
                        return (data, response)
                    }
                )
            // Decode the refresh result from the data
            let decoder = JSONDecoder()
            let tokenResponse = try decoder.decode(TokenResponse.self, from: refreshData)

            // Save the new session details from the successful refresh with clock skew protection
            let adjustedExpiresIn = applyClockSkewProtection(to: tokenResponse.expiresIn)
            let newSession = Session(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                createdAt: Date(), // Use current time as the refresh time
                expiresIn: adjustedExpiresIn,
                tokenType: session.tokenType, // Assume token type doesn't change on refresh
                did: account.did
            )

            // Save session with enhanced validation
            guard try await saveAndVerifySession(newSession, for: account.did) else {
                LogManager.logError("Token storage and verification failed for DID: \(account.did)")
                throw AuthError.tokenRefreshFailed
            }

            // Clear the in-progress flag only after successful save and verification
            try await markRefreshInProgress(for: account.did, inProgress: false)

            // Record success with circuit breaker
            await refreshCircuitBreaker.recordSuccess(for: account.did)

            // Record successful refresh time AND attempt time
            let now = Date()
            lastSuccessfulRefresh[account.did] = now
            lastRefreshAttempt[account.did] = now

            // Log successful token lifecycle event
            LogManager.logInfo(
                "✅ TOKEN_LIFECYCLE: Refresh completed successfully for DID \(LogManager.logDID(account.did)) "
                    + "(new_expires_in=\(Int(adjustedExpiresIn))s, token_type=\(session.tokenType.rawValue))",
                category: .authentication
            )
            LogManager.logInfo("METRIC token_refresh_success_total did=\(LogManager.logDID(account.did))")
            return .refreshedSuccessfully // Indicate actual refresh happened

        } catch let error as TokenRefreshCoordinator.RefreshError {
            // Clear in-progress flag regardless of error type
            try? await markRefreshInProgress(for: account.did, inProgress: false)

            switch error {
            case let .invalidGrant(description):
                // If an ambiguous timeout occurred recently, keep current access token and defer logout
                if let until = ambiguousRefreshUntil[did], until > Date(),
                   let session = try? await storage.getSession(for: did)
                {
                    let stillValid = Date() < session.createdAt.addingTimeInterval(session.expiresIn)
                    if stillValid {
                        LogManager.logInfo(
                            "METRIC invalid_grant_after_timeout_total did=\(LogManager.logDID(did))")
                        LogManager.logError(
                            "invalid_grant after ambiguous timeout for DID \(LogManager.logDID(account.did)); keeping current access token and deferring logout",
                            category: .authentication
                        )
                        return .stillValid
                    }
                }
                await refreshCircuitBreaker.recordFailure(for: did, kind: .invalidGrant)
                LogManager.logError(
                    "❌ TOKEN_LIFECYCLE: Refresh failed with invalid_grant for DID \(LogManager.logDID(account.did)): "
                        + "\(description ?? "No details"). Triggering automatic logout.",
                    category: .authentication
                )
                LogManager.logInfo(
                    "METRIC token_refresh_failures_total reason=invalid_grant did=\(LogManager.logDID(did))")
                // The refresh token is invalid, trigger logout
                try await logout() // Perform full logout to clear state
                throw AuthError.tokenRefreshFailed // Throw instead of returning
            case let .dpopError(description):
                await refreshCircuitBreaker.recordFailure(for: did, kind: .nonceRecoverable)
                // Treat any DPoP error as potentially recoverable with a one-time immediate retry
                LogManager.logError(
                    "Token refresh failed due to DPoP error for DID \(account.did): \(description ?? "No details"). Attempting one immediate retry."
                )

                do {
                    let (retryData, retryResponse) = try await performTokenRefresh(for: account.did)
                    if (200 ..< 300).contains(retryResponse.statusCode) {
                        let decoder = JSONDecoder()
                        let tokenResponse = try decoder.decode(TokenResponse.self, from: retryData)

                        let adjustedExpiresIn = applyClockSkewProtection(to: tokenResponse.expiresIn)
                        let newSession = Session(
                            accessToken: tokenResponse.accessToken,
                            refreshToken: tokenResponse.refreshToken,
                            createdAt: Date(),
                            expiresIn: adjustedExpiresIn,
                            tokenType: session.tokenType,
                            did: account.did
                        )
                        try await storage.saveSession(newSession, for: account.did)

                        guard let savedSession = try await storage.getSession(for: account.did),
                              savedSession.refreshToken == tokenResponse.refreshToken
                        else {
                            throw AuthError.tokenRefreshFailed
                        }

                        LogManager.logInfo(
                            "Successfully recovered from DPoP error via immediate retry for DID: \(account.did)")
                        return .refreshedSuccessfully
                    }
                } catch {
                    LogManager.logError("Immediate DPoP recovery attempt failed: \(error)")
                }

                // If we reach here, all attempts have failed
                LogManager.logInfo(
                    "METRIC token_refresh_failures_total reason=dpop did=\(LogManager.logDID(did))")
                throw AuthError.dpopKeyError
            case let .networkError(code, details):
                await refreshCircuitBreaker.recordFailure(for: did, kind: .network)
                LogManager.logError(
                    "Token refresh failed due to network error (\(code)) for DID \(account.did): \(details ?? "No details")"
                )
                LogManager.logInfo(
                    "METRIC token_refresh_failures_total reason=network did=\(LogManager.logDID(did))")
                // Logged details above, throw a general error for the caller
                throw AuthError.tokenRefreshFailed
            case let .decodingError(underlyingError, context):
                await refreshCircuitBreaker.recordFailure(for: did, kind: .server)
                LogManager.logError(
                    "Token refresh failed due to decoding error for DID \(account.did): \(underlyingError), context: \(context ?? "none")"
                )
                LogManager.logInfo(
                    "METRIC token_refresh_failures_total reason=decoding did=\(LogManager.logDID(did))")
                throw AuthError.invalidResponse // Map to invalid response
            case .alreadyInProgress, .invalidState, .refreshTooFrequent:
                // These are coordinator internal states, shouldn't typically escape unless there's a logic error.
                LogManager.logInfo("Token refresh coordinator encountered state: \(error)") // Use logInfo instead of logWarning
                throw AuthError.tokenRefreshFailed // Treat as general failure
            case let .refreshFunctionError(error):
                throw error
            }
        } catch {
            // Catch any other errors (e.g., from performTokenRefresh before coordinator call)
            // Ensure we clear the in-progress flag for any unexpected errors
            try? await markRefreshInProgress(for: account.did, inProgress: false)
            await refreshCircuitBreaker.recordFailure(for: did, kind: .other)
            LogManager.logInfo(
                "METRIC token_refresh_failures_total reason=other did=\(LogManager.logDID(did))")

            LogManager.logError(
                "Token refresh failed with unexpected error for DID \(account.did): \(error)")
            throw AuthError.tokenRefreshFailed // General refresh failure
        }
    }

    /// Refreshes the authentication token if needed (overload without forceRefresh parameter).
    /// - Returns: Result indicating whether token was refreshed, still valid, or skipped
    func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
        return try await refreshTokenIfNeeded(forceRefresh: false)
    }

    /// Helper method to mark a refresh operation as in progress
    /// This helps detect and recover from interrupted refreshes
    /// - Parameters:
    ///   - did: The DID associated with the refresh
    ///   - inProgress: Whether the refresh is in progress
    private func markRefreshInProgress(for did: String, inProgress: Bool) async throws {
        let key = "refresh.inProgress.\(did)"
        if inProgress {
            // Mark refresh as in progress
            try KeychainManager.store(key: key, value: Data([1]), namespace: storage.namespace)
            LogManager.logDebug("Marked refresh operation as in-progress for DID: \(did)")
        } else {
            // Clear refresh in progress flag
            try KeychainManager.delete(key: key, namespace: storage.namespace)
            LogManager.logDebug("Cleared refresh in-progress flag for DID: \(did)")
        }
    }

    /// Checks if a refresh operation was interrupted by app termination
    /// - Parameter did: The DID to check
    /// - Returns: True if a refresh operation is in progress
    private func isRefreshInProgress(for did: String) async -> Bool {
        let key = "refresh.inProgress.\(did)"
        do {
            let data = try KeychainManager.retrieve(key: key, namespace: storage.namespace)
            return data.count > 0 && data[0] == 1
        } catch {
            return false
        }
    }

    /// Handles app startup to detect interrupted refresh operations
    /// Call this method during app initialization
    func handleAppStartup() async {
        // Get current account
        guard let account = await accountManager.getCurrentAccount() else {
            return
        }

        // Check if a refresh operation was interrupted
        if await isRefreshInProgress(for: account.did) {
            LogManager.logError("Detected interrupted refresh operation for DID: \(account.did)")

            // Force a token refresh to get a fresh token
            do {
                let result = try await refreshTokenIfNeeded()
                if result == .refreshedSuccessfully {
                    LogManager.logInfo("Successfully recovered from interrupted refresh operation")
                } else {
                    LogManager.logInfo("Recovery attempted but token was already valid or skipped")
                }
            } catch {
                LogManager.logError("Failed to recover from interrupted refresh: \(error)")
                // Consider further recovery steps here
            }
        }
    }

    /// Performs the actual token refresh operation.
    /// - Parameter did: The DID to refresh tokens for.
    /// - Returns: A tuple containing the response Data and HTTPURLResponse.
    /// - Throws: An error if the refresh fails.
    private func performTokenRefresh(for did: String) async throws -> (Data, HTTPURLResponse) {
        // Try up to 2 times to handle nonce mismatch
        return try await performTokenRefreshWithRetry(for: did, retryCount: 0)
    }

    /// Internal helper that performs token refresh with retry logic for DPoP nonce errors
    /// - Parameters:
    ///   - did: The DID to refresh tokens for
    ///   - retryCount: Current retry attempt (max 1)
    /// - Returns: The response data and HTTP response
    private func performTokenRefreshWithRetry(for did: String, retryCount: Int) async throws -> (
        Data, HTTPURLResponse
    ) {
        // Limit retries to prevent infinite loops
        guard retryCount <= 1 else {
            LogManager.logError("performTokenRefresh: Too many retry attempts for DID: \(did)")
            throw AuthError.tokenRefreshFailed
        }

        // Get the session
        guard let session = try? await storage.getSession(for: did),
              let refreshToken = session.refreshToken
        else {
            LogManager.logError("performTokenRefresh: No session or refresh token found for DID \(did)")
            throw AuthError.tokenRefreshFailed // Indicate failure
        }

        // Get the account
        guard let account = await accountManager.getAccount(did: did),
              let authServerMetadata = account.authorizationServerMetadata
        else {
            LogManager.logError(
                "performTokenRefresh: Could not retrieve account or metadata for DID \(did)")
            throw AuthError.tokenRefreshFailed // Indicate failure
        }

        // Prepare refresh token request
        let tokenEndpoint = authServerMetadata.tokenEndpoint
        guard let endpointURL = URL(string: tokenEndpoint) else {
            LogManager.logError("performTokenRefresh: Invalid token endpoint URL")
            throw AuthError.tokenRefreshFailed
        }

        // Determine the intended audience/resource for this token per RFC 8707.
        // Prefer a one-shot override if provided (set upon detecting invalid audience),
        // otherwise use protected resource metadata value; fall back to the PDS base URL.
        var resourceValue: String? = nil
        if let override = nextRefreshResourceOverride, !override.isEmpty {
            resourceValue = override
            // Clear the override immediately to keep it one-shot
            nextRefreshResourceOverride = nil
            LogManager.logInfo("Using one-shot resource override for refresh: \(resourceValue!)")
        } else if let prm = account.protectedResourceMetadata {
            resourceValue = prm.resource.absoluteString
        } else {
            resourceValue = account.pdsURL.absoluteString
        }

        var requestBody: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": oauthConfig.clientId,
        ]
        if let resourceValue {
            requestBody["resource"] = resourceValue
            LogManager.logInfo("Including OAuth resource parameter for refresh: \(resourceValue)")
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = encodeFormData(requestBody)
        // Increase timeout for token endpoint to reduce ambiguous rotations on slow networks
        request.timeoutInterval = 30.0

        // Get the domain for nonce lookup
        _ = endpointURL.host?.lowercased() ?? ""

        // Add DPoP proof
        let dpopProof = try await createDPoPProof(
            for: "POST",
            url: tokenEndpoint,
            type: .tokenRefresh,
            did: did
        )
        request.setValue(dpopProof, forHTTPHeaderField: "DPoP")

        // Perform the request
        do {
            let (data, response) = try await networkService.request(request)

            guard let httpResponse = response as? HTTPURLResponse else {
                LogManager.logError(
                    "AuthenticationService - Token refresh response was not HTTPURLResponse")
                throw AuthError.invalidResponse
            }

            // Immediately handle DPoP nonce update to ensure it's captured regardless of response status
            if let newNonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce"),
               let url = httpResponse.url,
               let responseDomain = url.host?.lowercased()
            {
                await updateDPoPNonce(domain: responseDomain, nonce: newNonce, for: did)
                LogManager.logDebug(
                    "Updated DPoP nonce for domain \(responseDomain) after token refresh attempt")
            }

            // Log status without exposing sensitive token data
            LogManager.logDebug(
                "Token refresh response received (\(data.count) bytes)", category: .authentication
            )

            // Check for DPoP nonce mismatch and retry
            if httpResponse.statusCode == 400 {
                // Attempt to decode the error
                do {
                    let errorResponse = try JSONDecoder().decode(OAuthErrorResponse.self, from: data)

                    // Check specifically for DPoP nonce error
                    if errorResponse.error == "use_dpop_nonce", retryCount == 0 {
                        LogManager.logInfo(
                            "Detected DPoP nonce mismatch during token refresh. Will retry with updated nonce.")
                        LogManager.logInfo(
                            "METRIC dpop_nonce_retry_total origin=auth did=\(LogManager.logDID(did))")

                        // CRITICAL FIX: Ensure we use the most recent nonce for retry
                        // Atomically update and verify nonce synchronization before retry
                        var shouldRetry = false
                        if let refreshedNonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce"),
                           let url = httpResponse.url,
                           let responseDomain = url.host?.lowercased() {
                            
                            // Update and verify nonce synchronization atomically
                            let nonceUpdateSuccess = await updateAndVerifyNonce(
                                domain: responseDomain,
                                nonce: refreshedNonce,
                                did: did
                            )
                            
                            if nonceUpdateSuccess {
                                shouldRetry = true
                                LogManager.logDebug(
                                    "Successfully synchronized nonce for retry: domain=\(responseDomain), nonce=\(refreshedNonce)")
                            } else {
                                LogManager.logError(
                                    "Failed to synchronize nonce for retry. Aborting retry attempt to prevent loop.")
                            }
                        } else {
                            LogManager.logError(
                                "Missing DPoP-Nonce header in error response. Cannot retry safely.")
                        }
                        
                        // Only retry if nonce synchronization was successful
                        if shouldRetry {
                            return try await performTokenRefreshWithRetry(for: did, retryCount: retryCount + 1)
                        }
                        // If we can't sync nonces safely, fall through to normal error handling
                    }
                } catch {
                    // If we can't decode the error, just continue with normal error handling
                    LogManager.logDebug("Could not decode error response: \(error)")
                }
            }

            // Verify successful responses can be decoded
            if (200 ... 299).contains(httpResponse.statusCode) {
                do {
                    let decoder = JSONDecoder()
                    let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
                    // Validation that we received expected fields
                    guard !tokenResponse.accessToken.isEmpty, !tokenResponse.refreshToken.isEmpty else {
                        LogManager.logError("Token refresh succeeded but received empty tokens")
                        throw AuthError.invalidResponse
                    }

                    // Add detailed token refresh expiry logging for debugging
                    let tokenCreatedAt = Date()
                    let serverExpiresIn = TimeInterval(tokenResponse.expiresIn)
                    let calculatedExpiry = tokenCreatedAt.addingTimeInterval(serverExpiresIn)
                    LogManager.logInfo(
                        "🔄 Token Refresh Success - Server expires_in: \(tokenResponse.expiresIn)s, Created: \(tokenCreatedAt), Calculated expiry: \(calculatedExpiry)"
                    )
                    LogManager.logDebug(
                        "Successfully decoded token response with expiration in \(tokenResponse.expiresIn) seconds"
                    )
                } catch {
                    LogManager.logError("Failed to decode successful token response: \(error)")
                    // Allow to continue since coordinator will also try to decode and handle errors
                }
            }

            // Return the raw data and response for the coordinator to handle
            return (data, httpResponse)
        } catch let urlErr as URLError {
            // Timed out at token endpoint — ambiguous outcome: server may have rotated tokens
            if urlErr.code == .timedOut {
                ambiguousRefreshUntil[did] = Date().addingTimeInterval(900) // 15 minutes TTL
                LogManager.logInfo("METRIC ambiguous_refresh_timeout_total did=\(LogManager.logDID(did))")
            }
            LogManager.logError("AuthenticationService - Token refresh network request failed: \(urlErr)")
            throw AuthError.tokenRefreshFailed
        } catch {
            LogManager.logError("AuthenticationService - Token refresh network request failed: \(error)")
            throw AuthError.tokenRefreshFailed
        }
    }

    // MARK: - Request Authentication

    /// Prepares an authenticated request by adding necessary authentication headers.
    /// - Parameter request: The original request to authenticate.
    /// - Returns: The request with authentication headers added.
    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        guard let account = await accountManager.getCurrentAccount(),
              let session = try? await storage.getSession(for: account.did)
        else {
            // Log the URL that triggered this error for easier debugging
            LogManager.logError(
                "prepareAuthenticatedRequest: No active account for non-auth endpoint: \(request.url?.absoluteString ?? "Unknown URL")"
            )
            throw AuthError.noActiveAccount as Error
        }

        var modifiedRequest = request

        // If refresh is in progress for this DID, wait briefly to avoid transient key access errors
        if await isRefreshInProgress(for: account.did) {
            await waitForRefreshToComplete(did: account.did, timeout: 3.0)
        }

        // If refresh is in progress for this DID, wait briefly to avoid transient key access errors
        if await isRefreshInProgress(for: account.did) {
            await waitForRefreshToComplete(did: account.did, timeout: 3.0)
        }

        // Check if this is a token endpoint request (should be covered by the /oauth/ check above, but keep for safety)
        let isTokenEndpoint =
            account.authorizationServerMetadata?.tokenEndpoint == request.url?.absoluteString

        // Generate DPoP proof using the active session's key
        let urlString = request.url?.absoluteString ?? ""
        let method = request.httpMethod ?? "GET"
        // Determine proof type based on whether it's the token endpoint or general resource access
        let type: DPoPProofType = isTokenEndpoint ? .tokenRequest : .resourceAccess

        let dpopProof = try await createDPoPProof(
            for: method,
            url: urlString,
            type: type,
            accessToken: isTokenEndpoint ? nil : session.accessToken, // Only include ath for resource access
            did: account.did // Use the active account's DID
        )

        // Add DPoP header
        modifiedRequest.setValue(dpopProof, forHTTPHeaderField: "DPoP")

        // Add Authorization header for resource access (not needed for token endpoint requests)
        if !isTokenEndpoint {
            modifiedRequest.setValue("DPoP \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        return modifiedRequest
    }

    // New API: prepare request and return auth context (DID + JKT) to prevent cross-account/key contamination
    func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (
        URLRequest, AuthContext
    ) {
        guard let account = await accountManager.getCurrentAccount(),
              let session = try? await storage.getSession(for: account.did)
        else {
            LogManager.logError(
                "prepareAuthenticatedRequestWithContext: No active account for non-auth endpoint: \(request.url?.absoluteString ?? "Unknown URL")"
            )
            throw AuthError.noActiveAccount as Error
        }

        var modifiedRequest = request

        let isTokenEndpoint =
            account.authorizationServerMetadata?.tokenEndpoint == request.url?.absoluteString

        let urlString = request.url?.absoluteString ?? ""
        let method = request.httpMethod ?? "GET"
        let type: DPoPProofType = isTokenEndpoint ? .tokenRequest : .resourceAccess

        // Compute JKT for the DID's key
        let key = try await getOrCreateDPoPKey(for: account.did)
        let jwk = try createJWK(from: key)
        let thumbprint = try calculateJWKThumbprint(jwk: jwk)

        // Generate DPoP proof using DID (so nonce lookup uses persisted DID mapping)
        let dpopProof = try await createDPoPProof(
            for: method,
            url: urlString,
            type: type,
            accessToken: isTokenEndpoint ? nil : session.accessToken,
            did: account.did
        )

        modifiedRequest.setValue(dpopProof, forHTTPHeaderField: "DPoP")
        if !isTokenEndpoint {
            modifiedRequest.setValue("DPoP \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let context = AuthContext(did: account.did, jkt: thumbprint)
        return (modifiedRequest, context)
    }

    // MARK: - DPoP Functionality

    /// Creates a DPoP proof for authentication.
    /// - Parameters:
    ///   - method: The HTTP method of the request.
    ///   - url: The URL of the request.
    ///   - type: The type of DPoP proof to create.
    ///   - accessToken: The access token to include in the proof (for resource access).
    ///   - did: The DID to create the proof for (optional, overrides current account).
    ///   - ephemeralKey: An optional ephemeral key to use instead of the account's key.
    /// - Returns: A DPoP proof string.
    private func createDPoPProof(
        for method: String,
        url: String,
        type: DPoPProofType,
        accessToken: String? = nil,
        did: String? = nil,
        ephemeralKey: P256.Signing.PrivateKey? = nil, // Added ephemeralKey parameter
        nonce: String? = nil // Added nonce parameter
    ) async throws -> String {
        let targetDID: String?
        if did == nil {
            targetDID = await accountManager.getCurrentAccount()?.did
        } else {
            targetDID = did
        }

        let privateKey: P256.Signing.PrivateKey

        if let key = ephemeralKey {
            privateKey = key
        } else if let currentDID = targetDID {
            privateKey = try await getOrCreateDPoPKey(for: currentDID)
        } else {
            // Only throw noActiveAccount if no ephemeral key was provided AND no active account exists
            LogManager.logError(
                "DPoP Proof creation failed: No active account (targetDID: \(targetDID ?? "nil")) and no ephemeral key provided. Context: method=\(method), url=\(url), type=\(type)"
            )
            throw AuthError.noActiveAccount as Error
        }

        // Create JWK from the determined private key
        let jwk = try createJWK(from: privateKey)
        let keyThumbprint = try calculateJWKThumbprint(jwk: jwk) // Needed for token requests and JKT-scoped nonce lookup

        // Prepare DPoP payload
        _ = UUID().uuidString
        _ = Int(Date().timeIntervalSince1970)
        var ath: String? = nil

        if type == .resourceAccess, let token = accessToken {
            ath = calculateATH(from: token)
        }

        // Fetch nonce if needed (e.g., from headers or stored)
        // Use provided nonce if available, otherwise use stored nonce
        let finalNonce: String?
        if let explicitNonce = nonce { // Prioritize explicitly passed nonce for retries
            finalNonce = explicitNonce
        }
        // Case 2: OAuth flow (no DID, using ephemeral key) - check in-memory store
        else if did == nil && ephemeralKey != nil, let urlObject = URL(string: url),
                let domain = urlObject.host?.lowercased()
        {
            finalNonce = oauthFlowNonces[domain]
            LogManager.logDebug(
                "OAuth flow - using stored nonce for domain \(domain)", category: .authentication
            )
        }
        // Case 3: Authenticated flow - get from storage with robust synchronization
        else if let targetDID = targetDID, let urlObject = URL(string: url),
                let domain = urlObject.host?.lowercased()
        {
            // Always refresh JKT-scoped nonces from persistence to ensure consistency
            if let persistedByJKT = try? await storage.getDPoPNoncesByJKT(for: targetDID) {
                // Merge persisted JKT maps into memory, with persistence taking precedence
                for (pjkt, map) in persistedByJKT {
                    var existing = noncesByThumbprint[pjkt] ?? [:]
                    existing.merge(map) { _, new in new } // Persistent values win
                    noncesByThumbprint[pjkt] = existing
                }
            }
            
            // Multi-layer nonce retrieval with preference order:
            // 1. JKT-scoped in-memory (most recent)
            // 2. JKT-scoped persistent (cross-restart)
            // 3. DID-scoped persistent (fallback)
            if let jktNonce = noncesByThumbprint[keyThumbprint]?[domain] {
                finalNonce = jktNonce
                LogManager.logDebug("Using JKT-scoped in-memory nonce for domain \(domain)")
            } else if let persistedJktNonces = try? await storage.getDPoPNoncesByJKT(for: targetDID),
                      let jktPersistentNonce = persistedJktNonces[keyThumbprint]?[domain] {
                finalNonce = jktPersistentNonce
                LogManager.logDebug("Using JKT-scoped persistent nonce for domain \(domain)")
            } else if let storedNonces = try? await storage.getDPoPNonces(for: targetDID),
                      let didNonce = storedNonces[domain] {
                finalNonce = didNonce
                LogManager.logDebug("Using DID-scoped persistent nonce for domain \(domain)")
            } else {
                finalNonce = nil
                LogManager.logDebug("No nonce found for domain \(domain)")
            }
        } else {
            // No explicit nonce, using ephemeral key or couldn't get stored nonce
            finalNonce = nil
        }

        LogManager.logDebug(
            "DPoP proof nonce status: \(finalNonce != nil ? "present" : "none") for domain \(URL(string: url)?.host?.lowercased() ?? "N/A") (jkt=\(keyThumbprint))",
            category: .authentication
        )

        // Canonicalize the HTU per spec (lowercase scheme/host, drop default ports, keep query, drop fragment)
        let htuValue: String
        if let urlObj = URL(string: url) {
            htuValue = canonicalHTU(urlObj)
        } else {
            htuValue = url
        }

        // Create the encodable payload struct
        let payload = DPoPPayload(
            jti: "\(UUID().uuidString)-\(UInt64.random(in: 0 ... UInt64.max))", // Strong unique JTI
            htm: method,
            htu: htuValue,
            iat: Int(Date().timeIntervalSince1970),
            exp: Int(Date().timeIntervalSince1970) + 120, // short TTL (120s)
            ath: ath,
            nonce: finalNonce // Use the determined nonce
        )
        // --- End Prepare Payload ---

        // Create JWT payload data
        let jwtPayloadData = try JSONEncoder().encode(payload) // Encode the struct

        // Define the JWS header
        let header = DefaultJWSHeaderImpl(
            algorithm: .ES256,
            jwk: jwk, type: "dpop+jwt"
        )
        // Create header data
        let headerData = try JSONEncoder().encode(header)
        let headerBase64 = headerData.base64URLEscaped()

        // Create signing input
        let signingInput = "\(headerBase64).\(base64URLEncode(jwtPayloadData))"
        let signatureData = try privateKey.signature(for: Data(signingInput.utf8))
        let signatureBase64 = base64URLEncode(signatureData.rawRepresentation) // Convert signature to Data

        // Final compact serialization
        let jws = "\(headerBase64).\(base64URLEncode(jwtPayloadData)).\(signatureBase64)"
        return jws
    }

    /// Gets or creates a DPoP key for the specified DID.
    /// - Parameter did: The DID to get or create a key for.
    /// - Returns: The DPoP private key.
    private func getOrCreateDPoPKey(for did: String) async throws -> P256.Signing.PrivateKey {
        // Try to get existing key
        if let existingKey = try? await storage.getDPoPKey(for: did) {
            return existingKey
        }

        // Create a new key
        let newKey = P256.Signing.PrivateKey()
        try await storage.saveDPoPKey(newKey, for: did)
        return newKey
    }

    /// Waits for an in-progress refresh to complete (bounded) to avoid transient key/nonce errors for callers
    private func waitForRefreshToComplete(did: String, timeout: TimeInterval) async {
        let start = Date()
        while await isRefreshInProgress(for: did) {
            if Date().timeIntervalSince(start) > timeout { break }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }

    // Canonicalize URL for DPoP htu claim: lowercase scheme/host, drop default ports, ensure path, keep query, drop fragment
    private func canonicalHTU(_ url: URL) -> String {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        comps.scheme = comps.scheme?.lowercased()
        comps.host = comps.host?.lowercased()
        if (comps.scheme == "https" && comps.port == 443)
            || (comps.scheme == "http" && comps.port == 80)
        {
            comps.port = nil
        }
        if comps.path.isEmpty { comps.path = "/" }
        comps.fragment = nil
        return comps.string ?? url.absoluteString
    }

    /// Updates the DPoP nonce for a domain.
    /// - Parameters:
    ///   - domain: The domain the nonce is for.
    ///   - nonce: The new nonce value.
    ///   - did: The DID to update the nonce for.
    private func updateDPoPNonce(domain: String, nonce: String, for did: String) async {
        do {
            LogManager.logDebug(
                "Storing DPoP nonce for domain '\(domain)' for DID", category: .authentication
            )
            var nonces = try await storage.getDPoPNonces(for: did) ?? [:]
            nonces[domain] = nonce
            try await storage.saveDPoPNonces(nonces, for: did)
        } catch {
            LogManager.logError("AuthenticationService - Failed to update DPoP nonce: \(error)")
        }
    }
    
    /// Atomically updates and verifies nonce synchronization across all storage layers
    /// - Parameters:
    ///   - domain: The domain the nonce is for
    ///   - nonce: The new nonce value
    ///   - did: The DID to update the nonce for
    /// - Returns: True if nonce was successfully synchronized and verified, false otherwise
    private func updateAndVerifyNonce(domain: String, nonce: String, did: String) async -> Bool {
        do {
            // Get the key and thumbprint for JKT-scoped storage
            let key = try await getOrCreateDPoPKey(for: did)
            let jwk = try createJWK(from: key)
            let thumbprint = try calculateJWKThumbprint(jwk: jwk)
            
            // 1. Update in-memory JKT-scoped nonce store
            var domainMap = noncesByThumbprint[thumbprint] ?? [:]
            domainMap[domain] = nonce
            noncesByThumbprint[thumbprint] = domainMap
            
            // 2. Update persistent DID-scoped nonce store
            var didNonces = try await storage.getDPoPNonces(for: did) ?? [:]
            didNonces[domain] = nonce
            try await storage.saveDPoPNonces(didNonces, for: did)
            
            // 3. Update persistent JKT-scoped nonce store
            var jktNonces = (try? await storage.getDPoPNoncesByJKT(for: did)) ?? [:]
            var jktDomainMap = jktNonces[thumbprint] ?? [:]
            jktDomainMap[domain] = nonce
            jktNonces[thumbprint] = jktDomainMap
            try await storage.saveDPoPNoncesByJKT(jktNonces, for: did)
            
            // 4. Verify synchronization by reading back from all stores
            let verifyInMemory = noncesByThumbprint[thumbprint]?[domain] == nonce
            let verifyDidPersistent = (try? await storage.getDPoPNonces(for: did))?[domain] == nonce
            let verifyJktPersistent = (try? await storage.getDPoPNoncesByJKT(for: did))?[thumbprint]?[domain] == nonce
            
            let allSynchronized = verifyInMemory && verifyDidPersistent && verifyJktPersistent
            
            if allSynchronized {
                LogManager.logDebug(
                    "Nonce synchronization verified: domain=\(domain), did=\(LogManager.logDID(did)), jkt=\(thumbprint)")
            } else {
                LogManager.logError(
                    "Nonce synchronization failed: memory=\(verifyInMemory), did_persistent=\(verifyDidPersistent), jkt_persistent=\(verifyJktPersistent)")
            }
            
            return allSynchronized
            
        } catch {
            LogManager.logError("Failed to update and verify nonce: \(error)")
            return false
        }
    }

    // MARK: - Helper Methods

    /// Validates the integrity and consistency of a token session
    /// - Parameter session: The session to validate
    /// - Returns: True if the session is valid, false if corrupted
    /// - Note: All tokens (access and refresh) MUST be treated as opaque tokens.
    ///         Do NOT attempt to parse or validate their internal structure.
    private func validateTokenState(_ session: Session) -> Bool {
        // Basic presence checks - tokens must exist but are treated as opaque
        guard !session.accessToken.isEmpty,
              let refreshToken = session.refreshToken, !refreshToken.isEmpty
        else {
            LogManager.logError("Token validation failed: Empty tokens detected")
            return false
        }

        // IMPORTANT: Do NOT validate token format or structure
        // Both access tokens and refresh tokens are opaque and their format
        // is implementation-specific to the authorization server

        // Timestamp validation
        if session.createdAt > Date() {
            LogManager.logError("Token validation failed: Created timestamp is in the future")
            return false
        }

        // Expiry validation
        if session.expiresIn <= 0 {
            LogManager.logError("Token validation failed: Invalid expiry time")
            return false
        }

        // DID format validation
        if !session.did.hasPrefix("did:") {
            LogManager.logError("Token validation failed: Invalid DID format")
            return false
        }

        return true
    }

    /// Enhanced token state validation with transaction-like save verification
    /// - Parameters:
    ///   - newSession: The session to save
    ///   - did: The DID to save for
    /// - Returns: True if save was successful and verified
    /// - Note: Tokens are treated as opaque and only validated for presence, not format
    private func saveAndVerifySession(_ newSession: Session, for did: String) async throws -> Bool {
        // Validate session before saving
        guard validateTokenState(newSession) else {
            LogManager.logError(
                "Session validation failed before save for DID: \(LogManager.logDID(did))")
            return false
        }

        // Save session
        try await storage.saveSession(newSession, for: did)

        // Verify the session was saved correctly with all-or-nothing semantics
        guard let savedSession = try await storage.getSession(for: did) else {
            LogManager.logError(
                "Session verification failed: Could not retrieve saved session for DID: \(LogManager.logDID(did))"
            )
            return false
        }

        // Verify critical fields match
        guard savedSession.accessToken == newSession.accessToken,
              savedSession.refreshToken == newSession.refreshToken,
              savedSession.did == newSession.did,
              savedSession.tokenType == newSession.tokenType
        else {
            LogManager.logError(
                "Session verification failed: Saved session does not match expected values for DID: \(LogManager.logDID(did))"
            )
            return false
        }

        // Additional validation on the saved session
        guard validateTokenState(savedSession) else {
            LogManager.logError("Session validation failed after save for DID: \(LogManager.logDID(did))")
            return false
        }

        return true
    }

    /// Applies dynamic clock skew protection to server-provided expiry time
    /// Adjusts expiry time based on token lifetime and observed refresh patterns
    /// - Parameter serverExpiresIn: The expiry time in seconds provided by the server
    /// - Returns: Adjusted expiry time with dynamic safety margin applied
    private func applyClockSkewProtection(to serverExpiresIn: Int) -> TimeInterval {
        let originalExpiry = TimeInterval(serverExpiresIn)

        // Dynamic safety margin based on token lifetime
        let safetyMargin: TimeInterval = {
            if originalExpiry < 900 { // Less than 15 minutes
                // Short-lived tokens: use 20% of total time, minimum 60 seconds
                return max(originalExpiry * 0.2, 60)
            } else if originalExpiry < 3600 { // Less than 1 hour
                // Medium-lived tokens: use 300 seconds (5 minutes)
                return 300
            } else {
                // Long-lived tokens: use 600 seconds (10 minutes)
                return 600
            }
        }()

        // Minimum expiry based on token type
        let minimumExpiry: TimeInterval = {
            if originalExpiry < 900 {
                // For short tokens, ensure at least 5 minutes remain
                return 300
            } else {
                // For longer tokens, ensure at least 10 minutes remain
                return 600
            }
        }()

        let adjustedExpiry = max(originalExpiry - safetyMargin, minimumExpiry)

        // Only log if there's a significant change (more than 30 seconds)
        if abs(adjustedExpiry - originalExpiry) > 30 {
            let marginPercent = Int((safetyMargin / originalExpiry) * 100)
            LogManager.logInfo(
                "🕐 Dynamic clock skew protection: Server expires_in=\(serverExpiresIn)s, "
                    + "margin=\(Int(safetyMargin))s (\(marginPercent)%), adjusted to \(Int(adjustedExpiry))s"
            )
        }

        return adjustedExpiry
    }

    /// Creates a JWK from a private key.
    /// - Parameter privateKey: The private key to use.
    /// - Returns: A JWK.
    private func createJWK(from privateKey: P256.Signing.PrivateKey) throws -> JWK {
        let publicKey = privateKey.publicKey
        let x = publicKey.x963Representation.dropFirst().prefix(32)
        let y = publicKey.x963Representation.suffix(32)

        return JWK(
            keyType: .ellipticCurve,
            curve: .p256,
            x: x,
            y: y
        )
    }

    /// Calculates the ATH claim value for a token.
    /// - Parameter token: The token to hash.
    /// - Returns: The base64url-encoded SHA-256 hash of the token.
    private func calculateATH(from token: String) -> String {
        let tokenData = Data(token.utf8)
        let hash = SHA256.hash(data: tokenData)
        let hashData = Data(hash)
        return base64URLEncode(hashData)
    }

    /// Calculates the JWK thumbprint for a key.
    /// - Parameter jwk: The JWK to calculate the thumbprint for.
    /// - Returns: The base64url-encoded SHA-256 hash of the canonical JWK.
    private func calculateJWKThumbprint(jwk: JWK) throws -> String {
        // Create canonical JWK JSON
        let canonicalJWK: [String: String] = [
            "crv": "P-256",
            "kty": "EC",
            "x": jwk.x?.base64URLEscaped() ?? "",
            "y": jwk.y?.base64URLEscaped() ?? "",
        ]

        let jsonString = """
        {"crv":"P-256","kty":"EC","x":"\(canonicalJWK["x"]!)","y":"\(canonicalJWK["y"]!)"}
        """

        let jsonData = Data(jsonString.utf8)
        let hash = SHA256.hash(data: jsonData)
        return Data(hash).base64URLEscaped()
    }

    /// Generates a random code verifier for PKCE.
    /// - Returns: A base64url-encoded random string.
    private func generateCodeVerifier() -> String {
        let verifierData = Data((0 ..< 32).map { _ in UInt8.random(in: 0 ... 255) })
        return base64URLEncode(verifierData)
    }

    /// Generates a code challenge from a code verifier.
    /// - Parameter verifier: The code verifier.
    /// - Returns: The base64url-encoded SHA-256 hash of the verifier.
    private func generateCodeChallenge(from verifier: String) -> String {
        let verifierData = Data(verifier.utf8)
        let hash = SHA256.hash(data: verifierData)
        return base64URLEncode(Data(hash))
    }

    /// Base64URL-encodes data.
    /// - Parameter data: The data to encode.
    /// - Returns: The base64url-encoded string.
    private func base64URLEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Encodes form data for HTTP requests.
    /// - Parameter params: The parameters to encode.
    /// - Returns: The encoded data.
    private func encodeFormData(_ params: [String: String]) -> Data {
        let queryItems = params.map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue =
                value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }

        return queryItems.joined(separator: "&").data(using: .utf8) ?? Data()
    }

    /// Extracts the authorization code from a callback URL.
    /// - Parameter url: The callback URL.
    /// - Returns: The authorization code if found.
    private func extractAuthorizationCode(from url: URL) -> String? {
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value
    }

    /// Extracts the state from a callback URL.
    /// - Parameter url: The callback URL.
    /// - Returns: The state if found.
    private func extractState(from url: URL) -> String? {
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "state" })?
            .value
    }

    private struct OAuthErrorResponse: Decodable {
        let error: String
        let errorDescription: String?

        enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
        }
    }

    /// Sends a token exchange request with an ephemeral key and optional nonce.
    /// This function handles the specific case where an ephemeral key was used during PAR
    /// and might be required for the token exchange, including handling the `use_dpop_nonce`
    /// error by retrying with the received nonce.
    /// - Parameters:
    ///   - request: The base URLRequest (POST to token endpoint with grant_type=authorization_code, etc.).
    ///              This request should *not* yet have the DPoP header added.
    ///   - tokenEndpoint: The token endpoint URL string.
    ///   - code: The authorization code (needed for logging/debugging, potentially retry context).
    ///   - codeVerifier: The PKCE code verifier (needed for logging/debugging, potentially retry context).
    ///   - key: The ephemeral P256 private key used during PAR, if available from OAuthState.
    ///   - nonce: Optional nonce received from a previous 400 `use_dpop_nonce` response. If nil, this is the first attempt.
    /// - Returns: The decoded TokenResponse upon success.
    /// - Throws: AuthError or NetworkError if the exchange fails after potential retries.
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

        // Create DPoP proof with or without nonce
        let dpopProof = try await createDPoPProof(
            for: "POST",
            url: tokenEndpoint,
            type: .tokenRequest,
            did: nil,
            ephemeralKey: key,
            nonce: nonce,
        )

        request.setValue(dpopProof, forHTTPHeaderField: "DPoP")

        if nonce != nil {
            LogManager.logDebug("Attempting token exchange using ephemeral key WITH nonce in DPoP proof.")
        } else {
            LogManager.logDebug(
                "Attempting token exchange using ephemeral key WITHOUT nonce in DPoP proof.")
        }

        do {
            let (data, urlResponse) = try await networkService.request(request, skipTokenRefresh: true)

            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            // Handle 2xx success
            if (200 ..< 300).contains(httpResponse.statusCode) {
                let decoder = JSONDecoder()
                // Removed snake case conversion since TokenResponse already has custom CodingKeys
                do {
                    let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
                    LogManager.logDebug("Successfully decoded token response.")

                    // Add detailed token expiry logging for debugging
                    let tokenCreatedAt = Date()
                    let serverExpiresIn = TimeInterval(tokenResponse.expiresIn)
                    let calculatedExpiry = tokenCreatedAt.addingTimeInterval(serverExpiresIn)
                    LogManager.logInfo(
                        "🔐 Token Exchange Success - Server expires_in: \(tokenResponse.expiresIn)s, Created: \(tokenCreatedAt), Calculated expiry: \(calculatedExpiry)"
                    )

                    return tokenResponse
                } catch {
                    LogManager.logError("Failed to decode token response: \(error)")
                    // Log the actual response body for debugging
                    _ = String(data: data, encoding: .utf8) ?? "Could not decode response body"
                    LogManager.logError("Token exchange response decode failed", category: .authentication)
                    throw AuthError.invalidResponse
                }
            }
            // Handle 400 error with DPoP nonce - only retry ONCE
            else if httpResponse.statusCode == 400 && nonce == nil {
                let dpopNonceHeader = httpResponse.allHeaderFields["dpop-nonce"] as? String

                // Check if the error is specifically "use_dpop_nonce"
                var isNonceError = false
                do {
                    let errorResponse = try JSONDecoder().decode(OAuthErrorResponse.self, from: data)
                    if errorResponse.error == "use_dpop_nonce" {
                        isNonceError = true
                    }
                } catch {
                    LogManager.logDebug("Could not decode error response")
                }

                if isNonceError, let receivedNonce = dpopNonceHeader {
                    LogManager.logInfo(
                        "Received use_dpop_nonce error on token exchange. Retrying with received nonce",
                        category: .authentication
                    )

                    // Create a new DPoP proof with the nonce
                    let newDpopProof = try await createDPoPProof(
                        for: "POST",
                        url: tokenEndpoint,
                        type: .tokenRequest,
                        did: nil,
                        ephemeralKey: key,
                        nonce: receivedNonce
                    )

                    // Create a new request with the updated DPoP proof
                    var retryRequest = baseRequest
                    retryRequest.setValue(newDpopProof, forHTTPHeaderField: "DPoP")

                    // Make the request
                    let (retryData, retryResponse) = try await networkService.request(
                        retryRequest, skipTokenRefresh: true
                    )

                    guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                        throw NetworkError.invalidResponse
                    }

                    if (200 ..< 300).contains(retryHttpResponse.statusCode) {
                        let decoder = JSONDecoder()
                        let tokenResponse = try decoder.decode(TokenResponse.self, from: retryData)

                        // Add detailed token expiry logging for debugging
                        let tokenCreatedAt = Date()
                        let serverExpiresIn = TimeInterval(tokenResponse.expiresIn)
                        let calculatedExpiry = tokenCreatedAt.addingTimeInterval(serverExpiresIn)
                        LogManager.logInfo(
                            "🔐 Token Exchange Retry Success - Server expires_in: \(tokenResponse.expiresIn)s, Created: \(tokenCreatedAt), Calculated expiry: \(calculatedExpiry)"
                        )

                        return tokenResponse
                    } else {
                        // If retry failed, throw appropriate error
                        let statusCode = retryHttpResponse.statusCode
                        let errorDetails = String(data: retryData, encoding: .utf8) ?? "No details"
                        LogManager.logError(
                            "Token exchange retry failed with status code \(statusCode). Response: \(errorDetails)"
                        )

                        if let oauthError = try? JSONDecoder().decode(OAuthErrorResponse.self, from: retryData) {
                            LogManager.logError(
                                "OAuth Error: \(oauthError.error) - \(oauthError.errorDescription ?? "No description")"
                            )
                        }

                        throw AuthError.tokenRefreshFailed
                    }
                } else {
                    // Non-nonce 400 error
                    let errorDetails = String(data: data, encoding: .utf8) ?? "No details"
                    LogManager.logError(
                        "Token exchange failed with status code 400 (not a nonce error): \(errorDetails)")
                    throw AuthError.invalidCredentials
                }
            }
            // Handle other errors
            else {
                let statusCode = httpResponse.statusCode
                let errorDetails = String(data: data, encoding: .utf8) ?? "No details"
                LogManager.logError(
                    "Token exchange failed with status code \(statusCode). Response: \(errorDetails)")

                if let oauthError = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                    LogManager.logError(
                        "OAuth Error: \(oauthError.error) - \(oauthError.errorDescription ?? "No description")")
                }

                switch statusCode {
                case 400: throw AuthError.invalidCredentials
                case 401: throw AuthError.authorizationFailed
                default: throw AuthError.tokenRefreshFailed
                }
            }
        } catch let error as NetworkError {
            LogManager.logError("Network error during token exchange: \(error)")
            throw AuthError.networkError(error)
        } catch let error as AuthError {
            throw error
        } catch {
            LogManager.logError("Unexpected error during token exchange: \(error)")
            throw AuthError.tokenRefreshFailed
        }
    }

    /// Exchanges an authorization code for tokens at the token endpoint.
    /// Handles DPoP proof generation using an ephemeral key if provided (common after PAR),
    /// or potentially a persistent key (though less common and requires DID).
    /// Delegates nonce handling for ephemeral keys to `sendTokenRequestWithEphemeralKey`.
    /// - Parameters:
    ///   - code: The authorization code received from the callback.
    ///   - codeVerifier: The PKCE code verifier associated with the code.
    ///   - tokenEndpoint: The URL string of the authorization server's token endpoint.
    ///   - authServerURL: The base URL of the authorization server (used for context, logging).
    ///   - ephemeralKey: The ephemeral DPoP key used during PAR, if available from OAuthState.
    /// - Returns: The decoded TokenResponse containing access, refresh tokens, etc.
    /// - Throws: AuthError or NetworkError if the exchange fails.
    private func exchangeCodeForTokens(
        code: String,
        codeVerifier: String,
        tokenEndpoint: String,
        authServerURL: URL,
        ephemeralKey: P256.Signing.PrivateKey?,
        initialNonce: String?,
        resourceURL: URL? = nil
    ) async throws -> TokenResponse {
        guard let url = URL(string: tokenEndpoint) else {
            LogManager.logError("Invalid token endpoint URL provided: \(tokenEndpoint)")
            throw AuthError.invalidOAuthConfiguration
        }

        // --- Prepare Base Request ---
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var params: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": oauthConfig.redirectUri,
            "client_id": oauthConfig.clientId,
            "code_verifier": codeVerifier,
        ]
        if let resourceURL {
            params["resource"] = resourceURL.absoluteString
            LogManager.logInfo(
                "Including OAuth resource parameter for code exchange: \(resourceURL.absoluteString)")
        }
        request.httpBody = encodeFormData(params)

        LogManager.logDebug("Preparing to exchange authorization code for tokens at: \(tokenEndpoint)")
        // Increase timeout specifically for token exchange
        request.timeoutInterval = 30.0

        // --- DPoP Handling ---
        if let key = ephemeralKey {
            LogManager.logDebug("Using ephemeral key for DPoP proof in token exchange.")

            // Attempt token exchange using the ephemeral key
            do {
                // Use the PAR response nonce for the token exchange if available
                return try await sendTokenRequestWithEphemeralKey(
                    request: request,
                    tokenEndpoint: tokenEndpoint,
                    code: code,
                    codeVerifier: codeVerifier,
                    key: key,
                    nonce: initialNonce // Using the stored PAR nonce is required by Bluesky's OAuth implementation
                )
            } catch {
                LogManager.logError("Token exchange using ephemeral key failed: \(error)")
                if error is AuthError {
                    throw error
                } else if error is NetworkError {
                    throw AuthError.networkError(error)
                } else {
                    throw AuthError.tokenRefreshFailed
                }
            }
        } else {
            // Fallback for no ephemeral key (less common case)
            LogManager.logDebug(
                "No ephemeral key provided for token exchange. Attempting without DPoP."
            )
            // Note: If the server *requires* DPoP even without an ephemeral key hint, this call will likely fail.
            // A more robust implementation might attempt DPoP with a persistent key if one exists for a known DID,
            // but that's complex before the DID is confirmed by the token response.

            // Perform the request directly using the network service.
            do {
                // skipTokenRefresh is true as we are getting new tokens.
                let (data, urlResponse) = try await networkService.request(request, skipTokenRefresh: true)

                guard let httpResponse = urlResponse as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                // --- Basic Nonce Handling Check (Non-Ephemeral Path - Limited Usefulness) ---
                // Check for 400/use_dpop_nonce here, but retrying is problematic without a key.
                let dpopNonce = httpResponse.allHeaderFields["dpop-nonce"] as? String
                if httpResponse.statusCode == 400,
                   let errorData = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data),
                   errorData.error == "use_dpop_nonce",
                   dpopNonce != nil
                {
                    // We received the nonce error, but we don't have a key readily available to retry with DPoP.
                    LogManager.logError(
                        "Received 'use_dpop_nonce' error on token exchange (non-ephemeral path), but cannot retry without a DPoP key (DID unknown). Failing."
                    )
                    // Throw an error indicating the failure due to inability to handle DPoP requirement.
                    throw AuthError.dpopKeyError // Or tokenRefreshFailed
                }
                // --- End Basic Nonce Handling ---

                // --- Handle Success or Other Errors (Non-Ephemeral Path) ---
                if (200 ..< 300).contains(httpResponse.statusCode) {
                    // Success
                    let decoder = JSONDecoder()
                    do {
                        let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
                        LogManager.logDebug("Successfully decoded token response (non-ephemeral path).")
                        return tokenResponse
                    } catch {
                        LogManager.logError(
                            "Failed to decode successful token response (non-ephemeral path): \(error). Data: \(String(data: data, encoding: .utf8) ?? "unable to decode")"
                        )
                        throw AuthError.invalidResponse
                    }
                } else {
                    // Handle other HTTP errors
                    let errorDetails = String(data: data, encoding: .utf8) ?? "No error details"
                    LogManager.logError(
                        "Token exchange failed (non-ephemeral path) with status code \(httpResponse.statusCode). Response: \(errorDetails)"
                    )
                    // Log decoded OAuth error if possible
                    if let oauthError = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                        LogManager.logError(
                            "OAuth Error: \(oauthError.error) - \(oauthError.errorDescription ?? "No description")"
                        )
                    }
                    // Map common errors
                    switch httpResponse.statusCode {
                    case 400: throw AuthError.invalidCredentials // Non-nonce 400 error
                    case 401: throw AuthError.authorizationFailed
                    default: throw AuthError.tokenRefreshFailed
                    }
                }
            } catch let error as NetworkError {
                LogManager.logError("Network error during token exchange: \(error)")
                throw AuthError.networkError(error)
            } catch let error as AuthError {
                // Rethrow AuthErrors (e.g., dpopKeyError from nonce check)
                throw error
            } catch {
                LogManager.logError("Unexpected error during token exchange: \(error)")
                throw AuthError.tokenRefreshFailed
            }
        }
    }

    /// Fetches the protected resource metadata from a PDS.
    /// - Parameter pdsURL: The PDS URL.
    /// - Returns: The protected resource metadata.
    private func fetchProtectedResourceMetadata(pdsURL: URL) async throws -> ProtectedResourceMetadata {
        let endpoint = "\(pdsURL.absoluteString)/.well-known/oauth-protected-resource"
        guard let endpointURL = URL(string: endpoint) else {
            throw AuthError.invalidOAuthConfiguration
        }
        let request = URLRequest(url: endpointURL)

        // More resilient handling for local cancellations (-999): retry up to 3x with jittered backoff.
        // Other errors retain the prior behavior (single retry), to avoid masking real failures.
        let maxCancelledRetries = 3
        let maxGeneralRetries = 2
        var lastError: Error?
        for attempt in 1 ... maxCancelledRetries {
            do {
                let (data, _) = try await networkService.request(request)
                let metadata = try JSONDecoder().decode(ProtectedResourceMetadata.self, from: data)
                return metadata
            } catch {
                lastError = error

                // Detect explicit URLSession cancellation (-999)
                if let urlErr = error as? URLError, urlErr.code == .cancelled {
                    LogManager.logDebug(
                        "Protected resource metadata fetch cancelled (-999), attempt \(attempt)/\(maxCancelledRetries). Retrying...",
                        category: .authentication
                    )

                    if attempt < maxCancelledRetries {
                        // Exponential backoff with light jitter: 100ms, 200ms, 400ms (±20%)
                        let base = pow(2.0, Double(attempt - 1)) * 0.1 // seconds
                        let jitter = Double.random(in: 0.8 ... 1.2)
                        let delay = base * jitter
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                } else {
                    // Maintain prior single retry behavior for non-cancel errors
                    if attempt < maxGeneralRetries {
                        LogManager.logDebug(
                            "Protected resource metadata fetch attempt \(attempt) failed, retrying once: \(error)",
                            category: .authentication
                        )
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                        continue
                    }
                }
            }
        }

        throw lastError ?? AuthError.networkError(NetworkError.requestFailed)
    }

    /// Fetches the authorization server metadata.
    /// - Parameter authServerURL: The authorization server URL.
    /// - Returns: The authorization server metadata.
    private func fetchAuthorizationServerMetadata(authServerURL: URL) async throws
        -> AuthorizationServerMetadata
    {
        let endpoint = "\(authServerURL.absoluteString)/.well-known/oauth-authorization-server"
        guard let endpointURL = URL(string: endpoint) else {
            throw AuthError.invalidOAuthConfiguration
        }
        let request = URLRequest(url: endpointURL)

        // Resilient handling mirroring protected resource fetch
        let maxCancelledRetries = 3
        let maxGeneralRetries = 2
        var lastError: Error?
        for attempt in 1 ... maxCancelledRetries {
            do {
                let (data, _) = try await networkService.request(request)
                let metadata = try JSONDecoder().decode(AuthorizationServerMetadata.self, from: data)
                return metadata
            } catch {
                lastError = error

                if let urlErr = error as? URLError, urlErr.code == .cancelled {
                    LogManager.logDebug(
                        "Authorization server metadata fetch cancelled (-999), attempt \(attempt)/\(maxCancelledRetries). Retrying...",
                        category: .authentication
                    )

                    if attempt < maxCancelledRetries {
                        let base = pow(2.0, Double(attempt - 1)) * 0.1 // seconds
                        let jitter = Double.random(in: 0.8 ... 1.2)
                        let delay = base * jitter
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                } else {
                    if attempt < maxGeneralRetries {
                        LogManager.logDebug(
                            "Authorization server metadata fetch attempt \(attempt) failed, retrying once: \(error)",
                            category: .authentication
                        )
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        continue
                    }
                }
            }
        }

        throw lastError ?? AuthError.networkError(NetworkError.requestFailed)
    }
}

// MARK: - DPoP Payload

/// Payload for DPoP JWTs
private struct DPoPPayload: Encodable {
    let jti: String // JWT ID
    let htm: String // HTTP Method
    let htu: String // HTTP URI
    let iat: Int // Issued At timestamp
    let exp: Int? // Expiration (optional, short TTL)
    let ath: String? // Access Token Hash (optional)
    let nonce: String? // Nonce (optional)
}

// MARK: - Token Response

/// Response from the token endpoint
struct TokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let scope: String
    let sub: String?
    let dpopJkt: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case sub
        case dpopJkt = "dpop_jkt"
    }
}

// MARK: - PAR Response

/// Response from the pushed authorization request endpoint
private struct PARResponse: Decodable {
    let requestURI: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case requestURI = "request_uri"
        case expiresIn = "expires_in"
    }
}

// MARK: - Data Extension for Base64URL Encoding

extension Data {
    func base64URLEscaped() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
