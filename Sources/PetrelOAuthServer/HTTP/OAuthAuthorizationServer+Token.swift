import Foundation
import PetrelCrypto

extension OAuthAuthorizationServer {
    /// `POST /oauth/token`: the `authorization_code` and `refresh_token`
    /// grants. Every other grant type is refused.
    func handleToken(_ request: OAuthHTTPRequest) async -> OAuthHTTPResponse {
        let now = clock.now()
        do {
            let fields = try form(request)
            guard let grantType = fields["grant_type"] else {
                throw EndpointError.invalidRequest("grant_type is required")
            }
            guard grantType == "authorization_code" || grantType == "refresh_token" else {
                throw EndpointError(
                    status: 400, code: "unsupported_grant_type",
                    description: "only authorization_code and refresh_token are supported"
                )
            }
            // DPoP first, so a nonce challenge never consumes the single-use
            // client assertion the client is about to resend.
            let proof = try await requireDPoP(request, path: Path.token, now: now)
            // A confidential client's keys are fetched afresh on refresh, so a
            // key removed from its JWKS stops working within one request.
            let (client, clientKey) = try await authenticateClient(
                fields, revalidate: grantType == "refresh_token" && fields["client_assertion"] != nil, now: now
            )
            let body: OAuthTokenResponse = switch grantType {
            case "authorization_code":
                try await exchangeCode(fields, client: client, clientKey: clientKey, proof: proof, now: now)
            default:
                try await refresh(fields, client: client, clientKey: clientKey, proof: proof, now: now)
            }
            return json(200, body)
        } catch let error as EndpointError {
            return response(for: error)
        } catch {
            return response(for: .serverError)
        }
    }

    private func exchangeCode(
        _ fields: [String: String],
        client: OAuthResolvedClientMetadata,
        clientKey: OAuthClientKeyBinding?,
        proof: OAuthValidatedDPoPProof,
        now: Date
    ) async throws(EndpointError) -> OAuthTokenResponse {
        guard let code = fields["code"], code.utf8.count == 43 else {
            throw .invalidRequest("code is required")
        }
        guard let verifier = fields["code_verifier"], OAuthPKCE.isValidVerifier(verifier) else {
            throw .invalidRequest("code_verifier is required and must be 43 to 128 unreserved characters")
        }
        guard let redirectURI = fields["redirect_uri"] else {
            throw .invalidRequest("redirect_uri is required")
        }
        let codeDigest = digest.digest(code, purpose: .authorizationCode)
        let clientID = client.metadata.clientID.absoluteString

        let record: OAuthAuthorizationCode?
        do {
            record = try await store.authorizationCode(codeDigest: codeDigest, now: now)
        } catch {
            throw .unavailable
        }
        guard let record else { throw .invalidGrant("authorization code is invalid") }
        guard try await isUsable(subject: record.subject) else {
            try? await store.revokeSession(id: record.sessionID, now: now)
            throw .invalidGrant("authorization code is invalid")
        }
        let isConfidential = record.binding.clientKey != nil
        let sessionExpiresAt = try await sessionEnd(record.sessionID, now: now)
        let minted = try mint(
            sessionID: record.sessionID,
            subject: record.subject,
            binding: record.binding,
            isConfidential: isConfidential,
            sessionExpiresAt: sessionExpiresAt,
            now: now
        )
        do {
            _ = try await store.redeemAuthorizationCode(
                codeDigest: codeDigest,
                verifying: { stored in
                    // Every binding fixed at the pushed request must be
                    // presented again, unchanged, to redeem the code.
                    guard stored.binding.clientID == clientID,
                          ConstantTime.equal(stored.binding.redirectURI, redirectURI),
                          ConstantTime.equal(stored.binding.dpopJKT, proof.keyThumbprint),
                          stored.binding.clientKey == clientKey,
                          OAuthPKCE.verifyS256(verifier: verifier, challenge: stored.codeChallenge)
                    else {
                        throw OAuthStoreError.notFound
                    }
                },
                issuing: minted.digests,
                now: now
            )
        } catch let error as OAuthStoreError {
            switch error {
            case .replayed:
                throw .invalidGrant("authorization code was already used; the session has been revoked")
            case .notFound, .revoked, .duplicate:
                throw .invalidGrant("authorization code is invalid")
            }
        } catch {
            throw .unavailable
        }
        return minted.response
    }

