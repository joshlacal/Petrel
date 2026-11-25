use std::collections::HashSet;
use std::fmt;

use petrel_oauth_scopes::OAuthUnknownScopePolicy;
use url::Url;
use zeroize::Zeroizing;

use crate::error::OAuthServerError;
use crate::jose::{OAuthJsonWebKey, OAuthJwsAlgorithm, OAuthSigningKey};

/// Wire format of issued access tokens.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum OAuthAccessTokenFormat {
    /// Random opaque token persisted in [`crate::store::OAuthTokenStore`].
    #[default]
    Opaque,
    /// Self-contained `typ = "at+jwt"` ECDSA JWT (supports stateless [`crate::oauth::OAuthResourceServerVerifier`]).
    Jwt,
}

/// Configuration for [`crate::oauth::OAuthAuthorizationServer`].
#[derive(Clone)]
pub struct OAuthAuthorizationServerConfiguration {
    /// Canonical server issuer URL (no trailing slash unless root path is empty, no query/fragment).
    pub issuer: String,
    /// HMAC secret (>= 32 bytes) used for token/code digests and rotating DPoP nonces.
    pub server_secret: Zeroizing<Vec<u8>>,
    /// Issued access token format (`Opaque` or `Jwt`).
    pub access_token_format: OAuthAccessTokenFormat,
    /// Signing key used when `access_token_format == Jwt` (auto-generated ES256 key if `None`).
    pub access_token_signing_key: Option<OAuthSigningKey>,
    /// Public keys retained in `/.well-known/oauth-jwks` during key rotation.
    pub retiring_access_token_keys: Vec<OAuthJsonWebKey>,
    /// Policy for unknown / unrecognized requested scope tokens.
    pub unknown_scope_policy: OAuthUnknownScopePolicy,
    /// Optional audience string stamped into JWT access tokens (defaults to `issuer`).
    pub access_token_audience: Option<String>,
    /// Pre-trusted `client_id` set allowed without normal PAR/discovery constraints where configured.
    pub trusted_client_ids: HashSet<String>,
    /// DPoP nonce rotation step in seconds (default 180s).
    pub dpop_nonce_rotation_interval_secs: i64,
    /// Number of past nonce buckets still accepted (default 2).
    pub dpop_nonce_accepted_previous_buckets: i64,
    /// Require valid `DPoP-Nonce` on PAR requests (default true).
    pub require_dpop_nonce_on_par: bool,
    /// Require valid `DPoP-Nonce` on Token requests (default true).
    pub require_dpop_nonce_on_token: bool,
    /// PAR `request_uri` TTL in seconds (default 90s).
    pub pushed_request_ttl_secs: i64,
    /// Browser CSRF consent flow TTL in seconds (default 600s).
    pub browser_flow_ttl_secs: i64,
    /// Single-use authorization code TTL in seconds (default 60s).
    pub authorization_code_ttl_secs: i64,
    /// Issued access token lifetime in seconds (default 300s).
    pub access_token_ttl_secs: i64,
    /// Public client unused refresh token TTL in seconds (default 14 days, max 14 days per ATProto profile).
    pub public_client_refresh_ttl_secs: i64,
    /// Public client absolute session lifetime from creation in seconds (default 14 days, max 14 days).
    pub public_client_session_lifetime_secs: i64,
    /// Confidential client unused refresh token / session TTL in seconds (default 90 days, max 180 days).
    pub refresh_token_ttl_secs: i64,
    /// Optional confidential client absolute session lifetime from creation in seconds (default 2 years).
    pub confidential_client_session_lifetime_secs: Option<i64>,
    /// Maximum form body accepted on PAR/token/authorize/revoke (default 64 KiB).
    pub max_form_body_bytes: usize,
    /// Additional static scopes advertised in `scopes_supported`.
    pub scopes_supported: Vec<String>,
    /// Minimum interval in seconds between opportunistic expired-state purges (`Some(60)` default, `Some(0)` unthrottled, `None` explicit only).
    pub purge_interval_secs: Option<i64>,
    /// Allow `http://127.0.0.1` / `http://localhost` issuer for local tests only.
    pub allow_insecure_http_issuer_for_testing: bool,
}

impl fmt::Debug for OAuthAuthorizationServerConfiguration {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("OAuthAuthorizationServerConfiguration")
            .field("issuer", &self.issuer)
            .field("access_token_format", &self.access_token_format)
            .field("unknown_scope_policy", &self.unknown_scope_policy)
            .field("require_dpop_nonce_on_par", &self.require_dpop_nonce_on_par)
            .field(
                "require_dpop_nonce_on_token",
                &self.require_dpop_nonce_on_token,
            )
            .field("server_secret", &"<redacted>")
            .finish_non_exhaustive()
    }
}

impl OAuthAuthorizationServerConfiguration {
    /// Creates a validated configuration with AT Protocol OAuth defaults.
    pub fn new(
        issuer: impl Into<String>,
        server_secret: impl Into<Vec<u8>>,
    ) -> Result<Self, OAuthServerError> {
        Self::with_testing_http_allowed(issuer, server_secret, false)
    }

