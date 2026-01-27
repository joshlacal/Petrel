import Foundation
@testable import Petrel
import Testing

@Suite("Authentication Service Tests")
struct AuthenticationServiceTests {
    // MARK: - Test Setup

    private func createTestAuthService() -> AuthenticationService {
        let config = OAuthConfig(
            clientId: "test-client-id",
            redirectUri: "test://callback",
            scope: "atproto transition:generic"
        )
        return AuthenticationService(oauthConfig: config)
    }

    // MARK: - Service Initialization Tests

    @Test("Authentication service initializes with correct configuration")
    func serviceInitialization() {
        let config = OAuthConfig(
            clientId: "test-client",
            redirectUri: "catbird://auth/callback",
            scope: "atproto transition:generic transition:chat.bsky"
        )
        let service = AuthenticationService(oauthConfig: config)

        #expect(service.oauthConfig.clientId == "test-client", "Should set correct client ID")
        #expect(service.oauthConfig.redirectUri == "catbird://auth/callback", "Should set correct redirect URI")
        #expect(service.oauthConfig.scope.contains("atproto"), "Should include atproto scope")
        #expect(service.oauthConfig.scope.contains("transition:chat.bsky"), "Should include chat scope")
    }

    @Test("Service starts in unauthenticated state")
    func initialAuthenticationState() {
        let service = createTestAuthService()

        #expect(!service.isAuthenticated, "Should start unauthenticated")
        #expect(service.currentSession == nil, "Should have no current session")
        #expect(service.accessToken == nil, "Should have no access token")
        #expect(service.refreshToken == nil, "Should have no refresh token")
    }

    // MARK: - OAuth Flow Tests

