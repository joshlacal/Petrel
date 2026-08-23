import Crypto
import Foundation

/// Canonical raw P-256 signatures used by ATProto wire protocols.
///
/// P-256 ECDSA admits a second, equally valid signature for every message:
/// `(r, n - s)`. AT Protocol's ES256 and signed space context are serialized as a
/// fixed-width `r || s` value, so accepting both encodings would make those
/// wire values malleable. This boundary emits only low-S values and rejects
/// high-S values *before* asking Swift Crypto to verify them.
public enum P256WireSignature {
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

        let s = Data(rawRepresentation.suffix(32))
        guard compare(s, halfOrder) == .orderedDescending else {
            return rawRepresentation
        }

        var normalized = rawRepresentation
        normalized.replaceSubrange(32 ..< 64, with: subtract(s, from: order))
        return normalized
    }

    /// Rejects non-canonical raw P-256 values before creating the signature
    /// object passed to the cryptographic verifier.
    public static func decodeCanonical(_ rawRepresentation: Data) throws -> P256.Signing.ECDSASignature {
        try validateScalars(rawRepresentation)
        guard compare(Data(rawRepresentation.suffix(32)), halfOrder) != .orderedDescending else {
            throw PetrelCryptoError.malformed("P-256 signature is not canonical low-S")
        }
        return try decode(rawRepresentation)
    }

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
    /// assertions and DPoP proofs are replay-protected by `jti`, and a
    /// malleated variant carries the same `jti`, so it is caught by the
    /// existing claim. These tokens are never used as content addresses.
    /// Structural scalar validation still applies, and AT Protocol's own
    /// signature suites — PLC operations, repository commits, service JWTs —
    /// keep using ``decodeCanonical(_:)`` because their wire values *are*
    /// canonical and malleability there would be observable.
    public static func decodeMalleabilityTolerant(
        _ rawRepresentation: Data
    ) throws -> P256.Signing.ECDSASignature {
        try validateScalars(rawRepresentation)
        return try decode(rawRepresentation)
    }

    private static let order = Data([
        0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xbc, 0xe6, 0xfa, 0xad, 0xa7, 0x17, 0x9e, 0x84,
        0xf3, 0xb9, 0xca, 0xc2, 0xfc, 0x63, 0x25, 0x51,
    ])

    private static let halfOrder = Data([
        0x7f, 0xff, 0xff, 0xff, 0x80, 0x00, 0x00, 0x00,
        0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xde, 0x73, 0x7d, 0x56, 0xd3, 0x8b, 0xcf, 0x42,
        0x79, 0xdc, 0xd6, 0x61, 0x7e, 0x31, 0x92, 0xa8,
    ])

    private static func validateScalars(_ rawRepresentation: Data) throws {
        guard rawRepresentation.count == rawByteCount else {
            throw PetrelCryptoError.malformed("P-256 signature must be 64 bytes")
        }
        let r = Data(rawRepresentation.prefix(32))
        let s = Data(rawRepresentation.suffix(32))
        guard isValidScalar(r), isValidScalar(s) else {
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

    private static func isValidScalar(_ scalar: Data) -> Bool {
        scalar.count == 32 && scalar.contains(where: { $0 != 0 }) && compare(scalar, order) == .orderedAscending
    }

    private static func compare(_ lhs: Data, _ rhs: Data) -> ComparisonResult {
        precondition(lhs.count == rhs.count)
        for (left, right) in zip(lhs, rhs) {
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }
        return .orderedSame
    }

    /// Computes `minuend - subtrahend`, whose caller has already proven does
    /// not underflow. Both values are fixed-width big-endian scalar bytes.
    private static func subtract(_ subtrahend: Data, from minuend: Data) -> Data {
        precondition(subtrahend.count == 32 && minuend.count == 32)
        let minuendBytes = Array(minuend)
        let subtrahendBytes = Array(subtrahend)
        var result = Array(repeating: UInt8.zero, count: 32)
        var borrow = 0
        for index in stride(from: 31, through: 0, by: -1) {
            var value = Int(minuendBytes[index]) - Int(subtrahendBytes[index]) - borrow
            if value < 0 {
                value += 256
                borrow = 1
            } else {
                borrow = 0
            }
            result[index] = UInt8(value)
        }
        precondition(borrow == 0)
        return Data(result)
    }
}
