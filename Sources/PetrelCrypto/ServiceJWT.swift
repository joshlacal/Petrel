import Crypto
import Foundation

/// The claims of an AT Protocol inter-service authentication JWT.
///
/// Field names are the JWT claim names from the "Inter-Service
/// Authentication (JWT)" section of the XRPC specification.
public struct ServiceJWTClaims: Codable, Sendable, Equatable {
    /// Issuer: the DID of the account or service the request is made on
    /// behalf of. Legacy tokens may append `#service`.
    public let iss: String
    /// Audience: the DID of the receiving service, normally followed by
    /// its `#service` identifier.
    public let aud: String
    /// Creation time, UNIX seconds. Required by the specification; absent
    /// in tokens from some older issuers.
    public let iat: Int64?
    /// Expiry time, UNIX seconds.
    public let exp: Int64
    /// "Lexicon method": the NSID of the endpoint the token authorizes.
    /// Optional in the token; required for authenticated XRPC requests.
    public let lxm: String?
    /// Unique random nonce, for replay protection.
    public let jti: String?
    /// The `req` claim: a digest binding the token to one request body.
    /// A Petrel extension, not part of the AT Protocol specification;
    /// other implementations ignore it.
    public let requestBodyDigest: String?

    enum CodingKeys: String, CodingKey {
        case iss, aud, iat, exp, lxm, jti
        case requestBodyDigest = "req"
    }

    /// Creates a claim set. Use ``ServiceJWT`` to mint a signed token.
    public init(
        iss: String,
        aud: String,
        iat: Int64? = nil,
        exp: Int64,
        lxm: String? = nil,
        jti: String? = nil,
        requestBodyDigest: String? = nil
    ) {
        self.iss = iss
        self.aud = aud
        self.iat = iat
        self.exp = exp
        self.lxm = lxm
        self.jti = jti
        self.requestBodyDigest = requestBodyDigest
    }
}

/// What a compact service JWT says about itself, **before** its signature
/// has been checked.
///
/// Use this to decide how to verify a token (which issuer to resolve,
/// which key it names) or to read a token a PDS just issued to you. Never
/// treat an inspection as proof of who sent a request; that is what
/// ``ServiceAuthVerifier`` is for.
public struct ServiceJWTInspection: Sendable, Equatable {
    /// The `iss` claim exactly as sent, including any legacy `#fragment`.
    public let issuer: String
    /// The header `alg`: `ES256` or `ES256K`.
    public let algorithm: String
    /// The decoded claims.
    public let claims: ServiceJWTClaims
    /// The header `typ`, if present. Minted tokens say `JWT`.
    public let type: String?
    /// The header `kid`, if present: the fragment (with `#`) of the
    /// verification method the issuer says it signed with.
    public let keyID: String?

    /// Creates an inspection without header details.
    public init(issuer: String, algorithm: String, claims: ServiceJWTClaims) {
        self.init(issuer: issuer, algorithm: algorithm, claims: claims, type: nil, keyID: nil)
    }

    /// Creates an inspection.
    public init(issuer: String, algorithm: String, claims: ServiceJWTClaims, type: String?, keyID: String?) {
        self.issuer = issuer
        self.algorithm = algorithm
        self.claims = claims
        self.type = type
        self.keyID = keyID
    }

    /// The issuer's DID with any legacy `#fragment` removed.
    public var issuerDID: String {
        ServiceAuthSyntax.splitDIDReference(issuer)?.did ?? issuer
    }

    /// The fragment a legacy token appended to its issuer DID, without the
    /// `#`; `nil` for tokens that follow the current specification.
    public var issuerFragment: String? {
        ServiceAuthSyntax.splitDIDReference(issuer)?.fragment
    }

    /// The key the token claims to be signed with: ``keyID``, or `#atproto`
    /// when the header has no `kid`.
    public var effectiveKeyID: String { keyID ?? ServiceJWT.defaultKeyID }

    /// The `lxm` claim: the endpoint the token is bound to, if any.
    public var lexiconMethod: String? { claims.lxm }

    /// The `exp` claim as a date.
    public var expiresAt: Date { Date(timeIntervalSince1970: TimeInterval(claims.exp)) }
}

/// An in-memory signing key for the synchronous `ServiceJWT.mint(…key:…)`
/// overloads.
///
/// This enum predates ``ATProtoSigner``. New code should call
/// `ServiceJWT.mint(issuer:audience:lexiconMethod:signer:keyID:nonce:now:lifetime:)`
/// with a ``P256Keypair``, ``K256Keypair`` or any other ``ATProtoSigner``,
/// which also covers keys that cannot sign synchronously.
public enum ServiceJWTSigningKey: @unchecked Sendable {
    /// A Swift Crypto / CryptoKit P-256 key; tokens are signed `ES256`.
    case p256(P256.Signing.PrivateKey)
    /// A K-256 (secp256k1) keypair; tokens are signed `ES256K`.
    case k256(K256Keypair)
}

