use std::collections::HashMap;
use std::sync::Arc;

use async_lock::Mutex;
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};

use crate::dpop::OAuthDpopReplayChecker;
use crate::error::OAuthServerError;
use crate::support::{ConstantTime, OAuthPkce};

/// Whether a grant is bound directly to a DID or to an explicit device-scoped sub-account.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum OAuthGrantBinding {
    /// Standard AT Protocol user session identified by `did`.
    Subject { did: String },
    /// Account-bound grant identified by `(device_id, account_id, did)`.
    DeviceAccount {
        device_id: String,
        account_id: String,
        did: String,
    },
}

impl OAuthGrantBinding {
    /// Subject DID for either binding variant.
    pub fn did(&self) -> &str {
        match self {
            Self::Subject { did } | Self::DeviceAccount { did, .. } => did,
        }
    }
}

/// RFC 9207 / OAuth 2.1 authorization response delivery mode.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum OAuthResponseMode {
    #[default]
    Query,
    Fragment,
}

impl OAuthResponseMode {
    /// Wire parameter spelling (`"query"` or `"fragment"`).
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Query => "query",
            Self::Fragment => "fragment",
        }
    }

    /// Parses a `response_mode` parameter.
    pub fn parse(value: &str) -> Result<Self, OAuthServerError> {
        match value {
            "query" => Ok(Self::Query),
            "fragment" => Ok(Self::Fragment),
            _ => Err(OAuthServerError::Malformed(format!(
                "unsupported response_mode: {value}"
            ))),
        }
    }
}

/// Stored record for a Pushed Authorization Request (PAR, RFC 9126).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthPushedAuthorizationRequest {
    pub request_uri_digest: Vec<u8>,
    pub client_id: String,
    pub redirect_uri: String,
    pub scope: String,
    pub code_challenge: String,
    pub state: Option<String>,
    pub response_mode: OAuthResponseMode,
    pub dpop_jkt: Option<String>,
    pub login_hint: Option<String>,
    pub created_at_secs: i64,
    pub expires_at_secs: i64,
}

/// Pending CSRF-protected interactive browser consent state after `/oauth/authorize` GET.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthBrowserFlowRecord {
    pub flow_id_digest: Vec<u8>,
    pub csrf_token_digest: Vec<u8>,
    pub client_id: String,
    pub redirect_uri: String,
    pub scope: String,
    pub code_challenge: String,
    pub state: Option<String>,
    pub response_mode: OAuthResponseMode,
    pub dpop_jkt: Option<String>,
    pub login_hint: Option<String>,
    pub expires_at_secs: i64,
}

/// Single-use authorization code issued after user authentication/consent.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthAuthorizationCode {
    pub code_digest: Vec<u8>,
    pub client_id: String,
    pub redirect_uri: String,
    pub scope: String,
    pub code_challenge: String,
    pub dpop_jkt: Option<String>,
    pub binding: OAuthGrantBinding,
    pub session_id: String,
    pub created_at_secs: i64,
    pub expires_at_secs: i64,
}

/// Keyed digests for newly issued or rotated token pairs.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthIssuedTokenDigests {
    pub access_token_digest: Vec<u8>,
    pub refresh_token_digest: Vec<u8>,
    pub refresh_token_generation: u64,
}

/// Persisted OAuth 2.1 grant session with refresh-token rotation tracking.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthSession {
    pub session_id: String,
    pub client_id: String,
    pub scope: String,
    pub dpop_jkt: Option<String>,
    pub binding: OAuthGrantBinding,
    pub access_token_digest: Vec<u8>,
    pub refresh_token_digest: Option<Vec<u8>>,
    pub previous_refresh_token_digest: Option<Vec<u8>>,
    pub refresh_token_generation: u64,
    pub access_token_expires_at_secs: i64,
    pub created_at_secs: i64,
    pub expires_at_secs: i64,
    /// Optional absolute session expiration from `created_at_secs` (never extended by refresh rotation).
    pub hard_expires_at_secs: Option<i64>,
    pub revoked_at_secs: Option<i64>,
}

impl OAuthSession {
    /// True if the session has not been revoked and has not reached `expires_at_secs` or `hard_expires_at_secs`.
    pub fn is_active_at(&self, now_secs: i64) -> bool {
        self.revoked_at_secs.is_none()
            && now_secs < self.expires_at_secs
            && self.hard_expires_at_secs.is_none_or(|hard| now_secs < hard)
    }

    /// True if the current access token digest matches and is still valid at `now_secs`.
    pub fn is_access_token_active_at(&self, now_secs: i64) -> bool {
        self.is_active_at(now_secs) && now_secs < self.access_token_expires_at_secs
    }
}

