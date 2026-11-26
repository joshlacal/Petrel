use std::collections::BTreeMap;

use petrel::rt::BoxFuture;
use petrel_core::Cid;
use petrel_core::cid::BlessedKind;

use crate::block_store::{BlockMap, BlockSource};
use crate::error::MstError;
use crate::mst::codec::{decode_mst_node, key_depth, validate_mst_key};
use crate::mst::tree::MstOptions;

/// Inclusion and exclusion proofs against a partial or full MST block store
/// (`RepositoryMSTProof`).
#[derive(Debug, Clone, Copy, Default)]
pub struct MstProof;

impl MstProof {
    /// Verifies whether `key` exists or is proven absent under `root_cid` using
    /// only the MST node blocks along `key`'s search path in `source`.
    ///
    /// - Returns `Ok(Some(cid))` if an inclusion proof succeeds.
    /// - Returns `Ok(None)` if a complete exclusion proof succeeds (either the
    ///   search path ends at a `None` child pointer or an empty root).
    /// - Returns `Err(MstError::MissingBlock(_))` if a required block on the
    ///   search path is missing, or height/ordering/CID invariants fail along the path.
    pub async fn verify_membership(
        root_cid: &Cid,
        key: &str,
        source: &dyn BlockSource,
        options: &MstOptions,
    ) -> Result<Option<Cid>, MstError> {
        validate_mst_key(key, options.key_syntax)?;
        let expected_key_depth = key_depth(key.as_bytes());
        verify_path(
            root_cid,
            key,
            expected_key_depth,
            source,
            options,
            None,
            None,
            None,
            0,
        )
        .await
    }

    /// Asserts that `key` resolves to `expected_cid` in `root_cid`.
    pub async fn verify_inclusion(
        root_cid: &Cid,
        key: &str,
        expected_cid: &Cid,
        source: &dyn BlockSource,
        options: &MstOptions,
    ) -> Result<(), MstError> {
        match Self::verify_membership(root_cid, key, source, options).await? {
            Some(actual) if &actual == expected_cid => Ok(()),
            Some(actual) => Err(MstError::InvalidProof(format!(
                "key {key:?} resolved to {actual}, expected {expected_cid}"
            ))),
            None => Err(MstError::InvalidProof(format!(
                "key {key:?} proven absent, expected {expected_cid}"
            ))),
        }
    }

    /// Asserts that `key` is proven absent from `root_cid`.
    pub async fn verify_exclusion(
        root_cid: &Cid,
        key: &str,
        source: &dyn BlockSource,
        options: &MstOptions,
    ) -> Result<(), MstError> {
        match Self::verify_membership(root_cid, key, source, options).await? {
            None => Ok(()),
            Some(actual) => Err(MstError::InvalidProof(format!(
                "key {key:?} exists with value {actual}, expected exclusion"
            ))),
        }
    }

    /// Collects the proof block set (`BlockMap`) for a single `key` from `root_cid`.
    pub async fn build_proof_blocks(
        root_cid: &Cid,
        key: &str,
        source: &dyn BlockSource,
        options: &MstOptions,
    ) -> Result<BlockMap, MstError> {
        validate_mst_key(key, options.key_syntax)?;
        let mut out = BTreeMap::new();
        collect_proof_path(root_cid, key, source, options, &mut out, 0).await?;
        Ok(out)
    }
}

