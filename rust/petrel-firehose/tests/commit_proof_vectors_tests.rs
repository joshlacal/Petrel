mod common;

use std::collections::BTreeMap;
use std::sync::Arc;
use std::sync::atomic::Ordering;
use std::time::Duration;

use petrel::rt::SystemTime;
use petrel_core::{Cid, Tid, Value, dagcbor};
use petrel_firehose::repo_seam::{
    RepositoryBlockSource, RepositoryCommitOperation, RepositoryLimits, RepositoryMstKeySyntax,
    RepositoryReadPolicy, verify_mst_inversion,
};
use petrel_firehose::{
    InMemoryRelayAcceptedHeadStorage, ParsedCarArchive, PublicFirehoseDiffCAR,
    PublicFirehoseDiffCarError, PublicFirehoseRepoAction, RelayCommitEvent,
    RelayCommitSemanticVerifier, RelayEvent, RelayFullRepositoryVerifier, RelayGetRepoObservation,
    RelayGetRepoPolicy, RelayGetRepoQueryMode, RelayLifecycleVerifier, RelayReconnectEvidence,
    RelayRepoAction, RelayRepoOp, RelayRepositoryDigest, RelayRepositoryHead,
    RelayRepositoryPayloadKind, RelayRepositorySnapshot, RelayRepositoryVerificationState,
    RelaySequenceVerifier, RelaySyncEvent, RelayVerifierError,
};
use serde::Deserialize;

#[cfg(not(target_arch = "wasm32"))]
use tokio::test as async_test;
#[cfg(target_arch = "wasm32")]
use wasm_bindgen_test::wasm_bindgen_test as async_test;

#[derive(Deserialize)]
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

fn to_relay_ops(ops: &[petrel_firehose::PublicFirehoseRepoOp]) -> Vec<RelayRepoOp> {
    ops.iter()
        .map(|op| RelayRepoOp {
            action: match op.action {
                PublicFirehoseRepoAction::Create => RelayRepoAction::Create,
                PublicFirehoseRepoAction::Update => RelayRepoAction::Update,
                PublicFirehoseRepoAction::Delete => RelayRepoAction::Delete,
            },
            path: op.path.clone(),
            cid: op.cid.as_deref().map(|s| s.parse().unwrap()),
            prev: op.prev.as_deref().map(|s| s.parse().unwrap()),
        })
        .collect()
}

fn make_commit_event(seq: i64, did: &str, built: &common::BuiltCommit) -> RelayCommitEvent {
    RelayCommitEvent {
        seq,
        repo: did.to_owned(),
        commit_cid: built.commit_cid.clone(),
        rev: built.rev.clone(),
        since: built.since.clone(),
        blocks: built.diff_car.clone(),
        ops: to_relay_ops(&built.ops),
        prev_data_cid: built.prev_data_cid.clone(),
        time: "2026-01-01T00:00:00.000Z".to_owned(),
    }
}

#[allow(clippy::too_many_lines)]
#[async_test]
async fn official_commit_proof_fixtures_verify_and_reject_tampering() {
    let raw = include_str!("vectors/commit-proof-fixtures.json");
    let fixtures: Vec<CommitProofFixture> = serde_json::from_str(raw).unwrap();
    assert!(!fixtures.is_empty());

    for fixture in &fixtures {
        let leaf_cid: Cid = fixture.leaf_value.parse().expect("valid leaf CID");
        let expected_before: Cid = fixture
            .root_before_commit
            .parse()
            .expect("valid before CID");
        let expected_after: Cid = fixture.root_after_commit.parse().expect("valid after CID");

        let mut before_entries = BTreeMap::new();
        for k in &fixture.keys {
            before_entries.insert(k.clone(), leaf_cid.clone());
        }
        let (computed_before, _) = common::build_mst_blocks(&before_entries);
        assert_eq!(
            computed_before, expected_before,
            "before root mismatch on fixture: {}",
            fixture.comment
        );

        let mut after_entries = before_entries;
        for add in &fixture.adds {
            after_entries.insert(add.clone(), leaf_cid.clone());
        }
        for del in &fixture.dels {
            after_entries.remove(del);
        }
        let (computed_after, after_blocks) = common::build_mst_blocks(&after_entries);
        assert_eq!(
            computed_after, expected_after,
            "after root mismatch on fixture: {}",
            fixture.comment
        );

        let mut proof_blocks = BTreeMap::new();
        for cid_str in &fixture.blocks_in_proof {
            let cid: Cid = cid_str.parse().unwrap();
            let bytes = after_blocks
                .get(&cid)
                .unwrap_or_else(|| panic!("missing proof block {cid} in {}", fixture.comment))
                .clone();
            proof_blocks.insert(cid, bytes);
        }

        let mut ops = Vec::new();
        for add in &fixture.adds {
            ops.push(RepositoryCommitOperation::Create {
                path: add.clone(),
                cid: leaf_cid.clone(),
            });
        }
        for del in &fixture.dels {
            ops.push(RepositoryCommitOperation::Delete {
                path: del.clone(),
                previous: leaf_cid.clone(),
            });
        }

        let block_source = common::MapBlockSource {
            blocks: proof_blocks.clone(),
        };
        let limits = RepositoryLimits::default();

        verify_mst_inversion(
            &expected_after,
            &ops,
            &expected_before,
            &block_source,
            &limits,
            RepositoryMstKeySyntax::MstKey,
        )
        .await
        .unwrap_or_else(|e| {
            panic!(
                "fixture {} failed verify_mst_inversion: {e}",
                fixture.comment
            )
        });

        if let Some(root_cid_str) = fixture.blocks_in_proof.last() {
            let mut incomplete = proof_blocks.clone();
            incomplete.remove(&root_cid_str.parse().unwrap());
            let incomplete_src = common::MapBlockSource { blocks: incomplete };
            assert!(
                verify_mst_inversion(
                    &expected_after,
                    &ops,
                    &expected_before,
                    &incomplete_src,
                    &limits,
                    RepositoryMstKeySyntax::MstKey,
                )
                .await
                .is_err(),
                "incomplete proof unexpectedly accepted on {}",
                fixture.comment
            );
        }

        let wrong_before = common::dag_cbor_cid(b"\xa0");
        assert!(
            verify_mst_inversion(
                &expected_after,
                &ops,
                &wrong_before,
                &block_source,
                &limits,
                RepositoryMstKeySyntax::MstKey,
            )
            .await
            .is_err(),
            "wrong before root unexpectedly accepted on {}",
            fixture.comment
        );
    }
}

