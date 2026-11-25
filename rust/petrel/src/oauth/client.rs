use std::{
    collections::HashMap,
    fmt,
    sync::{
        Arc, Mutex,
        atomic::{AtomicU64, Ordering},
    },
};

use async_lock::Mutex as AsyncMutex;
use bytes::Bytes;
use http::{Response, StatusCode};
use petrel_core::{AtIdentifier, Did, Handle};
use petrel_oauth_scopes::ScopeSet;
use serde::Deserialize;
use url::Url;
use zeroize::Zeroize;

use crate::{
    crypto::{
        DpopSigner, SoftwareDpopSigner, base64url, pkce_challenge, pkce_verifier, random_bytes,
    },
    net::SharedTransport,
    rt::{BoxFuture, MaybeSend, MaybeSync},
    storage::{SessionStore, StoreError},
};

use super::{
    ClientAuth, MetadataError, OAuthProtocolError, Session, SessionRecord,
    dpop::{DpopNonces, nonce_header, oauth_error_code, use_dpop_nonce},
    metadata::{
        ValidatedAuthorizationServer, endpoint_url, is_loopback, origin, require_canonical_origin,
    },
    models::{Account, OAuthFlowState},
    protocol::{AsEndpoint, OAuthProtocol, unix_now},
    refresh::RefreshState,
};

#[derive(Clone, Debug, Eq, PartialEq, thiserror::Error)]
pub enum OAuthError {
    #[error(transparent)]
    Protocol(#[from] OAuthProtocolError),
    #[error(transparent)]
    Metadata(#[from] MetadataError),
    #[error(transparent)]
    Store(#[from] StoreError),
    #[error("invalid OAuth client ID")]
    ClientId,
    #[error("invalid OAuth redirect URI")]
    RedirectUri,
    #[error("OAuth scope is malformed or lacks atproto")]
    Scope,
    #[error("OAuth callback is invalid")]
    Callback,
    #[error("OAuth callback does not name an active authorization")]
    UnknownState,
    #[error("authorization was cancelled")]
    Cancelled,
    #[error("authorization was rejected")]
    AuthorizationRejected,
    #[error("OAuth response did not contain a valid DPoP nonce")]
    MissingNonce,
    #[error("authorization server still requires a DPoP nonce after the nonce retry")]
    NonceRetryExhausted,
    #[error("authorization server rejected the grant")]
    InvalidGrant,
    #[error("authorization server returned HTTP {0}")]
    ServerStatus(u16),
    #[error("authorization server response is malformed or violates the session binding")]
    InvalidResponse,
    #[error("account identity could not be resolved")]
    Identity,
    #[error("account PDS or issuer changed during authorization")]
    IdentityChanged,
    #[error("the session DPoP key is missing or mismatched")]
    KeyBinding,
    #[error("no OAuth session for the account")]
    MissingSession,
    #[error("session lacks a trusted issuer for OAuth metadata recovery")]
    MissingIssuer,
    #[error("the stored session changed before the refresh could be committed")]
    SessionChanged,
    #[error("rotated tokens are awaiting durable storage")]
    RefreshPersistencePending,
    #[error("the OAuth session has expired")]
    ExpiredSession,
    #[error("the authorization server did not rotate the refresh token")]
    UsedRefreshToken,
    #[error("another refresh is deferred by the per-account circuit breaker")]
    RefreshBackoff,
}

impl From<crate::crypto::CryptoError> for OAuthError {
    fn from(error: crate::crypto::CryptoError) -> Self {
        OAuthProtocolError::Crypto(error).into()
    }
}

#[derive(Clone, Debug)]
pub struct OAuthConfig {
    client_id: String,
    redirect_uri: Url,
    scope: ScopeSet,
    authentication: ClientAuth,
    allow_loopback: bool,
}

impl OAuthConfig {
    pub fn new(
        client_id: impl Into<String>,
        redirect_uri: Url,
        scope: &str,
        authentication: ClientAuth,
    ) -> Result<Self, OAuthError> {
        let client_id = client_id.into();
        let parsed = endpoint_url(&client_id).ok_or(OAuthError::ClientId)?;
        let raw_authority = client_id
            .split_once("://")
            .ok_or(OAuthError::ClientId)?
            .1
            .split(['/', '?', '#'])
            .next()
            .ok_or(OAuthError::ClientId)?;
        if raw_authority.contains(':') {
            return Err(OAuthError::ClientId);
        }
        let development_id = parsed.scheme() == "http" && parsed.host_str() == Some("localhost");
        if development_id {
            if parsed.path() != "/" || !matches!(authentication, ClientAuth::Public) {
                return Err(OAuthError::ClientId);
            }
        } else if parsed.scheme() != "https" || parsed.query().is_some() || is_loopback(&parsed) {
            return Err(OAuthError::ClientId);
        }
        if let ClientAuth::Cab {
            client_id: backend_client,
            ..
        } = &authentication
            && backend_client != &client_id
        {
            return Err(OAuthError::ClientId);
        }
        let reversed_host = parsed
            .host_str()
            .ok_or(OAuthError::ClientId)?
            .split('.')
            .rev()
            .collect::<Vec<_>>()
            .join(".");
        let redirect_matches = match redirect_uri.scheme() {
            "https" => {
                !development_id && redirect_uri.host_str().is_some() && !is_loopback(&redirect_uri)
            }
            "http" => {
                development_id && matches!(redirect_uri.host_str(), Some("127.0.0.1" | "[::1]"))
            }
            scheme => {
                !development_id
                    && scheme == reversed_host
                    && redirect_uri.host_str().is_none()
                    && redirect_uri.path().starts_with('/')
                    && !redirect_uri.path().starts_with("//")
            }
        };
        if !redirect_matches
            || redirect_uri.fragment().is_some()
            || !redirect_uri.username().is_empty()
            || redirect_uri.password().is_some()
            || redirect_uri
                .query_pairs()
                .any(|(key, _)| is_callback_parameter(&key))
        {
            return Err(OAuthError::RedirectUri);
        }
        let scope = ScopeSet::parse(scope).map_err(|_| OAuthError::Scope)?;
        if !scope.includes_atproto() {
            return Err(OAuthError::Scope);
        }

        Ok(Self {
            client_id,
            redirect_uri,
            scope,
            authentication,
            allow_loopback: false,
        })
    }

    /// Constructs public OAuth client metadata for a loopback development listener.
    pub fn loopback(port: u16, path: &str, scope: &str) -> Result<Self, OAuthError> {
        if port == 0 || !path.starts_with('/') || path.starts_with("//") {
            return Err(OAuthError::RedirectUri);
        }
        let mut redirect =
            Url::parse(&format!("http://127.0.0.1:{port}")).map_err(|_| OAuthError::RedirectUri)?;
        redirect.set_path(path);
        let query = url::form_urlencoded::Serializer::new(String::new())
            .append_pair("redirect_uri", redirect.as_str())
            .append_pair("scope", scope)
            .finish();
        Ok(Self::new(
            format!("http://localhost?{query}"),
            redirect,
            scope,
            ClientAuth::Public,
        )?
        .with_loopback_development())
    }

    /// Permit explicit loopback HTTP endpoints for local development.
    #[must_use]
    pub fn with_loopback_development(mut self) -> Self {
        self.allow_loopback = true;
        self
    }
}

#[derive(Clone, Debug)]
pub enum OAuthTarget {
    Identifier(AtIdentifier),
    Server(Url),
}

/// Overrides for one authorization flow.
#[derive(Clone, Copy, Debug, Default)]
pub struct OAuthStartOptions<'a> {
    pub scope: Option<&'a str>,
    pub state_prefix: Option<&'a str>,
}

/// The browser URL and state referring to a pending authorization.
#[derive(Clone)]
pub struct PendingOAuthFlow {
    pub authorize_url: Url,
    pub state: String,
}

impl fmt::Debug for PendingOAuthFlow {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("PendingOAuthFlow").finish_non_exhaustive()
    }
}

#[derive(Clone, Debug)]
pub struct OAuthIdentity {
    pub did: Did,
    pub handle: Option<Handle>,
    pub pds: Url,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, thiserror::Error)]
