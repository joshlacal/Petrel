//! App-password (`com.atproto.server.*Session`) authentication strategy.

use std::{
    collections::{HashMap, HashSet},
    fmt,
    sync::{
        Arc, Weak,
        atomic::{AtomicU64, AtomicUsize, Ordering},
    },
    time::Duration,
};

use async_lock::{Mutex, RwLock};
use base64::{
    Engine,
    engine::general_purpose::{STANDARD as BASE64_STANDARD, URL_SAFE_NO_PAD},
};
use bytes::Bytes;
#[cfg(not(target_arch = "wasm32"))]
use futures_util::future::BoxFuture as FuturesBoxFuture;
use futures_util::future::{FutureExt, Shared};
use http::{
    Method, Request, Response, StatusCode,
    header::{ACCEPT, AUTHORIZATION, CONTENT_TYPE},
};
use petrel_api::generated::com::atproto::server::{
    create_session, delete_session, refresh_session,
};
use petrel_core::{AtIdentifier, Did, Handle, xrpc::XrpcErrorBody};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use url::Url;
use web_time::{Instant, SystemTime, UNIX_EPOCH};
use zeroize::Zeroize;

use super::{
    AccountStatus, AccountStatusError, AuthFactorTokenRequiredError, RefreshCircuitBreaker,
    RefreshFailureKind,
};
use crate::{
    account::{AccountError, AccountManager},
    net::{RedirectPolicy, SendOptions, SharedTransport, TransportError, send_with_redirects},
    oauth::{Account, OAuthIdentityResolver},
    rt::BoxFuture,
    storage::StoreError,
    xrpc::{AuthCtx, AuthError, AuthProvider, UnauthorizedAction},
};

/// Default assumed lifetime (1 hour) when an access JWT lacks parseable `exp`/`iat` claims.
pub const ASSUMED_ACCESS_TOKEN_LIFETIME_SECS: u64 = 3_600;

const LEGACY_SESSION_KEY_PREFIX: &str = "legacySession.";
const MIN_REFRESH_INTERVAL: Duration = Duration::from_millis(500);
const MIN_REFRESH_INTERVAL_AFTER_SUCCESS: Duration = Duration::from_secs(30);

/// Result of checking or executing a token refresh.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TokenRefreshResult {
    /// Tokens were exchanged and updated in storage.
    RefreshedSuccessfully,
    /// Existing access token is still fresh; no network call was issued.
    StillValid,
    /// Skipped due to local minimum-interval throttling.
    SkippedDueToRateLimit,
}

/// Result returned by [`LegacyPasswordStrategy::login_with_password`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PasswordLoginResult {
    /// Authenticated DID.
    pub did: Did,
    /// Resolved handle if present.
    pub handle: Option<Handle>,
    /// Canonical PDS origin URL (`Url`).
    pub pds_url: Url,
    /// Initial account hosting status returned by `createSession`.
    pub status: AccountStatus,
}

