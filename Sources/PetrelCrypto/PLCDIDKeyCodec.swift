import Crypto
import Foundation
import secp256k1

/// The PLC wire format uses `did:key` multicodec values for both the local
/// P-256 identity and the pinned TypeScript PDS's secp256k1 identity. Keep the
/// decoding rule in one place so state/audit verification cannot accidentally
/// accept a key-shaped string without proving its curve and point encoding.
public enum PLCDIDVerificationKey: @unchecked Sendable, Equatable {
    case p256(P256.Signing.PublicKey)
    case secp256k1(Data)

    public var didKeyBytes: Data {
        switch self {
        case let .p256(key):
            return Data([0x80, 0x24]) + key.compressedRepresentation
        case let .secp256k1(bytes):
            return Data([0xe7, 0x01]) + bytes
        }
    }

    public var didKey: String {
        "did:key:z" + Base58BTC.encode(didKeyBytes)
    }

    public func verify(
        signature: Data,
        signingInput: Data,
        algorithm: String
    ) throws -> Bool {
        try ATProtoJWTVerificationKey(self).verify(
            signature: signature,
            signingInput: signingInput,
            algorithm: algorithm
        )
    }

    public static func == (lhs: PLCDIDVerificationKey, rhs: PLCDIDVerificationKey) -> Bool {
        lhs.didKeyBytes == rhs.didKeyBytes
    }
}

public enum PLCDIDKeyCodec {
    public static func decode(_ value: String) throws -> PLCDIDVerificationKey {
        guard value.hasPrefix("did:key:z"), value.utf8.count <= 256 else {
            throw PetrelCryptoError.invalidIdentifier("did:key")
        }
        let encoded = String(value.dropFirst("did:key:z".count))
        let decoded = try Base58BTC.decode(encoded)
        guard Base58BTC.encode(decoded) == encoded else {
            throw PetrelCryptoError.invalidIdentifier("did:key")
        }

        if decoded.count == 35, decoded.prefix(2) == Data([0x80, 0x24]) {
            do {
                let key = try P256.Signing.PublicKey(
                    compressedRepresentation: decoded.dropFirst(2)
                )
                guard key.compressedRepresentation == decoded.dropFirst(2) else {
                    throw PetrelCryptoError.invalidIdentifier("P-256 did:key")
                }
                return .p256(key)
            } catch {
                throw PetrelCryptoError.invalidIdentifier("P-256 did:key")
            }
        }

        guard decoded.count == 35, decoded.prefix(2) == Data([0xe7, 0x01]) else {
            throw PetrelCryptoError.invalidIdentifier("secp256k1 did:key")
        }
        let point = Data(decoded.dropFirst(2))
        do {
            _ = try secp256k1.Signing.PublicKey(
                dataRepresentation: point,
                format: .compressed
            )
        } catch {
            throw PetrelCryptoError.invalidIdentifier("secp256k1 did:key")
        }
        return .secp256k1(point)
    }

    /// The curve of a legacy W3C verification method, which — unlike a
    /// `Multikey` — is carried in the document's `type` field rather than in
    /// the key encoding itself.
    public enum LegacyVerificationKeyCurve: Sendable, Equatable {
        /// `EcdsaSecp256r1VerificationKey2019`.
        case p256
        /// `EcdsaSecp256k1VerificationKey2019`.
        case secp256k1
    }

    /// Decodes the two **legacy** `publicKeyMultibase` spellings upstream
    /// accepts alongside `Multikey`
    /// (`ATPROTO_VERIFICATION_METHOD_TYPES`).
    public static func decodeLegacyMultibase(
        _ multibase: String, curve: LegacyVerificationKeyCurve
    ) throws -> PLCDIDVerificationKey {
        guard multibase.hasPrefix("z"), multibase.utf8.count <= 256 else {
            throw PetrelCryptoError.invalidIdentifier("legacy verification method multibase")
        }
        let encoded = String(multibase.dropFirst())
        let decoded = try Base58BTC.decode(encoded)
        guard Base58BTC.encode(decoded) == encoded else {
            throw PetrelCryptoError.invalidIdentifier("legacy verification method multibase")
        }
        switch curve {
        case .p256:
            do {
                let key: P256.Signing.PublicKey
                switch decoded.count {
                case 33: key = try P256.Signing.PublicKey(compressedRepresentation: decoded)
                case 65: key = try P256.Signing.PublicKey(x963Representation: decoded)
                default: throw PetrelCryptoError.invalidIdentifier("P-256 legacy verification method")
                }
                return .p256(key)
            } catch {
                throw PetrelCryptoError.invalidIdentifier("P-256 legacy verification method")
            }
        case .secp256k1:
            let compressed: Data
            switch decoded.count {
            case 33:
                compressed = decoded
            case 65:
                // 0x04 ‖ X ‖ Y → (0x02 | lsb(Y)) ‖ X.
                guard decoded[decoded.startIndex] == 0x04 else {
                    throw PetrelCryptoError.invalidIdentifier("secp256k1 legacy verification method")
                }
                let x = Data(decoded.dropFirst().prefix(32))
                let yIsOdd = (decoded[decoded.index(decoded.startIndex, offsetBy: 64)] & 1) == 1
                compressed = Data([yIsOdd ? 0x03 : 0x02]) + x
            default:
                throw PetrelCryptoError.invalidIdentifier("secp256k1 legacy verification method")
            }
            do {
                _ = try secp256k1.Signing.PublicKey(
                    dataRepresentation: compressed, format: .compressed
                )
            } catch {
                throw PetrelCryptoError.invalidIdentifier("secp256k1 legacy verification method")
            }
            return .secp256k1(compressed)
        }
    }

    public static func validate(_ value: String) throws {
        _ = try decode(value)
    }

    public static func isCanonical(_ value: String) -> Bool {
        (try? decode(value)) != nil
    }
}

public struct P256DIDKey: Sendable, Equatable, Hashable, Codable {
    public let value: String

    public init(publicKey: P256.Signing.PublicKey) {
        value = "did:key:z" + Base58BTC.encode(
            Data([0x80, 0x24]) + publicKey.compressedRepresentation
        )
    }

    public init(_ value: String) throws {
        guard value.hasPrefix("did:key:z"), value.utf8.count <= 256 else {
            throw PetrelCryptoError.invalidIdentifier("P-256 did:key")
        }
        let encoded = String(value.dropFirst("did:key:z".count))
        let decoded = try Base58BTC.decode(encoded)
        guard Base58BTC.encode(decoded) == encoded,
              decoded.count == 35,
              decoded.prefix(2) == Data([0x80, 0x24]) else {
            throw PetrelCryptoError.invalidIdentifier("P-256 did:key")
        }
        do {
            let publicKey = try P256.Signing.PublicKey(
                compressedRepresentation: decoded.dropFirst(2)
            )
            guard publicKey.compressedRepresentation == decoded.dropFirst(2) else {
                throw PetrelCryptoError.invalidIdentifier("P-256 did:key")
            }
        } catch {
            throw PetrelCryptoError.invalidIdentifier("P-256 did:key")
        }
        self.value = value
    }

    public var publicKey: P256.Signing.PublicKey {
        get throws {
            let decoded = try Base58BTC.decode(String(value.dropFirst("did:key:z".count)))
            return try P256.Signing.PublicKey(
                compressedRepresentation: decoded.dropFirst(2)
            )
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
