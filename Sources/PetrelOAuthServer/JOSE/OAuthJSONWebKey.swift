import Crypto
import Foundation
import PetrelCrypto

/// The JWS signature algorithms the AT Protocol OAuth profile uses.
///
/// `ES256` is mandatory for every party; `ES256K` is the other curve AT
/// Protocol identities use and is accepted wherever a client may choose its
/// own key.
public enum OAuthJWSAlgorithm: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    /// ECDSA over NIST P-256 with SHA-256.
    case es256 = "ES256"
    /// ECDSA over secp256k1 with SHA-256.
    case es256k = "ES256K"

    /// The curve a key must live on to produce this algorithm's signatures.
    public var curve: OAuthJSONWebKey.Curve {
        switch self {
        case .es256: .p256
        case .es256k: .secp256k1
        }
    }
}

/// A public elliptic-curve JSON Web Key (RFC 7517) on P-256 or secp256k1.
///
/// Only public material is representable: decoding a JWK that carries the
/// private scalar `d` fails, so a private key published by mistake is refused
/// at the trust boundary instead of being silently used as a public key.
public struct OAuthJSONWebKey: Codable, Sendable, Equatable, Hashable {
    /// The curves this type models, by their JWK `crv` name.
    public enum Curve: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
        /// NIST P-256 (`secp256r1`).
        case p256 = "P-256"
        /// secp256k1.
        case secp256k1

        /// The JWS algorithm keys on this curve sign with.
        public var algorithm: OAuthJWSAlgorithm {
            switch self {
            case .p256: .es256
            case .secp256k1: .es256k
            }
        }
    }

    /// The curve the key lives on (`crv`).
    public let curve: Curve
    /// The base64url x coordinate, exactly 32 bytes when decoded.
    public let x: String
    /// The base64url y coordinate, exactly 32 bytes when decoded.
    public let y: String
    /// The key identifier (`kid`), when the key has one.
    public let keyID: String?
    /// The declared algorithm (`alg`). When present it equals the curve's
    /// algorithm.
    public let algorithm: OAuthJWSAlgorithm?
    /// The declared public key use (`use`). When present it is `sig`.
    public let use: String?

    /// The algorithm this key verifies, derived from its curve.
    public var signingAlgorithm: OAuthJWSAlgorithm { curve.algorithm }

    /// Creates a validated public key.
    ///
    /// - Throws: ``OAuthServerError/malformed(_:)`` when a coordinate is not
    ///   canonical base64url for 32 bytes, the point is not on the curve, `alg`
    ///   names a different curve, or `use` is not `sig`.
    public init(
        curve: Curve = .p256,
        x: String,
        y: String,
        keyID: String? = nil,
        algorithm: OAuthJWSAlgorithm? = nil,
        use: String? = nil
    ) throws {
        guard algorithm == nil || algorithm == curve.algorithm, use == nil || use == "sig" else {
            throw OAuthServerError.malformed("unsupported JWK parameters")
        }
        if let keyID {
            guard !keyID.isEmpty, keyID.utf8.count <= 1024, !keyID.utf8.contains(0) else {
                throw OAuthServerError.malformed("JWK kid is invalid")
            }
        }
        let xBytes = try Self.decodeCoordinate(x)
        let yBytes = try Self.decodeCoordinate(y)
        guard JOSECurveBackend.isValidPublicPoint(curve: curve, x: xBytes, y: yBytes) else {
            throw OAuthServerError.malformed("JWK point is not on the curve")
        }
        self.curve = curve
        self.x = x
        self.y = y
        self.keyID = keyID
        self.algorithm = algorithm
        self.use = use
    }

    private enum CodingKeys: String, CodingKey {
        case keyType = "kty"
        case curve = "crv"
        case x, y
        case keyID = "kid"
        case algorithm = "alg"
        case use
        case privateScalar = "d"
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard !values.contains(.privateScalar) else {
            throw OAuthServerError.malformed("private JWK material is not accepted")
        }
        guard try values.decode(String.self, forKey: .keyType) == "EC",
              let curve = try Curve(rawValue: values.decode(String.self, forKey: .curve))
        else {
            throw OAuthServerError.malformed("unsupported JWK key type or curve")
        }
        var algorithm: OAuthJWSAlgorithm?
        if let name = try values.decodeIfPresent(String.self, forKey: .algorithm) {
            guard let known = OAuthJWSAlgorithm(rawValue: name) else {
                throw OAuthServerError.malformed("unsupported JWK parameters")
            }
            algorithm = known
        }
        try self.init(
            curve: curve,
            x: values.decode(String.self, forKey: .x),
            y: values.decode(String.self, forKey: .y),
            keyID: values.decodeIfPresent(String.self, forKey: .keyID),
            algorithm: algorithm,
            use: values.decodeIfPresent(String.self, forKey: .use)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode("EC", forKey: .keyType)
        try values.encode(curve, forKey: .curve)
        try values.encode(x, forKey: .x)
        try values.encode(y, forKey: .y)
        try values.encodeIfPresent(keyID, forKey: .keyID)
        try values.encodeIfPresent(algorithm, forKey: .algorithm)
        try values.encodeIfPresent(use, forKey: .use)
    }

    /// The RFC 7638 SHA-256 thumbprint (`jkt`) over the required members
    /// `crv`, `kty`, `x`, `y` in lexicographic order.
    ///
    /// The coordinates were validated as canonical base64url, so they contain
    /// no character that needs JSON escaping.
    public func thumbprint() -> String {
        let canonical = "{\"crv\":\"\(curve.rawValue)\",\"kty\":\"EC\",\"x\":\"\(x)\",\"y\":\"\(y)\"}"
        return JWTBase64URL.encode(Data(SHA256.hash(data: Data(canonical.utf8))))
    }

    /// Verifies a 64-byte JWS `r || s` signature over `signingInput`.
    ///
    /// - Parameters:
    ///   - signature: the 64-byte `r || s` signature.
    ///   - signingInput: the bytes that were signed (hashed with SHA-256 here).
    ///   - encoding: whether a high-S signature is acceptable. See
    ///     ``OAuthJWTSignatureEncoding``.
    public func isValidSignature(
        _ signature: Data,
        for signingInput: Data,
        encoding: OAuthJWTSignatureEncoding = .joseInteroperable
    ) -> Bool {
        guard let xBytes = try? Self.decodeCoordinate(x), let yBytes = try? Self.decodeCoordinate(y) else {
            return false
        }
        return JOSECurveBackend.verify(
            curve: curve,
            x: xBytes,
            y: yBytes,
            signature: signature,
            signingInput: signingInput,
            acceptsHighS: encoding == .joseInteroperable
        )
    }

    private static func decodeCoordinate(_ value: String) throws -> Data {
        guard let decoded = try? JWTBase64URL.decode(value, maxBytes: JOSECurveBackend.coordinateByteCount),
              decoded.count == JOSECurveBackend.coordinateByteCount
        else {
            throw OAuthServerError.malformed("JWK coordinate must be exactly 32 bytes of base64url")
        }
        return decoded
    }
}

