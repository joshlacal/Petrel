//! Multi-strategy authentication coordinator unifying OAuth, legacy password, and gateway modes.

use std::{fmt, sync::Arc};

use async_lock::Mutex;
use bytes::Bytes;
use http::{Request, Response};
use petrel_core::{AtIdentifier, Did, Handle};
use url::Url;

use super::{
    AccountStatus, AuthContinuitySnapshot, AuthContinuityState, AuthContinuityTransactionResult,
    AuthMode, GatewayAuthIdentity, LegacyPasswordStrategy, PasswordAuthError, PasswordLoginResult,
};
use crate::{
    account::AccountManager,
    net::SharedTransport,
    oauth::{
        OAuthClient, OAuthError, OAuthIdentityResolver, OAuthStartOptions, OAuthTarget,
        PendingOAuthFlow, SessionAuth,
    },
    rt::BoxFuture,
    xrpc::{AuthCtx, AuthError, AuthProvider, UnauthorizedAction},
};

/// Errors produced by [`AuthManager`].
#[derive(Debug, thiserror::Error)]
pub enum AuthManagerError {
    /// Operation is unavailable in the currently active authentication mode.
    #[error("operation not supported in {0:?} authentication mode")]
    UnsupportedInMode(AuthMode),
    /// Error from OAuth client.
    #[error(transparent)]
    OAuth(#[from] OAuthError),
    /// Error from legacy password strategy.
    #[error(transparent)]
    Password(#[from] PasswordAuthError),
}

type CachedOAuthProvider = Arc<Mutex<Option<(Did, Arc<SessionAuth>)>>>;

/// Strategy backing [`AuthManager`].
#[derive(Clone)]
enum ActiveStrategy {
    None,
    Legacy(Arc<LegacyPasswordStrategy>),
    OAuth {
        client: Arc<OAuthClient>,
        provider: CachedOAuthProvider,
    },
    Gateway {
        #[expect(dead_code)]
        origin: Url,
    },
}

/// Multi-strategy coordinator switching cleanly between unauthenticated, app-password,
/// OAuth (`PublicOAuth` / `CAB`), and confidential gateway modes while preserving
/// fail-closed [`AuthContinuityState`].
pub struct AuthManager {
    account_manager: Arc<AccountManager>,
    transport: SharedTransport,
    identity: Arc<dyn OAuthIdentityResolver>,
    oauth_client: Option<Arc<OAuthClient>>,
    fallback_service: Url,
    allow_loopback: bool,
    state: Mutex<AuthManagerInner>,
}

struct AuthManagerInner {
    mode: AuthMode,
    strategy: ActiveStrategy,
    continuity: AuthContinuityState,
}

impl fmt::Debug for AuthManager {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("AuthManager")
            .field("allow_loopback", &self.allow_loopback)
            .finish_non_exhaustive()
    }
}

impl AuthManager {
    /// Builds an [`AuthManager`] initialized in `mode`.
    pub fn new(
        mode: AuthMode,
        account_manager: Arc<AccountManager>,
        transport: SharedTransport,
        identity: Arc<dyn OAuthIdentityResolver>,
        oauth_client: Option<Arc<OAuthClient>>,
        fallback_service: Url,
        allow_loopback: bool,
    ) -> Result<Self, AuthManagerError> {
        let strategy = build_strategy(
            &mode,
            &account_manager,
            &transport,
            &identity,
            oauth_client.as_ref(),
            &fallback_service,
            allow_loopback,
        )?;
        let continuity = AuthContinuityState::new(mode.clone());
        Ok(Self {
            account_manager,
            transport,
            identity,
            oauth_client,
            fallback_service,
            allow_loopback,
            state: Mutex::new(AuthManagerInner {
                mode,
                strategy,
                continuity,
            }),
        })
    }

    /// Returns the active [`AuthMode`].
    pub async fn current_mode(&self) -> AuthMode {
        self.state.lock().await.mode.clone()
    }

    /// Returns a non-secret [`AuthContinuitySnapshot`] reflecting the current auth principal.
    pub async fn auth_continuity_snapshot(&self) -> AuthContinuitySnapshot {
        self.state.lock().await.continuity.snapshot()
    }

    /// Records a gateway session identity observation for continuity tracking.
    pub async fn observe_gateway_identity(&self, identity: Option<GatewayAuthIdentity>) {
        self.state
            .lock()
            .await
            .continuity
            .observe_gateway_identity(identity);
    }

    /// Invalidates the current continuity generation (e.g. upon account switch or logout).
    pub async fn invalidate_continuity(&self) {
        self.state.lock().await.continuity.invalidate();
    }

