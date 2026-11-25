use core::fmt;
use core::str::FromStr;

use petrel_core::{Cid, Did, SpaceRef};
use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Unified error type for AT Protocol Spaces operations.
#[derive(Debug, Error, Clone, PartialEq, Eq)]
#[non_exhaustive]
pub enum SpaceError {
    /// Invalid `at:space/` space reference string.
    #[error("invalid space reference: {0}")]
    InvalidSpaceRef(String),

    /// Legacy `at://<did>/space/...` URI rejected under Nov 24 alpha rules.
    #[error("legacy at:// space URI is not accepted; expected at:space/... URI: {0}")]
    LegacySpaceUriRejected(String),

    /// Invalid AT-URI or URL syntax.
    #[error("invalid URI: {0}")]
    InvalidUri(String),

    /// Invalid DID syntax.
    #[error("invalid DID: {0}")]
    InvalidDid(String),

    /// Invalid NSID syntax.
    #[error("invalid NSID: {0}")]
    InvalidNsid(String),

    /// Invalid record key syntax.
    #[error("invalid record key: {0}")]
    InvalidRecordKey(String),

    /// Invalid TID syntax.
    #[error("invalid TID: {0}")]
    InvalidTid(String),

    /// Invalid CID syntax or encoding.
    #[error("invalid CID: {0}")]
    InvalidCid(String),

    /// JWT does not consist of 3 dot-separated base64url segments or has malformed structure.
    #[error("invalid JWT format")]
    InvalidTokenFormat,

    /// JWT `alg` header is unsupported.
    #[error("unsupported JWT algorithm: {0}")]
    UnsupportedAlgorithm(String),

    /// JWT `typ` header does not match expected token type.
    #[error("unsupported JWT type: {0}")]
    UnsupportedTokenType(String),

    /// Cryptographic signature verification failed.
    #[error("invalid signature")]
    InvalidSignature,

    /// JWT or HTTP header is malformed.
    #[error("malformed header: {0}")]
    MalformedHeader(String),

    /// JWT claims or HTTP body payload is malformed.
    #[error("malformed payload: {0}")]
    MalformedPayload(String),

    /// JWT `aud` claim does not match expected audience DID.
    #[error("invalid JWT audience: expected {expected}, got {actual}")]
    InvalidAudience { expected: String, actual: String },

    /// Required audience header or claim is missing.
    #[error("missing audience")]
    MissingAudience,

    /// JWT `sub` claim is not a valid Nov 24 `at:space/` URI or does not match expected space.
    #[error("invalid JWT subject: {0}")]
    InvalidSubject(String),

    /// JWT `iat` is in the future beyond allowed clock skew.
    #[error("token not yet valid (now={now}, iat={iat})")]
    TokenNotYetValid { now: i64, iat: i64 },

    /// JWT `exp` has passed beyond allowed clock skew.
    #[error("token expired (now={now}, exp={exp})")]
    TokenExpired { now: i64, exp: i64 },

    /// JWT lifetime exceeds protocol maximum.
    #[error("token lifetime {lifetime}s exceeds maximum {max}s")]
    TokenLifetimeTooLong { lifetime: i64, max: i64 },

    /// Timestamp freshness check failed.
    #[error("clock skew exceeded")]
    ClockSkewExceeded,

    /// No DID document was found for the DID.
    #[error("DID document not found for {0}")]
    DidDocumentNotFound(String),

    /// DID resolution failed.
    #[error("DID resolution failed: {0}")]
    DidResolutionFailed(String),

    /// Expected verification method or KEM key was missing in the DID document.
    #[error("signing or KEM key not found: {0}")]
    SigningKeyNotFound(String),

    /// Cryptographic key material is invalid.
    #[error("invalid key material: {0}")]
    InvalidKeyMaterial(String),

    /// Credential `cnf.kid` does not match the proof key.
    #[error("credential proof key mismatch")]
    KeyMismatch,

    /// RFC 9421 `Signature` or `Signature-Input` header is malformed or does not meet requirements.
    #[error("invalid HTTP signature header: {0}")]
    InvalidSignatureHeader(String),

    /// Unsupported or unexpected covered component in RFC 9421 `Signature-Input`.
    #[error("unsupported signature component: {0}")]
    UnsupportedSignatureComponent(String),

    /// Credential presentation `(iss, sub, jti, nonce)` or `jti` was replayed.
    #[error("signature replay detected")]
    SignatureReplay,

