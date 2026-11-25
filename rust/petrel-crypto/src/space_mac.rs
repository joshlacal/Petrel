//! Spaces response authentication via HPKE secret export
//! (DHKEM P-256 / HKDF-SHA256 / Export-only) and HMAC-SHA256.

use hmac::{Hmac, Mac};
use p256::elliptic_curve::sec1::ToEncodedPoint as _;
use p256::{PublicKey as P256PublicKey, SecretKey as P256SecretKey};
use sha2::Sha256;
use zeroize::Zeroizing;

use crate::did_key::P256DIDKey;

type HmacSha256 = Hmac<Sha256>;

const HASH_BYTE_COUNT: usize = 32;
const KEM_ID: [u8; 5] = [b'K', b'E', b'M', 0x00, 0x10];
const SUITE_ID: [u8; 10] = [b'H', b'P', b'K', b'E', 0x00, 0x10, 0x00, 0x01, 0xff, 0xff];

/// Errors returned by [`SpaceMAC`] encapsulation, decapsulation, and MAC verification.
#[derive(Debug, Clone, Copy, PartialEq, Eq, thiserror::Error)]
pub enum SpaceMACError {
    /// Public key, private scalar, or shared secret was invalid.
    #[error("invalid SpaceMAC key")]
    InvalidKey,
    /// HKDF context or length parameter was invalid.
    #[error("invalid SpaceMAC HPKE context")]
    InvalidContext,
    /// Authentication code did not verify.
    #[error("SpaceMAC authentication mismatch")]
    Mismatch,
    /// Operating system entropy was unavailable.
    #[error("operating system entropy unavailable")]
    Entropy,
}

/// Output of encapsulating a fresh SpaceMAC secret to an author's `did:key`.
#[derive(Clone, PartialEq, Eq)]
#[allow(clippy::upper_case_acronyms)]
pub struct SpaceMACEncapsulation {
    /// Ephemeral sender `did:key` (`P256DIDKey`).
    pub key_share: String,
    /// Derived 32-byte HPKE exported shared secret.
    pub shared_secret: Zeroizing<[u8; 32]>,
}

impl std::fmt::Debug for SpaceMACEncapsulation {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("SpaceMACEncapsulation")
            .field("key_share", &self.key_share)
            .finish_non_exhaustive()
    }
}

/// Spaces response authentication using HPKE DHKEM(P-256, HKDF-SHA256) export-only.
#[derive(Debug, Clone, Copy)]
#[allow(clippy::upper_case_acronyms)]
pub struct SpaceMAC;

impl SpaceMAC {
    /// Generates a fresh ephemeral P-256 key and derives a shared secret for `author_key`.
    pub fn encapsulate(author_key: &str) -> Result<SpaceMACEncapsulation, SpaceMACError> {
        let ephemeral = loop {
            let mut bytes = Zeroizing::new([0_u8; 32]);
            getrandom::getrandom(&mut *bytes).map_err(|_| SpaceMACError::Entropy)?;
            if let Ok(key) = P256SecretKey::from_slice(&*bytes) {
                break key;
            }
        };
        Self::encapsulate_with_key(author_key, &ephemeral)
    }

    /// Deterministic encapsulation entry point for cross-language and RFC 9180 vectors.
    pub fn encapsulate_with_ephemeral(
        author_key: &str,
        ephemeral_secret: &[u8; 32],
    ) -> Result<SpaceMACEncapsulation, SpaceMACError> {
        let ephemeral =
            P256SecretKey::from_slice(ephemeral_secret).map_err(|_| SpaceMACError::InvalidKey)?;
        Self::encapsulate_with_key(author_key, &ephemeral)
    }

    fn encapsulate_with_key(
        author_key: &str,
        ephemeral: &P256SecretKey,
    ) -> Result<SpaceMACEncapsulation, SpaceMACError> {
        let author = agreement_key(author_key)?;
        let eph_pub = ephemeral.public_key();
        let compressed: [u8; 33] = eph_pub
            .to_encoded_point(true)
            .as_bytes()
            .try_into()
            .map_err(|_| SpaceMACError::InvalidKey)?;
        let key_share = P256DIDKey::from_compressed_bytes(&compressed)
            .map_err(|_| SpaceMACError::InvalidKey)?
            .into_string();
        let shared_secret = derive(ephemeral, &author, &eph_pub, &author)?;
        Ok(SpaceMACEncapsulation {
            key_share,
            shared_secret,
        })
    }

    /// Decapsulates the 32-byte shared secret from a `key_share` (`did:key`) using the
    /// recipient's 32-byte P-256 private scalar.
    pub fn decapsulate(
        private_key: &[u8; 32],
        key_share: &str,
    ) -> Result<Zeroizing<[u8; 32]>, SpaceMACError> {
        let recipient =
            P256SecretKey::from_slice(private_key).map_err(|_| SpaceMACError::InvalidKey)?;
        let sender = agreement_key(key_share)?;
        let recipient_pub = recipient.public_key();
        derive(&recipient, &sender, &sender, &recipient_pub)
    }

    /// Computes the 32-byte HMAC-SHA256 authentication code for `message` under `shared_secret`.
    pub fn authentication_code(
        message: &[u8],
        shared_secret: &[u8],
    ) -> Result<[u8; 32], SpaceMACError> {
        if shared_secret.len() != HASH_BYTE_COUNT {
            return Err(SpaceMACError::InvalidKey);
        }
        let mut mac =
            HmacSha256::new_from_slice(shared_secret).map_err(|_| SpaceMACError::InvalidKey)?;
        mac.update(message);
        Ok(mac.finalize().into_bytes().into())
    }

