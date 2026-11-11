import Foundation
import PetrelCrypto

/// The protected header of a compact JWS, limited to the members the AT
/// Protocol OAuth profile uses.
public struct OAuthJWTHeader: Codable, Sendable, Equatable {
    /// The signature algorithm name (`alg`), exactly as the token states it.
    public let algorithm: String
    /// The media type (`typ`), for example `dpop+jwt` or `at+jwt`.
    public let type: String?
    /// The key identifier (`kid`).
    public let keyID: String?
    /// The embedded public key (`jwk`), as DPoP proofs carry.
    public let jwk: OAuthJSONWebKey?
    /// `crit`. Always rejected by ``OAuthCompactJWT``; modelled so its
    /// presence can be detected.
    public let criticalHeaders: [String]?
    /// `b64`. Always rejected by ``OAuthCompactJWT``; modelled so its presence
    /// can be detected.
    public let base64Payload: Bool?

    /// Creates a header for signing.
    public init(
        algorithm: OAuthJWSAlgorithm,
        type: String? = nil,
        keyID: String? = nil,
        jwk: OAuthJSONWebKey? = nil
    ) {
        self.algorithm = algorithm.rawValue
        self.type = type
        self.keyID = keyID
        self.jwk = jwk
        criticalHeaders = nil
        base64Payload = nil
    }

    private enum CodingKeys: String, CodingKey {
        case algorithm = "alg"
        case type = "typ"
        case keyID = "kid"
        case jwk
        case criticalHeaders = "crit"
        case base64Payload = "b64"
    }
}

/// The registered JWT claims (RFC 7519 §4.1), decoded independently of any
/// profile-specific claims. `aud` follows JWT's string-or-array encoding.
public struct OAuthJWTRegisteredClaims: Decodable, Sendable, Equatable {
    /// `iss`.
    public let issuer: String?
    /// `sub`.
    public let subject: String?
    /// `aud`, normalised to an array.
    public let audience: [String]?
    /// `iat` in whole seconds. A fractional NumericDate is legal (RFC 7519 §2)
    /// and is truncated toward negative infinity.
    public let issuedAt: Int64?
    /// `exp` in whole seconds, truncated like ``issuedAt``.
    public let expiresAt: Int64?
    /// `nbf` in whole seconds, rounded up so a fractional value is never
    /// honoured early.
    public let notBefore: Int64?
    /// `jti`.
    public let jwtID: String?

    private enum CodingKeys: String, CodingKey {
        case issuer = "iss"
        case subject = "sub"
        case audience = "aud"
        case issuedAt = "iat"
        case expiresAt = "exp"
        case notBefore = "nbf"
        case jwtID = "jti"
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        issuer = try values.decodeIfPresent(String.self, forKey: .issuer)
        subject = try values.decodeIfPresent(String.self, forKey: .subject)
        if let single = try? values.decodeIfPresent(String.self, forKey: .audience) {
            audience = [single]
        } else {
            audience = try values.decodeIfPresent([String].self, forKey: .audience)
        }
        issuedAt = try Self.numericDate(values, .issuedAt, roundingUp: false)
        expiresAt = try Self.numericDate(values, .expiresAt, roundingUp: false)
        notBefore = try Self.numericDate(values, .notBefore, roundingUp: true)
        jwtID = try values.decodeIfPresent(String.self, forKey: .jwtID)
    }

    private static func numericDate(
        _ values: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys,
        roundingUp: Bool
    ) throws -> Int64? {
        guard let raw = try values.decodeIfPresent(Double.self, forKey: key) else { return nil }
        let rounded = roundingUp ? raw.rounded(.up) : raw.rounded(.down)
        // `Double(Int64.max)` rounds up to 2^63, which does not convert back.
        guard rounded.isFinite, rounded >= Double(Int64.min), rounded < Double(Int64.max) else {
            throw OAuthServerError.malformed("JWT NumericDate is out of range")
        }
        return Int64(rounded)
    }
}

/// Constraints applied after a compact JWT has been structurally parsed and
/// its signature has verified. The defaults require no registered claims, so
/// the same verifier serves DPoP proofs, client assertions and access tokens,
/// and each caller opts into the claims its profile needs.
public struct OAuthJWTVerificationConstraints: Sendable, Equatable {
    /// When set, `iss` must equal this value.
    public var expectedIssuer: String?
    /// When set, `aud` must contain this value.
    public var expectedAudience: String?
    /// The instant the token is evaluated at.
    public var now: Date
    /// Tolerance applied to `iat`, `nbf` and `exp`.
    public var clockSkew: TimeInterval
    /// Whether a missing `iat` is an error.
    public var requireIssuedAt: Bool
    /// Whether a missing `exp` is an error.
    public var requireExpiration: Bool
    /// When set, `exp - iat` may not exceed this many seconds.
    public var maxLifetime: TimeInterval?
    /// When set, `iat` may not be older than this many seconds.
    public var maximumAge: TimeInterval?

