//! Public firehose event materials, source keys, time helpers, and relay verifier types.

use std::collections::BTreeMap;

use petrel::rt::SystemTime;
use petrel_core::Cid;
use serde::{Deserialize, Serialize};

use crate::limits::FirehoseFrameLimits;

/// Final durable event kind stored in outboxes and the global log.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PublicFirehoseEventKind {
    Commit,
    Sync,
    Identity,
    Account,
}

/// Repository mutation action on the firehose wire.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PublicFirehoseRepoAction {
    Create,
    Update,
    Delete,
}

/// One repository mutation op as it appears on the firehose wire.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PublicFirehoseRepoOp {
    pub action: PublicFirehoseRepoAction,
    pub path: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cid: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub prev: Option<String>,
}

/// Durable material for a `#commit` event.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PublicFirehoseCommitMaterial {
    pub did: String,
    pub rev: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub since: Option<String>,
    #[serde(rename = "commitCID")]
    pub commit_cid: String,
    #[serde(
        rename = "prevDataCID",
        default,
        skip_serializing_if = "Option::is_none"
    )]
    pub prev_data_cid: Option<String>,
    pub ops: Vec<PublicFirehoseRepoOp>,
    pub time: String,
}

/// Durable material for a `#sync` event.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PublicFirehoseSyncMaterial {
    pub did: String,
    pub rev: String,
    #[serde(rename = "commitCID")]
    pub commit_cid: String,
    pub time: String,
}

/// Durable material for an `#identity` event.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PublicFirehoseIdentityMaterial {
    pub did: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub handle: Option<String>,
    pub time: String,
}

/// Externally visible account statuses.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PublicFirehoseAccountStatus {
    Deactivated,
    Suspended,
    Takendown,
    Desynchronized,
    Throttled,
    Deleted,
}

impl PublicFirehoseAccountStatus {
    /// Returns the wire string for this account status.
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Deactivated => "deactivated",
            Self::Suspended => "suspended",
            Self::Takendown => "takendown",
            Self::Desynchronized => "desynchronized",
            Self::Throttled => "throttled",
            Self::Deleted => "deleted",
        }
    }
}

/// Durable material for an `#account` event.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PublicFirehoseAccountMaterial {
    pub did: String,
    pub active: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub status: Option<PublicFirehoseAccountStatus>,
    pub time: String,
}

/// Purpose-specific source keys for exact firehose replay idempotency.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PublicFirehoseSourceKey;

impl PublicFirehoseSourceKey {
    pub fn commit(did: &str, commit_cid: &str) -> String {
        format!("{did}|commit|{commit_cid}")
    }

    pub fn sync_oversize(did: &str, commit_cid: &str) -> String {
        format!("{did}|sync|oversize|{commit_cid}")
    }

    pub fn sync_manual(did: &str, request_uuid: &str) -> String {
        format!("{did}|sync|manual|{}", request_uuid.to_ascii_lowercase())
    }

    pub fn sync_activation(did: &str, operation_id: &str) -> String {
        format!("{did}|sync|activation|{operation_id}")
    }

    pub fn sync_reactivation(did: &str, operation_id: &str) -> String {
        format!("{did}|sync|reactivation|{operation_id}")
    }

    pub fn account(did: &str, operation_id: &str) -> String {
        format!("{did}|account|{operation_id}")
    }

    pub fn identity(did: &str, plc_operation_cid: &str) -> String {
        format!("{did}|identity|{plc_operation_cid}")
    }

    pub fn lifecycle_batch(did: &str, operation_id: &str) -> String {
        format!("{did}|lifecycle|{operation_id}")
    }
}

/// Errors returned by [`PublicFirehoseTime`].
#[derive(Debug, Clone, Copy, PartialEq, Eq, thiserror::Error)]
pub enum PublicFirehoseTimeError {
    #[error("timestamp is out of range")]
    OutOfRange,
}

/// UTC ISO-8601 and microsecond timestamp helpers for firehose events.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PublicFirehoseTime;

impl PublicFirehoseTime {
    /// Encodes a `SystemTime` as UTC ISO-8601 with millisecond precision (`YYYY-MM-DDTHH:MM:SS.mmmZ`).
    pub fn encode(time: SystemTime) -> String {
        let Ok(duration) = time.duration_since(petrel::rt::UNIX_EPOCH) else {
            return "1970-01-01T00:00:00.000Z".to_owned();
        };
        let total_secs = duration.as_secs();
        let millis = duration.subsec_millis();
        let secs_of_day = total_secs % 86_400;
        let days = i64::try_from(total_secs / 86_400).unwrap_or(i64::MAX);
        let (year, month, day) = civil_from_days(days);
        let hour = secs_of_day / 3_600;
        let minute = (secs_of_day % 3_600) / 60;
        let second = secs_of_day % 60;
        format!("{year:04}-{month:02}-{day:02}T{hour:02}:{minute:02}:{second:02}.{millis:03}Z")
    }