#[error("OAuth account identity could not be resolved")]
pub struct OAuthIdentityError;

pub trait OAuthIdentityResolver: MaybeSend + MaybeSync {
    /// `force_refresh` bypasses all cached DID/PDS data for callback verification.
    fn resolve_identity<'a>(
        &'a self,
        identifier: &'a AtIdentifier,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<OAuthIdentity, OAuthIdentityError>>;
}

/// Manages persistent DPoP keys retained by OAuth state and sessions.
/// Implementations may store opaque keys, such as browser WebCrypto CryptoKeys.
pub trait DpopKeyStore: MaybeSend + MaybeSync {
    fn create<'a>(&'a self, id: &'a str) -> BoxFuture<'a, Result<Arc<dyn DpopSigner>, StoreError>>;
    fn get<'a>(
        &'a self,
        id: &'a str,
    ) -> BoxFuture<'a, Result<Option<Arc<dyn DpopSigner>>, StoreError>>;
    fn delete<'a>(&'a self, id: &'a str) -> BoxFuture<'a, Result<(), StoreError>>;
}

/// Default software-key fallback storing raw P-256 scalars in [`SessionStore`].
/// Browser (`wasm32`) embedders should instead pass [`super::WebCryptoKeyStore`]
/// to [`OAuthClient::with_key_store`] so DPoP keys remain non-extractable.
struct SoftwareKeyStore {
    storage: SessionStore,
}

impl DpopKeyStore for SoftwareKeyStore {
    fn create<'a>(&'a self, id: &'a str) -> BoxFuture<'a, Result<Arc<dyn DpopSigner>, StoreError>> {
        Box::pin(async move {
            let key = SoftwareDpopSigner::generate()
                .map_err(|_| StoreError::Unavailable("DPoP key generation".into()))?;
            self.storage.save_dpop_key(id, &key.to_bytes()).await?;
            Ok(Arc::new(key) as Arc<dyn DpopSigner>)
        })
    }

