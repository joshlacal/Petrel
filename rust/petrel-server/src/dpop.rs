use std::fmt;

use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use serde::{Deserialize, Serialize};
use url::Url;

use crate::error::OAuthServerError;
use crate::http::OAuthHttpHeaders;
use crate::jose::{
    OAuthCompactJwt, OAuthJwsAlgorithm, OAuthJwtSignatureEncoding, OAuthJwtVerificationConstraints,
};
use crate::support::{
    ConstantTime, DigestPurpose, OAuthClock, OAuthKeyedDigest, SystemOAuthClock, base64url_encode,
    sha256,
};

/// Result of validating a DPoP proof per RFC 9449 and AT Protocol OAuth constraints.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthValidatedDpopProof {
    /// JWK thumbprint (`jkt`) of the embedded signing key.
    pub jkt: String,
    /// JWT ID (`jti`) claim.
    pub jti: String,
    /// Issued-at Unix timestamp (`iat`).
    pub iat: i64,
    /// Normalized HTTP URL (`htu`) claim.
    pub htu: String,
    /// Uppercased HTTP method (`htm`) claim.
    pub htm: String,
    /// Access token hash (`ath`) if present.
    pub ath: Option<String>,
    /// DPoP nonce presented in the proof, if any.
    pub nonce: Option<String>,
}

/// DPoP validation errors distinguishing nonce challenges (`use_dpop_nonce`) from malformed/invalid proofs.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum OAuthDpopError {
    /// Missing or rotated/expired `nonce` claim; client should retry using the returned `DPoP-Nonce` header.
    #[error("a valid DPoP nonce is required")]
    UseDpopNonce { next_nonce: String },
    /// Malformed, expired, wrong-method/url/ath, or replayed proof (`invalid_dpop_proof`).
    #[error("invalid DPoP proof: {0}")]
    InvalidDpopProof(String),
}

impl From<OAuthDpopError> for OAuthServerError {
    fn from(err: OAuthDpopError) -> Self {
        match err {
            OAuthDpopError::UseDpopNonce { .. } => Self::Unauthorized("use_dpop_nonce".into()),
            OAuthDpopError::InvalidDpopProof(msg) => Self::Unauthorized(msg),
        }
    }
}

/// Replay prevention hook used by [`OAuthDpopProofValidator`] and client assertion validation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ReplayScope {
    /// DPoP proof `jti` scoped to key thumbprint.
    DpopProof,
    /// Confidential client `private_key_jwt` `jti` scoped to `client_id`.
    ClientAssertion,
}

/// Replay protection abstraction implemented by [`crate::store::OAuthReplayStore`] adapters.
pub trait OAuthDpopReplayChecker: MaybeSend + MaybeSync {
    /// Records `digest` with expiration `expires_at_secs`, returning `Ok(true)` if fresh or `Ok(false)` if replayed.
    fn record_if_fresh(
        &self,
        digest: Vec<u8>,
        expires_at_secs: i64,
    ) -> BoxFuture<'_, Result<bool, OAuthServerError>>;
}

/// Stateless HMAC-based rotating DPoP nonce mint and validator.
#[derive(Clone)]
pub struct OAuthDpopNonceService {
    digest: OAuthKeyedDigest,
    rotation_interval_secs: i64,
    accepted_previous_buckets: i64,
}

impl fmt::Debug for OAuthDpopNonceService {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("OAuthDpopNonceService")
            .field("rotation_interval_secs", &self.rotation_interval_secs)
            .field("accepted_previous_buckets", &self.accepted_previous_buckets)
            .finish_non_exhaustive()
    }
}

impl OAuthDpopNonceService {
    /// Default DPoP nonce rotation step (180 seconds = 3 minutes).
    pub const DEFAULT_ROTATION_INTERVAL_SECS: i64 = 180;
    /// Default number of previous rotation buckets accepted (2 => up to 9 minutes effective window).
    pub const DEFAULT_ACCEPTED_PREVIOUS_BUCKETS: i64 = 2;

    /// Creates a nonce service backed by a 32+ byte secret.
    pub fn new(
        secret: impl Into<Vec<u8>>,
        rotation_interval_secs: i64,
        accepted_previous_buckets: i64,
    ) -> Result<Self, OAuthServerError> {
        if rotation_interval_secs <= 0 || accepted_previous_buckets < 0 {
            return Err(OAuthServerError::Malformed(
                "invalid DPoP nonce rotation configuration".into(),
            ));
        }
        Ok(Self {
            digest: OAuthKeyedDigest::new(secret)?,
            rotation_interval_secs,
            accepted_previous_buckets,
        })
    }

