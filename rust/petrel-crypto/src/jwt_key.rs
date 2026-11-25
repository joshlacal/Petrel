//! Legacy-compatible pinned JWT verification key (`ATProtoJWTVerificationKey`).

use crate::codecs::Hex;
use crate::curve::ATProtoKeyCurve;
use crate::did_key::PLCDIDVerificationKey;
use crate::error::PetrelCryptoError;
use crate::keys::{ATProtoCrypto, PublicKey};
use crate::signature::{ATProtoSignature, ATProtoSignatureVerificationOptions};

/// A bounded public key selected from a local account projection or an operator-pinned
/// interop fixture, supporting both P-256 (`ES256`) and secp256k1 (`ES256K`).
///
/// New code should prefer [`PublicKey`], which holds one canonical encoding for both curves.
#[derive(Debug, Clone)]
#[allow(clippy::upper_case_acronyms)]
pub enum ATProtoJWTVerificationKey {
    /// A validated P-256 public key.
    P256(PublicKey),
    /// A secp256k1 SEC1 point (normalized compressed when built with [`Self::from_secp256k1_public_key`]).
    Secp256k1(Vec<u8>),
}

impl ATProtoJWTVerificationKey {
    /// Creates a pinned secp256k1 verification key from compressed or uncompressed SEC1 bytes.
    pub fn from_secp256k1_public_key(bytes: &[u8]) -> Result<Self, PetrelCryptoError> {
        let key = PublicKey::from_sec1(ATProtoKeyCurve::Secp256k1, bytes)
            .map_err(|_| PetrelCryptoError::Malformed("invalid secp256k1 public key".into()))?;
        Ok(Self::Secp256k1(key.compressed_representation().to_vec()))
    }

    /// Wraps a [`PLCDIDVerificationKey`] after validating its SEC1 curve point.
    pub fn from_plc_key(key: &PLCDIDVerificationKey) -> Result<Self, PetrelCryptoError> {
        match key {
            PLCDIDVerificationKey::P256(compressed) => Ok(Self::P256(PublicKey::from_sec1(
                ATProtoKeyCurve::P256,
                compressed,
            )?)),
            PLCDIDVerificationKey::Secp256k1(bytes) => Self::from_secp256k1_public_key(bytes),
        }
    }

    /// Wraps a validated [`PublicKey`].
    pub fn from_public_key(key: &PublicKey) -> Self {
        match key.curve() {
            ATProtoKeyCurve::P256 => Self::P256(key.clone()),
            ATProtoKeyCurve::Secp256k1 => Self::Secp256k1(key.compressed_representation().to_vec()),
        }
    }

    /// Converts to a validated curve-tagged [`PublicKey`].
    pub fn public_key(&self) -> Result<PublicKey, PetrelCryptoError> {
        match self {
            Self::P256(key) => Ok(key.clone()),
            Self::Secp256k1(encoded) => PublicKey::from_sec1(ATProtoKeyCurve::Secp256k1, encoded),
        }
    }

    /// Verifies a signature strictly (64-byte compact low-S only).
    ///
    /// Throws `Unauthorized` on algorithm mismatch or non-canonical signature.
    pub fn verify(
        &self,
        signature: &[u8],
        signing_input: &[u8],
        algorithm: &str,
    ) -> Result<bool, PetrelCryptoError> {
        match self {
            Self::P256(key) => {
                if algorithm != "ES256" {
                    return Err(PetrelCryptoError::Unauthorized(
                        "JWT algorithm does not match verification key".into(),
                    ));
                }
                if !ATProtoSignature::is_canonical(signature, ATProtoKeyCurve::P256) {
                    return Err(Self::non_canonical_signature_error());
                }
                Ok(key.verify_strict(signature, signing_input))
            }
            Self::Secp256k1(encoded) => {
                if algorithm != "ES256K" {
                    return Err(PetrelCryptoError::Unauthorized(
                        "JWT algorithm or signature is invalid".into(),
                    ));
                }
                if !Self::is_canonical_secp256k1_signature(signature) {
                    return Err(Self::non_canonical_signature_error());
                }
                let key =
                    PublicKey::from_sec1(ATProtoKeyCurve::Secp256k1, encoded).map_err(|_| {
                        PetrelCryptoError::Unauthorized("secp256k1 public key is invalid".into())
                    })?;
                Ok(key.verify_strict(signature, signing_input))
            }
        }
    }

