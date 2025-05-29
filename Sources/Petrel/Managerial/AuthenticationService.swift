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

/// Protocol defining the interface for authentication services.
public protocol AuthServiceProtocol: Actor {
    /// Starts the OAuth flow for an existing user.
    /// - Parameter identifier: The user identifier (handle).
    /// - Returns: The authorization URL to present to the user.
    func startOAuthFlow(identifier: String?) async throws -> URL

    /// Handles the OAuth callback URL after user authentication.
    /// - Parameter url: The callback URL received from the authorization server.
    func handleOAuthCallback(url: URL) async throws

    /// Logs out the current user, invalidating their session.
    func logout() async throws

    /// Indicates whether authentication tokens exist for the current account.
    /// - Returns: True if tokens exist, false otherwise.
    func tokensExist() async -> Bool

    /// Refreshes the authentication token if needed.
    /// - Returns: True if token was refreshed or is still valid, false otherwise.
    func refreshTokenIfNeeded() async throws -> Bool

    /// Prepares an authenticated request by adding necessary authentication headers.
    /// - Parameter request: The original request to authenticate.
    /// - Returns: The request with authentication headers added.
    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest
}

/// Errors that can occur during authentication.
public enum AuthError: Error, Equatable {
    case noActiveAccount
    case invalidCredentials
    case invalidOAuthConfiguration
    case tokenRefreshFailed
    case authorizationFailed
    case invalidCallbackURL
    case dpopKeyError
    case networkError(Error)
    case invalidResponse

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
             (.invalidResponse, .invalidResponse):
            return true
        default:
            return false
        }
    }
}

