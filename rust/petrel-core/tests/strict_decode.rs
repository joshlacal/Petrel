//! Strict decoding (XRPC inputs): a malformed optional field is an error, and
//! the strictness reaches every object nested below the one being read.

use std::collections::BTreeMap;

use petrel_core::{
    Bytes, DecodeError, FromValue, Nullable, ObjectReader, Value, XrpcInput, dagcbor,
    from_dag_cbor, from_dag_cbor_strict, from_json, from_json_strict,
    serde_bridge::from_dag_cbor_with_strict, to_dag_cbor,
};

fn parse(json: &str) -> Value {
    from_json(json.as_bytes()).unwrap()
}

/// What a generated object looks like: one body, two entry points.
#[derive(Debug, PartialEq)]
struct Leaf {
    note: Option<i64>,
    extra: Option<BTreeMap<String, Value>>,
}

impl Leaf {
    fn decode(mut reader: ObjectReader) -> Result<Self, DecodeError> {
        Ok(Self {
            note: reader.optional("note")?,
            extra: reader.finish(),
        })
    }
}

impl FromValue for Leaf {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        Self::decode(ObjectReader::new(value)?)
    }

    fn from_value_strict(value: Value) -> Result<Self, DecodeError> {
        Self::decode(ObjectReader::new_strict(value)?)
    }
}

/// One field per way a nested object can be reached.
#[derive(Debug, PartialEq)]
struct Parent {
    required: Option<Leaf>,
    optional: Option<Leaf>,
    required_nullable: Option<Leaf>,
    tri_state: Option<Nullable<Leaf>>,
    list: Option<Vec<Leaf>>,
    boxed: Option<Box<Leaf>>,
    map: Option<BTreeMap<String, Leaf>>,
}

impl Parent {
    fn decode(mut reader: ObjectReader) -> Result<Self, DecodeError> {
        Ok(Self {
            required: Some(reader.required("required")?),
            optional: reader.optional("optional")?,
            required_nullable: reader.required_nullable("requiredNullable")?,
            tri_state: reader.optional_nullable("triState")?,
            list: reader.optional("list")?,
            boxed: reader.optional("boxed")?,
            map: reader.optional("map")?,
        })
    }
}

impl FromValue for Parent {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        Self::decode(ObjectReader::new(value)?)
    }

    fn from_value_strict(value: Value) -> Result<Self, DecodeError> {
        Self::decode(ObjectReader::new_strict(value)?)
    }
}

const BAD_LEAF: &str = r#"{"note":"not a number"}"#;

fn parent_with(field: &str, value: &str) -> Value {
    let mut fields = BTreeMap::from([
        ("required".to_owned(), parse("{}")),
        ("requiredNullable".to_owned(), Value::Null),
    ]);
    fields.insert(field.to_owned(), parse(value));
    Value::Object(fields)
}

