#![cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]

use std::collections::{BTreeMap, BTreeSet};

use petrel_crypto::{
    ATProtoKeyCurve, ATProtoKeypair, ATProtoSigner, K256Keypair, P256Keypair, PublicKey,
};
use petrel_plc::{
    PlcAtProfile, PlcAuditEntry, PlcAuditLogVerifier, PlcError, PlcExportCursor, PlcExportEntry,
    PlcOperation, PlcOperationCodec, UnsignedPlcOperation, UnsignedPlcTombstoneOperation,
    plc_timestamp_milliseconds,
};

mod common;
use common::{AUDIT_LOGS, EXPORT_LEGACY, EXPORT_SEQUENCED, audit_json_for};

async fn make_genesis(
    handle: &str,
    signing: &dyn ATProtoKeypair,
    rotation_keys: Vec<String>,
    signer: &dyn ATProtoSigner,
) -> (String, PlcOperation) {
    let unsigned = PlcAtProfile::genesis_operation(
        handle,
        &signing.did_key(),
        &rotation_keys,
        "https://pds.example.com",
    )
    .unwrap();
    let op = PlcOperationCodec::sign(&UnsignedPlcOperation::Regular(unsigned), signer)
        .await
        .unwrap();
    let did = PlcOperationCodec::genesis_did(&op).unwrap();
    (did, op)
}

async fn make_update(
    prev: &PlcOperation,
    handle: &str,
    signer: &dyn ATProtoSigner,
) -> PlcOperation {
    let unsigned = PlcOperationCodec::update_handle(prev, handle).unwrap();
    PlcOperationCodec::sign(&UnsignedPlcOperation::Regular(unsigned), signer)
        .await
        .unwrap()
}