    private func refresh(
        _ fields: [String: String],
        client: OAuthResolvedClientMetadata,
        clientKey: OAuthClientKeyBinding?,
        proof: OAuthValidatedDPoPProof,
        now: Date
    ) async throws(EndpointError) -> OAuthTokenResponse {
        guard let refreshToken = fields["refresh_token"], refreshToken.utf8.count == 43 else {
            throw .invalidRequest("refresh_token is required")
        }
        guard client.metadata.grantTypes.contains("refresh_token") else {
            throw EndpointError(
                status: 400, code: "unauthorized_client",
                description: "the client did not declare the refresh_token grant"
            )
        }
        let refreshDigest = digest.digest(refreshToken, purpose: .refreshToken)
        let session: OAuthSession?
        do {
            session = try await store.session(refreshTokenDigest: refreshDigest, now: now)
        } catch {
            throw .unavailable
        }
        guard let session else { throw .invalidGrant("refresh token is invalid") }
        let binding = session.binding
        guard binding.clientID == client.metadata.clientID.absoluteString, binding.refreshTokenAllowed else {
            throw .invalidGrant("refresh token is invalid")
        }
        guard ConstantTime.equal(binding.dpopJKT, proof.keyThumbprint) else {
            throw .invalidGrant("refresh token is bound to a different DPoP key")
        }
        // A confidential client must present the same key and method it used
        // for the initial request. When that key has left the client's JWKS
        // the session cannot continue and is revoked.
        if let boundKey = binding.clientKey {
            let stillPublished = client.keySet?.keys.contains {
                $0.keyID == boundKey.keyID && $0.thumbprint() == boundKey.thumbprint
            } ?? false
            guard stillPublished else {
                try? await store.revokeSession(id: session.sessionID, now: now)
                throw .invalidGrant("the client key this session is bound to is no longer published")
            }
            guard clientKey == boundKey else {
                throw .invalidGrant("refresh must use the client key the session was created with")
            }
        } else {
            guard clientKey == nil else { throw .invalidGrant("refresh token is invalid") }
        }
        guard try await isUsable(subject: session.subject) else {
            try? await store.revokeSession(id: session.sessionID, now: now)
            throw .invalidGrant("refresh token is invalid")
        }

        // The effective grant is re-derived from what the client originally
        // requested, so a changed permission set takes effect on refresh.
        // An existing session is never broken by a permission set that has
        // stopped resolving: it keeps the grant it already has.
        let granted: Set<String>
        do {
            granted = try await effectiveGrant(for: binding.requestedScopes, stage: .tokenMint).scopes
        } catch is OAuthScopeResolutionError {
            granted = binding.grantedScopes
        } catch {
            throw .unavailable
        }
        let minted = try mint(
            sessionID: session.sessionID,
            subject: session.subject,
            binding: binding.withGrantedScopes(granted),
            isConfidential: binding.clientKey != nil,
            sessionExpiresAt: session.expiresAt,
            now: now
        )
        do {
            _ = try await store.rotateRefreshToken(
                refreshTokenDigest: refreshDigest,
                replacement: minted.digests,
                grantedScopes: granted == binding.grantedScopes ? nil : granted,
                now: now
            )
        } catch let error as OAuthStoreError {
            switch error {
            case .replayed:
                throw .invalidGrant("refresh token was already used; the session has been revoked")
            case .notFound, .revoked, .duplicate:
                throw .invalidGrant("refresh token is invalid")
            }
        } catch {
            throw .unavailable
        }
        return minted.response
    }

