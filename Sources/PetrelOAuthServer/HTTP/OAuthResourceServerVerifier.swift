import Foundation
import PetrelCrypto

/// What a verified access token authorizes: who, through which client, and for
/// what.
public struct OAuthAccessGrant: Sendable, Equatable {
    /// The account DID (`sub`).
    public let subject: String
    /// The client the token was issued to.
    public let clientID: String
    /// The effective grant, ready to answer "may this token do X".
    public let permissions: ScopePermissions
    /// The thumbprint of the DPoP key the token is bound to (`cnf.jkt`).
    public let dpopJKT: String
    /// When the access token expires.
    public let expiresAt: Date
    /// The session the token belongs to, when the verifier can see sessions.
    public let sessionID: UUID?
}

/// Why a resource request was not authorized, in the terms RFC 6750 §3 and
/// RFC 9449 §7 use for the `WWW-Authenticate` challenge.
public enum OAuthResourceAuthorizationFailure: Error, Sendable, Equatable {
    /// No `Authorization` header, or one that is not `DPoP <token>`.
    case missingToken
    /// The DPoP proof lacked a current server nonce. Retry with the nonce
    /// from the `DPoP-Nonce` header.
    case useDPoPNonce
    /// The DPoP proof is missing or invalid.
    case invalidDPoPProof(String)
    /// The token is unknown, expired, revoked, or not bound to the proof's
    /// key.
    case invalidToken(String)
    /// The token is valid but does not carry the scope the request needs.
    case insufficientScope(needed: String)
    /// A dependency could not answer.
    case unavailable
}

/// Verifies access tokens on a resource server (a PDS): the `Authorization:
/// DPoP` token, the DPoP proof with its `ath`, the binding between them, and
/// then scopes.
///
/// Two modes:
///
/// - ``init(authorizationServer:)`` shares the authorization server's session
///   store. It accepts both token formats and sees revocation immediately.
/// - ``init(issuer:resource:keys:secret:replayStore:nonceService:clock:)``
///   verifies signed (`at+jwt`) access tokens with the authorization server's
///   public keys alone, for a resource server deployed separately. It cannot
///   see revocation, which is why the profile caps such tokens' lifetime.
public struct OAuthResourceServerVerifier: Sendable {
    private enum Mode: Sendable {
        case shared(store: any OAuthSessionStore, digest: OAuthKeyedDigest, keys: [OAuthJSONWebKey])
        case stateless(keys: [OAuthJSONWebKey])
    }

    private let mode: Mode
    private let issuer: String
    private let resource: String
    private let dpopValidator: OAuthDPoPProofValidator
    private let nonceService: OAuthDPoPNonceService
    private let clock: any OAuthClock

    /// A verifier for a resource server that shares the authorization
    /// server's stores, secret and nonces.
    public init(authorizationServer server: OAuthAuthorizationServer) {
        var keys: [OAuthJSONWebKey] = []
        if case let .signedJWT(key) = server.configuration.accessTokenFormat, let jwk = try? key.publicJWK {
            keys = [jwk]
        }
        mode = .shared(store: server.store, digest: server.digest, keys: keys)
        issuer = server.issuer
        resource = Self.trimmed(server.configuration.resource)
        dpopValidator = server.dpopValidator
        nonceService = server.nonceService
        clock = server.clock
    }

    /// A verifier for a resource server that holds only the authorization
    /// server's public keys.
    ///
    /// - Parameters:
    ///   - issuer: the authorization server's issuer identifier.
    ///   - resource: this resource server's URL, the expected token audience.
    ///   - keys: the authorization server's published keys (`/oauth/jwks`).
    ///   - secret: at least 32 bytes, for this server's own DPoP nonces and
    ///     replay digests.
    ///   - replayStore: where DPoP `jti` values are reserved.
    ///   - nonceService: DPoP nonces; by default derived from `secret`.
    ///   - clock: the time source.
    public init(
        issuer: URL,
        resource: URL,
        keys: OAuthJSONWebKeySet,
        secret: Data,
        replayStore: any OAuthReplayStore,
        nonceService: OAuthDPoPNonceService? = nil,
        clock: any OAuthClock = SystemOAuthClock()
    ) throws {
        let nonces = try nonceService ?? OAuthDPoPNonceService(secret: secret)
        mode = .stateless(keys: keys.keys)
        self.issuer = Self.trimmed(issuer)
        self.resource = Self.trimmed(resource)
        dpopValidator = try OAuthDPoPProofValidator(secret: secret, nonceService: nonces, replayStore: replayStore)
        self.nonceService = nonces
        self.clock = clock
    }

    /// The nonce to send in a `DPoP-Nonce` header on every response, including
    /// successful ones, so clients always hold a current value.
    public func currentNonce() -> String {
        nonceService.current(now: clock.now())
    }

