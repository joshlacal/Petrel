//! Wire compatibility with already-deployed peers (Jacquard servers, the
//! official TypeScript PDS, Swift and Kotlin Petrel).

use std::collections::BTreeMap;

use petrel_core::serde_bridge::cid_of;

use petrel_core::{
    Bytes, CidLink, ObjectReader, ObjectWriter, Value, XrpcErrorBody, dagcbor, from_json,
    from_json_strict, to_dag_cbor, to_json,
};

fn field<'a>(value: &'a Value, name: &str) -> &'a Value {
    value.as_object().unwrap().get(name).unwrap()
}

// --- floats -----------------------------------------------------------------

#[test]
fn an_integral_float_reads_as_an_integer_on_both_json_paths() {
    let json = br#"{"a":1.0,"b":-2e2,"c":30.000}"#;
    let lenient: Value = from_json(json).unwrap();
    let strict: Value = from_json_strict(json).unwrap();
    let data_model = Value::from_json_data_model(json).unwrap();
    for value in [&lenient, &strict, &data_model] {
        assert_eq!(field(value, "a"), &Value::Integer(1));
        assert_eq!(field(value, "b"), &Value::Integer(-200));
        assert_eq!(field(value, "c"), &Value::Integer(30));
    }
}

#[test]
fn a_fractional_float_in_an_untyped_position_survives_a_lenient_decode() {
    let json = br#"{"error":"X","unknownField":{"list":[1,2.5],"score":0.75}}"#;
    let value: Value = from_json(json).unwrap();
    assert_eq!(value.kind(), "object");
    assert_eq!(to_json(&value).unwrap(), json.to_vec());
}

