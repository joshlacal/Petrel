use std::collections::HashSet;
use std::fmt;
use std::str::FromStr;

use petrel_core::{Cid, Did, Nsid, RecordKey, Tid};

use crate::error::DomainError;

/// Policy governing how loosely or strictly repositories, records, MST links,
/// and CAR archives are validated on read.
///
/// Mirrors `RepositoryReadPolicy` in Swift.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[allow(clippy::struct_excessive_bools)]
pub struct RepositoryReadPolicy {
    pub requires_safe_integers: bool,
    pub requires_blessed_links_in_records: bool,
    pub requires_blessed_record_links_in_mst: bool,
    pub requires_record_type_to_match_collection: bool,
    pub rejects_foreign_car_blocks: bool,
    pub requires_single_car_root: bool,
}

impl RepositoryReadPolicy {
    /// Strict AT Protocol repository ruleset (matches `RepositoryReadPolicy.strict`).
    pub const fn strict() -> Self {
        Self {
            requires_safe_integers: true,
            requires_blessed_links_in_records: true,
            requires_blessed_record_links_in_mst: true,
            requires_record_type_to_match_collection: true,
            rejects_foreign_car_blocks: true,
            requires_single_car_root: true,
        }
    }

    /// Permissive AT Protocol data-model ruleset (matches `RepositoryReadPolicy.dataModel`).
    pub const fn data_model() -> Self {
        Self {
            requires_safe_integers: false,
            requires_blessed_links_in_records: false,
            requires_blessed_record_links_in_mst: false,
            requires_record_type_to_match_collection: false,
            rejects_foreign_car_blocks: false,
            requires_single_car_root: false,
        }
    }
}

impl Default for RepositoryReadPolicy {
    fn default() -> Self {
        Self::strict()
    }
}

/// Canonical `collection/rkey` repository path validated against AT Protocol
/// NSID, record key, and MST key byte-length bounds.
///
/// Mirrors `PublicRepositoryPath` in Swift.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct RepositoryPath {
    collection: Nsid,
    record_key: RecordKey,
    mst_key: String,
}

impl RepositoryPath {
    pub const MAXIMUM_COLLECTION_BYTES: usize = 317;
    pub const MAXIMUM_RECORD_KEY_BYTES: usize = 512;
    pub const MAXIMUM_MST_KEY_BYTES: usize = 1024;

    /// Constructs a repository path from validated components.
    pub fn new(collection: &str, record_key: &str) -> Result<Self, DomainError> {
        let collection_nsid = Nsid::parse(collection)
            .map_err(|err| DomainError::InvalidCollection(format!("{collection}: {err}")))?;
        if collection_nsid.as_str().len() > Self::MAXIMUM_COLLECTION_BYTES {
            return Err(DomainError::CollectionTooLong {
                len: collection_nsid.as_str().len(),
                max: Self::MAXIMUM_COLLECTION_BYTES,
            });
        }
        let rkey = RecordKey::parse(record_key)
            .map_err(|err| DomainError::InvalidRecordKey(format!("{record_key}: {err}")))?;
        if rkey.as_str().len() > Self::MAXIMUM_RECORD_KEY_BYTES {
            return Err(DomainError::RecordKeyTooLong {
                len: rkey.as_str().len(),
                max: Self::MAXIMUM_RECORD_KEY_BYTES,
            });
        }
        let mst_key = format!("{}/{}", collection_nsid.as_str(), rkey.as_str());
        if mst_key.len() > Self::MAXIMUM_MST_KEY_BYTES {
            return Err(DomainError::PathTooLong {
                len: mst_key.len(),
                max: Self::MAXIMUM_MST_KEY_BYTES,
            });
        }
        Ok(Self {
            collection: collection_nsid,
            record_key: rkey,
            mst_key,
        })
    }

    /// Parses an MST key in `collection/rkey` form.
    pub fn from_mst_key(mst_key: &str) -> Result<Self, DomainError> {
        let Some((collection, record_key)) = mst_key.split_once('/') else {
            return Err(DomainError::InvalidPath(format!(
                "MST key must have 'collection/rkey' form: {mst_key}"
            )));
        };
        if record_key.contains('/') {
            return Err(DomainError::InvalidPath(format!(
                "MST key must contain exactly one '/': {mst_key}"
            )));
        }
        Self::new(collection, record_key)
    }

