//! AT Protocol signature encoding, verification policies, and low-S canonicalization.

use crate::curve::ATProtoKeyCurve;
use crate::error::PetrelCryptoError;
use crate::scalar::{
    COMPACT_SIGNATURE_BYTE_COUNT, SCALAR_BYTE_COUNT, is_low, is_structurally_valid, low_s_form,
};

/// How strictly a signature's encoding is checked before the ECDSA equation is evaluated.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct ATProtoSignatureVerificationOptions {
    /// Accept `(r, n - s)` as well as `(r, s)`.
    pub allow_high_s: bool,
    /// Accept an ASN.1 DER `ECDSA-Sig-Value` as well as 64-byte `r || s`.
    pub allow_der: bool,
}

impl ATProtoSignatureVerificationOptions {
    /// 64-byte compact encoding, low-S only. Required for commits, labels,
    /// PLC operations, and every other signature over a CBOR object.
    pub const STRICT: Self = Self {
        allow_high_s: false,
        allow_der: false,
    };

    /// 64-byte compact encoding (RFC 7518 section 3.4), either S value.
    /// Used for service-auth and OAuth JWTs.
    pub const JWT: Self = Self {
        allow_high_s: true,
        allow_der: false,
    };

    /// Either S value and either encoding (DER or compact), matching
    /// `@atproto/crypto`'s `allowMalleableSig: true`.
    pub const ALLOW_MALLEABLE: Self = Self {
        allow_high_s: true,
        allow_der: true,
    };

    /// Creates a custom signature encoding policy.
    pub const fn new(allow_high_s: bool, allow_der: bool) -> Self {
        Self {
            allow_high_s,
            allow_der,
        }
    }
}

impl Default for ATProtoSignatureVerificationOptions {
    fn default() -> Self {
        Self::STRICT
    }
}

/// Encoding rules for AT Protocol ECDSA signatures on both curves.
#[derive(Debug, Clone, Copy)]
pub struct ATProtoSignature;

impl ATProtoSignature {
    /// Length in bytes of the compact `r || s` wire encoding.
    pub const COMPACT_BYTE_COUNT: usize = COMPACT_SIGNATURE_BYTE_COUNT;

    /// Returns `true` iff `signature` is 64 bytes with `0 < r < n` and `0 < s <= floor(n / 2)`.
    pub fn is_canonical(signature: &[u8], curve: ATProtoKeyCurve) -> bool {
        is_structurally_valid(signature, curve) && is_low(&signature[SCALAR_BYTE_COUNT..], curve)
    }

    /// Returns `true` iff `signature` is 64 bytes and its S half is at most `floor(n / 2)`.
    pub fn is_low_s(signature: &[u8], curve: ATProtoKeyCurve) -> bool {
        signature.len() == Self::COMPACT_BYTE_COUNT
            && is_low(&signature[SCALAR_BYTE_COUNT..], curve)
    }

    /// Converts a signature produced by a trusted local signer into the canonical
    /// wire form: 64-byte compact, low-S.
    ///
    /// Accepts either 64-byte `r || s` or ASN.1 DER. Never call this on an
    /// untrusted signature from the network to bypass malleability checks.
    pub fn canonicalize(
        signature: &[u8],
        curve: ATProtoKeyCurve,
    ) -> Result<[u8; 64], PetrelCryptoError> {
        let compact = if signature.len() == Self::COMPACT_BYTE_COUNT {
            let mut buf = [0_u8; 64];
            buf.copy_from_slice(signature);
            buf
        } else {
            Self::compact_from_der(signature, curve)?
        };
        if !is_structurally_valid(&compact, curve) {
            return Err(PetrelCryptoError::Malformed(format!(
                "{} signature scalar is out of range",
                curve.jwt_algorithm()
            )));
        }
        Ok(low_s_form(&compact, curve))
    }