/// Errors returned by [`LegacyPasswordStrategy`].
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum PasswordAuthError {
    /// No account is currently active.
    #[error("no active account")]
    NoActiveAccount,
    /// Username/identifier or app password rejected (HTTP 401).
    #[error("invalid credentials")]
    InvalidCredentials,
    /// Handle or DID could not be parsed.
    #[error("invalid identifier: {0}")]
    InvalidIdentifier(String),
    /// Identity or PDS endpoint could not be resolved.
    #[error("could not resolve identity for {0}")]
    IdentityResolutionFailed(String),
    /// Server rejected request due to account hosting status.
    #[error(transparent)]
    AccountStatus(#[from] AccountStatusError),
    /// Server emailed an auth-factor code required to finish sign-in.
    #[error(transparent)]
    AuthFactorTokenRequired(#[from] AuthFactorTokenRequiredError),
    /// Rate limited by the PDS (HTTP 429).
    #[error("rate limited")]
    RateLimited,
    /// Token refresh failed (circuit breaker open or server failure).
    #[error("token refresh failed: {0}")]
    TokenRefreshFailed(String),
    /// Server returned a malformed or mismatched response.
    #[error("invalid authentication response: {0}")]
    InvalidResponse(String),
    /// Server returned an unexpected HTTP error status.
    #[error("server returned HTTP {status}: {message}")]
    ServerError {
        /// HTTP status code.
        status: u16,
        /// Diagnostic message.
        message: String,
    },
    /// Transport failure.
    #[error(transparent)]
    Transport(#[from] TransportError),
    /// Storage error.
    #[error(transparent)]
    Store(#[from] StoreError),
    /// Account catalog error.
    #[error(transparent)]
    Account(#[from] AccountError),
}

impl From<PasswordAuthError> for AuthError {
    fn from(error: PasswordAuthError) -> Self {
        match error {
            PasswordAuthError::NoActiveAccount => Self::NoSession,
            PasswordAuthError::InvalidCredentials => {
                Self::SessionExpired("invalid credentials".to_owned())
            }
            PasswordAuthError::AccountStatus(status) => Self::AccountStatus(status),
            PasswordAuthError::Transport(err) => Self::Transport(err),
            PasswordAuthError::Store(err) => Self::Store(err),
            PasswordAuthError::TokenRefreshFailed(msg)
            | PasswordAuthError::InvalidResponse(msg)
            | PasswordAuthError::ServerError { message: msg, .. } => Self::RefreshFailed(msg),
            other => Self::Other(other.to_string()),
        }
    }
}

/// Bearer token pair stored for an app-password session.
#[derive(Clone, Deserialize, Serialize)]
pub struct LegacySession {
    /// Account DID owning this session.
    pub did: Did,
    access_jwt: String,
    refresh_jwt: String,
    /// Unix timestamp in seconds when the session was issued/refreshed.
    pub created_at: u64,
    /// Access token lifetime in seconds.
    pub expires_in: u64,
}

impl fmt::Debug for LegacySession {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("LegacySession")
            .field("did", &self.did)
            .field("created_at", &self.created_at)
            .field("expires_in", &self.expires_in)
            .finish_non_exhaustive()
    }
}

impl Drop for LegacySession {
    fn drop(&mut self) {
        self.access_jwt.zeroize();
        self.refresh_jwt.zeroize();
    }
}

impl LegacySession {
    /// Returns the Bearer access JWT.
    #[must_use]
    pub fn access_jwt(&self) -> &str {
        &self.access_jwt
    }

    /// Returns the Bearer refresh JWT.
    #[must_use]
    pub fn refresh_jwt(&self) -> &str {
        &self.refresh_jwt
    }

    /// Computes a non-secret generation fingerprint over tokens and timestamps.
    #[must_use]
    pub fn generation(&self) -> [u8; 32] {
        let mut hash = Sha256::new();
        for part in [
            self.did.as_str(),
            self.access_jwt.as_str(),
            self.refresh_jwt.as_str(),
        ] {
            hash.update(u64::try_from(part.len()).unwrap_or(u64::MAX).to_be_bytes());
            hash.update(part.as_bytes());
        }
        hash.update(self.created_at.to_be_bytes());
        hash.update(self.expires_in.to_be_bytes());
        hash.finalize().into()
    }

    /// Returns `true` when the access token is within its refresh margin or already expired.
    #[must_use]
    pub fn is_expiring_soon(&self, now_unix_secs: u64) -> bool {
        let expiry = self.created_at.saturating_add(self.expires_in);
        let margin = (self.expires_in / 5).min(60);
        now_unix_secs >= expiry.saturating_sub(margin)
    }
}

#[cfg(not(target_arch = "wasm32"))]
type SharedRefreshFuture =
    Shared<FuturesBoxFuture<'static, Result<TokenRefreshResult, PasswordAuthError>>>;
#[cfg(target_arch = "wasm32")]
type SharedRefreshFuture = Shared<
    std::pin::Pin<
        Box<dyn std::future::Future<Output = Result<TokenRefreshResult, PasswordAuthError>>>,
    >,
>;

struct ActiveRefreshEntry {
    generation: u64,
    active_waiters: Arc<AtomicUsize>,
    future: SharedRefreshFuture,
}

/// App-password authentication strategy (`com.atproto.server.*Session`).
///
/// Used by CLI/daemon clients (`catmos-cli`, `BIRDaemon`) and tests requiring
/// username/email/DID + app-password sign-in, 2FA email factor challenges,
/// hosting-status classification, and `Bearer` refresh/revocation.
pub struct LegacyPasswordStrategy {
    account_manager: Arc<AccountManager>,
    transport: SharedTransport,
    identity: Arc<dyn OAuthIdentityResolver>,
    fallback_service: RwLock<Url>,
    allow_loopback: bool,
    circuit_breaker: RefreshCircuitBreaker,
    last_refresh_attempt: Mutex<HashMap<Did, Instant>>,
    last_successful_refresh: Mutex<HashMap<Did, Instant>>,
    /// Refresh tokens with an exchange in flight or definitively consumed. A
    /// synchronous lock so a cancelled exchange can always release its token
    /// from `Drop`; it is never held across an await.
    used_refresh_tokens: std::sync::Mutex<HashSet<[u8; 32]>>,
    next_refresh_generation: AtomicU64,
    active_refreshes: Mutex<HashMap<Did, ActiveRefreshEntry>>,
    account_statuses: Mutex<HashMap<Did, AccountStatus>>,
    lifecycle_lock: Mutex<()>,
}

impl fmt::Debug for LegacyPasswordStrategy {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("LegacyPasswordStrategy")
            .field("allow_loopback", &self.allow_loopback)
            .finish_non_exhaustive()
    }
}

impl LegacyPasswordStrategy {
    /// Creates a [`LegacyPasswordStrategy`].
    #[must_use]
    pub fn new(
        account_manager: Arc<AccountManager>,
        transport: SharedTransport,
        identity: Arc<dyn OAuthIdentityResolver>,
        fallback_service: Url,
    ) -> Self {
        Self {
            account_manager,
            transport,
            identity,
            fallback_service: RwLock::new(fallback_service),
            allow_loopback: false,
            circuit_breaker: RefreshCircuitBreaker::new(),
            last_refresh_attempt: Mutex::new(HashMap::new()),
            last_successful_refresh: Mutex::new(HashMap::new()),
            used_refresh_tokens: std::sync::Mutex::new(HashSet::new()),
            next_refresh_generation: AtomicU64::new(1),
            active_refreshes: Mutex::new(HashMap::new()),
            account_statuses: Mutex::new(HashMap::new()),
            lifecycle_lock: Mutex::new(()),
        }
    }

    fn used_refresh_tokens(&self) -> std::sync::MutexGuard<'_, HashSet<[u8; 32]>> {
        self.used_refresh_tokens
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
    }

    /// Permits loopback HTTP/HTTPS endpoints (for local tests and development servers).
    #[must_use]
    pub const fn with_loopback_development(mut self, allow: bool) -> Self {
        self.allow_loopback = allow;
        self
    }

    /// Updates the fallback service URL used for email-based logins.
    pub async fn set_fallback_service(&self, url: Url) {
        *self.fallback_service.write().await = url;
    }

    /// Returns the last [`AccountStatus`] observed for `did` from sign-in, refresh, or errors.
    pub async fn last_known_account_status(&self, did: &Did) -> Option<AccountStatus> {
        self.account_statuses.lock().await.get(did).cloned()
    }

    /// Reads the stored [`LegacySession`] for `did`, if any.
    pub async fn get_session(&self, did: &Did) -> Result<Option<LegacySession>, StoreError> {
        let key = legacy_session_key(did);
        let store = self.account_manager.storage();
        let Some(bytes) = store.secrets().get(store.namespace(), &key).await? else {
            return Ok(None);
        };
        let session =
            serde_json::from_slice(&bytes).map_err(|e| StoreError::Corrupt(e.to_string()))?;
        Ok(Some(session))
    }

    async fn save_session(&self, session: &LegacySession) -> Result<(), StoreError> {
        let key = legacy_session_key(&session.did);
        let store = self.account_manager.storage();
        let bytes = serde_json::to_vec(session).map_err(|e| StoreError::Corrupt(e.to_string()))?;
        store.secrets().put(store.namespace(), &key, &bytes).await
    }

    async fn delete_stored_session(&self, did: &Did) -> Result<(), StoreError> {
        let key = legacy_session_key(did);
        let store = self.account_manager.storage();
        store.secrets().delete(store.namespace(), &key).await
    }

    /// Signs in using a handle, DID, or email address and an app password (plus optional 2FA code).
    pub async fn login_with_password(
        self: &Arc<Self>,
        identifier: &str,
        password: &str,
        auth_factor_token: Option<&str>,
    ) -> Result<PasswordLoginResult, PasswordAuthError> {
        let (expected_did, login_server) = self.resolve_login_server(identifier).await?;
        let output = self
            .send_create_session(identifier, password, auth_factor_token, &login_server)
            .await?;

        if let Some(ref expected) = expected_did
            && output.did != *expected
        {
            let _ = self
                .delete_server_session(&output.refresh_jwt, &login_server)
                .await;
            return Err(PasswordAuthError::InvalidResponse(
                "createSession returned a different DID than requested".to_owned(),
            ));
        }

        let pds_url = if expected_did.is_none() {
            let resolved = self
                .identity
                .resolve_identity(&AtIdentifier::Did(output.did.clone()), false)
                .await
                .map_err(|_| {
                    PasswordAuthError::IdentityResolutionFailed(output.did.as_str().to_owned())
                })?;
            resolved.pds
        } else {
            login_server
        };

        self.persist_login_session(output, pds_url).await
    }

    async fn resolve_login_server(
        &self,
        identifier: &str,
    ) -> Result<(Option<Did>, Url), PasswordAuthError> {
        if identifier.starts_with("did:") {
            let did: Did = identifier
                .parse()
                .map_err(|_| PasswordAuthError::InvalidIdentifier(identifier.to_owned()))?;
            let resolved = self
                .identity
                .resolve_identity(&AtIdentifier::Did(did.clone()), false)
                .await
                .map_err(|_| PasswordAuthError::IdentityResolutionFailed(identifier.to_owned()))?;
            return Ok((Some(did), resolved.pds));
        }
        if identifier.contains('@') {
            return Ok((None, self.fallback_service.read().await.clone()));
        }
        let handle: Handle = identifier
            .parse()
            .map_err(|_| PasswordAuthError::InvalidIdentifier(identifier.to_owned()))?;
        let resolved = self
            .identity
            .resolve_identity(&AtIdentifier::Handle(handle), false)
            .await
            .map_err(|_| PasswordAuthError::IdentityResolutionFailed(identifier.to_owned()))?;
        Ok((Some(resolved.did), resolved.pds))
    }

    async fn send_create_session(
        &self,
        identifier: &str,
        password: &str,
        auth_factor_token: Option<&str>,
        login_server: &Url,
    ) -> Result<create_session::Output, PasswordAuthError> {
        let mut url = login_server.clone();
        url.path_segments_mut()
            .map_err(|()| PasswordAuthError::InvalidResponse("invalid PDS URL".to_owned()))?
            .pop_if_empty()
            .extend(["xrpc", create_session::NSID]);

        let input = create_session::Input {
            identifier: identifier.to_owned(),
            password: password.to_owned(),
            auth_factor_token: auth_factor_token.map(str::to_owned),
            allow_takendown: Some(true),
        };
        let body = petrel_core::to_json(&input)
            .map_err(|e| PasswordAuthError::InvalidResponse(e.to_string()))?;

        let request = Request::builder()
            .method(Method::POST)
            .uri(url.as_str())
            .header(CONTENT_TYPE, "application/json")
            .header(ACCEPT, "application/json")
            .body(Bytes::from(body))
            .map_err(|e| TransportError::InvalidRequest(e.to_string()))?;

        let send_opts = SendOptions {
            allow_loopback: self.allow_loopback,
            anonymous: true,
            ..SendOptions::new()
        };
        let response = send_with_redirects(
            self.transport.as_ref(),
            request,
            &send_opts,
            RedirectPolicy::Never,
        )
        .await?;

        if response.status() != StatusCode::OK {
            return Err(Self::session_error(
                response.status().as_u16(),
                response.body(),
            ));
        }

        petrel_core::from_json(response.body())
            .map_err(|e| PasswordAuthError::InvalidResponse(e.to_string()))
    }

    async fn persist_login_session(
        &self,
        output: create_session::Output,
        pds_url: Url,
    ) -> Result<PasswordLoginResult, PasswordAuthError> {
        let status = AccountStatus::from_api(output.active, output.status.as_deref());
        self.account_statuses
            .lock()
            .await
            .insert(output.did.clone(), status.clone());

        let now = unix_now();
        let expires_in = Self::jwt_lifetime(&output.access_jwt);
        let session = LegacySession {
            did: output.did.clone(),
            access_jwt: output.access_jwt,
            refresh_jwt: output.refresh_jwt,
            created_at: now,
            expires_in,
        };

        let pds_origin = canonical_origin_string(&pds_url);
        let mut account = self
            .account_manager
            .get_account(&output.did)
            .await?
            .unwrap_or_else(|| Account {
                did: output.did.clone(),
                handle: Some(output.handle.clone()),
                pds: pds_origin.clone(),
                authorization_server: None,
                expected_issuer: None,
            });
        account.handle = Some(output.handle.clone());
        account.pds = pds_origin;
        account.authorization_server = None;
        account.expected_issuer = None;

        let lifecycle = self.lifecycle_lock.lock().await;
        self.save_session(&session).await?;
        self.account_manager.add_account(&account).await?;
        self.account_manager
            .set_current_account(&output.did)
            .await?;
        self.circuit_breaker.reset(&output.did).await;
        drop(lifecycle);

        Ok(PasswordLoginResult {
            did: output.did,
            handle: Some(output.handle),
            pds_url,
            status,
        })
    }

    /// Maps an unsuccessful `createSession` / `refreshSession` HTTP response into [`PasswordAuthError`].
    #[must_use]
    pub fn session_error(status: u16, body: &[u8]) -> PasswordAuthError {
        let parsed = XrpcErrorBody::parse(body);
        if let Some(ref err) = parsed {
            if let Some(status_err) =
                AccountStatusError::from_xrpc_error(&err.error, err.message.as_deref())
            {
                return PasswordAuthError::AccountStatus(status_err);
            }
            if err.error == "AuthFactorTokenRequired" {
                return PasswordAuthError::AuthFactorTokenRequired(AuthFactorTokenRequiredError);
            }
        }
        match status {
            401 => PasswordAuthError::InvalidCredentials,
            429 => PasswordAuthError::RateLimited,
            _ => {
                let message = parsed.map_or_else(String::new, |err| match err.message {
                    Some(msg) if !msg.is_empty() => format!("{}: {msg}", err.error),
                    _ => err.error,
                });
                PasswordAuthError::ServerError { status, message }
            }
        }
    }

    /// Computes JWT lifetime (`exp - iat`) in seconds, falling back to [`ASSUMED_ACCESS_TOKEN_LIFETIME_SECS`].
    #[must_use]
    pub fn jwt_lifetime(jwt: &str) -> u64 {
        let mut parts = jwt.split('.');
        let _header = parts.next();
        let Some(payload) = parts.next() else {
            return ASSUMED_ACCESS_TOKEN_LIFETIME_SECS;
        };
        let mut padded = payload.replace('-', "+").replace('_', "/");
        while !padded.len().is_multiple_of(4) {
            padded.push('=');
        }
        let Ok(decoded) = BASE64_STANDARD
            .decode(&padded)
            .or_else(|_| URL_SAFE_NO_PAD.decode(payload))
        else {
            return ASSUMED_ACCESS_TOKEN_LIFETIME_SECS;
        };
        let Ok(value) = serde_json::from_slice::<serde_json::Value>(&decoded) else {
            return ASSUMED_ACCESS_TOKEN_LIFETIME_SECS;
        };
        let exp = value.get("exp").and_then(serde_json::Value::as_f64);
        let iat = value.get("iat").and_then(serde_json::Value::as_f64);
        match (exp, iat) {
            (Some(exp), Some(iat)) if exp > iat && exp.is_finite() && iat.is_finite() => {
                let diff = (exp - iat).round();
                #[allow(
                    clippy::cast_possible_truncation,
                    clippy::cast_sign_loss,
                    clippy::cast_precision_loss
                )]
                if diff >= 1.0 && diff <= (1_u64 << 52) as f64 {
                    diff as u64
                } else {
                    ASSUMED_ACCESS_TOKEN_LIFETIME_SECS
                }
            }
            _ => ASSUMED_ACCESS_TOKEN_LIFETIME_SECS,
        }
    }

    /// Logs out the current account, calling `deleteSession` before clearing local tokens.
    pub async fn logout(&self) -> Result<(), PasswordAuthError> {
        let _ = self.logout_preserving_switch().await?;
        Ok(())
    }

    pub(crate) async fn logout_preserving_switch(&self) -> Result<bool, PasswordAuthError> {
        let _lifecycle = self.lifecycle_lock.lock().await;
        let Some(did) = self.account_manager.current_did().await? else {
            return Ok(true);
        };
        let _ = self.revoke_session(&did).await;
        self.delete_stored_session(&did).await?;
        self.account_statuses.lock().await.remove(&did);
        Ok(self
            .account_manager
            .clear_current_account_if_selected(&did)
            .await?)
    }

    /// Ends `did`'s remote session via `com.atproto.server.deleteSession`, leaving local storage untouched.
    pub async fn revoke_session(&self, did: &Did) -> bool {
        let Ok(Some(session)) = self.get_session(did).await else {
            return false;
        };
        let Ok(Some(account)) = self.account_manager.get_account(did).await else {
            return false;
        };
        let Ok(pds_url) = Url::parse(&account.pds) else {
            return false;
        };
        self.delete_server_session(session.refresh_jwt(), &pds_url)
            .await
    }

    async fn delete_server_session(&self, refresh_jwt: &str, pds_url: &Url) -> bool {
        let mut url = pds_url.clone();
        let Ok(mut segments) = url.path_segments_mut() else {
            return false;
        };
        segments
            .pop_if_empty()
            .extend(["xrpc", delete_session::NSID]);
        drop(segments);

        let Ok(request) = Request::builder()
            .method(Method::POST)
            .uri(url.as_str())
            .header(AUTHORIZATION, format!("Bearer {refresh_jwt}"))
            .body(Bytes::new())
        else {
            return false;
        };

        let send_opts = SendOptions {
            allow_loopback: self.allow_loopback,
            anonymous: false,
            ..SendOptions::new()
        };
        match send_with_redirects(
            self.transport.as_ref(),
            request,
            &send_opts,
            RedirectPolicy::Never,
        )
        .await
        {
            Ok(resp) => resp.status() == StatusCode::OK,
            Err(_) => false,
        }
    }

    /// Refreshes the active account's tokens if due (or when `force_refresh` is true),
    /// using single-flight deduplication and refresh-token replay protection.
    pub async fn refresh_token_if_needed(
        self: &Arc<Self>,
        force_refresh: bool,
    ) -> Result<TokenRefreshResult, PasswordAuthError> {
        let Some(account) = self.account_manager.get_current_account().await? else {
            return Err(PasswordAuthError::NoActiveAccount);
        };
        self.refresh_token_for_did(&account.did, force_refresh)
            .await
    }

    /// Refreshes `did`'s tokens if due (or when `force_refresh` is true),
    /// using single-flight deduplication and refresh-token replay protection.
    pub async fn refresh_token_for_did(
        self: &Arc<Self>,
        did: &Did,
        force_refresh: bool,
    ) -> Result<TokenRefreshResult, PasswordAuthError> {
        let did = did.clone();
        let Some(session) = self.get_session(&did).await? else {
            return Err(PasswordAuthError::NoActiveAccount);
        };

        if let Some((existing, mut waiter)) = self.try_join_active_refresh(&did).await {
            let res = existing.await;
            waiter.mark_finished();
            return res;
        }

        let token_hash = sha256_bytes(session.refresh_jwt().as_bytes());
        if !force_refresh
            && let Some(last_success) = self.last_successful_refresh.lock().await.get(&did).copied()
            && last_success.elapsed() < MIN_REFRESH_INTERVAL_AFTER_SUCCESS
        {
            return Ok(TokenRefreshResult::StillValid);
        }

        if !force_refresh && !session.is_expiring_soon(unix_now()) {
            return Ok(TokenRefreshResult::StillValid);
        }

        if let Some(last_attempt) = self.last_refresh_attempt.lock().await.get(&did).copied()
            && last_attempt.elapsed() < MIN_REFRESH_INTERVAL
        {
            if !force_refresh {
                return Ok(TokenRefreshResult::SkippedDueToRateLimit);
            }
            let wait = MIN_REFRESH_INTERVAL.saturating_sub(last_attempt.elapsed());
            #[cfg(any(
                all(not(target_arch = "wasm32"), feature = "native"),
                all(target_arch = "wasm32", feature = "wasm")
            ))]
            crate::rt::sleep(wait).await;
            #[cfg(not(any(
                all(not(target_arch = "wasm32"), feature = "native"),
                all(target_arch = "wasm32", feature = "wasm")
            )))]
            super::background::thread_delay(wait).await;
        }

        let (shared, mut waiter) = self.spawn_or_join_refresh(did, token_hash).await?;
        let res = shared.await;
        waiter.mark_finished();
        res
    }

    async fn spawn_or_join_refresh(
        self: &Arc<Self>,
        did: Did,
        token_hash: [u8; 32],
    ) -> Result<(SharedRefreshFuture, RefreshWaiterGuard), PasswordAuthError> {
        let mut refreshes = self.active_refreshes.lock().await;
        refreshes.retain(|_, entry| entry.active_waiters.load(Ordering::Acquire) > 0);
        if let Some(existing) = refreshes.get(&did)
            && try_increment_waiter(&existing.active_waiters)
        {
            let shared = existing.future.clone();
            let waiter = RefreshWaiterGuard {
                strategy: Arc::downgrade(self),
                did,
                generation: existing.generation,
                active_waiters: Arc::clone(&existing.active_waiters),
                finished: false,
            };
            return Ok((shared, waiter));
        }

        refreshes.remove(&did);
        let Some(acquired_probe) = self.circuit_breaker.try_acquire_refresh_slot(&did).await else {
            return Err(PasswordAuthError::TokenRefreshFailed(
                "refresh circuit breaker is open".to_owned(),
            ));
        };
        let mut probe_guard = HalfOpenProbeGuard {
            breaker: &self.circuit_breaker,
            did: &did,
            probe_id: acquired_probe,
        };
        let replayed = {
            let mut used = self.used_refresh_tokens();
            if used.contains(&token_hash) {
                used.remove(&token_hash);
                true
            } else {
                used.insert(token_hash);
                false
            }
        };
        if replayed {
            if let Some(id) = probe_guard.take() {
                self.circuit_breaker.release_half_open_probe(&did, id).await;
            }
            return Err(PasswordAuthError::TokenRefreshFailed(
                "refresh token replay prevented".to_owned(),
            ));
        }

        let probe_id = probe_guard.take();
        drop(probe_guard);
        let generation = self.next_refresh_generation.fetch_add(1, Ordering::Relaxed);
        // One waiter for this caller and one for the background runner below,
        // so the entry stays joinable while the exchange runs even if every
        // caller has gone.
        let active_waiters = Arc::new(AtomicUsize::new(2));
        let weak_this = Arc::downgrade(self);
        let did_for_task = did.clone();
        let fut = async move {
            let mut cleanup = RefreshCleanupGuard {
                strategy: Weak::clone(&weak_this),
                did: did_for_task.clone(),
                generation,
                token_hash,
                probe_id,
                finished: false,
            };
            let Some(this) = weak_this.upgrade() else {
                return Err(PasswordAuthError::NoActiveAccount);
            };
            let mut consumed = false;
            let res = this.perform_refresh(&did_for_task, &mut consumed).await;
            drop(this);
            // The PDS used the token if it answered with success (even one
            // we could not apply) or rejected it as expired or invalid.
            // Anything else leaves it usable for the next attempt.
            let keep_token_burned = consumed
                || res.is_ok()
                || matches!(res, Err(PasswordAuthError::InvalidCredentials));
            cleanup.finish_async(keep_token_burned).await;
            res
        };
        #[cfg(not(target_arch = "wasm32"))]
        let boxed: FuturesBoxFuture<
            'static,
            Result<TokenRefreshResult, PasswordAuthError>,
        > = Box::pin(fut);
        #[cfg(target_arch = "wasm32")]
        let boxed: std::pin::Pin<
            Box<dyn std::future::Future<Output = Result<TokenRefreshResult, PasswordAuthError>>>,
        > = Box::pin(fut);

        let shared = boxed.shared();
        run_in_background(&shared, &active_waiters);
        let waiter = RefreshWaiterGuard {
            strategy: Arc::downgrade(self),
            did: did.clone(),
            generation,
            active_waiters: Arc::clone(&active_waiters),
            finished: false,
        };
        refreshes.insert(
            did,
            ActiveRefreshEntry {
                generation,
                active_waiters,
                future: shared.clone(),
            },
        );
        Ok((shared, waiter))
    }

    async fn try_join_active_refresh(
        self: &Arc<Self>,
        did: &Did,
    ) -> Option<(SharedRefreshFuture, RefreshWaiterGuard)> {
        let mut refreshes = self.active_refreshes.lock().await;
        refreshes.retain(|_, entry| entry.active_waiters.load(Ordering::Acquire) > 0);
        let existing = refreshes.get(did)?;
        if !try_increment_waiter(&existing.active_waiters) {
            refreshes.remove(did);
            return None;
        }
        Some((
            existing.future.clone(),
            RefreshWaiterGuard {
                strategy: Arc::downgrade(self),
                did: did.clone(),
                generation: existing.generation,
                active_waiters: Arc::clone(&existing.active_waiters),
                finished: false,
            },
        ))
    }

    async fn perform_refresh(
        &self,
        did: &Did,
        consumed: &mut bool,
    ) -> Result<TokenRefreshResult, PasswordAuthError> {
        let Some(session) = self.get_session(did).await? else {
            return Err(PasswordAuthError::TokenRefreshFailed(
                "missing session".to_owned(),
            ));
        };
        let initial_gen = session.generation();
        let Some(account) = self.account_manager.get_account(did).await? else {
            return Err(PasswordAuthError::TokenRefreshFailed(
                "missing account".to_owned(),
            ));
        };
        let response = self
            .send_refresh_request(did, &account.pds, &session)
            .await?;
        *consumed = response.status().is_success();
        let refreshed = self.handle_refresh_response(did, &response).await?;

        let _lifecycle = self.lifecycle_lock.lock().await;
        let Some(current_session) = self.get_session(did).await? else {
            return Err(PasswordAuthError::TokenRefreshFailed(
                "session was removed during refresh".to_owned(),
            ));
        };
        if current_session.generation() != initial_gen {
            return Err(PasswordAuthError::TokenRefreshFailed(
                "session was replaced during refresh".to_owned(),
            ));
        }
        let Some(mut updated_account) = self.account_manager.get_account(did).await? else {
            return Err(PasswordAuthError::TokenRefreshFailed(
                "account was removed during refresh".to_owned(),
            ));
        };

        let hosting_status = AccountStatus::from_api(refreshed.active, refreshed.status.as_deref());
        self.account_statuses
            .lock()
            .await
            .insert(did.clone(), hosting_status);

        let expires_in = Self::jwt_lifetime(&refreshed.access_jwt);
        let new_session = LegacySession {
            did: did.clone(),
            access_jwt: refreshed.access_jwt,
            refresh_jwt: refreshed.refresh_jwt,
            created_at: unix_now(),
            expires_in,
        };
        updated_account.handle = Some(refreshed.handle);

        self.save_session(&new_session).await?;
        if !self
            .account_manager
            .update_account(&updated_account)
            .await?
        {
            return Err(PasswordAuthError::TokenRefreshFailed(
                "account was removed during refresh".to_owned(),
            ));
        }
        self.last_successful_refresh
            .lock()
            .await
            .insert(did.clone(), Instant::now());
        self.circuit_breaker.record_success(did).await;
        Ok(TokenRefreshResult::RefreshedSuccessfully)
    }

    async fn send_refresh_request(
        &self,
        did: &Did,
        pds: &str,
        session: &LegacySession,
    ) -> Result<Response<Bytes>, PasswordAuthError> {
        let mut url = Url::parse(pds).map_err(|_| {
            PasswordAuthError::TokenRefreshFailed("invalid account PDS URL".to_owned())
        })?;
        url.path_segments_mut()
            .map_err(|()| {
                PasswordAuthError::TokenRefreshFailed("invalid account PDS path".to_owned())
            })?
            .pop_if_empty()
            .extend(["xrpc", refresh_session::NSID]);

        let request = Request::builder()
            .method(Method::POST)
            .uri(url.as_str())
            .header(ACCEPT, "application/json")
            .header(AUTHORIZATION, format!("Bearer {}", session.refresh_jwt()))
            .body(Bytes::new())
            .map_err(|e| TransportError::InvalidRequest(e.to_string()))?;

        self.last_refresh_attempt
            .lock()
            .await
            .insert(did.clone(), Instant::now());

        let send_opts = SendOptions {
            allow_loopback: self.allow_loopback,
            anonymous: false,
            ..SendOptions::new()
        };
        match send_with_redirects(
            self.transport.as_ref(),
            request,
            &send_opts,
            RedirectPolicy::Never,
        )
        .await
        {
            Ok(resp) => Ok(resp),
            Err(err) => {
                self.circuit_breaker
                    .record_failure(did, RefreshFailureKind::Network)
                    .await;
                Err(PasswordAuthError::Transport(err))
            }
        }
    }

    async fn handle_refresh_response(
        &self,
        did: &Did,
        response: &Response<Bytes>,
    ) -> Result<refresh_session::Output, PasswordAuthError> {
        let status_code = response.status().as_u16();
        if !(200..300).contains(&status_code) {
            if (500..600).contains(&status_code) {
                self.circuit_breaker
                    .record_failure(did, RefreshFailureKind::Server)
                    .await;
                return Err(PasswordAuthError::TokenRefreshFailed(format!(
                    "HTTP {status_code}"
                )));
            }
            if status_code == 429 {
                self.circuit_breaker
                    .record_failure(did, RefreshFailureKind::Server)
                    .await;
                return Err(PasswordAuthError::RateLimited);
            }
            if let PasswordAuthError::AccountStatus(status_err) =
                Self::session_error(status_code, response.body())
            {
                self.account_statuses
                    .lock()
                    .await
                    .insert(did.clone(), status_err.status.clone());
                return Err(PasswordAuthError::AccountStatus(status_err));
            }
            let error = Self::refresh_error(status_code, response.body());
            let kind = if error == PasswordAuthError::InvalidCredentials {
                RefreshFailureKind::InvalidGrant
            } else {
                RefreshFailureKind::Server
            };
            self.circuit_breaker.record_failure(did, kind).await;
            return Err(error);
        }

        let refreshed: refresh_session::Output = petrel_core::from_json(response.body())
            .map_err(|e| PasswordAuthError::InvalidResponse(e.to_string()))?;

        if refreshed.did != *did {
            self.circuit_breaker
                .record_failure(did, RefreshFailureKind::InvalidGrant)
                .await;
            return Err(PasswordAuthError::InvalidCredentials);
        }
        Ok(refreshed)
    }

    /// Classifies a non-2xx, non-429, non-5xx `refreshSession` reply. Only a
    /// rejection of the refresh token itself (`ExpiredToken`, `InvalidToken`,
    /// or a 401 asking for authentication) ends the session. Other replies,
    /// such as a proxy's 403/408/413 or an unrelated 400, are reported as
    /// [`PasswordAuthError::ServerError`] and leave the session usable.
    fn refresh_error(status: u16, body: &[u8]) -> PasswordAuthError {
        let parsed = XrpcErrorBody::parse(body);
        let code = parsed.as_ref().map(|err| err.error.as_str());
        let terminal = matches!(code, Some("ExpiredToken" | "InvalidToken"))
            || (status == 401 && code == Some("AuthenticationRequired"));
        if terminal {
            return PasswordAuthError::InvalidCredentials;
        }
        let message = parsed.map_or_else(String::new, |err| match err.message {
            Some(msg) if !msg.is_empty() => format!("{}: {msg}", err.error),
            _ => err.error,
        });
        PasswordAuthError::ServerError { status, message }
    }

    /// Resets the circuit breaker for `did` (or the current account) and attempts a forced refresh.
    pub async fn attempt_recovery_from_server_failures(
        self: &Arc<Self>,
        did: Option<&Did>,
    ) -> Result<(), PasswordAuthError> {
        let target = match did {
            Some(d) => Some(d.clone()),
            None => self.account_manager.current_did().await?,
        };
        let Some(target) = target else {
            return Ok(());
        };
        self.circuit_breaker.reset(&target).await;
        let _ = self.refresh_token_for_did(&target, true).await?;
        Ok(())
    }
}

