//! AT Protocol inter-service authentication JWTs (`ServiceJWT`, `ProxyServiceJWT`, `SpaceServiceJWT`).

use std::time::Duration;

use serde::{Deserialize, Serialize};
use web_time::{SystemTime, UNIX_EPOCH};

use crate::codecs::{Hex, JWTBase64URL, StrictJSON};
use crate::did_key::{PLCDIDKeyCodec, PLCDIDVerificationKey};
use crate::error::PetrelCryptoError;
use crate::jwt_key::ATProtoJWTVerificationKey;
use crate::keys::{ATProtoCrypto, ATProtoSigner, K256Keypair, P256Keypair, PrivateKey, PublicKey};
use crate::service_auth::error::ServiceAuthError;
use crate::service_auth::syntax;
use crate::signature::{ATProtoSignature, ATProtoSignatureVerificationOptions};

/// Claims of an AT Protocol inter-service authentication JWT.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ServiceJWTClaims {
    /// Audience: receiving service DID (normally with `#service`).
    pub aud: String,
    /// Expiry time, UNIX seconds.
    pub exp: i64,
    /// Creation time, UNIX seconds.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub iat: Option<i64>,
    /// Issuer DID (legacy tokens may carry `#service`).
    pub iss: String,
    /// Unique random nonce for replay protection.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub jti: Option<String>,
    /// Lexicon method NSID authorized by this token.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub lxm: Option<String>,
    /// Petrel `req` request-body digest extension.
    #[serde(rename = "req", skip_serializing_if = "Option::is_none")]
    pub request_body_digest: Option<String>,
}

/// Unverified contents of a decoded compact service JWT.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ServiceJWTInspection {
    /// The `iss` claim verbatim (including any legacy `#fragment`).
    pub issuer: String,
    /// The JOSE header `alg` (`"ES256"` or `"ES256K"`).
    pub algorithm: String,
    /// Decoded claims.
    pub claims: ServiceJWTClaims,
    /// Header `typ`, if present.
    pub token_type: Option<String>,
    /// Header `kid` (with `#`), if present.
    pub key_id: Option<String>,
}

impl ServiceJWTInspection {
    /// Issuer DID with any legacy `#fragment` removed.
    pub fn issuer_did(&self) -> &str {
        syntax::split_did_reference(&self.issuer).map_or(self.issuer.as_str(), |(did, _)| did)
    }

    /// Fragment a legacy token appended to `iss`, without `#`.
    pub fn issuer_fragment(&self) -> Option<&str> {
        syntax::split_did_reference(&self.issuer).and_then(|(_, frag)| frag)
    }

    /// Key ID the token claims to be signed with (`key_id`, or `"#atproto"` if absent).
    pub fn effective_key_id(&self) -> &str {
        self.key_id.as_deref().unwrap_or(ServiceJWT::DEFAULT_KEY_ID)
    }

    /// The `lxm` claim, if present.
    pub fn lexicon_method(&self) -> Option<&str> {
        self.claims.lxm.as_deref()
    }

    /// The `exp` claim as a [`SystemTime`].
    pub fn expires_at(&self) -> SystemTime {
        unix_secs_to_system_time(self.claims.exp)
    }
}

/// In-memory signing key for synchronous [`ServiceJWT::mint_sync`].
#[derive(Debug, Clone, Copy)]
pub enum ServiceJWTSigningKey<'a> {
    /// Any curve-tagged [`PrivateKey`].
    PrivateKey(&'a PrivateKey),
    /// A P-256 keypair (`ES256`).
    P256(&'a P256Keypair),
    /// A K-256 keypair (`ES256K`).
    K256(&'a K256Keypair),
}

impl ServiceJWTSigningKey<'_> {
    const fn jwt_algorithm(&self) -> &'static str {
        match self {
            Self::PrivateKey(k) => k.curve().jwt_algorithm(),
            Self::P256(_) => "ES256",
            Self::K256(_) => "ES256K",
        }
    }

    fn sign_sync(&self, message: &[u8]) -> Result<[u8; 64], PetrelCryptoError> {
        match self {
            Self::PrivateKey(k) => k.sign_sync(message),
            Self::P256(k) => k.sign_sync(message),
            Self::K256(k) => k.sign_sync(message),
        }
    }
}