    /// Verifies a signature under an explicit encoding policy.
    pub fn verify_with_options(
        &self,
        signature: &[u8],
        signing_input: &[u8],
        algorithm: &str,
        options: ATProtoSignatureVerificationOptions,
    ) -> Result<bool, PetrelCryptoError> {
        if options == ATProtoSignatureVerificationOptions::STRICT {
            return self.verify(signature, signing_input, algorithm);
        }
        let key = self.public_key().map_err(|_| {
            PetrelCryptoError::Unauthorized("secp256k1 public key is invalid".into())
        })?;
        if algorithm != key.jwt_algorithm() {
            return Err(match key.curve() {
                ATProtoKeyCurve::P256 => PetrelCryptoError::Unauthorized(
                    "JWT algorithm does not match verification key".into(),
                ),
                ATProtoKeyCurve::Secp256k1 => {
                    PetrelCryptoError::Unauthorized("JWT algorithm or signature is invalid".into())
                }
            });
        }
        Ok(key.is_valid_signature(signature, signing_input, options))
    }

    /// Canonical key identity bytes (`0x01 || uncompressed_p256` or `0x02 || compressed_k256`).
    pub fn deterministic_identity(&self) -> Vec<u8> {
        match self {
            Self::P256(key) => {
                let uncompressed = key.uncompressed_representation();
                let mut out = Vec::with_capacity(66);
                out.push(0x01);
                out.extend_from_slice(&uncompressed);
                out
            }
            Self::Secp256k1(encoded) => {
                let mut out = Vec::with_capacity(34);
                out.push(0x02);
                if let Ok(key) = PublicKey::from_sec1(ATProtoKeyCurve::Secp256k1, encoded) {
                    out.extend_from_slice(key.compressed_representation());
                } else {
                    out.extend_from_slice(encoded);
                }
                out
            }
        }
    }

    /// Non-secret SHA-256 fingerprint (`"key-sha256:<hex>"`).
    pub fn recovery_verifier_identity(&self) -> String {
        format!(
            "key-sha256:{}",
            Hex::encode(&ATProtoCrypto::sha256(&self.deterministic_identity()))
        )
    }

    /// Returns `true` iff `encoded` is a valid 33- or 65-byte SEC1 secp256k1 public key.
    pub fn validates_secp256k1_public_key(encoded: &[u8]) -> bool {
        PublicKey::from_sec1(ATProtoKeyCurve::Secp256k1, encoded).is_ok()
    }

    /// Returns `true` iff `signature` is a canonical low-S compact secp256k1 signature.
    pub fn is_canonical_secp256k1_signature(signature: &[u8]) -> bool {
        ATProtoSignature::is_canonical(signature, ATProtoKeyCurve::Secp256k1)
    }

    fn non_canonical_signature_error() -> PetrelCryptoError {
        PetrelCryptoError::Unauthorized(
            "JWT signature is not a canonical low-S compact signature".into(),
        )
    }
}

impl PartialEq for ATProtoJWTVerificationKey {
    fn eq(&self, other: &Self) -> bool {
        self.deterministic_identity() == other.deterministic_identity()
    }
}

impl Eq for ATProtoJWTVerificationKey {}

impl From<PublicKey> for ATProtoJWTVerificationKey {
    fn from(value: PublicKey) -> Self {
        Self::from_public_key(&value)
    }
}

impl From<&PublicKey> for ATProtoJWTVerificationKey {
    fn from(value: &PublicKey) -> Self {
        Self::from_public_key(value)
    }
}

impl TryFrom<PLCDIDVerificationKey> for ATProtoJWTVerificationKey {
    type Error = PetrelCryptoError;

    fn try_from(value: PLCDIDVerificationKey) -> Result<Self, Self::Error> {
        Self::from_plc_key(&value)
    }
}

impl TryFrom<&PLCDIDVerificationKey> for ATProtoJWTVerificationKey {
    type Error = PetrelCryptoError;

    fn try_from(value: &PLCDIDVerificationKey) -> Result<Self, Self::Error> {
        Self::from_plc_key(value)
    }
}
