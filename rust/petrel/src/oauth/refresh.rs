use std::collections::VecDeque;

use petrel_core::Did;

use super::{
    OAuthClient, OAuthError, OAuthProtocolError, Session, SessionRecord,
    client::{TokenResponse, require_success},
    protocol::{AsEndpoint, retry_delay, unix_now},
};
use crate::{
    crypto::{random_bytes, sha256},
    net::TransportError,
    storage::{AuthEvent, PendingRefresh, RefreshLease, RefreshLeaseAcquire, StoreError},
};

const REFRESH_LEASE_TTL_SECS: u64 = 60;
const MAX_LEASE_WAIT_MS: u32 = 5_000;

#[derive(Default)]
pub(super) struct RefreshState {
    used: VecDeque<[u8; 32]>,
    consecutive_failures: u8,
    retry_after: u64,
    pending: Option<PendingRefresh>,
}

impl RefreshState {
    fn burn(&mut self, token: &str) -> Result<[u8; 32], OAuthError> {
        let hash = sha256(token.as_bytes());
        if self.used.contains(&hash) {
            return Err(OAuthError::UsedRefreshToken);
        }
        if self.used.len() == 64 {
            self.used.pop_front();
        }
        self.used.push_back(hash);
        Ok(hash)
    }

    fn failure(&mut self, now: u64, error: &OAuthError) {
        let (base, cap): (u64, u64) = match error {
            // A challenge handled by XRPC or the AS sender does not count.
            OAuthError::MissingNonce | OAuthError::NonceRetryExhausted => return,
            OAuthError::Metadata(_) => (60, 7_200),
            OAuthError::Protocol(OAuthProtocolError::Transport(_))
            | OAuthError::ServerStatus(500..=599) => (30, 3_600),
            _ => (300, 1_800),
        };
        self.consecutive_failures = self.consecutive_failures.saturating_add(1);
        if self.consecutive_failures >= 3 {
            let backoff = base * (1_u64 << (self.consecutive_failures - 3).min(6));
            let jitter = random_bytes::<1>().map_or(128, |bytes| u64::from(bytes[0]));
            let seconds = (backoff * (768 + 2 * jitter) / 1024).min(cap);
            self.retry_after = now.saturating_add(seconds);
        }
    }

    fn success(&mut self) {
        self.consecutive_failures = 0;
        self.retry_after = 0;
    }
}

/// A burned refresh token whose exchange has not returned yet. Dropping it
/// unsettled, as happens when the caller drops the refresh future, releases
/// the token so a later refresh can use it.
struct Burned<'a> {
    state: &'a mut RefreshState,
    digest: [u8; 32],
    settled: bool,
}

impl Burned<'_> {
    /// Marks the exchange as returned. The caller then decides whether the
    /// token stays burned.
    fn settle(mut self) {
        self.settled = true;
    }
}

impl Drop for Burned<'_> {
    fn drop(&mut self) {
        if !self.settled {
            let digest = self.digest;
            self.state.used.retain(|used| *used != digest);
        }
    }
}

impl OAuthClient {
    pub(super) fn missing_session(&self, did: &Did) -> OAuthError {
        self.storage
            .emit_auth_event(&AuthEvent::SessionMissing { did: did.clone() });
        OAuthError::MissingSession
    }

    /// Returns the current in-memory or durable session for a DID.
    pub async fn session(&self, did: &Did) -> Result<Option<Session>, OAuthError> {
        Ok(self.session_record(did).await?.map(|record| record.session))
    }

    pub(super) async fn session_record(
        &self,
        did: &Did,
    ) -> Result<Option<SessionRecord>, OAuthError> {
        let lock = self.account_lock(did);
        let mut refresh = lock.lock().await;
        self.read_record(did, &mut refresh).await
    }

    async fn read_record(
        &self,
        did: &Did,
        refresh: &mut RefreshState,
    ) -> Result<Option<SessionRecord>, OAuthError> {
        let committed = self.storage.get_session(did).await?;
        let Some(current) = committed else {
            refresh.pending = None;
            return Ok(None);
        };
        let pending = match &refresh.pending {
            Some(pending) => Some(pending.clone()),
            None => self.storage.get_pending_refresh(did).await?,
        };
        let Some(pending) = pending else {
            return Ok(Some(current));
        };
        if pending.based_on != current.generation() {
            refresh.pending = None;
            self.clear_pending_refresh(&pending).await;
            return Ok(Some(current));
        }

        match self.commit_refresh(&current, &pending.record).await {
            Ok(true) => {
                refresh.pending = None;
                self.clear_pending_refresh(&pending).await;
                Ok(Some(pending.record))
            }
            Ok(false) => {
                refresh.pending = None;
                self.clear_pending_refresh(&pending).await;
                Ok(self.storage.get_session(did).await?)
            }
            Err(_) => {
                // Reading succeeded and this is the predecessor's replacement.
                // Preserve it in memory if the durable promotion still fails.
                let record = pending.record.clone();
                refresh.pending = Some(pending);
                Ok(Some(record))
            }
        }
    }

