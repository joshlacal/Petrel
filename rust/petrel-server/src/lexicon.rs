use std::collections::HashMap;
use std::sync::Arc;

use async_lock::Mutex;
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use petrel_oauth_scopes::{
    AtProtoScope, IncludeScope, LexiconPermissionSet, OAuthScopeAdmissionError,
    OAuthScopeAdmissionPolicy, OAuthScopeBudget, OAuthUnknownScopePolicy, ScopeSet,
};
use serde::Deserialize;

use crate::store::{OAuthCachedLexicon, OAuthLexiconCache};
use crate::support::{OAuthClock, StrictJson, SystemOAuthClock};

/// Lifecycle stage at which OAuth scope resolution is evaluated.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum OAuthScopeResolutionStage {
    Admission,
    Authorization,
    TokenResponse,
}

/// Errors produced when admitting, expanding, or budgeting requested OAuth scopes.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum OAuthScopeResolutionError {
    #[error("scope admission failed: {0}")]
    Admission(#[from] OAuthScopeAdmissionError),
    #[error("failed to resolve lexicon permission set {nsid}: {reason}")]
    ResolutionFailed { nsid: String, reason: String },
    #[error("expanded scope invalid: {0}")]
    InvalidExpandedScope(String),
}

impl OAuthScopeResolutionError {
    /// RFC 6749 error code (`"invalid_scope"` or `"invalid_request"` or `"temporarily_unavailable"`).
    pub fn oauth_error_code(&self) -> &'static str {
        match self {
            Self::Admission(err) => err.oauth_error_code(),
            Self::ResolutionFailed { .. } | Self::InvalidExpandedScope(_) => "invalid_scope",
        }
    }
}

/// Human-readable description for a scope or permission-set presented during authorization consent.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthScopeDescription {
    /// Scope string (`include:...`, `repo:...`, etc.).
    pub scope: String,
    /// Optional localized title.
    pub title: Option<String>,
    /// Optional localized detail description.
    pub detail: Option<String>,
    /// Source permission-set NSID if expanded from `include:`.
    pub source_nsid: Option<String>,
}

/// Result of admitting and expanding an authorization scope request.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OAuthExpandedScopeSet {
    /// Admitted tokens as granted to the client (may still retain `include:` or expanded scopes depending on stage).
    pub admitted: ScopeSet,
    /// Fully expanded scopes after resolving `include:` permission sets.
    pub expanded: ScopeSet,
    /// Localized UI descriptions for consent screens.
    pub descriptions: Vec<OAuthScopeDescription>,
}

impl OAuthExpandedScopeSet {
    /// Canonical space-joined scope string for persistence and token responses.
    pub fn wire_scope(&self) -> String {
        self.admitted.scope_string()
    }

    /// Expanded space-joined scope string used when enforcing resource permissions.
    pub fn expanded_wire_scope(&self) -> String {
        self.expanded.scope_string()
    }
}

/// A resolved AT Protocol Lexicon document, optionally carrying a `permission-set` main def.
#[derive(Debug, Clone, PartialEq)]
pub struct OAuthLexiconDocument {
    pub nsid: String,
    pub cid: Option<String>,
    pub source_did: Option<String>,
    pub raw_json: Vec<u8>,
    pub permission_set: Option<LexiconPermissionSet>,
}

#[derive(Deserialize)]
struct LexiconEnvelope {
    id: String,
    defs: LexiconDefsEnvelope,
}

#[derive(Deserialize)]
struct LexiconDefsEnvelope {
    main: Option<LexiconMainProbe>,
}

#[derive(Deserialize)]
struct LexiconMainProbe {
    #[serde(rename = "type")]
    kind: String,
}