/// AT Protocol inter-service authentication JWTs: minting, inspection, and
/// verification against a key you already hold.
///
/// Both algorithms the protocol defines are supported: `ES256` (P-256) and
/// `ES256K` (K-256 / secp256k1). Minted signatures are 64-byte compact and
/// low-S; verification accepts either S value, as the specification
/// requires for JWTs.
///
/// ```swift
/// // Minting: a service or PDS signs with the issuer's key.
/// let token = try await ServiceJWT.mint(
///     issuer: "did:plc:abcdefghijklmnopqrstuvwx",
///     audience: "did:web:feed.example.com#bsky_fg",
///     lexiconMethod: "app.bsky.feed.getFeedSkeleton",
///     signer: keypair
/// )
/// ```
///
/// To authenticate an incoming request — resolve the issuer's key from its
/// DID document, check audience, method, expiry and replay — use
/// ``ServiceAuthVerifier``. The `verify` functions here are the lower-level
/// primitive it is built on, for callers that already hold the issuer's key.
public enum ServiceJWT {
    /// The claims of a service JWT.
    public typealias Claims = ServiceJWTClaims
    /// The unverified contents of a service JWT.
    public typealias Inspection = ServiceJWTInspection
    /// The legacy signing-key enum.
    public typealias SigningKey = ServiceJWTSigningKey

    /// Longest compact token accepted, in bytes.
    public static let maximumCompactBytes = 32 * 1024
    /// Lifetime of a minted token unless the caller chooses another: 60
    /// seconds, the lifetime the specification recommends.
    public static let defaultLifetime: TimeInterval = 60
    /// Longest lifetime `mint` will issue: one hour, the most the reference
    /// PDS grants through `com.atproto.server.getServiceAuth`.
    public static let maximumLifetime: TimeInterval = 60 * 60
    /// Longest token lifetime `verify` accepts unless told otherwise: one
    /// hour, so every token a reference PDS can issue verifies.
    public static let defaultMaximumAcceptedLifetime: TimeInterval = 60 * 60
    /// Clock skew `verify` tolerates on `exp` unless told otherwise.
    public static let defaultClockSkew: TimeInterval = 5
    /// The verification method a token is signed with when its header has
    /// no `kid`: the account's atproto signing key.
    public static let defaultKeyID = "#atproto"

    struct Header: Codable, Sendable {
        let alg: String
        let typ: String?
        let kid: String?
        let crit: [String]?
        let b64: Bool?

        init(alg: String, typ: String? = "JWT", kid: String? = nil, crit: [String]? = nil, b64: Bool? = nil) {
            self.alg = alg
            self.typ = typ
            self.kid = kid
            self.crit = crit
            self.b64 = b64
        }
    }

    struct Parsed: Sendable {
        let header: Header
        let claims: Claims
        let signingInput: Data
        let signature: Data
    }

    /// Mints a service JWT bound to the given issuer, audience, method (lxm),
    /// and eventID (jti) using the provided signing key (P-256 for ES256 or secp256k1 for ES256K).
    ///
    /// `requestBodyDigest` adds the non-standard `req` claim (see
    /// ``ServiceJWTClaims/requestBodyDigest``). New code should prefer
    /// `mint(issuer:audience:lexiconMethod:signer:keyID:nonce:now:lifetime:)`.
    public static func mint(
        issuer: String,
        audience: String,
        method: String,
        eventID: String,
        requestBodyDigest: String? = nil,
        key: ServiceJWTSigningKey,
        now: Date = Date(),
        lifetime: TimeInterval = defaultLifetime
    ) throws -> String {
        let alg: String
        switch key {
        case .p256: alg = "ES256"
        case .k256: alg = "ES256K"
        }
        let signingInput = try unsignedToken(
            issuer: issuer,
            audience: audience,
            method: method,
            nonce: eventID,
            requestBodyDigest: requestBodyDigest,
            keyID: nil,
            algorithm: alg,
            now: now,
            lifetime: lifetime
        )
        let signingInputData = Data(signingInput.utf8)

        let signatureData: Data
        switch key {
        case let .p256(p256Key):
            signatureData = try P256WireSignature.sign(signingInputData, using: p256Key)
        case let .k256(keypair):
            signatureData = try keypair.sign(signingInputData)
        }

        return "\(signingInput).\(JWTBase64URL.encode(signatureData))"
    }

