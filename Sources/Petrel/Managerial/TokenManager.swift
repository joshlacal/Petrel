//
//  TokenManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/21/24.
//

import Foundation
import JSONWebKey
import JSONWebSignature
import JSONWebToken

// MARK: - TokenType Enumeration

public enum TokenType: String, Codable {
    case bearer // Legacy authentication
    case dpop // OAuth authentication
}

// MARK: - TokenManaging Protocol

protocol TokenManaging: Actor {
    func isTokenCloseToExpiration(token: String) async -> Bool
    func hasAnyTokens() async -> Bool
    func fetchAuthServerMetadataAndJWKS(baseURL: URL) async throws
    func deleteTokens() async throws
    func deleteTokensForDID(_ did: String) async throws
    func hasValidTokens() async -> Bool
    func saveTokens(accessJwt: String?, refreshJwt: String?, type: TokenType, domain: String?)
        async throws
    func shouldRefreshTokens() async -> Bool
    func fetchRefreshToken() async -> String?
    func fetchAccessToken() async -> String?
    func fetchRefreshToken(did: String) async -> String?
    func fetchAccessToken(did: String) async -> String?
    func decodeJWT(token: String) async -> OAuthClaims?
    func isTokenExpired(token: String) async -> Bool
    func storeCodeVerifier(_ codeVerifier: String, for state: String) async throws
    func retrieveCodeVerifier(for state: String) async throws -> String?
    func deleteCodeVerifier(for state: String) async throws
    func storeState(_ state: String) async throws
    func retrieveState(_ state: String) async throws -> String?
    func deleteState(_ state: String) async throws
    func validateAndRetrieveState(_ state: String) async throws -> Bool
    func getDPoPBinding(for domain: String) async -> String?
    func listStoredDIDs() async -> [String]
    func getTokenType(did: String?) async -> TokenType?
    func setCurrentDID(_ did: String) async
    func getCurrentDID() async -> String?
    func clearDPoPBindingsForDID(_ did: String) async
}

// MARK: - TokenDelegate Protocol

// Removed the TokenDelegate protocol to eliminate direct dependencies.
// Token updates will now be communicated via the EventBus.

// MARK: - TokenManager Actor