impl OAuthLexiconDocument {
    /// Strictly decodes a Lexicon JSON schema document and extracts `defs.main` when `type == "permission-set"`.
    pub fn from_json(
        nsid: &str,
        cid: Option<String>,
        source_did: Option<String>,
        raw_json: Vec<u8>,
    ) -> Result<Self, OAuthLexiconResolverFailure> {
        StrictJson::validate(&raw_json)
            .map_err(|err| OAuthLexiconResolverFailure::Malformed(err.to_string()))?;
        let env: LexiconEnvelope = serde_json::from_slice(&raw_json)
            .map_err(|err| OAuthLexiconResolverFailure::Malformed(err.to_string()))?;
        if env.id != nsid {
            return Err(OAuthLexiconResolverFailure::VerificationFailed(format!(
                "lexicon id {} does not match requested NSID {nsid}",
                env.id
            )));
        }
        let permission_set = match env.defs.main {
            Some(main) if main.kind == "permission-set" => {
                #[derive(Deserialize)]
                struct FullEnv {
                    defs: FullDefs,
                }
                #[derive(Deserialize)]
                struct FullDefs {
                    main: LexiconPermissionSet,
                }
                let full: FullEnv = serde_json::from_slice(&raw_json)
                    .map_err(|err| OAuthLexiconResolverFailure::Malformed(err.to_string()))?;
                Some(full.defs.main)
            }
            _ => None,
        };
        Ok(Self {
            nsid: nsid.to_owned(),
            cid,
            source_did,
            raw_json,
            permission_set,
        })
    }
}

/// Resolution outcome for a single NSID lookup.
#[derive(Debug, Clone, PartialEq)]
pub enum OAuthLexiconResolution {
    Resolved(Box<OAuthLexiconDocument>),
    NotFound,
    NotPermissionSet,
}

/// Errors from lexicon schema lookup / proof verification.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum OAuthLexiconResolverFailure {
    #[error("invalid lexicon NSID: {0}")]
    InvalidNsid(String),
    #[error("lexicon resolver unavailable: {0}")]
    Unavailable(String),
    #[error("malformed lexicon document: {0}")]
    Malformed(String),
    #[error("lexicon provenance verification failed: {0}")]
    VerificationFailed(String),
}

/// Resource bounds guarding `include:` scope expansion.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct OAuthLexiconResolutionBudget {
    pub max_includes: usize,
    pub raw_budget: OAuthScopeBudget,
    pub expanded_budget: OAuthScopeBudget,
}

impl Default for OAuthLexiconResolutionBudget {
    fn default() -> Self {
        Self {
            max_includes: 16,
            raw_budget: OAuthScopeBudget::RAW_INPUT,
            expanded_budget: OAuthScopeBudget::EXPANDED_GRANT,
        }
    }
}

/// Async resolver for Lexicon `permission-set` documents (concrete repo-proof impl lives outside `petrel-server` until stacked with `petrel-lexicon`).
pub trait OAuthLexiconResolving: MaybeSend + MaybeSync {
    fn resolve(
        &self,
        nsid: &str,
    ) -> BoxFuture<'_, Result<OAuthLexiconResolution, OAuthLexiconResolverFailure>>;
}

/// Trait decoupling OAuth authorization/token issuance from concrete `petrel-lexicon` resolution.
pub trait OAuthLexiconScopeResolution: MaybeSend + MaybeSync {
    fn resolve_scopes<'a>(
        &'a self,
        requested: &'a ScopeSet,
        declared: &'a ScopeSet,
        unknown: OAuthUnknownScopePolicy,
        stage: OAuthScopeResolutionStage,
        languages: &'a [&'a str],
    ) -> BoxFuture<'a, Result<OAuthExpandedScopeSet, OAuthScopeResolutionError>>;
}

/// Deterministic in-memory lexicon resolver for tests and static permission-set registries.
#[derive(Debug, Default)]
pub struct StaticOAuthLexiconResolver {
    docs: Mutex<HashMap<String, OAuthLexiconResolution>>,
}

impl StaticOAuthLexiconResolver {
    /// Creates an empty static resolver.
    pub fn new() -> Self {
        Self::default()
    }

    /// Registers a resolved lexicon document.
    pub async fn register(&self, doc: OAuthLexiconDocument) {
        self.docs.lock().await.insert(
            doc.nsid.clone(),
            OAuthLexiconResolution::Resolved(Box::new(doc)),
        );
    }

    /// Registers a non-permission-set outcome for `nsid`.
    pub async fn register_outcome(&self, nsid: impl Into<String>, outcome: OAuthLexiconResolution) {
        self.docs.lock().await.insert(nsid.into(), outcome);
    }
}

