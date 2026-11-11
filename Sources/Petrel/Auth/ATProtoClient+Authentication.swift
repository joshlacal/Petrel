//
//  ATProtoClient+Authentication.swift
//  Petrel
//
//  Authentication API beyond the basic sign-in calls: server-first login,
//  per-flow scopes and scope upgrades, typed granted scopes, confidential
//  client authentication, auth-factor sign-in, and account hosting status.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public extension ATProtoClient {
    private func authenticationManager() async throws -> AuthManager {
        guard let manager = await networkService.authenticationProvider as? AuthManager else {
            throw OAuthConfigurationError.unsupportedByAuthMode
        }
        return manager
    }

    // MARK: - Starting OAuth flows

    /// Starts an OAuth flow from a hosting provider instead of an account
    /// identifier ("server-first" login).
    ///
    /// Use this when the user knows their provider but not their handle — they
    /// only remember their email address, or their handle is broken — and for
    /// creating a new account. No account is bound to the flow up front; after
    /// the user signs in, Petrel resolves the returned account's DID document
    /// and requires its PDS to name the same authorization server before the
    /// session is accepted.
    ///
    /// - Parameters:
    ///   - server: The provider's PDS or entryway URL, e.g. `https://bsky.social`.
    ///   - scopes: The scopes to request; `nil` requests the configured scope.
    /// - Returns: The authorization URL to open in a browser. Pass the redirect
    ///   it ends with to ``handleOAuthCallback(url:)``.
    /// - Throws: ``OAuthMetadataError`` when the server's OAuth metadata does not
    ///   satisfy the atproto profile; ``OAuthConfigurationError`` when the scope
    ///   lacks `atproto` or the client's mode has no OAuth flow.
    func startOAuthFlow(server: URL, scopes: ATProtoScopeSet? = nil) async throws -> URL {
        try await authenticationManager()
            .startOAuthFlow(target: .server(server), scope: scopes?.scopeString)
            .url
    }

    /// Starts an OAuth flow for an account, requesting specific scopes instead
    /// of the client's configured scope.
    ///
    /// - Parameters:
    ///   - identifier: The account's handle or DID.
    ///   - scopes: The scopes to request. Must include `.atproto`, and must be a
    ///     subset of the scopes declared in the client metadata document.
    /// - Returns: The authorization URL to open in a browser.
    func startOAuthFlow(identifier: String, scopes: ATProtoScopeSet) async throws -> URL {
        try await authenticationManager()
            .startOAuthFlow(target: .identifier(identifier), scope: scopes.scopeString)
            .url
    }

    /// Asks the signed-in user to grant a different set of scopes.
    ///
    /// atproto OAuth has no incremental grant: the account is sent through the
    /// authorization flow again, and the new session, with whatever the user
    /// approves, replaces the current one when ``handleOAuthCallback(url:)``
    /// completes. Until then the existing session keeps working.
    ///
    /// - Parameter scopes: The complete set of scopes wanted, including `.atproto`.
    /// - Returns: The authorization URL to open in a browser.
    /// - Throws: ``AuthError/noActiveAccount`` when nobody is signed in.
    func requestScopes(_ scopes: ATProtoScopeSet) async throws -> URL {
        guard let did = await getCurrentAccount()?.did else {
            throw AuthError.noActiveAccount
        }
        return try await startOAuthFlow(identifier: did, scopes: scopes)
    }

    /// The scopes the authorization server granted to an account, as typed
    /// scopes that can answer "may I do this?" — for example
    /// `grantedScopes().allowsRepo(.init(collection: "app.bsky.feed.post", action: .create))`.
    ///
    /// The grant may be narrower than what was requested. Scope strings this
    /// version of Petrel does not recognise are listed in the set's
    /// `unrecognized` and grant nothing. Empty for unknown accounts and for
    /// sessions without a tracked grant (app-password and gateway sessions).
    ///
    /// - Parameter did: The account DID, or `nil` for the active account.
    func grantedScopes(for did: String? = nil) async -> ATProtoScopeSet {
        ATProtoScopeSet(rawScopes: await getGrantedScopes(for: did))
    }

    // MARK: - Confidential client

    /// Makes this OAuth client a confidential client that authenticates to
    /// authorization servers with `private_key_jwt`, signing its own client
    /// assertions.
    ///
    /// For server-side Swift that holds its client-authentication key (use
    /// `AuthMode.cab` when a backend holds the key for an app). The key's
    /// public half must be published in the `jwks` of the client metadata
    /// document — see ``OAuthConfig/clientMetadataDocument(applicationType:clientName:additionalRedirectURIs:confidentialKeys:)``.
    /// Call this before starting a flow; the same key must keep being used for
    /// refreshes of the sessions it created.
    ///
    /// - Parameter signer: The signing key, or a custom signer backed by a KMS or HSM.
    /// - Throws: ``OAuthConfigurationError/unsupportedByAuthMode`` unless the
    ///   client was created with `AuthMode.publicOAuth`.
    func useClientAssertionSigner(_ signer: any OAuthClientAssertionSigner) async throws {
        try await authenticationManager().useClientAssertionSigner(signer)
    }

    // MARK: - App passwords

    /// Signs in with an app password and the emailed sign-in code of an account
    /// that has email two-factor authentication enabled.
    ///
    /// Sign in without a code first; when that fails with
    /// ``AuthFactorTokenRequiredError`` the server has emailed the code. Ask the
    /// user for it and call this method.
    ///
    /// - Parameters:
    ///   - identifier: The account's handle, DID or email address.
    ///   - password: The app password.
    ///   - authFactorToken: The code from the email.
    /// - Returns: The signed-in account's DID, handle and PDS URL.
    /// - Throws: ``AccountStatusError`` when the account is taken down;
    ///   ``AuthError/invalidCredentials`` when the password or code is wrong.
    @discardableResult
    func loginWithPassword(
        identifier: String,
        password: String,
        authFactorToken: String
    ) async throws -> (did: String, handle: String?, pdsURL: URL) {
        let account = try await authenticationManager().loginWithPassword(
            identifier: identifier,
            password: password,
            authFactorToken: authFactorToken,
            bskyAppViewDID: nil,
            bskyChatDID: nil
        )
        try await switchToAccount(did: account.did)
        return account
    }

    // MARK: - Account status

    /// Asks the signed-in account's PDS for the account's current hosting
    /// status (`com.atproto.server.getSession`).
    ///
    /// A deactivated account can still hold a session, so that it can be
    /// reactivated: this is how an app finds out. A taken-down or suspended
    /// account, which the server refuses outright, is reported as that status
    /// rather than as a thrown error.
    ///
    /// - Returns: The status; ``AccountStatus/active`` for an account in good standing.
    /// - Throws: ``AuthError/noActiveAccount`` when nobody is signed in, or the
    ///   underlying error when the PDS cannot be reached.
    func fetchAccountStatus() async throws -> AccountStatus {
        guard await getCurrentAccount() != nil else {
            throw AuthError.noActiveAccount
        }
        do {
            let (responseCode, session) = try await com.atproto.server.getSession()
            guard let session else {
                throw AuthError.serverError(responseCode, "com.atproto.server.getSession")
            }
            return AccountStatus(active: session.active, status: session.status)
        } catch let statusError as AccountStatusError {
            return statusError.status
        }
    }

    /// The hosting status the server reported when the account's app-password
    /// session was created or last refreshed, without a network request.
    /// `nil` when none has been reported in this process; use
    /// ``fetchAccountStatus()`` for a current answer.
    ///
    /// - Parameter did: The account DID, or `nil` for the active account.
    func lastKnownAccountStatus(for did: String? = nil) async -> AccountStatus? {
        guard let manager = try? await authenticationManager() else { return nil }
        var target = did
        if target == nil {
            target = await getCurrentAccount()?.did
        }
        guard let target else { return nil }
        return await manager.lastKnownAccountStatus(for: target)
    }
}
