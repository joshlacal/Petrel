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
        case authorizationResponseIssParameterSupported =
            "authorization_response_iss_parameter_supported"
        case requestObjectSigningAlgValuesSupported = "request_object_signing_alg_values_supported"
        case requestObjectEncryptionAlgValuesSupported =
            "request_object_encryption_alg_values_supported"
        case requestObjectEncryptionEncValuesSupported =
            "request_object_encryption_enc_values_supported"
        case requestParameterSupported = "request_parameter_supported"
        case requestUriParameterSupported = "request_uri_parameter_supported"
        case requireRequestUriRegistration = "require_request_uri_registration"
        case jwksUri = "jwks_uri"
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case tokenEndpointAuthMethodsSupported = "token_endpoint_auth_methods_supported"
        case tokenEndpointAuthSigningAlgValuesSupported =
            "token_endpoint_auth_signing_alg_values_supported"
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

// MARK: - OAuthManagerDelegate Protocol

protocol OAuthManagerDelegate: AnyObject, Sendable {
    func dpopKeyDeleted(forDID did: String) async
    func allDPoPKeysDeleted() async
}

actor OAuthManager {
    // MARK: - Properties

    private let networkManager: NetworkManaging
    private let configurationManager: ConfigurationManaging
    private let tokenManager: TokenManaging
    private let didResolver: DIDResolving
    private var authorizationServerMetadata: AuthorizationServerMetadata?
    private var protectedResourceMetadata: ProtectedResourceMetadata?
    private var dpopKeyPairs: [String: P256.Signing.PrivateKey] = [:] // Map of DID -> private key
    private let oauthConfig: OAuthConfiguration
    private var lastKeyRegenerationTime: Date
    private var dpopNonces: [String: [String: String]] = [:] // Map of DID -> [domain: nonce]
    private let namespace: String
    private let dpopKeyTagBase: String // Base tag that will be combined with DIDs
    private var currentDID: String? // Track current DID for key operations
    private weak var delegate: OAuthManagerDelegate?

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
        dpopKeyTagBase = "\(namespace).dpopkeypair"

        // Initialize stored properties
        lastKeyRegenerationTime = Date()
        dpopNonces = [:]
        authorizationServerMetadata = await configurationManager.getAuthorizationServerMetadata()
        protectedResourceMetadata = await configurationManager.getProtectedResourceMetadata()

        // Get the current DID for initializing DPoP state
        currentDID = await tokenManager.getCurrentDID()

        // If we have a current DID, try to load its DPoP key
        if let did = currentDID {
            await loadDPoPKeyForDID(did)
        }
    }

    // MARK: - Delegate Management

    func setDelegate(_ delegate: OAuthManagerDelegate?) {
        self.delegate = delegate
    }

    // MARK: - DID-specific key management

    private func getDPoPKeyTag(forDID did: String) -> String {
        return "\(dpopKeyTagBase).\(did)"
    }

    private func loadDPoPKeyForDID(_ did: String) async {
        do {
            let keyTag = getDPoPKeyTag(forDID: did)
            let privateKey = try KeychainManager.retrieveDPoPKey(keyTag: keyTag)
            dpopKeyPairs[did] = privateKey
            currentDID = did
            LogManager.logInfo("OAuthManager - Loaded DPoP key for DID: \(did)")
        } catch {
            LogManager.logDebug(
                "OAuthManager - No existing DPoP key for DID: \(did), will generate if needed")
        }
    }

    private func getOrCreateDPoPKeyForDID(_ did: String) throws -> P256.Signing.PrivateKey {
        // If we already have a key in memory for this DID, use it
        if let existingKey = dpopKeyPairs[did] {
            return existingKey
        }

        // Try to retrieve from keychain
        let keyTag = getDPoPKeyTag(forDID: did)
        do {
            let storedKey = try KeychainManager.retrieveDPoPKey(keyTag: keyTag)
            dpopKeyPairs[did] = storedKey
            return storedKey
        } catch {
            // Generate new key if not found
            let newKeyPair = P256.Signing.PrivateKey()
            try KeychainManager.storeDPoPKey(newKeyPair, keyTag: keyTag)
            dpopKeyPairs[did] = newKeyPair
            return newKeyPair
        }
    }

    // MARK: - DID-specific nonce management

    private func getDPoPNonceForDID(_ did: String, domain: String) -> String? {
        return dpopNonces[did]?[domain.lowercased()]
    }

    private func updateDPoPNonceForDID(_ did: String, domain: String, nonce: String) {
        if dpopNonces[did] == nil {
            dpopNonces[did] = [:]
        }
        dpopNonces[did]?[domain.lowercased()] = nonce
        LogManager.logInfo(
            "OAuthManager - Updated DPoP nonce for DID \(did), domain \(domain): \(nonce)")
    }

    // Update the existing updateDPoPNonce method to use the DID-specific version
    func updateDPoPNonce(for url: URL, from headers: [String: String]) async {
        if let newNonce = headers["dpop-nonce"] ?? headers["DPoP-Nonce"] {
            let domain = url.host?.lowercased() ?? "unknown"
            let did = currentDID ?? "default"
            updateDPoPNonceForDID(did, domain: domain, nonce: newNonce)
        }
    }

    // MARK: - DPoP Key Management

    func initializeDPoPState() async throws {
        // Get the current DID - use it for key operations
        if let did = await tokenManager.getCurrentDID() {
            currentDID = did
        }

        // Fetch the authorization server metadata if not already available
        if authorizationServerMetadata == nil {
            guard let pdsURL = await configurationManager.getPDSURL() else {
                throw OAuthError.invalidPDSURL
            }
            let protectedResourceMetadata = try await fetchProtectedResourceMetadata(pdsURL: pdsURL)
            guard let authServerURL = protectedResourceMetadata.authorizationServers.first else {
                throw OAuthError.missingServerMetadata
            }
            authorizationServerMetadata = try await fetchAuthorizationServerMetadata(
                authServerURL: authServerURL)
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
            // No need to cast response, it's already HTTPURLResponse
            if let newNonce = response.value(forHTTPHeaderField: "DPoP-Nonce"),
               let tokenEndpointURL = URL(string: tokenEndpoint),
               let did = currentDID
            {
                updateDPoPNonceForDID(did, domain: tokenEndpointURL.host ?? "unknown", nonce: newNonce)
            }
        } catch {
            // If we get a 401, that's expected. We just need the DPoP nonce from the response.
            if let error = error as? NetworkError, case .authenticationRequired = error {
                LogManager.logInfo("OAuthManager - Received expected 401 when fetching DPoP nonce")
            } else {
                LogManager.logError("OAuthManager - Error when fetching DPoP nonce: \(error)")
            }
        }
    }

    // MARK: - DPoP Key Operations

    private func getOrCreateDPoPKeyPair() throws -> P256.Signing.PrivateKey {
        guard let did = currentDID else {
            // If no current DID, use a temporary key
            return P256.Signing.PrivateKey()
        }

        return try getOrCreateDPoPKeyForDID(did)
    }

    func regenerateDPoPKeyPair() {
        guard let did = currentDID else {
            LogManager.logError("OAuthManager - Cannot regenerate DPoP key pair: No current DID")
            return
        }

        do {
            let newKeyPair = P256.Signing.PrivateKey()
            let keyTag = getDPoPKeyTag(forDID: did)
            try KeychainManager.storeDPoPKey(newKeyPair, keyTag: keyTag)
            dpopKeyPairs[did] = newKeyPair

            // Clear nonces for this DID
            dpopNonces[did] = [:]

            LogManager.logInfo(
                "OAuthManager - Regenerated DPoP key pair for DID: \(did) and cleared nonces")
        } catch {
            LogManager.logError("OAuthManager - Failed to regenerate DPoP key pair: \(error)")
        }
    }

    func deleteDPoPKey() async {
        if let did = currentDID {
            do {
                // Delete the DPoP key for the current DID
                let keyTag = getDPoPKeyTag(forDID: did)
                try KeychainManager.deleteDPoPKey(keyTag: keyTag)

                // Remove from in-memory storage
                dpopKeyPairs.removeValue(forKey: did)
                dpopNonces.removeValue(forKey: did)

                LogManager.logInfo("OAuthManager - Deleted DPoP key pair for DID: \(did)")

                // Notify delegate instead of using EventBus
                if let delegate = delegate {
                    await delegate.dpopKeyDeleted(forDID: did)
                }
            } catch {
                LogManager.logError("OAuthManager - Failed to delete DPoP key for DID \(did): \(error)")
            }
        } else {
            LogManager.logInfo("OAuthManager - No current DID, cannot delete specific DPoP key")
        }
    }

    func deleteAllDPoPKeys() async {
        do {
            // Delete all DPoP keys in memory
            dpopKeyPairs.removeAll()
            dpopNonces.removeAll()

            // Legacy key deletion for backward compatibility
            try KeychainManager.deleteDPoPKey(namespace: namespace)
            try KeychainManager.deleteDPoPKeyBindings(namespace: namespace)

            LogManager.logInfo("OAuthManager - Deleted all DPoP keys and cleared nonces")

            // Notify delegate instead of using EventBus
            if let delegate = delegate {
                await delegate.allDPoPKeysDeleted()
            }
        } catch {
            LogManager.logError("OAuthManager - Failed to delete all DPoP keys: \(error)")
        }
    }

    // MARK: - DPoP Proof Generation

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

    func createDPoPProof(for httpMethod: String, url: String, additionalClaims: [String: Any]? = nil)
        throws -> String
    {
        // Get the current DID's key or a temporary one if no current DID
        let privateKey: P256.Signing.PrivateKey
        if let did = currentDID, let key = dpopKeyPairs[did] {
            privateKey = key
        } else {
            guard let key = try? getOrCreateDPoPKeyPair() else {
                LogManager.logError("OAuthManager - No DPoP key pair available")
                throw OAuthError.noDPoPKeyPair
            }
            privateKey = key
        }

        let _ = try createJWK(from: privateKey) // Use '_' for unused jwk

        let header = try DefaultJWSHeaderImpl(
            algorithm: .ES256,
            jwk: createJWK(from: privateKey), // Recreate JWK here as it's needed
            type: "dpop+jwt"
        )

        // Basic payload - always include these
        var payload: [String: Any] = [
            "jti": UUID().uuidString,
            "htm": httpMethod,
            "htu": url,
            "iat": Int(Date().timeIntervalSince1970),
        ]

        // Add nonce if available for the current DID and domain
        if let did = currentDID,
           let domain = URL(string: url)?.host?.lowercased(),
           let nonce = getDPoPNonceForDID(did, domain: domain)
        {
            payload["nonce"] = nonce
            LogManager.logInfo("Including nonce in DPoP proof for DID \(did), domain \(domain): \(nonce)")
        }

        // Only include 'ath' claim for resource requests, not auth-related endpoints
        if let additional = additionalClaims {
            let isAuthEndpoint =
                url.contains("/oauth/") || url.contains("/.well-known/oauth-authorization-server")
                    || url.contains("/.well-known/oauth-protected-resource")

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

    func generateDPoPProof(for httpMethod: String, url: String, accessToken: String? = nil) throws
        -> String
    {
        var additionalClaims: [String: Any] = [:]

        let domain = URL(string: url)?.host?.lowercased() ?? "unknown"
        if let did = currentDID, let nonce = getDPoPNonceForDID(did, domain: domain) {
            additionalClaims["nonce"] = nonce
        }

        if let token = accessToken {
            let athHash = calculateATH(from: token)
            additionalClaims["ath"] = athHash
        }

        return try createDPoPProof(for: httpMethod, url: url, additionalClaims: additionalClaims)
    }

    private func createDPoPProofForRefresh(for httpMethod: String, url: String, refreshToken: String)
        async throws -> String
    {
        guard let did = currentDID, dpopKeyPairs[did] != nil else { // Use '_' for unused privateKey
            throw OAuthError.noDPoPKeyPair
        }

        // let jwk = try createJWK(from: privateKey) // No longer needed here
        let domain = URL(string: url)?.host ?? "unknown"

        // For refresh token, we don't include the token hash, but we do need the nonce
        var additionalClaims: [String: Any] = [:]

        // Get the DPoP binding for the domain if available
        if let binding = await tokenManager.getDPoPBinding(for: domain) {
            additionalClaims["cnf"] = ["jkt": binding]
        }

        // Get nonce for this domain if available
        if let nonce = getDPoPNonceForDID(did, domain: domain) {
            additionalClaims["nonce"] = nonce
        }

        return try createDPoPProof(
            for: httpMethod,
            url: url,
            additionalClaims: additionalClaims
        )
    }

    // MARK: - Utility Methods

    private func calculateATH(from accessToken: String) -> String {
        let accessTokenData = Data(accessToken.utf8)
        let hash = SHA256.hash(data: accessTokenData)
        return Data(hash).base64URLEscaped()
    }

    private func resetOAuthFlow() {
        if let did = currentDID {
            // Clear nonces for the current DID
            dpopNonces[did] = [:]
        }
    }

    // Other methods remain the same...

    // MARK: - OAuth Flow Methods

    func startOAuthFlow(identifier: String) async throws -> URL {
        resetOAuthFlow()

        // Step 1: Resolve the handle to DID FIRST
        let did = try await didResolver.resolveHandleToDID(handle: identifier)
        await tokenManager.setCurrentDID(did) // Set current DID early in TokenManager
        currentDID = did // Update actor's currentDID
        await configurationManager.updateHandle(identifier)

        // Step 1.5: Generate or retrieve DPoP key pair FOR THE RESOLVED DID
        let _ = try getOrCreateDPoPKeyPair() // Now uses the correct currentDID

        // Step 2: Resolve the DID to PDS URL (already have DID)
        let pdsURL = try await didResolver.resolveDIDToPDSURL(did: did)
        // CRITICAL FIX: Use the explicit forDID parameter to save the PDS URL
        await configurationManager.updatePDSURL(pdsURL, forDID: did)

        // Step 4: Fetch Protected Resource Metadata
        let protectedResourceMetadata = try await fetchProtectedResourceMetadata(pdsURL: pdsURL)
        LogManager.logDebug("Protected Resource Metadata: \(protectedResourceMetadata)")

        // Step 5: Extract Authorization Server URL
        guard let authorizationServerURL = protectedResourceMetadata.authorizationServers.first else {
            LogManager.logError(
                "Invalid Authorization Server URL: \(String(describing: protectedResourceMetadata.authorizationServers.first))"
            )
            throw OAuthError.missingServerMetadata
        }

        // Step 6: Fetch Authorization Server Metadata
        let authServerMetadata = try await fetchAuthorizationServerMetadata(
            authServerURL: authorizationServerURL)
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

        return authorizationURL
    }

    func pushAuthorizationRequest(
        codeChallenge: String,
        identifier: String,
        endpoint: String,
        authServerURL: URL,
        state: String
    ) async throws -> String {
        LogManager.logInfo(
            "Starting PAR request. Current DPoP nonce: \(dpopNonces[currentDID ?? "default"]?["bsky.social"] ?? "nil")"
        )

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

                let request = try await networkManager.createURLRequest(
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
                // No need to cast response, it's already HTTPURLResponse

                // Handle DPoP nonce updates
                if let newNonce = response.value(forHTTPHeaderField: "DPoP-Nonce"),
                   let endpointURL = URL(string: endpoint)
                {
                    await updateDPoPNonce(for: endpointURL, from: ["DPoP-Nonce": newNonce]) // Fixed argument type
                    LogManager.logInfo("Received new DPoP nonce from server: \(newNonce)")
                }

                switch response.statusCode { // Use response directly
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

    func handleCallback(url: URL) async throws -> (accessToken: String, refreshToken: String) {
        guard let code = extractAuthorizationCode(from: url),
              let state = extractState(from: url),
              try await tokenManager.validateAndRetrieveState(state)
        else {
            throw OAuthError.authorizationFailed
        }

        guard let codeVerifier = try await tokenManager.retrieveCodeVerifier(for: state) else {
            throw OAuthError.authorizationFailed
        }

        let (accessToken, refreshToken) = try await exchangeCodeForTokens(
            code: code, codeVerifier: codeVerifier
        )

        // Clean up stored verifier and state
        try await tokenManager.deleteCodeVerifier(for: state)

        // After successful token exchange, update the last key regeneration time
        lastKeyRegenerationTime = Date()

        if let currentPDSURL = await configurationManager.getPDSURL() {
            LogManager.logInfo("Current PDS URL after token exchange: \(currentPDSURL.absoluteString)")
        } else {
            LogManager.logInfo("PDS URL not set after token exchange")
        }

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
        LogManager.logInfo(
            "OAuthManager - Fetched ProtectedResourceMetadata with resource: \(metadata.resource)")

        // Pass the current DID to ensure correct storage
        await configurationManager.setProtectedResourceMetadata(metadata, forDID: currentDID)
        await networkManager.setProtectedResourceMetadata(metadata)

        return metadata
    }

    private func fetchAuthorizationServerMetadata(authServerURL: URL) async throws
        -> AuthorizationServerMetadata
    {
        let endpoint = "\(authServerURL.absoluteString)/.well-known/oauth-authorization-server"
        let request = try await networkManager.createURLRequest(
            endpoint: endpoint, method: "GET", headers: [:], body: nil, queryItems: nil
        )
        let (data, _) = try await networkManager.performRequest(request)
        let metadata = try JSONDecoder().decode(AuthorizationServerMetadata.self, from: data)

        // Pass the current DID to ensure correct storage
        await configurationManager.setAuthorizationServerMetadata(metadata, forDID: currentDID)
        await configurationManager.setCurrentAuthorizationServer(authServerURL, forDID: currentDID)
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

        // No need to cast response, it's already HTTPURLResponse
        guard response.statusCode == 200 else {
            throw OAuthError.invalidClientConfiguration
        }

        guard
            let metadata = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else {
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
        guard dpopKeyPairs[currentDID ?? "default"] != nil else {
            return false
        }

        // Optionally, add more validation logic here
        // For example, check if the key was regenerated recently
        let timeSinceLastRegeneration = Date().timeIntervalSince(lastKeyRegenerationTime)
        let maxKeyAge: TimeInterval = 60 * 60 * 24 // 24 hours

        if timeSinceLastRegeneration > maxKeyAge {
            LogManager.logInfo(
                "OAuthManager - DPoP key pair is older than \(maxKeyAge) seconds, considered invalid.")
            return false
        }

        return true
    }

    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> (
        String, String
    ) {
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

        // No need to cast response, it's already HTTPURLResponse
        if let dpopNonce = response.value(forHTTPHeaderField: "DPoP-Nonce"),
           let tokenEndpointURL = URL(string: metadata.tokenEndpoint),
           let headers = response.allHeaderFields as? [String: String]
        {
            await updateDPoPNonce(for: tokenEndpointURL, from: headers)
            LogManager.logInfo("Received new DPoP nonce from server: \(dpopNonce)")
        }

        // Check for HTTP errors
        if !(200 ... 299).contains(response.statusCode) {
            // Attempt to decode the error response
            if let oauthError = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                throw NSError(
                    domain: "OAuthError", code: response.statusCode,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "\(oauthError.error): \(oauthError.errorDescription ?? "No description")",
                    ]
                ) // Corrected closing parenthesis and bracket
            } else {
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                throw NSError(
                    domain: "OAuthError", code: response.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Unexpected error: \(responseString)"]
                )
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

        let request = try await networkManager.createURLRequest( // Changed var to let
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
        LogManager.logDebug(
            "Request Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")")

        let (data, response) = try await networkManager.performRequest(request)

        // Log the response for debugging
        LogManager.logDebug("Refresh Token Response: \(response)")
        LogManager.logDebug("Response Body: \(String(data: data, encoding: .utf8) ?? "")")

        // response is already HTTPURLResponse, no need for guard let or cast

        // Handle DPoP nonce update
        if let newNonce = response.value(forHTTPHeaderField: "DPoP-Nonce"),
           let tokenEndpointURL = URL(string: metadata.tokenEndpoint)
        {
            await updateDPoPNonce(for: tokenEndpointURL, from: ["DPoP-Nonce": newNonce])
            LogManager.logInfo("Received new DPoP nonce: \(newNonce)")
        }

        if response.statusCode == 200 {
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

            // Verify the 'sub' claim
            guard let sub = tokenResponse.sub, sub.starts(with: "did:") else {
                throw OAuthError.invalidSubClaim
            }

            // Update PDS URL
            let pdsURL = try await didResolver.resolveDIDToPDSURL(did: sub)
            await configurationManager.updatePDSURL(pdsURL)
            await networkManager.updateBaseURL(pdsURL)

            LogManager.logInfo("Token refreshed successfully. New PDS URL: \(pdsURL.absoluteString)")

            return (tokenResponse.accessToken, tokenResponse.refreshToken)
        } else if response.statusCode == 400 {
            if let errorResponse = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
                LogManager.logError(
                    "Token refresh failed: \(errorResponse.error) - \(errorResponse.errorDescription ?? "")")
                if errorResponse.error == "invalid_grant" {
                    // Token is expired, need to re-authenticate
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

    func switchToBackupAuthorizationServer() async throws {
        guard let protectedResourceMetadata = await configurationManager.getProtectedResourceMetadata(),
              let currentServer = await configurationManager.getCurrentAuthorizationServer()
        else {
            throw OAuthError.missingServerMetadata
        }

        let alternativeServers = protectedResourceMetadata.authorizationServers.filter {
            $0 != currentServer
        }
        guard let newServer = alternativeServers.first else {
            throw OAuthError.noAlternativeServersAvailable
        }

        let newMetadata = try await fetchAuthorizationServerMetadata(authServerURL: newServer)
        authorizationServerMetadata = newMetadata

        LogManager.logInfo("Switched to backup authorization server: \(newServer.absoluteString)")
    }

    // MARK: - Helper Methods (Single copy)

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

    func getDPoPNonce(for domain: String) -> String? {
        return dpopNonces[currentDID ?? "default"]?[domain.lowercased()]
    }

    private func resolvePDSURL(for identifier: String) async throws -> URL {
        if identifier.starts(with: "did:") {
            guard let method = identifier.split(separator: ":").dropFirst().first.map({ String($0) })
            else {
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
        guard
            let serviceURLString = response.service.first(where: {
                $0.type == "AtprotoPersonalDataServer"
            })?.serviceEndpoint,
            let serviceURL = URL(string: serviceURLString)
                
        else {
            throw OAuthError.invalidPDSURL
        }
        
        if let handle = response.alsoKnownAs.first {
            let handleString = handle.hasPrefix("at://") ? String(handle.dropFirst(5)) : handle
            try await configurationManager.updateUserConfiguration(did: response.id, handle: handleString, serviceEndpoint: serviceURLString)
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
        guard
            let serviceURLString = didDocument.service.first(where: {
                $0.type == "AtprotoPersonalDataServer"
            })?.serviceEndpoint,
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

//    struct DIDDocument: Codable {
//        let service: [Service]
//    }
//
//    struct Service: Codable {
//        let type: String
//        let serviceEndpoint: String
//    }

    // MARK: - Error Handling

    private func handleOAuthError(_ error: Error) async {
        LogManager.logError("OAuthManager - Handling OAuth error: \(error.localizedDescription)")
    }

    private func extractDIDFromToken(_ token: String) async throws -> String {
        let components = token.components(separatedBy: ".")
        guard components.count >= 2 else {
            throw OAuthError.invalidToken
        }

        let payloadBase64 = components[1]
        guard let payloadData = Data(base64Encoded: payloadBase64.base64URLUnescaped()) else {
            throw OAuthError.invalidToken
        }

        guard let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let sub = payload["sub"] as? String,
              sub.starts(with: "did:")
        else {
            throw OAuthError.invalidSubClaim
        }

        LogManager.logDebug("OAuthManager - Extracted DID from token: \(sub)")
        return sub
    }
}

// MARK: - Dictionary Extension for Percent Encoding

extension Dictionary where Key == String, Value == String {
    func percentEncoded() -> Data {
        return map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue =
                value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            LogManager.logDebug(escapedKey + "=" + escapedValue)

            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
        .data(using: .utf8) ?? Data()
    }
}