    fn get<'a>(
        &'a self,
        id: &'a str,
    ) -> BoxFuture<'a, Result<Option<Arc<dyn DpopSigner>>, StoreError>> {
        Box::pin(async move {
            self.storage
                .get_dpop_key(id)
                .await?
                .map(|material| {
                    SoftwareDpopSigner::from_bytes(&material)
                        .map(|key| Arc::new(key) as Arc<dyn DpopSigner>)
                        .map_err(|_| StoreError::Corrupt("DPoP key".into()))
                })
                .transpose()
        })
    }

    fn delete<'a>(&'a self, id: &'a str) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(self.storage.delete_dpop_key(id))
    }
}

type StartTargetKey = (String, String, Option<String>);

pub struct OAuthClient {
    pub(super) protocol: OAuthProtocol,
    pub(super) storage: SessionStore,
    pub(super) keys: Arc<dyn DpopKeyStore>,
    pub(super) resource_nonces: DpopNonces,
    pub(super) instance_id: [u8; 16],
    resolver: Arc<dyn OAuthIdentityResolver>,
    config: OAuthConfig,
    pub(super) accounts: Mutex<HashMap<Did, Arc<AsyncMutex<RefreshState>>>>,
    start_locks: Mutex<HashMap<StartTargetKey, Arc<AsyncMutex<()>>>>,
    start_seq: AtomicU64,
    pending: AsyncMutex<Vec<PendingAuthorization>>,
}

struct ResolvedAuthorizationTarget<'a> {
    server: ValidatedAuthorizationServer,
    expected_did: Option<Did>,
    expected_pds: Option<String>,
    login_hint: Option<&'a str>,
}

struct PendingAuthorization {
    target: StartTargetKey,
    flow: PendingOAuthFlow,
    expected_issuer: String,
    created_at: u64,
    reuse_until: u64,
    finished_seq: u64,
    denied: bool,
    key_id: String,
    jkt: String,
}

impl fmt::Debug for OAuthClient {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("OAuthClient").finish_non_exhaustive()
    }
}

impl OAuthClient {
    /// Creates an OAuth client using [`SessionStore`] for software DPoP keys.
    ///
    /// On `wasm32` browser targets, chain [`Self::with_key_store`] with
    /// [`super::WebCryptoKeyStore`] so private DPoP keys are held as
    /// non-extractable WebCrypto `CryptoKey` handles instead of persisted scalars.
    // The key store uses the same shared ownership API on native and wasm.
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    pub fn new(
        transport: SharedTransport,
        resolver: Arc<dyn OAuthIdentityResolver>,
        storage: SessionStore,
        config: OAuthConfig,
    ) -> Result<Self, OAuthError> {
        if endpoint_url(&config.client_id).is_some_and(|url| url.scheme() == "http")
            && !config.allow_loopback
        {
            return Err(OAuthError::ClientId);
        }
        Ok(Self {
            protocol: OAuthProtocol {
                transport,
                client_id: config.client_id.clone(),
                authentication: config.authentication.clone(),
                allow_loopback: config.allow_loopback,
                nonces: DpopNonces::default(),
            },
            keys: Arc::new(SoftwareKeyStore {
                storage: storage.clone(),
            }),
            resource_nonces: DpopNonces::default(),
            instance_id: random_bytes::<16>()?,
            storage,
            resolver,
            config,
            accounts: Mutex::new(HashMap::new()),
            start_locks: Mutex::new(HashMap::new()),
            start_seq: AtomicU64::new(0),
            pending: AsyncMutex::new(Vec::new()),
        })
    }

    #[must_use]
    pub fn with_key_store(mut self, keys: Arc<dyn DpopKeyStore>) -> Self {
        self.keys = keys;
        self
    }

    pub async fn start_authorization(&self, target: OAuthTarget) -> Result<Url, OAuthError> {
        Ok(self
            .start_authorization_with_options(target, OAuthStartOptions::default())
            .await?
            .authorize_url)
    }

