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
