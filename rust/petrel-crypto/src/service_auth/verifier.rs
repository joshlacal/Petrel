//! End-to-end service-auth JWT verifier (`ServiceAuthVerifier`).

use std::collections::{BTreeSet, HashMap};
use std::fmt;
use std::sync::Arc;
use std::time::Duration;

use web_time::{SystemTime, UNIX_EPOCH};

use crate::keys::PublicKey;
use crate::service_auth::error::ServiceAuthError;
use crate::service_auth::key_resolver::ServiceAuthKeyResolver;
use crate::service_auth::policy::{
    ServiceAuthAudience, ServiceAuthMethodPolicy, ServiceAuthRequiredClaims, VerifiedServiceAuth,
};
use crate::service_auth::replay_store::ServiceAuthReplayStore;
use crate::service_auth::syntax;
use crate::service_jwt::{
    ParsedServiceJWT, ServiceJWT, ServiceJWTClaims, ServiceJWTHeader, TimeFailure,
};
use crate::signature::ATProtoSignatureVerificationOptions;

/// Configuration for [`ServiceAuthVerifier`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ServiceAuthVerifierConfig {
    /// Which `aud` values name this service.
    pub audience: ServiceAuthAudience,
    /// Verification methods (`#...`) accepted in the `kid` header. Defaults to `{"#atproto"}`.
    pub accepted_key_ids: BTreeSet<String>,
    /// Legacy issuer `#fragment -> #key_id` mapping (e.g. `{"atproto_labeler": "#atproto_label"}`).
    pub issuer_fragment_key_ids: HashMap<String, String>,
    /// Seconds past `exp` tolerated for clock skew (0..=300s; values outside are treated as 0).
    pub clock_skew: Duration,
    /// Longest-lived token accepted (must be > 0 and <= 365 days; invalid values fail closed).
    pub maximum_lifetime: Duration,
    /// Claims to insist on beyond the reference verifier (`iss`, `aud`, `exp`).
    pub required_claims: ServiceAuthRequiredClaims,
    /// Which signature encodings are accepted (defaults to [`ATProtoSignatureVerificationOptions::JWT`]).
    pub signature_options: ATProtoSignatureVerificationOptions,
}

impl ServiceAuthVerifierConfig {
    /// Creates a configuration with default time bounds, `#atproto` key ID, and `.jwt` signature policy.
    pub fn new(audience: ServiceAuthAudience) -> Self {
        let mut accepted_key_ids = BTreeSet::new();
        accepted_key_ids.insert(ServiceJWT::DEFAULT_KEY_ID.to_owned());
        Self {
            audience,
            accepted_key_ids,
            issuer_fragment_key_ids: HashMap::new(),
            clock_skew: ServiceJWT::DEFAULT_CLOCK_SKEW,
            maximum_lifetime: ServiceJWT::DEFAULT_MAXIMUM_ACCEPTED_LIFETIME,
            required_claims: ServiceAuthRequiredClaims::REFERENCE,
            signature_options: ATProtoSignatureVerificationOptions::JWT,
        }
    }
}

/// Alias matching Swift's `ServiceAuthVerifier.Configuration`.
pub type ServiceAuthVerifierConfiguration = ServiceAuthVerifierConfig;

/// Authenticates incoming requests carrying an AT Protocol service-auth JWT.
pub struct ServiceAuthVerifier {
    config: ServiceAuthVerifierConfig,
    key_resolver: Arc<dyn ServiceAuthKeyResolver>,
    replay_store: Option<Arc<dyn ServiceAuthReplayStore>>,
}

impl fmt::Debug for ServiceAuthVerifier {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ServiceAuthVerifier")
            .field("config", &self.config)
            .field("has_replay_store", &self.replay_store.is_some())
            .finish_non_exhaustive()
    }
}

impl ServiceAuthVerifier {
    /// Creates a verifier with the default configuration for `audience`.
    pub fn new(
        audience: ServiceAuthAudience,
        key_resolver: Arc<dyn ServiceAuthKeyResolver>,
    ) -> Self {
        Self::from_config(ServiceAuthVerifierConfig::new(audience), key_resolver, None)
    }