    /// Strictly parses an ASN.1 DER `ECDSA-Sig-Value` into 64-byte `r || s` without modifying S.
    pub fn compact_from_der(
        der: &[u8],
        curve: ATProtoKeyCurve,
    ) -> Result<[u8; 64], PetrelCryptoError> {
        match curve {
            ATProtoKeyCurve::P256 => {
                let sig = p256::ecdsa::Signature::from_der(der).map_err(|_| {
                    PetrelCryptoError::Malformed("P-256 DER signature is malformed".into())
                })?;
                Ok(sig.to_bytes().into())
            }
            ATProtoKeyCurve::Secp256k1 => {
                let sig = k256::ecdsa::Signature::from_der(der).map_err(|_| {
                    PetrelCryptoError::Malformed("K-256 DER signature is malformed".into())
                })?;
                Ok(sig.to_bytes().into())
            }
        }
    }

    /// Returns the compact candidate encodings denoted by `signature` under `options`,
    /// reading DER first (matching `@atproto/crypto`).
    pub(crate) fn compact_candidates(
        signature: &[u8],
        curve: ATProtoKeyCurve,
        options: ATProtoSignatureVerificationOptions,
    ) -> Vec<[u8; 64]> {
        let mut candidates = Vec::new();
        if options.allow_der
            && signature.first() == Some(&0x30)
            && let Ok(from_der) = Self::compact_from_der(signature, curve)
        {
            candidates.push(from_der);
        }
        if let Ok(compact) = <[u8; 64]>::try_from(signature) {
            candidates.push(compact);
        }
        candidates
    }
}

/// Canonical raw P-256 signatures matching Swift `P256WireSignature`.
#[derive(Debug, Clone, Copy)]
pub struct P256WireSignature;

impl P256WireSignature {
    /// Length in bytes of the compact `r || s` encoding.
    pub const RAW_BYTE_COUNT: usize = 64;

    /// Normalizes a structurally valid raw P-256 signature to low-S form.
    pub fn canonicalize(raw: &[u8]) -> Result<[u8; 64], PetrelCryptoError> {
        let compact = Self::validate_scalars(raw)?;
        p256::ecdsa::Signature::from_bytes((&compact).into())
            .map_err(|_| PetrelCryptoError::Malformed("P-256 signature is malformed".into()))?;
        Ok(low_s_form(&compact, ATProtoKeyCurve::P256))
    }

    /// Rejects non-canonical or high-S raw P-256 signatures.
    pub fn decode_canonical(raw: &[u8]) -> Result<[u8; 64], PetrelCryptoError> {
        let compact = Self::validate_scalars(raw)?;
        if !is_low(&compact[SCALAR_BYTE_COUNT..], ATProtoKeyCurve::P256) {
            return Err(PetrelCryptoError::Malformed(
                "P-256 signature is not canonical low-S".into(),
            ));
        }
        p256::ecdsa::Signature::from_bytes((&compact).into())
            .map_err(|_| PetrelCryptoError::Malformed("P-256 signature is malformed".into()))?;
        Ok(compact)
    }

    /// Returns `true` iff `raw` is 64 bytes with `0 < r < n` and `0 < s <= floor(n / 2)`.
    pub fn is_canonical_low_s(raw: &[u8]) -> bool {
        Self::decode_canonical(raw).is_ok()
    }

    /// Decodes a raw 64-byte P-256 signature while permitting high-S (e.g., JOSE/WebCrypto).
    pub fn decode_malleability_tolerant(raw: &[u8]) -> Result<[u8; 64], PetrelCryptoError> {
        let compact = Self::validate_scalars(raw)?;
        p256::ecdsa::Signature::from_bytes((&compact).into())
            .map_err(|_| PetrelCryptoError::Malformed("P-256 signature is malformed".into()))?;
        Ok(compact)
    }

    fn validate_scalars(raw: &[u8]) -> Result<[u8; 64], PetrelCryptoError> {
        let compact: [u8; 64] = raw
            .try_into()
            .map_err(|_| PetrelCryptoError::Malformed("P-256 signature must be 64 bytes".into()))?;
        if !is_structurally_valid(&compact, ATProtoKeyCurve::P256) {
            return Err(PetrelCryptoError::Malformed(
                "P-256 signature scalar is invalid".into(),
            ));
        }
        Ok(compact)
    }
}
