use std::collections::HashMap;
use std::sync::Arc;

use async_lock::Mutex;
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;
use url::Url;

use crate::dpop::{
    DpopValidationContext, OAuthDpopError, OAuthDpopNonceService, OAuthDpopProofValidator,
    OAuthDpopReplayChecker,
};
use crate::error::OAuthServerError;
use crate::http::{OAuthHttpHeaders, OAuthHttpRequest, OAuthHttpResponse};
use crate::jose::{OAuthCompactJwt, OAuthJsonWebKey, OAuthJsonWebKeySet, OAuthSigningKey};
use crate::support::{
    ConstantTime, DigestPurpose, OAuthClock, OAuthKeyedDigest, OAuthRandomSource, SystemOAuthClock,
    SystemOAuthRandomSource,
};

/// OAuth-style error returned by the Client Assertion Backend (CAB).
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[error("{error}: {description}")]
pub struct CabRequestError {
    pub status: u16,
    pub error: String,
    pub description: String,
}

impl CabRequestError {
    /// `400 invalid_dpop_proof`.
    pub fn invalid_dpop_proof(description: impl Into<String>) -> Self {
        Self {
            status: 400,
            error: "invalid_dpop_proof".into(),
            description: description.into(),
        }
    }

    /// `400 invalid_request`.
    pub fn invalid_request(description: impl Into<String>) -> Self {
        Self {
            status: 400,
            error: "invalid_request".into(),
            description: description.into(),
        }
    }

    /// `400 use_dpop_nonce`.
    pub fn use_dpop_nonce() -> Self {
        Self {
            status: 400,
            error: "use_dpop_nonce".into(),
            description: "A DPoP nonce is required; retry with the DPoP-Nonce header value".into(),
        }
    }

    /// `403 access_denied`.
    pub fn access_denied(description: impl Into<String>) -> Self {
        Self {
            status: 403,
            error: "access_denied".into(),
            description: description.into(),
        }
    }

    /// `429 rate_limited`.
    pub fn rate_limited() -> Self {
        Self {
            status: 429,
            error: "rate_limited".into(),
            description: "Too many requests".into(),
        }
    }

    /// `503 temporarily_unavailable`.
    pub fn temporarily_unavailable(description: impl Into<String>) -> Self {
        Self {
            status: 503,
            error: "temporarily_unavailable".into(),
            description: description.into(),
        }
    }
}

/// Configuration for [`CabServerCore`].
#[derive(Debug, Clone)]
pub struct CabServerConfig {
    /// Public base URL of this CAB server (`https://client.example.com` or `http://127.0.0.1:PORT` in tests).
    pub public_base_url: String,
    /// `client_id` stamped into `iss` and `sub` of minted `private_key_jwt` assertions.
    pub client_id: String,
    /// Optional explicit OAuth client metadata document served at `/.well-known/oauth-client-metadata.json`.
    pub client_metadata: Option<JsonValue>,
    /// Allowed target authorization server issuer URLs (`aud`). Empty fails closed.
    pub allowed_audiences: Vec<String>,
    /// Allowed `Origin` header values (empty fails closed for any request with an `Origin` header).
    pub allowed_origins: Vec<String>,
    /// DPoP JWK thumbprints (`jkt`) explicitly denied from requesting assertions.
    pub denied_jkts: Vec<String>,
    /// Require a valid `DPoP-Nonce` on `/oauth/client-assertion` and `/v1/assertions` (default `false` matching Swift `PetrelCABServerCore`).
    pub require_dpop_nonce: bool,
    /// Require prior `/v1/devices/register` enrollment before minting assertions (default `false`; open enrollment by DPoP key unless set).
    pub require_registered_device: bool,
    /// Assertion lifetime in seconds (default 60s, clamped to `1..=60` per ATProto OAuth).
    pub assertion_lifetime_secs: i64,
    /// DPoP nonce rotation interval in seconds.
    pub nonce_rotation_interval_secs: i64,
    /// Maximum requests per sliding window in [`CabRateLimiter`].
    pub rate_limit_max_requests: usize,
    /// Sliding window length in seconds in [`CabRateLimiter`].
    pub rate_limit_window_secs: i64,
    /// Maximum distinct rate-limit bucket keys tracked before stale eviction / fail-closed rejection (default 10,000).
    pub rate_limit_max_keys: usize,
}

