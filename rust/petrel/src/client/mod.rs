//! High-level AT Protocol client facade coordinating XRPC, auth, accounts, labelers, and blobs.

use std::{collections::BTreeMap, fmt, sync::Arc};

use async_lock::RwLock;
use bytes::Bytes;
use http::HeaderMap;
use petrel_api::generated::com::atproto::{repo::upload_blob, server::get_session};
use petrel_core::{AtIdentifier, Did, Handle, xrpc::XrpcRequest};
use url::Url;

use crate::{
    account::{AccountError, AccountManager, AccountSwitchCoordinator, AccountSwitchError},
    auth::{
        AccountStatus, AccountStatusError, AuthContinuitySnapshot, AuthContinuityTransactionResult,
        AuthManager, AuthManagerError, AuthMode, PasswordLoginResult,
    },
    media::{ImageMetadataStripper, ImageMetadataStrippingError},
    net::{RequestDeduplicator, SharedTransport, TransportError},
    oauth::{Account, OAuthClient, OAuthIdentityResolver, OAuthStartOptions, PendingOAuthFlow},
    storage::SessionStore,
    xrpc::{
        AuthError, AuthProvider, CallOptions, Error as XrpcClientError, ResponseMetadata, XrpcBody,
        XrpcClient, XrpcLabeler, XrpcResponse,
    },
};

