//! Relay commit, repository, sequence, lifecycle, semantic, and accepted-head verification.

use std::collections::{BTreeMap, BTreeSet};
use std::ops::RangeInclusive;
use std::time::Duration;

use async_lock::Mutex;
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync, SystemTime};
use petrel_core::{Cid, Nsid, RecordKey, Tid, cid::BlessedKind};
use sha2::{Digest, Sha256};

use crate::car::{DiffCarBlockReader, ParsedCarArchive};
use crate::limits::FirehoseFrameLimits;
use crate::repo_seam::{
    CANONICAL_EMPTY_MST_CID, RepoCommitVerifier, RepositoryCommitDiffError, RepositoryCommitError,
    RepositoryCommitOperation, RepositoryLimits, RepositoryMstKeySyntax, RepositoryReadPolicy,
    RepositorySigningKeyResolver, VerifiedRepositoryCommitDiff, VerifiedSignedCommit,
    require_rev_not_in_future, structurally_validate_commit, validate_full_mst,
    validate_record_block, verify_commit_with_resolver, verify_commit_with_verifier,
    verify_mst_inversion,
};
use crate::types::{
    RelayCommitEvent, RelayEvent, RelayGetRepoObservation, RelayGetRepoQueryMode,
    RelayReconnectEvidence, RelayRepoAction, RelayRepoOp, RelayRepositoryHead,
    RelayRepositoryPayloadKind, RelayRepositorySnapshot, RelaySequenceVerification, RelaySyncEvent,
    RelayVerifierError,
};

// --- RelayAcceptedHeadStorage ---

/// Storage interface for persisting and loading verified accepted repository heads by DID.
pub trait RelayAcceptedHeadStorage: MaybeSend + MaybeSync {
    fn load_accepted_head<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<Option<RelayRepositoryHead>, RelayVerifierError>>;

    fn save_accepted_head(
        &self,
        head: RelayRepositoryHead,
    ) -> BoxFuture<'_, Result<(), RelayVerifierError>>;
}

/// In-memory [`RelayAcceptedHeadStorage`] enforcing monotonic `Tid` compare-and-set semantics.
#[derive(Debug, Default)]
pub struct InMemoryRelayAcceptedHeadStorage {
    heads: Mutex<BTreeMap<String, RelayRepositoryHead>>,
}

impl InMemoryRelayAcceptedHeadStorage {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn with_initial_heads(heads: BTreeMap<String, RelayRepositoryHead>) -> Self {
        Self {
            heads: Mutex::new(heads),
        }
    }
}

impl RelayAcceptedHeadStorage for InMemoryRelayAcceptedHeadStorage {
    fn load_accepted_head<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<Option<RelayRepositoryHead>, RelayVerifierError>> {
        Box::pin(async move { Ok(self.heads.lock().await.get(did).cloned()) })
    }

    fn save_accepted_head(
        &self,
        head: RelayRepositoryHead,
    ) -> BoxFuture<'_, Result<(), RelayVerifierError>> {
        Box::pin(async move {
            let mut guard = self.heads.lock().await;
            if let Some(existing) = guard.get(&head.did) {
                let existing_tid = Tid::parse(&existing.revision)
                    .map_err(|_| RelayVerifierError::InvalidEventBody)?;
                let incoming_tid =
                    Tid::parse(&head.revision).map_err(|_| RelayVerifierError::InvalidEventBody)?;
                if incoming_tid < existing_tid
                    || (incoming_tid == existing_tid && existing != &head)
                {
                    return Err(RelayVerifierError::RevisionRollback);
                }
            }
            guard.insert(head.did.clone(), head);
            Ok(())
        })
    }
}

// --- RelayCommitVerification (event-level self-contained verify) ---

impl RelayCommitEvent {
    /// Converts the event's operations into typed [`RepositoryCommitOperation`]s.
    pub fn repository_operations(
        &self,
        key_syntax: RepositoryMstKeySyntax,
    ) -> Result<Vec<RepositoryCommitOperation>, RepositoryCommitDiffError> {
        self.ops
            .iter()
            .map(|op| op.repository_operation(key_syntax))
            .collect()
    }