impl CabServerConfig {
    /// Creates default CAB configuration for `public_base_url` and `client_id`.
    pub fn new(public_base_url: impl Into<String>, client_id: impl Into<String>) -> Self {
        Self {
            public_base_url: public_base_url.into().trim_end_matches('/').to_owned(),
            client_id: client_id.into(),
            client_metadata: None,
            allowed_audiences: Vec::new(),
            allowed_origins: Vec::new(),
            denied_jkts: Vec::new(),
            require_dpop_nonce: false,
            require_registered_device: false,
            assertion_lifetime_secs: 60,
            nonce_rotation_interval_secs: 180,
            rate_limit_max_requests: 60,
            rate_limit_window_secs: 60,
            rate_limit_max_keys: 10_000,
        }
    }
}

/// Collection of active + retiring EC signing keys used by [`CabAssertionMinter`].
#[derive(Debug, Clone)]
pub struct CabKeyStore {
    pub keys: Vec<OAuthSigningKey>,
    pub active_kid: String,
}

impl CabKeyStore {
    /// Creates a keystore ensuring `active_kid` exists among `keys`.
    pub fn new(
        keys: Vec<OAuthSigningKey>,
        active_kid: impl Into<String>,
    ) -> Result<Self, OAuthServerError> {
        let active_kid = active_kid.into();
        if !keys
            .iter()
            .any(|k| k.key_id.as_deref() == Some(active_kid.as_str()))
        {
            return Err(OAuthServerError::Malformed(
                "CAB active_kid is missing from CabKeyStore".into(),
            ));
        }
        Ok(Self { keys, active_kid })
    }

    /// Returns the active signing key.
    ///
    /// # Panics
    ///
    /// Panics only if internal [`CabKeyStore`] invariants are violated externally.
    pub fn active_key(&self) -> &OAuthSigningKey {
        self.keys
            .iter()
            .find(|k| k.key_id.as_deref() == Some(self.active_kid.as_str()))
            .expect("CabKeyStore invariant guarantees active_kid presence")
    }

    /// Public JWKS published at `/.well-known/jwks.json`.
    pub fn public_jwks(&self) -> Result<OAuthJsonWebKeySet, OAuthServerError> {
        let keys = self
            .keys
            .iter()
            .map(|k| k.public_jwk(true))
            .collect::<Result<Vec<_>, _>>()?;
        Ok(OAuthJsonWebKeySet::new(keys))
    }
}

/// Device registration entry mapping a device ID to its DPoP JWK thumbprint (`jkt`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CabRegisteredDevice {
    pub device_id: String,
    pub dpop_jkt: String,
    pub public_jwk: Option<OAuthJsonWebKey>,
    pub registered_at_secs: i64,
}

/// Persistence abstraction for enrolled mobile/desktop client devices allowed to request assertions.
pub trait CabDeviceStore: MaybeSend + MaybeSync {
    fn register_device(
        &self,
        device: CabRegisteredDevice,
    ) -> BoxFuture<'_, Result<(), CabRequestError>>;

    fn lookup_device(
        &self,
        device_id: &str,
    ) -> BoxFuture<'_, Result<Option<CabRegisteredDevice>, CabRequestError>>;
}

/// In-memory device store for CAB servers.
#[derive(Debug, Default)]
pub struct InMemoryCabDeviceStore {
    devices: Mutex<HashMap<String, CabRegisteredDevice>>,
}

impl InMemoryCabDeviceStore {
    /// Creates an empty device store.
    pub fn new() -> Self {
        Self::default()
    }
}

impl CabDeviceStore for InMemoryCabDeviceStore {
    fn register_device(
        &self,
        device: CabRegisteredDevice,
    ) -> BoxFuture<'_, Result<(), CabRequestError>> {
        Box::pin(async move {
            let mut devices = self.devices.lock().await;
            if let Some(existing) = devices.get(&device.device_id) {
                if ConstantTime::equal(&existing.dpop_jkt, &device.dpop_jkt) {
                    return Ok(());
                }
                return Err(CabRequestError {
                    status: 409,
                    error: "device_already_registered".into(),
                    description: "device_id is already registered to a different key".into(),
                });
            }
            devices.insert(device.device_id.clone(), device);
            Ok(())
        })
    }

    fn lookup_device(
        &self,
        device_id: &str,
    ) -> BoxFuture<'_, Result<Option<CabRegisteredDevice>, CabRequestError>> {
        let id = device_id.to_owned();
        Box::pin(async move { Ok(self.devices.lock().await.get(&id).cloned()) })
    }
}

