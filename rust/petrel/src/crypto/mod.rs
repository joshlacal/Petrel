//! ES256, JWS, JWK and DPoP primitives.
//!
//! Contract 9 of the Petrel Rust plan lives here and is frozen:
//! [`DpopSigner`], with [`EcPublicJwk`] and [`CryptoError`].
//!
//! Lane E adds here (map: `maps/oauth-auth.md`, package O3): hand-rolled
//! compact JWS, DPoP proofs and RFC 7638 thumbprints on `p256` 0.13 and
//! `sha2` 0.10 (plan decision 8), and an in-memory software [`DpopSigner`].
//!
//! Two rules for that work:
//!
//! - **Every signature is low-S.** `p256` does not normalize on sign, so the
//!   code normalizes unconditionally and a test asserts it for every
//!   signature. A high-S signature is refused on verify.
//! - **No `p256` types in public APIs.** Keys cross this module's boundary as
//!   bytes or as [`EcPublicJwk`], so the later move to the 0.14 line stays
//!   internal.

mod jose;

pub(crate) use jose::{Jwk, finish_es256_jws, jws_signing_input, split_compact_jws};
pub use jose::{
    MAX_JWS_JSON_BYTES, SoftwareDpopSigner, base64url, decode_base64url, normalize_es256,
    pkce_challenge, pkce_verifier, random_bytes, sha256,
};

use crate::rt::{BoxFuture, MaybeSend, MaybeSync};

/// A P-256 public key as a JWK (`kty: "EC"`, `crv: "P-256"`).
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct EcPublicJwk {
    /// The x coordinate, base64url without padding.
    pub x: String,
    /// The y coordinate, base64url without padding.
    pub y: String,
}

/// A cryptographic operation failed.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[non_exhaustive]
pub enum CryptoError {
    #[error("operating system entropy unavailable")]
    Entropy,
    #[error("invalid P-256 key")]
    InvalidKey,
    #[error("invalid ES256 signature")]
    InvalidSignature,
    #[error("ES256 signing failed")]
    SigningFailed,
    #[error("invalid base64url")]
    InvalidEncoding,
    #[error("encoded value exceeds its size limit")]
    TooLarge,
    #[error("invalid compact JWS")]
    InvalidJws,
    /// The key could not be used (missing, wrong type, not permitted).
    #[error("key unavailable: {0}")]
    KeyUnavailable(String),
    /// Signing failed.
    #[error("signing failed: {0}")]
    Signing(String),
    /// Key material or a signature was malformed.
    #[error("malformed input: {0}")]
    Malformed(String),
}

/// Signs DPoP proofs with an ES256 key.
///
/// A trait rather than key bytes so the web build can hold a non-extractable
/// WebCrypto key. Signing is asynchronous for the same reason: WebCrypto only
/// offers a promise.
pub trait DpopSigner: MaybeSend + MaybeSync {
    /// The public half, for the proof's `jwk` header and the `jkt`
    /// thumbprint.
    fn public_jwk(&self) -> EcPublicJwk;

    /// Signs the JWS signing input (`base64url(header).base64url(claims)`)
    /// with ECDSA P-256 over SHA-256.
    ///
    /// Returns the raw 64-byte `r ‖ s` form, **low-S normalized**. Not DER.
    fn sign<'a>(&'a self, signing_input: &'a [u8]) -> BoxFuture<'a, Result<[u8; 64], CryptoError>>;
}