    /// Mints a service JWT with any ``ATProtoSigner`` — a ``P256Keypair``, a
    /// ``K256Keypair``, a Secure Enclave key, or a remote signer.
    ///
    /// The header `alg` is the signer's ``ATProtoSigner/jwtAlgorithm``
    /// (`ES256` or `ES256K`). Claims are validated exactly as for the
    /// key-based overloads.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)`` if the claims are
    ///   invalid or the signer returns something other than a 64-byte
    ///   compact low-S signature; otherwise whatever the signer throws.
    public static func mint(
        issuer: String,
        audience: String,
        method: String,
        eventID: String,
        requestBodyDigest: String? = nil,
        signer: any ATProtoSigner,
        now: Date = Date(),
        lifetime: TimeInterval = defaultLifetime
    ) async throws -> String {
        let signingInput = try unsignedToken(
            issuer: issuer,
            audience: audience,
            method: method,
            nonce: eventID,
            requestBodyDigest: requestBodyDigest,
            keyID: nil,
            algorithm: signer.jwtAlgorithm,
            now: now,
            lifetime: lifetime
        )
        return try await sign(signingInput, with: signer)
    }

    /// Mints a service JWT as the specification describes it: `lxm` is
    /// optional, `jti` is a fresh random nonce unless you supply one, and
    /// the header can name the signing key.
    ///
    /// ```swift
    /// let token = try await ServiceJWT.mint(
    ///     issuer: accountDID,
    ///     audience: "did:web:api.bsky.app#bsky_appview",
    ///     lexiconMethod: "app.bsky.feed.getTimeline",
    ///     signer: accountSigningKey
    /// )
    /// request.setValue(ServiceJWT.bearerAuthorization(token), forHTTPHeaderField: "Authorization")
    /// ```
    ///
    /// - Parameters:
    ///   - issuer: The DID the request is made on behalf of. A legacy
    ///     `did#service` form is still accepted.
    ///   - audience: The receiving service's DID, with its `#service`
    ///     identifier (`did:web:api.bsky.app#bsky_appview`). A bare DID is
    ///     accepted for legacy receivers; new software should include the
    ///     fragment.
    ///   - lexiconMethod: The NSID of the endpoint being called (`lxm`).
    ///     Required for authenticated XRPC requests; pass `nil` only for a
    ///     receiver that takes method-less tokens.
    ///   - signer: The issuer's signing key: a ``P256Keypair``,
    ///     ``K256Keypair``, Secure Enclave key or remote signer. The header
    ///     `alg` is its ``ATProtoSigner/jwtAlgorithm``.
    ///   - keyID: The `kid` header: the DID-document fragment, with its
    ///     `#`, of the key being used. Leave `nil` when signing with the
    ///     account's `#atproto` key; set it (for example `#atproto_label`)
    ///     when a service signs with another published key.
    ///   - nonce: The `jti` claim. `nil` generates 16 random bytes, hex
    ///     encoded, as the reference implementation does.
    ///   - now: The token's `iat`.
    ///   - lifetime: Whole seconds until `exp`, at most
    ///     ``maximumLifetime``. The specification recommends 60 seconds
    ///     because tokens cannot be revoked.
    /// - Throws: ``PetrelCryptoError/malformed(_:)`` naming the invalid
    ///   argument, or if the signer returns something other than a 64-byte
    ///   compact low-S signature; otherwise whatever the signer throws.
    public static func mint(
        issuer: String,
        audience: String,
        lexiconMethod: String?,
        signer: any ATProtoSigner,
        keyID: String? = nil,
        nonce: String? = nil,
        now: Date = Date(),
        lifetime: TimeInterval = defaultLifetime
    ) async throws -> String {
        let signingInput = try unsignedToken(
            issuer: issuer,
            audience: audience,
            method: lexiconMethod,
            nonce: nonce ?? Hex.encode(ATProtoCrypto.randomBytes(count: 16)),
            requestBodyDigest: nil,
            keyID: keyID,
            algorithm: signer.jwtAlgorithm,
            now: now,
            lifetime: lifetime
        )
        return try await sign(signingInput, with: signer)
    }

    /// The `Authorization` header value that carries a service JWT:
    /// `Bearer <token>`.
    public static func bearerAuthorization(_ token: String) -> String {
        "Bearer \(token)"
    }

    private static func sign(_ signingInput: String, with signer: any ATProtoSigner) async throws -> String {
        let signature = try await signer.sign(Data(signingInput.utf8))
        guard ATProtoSignature.isCanonical(signature, curve: signer.curve) else {
            throw PetrelCryptoError.malformed("signer did not return a 64-byte compact low-S signature")
        }
        return "\(signingInput).\(JWTBase64URL.encode(signature))"
    }

