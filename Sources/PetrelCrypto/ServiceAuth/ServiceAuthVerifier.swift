import Foundation

/// Authenticates incoming requests that carry an AT Protocol service-auth
/// JWT: `Authorization: Bearer <token>` in, verified caller out.
///
/// This is what a feed generator, labeler, AppView or any other service
/// runs on each authenticated request. It performs the whole procedure the
/// specification describes for a receiving service:
///
/// 1. reads the bearer token and decodes it strictly (duplicate-free JSON,
///    `ES256` / `ES256K` only, no `at+jwt` / `refresh+jwt` / `dpop+jwt`);
/// 2. checks `exp`, with a small clock skew, and refuses tokens that live
///    longer than the configured ceiling;
/// 3. checks that `aud` names this service and `lxm` names the endpoint;
/// 4. resolves the issuer's signing key through a ``ServiceAuthKeyResolver``
///    and verifies the signature, retrying once with a forced refresh so a
///    key rotation does not lock the issuer out;
/// 5. optionally records `jti` in a ``ServiceAuthReplayStore`` so a token
///    is accepted once.
///
/// ```swift
/// let verifier = ServiceAuthVerifier(
///     audience: .service(did: "did:web:feed.example.com", id: "bsky_fg", acceptBareDID: true),
///     keyResolver: resolver
/// )
///
/// // In the handler for app.bsky.feed.getFeedSkeleton:
/// let caller = try await verifier.verify(
///     authorizationHeader: request.headers["Authorization"],
///     method: .exactly("app.bsky.feed.getFeedSkeleton")
/// )
/// let viewerDID = caller.issuer
/// ```
///
/// Failures are ``ServiceAuthError`` values carrying the reference
/// implementation's XRPC error names.
public struct ServiceAuthVerifier: Sendable {
    /// What a verifier accepts.
    public struct Configuration: Sendable {
        /// Which `aud` values name this service.
        public var audience: ServiceAuthAudience

        /// The verification methods a token may be signed with, as DID
        /// document fragments with their `#`.
        ///
        /// The specification: "Receiving services must only accept
        /// specific key types (verification method identifiers), to
        /// maintain security separation between registered keys. This
        /// usually means accepting only `#atproto`." A token whose `kid`
        /// header names anything else is refused. Add `#atproto_label` to
        /// accept tokens a labeler signs with its labeling key; the
        /// ``ServiceAuthKeyResolver`` must then implement
        /// ``ServiceAuthKeyResolver/signingKey(for:keyID:forceRefresh:)``.
        public var acceptedKeyIDs: Set<String>

        /// Key selection for legacy tokens that put a service fragment in
        /// `iss` instead of a `kid` header: issuer fragment (without `#`)
        /// → key identifier (with `#`).
        ///
        /// Until Spring 2026 a labeler identified itself as
        /// `did:plc:…#atproto_labeler` and signed with its
        /// `#atproto_label` key; `["atproto_labeler": "#atproto_label"]`
        /// reproduces what the reference AppView does with such tokens. A
        /// mapped key is accepted for tokens carrying that fragment
        /// without being listed in ``acceptedKeyIDs``. Fragments with no
        /// entry do not change the key: the token must verify under its
        /// `kid`, or `#atproto`.
        public var issuerFragmentKeyIDs: [String: String]

        /// Seconds past `exp` a token is still accepted, to absorb clock
        /// differences between issuer and verifier. Values outside
        /// 0...300, or not finite, are treated as 0.
        public var clockSkew: TimeInterval

        /// The longest-lived token accepted, in seconds: `exp` may be at
        /// most this far in the future, and `exp - iat` at most this long.
        ///
        /// The default is one hour, the longest a reference PDS issues
        /// from `com.atproto.server.getServiceAuth` (the official app asks
        /// for 30 minutes when uploading video). Lower it for endpoints
        /// that should only see the usual 60 second tokens. A value that
        /// is not positive and finite refuses every token.
        public var maximumLifetime: TimeInterval

        /// Claims to insist on beyond what the reference verifier requires.
        public var requiredClaims: ServiceAuthRequiredClaims

        /// Which signature encodings are accepted. The default,
        /// ``ATProtoSignatureVerificationOptions/jwt``, is the JWS
        /// encoding with either S value, as the specification requires
        /// for service-auth tokens.
        public var signatureOptions: ATProtoSignatureVerificationOptions