/// Replay prevention interface for CAB DPoP proof `jti` values.
pub trait CabReplayStore: MaybeSend + MaybeSync {
    fn record_if_fresh(
        &self,
        key: Vec<u8>,
        expires_at_secs: i64,
        now_secs: i64,
    ) -> BoxFuture<'_, Result<bool, CabRequestError>>;
}

/// In-memory CAB replay store.
#[derive(Debug, Default)]
pub struct InMemoryCabReplayStore {
    entries: Mutex<HashMap<Vec<u8>, i64>>,
}

impl InMemoryCabReplayStore {
    /// Creates an empty replay store.
    pub fn new() -> Self {
        Self::default()
    }
}

impl CabReplayStore for InMemoryCabReplayStore {
    fn record_if_fresh(
        &self,
        key: Vec<u8>,
        expires_at_secs: i64,
        now_secs: i64,
    ) -> BoxFuture<'_, Result<bool, CabRequestError>> {
        Box::pin(async move {
            let mut guard = self.entries.lock().await;
            guard.retain(|_, exp| *exp > now_secs);
            if let Some(&existing) = guard.get(&key)
                && existing > now_secs
            {
                return Ok(false);
            }
            guard.insert(key, expires_at_secs);
            Ok(true)
        })
    }
}

struct CabDpopReplayBridge {
    store: Arc<dyn CabReplayStore>,
    clock: Arc<dyn OAuthClock>,
}

impl OAuthDpopReplayChecker for CabDpopReplayBridge {
    fn record_if_fresh(
        &self,
        digest: Vec<u8>,
        expires_at_secs: i64,
    ) -> BoxFuture<'_, Result<bool, OAuthServerError>> {
        let now = self.clock.now_secs();
        Box::pin(async move {
            self.store
                .record_if_fresh(digest, expires_at_secs, now)
                .await
                .map_err(|err| OAuthServerError::Unavailable(err.description))
        })
    }
}

/// Simple sliding-window per-key rate limiter for CAB endpoints with bounded bucket capacity.
#[derive(Debug)]
pub struct CabRateLimiter {
    max_requests: usize,
    window_secs: i64,
    max_keys: usize,
    buckets: Mutex<HashMap<String, Vec<i64>>>,
}

impl CabRateLimiter {
    /// Creates a rate limiter allowing `max_requests` within `window_secs` across up to 10,000 keys.
    pub fn new(max_requests: usize, window_secs: i64) -> Self {
        Self::with_max_keys(max_requests, window_secs, 10_000)
    }

    /// Creates a rate limiter bounded to at most `max_keys` concurrent active buckets.
    pub fn with_max_keys(max_requests: usize, window_secs: i64, max_keys: usize) -> Self {
        Self {
            max_requests: max_requests.max(1),
            window_secs: window_secs.max(1),
            max_keys: max_keys.max(1),
            buckets: Mutex::new(HashMap::new()),
        }
    }

    /// Records one hit for `key` at `now_secs`, returning `Ok(())` or `Err(rate_limited)`.
    pub async fn check(&self, key: &str, now_secs: i64) -> Result<(), CabRequestError> {
        let mut guard = self.buckets.lock().await;
        let cutoff = now_secs.saturating_sub(self.window_secs);
        if !guard.contains_key(key) && guard.len() >= self.max_keys {
            guard.retain(|_, hits| {
                hits.retain(|&ts| ts > cutoff);
                !hits.is_empty()
            });
            if guard.len() >= self.max_keys {
                return Err(CabRequestError::rate_limited());
            }
        }
        let hits = guard.entry(key.to_owned()).or_default();
        hits.retain(|&ts| ts > cutoff);
        if hits.len() >= self.max_requests {
            return Err(CabRequestError::rate_limited());
        }
        hits.push(now_secs);
        Ok(())
    }
}

/// Mints RFC 7523 `private_key_jwt` assertions signed by [`CabKeyStore::active_key`].
#[derive(Debug, Clone)]
pub struct CabAssertionMinter {
    client_id: String,
    key_store: CabKeyStore,
    lifetime_secs: i64,
}