public actor TokenManager: TokenManaging {
    private let namespace: String
    private var accessJwt: String?
    private var refreshJwt: String?
    private var tokenType: TokenType?
    private var jwks: JWKSet?
    private var authServerMetadata: AuthorizationServerMetadata?
    private var isJWKSFetched = false
    private var currentDID: String? // Track the current active DID

    // Internal dictionaries to associate state with code_verifier
    private var codeVerifiers: [String: String] = [:]
    private var states: Set<String> = []

    private var isInitialized = false

    private let dpopBindingsKey = "dpopKeyBindings"
    private let didsListKey = "storedDIDs" // Key to store list of DIDs

    // Store DPoP key binding info per domain and per DID
    private var dpopKeyBindings: [String: [String: String]] = [:] // [did: [domain: binding]]

    private func loadDPoPBindings() {
        // Load global bindings first (for backward compatibility)
        do {
            let data = try KeychainManager.retrieve(key: dpopBindingsKey, namespace: namespace)
            if let globalBindings = try? JSONDecoder().decode([String: String].self, from: data) {
                // Store global bindings under a "global" key to preserve them
                dpopKeyBindings["global"] = globalBindings
                LogManager.logDebug("TokenManager - Loaded global DPoP bindings from Keychain")
            }
        } catch {
            LogManager.logError("Failed to load global DPoP bindings: \(error)")
        }

        // Now load any DID-specific bindings
        // Using Task to handle the async call properly
        Task {
            let dids = await listStoredDIDs()
            for did in dids {
                do {
                    let didBindingsKey = "\(dpopBindingsKey).\(did)"
                    let data = try KeychainManager.retrieve(key: didBindingsKey, namespace: namespace)
                    if let didBindings = try? JSONDecoder().decode([String: String].self, from: data) {
                        dpopKeyBindings[did] = didBindings
                        LogManager.logDebug("TokenManager - Loaded DPoP bindings for DID \(did)")
                    }
                } catch {
                    LogManager.logDebug("No DPoP bindings found for DID \(did): \(error)")
                }
            }
        }
    }

    private func saveDPoPBindingsForDID(_ did: String) throws {
        guard let bindings = dpopKeyBindings[did] else {
            return // No bindings to save for this DID
        }

        let didBindingsKey = "\(dpopBindingsKey).\(did)"
        let data = try JSONEncoder().encode(bindings)
        try KeychainManager.store(key: didBindingsKey, value: data, namespace: namespace)
        LogManager.logDebug("TokenManager - Saved DPoP bindings for DID \(did) to Keychain")
    }

    private func saveDPoPBindings() throws {
        // Save global bindings for backward compatibility
        if let globalBindings = dpopKeyBindings["global"] {
            let data = try JSONEncoder().encode(globalBindings)
            try KeychainManager.store(key: dpopBindingsKey, value: data, namespace: namespace)
            LogManager.logDebug("TokenManager - Saved global DPoP bindings to Keychain")
        }

        // Save DID-specific bindings
        for did in dpopKeyBindings.keys where did != "global" {
            try saveDPoPBindingsForDID(did)
        }
    }

    func clearDPoPBindingsForDID(_ did: String) async {
        dpopKeyBindings.removeValue(forKey: did)
        do {
            try KeychainManager.deleteDPoPKeyBindingsForDID(namespace: namespace, did: did)
            LogManager.logDebug("TokenManager - Cleared DPoP bindings for DID \(did)")
        } catch {
            LogManager.logError("Failed to clear DPoP bindings for DID \(did): \(error)")
        }
    }

    // Update init to load bindings
    init(namespace: String) async {
        self.namespace = namespace

        // NEW: Try to load the last active DID first
        if let lastActiveDID = await TokenManager.getLastActiveDID(namespace: namespace) {
            currentDID = lastActiveDID
            LogManager.logInfo("TokenManager - Restored last active DID: \(lastActiveDID)")
        }

        await loadInitialTokens()
        loadDPoPBindings()
        LogManager.logDebug("Token Manager initialized")
    }

    private func loadInitialTokens() async {
        // First try to load tokens for the current DID if we have one
        if let did = currentDID {
            LogManager.logInfo("TokenManager - Loading tokens for DID: \(did)")
            await loadTokensForDID(did)
            return
        }

        // Fallback to loading tokens with default keys
        if let data = try? KeychainManager.retrieve(key: "tokenType", namespace: namespace),
           let type = try? JSONDecoder().decode(TokenType.self, from: data)
        {
            tokenType = type
            LogManager.logDebug("TokenManager - Initialized with token type: \(type.rawValue)")
        } else {
            LogManager.logDebug("TokenManager - No token type found in Keychain")
        }

        if let accessData = try? KeychainManager.retrieve(key: "accessJwt", namespace: namespace),
           let savedAccessToken = String(data: accessData, encoding: .utf8)
        {
            accessJwt = savedAccessToken
            LogManager.logDebug("TokenManager - Loaded accessJwt from Keychain")
        }

        if let refreshData = try? KeychainManager.retrieve(key: "refreshJwt", namespace: namespace),
           let savedRefreshToken = String(data: refreshData, encoding: .utf8)
        {
            refreshJwt = savedRefreshToken
            LogManager.logDebug("TokenManager - Loaded refreshJwt from Keychain")
        }
    }

    // MARK: - Token Management Methods

    public func fetchAuthServerMetadataAndJWKS(baseURL: URL) async throws {
        let metadataURL = baseURL.appendingPathComponent(".well-known/oauth-authorization-server")
        let (metadataData, _) = try await URLSession.shared.data(from: metadataURL)
        authServerMetadata = try JSONDecoder().decode(
            AuthorizationServerMetadata.self, from: metadataData
        )

        guard let jwksUri = authServerMetadata?.jwksUri, let jwksURL = URL(string: jwksUri) else {
            throw TokenError.missingJWKSURI
        }

        let (jwksData, _) = try await URLSession.shared.data(from: jwksURL)
        jwks = try JSONDecoder().decode(JWKSet.self, from: jwksData)
        isJWKSFetched = true
    }

    public func deleteTokens() async throws {
        // Delete both Legacy and OAuth tokens
        try KeychainManager.delete(key: "accessJwt", namespace: namespace)
        try KeychainManager.delete(key: "refreshJwt", namespace: namespace)
        try KeychainManager.delete(key: "tokenType", namespace: namespace)

        // Reset in-memory tokens
        accessJwt = nil
        refreshJwt = nil
        tokenType = nil

        // Publish token cleared event
        await EventBus.shared.publish(.tokensCleared)
        LogManager.logInfo("TokenManager - Tokens cleared successfully.")
    }

    public func hasValidTokens() async -> Bool {
        guard let accessToken = await fetchAccessToken(),
              let refreshToken = await fetchRefreshToken()
        else {
            return false
        }

        // Check if access token is expired
        if await isTokenExpired(token: accessToken) {
            // If access token is expired, check if refresh token is still valid
            if await isTokenExpired(token: refreshToken) {
                // Trigger a token refresh
                await EventBus.shared.publish(.tokenExpired)
                return false
            } else {
                return false
            }
        }

        return true
    }

    func isTokenCloseToExpiration(token: String) async -> Bool {
        guard let payload = await decodeJWT(token: token),
              let expDate = payload.exp
        else {
            return true // If we can't decode or there's no expiration, assume it needs refresh
        }

        let currentDate = Date()
        let timeInterval = expDate.timeIntervalSince(currentDate)

        // Consider the token close to expiration if it's within 5 minutes of expiring
        return timeInterval <= 300
    }

    public func isTokenExpired(token: String) async -> Bool {
        // If it's a refresh token, we can't determine expiration this way
        if token.starts(with: "ref-") {
            LogManager.logDebug("TokenManager - Refresh token, cannot determine expiration")
            return false // Assume refresh tokens are not expired
        }

        do {
            let payload = try verifyToken(token)
            if let expDate = payload.exp {
                let isExpired = Date() >= expDate
                LogManager.logDebug(
                    "TokenManager - Token expiration check: \(isExpired ? "expired" : "valid") (Expires: \(expDate))"
                )
                return isExpired
            }
            LogManager.logDebug("TokenManager - Token has no expiration date")
            return true // If there's no expiration date, consider it expired
        } catch {
            LogManager.logError("TokenManager - Error verifying token: \(error)")
            return true // If verification fails, consider it expired
        }
    }

    func shouldRefreshTokens() async -> Bool {
        guard let accessToken = await fetchAccessToken(),
              let claims = await decodeJWT(token: accessToken),
              let expiration = claims.exp
        else {
            return true
        }

        let currentTime = Date()
        let timeRemaining = expiration.timeIntervalSince(currentTime)

        LogManager.logInfo(
            """
            Token check:
            Current time: \(currentTime)
            Token expires: \(expiration)
            Time remaining: \(Int(timeRemaining))s
            """)

        if timeRemaining <= 0 {
            LogManager.logInfo("Token has expired")
            return true
        }

        // Refresh if less than 5 minutes remaining
        if timeRemaining <= 300 {
            LogManager.logInfo("Token expires soon (in \(Int(timeRemaining))s)")
            return true
        }

        return false
    }

    func hasAnyTokens() async -> Bool {
        return accessJwt != nil || refreshJwt != nil
    }

    // Update the getDPoPBinding method to check DID-specific bindings first
    public func getDPoPBinding(for domain: String) async -> String? {
        // If we have a current DID, check its specific bindings first
        if let did = currentDID, let didBindings = dpopKeyBindings[did],
           let binding = didBindings[domain]
        {
            return binding
        }

        // Fall back to global bindings if no DID-specific binding is found
        return dpopKeyBindings["global"]?[domain]
    }

    // Save the binding when tokens are saved
    public func saveTokens(
        accessJwt: String?, refreshJwt: String?, type: TokenType, domain: String? = nil
    ) async throws {
        self.accessJwt = accessJwt
        self.refreshJwt = refreshJwt
        tokenType = type

        // Extract and store DPoP binding from access token if present
        if let accessJwt = accessJwt,
           let jwt = try? JWT(jwtString: accessJwt),
           let claims = try? JSONDecoder().decode(OAuthClaims.self, from: jwt.payload),
           let cnf = claims.cnf,
           let domain = domain,
           let did = currentDID
        {
            // If we don't have an entry for this DID yet, create one
            if dpopKeyBindings[did] == nil {
                dpopKeyBindings[did] = [:]
            }

            // Store the binding for this DID and domain
            dpopKeyBindings[did]?[domain] = cnf.jkt

            do {
                try saveDPoPBindingsForDID(did)
                LogManager.logDebug("TokenManager - Stored DPoP binding for DID \(did), domain \(domain)")
            } catch {
                LogManager.logError("Failed to save DPoP bindings for DID \(did): \(error)")
            }
        }

        LogManager.logDebug(
            "TokenManager - Saving tokens. Access JWT: \(accessJwt?.prefix(30) ?? "nil")..., Refresh JWT: \(refreshJwt?.prefix(30) ?? "nil")..., Type: \(type.rawValue)"
        )

        if let accessJwt = accessJwt {
            try saveAccessToken(accessJwt, type: type)
        }
        if let refreshJwt = refreshJwt {
            try saveRefreshToken(refreshJwt, type: type)
        }
        try saveTokenType(type)
        LogManager.logDebug("TokenManager - Tokens saved successfully")

        // Publish token updated event
        if let accessJwt = accessJwt, let refreshJwt = refreshJwt {
            await EventBus.shared.publish(
                .tokensUpdated(accessToken: accessJwt, refreshToken: refreshJwt))
        }
    }

    private func saveAccessToken(_ token: String, type: TokenType) throws {
        guard let data = token.data(using: .utf8) else {
            throw TokenError.invalidTokenData
        }

        // Extract DID from the token itself for user-specific storage
        let did = getDIDFromToken(token)
        let key = userSpecificKey("accessJwt", did: did)

        try KeychainManager.store(key: key, value: data, namespace: namespace)

        // If we extracted a DID from the token, set it as current
        if let did = did {
            Task { await setCurrentDID(did) }
        }
    }

    private func saveRefreshToken(_ token: String, type: TokenType) throws {
        guard let data = token.data(using: .utf8) else {
            throw TokenError.invalidTokenData
        }

        // For refresh token, use the same DID as the access token if available
        let did = currentDID ?? accessJwt.flatMap { getDIDFromToken($0) }
        let key = userSpecificKey("refreshJwt", did: did)

        try KeychainManager.store(key: key, value: data, namespace: namespace)
    }

    private func saveTokenType(_ type: TokenType) throws {
        guard let data = try? JSONEncoder().encode(type) else {
            throw TokenError.invalidTokenData
        }

        let did = currentDID ?? accessJwt.flatMap { getDIDFromToken($0) }
        let key = userSpecificKey("tokenType", did: did)

        try KeychainManager.store(key: key, value: data, namespace: namespace)
    }

    func fetchAccessToken() async -> String? {
        // If we have a token in memory, return it
        if let token = accessJwt {
            LogManager.logDebug("TokenManager - Returning in-memory access token: \(token.prefix(30))...")
            return token
        }

        // Try to get the token for the current DID
        if let did = currentDID {
            return await fetchAccessToken(did: did)
        }

        // Legacy fallback for backward compatibility
        if let data = try? KeychainManager.retrieve(key: "accessJwt", namespace: namespace),
           let token = String(data: data, encoding: .utf8)
        {
            LogManager.logDebug("TokenManager - Retrieved legacy access token: \(token.prefix(30))...")
            return token
        }

        LogManager.logDebug("TokenManager - No access token available")
        return nil
    }

    public func fetchAccessToken(did: String) async -> String? {
        let key = userSpecificKey("accessJwt", did: did)

        if let data = try? KeychainManager.retrieve(key: key, namespace: namespace),
           let token = String(data: data, encoding: .utf8)
        {
            LogManager.logDebug(
                "TokenManager - Fetched access token for DID \(did): \(token.prefix(30))...")
            return token
        }

        LogManager.logDebug("TokenManager - No access token found for DID \(did)")
        return nil
    }

    public func fetchRefreshToken() async -> String? {
        // If we have a token in memory, return it
        if let token = refreshJwt {
            LogManager.logDebug(
                "TokenManager - Returning in-memory refresh token: \(token.prefix(30))...")
            return token
        }

        // Try to get the token for the current DID
        if let did = currentDID {
            return await fetchRefreshToken(did: did)
        }

        // Legacy fallback for backward compatibility
        if let data = try? KeychainManager.retrieve(key: "refreshJwt", namespace: namespace),
           let token = String(data: data, encoding: .utf8)
        {
            LogManager.logDebug("TokenManager - Retrieved legacy refresh token: \(token.prefix(30))...")
            return token
        }

        LogManager.logDebug("TokenManager - No refresh token available")
        return nil
    }

    public func fetchRefreshToken(did: String) async -> String? {
        let key = userSpecificKey("refreshJwt", did: did)

        if let data = try? KeychainManager.retrieve(key: key, namespace: namespace),
           let token = String(data: data, encoding: .utf8)
        {
            LogManager.logDebug(
                "TokenManager - Fetched refresh token for DID \(did): \(token.prefix(30))...")
            return token
        }

        LogManager.logDebug("TokenManager - No refresh token found for DID \(did)")
        return nil
    }

    public func decodeJWT(token: String) async -> OAuthClaims? {
        do {
            let jwt = try JWT(jwtString: token)
            let claims = try JSONDecoder().decode(OAuthClaims.self, from: jwt.payload)
            LogManager.logDebug("TokenManager - Decoded JWT claims: \(claims)")
            LogManager.logDebug(
                "TokenManager - Token expiration: \(claims.exp?.description ?? "nil"), Current time: \(Date().description)"
            )
            return claims
        } catch {
            LogManager.logError("TokenManager - Failed to decode JWT: \(error)")
            return nil
        }
    }

    // MARK: - OAuth-Specific Methods with State Association

    public func storeCodeVerifier(_ codeVerifier: String, for state: String) async throws {
        codeVerifiers[state] = codeVerifier
    }

    public func retrieveCodeVerifier(for state: String) async throws -> String? {
        return codeVerifiers[state]
    }

    public func deleteCodeVerifier(for state: String) async throws {
        codeVerifiers.removeValue(forKey: state)
    }

    public func storeState(_ state: String) async throws {
        states.insert(state)
    }

    public func retrieveState(_ state: String) async throws -> String? {
        if states.contains(state) {
            return state
        }
        return nil
    }

    public func deleteState(_ state: String) async throws {
        states.remove(state)
    }

    public func validateAndRetrieveState(_ state: String) async throws -> Bool {
        if states.contains(state) {
            states.remove(state)
            return true
        }
        return false
    }

    // MARK: - Token Refresh and Verification

    private func verifyToken(_ token: String) throws -> OAuthClaims {
        LogManager.logDebug("TokenManager - Verifying token: \(token.prefix(50))...")

        // Check if this is a refresh token (starts with "ref-")
        if token.starts(with: "ref-") {
            // For refresh tokens, we don't verify them, we just assume they're valid
            LogManager.logDebug("TokenManager - Refresh token detected, skipping verification")
            throw TokenError.refreshTokenDetected
        }

        do {
            let components = token.components(separatedBy: ".")
            if components.count >= 1,
               let headerData = Data(base64Encoded: components[0].base64URLUnescaped())
            {
                let headerString = String(data: headerData, encoding: .utf8) ?? "Unable to decode header"
                LogManager.logDebug("TokenManager - Token header: \(headerString)")

                if let headerDict = try? JSONSerialization.jsonObject(with: headerData, options: [])
                    as? [String: Any],
                    let typ = headerDict["typ"] as? String,
                    typ == "at+jwt"
                {
                    // This is a DPoP token
                    return try verifyDPoPToken(token)
                }
            }

            // If it's not a DPoP token or refresh token, proceed with regular JWT verification
            let jwt = try JWT(jwtString: token)

            // For now, we're not verifying the signature as we don't have the correct key
            // In a production environment, you would verify the signature here

            return try JSONDecoder().decode(OAuthClaims.self, from: jwt.payload)
        } catch {
            LogManager.logError("TokenManager - Failed to verify token: \(error)")
            throw TokenError.verificationFailed(error)
        }
    }

    private func verifyDPoPToken(_ token: String) throws -> OAuthClaims {
        // For DPoP tokens, we don't verify the signature here.
        // We just decode the claims and check the expiration.
        let jwt = try JWT(jwtString: token)
        let claims = try JSONDecoder().decode(OAuthClaims.self, from: jwt.payload)

        if let exp = claims.exp, exp <= Date() {
            throw TokenError.tokenExpired
        }

        return claims
    }

    private func extractKeyID(from token: String) throws -> String? {
        let components = token.components(separatedBy: ".")
        guard components.count >= 1,
              let headerData = Data(base64Encoded: components[0].base64URLUnescaped())
        else {
            throw TokenError.invalidTokenFormat
        }

        if let headerDict = try? JSONSerialization.jsonObject(with: headerData, options: [])
            as? [String: Any]
        {
            return headerDict["kid"] as? String
        }

        return nil
    }

    // MARK: - Multi-Account Methods

    /// Extracts the DID from a token
    private func getDIDFromToken(_ token: String) -> String? {
        do {
            let jwt = try JWT(jwtString: token)
            let claims = try JSONDecoder().decode(OAuthClaims.self, from: jwt.payload)
            return claims.sub
        } catch {
            LogManager.logError("TokenManager - Failed to extract DID from token: \(error)")
            return nil
        }
    }

    /// Creates a user-specific key by combining the base key with a DID
    private func userSpecificKey(_ baseKey: String, did: String? = nil) -> String {
        // Try to get DID from parameter, current DID, access token, or default to "anonymous"
        let userDID = did ?? currentDID ?? (accessJwt.flatMap { getDIDFromToken($0) }) ?? "anonymous"
        return "\(baseKey).\(userDID)"
    }

    /// Sets the current active DID
    public func setCurrentDID(_ did: String) async {
        currentDID = did
        LogManager.logInfo("TokenManager - Set current DID to: \(did)")

        // Load tokens for this DID
        await loadTokensForDID(did)

        // Add to stored DIDs list if not already present
        await addToStoredDIDs(did)

        // NEW: Store as the last active DID
        await TokenManager.storeLastActiveDID(did, namespace: namespace)
    }

    /// Gets the current active DID
    public func getCurrentDID() async -> String? {
        return currentDID
    }

    /// Loads tokens for a specific DID
    private func loadTokensForDID(_ did: String) async {
        // Clear existing tokens first
        accessJwt = nil
        refreshJwt = nil
        tokenType = nil

        let accessKey = userSpecificKey("accessJwt", did: did)
        let refreshKey = userSpecificKey("refreshJwt", did: did)
        let typeKey = userSpecificKey("tokenType", did: did)

        if let data = try? KeychainManager.retrieve(key: typeKey, namespace: namespace),
           let type = try? JSONDecoder().decode(TokenType.self, from: data)
        {
            tokenType = type
            LogManager.logDebug("TokenManager - Loaded token type for DID \(did): \(type.rawValue)")
        }

        if let accessData = try? KeychainManager.retrieve(key: accessKey, namespace: namespace),
           let savedAccessToken = String(data: accessData, encoding: .utf8)
        {
            accessJwt = savedAccessToken
            LogManager.logDebug("TokenManager - Loaded accessJwt for DID \(did)")
        }

        if let refreshData = try? KeychainManager.retrieve(key: refreshKey, namespace: namespace),
           let savedRefreshToken = String(data: refreshData, encoding: .utf8)
        {
            refreshJwt = savedRefreshToken
            LogManager.logDebug("TokenManager - Loaded refreshJwt for DID \(did)")
        }
    }

    /// Adds a DID to the stored DIDs list
    private func addToStoredDIDs(_ did: String) async {
        var dids = await listStoredDIDs()
        if !dids.contains(did) {
            dids.append(did)
            do {
                let data = try JSONEncoder().encode(dids)
                try KeychainManager.store(key: didsListKey, value: data, namespace: namespace)
                LogManager.logDebug("TokenManager - Added DID to stored list: \(did)")
            } catch {
                LogManager.logError("TokenManager - Failed to save DIDs list: \(error)")
            }
        }
    }

    /// Lists all DIDs with stored tokens
    public func listStoredDIDs() async -> [String] {
        do {
            let data = try KeychainManager.retrieve(key: didsListKey, namespace: namespace)
            let dids = try JSONDecoder().decode([String].self, from: data)
            return dids
        } catch {
            LogManager.logDebug("TokenManager - No stored DIDs found or error retrieving them: \(error)")
            return []
        }
    }

    /// Deletes tokens for a specific DID
    public func deleteTokensForDID(_ did: String) async throws {
        let accessKey = userSpecificKey("accessJwt", did: did)
        let refreshKey = userSpecificKey("refreshJwt", did: did)
        let typeKey = userSpecificKey("tokenType", did: did)

        try KeychainManager.delete(key: accessKey, namespace: namespace)
        try KeychainManager.delete(key: refreshKey, namespace: namespace)
        try KeychainManager.delete(key: typeKey, namespace: namespace)

        // Remove from DIDs list
        var dids = await listStoredDIDs()
        dids.removeAll { $0 == did }
        let data = try JSONEncoder().encode(dids)
        try KeychainManager.store(key: didsListKey, value: data, namespace: namespace)

        LogManager.logInfo("TokenManager - Deleted tokens for DID: \(did)")

        // If this was the current DID, reset the current tokens
        if currentDID == did {
            accessJwt = nil
            refreshJwt = nil
            tokenType = nil
            currentDID = nil
        }
    }

    /// Gets the token type for a specific DID
    public func getTokenType(did: String? = nil) async -> TokenType? {
        if let requestedDID = did {
            let typeKey = userSpecificKey("tokenType", did: requestedDID)
            if let data = try? KeychainManager.retrieve(key: typeKey, namespace: namespace),
               let type = try? JSONDecoder().decode(TokenType.self, from: data)
            {
                return type
            }
            return nil
        }

        // Return current token type if no DID specified
        return tokenType
    }

    // MARK: - Static Methods for Account Switching

    /// Stores the last active DID when switching accounts
    /// - Parameters:
    ///   - did: The DID of the last active account
    ///   - namespace: The namespace for storage
    static func storeLastActiveDID(_ did: String, namespace: String) async {
        do {
            let data = did.data(using: .utf8) ?? Data()
            try KeychainManager.store(key: "lastActiveDID", value: data, namespace: namespace)
            LogManager.logDebug("TokenManager - Stored last active DID: \(did)")
        } catch {
            LogManager.logError("TokenManager - Failed to store last active DID: \(error)")
        }
    }

    /// Retrieves the last active DID
    /// - Parameter namespace: The namespace for storage
    /// - Returns: The DID of the last active account, if available
    static func getLastActiveDID(namespace: String) async -> String? {
        do {
            let data = try KeychainManager.retrieve(key: "lastActiveDID", namespace: namespace)
            guard let did = String(data: data, encoding: .utf8) else { return nil }
            LogManager.logDebug("TokenManager - Retrieved last active DID: \(did)")
            return did
        } catch {
            LogManager.logDebug("TokenManager - No last active DID found: \(error)")
            return nil
        }
    }

    /// Clears the last active DID
    /// - Parameter namespace: The namespace for storage
    static func clearLastActiveDID(namespace: String) async {
        LogManager.logError("TOKEN_MANAGER: clearLastActiveDID called for namespace \(namespace)")
        let keyToDelete = "lastActiveDID" // The key name used in store/retrieve

        do {
            try KeychainManager.delete(key: keyToDelete, namespace: namespace)
            LogManager.logError("TOKEN_MANAGER: KeychainManager.delete succeeded for key \(keyToDelete)")

            // Add additional verification
            let checkAfterDelete = try? KeychainManager.retrieve(key: keyToDelete, namespace: namespace)
            if checkAfterDelete != nil {
                LogManager.logError("TOKEN_MANAGER: Key still exists after delete attempt, retrying with full path")
                // Try with explicit path as fallback
                let namespacedKey = "\(namespace).\(keyToDelete)"
                try? KeychainManager.deleteExplicitKey(namespacedKey)
            }
        } catch {
            LogManager.logError("TOKEN_MANAGER: KeychainManager.delete FAILED for key \(keyToDelete): \(error)")
            // Try with explicit path as fallback
            let namespacedKey = "\(namespace).\(keyToDelete)"
            try? KeychainManager.deleteExplicitKey(namespacedKey)
        }
    }
}