/// Options for minting a service JWT via [`ServiceJWT::mint`] or [`ServiceJWT::mint_sync`].
#[derive(Debug, Clone)]
pub struct ServiceJWTMintOptions<'a> {
    /// Issuer DID (or legacy `did#service`).
    pub issuer: &'a str,
    /// Audience DID (normally `did#service`).
    pub audience: &'a str,
    /// Optional XRPC method NSID (`lxm`).
    pub lexicon_method: Option<&'a str>,
    /// Optional `kid` header fragment (e.g. `"#atproto_label"`).
    pub key_id: Option<&'a str>,
    /// Optional `jti` nonce (if `None`, generates 16 random bytes hex-encoded).
    pub nonce: Option<&'a str>,
    /// Optional Petrel `req` request-body digest.
    pub request_body_digest: Option<&'a str>,
    /// Current clock instant (`iat`). Defaults to `SystemTime::now()`.
    pub now: SystemTime,
    /// Token lifetime in whole seconds (`1..=3600`). Defaults to 60 seconds.
    pub lifetime: Duration,
}

impl<'a> ServiceJWTMintOptions<'a> {
    /// Creates mint options with default `now = SystemTime::now()` and `lifetime = 60s`.
    pub fn new(issuer: &'a str, audience: &'a str, lexicon_method: Option<&'a str>) -> Self {
        Self {
            issuer,
            audience,
            lexicon_method,
            key_id: None,
            nonce: None,
            request_body_digest: None,
            now: SystemTime::now(),
            lifetime: ServiceJWT::DEFAULT_LIFETIME,
        }
    }
}

/// Options for verifying a service JWT directly against a known public key via [`ServiceJWT::verify_with_options`].
#[derive(Debug, Clone)]
pub struct ServiceJWTVerifyOptions<'a> {
    /// Signature encoding policy (defaults to [`ATProtoSignatureVerificationOptions::JWT`]).
    pub signature_options: ATProtoSignatureVerificationOptions,
    /// Required exact `aud` claim, or `None` to skip.
    pub expected_audience: Option<&'a str>,
    /// Required exact `lxm` claim, or `None` to skip.
    pub expected_method: Option<&'a str>,
    /// Required exact `req` claim, or `None` to skip.
    pub expected_request_body_digest: Option<&'a str>,
    /// Verifier clock instant. Defaults to `SystemTime::now()`.
    pub now: SystemTime,
    /// Allowed clock skew past `exp` (`0..=300s`). Defaults to 5 seconds.
    pub clock_skew: Duration,
    /// Maximum accepted token lifetime. Defaults to 1 hour.
    pub maximum_lifetime: Duration,
}

impl Default for ServiceJWTVerifyOptions<'_> {
    fn default() -> Self {
        Self {
            signature_options: ATProtoSignatureVerificationOptions::JWT,
            expected_audience: None,
            expected_method: None,
            expected_request_body_digest: None,
            now: SystemTime::now(),
            clock_skew: ServiceJWT::DEFAULT_CLOCK_SKEW,
            maximum_lifetime: ServiceJWT::DEFAULT_MAXIMUM_ACCEPTED_LIFETIME,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub(crate) struct ServiceJWTHeader {
    pub(crate) alg: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) kid: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) typ: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) crit: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) b64: Option<bool>,
}

pub(crate) struct ParsedServiceJWT {
    pub(crate) header: ServiceJWTHeader,
    pub(crate) claims: ServiceJWTClaims,
    pub(crate) signing_input: Vec<u8>,
    pub(crate) signature: Vec<u8>,
}

pub(crate) enum TimeFailure {
    InvalidClock,
    Expired,
    ExcessiveLifetime,
    ExpiresBeforeIssued,
}