    async fn commit_refresh(
        &self,
        old: &SessionRecord,
        new: &SessionRecord,
    ) -> Result<bool, StoreError> {
        match self.storage.compare_and_swap_session(old, new).await {
            Err(StoreError::Unsupported) => {
                // Embedders without CAS must serialize mutations across clients.
                let current = self.storage.get_session(&old.session.did).await?;
                if current.is_none_or(|record| record.generation() != old.generation()) {
                    return Ok(false);
                }
                self.storage.save_session(new).await?;
                Ok(true)
            }
            result => result,
        }
    }

    async fn clear_pending_refresh(&self, pending: &PendingRefresh) {
        if let Err(StoreError::Unsupported) = self
            .storage
            .compare_and_delete_pending_refresh(pending)
            .await
        {
            let _ = self
                .storage
                .delete_pending_session(&pending.record.session.did)
                .await;
        }
    }

    /// Refreshes the account session if due, or immediately if `force` is set.
    /// Concurrent callers that observed the same session share one exchange.
    pub async fn refresh(&self, did: &Did, force: bool) -> Result<Session, OAuthError> {
        // Read the observed generation before waiting for its refresh. A
        // caller that begins after a refresh started still sees the old one.
        let observed = self
            .storage
            .get_session(did)
            .await?
            .ok_or_else(|| self.missing_session(did))?;
        self.refresh_after(&observed, force).await
    }

    pub(super) async fn refresh_after(
        &self,
        observed: &SessionRecord,
        force: bool,
    ) -> Result<Session, OAuthError> {
        let did = &observed.session.did;
        let lock = self.account_lock(did);
        let mut state = lock.lock().await;
        let (mut current, lease) = self
            .acquire_refresh_slot(did, observed, force, &mut state)
            .await?;
        if current.generation() != observed.generation()
            || (!force && !current.session.needs_refresh(unix_now()?))
        {
            if let Some(lease) = lease.as_ref() {
                self.storage.release_refresh_lease(did, lease).await;
            }
            return Ok(current.session);
        }

        // Re-check once more after acquiring a cross-instance lease in case
        // a peer finished publishing a replacement just before handover.
        if lease.is_some() {
            let Some(latest) = self.read_record(did, &mut state).await? else {
                self.release_lease(did, lease.as_ref()).await;
                drop(state);
                return Err(self.missing_session(did));
            };
            if latest.generation() != observed.generation() {
                self.release_lease(did, lease.as_ref()).await;
                return Ok(latest.session);
            }
            current = latest;
        }

        let outcome = self.execute_refresh(did, &current, force, &mut state).await;
        self.release_lease(did, lease.as_ref()).await;
        outcome
    }

    async fn release_lease(&self, did: &Did, lease: Option<&RefreshLease>) {
        if let Some(lease) = lease {
            self.storage.release_refresh_lease(did, lease).await;
        }
    }

    async fn acquire_refresh_slot(
        &self,
        did: &Did,
        observed: &SessionRecord,
        force: bool,
        state: &mut RefreshState,
    ) -> Result<(SessionRecord, Option<RefreshLease>), OAuthError> {
        let mut waited_ms: u32 = 0;
        loop {
            let Some(current) = self.read_record(did, state).await? else {
                return Err(self.missing_session(did));
            };
            if current.generation() != observed.generation() {
                return Ok((current, None));
            }
            let now = unix_now()?;
            if !force && !current.session.needs_refresh(now) {
                return Ok((current, None));
            }
            if state.pending.is_some() {
                return Err(OAuthError::RefreshPersistencePending);
            }
            if current.session.refresh_token().is_none() {
                if !force && now < current.session.expires_at() {
                    return Ok((current, None));
                }
                return Err(OAuthError::ExpiredSession);
            }
            if now < state.retry_after {
                return Err(OAuthError::RefreshBackoff);
            }

            match self
                .storage
                .try_acquire_refresh_lease(
                    did,
                    self.instance_id,
                    current.generation(),
                    now,
                    REFRESH_LEASE_TTL_SECS,
                )
                .await?
            {
                RefreshLeaseAcquire::Acquired(lease) => return Ok((current, Some(lease))),
                RefreshLeaseAcquire::Unsupported => return Ok((current, None)),
                RefreshLeaseAcquire::HeldByPeer => {
                    if waited_ms >= MAX_LEASE_WAIT_MS {
                        return Err(OAuthError::RefreshBackoff);
                    }
                    let step = 50_u32.min(MAX_LEASE_WAIT_MS - waited_ms);
                    retry_delay(step).await;
                    waited_ms += step;
                }
            }
        }
    }

