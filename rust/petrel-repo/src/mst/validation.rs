use std::collections::HashSet;

use petrel::rt::BoxFuture;
use petrel_core::Cid;

use crate::block_store::BlockSource;
use crate::error::MstError;
use crate::mst::codec::{decode_mst_node, key_depth};
use crate::mst::tree::{MstEntry, MstOptions};

/// Statistics collected while validating an entire MST (`RepositoryMSTStatistics`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MstStats {
    pub record_count: usize,
    pub node_count: usize,
    pub tree_depth: usize,
    pub root_layer: usize,
    pub total_mst_block_bytes: usize,
    pub total_record_block_bytes: usize,
}

/// Full structural & cryptographic verification of an AT Protocol MST
/// (`RepositoryMSTValidation`).
#[derive(Debug, Clone, Copy, Default)]
pub struct MstValidation;

impl MstValidation {
    /// Validates the entire MST rooted at `root_cid`:
    /// - Acyclicity (`CycleDetected`)
    /// - Bounded depth & node/record count
    /// - Hash-verified canonical DAG-CBOR node encoding
    /// - Canonical prefix compression & strict UTF-8 key ordering
    /// - Exact layer-height invariants (each entry key's `key_depth` matches
    ///   its layer, child subtrees sit at `layer - 1`, root is trimmed unless
    ///   empty)
    /// - Optionally verifies that all leaf record blocks exist & match their CIDs
    pub async fn validate_full(
        root_cid: &Cid,
        source: &dyn BlockSource,
        options: &MstOptions,
        max_record_count: usize,
        verify_record_blocks: bool,
    ) -> Result<(MstStats, Vec<MstEntry>), MstError> {
        let mut ctx = ValidationContext {
            source,
            options,
            max_record_count,
            verify_record_blocks,
            seen_cids: HashSet::new(),
            last_key: None,
            entries: Vec::new(),
            node_count: 0,
            max_depth_seen: 0,
            total_mst_block_bytes: 0,
            total_record_block_bytes: 0,
        };

        let root_layer = validate_node(&mut ctx, root_cid.clone(), None, true, 0).await?;
        let stats = MstStats {
            record_count: ctx.entries.len(),
            node_count: ctx.node_count,
            tree_depth: ctx.max_depth_seen + 1,
            root_layer: root_layer.unwrap_or(0),
            total_mst_block_bytes: ctx.total_mst_block_bytes,
            total_record_block_bytes: ctx.total_record_block_bytes,
        };
        Ok((stats, ctx.entries))
    }
}

struct ValidationContext<'s> {
    source: &'s dyn BlockSource,
    options: &'s MstOptions,
    max_record_count: usize,
    verify_record_blocks: bool,
    seen_cids: HashSet<Cid>,
    last_key: Option<String>,
    entries: Vec<MstEntry>,
    node_count: usize,
    max_depth_seen: usize,
    total_mst_block_bytes: usize,
    total_record_block_bytes: usize,
}