/// AT Protocol inter-service authentication JWTs: minting, inspection, and verification.
#[derive(Debug, Clone, Copy)]
#[allow(clippy::upper_case_acronyms)]
pub struct ServiceJWT;

impl ServiceJWT {
    /// Longest compact token accepted, in bytes (32 KiB).
    pub const MAXIMUM_COMPACT_BYTES: usize = 32 * 1024;
    /// Default lifetime of a minted token (60 seconds).
    pub const DEFAULT_LIFETIME: Duration = Duration::from_secs(60);
    /// Longest lifetime `mint` will issue (1 hour).
    pub const MAXIMUM_LIFETIME: Duration = Duration::from_secs(60 * 60);
    /// Longest lifetime `verify` accepts by default (1 hour).
    pub const DEFAULT_MAXIMUM_ACCEPTED_LIFETIME: Duration = Duration::from_secs(60 * 60);
    /// Clock skew `verify` tolerates by default (5 seconds).
    pub const DEFAULT_CLOCK_SKEW: Duration = Duration::from_secs(5);
    /// Default verification method key ID (`"#atproto"`).
    pub const DEFAULT_KEY_ID: &'static str = "#atproto";
    /// Upper bound on configurable lifetime ceiling (365 days).
    pub const MAXIMUM_CONFIGURABLE_LIFETIME: Duration = Duration::from_secs(365 * 24 * 60 * 60);

    /// Mints a service JWT asynchronously using any [`ATProtoSigner`].
    pub async fn mint(
        options: &ServiceJWTMintOptions<'_>,
        signer: &dyn ATProtoSigner,
    ) -> Result<String, PetrelCryptoError> {
        let nonce_owned;
        let nonce = if let Some(n) = options.nonce {
            n
        } else {
            nonce_owned = Hex::encode(&ATProtoCrypto::random_array::<16>()?);
            &nonce_owned
        };
        let signing_input = Self::unsigned_token(
            options.issuer,
            options.audience,
            options.lexicon_method,
            nonce,
            options.request_body_digest,
            options.key_id,
            signer.jwt_algorithm(),
            options.now,
            options.lifetime,
        )?;
        let signature = signer.sign(signing_input.as_bytes()).await?;
        if !ATProtoSignature::is_canonical(&signature, signer.curve()) {
            return Err(PetrelCryptoError::Malformed(
                "signer did not return a 64-byte compact low-S signature".into(),
            ));
        }
        Ok(format!(
            "{signing_input}.{}",
            JWTBase64URL::encode(&signature)
        ))
    }

    /// Mints a service JWT synchronously using an in-memory [`ServiceJWTSigningKey`].
    pub fn mint_sync(
        options: &ServiceJWTMintOptions<'_>,
        key: ServiceJWTSigningKey<'_>,
    ) -> Result<String, PetrelCryptoError> {
        let nonce_owned;
        let nonce = if let Some(n) = options.nonce {
            n
        } else {
            nonce_owned = Hex::encode(&ATProtoCrypto::random_array::<16>()?);
            &nonce_owned
        };
        let signing_input = Self::unsigned_token(
            options.issuer,
            options.audience,
            options.lexicon_method,
            nonce,
            options.request_body_digest,
            options.key_id,
            key.jwt_algorithm(),
            options.now,
            options.lifetime,
        )?;
        let signature = key.sign_sync(signing_input.as_bytes())?;
        Ok(format!(
            "{signing_input}.{}",
            JWTBase64URL::encode(&signature)
        ))
    }

    /// Returns the `Authorization` header value (`"Bearer <token>"`).
    pub fn bearer_authorization(token: &str) -> String {
        format!("Bearer {token}")
    }

    /// Returns `true` iff `value` is a syntactically valid NSID.
    pub fn is_nsid(value: &str) -> bool {
        syntax::is_nsid(value)
    }

    /// Returns `true` iff `value` is a syntactically valid AT Protocol DID.
    pub fn is_did(value: &str) -> bool {
        syntax::is_did(value)
    }

