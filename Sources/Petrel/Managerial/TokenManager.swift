import Foundation
internal import ZippyJSON
import JWTKit

struct AuthorizationServerMetadata: Codable {
    let issuer: String
    let jwksUri: String
    // Add other fields as needed
}

protocol TokenManaging: Actor {
    func fetchAuthServerMetadataAndJWKS(baseURL: URL) async throws
    func deleteTokens() async throws
    func hasValidTokens() async -> Bool
    func saveTokens(accessJwt: String, refreshJwt: String) async throws
    func shouldRefreshTokens() async -> Bool
    func fetchRefreshToken() async -> String?
    func fetchAccessToken() async -> String?
    func decodeJWT(token: String) async -> OAuthJWTPayload?
    func isTokenExpired(token: String) async -> Bool
    func setDelegate(_ delegate: TokenDelegate?) async
    func storeCodeVerifier(_ codeVerifier: String) async throws
    func retrieveCodeVerifier() async throws -> String?
    func deleteCodeVerifier() async throws
    func storeState(_ state: String) async throws
    func retrieveState() async throws -> String?
    func deleteState() async throws
}

protocol TokenDelegate: Actor {
    func tokenDidUpdate() async
}

public actor TokenManager: TokenManaging {
    private var accessJwt: String?
    private var refreshJwt: String?
    var delegate: TokenDelegate?
    private var jwks: JWKS?
    private var authServerMetadata: AuthorizationServerMetadata?

    public func fetchAuthServerMetadataAndJWKS(baseURL: URL) async throws {
        let metadataURL = baseURL.appendingPathComponent(".well-known/oauth-authorization-server")
        let (metadataData, _) = try await URLSession.shared.data(from: metadataURL)
        authServerMetadata = try JSONDecoder().decode(AuthorizationServerMetadata.self, from: metadataData)

        guard let jwksUri = authServerMetadata?.jwksUri,
              let jwksURL = URL(string: jwksUri)
        else {
            throw TokenError.missingJWKSURI
        }

        let (jwksData, _) = try await URLSession.shared.data(from: jwksURL)
        jwks = try JSONDecoder().decode(JWKS.self, from: jwksData)
    }

    // Update token verification methods to use JWKS
    private func verifyToken(_ token: String) throws -> OAuthJWTPayload {
        guard let jwks = jwks else {
            throw TokenError.missingJWKS
        }

        let signers = JWTSigners()

        try jwks.keys.forEach { key in
            try signers.use(jwk: key)
        }

        return try signers.verify(token, as: OAuthJWTPayload.self)
    }

    func setDelegate(_ delegate: TokenDelegate?) {
        self.delegate = delegate
    }

    public func hasValidTokens() async -> Bool {
        LogManager.logDebug("TokenManager - Checking token validity.")

        guard let accessJwt = fetchAccessToken(), let refreshJwt = fetchRefreshToken() else {
            LogManager.logInfo("TokenManager - Access or Refresh Token not found.")
            return false
        }

        do {
            let accessPayload = try verifyToken(accessJwt)
            let refreshPayload = try verifyToken(refreshJwt)

            let currentDate = Date()

            if accessPayload.exp.value > currentDate && refreshPayload.exp.value > currentDate {
                LogManager.logInfo("TokenManager - Tokens are valid.")
                return true
            } else {
                if accessPayload.exp.value <= currentDate {
                    LogManager.logInfo("TokenManager - Access token is expired.")
                }
                if refreshPayload.exp.value <= currentDate {
                    LogManager.logInfo("TokenManager - Refresh token is expired.")
                }
                LogManager.logInfo("TokenManager - One or both tokens are expired or invalid.")
                return false
            }
        } catch {
            LogManager.logError("TokenManager - Error verifying tokens: \(error)")
            return false
        }
    }

    func isTokenExpired(token: String) async -> Bool {
        do {
            let payload = try verifyToken(token)
            let currentDate = Date()
            let expirationDate = payload.exp.value

            LogManager.logDebug(
                "TokenManager - the current date is \(currentDate.description). the exp date is \(expirationDate.description)."
            )

            if currentDate >= expirationDate {
                LogManager.logDebug("TokenManager - Token is expired.")
                return true
            } else {
                LogManager.logDebug("TokenManager - Token is still valid.")
                return false
            }
        } catch {
            LogManager.logError("TokenManager - Error verifying token: \(error)")
            return true
        }
    }

    public func saveTokens(accessJwt: String, refreshJwt: String) async throws {
        // Update the stored JWTs in memory
        self.accessJwt = accessJwt
        self.refreshJwt = refreshJwt

        // Notify delegate about the token update
        await delegate?.tokenDidUpdate()
        LogManager.logInfo("Tokens updated and delegate notified.")

        // Log saving tokens and attempt to save them in the keychain
        LogManager.logDebug(
            "TokenManager - Saving new tokens at \(Date()) - Access Token Prefix: \(String(accessJwt.prefix(5)))"
        )
        do {
            // Save access and refresh tokens to the Keychain
            try saveAccessToken(accessJwt)
            try saveRefreshToken(refreshJwt)
            LogManager.logInfo("Tokens saved successfully in Keychain")
        } catch {
            LogManager.logError("Failed to save tokens in Keychain: \(error.localizedDescription)")
            throw error
        }
    }

    func saveAccessToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw TokenError.invalidTokenData
        }
        try KeychainManager.store(key: "accessJwt", value: data)
    }

    func saveRefreshToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw TokenError.invalidTokenData
        }
        try KeychainManager.store(key: "refreshJwt", value: data)
    }

    func fetchAccessToken() -> String? {
        guard let data = try? KeychainManager.retrieve(key: "accessJwt") else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func fetchRefreshToken() -> String? {
        guard let data = try? KeychainManager.retrieve(key: "refreshJwt") else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func deleteTokens() throws {
        try KeychainManager.delete(key: "accessJwt")
        try KeychainManager.delete(key: "refreshJwt")
    }

    public func shouldRefreshTokens() async -> Bool {
        LogManager.logDebug("Checking if tokens should be refreshed.")

        guard let refreshToken = fetchRefreshToken(), let accessToken = fetchAccessToken() else {
            LogManager.logInfo("TokenManager - One or both tokens missing.")
            return true
        }

        do {
            let refreshPayload = try verifyToken(refreshToken)
            let accessPayload = try verifyToken(accessToken)

            let currentTime = Date()
            let refreshTimeToExpiration = refreshPayload.exp.value.timeIntervalSince(currentTime)
            let accessTimeToExpiration = accessPayload.exp.value.timeIntervalSince(currentTime)

            if accessTimeToExpiration < 0 {
                LogManager.logInfo("TokenManager - Access token is expired.")
                return true
            } else if refreshTimeToExpiration < 0 {
                LogManager.logInfo("TokenManager - Refresh token is expired.")
                return true
            } else if refreshTimeToExpiration < 300 {
                LogManager.logInfo("TokenManager - Refresh token is close to expiration.")
                return true
            } else {
                LogManager.logDebug("TokenManager - No need to refresh tokens yet.")
                return false
            }
        } catch {
            LogManager.logError("TokenManager - Error verifying tokens: \(error)")
            return true
        }
    }

    public func decodeJWT(token: String) async -> OAuthJWTPayload? {
        do {
            let signers = JWTSigners()
            return try signers.unverified(token, as: OAuthJWTPayload.self)
        } catch {
            LogManager.logError("Failed to decode JWT token: \(error.localizedDescription)")
            return nil
        }
    }

    public func storeState(_ state: String) async throws {
        try await storeValue(state, for: "oauth_state")
    }

    public func retrieveState() async throws -> String? {
        return try await retrieveValue(for: "oauth_state")
    }

    public func deleteState() async throws {
        try await deleteValue(for: "oauth_state")
    }

    public func storeCodeVerifier(_ codeVerifier: String) async throws {
        try await storeValue(codeVerifier, for: "oauth_code_verifier")
    }

    public func retrieveCodeVerifier() async throws -> String? {
        return try await retrieveValue(for: "oauth_code_verifier")
    }

    public func deleteCodeVerifier() async throws {
        try await deleteValue(for: "oauth_code_verifier")
    }

    private func storeValue(_ value: String, for key: String) async throws {
        let data = value.data(using: .utf8)!
        try KeychainManager.store(key: key, value: data)
    }

    private func retrieveValue(for key: String) async throws -> String? {
        guard let data = try? KeychainManager.retrieve(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteValue(for key: String) async throws {
        try KeychainManager.delete(key: key)
    }
}

// Define TokenError and JWTPayload within the same file to keep them scoped correctly.
enum TokenError: Error {
    case invalidTokenData
    case missingJWKSURI
    case missingJWKS

    var localizedDescription: String {
        switch self {
        case .invalidTokenData:
            return "Invalid data for token"
        case .missingJWKSURI:
            return "Missing JWKS URI in server metadata"
        case .missingJWKS:
            return "Missing JWKS"
        }
    }
}

public struct OAuthJWTPayload: JWTPayload, @unchecked Sendable {
    public let sub: SubjectClaim
    public let exp: ExpirationClaim
    public let iat: IssuedAtClaim
    public let scope: String
    public let aud: AudienceClaim

    public func verify(using _: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}

////  "alg": "ES256K"
// public struct JWTPayload: Codable, Sendable {
//    let scope: String
//    let sub: String
//    let exp: Int
//    let iat: Int
//    let aud: String
//    var expirationDate: Date { Date(timeIntervalSince1970: Double(exp)) }
//    var issuedAtDate: Date { Date(timeIntervalSince1970: Double(iat)) }
// }
