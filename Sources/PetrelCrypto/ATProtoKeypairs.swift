import Crypto
import Foundation

/// An in-memory NIST P-256 (`ES256`) signing key.
///
/// The private scalar is held in ordinary memory (`Data`), which is not
/// zeroed when the value is released; use a hardware-backed signer such as
/// `SecureEnclaveP256Signer` where that matters.
///
/// ```swift
/// let keypair = P256Keypair.generate()
/// let signature = try keypair.sign(Data("hello".utf8))   // 64 bytes, low-S
/// keypair.publicKey.isValidSignature(signature, for: Data("hello".utf8))
/// ```
public struct P256Keypair: ATProtoExportableKeypair, CustomStringConvertible, CustomDebugStringConvertible,
    CustomReflectable
{
    /// The public half of the key.
    public let publicKey: ATProtoPublicKey
    private let rawRepresentation: Data

    /// Generates a new random key with the platform CSPRNG.
    public static func generate() -> P256Keypair {
        P256Keypair(P256.Signing.PrivateKey())
    }

    /// Wraps a Swift Crypto / CryptoKit private key.
    public init(_ privateKey: P256.Signing.PrivateKey) {
        rawRepresentation = privateKey.rawRepresentation
        publicKey = ATProtoPublicKey(privateKey.publicKey)
    }

    /// Imports a private key from its 32-byte big-endian scalar.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)`` unless `0 < d < n`.
    public init(rawRepresentation: Data) throws {
        guard rawRepresentation.count == ECDSAScalar.byteCount,
              let key = try? P256.Signing.PrivateKey(rawRepresentation: rawRepresentation) else {
            throw PetrelCryptoError.malformed("P-256 private key must be a 32-byte scalar in 1 ..< n")
        }
        self.init(key)
    }

    /// Imports a private key from 64 hex characters.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)``.
    public init(hex: String) throws {
        try self.init(rawRepresentation: PrivateKeyEncoding.decode(hex: hex))
    }

    /// Imports a private key from base58btc multibase (`z…`): either a
    /// private multikey with the `p256-priv` multicodec prefix, as
    /// ``ATProtoExportableKeypair/exportMultibase()`` writes, or the bare
    /// 32-byte scalar.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)``;
    ///   ``PetrelCryptoError/unsupportedAlgorithm(_:)`` if the multicodec
    ///   prefix names another curve.
    public init(multibase: String) throws {
        try self.init(rawRepresentation: PrivateKeyEncoding.decode(multibase: multibase, expecting: .p256))
    }

    /// The key as a Swift Crypto / CryptoKit value, for APIs that need one.
    public func privateKey() throws -> P256.Signing.PrivateKey {
        do {
            return try P256.Signing.PrivateKey(rawRepresentation: rawRepresentation)
        } catch {
            throw PetrelCryptoError.malformed("P-256 private key is invalid")
        }
    }

    /// Signs `SHA-256(message)` and returns the 64-byte compact low-S
    /// signature. CryptoKit does not normalize S, so this does.
    public func sign(_ message: Data) throws -> Data {
        try P256WireSignature.sign(message, using: privateKey())
    }

    /// The 32-byte big-endian private scalar.
    public func exportRawRepresentation() -> Data { rawRepresentation }

    /// The public `did:key`. The private scalar is never printed.
    public var description: String { "P256Keypair(\(publicKey.didKey))" }
    /// Same as ``description``.
    public var debugDescription: String { description }
    /// Only the public key: `dump` and `Mirror` never reach the private scalar.
    public var customMirror: Mirror {
        Mirror(self, children: ["publicKey": publicKey.didKey], displayStyle: .struct)
    }
}

