//
//  OAuthCore+Flow.swift
//  Petrel
//
//  The atproto OAuth authorization flow, shared by every OAuth strategy:
//  starting a flow (identifier-first or server-first), completing it from the
//  redirect callback, refreshing, revoking and logging out. Strategies differ
//  only in how the client authenticates (`OAuthClientAuthenticating`).
//

import Crypto
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Where an authorization flow starts ("Identity Authentication" in the OAuth spec).
enum OAuthFlowTarget: Sendable, Equatable {
    /// A public account identifier supplied by the user: a handle or a DID. The
    /// account's DID is bound to the flow and the token response's `sub` must match it.
    case identifier(String)
    /// A hosting provider supplied by the user: a PDS or entryway URL. Only the
    /// authorization server's issuer is bound to the flow; the account is
    /// verified against it after the token response.
    case server(URL)

    var deduplicationKey: String {
        switch self {
        case let .identifier(identifier): "id:\(identifier.lowercased())"
        case let .server(url): "server:\(url.absoluteString.lowercased())"
        }
    }
}

extension OAuthCore {
    // MARK: - Delegates

    func setProgressDelegate(_ delegate: AuthProgressDelegate?) {
        progressDelegate = delegate
    }

    private func emitProgress(_ event: AuthProgressEvent) async {
        await progressDelegate?.authenticationProgress(event)
    }

    // MARK: - Starting a Flow

    /// Starts an authorization flow and returns the URL to open in the user's
    /// browser, with the `state` token that identifies the flow.
    ///
    /// - Parameters:
    ///   - target: The account identifier or server the user supplied.
    ///   - scope: The scope to request, or `nil` for the client's configured scope.
    ///     Must include `atproto`.
    func startAuthorizationFlow(
        target: OAuthFlowTarget,
        scope: String? = nil,
        bskyAppViewDID: String? = nil,
        bskyChatDID: String? = nil
    ) async throws -> (url: URL, state: String) {
        let key = "\(target.deduplicationKey)|\(scope ?? "")"
        if let existing = oauthStartTasks[key] {
            return try await existing.value
        }

        let task = Task<(url: URL, state: String), Error>(priority: .userInitiated) { [weak self] in
            guard let self else { throw AuthError.invalidOAuthConfiguration }
            return try await self.beginAuthorizationFlow(
                target: target,
                scope: scope,
                bskyAppViewDID: bskyAppViewDID,
                bskyChatDID: bskyChatDID
            )
        }
        oauthStartTasks[key] = task
        defer { oauthStartTasks.removeValue(forKey: key) }
        return try await task.value
    }

    private func beginAuthorizationFlow(
        target: OAuthFlowTarget,
        scope: String?,
        bskyAppViewDID: String?,
        bskyChatDID: String?
    ) async throws -> (url: URL, state: String) {
        let requestedScope = scope ?? oauthConfig.scope
        guard ATProtoScopeSet(scope: requestedScope).includesAtproto else {
            throw OAuthConfigurationError.scopeMissingAtproto(requestedScope)
        }

        // Resolve the authorization server. Its metadata is validated here —
        // issuer equal to the origin it was fetched from, profile requirements
        // met, endpoints https — before anything is sent to it or shown to the user.
        let loginHint: String?
        let expectedDID: String?
        let pdsURL: URL
        let metadata: AuthorizationServerMetadata
        switch target {
        case let .identifier(identifier):
            await emitProgress(.resolvingHandle(identifier))
            let did = identifier.hasPrefix("did:")
                ? identifier
                : try await didResolver.resolveHandleToDID(handle: identifier)
            pdsURL = try await didResolver.resolveDIDToPDSURL(did: did)
            await emitProgress(.fetchingMetadata(url: pdsURL.absoluteString))
            metadata = try await resolveAuthorizationServer(forPDS: pdsURL)
            loginHint = identifier
            expectedDID = did
        case let .server(serverURL):
            await emitProgress(.fetchingMetadata(url: serverURL.absoluteString))
            metadata = try await resolveAuthorizationServer(forServer: serverURL)
            pdsURL = serverURL
            loginHint = nil
            expectedDID = nil
        }

        await emitProgress(.generatingParameters)
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)
        let stateToken = UUID().uuidString
        // A new DPoP key for this session, used from the PAR request onward.
        let flowKey = P256.Signing.PrivateKey().rawRepresentation
        let dpopJKT = try calculateJWKThumbprint(
            jwk: createJWK(from: P256.Signing.PrivateKey(rawRepresentation: flowKey))
        )

