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
};

#[derive(Default)]
pub(super) struct RefreshState {
    used: VecDeque<[u8; 32]>,
    consecutive_failures: u8,
    retry_after: u64,
    pending: Option<SessionRecord>,
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
            OAuthError::MissingNonce => return,
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

impl OAuthClient {
    /// Returns the current in-memory or durable session for a DID.
    pub async fn session(&self, did: &Did) -> Result<Option<Session>, OAuthError> {
        Ok(self.session_record(did).await?.map(|record| record.session))
    }

    pub(super) async fn session_record(
        &self,
        did: &Did,
    ) -> Result<Option<SessionRecord>, OAuthError> {
        let lock = self.account_lock(did);
        let refresh = lock.lock().await;
        self.read_record(did, &refresh).await
    }

    async fn read_record(
        &self,
        did: &Did,
        refresh: &RefreshState,
    ) -> Result<Option<SessionRecord>, OAuthError> {
        if let Some(record) = &refresh.pending {
            return Ok(Some(record.clone()));
        }
        Ok(self.storage.get_session(did).await?)
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
            .ok_or(OAuthError::MissingSession)?;
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
        let current = self
            .read_record(did, &state)
            .await?
            .ok_or(OAuthError::MissingSession)?;
        if current.dpop_jkt != observed.dpop_jkt
            || current.session.access_token() != observed.session.access_token()
            || current.session.created_at != observed.session.created_at
            || current.session.refresh_token() != observed.session.refresh_token()
        {
            return Ok(current.session);
        }
        let now = unix_now()?;
        if !force && !current.session.needs_refresh(now) {
            return Ok(current.session);
        }
        let Some(token) = current.session.refresh_token() else {
            if !force && now < current.session.expires_at() {
                return Ok(current.session);
            }
            return Err(OAuthError::ExpiredSession);
        };
        if now < state.retry_after {
            return Err(OAuthError::RefreshBackoff);
        }
        let server = self
            .validate_account(&current.account)
            .inspect_err(|error| state.failure(now, error))?;
        let key = self
            .bound_key(&current.dpop_key_id, &current.dpop_jkt)
            .await?;
        let digest = state.burn(token)?;
        let response = self
            .protocol
            .send_as(
                &server,
                AsEndpoint::Token,
                &[("grant_type", "refresh_token"), ("refresh_token", token)],
                &*key,
            )
            .await;
        let result = match response {
            Ok(response) => match require_success(&response) {
                Ok(()) => {
                    let session = TokenResponse::decode(response.body()).and_then(|tokens| {
                        let subject = tokens.did()?;
                        if &subject != did {
                            return Err(OAuthError::InvalidResponse);
                        }
                        tokens.session(subject, unix_now()?, Some(token))
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
                state.success();
                let new = SessionRecord {
                    session: session.clone(),
                    ..current
                };
                self.persist_refresh(&mut state, new).await;
                Ok(session)
            }
            Err(error) => {
                if retryable_refresh_failure(&error) {
                    state.used.retain(|used| *used != digest);
                }
                state.failure(now, &error);
                Err(error)
            }
        }
    }

    async fn persist_refresh(&self, state: &mut RefreshState, current: SessionRecord) {
        for attempt in 0..3 {
            if self.storage.save_session(&current).await.is_ok() {
                state.pending = None;
                let _ = self
                    .storage
                    .delete_pending_session(&current.session.did)
                    .await;
                return;
            }
            if attempt < 2 {
                retry_delay(150 << attempt).await;
            }
        }
        // The refresh token was accepted by the server. Keep its replacement
        // available even if the durable session slot cannot be updated yet.
        let _ = self.storage.save_pending_session(&current).await;
        state.pending = Some(current);
    }

    /// Tries upstream revocation, then clears local tokens, nonces and the DPoP key.
    pub async fn logout(&self, did: &Did) -> Result<bool, OAuthError> {
        let lock = self.account_lock(did);
        let mut state = lock.lock().await;
        let Some(record) = self.read_record(did, &state).await? else {
            return Ok(false);
        };
        let revoked = match (
            self.validate_account(&record.account),
            self.bound_key(&record.dpop_key_id, &record.dpop_jkt).await,
        ) {
            (Ok(server), Ok(key)) => {
                let token = record
                    .session
                    .refresh_token()
                    .unwrap_or_else(|| record.session.access_token());
                self.revoke(&server, &*key, token).await
            }
            _ => false,
        };

        let pending_result = self.storage.delete_pending_session(did).await;
        let session_result = self.storage.delete_session(did).await;
        let key_result = self.keys.delete(&record.dpop_key_id).await;
        self.protocol.nonces.clear_key(&record.dpop_jkt);
        *state = RefreshState::default();
        pending_result?;
        session_result?;
        key_result?;
        Ok(revoked)
    }
}

fn retryable_refresh_failure(error: &OAuthError) -> bool {
    matches!(
        error,
        OAuthError::ServerStatus(429 | 500..=599)
            | OAuthError::Protocol(OAuthProtocolError::Transport(
                TransportError::Timeout | TransportError::Connect(_)
            ))
            | OAuthError::Protocol(OAuthProtocolError::AssertionBackend(
                super::AssertionBackendError::Rejected {
                    status: 429 | 500..=599,
                    ..
                }
            ))
    )
}
