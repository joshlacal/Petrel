import Foundation

/// The two elliptic curves AT Protocol signs with.
///
/// The specification requires implementations to "fully support both". Every
/// key, signer and verifier in this module is tagged with one of these cases.
public enum ATProtoKeyCurve: String, Sendable, Hashable, CaseIterable, Codable {
    /// NIST P-256, also known as `secp256r1` or `prime256v1`. JWT algorithm `ES256`.
    case p256
    /// `secp256k1`, the reference implementation's default for new keys. JWT algorithm `ES256K`.
    case k256

    /// The JOSE `alg` value for ECDSA with SHA-256 on this curve.
    public var jwtAlgorithm: String {
        switch self {
        case .p256: return "ES256"
        case .k256: return "ES256K"
        }
    }

    /// Looks a curve up by its JOSE `alg` value (`ES256` or `ES256K`).
    public init?(jwtAlgorithm: String) {
        switch jwtAlgorithm {
        case "ES256": self = .p256
        case "ES256K": self = .k256
        default: return nil
        }
    }

    /// Varint-encoded multicodec prefix of a compressed public key on this
    /// curve: `p256-pub` (0x1200) or `secp256k1-pub` (0xE7).
    public var publicKeyMulticodecPrefix: Data {
        switch self {
        case .p256: return Data([0x80, 0x24])
        case .k256: return Data([0xe7, 0x01])
        }
    }

    /// Varint-encoded multicodec prefix of a private scalar on this curve:
    /// `p256-priv` (0x1306) or `secp256k1-priv` (0x1301).
    public var privateKeyMulticodecPrefix: Data {
        switch self {
        case .p256: return Data([0x86, 0x26])
        case .k256: return Data([0x81, 0x26])
        }
    }

    /// The `type` a pre-`Multikey` DID document used for a verification
    /// method on this curve.
    public var legacyVerificationMethodType: String {
        switch self {
        case .p256: return "EcdsaSecp256r1VerificationKey2019"
        case .k256: return "EcdsaSecp256k1VerificationKey2019"
        }
    }
}
