use std::{fmt, future::Future, sync::Arc, time::Duration};

use bytes::Bytes;
use futures_util::future::{Either, select};
use http::{Request, Response, StatusCode, header::ACCEPT};
use petrel_core::{Did, Handle};
use petrel_crypto::{PublicKey, ServiceAuthError, ServiceAuthKeyResolver};
use serde::Deserialize;
use url::Url;
use web_time::SystemTime;

use super::{
    CacheEntry, CachePolicy, DidDocument, DidServiceIdentifier, DidWebError, DidWebIdentifier,
    DnsResolver, IdentityCache, InMemoryIdentityCache, ServiceKind, SigningKey,
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
    #[error("invalid handle syntax: {0}")]
    InvalidHandleSyntax(String),
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
    #[error("{did} has no {fragment} service")]
    MissingService { did: Did, fragment: String },
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

/// Ordering for direct DNS TXT and HTTPS `.well-known/atproto-did` handle lookups.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum DirectLookupOrder {
    /// Race DNS TXT and HTTPS `.well-known/atproto-did` in parallel.
    #[default]
    Race,
    /// Query DNS TXT first; fall back to HTTPS `.well-known` if DNS finds nothing or fails transiently.
    DnsFirst,
    /// Query HTTPS `.well-known` first; fall back to DNS TXT if HTTPS finds nothing or fails transiently.
    HttpFirst,
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
    pub direct_order: DirectLookupOrder,
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
            direct_order: DirectLookupOrder::Race,
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

impl ResolvedIdentity {
    /// Whether `handle` was verified bidirectionally.
    pub fn is_handle_verified(&self) -> bool {
        self.verification == HandleVerification::Verified
    }

    /// The handle the DID document claims, whether or not it verified.
    pub fn claimed_handle(&self) -> Option<Handle> {
        self.document.claimed_handle()
    }

    /// The account's PDS endpoint, or `None` when absent/invalid.
    pub fn pds_endpoint(&self) -> Option<Url> {
        self.document.pds_endpoint()
    }

    /// The account's `#atproto` signing key.
    pub fn signing_key(&self) -> Result<PublicKey, IdentityError> {
        self.document.atproto_signing_key()
    }
}

/// High-level DID and handle lookups used by ATProto clients.
pub trait DidResolving: MaybeSend + MaybeSync {
    fn resolve_handle_to_did<'a>(
        &'a self,
        handle: &'a str,
    ) -> BoxFuture<'a, Result<Did, IdentityError>>;

    fn resolve_did_to_pds_url<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<Url, IdentityError>>;

    fn resolve_did_to_handle_and_pds_url<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<(Handle, Url), IdentityError>>;
}

