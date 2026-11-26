//! Network [`OAuthLexiconResolving`] implementing the full AT Protocol Lexicon
//! resolution and cryptographic repository proof chain (`_lexicon.<authority>` TXT ->
//! DID document -> `com.atproto.sync.getRecord` CAR proof -> schema verification).

use std::collections::HashMap;
use std::future::Future;
use std::sync::Arc;

use async_lock::Mutex;
use bytes::Bytes;
use petrel::identity::{
    DnsResolver, IdentityOptions, IdentityResolver, InMemoryIdentityCache, ServiceKind,
};
use petrel::net::{HttpTransport, SendOptions, SharedTransport, TransportError};
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use petrel_core::{Did, Nsid, RecordKey};
use petrel_crypto::PublicKey;
use petrel_lexicon::{
    DefaultLexiconRepoProofVerifier, LEXICON_SCHEMA_COLLECTION, LexValue, LexiconAuthority,
    LexiconDnsResolver, LexiconDoc, LexiconSchemaOptions, ParseOptions,
};
use petrel_repo::{
    CARError, CommitError, LimitError, LimitKind, RecordCodecError, RepositoryError,
};
use url::Url;

use crate::clients::{OAuthRemoteFetchPolicy, OAuthRemoteTransport};
use crate::lexicon::{
    OAuthLexiconDocument, OAuthLexiconResolution, OAuthLexiconResolverFailure,
    OAuthLexiconResolving,
};
use crate::support::{OAuthClock, SystemOAuthClock};

/// Resolved authority metadata from a Lexicon publisher's DID document:
/// the `#atproto_pds` endpoint and `#atproto` repository signing key.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthLexiconAuthority {
    /// The `#atproto_pds` service endpoint.
    pub pds_endpoint: Url,
    /// The `#atproto` repository signing key.
    pub signing_key: PublicKey,
}

/// Errors returned while resolving a Lexicon authority DID document.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum OAuthLexiconAuthorityError {
    /// The DID document could not be fetched or uses an unsupported DID method.
    #[error("authority DID document is unavailable")]
    DocumentUnavailable,
    /// The DID document lacked a valid `#atproto_pds` service or `#atproto` signing key.
    #[error("authority DID document is missing PDS endpoint or #atproto key")]
    DocumentIncomplete,
}

/// Resolves an authority DID string to its PDS endpoint and `#atproto` signing key.
pub trait OAuthLexiconAuthorityResolving: MaybeSend + MaybeSync {
    fn resolve_authority<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<OAuthLexiconAuthority, OAuthLexiconAuthorityError>>;
}

/// [`petrel::net::HttpTransport`] adapter routing outbound identity/DID fetches through
/// an [`OAuthRemoteTransport`] so `did:web` / PLC lookups obey the server's SSRF-pinned policy.
pub struct OAuthRemoteIdentityHttpTransport {
    transport: Arc<dyn OAuthRemoteTransport>,
    policy: OAuthRemoteFetchPolicy,
}

impl std::fmt::Debug for OAuthRemoteIdentityHttpTransport {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("OAuthRemoteIdentityHttpTransport")
            .field("policy", &self.policy)
            .finish_non_exhaustive()
    }
}

impl OAuthRemoteIdentityHttpTransport {
    /// Creates an identity HTTP transport adapter backed by `transport` and `policy`.
    pub fn new(transport: Arc<dyn OAuthRemoteTransport>, policy: OAuthRemoteFetchPolicy) -> Self {
        Self { transport, policy }
    }
}

#[allow(clippy::manual_async_fn)]
impl HttpTransport for OAuthRemoteIdentityHttpTransport {
    fn send(
        &self,
        request: http::Request<Bytes>,
        options: &SendOptions,
    ) -> impl Future<Output = Result<http::Response<Bytes>, TransportError>> + MaybeSend {
        async move {
            if !self.transport.pins_connections() {
                return Err(TransportError::PolicyViolation(
                    "remote transport does not pin outbound connections".into(),
                ));
            }
            let url = Url::parse(&request.uri().to_string())
                .map_err(|err| TransportError::InvalidRequest(err.to_string()))?;
            let mut effective_policy = self.policy.clone();
            if let Some(max_bytes) = options.max_response_bytes
                && let Ok(max_usize) = usize::try_from(max_bytes)
            {
                effective_policy.max_bytes = effective_policy.max_bytes.min(max_usize);
            }
            let resp = self
                .transport
                .fetch(&url, None, &effective_policy)
                .await
                .map_err(|err| TransportError::Connect(err.to_string()))?;
            if resp.status != 200 {
                return Err(TransportError::Connect(format!(
                    "expected HTTP 200 from {url}, got {}",
                    resp.status
                )));
            }
            if resp.body.len() > effective_policy.max_bytes {
                return Err(TransportError::ResponseTooLarge {
                    limit: effective_policy.max_bytes as u64,
                });
            }
            http::Response::builder()
                .status(http::StatusCode::OK)
                .body(Bytes::from(resp.body))
                .map_err(|err| TransportError::InvalidRequest(err.to_string()))
        }
    }
}