/// Result of an atomic refresh-token rotation check and update.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum OAuthRefreshRotationResult {
    /// Refresh succeeded and updated session (plus optional atomically minted JWT access token) is returned.
    Rotated {
        session: Box<OAuthSession>,
        issued_access_token: Option<String>,
    },
    /// A previously rotated refresh token was replayed; the entire session has been revoked.
    ReplayDetected,
    /// No session matched the presented refresh token digest.
    NotFound,
    /// Session belongs to a different `client_id`.
    ClientMismatch,
    /// Session was already revoked.
    Revoked,
    /// Session expired.
    Expired,
}

/// Replay protection namespace preventing cross-domain collisions.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum OAuthReplayNamespace {
    DpopProof,
    ClientAssertion,
    ServiceAuth,
}

/// Cached client metadata entry supporting RFC 9111 / stale-while-revalidate semantics.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthCachedClientMetadata {
    pub client_id: String,
    pub raw_json: Vec<u8>,
    pub fetched_at_secs: i64,
    pub expires_at_secs: i64,
    pub stale_until_secs: i64,
    pub etag: Option<String>,
}

/// Device-scoped account record stored for `create_or_get_device_account` flows.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthDeviceAccount {
    pub device_id: String,
    pub account_id: String,
    pub did: String,
    pub created_at_secs: i64,
}

/// Cached resolved lexicon permission-set document.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthCachedLexicon {
    pub nsid: String,
    pub source_did: Option<String>,
    pub raw_json: Vec<u8>,
    pub cid: Option<String>,
    pub fetched_at_secs: i64,
    pub expires_at_secs: i64,
    pub stale_until_secs: i64,
}

/// Storage for Pushed Authorization Requests (`urn:ietf:params:oauth:request_uri:...`).
pub trait OAuthRequestStore: MaybeSend + MaybeSync {
    fn store_pushed_request(
        &self,
        record: OAuthPushedAuthorizationRequest,
    ) -> BoxFuture<'_, Result<(), OAuthServerError>>;

    fn consume_pushed_request(
        &self,
        request_uri_digest: &[u8],
        now_secs: i64,
    ) -> BoxFuture<'_, Result<Option<OAuthPushedAuthorizationRequest>, OAuthServerError>>;
}

/// Storage for interactive CSRF-protected authorization browser sessions.
pub trait OAuthBrowserSessionStore: MaybeSend + MaybeSync {
    fn store_browser_flow(
        &self,
        record: OAuthBrowserFlowRecord,
    ) -> BoxFuture<'_, Result<(), OAuthServerError>>;

    fn consume_browser_flow(
        &self,
        flow_id_digest: &[u8],
        now_secs: i64,
    ) -> BoxFuture<'_, Result<Option<OAuthBrowserFlowRecord>, OAuthServerError>>;
}

/// Outcome of consuming a single-use authorization code.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum OAuthCodeConsumeResult {
    /// First redemption of an active authorization code.
    Consumed(Box<OAuthAuthorizationCode>),
    /// Code was already consumed previously with matching bindings; the store revoked its bound session.
    Replayed,
    /// Presented `client_id`, `redirect_uri`, `dpop_jkt`, or PKCE verifier did not match the code.
    BindingMismatch,
    /// Code was unknown or already expired before redemption.
    NotFound,
}

/// Bindings validated atomically before consuming or marking an authorization code spent.
#[derive(Debug, Clone, Copy)]
pub struct ConsumeAuthorizationCodeParams<'a> {
    pub code_digest: &'a [u8],
    pub client_id: &'a str,
    pub redirect_uri: &'a str,
    pub dpop_jkt: &'a str,
    pub code_verifier: &'a str,
    pub now_secs: i64,
}

/// Single-use authorization code store.
pub trait OAuthCodeStore: MaybeSend + MaybeSync {
    fn store_authorization_code(
        &self,
        record: OAuthAuthorizationCode,
    ) -> BoxFuture<'_, Result<(), OAuthServerError>>;

    fn consume_authorization_code<'a>(
        &'a self,
        params: ConsumeAuthorizationCodeParams<'a>,
    ) -> BoxFuture<'a, Result<OAuthCodeConsumeResult, OAuthServerError>>;
}

/// Access token and digest minted atomically inside refresh rotation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthMintedAccessToken {
    pub token: String,
    pub digest: Vec<u8>,
}

/// Callback minting a session-bound access token inside [`OAuthTokenStore::rotate_refresh_token`].
pub trait OAuthAccessTokenMinting: MaybeSend + MaybeSync {
    fn mint_access_token_for_rotation(
        &self,
        session: &OAuthSession,
    ) -> Result<OAuthMintedAccessToken, OAuthServerError>;
}