#[async_test]
async fn commit_sync_full_repo_and_accepted_head_verification_succeed_for_p256_and_k256() {
    for (did, key) in [
        (
            "did:plc:p256testuser",
            common::TestSigningKey::p256_deterministic(7),
        ),
        (
            "did:plc:k256testuser",
            common::TestSigningKey::k256_deterministic(9),
        ),
    ] {
        let pub_key = key.public_key();
        let resolver = common::TestKeyResolver::new();
        resolver.insert(did, pub_key.clone()).await;

        let mut repo = common::TestRepoState::new(did, key);
        // c0 is initial empty activation commit, then c1/c2/c3 build on top of it
        let c0 = repo.commit(&[]);
        let c1 = repo.commit(&[("app.bsky.feed.post/3k7post000001", Some(("hello", vec![])))]);
        let c2 = repo.commit(&[
            ("app.bsky.feed.post/3k7post000001", Some(("edited", vec![]))),
            ("app.bsky.feed.post/3k7post000002", Some(("second", vec![]))),
        ]);
        let c3 = repo.commit(&[("app.bsky.feed.post/3k7post000002", None)]);

        let limits = RepositoryLimits::STANDARD;
        let now = SystemTime::now();
        let skew = Duration::from_secs(600);

        for (seq, built) in [(2_i64, &c1), (3, &c2), (4, &c3)] {
            let event = make_commit_event(seq, did, built);
            let verified_records = event.records().unwrap();
            assert_eq!(verified_records.len(), built.ops.len());

            let verified = event
                .verify(&resolver, &limits, RepositoryReadPolicy::Strict, now, skew)
                .await
                .unwrap();
            assert_eq!(verified.commit.descriptor.did, did);
            assert_eq!(verified.commit.commit_cid, built.commit_cid);
            assert_eq!(verified.commit.descriptor.data_cid, built.data_cid);
        }

        // Verify #sync event on c0 and c3
        let sync0 = RelaySyncEvent {
            seq: 1,
            did: did.to_owned(),
            blocks: PublicFirehoseDiffCAR::commit_only(
                &c0.commit_cid,
                c0.all_blocks.get(&c0.commit_cid).unwrap(),
            )
            .unwrap(),
            rev: c0.rev.clone(),
            time: "2026-01-01T00:00:00.000Z".to_owned(),
        };
        let verified_sync = sync0.verify(&resolver, &limits, now, skew).await.unwrap();
        assert_eq!(verified_sync.commit_cid, c0.commit_cid);

        // Stateful chain verification starting from activation_sync -> applying_commit(c1..c3)
        let heads = Arc::new(InMemoryRelayAcceptedHeadStorage::new());
        let state =
            RelayRepositoryVerificationState::activation_sync(&sync0, &pub_key, heads.as_ref())
                .await
                .unwrap();
        let state = state
            .applying_commit(&make_commit_event(2, did, &c1), &pub_key, heads.as_ref())
            .await
            .unwrap();
        let state = state
            .applying_commit(&make_commit_event(3, did, &c2), &pub_key, heads.as_ref())
            .await
            .unwrap();
        let state = state
            .applying_commit(&make_commit_event(4, did, &c3), &pub_key, heads.as_ref())
            .await
            .unwrap();
        assert_eq!(state.snapshot.commit_cid, c3.commit_cid);
        assert_eq!(state.snapshot.data_cid, c3.data_cid);
        assert_eq!(state.snapshot.records.len(), 1);

        // Verify full repository snapshot on a separate head storage
        let full_heads = InMemoryRelayAcceptedHeadStorage::new();
        let expected_head = RelayRepositoryHead {
            did: did.to_owned(),
            revision: c3.rev.clone(),
            commit_cid: c3.commit_cid.clone(),
            data_cid: c3.data_cid.clone(),
        };
        let full = RelayFullRepositoryVerifier::verify(
            &c3.full_car,
            &expected_head,
            &pub_key,
            &full_heads,
            limits.maximum_car_bytes,
        )
        .await
        .unwrap();
        assert_eq!(full.head(), expected_head);
        assert_eq!(full.records.len(), 1);
    }
}