        /// Creates a configuration.
        public init(
            audience: ServiceAuthAudience,
            acceptedKeyIDs: Set<String> = [ServiceJWT.defaultKeyID],
            issuerFragmentKeyIDs: [String: String] = [:],
            clockSkew: TimeInterval = ServiceJWT.defaultClockSkew,
            maximumLifetime: TimeInterval = ServiceJWT.defaultMaximumAcceptedLifetime,
            requiredClaims: ServiceAuthRequiredClaims = .reference,
            signatureOptions: ATProtoSignatureVerificationOptions = .jwt
        ) {
            self.audience = audience
            self.acceptedKeyIDs = acceptedKeyIDs
            self.issuerFragmentKeyIDs = issuerFragmentKeyIDs
            self.clockSkew = clockSkew
            self.maximumLifetime = maximumLifetime
            self.requiredClaims = requiredClaims
            self.signatureOptions = signatureOptions
        }
    }

    /// What this verifier accepts.
    public let configuration: Configuration
    private let keyResolver: any ServiceAuthKeyResolver
    private let replayStore: (any ServiceAuthReplayStore)?

    /// Creates a verifier.
    ///
    /// - Parameters:
    ///   - configuration: What to accept.
    ///   - keyResolver: Resolves an issuer DID to its signing key.
    ///   - replayStore: If set, each token's `jti` is recorded and a token
    ///     is accepted only once; tokens without a `jti` are refused.
    public init(
        configuration: Configuration,
        keyResolver: any ServiceAuthKeyResolver,
        replayStore: (any ServiceAuthReplayStore)? = nil
    ) {
        self.configuration = configuration
        self.keyResolver = keyResolver
        self.replayStore = replayStore
    }

    /// Creates a verifier with the default configuration for an audience.
    public init(
        audience: ServiceAuthAudience,
        keyResolver: any ServiceAuthKeyResolver,
        replayStore: (any ServiceAuthReplayStore)? = nil
    ) {
        self.init(
            configuration: Configuration(audience: audience),
            keyResolver: keyResolver,
            replayStore: replayStore
        )
    }

    // MARK: Authorization header

    /// Extracts the token from an `Authorization: Bearer <token>` header
    /// value. The scheme name is matched case-insensitively.
    ///
    /// - Throws: ``ServiceAuthError/missingAuthorization`` for `nil` or an
    ///   empty value; ``ServiceAuthError/unsupportedAuthorizationScheme``
    ///   for any other scheme or a token containing whitespace.
    public static func bearerToken(fromAuthorizationHeader header: String?) throws(ServiceAuthError) -> String {
        guard let header else { throw .missingAuthorization }
        let trimmed = header.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
        guard !trimmed.isEmpty else { throw .missingAuthorization }
        let scheme = "bearer "
        guard trimmed.count > scheme.count, trimmed.prefix(scheme.count).lowercased() == scheme else {
            throw .unsupportedAuthorizationScheme
        }
        let token = trimmed.dropFirst(scheme.count).trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
        guard !token.isEmpty, !token.utf8.contains(where: { $0 <= 0x20 || $0 >= 0x7F }) else {
            throw .unsupportedAuthorizationScheme
        }
        return token
    }

    // MARK: Verification

    /// Authenticates a request from its `Authorization` header.
    ///
    /// - Parameters:
    ///   - authorizationHeader: The header value, or `nil` if the request
    ///     has none.
    ///   - method: How to check `lxm`; normally `.exactly(nsid)` with the
    ///     NSID of the endpoint being served.
    ///   - now: The verifier's clock.
    /// - Returns: The verified caller and token bindings.
    public func verify(
        authorizationHeader: String?,
        method: ServiceAuthMethodPolicy,
        now: Date = Date()
    ) async throws(ServiceAuthError) -> VerifiedServiceAuth {
        try await verify(
            token: Self.bearerToken(fromAuthorizationHeader: authorizationHeader),
            method: method,
            now: now
        )
    }

