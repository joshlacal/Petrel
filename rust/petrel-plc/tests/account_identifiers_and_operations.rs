#![cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]

use std::collections::BTreeMap;

use petrel_core::{Cid, Value, dagcbor};
use petrel_crypto::{
    ATProtoKeyCurve, ATProtoSignature, ATProtoSignatureVerificationOptions, JWTBase64URL,
    K256Keypair, P256Keypair, PublicKey,
};
use petrel_plc::{
    AccountIdentifiers, CreateOp, PlcAtProfile, PlcDidDocument, PlcDocumentData, PlcError,
    PlcOperation, PlcOperationCodec, PlcOperationLimits, PlcService, PlcStrictJson,
    UnsignedPlcOperation, UnsignedPlcRegularOperation, UnsignedPlcTombstoneOperation,
};
use serde_json::{Value as Json, json};
use url::Url;

mod common;
use common::{AUDIT_LOGS, EXPORT_LEGACY, audit_json_for};

// MARK: AccountIdentifiersTests parity

#[test]
fn validate_did_with_valid_plc() {
    assert_eq!(
        AccountIdentifiers::validate_did("did:plc:z72i7hdynmk6r22z27h6tvur", false).unwrap(),
        "did:plc:z72i7hdynmk6r22z27h6tvur"
    );
}

#[test]
fn validate_did_rejects_malformed_plc() {
    for invalid in [
        "did:plc:short",
        "did:plc:Z72I7HDYNMK6R22Z27H6TVUR",
        "did:plc:z72i7hdynmk6r22z27h6tvu0",
        "did:plc:z72i7hdynmk6r22z27h6tvu1",
        "did:plc:z72i7hdynmk6r22z27h6tvu8",
        "did:plc:z72i7hdynmk6r22z27h6tvurx",
    ] {
        assert!(
            matches!(
                AccountIdentifiers::validate_did(invalid, false),
                Err(PlcError::InvalidIdentifier(_))
            ),
            "{invalid}"
        );
    }
}

#[test]
fn validate_did_with_valid_web_dids() {
    for valid in [
        "did:web:example.com",
        "did:web:sub.example.co.uk",
        "did:web:xn--bcher-kva.example.com",
        "did:web:localhost",
    ] {
        let allow_local = valid == "did:web:localhost";
        assert_eq!(
            AccountIdentifiers::validate_did(valid, allow_local).unwrap(),
            valid
        );
    }
}

#[test]
fn validate_did_rejects_web_dids_with_path_segments() {
    for bad in [
        "did:web:example.com:user",
        "did:web:example.com:users:alice",
        "did:web:example.com:",
        "did:web:",
    ] {
        assert!(
            AccountIdentifiers::validate_did(bad, true).is_err(),
            "{bad}"
        );
    }
}

#[test]
fn validate_did_allows_port_only_on_localhost() {
    assert!(AccountIdentifiers::validate_did("did:web:localhost%3A2583", true).is_ok());
    assert!(AccountIdentifiers::validate_did("did:web:localhost%3a2583", true).is_ok());
    assert!(AccountIdentifiers::validate_did("did:web:localhost%3A2583", false).is_err());
    assert!(AccountIdentifiers::validate_did("did:web:example.com%3A8443", true).is_err());
    assert!(AccountIdentifiers::validate_did("did:web:localhost%3A0", true).is_err());
    assert!(AccountIdentifiers::validate_did("did:web:localhost%3A65536", true).is_err());
}

#[test]
fn validate_did_rejects_non_handle_hosts_reserved_tlds_and_other_methods() {
    for bad in [
        "did:web:com",
        "did:web:127.0.0.1",
        "did:web:Example.COM",
        "did:web:-bad.example.com",
        "did:web:bad-.example.com",
        "did:web:foo.alt",
        "did:web:foo.arpa",
        "did:web:foo.example",
        "did:web:foo.internal",
        "did:web:foo.invalid",
        "did:web:foo.local",
        "did:web:foo.localhost",
        "did:web:foo.onion",
        "did:key:zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme",
        "alice.bsky.social",
    ] {
        assert!(
            AccountIdentifiers::validate_did(bad, true).is_err(),
            "{bad}"
        );
    }
}