    /// Creates a configuration optionally permitting `http://` loopback issuers for local tests.
    pub fn with_testing_http_allowed(
        issuer: impl Into<String>,
        server_secret: impl Into<Vec<u8>>,
        allow_insecure_http: bool,
    ) -> Result<Self, OAuthServerError> {
        let issuer = normalize_and_validate_issuer(&issuer.into(), allow_insecure_http)?;
        let secret = server_secret.into();
        if secret.len() < 32 {
            return Err(OAuthServerError::Malformed(
                "OAuth server_secret must be at least 32 bytes".into(),
            ));
        }
        Ok(Self {
            issuer,
            server_secret: Zeroizing::new(secret),
            access_token_format: OAuthAccessTokenFormat::Opaque,
            access_token_signing_key: None,
            retiring_access_token_keys: Vec::new(),
            unknown_scope_policy: OAuthUnknownScopePolicy::Reject,
            access_token_audience: None,
            trusted_client_ids: HashSet::new(),
            dpop_nonce_rotation_interval_secs: 180,
            dpop_nonce_accepted_previous_buckets: 2,
            require_dpop_nonce_on_par: true,
            require_dpop_nonce_on_token: true,
            pushed_request_ttl_secs: 90,
            browser_flow_ttl_secs: 600,
            authorization_code_ttl_secs: 60,
            access_token_ttl_secs: 300,
            public_client_refresh_ttl_secs: 14 * 24 * 60 * 60,
            public_client_session_lifetime_secs: 14 * 24 * 60 * 60,
            refresh_token_ttl_secs: 90 * 24 * 60 * 60,
            confidential_client_session_lifetime_secs: Some(2 * 365 * 24 * 60 * 60),
            max_form_body_bytes: 64 * 1024,
            scopes_supported: vec![
                "atproto".to_owned(),
                "transition:generic".to_owned(),
                "transition:email".to_owned(),
                "transition:chat.bsky".to_owned(),
            ],
            purge_interval_secs: Some(60),
            allow_insecure_http_issuer_for_testing: allow_insecure_http,
        })
    }

    /// Validates configuration invariants and materializes an active JWT signing key if needed.
    pub fn validate(&self) -> Result<OAuthSigningKey, OAuthServerError> {
        let _ = normalize_and_validate_issuer(
            &self.issuer,
            self.allow_insecure_http_issuer_for_testing,
        )?;
        if self.server_secret.len() < 32 {
            return Err(OAuthServerError::Malformed(
                "OAuth server_secret must be at least 32 bytes".into(),
            ));
        }
        let day: i64 = 24 * 60 * 60;
        if self.access_token_ttl_secs <= 0
            || self.public_client_refresh_ttl_secs < 60
            || self.public_client_refresh_ttl_secs > 14 * day
            || self.public_client_session_lifetime_secs < 60
            || self.public_client_session_lifetime_secs > 14 * day
            || self.refresh_token_ttl_secs < 60
            || self.refresh_token_ttl_secs > 180 * day
            || self
                .confidential_client_session_lifetime_secs
                .is_some_and(|ttl| ttl < 60)
            || self.pushed_request_ttl_secs <= 0
            || self.authorization_code_ttl_secs <= 0
            || self.browser_flow_ttl_secs <= 0
        {
            return Err(OAuthServerError::Malformed(
                "OAuth TTL values are outside profile limits".into(),
            ));
        }
        if self.purge_interval_secs.is_some_and(|secs| secs < 0) {
            return Err(OAuthServerError::Malformed(
                "OAuth purge_interval_secs must be non-negative".into(),
            ));
        }
        match &self.access_token_signing_key {
            Some(key) => Ok(key.clone()),
            None => OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("at-1".to_owned())),
        }
    }
}

pub(crate) fn normalize_and_validate_issuer(
    raw: &str,
    allow_http_loopback: bool,
) -> Result<String, OAuthServerError> {
    let url = Url::parse(raw)
        .map_err(|_| OAuthServerError::InvalidIdentifier("issuer must be a valid URL".into()))?;
    let host = url
        .host_str()
        .ok_or_else(|| OAuthServerError::InvalidIdentifier("issuer missing host".into()))?;
    let scheme_ok = url.scheme() == "https"
        || (allow_http_loopback
            && url.scheme() == "http"
            && matches!(host, "127.0.0.1" | "localhost" | "[::1]" | "::1"));
    if !scheme_ok {
        return Err(OAuthServerError::InvalidIdentifier(
            "issuer must use https scheme".into(),
        ));
    }
    if !url.username().is_empty() || url.password().is_some() {
        return Err(OAuthServerError::InvalidIdentifier(
            "issuer must not contain userinfo".into(),
        ));
    }
    if url.query().is_some() || url.fragment().is_some() {
        return Err(OAuthServerError::InvalidIdentifier(
            "issuer must not contain query or fragment".into(),
        ));
    }
    let normalized = raw.trim_end_matches('/').to_owned();
    Ok(normalized)
}