    /// Verifies this `#commit` event from its own fields (signature, revision clock skew,
    /// MST inversion to `prevData`, and record block CIDs/schemas).
    pub async fn verify(
        &self,
        key_resolver: &dyn RepositorySigningKeyResolver,
        limits: &RepositoryLimits,
        policy: RepositoryReadPolicy,
        now: SystemTime,
        maximum_clock_skew: Duration,
    ) -> Result<VerifiedRepositoryCommitDiff, RepositoryCommitDiffError> {
        let Some(prev_data_cid) = &self.prev_data_cid else {
            return Err(RepositoryCommitDiffError::MissingPreviousData);
        };
        require_rev_not_in_future(&self.rev, now, maximum_clock_skew)?;

        let operations = self.repository_operations(RepositoryMstKeySyntax::RepositoryPath)?;
        if operations.len() > limits.maximum_writes {
            return Err(RepositoryCommitDiffError::TooManyOperations {
                count: operations.len(),
                limit: limits.maximum_writes,
            });
        }
        if self.blocks.len() > limits.maximum_relevant_block_bytes {
            return Err(RepositoryCommitDiffError::BlocksTooLarge {
                byte_count: self.blocks.len(),
                limit: limits.maximum_relevant_block_bytes,
            });
        }

        let car = ParsedCarArchive::parse(&self.blocks, limits.maximum_car_bytes, false)
            .map_err(|_| RepositoryCommitDiffError::MalformedBlocks)?;
        if car.root_cid() != &self.commit_cid {
            return Err(RepositoryCommitDiffError::RootMismatch {
                root: car.root_cid().clone(),
                commit: self.commit_cid.clone(),
            });
        }
        let Some(commit_bytes) = car.block_bytes(&self.commit_cid) else {
            return Err(RepositoryCommitDiffError::MissingCommit);
        };
        let commit = verify_commit_with_resolver(
            commit_bytes,
            &self.commit_cid,
            key_resolver,
            Some(&self.repo),
        )
        .await?;

        let mst_syntax = RepositoryMstKeySyntax::RepositoryPath;
        verify_mst_inversion(
            &commit.descriptor.data_cid,
            &operations,
            prev_data_cid,
            &car,
            limits,
            mst_syntax,
        )
        .await?;

        for op in &operations {
            let Some(cid) = op.record_cid() else {
                continue;
            };
            if cid.blessed_kind() != Some(BlessedKind::DagCbor) {
                continue;
            }
            let Some(bytes) = car.block_bytes(cid) else {
                return Err(RepositoryCommitDiffError::MissingRecord(
                    op.path().to_owned(),
                ));
            };
            if !cid.matches_content(bytes) || bytes.len() > limits.maximum_record_block_bytes {
                return Err(RepositoryCommitDiffError::InvalidRecord(
                    op.path().to_owned(),
                ));
            }
            let Some((collection, _)) = op.path().split_once('/') else {
                return Err(RepositoryCommitDiffError::InvalidRecord(
                    op.path().to_owned(),
                ));
            };
            validate_record_block(bytes, collection, policy)
                .map_err(|()| RepositoryCommitDiffError::InvalidRecord(op.path().to_owned()))?;
        }

        if commit.descriptor.revision != self.rev {
            return Err(RepositoryCommitDiffError::RevisionMismatch {
                event: self.rev.clone(),
                commit: commit.descriptor.revision,
            });
        }

        Ok(VerifiedRepositoryCommitDiff {
            commit,
            operations,
            previous_data_cid: prev_data_cid.clone(),
        })
    }
}

impl RelaySyncEvent {
    /// Verifies this `#sync` event (commit signature, DID, revision, clock skew).
    pub async fn verify(
        &self,
        key_resolver: &dyn RepositorySigningKeyResolver,
        limits: &RepositoryLimits,
        now: SystemTime,
        maximum_clock_skew: Duration,
    ) -> Result<VerifiedSignedCommit, RepositoryCommitDiffError> {
        require_rev_not_in_future(&self.rev, now, maximum_clock_skew)?;
        let car = ParsedCarArchive::parse(&self.blocks, limits.maximum_car_bytes, false)
            .map_err(|_| RepositoryCommitDiffError::MalformedBlocks)?;
        let Some(commit_bytes) = car.block_bytes(car.root_cid()) else {
            return Err(RepositoryCommitDiffError::MissingCommit);
        };
        let commit = verify_commit_with_resolver(
            commit_bytes,
            car.root_cid(),
            key_resolver,
            Some(&self.did),
        )
        .await?;
        if commit.descriptor.revision != self.rev {
            return Err(RepositoryCommitDiffError::RevisionMismatch {
                event: self.rev.clone(),
                commit: commit.descriptor.revision,
            });
        }
        Ok(commit)
    }
}