// MARK: - OAuthClaims Structure

public struct OAuthClaims: Codable, JWTRegisteredFieldsClaims, Sendable {
    public let iss: String?
    public let sub: String?
    private let _aud: [String]? // Internal property to store aud
    public var aud: [String]? { _aud } // Computed property to satisfy protocol
    public let exp: Date?
    public let nbf: Date?
    public let iat: Date?
    public let jti: String?
    public let scope: String
    public let cnf: ConfirmationClaims?

    public struct ConfirmationClaims: Codable, Sendable {
        let jkt: String
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        iss = try container.decodeIfPresent(String.self, forKey: .iss)
        sub = try container.decodeIfPresent(String.self, forKey: .sub)
        cnf = try container.decodeIfPresent(ConfirmationClaims.self, forKey: .cnf)

        // Decode `aud` as either String or Array
        if let audArray = try? container.decode([String].self, forKey: .aud) {
            _aud = audArray
        } else if let audString = try? container.decode(String.self, forKey: .aud) {
            _aud = [audString]
        } else {
            _aud = nil
        }

        // Decode date fields from Int (Unix timestamp) to Date
        if let expInt = try container.decodeIfPresent(Int.self, forKey: .exp) {
            exp = Date(timeIntervalSince1970: TimeInterval(expInt))
        } else {
            exp = nil
        }