    /// Converts a non-negative finite `SystemTime` to whole microseconds since the Unix epoch.
    pub fn microseconds(time: SystemTime) -> Result<i64, PublicFirehoseTimeError> {
        let duration = time
            .duration_since(petrel::rt::UNIX_EPOCH)
            .map_err(|_| PublicFirehoseTimeError::OutOfRange)?;
        i64::try_from(duration.as_micros()).map_err(|_| PublicFirehoseTimeError::OutOfRange)
    }

    /// Converts finite Unix seconds (`f64`) to whole microseconds, rejecting negative, NaN, infinite,
    /// or overflowing values.
    #[allow(clippy::cast_precision_loss, clippy::cast_possible_truncation)]
    pub fn microseconds_from_seconds(seconds: f64) -> Result<i64, PublicFirehoseTimeError> {
        if !seconds.is_finite() || seconds < 0.0 {
            return Err(PublicFirehoseTimeError::OutOfRange);
        }
        let micros = (seconds * 1_000_000.0).trunc();
        if !micros.is_finite() || micros > i64::MAX as f64 {
            return Err(PublicFirehoseTimeError::OutOfRange);
        }
        Ok(micros as i64)
    }
}

/// Howard Hinnant's civil-from-days algorithm (public domain).
fn civil_from_days(days: i64) -> (i64, u32, u32) {
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = (z - era * 146_097).cast_unsigned();
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe.cast_signed() + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let year = y + i64::from(m <= 2);
    (
        year,
        u32::try_from(m).unwrap_or(1),
        u32::try_from(d).unwrap_or(1),
    )
}

/// Errors produced during relay frame decoding and repository/semantic verification.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, thiserror::Error)]
#[serde(rename_all = "camelCase")]
pub enum RelayVerifierError {
    #[error("truncated frame")]
    TruncatedFrame,
    #[error("invalid CBOR")]
    InvalidCbor,
    #[error("non-canonical CBOR")]
    NonCanonicalCbor,
    #[error("invalid CID link")]
    InvalidCidLink,
    #[error("trailing frame bytes")]
    TrailingFrameBytes,
    #[error("frame too large")]
    FrameTooLarge,
    #[error("invalid frame header")]
    InvalidFrameHeader,
    #[error("unknown event kind")]
    UnknownEventKind,
    #[error("invalid event body")]
    InvalidEventBody,
    #[error("sequence out of range")]
    SequenceOutOfRange,
    #[error("commit blocks too large")]
    CommitBlocksTooLarge,
    #[error("sync blocks too large")]
    SyncBlocksTooLarge,
    #[error("too many operations")]
    TooManyOperations,
    #[error("invalid repository operation")]
    InvalidRepositoryOperation,
    #[error("invalid account status")]
    InvalidAccountStatus,
    #[error("duplicate sequence")]
    DuplicateSequence,
    #[error("sequence gap")]
    SequenceGap,
    #[error("reconnect cursor out of bounds")]
    ReconnectCursorOutOfBounds,
    #[error("offline commit count mismatch")]
    OfflineCommitCountMismatch,
    #[error("lifecycle order mismatch")]
    LifecycleOrderMismatch,
    #[error("repository DID mismatch")]
    RepositoryDidMismatch,
    #[error("commit revision mismatch")]
    CommitRevisionMismatch,
    #[error("commit CID mismatch")]
    CommitCidMismatch,
    #[error("since revision mismatch")]
    SinceRevisionMismatch,
    #[error("previous data CID mismatch")]
    PreviousDataCidMismatch,
    #[error("repository delta mismatch")]
    RepositoryDeltaMismatch,
    #[error("since observed not proven")]
    SinceObservedNotProven,
    #[error("repository CAR too large")]
    RepositoryCarTooLarge,
    #[error("invalid repository CAR")]
    InvalidRepositoryCar,
    #[error("invalid commit signature")]
    InvalidCommitSignature,
    #[error("final revision mismatch")]
    FinalRevisionMismatch,
    #[error("final commit CID mismatch")]
    FinalCommitCidMismatch,
    #[error("final data CID mismatch")]
    FinalDataCidMismatch,
    #[error("final projection mismatch")]
    FinalProjectionMismatch,
    #[error("final MST mismatch")]
    FinalMstMismatch,
    #[error("invalid capture manifest")]
    InvalidCaptureManifest,
    #[error("missing final repository")]
    MissingFinalRepository,
    #[error("revision rollback")]
    RevisionRollback,
    #[error("storage failure")]
    StorageFailure,
}

