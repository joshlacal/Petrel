use std::collections::BTreeMap;

use base64::Engine as _;
use base64::engine::general_purpose::STANDARD_NO_PAD;
use petrel_core::{Cid, ToValue, Value};
use petrel_lexicon::{LexBlobRef, LexValue, LexValueError, ParseOptions};
use serde::Deserialize;

#[derive(Deserialize)]
struct ValidVector {
    note: String,
    json: serde_json::Value,
}

#[derive(Deserialize)]
struct InvalidVector {
    note: String,
    json: serde_json::Value,
}

#[derive(Deserialize)]
struct FixtureVector {
    json: serde_json::Value,
    cbor_base64: String,
    cid: String,
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn official_data_model_valid_vectors() {
    let raw =
        include_str!("../../../Tests/PetrelLexiconTests/Vectors/data-model/data-model-valid.json");
    let cases: Vec<ValidVector> = serde_json::from_str(raw).expect("parse data-model-valid.json");
    assert!(!cases.is_empty());

    for case in cases {
        let json_bytes = serde_json::to_vec(&case.json).expect("re-encode fixture");
        let parsed = LexValue::from_record_json_bytes(&json_bytes, ParseOptions::standard())
            .unwrap_or_else(|e| panic!("valid vector {:?} failed: {e}", case.note));
        let cbor = parsed.to_dag_cbor();
        let from_cbor = LexValue::from_record_dag_cbor(&cbor, ParseOptions::standard())
            .unwrap_or_else(|e| panic!("cbor roundtrip {:?} failed: {e}", case.note));
        assert_eq!(from_cbor, parsed, "roundtrip mismatch for {}", case.note);
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn official_data_model_invalid_vectors() {
    let raw = include_str!(
        "../../../Tests/PetrelLexiconTests/Vectors/data-model/data-model-invalid.json"
    );
    let cases: Vec<InvalidVector> =
        serde_json::from_str(raw).expect("parse data-model-invalid.json");
    assert!(!cases.is_empty());

    for case in cases {
        let json_bytes = serde_json::to_vec(&case.json).expect("re-encode fixture");
        let result = LexValue::from_record_json_bytes(&json_bytes, ParseOptions::standard());
        assert!(
            result.is_err(),
            "expected invalid vector {:?} to fail, got {result:?}",
            case.note
        );
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn official_data_model_fixtures_match_cbor_and_cid() {
    let raw = include_str!(
        "../../../Tests/PetrelLexiconTests/Vectors/data-model/data-model-fixtures.json"
    );
    let cases: Vec<FixtureVector> =
        serde_json::from_str(raw).expect("parse data-model-fixtures.json");
    assert_eq!(cases.len(), 3);

    for (idx, case) in cases.iter().enumerate() {
        let json_bytes = serde_json::to_vec(&case.json).expect("re-encode fixture json");
        let val = LexValue::from_record_json_bytes(&json_bytes, ParseOptions::standard())
            .unwrap_or_else(|e| panic!("fixture #{idx} JSON decode failed: {e}"));
        let expected_cbor = STANDARD_NO_PAD
            .decode(case.cbor_base64.as_bytes())
            .expect("decode fixture cbor_base64");
        assert_eq!(val.to_dag_cbor(), expected_cbor, "CBOR mismatch #{idx}");
        assert_eq!(val.cid().to_string(), case.cid, "CID mismatch #{idx}");

        let decoded_cbor = LexValue::from_record_dag_cbor(&expected_cbor, ParseOptions::standard())
            .unwrap_or_else(|e| panic!("fixture #{idx} CBOR decode failed: {e}"));
        assert_eq!(decoded_cbor, val, "CBOR/JSON equality #{idx}");
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn strict_json_edge_cases_and_options() {
    // UTF-8 BOM rejected
    assert!(matches!(
        LexValue::from_json_bytes(b"\xEF\xBB\xBF{}", ParseOptions::standard()),
        Err(LexValueError::InvalidUtf8 { .. })
    ));

    // Duplicate key rejected
    assert!(matches!(
        LexValue::from_json_bytes(br#"{"a":1,"a":2}"#, ParseOptions::standard()),
        Err(LexValueError::DuplicateKey { .. })
    ));

    // Integer-like float accepted, fractional float & -0 rejected
    assert_eq!(
        LexValue::from_json_bytes(b"123.0", ParseOptions::standard()).unwrap(),
        LexValue::integer(123)
    );
    assert_eq!(
        LexValue::from_json_bytes(b"9007199254740993e0", ParseOptions::standard()).unwrap(),
        LexValue::integer(9_007_199_254_740_993)
    );
    assert_eq!(
        LexValue::from_json_bytes(b"9223372036854775807e0", ParseOptions::standard()).unwrap(),
        LexValue::integer(i64::MAX)
    );
    assert_eq!(
        LexValue::from_json_bytes(b"-9223372036854775808e0", ParseOptions::standard()).unwrap(),
        LexValue::integer(i64::MIN)
    );
    assert_eq!(
        LexValue::from_json_bytes(b"1.5e2", ParseOptions::standard()).unwrap(),
        LexValue::integer(150)
    );
    assert_eq!(
        LexValue::from_json_bytes(b"100e-2", ParseOptions::standard()).unwrap(),
        LexValue::integer(1)
    );
    assert_eq!(
        LexValue::from_json_bytes(b"0e999999", ParseOptions::standard()).unwrap(),
        LexValue::integer(0)
    );
    assert!(matches!(
        LexValue::from_json_bytes(b"1000000000000000001e-18", ParseOptions::standard()),
        Err(LexValueError::InvalidNumber { .. })
    ));
    assert!(matches!(
        LexValue::from_json_bytes(b"9223372036854775808e0", ParseOptions::standard()),
        Err(LexValueError::InvalidNumber { .. })
    ));
    assert!(matches!(
        LexValue::from_json_bytes(b"-0e0", ParseOptions::standard()),
        Err(LexValueError::InvalidNumber { .. })
    ));
    assert!(matches!(
        LexValue::from_json_bytes(b"1e1000", ParseOptions::standard()),
        Err(LexValueError::InvalidNumber { .. })
    ));
    assert!(matches!(
        LexValue::from_json_bytes(b"123.45", ParseOptions::standard()),
        Err(LexValueError::InvalidNumber { .. })
    ));
    assert!(matches!(
        LexValue::from_json_bytes(b"-0", ParseOptions::standard()),
        Err(LexValueError::InvalidNumber { .. })
    ));

    // Padded base64 rejected in $bytes
    assert!(matches!(
        LexValue::from_json_bytes(br#"{"$bytes":"AQID="}"#, ParseOptions::standard()),
        Err(LexValueError::InvalidBytesEncoding { .. })
    ));

    // Depth limit enforced
    let deep = format!("{}{}", "[".repeat(129), "]".repeat(129));
    assert!(matches!(
        LexValue::from_json_bytes(deep.as_bytes(), ParseOptions::standard()),
        Err(LexValueError::DepthExceeded { .. })
    ));

    // Blob with dag-cbor CID: accepted under standard(), rejected under strict()
    let blob_json = br#"{"$type":"blob","ref":{"$link":"bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a"},"mimeType":"image/png","size":42}"#;
    let standard = LexValue::from_json_bytes(blob_json, ParseOptions::standard()).unwrap();
    assert!(
        standard
            .as_blob_ref(&ParseOptions::standard())
            .unwrap()
            .is_some()
    );
    assert!(matches!(
        LexValue::from_json_bytes(blob_json, ParseOptions::strict()),
        Err(LexValueError::InvalidLink { .. })
    ));

    // Large (400KB+) multi-byte UTF-8 JSON string parses cleanly in linear time
    let big_text = "é😀a".repeat(100_000);
    let big_json = format!(r#"{{"text":"{big_text}"}}"#);
    let parsed_big =
        LexValue::from_json_bytes(big_json.as_bytes(), ParseOptions::standard()).unwrap();
    assert_eq!(
        parsed_big
            .as_object()
            .and_then(|m| m.get("text"))
            .and_then(Value::as_str),
        Some(big_text.as_str())
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn strict_dag_cbor_rejections_and_nfc_nfd_keys() {
    // Non-canonical key order: "bb" before "a" (longer before shorter)
    let non_canonical = [0xA2, 0x62, b'b', b'b', 0x01, 0x61, b'a', 0x02];
    assert!(matches!(
        LexValue::from_dag_cbor(&non_canonical, ParseOptions::standard()),
        Err(LexValueError::InvalidCbor { .. })
    ));

    // Non-minimal integer (0x18 0x05 instead of 0x05)
    assert!(matches!(
        LexValue::from_dag_cbor(&[0x18, 0x05], ParseOptions::standard()),
        Err(LexValueError::InvalidCbor { .. })
    ));

    // Float64 rejected
    assert!(matches!(
        LexValue::from_dag_cbor(
            &[0xFB, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
            ParseOptions::standard()
        ),
        Err(LexValueError::InvalidCbor { .. })
    ));

    // Indefinite array rejected
    assert!(matches!(
        LexValue::from_dag_cbor(&[0x9F, 0xFF], ParseOptions::standard()),
        Err(LexValueError::InvalidCbor { .. })
    ));

    // Non-42 tag rejected
    assert!(matches!(
        LexValue::from_dag_cbor(&[0xC1, 0x00], ParseOptions::standard()),
        Err(LexValueError::InvalidCbor { .. })
    ));

    // Trailing bytes rejected
    assert!(matches!(
        LexValue::from_dag_cbor(&[0x01, 0x02], ParseOptions::standard()),
        Err(LexValueError::InvalidCbor { .. })
    ));

    // NFC vs NFD keys stay distinct
    let mut map = BTreeMap::new();
    map.insert("\u{00E9}".to_owned(), Value::Integer(1));
    map.insert("e\u{0301}".to_owned(), Value::Integer(2));
    let val = LexValue::object(map);
    let cbor = val.to_dag_cbor();
    let rt = LexValue::from_dag_cbor(&cbor, ParseOptions::standard()).unwrap();
    assert_eq!(rt.as_object().unwrap().len(), 2);

    // JSON-only reserved `$bytes` and `$link` keys rejected in DAG-CBOR maps (top-level & nested)
    let cbor_reserved_bytes: [u8; 11] = [
        0xA1, 0x66, b'$', b'b', b'y', b't', b'e', b's', 0x62, b'A', b'A',
    ];
    assert!(matches!(
        LexValue::from_dag_cbor(&cbor_reserved_bytes, ParseOptions::standard()),
        Err(LexValueError::InvalidBytesEncoding { ref path, .. }) if path.is_empty()
    ));

    let mut nested_link = BTreeMap::new();
    nested_link.insert("$link".to_owned(), Value::String("AA".to_owned()));
    let mut outer = BTreeMap::new();
    outer.insert("inner".to_owned(), Value::Object(nested_link));
    let nested_cbor = petrel_core::dagcbor::encode(&Value::Object(outer));
    assert!(matches!(
        LexValue::from_dag_cbor(&nested_cbor, ParseOptions::standard()),
        Err(LexValueError::InvalidLink { ref path, .. }) if path == "/inner"
    ));

    // Real CBOR bytes/CID survive CBOR -> JSON -> CBOR round-trip unchanged
    let mut mixed = BTreeMap::new();
    mixed.insert("raw".to_owned(), Value::Bytes(vec![1, 2, 3]));
    mixed.insert("cid".to_owned(), Value::Link(Cid::for_raw(b"link-payload")));
    let mixed_val = LexValue::object(mixed);
    let json_rt =
        LexValue::from_json_bytes(&mixed_val.to_json_bytes(), ParseOptions::standard()).unwrap();
    assert_eq!(json_rt, mixed_val);
    assert_eq!(json_rt.to_dag_cbor(), mixed_val.to_dag_cbor());
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn generated_type_and_blob_ref_bridge() {
    let cid = Cid::for_raw(b"hello blob");
    let blob = LexBlobRef::new(cid.clone(), "text/plain", 10);
    let val = LexValue::from_value(blob.to_value());
    let roundtrip = val
        .as_blob_ref(&ParseOptions::strict())
        .unwrap()
        .expect("blob ref");
    assert_eq!(roundtrip, blob);

    let strong = petrel_api::generated::com::atproto::repo::strong_ref::StrongRef::new(
        petrel_core::AtUri::parse("at://did:plc:alice/app.bsky.feed.post/3k2y").unwrap(),
        petrel_core::CidString::parse(cid.to_string()).unwrap(),
    );
    let encoded = LexValue::from_encoding(&strong).expect("encode StrongRef");
    let decoded: petrel_api::generated::com::atproto::repo::strong_ref::StrongRef =
        encoded.decode().expect("decode StrongRef");
    assert_eq!(decoded, strong);
    let _ = strong.to_value().unwrap();
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn unicode_escape_rejects_non_hex_signs_and_whitespace() {
    for raw in [
        br#""\u+041""#.as_slice(),
        br#""\u-041""#.as_slice(),
        br#""\u0+41""#.as_slice(),
        br#""\u 041""#.as_slice(),
        br#""\u004""#.as_slice(),
    ] {
        assert!(
            matches!(
                LexValue::from_json_bytes(raw, ParseOptions::standard()),
                Err(LexValueError::InvalidJson { .. })
            ),
            "expected InvalidJson for {:?}",
            std::str::from_utf8(raw)
        );
    }
    assert_eq!(
        LexValue::from_json_bytes(br#""\u0041\u00e9""#, ParseOptions::standard())
            .unwrap()
            .0
            .as_str(),
        Some("A\u{00E9}")
    );
}