    async fn execute_refresh(
        &self,
        did: &Did,
        current: &SessionRecord,
        force: bool,
        state: &mut RefreshState,
    ) -> Result<Session, OAuthError> {
        let now = unix_now()?;
        if state.pending.is_some() {
            // The active slot is still the predecessor. A second rotation
            // would create a replacement that cannot be safely published.
            return Err(OAuthError::RefreshPersistencePending);
        }
        let Some(token) = current.session.refresh_token() else {
            if !force && now < current.session.expires_at() {
                return Ok(current.session.clone());
            }
            return Err(OAuthError::ExpiredSession);
        };
        if now < state.retry_after {
            return Err(OAuthError::RefreshBackoff);
        }
        let server = self
            .resolve_account_server(&current.account)
            .await
            .inspect_err(|error| state.failure(now, error))?;
        let key = self
            .bound_key(&current.dpop_key_id, &current.dpop_jkt)
            .await?;
        let digest = state.burn(token)?;
        // If the caller drops this future while the exchange is in flight,
        // for example while the client assertion backend is still answering,
        // release the token again. Otherwise it would stay burned with no
        // replacement and every later refresh would fail with
        // `UsedRefreshToken`. A drop after the authorization server rotated
        // the token loses that rotation either way; the next attempt then
        // gets `invalid_grant` instead of a local error.
        let burned = Burned {
            state,
            digest,
            settled: false,
        };
        let response = self
            .protocol
            .send_as(
                &server,
                AsEndpoint::Token,
                &[("grant_type", "refresh_token"), ("refresh_token", token)],
                &*key,
            )
            .await;
        burned.settle();
        let result = match response {
            Ok(response) => match require_success(&response) {
                Ok(()) => {
                    let session = TokenResponse::decode(response.body()).and_then(|tokens| {
                        let subject = tokens.did()?;
                        if &subject != did {
                            return Err(OAuthError::InvalidResponse);
                        }
                        tokens.session(subject, unix_now()?, Some(token), &current.dpop_jkt)
                    });
                    if session.is_err() {
                        self.revoke_returned(&server, &*key, response.body()).await;
                    }
                    session
                }
                Err(error) => Err(error),
            },
            Err(error) => Err(error.into()),
        };

        match result {
            Ok(session) => {
                if session.refresh_token() == Some(token) {
                    // RFC 6749 allows the issuer to keep the existing refresh token.
                    state.used.retain(|used| *used != digest);
                }
                state.success();
                let mut new = current.clone();
                new.session = session.clone();
                new.account.authorization_server = Some(server.metadata().clone());
                new.account.expected_issuer = Some(server.issuer().to_owned());
                self.persist_refresh(state, current, new).await?;
                Ok(session)
            }
            Err(error) => {
                if retryable_refresh_failure(&error) {
                    state.used.retain(|used| *used != digest);
                }
                state.failure(unix_now().unwrap_or(now), &error);
                if error == OAuthError::InvalidGrant {
                    self.storage
                        .emit_auth_event(&AuthEvent::RefreshTokenInvalid { did: did.clone() });
                }
                Err(error)
            }
        }
    }

    async fn persist_refresh(
        &self,
        state: &mut RefreshState,
        old: &SessionRecord,
        current: SessionRecord,
    ) -> Result<(), OAuthError> {
        let pending = PendingRefresh {
            based_on: old.generation(),
            record: current,
        };
        // Keep the replacement under the account lock before the next await,
        // including if the caller drops its future during a storage operation.
        state.pending = Some(pending.clone());
        let durable_pending = self.storage.save_pending_refresh(&pending).await.is_ok();
        for attempt in 0..3 {
            match self.commit_refresh(old, &pending.record).await {
                Ok(true) => {
                    state.pending = None;
                    if durable_pending {
                        self.clear_pending_refresh(&pending).await;
                    }
                    return Ok(());
                }
                Ok(false) => {
                    state.pending = None;
                    if durable_pending {
                        self.clear_pending_refresh(&pending).await;
                    }
                    let committed = self.storage.get_session(&old.session.did).await?;
                    return if committed
                        .is_some_and(|record| record.generation() == pending.record.generation())
                    {
                        Ok(())
                    } else {
                        Err(OAuthError::SessionChanged)
                    };
                }
                Err(_) if attempt < 2 => retry_delay(150 << attempt).await,
                Err(_) => {
                    if !durable_pending {
                        tracing::warn!(
                            "rotated OAuth session is only available until this process exits"
                        );
                    }
                }
            }
        }
        Ok(())
    }