// --- RelayFullRepositoryVerifier & RelayRepositoryVerificationState ---

/// Verified full-repository snapshot and record projection.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RelayVerifiedFullRepository {
    pub snapshot: RelayRepositorySnapshot,
    pub records: BTreeMap<String, Cid>,
}

impl RelayVerifiedFullRepository {
    pub fn head(&self) -> RelayRepositoryHead {
        self.snapshot.head()
    }
}

/// Full-repository CAR inspection and authenticated verification.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RelayFullRepositoryVerifier;

impl RelayFullRepositoryVerifier {
    /// Structurally inspects a self-contained CAR without checking signatures.
    pub async fn inspect(car: &[u8]) -> Result<RelayRepositorySnapshot, RelayVerifierError> {
        let limits = RepositoryLimits::STANDARD;
        if car.len() > limits.maximum_car_bytes {
            return Err(RelayVerifierError::RepositoryCarTooLarge);
        }
        let parsed = ParsedCarArchive::parse(car, limits.maximum_car_bytes, true)?;
        let root_cid = parsed.root_cid().clone();
        let commit_bytes = parsed
            .block_bytes(&root_cid)
            .ok_or(RelayVerifierError::InvalidRepositoryCar)?;
        let commit = structurally_validate_commit(commit_bytes, &root_cid)
            .map_err(|e| map_commit_error(&e))?;
        let mst = validate_full_mst(
            &commit.descriptor.data_cid,
            &parsed,
            &limits,
            RepositoryReadPolicy::Strict,
            limits.maximum_car_bytes,
        )
        .await?;

        for cid in mst.mst_blocks.keys().chain(mst.record_cids.iter()) {
            if parsed.block_bytes(cid).is_none() {
                return Err(RelayVerifierError::InvalidRepositoryCar);
            }
        }

        Ok(RelayRepositorySnapshot {
            did: commit.descriptor.did,
            revision: commit.descriptor.revision,
            commit_cid: root_cid,
            data_cid: commit.descriptor.data_cid,
            records: mst.records,
            mst_digest: RelayRepositoryVerificationState::mst_digest(&mst.mst_blocks),
        })
    }

    /// Authenticates a full repository CAR against `expected`, `verifier`, and `storage`.
    pub async fn verify(
        car: &[u8],
        expected: &RelayRepositoryHead,
        verifier: &dyn RepoCommitVerifier,
        storage: &dyn RelayAcceptedHeadStorage,
        maximum_car_bytes: usize,
    ) -> Result<RelayVerifiedFullRepository, RelayVerifierError> {
        let state = RelayRepositoryVerificationState::full_snapshot(
            car,
            expected,
            verifier,
            storage,
            maximum_car_bytes,
        )
        .await?;
        let records = state.snapshot.records.clone();
        Ok(RelayVerifiedFullRepository {
            snapshot: state.snapshot,
            records,
        })
    }
}

/// Authenticated repository state retained while a relay capture is verified.
#[derive(Debug, Clone)]
pub struct RelayRepositoryVerificationState {
    pub snapshot: RelayRepositorySnapshot,
    pub payload_kind: RelayRepositoryPayloadKind,
    reachable_blocks: BTreeMap<Cid, Vec<u8>>,
}

impl RelayRepositoryVerificationState {
    pub async fn full_snapshot(
        car: &[u8],
        expected: &RelayRepositoryHead,
        verifier: &dyn RepoCommitVerifier,
        storage: &dyn RelayAcceptedHeadStorage,
        maximum_car_bytes: usize,
    ) -> Result<Self, RelayVerifierError> {
        if let Some(accepted) = storage.load_accepted_head(&expected.did).await? {
            let accepted_tid =
                Tid::parse(&accepted.revision).map_err(|_| RelayVerifierError::InvalidEventBody)?;
            let expected_tid =
                Tid::parse(&expected.revision).map_err(|_| RelayVerifierError::InvalidEventBody)?;
            if accepted_tid >= expected_tid {
                return Err(RelayVerifierError::RevisionRollback);
            }
        }

        let (snapshot, reachable) = Self::verify_car(
            car,
            Some(&expected.commit_cid),
            Some(&expected.did),
            &BTreeMap::new(),
            true,
            verifier,
            maximum_car_bytes,
        )
        .await?;

        let actual = snapshot.head();
        if actual.did != expected.did {
            return Err(RelayVerifierError::RepositoryDidMismatch);
        }
        if actual.revision != expected.revision {
            return Err(RelayVerifierError::CommitRevisionMismatch);
        }
        if actual.commit_cid != expected.commit_cid {
            return Err(RelayVerifierError::CommitCidMismatch);
        }
        if actual.data_cid != expected.data_cid {
            return Err(RelayVerifierError::FinalDataCidMismatch);
        }

        storage.save_accepted_head(actual).await?;
        Ok(Self {
            snapshot,
            payload_kind: RelayRepositoryPayloadKind::FullSnapshot,
            reachable_blocks: reachable,
        })
    }