#[derive(Serialize)]
struct MintedClientAssertionClaims<'a> {
    iss: &'a str,
    sub: &'a str,
    aud: &'a str,
    iat: i64,
    exp: i64,
    jti: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    cnf: Option<MintedAssertionCnf<'a>>,
}

#[derive(Serialize)]
struct MintedAssertionCnf<'a> {
    jkt: &'a str,
}

impl CabAssertionMinter {
    /// Creates an assertion minter for `client_id`.
    pub fn new(client_id: impl Into<String>, key_store: CabKeyStore, lifetime_secs: i64) -> Self {
        Self {
            client_id: client_id.into(),
            key_store,
            lifetime_secs,
        }
    }

    /// Mints a signed `private_key_jwt` compact JWT for `audience` optionally bound to `device_jkt` (`cnf.jkt`).
    pub fn mint(
        &self,
        audience: &str,
        device_jkt: Option<&str>,
        now_secs: i64,
        random: &dyn OAuthRandomSource,
    ) -> Result<String, CabRequestError> {
        let claims = MintedClientAssertionClaims {
            iss: &self.client_id,
            sub: &self.client_id,
            aud: audience,
            iat: now_secs,
            exp: now_secs.saturating_add(self.lifetime_secs),
            jti: random.uuid_v4().to_string(),
            cnf: device_jkt.map(|jkt| MintedAssertionCnf { jkt }),
        };
        OAuthCompactJwt::sign(&claims, self.key_store.active_key(), Some("JWT"), false)
            .map_err(|err| CabRequestError::temporarily_unavailable(err.to_string()))
    }
}

#[derive(Deserialize)]
struct RegisterDeviceRequest {
    device_id: String,
    #[serde(default)]
    jwk: Option<OAuthJsonWebKey>,
    #[serde(default)]
    dpop_jkt: Option<String>,
}

#[derive(Deserialize)]
struct MintAssertionJsonRequest {
    #[serde(default)]
    device_id: Option<String>,
    aud: String,
}

#[derive(Serialize)]
struct MintAssertionResponse {
    client_id: String,
    client_assertion: String,
    client_assertion_type: &'static str,
    expires_in: i64,
}

/// Core protocol handler for Petrel Confidential Client Assertion Backend (CAB).
pub struct CabServerCore {
    config: CabServerConfig,
    key_store: CabKeyStore,
    minter: CabAssertionMinter,
    nonce_service: OAuthDpopNonceService,
    dpop_validator: OAuthDpopProofValidator,
    replay_checker: Arc<dyn OAuthDpopReplayChecker>,
    device_store: Arc<dyn CabDeviceStore>,
    rate_limiter: CabRateLimiter,
    clock: Arc<dyn OAuthClock>,
    random: Arc<dyn OAuthRandomSource>,
}

struct ArcClock(Arc<dyn OAuthClock>);
impl OAuthClock for ArcClock {
    fn now_secs(&self) -> i64 {
        self.0.now_secs()
    }
    fn now_unix_f64(&self) -> f64 {
        self.0.now_unix_f64()
    }
}

impl std::fmt::Debug for CabServerCore {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("CabServerCore")
            .field("client_id", &self.config.client_id)
            .field("public_base_url", &self.config.public_base_url)
            .finish_non_exhaustive()
    }
}

impl CabServerCore {
    /// Creates a new CAB server core backed by `key_store`, `device_store`, `replay_store`, and `secret`.
    pub fn new(
        config: CabServerConfig,
        key_store: CabKeyStore,
        secret: &[u8],
        device_store: Arc<dyn CabDeviceStore>,
        replay_store: Arc<dyn CabReplayStore>,
    ) -> Result<Self, OAuthServerError> {
        let clock: Arc<dyn OAuthClock> = Arc::new(SystemOAuthClock);
        let random: Arc<dyn OAuthRandomSource> = Arc::new(SystemOAuthRandomSource);
        Self::with_clock_and_random(
            config,
            key_store,
            secret,
            device_store,
            replay_store,
            clock,
            random,
        )
    }