    pub async fn start_authorization_with_options(
        &self,
        target: OAuthTarget,
        options: OAuthStartOptions<'_>,
    ) -> Result<PendingOAuthFlow, OAuthError> {
        let start_seq = self.start_seq.fetch_add(1, Ordering::Relaxed);
        let requested_scope = options
            .scope
            .map(ScopeSet::parse)
            .transpose()
            .map_err(|_| OAuthError::Scope)?;
        let scope = requested_scope.as_ref().unwrap_or(&self.config.scope);
        if !scope.includes_atproto() {
            return Err(OAuthError::Scope);
        }
        if options
            .state_prefix
            .is_some_and(|prefix| !valid_state_prefix(prefix))
        {
            return Err(OAuthError::Callback);
        }

        let target_key = match &target {
            OAuthTarget::Identifier(identifier) => identifier.as_str(),
            OAuthTarget::Server(url) => url.as_str(),
        };
        let target_key = (
            target_key.to_owned(),
            scope.scope_string(),
            options.state_prefix.map(str::to_owned),
        );
        // Serialize overlapping starts for the same target key so they share
        // one PAR/DPoP flow without holding `pending` across network I/O.
        let target_lock = self.start_lock(&target_key);
        let _target_guard = target_lock.lock().await;
        let now = unix_now()?;
        let (reused, expired) = self
            .take_reusable_or_expired_pending(&target_key, now, start_seq)
            .await?;
        if let Some(flow) = reused {
            return Ok(flow);
        }
        for flow in &expired {
            self.cancel_flow(flow, now).await?;
        }

        let resolved = self.resolve_target(&target).await?;
        let expected_issuer = resolved.server.issuer().to_owned();
        let key_id = base64url(&random_bytes::<32>()?);
        let state = base64url(&random_bytes::<32>()?);
        let state = match options.state_prefix {
            Some(prefix) => format!("{prefix}.{state}"),
            None => state,
        };
        let key = self.keys.create(&key_id).await?;
        let jkt = match key.public_jwk().thumbprint() {
            Ok(jkt) => jkt,
            Err(error) => {
                self.keys.delete(&key_id).await?;
                return Err(error.into());
            }
        };
        let (authorize_url, par_lifetime) = match self
            .push_authorization(resolved, &target_key.1, &state, &key_id, &jkt, &*key)
            .await
        {
            Ok(url) => url,
            Err(error) => {
                self.protocol.nonces.clear_key(&jkt);
                self.keys.delete(&key_id).await?;
                return Err(error);
            }
        };
        let created_at = unix_now()?;
        let flow = PendingOAuthFlow {
            authorize_url,
            state,
        };
        self.store_pending_authorization(PendingAuthorization {
            target: target_key,
            flow: flow.clone(),
            expected_issuer,
            created_at,
            reuse_until: created_at.saturating_add(par_lifetime),
            finished_seq: self.start_seq.load(Ordering::Relaxed),
            denied: false,
            key_id,
            jkt,
        })
        .await?;
        Ok(flow)
    }

    fn start_lock(&self, target: &StartTargetKey) -> Arc<AsyncMutex<()>> {
        let mut locks = self
            .start_locks
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        if locks.len() > 64 {
            locks.retain(|_, lock| Arc::strong_count(lock) > 1);
        }
        Arc::clone(locks.entry(target.clone()).or_default())
    }

    async fn take_reusable_or_expired_pending(
        &self,
        target_key: &StartTargetKey,
        now: u64,
        start_seq: u64,
    ) -> Result<(Option<PendingOAuthFlow>, Vec<PendingAuthorization>), OAuthError> {
        let mut pending = self.pending.lock().await;
        if let Some(flow) = pending.iter().find(|flow| {
            !flow.denied
                && &flow.target == target_key
                && now < flow.reuse_until
                && start_seq < flow.finished_seq
        }) {
            return Ok((Some(flow.flow.clone()), Vec::new()));
        }
        let expired = drain_expired_pending(&mut pending, now);
        if pending.len() >= 8 {
            return Err(OAuthError::AuthorizationRejected);
        }
        Ok((None, expired))
    }

    async fn store_pending_authorization(
        &self,
        entry: PendingAuthorization,
    ) -> Result<(), OAuthError> {
        let now = entry.created_at;
        let overflow_expired: Vec<PendingAuthorization> = {
            let mut pending = self.pending.lock().await;
            let expired = drain_expired_pending(&mut pending, now);
            if pending.len() >= 8 {
                drop(pending);
                for stale in &expired {
                    let _ = self.cancel_flow(stale, now).await;
                }
                let _ = self.cancel_flow(&entry, now).await;
                return Err(OAuthError::AuthorizationRejected);
            }
            pending.push(entry);
            expired
        };
        for stale in &overflow_expired {
            let _ = self.cancel_flow(stale, now).await;
        }
        Ok(())
    }
}

fn drain_expired_pending(
    pending: &mut Vec<PendingAuthorization>,
    now: u64,
) -> Vec<PendingAuthorization> {
    let mut expired = Vec::new();
    let mut index = 0;
    while index < pending.len() {
        if now.saturating_sub(pending[index].created_at) > 600 {
            expired.push(pending.swap_remove(index));
        } else {
            index += 1;
        }
    }
    expired
}

