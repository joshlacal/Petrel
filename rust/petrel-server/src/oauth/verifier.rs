use std::collections::HashMap;
use std::sync::Arc;

use async_lock::Mutex;
use petrel_oauth_scopes::{OAuthScopeAdmissionPolicy, OAuthUnknownScopePolicy, ScopeSet};

use crate::dpop::{
    DpopValidationContext, OAuthDpopError, OAuthDpopNonceService, OAuthDpopProofValidator,
    OAuthDpopReplayChecker,
};
use crate::error::OAuthServerError;
use crate::http::OAuthHttpHeaders;
use crate::jose::{
    OAuthCompactJwt, OAuthJsonWebKeySet, OAuthJwsAlgorithm, OAuthJwtVerificationConstraints,
};
use crate::lexicon::{OAuthLexiconScopeResolution, OAuthScopeResolutionStage};
use crate::oauth::tokens::OAuthAccessTokenClaims;
use crate::store::{OAuthGrantBinding, OAuthReplayStore, OAuthTokenStore, ReplayStoreDpopChecker};
use crate::support::{DigestPurpose, OAuthClock, OAuthKeyedDigest};

/// Verified AT Protocol OAuth access grant extracted by a resource server.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthAccessGrant {
    pub session_id: Option<String>,
    pub client_id: String,
    pub did: String,
    pub binding: OAuthGrantBinding,
    pub raw_scopes: ScopeSet,
    pub expanded_scopes: ScopeSet,
    pub dpop_jkt: String,
    pub expires_at_secs: i64,
}

impl OAuthAccessGrant {
    /// Checks `repo:<collection>?action=<action>`.
    pub fn require_repo(&self, collection: &str, action: &str) -> Result<(), OAuthServerError> {
        self.expanded_scopes
            .require_repo(collection, action)
            .map_err(|err| OAuthServerError::Unauthorized(err.needed))
    }

    /// Checks `rpc:<lxm>?aud=<aud>`.
    pub fn require_rpc(&self, lxm: &str, aud: &str) -> Result<(), OAuthServerError> {
        self.expanded_scopes
            .require_rpc(lxm, aud)
            .map_err(|err| OAuthServerError::Unauthorized(err.needed))
    }

    /// Checks `blob:<mime>`.
    pub fn require_blob(&self, mime: &str) -> Result<(), OAuthServerError> {
        self.expanded_scopes
            .require_blob(mime)
            .map_err(|err| OAuthServerError::Unauthorized(err.needed))
    }

    /// Checks `account:<attr>?action=<action>`.
    pub fn require_account(&self, attr: &str, action: &str) -> Result<(), OAuthServerError> {
        self.expanded_scopes
            .require_account(attr, action)
            .map_err(|err| OAuthServerError::Unauthorized(err.needed))
    }

    /// Checks `identity:<attr>`.
    pub fn require_identity(&self, attr: &str) -> Result<(), OAuthServerError> {
        self.expanded_scopes
            .require_identity(attr)
            .map_err(|err| OAuthServerError::Unauthorized(err.needed))
    }
}

/// Resource server challenge payload (`401` + `WWW-Authenticate: DPoP ...` + optional `DPoP-Nonce`).
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[error("{error}: {error_description}")]
pub struct OAuthResourceChallenge {
    pub status: u16,
    pub error: &'static str,
    pub error_description: String,
    pub www_authenticate: String,
    pub dpop_nonce: Option<String>,
}

impl OAuthResourceChallenge {
    pub(crate) fn unauthorized(
        error: &'static str,
        description: impl Into<String>,
        nonce: Option<String>,
    ) -> Self {
        let desc = description.into();
        let escaped = desc.replace('"', "'");
        let www_authenticate = format!(
            "DPoP algs=\"ES256 ES256K\", error=\"{error}\", error_description=\"{escaped}\""
        );
        Self {
            status: 401,
            error,
            error_description: desc,
            www_authenticate,
            dpop_nonce: nonce,
        }
    }
}

