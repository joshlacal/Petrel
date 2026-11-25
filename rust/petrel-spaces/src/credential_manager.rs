//! `SpaceCredentialManager`, single-flight credential exchange, generation-safe invalidation,
//! and authenticated HTTP space transport helpers.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use async_lock::Mutex as AsyncMutex;
use bytes::Bytes;
use http::{HeaderMap, Method, Request, Response, StatusCode, header::CONTENT_TYPE};
use petrel::net::{RedirectPolicy, SendOptions, SharedTransport, send_with_redirects};
use petrel_api::generated::com::atproto::space::{
    authorize_space_sync::{
        Input as AuthorizeSpaceSyncInput, NSID as AUTHORIZE_SPACE_SYNC_NSID, Notify,
        Output as AuthorizeSpaceSyncOutput,
    },
    get_delegation_token::{NSID as GET_DELEGATION_TOKEN_NSID, Output as GetDelegationTokenOutput},
};
use petrel_core::{Did, SpaceRef, Uri};
use petrel_crypto::rt::{BoxFuture, MaybeSend, MaybeSync};
use serde::Deserialize;
use url::Url;

use crate::error::{Result, SpaceError};
use crate::http_signature::{SpaceRequestHeaders, derive_audience, sign_credential_request};
use crate::resolver::SpaceHostResolver;
use crate::star::DEFAULT_MAX_ARCHIVE_BYTES;
use crate::tokens::{SigningKeyPair, generate_jti, inspect_credential_token_unverified};

/// Default maximum space blob byte limit (50 MiB, matching `SpaceCredentialManager.swift`).
pub const DEFAULT_MAX_BLOB_BYTES: usize = 50 * 1024 * 1024;
/// Default safety margin before `expires_at` when computing `refresh_deadline` (seconds).
pub const CREDENTIAL_REFRESH_MARGIN_SECS: i64 = 30;
/// Space credential revocation wire error name.
pub const CREDENTIAL_REVOKED_ERROR_NAME: &str = "CredentialRevoked";

/// Active proof-of-possession space credential and its bound P-256 `cnf` signing keypair.
#[derive(Clone)]
pub struct SpaceCredential {
    pub jwt: String,
    pub space: SpaceRef,
    pub issuer: Did,
    pub jti: String,
    pub proof_key: SigningKeyPair,
    pub cnf_kid: String,
    pub issued_at: i64,
    pub expires_at: i64,
    pub pds_did: Option<Did>,
}

impl core::fmt::Debug for SpaceCredential {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.debug_struct("SpaceCredential")
            .field("jwt", &"[REDACTED]")
            .field("space", &self.space)
            .field("issuer", &self.issuer)
            .field("jti", &self.jti)
            .field("cnf_kid", &self.cnf_kid)
            .field("issued_at", &self.issued_at)
            .field("expires_at", &self.expires_at)
            .field("pds_did", &self.pds_did)
            .finish_non_exhaustive()
    }
}

impl SpaceCredential {
    /// Construct a [`SpaceCredential`] from a newly issued credential JWT and the proof key used to mint it.
    pub fn from_issued_jwt(
        jwt: String,
        proof_key: SigningKeyPair,
        expected_space: &SpaceRef,
        pds_did: Option<Did>,
    ) -> Result<Self> {
        let (_, claims) = inspect_credential_token_unverified(&jwt)?;
        let claimed_space = claims.space_ref()?;
        if &claimed_space != expected_space {
            return Err(SpaceError::InvalidSubject(format!(
                "credential sub '{claimed_space}' does not match '{expected_space}'"
            )));
        }
        let expected_kid = proof_key.did_key()?;
        if claims.cnf.kid != expected_kid {
            return Err(SpaceError::KeyMismatch);
        }
        let issuer = claims.issuer_did()?;
        Ok(Self {
            jwt,
            space: claimed_space,
            issuer,
            jti: claims.jti,
            proof_key,
            cnf_kid: expected_kid,
            issued_at: claims.iat,
            expires_at: claims.exp,
            pds_did,
        })
    }