impl OAuthLexiconResolving for StaticOAuthLexiconResolver {
    fn resolve(
        &self,
        nsid: &str,
    ) -> BoxFuture<'_, Result<OAuthLexiconResolution, OAuthLexiconResolverFailure>> {
        let key = nsid.to_owned();
        Box::pin(async move {
            Ok(self
                .docs
                .lock()
                .await
                .get(&key)
                .cloned()
                .unwrap_or(OAuthLexiconResolution::NotFound))
        })
    }
}

/// Caching wrapper around any [`OAuthLexiconResolving`] backend with TTL + stale-while-revalidate,
/// outage backoff, and short negative caching.
pub struct CachingOAuthLexiconResolver {
    inner: Arc<dyn OAuthLexiconResolving>,
    cache: Arc<dyn OAuthLexiconCache>,
    clock: Arc<dyn OAuthClock>,
    ttl_secs: i64,
    stale_ttl_secs: i64,
    negative_ttl_secs: i64,
    failure_backoff_secs: i64,
    max_backoff_entries: usize,
    negative_until: Mutex<HashMap<String, i64>>,
    outage_retry_after: Mutex<HashMap<String, i64>>,
}

impl std::fmt::Debug for CachingOAuthLexiconResolver {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("CachingOAuthLexiconResolver")
            .field("ttl_secs", &self.ttl_secs)
            .finish_non_exhaustive()
    }
}

impl CachingOAuthLexiconResolver {
    /// Default capacity ceiling for the in-memory negative-cache and outage-backoff maps.
    pub const DEFAULT_MAX_BACKOFF_ENTRIES: usize = 4096;

    /// Wraps `inner` with `cache` using default 15-minute fresh / 24-hour stale / 5-minute negative
    /// & outage backoff windows.
    pub fn new(inner: Arc<dyn OAuthLexiconResolving>, cache: Arc<dyn OAuthLexiconCache>) -> Self {
        Self {
            inner,
            cache,
            clock: Arc::new(SystemOAuthClock),
            ttl_secs: 900,
            stale_ttl_secs: 86_400,
            negative_ttl_secs: 300,
            failure_backoff_secs: 300,
            max_backoff_entries: Self::DEFAULT_MAX_BACKOFF_ENTRIES,
            negative_until: Mutex::new(HashMap::new()),
            outage_retry_after: Mutex::new(HashMap::new()),
        }
    }

    /// Overrides the clock source.
    #[must_use]
    pub fn with_clock(mut self, clock: Arc<dyn OAuthClock>) -> Self {
        self.clock = clock;
        self
    }

    /// Overrides fresh and stale TTLs in seconds.
    #[must_use]
    pub fn with_ttls(mut self, ttl_secs: i64, stale_ttl_secs: i64) -> Self {
        self.ttl_secs = ttl_secs;
        self.stale_ttl_secs = stale_ttl_secs;
        self
    }

    /// Overrides negative-cache and outage retry backoff windows in seconds.
    #[must_use]
    pub fn with_backoffs(mut self, negative_ttl_secs: i64, failure_backoff_secs: i64) -> Self {
        self.negative_ttl_secs = negative_ttl_secs;
        self.failure_backoff_secs = failure_backoff_secs;
        self
    }

    /// Overrides the maximum entries retained in negative-cache and outage-backoff tracking maps.
    #[must_use]
    pub fn with_max_backoff_entries(mut self, max_entries: usize) -> Self {
        self.max_backoff_entries = max_entries.max(1);
        self
    }

    /// Returns current `(negative_cache_entries, outage_backoff_entries)` counts after pruning expired entries.
    pub async fn backoff_tracking_counts(&self) -> (usize, usize) {
        let now = self.clock.now_secs();
        let mut neg = self.negative_until.lock().await;
        neg.retain(|_, until| now < *until);
        let mut outage = self.outage_retry_after.lock().await;
        outage.retain(|_, until| now < *until);
        (neg.len(), outage.len())
    }

    fn insert_bounded_deadline(
        map: &mut HashMap<String, i64>,
        key: String,
        until: i64,
        now: i64,
        max_entries: usize,
    ) {
        map.retain(|_, existing| now < *existing);
        let cap = max_entries.max(1);
        if map.len() >= cap
            && !map.contains_key(&key)
            && let Some(oldest) = map
                .iter()
                .min_by_key(|(_, existing)| *existing)
                .map(|(k, _)| k.clone())
        {
            map.remove(&oldest);
        }
        map.insert(key, until);
    }