        if let nbfInt = try container.decodeIfPresent(Int.self, forKey: .nbf) {
            nbf = Date(timeIntervalSince1970: TimeInterval(nbfInt))
        } else {
            nbf = nil
        }

        if let iatInt = try container.decodeIfPresent(Int.self, forKey: .iat) {
            iat = Date(timeIntervalSince1970: TimeInterval(iatInt))
        } else {
            iat = nil
        }

        jti = try container.decodeIfPresent(String.self, forKey: .jti)
        scope = try container.decode(String.self, forKey: .scope)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(iss, forKey: .iss)
        try container.encodeIfPresent(sub, forKey: .sub)
        try container.encodeIfPresent(_aud, forKey: .aud)

        // Encode Date fields as Int (Unix timestamp)
        if let exp = exp {
            try container.encode(Int(exp.timeIntervalSince1970), forKey: .exp)
        }
        if let nbf = nbf {
            try container.encode(Int(nbf.timeIntervalSince1970), forKey: .nbf)
        }
        if let iat = iat {
            try container.encode(Int(iat.timeIntervalSince1970), forKey: .iat)
        }

        try container.encodeIfPresent(jti, forKey: .jti)
        try container.encode(scope, forKey: .scope)
    }

    public func validateExtraClaims() throws {
        if scope.isEmpty {
            throw JWTError.invalidClaim(name: "scope", reason: "Scope cannot be empty")
        }
    }