/// Actor responsible for handling authentication operations.
public actor AuthenticationService: AuthServiceProtocol, AuthenticationProvider {
    public func handleOAuthCallback(url: URL) async throws {
        LogManager.logInfo("Handling OAuth callback: \(url.absoluteString)")

        // 1. Extract code and state
        guard let code = extractAuthorizationCode(from: url),
              let stateToken = extractState(from: url)
        else {
            LogManager.logError("Callback URL missing code or state.")
            throw AuthError.invalidCallbackURL
        }
        LogManager.logDebug("Extracted state: \(stateToken), code: \(code.prefix(4))...")

        // 2. Retrieve OAuthState using the stateToken
        guard let oauthState = try await storage.getOAuthState(for: stateToken) else {
            LogManager.logError("No matching OAuth state found for state: \(stateToken)")
            // It's possible the state was already used or expired.
            throw AuthError.invalidCallbackURL // Or a more specific state error
        }
        LogManager.logDebug("Successfully retrieved OAuth state for state: \(stateToken)")

        // 3. Extract necessary info from oauthState
        let codeVerifier = oauthState.codeVerifier
        // Using _ to explicitly show we're reading but not using this variable
        _ = oauthState.targetPDSURL
        // Removed duplicate declarations of codeVerifier and pdsURL
        let initialNonce = oauthState.parResponseNonce

        // --- Get ephemeral key directly from OAuthState ---
        guard let keyData = oauthState.ephemeralDPoPKey else {
            LogManager.logError(
                "Ephemeral DPoP key data missing in retrieved OAuth state for state: \(stateToken)")
            try? await storage.deleteOAuthState(for: stateToken)
            throw AuthError.dpopKeyError
        }

        let privateKey: P256.Signing.PrivateKey
        do {
            privateKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)
            LogManager.logDebug("Successfully deserialized ephemeral DPoP key from OAuth state.")
            // Log the deserialized key's x coordinate for debugging
            let publicKey = privateKey.publicKey
            let x = publicKey.x963Representation.dropFirst().prefix(32).base64URLEscaped()
            LogManager.logDebug(
                "Using deserialized ephemeral key with x coordinate: \(x) for token exchange")
        } catch {
            LogManager.logError("Failed to deserialize ephemeral DPoP key: \(error)")
            try? await storage.deleteOAuthState(for: stateToken)
            throw AuthError.dpopKeyError
        }

        LogManager.logDebug("Using nonce for token exchange: \(initialNonce ?? "nil")")
        LogManager.logDebug("Using nonce for token exchange: \(initialNonce ?? "nil")")
        // --- End Key Retrieval ---

        // 4. Delete the OAuthState *after* successfully retrieving all needed info
        do {
            try await storage.deleteOAuthState(for: stateToken)
            LogManager.logDebug("Successfully deleted OAuth state for state: \(stateToken)")
        } catch {
            LogManager.logError("Failed to delete OAuth state for \(stateToken): \(error)")
            // Decide if you should proceed or throw. Proceeding might be okay if token exchange works,
            // but it leaves stale data. Throwing might be safer.
            throw AuthError.networkError(error)
        }

        // 3. Fetch Authorization Server Metadata (needed for token endpoint)
        // We stored the targetPDSURL in the OAuthState
        guard let pdsURL = oauthState.targetPDSURL else {
            LogManager.logError("Missing target PDS URL in OAuth state.")
            throw AuthError.invalidOAuthConfiguration // Or a more specific state error
        }
        LogManager.logDebug("Target PDS URL from OAuth state: \(pdsURL.absoluteString)")

        // Try to fetch protected resource metadata first (as per OAuth spec)
        let authServerURL: URL
        do {
            let metadata = try await fetchProtectedResourceMetadata(pdsURL: pdsURL)
            if let foundAuthServerURL = metadata.authorizationServers.first {
                authServerURL = foundAuthServerURL
                LogManager.logDebug("Found authorization server from protected resource metadata: \(authServerURL)")
            } else {
                // Protected resource metadata exists but has no auth servers listed
                LogManager.logError("Protected resource metadata has no authorization servers")
                throw AuthError.invalidOAuthConfiguration
            }
        } catch {
            // If protected resource metadata fetch fails (e.g., 404), 
            // fall back to treating the URL as the authorization server itself
            LogManager.logDebug("Could not fetch protected resource metadata from \(pdsURL), treating it as authorization server")
            authServerURL = pdsURL
        }
        
        let authServerMetadata = try await fetchAuthorizationServerMetadata(
            authServerURL: authServerURL)
        let tokenEndpoint = authServerMetadata.tokenEndpoint
        LogManager.logDebug("Token endpoint: \(tokenEndpoint)")

        // 4. Exchange code for tokens directly
        // Pass the extracted codeVerifier and the ephemeralKey

        // Add debug logging to show the key thumbprint
        let jwk = try createJWK(from: privateKey)
        let thumbprint = try calculateJWKThumbprint(jwk: jwk)
        LogManager.logDebug("Using ephemeral key with thumbprint: \(thumbprint) for token exchange")

        let tokenResponse = try await exchangeCodeForTokens(
            code: code,
            codeVerifier: codeVerifier, // Use the verifier from the state
            tokenEndpoint: tokenEndpoint,
            authServerURL: authServerURL, // Pass the auth server URL for DPoP proof
            ephemeralKey: privateKey, // Pass the ephemeral key
            initialNonce: initialNonce
        )

        // 5. Process Token Response
        guard let did = tokenResponse.sub else {
            LogManager.logError("Token response is missing 'sub' (DID).")
            throw AuthError.invalidResponse // Or a more specific error
        }
        LogManager.logInfo("Successfully exchanged code for tokens. Received DID: \(did)")

        // Transfer any OAuth flow nonces to this new DID
        if !oauthFlowNonces.isEmpty {
            var didNonces = try await storage.getDPoPNonces(for: did) ?? [:]

            // Copy OAuth nonces to the confirmed DID's nonce storage
            for (domain, nonce) in oauthFlowNonces {
                didNonces[domain] = nonce
                LogManager.logDebug("Transferred nonce for domain \(domain) to new DID \(did)")
            }

            try await storage.saveDPoPNonces(didNonces, for: did)
            oauthFlowNonces = [:] // Clear memory store
            LogManager.logInfo("Transferred \(oauthFlowNonces.count) OAuth flow nonces to DID \(did)")
        }

        // Determine token type based on response
        let tokenType: TokenType = (tokenResponse.tokenType.lowercased() == "dpop") ? .dpop : .bearer
        LogManager.logDebug("Determined token type: \(tokenType.rawValue)")

        // 6. Create Session
        let newSession = Session(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            createdAt: Date(), // Use current time
            expiresIn: TimeInterval(tokenResponse.expiresIn),
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
            LogManager.logDebug("Could not fetch protected resource metadata for account (will use nil): \(error)")
            protectedResourceMetadata = nil
        }
        
        if isNewAccount {
            LogManager.logDebug("Creating new account for DID: \(did)")
            account = Account(
                did: did,
                handle: oauthState.initialIdentifier, // Use handle from initial state if available
                pdsURL: pdsURL, // Use the PDS URL from the state
                protectedResourceMetadata: protectedResourceMetadata, // Store fetched metadata (may be nil)
                authorizationServerMetadata: authServerMetadata // Store fetched metadata
            )
        } else {
            LogManager.logDebug("Updating existing account for DID: \(did)")
            // Update existing account details if necessary
            account?.pdsURL = pdsURL // Ensure PDS URL is up-to-date
            let existingHandle = account?.handle
            account?.handle = oauthState.initialIdentifier ?? existingHandle // Update handle if provided
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
            LogManager.logInfo("Stored the ephemeral DPoP key used in token exchange as the active key for DID: \(did)")
        } catch {
            LogManager.logError("Failed to save the active DPoP key for DID \(did) after token exchange: \(error)")
            throw AuthError.dpopKeyError
        }
        // --- End DPoP Key Handling ---

        // 8. Save Session and Account
        try await storage.saveSession(newSession, for: did)
        LogManager.logDebug("Saved session for DID: \(did)")
        try await accountManager.addAccount(finalAccount) // Changed from addOrUpdateAccount to add(account:)
        LogManager.logDebug("Added/Updated account in AccountManager for DID: \(did)")
        try await accountManager.setCurrentAccount(did: did) // Set as current account
        LogManager.logInfo("Set current account to DID: \(did)")

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
    }

    public func logout() async throws {
        LogManager.logInfo("Starting logout process.")
        guard let did = await accountManager.getCurrentAccount()?.did else {
            LogManager.logDebug("Logout called but no active account found.")
            // No active user, nothing to log out.
            return
        }

        LogManager.logInfo("Logging out account with DID: \(did)")

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
            LogManager.logDebug("Deleted DPoP nonces for DID: \(did)")
        } catch {
            LogManager.logError("Failed to delete DPoP nonces for DID \(did): \(error)")
            // Continue logout process
        }

        // 5. Update Account Manager State
        // Remove the account entirely or just clear the current user?
        // Let's remove the account for a full logout effect.
        // `removeAccount` handles switching to another account if available.
        do {
            try await accountManager.removeAccount(did: did)
            LogManager.logInfo("Removed account and updated current account status.")
        } catch {
            LogManager.logError(
                "Failed during account removal/switching after logout for DID \(did): \(error)")
            // At this point, local data is cleared, but account manager state might be inconsistent.
            // Consider just clearing currentDID as a fallback?
            // try? await accountManager.setCurrentAccount(did: "") // Or handle more gracefully
        }

        LogManager.logInfo("Logout process completed for DID: \(did)")
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

    public func handleUnauthorizedResponse(
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

        // Refresh the token
        let refreshed = try await refreshTokenIfNeeded()

        // If refresh was successful, retry the request
        if refreshed {
            var newRequest = request
            if let session = try? await storage.getSession(for: did) {
                // Prepare the authenticated request
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
        } else {
            throw AuthError.tokenRefreshFailed as Error
        }
    }

    public func updateDPoPNonce(for url: URL, from headers: [String: String]) async {
        guard let domain = url.host?.lowercased(),
              let nonce = headers["DPoP-Nonce"],
              let did = await accountManager.getCurrentAccount()?.did
        else {
            return
        }

        // Update the DPoP nonce for the domain
        await updateDPoPNonce(domain: domain, nonce: nonce, for: did)
    }

    // MARK: - Properties

    private let storage: KeychainStorage
    private let accountManager: AccountManaging
    private let networkService: NetworkService
    private let oauthConfig: OAuthConfig
    private let didResolver: DIDResolving
    private let refreshCoordinator = TokenRefreshCoordinator()
    // Simple in-memory store for OAuth flow nonces (independent of any account)
    private var oauthFlowNonces: [String: String] = [:]

    // MARK: - Initialization

    /// Initializes a new AuthenticationService with the specified dependencies.
    /// - Parameters:
    ///   - storage: The secure storage for tokens and keys.
    ///   - accountManager: The account manager.
    ///   - networkService: The network service for making HTTP requests.
    ///   - oauthConfig: The OAuth configuration.
    ///   - didResolver: The DID resolver for resolving DIDs to PDS URLs.
    public init(
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
    public func startOAuthFlow(identifier: String? = nil) async throws -> URL {
        let pdsURL: URL
        var did: String?

        // For sign-up flow (no identifier), use default PDS URL
        if let identifier = identifier {
            // Resolve handle to DID and DID to PDS URL
            did = try await didResolver.resolveHandleToDID(handle: identifier)
            pdsURL = try await didResolver.resolveDIDToPDSURL(did: did!)
        } else {
            // Use default PDS URL for sign-up
            pdsURL = URL(string: "https://bsky.social")!
        }

        // Try to fetch protected resource metadata first (as per OAuth spec)
        let authServerURL: URL
        let protectedResourceMetadata: ProtectedResourceMetadata?
        do {
            let metadata = try await fetchProtectedResourceMetadata(pdsURL: pdsURL)
            protectedResourceMetadata = metadata
            if let foundAuthServerURL = metadata.authorizationServers.first {
                authServerURL = foundAuthServerURL
                LogManager.logDebug("Found authorization server from protected resource metadata: \(authServerURL)")
            } else {
                // Protected resource metadata exists but has no auth servers listed
                LogManager.logError("Protected resource metadata has no authorization servers")
                throw AuthError.invalidOAuthConfiguration
            }
        } catch {
            // If protected resource metadata fetch fails (e.g., 404), 
            // fall back to treating the URL as the authorization server itself
            LogManager.logDebug("Could not fetch protected resource metadata from \(pdsURL), treating it as authorization server")
            authServerURL = pdsURL
        }

        // Fetch Authorization Server Metadata
        let authServerMetadata = try await fetchAuthorizationServerMetadata(
            authServerURL: authServerURL)

        // Generate PKCE code verifier and challenge
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Generate state token
        let stateToken = UUID().uuidString

        // Generate an ephemeral key for this OAuth session
        let ephemeralKey = P256.Signing.PrivateKey()

        // Removed caching of the key

        // Add debug logging for key tracking
        let publicKey = ephemeralKey.publicKey
        let x = publicKey.x963Representation.dropFirst().prefix(32).base64URLEscaped()
        LogManager.logDebug("Generated ephemeral DPoP key for OAuth session with x coordinate: \(x)")

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
        LogManager.logDebug("Saved OAuth state including PAR nonce: \(parNonce ?? "nil")")

        // Build Authorization URL
        var components = URLComponents(string: authServerMetadata.authorizationEndpoint)!
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
    public func startOAuthFlowForSignUp(pdsURL: URL = URL(string: "https://bsky.social")!)
        async throws -> URL
    {
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
            targetPDSURL: pdsURL,
            ephemeralDPoPKey: ephemeralKey.rawRepresentation,
            parResponseNonce: nil // Initialize explicitly as nil, will update after PAR
        )
        // Save the initial state (optional, but good practice if PAR fails before nonce is known)
        // try await storage.saveOAuthState(oauthState) // Consider if needed

        // Try to fetch protected resource metadata first (as per OAuth spec)
        let authServerURL: URL
        do {
            let protectedResourceMetadata = try await fetchProtectedResourceMetadata(pdsURL: pdsURL)
            if let foundAuthServerURL = protectedResourceMetadata.authorizationServers.first {
                authServerURL = foundAuthServerURL
                LogManager.logDebug("Found authorization server from protected resource metadata: \(authServerURL)")
            } else {
                // Protected resource metadata exists but has no auth servers listed
                LogManager.logError("Protected resource metadata has no authorization servers")
                throw AuthError.invalidOAuthConfiguration
            }
        } catch {
            // If protected resource metadata fetch fails (e.g., 404), 
            // fall back to treating the URL as the authorization server itself
            LogManager.logDebug("Could not fetch protected resource metadata from \(pdsURL), treating it as authorization server")
            authServerURL = pdsURL
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
        LogManager.logDebug("Saved OAuth state for sign-up including PAR nonce: \(parNonce ?? "nil")")
        // Build authorization URL
        var components = URLComponents(string: authServerMetadata.authorizationEndpoint)!
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
        var parameters: [String: String] = [
            "client_id": oauthConfig.clientId, // FIX: Use self.oauthConfig
            "redirect_uri": oauthConfig.redirectUri, // FIX: Use self.oauthConfig
            "response_type": "code",
            "code_challenge_method": "S256",
            "code_challenge": codeChallenge,
            "state": state,
            "scope": oauthConfig.scope, // FIX: Use self.oauthConfig // Ensure scope is included
        ]

        let body = encodeFormData(parameters)

        var request = URLRequest(url: URL(string: endpoint)!)
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
                if let keyString = key as? String, keyString.caseInsensitiveCompare("DPoP-Nonce") == .orderedSame {
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
                    "Received use_dpop_nonce error on Sign-Up PAR. Retrying with nonce: \(receivedNonce)")
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
        var request = URLRequest(url: URL(string: endpoint)!)
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
            LogManager.logDebug("No ephemeral key provided for PAR, but active account (\(did)) found. Using persistent key (unusual for standard flow).")
            proofKey = try await getOrCreateDPoPKey(for: did)
            dpopProof = try await createDPoPProof(
                for: "POST", url: endpoint, type: .authorization, did: did
            )
        } else {
            // Fallback: Should not happen if startOAuthFlow always provides a key
            LogManager.logError("No active account and no ephemeral key provided for PAR. Generating temporary key (unexpected).") // Changed logWarning to logError
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
                if let keyString = key as? String, keyString.caseInsensitiveCompare("DPoP-Nonce") == .orderedSame {
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
                    "Received use_dpop_nonce error on PAR. Retrying with nonce: \(receivedNonce)")
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
    public func tokensExist() async -> Bool {
        guard let account = await accountManager.getCurrentAccount(),
              let session = try? await storage.getSession(for: account.did)
        else {
            return false
        }

        return session.accessToken.isEmpty == false
    }

    /// Refreshes the authentication token if needed.
    /// - Returns: True if token was refreshed or is still valid, false otherwise.
    public func refreshTokenIfNeeded() async throws -> Bool {
        // Get current account and session
        guard let account = await accountManager.getCurrentAccount(),
              let session = try? await storage.getSession(for: account.did)
        else {
            return false
        }

        // Check if token is still valid (restore this check to avoid unnecessary refreshes)
        if !session.isExpiringSoon {
            LogManager.logDebug("Token for DID: \(account.did) is not expiring soon, skipping refresh")
            return true // Token is still valid
        }

        // Set in-progress flag to handle app termination during refresh
        // This helps detect and recover from incomplete refresh operations
        try await markRefreshInProgress(for: account.did, inProgress: true)

        // Use the coordinator to prevent concurrent refreshes
        do {
            // The coordinator expects a function returning the raw response data and response object
            let (refreshData, refreshResponse): (Data, HTTPURLResponse) = try await refreshCoordinator.coordinateRefresh(
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

            // Save the new session details from the successful refresh
            let newSession = Session(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                createdAt: Date(), // Use current time as the refresh time
                expiresIn: TimeInterval(tokenResponse.expiresIn),
                tokenType: session.tokenType, // Assume token type doesn't change on refresh
                did: account.did
            )

            // Save session and verify it was saved correctly
            try await storage.saveSession(newSession, for: account.did)

            // Verify the session was saved correctly (important check!)
            guard let savedSession = try await storage.getSession(for: account.did),
                  savedSession.refreshToken == tokenResponse.refreshToken
            else {
                LogManager.logError("Token storage verification failed for DID: \(account.did)")
                throw AuthError.tokenRefreshFailed
            }

            // Clear the in-progress flag only after successful save and verification
            try await markRefreshInProgress(for: account.did, inProgress: false)

            LogManager.logInfo("Successfully refreshed, saved and verified token for DID: \(account.did)")
            return true // Indicate success

        } catch let error as TokenRefreshCoordinator.RefreshError {
            // Clear in-progress flag regardless of error type
            try? await markRefreshInProgress(for: account.did, inProgress: false)

            switch error {
            case let .invalidGrant(description):
                LogManager.logError("Token refresh failed with invalid_grant for DID \(account.did): \(description ?? "No details"). Logging out.")
                // The refresh token is invalid, trigger logout
                try await logout() // Perform full logout to clear state
                return false // Indicate failure
            case let .dpopError(description):
                // We should rarely hit this error now with our retry logic in performTokenRefreshWithRetry,
                // but handle it gracefully if it does occur
                LogManager.logError("Token refresh failed due to DPoP error for DID \(account.did): \(description ?? "No details")")

                // If it's specifically a nonce mismatch, we can try an immediate refresh again
                // since we've already updated the nonce in our storage by this point
                if description?.contains("nonce mismatch") == true || description?.contains("use_dpop_nonce") == true {
                    LogManager.logInfo("Attempting one final refresh after DPoP nonce mismatch...")
                    // Try a direct refresh - this will use our updated nonce
                    do {
                        let (retryData, retryResponse) = try await performTokenRefresh(for: account.did)
                        // If successful, decode and save the new session
                        if (200 ..< 300).contains(retryResponse.statusCode) {
                            let decoder = JSONDecoder()
                            let tokenResponse = try decoder.decode(TokenResponse.self, from: retryData)

                            // Create and save new session
                            let newSession = Session(
                                accessToken: tokenResponse.accessToken,
                                refreshToken: tokenResponse.refreshToken,
                                createdAt: Date(),
                                expiresIn: TimeInterval(tokenResponse.expiresIn),
                                tokenType: session.tokenType,
                                did: account.did
                            )
                            try await storage.saveSession(newSession, for: account.did)

                            // Verify save was successful
                            guard let savedSession = try await storage.getSession(for: account.did),
                                  savedSession.refreshToken == tokenResponse.refreshToken
                            else {
                                throw AuthError.tokenRefreshFailed
                            }

                            LogManager.logInfo("Successfully recovered from DPoP nonce mismatch for DID: \(account.did)")
                            return true
                        }
                    } catch {
                        LogManager.logError("Final nonce recovery attempt failed: \(error)")
                    }
                }

                // If we reach here, all attempts have failed
                throw AuthError.dpopKeyError // Map to a relevant AuthError
            case let .networkError(code, details):
                LogManager.logError("Token refresh failed due to network error (\(code)) for DID \(account.did): \(details ?? "No details")")
                // Logged details above, throw a general error for the caller
                throw AuthError.tokenRefreshFailed
            case let .decodingError(underlyingError, context):
                LogManager.logError("Token refresh failed due to decoding error for DID \(account.did): \(underlyingError), context: \(context ?? "none")")
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

            LogManager.logError("Token refresh failed with unexpected error for DID \(account.did): \(error)")
            throw AuthError.tokenRefreshFailed // General refresh failure
        }
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
    public func handleAppStartup() async {
        // Get current account
        guard let account = await accountManager.getCurrentAccount() else {
            return
        }

        // Check if a refresh operation was interrupted
        if await isRefreshInProgress(for: account.did) {
            LogManager.logError("Detected interrupted refresh operation for DID: \(account.did)")

            // Force a token refresh to get a fresh token
            do {
                _ = try await refreshTokenIfNeeded()
                LogManager.logInfo("Successfully recovered from interrupted refresh operation")
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
    private func performTokenRefreshWithRetry(for did: String, retryCount: Int) async throws -> (Data, HTTPURLResponse) {
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
            LogManager.logError("performTokenRefresh: Could not retrieve account or metadata for DID \(did)")
            throw AuthError.tokenRefreshFailed // Indicate failure
        }

        // Prepare refresh token request
        let tokenEndpoint = authServerMetadata.tokenEndpoint
        guard let endpointURL = URL(string: tokenEndpoint) else {
            LogManager.logError("performTokenRefresh: Invalid token endpoint URL")
            throw AuthError.tokenRefreshFailed
        }

        let requestBody: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": oauthConfig.clientId,
        ]

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = encodeFormData(requestBody)

        // Get the domain for nonce lookup
        let domain = endpointURL.host?.lowercased() ?? ""

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
                LogManager.logError("AuthenticationService - Token refresh response was not HTTPURLResponse")
                throw AuthError.invalidResponse
            }

            // Immediately handle DPoP nonce update to ensure it's captured regardless of response status
            if let newNonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce"),
               let url = httpResponse.url,
               let responseDomain = url.host?.lowercased()
            {
                await updateDPoPNonce(domain: responseDomain, nonce: newNonce, for: did)
                LogManager.logDebug("Updated DPoP nonce for domain \(responseDomain) after token refresh attempt")
            }

            // Log the response data for debugging
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode as string"
            LogManager.logDebug("Token refresh raw response: \(responseString)")

            // Check for DPoP nonce mismatch and retry
            if httpResponse.statusCode == 400 {
                // Attempt to decode the error
                do {
                    let errorResponse = try JSONDecoder().decode(OAuthErrorResponse.self, from: data)

                    // Check specifically for DPoP nonce error
                    if errorResponse.error == "use_dpop_nonce" && retryCount == 0 {
                        LogManager.logInfo("Detected DPoP nonce mismatch during token refresh. Will retry with updated nonce.")

                        // Wait a moment to ensure the nonce is properly stored
                        try await Task.sleep(nanoseconds: 500_000_000) // 500ms delay

                        // Retry the request with the new nonce
                        return try await performTokenRefreshWithRetry(for: did, retryCount: retryCount + 1)
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
                    guard !tokenResponse.accessToken.isEmpty && !tokenResponse.refreshToken.isEmpty else {
                        LogManager.logError("Token refresh succeeded but received empty tokens")
                        throw AuthError.invalidResponse
                    }

                    LogManager.logDebug("Successfully decoded token response with expiration in \(tokenResponse.expiresIn) seconds")
                } catch {
                    LogManager.logError("Failed to decode successful token response: \(error)")
                    // Allow to continue since coordinator will also try to decode and handle errors
                }
            }

            // Return the raw data and response for the coordinator to handle
            return (data, httpResponse)
        } catch {
            LogManager.logError("AuthenticationService - Token refresh network request failed: \(error)")
            // Propagate the network error or a generic refresh failure
            throw AuthError.tokenRefreshFailed // Or rethrow the specific network error
        }
    }

    // MARK: - Request Authentication

    /// Prepares an authenticated request by adding necessary authentication headers.
    /// - Parameter request: The original request to authenticate.
    /// - Returns: The request with authentication headers added.
    public func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
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
        let jwkThumbprint = try calculateJWKThumbprint(jwk: jwk) // Needed for token requests

        // Prepare DPoP payload
        let jti = UUID().uuidString
        let iat = Int(Date().timeIntervalSince1970)
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
            LogManager.logDebug("OAuth flow - using in-memory nonce for domain \(domain): \(finalNonce ?? "nil")")
        }
        // Case 3: Authenticated flow - get from storage
        else if let targetDID = targetDID, let urlObject = URL(string: url),
                let domain = urlObject.host?.lowercased()
        {
            // Fetch stored nonce for authenticated user
            if let storedNonces = try? await storage.getDPoPNonces(for: targetDID) {
                finalNonce = storedNonces[domain]
            } else {
                finalNonce = nil
            }
        } else {
            // No explicit nonce, using ephemeral key or couldn't get stored nonce
            finalNonce = nil
        }

        LogManager.logDebug("Using DPoP nonce for proof: \(finalNonce ?? "nil") for domain \(URL(string: url)?.host?.lowercased() ?? "N/A")") // Added Logging

        // Create the encodable payload struct
        let payload = DPoPPayload(
            jti: UUID().uuidString, // Use unique JTI per proof
            htm: method,
            htu: url,
            iat: Int(Date().timeIntervalSince1970),
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

    /// Updates the DPoP nonce for a domain.
    /// - Parameters:
    ///   - domain: The domain the nonce is for.
    ///   - nonce: The new nonce value.
    ///   - did: The DID to update the nonce for.
    private func updateDPoPNonce(domain: String, nonce: String, for did: String) async {
        do {
            LogManager.logDebug("Storing DPoP nonce '\(nonce)' for domain '\(domain)' for DID \(did)") // Added Logging
            var nonces = try await storage.getDPoPNonces(for: did) ?? [:]
            nonces[domain] = nonce
            try await storage.saveDPoPNonces(nonces, for: did)
        } catch {
            LogManager.logError("AuthenticationService - Failed to update DPoP nonce: \(error)")
        }
    }

    // MARK: - Helper Methods

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
                    return tokenResponse
                } catch {
                    LogManager.logError("Failed to decode token response: \(error)")
                    // Log the actual response body for debugging
                    let responseBody = String(data: data, encoding: .utf8) ?? "Could not decode response body"
                    LogManager.logError("Token Exchange Response Body (on decode failure): \(responseBody)")
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
                        "Received use_dpop_nonce error on token exchange. Retrying with nonce: \(receivedNonce)"
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
                        return try decoder.decode(TokenResponse.self, from: retryData)
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
        initialNonce: String?
    ) async throws -> TokenResponse {
        guard let url = URL(string: tokenEndpoint) else {
            LogManager.logError("Invalid token endpoint URL provided: \(tokenEndpoint)")
            throw AuthError.invalidOAuthConfiguration
        }

        // --- Prepare Base Request ---
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": oauthConfig.redirectUri,
            "client_id": oauthConfig.clientId,
            "code_verifier": codeVerifier,
        ]
        request.httpBody = encodeFormData(params)

        LogManager.logDebug("Preparing to exchange authorization code for tokens at: \(tokenEndpoint)")

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
        let request = URLRequest(url: URL(string: endpoint)!)

        let (data, _) = try await networkService.request(request)
        let metadata = try JSONDecoder().decode(ProtectedResourceMetadata.self, from: data)

        return metadata
    }

    /// Fetches the authorization server metadata.
    /// - Parameter authServerURL: The authorization server URL.
    /// - Returns: The authorization server metadata.
    private func fetchAuthorizationServerMetadata(authServerURL: URL) async throws
        -> AuthorizationServerMetadata
    {
        let endpoint = "\(authServerURL.absoluteString)/.well-known/oauth-authorization-server"
        let request = URLRequest(url: URL(string: endpoint)!)

        let (data, _) = try await networkService.request(request)
        let metadata = try JSONDecoder().decode(AuthorizationServerMetadata.self, from: data)

        return metadata
    }
}

// MARK: - DPoP Payload

/// Payload for DPoP JWTs
private struct DPoPPayload: Encodable {
    let jti: String // JWT ID
    let htm: String // HTTP Method
    let htu: String // HTTP URI
    let iat: Int // Issued At timestamp
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
