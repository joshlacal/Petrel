//! Remote AT Protocol Lexicon NSID resolution (`_lexicon.<authority>` DNS TXT -> DID -> PDS).

use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::Duration;

use async_lock::RwLock;
use bytes::Bytes;
use petrel::identity::SigningKey;
use petrel::net::{SendOptions, SharedTransport};
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync, SystemTime};
use petrel_core::{Cid, Did, Nsid, RecordKey, Value};
use thiserror::Error;
use url::Url;

use crate::doc::LexiconDoc;
use crate::proof::DefaultLexiconRepoProofVerifier;
use crate::schema::{LexiconSchemaError, LexiconSchemaOptions};
use crate::value::{LexValue, ParseOptions};

/// Collection NSID storing published Lexicon schema records in ATProto repositories.
pub const LEXICON_SCHEMA_COLLECTION: &str = "com.atproto.lexicon.schema";

/// Errors produced during remote Lexicon NSID resolution.
#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum LexiconResolutionError {
    /// Target string is not a valid ATProto NSID.
    #[error("invalid NSID {nsid:?}: {message}")]
    InvalidNsid {
        /// Offending NSID string.
        nsid: String,
        /// Syntax error message.
        message: String,
    },

    /// No valid `did=` TXT record found at `_lexicon.<authority>`.
    #[error("no lexicon authority DID found for {domain}")]
    AuthorityNotFound {
        /// DNS domain queried.
        domain: String,
    },

    /// Multiple conflicting `did=` TXT records found at `_lexicon.<authority>`.
    #[error("ambiguous lexicon authority DIDs at {domain}: {dids:?}")]
    AmbiguousAuthority {
        /// DNS domain queried.
        domain: String,
        /// Conflicting DIDs returned.
        dids: Vec<String>,
    },

    /// DNS lookup failed.
    #[error("DNS lookup failed for {domain}: {message}")]
    DnsFailed {
        /// DNS domain queried.
        domain: String,
        /// Underlying DNS error description.
        message: String,
    },

    /// DID document or PDS service resolution failed.
    #[error("identity resolution failed for {did}: {message}")]
    IdentityFailed {
        /// Target DID.
        did: String,
        /// Underlying error description.
        message: String,
    },

    /// HTTP transport or status error when fetching a schema record.
    #[error("HTTP record fetch failed: {message}")]
    FetchFailed {
        /// HTTP status code if a response was received.
        status: Option<u16>,
        /// Error description.
        message: String,
    },

    /// Fetched schema record had invalid data-model encoding, JSON, or `$type`/`id` mismatch.
    #[error("invalid lexicon record payload: {message}")]
    InvalidRecord {
        /// Description of the malformed record.
        message: String,
    },

    /// Cryptographic repository Merkle proof verification failed.
    #[error("repository proof verification failed: {message}")]
    ProofVerificationFailed {
        /// Description of the verification error.
        message: String,
    },

    /// Resolved schema failed static [`LexiconDoc::validate`] checks.
    #[error(transparent)]
    InvalidSchema(#[from] LexiconSchemaError),
}

/// Authority helper mapping an NSID to its `_lexicon.<reversed-authority>` DNS TXT name
/// and parsing `did=` TXT records.
#[derive(Debug, Clone, Copy, Default)]
pub struct LexiconAuthority;

impl LexiconAuthority {
    /// Compute the `_lexicon.<reversed-authority>` DNS domain for `nsid`.
    pub fn txt_domain(nsid: &Nsid) -> String {
        let mut labels: Vec<&str> = nsid.authority().split('.').collect();
        labels.reverse();
        format!("_lexicon.{}", labels.join("."))
    }

