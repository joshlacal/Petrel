use petrel_core::AtIdentifier;

use crate::{
    identity::{DnsResolver, HandleVerification, IdentityCache, IdentityResolver, ServiceKind},
    rt::BoxFuture,
};

use super::{OAuthIdentity, OAuthIdentityError, OAuthIdentityResolver};

/// Uses Petrel's DID and handle resolver to bind authorization to an account PDS.
#[derive(Debug)]
pub struct OAuthIdentityAdapter<D, C> {
    resolver: IdentityResolver<D, C>,
    allow_loopback: bool,
}

impl<D, C> OAuthIdentityAdapter<D, C> {
    pub fn new(resolver: IdentityResolver<D, C>) -> Self {
        Self {
            resolver,
            allow_loopback: false,
        }
    }

    /// Permit exact loopback PDS endpoints from local development DID documents.
    #[must_use]
    pub fn with_loopback_development(mut self) -> Self {
        self.allow_loopback = true;
        self
    }
}

impl<D: DnsResolver, C: IdentityCache> OAuthIdentityResolver for OAuthIdentityAdapter<D, C> {
    fn resolve_identity<'a>(
        &'a self,
        identifier: &'a AtIdentifier,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<OAuthIdentity, OAuthIdentityError>> {
        Box::pin(async move {
            let did = match identifier {
                AtIdentifier::Did(did) => did.clone(),
                AtIdentifier::Handle(handle) => self
                    .resolver
                    .resolve_handle_with_refresh(handle, force_refresh)
                    .await
                    .map_err(|_| OAuthIdentityError)?,
            };
            let resolved = self
                .resolver
                .resolve_identity_with_refresh(&did, force_refresh)
                .await
                .map_err(|_| OAuthIdentityError)?;
            let pds = resolved
                .document
                .validated_service_endpoint_with_development(ServiceKind::Pds, self.allow_loopback)
                .map_err(|_| OAuthIdentityError)?
                .ok_or(OAuthIdentityError)?;
            Ok(OAuthIdentity {
                did,
                handle: (resolved.verification == HandleVerification::Verified)
                    .then_some(resolved.handle),
                pds,
            })
        })
    }
}
