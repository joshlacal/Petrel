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