    /// Creates a constraint set.
    public init(
        expectedIssuer: String? = nil,
        expectedAudience: String? = nil,
        now: Date = Date(),
        clockSkew: TimeInterval = 60,
        requireIssuedAt: Bool = false,
        requireExpiration: Bool = false,
        maxLifetime: TimeInterval? = nil,
        maximumAge: TimeInterval? = nil
    ) {
        self.expectedIssuer = expectedIssuer
        self.expectedAudience = expectedAudience
        self.now = now
        self.clockSkew = clockSkew
        self.requireIssuedAt = requireIssuedAt
        self.requireExpiration = requireExpiration
        self.maxLifetime = maxLifetime
        self.maximumAge = maximumAge
    }
}

/// A compact JWT whose signature and registered claims have been verified.
public struct OAuthVerifiedJWT: Sendable {
    /// The protected header.
    public let header: OAuthJWTHeader
    /// The raw JSON payload, for decoding profile-specific claims with
    /// ``OAuthCompactJWT/decodeClaims(_:from:)``.
    public let payload: Data
    /// The registered claims.
    public let registeredClaims: OAuthJWTRegisteredClaims
}

/// Which `(r, s)` encodings a compact JWT's ECDSA signature may use.
///
/// JOSE verifies by SEC1, which accepts `(r, s)` and `(r, n - s)` alike, and
/// conformant signers emit high-S roughly half the time. AT Protocol-native
/// signatures (repository commits, service-auth tokens) are canonical low-S
/// wire values, so a second valid encoding of the same signature is rejected
/// there.
public enum OAuthJWTSignatureEncoding: Sendable, Equatable {
    /// Reject high-S. Correct for AT Protocol-defined signatures.
    case canonicalLowS
    /// Accept either encoding. Correct for JOSE tokens from third-party OAuth
    /// clients: DPoP proofs and client assertions.
    case joseInteroperable
}

/// Strict compact-JWS signing and verification for ES256 and ES256K.
///
/// The verifier never accepts `none`, never infers an algorithm from a key
/// (the header's `alg` must equal the algorithm of the key's curve), rejects
/// `crit` and `b64`, and scans header and payload JSON for duplicate member
/// names before decoding either document.
public enum OAuthCompactJWT {
    /// The largest compact serialization accepted, in bytes.
    public static let maximumCompactBytes = 32768

    /// Reads a JOSE header only to locate the verification key. The result is
    /// untrusted: callers must verify the complete token before relying on any
    /// field.
    public static func unverifiedHeader(_ compact: String) throws -> OAuthJWTHeader {
        try parse(compact).header
    }

    /// Reads a claims document from a token whose signature has NOT been
    /// checked. Useful only to pick which validator to run; never to make an
    /// authorization decision.
    public static func unverifiedClaims<Claims: Decodable>(
        _ type: Claims.Type,
        from compact: String
    ) throws -> Claims {
        try strictDecode(type, from: parse(compact).payload)
    }

    /// Verifies a compact JWT against one public key.
    ///
    /// - Parameters:
    ///   - compact: the `header.payload.signature` serialization.
    ///   - key: the verification key. The header's `alg` must be the algorithm
    ///     of this key's curve.
    ///   - expectedType: when set, the header's `typ` must equal it exactly.
    ///   - signatureEncoding: whether a high-S signature is acceptable.
    ///   - constraints: registered-claim checks.
    /// - Throws: ``OAuthServerError/malformed(_:)`` for structural problems,
    ///   ``OAuthServerError/unauthorized(_:)`` for a bad signature, type,
    ///   algorithm, issuer or audience, and ``OAuthServerError/expired`` when
    ///   `exp` or the maximum age has passed.
    public static func verify(
        _ compact: String,
        key: OAuthJSONWebKey,
        expectedType: String? = nil,
        signatureEncoding: OAuthJWTSignatureEncoding = .joseInteroperable,
        constraints: OAuthJWTVerificationConstraints = .init()
    ) throws -> OAuthVerifiedJWT {
        let parsed = try parse(compact)
        guard parsed.header.algorithm == key.signingAlgorithm.rawValue,
              expectedType == nil || parsed.header.type == expectedType
        else {
            throw OAuthServerError.unauthorized("JWT type or algorithm is invalid")
        }
        guard key.isValidSignature(parsed.signature, for: parsed.signingInput, encoding: signatureEncoding) else {
            throw OAuthServerError.unauthorized("JWT signature is invalid")
        }
        let registered = try strictDecode(OAuthJWTRegisteredClaims.self, from: parsed.payload)
        try validate(registered, constraints: constraints)
        return OAuthVerifiedJWT(header: parsed.header, payload: parsed.payload, registeredClaims: registered)
    }

