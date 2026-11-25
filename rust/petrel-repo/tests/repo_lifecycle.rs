mod common;

use std::collections::BTreeMap;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

use petrel::rt::BoxFuture;
use petrel_core::{Cid, Did, Value, dagcbor};
use petrel_repo::block_store::{BlockSource as _, InMemoryBlockStore, RepositoryBlock};
use petrel_repo::commit::{CommitCodec, CommitDescriptor};
use petrel_repo::crypto::{
    CommitVerifier, FixedSigningKey, K256Keypair, P256Keypair, RepositorySigningKeyResolver,
    SigningAlgorithm, SigningPublicKey,
};
use petrel_repo::diff::{CommitDiff, CommitOperation};
use petrel_repo::engine::RepositoryEngine;
use petrel_repo::error::{CommitError, DomainError, EngineError, LimitError};
use petrel_repo::footprint::RepositoryFootprint;
use petrel_repo::genesis::{
    GenesisCodec, GenesisStore as _, InMemoryGenesisStore, PersistedGenesis,
};
use petrel_repo::limits::RepositoryLimits;
use petrel_repo::mst::MstOptions;
use petrel_repo::reference::ReferenceSurface;
use petrel_repo::repository::{OpenVerification, Repository, create_op, update_op};
use petrel_repo::types::{
    RepositoryPath, RepositoryReadPolicy, RepositoryState, RepositoryTid, WriteBatch, WriteOp,
};