    /// Creates a CAB server core with injectable clock and CSPRNG (for tests).
    pub fn with_clock_and_random(
        config: CabServerConfig,
        key_store: CabKeyStore,
        secret: &[u8],
        device_store: Arc<dyn CabDeviceStore>,
        replay_store: Arc<dyn CabReplayStore>,
        clock: Arc<dyn OAuthClock>,
        random: Arc<dyn OAuthRandomSource>,
    ) -> Result<Self, OAuthServerError> {
        if !(1..=60).contains(&config.assertion_lifetime_secs) {
            return Err(OAuthServerError::Malformed(
                "CAB assertion_lifetime_secs must be between 1 and 60 seconds".into(),
            ));
        }
        if config.nonce_rotation_interval_secs < 1
            || config.rate_limit_max_requests == 0
            || config.rate_limit_window_secs < 1
            || config.rate_limit_max_keys == 0
        {
            return Err(OAuthServerError::Malformed(
                "CAB timing and rate-limit configuration values must be positive".into(),
            ));
        }
        let keyed_digest = OAuthKeyedDigest::new(secret)?;
        let nonce_service =
            OAuthDpopNonceService::new(secret, config.nonce_rotation_interval_secs, 2)?;
        let dpop_validator = OAuthDpopProofValidator::new(nonce_service.clone(), keyed_digest)
            .with_clock(ArcClock(clock.clone()));
        #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
        let replay_checker: Arc<dyn OAuthDpopReplayChecker> = Arc::new(CabDpopReplayBridge {
            store: replay_store,
            clock: clock.clone(),
        });
        let minter = CabAssertionMinter::new(
            config.client_id.clone(),
            key_store.clone(),
            config.assertion_lifetime_secs,
        );
        let rate_limiter = CabRateLimiter::with_max_keys(
            config.rate_limit_max_requests,
            config.rate_limit_window_secs,
            config.rate_limit_max_keys,
        );
        let _ = DigestPurpose::ClientAssertion;
        Ok(Self {
            config,
            key_store,
            minter,
            nonce_service,
            dpop_validator,
            replay_checker,
            device_store,
            rate_limiter,
            clock,
            random,
        })
    }

    /// Returns the active public JWKS.
    pub fn public_jwks(&self) -> Result<OAuthJsonWebKeySet, OAuthServerError> {
        self.key_store.public_jwks()
    }

    /// Dispatches a framework-agnostic HTTP request to CAB endpoints.
    pub async fn handle(&self, req: OAuthHttpRequest) -> OAuthHttpResponse {
        let origin_header = req.headers.get("Origin").map(str::to_owned);
        if let Err(err) = self.check_origin(&req.headers) {
            return self.error_response(&err, None);
        }
        let now = self.clock.now_secs();
        if let Some(ip) = req.remote_address.as_deref()
            && let Err(err) = self.rate_limiter.check(&format!("ip:{ip}"), now).await
        {
            return self.error_response(&err, None);
        }

        let mut resp = match (req.method.as_str(), req.path.as_str()) {
            (
                "OPTIONS",
                "/health"
                | "/.well-known/oauth-client-metadata.json"
                | "/oauth-client-metadata.json"
                | "/.well-known/jwks.json"
                | "/nonce"
                | "/v1/nonce"
                | "/v1/devices/register"
                | "/oauth/client-assertion"
                | "/v1/assertions",
            ) => Self::cors_preflight(),
            ("GET", "/health") => self.handle_health(&req, now).await,
            ("GET", "/.well-known/oauth-client-metadata.json" | "/oauth-client-metadata.json") => {
                self.handle_client_metadata(&req, now).await
            }
            ("GET", "/.well-known/jwks.json") => self.handle_jwks(&req, now).await,
            ("POST", "/nonce" | "/v1/nonce") => self.handle_nonce(&req, now).await,
            ("POST", "/v1/devices/register") => self.handle_register_device(&req, now).await,
            ("POST", "/oauth/client-assertion" | "/v1/assertions") => {
                self.handle_mint_assertion(&req, now).await
            }
            (
                _,
                "/health"
                | "/.well-known/oauth-client-metadata.json"
                | "/oauth-client-metadata.json"
                | "/.well-known/jwks.json"
                | "/nonce"
                | "/v1/nonce"
                | "/v1/devices/register"
                | "/oauth/client-assertion"
                | "/v1/assertions",
            ) => self.error_response(
                &CabRequestError {
                    status: 405,
                    error: "invalid_request".into(),
                    description: "method not allowed".into(),
                },
                None,
            ),
            _ => self.error_response(&CabRequestError::invalid_request("unknown CAB route"), None),
        };
        if let Some(origin) = origin_header
            && self.origin_is_allowed(&origin)
        {
            resp.headers.set("Access-Control-Allow-Origin", origin);
            resp.headers.set("Vary", "Origin");
            resp.headers
                .set("Access-Control-Expose-Headers", "DPoP-Nonce");
        }
        resp
    }