/// Authority resolver backed by [`petrel::identity::IdentityResolver`] (always bypasses
/// the identity cache so authority caching stays solely under the OAuth 5-minute TTL).
pub struct IdentityOAuthLexiconAuthorityResolver<D> {
    identity: IdentityResolver<D, InMemoryIdentityCache>,
}

impl<D> std::fmt::Debug for IdentityOAuthLexiconAuthorityResolver<D> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("IdentityOAuthLexiconAuthorityResolver")
            .finish_non_exhaustive()
    }
}

impl<D: DnsResolver + MaybeSend + MaybeSync + 'static> IdentityOAuthLexiconAuthorityResolver<D> {
    /// Creates an authority resolver routing DID lookups through `transport` and `dns`.
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    pub fn new(
        transport: Arc<dyn OAuthRemoteTransport>,
        policy: OAuthRemoteFetchPolicy,
        dns: D,
    ) -> Self {
        let http_transport: SharedTransport =
            Arc::new(OAuthRemoteIdentityHttpTransport::new(transport, policy));
        let identity = IdentityResolver::new(http_transport, dns, IdentityOptions::default());
        Self { identity }
    }
}

impl<D: DnsResolver + MaybeSend + MaybeSync + 'static> OAuthLexiconAuthorityResolving
    for IdentityOAuthLexiconAuthorityResolver<D>
{
    fn resolve_authority<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<OAuthLexiconAuthority, OAuthLexiconAuthorityError>> {
        Box::pin(async move {
            let parsed =
                Did::parse(did).map_err(|_| OAuthLexiconAuthorityError::DocumentUnavailable)?;
            let doc = self
                .identity
                .refresh_did_document(&parsed)
                .await
                .map_err(|_| OAuthLexiconAuthorityError::DocumentUnavailable)?;
            let pds_endpoint = doc
                .validated_service_endpoint(ServiceKind::Pds)
                .map_err(|_| OAuthLexiconAuthorityError::DocumentIncomplete)?
                .ok_or(OAuthLexiconAuthorityError::DocumentIncomplete)?;
            let signing_key_raw = doc
                .signing_key()
                .map_err(|_| OAuthLexiconAuthorityError::DocumentIncomplete)?;
            let signing_key = DefaultLexiconRepoProofVerifier::crypto_public_key(&signing_key_raw)
                .map_err(|_| OAuthLexiconAuthorityError::DocumentIncomplete)?;
            Ok(OAuthLexiconAuthority {
                pds_endpoint,
                signing_key,
            })
        })
    }
}

/// Configuration error raised when [`AuthenticatedOAuthLexiconResolver`] is built with
/// bounds exceeding the OAuth server's CPU/memory safety budget.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum OAuthLexiconResolverConfigurationError {
    /// Fetch policy accepts responses larger than [`AuthenticatedOAuthLexiconResolver::MAXIMUM_CAR_BYTES`].
    #[error(
        "fetch policy maximum_bytes ({maximum_body_bytes}) exceeds MAXIMUM_CAR_BYTES ({})",
        AuthenticatedOAuthLexiconResolver::MAXIMUM_CAR_BYTES
    )]
    FetchPolicyTooPermissive { maximum_body_bytes: usize },
}

