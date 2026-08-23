import Crypto
import Foundation
import secp256k1

/// A bounded public key selected from a local account projection or an
/// operator-pinned interop fixture. P-256 remains the local issuance
/// format, while the reference TypeScript PDS produces compact low-S secp256k1
/// JWT signatures (`ES256K`). Keeping only raw secp256k1 public bytes here
/// makes the key material `Sendable` and avoids a request path retaining a
/// mutable C crypto context.
public enum ATProtoJWTVerificationKey: Sendable, Equatable {
    case p256(P256.Signing.PublicKey)
    case secp256k1PublicKey(Data)

    /// Creates a pinned secp256k1 verification key from the compressed or
    /// uncompressed public bytes used by the reference TypeScript PDS.
    /// Private key material is never accepted by this API.
    public init(secp256k1PublicKey: Data) throws {
        guard Self.validatesSecp256k1PublicKey(secp256k1PublicKey) else {
            throw PetrelCryptoError.malformed("invalid secp256k1 public key")
        }
        self = .secp256k1PublicKey(secp256k1PublicKey)
    }

    public init(_ key: PLCDIDVerificationKey) {
        switch key {
        case let .p256(publicKey):
            self = .p256(publicKey)
        case let .secp256k1(bytes):
            self = .secp256k1PublicKey(bytes)
        }
    }

    /// Verifies one compact signature with the algorithm bound to this
    /// pinned public-key representation.
    public func verify(
        signature: Data,
        signingInput: Data,
        algorithm: String
    ) throws -> Bool {
        try verifies(signature: signature, signingInput: signingInput, algorithm: algorithm)
    }

    public var deterministicIdentity: Data {
        switch self {
        case let .p256(publicKey):
            return Data([0x01]) + publicKey.x963Representation
        case let .secp256k1PublicKey(encoded):
            return Data([0x02]) + encoded
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
            let format: secp256k1.Format
            switch (encoded.count, encoded.first) {
            case (33, 0x02), (33, 0x03):
                format = .compressed
            case (65, 0x04):
                format = .uncompressed
            default:
                throw PetrelCryptoError.unauthorized("secp256k1 public key is invalid")
            }
            do {
                let publicKey = try secp256k1.Signing.PublicKey(
                    dataRepresentation: encoded,
                    format: format
                )
                let compact = try secp256k1.Signing.ECDSASignature(
                    compactRepresentation: signature
                )
                return publicKey.isValidSignature(compact, for: signingInput)
            } catch {
                throw PetrelCryptoError.unauthorized("secp256k1 JWT verification failed")
            }
        }
    }

    public static func validatesSecp256k1PublicKey(_ encoded: Data) -> Bool {
        do {
            let format: secp256k1.Format
            switch (encoded.count, encoded.first) {
            case (33, 0x02), (33, 0x03):
                format = .compressed
            case (65, 0x04):
                format = .uncompressed
            default:
                return false
            }
            _ = try secp256k1.Signing.PublicKey(
                dataRepresentation: encoded,
                format: format
            )
            return true
        } catch {
            return false
        }
    }

    /// Both the TypeScript `@noble/curves` implementation and ATProto reject
    /// malleable high-S compact signatures. secp256k1's group-order half is
    /// encoded as a big-endian 32-byte integer for a constant-size lexical
    /// comparison of the S half of `r || s`.
    public static func isCanonicalSecp256k1Signature(_ signature: Data) -> Bool {
        let bytes = Array(signature)
        guard bytes.count == 64 else { return false }
        let halfOrder: [UInt8] = [
            0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
            0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
            0x5d, 0x57, 0x6e, 0x73, 0x57, 0xa4, 0x50, 0x1d,
            0xdf, 0xe9, 0x2f, 0x46, 0x68, 0x1b, 0x20, 0xa0,
        ]
        let s = bytes[32...]
        guard s.contains(where: { $0 != 0 }) else { return false }
        for (value, maximum) in zip(s, halfOrder) {
            if value != maximum { return value < maximum }
        }
        return true
    }

    public static func == (lhs: ATProtoJWTVerificationKey, rhs: ATProtoJWTVerificationKey) -> Bool {
        lhs.deterministicIdentity == rhs.deterministicIdentity
    }
}

public typealias PermissionedDataJWTVerificationKey = ATProtoJWTVerificationKey
public typealias JWTVerificationKey = ATProtoJWTVerificationKey
