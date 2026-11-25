//! Supported elliptic curves for AT Protocol cryptography.

use serde::{Deserialize, Serialize};

/// The two elliptic curves AT Protocol signs with.
///
/// The AT Protocol Cryptography specification requires implementations to
/// fully support both `P256` (`ES256`) and `Secp256k1` (`ES256K`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ATProtoKeyCurve {
    /// NIST P-256 (`secp256r1` / `prime256v1`). JWT algorithm `ES256`.
    #[serde(rename = "p256")]
    P256,
    /// `secp256k1`, the reference implementation's default for new keys. JWT algorithm `ES256K`.
    #[serde(rename = "k256")]
    Secp256k1,
}

impl ATProtoKeyCurve {
    /// All supported curves, in canonical order (`P256`, `Secp256k1`).
    pub const ALL: [Self; 2] = [Self::P256, Self::Secp256k1];

    /// The curve name matching Swift `ATProtoKeyCurve.rawValue` (`"p256"` or `"k256"`).
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::P256 => "p256",
            Self::Secp256k1 => "k256",
        }
    }

    /// The JOSE `alg` value for ECDSA with SHA-256 on this curve.
    pub const fn jwt_algorithm(self) -> &'static str {
        match self {
            Self::P256 => "ES256",
            Self::Secp256k1 => "ES256K",
        }
    }

    /// Looks up a curve by its JOSE `alg` value (`"ES256"` or `"ES256K"`).
    pub fn from_jwt_algorithm(alg: &str) -> Option<Self> {
        match alg {
            "ES256" => Some(Self::P256),
            "ES256K" => Some(Self::Secp256k1),
            _ => None,
        }
    }

    /// Varint-encoded multicodec prefix of a compressed public key on this
    /// curve: `p256-pub` (`0x1200` -> `[0x80, 0x24]`) or `secp256k1-pub` (`0xE7` -> `[0xe7, 0x01]`).
    pub const fn public_key_multicodec_prefix(self) -> [u8; 2] {
        match self {
            Self::P256 => [0x80, 0x24],
            Self::Secp256k1 => [0xe7, 0x01],
        }
    }

    /// Varint-encoded multicodec prefix of a private scalar on this curve:
    /// `p256-priv` (`0x1306` -> `[0x86, 0x26]`) or `secp256k1-priv` (`0x1301` -> `[0x81, 0x26]`).
    pub const fn private_key_multicodec_prefix(self) -> [u8; 2] {
        match self {
            Self::P256 => [0x86, 0x26],
            Self::Secp256k1 => [0x81, 0x26],
        }
    }

    /// The `type` a pre-`Multikey` DID document used for a verification method on this curve.
    pub const fn legacy_verification_method_type(self) -> &'static str {
        match self {
            Self::P256 => "EcdsaSecp256r1VerificationKey2019",
            Self::Secp256k1 => "EcdsaSecp256k1VerificationKey2019",
        }
    }
}