    /// Validates the claims and returns `base64url(header).base64url(claims)`.
    private static func unsignedToken(
        issuer: String,
        audience: String,
        method: String?,
        nonce: String,
        requestBodyDigest: String?,
        keyID: String?,
        algorithm: String,
        now: Date,
        lifetime: TimeInterval
    ) throws -> String {
        guard ServiceAuthSyntax.splitDIDReference(issuer) != nil else {
            throw PetrelCryptoError.malformed("service authentication issuer is not a DID")
        }
        guard ServiceAuthSyntax.splitDIDReference(audience) != nil else {
            throw PetrelCryptoError.malformed(
                "service authentication audience is not a DID with an optional #service fragment"
            )
        }
        if let method, !ServiceAuthSyntax.isNSID(method) {
            throw PetrelCryptoError.malformed("service authentication lexicon method is not an NSID")
        }
        guard ServiceAuthSyntax.isPrintableASCII(nonce, maximumBytes: 256) else {
            throw PetrelCryptoError.malformed("service authentication nonce must be 1-256 printable ASCII characters")
        }
        guard validServiceRequestBodyDigest(requestBodyDigest) else {
            throw PetrelCryptoError.malformed("service authentication request body digest is invalid")
        }
        if let keyID, !ServiceAuthSyntax.isKeyID(keyID) {
            throw PetrelCryptoError.malformed(
                "service authentication key id must be a DID document fragment starting with #"
            )
        }
        guard lifetime > 0, lifetime <= maximumLifetime,
              lifetime.rounded(.towardZero) == lifetime else {
            throw PetrelCryptoError.malformed(
                "service authentication lifetime must be a whole number of seconds from 1 to \(Int(maximumLifetime))"
            )
        }
        guard let iat = integerServiceTimestamp(now) else {
            throw PetrelCryptoError.malformed("service authentication current time is invalid")
        }
        let (exp, overflow) = iat.addingReportingOverflow(Int64(lifetime))
        guard !overflow else {
            throw PetrelCryptoError.malformed("service authentication expiry is invalid")
        }

        let claims = Claims(
            iss: issuer,
            aud: audience,
            iat: iat,
            exp: exp,
            lxm: method,
            jti: nonce,
            requestBodyDigest: requestBodyDigest
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let headerData = try encoder.encode(Header(alg: algorithm, typ: "JWT", kid: keyID))
        let claimsData = try encoder.encode(claims)

        return "\(JWTBase64URL.encode(headerData)).\(JWTBase64URL.encode(claimsData))"
    }

    /// Mints an `ES256` service JWT with a Swift Crypto P-256 key. Same
    /// claims as the `key: ServiceJWTSigningKey` overload.
    public static func mint(
        issuer: String,
        audience: String,
        method: String,
        eventID: String,
        requestBodyDigest: String? = nil,
        key: P256.Signing.PrivateKey,
        now: Date = Date(),
        lifetime: TimeInterval = defaultLifetime
    ) throws -> String {
        try mint(
            issuer: issuer,
            audience: audience,
            method: method,
            eventID: eventID,
            requestBodyDigest: requestBodyDigest,
            key: .p256(key),
            now: now,
            lifetime: lifetime
        )
    }

    /// A legacy spelling of `mint(issuer:audience:method:eventID:requestBodyDigest:key:now:lifetime:)`.
    public static func create(
        issuer: String,
        audience: String,
        method: String,
        eventID: String,
        requestBodyDigest: String? = nil,
        key: P256.Signing.PrivateKey,
        now: Date = Date(),
        lifetime: TimeInterval = defaultLifetime
    ) throws -> String {
        try mint(
            issuer: issuer,
            audience: audience,
            method: method,
            eventID: eventID,
            requestBodyDigest: requestBodyDigest,
            key: .p256(key),
            now: now,
            lifetime: lifetime
        )
    }

    /// Decodes a compact service JWT **without verifying its signature**.
    ///
    /// The token must be structurally valid — three base64url segments, a
    /// duplicate-free JSON header and payload, an `ES256` or `ES256K`
    /// algorithm, a DID issuer — but `lxm`, `iat` and `jti` may be absent,
    /// and expiry is not checked.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)`` for a token that does
    ///   not parse; ``PetrelCryptoError/unauthorized(_:)`` for one whose
    ///   header or claims are not those of a service token.
    public static func inspect(_ compact: String) throws -> Inspection {
        let parsed = try parse(compact)
        try validateShape(parsed.header, claims: parsed.claims)
        return Inspection(
            issuer: parsed.claims.iss,
            algorithm: parsed.header.alg,
            claims: parsed.claims,
            type: parsed.header.typ,
            keyID: parsed.header.kid
        )
    }

    /// Verifies a service JWT against an already-resolved public key.
    ///
    /// The signature must be the 64-byte compact encoding. Either S value
    /// is accepted: the specification's low-S rule covers signatures over
    /// CBOR objects and "does not impact JWT signature validation, for
    /// example service auth tokens", and the reference implementation
    /// verifies these with `allowMalleableSig: true`. Use the overload with
    /// `signatureOptions:` to demand low-S.
    ///
    /// - Important: `expectedAudience` and `expectedMethod` default to
    ///   `nil`, which **skips** those checks. A service authenticating a
    ///   request must check both; ``ServiceAuthVerifier`` makes them
    ///   mandatory and also resolves the issuer's key for you.
    ///
    /// - Parameters:
    ///   - compact: The token.
    ///   - publicKey: The issuer's signing key.
    ///   - expectedAudience: The exact `aud` required, or `nil` to skip.
    ///   - expectedMethod: The exact `lxm` required, or `nil` to skip. A
    ///     token without `lxm` fails when a method is expected.
    ///   - expectedRequestBodyDigest: The exact `req` required, or `nil`.
    ///   - now: The verifier's clock.
    ///   - clockSkew: Seconds past `exp` a token is still accepted
    ///     (0...300).
    ///   - maximumLifetime: The longest token accepted: `exp` may be at
    ///     most this far ahead of `now`, and `exp - iat` at most this long.
    /// - Throws: ``PetrelCryptoError/expired`` for an expired token,
    ///   ``PetrelCryptoError/unauthorized(_:)`` for any other refusal,
    ///   ``PetrelCryptoError/malformed(_:)`` for input that does not parse.
    public static func verify(
        _ compact: String,
        publicKey: ATProtoJWTVerificationKey,
        expectedAudience: String? = nil,
        expectedMethod: String? = nil,
        expectedRequestBodyDigest: String? = nil,
        now: Date = Date(),
        clockSkew: TimeInterval = defaultClockSkew,
        maximumLifetime: TimeInterval = defaultMaximumAcceptedLifetime
    ) throws -> Claims {
        try verify(
            compact,
            publicKey: publicKey,
            signatureOptions: .jwt,
            expectedAudience: expectedAudience,
            expectedMethod: expectedMethod,
            expectedRequestBodyDigest: expectedRequestBodyDigest,
            now: now,
            clockSkew: clockSkew,
            maximumLifetime: maximumLifetime
        )
    }

    /// Verifies a service JWT under an explicit signature-encoding policy.
    ///
    /// `signatureOptions` chooses which encodings pass:
    /// ``ATProtoSignatureVerificationOptions/jwt`` (compact, either S) is
    /// what the specification asks for;
    /// ``ATProtoSignatureVerificationOptions/strict`` additionally rejects
    /// high-S. The other parameters are those of
    /// `verify(_:publicKey:expectedAudience:expectedMethod:expectedRequestBodyDigest:now:clockSkew:maximumLifetime:)`.
    public static func verify(
        _ compact: String,
        publicKey: ATProtoJWTVerificationKey,
        signatureOptions: ATProtoSignatureVerificationOptions,
        expectedAudience: String? = nil,
        expectedMethod: String? = nil,
        expectedRequestBodyDigest: String? = nil,
        now: Date = Date(),
        clockSkew: TimeInterval = defaultClockSkew,
        maximumLifetime: TimeInterval = defaultMaximumAcceptedLifetime
    ) throws -> Claims {
        guard isValidTimePolicy(clockSkew: clockSkew, maximumLifetime: maximumLifetime) else {
            throw PetrelCryptoError.malformed("service authentication time policy is invalid")
        }
        let parsed = try parse(compact)
        try validateShape(parsed.header, claims: parsed.claims)
        if let expectedAudience {
            guard parsed.claims.aud == expectedAudience else {
                throw PetrelCryptoError.unauthorized("service authentication audience mismatch")
            }
        }
        if let expectedMethod {
            guard parsed.claims.lxm == expectedMethod else {
                throw PetrelCryptoError.unauthorized("service authentication method mismatch")
            }
        }
        if let expectedRequestBodyDigest {
            guard parsed.claims.requestBodyDigest == expectedRequestBodyDigest else {
                throw PetrelCryptoError.unauthorized("service authentication request body digest mismatch")
            }
        }
        guard try publicKey.verify(
            signature: parsed.signature,
            signingInput: parsed.signingInput,
            algorithm: parsed.header.alg,
            options: signatureOptions
        ) else {
            throw PetrelCryptoError.unauthorized("service authentication signature is invalid")
        }
        switch timeFailure(parsed.claims, now: now, clockSkew: clockSkew, maximumLifetime: maximumLifetime) {
        case nil:
            return parsed.claims
        case .invalidClock:
            throw PetrelCryptoError.malformed("service authentication current time is invalid")
        case .expired:
            throw PetrelCryptoError.expired
        case .excessiveLifetime, .expiresBeforeIssued:
            throw PetrelCryptoError.unauthorized("service authentication time claims are invalid")
        }
    }

    // MARK: Time policy

    /// Why a token's `exp` / `iat` are unacceptable.
    enum TimeFailure: Sendable, Equatable {
        /// The verifier's own clock is not representable.
        case invalidClock
        /// `exp` is more than the clock skew in the past.
        case expired
        /// `exp` is beyond `now + skew + maximumLifetime`, or `exp - iat`
        /// exceeds `maximumLifetime`.
        case excessiveLifetime
        /// `exp` is earlier than `iat`.
        case expiresBeforeIssued
    }

    /// Whether a clock skew and lifetime ceiling are usable: skew within
    /// 0...300 s, ceiling positive, both finite.
    static func isValidTimePolicy(clockSkew: TimeInterval, maximumLifetime: TimeInterval) -> Bool {
        clockSkew.isFinite && maximumLifetime.isFinite
            && clockSkew >= 0 && clockSkew <= 5 * 60
            && maximumLifetime > 0 && maximumLifetime <= maximumConfigurableLifetime
    }

    /// Upper bound on a configurable lifetime ceiling (one year). The
    /// specification sets no ceiling; this only keeps the arithmetic in
    /// range.
    static let maximumConfigurableLifetime: TimeInterval = 365 * 24 * 60 * 60

    /// Checks `exp` and `iat` against the clock.
    ///
    /// `iat` is used only to bound the token's stated lifetime. It is not
    /// compared with the clock: RFC 7519 makes `iat` informational (the
    /// not-before claim is `nbf`), neither reference implementation
    /// rejects a token for a future `iat`, and doing so would turn a few
    /// seconds of issuer clock drift into authentication failures.
    static func timeFailure(
        _ claims: Claims,
        now: Date,
        clockSkew: TimeInterval,
        maximumLifetime: TimeInterval
    ) -> TimeFailure? {
        guard let nowSeconds = integerServiceTimestamp(now) else { return .invalidClock }
        let skew = Int64(clockSkew)
        let ceiling = Int64(maximumLifetime)
        let expirationCutoff = nowSeconds.subtractingReportingOverflow(skew)
        guard !expirationCutoff.overflow else { return .invalidClock }
        guard claims.exp >= expirationCutoff.partialValue else { return .expired }
        let latestStart = nowSeconds.addingReportingOverflow(skew)
        let latestExpiration = latestStart.partialValue.addingReportingOverflow(ceiling)
        guard !latestStart.overflow, !latestExpiration.overflow else { return .invalidClock }
        guard claims.exp <= latestExpiration.partialValue else { return .excessiveLifetime }
        if let issuedAt = claims.iat {
            guard claims.exp >= issuedAt else { return .expiresBeforeIssued }
            let lifetime = claims.exp.subtractingReportingOverflow(issuedAt)
            guard !lifetime.overflow, lifetime.partialValue <= ceiling else { return .excessiveLifetime }
        }
        return nil
    }

    /// Verifies a service JWT against a validated ``ATProtoPublicKey`` on
    /// either curve.
    ///
    /// `signatureOptions` defaults to
    /// ``ATProtoSignatureVerificationOptions/jwt``: the 64-byte encoding
    /// with either S value. `expectedAudience` and `expectedMethod` default
    /// to `nil`, which skips those checks; a service authenticating a
    /// request should use ``ServiceAuthVerifier``, which requires both.
    public static func verify(
        _ compact: String,
        publicKey: ATProtoPublicKey,
        signatureOptions: ATProtoSignatureVerificationOptions = .jwt,
        expectedAudience: String? = nil,
        expectedMethod: String? = nil,
        expectedRequestBodyDigest: String? = nil,
        now: Date = Date(),
        clockSkew: TimeInterval = defaultClockSkew,
        maximumLifetime: TimeInterval = defaultMaximumAcceptedLifetime
    ) throws -> Claims {
        try verify(
            compact,
            publicKey: ATProtoJWTVerificationKey(publicKey),
            signatureOptions: signatureOptions,
            expectedAudience: expectedAudience,
            expectedMethod: expectedMethod,
            expectedRequestBodyDigest: expectedRequestBodyDigest,
            now: now,
            clockSkew: clockSkew,
            maximumLifetime: maximumLifetime
        )
    }

    /// Verifies a service JWT against a key decoded by ``PLCDIDKeyCodec``.
    /// See `verify(_:publicKey:expectedAudience:expectedMethod:expectedRequestBodyDigest:now:clockSkew:maximumLifetime:)`.
    public static func verify(
        _ compact: String,
        publicKey: PLCDIDVerificationKey,
        expectedAudience: String? = nil,
        expectedMethod: String? = nil,
        expectedRequestBodyDigest: String? = nil,
        now: Date = Date(),
        clockSkew: TimeInterval = defaultClockSkew,
        maximumLifetime: TimeInterval = defaultMaximumAcceptedLifetime
    ) throws -> Claims {
        try verify(
            compact,
            publicKey: ATProtoJWTVerificationKey(publicKey),
            expectedAudience: expectedAudience,
            expectedMethod: expectedMethod,
            expectedRequestBodyDigest: expectedRequestBodyDigest,
            now: now,
            clockSkew: clockSkew,
            maximumLifetime: maximumLifetime
        )
    }

    /// Verifies a service JWT against a `did:key` on either curve.
    /// See `verify(_:publicKey:expectedAudience:expectedMethod:expectedRequestBodyDigest:now:clockSkew:maximumLifetime:)`.
    public static func verify(
        _ compact: String,
        didKey: String,
        expectedAudience: String? = nil,
        expectedMethod: String? = nil,
        expectedRequestBodyDigest: String? = nil,
        now: Date = Date(),
        clockSkew: TimeInterval = defaultClockSkew,
        maximumLifetime: TimeInterval = defaultMaximumAcceptedLifetime
    ) throws -> Claims {
        let key = try PLCDIDKeyCodec.decode(didKey)
        return try verify(
            compact,
            publicKey: key,
            expectedAudience: expectedAudience,
            expectedMethod: expectedMethod,
            expectedRequestBodyDigest: expectedRequestBodyDigest,
            now: now,
            clockSkew: clockSkew,
            maximumLifetime: maximumLifetime
        )
    }

    private static func integerServiceTimestamp(_ date: Date) -> Int64? {
        let timestamp = date.timeIntervalSince1970
        guard timestamp.isFinite,
              timestamp >= Double(Int64.min),
              timestamp < Double(Int64.max) else {
            return nil
        }
        return Int64(timestamp)
    }

    /// Splits and decodes a compact JWS.
    ///
    /// - Parameter allowDERSignature: Admit a signature segment that is
    ///   not 64 bytes (up to 72, the longest ASN.1 DER encoding). Only the
    ///   reference-parity ``ATProtoSignatureVerificationOptions/allowMalleable``
    ///   policy uses this; a JWS signature is `r || s`.
    static func parse(_ compact: String, allowDERSignature: Bool = false) throws -> Parsed {
        guard !compact.isEmpty, compact.utf8.count <= maximumCompactBytes else {
            throw PetrelCryptoError.malformed("service authentication token is invalid")
        }
        let pieces = compact.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 3,
              pieces.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 16 * 1024 }),
              let headerData = try? JWTBase64URL.decode(String(pieces[0]), maxBytes: 4 * 1024),
              let payload = try? JWTBase64URL.decode(String(pieces[1]), maxBytes: 16 * 1024),
              let signature = try? JWTBase64URL.decode(String(pieces[2]), maxBytes: allowDERSignature ? 72 : 64),
              signature.count == 64 || allowDERSignature else {
            throw PetrelCryptoError.malformed("service authentication token is invalid")
        }
        let header = try StrictJSON.decode(Header.self, from: headerData)
        let claims = try StrictJSON.decode(Claims.self, from: payload)
        return Parsed(
            header: header,
            claims: claims,
            signingInput: Data("\(pieces[0]).\(pieces[1])".utf8),
            signature: signature
        )
    }

    /// The token types that are never service tokens: OAuth access tokens,
    /// the reference PDS's refresh tokens, and DPoP proofs.
    static let disallowedTypes: Set<String> = ["at+jwt", "refresh+jwt", "dpop+jwt"]

    /// The algorithms a service token may be signed with.
    static let allowedAlgorithms: Set<String> = ["ES256", "ES256K"]

    /// Structural problems with a decoded header and claim set, as a typed
    /// reason. `nil` means the token has the shape of a service token; it
    /// says nothing about its signature, audience, method or expiry.
    ///
    /// `lxm`, `iat`, `jti` and `kid` may be absent. `kid` syntax is not
    /// judged here: the pinned-key primitives ignore `kid`, and
    /// ``ServiceAuthVerifier`` checks it when it selects a key.
    static func shapeFailure(_ header: Header, claims: Claims) -> ServiceAuthError? {
        if header.crit != nil || header.b64 != nil {
            return .malformedToken("unsupported critical header parameters")
        }
        if let type = header.typ, disallowedTypes.contains(type.lowercased()) {
            return .disallowedTokenType(type)
        }
        if ServiceAuthSyntax.splitDIDReference(claims.iss) == nil {
            return .invalidIssuer(claims.iss)
        }
        if !ServiceAuthSyntax.isPrintableASCII(claims.aud, maximumBytes: 4096) {
            return .malformedToken("aud is not a service identifier")
        }
        if let method = claims.lxm, !ServiceAuthSyntax.isNSID(method) {
            return .malformedToken("lxm is not an NSID")
        }
        if let nonce = claims.jti, !nonce.isEmpty, !ServiceAuthSyntax.isPrintableASCII(nonce, maximumBytes: 256) {
            return .malformedToken("jti is not a printable nonce")
        }
        if !validServiceRequestBodyDigest(claims.requestBodyDigest) {
            return .malformedToken("req is not a printable digest")
        }
        return nil
    }

    private static func validateShape(_ header: Header, claims: Claims) throws {
        guard allowedAlgorithms.contains(header.alg), shapeFailure(header, claims: claims) == nil else {
            throw PetrelCryptoError.unauthorized("service authentication token is invalid")
        }
    }

    private static func validServiceRequestBodyDigest(_ value: String?) -> Bool {
        guard let value else { return true }
        return ServiceAuthSyntax.isPrintableASCII(value, maximumBytes: 4096)
    }

    /// Whether `value` is a syntactically valid NSID, as required of the
    /// `lxm` claim: at least three period-separated segments, a domain
    /// authority, and a name of letters and digits.
    public static func isNSID(_ value: String) -> Bool { ServiceAuthSyntax.isNSID(value) }
}