#[async_test]
async fn accepted_head_rollback_and_failed_save_abort_acceptance() {
    let did = "did:plc:rollbacktest";
    let key = common::TestSigningKey::p256_deterministic(11);
    let pub_key = key.public_key();

    let mut repo = common::TestRepoState::new(did, key);
    let c0 = repo.commit(&[]);
    let c1 = repo.commit(&[("app.bsky.feed.post/3k7post000010", Some(("first", vec![])))]);
    let c2 = repo.commit(&[("app.bsky.feed.post/3k7post000011", Some(("second", vec![])))]);

    let sync0 = RelaySyncEvent {
        seq: 1,
        did: did.to_owned(),
        blocks: PublicFirehoseDiffCAR::commit_only(
            &c0.commit_cid,
            c0.all_blocks.get(&c0.commit_cid).unwrap(),
        )
        .unwrap(),
        rev: c0.rev.clone(),
        time: "2026-01-01T00:00:00.000Z".to_owned(),
    };

    let storage = common::FailingHeadStorage::default();
    let s0 = RelayRepositoryVerificationState::activation_sync(&sync0, &pub_key, &storage)
        .await
        .unwrap();
    let s1 = s0
        .applying_commit(&make_commit_event(2, did, &c1), &pub_key, &storage)
        .await
        .unwrap();

    // Failing storage on next commit must surface StorageFailure without overwriting head.
    storage.fail_save.store(true, Ordering::SeqCst);
    let err = s1
        .applying_commit(&make_commit_event(3, did, &c2), &pub_key, &storage)
        .await
        .unwrap_err();
    assert_eq!(err, RelayVerifierError::StorageFailure);

    // In-memory accepted head storage enforces strict monotonic TID ordering.
    let mem = InMemoryRelayAcceptedHeadStorage::new();
    let head2 = RelayRepositoryHead {
        did: did.to_owned(),
        revision: c2.rev.clone(),
        commit_cid: c2.commit_cid.clone(),
        data_cid: c2.data_cid.clone(),
    };
    RelayFullRepositoryVerifier::verify(
        &c2.full_car,
        &head2,
        &pub_key,
        &mem,
        RepositoryLimits::STANDARD.maximum_car_bytes,
    )
    .await
    .unwrap();
    assert_eq!(
        s0.applying_commit(&make_commit_event(2, did, &c1), &pub_key, &mem)
            .await
            .unwrap_err(),
        RelayVerifierError::RevisionRollback
    );
}

