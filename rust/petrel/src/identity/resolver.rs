use std::{fmt, future::Future, sync::Arc, time::Duration};

use bytes::Bytes;
use futures_util::future::{Either, select};
use http::{Request, Response, StatusCode, header::ACCEPT};
use petrel_core::{Did, Handle};
use serde::Deserialize;
use url::Url;
use web_time::SystemTime;

use super::{
    CacheEntry, CachePolicy, DidDocument, DidWebError, DidWebIdentifier, DnsResolver,
    IdentityCache, InMemoryIdentityCache, ServiceKind, SigningKey,
};
use crate::{
    net::{RedirectPolicy, SendOptions, SharedTransport, TransportError, send_with_redirects},
    rt::{BoxFuture, MaybeSend, MaybeSync},
};

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[non_exhaustive]
pub enum IdentityError {
    #[error("invalid DID syntax: {0}")]
    InvalidDidSyntax(String),
    #[error("unsupported DID method in {0}")]
    UnsupportedDidMethod(Did),
    #[error("AT Protocol does not support path-based did:web identifiers: {0}")]
    UnsupportedDidWebPath(Did),
    #[error("invalid did:web identifier {did}: {reason}")]
    InvalidDidWeb { did: Did, reason: DidWebError },
    #[error("DID not found: {0}")]
    DidNotFound(Did),
    #[error("DID was deactivated: {0}")]
    DidTombstoned(Did),
    #[error("the DID document for {expected} declares {actual}")]
    DocumentIdMismatch { expected: Did, actual: Did },
    #[error("invalid DID document for {0}")]
    InvalidDidDocument(Did),
    #[error("{0} has no valid #atproto signing key")]
    MissingSigningKey(Did),
    #[error("{did} has no valid {fragment} verification method")]
    MissingVerificationMethod { did: Did, fragment: String },
    #[error("{did} has an invalid {fragment} service endpoint")]
    InvalidServiceEndpoint { did: Did, fragment: String },
    #[error("reserved handle top-level domain: {0}")]
    ReservedHandleTld(Handle),
    #[error("handle not found: {0}")]
    HandleNotFound(Handle),
    #[error("conflicting DID candidates for {handle}: {dids:?}")]
    HandleAmbiguous { handle: Handle, dids: Vec<Did> },
    #[error("{did} does not claim {handle}")]
    HandleNotClaimedByDid { handle: Handle, did: Did },
    #[error("lookup failed for {handle}: {reason}")]
    HandleLookupFailed { handle: Handle, reason: String },
    #[error("identity service returned HTTP {status} at {url}")]
    UnexpectedStatus { url: Url, status: StatusCode },
    #[error("identity response from {0} exceeded its size limit")]
    ResponseTooLarge(Url),
    #[error("identity lookup timed out")]
    TimedOut,
    #[error("identity host was blocked by network policy: {0}")]
    BlockedByNetworkPolicy(Url),
    #[error("identity request to {url} failed: {reason}")]
    Transport { url: Url, reason: String },
}