    /// Authenticates one resource request.
    ///
    /// - Parameters:
    ///   - method: the request's HTTP method.
    ///   - url: the request URL as the client addressed it (the resource
    ///     server's public origin plus the request path). The proof's `htu`
    ///     must match it, ignoring query and fragment.
    ///   - headers: the request headers.
    /// - Returns: the grant the token carries. Check it with
    ///   ``OAuthAccessGrant/permissions`` before serving the request.
    public func authenticate(
        method: String,
        url: URL,
        headers: OAuthHTTPHeaders
    ) async throws(OAuthResourceAuthorizationFailure) -> OAuthAccessGrant {
        let now = clock.now()
        guard let authorization = headers.single("Authorization") else { throw .missingToken }
        let parts = authorization.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2, parts[0].lowercased() == "dpop" else {
            // A Bearer token is never acceptable: every token is DPoP-bound.
            throw parts.first?.lowercased() == "bearer"
                ? .invalidToken("access tokens must be presented with the DPoP scheme")
                : .missingToken
        }
        let token = String(parts[1])
        guard Self.isToken68(token) else { throw .invalidToken("access token is malformed") }
        let proofs = headers.values(for: "DPoP")
        guard proofs.count == 1 else {
            throw .invalidDPoPProof(proofs.isEmpty ? "a DPoP proof is required" : "exactly one DPoP header is allowed")
        }
        let proof: OAuthValidatedDPoPProof
        do {
            proof = try await dpopValidator.validate(
                proofs[0], method: method, target: url, accessToken: token, now: now
            )
        } catch .useNonce {
            throw .useDPoPNonce
        } catch let .invalidProof(reason) {
            throw .invalidDPoPProof(reason)
        } catch {
            throw .unavailable
        }

        let grant = try await grant(for: token, now: now)
        guard ConstantTime.equal(grant.dpopJKT, proof.keyThumbprint) else {
            throw .invalidToken("access token is bound to a different DPoP key")
        }
        guard grant.permissions.hasBaseATProtocolScope else {
            throw .insufficientScope(needed: "atproto")
        }
        return grant
    }

    private func grant(for token: String, now: Date) async throws(OAuthResourceAuthorizationFailure) -> OAuthAccessGrant {
        switch mode {
        case let .shared(store, digest, keys):
            let session: OAuthSession?
            do {
                session = try await store.session(
                    accessTokenDigest: digest.digest(token, purpose: .accessToken), now: now
                )
            } catch {
                throw .unavailable
            }
            guard let session, let tokens = session.tokens else {
                throw .invalidToken("access token is invalid, expired or revoked")
            }
            // A signed token is verified as well, so a store bug cannot turn a
            // forged token into a session lookup.
            if !keys.isEmpty, token.contains(".") {
                _ = try verifySigned(token, keys: keys, now: now)
            }
            return OAuthAccessGrant(
                subject: session.subject,
                clientID: session.binding.clientID,
                permissions: ScopePermissions(rawScopes: session.binding.grantedScopes),
                dpopJKT: session.binding.dpopJKT,
                expiresAt: tokens.accessExpiresAt,
                sessionID: session.sessionID
            )
        case let .stateless(keys):
            let claims = try verifySigned(token, keys: keys, now: now)
            return OAuthAccessGrant(
                subject: claims.sub,
                clientID: claims.clientID,
                permissions: ScopePermissions(scope: claims.scope),
                dpopJKT: claims.cnf.jkt,
                expiresAt: Date(timeIntervalSince1970: TimeInterval(claims.exp)),
                sessionID: nil
            )
        }
    }

    private func verifySigned(
        _ token: String,
        keys: [OAuthJSONWebKey],
        now: Date
    ) throws(OAuthResourceAuthorizationFailure) -> OAuthAccessTokenClaims {
        do {
            let header = try OAuthCompactJWT.unverifiedHeader(token)
            let candidates = keys.filter { header.keyID == nil || $0.keyID == header.keyID }
            guard candidates.count == 1, let key = candidates.first else {
                throw OAuthServerError.unauthorized("access token key is unknown")
            }
            let verified = try OAuthCompactJWT.verify(
                token,
                key: key,
                expectedType: OAuthAccessTokenType.jwtType,
                // The authorization server signs low-S; nothing else is ours.
                signatureEncoding: .canonicalLowS,
                constraints: .init(
                    expectedIssuer: issuer,
                    expectedAudience: resource,
                    now: now,
                    clockSkew: 30,
                    requireIssuedAt: true,
                    requireExpiration: true,
                    maxLifetime: 30 * 60
                )
            )
            let claims = try OAuthCompactJWT.decodeClaims(OAuthAccessTokenClaims.self, from: verified)
            guard claims.sub.hasPrefix("did:"), !claims.cnf.jkt.isEmpty else {
                throw OAuthServerError.unauthorized("access token claims are invalid")
            }
            return claims
        } catch {
            throw .invalidToken("access token is invalid, expired or revoked")
        }
    }

