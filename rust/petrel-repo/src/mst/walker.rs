use std::sync::Arc;

use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use petrel_core::Cid;

use crate::block_store::BlockSource;
use crate::error::MstError;
use crate::mst::codec::decode_mst_node;
use crate::mst::tree::{MstEntry, MstOptions};

/// Streaming traversal options (`RepositoryMSTWalkOptions`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MstWalkOptions {
    pub mst_options: MstOptions,
    pub max_record_count: usize,
    pub verify_block_hashes: bool,
}

impl Default for MstWalkOptions {
    fn default() -> Self {
        Self {
            mst_options: MstOptions::default(),
            max_record_count: 250_000,
            verify_block_hashes: true,
        }
    }
}

/// Summary produced upon completing an MST walk (`RepositoryMSTWalkProgress`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MstWalkProgress {
    pub visited_nodes: usize,
    pub visited_entries: usize,
    pub max_depth_reached: usize,
    pub last_key: Option<String>,
}

/// Depth-first bounded streaming walker across an MST (`RepositoryMSTWalker`).
#[derive(Debug)]
pub struct MstWalker {
    options: MstWalkOptions,
}

impl MstWalker {
    pub fn new(options: MstWalkOptions) -> Self {
        Self { options }
    }

    /// Walks all entries in `root_cid` in ascending key order, invoking `visitor`
    /// with each `(key, value_cid)`.
    pub async fn walk<F>(
        &self,
        root_cid: &Cid,
        source: &dyn BlockSource,
        mut visitor: F,
    ) -> Result<MstWalkProgress, MstError>
    where
        F: FnMut(MstEntry) -> Result<(), MstError> + MaybeSend + MaybeSync,
    {
        let mut state = WalkState {
            visited_nodes: 0,
            visited_entries: 0,
            max_depth_reached: 0,
            last_key: None,
            seen_nodes: std::collections::HashSet::new(),
        };
        visit_node(
            &self.options,
            root_cid.clone(),
            source,
            0,
            &mut state,
            &mut visitor,
        )
        .await?;
        Ok(MstWalkProgress {
            visited_nodes: state.visited_nodes,
            visited_entries: state.visited_entries,
            max_depth_reached: state.max_depth_reached,
            last_key: state.last_key,
        })
    }

    /// Convenience collector wrapper over [`Self::walk`].
    pub async fn collect_entries(
        &self,
        root_cid: &Cid,
        source: &Arc<dyn BlockSource>,
    ) -> Result<(Vec<MstEntry>, MstWalkProgress), MstError> {
        let mut entries = Vec::new();
        let progress = self
            .walk(root_cid, source.as_ref(), |entry| {
                entries.push(entry);
                Ok(())
            })
            .await?;
        Ok((entries, progress))
    }
}

struct WalkState {
    visited_nodes: usize,
    visited_entries: usize,
    max_depth_reached: usize,
    last_key: Option<String>,
    seen_nodes: std::collections::HashSet<Cid>,
}

fn visit_node<'c, 's: 'c, F>(
    options: &'s MstWalkOptions,
    node_cid: Cid,
    source: &'s dyn BlockSource,
    depth: usize,
    state: &'c mut WalkState,
    visitor: &'c mut F,
) -> BoxFuture<'c, Result<(), MstError>>
where
    F: FnMut(MstEntry) -> Result<(), MstError> + MaybeSend + MaybeSync,
{
    Box::pin(async move {
        if depth > options.mst_options.max_depth {
            return Err(MstError::DepthExceeded {
                depth,
                limit: options.mst_options.max_depth,
            });
        }
        state.max_depth_reached = state.max_depth_reached.max(depth);
        if !state.seen_nodes.insert(node_cid.clone()) {
            return Err(MstError::CycleDetected(node_cid));
        }
        state.visited_nodes += 1;
        if state.visited_nodes > options.mst_options.max_node_count {
            return Err(MstError::NodeCountExceeded {
                count: state.visited_nodes,
                limit: options.mst_options.max_node_count,
            });
        }

        let bytes = source
            .get_block(&node_cid)
            .await?
            .ok_or_else(|| MstError::MissingBlock(node_cid.clone()))?;
        if options.verify_block_hashes
            && node_cid.hash_code() == 0x12
            && !node_cid.matches_content(&bytes)
        {
            return Err(MstError::InvalidNode(format!(
                "MST node hash mismatch for {node_cid}"
            )));
        }

        let view = decode_mst_node(
            &bytes,
            options.mst_options.key_syntax,
            &options.mst_options.policy,
            options.mst_options.require_canonical_prefix,
        )?;

        if let Some(left) = view.left {
            visit_node(options, left, source, depth + 1, state, visitor).await?;
        }

        for entry in view.entries {
            if let Some(prev) = state.last_key.as_deref()
                && entry.key.as_str() <= prev
            {
                return Err(MstError::KeyOrderViolation {
                    previous: prev.to_owned(),
                    next: entry.key,
                });
            }
            state.last_key = Some(entry.key.clone());
            state.visited_entries += 1;
            if state.visited_entries > options.max_record_count {
                return Err(MstError::RecordCountExceeded {
                    count: state.visited_entries,
                    limit: options.max_record_count,
                });
            }
            visitor(MstEntry {
                key: entry.key,
                value: entry.value,
            })?;

            if let Some(right) = entry.tree {
                visit_node(options, right, source, depth + 1, state, visitor).await?;
            }
        }

        state.seen_nodes.remove(&node_cid);
        Ok(())
    })
}
