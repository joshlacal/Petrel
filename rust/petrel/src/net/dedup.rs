//! In-flight deduplication for idempotent `GET` and `HEAD` requests.

use std::{
    collections::{BTreeSet, HashMap},
    fmt::{self, Write as _},
    future::Future,
    sync::{
        Arc,
        atomic::{AtomicU64, Ordering},
    },
    time::Duration,
};

use async_lock::Mutex;
use bytes::Bytes;
use futures_util::future::{FutureExt, Shared};
use http::{HeaderMap, Method, Request, Response};
use web_time::Instant;

use super::TransportError;
use crate::{
    crypto::sha256,
    rt::{BoxFuture, MaybeSend},
};

const DEFAULT_MAX_REQUEST_AGE: Duration = Duration::from_secs(30);

/// Canonical key identifying an idempotent `GET` or `HEAD` request for deduplication.
///
/// Requests that differ in response-affecting headers (`atproto-proxy`,
/// `atproto-accept-labelers`, or any caller header), calling `auth_identity`, or
/// whether an `Authorization` header is present map to distinct keys, while per-request
/// `DPoP` proofs and configured ignored headers do not split keys.
#[derive(Clone, PartialEq, Eq, Hash)]
pub struct RequestKey {
    /// Calling identity (or opaque hash of `Authorization` when explicit identity is absent),
    /// used to isolate responses per user/session.
    pub auth_identity: Option<String>,
    /// Distinguishes authenticated requests carrying an `Authorization` header from
    /// pre-auth / unauthenticated requests even if `auth_identity` matches.
    has_authorization: bool,
    /// HTTP method (`GET` or `HEAD`).
    pub method: String,
    /// Full request URL string.
    pub url: String,
    /// Sorted lowercase `name:value` pairs for non-ignored headers.
    pub headers: Vec<String>,
}

impl fmt::Debug for RequestKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let header_names: Vec<&str> = self
            .headers
            .iter()
            .map(|entry| {
                entry
                    .split_once(':')
                    .map_or(entry.as_str(), |(name, _)| name)
            })
            .collect();
        f.debug_struct("RequestKey")
            .field(
                "auth_identity",
                &self.auth_identity.as_ref().map(|_| "[REDACTED]"),
            )
            .field("has_authorization", &self.has_authorization)
            .field("method", &self.method)
            .field("url", &self.url)
            .field("header_names", &header_names)
            .finish()
    }
}

fn authorization_digest(headers: &HeaderMap) -> Option<String> {
    let mut values = headers
        .get_all(http::header::AUTHORIZATION)
        .iter()
        .peekable();
    values.peek()?;
    let mut material = Vec::new();
    for value in values {
        let bytes = value.as_bytes();
        material.extend_from_slice(&(bytes.len() as u64).to_be_bytes());
        material.extend_from_slice(bytes);
    }
    let digest = sha256(&material);
    let mut out = String::with_capacity("auth-sha256:".len() + digest.len() * 2);
    out.push_str("auth-sha256:");
    for byte in digest {
        let _ = write!(&mut out, "{byte:02x}");
    }
    Some(out)
}

impl RequestKey {
    /// Headers ignored by default when constructing a deduplication key.
    pub const DEFAULT_IGNORED_HEADERS: [&'static str; 2] = ["authorization", "dpop"];

    /// Builds a key from an [`http::Request`]. Returns `None` for non-idempotent methods
    /// or requests with empty URIs.
    #[must_use]
    pub fn from_request<B>(
        request: &Request<B>,
        auth_identity: Option<&str>,
        ignoring_headers: &[&str],
    ) -> Option<Self> {
        Self::new(
            request.method(),
            &request.uri().to_string(),
            auth_identity,
            request.headers(),
            ignoring_headers,
        )
    }

    /// Builds a key from explicit HTTP components. Returns `None` if `method` is not
    /// `GET`/`HEAD` or if `url` is empty.
    #[must_use]
    pub fn new(
        method: &Method,
        url: &str,
        auth_identity: Option<&str>,
        headers: &HeaderMap,
        ignoring_headers: &[&str],
    ) -> Option<Self> {
        if *method != Method::GET && *method != Method::HEAD {
            return None;
        }
        if url.is_empty() {
            return None;
        }
        let has_authorization = headers.contains_key(http::header::AUTHORIZATION);
        let bound_identity = auth_identity
            .map(str::to_owned)
            .or_else(|| authorization_digest(headers));
        let mut ignored: BTreeSet<String> = Self::DEFAULT_IGNORED_HEADERS
            .iter()
            .map(|name| (*name).to_owned())
            .collect();
        for name in ignoring_headers {
            ignored.insert(name.to_ascii_lowercase());
        }

        let mut normalized_headers: Vec<String> = headers
            .iter()
            .filter_map(|(name, value)| {
                let lower = name.as_str().to_ascii_lowercase();
                if ignored.contains(&lower) {
                    return None;
                }
                let text = value.to_str().ok()?;
                Some(format!("{lower}:{text}"))
            })
            .collect();
        normalized_headers.sort();

        Some(Self {
            auth_identity: bound_identity,
            has_authorization,
            method: method.as_str().to_owned(),
            url: url.to_owned(),
            headers: normalized_headers,
        })
    }
}

type SharedResponseFuture = Shared<BoxFuture<'static, Result<Response<Bytes>, TransportError>>>;

struct InFlightEntry {
    generation: u64,
    started_at: Instant,
    future: SharedResponseFuture,
}

/// Coalesces concurrent identical `GET` and `HEAD` requests into one execution.
pub struct RequestDeduplicator {
    max_request_age: Duration,
    next_generation: AtomicU64,
    in_flight: Arc<Mutex<HashMap<RequestKey, InFlightEntry>>>,
}

impl fmt::Debug for RequestDeduplicator {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("RequestDeduplicator")
            .field("max_request_age", &self.max_request_age)
            .finish_non_exhaustive()
    }
}