    /// Parse `did=` TXT records returned for `_lexicon.<authority>`, enforcing uniqueness.
    pub fn parse_txt_dids(domain: &str, records: &[String]) -> Result<Did, LexiconResolutionError> {
        let mut found: Option<Did> = None;
        let mut conflicts: Vec<String> = Vec::new();

        for raw in records {
            let trimmed = raw.trim();
            let Some(candidate) = trimmed.strip_prefix("did=") else {
                continue;
            };
            let candidate = candidate.trim();
            let Ok(did) = Did::parse(candidate) else {
                continue;
            };
            match &found {
                None => found = Some(did),
                Some(existing) if existing == &did => {}
                Some(existing) => {
                    if conflicts.is_empty() {
                        conflicts.push(existing.to_string());
                    }
                    conflicts.push(did.to_string());
                }
            }
        }

        if !conflicts.is_empty() {
            return Err(LexiconResolutionError::AmbiguousAuthority {
                domain: domain.to_owned(),
                dids: conflicts,
            });
        }

        found.ok_or_else(|| LexiconResolutionError::AuthorityNotFound {
            domain: domain.to_owned(),
        })
    }
}

/// Resolved DID identity endpoints needed to fetch (and optionally verify) a Lexicon record.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ResolvedLexiconIdentity {
    /// Atproto PDS HTTP base URL from the DID document.
    pub pds_endpoint: Url,
    /// Optional ATProto repository signing key from the DID document (`#atproto`).
    pub signing_key: Option<SigningKey>,
}

/// Async DNS TXT resolver interface used by [`DefaultLexiconResolver`].
pub trait LexiconDnsResolver: MaybeSend + MaybeSync {
    /// Query TXT records for `domain` (for example `_lexicon.feed.bsky.app`).
    fn lookup_txt<'a>(
        &'a self,
        domain: &'a str,
    ) -> BoxFuture<'a, Result<Vec<String>, LexiconResolutionError>>;
}

/// Async DID -> PDS/signing-key resolver interface used by [`DefaultLexiconResolver`].
pub trait LexiconDidResolver: MaybeSend + MaybeSync {
    /// Resolve `did` to its PDS endpoint and optional repository signing key.
    fn resolve_identity<'a>(
        &'a self,
        did: &'a Did,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<ResolvedLexiconIdentity, LexiconResolutionError>>;
}

/// Verified repository record extracted from a signed AT Protocol CAR proof (`com.atproto.sync.getRecord`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedLexiconRecord {
    /// Verified CID of the record leaf block.
    pub cid: Cid,
    /// Verified DAG-CBOR bytes of the record.
    pub record_cbor: Vec<u8>,
}

/// Seam allowing downstream crates (such as `petrel-server` backed by `petrel-repo`)
/// to verify cryptographic `com.atproto.sync.getRecord` CAR proofs fetched over HTTP.
pub trait LexiconRepoProofVerifier: MaybeSend + MaybeSync {
    /// Verify `car_bytes` from `com.atproto.sync.getRecord` for `did/collection/rkey`
    /// using `signing_key`, returning the verified record CID and DAG-CBOR payload.
    fn verify_record_proof(
        &self,
        car_bytes: &[u8],
        did: &Did,
        collection: &Nsid,
        rkey: &RecordKey,
        signing_key: &SigningKey,
    ) -> Result<VerifiedLexiconRecord, LexiconResolutionError>;
}

/// Abstract fetcher returning a parsed [`LexiconDoc`] from a repository host.
pub trait LexiconRecordFetcher: MaybeSend + MaybeSync {
    /// Fetch the `com.atproto.lexicon.schema` record at `(did, rkey = nsid)` from `pds`.
    fn fetch_lexicon_record<'a>(
        &'a self,
        pds: &'a Url,
        did: &'a Did,
        nsid: &'a Nsid,
        signing_key: Option<&'a SigningKey>,
    ) -> BoxFuture<'a, Result<LexiconDoc, LexiconResolutionError>>;
}

/// High-level Lexicon resolver interface implemented by [`DefaultLexiconResolver`]
/// and downstream authenticated resolvers (such as `AuthenticatedOAuthLexiconResolver`).
pub trait LexiconResolver: MaybeSend + MaybeSync {
    /// Resolve `nsid` to a validated [`LexiconDoc`].
    fn resolve<'a>(
        &'a self,
        nsid: &'a str,
    ) -> BoxFuture<'a, Result<LexiconDoc, LexiconResolutionError>>;

    /// Resolve `nsid` with explicit cache-bypass and schema-validation options.
    fn resolve_with_options<'a>(
        &'a self,
        nsid: &'a str,
        force_refresh: bool,
        schema_options: LexiconSchemaOptions,
    ) -> BoxFuture<'a, Result<LexiconDoc, LexiconResolutionError>>;
}

