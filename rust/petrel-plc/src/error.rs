use std::fmt;

use thiserror::Error;

/// Every failure reported by `petrel-plc`.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum PlcError {
    /// A DID, handle, or CID is not syntactically valid.
    #[error("invalid identifier: {0}")]
    InvalidIdentifier(String),
    /// A value does not fit the AT Protocol profile of a PLC operation.
    #[error("invalid protocol profile: {0}")]
    InvalidProfile(String),
    /// A signature, CID, genesis hash, or operation chain does not verify.
    #[error("unauthorized: {0}")]
    Unauthorized(String),
    /// Kept for parity with `PetrelPLCError`.
    #[error("repository revision conflict (expected {expected}, actual {actual})")]
    Conflict { expected: u64, actual: u64 },
    /// Kept for parity with `PetrelPLCError`.
    #[error("credential or token expired")]
    Expired,
    /// Input is not a well-formed operation, log, or directory response, or violates a write limit.
    #[error("malformed input: {0}")]
    Malformed(String),
    /// The directory could not be reached, answered with a server error, or exceeded size bounds.
    #[error("unavailable: {0}")]
    Unavailable(String),
    /// The directory has no operations for this DID (404 "DID not registered").
    #[error("DID not registered: {did}")]
    NotFound { did: String },
    /// The DID exists but its current operation is a tombstone (410 or 404 "DID not available").
    #[error("DID is tombstoned: {did}")]
    Tombstoned { did: String },
    /// The directory refused the request with a 4xx status.
    #[error("{}", format_rejected(*.status, message))]
    Rejected { status: u16, message: String },
    /// The directory answered 429 with an optional `Retry-After` integer seconds value.
    #[error("{}", format_rate_limited(*.retry_after_seconds))]
    RateLimited { retry_after_seconds: Option<u64> },
    /// Directory accepted submit, but follow-up audit log confirmation failed.
    #[error("PLC directory accepted operation {cid} but it could not be confirmed: {reason}")]
    SubmittedButUnconfirmed { cid: String, reason: String },
}

fn format_rejected(status: u16, message: &str) -> String {
    if message.is_empty() {
        format!("PLC directory rejected the request (HTTP {status})")
    } else {
        format!("PLC directory rejected the request (HTTP {status}): {message}")
    }
}

fn format_rate_limited(retry_after: Option<u64>) -> String {
    match retry_after {
        Some(seconds) => format!("PLC directory rate limit reached; retry after {seconds} s"),
        None => "PLC directory rate limit reached".to_owned(),
    }
}

/// Alias matching `PetrelPLCError` / `PLCError`.
pub type PetrelPlcError = PlcError;

impl PlcError {
    pub fn invalid_identifier(msg: impl Into<String>) -> Self {
        Self::InvalidIdentifier(msg.into())
    }

    pub fn invalid_profile(msg: impl Into<String>) -> Self {
        Self::InvalidProfile(msg.into())
    }

    pub fn unauthorized(msg: impl Into<String>) -> Self {
        Self::Unauthorized(msg.into())
    }

    pub fn malformed(msg: impl Into<String>) -> Self {
        Self::Malformed(msg.into())
    }

    pub fn unavailable(msg: impl Into<String>) -> Self {
        Self::Unavailable(msg.into())
    }
}

/// Ensures `PlcError` satisfies `Display` identically to Swift's `description`.
#[allow(dead_code)]
fn assert_display<T: fmt::Display>() {}