/// Token verification strategy for [`OAuthResourceServerVerifier`].
#[derive(Clone)]
pub enum OAuthResourceVerificationMode {
    /// Looks up opaque or JWT access tokens against the shared authorization server store.
    Shared {
        token_store: Arc<dyn OAuthTokenStore>,
        keyed_digest: OAuthKeyedDigest,
    },
    /// Verifies self-contained `at+jwt` tokens offline against issuer JWKS (no token store lookup).
    Stateless {
        issuer: String,
        jwks: OAuthJsonWebKeySet,
        expected_audience: Option<String>,
    },
}

impl std::fmt::Debug for OAuthResourceVerificationMode {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Shared { .. } => f.debug_struct("Shared").finish_non_exhaustive(),
            Self::Stateless {
                issuer,
                expected_audience,
                ..
            } => f
                .debug_struct("Stateless")
                .field("issuer", issuer)
                .field("expected_audience", expected_audience)
                .finish_non_exhaustive(),
        }
    }
}

/// Verifies `Authorization: DPoP <access_token>` + `DPoP` proofs on protected resource endpoints.
pub struct OAuthResourceServerVerifier {
    mode: OAuthResourceVerificationMode,
    dpop_validator: OAuthDpopProofValidator,
    replay_checker: Arc<dyn OAuthDpopReplayChecker>,
    clock: Arc<dyn OAuthClock>,
    require_dpop_nonce: bool,
    scope_resolver: Option<Arc<dyn OAuthLexiconScopeResolution>>,
    scope_cache: Mutex<HashMap<String, (i64, ScopeSet)>>,
}

impl std::fmt::Debug for OAuthResourceServerVerifier {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("OAuthResourceServerVerifier")
            .field("mode", &self.mode)
            .field("require_dpop_nonce", &self.require_dpop_nonce)
            .finish_non_exhaustive()
    }
}

struct ClockBox(Arc<dyn OAuthClock>);
impl OAuthClock for ClockBox {
    fn now_secs(&self) -> i64 {
        self.0.now_secs()
    }
    fn now_unix_f64(&self) -> f64 {
        self.0.now_unix_f64()
    }
}

impl OAuthResourceServerVerifier {
    /// Builds a resource server verifier sharing `nonce_service`, `keyed_digest`, and `replay_store`.
    pub fn new(
        mode: OAuthResourceVerificationMode,
        nonce_service: OAuthDpopNonceService,
        keyed_digest: OAuthKeyedDigest,
        replay_store: Arc<dyn OAuthReplayStore>,
        clock: Arc<dyn OAuthClock>,
    ) -> Self {
        let dpop_validator = OAuthDpopProofValidator::new(nonce_service, keyed_digest)
            .with_clock(ClockBox(clock.clone()));
        #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
        let replay_checker = Arc::new(ReplayStoreDpopChecker::new(replay_store, clock.clone()));
        Self {
            mode,
            dpop_validator,
            replay_checker,
            clock,
            require_dpop_nonce: true,
            scope_resolver: None,
            scope_cache: Mutex::new(HashMap::new()),
        }
    }

    /// Configures whether resource endpoints require a fresh server `DPoP-Nonce` claim (default `true`).
    #[must_use]
    pub fn with_require_dpop_nonce(mut self, required: bool) -> Self {
        self.require_dpop_nonce = required;
        self
    }

    /// Installs an optional `include:` permission-set expander for incoming grants.
    #[must_use]
    pub fn with_scope_resolver(mut self, resolver: Arc<dyn OAuthLexiconScopeResolution>) -> Self {
        self.scope_resolver = Some(resolver);
        self
    }

    /// Current nonce for issuing `DPoP-Nonce` headers alongside successful resource responses.
    pub fn current_nonce(&self) -> String {
        self.dpop_validator.current_nonce()
    }

