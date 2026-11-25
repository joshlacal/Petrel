//! Service-auth signing key resolution, static/closure adapters, and coalescing cache.

use std::collections::HashMap;
use std::fmt;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use async_lock::OnceCell;
use web_time::SystemTime;

use crate::keys::PublicKey;
use crate::rt::{BoxFuture, MaybeSend, MaybeSync};
use crate::service_auth::error::ServiceAuthError;
use crate::service_jwt::ServiceJWT;

/// Looks up the public key a service-auth token must be signed with.
///
/// `force_refresh` is the key-rotation hook: [`crate::service_auth::ServiceAuthVerifier`]
/// first asks with `false`, and only if the signature fails asks once more with `true`.
pub trait ServiceAuthKeyResolver: MaybeSend + MaybeSync {
    /// Returns the issuer's `#atproto` signing key.
    fn signing_key<'a>(
        &'a self,
        did: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<PublicKey, ServiceAuthError>>;

    /// Returns the key published under a specific verification method fragment (`#...`).
    ///
    /// The default implementation serves `#atproto` via [`Self::signing_key`] and rejects
    /// other key IDs with [`ServiceAuthError::KeyNotAccepted`].
    fn signing_key_for_id<'a>(
        &'a self,
        did: &'a str,
        key_id: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<PublicKey, ServiceAuthError>> {
        Box::pin(async move {
            if key_id != ServiceJWT::DEFAULT_KEY_ID {
                return Err(ServiceAuthError::KeyNotAccepted {
                    key_id: key_id.to_owned(),
                });
            }
            self.signing_key(did, force_refresh).await
        })
    }
}

/// Fixed table of signing keys for tests, allow-listed callers, or pinned keys.
#[derive(Debug, Clone, Default)]
pub struct StaticServiceAuthKeyResolver {
    keys: HashMap<String, HashMap<String, PublicKey>>,
}

impl StaticServiceAuthKeyResolver {
    /// Creates a resolver mapping each DID to its `#atproto` signing key.
    pub fn new(keys: HashMap<String, PublicKey>) -> Self {
        let by_id = keys
            .into_iter()
            .map(|(did, key)| {
                let mut inner = HashMap::new();
                inner.insert(ServiceJWT::DEFAULT_KEY_ID.to_owned(), key);
                (did, inner)
            })
            .collect();
        Self { keys: by_id }
    }

    /// Creates a resolver from `did -> key_id (with '#') -> PublicKey`.
    pub fn from_keys_by_id(keys: HashMap<String, HashMap<String, PublicKey>>) -> Self {
        Self { keys }
    }
}

impl ServiceAuthKeyResolver for StaticServiceAuthKeyResolver {
    fn signing_key<'a>(
        &'a self,
        did: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<PublicKey, ServiceAuthError>> {
        self.signing_key_for_id(did, ServiceJWT::DEFAULT_KEY_ID, force_refresh)
    }

    fn signing_key_for_id<'a>(
        &'a self,
        did: &'a str,
        key_id: &'a str,
        _force_refresh: bool,
    ) -> BoxFuture<'a, Result<PublicKey, ServiceAuthError>> {
        Box::pin(async move {
            self.keys
                .get(did)
                .and_then(|by_id| by_id.get(key_id))
                .cloned()
                .ok_or_else(|| ServiceAuthError::KeyResolutionFailed {
                    did: did.to_owned(),
                    key_id: key_id.to_owned(),
                    reason: "no key on record".into(),
                })
        })
    }
}

trait ResolveKeyOp:
    Fn(&str, &str, bool) -> BoxFuture<'static, Result<PublicKey, ServiceAuthError>>
    + MaybeSend
    + MaybeSync
{
}

impl<F> ResolveKeyOp for F where
    F: Fn(&str, &str, bool) -> BoxFuture<'static, Result<PublicKey, ServiceAuthError>>
        + MaybeSend
        + MaybeSync
{
}

/// Resolver backed by a closure, adapting any DID-document source without declaring a type.
pub struct ClosureServiceAuthKeyResolver {
    resolve: Box<dyn ResolveKeyOp>,
}

impl ClosureServiceAuthKeyResolver {
    /// Creates a resolver from an async `(did, key_id, force_refresh)` lookup closure.
    pub fn new<F>(resolve: F) -> Self
    where
        F: Fn(&str, &str, bool) -> BoxFuture<'static, Result<PublicKey, ServiceAuthError>>
            + MaybeSend
            + MaybeSync
            + 'static,
    {
        Self {
            resolve: Box::new(resolve),
        }
    }
}

impl fmt::Debug for ClosureServiceAuthKeyResolver {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("ClosureServiceAuthKeyResolver")
            .finish_non_exhaustive()
    }
}

