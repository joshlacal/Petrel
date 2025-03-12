//
//  OAuthManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 9/9/24.
//

import CryptoKit
import Foundation
import JSONWebAlgorithms
import JSONWebKey
import JSONWebSignature


// MARK: - AuthorizationServerMetadata Structure

struct AuthorizationServerMetadata: Codable {
    let issuer: String
    let scopesSupported: [String]
    let subjectTypesSupported: [String]
    let responseTypesSupported: [String]
    let responseModesSupported: [String]
    let grantTypesSupported: [String]
    let codeChallengeMethodsSupported: [String]
    let uiLocalesSupported: [String]
    let displayValuesSupported: [String]
    let authorizationResponseIssParameterSupported: Bool
    let requestObjectSigningAlgValuesSupported: [String]
    let requestObjectEncryptionAlgValuesSupported: [String]
    let requestObjectEncryptionEncValuesSupported: [String]
    let requestParameterSupported: Bool
    let requestUriParameterSupported: Bool
    let requireRequestUriRegistration: Bool
    let jwksUri: String
    let authorizationEndpoint: String
    let tokenEndpoint: String
    let tokenEndpointAuthMethodsSupported: [String]
    let tokenEndpointAuthSigningAlgValuesSupported: [String]
    let revocationEndpoint: String
    let introspectionEndpoint: String
    let pushedAuthorizationRequestEndpoint: String
    let requirePushedAuthorizationRequests: Bool
    let dpopSigningAlgValuesSupported: [String]
    let clientIdMetadataDocumentSupported: Bool

    enum CodingKeys: String, CodingKey {
        case issuer
        case scopesSupported = "scopes_supported"
        case subjectTypesSupported = "subject_types_supported"
        case responseTypesSupported = "response_types_supported"
        case responseModesSupported = "response_modes_supported"
        case grantTypesSupported = "grant_types_supported"
        case codeChallengeMethodsSupported = "code_challenge_methods_supported"
        case uiLocalesSupported = "ui_locales_supported"
        case displayValuesSupported = "display_values_supported"
        case authorizationResponseIssParameterSupported = "authorization_response_iss_parameter_supported"
        case requestObjectSigningAlgValuesSupported = "request_object_signing_alg_values_supported"
        case requestObjectEncryptionAlgValuesSupported = "request_object_encryption_alg_values_supported"
        case requestObjectEncryptionEncValuesSupported = "request_object_encryption_enc_values_supported"
        case requestParameterSupported = "request_parameter_supported"
        case requestUriParameterSupported = "request_uri_parameter_supported"
        case requireRequestUriRegistration = "require_request_uri_registration"
        case jwksUri = "jwks_uri"
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case tokenEndpointAuthMethodsSupported = "token_endpoint_auth_methods_supported"
        case tokenEndpointAuthSigningAlgValuesSupported = "token_endpoint_auth_signing_alg_values_supported"
        case revocationEndpoint = "revocation_endpoint"
        case introspectionEndpoint = "introspection_endpoint"
        case pushedAuthorizationRequestEndpoint = "pushed_authorization_request_endpoint"
        case requirePushedAuthorizationRequests = "require_pushed_authorization_requests"
        case dpopSigningAlgValuesSupported = "dpop_signing_alg_values_supported"
        case clientIdMetadataDocumentSupported = "client_id_metadata_document_supported"
    }
}

// MARK: - ProtectedResourceMetadata Structure

struct ProtectedResourceMetadata: Codable {
    let resource: URL
    let authorizationServers: [URL]
    let scopesSupported: [String]
    let bearerMethodsSupported: [String]
    let resourceDocumentation: URL

    enum CodingKeys: String, CodingKey {
        case resource
        case authorizationServers = "authorization_servers"
        case scopesSupported = "scopes_supported"
        case bearerMethodsSupported = "bearer_methods_supported"
        case resourceDocumentation = "resource_documentation"
    }
}

// MARK: - OAuthErrorResponse Structure

struct OAuthErrorResponse: Codable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - OAuthError Enumeration

enum OAuthError: Error, LocalizedError {
    case invalidPDSURL
    case missingServerMetadata
    case authorizationFailed
    case tokenExchangeFailed
    case invalidSubClaim
    case noDPoPKeyPair
    case maxRetriesReached
    case invalidNonce
    case invalidClientConfiguration
    case expiredToken
    case invalidToken
    case invalidResponse
    case tokenRefreshFailed
    case noAlternativeServersAvailable

