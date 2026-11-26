mod common;

use std::collections::BTreeMap;
use std::sync::Arc;

use petrel_core::{Cid, Value, dagcbor};
use petrel_repo::block_store::{BlockStore as _, InMemoryBlockStore, RepositoryBlock};
use petrel_repo::error::MstError;
use petrel_repo::mst::codec::{MstNodeEntryView, MstNodeView, decode_mst_node, encode_mst_node};
use petrel_repo::mst::{
    MstKeySyntax, MstOptions, MstProof, MstValidation, MstWalkOptions, MstWalker, RepositoryMst,
    build_mst_from_entries,
};
use petrel_repo::types::RepositoryReadPolicy;

fn synthetic_val(tag: usize) -> Cid {
    let mut map = BTreeMap::new();
    map.insert("$type".to_owned(), Value::String("com.example.test".into()));
    map.insert(
        "tag".to_owned(),
        Value::Integer(i64::try_from(tag).unwrap()),
    );
    Cid::for_dag_cbor(&dagcbor::encode(&Value::Object(map)))
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn mst_mutation_differential_against_bulk_builder() {
    let options = MstOptions {
        key_syntax: MstKeySyntax::StrictAtProto,
        policy: RepositoryReadPolicy::strict(),
        require_canonical_prefix: true,
        ..MstOptions::default()
    };

    let mut oracle: BTreeMap<String, Cid> = BTreeMap::new();
    let mut incremental = RepositoryMst::empty_with_options(options);

    let mut rng = 0x9e37_79b9_7f4a_7c15_u64;
    for step in 0..160_usize {
        rng = rng
            .wrapping_mul(6_364_136_223_846_793_005)
            .wrapping_add(1_442_695_040_888_963_407);
        let bucket = ((rng >> 32) as usize) % 45;
        let key = format!("com.example.item/r{bucket:03}");
        let op = ((rng >> 16) as usize) % 5;

        if !oracle.contains_key(&key) {
            let cid = synthetic_val(step);
            oracle.insert(key.clone(), cid.clone());
            incremental.insert(&key, cid).await.unwrap();
        } else if op == 0 {
            oracle.remove(&key);
            incremental.delete(&key).await.unwrap();
        } else {
            let cid = synthetic_val(step + 10_000);
            oracle.insert(key.clone(), cid.clone());
            incremental.update(&key, cid).await.unwrap();
        }

        let (bulk_tree, _) = build_mst_from_entries(oracle.clone(), options).unwrap();
        assert_eq!(
            incremental.root_cid(),
            bulk_tree.root_cid(),
            "root CID diverged at step {step}"
        );
    }

    // Verify full walk, validation, and point lookups on final state
    let blocks = incremental.reachable_node_blocks().await.unwrap();
    let store: Arc<dyn petrel_repo::block_store::BlockSource> =
        Arc::new(InMemoryBlockStore::from_blocks(blocks).unwrap());

    let walker = MstWalker::new(MstWalkOptions {
        mst_options: options,
        max_record_count: 1000,
        verify_block_hashes: true,
    });
    let (mst_entries, progress) = walker
        .collect_entries(incremental.root_cid(), &store)
        .await
        .unwrap();
    assert_eq!(mst_entries.len(), oracle.len());
    assert_eq!(progress.visited_entries, oracle.len());
    for (entry, (k, v)) in mst_entries.iter().zip(oracle.iter()) {
        assert_eq!(&entry.key, k);
        assert_eq!(&entry.value, v);
        assert_eq!(incremental.get(k).await.unwrap().as_ref(), Some(v));
    }

    let (stats, _) = MstValidation::validate_full(
        incremental.root_cid(),
        store.as_ref(),
        &options,
        1000,
        false,
    )
    .await
    .unwrap();
    assert_eq!(stats.record_count, oracle.len());

    // Delete all keys back to canonical empty root
    let remaining: Vec<String> = oracle.keys().cloned().collect();
    for k in remaining {
        incremental.delete(&k).await.unwrap();
    }
    assert_eq!(
        incremental.root_cid().to_string(),
        petrel_repo::CANONICAL_EMPTY_MST_CID
    );
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn mst_validation_and_walker_reject_corrupt_structures() {
    let options = MstOptions::default();

    // 1. Key at wrong MST layer (use height-0 or non-matching key height wrapped inside root)
    let leaf_cid = synthetic_val(1);
    let mut non_h0_key = None;
    for i in 0..200 {
        let candidate = format!("com.example.item/k{i}");
        if petrel_repo::mst::codec::key_depth(candidate.as_bytes()) > 0 {
            non_h0_key = Some(candidate);
            break;
        }
    }
    let key_h_gt_0 = non_h0_key.unwrap();
    let expected_layer = petrel_repo::mst::codec::key_depth(key_h_gt_0.as_bytes());
    // Force `key_h_gt_0` under a root wrapper so its layer mismatches!
    let (child_cid, child_bytes) = encode_mst_node(&MstNodeView {
        left: None,
        entries: vec![MstNodeEntryView {
            key: key_h_gt_0.clone(),
            value: leaf_cid.clone(),
            tree: None,
        }],
    })
    .unwrap();
    let (bad_root_cid, bad_root_bytes) = encode_mst_node(&MstNodeView {
        left: Some(child_cid.clone()),
        entries: vec![],
    })
    .unwrap();
    let store = InMemoryBlockStore::from_blocks([
        (child_cid.clone(), child_bytes.clone()),
        (bad_root_cid.clone(), bad_root_bytes),
    ])
    .unwrap();

    let err = MstValidation::validate_full(&bad_root_cid, &store, &options, 100, false)
        .await
        .unwrap_err();
    assert!(matches!(err, MstError::NonCanonical(_)));

    // 2. Two keys of different heights placed into the SAME MST node
    let mut h0_key = None;
    for i in 0..200 {
        let candidate = format!("com.example.item/z{i}");
        if petrel_repo::mst::codec::key_depth(candidate.as_bytes()) == 0 {
            h0_key = Some(candidate);
            break;
        }
    }
    let h0 = h0_key.unwrap();
    let (a, b) = if h0 < key_h_gt_0 {
        (h0, key_h_gt_0.clone())
    } else {
        (key_h_gt_0.clone(), h0)
    };
    let (mixed_cid, mixed_bytes) = encode_mst_node(&MstNodeView {
        left: None,
        entries: vec![
            MstNodeEntryView {
                key: a,
                value: leaf_cid.clone(),
                tree: None,
            },
            MstNodeEntryView {
                key: b,
                value: leaf_cid.clone(),
                tree: None,
            },
        ],
    })
    .unwrap();
    let mixed_store = InMemoryBlockStore::from_blocks([(mixed_cid.clone(), mixed_bytes)]).unwrap();
    let err2 = MstValidation::validate_full(&mixed_cid, &mixed_store, &options, 100, false)
        .await
        .unwrap_err();
    assert!(matches!(err2, MstError::KeyHeightMismatch { .. }));

    // 3. Non-canonical prefix encoding (prefix_len = 0 when keys share prefix)
    let bad_prefix_cbor = {
        let mut e1 = BTreeMap::new();
        e1.insert(
            "k".to_owned(),
            Value::Bytes(b"com.example.item/aaa".to_vec()),
        );
        e1.insert("p".to_owned(), Value::Integer(0));
        e1.insert("t".to_owned(), Value::Null);
        e1.insert("v".to_owned(), Value::Link(leaf_cid.clone()));

        let mut e2 = BTreeMap::new();
        e2.insert(
            "k".to_owned(),
            Value::Bytes(b"com.example.item/aab".to_vec()),
        );
        e2.insert("p".to_owned(), Value::Integer(0));
        e2.insert("t".to_owned(), Value::Null);
        e2.insert("v".to_owned(), Value::Link(leaf_cid.clone()));

        let mut node = BTreeMap::new();
        node.insert(
            "e".to_owned(),
            Value::Array(vec![Value::Object(e1), Value::Object(e2)]),
        );
        node.insert("l".to_owned(), Value::Null);
        dagcbor::encode(&Value::Object(node))
    };
    assert!(matches!(
        decode_mst_node(
            &bad_prefix_cbor,
            MstKeySyntax::StrictAtProto,
            &RepositoryReadPolicy::strict(),
            true
        ),
        Err(MstError::NonCanonical(_))
    ));

    // 4. Walker record count limit enforcement
    let mut entries = Vec::new();
    for i in 0..5_usize {
        entries.push((format!("com.example.item/r{i:02}"), synthetic_val(i)));
    }
    let (tree, blocks) = build_mst_from_entries(entries, options).unwrap();
    let walker_store: Arc<dyn petrel_repo::block_store::BlockSource> = Arc::new(
        InMemoryBlockStore::from_blocks(blocks.into_iter().map(|b| (b.cid, b.bytes))).unwrap(),
    );
    let bounded_walker = MstWalker::new(MstWalkOptions {
        mst_options: options,
        max_record_count: 3,
        verify_block_hashes: true,
    });
    let err_count = bounded_walker
        .collect_entries(tree.root_cid(), &walker_store)
        .await
        .unwrap_err();
    assert!(matches!(err_count, MstError::RecordCountExceeded { .. }));

    // 5. Proof fails with MissingBlock if needed intermediate block is dropped
    let partial = InMemoryBlockStore::new();
    let root_bytes = walker_store
        .get_block(tree.root_cid())
        .await
        .unwrap()
        .unwrap();
    let _ = RepositoryBlock::new(tree.root_cid().clone(), root_bytes);
    let _ = partial.len().await.unwrap();
    let err_proof =
        MstProof::verify_exclusion(tree.root_cid(), "com.example.item/r00", &partial, &options)
            .await
            .unwrap_err();
    assert!(matches!(err_proof, MstError::MissingBlock(_)));
    let _ = expected_layer;
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn new_blocks_since_reads_zero_unchanged_subtrees() {
    use petrel::rt::BoxFuture;
    use petrel_repo::block_store::BlockSource;
    use petrel_repo::error::BlockStoreError;
    use std::sync::atomic::{AtomicUsize, Ordering};

    #[derive(Debug)]
    struct CountingSource {
        inner: InMemoryBlockStore,
        get_calls: AtomicUsize,
    }

    impl BlockSource for CountingSource {
        fn get_block<'a>(
            &'a self,
            cid: &'a Cid,
        ) -> BoxFuture<'a, Result<Option<Vec<u8>>, BlockStoreError>> {
            self.get_calls.fetch_add(1, Ordering::Relaxed);
            self.inner.get_block(cid)
        }

        fn contains_block<'a>(
            &'a self,
            cid: &'a Cid,
        ) -> BoxFuture<'a, Result<bool, BlockStoreError>> {
            self.inner.contains_block(cid)
        }
    }

    let options = MstOptions::default();
    let entries: Vec<(String, Cid)> = (0..250_usize)
        .map(|i| (format!("com.example.item/r{i:04}"), synthetic_val(i)))
        .collect();
    let (mut base_tree, base_blocks) = build_mst_from_entries(entries, options).unwrap();
    let base_root = base_tree.root_cid().clone();
    let base_reachable = base_tree.reachable_node_blocks().await.unwrap();
    let base_node_count = base_reachable.len();

    let source = Arc::new(CountingSource {
        inner: InMemoryBlockStore::from_blocks(base_blocks.into_iter().map(|b| (b.cid, b.bytes)))
            .unwrap(),
        get_calls: AtomicUsize::new(0),
    });

    let mut mutated = RepositoryMst::open_with_options(base_root.clone(), source.clone(), options);
    mutated
        .insert("com.example.item/r0125x", synthetic_val(999_999))
        .await
        .unwrap();

    let reads_before_diff = source.get_calls.load(Ordering::Relaxed);
    let delta = mutated.new_blocks_since(Some(&base_root)).await.unwrap();
    let reads_during_diff = source.get_calls.load(Ordering::Relaxed) - reads_before_diff;

    assert_eq!(reads_during_diff, 0);
    assert!(reads_before_diff < base_node_count / 2);

    let after_reachable = mutated.reachable_node_blocks().await.unwrap();
    let expected_cids: std::collections::BTreeSet<Cid> = after_reachable
        .keys()
        .filter(|cid| !base_reachable.contains_key(*cid))
        .cloned()
        .collect();
    let delta_cids: std::collections::BTreeSet<Cid> = delta.into_iter().map(|b| b.cid).collect();
    assert_eq!(delta_cids, expected_cids);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn mst_proof_and_validation_reject_empty_left_anomalies_and_non_sha256_cids() {
    use petrel::rt::BoxFuture;
    use petrel_repo::block_store::BlockSource;
    use petrel_repo::error::BlockStoreError;

    // A source that allows storing arbitrary bytes under unblessed / non-SHA-256 CIDs
    // (simulating an untrusted network peer, bypassing BlockStore write checks).
    #[derive(Debug, Default)]
    struct UncheckedSource(BTreeMap<Cid, Vec<u8>>);

    impl BlockSource for UncheckedSource {
        fn get_block<'a>(
            &'a self,
            cid: &'a Cid,
        ) -> BoxFuture<'a, Result<Option<Vec<u8>>, BlockStoreError>> {
            Box::pin(async move { Ok(self.0.get(cid).cloned()) })
        }
    }

    let options = MstOptions::default();

    // 1. Empty root node with `left` pointer must fail proof verification as NonCanonical.
    let (leaf_cid, leaf_bytes) = encode_mst_node(&MstNodeView {
        left: None,
        entries: vec![MstNodeEntryView {
            key: "com.example.item/r0".into(),
            value: synthetic_val(1),
            tree: None,
        }],
    })
    .unwrap();
    let (empty_root_cid, empty_root_bytes) = encode_mst_node(&MstNodeView {
        left: Some(leaf_cid.clone()),
        entries: vec![],
    })
    .unwrap();
    let mut store = UncheckedSource::default();
    store.0.insert(leaf_cid.clone(), leaf_bytes.clone());
    store.0.insert(empty_root_cid.clone(), empty_root_bytes);

    let err_empty_root =
        MstProof::verify_membership(&empty_root_cid, "com.example.item/r0", &store, &options)
            .await
            .unwrap_err();
    assert!(matches!(err_empty_root, MstError::NonCanonical(_)));

    // 2. Layer-0 parent node with empty child having `left` pointer must fail InvalidNode.
    // Pick a height-1 key lexicographically after `"com.example.item/r0"` so querying `"com.example.item/r0"` descends `left`.
    let layer1_key = (0..200_usize)
        .map(|i| format!("com.example.item/z{i}"))
        .find(|k| petrel_repo::mst::key_depth(k.as_bytes()) == 1)
        .unwrap();
    let (empty_layer0_cid, empty_layer0_bytes) = encode_mst_node(&MstNodeView {
        left: Some(leaf_cid.clone()),
        entries: vec![],
    })
    .unwrap();
    let (parent_cid, parent_bytes) = encode_mst_node(&MstNodeView {
        left: Some(empty_layer0_cid.clone()),
        entries: vec![MstNodeEntryView {
            key: layer1_key,
            value: synthetic_val(2),
            tree: None,
        }],
    })
    .unwrap();
    store.0.insert(empty_layer0_cid, empty_layer0_bytes);
    store.0.insert(parent_cid.clone(), parent_bytes);
    let err_layer0 =
        MstProof::verify_membership(&parent_cid, "com.example.item/r0", &store, &options)
            .await
            .unwrap_err();
    assert!(matches!(err_layer0, MstError::InvalidNode(_)));

    // 3. Non-SHA-256 (0x13) and Raw (0x55) MST node CIDs are rejected by proof, validation, and walker.
    let sha512_cid = Cid::from_bytes(&{
        let mut raw = vec![0x01, 0x71, 0x13, 0x20];
        raw.extend_from_slice(&[0x11; 32]);
        raw
    })
    .unwrap();
    let raw_cid = Cid::for_raw(&leaf_bytes);
    store.0.insert(sha512_cid.clone(), leaf_bytes.clone());
    store.0.insert(raw_cid.clone(), leaf_bytes);
    let source_arc: Arc<dyn BlockSource> = Arc::new(store);
    let walker = MstWalker::new(MstWalkOptions::default());
    for bad_node in [sha512_cid, raw_cid] {
        assert!(matches!(
            MstProof::verify_membership(
                &bad_node,
                "com.example.item/r0",
                source_arc.as_ref(),
                &options
            )
            .await,
            Err(MstError::InvalidProof(_))
        ));
        assert!(matches!(
            MstValidation::validate_full(&bad_node, source_arc.as_ref(), &options, 10, false).await,
            Err(MstError::InvalidNode(_))
        ));
        assert!(matches!(
            walker.collect_entries(&bad_node, &source_arc).await,
            Err(MstError::InvalidNode(_))
        ));
    }
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn mst_mutation_and_bulk_builder_enforce_depth_and_dag_cbor_leaf_links() {
    let options = MstOptions {
        policy: RepositoryReadPolicy::strict(),
        max_depth: 6,
        ..MstOptions::default()
    };

    // 1. `Cid::for_raw` must be rejected by `build_mst_from_entries`, `insert`, `upsert`, and `update`
    //    under strict policy (`Codex 4697754782`).
    let raw_leaf = Cid::for_raw(b"not-dag-cbor");
    let err_bulk = build_mst_from_entries(
        vec![("com.example.item/r0".to_owned(), raw_leaf.clone())],
        options,
    )
    .unwrap_err();
    assert!(matches!(err_bulk, MstError::UnblessedLink(_)));

    let mut strict_tree = RepositoryMst::empty_with_options(options);
    assert!(matches!(
        strict_tree
            .insert("com.example.item/r0", raw_leaf.clone())
            .await,
        Err(MstError::UnblessedLink(_))
    ));
    assert!(matches!(
        strict_tree
            .upsert("com.example.item/r0", raw_leaf.clone())
            .await,
        Err(MstError::UnblessedLink(_))
    ));
    strict_tree
        .insert("com.example.item/r0", synthetic_val(1))
        .await
        .unwrap();
    assert!(matches!(
        strict_tree.update("com.example.item/r0", raw_leaf).await,
        Err(MstError::UnblessedLink(_))
    ));

    // 2. Sibling empty-wrapper chains deeper than `max_depth` trigger `MstError::DepthExceeded`
    //    during `delete` / `merge_trees` instead of overflowing the stack (`Codex 4697754761`).
    let store = InMemoryBlockStore::new();
    let val_a = synthetic_val(10);
    let val_m = synthetic_val(20);
    let val_z = synthetic_val(30);
    let key_mid = (0..200_usize)
        .map(|i| format!("com.example.item/m{i}"))
        .find(|k| petrel_repo::mst::key_depth(k.as_bytes()) >= 1)
        .unwrap();

    let (mut left_cid, left_bytes) = encode_mst_node(&MstNodeView {
        left: None,
        entries: vec![MstNodeEntryView {
            key: "com.example.item/a0".into(),
            value: val_a,
            tree: None,
        }],
    })
    .unwrap();
    store.put_block(&left_cid, &left_bytes).await.unwrap();
    let (mut right_cid, right_bytes) = encode_mst_node(&MstNodeView {
        left: None,
        entries: vec![MstNodeEntryView {
            key: "com.example.item/z0".into(),
            value: val_z,
            tree: None,
        }],
    })
    .unwrap();
    store.put_block(&right_cid, &right_bytes).await.unwrap();

    for _ in 0..8 {
        let (wrap_left_cid, wrap_left_bytes) = encode_mst_node(&MstNodeView {
            left: Some(left_cid),
            entries: vec![],
        })
        .unwrap();
        store
            .put_block(&wrap_left_cid, &wrap_left_bytes)
            .await
            .unwrap();
        left_cid = wrap_left_cid;

        let (wrap_right_cid, wrap_right_bytes) = encode_mst_node(&MstNodeView {
            left: Some(right_cid),
            entries: vec![],
        })
        .unwrap();
        store
            .put_block(&wrap_right_cid, &wrap_right_bytes)
            .await
            .unwrap();
        right_cid = wrap_right_cid;
    }

    let (root_cid, root_bytes) = encode_mst_node(&MstNodeView {
        left: Some(left_cid),
        entries: vec![MstNodeEntryView {
            key: key_mid.clone(),
            value: val_m,
            tree: Some(right_cid),
        }],
    })
    .unwrap();
    store.put_block(&root_cid, &root_bytes).await.unwrap();

    let mut deep_tree = RepositoryMst::open_with_options(root_cid, Arc::new(store), options);
    assert!(deep_tree.get(&key_mid).await.unwrap().is_some());
    let err_merge = deep_tree.delete(&key_mid).await.unwrap_err();
    assert!(matches!(err_merge, MstError::DepthExceeded { .. }));
}