#[allow(clippy::too_many_lines)]
#[test]
fn diff_car_and_semantic_verifiers_cover_contract_edges() {
    let root_c = common::dag_cbor_cid(b"root");
    assert!(matches!(
        PublicFirehoseDiffCAR::encode(&Cid::for_raw(b"raw"), std::iter::empty()),
        Err(PublicFirehoseDiffCarError::InvalidBlock(_))
    ));
    let single = PublicFirehoseDiffCAR::commit_only(&root_c, b"root").unwrap();
    let parsed = ParsedCarArchive::parse(&single, usize::MAX, true).unwrap();
    assert_eq!(parsed.root_cid(), &root_c);

    let seq_events = vec![
        RelayEvent::Identity(petrel_firehose::RelayIdentityEvent {
            seq: 1,
            did: "did:plc:seq".to_owned(),
            time: "2026-01-01T00:00:00.000Z".to_owned(),
            handle: None,
        }),
        RelayEvent::Identity(petrel_firehose::RelayIdentityEvent {
            seq: 2,
            did: "did:plc:seq".to_owned(),
            time: "2026-01-01T00:00:01.000Z".to_owned(),
            handle: None,
        }),
        RelayEvent::Identity(petrel_firehose::RelayIdentityEvent {
            seq: 2,
            did: "did:plc:seq".to_owned(),
            time: "2026-01-01T00:00:02.000Z".to_owned(),
            handle: None,
        }),
    ];
    assert_eq!(
        RelaySequenceVerifier::verify(&seq_events, &[], None, 0).unwrap_err(),
        RelayVerifierError::DuplicateSequence
    );

    let gap_events = vec![seq_events[0].clone(), {
        let mut e = seq_events[1].clone();
        if let RelayEvent::Identity(ref mut i) = e {
            i.seq = 3;
        }
        e
    }];
    assert_eq!(
        RelaySequenceVerifier::verify(&gap_events, &[], None, 0).unwrap_err(),
        RelayVerifierError::SequenceGap
    );

    let ok_events = vec![seq_events[0].clone(), seq_events[1].clone(), {
        let mut e = seq_events[1].clone();
        if let RelayEvent::Identity(ref mut i) = e {
            i.seq = 3;
        }
        e
    }];
    assert_eq!(
        RelaySequenceVerifier::verify(
            &ok_events,
            &[RelayReconnectEvidence {
                upstream_cursor: 2,
                first_delivered_relay_sequence: 99,
            }],
            None,
            0,
        )
        .unwrap_err(),
        RelayVerifierError::ReconnectCursorOutOfBounds
    );
    assert!(
        RelaySequenceVerifier::verify(
            &ok_events,
            &[RelayReconnectEvidence {
                upstream_cursor: 2,
                first_delivered_relay_sequence: 2,
            }],
            None,
            0,
        )
        .is_ok()
    );

    // GetRepoPolicy: since-observed requires non-diff full snapshot + exact final state
    assert_eq!(
        RelayGetRepoPolicy::verify(&RelayGetRepoObservation {
            mode: RelayGetRepoQueryMode::SinceObserved,
            full_snapshot_accepted: false,
            exact_final_state_proven: true,
        })
        .unwrap_err(),
        RelayVerifierError::SinceObservedNotProven
    );
    assert!(
        RelayGetRepoPolicy::verify(&RelayGetRepoObservation {
            mode: RelayGetRepoQueryMode::SinceObserved,
            full_snapshot_accepted: true,
            exact_final_state_proven: true,
        })
        .is_ok()
    );
    let _ = RelayRepositoryPayloadKind::FullSnapshot;

    // Lifecycle & Semantic checks
    let did = "did:plc:semantic";
    let mut repo = common::TestRepoState::new(did, common::TestSigningKey::p256_deterministic(3));
    let c0 = repo.commit(&[]);
    let c1 = repo.commit(&[("app.bsky.feed.post/3k7post000001", Some(("hi1", vec![])))]);
    let snap1 = RelayRepositorySnapshot {
        did: did.to_owned(),
        revision: c1.rev.clone(),
        commit_cid: c1.commit_cid.clone(),
        data_cid: c1.data_cid.clone(),
        records: BTreeMap::from([(
            "app.bsky.feed.post/3k7post000001".to_owned(),
            c1.ops[0].cid.as_deref().unwrap().parse().unwrap(),
        )]),
        mst_digest: RelayRepositoryDigest::projection(&BTreeMap::new()),
    };
    let c2 = repo.commit(&[("app.bsky.feed.post/3k7post000002", Some(("hi2", vec![])))]);
    let snap2 = RelayRepositorySnapshot {
        did: did.to_owned(),
        revision: c2.rev.clone(),
        commit_cid: c2.commit_cid.clone(),
        data_cid: c2.data_cid.clone(),
        records: BTreeMap::from([
            (
                "app.bsky.feed.post/3k7post000001".to_owned(),
                snap1.records["app.bsky.feed.post/3k7post000001"].clone(),
            ),
            (
                "app.bsky.feed.post/3k7post000002".to_owned(),
                c2.ops[0].cid.as_deref().unwrap().parse().unwrap(),
            ),
        ]),
        mst_digest: snap1.mst_digest.clone(),
    };

    let c2_ev = make_commit_event(2, did, &c2);
    assert!(RelayCommitSemanticVerifier::verify(&c2_ev, &snap1, &snap2).is_ok());

    let id_ev = RelayEvent::Identity(petrel_firehose::RelayIdentityEvent {
        seq: 1,
        did: did.to_owned(),
        time: "2026-01-01T00:00:00.000Z".to_owned(),
        handle: Some("a.test".to_owned()),
    });
    let acct_ev = RelayEvent::Account(petrel_firehose::RelayAccountEvent {
        seq: 2,
        did: did.to_owned(),
        time: "2026-01-01T00:00:01.000Z".to_owned(),
        active: true,
        status: None,
    });
    let sync_ev = RelayEvent::Sync(RelaySyncEvent {
        seq: 3,
        did: did.to_owned(),
        blocks: c0.full_car,
        rev: c0.rev,
        time: "2026-01-01T00:00:02.000Z".to_owned(),
    });
    assert!(RelayLifecycleVerifier::verify(&[id_ev, acct_ev.clone(), sync_ev], Some(did)).is_ok());
    assert_eq!(
        RelayLifecycleVerifier::verify(&[acct_ev], Some(did)).unwrap_err(),
        RelayVerifierError::LifecycleOrderMismatch
    );
    let _ = (
        Tid::from_parts(1, 0),
        Value::Null,
        dagcbor::encode(&Value::Null),
        common::MapBlockSource::default().block(&c1.commit_cid),
    );
}