/// Parameters for rotating a refresh token atomically.
#[derive(Clone)]
pub struct RotateRefreshTokenParams<'a> {
    pub presented_refresh_digest: &'a [u8],
    pub client_id: &'a str,
    pub dpop_jkt: &'a str,
    pub next_access_digest: Vec<u8>,
    pub next_refresh_digest: Vec<u8>,
    pub next_access_expires_at_secs: i64,
    pub next_session_expires_at_secs: i64,
    pub now_secs: i64,
    /// Optional atomic access-token minter (used for `at+jwt` tokens binding session claims).
    pub access_token_minter: Option<&'a dyn OAuthAccessTokenMinting>,
}

impl std::fmt::Debug for RotateRefreshTokenParams<'_> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("RotateRefreshTokenParams")
            .field("client_id", &self.client_id)
            .field("now_secs", &self.now_secs)
            .field("has_minter", &self.access_token_minter.is_some())
            .finish_non_exhaustive()
    }
}

/// Storage for active OAuth sessions, refresh rotation, and token revocation.
pub trait OAuthTokenStore: MaybeSend + MaybeSync {
    fn store_session(&self, session: OAuthSession) -> BoxFuture<'_, Result<(), OAuthServerError>>;

    fn lookup_by_access_token_digest(
        &self,
        digest: &[u8],
    ) -> BoxFuture<'_, Result<Option<OAuthSession>, OAuthServerError>>;

    fn lookup_session(
        &self,
        session_id: &str,
    ) -> BoxFuture<'_, Result<Option<OAuthSession>, OAuthServerError>>;

    /// Looks up the owning session for an active access token, active refresh token, or retired
    /// refresh token digest without mutating state.
    fn lookup_by_token_digest(
        &self,
        token_digest: &[u8],
    ) -> BoxFuture<'_, Result<Option<OAuthSession>, OAuthServerError>>;

    fn rotate_refresh_token<'a>(
        &'a self,
        params: RotateRefreshTokenParams<'a>,
    ) -> BoxFuture<'a, Result<OAuthRefreshRotationResult, OAuthServerError>>;

    fn revoke_session(
        &self,
        session_id: &str,
        revoked_at_secs: i64,
    ) -> BoxFuture<'_, Result<bool, OAuthServerError>>;

    fn revoke_by_token_digest(
        &self,
        token_digest: &[u8],
        revoked_at_secs: i64,
    ) -> BoxFuture<'_, Result<bool, OAuthServerError>>;
}

/// Replay prevention store keyed by namespace + digest.
pub trait OAuthReplayStore: MaybeSend + MaybeSync {
    fn record_if_fresh(
        &self,
        namespace: OAuthReplayNamespace,
        digest: Vec<u8>,
        expires_at_secs: i64,
        now_secs: i64,
    ) -> BoxFuture<'_, Result<bool, OAuthServerError>>;
}

/// Adapter exposing any [`OAuthReplayStore`] as an [`OAuthDpopReplayChecker`].
pub struct ReplayStoreDpopChecker {
    store: Arc<dyn OAuthReplayStore>,
    clock: Arc<dyn crate::support::OAuthClock>,
}

impl std::fmt::Debug for ReplayStoreDpopChecker {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ReplayStoreDpopChecker")
            .finish_non_exhaustive()
    }
}

impl ReplayStoreDpopChecker {
    /// Creates a DPoP replay checker backed by `store` and `clock`.
    pub fn new(
        store: Arc<dyn OAuthReplayStore>,
        clock: Arc<dyn crate::support::OAuthClock>,
    ) -> Self {
        Self { store, clock }
    }
}

impl OAuthDpopReplayChecker for ReplayStoreDpopChecker {
    fn record_if_fresh(
        &self,
        digest: Vec<u8>,
        expires_at_secs: i64,
    ) -> BoxFuture<'_, Result<bool, OAuthServerError>> {
        let now_secs = self.clock.now_secs();
        self.store.record_if_fresh(
            OAuthReplayNamespace::DpopProof,
            digest,
            expires_at_secs,
            now_secs,
        )
    }
}

/// Cache for remote OAuth client metadata documents.
pub trait OAuthClientMetadataCache: MaybeSend + MaybeSync {
    fn get_cached_metadata(
        &self,
        client_id: &str,
    ) -> BoxFuture<'_, Result<Option<OAuthCachedClientMetadata>, OAuthServerError>>;

    fn put_cached_metadata(
        &self,
        entry: OAuthCachedClientMetadata,
    ) -> BoxFuture<'_, Result<(), OAuthServerError>>;
}

