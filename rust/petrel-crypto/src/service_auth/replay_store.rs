//! Replay protection stores for service-auth JWT `jti` nonces.

use std::collections::HashMap;
use std::fmt;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use web_time::{SystemTime, UNIX_EPOCH};

use crate::rt::{BoxFuture, MaybeSend, MaybeSync};
use crate::service_auth::key_resolver::ClockFn;

/// Errors returned by a [`ServiceAuthReplayStore`].
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum ReplayStoreError {
    /// The in-memory store reached its configured capacity of unexpired entries.
    #[error("replay store is full ({capacity} unexpired tokens)")]
    CapacityExceeded {
        /// Configured capacity limit.
        capacity: usize,
    },
    /// The underlying storage backend failed.
    #[error("{0}")]
    Backend(String),
}

/// Remembers which service-auth tokens have been used, so each `jti` is accepted once.
pub trait ServiceAuthReplayStore: MaybeSend + MaybeSync {
    /// Atomically records `(issuer, nonce)` until `expires_at`.
    ///
    /// Returns `Ok(true)` if this is the first use, or `Ok(false)` if already recorded.
    fn claim<'a>(
        &'a self,
        nonce: &'a str,
        issuer: &'a str,
        expires_at: SystemTime,
    ) -> BoxFuture<'a, Result<bool, ReplayStoreError>>;
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
struct ReplayKey {
    issuer: String,
    nonce: String,
}

struct ReplayState {
    seen: HashMap<ReplayKey, SystemTime>,
    next_sweep: SystemTime,
}

/// Process-local [`ServiceAuthReplayStore`] with capacity-bounded pruning.
pub struct InMemoryServiceAuthReplayStore {
    capacity: usize,
    clock: ClockFn,
    state: Mutex<ReplayState>,
}

impl fmt::Debug for InMemoryServiceAuthReplayStore {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("InMemoryServiceAuthReplayStore")
            .field("capacity", &self.capacity)
            .field("count", &self.len())
            .finish_non_exhaustive()
    }
}

impl Default for InMemoryServiceAuthReplayStore {
    fn default() -> Self {
        Self::new()
    }
}

impl InMemoryServiceAuthReplayStore {
    /// Creates an in-memory replay store with default capacity (100,000 entries).
    pub fn new() -> Self {
        Self::with_config(100_000, Arc::new(SystemTime::now))
    }

    /// Creates an in-memory replay store with explicit capacity and clock.
    pub fn with_config(capacity: usize, clock: ClockFn) -> Self {
        Self {
            capacity: capacity.max(1),
            clock,
            state: Mutex::new(ReplayState {
                seen: HashMap::new(),
                next_sweep: UNIX_EPOCH,
            }),
        }
    }

    /// Number of nonces currently remembered.
    pub fn len(&self) -> usize {
        self.state.lock().map_or(0, |guard| guard.seen.len())
    }

    /// Returns `true` if no nonces are currently stored.
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

impl ServiceAuthReplayStore for InMemoryServiceAuthReplayStore {
    fn claim<'a>(
        &'a self,
        nonce: &'a str,
        issuer: &'a str,
        expires_at: SystemTime,
    ) -> BoxFuture<'a, Result<bool, ReplayStoreError>> {
        let key = ReplayKey {
            issuer: issuer.to_owned(),
            nonce: nonce.to_owned(),
        };
        Box::pin(async move {
            let now = (self.clock)();
            let mut guard = self
                .state
                .lock()
                .map_err(|_| ReplayStoreError::Backend("replay store lock poisoned".into()))?;
            if now >= guard.next_sweep || guard.seen.len() >= self.capacity {
                guard.seen.retain(|_, &mut until| until > now);
                guard.next_sweep = now + Duration::from_secs(30);
            }
            if let Some(&recorded_until) = guard.seen.get(&key)
                && recorded_until > now
            {
                return Ok(false);
            }
            if guard.seen.len() >= self.capacity {
                return Err(ReplayStoreError::CapacityExceeded {
                    capacity: self.capacity,
                });
            }
            guard.seen.insert(key, expires_at);
            Ok(true)
        })
    }
}