#[test]
fn car_parser_rejects_u64_max_block_length_varint_without_overflow_panic() {
    let did = "did:plc:caroverflow";
    let mut repo = common::TestRepoState::new(did, common::TestSigningKey::p256_deterministic(4));
    let commit = repo.commit(&[]);
    let mut car = commit.full_car;
    // Append canonical LEB128 varint for u64::MAX (9x 0xFF, 0x01) as a synthetic next block length.
    car.extend_from_slice(&[0xff; 9]);
    car.push(0x01);

    let err = ParsedCarArchive::parse(&car, 1024 * 1024, false)
        .expect_err("u64::MAX CAR frame length must return InvalidRepositoryCar");
    assert_eq!(err, RelayVerifierError::InvalidRepositoryCar);
}

#[async_test]
async fn commit_proof_rejects_long_chain_of_empty_mst_nodes_without_stack_overflow() {
    use petrel_firehose::repo_seam::RepositoryCommitDiffError;

    let mut blocks: BTreeMap<Cid, Vec<u8>> = BTreeMap::new();
    let empty = BTreeMap::from([
        ("e".to_owned(), Value::Array(Vec::new())),
        ("l".to_owned(), Value::Null),
    ]);
    let empty_bytes = dagcbor::encode(&Value::Object(empty));
    let mut cur_cid = Cid::for_dag_cbor(&empty_bytes);
    blocks.insert(cur_cid.clone(), empty_bytes);

    // Chain 200 valid DAG-CBOR empty MST nodes through `l` (total ~8 KiB, well under CAR limits).
    for _ in 0..200 {
        let node = BTreeMap::from([
            ("e".to_owned(), Value::Array(Vec::new())),
            ("l".to_owned(), Value::Link(cur_cid.clone())),
        ]);
        let bytes = dagcbor::encode(&Value::Object(node));
        cur_cid = Cid::for_dag_cbor(&bytes);
        blocks.insert(cur_cid.clone(), bytes);
    }

    let op = RepositoryCommitOperation::Create {
        path: "app.bsky.feed.post/3k7deep000001".to_owned(),
        cid: cur_cid.clone(),
    };
    let err = verify_mst_inversion(
        &cur_cid,
        &[op],
        &cur_cid,
        &blocks,
        &RepositoryLimits::STANDARD,
        RepositoryMstKeySyntax::RepositoryPath,
    )
    .await
    .expect_err("deep empty MST chain must return InvalidTree instead of exhausting stack");
    assert_eq!(err, RepositoryCommitDiffError::InvalidTree);
}

#[async_test]
async fn verified_commit_with_over_10000_cbor_values_decodes_via_records() {
    let did = "did:plc:largecborrecord";
    let key = common::TestSigningKey::p256_deterministic(11);
    let resolver = common::TestKeyResolver::new();
    resolver.insert(did, key.public_key()).await;

    let mut repo = common::TestRepoState::new(did, key);
    let _c0 = repo.commit(&[]);

    // >10,000 CBOR values while well under 1 MiB (exceeds Limits::STANDARD, allowed by Limits::REPOSITORY_BLOCK).
    let items: Vec<Value> = (0..10_500_i64).map(Value::Integer).collect();
    let record_bytes = dagcbor::encode(&Value::Object(BTreeMap::from([
        (
            "$type".to_owned(),
            Value::String("app.bsky.feed.post".to_owned()),
        ),
        ("items".to_owned(), Value::Array(items)),
    ])));
    assert!(record_bytes.len() < 1_000_000);
    assert!(dagcbor::decode(&record_bytes).is_err());

    let c1 = repo.commit(&[("app.bsky.feed.post/3k7large00001", Some(("", record_bytes)))]);
    let event = make_commit_event(2, did, &c1);

    let verified = event
        .verify(
            &resolver,
            &RepositoryLimits::STANDARD,
            RepositoryReadPolicy::Strict,
            SystemTime::now(),
            Duration::from_secs(600),
        )
        .await
        .expect("verified commit under repository block limits must succeed");
    assert_eq!(verified.commit.commit_cid, c1.commit_cid);

    let decoded_ops = event
        .records()
        .expect("records() must decode valid repository record with >10,000 CBOR values");
    assert_eq!(decoded_ops.len(), 1);
    let record = decoded_ops[0]
        .record
        .as_ref()
        .and_then(Value::as_object)
        .expect("decoded record object");
    let items_len = match record.get("items") {
        Some(Value::Array(items)) => Some(items.len()),
        _ => None,
    };
    assert_eq!(items_len, Some(10_500));
}