    /// Recommended refresh deadline: `min(expires_at - 30, issued_at + (expires_at - issued_at) / 2)`.
    pub fn refresh_deadline(&self) -> i64 {
        let half_life = self.expires_at.saturating_sub(self.issued_at) / 2;
        let midpoint = self.issued_at.saturating_add(half_life);
        let early = self
            .expires_at
            .saturating_sub(CREDENTIAL_REFRESH_MARGIN_SECS);
        early.min(midpoint)
    }

    /// Returns `true` if `now >= expires_at`.
    pub fn is_expired(&self, now: i64) -> bool {
        now >= self.expires_at
    }

    /// Returns `true` if `now >= refresh_deadline()`.
    pub fn needs_refresh(&self, now: i64) -> bool {
        now >= self.refresh_deadline()
    }
}

/// Persistence interface for caching space credentials across invocations.
pub trait CredentialCache: MaybeSend + MaybeSync {
    fn get<'a>(&'a self, space: &'a SpaceRef) -> BoxFuture<'a, Result<Option<SpaceCredential>>>;
    fn put(&self, credential: SpaceCredential) -> BoxFuture<'_, Result<()>>;
    fn invalidate<'a>(&'a self, space: &'a SpaceRef) -> BoxFuture<'a, Result<()>>;
    fn clear(&self) -> BoxFuture<'_, Result<()>>;
}

/// In-memory [`CredentialCache`] implementation.
#[derive(Debug, Default)]
pub struct InMemoryCredentialCache {
    inner: Mutex<HashMap<SpaceRef, SpaceCredential>>,
}

impl InMemoryCredentialCache {
    pub fn new() -> Self {
        Self::default()
    }
}

impl CredentialCache for InMemoryCredentialCache {
    fn get<'a>(&'a self, space: &'a SpaceRef) -> BoxFuture<'a, Result<Option<SpaceCredential>>> {
        Box::pin(async move {
            let guard = self
                .inner
                .lock()
                .map_err(|_| SpaceError::Storage("credential cache mutex poisoned".into()))?;
            Ok(guard.get(space).cloned())
        })
    }

    fn put(&self, credential: SpaceCredential) -> BoxFuture<'_, Result<()>> {
        Box::pin(async move {
            let mut guard = self
                .inner
                .lock()
                .map_err(|_| SpaceError::Storage("credential cache mutex poisoned".into()))?;
            guard.insert(credential.space.clone(), credential);
            Ok(())
        })
    }

    fn invalidate<'a>(&'a self, space: &'a SpaceRef) -> BoxFuture<'a, Result<()>> {
        Box::pin(async move {
            let mut guard = self
                .inner
                .lock()
                .map_err(|_| SpaceError::Storage("credential cache mutex poisoned".into()))?;
            guard.remove(space);
            Ok(())
        })
    }

    fn clear(&self) -> BoxFuture<'_, Result<()>> {
        Box::pin(async move {
            let mut guard = self
                .inner
                .lock()
                .map_err(|_| SpaceError::Storage("credential cache mutex poisoned".into()))?;
            guard.clear();
            Ok(())
        })
    }
}

/// Obtains a short-lived PDS delegation token (`com.atproto.space.getDelegationToken`)
/// bound to `space` and addressed to the space's authority DID.
pub trait DelegationMinter: MaybeSend + MaybeSync {
    fn get_delegation_token<'a>(&'a self, space: &'a SpaceRef) -> BoxFuture<'a, Result<String>>;
}

/// Exchanges `(space, cnf_did_key, delegation_token)` with the space host for a credential JWT
/// (`com.atproto.space.authorizeSpaceSync`).
pub trait CredentialExchanger: MaybeSend + MaybeSync {
    fn exchange<'a>(
        &'a self,
        space: &'a SpaceRef,
        proof_key: &'a SigningKeyPair,
        now: i64,
    ) -> BoxFuture<'a, Result<SpaceCredential>>;
}

#[derive(Debug, Deserialize)]
struct XrpcErrorPayload {
    error: Option<String>,
    message: Option<String>,
}

