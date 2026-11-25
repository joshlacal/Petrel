use std::collections::{BTreeMap, HashMap};
use std::sync::Arc;

use petrel::rt::BoxFuture;
use petrel_core::Cid;

use crate::block_store::{BlockMap, BlockSource, RepositoryBlock};
use crate::error::MstError;
use crate::genesis::CANONICAL_EMPTY_MST_BYTES;
use crate::mst::codec::{
    MstNodeEntryView, MstNodeView, decode_mst_node, encode_mst_node, key_depth, validate_mst_key,
};
use crate::types::{RepositoryReadPolicy, WriteOp};

/// Syntax strictness for keys inside a [`RepositoryMst`].
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum MstKeySyntax {
    /// Full AT Protocol NSID + RecordKey + byte-length rules.
    #[default]
    StrictAtProto,
    /// Two `/` segments (`collection/rkey`), non-empty, <= 1024 bytes.
    TwoSegment,
    /// Any non-empty UTF-8 string <= 1024 bytes (used for raw MST interop tests).
    PermissiveUtf8,
}

/// Configuration options for opening or mutating a [`RepositoryMst`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MstOptions {
    pub key_syntax: MstKeySyntax,
    pub policy: RepositoryReadPolicy,
    pub require_canonical_prefix: bool,
    pub max_depth: usize,
    pub max_node_count: usize,
    pub max_single_block_bytes: usize,
}

impl Default for MstOptions {
    fn default() -> Self {
        Self {
            key_syntax: MstKeySyntax::StrictAtProto,
            policy: RepositoryReadPolicy::strict(),
            require_canonical_prefix: true,
            max_depth: 128,
            max_node_count: 250_000,
            max_single_block_bytes: 1_048_576,
        }
    }
}

/// A leaf `(key, value)` entry in an MST.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MstEntry {
    pub key: String,
    pub value: Cid,
}

/// Difference between two MST roots (`new_blocks`, `removed_cids`).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MstDiff {
    pub new_blocks: Vec<RepositoryBlock>,
    pub removed_cids: Vec<Cid>,
    pub created: Vec<MstDiffEntry>,
    pub updated: Vec<MstDiffEntry>,
    pub deleted: Vec<MstDiffEntry>,
}

/// A single key change recorded in an [`MstDiff`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MstDiffEntry {
    pub key: String,
    pub old_value: Option<Cid>,
    pub new_value: Option<Cid>,
}

#[derive(Debug, Clone)]
enum NodeSource {
    External(Arc<dyn BlockSource>),
    Empty,
}

type SplitPair = (Option<Cid>, Option<Cid>);

/// Distinct block, MST node, and live record counts returned by
/// [`RepositoryMst::count_reachable_counts_bounded`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ReachableMstCounts {
    pub unique_blocks: usize,
    pub mst_node_count: usize,
    pub record_count: usize,
}

/// Immutable, lazily-loaded AT Protocol Merkle Search Tree backed by a
/// [`BlockSource`] plus local copy-on-write dirty node overlay.
#[derive(Debug, Clone)]
pub struct RepositoryMst {
    root_cid: Cid,
    base_root_cid: Option<Cid>,
    base_nodes: std::collections::HashSet<Cid>,
    source: NodeSource,
    dirty_blocks: BlockMap,
    decoded_cache: BTreeMap<Cid, MstNodeView>,
    options: MstOptions,
}

impl RepositoryMst {
    /// Returns the canonical empty MST (`bafyreie5737gdxlw5i64vzichcalba3z2v5n6icifvx5xytvske7mr3hpm`).
    pub fn empty() -> Self {
        let root_cid = Cid::for_dag_cbor(crate::genesis::CANONICAL_EMPTY_MST_BYTES);
        let mut dirty_blocks = BTreeMap::new();
        dirty_blocks.insert(root_cid.clone(), CANONICAL_EMPTY_MST_BYTES.to_vec());
        let mut decoded_cache = BTreeMap::new();
        decoded_cache.insert(
            root_cid.clone(),
            MstNodeView {
                left: None,
                entries: Vec::new(),
            },
        );
        Self {
            root_cid,
            base_root_cid: None,
            base_nodes: std::collections::HashSet::new(),
            source: NodeSource::Empty,
            dirty_blocks,
            decoded_cache,
            options: MstOptions::default(),
        }
    }

    pub fn empty_with_options(options: MstOptions) -> Self {
        let mut tree = Self::empty();
        tree.options = options;
        tree
    }

    /// Opens an MST rooted at `root_cid` backed by `source`.
    pub fn open(root_cid: Cid, source: Arc<dyn BlockSource>) -> Self {
        Self::open_with_options(root_cid, source, MstOptions::default())
    }

    pub fn open_with_options(
        root_cid: Cid,
        source: Arc<dyn BlockSource>,
        options: MstOptions,
    ) -> Self {
        let mut base_nodes = std::collections::HashSet::new();
        base_nodes.insert(root_cid.clone());
        Self {
            base_root_cid: Some(root_cid.clone()),
            base_nodes,
            root_cid,
            source: NodeSource::External(source),
            dirty_blocks: BTreeMap::new(),
            decoded_cache: BTreeMap::new(),
            options,
        }
    }

    pub fn root_cid(&self) -> &Cid {
        &self.root_cid
    }

    /// Returns the MST layer height of the current root (`0` when empty).
    pub async fn root_layer(&mut self) -> Result<usize, MstError> {
        let root = self.root_cid.clone();
        Ok(self.node_layer(&root).await?.unwrap_or(0))
    }