    fn decode_cached(
        nsid: &str,
        entry: &OAuthCachedLexicon,
    ) -> Result<OAuthLexiconResolution, OAuthLexiconResolverFailure> {
        let doc = OAuthLexiconDocument::from_json(
            nsid,
            entry.cid.clone(),
            entry.source_did.clone(),
            entry.raw_json.clone(),
        )?;
        Ok(if doc.permission_set.is_some() {
            OAuthLexiconResolution::Resolved(Box::new(doc))
        } else {
            OAuthLexiconResolution::NotPermissionSet
        })
    }
}

impl OAuthLexiconResolving for CachingOAuthLexiconResolver {
    fn resolve(
        &self,
        nsid: &str,
    ) -> BoxFuture<'_, Result<OAuthLexiconResolution, OAuthLexiconResolverFailure>> {
        let key = nsid.to_owned();
        Box::pin(async move {
            let now = self.clock.now_secs();
            let cached = self
                .cache
                .get_cached_lexicon(&key)
                .await
                .map_err(|err| OAuthLexiconResolverFailure::Unavailable(err.to_string()))?;
            if let Some(ref entry) = cached {
                if now < entry.expires_at_secs {
                    return Self::decode_cached(&key, entry);
                }
                if now < entry.stale_until_secs {
                    let mut outage = self.outage_retry_after.lock().await;
                    outage.retain(|_, until| now < *until);
                    if outage.get(&key).is_some_and(|until| now < *until) {
                        return Self::decode_cached(&key, entry);
                    }
                }
            }

            {
                let mut neg = self.negative_until.lock().await;
                neg.retain(|_, until| now < *until);
                if neg.get(&key).is_some_and(|until| now < *until) {
                    return Ok(OAuthLexiconResolution::NotFound);
                }
            }

            match self.inner.resolve(&key).await {
                Ok(OAuthLexiconResolution::Resolved(doc)) => {
                    self.negative_until.lock().await.remove(&key);
                    self.outage_retry_after.lock().await.remove(&key);
                    let entry = OAuthCachedLexicon {
                        nsid: key.clone(),
                        source_did: doc.source_did.clone(),
                        raw_json: doc.raw_json.clone(),
                        cid: doc.cid.clone(),
                        fetched_at_secs: now,
                        expires_at_secs: now + self.ttl_secs,
                        stale_until_secs: now + self.stale_ttl_secs,
                    };
                    let _ = self.cache.put_cached_lexicon(entry).await;
                    Ok(OAuthLexiconResolution::Resolved(doc))
                }
                Ok(other) => {
                    let mut neg = self.negative_until.lock().await;
                    Self::insert_bounded_deadline(
                        &mut neg,
                        key,
                        now + self.negative_ttl_secs,
                        now,
                        self.max_backoff_entries,
                    );
                    Ok(other)
                }
                Err(err) => {
                    if let Some(ref entry) = cached
                        && now < entry.stale_until_secs
                    {
                        let mut outage = self.outage_retry_after.lock().await;
                        Self::insert_bounded_deadline(
                            &mut outage,
                            key.clone(),
                            now + self.failure_backoff_secs,
                            now,
                            self.max_backoff_entries,
                        );
                        return Self::decode_cached(&key, entry);
                    }
                    let mut neg = self.negative_until.lock().await;
                    Self::insert_bounded_deadline(
                        &mut neg,
                        key,
                        now + self.negative_ttl_secs,
                        now,
                        self.max_backoff_entries,
                    );
                    Err(err)
                }
            }
        })
    }
}

/// Default [`OAuthLexiconScopeResolution`] backed by an [`OAuthLexiconResolving`] schema resolver.
pub struct PetrelOAuthScopeResolver {
    lexicons: Arc<dyn OAuthLexiconResolving>,
    budget: OAuthLexiconResolutionBudget,
}

impl std::fmt::Debug for PetrelOAuthScopeResolver {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("PetrelOAuthScopeResolver")
            .field("budget", &self.budget)
            .finish_non_exhaustive()
    }
}