/// Exact step-level failure produced by [`AuthenticatedOAuthLexiconResolver::perform_resolution`].
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, thiserror::Error)]
pub enum AuthenticatedLexiconResolutionFailure {
    #[error("invalid NSID")]
    InvalidNsid,
    #[error("DNS lookup unavailable")]
    DnsUnavailable,
    #[error("no authority DID found in _lexicon TXT records")]
    NoAuthorityDidInTxt,
    #[error("multiple did= lines found in _lexicon TXT records")]
    MultipleAuthorityDidsInTxt,
    #[error("invalid DID in _lexicon TXT record")]
    InvalidAuthorityDidInTxt,
    #[error("authority DID document unavailable")]
    AuthorityDocumentUnavailable,
    #[error("authority DID document incomplete")]
    AuthorityDocumentIncomplete,
    #[error("com.atproto.sync.getRecord fetch failed")]
    RecordFetchFailed,
    #[error("CAR header / root count invalid")]
    CarRootCountInvalid,
    #[error("commit block decoding failed")]
    CommitDecodeFailed,
    #[error("commit DID mismatch")]
    CommitDidMismatch,
    #[error("commit signature invalid")]
    CommitSignatureInvalid,
    #[error("record not proven in signed MST")]
    RecordNotInProof,
    #[error("record $type mismatch")]
    RecordTypeMismatch,
    #[error("lexicon schema document invalid")]
    DocumentSchemaInvalid,
    #[error("lexicon document id does not match NSID")]
    DocumentIdMismatch,
}

impl From<AuthenticatedLexiconResolutionFailure> for OAuthLexiconResolverFailure {
    fn from(err: AuthenticatedLexiconResolutionFailure) -> Self {
        match err {
            AuthenticatedLexiconResolutionFailure::InvalidNsid => {
                Self::InvalidNsid(err.to_string())
            }
            AuthenticatedLexiconResolutionFailure::DnsUnavailable
            | AuthenticatedLexiconResolutionFailure::AuthorityDocumentUnavailable
            | AuthenticatedLexiconResolutionFailure::RecordFetchFailed => {
                Self::Unavailable(err.to_string())
            }
            AuthenticatedLexiconResolutionFailure::NoAuthorityDidInTxt
            | AuthenticatedLexiconResolutionFailure::MultipleAuthorityDidsInTxt
            | AuthenticatedLexiconResolutionFailure::InvalidAuthorityDidInTxt
            | AuthenticatedLexiconResolutionFailure::AuthorityDocumentIncomplete
            | AuthenticatedLexiconResolutionFailure::CarRootCountInvalid
            | AuthenticatedLexiconResolutionFailure::CommitDecodeFailed
            | AuthenticatedLexiconResolutionFailure::CommitDidMismatch
            | AuthenticatedLexiconResolutionFailure::CommitSignatureInvalid
            | AuthenticatedLexiconResolutionFailure::RecordNotInProof
            | AuthenticatedLexiconResolutionFailure::RecordTypeMismatch
            | AuthenticatedLexiconResolutionFailure::DocumentIdMismatch => {
                Self::VerificationFailed(err.to_string())
            }
            AuthenticatedLexiconResolutionFailure::DocumentSchemaInvalid => {
                Self::Malformed(err.to_string())
            }
        }
    }
}

#[derive(Clone)]
struct CachedAuthority {
    did: Did,
    authority: OAuthLexiconAuthority,
    stored_at_secs: i64,
}

struct AuthorityCache {
    entries: HashMap<String, CachedAuthority>,
}

impl AuthorityCache {
    fn new() -> Self {
        Self {
            entries: HashMap::new(),
        }
    }

    fn get(&mut self, domain: &str, now_secs: i64) -> Option<CachedAuthority> {
        let entry = self.entries.get(domain)?.clone();
        let age = now_secs - entry.stored_at_secs;
        if !(0..AuthenticatedOAuthLexiconResolver::AUTHORITY_CACHE_TTL_SECS).contains(&age) {
            self.entries.remove(domain);
            return None;
        }
        Some(entry)
    }

    fn insert(
        &mut self,
        domain: String,
        did: Did,
        authority: OAuthLexiconAuthority,
        now_secs: i64,
    ) {
        if !self.entries.contains_key(&domain)
            && self.entries.len() >= AuthenticatedOAuthLexiconResolver::AUTHORITY_CACHE_CAPACITY
            && let Some(oldest_key) = self
                .entries
                .iter()
                .min_by_key(|(_, v)| v.stored_at_secs)
                .map(|(k, _)| k.clone())
        {
            self.entries.remove(&oldest_key);
        }
        self.entries.insert(
            domain,
            CachedAuthority {
                did,
                authority,
                stored_at_secs: now_secs,
            },
        );
    }
}