    /// Required HTTP header is missing.
    #[error("missing HTTP header: {0}")]
    MissingHeader(String),

    /// HTTP signature `created` timestamp is outside the freshness window.
    #[error("invalid or stale HTTP signature timestamp: {0}")]
    InvalidTimestamp(String),

    /// Space MAC header (`Covered-Signature`, `Signature-Input`, `Signature`) is invalid.
    #[error("invalid Space MAC header: {0}")]
    InvalidMacHeader(String),

    /// Space MAC tag verification failed.
    #[error("Space MAC mismatch")]
    MacMismatch,

    /// `Accept-Signature` header is invalid or uses an unsupported profile.
    #[error("invalid Accept-Signature header: {0}")]
    InvalidAcceptSignature(String),

    /// Invalid `#atproto_kem` key.
    #[error("invalid KEM key: {0}")]
    InvalidKemKey(String),

    /// Invalid HPKE ephemeral public key.
    #[error("invalid HPKE ephemeral key")]
    InvalidEphemeralKey,

    /// HPKE encapsulation/decapsulation failure.
    #[error("HPKE KEM error: {0}")]
    KemError(String),

    /// Malformed STAR archive container or entries.
    #[error("invalid STAR archive: {0}")]
    InvalidArchive(String),

    /// Archive or blob exceeds configured byte limit.
    #[error("archive size {actual} bytes exceeds maximum {max} bytes")]
    ArchiveTooLarge { actual: usize, max: usize },

    /// Invalid DAG-CBOR input.
    #[error("invalid DAG-CBOR: {0}")]
    InvalidCbor(String),

    /// DAG-CBOR encoding failed.
    #[error("DAG-CBOR encoding failed: {0}")]
    CborEncoding(String),

    /// Computed `SpaceSetHash` / `LtHash` digest does not match commit `data`.
    #[error("data hash mismatch: expected {expected}, got {actual}")]
    DataHashMismatch { expected: String, actual: String },

    /// Blob payloads are not supported by this operation.
    #[error("blob not supported: {0}")]
    BlobNotSupported(String),

    /// JSON integer outside the JavaScript safe integer range `[-2^53+1, 2^53-1]`.
    #[error("unsafe JSON integer for {0}")]
    UnsafeInteger(String),

    /// Space does not exist or is unknown to the authority/PDS.
    #[error("space not found: {0}")]
    SpaceNotFound(String),

    /// Space was permanently deleted by its authority.
    #[error("space deleted: {0}")]
    SpaceDeleted(String),

    /// Caller is not authorized for the space operation.
    #[error("unauthorized: {0}")]
    Unauthorized(String),

    /// Space authority refused authorization for the space.
    #[error("authorization refused for {space}{}", detail.as_deref().map(|d| format!(": {d}")).unwrap_or_default())]
    AuthorizationRefused {
        space: String,
        detail: Option<String>,
    },

    /// Delegation token was rejected by the space authority.
    #[error("delegation token rejected for {space}{}", detail.as_deref().map(|d| format!(": {d}")).unwrap_or_default())]
    TokenRejected {
        space: String,
        detail: Option<String>,
    },

    /// Operation forbidden.
    #[error("forbidden: {0}")]
    Forbidden(String),

    /// Credential was invalidated while an exchange was in flight.
    #[error("credential invalidated during in-flight exchange")]
    InvalidationDuringExchange,

    /// Remote host returned HTTP 429 rate limit.
    #[error("rate limited (retry_after={retry_after:?}s)")]
    TooManyRequests { retry_after: Option<u64> },

    /// HTTP transport error.
    #[error("transport error: {0}")]
    Transport(String),

    /// Unexpected HTTP response status.
    #[error("HTTP {status}{}{}", error.as_deref().map(|e| format!(" ({e})")).unwrap_or_default(), message.as_deref().map(|m| format!(": {m}")).unwrap_or_default())]
    HttpStatus {
        status: u16,
        error: Option<String>,
        message: Option<String>,
    },

    /// Named XRPC error response.
    #[error("XRPC error {error} (HTTP {status}){}", message.as_deref().map(|m| format!(": {m}")).unwrap_or_default())]
    Xrpc {
        status: u16,
        error: String,
        message: Option<String>,
    },

    /// Persistence/cache backend error.
    #[error("storage error: {0}")]
    Storage(String),

    /// Invalid configuration or missing host service.
    #[error("configuration error: {0}")]
    Configuration(String),
}

