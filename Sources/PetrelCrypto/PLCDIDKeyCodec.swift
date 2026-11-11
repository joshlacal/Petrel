import Crypto
import Foundation

/// The PLC wire format uses `did:key` multicodec values for both the local
/// P-256 identity and the pinned TypeScript PDS's secp256k1 identity. Keep the
/// decoding rule in one place so state/audit verification cannot accidentally
/// accept a key-shaped string without proving its curve and point encoding.
///
/// Despite the name this is not PLC-specific: it is a public key on either
/// AT Protocol curve. New code should prefer ``ATProtoPublicKey``, which is
/// validated at construction; convert with `init(_:)` and ``publicKey()``.
public enum PLCDIDVerificationKey: @unchecked Sendable, Equatable {
    case p256(P256.Signing.PublicKey)
    /// A secp256k1 SEC1 point. Build this with
    /// ``init(secp256k1PublicKey:)`` or ``PLCDIDKeyCodec``, which validate
    /// the point and store it compressed.
    case secp256k1(Data)

    /// Creates a secp256k1 key from a 33-byte compressed or 65-byte
    /// uncompressed SEC1 point. The point is checked against the curve and
    /// stored compressed.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)``.
    public init(secp256k1PublicKey: Data) throws {
        self = try .secp256k1(K256Backend.compressedPublicKey(fromSEC1: secp256k1PublicKey))
    }

    /// Wraps a validated ``ATProtoPublicKey``.
    ///
    /// - Throws: Never for a value built by ``ATProtoPublicKey``'s own
    ///   initializers; the error path exists because the P-256 point is
    ///   re-parsed into a Swift Crypto key.
    public init(_ key: ATProtoPublicKey) throws {
        switch key.curve {
        case .p256: self = try .p256(key.p256Key())
        case .k256: self = .secp256k1(key.compressedRepresentation)
        }
    }

    /// The same key as a validated, curve-tagged ``ATProtoPublicKey``.
    ///
    /// - Throws: ``PetrelCryptoError/malformed(_:)`` if a hand-built
    ///   `.secp256k1` case holds bytes that are not a curve point.
    public func publicKey() throws -> ATProtoPublicKey {
        switch self {
        case let .p256(key):
            return ATProtoPublicKey(key)
        case let .secp256k1(bytes):
            return try ATProtoPublicKey(curve: .k256, sec1Representation: bytes)
        }
    }

    /// Multicodec prefix followed by the compressed point.
    ///
    /// A `.secp256k1` case built by hand from an uncompressed point is
    /// compressed here, so the result is always the canonical 35 bytes for
    /// a real key. Bytes that are not a curve point are passed through
    /// unchanged and will not decode.
    public var didKeyBytes: Data {
        switch self {
        case let .p256(key):
            return Data([0x80, 0x24]) + key.compressedRepresentation
        case let .secp256k1(bytes):
            let canonical = (try? K256Backend.compressedPublicKey(fromSEC1: bytes)) ?? bytes
            return Data([0xe7, 0x01]) + canonical
        }
    }

    /// The multikey string (`z…`), as used for a `Multikey` verification
    /// method's `publicKeyMultibase`.
    public var multikey: String {
        "z" + Base58BTC.encode(didKeyBytes)
    }

    public var didKey: String {
        "did:key:" + multikey
    }

    /// Strict verification of a compact low-S signature. See
    /// ``ATProtoJWTVerificationKey/verify(signature:signingInput:algorithm:)``.
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

/// `did:key` and multikey decoding for both AT Protocol curves.
///
/// Despite the name this is not PLC-specific. ``ATProtoPublicKey`` offers
/// the same parsing with a curve-neutral result type.
public enum PLCDIDKeyCodec {
    /// Decodes a `did:key` for P-256 or K-256. The value must be canonical:
    /// compressed point, minimal base58btc.
    public static func decode(_ value: String) throws -> PLCDIDVerificationKey {
        guard value.hasPrefix("did:key:z"), value.utf8.count <= 256 else {
            throw PetrelCryptoError.invalidIdentifier("did:key")
        }
        return try decodeMultikeyBody(String(value.dropFirst("did:key:z".count)), context: "did:key")
    }

    /// Decodes a bare multikey (`z…`, no `did:key:` prefix) — the
    /// `publicKeyMultibase` of a `Multikey` verification method.
    public static func decodeMultikey(_ value: String) throws -> PLCDIDVerificationKey {
        guard value.hasPrefix("z"), value.utf8.count <= 256 else {
            throw PetrelCryptoError.invalidIdentifier("multikey")
        }
        return try decodeMultikeyBody(String(value.dropFirst()), context: "multikey")
    }

    private static func decodeMultikeyBody(_ encoded: String, context: String) throws -> PLCDIDVerificationKey {
        let decoded = try Base58BTC.decode(encoded)
        guard Base58BTC.encode(decoded) == encoded else {
            throw PetrelCryptoError.invalidIdentifier(context)
        }

        if decoded.count == 35, decoded.prefix(2) == Data([0x80, 0x24]) {
            do {
                let key = try P256.Signing.PublicKey(
                    compressedRepresentation: decoded.dropFirst(2)
                )
                guard key.compressedRepresentation == decoded.dropFirst(2) else {
                    throw PetrelCryptoError.invalidIdentifier("P-256 \(context)")
                }
                return .p256(key)
            } catch {
                throw PetrelCryptoError.invalidIdentifier("P-256 \(context)")
            }
        }

        guard decoded.count == 35, decoded.prefix(2) == Data([0xe7, 0x01]) else {
            throw PetrelCryptoError.invalidIdentifier("secp256k1 \(context)")
        }
        let point = Data(decoded.dropFirst(2))
        guard let compressed = try? K256Backend.compressedPublicKey(fromSEC1: point), compressed == point else {
            throw PetrelCryptoError.invalidIdentifier("secp256k1 \(context)")
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
            // Parse with libsecp256k1 in either encoding: for the 65-byte
            // form that checks (X, Y) against the curve equation, so a
            // corrupted Y is rejected rather than silently discarded.
            guard decoded.count == 33 || decoded.count == 65,
                  let compressed = try? K256Backend.compressedPublicKey(fromSEC1: decoded) else {
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