#[async_test]
#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
async fn state_machine_verifiers_enforce_expected_did_and_throttled_resolver_caps_forced_refresh() {
    use std::sync::atomic::AtomicUsize;

    use petrel_firehose::ThrottledSigningKeyResolver;
    use petrel_firehose::repo_seam::{
        RepoCommitVerifier, RepositoryCommitError, RepositorySigningKeyResolver,
        verify_commit_with_resolver,
    };

    #[derive(Debug)]
    struct CountingResolver {
        key: petrel_firehose::SigningPublicKey,
        forced_calls: AtomicUsize,
    }
    impl RepositorySigningKeyResolver for CountingResolver {
        fn resolve_signing_key<'a>(
            &'a self,
            _did: &'a str,
            force_refresh: bool,
        ) -> petrel::rt::BoxFuture<'a, Result<Box<dyn RepoCommitVerifier>, RepositoryCommitError>>
        {
            if force_refresh {
                self.forced_calls.fetch_add(1, Ordering::SeqCst);
            }
            let k = self.key.clone();
            Box::pin(async move { Ok(Box::new(k) as Box<dyn RepoCommitVerifier>) })
        }
    }

    let did = "did:plc:expecteddid01";
    let key = common::TestSigningKey::p256_deterministic(15);
    let pub_key = key.public_key();
    let mut repo = common::TestRepoState::new(did, key);
    let c0 = repo.commit(&[]);
    let c1 = repo.commit(&[("app.bsky.feed.post/3k7did000001", Some(("hi", vec![])))]);

    let storage = InMemoryRelayAcceptedHeadStorage::new();
    let wrong_did_head = RelayRepositoryHead {
        did: "did:plc:otherdid99999".to_owned(),
        revision: c0.rev.clone(),
        commit_cid: c0.commit_cid.clone(),
        data_cid: c0.data_cid.clone(),
    };
    let full_err = RelayFullRepositoryVerifier::verify(
        &c0.full_car,
        &wrong_did_head,
        &pub_key,
        &storage,
        RepositoryLimits::STANDARD.maximum_car_bytes,
    )
    .await
    .unwrap_err();
    assert_eq!(full_err, RelayVerifierError::RepositoryDidMismatch);

    let sync_wrong_did = RelaySyncEvent {
        seq: 1,
        did: "did:plc:otherdid99999".to_owned(),
        blocks: PublicFirehoseDiffCAR::commit_only(
            &c0.commit_cid,
            c0.all_blocks.get(&c0.commit_cid).unwrap(),
        )
        .unwrap(),
        rev: c0.rev.clone(),
        time: "2026-01-01T00:00:00.000Z".to_owned(),
    };
    let sync_err =
        RelayRepositoryVerificationState::activation_sync(&sync_wrong_did, &pub_key, &storage)
            .await
            .unwrap_err();
    assert_eq!(sync_err, RelayVerifierError::RepositoryDidMismatch);

    let sync_ok = RelaySyncEvent {
        did: did.to_owned(),
        ..sync_wrong_did
    };
    let state = RelayRepositoryVerificationState::activation_sync(&sync_ok, &pub_key, &storage)
        .await
        .unwrap();
    let commit_wrong_repo = make_commit_event(2, "did:plc:otherdid99999", &c1);
    let apply_err = state
        .applying_commit(&commit_wrong_repo, &pub_key, &storage)
        .await
        .unwrap_err();
    assert_eq!(apply_err, RelayVerifierError::RepositoryDidMismatch);

    // ThrottledSigningKeyResolver allows one forced refresh per DID within cooldown, then downgrades.
    let wrong_key = common::TestSigningKey::p256_deterministic(16).public_key();
    let inner = Arc::new(CountingResolver {
        key: wrong_key,
        forced_calls: AtomicUsize::new(0),
    });
    let throttled =
        ThrottledSigningKeyResolver::with_cooldown(inner.clone(), Duration::from_secs(60));
    let commit_bytes = c1.all_blocks.get(&c1.commit_cid).unwrap();
    for _ in 0..3 {
        let err = verify_commit_with_resolver(commit_bytes, &c1.commit_cid, &throttled, Some(did))
            .await
            .unwrap_err();
        assert_eq!(err, RepositoryCommitError::InvalidSignature);
    }
    assert_eq!(inner.forced_calls.load(Ordering::SeqCst), 1);
}