impl Default for RequestDeduplicator {
    fn default() -> Self {
        Self::new()
    }
}

impl RequestDeduplicator {
    /// Creates a deduplicator with the default 30-second in-flight window.
    #[must_use]
    pub fn new() -> Self {
        Self::with_max_request_age(DEFAULT_MAX_REQUEST_AGE)
    }

    /// Creates a deduplicator with a custom expiration window for stale in-flight entries.
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    #[must_use]
    pub fn with_max_request_age(max_request_age: Duration) -> Self {
        Self {
            max_request_age,
            next_generation: AtomicU64::new(1),
            in_flight: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// Returns `true` if a matching request is currently in flight and unexpired.
    pub async fn is_request_in_flight<B>(
        &self,
        request: &Request<B>,
        auth_identity: Option<&str>,
        ignoring_headers: &[&str],
    ) -> bool {
        let Some(key) = RequestKey::from_request(request, auth_identity, ignoring_headers) else {
            return false;
        };
        let guard = self.in_flight.lock().await;
        guard
            .get(&key)
            .is_some_and(|entry| entry.started_at.elapsed() <= self.max_request_age)
    }

    /// Executes `work` or joins an identical in-flight request when eligible.
    pub async fn deduplicate<B, F, Fut>(
        &self,
        request: &Request<B>,
        auth_identity: Option<&str>,
        ignoring_headers: &[&str],
        work: F,
    ) -> Result<Response<Bytes>, TransportError>
    where
        F: FnOnce() -> Fut + MaybeSend + 'static,
        Fut: Future<Output = Result<Response<Bytes>, TransportError>> + MaybeSend + 'static,
    {
        self.deduplicate_with_hook(request, auth_identity, ignoring_headers, || {}, work)
            .await
    }

    /// Executes `work` or joins an identical in-flight request, invoking `on_join_existing`
    /// when joining an already active request.
    pub async fn deduplicate_with_hook<B, H, F, Fut>(
        &self,
        request: &Request<B>,
        auth_identity: Option<&str>,
        ignoring_headers: &[&str],
        on_join_existing: H,
        work: F,
    ) -> Result<Response<Bytes>, TransportError>
    where
        H: FnOnce(),
        F: FnOnce() -> Fut + MaybeSend + 'static,
        Fut: Future<Output = Result<Response<Bytes>, TransportError>> + MaybeSend + 'static,
    {
        let Some(key) = RequestKey::from_request(request, auth_identity, ignoring_headers) else {
            return work().await;
        };

        let shared = {
            let mut guard = self.in_flight.lock().await;
            if let Some(existing) = guard.get(&key) {
                if existing.started_at.elapsed() <= self.max_request_age {
                    let shared = existing.future.clone();
                    drop(guard);
                    on_join_existing();
                    return shared.await;
                }
                guard.remove(&key);
            }

            let generation = self.next_generation.fetch_add(1, Ordering::Relaxed);
            let in_flight = Arc::clone(&self.in_flight);
            let key_for_cleanup = key.clone();

            let boxed: BoxFuture<'static, Result<Response<Bytes>, TransportError>> =
                Box::pin(async move {
                    let mut cleanup = EntryCleanupGuard {
                        in_flight: Arc::clone(&in_flight),
                        key: key_for_cleanup,
                        generation,
                        cleaned: false,
                    };
                    let result = work().await;
                    cleanup.cleanup_async().await;
                    result
                });
            let shared = boxed.shared();
            guard.insert(
                key,
                InFlightEntry {
                    generation,
                    started_at: Instant::now(),
                    future: shared.clone(),
                },
            );
            shared
        };

        shared.await
    }

    /// Clears all tracked in-flight entries so subsequent calls start fresh requests.
    pub async fn cancel_all_requests(&self) {
        self.in_flight.lock().await.clear();
    }
}

struct EntryCleanupGuard {
    in_flight: Arc<Mutex<HashMap<RequestKey, InFlightEntry>>>,
    key: RequestKey,
    generation: u64,
    cleaned: bool,
}

impl EntryCleanupGuard {
    async fn cleanup_async(&mut self) {
        self.cleaned = true;
        let mut guard = self.in_flight.lock().await;
        if guard
            .get(&self.key)
            .is_some_and(|entry| entry.generation == self.generation)
        {
            guard.remove(&self.key);
        }
    }
}

impl Drop for EntryCleanupGuard {
    fn drop(&mut self) {
        if self.cleaned {
            return;
        }
        if let Some(mut guard) = self.in_flight.try_lock()
            && guard
                .get(&self.key)
                .is_some_and(|entry| entry.generation == self.generation)
        {
            guard.remove(&self.key);
        }
    }
}
