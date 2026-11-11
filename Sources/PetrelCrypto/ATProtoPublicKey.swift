import Crypto
import Foundation

/// A validated AT Protocol public key on either supported curve.
///
/// The value always holds the 33-byte compressed SEC1 point, proven to be on
/// its curve at construction, so two instances are equal exactly when they
/// denote the same key — whatever encoding they were parsed from.
///
/// ```swift
/// let key = try ATProtoPublicKey(didKey: "did:key:zQ3shqwJEJyMBsBXCWyCBpUBMqxcon9oHB7mCvx4sSpMdLJwc")
/// let ok = key.isValidSignature(signature, for: commitBytes)
/// ```
public struct ATProtoPublicKey: Sendable, Hashable, CustomStringConvertible {
    /// The curve this key is a point on.
    public let curve: ATProtoKeyCurve

    /// The 33-byte compressed SEC1 point (`0x02`/`0x03` followed by X).
    public let compressedRepresentation: Data

    /// Creates a key from a SEC1 point: 33 bytes compressed or 65 bytes
    /// uncompressed (`0x04 || X || Y`). The point is checked against the
    /// curve equation and stored compressed.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)`` if the bytes are not a
    ///   point on `curve`.
    public init(curve: ATProtoKeyCurve, sec1Representation: Data) throws {
        self.curve = curve
        switch curve {
        case .p256:
            do {
                let key: P256.Signing.PublicKey
                switch (sec1Representation.count, sec1Representation.first) {
                case (33, 0x02), (33, 0x03):
                    key = try P256.Signing.PublicKey(compressedRepresentation: sec1Representation)
                case (65, 0x04):
                    key = try P256.Signing.PublicKey(x963Representation: sec1Representation)
                default:
                    throw PetrelCryptoError.malformed("P-256 public key must be a 33- or 65-byte SEC1 point")
                }
                compressedRepresentation = key.compressedRepresentation
            } catch let error as PetrelCryptoError {
                throw error
            } catch {
                throw PetrelCryptoError.malformed("P-256 public key is not a point on the curve")
            }
        case .k256:
            compressedRepresentation = try K256Backend.compressedPublicKey(fromSEC1: sec1Representation)
        }
    }

    /// Wraps a Swift Crypto / CryptoKit P-256 public key.
    public init(_ key: P256.Signing.PublicKey) {
        curve = .p256
        compressedRepresentation = key.compressedRepresentation
    }

    // MARK: Multikey and did:key

    /// Parses a `did:key` identifier.
    ///
    /// - Throws: ``PetrelCryptoError/invalidIdentifier(_:)`` unless the value
    ///   is `did:key:` followed by a canonical multikey for P-256 or K-256.
    public init(didKey: String) throws {
        guard didKey.hasPrefix(Self.didKeyPrefix) else {
            throw PetrelCryptoError.invalidIdentifier("did:key")
        }
        try self.init(multikey: String(didKey.dropFirst(Self.didKeyPrefix.count)))
    }

    /// Parses a multikey: `z` + base58btc(multicodec varint + compressed
    /// point). This is the `publicKeyMultibase` of a `Multikey` verification
    /// method, and a `did:key` without its prefix.
    ///
    /// The curve is read from the multicodec prefix. The value must be the
    /// canonical encoding: compressed point, minimal base58.
    ///
    /// - Throws: ``PetrelCryptoError/invalidIdentifier(_:)``.
    public init(multikey: String) throws {
        let decoded = try Self.decodeBase58Multibase(multikey, context: "multikey")
        guard decoded.count == 35,
              let curve = ATProtoKeyCurve.allCases.first(where: {
                  decoded.prefix(2) == $0.publicKeyMulticodecPrefix
              }) else {
            throw PetrelCryptoError.invalidIdentifier("multikey is not a compressed P-256 or K-256 public key")
        }
        let point = Data(decoded.dropFirst(2))
        do {
            try self.init(curve: curve, sec1Representation: point)
        } catch {
            throw PetrelCryptoError.invalidIdentifier("multikey is not a point on its curve")
        }
        guard compressedRepresentation == point else {
            throw PetrelCryptoError.invalidIdentifier("multikey is not canonical")
        }
    }

    /// Parses the deprecated multibase encoding used by
    /// `EcdsaSecp256r1VerificationKey2019` and
    /// `EcdsaSecp256k1VerificationKey2019` verification methods: `z` +
    /// base58btc(point) with **no** multicodec prefix, so the curve comes
    /// from the caller. The specification writes these uncompressed; the
    /// compressed form is accepted too, as the reference implementation does.
    ///
    /// - Throws: ``PetrelCryptoError/invalidIdentifier(_:)``.
    public init(legacyMultibase: String, curve: ATProtoKeyCurve) throws {
        let decoded = try Self.decodeBase58Multibase(legacyMultibase, context: "legacy verification method multibase")
        do {
            try self.init(curve: curve, sec1Representation: decoded)
        } catch {
            throw PetrelCryptoError.invalidIdentifier("legacy \(curve.rawValue) verification method")
        }
    }