impl SpaceError {
    /// Returns the AT Protocol error name for HTTP XRPC error responses.
    pub fn atproto_error_name(&self) -> &'static str {
        match self {
            Self::InvalidSpaceRef(_)
            | Self::LegacySpaceUriRejected(_)
            | Self::InvalidUri(_)
            | Self::InvalidDid(_)
            | Self::InvalidNsid(_)
            | Self::InvalidRecordKey(_)
            | Self::InvalidTid(_)
            | Self::InvalidCid(_)
            | Self::InvalidTokenFormat
            | Self::UnsupportedAlgorithm(_)
            | Self::UnsupportedTokenType(_)
            | Self::MalformedHeader(_)
            | Self::MalformedPayload(_)
            | Self::InvalidAudience { .. }
            | Self::MissingAudience
            | Self::InvalidSubject(_)
            | Self::TokenLifetimeTooLong { .. }
            | Self::InvalidKeyMaterial(_)
            | Self::InvalidSignatureHeader(_)
            | Self::UnsupportedSignatureComponent(_)
            | Self::MissingHeader(_)
            | Self::InvalidAcceptSignature(_)
            | Self::InvalidKemKey(_)
            | Self::InvalidEphemeralKey
            | Self::InvalidArchive(_)
            | Self::ArchiveTooLarge { .. }
            | Self::InvalidCbor(_)
            | Self::CborEncoding(_)
            | Self::DataHashMismatch { .. }
            | Self::BlobNotSupported(_)
            | Self::UnsafeInteger(_) => "InvalidRequest",
            Self::InvalidSignature | Self::KeyMismatch | Self::Unauthorized(_) => {
                "AuthenticationRequired"
            }
            Self::TokenNotYetValid { .. }
            | Self::TokenExpired { .. }
            | Self::ClockSkewExceeded
            | Self::InvalidTimestamp(_) => "ExpiredToken",
            Self::SignatureReplay => "SignatureReplay",
            Self::TokenRejected { .. } => "InvalidToken",
            Self::AuthorizationRefused { .. } | Self::Forbidden(_) => "NotAuthorized",
            Self::SpaceNotFound(_) | Self::SpaceDeleted(_) => "SpaceNotFound",
            Self::InvalidMacHeader(_) | Self::MacMismatch => "InvalidSpaceMac",
            Self::TooManyRequests { .. } => "RateLimitExceeded",
            Self::DidDocumentNotFound(_)
            | Self::DidResolutionFailed(_)
            | Self::SigningKeyNotFound(_)
            | Self::KemError(_)
            | Self::InvalidationDuringExchange
            | Self::Transport(_)
            | Self::HttpStatus { .. }
            | Self::Xrpc { .. }
            | Self::Storage(_)
            | Self::Configuration(_) => "InternalServerError",
        }
    }

    /// Returns the HTTP status code corresponding to this error.
    pub fn http_status(&self) -> u16 {
        match self {
            Self::InvalidSpaceRef(_)
            | Self::LegacySpaceUriRejected(_)
            | Self::InvalidUri(_)
            | Self::InvalidDid(_)
            | Self::InvalidNsid(_)
            | Self::InvalidRecordKey(_)
            | Self::InvalidTid(_)
            | Self::InvalidCid(_)
            | Self::InvalidTokenFormat
            | Self::UnsupportedAlgorithm(_)
            | Self::UnsupportedTokenType(_)
            | Self::MalformedHeader(_)
            | Self::MalformedPayload(_)
            | Self::InvalidAudience { .. }
            | Self::MissingAudience
            | Self::InvalidSubject(_)
            | Self::TokenLifetimeTooLong { .. }
            | Self::InvalidKeyMaterial(_)
            | Self::InvalidSignatureHeader(_)
            | Self::UnsupportedSignatureComponent(_)
            | Self::MissingHeader(_)
            | Self::InvalidAcceptSignature(_)
            | Self::InvalidKemKey(_)
            | Self::InvalidEphemeralKey
            | Self::InvalidArchive(_)
            | Self::ArchiveTooLarge { .. }
            | Self::InvalidCbor(_)
            | Self::CborEncoding(_)
            | Self::DataHashMismatch { .. }
            | Self::BlobNotSupported(_)
            | Self::UnsafeInteger(_)
            | Self::InvalidMacHeader(_)
            | Self::MacMismatch => 400,
            Self::InvalidSignature
            | Self::KeyMismatch
            | Self::TokenNotYetValid { .. }
            | Self::TokenExpired { .. }
            | Self::ClockSkewExceeded
            | Self::InvalidTimestamp(_)
            | Self::SignatureReplay
            | Self::Unauthorized(_)
            | Self::TokenRejected { .. } => 401,
            Self::AuthorizationRefused { .. } | Self::Forbidden(_) => 403,
            Self::SpaceNotFound(_) => 404,
            Self::SpaceDeleted(_) => 410,
            Self::TooManyRequests { .. } => 429,
            Self::HttpStatus { status, .. } | Self::Xrpc { status, .. } => *status,
            Self::DidDocumentNotFound(_)
            | Self::DidResolutionFailed(_)
            | Self::SigningKeyNotFound(_)
            | Self::KemError(_)
            | Self::InvalidationDuringExchange
            | Self::Transport(_)
            | Self::Storage(_)
            | Self::Configuration(_) => 500,
        }
    }
}