    /// Creates a verifier with default configuration and a replay store.
    pub fn with_replay_store(
        audience: ServiceAuthAudience,
        key_resolver: Arc<dyn ServiceAuthKeyResolver>,
        replay_store: Arc<dyn ServiceAuthReplayStore>,
    ) -> Self {
        Self::from_config(
            ServiceAuthVerifierConfig::new(audience),
            key_resolver,
            Some(replay_store),
        )
    }

    /// Creates a verifier from an explicit [`ServiceAuthVerifierConfig`].
    pub fn from_config(
        config: ServiceAuthVerifierConfig,
        key_resolver: Arc<dyn ServiceAuthKeyResolver>,
        replay_store: Option<Arc<dyn ServiceAuthReplayStore>>,
    ) -> Self {
        Self {
            config,
            key_resolver,
            replay_store,
        }
    }

    /// Returns the verifier's configuration.
    pub const fn config(&self) -> &ServiceAuthVerifierConfig {
        &self.config
    }

    /// Extracts the token from an `Authorization: Bearer <token>` header value.
    pub fn bearer_token_from_authorization_header(
        header: Option<&str>,
    ) -> Result<String, ServiceAuthError> {
        let Some(header) = header else {
            return Err(ServiceAuthError::MissingAuthorization);
        };
        let trimmed = header.trim_matches(|c| c == ' ' || c == '\t');
        if trimmed.is_empty() {
            return Err(ServiceAuthError::MissingAuthorization);
        }
        let scheme = "bearer ";
        if trimmed.len() <= scheme.len() || !trimmed[..scheme.len()].eq_ignore_ascii_case(scheme) {
            return Err(ServiceAuthError::UnsupportedAuthorizationScheme);
        }
        let token = trimmed[scheme.len()..].trim_matches(|c| c == ' ' || c == '\t');
        if token.is_empty() || token.bytes().any(|b| b <= 0x20 || b >= 0x7F) {
            return Err(ServiceAuthError::UnsupportedAuthorizationScheme);
        }
        Ok(token.to_owned())
    }

    /// Authenticates a request from its `Authorization` header using the current system clock.
    pub async fn verify_authorization_header(
        &self,
        authorization_header: Option<&str>,
        method: &ServiceAuthMethodPolicy,
    ) -> Result<VerifiedServiceAuth, ServiceAuthError> {
        self.verify_authorization_header_at(authorization_header, method, SystemTime::now())
            .await
    }

    /// Authenticates a request from its `Authorization` header at a specified clock instant.
    pub async fn verify_authorization_header_at(
        &self,
        authorization_header: Option<&str>,
        method: &ServiceAuthMethodPolicy,
        now: SystemTime,
    ) -> Result<VerifiedServiceAuth, ServiceAuthError> {
        let token = Self::bearer_token_from_authorization_header(authorization_header)?;
        self.verify_token_at(&token, method, now).await
    }

    /// Verifies a bare compact service JWT using the current system clock.
    pub async fn verify_token(
        &self,
        token: &str,
        method: &ServiceAuthMethodPolicy,
    ) -> Result<VerifiedServiceAuth, ServiceAuthError> {
        self.verify_token_at(token, method, SystemTime::now()).await
    }