    async fn check_unauth_rate_limit(
        &self,
        req: &OAuthHttpRequest,
        now: i64,
    ) -> Result<(), CabRequestError> {
        if req.remote_address.is_none() {
            self.rate_limiter.check("unauth:public", now).await?;
        }
        Ok(())
    }

    async fn check_unauth_dpop_rate_limit(
        &self,
        req: &OAuthHttpRequest,
        now: i64,
    ) -> Result<(), CabRequestError> {
        if req.remote_address.is_none() {
            self.rate_limiter.check("unauth:dpop", now).await?;
        }
        Ok(())
    }

    async fn handle_health(&self, req: &OAuthHttpRequest, now: i64) -> OAuthHttpResponse {
        if let Err(err) = self.check_unauth_rate_limit(req, now).await {
            return self.error_response(&err, None);
        }
        self.json_response(200, &serde_json::json!({"status": "ok"}), false)
    }

    async fn handle_client_metadata(&self, req: &OAuthHttpRequest, now: i64) -> OAuthHttpResponse {
        if let Err(err) = self.check_unauth_rate_limit(req, now).await {
            return self.error_response(&err, None);
        }
        match &self.config.client_metadata {
            Some(doc) => self.json_response(200, doc, false),
            None => self.error_response(
                &CabRequestError {
                    status: 404,
                    error: "not_found".into(),
                    description: "client_metadata not configured".into(),
                },
                None,
            ),
        }
    }

    async fn handle_jwks(&self, req: &OAuthHttpRequest, now: i64) -> OAuthHttpResponse {
        if let Err(err) = self.check_unauth_rate_limit(req, now).await {
            return self.error_response(&err, None);
        }
        match self.key_store.public_jwks() {
            Ok(jwks) => self.json_response(200, &jwks, false),
            Err(_) => self.error_response(
                &CabRequestError::temporarily_unavailable("key set unavailable"),
                None,
            ),
        }
    }

    async fn handle_nonce(&self, req: &OAuthHttpRequest, now: i64) -> OAuthHttpResponse {
        if let Err(err) = self.check_unauth_rate_limit(req, now).await {
            return self.error_response(&err, None);
        }
        let nonce = self.nonce_service.current_nonce(now);
        let mut headers = OAuthHttpHeaders::default();
        headers.set("DPoP-Nonce", nonce.clone());
        headers.set("Cache-Control", "no-store");
        headers.set("Content-Type", "application/json");
        let body = serde_json::to_vec(&serde_json::json!({"nonce": nonce}))
            .unwrap_or_else(|_| b"{}".to_vec());
        OAuthHttpResponse::new(200, headers, body)
    }

    fn cors_preflight() -> OAuthHttpResponse {
        let mut headers = OAuthHttpHeaders::default();
        headers.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
        headers.set(
            "Access-Control-Allow-Headers",
            "Authorization, Content-Type, DPoP",
        );
        headers.set("Access-Control-Max-Age", "86400");
        headers.set("Vary", "Origin");
        OAuthHttpResponse::new(204, headers, Vec::new())
    }

