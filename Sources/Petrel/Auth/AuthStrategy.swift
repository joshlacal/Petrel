//
//  AuthStrategy.swift
//  Petrel
//
//  Created by Josh LaCalamito on 1/19/26.
//

import Foundation

/// Defines the common interface for Petrel authentication strategies.
public protocol AuthStrategy: AuthenticationProvider, Sendable {
    /// Starts the OAuth flow for an existing user.
    func startOAuthFlow(identifier: String?, bskyAppViewDID: String?, bskyChatDID: String?) async throws
        -> URL

    /// Starts the OAuth flow for account creation.
    func startOAuthFlowForSignUp(pdsURL: URL?, bskyAppViewDID: String?, bskyChatDID: String?) async throws
        -> URL

    /// Handles the OAuth callback URL after user authentication.
    func handleOAuthCallback(url: URL) async throws -> (did: String, handle: String?, pdsURL: URL)

    /// Authenticates using legacy password-based authentication.
    func loginWithPassword(
        identifier: String,
        password: String,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> (did: String, handle: String?, pdsURL: URL)

    /// Logs out the current user.
    func logout() async throws

    /// Cancels any ongoing OAuth authentication flows.
    func cancelOAuthFlow() async

    /// Indicates whether authentication tokens exist for the current account.
    func tokensExist() async -> Bool

    /// Sets the authentication progress delegate.
    func setProgressDelegate(_ delegate: AuthProgressDelegate?) async

    /// Sets the authentication failure delegate.
    func setFailureDelegate(_ delegate: AuthFailureDelegate?) async

    /// Attempts to recover from catastrophic auth failures.
    func attemptRecoveryFromServerFailures(for did: String?) async throws
}
