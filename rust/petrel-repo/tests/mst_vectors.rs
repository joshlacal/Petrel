mod common;

use petrel_core::Cid;
use petrel_repo::mst::codec::{common_prefix_len, key_depth};
use petrel_repo::mst::{MstKeySyntax, MstOptions, MstValidation, RepositoryMst};
use petrel_repo::types::RepositoryReadPolicy;
use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct CommonPrefixVector {
    left: String,
    right: String,
    len: usize,
}

#[derive(Debug, Deserialize)]
struct KeyHeightVector {
    key: String,
    height: usize,
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn official_common_prefix_vectors() {
    let vectors: Vec<CommonPrefixVector> =
        serde_json::from_str(common::mst_common_prefix_json()).unwrap();
    assert_eq!(vectors.len(), 13);
    for vec in vectors {
        assert_eq!(
            common_prefix_len(vec.left.as_bytes(), vec.right.as_bytes()),
            vec.len,
            "left={:?} right={:?}",
            vec.left,
            vec.right
        );
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn official_key_height_vectors() {
    let vectors: Vec<KeyHeightVector> =
        serde_json::from_str(common::mst_key_heights_json()).unwrap();
    assert_eq!(vectors.len(), 9);
    for vec in vectors {
        assert_eq!(
            key_depth(vec.key.as_bytes()),
            vec.height,
            "key={:?}",
            vec.key
        );
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn example_keys_vector_order_independence_and_validation() {
    let leaf = Cid::parse("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454").unwrap();
    let keys: Vec<String> = common::mst_example_keys_txt()
        .lines()
        .map(str::trim)
        .filter(|l| !l.is_empty())
        .map(str::to_owned)
        .collect();
    assert_eq!(keys.len(), 156);

    // 1. Bulk build (sorted)
    let bulk_entries: Vec<(String, Cid)> = keys.iter().map(|k| (k.clone(), leaf.clone())).collect();
    let (mut bulk_tree, _) = common::build_raw_mst(bulk_entries, MstKeySyntax::TwoSegment);

    // 2. Forward sequential insert
    let options = MstOptions {
        key_syntax: MstKeySyntax::TwoSegment,
        policy: RepositoryReadPolicy::data_model(),
        ..MstOptions::default()
    };
    let mut forward_tree = RepositoryMst::empty_with_options(options);
    for k in &keys {
        forward_tree.insert(k, leaf.clone()).await.unwrap();
    }
    assert_eq!(forward_tree.root_cid(), bulk_tree.root_cid());

    // 3. Reverse sequential insert
    let mut reverse_tree = RepositoryMst::empty_with_options(options);
    for k in keys.iter().rev() {
        reverse_tree.insert(k, leaf.clone()).await.unwrap();
    }
    assert_eq!(reverse_tree.root_cid(), bulk_tree.root_cid());

    // 4. Deterministically shuffled insert (LCG permutation)
    let mut shuffled = keys.clone();
    let mut rng_state = 0x517c_c1b7_2722_0a95_u64;
    for i in (1..shuffled.len()).rev() {
        rng_state = rng_state
            .wrapping_mul(6_364_136_223_846_793_005)
            .wrapping_add(1);
        let j = usize::try_from(rng_state % ((i + 1) as u64)).unwrap();
        shuffled.swap(i, j);
    }
    let mut shuffled_tree = RepositoryMst::empty_with_options(options);
    for k in &shuffled {
        shuffled_tree.insert(k, leaf.clone()).await.unwrap();
    }
    assert_eq!(shuffled_tree.root_cid(), bulk_tree.root_cid());

    // Validate full structure against `MstValidation`
    let blocks = shuffled_tree.reachable_node_blocks().await.unwrap();
    let store = petrel_repo::block_store::InMemoryBlockStore::from_blocks(blocks).unwrap();
    let (mst_stats, entries) =
        MstValidation::validate_full(shuffled_tree.root_cid(), &store, &options, 10_000, false)
            .await
            .unwrap();
    assert_eq!(mst_stats.record_count, 156);
    assert_eq!(entries.len(), 156);
    assert_eq!(bulk_tree.all_entries().await.unwrap().len(), 156);

    // Proof inclusion & exclusion checks across samples
    common::check_inclusion_and_exclusion(
        shuffled_tree.root_cid(),
        &keys[0],
        Some(&leaf),
        &store,
        MstKeySyntax::TwoSegment,
    )
    .await;
    common::check_inclusion_and_exclusion(
        shuffled_tree.root_cid(),
        &keys[77],
        Some(&leaf),
        &store,
        MstKeySyntax::TwoSegment,
    )
    .await;
    common::check_inclusion_and_exclusion(
        shuffled_tree.root_cid(),
        "A0/999999",
        None,
        &store,
        MstKeySyntax::TwoSegment,
    )
    .await;

    // Delete everything back down to canonical empty MST
    for k in &shuffled {
        shuffled_tree.delete(k).await.unwrap();
    }
    assert_eq!(
        shuffled_tree.root_cid().to_string(),
        petrel_repo::CANONICAL_EMPTY_MST_CID
    );
}
