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
    /// The in-memory store reached a configured capacity of unexpired entries, either
    /// globally or for the token's issuer, after evicting expired entries.
    #[error("replay store is full ({capacity} unexpired tokens)")]
    CapacityExceeded {
        /// Configured capacity limit that was reached.
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

/// Nonces remembered for one issuer, each with the time it may be forgotten.
type IssuerNonces = HashMap<String, SystemTime>;

struct ReplayState {
    by_issuer: HashMap<String, IssuerNonces>,
    total: usize,
    next_sweep: SystemTime,
}

impl ReplayState {
    /// Drops every expired nonce and every issuer left with none.
    fn sweep_all(&mut self, now: SystemTime) {
        self.by_issuer.retain(|_, nonces| {
            nonces.retain(|_, until| *until > now);
            !nonces.is_empty()
        });
        self.total = self.by_issuer.values().map(HashMap::len).sum();
    }

    /// Drops the expired nonces of one issuer.
    fn sweep_issuer(&mut self, issuer: &str, now: SystemTime) {
        if let Some(nonces) = self.by_issuer.get_mut(issuer) {
            let before = nonces.len();
            nonces.retain(|_, until| *until > now);
            self.total -= before - nonces.len();
            if nonces.is_empty() {
                self.by_issuer.remove(issuer);
            }
        }
    }

    fn issuer_len(&self, issuer: &str) -> usize {
        self.by_issuer.get(issuer).map_or(0, HashMap::len)
    }
}

/// Process-local [`ServiceAuthReplayStore`] with capacity-bounded pruning.
///
/// Two limits bound memory: a global capacity of unexpired nonces and a per-issuer limit
/// (default [`Self::DEFAULT_PER_ISSUER_CAPACITY`]). An issuer flooding fresh tokens hits its
/// own limit and only its tokens are refused; it cannot fill the store and make every other
/// issuer's verification fail. Expired entries are evicted before either limit is reported
/// as exceeded.
///
/// **Per-instance only.** The store lives in one process: replicas behind a load balancer do
/// not see each other's nonces, so a token could be replayed once per replica. Multi-instance
/// deployments must implement [`ServiceAuthReplayStore`] over a shared backend (for example
/// Postgres or Redis) with an atomic insert-if-absent.
pub struct InMemoryServiceAuthReplayStore {
    capacity: usize,
    per_issuer_capacity: Option<usize>,
    clock: ClockFn,
    state: Mutex<ReplayState>,
}

impl fmt::Debug for InMemoryServiceAuthReplayStore {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("InMemoryServiceAuthReplayStore")
            .field("capacity", &self.capacity)
            .field("per_issuer_capacity", &self.per_issuer_capacity)
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
    /// Default global capacity of unexpired nonces.
    pub const DEFAULT_CAPACITY: usize = 100_000;
    /// Default limit on unexpired nonces remembered for a single issuer.
    pub const DEFAULT_PER_ISSUER_CAPACITY: usize = 1_000;

    /// Creates an in-memory replay store with the default capacity (100,000 entries) and
    /// per-issuer limit (1,000 entries).
    pub fn new() -> Self {
        Self::with_config(Self::DEFAULT_CAPACITY, Arc::new(SystemTime::now))
    }

    /// Creates an in-memory replay store with explicit capacity and clock, keeping the
    /// default per-issuer limit.
    pub fn with_config(capacity: usize, clock: ClockFn) -> Self {
        Self {
            capacity: capacity.max(1),
            per_issuer_capacity: Some(Self::DEFAULT_PER_ISSUER_CAPACITY),
            clock,
            state: Mutex::new(ReplayState {
                by_issuer: HashMap::new(),
                total: 0,
                next_sweep: UNIX_EPOCH,
            }),
        }
    }

    /// Sets the per-issuer limit on unexpired nonces so one issuer cannot exhaust global
    /// store capacity for other issuers in multi-tenant deployments.
    #[must_use]
    pub fn with_per_issuer_capacity(mut self, limit: usize) -> Self {
        self.per_issuer_capacity = Some(limit.max(1));
        self
    }

    /// Removes the per-issuer limit, leaving only the global capacity.
    #[must_use]
    pub fn without_per_issuer_capacity(mut self) -> Self {
        self.per_issuer_capacity = None;
        self
    }

    /// Number of nonces currently remembered.
    pub fn len(&self) -> usize {
        self.state.lock().map_or(0, |guard| guard.total)
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
        Box::pin(async move {
            let now = (self.clock)();
            let mut guard = self
                .state
                .lock()
                .map_err(|_| ReplayStoreError::Backend("replay store lock poisoned".into()))?;
            let state = &mut *guard;
            if now >= state.next_sweep {
                state.sweep_all(now);
                state.next_sweep = now + Duration::from_secs(30);
            }
            if let Some(&recorded_until) = state
                .by_issuer
                .get(issuer)
                .and_then(|nonces| nonces.get(nonce))
                && recorded_until > now
            {
                return Ok(false);
            }
            if expires_at <= now {
                return Ok(true);
            }
            if let Some(limit) = self.per_issuer_capacity {
                if state.issuer_len(issuer) >= limit {
                    state.sweep_issuer(issuer, now);
                }
                if state.issuer_len(issuer) >= limit {
                    return Err(ReplayStoreError::CapacityExceeded { capacity: limit });
                }
            }
            if state.total >= self.capacity {
                state.sweep_all(now);
                state.next_sweep = now + Duration::from_secs(30);
                if state.total >= self.capacity {
                    return Err(ReplayStoreError::CapacityExceeded {
                        capacity: self.capacity,
                    });
                }
            }
            let nonces = state.by_issuer.entry(issuer.to_owned()).or_default();
            if nonces.insert(nonce.to_owned(), expires_at).is_none() {
                state.total += 1;
            }
            Ok(true)
        })
    }
}

#[cfg(all(test, not(target_arch = "wasm32")))]
mod tests {
    use super::*;

    fn ts(secs: u64) -> SystemTime {
        UNIX_EPOCH + Duration::from_secs(secs)
    }

    fn pinned_store(capacity: usize, clock: Arc<Mutex<u64>>) -> InMemoryServiceAuthReplayStore {
        InMemoryServiceAuthReplayStore::with_config(
            capacity,
            Arc::new(move || ts(*clock.lock().unwrap())),
        )
    }

    #[tokio::test]
    async fn default_per_issuer_cap_isolates_a_flooding_issuer() {
        let clock = Arc::new(Mutex::new(1_700_000_000));
        let store = pinned_store(100_000, clock);
        let limit = InMemoryServiceAuthReplayStore::DEFAULT_PER_ISSUER_CAPACITY;
        for i in 0..limit {
            assert!(
                store
                    .claim(&format!("n{i}"), "did:plc:noisy", ts(1_700_000_060))
                    .await
                    .unwrap()
            );
        }
        assert_eq!(
            store
                .claim("one-more", "did:plc:noisy", ts(1_700_000_060))
                .await,
            Err(ReplayStoreError::CapacityExceeded { capacity: limit })
        );
        assert!(
            store
                .claim("n0", "did:plc:quiet", ts(1_700_000_060))
                .await
                .unwrap()
        );
        assert_eq!(store.len(), limit + 1);
    }

    #[tokio::test]
    async fn issuer_cap_evicts_own_expired_entries_before_rejecting() {
        let clock = Arc::new(Mutex::new(1_700_000_000));
        let store = pinned_store(10, Arc::clone(&clock)).with_per_issuer_capacity(2);
        assert!(
            store
                .claim("a", "did:plc:x", ts(1_700_000_005))
                .await
                .unwrap()
        );
        assert!(
            store
                .claim("b", "did:plc:x", ts(1_700_000_005))
                .await
                .unwrap()
        );
        assert!(
            store
                .claim("c", "did:plc:x", ts(1_700_000_005))
                .await
                .is_err()
        );
        // Expired but before the 30 s sweep interval: the issuer sweep frees its slots.
        *clock.lock().unwrap() = 1_700_000_006;
        assert!(
            store
                .claim("c", "did:plc:x", ts(1_700_000_050))
                .await
                .unwrap()
        );
        assert_eq!(store.len(), 1);
    }

    #[tokio::test]
    async fn without_per_issuer_capacity_only_global_limit_applies() {
        let clock = Arc::new(Mutex::new(1_700_000_000));
        let store = pinned_store(3, clock)
            .with_per_issuer_capacity(1)
            .without_per_issuer_capacity();
        for nonce in ["a", "b", "c"] {
            assert!(
                store
                    .claim(nonce, "did:plc:x", ts(1_700_000_050))
                    .await
                    .unwrap()
            );
        }
        assert_eq!(
            store.claim("d", "did:plc:y", ts(1_700_000_050)).await,
            Err(ReplayStoreError::CapacityExceeded { capacity: 3 })
        );
    }
}