/// HTTP record fetcher built over [`petrel::net::SharedTransport`].
///
/// By default ([`Self::new`]), fetches signed CAR proofs from `com.atproto.sync.getRecord`
/// and cryptographically verifies commit signatures + MST inclusion proofs against the DID's
/// `#atproto` signing key via [`DefaultLexiconRepoProofVerifier`]. Use [`Self::unverified`] only
/// when explicitly opting into unsigned `com.atproto.repo.getRecord` JSON fetches.
pub struct LexiconHttpRecordFetcher {
    transport: SharedTransport,
    verifier: Option<Arc<dyn LexiconRepoProofVerifier>>,
    timeout: Duration,
}

impl std::fmt::Debug for LexiconHttpRecordFetcher {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("LexiconHttpRecordFetcher")
            .field("has_verifier", &self.verifier.is_some())
            .field("timeout", &self.timeout)
            .finish_non_exhaustive()
    }
}

impl LexiconHttpRecordFetcher {
    /// Construct the default proof-verifying HTTP fetcher using `com.atproto.sync.getRecord`
    /// and [`DefaultLexiconRepoProofVerifier`].
    pub fn new(transport: SharedTransport) -> Self {
        Self::with_proof_verifier(
            transport,
            Arc::new(DefaultLexiconRepoProofVerifier::default()),
        )
    }

    /// Construct an explicitly **unverified** HTTP fetcher using `com.atproto.repo.getRecord`
    /// (trusts the PDS over TLS without commit signature or MST proof verification).
    pub fn unverified(transport: SharedTransport) -> Self {
        Self {
            transport,
            verifier: None,
            timeout: Duration::from_secs(10),
        }
    }

    /// Construct a proof-verifying HTTP fetcher using `com.atproto.sync.getRecord`
    /// and the supplied [`LexiconRepoProofVerifier`].
    pub fn with_proof_verifier(
        transport: SharedTransport,
        verifier: Arc<dyn LexiconRepoProofVerifier>,
    ) -> Self {
        Self {
            transport,
            verifier: Some(verifier),
            timeout: Duration::from_secs(10),
        }
    }

    /// Override the per-request HTTP timeout (default `10s`).
    #[must_use]
    pub const fn with_timeout(mut self, timeout: Duration) -> Self {
        self.timeout = timeout;
        self
    }

    async fn fetch_unverified(
        &self,
        pds: &Url,
        did: &Did,
        nsid: &Nsid,
    ) -> Result<LexiconDoc, LexiconResolutionError> {
        let mut endpoint = pds.join("xrpc/com.atproto.repo.getRecord").map_err(|err| {
            LexiconResolutionError::FetchFailed {
                status: None,
                message: format!("invalid PDS URL {pds}: {err}"),
            }
        })?;
        endpoint
            .query_pairs_mut()
            .append_pair("repo", did.as_str())
            .append_pair("collection", LEXICON_SCHEMA_COLLECTION)
            .append_pair("rkey", nsid.as_str());

        let req = http::Request::builder()
            .method(http::Method::GET)
            .uri(endpoint.as_str())
            .header(http::header::ACCEPT, "application/json")
            .body(Bytes::new())
            .map_err(|err| LexiconResolutionError::FetchFailed {
                status: None,
                message: err.to_string(),
            })?;

        let mut opts = SendOptions::default();
        opts.timeout = Some(self.timeout);
        opts.max_response_bytes = Some(1_048_576);
        opts.anonymous = true;
        let resp = self.transport.send_dyn(req, &opts).await.map_err(|err| {
            LexiconResolutionError::FetchFailed {
                status: None,
                message: err.to_string(),
            }
        })?;

        let status = resp.status();
        if !status.is_success() {
            return Err(LexiconResolutionError::FetchFailed {
                status: Some(status.as_u16()),
                message: format!("PDS returned HTTP {status} for {endpoint}"),
            });
        }

        let envelope =
            LexValue::from_json_bytes(resp.body(), ParseOptions::standard()).map_err(|err| {
                LexiconResolutionError::InvalidRecord {
                    message: err.to_string(),
                }
            })?;
        let Value::Object(map) = envelope.into_value() else {
            return Err(LexiconResolutionError::InvalidRecord {
                message: "getRecord response is not a JSON object".to_owned(),
            });
        };
        let Some(record_val) = map.get("value") else {
            return Err(LexiconResolutionError::InvalidRecord {
                message: "getRecord response missing 'value' field".to_owned(),
            });
        };
        lexicon_doc_from_record_value(record_val, nsid)
    }