    /// Decodes profile-specific claims from a verified token, rejecting
    /// duplicate member names.
    public static func decodeClaims<Claims: Decodable>(
        _ type: Claims.Type,
        from token: OAuthVerifiedJWT
    ) throws -> Claims {
        try strictDecode(type, from: token.payload)
    }

    /// Signs a claims document and returns the compact serialization.
    ///
    /// The header's `alg` is always the key's algorithm; `kid` defaults to the
    /// key's identifier.
    ///
    /// - Parameters:
    ///   - claims: the payload. Encoded with sorted keys so the output is a
    ///     deterministic function of the input apart from the signature.
    ///   - key: the private signing key.
    ///   - type: the header's `typ`.
    ///   - embedsPublicKey: when true the header carries the public `jwk`, as a
    ///     DPoP proof does, and no `kid`.
    public static func sign(
        _ claims: some Encodable,
        with key: OAuthSigningKey,
        type: String? = nil,
        embedsPublicKey: Bool = false
    ) throws -> String {
        let header = OAuthJWTHeader(
            algorithm: key.algorithm,
            type: type,
            keyID: embedsPublicKey ? nil : key.keyID,
            jwk: embedsPublicKey ? try key.publicKey(includingKeyID: false) : nil
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let headerData: Data
        let payloadData: Data
        do {
            headerData = try encoder.encode(header)
            payloadData = try encoder.encode(claims)
        } catch {
            throw OAuthServerError.malformed("JWT claims cannot be encoded")
        }
        let signingInput = "\(JWTBase64URL.encode(headerData)).\(JWTBase64URL.encode(payloadData))"
        let signature = try key.signature(for: Data(signingInput.utf8))
        return "\(signingInput).\(JWTBase64URL.encode(signature))"
    }

    private struct Parsed: Sendable {
        let header: OAuthJWTHeader
        let payload: Data
        let signingInput: Data
        let signature: Data
    }

    private static func parse(_ compact: String) throws -> Parsed {
        guard compact.utf8.count <= maximumCompactBytes else {
            throw OAuthServerError.malformed("JWT is too large")
        }
        let parts = compact.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3 else { throw OAuthServerError.malformed("JWT must be compact serialization") }
        let headerData = try decodeSegment(parts[0], maxBytes: 4096)
        let payload = try decodeSegment(parts[1], maxBytes: 16384)
        let signature = try decodeSegment(parts[2], maxBytes: JOSECurveBackend.signatureByteCount)
        guard signature.count == JOSECurveBackend.signatureByteCount else {
            throw OAuthServerError.malformed("JWT signature length is invalid")
        }
        let header = try strictDecode(OAuthJWTHeader.self, from: headerData)
        // Only ordinary compact JWS processing of a JSON payload is
        // implemented. There are no supported critical extensions, and
        // accepting either a `crit` list or an explicit `b64` flag would permit
        // semantics the verifier does not model in its signing input.
        guard header.criticalHeaders == nil, header.base64Payload == nil else {
            throw OAuthServerError.malformed("JWT uses unsupported critical JOSE header semantics")
        }
        return Parsed(
            header: header,
            payload: payload,
            signingInput: Data("\(parts[0]).\(parts[1])".utf8),
            signature: signature
        )
    }

    private static func decodeSegment(_ value: String, maxBytes: Int) throws -> Data {
        do {
            return try JWTBase64URL.decode(value, maxBytes: maxBytes)
        } catch {
            throw OAuthServerError.malformed("invalid base64url value")
        }
    }

    private static func strictDecode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            try StrictJSON.validate(data)
        } catch {
            throw OAuthServerError.malformed("invalid JSON")
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as OAuthServerError {
            throw error
        } catch {
            throw OAuthServerError.malformed("invalid JSON")
        }
    }