    /// The response for a failed authentication or scope check: `401` (or
    /// `403` for a scope failure) with the `WWW-Authenticate: DPoP` challenge
    /// and a fresh `DPoP-Nonce`.
    public func challenge(for failure: OAuthResourceAuthorizationFailure) -> OAuthHTTPResponse {
        struct Body: Encodable {
            let error: String
            let message: String
        }
        let status: Int
        let code: String?
        let description: String
        switch failure {
        case .missingToken:
            (status, code, description) = (401, nil, "authentication required")
        case .useDPoPNonce:
            (status, code, description) = (401, "use_dpop_nonce", "retry with the nonce from the DPoP-Nonce header")
        case let .invalidDPoPProof(reason):
            (status, code, description) = (401, "invalid_dpop_proof", reason)
        case let .invalidToken(reason):
            (status, code, description) = (401, "invalid_token", reason)
        case let .insufficientScope(needed):
            (status, code, description) = (403, "insufficient_scope", "missing scope: \(needed)")
        case .unavailable:
            (status, code, description) = (503, nil, "the server cannot answer right now")
        }
        var headers = OAuthHTTPHeaders([
            ("Content-Type", "application/json"),
            ("Cache-Control", "no-store"),
            ("DPoP-Nonce", currentNonce()),
            ("Access-Control-Expose-Headers", "DPoP-Nonce, WWW-Authenticate"),
        ])
        if status != 503 {
            var challenge = "DPoP algs=\"\(OAuthJWSAlgorithm.allCases.map(\.rawValue).joined(separator: " "))\""
            if let code {
                challenge += ", error=\"\(code)\", error_description=\"\(Self.quoted(description))\""
            }
            headers.set("WWW-Authenticate", challenge)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let body = (try? encoder.encode(Body(error: code ?? "AuthenticationRequired", message: description))) ?? Data()
        return OAuthHTTPResponse(status: status, headers: headers, body: body)
    }

    private static func quoted(_ text: String) -> String {
        String(text.unicodeScalars.filter { $0.value >= 0x20 && $0.value < 0x7F && $0 != "\"" && $0 != "\\" })
    }

    private static func isToken68(_ token: String) -> Bool {
        !token.isEmpty && token.utf8.count <= 8192 && token.utf8.allSatisfy { byte in
            (0x30 ... 0x39).contains(byte) || (0x41 ... 0x5A).contains(byte) || (0x61 ... 0x7A).contains(byte)
                || byte == 0x2D || byte == 0x2E || byte == 0x5F || byte == 0x7E || byte == 0x2B || byte == 0x2F
                || byte == 0x3D
        }
    }

    private static func trimmed(_ url: URL) -> String {
        let text = url.absoluteString
        return text.hasSuffix("/") ? String(text.dropLast()) : text
    }
}

public extension OAuthAccessGrant {
    /// Throws ``OAuthResourceAuthorizationFailure/insufficientScope(needed:)``
    /// unless the grant allows writing `collection` with `action`.
    func requireRepo(collection: String, action: RepoAction) throws(OAuthResourceAuthorizationFailure) {
        let target = RepoPermission.Target(collection: collection, action: action)
        guard permissions.allowsRepo(target) else {
            throw .insufficientScope(needed: (try? RepoPermission.scopeNeeded(for: target)) ?? "repo")
        }
    }

    /// Throws unless the grant allows calling `lxm` on the service `aud`.
    func requireRPC(lxm: String, aud: String) throws(OAuthResourceAuthorizationFailure) {
        let target = RpcPermission.Target(lxm: lxm, aud: aud)
        guard permissions.allowsRPC(target) else {
            throw .insufficientScope(needed: (try? RpcPermission.scopeNeeded(for: target)) ?? "rpc")
        }
    }

    /// Throws unless the grant allows uploading a blob of type `mime`.
    func requireBlob(mime: String) throws(OAuthResourceAuthorizationFailure) {
        let target = BlobPermission.Target(mime: mime)
        guard permissions.allowsBlob(target) else {
            throw .insufficientScope(needed: (try? BlobPermission.scopeNeeded(for: target)) ?? "blob")
        }
    }

    /// Throws unless the grant allows `action` on the account attribute `attr`.
    func requireAccount(attr: AccountAttribute, action: AccountAction) throws(OAuthResourceAuthorizationFailure) {
        let target = AccountPermission.Target(attr: attr, action: action)
        guard permissions.allowsAccount(target) else {
            throw .insufficientScope(needed: (try? AccountPermission.scopeNeeded(for: target)) ?? "account")
        }
    }

    /// Throws unless the grant allows changing the identity attribute `attr`.
    func requireIdentity(attr: IdentityAttribute) throws(OAuthResourceAuthorizationFailure) {
        let target = IdentityPermission.Target(attr: attr)
        guard permissions.allowsIdentity(target) else {
            throw .insufficientScope(needed: (try? IdentityPermission.scopeNeeded(for: target)) ?? "identity")
        }
    }
}