    /// Reads the key out of a DID document verification method, given its
    /// `type` and `publicKeyMultibase` fields. Supports `Multikey` and the
    /// two legacy 2019 suites.
    ///
    /// - Throws: ``PetrelCryptoError/unsupportedAlgorithm(_:)`` for any other
    ///   `type`; ``PetrelCryptoError/invalidIdentifier(_:)`` for a bad key.
    public init(verificationMethodType type: String, publicKeyMultibase: String) throws {
        switch type {
        case "Multikey":
            try self.init(multikey: publicKeyMultibase)
        case ATProtoKeyCurve.p256.legacyVerificationMethodType:
            try self.init(legacyMultibase: publicKeyMultibase, curve: .p256)
        case ATProtoKeyCurve.k256.legacyVerificationMethodType:
            try self.init(legacyMultibase: publicKeyMultibase, curve: .k256)
        default:
            throw PetrelCryptoError.unsupportedAlgorithm("verification method type \(type)")
        }
    }

    /// The JOSE `alg` value for signatures by this key.
    public var jwtAlgorithm: String { curve.jwtAlgorithm }

    /// Multicodec prefix followed by the compressed point (35 bytes).
    public var multikeyBytes: Data { curve.publicKeyMulticodecPrefix + compressedRepresentation }

    /// The multikey string, for a `Multikey` verification method's
    /// `publicKeyMultibase`.
    public var multikey: String { "z" + Base58BTC.encode(multikeyBytes) }

    /// The `did:key` identifier, as used for PLC rotation keys.
    public var didKey: String { Self.didKeyPrefix + multikey }

    /// The 65-byte uncompressed SEC1 point (`0x04 || X || Y`).
    public var uncompressedRepresentation: Data {
        get throws {
            switch curve {
            case .p256:
                return try p256Key().x963Representation
            case .k256:
                return try K256Backend.uncompressedPublicKey(fromSEC1: compressedRepresentation)
            }
        }
    }

    /// The deprecated legacy multibase encoding (`z` + base58btc of the
    /// uncompressed point). Only for producing old-style DID documents.
    public var legacyMultibase: String {
        get throws { try "z" + Base58BTC.encode(uncompressedRepresentation) }
    }

    /// Same as ``didKey``.
    public var description: String { didKey }

    // MARK: Verification

    /// Verifies an ECDSA signature over `SHA-256(message)`.
    ///
    /// `message` is the exact bytes that were signed (for example the
    /// DAG-CBOR of an unsigned commit); hashing happens here. Returns `false`
    /// — never throws — for a wrong signature, wrong length, out-of-range
    /// scalar, or an encoding `options` does not allow. The comparison is
    /// done by the cryptographic library, not on signature bytes.
    ///
    /// - Parameters:
    ///   - signature: 64-byte compact `r || s` (or DER if `options` allows).
    ///   - message: The signed bytes, unhashed.
    ///   - options: Encoding policy. Defaults to ``ATProtoSignatureVerificationOptions/strict``.
    public func isValidSignature(
        _ signature: Data,
        for message: Data,
        options: ATProtoSignatureVerificationOptions = .strict
    ) -> Bool {
        for compact in ATProtoSignature.compactCandidates(signature, curve: curve, options: options) {
            guard ECDSAScalar.isStructurallyValid(compact: compact, curve: curve) else { continue }
            let isLowS = ECDSAScalar.isLow(compact.suffix(ECDSAScalar.byteCount), curve: curve)
            guard isLowS || options.allowHighS else { continue }
            if verifies(structurallyValidCompact: compact, message: message) {
                return true
            }
        }
        return false
    }

    private func verifies(structurallyValidCompact compact: Data, message: Data) -> Bool {
        switch curve {
        case .p256:
            guard let key = try? p256Key(),
                  let signature = try? P256.Signing.ECDSASignature(rawRepresentation: compact) else {
                return false
            }
            // Swift Crypto verifies (r, s) and (r, n - s) alike; the low-S
            // gate above is what makes strict mode strict.
            return key.isValidSignature(signature, for: message)
        case .k256:
            // libsecp256k1 refuses high-S, so fold first. Whether a high-S
            // input is acceptable at all was decided by the caller.
            return K256Backend.isValidSignature(
                lowSCompact: ECDSAScalar.lowSForm(ofStructurallyValid: compact, curve: .k256),
                message: message,
                compressedPublicKey: compressedRepresentation
            )
        }
    }

    /// The Swift Crypto / CryptoKit key, for P-256 keys.
    ///
    /// - Throws: ``PetrelCryptoError/unsupportedAlgorithm(_:)`` for a K-256 key.
    public func p256Key() throws -> P256.Signing.PublicKey {
        guard curve == .p256 else {
            throw PetrelCryptoError.unsupportedAlgorithm("not a P-256 key")
        }
        do {
            return try P256.Signing.PublicKey(compressedRepresentation: compressedRepresentation)
        } catch {
            throw PetrelCryptoError.malformed("P-256 public key is not a point on the curve")
        }
    }

    private static let didKeyPrefix = "did:key:"

    private static func decodeBase58Multibase(_ value: String, context: String) throws -> Data {
        guard value.hasPrefix("z"), value.utf8.count <= 256 else {
            throw PetrelCryptoError.invalidIdentifier("\(context) must be base58btc with a z prefix")
        }
        let encoded = String(value.dropFirst())
        guard let decoded = try? Base58BTC.decode(encoded), Base58BTC.encode(decoded) == encoded else {
            throw PetrelCryptoError.invalidIdentifier("\(context) is not canonical base58btc")
        }
        return decoded
    }
}