    async fn fetch_verified(
        &self,
        verifier: &dyn LexiconRepoProofVerifier,
        pds: &Url,
        did: &Did,
        nsid: &Nsid,
        signing_key: &SigningKey,
    ) -> Result<LexiconDoc, LexiconResolutionError> {
        let mut endpoint = pds.join("xrpc/com.atproto.sync.getRecord").map_err(|err| {
            LexiconResolutionError::FetchFailed {
                status: None,
                message: format!("invalid PDS URL {pds}: {err}"),
            }
        })?;
        endpoint
            .query_pairs_mut()
            .append_pair("did", did.as_str())
            .append_pair("collection", LEXICON_SCHEMA_COLLECTION)
            .append_pair("rkey", nsid.as_str());

        let req = http::Request::builder()
            .method(http::Method::GET)
            .uri(endpoint.as_str())
            .header(http::header::ACCEPT, "application/vnd.ipld.car")
            .body(Bytes::new())
            .map_err(|err| LexiconResolutionError::FetchFailed {
                status: None,
                message: err.to_string(),
            })?;

        let mut opts = SendOptions::default();
        opts.timeout = Some(self.timeout);
        opts.max_response_bytes = Some(1_048_576);
        opts.anonymous = true;
        let resp = self.transport.send_dyn(req, &opts).await.map_err(|err| {
            LexiconResolutionError::FetchFailed {
                status: None,
                message: err.to_string(),
            }
        })?;

        let status = resp.status();
        if !status.is_success() {
            return Err(LexiconResolutionError::FetchFailed {
                status: Some(status.as_u16()),
                message: format!("PDS returned HTTP {status} for {endpoint}"),
            });
        }

        let collection = Nsid::parse(LEXICON_SCHEMA_COLLECTION).map_err(|err| {
            LexiconResolutionError::InvalidRecord {
                message: err.to_string(),
            }
        })?;
        let rkey =
            RecordKey::parse(nsid.as_str()).map_err(|err| LexiconResolutionError::InvalidNsid {
                nsid: nsid.to_string(),
                message: err.to_string(),
            })?;

        let proof_record =
            verifier.verify_record_proof(resp.body(), did, &collection, &rkey, signing_key)?;
        let value =
            LexValue::from_record_dag_cbor(&proof_record.record_cbor, ParseOptions::standard())
                .map_err(|err| LexiconResolutionError::InvalidRecord {
                    message: err.to_string(),
                })?;
        lexicon_doc_from_record_value(value.inner(), nsid)
    }
}

impl LexiconRecordFetcher for LexiconHttpRecordFetcher {
    fn fetch_lexicon_record<'a>(
        &'a self,
        pds: &'a Url,
        did: &'a Did,
        nsid: &'a Nsid,
        signing_key: Option<&'a SigningKey>,
    ) -> BoxFuture<'a, Result<LexiconDoc, LexiconResolutionError>> {
        Box::pin(async move {
            match (&self.verifier, signing_key) {
                (Some(verifier), Some(key)) => {
                    self.fetch_verified(verifier.as_ref(), pds, did, nsid, key)
                        .await
                }
                (Some(_), None) => Err(LexiconResolutionError::ProofVerificationFailed {
                    message: format!("DID {did} document lacks an #atproto signing key"),
                }),
                (None, _) => self.fetch_unverified(pds, did, nsid).await,
            }
        })
    }
}