    /// Verifies a bare compact service JWT at a specified clock instant.
    pub async fn verify_token_at(
        &self,
        token: &str,
        method: &ServiceAuthMethodPolicy,
        now: SystemTime,
    ) -> Result<VerifiedServiceAuth, ServiceAuthError> {
        let parsed =
            ServiceJWT::parse(token, self.config.signature_options.allow_der).map_err(|err| {
                match err {
                    crate::error::PetrelCryptoError::Expired => ServiceAuthError::Expired,
                    crate::error::PetrelCryptoError::Malformed(detail)
                    | crate::error::PetrelCryptoError::Unauthorized(detail)
                    | crate::error::PetrelCryptoError::InvalidIdentifier(detail)
                    | crate::error::PetrelCryptoError::UnsupportedAlgorithm(detail) => {
                        ServiceAuthError::MalformedToken(detail)
                    }
                    crate::error::PetrelCryptoError::Entropy => {
                        ServiceAuthError::MalformedToken("entropy unavailable".into())
                    }
                }
            })?;

        let header = &parsed.header;
        let claims = &parsed.claims;

        if header.crit.is_some() || header.b64.is_some() {
            return Err(ServiceAuthError::MalformedToken(
                "unsupported critical header parameters".into(),
            ));
        }
        if let Some(typ) = header.typ.as_deref()
            && ServiceJWT::is_disallowed_type(typ)
        {
            return Err(ServiceAuthError::DisallowedTokenType(typ.to_owned()));
        }

        self.check_times(claims, now)?;

        if !self.config.audience.accepts(&claims.aud) {
            return Err(ServiceAuthError::AudienceMismatch {
                actual: claims.aud.clone(),
            });
        }

        method.check(claims.lxm.as_deref())?;

        let Some((issuer_did, issuer_fragment)) = syntax::split_did_reference(&claims.iss) else {
            return Err(ServiceAuthError::InvalidIssuer(claims.iss.clone()));
        };

        if let Some(failure) = ServiceJWT::shape_failure(header, claims) {
            return Err(failure);
        }

        self.check_required_claims(header, claims)?;

        if !ServiceJWT::is_allowed_algorithm(&header.alg) {
            return Err(ServiceAuthError::UnsupportedAlgorithm(header.alg.clone()));
        }

        let key_id = self.select_key_id(header, issuer_fragment)?;
        let signing_key = self
            .verified_signing_key(&parsed, issuer_did, &key_id)
            .await?;

        let expires_at = unix_secs_to_system_time(claims.exp);
        let issued_at = claims.iat.map(unix_secs_to_system_time);

        if let Some(replay_store) = &self.replay_store
            && let Some(nonce) = claims.jti.as_deref()
            && !nonce.is_empty()
        {
            let first_use = replay_store
                .claim(nonce, issuer_did, self.replay_record_expiry(claims.exp))
                .await
                .map_err(|err| ServiceAuthError::ReplayStoreFailed(err.to_string()))?;
            if !first_use {
                return Err(ServiceAuthError::Replayed);
            }
        }

        Ok(VerifiedServiceAuth {
            issuer: issuer_did.to_owned(),
            issuer_fragment: issuer_fragment.map(str::to_owned),
            key_id,
            audience: claims.aud.clone(),
            lexicon_method: claims.lxm.clone(),
            nonce: claims
                .jti
                .as_deref()
                .filter(|j| !j.is_empty())
                .map(str::to_owned),
            expires_at,
            issued_at,
            algorithm: header.alg.clone(),
            signing_key,
            claims: claims.clone(),
        })
    }

    fn effective_clock_skew(&self) -> Duration {
        if self.config.clock_skew <= Duration::from_secs(5 * 60) {
            self.config.clock_skew
        } else {
            Duration::ZERO
        }
    }

    fn replay_record_expiry(&self, exp: i64) -> SystemTime {
        let skew_secs = i64::try_from(self.effective_clock_skew().as_secs()).unwrap_or(0);
        let Some(last_accepted) = exp.checked_add(skew_secs).and_then(|v| v.checked_add(1)) else {
            return UNIX_EPOCH + Duration::from_secs(u64::MAX / 2);
        };
        unix_secs_to_system_time(last_accepted)
    }