    /// Authenticates an incoming HTTP request (`method`, full request `url`, and `headers`).
    pub async fn authenticate(
        &self,
        method: &str,
        url: &str,
        headers: &OAuthHttpHeaders,
    ) -> Result<OAuthAccessGrant, OAuthResourceChallenge> {
        let auth_vals = headers.values("Authorization");
        let current_nonce = self.dpop_validator.current_nonce();
        if auth_vals.is_empty() {
            return Err(OAuthResourceChallenge::unauthorized(
                "invalid_token",
                "missing Authorization header",
                Some(current_nonce),
            ));
        }
        if auth_vals.len() > 1 {
            return Err(OAuthResourceChallenge::unauthorized(
                "invalid_request",
                "multiple Authorization headers",
                Some(current_nonce),
            ));
        }
        let mut parts = auth_vals[0].trim().splitn(2, char::is_whitespace);
        let scheme = parts.next().unwrap_or("");
        let token = parts.next().map_or("", str::trim);
        if !scheme.eq_ignore_ascii_case("DPoP") || token.is_empty() {
            return Err(OAuthResourceChallenge::unauthorized(
                "invalid_token",
                "Authorization header must use DPoP scheme",
                Some(current_nonce),
            ));
        }

        let now = self.clock.now_secs();
        let (session_id, client_id, binding, scope_str, expected_jkt, expires_at_secs) = self
            .resolve_token_binding(token, now, &current_nonce)
            .await?;

        let ctx = DpopValidationContext {
            method,
            url,
            expected_access_token: Some(token),
            expected_jkt: Some(&expected_jkt),
            require_nonce: self.require_dpop_nonce,
        };
        if let Err(err) = self
            .dpop_validator
            .validate_headers(headers, ctx, self.replay_checker.as_ref())
            .await
        {
            return Err(match err {
                OAuthDpopError::UseDpopNonce { next_nonce } => {
                    OAuthResourceChallenge::unauthorized(
                        "use_dpop_nonce",
                        "DPoP nonce is required or stale",
                        Some(next_nonce),
                    )
                }
                OAuthDpopError::InvalidDpopProof(reason) => OAuthResourceChallenge::unauthorized(
                    "invalid_dpop_proof",
                    reason,
                    Some(current_nonce),
                ),
            });
        }

        let raw_scopes = ScopeSet::from_scope_string(&scope_str);
        let expanded_scopes = self.expand_grant_scopes(&raw_scopes).await;

        Ok(OAuthAccessGrant {
            session_id,
            client_id,
            did: binding.did().to_owned(),
            binding,
            raw_scopes,
            expanded_scopes,
            dpop_jkt: expected_jkt,
            expires_at_secs,
        })
    }