fn post_record_value(text: &str) -> Value {
    let mut map = BTreeMap::new();
    map.insert(
        "$type".to_owned(),
        Value::String("app.bsky.feed.post".into()),
    );
    map.insert("text".to_owned(), Value::String(text.into()));
    Value::Object(map)
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn domain_paths_tids_and_limits_validation() {
    let path = RepositoryPath::new("app.bsky.feed.post", "3lon5dzeaihj2").unwrap();
    assert_eq!(path.mst_key(), "app.bsky.feed.post/3lon5dzeaihj2");
    assert_eq!(RepositoryPath::from_mst_key(path.mst_key()).unwrap(), path);

    assert!(RepositoryPath::from_mst_key("invalid_no_slash").is_err());
    assert!(RepositoryPath::from_mst_key("a.b.c/r1/extra").is_err());

    let t1 = RepositoryTid::from_parts(1_000_000, 3).unwrap();
    let t2 = RepositoryTid::next_after(Some(&t1), 500_000, 3).unwrap();
    assert!(t2 > t1);
    assert!(t2.is_in_future(100_000, 100_000));
    assert!(!t1.is_in_future(900_000, 200_000));

    // Limits validation
    assert!(RepositoryLimits::standard().validate().is_ok());
    assert!(RepositoryLimits::network_scale().validate().is_ok());
    let mut bad = RepositoryLimits::standard();
    bad.max_block_count = 0;
    assert!(matches!(
        bad.validate(),
        Err(LimitError::InvalidConfiguration(_))
    ));

    let mut mismatched = RepositoryLimits::standard();
    mismatched.max_record_count = mismatched.max_block_count + 1;
    assert!(matches!(
        mismatched.validate(),
        Err(LimitError::InvalidConfiguration(_))
    ));

    // Footprint tracking
    let mut fp = RepositoryFootprint::new();
    fp.add_block(128, &RepositoryLimits::standard()).unwrap();
    fp.add_record(128, &RepositoryLimits::standard()).unwrap();
    fp.add_mst_node(2, &RepositoryLimits::standard()).unwrap();
    fp.check_all(&RepositoryLimits::standard()).unwrap();
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn commit_signing_p256_k256_high_s_rejection_and_rotation_retry() {
    let did = common::test_did();
    let empty_mst = Cid::parse(petrel_repo::CANONICAL_EMPTY_MST_CID).unwrap();
    let rev = RepositoryTid::parse("3jzfcijpj2z2a").unwrap();
    let limits = RepositoryLimits::standard();
    let policy = RepositoryReadPolicy::strict();

    let desc = CommitDescriptor {
        did: did.clone(),
        rev: rev.clone(),
        data_cid: empty_mst.clone(),
        prev_cid: None,
    };

    // P-256 roundtrip + did:key roundtrip
    let p256 = P256Keypair::generate().unwrap();
    let p256_did_key = SigningPublicKey::from_did_key(&p256.did_key()).unwrap();
    assert_eq!(p256_did_key.algorithm(), SigningAlgorithm::P256);
    let prepared_p256 = CommitCodec::prepare(&desc, &p256, &limits).await.unwrap();
    let verified_p256 = CommitCodec::verify(
        &prepared_p256.signed_commit_bytes,
        Some(&prepared_p256.cid),
        Some(&did),
        &FixedSigningKey::from_public_key(p256_did_key),
        &policy,
    )
    .await
    .unwrap();
    assert_eq!(verified_p256.cid, prepared_p256.cid);
    assert!(verified_p256.prev_cid.is_none());

    // K-256 roundtrip + did:key roundtrip
    let k256 = K256Keypair::generate().unwrap();
    let k256_did_key = SigningPublicKey::from_did_key(&k256.did_key()).unwrap();
    assert_eq!(k256_did_key.algorithm(), SigningAlgorithm::Secp256k1);
    let k256_prepared = CommitCodec::prepare(&desc, &k256, &limits).await.unwrap();
    let k256_verified = CommitCodec::verify(
        &k256_prepared.signed_commit_bytes,
        Some(&k256_prepared.cid),
        Some(&did),
        &FixedSigningKey::from_public_key(k256_did_key),
        &policy,
    )
    .await
    .unwrap();
    assert_eq!(k256_verified.cid, k256_prepared.cid);

    // High-S malleable signature must be rejected!
    // Construct a high-S secp256k1 signature by negating `s` modulo group order `n`.
    let mut high_s_sig = k256_prepared.signature.clone();
    let k_sig = k256::ecdsa::Signature::from_slice(&high_s_sig).unwrap();
    let (r, s) = k_sig.split_scalars();
    let negated_s = -s;
    let r_bytes: [u8; 32] = r.to_bytes().into();
    let s_bytes: [u8; 32] = negated_s.to_bytes().into();
    let high_s_bytes = [r_bytes.as_slice(), s_bytes.as_slice()].concat();
    high_s_sig.copy_from_slice(&high_s_bytes);
    let Value::Object(mut high_s_map) =
        dagcbor::decode(&k256_prepared.unsigned_commit_bytes).unwrap()
    else {
        unreachable!();
    };
    high_s_map.insert("sig".to_owned(), Value::Bytes(high_s_sig));
    let high_s_cbor = dagcbor::encode(&Value::Object(high_s_map));
    let high_s_err = CommitCodec::verify(
        &high_s_cbor,
        None,
        Some(&did),
        &FixedSigningKey::from_public_key(k256.public_key().clone()),
        &policy,
    )
    .await
    .unwrap_err();
    assert!(matches!(high_s_err, CommitError::HighSSignature));

    // Refresh-once retry on key rotation: stale cached key fails first, forced refresh returns `k256`.
    let rotating = RotatingResolver {
        stale: p256.public_key().clone(),
        fresh: k256.public_key().clone(),
        refreshed: AtomicBool::new(false),
    };
    CommitCodec::verify(
        &k256_prepared.signed_commit_bytes,
        Some(&k256_prepared.cid),
        Some(&did),
        &rotating,
        &policy,
    )
    .await
    .unwrap();
    assert!(rotating.refreshed.load(Ordering::SeqCst));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn legacy_commit_v2_decode_and_verify() {
    let did = common::test_did();
    let signer = P256Keypair::generate().unwrap();
    let data_cid = Cid::parse(petrel_repo::CANONICAL_EMPTY_MST_CID).unwrap();

    let mut v2_unsigned = BTreeMap::new();
    v2_unsigned.insert("data".to_owned(), Value::Link(data_cid.clone()));
    v2_unsigned.insert("did".to_owned(), Value::String(did.as_str().to_owned()));
    v2_unsigned.insert("prev".to_owned(), Value::Null);
    v2_unsigned.insert("version".to_owned(), Value::Integer(2));
    let unsigned_bytes = dagcbor::encode(&Value::Object(v2_unsigned.clone()));
    let sig = signer.sign_sync(&unsigned_bytes).unwrap();
    v2_unsigned.insert("sig".to_owned(), Value::Bytes(sig));
    let v2_bytes = dagcbor::encode(&Value::Object(v2_unsigned));
    let v2_cid = Cid::for_dag_cbor(&v2_bytes);

    assert_eq!(CommitCodec::commit_version(&v2_bytes).unwrap(), 2);
    let verified = CommitCodec::verify_legacy_v2(
        &v2_bytes,
        Some(&v2_cid),
        Some(&did),
        &FixedSigningKey::from_public_key(signer.public_key().clone()),
    )
    .await
    .unwrap();
    assert_eq!(verified.version, 2);
    assert_eq!(verified.data_cid, data_cid);
    assert!(verified.rev.is_none());
}

#[derive(Debug)]
struct RotatingResolver {
    stale: SigningPublicKey,
    fresh: SigningPublicKey,
    refreshed: AtomicBool,
}

impl RepositorySigningKeyResolver for RotatingResolver {
    fn resolve_signing_key<'a>(
        &'a self,
        _did: &'a Did,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<Arc<dyn CommitVerifier>, CommitError>> {
        Box::pin(async move {
            if force_refresh {
                self.refreshed.store(true, Ordering::SeqCst);
                Ok(Arc::new(self.fresh.clone()) as Arc<dyn CommitVerifier>)
            } else {
                Ok(Arc::new(self.stale.clone()) as Arc<dyn CommitVerifier>)
            }
        })
    }
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn genesis_engine_commit_diff_and_reference_surface_lifecycle() {
    let did = common::test_did();
    let signer = K256Keypair::generate().unwrap();
    let limits = RepositoryLimits::standard();
    let policy = RepositoryReadPolicy::strict();
    let store = Arc::new(InMemoryBlockStore::new());
    let genesis_store = InMemoryGenesisStore::new();

    let rev1 = RepositoryTid::from_parts(1_700_000_000_000_000, 0).unwrap();
    let genesis = GenesisCodec::create(&did, &signer, rev1.clone(), 1, store.as_ref(), &limits)
        .await
        .unwrap();
    assert_eq!(
        genesis.empty_mst_cid.to_string(),
        petrel_repo::CANONICAL_EMPTY_MST_CID
    );

    let persisted = PersistedGenesis {
        did: did.clone(),
        commit_cid: genesis.commit.cid.clone(),
        commit_bytes: genesis.commit.signed_commit_bytes.clone(),
        empty_mst_cid: genesis.empty_mst_cid.clone(),
        empty_mst_bytes: genesis.empty_mst_bytes.clone(),
        rev: rev1.clone(),
        signing_key_generation: 1,
    };
    genesis_store.save(&persisted).await.unwrap();
    let reloaded_genesis = genesis_store.load(&did).await.unwrap().unwrap();
    let verified_state = GenesisCodec::verify_persisted(&reloaded_genesis, signer.public_key())
        .await
        .unwrap();
    assert_eq!(
        verified_state.head_commit_cid,
        Some(genesis.commit.cid.clone())
    );

    // Apply commit #1: Create two records
    let rev2 = RepositoryTid::next_after(Some(&rev1), 1_700_000_001_000_000, 0).unwrap();
    let batch1 = WriteBatch::new(vec![
        create_op(
            "app.bsky.feed.post",
            "3lon5dzeaihj2",
            &post_record_value("first"),
        )
        .unwrap(),
        create_op(
            "app.bsky.feed.post",
            "3lon5dzeaihj3",
            &post_record_value("second"),
        )
        .unwrap(),
    ])
    .unwrap();
    let commit_one = RepositoryEngine::apply(
        &verified_state,
        &batch1,
        Some(&genesis.commit.cid),
        rev2.clone(),
        &signer,
        Arc::clone(&store),
        &limits,
        &policy,
    )
    .await
    .unwrap();
    assert_eq!(commit_one.operations.len(), 2);

    // Non-increasing rev rejected
    let bad_rev_err = RepositoryEngine::apply(
        &commit_one.state,
        &WriteBatch::new(vec![
            create_op(
                "app.bsky.feed.post",
                "3lon5dzeaihj4",
                &post_record_value("third"),
            )
            .unwrap(),
        ])
        .unwrap(),
        Some(&commit_one.commit.cid),
        rev2.clone(),
        &signer,
        Arc::clone(&store),
        &limits,
        &policy,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        bad_rev_err,
        EngineError::Domain(DomainError::NonIncreasingRevision { .. })
    ));

    // Stale expected head rejected
    let rev3 = RepositoryTid::next_after(Some(&rev2), 1_700_000_002_000_000, 0).unwrap();
    let bad_head_err = RepositoryEngine::apply(
        &commit_one.state,
        &WriteBatch::new(vec![
            create_op(
                "app.bsky.feed.post",
                "3lon5dzeaihj4",
                &post_record_value("third"),
            )
            .unwrap(),
        ])
        .unwrap(),
        Some(&genesis.commit.cid),
        rev3.clone(),
        &signer,
        Arc::clone(&store),
        &limits,
        &policy,
    )
    .await
    .unwrap_err();
    assert!(matches!(bad_head_err, EngineError::CommitMismatch { .. }));

    // Apply commit #2: mixed Create + Update + Delete
    let del_path = RepositoryPath::new("app.bsky.feed.post", "3lon5dzeaihj2").unwrap();
    let batch2 = WriteBatch::new(vec![
        WriteOp::Delete { path: del_path },
        update_op(
            "app.bsky.feed.post",
            "3lon5dzeaihj3",
            &post_record_value("second-edited"),
        )
        .unwrap(),
        create_op(
            "app.bsky.feed.post",
            "3lon5dzeaihj4",
            &post_record_value("fourth"),
        )
        .unwrap(),
    ])
    .unwrap();
    let commit_two = RepositoryEngine::apply(
        &commit_one.state,
        &batch2,
        Some(&commit_one.commit.cid),
        rev3,
        &signer,
        Arc::clone(&store),
        &limits,
        &policy,
    )
    .await
    .unwrap();
    assert_eq!(commit_two.operations.len(), 3);

    // Verify commit event diff CAR cleanly
    let diff_car = commit_two.diff_car().unwrap();
    let resolver = FixedSigningKey::from_public_key(signer.public_key().clone());
    let verified_event = CommitDiff::verify_commit_event(
        &diff_car,
        &commit_two.commit.cid,
        &did,
        &commit_two.operations,
        commit_two.previous_data_cid.as_ref(),
        &resolver,
        &limits,
        &policy,
    )
    .await
    .unwrap();
    assert_eq!(verified_event.commit.cid, commit_two.commit.cid);

    // Verify sync event CAR (commit + MST root block)
    let root_mst_bytes = store
        .get_block(&commit_two.commit.data_cid)
        .await
        .unwrap()
        .unwrap();
    let sync_car = petrel_repo::PublicRepositoryCAR::write(
        std::slice::from_ref(&commit_two.commit.cid),
        &[
            RepositoryBlock::new(
                commit_two.commit.cid.clone(),
                commit_two.commit.signed_commit_bytes.clone(),
            ),
            RepositoryBlock::new(commit_two.commit.data_cid.clone(), root_mst_bytes),
        ],
    )
    .unwrap();
    let sync_commit = CommitDiff::verify_sync_event(
        &sync_car,
        &commit_two.commit.cid,
        &did,
        &resolver,
        &limits,
        &policy,
    )
    .await
    .unwrap();
    assert_eq!(sync_commit.cid, commit_two.commit.cid);

    // ReferenceSurface import check
    let repo = Repository::open_store(
        commit_two.commit.cid.clone(),
        Arc::clone(&store),
        OpenVerification::SigningKey(signer.public_key().clone()),
        Some(&did),
        limits,
        policy,
        true,
    )
    .await
    .unwrap();
    let full_car = repo.export_car().await.unwrap();
    let imported =
        ReferenceSurface::import_car(&full_car, signer.public_key(), Some(&did), &limits, &policy)
            .await
            .unwrap();
    assert_eq!(imported.records.len(), 2);
    assert!(
        ReferenceSurface::read_record(&imported, "app.bsky.feed.post", "3lon5dzeaihj2", &policy)
            .await
            .unwrap()
            .is_none()
    );
    let rec =
        ReferenceSurface::read_record(&imported, "app.bsky.feed.post", "3lon5dzeaihj3", &policy)
            .await
            .unwrap()
            .unwrap();
    assert_eq!(
        rec.1.get("text"),
        Some(&Value::String("second-edited".into()))
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn commit_relevant_block_budget_and_write_limit_enforcement() {
    let did = common::test_did();
    let signer = P256Keypair::generate().unwrap();
    let store = Arc::new(InMemoryBlockStore::new());
    let state = RepositoryState::new(did, 1).unwrap();
    let rev = RepositoryTid::from_parts(1_700_000_000_000_000, 0).unwrap();

    let mut tight_limits = RepositoryLimits::standard();
    tight_limits.max_writes_per_commit = 2;
    let ops3 = WriteBatch::new(vec![
        create_op("app.bsky.feed.post", "r1", &post_record_value("1")).unwrap(),
        create_op("app.bsky.feed.post", "r2", &post_record_value("2")).unwrap(),
        create_op("app.bsky.feed.post", "r3", &post_record_value("3")).unwrap(),
    ])
    .unwrap();
    let err_writes = RepositoryEngine::apply(
        &state,
        &ops3,
        None,
        rev.clone(),
        &signer,
        Arc::clone(&store),
        &tight_limits,
        &RepositoryReadPolicy::strict(),
    )
    .await
    .unwrap_err();
    assert!(matches!(err_writes, EngineError::Limit(_)));

    // Relevant block bytes budget check
    let mut byte_limits = RepositoryLimits::standard();
    byte_limits.max_relevant_block_bytes = 250;
    let big_text = "x".repeat(400);
    let big_batch = WriteBatch::new(vec![
        create_op("app.bsky.feed.post", "big", &post_record_value(&big_text)).unwrap(),
    ])
    .unwrap();
    let err_budget = RepositoryEngine::apply(
        &state,
        &big_batch,
        None,
        rev,
        &signer,
        store,
        &byte_limits,
        &RepositoryReadPolicy::strict(),
    )
    .await
    .unwrap_err();
    assert!(matches!(
        err_budget,
        EngineError::RelevantBlocksExceedBudget { .. }
    ));
    let _ = CommitOperation::Delete {
        path: RepositoryPath::new("app.bsky.feed.post", "x").unwrap(),
        prev: Cid::parse(petrel_repo::CANONICAL_EMPTY_MST_CID).unwrap(),
    };
    let _ = MstOptions::default();
}

#[allow(clippy::too_many_lines)]
#[cfg(not(target_arch = "wasm32"))]
#[tokio::test]
async fn scale_synthetic_disk_repository_streams_and_enforces_standard_ceilings() {
    use petrel_repo::block_store::BlockStore as _;
    let dir = tempfile::tempdir().unwrap();
    let count = 4_000_usize;
    let did = common::test_did();
    let collection = "com.example.record";
    let signer = K256Keypair::generate().unwrap();

    let mut entries = Vec::with_capacity(count);
    let mut record_blocks = Vec::with_capacity(count);
    for i in 0..count {
        let key = format!("{collection}/r{i:07}");
        let mut rec = BTreeMap::new();
        rec.insert("$type".to_owned(), Value::String(collection.into()));
        rec.insert("n".to_owned(), Value::Integer(i64::try_from(i).unwrap()));
        let bytes = dagcbor::encode(&Value::Object(rec));
        let cid = Cid::for_dag_cbor(&bytes);
        entries.push((key, cid.clone()));
        record_blocks.push(RepositoryBlock::new(cid, bytes));
    }

    let (mst, mst_blocks) =
        petrel_repo::mst::tree::build_mst_from_entries(entries, MstOptions::default()).unwrap();
    let rev = RepositoryTid::parse("3jzfcijpj2z2a").unwrap();
    let commit = CommitCodec::prepare(
        &CommitDescriptor {
            did: did.clone(),
            rev,
            data_cid: mst.root_cid().clone(),
            prev_cid: None,
        },
        &signer,
        &RepositoryLimits::network_scale(),
    )
    .await
    .unwrap();

    let mut all_blocks = Vec::with_capacity(1 + mst_blocks.len() + record_blocks.len());
    all_blocks.push(RepositoryBlock::new(
        commit.cid.clone(),
        commit.signed_commit_bytes.clone(),
    ));
    all_blocks.extend(mst_blocks);
    all_blocks.extend(record_blocks);

    let car_path = dir.path().join("scale.car");
    let sink = petrel_repo::FileCARByteSink::create(&car_path).unwrap();
    petrel_repo::PublicRepositoryCAR::write_to_sink(
        std::slice::from_ref(&commit.cid),
        &all_blocks,
        &sink,
    )
    .await
    .unwrap();
    sink.synchronize().await.unwrap();

    let store_path = dir.path().join("blocks.car");
    let store = Arc::new(petrel_repo::FileBlockStore::open(&store_path).unwrap());
    let mut source = petrel_repo::FileCARByteSource::open(&car_path).unwrap();
    let repo = Repository::open_car_source(
        &mut source,
        Arc::clone(&store),
        OpenVerification::SigningKey(signer.public_key().clone()),
        Some(&did),
        RepositoryLimits::network_scale(),
        RepositoryReadPolicy::strict(),
        true,
    )
    .await
    .unwrap();
    assert_eq!(repo.statistics().unwrap().record_count, count);

    // Reopen existing FileBlockStore from disk and verify persistence across restart
    store.synchronize().await.unwrap();
    drop(repo);
    drop(store);

    let reopened_store = Arc::new(petrel_repo::FileBlockStore::open(&store_path).unwrap());
    assert!(reopened_store.len().await.unwrap() > count);

    let mut small_limits = RepositoryLimits::standard();
    small_limits.max_record_count = 1_000;
    let err_limit = Repository::open_store(
        commit.cid.clone(),
        Arc::clone(&reopened_store),
        OpenVerification::SigningKey(signer.public_key().clone()),
        Some(&did),
        small_limits,
        RepositoryReadPolicy::strict(),
        true,
    )
    .await
    .unwrap_err();
    assert!(matches!(err_limit, petrel_repo::RepositoryError::Mst(_)));

    let reopened = Repository::open_store(
        commit.cid.clone(),
        reopened_store,
        OpenVerification::SigningKey(signer.public_key().clone()),
        Some(&did),
        RepositoryLimits::network_scale(),
        RepositoryReadPolicy::strict(),
        true,
    )
    .await
    .unwrap();
    for idx in [0, 1, count / 2, count - 1] {
        let rec = reopened
            .record(collection, &format!("r{idx:07}"))
            .await
            .unwrap()
            .unwrap();
        assert_eq!(
            rec.record().unwrap().get("n"),
            Some(&Value::Integer(i64::try_from(idx).unwrap()))
        );
    }
    assert!(
        reopened
            .record(collection, "r9999999")
            .await
            .unwrap()
            .is_none()
    );

    let mut extra_val = BTreeMap::new();
    extra_val.insert("$type".to_owned(), Value::String(collection.into()));
    extra_val.insert("n".to_owned(), Value::Integer(-1));
    let extra_op = create_op(collection, "r0002000x", &Value::Object(extra_val)).unwrap();
    let committed = reopened
        .commit_writes(WriteBatch::new(vec![extra_op]).unwrap(), &signer)
        .await
        .unwrap();
    assert!(committed.new_blocks.len() < 24);
    assert_eq!(
        committed.repository.statistics().unwrap().record_count,
        count + 1
    );
}

#[cfg(not(target_arch = "wasm32"))]
#[tokio::test]
async fn file_block_store_persists_deletions_across_sync_and_reopen() {
    use petrel_repo::block_store::BlockStore as _;

    let dir = tempfile::tempdir().unwrap();
    let store_path = dir.path().join("blocks.car");

    let blk_a = dagcbor::encode(&Value::String("block-a".into()));
    let cid_a = Cid::for_dag_cbor(&blk_a);
    let blk_b = dagcbor::encode(&Value::String("block-b".into()));
    let cid_b = Cid::for_dag_cbor(&blk_b);
    let blk_c = dagcbor::encode(&Value::String("block-c-unflushed".into()));
    let cid_c = Cid::for_dag_cbor(&blk_c);

    // 1. Delete an unflushed pending block before synchronize: it must never land on disk.
    let store = petrel_repo::FileBlockStore::open(&store_path).unwrap();
    store.put_block(&cid_a, &blk_a).await.unwrap();
    store.put_block(&cid_c, &blk_c).await.unwrap();
    assert!(store.delete_block(&cid_c).await.unwrap());
    assert!(!store.delete_block(&cid_c).await.unwrap());
    store.synchronize().await.unwrap();
    drop(store);

    let reopened = petrel_repo::FileBlockStore::open(&store_path).unwrap();
    assert_eq!(reopened.len().await.unwrap(), 1);
    assert_eq!(reopened.total_bytes().await.unwrap(), blk_a.len());
    assert_eq!(
        reopened.get_block(&cid_a).await.unwrap(),
        Some(blk_a.clone())
    );
    assert_eq!(reopened.get_block(&cid_c).await.unwrap(), None);

    // 2. Delete a persisted block, add another block, synchronize, and reopen: deletion survives.
    reopened.put_block(&cid_b, &blk_b).await.unwrap();
    reopened.synchronize().await.unwrap();
    assert!(reopened.delete_block(&cid_a).await.unwrap());
    assert_eq!(reopened.get_block(&cid_a).await.unwrap(), None);
    assert!(!reopened.contains_block(&cid_a).await.unwrap());
    assert_eq!(reopened.len().await.unwrap(), 1);
    assert_eq!(reopened.total_bytes().await.unwrap(), blk_b.len());
    reopened.synchronize().await.unwrap();
    drop(reopened);

    let reopened2 = petrel_repo::FileBlockStore::open(&store_path).unwrap();
    assert_eq!(reopened2.get_block(&cid_a).await.unwrap(), None);
    assert_eq!(
        reopened2.get_block(&cid_b).await.unwrap(),
        Some(blk_b.clone())
    );
    assert_eq!(reopened2.len().await.unwrap(), 1);
    assert_eq!(reopened2.total_bytes().await.unwrap(), blk_b.len());

    // 3. Re-putting the previously deleted CID succeeds and survives another reopen.
    reopened2.put_block(&cid_a, &blk_a).await.unwrap();
    reopened2.synchronize().await.unwrap();
    drop(reopened2);

    let reopened3 = petrel_repo::FileBlockStore::open(&store_path).unwrap();
    assert_eq!(
        reopened3.get_block(&cid_a).await.unwrap(),
        Some(blk_a.clone())
    );
    assert_eq!(
        reopened3.get_block(&cid_b).await.unwrap(),
        Some(blk_b.clone())
    );
    assert_eq!(reopened3.len().await.unwrap(), 2);
    assert_eq!(
        reopened3.total_bytes().await.unwrap(),
        blk_a.len() + blk_b.len()
    );
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn recreated_mst_split_emits_new_blocks_and_verifies_commit_diff() {
    use petrel_repo::mst::key_depth;

    let did = common::test_did();
    let signer = P256Keypair::generate().unwrap();
    let resolver = FixedSigningKey::from_public_key(signer.public_key().clone());
    let limits = RepositoryLimits::standard();
    let policy = RepositoryReadPolicy::strict();
    let store = Arc::new(InMemoryBlockStore::new());

    // Find deterministic layer-0 / layer->=1 / layer-0 keys in sorted order: low < mid < high.
    let mut layer0_keys = Vec::new();
    let mut selected_mid = None;
    for i in 0..200_u32 {
        let rkey = format!("k{i:04}");
        let mst_key = format!("app.bsky.feed.post/{rkey}");
        let depth = key_depth(mst_key.as_bytes());
        if depth == 0 && layer0_keys.is_empty() {
            layer0_keys.push(rkey);
        } else if depth >= 1 && !layer0_keys.is_empty() && selected_mid.is_none() {
            selected_mid = Some(rkey);
        } else if depth == 0 && selected_mid.is_some() {
            layer0_keys.push(rkey);
            break;
        }
    }
    assert_eq!(layer0_keys.len(), 2);
    let mid_rkey = selected_mid.expect("expected intervening layer >= 1 key");
    let low_path = RepositoryPath::new("app.bsky.feed.post", &layer0_keys[0]).unwrap();
    let mid_path = RepositoryPath::new("app.bsky.feed.post", &mid_rkey).unwrap();
    let high_path = RepositoryPath::new("app.bsky.feed.post", &layer0_keys[1]).unwrap();
    let rec_bytes = dagcbor::encode(&post_record_value("mst split regression"));

    let s0 = RepositoryState::new(did.clone(), 1).unwrap();

    // 1. Create low + high in a single layer-0 MST node.
    let b1 = WriteBatch::new(vec![
        WriteOp::Create {
            path: low_path,
            record_cbor: rec_bytes.clone(),
        },
        WriteOp::Create {
            path: high_path,
            record_cbor: rec_bytes.clone(),
        },
    ])
    .unwrap();
    let r1 = RepositoryEngine::apply(
        &s0,
        &b1,
        None,
        RepositoryTid::parse("3jzfcijpj2z2a").unwrap(),
        &signer,
        Arc::clone(&store),
        &limits,
        &policy,
    )
    .await
    .unwrap();

    // 2. Insert intervening layer >= 1 key `mid`, persisting split children in `store`.
    let b2 = WriteBatch::new(vec![WriteOp::Create {
        path: mid_path.clone(),
        record_cbor: rec_bytes.clone(),
    }])
    .unwrap();
    let r2 = RepositoryEngine::apply(
        &r1.state,
        &b2,
        r1.state.head_commit_cid.as_ref(),
        RepositoryTid::parse("3jzfcijpj2z2b").unwrap(),
        &signer,
        Arc::clone(&store),
        &limits,
        &policy,
    )
    .await
    .unwrap();
    CommitDiff::verify_commit_event(
        &r2.diff_car().unwrap(),
        &r2.commit.cid,
        &did,
        &r2.operations,
        r2.previous_data_cid.as_ref(),
        &resolver,
        &limits,
        &policy,
    )
    .await
    .unwrap();

    // 3. Delete `mid`, merging back to the single layer-0 root while split children remain in `store`.
    let b3 = WriteBatch::new(vec![WriteOp::Delete {
        path: mid_path.clone(),
    }])
    .unwrap();
    let r3 = RepositoryEngine::apply(
        &r2.state,
        &b3,
        r2.state.head_commit_cid.as_ref(),
        RepositoryTid::parse("3jzfcijpj2z2c").unwrap(),
        &signer,
        Arc::clone(&store),
        &limits,
        &policy,
    )
    .await
    .unwrap();
    assert_eq!(r3.state.head_data_cid, r1.state.head_data_cid);
    CommitDiff::verify_commit_event(
        &r3.diff_car().unwrap(),
        &r3.commit.cid,
        &did,
        &r3.operations,
        r3.previous_data_cid.as_ref(),
        &resolver,
        &limits,
        &policy,
    )
    .await
    .unwrap();

    // 4. Recreate `mid`: diff CAR must still emit the recreated split child nodes even though
    // `store` retained them from commit 2, and `verify_commit_event` must succeed.
    let b4 = WriteBatch::new(vec![WriteOp::Create {
        path: mid_path,
        record_cbor: rec_bytes,
    }])
    .unwrap();
    let r4 = RepositoryEngine::apply(
        &r3.state,
        &b4,
        r3.state.head_commit_cid.as_ref(),
        RepositoryTid::parse("3jzfcijpj2z2d").unwrap(),
        &signer,
        Arc::clone(&store),
        &limits,
        &policy,
    )
    .await
    .unwrap();
    let emitted_cids: std::collections::BTreeSet<Cid> =
        r4.new_blocks.iter().map(|b| b.cid.clone()).collect();
    for expected in &r2.new_blocks {
        if expected.cid != r2.commit.cid {
            assert!(
                emitted_cids.contains(&expected.cid),
                "re-split MST diff omitted node block {}",
                expected.cid
            );
        }
    }
    CommitDiff::verify_commit_event(
        &r4.diff_car().unwrap(),
        &r4.commit.cid,
        &did,
        &r4.operations,
        r4.previous_data_cid.as_ref(),
        &resolver,
        &limits,
        &policy,
    )
    .await
    .unwrap();
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn engine_and_validation_reject_mst_blocks_exceeding_single_block_limit() {
    use petrel_repo::block_store::BlockStore as _;
    use petrel_repo::error::{LimitKind, MstError, RepositoryError};
    use petrel_repo::mst::MstValidation;

    let did = common::test_did();
    let signer = P256Keypair::generate().unwrap();
    let policy = RepositoryReadPolicy::strict();

    // Valid ~509-byte MST path (`app.bsky.feed.post/` + 490 chars) produces an MST node > 512 bytes,
    // while the small record and signed commit stay well below 512 bytes.
    let long_rkey = "a".repeat(490);
    let long_path = RepositoryPath::new("app.bsky.feed.post", &long_rkey).unwrap();
    let small_record_cbor = dagcbor::encode(&post_record_value("hi"));
    assert!(small_record_cbor.len() < 128);

    let batch = WriteBatch::new(vec![WriteOp::Create {
        path: long_path,
        record_cbor: small_record_cbor,
    }])
    .unwrap();

    let strict_limits = RepositoryLimits {
        max_single_block_bytes: 512,
        ..RepositoryLimits::standard()
    };
    strict_limits.validate().unwrap();

    let unbounded_store = Arc::new(InMemoryBlockStore::new());
    let s0 = RepositoryState::new(did.clone(), 1).unwrap();
    let err = RepositoryEngine::apply(
        &s0,
        &batch,
        None,
        RepositoryTid::parse("3jzfcijpj2z2a").unwrap(),
        &signer,
        Arc::clone(&unbounded_store),
        &strict_limits,
        &policy,
    )
    .await
    .unwrap_err();
    assert!(
        matches!(
            err,
            EngineError::Mst(MstError::BlockTooLarge { limit: 512, .. })
                | EngineError::Limit(LimitError::Exceeded {
                    kind: LimitKind::SingleBlockBytes,
                    limit: 512,
                    ..
                })
        ),
        "unexpected error for oversized MST block: {err:?}"
    );
    assert_eq!(
        unbounded_store.len().await.unwrap(),
        0,
        "oversized MST commit must fail before persisting any blocks"
    );

    // Apply under standard limits so an MST block > 512B exists in the unbounded store, then
    // verify full-tree validation & Repository::open_store enforce `max_single_block_bytes: 512`.
    let standard_limits = RepositoryLimits::standard();
    let res = RepositoryEngine::apply(
        &s0,
        &batch,
        None,
        RepositoryTid::parse("3jzfcijpj2z2a").unwrap(),
        &signer,
        Arc::clone(&unbounded_store),
        &standard_limits,
        &policy,
    )
    .await
    .unwrap();
    let data_cid = res.state.head_data_cid.unwrap();

    let strict_mst_opts = MstOptions {
        max_single_block_bytes: 512,
        ..MstOptions::default()
    };
    let val_err = MstValidation::validate_full(
        &data_cid,
        unbounded_store.as_ref(),
        &strict_mst_opts,
        strict_limits.max_record_count,
        true,
    )
    .await
    .unwrap_err();
    assert!(
        matches!(val_err, MstError::BlockTooLarge { limit: 512, .. }),
        "unexpected full-tree validation error: {val_err:?}"
    );

    let open_err = Repository::open_store(
        res.commit.cid,
        unbounded_store,
        OpenVerification::SigningKey(signer.public_key().clone()),
        Some(&did),
        strict_limits,
        policy,
        true,
    )
    .await
    .unwrap_err();
    assert!(
        matches!(
            open_err,
            RepositoryError::Mst(MstError::BlockTooLarge { limit: 512, .. })
        ),
        "unexpected Repository::open_store error: {open_err:?}"
    );
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn commit_diff_validates_record_blocks_and_rejects_duplicate_paths() {
    use petrel_repo::car::PublicRepositoryCAR;
    use petrel_repo::error::CommitDiffError;

    let did = common::test_did();
    let signer = P256Keypair::generate().unwrap();
    let resolver = FixedSigningKey::from_public_key(signer.public_key().clone());
    let limits = RepositoryLimits::standard();
    let policy = RepositoryReadPolicy::strict();
    let store = Arc::new(InMemoryBlockStore::new());
    let s0 = RepositoryState::new(did.clone(), 1).unwrap();

    let post_path = RepositoryPath::new("app.bsky.feed.post", "3jzfcijpj2z2a").unwrap();
    let valid_cbor = dagcbor::encode(&post_record_value("hello world"));
    let batch = WriteBatch::new(vec![WriteOp::Create {
        path: post_path.clone(),
        record_cbor: valid_cbor.clone(),
    }])
    .unwrap();
    let res = RepositoryEngine::apply(
        &s0,
        &batch,
        None,
        RepositoryTid::parse("3jzfcijpj2z2a").unwrap(),
        &signer,
        Arc::clone(&store),
        &limits,
        &policy,
    )
    .await
    .unwrap();
    let record_cid = res.operations[0].cid().unwrap().clone();

    // 1. Missing record block in commit diff CAR fails `verify_commit_event`.
    let blocks_without_record: Vec<RepositoryBlock> = std::iter::once(RepositoryBlock::new(
        res.commit.cid.clone(),
        res.commit.signed_commit_bytes.clone(),
    ))
    .chain(res.proof_blocks.iter().cloned())
    .chain(
        res.new_blocks
            .iter()
            .filter(|b| b.cid != record_cid)
            .cloned(),
    )
    .collect();
    let car_missing_record = PublicRepositoryCAR::write(
        std::slice::from_ref(&res.commit.cid),
        &blocks_without_record,
    )
    .unwrap();
    let missing_err = CommitDiff::verify_commit_event(
        &car_missing_record,
        &res.commit.cid,
        &did,
        &res.operations,
        res.previous_data_cid.as_ref(),
        &resolver,
        &limits,
        &policy,
    )
    .await
    .unwrap_err();
    assert!(matches!(missing_err, CommitDiffError::MissingBlock(c) if c == record_cid));

    // 2. Record block whose `$type` mismatches operation collection fails `verify_commit_event`.
    let mut wrong_type_map = BTreeMap::new();
    wrong_type_map.insert(
        "$type".to_owned(),
        Value::String("app.bsky.feed.like".into()),
    );
    wrong_type_map.insert("subject".to_owned(), Value::String("at://example".into()));
    let wrong_cbor = dagcbor::encode(&Value::Object(wrong_type_map));
    let wrong_cid = Cid::for_dag_cbor(&wrong_cbor);
    let mut mst = petrel_repo::mst::RepositoryMst::empty();
    let wrong_root = mst
        .insert(post_path.mst_key(), wrong_cid.clone())
        .await
        .unwrap();
    let wrong_commit = CommitCodec::prepare(
        &CommitDescriptor {
            did: did.clone(),
            rev: RepositoryTid::parse("3jzfcijpj2z2b").unwrap(),
            data_cid: wrong_root,
            prev_cid: None,
        },
        &signer,
        &limits,
    )
    .await
    .unwrap();
    let mut wrong_blocks = vec![
        RepositoryBlock::new(
            wrong_commit.cid.clone(),
            wrong_commit.signed_commit_bytes.clone(),
        ),
        RepositoryBlock::new(wrong_cid.clone(), wrong_cbor),
    ];
    wrong_blocks.extend(mst.new_blocks());
    let wrong_car =
        PublicRepositoryCAR::write(std::slice::from_ref(&wrong_commit.cid), &wrong_blocks).unwrap();
    let wrong_ops = vec![CommitOperation::Create {
        path: post_path.clone(),
        cid: wrong_cid.clone(),
    }];
    let type_err = CommitDiff::verify_commit_event(
        &wrong_car,
        &wrong_commit.cid,
        &did,
        &wrong_ops,
        Some(&Cid::parse(petrel_repo::CANONICAL_EMPTY_MST_CID).unwrap()),
        &resolver,
        &limits,
        &policy,
    )
    .await
    .unwrap_err();
    assert!(matches!(type_err, CommitDiffError::InvalidOperation(_)));

    // 3. Record block exceeding `max_single_block_bytes` fails `CommitDiff::verify`.
    let diff_store = Arc::new(InMemoryBlockStore::new());
    PublicRepositoryCAR::load(
        &res.diff_car().unwrap(),
        diff_store.as_ref(),
        &limits,
        &policy,
    )
    .await
    .unwrap();
    let tight_limits = RepositoryLimits {
        max_single_block_bytes: valid_cbor.len().saturating_sub(1).max(1),
        ..limits
    };
    let size_err = CommitDiff::verify(
        &res.commit.cid,
        &res.operations,
        res.previous_data_cid.as_ref(),
        diff_store,
        &resolver,
        Some(&did),
        &tight_limits,
        &policy,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        size_err,
        CommitDiffError::Mst(petrel_repo::error::MstError::BlockTooLarge { .. })
    ));

    // 4. Duplicate cancelling path `[Create(absent, bogus), Delete(absent, bogus)]` fails on
    // an unchanged-tree commit before inversion executes.
    let absent_path = RepositoryPath::new("app.bsky.feed.post", "3jzfcijpj2zzz").unwrap();
    let bogus_cid = Cid::for_dag_cbor(&[0xa0]);
    let mut proof_blocks = vec![RepositoryBlock::new(
        res.commit.cid.clone(),
        res.commit.signed_commit_bytes.clone(),
    )];
    let mut open_mst =
        petrel_repo::mst::RepositoryMst::open(res.commit.data_cid.clone(), Arc::clone(&store) as _);
    for (cid, bytes) in open_mst
        .covering_proof_blocks(&[absent_path.mst_key().to_owned()])
        .await
        .unwrap()
    {
        proof_blocks.push(RepositoryBlock::new(cid, bytes));
    }
    let unchanged_car =
        PublicRepositoryCAR::write(std::slice::from_ref(&res.commit.cid), &proof_blocks).unwrap();
    let dup_ops = vec![
        CommitOperation::Create {
            path: absent_path.clone(),
            cid: bogus_cid.clone(),
        },
        CommitOperation::Delete {
            path: absent_path,
            prev: bogus_cid,
        },
    ];
    let dup_err = CommitDiff::verify_commit_event(
        &unchanged_car,
        &res.commit.cid,
        &did,
        &dup_ops,
        Some(&res.commit.data_cid),
        &resolver,
        &limits,
        &policy,
    )
    .await
    .unwrap_err();
    assert!(matches!(dup_err, CommitDiffError::InvalidOperation(_)));
}

#[derive(Debug, Default)]
struct IncrementalSink {
    chunks: async_lock::Mutex<Vec<Vec<u8>>>,
    write_calls: std::sync::atomic::AtomicUsize,
    finished: AtomicBool,
}

impl petrel_repo::car::CARByteSink for IncrementalSink {
    fn write_bytes<'a>(
        &'a self,
        chunk: &'a [u8],
    ) -> BoxFuture<'a, Result<(), petrel_repo::error::CARError>> {
        Box::pin(async move {
            self.write_calls.fetch_add(1, Ordering::Relaxed);
            self.chunks.lock().await.push(chunk.to_vec());
            Ok(())
        })
    }

    fn finish(&self) -> BoxFuture<'_, Result<(), petrel_repo::error::CARError>> {
        Box::pin(async move {
            self.finished.store(true, Ordering::Relaxed);
            Ok(())
        })
    }
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn data_model_open_store_validates_record_cbor_and_streaming_export_avoids_buffering() {
    use petrel_repo::block_store::BlockStore as _;
    use petrel_repo::car::PublicRepositoryCAR;
    use petrel_repo::error::{LimitKind, RecordCodecError, RepositoryError};
    use petrel_repo::repository::CARExportOrder;

    let did = common::test_did();
    let signer = P256Keypair::generate().unwrap();
    let limits = RepositoryLimits::standard();
    let strict = RepositoryReadPolicy::strict();
    let data_model = RepositoryReadPolicy::data_model();
    let store = Arc::new(InMemoryBlockStore::new());

    // 1. Non-map record (CBOR array) stored with valid CID must fail `open_store(..., data_model(), true)`.
    let non_map_bytes = dagcbor::encode(&Value::Array(vec![Value::Integer(1)]));
    let non_map_cid = Cid::for_dag_cbor(&non_map_bytes);
    let mut mst = petrel_repo::mst::RepositoryMst::empty();
    let bad_root = mst
        .insert("app.bsky.feed.post/3jzfcijpj2z2a", non_map_cid.clone())
        .await
        .unwrap();
    for b in mst.new_blocks() {
        store.put_block(&b.cid, &b.bytes).await.unwrap();
    }
    store.put_block(&non_map_cid, &non_map_bytes).await.unwrap();
    let bad_commit = CommitCodec::prepare(
        &CommitDescriptor {
            did: did.clone(),
            rev: RepositoryTid::parse("3jzfcijpj2z2a").unwrap(),
            data_cid: bad_root,
            prev_cid: None,
        },
        &signer,
        &limits,
    )
    .await
    .unwrap();
    store
        .put_block(&bad_commit.cid, &bad_commit.signed_commit_bytes)
        .await
        .unwrap();

    let open_err = Repository::open_store(
        bad_commit.cid,
        Arc::clone(&store),
        OpenVerification::SigningKey(signer.public_key().clone()),
        Some(&did),
        limits,
        data_model,
        true,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        open_err,
        RepositoryError::Record(RecordCodecError::TopLevelNotMap)
    ));

    // 2. Engine enforces resulting reachable block count (`1 + mst_nodes + records <= max_block_count`)
    // even against an unbounded store when creating 2 distinct layer-0 records under `max_block_count = 3`.
    let unbounded = Arc::new(InMemoryBlockStore::new());
    let s0 = RepositoryState::new(did.clone(), 1).unwrap();
    let tight_limits = RepositoryLimits {
        max_block_count: 3,
        max_record_count: 2,
        max_mst_node_count: 2,
        ..RepositoryLimits::standard()
    };
    tight_limits.validate().unwrap();
    let two_rec_batch = WriteBatch::new(vec![
        create_op(
            "app.bsky.feed.post",
            "3jzfcijpj2z2a",
            &post_record_value("first distinct record"),
        )
        .unwrap(),
        create_op(
            "app.bsky.feed.post",
            "3jzfcijpj2z2b",
            &post_record_value("second distinct record"),
        )
        .unwrap(),
    ])
    .unwrap();
    let count_err = RepositoryEngine::apply(
        &s0,
        &two_rec_batch,
        None,
        RepositoryTid::parse("3jzfcijpj2z2a").unwrap(),
        &signer,
        Arc::clone(&unbounded),
        &tight_limits,
        &strict,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        count_err,
        EngineError::Limit(LimitError::Exceeded {
            kind: LimitKind::BlockCount,
            observed: 4,
            limit: 3,
        })
    ));
    assert_eq!(unbounded.len().await.unwrap(), 0);

    // 3. Streaming CAR export writes header + individual frames incrementally to `CARByteSink`
    // (1 header + 4 blocks = 5 separate `write_bytes` calls) and roundtrips cleanly.
    let res = RepositoryEngine::apply(
        &s0,
        &two_rec_batch,
        None,
        RepositoryTid::parse("3jzfcijpj2z2a").unwrap(),
        &signer,
        Arc::clone(&unbounded),
        &limits,
        &strict,
    )
    .await
    .unwrap();
    let repo = Repository::open_store(
        res.commit.cid,
        unbounded,
        OpenVerification::SigningKey(signer.public_key().clone()),
        Some(&did),
        limits,
        strict,
        true,
    )
    .await
    .unwrap();

    for order in [
        CARExportOrder::Streamable,
        CARExportOrder::BreadthFirst,
        CARExportOrder::Stored,
    ] {
        let sink = IncrementalSink::default();
        repo.export_car_to_sink(&sink, order).await.unwrap();
        assert!(sink.finished.load(Ordering::Relaxed));
        let streamed: Vec<u8> = sink.chunks.lock().await.concat();
        let (_, imported) = PublicRepositoryCAR::import_bytes(&streamed, &limits, &strict)
            .await
            .unwrap();
        let imported_len = imported.len().await.unwrap();
        assert!(imported_len >= 4);
        // Header + 1 write call per exported block = `1 + imported_len` incremental writes.
        assert_eq!(sink.write_calls.load(Ordering::Relaxed), 1 + imported_len);
    }

    // 4. Engine enforces resulting `max_record_count` and `max_mst_node_count` before signing
    // or persisting even against an unbounded backing store and generous `max_block_count`.
    let rec_limit_store = Arc::new(InMemoryBlockStore::new());
    let rec_limits = RepositoryLimits {
        max_block_count: 50,
        max_record_count: 1,
        max_mst_node_count: 10,
        ..RepositoryLimits::standard()
    };
    let rec_batch_1 = WriteBatch::new(vec![
        create_op(
            "app.bsky.feed.post",
            "k002",
            &post_record_value("first record"),
        )
        .unwrap(),
    ])
    .unwrap();
    let r_first = RepositoryEngine::apply(
        &s0,
        &rec_batch_1,
        None,
        RepositoryTid::parse("3jzfcijpj2z2a").unwrap(),
        &signer,
        Arc::clone(&rec_limit_store),
        &rec_limits,
        &strict,
    )
    .await
    .unwrap();
    let count_after_first = rec_limit_store.len().await.unwrap();
    let rec_batch_2 = WriteBatch::new(vec![
        create_op(
            "app.bsky.feed.post",
            "k005",
            &post_record_value("second record exceeds max_record_count=1"),
        )
        .unwrap(),
    ])
    .unwrap();
    let rec_err = RepositoryEngine::apply(
        &r_first.state,
        &rec_batch_2,
        r_first.state.head_commit_cid.as_ref(),
        RepositoryTid::parse("3jzfcijpj2z2b").unwrap(),
        &signer,
        Arc::clone(&rec_limit_store),
        &rec_limits,
        &strict,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        rec_err,
        EngineError::Limit(LimitError::Exceeded {
            kind: LimitKind::RecordCount,
            observed: 2,
            limit: 1,
        })
    ));
    assert_eq!(
        rec_limit_store.len().await.unwrap(),
        count_after_first,
        "failed commit must not persist any blocks"
    );

    // Also enforce `max_mst_node_count = 1` when an intervening split creates > 1 MST nodes.
    let mut split_mid = None;
    for i in 0..200_u32 {
        let candidate = format!("k003_{i:03}");
        if candidate.as_str() > "k002"
            && candidate.as_str() < "k005"
            && petrel_repo::mst::key_depth(format!("app.bsky.feed.post/{candidate}").as_bytes())
                >= 1
        {
            split_mid = Some(candidate);
            break;
        }
    }
    let split_rkey = split_mid.unwrap();
    let node_limits = RepositoryLimits {
        max_block_count: 50,
        max_record_count: 10,
        max_mst_node_count: 1,
        ..RepositoryLimits::standard()
    };
    let two_rec_same_layer = WriteBatch::new(vec![
        create_op("app.bsky.feed.post", "k002", &post_record_value("left")).unwrap(),
        create_op(
            "app.bsky.feed.post",
            &split_rkey,
            &post_record_value("split height >= 1"),
        )
        .unwrap(),
    ])
    .unwrap();
    let split_store = Arc::new(InMemoryBlockStore::new());
    let node_err = RepositoryEngine::apply(
        &s0,
        &two_rec_same_layer,
        None,
        RepositoryTid::parse("3jzfcijpj2z2a").unwrap(),
        &signer,
        Arc::clone(&split_store),
        &node_limits,
        &strict,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        node_err,
        EngineError::Limit(LimitError::Exceeded {
            kind: LimitKind::MstNodeCount,
            limit: 1,
            ..
        })
    ));
    assert_eq!(split_store.len().await.unwrap(), 0);

    // 5. GenesisCodec::create and Repository::create_in_store enforce the 2-block genesis
    // footprint (commit + empty MST root) before signing or persisting on unbounded stores.
    let one_block_limits = RepositoryLimits {
        max_block_count: 1,
        max_record_count: 1,
        max_mst_node_count: 1,
        ..RepositoryLimits::standard()
    };
    let genesis_store = Arc::new(InMemoryBlockStore::new());
    let gen_err = GenesisCodec::create(
        &did,
        &signer,
        RepositoryTid::parse("3jzfcijpj2z2a").unwrap(),
        1,
        genesis_store.as_ref(),
        &one_block_limits,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        gen_err,
        petrel_repo::error::GenesisStoreError::Limit(LimitError::Exceeded {
            kind: LimitKind::BlockCount,
            observed: 2,
            limit: 1,
        })
    ));
    assert_eq!(genesis_store.len().await.unwrap(), 0);

    let repo_create_err = Repository::create_in_store(
        did.clone(),
        &signer,
        Arc::clone(&genesis_store),
        one_block_limits,
        strict,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        repo_create_err,
        RepositoryError::Limit(LimitError::Exceeded {
            kind: LimitKind::BlockCount,
            observed: 2,
            limit: 1,
        })
    ));
    assert_eq!(genesis_store.len().await.unwrap(), 0);

    let small_relevant_limits = RepositoryLimits {
        max_block_count: 2,
        max_record_count: 1,
        max_mst_node_count: 1,
        max_relevant_block_bytes: 50,
        ..RepositoryLimits::standard()
    };
    let budget_err = GenesisCodec::create(
        &did,
        &signer,
        RepositoryTid::parse("3jzfcijpj2z2a").unwrap(),
        1,
        genesis_store.as_ref(),
        &small_relevant_limits,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        budget_err,
        petrel_repo::error::GenesisStoreError::Limit(LimitError::Exceeded {
            kind: LimitKind::RelevantBlockBytes,
            limit: 50,
            ..
        })
    ));
    assert_eq!(genesis_store.len().await.unwrap(), 0);

    let tiny_single_limits = RepositoryLimits {
        max_block_count: 2,
        max_record_count: 1,
        max_mst_node_count: 1,
        max_single_block_bytes: 5,
        ..RepositoryLimits::standard()
    };
    let single_err = GenesisCodec::create(
        &did,
        &signer,
        RepositoryTid::parse("3jzfcijpj2z2a").unwrap(),
        1,
        genesis_store.as_ref(),
        &tiny_single_limits,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        single_err,
        petrel_repo::error::GenesisStoreError::Limit(LimitError::Exceeded {
            kind: LimitKind::SingleBlockBytes,
            limit: 5,
            ..
        })
    ));
    assert_eq!(genesis_store.len().await.unwrap(), 0);

    // 6. Engine enforces `limits.max_mst_depth` across reused unchanged subtrees before signing
    // or persisting: e.g. with `max_mst_depth = 1`, layer-0 + layer-1 succeeds (depth 1), then
    // inserting a layer >= 2 key pushes the unchanged layer-0 subtree to depth >= 2 and fails.
    let mut layer0_rkey = None;
    let mut layer1_rkey = None;
    let mut layer2plus_rkey = None;
    for i in 0..2000_u32 {
        let rkey = format!("d{i:04}");
        let d = petrel_repo::mst::key_depth(format!("app.bsky.feed.post/{rkey}").as_bytes());
        if d == 0 && layer0_rkey.is_none() {
            layer0_rkey = Some(rkey);
        } else if d == 1 && layer1_rkey.is_none() {
            layer1_rkey = Some(rkey);
        } else if d >= 2 && layer2plus_rkey.is_none() {
            layer2plus_rkey = Some(rkey);
        }
        if layer0_rkey.is_some() && layer1_rkey.is_some() && layer2plus_rkey.is_some() {
            break;
        }
    }
    let l0 = layer0_rkey.unwrap();
    let l1 = layer1_rkey.unwrap();
    let l2 = layer2plus_rkey.unwrap();

    let depth_limits = RepositoryLimits {
        max_mst_depth: 1,
        ..RepositoryLimits::standard()
    };
    let depth_store = Arc::new(InMemoryBlockStore::new());
    let base_repo = Repository::create_in_store(
        did.clone(),
        &signer,
        Arc::clone(&depth_store),
        depth_limits,
        strict,
    )
    .await
    .unwrap();
    let rev1 = RepositoryTid::next_after(Some(base_repo.revision()), 0, 0).unwrap();
    let depth_c1 = base_repo
        .commit_writes_with_rev(
            WriteBatch::new(vec![
                create_op("app.bsky.feed.post", &l0, &post_record_value("layer 0")).unwrap(),
                create_op("app.bsky.feed.post", &l1, &post_record_value("layer 1")).unwrap(),
            ])
            .unwrap(),
            rev1,
            &signer,
        )
        .await
        .unwrap();
    let persisted_before_fail = depth_store.len().await.unwrap();
    let prev_commit_cid = depth_c1.commit.cid.clone();
    let rev2 = RepositoryTid::next_after(Some(depth_c1.repository.revision()), 0, 0).unwrap();

    let depth_err = RepositoryEngine::apply(
        &depth_c1.repository.state(),
        &WriteBatch::new(vec![
            create_op("app.bsky.feed.post", &l2, &post_record_value("layer >= 2")).unwrap(),
        ])
        .unwrap(),
        Some(&prev_commit_cid),
        rev2,
        &signer,
        Arc::clone(&depth_store),
        &depth_limits,
        &strict,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        depth_err,
        EngineError::Mst(petrel_repo::error::MstError::DepthExceeded { limit: 1, .. })
    ));
    assert_eq!(
        depth_store.len().await.unwrap(),
        persisted_before_fail,
        "depth-exceeded commit must fail before signing or persisting any blocks"
    );

    // Conversely, when root_layer == 2 > max_mst_depth(1) but only layer-1 and layer-2 keys
    // exist (no layer-0 subtree), actual tree depth is 1 <= 1 and must succeed.
    let no_l0_store = Arc::new(InMemoryBlockStore::new());
    let no_l0_res = RepositoryEngine::apply(
        &s0,
        &WriteBatch::new(vec![
            create_op("app.bsky.feed.post", &l1, &post_record_value("layer 1")).unwrap(),
            create_op("app.bsky.feed.post", &l2, &post_record_value("layer >= 2")).unwrap(),
        ])
        .unwrap(),
        None,
        RepositoryTid::parse("3jzfcijpj2z2a").unwrap(),
        &signer,
        Arc::clone(&no_l0_store),
        &depth_limits,
        &strict,
    )
    .await
    .unwrap();
    let reopened_no_l0 = Repository::open_store(
        no_l0_res.commit.cid,
        no_l0_store,
        OpenVerification::SigningKey(signer.public_key().clone()),
        Some(&did),
        depth_limits,
        strict,
        true,
    )
    .await
    .unwrap();
    assert_eq!(reopened_no_l0.statistics().unwrap().record_count, 2);
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn non_blessed_leaf_link_preserved_under_data_model_and_rejected_under_strict() {
    use petrel_repo::car::{DataCARByteSink, PublicRepositoryCAR};
    use petrel_repo::error::{MstError, RepositoryError};
    use petrel_repo::mst::codec::{
        MstNodeEntryView, MstNodeView, decode_mst_node, encode_mst_node,
    };
    use petrel_repo::mst::{MstKeySyntax, MstOptions, RepositoryMst};
    use petrel_repo::repository::CARExportOrder;

    let did = common::test_did();
    let signer = P256Keypair::generate().unwrap();
    let limits = RepositoryLimits::standard();
    let data_model = RepositoryReadPolicy::data_model();
    let strict = RepositoryReadPolicy::strict();

    // Build a CIDv1(dag-cbor, sha2-512) non-blessed leaf link with no payload in the CAR.
    let mut foreign_bytes = vec![0x01, 0x71, 0x13, 0x40];
    foreign_bytes.extend(std::iter::repeat_n(5_u8, 64));
    let foreign = Cid::from_bytes(&foreign_bytes).unwrap();
    assert!(foreign.blessed_kind().is_none());

    let mut mst = RepositoryMst::empty_with_options(MstOptions {
        policy: data_model,
        ..MstOptions::default()
    });
    let root_cid = mst
        .insert("app.bsky.feed.post/self", foreign.clone())
        .await
        .unwrap();
    let commit = CommitCodec::prepare(
        &CommitDescriptor {
            did: did.clone(),
            rev: RepositoryTid::parse("3jzfcijpj2z2a").unwrap(),
            data_cid: root_cid,
            prev_cid: None,
        },
        &signer,
        &limits,
    )
    .await
    .unwrap();

    let mut archive_blocks = vec![RepositoryBlock::new(
        commit.cid.clone(),
        commit.signed_commit_bytes.clone(),
    )];
    archive_blocks.extend(mst.new_blocks());
    let car =
        PublicRepositoryCAR::write(std::slice::from_ref(&commit.cid), &archive_blocks).unwrap();

    // 1. Opening with `data_model()` + `verifies_tree = true` preserves the foreign leaf link.
    let opened = Repository::open_car_with_options(
        &car,
        OpenVerification::SigningKey(signer.public_key().clone()),
        Some(&did),
        limits,
        data_model,
        true,
    )
    .await
    .unwrap();
    let stats = opened.statistics().unwrap();
    assert_eq!(stats.record_count, 1);
    assert_eq!(stats.unverifiable_record_count, 1);
    assert_eq!(
        opened
            .record_cid("app.bsky.feed.post", "self")
            .await
            .unwrap(),
        Some(foreign.clone())
    );
    let refs = opened.record_references(None).await.unwrap();
    assert_eq!(refs.len(), 1);
    assert_eq!(refs[0].cid, foreign);

    // Direct record payload read fails with `UnsupportedRecordCid`.
    let read_err = opened
        .record("app.bsky.feed.post", "self")
        .await
        .unwrap_err();
    assert!(matches!(
        read_err,
        RepositoryError::UnsupportedRecordCid { ref path, ref cid }
            if path == "app.bsky.feed.post/self" && cid == &foreign
    ));
    let records_err = opened.records(None).await.unwrap_err();
    assert!(matches!(
        records_err,
        RepositoryError::UnsupportedRecordCid { ref path, ref cid }
            if path == "app.bsky.feed.post/self" && cid == &foreign
    ));

    // All three CAR export orders succeed without MissingBlock and re-open cleanly under `data_model()`.
    for order in [
        CARExportOrder::Stored,
        CARExportOrder::Streamable,
        CARExportOrder::BreadthFirst,
    ] {
        let sink = DataCARByteSink::new();
        opened.export_car_to_sink(&sink, order).await.unwrap();
        let exported = sink.into_bytes().await;
        if order == CARExportOrder::Stored {
            assert_eq!(exported, car);
        }
        let reopened = Repository::open_car_with_options(
            &exported,
            OpenVerification::SigningKey(signer.public_key().clone()),
            Some(&did),
            limits,
            data_model,
            true,
        )
        .await
        .unwrap();
        assert_eq!(
            reopened
                .record_cid("app.bsky.feed.post", "self")
                .await
                .unwrap(),
            Some(foreign.clone())
        );
    }

    // Writing a normal record keeps the foreign leaf link intact.
    let batch = WriteBatch::new(vec![
        create_op(
            "app.bsky.feed.post",
            "other",
            &post_record_value("new verifiable record"),
        )
        .unwrap(),
    ])
    .unwrap();
    let committed = opened.commit_writes(batch, &signer).await.unwrap();
    let written_stats = committed.repository.statistics().unwrap();
    assert_eq!(written_stats.record_count, 2);
    assert_eq!(written_stats.unverifiable_record_count, 1);
    assert_eq!(
        committed
            .repository
            .record_cid("app.bsky.feed.post", "self")
            .await
            .unwrap(),
        Some(foreign.clone())
    );
    assert!(
        committed
            .repository
            .record("app.bsky.feed.post", "other")
            .await
            .unwrap()
            .is_some()
    );

    // 2. Strict policy rejects non-blessed leaf links.
    let strict_err = Repository::open_car_with_options(
        &car,
        OpenVerification::SigningKey(signer.public_key().clone()),
        Some(&did),
        limits,
        strict,
        true,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        strict_err,
        RepositoryError::Mst(MstError::UnblessedLink(_))
    ));

    // 3. Structural MST links (`l` and `t`) are ALWAYS required to be blessed DAG-CBOR even
    // under `data_model()`.
    let raw_cid = Cid::for_raw(b"not-an-mst-node");
    let (_, bad_left_bytes) = encode_mst_node(&MstNodeView {
        left: Some(raw_cid.clone()),
        entries: vec![MstNodeEntryView {
            key: "app.bsky.feed.post/other".into(),
            value: Cid::for_dag_cbor(b"\xa0"),
            tree: None,
        }],
    })
    .unwrap();
    let (_, bad_right_bytes) = encode_mst_node(&MstNodeView {
        left: None,
        entries: vec![MstNodeEntryView {
            key: "app.bsky.feed.post/other".into(),
            value: Cid::for_dag_cbor(b"\xa0"),
            tree: Some(raw_cid),
        }],
    })
    .unwrap();
    for bad_node in [bad_left_bytes, bad_right_bytes] {
        for policy in [strict, data_model] {
            let err =
                decode_mst_node(&bad_node, MstKeySyntax::StrictAtProto, &policy, true).unwrap_err();
            assert!(matches!(err, MstError::UnblessedLink(_)));
        }
    }
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn open_car_source_rolls_back_on_error_and_open_store_enforces_block_count() {
    use petrel_repo::block_store::BlockStore as _;
    use petrel_repo::car::PublicRepositoryCAR;
    use petrel_repo::error::{LimitError, LimitKind, RepositoryError};

    let did = common::test_did();
    let signer = P256Keypair::generate().unwrap();
    let other_signer = P256Keypair::generate().unwrap();
    let limits = RepositoryLimits::standard();
    let policy = RepositoryReadPolicy::strict();

    // Create a valid signed empty repo CAR + a signed populated CAR sharing one record CID.
    let empty_repo = Repository::create(did.clone(), &signer).await.unwrap();
    let empty_cid = empty_repo.commit().cid.clone();
    let empty_car = empty_repo.export_car().await.unwrap();

    // Verify `open_store` enforces combined `max_block_count` on an empty repository (2 blocks).
    let one_block_limits = RepositoryLimits {
        max_block_count: 1,
        max_record_count: 1,
        max_mst_node_count: 1,
        ..limits
    };
    let two_block_limits = RepositoryLimits {
        max_block_count: 2,
        max_record_count: 2,
        max_mst_node_count: 2,
        ..limits
    };
    let err_empty = Repository::open_store(
        empty_cid.clone(),
        Arc::clone(empty_repo.store()),
        OpenVerification::SigningKey(signer.public_key().clone()),
        Some(&did),
        one_block_limits,
        policy,
        true,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        err_empty,
        RepositoryError::Limit(LimitError::Exceeded {
            kind: LimitKind::BlockCount,
            observed: 2,
            limit: 1,
        })
    ));
    assert!(
        Repository::open_store(
            empty_cid.clone(),
            Arc::clone(empty_repo.store()),
            OpenVerification::SigningKey(signer.public_key().clone()),
            Some(&did),
            two_block_limits,
            policy,
            true,
        )
        .await
        .is_ok()
    );

    // `open_store` also enforces `max_single_block_bytes` on the commit block itself (Codex 4697647815).
    let tiny_commit_limits = RepositoryLimits {
        max_single_block_bytes: 64,
        ..limits
    };
    let err_commit_size = Repository::open_store(
        empty_cid.clone(),
        Arc::clone(empty_repo.store()),
        OpenVerification::SigningKey(signer.public_key().clone()),
        Some(&did),
        tiny_commit_limits,
        policy,
        true,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        err_commit_size,
        RepositoryError::Limit(LimitError::Exceeded {
            kind: LimitKind::SingleBlockBytes,
            limit: 64,
            ..
        })
    ));

    // Populated repo where two keys share the exact same record CID: 1 commit + 1 MST + 1 record = 3 blocks.
    let shared_val = post_record_value("shared");
    let batch = WriteBatch::new(vec![
        create_op("app.bsky.feed.post", "r1", &shared_val).unwrap(),
        create_op("app.bsky.feed.post", "r2", &shared_val).unwrap(),
    ])
    .unwrap();
    let populated = empty_repo.commit_writes(batch, &signer).await.unwrap();
    let err_shared = Repository::open_store(
        populated.commit.cid.clone(),
        Arc::clone(populated.repository.store()),
        OpenVerification::SigningKey(signer.public_key().clone()),
        Some(&did),
        two_block_limits,
        policy,
        true,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        err_shared,
        RepositoryError::Limit(LimitError::Exceeded {
            kind: LimitKind::BlockCount,
            observed: 3,
            limit: 2,
        })
    ));
    let three_block_limits = RepositoryLimits {
        max_block_count: 3,
        max_record_count: 3,
        max_mst_node_count: 3,
        ..limits
    };
    assert!(
        Repository::open_store(
            populated.commit.cid.clone(),
            Arc::clone(populated.repository.store()),
            OpenVerification::SigningKey(signer.public_key().clone()),
            Some(&did),
            three_block_limits,
            policy,
            true,
        )
        .await
        .is_ok()
    );

    // `open_car_source` rolls back newly added blocks when verification fails while keeping pre-existing blocks.
    let pre_bytes = dagcbor::encode(&Value::String("pre-existing".into()));
    let pre_cid = Cid::for_dag_cbor(&pre_bytes);
    let mem_store = Arc::new(InMemoryBlockStore::new());
    mem_store.put_block(&pre_cid, &pre_bytes).await.unwrap();
    let mut source = petrel_repo::DataCARByteSource::new(empty_car.clone());
    let err_sig = Repository::open_car_source(
        &mut source,
        Arc::clone(&mem_store),
        OpenVerification::SigningKey(other_signer.public_key().clone()),
        Some(&did),
        limits,
        policy,
        true,
    )
    .await
    .unwrap_err();
    assert!(matches!(err_sig, RepositoryError::Commit(_)));
    assert_eq!(mem_store.all_cids().await.unwrap(), vec![pre_cid.clone()]);

    // Also confirm failed rollback when `verifies_tree` fails after valid commit verification (block_count = 1).
    let mut source2 = petrel_repo::DataCARByteSource::new(empty_car);
    let err_limit = Repository::open_car_source(
        &mut source2,
        Arc::clone(&mem_store),
        OpenVerification::SigningKey(signer.public_key().clone()),
        Some(&did),
        one_block_limits,
        policy,
        true,
    )
    .await
    .unwrap_err();
    assert!(matches!(
        err_limit,
        RepositoryError::Car(petrel_repo::error::CARError::Limit(LimitError::Exceeded {
            kind: LimitKind::BlockCount,
            ..
        }))
    ));
    assert_eq!(mem_store.all_cids().await.unwrap(), vec![pre_cid]);

    // `verify_record_proof` fails closed on non-DAG-CBOR leaf even under `data_model()`.
    let raw_leaf = Cid::for_raw(b"\xa0");
    let (mst, mst_blocks) = petrel_repo::mst::tree::build_mst_from_entries(
        vec![("app.bsky.feed.post/bad".to_owned(), raw_leaf.clone())],
        petrel_repo::mst::MstOptions {
            policy: RepositoryReadPolicy::data_model(),
            ..petrel_repo::mst::MstOptions::default()
        },
    )
    .unwrap();
    let bad_commit = CommitCodec::prepare(
        &CommitDescriptor {
            did: did.clone(),
            rev: RepositoryTid::parse("3jzfcijpj2z2b").unwrap(),
            data_cid: mst.root_cid().clone(),
            prev_cid: None,
        },
        &signer,
        &limits,
    )
    .await
    .unwrap();
    let mut proof_blocks = vec![RepositoryBlock::new(
        bad_commit.cid.clone(),
        bad_commit.signed_commit_bytes,
    )];
    proof_blocks.extend(mst_blocks);
    proof_blocks.push(RepositoryBlock::new(raw_leaf, b"\xa0".to_vec()));
    let bad_car =
        PublicRepositoryCAR::write(std::slice::from_ref(&bad_commit.cid), &proof_blocks).unwrap();
    let err_proof = Repository::verify_record_proof_with_options(
        &bad_car,
        &did,
        "app.bsky.feed.post",
        "bad",
        OpenVerification::SigningKey(signer.public_key().clone()),
        limits,
        RepositoryReadPolicy::data_model(),
    )
    .await
    .unwrap_err();
    assert!(matches!(
        err_proof,
        RepositoryError::ProofFailure(_) | RepositoryError::MissingBlock(_)
    ));
}

