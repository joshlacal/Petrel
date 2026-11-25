//! `did:key` and multikey codecs (`PLCDIDKeyCodec`, `PLCDIDVerificationKey`, `P256DIDKey`).

use std::fmt;
use std::str::FromStr;

use serde::{Deserialize, Deserializer, Serialize, Serializer};

use crate::base58::Base58BTC;
use crate::curve::ATProtoKeyCurve;
use crate::error::PetrelCryptoError;
use crate::jwt_key::ATProtoJWTVerificationKey;
use crate::keys::{PublicKey, decode_base58_multibase};

const DID_KEY_PREFIX: &str = "did:key:";

/// Curve selector for legacy W3C verification methods without multicodec prefixes.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum LegacyVerificationKeyCurve {
    /// `EcdsaSecp256r1VerificationKey2019`.
    P256,
    /// `EcdsaSecp256k1VerificationKey2019`.
    Secp256k1,
}

impl From<LegacyVerificationKeyCurve> for ATProtoKeyCurve {
    fn from(value: LegacyVerificationKeyCurve) -> Self {
        match value {
            LegacyVerificationKeyCurve::P256 => Self::P256,
            LegacyVerificationKeyCurve::Secp256k1 => Self::Secp256k1,
        }
    }
}

/// Decoded PLC / ATProto verification key (P-256 or secp256k1).
#[derive(Debug, Clone)]
#[allow(clippy::upper_case_acronyms)]
pub enum PLCDIDVerificationKey {
    /// P-256 key stored in 33-byte compressed SEC1 form.
    P256([u8; 33]),
    /// Secp256k1 SEC1 point bytes (33-byte compressed or 65-byte uncompressed).
    Secp256k1(Vec<u8>),
}

impl PLCDIDVerificationKey {
    /// Creates a secp256k1 verification key from a 33-byte compressed or 65-byte
    /// uncompressed SEC1 point, validating on-curve and normalizing to compressed form.
    pub fn from_secp256k1_public_key(bytes: &[u8]) -> Result<Self, PetrelCryptoError> {
        let key = PublicKey::from_sec1(ATProtoKeyCurve::Secp256k1, bytes)?;
        Ok(Self::Secp256k1(key.compressed_representation().to_vec()))
    }

    /// Creates a P-256 verification key from a 33- or 65-byte SEC1 point.
    pub fn from_p256_public_key(bytes: &[u8]) -> Result<Self, PetrelCryptoError> {
        let key = PublicKey::from_sec1(ATProtoKeyCurve::P256, bytes)?;
        Ok(Self::P256(*key.compressed_representation()))
    }

    /// Wraps a validated [`PublicKey`].
    pub fn from_public_key(key: &PublicKey) -> Self {
        match key.curve() {
            ATProtoKeyCurve::P256 => Self::P256(*key.compressed_representation()),
            ATProtoKeyCurve::Secp256k1 => Self::Secp256k1(key.compressed_representation().to_vec()),
        }
    }

    /// Converts to a validated curve-tagged [`PublicKey`].
    pub fn public_key(&self) -> Result<PublicKey, PetrelCryptoError> {
        match self {
            Self::P256(bytes) => PublicKey::from_sec1(ATProtoKeyCurve::P256, bytes),
            Self::Secp256k1(bytes) => PublicKey::from_sec1(ATProtoKeyCurve::Secp256k1, bytes),
        }
    }

    /// Multicodec prefix followed by the compressed SEC1 point.
    pub fn did_key_bytes(&self) -> Vec<u8> {
        match self {
            Self::P256(compressed) => {
                let mut out = Vec::with_capacity(35);
                out.extend_from_slice(&[0x80, 0x24]);
                out.extend_from_slice(compressed);
                out
            }
            Self::Secp256k1(bytes) => {
                let mut out = Vec::with_capacity(35);
                out.extend_from_slice(&[0xe7, 0x01]);
                if let Ok(key) = PublicKey::from_sec1(ATProtoKeyCurve::Secp256k1, bytes) {
                    out.extend_from_slice(key.compressed_representation());
                } else {
                    out.extend_from_slice(bytes);
                }
                out
            }
        }
    }

    /// The canonical multikey string (`z...`).
    pub fn multikey(&self) -> String {
        format!("z{}", Base58BTC::encode(&self.did_key_bytes()))
    }

    /// The canonical `did:key` string (`did:key:z...`).
    pub fn did_key(&self) -> String {
        format!("{DID_KEY_PREFIX}{}", self.multikey())
    }

    /// Strict low-S verification of a compact signature under `algorithm`.
    pub fn verify(
        &self,
        signature: &[u8],
        signing_input: &[u8],
        algorithm: &str,
    ) -> Result<bool, PetrelCryptoError> {
        ATProtoJWTVerificationKey::from_plc_key(self).verify(signature, signing_input, algorithm)
    }
}

