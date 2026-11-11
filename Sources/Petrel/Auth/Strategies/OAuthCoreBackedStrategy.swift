//
//  OAuthCoreBackedStrategy.swift
//  Petrel
//
//  The `AuthStrategy` surface shared by every strategy that runs the atproto
//  OAuth flow through `OAuthCore`.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// An authentication strategy whose OAuth flow is implemented by ``OAuthCore``.
///
/// Conforming strategies differ only in how the client authenticates to the
/// authorization server, which is configured on the core. Everything else —
/// flow start, callback verification, refresh, revocation, DPoP — is shared, so
/// a fix to the flow applies to every OAuth mode at once.
protocol OAuthCoreBackedStrategy: AuthStrategy {
    var core: OAuthCore { get }
}

extension OAuthCoreBackedStrategy {
    // MARK: Starting a flow

    func startOAuthFlow(
        identifier: String?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> URL {
        try await startOAuthFlowWithState(
            identifier: identifier,
            bskyAppViewDID: bskyAppViewDID,
            bskyChatDID: bskyChatDID
        ).url
    }

    func startOAuthFlowWithState(
        identifier: String? = nil,
        bskyAppViewDID: String? = nil,
        bskyChatDID: String? = nil
    ) async throws -> (url: URL, state: String) {
        // With no identifier the flow starts from the default hosting provider.
        let target: OAuthFlowTarget = identifier.map { .identifier($0) } ?? .server(Self.defaultServerURL)
        return try await core.startAuthorizationFlow(
            target: target,
            bskyAppViewDID: bskyAppViewDID,
            bskyChatDID: bskyChatDID
        )
    }

    func startOAuthFlowForSignUp(
        pdsURL: URL?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> URL {
        try await core.startAuthorizationFlow(
            target: .server(pdsURL ?? Self.defaultServerURL),
            bskyAppViewDID: bskyAppViewDID,
            bskyChatDID: bskyChatDID
        ).url
    }

    /// Starts a flow from an account identifier or a server, optionally
    /// requesting a scope other than the client's configured one.
    func startOAuthFlow(
        target: OAuthFlowTarget,
        scope: String?,
        bskyAppViewDID: String? = nil,
        bskyChatDID: String? = nil
    ) async throws -> (url: URL, state: String) {
        try await core.startAuthorizationFlow(
            target: target,
            scope: scope,
            bskyAppViewDID: bskyAppViewDID,
            bskyChatDID: bskyChatDID
        )
    }

    /// The hosting provider used when a flow is started with neither an
    /// identifier nor a server.
    static var defaultServerURL: URL {
        URL(staticString: "https://bsky.social")
    }

    // MARK: Completing, cancelling, ending

    func handleOAuthCallback(url: URL) async throws -> (did: String, handle: String?, pdsURL: URL) {
        try await core.completeAuthorizationFlow(callbackURL: url)
    }

    func loginWithPassword(
        identifier _: String,
        password _: String,
        bskyAppViewDID _: String?,
        bskyChatDID _: String?
    ) async throws -> (did: String, handle: String?, pdsURL: URL) {
        // OAuth strategies do not accept passwords.
        throw AuthError.invalidOAuthConfiguration
    }

    func logout() async throws {
        try await core.logoutCurrentAccount()
    }

    /// Revokes `did`'s session at its authorization server without touching local state.
    @discardableResult
    func revokeSession(for did: String) async -> Bool {
        await core.revokeSession(for: did)
    }

    func cancelOAuthFlow() async {
        await core.cancelAuthorizationFlows()
    }

    func tokensExist() async -> Bool {
        await core.tokensExist()
    }

    func setProgressDelegate(_ delegate: AuthProgressDelegate?) async {
        await core.setProgressDelegate(delegate)
    }

    func setFailureDelegate(_: AuthFailureDelegate?) async {}

    func attemptRecoveryFromServerFailures(for did: String?) async throws {
        try await core.attemptRecoveryFromServerFailures(for: did)
    }

    // MARK: AuthenticationProvider

    func prepareAuthenticatedRequest(_ request: URLRequest) async throws -> URLRequest {
        try await core.prepareAuthenticatedRequest(request)
    }

    func prepareAuthenticatedRequestWithContext(_ request: URLRequest) async throws -> (URLRequest, AuthContext) {
        try await core.prepareAuthenticatedRequestWithContext(request)
    }

    func refreshTokenIfNeeded() async throws -> TokenRefreshResult {
        try await core.refreshTokenIfNeeded()
    }

    func refreshTokenIfNeeded(forceRefresh: Bool) async throws -> TokenRefreshResult {
        try await core.refreshTokenIfNeeded(forceRefresh: forceRefresh)
    }

    func handleUnauthorizedResponse(
        _ response: HTTPURLResponse,
        data: Data,
        for request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        try await core.handleUnauthorizedResponse(response, data: data, for: request)
    }

    func updateDPoPNonce(for url: URL, from headers: [String: String], did: String?, jkt: String?) async {
        await core.updateDPoPNonce(for: url, from: headers, did: did, jkt: jkt)
    }
}