/// Resolve DIDs and verify both sides of a DID-to-handle relationship.
#[must_use]
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

    /// Creates a resolver backed by an in-memory cache with the given per-category capacity.
    pub fn with_cache_capacity(
        transport: SharedTransport,
        dns: D,
        options: IdentityOptions,
        capacity: usize,
    ) -> Self {
        Self::with_cache(
            transport,
            dns,
            options,
            InMemoryIdentityCache::new(capacity),
        )
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

    /// Returns the configuration this resolver was constructed with.
    pub fn options(&self) -> &IdentityOptions {
        &self.options
    }

    pub async fn resolve_handle(&self, handle: &Handle) -> Result<Did, IdentityError> {
        self.resolve_handle_with_refresh(handle, false).await
    }

    /// Resolves a handle string to a verified DID.
    pub async fn resolve_handle_str(
        &self,
        handle: &str,
        force_refresh: bool,
    ) -> Result<Did, IdentityError> {
        let handle: Handle = handle
            .parse()
            .map_err(|_| IdentityError::InvalidHandleSyntax(handle.to_owned()))?;
        self.resolve_handle_with_refresh(&handle, force_refresh)
            .await
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

    /// Resolves a DID string to its document.
    pub async fn resolve_did_document_str(
        &self,
        did: &str,
        force_refresh: bool,
    ) -> Result<DidDocument, IdentityError> {
        let parsed =
            strict_did(did).ok_or_else(|| IdentityError::InvalidDidSyntax(did.to_owned()))?;
        self.resolve_document(&parsed, force_refresh).await
    }

    pub async fn refresh_did_document(&self, did: &Did) -> Result<DidDocument, IdentityError> {
        self.resolve_document(did, true).await
    }

    pub async fn resolve_identity(&self, did: &Did) -> Result<ResolvedIdentity, IdentityError> {
        self.resolve_identity_with_refresh(did, false).await
    }

    /// Resolves either a DID or a handle string into a verified identity.
    pub async fn resolve_identity_str(
        &self,
        identifier: &str,
        force_refresh: bool,
    ) -> Result<ResolvedIdentity, IdentityError> {
        if identifier.starts_with("did:") {
            let did = strict_did(identifier)
                .ok_or_else(|| IdentityError::InvalidDidSyntax(identifier.to_owned()))?;
            return self
                .resolve_identity_with_refresh(&did, force_refresh)
                .await;
        }
        let handle: Handle = identifier
            .parse()
            .map_err(|_| IdentityError::InvalidHandleSyntax(identifier.to_owned()))?;
        self.validate_handle(&handle)?;
        let did = self.lookup_handle(&handle, force_refresh).await?;
        let document = self.resolve_document(&did, force_refresh).await?;
        if document.claimed_handle().as_ref() != Some(&handle) {
            self.cache.remove_handle(&handle).await;
            return Err(IdentityError::HandleNotClaimedByDid { handle, did });
        }
        Ok(ResolvedIdentity {
            did,
            handle,
            verification: HandleVerification::Verified,
            document,
        })
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
            handle: handle.unwrap_or_else(invalid_handle),
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
        let allow_dev_endpoint = self.allows_development_endpoint_for(did);
        self.resolve_did_document(did)
            .await?
            .validated_service_endpoint_with_development(kind, allow_dev_endpoint)
    }

    fn allows_development_endpoint_for(&self, did: &Did) -> bool {
        if !self.options.allow_development_identifiers {
            return false;
        }
        match did.method() {
            "web" => DidWebIdentifier::parse(did.as_str(), true).is_ok_and(|web| {
                let host = web.host();
                host == "localhost"
                    || host
                        .rsplit_once('.')
                        .is_some_and(|(_, tld)| tld.eq_ignore_ascii_case("test"))
            }),
            "plc" => is_development_url(&self.options.plc_directory),
            _ => false,
        }
    }

    /// Resolves a DID's required `#atproto_pds` service URL.
    pub async fn resolve_did_to_pds_url(&self, did: &str) -> Result<Url, IdentityError> {
        self.resolve_did_document_str(did, false)
            .await?
            .service_endpoint_with_development(
                &DidServiceIdentifier::pds(),
                self.options.allow_development_identifiers,
            )
    }

    /// Resolves a DID's verified handle (or `handle.invalid`) and required `#atproto_pds` URL.
    pub async fn resolve_did_to_handle_and_pds_url(
        &self,
        did: &str,
    ) -> Result<(Handle, Url), IdentityError> {
        let parsed =
            strict_did(did).ok_or_else(|| IdentityError::InvalidDidSyntax(did.to_owned()))?;
        let identity = self.resolve_identity_with_refresh(&parsed, false).await?;
        let pds = identity.document.service_endpoint_with_development(
            &DidServiceIdentifier::pds(),
            self.options.allow_development_identifiers,
        )?;
        Ok((identity.handle, pds))
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
        let dev = handle
            .normalized()
            .rsplit_once('.')
            .is_some_and(|(_, tld)| tld == "test");
        if !handle.is_valid_tld() || (dev && !self.options.allow_development_identifiers) {
            return Err(IdentityError::ReservedHandleTld(handle.clone()));
        }
        Ok(())
    }

    async fn resolve_document(&self, did: &Did, force: bool) -> Result<DidDocument, IdentityError> {
        let (url, plc) = self.document_source(did)?;
        let now = (self.clock)();
        let cached = if force {
            None
        } else {
            self.cache.document(did).await
        };
        if let Some(entry) = fresh(cached.as_ref(), self.options.cache_policy.fresh_for, now) {
            return Ok(entry.value.clone());
        }
        if !force && self.options.cache_policy.negative_ttl > Duration::ZERO {
            let neg = self.cache.negative_document(did).await;
            if let Some(entry) = fresh(neg.as_ref(), self.options.cache_policy.negative_ttl, now) {
                return Err(entry.value.clone());
            }
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
                    if self.options.cache_policy.negative_ttl > Duration::ZERO {
                        self.cache
                            .put_negative_document(
                                did.clone(),
                                CacheEntry {
                                    value: error.clone(),
                                    stored_at: (self.clock)(),
                                },
                            )
                            .await;
                    }
                } else if let Some(entry) = fresh(
                    cached.as_ref(),
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
        let now = (self.clock)();
        let cached = if force {
            None
        } else {
            self.cache.handle(handle).await
        };
        if let Some(entry) = fresh(cached.as_ref(), self.options.cache_policy.fresh_for, now) {
            return Ok(entry.value.clone());
        }
        if !force && self.options.cache_policy.negative_ttl > Duration::ZERO {
            let neg = self.cache.negative_handle(handle).await;
            if let Some(entry) = fresh(neg.as_ref(), self.options.cache_policy.negative_ttl, now) {
                return Err(entry.value.clone());
            }
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
                    if self.options.cache_policy.negative_ttl > Duration::ZERO {
                        self.cache
                            .put_negative_handle(
                                handle.clone(),
                                CacheEntry {
                                    value: error.clone(),
                                    stored_at: (self.clock)(),
                                },
                            )
                            .await;
                    }
                } else if let Some(entry) = fresh(
                    cached.as_ref(),
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
        match self.options.direct_order {
            DirectLookupOrder::Race => {
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
                combine_direct_outcomes(handle, dns, http, self.options.handle_conflict)
            }
            DirectLookupOrder::DnsFirst => {
                let dns = self.lookup_dns(handle).await;
                if let Err(error @ IdentityError::HandleAmbiguous { .. }) = dns {
                    return Err(error);
                }
                if let Ok(Some(did)) = &dns
                    && self.options.handle_conflict == HandleConflictPolicy::PreferDns
                {
                    return Ok(did.clone());
                }
                let http = self.lookup_https(handle).await;
                combine_direct_outcomes(handle, dns, http, self.options.handle_conflict)
            }
            DirectLookupOrder::HttpFirst => {
                let http = self.lookup_https(handle).await;
                if let Ok(Some(did)) = &http
                    && self.options.handle_conflict == HandleConflictPolicy::PreferDns
                {
                    return Ok(did.clone());
                }
                let dns = self.lookup_dns(handle).await;
                combine_direct_outcomes(handle, dns, http, self.options.handle_conflict)
            }
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
        let mut dids = dids_in_txt_records(&records);
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

        match response.status() {
            status if status.is_success() => {
                let body: ResolveHandleOutput =
                    serde_json::from_slice(response.body()).map_err(|_| {
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
            allow_loopback: self.options.allow_development_identifiers && is_loopback_url(url),
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

impl<D: DnsResolver, C: IdentityCache> DidResolving for IdentityResolver<D, C> {
    fn resolve_handle_to_did<'a>(
        &'a self,
        handle: &'a str,
    ) -> BoxFuture<'a, Result<Did, IdentityError>> {
        Box::pin(self.resolve_handle_str(handle, false))
    }

    fn resolve_did_to_pds_url<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<Url, IdentityError>> {
        Box::pin(Self::resolve_did_to_pds_url(self, did))
    }

    fn resolve_did_to_handle_and_pds_url<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<(Handle, Url), IdentityError>> {
        Box::pin(Self::resolve_did_to_handle_and_pds_url(self, did))
    }
}

impl<D: DnsResolver, C: IdentityCache> ServiceAuthKeyResolver for IdentityResolver<D, C> {
    fn signing_key<'a>(
        &'a self,
        did: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<PublicKey, ServiceAuthError>> {
        self.signing_key_for_id(did, "#atproto", force_refresh)
    }

    fn signing_key_for_id<'a>(
        &'a self,
        did: &'a str,
        key_id: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<PublicKey, ServiceAuthError>> {
        Box::pin(async move {
            let document = self
                .resolve_did_document_str(did, force_refresh)
                .await
                .map_err(|error| ServiceAuthError::KeyResolutionFailed {
                    did: did.to_owned(),
                    key_id: key_id.to_owned(),
                    reason: error.to_string(),
                })?;
            let key = document.verification_key(key_id).map_err(|error| {
                ServiceAuthError::KeyResolutionFailed {
                    did: did.to_owned(),
                    key_id: key_id.to_owned(),
                    reason: error.to_string(),
                }
            })?;
            key.to_public_key()
                .map_err(|error| ServiceAuthError::KeyResolutionFailed {
                    did: did.to_owned(),
                    key_id: key_id.to_owned(),
                    reason: error.to_string(),
                })
        })
    }
}

trait ResolveDocumentCallback:
    for<'a> Fn(&'a str, bool) -> BoxFuture<'a, Result<DidDocument, ServiceAuthError>>
    + MaybeSend
    + MaybeSync
{
}

impl<F> ResolveDocumentCallback for F where
    F: for<'a> Fn(&'a str, bool) -> BoxFuture<'a, Result<DidDocument, ServiceAuthError>>
        + MaybeSend
        + MaybeSync
{
}

/// Resolves service-auth signing keys from a custom DID document source.
#[derive(Clone)]
pub struct DidDocumentServiceAuthKeyResolver {
    resolve_document: Arc<dyn ResolveDocumentCallback>,
}

impl fmt::Debug for DidDocumentServiceAuthKeyResolver {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("DidDocumentServiceAuthKeyResolver")
            .finish_non_exhaustive()
    }
}

impl DidDocumentServiceAuthKeyResolver {
    /// Creates a key resolver backed by any async DID document lookup function.
    #[must_use]
    pub fn new<F>(resolve_document: F) -> Self
    where
        F: for<'a> Fn(&'a str, bool) -> BoxFuture<'a, Result<DidDocument, ServiceAuthError>>
            + MaybeSend
            + MaybeSync
            + 'static,
    {
        Self {
            resolve_document: Arc::new(resolve_document),
        }
    }

    /// Reads the verification key published under `key_id` out of `document`.
    pub fn signing_key_in_document(
        document: &DidDocument,
        did: &str,
        key_id: &str,
    ) -> Result<PublicKey, ServiceAuthError> {
        let failure = |reason: String| ServiceAuthError::KeyResolutionFailed {
            did: did.to_owned(),
            key_id: key_id.to_owned(),
            reason,
        };
        if document.id.as_str() != did {
            return Err(failure(format!("DID document is for {}", document.id)));
        }
        let full_id = format!("{did}{key_id}");
        let method = document
            .verification_methods
            .iter()
            .find(|method| method.id == key_id || method.id == full_id)
            .ok_or_else(|| failure(format!("DID document has no verification method {key_id}")))?;
        PublicKey::from_verification_method(&method.kind, &method.public_key_multibase).map_err(
            |error| {
                failure(format!(
                    "verification method {key_id} does not hold a P-256 or K-256 key ({error})"
                ))
            },
        )
    }
}

impl ServiceAuthKeyResolver for DidDocumentServiceAuthKeyResolver {
    fn signing_key<'a>(
        &'a self,
        did: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<PublicKey, ServiceAuthError>> {
        self.signing_key_for_id(did, "#atproto", force_refresh)
    }

    fn signing_key_for_id<'a>(
        &'a self,
        did: &'a str,
        key_id: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<PublicKey, ServiceAuthError>> {
        Box::pin(async move {
            let document = (self.resolve_document)(did, force_refresh).await?;
            Self::signing_key_in_document(&document, did, key_id)
        })
    }
}

/// Client-oriented `DidResolving` wrapper over an `IdentityResolver` configured with an
/// XRPC `resolveHandle` lookup and direct fallback.
#[derive(Debug)]
pub struct DidResolutionService<D, C = InMemoryIdentityCache> {
    identity_resolver: IdentityResolver<D, C>,
}

impl<D: DnsResolver> DidResolutionService<D, InMemoryIdentityCache> {
    /// Creates a resolution service that asks `service` via `com.atproto.identity.resolveHandle`
    /// and falls back to direct DNS/HTTPS lookups.
    #[must_use]
    pub fn with_service_url(
        transport: SharedTransport,
        dns: D,
        service: Url,
        allow_development_identifiers: bool,
    ) -> Self {
        let options = IdentityOptions {
            handle_strategy: HandleStrategy::Xrpc {
                service,
                fallback_to_direct: true,
            },
            allow_development_identifiers,
            ..IdentityOptions::default()
        };
        Self {
            identity_resolver: IdentityResolver::new(transport, dns, options),
        }
    }
}

impl<D: DnsResolver, C: IdentityCache> DidResolutionService<D, C> {
    /// Wraps an already-configured `IdentityResolver`.
    #[must_use]
    pub fn from_resolver(identity_resolver: IdentityResolver<D, C>) -> Self {
        Self { identity_resolver }
    }

    /// Accesses the underlying `IdentityResolver`.
    pub fn identity_resolver(&self) -> &IdentityResolver<D, C> {
        &self.identity_resolver
    }
}

impl<D: DnsResolver, C: IdentityCache> DidResolving for DidResolutionService<D, C> {
    fn resolve_handle_to_did<'a>(
        &'a self,
        handle: &'a str,
    ) -> BoxFuture<'a, Result<Did, IdentityError>> {
        <IdentityResolver<D, C> as DidResolving>::resolve_handle_to_did(
            &self.identity_resolver,
            handle,
        )
    }

    fn resolve_did_to_pds_url<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<Url, IdentityError>> {
        <IdentityResolver<D, C> as DidResolving>::resolve_did_to_pds_url(
            &self.identity_resolver,
            did,
        )
    }

    fn resolve_did_to_handle_and_pds_url<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<(Handle, Url), IdentityError>> {
        <IdentityResolver<D, C> as DidResolving>::resolve_did_to_handle_and_pds_url(
            &self.identity_resolver,
            did,
        )
    }
}

/// Distinct, syntactically valid DIDs carried by `did=` TXT records, in order.
pub fn dids_in_txt_records(records: &[String]) -> Vec<Did> {
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
    dids
}

/// Returns `true` iff `value` satisfies strict AT Protocol DID syntax.
pub fn is_strictly_valid_did(value: &str) -> bool {
    strict_did(value).is_some()
}

fn combine_direct_outcomes(
    handle: &Handle,
    dns: Result<Option<Did>, IdentityError>,
    http: Result<Option<Did>, IdentityError>,
    conflict_policy: HandleConflictPolicy,
) -> Result<Did, IdentityError> {
    match (dns, http) {
        (Err(error @ IdentityError::HandleAmbiguous { .. }), _) => Err(error),
        (Ok(Some(dns)), Ok(Some(http)))
            if dns != http && conflict_policy == HandleConflictPolicy::Reject =>
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

#[derive(Deserialize)]
struct ResolveHandleOutput {
    did: String,
}

fn invalid_handle() -> Handle {
    "handle.invalid".parse().expect("fixed handle sentinel")
}

fn is_loopback_url(url: &Url) -> bool {
    matches!(url.host_str(), Some("localhost" | "127.0.0.1" | "[::1]"))
}

fn is_development_url(url: &Url) -> bool {
    is_loopback_url(url)
        || url.host_str().is_some_and(|host| {
            host.trim_end_matches('.')
                .rsplit_once('.')
                .is_some_and(|(_, tld)| tld.eq_ignore_ascii_case("test"))
        })
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
    cached: Option<&CacheEntry<T>>,
    max_age: Duration,
    now: SystemTime,
) -> Option<&CacheEntry<T>> {
    cached.filter(|entry| entry.within(max_age, now))
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