    /// Decodes a compact service JWT without verifying its signature.
    pub fn inspect(compact: &str) -> Result<ServiceJWTInspection, PetrelCryptoError> {
        let parsed = Self::parse(compact, false)?;
        Self::validate_shape(&parsed.header, &parsed.claims)?;
        Ok(ServiceJWTInspection {
            issuer: parsed.claims.iss.clone(),
            algorithm: parsed.header.alg,
            claims: parsed.claims,
            token_type: parsed.header.typ,
            key_id: parsed.header.kid,
        })
    }

    /// Verifies a service JWT against a [`PublicKey`] using default options.
    pub fn verify(
        compact: &str,
        public_key: &PublicKey,
    ) -> Result<ServiceJWTClaims, PetrelCryptoError> {
        Self::verify_with_options(
            compact,
            &ATProtoJWTVerificationKey::from_public_key(public_key),
            &ServiceJWTVerifyOptions::default(),
        )
    }

    /// Verifies a service JWT against an [`ATProtoJWTVerificationKey`] with explicit options.
    pub fn verify_with_options(
        compact: &str,
        public_key: &ATProtoJWTVerificationKey,
        options: &ServiceJWTVerifyOptions<'_>,
    ) -> Result<ServiceJWTClaims, PetrelCryptoError> {
        if !Self::is_valid_time_policy(options.clock_skew, options.maximum_lifetime) {
            return Err(PetrelCryptoError::Malformed(
                "service authentication time policy is invalid".into(),
            ));
        }
        let parsed = Self::parse(compact, options.signature_options.allow_der)?;
        Self::validate_shape(&parsed.header, &parsed.claims)?;

        if let Some(expected_aud) = options.expected_audience
            && parsed.claims.aud != expected_aud
        {
            return Err(PetrelCryptoError::Unauthorized(
                "service authentication audience mismatch".into(),
            ));
        }
        if let Some(expected_lxm) = options.expected_method
            && parsed.claims.lxm.as_deref() != Some(expected_lxm)
        {
            return Err(PetrelCryptoError::Unauthorized(
                "service authentication method mismatch".into(),
            ));
        }
        if let Some(expected_req) = options.expected_request_body_digest
            && parsed.claims.request_body_digest.as_deref() != Some(expected_req)
        {
            return Err(PetrelCryptoError::Unauthorized(
                "service authentication request body digest mismatch".into(),
            ));
        }

        if !public_key.verify_with_options(
            &parsed.signature,
            &parsed.signing_input,
            &parsed.header.alg,
            options.signature_options,
        )? {
            return Err(PetrelCryptoError::Unauthorized(
                "service authentication signature is invalid".into(),
            ));
        }

        match Self::time_failure(
            &parsed.claims,
            options.now,
            options.clock_skew,
            options.maximum_lifetime,
        ) {
            None => Ok(parsed.claims),
            Some(TimeFailure::InvalidClock) => Err(PetrelCryptoError::Malformed(
                "service authentication current time is invalid".into(),
            )),
            Some(TimeFailure::Expired) => Err(PetrelCryptoError::Expired),
            Some(TimeFailure::ExcessiveLifetime | TimeFailure::ExpiresBeforeIssued) => {
                Err(PetrelCryptoError::Unauthorized(
                    "service authentication time claims are invalid".into(),
                ))
            }
        }
    }

    /// Verifies a service JWT against a [`PublicKey`] with explicit options.
    pub fn verify_with_public_key(
        compact: &str,
        public_key: &PublicKey,
        options: &ServiceJWTVerifyOptions<'_>,
    ) -> Result<ServiceJWTClaims, PetrelCryptoError> {
        Self::verify_with_options(
            compact,
            &ATProtoJWTVerificationKey::from_public_key(public_key),
            options,
        )
    }