#[allow(clippy::too_many_arguments, clippy::too_many_lines)]
fn verify_path<'a>(
    node_cid: &'a Cid,
    key: &'a str,
    expected_key_depth: usize,
    source: &'a dyn BlockSource,
    options: &'a MstOptions,
    expected_layer: Option<usize>,
    lower_bound: Option<String>,
    upper_bound: Option<String>,
    depth: usize,
) -> BoxFuture<'a, Result<Option<Cid>, MstError>> {
    Box::pin(async move {
        if depth > options.max_depth {
            return Err(MstError::DepthExceeded {
                depth,
                limit: options.max_depth,
            });
        }
        let bytes = source
            .get_block(node_cid)
            .await?
            .ok_or_else(|| MstError::MissingBlock(node_cid.clone()))?;
        if node_cid.blessed_kind() != Some(BlessedKind::DagCbor)
            || !node_cid.matches_content(&bytes)
        {
            return Err(MstError::InvalidProof(format!(
                "proof node CID hash mismatch for {node_cid}"
            )));
        }
        let view = decode_mst_node(
            &bytes,
            options.key_syntax,
            &options.policy,
            options.require_canonical_prefix,
        )?;

        if let (Some(lb), Some(first)) = (&lower_bound, view.entries.first())
            && first.key.as_bytes() <= lb.as_bytes()
        {
            return Err(MstError::KeyOrderViolation {
                previous: lb.clone(),
                next: first.key.clone(),
            });
        }
        if let (Some(ub), Some(last)) = (&upper_bound, view.entries.last())
            && last.key.as_bytes() >= ub.as_bytes()
        {
            return Err(MstError::KeyOrderViolation {
                previous: last.key.clone(),
                next: ub.clone(),
            });
        }

        if view.entries.is_empty() {
            return if let Some(left_cid) = view.left {
                if depth == 0 {
                    return Err(MstError::NonCanonical(
                        "non-empty MST root cannot have zero entries and a left pointer".into(),
                    ));
                }
                if expected_layer == Some(0) {
                    return Err(MstError::InvalidNode(
                        "layer-0 node cannot point to a left subtree".into(),
                    ));
                }
                let next_layer = expected_layer.and_then(|l| l.checked_sub(1));
                verify_path(
                    &left_cid,
                    key,
                    expected_key_depth,
                    source,
                    options,
                    next_layer,
                    lower_bound,
                    upper_bound,
                    depth + 1,
                )
                .await
            } else {
                if depth != 0 {
                    return Err(MstError::NonCanonical(
                        "empty MST node only permitted as tree root".into(),
                    ));
                }
                Ok(None)
            };
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

        let key_bytes = key.as_bytes();
        let pos = view
            .entries
            .partition_point(|entry| entry.key.as_bytes() < key_bytes);
        if pos < view.entries.len() && view.entries[pos].key == key {
            if expected_key_depth != node_layer {
                return Err(MstError::KeyHeightMismatch {
                    key: key.to_owned(),
                    actual: expected_key_depth,
                    expected: node_layer,
                });
            }
            return Ok(Some(view.entries[pos].value.clone()));
        }

        // Key is absent from this node. If `expected_key_depth >= node_layer`,
        // a matching key would have belonged at or above this layer, so it cannot
        // exist below — provided we check whether `node_layer == expected_key_depth`!
        let child = if pos == 0 {
            view.left.clone()
        } else {
            view.entries[pos - 1].tree.clone()
        };
        let next_lower = if pos == 0 {
            lower_bound
        } else {
            Some(view.entries[pos - 1].key.clone())
        };
        let next_upper = if pos < view.entries.len() {
            Some(view.entries[pos].key.clone())
        } else {
            upper_bound
        };
        match child {
            Some(child_cid) => {
                if node_layer == 0 {
                    return Err(MstError::InvalidProof(format!(
                        "layer-0 node {node_cid} cannot reference non-empty subtree"
                    )));
                }
                verify_path(
                    &child_cid,
                    key,
                    expected_key_depth,
                    source,
                    options,
                    Some(node_layer - 1),
                    next_lower,
                    next_upper,
                    depth + 1,
                )
                .await
            }
            None => Ok(None),
        }
    })
}

fn collect_proof_path<'a>(
    node_cid: &'a Cid,
    key: &'a str,
    source: &'a dyn BlockSource,
    options: &'a MstOptions,
    out: &'a mut BlockMap,
    depth: usize,
) -> BoxFuture<'a, Result<(), MstError>> {
    Box::pin(async move {
        if depth > options.max_depth {
            return Err(MstError::DepthExceeded {
                depth,
                limit: options.max_depth,
            });
        }
        let bytes = source
            .get_block(node_cid)
            .await?
            .ok_or_else(|| MstError::MissingBlock(node_cid.clone()))?;
        let view = decode_mst_node(
            &bytes,
            options.key_syntax,
            &options.policy,
            options.require_canonical_prefix,
        )?;
        out.insert(node_cid.clone(), bytes);
        if view.entries.is_empty() {
            if let Some(left) = view.left {
                collect_proof_path(&left, key, source, options, out, depth + 1).await?;
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
        let child = if pos == 0 {
            view.left.clone()
        } else {
            view.entries[pos - 1].tree.clone()
        };
        if let Some(child_cid) = child {
            collect_proof_path(&child_cid, key, source, options, out, depth + 1).await?;
        }
        Ok(())
    })
}
