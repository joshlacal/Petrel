//! Jetstream domain events and filter predicates.

use petrel_api::generated::com::atproto::sync::subscribe_repos;
use petrel_core::Value;
use petrel_firehose::RelayRepoAction;
use serde::{Deserialize, Serialize};

/// One record mutation from the Jetstream v2 stream or archive.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JetstreamCommitEvent {
    /// Monotonic per-event sequence number (or `time_us` on legacy `/subscribe`).
    pub seq: i64,
    /// Repository DID.
    pub did: String,
    /// Event timestamp in Unix microseconds.
    pub time_us: i64,
    /// Commit TID revision string.
    pub rev: String,
    /// Mutation action (`create`, `update`, `delete`).
    pub operation: RelayRepoAction,
    /// Record collection NSID.
    pub collection: String,
    /// Record key.
    pub rkey: String,
    /// Record CID string (absent for deletes and archive rows).
    pub cid: Option<String>,
    /// Raw JSON bytes of the record (`None` on deletes or failed archive decode).
    pub record_json: Option<Vec<u8>>,
}

impl JetstreamCommitEvent {
    /// Decodes `record_json` into [`petrel_core::Value`].
    pub fn decoded_record(&self) -> Option<Value> {
        let bytes = self.record_json.as_deref()?;
        petrel_core::from_json(bytes).ok()
    }
}

/// Identity update event.
#[derive(Debug, Clone, PartialEq)]
pub struct JetstreamIdentityEvent {
    pub seq: i64,
    pub did: String,
    pub time_us: i64,
    /// Wrapped upstream `#identity` event (`None` if inner decode failed).
    pub identity: Option<subscribe_repos::Identity>,
}

/// Account status change event.
#[derive(Debug, Clone, PartialEq)]
pub struct JetstreamAccountEvent {
    pub seq: i64,
    pub did: String,
    pub time_us: i64,
    /// Wrapped upstream `#account` event (`None` if inner decode failed).
    pub account: Option<subscribe_repos::Account>,
}

/// Repository sync event.
#[derive(Debug, Clone, PartialEq)]
pub struct JetstreamSyncEvent {
    pub seq: i64,
    pub did: String,
    pub time_us: i64,
    /// Wrapped upstream `#sync` event (`None` if inner decode failed).
    pub sync: Option<subscribe_repos::Sync>,
}

/// Advisory server notice (carries no `seq` and does not advance the cursor).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JetstreamInfoEvent {
    pub name: String,
    pub message: Option<String>,
}

/// High-level decoded event from a Jetstream stream or segment archive.
#[derive(Debug, Clone, PartialEq)]
pub enum JetstreamEvent {
    Commit(JetstreamCommitEvent),
    Identity(JetstreamIdentityEvent),
    Account(JetstreamAccountEvent),
    Sync(JetstreamSyncEvent),
    Info(JetstreamInfoEvent),
}

impl JetstreamEvent {
    /// Sequence number carried by this event (`None` for [`Self::Info`]).
    pub const fn seq(&self) -> Option<i64> {
        match self {
            Self::Commit(e) => Some(e.seq),
            Self::Identity(e) => Some(e.seq),
            Self::Account(e) => Some(e.seq),
            Self::Sync(e) => Some(e.seq),
            Self::Info(_) => None,
        }
    }

    /// Repository DID carried by this event (`None` for [`Self::Info`]).
    pub fn did(&self) -> Option<&str> {
        match self {
            Self::Commit(e) => Some(&e.did),
            Self::Identity(e) => Some(&e.did),
            Self::Account(e) => Some(&e.did),
            Self::Sync(e) => Some(&e.did),
            Self::Info(_) => None,
        }
    }

    /// Wire event type fragment (`commit`, `identity`, `account`, `sync`, `info`).
    pub const fn type_name(&self) -> &'static str {
        match self {
            Self::Commit(_) => "commit",
            Self::Identity(_) => "identity",
            Self::Account(_) => "account",
            Self::Sync(_) => "sync",
            Self::Info(_) => "info",
        }
    }
}

/// Event kinds used for Jetstream filtering.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum JetstreamKind {
    Commit,
    Identity,
    Account,
    Sync,
}

impl JetstreamKind {
    /// All supported event kinds in canonical order.
    pub const ALL: [Self; 4] = [Self::Commit, Self::Identity, Self::Account, Self::Sync];

    /// Wire filter string (`"commit"`, `"identity"`, `"account"`, `"sync"`).
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Commit => "commit",
            Self::Identity => "identity",
            Self::Account => "account",
            Self::Sync => "sync",
        }
    }
}

/// Independent ANDed filter predicates for Jetstream subscriptions and snapshot planning.
/// Each dimension matches everything when empty.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct JetstreamFilter {
    /// Allowed event kinds (empty = all kinds).
    pub kinds: Vec<JetstreamKind>,
    /// Allowed repository DIDs (empty = all DIDs).
    pub dids: Vec<String>,
    /// Allowed collection NSIDs or `<prefix>.*` wildcards; constrains commit events ONLY.
    pub collections: Vec<String>,
}

impl JetstreamFilter {
    /// Creates an unconstrained filter matching every event.
    pub fn new() -> Self {
        Self::default()
    }

    /// Exact filter re-applied client-side to decoded events (snapshot planners may over-select).
    /// `collections` constrains only commits; [`JetstreamEvent::Info`] always passes.
    pub fn matches(&self, event: &JetstreamEvent) -> bool {
        let kind = match event {
            JetstreamEvent::Info(_) => return true,
            JetstreamEvent::Commit(_) => JetstreamKind::Commit,
            JetstreamEvent::Identity(_) => JetstreamKind::Identity,
            JetstreamEvent::Account(_) => JetstreamKind::Account,
            JetstreamEvent::Sync(_) => JetstreamKind::Sync,
        };
        if !self.kinds.is_empty() && !self.kinds.contains(&kind) {
            return false;
        }
        if !self.dids.is_empty()
            && let Some(did) = event.did()
            && !self.dids.iter().any(|d| d == did)
        {
            return false;
        }
        if let JetstreamEvent::Commit(commit) = event
            && !self.collections.is_empty()
            && !self
                .collections
                .iter()
                .any(|pattern| Self::collection_matches(pattern, &commit.collection))
        {
            return false;
        }
        true
    }

    /// Matches either an exact NSID or a `<prefix>.*` wildcard.
    pub fn collection_matches(pattern: &str, collection: &str) -> bool {
        if let Some(prefix) = pattern.strip_suffix(".*") {
            let mut with_dot = String::with_capacity(prefix.len() + 1);
            with_dot.push_str(prefix);
            with_dot.push('.');
            collection.starts_with(&with_dot)
        } else {
            pattern == collection
        }
    }
}