/// Backward compatibility types.
///
/// `ProxyServiceJWT` is a legacy alias for the P-256 minting path of
/// ``ServiceJWT``, kept so existing callers compile. New code should call
/// `ServiceJWT.mint(issuer:audience:lexiconMethod:signer:keyID:nonce:now:lifetime:)`.
public enum ProxyServiceJWT {
    /// The longest (and default) lifetime of a token minted through this
    /// alias: 60 seconds.
    public static let maximumLifetime: TimeInterval = 60

    public static func create(
        issuer: String,
        audience: String,
        method: String,
        eventID: String,
        requestBodyDigest: String? = nil,
        key: P256.Signing.PrivateKey,
        now: Date = Date(),
        lifetime: TimeInterval = maximumLifetime
    ) throws -> String {
        try ServiceJWT.mint(
            issuer: issuer,
            audience: audience,
            method: method,
            eventID: eventID,
            requestBodyDigest: requestBodyDigest,
            key: .p256(key),
            now: now,
            lifetime: lifetime
        )
    }

    public static func isNSID(_ value: String) -> Bool {
        ServiceJWT.isNSID(value)
    }
}

/// A legacy alias for ``ServiceJWT`` with the time policy permissioned-data
/// ("Spaces") callers were built against: 60 seconds of clock skew and a
/// five minute lifetime ceiling. New code should use ``ServiceJWT`` and
/// ``ServiceAuthVerifier``.
public enum SpaceServiceJWT {
    public typealias Claims = ServiceJWTClaims
    public typealias Inspection = ServiceJWTInspection

