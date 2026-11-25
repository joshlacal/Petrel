//! Adapters bridging [`petrel::identity`] DNS and DID resolvers into `petrel-lexicon`.

use std::sync::Arc;

use petrel::identity::{
    DnsResolver, IdentityCache, IdentityResolver, InMemoryIdentityCache, ServiceKind,
};
use petrel::net::SharedTransport;
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use petrel_core::Did;

use crate::resolver::{
    DefaultLexiconResolver, LexiconDidResolver, LexiconDnsResolver, LexiconHttpRecordFetcher,
    LexiconRepoProofVerifier, LexiconResolutionCache, LexiconResolutionError,
    ResolvedLexiconIdentity,
};

/// Adapter wrapping any [`petrel::identity::DnsResolver`] as a [`LexiconDnsResolver`].
pub struct IdentityLexiconDnsResolver<D> {
    inner: Arc<D>,
}

impl<D> Clone for IdentityLexiconDnsResolver<D> {
    fn clone(&self) -> Self {
        Self {
            inner: Arc::clone(&self.inner),
        }
    }
}

impl<D> std::fmt::Debug for IdentityLexiconDnsResolver<D> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("IdentityLexiconDnsResolver")
            .finish_non_exhaustive()
    }
}

impl<D: DnsResolver + MaybeSend + MaybeSync> IdentityLexiconDnsResolver<D> {
    /// Wrap a [`petrel::identity::DnsResolver`].
    pub fn new(inner: Arc<D>) -> Self {
        Self { inner }
    }
}

impl<D: DnsResolver + MaybeSend + MaybeSync> LexiconDnsResolver for IdentityLexiconDnsResolver<D> {
    fn lookup_txt<'a>(
        &'a self,
        domain: &'a str,
    ) -> BoxFuture<'a, Result<Vec<String>, LexiconResolutionError>> {
        Box::pin(async move {
            self.inner
                .txt(domain)
                .await
                .map_err(|err| LexiconResolutionError::DnsFailed {
                    domain: domain.to_owned(),
                    message: err.to_string(),
                })
        })
    }
}

/// Adapter wrapping [`petrel::identity::IdentityResolver`] as a [`LexiconDidResolver`].
pub struct IdentityLexiconDidResolver<D, C = InMemoryIdentityCache> {
    inner: Arc<IdentityResolver<D, C>>,
}

impl<D, C> Clone for IdentityLexiconDidResolver<D, C> {
    fn clone(&self) -> Self {
        Self {
            inner: Arc::clone(&self.inner),
        }
    }
}

impl<D, C> std::fmt::Debug for IdentityLexiconDidResolver<D, C> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("IdentityLexiconDidResolver")
            .finish_non_exhaustive()
    }
}

impl<D, C> IdentityLexiconDidResolver<D, C> {
    /// Wrap an [`IdentityResolver`].
    pub fn new(inner: Arc<IdentityResolver<D, C>>) -> Self {
        Self { inner }
    }

    /// Borrow the wrapped [`IdentityResolver`].
    pub fn inner(&self) -> &IdentityResolver<D, C> {
        &self.inner
    }
}

impl<D, C> LexiconDidResolver for IdentityLexiconDidResolver<D, C>
where
    D: DnsResolver + MaybeSend + MaybeSync,
    C: IdentityCache + MaybeSend + MaybeSync,
{
    fn resolve_identity<'a>(
        &'a self,
        did: &'a Did,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<ResolvedLexiconIdentity, LexiconResolutionError>> {
        Box::pin(async move {
            let doc = if force_refresh {
                self.inner.refresh_did_document(did).await
            } else {
                self.inner.resolve_did_document(did).await
            }
            .map_err(|err| LexiconResolutionError::IdentityFailed {
                did: did.to_string(),
                message: err.to_string(),
            })?;

            let pds_endpoint = doc
                .validated_service_endpoint(ServiceKind::Pds)
                .map_err(|err| LexiconResolutionError::IdentityFailed {
                    did: did.to_string(),
                    message: err.to_string(),
                })?
                .ok_or_else(|| LexiconResolutionError::IdentityFailed {
                    did: did.to_string(),
                    message: "DID document has no valid #atproto_pds service endpoint".to_owned(),
                })?;

            let signing_key = doc.signing_key().ok();

            Ok(ResolvedLexiconIdentity {
                pds_endpoint,
                signing_key,
            })
        })
    }
}

/// Convenience constructors pairing [`petrel`] transport + identity primitives into a [`DefaultLexiconResolver`].
#[derive(Debug, Clone, Copy)]
pub struct LexiconIdentityResolution;

impl LexiconIdentityResolution {
    /// Build the default proof-verifying [`DefaultLexiconResolver`] from [`petrel::identity::IdentityResolver`]
    /// using signed `com.atproto.sync.getRecord` CAR proofs verified by [`crate::DefaultLexiconRepoProofVerifier`].
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    pub fn default_resolver<D, C>(
        identity: Arc<IdentityResolver<D, C>>,
        dns: Arc<D>,
        transport: SharedTransport,
        cache: LexiconResolutionCache,
    ) -> DefaultLexiconResolver
    where
        D: DnsResolver + MaybeSend + MaybeSync + 'static,
        C: IdentityCache + MaybeSend + MaybeSync + 'static,
    {
        DefaultLexiconResolver::new(
            Arc::new(IdentityLexiconDnsResolver::new(dns)),
            Arc::new(IdentityLexiconDidResolver::new(identity)),
            Arc::new(LexiconHttpRecordFetcher::new(transport)),
            cache,
        )
    }

    /// Build a proof-verifying [`DefaultLexiconResolver`] backed by `com.atproto.sync.getRecord`
    /// and a custom [`LexiconRepoProofVerifier`] implementation.
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    pub fn verified_resolver<D, C>(
        identity: Arc<IdentityResolver<D, C>>,
        dns: Arc<D>,
        transport: SharedTransport,
        verifier: Arc<dyn LexiconRepoProofVerifier>,
        cache: LexiconResolutionCache,
    ) -> DefaultLexiconResolver
    where
        D: DnsResolver + MaybeSend + MaybeSync + 'static,
        C: IdentityCache + MaybeSend + MaybeSync + 'static,
    {
        DefaultLexiconResolver::new(
            Arc::new(IdentityLexiconDnsResolver::new(dns)),
            Arc::new(IdentityLexiconDidResolver::new(identity)),
            Arc::new(LexiconHttpRecordFetcher::with_proof_verifier(
                transport, verifier,
            )),
            cache,
        )
    }

    /// Build an unverified [`DefaultLexiconResolver`] that explicitly opts out of CAR/commit/MST proof
    /// verification and instead trusts unsigned `com.atproto.repo.getRecord` JSON from the PDS.
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    pub fn unverified_resolver<D, C>(
        identity: Arc<IdentityResolver<D, C>>,
        dns: Arc<D>,
        transport: SharedTransport,
        cache: LexiconResolutionCache,
    ) -> DefaultLexiconResolver
    where
        D: DnsResolver + MaybeSend + MaybeSync + 'static,
        C: IdentityCache + MaybeSend + MaybeSync + 'static,
    {
        DefaultLexiconResolver::new(
            Arc::new(IdentityLexiconDnsResolver::new(dns)),
            Arc::new(IdentityLexiconDidResolver::new(identity)),
            Arc::new(LexiconHttpRecordFetcher::unverified(transport)),
            cache,
        )
    }
}
