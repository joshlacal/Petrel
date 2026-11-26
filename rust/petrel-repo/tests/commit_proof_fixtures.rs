mod common;

use std::collections::BTreeSet;
use std::sync::Arc;

use petrel_core::Cid;
use petrel_repo::block_store::{BlockSource as _, BlockStore as _, InMemoryBlockStore};
use petrel_repo::mst::{MstKeySyntax, MstOptions, RepositoryMst};
use petrel_repo::types::RepositoryReadPolicy;
use serde::Deserialize;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CommitProofFixture {
    comment: String,
    leaf_value: String,
    keys: Vec<String>,
    adds: Vec<String>,
    dels: Vec<String>,
    root_before_commit: String,
    root_after_commit: String,
    blocks_in_proof: Vec<String>,
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn firehose_commit_proof_fixtures_match_roots_and_proof_blocks() {
    let fixtures: Vec<CommitProofFixture> =
        serde_json::from_str(common::commit_proof_fixtures_json()).unwrap();
    assert!(!fixtures.is_empty());

    let options = MstOptions {
        key_syntax: MstKeySyntax::TwoSegment,
        policy: RepositoryReadPolicy::data_model(),
        require_canonical_prefix: true,
        ..MstOptions::default()
    };

    for fixture in fixtures {
        let leaf = Cid::parse(&fixture.leaf_value).unwrap();
        let initial: Vec<(String, Cid)> = fixture
            .keys
            .iter()
            .map(|k| (k.clone(), leaf.clone()))
            .collect();
        let (mut tree, before_store) = common::build_raw_mst(initial, MstKeySyntax::TwoSegment);
        assert_eq!(
            tree.root_cid().to_string(),
            fixture.root_before_commit,
            "rootBeforeCommit mismatch for fixture `{}`",
            fixture.comment
        );

        for add in &fixture.adds {
            tree.insert(add, leaf.clone()).await.unwrap();
        }
        for del in &fixture.dels {
            tree.delete(del).await.unwrap();
        }
        assert_eq!(
            tree.root_cid().to_string(),
            fixture.root_after_commit,
            "rootAfterCommit mismatch for fixture `{}`",
            fixture.comment
        );

        // Compute new MST blocks + covering proof blocks across touched keys, mirroring
        // ATProto firehose commit proof collection.
        let mut touched: Vec<String> = fixture.adds.clone();
        touched.extend(fixture.dels.clone());
        let new_blocks = tree
            .new_blocks_since(Some(&Cid::parse(&fixture.root_before_commit).unwrap()))
            .await
            .unwrap();
        let new_cids: BTreeSet<String> = new_blocks.iter().map(|b| b.cid.to_string()).collect();
        let expected_cids: BTreeSet<String> = fixture.blocks_in_proof.iter().cloned().collect();

        // Every new block created by the mutation must be in `blocksInProof`,
        // and inverting adds/dels using ONLY `blocksInProof` blocks reproduces `rootBeforeCommit`.
        assert!(
            new_cids.is_subset(&expected_cids),
            "new blocks {:?} not subset of expected {:?} in `{}`",
            new_cids,
            expected_cids,
            fixture.comment
        );

        // Populate a proof-only store containing exclusively `blocksInProof` blocks.
        let after_reachable = tree.reachable_node_blocks().await.unwrap();
        let proof_only_store = Arc::new(InMemoryBlockStore::new());
        for cid_str in &fixture.blocks_in_proof {
            let cid = Cid::parse(cid_str).unwrap();
            if let Some(b) = after_reachable.get(&cid) {
                proof_only_store.put_block(&cid, b).await.unwrap();
            } else if let Some(b) = before_store.get_block(&cid).await.unwrap() {
                proof_only_store.put_block(&cid, &b).await.unwrap();
            }
        }

        // Invert ops directly over `proof_only_store` starting from `rootAfterCommit`!
        let mut inverted = RepositoryMst::open_with_options(
            Cid::parse(&fixture.root_after_commit).unwrap(),
            proof_only_store,
            options,
        );
        for del in fixture.dels.iter().rev() {
            inverted.insert(del, leaf.clone()).await.unwrap();
        }
        for add in fixture.adds.iter().rev() {
            inverted.delete(add).await.unwrap();
        }
        assert_eq!(
            inverted.root_cid().to_string(),
            fixture.root_before_commit,
            "inversion over blocksInProof failed for `{}`",
            fixture.comment
        );

        // Verify membership / exclusion for adds & dels against full `after_reachable` store
        let after_store = InMemoryBlockStore::from_blocks(after_reachable).unwrap();
        for add in &fixture.adds {
            common::check_inclusion_and_exclusion(
                tree.root_cid(),
                add,
                Some(&leaf),
                &after_store,
                MstKeySyntax::TwoSegment,
            )
            .await;
        }
        for del in &fixture.dels {
            common::check_inclusion_and_exclusion(
                tree.root_cid(),
                del,
                None,
                &after_store,
                MstKeySyntax::TwoSegment,
            )
            .await;
        }
    }
}