/// Store for per-device sub-accounts used when multi-account / device isolation is active.
pub trait OAuthDeviceAccountStore: MaybeSend + MaybeSync {
    fn create_or_get_device_account(
        &self,
        device_id: String,
        account_id: String,
        did: String,
        now_secs: i64,
    ) -> BoxFuture<'_, Result<OAuthDeviceAccount, OAuthServerError>>;

    fn lookup_device_account(
        &self,
        device_id: &str,
        account_id: &str,
    ) -> BoxFuture<'_, Result<Option<OAuthDeviceAccount>, OAuthServerError>>;
}

/// Cache for resolved lexicon permission-set documents.
pub trait OAuthLexiconCache: MaybeSend + MaybeSync {
    fn get_cached_lexicon(
        &self,
        nsid: &str,
    ) -> BoxFuture<'_, Result<Option<OAuthCachedLexicon>, OAuthServerError>>;

    fn put_cached_lexicon(
        &self,
        entry: OAuthCachedLexicon,
    ) -> BoxFuture<'_, Result<(), OAuthServerError>>;
}

/// Opportunistic garbage collection for expired entries.
pub trait OAuthStorePurging: MaybeSend + MaybeSync {
    fn purge_expired(&self, now_secs: i64) -> BoxFuture<'_, Result<usize, OAuthServerError>>;
}

/// Bundled trait objects required by [`crate::oauth::OAuthAuthorizationServer`].
#[derive(Clone)]
pub struct OAuthServerStores {
    pub requests: Arc<dyn OAuthRequestStore>,
    pub browser_flows: Arc<dyn OAuthBrowserSessionStore>,
    pub codes: Arc<dyn OAuthCodeStore>,
    pub tokens: Arc<dyn OAuthTokenStore>,
    pub replay: Arc<dyn OAuthReplayStore>,
    pub purging: Option<Arc<dyn OAuthStorePurging>>,
}

impl std::fmt::Debug for OAuthServerStores {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("OAuthServerStores").finish_non_exhaustive()
    }
}

impl OAuthServerStores {
    /// Builds an `OAuthServerStores` from a single store implementing all server store traits (such as [`InMemoryOAuthStore`]).
    pub fn from_unified<S>(store: Arc<S>) -> Self
    where
        S: OAuthRequestStore
            + OAuthBrowserSessionStore
            + OAuthCodeStore
            + OAuthTokenStore
            + OAuthReplayStore
            + OAuthStorePurging
            + 'static,
    {
        Self {
            requests: store.clone(),
            browser_flows: store.clone(),
            codes: store.clone(),
            tokens: store.clone(),
            replay: store.clone(),
            purging: Some(store),
        }
    }
}

#[derive(Default)]
struct InMemoryState {
    requests: HashMap<Vec<u8>, OAuthPushedAuthorizationRequest>,
    browser_flows: HashMap<Vec<u8>, OAuthBrowserFlowRecord>,
    codes: HashMap<Vec<u8>, OAuthAuthorizationCode>,
    spent_codes: HashMap<Vec<u8>, OAuthAuthorizationCode>,
    spent_codes_by_session: HashMap<String, Vec<Vec<u8>>>,
    pending_session_revocations: HashMap<String, (i64, i64)>,
    sessions: HashMap<String, OAuthSession>,
    access_index: HashMap<Vec<u8>, String>,
    refresh_index: HashMap<Vec<u8>, String>,
    prev_refresh_index: HashMap<Vec<u8>, String>,
    spent_refresh_by_session: HashMap<String, Vec<Vec<u8>>>,
    replay: HashMap<(OAuthReplayNamespace, Vec<u8>), i64>,
    client_metadata: HashMap<String, OAuthCachedClientMetadata>,
    device_accounts: HashMap<(String, String), OAuthDeviceAccount>,
    lexicons: HashMap<String, OAuthCachedLexicon>,
}

/// Async-safe in-memory implementation of all `petrel-server` store and cache traits (suitable for tests, dev, and wasm32).
#[derive(Default)]
pub struct InMemoryOAuthStore {
    state: Mutex<InMemoryState>,
}

impl std::fmt::Debug for InMemoryOAuthStore {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("InMemoryOAuthStore").finish_non_exhaustive()
    }
}

impl InMemoryOAuthStore {
    /// Creates an empty in-memory store.
    pub fn new() -> Self {
        Self::default()
    }

    /// Returns a snapshot of all currently stored sessions (for tests and inspection).
    pub async fn snapshot_sessions(&self) -> Vec<OAuthSession> {
        self.state.lock().await.sessions.values().cloned().collect()
    }
}