    /// Creates a nonce service from an existing [`OAuthKeyedDigest`] using default rotation intervals.
    pub fn with_defaults(digest: OAuthKeyedDigest) -> Self {
        Self {
            digest,
            rotation_interval_secs: Self::DEFAULT_ROTATION_INTERVAL_SECS,
            accepted_previous_buckets: Self::DEFAULT_ACCEPTED_PREVIOUS_BUCKETS,
        }
    }

    /// Returns the current server nonce to emit in the `DPoP-Nonce` header.
    pub fn current_nonce(&self, now_secs: i64) -> String {
        let bucket = now_secs.div_euclid(self.rotation_interval_secs);
        self.nonce_for_bucket(bucket)
    }

    /// Checks whether `nonce` matches the current or accepted recent time buckets.
    pub fn is_valid(&self, nonce: &str, now_secs: i64) -> bool {
        let current_bucket = now_secs.div_euclid(self.rotation_interval_secs);
        for offset in 0..=self.accepted_previous_buckets {
            if let Some(bucket) = current_bucket.checked_sub(offset) {
                let candidate = self.nonce_for_bucket(bucket);
                if ConstantTime::equal(&candidate, nonce) {
                    return true;
                }
            }
        }
        false
    }

    fn nonce_for_bucket(&self, bucket: i64) -> String {
        let mac = self
            .digest
            .digest_str(&bucket.to_string(), DigestPurpose::DPoPNonce);
        base64url_encode(&mac)
    }
}

/// DPoP proof claims per RFC 9449 §4.2.
#[derive(Debug, Clone, Deserialize, Serialize)]
struct DpopProofClaims {
    jti: String,
    htm: String,
    htu: String,
    #[serde(default)]
    iat: Option<i64>,
    #[serde(default)]
    ath: Option<String>,
    #[serde(default)]
    nonce: Option<String>,
}

/// Parameters controlling single-request DPoP proof validation.
#[derive(Debug, Clone)]
pub struct DpopValidationContext<'a> {
    /// Expected HTTP method (e.g. `"POST"`).
    pub method: &'a str,
    /// Expected HTTP request URI (`scheme://host[:port]/path`, query/fragment stripped during normalization).
    pub url: &'a str,
    /// Expected OAuth access token (when validating resource requests; triggers `ath` check).
    pub expected_access_token: Option<&'a str>,
    /// Required key thumbprint (`cnf.jkt`) when binding refresh/access tokens.
    pub expected_jkt: Option<&'a str>,
    /// Override whether a valid server nonce is required for this request.
    pub require_nonce: bool,
}

/// Validates AT Protocol OAuth DPoP proofs (`RFC 9449`).
pub struct OAuthDpopProofValidator {
    nonce_service: OAuthDpopNonceService,
    keyed_digest: OAuthKeyedDigest,
    clock: Box<dyn OAuthClock>,
    allowed_algorithms: Vec<OAuthJwsAlgorithm>,
    max_proof_age_secs: i64,
    clock_skew_secs: i64,
    max_jti_bytes: usize,
}

impl fmt::Debug for OAuthDpopProofValidator {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("OAuthDpopProofValidator")
            .field("allowed_algorithms", &self.allowed_algorithms)
            .field("max_proof_age_secs", &self.max_proof_age_secs)
            .field("clock_skew_secs", &self.clock_skew_secs)
            .finish_non_exhaustive()
    }
}

impl OAuthDpopProofValidator {
    /// Default maximum age for DPoP `iat` claims (300 seconds).
    pub const DEFAULT_MAX_AGE_SECS: i64 = 300;
    /// Default clock skew tolerance (5 seconds).
    pub const DEFAULT_CLOCK_SKEW_SECS: i64 = 5;
    /// Default maximum `jti` byte length.
    pub const DEFAULT_MAX_JTI_BYTES: usize = 256;

    /// Constructs a validator backed by `nonce_service` and `keyed_digest`.
    pub fn new(nonce_service: OAuthDpopNonceService, keyed_digest: OAuthKeyedDigest) -> Self {
        Self {
            nonce_service,
            keyed_digest,
            clock: Box::new(SystemOAuthClock),
            allowed_algorithms: vec![OAuthJwsAlgorithm::Es256, OAuthJwsAlgorithm::Es256k],
            max_proof_age_secs: Self::DEFAULT_MAX_AGE_SECS,
            clock_skew_secs: Self::DEFAULT_CLOCK_SKEW_SECS,
            max_jti_bytes: Self::DEFAULT_MAX_JTI_BYTES,
        }
    }

