//! HPKE P-256 KEM and `did:key` utilities wrapping `petrel_crypto::SpaceMAC`.

use petrel_crypto::{P256DIDKey, P256Keypair, SpaceMAC, SpaceMACEncapsulation};
use zeroize::Zeroizing;

use crate::error::{Result, SpaceError};

/// Encapsulate an ephemeral HPKE P-256 key share and derive a 32-byte shared MAC secret
/// toward a recipient's `did:key:` P-256 public key.
pub fn encapsulate_p256(recipient_did_key: &str) -> Result<SpaceMACEncapsulation> {
    SpaceMAC::encapsulate(recipient_did_key).map_err(|e| SpaceError::KemError(e.to_string()))
}

/// Deterministic HPKE P-256 encapsulation using a fixed 32-byte ephemeral private key scalar
/// (for vector conformance testing).
pub fn encapsulate_p256_with_ephemeral(
    recipient_did_key: &str,
    ephemeral_secret: &[u8; 32],
) -> Result<SpaceMACEncapsulation> {
    SpaceMAC::encapsulate_with_ephemeral(recipient_did_key, ephemeral_secret)
        .map_err(|e| SpaceError::KemError(e.to_string()))
}

/// Decapsulate the shared 32-byte MAC secret from an ephemeral `did:key:` share
/// using the recipient's 32-byte raw P-256 private scalar.
pub fn decapsulate_p256(
    recipient_secret: &[u8; 32],
    key_share_did_key: &str,
) -> Result<Zeroizing<[u8; 32]>> {
    SpaceMAC::decapsulate(recipient_secret, key_share_did_key)
        .map_err(|e| SpaceError::KemError(e.to_string()))
}

/// Decode a P-256 `did:key:` into its 33-byte compressed SEC1 public point.
pub fn decode_p256_did_key(did_key: &str) -> Result<Vec<u8>> {
    let parsed =
        P256DIDKey::parse(did_key).map_err(|e| SpaceError::InvalidKemKey(e.to_string()))?;
    let bytes = parsed
        .compressed_bytes()
        .map_err(|e| SpaceError::InvalidKemKey(e.to_string()))?;
    Ok(bytes.to_vec())
}

/// Encode a 33-byte compressed SEC1 P-256 public point as a `did:key:` multikey string.
pub fn encode_p256_did_key(compressed_sec1: &[u8]) -> Result<String> {
    let arr: [u8; 33] = compressed_sec1
        .try_into()
        .map_err(|_| SpaceError::InvalidKemKey("compressed P-256 key must be 33 bytes".into()))?;
    let parsed = P256DIDKey::from_compressed_bytes(&arr)
        .map_err(|e| SpaceError::InvalidKemKey(e.to_string()))?;
    Ok(parsed.into_string())
}

/// Generate a fresh P-256 keypair, returning `(raw_32_byte_secret, did_key)`.
pub fn generate_p256_keypair() -> Result<(Zeroizing<[u8; 32]>, String)> {
    let kp = P256Keypair::generate().map_err(|e| SpaceError::KemError(e.to_string()))?;
    let raw = kp.export_raw_representation();
    let did_key = kp.did_key();
    Ok((raw, did_key))
}