    /// Revokes the current token with the authorization server if it has a
    /// revocation endpoint. The server must confirm with HTTP 200.
    pub async fn revoke_session(&self, did: &Did) -> Result<bool, OAuthError> {
        let lock = self.account_lock(did);
        let mut state = lock.lock().await;
        match self.read_record(did, &mut state).await? {
            Some(record) => Ok(self.revoke_record(&record).await),
            None => Ok(false),
        }
    }

    async fn revoke_record(&self, record: &SessionRecord) -> bool {
        let Ok(server) = self.resolve_account_server(&record.account).await else {
            return false;
        };
        let Ok(key) = self.bound_key(&record.dpop_key_id, &record.dpop_jkt).await else {
            return false;
        };
        let token = record
            .session
            .refresh_token()
            .unwrap_or_else(|| record.session.access_token());
        self.revoke(&server, &*key, token).await
    }

    /// Tries upstream revocation, then clears local tokens, nonces and the DPoP key.
    pub async fn logout(&self, did: &Did) -> Result<bool, OAuthError> {
        let lock = self.account_lock(did);
        let mut state = lock.lock().await;
        let Some(record) = self.read_record(did, &mut state).await? else {
            return Ok(false);
        };
        let revoked = self.revoke_record(&record).await;

        let pending_result = self.storage.delete_pending_session(did).await;
        let session_result = self.storage.delete_session(did).await;
        let key_result = self.keys.delete(&record.dpop_key_id).await;
        self.protocol.nonces.clear_key(&record.dpop_jkt);
        self.resource_nonces.clear_key(&record.dpop_jkt);
        *state = RefreshState::default();
        pending_result?;
        session_result?;
        key_result?;
        let selection_result = self.storage.clear_current_did_if_selected(did).await;
        drop(state);
        self.storage
            .emit_auth_event(&AuthEvent::Logout { did: did.clone() });
        selection_result?;
        Ok(revoked)
    }
}

fn retryable_refresh_failure(error: &OAuthError) -> bool {
    matches!(
        error,
        OAuthError::NonceRetryExhausted
            | OAuthError::ServerStatus(429 | 500..=599)
            | OAuthError::Protocol(
                OAuthProtocolError::Transport(
                    TransportError::Timeout
                        | TransportError::Connect(_)
                        | TransportError::ConnectionLost(_)
                ) | OAuthProtocolError::AssertionBackend(super::AssertionBackendError::Rejected {
                    status: 429 | 500..=599,
                    ..
                })
            )
    )
}

#[cfg(test)]
impl OAuthClient {
    pub(super) async fn allow_next_refresh_probe(&self, did: &Did) {
        let account = self.account_lock(did);
        let mut state = account.lock().await;
        assert!(state.retry_after != 0);
        state.retry_after = 0;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), test)]
    fn breaker_opens_after_three_transient_errors_and_resets_after_success() {
        let mut state = RefreshState::default();
        let error = OAuthError::ServerStatus(503);
        state.failure(100, &error);
        state.failure(101, &error);
        assert_eq!(state.retry_after, 0);
        state.failure(102, &error);
        assert!((124..=139).contains(&state.retry_after));
        let retry = state.retry_after;
        state.failure(retry, &error);
        assert!((retry + 45..=retry + 74).contains(&state.retry_after));
        state.success();
        assert_eq!(state.retry_after, 0);
        assert_eq!(state.consecutive_failures, 0);
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), test)]
    fn breaker_does_not_count_nonce_challenges_twice_or_burn_a_token_twice() {
        let mut state = RefreshState::default();
        state.failure(100, &OAuthError::NonceRetryExhausted);
        assert_eq!(state.consecutive_failures, 0);
        assert!(state.burn("synthetic-refresh-token").is_ok());
        state.failure(101, &OAuthError::InvalidGrant);
        assert_eq!(
            state.burn("synthetic-refresh-token"),
            Err(OAuthError::UsedRefreshToken)
        );
        assert_eq!(state.consecutive_failures, 1);
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), test)]
    fn refresh_margin_is_capped_and_an_access_only_session_runs_to_expiry() {
        let did: Did = "did:plc:abcdefghijklmnopqrstuvwx".parse().unwrap();
        let scope = petrel_oauth_scopes::ScopeSet::parse("atproto").unwrap();
        let refreshable = |ttl| {
            Session::new(
                did.clone(),
                "access".into(),
                Some("refresh".into()),
                1000,
                ttl,
                &scope,
            )
        };
        assert!(!refreshable(50).needs_refresh(1039));
        assert!(refreshable(50).needs_refresh(1040));
        assert!(!refreshable(600).needs_refresh(1539));
        assert!(refreshable(600).needs_refresh(1540));
        let access_only = Session::new(did, "access".into(), None, 1000, 300, &scope);
        assert!(!access_only.needs_refresh(1299));
        assert!(access_only.needs_refresh(1300));
    }
}