    pub fn options(&self) -> &MstOptions {
        &self.options
    }

    #[must_use]
    pub fn with_options(mut self, options: MstOptions) -> Self {
        self.options = options;
        self
    }

    /// Returns all newly produced node blocks accumulated since opening/cloning.
    pub fn new_blocks(&self) -> Vec<RepositoryBlock> {
        self.dirty_blocks
            .iter()
            .map(|(cid, bytes)| RepositoryBlock::new(cid.clone(), bytes.clone()))
            .collect()
    }

    /// Clears local dirty tracking while keeping cached decoded nodes and source.
    pub fn clear_dirty_tracking(&mut self) {
        self.dirty_blocks.clear();
        self.base_root_cid = Some(self.root_cid.clone());
        self.base_nodes.clear();
        self.base_nodes.insert(self.root_cid.clone());
    }

    /// Fetches and decodes `node_cid` either from the local overlay or `source`.
    pub async fn load_node(&mut self, node_cid: &Cid) -> Result<MstNodeView, MstError> {
        if let Some(view) = self.decoded_cache.get(node_cid) {
            return Ok(view.clone());
        }
        let from_base_source = !self.dirty_blocks.contains_key(node_cid)
            && matches!(self.source, NodeSource::External(_));
        let bytes = self.get_raw_block(node_cid).await?;
        let view = decode_mst_node(
            &bytes,
            self.options.key_syntax,
            &self.options.policy,
            self.options.require_canonical_prefix,
        )?;
        if from_base_source {
            self.base_nodes.insert(node_cid.clone());
        }
        self.decoded_cache.insert(node_cid.clone(), view.clone());
        Ok(view)
    }

    pub(crate) async fn get_raw_block(&self, cid: &Cid) -> Result<Vec<u8>, MstError> {
        if let Some(bytes) = self.dirty_blocks.get(cid) {
            return Ok(bytes.clone());
        }
        match &self.source {
            NodeSource::Empty => {
                if cid == &Cid::for_dag_cbor(CANONICAL_EMPTY_MST_BYTES) {
                    Ok(CANONICAL_EMPTY_MST_BYTES.to_vec())
                } else {
                    Err(MstError::MissingBlock(cid.clone()))
                }
            }
            NodeSource::External(src) => src
                .get_block(cid)
                .await?
                .ok_or_else(|| MstError::MissingBlock(cid.clone())),
        }
    }

    fn store_node(&mut self, view: MstNodeView) -> Result<Cid, MstError> {
        let (cid, bytes) = encode_mst_node(&view)?;
        if bytes.len() > self.options.max_single_block_bytes {
            return Err(MstError::BlockTooLarge {
                len: bytes.len(),
                limit: self.options.max_single_block_bytes,
            });
        }
        self.dirty_blocks.insert(cid.clone(), bytes);
        self.decoded_cache.insert(cid.clone(), view);
        Ok(cid)
    }

