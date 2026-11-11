import Foundation
@preconcurrency import secp256k1

/// The only place the new key API touches the third-party `secp256k1`
/// module (a Swift wrapper over Bitcoin Core's libsecp256k1). Everything
/// public is expressed in `Data`, so the dependency can be replaced or
/// upgraded without changing Petrel's API.
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
            let key = try secp256k1.Signing.PrivateKey(
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
        var parsed = try parse(encoded)
        return try serialize(&parsed, format: .compressed)
    }

    /// Returns the 65-byte uncompressed form of a SEC1 point.
    static func uncompressedPublicKey(fromSEC1 encoded: Data) throws -> Data {
        var parsed = try parse(encoded)
        return try serialize(&parsed, format: .uncompressed)
    }

    /// SHA-256 hashes `message` and signs the digest with deterministic
    /// (RFC 6979) ECDSA. libsecp256k1 only ever produces low-S signatures;
    /// the result is checked anyway so the contract does not rest on that.
    static func sign(message: Data, privateKey rawRepresentation: Data) throws -> Data {
        let compact: Data
        do {
            let key = try secp256k1.Signing.PrivateKey(
                dataRepresentation: rawRepresentation,
                format: .compressed
            )
            compact = try key.signature(for: message).compactRepresentation
        } catch {
            throw PetrelCryptoError.malformed("K-256 signing failed")
        }
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
            let key = try secp256k1.Signing.PublicKey(
                dataRepresentation: compressedPublicKey,
                format: .compressed
            )
            let signature = try secp256k1.Signing.ECDSASignature(compactRepresentation: compact)
            return key.isValidSignature(signature, for: message)
        } catch {
            return false
        }
    }

    /// Strictly parses an ASN.1 DER `ECDSA-Sig-Value` into `r || s`.
    static func compactSignature(fromDER der: Data) throws -> Data {
        do {
            return try secp256k1.Signing.ECDSASignature(derRepresentation: der).compactRepresentation
        } catch {
            throw PetrelCryptoError.malformed("K-256 DER signature is malformed")
        }
    }

    private static func parse(_ encoded: Data) throws -> secp256k1_pubkey {
        let format: secp256k1.Format
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
            return try secp256k1.Signing.PublicKey(
                dataRepresentation: encoded,
                format: format
            ).rawRepresentation
        } catch {
            throw PetrelCryptoError.malformed("K-256 public key is not a point on the curve")
        }
    }

    private static func serialize(_ key: inout secp256k1_pubkey, format: secp256k1.Format) throws -> Data {
        var length = format.length
        var bytes = [UInt8](repeating: 0, count: length)
        guard secp256k1_ec_pubkey_serialize(
            secp256k1.Context.rawRepresentation,
            &bytes,
            &length,
            &key,
            format.rawValue
        ) == 1, length == format.length else {
            throw PetrelCryptoError.malformed("K-256 public key could not be serialized")
        }
        return Data(bytes)
    }
}