/// An in-memory secp256k1 (`ES256K`) signing key — the curve the reference
/// implementation uses by default for new keys.
///
/// The private scalar is held in ordinary memory (`Data`), which is not
/// zeroed when the value is released.
///
/// ```swift
/// let keypair = K256Keypair.generate()
/// let signature = try keypair.sign(Data("hello".utf8))   // 64 bytes, low-S
/// keypair.publicKey.isValidSignature(signature, for: Data("hello".utf8))
/// ```
public struct K256Keypair: ATProtoExportableKeypair, CustomStringConvertible, CustomDebugStringConvertible,
    CustomReflectable
{
    /// The public half of the key.
    public let publicKey: ATProtoPublicKey
    private let rawRepresentation: Data

    /// Generates a new random key: 32 bytes from the platform CSPRNG,
    /// redrawn in the (probability about 2^-128) case that libsecp256k1 does not
    /// accept them as a scalar in `1 ..< n`.
    public static func generate() -> K256Keypair {
        while true {
            if let keypair = try? K256Keypair(rawRepresentation: ATProtoCrypto.randomBytes(count: ECDSAScalar.byteCount)) {
                return keypair
            }
        }
    }

    /// Imports a private key from its 32-byte big-endian scalar.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)`` unless `0 < d < n`.
    public init(rawRepresentation: Data) throws {
        let compressed = try K256Backend.compressedPublicKey(forPrivateKey: rawRepresentation)
        publicKey = try ATProtoPublicKey(curve: .k256, sec1Representation: compressed)
        self.rawRepresentation = Data(rawRepresentation)
    }

    /// Imports a private key from 64 hex characters.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)``.
    public init(hex: String) throws {
        try self.init(rawRepresentation: PrivateKeyEncoding.decode(hex: hex))
    }

    /// Imports a private key from base58btc multibase (`z…`): either a
    /// private multikey with the `secp256k1-priv` multicodec prefix, as
    /// ``ATProtoExportableKeypair/exportMultibase()`` writes, or the bare
    /// 32-byte scalar.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)``;
    ///   ``PetrelCryptoError/unsupportedAlgorithm(_:)`` if the multicodec
    ///   prefix names another curve.
    public init(multibase: String) throws {
        try self.init(rawRepresentation: PrivateKeyEncoding.decode(multibase: multibase, expecting: .k256))
    }

    /// Signs `SHA-256(message)` with deterministic (RFC 6979) ECDSA and
    /// returns the 64-byte compact low-S signature.
    public func sign(_ message: Data) throws -> Data {
        try K256Backend.sign(message: message, privateKey: rawRepresentation)
    }

    /// The 32-byte big-endian private scalar.
    public func exportRawRepresentation() -> Data { rawRepresentation }

    /// The public `did:key`. The private scalar is never printed.
    public var description: String { "K256Keypair(\(publicKey.didKey))" }
    /// Same as ``description``.
    public var debugDescription: String { description }
    /// Only the public key: `dump` and `Mirror` never reach the private scalar.
    public var customMirror: Mirror {
        Mirror(self, children: ["publicKey": publicKey.didKey], displayStyle: .struct)
    }
}

/// Private-key string encodings shared by both curves.
enum PrivateKeyEncoding {
    static func decode(hex: String) throws -> Data {
        guard hex.utf8.count == 2 * ECDSAScalar.byteCount, let bytes = Hex.decode(hex) else {
            throw PetrelCryptoError.malformed("private key hex must be 64 hex characters")
        }
        return bytes
    }

    /// Returns the curve named by a private multikey's multicodec prefix, or
    /// `nil` for a bare 32-byte scalar, together with the scalar.
    static func decode(multibase: String) throws -> (curve: ATProtoKeyCurve?, scalar: Data) {
        guard multibase.hasPrefix("z"), multibase.utf8.count <= 128 else {
            throw PetrelCryptoError.malformed("private key multibase must be base58btc with a z prefix")
        }
        let encoded = String(multibase.dropFirst())
        guard let decoded = try? Base58BTC.decode(encoded), Base58BTC.encode(decoded) == encoded else {
            throw PetrelCryptoError.malformed("private key multibase is not canonical base58btc")
        }
        switch decoded.count {
        case ECDSAScalar.byteCount:
            return (nil, decoded)
        case ECDSAScalar.byteCount + 2:
            guard let curve = ATProtoKeyCurve.allCases.first(where: {
                decoded.prefix(2) == $0.privateKeyMulticodecPrefix
            }) else {
                throw PetrelCryptoError.unsupportedAlgorithm("private multikey is not a P-256 or K-256 key")
            }
            return (curve, Data(decoded.dropFirst(2)))
        default:
            throw PetrelCryptoError.malformed("private key multibase has the wrong length")
        }
    }

    static func decode(multibase: String, expecting expected: ATProtoKeyCurve) throws -> Data {
        let (curve, scalar) = try decode(multibase: multibase)
        if let curve, curve != expected {
            throw PetrelCryptoError.unsupportedAlgorithm(
                "private multikey is a \(curve.rawValue) key, expected \(expected.rawValue)"
            )
        }
        return scalar
    }
}
