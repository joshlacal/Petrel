//! Cryptographic error types.

/// Errors returned by AT Protocol cryptographic, key-codec, and token primitives.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[non_exhaustive]
pub enum PetrelCryptoError {
    /// A `did:key`, multikey, multibase, or service reference identifier was invalid.
    #[error("Invalid identifier: {0}")]
    InvalidIdentifier(String),
    /// Input bytes, key scalar, signature encoding, or JSON payload was malformed.
    #[error("Malformed data: {0}")]
    Malformed(String),
    /// A token or signature failed an authorization or verification check.
    #[error("Unauthorized: {0}")]
    Unauthorized(String),
    /// An algorithm, curve, or verification-method type is unsupported or mismatched.
    #[error("Unsupported algorithm: {0}")]
    UnsupportedAlgorithm(String),
    /// A token's `exp` claim is in the past beyond the allowed clock skew.
    #[error("Expired")]
    Expired,
    /// Operating system entropy was unavailable.
    #[error("Operating system entropy unavailable")]
    Entropy,
}