        let (requestURI, parNonce) = try await pushAuthorizationRequest(
            metadata: metadata,
            codeChallenge: codeChallenge,
            identifier: loginHint,
            state: stateToken,
            scope: requestedScope,
            flowKey: flowKey
        )

        var oauthState = OAuthState(
            stateToken: stateToken,
            codeVerifier: codeVerifier,
            createdAt: Date(),
            initialIdentifier: loginHint,
            targetPDSURL: pdsURL,
            ephemeralDPoPKey: flowKey,
            parResponseNonce: parNonce,
            bskyAppViewDID: bskyAppViewDID,
            bskyChatDID: bskyChatDID,
            expectedIssuer: metadata.issuer,
            expectedPDSOrigin: pdsURL.absoluteString,
            expectedDID: expectedDID,
            redirectURI: oauthConfig.redirectUri,
            dpopJKT: dpopJKT,
            tokenEndpoint: metadata.tokenEndpoint,
            authorizationEndpoint: metadata.authorizationEndpoint
        )
        oauthState.authorizationServerMetadata = metadata
        oauthState.requestedScope = scope

        let generation = cancellationGeneration
        inFlightOAuthStateTokens.insert(stateToken)
        do {
            try await storage.saveOAuthState(oauthState)
        } catch {
            inFlightOAuthStateTokens.remove(stateToken)
            throw error
        }

        if cancellationGeneration != generation || !inFlightOAuthStateTokens.contains(stateToken) {
            deniedStateTokens.insert(stateToken)
            _ = try? await storage.deleteOAuthState(for: stateToken)
            inFlightOAuthStateTokens.remove(stateToken)
            throw AuthError.cancelled
        }

