use std::{collections::HashMap, fmt, sync::{Arc, Mutex}};

use async_lock::Mutex as AsyncMutex;
use bytes::Bytes;
use http::{Response, StatusCode};
use petrel_core::{AtIdentifier, Did, Handle};
use petrel_oauth_scopes::ScopeSet;
use serde::Deserialize;
use url::Url;
use zeroize::Zeroize;

use crate::{crypto::{DpopSigner, SoftwareDpopSigner, base64url, pkce_challenge, pkce_verifier, random_bytes},
    net::SharedTransport, rt::{BoxFuture, MaybeSend, MaybeSync}, storage::{SessionStore, StoreError}};

use super::{
    ClientAuth, MetadataError, OAuthProtocolError, Session, SessionRecord,
    dpop::{DpopNonces, nonce_header, oauth_error_code}, metadata::{ValidatedAuthorizationServer, endpoint_url, is_loopback, origin, require_canonical_origin},
    models::{Account, OAuthFlowState}, protocol::{AsEndpoint, OAuthProtocol, unix_now},
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
        let raw_authority = client_id.split_once("://").ok_or(OAuthError::ClientId)?.1
            .split(['/', '?', '#']).next().ok_or(OAuthError::ClientId)?;
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
        if let ClientAuth::Cab { client_id: backend_client, .. } = &authentication
            && backend_client != &client_id
        {
            return Err(OAuthError::ClientId);
        }
        let reversed_host = parsed.host_str().ok_or(OAuthError::ClientId)?
            .split('.').rev().collect::<Vec<_>>().join(".");
        let redirect_matches = match redirect_uri.scheme() {
            "https" => !development_id && redirect_uri.host_str().is_some() && !is_loopback(&redirect_uri),
            "http" => development_id
                && matches!(redirect_uri.host_str(), Some("127.0.0.1" | "[::1]")),
            scheme => !development_id && scheme == reversed_host && redirect_uri.host_str().is_none()
                && redirect_uri.path().starts_with('/') && !redirect_uri.path().starts_with("//"),
        };
        if !redirect_matches || redirect_uri.fragment().is_some()
            || !redirect_uri.username().is_empty() || redirect_uri.password().is_some()
            || redirect_uri.query_pairs().any(|(key, _)| is_callback_parameter(&key))
        {
            return Err(OAuthError::RedirectUri);
        }
        let scope = ScopeSet::parse(scope).map_err(|_| OAuthError::Scope)?;
        if !scope.includes_atproto() {
            return Err(OAuthError::Scope);
        }

        Ok(Self { client_id, redirect_uri, scope, authentication, allow_loopback: false })
    }

    /// Permit explicit loopback HTTP endpoints for local development.
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
    fn get<'a>(&'a self, id: &'a str) -> BoxFuture<'a, Result<Option<Arc<dyn DpopSigner>>, StoreError>>;
    fn delete<'a>(&'a self, id: &'a str) -> BoxFuture<'a, Result<(), StoreError>>;
}

struct SoftwareKeyStore {
    storage: SessionStore,
}

impl DpopKeyStore for SoftwareKeyStore {
    fn create<'a>(&'a self, id: &'a str) -> BoxFuture<'a, Result<Arc<dyn DpopSigner>, StoreError>> {
        Box::pin(async move {
            let key = SoftwareDpopSigner::generate().map_err(|_| StoreError::Unavailable("DPoP key generation".into()))?;
            self.storage.save_dpop_key(id, &key.to_bytes()).await?;
            Ok(Arc::new(key) as Arc<dyn DpopSigner>)
        })
    }

    fn get<'a>(&'a self, id: &'a str) -> BoxFuture<'a, Result<Option<Arc<dyn DpopSigner>>, StoreError>> {
        Box::pin(async move {
            self.storage.get_dpop_key(id).await?.map(|material| {
                SoftwareDpopSigner::from_bytes(&material).map(|key| Arc::new(key) as Arc<dyn DpopSigner>)
                    .map_err(|_| StoreError::Corrupt("DPoP key".into()))
            }).transpose()
        })
    }

    fn delete<'a>(&'a self, id: &'a str) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(self.storage.delete_dpop_key(id))
    }
}

pub struct OAuthClient {
    pub(super) protocol: OAuthProtocol,
    pub(super) storage: SessionStore,
    pub(super) keys: Arc<dyn DpopKeyStore>,
    resolver: Arc<dyn OAuthIdentityResolver>,
    config: OAuthConfig,
    pub(super) accounts: Mutex<HashMap<Did, Arc<AsyncMutex<RefreshState>>>>,
    pending: AsyncMutex<HashMap<String, PendingAuthorization>>,
}

