//! Replay protection for presented space credentials and HTTP signatures.

use std::collections::HashMap;
use std::sync::Mutex;

use petrel_crypto::rt::{BoxFuture, MaybeSend, MaybeSync};

use crate::error::{Result, SpaceError};

/// Default clock skew leeway for replay expiration pruning (seconds).
pub const DEFAULT_REPLAY_CLOCK_SKEW_SECS: i64 = 60;

/// Storage interface for recording seen presentation replay keys until their expiry.
pub trait SignatureReplayStore: MaybeSend + MaybeSync {
    /// Atomically check whether `key` has already been seen (and is still active at `now`)
    /// and record it until `expires_at` if fresh.
    ///
    /// Returns `Ok(true)` if the presentation is fresh and recorded, or `Ok(false)` on replay.
    fn check_and_record(&self, key: &str, expires_at: i64, now: i64)
    -> BoxFuture<'_, Result<bool>>;
}

/// Thread-safe in-memory replay cache suitable for single-process hosts and tests.
#[derive(Debug)]
pub struct InMemorySignatureReplayCache {
    max_entries: usize,
    entries: Mutex<HashMap<String, i64>>,
}

impl Default for InMemorySignatureReplayCache {
    fn default() -> Self {
        Self::new(100_000)
    }
}

impl InMemorySignatureReplayCache {
    /// Create a replay cache capped at `max_entries` live entries.
    pub fn new(max_entries: usize) -> Self {
        Self {
            max_entries: max_entries.max(1),
            entries: Mutex::new(HashMap::new()),
        }
    }

    /// Number of currently tracked entries (including unpruned entries).
    pub fn len(&self) -> usize {
        self.entries.lock().map_or(0, |guard| guard.len())
    }

    /// Whether the cache currently holds zero entries.
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

impl SignatureReplayStore for InMemorySignatureReplayCache {
    fn check_and_record(
        &self,
        key: &str,
        expires_at: i64,
        now: i64,
    ) -> BoxFuture<'_, Result<bool>> {
        let key = key.to_owned();
        Box::pin(async move {
            let mut guard = self
                .entries
                .lock()
                .map_err(|_| SpaceError::Storage("replay cache mutex poisoned".to_owned()))?;

            if let Some(&existing_exp) = guard.get(&key)
                && existing_exp >= now
            {
                return Ok(false);
            }

            if guard.len() >= self.max_entries {
                guard.retain(|_, &mut exp| exp >= now);
            }
            if guard.len() >= self.max_entries
                && let Some(oldest_key) = guard
                    .iter()
                    .min_by_key(|(_, exp)| *exp)
                    .map(|(k, _)| k.clone())
            {
                guard.remove(&oldest_key);
            }

            guard.insert(key, expires_at);
            Ok(true)
        })
    }
}

/// Compute the deterministic replay cache key for a credential presentation.
pub fn replay_key(iss: &str, nonce: &str) -> String {
    format!("{iss}\0{nonce}")
}

/// Compute the timestamp until which a presentation's nonce remains valid and must be remembered:
/// `min(created + max_signature_age_secs, expires + max_clock_skew_secs, credential_exp + credential_expiry_skew_secs)`.
pub fn replay_window_end(
    created: Option<i64>,
    expires: Option<i64>,
    credential_exp: i64,
    max_signature_age_secs: i64,
    max_clock_skew_secs: i64,
    credential_expiry_skew_secs: i64,
) -> i64 {
    let mut bound = credential_exp.saturating_add(credential_expiry_skew_secs);
    if let Some(c) = created {
        bound = bound.min(c.saturating_add(max_signature_age_secs));
    }
    if let Some(e) = expires {
        bound = bound.min(e.saturating_add(max_clock_skew_secs));
    }
    bound
}

/// Check and record a verified credential presentation in `store`.
///
/// Presentations without a `nonce` are untracked (returns `Ok(())`).
#[allow(clippy::too_many_arguments)]
pub async fn check_presentation_replay<S: SignatureReplayStore + ?Sized>(
    store: &S,
    iss: &str,
    nonce: Option<&str>,
    created: Option<i64>,
    expires: Option<i64>,
    credential_exp: i64,
    max_signature_age_secs: i64,
    max_clock_skew_secs: i64,
    credential_expiry_skew_secs: i64,
    now: i64,
) -> Result<()> {
    let Some(nonce) = nonce else {
        return Ok(());
    };
    let key = replay_key(iss, nonce);
    let expires_at = replay_window_end(
        created,
        expires,
        credential_exp,
        max_signature_age_secs,
        max_clock_skew_secs,
        credential_expiry_skew_secs,
    );
    let fresh = store.check_and_record(&key, expires_at, now).await?;
    if !fresh {
        return Err(SpaceError::SignatureReplay);
    }
    Ok(())
}