    /// Verifies a bare service JWT.
    ///
    /// - Parameters:
    ///   - token: The compact JWT, without the `Bearer` prefix.
    ///   - method: How to check `lxm`; normally `.exactly(nsid)` with the
    ///     NSID of the endpoint being served.
    ///   - now: The verifier's clock.
    /// - Returns: The verified caller and token bindings.
    public func verify(
        token: String,
        method: ServiceAuthMethodPolicy,
        now: Date = Date()
    ) async throws(ServiceAuthError) -> VerifiedServiceAuth {
        let parsed = try Self.parse(token, allowDERSignature: configuration.signatureOptions.allowDER)
        let header = parsed.header
        let claims = parsed.claims

        // Checks run in the order the reference verifier uses, so the same
        // token is refused for the same reason by both.
        if header.crit != nil || header.b64 != nil {
            throw .malformedToken("unsupported critical header parameters")
        }
        if let type = header.typ, ServiceJWT.disallowedTypes.contains(type.lowercased()) {
            throw .disallowedTokenType(type)
        }
        try checkTimes(claims, now: now)
        guard configuration.audience.accepts(claims.aud) else {
            throw .audienceMismatch(actual: claims.aud)
        }
        try method.check(claims.lxm)
        guard let issuer = ServiceAuthSyntax.splitDIDReference(claims.iss) else {
            throw .invalidIssuer(claims.iss)
        }
        if let failure = ServiceJWT.shapeFailure(header, claims: claims) {
            throw failure
        }
        try checkRequiredClaims(header, claims: claims)

        guard ServiceJWT.allowedAlgorithms.contains(header.alg) else {
            throw .unsupportedAlgorithm(header.alg)
        }
        let keyID = try selectKeyID(header: header, issuerFragment: issuer.fragment)
        let signingKey = try await verifiedSigningKey(parsed, issuerDID: issuer.did, keyID: keyID)

        let expiresAt = Date(timeIntervalSince1970: TimeInterval(claims.exp))
        // Only a token that is authentic and otherwise acceptable reaches
        // the replay store, so forged input cannot fill it.
        if let replayStore, let nonce = claims.jti, !nonce.isEmpty {
            let firstUse: Bool
            do {
                firstUse = try await replayStore.claim(
                    nonce: nonce,
                    issuer: issuer.did,
                    expiresAt: replayRecordExpiry(exp: claims.exp)
                )
            } catch {
                throw .replayStoreFailed(String(describing: error))
            }
            guard firstUse else { throw .replayed }
        }

        return VerifiedServiceAuth(
            issuer: issuer.did,
            issuerFragment: issuer.fragment,
            keyID: keyID,
            audience: claims.aud,
            lexiconMethod: claims.lxm,
            nonce: claims.jti.flatMap { $0.isEmpty ? nil : $0 },
            expiresAt: expiresAt,
            issuedAt: claims.iat.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            algorithm: header.alg,
            signingKey: signingKey,
            claims: claims
        )
    }

    // MARK: Steps

    private static func parse(_ token: String, allowDERSignature: Bool) throws(ServiceAuthError) -> ServiceJWT.Parsed {
        do {
            return try ServiceJWT.parse(token, allowDERSignature: allowDERSignature)
        } catch let error as PetrelCryptoError {
            switch error {
            case let .malformed(detail), let .unauthorized(detail), let .invalidIdentifier(detail),
                 let .unsupportedAlgorithm(detail):
                throw .malformedToken(detail)
            case .expired:
                throw .expired
            }
        } catch {
            throw .malformedToken("service authentication token is invalid")
        }
    }

    private var effectiveClockSkew: TimeInterval {
        let skew = configuration.clockSkew
        return skew.isFinite && skew >= 0 && skew <= 5 * 60 ? skew : 0
    }

    /// The first instant at which a token with this `exp` is refused as
    /// expired.
    ///
    /// The expiry check compares whole seconds (`exp >= floor(now) - skew`,
    /// with the skew truncated), so the token stays acceptable until just
    /// before `exp + skew + 1`. The replay record must last that long, or
    /// the token could be replayed during its final accepted second.
    private func replayRecordExpiry(exp: Int64) -> Date {
        let lastAcceptedSecond = exp.addingReportingOverflow(Int64(effectiveClockSkew))
        guard !lastAcceptedSecond.overflow, lastAcceptedSecond.partialValue < .max else { return .distantFuture }
        return Date(timeIntervalSince1970: TimeInterval(lastAcceptedSecond.partialValue + 1))
    }