impl ServiceAuthKeyResolver for ClosureServiceAuthKeyResolver {
    fn signing_key<'a>(
        &'a self,
        did: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<PublicKey, ServiceAuthError>> {
        self.signing_key_for_id(did, ServiceJWT::DEFAULT_KEY_ID, force_refresh)
    }

    fn signing_key_for_id<'a>(
        &'a self,
        did: &'a str,
        key_id: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<PublicKey, ServiceAuthError>> {
        (self.resolve)(did, key_id, force_refresh)
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
struct CacheKey {
    did: String,
    key_id: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
struct FetchKey {
    cache_key: CacheKey,
    refresh: bool,
}

#[derive(Debug, Clone)]
struct CacheEntry {
    key: PublicKey,
    fetched_at: SystemTime,
    was_refreshed: bool,
}

struct InFlightFetch {
    refresh: bool,
    cell: OnceCell<Result<PublicKey, ServiceAuthError>>,
}

enum LookupPlan {
    Cached(PublicKey),
    Join(Arc<InFlightFetch>),
    Drive {
        fetch_key: FetchKey,
        fetch: Arc<InFlightFetch>,
    },
}

struct CacheState {
    entries: HashMap<CacheKey, CacheEntry>,
    in_flight: HashMap<FetchKey, Arc<InFlightFetch>>,
}

/// Clock trait compatible with both native (`Send + Sync`) and `wasm32`.
pub trait Clock: Fn() -> SystemTime + MaybeSend + MaybeSync {}
impl<F: Fn() -> SystemTime + MaybeSend + MaybeSync> Clock for F {}

/// Clock source abstraction compatible with both native and `wasm32`.
pub type ClockFn = Arc<dyn Clock>;

/// Caches another [`ServiceAuthKeyResolver`]'s answers, coalesces concurrent
/// lookups, and rate-limits forced refreshes.
pub struct CachingServiceAuthKeyResolver<R: ServiceAuthKeyResolver> {
    upstream: Arc<R>,
    time_to_live: Duration,
    minimum_refresh_interval: Duration,
    capacity: usize,
    clock: ClockFn,
    state: Arc<Mutex<CacheState>>,
}

impl<R: ServiceAuthKeyResolver> fmt::Debug for CachingServiceAuthKeyResolver<R> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("CachingServiceAuthKeyResolver")
            .field("time_to_live", &self.time_to_live)
            .field("minimum_refresh_interval", &self.minimum_refresh_interval)
            .field("capacity", &self.capacity)
            .finish_non_exhaustive()
    }
}

impl<R: ServiceAuthKeyResolver> CachingServiceAuthKeyResolver<R> {
    /// Wraps `upstream` with defaults: 15 min TTL, 30 s minimum refresh interval, 10,000 capacity.
    pub fn new(upstream: R) -> Self {
        Self::with_config(
            upstream,
            Duration::from_secs(15 * 60),
            Duration::from_secs(30),
            10_000,
            Arc::new(SystemTime::now),
        )
    }

    /// Wraps `upstream` with explicit TTL, refresh rate-limit, capacity, and clock.
    pub fn with_config(
        upstream: R,
        time_to_live: Duration,
        minimum_refresh_interval: Duration,
        capacity: usize,
        clock: ClockFn,
    ) -> Self {
        Self {
            upstream: Arc::new(upstream),
            time_to_live,
            minimum_refresh_interval,
            capacity: capacity.max(1),
            clock,
            state: Arc::new(Mutex::new(CacheState {
                entries: HashMap::new(),
                in_flight: HashMap::new(),
            })),
        }
    }

    /// Forgets every cached key.
    pub fn remove_all(&self) {
        if let Ok(mut guard) = self.state.lock() {
            guard.entries.clear();
        }
    }

    fn store(
        &self,
        key: PublicKey,
        cache_key: &CacheKey,
        refreshed: bool,
        requested_at: SystemTime,
    ) -> PublicKey {
        let Ok(mut state) = self.state.lock() else {
            return key;
        };
        if !refreshed
            && let Some(newer) = state.entries.get(cache_key)
            && newer.was_refreshed
            && newer.fetched_at >= requested_at
        {
            return newer.key.clone();
        }
        if !state.entries.contains_key(cache_key) && state.entries.len() >= self.capacity {
            Self::evict_oldest(&mut state.entries, self.capacity);
        }
        let now = (self.clock)();
        state.entries.insert(
            cache_key.clone(),
            CacheEntry {
                key: key.clone(),
                fetched_at: now,
                was_refreshed: refreshed,
            },
        );
        key
    }