impl OAuthRequestStore for InMemoryOAuthStore {
    fn store_pushed_request(
        &self,
        record: OAuthPushedAuthorizationRequest,
    ) -> BoxFuture<'_, Result<(), OAuthServerError>> {
        Box::pin(async move {
            let mut st = self.state.lock().await;
            st.requests
                .insert(record.request_uri_digest.clone(), record);
            Ok(())
        })
    }

    fn consume_pushed_request(
        &self,
        request_uri_digest: &[u8],
        now_secs: i64,
    ) -> BoxFuture<'_, Result<Option<OAuthPushedAuthorizationRequest>, OAuthServerError>> {
        let digest = request_uri_digest.to_vec();
        Box::pin(async move {
            let mut st = self.state.lock().await;
            let Some(rec) = st.requests.remove(&digest) else {
                return Ok(None);
            };
            if now_secs >= rec.expires_at_secs {
                return Ok(None);
            }
            Ok(Some(rec))
        })
    }
}

impl OAuthBrowserSessionStore for InMemoryOAuthStore {
    fn store_browser_flow(
        &self,
        record: OAuthBrowserFlowRecord,
    ) -> BoxFuture<'_, Result<(), OAuthServerError>> {
        Box::pin(async move {
            let mut st = self.state.lock().await;
            st.browser_flows
                .insert(record.flow_id_digest.clone(), record);
            Ok(())
        })
    }

    fn consume_browser_flow(
        &self,
        flow_id_digest: &[u8],
        now_secs: i64,
    ) -> BoxFuture<'_, Result<Option<OAuthBrowserFlowRecord>, OAuthServerError>> {
        let digest = flow_id_digest.to_vec();
        Box::pin(async move {
            let mut st = self.state.lock().await;
            let Some(rec) = st.browser_flows.remove(&digest) else {
                return Ok(None);
            };
            if now_secs >= rec.expires_at_secs {
                return Ok(None);
            }
            Ok(Some(rec))
        })
    }
}

impl OAuthCodeStore for InMemoryOAuthStore {
    fn store_authorization_code(
        &self,
        record: OAuthAuthorizationCode,
    ) -> BoxFuture<'_, Result<(), OAuthServerError>> {
        Box::pin(async move {
            let mut st = self.state.lock().await;
            st.codes.insert(record.code_digest.clone(), record);
            Ok(())
        })
    }

    fn consume_authorization_code<'a>(
        &'a self,
        params: ConsumeAuthorizationCodeParams<'a>,
    ) -> BoxFuture<'a, Result<OAuthCodeConsumeResult, OAuthServerError>> {
        Box::pin(async move {
            let mut st = self.state.lock().await;
            if let Some(spent_rec) = st.spent_codes.get(params.code_digest).cloned() {
                if !authorization_code_bindings_match(&spent_rec, &params) {
                    return Ok(OAuthCodeConsumeResult::BindingMismatch);
                }
                if let Some(session) = st.sessions.get_mut(&spent_rec.session_id) {
                    session.revoked_at_secs.get_or_insert(params.now_secs);
                } else {
                    let cleanup_at = params
                        .now_secs
                        .saturating_add(3600)
                        .max(spent_rec.expires_at_secs);
                    st.pending_session_revocations
                        .entry(spent_rec.session_id.clone())
                        .or_insert((params.now_secs, cleanup_at));
                }
                return Ok(OAuthCodeConsumeResult::Replayed);
            }
            let Some(rec) = st.codes.get(params.code_digest).cloned() else {
                return Ok(OAuthCodeConsumeResult::NotFound);
            };
            if params.now_secs >= rec.expires_at_secs {
                st.codes.remove(params.code_digest);
                return Ok(OAuthCodeConsumeResult::NotFound);
            }
            if !authorization_code_bindings_match(&rec, &params) {
                return Ok(OAuthCodeConsumeResult::BindingMismatch);
            }
            st.codes.remove(params.code_digest);
            let digest = params.code_digest.to_vec();
            st.spent_codes.insert(digest.clone(), rec.clone());
            st.spent_codes_by_session
                .entry(rec.session_id.clone())
                .or_default()
                .push(digest);
            Ok(OAuthCodeConsumeResult::Consumed(Box::new(rec)))
        })
    }
}

fn authorization_code_bindings_match(
    record: &OAuthAuthorizationCode,
    params: &ConsumeAuthorizationCodeParams<'_>,
) -> bool {
    ConstantTime::equal(&record.client_id, params.client_id)
        && ConstantTime::equal(&record.redirect_uri, params.redirect_uri)
        && record
            .dpop_jkt
            .as_deref()
            .is_none_or(|bound| ConstantTime::equal(bound, params.dpop_jkt))
        && OAuthPkce::verify_s256(params.code_verifier, &record.code_challenge)
}

