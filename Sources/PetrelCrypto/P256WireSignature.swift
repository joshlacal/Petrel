import Crypto
import Foundation

/// Canonical raw P-256 signatures used by ATProto wire protocols.
///
/// P-256 ECDSA admits a second, equally valid signature for every message:
/// `(r, n - s)`. AT Protocol's ES256 and signed space context are serialized as a
/// fixed-width `r || s` value, so accepting both encodings would make those
/// wire values malleable. This boundary emits only low-S values and rejects
/// high-S values *before* asking Swift Crypto to verify them.
///
/// This is the P-256-specific, Swift Crypto-typed layer. For code that
/// should work on both curves use ``ATProtoSignature``, ``P256Keypair`` /
/// ``K256Keypair`` and ``ATProtoPublicKey``. The low-S threshold itself
/// (`floor(n / 2)`) is shared with K-256 and derived from the group order.
public enum P256WireSignature {
    /// Length of the compact `r || s` encoding.
    public static let rawByteCount = 64

    /// Signs a message using Swift Crypto's P-256 implementation, normalizing
    /// the raw `r || s` representation even if the provider changes its
    /// default signature normalization behavior.
    public static func sign(_ message: Data, using key: P256.Signing.PrivateKey) throws -> Data {
        try canonicalize(try key.signature(for: message).rawRepresentation)
    }

    /// Normalizes a structurally valid raw P-256 signature to low-S form.
    /// This is appropriate only for locally produced signatures. Untrusted
    /// inputs must use ``decodeCanonical(_:)`` instead.
    public static func canonicalize(_ rawRepresentation: Data) throws -> Data {
        try validateScalars(rawRepresentation)
        _ = try decode(rawRepresentation)

        return ECDSAScalar.lowSForm(ofStructurallyValid: rawRepresentation, curve: .p256)
    }

    /// Rejects non-canonical raw P-256 values before creating the signature
    /// object passed to the cryptographic verifier.
    public static func decodeCanonical(_ rawRepresentation: Data) throws -> P256.Signing.ECDSASignature {
        try validateScalars(rawRepresentation)
        guard ECDSAScalar.isLow(rawRepresentation.suffix(32), curve: .p256) else {
            throw PetrelCryptoError.malformed("P-256 signature is not canonical low-S")
        }
        return try decode(rawRepresentation)
    }

    /// Whether `rawRepresentation` is 64 bytes with `0 < r < n` and
    /// `0 < s <= floor(n / 2)`.
    public static func isCanonicalLowS(_ rawRepresentation: Data) -> Bool {
        (try? decodeCanonical(rawRepresentation)) != nil
    }

    /// Decodes a raw P-256 signature for a wire format that does **not**
    /// define a canonical `(r, s)` encoding.
    ///
    /// JOSE is such a format: RFC 7515/7518 specify ES256 verification by
    /// SEC1/X9.62, which accepts `(r, s)` and `(r, n - s)` alike, and
    /// conformant signers emit whichever their ECDSA implementation produced
    /// — roughly half of all signatures are high-S. Rejecting those makes
    /// every OAuth JWT a coin flip rather than a security boundary.
    ///
    /// Malleating a JOSE token here buys an attacker nothing: client
    /// assertions, DPoP proofs and service-auth tokens are replay-protected
    /// by `jti`, and a malleated variant carries the same `jti`, so it is
    /// caught by the existing claim. These tokens are never used as content
    /// addresses. Structural scalar validation still applies. AT Protocol's
    /// signatures over CBOR objects — PLC operations, repository commits,
    /// labels — keep using ``decodeCanonical(_:)``, because the
    /// specification requires verifiers to reject non-low-S values there.
    public static func decodeMalleabilityTolerant(
        _ rawRepresentation: Data
    ) throws -> P256.Signing.ECDSASignature {
        try validateScalars(rawRepresentation)
        return try decode(rawRepresentation)
    }

    private static func validateScalars(_ rawRepresentation: Data) throws {
        guard rawRepresentation.count == rawByteCount else {
            throw PetrelCryptoError.malformed("P-256 signature must be 64 bytes")
        }
        guard ECDSAScalar.isStructurallyValid(compact: rawRepresentation, curve: .p256) else {
            throw PetrelCryptoError.malformed("P-256 signature scalar is invalid")
        }
    }

    private static func decode(_ rawRepresentation: Data) throws -> P256.Signing.ECDSASignature {
        do {
            return try P256.Signing.ECDSASignature(rawRepresentation: rawRepresentation)
        } catch {
            throw PetrelCryptoError.malformed("P-256 signature is malformed")
        }
    }
}