    /// Sets an injectable clock (primarily for tests).
    #[must_use]
    pub fn with_clock(mut self, clock: impl OAuthClock + 'static) -> Self {
        self.clock = Box::new(clock);
        self
    }

    /// Overrides the allowed DPoP JWS signing algorithms (defaults to `ES256`, `ES256K`).
    #[must_use]
    pub fn with_allowed_algorithms(mut self, algs: Vec<OAuthJwsAlgorithm>) -> Self {
        self.allowed_algorithms = algs;
        self
    }

    /// Overrides maximum DPoP proof age and clock skew in seconds.
    #[must_use]
    pub fn with_timing_bounds(mut self, max_age_secs: i64, clock_skew_secs: i64) -> Self {
        self.max_proof_age_secs = max_age_secs;
        self.clock_skew_secs = clock_skew_secs;
        self
    }

    /// Current nonce for emitting `DPoP-Nonce` headers.
    pub fn current_nonce(&self) -> String {
        self.nonce_service.current_nonce(self.clock.now_secs())
    }

    /// Access to the underlying nonce service.
    pub fn nonce_service(&self) -> &OAuthDpopNonceService {
        &self.nonce_service
    }

    /// Extracts the `DPoP` header (must appear exactly once) and validates the proof.
    pub async fn validate_headers(
        &self,
        headers: &OAuthHttpHeaders,
        ctx: DpopValidationContext<'_>,
        replay_checker: &dyn OAuthDpopReplayChecker,
    ) -> Result<OAuthValidatedDpopProof, OAuthDpopError> {
        let vals = headers.values("DPoP");
        if vals.is_empty() {
            return Err(OAuthDpopError::InvalidDpopProof(
                "missing DPoP header".into(),
            ));
        }
        if vals.len() > 1 {
            return Err(OAuthDpopError::InvalidDpopProof(
                "multiple DPoP headers are not allowed".into(),
            ));
        }
        self.validate_proof(vals[0].trim(), ctx, replay_checker)
            .await
    }

    /// Validates a compact DPoP JWT string.
    pub async fn validate_proof(
        &self,
        proof_jwt: &str,
        ctx: DpopValidationContext<'_>,
        replay_checker: &dyn OAuthDpopReplayChecker,
    ) -> Result<OAuthValidatedDpopProof, OAuthDpopError> {
        if proof_jwt.is_empty() {
            return Err(OAuthDpopError::InvalidDpopProof("empty DPoP header".into()));
        }
        let now_secs = self.clock.now_secs();
        let mut constraints = OAuthJwtVerificationConstraints::new(now_secs);
        constraints.allowed_algorithms = self.allowed_algorithms.clone();
        constraints.expected_type = Some("dpop+jwt".to_owned());
        constraints.require_issued_at = true;
        constraints.maximum_age_secs = Some(self.max_proof_age_secs);
        constraints.clock_skew_secs = self.clock_skew_secs;
        constraints.signature_encoding = OAuthJwtSignatureEncoding::JoseInteroperable;

        let verified =
            OAuthCompactJwt::verify_dpop_proof::<DpopProofClaims>(proof_jwt, &constraints)
                .map_err(|err| OAuthDpopError::InvalidDpopProof(err.to_string()))?;

        let jwk = verified
            .embedded_jwk
            .as_ref()
            .ok_or_else(|| OAuthDpopError::InvalidDpopProof("missing embedded jwk".into()))?;
        let jkt = jwk.thumbprint();

        if let Some(expected_jkt) = ctx.expected_jkt
            && !ConstantTime::equal(&jkt, expected_jkt)
        {
            return Err(OAuthDpopError::InvalidDpopProof(
                "DPoP key does not match bound jkt".into(),
            ));
        }

        let validated = self.validate_claims_and_nonce(&jkt, verified.claims, &ctx, now_secs)?;

        // Scope replay digest to `jkt` + `jti` so independent clients choosing colliding `jti` don't block each other.
        let replay_key = format!("{jkt}\0{}", validated.jti);
        let replay_digest = self
            .keyed_digest
            .digest_str(&replay_key, DigestPurpose::DPoPProof);
        // Retain through `iat + max_proof_age + clock_skew` (+1s grace for inclusive expiry check).
        let expires_at = validated
            .iat
            .saturating_add(self.max_proof_age_secs)
            .saturating_add(self.clock_skew_secs)
            .saturating_add(1);
        let fresh = replay_checker
            .record_if_fresh(replay_digest, expires_at)
            .await
            .map_err(|err| OAuthDpopError::InvalidDpopProof(err.to_string()))?;
        if !fresh {
            return Err(OAuthDpopError::InvalidDpopProof(
                "DPoP jti was replayed".into(),
            ));
        }

        Ok(validated)
    }