    /// Executes `operation` only while `expected` matches the exact current continuity snapshot.
    pub async fn perform_with_exact_auth_continuity<T, F>(
        &self,
        expected: &AuthContinuitySnapshot,
        operation: F,
    ) -> AuthContinuityTransactionResult<T>
    where
        F: FnOnce() -> T,
    {
        let guard = self.state.lock().await;
        let current = guard.continuity.snapshot();
        if current != *expected {
            return AuthContinuityTransactionResult::ContinuityChanged;
        }
        AuthContinuityTransactionResult::Performed(operation())
    }

    /// Switches authentication mode, invalidating continuity before activating the new strategy.
    pub async fn switch_mode(&self, new_mode: AuthMode) -> Result<(), AuthManagerError> {
        let mut inner = self.state.lock().await;
        if inner.mode == new_mode {
            return Ok(());
        }
        inner.continuity.invalidate();
        let strategy = build_strategy(
            &new_mode,
            &self.account_manager,
            &self.transport,
            &self.identity,
            self.oauth_client.as_ref(),
            &self.fallback_service,
            self.allow_loopback,
        )?;
        inner.continuity.commit_mode(new_mode.clone());
        inner.mode = new_mode;
        inner.strategy = strategy;
        Ok(())
    }

    /// Binds an OAuth [`SessionAuth`] provider for `did` when operating in OAuth/CAB mode.
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    pub async fn select_oauth_account(&self, did: &Did) -> Result<(), AuthManagerError> {
        let inner = self.state.lock().await;
        if let ActiveStrategy::OAuth { client, provider } = &inner.strategy {
            let auth = Arc::new(client.session_auth(did.clone()));
            *provider.lock().await = Some((did.clone(), auth));
        }
        Ok(())
    }

    /// Starts an OAuth authorization flow when in `PublicOAuth` or `Cab` mode.
    pub async fn start_oauth_flow(
        &self,
        identifier: Option<&AtIdentifier>,
        pds_fallback: Option<&Url>,
        options: OAuthStartOptions<'_>,
    ) -> Result<PendingOAuthFlow, AuthManagerError> {
        let client = {
            let inner = self.state.lock().await;
            match &inner.strategy {
                ActiveStrategy::OAuth { client, .. } => Arc::clone(client),
                other => return Err(unsupported_mode_err(&inner.mode, other)),
            }
        };
        let target = match (identifier, pds_fallback) {
            (Some(id), _) => OAuthTarget::Identifier(id.clone()),
            (None, Some(url)) => OAuthTarget::Server(url.clone()),
            (None, None) => OAuthTarget::Server(self.fallback_service.clone()),
        };
        Ok(client
            .start_authorization_with_options(target, options)
            .await?)
    }

    /// Completes an OAuth callback URL and activates the returned DID.
    pub async fn handle_oauth_callback(
        &self,
        callback_url: &Url,
    ) -> Result<(Did, Option<Handle>, Option<String>), AuthManagerError> {
        let client = {
            let inner = self.state.lock().await;
            match &inner.strategy {
                ActiveStrategy::OAuth { client, .. } => Arc::clone(client),
                other => return Err(unsupported_mode_err(&inner.mode, other)),
            }
        };
        let session = client.complete_authorization(callback_url).await?;
        self.account_manager
            .update_account_from_storage(&session.did)
            .await
            .map_err(PasswordAuthError::from)?;
        self.account_manager
            .set_current_account(&session.did)
            .await
            .map_err(PasswordAuthError::from)?;
        self.select_oauth_account(&session.did).await?;
        self.invalidate_continuity().await;
        let account = self
            .account_manager
            .get_account(&session.did)
            .await
            .map_err(PasswordAuthError::from)?;
        Ok((
            session.did.clone(),
            account.as_ref().and_then(|acc| acc.handle.clone()),
            account.map(|acc| acc.pds),
        ))
    }

    /// Signs in with an app password when operating in `AuthMode::Legacy`.
    pub async fn login_with_password(
        &self,
        identifier: &str,
        password: &str,
        auth_factor_token: Option<&str>,
    ) -> Result<PasswordLoginResult, AuthManagerError> {
        let legacy = {
            let inner = self.state.lock().await;
            match &inner.strategy {
                ActiveStrategy::Legacy(strategy) => Arc::clone(strategy),
                other => return Err(unsupported_mode_err(&inner.mode, other)),
            }
        };
        let result = legacy
            .login_with_password(identifier, password, auth_factor_token)
            .await?;
        self.invalidate_continuity().await;
        Ok(result)
    }