    fn check_times(
        &self,
        claims: &ServiceJWTClaims,
        now: SystemTime,
    ) -> Result<(), ServiceAuthError> {
        let skew = self.effective_clock_skew();
        let ceiling = self.config.maximum_lifetime;
        if !ServiceJWT::is_valid_time_policy(skew, ceiling) {
            return Err(ServiceAuthError::ExcessiveLifetime { maximum_secs: 0 });
        }
        match ServiceJWT::time_failure(claims, now, skew, ceiling) {
            None => Ok(()),
            Some(TimeFailure::Expired) => Err(ServiceAuthError::Expired),
            Some(TimeFailure::ExcessiveLifetime) => Err(ServiceAuthError::ExcessiveLifetime {
                maximum_secs: ceiling.as_secs(),
            }),
            Some(TimeFailure::ExpiresBeforeIssued) => Err(ServiceAuthError::MalformedToken(
                "exp is earlier than iat".into(),
            )),
            Some(TimeFailure::InvalidClock) => Err(ServiceAuthError::MalformedToken(
                "verifier clock is out of range".into(),
            )),
        }
    }

    fn check_required_claims(
        &self,
        header: &ServiceJWTHeader,
        claims: &ServiceJWTClaims,
    ) -> Result<(), ServiceAuthError> {
        let required = self.config.required_claims;
        if required.contains(ServiceAuthRequiredClaims::TYPE) && header.typ.is_none() {
            return Err(ServiceAuthError::MissingClaim("typ".into()));
        }
        if required.contains(ServiceAuthRequiredClaims::ISSUED_AT) && claims.iat.is_none() {
            return Err(ServiceAuthError::MissingClaim("iat".into()));
        }
        if (required.contains(ServiceAuthRequiredClaims::NONCE) || self.replay_store.is_some())
            && claims.jti.as_deref().is_none_or(str::is_empty)
        {
            return Err(ServiceAuthError::MissingClaim("jti".into()));
        }
        Ok(())
    }

    fn select_key_id(
        &self,
        header: &ServiceJWTHeader,
        issuer_fragment: Option<&str>,
    ) -> Result<String, ServiceAuthError> {
        if let Some(key_id) = header.kid.as_deref() {
            if !syntax::is_key_id(key_id) {
                return Err(ServiceAuthError::MalformedToken(
                    "kid is not a DID document fragment starting with #".into(),
                ));
            }
            if !self.config.accepted_key_ids.contains(key_id) {
                return Err(ServiceAuthError::KeyNotAccepted {
                    key_id: key_id.to_owned(),
                });
            }
            return Ok(key_id.to_owned());
        }
        if let Some(fragment) = issuer_fragment
            && let Some(mapped) = self.config.issuer_fragment_key_ids.get(fragment)
        {
            return Ok(mapped.clone());
        }
        if !self
            .config
            .accepted_key_ids
            .contains(ServiceJWT::DEFAULT_KEY_ID)
        {
            return Err(ServiceAuthError::KeyNotAccepted {
                key_id: ServiceJWT::DEFAULT_KEY_ID.to_owned(),
            });
        }
        Ok(ServiceJWT::DEFAULT_KEY_ID.to_owned())
    }

    async fn verified_signing_key(
        &self,
        parsed: &ParsedServiceJWT,
        issuer_did: &str,
        key_id: &str,
    ) -> Result<PublicKey, ServiceAuthError> {
        let cached = self.resolve_key(issuer_did, key_id, false).await?;
        if self.signature_verifies(parsed, &cached) {
            return Ok(cached);
        }
        let fresh = self.resolve_key(issuer_did, key_id, true).await?;
        if fresh != cached && self.signature_verifies(parsed, &fresh) {
            return Ok(fresh);
        }
        Err(ServiceAuthError::InvalidSignature)
    }

    fn signature_verifies(&self, parsed: &ParsedServiceJWT, key: &PublicKey) -> bool {
        key.jwt_algorithm() == parsed.header.alg
            && key.is_valid_signature(
                &parsed.signature,
                &parsed.signing_input,
                self.config.signature_options,
            )
    }

    async fn resolve_key(
        &self,
        did: &str,
        key_id: &str,
        force_refresh: bool,
    ) -> Result<PublicKey, ServiceAuthError> {
        if key_id == ServiceJWT::DEFAULT_KEY_ID {
            self.key_resolver.signing_key(did, force_refresh).await
        } else {
            self.key_resolver
                .signing_key_for_id(did, key_id, force_refresh)
                .await
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