    /// Verifies a service JWT against a [`PLCDIDVerificationKey`] with explicit options.
    pub fn verify_with_plc_key(
        compact: &str,
        public_key: &PLCDIDVerificationKey,
        options: &ServiceJWTVerifyOptions<'_>,
    ) -> Result<ServiceJWTClaims, PetrelCryptoError> {
        Self::verify_with_options(
            compact,
            &ATProtoJWTVerificationKey::from_plc_key(public_key),
            options,
        )
    }

    /// Verifies a service JWT against a `did:key` string with explicit options.
    pub fn verify_with_did_key(
        compact: &str,
        did_key: &str,
        options: &ServiceJWTVerifyOptions<'_>,
    ) -> Result<ServiceJWTClaims, PetrelCryptoError> {
        let key = PLCDIDKeyCodec::decode(did_key)?;
        Self::verify_with_plc_key(compact, &key, options)
    }

    #[allow(clippy::too_many_arguments)]
    fn unsigned_token(
        issuer: &str,
        audience: &str,
        method: Option<&str>,
        nonce: &str,
        request_body_digest: Option<&str>,
        key_id: Option<&str>,
        algorithm: &str,
        now: SystemTime,
        lifetime: Duration,
    ) -> Result<String, PetrelCryptoError> {
        if syntax::split_did_reference(issuer).is_none() {
            return Err(PetrelCryptoError::Malformed(
                "service authentication issuer is not a DID".into(),
            ));
        }
        if syntax::split_did_reference(audience).is_none() {
            return Err(PetrelCryptoError::Malformed(
                "service authentication audience is not a DID with an optional #service fragment"
                    .into(),
            ));
        }
        if let Some(m) = method
            && !syntax::is_nsid(m)
        {
            return Err(PetrelCryptoError::Malformed(
                "service authentication lexicon method is not an NSID".into(),
            ));
        }
        if !syntax::is_printable_ascii(nonce, 256) {
            return Err(PetrelCryptoError::Malformed(
                "service authentication nonce must be 1-256 printable ASCII characters".into(),
            ));
        }
        if !Self::valid_request_body_digest(request_body_digest) {
            return Err(PetrelCryptoError::Malformed(
                "service authentication request body digest is invalid".into(),
            ));
        }
        if let Some(kid) = key_id
            && !syntax::is_key_id(kid)
        {
            return Err(PetrelCryptoError::Malformed(
                "service authentication key id must be a DID document fragment starting with #"
                    .into(),
            ));
        }
        if lifetime.subsec_nanos() != 0
            || lifetime < Duration::from_secs(1)
            || lifetime > Self::MAXIMUM_LIFETIME
        {
            return Err(PetrelCryptoError::Malformed(format!(
                "service authentication lifetime must be a whole number of seconds from 1 to {}",
                Self::MAXIMUM_LIFETIME.as_secs()
            )));
        }
        let iat = system_time_to_unix_secs(now).ok_or_else(|| {
            PetrelCryptoError::Malformed("service authentication current time is invalid".into())
        })?;
        let lifetime_secs = i64::try_from(lifetime.as_secs()).map_err(|_| {
            PetrelCryptoError::Malformed("service authentication expiry is invalid".into())
        })?;
        let exp = iat.checked_add(lifetime_secs).ok_or_else(|| {
            PetrelCryptoError::Malformed("service authentication expiry is invalid".into())
        })?;

        let header = ServiceJWTHeader {
            alg: algorithm.to_owned(),
            kid: key_id.map(str::to_owned),
            typ: Some("JWT".into()),
            crit: None,
            b64: None,
        };
        let claims = ServiceJWTClaims {
            aud: audience.to_owned(),
            exp,
            iat: Some(iat),
            iss: issuer.to_owned(),
            jti: Some(nonce.to_owned()),
            lxm: method.map(str::to_owned),
            request_body_digest: request_body_digest.map(str::to_owned),
        };
        let header_bytes = serde_json::to_vec(&header)
            .map_err(|_| PetrelCryptoError::Malformed("failed to encode JWT header".into()))?;
        let claims_bytes = serde_json::to_vec(&claims)
            .map_err(|_| PetrelCryptoError::Malformed("failed to encode JWT claims".into()))?;

        Ok(format!(
            "{}.{}",
            JWTBase64URL::encode(&header_bytes),
            JWTBase64URL::encode(&claims_bytes)
        ))
    }