    private func checkTimes(_ claims: ServiceJWTClaims, now: Date) throws(ServiceAuthError) {
        let ceiling = configuration.maximumLifetime
        guard ServiceJWT.isValidTimePolicy(clockSkew: effectiveClockSkew, maximumLifetime: ceiling) else {
            // An unusable ceiling fails closed.
            throw .excessiveLifetime(maximum: 0)
        }
        switch ServiceJWT.timeFailure(claims, now: now, clockSkew: effectiveClockSkew, maximumLifetime: ceiling) {
        case nil:
            return
        case .expired:
            throw .expired
        case .excessiveLifetime:
            throw .excessiveLifetime(maximum: ceiling)
        case .expiresBeforeIssued:
            throw .malformedToken("exp is earlier than iat")
        case .invalidClock:
            throw .malformedToken("verifier clock is out of range")
        }
    }

    private func checkRequiredClaims(_ header: ServiceJWT.Header, claims: ServiceJWTClaims) throws(ServiceAuthError) {
        let required = configuration.requiredClaims
        if required.contains(.type), header.typ == nil {
            throw .missingClaim("typ")
        }
        if required.contains(.issuedAt), claims.iat == nil {
            throw .missingClaim("iat")
        }
        if required.contains(.nonce) || replayStore != nil, claims.jti?.isEmpty ?? true {
            throw .missingClaim("jti")
        }
    }

    /// Picks the verification method the token must verify under, and
    /// refuses it unless this service accepts that method.
    private func selectKeyID(header: ServiceJWT.Header, issuerFragment: String?) throws(ServiceAuthError) -> String {
        if let keyID = header.kid {
            guard ServiceAuthSyntax.isKeyID(keyID) else {
                throw .malformedToken("kid is not a DID document fragment starting with #")
            }
            guard configuration.acceptedKeyIDs.contains(keyID) else {
                throw .keyNotAccepted(keyID: keyID)
            }
            return keyID
        }
        if let issuerFragment, let mapped = configuration.issuerFragmentKeyIDs[issuerFragment] {
            return mapped
        }
        guard configuration.acceptedKeyIDs.contains(ServiceJWT.defaultKeyID) else {
            throw .keyNotAccepted(keyID: ServiceJWT.defaultKeyID)
        }
        return ServiceJWT.defaultKeyID
    }

    /// Resolves the issuer's key and checks the signature, retrying once
    /// with a forced refresh: after a key rotation the cached key is stale
    /// and the first attempt fails for an honest token.
    private func verifiedSigningKey(
        _ parsed: ServiceJWT.Parsed,
        issuerDID: String,
        keyID: String
    ) async throws(ServiceAuthError) -> ATProtoPublicKey {
        let cached = try await resolveKey(did: issuerDID, keyID: keyID, forceRefresh: false)
        if signatureVerifies(parsed, with: cached) {
            return cached
        }
        let fresh = try await resolveKey(did: issuerDID, keyID: keyID, forceRefresh: true)
        guard fresh != cached, signatureVerifies(parsed, with: fresh) else {
            throw .invalidSignature
        }
        return fresh
    }

    private func signatureVerifies(_ parsed: ServiceJWT.Parsed, with key: ATProtoPublicKey) -> Bool {
        // `alg` must be the algorithm of the published key; a key on the
        // other curve never verifies, whatever the header claims.
        key.jwtAlgorithm == parsed.header.alg
            && key.isValidSignature(parsed.signature, for: parsed.signingInput, options: configuration.signatureOptions)
    }

    private func resolveKey(
        did: String,
        keyID: String,
        forceRefresh: Bool
    ) async throws(ServiceAuthError) -> ATProtoPublicKey {
        do {
            if keyID == ServiceJWT.defaultKeyID {
                return try await keyResolver.signingKey(for: did, forceRefresh: forceRefresh)
            }
            return try await keyResolver.signingKey(for: did, keyID: keyID, forceRefresh: forceRefresh)
        } catch let error as ServiceAuthError {
            throw error
        } catch {
            throw .keyResolutionFailed(did: did, keyID: keyID, reason: String(describing: error))
        }
    }
}