/// Errors produced by [`AtProtoClient`].
#[derive(Debug, thiserror::Error)]
pub enum ClientError {
    /// XRPC pipeline error.
    #[error(transparent)]
    Xrpc(#[from] XrpcClientError),
    /// Authentication manager error.
    #[error(transparent)]
    Auth(#[from] AuthManagerError),
    /// Account management error.
    #[error(transparent)]
    Account(#[from] AccountError),
    /// Concurrent account switch error.
    #[error(transparent)]
    Switch(#[from] AccountSwitchError),
    /// Transport configuration error.
    #[error(transparent)]
    Transport(#[from] TransportError),
    /// Image metadata stripping failed before blob upload.
    #[error(transparent)]
    Media(#[from] ImageMetadataStrippingError),
}

/// High-level AT Protocol client matching Swift `ATProtoClient` capabilities.
pub struct AtProtoClient {
    transport: SharedTransport,
    account_manager: Arc<AccountManager>,
    auth_manager: Arc<AuthManager>,
    switch_coordinator: AccountSwitchCoordinator,
    deduplicator: RequestDeduplicator,
    state: RwLock<ClientState>,
}

struct ClientState {
    base_url: Url,
    xrpc: XrpcClient,
    labelers: Option<Vec<XrpcLabeler>>,
    service_dids: BTreeMap<String, String>,
    request_ids: bool,
    headers: HeaderMap,
    synced_selection_epoch: u64,
}

impl fmt::Debug for AtProtoClient {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("AtProtoClient").finish_non_exhaustive()
    }
}

impl AtProtoClient {
    /// Constructs an [`AtProtoClient`] from a transport, session store, identity resolver,
    /// initial base URL, and initial [`AuthMode`].
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    pub fn new(
        base_url: Url,
        transport: SharedTransport,
        storage: SessionStore,
        identity: Arc<dyn OAuthIdentityResolver>,
        oauth_client: Option<Arc<OAuthClient>>,
        auth_mode: AuthMode,
        allow_loopback: bool,
    ) -> Result<Self, ClientError> {
        let account_manager = Arc::new(AccountManager::new(storage));
        let auth_manager = Arc::new(AuthManager::new(
            auth_mode,
            Arc::clone(&account_manager),
            Arc::clone(&transport),
            identity,
            oauth_client,
            base_url.clone(),
            allow_loopback,
        )?);
        let service_dids = default_service_dids();
        let xrpc = build_xrpc_client(
            &base_url,
            &transport,
            &auth_manager,
            &HeaderMap::new(),
            &service_dids,
            None,
            false,
        )?;
        let synced_selection_epoch = account_manager.selection_epoch();
        Ok(Self {
            transport,
            account_manager,
            auth_manager,
            switch_coordinator: AccountSwitchCoordinator::new(),
            deduplicator: RequestDeduplicator::new(),
            state: RwLock::new(ClientState {
                base_url,
                xrpc,
                labelers: None,
                service_dids,
                request_ids: false,
                headers: HeaderMap::new(),
                synced_selection_epoch,
            }),
        })
    }

    /// Returns the underlying [`AccountManager`].
    #[must_use]
    pub const fn account_manager(&self) -> &Arc<AccountManager> {
        &self.account_manager
    }

    /// Returns the underlying [`AuthManager`].
    #[must_use]
    pub const fn auth_manager(&self) -> &Arc<AuthManager> {
        &self.auth_manager
    }

    /// Returns the shared [`RequestDeduplicator`].
    #[must_use]
    pub const fn deduplicator(&self) -> &RequestDeduplicator {
        &self.deduplicator
    }

    /// Returns the current base XRPC service URL.
    pub async fn base_url(&self) -> Url {
        let _ = self.sync_active_account_pipeline_if_needed().await;
        self.state.read().await.base_url.clone()
    }

    /// Updates the base XRPC service URL and rebuilds the internal pipeline.
    pub async fn set_base_url(&self, base_url: Url) -> Result<(), ClientError> {
        let mut state = self.state.write().await;
        let xrpc = build_xrpc_client(
            &base_url,
            &self.transport,
            &self.auth_manager,
            &state.headers,
            &state.service_dids,
            state.labelers.as_deref(),
            state.request_ids,
        )?;
        state.base_url = base_url;
        state.xrpc = xrpc;
        state.synced_selection_epoch = self.account_manager.selection_epoch();
        Ok(())
    }

    /// Sets the `atproto-accept-labelers` header sent on same-origin calls.
    ///
    /// Passing an empty slice sends `atproto-accept-labelers: ""` (meaning apply no labels),
    /// whereas [`Self::clear_labelers`] removes the header completely.
    pub async fn configure_labelers(&self, labelers: &[XrpcLabeler]) -> Result<(), ClientError> {
        let deduped = XrpcLabeler::deduplicated(labelers);
        let mut state = self.state.write().await;
        state.labelers = Some(deduped);
        state.xrpc = build_xrpc_client(
            &state.base_url,
            &self.transport,
            &self.auth_manager,
            &state.headers,
            &state.service_dids,
            state.labelers.as_deref(),
            state.request_ids,
        )?;
        Ok(())
    }

    /// Removes the `atproto-accept-labelers` header so the service applies its default labelers.
    pub async fn clear_labelers(&self) -> Result<(), ClientError> {
        let mut state = self.state.write().await;
        state.labelers = None;
        state.xrpc = build_xrpc_client(
            &state.base_url,
            &self.transport,
            &self.auth_manager,
            &state.headers,
            &state.service_dids,
            None,
            state.request_ids,
        )?;
        Ok(())
    }

    /// Updates `atproto-accept-labelers` only if `expected_continuity` and `expected_did` still match.
    pub async fn configure_labelers_if_continuity(
        &self,
        expected_continuity: &AuthContinuitySnapshot,
        expected_did: Option<&Did>,
        labelers: &[XrpcLabeler],
    ) -> Result<bool, ClientError> {
        let deduped = XrpcLabeler::deduplicated(labelers);
        let mut state = self.state.write().await;
        let current_did = self.account_manager.current_did().await?;
        let outcome = self
            .auth_manager
            .perform_with_exact_auth_continuity(expected_continuity, || {
                current_did.as_ref() == expected_did
            })
            .await;
        if outcome != AuthContinuityTransactionResult::Performed(true) {
            return Ok(false);
        }
        state.labelers = Some(deduped);
        state.xrpc = build_xrpc_client(
            &state.base_url,
            &self.transport,
            &self.auth_manager,
            &state.headers,
            &state.service_dids,
            state.labelers.as_deref(),
            state.request_ids,
        )?;
        Ok(true)
    }

    /// Returns the currently configured labelers, or `None` when the header is omitted.
    pub async fn configured_labelers(&self) -> Option<Vec<XrpcLabeler>> {
        self.state.read().await.labelers.clone()
    }

    /// Enables or disables automatic per-request `x-request-id` header generation.
    pub async fn set_request_ids(&self, enabled: bool) -> Result<(), ClientError> {
        let mut state = self.state.write().await;
        state.request_ids = enabled;
        state.xrpc = build_xrpc_client(
            &state.base_url,
            &self.transport,
            &self.auth_manager,
            &state.headers,
            &state.service_dids,
            state.labelers.as_deref(),
            state.request_ids,
        )?;
        Ok(())
    }

    /// Sets the proxy DID mapping for an NSID prefix (e.g., `"app.bsky"`).
    pub async fn set_service_did(&self, prefix: String, did: String) -> Result<(), ClientError> {
        let mut state = self.state.write().await;
        state.service_dids.insert(prefix, did);
        state.xrpc = build_xrpc_client(
            &state.base_url,
            &self.transport,
            &self.auth_manager,
            &state.headers,
            &state.service_dids,
            state.labelers.as_deref(),
            state.request_ids,
        )?;
        Ok(())
    }

    /// Returns a cloned snapshot of the underlying [`XrpcClient`], bound to the current
    /// authentication continuity and active account DID.
    pub async fn xrpc(&self) -> XrpcClient {
        let _ = self.sync_active_account_pipeline_if_needed().await;
        let state = self.state.read().await;
        let continuity = self.auth_manager.auth_continuity_snapshot().await;
        let expected_did = self.account_manager.current_did().await.ok().flatten();
        state
            .xrpc
            .clone()
            .with_auth_provider(self.auth_manager.bind_continuity(continuity, expected_did))
    }

    /// Returns the current authentication continuity snapshot.
    pub async fn auth_continuity_snapshot(&self) -> AuthContinuitySnapshot {
        let _ = self.sync_active_account_pipeline_if_needed().await;
        self.auth_manager.auth_continuity_snapshot().await
    }

    /// Executes `operation` synchronously while `expected` remains the exact continuity snapshot.
    pub async fn perform_with_exact_auth_continuity<T, F>(
        &self,
        expected: &AuthContinuitySnapshot,
        operation: F,
    ) -> AuthContinuityTransactionResult<T>
    where
        F: FnOnce() -> T,
    {
        let _ = self.sync_active_account_pipeline_if_needed().await;
        self.auth_manager
            .perform_with_exact_auth_continuity(expected, operation)
            .await
    }

    /// Switches authentication mode (invalidating continuity).
    pub async fn switch_auth_mode(&self, mode: AuthMode) -> Result<(), ClientError> {
        self.auth_manager.switch_mode(mode).await?;
        Ok(())
    }

    /// Removes `did` via [`AccountManager::remove_account`] and synchronizes the client pipeline
    /// if removal auto-selected or cleared the active account.
    pub async fn remove_account(&self, did: &Did) -> Result<(), ClientError> {
        self.account_manager.remove_account(did).await?;
        self.sync_active_account_pipeline_if_needed().await?;
        Ok(())
    }

    /// Switches the active account atomically and updates the base PDS URL when available.
    pub async fn switch_to_account(&self, did: &Did) -> Result<(), ClientError> {
        let current = self.account_manager.current_did().await?;
        self.switch_coordinator
            .begin_account_switch(current.as_ref(), did)?;
        let res = async {
            self.auth_manager.invalidate_continuity().await;
            self.account_manager.set_current_account(did).await?;
            self.auth_manager.select_oauth_account(did).await?;
            if let Some(account) = self.account_manager.get_account(did).await?
                && let Ok(url) = Url::parse(&account.pds)
            {
                self.set_base_url(url).await?;
            } else {
                self.state.write().await.synced_selection_epoch =
                    self.account_manager.selection_epoch();
            }
            Ok::<(), ClientError>(())
        }
        .await;
        match res {
            Ok(()) => {
                self.switch_coordinator.complete_account_switch();
                Ok(())
            }
            Err(err) => {
                self.switch_coordinator.handle_switch_error(&err);
                Err(err)
            }
        }
    }

    /// Starts an OAuth authorization flow in `PublicOAuth` / `Cab` mode.
    pub async fn start_oauth_flow(
        &self,
        identifier: Option<&AtIdentifier>,
        pds_fallback: Option<&Url>,
        options: OAuthStartOptions<'_>,
    ) -> Result<PendingOAuthFlow, ClientError> {
        Ok(self
            .auth_manager
            .start_oauth_flow(identifier, pds_fallback, options)
            .await?)
    }

    /// Completes an OAuth callback URL and updates the base PDS URL.
    pub async fn handle_oauth_callback(
        &self,
        callback_url: &Url,
    ) -> Result<(Did, Option<Handle>), ClientError> {
        let (did, handle, pds) = self
            .auth_manager
            .handle_oauth_callback(callback_url)
            .await?;
        if let Some(pds) = pds
            && let Ok(url) = Url::parse(&pds)
        {
            self.set_base_url(url).await?;
        } else {
            self.state.write().await.synced_selection_epoch =
                self.account_manager.selection_epoch();
        }
        Ok((did, handle))
    }

    /// Signs in using an identifier and app password, updating `base_url` to the account PDS.
    pub async fn login_with_password(
        &self,
        identifier: &str,
        password: &str,
        auth_factor_token: Option<&str>,
    ) -> Result<PasswordLoginResult, ClientError> {
        let res = self
            .auth_manager
            .login_with_password(identifier, password, auth_factor_token)
            .await?;
        self.set_base_url(res.pds_url.clone()).await?;
        Ok(res)
    }

    /// Logs out of the current session.
    pub async fn logout(&self) -> Result<(), ClientError> {
        self.auth_manager.logout().await?;
        Ok(())
    }

    /// Returns `true` if a session is active for the current account.
    pub async fn has_valid_session(&self) -> bool {
        self.auth_manager.tokens_exist().await
    }

    /// Returns the active account DID if signed in.
    pub async fn get_did(&self) -> Result<Option<Did>, ClientError> {
        Ok(self.account_manager.current_did().await?)
    }

    /// Returns the active [`Account`] record if signed in.
    pub async fn get_current_account(&self) -> Result<Option<Account>, ClientError> {
        Ok(self.account_manager.get_current_account().await?)
    }

    /// Returns the last known [`AccountStatus`] cached by the auth strategy for the active DID.
    pub async fn last_known_account_status(&self) -> Option<AccountStatus> {
        let did = self.account_manager.current_did().await.ok().flatten()?;
        self.auth_manager.last_known_account_status(&did).await
    }

    /// Queries `com.atproto.server.getSession` to determine the current account's hosting status,
    /// translating hosting-status refusals (`AccountTakedown`, etc.) into `Ok(AccountStatus)`.
    pub async fn fetch_account_status(&self) -> Result<AccountStatus, ClientError> {
        let xrpc = self.xrpc().await;
        match xrpc
            .send::<get_session::GetSession>((), (), &CallOptions::default())
            .await
        {
            Ok(out) => Ok(AccountStatus::from_api(out.active, out.status.as_deref())),
            Err(XrpcClientError::Auth(AuthError::AccountStatus(status_err))) => {
                Ok(status_err.status)
            }
            Err(err) => {
                if let XrpcClientError::Xrpc(ref xrpc_err) = err
                    && let Some(status_err) = AccountStatusError::from_xrpc_error(
                        &xrpc_err.code,
                        xrpc_err.message.as_deref(),
                    )
                {
                    return Ok(status_err.status);
                }
                Err(err.into())
            }
        }
    }

    /// Executes a typed XRPC request using effective client options.
    pub async fn send<R: XrpcRequest>(
        &self,
        params: R::Params,
        input: R::Input,
        options: &CallOptions,
    ) -> Result<R::Output, XrpcClientError<R::Error>> {
        let (xrpc, effective) = self.effective_call(options).await;
        xrpc.send::<R>(params, input, &effective).await
    }

    /// Executes a typed XRPC request and returns its [`ResponseMetadata`].
    pub async fn send_with_metadata<R: XrpcRequest>(
        &self,
        params: R::Params,
        input: R::Input,
        options: &CallOptions,
    ) -> Result<(R::Output, ResponseMetadata), XrpcClientError<R::Error>> {
        let (xrpc, effective) = self.effective_call(options).await;
        xrpc.send_with_metadata::<R>(params, input, &effective)
            .await
    }

    /// Executes a raw XRPC query (`GET`).
    pub async fn query(
        &self,
        nsid: &str,
        params: impl IntoIterator<Item = (impl AsRef<str>, impl AsRef<str>)>,
        options: &CallOptions,
    ) -> Result<XrpcResponse, XrpcClientError> {
        let (xrpc, effective) = self.effective_call(options).await;
        xrpc.query(nsid, params, &effective).await
    }

    /// Executes a raw XRPC procedure (`POST`).
    pub async fn procedure(
        &self,
        nsid: &str,
        params: impl IntoIterator<Item = (impl AsRef<str>, impl AsRef<str>)>,
        body: Option<XrpcBody>,
        options: &CallOptions,
    ) -> Result<XrpcResponse, XrpcClientError> {
        let (xrpc, effective) = self.effective_call(options).await;
        xrpc.procedure(nsid, params, body, &effective).await
    }

    /// Strips image metadata (when `strip_metadata` is true) and uploads a blob via
    /// `com.atproto.repo.uploadBlob`.
    pub async fn upload_blob(
        &self,
        data: Bytes,
        mime_type: &str,
        strip_metadata: bool,
        max_bytes: Option<usize>,
        options: &CallOptions,
    ) -> Result<upload_blob::Output, ClientError> {
        let payload = if strip_metadata {
            ImageMetadataStripper::strip_metadata(&data, mime_type)?
        } else {
            data
        };
        let (xrpc, effective) = self.effective_call(options).await;
        Ok(xrpc
            .upload_blob(payload, mime_type, max_bytes, &effective)
            .await?)
    }

    async fn sync_active_account_pipeline_if_needed(&self) -> Result<(), ClientError> {
        let epoch = self.account_manager.selection_epoch();
        if self.state.read().await.synced_selection_epoch == epoch {
            return Ok(());
        }
        let mut state = self.state.write().await;
        let epoch = self.account_manager.selection_epoch();
        if state.synced_selection_epoch == epoch {
            return Ok(());
        }
        self.auth_manager.invalidate_continuity().await;
        if let Some(did) = self.account_manager.current_did().await? {
            self.auth_manager.select_oauth_account(&did).await?;
            if let Some(account) = self.account_manager.get_account(&did).await?
                && let Ok(url) = Url::parse(&account.pds)
            {
                let xrpc = build_xrpc_client(
                    &url,
                    &self.transport,
                    &self.auth_manager,
                    &state.headers,
                    &state.service_dids,
                    state.labelers.as_deref(),
                    state.request_ids,
                )?;
                state.base_url = url;
                state.xrpc = xrpc;
            }
        }
        state.synced_selection_epoch = epoch;
        Ok(())
    }

    async fn effective_call(&self, options: &CallOptions) -> (XrpcClient, CallOptions) {
        let _ = self.sync_active_account_pipeline_if_needed().await;
        let state = self.state.read().await;
        let continuity = self.auth_manager.auth_continuity_snapshot().await;
        let expected_did = self.account_manager.current_did().await.ok().flatten();
        let mut effective = options.clone();
        if effective.accept_labelers.is_none()
            && let Some(ref labelers) = state.labelers
        {
            effective.accept_labelers = Some(labelers.clone());
        }
        (
            state
                .xrpc
                .clone()
                .with_auth_provider(self.auth_manager.bind_continuity(continuity, expected_did)),
            effective,
        )
    }
}

fn default_service_dids() -> BTreeMap<String, String> {
    [
        (
            "app.bsky".to_owned(),
            "did:web:api.bsky.app#bsky_appview".to_owned(),
        ),
        (
            "chat.bsky".to_owned(),
            "did:web:api.bsky.chat#bsky_chat".to_owned(),
        ),
    ]
    .into()
}

fn build_xrpc_client(
    base_url: &Url,
    transport: &SharedTransport,
    auth_manager: &Arc<AuthManager>,
    headers: &HeaderMap,
    service_dids: &BTreeMap<String, String>,
    labelers: Option<&[XrpcLabeler]>,
    request_ids: bool,
) -> Result<XrpcClient, TransportError> {
    let provider: Arc<dyn AuthProvider> = auth_manager.clone();
    let mut client = XrpcClient::new(base_url.clone(), Arc::clone(transport))?
        .with_auth_provider(provider)
        .with_headers(headers.clone())
        .with_service_dids(service_dids.clone())
        .with_request_ids(request_ids);
    if let Some(labelers) = labelers {
        client = client.with_labelers(labelers.to_vec());
    }
    Ok(client)
}