    async fn resolve_token_binding(
        &self,
        token: &str,
        now: i64,
        current_nonce: &str,
    ) -> Result<
        (
            Option<String>,
            String,
            OAuthGrantBinding,
            String,
            String,
            i64,
        ),
        OAuthResourceChallenge,
    > {
        match &self.mode {
            OAuthResourceVerificationMode::Shared {
                token_store,
                keyed_digest,
            } => {
                let digest = keyed_digest.digest_str(token, DigestPurpose::AccessToken);
                let session = token_store
                    .lookup_by_access_token_digest(&digest)
                    .await
                    .map_err(|_| {
                        OAuthResourceChallenge::unauthorized(
                            "invalid_token",
                            "token verification unavailable",
                            Some(current_nonce.to_owned()),
                        )
                    })?
                    .ok_or_else(|| {
                        OAuthResourceChallenge::unauthorized(
                            "invalid_token",
                            "unknown access token",
                            Some(current_nonce.to_owned()),
                        )
                    })?;
                if !session.is_access_token_active_at(now) {
                    return Err(OAuthResourceChallenge::unauthorized(
                        "invalid_token",
                        "access token is expired or revoked",
                        Some(current_nonce.to_owned()),
                    ));
                }
                let jkt = session.dpop_jkt.clone().ok_or_else(|| {
                    OAuthResourceChallenge::unauthorized(
                        "invalid_token",
                        "session lacks DPoP key binding",
                        Some(current_nonce.to_owned()),
                    )
                })?;
                Ok((
                    Some(session.session_id),
                    session.client_id,
                    session.binding,
                    session.scope,
                    jkt,
                    session.access_token_expires_at_secs,
                ))
            }
            OAuthResourceVerificationMode::Stateless {
                issuer,
                jwks,
                expected_audience,
            } => {
                let mut constraints = OAuthJwtVerificationConstraints::new(now);
                constraints.allowed_algorithms =
                    vec![OAuthJwsAlgorithm::Es256, OAuthJwsAlgorithm::Es256k];
                constraints.expected_type = Some("at+jwt".to_owned());
                constraints.expected_issuer = Some(issuer.clone());
                constraints.expected_audience.clone_from(expected_audience);
                constraints.require_issued_at = true;
                constraints.require_expiration = true;
                let verified = OAuthCompactJwt::verify_with_jwks::<OAuthAccessTokenClaims>(
                    token,
                    jwks,
                    &constraints,
                )
                .map_err(|err| {
                    OAuthResourceChallenge::unauthorized(
                        "invalid_token",
                        err.to_string(),
                        Some(current_nonce.to_owned()),
                    )
                })?;
                let c = verified.claims;
                let jkt = c.cnf.map(|cnf| cnf.jkt).ok_or_else(|| {
                    OAuthResourceChallenge::unauthorized(
                        "invalid_token",
                        "access token JWT missing cnf.jkt",
                        Some(current_nonce.to_owned()),
                    )
                })?;
                let binding = match (c.device_id, c.account_id) {
                    (Some(device_id), Some(account_id)) => OAuthGrantBinding::DeviceAccount {
                        device_id,
                        account_id,
                        did: c.sub.clone(),
                    },
                    _ => OAuthGrantBinding::Subject { did: c.sub },
                };
                Ok((c.session_id, c.client_id, binding, c.scope, jkt, c.exp))
            }
        }
    }

    async fn expand_grant_scopes(&self, raw_scopes: &ScopeSet) -> ScopeSet {
        const SCOPE_CACHE_TTL_SECS: i64 = 60;
        const SCOPE_CACHE_MAX_ENTRIES: usize = 2048;

        let Some(ref resolver) = self.scope_resolver else {
            return raw_scopes.clone();
        };
        let cache_key = raw_scopes.scope_string();
        let now = self.clock.now_secs();
        {
            let guard = self.scope_cache.lock().await;
            if let Some((expires_at, cached)) = guard.get(&cache_key)
                && now < *expires_at
            {
                return cached.clone();
            }
        }
        let empty_langs: &[&str] = &[];
        let expanded = match resolver
            .resolve_scopes(
                raw_scopes,
                raw_scopes,
                OAuthUnknownScopePolicy::Ignore,
                OAuthScopeResolutionStage::Authorization,
                empty_langs,
            )
            .await
        {
            Ok(outcome) => outcome.expanded,
            Err(_) => OAuthScopeAdmissionPolicy::admit(
                raw_scopes,
                raw_scopes,
                OAuthUnknownScopePolicy::Ignore,
            )
            .unwrap_or_else(|_| raw_scopes.clone()),
        };
        let mut guard = self.scope_cache.lock().await;
        if guard.len() >= SCOPE_CACHE_MAX_ENTRIES && !guard.contains_key(&cache_key) {
            guard.retain(|_, (exp, _)| now < *exp);
            if guard.len() >= SCOPE_CACHE_MAX_ENTRIES {
                guard.clear();
            }
        }
        guard.insert(cache_key, (now + SCOPE_CACHE_TTL_SECS, expanded.clone()));
        expanded
    }
}