        // The redirect carries only `client_id` and `request_uri` (RFC 9126 §4);
        // every other parameter was pushed.
        guard var components = URLComponents(string: metadata.authorizationEndpoint) else {
            throw OAuthMetadataError.invalidEndpoint(
                field: "authorization_endpoint", value: metadata.authorizationEndpoint
            )
        }
        let pushed = Self.formEncode([("client_id", oauthConfig.clientId), ("request_uri", requestURI)])
        components.percentEncodedQuery = [components.percentEncodedQuery, pushed]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "&")
        guard let url = components.url else { throw AuthError.authorizationFailed }
        return (url, stateToken)
    }

    /// Form-encodes ordered pairs with the strict value alphabet of `encodeFormData`.
    static func formEncode(_ pairs: [(String, String)]) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+;")
        return pairs.map { name, value in
            let escapedName = name.addingPercentEncoding(withAllowedCharacters: allowed) ?? name
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(escapedName)=\(escapedValue)"
        }.joined(separator: "&")
    }

    // MARK: - Completing a Flow

    /// Completes an authorization flow from its redirect callback.
    ///
    /// Before the authorization code is sent anywhere the callback is tied to
    /// the flow that produced it: the single-use `state`, the redirect URI, the
    /// `iss` parameter (RFC 9207, always required by the atproto profile) and
    /// the flow's DPoP key. After the exchange the token response is verified —
    /// `DPoP` token type, `atproto` scope, and the `sub` DID against the account
    /// the flow was started for or, for a server-first flow, against the
    /// authorization server through the account's own DID document. Tokens that
    /// fail verification are revoked rather than stored.
    func completeAuthorizationFlow(callbackURL url: URL) async throws -> (did: String, handle: String?, pdsURL: URL) {
        await emitProgress(.exchangingTokens)

        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func parameter(_ name: String) -> String? {
            query.first(where: { $0.name == name })?.value
        }

        // The authorization server reported an error instead of a code.
        if let error = parameter("error") {
            if let stateToken = parameter("state") {
                deniedStateTokens.insert(stateToken)
                _ = try? await storage.consumeOAuthState(stateToken)
                _ = try? await storage.deleteOAuthState(for: stateToken)
                inFlightOAuthStateTokens.remove(stateToken)
            }
            if error == "access_denied" {
                throw AuthError.cancelled
            }
            throw AuthError.serverError(0, [error, parameter("error_description")].compactMap { $0 }.joined(separator: ": "))
        }

        guard let code = parameter("code"), let stateToken = parameter("state") else {
            throw AuthError.invalidCallbackURL
        }
        if deniedStateTokens.contains(stateToken) {
            throw AuthError.invalidCallbackURL
        }

        // Consume the state before any other check or network call: it is
        // single-use, so a replayed or forged callback can never reach the token
        // endpoint twice.
        let oauthState: OAuthState
        do {
            oauthState = try await storage.consumeOAuthState(stateToken)
            inFlightOAuthStateTokens.remove(stateToken)
        } catch {
            throw AuthError.invalidCallbackURL
        }

        // Fail closed unless the whole trust tuple recorded at flow start is present.
        guard let expectedIssuer = oauthState.expectedIssuer,
              (try? OAuthOrigin.requireCanonical(expectedIssuer)) != nil,
              let expectedJKT = oauthState.dpopJKT,
              let persistedRedirectURI = oauthState.redirectURI,
              let expectedPDSOrigin = oauthState.expectedPDSOrigin,
              let expectedPDSOriginURL = URL(string: expectedPDSOrigin),
              expectedPDSOriginURL.scheme != nil, expectedPDSOriginURL.host != nil,
              let flowKey = oauthState.ephemeralDPoPKey
        else {
            throw AuthError.invalidCallbackURL
        }
        if oauthState.initialIdentifier != nil, oauthState.expectedDID == nil {
            throw AuthError.invalidCallbackURL
        }

        guard Self.matchesRedirectURI(callbackURL: url, expectedRedirectURI: persistedRedirectURI) else {
            throw AuthError.invalidCallbackURL
        }

        // RFC 9207 mix-up defence. Validated server metadata guarantees
        // `authorization_response_iss_parameter_supported`, so `iss` is never optional.
        guard let callbackIssuer = parameter("iss"), callbackIssuer == expectedIssuer else {
            throw AuthError.invalidCallbackURL
        }

        let thumbprint = try calculateJWKThumbprint(
            jwk: createJWK(from: P256.Signing.PrivateKey(rawRepresentation: flowKey))
        )
        guard thumbprint == expectedJKT else {
            throw AuthError.dpopKeyError
        }

        // The authorization server metadata validated when the flow started is
        // the only source of the token endpoint. A state without it (written by an
        // older version, or tampered with) fails closed: nothing is rediscovered
        // at callback time, and the stored document is validated again.
        guard let metadata = oauthState.authorizationServerMetadata,
              (try? metadata.validate(fetchedFrom: expectedIssuer, clientAuthentication: clientAuthenticator.method)) != nil
        else {
            throw AuthError.invalidCallbackURL
        }

        let tokenResponse = try await exchangeAuthorizationCode(
            code,
            codeVerifier: oauthState.codeVerifier,
            redirectURI: persistedRedirectURI,
            metadata: metadata,
            flowKey: flowKey,
            initialNonce: oauthState.parResponseNonce
        )

        // From here on the server holds a live session for this client. Any
        // verification failure revokes it instead of leaving it dangling.
        let did: String
        let handle: String
        let actualPDS: URL
        do {
            (did, handle, actualPDS) = try await verifyTokenResponse(
                tokenResponse,
                oauthState: oauthState,
                expectedIssuer: expectedIssuer,
                expectedPDSOriginURL: expectedPDSOriginURL
            )
        } catch {
            await revokeToken(
                tokenResponse.refreshToken ?? tokenResponse.accessToken,
                metadata: metadata,
                key: .flow(flowKey)
            )
            throw error
        }

        // Bind the flow's key to the account and invalidate any prior cached key.
        let x963 = try P256.Signing.PrivateKey(rawRepresentation: flowKey).x963Representation
        try await storage.saveDPoPKeyRepresentation(x963, for: did)
        clearDPoPKeyCache(for: did)

        // The flow's key is now this DID's DPoP key, so the nonces learned during
        // PAR and token exchange stay valid for it.
        await transferOAuthFlowNonces(to: did)

        let session = Session(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            createdAt: Date(),
            expiresIn: tokenResponse.effectiveExpiresIn,
            tokenType: .dpop,
            did: did,
            grantedScopes: tokenResponse.grantedScopes
        )
        let account = Account(
            did: did,
            handle: handle,
            pdsURL: actualPDS,
            protectedResourceMetadata: nil,
            authorizationServerMetadata: metadata,
            bskyAppViewDID: oauthState.bskyAppViewDID ?? "",
            bskyChatDID: oauthState.bskyChatDID ?? ""
        )

        try await storage.saveAccountAndSession(account, session: session, for: did)
        try await accountManager.updateAccountFromStorage(did: did)
        try await accountManager.setCurrentAccount(did: did)
        await networkService.setBaseURL(actualPDS)

        return (did: did, handle: account.handle, pdsURL: actualPDS)
    }

    /// Verifies that the account named by a token response is the one the flow
    /// may sign in ("it is critical … to verify that the account identified by
    /// the `sub` field is consistent with the Authorization Server").
    private func verifyTokenResponse(
        _ tokenResponse: TokenResponse,
        oauthState: OAuthState,
        expectedIssuer: String,
        expectedPDSOriginURL: URL
    ) async throws -> (did: String, handle: String, pdsURL: URL) {
        guard let did = tokenResponse.sub, did.hasPrefix("did:") else {
            throw AuthError.invalidResponse
        }
        guard tokenResponse.tokenType.lowercased() == "dpop" else {
            throw AuthError.invalidResponse
        }
        if let expectedDID = oauthState.expectedDID, did != expectedDID {
            throw AuthError.invalidResponse
        }

        // Resolve the account independently of anything the authorization server said.
        let (handle, actualPDS) = try await didResolver.resolveDIDToHandleAndPDSURL(did: did)

        let startedWithIdentifier = oauthState.initialIdentifier != nil
        if startedWithIdentifier {
            // The account → PDS → authorization server linkage was verified at
            // flow start; the PDS must still be the one that linkage was built on.
            guard let actualOrigin = OAuthOrigin.canonical(of: actualPDS),
                  actualOrigin == OAuthOrigin.canonical(of: expectedPDSOriginURL)
            else {
                throw AuthError.invalidOAuthConfiguration
            }
        }

        // A server-first flow has no account bound to it: the `sub` cannot be
        // trusted until its own PDS, found through its DID document, names the
        // authorization server that issued the tokens. `resolveAuthorizationServer`
        // re-fetches and validates both metadata documents.
        if !startedWithIdentifier || oauthConfig.enforcePDSAuthorizationBinding {
            let boundServer = try await resolveAuthorizationServer(forPDS: actualPDS)
            guard boundServer.issuer == expectedIssuer else {
                throw AuthError.invalidOAuthConfiguration
            }
        }

        return (did, handle, actualPDS)
    }

    /// Whether `callbackURL` is a redirect to `expectedRedirectURI`: same scheme
    /// and host (case-insensitive), port and path.
    static func matchesRedirectURI(callbackURL: URL, expectedRedirectURI: String) -> Bool {
        guard let expectedURL = URL(string: expectedRedirectURI),
              let callback = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let expected = URLComponents(url: expectedURL, resolvingAgainstBaseURL: false),
              let callbackScheme = callback.scheme?.lowercased(),
              callbackScheme == expected.scheme?.lowercased(),
              callback.host?.lowercased() == expected.host?.lowercased(),
              callback.port == expected.port
        else {
            return false
        }
        let callbackPath = callback.path.isEmpty ? "/" : callback.path
        let expectedPath = expected.path.isEmpty ? "/" : expected.path
        return callbackPath == expectedPath
    }

    /// Cancels every flow that has been started and not completed. Their
    /// callbacks, should they still arrive, are refused.
    func cancelAuthorizationFlows() async {
        cancellationGeneration &+= 1
        oauthStartTasks.values.forEach { $0.cancel() }
        oauthStartTasks.removeAll()
        for token in inFlightOAuthStateTokens {
            deniedStateTokens.insert(token)
            do {
                try await storage.deleteOAuthState(for: token)
            } catch {
                LogManager.logWarning("Failed to delete OAuth state: \(error.localizedDescription)")
            }
        }
        inFlightOAuthStateTokens.removeAll()
    }

    // MARK: - Refresh

    /// Performs one refresh-token grant for `account` and stores the result.
    ///
    /// Called with the refresh lock held (see `refreshTokenIfNeeded`), so a
    /// single-use refresh token is presented by exactly one request at a time.
    func performRefresh(for account: Account, session: Session) async throws -> TokenRefreshResult {
        let did = account.did
        guard let refreshToken = session.refreshToken else {
            throw AuthError.tokenRefreshFailed
        }

        var account = account
        let metadata: AuthorizationServerMetadata
        if let stored = account.authorizationServerMetadata {
            metadata = stored
        } else if let stored = await accountManager.getAccount(did: did)?.authorizationServerMetadata {
            metadata = stored
            account.authorizationServerMetadata = stored
        } else {
            // An account stored without server metadata: recover it through the
            // account's PDS rather than leaving the session unrefreshable.
            do {
                metadata = try await resolveAuthorizationServer(forPDS: account.pdsURL)
            } catch {
                await refreshCircuitBreaker.recordFailure(for: did, kind: .metadataUnavailable)
                throw error
            }
            account.authorizationServerMetadata = metadata
        }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await requestTokenRefresh(did: did, refreshToken: refreshToken, metadata: metadata)
        } catch let error as NetworkError {
            // Transport never reached a definitive answer: the refresh token may still be valid.
            await refreshCircuitBreaker.recordFailure(for: did, kind: .network)
            throw AuthError.networkError(error)
        }

        if (200 ..< 300).contains(response.statusCode) {
            // The server has rotated the refresh token. Whatever happens next, the
            // old one is spent.
            guard let tokenResponse = try? JSONCoders.decode(TokenResponse.self, from: data) else {
                await refreshCircuitBreaker.recordFailure(for: did, kind: .invalidGrant)
                throw AuthError.invalidResponse
            }
            // The refreshed tokens must still be this account's DPoP-bound tokens.
            guard tokenResponse.sub == did,
                  session.tokenType != .dpop || tokenResponse.tokenType.lowercased() == "dpop"
            else {
                LogManager.logError(
                    "Refresh response for DID \(LogManager.logDID(did)) failed verification (subject or token type); revoking it",
                    category: .authentication
                )
                await revokeToken(
                    tokenResponse.refreshToken ?? tokenResponse.accessToken,
                    metadata: metadata,
                    key: .account(did)
                )
                await refreshCircuitBreaker.recordFailure(for: did, kind: .invalidGrant)
                throw AuthError.invalidResponse
            }

            // RFC 6749 §6: a server that issues no new refresh token leaves the old one valid.
            let nextRefreshToken = tokenResponse.refreshToken ?? refreshToken
            if nextRefreshToken == refreshToken {
                usedRefreshTokens.remove(refreshToken)
            }
            let newSession = Session(
                accessToken: tokenResponse.accessToken,
                refreshToken: nextRefreshToken,
                createdAt: Date(),
                expiresIn: tokenResponse.effectiveExpiresIn,
                tokenType: session.tokenType,
                did: did,
                // Refresh responses restate the grant; the server may have reduced it.
                grantedScopes: tokenResponse.grantedScopes
            )
            // Persistence failures are handled inside (retry, pending key,
            // in-memory copy) and must not fail the refresh.
            await persistRefreshedSession(newSession, for: account)
            await refreshCircuitBreaker.recordSuccess(for: did)
            return .refreshedSuccessfully
        }

        // A definitive rejection (token consumed or revoked — never retry it)
        // versus transient server trouble (safe to retry with the same token).
        if response.statusCode == 400 || response.statusCode == 401,
           let errorResponse = try? JSONCoders.decode(OAuthErrorResponse.self, from: data),
           errorResponse.error == "invalid_grant"
        {
            LogManager.logError(
                "Token refresh definitively rejected (invalid_grant) for DID: \(LogManager.logDID(did))"
            )
            await refreshCircuitBreaker.recordFailure(for: did, kind: .invalidGrant)
            throw AuthError.invalidCredentials
        }

        let kind: RefreshCircuitBreaker.RefreshFailureKind = (500 ..< 600).contains(response.statusCode) ? .server : .other
        await refreshCircuitBreaker.recordFailure(for: did, kind: kind)
        throw AuthError.tokenRefreshFailed
    }

    // MARK: - Revocation and Logout

    /// Revokes `did`'s session at its authorization server, leaving local state untouched.
    /// - Returns: `true` only when the server confirmed the revocation.
    @discardableResult
    func revokeSession(for did: String) async -> Bool {
        let session: Session?
        do {
            session = try await storage.getSession(for: did)
        } catch {
            // A read failure leaves the refresh token valid server-side, which is
            // materially different from having no session at all.
            LogManager.logError(
                "Could not read the session for DID \(LogManager.logDID(did)) (\(error)); skipping server-side revocation. The refresh token may remain valid."
            )
            return false
        }
        guard let session else {
            LogManager.logInfo("No stored session for DID \(LogManager.logDID(did)); nothing to revoke")
            return false
        }
        guard session.tokenType == .dpop else { return false }

        var metadata = await accountManager.getAccount(did: did)?.authorizationServerMetadata
        if metadata == nil {
            metadata = (try? await storage.getAccount(for: did))?.authorizationServerMetadata
        }
        guard let metadata else {
            LogManager.logError(
                "No authorization server metadata stored for DID \(LogManager.logDID(did)); cannot revoke its session"
            )
            return false
        }

        // Revoking the refresh token ends the whole session at the authorization server.
        return await revokeToken(
            session.refreshToken ?? session.accessToken,
            metadata: metadata,
            key: .account(did)
        )
    }

    /// Logs the current account out: revokes its session at the authorization
    /// server, then deletes its tokens, DPoP key and nonces locally. Local state
    /// is removed even when revocation fails, so logout works offline.
    func logoutCurrentAccount() async throws {
        guard let did = await accountManager.getCurrentAccount()?.did else { return }

        await revokeSession(for: did)

        try await storage.deleteSession(for: did)
        try await storage.deleteDPoPKey(for: did)
        clearDPoPKeyCache(for: did)
        // Every store `createDPoPProof` reads, or the next login inherits nonces
        // bound to the DPoP key just deleted. Scoped to this DID, so a second
        // signed-in account keeps its cached nonces.
        try await storage.saveDPoPNonces([:], for: did)
        try await storage.saveDPoPNoncesByJKT([:], for: did)
        clearNonceCache(for: did)

        await accountManager.clearCurrentAccount()
    }

    // MARK: - Unauthorized Responses

    /// Answers a 401 from a resource server by refreshing and replaying the request once.
    func handleUnauthorizedResponse(
        _ response: HTTPURLResponse,
        data: Data,
        for request: URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        guard response.statusCode == 401 else { return (data, response) }

        switch try await refreshTokenIfNeeded(forceRefresh: true) {
        case .refreshedSuccessfully:
            let (newRequest, _) = try await prepareAuthenticatedRequestWithContext(request)
            let result = try await networkService.request(newRequest)
            guard let http = result.1 as? HTTPURLResponse else { throw AuthError.invalidResponse }
            return (result.0, http)
        default:
            throw AuthError.tokenRefreshFailed
        }
    }

    func attemptRecoveryFromServerFailures(for did: String?) async throws {
        var targetDID = did
        if targetDID == nil {
            targetDID = await accountManager.getCurrentAccount()?.did
        }
        guard let targetDID else { return }
        await refreshCircuitBreaker.reset(for: targetDID)
        _ = try await refreshTokenIfNeeded(forceRefresh: true)
    }
}