    pub(crate) fn parse(
        compact: &str,
        allow_der_signature: bool,
    ) -> Result<ParsedServiceJWT, PetrelCryptoError> {
        if compact.is_empty() || compact.len() > Self::MAXIMUM_COMPACT_BYTES {
            return Err(PetrelCryptoError::Malformed(
                "service authentication token is invalid".into(),
            ));
        }
        let mut pieces = compact.split('.');
        let (Some(h_b64), Some(p_b64), Some(s_b64), None) =
            (pieces.next(), pieces.next(), pieces.next(), pieces.next())
        else {
            return Err(PetrelCryptoError::Malformed(
                "service authentication token is invalid".into(),
            ));
        };
        if [h_b64, p_b64, s_b64]
            .iter()
            .any(|seg| seg.is_empty() || seg.len() > 16 * 1024)
        {
            return Err(PetrelCryptoError::Malformed(
                "service authentication token is invalid".into(),
            ));
        }
        let header_data = JWTBase64URL::decode(h_b64, 4 * 1024).map_err(|_| {
            PetrelCryptoError::Malformed("service authentication token is invalid".into())
        })?;
        let payload = JWTBase64URL::decode(p_b64, 16 * 1024).map_err(|_| {
            PetrelCryptoError::Malformed("service authentication token is invalid".into())
        })?;
        let signature = JWTBase64URL::decode(s_b64, if allow_der_signature { 72 } else { 64 })
            .map_err(|_| {
                PetrelCryptoError::Malformed("service authentication token is invalid".into())
            })?;
        if !(signature.len() == 64 || allow_der_signature) {
            return Err(PetrelCryptoError::Malformed(
                "service authentication token is invalid".into(),
            ));
        }
        let header: ServiceJWTHeader = StrictJSON::decode(&header_data)?;
        let claims: ServiceJWTClaims = StrictJSON::decode(&payload)?;
        let mut signing_input = Vec::with_capacity(h_b64.len() + 1 + p_b64.len());
        signing_input.extend_from_slice(h_b64.as_bytes());
        signing_input.push(b'.');
        signing_input.extend_from_slice(p_b64.as_bytes());
        Ok(ParsedServiceJWT {
            header,
            claims,
            signing_input,
            signature,
        })
    }

    pub(crate) fn is_disallowed_type(typ: &str) -> bool {
        ["at+jwt", "refresh+jwt", "dpop+jwt"]
            .iter()
            .any(|disallowed| disallowed.eq_ignore_ascii_case(typ))
    }

    pub(crate) fn is_allowed_algorithm(alg: &str) -> bool {
        matches!(alg, "ES256" | "ES256K")
    }

    pub(crate) fn shape_failure(
        header: &ServiceJWTHeader,
        claims: &ServiceJWTClaims,
    ) -> Option<ServiceAuthError> {
        if header.crit.is_some() || header.b64.is_some() {
            return Some(ServiceAuthError::MalformedToken(
                "unsupported critical header parameters".into(),
            ));
        }
        if let Some(typ) = header.typ.as_deref()
            && Self::is_disallowed_type(typ)
        {
            return Some(ServiceAuthError::DisallowedTokenType(typ.to_owned()));
        }
        if syntax::split_did_reference(&claims.iss).is_none() {
            return Some(ServiceAuthError::InvalidIssuer(claims.iss.clone()));
        }
        if !syntax::is_printable_ascii(&claims.aud, 4096) {
            return Some(ServiceAuthError::MalformedToken(
                "aud is not a service identifier".into(),
            ));
        }
        if let Some(lxm) = claims.lxm.as_deref()
            && !syntax::is_nsid(lxm)
        {
            return Some(ServiceAuthError::MalformedToken(
                "lxm is not an NSID".into(),
            ));
        }
        if let Some(jti) = claims.jti.as_deref()
            && !jti.is_empty()
            && !syntax::is_printable_ascii(jti, 256)
        {
            return Some(ServiceAuthError::MalformedToken(
                "jti is not a printable nonce".into(),
            ));
        }
        if !Self::valid_request_body_digest(claims.request_body_digest.as_deref()) {
            return Some(ServiceAuthError::MalformedToken(
                "req is not a printable digest".into(),
            ));
        }
        None
    }

