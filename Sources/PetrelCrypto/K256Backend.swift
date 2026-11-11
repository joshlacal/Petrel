import Foundation
import P256K

/// The only place the key API touches the third-party `P256K` module
/// (swift-secp256k1, a Swift wrapper over Bitcoin Core's libsecp256k1).
/// Everything public is expressed in `Data`, so the dependency can be
/// replaced or upgraded without changing Petrel's API.
enum K256Backend {
    static let privateKeyByteCount = 32
    static let compressedPublicKeyByteCount = 33
    static let uncompressedPublicKeyByteCount = 65

    /// Validates a 32-byte private scalar (`0 < d < n`) and returns the
    /// compressed public point.
    static func compressedPublicKey(forPrivateKey rawRepresentation: Data) throws -> Data {
        guard rawRepresentation.count == privateKeyByteCount else {
            throw PetrelCryptoError.malformed("K-256 private key must be 32 bytes")
        }
        do {
            let key = try P256K.Signing.PrivateKey(
                dataRepresentation: rawRepresentation,
                format: .compressed
            )
            return key.publicKey.dataRepresentation
        } catch {
            throw PetrelCryptoError.malformed("K-256 private key is not a valid scalar")
        }
    }

    /// Parses a SEC1 point (33-byte compressed or 65-byte uncompressed),
    /// proves it is on the curve, and returns the compressed form.
    static func compressedPublicKey(fromSEC1 encoded: Data) throws -> Data {
        let key = try parse(encoded)
        switch key.format {
        case .compressed:
            return key.dataRepresentation
        case .uncompressed:
            // libsecp256k1 has checked (X, Y) against the curve equation, so
            // the compressed form is the parity of Y followed by X.
            let point = key.dataRepresentation
            guard point.count == uncompressedPublicKeyByteCount, let lastByteOfY = point.last else {
                throw PetrelCryptoError.malformed("K-256 public key could not be serialized")
            }
            return Data([0x02 | (lastByteOfY & 1)]) + point.dropFirst().prefix(32)
        }
    }

    /// Returns the 65-byte uncompressed form of a SEC1 point.
    static func uncompressedPublicKey(fromSEC1 encoded: Data) throws -> Data {
        let uncompressed = try parse(encoded).uncompressedRepresentation
        guard uncompressed.count == uncompressedPublicKeyByteCount else {
            throw PetrelCryptoError.malformed("K-256 public key could not be serialized")
        }
        return uncompressed
    }

    /// SHA-256 hashes `message` and signs the digest with deterministic
    /// (RFC 6979) ECDSA. libsecp256k1 only ever produces low-S signatures;
    /// the result is checked anyway so the contract does not rest on that.
    static func sign(message: Data, privateKey rawRepresentation: Data) throws -> Data {
        let key: P256K.Signing.PrivateKey
        do {
            key = try P256K.Signing.PrivateKey(
                dataRepresentation: rawRepresentation,
                format: .compressed
            )
        } catch {
            throw PetrelCryptoError.malformed("K-256 private key is not a valid scalar")
        }
        let compact = key.signature(for: message).compactRepresentation
        guard ECDSAScalar.isStructurallyValid(compact: compact, curve: .k256) else {
            throw PetrelCryptoError.malformed("K-256 signer produced an invalid signature")
        }
        return ECDSAScalar.lowSForm(ofStructurallyValid: compact, curve: .k256)
    }

    /// Verifies a low-S compact signature over `SHA-256(message)`.
    /// libsecp256k1 rejects high-S values itself, so lax callers fold S
    /// before calling this.
    static func isValidSignature(
        lowSCompact compact: Data,
        message: Data,
        compressedPublicKey: Data
    ) -> Bool {
        do {
            let key = try P256K.Signing.PublicKey(
                dataRepresentation: compressedPublicKey,
                format: .compressed
            )
            let signature = try P256K.Signing.ECDSASignature(compactRepresentation: compact)
            return key.isValidSignature(signature, for: message)
        } catch {
            return false
        }
    }

    /// Strictly parses an ASN.1 DER `ECDSA-Sig-Value` into `r || s`.
    static func compactSignature(fromDER der: Data) throws -> Data {
        do {
            return try P256K.Signing.ECDSASignature(derRepresentation: der).compactRepresentation
        } catch {
            throw PetrelCryptoError.malformed("K-256 DER signature is malformed")
        }
    }

    private static func parse(_ encoded: Data) throws -> P256K.Signing.PublicKey {
        let format: P256K.Format
        switch (encoded.count, encoded.first) {
        case (compressedPublicKeyByteCount, 0x02), (compressedPublicKeyByteCount, 0x03):
            format = .compressed
        case (uncompressedPublicKeyByteCount, 0x04):
            format = .uncompressed
        default:
            throw PetrelCryptoError.malformed("K-256 public key must be a 33- or 65-byte SEC1 point")
        }
        do {
            // `secp256k1_ec_pubkey_parse` proves the point satisfies the
            // curve equation, for both encodings.
            return try P256K.Signing.PublicKey(dataRepresentation: encoded, format: format)
        } catch {
            throw PetrelCryptoError.malformed("K-256 public key is not a point on the curve")
        }
    }
}