impl IdentityError {
    fn definitive(&self) -> bool {
        !matches!(
            self,
            Self::UnexpectedStatus { .. }
                | Self::ResponseTooLarge(_)
                | Self::TimedOut
                | Self::BlockedByNetworkPolicy(_)
                | Self::Transport { .. }
                | Self::HandleLookupFailed { .. }
        )
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum HandleConflictPolicy {
    #[default]
    PreferDns,
    Reject,
}

pub trait HandleLookup: MaybeSend + MaybeSync {
    fn lookup<'a>(
        &'a self,
        handle: &'a Handle,
    ) -> BoxFuture<'a, Result<Option<Did>, IdentityError>>;
}

#[derive(Clone, Default)]
pub enum HandleStrategy {
    #[default]
    Direct,
    Xrpc {
        service: Url,
        fallback_to_direct: bool,
    },
    Custom {
        lookup: Arc<dyn HandleLookup>,
        fallback_to_direct: bool,
    },
}

impl fmt::Debug for HandleStrategy {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Direct => f.write_str("Direct"),
            Self::Xrpc {
                service,
                fallback_to_direct,
            } => f
                .debug_struct("Xrpc")
                .field("service", service)
                .field("fallback_to_direct", fallback_to_direct)
                .finish(),
            Self::Custom {
                fallback_to_direct, ..
            } => f
                .debug_struct("Custom")
                .field("fallback_to_direct", fallback_to_direct)
                .finish_non_exhaustive(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct IdentityOptions {
    pub plc_directory: Url,
    pub handle_strategy: HandleStrategy,
    pub handle_conflict: HandleConflictPolicy,
    pub timeout: Duration,
    pub cache_policy: CachePolicy,
    pub max_document_bytes: usize,
    pub allow_development_identifiers: bool,
}

impl Default for IdentityOptions {
    fn default() -> Self {
        Self {
            plc_directory: Url::parse("https://plc.directory").expect("fixed PLC directory URL"),
            handle_strategy: HandleStrategy::Direct,
            handle_conflict: HandleConflictPolicy::PreferDns,
            timeout: Duration::from_secs(5),
            cache_policy: CachePolicy::default(),
            max_document_bytes: 256 * 1024,
            allow_development_identifiers: false,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum HandleVerification {
    Verified,
    NoHandleClaimed,
    ResolvesToDifferentDid(Did),
    DoesNotResolve,
    LookupFailed,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ResolvedIdentity {
    pub did: Did,
    pub handle: Handle,
    pub verification: HandleVerification,
    pub document: DidDocument,
}

/// Resolve DIDs and verify both sides of a DID-to-handle relationship.
pub struct IdentityResolver<D, C = InMemoryIdentityCache> {
    transport: SharedTransport,
    dns: D,
    cache: C,
    options: IdentityOptions,
    clock: Arc<dyn IdentityClock>,
}

trait IdentityClock: Fn() -> SystemTime + MaybeSend + MaybeSync {}
impl<F: Fn() -> SystemTime + MaybeSend + MaybeSync> IdentityClock for F {}

impl<D, C> fmt::Debug for IdentityResolver<D, C> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("IdentityResolver")
            .field("options", &self.options)
            .finish_non_exhaustive()
    }
}

impl<D: DnsResolver> IdentityResolver<D> {
    pub fn new(transport: SharedTransport, dns: D, options: IdentityOptions) -> Self {
        Self::with_cache(transport, dns, options, InMemoryIdentityCache::default())
    }
}

impl<D: DnsResolver, C: IdentityCache> IdentityResolver<D, C> {
    pub fn with_cache(
        transport: SharedTransport,
        dns: D,
        options: IdentityOptions,
        cache: C,
    ) -> Self {
        Self {
            transport,
            dns,
            cache,
            options,
            clock: Arc::new(SystemTime::now),
        }
    }

    pub fn with_clock(
        mut self,
        clock: impl Fn() -> SystemTime + MaybeSend + MaybeSync + 'static,
    ) -> Self {
        self.clock = Arc::new(clock);
        self
    }

    pub async fn resolve_handle(&self, handle: &Handle) -> Result<Did, IdentityError> {
        self.resolve_handle_with_refresh(handle, false).await
    }

    pub async fn resolve_handle_with_refresh(
        &self,
        handle: &Handle,
        force_refresh: bool,
    ) -> Result<Did, IdentityError> {
        self.validate_handle(handle)?;
        let did = self.lookup_handle(handle, force_refresh).await?;
        let document = self.resolve_document(&did, force_refresh).await?;
        if document.claimed_handle().as_ref() != Some(handle) {
            self.cache.remove_handle(handle).await;
            return Err(IdentityError::HandleNotClaimedByDid {
                handle: handle.clone(),
                did,
            });
        }
        Ok(did)
    }

    pub async fn resolve_did_document(&self, did: &Did) -> Result<DidDocument, IdentityError> {
        self.resolve_document(did, false).await
    }

    pub async fn refresh_did_document(&self, did: &Did) -> Result<DidDocument, IdentityError> {
        self.resolve_document(did, true).await
    }

    pub async fn resolve_identity(&self, did: &Did) -> Result<ResolvedIdentity, IdentityError> {
        self.resolve_identity_with_refresh(did, false).await
    }

    pub async fn resolve_identity_with_refresh(
        &self,
        did: &Did,
        force_refresh: bool,
    ) -> Result<ResolvedIdentity, IdentityError> {
        let document = self.resolve_document(did, force_refresh).await?;
        let (handle, verification) = match document.claimed_handle() {
            None => (None, HandleVerification::NoHandleClaimed),
            Some(handle) if self.validate_handle(&handle).is_err() => {
                (None, HandleVerification::DoesNotResolve)
            }
            Some(handle) => match self.lookup_handle(&handle, force_refresh).await {
                Ok(candidate) if &candidate == did => (Some(handle), HandleVerification::Verified),
                Ok(candidate) => (None, HandleVerification::ResolvesToDifferentDid(candidate)),
                Err(error) if error.definitive() => (None, HandleVerification::DoesNotResolve),
                Err(_) => (None, HandleVerification::LookupFailed),
            },
        };
        Ok(ResolvedIdentity {
            did: did.clone(),
            handle: handle
                .unwrap_or_else(|| "handle.invalid".parse().expect("fixed handle sentinel")),
            verification,
            document,
        })
    }

    pub async fn resolve_signing_key(&self, did: &Did) -> Result<SigningKey, IdentityError> {
        self.resolve_did_document(did).await?.signing_key()
    }

    pub async fn resolve_service_endpoint(
        &self,
        did: &Did,
        kind: ServiceKind,
    ) -> Result<Option<Url>, IdentityError> {
        self.resolve_did_document(did)
            .await?
            .validated_service_endpoint_with_development(
                kind,
                self.options.allow_development_identifiers,
            )
    }

    pub async fn invalidate_did(&self, did: &Did) {
        self.cache.remove_document(did).await;
    }

    pub async fn invalidate_handle(&self, handle: &Handle) {
        self.cache.remove_handle(handle).await;
    }

    pub async fn clear_cache(&self) {
        self.cache.clear().await;
    }

    fn validate_handle(&self, handle: &Handle) -> Result<(), IdentityError> {
        let dev = handle.normalized().ends_with(".test");
        if !handle.is_valid_tld() || (dev && !self.options.allow_development_identifiers) {
            return Err(IdentityError::ReservedHandleTld(handle.clone()));
        }
        Ok(())
    }

    async fn resolve_document(&self, did: &Did, force: bool) -> Result<DidDocument, IdentityError> {
        let (url, plc) = self.document_source(did)?;
        let cached = if force {
            None
        } else {
            self.cache.document(did).await
        };
        if let Some(entry) = fresh(&cached, self.options.cache_policy.fresh_for, (self.clock)()) {
            return Ok(entry.value.clone());
        }

        match self.fetch_document(did, &url, plc).await {
            Ok(document) => {
                self.cache
                    .put_document(CacheEntry {
                        value: document.clone(),
                        stored_at: (self.clock)(),
                    })
                    .await;
                Ok(document)
            }
            Err(error) => {
                if error.definitive() {
                    self.cache.remove_document(did).await;
                } else if let Some(entry) = fresh(
                    &cached,
                    self.options.cache_policy.maximum_age,
                    (self.clock)(),
                ) {
                    return Ok(entry.value.clone());
                }
                Err(error)
            }
        }
    }

    async fn lookup_handle(&self, handle: &Handle, force: bool) -> Result<Did, IdentityError> {
        let cached = if force {
            None
        } else {
            self.cache.handle(handle).await
        };
        if let Some(entry) = fresh(&cached, self.options.cache_policy.fresh_for, (self.clock)()) {
            return Ok(entry.value.clone());
        }

        match self.lookup_uncached(handle).await {
            Ok(did) => {
                self.cache
                    .put_handle(
                        handle.clone(),
                        CacheEntry {
                            value: did.clone(),
                            stored_at: (self.clock)(),
                        },
                    )
                    .await;
                Ok(did)
            }
            Err(error) => {
                if error.definitive() {
                    self.cache.remove_handle(handle).await;
                } else if let Some(entry) = fresh(
                    &cached,
                    self.options.cache_policy.maximum_age,
                    (self.clock)(),
                ) {
                    return Ok(entry.value.clone());
                }
                Err(error)
            }
        }
    }

    async fn lookup_uncached(&self, handle: &Handle) -> Result<Did, IdentityError> {
        let (delegated, fallback) = match &self.options.handle_strategy {
            HandleStrategy::Direct => return self.lookup_direct(handle).await,
            HandleStrategy::Xrpc {
                service,
                fallback_to_direct,
            } => (self.lookup_xrpc(handle, service).await, *fallback_to_direct),
            HandleStrategy::Custom {
                lookup,
                fallback_to_direct,
            } => {
                let result = with_deadline(self.options.timeout, lookup.lookup(handle))
                    .await
                    .and_then(|result| result)
                    .and_then(|candidate| {
                        candidate
                            .map(|did| validate_candidate(did.as_str(), handle))
                            .transpose()
                    });
                (result, *fallback_to_direct)
            }
        };

        match delegated {
            Ok(Some(did)) => Ok(did),
            _ if fallback => self.lookup_direct(handle).await,
            Ok(None) => Err(IdentityError::HandleNotFound(handle.clone())),
            Err(err) => Err(err),
        }
    }

    async fn lookup_direct(&self, handle: &Handle) -> Result<Did, IdentityError> {
        let dns = std::pin::pin!(self.lookup_dns(handle));
        let http = std::pin::pin!(self.lookup_https(handle));
        let (dns, http) = match select(dns, http).await {
            Either::Left((Err(error @ IdentityError::HandleAmbiguous { .. }), _)) => {
                return Err(error);
            }
            Either::Left((Ok(Some(did)), _))
                if self.options.handle_conflict == HandleConflictPolicy::PreferDns =>
            {
                return Ok(did);
            }
            Either::Left((dns, http)) => (dns, http.await),
            Either::Right((http, dns)) => (dns.await, http),
        };
        match (dns, http) {
            (Err(error @ IdentityError::HandleAmbiguous { .. }), _) => Err(error),
            (Ok(Some(dns)), Ok(Some(http)))
                if dns != http && self.options.handle_conflict == HandleConflictPolicy::Reject =>
            {
                Err(IdentityError::HandleAmbiguous {
                    handle: handle.clone(),
                    dids: vec![dns, http],
                })
            }
            (Ok(Some(did)), _) | (_, Ok(Some(did))) => Ok(did),
            (Err(err), _) | (_, Err(err)) => Err(IdentityError::HandleLookupFailed {
                handle: handle.clone(),
                reason: err.to_string(),
            }),
            (Ok(None), Ok(None)) => Err(IdentityError::HandleNotFound(handle.clone())),
        }
    }

    async fn lookup_dns(&self, handle: &Handle) -> Result<Option<Did>, IdentityError> {
        let name = format!("_atproto.{}", handle.normalized());
        if name.len() > 253 {
            return Ok(None);
        }
        let records = with_deadline(self.options.timeout, self.dns.txt(&name))
            .await?
            .map_err(|error| IdentityError::HandleLookupFailed {
                handle: handle.clone(),
                reason: error.to_string(),
            })?;
        let mut dids = Vec::new();
        for did in records
            .iter()
            .filter_map(|txt| txt.strip_prefix("did="))
            .filter_map(strict_did)
        {
            if !dids.contains(&did) {
                dids.push(did);
            }
        }
        if dids.len() > 1 {
            return Err(IdentityError::HandleAmbiguous {
                handle: handle.clone(),
                dids,
            });
        }
        Ok(dids.pop())
    }

    async fn lookup_https(&self, handle: &Handle) -> Result<Option<Did>, IdentityError> {
        let url = Url::parse(&format!(
            "https://{}/.well-known/atproto-did",
            handle.normalized()
        ))
        .map_err(|error| IdentityError::HandleLookupFailed {
            handle: handle.clone(),
            reason: error.to_string(),
        })?;
        let response = self
            .get(&url, "text/plain", 4096, RedirectPolicy::Follow)
            .await?;

        match response.status() {
            status if status.is_success() => Ok(std::str::from_utf8(response.body())
                .ok()
                .and_then(|body| strict_did(body.trim()))),
            status if status.is_server_error() || status == StatusCode::TOO_MANY_REQUESTS => {
                Err(IdentityError::UnexpectedStatus { url, status })
            }
            _ => Ok(None),
        }
    }

    async fn lookup_xrpc(
        &self,
        handle: &Handle,
        service: &Url,
    ) -> Result<Option<Did>, IdentityError> {
        let mut url = service.clone();
        url.set_query(None);
        url.set_fragment(None);
        url.path_segments_mut()
            .map_err(|()| IdentityError::BlockedByNetworkPolicy(service.clone()))?
            .pop_if_empty()
            .extend(["xrpc", "com.atproto.identity.resolveHandle"]);
        url.query_pairs_mut()
            .append_pair("handle", handle.normalized());
        let response = self
            .get(&url, "application/json", 16 * 1024, RedirectPolicy::Never)
            .await?;

        #[derive(Deserialize)]
        struct Output {
            did: String,
        }

        match response.status() {
            status if status.is_success() => {
                let body: Output = serde_json::from_slice(response.body()).map_err(|_| {
                    IdentityError::HandleLookupFailed {
                        handle: handle.clone(),
                        reason: "invalid resolveHandle response".to_owned(),
                    }
                })?;
                validate_candidate(&body.did, handle).map(Some)
            }
            StatusCode::BAD_REQUEST | StatusCode::NOT_FOUND => Ok(None),
            status => Err(IdentityError::UnexpectedStatus { url, status }),
        }
    }

    fn document_source(&self, did: &Did) -> Result<(Url, bool), IdentityError> {
        let did = strict_did(did.as_str())
            .ok_or_else(|| IdentityError::InvalidDidSyntax(did.to_string()))?;
        match did.method() {
            "plc" => {
                let mut url = self.options.plc_directory.clone();
                url.set_query(None);
                url.set_fragment(None);
                url.path_segments_mut()
                    .map_err(|()| {
                        IdentityError::BlockedByNetworkPolicy(self.options.plc_directory.clone())
                    })?
                    .pop_if_empty()
                    .push(did.as_str());
                Ok((url, true))
            }
            "web" => {
                let web = DidWebIdentifier::parse(
                    did.as_str(),
                    self.options.allow_development_identifiers,
                )
                .map_err(|reason| match reason {
                    DidWebError::UnsupportedPath => {
                        IdentityError::UnsupportedDidWebPath(did.clone())
                    }
                    reason => IdentityError::InvalidDidWeb {
                        did: did.clone(),
                        reason,
                    },
                })?;
                let url = web
                    .document_url()
                    .map_err(|_| IdentityError::InvalidDidSyntax(did.to_string()))?;
                Ok((url, false))
            }
            _ => Err(IdentityError::UnsupportedDidMethod(did)),
        }
    }

    async fn fetch_document(
        &self,
        did: &Did,
        url: &Url,
        plc: bool,
    ) -> Result<DidDocument, IdentityError> {
        let response = self
            .get(
                url,
                "application/did+ld+json,application/json",
                self.options.max_document_bytes,
                RedirectPolicy::Never,
            )
            .await?;
        match response.status() {
            status if status.is_success() => {}
            StatusCode::NOT_FOUND => return Err(IdentityError::DidNotFound(did.clone())),
            StatusCode::GONE if plc => return Err(IdentityError::DidTombstoned(did.clone())),
            status => {
                return Err(IdentityError::UnexpectedStatus {
                    url: url.clone(),
                    status,
                });
            }
        }

        let document: DidDocument = serde_json::from_slice(response.body())
            .map_err(|_| IdentityError::InvalidDidDocument(did.clone()))?;
        if &document.id != did {
            return Err(IdentityError::DocumentIdMismatch {
                expected: did.clone(),
                actual: document.id,
            });
        }
        Ok(document)
    }

    async fn get(
        &self,
        url: &Url,
        accept: &str,
        size: usize,
        redirects: RedirectPolicy,
    ) -> Result<Response<Bytes>, IdentityError> {
        let request = Request::get(url.as_str())
            .header(ACCEPT, accept)
            .body(Bytes::new())
            .map_err(|error| IdentityError::Transport {
                url: url.clone(),
                reason: error.to_string(),
            })?;
        let size = size.min(128 * 1024 * 1024);
        let options = SendOptions {
            timeout: Some(self.options.timeout),
            max_response_bytes: Some(size as u64),
            allow_loopback: self.options.allow_development_identifiers,
            anonymous: true,
            ..SendOptions::default()
        };
        let result = with_deadline(
            self.options.timeout,
            send_with_redirects(self.transport.as_ref(), request, &options, redirects),
        )
        .await?;
        let response = result.map_err(|error| match error {
            TransportError::Timeout => IdentityError::TimedOut,
            TransportError::PolicyViolation(_) => {
                IdentityError::BlockedByNetworkPolicy(url.clone())
            }
            TransportError::ResponseTooLarge { .. } => IdentityError::ResponseTooLarge(url.clone()),
            error => IdentityError::Transport {
                url: url.clone(),
                reason: error.to_string(),
            },
        })?;
        if response.body().len() > size {
            return Err(IdentityError::ResponseTooLarge(url.clone()));
        }
        Ok(response)
    }
}

fn strict_did(value: &str) -> Option<Did> {
    let did: Did = value.parse().ok()?;
    if did.method().bytes().all(|byte| byte.is_ascii_lowercase()) && !value.ends_with([':', '%']) {
        Some(did)
    } else {
        None
    }
}

fn validate_candidate(value: &str, handle: &Handle) -> Result<Did, IdentityError> {
    strict_did(value).ok_or_else(|| IdentityError::HandleLookupFailed {
        handle: handle.clone(),
        reason: "lookup returned invalid DID syntax".to_owned(),
    })
}

fn fresh<T>(
    cached: &Option<CacheEntry<T>>,
    max_age: Duration,
    now: SystemTime,
) -> Option<&CacheEntry<T>> {
    cached.as_ref().filter(|entry| entry.within(max_age, now))
}

async fn with_deadline<T>(
    duration: Duration,
    work: impl Future<Output = T>,
) -> Result<T, IdentityError> {
    #[cfg(any(
        all(not(target_arch = "wasm32"), feature = "native"),
        all(target_arch = "wasm32", feature = "wasm")
    ))]
    {
        crate::rt::timeout(duration, work)
            .await
            .map_err(|_| IdentityError::TimedOut)
    }
    #[cfg(not(any(
        all(not(target_arch = "wasm32"), feature = "native"),
        all(target_arch = "wasm32", feature = "wasm")
    )))]
    {
        let _ = duration;
        Ok(work.await)
    }
}