#[async_test]
#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
async fn petrel_repo_and_petrel_crypto_adapters_verify_real_commit_end_to_end() {
    use petrel_core::Did;
    use petrel_crypto::ATProtoSigner as _;
    use petrel_firehose::{
        RepoBlockSourceAdapter, RepoSigningKeyResolverAdapter, RepositoryBlockSource,
        RepositorySigningKeyResolver,
    };
    use petrel_repo::crypto::{
        CommitVerifier, P256Keypair, RepositorySigningKeyResolver as RepoTraitResolver,
    };

    #[derive(Debug)]
    struct StaticRepoResolver(Arc<dyn CommitVerifier>);
    impl RepoTraitResolver for StaticRepoResolver {
        fn resolve_signing_key<'a>(
            &'a self,
            _did: &'a Did,
            _force_refresh: bool,
        ) -> petrel::rt::BoxFuture<'a, Result<Arc<dyn CommitVerifier>, petrel_repo::CommitError>>
        {
            let v = Arc::clone(&self.0);
            Box::pin(async move { Ok(v) })
        }
    }

    let keypair = P256Keypair::generate().expect("p256 keypair");
    let did = "did:plc:repoadapter01";
    let parsed_did = Did::parse(did).unwrap();

    let store = Arc::new(petrel_repo::InMemoryBlockStore::new());
    let repo = petrel_repo::Repository::create_in_store(
        parsed_did.clone(),
        &keypair,
        Arc::clone(&store),
        petrel_repo::RepositoryLimits::standard(),
        petrel_repo::RepositoryReadPolicy::strict(),
    )
    .await
    .unwrap();

    let block_adapter = RepoBlockSourceAdapter(store.as_ref().clone());
    let root_bytes = block_adapter
        .block(&repo.commit().data_cid)
        .await
        .unwrap()
        .expect("empty mst root block");
    assert_ne!(root_bytes.len(), 0);

    let descriptor = petrel_repo::CommitDescriptor {
        did: parsed_did,
        rev: repo.revision().clone(),
        data_cid: repo.commit().data_cid.clone(),
        prev_cid: None,
    };
    let prepared = petrel_repo::CommitCodec::prepare(
        &descriptor,
        &keypair,
        &petrel_repo::RepositoryLimits::standard(),
    )
    .await
    .unwrap();

    let resolver_adapter =
        RepoSigningKeyResolverAdapter(StaticRepoResolver(Arc::new(keypair.public_key().clone())));
    let verified_via_adapter = petrel_firehose::repo_seam::verify_commit_with_resolver(
        &prepared.signed_commit_bytes,
        &prepared.cid,
        &resolver_adapter as &dyn RepositorySigningKeyResolver,
        Some(did),
    )
    .await
    .unwrap();
    assert_eq!(verified_via_adapter.commit_cid, prepared.cid);

    let crypto_kp = petrel_crypto::P256Keypair::generate().unwrap();
    let crypto_pub = crypto_kp.public_key().clone();
    let sig = crypto_kp.sign(b"test-commit-msg").await.unwrap();
    let verifier_from_crypto: Box<dyn petrel_firehose::RepoCommitVerifier> = Box::new(crypto_pub);
    verifier_from_crypto
        .verify(did, b"test-commit-msg", &sig)
        .await
        .unwrap();
}