    /// Computes the MST layer height of a loaded non-empty node or `0` if empty.
    fn node_layer<'a>(
        &'a mut self,
        node_cid: &'a Cid,
    ) -> BoxFuture<'a, Result<Option<usize>, MstError>> {
        Box::pin(async move {
            let view = self.load_node(node_cid).await?;
            if let Some(first) = view.entries.first() {
                return Ok(Some(key_depth(first.key.as_bytes())));
            }
            match view.left {
                Some(left_cid) => match self.node_layer(&left_cid).await? {
                    Some(h) => Ok(Some(h + 1)),
                    None => Ok(None),
                },
                None => Ok(None),
            }
        })
    }

    /// Looks up a key's value CID in the MST.
    pub async fn get(&mut self, key: &str) -> Result<Option<Cid>, MstError> {
        validate_mst_key(key, self.options.key_syntax)?;
        let root = self.root_cid.clone();
        self.get_in(&root, key, 0).await
    }

    fn get_in<'a>(
        &'a mut self,
        node_cid: &'a Cid,
        key: &'a str,
        depth: usize,
    ) -> BoxFuture<'a, Result<Option<Cid>, MstError>> {
        Box::pin(async move {
            if depth > self.options.max_depth {
                return Err(MstError::DepthExceeded {
                    depth,
                    limit: self.options.max_depth,
                });
            }
            let view = self.load_node(node_cid).await?;
            if view.entries.is_empty() {
                return match view.left {
                    Some(left_cid) => self.get_in(&left_cid, key, depth + 1).await,
                    None => Ok(None),
                };
            }
            let key_bytes = key.as_bytes();
            let pos = view
                .entries
                .partition_point(|entry| entry.key.as_bytes() < key_bytes);
            if pos < view.entries.len() && view.entries[pos].key == key {
                return Ok(Some(view.entries[pos].value.clone()));
            }
            let child = if pos == 0 {
                view.left.clone()
            } else {
                view.entries[pos - 1].tree.clone()
            };
            match child {
                Some(cid) => self.get_in(&cid, key, depth + 1).await,
                None => Ok(None),
            }
        })
    }

    /// Lists all entries in canonical sorted key order.
    pub async fn all_entries(&mut self) -> Result<Vec<MstEntry>, MstError> {
        let root = self.root_cid.clone();
        let mut out = Vec::new();
        self.collect_entries(&root, &mut out, 0).await?;
        Ok(out)
    }

    fn collect_entries<'a>(
        &'a mut self,
        node_cid: &'a Cid,
        out: &'a mut Vec<MstEntry>,
        depth: usize,
    ) -> BoxFuture<'a, Result<(), MstError>> {
        Box::pin(async move {
            if depth > self.options.max_depth {
                return Err(MstError::DepthExceeded {
                    depth,
                    limit: self.options.max_depth,
                });
            }
            let view = self.load_node(node_cid).await?;
            if let Some(left) = view.left {
                self.collect_entries(&left, out, depth + 1).await?;
            }
            for entry in view.entries {
                out.push(MstEntry {
                    key: entry.key,
                    value: entry.value,
                });
                if let Some(right) = entry.tree {
                    self.collect_entries(&right, out, depth + 1).await?;
                }
            }
            Ok(())
        })
    }

    /// Collects all reachable MST node blocks (`(cid, bytes)`) in the tree.
    pub async fn reachable_node_blocks(&mut self) -> Result<BlockMap, MstError> {
        let root = self.root_cid.clone();
        let mut out = BTreeMap::new();
        self.collect_blocks(&root, &mut out, 0).await?;
        Ok(out)
    }

    /// Counts distinct reachable blocks, MST nodes, and live records, aborting
    /// early as soon as any configured bound is exceeded.
    pub async fn count_reachable_counts_bounded(
        &mut self,
        max_unique_blocks: usize,
        max_mst_node_count: usize,
        max_record_count: usize,
    ) -> Result<ReachableMstCounts, MstError> {
        let mut seen_nodes = std::collections::HashSet::new();
        let mut unique_blocks = std::collections::HashSet::new();
        let mut mst_node_count = 0_usize;
        let mut record_count = 0_usize;
        let mut stack = vec![(self.root_cid.clone(), 0_usize)];

        while let Some((node_cid, depth)) = stack.pop() {
            if depth > self.options.max_depth {
                return Err(MstError::DepthExceeded {
                    depth,
                    limit: self.options.max_depth,
                });
            }
            if !seen_nodes.insert(node_cid.clone()) {
                continue;
            }
            mst_node_count = mst_node_count.saturating_add(1);
            unique_blocks.insert(node_cid.clone());
            if mst_node_count > max_mst_node_count || unique_blocks.len() > max_unique_blocks {
                return Ok(ReachableMstCounts {
                    unique_blocks: unique_blocks.len(),
                    mst_node_count,
                    record_count,
                });
            }
            let view = self.load_node(&node_cid).await?;
            if let Some(left) = view.left {
                stack.push((left, depth + 1));
            }
            for entry in view.entries {
                record_count = record_count.saturating_add(1);
                unique_blocks.insert(entry.value);
                if record_count > max_record_count || unique_blocks.len() > max_unique_blocks {
                    return Ok(ReachableMstCounts {
                        unique_blocks: unique_blocks.len(),
                        mst_node_count,
                        record_count,
                    });
                }
                if let Some(right) = entry.tree {
                    stack.push((right, depth + 1));
                }
            }
        }
        Ok(ReachableMstCounts {
            unique_blocks: unique_blocks.len(),
            mst_node_count,
            record_count,
        })
    }

    fn collect_blocks<'a>(
        &'a mut self,
        node_cid: &'a Cid,
        out: &'a mut BlockMap,
        depth: usize,
    ) -> BoxFuture<'a, Result<(), MstError>> {
        Box::pin(async move {
            if depth > self.options.max_depth {
                return Err(MstError::DepthExceeded {
                    depth,
                    limit: self.options.max_depth,
                });
            }
            if out.contains_key(node_cid) {
                return Ok(());
            }
            let bytes = self.get_raw_block(node_cid).await?;
            let view = self.load_node(node_cid).await?;
            out.insert(node_cid.clone(), bytes);
            if let Some(left) = view.left {
                self.collect_blocks(&left, out, depth + 1).await?;
            }
            for entry in view.entries {
                if let Some(right) = entry.tree {
                    self.collect_blocks(&right, out, depth + 1).await?;
                }
            }
            Ok(())
        })
    }

    /// Inserts a new `(key, value)` pair, failing with [`MstError::DuplicateKey`]
    /// if `key` already exists.
    pub async fn insert(&mut self, key: &str, value: Cid) -> Result<Cid, MstError> {
        self.validate_insert_args(key, &value)?;
        let target_layer = key_depth(key.as_bytes());
        let root = self.root_cid.clone();
        let new_root = self
            .insert_at(&root, key, value, target_layer, false)
            .await?;
        let trimmed = self.trim_top(new_root).await?;
        self.root_cid = trimmed.clone();
        Ok(trimmed)
    }

    /// Inserts or replaces `(key, value)`.
    pub async fn upsert(&mut self, key: &str, value: Cid) -> Result<Cid, MstError> {
        self.validate_insert_args(key, &value)?;
        let target_layer = key_depth(key.as_bytes());
        let root = self.root_cid.clone();
        let new_root = self
            .insert_at(&root, key, value, target_layer, true)
            .await?;
        let trimmed = self.trim_top(new_root).await?;
        self.root_cid = trimmed.clone();
        Ok(trimmed)
    }

    /// Updates an existing `key`, failing with [`MstError::MissingKey`] if absent.
    pub async fn update(&mut self, key: &str, value: Cid) -> Result<Cid, MstError> {
        self.validate_insert_args(key, &value)?;
        let root = self.root_cid.clone();
        let new_root = self.update_existing(&root, key, value).await?;
        self.root_cid = new_root.clone();
        Ok(new_root)
    }

    /// Deletes an existing `key`, failing with [`MstError::MissingKey`] if absent.
    pub async fn delete(&mut self, key: &str) -> Result<Cid, MstError> {
        validate_mst_key(key, self.options.key_syntax)?;
        let root = self.root_cid.clone();
        let new_root = self.delete_at(&root, key).await?;
        let trimmed = match new_root {
            Some(cid) => self.trim_top(cid).await?,
            None => self.store_empty()?,
        };
        self.root_cid = trimmed.clone();
        Ok(trimmed)
    }

    /// Applies a batch of repository write operations (`Create`, `Update`, `Delete`)
    /// returning the updated MST root CID and operation diff summary.
    pub async fn apply_writes(
        &mut self,
        writes: &[WriteOp],
    ) -> Result<(Cid, Vec<MstDiffEntry>), MstError> {
        let mut diff = Vec::with_capacity(writes.len());
        for write in writes {
            let key = write.path().mst_key();
            match write {
                WriteOp::Create { record_cbor, .. } => {
                    let cid = Cid::for_dag_cbor(record_cbor);
                    self.insert(key, cid.clone()).await?;
                    diff.push(MstDiffEntry {
                        key: key.to_owned(),
                        old_value: None,
                        new_value: Some(cid),
                    });
                }
                WriteOp::Update { record_cbor, .. } => {
                    let old_value = self.get(key).await?;
                    let Some(prev) = old_value else {
                        return Err(MstError::MissingKey(key.to_owned()));
                    };
                    let cid = Cid::for_dag_cbor(record_cbor);
                    self.update(key, cid.clone()).await?;
                    diff.push(MstDiffEntry {
                        key: key.to_owned(),
                        old_value: Some(prev),
                        new_value: Some(cid),
                    });
                }
                WriteOp::Delete { .. } => {
                    let Some(prev) = self.get(key).await? else {
                        return Err(MstError::MissingKey(key.to_owned()));
                    };
                    self.delete(key).await?;
                    diff.push(MstDiffEntry {
                        key: key.to_owned(),
                        old_value: Some(prev),
                        new_value: None,
                    });
                }
            }
        }
        Ok((self.root_cid.clone(), diff))
    }

    /// Returns the minimal covering node proof blocks for `keys` (including the
    /// root node and every node traversed toward any key in `keys`), plus
    /// guarantees canonical empty root is included if empty.
    pub async fn covering_proof_blocks(&mut self, keys: &[String]) -> Result<BlockMap, MstError> {
        let mut collected = BTreeMap::new();
        let root = self.root_cid.clone();
        let root_bytes = self.get_raw_block(&root).await?;
        collected.insert(root.clone(), root_bytes);

        for key in keys {
            self.collect_search_path(&root, key, &mut collected, 0)
                .await?;
        }
        Ok(collected)
    }

    fn collect_search_path<'a>(
        &'a mut self,
        node_cid: &'a Cid,
        key: &'a str,
        out: &'a mut BlockMap,
        depth: usize,
    ) -> BoxFuture<'a, Result<(), MstError>> {
        Box::pin(async move {
            if depth > self.options.max_depth {
                return Err(MstError::DepthExceeded {
                    depth,
                    limit: self.options.max_depth,
                });
            }
            if !out.contains_key(node_cid) {
                let bytes = self.get_raw_block(node_cid).await?;
                out.insert(node_cid.clone(), bytes);
            }
            let view = self.load_node(node_cid).await?;
            if view.entries.is_empty() {
                if let Some(left) = view.left {
                    self.collect_search_path(&left, key, out, depth + 1).await?;
                }
                return Ok(());
            }
            let key_bytes = key.as_bytes();
            let pos = view
                .entries
                .partition_point(|entry| entry.key.as_bytes() < key_bytes);
            if pos < view.entries.len() && view.entries[pos].key == key {
                return Ok(());
            }
            let next_child = if pos == 0 {
                view.left.clone()
            } else {
                view.entries[pos - 1].tree.clone()
            };
            if let Some(child) = next_child {
                self.collect_search_path(&child, key, out, depth + 1)
                    .await?;
            }
            Ok(())
        })
    }

    /// Computes minimal new blocks between `self` (new MST) and `previous_root_cid`.
    ///
    /// When comparing against the root this tree was branched from, traverses
    /// strictly through the dirty-node overlay so unchanged subtrees in the
    /// backing store incur zero block reads. Otherwise performs a CID-pruned
    /// subtree comparison skipping identical CIDs.
    pub async fn new_blocks_since(
        &mut self,
        previous_root_cid: Option<&Cid>,
    ) -> Result<Vec<RepositoryBlock>, MstError> {
        if previous_root_cid == Some(&self.root_cid) {
            return Ok(Vec::new());
        }

        // Fast path: tree was opened at `base_root_cid` and mutated via `self.dirty_blocks`.
        // Any child not in `self.dirty_blocks` is an unmodified subtree from `base_root_cid`.
        // Any dirty block whose CID matches a node loaded from `base_root_cid` (`base_nodes`)
        // is also already part of `previous_root_cid`, whereas historical store blocks from older
        // epochs that are absent from `base_root_cid` are never skipped.
        if previous_root_cid == self.base_root_cid.as_ref() {
            let root = self.root_cid.clone();
            let mut collected: BlockMap = BTreeMap::new();
            let mut visited: std::collections::HashSet<Cid> = std::collections::HashSet::new();
            self.collect_reachable_dirty(&root, &mut visited, &mut collected, 0)
                .await?;

            return Ok(collected
                .into_iter()
                .map(|(cid, bytes)| RepositoryBlock::new(cid, bytes))
                .collect());
        }

        // General path against an arbitrary `previous_root_cid`: CID-pruned traversal.
        let mut prev_cids: std::collections::HashSet<Cid> = std::collections::HashSet::new();
        if let Some(prev) = previous_root_cid {
            let mut prev_mst = match &self.source {
                NodeSource::External(src) => {
                    Self::open_with_options(prev.clone(), Arc::clone(src), self.options)
                }
                NodeSource::Empty => Self::empty_with_options(self.options),
            };
            if prev_mst.get_raw_block(prev).await.is_ok() {
                let mut new_cids_on_shared = std::collections::HashSet::new();
                // Collect CIDs only down to subtrees whose CIDs already appear in `self`,
                // or simply collect prev CIDs when comparing distinct arbitrary roots.
                let _ = prev_mst
                    .collect_cids(&prev.clone(), &mut prev_cids, &mut new_cids_on_shared, 0)
                    .await;
            }
        }

        let root = self.root_cid.clone();
        let mut collected = BTreeMap::new();
        self.collect_blocks_pruned(&root, &prev_cids, &mut collected, 0)
            .await?;
        Ok(collected
            .into_iter()
            .map(|(cid, bytes)| RepositoryBlock::new(cid, bytes))
            .collect())
    }

    fn collect_reachable_dirty<'a>(
        &'a mut self,
        node_cid: &'a Cid,
        visited: &'a mut std::collections::HashSet<Cid>,
        out: &'a mut BlockMap,
        depth: usize,
    ) -> BoxFuture<'a, Result<(), MstError>> {
        Box::pin(async move {
            if depth > self.options.max_depth {
                return Err(MstError::DepthExceeded {
                    depth,
                    limit: self.options.max_depth,
                });
            }
            if !visited.insert(node_cid.clone()) || self.base_nodes.contains(node_cid) {
                return Ok(());
            }
            let Some(bytes) = self.dirty_blocks.get(node_cid).cloned() else {
                // Node was not created/modified in this mutation sequence; its entire
                // subtree already belongs to `base_root_cid`.
                return Ok(());
            };
            let view = self.load_node(node_cid).await?;
            out.insert(node_cid.clone(), bytes);
            if let Some(left) = view.left {
                self.collect_reachable_dirty(&left, visited, out, depth + 1)
                    .await?;
            }
            for entry in view.entries {
                if let Some(right) = entry.tree {
                    self.collect_reachable_dirty(&right, visited, out, depth + 1)
                        .await?;
                }
            }
            Ok(())
        })
    }

    fn collect_cids<'a>(
        &'a mut self,
        node_cid: &'a Cid,
        cids: &'a mut std::collections::HashSet<Cid>,
        visited: &'a mut std::collections::HashSet<Cid>,
        depth: usize,
    ) -> BoxFuture<'a, Result<(), MstError>> {
        Box::pin(async move {
            if depth > self.options.max_depth || !visited.insert(node_cid.clone()) {
                return Ok(());
            }
            cids.insert(node_cid.clone());
            let Ok(view) = self.load_node(node_cid).await else {
                return Ok(());
            };
            if let Some(left) = view.left {
                self.collect_cids(&left, cids, visited, depth + 1).await?;
            }
            for entry in view.entries {
                if let Some(right) = entry.tree {
                    self.collect_cids(&right, cids, visited, depth + 1).await?;
                }
            }
            Ok(())
        })
    }

    fn collect_blocks_pruned<'a>(
        &'a mut self,
        node_cid: &'a Cid,
        skip_cids: &'a std::collections::HashSet<Cid>,
        out: &'a mut BlockMap,
        depth: usize,
    ) -> BoxFuture<'a, Result<(), MstError>> {
        Box::pin(async move {
            if depth > self.options.max_depth {
                return Err(MstError::DepthExceeded {
                    depth,
                    limit: self.options.max_depth,
                });
            }
            if skip_cids.contains(node_cid) || out.contains_key(node_cid) {
                return Ok(());
            }
            let bytes = self.get_raw_block(node_cid).await?;
            let view = self.load_node(node_cid).await?;
            out.insert(node_cid.clone(), bytes);
            if let Some(left) = view.left {
                self.collect_blocks_pruned(&left, skip_cids, out, depth + 1)
                    .await?;
            }
            for entry in view.entries {
                if let Some(right) = entry.tree {
                    self.collect_blocks_pruned(&right, skip_cids, out, depth + 1)
                        .await?;
                }
            }
            Ok(())
        })
    }

    fn validate_insert_args(&self, key: &str, value: &Cid) -> Result<(), MstError> {
        validate_mst_key(key, self.options.key_syntax)?;
        if self.options.policy.requires_blessed_record_links_in_mst && !value.is_blessed() {
            return Err(MstError::UnblessedLink(value.to_string()));
        }
        Ok(())
    }

    fn store_empty(&mut self) -> Result<Cid, MstError> {
        self.store_node(MstNodeView {
            left: None,
            entries: Vec::new(),
        })
    }

    fn update_existing<'a>(
        &'a mut self,
        node_cid: &'a Cid,
        key: &'a str,
        value: Cid,
    ) -> BoxFuture<'a, Result<Cid, MstError>> {
        Box::pin(async move {
            let mut view = self.load_node(node_cid).await?;
            let key_bytes = key.as_bytes();
            let pos = view
                .entries
                .partition_point(|entry| entry.key.as_bytes() < key_bytes);
            if pos < view.entries.len() && view.entries[pos].key == key {
                view.entries[pos].value = value;
                return self.store_node(view);
            }
            if pos == 0 {
                let Some(left_cid) = view.left.take() else {
                    return Err(MstError::MissingKey(key.to_owned()));
                };
                let updated_left = self.update_existing(&left_cid, key, value).await?;
                view.left = Some(updated_left);
            } else {
                let Some(right_cid) = view.entries[pos - 1].tree.take() else {
                    return Err(MstError::MissingKey(key.to_owned()));
                };
                let updated_right = self.update_existing(&right_cid, key, value).await?;
                view.entries[pos - 1].tree = Some(updated_right);
            }
            self.store_node(view)
        })
    }

    #[allow(clippy::too_many_lines)]
    fn insert_at<'a>(
        &'a mut self,
        node_cid: &'a Cid,
        key: &'a str,
        value: Cid,
        target_layer: usize,
        allow_overwrite: bool,
    ) -> BoxFuture<'a, Result<Cid, MstError>> {
        Box::pin(async move {
            let layer_opt = self.node_layer(node_cid).await?;
            let Some(current_layer) = layer_opt else {
                // Empty tree: materialize directly at `target_layer` (or height 0 wrapper)
                let base = self.store_node(MstNodeView {
                    left: None,
                    entries: vec![MstNodeEntryView {
                        key: key.to_owned(),
                        value,
                        tree: None,
                    }],
                })?;
                return Ok(base);
            };

            if target_layer > current_layer {
                // New root sits above `current_layer`!
                // Pad intermediate empty wrapper layers above split subtrees if gap > 1.
                let (left_sub, right_sub) =
                    self.split_around(node_cid, key, allow_overwrite).await?;
                let wrapped_left = self
                    .pad_to_layer(left_sub, current_layer, target_layer - 1)
                    .await?;
                let wrapped_right = self
                    .pad_to_layer(right_sub, current_layer, target_layer - 1)
                    .await?;
                return self.store_node(MstNodeView {
                    left: wrapped_left,
                    entries: vec![MstNodeEntryView {
                        key: key.to_owned(),
                        value,
                        tree: wrapped_right,
                    }],
                });
            }

            if target_layer == current_layer {
                let mut view = self.load_node(node_cid).await?;
                let key_bytes = key.as_bytes();
                let pos = view
                    .entries
                    .partition_point(|entry| entry.key.as_bytes() < key_bytes);
                if pos < view.entries.len() && view.entries[pos].key == key {
                    if !allow_overwrite {
                        return Err(MstError::DuplicateKey(key.to_owned()));
                    }
                    view.entries[pos].value = value;
                    return self.store_node(view);
                }

                // Split the child subtree spanning `pos` if present.
                let child_to_split = if pos == 0 {
                    view.left.take()
                } else {
                    view.entries[pos - 1].tree.take()
                };
                let (new_left_child, new_right_child) = match child_to_split {
                    Some(child_cid) => self.split_around(&child_cid, key, allow_overwrite).await?,
                    None => (None, None),
                };

                if pos == 0 {
                    view.left = new_left_child;
                } else {
                    view.entries[pos - 1].tree = new_left_child;
                }
                view.entries.insert(
                    pos,
                    MstNodeEntryView {
                        key: key.to_owned(),
                        value,
                        tree: new_right_child,
                    },
                );
                return self.store_node(view);
            }

            // `target_layer < current_layer`: descend into child at `current_layer - 1`.
            let mut view = self.load_node(node_cid).await?;
            let key_bytes = key.as_bytes();
            let pos = view
                .entries
                .partition_point(|entry| entry.key.as_bytes() < key_bytes);
            if pos < view.entries.len() && view.entries[pos].key == key {
                if !allow_overwrite {
                    return Err(MstError::DuplicateKey(key.to_owned()));
                }
                view.entries[pos].value = value;
                return self.store_node(view);
            }

            let existing_child = if pos == 0 {
                view.left.take()
            } else {
                view.entries[pos - 1].tree.take()
            };
            let next_child = if let Some(child_cid) = existing_child {
                self.insert_at(&child_cid, key, value, target_layer, allow_overwrite)
                    .await?
            } else {
                // Create leaf entry and wrap up to `current_layer - 1`.
                let leaf = self.store_node(MstNodeView {
                    left: None,
                    entries: vec![MstNodeEntryView {
                        key: key.to_owned(),
                        value,
                        tree: None,
                    }],
                })?;
                let wrapped = self
                    .pad_to_layer(Some(leaf), target_layer, current_layer - 1)
                    .await?;
                wrapped.ok_or_else(|| {
                    MstError::InvalidNode("padded subtree vanished unexpectedly".into())
                })?
            };
            if pos == 0 {
                view.left = Some(next_child);
            } else {
                view.entries[pos - 1].tree = Some(next_child);
            }
            self.store_node(view)
        })
    }

    fn pad_to_layer(
        &mut self,
        child: Option<Cid>,
        from_layer: usize,
        to_layer: usize,
    ) -> BoxFuture<'_, Result<Option<Cid>, MstError>> {
        Box::pin(async move {
            let Some(mut cur) = child else {
                return Ok(None);
            };
            let actual_layer = self.node_layer(&cur).await?.unwrap_or(from_layer);
            for _ in actual_layer..to_layer {
                cur = self.store_node(MstNodeView {
                    left: Some(cur),
                    entries: Vec::new(),
                })?;
            }
            Ok(Some(cur))
        })
    }

    #[allow(clippy::too_many_lines)]
    fn split_around<'a>(
        &'a mut self,
        node_cid: &'a Cid,
        key: &'a str,
        allow_overwrite: bool,
    ) -> BoxFuture<'a, Result<SplitPair, MstError>> {
        Box::pin(async move {
            let view = self.load_node(node_cid).await?;
            if view.entries.is_empty() {
                return match view.left {
                    Some(left_cid) => {
                        let (l, r) = self.split_around(&left_cid, key, allow_overwrite).await?;
                        let wrapped_l = match l {
                            Some(lc) => Some(self.store_node(MstNodeView {
                                left: Some(lc),
                                entries: Vec::new(),
                            })?),
                            None => None,
                        };
                        let wrapped_r = match r {
                            Some(rc) => Some(self.store_node(MstNodeView {
                                left: Some(rc),
                                entries: Vec::new(),
                            })?),
                            None => None,
                        };
                        Ok((wrapped_l, wrapped_r))
                    }
                    None => Ok((None, None)),
                };
            }

            let key_bytes = key.as_bytes();
            let pos = view
                .entries
                .partition_point(|entry| entry.key.as_bytes() < key_bytes);
            if pos < view.entries.len() && view.entries[pos].key == key && !allow_overwrite {
                return Err(MstError::DuplicateKey(key.to_owned()));
            }

            let mut left_entries = view.entries[..pos].to_vec();
            let right_entries = if pos < view.entries.len() && view.entries[pos].key == key {
                view.entries[pos + 1..].to_vec()
            } else {
                view.entries[pos..].to_vec()
            };

            let mid_child = if pos == 0 {
                view.left.clone()
            } else {
                left_entries.last().and_then(|e| e.tree.clone())
            };

            let (mid_left, mid_right) = match mid_child {
                Some(child) => self.split_around(&child, key, allow_overwrite).await?,
                None => (None, None),
            };

            let left_tree = if pos == 0 {
                mid_left
                    .map(|cid| {
                        self.store_node(MstNodeView {
                            left: Some(cid),
                            entries: Vec::new(),
                        })
                    })
                    .transpose()?
            } else {
                if let Some(last) = left_entries.last_mut() {
                    last.tree = mid_left;
                }
                let node = MstNodeView {
                    left: view.left.clone(),
                    entries: left_entries,
                };
                if node.left.is_none() && node.entries.is_empty() {
                    None
                } else {
                    Some(self.store_node(node)?)
                }
            };

            let right_tree = if right_entries.is_empty() {
                mid_right
                    .map(|cid| {
                        self.store_node(MstNodeView {
                            left: Some(cid),
                            entries: Vec::new(),
                        })
                    })
                    .transpose()?
            } else if pos < view.entries.len() && view.entries[pos].key == key {
                // When overwriting an identical key, its old `tree` child moves into `right_entries` left edge.
                let overwritten_right = view.entries[pos].tree.clone();
                let merged = match (mid_right, overwritten_right) {
                    (None, None) => None,
                    (Some(a), None) => Some(a),
                    (None, Some(b)) => Some(b),
                    (Some(a), Some(b)) => Some(self.merge_trees(a, b).await?),
                };
                let node = MstNodeView {
                    left: merged,
                    entries: right_entries,
                };
                Some(self.store_node(node)?)
            } else {
                let node = MstNodeView {
                    left: mid_right,
                    entries: right_entries,
                };
                Some(self.store_node(node)?)
            };

            Ok((left_tree, right_tree))
        })
    }

    fn delete_at<'a>(
        &'a mut self,
        node_cid: &'a Cid,
        key: &'a str,
    ) -> BoxFuture<'a, Result<Option<Cid>, MstError>> {
        Box::pin(async move {
            let mut view = self.load_node(node_cid).await?;
            if view.entries.is_empty() {
                let Some(left_cid) = view.left else {
                    return Err(MstError::MissingKey(key.to_owned()));
                };
                let updated = self.delete_at(&left_cid, key).await?;
                return match updated {
                    Some(cid) => Ok(Some(self.store_node(MstNodeView {
                        left: Some(cid),
                        entries: Vec::new(),
                    })?)),
                    None => Ok(None),
                };
            }

            let key_bytes = key.as_bytes();
            let pos = view
                .entries
                .partition_point(|entry| entry.key.as_bytes() < key_bytes);
            if pos < view.entries.len() && view.entries[pos].key == key {
                let removed = view.entries.remove(pos);
                let left_sibling = if pos == 0 {
                    view.left.clone()
                } else {
                    view.entries[pos - 1].tree.clone()
                };
                let merged = match (left_sibling, removed.tree) {
                    (None, None) => None,
                    (Some(a), None) => Some(a),
                    (None, Some(b)) => Some(b),
                    (Some(a), Some(b)) => Some(self.merge_trees(a, b).await?),
                };
                if pos == 0 {
                    view.left = merged;
                } else {
                    view.entries[pos - 1].tree = merged;
                }
                if view.entries.is_empty() && view.left.is_none() {
                    return Ok(None);
                }
                return Ok(Some(self.store_node(view)?));
            }

            let target_child = if pos == 0 {
                view.left.take()
            } else {
                view.entries[pos - 1].tree.take()
            };
            let Some(child_cid) = target_child else {
                return Err(MstError::MissingKey(key.to_owned()));
            };
            let updated_child = self.delete_at(&child_cid, key).await?;
            if pos == 0 {
                view.left = updated_child;
            } else {
                view.entries[pos - 1].tree = updated_child;
            }
            if view.entries.is_empty() && view.left.is_none() {
                Ok(None)
            } else {
                Ok(Some(self.store_node(view)?))
            }
        })
    }

    fn merge_trees(
        &mut self,
        left_cid: Cid,
        right_cid: Cid,
    ) -> BoxFuture<'_, Result<Cid, MstError>> {
        Box::pin(async move {
            let mut left_view = self.load_node(&left_cid).await?;
            let right_view = self.load_node(&right_cid).await?;

            // Both `left_cid` and `right_cid` sit at the same tree depth because
            // intermediate layers are never skipped in canonical MSTs.
            let boundary_left = left_view.entries.last().and_then(|e| e.tree.clone());
            let boundary_right = right_view.left.clone();

            let merged_middle = match (boundary_left, boundary_right) {
                (None, None) => None,
                (Some(a), None) => Some(a),
                (None, Some(b)) => Some(b),
                (Some(a), Some(b)) => Some(self.merge_trees(a, b).await?),
            };

            if let Some(last) = left_view.entries.last_mut() {
                last.tree = merged_middle;
                left_view.entries.extend(right_view.entries);
                self.store_node(left_view)
            } else {
                let merged_left = match (left_view.left, merged_middle) {
                    (None, m) => m,
                    (Some(l), None) => Some(l),
                    (Some(l), Some(m)) => Some(self.merge_trees(l, m).await?),
                };
                self.store_node(MstNodeView {
                    left: merged_left,
                    entries: right_view.entries,
                })
            }
        })
    }

    fn trim_top(&mut self, mut root: Cid) -> BoxFuture<'_, Result<Cid, MstError>> {
        Box::pin(async move {
            loop {
                let view = self.load_node(&root).await?;
                if view.entries.is_empty()
                    && let Some(left) = view.left
                {
                    root = left;
                    continue;
                }
                return Ok(root);
            }
        })
    }
}

