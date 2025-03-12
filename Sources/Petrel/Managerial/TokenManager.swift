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
    func hasValidTokens() async -> Bool
    func saveTokens(accessJwt: String?, refreshJwt: String?, type: TokenType, domain: String?) async throws
    func shouldRefreshTokens() async -> Bool
    func fetchRefreshToken() async -> String?
    func fetchAccessToken() async -> String?
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

    // Internal dictionaries to associate state with code_verifier
    private var codeVerifiers: [String: String] = [:]
    private var states: Set<String> = []

    private var isInitialized = false

    private let dpopBindingsKey = "dpopKeyBindings"

    private func loadDPoPBindings() {
        do {
            let data = try KeychainManager.retrieve(key: dpopBindingsKey, namespace: namespace)

            let bindings = try JSONDecoder().decode([String: String].self, from: data)
            dpopKeyBindings = bindings
            LogManager.logDebug("TokenManager - Loaded DPoP bindings from Keychain: \(bindings)")
        } catch {
            LogManager.logError("Failed to load DPoP bindings: \(error)")
            dpopKeyBindings = [:]
        }
    }

    private func saveDPoPBindings() throws {
        let data = try JSONEncoder().encode(dpopKeyBindings)
        try KeychainManager.store(key: dpopBindingsKey, value: data, namespace: namespace)
        LogManager.logDebug("TokenManager - Saved DPoP bindings to Keychain")
    }

    // Update init to load bindings
    init(namespace: String) async {
        self.namespace = namespace
        await loadInitialTokens()
        loadDPoPBindings()
        LogManager.logDebug("Token Manager initialized")
    }

    private func loadInitialTokens() async {
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
        authServerMetadata = try JSONDecoder().decode(AuthorizationServerMetadata.self, from: metadataData)

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
              let refreshToken = fetchRefreshToken()
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
                LogManager.logDebug("TokenManager - Token expiration check: \(isExpired ? "expired" : "valid") (Expires: \(expDate))")
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

        LogManager.logInfo("""
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

    func hasAnyTokens() -> Bool {
        return accessJwt != nil || refreshJwt != nil
    }

    // Store DPoP key binding info per domain
    private var dpopKeyBindings: [String: String] = [:]

    public func getDPoPBinding(for domain: String) async -> String? {
        return dpopKeyBindings[domain]
    }

    // Save the binding when tokens are saved
    public func saveTokens(accessJwt: String?, refreshJwt: String?, type: TokenType, domain: String? = nil) async throws {
        self.accessJwt = accessJwt
        self.refreshJwt = refreshJwt
        tokenType = type

        // Extract and store DPoP binding from access token if present
        if let accessJwt = accessJwt,
           let jwt = try? JWT(jwtString: accessJwt),
           let claims = try? JSONDecoder().decode(OAuthClaims.self, from: jwt.payload),
           let cnf = claims.cnf,
           let domain = domain
        {
            dpopKeyBindings[domain] = cnf.jkt
            do {
                try saveDPoPBindings()
                LogManager.logDebug("TokenManager - Stored DPoP binding for domain \(domain)")
            } catch {
                LogManager.logError("Failed to save DPoP bindings: \(error)")
            }
        }

        LogManager.logDebug("TokenManager - Saving tokens. Access JWT: \(accessJwt?.prefix(30) ?? "nil")..., Refresh JWT: \(refreshJwt?.prefix(30) ?? "nil")..., Type: \(type.rawValue)")

        if let accessJwt = accessJwt {
            try saveAccessToken(accessJwt, type: type)
        }
        if let refreshJwt = refreshJwt {
            try saveRefreshToken(refreshJwt, type: type)
        }
        try saveTokenType(type)
        LogManager.logDebug("TokenManager - Tokens saved successfully")

        // Publish token updated event
        await EventBus.shared.publish(.tokensUpdated(accessToken: accessJwt ?? "", refreshToken: refreshJwt ?? ""))
    }

    private func saveAccessToken(_ token: String, type: TokenType) throws {
        guard let data = token.data(using: .utf8) else {
            throw TokenError.invalidTokenData
        }
        switch type {
        case .bearer:
            try KeychainManager.store(key: "accessJwt", value: data, namespace: namespace)
        case .dpop:
            try KeychainManager.store(key: "accessJwt", value: data, namespace: namespace)
        }
    }

    private func saveRefreshToken(_ token: String, type: TokenType) throws {
        guard let data = token.data(using: .utf8) else {
            throw TokenError.invalidTokenData
        }
        switch type {
        case .bearer:
            try KeychainManager.store(key: "refreshJwt", value: data, namespace: namespace)
        case .dpop:
            try KeychainManager.store(key: "refreshJwt", value: data, namespace: namespace)
        }
    }

    private func saveTokenType(_ type: TokenType) throws {
        guard let data = try? JSONEncoder().encode(type) else {
            throw TokenError.invalidTokenData
        }
        try KeychainManager.store(key: "tokenType", value: data, namespace: namespace)
    }

    func fetchAccessToken() async -> String? {
        guard let token = accessJwt else {
            LogManager.logDebug("TokenManager - No access token available")
            return nil
        }

        if Task.isCancelled { return nil }

        // We're not checking expiration here anymore
        LogManager.logDebug("TokenManager - Fetched accessJwt: \(token.prefix(30))...")
        return token
    }

    public func fetchRefreshToken() -> String? {
        var token: String?
        switch tokenType {
        case .bearer, .dpop:
            if let data = try? KeychainManager.retrieve(key: "refreshJwt", namespace: namespace),
               let savedToken = String(data: data, encoding: .utf8)
            {
                token = savedToken
            } else {
                LogManager.logDebug("TokenManager - Failed to fetch refreshJwt from Keychain")
            }
        case .none:
            return nil
        }
        LogManager.logDebug("TokenManager - Fetched refreshJwt: \(token?.prefix(30) ?? "nil")")
        return token
    }

    public func decodeJWT(token: String) async -> OAuthClaims? {
        do {
            let jwt = try JWT(jwtString: token)
            let claims = try JSONDecoder().decode(OAuthClaims.self, from: jwt.payload)
            LogManager.logDebug("TokenManager - Decoded JWT claims: \(claims)")
            LogManager.logDebug("TokenManager - Token expiration: \(claims.exp?.description ?? "nil"), Current time: \(Date().description)")
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
            if components.count >= 1, let headerData = Data(base64Encoded: components[0].base64URLUnescaped()) {
                let headerString = String(data: headerData, encoding: .utf8) ?? "Unable to decode header"
                LogManager.logDebug("TokenManager - Token header: \(headerString)")

                if let headerDict = try? JSONSerialization.jsonObject(with: headerData, options: []) as? [String: Any],
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
        guard components.count >= 1, let headerData = Data(base64Encoded: components[0].base64URLUnescaped()) else {
            throw TokenError.invalidTokenFormat
        }

        if let headerDict = try? JSONSerialization.jsonObject(with: headerData, options: []) as? [String: Any] {
            return headerDict["kid"] as? String
        }

        return nil
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
    public let cnf: ConfirmationClaims? // Add this

    // Add this struct
    public struct ConfirmationClaims: Codable, Sendable {
        let jkt: String
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        iss = try container.decodeIfPresent(String.self, forKey: .iss)
        sub = try container.decodeIfPresent(String.self, forKey: .sub)
        cnf = try container.decodeIfPresent(ConfirmationClaims.self, forKey: .cnf) // Add this

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
            print("Raw exp timestamp: \(expInt)") // Let's see the Unix timestamp
            exp = Date(timeIntervalSince1970: TimeInterval(expInt))
            print("Converted to date: \(exp)")
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
        // Implement any additional claim validations here
        // For example, you might want to check if the scope is valid
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