    fn validate_shape(
        header: &ServiceJWTHeader,
        claims: &ServiceJWTClaims,
    ) -> Result<(), PetrelCryptoError> {
        if !Self::is_allowed_algorithm(&header.alg) || Self::shape_failure(header, claims).is_some()
        {
            return Err(PetrelCryptoError::Unauthorized(
                "service authentication token is invalid".into(),
            ));
        }
        Ok(())
    }

    fn valid_request_body_digest(value: Option<&str>) -> bool {
        value.is_none_or(|v| syntax::is_printable_ascii(v, 4096))
    }

    pub(crate) fn is_valid_time_policy(clock_skew: Duration, maximum_lifetime: Duration) -> bool {
        clock_skew <= Duration::from_secs(5 * 60)
            && !maximum_lifetime.is_zero()
            && maximum_lifetime <= Self::MAXIMUM_CONFIGURABLE_LIFETIME
    }

    pub(crate) fn time_failure(
        claims: &ServiceJWTClaims,
        now: SystemTime,
        clock_skew: Duration,
        maximum_lifetime: Duration,
    ) -> Option<TimeFailure> {
        let Some(now_secs) = system_time_to_unix_secs(now) else {
            return Some(TimeFailure::InvalidClock);
        };
        let Ok(skew) = i64::try_from(clock_skew.as_secs()) else {
            return Some(TimeFailure::InvalidClock);
        };
        let Ok(ceiling) = i64::try_from(maximum_lifetime.as_secs()) else {
            return Some(TimeFailure::InvalidClock);
        };
        let Some(expiration_cutoff) = now_secs.checked_sub(skew) else {
            return Some(TimeFailure::InvalidClock);
        };
        if claims.exp < expiration_cutoff {
            return Some(TimeFailure::Expired);
        }
        let Some(latest_expiration) = now_secs
            .checked_add(skew)
            .and_then(|s| s.checked_add(ceiling))
        else {
            return Some(TimeFailure::InvalidClock);
        };
        if claims.exp > latest_expiration {
            return Some(TimeFailure::ExcessiveLifetime);
        }
        if let Some(issued_at) = claims.iat {
            if claims.exp < issued_at {
                return Some(TimeFailure::ExpiresBeforeIssued);
            }
            let Some(lifetime) = claims.exp.checked_sub(issued_at) else {
                return Some(TimeFailure::ExcessiveLifetime);
            };
            if lifetime > ceiling {
                return Some(TimeFailure::ExcessiveLifetime);
            }
        }
        None
    }
}

/// Backward-compatibility alias for the P-256 service-JWT minting path.
#[derive(Debug, Clone, Copy)]
#[allow(clippy::upper_case_acronyms)]
pub struct ProxyServiceJWT;

impl ProxyServiceJWT {
    /// Maximum/default lifetime (60 seconds).
    pub const MAXIMUM_LIFETIME: Duration = Duration::from_secs(60);

    /// Mints a P-256 (`ES256`) proxy service JWT.
    pub fn create(
        options: &ServiceJWTMintOptions<'_>,
        key: &P256Keypair,
    ) -> Result<String, PetrelCryptoError> {
        ServiceJWT::mint_sync(options, ServiceJWTSigningKey::P256(key))
    }

    /// Returns `true` iff `value` is a syntactically valid NSID.
    pub fn is_nsid(value: &str) -> bool {
        ServiceJWT::is_nsid(value)
    }
}

