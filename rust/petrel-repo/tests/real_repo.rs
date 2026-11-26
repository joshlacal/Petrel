mod common;

use std::collections::BTreeMap;
use std::sync::Arc;

use petrel_core::{Cid, Did, Value};
use petrel_repo::block_store::BlockStore as _;
use petrel_repo::car::CARRepository;
use petrel_repo::crypto::{CommitSigner as _, K256Keypair, SigningPublicKey};
use petrel_repo::diff::CommitDiff;
use petrel_repo::limits::RepositoryLimits;
use petrel_repo::repository::{CARExportOrder, OpenVerification, Repository, create_op};
use petrel_repo::types::{RepositoryPath, RepositoryReadPolicy, WriteBatch};
use serde::Deserialize;
use sha2::{Digest as _, Sha256};

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ExpectedRealRepo {
    did: String,
    rev: String,
    version: i64,
    commit: String,
    data: String,
    prev: Option<String>,
    car_bytes: usize,
    #[serde(rename = "carSHA256")]
    car_sha256: String,
    frames: usize,
    distinct_blocks: usize,
    records: usize,
    collections: BTreeMap<String, usize>,
}

fn hex_lower(bytes: &[u8]) -> String {
    use std::fmt::Write as _;
    let mut out = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        let _ = write!(&mut out, "{b:02x}");
    }
    out
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn real_repository_differential_and_proof_checks() {
    let expected: ExpectedRealRepo =
        serde_json::from_str(common::real_repo_expected_json()).unwrap();
    let car_bytes = common::real_repo_car();
    assert_eq!(car_bytes.len(), expected.car_bytes);
    let sha: [u8; 32] = Sha256::digest(car_bytes).into();
    assert_eq!(hex_lower(&sha), expected.car_sha256);

    let did = Did::parse(&expected.did).unwrap();
    let key = Repository::signing_key_from_did_document(common::real_repo_diddoc(), &did).unwrap();

    // Verify independent lightweight CARRepository parser matches expected metadata & counts
    let raw_repo = CARRepository::parse(car_bytes).unwrap();
    assert_eq!(raw_repo.did, expected.did);
    assert_eq!(raw_repo.version, expected.version);
    assert_eq!(raw_repo.rev.as_deref(), Some(expected.rev.as_str()));
    assert_eq!(raw_repo.data_cid.to_string(), expected.data);
    assert!(raw_repo.prev_cid.is_none());
    assert!(expected.prev.is_none());
    let raw_counts: BTreeMap<String, usize> = raw_repo
        .collections
        .iter()
        .map(|(k, v)| (k.clone(), v.len()))
        .collect();
    assert_eq!(raw_counts, expected.collections);
    assert_eq!(raw_repo.records.len(), expected.records);

    // Open & fully verify repository (v3 commit signature, full MST, every record block)
    let repo = Repository::open_car(
        car_bytes,
        OpenVerification::SigningKey(key.clone()),
        Some(&did),
    )
    .await
    .unwrap();
    assert_eq!(repo.commit().cid.to_string(), expected.commit);
    assert_eq!(repo.commit().data_cid.to_string(), expected.data);
    assert_eq!(repo.revision().as_str(), expected.rev);
    assert_eq!(repo.store().len().await.unwrap(), expected.distinct_blocks);
    assert!(expected.frames >= expected.distinct_blocks);
    let stats = repo.statistics().unwrap();
    assert_eq!(stats.record_count, expected.records);

    // Per-collection enumeration & record lookup parity (Documentation examples)
    let profile = repo
        .record("app.bsky.actor.profile", "self")
        .await
        .unwrap()
        .expect("profile/self exists");
    let profile_record = profile.record().unwrap();
    assert_eq!(profile_record.record_type(), Some("app.bsky.actor.profile"));
    assert_ne!(profile.json_string().unwrap(), "");

    let post_refs = repo
        .record_references(Some("app.bsky.feed.post"))
        .await
        .unwrap();
    assert_eq!(post_refs.len(), 297);
    let post_keys: Vec<&str> = post_refs.iter().map(|r| r.path.record_key_str()).collect();
    let mut sorted_keys = post_keys.clone();
    sorted_keys.sort_unstable();
    assert_eq!(post_keys, sorted_keys);

    // Verify server-issued inclusion proof for app.bsky.actor.profile/self
    let present_proof = Repository::verify_record_proof(
        common::real_repo_proof_present_car(),
        &did,
        "app.bsky.actor.profile",
        "self",
        OpenVerification::SigningKey(key.clone()),
    )
    .await
    .unwrap();
    let proven_record = present_proof
        .record
        .expect("inclusion proof includes record");
    assert_eq!(proven_record.cid, profile.cid);

    // Self-constructed inclusion proof roundtrips cleanly
    let built_proof = repo
        .record_proof("app.bsky.actor.profile", "self")
        .await
        .unwrap();
    assert_eq!(built_proof.record_cid, Some(profile.cid.clone()));
    let rebuilt_car = built_proof.car().unwrap();
    let re_verified = Repository::verify_record_proof(
        &rebuilt_car,
        &did,
        "app.bsky.actor.profile",
        "self",
        OpenVerification::SigningKey(key.clone()),
    )
    .await
    .unwrap();
    assert_eq!(re_verified.record.unwrap().cid, profile.cid);

    // Verify server-issued exclusion proof for app.bsky.actor.profile/doesnotexist
    let absent_proof = Repository::verify_record_proof(
        common::real_repo_proof_absent_car(),
        &did,
        "app.bsky.actor.profile",
        "doesnotexist",
        OpenVerification::SigningKey(key.clone()),
    )
    .await
    .unwrap();
    assert!(absent_proof.record.is_none());

    // Exclusion proof for `doesnotexist` cannot falsely certify missing `self`
    assert!(
        Repository::verify_record_proof(
            common::real_repo_proof_absent_car(),
            &did,
            "app.bsky.actor.profile",
            "self",
            OpenVerification::SigningKey(key.clone()),
        )
        .await
        .is_err()
    );

    // Export CAR in all 3 modes and reopen
    for order in [
        CARExportOrder::Streamable,
        CARExportOrder::BreadthFirst,
        CARExportOrder::Stored,
    ] {
        let sink = petrel_repo::car::DataCARByteSink::new();
        repo.export_car_to_sink(&sink, order).await.unwrap();
        let exported = sink.into_bytes().await;
        let reopened = Repository::open_car(
            &exported,
            OpenVerification::SigningKey(key.clone()),
            Some(&did),
        )
        .await
        .unwrap();
        assert_eq!(reopened.commit().cid, repo.commit().cid);
        assert_eq!(reopened.statistics(), repo.statistics());
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn documentation_make_a_commit_and_verify_diff_flow() {
    let did = common::test_did();
    let signer = K256Keypair::generate().unwrap();
    let mine = Repository::create(did.clone(), &signer).await.unwrap();

    let mut post_fields = BTreeMap::new();
    post_fields.insert(
        "$type".to_owned(),
        Value::String("app.bsky.feed.post".into()),
    );
    post_fields.insert("text".to_owned(), Value::String("Hello from Petrel".into()));
    post_fields.insert(
        "createdAt".to_owned(),
        Value::String("2026-11-11T12:00:00.000Z".into()),
    );
    let post_val = Value::Object(post_fields);
    let op = create_op("app.bsky.feed.post", "3lon5dzeaihj2", &post_val).unwrap();
    let result = mine
        .commit_writes(WriteBatch::new(vec![op]).unwrap(), &signer)
        .await
        .unwrap();

    let head = &result.repository;
    let export = head.export_car().await.unwrap();
    let reopened = Repository::open_car(
        &export,
        OpenVerification::SigningKey(signer.public_key().clone()),
        None,
    )
    .await
    .unwrap();
    assert_eq!(reopened.statistics().unwrap().record_count, 1);
    let loaded = reopened
        .record("app.bsky.feed.post", "3lon5dzeaihj2")
        .await
        .unwrap()
        .unwrap();
    assert_eq!(loaded.record().unwrap().as_value(), post_val);
    assert!(mine.revision() < head.revision());

    let diff_car = result.diff_car();
    let diff_store = Arc::new(petrel_repo::block_store::InMemoryBlockStore::new());
    let parsed_diff = petrel_repo::car::PublicRepositoryCAR::load(
        diff_car,
        diff_store.as_ref(),
        &RepositoryLimits::standard(),
        &RepositoryReadPolicy::strict(),
    )
    .await
    .unwrap();
    assert_eq!(parsed_diff.root_cid, head.commit().cid);

    let received = Repository::open_store(
        parsed_diff.root_cid.clone(),
        Arc::clone(&diff_store),
        OpenVerification::SigningKey(signer.public_key().clone()),
        None,
        RepositoryLimits::standard(),
        RepositoryReadPolicy::strict(),
        false,
    )
    .await
    .unwrap();

    CommitDiff::verify_inversion(
        &received.commit().data_cid,
        &result.operations,
        result.previous_data_cid.as_ref(),
        Arc::clone(&diff_store),
        &RepositoryLimits::standard(),
        &RepositoryReadPolicy::strict(),
    )
    .await
    .unwrap();

    let fixed_key =
        petrel_repo::crypto::FixedSigningKey::from_public_key(signer.public_key().clone());
    let verified_diff = CommitDiff::verify(
        &head.commit().cid,
        &result.operations,
        result.previous_data_cid.as_ref(),
        diff_store,
        &fixed_key,
        Some(&did),
        &RepositoryLimits::standard(),
        &RepositoryReadPolicy::strict(),
    )
    .await
    .unwrap();
    assert_eq!(verified_diff.operations.len(), 1);
    let _ = Cid::for_dag_cbor(&[]);
    let _ = SigningPublicKey::from_did_key(&signer.did_key()).unwrap();
    let _ = RepositoryPath::new("app.bsky.feed.post", "3lon5dzeaihj2").unwrap();
    let _ = signer.algorithm();
}

#[cfg(not(target_arch = "wasm32"))]
#[tokio::test]
async fn real_repo_streams_through_file_block_store_and_file_car_sink() {
    let dir = tempfile::tempdir().unwrap();
    let repo_car_path = dir.path().join("input.car");
    std::fs::write(&repo_car_path, common::real_repo_car()).unwrap();

    let expected: ExpectedRealRepo =
        serde_json::from_str(common::real_repo_expected_json()).unwrap();
    let did = Did::parse(&expected.did).unwrap();
    let key = Repository::signing_key_from_did_document(common::real_repo_diddoc(), &did).unwrap();

    let store = Arc::new(petrel_repo::FileBlockStore::open(dir.path().join("blocks.car")).unwrap());
    let mut source = petrel_repo::FileCARByteSource::open(&repo_car_path).unwrap();
    let large = Repository::open_car_source(
        &mut source,
        Arc::clone(&store),
        OpenVerification::SigningKey(key.clone()),
        Some(&did),
        RepositoryLimits::network_scale(),
        RepositoryReadPolicy::strict(),
        true,
    )
    .await
    .unwrap();

    let copy_path = dir.path().join("copy.car");
    let sink = petrel_repo::FileCARByteSink::create(&copy_path).unwrap();
    large
        .export_car_to_sink(&sink, CARExportOrder::Streamable)
        .await
        .unwrap();
    sink.synchronize().await.unwrap();

    let copy_store =
        Arc::new(petrel_repo::FileBlockStore::open(dir.path().join("copy_blocks.car")).unwrap());
    let mut copy_src = petrel_repo::FileCARByteSource::open(&copy_path).unwrap();
    let copy = Repository::open_car_source(
        &mut copy_src,
        copy_store,
        OpenVerification::SigningKey(key),
        Some(&did),
        RepositoryLimits::network_scale(),
        RepositoryReadPolicy::strict(),
        true,
    )
    .await
    .unwrap();

    assert_eq!(copy.commit().cid, large.commit().cid);
    assert_eq!(copy.statistics(), large.statistics());
}