/// Convenience `Result` alias for `petrel-spaces`.
pub type Result<T> = core::result::Result<T, SpaceError>;

/// Constant-time equality comparison for two byte slices.
pub fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let mut diff = 0u8;
    for (&x, &y) in a.iter().zip(b.iter()) {
        diff |= x ^ y;
    }
    diff == 0
}

/// Parse a Nov 24 alpha `at:space/` URI, returning a specific error if a legacy `at://.../space/...` URI was supplied.
pub fn parse_space_ref(raw: &str) -> Result<SpaceRef> {
    if raw.starts_with("at://") && raw[5..].contains("/space/") {
        return Err(SpaceError::LegacySpaceUriRejected(raw.to_owned()));
    }
    SpaceRef::parse(raw).map_err(|err| SpaceError::InvalidSpaceRef(err.to_string()))
}

/// Locator for a blob stored inside a space repo: `"{space}|{repo}|{cid}"`.
///
/// Only Nov 24 alpha `at:space/` space references are accepted.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct SpaceBlobLocator {
    pub space: SpaceRef,
    pub repo: Did,
    pub cid: Cid,
}

impl SpaceBlobLocator {
    /// Construct a new blob locator.
    pub fn new(space: SpaceRef, repo: Did, cid: Cid) -> Self {
        Self { space, repo, cid }
    }

    /// Encode as `"{space}|{repo}|{cid}"`.
    pub fn encode(&self) -> String {
        format!("{}|{}|{}", self.space, self.repo, self.cid)
    }

    /// Parse `"{space}|{repo}|{cid}"`, enforcing Nov 24 `at:space/` syntax.
    pub fn parse(raw: &str) -> Result<Self> {
        let mut parts = raw.split('|');
        let space_str = parts
            .next()
            .filter(|s| !s.is_empty())
            .ok_or_else(|| SpaceError::InvalidUri(format!("invalid blob locator: {raw}")))?;
        let repo_str = parts
            .next()
            .filter(|s| !s.is_empty())
            .ok_or_else(|| SpaceError::InvalidUri(format!("invalid blob locator: {raw}")))?;
        let cid_str = parts
            .next()
            .filter(|s| !s.is_empty())
            .ok_or_else(|| SpaceError::InvalidUri(format!("invalid blob locator: {raw}")))?;
        if parts.next().is_some() {
            return Err(SpaceError::InvalidUri(format!(
                "invalid blob locator (too many parts): {raw}"
            )));
        }

        let space = parse_space_ref(space_str)?;
        let repo = Did::parse(repo_str).map_err(|e| SpaceError::InvalidDid(e.to_string()))?;
        let cid = Cid::parse(cid_str).map_err(|e| SpaceError::InvalidCid(e.to_string()))?;
        Ok(Self { space, repo, cid })
    }
}

impl fmt::Display for SpaceBlobLocator {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}|{}|{}", self.space, self.repo, self.cid)
    }
}

impl FromStr for SpaceBlobLocator {
    type Err = SpaceError;

    fn from_str(s: &str) -> Result<Self> {
        Self::parse(s)
    }
}

impl Serialize for SpaceBlobLocator {
    fn serialize<S: serde::Serializer>(
        &self,
        serializer: S,
    ) -> core::result::Result<S::Ok, S::Error> {
        serializer.serialize_str(&self.encode())
    }
}

impl<'de> Deserialize<'de> for SpaceBlobLocator {
    fn deserialize<D: serde::Deserializer<'de>>(
        deserializer: D,
    ) -> core::result::Result<Self, D::Error> {
        let raw = String::deserialize(deserializer)?;
        Self::parse(&raw).map_err(serde::de::Error::custom)
    }
}
