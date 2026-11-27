use std::{collections::VecDeque, future::Future, sync::Arc};

use async_lock::MutexGuardArc;
use futures_util::future::{Either, select};
use petrel_core::Did;

use super::{
    OAuthClient, OAuthError, OAuthProtocolError, Session, SessionRecord,
    client::{TokenResponse, require_success},
    metadata::ValidatedAuthorizationServer,
    protocol::{AsEndpoint, OAuthProtocol, retry_delay, unix_now},
};
use crate::{
    auth::background::{HAS_TIMER, run_detached},
    crypto::{DpopSigner, random_bytes, sha256},
    storage::{
        AuthEvent, PendingRefresh, RefreshLease, RefreshLeaseAcquire, SessionStore, StoreError,
    },
};

/// How long a cross-instance refresh lease lasts without renewal. A crashed
/// holder blocks peers for at most this long.
const REFRESH_LEASE_TTL_SECS: u64 = 60;
/// The holder renews its lease this often while the exchange runs. A worst-case
/// exchange is about 180 s (two nonce attempts, each a 2 x 30 s client
/// assertion plus a 30 s token request), three times the TTL, so a lease that
/// was never renewed would lapse mid-exchange and let a peer replay the token.
#[cfg(not(test))]
const LEASE_RENEW_INTERVAL_MS: u32 = 20_000;
#[cfg(test)]
const LEASE_RENEW_INTERVAL_MS: u32 = 100;
/// The longest a caller waits for a peer's refresh before reporting
/// [`OAuthError::RefreshBackoff`]. It covers a worst-case renewed exchange.
const MAX_PEER_WAIT_SECS: u64 = 4 * REFRESH_LEASE_TTL_SECS;
/// Lease polls allowed when the build has no timer, so the wait stays bounded.
const MAX_UNTIMED_LEASE_POLLS: u32 = 100;

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
/// unsettled releases the token so a later refresh can use it. With a runtime
/// the exchange is detached and runs to completion, so this happens only when
/// the exchange runs on a caller's task that is dropped (see
/// [`crate::auth::background`]).
struct Burned<'a> {
    /// `None` once settled.
    state: Option<&'a mut RefreshState>,
    digest: [u8; 32],
}

impl<'a> Burned<'a> {
    /// Marks the exchange as returned and hands the state back. The caller
    /// then decides whether the token stays burned.
    fn settle(mut self) -> &'a mut RefreshState {
        self.state
            .take()
            .unwrap_or_else(|| unreachable!("a burned token is settled once"))
    }
}