impl AuthProvider for Arc<LegacyPasswordStrategy> {
    fn prepare(
        &self,
        mut request: Request<Bytes>,
    ) -> BoxFuture<'_, Result<(Request<Bytes>, AuthCtx), AuthError>> {
        Box::pin(async move {
            let uri = Url::parse(&request.uri().to_string())
                .map_err(|_| AuthError::Other("invalid request URI".to_owned()))?;
            let Some(account) = self
                .account_manager
                .get_current_account()
                .await
                .map_err(|err| AuthError::Other(err.to_string()))?
            else {
                return Err(AuthError::NoSession);
            };
            let scheme_allowed = uri.scheme() == "https" || self.allow_loopback;
            if !scheme_allowed || canonical_origin_string(&uri) != account.pds {
                request.headers_mut().remove(AUTHORIZATION);
                return Ok((request, AuthCtx::default()));
            }
            let Some(session) = self.get_session(&account.did).await? else {
                return Err(AuthError::NoSession);
            };
            let mut header =
                http::HeaderValue::from_str(&format!("Bearer {}", session.access_jwt()))
                    .map_err(|_| AuthError::Other("invalid access token header".to_owned()))?;
            header.set_sensitive(true);
            request.headers_mut().insert(AUTHORIZATION, header);
            let ctx = AuthCtx {
                did: Some(account.did),
                jkt: None,
                session_generation: Some(session.generation()),
            };
            Ok((request, ctx))
        })
    }

    fn refresh_if_needed(&self) -> BoxFuture<'_, Result<(), AuthError>> {
        Box::pin(async move {
            self.refresh_token_if_needed(false)
                .await
                .map(|_| ())
                .map_err(AuthError::from)
        })
    }

    fn handle_unauthorized<'a>(
        &'a self,
        response: &'a Response<Bytes>,
        ctx: &'a AuthCtx,
    ) -> BoxFuture<'a, Result<UnauthorizedAction, AuthError>> {
        Box::pin(async move {
            let error_code = serde_json::from_slice::<XrpcErrorBody>(response.body())
                .ok()
                .map(|body| body.error);
            let is_refreshable = response.status() == StatusCode::UNAUTHORIZED
                || (response.status() == StatusCode::BAD_REQUEST
                    && error_code.as_deref() == Some("ExpiredToken"));
            if !is_refreshable {
                return Ok(UnauthorizedAction::GiveUp);
            }
            if let Some(status_err) = AccountStatusError::from_xrpc_body(response.body()) {
                if let Some(ref did) = ctx.did {
                    self.account_statuses
                        .lock()
                        .await
                        .insert(did.clone(), status_err.status.clone());
                }
                return Err(AuthError::AccountStatus(status_err));
            }
            if let (Some(did), Some(sent_gen)) = (ctx.did.as_ref(), ctx.session_generation)
                && let Ok(Some(current)) = self.get_session(did).await
                && current.generation() != sent_gen
            {
                return Ok(UnauthorizedAction::Retry);
            }
            let refresh_result = if let Some(ref did) = ctx.did {
                let current_did = self
                    .account_manager
                    .current_did()
                    .await
                    .map_err(PasswordAuthError::from)
                    .map_err(AuthError::from)?;
                if current_did.as_ref() != Some(did) {
                    return Ok(UnauthorizedAction::GiveUp);
                }
                self.refresh_token_for_did(did, true).await
            } else {
                self.refresh_token_if_needed(true).await
            };
            match refresh_result {
                Ok(TokenRefreshResult::RefreshedSuccessfully) => Ok(UnauthorizedAction::Retry),
                Ok(_) => Ok(UnauthorizedAction::GiveUp),
                Err(err) => Err(AuthError::from(err)),
            }
        })
    }

    fn update_dpop_nonce<'a>(
        &'a self,
        _origin: &'a str,
        _nonce: &'a str,
        _ctx: &'a AuthCtx,
    ) -> BoxFuture<'a, ()> {
        Box::pin(async {})
    }
}