/// Authenticated [`OAuthLexiconResolving`] performing all 15 steps of AT Protocol
/// Lexicon resolution: `_lexicon` DNS TXT -> DID document -> SSRF-pinned `com.atproto.sync.getRecord`
/// -> cryptographic commit + MST proof verification (`petrel-repo` + `petrel-crypto`) ->
/// strict Lexicon document validation (`petrel-lexicon`).
pub struct AuthenticatedOAuthLexiconResolver {
    transport: Arc<dyn OAuthRemoteTransport>,
    policy: OAuthRemoteFetchPolicy,
    dns: Arc<dyn LexiconDnsResolver>,
    authorities: Arc<dyn OAuthLexiconAuthorityResolving>,
    clock: Arc<dyn OAuthClock>,
    authority_cache: Mutex<AuthorityCache>,
    proof_verifier: DefaultLexiconRepoProofVerifier,
}

impl std::fmt::Debug for AuthenticatedOAuthLexiconResolver {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("AuthenticatedOAuthLexiconResolver")
            .field("policy", &self.policy)
            .finish_non_exhaustive()
    }
}

impl AuthenticatedOAuthLexiconResolver {
    /// Maximum proof CAR archive size admitted (`256 KiB`).
    pub const MAXIMUM_CAR_BYTES: usize = 256 * 1024;
    /// TTL for cached DID authority records (`5 minutes`).
    pub const AUTHORITY_CACHE_TTL_SECS: i64 = 300;
    /// Maximum cached authority domains.
    pub const AUTHORITY_CACHE_CAPACITY: usize = 256;
    /// Maximum TXT answers inspected for one `_lexicon` domain.
    pub const MAXIMUM_TXT_RECORDS: usize = 128;

    /// Creates a resolver with explicit collaborators.
    pub fn new(
        transport: Arc<dyn OAuthRemoteTransport>,
        policy: OAuthRemoteFetchPolicy,
        dns: Arc<dyn LexiconDnsResolver>,
        authorities: Arc<dyn OAuthLexiconAuthorityResolving>,
        clock: Arc<dyn OAuthClock>,
    ) -> Result<Self, OAuthLexiconResolverConfigurationError> {
        if policy.max_bytes > Self::MAXIMUM_CAR_BYTES {
            return Err(
                OAuthLexiconResolverConfigurationError::FetchPolicyTooPermissive {
                    maximum_body_bytes: policy.max_bytes,
                },
            );
        }
        Ok(Self {
            transport,
            policy,
            dns,
            authorities,
            clock,
            authority_cache: Mutex::new(AuthorityCache::new()),
            proof_verifier: DefaultLexiconRepoProofVerifier::new()
                .with_max_car_bytes(Self::MAXIMUM_CAR_BYTES),
        })
    }

    /// Creates a resolver whose default DID authority lookups route through the same
    /// SSRF-pinned `transport` and `dns` resolver.
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    pub fn with_identity_authorities<D>(
        transport: Arc<dyn OAuthRemoteTransport>,
        policy: OAuthRemoteFetchPolicy,
        dns: Arc<D>,
        clock: Option<Arc<dyn OAuthClock>>,
    ) -> Result<Self, OAuthLexiconResolverConfigurationError>
    where
        D: DnsResolver + MaybeSend + MaybeSync + 'static,
    {
        struct BorrowedDns<D>(Arc<D>);
        #[allow(clippy::manual_async_fn)]
        impl<D: DnsResolver + MaybeSend + MaybeSync + 'static> DnsResolver for BorrowedDns<D> {
            fn txt(
                &self,
                name: &str,
            ) -> impl Future<Output = Result<Vec<String>, petrel::identity::DnsError>> + MaybeSend
            {
                self.0.txt(name)
            }

            #[cfg(not(target_arch = "wasm32"))]
            fn lookup_ip(
                &self,
                host: &str,
            ) -> impl Future<
                Output = Result<Vec<std::net::IpAddr>, petrel::identity::DnsError>,
            > + MaybeSend {
                self.0.lookup_ip(host)
            }
        }