struct PendingAuthorization {
    state: String,
    authorize_url: Url,
    created_at: u64,
    key_id: String,
    jkt: String,
}

impl fmt::Debug for OAuthClient {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("OAuthClient").finish_non_exhaustive()
    }
}

impl OAuthClient {
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
            keys: Arc::new(SoftwareKeyStore { storage: storage.clone() }),
            storage,
            resolver,
            config,
            accounts: Mutex::new(HashMap::new()),
            pending: AsyncMutex::new(HashMap::new()),
        })
    }

    pub fn with_key_store(mut self, keys: Arc<dyn DpopKeyStore>) -> Self {
        self.keys = keys;
        self
    }

    pub async fn start_authorization(&self, target: OAuthTarget) -> Result<Url, OAuthError> {
        let target_key = match &target {
            OAuthTarget::Identifier(identifier) => identifier.as_str(),
            OAuthTarget::Server(url) => url.as_str(),
        }.to_owned();
        // Different targets share a short-lived flow limit. A concurrent start
        // for the same target reuses the same pushed request and state.
        let mut pending = self.pending.lock().await;
        let now = unix_now()?;
        if let Some(flow) = pending.get(&target_key)
            && now.saturating_sub(flow.created_at) <= 600
        {
            return Ok(flow.authorize_url.clone());
        }
        let expired = pending.iter().filter(|(_, flow)| now.saturating_sub(flow.created_at) > 600)
            .map(|(target, _)| target.clone()).collect::<Vec<_>>();
        for target in expired {
            if let Some(flow) = pending.remove(&target) {
                self.cancel_flow(&flow, now).await?;
            }
        }
        if pending.len() >= 8 {
            return Err(OAuthError::AuthorizationRejected);
        }

        let (expected_did, expected_pds, server, login_hint) = match &target {
            OAuthTarget::Identifier(identifier) => {
                let identity = self.resolver.resolve_identity(identifier, false).await.map_err(|_| OAuthError::Identity)?;
                if let AtIdentifier::Did(did) = identifier && did != &identity.did {
                    return Err(OAuthError::IdentityChanged);
                }
                let pds = origin(&identity.pds, false).ok_or(OAuthError::Identity)?;
                let metadata = self.protocol.discover_pds(&identity.pds).await?;
                (Some(identity.did), Some(pds), metadata, Some(identifier.as_str()))
            }
            OAuthTarget::Server(url) => (None, None, self.protocol.discover_server(url).await?, None),
        };

        let key_id = base64url(&random_bytes::<32>()?);
        let state = base64url(&random_bytes::<32>()?);
        let key = self.keys.create(&key_id).await?;
        let jkt = match key.public_jwk().thumbprint() {
            Ok(jkt) => jkt,
            Err(error) => {
                self.keys.delete(&key_id).await?;
                return Err(error.into());
            }
        };
        let authorize_url = match self.push_authorization(&server, &state, &key_id, &jkt, &*key,
            expected_did, expected_pds, login_hint).await
        {
            Ok(url) => url,
            Err(error) => {
                self.protocol.nonces.clear_key(&jkt);
                self.keys.delete(&key_id).await?;
                return Err(error);
            }
        };
        pending.insert(target_key, PendingAuthorization {
            state, authorize_url: authorize_url.clone(), created_at: unix_now()?, key_id, jkt,
        });
        Ok(authorize_url)
    }

    #[allow(clippy::too_many_arguments)]
    async fn push_authorization(
        &self,
        server: &ValidatedAuthorizationServer,
        state: &str,
        key_id: &str,
        jkt: &str,
        key: &dyn DpopSigner,
        expected_did: Option<Did>,
        expected_pds: Option<String>,
        login_hint: Option<&str>,
    ) -> Result<Url, OAuthError> {
        #[derive(Deserialize)]
        struct ParResponse { request_uri: String }

        let verifier = zeroize::Zeroizing::new(pkce_verifier()?);
        let challenge = pkce_challenge(&verifier);
        let scope = self.config.scope.scope_string();
        let mut parameters = vec![
            ("redirect_uri", self.config.redirect_uri.as_str()),
            ("response_type", "code"),
            ("code_challenge_method", "S256"),
            ("code_challenge", challenge.as_str()),
            ("state", state),
            ("scope", scope.as_str()),
        ];
        if let Some(hint) = login_hint { parameters.push(("login_hint", hint)); }
        let response = self.protocol.send_as(server, AsEndpoint::Par, &parameters, key).await?;
        require_success(&response)?;
        let nonce = required_nonce(response.headers())?;
        let par: ParResponse = serde_json::from_slice(response.body())
            .map_err(|_| OAuthError::InvalidResponse)?;
        if par.request_uri.is_empty() || par.request_uri.bytes().any(|byte| byte.is_ascii_control()) {
            return Err(OAuthError::InvalidResponse);
        }
        let mut authorize = server.authorization_endpoint().clone();
        if authorize.query_pairs().any(|(param, _)| matches!(param.as_ref(), "client_id" | "request_uri")) {
            return Err(OAuthError::InvalidResponse);
        }
        authorize.query_pairs_mut().append_pair("client_id", &self.config.client_id)
            .append_pair("request_uri", &par.request_uri);

        let stored = OAuthFlowState {
            code_verifier: verifier.to_string(),
            nonce: nonce.to_owned(),
            expected_issuer: server.issuer().to_owned(),
            expected_pds,
            expected_did,
            redirect_uri: self.config.redirect_uri.as_str().to_owned(),
            dpop_key_id: key_id.to_owned(),
            dpop_jkt: jkt.to_owned(),
            metadata: server.metadata().clone(),
        };
        self.storage.save_oauth_state(state, unix_now()?, &stored).await?;
        Ok(authorize)
    }

    async fn cancel_flow(&self, flow: &PendingAuthorization, now: u64) -> Result<(), OAuthError> {
        match self.storage.consume_oauth_state::<OAuthFlowState>(&flow.state, now).await {
            Ok(_) | Err(StoreError::InvalidFlowStateAge) => {},
            Err(error) => return Err(error.into()),
        }
        self.protocol.nonces.clear_key(&flow.jkt);
        self.keys.delete(&flow.key_id).await?;
        Ok(())
    }

    /// Completes a callback and atomically commits its bound account session.
    pub async fn complete_authorization(&self, callback: &Url) -> Result<Session, OAuthError> {
        let state = callback_parameter(callback, "state")?.ok_or(OAuthError::UnknownState)?;
        if state.len() != 43 || !state.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_')) {
            return Err(OAuthError::UnknownState);
        }
        let flow: OAuthFlowState = self.storage.consume_oauth_state(&state, unix_now()?).await?
            .ok_or(OAuthError::UnknownState)?;
        self.pending.lock().await.retain(|_, pending| pending.state != state);
        let result = self.complete_flow(callback, &flow).await;
        if result.is_err() {
            self.protocol.nonces.clear_key(&flow.dpop_jkt);
            self.keys.delete(&flow.dpop_key_id).await?;
        }
        result
    }

    async fn complete_flow(&self, callback: &Url, flow: &OAuthFlowState) -> Result<Session, OAuthError> {
        if flow.redirect_uri != self.config.redirect_uri.as_str() || !same_redirect(callback, &self.config.redirect_uri) {
            return Err(OAuthError::RedirectUri);
        }
        if let Some(error) = callback_parameter(callback, "error")? {
            return Err(if error == "access_denied" { OAuthError::Cancelled } else { OAuthError::AuthorizationRejected });
        }
        let issuer = callback_parameter(callback, "iss")?.ok_or(OAuthError::Callback)?;
        if issuer != flow.expected_issuer || flow.expected_did.is_some() != flow.expected_pds.is_some() {
            return Err(OAuthError::Callback);
        }
        let code = zeroize::Zeroizing::new(callback_parameter(callback, "code")?.ok_or(OAuthError::Callback)?);
        let key = self.bound_key(&flow.dpop_key_id, &flow.dpop_jkt).await?;
        let server = flow.metadata.clone().validate(&flow.expected_issuer, self.config.authentication.method())?;
        if let Some(pds) = &flow.expected_pds {
            server.validates_resource(pds)?;
        }
        if server.par_endpoint.origin() == server.token_endpoint.origin() {
            self.protocol.nonces.put(&flow.dpop_jkt, &server.token_endpoint, &flow.nonce)
                .map_err(OAuthProtocolError::Dpop)?;
        }

        let response = self.protocol.send_as(&server, AsEndpoint::Token, &[
            ("grant_type", "authorization_code"), ("code", &code),
            ("redirect_uri", &flow.redirect_uri), ("code_verifier", &flow.code_verifier),
        ], &*key).await?;
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
        if flow.expected_did.as_ref().is_some_and(|expected| expected != &did) {
            return Err(OAuthError::IdentityChanged);
        }
        let identity = self.resolver.resolve_identity(&AtIdentifier::Did(did.clone()), true).await
            .map_err(|_| OAuthError::Identity)?;
        let pds = origin(&identity.pds, false).ok_or(OAuthError::Identity)?;
        if identity.did != did || flow.expected_pds.as_ref().is_some_and(|expected| expected != &pds) {
            return Err(OAuthError::IdentityChanged);
        }
        let verified = self.protocol.discover_pds(&identity.pds).await?;
        if verified.issuer() != server.issuer() {
            return Err(OAuthError::IdentityChanged);
        }
        let session = tokens.session(did.clone(), unix_now()?, None)?;
        let record = SessionRecord {
            account: Account {
                did: did.clone(),
                handle: identity.handle,
                pds,
                authorization_server: server.metadata().clone(),
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
            }
            // Once the new session is persisted, cleanup cannot invalidate it.
            let _ = self.keys.delete(&old.dpop_key_id).await;
        }
        Ok(session)
    }

    pub(super) fn account_lock(&self, did: &Did) -> Arc<AsyncMutex<RefreshState>> {
        self.accounts.lock().unwrap_or_else(std::sync::PoisonError::into_inner)
            .entry(did.clone()).or_default().clone()
    }

    pub(super) async fn bound_key(&self, id: &str, jkt: &str) -> Result<Arc<dyn DpopSigner>, OAuthError> {
        let key = self.keys.get(id).await?.ok_or(OAuthError::KeyBinding)?;
        if key.public_jwk().thumbprint()? != jkt {
            return Err(OAuthError::KeyBinding);
        }
        Ok(key)
    }

    pub(super) fn validate_account(
        &self,
        account: &Account,
    ) -> Result<ValidatedAuthorizationServer, OAuthError> {
        let pds = require_canonical_origin(&account.pds)?;
        if !self.protocol.permits(&pds) {
            return Err(OAuthError::Identity);
        }
        let metadata = &account.authorization_server;
        let server = metadata.clone().validate(&metadata.issuer, self.config.authentication.method())?;
        if is_loopback(&require_canonical_origin(server.issuer())?) && !is_loopback(&pds) {
            return Err(OAuthError::Identity);
        }
        server.validates_resource(&account.pds)?;
        Ok(server)
    }

    pub(super) async fn revoke_returned(&self, server: &ValidatedAuthorizationServer, key: &dyn DpopSigner, body: &[u8]) {
        #[derive(Deserialize)]
        struct Revocable {
            #[serde(default)]
            access_token: Option<String>,
            #[serde(default)]
            refresh_token: Option<String>,
        }

        impl Drop for Revocable {
            fn drop(&mut self) {
                self.access_token.zeroize();
                self.refresh_token.zeroize();
            }
        }

        if let Ok(tokens) = serde_json::from_slice::<Revocable>(body)
            && let Some(token) = tokens.refresh_token.as_deref().filter(|token| !token.is_empty())
                .or(tokens.access_token.as_deref().filter(|token| !token.is_empty()))
        {
            let _ = self.revoke(server, key, token).await;
        }
    }

    pub(super) async fn revoke(&self, server: &ValidatedAuthorizationServer, key: &dyn DpopSigner, token: &str) -> bool {
        if server.revocation_endpoint.is_none() {
            return false;
        }
        self.protocol.send_as(server, AsEndpoint::Revoke, &[("token", token)], key).await
            .is_ok_and(|response| response.status() == StatusCode::OK)
    }
}