/// Drives a refresh to completion on the platform runtime, counted as one of
/// its waiters until it finishes. Once `refreshSession` may have reached the
/// PDS, losing its answer loses the rotated token, so the exchange must not
/// depend on any caller keeping its future alive.
fn run_in_background(shared: &SharedRefreshFuture, active_waiters: &Arc<AtomicUsize>) {
    let runner_waiters = Arc::clone(active_waiters);
    let runner = shared.clone().map(move |_| {
        runner_waiters.fetch_sub(1, Ordering::AcqRel);
    });
    if !super::background::spawn(runner) {
        active_waiters.fetch_sub(1, Ordering::AcqRel);
    }
}

fn try_increment_waiter(active_waiters: &AtomicUsize) -> bool {
    let mut current = active_waiters.load(Ordering::Acquire);
    while current > 0 {
        match active_waiters.compare_exchange_weak(
            current,
            current + 1,
            Ordering::AcqRel,
            Ordering::Acquire,
        ) {
            Ok(_) => return true,
            Err(observed) => current = observed,
        }
    }
    false
}

struct RefreshWaiterGuard {
    strategy: Weak<LegacyPasswordStrategy>,
    did: Did,
    generation: u64,
    active_waiters: Arc<AtomicUsize>,
    finished: bool,
}