    pub async fn activation_sync(
        event: &RelaySyncEvent,
        verifier: &dyn RepoCommitVerifier,
        storage: &dyn RelayAcceptedHeadStorage,
    ) -> Result<Self, RelayVerifierError> {
        if let Some(accepted) = storage.load_accepted_head(&event.did).await? {
            let accepted_tid =
                Tid::parse(&accepted.revision).map_err(|_| RelayVerifierError::InvalidEventBody)?;
            let event_tid =
                Tid::parse(&event.rev).map_err(|_| RelayVerifierError::InvalidEventBody)?;
            if accepted_tid >= event_tid {
                return Err(RelayVerifierError::RevisionRollback);
            }
        }
        let commit = verify_commit_announcement(event, verifier).await?;
        if commit.descriptor.did != event.did {
            return Err(RelayVerifierError::RepositoryDidMismatch);
        }
        if commit.descriptor.revision != event.rev {
            return Err(RelayVerifierError::CommitRevisionMismatch);
        }
        let empty_cid = Cid::parse(CANONICAL_EMPTY_MST_CID)
            .map_err(|_| RelayVerifierError::InvalidRepositoryCar)?;
        if commit.descriptor.data_cid != empty_cid {
            return Err(RelayVerifierError::InvalidRepositoryCar);
        }
        let empty_mst_bytes = canonical_empty_mst_bytes();
        let mut mst_blocks = BTreeMap::new();
        mst_blocks.insert(empty_cid.clone(), empty_mst_bytes.clone());
        let snapshot = RelayRepositorySnapshot {
            did: event.did.clone(),
            revision: event.rev.clone(),
            commit_cid: commit.commit_cid.clone(),
            data_cid: empty_cid.clone(),
            records: BTreeMap::new(),
            mst_digest: Self::mst_digest(&mst_blocks),
        };
        storage.save_accepted_head(snapshot.head()).await?;

        let mut reachable = BTreeMap::new();
        reachable.insert(commit.commit_cid, commit.signed_commit_bytes);
        reachable.insert(empty_cid, empty_mst_bytes);
        Ok(Self {
            snapshot,
            payload_kind: RelayRepositoryPayloadKind::CommitAnnouncement,
            reachable_blocks: reachable,
        })
    }

    pub async fn synchronizing(
        &self,
        event: &RelaySyncEvent,
        verifier: &dyn RepoCommitVerifier,
        storage: &dyn RelayAcceptedHeadStorage,
    ) -> Result<Self, RelayVerifierError> {
        if let Some(accepted) = storage.load_accepted_head(&event.did).await? {
            let accepted_tid =
                Tid::parse(&accepted.revision).map_err(|_| RelayVerifierError::InvalidEventBody)?;
            let event_tid =
                Tid::parse(&event.rev).map_err(|_| RelayVerifierError::InvalidEventBody)?;
            if accepted_tid > event_tid {
                return Err(RelayVerifierError::RevisionRollback);
            }
            if accepted_tid == event_tid
                && (accepted.commit_cid != self.snapshot.commit_cid
                    || accepted.data_cid != self.snapshot.data_cid)
            {
                return Err(RelayVerifierError::RevisionRollback);
            }
        }
        let commit = verify_commit_announcement(event, verifier).await?;
        if commit.descriptor.did != event.did || event.did != self.snapshot.did {
            return Err(RelayVerifierError::RepositoryDidMismatch);
        }
        if commit.descriptor.revision != event.rev || event.rev != self.snapshot.revision {
            return Err(RelayVerifierError::CommitRevisionMismatch);
        }
        if commit.commit_cid != self.snapshot.commit_cid {
            return Err(RelayVerifierError::CommitCidMismatch);
        }
        if commit.descriptor.data_cid != self.snapshot.data_cid {
            return Err(RelayVerifierError::FinalDataCidMismatch);
        }
        storage.save_accepted_head(self.snapshot.head()).await?;
        Ok(Self {
            snapshot: self.snapshot.clone(),
            payload_kind: RelayRepositoryPayloadKind::CommitAnnouncement,
            reachable_blocks: self.reachable_blocks.clone(),
        })
    }