/// Convert a decoded `com.atproto.lexicon.schema` record [`Value`] into a [`LexiconDoc`],
/// verifying `$type` and `id` parity.
pub fn lexicon_doc_from_record_value(
    value: &Value,
    expected_nsid: &Nsid,
) -> Result<LexiconDoc, LexiconResolutionError> {
    let Value::Object(map) = value else {
        return Err(LexiconResolutionError::InvalidRecord {
            message: format!(
                "lexicon schema record must be an object, got {}",
                value.kind()
            ),
        });
    };
    let Some(record_type) = map.get("$type") else {
        return Err(LexiconResolutionError::InvalidRecord {
            message: format!(
                "lexicon record missing required '$type': {LEXICON_SCHEMA_COLLECTION:?}"
            ),
        });
    };
    let Some(type_str) = record_type.as_str() else {
        return Err(LexiconResolutionError::InvalidRecord {
            message: "lexicon record '$type' must be a string".to_owned(),
        });
    };
    if type_str != LEXICON_SCHEMA_COLLECTION {
        return Err(LexiconResolutionError::InvalidRecord {
            message: format!("expected $type == {LEXICON_SCHEMA_COLLECTION:?}, got {type_str:?}"),
        });
    }

    let json_bytes = LexValue::from_value(value.clone()).to_json_bytes();
    let doc = LexiconDoc::from_json_bytes(&json_bytes).map_err(|err| {
        LexiconResolutionError::InvalidRecord {
            message: err.to_string(),
        }
    })?;
    if doc.id != expected_nsid.as_str() {
        return Err(LexiconResolutionError::InvalidRecord {
            message: format!(
                "lexicon record id {:?} does not match requested NSID {:?}",
                doc.id,
                expected_nsid.as_str()
            ),
        });
    }
    Ok(doc)
}

#[derive(Debug, Clone)]
struct CachedLexicon {
    doc: LexiconDoc,
    expires_at: SystemTime,
}

/// Thread-safe, TTL-bounded in-memory cache of resolved [`LexiconDoc`] schemas.
#[derive(Debug)]
pub struct LexiconResolutionCache {
    entries: RwLock<BTreeMap<String, CachedLexicon>>,
    ttl: Duration,
    max_entries: usize,
}

impl LexiconResolutionCache {
    /// Create a cache with the given entry TTL and maximum capacity.
    pub fn new(ttl: Duration, max_entries: usize) -> Self {
        Self {
            entries: RwLock::new(BTreeMap::new()),
            ttl,
            max_entries: max_entries.max(1),
        }
    }

    /// Look up a fresh cached [`LexiconDoc`] for `nsid`.
    pub async fn get(&self, nsid: &str) -> Option<LexiconDoc> {
        let now = SystemTime::now();
        let guard = self.entries.read().await;
        let entry = guard.get(nsid)?;
        if now <= entry.expires_at {
            Some(entry.doc.clone())
        } else {
            None
        }
    }

    /// Insert a resolved [`LexiconDoc`] into the cache, evicting expired or oldest entries when full.
    pub async fn insert(&self, nsid: String, doc: LexiconDoc) {
        let now = SystemTime::now();
        let expires_at = now + self.ttl;
        let mut guard = self.entries.write().await;
        guard.retain(|_, v| now <= v.expires_at);
        if guard.len() >= self.max_entries
            && !guard.contains_key(&nsid)
            && let Some(first_key) = guard.keys().next().cloned()
        {
            guard.remove(&first_key);
        }
        guard.insert(nsid, CachedLexicon { doc, expires_at });
    }

    /// Evict a single NSID from the cache.
    pub async fn invalidate(&self, nsid: &str) {
        self.entries.write().await.remove(nsid);
    }

    /// Clear all cached entries.
    pub async fn clear(&self) {
        self.entries.write().await.clear();
    }
}

impl Default for LexiconResolutionCache {
    fn default() -> Self {
        Self::new(Duration::from_secs(300), 512)
    }
}