/// Classify a failed `authorizeSpaceSync` response into a structured [`SpaceError`].
pub fn classify_authorize_space_sync_error(
    space: &SpaceRef,
    status: u16,
    body: &[u8],
) -> SpaceError {
    let parsed: Option<XrpcErrorPayload> = serde_json::from_slice(body).ok();
    let error_name = parsed.as_ref().and_then(|p| p.error.clone());
    let detail = parsed.as_ref().and_then(|p| p.message.clone());
    let space_str = space.as_str().to_owned();

    match (status, error_name.as_deref()) {
        (410, _) | (_, Some("SpaceDeleted")) => SpaceError::SpaceDeleted(space_str),
        (404, _) | (_, Some("SpaceNotFound")) => SpaceError::SpaceNotFound(space_str),
        (401, _) | (_, Some("InvalidToken" | "ExpiredToken")) => SpaceError::TokenRejected {
            space: space_str,
            detail: detail.or(error_name),
        },
        (403, _) | (_, Some("NotAuthorized" | "AuthorizationRefused")) => {
            SpaceError::AuthorizationRefused {
                space: space_str,
                detail: detail.or(error_name),
            }
        }
        (429, _) => SpaceError::TooManyRequests { retry_after: None },
        _ => SpaceError::HttpStatus {
            status,
            error: error_name,
            message: detail,
        },
    }
}

/// HTTP-backed [`CredentialExchanger`] executing `com.atproto.space.authorizeSpaceSync`
/// against the host resolved for `space.space_did()` via [`SpaceHostResolver`].
#[derive(Clone)]
pub struct HttpCredentialExchanger<M: DelegationMinter> {
    transport: SharedTransport,
    host_resolver: Arc<SpaceHostResolver>,
    delegation_minter: Arc<M>,
    notify_endpoint: Option<(Uri, String)>,
}

impl<M: DelegationMinter> core::fmt::Debug for HttpCredentialExchanger<M> {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.debug_struct("HttpCredentialExchanger")
            .field("host_resolver", &self.host_resolver)
            .field(
                "notify_endpoint",
                &self.notify_endpoint.as_ref().map(|(u, _)| u),
            )
            .finish_non_exhaustive()
    }
}

impl<M: DelegationMinter> HttpCredentialExchanger<M> {
    /// Create an HTTP credential exchanger.
    pub fn new(
        transport: SharedTransport,
        host_resolver: Arc<SpaceHostResolver>,
        delegation_minter: Arc<M>,
    ) -> Self {
        Self {
            transport,
            host_resolver,
            delegation_minter,
            notify_endpoint: None,
        }
    }

    /// Optional `notify` callback URL and token included in `authorizeSpaceSync`.
    pub fn with_notify_endpoint(mut self, endpoint: &Url, token: Option<String>) -> Result<Self> {
        let uri =
            Uri::parse(endpoint.as_str()).map_err(|e| SpaceError::InvalidUri(e.to_string()))?;
        let tok = match token {
            Some(t) => t,
            None => generate_jti()?,
        };
        self.notify_endpoint = Some((uri, tok));
        Ok(self)
    }

    /// Probe `com.atproto.server.describeServer` on `service_url` to distinguish a Space-capable
    /// host from a misconfigured or generic endpoint when diagnosing `authorizeSpaceSync` failures.
    pub async fn probe_describe_server(&self, service_url: &Url) -> Result<bool> {
        let mut url = service_url.clone();
        url.set_path("/xrpc/com.atproto.server.describeServer");
        url.set_query(None);
        let req = Request::builder()
            .method(Method::GET)
            .uri(url.as_str())
            .body(Bytes::new())
            .map_err(|e| SpaceError::Transport(e.to_string()))?;
        let resp = send_with_redirects(
            self.transport.as_ref(),
            req,
            &SendOptions::new(),
            RedirectPolicy::Never,
        )
        .await
        .map_err(|e| SpaceError::Transport(e.to_string()))?;
        Ok(resp.status().is_success())
    }
}