/// A JSON Web Key Set (RFC 7517 §5) reduced to the keys this library can
/// verify with.
///
/// Key selection is fail-closed: a `kid` must match exactly one key, and an
/// absent `kid` works only when the set holds a single key. Nothing ever
/// "picks the first" of several candidates.
public struct OAuthJSONWebKeySet: Codable, Sendable, Equatable {
    /// The usable signature-verification keys, in document order.
    public let keys: [OAuthJSONWebKey]

    private enum CodingKeys: String, CodingKey {
        case keys
    }

    /// Creates a key set.
    ///
    /// - Throws: ``OAuthServerError/malformed(_:)`` when the set is empty,
    ///   holds more than 64 keys, or repeats a `kid`.
    public init(keys: [OAuthJSONWebKey]) throws {
        guard !keys.isEmpty, keys.count <= 64 else {
            throw OAuthServerError.malformed("JWKS key count is invalid")
        }
        let named = keys.compactMap(\.keyID)
        guard named.count == Set(named).count else {
            throw OAuthServerError.malformed("JWKS contains duplicate kid values")
        }
        self.keys = keys
    }

    /// Decodes a JWKS document.
    ///
    /// Keys of a type this library does not verify with (RSA, OKP, other
    /// curves, encryption keys) are skipped, because a client may publish them
    /// for other purposes. Private key material anywhere in the set fails the
    /// whole document.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        var entries = try values.nestedUnkeyedContainer(forKey: .keys)
        var usable: [OAuthJSONWebKey] = []
        var count = 0
        while !entries.isAtEnd {
            count += 1
            guard count <= 64 else { throw OAuthServerError.malformed("JWKS key count is invalid") }
            let probe = try entries.decode(KeyProbe.self)
            guard !probe.hasPrivateMaterial else {
                throw OAuthServerError.malformed("private JWK material is not accepted")
            }
            if let key = probe.key { usable.append(key) }
        }
        try self.init(keys: usable)
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(keys, forKey: .keys)
    }

    /// Selects the verification key for a JWS header's `kid`.
    ///
    /// - Throws: ``OAuthServerError/unauthorized(_:)`` when no key, or more
    ///   than one candidate, matches.
    public func select(keyID: String?) throws -> OAuthJSONWebKey {
        if let keyID {
            guard let key = keys.first(where: { $0.keyID == keyID }) else {
                throw OAuthServerError.unauthorized("JWT kid is not present in JWKS")
            }
            return key
        }
        guard keys.count == 1, let key = keys.first else {
            throw OAuthServerError.unauthorized("JWT key selection is ambiguous")
        }
        return key
    }

    /// Decodes a fetched JWKS after rejecting duplicate JSON member names.
    public static func decodeValidated(_ data: Data) throws -> Self {
        do {
            return try StrictJSON.decode(Self.self, from: data)
        } catch let error as OAuthServerError {
            throw error
        } catch {
            throw OAuthServerError.malformed("JWKS document is invalid")
        }
    }

    /// One JWKS entry: either a key this library verifies with, or a key of
    /// another kind that is skipped.
    private struct KeyProbe: Decodable {
        let key: OAuthJSONWebKey?
        let hasPrivateMaterial: Bool

        private enum CodingKeys: String, CodingKey {
            case keyType = "kty"
            case curve = "crv"
            case use
            case d, p, q, dp, dq, qi, k
        }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            hasPrivateMaterial = [CodingKeys.d, .p, .q, .dp, .dq, .qi, .k].contains { values.contains($0) }
            guard !hasPrivateMaterial else {
                key = nil
                return
            }
            let keyType = try values.decode(String.self, forKey: .keyType)
            let curve = try values.decodeIfPresent(String.self, forKey: .curve)
            let use = try values.decodeIfPresent(String.self, forKey: .use)
            guard keyType == "EC", let curve, OAuthJSONWebKey.Curve(rawValue: curve) != nil,
                  use == nil || use == "sig"
            else {
                key = nil
                return
            }
            // A key of a supported kind must itself be valid: a malformed
            // P-256 key is an error, not something to skip past.
            key = try OAuthJSONWebKey(from: decoder)
        }
    }
}