    /// Returns the last known hosting status in legacy mode, if recorded.
    pub async fn last_known_account_status(&self, did: &Did) -> Option<AccountStatus> {
        let legacy = {
            let inner = self.state.lock().await;
            match &inner.strategy {
                ActiveStrategy::Legacy(strategy) => Arc::clone(strategy),
                _ => return None,
            }
        };
        legacy.last_known_account_status(did).await
    }

    /// Signs out of the current account and clears local credentials.
    pub async fn logout(&self) -> Result<(), AuthManagerError> {
        let strategy = self.state.lock().await.strategy.clone();
        match strategy {
            ActiveStrategy::None | ActiveStrategy::Gateway { .. } => {
                let _ = self.account_manager.clear_current_account().await;
            }
            ActiveStrategy::Legacy(legacy) => legacy.logout().await?,
            ActiveStrategy::OAuth { client, provider } => {
                if let Some(did) = self
                    .account_manager
                    .current_did()
                    .await
                    .map_err(PasswordAuthError::from)?
                {
                    let _ = client.logout(&did).await;
                }
                *provider.lock().await = None;
                let _ = self.account_manager.clear_current_account().await;
            }
        }
        self.invalidate_continuity().await;
        Ok(())
    }

    /// Returns `true` if credentials exist for the currently active account.
    pub async fn tokens_exist(&self) -> bool {
        let Ok(Some(did)) = self.account_manager.current_did().await else {
            return false;
        };
        let strategy = self.state.lock().await.strategy.clone();
        match strategy {
            ActiveStrategy::None | ActiveStrategy::Gateway { .. } => false,
            ActiveStrategy::Legacy(legacy) => {
                legacy.get_session(&did).await.ok().flatten().is_some()
            }
            ActiveStrategy::OAuth { client, .. } => {
                client.session(&did).await.ok().flatten().is_some()
            }
        }
    }

    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    async fn active_auth_provider(&self) -> Option<Arc<dyn AuthProvider>> {
        let strategy = self.state.lock().await.strategy.clone();
        match strategy {
            ActiveStrategy::None | ActiveStrategy::Gateway { .. } => None,
            ActiveStrategy::Legacy(legacy) => Some(Arc::new(legacy)),
            ActiveStrategy::OAuth { client, provider } => {
                let mut guard = provider.lock().await;
                let Some(did) = self.account_manager.current_did().await.ok().flatten() else {
                    *guard = None;
                    return None;
                };
                if let Some((cached_did, existing)) = guard.as_ref()
                    && *cached_did == did
                {
                    return Some(Arc::clone(existing) as Arc<dyn AuthProvider>);
                }
                let auth = Arc::new(client.session_auth(did.clone()));
                *guard = Some((did, Arc::clone(&auth)));
                Some(auth)
            }
        }
    }
    async fn is_unauthenticated_passthrough(&self) -> bool {
        matches!(
            self.state.lock().await.strategy,
            ActiveStrategy::None | ActiveStrategy::Gateway { .. }
        )
    }

    /// Wraps this [`AuthManager`] in a provider bound to `(expected_continuity, expected_did)`.
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    #[must_use]
    pub fn bind_continuity(
        self: &Arc<Self>,
        expected_continuity: AuthContinuitySnapshot,
        expected_did: Option<Did>,
    ) -> Arc<dyn AuthProvider> {
        Arc::new(BoundAuthProvider {
            auth_manager: Arc::clone(self),
            expected_continuity,
            expected_did,
        })
    }
}

#[derive(Clone)]
struct BoundAuthProvider {
    auth_manager: Arc<AuthManager>,
    expected_continuity: AuthContinuitySnapshot,
    expected_did: Option<Did>,
}

impl BoundAuthProvider {
    async fn check_binding(&self) -> Result<(), AuthError> {
        let continuity = self.auth_manager.auth_continuity_snapshot().await;
        if continuity != self.expected_continuity {
            return Err(AuthError::Other(
                "authentication continuity changed".to_owned(),
            ));
        }
        let current_did = self
            .auth_manager
            .account_manager
            .current_did()
            .await
            .map_err(|e| AuthError::Other(e.to_string()))?;
        if current_did != self.expected_did {
            return Err(AuthError::Other("active account changed".to_owned()));
        }
        Ok(())
    }
}

impl AuthProvider for BoundAuthProvider {
    fn prepare(
        &self,
        request: Request<Bytes>,
    ) -> BoxFuture<'_, Result<(Request<Bytes>, AuthCtx), AuthError>> {
        Box::pin(async move {
            self.check_binding().await?;
            let prepared = self.auth_manager.prepare(request).await?;
            self.check_binding().await?;
            Ok(prepared)
        })
    }