impl PartialEq for PLCDIDVerificationKey {
    fn eq(&self, other: &Self) -> bool {
        self.did_key_bytes() == other.did_key_bytes()
    }
}

impl Eq for PLCDIDVerificationKey {}

/// `did:key` and multikey codec for P-256 and secp256k1.
#[derive(Debug, Clone, Copy)]
#[allow(clippy::upper_case_acronyms)]
pub struct PLCDIDKeyCodec;

impl PLCDIDKeyCodec {
    /// Decodes a canonical `did:key:z...` for P-256 or K-256.
    pub fn decode(value: &str) -> Result<PLCDIDVerificationKey, PetrelCryptoError> {
        let encoded = value
            .strip_prefix("did:key:z")
            .filter(|_| value.len() <= 256)
            .ok_or_else(|| PetrelCryptoError::InvalidIdentifier("did:key".into()))?;
        Self::decode_multikey_body(encoded, "did:key")
    }

    /// Decodes a bare multikey (`z...`, without `did:key:`).
    pub fn decode_multikey(value: &str) -> Result<PLCDIDVerificationKey, PetrelCryptoError> {
        let encoded = value
            .strip_prefix('z')
            .filter(|_| value.len() <= 256)
            .ok_or_else(|| PetrelCryptoError::InvalidIdentifier("multikey".into()))?;
        Self::decode_multikey_body(encoded, "multikey")
    }

    fn decode_multikey_body(
        encoded: &str,
        context: &str,
    ) -> Result<PLCDIDVerificationKey, PetrelCryptoError> {
        let decoded = Base58BTC::decode(encoded)
            .map_err(|_| PetrelCryptoError::InvalidIdentifier(context.into()))?;
        if Base58BTC::encode(&decoded) != encoded {
            return Err(PetrelCryptoError::InvalidIdentifier(context.into()));
        }
        if decoded.len() == 35 && decoded[..2] == [0x80, 0x24] {
            let point = &decoded[2..];
            let key = PublicKey::from_sec1(ATProtoKeyCurve::P256, point)
                .map_err(|_| PetrelCryptoError::InvalidIdentifier(format!("P-256 {context}")))?;
            if key.compressed_representation() != point {
                return Err(PetrelCryptoError::InvalidIdentifier(format!(
                    "P-256 {context}"
                )));
            }
            return Ok(PLCDIDVerificationKey::P256(
                *key.compressed_representation(),
            ));
        }
        if decoded.len() == 35 && decoded[..2] == [0xe7, 0x01] {
            let point = &decoded[2..];
            let key = PublicKey::from_sec1(ATProtoKeyCurve::Secp256k1, point).map_err(|_| {
                PetrelCryptoError::InvalidIdentifier(format!("secp256k1 {context}"))
            })?;
            if key.compressed_representation() != point {
                return Err(PetrelCryptoError::InvalidIdentifier(format!(
                    "secp256k1 {context}"
                )));
            }
            return Ok(PLCDIDVerificationKey::Secp256k1(
                key.compressed_representation().to_vec(),
            ));
        }
        Err(PetrelCryptoError::InvalidIdentifier(format!(
            "secp256k1 {context}"
        )))
    }

    /// Decodes a legacy `publicKeyMultibase` (`z` + base58btc(33- or 65-byte point), no multicodec).
    pub fn decode_legacy_multibase(
        multibase: &str,
        curve: LegacyVerificationKeyCurve,
    ) -> Result<PLCDIDVerificationKey, PetrelCryptoError> {
        let decoded = decode_base58_multibase(multibase, "legacy verification method multibase")
            .map_err(|_| {
                PetrelCryptoError::InvalidIdentifier("legacy verification method multibase".into())
            })?;
        match curve {
            LegacyVerificationKeyCurve::P256 => {
                if !matches!(decoded.len(), 33 | 65) {
                    return Err(PetrelCryptoError::InvalidIdentifier(
                        "P-256 legacy verification method".into(),
                    ));
                }
                let key = PublicKey::from_sec1(ATProtoKeyCurve::P256, &decoded).map_err(|_| {
                    PetrelCryptoError::InvalidIdentifier("P-256 legacy verification method".into())
                })?;
                Ok(PLCDIDVerificationKey::P256(
                    *key.compressed_representation(),
                ))
            }
            LegacyVerificationKeyCurve::Secp256k1 => {
                if !matches!(decoded.len(), 33 | 65) {
                    return Err(PetrelCryptoError::InvalidIdentifier(
                        "secp256k1 legacy verification method".into(),
                    ));
                }
                let key =
                    PublicKey::from_sec1(ATProtoKeyCurve::Secp256k1, &decoded).map_err(|_| {
                        PetrelCryptoError::InvalidIdentifier(
                            "secp256k1 legacy verification method".into(),
                        )
                    })?;
                Ok(PLCDIDVerificationKey::Secp256k1(
                    key.compressed_representation().to_vec(),
                ))
            }
        }
    }

