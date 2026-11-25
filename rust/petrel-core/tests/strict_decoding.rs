//! `strictly`: an optional field that does not decode fails the whole decode
//! at any depth, while lenient decoding keeps degrading it.

use petrel_core::{
    DecodeError, FromValue, ObjectReader, Value, from_dag_cbor_strict, from_json, from_json_strict,
    strictly, to_dag_cbor,
};

#[derive(Debug, PartialEq)]
struct Leaf {
    count: Option<i64>,
}

impl FromValue for Leaf {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        let mut reader = ObjectReader::new(value)?;
        Ok(Self {
            count: reader.optional("count"),
        })
    }
}

#[derive(Debug, PartialEq)]
struct Branch {
    leaf: Leaf,
    leaves: Option<Vec<Leaf>>,
}

impl FromValue for Branch {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        let mut reader = ObjectReader::new(value)?;
        Ok(Self {
            leaf: reader.required("leaf")?,
            leaves: reader.optional("leaves"),
        })
    }
}

/// A type whose own decode is strict, as a generated XRPC input's is.
#[derive(Debug, PartialEq)]
struct Input {
    branch: Branch,
}

impl FromValue for Input {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        strictly(|| {
            let mut reader = ObjectReader::new(value)?;
            Ok(Self {
                branch: reader.required("branch")?,
            })
        })
    }
}

const NESTED_BAD: &[u8] = br#"{"leaf":{"count":"seven"}}"#;
const DEEP_BAD: &[u8] = br#"{"branch":{"leaf":{"count":1},"leaves":[{"count":2},{"count":"x"}]}}"#;

fn path(error: &DecodeError) -> Vec<String> {
    let mut fields = Vec::new();
    let mut current = error;
    while let DecodeError::Field { field, source } = current {
        fields.push(field.clone());
        current = source;
    }
    fields
}

#[test]
fn lenient_decoding_still_degrades_a_nested_optional_field() {
    let branch: Branch = from_json(NESTED_BAD).unwrap();
    assert_eq!(branch.leaf, Leaf { count: None });
}

#[test]
fn strict_decoding_rejects_a_nested_optional_field_with_its_path() {
    let error = from_json_strict::<Branch>(NESTED_BAD).unwrap_err();
    assert_eq!(path(&error), ["leaf", "count"]);
}

#[test]
fn a_degraded_field_inside_an_array_item_rejects_the_whole_strict_decode() {
    const BAD_ITEM: &[u8] = br#"{"leaf":{},"leaves":[{"count":2},{"count":"x"}]}"#;
    let branch: Branch = from_json(BAD_ITEM).unwrap();
    assert_eq!(
        branch.leaves,
        Some(vec![Leaf { count: Some(2) }, Leaf { count: None }])
    );

    let error = from_json_strict::<Branch>(BAD_ITEM).unwrap_err();
    assert_eq!(path(&error), ["leaves", "count"]);
}

#[test]
fn a_type_that_decodes_strictly_is_strict_wherever_it_is_decoded() {
    // Through the lenient entry points too: the input's own decode is strict.
    let error = from_json::<Input>(DEEP_BAD).unwrap_err();
    assert_eq!(path(&error), ["branch", "leaves", "count"]);

    let ok: Input = from_json(br#"{"branch":{"leaf":{"count":1}}}"#).unwrap();
    assert_eq!(ok.branch.leaf.count, Some(1));
}

#[test]
fn strict_decoding_keeps_unknown_fields_and_valid_data() {
    let branch: Branch =
        from_json_strict(br#"{"leaf":{"count":3,"extra":true},"leaves":[],"more":1}"#).unwrap();
    assert_eq!(branch.leaf.count, Some(3));
    assert_eq!(branch.leaves, Some(Vec::new()));
}

#[test]
fn strict_decoding_applies_to_dag_cbor() {
    let value: Value = serde_json::from_slice(NESTED_BAD).unwrap();
    let bytes = to_dag_cbor(&value).unwrap();
    assert!(from_dag_cbor_strict::<Branch>(&bytes).is_err());
}

#[test]
fn a_strict_decode_leaves_no_state_behind() {
    assert!(from_json_strict::<Branch>(NESTED_BAD).is_err());
    // The next lenient decode on this thread degrades as usual.
    let branch: Branch = from_json(NESTED_BAD).unwrap();
    assert_eq!(branch.leaf.count, None);
    // And the next strict one reports its own error, not a stale one.
    let error = from_json_strict::<Branch>(br#"{"leaf":{},"leaves":[{"count":"y"}]}"#).unwrap_err();
    assert_eq!(path(&error), ["leaves", "count"]);
}

#[test]
fn a_panic_inside_a_strict_decode_does_not_leave_it_strict() {
    let caught = std::panic::catch_unwind(|| {
        strictly(|| -> Result<(), DecodeError> {
            let _ = from_json::<Branch>(NESTED_BAD);
            panic!("decoder panicked");
        })
    });
    assert!(caught.is_err());
    let branch: Branch = from_json(NESTED_BAD).unwrap();
    assert_eq!(branch.leaf.count, None);
}

#[test]
fn strict_decoding_refuses_null_in_a_field_that_is_not_nullable() {
    let leaf: Leaf = from_json(br#"{"count":null}"#).unwrap();
    assert_eq!(leaf.count, None);

    let error = from_json_strict::<Branch>(br#"{"leaf":{"count":null}}"#).unwrap_err();
    assert_eq!(path(&error), ["leaf", "count"]);
}
