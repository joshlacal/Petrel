use std::sync::Arc;

use petrel_core::{Cid, Did};

use crate::block_store::{BlockSource, BlockStore};
use crate::commit::{CommitCodec, VerifiedSignedCommit};
use crate::crypto::RepositorySigningKeyResolver;
use crate::error::CommitDiffError;
use crate::limits::RepositoryLimits;
use crate::mst::{MstOptions, RepositoryMst};
use crate::types::{RepositoryPath, RepositoryReadPolicy};

/// A single atomic operation emitted in a repository commit event
/// (`RepositoryCommitOperation`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CommitOperation {
    Create {
        path: RepositoryPath,
        cid: Cid,
    },
    Update {
        path: RepositoryPath,
        cid: Cid,
        prev: Cid,
    },
    Delete {
        path: RepositoryPath,
        prev: Cid,
    },
}

impl CommitOperation {
    pub fn action(&self) -> &'static str {
        match self {
            Self::Create { .. } => "create",
            Self::Update { .. } => "update",
            Self::Delete { .. } => "delete",
        }
    }

    pub fn path(&self) -> &RepositoryPath {
        match self {
            Self::Create { path, .. } | Self::Update { path, .. } | Self::Delete { path, .. } => {
                path
            }
        }
    }

    pub fn cid(&self) -> Option<&Cid> {
        match self {
            Self::Create { cid, .. } | Self::Update { cid, .. } => Some(cid),
            Self::Delete { .. } => None,
        }
    }

    pub fn prev(&self) -> Option<&Cid> {
        match self {
            Self::Create { .. } => None,
            Self::Update { prev, .. } | Self::Delete { prev, .. } => Some(prev),
        }
    }
}

/// Verified repository commit plus inverted/verified operations (`VerifiedRepositoryCommitDiff`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VerifiedCommitDiff {
    pub commit: VerifiedSignedCommit,
    pub previous_data_cid: Option<Cid>,
    pub operations: Vec<CommitOperation>,
}

/// Verifies firehose `#commit` / `#sync` events and MST diffs by inverting ops
/// over the partial CAR proof block set (`RepositoryCommitDiff`).
#[derive(Debug, Clone, Copy, Default)]
pub struct CommitDiff;