impl<M: DelegationMinter> CredentialExchanger for HttpCredentialExchanger<M> {
    fn exchange<'a>(
        &'a self,
        space: &'a SpaceRef,
        proof_key: &'a SigningKeyPair,
        _now: i64,
    ) -> BoxFuture<'a, Result<SpaceCredential>> {
        Box::pin(async move {
            let space_did = space.space_did().clone();
            let endpoints = self
                .host_resolver
                .resolve_authority_endpoints(&space_did, false)
                .await?;
            let delegation = self.delegation_minter.get_delegation_token(space).await?;
            let cred_key = proof_key.did_key()?;

            let mut url = endpoints.service_url.clone();
            url.set_path(&format!("/xrpc/{AUTHORIZE_SPACE_SYNC_NSID}"));
            url.set_query(None);

            let mut input = AuthorizeSpaceSyncInput::new(space.clone(), cred_key);
            input.delegation_token = Some(delegation);
            input.notify = self
                .notify_endpoint
                .as_ref()
                .map(|(u, tok)| Notify::new(u.clone(), tok.clone()));

            let body = serde_json::to_vec(&input)
                .map_err(|e| SpaceError::MalformedPayload(e.to_string()))?;

            let req = Request::builder()
                .method(Method::POST)
                .uri(url.as_str())
                .header(CONTENT_TYPE, "application/json")
                .body(Bytes::from(body))
                .map_err(|e| SpaceError::Transport(e.to_string()))?;

            let resp = send_with_redirects(
                self.transport.as_ref(),
                req,
                &SendOptions::new(),
                RedirectPolicy::Never,
            )
            .await
            .map_err(|e| SpaceError::Transport(e.to_string()))?;

            let status = resp.status().as_u16();
            if !(200..300).contains(&status) {
                return Err(classify_authorize_space_sync_error(
                    space,
                    status,
                    resp.body(),
                ));
            }
            let output: AuthorizeSpaceSyncOutput = serde_json::from_slice(resp.body())
                .map_err(|e| SpaceError::MalformedPayload(e.to_string()))?;

            SpaceCredential::from_issued_jwt(output.credential, proof_key.clone(), space, None)
        })
    }
}

/// Fetches a delegation token from the user's PDS via `com.atproto.space.getDelegationToken`.
pub struct PdsDelegationMinter {
    transport: SharedTransport,
    pds_url: Url,
    access_jwt: Mutex<String>,
}

impl core::fmt::Debug for PdsDelegationMinter {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.debug_struct("PdsDelegationMinter")
            .field("pds_url", &self.pds_url)
            .finish_non_exhaustive()
    }
}

impl PdsDelegationMinter {
    pub fn new(transport: SharedTransport, pds_url: Url, access_jwt: String) -> Self {
        Self {
            transport,
            pds_url,
            access_jwt: Mutex::new(access_jwt),
        }
    }

    pub fn update_access_jwt(&self, jwt: String) {
        if let Ok(mut guard) = self.access_jwt.lock() {
            *guard = jwt;
        }
    }
}

impl DelegationMinter for PdsDelegationMinter {
    fn get_delegation_token<'a>(&'a self, space: &'a SpaceRef) -> BoxFuture<'a, Result<String>> {
        Box::pin(async move {
            let mut url = self.pds_url.clone();
            url.set_path(&format!("/xrpc/{GET_DELEGATION_TOKEN_NSID}"));
            url.query_pairs_mut().append_pair("space", space.as_str());

            let access = self
                .access_jwt
                .lock()
                .map_err(|_| SpaceError::Storage("access jwt mutex poisoned".into()))?
                .clone();

            let req = Request::builder()
                .method(Method::GET)
                .uri(url.as_str())
                .header(http::header::AUTHORIZATION, format!("Bearer {access}"))
                .body(Bytes::new())
                .map_err(|e| SpaceError::Transport(e.to_string()))?;

            let resp = send_with_redirects(
                self.transport.as_ref(),
                req,
                &SendOptions::new(),
                RedirectPolicy::Never,
            )
            .await
            .map_err(|e| SpaceError::Transport(e.to_string()))?;

            let status = resp.status().as_u16();
            if !(200..300).contains(&status) {
                return Err(classify_authorize_space_sync_error(
                    space,
                    status,
                    resp.body(),
                ));
            }
            let out: GetDelegationTokenOutput = serde_json::from_slice(resp.body())
                .map_err(|e| SpaceError::MalformedPayload(e.to_string()))?;
            Ok(out.token)
        })
    }
}