    fn evict_oldest(entries: &mut HashMap<CacheKey, CacheEntry>, capacity: usize) {
        let batch = (capacity / 10).max(1);
        let mut items: Vec<(CacheKey, SystemTime)> = entries
            .iter()
            .map(|(k, v)| (k.clone(), v.fetched_at))
            .collect();
        items.sort_by_key(|(_, fetched_at)| *fetched_at);
        for (key, _) in items.into_iter().take(batch) {
            entries.remove(&key);
        }
    }
}

struct InFlightGuard {
    state: Arc<Mutex<CacheState>>,
    fetch_key: FetchKey,
    fetch: Arc<InFlightFetch>,
}

impl Drop for InFlightGuard {
    fn drop(&mut self) {
        if let Ok(mut guard) = self.state.lock()
            && let Some(existing) = guard.in_flight.get(&self.fetch_key)
            && Arc::ptr_eq(existing, &self.fetch)
        {
            guard.in_flight.remove(&self.fetch_key);
        }
    }
}

impl<R: ServiceAuthKeyResolver + 'static> CachingServiceAuthKeyResolver<R> {
    fn plan_lookup(
        &self,
        cache_key: &CacheKey,
        force_refresh: bool,
        now: SystemTime,
    ) -> Result<LookupPlan, ServiceAuthError> {
        let mut guard = self
            .state
            .lock()
            .map_err(|_| ServiceAuthError::KeyResolutionFailed {
                did: cache_key.did.clone(),
                key_id: cache_key.key_id.clone(),
                reason: "key cache lock poisoned".into(),
            })?;

        if let Some(entry) = guard.entries.get(cache_key)
            && let Ok(age) = now.duration_since(entry.fetched_at)
        {
            let fresh = age < self.time_to_live;
            let recently_fetched = age < self.minimum_refresh_interval;
            if fresh && !force_refresh {
                return Ok(LookupPlan::Cached(entry.key.clone()));
            }
            if recently_fetched && (!force_refresh || entry.was_refreshed) {
                return Ok(LookupPlan::Cached(entry.key.clone()));
            }
        }

        let refreshing_key = FetchKey {
            cache_key: cache_key.clone(),
            refresh: true,
        };
        let ordinary_key = FetchKey {
            cache_key: cache_key.clone(),
            refresh: false,
        };

        if let Some(pending) = guard.in_flight.get(&refreshing_key).cloned().or_else(|| {
            if force_refresh {
                None
            } else {
                guard.in_flight.get(&ordinary_key).cloned()
            }
        }) {
            return Ok(LookupPlan::Join(pending));
        }

        let refresh = force_refresh || guard.entries.contains_key(cache_key);
        let fetch_key = FetchKey {
            cache_key: cache_key.clone(),
            refresh,
        };
        let fetch = Arc::new(InFlightFetch {
            refresh,
            cell: OnceCell::new(),
        });
        guard
            .in_flight
            .insert(fetch_key.clone(), Arc::clone(&fetch));
        Ok(LookupPlan::Drive { fetch_key, fetch })
    }
}

impl<R: ServiceAuthKeyResolver + 'static> ServiceAuthKeyResolver
    for CachingServiceAuthKeyResolver<R>
{
    fn signing_key<'a>(
        &'a self,
        did: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<PublicKey, ServiceAuthError>> {
        self.signing_key_for_id(did, ServiceJWT::DEFAULT_KEY_ID, force_refresh)
    }

    fn signing_key_for_id<'a>(
        &'a self,
        did: &'a str,
        key_id: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<PublicKey, ServiceAuthError>> {
        let did_owned = did.to_owned();
        let key_id_owned = key_id.to_owned();
        Box::pin(async move {
            let cache_key = CacheKey {
                did: did_owned.clone(),
                key_id: key_id_owned.clone(),
            };
            let now = (self.clock)();

            match self.plan_lookup(&cache_key, force_refresh, now)? {
                LookupPlan::Cached(key) => Ok(key),
                LookupPlan::Join(pending) => {
                    let res = pending
                        .cell
                        .get_or_init(|| async {
                            match self
                                .upstream
                                .signing_key_for_id(&did_owned, &key_id_owned, pending.refresh)
                                .await
                            {
                                Ok(key) => Ok(self.store(key, &cache_key, pending.refresh, now)),
                                Err(err) => Err(err),
                            }
                        })
                        .await;
                    res.clone()
                }
                LookupPlan::Drive { fetch_key, fetch } => {
                    let _guard = InFlightGuard {
                        state: Arc::clone(&self.state),
                        fetch_key,
                        fetch: Arc::clone(&fetch),
                    };
                    let res = fetch
                        .cell
                        .get_or_init(|| async {
                            match self
                                .upstream
                                .signing_key_for_id(&did_owned, &key_id_owned, fetch.refresh)
                                .await
                            {
                                Ok(key) => Ok(self.store(key, &cache_key, fetch.refresh, now)),
                                Err(err) => Err(err),
                            }
                        })
                        .await;
                    res.clone()
                }
            }
        })
    }
}