/// Default end-to-end AT Protocol Lexicon resolver (`_lexicon.<authority>` TXT -> DID -> PDS).
pub struct DefaultLexiconResolver {
    dns: Arc<dyn LexiconDnsResolver>,
    did_resolver: Arc<dyn LexiconDidResolver>,
    fetcher: Arc<dyn LexiconRecordFetcher>,
    cache: LexiconResolutionCache,
}

impl std::fmt::Debug for DefaultLexiconResolver {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DefaultLexiconResolver")
            .field("cache", &self.cache)
            .finish_non_exhaustive()
    }
}

impl DefaultLexiconResolver {
    /// Construct a new [`DefaultLexiconResolver`] with explicit collaborators and cache settings.
    pub fn new(
        dns: Arc<dyn LexiconDnsResolver>,
        did_resolver: Arc<dyn LexiconDidResolver>,
        fetcher: Arc<dyn LexiconRecordFetcher>,
        cache: LexiconResolutionCache,
    ) -> Self {
        Self {
            dns,
            did_resolver,
            fetcher,
            cache,
        }
    }

    /// Access the underlying resolution cache.
    pub const fn cache(&self) -> &LexiconResolutionCache {
        &self.cache
    }

    /// Resolve the authority DID for `nsid` via `_lexicon.<reversed-authority>` TXT lookup.
    pub async fn resolve_authority(&self, nsid: &Nsid) -> Result<Did, LexiconResolutionError> {
        let domain = LexiconAuthority::txt_domain(nsid);
        let records = self.dns.lookup_txt(&domain).await?;
        LexiconAuthority::parse_txt_dids(&domain, &records)
    }

    /// Resolve `nsid` end-to-end with explicit refresh and schema validation options.
    pub async fn resolve_schema(
        &self,
        nsid: &str,
        force_refresh: bool,
        schema_options: LexiconSchemaOptions,
    ) -> Result<LexiconDoc, LexiconResolutionError> {
        let parsed = Nsid::parse(nsid).map_err(|err| LexiconResolutionError::InvalidNsid {
            nsid: nsid.to_owned(),
            message: err.to_string(),
        })?;

        if !force_refresh && let Some(cached) = self.cache.get(parsed.as_str()).await {
            cached.validate(schema_options)?;
            return Ok(cached);
        }

        let did = self.resolve_authority(&parsed).await?;
        let identity = self
            .did_resolver
            .resolve_identity(&did, force_refresh)
            .await?;

        let doc = match self
            .fetcher
            .fetch_lexicon_record(
                &identity.pds_endpoint,
                &did,
                &parsed,
                identity.signing_key.as_ref(),
            )
            .await
        {
            Ok(doc) => doc,
            Err(err @ LexiconResolutionError::ProofVerificationFailed { .. }) if !force_refresh => {
                let refreshed = self.did_resolver.resolve_identity(&did, true).await?;
                if refreshed == identity {
                    return Err(err);
                }
                self.fetcher
                    .fetch_lexicon_record(
                        &refreshed.pds_endpoint,
                        &did,
                        &parsed,
                        refreshed.signing_key.as_ref(),
                    )
                    .await?
            }
            Err(err) => return Err(err),
        };

        doc.validate(schema_options)?;
        self.cache.insert(parsed.to_string(), doc.clone()).await;
        Ok(doc)
    }
}

impl LexiconResolver for DefaultLexiconResolver {
    fn resolve<'a>(
        &'a self,
        nsid: &'a str,
    ) -> BoxFuture<'a, Result<LexiconDoc, LexiconResolutionError>> {
        self.resolve_with_options(nsid, false, LexiconSchemaOptions::strict())
    }

    fn resolve_with_options<'a>(
        &'a self,
        nsid: &'a str,
        force_refresh: bool,
        schema_options: LexiconSchemaOptions,
    ) -> BoxFuture<'a, Result<LexiconDoc, LexiconResolutionError>> {
        Box::pin(async move {
            self.resolve_schema(nsid, force_refresh, schema_options)
                .await
        })
    }
}