#[derive(Default)]
struct ManagerState {
    cache: HashMap<SpaceRef, SpaceCredential>,
    generations: HashMap<SpaceRef, u64>,
    global_generation: u64,
    locks: HashMap<SpaceRef, Arc<AsyncMutex<()>>>,
}

/// Manages proof-of-possession space credentials with single-flight coalescing,
/// generation-tracked invalidation, and configured archive/blob byte limits.
pub struct SpaceCredentialManager<E: CredentialExchanger> {
    exchanger: Arc<E>,
    state: Mutex<ManagerState>,
    max_archive_bytes: usize,
    max_blob_bytes: usize,
}

impl<E: CredentialExchanger + core::fmt::Debug> core::fmt::Debug for SpaceCredentialManager<E> {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.debug_struct("SpaceCredentialManager")
            .field("exchanger", &self.exchanger)
            .field("max_archive_bytes", &self.max_archive_bytes)
            .field("max_blob_bytes", &self.max_blob_bytes)
            .finish_non_exhaustive()
    }
}

impl<E: CredentialExchanger> SpaceCredentialManager<E> {
    /// Create a manager with default archive (5 MiB) and blob (50 MiB) limits.
    pub fn new(exchanger: Arc<E>) -> Self {
        Self {
            exchanger,
            state: Mutex::new(ManagerState::default()),
            max_archive_bytes: DEFAULT_MAX_ARCHIVE_BYTES,
            max_blob_bytes: DEFAULT_MAX_BLOB_BYTES,
        }
    }

    #[must_use]
    pub fn with_max_archive_bytes(mut self, max: usize) -> Self {
        self.max_archive_bytes = max;
        self
    }

    #[must_use]
    pub fn with_max_blob_bytes(mut self, max: usize) -> Self {
        self.max_blob_bytes = max;
        self
    }

    pub fn max_archive_bytes(&self) -> usize {
        self.max_archive_bytes
    }

    pub fn max_blob_bytes(&self) -> usize {
        self.max_blob_bytes
    }

    /// Retrieve a valid credential for `space`, coalescing concurrent refreshes into one exchange.
    pub async fn credential(
        &self,
        space: &SpaceRef,
        force_refresh: bool,
        now: i64,
    ) -> Result<SpaceCredential> {
        let space_lock = {
            let mut guard = self
                .state
                .lock()
                .map_err(|_| SpaceError::Storage("credential manager mutex poisoned".into()))?;
            if !force_refresh
                && let Some(cached) = guard.cache.get(space)
                && !cached.needs_refresh(now)
            {
                return Ok(cached.clone());
            }
            guard
                .locks
                .entry(space.clone())
                .or_insert_with(|| Arc::new(AsyncMutex::new(())))
                .clone()
        };

        let _flight = space_lock.lock().await;

        let (start_gen, start_global) = {
            let guard = self
                .state
                .lock()
                .map_err(|_| SpaceError::Storage("credential manager mutex poisoned".into()))?;
            if !force_refresh
                && let Some(cached) = guard.cache.get(space)
                && !cached.needs_refresh(now)
            {
                return Ok(cached.clone());
            }
            (
                guard.generations.get(space).copied().unwrap_or(0),
                guard.global_generation,
            )
        };

        let proof_key = SigningKeyPair::generate_p256()?;
        let cred = self.exchanger.exchange(space, &proof_key, now).await?;

        let mut guard = self
            .state
            .lock()
            .map_err(|_| SpaceError::Storage("credential manager mutex poisoned".into()))?;
        let cur_gen = guard.generations.get(space).copied().unwrap_or(0);
        if cur_gen != start_gen || guard.global_generation != start_global {
            return Err(SpaceError::InvalidationDuringExchange);
        }
        guard.cache.insert(space.clone(), cred.clone());
        Ok(cred)
    }