    pub async fn applying_commit(
        &self,
        event: &RelayCommitEvent,
        verifier: &dyn RepoCommitVerifier,
        storage: &dyn RelayAcceptedHeadStorage,
    ) -> Result<Self, RelayVerifierError> {
        if event.repo != self.snapshot.did {
            return Err(RelayVerifierError::RepositoryDidMismatch);
        }
        if let Some(accepted) = storage.load_accepted_head(&event.repo).await? {
            let accepted_tid =
                Tid::parse(&accepted.revision).map_err(|_| RelayVerifierError::InvalidEventBody)?;
            let event_tid =
                Tid::parse(&event.rev).map_err(|_| RelayVerifierError::InvalidEventBody)?;
            if accepted_tid >= event_tid {
                return Err(RelayVerifierError::RevisionRollback);
            }
        }
        if event.blocks.len() > FirehoseFrameLimits::MAXIMUM_COMMIT_BLOCKS_BYTES {
            return Err(RelayVerifierError::CommitBlocksTooLarge);
        }
        let (snapshot, reachable) = Self::verify_car(
            &event.blocks,
            Some(&event.commit_cid),
            Some(&event.repo),
            &self.reachable_blocks,
            false,
            verifier,
            FirehoseFrameLimits::MAXIMUM_COMMIT_BLOCKS_BYTES,
        )
        .await?;
        RelayCommitSemanticVerifier::verify(event, &self.snapshot, &snapshot)?;
        storage.save_accepted_head(snapshot.head()).await?;
        Ok(Self {
            snapshot,
            payload_kind: RelayRepositoryPayloadKind::CommitDiff,
            reachable_blocks: reachable,
        })
    }

    async fn verify_car(
        car: &[u8],
        expected_root: Option<&Cid>,
        expected_did: Option<&str>,
        previous_blocks: &BTreeMap<Cid, Vec<u8>>,
        require_self_contained: bool,
        verifier: &dyn RepoCommitVerifier,
        maximum_car_bytes: usize,
    ) -> Result<(RelayRepositorySnapshot, BTreeMap<Cid, Vec<u8>>), RelayVerifierError> {
        if maximum_car_bytes == 0 || car.len() > maximum_car_bytes {
            return Err(RelayVerifierError::RepositoryCarTooLarge);
        }
        let parsed = ParsedCarArchive::parse(car, maximum_car_bytes, true)?;
        let root = parsed.root_cid().clone();
        if let Some(expected_root) = expected_root
            && &root != expected_root
        {
            return Err(RelayVerifierError::CommitCidMismatch);
        }
        let diff_blocks = parsed.into_block_map();
        let commit_bytes = diff_blocks
            .get(&root)
            .ok_or(RelayVerifierError::InvalidRepositoryCar)?
            .clone();

        let mut merged = previous_blocks.clone();
        for (cid, bytes) in &diff_blocks {
            if let Some(existing) = merged.get(cid)
                && existing != bytes
            {
                return Err(RelayVerifierError::InvalidRepositoryCar);
            }
            merged.insert(cid.clone(), bytes.clone());
        }

        let commit = verify_commit_with_verifier(&commit_bytes, &root, verifier, expected_did)
            .await
            .map_err(|e| map_commit_error(&e))?;

        let limits = RepositoryLimits::STANDARD;
        let mst = validate_full_mst(
            &commit.descriptor.data_cid,
            &merged,
            &limits,
            RepositoryReadPolicy::Strict,
            limits.maximum_car_bytes,
        )
        .await?;

        if require_self_contained {
            if !diff_blocks.contains_key(&root) {
                return Err(RelayVerifierError::InvalidRepositoryCar);
            }
            for cid in mst.mst_blocks.keys().chain(mst.record_cids.iter()) {
                if !diff_blocks.contains_key(cid) {
                    return Err(RelayVerifierError::InvalidRepositoryCar);
                }
            }
        }

        let mut reachable = BTreeMap::new();
        reachable.insert(root.clone(), commit_bytes);
        for cid in mst.mst_blocks.keys().chain(mst.record_cids.iter()) {
            let bytes = merged
                .get(cid)
                .ok_or(RelayVerifierError::InvalidRepositoryCar)?;
            reachable.insert(cid.clone(), bytes.clone());
        }

        let snapshot = RelayRepositorySnapshot {
            did: commit.descriptor.did,
            revision: commit.descriptor.revision,
            commit_cid: root,
            data_cid: commit.descriptor.data_cid,
            records: mst.records,
            mst_digest: Self::mst_digest(&mst.mst_blocks),
        };
        Ok((snapshot, reachable))
    }