impl CommitDiff {
    /// Verifies that applying `operations` in reverse against `data_cid` using
    /// only the partial MST blocks in `blocks` reproduces `previous_data_cid`.
    pub async fn verify_inversion<S: BlockStore + 'static>(
        data_cid: &Cid,
        operations: &[CommitOperation],
        previous_data_cid: Option<&Cid>,
        blocks: Arc<S>,
        limits: &RepositoryLimits,
        policy: &RepositoryReadPolicy,
    ) -> Result<Cid, CommitDiffError> {
        if operations.len() > limits.max_writes_per_commit {
            return Err(CommitDiffError::InvalidOperation(format!(
                "operation count {} exceeds limit {}",
                operations.len(),
                limits.max_writes_per_commit
            )));
        }

        let mut options = MstOptions {
            policy: *policy,
            ..MstOptions::default()
        };
        options.max_depth = limits.max_mst_depth;
        options.max_node_count = limits.max_mst_node_count;

        let mut tree = RepositoryMst::open_with_options(data_cid.clone(), blocks, options);

        // Apply inverted operations in reverse order.
        for op in operations.iter().rev() {
            let key = op.path().mst_key();
            match op {
                CommitOperation::Create { cid, .. } => {
                    let current = tree.get(key).await?;
                    if current.as_ref() != Some(cid) {
                        return Err(CommitDiffError::InvalidOperation(format!(
                            "create op key {key} resolved to {current:?}, expected {cid}"
                        )));
                    }
                    tree.delete(key).await?;
                }
                CommitOperation::Update { cid, prev, .. } => {
                    let current = tree.get(key).await?;
                    if current.as_ref() != Some(cid) {
                        return Err(CommitDiffError::InvalidOperation(format!(
                            "update op key {key} resolved to {current:?}, expected {cid}"
                        )));
                    }
                    if policy.requires_blessed_record_links_in_mst && !prev.is_blessed() {
                        return Err(CommitDiffError::Mst(crate::error::MstError::UnblessedLink(
                            prev.to_string(),
                        )));
                    }
                    tree.update(key, prev.clone()).await?;
                }
                CommitOperation::Delete { prev, .. } => {
                    let current = tree.get(key).await?;
                    if current.is_some() {
                        return Err(CommitDiffError::InvalidOperation(format!(
                            "delete op key {key} unexpectedly present in new MST: {current:?}"
                        )));
                    }
                    if policy.requires_blessed_record_links_in_mst && !prev.is_blessed() {
                        return Err(CommitDiffError::Mst(crate::error::MstError::UnblessedLink(
                            prev.to_string(),
                        )));
                    }
                    tree.insert(key, prev.clone()).await?;
                }
            }
        }

        let computed_prev = tree.root_cid().clone();
        if let Some(expected_prev) = previous_data_cid
            && &computed_prev != expected_prev
        {
            return Err(CommitDiffError::PreviousDataMismatch {
                computed: computed_prev,
                expected: Some(expected_prev.clone()),
            });
        }
        Ok(computed_prev)
    }

    /// Loads `commit_cid` from `blocks`, verifies its signature via `key_resolver`,
    /// and verifies MST diff inversion against `previous_data_cid`.
    #[allow(clippy::too_many_arguments)]
    pub async fn verify<S: BlockStore + 'static>(
        commit_cid: &Cid,
        operations: &[CommitOperation],
        previous_data_cid: Option<&Cid>,
        blocks: Arc<S>,
        key_resolver: &dyn RepositorySigningKeyResolver,
        expected_did: Option<&Did>,
        limits: &RepositoryLimits,
        policy: &RepositoryReadPolicy,
    ) -> Result<VerifiedCommitDiff, CommitDiffError> {
        let commit = CommitCodec::verify_from_store(
            commit_cid,
            blocks.as_ref(),
            expected_did,
            key_resolver,
            policy,
        )
        .await?;

        let computed_prev = Self::verify_inversion(
            &commit.data_cid,
            operations,
            previous_data_cid,
            blocks,
            limits,
            policy,
        )
        .await?;

        Ok(VerifiedCommitDiff {
            commit,
            previous_data_cid: Some(previous_data_cid.cloned().unwrap_or(computed_prev)),
            operations: operations.to_vec(),
        })
    }

    /// Parses a commit CAR slice (e.g. firehose `#commit` `blocks`), verifies the
    /// commit signature, and verifies diff inversion.
    #[allow(clippy::too_many_arguments)]
    pub async fn verify_commit_event(
        car_bytes: &[u8],
        expected_commit_cid: &Cid,
        expected_did: &Did,
        operations: &[CommitOperation],
        previous_data_cid: Option<&Cid>,
        key_resolver: &dyn RepositorySigningKeyResolver,
        limits: &RepositoryLimits,
        policy: &RepositoryReadPolicy,
    ) -> Result<VerifiedCommitDiff, CommitDiffError> {
        let (parsed, store) =
            crate::car::PublicRepositoryCAR::import_bytes(car_bytes, limits, policy)
                .await
                .map_err(|err| CommitDiffError::InvalidOperation(err.to_string()))?;
        if &parsed.root_cid != expected_commit_cid {
            return Err(CommitDiffError::ResultDataMismatch {
                computed: parsed.root_cid,
                expected: expected_commit_cid.clone(),
            });
        }
        Self::verify(
            expected_commit_cid,
            operations,
            previous_data_cid,
            Arc::new(store),
            key_resolver,
            Some(expected_did),
            limits,
            policy,
        )
        .await
    }

    /// Parses and verifies a firehose `#sync` event CAR slice (`commit` + MST root block).
    pub async fn verify_sync_event(
        car_bytes: &[u8],
        expected_commit_cid: &Cid,
        expected_did: &Did,
        key_resolver: &dyn RepositorySigningKeyResolver,
        limits: &RepositoryLimits,
        policy: &RepositoryReadPolicy,
    ) -> Result<VerifiedSignedCommit, CommitDiffError> {
        let (parsed, store) =
            crate::car::PublicRepositoryCAR::import_bytes(car_bytes, limits, policy)
                .await
                .map_err(|err| CommitDiffError::InvalidOperation(err.to_string()))?;
        if &parsed.root_cid != expected_commit_cid {
            return Err(CommitDiffError::ResultDataMismatch {
                computed: parsed.root_cid,
                expected: expected_commit_cid.clone(),
            });
        }
        let commit = CommitCodec::verify_from_store(
            expected_commit_cid,
            &store,
            Some(expected_did),
            key_resolver,
            policy,
        )
        .await?;
        // Ensure referenced MST root exists and is valid DAG-CBOR MST node.
        let mst_root_bytes = store
            .get_block(&commit.data_cid)
            .await?
            .ok_or_else(|| CommitDiffError::MissingBlock(commit.data_cid.clone()))?;
        crate::mst::codec::decode_mst_node(
            &mst_root_bytes,
            crate::mst::MstKeySyntax::StrictAtProto,
            policy,
            true,
        )?;
        Ok(commit)
    }
}