    enum JWTError: Error {
        case invalidClaim(name: String, reason: String)
    }

    private enum CodingKeys: String, CodingKey {
        case iss, sub, aud, exp, nbf, iat, jti, scope, cnf
    }
}

// MARK: - TokenError Enumeration

enum TokenError: Error {
    case invalidTokenData
    case missingJWKS
    case missingJWKSURI
    case unsupportedAlgorithm(String)
    case invalidJWKFormat
    case missingAlgorithm
    case noValidSigners
    case verificationFailed(Error)
    case tokenExpired
    case tokenNotYetValid
    case invalidTokenFormat
    case missingKeyID
    case missingSigningKey
    case refreshTokenDetected

    var localizedDescription: String {
        switch self {
        case .invalidTokenData:
            return "Invalid data for token"
        case .missingJWKSURI:
            return "Missing JWKS URI in server metadata"
        case .missingJWKS:
            return "Missing JWKS"
        case let .unsupportedAlgorithm(alg):
            return "Unsupported algorithm: \(alg)"
        case .invalidJWKFormat:
            return "Invalid JWK format"
        case .missingAlgorithm:
            return "Missing algorithm"
        case .noValidSigners:
            return "No valid signers"
        case let .verificationFailed(error):
            return error.localizedDescription
        case .tokenExpired:
            return "Token expired"
        case .tokenNotYetValid:
            return "Token not yet valid"
        case .invalidTokenFormat:
            return "Invalid JWT format"
        case .missingKeyID:
            return "Token missing key ID"
        case .missingSigningKey:
            return "Token missing signing key"
        case .refreshTokenDetected:
            return "Refresh token detected; should skip verification"
        }
    }
}

// MARK: - String Extension for Base64URL

extension String {
    func base64URLUnescaped() -> String {
        var result = replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while result.count % 4 != 0 {
            result += "="
        }
        return result
    }
}
