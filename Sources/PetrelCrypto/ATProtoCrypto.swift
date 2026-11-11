import Crypto
import Foundation

/// Curve-agnostic entry points for AT Protocol cryptography: one-call
/// signature verification, key generation and import, and the hash and
/// random helpers the protocol uses.
///
/// ```swift
/// let keypair = ATProtoCrypto.generateKeypair()            // K-256 by default
/// let signature = try await keypair.sign(bytes)
/// let ok = try ATProtoCrypto.verifySignature(
///     didKey: keypair.didKey, data: bytes, signature: signature
/// )
/// ```
public enum ATProtoCrypto {
    // MARK: Verification

    /// Verifies `signature` over `SHA-256(data)` against a `did:key`.
    ///
    /// The curve is taken from the `did:key`. Verification is strict by
    /// default: only a 64-byte compact low-S signature can return `true`.
    /// Pass ``ATProtoSignatureVerificationOptions/jwt`` when checking a JWT
    /// signature, which the specification exempts from the low-S rule.
    ///
    /// - Parameters:
    ///   - didKey: The signer's public key as `did:key:z…`.
    ///   - data: The signed bytes, unhashed.
    ///   - signature: The signature bytes.
    ///   - options: Encoding policy; defaults to strict.
    ///   - expectedJWTAlgorithm: If set (`ES256` / `ES256K`), the key must be
    ///     on the matching curve.
    /// - Returns: `false` for a wrong, malformed or non-canonical signature.
    /// - Throws: ``PetrelCryptoError/invalidIdentifier(_:)`` if `didKey` is
    ///   not a P-256 or K-256 `did:key`;
    ///   ``PetrelCryptoError/unsupportedAlgorithm(_:)`` if the key's curve
    ///   does not match `expectedJWTAlgorithm`.
    public static func verifySignature(
        didKey: String,
        data: Data,
        signature: Data,
        options: ATProtoSignatureVerificationOptions = .strict,
        expectedJWTAlgorithm: String? = nil
    ) throws -> Bool {
        let key = try ATProtoPublicKey(didKey: didKey)
        if let expectedJWTAlgorithm, expectedJWTAlgorithm != key.jwtAlgorithm {
            throw PetrelCryptoError.unsupportedAlgorithm(
                "expected key algorithm \(expectedJWTAlgorithm), got \(key.jwtAlgorithm)"
            )
        }
        return key.isValidSignature(signature, for: data, options: options)
    }

    // MARK: Keys

    /// Generates a new in-memory keypair. Defaults to K-256, like the
    /// reference implementation.
    public static func generateKeypair(curve: ATProtoKeyCurve = .k256) -> any ATProtoExportableKeypair {
        switch curve {
        case .p256: return P256Keypair.generate()
        case .k256: return K256Keypair.generate()
        }
    }

    /// Imports a keypair from its 32-byte private scalar.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)`` unless `0 < d < n`.
    public static func importKeypair(
        curve: ATProtoKeyCurve,
        rawRepresentation: Data
    ) throws -> any ATProtoExportableKeypair {
        switch curve {
        case .p256: return try P256Keypair(rawRepresentation: rawRepresentation)
        case .k256: return try K256Keypair(rawRepresentation: rawRepresentation)
        }
    }

    /// Imports a keypair from 64 hex characters.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)``.
    public static func importKeypair(
        curve: ATProtoKeyCurve,
        hex: String
    ) throws -> any ATProtoExportableKeypair {
        try importKeypair(curve: curve, rawRepresentation: PrivateKeyEncoding.decode(hex: hex))
    }

    /// Imports a keypair from a private multikey (`z` + base58btc of the
    /// `p256-priv` or `secp256k1-priv` multicodec prefix and the scalar),
    /// choosing the curve from the prefix.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)`` if the value has no
    ///   multicodec prefix — a bare scalar does not say which curve it is
    ///   for; use ``P256Keypair/init(multibase:)`` or
    ///   ``K256Keypair/init(multibase:)`` for those.
    public static func importKeypair(privateMultibase: String) throws -> any ATProtoExportableKeypair {
        let (curve, scalar) = try PrivateKeyEncoding.decode(multibase: privateMultibase)
        guard let curve else {
            throw PetrelCryptoError.malformed("private key multibase has no multicodec prefix naming its curve")
        }
        return try importKeypair(curve: curve, rawRepresentation: scalar)
    }

    // MARK: Hashing and randomness

    /// SHA-256 of `data`, as 32 raw bytes.
    public static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    /// SHA-256 of `data`, as 64 lowercase hex characters.
    public static func sha256Hex(_ data: Data) -> String {
        Hex.encode(SHA256.hash(data: data))
    }

    /// `count` bytes from the platform's cryptographically secure generator
    /// (`SystemRandomNumberGenerator`: `arc4random_buf` on Apple platforms,
    /// `getrandom(2)` on Linux).
    public static func randomBytes(count: Int) -> Data {
        precondition(count >= 0, "byte count must not be negative")
        var generator = SystemRandomNumberGenerator()
        var bytes = [UInt8](repeating: 0, count: count)
        for index in bytes.indices {
            bytes[index] = UInt8.random(in: .min ... .max, using: &generator)
        }
        return Data(bytes)
    }
}
