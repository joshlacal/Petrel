mod common;

use std::collections::BTreeMap;

use base64::Engine as _;
use base64::engine::general_purpose::STANDARD_NO_PAD;
use petrel_core::{Cid, Nsid, Value, dagcbor};
use petrel_repo::error::RecordCodecError;
use petrel_repo::limits::RepositoryLimits;
use petrel_repo::record::{
    MAX_RECORD_DEPTH, MAX_SAFE_INT, MIN_SAFE_INT, Record, RecordCodec, parse_strict_json,
};
use petrel_repo::types::RepositoryReadPolicy;
use serde::Deserialize;
use serde_json::Value as JsonValue;

#[derive(Debug, Deserialize)]
struct FixtureVector {
    json: JsonValue,
    cbor_base64: String,
    cid: String,
}

#[derive(Debug, Deserialize)]
struct NoteJsonVector {
    note: String,
    json: JsonValue,
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn data_model_fixture_vectors_match_cbor_cid_and_json_roundtrip() {
    let vectors: Vec<FixtureVector> =
        serde_json::from_str(common::data_model_fixtures_json()).unwrap();
    assert!(!vectors.is_empty());

    for vec_entry in vectors {
        let json_bytes = serde_json::to_vec(&vec_entry.json).unwrap();
        let record =
            Record::from_json_bytes_with_policy(&json_bytes, &RepositoryReadPolicy::data_model())
                .unwrap();
        let expected_cbor = STANDARD_NO_PAD.decode(&vec_entry.cbor_base64).unwrap();
        assert_eq!(record.to_dag_cbor(), expected_cbor);
        assert_eq!(record.cid().to_string(), vec_entry.cid);

        // Decode back from DAG-CBOR and confirm JSON serialization matches input value.
        let from_cbor =
            Record::from_dag_cbor_with_policy(&expected_cbor, &RepositoryReadPolicy::data_model())
                .unwrap();
        assert_eq!(from_cbor, record);
        let roundtrip_json: JsonValue =
            serde_json::from_slice(&from_cbor.to_json_bytes().unwrap()).unwrap();
        assert_eq!(roundtrip_json, vec_entry.json);
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn data_model_valid_and_invalid_json_vectors() {
    let valid_vectors: Vec<NoteJsonVector> =
        serde_json::from_str(common::data_model_valid_json()).unwrap();
    for item in valid_vectors {
        let json_bytes = serde_json::to_vec(&item.json).unwrap();
        // `float, but integer-like` has `123.0` in JSON — Rust `serde_json` parses `123.0`
        // as f64 whose Display contains `.`, whereas `parse_strict_json` rejects `.` unless checked;
        // note `petrel_core::Value::from_json_data_model` mirrors ATProto JSON rules:
        if item.note == "float, but integer-like" {
            let parsed = Value::from_json_data_model(&json_bytes);
            assert!(
                parsed.is_ok(),
                "expected `{}` to pass data_model JSON parsing: {:?}",
                item.note,
                parsed
            );
        } else {
            let parsed = Record::from_json_bytes_with_policy(
                &json_bytes,
                &RepositoryReadPolicy::data_model(),
            );
            assert!(
                parsed.is_ok(),
                "expected `{}` to pass: {:?}",
                item.note,
                parsed
            );
        }
    }

    let invalid_vectors: Vec<NoteJsonVector> =
        serde_json::from_str(common::data_model_invalid_json()).unwrap();
    for item in invalid_vectors {
        let json_bytes = serde_json::to_vec(&item.json).unwrap();
        // Notice: `record with $type null / 123 / ""` or `blob with string size` etc.
        let strict = Record::from_json_bytes(&json_bytes);
        assert!(
            strict.is_err(),
            "expected invalid `{}` to be rejected, got Ok({:?})",
            item.note,
            strict
        );
    }
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn blob_and_strong_ref_record_codec_parity() {
    let blob_cid = "bafkreiexxtxgfx3tvpg4h5pjzlzvmc2rozjbt5wc6fjlzyqgz4fswzyliq";
    let record_cid = "bafyreiae5sz3cd4ohalt7yiwrdfke4wjof3rbnufaxo533zzxocygc3uwa";

    let avatar_json = format!(
        r#"{{"$type":"app.bsky.actor.profile","displayName":"Swan","avatar":{{"$type":"blob","ref":{{"$link":"{blob_cid}"}},"mimeType":"image/jpeg","size":17}}}}"#
    );
    let record = Record::from_json_bytes(avatar_json.as_bytes()).unwrap();
    assert_eq!(
        record
            .blob_cids()
            .unwrap()
            .into_iter()
            .map(|c| c.to_string())
            .collect::<Vec<_>>(),
        vec![blob_cid.to_owned()]
    );
    let typed = record.typed_blob_references().unwrap();
    assert_eq!(typed.len(), 1);
    assert_eq!(typed[0].cid.to_string(), blob_cid);
    assert_eq!(typed[0].mime_type, "image/jpeg");
    assert_eq!(typed[0].size, 17);

    // StrongRef stays string and reports zero blobs
    let like_json = format!(
        r#"{{"$type":"app.bsky.feed.like","createdAt":"2026-08-20T19:00:00.000Z","subject":{{"uri":"at://did:plc:abcdefghijklmnopqrstuvwx/app.bsky.feed.post/abc","cid":"{record_cid}"}}}}"#
    );
    let like = Record::from_json_bytes(like_json.as_bytes()).unwrap();
    assert_eq!(like.blob_cids().unwrap(), vec![]);
    assert_eq!(like.typed_blob_references().unwrap(), vec![]);
}

#[allow(clippy::too_many_lines)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn record_codec_enforces_safe_integers_depth_type_and_blessed_links() {
    let collection = Nsid::parse("app.bsky.feed.post").unwrap();
    let limits = RepositoryLimits::standard();

    // Unsafe integer fails under strict, succeeds under data_model
    let mut unsafe_map = BTreeMap::new();
    unsafe_map.insert(
        "$type".to_owned(),
        Value::String("app.bsky.feed.post".into()),
    );
    unsafe_map.insert("n".to_owned(), Value::Integer(MAX_SAFE_INT + 1));
    assert!(matches!(
        RecordCodec::prepare_for_write(
            &Value::Object(unsafe_map.clone()),
            &collection,
            &limits,
            &RepositoryReadPolicy::strict()
        ),
        Err(RecordCodecError::UnsafeInteger(_))
    ));
    unsafe_map.insert("n".to_owned(), Value::Integer(MIN_SAFE_INT - 1));
    assert!(matches!(
        RecordCodec::prepare_for_write(
            &Value::Object(unsafe_map.clone()),
            &collection,
            &limits,
            &RepositoryReadPolicy::strict()
        ),
        Err(RecordCodecError::UnsafeInteger(_))
    ));
    assert!(
        RecordCodec::prepare_for_write(
            &Value::Object(unsafe_map),
            &collection,
            &limits,
            &RepositoryReadPolicy::data_model()
        )
        .is_ok()
    );

    // Record $type mismatch
    let mut wrong_type = BTreeMap::new();
    wrong_type.insert(
        "$type".to_owned(),
        Value::String("app.bsky.feed.like".into()),
    );
    assert!(matches!(
        RecordCodec::prepare_for_write(
            &Value::Object(wrong_type),
            &collection,
            &limits,
            &RepositoryReadPolicy::strict()
        ),
        Err(RecordCodecError::TypeCollectionMismatch { .. })
    ));

    // Unblessed link in record (custom codec 0x70 dag-pb)
    let custom_cid = Cid::from_bytes(&[
        0x01, 0x70, 0x12, 0x20, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    ])
    .unwrap();
    let mut unblessed = BTreeMap::new();
    unblessed.insert(
        "$type".to_owned(),
        Value::String("app.bsky.feed.post".into()),
    );
    unblessed.insert("link".to_owned(), Value::Link(custom_cid));
    assert!(matches!(
        RecordCodec::prepare_for_write(
            &Value::Object(unblessed.clone()),
            &collection,
            &limits,
            &RepositoryReadPolicy::strict()
        ),
        Err(RecordCodecError::UnblessedLink(_))
    ));

    // Exceeding nesting depth 64
    let mut nested = Value::Integer(1);
    for _ in 0..(MAX_RECORD_DEPTH + 2) {
        nested = Value::Array(vec![nested]);
    }
    let mut deep_map = BTreeMap::new();
    deep_map.insert(
        "$type".to_owned(),
        Value::String("app.bsky.feed.post".into()),
    );
    deep_map.insert("deep".to_owned(), nested);
    assert!(matches!(
        RecordCodec::prepare_for_write(
            &Value::Object(deep_map),
            &collection,
            &limits,
            &RepositoryReadPolicy::strict()
        ),
        Err(RecordCodecError::DepthExceeded { .. })
    ));

    // Strict JSON rejects floats and padded $bytes
    assert!(parse_strict_json(br#"{"a":1.5}"#, true).is_err());
    assert!(parse_strict_json(br#"{"b":{"$bytes":"AQID="}}"#, true).is_err());

    // Strict JSON and Record::from_json_bytes reject duplicate keys (top-level, nested, and wrappers)
    // and excessive nesting depth during deserialization.
    let dup_top = br#"{"$type":"app.bsky.feed.post","text":"first","text":"second"}"#;
    assert!(matches!(
        parse_strict_json(dup_top, true),
        Err(petrel_repo::error::RecordJsonError::DuplicateKey(ref k)) if k == "text"
    ));
    assert!(matches!(
        Record::from_json_bytes(dup_top),
        Err(RecordCodecError::Json(
            petrel_repo::error::RecordJsonError::DuplicateKey(ref k)
        )) if k == "text"
    ));

    let dup_nested = br#"{"$type":"app.bsky.feed.post","embed":{"k":1,"k":2}}"#;
    assert!(matches!(
        Record::from_json_bytes(dup_nested),
        Err(RecordCodecError::Json(
            petrel_repo::error::RecordJsonError::DuplicateKey(ref k)
        )) if k == "k"
    ));

    let cid_str = "bafkreiexxtxgfx3tvpg4h5pjzlzvmc2rozjbt5wc6fjlzyqgz4fswzyliq";
    let dup_link = format!(
        r#"{{"$type":"app.bsky.feed.post","ref":{{"$link":"{cid_str}","$link":"{cid_str}"}}}}"#
    );
    assert!(matches!(
        Record::from_json_bytes(dup_link.as_bytes()),
        Err(RecordCodecError::Json(
            petrel_repo::error::RecordJsonError::DuplicateKey(ref k)
        )) if k == "$link"
    ));

    let dup_bytes = br#"{"$type":"app.bsky.feed.post","blob":{"$bytes":"AQID","$bytes":"AQID"}}"#;
    assert!(matches!(
        Record::from_json_bytes(dup_bytes),
        Err(RecordCodecError::Json(
            petrel_repo::error::RecordJsonError::DuplicateKey(ref k)
        )) if k == "$bytes"
    ));

    let deep_json = format!(
        "{}1{}",
        "[".repeat(MAX_RECORD_DEPTH + 2),
        "]".repeat(MAX_RECORD_DEPTH + 2)
    );
    assert!(matches!(
        parse_strict_json(deep_json.as_bytes(), true),
        Err(petrel_repo::error::RecordJsonError::DepthExceeded(
            MAX_RECORD_DEPTH
        ))
    ));
    assert!(parse_strict_json(br#"{"a":1} trailing"#, true).is_err());

    let _ = dagcbor::encode(&Value::Null);
}