impl OAuthClient {
    async fn resolve_target<'a>(
        &self,
        target: &'a OAuthTarget,
    ) -> Result<ResolvedAuthorizationTarget<'a>, OAuthError> {
        match target {
            OAuthTarget::Identifier(identifier) => {
                let identity = self
                    .resolver
                    .resolve_identity(identifier, false)
                    .await
                    .map_err(|_| OAuthError::Identity)?;
                if let AtIdentifier::Did(did) = identifier
                    && did != &identity.did
                {
                    return Err(OAuthError::IdentityChanged);
                }
                let pds = origin(&identity.pds, false).ok_or(OAuthError::Identity)?;
                let server = self.protocol.discover_pds(&identity.pds).await?;
                Ok(ResolvedAuthorizationTarget {
                    server,
                    expected_did: Some(identity.did),
                    expected_pds: Some(pds),
                    login_hint: Some(identifier.as_str()),
                })
            }
            OAuthTarget::Server(url) => Ok(ResolvedAuthorizationTarget {
                server: self.protocol.discover_server(url).await?,
                expected_did: None,
                expected_pds: None,
                login_hint: None,
            }),
        }
    }

    async fn push_authorization(
        &self,
        target: ResolvedAuthorizationTarget<'_>,
        scope: &str,
        state: &str,
        key_id: &str,
        jkt: &str,
        key: &dyn DpopSigner,
    ) -> Result<(Url, u64), OAuthError> {
        #[derive(Deserialize)]
        struct ParResponse {
            request_uri: String,
            expires_in: Option<u64>,
        }

        let verifier = zeroize::Zeroizing::new(pkce_verifier()?);
        let challenge = pkce_challenge(&verifier);
        let mut parameters = vec![
            ("redirect_uri", self.config.redirect_uri.as_str()),
            ("response_type", "code"),
            ("code_challenge_method", "S256"),
            ("code_challenge", challenge.as_str()),
            ("state", state),
            ("scope", scope),
        ];
        if let Some(hint) = target.login_hint {
            parameters.push(("login_hint", hint));
        }
        let server = &target.server;
        let response = self
            .protocol
            .send_as(server, AsEndpoint::Par, &parameters, key)
            .await?;
        require_success(&response)?;
        let nonce = required_nonce(response.headers())?;
        let par: ParResponse =
            serde_json::from_slice(response.body()).map_err(|_| OAuthError::InvalidResponse)?;
        if par.request_uri.is_empty() || par.request_uri.bytes().any(|byte| byte.is_ascii_control())
        {
            return Err(OAuthError::InvalidResponse);
        }
        let mut authorize = server.authorization_endpoint().clone();
        if authorize
            .query_pairs()
            .any(|(param, _)| matches!(param.as_ref(), "client_id" | "request_uri"))
        {
            return Err(OAuthError::InvalidResponse);
        }
        authorize
            .query_pairs_mut()
            .append_pair("client_id", &self.config.client_id)
            .append_pair("request_uri", &par.request_uri);

        let stored = OAuthFlowState {
            code_verifier: verifier.to_string(),
            nonce: nonce.to_owned(),
            expected_issuer: server.issuer().to_owned(),
            expected_pds: target.expected_pds,
            expected_did: target.expected_did,
            redirect_uri: self.config.redirect_uri.as_str().to_owned(),
            dpop_key_id: key_id.to_owned(),
            dpop_jkt: jkt.to_owned(),
            metadata: server.metadata().clone(),
        };
        self.storage
            .save_oauth_state(state, unix_now()?, &stored)
            .await?;
        Ok((authorize, par.expires_in.unwrap_or(30).min(600)))
    }

    async fn cancel_flow(&self, flow: &PendingAuthorization, now: u64) -> Result<(), OAuthError> {
        match self
            .storage
            .consume_oauth_state::<OAuthFlowState>(&flow.flow.state, now)
            .await
        {
            Ok(None) => return Ok(()),
            Ok(Some(_)) | Err(StoreError::InvalidFlowStateAge) => {}
            Err(error) => return Err(error.into()),
        }
        self.protocol.nonces.clear_key(&flow.jkt);
        self.keys.delete(&flow.key_id).await?;
        Ok(())
    }

    /// Spends a pending state and removes its DPoP key.
    pub async fn cancel_authorization(&self, state: &str) -> Result<bool, OAuthError> {
        if !valid_state(state) {
            return Err(OAuthError::UnknownState);
        }
        let known = {
            let mut pending = self.pending.lock().await;
            if let Some(flow) = pending.iter_mut().find(|flow| flow.flow.state == state) {
                flow.denied = true;
                true
            } else {
                false
            }
        };
        let taken = self
            .storage
            .consume_oauth_state::<OAuthFlowState>(state, unix_now()?)
            .await;
        if let Err(error) = &taken
            && *error != StoreError::InvalidFlowStateAge
        {
            // Keep the in-process denial marker if the store could not
            // atomically take this locally created state.
            return Err(error.clone().into());
        }
        if matches!(taken, Ok(None)) {
            // If a callback took the record while this cancellation was
            // marking it, leave the marker for that consumer to observe.
            return Ok(known);
        }
        let local = self.remove_pending(state).await;
        match taken {
            Ok(Some(flow)) => {
                self.protocol.nonces.clear_key(&flow.dpop_jkt);
                self.keys.delete(&flow.dpop_key_id).await?;
                Ok(true)
            }
            Ok(None) => Ok(false),
            Err(StoreError::InvalidFlowStateAge) => {
                if let Some(flow) = local {
                    self.protocol.nonces.clear_key(&flow.jkt);
                    self.keys.delete(&flow.key_id).await?;
                }
                Ok(false)
            }
            Err(error) => Err(error.into()),
        }
    }

    async fn remove_pending(&self, state: &str) -> Option<PendingAuthorization> {
        let mut pending = self.pending.lock().await;
        pending
            .iter()
            .position(|flow| flow.flow.state == state)
            .map(|index| pending.swap_remove(index))
    }

    /// Completes a callback and atomically commits its bound account session.
    pub async fn complete_authorization(&self, callback: &Url) -> Result<Session, OAuthError> {
        let state = callback_parameter(callback, "state")?.ok_or(OAuthError::UnknownState)?;
        if !valid_state(&state) {
            return Err(OAuthError::UnknownState);
        }
        if self
            .pending
            .lock()
            .await
            .iter()
            .any(|flow| flow.denied && flow.flow.state == state)
        {
            return Err(OAuthError::UnknownState);
        }
        if same_redirect(callback, &self.config.redirect_uri)
            && let Some(error) = callback_parameter(callback, "error")?
        {
            let callback_iss = callback_parameter(callback, "iss")?;
            let pending_issuer = {
                let pending = self.pending.lock().await;
                pending
                    .iter()
                    .find(|flow| flow.flow.state == state)
                    .map(|flow| flow.expected_issuer.clone())
            };
            if let Some(expected_issuer) = pending_issuer {
                if callback_iss.as_deref() != Some(expected_issuer.as_str()) {
                    return Err(OAuthError::Callback);
                }
                match self.cancel_authorization(&state).await {
                    Ok(false) => return Err(OAuthError::UnknownState),
                    Err(_) => {
                        tracing::warn!(
                            "could not remove a denied OAuth authorization from storage"
                        );
                    }
                    Ok(true) => {}
                }
            } else {
                let Some(callback_iss) = callback_iss else {
                    return Err(OAuthError::Callback);
                };
                let flow: OAuthFlowState = self
                    .storage
                    .consume_oauth_state(&state, unix_now()?)
                    .await?
                    .ok_or(OAuthError::UnknownState)?;
                self.protocol.nonces.clear_key(&flow.dpop_jkt);
                self.keys.delete(&flow.dpop_key_id).await?;
                if callback_iss != flow.expected_issuer {
                    return Err(OAuthError::Callback);
                }
            }
            return Err(if error == "access_denied" {
                OAuthError::Cancelled
            } else {
                OAuthError::AuthorizationRejected
            });
        }
        let flow: OAuthFlowState = self
            .storage
            .consume_oauth_state(&state, unix_now()?)
            .await?
            .ok_or(OAuthError::UnknownState)?;
        if self
            .remove_pending(&state)
            .await
            .is_some_and(|local| local.denied)
        {
            self.protocol.nonces.clear_key(&flow.dpop_jkt);
            self.keys.delete(&flow.dpop_key_id).await?;
            return Err(OAuthError::UnknownState);
        }
        let result = self.complete_flow(callback, &flow).await;
        if result.is_err() {
            self.protocol.nonces.clear_key(&flow.dpop_jkt);
            self.keys.delete(&flow.dpop_key_id).await?;
        }
        result
    }

    async fn complete_flow(
        &self,
        callback: &Url,
        flow: &OAuthFlowState,
    ) -> Result<Session, OAuthError> {
        if flow.redirect_uri != self.config.redirect_uri.as_str()
            || !same_redirect(callback, &self.config.redirect_uri)
        {
            return Err(OAuthError::RedirectUri);
        }
        let issuer = callback_parameter(callback, "iss")?.ok_or(OAuthError::Callback)?;
        if issuer != flow.expected_issuer
            || flow.expected_did.is_some() != flow.expected_pds.is_some()
        {
            return Err(OAuthError::Callback);
        }
        let code = zeroize::Zeroizing::new(
            callback_parameter(callback, "code")?.ok_or(OAuthError::Callback)?,
        );
        let key = self.bound_key(&flow.dpop_key_id, &flow.dpop_jkt).await?;
        let server = flow
            .metadata
            .clone()
            .validate(&flow.expected_issuer, self.config.authentication.method())?;
        if let Some(pds) = &flow.expected_pds {
            server.validates_resource(pds)?;
        }
        if server.par_endpoint.origin() == server.token_endpoint.origin() {
            self.protocol
                .nonces
                .put(&flow.dpop_jkt, &server.token_endpoint, &flow.nonce)
                .map_err(OAuthProtocolError::Dpop)?;
        }

        let response = self
            .protocol
            .send_as(
                &server,
                AsEndpoint::Token,
                &[
                    ("grant_type", "authorization_code"),
                    ("code", &code),
                    ("redirect_uri", &flow.redirect_uri),
                    ("code_verifier", &flow.code_verifier),
                ],
                &*key,
            )
            .await?;
        require_success(&response)?;
        let result = self.verify_and_save(flow, &server, &response).await;
        if result.is_err() {
            self.revoke_returned(&server, &*key, response.body()).await;
        }
        result
    }

    async fn verify_and_save(
        &self,
        flow: &OAuthFlowState,
        server: &ValidatedAuthorizationServer,
        response: &Response<Bytes>,
    ) -> Result<Session, OAuthError> {
        required_nonce(response.headers())?;
        let tokens = TokenResponse::decode(response.body())?;
        let did = tokens.did()?;
        if flow
            .expected_did
            .as_ref()
            .is_some_and(|expected| expected != &did)
        {
            return Err(OAuthError::IdentityChanged);
        }
        let identity = self
            .resolver
            .resolve_identity(&AtIdentifier::Did(did.clone()), true)
            .await
            .map_err(|_| OAuthError::Identity)?;
        let pds = origin(&identity.pds, false).ok_or(OAuthError::Identity)?;
        if identity.did != did
            || flow
                .expected_pds
                .as_ref()
                .is_some_and(|expected| expected != &pds)
        {
            return Err(OAuthError::IdentityChanged);
        }
        let verified = self.protocol.discover_pds(&identity.pds).await?;
        if verified.issuer() != server.issuer() {
            return Err(OAuthError::IdentityChanged);
        }
        server.validates_resource(&pds)?;
        let session = tokens.session(did.clone(), unix_now()?, None, &flow.dpop_jkt)?;
        let record = SessionRecord {
            account: Account {
                did: did.clone(),
                handle: identity.handle,
                pds,
                authorization_server: Some(server.metadata().clone()),
                expected_issuer: Some(server.issuer().to_owned()),
            },
            session: session.clone(),
            dpop_key_id: flow.dpop_key_id.clone(),
            dpop_jkt: flow.dpop_jkt.clone(),
        };
        let lock = self.account_lock(&did);
        let mut refresh = lock.lock().await;
        let old = self.storage.get_session(&did).await?;
        self.storage.save_session(&record).await?;
        *refresh = RefreshState::default();
        if let Some(old) = old
            && old.dpop_key_id != record.dpop_key_id
        {
            if old.dpop_jkt != record.dpop_jkt {
                self.protocol.nonces.clear_key(&old.dpop_jkt);
                self.resource_nonces.clear_key(&old.dpop_jkt);
            }
            // Once the new session is persisted, cleanup cannot invalidate it.
            let _ = self.keys.delete(&old.dpop_key_id).await;
        }
        // Once credentials are durable, a separate selection write can be
        // reported as a storage event without invalidating the new session.
        if self.storage.save_current_did(&did).await.is_err() {
            tracing::warn!("could not persist the current OAuth account selection");
        }
        Ok(session)
    }

    pub(super) fn account_lock(&self, did: &Did) -> Arc<AsyncMutex<RefreshState>> {
        self.accounts
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .entry(did.clone())
            .or_default()
            .clone()
    }

    pub(super) async fn bound_key(
        &self,
        id: &str,
        jkt: &str,
    ) -> Result<Arc<dyn DpopSigner>, OAuthError> {
        let key = self.keys.get(id).await?.ok_or(OAuthError::KeyBinding)?;
        if key.public_jwk().thumbprint()? != jkt {
            return Err(OAuthError::KeyBinding);
        }
        Ok(key)
    }

    pub(super) async fn resolve_account_server(
        &self,
        account: &Account,
    ) -> Result<ValidatedAuthorizationServer, OAuthError> {
        let pds = require_canonical_origin(&account.pds)?;
        if !self.protocol.permits(&pds) {
            return Err(OAuthError::Identity);
        }

        let expected = account.expected_issuer.as_deref();
        if let Some(expected) = expected {
            let issuer = require_canonical_origin(expected)?;
            if !self.protocol.permits(&issuer) || (is_loopback(&issuer) && !is_loopback(&pds)) {
                return Err(OAuthError::Identity);
            }
        }
        let Some(metadata) = &account.authorization_server else {
            let issuer = expected.ok_or(OAuthError::MissingIssuer)?;
            return Ok(self
                .protocol
                .discover_pds_with_issuer(&pds, Some(issuer))
                .await?);
        };

        // Old Rust v1 records with a complete metadata document remain valid.
        // An invalid present document must never trigger a discovery fallback.
        let server = metadata.clone().validate(
            expected.unwrap_or(&metadata.issuer),
            self.config.authentication.method(),
        )?;
        let issuer = require_canonical_origin(server.issuer())?;
        if !self.protocol.permits(&issuer) || (is_loopback(&issuer) && !is_loopback(&pds)) {
            return Err(OAuthError::Identity);
        }
        server.validates_resource(&account.pds)?;
        Ok(server)
    }

    pub(super) async fn revoke_returned(
        &self,
        server: &ValidatedAuthorizationServer,
        key: &dyn DpopSigner,
        body: &[u8],
    ) {
        let Ok(fields) =
            serde_json::from_slice::<HashMap<String, &serde_json::value::RawValue>>(body)
        else {
            return;
        };
        for field in ["refresh_token", "access_token"] {
            if let Some(value) = fields.get(field)
                && let Ok(token) = serde_json::from_str::<String>(value.get())
                && !token.is_empty()
            {
                let token = zeroize::Zeroizing::new(token);
                let _ = self.revoke(server, key, &token).await;
                break;
            }
        }
    }

    pub(super) async fn revoke(
        &self,
        server: &ValidatedAuthorizationServer,
        key: &dyn DpopSigner,
        token: &str,
    ) -> bool {
        if server.revocation_endpoint.is_none() {
            return false;
        }
        self.protocol
            .send_as(server, AsEndpoint::Revoke, &[("token", token)], key)
            .await
            .is_ok_and(|response| response.status() == StatusCode::OK)
    }
}