#[cfg(not(target_arch = "wasm32"))]
#[tokio::test]
async fn open_car_source_rolls_back_file_block_store_on_error() {
    use petrel_repo::block_store::BlockStore as _;

    let did = common::test_did();
    let signer = P256Keypair::generate().unwrap();
    let wrong_signer = P256Keypair::generate().unwrap();
    let limits = RepositoryLimits::standard();
    let policy = RepositoryReadPolicy::strict();

    let repo = Repository::create(did.clone(), &signer).await.unwrap();
    let car = repo.export_car().await.unwrap();

    let dir = tempfile::tempdir().unwrap();
    let store_path = dir.path().join("rollback.carframes");
    let file_store = Arc::new(petrel_repo::FileBlockStore::open(&store_path).unwrap());

    let pre_bytes = dagcbor::encode(&Value::String("kept".into()));
    let pre_cid = Cid::for_dag_cbor(&pre_bytes);
    file_store.put_block(&pre_cid, &pre_bytes).await.unwrap();
    file_store.synchronize().await.unwrap();

    let mut source = petrel_repo::DataCARByteSource::new(car);
    let err = Repository::open_car_source(
        &mut source,
        Arc::clone(&file_store),
        OpenVerification::SigningKey(wrong_signer.public_key().clone()),
        Some(&did),
        limits,
        policy,
        true,
    )
    .await
    .unwrap_err();
    assert!(matches!(err, petrel_repo::RepositoryError::Commit(_)));
    assert_eq!(file_store.all_cids().await.unwrap(), vec![pre_cid.clone()]);
    drop(file_store);

    let reopened = petrel_repo::FileBlockStore::open(&store_path).unwrap();
    assert_eq!(reopened.all_cids().await.unwrap(), vec![pre_cid]);
}
