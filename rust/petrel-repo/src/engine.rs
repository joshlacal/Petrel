use std::collections::BTreeMap;
use std::sync::Arc;

use petrel_core::Cid;

use crate::block_store::{BlockStore, RepositoryBlock};
use crate::car::PublicRepositoryCAR;
use crate::commit::{CommitCodec, CommitDescriptor, PreparedSignedCommit};
use crate::crypto::CommitSigner;
use crate::diff::CommitOperation;
use crate::error::{EngineError, LimitError, LimitKind};
use crate::genesis::GenesisCodec;
use crate::limits::RepositoryLimits;
use crate::mst::{MstOptions, RepositoryMst};
use crate::record::RecordCodec;
use crate::types::{RepositoryReadPolicy, RepositoryState, RepositoryTid, WriteBatch, WriteOp};

/// Pre-signed mutation bundle computed by [`RepositoryEngine`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PreparedMutation {
    pub state: RepositoryState,
    pub commit: PreparedSignedCommit,
    pub previous_data_cid: Option<Cid>,
    pub new_blocks: Vec<RepositoryBlock>,
    pub proof_blocks: Vec<RepositoryBlock>,
    pub operations: Vec<CommitOperation>,
}

/// Persisted result of [`RepositoryEngine::apply`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RepositoryMutationResult {
    pub state: RepositoryState,
    pub commit: PreparedSignedCommit,
    pub previous_data_cid: Option<Cid>,
    pub new_blocks: Vec<RepositoryBlock>,
    pub proof_blocks: Vec<RepositoryBlock>,
    pub operations: Vec<CommitOperation>,
}

impl RepositoryMutationResult {
    /// Encodes the commit diff CAR (`commit` + new/proof MST nodes + new records)
    /// suitable for firehose `#commit` `blocks` or `CommitDiff::verify_commit_event`.
    pub fn diff_car(&self) -> Result<Vec<u8>, crate::error::CARError> {
        let mut all: BTreeMap<Cid, Vec<u8>> = BTreeMap::new();
        all.insert(
            self.commit.cid.clone(),
            self.commit.signed_commit_bytes.clone(),
        );
        for b in &self.new_blocks {
            all.insert(b.cid.clone(), b.bytes.clone());
        }
        for b in &self.proof_blocks {
            all.insert(b.cid.clone(), b.bytes.clone());
        }
        let mut ordered = Vec::with_capacity(all.len());
        if let Some(commit_bytes) = all.remove(&self.commit.cid) {
            ordered.push(RepositoryBlock::new(self.commit.cid.clone(), commit_bytes));
        }
        if let Some(mst_root) = all.remove(&self.commit.data_cid) {
            ordered.push(RepositoryBlock::new(self.commit.data_cid.clone(), mst_root));
        }
        for (cid, bytes) in all {
            ordered.push(RepositoryBlock::new(cid, bytes));
        }
        PublicRepositoryCAR::write(std::slice::from_ref(&self.commit.cid), &ordered)
    }
}

/// Transactional repository write engine (`PublicRepositoryEngine`).
#[derive(Debug, Clone, Copy, Default)]
pub struct RepositoryEngine;