    fn validate_claims_and_nonce(
        &self,
        jkt: &str,
        claims: DpopProofClaims,
        ctx: &DpopValidationContext<'_>,
        now_secs: i64,
    ) -> Result<OAuthValidatedDpopProof, OAuthDpopError> {
        if claims.jti.is_empty() || claims.jti.len() > self.max_jti_bytes {
            return Err(OAuthDpopError::InvalidDpopProof(
                "DPoP jti is missing or too long".into(),
            ));
        }
        if !claims.htm.eq_ignore_ascii_case(ctx.method) {
            return Err(OAuthDpopError::InvalidDpopProof(
                "DPoP htm does not match request method".into(),
            ));
        }
        let expected_htu = Self::normalize_htu(ctx.url)
            .map_err(|err| OAuthDpopError::InvalidDpopProof(err.to_string()))?;
        let actual_htu = Self::normalize_htu(&claims.htu)
            .map_err(|err| OAuthDpopError::InvalidDpopProof(err.to_string()))?;
        if actual_htu != expected_htu {
            return Err(OAuthDpopError::InvalidDpopProof(
                "DPoP htu does not match request target URI".into(),
            ));
        }

        if let Some(access_token) = ctx.expected_access_token {
            let expected_ath = Self::access_token_hash(access_token);
            match claims.ath.as_deref() {
                Some(ath) if ConstantTime::equal(ath, &expected_ath) => {}
                _ => {
                    return Err(OAuthDpopError::InvalidDpopProof(
                        "DPoP ath does not match access token".into(),
                    ));
                }
            }
        } else if claims.ath.is_some() {
            return Err(OAuthDpopError::InvalidDpopProof(
                "unexpected ath claim on non-resource DPoP proof".into(),
            ));
        }

        let iat = claims
            .iat
            .ok_or_else(|| OAuthDpopError::InvalidDpopProof("DPoP iat is required".into()))?;

        if ctx.require_nonce {
            match claims.nonce.as_deref() {
                Some(n) if self.nonce_service.is_valid(n, now_secs) => {}
                _ => {
                    return Err(OAuthDpopError::UseDpopNonce {
                        next_nonce: self.nonce_service.current_nonce(now_secs),
                    });
                }
            }
        } else if let Some(ref n) = claims.nonce
            && !self.nonce_service.is_valid(n, now_secs)
        {
            return Err(OAuthDpopError::UseDpopNonce {
                next_nonce: self.nonce_service.current_nonce(now_secs),
            });
        }

        Ok(OAuthValidatedDpopProof {
            jkt: jkt.to_owned(),
            jti: claims.jti,
            iat,
            htu: actual_htu,
            htm: claims.htm.to_ascii_uppercase(),
            ath: claims.ath,
            nonce: claims.nonce,
        })
    }

    /// Computes RFC 9449 `ath = BASE64URL(SHA256(access_token))`.
    pub fn access_token_hash(access_token: &str) -> String {
        base64url_encode(&sha256(access_token.as_bytes()))
    }

    /// Normalizes a URL per RFC 9449 §4.2 / RFC 3986 (`scheme://host[:non_default_port]/path`, empty path -> `/`).
    pub fn normalize_htu(raw: &str) -> Result<String, OAuthServerError> {
        let mut parsed = Url::parse(raw)
            .map_err(|_| OAuthServerError::Malformed("DPoP htu is not a valid URL".into()))?;
        if !matches!(parsed.scheme(), "http" | "https") {
            return Err(OAuthServerError::Malformed(
                "DPoP htu must use http or https scheme".into(),
            ));
        }
        if !parsed.username().is_empty() || parsed.password().is_some() {
            return Err(OAuthServerError::Malformed(
                "DPoP htu must not contain userinfo".into(),
            ));
        }
        if parsed.host_str().is_none() {
            return Err(OAuthServerError::Malformed(
                "DPoP htu must contain a host".into(),
            ));
        }
        parsed.set_query(None);
        parsed.set_fragment(None);
        if parsed.path().is_empty() {
            parsed.set_path("/");
        }
        Ok(parsed.into())
    }
}