    async fn handle_register_device(&self, req: &OAuthHttpRequest, now: i64) -> OAuthHttpResponse {
        if let Err(err) = self.check_unauth_dpop_rate_limit(req, now).await {
            return self.error_response(&err, None);
        }
        let body: RegisterDeviceRequest = match serde_json::from_slice(&req.body) {
            Ok(b) => b,
            Err(_) => {
                return self
                    .error_response(&CabRequestError::invalid_request("invalid JSON body"), None);
            }
        };
        if body.device_id.is_empty() || body.device_id.len() > 256 {
            return self.error_response(
                &CabRequestError::invalid_request("device_id is invalid"),
                None,
            );
        }

        let target_url = format!("{}{}", self.config.public_base_url, req.path);
        let ctx = DpopValidationContext {
            method: "POST",
            url: &target_url,
            expected_access_token: None,
            expected_jkt: None,
            require_nonce: self.config.require_dpop_nonce,
        };
        let validated = match self
            .dpop_validator
            .validate_headers(&req.headers, ctx, self.replay_checker.as_ref())
            .await
        {
            Ok(v) => v,
            Err(OAuthDpopError::UseDpopNonce { next_nonce }) => {
                return self.error_response(&CabRequestError::use_dpop_nonce(), Some(next_nonce));
            }
            Err(OAuthDpopError::InvalidDpopProof(msg)) => {
                return self.error_response(&CabRequestError::invalid_dpop_proof(msg), None);
            }
        };
        if req.remote_address.is_none()
            && let Err(err) = self
                .rate_limiter
                .check(&format!("jkt:{}", validated.jkt), now)
                .await
        {
            return self.error_response(&err, None);
        }

        if let Some(ref body_jwk) = body.jwk
            && !ConstantTime::equal(&body_jwk.thumbprint(), &validated.jkt)
        {
            return self.error_response(
                &CabRequestError::invalid_dpop_proof("body jwk does not match DPoP proof key"),
                None,
            );
        }
        if let Some(ref body_jkt) = body.dpop_jkt
            && !ConstantTime::equal(body_jkt, &validated.jkt)
        {
            return self.error_response(
                &CabRequestError::invalid_dpop_proof("body dpop_jkt does not match DPoP proof key"),
                None,
            );
        }

        let rec = CabRegisteredDevice {
            device_id: body.device_id,
            dpop_jkt: validated.jkt,
            public_jwk: body.jwk,
            registered_at_secs: now,
        };
        if let Err(err) = self.device_store.register_device(rec).await {
            return self.error_response(&err, None);
        }
        self.json_response(201, &serde_json::json!({"registered": true}), true)
    }

    async fn handle_mint_assertion(&self, req: &OAuthHttpRequest, now: i64) -> OAuthHttpResponse {
        if let Err(err) = self.check_unauth_dpop_rate_limit(req, now).await {
            return self.error_response(&err, None);
        }
        let (aud, device_id) = match Self::parse_assertion_request(&req.headers, &req.body) {
            Ok(parsed) => parsed,
            Err(err) => return self.error_response(&err, None),
        };

        if let Err(err) = self.check_audience(&aud) {
            return self.error_response(&err, None);
        }

        let expected_jkt = if self.config.require_registered_device || device_id.is_some() {
            let Some(ref id) = device_id else {
                return self.error_response(
                    &CabRequestError::access_denied("device_id is required"),
                    None,
                );
            };
            match self.device_store.lookup_device(id).await {
                Ok(Some(d)) => Some(d.dpop_jkt),
                Ok(None) => {
                    return self.error_response(
                        &CabRequestError::access_denied("device is not registered"),
                        None,
                    );
                }
                Err(err) => return self.error_response(&err, None),
            }
        } else {
            None
        };

        let target_url = format!("{}{}", self.config.public_base_url, req.path);
        let ctx = DpopValidationContext {
            method: "POST",
            url: &target_url,
            expected_access_token: None,
            expected_jkt: expected_jkt.as_deref(),
            require_nonce: self.config.require_dpop_nonce,
        };
        let validated = match self
            .dpop_validator
            .validate_headers(&req.headers, ctx, self.replay_checker.as_ref())
            .await
        {
            Ok(v) => v,
            Err(OAuthDpopError::UseDpopNonce { next_nonce }) => {
                return self.error_response(&CabRequestError::use_dpop_nonce(), Some(next_nonce));
            }
            Err(OAuthDpopError::InvalidDpopProof(msg)) => {
                return self.error_response(&CabRequestError::invalid_dpop_proof(msg), None);
            }
        };
        if req.remote_address.is_none()
            && let Err(err) = self
                .rate_limiter
                .check(&format!("jkt:{}", validated.jkt), now)
                .await
        {
            return self.error_response(&err, None);
        }

        if self
            .config
            .denied_jkts
            .iter()
            .any(|denied| ConstantTime::equal(denied, &validated.jkt))
        {
            return self.error_response(
                &CabRequestError::access_denied("device key is denied"),
                None,
            );
        }

        match self
            .minter
            .mint(&aud, Some(&validated.jkt), now, self.random.as_ref())
        {
            Ok(assertion) => {
                let resp = MintAssertionResponse {
                    client_id: self.config.client_id.clone(),
                    client_assertion: assertion,
                    client_assertion_type: "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
                    expires_in: self.config.assertion_lifetime_secs,
                };
                self.json_response(200, &resp, true)
            }
            Err(err) => self.error_response(&err, None),
        }
    }