impl RepositoryEngine {
    /// Validates, applies, signs, and persists `writes` on top of `state`,
    /// producing the next [`RepositoryState`], signed commit, new/proof blocks,
    /// and [`CommitOperation`] list.
    #[allow(clippy::too_many_arguments, clippy::too_many_lines)]
    pub async fn apply<B: BlockStore + 'static>(
        state: &RepositoryState,
        writes: &WriteBatch,
        expected_head_commit: Option<&Cid>,
        rev: RepositoryTid,
        signer: &dyn CommitSigner,
        store: Arc<B>,
        limits: &RepositoryLimits,
        policy: &RepositoryReadPolicy,
    ) -> Result<RepositoryMutationResult, EngineError> {
        limits.validate()?;
        if state.signing_key_generation == 0 {
            return Err(EngineError::InvalidSigningKeyGeneration(
                state.signing_key_generation,
            ));
        }
        if expected_head_commit != state.head_commit_cid.as_ref() {
            return Err(EngineError::CommitMismatch {
                expected: expected_head_commit.cloned(),
                actual: state.head_commit_cid.clone(),
            });
        }
        if let Some(prev_rev) = &state.rev
            && &rev <= prev_rev
        {
            return Err(EngineError::Domain(
                crate::error::DomainError::NonIncreasingRevision {
                    previous: prev_rev.as_str().to_owned(),
                    next: rev.as_str().to_owned(),
                },
            ));
        }

        if writes.len() > limits.max_writes_per_commit {
            return Err(EngineError::Limit(LimitError::Exceeded {
                kind: LimitKind::WritesPerCommit,
                observed: writes.len(),
                limit: limits.max_writes_per_commit,
            }));
        }

        // Canonicalize & validate all write records up front.
        let mut canonical_writes = Vec::with_capacity(writes.len());
        let mut record_blocks: BTreeMap<Cid, Vec<u8>> = BTreeMap::new();
        for op in writes.writes() {
            match op {
                WriteOp::Create { path, record_cbor } => {
                    let record = RecordCodec::validate_record_bytes(
                        record_cbor,
                        Some(path.collection()),
                        policy,
                    )?;
                    let canonical_bytes = record.to_dag_cbor();
                    if canonical_bytes.len() > limits.max_single_block_bytes {
                        return Err(EngineError::Limit(LimitError::Exceeded {
                            kind: LimitKind::SingleBlockBytes,
                            observed: canonical_bytes.len(),
                            limit: limits.max_single_block_bytes,
                        }));
                    }
                    let cid = Cid::for_dag_cbor(&canonical_bytes);
                    record_blocks.insert(cid, canonical_bytes.clone());
                    canonical_writes.push(WriteOp::Create {
                        path: path.clone(),
                        record_cbor: canonical_bytes,
                    });
                }
                WriteOp::Update { path, record_cbor } => {
                    let record = RecordCodec::validate_record_bytes(
                        record_cbor,
                        Some(path.collection()),
                        policy,
                    )?;
                    let canonical_bytes = record.to_dag_cbor();
                    if canonical_bytes.len() > limits.max_single_block_bytes {
                        return Err(EngineError::Limit(LimitError::Exceeded {
                            kind: LimitKind::SingleBlockBytes,
                            observed: canonical_bytes.len(),
                            limit: limits.max_single_block_bytes,
                        }));
                    }
                    let cid = Cid::for_dag_cbor(&canonical_bytes);
                    record_blocks.insert(cid, canonical_bytes.clone());
                    canonical_writes.push(WriteOp::Update {
                        path: path.clone(),
                        record_cbor: canonical_bytes,
                    });
                }
                WriteOp::Delete { path } => {
                    canonical_writes.push(WriteOp::Delete { path: path.clone() });
                }
            }
        }

        let previous_data_cid = state.head_data_cid.clone();
        let mst_options = MstOptions {
            key_syntax: crate::mst::MstKeySyntax::StrictAtProto,
            policy: *policy,
            require_canonical_prefix: true,
            max_depth: limits.max_mst_depth,
            max_node_count: limits.max_mst_node_count,
            max_single_block_bytes: limits.max_single_block_bytes,
        };

        let mut mst = match &previous_data_cid {
            Some(root) => {
                RepositoryMst::open_with_options(root.clone(), Arc::clone(&store) as _, mst_options)
            }
            None => RepositoryMst::empty_with_options(mst_options),
        };

        let (new_data_cid, mst_diff) = mst.apply_writes(&canonical_writes).await?;

        let touched_keys: Vec<String> = canonical_writes
            .iter()
            .map(|w| w.path().mst_key().to_owned())
            .collect();

        // Collect newly created MST blocks and covering proof blocks for inversion/firehose.
        let new_mst_blocks = mst.new_blocks_since(previous_data_cid.as_ref()).await?;
        let new_covering_map = mst.covering_proof_blocks(&touched_keys).await?;

        let mut prev_covering_map = BTreeMap::new();
        if let Some(prev_root) = &previous_data_cid {
            let mut prev_mst = RepositoryMst::open_with_options(
                prev_root.clone(),
                Arc::clone(&store) as _,
                mst_options,
            );
            prev_covering_map = prev_mst.covering_proof_blocks(&touched_keys).await?;
        } else {
            let empty_cid = GenesisCodec::canonical_empty_mst_cid();
            prev_covering_map.insert(
                empty_cid,
                crate::genesis::CANONICAL_EMPTY_MST_BYTES.to_vec(),
            );
        }

        // Assemble deduplicated relevant blocks (new MST + new records + proof nodes).
        let mut new_blocks_map: BTreeMap<Cid, Vec<u8>> = BTreeMap::new();
        for b in new_mst_blocks {
            new_blocks_map.insert(b.cid, b.bytes);
        }
        for (cid, bytes) in record_blocks {
            new_blocks_map.insert(cid, bytes);
        }

        let mut proof_blocks_map: BTreeMap<Cid, Vec<u8>> = BTreeMap::new();
        for (cid, bytes) in new_covering_map.into_iter().chain(prev_covering_map) {
            proof_blocks_map.insert(cid, bytes);
        }

        let descriptor = CommitDescriptor {
            did: state.did.clone(),
            rev: rev.clone(),
            data_cid: new_data_cid.clone(),
            prev_cid: None,
        };
        let estimated_commit_bytes =
            CommitCodec::preflight_signed_commit_byte_count(&descriptor, limits)?;

        let mut relevant_union: BTreeMap<&Cid, usize> = BTreeMap::new();
        for (cid, bytes) in &new_blocks_map {
            relevant_union.insert(cid, bytes.len());
        }
        for (cid, bytes) in &proof_blocks_map {
            relevant_union.insert(cid, bytes.len());
        }
        for &block_len in relevant_union.values() {
            if block_len > limits.max_single_block_bytes {
                return Err(EngineError::Limit(LimitError::Exceeded {
                    kind: LimitKind::SingleBlockBytes,
                    observed: block_len,
                    limit: limits.max_single_block_bytes,
                }));
            }
        }
        let relevant_bytes: usize = relevant_union.values().sum();
        let total_commit_bytes = relevant_bytes.saturating_add(estimated_commit_bytes);
        if total_commit_bytes > limits.max_relevant_block_bytes {
            return Err(EngineError::RelevantBlocksExceedBudget {
                total: relevant_bytes,
                budget: limits
                    .max_relevant_block_bytes
                    .saturating_sub(estimated_commit_bytes),
            });
        }

        // Enforce `max_block_count` over the resulting reachable CAR blocks
        // (1 commit + unique MST nodes + live record blocks) before signing/persisting.
        // Uses O(1) `store.len()` fast-path unless total candidate blocks approach the ceiling.
        let candidate_upper_bound = store
            .len()
            .await?
            .saturating_add(1)
            .saturating_add(new_blocks_map.len());
        if candidate_upper_bound > limits.max_block_count {
            let max_tree_blocks = limits.max_block_count.saturating_sub(1);
            let tree_blocks = mst.count_reachable_blocks_bounded(max_tree_blocks).await?;
            let total_reachable = 1_usize.saturating_add(tree_blocks);
            if total_reachable > limits.max_block_count {
                return Err(EngineError::Limit(LimitError::Exceeded {
                    kind: LimitKind::BlockCount,
                    observed: total_reachable,
                    limit: limits.max_block_count,
                }));
            }
        }

        let commit = CommitCodec::prepare(&descriptor, signer, limits).await?;

        let new_blocks: Vec<RepositoryBlock> = new_blocks_map
            .into_iter()
            .map(|(cid, bytes)| RepositoryBlock::new(cid, bytes))
            .collect();
        let proof_blocks: Vec<RepositoryBlock> = proof_blocks_map
            .into_iter()
            .map(|(cid, bytes)| RepositoryBlock::new(cid, bytes))
            .collect();

        // Persist newly created blocks and commit to the block store.
        store.put_blocks(&new_blocks).await?;
        store
            .put_block(&commit.cid, &commit.signed_commit_bytes)
            .await?;

        let mut operations = Vec::with_capacity(canonical_writes.len());
        for (write, diff) in canonical_writes.iter().zip(mst_diff.iter()) {
            let op = match write {
                WriteOp::Create { path, .. } => CommitOperation::Create {
                    path: path.clone(),
                    cid: diff.new_value.clone().ok_or_else(|| {
                        EngineError::Mst(crate::error::MstError::MissingKey(
                            path.mst_key().to_owned(),
                        ))
                    })?,
                },
                WriteOp::Update { path, .. } => CommitOperation::Update {
                    path: path.clone(),
                    cid: diff.new_value.clone().ok_or_else(|| {
                        EngineError::Mst(crate::error::MstError::MissingKey(
                            path.mst_key().to_owned(),
                        ))
                    })?,
                    prev: diff.old_value.clone().ok_or_else(|| {
                        EngineError::Mst(crate::error::MstError::MissingKey(
                            path.mst_key().to_owned(),
                        ))
                    })?,
                },
                WriteOp::Delete { path } => CommitOperation::Delete {
                    path: path.clone(),
                    prev: diff.old_value.clone().ok_or_else(|| {
                        EngineError::Mst(crate::error::MstError::MissingKey(
                            path.mst_key().to_owned(),
                        ))
                    })?,
                },
            };
            operations.push(op);
        }

        let next_state = RepositoryState::with_head(
            state.did.clone(),
            commit.cid.clone(),
            new_data_cid,
            rev,
            state.signing_key_generation,
        );

        Ok(RepositoryMutationResult {
            state: next_state,
            commit,
            previous_data_cid,
            new_blocks,
            proof_blocks,
            operations,
        })
    }
}
