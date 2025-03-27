//
//  Event.swift
//  Petrel
//
//  Created by Josh LaCalamito on 10/18/24.
//

import Foundation

/// Defines all possible events in the system.
enum Event: Sendable {
    // MARK: - Initialization Events

    /// Indicates that the initialization process has started.
    case initializationStarted

    /// Indicates that the initialization process has completed successfully.
    case initializationCompleted

    /// Indicates that the initialization process has failed with an error.
    case initializationFailed(Error)

    // MARK: - Authentication Events

    /// Indicates that an authentication process (login) has started.
    case authenticationStarted

    /// Indicates that the authentication process (login) has succeeded.
    case authenticationSucceeded

    /// Indicates that the authentication process (login) has failed with an error.
    case authenticationFailed(Error)

    /// Indicates that an authentication process (logout) has started.
    case logoutStarted

    /// Indicates that the authentication process (logout) has succeeded.
    case logoutSucceeded

    /// Indicates that the authentication process (logout) has failed with an error.
    case logoutFailed(Error)

    /// Indicates that authentication is required (e.g., session expired).
    case authenticationRequired

    // MARK: - Token Events

    /// Request to fetch the current access token
    case accessTokenRequested

    /// Response to an access token request
    case accessTokenFetched(Result<String, Error>)

    /// Notification that a token refresh operation has started
    case tokenRefreshStarted

    /// Notification that a token refresh operation has completed
    case tokenRefreshCompleted(Result<(accessToken: String, refreshToken: String), Error>)

    /// Notification that tokens have been manually updated (e.g., after initial OAuth flow)
    case tokensUpdated(accessToken: String, refreshToken: String)

    /// Notification that a token has expired
    case tokenExpired

    /// Notification that tokens have been cleared (e.g., during logout)
    case tokensCleared

    // MARK: - Session Events

    /// Indicates that the session has been initialized successfully.
    case sessionInitialized

    /// Indicates that the session is valid.
    case sessionValid

    /// Indicates that the session has expired.
    case sessionExpired

    /// Indicates that session validation has failed with an error.
    case sessionValidationFailed(Error)

    // MARK: - Network Events

    /// Indicates that a network request is about to be performed.
    /// - Parameters:
    ///   - endpoint: The API endpoint.
    ///   - method: The HTTP method (e.g., GET, POST).
    ///   - headers: The HTTP headers.
    ///   - body: The request body.
    case performNetworkRequest(
        endpoint: String, method: String, headers: [String: String], body: Data?
    )

    /// Indicates that a network request has been completed successfully.
    /// - Parameters:
    ///   - request: The original URLRequest.
    ///   - data: The response data.
    ///   - response: The HTTPURLResponse.
    case requestCompleted(request: URLRequest, data: Data, response: HTTPURLResponse)

    /// Indicates that a network request has failed with an error.
    /// - Parameters:
    ///   - request: The original URLRequest.
    ///   - error: The error encountered.
    case networkRequestFailed(request: URLRequest, error: Error)

    /// Indicates that a network error has occurred.
    /// - Parameter error: The error encountered.
    case networkError(Error)

    // MARK: - OAuth Events

    /// Indicates that the OAuth flow has been started.
    /// - Parameter url: The authorization URL.
    case oauthFlowStarted(URL)

    /// Indicates that the OAuth callback has been received.
    /// - Parameter url: The callback URL containing authorization data.
    case oauthCallbackReceived(URL)

    /// Indicates that OAuth tokens have been received.
    /// - Parameters:
    ///   - accessToken: The access token.
    ///   - refreshToken: The refresh token.
    case oauthTokensReceived(accessToken: String, refreshToken: String)

    /// Indicates that the OAuth flow has failed with an error.
    /// - Parameter error: The error encountered during OAuth flow.
    case oauthFlowFailed(Error)

    /// Indicates that the OAuth flow has been completed successfully.
    case oauthFlowCompleted

    /// Indicates that the OAuth flow has been canceled.
    case oauthFlowCanceled

    // MARK: - Multi-Account Events

    /// Indicates that the active account has been switched
    /// - Parameter did: The DID of the account that was switched to
    case accountSwitched(did: String)

    /// Indicates that an account has been added
    /// - Parameter did: The DID of the account that was added
    case accountAdded(did: String)

    /// Indicates that an account has been removed
    /// - Parameter did: The DID of the account that was removed
    case accountRemoved(did: String)

    /// Indicates that the account list has been updated
    /// - Parameter accounts: The list of available accounts (DIDs)
    case accountsListUpdated(accounts: [String])

    /// Indicates a request to restore the previous active account
    /// - Parameter did: The DID of the account to restore, if available
    case restorePreviousAccount(did: String?)

    // MARK: - Configuration Events

    /// Indicates that the configuration has been updated.
    /// - Parameter newURL: The new configuration URL.
    case baseURLUpdated(URL)

    /// Indicates that the PDS (Personal Data Server) URL has been resolved.
    /// - Parameter pdsURL: The resolved PDS URL.
    case pdsURLResolved(URL)

    /// Indicates configuration has been loaded into `ConfigurationManager`
    case userConfigurationUpdated(did: String, handle: String, serviceEndpoint: String)

    /// Indicates configuration has been loaded into `ConfigurationManager`
    case configurationLoaded

    // MARK: - DID Resolution Events

    /// Indicates that a DID (Decentralized Identifier) has been resolved.
    /// - Parameter did: The resolved DID.
    case didResolved(did: String)

    /// Indicates that a handle has been resolved.
    /// - Parameter did: The resolved DID.
    case handleResolved(handle: String)

    /// Indicates that resolving a DID to PDS URL has succeeded.
    /// - Parameter pdsURL: The resolved PDS URL.
    case didToPDSURLResolved(pdsURL: URL)

    /// Indicates that resolving a DID has failed with an error.
    /// - Parameter error: The error encountered during DID resolution.
    case didResolutionFailed(Error)

    // MARK: - Logging Events

    /// Indicates that a log message has been generated.
    /// - Parameters:
    ///   - level: The log level (e.g., info, debug, error).
    ///   - message: The log message.
    case logMessage(level: LogLevel, message: String)

    // MARK: - General Events

    /// Placeholder for additional custom events.
    /// - Parameter data: Associated data for the event.
    case customEvent(name: String, data: any Sendable)

    // MARK: - Helper Enums

    /// Defines the severity level of log messages.
    enum LogLevel {
        case info
        case debug
        case error
        case warning
        // Add other log levels as needed
    }
}