    var errorDescription: String? {
        switch self {
        case .invalidPDSURL:
            return "Invalid PDS URL."
        case .missingServerMetadata:
            return "Missing server metadata."
        case .authorizationFailed:
            return "Authorization failed."
        case .tokenExchangeFailed:
            return "Token exchange failed."
        case .invalidSubClaim:
            return "Invalid 'sub' claim in token."
        case .noDPoPKeyPair:
            return "DPoP key pair not found."
        case .maxRetriesReached:
            return "Maximum retry attempts reached."
        case .invalidNonce:
            return "Invalid nonce received."
        case .invalidClientConfiguration:
            return "Invalid client configuration."
        case .expiredToken:
            return "Token has expired."
        case .invalidToken:
            return "Invalid token."
        case .invalidResponse:
            return "Invalid response from server."
        case .tokenRefreshFailed:
            return "Token refresh failed."
        case .noAlternativeServersAvailable:
            return "No alternative authorization servers available."
        }
    }
}

// MARK: - String Extension for Base64URL Encoding

extension String {
    func base64URLEscaped() -> String {
        return replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
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

// MARK: - OAuthManager Actor

actor OAuthManager {
    private let networkManager: NetworkManaging
    private let configurationManager: ConfigurationManaging
    private let tokenManager: TokenManaging
    private let didResolver: DIDResolving
    private var authorizationServerMetadata: AuthorizationServerMetadata?
    private var protectedResourceMetadata: ProtectedResourceMetadata?
    private var dpopKeyPair: P256.Signing.PrivateKey?
    private let oauthConfig: OAuthConfiguration
    private var lastKeyRegenerationTime: Date
    private var dpopNonces: [String: String] = [:] // Dictionary to store nonces for different domains
    private let namespace: String
    private let dpopKeyTag: String

    public init(
        oauthConfig: OAuthConfiguration,
        networkManager: NetworkManaging,
        configurationManager: ConfigurationManaging,
        tokenManager: TokenManaging,
        didResolver: DIDResolving,
        namespace: String
    ) async {
        self.oauthConfig = oauthConfig
        self.networkManager = networkManager
        self.configurationManager = configurationManager
        self.tokenManager = tokenManager
        self.didResolver = didResolver
        self.namespace = namespace
        dpopKeyTag = "\(namespace).dpopkeypair"

        // Initialize stored properties
        lastKeyRegenerationTime = Date()
        dpopNonces = [:]
        dpopKeyPair = nil
        authorizationServerMetadata = await configurationManager.getAuthorizationServerMetadata()
        protectedResourceMetadata = await configurationManager.getProtectedResourceMetadata()

        // Attempt to load existing DPoP key pair
        do {
            dpopKeyPair = try KeychainManager.retrieveDPoPKey(namespace: namespace)
            LogManager.logInfo("Loaded existing DPoP key pair from keychain.")
        } catch {
            // Generate new DPoP key pair if not found
            dpopKeyPair = P256.Signing.PrivateKey()
            lastKeyRegenerationTime = Date()
            do {
                try KeychainManager.storeDPoPKey(dpopKeyPair!, namespace: namespace)
                LogManager.logInfo("Generated new DPoP key pair and stored in keychain.")
            } catch {
                LogManager.logError("Failed to store DPoP key pair: \(error)")
                // Handle error as appropriate
            }
        }

        LogManager.logDebug("OAuth Configuration: clientId=\(oauthConfig.clientId), redirectUri=\(oauthConfig.redirectUri), scopes=\(oauthConfig.scope)")

        // Subscribe to relevant events if needed
        // await self.subscribeToEvents()
    }

    // MARK: - Event Subscription

    private func subscribeToEvents() async {
        let eventStream = await EventBus.shared.subscribe()
        for await event in eventStream {
            switch event {
//            case .tokensUpdated(_, _):
//                LogManager.logDebug("OAuthManager - Token updated event received.")
//                // Handle token updates, e.g., initiate token refresh if needed
//
//            case .tokensCleared:
//                LogManager.logDebug("OAuthManager - Tokens cleared event received. Resetting OAuth flow.")
//                await resetOAuthFlow()
//
//            case .sessionExpired:
//                LogManager.logInfo("OAuthManager - Session expired event received. Initiating re-authentication.")
//                // Optionally initiate OAuth flow again or notify the user
//
//            case .authenticationRequired:
//                LogManager.logInfo("OAuthManager - Authentication required event received.")
//                // Optionally trigger OAuth authentication flow
//
//            case .oauthFlowFailed(let error):
//                LogManager.logError("OAuthManager - OAuth flow failed with error: \(error.localizedDescription)")
//                await EventBus.shared.publish(.oauthFlowFailed(error))
//
//            case .oauthTokensReceived(let accessToken, let refreshToken):
//                LogManager.logInfo("OAuthManager - OAuth tokens received.")
//                // Handle received tokens if additional processing is needed
//
//            case .oauthFlowStarted(let url):
//                LogManager.logInfo("OAuthManager - OAuth flow started with URL: \(url.absoluteString)")
//                // Handle OAuth flow initiation if needed
//
//            case .oauthFlowCompleted:
//                LogManager.logInfo("OAuthManager - OAuth flow completed successfully.")
//
//            case .customEvent(let name, let data):
//                // Handle custom events if necessary
//                LogManager.logDebug("OAuthManager - Received custom event: \(name) with data: \(data)")
//
            default:
                break
            }
        }
    }

    // MARK: - OAuth Flow Methods

    func startOAuthFlow(identifier: String) async throws -> URL {
        resetOAuthFlow()

        // Step 1: Generate or retrieve DPoP key pair
        let privateKey = try getOrCreateDPoPKeyPair()

        // Step 2: Resolve the handle to DID
        let did = try await didResolver.resolveHandleToDID(handle: identifier)

        // Step 3: Resolve the DID to PDS URL
        let pdsURL = try await didResolver.resolveDIDToPDSURL(did: did)
        await configurationManager.updatePDSURL(pdsURL)

        // Step 4: Fetch Protected Resource Metadata
        let protectedResourceMetadata = try await fetchProtectedResourceMetadata(pdsURL: pdsURL)
        LogManager.logDebug("Protected Resource Metadata: \(protectedResourceMetadata)")

        // Step 5: Extract Authorization Server URL
        guard let authorizationServerURL = protectedResourceMetadata.authorizationServers.first else {
            LogManager.logError("Invalid Authorization Server URL: \(String(describing: protectedResourceMetadata.authorizationServers.first))")
            throw OAuthError.missingServerMetadata
        }

        // Step 6: Fetch Authorization Server Metadata
        let authServerMetadata = try await fetchAuthorizationServerMetadata(authServerURL: authorizationServerURL)
        authorizationServerMetadata = authServerMetadata

        // Step 7: Generate PKCE code verifier and challenge
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // Step 8: Generate and store state
        let state = UUID().uuidString
        try await tokenManager.storeCodeVerifier(codeVerifier, for: state)
        try await tokenManager.storeState(state)

        LogManager.logDebug("Generated code_verifier: \(codeVerifier)")
        LogManager.logDebug("Generated state: \(state)")

        // Step 9: Create Pushed Authorization Request (PAR)
        let parEndpoint = authServerMetadata.pushedAuthorizationRequestEndpoint
        let requestURI = try await pushAuthorizationRequest(
            codeChallenge: codeChallenge,
            identifier: identifier,
            endpoint: parEndpoint,
            authServerURL: authorizationServerURL,
            state: state
        )

        // Step 10: Build Authorization URL
        var components = URLComponents(string: authServerMetadata.authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "request_uri", value: requestURI),
            URLQueryItem(name: "client_id", value: oauthConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: oauthConfig.redirectUri),
        ]

        guard let authorizationURL = components.url else {
            throw OAuthError.invalidPDSURL
        }

        await EventBus.shared.publish(.oauthFlowStarted(authorizationURL))
        return authorizationURL
    }

    func pushAuthorizationRequest(
        codeChallenge: String,
        identifier: String,
        endpoint: String,
        authServerURL: URL,
        state: String
    ) async throws -> String {
        LogManager.logInfo("Starting PAR request. Current DPoP nonce: \(dpopNonces["bsky.social"] ?? "nil")")

        let parameters: [String: String] = [
            "client_id": oauthConfig.clientId,
            "code_challenge": codeChallenge,
            "code_challenge_method": "S256",
            "scope": oauthConfig.scope,
            "state": state,
            "redirect_uri": oauthConfig.redirectUri,
            "response_type": "code",
            "login_hint": identifier,
        ]

        let body = parameters.percentEncoded()
        var attempt = 0
        let maxRetries = 3

        while attempt < maxRetries {
            do {
                // Generate a new DPoP proof for each attempt - without ath claim
                let dpopProof = try createDPoPProof(for: "POST", url: endpoint)

                var request = try await networkManager.createURLRequest(
                    endpoint: endpoint,
                    method: "POST",
                    headers: [
                        "Content-Type": "application/x-www-form-urlencoded",
                        "DPoP": dpopProof,
                    ],
                    body: body,
                    queryItems: nil
                )

                LogManager.logDebug("PAR Request Headers: \(request.allHTTPHeaderFields ?? [:])")

                let (data, response) = try await networkManager.performRequest(request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.requestFailed
                }

                // Handle DPoP nonce updates
                if let newNonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce"),
                   let endpointURL = URL(string: endpoint)
                {
                    await updateDPoPNonce(for: endpointURL, from: ["DPoP-Nonce": newNonce])
                    LogManager.logInfo("Received new DPoP nonce from server: \(newNonce)")
                }

                switch httpResponse.statusCode {
                case 200, 201:
                    guard let parResponse = try? JSONDecoder().decode(PARResponse.self, from: data) else {
                        throw OAuthError.authorizationFailed
                    }
                    return parResponse.requestURI

                case 400, 401:
                    if let errorDetails = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                        switch errorDetails.error {
                        case "use_dpop_nonce":
                            attempt += 1
                            continue

                        case "invalid_dpop_proof":
                            // Clear stale state and retry
                            LogManager.logInfo("Invalid DPoP proof, regenerating state")
                            regenerateDPoPKeyPair()
                            dpopNonces.removeAll()
                            attempt += 1
                            continue

                        default:
                            throw OAuthError.authorizationFailed
                        }
                    }
                    throw OAuthError.authorizationFailed

                default:
                    throw OAuthError.authorizationFailed
                }
            } catch {
                if attempt >= maxRetries - 1 {
                    throw error
                }
                attempt += 1
                // Add exponential backoff
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
            }
        }

        throw OAuthError.maxRetriesReached
    }