pub(super) fn require_success(response: &Response<Bytes>) -> Result<(), OAuthError> {
    if response.status().is_success() {
        return Ok(());
    }
    if matches!(
        response.status(),
        StatusCode::BAD_REQUEST | StatusCode::UNAUTHORIZED
    ) && oauth_error_code(response.body()) == Some("invalid_grant")
    {
        return Err(OAuthError::InvalidGrant);
    }
    if use_dpop_nonce(response) {
        return Err(OAuthError::NonceRetryExhausted);
    }
    Err(OAuthError::ServerStatus(response.status().as_u16()))
}

fn required_nonce(headers: &http::HeaderMap) -> Result<&str, OAuthError> {
    nonce_header(headers)
        .ok()
        .flatten()
        .ok_or(OAuthError::MissingNonce)
}

fn callback_parameter(url: &Url, name: &str) -> Result<Option<String>, OAuthError> {
    let mut values = url.query_pairs().filter(|(key, _)| key == name);
    let found = values.next().map(|(_, value)| value.into_owned());
    if values.next().is_some() || found.as_deref() == Some("") {
        return Err(OAuthError::Callback);
    }
    Ok(found)
}

fn valid_state_prefix(prefix: &str) -> bool {
    !prefix.is_empty()
        && prefix.len() <= 64
        && prefix
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_' | b'.' | b'~'))
}

