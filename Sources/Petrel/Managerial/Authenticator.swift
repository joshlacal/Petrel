import Foundation

/// A protocol defining the authentication methods for both legacy and OAuth authentication.
public protocol Authenticator: Sendable {
    /// Performs a login using identifier and password (primarily for legacy authentication).
    /// - Parameters:
    ///   - identifier: The user's identifier (e.g., username or email).
    ///   - password: The user's password.
    /// - Throws: An error if the login fails.
    func login(identifier: String, password: String) async throws

    /// Initiates the OAuth flow.
    /// - Parameter identifier: The user's identifier for OAuth.
    /// - Returns: The URL to start the OAuth flow.
    /// - Throws: An error if starting the OAuth flow fails.
    func startOAuthFlow(identifier: String) async throws -> URL

    /// Handles the OAuth callback after the user has authenticated.
    /// - Parameter url: The callback URL received after OAuth authentication.
    /// - Throws: An error if handling the callback fails.
    func handleOAuthCallback(url: URL) async throws

    /// Logs out the current user.
    /// - Throws: An error if the logout fails.
    func logout() async throws

    /// Refreshes the authentication token if needed.
    /// - Throws: An error if the token refresh fails.
    func refreshTokenIfNeeded() async throws -> Bool
}