/// Backward-compatibility alias for Spaces service JWTs (60 s skew, 5 min max lifetime).
#[derive(Debug, Clone, Copy)]
#[allow(clippy::upper_case_acronyms)]
pub struct SpaceServiceJWT;

impl SpaceServiceJWT {
    /// Maximum compact JWT size in bytes.
    pub const MAXIMUM_COMPACT_BYTES: usize = ServiceJWT::MAXIMUM_COMPACT_BYTES;
    /// Default token lifetime (60 seconds).
    pub const LIFETIME: Duration = ServiceJWT::DEFAULT_LIFETIME;
    /// Default Spaces clock skew (60 seconds).
    pub const DEFAULT_CLOCK_SKEW: Duration = Duration::from_secs(60);
    /// Default Spaces maximum accepted lifetime (5 minutes).
    pub const DEFAULT_MAXIMUM_LIFETIME: Duration = Duration::from_secs(5 * 60);

    /// Mints a P-256 (`ES256`) service JWT.
    pub fn create(
        options: &ServiceJWTMintOptions<'_>,
        key: &P256Keypair,
    ) -> Result<String, PetrelCryptoError> {
        ServiceJWT::mint_sync(options, ServiceJWTSigningKey::P256(key))
    }

    /// Inspects a compact service JWT without verifying its signature.
    pub fn inspect(compact: &str) -> Result<ServiceJWTInspection, PetrelCryptoError> {
        ServiceJWT::inspect(compact)
    }

    /// Verifies a service JWT against an [`ATProtoJWTVerificationKey`] using Spaces defaults.
    pub fn verify(
        compact: &str,
        public_key: &ATProtoJWTVerificationKey,
        expected_audience: Option<&str>,
        expected_method: Option<&str>,
        expected_request_body_digest: Option<&str>,
        now: SystemTime,
    ) -> Result<ServiceJWTClaims, PetrelCryptoError> {
        let options = ServiceJWTVerifyOptions {
            signature_options: ATProtoSignatureVerificationOptions::JWT,
            expected_audience,
            expected_method,
            expected_request_body_digest,
            now,
            clock_skew: Self::DEFAULT_CLOCK_SKEW,
            maximum_lifetime: Self::DEFAULT_MAXIMUM_LIFETIME,
        };
        ServiceJWT::verify_with_options(compact, public_key, &options)
    }

    /// Verifies a service JWT against a [`PLCDIDVerificationKey`] using Spaces defaults.
    pub fn verify_with_plc_key(
        compact: &str,
        public_key: &PLCDIDVerificationKey,
        expected_audience: Option<&str>,
        expected_method: Option<&str>,
        expected_request_body_digest: Option<&str>,
        now: SystemTime,
    ) -> Result<ServiceJWTClaims, PetrelCryptoError> {
        Self::verify(
            compact,
            &ATProtoJWTVerificationKey::from_plc_key(public_key),
            expected_audience,
            expected_method,
            expected_request_body_digest,
            now,
        )
    }
}

fn system_time_to_unix_secs(time: SystemTime) -> Option<i64> {
    match time.duration_since(UNIX_EPOCH) {
        Ok(d) => i64::try_from(d.as_secs()).ok(),
        Err(err) => {
            let d = err.duration();
            let secs = d.as_secs();
            if d.subsec_nanos() == 0 {
                i64::try_from(secs).ok().and_then(i64::checked_neg)
            } else {
                // Match Swift `Int64(timeIntervalSince1970)` truncation toward zero?
                // Wait: Swift `Int64(-1.5) == -1`, `Int64(-1.0) == -1`.
                i64::try_from(secs).ok().and_then(i64::checked_neg)
            }
        }
    }
}

fn unix_secs_to_system_time(secs: i64) -> SystemTime {
    if secs >= 0 {
        UNIX_EPOCH + Duration::from_secs(secs.cast_unsigned())
    } else {
        UNIX_EPOCH - Duration::from_secs(secs.unsigned_abs())
    }
}
