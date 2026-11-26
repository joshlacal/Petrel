//! AT Protocol inter-service authentication JWT verification (`ES256` / `ES256K`),
//! re-exporting core verification, replay protection, and key types from [`petrel_crypto`]
//! paired with server adapters for [`petrel::identity::IdentityResolver`] and
//! [`crate::store::OAuthReplayStore`].

use std::sync::Arc;

use petrel::identity::{DnsResolver, IdentityCache, IdentityResolver, SigningCurve};
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use petrel_core::Did;
use web_time::{SystemTime, UNIX_EPOCH};

pub use petrel_crypto::{
    ATProtoKeyCurve, ATProtoSignatureVerificationOptions, CachingServiceAuthKeyResolver,
    ClosureServiceAuthKeyResolver, InMemoryServiceAuthReplayStore, PublicKey, ReplayStoreError,
    ServiceAuthAudience, ServiceAuthError, ServiceAuthKeyResolver, ServiceAuthMethodPolicy,
    ServiceAuthReplayStore, ServiceAuthRequiredClaims, ServiceAuthVerifier,
    ServiceAuthVerifierConfig, ServiceAuthVerifierConfiguration, ServiceJWT, ServiceJWTClaims,
    ServiceJWTInspection, ServiceJWTMintOptions, ServiceJWTSigningKey, ServiceJWTVerifyOptions,
    StaticServiceAuthKeyResolver, VerifiedServiceAuth,
};

use crate::jose::{OAuthCurve, OAuthJsonWebKey};
use crate::store::{OAuthReplayNamespace, OAuthReplayStore};
use crate::support::{DigestPurpose, OAuthKeyedDigest};

/// Converts an [`OAuthJsonWebKey`] into a [`petrel_crypto::PublicKey`].
pub fn public_key_from_jwk(jwk: &OAuthJsonWebKey) -> Result<PublicKey, ServiceAuthError> {
    let sec1 = jwk
        .to_sec1_uncompressed()
        .map_err(|err| ServiceAuthError::MalformedToken(err.to_string()))?;
    let curve = match jwk.crv {
        OAuthCurve::P256 => ATProtoKeyCurve::P256,
        OAuthCurve::Secp256k1 => ATProtoKeyCurve::Secp256k1,
    };
    PublicKey::from_sec1(curve, &sec1)
        .map_err(|err| ServiceAuthError::MalformedToken(err.to_string()))
}

/// Production [`ServiceAuthKeyResolver`] backed by `petrel::identity::IdentityResolver`.
pub struct IdentityResolverServiceAuthKeyResolver<D: DnsResolver, C: IdentityCache> {
    resolver: Arc<IdentityResolver<D, C>>,
}

impl<D: DnsResolver, C: IdentityCache> std::fmt::Debug
    for IdentityResolverServiceAuthKeyResolver<D, C>
{
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("IdentityResolverServiceAuthKeyResolver")
            .finish_non_exhaustive()
    }
}

impl<D: DnsResolver, C: IdentityCache> IdentityResolverServiceAuthKeyResolver<D, C> {
    /// Wraps an existing `IdentityResolver`.
    pub fn new(resolver: Arc<IdentityResolver<D, C>>) -> Self {
        Self { resolver }
    }
}

impl<D: DnsResolver + MaybeSend + MaybeSync + 'static, C: IdentityCache + 'static>
    ServiceAuthKeyResolver for IdentityResolverServiceAuthKeyResolver<D, C>
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
        let did_str = did.to_owned();
        let frag = key_id.trim_start_matches('#').to_owned();
        let full_key_id = format!("#{frag}");
        Box::pin(async move {
            let parsed_did = Did::parse(&did_str)
                .map_err(|_| ServiceAuthError::InvalidIssuer(did_str.clone()))?;
            let doc = if force_refresh {
                self.resolver.refresh_did_document(&parsed_did).await
            } else {
                self.resolver.resolve_did_document(&parsed_did).await
            }
            .map_err(|err| ServiceAuthError::KeyResolutionFailed {
                did: did_str.clone(),
                key_id: full_key_id.clone(),
                reason: err.to_string(),
            })?;

            let key = if frag == "atproto" {
                doc.signing_key()
            } else {
                doc.verification_key(&full_key_id)
            }
            .map_err(|err| ServiceAuthError::KeyResolutionFailed {
                did: did_str.clone(),
                key_id: full_key_id.clone(),
                reason: err.to_string(),
            })?;

            let curve = match key.curve() {
                SigningCurve::P256 => ATProtoKeyCurve::P256,
                SigningCurve::Secp256k1 => ATProtoKeyCurve::Secp256k1,
            };
            PublicKey::from_sec1(curve, key.as_sec1()).map_err(|err| {
                ServiceAuthError::KeyResolutionFailed {
                    did: did_str,
                    key_id: full_key_id,
                    reason: err.to_string(),
                }
            })
        })
    }
}

/// Adapter backing [`ServiceAuthReplayStore`] with any [`OAuthReplayStore`].
pub struct OAuthReplayStoreServiceAuthAdapter {
    store: Arc<dyn OAuthReplayStore>,
    digest: OAuthKeyedDigest,
}

impl std::fmt::Debug for OAuthReplayStoreServiceAuthAdapter {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("OAuthReplayStoreServiceAuthAdapter")
            .finish_non_exhaustive()
    }
}

impl OAuthReplayStoreServiceAuthAdapter {
    /// Creates a service-auth replay store adapter using `digest` for domain separation.
    pub fn new(store: Arc<dyn OAuthReplayStore>, digest: OAuthKeyedDigest) -> Self {
        Self { store, digest }
    }
}

impl ServiceAuthReplayStore for OAuthReplayStoreServiceAuthAdapter {
    fn claim<'a>(
        &'a self,
        nonce: &'a str,
        issuer: &'a str,
        expires_at: SystemTime,
    ) -> BoxFuture<'a, Result<bool, ReplayStoreError>> {
        let key = format!("{issuer}\0{nonce}");
        let digest = self.digest.digest_str(&key, DigestPurpose::DPoPProof);
        let exp_secs = expires_at
            .duration_since(UNIX_EPOCH)
            .map_or(0, |d| i64::try_from(d.as_secs()).unwrap_or(i64::MAX));
        let now_secs = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_or(0, |d| i64::try_from(d.as_secs()).unwrap_or(i64::MAX));
        Box::pin(async move {
            self.store
                .record_if_fresh(
                    OAuthReplayNamespace::ServiceAuth,
                    digest,
                    exp_secs,
                    now_secs,
                )
                .await
                .map_err(|err| ReplayStoreError::Backend(err.to_string()))
        })
    }
}