        let authorities: Arc<dyn OAuthLexiconAuthorityResolving> =
            Arc::new(IdentityOAuthLexiconAuthorityResolver::new(
                transport.clone(),
                policy.clone(),
                BorrowedDns(dns.clone()),
            ));
        let lexicon_dns: Arc<dyn LexiconDnsResolver> =
            Arc::new(petrel_lexicon::IdentityLexiconDnsResolver::new(dns));
        Self::new(
            transport,
            policy,
            lexicon_dns,
            authorities,
            clock.unwrap_or_else(|| Arc::new(SystemOAuthClock)),
        )
    }

    /// Executes all 15 steps, returning exact step failure details for diagnostics & tests.
    pub async fn perform_resolution(
        &self,
        nsid: &str,
    ) -> Result<OAuthLexiconResolution, AuthenticatedLexiconResolutionFailure> {
        let parsed_nsid =
            Nsid::parse(nsid).map_err(|_| AuthenticatedLexiconResolutionFailure::InvalidNsid)?;
        let txt_domain = LexiconAuthority::txt_domain(&parsed_nsid);

        let (did, authority) = self.resolve_authority(&txt_domain).await?;
        let collection = Nsid::parse(LEXICON_SCHEMA_COLLECTION)
            .map_err(|_| AuthenticatedLexiconResolutionFailure::InvalidNsid)?;
        let rkey = RecordKey::parse(parsed_nsid.as_str())
            .map_err(|_| AuthenticatedLexiconResolutionFailure::InvalidNsid)?;

        let car_bytes = self
            .fetch_proof_car(&authority.pds_endpoint, &did, &parsed_nsid)
            .await?;

        let proven = self
            .proof_verifier
            .verify_with_repository(&car_bytes, &did, &collection, &rkey, &authority.signing_key)
            .map_err(|err| classify_repository_error(&err))?;

        let Some(record) = proven.record else {
            return Err(AuthenticatedLexiconResolutionFailure::RecordNotInProof);
        };

        let lex_val = LexValue::from_record_dag_cbor(&record.bytes, ParseOptions::standard())
            .map_err(|_| AuthenticatedLexiconResolutionFailure::RecordTypeMismatch)?;
        let json_bytes = lex_val.to_json_bytes();

        let doc = LexiconDoc::from_json_bytes(&json_bytes)
            .map_err(|_| AuthenticatedLexiconResolutionFailure::DocumentSchemaInvalid)?;
        doc.validate(LexiconSchemaOptions::strict())
            .map_err(|_| AuthenticatedLexiconResolutionFailure::DocumentSchemaInvalid)?;

        if doc.id != parsed_nsid.as_str() {
            return Err(AuthenticatedLexiconResolutionFailure::DocumentIdMismatch);
        }

        let oauth_doc = OAuthLexiconDocument::from_json(
            parsed_nsid.as_str(),
            Some(record.cid.to_string()),
            Some(did.to_string()),
            json_bytes,
        )
        .map_err(|_| AuthenticatedLexiconResolutionFailure::DocumentSchemaInvalid)?;

        if oauth_doc.permission_set.is_some() {
            Ok(OAuthLexiconResolution::Resolved(Box::new(oauth_doc)))
        } else {
            Ok(OAuthLexiconResolution::NotPermissionSet)
        }
    }

    async fn resolve_authority(
        &self,
        txt_domain: &str,
    ) -> Result<(Did, OAuthLexiconAuthority), AuthenticatedLexiconResolutionFailure> {
        let now = self.clock.now_secs();
        if let Some(cached) = self.authority_cache.lock().await.get(txt_domain, now) {
            return Ok((cached.did, cached.authority));
        }

        let did = self.resolve_authority_did(txt_domain).await?;
        let authority = self
            .authorities
            .resolve_authority(did.as_str())
            .await
            .map_err(|err| match err {
                OAuthLexiconAuthorityError::DocumentUnavailable => {
                    AuthenticatedLexiconResolutionFailure::AuthorityDocumentUnavailable
                }
                OAuthLexiconAuthorityError::DocumentIncomplete => {
                    AuthenticatedLexiconResolutionFailure::AuthorityDocumentIncomplete
                }
            })?;

        self.authority_cache.lock().await.insert(
            txt_domain.to_owned(),
            did.clone(),
            authority.clone(),
            self.clock.now_secs(),
        );
        Ok((did, authority))
    }

    async fn resolve_authority_did(
        &self,
        txt_domain: &str,
    ) -> Result<Did, AuthenticatedLexiconResolutionFailure> {
        let records = self
            .dns
            .lookup_txt(txt_domain)
            .await
            .map_err(|_| AuthenticatedLexiconResolutionFailure::DnsUnavailable)?;
        if records.len() > Self::MAXIMUM_TXT_RECORDS {
            return Err(AuthenticatedLexiconResolutionFailure::DnsUnavailable);
        }

        // Exactly one `did=` TXT line (two identical lines are still two, matching `lex-resolver.ts`).
        let mut did_lines = records.iter().filter(|r| r.starts_with("did="));
        let Some(first) = did_lines.next() else {
            return Err(AuthenticatedLexiconResolutionFailure::NoAuthorityDidInTxt);
        };
        if did_lines.next().is_some() {
            return Err(AuthenticatedLexiconResolutionFailure::MultipleAuthorityDidsInTxt);
        }
        let raw_did = first.strip_prefix("did=").unwrap_or_default();
        Did::parse(raw_did)
            .map_err(|_| AuthenticatedLexiconResolutionFailure::InvalidAuthorityDidInTxt)
    }

    async fn fetch_proof_car(
        &self,
        pds: &Url,
        did: &Did,
        nsid: &Nsid,
    ) -> Result<Vec<u8>, AuthenticatedLexiconResolutionFailure> {
        if !self.transport.pins_connections() {
            return Err(AuthenticatedLexiconResolutionFailure::RecordFetchFailed);
        }
        let mut endpoint = pds.clone();
        let base_path = endpoint.path().trim_end_matches('/').to_owned();
        endpoint.set_path(&format!("{base_path}/xrpc/com.atproto.sync.getRecord"));
        endpoint.set_fragment(None);
        endpoint
            .query_pairs_mut()
            .append_pair("did", did.as_str())
            .append_pair("collection", LEXICON_SCHEMA_COLLECTION)
            .append_pair("rkey", nsid.as_str());

        let resp = self
            .transport
            .fetch(&endpoint, None, &self.policy)
            .await
            .map_err(|_| AuthenticatedLexiconResolutionFailure::RecordFetchFailed)?;
        let cap = self.policy.max_bytes.min(Self::MAXIMUM_CAR_BYTES);
        if resp.status != 200 || resp.body.is_empty() || resp.body.len() > cap {
            return Err(AuthenticatedLexiconResolutionFailure::RecordFetchFailed);
        }
        Ok(resp.body)
    }
}