impl OAuthTokenStore for InMemoryOAuthStore {
    fn store_session(
        &self,
        mut session: OAuthSession,
    ) -> BoxFuture<'_, Result<(), OAuthServerError>> {
        Box::pin(async move {
            let mut st = self.state.lock().await;
            let pending_revocation = st.pending_session_revocations.remove(&session.session_id);
            if let Some((revoked_at, _)) = pending_revocation {
                session.revoked_at_secs.get_or_insert(revoked_at);
            }
            st.access_index.insert(
                session.access_token_digest.clone(),
                session.session_id.clone(),
            );
            if let Some(ref rt) = session.refresh_token_digest {
                st.refresh_index
                    .insert(rt.clone(), session.session_id.clone());
            }
            if let Some(ref prev) = session.previous_refresh_token_digest {
                st.prev_refresh_index
                    .insert(prev.clone(), session.session_id.clone());
                st.spent_refresh_by_session
                    .entry(session.session_id.clone())
                    .or_default()
                    .push(prev.clone());
            }
            st.sessions.insert(session.session_id.clone(), session);
            if pending_revocation.is_some() {
                return Err(OAuthServerError::Unauthorized(
                    "authorization code was already used; the session has been revoked".into(),
                ));
            }
            Ok(())
        })
    }

    fn lookup_by_access_token_digest(
        &self,
        digest: &[u8],
    ) -> BoxFuture<'_, Result<Option<OAuthSession>, OAuthServerError>> {
        let digest = digest.to_vec();
        Box::pin(async move {
            let st = self.state.lock().await;
            let Some(id) = st.access_index.get(&digest) else {
                return Ok(None);
            };
            Ok(st.sessions.get(id).cloned())
        })
    }

    fn lookup_session(
        &self,
        session_id: &str,
    ) -> BoxFuture<'_, Result<Option<OAuthSession>, OAuthServerError>> {
        let id = session_id.to_owned();
        Box::pin(async move {
            let st = self.state.lock().await;
            Ok(st.sessions.get(&id).cloned())
        })
    }

    fn lookup_by_token_digest(
        &self,
        token_digest: &[u8],
    ) -> BoxFuture<'_, Result<Option<OAuthSession>, OAuthServerError>> {
        let digest = token_digest.to_vec();
        Box::pin(async move {
            let st = self.state.lock().await;
            let target_id = st
                .access_index
                .get(&digest)
                .or_else(|| st.refresh_index.get(&digest))
                .or_else(|| st.prev_refresh_index.get(&digest));
            Ok(target_id.and_then(|id| st.sessions.get(id).cloned()))
        })
    }

    fn rotate_refresh_token<'a>(
        &'a self,
        params: RotateRefreshTokenParams<'a>,
    ) -> BoxFuture<'a, Result<OAuthRefreshRotationResult, OAuthServerError>> {
        Box::pin(async move {
            let mut st = self.state.lock().await;
            if let Some(replayed_session_id) = st
                .prev_refresh_index
                .get(params.presented_refresh_digest)
                .cloned()
            {
                let Some(session) = st.sessions.get_mut(&replayed_session_id) else {
                    return Ok(OAuthRefreshRotationResult::NotFound);
                };
                if !ConstantTime::equal(&session.client_id, params.client_id) {
                    return Ok(OAuthRefreshRotationResult::ClientMismatch);
                }
                if let Some(ref bound_jkt) = session.dpop_jkt
                    && !ConstantTime::equal(bound_jkt, params.dpop_jkt)
                {
                    return Ok(OAuthRefreshRotationResult::ClientMismatch);
                }
                session.revoked_at_secs.get_or_insert(params.now_secs);
                return Ok(OAuthRefreshRotationResult::ReplayDetected);
            }

            let Some(session_id) = st
                .refresh_index
                .get(params.presented_refresh_digest)
                .cloned()
            else {
                return Ok(OAuthRefreshRotationResult::NotFound);
            };

            let Some(session) = st.sessions.get(&session_id).cloned() else {
                return Ok(OAuthRefreshRotationResult::NotFound);
            };

            if !ConstantTime::equal(&session.client_id, params.client_id) {
                return Ok(OAuthRefreshRotationResult::ClientMismatch);
            }
            if let Some(ref bound_jkt) = session.dpop_jkt
                && !ConstantTime::equal(bound_jkt, params.dpop_jkt)
            {
                return Ok(OAuthRefreshRotationResult::ClientMismatch);
            }
            if session.revoked_at_secs.is_some() {
                return Ok(OAuthRefreshRotationResult::Revoked);
            }
            if params.now_secs >= session.expires_at_secs
                || session
                    .hard_expires_at_secs
                    .is_some_and(|hard| params.now_secs >= hard)
            {
                return Ok(OAuthRefreshRotationResult::Expired);
            }

            let mut updated = session.clone();
            let previous_digest = updated.refresh_token_digest.clone();
            updated
                .previous_refresh_token_digest
                .clone_from(&previous_digest);
            updated.refresh_token_digest = Some(params.next_refresh_digest.clone());
            updated.refresh_token_generation = updated.refresh_token_generation.saturating_add(1);
            updated.expires_at_secs = session
                .hard_expires_at_secs
                .map_or(params.next_session_expires_at_secs, |hard| {
                    params.next_session_expires_at_secs.min(hard)
                });
            updated.access_token_expires_at_secs = params
                .next_access_expires_at_secs
                .min(updated.expires_at_secs);

            let issued_access_token = if let Some(minter) = params.access_token_minter {
                let minted = minter.mint_access_token_for_rotation(&updated)?;
                updated.access_token_digest = minted.digest;
                Some(minted.token)
            } else {
                updated.access_token_digest = params.next_access_digest;
                None
            };

            st.access_index.remove(&session.access_token_digest);
            if let Some(ref old_rt) = session.refresh_token_digest {
                st.refresh_index.remove(old_rt);
            }

            if let Some(prev) = previous_digest {
                st.prev_refresh_index
                    .insert(prev.clone(), session_id.clone());
                st.spent_refresh_by_session
                    .entry(session_id.clone())
                    .or_default()
                    .push(prev);
            }
            st.access_index
                .insert(updated.access_token_digest.clone(), session_id.clone());
            st.refresh_index
                .insert(params.next_refresh_digest, session_id.clone());
            st.sessions.insert(session_id, updated.clone());

            Ok(OAuthRefreshRotationResult::Rotated {
                session: Box::new(updated),
                issued_access_token,
            })
        })
    }

    fn revoke_session(
        &self,
        session_id: &str,
        revoked_at_secs: i64,
    ) -> BoxFuture<'_, Result<bool, OAuthServerError>> {
        let id = session_id.to_owned();
        Box::pin(async move {
            let mut st = self.state.lock().await;
            if let Some(session) = st.sessions.get_mut(&id) {
                session.revoked_at_secs.get_or_insert(revoked_at_secs);
                return Ok(true);
            }
            Ok(false)
        })
    }

    fn revoke_by_token_digest(
        &self,
        token_digest: &[u8],
        revoked_at_secs: i64,
    ) -> BoxFuture<'_, Result<bool, OAuthServerError>> {
        let digest = token_digest.to_vec();
        Box::pin(async move {
            let mut st = self.state.lock().await;
            let target_id = st
                .access_index
                .get(&digest)
                .or_else(|| st.refresh_index.get(&digest))
                .or_else(|| st.prev_refresh_index.get(&digest))
                .cloned();
            if let Some(id) = target_id
                && let Some(session) = st.sessions.get_mut(&id)
            {
                session.revoked_at_secs.get_or_insert(revoked_at_secs);
                return Ok(true);
            }
            Ok(false)
        })
    }
}