impl PetrelOAuthScopeResolver {
    /// Creates a scope resolver backed by `lexicons`.
    pub fn new(lexicons: Arc<dyn OAuthLexiconResolving>) -> Self {
        Self {
            lexicons,
            budget: OAuthLexiconResolutionBudget::default(),
        }
    }

    /// Overrides resolution budgets.
    #[must_use]
    pub fn with_budget(mut self, budget: OAuthLexiconResolutionBudget) -> Self {
        self.budget = budget;
        self
    }

    fn expand_include(
        include: &IncludeScope,
        set: &LexiconPermissionSet,
    ) -> Result<Vec<String>, OAuthScopeResolutionError> {
        include
            .expand_to_scope_strings(set)
            .map_err(|err| OAuthScopeResolutionError::InvalidExpandedScope(err.to_string()))
    }
}

impl OAuthLexiconScopeResolution for PetrelOAuthScopeResolver {
    fn resolve_scopes<'a>(
        &'a self,
        requested: &'a ScopeSet,
        declared: &'a ScopeSet,
        unknown: OAuthUnknownScopePolicy,
        _stage: OAuthScopeResolutionStage,
        languages: &'a [&'a str],
    ) -> BoxFuture<'a, Result<OAuthExpandedScopeSet, OAuthScopeResolutionError>> {
        Box::pin(async move {
            let admitted = OAuthScopeAdmissionPolicy::admit(requested, declared, unknown)?;
            let mut expanded_raw = admitted.raw_scopes().clone();
            let mut descriptions = Vec::new();
            let mut include_count = 0usize;

            for scope in admitted.scopes() {
                if let AtProtoScope::Include(include) = scope {
                    include_count += 1;
                    if include_count > self.budget.max_includes {
                        return Err(OAuthScopeResolutionError::Admission(
                            OAuthScopeAdmissionError::ExpandedGrantTooManyScopes {
                                count: include_count,
                                limit: self.budget.max_includes,
                            },
                        ));
                    }
                    let Some(nsid) = include.parameters().single("nsid") else {
                        return Err(OAuthScopeResolutionError::InvalidExpandedScope(
                            "include scope missing nsid".into(),
                        ));
                    };
                    match self.lexicons.resolve(nsid).await {
                        Ok(OAuthLexiconResolution::Resolved(doc)) => {
                            let Some(set) = doc.permission_set.as_ref() else {
                                return Err(OAuthScopeResolutionError::ResolutionFailed {
                                    nsid: nsid.to_owned(),
                                    reason: "lexicon is not a permission-set".into(),
                                });
                            };
                            let wire_str = include
                                .wire_scope_string()
                                .unwrap_or_else(|_| format!("include:{nsid}"));
                            descriptions.push(OAuthScopeDescription {
                                scope: wire_str,
                                title: set.localized_title(languages).map(str::to_owned),
                                detail: set.localized_detail(languages).map(str::to_owned),
                                source_nsid: Some(nsid.to_owned()),
                            });
                            for expanded in Self::expand_include(include, set)? {
                                expanded_raw.insert(expanded);
                            }
                        }
                        Ok(OAuthLexiconResolution::NotFound) => {
                            return Err(OAuthScopeResolutionError::ResolutionFailed {
                                nsid: nsid.to_owned(),
                                reason: "permission set not found".into(),
                            });
                        }
                        Ok(OAuthLexiconResolution::NotPermissionSet) => {
                            return Err(OAuthScopeResolutionError::ResolutionFailed {
                                nsid: nsid.to_owned(),
                                reason: "lexicon is not a permission-set".into(),
                            });
                        }
                        Err(err) => {
                            return Err(OAuthScopeResolutionError::ResolutionFailed {
                                nsid: nsid.to_owned(),
                                reason: err.to_string(),
                            });
                        }
                    }
                } else if let Ok(wire) = scope.wire_scope_string() {
                    descriptions.push(OAuthScopeDescription {
                        scope: wire,
                        title: None,
                        detail: None,
                        source_nsid: None,
                    });
                }
            }

            let expanded = ScopeSet::from_raw_scopes(expanded_raw);
            OAuthScopeAdmissionPolicy::enforce_expanded_grant_budget(
                &expanded,
                self.budget.expanded_budget,
            )?;

            Ok(OAuthExpandedScopeSet {
                admitted,
                expanded,
                descriptions,
            })
        })
    }
}