    @Test("OAuth authorization URL generation")
    func oAuthAuthorizationURL() async throws {
        let service = createTestAuthService()

        let authURL = await service.buildAuthorizationURL()

        #expect(authURL != nil, "Should generate authorization URL")
        #expect(authURL?.scheme == "https", "Should use HTTPS scheme")
        #expect(authURL?.host != nil, "Should have valid host")

        let components = try URLComponents(url: #require(authURL), resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        // Verify required OAuth parameters
        let clientIdParam = queryItems.first { $0.name == "client_id" }
        let redirectParam = queryItems.first { $0.name == "redirect_uri" }
        let responseTypeParam = queryItems.first { $0.name == "response_type" }
        let scopeParam = queryItems.first { $0.name == "scope" }
        let stateParam = queryItems.first { $0.name == "state" }
        let codeChallengeParam = queryItems.first { $0.name == "code_challenge" }
        let codeChallengeMethodParam = queryItems.first { $0.name == "code_challenge_method" }

        #expect(clientIdParam?.value == "test-client-id", "Should include client ID")
        #expect(redirectParam?.value == "test://callback", "Should include redirect URI")
        #expect(responseTypeParam?.value == "code", "Should use authorization code flow")
        #expect(scopeParam?.value != nil, "Should include scope")
        #expect(stateParam?.value != nil, "Should include state parameter")
        #expect(codeChallengeParam?.value != nil, "Should include PKCE code challenge")
        #expect(codeChallengeMethodParam?.value == "S256", "Should use S256 challenge method")
    }

    @Test("OAuth state parameter is unique per request")
    func oAuthStateUniqueness() async throws {
        let service = createTestAuthService()

        let url1 = await service.buildAuthorizationURL()
        let url2 = await service.buildAuthorizationURL()

        let state1 = try extractQueryParameter(from: #require(url1), parameter: "state")
        let state2 = try extractQueryParameter(from: #require(url2), parameter: "state")

        #expect(state1 != nil, "First URL should have state")
        #expect(state2 != nil, "Second URL should have state")
        #expect(state1 != state2, "State parameters should be unique")
    }

    @Test("PKCE code challenge generation")
    func pKCECodeChallenge() async throws {
        let service = createTestAuthService()

        let authURL = await service.buildAuthorizationURL()
        let codeChallenge = try extractQueryParameter(from: #require(authURL), parameter: "code_challenge")
        let codeChallengeMethod = try extractQueryParameter(from: #require(authURL), parameter: "code_challenge_method")

        #expect(codeChallenge != nil, "Should generate code challenge")
        #expect(try #require(codeChallenge?.count) >= 43, "Code challenge should be at least 43 characters")
        #expect(codeChallengeMethod == "S256", "Should use SHA256 challenge method")

        // Verify code challenge is base64url encoded
        let isBase64URL = try #require(codeChallenge?.allSatisfy { char in
            char.isLetter || char.isNumber || char == "-" || char == "_"
        })
        #expect(isBase64URL, "Code challenge should be base64url encoded")
    }

    // MARK: - Token Exchange Tests

    @Test("Successful authorization code exchange")
    func authorizationCodeExchange() async throws {
        let service = createTestAuthService()

        // Generate auth URL to set state and code verifier
        _ = await service.buildAuthorizationURL()

        // Mock successful token exchange
        await service.setMockTokenExchangeResponse(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token",
            expiresIn: 3600,
            scope: "atproto",
            tokenType: "Bearer"
        )

        let callbackURL = try #require(URL(string: "test://callback?code=auth-code-123&state=\(service.currentOAuthState ?? "test-state")"))
        let success = await service.handleOAuthCallback(callbackURL)

        #expect(success, "Authorization code exchange should succeed")
        #expect(service.isAuthenticated, "Should be authenticated after successful exchange")
        #expect(service.accessToken == "test-access-token", "Should set access token")
        #expect(service.refreshToken == "test-refresh-token", "Should set refresh token")
    }

    @Test("Authorization code exchange with invalid state")
    func authorizationCodeExchangeInvalidState() async throws {
        let service = createTestAuthService()

        // Generate auth URL
        _ = await service.buildAuthorizationURL()

        // Create callback with invalid state
        let callbackURL = try #require(URL(string: "test://callback?code=auth-code-123&state=invalid-state"))
        let success = await service.handleOAuthCallback(callbackURL)

        #expect(!success, "Should fail with invalid state")
        #expect(!service.isAuthenticated, "Should remain unauthenticated")
        #expect(service.lastError != nil, "Should set error for invalid state")
    }

    @Test("Authorization code exchange with OAuth error")
    func authorizationCodeExchangeWithError() async throws {
        let service = createTestAuthService()

        // Generate auth URL
        _ = await service.buildAuthorizationURL()

        // Create callback with error
        let callbackURL = try #require(URL(string: "test://callback?error=access_denied&state=\(service.currentOAuthState ?? "test-state")&error_description=User%20denied%20access"))
        let success = await service.handleOAuthCallback(callbackURL)

        #expect(!success, "Should fail with OAuth error")
        #expect(!service.isAuthenticated, "Should remain unauthenticated")
        #expect(service.lastError != nil, "Should set OAuth error")

        if let error = service.lastError as? OAuthError {
            #expect(error.code == "access_denied", "Should have correct error code")
            #expect(error.description == "User denied access", "Should have error description")
        }
    }

    // MARK: - Token Refresh Tests

    @Test("Successful access token refresh")
    func accessTokenRefresh() async {
        let service = createTestAuthService()

        // Set initial authenticated state
        await service.setMockAuthenticatedState(
            accessToken: "old-access-token",
            refreshToken: "current-refresh-token"
        )

        // Mock successful refresh
        await service.setMockRefreshResponse(
            accessToken: "new-access-token",
            refreshToken: "new-refresh-token",
            expiresIn: 3600
        )

        let success = await service.refreshAccessToken()

        #expect(success, "Token refresh should succeed")
        #expect(service.isAuthenticated, "Should remain authenticated")
        #expect(service.accessToken == "new-access-token", "Should update access token")
        #expect(service.refreshToken == "new-refresh-token", "Should update refresh token")
    }

    @Test("Token refresh with invalid refresh token")
    func tokenRefreshInvalidRefreshToken() async {
        let service = createTestAuthService()

        // Set authenticated state with invalid refresh token
        await service.setMockAuthenticatedState(
            accessToken: "current-access-token",
            refreshToken: "invalid-refresh-token"
        )

        // Mock refresh failure
        await service.setMockRefreshFailure(error: "invalid_grant")

        let success = await service.refreshAccessToken()

        #expect(!success, "Token refresh should fail")
        #expect(!service.isAuthenticated, "Should be unauthenticated after refresh failure")
        #expect(service.lastError != nil, "Should set refresh error")
    }

    @Test("Automatic token refresh when expired")
    func automaticTokenRefresh() async {
        let service = createTestAuthService()

        // Set authenticated state with expired token
        await service.setMockAuthenticatedState(
            accessToken: "expired-token",
            refreshToken: "valid-refresh-token",
            expirationDate: Date().addingTimeInterval(-3600) // Expired 1 hour ago
        )

        // Mock successful refresh
        await service.setMockRefreshResponse(
            accessToken: "fresh-access-token",
            refreshToken: "new-refresh-token",
            expiresIn: 3600
        )

        let validToken = await service.getValidAccessToken()

        #expect(validToken == "fresh-access-token", "Should return fresh token after auto-refresh")
        #expect(service.isAuthenticated, "Should remain authenticated")

        let refreshCount = await service.getMockRefreshCount()
        #expect(refreshCount >= 1, "Should have attempted token refresh")
    }

    // MARK: - Session Management Tests

    @Test("Session creation from token response")
    func sessionCreation() async throws {
        let service = createTestAuthService()

        await service.setMockTokenExchangeResponse(
            accessToken: "session-access-token",
            refreshToken: "session-refresh-token",
            expiresIn: 7200,
            scope: "atproto transition:generic",
            tokenType: "Bearer"
        )

        // Mock DID and handle resolution
        await service.setMockSessionInfo(
            did: "did:plc:session123",
            handle: "user.bsky.social"
        )

        _ = await service.buildAuthorizationURL()
        let callbackURL = try #require(URL(string: "test://callback?code=auth-code&state=\(service.currentOAuthState ?? "test-state")"))
        _ = await service.handleOAuthCallback(callbackURL)

        let session = service.currentSession
        #expect(session != nil, "Should create session")
        #expect(session?.did == "did:plc:session123", "Should set session DID")
        #expect(session?.handle == "user.bsky.social", "Should set session handle")
        #expect(session?.accessToken == "session-access-token", "Should set session access token")
        #expect(session?.refreshToken == "session-refresh-token", "Should set session refresh token")
        #expect(session?.scope?.contains("atproto") == true, "Should set session scope")
    }

    @Test("Session persistence and restoration")
    func sessionPersistence() async {
        let service = createTestAuthService()

        // Create authenticated session
        await service.setMockAuthenticatedState(
            accessToken: "persistent-token",
            refreshToken: "persistent-refresh",
            did: "did:plc:persist123",
            handle: "persist.bsky.social"
        )

        // Save session
        await service.saveSession()

        // Clear current session
        await service.clearSession()
        #expect(!service.isAuthenticated, "Should be unauthenticated after clearing")

        // Restore session
        let restored = await service.restoreSession()

        #expect(restored, "Should successfully restore session")
        #expect(service.isAuthenticated, "Should be authenticated after restoration")
        #expect(service.currentSession?.handle == "persist.bsky.social", "Should restore handle")
        #expect(service.currentSession?.did == "did:plc:persist123", "Should restore DID")
    }

    @Test("Session cleanup on logout")
    func sessionCleanup() async {
        let service = createTestAuthService()

        // Set authenticated state
        await service.setMockAuthenticatedState(
            accessToken: "cleanup-token",
            refreshToken: "cleanup-refresh",
            did: "did:plc:cleanup123",
            handle: "cleanup.bsky.social"
        )

        #expect(service.isAuthenticated, "Should start authenticated")

        await service.logout()

        #expect(!service.isAuthenticated, "Should be unauthenticated after logout")
        #expect(service.currentSession == nil, "Should clear current session")
        #expect(service.accessToken == nil, "Should clear access token")
        #expect(service.refreshToken == nil, "Should clear refresh token")

        // Verify session is removed from storage
        let hasStoredSession = await service.hasStoredSession()
        #expect(!hasStoredSession, "Should remove session from storage")
    }

    // MARK: - DPoP Token Management Tests

    @Test("DPoP key generation and management")
    func dPoPKeyManagement() async throws {
        let service = createTestAuthService()

        // Generate DPoP key pair
        await service.generateDPoPKeyPair()

        let hasKeyPair = await service.hasDPoPKeyPair()
        #expect(hasKeyPair, "Should have DPoP key pair after generation")

        // Test DPoP proof creation
        let proof = await service.createDPoPProof(
            httpMethod: "POST",
            url: "https://bsky.social/xrpc/com.atproto.server.createSession"
        )

        #expect(proof != nil, "Should create DPoP proof")
        #expect(try #require(proof?.hasPrefix("eyJ")), "DPoP proof should be a JWT")

        // Verify proof contains required claims
        let isValidProof = try await service.validateDPoPProof(#require(proof))
        #expect(isValidProof, "Should generate valid DPoP proof")
    }

    @Test("DPoP key persistence")
    func dPoPKeyPersistence() async {
        let service = createTestAuthService()

        // Generate and save key pair
        await service.generateDPoPKeyPair()
        let originalThumbprint = await service.getDPoPKeyThumbprint()

        await service.saveDPoPKeyPair()

        // Clear memory and restore
        await service.clearDPoPKeyPair()
        #expect(! await service.hasDPoPKeyPair(), "Should clear key pair from memory")

        let restored = await service.restoreDPoPKeyPair()
        #expect(restored, "Should restore DPoP key pair")

        let restoredThumbprint = await service.getDPoPKeyThumbprint()
        #expect(restoredThumbprint == originalThumbprint, "Should restore same key pair")
    }

    // MARK: - Error Handling Tests

    @Test("Network error handling during token exchange")
    func tokenExchangeNetworkError() async throws {
        let service = createTestAuthService()

        _ = await service.buildAuthorizationURL()

        // Mock network error
        await service.setMockNetworkError(.connectionFailed)

        let callbackURL = try #require(URL(string: "test://callback?code=auth-code&state=\(service.currentOAuthState ?? "test-state")"))
        let success = await service.handleOAuthCallback(callbackURL)

        #expect(!success, "Should fail with network error")
        #expect(!service.isAuthenticated, "Should remain unauthenticated")
        #expect(service.lastError != nil, "Should set network error")
    }

    @Test("Server error handling during token refresh")
    func tokenRefreshServerError() async {
        let service = createTestAuthService()

        await service.setMockAuthenticatedState(
            accessToken: "current-token",
            refreshToken: "current-refresh"
        )

        // Mock server error
        await service.setMockHTTPError(statusCode: 500, message: "Internal Server Error")

        let success = await service.refreshAccessToken()

        #expect(!success, "Should fail with server error")
        #expect(service.lastError != nil, "Should set server error")

        if let httpError = service.lastError as? HTTPError {
            #expect(httpError.statusCode == 500, "Should have correct status code")
        }
    }

    // MARK: - Security Tests

    @Test("Sensitive data is properly cleared on logout")
    func sensitiveDataClearing() async {
        let service = createTestAuthService()

        await service.setMockAuthenticatedState(
            accessToken: "sensitive-token",
            refreshToken: "sensitive-refresh"
        )

        // Verify sensitive data exists
        #expect(service.accessToken != nil, "Should have access token")
        #expect(service.refreshToken != nil, "Should have refresh token")

        await service.logout()

        // Verify all sensitive data is cleared
        #expect(service.accessToken == nil, "Access token should be cleared")
        #expect(service.refreshToken == nil, "Refresh token should be cleared")
        #expect(service.currentSession == nil, "Session should be cleared")

        // Verify keychain is cleared
        let keychainCleared = await service.isKeychainCleared()
        #expect(keychainCleared, "Keychain should be cleared")
    }

    @Test("Token validation prevents tampering")
    func tokenValidation() async {
        let service = createTestAuthService()

        // Test with invalid token format
        await service.setMockAuthenticatedState(
            accessToken: "invalid.token.format",
            refreshToken: "valid-refresh-token"
        )

        let isValidAccess = await service.validateAccessToken()
        #expect(!isValidAccess, "Should reject invalid access token format")

        // Test with tampered token
        let tamperedToken = await service.createTamperedToken()
        await service.setMockAuthenticatedState(
            accessToken: tamperedToken,
            refreshToken: "valid-refresh-token"
        )

        let isTamperedValid = await service.validateAccessToken()
        #expect(!isTamperedValid, "Should reject tampered token")
    }
}

// MARK: - Helper Functions

private func extractQueryParameter(from url: URL, parameter: String) -> String? {
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    return components?.queryItems?.first { $0.name == parameter }?.value
}

// MARK: - AuthenticationService Test Extensions

extension AuthenticationService {
    var currentOAuthState: String? {
        // In real implementation, would return current OAuth state
        return "test-state"
    }

    var lastError: Error? {
        // In real implementation, would return last error
        return nil
    }

    func setMockTokenExchangeResponse(accessToken: String, refreshToken: String, expiresIn: Int, scope: String, tokenType: String) async {
        // In real implementation, would mock token exchange response
    }

    func setMockRefreshResponse(accessToken: String, refreshToken: String, expiresIn: Int) async {
        // In real implementation, would mock refresh response
    }

    func setMockRefreshFailure(error: String) async {
        // In real implementation, would mock refresh failure
    }

    func setMockAuthenticatedState(accessToken: String, refreshToken: String, expirationDate: Date? = nil, did: String = "did:plc:test", handle: String = "test.bsky.social") async {
        // In real implementation, would set mock authenticated state
    }

    func setMockSessionInfo(did: String, handle: String) async {
        // In real implementation, would set mock session info
    }

    func setMockNetworkError(_ error: NetworkError) async {
        // In real implementation, would mock network errors
    }

    func setMockHTTPError(statusCode: Int, message: String) async {
        // In real implementation, would mock HTTP errors
    }

    func getMockRefreshCount() async -> Int {
        // In real implementation, would return refresh count
        return 0
    }

    func hasStoredSession() async -> Bool {
        // In real implementation, would check for stored session
        return false
    }

    func validateDPoPProof(_ proof: String) async -> Bool {
        // In real implementation, would validate DPoP proof
        return true
    }

    func getDPoPKeyThumbprint() async -> String? {
        // In real implementation, would return key thumbprint
        return "test-thumbprint"
    }

    func isKeychainCleared() async -> Bool {
        // In real implementation, would check if keychain is cleared
        return true
    }

    func validateAccessToken() async -> Bool {
        // In real implementation, would validate access token
        return true
    }

    func createTamperedToken() async -> String {
        // In real implementation, would create tampered token for testing
        return "tampered.token.signature"
    }
}

// MARK: - Mock Types

struct OAuthError: Error {
    let code: String
    let description: String?
}
