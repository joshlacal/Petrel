mod common;

use std::collections::BTreeMap;

use petrel_core::{Cid, Value, dagcbor};
use petrel_repo::block_store::{BlockSource as _, InMemoryBlockStore, RepositoryBlock};
use petrel_repo::car::{
    CARByteSource as _, CARReader, CARRepository, DataCARByteSink, DataCARByteSource,
    PublicRepositoryCAR, varint,
};
use petrel_repo::error::{CARError, CARReaderError};
use petrel_repo::limits::RepositoryLimits;
use petrel_repo::mst::codec::{MstNodeEntryView, MstNodeView, encode_mst_node};
use petrel_repo::types::RepositoryReadPolicy;
use sha2::{Digest as _, Sha256};

fn cbor_block(val: &Value) -> (Cid, Vec<u8>) {
    let bytes = dagcbor::encode(val);
    let cid = Cid::for_dag_cbor(&bytes);
    (cid, bytes)
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn car_reader_rejects_empty_and_truncated_inputs() {
    assert!(matches!(
        CARReader::parse(&[]),
        Err(CARReaderError::Truncated)
    ));
    assert!(matches!(
        CARReader::parse(&[0x05, 0xa2]),
        Err(CARReaderError::Truncated)
    ));
    let (cid, payload) = cbor_block(&Value::Object(BTreeMap::new()));
    let mut car = PublicRepositoryCAR::write(
        std::slice::from_ref(&cid),
        &[RepositoryBlock::new(cid.clone(), payload)],
    )
    .unwrap();
    car.pop();
    assert!(matches!(
        CARReader::parse(&car),
        Err(CARReaderError::Truncated)
    ));
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn car_reader_rejects_non_canonical_and_overflow_varints() {
    // Non-canonical trailing 0x00 in varint: `0x81, 0x00`
    assert!(matches!(
        varint::decode(&[0x81, 0x00]),
        Err(CARError::NonCanonicalVarint)
    ));
    assert!(matches!(
        CARReader::parse(&[0x81, 0x00]),
        Err(CARReaderError::InvalidVarint)
    ));
    // Overlong 10-byte varint
    assert!(matches!(
        varint::decode(&[0x80; 10]),
        Err(CARError::VarintOverflow)
    ));
    assert!(matches!(
        CARReader::parse(&[0x80; 10]),
        Err(CARReaderError::InvalidVarint)
    ));
    // 9th byte with continuation bit set (> i64::MAX)
    let over63 = [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x80, 0x01];
    assert!(matches!(
        varint::decode(&over63),
        Err(CARError::VarintOverflow)
    ));
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn car_reader_rejects_bad_headers() {
    let (cid, payload) = cbor_block(&Value::Object(BTreeMap::new()));
    // Version 2
    let mut bad_ver = BTreeMap::new();
    bad_ver.insert(
        "roots".to_owned(),
        Value::Array(vec![Value::Link(cid.clone())]),
    );
    bad_ver.insert("version".to_owned(), Value::Integer(2));
    let header_bytes = dagcbor::encode(&Value::Object(bad_ver));
    let mut car = Vec::new();
    varint::push_varint(header_bytes.len() as u64, &mut car).unwrap();
    car.extend_from_slice(&header_bytes);
    assert!(matches!(
        CARReader::parse(&car),
        Err(CARReaderError::UnsupportedVersion(2))
    ));

    // Missing roots
    let mut empty_roots = BTreeMap::new();
    empty_roots.insert("roots".to_owned(), Value::Array(vec![]));
    empty_roots.insert("version".to_owned(), Value::Integer(1));
    let header_bytes = dagcbor::encode(&Value::Object(empty_roots));
    let mut car = Vec::new();
    varint::push_varint(header_bytes.len() as u64, &mut car).unwrap();
    car.extend_from_slice(&header_bytes);
    assert!(matches!(
        CARReader::parse(&car),
        Err(CARReaderError::MissingRoots)
    ));

    // Unexpected extra key in header
    let mut extra = BTreeMap::new();
    extra.insert("roots".to_owned(), Value::Array(vec![Value::Link(cid)]));
    extra.insert("version".to_owned(), Value::Integer(1));
    extra.insert("extra".to_owned(), Value::Integer(9));
    let header_bytes = dagcbor::encode(&Value::Object(extra));
    let mut car = Vec::new();
    varint::push_varint(header_bytes.len() as u64, &mut car).unwrap();
    car.extend_from_slice(&header_bytes);
    assert!(matches!(
        CARReader::parse(&car),
        Err(CARReaderError::InvalidHeader(_))
    ));
    let _ = payload;
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn car_reader_accepts_cidv0_and_rejects_hash_mismatch_and_conflicting_duplicates() {
    let payload = b"hello cidv0 payload".to_vec();
    let digest: [u8; 32] = Sha256::digest(&payload).into();
    let mut cidv0 = vec![0x12, 0x20];
    cidv0.extend_from_slice(&digest);

    let (root_cid, root_bytes) = cbor_block(&Value::Object(BTreeMap::new()));
    let valid_car = common::encode_raw_car(
        std::slice::from_ref(&root_cid),
        &[
            (root_cid.as_bytes().to_vec(), root_bytes.clone()),
            (cidv0.clone(), payload.clone()),
            // Exact identical duplicate is idempotent.
            (cidv0.clone(), payload.clone()),
        ],
    );
    let parsed = CARReader::parse(&valid_car).unwrap();
    assert_eq!(parsed.blocks.len(), 1);
    assert_eq!(parsed.raw_blocks.len(), 2);

    // Hash mismatch
    let tampered = common::encode_raw_car(
        std::slice::from_ref(&root_cid),
        &[(cidv0.clone(), b"tampered".to_vec())],
    );
    assert!(matches!(
        CARReader::parse(&tampered),
        Err(CARReaderError::HashMismatch(_))
    ));

    // Conflicting duplicate
    let mut other_cidv1_bytes = root_bytes.clone();
    other_cidv1_bytes.push(0x00);
    // Use non-matching second block with same CIDv1 bytes directly in raw CAR
    let conflicting = common::encode_raw_car(
        std::slice::from_ref(&root_cid),
        &[
            (root_cid.as_bytes().to_vec(), root_bytes),
            (root_cid.as_bytes().to_vec(), b"bad".to_vec()),
        ],
    );
    assert!(matches!(
        CARReader::parse(&conflicting),
        Err(CARReaderError::HashMismatch(_) | CARReaderError::ConflictingDuplicateBlock(_))
    ));

    // Unsupported multihash algorithm (0x13 = sha2-512)
    let mut sha512_cid = vec![0x01, 0x71, 0x13, 0x20];
    sha512_cid.extend_from_slice(&[0_u8; 32]);
    let bad_hash = common::encode_raw_car(
        std::slice::from_ref(&root_cid),
        &[(sha512_cid, b"abc".to_vec())],
    );
    assert!(matches!(
        CARReader::parse(&bad_hash),
        Err(CARReaderError::UnsupportedMultihash(0x13))
    ));
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn car_repository_detects_mst_cycles_depth_and_ordering() {
    let did = common::test_did();
    let signer = common::deterministic_p256_signer();
    let empty_cid = Cid::parse(petrel_repo::CANONICAL_EMPTY_MST_CID).unwrap();

    // Commit pointing to an MST cycle: node_a.left = node_a? Construct via crafted CID
    // Wait: SHA-256 can't self-cycle, so construct 2-node cycle? Even 2-node cycle can't hash-cycle,
    // wait: CAN construct duplicate shared child visited only if cycle? No, diamond DAG is NOT a cycle!
    // What DOES trigger cycle check in CARRepository? A valid hash chain cannot cycle, EXCEPT
    // a node referencing ITSELF cannot happen with SHA-256, unless a custom/synthetic hash;
    // instead test > 128 depth chain!
    let mut rec_map = BTreeMap::new();
    rec_map.insert(
        "$type".to_owned(),
        Value::String("app.bsky.feed.post".into()),
    );
    rec_map.insert("text".to_owned(), Value::String("deep".into()));
    let (rec_cid, rec_bytes) = cbor_block(&Value::Object(rec_map));

    let mut cur_cid = rec_cid.clone();
    let mut blocks = vec![(rec_cid.as_bytes().to_vec(), rec_bytes)];
    let (leaf_cid, leaf_bytes) = encode_mst_node(&MstNodeView {
        left: None,
        entries: vec![MstNodeEntryView {
            key: "app.bsky.feed.post/3k2abc".into(),
            value: cur_cid,
            tree: None,
        }],
    })
    .unwrap();
    cur_cid = leaf_cid.clone();
    blocks.push((leaf_cid.as_bytes().to_vec(), leaf_bytes));

    for _ in 0..130 {
        let (wrap_cid, wrap_bytes) = encode_mst_node(&MstNodeView {
            left: Some(cur_cid),
            entries: vec![],
        })
        .unwrap();
        blocks.push((wrap_cid.as_bytes().to_vec(), wrap_bytes));
        cur_cid = wrap_cid;
    }

    let mut commit = BTreeMap::new();
    commit.insert("did".to_owned(), Value::String(did.as_str().to_owned()));
    commit.insert("rev".to_owned(), Value::String("3jzfcijpj2z2a".into()));
    commit.insert("data".to_owned(), Value::Link(cur_cid));
    commit.insert("prev".to_owned(), Value::Null);
    commit.insert("version".to_owned(), Value::Integer(3));
    let unsigned = dagcbor::encode(&Value::Object(commit.clone()));
    let sig = signer.sign_sync(&unsigned).unwrap();
    commit.insert("sig".to_owned(), Value::Bytes(sig));
    let (commit_cid, commit_bytes) = cbor_block(&Value::Object(commit));
    blocks.push((commit_cid.as_bytes().to_vec(), commit_bytes));

    let car = common::encode_raw_car(std::slice::from_ref(&commit_cid), &blocks);
    assert!(matches!(
        CARRepository::parse(&car),
        Err(CARReaderError::MstDepthLimitExceeded)
    ));
    let _ = empty_cid;
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn public_car_writes_canonical_58_byte_header_and_streams_equivalently() {
    let (cid, bytes) = cbor_block(&Value::String("hello".into()));
    let car = PublicRepositoryCAR::write(
        std::slice::from_ref(&cid),
        &[RepositoryBlock::new(cid.clone(), bytes.clone())],
    )
    .unwrap();
    // Canonical single-root header is 1 byte varint (0x3a = 58) + 58 bytes DAG-CBOR = 59 bytes.
    assert_eq!(car[0], 0x3a);
    assert!(car.len() > 59);

    // Chunked streaming (7-byte chunks) matches full-buffer load cleanly.
    let limits = RepositoryLimits::standard();
    let policy = RepositoryReadPolicy::strict();
    let (_, full_store) = PublicRepositoryCAR::import_bytes(&car, &limits, &policy)
        .await
        .unwrap();

    let stream_store = InMemoryBlockStore::new();
    let mut source = DataCARByteSource::with_chunk_size(car.clone(), 7);
    let parsed =
        PublicRepositoryCAR::load_from_source(&mut source, &stream_store, &limits, &policy)
            .await
            .unwrap();
    assert!(source.next_chunk().await.unwrap().is_none());
    assert_eq!(parsed.root_cid, cid);
    assert_eq!(parsed.block_count, 1);
    assert_eq!(stream_store.get_block(&cid).await.unwrap(), Some(bytes));
    assert_eq!(full_store.snapshot().await, stream_store.snapshot().await);

    // Roundtrip via DataCARByteSink
    let sink = DataCARByteSink::new();
    PublicRepositoryCAR::write_to_sink(
        std::slice::from_ref(&cid),
        &[RepositoryBlock::new(
            cid.clone(),
            full_store.get_block(&cid).await.unwrap().unwrap(),
        )],
        &sink,
    )
    .await
    .unwrap();
    assert_eq!(sink.into_bytes().await, car);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn public_car_enforces_foreign_blocks_and_root_policies() {
    let raw_payload = b"raw-bytes-payload".to_vec();
    let raw_cid = Cid::for_raw(&raw_payload);
    let (cbor_cid, cbor_bytes) = cbor_block(&Value::Integer(42));
    let car = PublicRepositoryCAR::write(
        std::slice::from_ref(&cbor_cid),
        &[
            RepositoryBlock::new(cbor_cid.clone(), cbor_bytes),
            RepositoryBlock::new(raw_cid.clone(), raw_payload.clone()),
        ],
    )
    .unwrap();

    let limits = RepositoryLimits::standard();
    // Strict rejects raw blocks (`rejects_foreign_car_blocks = true`).
    let strict_err =
        PublicRepositoryCAR::import_bytes(&car, &limits, &RepositoryReadPolicy::strict())
            .await
            .unwrap_err();
    assert!(matches!(strict_err, CARError::ForeignBlockRejected(_)));

    // Data model tolerates/ignores foreign non-repository blocks (`raw`).
    let (parsed, store) =
        PublicRepositoryCAR::import_bytes(&car, &limits, &RepositoryReadPolicy::data_model())
            .await
            .unwrap();
    assert_eq!(parsed.block_count, 1);
    assert_eq!(store.get_block(&cbor_cid).await.unwrap().unwrap().len(), 2);
    assert!(store.get_block(&raw_cid).await.unwrap().is_none());

    // Multi-root CAR enforcement
    let two_root_car = PublicRepositoryCAR::write(&[cbor_cid.clone(), raw_cid], &[]).unwrap();
    let mut multi_limits = limits;
    multi_limits.max_car_roots = 4;
    let strict_multi = PublicRepositoryCAR::import_bytes(
        &two_root_car,
        &multi_limits,
        &RepositoryReadPolicy::strict(),
    )
    .await
    .unwrap_err();
    assert!(matches!(strict_multi, CARError::MultipleRoots { count: 2 }));

    let (parsed_multi, _) = PublicRepositoryCAR::import_bytes(
        &two_root_car,
        &multi_limits,
        &RepositoryReadPolicy::data_model(),
    )
    .await
    .unwrap();
    assert_eq!(parsed_multi.roots.len(), 2);
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
async fn public_car_counts_foreign_blocks_toward_max_block_count() {
    use petrel_repo::block_store::BlockStore as _;
    use petrel_repo::error::{LimitError, LimitKind};

    let (cbor_cid, cbor_bytes) = cbor_block(&Value::Integer(42));
    let raw_payload = b"raw-bytes-payload".to_vec();
    let raw_cid = Cid::for_raw(&raw_payload);
    let mut sha512_cid = vec![0x01, 0x71, 0x13, 0x20];
    sha512_cid.extend_from_slice(&[0xab; 32]);
    let mut v0_cid = vec![0x12, 0x20];
    let v0_payload = b"dag-pb-v0-payload".to_vec();
    v0_cid.extend_from_slice(&<sha2::Sha256 as sha2::Digest>::digest(&v0_payload));

    let tight_limits = RepositoryLimits {
        max_block_count: 1,
        max_record_count: 1,
        max_mst_node_count: 1,
        ..RepositoryLimits::standard()
    };
    let policy = RepositoryReadPolicy::data_model();

    // 1 blessed block + 1 foreign CIDv1(raw) block exceeds max_block_count=1.
    let car_raw = common::encode_raw_car(
        std::slice::from_ref(&cbor_cid),
        &[
            (cbor_cid.as_bytes().to_vec(), cbor_bytes.clone()),
            (raw_cid.as_bytes().to_vec(), raw_payload.clone()),
        ],
    );
    let err_raw = PublicRepositoryCAR::import_bytes(&car_raw, &tight_limits, &policy)
        .await
        .unwrap_err();
    assert!(matches!(
        err_raw,
        CARError::Limit(LimitError::Exceeded {
            kind: LimitKind::BlockCount,
            limit: 1,
            ..
        })
    ));

    // 1 blessed block + 1 foreign non-blessed (sha2-512) CIDv1 block exceeds max_block_count=1.
    let car_foreign_v1 = common::encode_raw_car(
        std::slice::from_ref(&cbor_cid),
        &[
            (cbor_cid.as_bytes().to_vec(), cbor_bytes.clone()),
            (sha512_cid.clone(), b"foreign-sha512".to_vec()),
        ],
    );
    let err_foreign_v1 = PublicRepositoryCAR::import_bytes(&car_foreign_v1, &tight_limits, &policy)
        .await
        .unwrap_err();
    assert!(matches!(
        err_foreign_v1,
        CARError::Limit(LimitError::Exceeded {
            kind: LimitKind::BlockCount,
            limit: 1,
            ..
        })
    ));

    // 1 blessed block + 1 CIDv0 block exceeds max_block_count=1.
    let car_v0 = common::encode_raw_car(
        std::slice::from_ref(&cbor_cid),
        &[
            (cbor_cid.as_bytes().to_vec(), cbor_bytes.clone()),
            (v0_cid, v0_payload),
        ],
    );
    let err_v0 = PublicRepositoryCAR::import_bytes(&car_v0, &tight_limits, &policy)
        .await
        .unwrap_err();
    assert!(matches!(
        err_v0,
        CARError::Limit(LimitError::Exceeded {
            kind: LimitKind::BlockCount,
            limit: 1,
            ..
        })
    ));

    // Conflicting duplicate foreign non-blessed block is rejected.
    let conflict_car = common::encode_raw_car(
        std::slice::from_ref(&cbor_cid),
        &[
            (sha512_cid.clone(), b"first".to_vec()),
            (sha512_cid, b"second".to_vec()),
        ],
    );
    let err_conflict = PublicRepositoryCAR::import_bytes(&conflict_car, &tight_limits, &policy)
        .await
        .unwrap_err();
    assert!(matches!(
        err_conflict,
        CARError::ConflictingDuplicateBlock(_)
    ));

    // Identical duplicate foreign raw blocks only consume one block-count slot.
    let two_limits = RepositoryLimits {
        max_block_count: 2,
        max_record_count: 2,
        max_mst_node_count: 2,
        ..RepositoryLimits::standard()
    };
    let dup_ok_car = common::encode_raw_car(
        std::slice::from_ref(&cbor_cid),
        &[
            (cbor_cid.as_bytes().to_vec(), cbor_bytes),
            (raw_cid.as_bytes().to_vec(), raw_payload.clone()),
            (raw_cid.as_bytes().to_vec(), raw_payload),
        ],
    );
    let (parsed_ok, _) = PublicRepositoryCAR::import_bytes(&dup_ok_car, &two_limits, &policy)
        .await
        .unwrap();
    assert_eq!(parsed_ok.block_count, 1);

    // Pre-populated store containing identical copies still counts every distinct CAR block
    // toward `block_count`, `total_block_bytes`, and `max_block_count`.
    let (b1_cid, b1_bytes) = cbor_block(&Value::String("abc".into()));
    let (b2_cid, b2_bytes) = cbor_block(&Value::String("def".into()));
    let (b3_cid, b3_bytes) = cbor_block(&Value::Integer(3));
    let three_car = PublicRepositoryCAR::write(
        std::slice::from_ref(&b1_cid),
        &[
            RepositoryBlock::new(b1_cid.clone(), b1_bytes.clone()),
            RepositoryBlock::new(b2_cid.clone(), b2_bytes.clone()),
            RepositoryBlock::new(b3_cid.clone(), b3_bytes.clone()),
        ],
    )
    .unwrap();
    let prepop_store = InMemoryBlockStore::new();
    prepop_store.put_block(&b1_cid, &b1_bytes).await.unwrap();
    prepop_store.put_block(&b2_cid, &b2_bytes).await.unwrap();
    prepop_store.put_block(&b3_cid, &b3_bytes).await.unwrap();

    let err_prepop = PublicRepositoryCAR::load(
        &three_car,
        &prepop_store,
        &two_limits,
        &RepositoryReadPolicy::strict(),
    )
    .await
    .unwrap_err();
    assert!(matches!(
        err_prepop,
        CARError::Limit(LimitError::Exceeded {
            kind: LimitKind::BlockCount,
            observed: 3,
            limit: 2,
        })
    ));

    let three_limits = RepositoryLimits {
        max_block_count: 3,
        max_record_count: 3,
        max_mst_node_count: 3,
        ..RepositoryLimits::standard()
    };
    let parsed_prepop = PublicRepositoryCAR::load(
        &three_car,
        &prepop_store,
        &three_limits,
        &RepositoryReadPolicy::strict(),
    )
    .await
    .unwrap();
    assert_eq!(parsed_prepop.block_count, 3);
    assert_eq!(
        parsed_prepop.total_block_bytes,
        b1_bytes.len() + b2_bytes.len() + b3_bytes.len()
    );
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn car_reader_and_car_repository_enforce_limits() {
    use petrel_repo::error::{LimitError, LimitKind};

    let (b1_cid, b1_bytes) = cbor_block(&Value::String("abc".into()));
    let (b2_cid, b2_bytes) = cbor_block(&Value::String("def".into()));
    let car = PublicRepositoryCAR::write(
        std::slice::from_ref(&b1_cid),
        &[
            RepositoryBlock::new(b1_cid.clone(), b1_bytes),
            RepositoryBlock::new(b2_cid, b2_bytes.clone()),
        ],
    )
    .unwrap();

    // 1. Archive byte limit
    let tiny_car_limits = RepositoryLimits {
        max_import_car_bytes: 8,
        ..RepositoryLimits::standard()
    };
    assert!(matches!(
        CARReader::parse_with_limits(&car, &tiny_car_limits),
        Err(CARReaderError::Limit(LimitError::Exceeded {
            kind: LimitKind::ImportCarBytes,
            ..
        }))
    ));

    // 2. Single-block byte limit
    let tiny_block_limits = RepositoryLimits {
        max_single_block_bytes: 1,
        ..RepositoryLimits::standard()
    };
    assert!(matches!(
        CARReader::parse_with_limits(&car, &tiny_block_limits),
        Err(CARReaderError::Limit(LimitError::Exceeded {
            kind: LimitKind::SingleBlockBytes,
            ..
        }))
    ));

    // 3. Block count limit
    let one_block_limits = RepositoryLimits {
        max_block_count: 1,
        max_record_count: 1,
        max_mst_node_count: 1,
        ..RepositoryLimits::standard()
    };
    assert!(matches!(
        CARReader::parse_with_limits(&car, &one_block_limits),
        Err(CARReaderError::Limit(LimitError::Exceeded {
            kind: LimitKind::BlockCount,
            ..
        }))
    ));

    // 4. CARRepository::parse_with_limits enforces max_record_count and max_car_roots
    let did = common::test_did();
    let signer = common::deterministic_p256_signer();
    let mut rec_map = BTreeMap::new();
    rec_map.insert(
        "$type".to_owned(),
        Value::String("app.bsky.feed.post".into()),
    );
    rec_map.insert("text".to_owned(), Value::String("ok".into()));
    let (rec_cid, rec_bytes) = cbor_block(&Value::Object(rec_map));
    let (mst, mst_blocks) = petrel_repo::mst::tree::build_mst_from_entries(
        vec![
            ("app.bsky.feed.post/r1".to_owned(), rec_cid.clone()),
            ("app.bsky.feed.post/r2".to_owned(), rec_cid.clone()),
        ],
        petrel_repo::mst::MstOptions::default(),
    )
    .unwrap();
    let mut commit = BTreeMap::new();
    commit.insert("did".to_owned(), Value::String(did.as_str().to_owned()));
    commit.insert("rev".to_owned(), Value::String("3jzfcijpj2z2a".into()));
    commit.insert("data".to_owned(), Value::Link(mst.root_cid().clone()));
    commit.insert("prev".to_owned(), Value::Null);
    commit.insert("version".to_owned(), Value::Integer(3));
    let unsigned = dagcbor::encode(&Value::Object(commit.clone()));
    let sig = signer.sign_sync(&unsigned).unwrap();
    commit.insert("sig".to_owned(), Value::Bytes(sig));
    let (commit_cid, commit_bytes) = cbor_block(&Value::Object(commit));
    let mut repo_blocks = vec![
        (commit_cid.as_bytes().to_vec(), commit_bytes),
        (rec_cid.as_bytes().to_vec(), rec_bytes),
    ];
    for b in mst_blocks {
        repo_blocks.push((b.cid.as_bytes().to_vec(), b.bytes));
    }
    let repo_car = common::encode_raw_car(std::slice::from_ref(&commit_cid), &repo_blocks);

    assert!(matches!(
        CARRepository::parse_with_limits(&repo_car, &one_block_limits),
        Err(CARReaderError::Limit(LimitError::Exceeded { .. }))
    ));
    let parsed_repo =
        CARRepository::parse_with_limits(&repo_car, &RepositoryLimits::standard()).unwrap();
    assert_eq!(parsed_repo.records.len(), 2);

    // 5. Partial CAR omitting record payloads still counts visited MST leaf entries toward
    //    `max_record_count` (Codex 4697647824).
    let mut partial_blocks = Vec::new();
    for (raw_cid, raw_bytes) in &repo_blocks {
        if raw_cid.as_slice() != rec_cid.as_bytes() {
            partial_blocks.push((raw_cid.clone(), raw_bytes.clone()));
        }
    }
    let partial_car = common::encode_raw_car(std::slice::from_ref(&commit_cid), &partial_blocks);
    let partial_one_record = RepositoryLimits {
        max_block_count: 10,
        max_mst_node_count: 10,
        max_record_count: 1,
        ..RepositoryLimits::standard()
    };
    assert!(matches!(
        CARRepository::parse_with_limits(&partial_car, &partial_one_record),
        Err(CARReaderError::Limit(LimitError::Exceeded {
            kind: LimitKind::RecordCount,
            observed: 2,
            limit: 1,
        }))
    ));
    let parsed_partial =
        CARRepository::parse_with_limits(&partial_car, &RepositoryLimits::standard()).unwrap();
    assert_eq!(parsed_partial.collections["app.bsky.feed.post"].len(), 2);
    assert!(parsed_partial.records.is_empty());

    // 6. `CARRepository::parse_with_limits` enforces `limits.max_mst_depth` (Codex 4697873614).
    let layer1_key = (0..200_usize)
        .map(|i| format!("app.bsky.feed.post/z{i}"))
        .find(|k| petrel_repo::mst::key_depth(k.as_bytes()) >= 1)
        .unwrap();
    let (deep_mst, deep_mst_blocks) = petrel_repo::mst::tree::build_mst_from_entries(
        vec![
            ("app.bsky.feed.post/a0".to_owned(), rec_cid.clone()),
            (layer1_key, rec_cid.clone()),
        ],
        petrel_repo::mst::MstOptions::default(),
    )
    .unwrap();
    let mut deep_commit = BTreeMap::new();
    deep_commit.insert("did".to_owned(), Value::String(did.as_str().to_owned()));
    deep_commit.insert("rev".to_owned(), Value::String("3jzfcijpj2z2d".into()));
    deep_commit.insert("data".to_owned(), Value::Link(deep_mst.root_cid().clone()));
    deep_commit.insert("prev".to_owned(), Value::Null);
    deep_commit.insert("version".to_owned(), Value::Integer(3));
    let deep_unsigned = dagcbor::encode(&Value::Object(deep_commit.clone()));
    deep_commit.insert(
        "sig".to_owned(),
        Value::Bytes(signer.sign_sync(&deep_unsigned).unwrap()),
    );
    let (deep_commit_cid, deep_commit_bytes) = cbor_block(&Value::Object(deep_commit));
    let mut deep_blocks = vec![(deep_commit_cid.as_bytes().to_vec(), deep_commit_bytes)];
    for b in deep_mst_blocks {
        deep_blocks.push((b.cid.as_bytes().to_vec(), b.bytes));
    }
    let deep_car = common::encode_raw_car(std::slice::from_ref(&deep_commit_cid), &deep_blocks);
    let depth_1_limits = RepositoryLimits {
        max_mst_depth: 1,
        ..RepositoryLimits::standard()
    };
    assert!(CARRepository::parse_with_limits(&deep_car, &depth_1_limits).is_ok());
    // Wrap once more so depth hits 2 > max_mst_depth=1.
    let (wrap_cid, wrap_bytes) = encode_mst_node(&MstNodeView {
        left: Some(deep_mst.root_cid().clone()),
        entries: vec![],
    })
    .unwrap();
    let mut depth2_commit = BTreeMap::new();
    depth2_commit.insert("did".to_owned(), Value::String(did.as_str().to_owned()));
    depth2_commit.insert("rev".to_owned(), Value::String("3jzfcijpj2z2e".into()));
    depth2_commit.insert("data".to_owned(), Value::Link(wrap_cid.clone()));
    depth2_commit.insert("prev".to_owned(), Value::Null);
    depth2_commit.insert("version".to_owned(), Value::Integer(3));
    let depth2_unsigned = dagcbor::encode(&Value::Object(depth2_commit.clone()));
    depth2_commit.insert(
        "sig".to_owned(),
        Value::Bytes(signer.sign_sync(&depth2_unsigned).unwrap()),
    );
    let (depth2_commit_cid, depth2_commit_bytes) = cbor_block(&Value::Object(depth2_commit));
    deep_blocks.push((wrap_cid.as_bytes().to_vec(), wrap_bytes));
    deep_blocks.push((depth2_commit_cid.as_bytes().to_vec(), depth2_commit_bytes));
    let depth2_car = common::encode_raw_car(std::slice::from_ref(&depth2_commit_cid), &deep_blocks);
    assert!(matches!(
        CARRepository::parse_with_limits(&depth2_car, &depth_1_limits),
        Err(CARReaderError::MstDepthLimitExceeded)
    ));
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn car_repository_parses_mst_node_exceeding_10k_cbor_values() {
    let did = common::test_did();
    let signer = common::deterministic_p256_signer();
    let mut rec_map = BTreeMap::new();
    rec_map.insert(
        "$type".to_owned(),
        Value::String("app.bsky.feed.post".into()),
    );
    rec_map.insert("text".to_owned(), Value::String("wide".into()));
    let (rec_cid, rec_bytes) = cbor_block(&Value::Object(rec_map));

    let mut entries = Vec::with_capacity(2_050);
    let mut idx = 0_usize;
    while entries.len() < 2_050 {
        let key = format!("app.bsky.feed.post/w{idx:05}");
        idx += 1;
        if petrel_repo::mst::key_depth(key.as_bytes()) == 0 {
            entries.push(MstNodeEntryView {
                key,
                value: rec_cid.clone(),
                tree: None,
            });
        }
    }
    let (mst_cid, mst_bytes) = encode_mst_node(&MstNodeView {
        left: None,
        entries,
    })
    .unwrap();
    // Sanity check: confirm standard 10k CBOR value limit would reject this node.
    assert!(dagcbor::decode(&mst_bytes).is_err());
    assert!(dagcbor::decode_with(&mst_bytes, dagcbor::Limits::REPOSITORY_BLOCK).is_ok());

    let mut commit = BTreeMap::new();
    commit.insert("did".to_owned(), Value::String(did.as_str().to_owned()));
    commit.insert("rev".to_owned(), Value::String("3jzfcijpj2z2g".into()));
    commit.insert("data".to_owned(), Value::Link(mst_cid.clone()));
    commit.insert("prev".to_owned(), Value::Null);
    commit.insert("version".to_owned(), Value::Integer(3));
    let unsigned = dagcbor::encode(&Value::Object(commit.clone()));
    commit.insert(
        "sig".to_owned(),
        Value::Bytes(signer.sign_sync(&unsigned).unwrap()),
    );
    let (commit_cid, commit_bytes) = cbor_block(&Value::Object(commit));

    let car = common::encode_raw_car(
        std::slice::from_ref(&commit_cid),
        &[
            (commit_cid.as_bytes().to_vec(), commit_bytes),
            (mst_cid.as_bytes().to_vec(), mst_bytes),
            (rec_cid.as_bytes().to_vec(), rec_bytes),
        ],
    );
    let parsed = CARRepository::parse_with_limits(&car, &RepositoryLimits::standard()).unwrap();
    assert_eq!(parsed.collections["app.bsky.feed.post"].len(), 2_050);
    assert_eq!(parsed.records.len(), 2_050);
}