impl RefreshWaiterGuard {
    const fn mark_finished(&mut self) {
        self.finished = true;
    }
}

impl Drop for RefreshWaiterGuard {
    fn drop(&mut self) {
        let prev = self.active_waiters.fetch_sub(1, Ordering::AcqRel);
        if self.finished || prev != 1 {
            return;
        }
        if let Some(strategy) = self.strategy.upgrade()
            && let Some(mut refreshes) = strategy.active_refreshes.try_lock()
            && refreshes
                .get(&self.did)
                .is_some_and(|entry| entry.generation == self.generation)
        {
            refreshes.remove(&self.did);
        }
    }
}

struct HalfOpenProbeGuard<'a> {
    breaker: &'a RefreshCircuitBreaker,
    did: &'a Did,
    probe_id: Option<u64>,
}

impl HalfOpenProbeGuard<'_> {
    const fn take(&mut self) -> Option<u64> {
        self.probe_id.take()
    }
}

impl Drop for HalfOpenProbeGuard<'_> {
    fn drop(&mut self) {
        if let Some(probe_id) = self.probe_id.take() {
            self.breaker.try_release_half_open_probe(self.did, probe_id);
        }
    }
}

struct RefreshCleanupGuard {
    strategy: Weak<LegacyPasswordStrategy>,
    did: Did,
    generation: u64,
    token_hash: [u8; 32],
    probe_id: Option<u64>,
    finished: bool,
}