/// Builds a canonical AT Protocol MST directly in memory in `O(N * max_height)`
/// time from `(key, value)` pairs (`BulkMST`).
pub fn build_mst_from_entries<I>(
    entries: I,
    options: MstOptions,
) -> Result<(RepositoryMst, Vec<RepositoryBlock>), MstError>
where
    I: IntoIterator<Item = (String, Cid)>,
{
    let mut map: HashMap<String, Cid> = HashMap::new();
    for (k, v) in entries {
        validate_mst_key(&k, options.key_syntax)?;
        if options.policy.requires_blessed_record_links_in_mst && !v.is_blessed() {
            return Err(MstError::UnblessedLink(v.to_string()));
        }
        map.insert(k, v);
    }
    if map.is_empty() {
        let tree = RepositoryMst::empty_with_options(options);
        let blocks = tree.new_blocks();
        return Ok((tree, blocks));
    }
    let mut sorted: Vec<(String, Cid, usize)> = map
        .into_iter()
        .map(|(k, v)| {
            let h = key_depth(k.as_bytes());
            (k, v, h)
        })
        .collect();
    sorted.sort_by(|a, b| a.0.cmp(&b.0));

    let mut out_blocks: BTreeMap<Cid, Vec<u8>> = BTreeMap::new();
    let Some((root_cid, _)) = build_bulk_slice(&sorted, &mut out_blocks)? else {
        let tree = RepositoryMst::empty_with_options(options);
        let blocks = tree.new_blocks();
        return Ok((tree, blocks));
    };
    let blocks: Vec<RepositoryBlock> = out_blocks
        .iter()
        .map(|(cid, bytes)| RepositoryBlock::new(cid.clone(), bytes.clone()))
        .collect();
    let store = Arc::new(crate::block_store::InMemoryBlockStore::from_blocks(
        out_blocks,
    )?);
    let tree = RepositoryMst::open_with_options(root_cid, store, options);
    Ok((tree, blocks))
}

