//! Service authentication error type mapped to ATProto XRPC error names.

use std::fmt;

/// Why a request's service authentication was refused.
///
/// Every variant maps to the reference implementation's XRPC error name via
/// [`ServiceAuthError::xrpc_error_name`].
#[derive(Clone, PartialEq, Eq, thiserror::Error)]
pub enum ServiceAuthError {
    /// The request has no `Authorization` header.
    MissingAuthorization,
    /// The `Authorization` header is not `Bearer <token>`.
    UnsupportedAuthorizationScheme,
    /// The token is not a well-formed compact JWS with valid claims.
    MalformedToken(String),
    /// The header `typ` marks the token as an OAuth or DPoP token (`at+jwt`, `refresh+jwt`, `dpop+jwt`).
    DisallowedTokenType(String),
    /// `exp` is in the past beyond the allowed clock skew.
    Expired,
    /// `exp` exceeds the configured lifetime ceiling, or `exp - iat` exceeds it.
    ExcessiveLifetime {
        /// Maximum accepted lifetime in seconds.
        maximum_secs: u64,
    },
    /// `aud` does not name this service.
    AudienceMismatch {
        /// The actual `aud` claim present in the token.
        actual: String,
    },
    /// `lxm` is missing or does not match the method policy.
    LexiconMethodMismatch {
        /// The expected NSID, if one was specified.
        expected: Option<String>,
        /// The actual `lxm` claim in the token, if present.
        actual: Option<String>,
    },
    /// `iss` is not a valid DID (optionally followed by `#fragment`).
    InvalidIssuer(String),
    /// The token names a signing key (`kid`) this service does not accept.
    KeyNotAccepted {
        /// The rejected `kid` fragment.
        key_id: String,
    },
    /// The header `alg` is not `ES256` or `ES256K`.
    UnsupportedAlgorithm(String),
    /// The issuer's signing key could not be resolved.
    KeyResolutionFailed {
        /// Issuer DID without fragment.
        did: String,
        /// Verification method fragment with `#`.
        key_id: String,
        /// Human-readable reason.
        reason: String,
    },
    /// The signature does not verify against the issuer's key, even after refresh.
    InvalidSignature,
    /// A claim required by policy or replay protection is absent.
    MissingClaim(String),
    /// The token's `jti` was already used.
    Replayed,
    /// The replay store failed, so reuse could not be checked.
    ReplayStoreFailed(String),
}

impl ServiceAuthError {
    /// The XRPC error name used in HTTP 401 JSON responses.
    pub const fn xrpc_error_name(&self) -> &'static str {
        match self {
            Self::MissingAuthorization | Self::UnsupportedAuthorizationScheme => "MissingJwt",
            Self::MalformedToken(_)
            | Self::ExcessiveLifetime { .. }
            | Self::KeyNotAccepted { .. }
            | Self::MissingClaim(_)
            | Self::Replayed
            | Self::ReplayStoreFailed(_) => "BadJwt",
            Self::DisallowedTokenType(_) => "BadJwtType",
            Self::Expired => "JwtExpired",
            Self::AudienceMismatch { .. } => "BadJwtAudience",
            Self::LexiconMethodMismatch { .. } => "BadJwtLexiconMethod",
            Self::InvalidIssuer(_) => "BadJwtIss",
            Self::UnsupportedAlgorithm(_)
            | Self::KeyResolutionFailed { .. }
            | Self::InvalidSignature => "BadJwtSignature",
        }
    }

    /// The HTTP status code to answer with (always `401`).
    pub const fn http_status(&self) -> u16 {
        401
    }

    /// A non-secret human-readable message suitable for the XRPC error body.
    pub fn message(&self) -> String {
        match self {
            Self::MissingAuthorization => "missing jwt".into(),
            Self::UnsupportedAuthorizationScheme => {
                "authorization header is not a bearer token".into()
            }
            Self::MalformedToken(detail) => format!("poorly formatted jwt: {detail}"),
            Self::DisallowedTokenType(kind) => format!("invalid jwt type \"{kind}\""),
            Self::Expired => "jwt expired".into(),
            Self::ExcessiveLifetime { maximum_secs } => {
                format!("jwt lifetime exceeds {maximum_secs} seconds")
            }
            Self::AudienceMismatch { .. } => "jwt audience does not match service did".into(),
            Self::LexiconMethodMismatch { expected, actual } => {
                let wanted = expected
                    .as_deref()
                    .map_or_else(String::new, |e| format!(" must match: {e}"));
                if actual.is_none() {
                    format!("missing jwt lexicon method (\"lxm\").{wanted}")
                } else {
                    format!("bad jwt lexicon method (\"lxm\").{wanted}")
                }
            }
            Self::InvalidIssuer(_) => "jwt iss is not a valid did".into(),
            Self::KeyNotAccepted { key_id } => {
                format!("jwt signing key {key_id} is not accepted by this service")
            }
            Self::UnsupportedAlgorithm(alg) => format!("unsupported jwt algorithm \"{alg}\""),
            Self::KeyResolutionFailed {
                did,
                key_id,
                reason,
            } => format!("could not resolve signing key {key_id} of {did}: {reason}"),
            Self::InvalidSignature => "jwt signature does not match jwt issuer".into(),
            Self::MissingClaim(name) => format!("jwt is missing required claim \"{name}\""),
            Self::Replayed => "jwt was already used".into(),
            Self::ReplayStoreFailed(reason) => {
                format!("could not check jwt for reuse: {reason}")
            }
        }
    }
}

impl fmt::Debug for ServiceAuthError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.xrpc_error_name(), self.message())
    }
}

impl fmt::Display for ServiceAuthError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}: {}", self.xrpc_error_name(), self.message())
    }
}