    pub fn mst_digest(blocks: &BTreeMap<Cid, Vec<u8>>) -> String {
        let mut sorted: Vec<(&Cid, String, &[u8])> = blocks
            .iter()
            .map(|(cid, bytes)| (cid, cid.to_string(), bytes.as_slice()))
            .collect();
        sorted.sort_by(|a, b| a.1.cmp(&b.1));
        let mut hasher = Sha256::new();
        for (cid, _, bytes) in sorted {
            hasher.update(cid.as_bytes());
            hasher.update(bytes);
        }
        format!("sha256:{}", hex_lower(&hasher.finalize()))
    }
}

async fn verify_commit_announcement(
    event: &RelaySyncEvent,
    verifier: &dyn RepoCommitVerifier,
) -> Result<VerifiedSignedCommit, RelayVerifierError> {
    if event.blocks.len() > FirehoseFrameLimits::MAXIMUM_SYNC_BLOCKS_BYTES {
        return Err(RelayVerifierError::SyncBlocksTooLarge);
    }
    let parsed = ParsedCarArchive::parse(
        &event.blocks,
        FirehoseFrameLimits::MAXIMUM_SYNC_BLOCKS_BYTES,
        true,
    )?;
    if parsed.blocks().len() != 1 {
        return Err(RelayVerifierError::InvalidRepositoryCar);
    }
    let root = parsed.root_cid().clone();
    let commit_bytes = parsed
        .block_bytes(&root)
        .ok_or(RelayVerifierError::InvalidRepositoryCar)?;
    verify_commit_with_verifier(commit_bytes, &root, verifier, Some(&event.did))
        .await
        .map_err(|e| map_commit_error(&e))
}

/// Digest over the final sorted `(path, record_cid)` projection.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RelayRepositoryDigest;

impl RelayRepositoryDigest {
    pub fn projection(records: &BTreeMap<String, Cid>) -> String {
        let mut hasher = Sha256::new();
        for (path, cid) in records {
            hasher.update(path.as_bytes());
            hasher.update([0u8]);
            hasher.update(cid.as_bytes());
        }
        format!("sha256:{}", hex_lower(&hasher.finalize()))
    }
}

fn map_commit_error(err: &RepositoryCommitError) -> RelayVerifierError {
    match err {
        RepositoryCommitError::InvalidSignature => RelayVerifierError::InvalidCommitSignature,
        RepositoryCommitError::DidMismatch => RelayVerifierError::RepositoryDidMismatch,
        _ => RelayVerifierError::InvalidRepositoryCar,
    }
}

fn canonical_empty_mst_bytes() -> Vec<u8> {
    let mut map = BTreeMap::new();
    map.insert("l".to_owned(), petrel_core::Value::Null);
    map.insert("e".to_owned(), petrel_core::Value::Array(Vec::new()));
    petrel_core::dagcbor::encode(&petrel_core::Value::Object(map))
}

fn hex_lower(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for &b in bytes {
        out.push(char::from(HEX[(b >> 4) as usize]));
        out.push(char::from(HEX[(b & 0x0f) as usize]));
    }
    out
}

// --- Semantic Verifiers ---

/// Verifies contiguous sequence numbers, reconnect cursors, and offline commit ranges.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RelaySequenceVerifier;