    /// `POST /oauth/revoke` (RFC 7009). Possession of a token is the authority
    /// to revoke the session it belongs to. An unknown token is a success, as
    /// the RFC requires, so the endpoint is not a token oracle.
    func handleRevoke(_ request: OAuthHTTPRequest) async -> OAuthHTTPResponse {
        struct Empty: Encodable {}
        let now = clock.now()
        do {
            let fields = try form(request)
            guard let token = fields["token"], !token.isEmpty, token.utf8.count <= 8192 else {
                throw EndpointError.invalidRequest("token is required")
            }
            do {
                var session = try await store.session(
                    refreshTokenDigest: digest.digest(token, purpose: .refreshToken), now: now
                )
                if session == nil {
                    session = try await store.session(
                        accessTokenDigest: digest.digest(token, purpose: .accessToken), now: now
                    )
                }
                if let session {
                    // When the caller names a client, it must be the session's.
                    if let clientID = fields["client_id"], clientID != session.binding.clientID {
                        return json(200, Empty())
                    }
                    try await store.revokeSession(id: session.sessionID, now: now)
                }
            } catch {
                throw EndpointError.unavailable
            }
            return json(200, Empty())
        } catch let error as EndpointError {
            return response(for: error)
        } catch {
            return response(for: .serverError)
        }
    }

    // MARK: - Minting

    struct MintedTokens {
        let response: OAuthTokenResponse
        let digests: OAuthIssuedTokenDigests
    }

    /// Creates the access token, and the refresh token when the client may
    /// have one, without persisting anything.
    func mint(
        sessionID _: UUID,
        subject: String,
        binding: OAuthGrantBinding,
        isConfidential: Bool,
        sessionExpiresAt: Date?,
        now: Date
    ) throws(EndpointError) -> MintedTokens {
        let ceiling = sessionExpiresAt ?? .distantFuture
        guard ceiling > now else { throw .invalidGrant("the session has ended") }
        let accessExpiresAt = min(now.addingTimeInterval(configuration.accessTokenLifetime), ceiling)
        let accessToken: String
        switch configuration.accessTokenFormat {
        case .opaque:
            accessToken = random.opaqueValue()
        case let .signedJWT(key):
            let resource = configuration.resource.absoluteString
            let claims = OAuthAccessTokenClaims(
                iss: issuer,
                aud: resource.hasSuffix("/") ? String(resource.dropLast()) : resource,
                sub: subject,
                clientID: binding.clientID,
                scope: binding.grantedScopes.sorted().joined(separator: " "),
                cnf: .init(jkt: binding.dpopJKT),
                iat: Int64(now.timeIntervalSince1970),
                exp: Int64(accessExpiresAt.timeIntervalSince1970),
                jti: random.opaqueValue()
            )
            do {
                accessToken = try OAuthCompactJWT.sign(claims, with: key, type: OAuthAccessTokenType.jwtType)
            } catch {
                throw .serverError
            }
        }
        var refreshToken: String?
        var refreshExpiresAt: Date?
        if binding.refreshTokenAllowed {
            let lifetime = isConfidential
                ? configuration.confidentialClientRefreshLifetime
                : configuration.publicClientRefreshLifetime
            refreshToken = random.opaqueValue()
            refreshExpiresAt = min(now.addingTimeInterval(lifetime), ceiling)
        }
        return MintedTokens(
            response: OAuthTokenResponse(
                accessToken: accessToken,
                tokenType: "DPoP",
                expiresIn: max(1, Int(accessExpiresAt.timeIntervalSince(now))),
                refreshToken: refreshToken,
                scope: binding.requestedScopes.sorted().joined(separator: " "),
                sub: subject
            ),
            digests: OAuthIssuedTokenDigests(
                accessTokenDigest: digest.digest(accessToken, purpose: .accessToken),
                accessExpiresAt: accessExpiresAt,
                refreshTokenDigest: refreshToken.map { digest.digest($0, purpose: .refreshToken) },
                refreshExpiresAt: refreshExpiresAt
            )
        )
    }

    private func isUsable(subject: String) async throws(EndpointError) -> Bool {
        do {
            return try await accounts.account(did: subject) != nil
        } catch {
            throw .unavailable
        }
    }

    private func sessionEnd(_ id: UUID, now: Date) async throws(EndpointError) -> Date? {
        do {
            guard let session = try await store.session(id: id, now: now), session.isActive(at: now) else {
                throw EndpointError.invalidGrant("authorization code is invalid")
            }
            return session.expiresAt
        } catch let error as EndpointError {
            throw error
        } catch {
            throw .unavailable
        }
    }
}