impl OAuthLexiconResolving for AuthenticatedOAuthLexiconResolver {
    fn resolve(
        &self,
        nsid: &str,
    ) -> BoxFuture<'_, Result<OAuthLexiconResolution, OAuthLexiconResolverFailure>> {
        let target = nsid.to_owned();
        Box::pin(async move {
            self.perform_resolution(&target)
                .await
                .map_err(OAuthLexiconResolverFailure::from)
        })
    }
}

fn classify_repository_error(err: &RepositoryError) -> AuthenticatedLexiconResolutionFailure {
    match err {
        RepositoryError::Car(
            CARError::Limit(LimitError::Exceeded {
                kind: LimitKind::CarRootCount,
                ..
            })
            | CARError::MultipleRoots { .. }
            | CARError::TooManyRoots { .. }
            | CARError::MissingRoots
            | CARError::InvalidHeader(_)
            | CARError::UnsupportedVersion(_),
        ) => AuthenticatedLexiconResolutionFailure::CarRootCountInvalid,
        RepositoryError::Commit(CommitError::DidMismatch { .. }) => {
            AuthenticatedLexiconResolutionFailure::CommitDidMismatch
        }
        RepositoryError::Commit(
            CommitError::InvalidSignature
            | CommitError::HighSSignature
            | CommitError::InvalidSignatureEncoding(_)
            | CommitError::InvalidPublicKey(_),
        ) => AuthenticatedLexiconResolutionFailure::CommitSignatureInvalid,
        RepositoryError::Mst(_)
        | RepositoryError::MissingBlock(_)
        | RepositoryError::Car(_)
        | RepositoryError::ProofFailure(_) => {
            AuthenticatedLexiconResolutionFailure::RecordNotInProof
        }
        RepositoryError::Record(
            RecordCodecError::TypeCollectionMismatch { .. }
            | RecordCodecError::InvalidTypeField(_)
            | RecordCodecError::InvalidDagCbor(_)
            | RecordCodecError::TopLevelNotMap,
        ) => AuthenticatedLexiconResolutionFailure::RecordTypeMismatch,
        _ => AuthenticatedLexiconResolutionFailure::CommitDecodeFailed,
    }
}