impl RelaySequenceVerifier {
    pub fn verify(
        events: &[RelayEvent],
        reconnects: &[RelayReconnectEvidence],
        offline_commit_range: Option<RangeInclusive<i64>>,
        expected_offline_commit_count: usize,
    ) -> Result<RelaySequenceVerification, RelayVerifierError> {
        let sequenced: Vec<(i64, &RelayEvent)> = events
            .iter()
            .filter_map(|e| e.sequence().map(|seq| (seq, e)))
            .collect();
        let (Some(first), Some(last)) = (sequenced.first(), sequenced.last()) else {
            return Err(RelayVerifierError::InvalidEventBody);
        };
        let mut prev: Option<i64> = None;
        let mut seen = BTreeSet::new();
        for &(seq, _) in &sequenced {
            if !seen.insert(seq) {
                return Err(RelayVerifierError::DuplicateSequence);
            }
            if let Some(p) = prev
                && seq != p + 1
            {
                return Err(RelayVerifierError::SequenceGap);
            }
            prev = Some(seq);
        }
        for reconnect in reconnects {
            if reconnect.upstream_cursor < 0
                || reconnect.upstream_cursor > FirehoseFrameLimits::MAXIMUM_SEQUENCE
                || !seen.contains(&reconnect.first_delivered_relay_sequence)
            {
                return Err(RelayVerifierError::ReconnectCursorOutOfBounds);
            }
        }
        let offline_commit_count = if let Some(range) = offline_commit_range {
            let ranged: Vec<_> = sequenced
                .iter()
                .filter(|(seq, _)| range.contains(seq))
                .collect();
            let count = ranged
                .iter()
                .filter(|(_, ev)| matches!(ev, RelayEvent::Commit(_)))
                .count();
            let range_len =
                usize::try_from(*range.end() - *range.start() + 1).unwrap_or(usize::MAX);
            if ranged.len() != range_len || count != expected_offline_commit_count {
                return Err(RelayVerifierError::OfflineCommitCountMismatch);
            }
            if !reconnects
                .iter()
                .any(|r| r.first_delivered_relay_sequence == *range.start())
            {
                return Err(RelayVerifierError::ReconnectCursorOutOfBounds);
            }
            count
        } else {
            0
        };
        Ok(RelaySequenceVerification {
            first_sequence: first.0,
            last_sequence: last.0,
            offline_commit_count,
        })
    }
}

/// Verifies repository lifecycle ordering (`#identity` -> active `#account` -> `#sync` -> ops).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RelayLifecycleVerifier;

impl RelayLifecycleVerifier {
    pub fn verify(
        events: &[RelayEvent],
        expected_did: Option<&str>,
    ) -> Result<(), RelayVerifierError> {
        #[derive(PartialEq, Eq)]
        enum Stage {
            Initial,
            Identity,
            Account,
            Synchronized,
        }
        let mut stage = Stage::Initial;
        let mut did = expected_did.map(str::to_owned);
        for event in events {
            let Some(event_did) = event.repository_did() else {
                continue;
            };
            if let Some(existing) = &did {
                if existing != event_did {
                    return Err(RelayVerifierError::RepositoryDidMismatch);
                }
            } else {
                did = Some(event_did.to_owned());
            }
            match (&stage, event) {
                (Stage::Initial, RelayEvent::Identity(_)) => stage = Stage::Identity,
                (Stage::Identity, RelayEvent::Account(acc))
                    if acc.active && acc.status.is_none() =>
                {
                    stage = Stage::Account;
                }
                (Stage::Account, RelayEvent::Sync(_)) => stage = Stage::Synchronized,
                (
                    Stage::Synchronized,
                    RelayEvent::Identity(_)
                    | RelayEvent::Account(_)
                    | RelayEvent::Sync(_)
                    | RelayEvent::Commit(_),
                ) => {}
                _ => return Err(RelayVerifierError::LifecycleOrderMismatch),
            }
        }
        if stage != Stage::Synchronized {
            return Err(RelayVerifierError::LifecycleOrderMismatch);
        }
        Ok(())
    }
}

/// Verifies that a `#commit` event's metadata and `ops` match the delta between snapshots.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RelayCommitSemanticVerifier;