    /// Constant-time verification of an HMAC-SHA256 `authentication_code` over `message`.
    pub fn verify(
        authentication_code: &[u8],
        message: &[u8],
        shared_secret: &[u8],
    ) -> Result<(), SpaceMACError> {
        if shared_secret.len() != HASH_BYTE_COUNT {
            return Err(SpaceMACError::InvalidKey);
        }
        if authentication_code.len() != HASH_BYTE_COUNT {
            return Err(SpaceMACError::Mismatch);
        }
        let mut mac =
            HmacSha256::new_from_slice(shared_secret).map_err(|_| SpaceMACError::InvalidKey)?;
        mac.update(message);
        mac.verify_slice(authentication_code)
            .map_err(|_| SpaceMACError::Mismatch)
    }
}

fn agreement_key(did_key: &str) -> Result<P256PublicKey, SpaceMACError> {
    let parsed = P256DIDKey::parse(did_key).map_err(|_| SpaceMACError::InvalidKey)?;
    let compressed = parsed
        .compressed_bytes()
        .map_err(|_| SpaceMACError::InvalidKey)?;
    P256PublicKey::from_sec1_bytes(&compressed).map_err(|_| SpaceMACError::InvalidKey)
}

fn derive(
    private_key: &P256SecretKey,
    public_key: &P256PublicKey,
    sender: &P256PublicKey,
    recipient: &P256PublicKey,
) -> Result<Zeroizing<[u8; 32]>, SpaceMACError> {
    let dh = p256::ecdh::diffie_hellman(private_key.to_nonzero_scalar(), public_key.as_affine());
    let dh_bytes: Zeroizing<[u8; 32]> = Zeroizing::new((*dh.raw_secret_bytes()).into());

    let eae_prk = labeled_extract(&KEM_ID, &[], b"eae_prk", &*dh_bytes)?;
    let sender_uncompressed = sender.to_encoded_point(false);
    let recipient_uncompressed = recipient.to_encoded_point(false);
    let mut kem_context = Vec::with_capacity(130);
    kem_context.extend_from_slice(sender_uncompressed.as_bytes());
    kem_context.extend_from_slice(recipient_uncompressed.as_bytes());
    let kem_secret = labeled_expand_32(&KEM_ID, &eae_prk, b"shared_secret", &kem_context)?;

    let psk_id_hash = labeled_extract(&SUITE_ID, &[], b"psk_id_hash", &[])?;
    let info_hash = labeled_extract(&SUITE_ID, &[], b"info_hash", b"atproto-mac")?;
    let mut key_schedule_context = Vec::with_capacity(1 + 32 + 32);
    key_schedule_context.push(0);
    key_schedule_context.extend_from_slice(&*psk_id_hash);
    key_schedule_context.extend_from_slice(&*info_hash);

    let secret = labeled_extract(&SUITE_ID, kem_secret.as_slice(), b"secret", &[])?;
    let exporter_secret = labeled_expand_32(&SUITE_ID, &secret, b"exp", &key_schedule_context)?;
    labeled_expand_32(&SUITE_ID, &exporter_secret, b"sec", &[])
}

fn labeled_extract(
    id: &[u8],
    salt: &[u8],
    label: &[u8],
    input: &[u8],
) -> Result<Zeroizing<[u8; 32]>, SpaceMACError> {
    let mut ikm = Vec::with_capacity(7 + id.len() + label.len() + input.len());
    ikm.extend_from_slice(b"HPKE-v1");
    ikm.extend_from_slice(id);
    ikm.extend_from_slice(label);
    ikm.extend_from_slice(input);
    hkdf_extract(salt, &ikm)
}

fn labeled_expand_32(
    id: &[u8],
    prk: &[u8; 32],
    label: &[u8],
    info: &[u8],
) -> Result<Zeroizing<[u8; 32]>, SpaceMACError> {
    let len_bytes = 32_u16.to_be_bytes();
    let mut labeled_info = Vec::with_capacity(2 + 7 + id.len() + label.len() + info.len());
    labeled_info.extend_from_slice(&len_bytes);
    labeled_info.extend_from_slice(b"HPKE-v1");
    labeled_info.extend_from_slice(id);
    labeled_info.extend_from_slice(label);
    labeled_info.extend_from_slice(info);
    hkdf_expand_32(prk, &labeled_info)
}

fn hkdf_extract(salt: &[u8], input: &[u8]) -> Result<Zeroizing<[u8; 32]>, SpaceMACError> {
    let zero_salt = [0_u8; HASH_BYTE_COUNT];
    let effective_salt = if salt.is_empty() { &zero_salt } else { salt };
    let mut mac =
        HmacSha256::new_from_slice(effective_salt).map_err(|_| SpaceMACError::InvalidContext)?;
    mac.update(input);
    let bytes: [u8; 32] = mac.finalize().into_bytes().into();
    Ok(Zeroizing::new(bytes))
}

fn hkdf_expand_32(prk: &[u8; 32], info: &[u8]) -> Result<Zeroizing<[u8; 32]>, SpaceMACError> {
    let mut mac = HmacSha256::new_from_slice(prk).map_err(|_| SpaceMACError::InvalidContext)?;
    mac.update(info);
    mac.update(&[1_u8]);
    let bytes: [u8; 32] = mac.finalize().into_bytes().into();
    Ok(Zeroizing::new(bytes))
}