    private static func validate(
        _ claims: OAuthJWTRegisteredClaims,
        constraints: OAuthJWTVerificationConstraints
    ) throws {
        guard constraints.clockSkew >= 0, constraints.clockSkew.isFinite else {
            throw OAuthServerError.malformed("JWT clock skew policy is invalid")
        }
        if let expectedIssuer = constraints.expectedIssuer {
            guard claims.issuer == expectedIssuer else { throw OAuthServerError.unauthorized("JWT issuer is invalid") }
        }
        if let expectedAudience = constraints.expectedAudience {
            guard claims.audience?.contains(expectedAudience) == true else {
                throw OAuthServerError.unauthorized("JWT audience is invalid")
            }
        }
        let now = try integerTimestamp(
            constraints.now,
            error: "JWT current time policy is invalid"
        )
        let skew = try integerInterval(
            constraints.clockSkew,
            permitsZero: true,
            error: "JWT clock skew policy is invalid"
        )
        if constraints.requireIssuedAt, claims.issuedAt == nil { throw OAuthServerError.malformed("JWT iat is required") }
        if constraints.requireExpiration, claims.expiresAt == nil { throw OAuthServerError.malformed("JWT exp is required") }
        if let issuedAt = claims.issuedAt {
            let latestIssuedAt = now.addingReportingOverflow(skew)
            guard !latestIssuedAt.overflow else {
                throw OAuthServerError.malformed("JWT time policy is invalid")
            }
            guard issuedAt <= latestIssuedAt.partialValue else {
                throw OAuthServerError.unauthorized("JWT iat is in the future")
            }
            if let maximumAge = constraints.maximumAge {
                let age = try integerInterval(
                    maximumAge,
                    permitsZero: false,
                    error: "JWT maximum age policy is invalid"
                )
                let ageCutoff = now.subtractingReportingOverflow(age)
                guard !ageCutoff.overflow else {
                    throw OAuthServerError.malformed("JWT time policy is invalid")
                }
                let skewedAgeCutoff =
                    ageCutoff.partialValue.subtractingReportingOverflow(skew)
                guard !skewedAgeCutoff.overflow else {
                    throw OAuthServerError.malformed("JWT time policy is invalid")
                }
                guard issuedAt >= skewedAgeCutoff.partialValue else {
                    throw OAuthServerError.expired
                }
            }
        }
        if let notBefore = claims.notBefore {
            let latest = now.addingReportingOverflow(skew)
            guard !latest.overflow else {
                throw OAuthServerError.malformed("JWT time policy is invalid")
            }
            guard notBefore <= latest.partialValue else {
                throw OAuthServerError.unauthorized("JWT is not yet valid")
            }
        }
        if let expiresAt = claims.expiresAt {
            let earliestExpiration = now.subtractingReportingOverflow(skew)
            guard !earliestExpiration.overflow else {
                throw OAuthServerError.malformed("JWT time policy is invalid")
            }
            guard expiresAt >= earliestExpiration.partialValue else {
                throw OAuthServerError.expired
            }
            if let issuedAt = claims.issuedAt {
                guard expiresAt >= issuedAt else { throw OAuthServerError.malformed("JWT exp precedes iat") }
                if let maxLifetime = constraints.maxLifetime {
                    let maximum = try integerInterval(
                        maxLifetime,
                        permitsZero: false,
                        error: "JWT maximum lifetime policy is invalid"
                    )
                    let lifetime =
                        expiresAt.subtractingReportingOverflow(issuedAt)
                    guard !lifetime.overflow,
                          lifetime.partialValue <= maximum else {
                        throw OAuthServerError.unauthorized("JWT lifetime is too long")
                    }
                }
            }
        }
    }

    private static func integerTimestamp(
        _ date: Date,
        error message: String
    ) throws -> Int64 {
        let timestamp = date.timeIntervalSince1970
        // Double(Int64.max) rounds up to 2^63, which cannot be converted back
        // to Int64. Keep that upper bound exclusive.
        guard timestamp.isFinite,
              timestamp >= Double(Int64.min),
              timestamp < Double(Int64.max) else {
            throw OAuthServerError.malformed(message)
        }
        return Int64(timestamp)
    }

    private static func integerInterval(
        _ interval: TimeInterval,
        permitsZero: Bool,
        error message: String
    ) throws -> Int64 {
        guard interval.isFinite,
              (permitsZero ? interval >= 0 : interval > 0),
              interval < Double(Int64.max) else {
            throw OAuthServerError.malformed(message)
        }
        return Int64(interval)
    }
}