impl OAuthReplayStore for InMemoryOAuthStore {
    fn record_if_fresh(
        &self,
        namespace: OAuthReplayNamespace,
        digest: Vec<u8>,
        expires_at_secs: i64,
        now_secs: i64,
    ) -> BoxFuture<'_, Result<bool, OAuthServerError>> {
        Box::pin(async move {
            let mut st = self.state.lock().await;
            let key = (namespace, digest);
            if let Some(&existing_exp) = st.replay.get(&key)
                && now_secs < existing_exp
            {
                return Ok(false);
            }
            st.replay.insert(key, expires_at_secs);
            Ok(true)
        })
    }
}

impl OAuthClientMetadataCache for InMemoryOAuthStore {
    fn get_cached_metadata(
        &self,
        client_id: &str,
    ) -> BoxFuture<'_, Result<Option<OAuthCachedClientMetadata>, OAuthServerError>> {
        let id = client_id.to_owned();
        Box::pin(async move { Ok(self.state.lock().await.client_metadata.get(&id).cloned()) })
    }

    fn put_cached_metadata(
        &self,
        entry: OAuthCachedClientMetadata,
    ) -> BoxFuture<'_, Result<(), OAuthServerError>> {
        const MAX_CLIENT_METADATA_ENTRIES: usize = 4096;
        Box::pin(async move {
            let mut st = self.state.lock().await;
            if !st.client_metadata.contains_key(&entry.client_id)
                && st.client_metadata.len() >= MAX_CLIENT_METADATA_ENTRIES
            {
                let cutoff = entry.fetched_at_secs;
                st.client_metadata
                    .retain(|_, v| cutoff < v.stale_until_secs.max(v.expires_at_secs));
                if st.client_metadata.len() >= MAX_CLIENT_METADATA_ENTRIES
                    && let Some(oldest_key) = st
                        .client_metadata
                        .iter()
                        .min_by_key(|(_, v)| v.fetched_at_secs)
                        .map(|(k, _)| k.clone())
                {
                    st.client_metadata.remove(&oldest_key);
                }
            }
            st.client_metadata.insert(entry.client_id.clone(), entry);
            Ok(())
        })
    }
}