impl RefreshCleanupGuard {
    async fn finish_async(&mut self, keep_token_burned: bool) {
        self.finished = true;
        if let Some(strategy) = self.strategy.upgrade() {
            if let Some(probe_id) = self.probe_id.take() {
                strategy
                    .circuit_breaker
                    .release_half_open_probe(&self.did, probe_id)
                    .await;
            }
            let mut refreshes = strategy.active_refreshes.lock().await;
            if refreshes
                .get(&self.did)
                .is_some_and(|entry| entry.generation == self.generation)
            {
                refreshes.remove(&self.did);
            }
            drop(refreshes);
            if !keep_token_burned {
                strategy.used_refresh_tokens().remove(&self.token_hash);
            }
        }
    }
}

impl Drop for RefreshCleanupGuard {
    fn drop(&mut self) {
        if self.finished {
            return;
        }
        if let Some(strategy) = self.strategy.upgrade() {
            if let Some(probe_id) = self.probe_id.take() {
                strategy
                    .circuit_breaker
                    .try_release_half_open_probe(&self.did, probe_id);
            }
            if let Some(mut refreshes) = strategy.active_refreshes.try_lock()
                && refreshes
                    .get(&self.did)
                    .is_some_and(|entry| entry.generation == self.generation)
            {
                refreshes.remove(&self.did);
            }
            strategy.used_refresh_tokens().remove(&self.token_hash);
        }
    }
}