    fn parse_assertion_request(
        headers: &OAuthHttpHeaders,
        body: &[u8],
    ) -> Result<(String, Option<String>), CabRequestError> {
        if crate::http::OAuthForm::is_form_content_type(headers) {
            let form = crate::http::OAuthForm::parse(body, 16 * 1024)
                .map_err(|_| CabRequestError::invalid_request("malformed form body"))?;
            let Some(aud) = form.get("aud").filter(|s| !s.is_empty()).cloned() else {
                return Err(CabRequestError::invalid_request("aud is required"));
            };
            return Ok((
                aud,
                form.get("device_id").filter(|s| !s.is_empty()).cloned(),
            ));
        }
        let parsed: MintAssertionJsonRequest = serde_json::from_slice(body).map_err(|err| {
            CabRequestError::invalid_request(format!("invalid request body: {err}"))
        })?;
        if parsed.aud.is_empty() {
            return Err(CabRequestError::invalid_request("aud is required"));
        }
        Ok((parsed.aud, parsed.device_id))
    }

    fn check_audience(&self, aud: &str) -> Result<(), CabRequestError> {
        let Ok(url) = Url::parse(aud) else {
            return Err(CabRequestError::invalid_request("aud must be a valid URL"));
        };
        let Some(host) = url.host_str() else {
            return Err(CabRequestError::invalid_request("aud missing host"));
        };
        let is_loopback = matches!(host, "127.0.0.1" | "localhost" | "[::1]" | "::1");
        if !(url.scheme() == "https" || (url.scheme() == "http" && is_loopback)) {
            return Err(CabRequestError::invalid_request("aud must be an https URL"));
        }
        if !self
            .config
            .allowed_audiences
            .iter()
            .any(|a| ConstantTime::equal(a, aud))
        {
            return Err(CabRequestError::invalid_request(
                "aud is not in allowed_audiences",
            ));
        }
        Ok(())
    }

    fn origin_is_allowed(&self, origin: &str) -> bool {
        self.config
            .allowed_origins
            .iter()
            .any(|allowed| allowed == "*" || ConstantTime::equal(allowed, origin))
    }

    fn check_origin(&self, headers: &OAuthHttpHeaders) -> Result<(), CabRequestError> {
        let Some(origin) = headers.get("Origin") else {
            return Ok(());
        };
        if self.origin_is_allowed(origin) {
            Ok(())
        } else {
            Err(CabRequestError::access_denied("origin is not allowed"))
        }
    }

    fn json_response<T: Serialize>(
        &self,
        status: u16,
        body: &T,
        include_nonce: bool,
    ) -> OAuthHttpResponse {
        let mut headers = OAuthHttpHeaders::default();
        headers.set("Content-Type", "application/json");
        headers.set("Cache-Control", "no-store");
        if include_nonce {
            headers.set(
                "DPoP-Nonce",
                self.nonce_service.current_nonce(self.clock.now_secs()),
            );
        }
        let bytes = serde_json::to_vec(body).unwrap_or_else(|_| b"{}".to_vec());
        OAuthHttpResponse::new(status, headers, bytes)
    }

    fn error_response(&self, err: &CabRequestError, nonce: Option<String>) -> OAuthHttpResponse {
        let mut headers = OAuthHttpHeaders::default();
        headers.set("Content-Type", "application/json");
        headers.set("Cache-Control", "no-store");
        headers.set(
            "DPoP-Nonce",
            nonce.unwrap_or_else(|| self.nonce_service.current_nonce(self.clock.now_secs())),
        );
        let bytes = serde_json::to_vec(&serde_json::json!({
            "error": err.error,
            "error_description": err.description,
        }))
        .unwrap_or_else(|_| b"{}".to_vec());
        OAuthHttpResponse::new(err.status, headers, bytes)
    }
}