impl OAuthDeviceAccountStore for InMemoryOAuthStore {
    fn create_or_get_device_account(
        &self,
        device_id: String,
        account_id: String,
        did: String,
        now_secs: i64,
    ) -> BoxFuture<'_, Result<OAuthDeviceAccount, OAuthServerError>> {
        Box::pin(async move {
            let mut st = self.state.lock().await;
            let key = (device_id.clone(), account_id.clone());
            if let Some(existing) = st.device_accounts.get(&key) {
                return Ok(existing.clone());
            }
            let created = OAuthDeviceAccount {
                device_id,
                account_id,
                did,
                created_at_secs: now_secs,
            };
            st.device_accounts.insert(key, created.clone());
            Ok(created)
        })
    }

    fn lookup_device_account(
        &self,
        device_id: &str,
        account_id: &str,
    ) -> BoxFuture<'_, Result<Option<OAuthDeviceAccount>, OAuthServerError>> {
        let key = (device_id.to_owned(), account_id.to_owned());
        Box::pin(async move { Ok(self.state.lock().await.device_accounts.get(&key).cloned()) })
    }
}

impl OAuthLexiconCache for InMemoryOAuthStore {
    fn get_cached_lexicon(
        &self,
        nsid: &str,
    ) -> BoxFuture<'_, Result<Option<OAuthCachedLexicon>, OAuthServerError>> {
        let key = nsid.to_owned();
        Box::pin(async move { Ok(self.state.lock().await.lexicons.get(&key).cloned()) })
    }

    fn put_cached_lexicon(
        &self,
        entry: OAuthCachedLexicon,
    ) -> BoxFuture<'_, Result<(), OAuthServerError>> {
        Box::pin(async move {
            self.state
                .lock()
                .await
                .lexicons
                .insert(entry.nsid.clone(), entry);
            Ok(())
        })
    }
}

impl OAuthStorePurging for InMemoryOAuthStore {
    fn purge_expired(&self, now_secs: i64) -> BoxFuture<'_, Result<usize, OAuthServerError>> {
        Box::pin(async move {
            let mut st = self.state.lock().await;
            let before = st.requests.len()
                + st.browser_flows.len()
                + st.codes.len()
                + st.replay.len()
                + st.client_metadata.len();

            st.requests.retain(|_, v| now_secs < v.expires_at_secs);
            st.browser_flows.retain(|_, v| now_secs < v.expires_at_secs);
            st.codes.retain(|_, v| now_secs < v.expires_at_secs);
            st.replay.retain(|_, exp| now_secs < *exp);
            st.pending_session_revocations
                .retain(|_, (_, exp)| now_secs < *exp);
            st.client_metadata
                .retain(|_, v| now_secs < v.stale_until_secs.max(v.expires_at_secs));

            let expired_ids: Vec<String> = st
                .sessions
                .iter()
                .filter(|(_, s)| {
                    now_secs >= s.expires_at_secs
                        || s.hard_expires_at_secs.is_some_and(|hard| now_secs >= hard)
                })
                .map(|(id, _)| id.clone())
                .collect();
            for id in &expired_ids {
                if let Some(s) = st.sessions.remove(id) {
                    st.access_index.remove(&s.access_token_digest);
                    if let Some(rt) = s.refresh_token_digest {
                        st.refresh_index.remove(&rt);
                    }
                    if let Some(prev) = s.previous_refresh_token_digest {
                        st.prev_refresh_index.remove(&prev);
                    }
                }
                if let Some(spent) = st.spent_refresh_by_session.remove(id) {
                    for digest in spent {
                        st.prev_refresh_index.remove(&digest);
                    }
                }
                if let Some(code_digests) = st.spent_codes_by_session.remove(id) {
                    for code_digest in code_digests {
                        st.spent_codes.remove(&code_digest);
                    }
                }
            }

            let after = st.requests.len()
                + st.browser_flows.len()
                + st.codes.len()
                + st.replay.len()
                + st.client_metadata.len();
            Ok(before.saturating_sub(after) + expired_ids.len())
        })
    }
}