#[test]
fn a_fractional_float_has_no_dag_cbor_form() {
    let value: Value = from_json(br#"{"score":0.75}"#).unwrap();
    assert!(to_dag_cbor(&value).is_err());
    assert!(cid_of(&value).is_err());
    assert!(dagcbor::try_encode(&value).is_err());
}

#[test]
fn a_fractional_float_is_refused_by_strict_and_data_model_decoding() {
    let json = br#"{"score":0.75}"#;
    assert!(from_json_strict::<Value>(json).is_err());
    assert!(Value::from_json_data_model(json).is_err());
}

#[test]
fn a_float_in_a_typed_integer_field_is_still_an_error() {
    assert!(from_json::<i64>(b"1.5").is_err());
    let value: Value = from_json(br#"{"count":1.5}"#).unwrap();
    let mut reader = ObjectReader::new(value).unwrap();
    assert!(reader.required::<i64>("count").is_err());
}

#[test]
fn an_xrpc_error_body_with_a_float_still_parses() {
    let body = br#"{"error":"RateLimitExceeded","message":"slow down","retryAfter":1.5}"#;
    let parsed = XrpcErrorBody::parse(body).expect("error body");
    assert_eq!(parsed.error, "RateLimitExceeded");
    assert_eq!(parsed.message.as_deref(), Some("slow down"));
}

// --- $bytes -----------------------------------------------------------------

#[test]
fn bytes_decode_padded_unpadded_and_url_safe() {
    // 0xfb 0xff 0xbf: '+' and '/' in the standard alphabet, '-' and '_' in
    // the URL-safe one.
    let expected = vec![0xfb_u8, 0xff, 0xbf, 0x01];
    for text in ["+/+/AQ==", "+/+/AQ", "-_-_AQ==", "-_-_AQ"] {
        let json = format!(r#"{{"$bytes":"{text}"}}"#);
        let bytes: Bytes = from_json(json.as_bytes()).unwrap_or_else(|e| panic!("{text}: {e}"));
        assert_eq!(bytes.0, expected, "{text}");
        let data_model = Value::from_json_data_model(json.as_bytes()).unwrap();
        assert_eq!(data_model, Value::Bytes(expected.clone()), "{text}");
    }
}

#[test]
fn bytes_encode_unpadded_standard_base64_like_the_reference_pds() {
    let json = to_json(&Bytes(vec![0xfb, 0xff, 0xbf, 0x01])).unwrap();
    assert_eq!(json, br#"{"$bytes":"+/+/AQ"}"#.to_vec());
}

#[test]
fn bytes_with_mixed_alphabets_are_refused() {
    assert!(from_json::<Bytes>(br#"{"$bytes":"+_+_AQ"}"#).is_err());
}

// --- malformed $bytes / $link lookalikes in untyped positions ---------------

#[test]
fn a_malformed_lookalike_in_an_untyped_position_stays_a_plain_map() {
    for inner in [
        r#"{"$bytes":"!!not base64!!"}"#,
        r#"{"$bytes":12}"#,
        r#"{"$link":"not-a-cid"}"#,
        r#"{"$link":"QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"}"#,
        r#"{"$link":true}"#,
    ] {
        let json = format!(r#"{{"extra":{inner}}}"#);
        let value: Value = from_json(json.as_bytes()).unwrap_or_else(|e| panic!("{inner}: {e}"));
        assert_eq!(field(&value, "extra").kind(), "object", "{inner}");
        // JSON re-encode is faithful: the map reads back as the same map.
        assert_eq!(
            to_json(&value).unwrap(),
            json.as_bytes().to_vec(),
            "{inner}"
        );
        // DAG-CBOR still round-trips canonically.
        let block = dagcbor::encode(&value);
        assert_eq!(dagcbor::decode(&block).unwrap(), value, "{inner}");
    }
}

#[test]
fn a_malformed_lookalike_is_still_refused_where_it_must_be_typed() {
    assert!(from_json::<Bytes>(br#"{"$bytes":"!!"}"#).is_err());
    assert!(from_json::<CidLink>(br#"{"$link":"not-a-cid"}"#).is_err());
    assert!(from_json_strict::<Value>(br#"{"x":{"$bytes":"!!"}}"#).is_err());
    assert!(Value::from_json_data_model(br#"{"x":{"$link":"nope"}}"#).is_err());
}

#[test]
fn a_well_formed_lookalike_map_still_has_no_json_form() {
    let mut map = BTreeMap::new();
    map.insert("$bytes".to_owned(), Value::String("AAEC".into()));
    assert!(to_json(&Value::Object(map)).is_err());
}

// --- JSON depth -------------------------------------------------------------

fn nested(depth: usize) -> Vec<u8> {
    let mut json = "{\"p\":".repeat(depth - 1);
    json.push_str("{}");
    json.push_str(&"}".repeat(depth - 1));
    json.into_bytes()
}

#[test]
fn json_nesting_up_to_the_cap_decodes_on_every_path() {
    let json = nested(64);
    from_json::<Value>(&json).unwrap();
    from_json_strict::<Value>(&json).unwrap();
    Value::from_json_data_model(&json).unwrap();
}

#[test]
fn json_nesting_beyond_the_cap_is_refused_on_every_path() {
    // The cap bounds typed-decode recursion so hostile nesting returns an
    // error instead of overflowing the stack.
    let json = nested(65);
    assert!(Value::from_json_data_model(&json).is_err());
    assert!(from_json::<Value>(&json).is_err());
    assert!(from_json_strict::<Value>(&json).is_err());
}

// --- nested $type -----------------------------------------------------------

#[test]
fn an_object_reader_can_keep_the_type_tag_for_re_encoding() {
    let raw: Value = from_json(br#"{"$type":"app.bsky.richtext.facet","n":1}"#).unwrap();
    let mut reader = ObjectReader::new(raw.clone()).unwrap();
    let n: i64 = reader.required("n").unwrap();
    let extra = reader.finish_preserving_type();
    let mut writer = ObjectWriter::new();
    writer.field("n", &n).unwrap();
    writer.extra(extra.as_ref());
    assert_eq!(writer.finish(), raw);

    // Absent stays absent.
    let raw: Value = from_json(br#"{"n":1}"#).unwrap();
    let mut reader = ObjectReader::new(raw).unwrap();
    let _: i64 = reader.required("n").unwrap();
    assert!(reader.finish_preserving_type().is_none());
}
