import Crypto
import Foundation

/// A bounded public key selected from a local account projection or an
/// operator-pinned interop fixture. P-256 remains the local issuance
/// format, while the reference TypeScript PDS produces compact low-S secp256k1
/// JWT signatures (`ES256K`). Keeping only raw secp256k1 public bytes here
/// avoids retaining a mutable C crypto context. Swift Crypto 3.x's P-256
/// public key is immutable but lacks a Linux `Sendable` annotation.
///
/// New code should prefer ``ATProtoPublicKey``, which is validated at
/// construction and holds one canonical encoding for both curves; convert
/// with `init(_:)` and ``publicKey()``.
public enum ATProtoJWTVerificationKey: @unchecked Sendable, Equatable {
    case p256(P256.Signing.PublicKey)
    /// A secp256k1 SEC1 point. Build this with
    /// ``init(secp256k1PublicKey:)``, which validates the point and stores
    /// it compressed; a hand-built case is validated when it is used.
    case secp256k1PublicKey(Data)

    /// Creates a pinned secp256k1 verification key from the compressed or
    /// uncompressed public bytes used by the reference TypeScript PDS.
    /// The point is validated and stored compressed, so the same key has
    /// the same identity whichever encoding it arrived in.
    /// Private key material is never accepted by this API.
    public init(secp256k1PublicKey: Data) throws {
        guard let compressed = try? K256Backend.compressedPublicKey(fromSEC1: secp256k1PublicKey) else {
            throw PetrelCryptoError.malformed("invalid secp256k1 public key")
        }
        self = .secp256k1PublicKey(compressed)
    }

    public init(_ key: PLCDIDVerificationKey) {
        switch key {
        case let .p256(publicKey):
            self = .p256(publicKey)
        case let .secp256k1(bytes):
            self = .secp256k1PublicKey(bytes)
        }
    }

    /// Wraps a validated ``ATProtoPublicKey``.
    ///
    /// - Throws: Never for a value built by ``ATProtoPublicKey``'s own
    ///   initializers; the error path exists because the P-256 point is
    ///   re-parsed into a Swift Crypto key.
    public init(_ key: ATProtoPublicKey) throws {
        switch key.curve {
        case .p256: self = try .p256(key.p256Key())
        case .k256: self = .secp256k1PublicKey(key.compressedRepresentation)
        }
    }

    /// The same key as a validated, curve-tagged ``ATProtoPublicKey``.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)`` if a hand-built
    ///   `.secp256k1PublicKey` case holds bytes that are not a curve point.
    public func publicKey() throws -> ATProtoPublicKey {
        switch self {
        case let .p256(publicKey):
            return ATProtoPublicKey(publicKey)
        case let .secp256k1PublicKey(encoded):
            return try ATProtoPublicKey(curve: .k256, sec1Representation: encoded)
        }
    }

    /// Verifies one compact signature with the algorithm bound to this
    /// pinned public-key representation. Strict: a high-S or non-compact
    /// signature is an error. Use ``verify(signature:signingInput:algorithm:options:)``
    /// with ``ATProtoSignatureVerificationOptions/jwt`` for JWTs.
    public func verify(
        signature: Data,
        signingInput: Data,
        algorithm: String
    ) throws -> Bool {
        try verifies(signature: signature, signingInput: signingInput, algorithm: algorithm)
    }

    /// Verifies a signature under an explicit encoding policy.
    ///
    /// With ``ATProtoSignatureVerificationOptions/strict`` this is exactly
    /// ``verify(signature:signingInput:algorithm:)``. With a laxer policy a
    /// signature the policy does not admit, or that fails the ECDSA check,
    /// returns `false`.
    ///
    /// - Throws: ``PetrelCryptoError/unauthorized(_:)`` if `algorithm` does
    ///   not match the key's curve or the key bytes are invalid.
    public func verify(
        signature: Data,
        signingInput: Data,
        algorithm: String,
        options: ATProtoSignatureVerificationOptions
    ) throws -> Bool {
        guard options != .strict else {
            return try verifies(signature: signature, signingInput: signingInput, algorithm: algorithm)
        }
        guard let key = try? publicKey() else {
            throw PetrelCryptoError.unauthorized("secp256k1 public key is invalid")
        }
        guard algorithm == key.jwtAlgorithm else {
            // Same messages as the strict path, per curve.
            switch key.curve {
            case .p256: throw PetrelCryptoError.unauthorized("JWT algorithm does not match verification key")
            case .k256: throw PetrelCryptoError.unauthorized("JWT algorithm or signature is invalid")
            }
        }
        return key.isValidSignature(signature, for: signingInput, options: options)
    }

    public var deterministicIdentity: Data {
        switch self {
        case let .p256(publicKey):
            return Data([0x01]) + publicKey.x963Representation
        case let .secp256k1PublicKey(encoded):
            // One identity per key: an uncompressed point hashes as its
            // compressed form. Bytes that are not a point stay as given and
            // fail at verification.
            let canonical = (try? K256Backend.compressedPublicKey(fromSEC1: encoded)) ?? encoded
            return Data([0x02]) + canonical
        }
    }

    /// Stable, non-secret identity used when binding durable evidence to the
    /// exact public key that verified the artifact. The key bytes never leave
    /// this value; only their SHA-256 fingerprint is exposed.
    public var recoveryVerifierIdentity: String {
        "key-sha256:" + Hex.encode(SHA256.hash(data: deterministicIdentity))
    }

    func verifies(
        signature: Data,
        signingInput: Data,
        algorithm: String
    ) throws -> Bool {
        switch self {
        case let .p256(publicKey):
            guard algorithm == "ES256" else {
                throw PetrelCryptoError.unauthorized("JWT algorithm does not match verification key")
            }
            let canonical = try P256WireSignature.decodeCanonical(signature)
            return publicKey.isValidSignature(canonical, for: signingInput)
        case let .secp256k1PublicKey(encoded):
            guard algorithm == "ES256K",
                  Self.isCanonicalSecp256k1Signature(signature) else {
                throw PetrelCryptoError.unauthorized("JWT algorithm or signature is invalid")
            }
            guard let compressed = try? K256Backend.compressedPublicKey(fromSEC1: encoded) else {
                throw PetrelCryptoError.unauthorized("secp256k1 public key is invalid")
            }
            return K256Backend.isValidSignature(
                lowSCompact: signature,
                message: signingInput,
                compressedPublicKey: compressed
            )
        }
    }

    public static func validatesSecp256k1PublicKey(_ encoded: Data) -> Bool {
        (try? K256Backend.compressedPublicKey(fromSEC1: encoded)) != nil
    }

    /// Whether `signature` is a canonical K-256 wire signature: 64 bytes,
    /// `0 < r < n`, `0 < s <= floor(n / 2)`. Both the TypeScript
    /// `@noble/curves` implementation and ATProto reject malleable high-S
    /// compact signatures. Same as
    /// `ATProtoSignature.isCanonical(signature, curve: .k256)`.
    public static func isCanonicalSecp256k1Signature(_ signature: Data) -> Bool {
        ATProtoSignature.isCanonical(signature, curve: .k256)
    }

    public static func == (lhs: ATProtoJWTVerificationKey, rhs: ATProtoJWTVerificationKey) -> Bool {
        lhs.deterministicIdentity == rhs.deterministicIdentity
    }
}

public typealias PermissionedDataJWTVerificationKey = ATProtoJWTVerificationKey
public typealias JWTVerificationKey = ATProtoJWTVerificationKey