fn valid_state(state: &str) -> bool {
    let suffix = match state.rsplit_once('.') {
        Some((prefix, suffix)) if valid_state_prefix(prefix) => suffix,
        Some(_) => return false,
        None => state,
    };
    suffix.len() == 43
        && suffix
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_'))
}

fn is_callback_parameter(name: &str) -> bool {
    matches!(
        name,
        "state" | "iss" | "code" | "error" | "error_description" | "error_uri"
    )
}

fn same_redirect(callback: &Url, expected: &Url) -> bool {
    callback.scheme() == expected.scheme()
        && callback.host() == expected.host()
        && callback.port() == expected.port()
        && callback.path() == expected.path()
        && callback.username().is_empty()
        && callback.password().is_none()
        && callback.fragment().is_none()
        && expected.query_pairs().all(|(key, value)| {
            callback_parameter(callback, &key)
                .is_ok_and(|found| found.as_deref() == Some(value.as_ref()))
        })
}

#[derive(Deserialize)]
pub(super) struct TokenResponse {
    access_token: String,
    refresh_token: Option<String>,
    token_type: String,
    expires_in: Option<u64>,
    sub: String,
    scope: String,
    dpop_jkt: Option<String>,
}

impl TokenResponse {
    pub(super) fn decode(body: &[u8]) -> Result<Self, OAuthError> {
        serde_json::from_slice(body).map_err(|_| OAuthError::InvalidResponse)
    }