    pub fn collection(&self) -> &Nsid {
        &self.collection
    }

    pub fn collection_str(&self) -> &str {
        self.collection.as_str()
    }

    pub fn record_key(&self) -> &RecordKey {
        &self.record_key
    }

    pub fn record_key_str(&self) -> &str {
        self.record_key.as_str()
    }

    pub fn mst_key(&self) -> &str {
        &self.mst_key
    }
}

impl fmt::Display for RepositoryPath {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.mst_key)
    }
}

impl FromStr for RepositoryPath {
    type Err = DomainError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Self::from_mst_key(s)
    }
}

/// Repository revision identifier backed by [`petrel_core::Tid`].
///
/// Mirrors `PublicRepositoryTID` in Swift: 13 base32-sortable characters
/// starting with `234567abcdefghij`, supporting monotonic advancement and
/// future-drift checks.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct RepositoryTid(Tid);

impl RepositoryTid {
    /// Maximum future clock drift permitted by `PublicRepositoryTID.isInFuture`.
    pub const DEFAULT_FUTURE_TOLERANCE_MICROS: u64 = 300_000_000;

    /// Parses a repository revision TID string.
    pub fn parse(raw: &str) -> Result<Self, DomainError> {
        Tid::parse(raw)
            .map(Self)
            .map_err(|err| DomainError::InvalidTid(format!("{raw}: {err}")))
    }

    /// Constructs a repository TID from a 53-bit timestamp and 10-bit clock ID.
    pub fn from_parts(timestamp_micros: u64, clock_id: u16) -> Result<Self, DomainError> {
        Tid::from_parts(timestamp_micros, clock_id)
            .map(Self)
            .map_err(|err| DomainError::InvalidTid(err.to_string()))
    }

    /// Generates the next strictly monotonic TID relative to `previous` and
    /// `now_micros`.
    pub fn next_after(
        previous: Option<&Self>,
        now_micros: u64,
        clock_id: u16,
    ) -> Result<Self, DomainError> {
        let effective_clock = clock_id & 1023;
        let clamped_now = now_micros.min(Tid::MAX_TIMESTAMP_MICROS);
        let candidate = Self::from_parts(clamped_now, effective_clock)?;
        match previous {
            None => Ok(candidate),
            Some(prev) if candidate > *prev => Ok(candidate),
            Some(prev) => {
                let prev_val = prev.0.value();
                if prev.0.has_high_bit() {
                    return Err(DomainError::TidOverflow);
                }
                let next_ts = prev
                    .0
                    .timestamp_micros()
                    .checked_add(1)
                    .ok_or(DomainError::TidOverflow)?;
                if next_ts > Tid::MAX_TIMESTAMP_MICROS {
                    return Err(DomainError::TidOverflow);
                }
                let next = Self::from_parts(next_ts, effective_clock)?;
                if next.0.value() <= prev_val {
                    return Err(DomainError::TidOverflow);
                }
                Ok(next)
            }
        }
    }

    /// Generates a fresh TID from the current wall-clock time.
    pub fn now(clock_id: u16) -> Result<Self, DomainError> {
        Self::next_after(None, current_unix_micros(), clock_id)
    }

    /// Returns true if this TID's timestamp is more than `tolerance_micros` ahead of `now_micros`.
    pub fn is_in_future(&self, now_micros: u64, tolerance_micros: u64) -> bool {
        self.0.timestamp_micros() > now_micros.saturating_add(tolerance_micros)
    }

    pub fn as_str(&self) -> &str {
        self.0.as_str()
    }

    pub fn inner(&self) -> &Tid {
        &self.0
    }

    pub fn timestamp_micros(&self) -> u64 {
        self.0.timestamp_micros()
    }

    pub fn clock_id(&self) -> u16 {
        self.0.clock_id()
    }
}

impl From<Tid> for RepositoryTid {
    fn from(value: Tid) -> Self {
        Self(value)
    }
}