    /// Validates that `value` is a canonical P-256 or K-256 `did:key`.
    pub fn validate(value: &str) -> Result<(), PetrelCryptoError> {
        let _ = Self::decode(value)?;
        Ok(())
    }

    /// Returns `true` iff `value` is a canonical P-256 or K-256 `did:key`.
    pub fn is_canonical(value: &str) -> bool {
        Self::decode(value).is_ok()
    }
}

/// Canonical P-256 `did:key` wrapper (`did:key:zDna...`).
#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord)]
#[allow(clippy::upper_case_acronyms)]
pub struct P256DIDKey {
    value: String,
}

impl P256DIDKey {
    /// Builds a `P256DIDKey` from a 33-byte compressed P-256 public key.
    pub fn from_compressed_bytes(compressed: &[u8; 33]) -> Result<Self, PetrelCryptoError> {
        let key = PublicKey::from_sec1(ATProtoKeyCurve::P256, compressed)?;
        Self::from_public_key(&key)
    }

    /// Builds a `P256DIDKey` from a [`PublicKey`] on `ATProtoKeyCurve::P256`.
    pub fn from_public_key(key: &PublicKey) -> Result<Self, PetrelCryptoError> {
        if key.curve() != ATProtoKeyCurve::P256 {
            return Err(PetrelCryptoError::UnsupportedAlgorithm(
                "not a P-256 key".into(),
            ));
        }
        Ok(Self {
            value: key.did_key(),
        })
    }

    /// Parses and validates a canonical P-256 `did:key:zDna...` string.
    pub fn parse(value: &str) -> Result<Self, PetrelCryptoError> {
        let encoded = value
            .strip_prefix("did:key:z")
            .filter(|_| value.len() <= 256)
            .ok_or_else(|| PetrelCryptoError::InvalidIdentifier("P-256 did:key".into()))?;
        let decoded = Base58BTC::decode(encoded)
            .map_err(|_| PetrelCryptoError::InvalidIdentifier("P-256 did:key".into()))?;
        if Base58BTC::encode(&decoded) != encoded
            || decoded.len() != 35
            || decoded[..2] != [0x80, 0x24]
        {
            return Err(PetrelCryptoError::InvalidIdentifier("P-256 did:key".into()));
        }
        let key = PublicKey::from_sec1(ATProtoKeyCurve::P256, &decoded[2..])
            .map_err(|_| PetrelCryptoError::InvalidIdentifier("P-256 did:key".into()))?;
        if key.compressed_representation() != &decoded[2..] {
            return Err(PetrelCryptoError::InvalidIdentifier("P-256 did:key".into()));
        }
        Ok(Self {
            value: value.to_owned(),
        })
    }

    /// Returns the `did:key:z...` string slice.
    pub fn as_str(&self) -> &str {
        &self.value
    }

    /// Consumes `self` and returns the inner `did:key:z...` string.
    pub fn into_string(self) -> String {
        self.value
    }

    /// Returns the 33-byte compressed P-256 point bytes.
    pub fn compressed_bytes(&self) -> Result<[u8; 33], PetrelCryptoError> {
        let encoded = self
            .value
            .strip_prefix("did:key:z")
            .ok_or_else(|| PetrelCryptoError::InvalidIdentifier("P-256 did:key".into()))?;
        let decoded = Base58BTC::decode(encoded)?;
        decoded
            .get(2..)
            .and_then(|s| <[u8; 33]>::try_from(s).ok())
            .ok_or_else(|| PetrelCryptoError::InvalidIdentifier("P-256 did:key".into()))
    }

    /// Decodes the underlying validated [`PublicKey`].
    pub fn public_key(&self) -> Result<PublicKey, PetrelCryptoError> {
        let compressed = self.compressed_bytes()?;
        PublicKey::from_sec1(ATProtoKeyCurve::P256, &compressed)
    }
}

impl fmt::Display for P256DIDKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.value)
    }
}

impl FromStr for P256DIDKey {
    type Err = PetrelCryptoError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Self::parse(s)
    }
}

impl Serialize for P256DIDKey {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        serializer.serialize_str(&self.value)
    }
}

impl<'de> Deserialize<'de> for P256DIDKey {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let raw = String::deserialize(deserializer)?;
        Self::parse(&raw).map_err(serde::de::Error::custom)
    }
}