pub(super) fn require_success(response: &Response<Bytes>) -> Result<(), OAuthError> {
    if response.status().is_success() {
        return Ok(());
    }
    if matches!(response.status(), StatusCode::BAD_REQUEST | StatusCode::UNAUTHORIZED)
        && oauth_error_code(response.body()) == Some("invalid_grant")
    {
        return Err(OAuthError::InvalidGrant);
    }
    Err(OAuthError::ServerStatus(response.status().as_u16()))
}

fn required_nonce(headers: &http::HeaderMap) -> Result<&str, OAuthError> {
    nonce_header(headers).ok().flatten().ok_or(OAuthError::MissingNonce)
}

fn callback_parameter(url: &Url, name: &str) -> Result<Option<String>, OAuthError> {
    let mut values = url.query_pairs().filter(|(key, _)| key == name);
    let found = values.next().map(|(_, value)| value.into_owned());
    if values.next().is_some() || found.as_deref() == Some("") {
        return Err(OAuthError::Callback);
    }
    Ok(found)
}

fn is_callback_parameter(name: &str) -> bool {
    matches!(name, "state" | "iss" | "code" | "error" | "error_description" | "error_uri")
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
            callback_parameter(callback, &key).is_ok_and(|found| found.as_deref() == Some(value.as_ref()))
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
    ) -> Result<Session, OAuthError> {
        if !self.token_type.eq_ignore_ascii_case("dpop") || !valid_access_token(&self.access_token)
            || self.refresh_token.as_ref().is_some_and(String::is_empty)
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
        Ok(Session::new(did, self.access_token.clone(),
            self.refresh_token.clone().or_else(|| old_refresh.map(str::to_owned)), now, expires_in, &scope))
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
    !base.is_empty() && base.bytes().all(|byte|
        byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'.' | b'_' | b'~' | b'+' | b'/'))
}
