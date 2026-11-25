use base64::Engine as _;
use base64::engine::general_purpose::{STANDARD, STANDARD_NO_PAD};
use petrel_core::serde_bridge::cid_of;
use petrel_core::unknown::{self, TypedValue};
use petrel_core::{
    Blob, Bytes, Cid, CidLink, CidString, DagCborError, DecodeError, EncodeError, FromValue,
    ObjectReader, ObjectWriter, ToValue, Value, dagcbor, from_dag_cbor, from_json, to_dag_cbor,
    to_json,
};
use serde::Deserialize;
use serde_json::value::RawValue;

#[derive(Deserialize)]
struct Fixture<'a> {
    #[serde(borrow)]
    json: &'a RawValue,
    cbor_base64: &'a str,
    cid: &'a str,
}

#[derive(Deserialize)]
struct Case<'a> {
    note: &'a str,
    #[serde(borrow)]
    json: &'a RawValue,
}

macro_rules! vectors {
    ($name:literal) => {
        include_bytes!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../Tests/PetrelRepoTests/Vectors/data-model/",
            $name,
        ))
    };
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn official_fixtures_match_bytes_and_cids() {
    let fixtures: Vec<Fixture<'_>> =
        serde_json::from_slice(vectors!("data-model-fixtures.json")).unwrap();
    assert_eq!(fixtures.len(), 3);
    for (index, fixture) in fixtures.into_iter().enumerate() {
        let value = Value::from_json_data_model(fixture.json.get().as_bytes()).unwrap();
        let expected = STANDARD_NO_PAD.decode(fixture.cbor_base64).unwrap();
        assert_eq!(dagcbor::encode(&value), expected, "fixture {index}");
        assert_eq!(value.cid().to_string(), fixture.cid, "fixture {index}");
        assert!(
            Cid::parse_blessed(fixture.cid)
                .unwrap()
                .matches_content(&expected)
        );
        assert_eq!(
            dagcbor::decode(&expected).unwrap(),
            value,
            "fixture {index}"
        );
        assert_eq!(
            Value::from_json_data_model(&to_json(&value).unwrap()).unwrap(),
            value,
            "fixture {index}",
        );
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn official_valid_values_round_trip() {
    let cases: Vec<Case<'_>> = serde_json::from_slice(vectors!("data-model-valid.json")).unwrap();
    assert_eq!(cases.len(), 5);
    for case in cases {
        let text = case.json.get();
        let value = Value::from_json_data_model(text.as_bytes())
            .unwrap_or_else(|error| panic!("{}: {error}", case.note));
        if case.note == "float, but integer-like" {
            assert!(text.contains("123.0"));
            let record = value.as_object().unwrap()["rcrd"].as_object().unwrap();
            assert_eq!(record["a"], Value::Integer(123));
        }
        let bytes = dagcbor::encode(&value);
        assert_eq!(dagcbor::decode(&bytes).unwrap(), value, "{}", case.note);
        assert!(value.as_object().is_some(), "{}", case.note);
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn official_invalid_values_are_refused_for_the_expected_reason() {
    let cases: Vec<Case<'_>> = serde_json::from_slice(vectors!("data-model-invalid.json")).unwrap();
    assert_eq!(cases.len(), 12);
    for case in cases {
        let json = case.json.get().as_bytes();
        let error = if case.note == "top-level not an object" {
            Value::from_json_record(json).unwrap_err()
        } else {
            Value::from_json_data_model(json).unwrap_err()
        };
        let expected_reason = match case.note {
            "top-level not an object" => matches!(error, DecodeError::NotARecord),
            "float" => matches!(error, DecodeError::NonInteger),
            "record with $type null"
            | "record with $type wrong type"
            | "record with empty $type string" => matches!(error, DecodeError::InvalidType),
            "blob with string size" | "blob with missing key" => {
                matches!(error, DecodeError::MalformedBlob(_))
            }
            "bytes with wrong field type" | "bytes with extra fields" => {
                matches!(error, DecodeError::MalformedBytes)
            }
            "link with wrong field type" | "link with extra fields" => {
                matches!(error, DecodeError::MalformedLink)
            }
            "link with bogus CID" => matches!(error, DecodeError::Cid(_)),
            other => panic!("no expected error for {other}"),
        };
        assert!(expected_reason, "{}: {error}", case.note);
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn exact_decimal_integers_and_malformed_json() {
    let exact = [
        ("123.0", 123),
        ("1e3", 1_000),
        ("-0.0", 0),
        ("0e-9999", 0),
        ("0.000e99999999999999999999", 0),
        ("1.50e1", 15),
        ("12300e-2", 123),
        ("9007199254740993.0", 9_007_199_254_740_993),
        ("9.223372036854775807e18", i64::MAX),
        ("-9.223372036854775808e18", i64::MIN),
    ];
    for (json, integer) in exact {
        assert_eq!(
            Value::from_json_data_model(json.as_bytes()),
            Ok(Value::Integer(integer)),
            "{json}"
        );
    }
    for json in [
        "123.456",
        "1e-1",
        "1e400",
        "0.1",
        "1.00000000000000001",
        "9007199254740990.5",
        "1e-9999",
        "-1e-9999",
        "12345678901234567.25e1",
        "1e-99999999999999999999",
        "9.223372036854775808e18",
        "1e19",
        "1e99999999999999999999",
        "9223372036854775808",
        "-9223372036854775809",
    ] {
        assert_eq!(
            Value::from_json_data_model(json.as_bytes()),
            Err(DecodeError::NonInteger),
            "{json}"
        );
    }
    for json in [
        "",
        "{",
        "[1,]",
        r#"{"a":1,}"#,
        "01",
        "1 2",
        "nul",
        "\"unterminated",
        r#""bad \x escape""#,
        r#""lone \ud800 surrogate""#,
        r#"{"a" 1}"#,
        "[1 2]",
        "+1",
        ".5",
    ] {
        assert!(
            matches!(
                Value::from_json_data_model(json.as_bytes()),
                Err(DecodeError::Json(_))
            ),
            "{json}"
        );
    }
    assert_eq!(
        Value::from_json_data_model(br#"{"a":1,"\u0061":2}"#),
        Err(DecodeError::DuplicateKey("a".into())),
    );
    let nested = |depth| format!("{}1{}", "[".repeat(depth), "]".repeat(depth));
    assert!(Value::from_json_data_model(nested(64).as_bytes()).is_ok());
    assert_eq!(
        Value::from_json_data_model(nested(65).as_bytes()),
        Err(DecodeError::JsonDepthExceeded(64)),
    );
    assert!(from_json::<Value>(nested(64).as_bytes()).is_ok());
    assert!(from_json::<Value>(nested(65).as_bytes()).is_err());
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn malformed_dag_cbor_is_refused() {
    let malformed: &[(&str, &[u8])] = &[
        ("float16", &[0xf9, 0x3c, 0]),
        ("float32", &[0xfa, 0x3f, 0x80, 0, 0]),
        ("float64", &[0xfb, 0x3f, 0xf0, 0, 0, 0, 0, 0, 0]),
        ("undefined", &[0xf7]),
        ("simple(16)", &[0xf0]),
        ("indefinite array", &[0x9f, 0x01, 0xff]),
        ("indefinite map", &[0xbf, 0x61, b'a', 0x01, 0xff]),
        ("indefinite bytes", &[0x5f, 0x41, 0, 0xff]),
        ("indefinite text", &[0x7f, 0x61, b'a', 0xff]),
        ("non-minimal u8", &[0x18, 0x01]),
        ("non-minimal u16", &[0x19, 0, 0xff]),
        ("non-minimal u32", &[0x1a, 0, 0, 0xff, 0xff]),
        (
            "non-minimal u64",
            &[0x1b, 0, 0, 0, 0, 0xff, 0xff, 0xff, 0xff],
        ),
        ("non-minimal negative", &[0x38, 0]),
        ("non-minimal text length", &[0x78, 1, b'a']),
        ("non-minimal array length", &[0x98, 0]),
        ("non-minimal map length", &[0xb8, 1, 0x61, b'a', 1]),
        ("non-minimal tag", &[0xd9, 0, 0x2a, 0x41, 0]),
        (
            "keys out of byte order",
            &[0xa2, 0x61, b'b', 1, 0x61, b'a', 2],
        ),
        (
            "keys out of length order",
            &[0xa2, 0x62, b'a', b'a', 1, 0x61, b'b', 2],
        ),
        ("duplicate key", &[0xa2, 0x61, b'a', 1, 0x61, b'a', 2]),
        ("integer key", &[0xa1, 1, 1]),
        ("byte string key", &[0xa1, 0x41, b'a', 1]),
        ("tag 1", &[0xc1, 1]),
        ("tag 43", &[0xd8, 0x2b, 0x41, 0]),
        ("tag 42 over text", &[0xd8, 0x2a, 0x61, b'a']),
        ("tag 42 over integer", &[0xd8, 0x2a, 1]),
        (
            "tag 42 without prefix",
            &[0xd8, 0x2a, 0x45, 1, 0x71, 0x12, 1, 7],
        ),
        ("tag 42 containing only the prefix", &[0xd8, 0x2a, 0x41, 0]),
        (
            "tag 42 truncated CID",
            &[0xd8, 0x2a, 0x45, 0, 1, 0x71, 0x12, 0x20],
        ),
        (
            "tag 42 malformed CID",
            &[0xd8, 0x2a, 0x45, 0, 0xff, 0xff, 0xff, 0xff],
        ),
        ("trailing byte", &[1, 0]),
        ("truncated value", &[0xa1, 0x61, b'a']),
        ("truncated text", &[0x65, b'a']),
        ("invalid UTF-8", &[0x62, 0xc3, 0x28]),
        ("invalid UTF-8 key", &[0xa1, 0x62, 0xc3, 0x28, 1]),
        ("above i64 max", &[0x1b, 0x80, 0, 0, 0, 0, 0, 0, 0]),
        ("below i64 min", &[0x3b, 0x80, 0, 0, 0, 0, 0, 0, 0]),
        ("empty input", &[]),
    ];
    for (case, bytes) in malformed {
        assert!(dagcbor::decode(bytes).is_err(), "{case}");
    }
    for number in [i64::MIN, -1, 0, 9_007_199_254_740_992, i64::MAX] {
        let value = Value::Integer(number);
        assert_eq!(dagcbor::decode(&dagcbor::encode(&value)), Ok(value));
    }
    assert_eq!(
        Value::from_dag_cbor_record(&[0x81, 1]),
        Err(DecodeError::NotARecord)
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn dag_cbor_limits_and_canonical_order() {
    let limits = dagcbor::Limits::STANDARD;
    let at_limit = Value::Array(vec![Value::Null; limits.max_nodes - 1]);
    assert_eq!(dagcbor::decode(&dagcbor::encode(&at_limit)), Ok(at_limit));
    let above_limit = Value::Array(vec![Value::Null; limits.max_nodes]);
    let bytes = dagcbor::encode(&above_limit);
    assert_eq!(
        dagcbor::decode(&bytes),
        Err(DagCborError::NodeLimitExceeded(limits.max_nodes))
    );
    assert_eq!(
        dagcbor::decode_with(&bytes, dagcbor::Limits::REPOSITORY_BLOCK),
        Ok(above_limit)
    );

    let mut custom = limits;
    custom.max_container_elements = 2;
    assert_eq!(
        dagcbor::decode_with(&[0x83, 1, 2, 3], custom),
        Err(DagCborError::ContainerLimitExceeded(2)),
    );
    let nested = |depth| {
        let mut bytes = vec![0x81; depth];
        bytes.push(0xf6);
        bytes
    };
    assert!(dagcbor::decode(&nested(limits.max_depth)).is_ok());
    assert_eq!(
        dagcbor::decode(&nested(limits.max_depth + 1)),
        Err(DagCborError::DepthExceeded(limits.max_depth)),
    );

    // Rust string keys preserve byte-distinct spellings. Length-first ordering
    // sorts the two-byte composed spelling before the three-byte decomposed one.
    let distinct = [0xa2, 0x62, 0xc3, 0xa9, 1, 0x63, b'e', 0xcc, 0x81, 2];
    let parsed = dagcbor::decode(&distinct).unwrap();
    assert_eq!(parsed.as_object().unwrap().len(), 2);
    assert_eq!(dagcbor::encode(&parsed), distinct);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn base64_round_trips_all_bytes_and_refuses_malformed_padding() {
    for length in [0, 256, 257, 258] {
        let mut all = (0..=u8::MAX).collect::<Vec<_>>();
        all.resize(length, 0xff);
        for encoded in [STANDARD.encode(&all), STANDARD_NO_PAD.encode(&all)] {
            let wire = serde_json::to_vec(&serde_json::json!({"$bytes": encoded})).unwrap();
            assert_eq!(from_json::<Bytes>(&wire).unwrap().0, all);
        }
        let json = to_json(&Bytes(all.clone())).unwrap();
        let encoded: serde_json::Value = serde_json::from_slice(&json).unwrap();
        assert_eq!(encoded["$bytes"], STANDARD_NO_PAD.encode(&all));
    }
    assert_eq!(
        from_json::<Bytes>(br#"{"$bytes":"123"}"#).unwrap().0,
        [0xd7, 0x6d]
    );
    for encoded in [
        "AAAé", "AAAＡ", "AAA🙂", "A", "AA=", "AA===", "AA=A", "=AAA", "A=AA", "====", "AAAA=",
    ] {
        let wire = serde_json::to_vec(&serde_json::json!({"$bytes": encoded})).unwrap();
        assert!(from_json::<Bytes>(&wire).is_err(), "{encoded}");
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn cid_v1_varints_and_blessed_link_boundaries() {
    let mut binary = vec![1, 0xa9, 0x02, 0x12, 0x20];
    binary.extend([7; 32]);
    let alternate = Cid::from_bytes(&binary).unwrap();
    assert_eq!(alternate.codec(), 0x129);
    assert_eq!(alternate.hash_code(), 0x12);
    assert_eq!(alternate.digest(), &[7; 32]);
    assert_eq!(Cid::parse(&alternate.to_string()).unwrap(), alternate);
    assert!(!alternate.is_blessed());
    assert!(Cid::parse_blessed(&alternate.to_string()).is_err());
    assert!(CidLink::new(alternate.clone()).is_err());
    let dag = dagcbor::encode(&Value::Link(alternate.clone()));
    assert_eq!(dagcbor::decode(&dag).unwrap(), Value::Link(alternate));
    assert!(petrel_core::from_dag_cbor::<CidLink>(&dag).is_err());

    for bytes in [
        &[0x81, 0, 0x71, 0x12, 1, 7][..],
        &[1, 0xf1, 0, 0x12, 1, 7],
        &[1, 0x71, 0x92, 0, 1, 7],
        &[1, 0x71, 0x12, 0x81, 0, 7],
        &[1, 0x71, 0x12, 1, 7, 8],
        &[1, 0x71, 0x12, 0],
    ] {
        assert!(Cid::from_bytes(bytes).is_err(), "{bytes:02x?}");
    }
    let cid = Cid::for_raw(b"input");
    assert!(cid.matches_content(b"input"));
    assert!(!cid.matches_content(b"else"));
    let text = cid.to_string();
    assert_ne!(text, text.to_uppercase());
    assert!(Cid::parse(&text.to_uppercase()).is_err());
    assert!(Cid::parse(&format!("{text}a")).is_err());
    let final_byte = text.as_bytes()[text.len() - 1];
    let alphabet = b"abcdefghijklmnopqrstuvwxyz234567";
    let index = alphabet
        .iter()
        .position(|&byte| byte == final_byte)
        .unwrap();
    let noncanonical = format!(
        "{}{}",
        &text[..text.len() - 1],
        char::from(alphabet[index + 1])
    );
    assert!(Cid::parse(&noncanonical).is_err());
}

#[cfg(feature = "ipld-interop")]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn converts_cid_crate_values_without_changing_binary_links() {
    let local = Cid::from_bytes(&[1, 0xa9, 0x02, 0x90, 0x02, 2, 1, 2]).unwrap();
    let external = ::cid::Cid::from(local.clone());
    assert_eq!(external.codec(), 0x129);
    assert_eq!(external.hash().code(), 0x110);
    assert_eq!(external.to_bytes(), local.as_bytes());
    assert_eq!(Cid::try_from(external).unwrap(), local);

    let blessed = ::cid::Cid::from(Cid::for_dag_cbor(b"CIDv1 only"));
    let v0 = ::cid::Cid::new_v0(*blessed.hash()).unwrap();
    assert!(Cid::try_from(v0).is_err());
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn typed_values_preserve_cid_strings_links_bytes_and_blobs() {
    let raw = Cid::for_raw(b"blob");
    let text: CidString = raw.to_string().parse().unwrap();
    assert_eq!(text.cid().as_ref(), Some(&raw));
    let link = CidLink::new(raw).unwrap();
    let bytes = Bytes(vec![1, 2, 3]);
    let blob = Blob::TypedWithCid {
        r#ref: link.clone(),
        mime_type: "image/png".into(),
        size: 4,
        cid: text.as_str().into(),
    };
    let mut object = ObjectWriter::new();
    object.field("cid", &text).unwrap();
    object.field("link", &link).unwrap();
    object.field("bytes", &bytes).unwrap();
    object.field("blob", &blob).unwrap();

    let value = object.finish();
    let encoded = to_dag_cbor(&value).unwrap();
    let decoded = dagcbor::decode(&encoded).unwrap();
    assert_eq!(
        decoded.as_object().unwrap()["cid"],
        Value::String(text.as_str().into())
    );
    assert_eq!(
        decoded.as_object().unwrap()["link"],
        link.to_value().unwrap()
    );
    assert_eq!(
        decoded.as_object().unwrap()["bytes"],
        Value::Bytes(vec![1, 2, 3])
    );
    assert_eq!(cid_of(&value).unwrap(), Cid::for_dag_cbor(&encoded));

    let mut reader = ObjectReader::new(decoded).unwrap();
    assert_eq!(reader.required("cid"), Ok(text));
    assert_eq!(reader.required("link"), Ok(link));
    assert_eq!(reader.required("bytes"), Ok(bytes));
    assert_eq!(reader.required("blob"), Ok(blob));
    assert_eq!(reader.finish_strict(), Ok(None));
    assert!(
        from_json::<Blob>(br#"{"cid":"legacy","mimeType":"image/png"}"#)
            .unwrap()
            .is_legacy()
    );
    assert!(from_json::<Blob>(br#"{"$type":null,"cid":"legacy","mimeType":"image/png"}"#).is_err());
    let legacy = br#"{"cid":"legacy","mimeType":"image/png"}"#;
    let blob: Blob = from_json(legacy).unwrap();
    let decoded: Blob = from_dag_cbor(&to_dag_cbor(&blob).unwrap()).unwrap();
    assert_eq!(to_json(&decoded).unwrap(), legacy);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn bare_cid_accepts_link_form_but_serializes_as_string() {
    let cid = Cid::for_dag_cbor(b"record");
    let json = serde_json::to_vec(&cid.to_string()).unwrap();
    let link = serde_json::to_vec(&serde_json::json!({"$link": cid.to_string()})).unwrap();
    assert_eq!(serde_json::from_slice::<Cid>(&json).unwrap(), cid);
    assert_eq!(serde_json::from_slice::<Cid>(&link).unwrap(), cid);
    assert_eq!(serde_json::to_vec(&cid).unwrap(), json);
    assert!(serde_json::from_str::<Cid>(r#""bgarbage""#).is_err());

    let cbor = to_dag_cbor(&cid).unwrap();
    assert_eq!(
        dagcbor::decode(&cbor).unwrap(),
        Value::String(cid.to_string())
    );
    assert_eq!(from_dag_cbor::<Cid>(&cbor).unwrap(), cid);
}

#[derive(Debug, PartialEq, Eq)]
struct Label(String);

impl FromValue for Label {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        let mut reader = ObjectReader::new(value)?;
        Ok(Self(reader.required("name")?))
    }
}

impl ToValue for Label {
    fn to_value(&self) -> Result<Value, EncodeError> {
        let mut writer = ObjectWriter::new();
        writer.field("name", &self.0)?;
        Ok(writer.finish())
    }
}

impl TypedValue for Label {
    const NSID: &'static str = "com.example.label";
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn dynamic_decoding_preserves_unknown_values_and_guards_projection() {
    let parse = |json: &str| from_json::<Value>(json.as_bytes()).unwrap();
    let accepted = parse(r#"{"$type":"com.example.label","name":"x","nullField":null}"#);
    let typed: Label = unknown::decode_typed(&accepted).unwrap();
    assert_eq!(typed, Label("x".into()));
    assert_eq!(
        unknown::type_of(&unknown::encode_typed(&typed).unwrap()),
        Ok(Label::NSID)
    );

    let unexpected_type = parse(r#"{"$type":"com.example.other","name":"x"}"#);
    assert!(matches!(
        unknown::decode_typed::<Label>(&unexpected_type),
        Err(DecodeError::TypeIdMismatch { .. })
    ));
    assert!(unknown::tagged(unexpected_type, Label::NSID).is_err());
    assert_eq!(
        unknown::type_of(&parse(r#"{"$type":""}"#)),
        Err(DecodeError::InvalidType)
    );

    let unknown_field = parse(r#"{"name":"x","future":{"example":[false,{"$bytes":"AA"}]}}"#);
    assert_eq!(
        unknown::decode_as::<Label>(&unknown_field),
        Err(DecodeError::LossyProjection)
    );
    assert_eq!(
        dagcbor::decode(&dagcbor::encode(&unknown_field)),
        Ok(unknown_field)
    );
    let lookalike = parse(r#"{"$link":"invalid","field":true}"#);
    assert!(matches!(lookalike, Value::Object(_)));
    assert!(from_json::<Value>(br#"{"$link":"invalid"}"#).is_err());

    let mut reader = ObjectReader::new(parse(r#"{"bad":"none","future":7}"#)).unwrap();
    assert_eq!(reader.optional::<i64>("bad"), Ok(None));
    assert_eq!(reader.degraded().collect::<Vec<_>>(), ["bad"]);
    assert_eq!(
        reader.finish_strict(),
        Err(DecodeError::DegradedField("bad".into()))
    );
}

#[test]
fn successful_decodes_of_mutated_dag_cbor_reencode_identically() {
    let fixtures: Vec<Fixture<'_>> =
        serde_json::from_slice(vectors!("data-model-fixtures.json")).unwrap();
    let assert_canonical_if_accepted = |bytes: &[u8]| {
        if let Ok(value) = dagcbor::decode(bytes) {
            assert_eq!(dagcbor::encode(&value), bytes);
        }
    };
    for fixture in fixtures {
        let mut bytes = STANDARD_NO_PAD.decode(fixture.cbor_base64).unwrap();
        for prefix in 0..=bytes.len() {
            assert_canonical_if_accepted(&bytes[..prefix]);
        }
        for index in 0..bytes.len() {
            let original = bytes[index];
            for bit in 0..8 {
                bytes[index] = original ^ (1 << bit);
                assert_canonical_if_accepted(&bytes);
            }
            bytes[index] = original;
        }
    }
}