impl RelayVerifierError {
    /// Returns the camelCase wire/raw identifier matching Swift's `RelayVerifierError.rawValue`.
    pub const fn raw_value(self) -> &'static str {
        match self {
            Self::TruncatedFrame => "truncatedFrame",
            Self::InvalidCbor => "invalidCBOR",
            Self::NonCanonicalCbor => "nonCanonicalCBOR",
            Self::InvalidCidLink => "invalidCIDLink",
            Self::TrailingFrameBytes => "trailingFrameBytes",
            Self::FrameTooLarge => "frameTooLarge",
            Self::InvalidFrameHeader => "invalidFrameHeader",
            Self::UnknownEventKind => "unknownEventKind",
            Self::InvalidEventBody => "invalidEventBody",
            Self::SequenceOutOfRange => "sequenceOutOfRange",
            Self::CommitBlocksTooLarge => "commitBlocksTooLarge",
            Self::SyncBlocksTooLarge => "syncBlocksTooLarge",
            Self::TooManyOperations => "tooManyOperations",
            Self::InvalidRepositoryOperation => "invalidRepositoryOperation",
            Self::InvalidAccountStatus => "invalidAccountStatus",
            Self::DuplicateSequence => "duplicateSequence",
            Self::SequenceGap => "sequenceGap",
            Self::ReconnectCursorOutOfBounds => "reconnectCursorOutOfBounds",
            Self::OfflineCommitCountMismatch => "offlineCommitCountMismatch",
            Self::LifecycleOrderMismatch => "lifecycleOrderMismatch",
            Self::RepositoryDidMismatch => "repositoryDIDMismatch",
            Self::CommitRevisionMismatch => "commitRevisionMismatch",
            Self::CommitCidMismatch => "commitCIDMismatch",
            Self::SinceRevisionMismatch => "sinceRevisionMismatch",
            Self::PreviousDataCidMismatch => "previousDataCIDMismatch",
            Self::RepositoryDeltaMismatch => "repositoryDeltaMismatch",
            Self::SinceObservedNotProven => "sinceObservedNotProven",
            Self::RepositoryCarTooLarge => "repositoryCARTooLarge",
            Self::InvalidRepositoryCar => "invalidRepositoryCAR",
            Self::InvalidCommitSignature => "invalidCommitSignature",
            Self::FinalRevisionMismatch => "finalRevisionMismatch",
            Self::FinalCommitCidMismatch => "finalCommitCIDMismatch",
            Self::FinalDataCidMismatch => "finalDataCIDMismatch",
            Self::FinalProjectionMismatch => "finalProjectionMismatch",
            Self::FinalMstMismatch => "finalMSTMismatch",
            Self::InvalidCaptureManifest => "invalidCaptureManifest",
            Self::MissingFinalRepository => "missingFinalRepository",
            Self::RevisionRollback => "revisionRollback",
            Self::StorageFailure => "storageFailure",
        }
    }
}

/// Action on a repository record inside a decoded `#commit` event.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum RelayRepoAction {
    Create,
    Update,
    Delete,
}

impl RelayRepoAction {
    pub fn from_wire(raw: &str) -> Option<Self> {
        match raw {
            "create" => Some(Self::Create),
            "update" => Some(Self::Update),
            "delete" => Some(Self::Delete),
            _ => None,
        }
    }

    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Create => "create",
            Self::Update => "update",
            Self::Delete => "delete",
        }
    }
}

/// Decoded repository operation inside a `#commit` event.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RelayRepoOp {
    pub action: RelayRepoAction,
    pub path: String,
    pub cid: Option<Cid>,
    pub prev: Option<Cid>,
}

/// Decoded `#identity` event.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RelayIdentityEvent {
    pub seq: i64,
    pub did: String,
    pub time: String,
    pub handle: Option<String>,
}

/// Decoded `#account` event.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RelayAccountEvent {
    pub seq: i64,
    pub did: String,
    pub time: String,
    pub active: bool,
    pub status: Option<String>,
}

/// Decoded `#sync` event.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RelaySyncEvent {
    pub seq: i64,
    pub did: String,
    pub blocks: Vec<u8>,
    pub rev: String,
    pub time: String,
}

/// Decoded `#commit` event.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RelayCommitEvent {
    pub seq: i64,
    pub repo: String,
    pub commit_cid: Cid,
    pub rev: String,
    pub since: Option<String>,
    pub blocks: Vec<u8>,
    pub ops: Vec<RelayRepoOp>,
    pub prev_data_cid: Option<Cid>,
    pub time: String,
}

/// Decoded `#info` event.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RelayInfoEvent {
    pub name: String,
    pub message: Option<String>,
}

/// Decoded `#error` (`op: -1`) event.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RelayErrorEvent {
    pub error: String,
    pub message: Option<String>,
}