#[test]
fn canonical_handle_validation() {
    assert_eq!(
        AccountIdentifiers::canonical_handle("Alice.Bsky.Social").unwrap(),
        "alice.bsky.social"
    );
    assert!(AccountIdentifiers::canonical_handle("alice").is_err());
    assert!(AccountIdentifiers::canonical_handle("alice.123").is_err());
    assert!(AccountIdentifiers::canonical_handle("-alice.example.com").is_err());
}

// MARK: PLCOperationTests parity

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn p256_and_k256_did_key_goldens_and_roundtrips() {
    // P-256 golden
    let compressed_p256 = [
        0x03, 0xa8, 0xc3, 0x05, 0x62, 0x59, 0x20, 0x89, 0x84, 0xf2, 0x1e, 0x3b, 0xb1, 0x45, 0x26,
        0x45, 0xc9, 0x4c, 0x33, 0x4f, 0x7b, 0x7e, 0x6a, 0x72, 0x1c, 0x2c, 0x3f, 0x4b, 0x5e, 0x6d,
        0x7c, 0x8b, 0x9a,
    ];
    if let Ok(pk) = PublicKey::from_sec1(ATProtoKeyCurve::P256, &compressed_p256) {
        let dk = pk.did_key();
        assert!(dk.starts_with("did:key:zDn"));
        assert_eq!(PublicKey::from_did_key(&dk).unwrap(), pk);
    }

    let p256 = P256Keypair::generate().unwrap();
    assert!(p256.did_key().starts_with("did:key:zDn"));
    assert_eq!(
        &PublicKey::from_did_key(&p256.did_key()).unwrap(),
        p256.public_key()
    );

    // K-256 golden from did:key interop vectors
    let k256_did = "did:key:zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF";
    let k256_pk = PublicKey::from_did_key(k256_did).unwrap();
    assert_eq!(k256_pk.curve(), ATProtoKeyCurve::Secp256k1);
    assert_eq!(k256_pk.did_key(), k256_did);

    // Rejects wrong multicodec / uncompressed / non-canonical base58
    assert!(PublicKey::from_did_key("did:key:z82LkvCwKAaiW24gS2F").is_err());
    assert!(PublicKey::from_did_key("did:key:z000").is_err());

    // Zero-R signature rejected
    let zero_sig = [0_u8; 64];
    assert!(!ATProtoSignature::is_canonical(
        &zero_sig,
        ATProtoKeyCurve::Secp256k1
    ));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn atprofile_genesis_maps_cid_and_did_stability() {
    let signing = P256Keypair::generate().unwrap();
    let rotation = P256Keypair::generate().unwrap();

    let unsigned = PlcAtProfile::regular_operation(
        "Alice.Example.Com",
        signing.public_key(),
        &[rotation.public_key().clone()],
        &Url::parse("https://pds.example.com/").unwrap(),
        None,
    )
    .unwrap();
    assert_eq!(unsigned.also_known_as, vec!["at://alice.example.com"]);
    assert_eq!(
        unsigned.services.get("atproto_pds").unwrap().endpoint,
        "https://pds.example.com"
    );

    // Reject path / non-443 HTTPS / non-loopback HTTP in canonical regular_operation
    assert!(
        PlcAtProfile::regular_operation(
            "alice.example.com",
            signing.public_key(),
            &[rotation.public_key().clone()],
            &Url::parse("https://pds.example.com/xrpc").unwrap(),
            None,
        )
        .is_err()
    );
    assert!(
        PlcAtProfile::regular_operation(
            "alice.example.com",
            signing.public_key(),
            &[rotation.public_key().clone()],
            &Url::parse("http://pds.example.com").unwrap(),
            None,
        )
        .is_err()
    );

    // Signing bytes omit `sig` and have explicit null `prev`
    let unsigned_cbor = UnsignedPlcOperation::Regular(unsigned.clone()).signing_dag_cbor();
    let val = dagcbor::decode(&unsigned_cbor).unwrap();
    let obj = val.as_object().unwrap();
    assert!(!obj.contains_key("sig"));
    assert_eq!(obj.get("prev"), Some(&Value::Null));

    let signed = PlcOperationCodec::sign(&UnsignedPlcOperation::Regular(unsigned), &rotation)
        .await
        .unwrap();
    let did = PlcOperationCodec::genesis_did(&signed).unwrap();
    assert!(did.starts_with("did:plc:") && did.len() == 32);
    PlcOperationCodec::verify_genesis(&signed, &did).unwrap();

    // Update requires canonical DAG-CBOR SHA-256 CID
    assert!(UnsignedPlcTombstoneOperation::new("not-a-cid".to_owned()).is_err());
    let raw_cid = Cid::for_raw(b"not dag-cbor").to_string();
    assert!(UnsignedPlcTombstoneOperation::new(raw_cid).is_err());

    let tomb_unsigned = UnsignedPlcTombstoneOperation::new(signed.cid_string().unwrap()).unwrap();
    let tomb_signed =
        PlcOperationCodec::sign(&UnsignedPlcOperation::Tombstone(tomb_unsigned), &rotation)
            .await
            .unwrap();
    assert_eq!(
        PlcOperationCodec::verify(&tomb_signed, &[rotation.did_key()]).unwrap(),
        0
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn rejects_duplicate_rotation_keys_high_s_tampering_and_strict_json() {
    let k = K256Keypair::generate().unwrap();
    let dup = UnsignedPlcRegularOperation::new(
        vec![k.did_key(), k.did_key()],
        BTreeMap::new(),
        vec![],
        BTreeMap::new(),
        None,
    );
    assert!(matches!(dup, Err(PlcError::Malformed(_))));

    let big_alias = format!("at://{}.example.com", "a".repeat(8_000));
    let too_big = UnsignedPlcRegularOperation::new(
        vec![k.did_key()],
        BTreeMap::new(),
        vec![big_alias],
        BTreeMap::new(),
        None,
    );
    assert!(matches!(too_big, Err(PlcError::Malformed(_))));

    // Tampered operation fails signature check
    let unsigned = PlcAtProfile::genesis_operation(
        "alice.example.com",
        &k.did_key(),
        &[k.did_key()],
        "https://pds.example.com",
    )
    .unwrap();
    let mut signed = PlcOperationCodec::sign(&UnsignedPlcOperation::Regular(unsigned), &k)
        .await
        .unwrap();
    if let PlcOperation::Regular(ref mut reg) = signed {
        reg.also_known_as = vec!["at://mallory.example.com".to_owned()];
    }
    assert!(matches!(
        PlcOperationCodec::verify(&signed, &[k.did_key()]),
        Err(PlcError::Unauthorized(_))
    ));

    // Strict JSON: duplicate key, padded signature, nesting depth > 64
    assert!(matches!(
        PlcStrictJson::validate(br#"{"a":1,"a":2}"#),
        Err(PlcError::Malformed(_))
    ));
    let padded_sig = format!("{}=", JWTBase64URL::encode(&[1_u8; 64]));
    assert!(matches!(
        PlcOperationCodec::decode_canonical_signature(&padded_sig),
        Err(PlcError::Malformed(_))
    ));
    let deep = format!("{}{}", "[".repeat(65), "]".repeat(65));
    assert!(matches!(
        PlcStrictJson::validate(deep.as_bytes()),
        Err(PlcError::Malformed(_))
    ));
}

// MARK: PLCOperationRulesTests & PLCLenientHeadUpdateTests parity

#[test]
fn operation_limits_presets_and_strict_structure() {
    assert_eq!(
        PlcOperationLimits::SPECIFICATION.maximum_dag_cbor_bytes,
        7_500
    );
    assert_eq!(
        PlcOperationLimits::REFERENCE_DIRECTORY.maximum_dag_cbor_bytes,
        4_000
    );
    const {
        assert!(!PlcOperationLimits::REFERENCE_DIRECTORY.allows_duplicate_also_known_as);
    }

    // Extra / missing field rejected on read
    assert!(
        PlcOperationCodec::decode_signed_json(
            br#"{"type":"plc_tombstone","prev":"bafyreibaaaa","sig":"aa","extra":1}"#
        )
        .is_err()
    );
    assert!(
        PlcOperationCodec::decode_signed_json(br#"{"type":"plc_operation","prev":null}"#).is_err()
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn updates_carry_untouched_fields_and_legacy_heads_normalize() {
    let rot = K256Keypair::generate().unwrap();
    let sign = P256Keypair::generate().unwrap();
    let mut ver_methods = BTreeMap::new();
    ver_methods.insert("atproto".to_owned(), sign.did_key());
    ver_methods.insert("extra".to_owned(), sign.did_key());
    let mut services = BTreeMap::new();
    services.insert(
        "atproto_pds".to_owned(),
        PlcService {
            kind: "AtprotoPersonalDataServer".to_owned(),
            endpoint: "https://pds.example.com".to_owned(),
        },
    );
    services.insert(
        "custom".to_owned(),
        PlcService {
            kind: "Custom".to_owned(),
            endpoint: "https://custom.example.com".to_owned(),
        },
    );

    let genesis = UnsignedPlcRegularOperation::new(
        vec![rot.did_key()],
        ver_methods.clone(),
        vec![
            "https://alice.example.com".to_owned(),
            "at://alice.example.com".to_owned(),
        ],
        services.clone(),
        None,
    )
    .unwrap();
    let signed = PlcOperationCodec::sign(&UnsignedPlcOperation::Regular(genesis), &rot)
        .await
        .unwrap();

    // Update handle replaces first at:// entry while keeping https:// alias, custom service, extra key
    let next = PlcOperationCodec::update_handle(&signed, "new.example.com").unwrap();
    assert_eq!(
        next.also_known_as,
        vec![
            "https://alice.example.com".to_owned(),
            "at://new.example.com".to_owned(),
        ]
    );
    assert_eq!(next.verification_methods, ver_methods);
    assert_eq!(next.services, services);
    assert_eq!(next.prev, Some(signed.cid_string().unwrap()));

    // Legacy genesis whose recoveryKey == signingKey updates cleanly
    let legacy_entries = petrel_plc::PlcExportEntry::decode_json_lines(EXPORT_LEGACY).unwrap();
    let legacy_entry = &legacy_entries[32];
    let CreateOp {
        signing_key,
        recovery_key,
        ..
    } = legacy_entry
        .operation
        .as_legacy_create()
        .expect("vector 32 is legacy create");
    assert_eq!(recovery_key, signing_key);

    let after_legacy =
        PlcOperationCodec::update_handle(&legacy_entry.operation, "renamed.example.com").unwrap();
    assert_eq!(after_legacy.rotation_keys, vec![signing_key.clone()]);
    assert_eq!(
        after_legacy.also_known_as.first().map(String::as_str),
        Some("at://renamed.example.com")
    );
    assert_eq!(
        after_legacy.prev,
        Some(legacy_entry.operation.cid_string().unwrap())
    );
}

#[test]
fn lenient_heads_and_deterministic_did_document_render() {
    let sign = P256Keypair::generate().unwrap();
    let legacy_entries = petrel_plc::PlcExportEntry::decode_json_lines(EXPORT_LEGACY).unwrap();

    // Lenient head with duplicate rotation keys and aliases drops later duplicates on update
    let sig = legacy_entries[0].operation.signature().to_owned();
    let rot_a = K256Keypair::generate().unwrap().did_key();
    let rot_b = K256Keypair::generate().unwrap().did_key();
    let lenient_json = serde_json::to_vec(&json!({
        "type": "plc_operation",
        "rotationKeys": [rot_a, rot_b, rot_a],
        "verificationMethods": { "atproto": sign.did_key() },
        "alsoKnownAs": ["at://alice.example.com", "at://alice.example.com"],
        "services": {
            "atproto_pds": { "type": "AtprotoPersonalDataServer", "endpoint": "https://pds.example.com" }
        },
        "prev": Json::Null,
        "sig": sig
    }))
    .unwrap();
    let lenient_head = PlcOperationCodec::decode_signed_json(&lenient_json).unwrap();
    let updated =
        PlcOperationCodec::update_pds(&lenient_head, "https://other.example.com").unwrap();
    assert_eq!(updated.rotation_keys, vec![rot_a, rot_b]);
    assert_eq!(updated.also_known_as, vec!["at://alice.example.com"]);
    assert_eq!(
        updated.services.get("atproto_pds").unwrap().endpoint,
        "https://other.example.com"
    );

    // Oversized alias error names 2048 & alsoKnownAs
    let oversized_json = serde_json::to_vec(&json!({
        "type": "plc_operation",
        "rotationKeys": [K256Keypair::generate().unwrap().did_key()],
        "verificationMethods": { "atproto": sign.did_key() },
        "alsoKnownAs": ["at://alice.example.com", format!("https://example.com/{}", "a".repeat(2_100))],
        "services": {
            "atproto_pds": { "type": "AtprotoPersonalDataServer", "endpoint": "https://pds.example.com" }
        },
        "prev": Json::Null,
        "sig": sig
    }))
    .unwrap();
    let oversized_head = PlcOperationCodec::decode_signed_json(&oversized_json).unwrap();
    match PlcOperationCodec::update_handle(&oversized_head, "bob.example.com") {
        Err(PlcError::Malformed(msg)) => {
            assert!(msg.contains("2048"), "{msg}");
            assert!(msg.contains("alsoKnownAs"), "{msg}");
        }
        other => panic!("expected Malformed, got {other:?}"),
    }

    // DID document rendering deterministically orders keys & services
    let (atproto_did, _) = AUDIT_LOGS
        .iter()
        .find(|(d, _)| *d == "did:plc:ewvi7nxzyoun6zhxrhs64oiz")
        .copied()
        .unwrap();
    let verified =
        petrel_plc::PlcAuditLogVerifier::verify_json(audit_json_for(atproto_did), atproto_did)
            .unwrap();
    let doc = PlcDidDocument::from_data(&verified.document_data().unwrap());
    assert_eq!(doc.id, atproto_did);
    assert_eq!(doc.handle(), Some("atproto.com"));
    assert_eq!(
        doc.pds_endpoint(),
        Some("https://enoki.us-east.host.bsky.network")
    );
    let _ = PlcDocumentData::clone(&verified.document_data().unwrap());
    let _ = ATProtoSignatureVerificationOptions::STRICT;
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn verification_method_keys_link_and_bytes_canonical_json_roundtrip() {
    for key_id in ["$link", "$bytes"] {
        let signing = K256Keypair::generate().unwrap();
        let rotation = P256Keypair::generate().unwrap();
        let mut methods = BTreeMap::new();
        methods.insert(key_id.to_owned(), signing.did_key());
        let mut services = BTreeMap::new();
        services.insert(
            "atproto_pds".to_owned(),
            PlcService {
                kind: "AtprotoPersonalDataServer".to_owned(),
                endpoint: "https://pds.example.com".to_owned(),
            },
        );
        let unsigned = UnsignedPlcRegularOperation::new(
            vec![rotation.did_key()],
            methods,
            vec!["at://alice.example.com".to_owned()],
            services,
            None,
        )
        .unwrap();
        let signed = PlcOperationCodec::sign(&UnsignedPlcOperation::Regular(unsigned), &rotation)
            .await
            .unwrap();
        let json_bytes = signed.canonical_json().unwrap();
        let json_str = std::str::from_utf8(&json_bytes).unwrap();
        assert!(
            json_str.contains(&format!("\"{key_id}\":\"{}\"", signing.did_key())),
            "{json_str}"
        );
        let decoded = PlcOperationCodec::decode_signed_json(&json_bytes).unwrap();
        assert_eq!(decoded, signed);
        let did = PlcOperationCodec::genesis_did(&decoded).unwrap();
        PlcOperationCodec::verify_genesis(&decoded, &did).unwrap();
    }
}