    func regenerateDPoPKeyPair() {
        do {
            let newKeyPair = P256.Signing.PrivateKey()
            try KeychainManager.storeDPoPKey(newKeyPair, namespace: namespace)
            dpopKeyPair = newKeyPair
            dpopNonces = [:] // Clear all nonces when generating a new key pair
            LogManager.logInfo("Regenerated DPoP key pair and cleared all nonces")
        } catch {
            LogManager.logError("Failed to regenerate DPoP key pair: \(error)")
        }
    }

    private func resetOAuthFlow() {
        regenerateDPoPKeyPair()
    }

    func deleteDPoPKey() {
        do {
            try KeychainManager.deleteDPoPKey(namespace: namespace)
            dpopKeyPair = nil
            dpopNonces = [:]
            LogManager.logInfo("Deleted DPoP key pair and cleared nonces")
            // Optionally publish an event
            Task {
                await EventBus.shared.publish(.customEvent(name: "DPoPKeyDeleted", data: "DPoP key pair deleted and nonces cleared"))
            }
        } catch {
            LogManager.logError("Failed to delete DPoP key: \(error)")
        }
    }

    func handleCallback(url: URL) async throws -> (accessToken: String, refreshToken: String) {
        await EventBus.shared.publish(.oauthFlowStarted(url))
        guard let code = extractAuthorizationCode(from: url),
              let state = extractState(from: url),
              try await tokenManager.validateAndRetrieveState(state)
        else {
            throw OAuthError.authorizationFailed
        }

        guard let codeVerifier = try await tokenManager.retrieveCodeVerifier(for: state) else {
            throw OAuthError.authorizationFailed
        }

        let (accessToken, refreshToken) = try await exchangeCodeForTokens(code: code, codeVerifier: codeVerifier)

        // Clean up stored verifier and state
        try await tokenManager.deleteCodeVerifier(for: state)

        // After successful token exchange, update the last key regeneration time
        lastKeyRegenerationTime = Date()

        if let currentPDSURL = await configurationManager.getPDSURL() {
            LogManager.logInfo("Current PDS URL after token exchange: \(currentPDSURL.absoluteString)")
        } else {
            LogManager.logInfo("PDS URL not set after token exchange")
        }

        await EventBus.shared.publish(.oauthTokensReceived(accessToken: accessToken, refreshToken: refreshToken))
        await EventBus.shared.publish(.oauthFlowCompleted)

        return (accessToken, refreshToken)
    }

