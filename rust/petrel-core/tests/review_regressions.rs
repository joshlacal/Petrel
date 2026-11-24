//! Cases found by the review of the first integrated Rust SDK.

use std::collections::BTreeMap;

use petrel_core::{Blob, Cid, FromValue, Value, dagcbor, from_dag_cbor, to_json};

fn object(fields: impl IntoIterator<Item = (&'static str, Value)>) -> Value {
    Value::Object(
        fields
            .into_iter()
            .map(|(key, value)| (key.to_owned(), value))
            .collect::<BTreeMap<_, _>>(),
    )
}

#[test]
fn a_cbor_map_that_would_read_back_as_a_link_or_bytes_has_no_json_form() {
    let cid = Cid::for_raw(b"content").to_string();
    for (key, text) in [("$link", cid.as_str()), ("$bytes", "AAEC")] {
        // DAG-CBOR holds this as a plain map with a text value.
        let block = dagcbor::encode(&object([(key, Value::String(text.to_owned()))]));
        let decoded: Value = from_dag_cbor(&block).unwrap();
        assert!(matches!(decoded, Value::Object(_)));
        // As JSON it would come back as a link or bytes: a different value.
        assert!(to_json(&decoded).is_err(), "{key}");
    }
    // The same key next to another field is an ordinary object.
    let ordinary = object([
        ("$link", Value::String(cid.clone())),
        ("note", Value::String("x".into())),
    ]);
    assert!(to_json(&ordinary).is_ok());
}

#[test]
fn a_link_object_with_other_fields_is_not_a_cid() {
    let cid = Cid::for_raw(b"content");
    let exact = object([("$link", Value::String(cid.to_string()))]);
    assert_eq!(Cid::from_value(exact).unwrap(), cid);
    let padded = object([
        ("$link", Value::String(cid.to_string())),
        ("extra", Value::Integer(1)),
    ]);
    assert!(Cid::from_value(padded).is_err());
}

#[test]
fn a_typed_blob_requires_a_raw_codec_ref_like_record_validation_does() {
    let blob = |reference: Cid| {
        object([
            ("$type", Value::String("blob".into())),
            ("ref", Value::Link(reference)),
            ("mimeType", Value::String("image/png".into())),
            ("size", Value::Integer(7)),
        ])
    };
    assert!(Blob::from_value(blob(Cid::for_raw(b"content"))).is_ok());
    assert!(Blob::from_value(blob(Cid::for_dag_cbor(b"content"))).is_err());
}