impl RelayCommitSemanticVerifier {
    pub fn verify(
        event: &RelayCommitEvent,
        previous: &RelayRepositorySnapshot,
        current: &RelayRepositorySnapshot,
    ) -> Result<(), RelayVerifierError> {
        if event.repo != previous.did || event.repo != current.did {
            return Err(RelayVerifierError::RepositoryDidMismatch);
        }
        if event.rev != current.revision {
            return Err(RelayVerifierError::CommitRevisionMismatch);
        }
        if event.commit_cid != current.commit_cid {
            return Err(RelayVerifierError::CommitCidMismatch);
        }
        if event.since.as_deref() != Some(previous.revision.as_str()) {
            return Err(RelayVerifierError::SinceRevisionMismatch);
        }
        if event.prev_data_cid.as_ref() != Some(&previous.data_cid) {
            return Err(RelayVerifierError::PreviousDataCidMismatch);
        }
        let Ok(prev_tid) = Tid::parse(&previous.revision) else {
            return Err(RelayVerifierError::RevisionRollback);
        };
        let Ok(cur_tid) = Tid::parse(&current.revision) else {
            return Err(RelayVerifierError::RevisionRollback);
        };
        if prev_tid >= cur_tid {
            return Err(RelayVerifierError::RevisionRollback);
        }
        let expected = expected_delta(&previous.records, &current.records)?;
        if event.ops != expected {
            return Err(RelayVerifierError::RepositoryDeltaMismatch);
        }
        Ok(())
    }
}

fn expected_delta(
    previous: &BTreeMap<String, Cid>,
    current: &BTreeMap<String, Cid>,
) -> Result<Vec<RelayRepoOp>, RelayVerifierError> {
    let mut keys: BTreeSet<&str> = BTreeSet::new();
    for k in previous.keys().chain(current.keys()) {
        keys.insert(k.as_str());
    }
    let mut ops = Vec::new();
    for path in keys {
        let Some((collection, rkey)) = path.split_once('/') else {
            return Err(RelayVerifierError::RepositoryDeltaMismatch);
        };
        if Nsid::parse(collection).is_err() || RecordKey::parse(rkey).is_err() {
            return Err(RelayVerifierError::RepositoryDeltaMismatch);
        }
        match (previous.get(path), current.get(path)) {
            (None, Some(cur)) => ops.push(RelayRepoOp {
                action: RelayRepoAction::Create,
                path: path.to_owned(),
                cid: Some(cur.clone()),
                prev: None,
            }),
            (Some(prev), None) => ops.push(RelayRepoOp {
                action: RelayRepoAction::Delete,
                path: path.to_owned(),
                cid: None,
                prev: Some(prev.clone()),
            }),
            (Some(prev), Some(cur)) if prev != cur => ops.push(RelayRepoOp {
                action: RelayRepoAction::Update,
                path: path.to_owned(),
                cid: Some(cur.clone()),
                prev: Some(prev.clone()),
            }),
            _ => {}
        }
    }
    Ok(ops)
}

/// Fail-closed policy check for `getRepo` observations.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RelayGetRepoPolicy;

impl RelayGetRepoPolicy {
    pub fn verify(
        observation: &RelayGetRepoObservation,
    ) -> Result<RelayGetRepoQueryMode, RelayVerifierError> {
        match observation.mode {
            RelayGetRepoQueryMode::CursorOnly | RelayGetRepoQueryMode::SinceRejected => {
                Ok(observation.mode)
            }
            RelayGetRepoQueryMode::SinceObserved => {
                if !observation.full_snapshot_accepted || !observation.exact_final_state_proven {
                    return Err(RelayVerifierError::SinceObservedNotProven);
                }
                Ok(RelayGetRepoQueryMode::SinceObserved)
            }
        }
    }
}

/// Compares a relay's final snapshot against a reference PDS snapshot.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RelayFinalStateVerifier;

impl RelayFinalStateVerifier {
    pub fn verify(
        relay: &RelayRepositorySnapshot,
        reference: &RelayRepositorySnapshot,
    ) -> Result<(), RelayVerifierError> {
        if relay.did != reference.did {
            return Err(RelayVerifierError::RepositoryDidMismatch);
        }
        if relay.revision != reference.revision {
            return Err(RelayVerifierError::FinalRevisionMismatch);
        }
        if relay.commit_cid != reference.commit_cid {
            return Err(RelayVerifierError::FinalCommitCidMismatch);
        }
        if relay.data_cid != reference.data_cid {
            return Err(RelayVerifierError::FinalDataCidMismatch);
        }
        if relay.records != reference.records {
            return Err(RelayVerifierError::FinalProjectionMismatch);
        }
        if relay.mst_digest != reference.mst_digest {
            return Err(RelayVerifierError::FinalMstMismatch);
        }
        Ok(())
    }
}