impl Drop for Burned<'_> {
    fn drop(&mut self) {
        if let Some(state) = self.state.take() {
            let digest = self.digest;
            state.used.retain(|used| *used != digest);
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
            clear_pending_refresh(&self.storage, &pending).await;
            return Ok(Some(current));
        }

        match commit_refresh(&self.storage, &current, &pending.record).await {
            Ok(true) => {
                refresh.pending = None;
                clear_pending_refresh(&self.storage, &pending).await;
                Ok(Some(pending.record))
            }
            Ok(false) => {
                refresh.pending = None;
                clear_pending_refresh(&self.storage, &pending).await;
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

    /// Refreshes the account session if due, or immediately if `force` is set.
    /// Concurrent callers that observed the same session share one exchange.
    pub async fn refresh(&self, did: &Did, force: bool) -> Result<Session, OAuthError> {
        let (session, _) = self.refresh_with_status(did, force).await?;
        Ok(session)
    }

    pub(crate) async fn refresh_with_status(
        &self,
        did: &Did,
        force: bool,
    ) -> Result<(Session, bool), OAuthError> {
        // Read the observed generation before waiting for its refresh. A
        // caller that begins after a refresh started still sees the old one.
        let observed = self
            .storage
            .get_session(did)
            .await?
            .ok_or_else(|| self.missing_session(did))?;
        let before_gen = observed.generation();
        let session = self.refresh_after(&observed, force).await?;
        let changed = force
            || self
                .storage
                .get_session(did)
                .await?
                .is_some_and(|after| after.generation() != before_gen);
        Ok((session, changed))
    }

    /// Debug-only helper simulating an ambiguous refresh timeout: performs one real token
    /// exchange and stores the replacement only in durable `PENDING_SESSION` storage (clearing
    /// in-memory `pending`), leaving the old committed `SESSION` intact so subsequent calls
    /// exercise `PendingRefresh` crash/timeout recovery.
    #[cfg(debug_assertions)]
    pub async fn simulate_ambiguous_refresh_timeout(&self, did: &Did) -> Result<(), OAuthError> {
        let observed = self
            .storage
            .get_session(did)
            .await?
            .ok_or_else(|| self.missing_session(did))?;
        let lock = self.account_lock(did);
        let mut state = lock.lock_arc().await;
        let (current, lease) = self
            .acquire_refresh_slot(did, &observed, true, &mut state)
            .await?;
        self.execute_refresh(did, &current, true, state, lease, false)
            .await
            .map(|_| ())
    }

    pub(super) async fn refresh_after(
        &self,
        observed: &SessionRecord,
        force: bool,
    ) -> Result<Session, OAuthError> {
        let did = &observed.session.did;
        let lock = self.account_lock(did);
        let mut state = lock.lock_arc().await;
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

        self.execute_refresh(did, &current, force, state, lease, true)
            .await
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
        let wait_deadline = unix_now()?.saturating_add(MAX_PEER_WAIT_SECS);
        let mut polls: u32 = 0;
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
                RefreshLeaseAcquire::HeldByPeer { expires_at } => {
                    // The peer renews its lease while its exchange runs, so
                    // wait for its result (or for the lease to lapse) rather
                    // than give up while it is still working.
                    polls += 1;
                    if now >= wait_deadline || (!HAS_TIMER && polls > MAX_UNTIMED_LEASE_POLLS) {
                        return Err(OAuthError::RefreshBackoff);
                    }
                    let step = if polls <= 40 || expires_at <= now.saturating_add(1) {
                        50
                    } else {
                        250
                    };
                    retry_delay(step).await;
                }
            }
        }
    }

    /// Runs one refresh for `current` while holding the account lock, then
    /// releases `lease`. Once the token request is about to be sent, the
    /// exchange and the persistence of its result are detached from the
    /// caller: dropping this future does not stop them, and the account lock
    /// stays held until they finish, so concurrent callers wait for that
    /// exchange and then read its result instead of starting another.
    async fn execute_refresh(
        &self,
        did: &Did,
        current: &SessionRecord,
        force: bool,
        mut state: MutexGuardArc<RefreshState>,
        lease: Option<RefreshLease>,
        commit_replacement: bool,
    ) -> Result<Session, OAuthError> {
        let prepared = self.prepare_exchange(current, force, &mut state).await;
        let (server, key) = match prepared {
            Ok(Some(prepared)) => prepared,
            Ok(None) => {
                self.release_lease(did, lease.as_ref()).await;
                return Ok(current.session.clone());
            }
            Err(error) => {
                self.release_lease(did, lease.as_ref()).await;
                return Err(error);
            }
        };
        let exchange = Exchange {
            protocol: Arc::clone(&self.protocol),
            storage: self.storage.clone(),
            did: did.clone(),
            current: current.clone(),
            server,
            key,
            lease,
            commit_replacement,
        };
        run_detached(exchange.run(state)).await
    }

    /// Checks that a refresh may run and resolves what it needs. `None` means
    /// the current access-only session is still usable.
    async fn prepare_exchange(
        &self,
        current: &SessionRecord,
        force: bool,
        state: &mut RefreshState,
    ) -> Result<Option<(ValidatedAuthorizationServer, Arc<dyn DpopSigner>)>, OAuthError> {
        let now = unix_now()?;
        if state.pending.is_some() {
            // The active slot is still the predecessor. A second rotation
            // would create a replacement that cannot be safely published.
            return Err(OAuthError::RefreshPersistencePending);
        }
        if current.session.refresh_token().is_none() {
            if !force && now < current.session.expires_at() {
                return Ok(None);
            }
            return Err(OAuthError::ExpiredSession);
        }
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
        Ok(Some((server, key)))
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

/// Everything a refresh exchange needs, owned so the exchange can outlive the
/// caller's future.
struct Exchange {
    protocol: Arc<OAuthProtocol>,
    storage: SessionStore,
    did: Did,
    current: SessionRecord,
    server: ValidatedAuthorizationServer,
    key: Arc<dyn DpopSigner>,
    lease: Option<RefreshLease>,
    commit_replacement: bool,
}

impl Exchange {
    async fn run(mut self, mut state: MutexGuardArc<RefreshState>) -> Result<Session, OAuthError> {
        let outcome = self.exchange(&mut state).await;
        if let Some(lease) = self.lease.as_ref() {
            self.storage.release_refresh_lease(&self.did, lease).await;
        }
        drop(state);
        outcome
    }

    async fn exchange(&mut self, state: &mut RefreshState) -> Result<Session, OAuthError> {
        let now = unix_now()?;
        let current = &self.current;
        let Some(token) = current.session.refresh_token() else {
            return Err(OAuthError::ExpiredSession);
        };
        let digest = state.burn(token)?;
        let burned = Burned {
            state: Some(state),
            digest,
        };
        let response = keep_lease(
            &self.storage,
            &self.did,
            &mut self.lease,
            self.protocol.send_as(
                &self.server,
                AsEndpoint::Token,
                &[("grant_type", "refresh_token"), ("refresh_token", token)],
                &*self.key,
            ),
        )
        .await;
        let state = burned.settle();

        // The server consumed the token only if it answered with success or
        // definitively rejected the grant. Anything else (a transport
        // failure, a 4xx such as `invalid_dpop_proof` or `invalid_client`, a
        // proxy error, 5xx) leaves the token usable, so it is released and
        // the error is reported as non-terminal.
        //
        // A connection lost after the request was sent is ambiguous. The token
        // is released and the next refresh retries with it: if the server
        // never processed the request that refresh succeeds, and if it did
        // the rotated replacement is already lost, so the session cannot be
        // recovered either way and the retry only learns that sooner
        // (`invalid_grant`, or the rotation again where the server allows a
        // replay grace period).
        let answered = response
            .as_ref()
            .is_ok_and(|response| response.status().is_success());
        let result = match response {
            Ok(response) => match require_success(&response) {
                Ok(()) => {
                    let session = TokenResponse::decode(response.body()).and_then(|tokens| {
                        let subject = tokens.did()?;
                        if subject != self.did {
                            return Err(OAuthError::InvalidResponse);
                        }
                        tokens.session(subject, unix_now()?, Some(token), &current.dpop_jkt)
                    });
                    if session.is_err() {
                        self.protocol
                            .revoke_returned(&self.server, &*self.key, response.body())
                            .await;
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
                new.account.authorization_server = Some(self.server.metadata().clone());
                new.account.expected_issuer = Some(self.server.issuer().to_owned());
                if self.commit_replacement {
                    persist_refresh(&self.storage, state, current, new).await?;
                } else {
                    let pending = PendingRefresh {
                        based_on: current.generation(),
                        record: new,
                    };
                    self.storage.save_pending_refresh(&pending).await?;
                    // Drop the in-memory copy so recovery must promote the durable pending entry.
                    state.pending = None;
                }
                Ok(session)
            }
            Err(error) => {
                let consumed = answered || error == OAuthError::InvalidGrant;
                if !consumed {
                    state.used.retain(|used| *used != digest);
                }
                state.failure(unix_now().unwrap_or(now), &error);
                if error == OAuthError::InvalidGrant {
                    self.storage
                        .emit_auth_event(&AuthEvent::RefreshTokenInvalid {
                            did: self.did.clone(),
                        });
                }
                Err(error)
            }
        }
    }
}

/// Runs `work` while renewing `lease` in the background, so a slow exchange
/// keeps its cross-instance lease. If a peer has replaced the lease the
/// exchange still finishes; it is past the point where stopping would help.
async fn keep_lease<F: Future>(
    storage: &SessionStore,
    did: &Did,
    lease: &mut Option<RefreshLease>,
    work: F,
) -> F::Output {
    if lease.is_none() || !HAS_TIMER {
        return work.await;
    }
    let mut work = std::pin::pin!(work);
    loop {
        let tick = std::pin::pin!(retry_delay(LEASE_RENEW_INTERVAL_MS));
        match select(work.as_mut(), tick).await {
            Either::Left((output, _)) => return output,
            Either::Right(((), _)) => {
                let (Some(held), Ok(now)) = (lease.as_ref(), unix_now()) else {
                    continue;
                };
                match storage
                    .renew_refresh_lease(did, held, now, REFRESH_LEASE_TTL_SECS)
                    .await
                {
                    Ok(Some(renewed)) => *lease = Some(renewed),
                    Ok(None) => {
                        tracing::warn!("OAuth refresh lease was replaced during the exchange");
                        *lease = None;
                        return work.await;
                    }
                    // A storage hiccup: the lease still has time left, try again.
                    Err(_) => {}
                }
            }
        }
    }
}

async fn commit_refresh(
    storage: &SessionStore,
    old: &SessionRecord,
    new: &SessionRecord,
) -> Result<bool, StoreError> {
    match storage.compare_and_swap_session(old, new).await {
        Err(StoreError::Unsupported) => {
            // Embedders without CAS must serialize mutations across clients.
            let current = storage.get_session(&old.session.did).await?;
            if current.is_none_or(|record| record.generation() != old.generation()) {
                return Ok(false);
            }
            storage.save_session(new).await?;
            Ok(true)
        }
        result => result,
    }
}

async fn clear_pending_refresh(storage: &SessionStore, pending: &PendingRefresh) {
    if let Err(StoreError::Unsupported) = storage.compare_and_delete_pending_refresh(pending).await
    {
        let _ = storage
            .delete_pending_session(&pending.record.session.did)
            .await;
    }
}

async fn persist_refresh(
    storage: &SessionStore,
    state: &mut RefreshState,
    old: &SessionRecord,
    current: SessionRecord,
) -> Result<(), OAuthError> {
    let pending = PendingRefresh {
        based_on: old.generation(),
        record: current,
    };
    // Keep the replacement under the account lock before the next await,
    // including if the exchange is cancelled during a storage operation.
    state.pending = Some(pending.clone());
    let durable_pending = storage.save_pending_refresh(&pending).await.is_ok();
    for attempt in 0..3 {
        match commit_refresh(storage, old, &pending.record).await {
            Ok(true) => {
                state.pending = None;
                if durable_pending {
                    clear_pending_refresh(storage, &pending).await;
                }
                return Ok(());
            }
            Ok(false) => {
                state.pending = None;
                if durable_pending {
                    clear_pending_refresh(storage, &pending).await;
                }
                let committed = storage.get_session(&old.session.did).await?;
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