    public static let maximumCompactBytes = ServiceJWT.maximumCompactBytes
    public static let lifetime: TimeInterval = ServiceJWT.defaultLifetime

    public static func create(
        issuer: String,
        audience: String,
        method: String,
        eventID: String,
        requestBodyDigest: String? = nil,
        key: P256.Signing.PrivateKey,
        now: Date = Date(),
        lifetime: TimeInterval = lifetime
    ) throws -> String {
        try ServiceJWT.mint(
            issuer: issuer,
            audience: audience,
            method: method,
            eventID: eventID,
            requestBodyDigest: requestBodyDigest,
            key: .p256(key),
            now: now,
            lifetime: lifetime
        )
    }

    public static func inspect(_ compact: String) throws -> Inspection {
        try ServiceJWT.inspect(compact)
    }

    public static func verify(
        _ compact: String,
        publicKey: ATProtoJWTVerificationKey,
        expectedAudience: String? = nil,
        expectedMethod: String? = nil,
        expectedRequestBodyDigest: String? = nil,
        now: Date = Date(),
        clockSkew: TimeInterval = 60,
        maximumLifetime: TimeInterval = 5 * 60
    ) throws -> Claims {
        try ServiceJWT.verify(
            compact,
            publicKey: publicKey,
            expectedAudience: expectedAudience,
            expectedMethod: expectedMethod,
            expectedRequestBodyDigest: expectedRequestBodyDigest,
            now: now,
            clockSkew: clockSkew,
            maximumLifetime: maximumLifetime
        )
    }

    public static func verify(
        _ compact: String,
        publicKey: PLCDIDVerificationKey,
        expectedAudience: String? = nil,
        expectedMethod: String? = nil,
        expectedRequestBodyDigest: String? = nil,
        now: Date = Date(),
        clockSkew: TimeInterval = 60,
        maximumLifetime: TimeInterval = 5 * 60
    ) throws -> Claims {
        try ServiceJWT.verify(
            compact,
            publicKey: publicKey,
            expectedAudience: expectedAudience,
            expectedMethod: expectedMethod,
            expectedRequestBodyDigest: expectedRequestBodyDigest,
            now: now,
            clockSkew: clockSkew,
            maximumLifetime: maximumLifetime
        )
    }
}
