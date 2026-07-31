//
//  AuthTypes.swift
//  Petrel
//
//  Shared authentication vocabulary: progress/failure delegates, the token
//  refresh result, and the error types surfaced by every auth strategy.
//

import Foundation

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

/// Delegate protocol for handling catastrophic authentication failures
public protocol AuthFailureDelegate: AnyObject, Sendable {
    /// Called when authentication fails due to server/infrastructure issues
    /// - Parameters:
    ///   - did: The DID that experienced the failure
    ///   - error: The specific error that occurred
    ///   - isRetryable: Whether this error could be resolved by retrying later
    func handleCatastrophicAuthFailure(did: String, error: Error, isRetryable: Bool) async

    /// Called when the circuit breaker opens due to repeated failures
    /// - Parameter did: The DID for which the circuit opened
    func handleCircuitBreakerOpen(did: String) async
}

/// Result of a token refresh attempt
public enum TokenRefreshResult: Sendable {
    case refreshedSuccessfully // Token was actually refreshed
    case stillValid // Token is still valid, no refresh needed
    case skippedDueToRateLimit // Refresh was skipped due to rate limiting
}

/// A typed refusal from a client assertion backend.
public struct ClientAssertionBackendError: Error, LocalizedError, Sendable, Equatable {
    public let statusCode: Int
    public let code: String?

    public init(statusCode: Int, code: String?) {
        self.statusCode = statusCode
        self.code = code
    }

    public var errorDescription: String? {
        "The client assertion backend refused the request (HTTP \(statusCode)\(code.map { ": \($0)" } ?? ""))."
    }
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

// MARK: - Data Extension for Base64URL Encoding

extension Data {
    func base64URLEscaped() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