    /// Immediately evict `space`'s credential and invalidate any in-flight exchange for `space`.
    pub fn invalidate(&self, space: &SpaceRef) {
        if let Ok(mut guard) = self.state.lock() {
            guard.cache.remove(space);
            let gen_ref = guard.generations.entry(space.clone()).or_insert(0);
            *gen_ref = gen_ref.saturating_add(1);
        }
    }

    /// Immediately evict all cached credentials and invalidate all in-flight exchanges.
    pub fn invalidate_all(&self) {
        if let Ok(mut guard) = self.state.lock() {
            guard.cache.clear();
            guard.global_generation = guard.global_generation.saturating_add(1);
        }
    }

    /// Evict `space`'s cached credential when a response reports `401 CredentialRevoked`.
    /// Returns `true` if eviction occurred.
    pub fn evict_if_revoked(&self, space: &SpaceRef, status: StatusCode, body: &[u8]) -> bool {
        if status != StatusCode::UNAUTHORIZED {
            return false;
        }
        let parsed: Option<XrpcErrorPayload> = serde_json::from_slice(body).ok();
        if parsed.as_ref().and_then(|p| p.error.as_deref()) == Some(CREDENTIAL_REVOKED_ERROR_NAME) {
            self.invalidate(space);
            return true;
        }
        false
    }

    /// Build RFC 9421 signed request headers for a target `request_url`.
    pub async fn sign_request(
        &self,
        space: &SpaceRef,
        request_url: &Url,
        explicit_server_did: Option<&Did>,
        force_refresh: bool,
        now: i64,
        nonce: Option<&str>,
    ) -> Result<(SpaceCredential, SpaceRequestHeaders)> {
        let cred = self.credential(space, force_refresh, now).await?;
        let aud = derive_audience(request_url, explicit_server_did.or(cred.pds_did.as_ref()))?;
        let headers =
            sign_credential_request(&cred.jwt, &cred.proof_key, aud.as_str(), now, nonce)?;
        Ok((cred, headers))
    }

    /// Execute an HTTP request signed with RFC 9421 space credential headers, automatically
    /// evicting and retrying once if the server returns `401 CredentialRevoked`.
    #[allow(clippy::too_many_arguments)]
    pub async fn send_signed_request(
        &self,
        transport: &SharedTransport,
        space: &SpaceRef,
        method: Method,
        url: &Url,
        explicit_server_did: Option<&Did>,
        extra_headers: &HeaderMap,
        body: Bytes,
        now: i64,
        nonce: Option<&str>,
    ) -> Result<Response<Bytes>> {
        for attempt in 0..2 {
            let force_refresh = attempt > 0;
            let fresh_nonce = match nonce {
                Some(_) => None,
                None => Some(generate_jti()?),
            };
            let (_cred, sig_headers) = self
                .sign_request(
                    space,
                    url,
                    explicit_server_did,
                    force_refresh,
                    now,
                    nonce.or(fresh_nonce.as_deref()),
                )
                .await?;
            let mut merged = extra_headers.clone();
            sig_headers.apply_to_header_map(&mut merged)?;

            let mut builder = Request::builder().method(method.clone()).uri(url.as_str());
            if let Some(h) = builder.headers_mut() {
                *h = merged;
            }
            let req = builder
                .body(body.clone())
                .map_err(|e| SpaceError::Transport(e.to_string()))?;

            let resp = send_with_redirects(
                transport.as_ref(),
                req,
                &SendOptions::new(),
                RedirectPolicy::Never,
            )
            .await
            .map_err(|e| SpaceError::Transport(e.to_string()))?;

            if attempt == 0 && self.evict_if_revoked(space, resp.status(), resp.body()) {
                continue;
            }
            return Ok(resp);
        }
        unreachable!("loop returns on attempt 0 or 1")
    }
}