    pub(super) fn did(&self) -> Result<Did, OAuthError> {
        self.sub.parse().map_err(|_| OAuthError::InvalidResponse)
    }

    pub(super) fn session(
        &self,
        did: Did,
        now: u64,
        old_refresh: Option<&str>,
        expected_jkt: &str,
    ) -> Result<Session, OAuthError> {
        if !self.token_type.eq_ignore_ascii_case("dpop")
            || !valid_access_token(&self.access_token)
            || self.refresh_token.as_ref().is_some_and(String::is_empty)
            || self
                .dpop_jkt
                .as_ref()
                .is_some_and(|jkt| jkt != expected_jkt)
        {
            return Err(OAuthError::InvalidResponse);
        }
        let scope = ScopeSet::parse(&self.scope).map_err(|_| OAuthError::InvalidResponse)?;
        if !scope.includes_atproto() {
            return Err(OAuthError::InvalidResponse);
        }
        let expires_in = self.expires_in.unwrap_or(300);
        if expires_in == 0 || now.checked_add(expires_in).is_none() {
            return Err(OAuthError::InvalidResponse);
        }
        Ok(Session::new(
            did,
            self.access_token.clone(),
            self.refresh_token
                .clone()
                .or_else(|| old_refresh.map(str::to_owned)),
            now,
            expires_in,
            &scope,
        ))
    }
}

impl Drop for TokenResponse {
    fn drop(&mut self) {
        self.access_token.zeroize();
        self.refresh_token.zeroize();
    }
}

pub(super) fn valid_access_token(token: &str) -> bool {
    let base = token.trim_end_matches('=');
    !base.is_empty()
        && base.bytes().all(|byte| {
            byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'.' | b'_' | b'~' | b'+' | b'/')
        })
}