#[async_test]
async fn verify_mst_inversion_handles_ancestor_create_and_non_spine_grandchild_ops() {
    fn key_with_layer(prefix: char, target_layer: usize) -> String {
        for i in 0_u32..5_000 {
            let candidate = format!("app.bsky.feed.post/{prefix}{i:012}");
            if common::mst_layer(candidate.as_bytes()) == target_layer {
                return candidate;
            }
        }
        panic!("no deterministic key found for prefix {prefix} layer {target_layer}");
    }

    let k0_left = key_with_layer('0', 0);
    let k1_left = key_with_layer('1', 1);
    let k0_left_mid = key_with_layer('2', 0);
    let k2_root = key_with_layer('3', 2);
    let k0_right_mid = key_with_layer('4', 0);
    let k1_right = key_with_layer('5', 1);
    let k0_right = key_with_layer('6', 0);

    let key = common::TestSigningKey::p256_deterministic(11);
    let did = "did:plc:multilayermst01";
    let resolver = common::TestKeyResolver::new();
    resolver.insert(did, key.public_key()).await;
    let mut repo = common::TestRepoState::new(did, key);

    let _base = repo.commit(&[
        (k0_left.as_str(), Some(("left-leaf-v1", vec![]))),
        (k1_left.as_str(), Some(("left-layer1", vec![]))),
        (k0_left_mid.as_str(), Some(("left-mid-leaf", vec![]))),
        (k0_right_mid.as_str(), Some(("right-mid-leaf", vec![]))),
        (k1_right.as_str(), Some(("right-layer1", vec![]))),
        (k0_right.as_str(), Some(("right-leaf-v1", vec![]))),
    ]);

    // Layer-2 ancestor create + non-spine layer-0 grandchild updates on both sides.
    let c_update = repo.commit(&[
        (k2_root.as_str(), Some(("root-layer2-v1", vec![]))),
        (k0_left.as_str(), Some(("left-leaf-v2", vec![]))),
        (k0_right.as_str(), Some(("right-leaf-v2", vec![]))),
    ]);
    let ev_update = make_commit_event(2, did, &c_update);
    let verified_update = ev_update
        .verify(
            &resolver,
            &RepositoryLimits::STANDARD,
            RepositoryReadPolicy::Strict,
            SystemTime::now(),
            Duration::from_secs(600),
        )
        .await
        .expect("ancestor create + non-spine grandchild updates must verify");
    assert_eq!(verified_update.commit.commit_cid, c_update.commit_cid);
    assert_eq!(verified_update.operations.len(), 3);
    assert_eq!(
        Some(verified_update.previous_data_cid),
        c_update.prev_data_cid
    );

    // Non-spine grandchild deletes combined with layer-2 root delete.
    let c_delete = repo.commit(&[
        (k2_root.as_str(), None),
        (k0_left.as_str(), None),
        (k0_right.as_str(), None),
    ]);
    let ev_delete = make_commit_event(3, did, &c_delete);
    let verified_delete = ev_delete
        .verify(
            &resolver,
            &RepositoryLimits::STANDARD,
            RepositoryReadPolicy::Strict,
            SystemTime::now(),
            Duration::from_secs(600),
        )
        .await
        .expect("ancestor delete + non-spine grandchild deletes must verify");
    assert_eq!(verified_delete.commit.commit_cid, c_delete.commit_cid);
    assert_eq!(verified_delete.operations.len(), 3);
    assert_eq!(
        Some(verified_delete.previous_data_cid),
        c_delete.prev_data_cid
    );
}

#[test]
fn record_results_isolates_per_operation_failures() {
    use petrel_firehose::RelayRecordOperationError;

    let good_bytes = dagcbor::encode(&Value::Object(BTreeMap::from([
        (
            "$type".to_owned(),
            Value::String("app.bsky.feed.post".to_owned()),
        ),
        ("text".to_owned(), Value::String("hi".to_owned())),
    ])));
    let good_cid = Cid::for_dag_cbor(&good_bytes);
    // Valid DAG-CBOR block but not a record (no `$type`).
    let bad_bytes = dagcbor::encode(&Value::Integer(5));
    let bad_cid = Cid::for_dag_cbor(&bad_bytes);
    let commit_bytes = dagcbor::encode(&Value::Object(BTreeMap::new()));
    let commit_cid = Cid::for_dag_cbor(&commit_bytes);

    let blocks = common::encode_car(
        std::slice::from_ref(&commit_cid),
        &[
            (commit_cid.clone(), commit_bytes),
            (good_cid.clone(), good_bytes),
            (bad_cid.clone(), bad_bytes),
        ],
    );
    let op = |path: &str, cid: &Cid| RelayRepoOp {
        action: RelayRepoAction::Create,
        path: path.to_owned(),
        cid: Some(cid.clone()),
        prev: None,
    };
    let event = RelayCommitEvent {
        seq: 1,
        repo: "did:plc:abcdefghijklmnopqrstuvwx".to_owned(),
        commit_cid,
        rev: "3jzfcijpj2z2a".to_owned(),
        since: None,
        blocks,
        ops: vec![
            op("app.bsky.feed.post/3k7good00001", &good_cid),
            op("app.bsky.feed.post/3k7bad000001", &bad_cid),
            op("no-slash-path", &good_cid),
            op("app.bsky.feed.post/3k7good00002", &good_cid),
        ],
        prev_data_cid: None,
        time: "2026-01-01T00:00:00.000Z".to_owned(),
    };

    let results = event.record_results().unwrap();
    assert_eq!(results.len(), 4);
    assert_eq!(
        results[0].as_ref().unwrap().record_key,
        "3k7good00001".to_owned()
    );
    assert_eq!(
        results[1],
        Err(RelayRecordOperationError {
            index: 1,
            action: RelayRepoAction::Create,
            path: "app.bsky.feed.post/3k7bad000001".to_owned(),
            error: RelayVerifierError::InvalidRepositoryCar,
        })
    );
    assert_eq!(
        results[2].as_ref().unwrap_err().error,
        RelayVerifierError::InvalidRepositoryOperation
    );
    assert!(results[3].as_ref().unwrap().record.is_some());

    // The all-or-nothing API keeps its behaviour: first failing op fails the commit.
    assert_eq!(
        event.records(),
        Err(RelayVerifierError::InvalidRepositoryCar)
    );
}
