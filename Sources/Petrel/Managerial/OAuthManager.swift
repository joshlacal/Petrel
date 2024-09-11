//
//  OAuthManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 9/9/24.
//


import Foundation
import CryptoKit
import JWTKit

actor OAuthManager {
    private let networkManager: NetworkManaging
    private let configurationManager: ConfigurationManaging
    private let tokenManager: TokenManaging
    private var authorizationServerMetadata: AuthorizationServerMetadata?
    private var protectedResourceMetadata: ProtectedResourceMetadata?
    private var dpopKeyPair: P256.Signing.PrivateKey?
    private var dpopNonce: String?
    private let oauthConfig: OAuthConfiguration
    
    init(networkManager: NetworkManaging,
         configurationManager: ConfigurationManaging,
         tokenManager: TokenManaging,
         oauthConfig: OAuthConfiguration) {
        self.networkManager = networkManager
        self.configurationManager = configurationManager
        self.tokenManager = tokenManager
        self.oauthConfig = oauthConfig
    }
    
    struct AuthorizationServerMetadata: Codable {
        let issuer: String
        let authorizationEndpoint: String
        let tokenEndpoint: String
        let pushAuthorizationRequestEndpoint: String
        let dpopSigningAlgValuesSupported: [String]
        let scopesSupported: String
    }
    
    struct ProtectedResourceMetadata: Codable {
        let authorizationServer: String
    }
    
    enum OAuthError: Error {
        case invalidPDSURL
        case missingServerMetadata
        case authorizationFailed
        case tokenExchangeFailed
        case invalidSubClaim
        case noDPoPKeyPair
        case maxRetriesReached
        case invalidNonce
    }
    
    private func resolvePDSURL(for identifier: String) async throws -> URL {
        if identifier.starts(with: "did:") {
            // Implement DID resolution
            fatalError("DID resolution not implemented")
        } else {
            // Assume it's a handle
            return URL(string: "https://\(identifier.split(separator: "@").last!)")!
        }
    }
    
    func startOAuthFlow(identifier: String) async throws -> URL {
        let pdsURL = try await resolvePDSURL(for: identifier)
        protectedResourceMetadata = try await fetchProtectedResourceMetadata(pdsHost: pdsURL.host!)
        authorizationServerMetadata = try await fetchAuthorizationServerMetadata(authServerURL: protectedResourceMetadata!.authorizationServer)
        
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        
        generateDPoPKeypair()
        
        let requestURI = try await pushAuthorizationRequest(codeChallenge: codeChallenge, identifier: identifier)
        
        try await tokenManager.storeCodeVerifier(codeVerifier)
        
        return URL(string: "\(authorizationServerMetadata!.authorizationEndpoint)?request_uri=\(requestURI)&client_id=\(oauthConfig.clientId)&redirect_uri=\(oauthConfig.redirectUri)")!
    }
    
    func handleCallback(url: URL) async throws -> (accessToken: String, refreshToken: String) {
        guard let code = extractAuthorizationCode(from: url),
              let state = extractState(from: url),
              let storedState = try? await tokenManager.retrieveState(),
              state == storedState else {
            throw OAuthError.authorizationFailed
        }
        
        guard let codeVerifier = try? await tokenManager.retrieveCodeVerifier() else {
            throw OAuthError.authorizationFailed
        }
        
        let (accessToken, refreshToken) = try await exchangeCodeForTokens(code: code, codeVerifier: codeVerifier)
        
        try? await tokenManager.deleteCodeVerifier()
        try? await tokenManager.deleteState()
        
        return (accessToken, refreshToken)
    }
    
    private func fetchProtectedResourceMetadata(pdsHost: String) async throws -> ProtectedResourceMetadata {
        let endpoint = "https://\(pdsHost)/.well-known/oauth-protected-resource"
        let request = try await networkManager.createURLRequest(
            endpoint: endpoint, method: "GET", headers: [:], body: nil, queryItems: nil)
        let (data, _) = try await networkManager.performRequest(request, retryCount: 0, duringInitialSetup: true)
        return try JSONDecoder().decode(ProtectedResourceMetadata.self, from: data)
    }
    
    private func fetchAuthorizationServerMetadata(authServerURL: String) async throws -> AuthorizationServerMetadata {
        let endpoint = "\(authServerURL)/.well-known/oauth-authorization-server"
        let request = try await networkManager.createURLRequest(
            endpoint: endpoint, method: "GET", headers: [:], body: nil, queryItems: nil)
        let (data, _) = try await networkManager.performRequest(request, retryCount: 0, duringInitialSetup: true)
        return try JSONDecoder().decode(AuthorizationServerMetadata.self, from: data)
    }
    
    private func generateCodeVerifier() -> String {
        let verifierData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        return verifierData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        let verifierData = Data(verifier.utf8)
        let hash = SHA256.hash(data: verifierData)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func generateDPoPKeypair() {
        dpopKeyPair = P256.Signing.PrivateKey()
    }
    func updateDPoPNonce(from headers: [String: String]) {
        if let newNonce = headers["DPoP-Nonce"] {
            // Update the stored nonce
            self.dpopNonce = newNonce
        }
    }
    private func pushAuthorizationRequest(codeChallenge: String, identifier: String) async throws -> String {
        guard let metadata = authorizationServerMetadata else {
            throw OAuthError.missingServerMetadata
        }
        
        let state = UUID().uuidString
        try await tokenManager.storeState(state)
        
        let parameters: [String: String] = [
            "client_id": oauthConfig.clientId,
            "code_challenge": codeChallenge,
            "code_challenge_method": "S256",
            "scope": oauthConfig.scopes.joined(separator: " "),
            "state": state,
            "redirect_uri": oauthConfig.redirectUri,
            "response_type": "code",
            "login_hint": identifier
        ]
        
        let body = parameters.percentEncoded()
        
        var request = try await networkManager.createURLRequest(
            endpoint: metadata.pushAuthorizationRequestEndpoint,
            method: "POST",
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: body,
            queryItems: nil
        )
        
        let dpopProof = try await createDPoPProof(for: "POST", url: metadata.pushAuthorizationRequestEndpoint)
        request.setValue(dpopProof, forHTTPHeaderField: "DPoP")
        
        let (data, response) = try await networkManager.performRequest(request, retryCount: 0, duringInitialSetup: true)
        
        if let dpopNonce = response.value(forHTTPHeaderField: "DPoP-Nonce") {
            self.dpopNonce = dpopNonce
        }
        
        let parResponse = try JSONDecoder().decode(PARResponse.self, from: data)
        return parResponse.request_uri
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
    
    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> (String, String) {
        guard let metadata = authorizationServerMetadata else {
            throw OAuthError.missingServerMetadata
        }
        
        let dpopProof = try await createDPoPProof(for: "POST", url: metadata.tokenEndpoint)
        
        let parameters: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "code_verifier": codeVerifier,
            "client_id": oauthConfig.clientId,
            "redirect_uri": oauthConfig.redirectUri
        ]
        
        let body = parameters.percentEncoded()
        
        var request = try await networkManager.createURLRequest(
            endpoint: metadata.tokenEndpoint,
            method: "POST",
            headers: [
                "Content-Type": "application/x-www-form-urlencoded",
                "DPoP": dpopProof
            ],
            body: body,
            queryItems: nil
        )
        
        let (data, response) = try await networkManager.performRequest(request, retryCount: 0, duringInitialSetup: true)
        
        if let dpopNonce = response.value(forHTTPHeaderField: "DPoP-Nonce") {
            self.dpopNonce = dpopNonce
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        // Verify the 'sub' claim
        guard let sub = tokenResponse.sub, sub.starts(with: "did:") else {
            throw OAuthError.invalidSubClaim
        }
        
        return (tokenResponse.access_token, tokenResponse.refresh_token)
    }
    
    func createDPoPProof(for httpMethod: String, url: String) async throws -> String {
        guard let privateKey = dpopKeyPair else {
            throw OAuthError.noDPoPKeyPair
        }
        
        let publicKey = privateKey.publicKey
        let jwk = JWK.ecdsa(
            .es256,
            identifier: nil,
            x: publicKey.x963Representation.dropFirst(1).prefix(32).base64EncodedString().base64URLEscaped(),
            y: publicKey.x963Representation.suffix(32).base64EncodedString().base64URLEscaped(),
            curve: .p256
        )
        
        let jwkData = try JSONEncoder().encode(jwk)
        let jwkString = String(data: jwkData, encoding: .utf8) ?? ""
        
        let payload = DPoPClaims(
            jti: UUID().uuidString,
            htm: httpMethod,
            htu: url,
            iat: Date(),
            nonce: dpopNonce
        )
        
        let signer = JWTSigner.es256(key: try .private(pem: privateKey.pemRepresentation))
        return try signer.sign(payload)
    }
    
    struct PARResponse: Codable {
        let request_uri: String
        let expires_in: Int
    }
    
    struct TokenResponse: Codable {
        let access_token: String
        let token_type: String
        let expires_in: Int
        let refresh_token: String
        let scope: String
        let sub: String?
    }
    
    struct DPoPClaims: JWTPayload {
        
        let jti: String
        let htm: String
        let htu: String
        let iat: Date
        var nonce: String?
        
        func verify(using signer: JWTKit.JWTSigner) throws {
            // Add any additional verification logic here
        }
    }}
extension String {
    func base64URLEscaped() -> String {
        return self.replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
extension Dictionary where Key == String, Value == String {
    func percentEncoded() -> Data {
        map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return escapedKey + "=" + escapedValue
        }
        .joined(separator: "&")
        .data(using: .utf8)!
    }
}