#[test]
fn a_lenient_reader_keeps_a_malformed_optional_field_as_raw_data() {
    let mut reader = ObjectReader::new(parse(r#"{"note":"x","future":7}"#)).unwrap();
    assert_eq!(reader.optional::<i64>("note"), Ok(None));
    assert_eq!(reader.degraded().collect::<Vec<_>>(), ["note"]);
    let extra = reader.finish().unwrap();
    assert_eq!(extra["note"], Value::String("x".into()));
    assert_eq!(extra["future"], Value::Integer(7));
}

#[test]
fn a_strict_reader_rejects_a_malformed_optional_field() {
    let mut reader = ObjectReader::new_strict(parse(r#"{"note":"x"}"#)).unwrap();
    let error = reader.optional::<i64>("note").unwrap_err();
    assert!(
        matches!(&error, DecodeError::Field { field, .. } if field == "note"),
        "{error:?}"
    );
}

#[test]
fn a_strict_reader_reads_absent_and_null_like_a_lenient_one() {
    let mut reader = ObjectReader::new_strict(parse(r#"{"null":null,"future":7}"#)).unwrap();
    assert_eq!(reader.optional::<i64>("absent"), Ok(None));
    assert_eq!(reader.optional::<i64>("null"), Ok(None));
    assert_eq!(reader.finish().unwrap()["future"], Value::Integer(7));
}

#[test]
fn a_strict_reader_rejects_a_malformed_tri_state_field() {
    let mut reader =
        ObjectReader::new_strict(parse(r#"{"bad":"x","null":null,"good":3}"#)).unwrap();
    assert!(reader.optional_nullable::<i64>("bad").is_err());
    assert_eq!(reader.optional_nullable::<i64>("absent"), Ok(None));
    assert_eq!(
        reader.optional_nullable::<i64>("null"),
        Ok(Some(Nullable::Null))
    );
    assert_eq!(
        reader.optional_nullable::<i64>("good"),
        Ok(Some(Nullable::Value(3)))
    );
}

#[test]
fn strictness_reaches_an_object_nested_in_any_position() {
    let positions = [
        ("required", BAD_LEAF.to_owned()),
        ("optional", BAD_LEAF.to_owned()),
        ("requiredNullable", BAD_LEAF.to_owned()),
        ("triState", BAD_LEAF.to_owned()),
        ("list", format!("[{{}},{BAD_LEAF}]")),
        ("boxed", BAD_LEAF.to_owned()),
        ("map", format!(r#"{{"key":{BAD_LEAF}}}"#)),
    ];
    for (field, value) in positions {
        let input = parent_with(field, &value);

        // Lenient: the leaf keeps the malformed field as raw data.
        assert!(
            Parent::from_value(input.clone()).is_ok(),
            "lenient decode of `{field}` should succeed"
        );

        let error = Parent::from_value_strict(input).unwrap_err();
        let message = error.to_string();
        assert!(message.contains(field), "`{field}`: {message}");
        assert!(message.contains("note"), "`{field}`: {message}");
    }
}

#[test]
fn a_well_formed_object_decodes_the_same_either_way() {
    let input = parent_with("list", r#"[{"note":1},{"future":true}]"#);
    assert_eq!(
        Parent::from_value_strict(input.clone()),
        Parent::from_value(input)
    );
}

#[test]
fn a_type_without_a_strict_path_decodes_as_usual() {
    assert_eq!(i64::from_value_strict(Value::Integer(4)), Ok(4));
    assert!(String::from_value_strict(Value::Integer(4)).is_err());
}

#[test]
fn public_strict_json_and_dag_cbor_entry_points_reject_malformed_nested_fields() {
    let raw_json = format!(r#"{{"required":{{}},"requiredNullable":null,"optional":{BAD_LEAF}}}"#);
    assert!(from_json::<Parent>(raw_json.as_bytes()).is_ok());
    let json_err = from_json_strict::<Parent>(raw_json.as_bytes()).unwrap_err();
    assert!(json_err.to_string().contains("optional"), "{json_err}");
    assert!(json_err.to_string().contains("note"), "{json_err}");

    let value = parent_with("list", &format!("[{{}},{BAD_LEAF}]"));
    let cbor = dagcbor::encode(&value);
    assert!(from_dag_cbor::<Parent>(&cbor).is_ok());
    let cbor_err = from_dag_cbor_strict::<Parent>(&cbor).unwrap_err();
    assert!(cbor_err.to_string().contains("list"), "{cbor_err}");
    assert!(cbor_err.to_string().contains("note"), "{cbor_err}");

    let well_formed = parent_with("boxed", r#"{"note":42}"#);
    let well_formed_cbor = to_dag_cbor(&well_formed).unwrap();
    assert_eq!(
        from_dag_cbor_strict::<Parent>(&well_formed_cbor),
        from_dag_cbor::<Parent>(&well_formed_cbor)
    );
    assert_eq!(
        from_dag_cbor_with_strict::<Parent>(&well_formed_cbor, dagcbor::Limits::STANDARD),
        from_dag_cbor::<Parent>(&well_formed_cbor)
    );
}

#[test]
fn xrpc_input_from_body_for_unit_and_bytes() {
    assert_eq!(<() as XrpcInput>::from_body(b""), Ok(()));
    assert!(<() as XrpcInput>::from_body(b"{}").is_err());
    let bytes = <Bytes as XrpcInput>::from_body(b"payload").unwrap();
    assert_eq!(bytes.0, b"payload");
}