fn build_bulk_slice(
    entries: &[(String, Cid, usize)],
    out: &mut BTreeMap<Cid, Vec<u8>>,
) -> Result<Option<(Cid, usize)>, MstError> {
    if entries.is_empty() {
        return Ok(None);
    }
    let layer = entries.iter().map(|e| e.2).max().unwrap_or(0);
    let positions: Vec<usize> = entries
        .iter()
        .enumerate()
        .filter_map(|(i, e)| (e.2 == layer).then_some(i))
        .collect();

    let first_pos = positions[0];
    let left_child = build_bulk_slice(&entries[..first_pos], out)?;
    let left = pad_bulk_child(left_child, layer, out)?;

    let mut node_entries = Vec::with_capacity(positions.len());
    for idx in 0..positions.len() {
        let cur = positions[idx];
        let next = if idx + 1 < positions.len() {
            positions[idx + 1]
        } else {
            entries.len()
        };
        let right_child = build_bulk_slice(&entries[cur + 1..next], out)?;
        let right = pad_bulk_child(right_child, layer, out)?;
        node_entries.push(MstNodeEntryView {
            key: entries[cur].0.clone(),
            value: entries[cur].1.clone(),
            tree: right,
        });
    }

    let (cid, bytes) = encode_mst_node(&MstNodeView {
        left,
        entries: node_entries,
    })?;
    out.insert(cid.clone(), bytes);
    Ok(Some((cid, layer)))
}

fn pad_bulk_child(
    child: Option<(Cid, usize)>,
    parent_layer: usize,
    out: &mut BTreeMap<Cid, Vec<u8>>,
) -> Result<Option<Cid>, MstError> {
    let Some((mut cid, mut layer)) = child else {
        return Ok(None);
    };
    while layer + 1 < parent_layer {
        layer += 1;
        let (wrapped_cid, wrapped_bytes) = encode_mst_node(&MstNodeView {
            left: Some(cid),
            entries: Vec::new(),
        })?;
        out.insert(wrapped_cid.clone(), wrapped_bytes);
        cid = wrapped_cid;
    }
    Ok(Some(cid))
}