/// Decoded `com.atproto.sync.subscribeRepos` event.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RelayEvent {
    Identity(RelayIdentityEvent),
    Account(RelayAccountEvent),
    Sync(RelaySyncEvent),
    Commit(RelayCommitEvent),
    Info(RelayInfoEvent),
    Error(RelayErrorEvent),
}

impl RelayEvent {
    /// Returns the sequence number of sequenced events (`None` for `#info` and `#error`).
    pub const fn sequence(&self) -> Option<i64> {
        match self {
            Self::Identity(e) => Some(e.seq),
            Self::Account(e) => Some(e.seq),
            Self::Sync(e) => Some(e.seq),
            Self::Commit(e) => Some(e.seq),
            Self::Info(_) | Self::Error(_) => None,
        }
    }

    /// Returns the repository DID for repo-scoped events.
    pub fn repository_did(&self) -> Option<&str> {
        match self {
            Self::Identity(e) => Some(&e.did),
            Self::Account(e) => Some(&e.did),
            Self::Sync(e) => Some(&e.did),
            Self::Commit(e) => Some(&e.repo),
            Self::Info(_) | Self::Error(_) => None,
        }
    }
}

/// Evidence of a reconnect cursor and first delivered relay sequence.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RelayReconnectEvidence {
    pub upstream_cursor: i64,
    pub first_delivered_relay_sequence: i64,
}

/// Result of sequence verification across a relay capture.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RelaySequenceVerification {
    pub first_sequence: i64,
    pub last_sequence: i64,
    pub offline_commit_count: usize,
}

/// Accepted repository head metadata.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RelayRepositoryHead {
    pub did: String,
    pub revision: String,
    pub commit_cid: Cid,
    pub data_cid: Cid,
}

/// Authenticated snapshot of a repository at a commit.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RelayRepositorySnapshot {
    pub did: String,
    pub revision: String,
    pub commit_cid: Cid,
    pub data_cid: Cid,
    pub records: BTreeMap<String, Cid>,
    pub mst_digest: String,
}

impl RelayRepositorySnapshot {
    pub fn head(&self) -> RelayRepositoryHead {
        RelayRepositoryHead {
            did: self.did.clone(),
            revision: self.revision.clone(),
            commit_cid: self.commit_cid.clone(),
            data_cid: self.data_cid.clone(),
        }
    }
}

/// Kind of CAR payload carried by a repository state transition.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum RelayRepositoryPayloadKind {
    FullSnapshot,
    CommitDiff,
    CommitAnnouncement,
}

impl RelayRepositoryPayloadKind {
    pub const fn is_diff(self) -> bool {
        matches!(self, Self::CommitDiff)
    }
}

/// Mode observed when querying `com.atproto.sync.getRepo`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum RelayGetRepoQueryMode {
    #[serde(rename = "cursor-only")]
    CursorOnly,
    #[serde(rename = "since-rejected")]
    SinceRejected,
    #[serde(rename = "since-observed")]
    SinceObserved,
}

/// Observation of a `getRepo` query during relay verification.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RelayGetRepoObservation {
    pub mode: RelayGetRepoQueryMode,
    #[serde(default)]
    pub full_snapshot_accepted: bool,
    #[serde(default)]
    pub exact_final_state_proven: bool,
}

/// Named check identifiers in a relay verification aggregate.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RelayVerificationCheckName {
    CanonicalFrames,
    OrderedLifecycle,
    CursorRecovery,
    RepositoryCommits,
    GetRepoMode,
    #[serde(rename = "final_mst_equality")]
    FinalMstEquality,
}

/// Outcome of a single named check.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum RelayVerificationCheckOutcome {
    Passed,
    Failed,
}

/// One named check result.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct RelayNamedCheck {
    pub name: RelayVerificationCheckName,
    pub outcome: RelayVerificationCheckOutcome,
}

/// Public summary of a relay verification run (no raw frames, CARs, or proofs).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RelayVerificationAggregate {
    pub did: String,
    pub first_sequence: i64,
    pub last_sequence: i64,
    pub frame_count: usize,
    pub final_revision: String,
    #[serde(rename = "finalCommitCID")]
    pub final_commit_cid: String,
    #[serde(rename = "finalDataCID")]
    pub final_data_cid: String,
    pub projection_digest: String,
    pub checks: Vec<RelayNamedCheck>,
}

/// Validates `1 <= seq <= MAXIMUM_SEQUENCE` returning [`RelayVerifierError::SequenceOutOfRange`].
pub(crate) fn validate_relay_sequence(seq: i64) -> Result<i64, RelayVerifierError> {
    if (1..=FirehoseFrameLimits::MAXIMUM_SEQUENCE).contains(&seq) {
        Ok(seq)
    } else {
        Err(RelayVerifierError::SequenceOutOfRange)
    }
}