    fn refresh_if_needed(&self) -> BoxFuture<'_, Result<(), AuthError>> {
        Box::pin(async move {
            self.check_binding().await?;
            self.auth_manager.refresh_if_needed().await
        })
    }

    fn handle_unauthorized<'a>(
        &'a self,
        response: &'a Response<Bytes>,
        ctx: &'a AuthCtx,
    ) -> BoxFuture<'a, Result<UnauthorizedAction, AuthError>> {
        Box::pin(async move {
            if self.check_binding().await.is_err() {
                return Ok(UnauthorizedAction::GiveUp);
            }
            self.auth_manager.handle_unauthorized(response, ctx).await
        })
    }

    fn update_dpop_nonce<'a>(
        &'a self,
        origin: &'a str,
        nonce: &'a str,
        ctx: &'a AuthCtx,
    ) -> BoxFuture<'a, ()> {
        Box::pin(async move {
            if self.check_binding().await.is_ok() {
                self.auth_manager
                    .update_dpop_nonce(origin, nonce, ctx)
                    .await;
            }
        })
    }
}

impl AuthProvider for AuthManager {
    fn prepare(
        &self,
        request: Request<Bytes>,
    ) -> BoxFuture<'_, Result<(Request<Bytes>, AuthCtx), AuthError>> {
        Box::pin(async move {
            if let Some(provider) = self.active_auth_provider().await {
                return provider.prepare(request).await;
            }
            if self.is_unauthenticated_passthrough().await {
                return Ok((request, AuthCtx::default()));
            }
            Err(AuthError::NoSession)
        })
    }

    fn refresh_if_needed(&self) -> BoxFuture<'_, Result<(), AuthError>> {
        Box::pin(async move {
            if let Some(provider) = self.active_auth_provider().await {
                return provider.refresh_if_needed().await;
            }
            if self.is_unauthenticated_passthrough().await {
                return Ok(());
            }
            Err(AuthError::NoSession)
        })
    }

    fn handle_unauthorized<'a>(
        &'a self,
        response: &'a Response<Bytes>,
        ctx: &'a AuthCtx,
    ) -> BoxFuture<'a, Result<UnauthorizedAction, AuthError>> {
        Box::pin(async move {
            let Some(provider) = self.active_auth_provider().await else {
                return Ok(UnauthorizedAction::GiveUp);
            };
            provider.handle_unauthorized(response, ctx).await
        })
    }

    fn update_dpop_nonce<'a>(
        &'a self,
        origin: &'a str,
        nonce: &'a str,
        ctx: &'a AuthCtx,
    ) -> BoxFuture<'a, ()> {
        Box::pin(async move {
            if let Some(provider) = self.active_auth_provider().await {
                provider.update_dpop_nonce(origin, nonce, ctx).await;
            }
        })
    }
}

#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
fn build_strategy(
    mode: &AuthMode,
    account_manager: &Arc<AccountManager>,
    transport: &SharedTransport,
    identity: &Arc<dyn OAuthIdentityResolver>,
    oauth_client: Option<&Arc<OAuthClient>>,
    fallback_service: &Url,
    allow_loopback: bool,
) -> Result<ActiveStrategy, AuthManagerError> {
    match mode {
        AuthMode::None => Ok(ActiveStrategy::None),
        AuthMode::Legacy => Ok(ActiveStrategy::Legacy(Arc::new(
            LegacyPasswordStrategy::new(
                Arc::clone(account_manager),
                Arc::clone(transport),
                Arc::clone(identity),
                fallback_service.clone(),
            )
            .with_loopback_development(allow_loopback),
        ))),
        AuthMode::PublicOAuth | AuthMode::Cab { .. } => {
            let client = oauth_client
                .cloned()
                .ok_or_else(|| AuthManagerError::UnsupportedInMode(mode.clone()))?;
            Ok(ActiveStrategy::OAuth {
                client,
                provider: Arc::new(Mutex::new(None)),
            })
        }
        AuthMode::Gateway { origin } => Ok(ActiveStrategy::Gateway {
            origin: origin.clone(),
        }),
    }
}

fn unsupported_mode_err(mode: &AuthMode, _strategy: &ActiveStrategy) -> AuthManagerError {
    AuthManagerError::UnsupportedInMode(mode.clone())
}
