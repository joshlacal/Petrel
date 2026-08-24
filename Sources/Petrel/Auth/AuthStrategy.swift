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

    /// Starts the OAuth flow for an existing user and returns both the authorization URL and state token.
    func startOAuthFlowWithState(identifier: String?, bskyAppViewDID: String?, bskyChatDID: String?) async throws
        -> (url: URL, state: String)

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

    /// Starts a progressive gateway scope upgrade flow.
    func startGatewayScopeUpgrade(
        requesting: Set<String>,
        for expectedDID: String,
        callbackURL: URL
    ) async throws -> URL

    /// Completes a progressive gateway scope upgrade flow.
    func completeGatewayScopeUpgrade(
        callbackURL: URL,
        for expectedDID: String
    ) async throws -> Set<String>

    /// Authoritatively fetches granted scopes for the account from the auth provider.
    func fetchGrantedScopes(for did: String?) async throws -> Set<String>
}

extension AuthStrategy {
    public func startOAuthFlow(identifier: String? = nil, bskyAppViewDID: String? = nil, bskyChatDID: String? = nil) async throws
        -> URL {
        try await startOAuthFlow(identifier: identifier, bskyAppViewDID: bskyAppViewDID, bskyChatDID: bskyChatDID)
    }

    public func startOAuthFlowWithState(identifier: String? = nil, bskyAppViewDID: String? = nil, bskyChatDID: String? = nil) async throws
        -> (url: URL, state: String) {
        throw AuthError.oauthFlowStateUnavailable
    }

    public func startGatewayScopeUpgrade(
        requesting: Set<String>,
        for expectedDID: String,
        callbackURL: URL
    ) async throws -> URL {
        throw AuthError.invalidOAuthConfiguration
    }

    public func completeGatewayScopeUpgrade(
        callbackURL: URL,
        for expectedDID: String
    ) async throws -> Set<String> {
        throw AuthError.invalidOAuthConfiguration
    }

    public func fetchGrantedScopes(for did: String?) async throws -> Set<String> {
        throw AuthError.invalidOAuthConfiguration
    }
}
