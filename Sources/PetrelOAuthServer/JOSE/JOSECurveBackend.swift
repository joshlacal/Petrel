import Foundation
import PetrelCrypto

/// The bridge from JOSE's representation of keys and signatures (32-byte
/// base64url coordinates, 64-byte `r || s`) to `PetrelCrypto`, which owns all
/// curve arithmetic for both P-256 and secp256k1.
enum JOSECurveBackend {
    static let coordinateByteCount = 32
    static let signatureByteCount = 64

    static func publicKey(curve: OAuthJSONWebKey.Curve, x: Data, y: Data) -> ATProtoPublicKey? {
        guard x.count == coordinateByteCount, y.count == coordinateByteCount else { return nil }
        return try? ATProtoPublicKey(curve: curve.keyCurve, sec1Representation: Data([0x04]) + x + y)
    }

    static func isValidPublicPoint(curve: OAuthJSONWebKey.Curve, x: Data, y: Data) -> Bool {
        publicKey(curve: curve, x: x, y: y) != nil
    }

    /// Verifies a JWS `r || s` signature over `signingInput` (hashed with
    /// SHA-256 by `PetrelCrypto`).
    ///
    /// - Parameter acceptsHighS: JOSE does not canonicalise `s` (RFC 7518
    ///   §3.4), so tokens minted by third-party clients verify with either
    ///   encoding. AT Protocol-native signatures are low-S only.
    static func verify(
        curve: OAuthJSONWebKey.Curve,
        x: Data,
        y: Data,
        signature: Data,
        signingInput: Data,
        acceptsHighS: Bool
    ) -> Bool {
        guard signature.count == signatureByteCount, let key = publicKey(curve: curve, x: x, y: y) else {
            return false
        }
        return key.isValidSignature(signature, for: signingInput, options: acceptsHighS ? .jwt : .strict)
    }

    /// Signs `signingInput` and returns a low-S `r || s` signature.
    static func sign(
        curve: OAuthJSONWebKey.Curve,
        privateKey: Data,
        signingInput: Data
    ) throws -> Data {
        do {
            switch curve {
            case .p256:
                return try P256Keypair(rawRepresentation: privateKey).sign(signingInput)
            case .secp256k1:
                return try K256Keypair(rawRepresentation: privateKey).sign(signingInput)
            }
        } catch {
            throw OAuthServerError.malformed("\(curve.rawValue) private key is invalid")
        }
    }

    static func publicCoordinates(
        curve: OAuthJSONWebKey.Curve,
        privateKey: Data
    ) throws -> (x: Data, y: Data) {
        let uncompressed: Data
        do {
            switch curve {
            case .p256:
                uncompressed = try P256Keypair(rawRepresentation: privateKey).publicKey.uncompressedRepresentation
            case .secp256k1:
                uncompressed = try K256Keypair(rawRepresentation: privateKey).publicKey.uncompressedRepresentation
            }
        } catch {
            throw OAuthServerError.malformed("\(curve.rawValue) private key is invalid")
        }
        guard uncompressed.count == 65, uncompressed.first == 0x04 else {
            throw OAuthServerError.malformed("public key encoding is invalid")
        }
        let bytes = Array(uncompressed)
        return (Data(bytes[1 ..< 33]), Data(bytes[33 ..< 65]))
    }

    static func generatePrivateKey(curve: OAuthJSONWebKey.Curve) -> Data {
        switch curve {
        case .p256: P256Keypair.generate().exportRawRepresentation()
        case .secp256k1: K256Keypair.generate().exportRawRepresentation()
        }
    }
}

extension OAuthJSONWebKey.Curve {
    /// The `PetrelCrypto` curve for this JWK curve.
    var keyCurve: ATProtoKeyCurve {
        switch self {
        case .p256: .p256
        case .secp256k1: .k256
        }
    }
}