    private func fetchProtectedResourceMetadata(pdsURL: URL) async throws -> ProtectedResourceMetadata {
        let endpoint = "\(pdsURL.absoluteString)/.well-known/oauth-protected-resource"
        LogManager.logDebug("OAuthManager - Fetching Protected Resource Metadata from: \(endpoint)")
        let request = try await networkManager.createURLRequest(
            endpoint: endpoint, method: "GET", headers: [:], body: nil, queryItems: nil
        )
        let (data, _) = try await networkManager.performRequest(request)
        let metadata = try JSONDecoder().decode(ProtectedResourceMetadata.self, from: data)
        LogManager.logInfo("OAuthManager - Fetched ProtectedResourceMetadata with resource: \(metadata.resource)")
        await configurationManager.setProtectedResourceMetadata(metadata)
        await networkManager.setProtectedResourceMetadata(metadata)
        return metadata
    }

    private func fetchAuthorizationServerMetadata(authServerURL: URL) async throws -> AuthorizationServerMetadata {
        let endpoint = "\(authServerURL.absoluteString)/.well-known/oauth-authorization-server"
        let request = try await networkManager.createURLRequest(
            endpoint: endpoint, method: "GET", headers: [:], body: nil, queryItems: nil
        )
        let (data, _) = try await networkManager.performRequest(request)
        let metadata = try JSONDecoder().decode(AuthorizationServerMetadata.self, from: data)
        await configurationManager.setAuthorizationServerMetadata(metadata)
        await configurationManager.setCurrentAuthorizationServer(authServerURL)
        await networkManager.setAuthorizationServerMetadata(metadata)

        return metadata
    }