#[allow(clippy::too_many_lines)]
fn validate_node<'c, 's: 'c>(
    ctx: &'c mut ValidationContext<'s>,
    node_cid: Cid,
    expected_layer: Option<usize>,
    is_root: bool,
    depth: usize,
) -> BoxFuture<'c, Result<Option<usize>, MstError>> {
    Box::pin(async move {
        if depth > ctx.options.max_depth {
            return Err(MstError::DepthExceeded {
                depth,
                limit: ctx.options.max_depth,
            });
        }
        ctx.max_depth_seen = ctx.max_depth_seen.max(depth);
        if !ctx.seen_cids.insert(node_cid.clone()) {
            return Err(MstError::CycleDetected(node_cid));
        }
        ctx.node_count += 1;
        if ctx.node_count > ctx.options.max_node_count {
            return Err(MstError::NodeCountExceeded {
                count: ctx.node_count,
                limit: ctx.options.max_node_count,
            });
        }

        let bytes = ctx
            .source
            .get_block(&node_cid)
            .await?
            .ok_or_else(|| MstError::MissingBlock(node_cid.clone()))?;
        if node_cid.hash_code() == 0x12 && !node_cid.matches_content(&bytes) {
            return Err(MstError::InvalidNode(format!(
                "MST node CID hash mismatch for {node_cid}"
            )));
        }
        ctx.total_mst_block_bytes = ctx.total_mst_block_bytes.saturating_add(bytes.len());

        let view = decode_mst_node(
            &bytes,
            ctx.options.key_syntax,
            &ctx.options.policy,
            ctx.options.require_canonical_prefix,
        )?;

        if view.entries.is_empty() {
            if let Some(left) = view.left {
                if is_root {
                    return Err(MstError::NonCanonical(
                        "non-empty MST root cannot have zero entries and a left pointer".into(),
                    ));
                }
                let child_expected = expected_layer.and_then(|l| l.checked_sub(1));
                if expected_layer == Some(0) {
                    return Err(MstError::InvalidNode(
                        "layer-0 node cannot point to a left subtree".into(),
                    ));
                }
                let child_layer =
                    validate_node(ctx, left, child_expected, false, depth + 1).await?;
                let Some(cl) = child_layer else {
                    return Err(MstError::NonCanonical(
                        "empty child subtree referenced by left pointer".into(),
                    ));
                };
                ctx.seen_cids.remove(&node_cid);
                return Ok(Some(cl + 1));
            }
            if !is_root {
                return Err(MstError::NonCanonical(
                    "empty MST node only permitted as tree root".into(),
                ));
            }
            ctx.seen_cids.remove(&node_cid);
            return Ok(None);
        }

        let node_layer = key_depth(view.entries[0].key.as_bytes());
        if let Some(exp) = expected_layer
            && node_layer != exp
        {
            return Err(MstError::KeyHeightMismatch {
                key: view.entries[0].key.clone(),
                actual: node_layer,
                expected: exp,
            });
        }
        for entry in &view.entries {
            let h = key_depth(entry.key.as_bytes());
            if h != node_layer {
                return Err(MstError::KeyHeightMismatch {
                    key: entry.key.clone(),
                    actual: h,
                    expected: node_layer,
                });
            }
        }

        if let Some(left) = view.left {
            if node_layer == 0 {
                return Err(MstError::InvalidNode(
                    "layer-0 node cannot have left subtree".into(),
                ));
            }
            let child_layer =
                validate_node(ctx, left, Some(node_layer - 1), false, depth + 1).await?;
            if child_layer.is_none() {
                return Err(MstError::NonCanonical(
                    "left child cannot be empty canonical node".into(),
                ));
            }
        }

        for entry in view.entries {
            if let Some(prev) = ctx.last_key.as_deref()
                && entry.key.as_str() <= prev
            {
                return Err(MstError::KeyOrderViolation {
                    previous: prev.to_owned(),
                    next: entry.key,
                });
            }
            ctx.last_key = Some(entry.key.clone());

            if ctx.entries.len() >= ctx.max_record_count {
                return Err(MstError::RecordCountExceeded {
                    count: ctx.entries.len() + 1,
                    limit: ctx.max_record_count,
                });
            }

            if ctx.verify_record_blocks {
                let rec_bytes = ctx
                    .source
                    .get_block(&entry.value)
                    .await?
                    .ok_or_else(|| MstError::MissingBlock(entry.value.clone()))?;
                if entry.value.hash_code() == 0x12 && !entry.value.matches_content(&rec_bytes) {
                    return Err(MstError::InvalidNode(format!(
                        "record block CID hash mismatch for {}",
                        entry.value
                    )));
                }
                ctx.total_record_block_bytes =
                    ctx.total_record_block_bytes.saturating_add(rec_bytes.len());
            }

            ctx.entries.push(MstEntry {
                key: entry.key,
                value: entry.value,
            });

            if let Some(right) = entry.tree {
                if node_layer == 0 {
                    return Err(MstError::InvalidNode(
                        "layer-0 node cannot have right subtree".into(),
                    ));
                }
                let child_layer =
                    validate_node(ctx, right, Some(node_layer - 1), false, depth + 1).await?;
                if child_layer.is_none() {
                    return Err(MstError::NonCanonical(
                        "right child cannot be empty canonical node".into(),
                    ));
                }
            }
        }

        ctx.seen_cids.remove(&node_cid);
        Ok(Some(node_layer))
    })
}