impl From<RepositoryTid> for Tid {
    fn from(value: RepositoryTid) -> Self {
        value.0
    }
}

impl fmt::Display for RepositoryTid {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

impl FromStr for RepositoryTid {
    type Err = DomainError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Self::parse(s)
    }
}

/// Snapshot state of a repository tracked across commits (`PublicRepositoryState`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RepositoryState {
    pub did: Did,
    pub head_commit_cid: Option<Cid>,
    pub head_data_cid: Option<Cid>,
    pub rev: Option<RepositoryTid>,
    pub signing_key_generation: u64,
}

impl RepositoryState {
    /// Creates an initial pre-genesis repository state.
    pub fn new(did: Did, signing_key_generation: u64) -> Result<Self, DomainError> {
        if signing_key_generation == 0 {
            return Err(DomainError::InvalidPath(
                "signing_key_generation must be positive".into(),
            ));
        }
        Ok(Self {
            did,
            head_commit_cid: None,
            head_data_cid: None,
            rev: None,
            signing_key_generation,
        })
    }

    /// Creates a repository state anchored at an existing commit.
    pub fn with_head(
        did: Did,
        head_commit_cid: Cid,
        head_data_cid: Cid,
        rev: RepositoryTid,
        signing_key_generation: u64,
    ) -> Self {
        Self {
            did,
            head_commit_cid: Some(head_commit_cid),
            head_data_cid: Some(head_data_cid),
            rev: Some(rev),
            signing_key_generation,
        }
    }
}

/// A single mutation targeting a [`RepositoryPath`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WriteOp {
    Create {
        path: RepositoryPath,
        record_cbor: Vec<u8>,
    },
    Update {
        path: RepositoryPath,
        record_cbor: Vec<u8>,
    },
    Delete {
        path: RepositoryPath,
    },
}

impl WriteOp {
    pub fn path(&self) -> &RepositoryPath {
        match self {
            Self::Create { path, .. } | Self::Update { path, .. } | Self::Delete { path } => path,
        }
    }

    pub fn record_cbor(&self) -> Option<&[u8]> {
        match self {
            Self::Create { record_cbor, .. } | Self::Update { record_cbor, .. } => {
                Some(record_cbor)
            }
            Self::Delete { .. } => None,
        }
    }
}

/// Validated, duplicate-free batch of repository writes (`PublicRepositoryWriteBatch`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WriteBatch {
    writes: Vec<WriteOp>,
}

impl WriteBatch {
    /// Validates a non-empty batch with no duplicate target paths.
    pub fn new(writes: Vec<WriteOp>) -> Result<Self, DomainError> {
        if writes.is_empty() {
            return Err(DomainError::EmptyWriteBatch);
        }
        let mut seen = HashSet::with_capacity(writes.len());
        for write in &writes {
            let key = write.path().mst_key();
            if !seen.insert(key.to_owned()) {
                return Err(DomainError::DuplicateWriteTarget(key.to_owned()));
            }
        }
        Ok(Self { writes })
    }

    /// Allows constructing a possibly-empty write batch (e.g. genesis empty commit).
    pub fn allowing_empty(writes: Vec<WriteOp>) -> Result<Self, DomainError> {
        let mut seen = HashSet::with_capacity(writes.len());
        for write in &writes {
            let key = write.path().mst_key();
            if !seen.insert(key.to_owned()) {
                return Err(DomainError::DuplicateWriteTarget(key.to_owned()));
            }
        }
        Ok(Self { writes })
    }

    pub fn writes(&self) -> &[WriteOp] {
        &self.writes
    }

    pub fn into_writes(self) -> Vec<WriteOp> {
        self.writes
    }

    pub fn len(&self) -> usize {
        self.writes.len()
    }

    pub fn is_empty(&self) -> bool {
        self.writes.is_empty()
    }
}

pub(crate) fn current_unix_micros() -> u64 {
    let duration = web_time::SystemTime::now()
        .duration_since(web_time::UNIX_EPOCH)
        .unwrap_or_default();
    u64::try_from(duration.as_micros()).unwrap_or(u64::MAX)
}