fn entry(did: &str, op: &PlcOperation, ts: &str, claimed_nullified: bool) -> PlcAuditEntry {
    PlcAuditEntry {
        did: did.to_owned(),
        operation: op.clone(),
        cid: op.cid_string().unwrap(),
        nullified: claimed_nullified,
        created_at: ts.to_owned(),
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn linear_log_alternating_k256_and_p256_verifies() {
    let signing = P256Keypair::generate().unwrap();
    let rot_k = K256Keypair::generate().unwrap();
    let rot_p = P256Keypair::generate().unwrap();

    let (did, genesis_op) = make_genesis(
        "alice.example.com",
        &signing,
        vec![rot_k.did_key(), rot_p.did_key()],
        &rot_k,
    )
    .await;
    let upd1 = make_update(&genesis_op, "alice2.example.com", &rot_p).await;
    let upd2 = make_update(&upd1, "alice3.example.com", &rot_k).await;

    let log = PlcAuditLogVerifier::verify(
        &[
            entry(&did, &genesis_op, "2026-01-01T00:00:00.000Z", false),
            entry(&did, &upd1, "2026-01-01T00:01:00.000Z", false),
            entry(&did, &upd2, "2026-01-01T00:02:00.000Z", false),
        ],
        &did,
    )
    .unwrap();
    assert_eq!(
        log.signers,
        vec![rot_k.did_key(), rot_p.did_key(), rot_k.did_key()]
    );
    assert_eq!(log.head.cid, upd2.cid_string().unwrap());
    assert_eq!(
        log.document_data().unwrap().handle(),
        Some("alice3.example.com")
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn recovery_authority_and_72_hour_window_boundaries() {
    let signing = P256Keypair::generate().unwrap();
    let high = K256Keypair::generate().unwrap();
    let low = P256Keypair::generate().unwrap();

    let (did, genesis_op) = make_genesis(
        "alice.example.com",
        &signing,
        vec![high.did_key(), low.did_key()],
        &low,
    )
    .await;
    let low_op = make_update(&genesis_op, "hijacked.example.com", &low).await;
    let recovery = make_update(&genesis_op, "recovered.example.com", &high).await;

    // Within 72 hours (exact 72h inclusive succeeds, even if directory lied about nullified)
    let ok = PlcAuditLogVerifier::verify(
        &[
            entry(&did, &genesis_op, "2026-01-01T00:00:00.000Z", false),
            entry(&did, &low_op, "2026-01-01T00:00:00.000Z", false),
            entry(&did, &recovery, "2026-01-04T00:00:00.000Z", false),
        ],
        &did,
    )
    .unwrap();
    assert!(!ok.entries[0].nullified);
    assert!(ok.entries[1].nullified);
    assert!(!ok.entries[2].nullified);
    assert_eq!(
        ok.document_data().unwrap().handle(),
        Some("recovered.example.com")
    );

    // 72h + 1ms is rejected
    assert!(matches!(
        PlcAuditLogVerifier::verify(
            &[
                entry(&did, &genesis_op, "2026-01-01T00:00:00.000Z", false),
                entry(&did, &low_op, "2026-01-01T00:00:00.000Z", false),
                entry(&did, &recovery, "2026-01-04T00:00:00.001Z", false),
            ],
            &did
        ),
        Err(PlcError::Unauthorized(_))
    ));

    // Equal or lower authority cannot nullify
    let high_op = make_update(&genesis_op, "high.example.com", &high).await;
    let equal_fork = make_update(&genesis_op, "equal.example.com", &high).await;
    let lower_fork = make_update(&genesis_op, "lower.example.com", &low).await;
    for fork in [equal_fork, lower_fork] {
        assert!(matches!(
            PlcAuditLogVerifier::verify(
                &[
                    entry(&did, &genesis_op, "2026-01-01T00:00:00.000Z", false),
                    entry(&did, &high_op, "2026-01-01T00:01:00.000Z", false),
                    entry(&did, &fork, "2026-01-01T00:02:00.000Z", false),
                ],
                &did
            ),
            Err(PlcError::Unauthorized(_))
        ));
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn tombstone_termination_nullification_duplicate_keys_and_next_op() {
    let signing = P256Keypair::generate().unwrap();
    let high = K256Keypair::generate().unwrap();
    let low = P256Keypair::generate().unwrap();

    let (did, genesis_op) = make_genesis(
        "alice.example.com",
        &signing,
        vec![high.did_key(), low.did_key()],
        &high,
    )
    .await;
    let tomb_unsigned =
        UnsignedPlcTombstoneOperation::new(genesis_op.cid_string().unwrap()).unwrap();
    let tomb = PlcOperationCodec::sign(&UnsignedPlcOperation::Tombstone(tomb_unsigned), &low)
        .await
        .unwrap();

    // Tombstone ends the log; nothing may follow it directly
    let after_tomb = make_update(&genesis_op, "after.example.com", &high).await;
    let recovered = PlcAuditLogVerifier::verify(
        &[
            entry(&did, &genesis_op, "2026-01-01T00:00:00.000Z", false),
            entry(&did, &tomb, "2026-01-01T00:01:00.000Z", false),
            entry(&did, &after_tomb, "2026-01-01T00:02:00.000Z", false),
        ],
        &did,
    )
    .unwrap();
    assert!(!recovered.is_tombstoned());
    assert!(recovered.entries[1].nullified);
    assert_eq!(
        recovered
            .verify_next_operation(&make_update(&after_tomb, "next.example.com", &low).await)
            .unwrap(),
        1
    );

    // Tombstone followed directly as prev fails
    let bad_after_tomb_unsigned =
        UnsignedPlcTombstoneOperation::new(tomb.cid_string().unwrap()).unwrap();
    let bad_after_tomb = PlcOperationCodec::sign(
        &UnsignedPlcOperation::Tombstone(bad_after_tomb_unsigned),
        &high,
    )
    .await
    .unwrap();
    assert!(matches!(
        PlcAuditLogVerifier::verify(
            &[
                entry(&did, &genesis_op, "2026-01-01T00:00:00.000Z", false),
                entry(&did, &tomb, "2026-01-01T00:01:00.000Z", false),
                entry(&did, &bad_after_tomb, "2026-01-01T00:02:00.000Z", false),
            ],
            &did
        ),
        Err(PlcError::Unauthorized(_))
    ));

    // Timestamp parser edge cases
    assert_eq!(
        plc_timestamp_milliseconds("1970-01-01T00:00:00.000Z"),
        Some(0)
    );
    assert_eq!(
        plc_timestamp_milliseconds("2024-02-29T23:59:59.999Z"),
        Some(1_709_251_199_999)
    );
    assert_eq!(plc_timestamp_milliseconds("2025-02-29T00:00:00.000Z"), None);
    assert_eq!(plc_timestamp_milliseconds("2026-01-01T00:00:00Z"), None);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn corpus_exports_verify_100_percent() {
    let mut parents: BTreeMap<String, PlcOperation> = BTreeMap::new();
    for (did, json) in AUDIT_LOGS {
        for entry in PlcAuditLogVerifier::decode(json.as_bytes(), did).unwrap() {
            parents.insert(entry.cid, entry.operation);
        }
    }

    let legacy = PlcExportEntry::decode_json_lines(EXPORT_LEGACY).unwrap();
    let sequenced = PlcExportEntry::decode_json_lines(EXPORT_SEQUENCED).unwrap();
    assert_eq!(legacy.len(), 34);
    assert_eq!(sequenced.len(), 14);

    let legacy_cids: BTreeSet<String> = legacy.iter().map(|e| e.cid.clone()).collect();
    let parent_cids: BTreeSet<String> = parents.keys().cloned().collect();
    assert_eq!(legacy_cids, parent_cids);

    let (
        mut ops,
        mut legacy_creates,
        mut regular_gen,
        mut updates,
        mut tombstones,
        mut k256,
        mut p256,
    ) = (0, 0, 0, 0, 0, 0, 0);
    for e in &legacy {
        ops += 1;
        if e.operation.is_tombstone() {
            tombstones += 1;
        }
        let auth_keys = if let Some(prev) = e.operation.prev() {
            updates += 1;
            parents[prev].rotation_keys().unwrap()
        } else {
            if e.operation.is_legacy() {
                legacy_creates += 1;
            } else {
                regular_gen += 1;
            }
            assert_eq!(PlcOperationCodec::genesis_did(&e.operation).unwrap(), e.did);
            e.operation.rotation_keys().unwrap()
        };
        let signer_idx = PlcOperationCodec::verify(&e.operation, &auth_keys).unwrap();
        match PublicKey::from_did_key(&auth_keys[signer_idx])
            .unwrap()
            .curve()
        {
            ATProtoKeyCurve::Secp256k1 => k256 += 1,
            ATProtoKeyCurve::P256 => p256 += 1,
        }
        assert_eq!(parents[&e.cid], e.operation);
    }
    assert_eq!(
        (
            ops,
            legacy_creates,
            regular_gen,
            updates,
            tombstones,
            k256,
            p256
        ),
        (34, 2, 10, 22, 3, 32, 2)
    );

    // Check sequenced vs legacy format correspondence
    assert!(
        sequenced
            .iter()
            .all(|e| e.sequence.is_some() && e.nullified.is_none())
    );
    assert_eq!(sequenced[0].did, "did:plc:z72i7hdynmk6r22z27h6tvur");
    assert_eq!(sequenced[0].cursor(), PlcExportCursor::Sequence(26_043));
    assert_eq!(
        legacy.iter().filter(|e| e.nullified == Some(true)).count(),
        2
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn corpus_all_12_audit_logs_and_recovery_identities_verify() {
    assert_eq!(AUDIT_LOGS.len(), 12);
    let mut total_ops = 0;
    let mut curves = BTreeSet::new();

    for (did, raw) in AUDIT_LOGS {
        let log = PlcAuditLogVerifier::verify_json(raw.as_bytes(), did).unwrap();
        total_ops += log.entries.len();
        assert_eq!(log.signers.len(), log.entries.len());
        for signer in &log.signers {
            let curve = PublicKey::from_did_key(signer).unwrap().curve();
            curves.insert(match curve {
                ATProtoKeyCurve::P256 => "p256",
                ATProtoKeyCurve::Secp256k1 => "k256",
            });
        }
        let claimed = PlcAuditLogVerifier::decode(raw.as_bytes(), did).unwrap();
        let claimed_flags: Vec<bool> = claimed.iter().map(|e| e.nullified).collect();
        let verified_flags: Vec<bool> = log.entries.iter().map(|e| e.nullified).collect();
        assert_eq!(claimed_flags, verified_flags, "{did}");

        let active_ops: Vec<PlcOperation> = log
            .active_entries()
            .into_iter()
            .map(|e| e.operation.clone())
            .collect();
        assert_eq!(
            PlcAuditLogVerifier::validate_operation_log(&active_ops, did).unwrap(),
            log.document_data(),
            "{did}"
        );
    }
    assert_eq!(total_ops, 34);
    assert_eq!(curves, BTreeSet::from(["k256", "p256"]));

    // Tombstoned corpus identity
    let tomb = PlcAuditLogVerifier::verify_json(
        audit_json_for("did:plc:5qepwfemd2p3ts3phpzjvmsi"),
        "did:plc:5qepwfemd2p3ts3phpzjvmsi",
    )
    .unwrap();
    assert!(tomb.is_tombstoned());
    assert!(tomb.document_data().is_none());

    // Recovered corpus identities
    for did in [
        "did:plc:n7eilcz7ouze6kj5hwvyt4ju",
        "did:plc:xgj5yvayzto5fx3qq2o7ichg",
    ] {
        let rec = PlcAuditLogVerifier::verify_json(audit_json_for(did), did).unwrap();
        let flags: Vec<bool> = rec.entries.iter().map(|e| e.nullified).collect();
        assert_eq!(flags, vec![false, false, true, false], "{did}");
        assert!(!rec.is_tombstoned());
    }

    // Legacy P-256 without http scheme
    let legacy_p256 = PlcAuditLogVerifier::verify_json(
        audit_json_for("did:plc:k525d5my7ob3divsqd5ogf7b"),
        "did:plc:k525d5my7ob3divsqd5ogf7b",
    )
    .unwrap();
    assert_eq!(
        legacy_p256.document_data().unwrap().pds_endpoint(),
        Some("https://localhost:4989")
    );
}