fn legacy_session_key(did: &Did) -> String {
    format!("{LEGACY_SESSION_KEY_PREFIX}{}", did.as_str())
}

fn canonical_origin_string(url: &Url) -> String {
    url.origin().ascii_serialization()
}

fn sha256_bytes(data: &[u8]) -> [u8; 32] {
    Sha256::digest(data).into()
}

fn unix_now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |d| d.as_secs())
}

#[cfg(test)]
mod tests {
    use std::sync::Mutex as StdMutex;

    use serde_json::json;

    use super::*;
    use crate::{
        net::HttpTransport,
        oauth::{OAuthIdentity, OAuthIdentityError},
        storage::{MemorySecretStore, SessionStore},
    };

    const A_DID: &str = "did:plc:recova111111111111111111";
    const B_DID: &str = "did:plc:recovb222222222222222222";
    const PDS_URL: &str = "https://pds.recovery.example";

    struct StaticRecoveryResolver;
    impl OAuthIdentityResolver for StaticRecoveryResolver {
        fn resolve_identity<'a>(
            &'a self,
            identifier: &'a AtIdentifier,
            _force_refresh: bool,
        ) -> BoxFuture<'a, Result<OAuthIdentity, OAuthIdentityError>> {
            let ident = identifier.as_str().to_owned();
            Box::pin(async move {
                let did = if ident.contains("recova") || ident == "alice.example" {
                    A_DID
                } else {
                    B_DID
                };
                Ok(OAuthIdentity {
                    did: did.parse().expect("valid did"),
                    handle: None,
                    pds: Url::parse(PDS_URL).expect("valid pds url"),
                })
            })
        }
    }

    struct MultiAccountRecoveryTransport {
        refresh_bearers: StdMutex<Vec<String>>,
        a_refresh_seq: StdMutex<usize>,
        b_refresh_seq: StdMutex<usize>,
    }

    impl MultiAccountRecoveryTransport {
        fn new() -> Self {
            Self {
                refresh_bearers: StdMutex::new(Vec::new()),
                a_refresh_seq: StdMutex::new(0),
                b_refresh_seq: StdMutex::new(0),
            }
        }
    }

    impl HttpTransport for MultiAccountRecoveryTransport {
        fn send(
            &self,
            request: Request<Bytes>,
            _options: &SendOptions,
        ) -> impl std::future::Future<Output = Result<Response<Bytes>, TransportError>>
        + crate::rt::MaybeSend {
            let path = request.uri().path().to_owned();
            let auth = request
                .headers()
                .get(AUTHORIZATION)
                .and_then(|v| v.to_str().ok())
                .map(str::to_owned);
            let body = request.into_body();
            let (status, payload) = match path.as_str() {
                "/xrpc/com.atproto.server.createSession" => {
                    let parsed: serde_json::Value =
                        serde_json::from_slice(&body).expect("valid login JSON");
                    let identifier = parsed["identifier"].as_str().unwrap_or_default();
                    if identifier == "alice.example" || identifier == A_DID {
                        (
                            StatusCode::OK,
                            json!({
                                "did": A_DID,
                                "handle": "alice.example",
                                "accessJwt": "a-access-0",
                                "refreshJwt": "a-refresh-0",
                                "active": true
                            }),
                        )
                    } else {
                        (
                            StatusCode::OK,
                            json!({
                                "did": B_DID,
                                "handle": "bob.example",
                                "accessJwt": "b-access-0",
                                "refreshJwt": "b-refresh-0",
                                "active": true
                            }),
                        )
                    }
                }
                "/xrpc/com.atproto.server.refreshSession" => {
                    let bearer = auth.unwrap_or_default();
                    self.refresh_bearers.lock().unwrap().push(bearer.clone());
                    if bearer.starts_with("Bearer a-refresh-") {
                        let mut seq = self.a_refresh_seq.lock().unwrap();
                        *seq += 1;
                        (
                            StatusCode::OK,
                            json!({
                                "did": A_DID,
                                "handle": "alice.example",
                                "accessJwt": format!("a-access-{}", *seq),
                                "refreshJwt": format!("a-refresh-{}", *seq),
                                "active": true
                            }),
                        )
                    } else if bearer.starts_with("Bearer b-refresh-") {
                        let mut seq = self.b_refresh_seq.lock().unwrap();
                        *seq += 1;
                        (
                            StatusCode::OK,
                            json!({
                                "did": B_DID,
                                "handle": "bob.example",
                                "accessJwt": format!("b-access-{}", *seq),
                                "refreshJwt": format!("b-refresh-{}", *seq),
                                "active": true
                            }),
                        )
                    } else {
                        (
                            StatusCode::UNAUTHORIZED,
                            json!({"error": "InvalidToken", "message": "unexpected token"}),
                        )
                    }
                }
                _ => (StatusCode::NOT_FOUND, json!({"error": "NotFound"})),
            };
            std::future::ready(Ok(Response::builder()
                .status(status)
                .header(CONTENT_TYPE, "application/json")
                .body(Bytes::from(serde_json::to_vec(&payload).unwrap()))
                .unwrap()))
        }
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
    async fn cancelled_refresh_releases_its_token_while_the_refresh_map_is_busy() {
        let (strategy, _, _) = make_recovery_strategy();
        let hash = [7_u8; 32];
        strategy.used_refresh_tokens().insert(hash);
        let busy = strategy.active_refreshes.lock().await;
        drop(RefreshCleanupGuard {
            strategy: Arc::downgrade(&strategy),
            did: A_DID.parse().unwrap(),
            generation: 1,
            token_hash: hash,
            probe_id: None,
            finished: false,
        });
        drop(busy);
        // Before: `try_lock` lost to contention and left the token burned, so
        // the next refresh failed with "refresh token replay prevented".
        assert!(!strategy.used_refresh_tokens().contains(&hash));
    }

    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    fn make_recovery_strategy() -> (
        Arc<LegacyPasswordStrategy>,
        Arc<AccountManager>,
        Arc<MultiAccountRecoveryTransport>,
    ) {
        let store = SessionStore::new(Arc::new(MemorySecretStore::new()), "pw-recovery-test")
            .expect("session store");
        let account_manager = Arc::new(AccountManager::new(store));
        let transport = Arc::new(MultiAccountRecoveryTransport::new());
        let shared: SharedTransport = transport.clone();
        let strategy = Arc::new(LegacyPasswordStrategy::new(
            Arc::clone(&account_manager),
            shared,
            Arc::new(StaticRecoveryResolver),
            Url::parse(PDS_URL).expect("valid pds url"),
        ));
        (strategy, account_manager, transport)
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
    async fn attempt_recovery_refreshes_targeted_account_while_different_account_is_active() {
        let (strategy, account_manager, transport) = make_recovery_strategy();
        let did_a: Did = A_DID.parse().unwrap();
        let did_b: Did = B_DID.parse().unwrap();
        let missing_did: Did = "did:plc:missing33333333333333333".parse().unwrap();

        strategy
            .login_with_password("alice.example", "pw-a", None)
            .await
            .unwrap();
        strategy
            .login_with_password("bob.example", "pw-b", None)
            .await
            .unwrap();
        assert_eq!(
            account_manager.current_did().await.unwrap(),
            Some(did_b.clone())
        );

        for _ in 0..3 {
            strategy
                .circuit_breaker
                .record_failure(&did_a, RefreshFailureKind::Server)
                .await;
        }
        assert!(!strategy.circuit_breaker.can_attempt_refresh(&did_a).await);
        assert!(matches!(
            strategy.refresh_token_for_did(&did_a, true).await,
            Err(PasswordAuthError::TokenRefreshFailed(_))
        ));

        // Recovering `did_a` while `did_b` is active must refresh ONLY `did_a` and keep `did_b` active/untouched.
        strategy
            .attempt_recovery_from_server_failures(Some(&did_a))
            .await
            .unwrap();

        assert_eq!(
            transport.refresh_bearers.lock().unwrap().as_slice(),
            ["Bearer a-refresh-0"]
        );
        assert!(strategy.circuit_breaker.can_attempt_refresh(&did_a).await);
        assert_eq!(
            account_manager.current_did().await.unwrap(),
            Some(did_b.clone())
        );

        let session_a = strategy.get_session(&did_a).await.unwrap().unwrap();
        assert_eq!(session_a.access_jwt(), "a-access-1");
        assert_eq!(session_a.refresh_jwt(), "a-refresh-1");

        let session_b = strategy.get_session(&did_b).await.unwrap().unwrap();
        assert_eq!(session_b.access_jwt(), "b-access-0");
        assert_eq!(session_b.refresh_jwt(), "b-refresh-0");

        // Recovering an unknown DID fails cleanly without refreshing either A or B.
        assert!(matches!(
            strategy
                .attempt_recovery_from_server_failures(Some(&missing_did))
                .await,
            Err(PasswordAuthError::NoActiveAccount)
        ));
        assert_eq!(
            transport.refresh_bearers.lock().unwrap().as_slice(),
            ["Bearer a-refresh-0"]
        );

        // `None` falls back to recovering the currently active account (`did_b`).
        strategy
            .attempt_recovery_from_server_failures(None)
            .await
            .unwrap();
        assert_eq!(
            transport.refresh_bearers.lock().unwrap().as_slice(),
            ["Bearer a-refresh-0", "Bearer b-refresh-0"]
        );
        let session_b_after = strategy.get_session(&did_b).await.unwrap().unwrap();
        assert_eq!(session_b_after.access_jwt(), "b-access-1");
        assert_eq!(session_b_after.refresh_jwt(), "b-refresh-1");
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
    async fn half_open_breaker_not_stuck_when_routine_refresh_sees_still_valid() {
        use super::super::CircuitState;

        let (strategy, _account_manager, transport) = make_recovery_strategy();
        let did_a: Did = A_DID.parse().unwrap();

        strategy
            .login_with_password("alice.example", "pw-a", None)
            .await
            .unwrap();

        // Trip breaker open after 3 server failures, then transition to `HalfOpen`.
        for _ in 0..3 {
            strategy
                .circuit_breaker
                .record_failure(&did_a, RefreshFailureKind::Server)
                .await;
        }
        assert_eq!(
            strategy.circuit_breaker.state(&did_a).await,
            CircuitState::Open
        );
        assert!(strategy.circuit_breaker.force_half_open(&did_a).await);
        assert_eq!(
            strategy.circuit_breaker.state(&did_a).await,
            CircuitState::HalfOpen
        );

        // Routine non-forced refresh on a still-valid token returns `StillValid` WITHOUT
        // consuming or leaking `half_open_test_in_progress`.
        assert_eq!(
            strategy.refresh_token_if_needed(false).await.unwrap(),
            TokenRefreshResult::StillValid
        );
        assert_eq!(
            strategy.refresh_token_if_needed(false).await.unwrap(),
            TokenRefreshResult::StillValid
        );
        assert!(transport.refresh_bearers.lock().unwrap().is_empty());
        assert_eq!(
            strategy.circuit_breaker.state(&did_a).await,
            CircuitState::HalfOpen
        );

        // Subsequent forced recovery probe succeeds and closes the circuit breaker.
        assert_eq!(
            strategy.refresh_token_if_needed(true).await.unwrap(),
            TokenRefreshResult::RefreshedSuccessfully
        );
        assert_eq!(
            strategy.circuit_breaker.state(&did_a).await,
            CircuitState::Closed
        );
        assert_eq!(
            transport.refresh_bearers.lock().unwrap().as_slice(),
            ["Bearer a-refresh-0"]
        );
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
    async fn half_open_probe_released_when_refresh_exits_without_exchange() {
        use super::super::CircuitState;

        let (strategy, account_manager, transport) = make_recovery_strategy();
        let did_a: Did = A_DID.parse().unwrap();

        strategy
            .login_with_password("alice.example", "pw-a", None)
            .await
            .unwrap();

        // Direct breaker probe exclusivity & release check.
        for _ in 0..3 {
            strategy
                .circuit_breaker
                .record_failure(&did_a, RefreshFailureKind::Server)
                .await;
        }
        assert!(strategy.circuit_breaker.force_half_open(&did_a).await);
        let probe = strategy
            .circuit_breaker
            .try_acquire_refresh_slot(&did_a)
            .await
            .expect("first half-open probe admitted")
            .expect("half-open slot returns probe id");
        assert!(
            strategy
                .circuit_breaker
                .try_acquire_refresh_slot(&did_a)
                .await
                .is_none()
        );
        strategy
            .circuit_breaker
            .release_half_open_probe(&did_a, probe)
            .await;

        // Remove catalog account so `perform_refresh` fails before network exchange without
        // calling `record_success`/`record_failure`, then restore and retry.
        let saved_account = account_manager.get_account(&did_a).await.unwrap().unwrap();
        account_manager
            .storage()
            .delete_account(&did_a)
            .await
            .unwrap();
        account_manager.invalidate_cache(Some(&did_a)).await;

        assert!(matches!(
            strategy.refresh_token_for_did(&did_a, true).await,
            Err(PasswordAuthError::TokenRefreshFailed(_))
        ));
        assert!(transport.refresh_bearers.lock().unwrap().is_empty());
        assert_eq!(
            strategy.circuit_breaker.state(&did_a).await,
            CircuitState::HalfOpen
        );

        account_manager.add_account(&saved_account).await.unwrap();
        assert_eq!(
            strategy.refresh_token_for_did(&did_a, true).await.unwrap(),
            TokenRefreshResult::RefreshedSuccessfully
        );
        assert_eq!(
            strategy.circuit_breaker.state(&did_a).await,
            CircuitState::Closed
        );
        assert_eq!(
            transport.refresh_bearers.lock().unwrap().as_slice(),
            ["Bearer a-refresh-0"]
        );
    }
}