    private func verifyClientMetadata() async throws -> [String: Any] {
        guard let metadataURL = URL(string: oauthConfig.clientId) else {
            throw OAuthError.invalidClientConfiguration
        }

        let request = try await networkManager.createURLRequest(
            endpoint: metadataURL.absoluteString,
            method: "GET",
            headers: [:],
            body: nil,
            queryItems: nil
        )

        let (data, response) = try await networkManager.performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OAuthError.invalidClientConfiguration
        }

        guard let metadata = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw OAuthError.invalidClientConfiguration
        }

        LogManager.logDebug("Client Metadata: \(metadata)")
        return metadata
    }

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

    func hasValidDPoPKeyPair() async throws -> Bool {
        guard let keyPair = dpopKeyPair else {
            return false
        }

        // Optionally, add more validation logic here
        // For example, check if the key was regenerated recently
        let timeSinceLastRegeneration = Date().timeIntervalSince(lastKeyRegenerationTime)
        let maxKeyAge: TimeInterval = 60 * 60 * 24 // 24 hours

        if timeSinceLastRegeneration > maxKeyAge {
            LogManager.logInfo("OAuthManager - DPoP key pair is older than \(maxKeyAge) seconds, considered invalid.")
            return false
        }

        return true
    }

    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> (String, String) {
        guard let metadata = authorizationServerMetadata else {
            throw OAuthError.missingServerMetadata
        }

        // Create DPoP proof for token exchange
        let dpopProof = try createDPoPProof(for: "POST", url: metadata.tokenEndpoint)

        let parameters: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "code_verifier": codeVerifier,
            "client_id": oauthConfig.clientId,
            "redirect_uri": oauthConfig.redirectUri,
        ]

        let body = parameters.percentEncoded()

        let request = try await networkManager.createURLRequest(
            endpoint: metadata.tokenEndpoint,
            method: "POST",
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "DPoP": dpopProof,
            ],
            body: body,
            queryItems: nil
        )

        let (data, response) = try await networkManager.performRequest(request)

        // Log the raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            LogManager.logDebug("Token Endpoint Response: \(responseString)")
        }

        if let httpResponse = response as? HTTPURLResponse {
            if let dpopNonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce"),
               let tokenEndpointURL = URL(string: metadata.tokenEndpoint),
               let headers = httpResponse.allHeaderFields as? [String: String]
            {
                await updateDPoPNonce(for: tokenEndpointURL, from: headers)
                LogManager.logInfo("Received new DPoP nonce from server: \(dpopNonce)")
            }

            // Check for HTTP errors
            if !(200 ... 299).contains(httpResponse.statusCode) {
                // Attempt to decode the error response
                if let oauthError = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                    throw NSError(domain: "OAuthError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "\(oauthError.error): \(oauthError.errorDescription ?? "No description")"])
                } else {
                    let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                    throw NSError(domain: "OAuthError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Unexpected error: \(responseString)"])
                }
            }
        }

        // Decode the token response
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Verify the 'sub' claim
        guard let sub = tokenResponse.sub, sub.starts(with: "did:") else {
            throw OAuthError.invalidSubClaim
        }

        // After successful token exchange, resolve the PDS URL and update it
        let pdsURL = try await didResolver.resolveDIDToPDSURL(did: sub)
        await configurationManager.updatePDSURL(pdsURL)
        await EventBus.shared.publish(.baseURLUpdated(pdsURL))

        LogManager.logInfo("Switched back to PDS URL: \(pdsURL.absoluteString)")

        return (tokenResponse.accessToken, tokenResponse.refreshToken)
    }

    func refreshToken(refreshToken: String) async throws -> (String, String) {
        LogManager.logInfo("OAuthManager - Refreshing OAuth token")
        guard let metadata = authorizationServerMetadata else {
            throw OAuthError.missingServerMetadata
        }

        let parameters: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": oauthConfig.clientId,
        ]

        let body = parameters.percentEncoded()

        // Use the specialized refresh DPoP proof creator
        let dpopProof = try await createDPoPProofForRefresh(
            for: "POST",
            url: metadata.tokenEndpoint,
            refreshToken: refreshToken
        )

        var request = try await networkManager.createURLRequest(
            endpoint: metadata.tokenEndpoint,
            method: "POST",
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "DPoP": dpopProof,
            ],
            body: body,
            queryItems: nil
        )

        // Log the request for debugging
        LogManager.logDebug("Refresh Token Request: \(request)")
        LogManager.logDebug("Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")

        let (data, response) = try await networkManager.performRequest(request)

        // Log the response for debugging
        LogManager.logDebug("Refresh Token Response: \(response)")
        LogManager.logDebug("Response Body: \(String(data: data, encoding: .utf8) ?? "")")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }

        // Handle DPoP nonce update
        if let newNonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce"),
           let tokenEndpointURL = URL(string: metadata.tokenEndpoint)
        {
            await updateDPoPNonce(for: tokenEndpointURL, from: ["DPoP-Nonce": newNonce])
            LogManager.logInfo("Received new DPoP nonce: \(newNonce)")
        }

        if httpResponse.statusCode == 200 {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

            // Verify the 'sub' claim
            guard let sub = tokenResponse.sub, sub.starts(with: "did:") else {
                throw OAuthError.invalidSubClaim
            }

            // Update PDS URL
            let pdsURL = try await didResolver.resolveDIDToPDSURL(did: sub)
            await configurationManager.updatePDSURL(pdsURL)
            await networkManager.updateBaseURL(pdsURL)
            await EventBus.shared.publish(.baseURLUpdated(pdsURL))

            LogManager.logInfo("Token refreshed successfully. New PDS URL: \(pdsURL.absoluteString)")

            return (tokenResponse.accessToken, tokenResponse.refreshToken)
        } else if httpResponse.statusCode == 400 {
            if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                LogManager.logError("Token refresh failed: \(errorResponse.error) - \(errorResponse.errorDescription ?? "")")
                if errorResponse.error == "invalid_grant" {
                    // Token is expired, need to re-authenticate
                    await EventBus.shared.publish(.authenticationRequired)
                }
            }
            throw OAuthError.tokenRefreshFailed
        } else {
            // Log the error response for debugging
            if let errorBody = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                LogManager.logError("Refresh token error: \(errorBody)")
            } else {
                LogManager.logError("Refresh token error: \(String(data: data, encoding: .utf8) ?? "")")
            }
            throw OAuthError.tokenRefreshFailed
        }
    }

    private func createDPoPProofForRefresh(for httpMethod: String, url: String, refreshToken: String) async throws -> String {
        guard let privateKey = dpopKeyPair else {
            throw OAuthError.noDPoPKeyPair
        }

        let jwk = try createJWK(from: privateKey)
        let domain = URL(string: url)?.host ?? "unknown"

        // Get the DPoP binding for the domain
        var additionalClaims: [String: Any] = [:]
        if let binding = await tokenManager.getDPoPBinding(for: domain) {
            additionalClaims["cnf"] = ["jkt": binding]
            LogManager.logDebug("Including DPoP binding \(binding) for domain \(domain)")
        }

        return try createDPoPProof(
            for: httpMethod,
            url: url,
            additionalClaims: additionalClaims
        )
    }

    func initializeDPoPState() async throws {
        // Fetch the authorization server metadata if not already available
        if authorizationServerMetadata == nil {
            guard let pdsURL = await configurationManager.getPDSURL() else {
                throw OAuthError.invalidPDSURL
            }
            let protectedResourceMetadata = try await fetchProtectedResourceMetadata(pdsURL: pdsURL)
            guard let authServerURL = protectedResourceMetadata.authorizationServers.first else {
                throw OAuthError.missingServerMetadata
            }
            authorizationServerMetadata = try await fetchAuthorizationServerMetadata(authServerURL: authServerURL)
        }

        // Make a request to the token endpoint to get the initial DPoP nonce
        guard let tokenEndpoint = authorizationServerMetadata?.tokenEndpoint else {
            throw OAuthError.missingServerMetadata
        }

        let request = try await networkManager.createURLRequest(
            endpoint: tokenEndpoint,
            method: "POST",
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: nil,
            queryItems: nil
        )

        do {
            let (_, response) = try await networkManager.performRequest(request)
            if let httpResponse = response as? HTTPURLResponse,
               let newNonce = httpResponse.value(forHTTPHeaderField: "DPoP-Nonce"),
               let tokenEndpointURL = URL(string: tokenEndpoint)
            {
                await updateDPoPNonce(for: tokenEndpointURL, from: ["DPoP-Nonce": newNonce])
            }
        } catch {
            // If we get a 401, that's expected. We just need the DPoP nonce from the response.
            if let error = error as? NetworkError, case .authenticationRequired = error {
                // This is fine, we've updated the nonce in the networkManager's performRequest method
            } else {
                throw error
            }
        }
    }

    func switchToBackupAuthorizationServer() async throws {
        guard let protectedResourceMetadata = await configurationManager.getProtectedResourceMetadata(),
              let currentServer = await configurationManager.getCurrentAuthorizationServer()
        else {
            throw OAuthError.missingServerMetadata
        }

        let alternativeServers = protectedResourceMetadata.authorizationServers.filter { $0 != currentServer }
        guard let newServer = alternativeServers.first else {
            throw OAuthError.noAlternativeServersAvailable
        }

        let newMetadata = try await fetchAuthorizationServerMetadata(authServerURL: newServer)
        authorizationServerMetadata = newMetadata

        LogManager.logInfo("Switched to backup authorization server: \(newServer.absoluteString)")
    }

    // MARK: - Helper Methods

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

    func regenerateDPoPProof() async throws {
        // Regenerate the DPoP key pair
        regenerateDPoPKeyPair()

        // Initialize the DPoP state
        try await initializeDPoPState()

        LogManager.logInfo("OAuthManager - DPoP proof regenerated successfully")
    }

    private func getOrCreateDPoPKeyPair() throws -> P256.Signing.PrivateKey {
        if let existingKeyPair = dpopKeyPair {
            return existingKeyPair
        }

        do {
            // Try to retrieve from keychain
            let storedKey = try KeychainManager.retrieveDPoPKey(namespace: namespace)
            dpopKeyPair = storedKey
            return storedKey
        } catch KeychainError.itemRetrievalError {
            // Generate new key pair if not found
            let newKeyPair = P256.Signing.PrivateKey()
            try KeychainManager.storeDPoPKey(newKeyPair, namespace: namespace)
            dpopKeyPair = newKeyPair
            return newKeyPair
        }
    }

    private func calculateATH(from accessToken: String) -> String {
        let accessTokenData = Data(accessToken.utf8)
        let hash = SHA256.hash(data: accessTokenData)
        return Data(hash).base64URLEscaped()
    }

    func createDPoPProof(for httpMethod: String, url: String, additionalClaims: [String: Any]? = nil) throws -> String {
        guard let privateKey = dpopKeyPair else {
            LogManager.logError("OAuthManager - No DPoP key pair available")
            throw OAuthError.noDPoPKeyPair
        }

        let jwk = try createJWK(from: privateKey)

        let header = DefaultJWSHeaderImpl(
            algorithm: .ES256,
            jwk: jwk,
            type: "dpop+jwt"
        )

        // Basic payload - always include these
        var payload: [String: Any] = [
            "jti": UUID().uuidString,
            "htm": httpMethod,
            "htu": url,
            "iat": Int(Date().timeIntervalSince1970),
        ]

        // Add nonce if available
        if let domain = URL(string: url)?.host?.lowercased(),
           let nonce = dpopNonces[domain]
        {
            payload["nonce"] = nonce
            LogManager.logInfo("Including nonce in DPoP proof for domain \(domain): \(nonce)")
        }

        // Only include 'ath' claim for resource requests, not auth-related endpoints
        if let additional = additionalClaims {
            let isAuthEndpoint = url.contains("/oauth/") ||
                url.contains("/.well-known/oauth-authorization-server") ||
                url.contains("/.well-known/oauth-protected-resource")

            for (key, value) in additional {
                if key == "ath" && isAuthEndpoint {
                    LogManager.logDebug("Skipping ath claim for auth endpoint")
                    continue
                }
                payload[key] = value
            }
        }

        let jws = try JWS(
            payload: JSONSerialization.data(withJSONObject: payload),
            protectedHeader: header,
            key: privateKey
        )

        LogManager.logDebug("OAuthManager - Created DPoP proof for \(httpMethod) \(url)")
        return jws.compactSerialization
    }

    func generateDPoPProof(for httpMethod: String, url: String, accessToken: String? = nil) throws -> String {
        var additionalClaims: [String: Any] = [:]

        let domain = URL(string: url)?.host?.lowercased() ?? "unknown"
        if let nonce = getDPoPNonce(for: domain) {
            additionalClaims["nonce"] = nonce
        }

        if let token = accessToken {
            let athHash = calculateATH(from: token)
            additionalClaims["ath"] = athHash
        }

        return try createDPoPProof(for: httpMethod, url: url, additionalClaims: additionalClaims)
    }

    private func generateCodeVerifier() -> String {
        let verifierData = Data((0 ..< 32).map { _ in UInt8.random(in: 0 ... 255) })
        let verifier = verifierData.base64URLEscaped()
        assert(verifier.count >= 43 && verifier.count <= 128, "code_verifier length out of bounds")
        return verifier
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let verifierData = Data(verifier.utf8)
        let hash = SHA256.hash(data: verifierData)
        return Data(hash).base64URLEscaped()
    }

    func updateDPoPNonce(for url: URL, from headers: [String: String]) {
        if let newNonce = headers["dpop-nonce"] ?? headers["DPoP-Nonce"] {
            let domain = url.host?.lowercased() ?? "unknown"
            dpopNonces[domain] = newNonce
            LogManager.logInfo("Updated DPoP nonce for \(domain): \(newNonce)")
        }
    }

    func getDPoPNonce(for domain: String) -> String? {
        return dpopNonces[domain.lowercased()]
    }

    private func resolvePDSURL(for identifier: String) async throws -> URL {
        if identifier.starts(with: "did:") {
            guard let method = identifier.split(separator: ":").dropFirst().first.map({ String($0) }) else {
                throw OAuthError.invalidClientConfiguration
            }

            switch method {
            case "plc":
                return try await resolvePLCDID(identifier)
            case "web":
                return try await resolveWebDID(identifier)
            default:
                throw OAuthError.invalidClientConfiguration
            }
        } else {
            // Handle resolution
            // First, resolve the handle to a DID
            let did = try await didResolver.resolveHandleToDID(handle: identifier)

            // Then, resolve the DID to a PDS URL
            return try await didResolver.resolveDIDToPDSURL(did: did)
        }
    }

    // Resolve did:plc DIDs
    private func resolvePLCDID(_ did: String) async throws -> URL {
        let plcEndpoint = "https://plc.directory/\(did)"
        guard let url = URL(string: plcEndpoint) else {
            throw OAuthError.invalidPDSURL
        }
        let request = try await networkManager.createURLRequest(
            endpoint: url.absoluteString, method: "GET", headers: [:], body: nil, queryItems: nil
        )
        let (data, _) = try await networkManager.performRequest(request)

        let response = try JSONDecoder().decode(DIDDocument.self, from: data)
        guard let serviceURLString = response.service.first(where: { $0.type == "AtprotoPersonalDataServer" })?.serviceEndpoint,
              let serviceURL = URL(string: serviceURLString)
        else {
            throw OAuthError.invalidPDSURL
        }

        return serviceURL
    }

    // Resolve did:web DIDs
    private func resolveWebDID(_ did: String) async throws -> URL {
        // Example: did:web:example.com
        let webDID = did.replacingOccurrences(of: "did:web:", with: "")

        // Construct the well-known DID document URL
        let didDocURL = "https://\(webDID)/.well-known/did.json"
        let request = try await networkManager.createURLRequest(
            endpoint: didDocURL, method: "GET", headers: [:], body: nil, queryItems: nil
        )
        let (data, _) = try await networkManager.performRequest(request)

        // Decode the DID document from the response data
        let didDocument = try JSONDecoder().decode(DIDDocument.self, from: data)

        // Extract the PDS service URL from the array of services
        guard let serviceURLString = didDocument.service.first(where: { $0.type == "AtprotoPersonalDataServer" })?.serviceEndpoint,
              let serviceURL = URL(string: serviceURLString)
        else {
            throw OAuthError.invalidPDSURL
        }

        return serviceURL
    }

    // High-level function to get PDS URL from a handle
    func getPDSURLFromHandle(handle: String) async throws -> URL {
        // Step 1: Resolve the handle to a DID
        let did = try await didResolver.resolveHandleToDID(handle: handle)
        let pdsURL = try await didResolver.resolveDIDToPDSURL(did: did)

        return pdsURL
    }

    // MARK: - Helper Structures

    struct PARResponse: Codable {
        let requestURI: String
        let expiresIn: Int

        enum CodingKeys: String, CodingKey {
            case requestURI = "request_uri"
            case expiresIn = "expires_in"
        }
    }

    struct TokenResponse: Codable {
        let accessToken: String
        let tokenType: String
        let expiresIn: Int
        let refreshToken: String
        let scope: String
        let sub: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
            case scope
            case sub
        }
    }

    // MARK: - ProtectedResourceMetadata Structure

    struct DIDDocument: Codable {
        let service: [Service]
    }

    struct Service: Codable {
        let type: String
        let serviceEndpoint: String
    }

    // MARK: - Error Handling

    private func handleOAuthError(_ error: Error) async {
        LogManager.logError("OAuthManager - Handling OAuth error: \(error.localizedDescription)")
        await EventBus.shared.publish(.oauthFlowFailed(error))
    }
}

// MARK: - Dictionary Extension for Percent Encoding

extension Dictionary where Key == String, Value == String {
    func percentEncoded() -> Data {
        return map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            LogManager.logDebug(escapedKey + "=" + escapedValue)

            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
        .data(using: .utf8) ?? Data()
    }
}
