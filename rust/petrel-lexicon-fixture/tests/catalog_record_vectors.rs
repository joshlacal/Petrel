//! The official `atproto-interop-tests/lexicon` record vectors, read through
//! the Rust type the generator produces for the catalog Lexicon
//! `example.lexicon.record`. The Swift twin is
//! `Tests/PetrelLexiconFixtureTests/CatalogRecordVectorTests.swift`.
//!
//! A generated type enforces the *shape* of data: field types, required and
//! nullable fields, string formats, union membership. Value *constraints*
//! (lengths, ranges, enums of integers, `const`, blob size and MIME type) are
//! schema metadata it does not carry. This suite pins exactly where that line
//! is, under strict decoding, and that lenient decoding (how a client reads
//! records it did not write) accepts every vector it can still represent.
//!
//! One deviation from the files: their blob refs are DRISL (`dag-cbor`) CIDs,
//! and the data-model spec requires a blob ref to use the `raw` codec. Petrel
//! follows the spec, as the interop repository's README says implementations
//! should when the two disagree, so the suite reads each vector with its blob
//! refs moved to the `raw` CID of the same digest, and pins the as-written
//! form separately.

use std::collections::BTreeSet;

use petrel_core::{DecodeError, FromValue, Value, from_json, to_dag_cbor, to_json};

/// Decodes `json` the way an XRPC input is decoded: a malformed optional
/// field anywhere inside it is an error.
fn from_json_strict<T: FromValue>(json: &[u8]) -> Result<T, DecodeError> {
    T::from_value_strict(from_json::<Value>(json)?)
}

use petrel_lexicon_fixture::generated::example::lexicon::record::Record;

struct Vector {
    name: String,
    /// The record exactly as the vector file spells it.
    as_written: Vec<u8>,
    /// The record with its blob refs in the `raw` codec the spec requires.
    json: Vec<u8>,
}

/// The vectors' blob ref, a DRISL CID, and the `raw` CID of the same digest.
const DRISL_BLOB_REF: &str = "bafyreiclp443lavogvhj3d2ob2cxbfuscni2k5jk7bebjzg7khl3esabwq";
const RAW_BLOB_REF: &str = "bafkreiclp443lavogvhj3d2ob2cxbfuscni2k5jk7bebjzg7khl3esabwq";

/// Moves every blob ref in `value` from [`DRISL_BLOB_REF`] to [`RAW_BLOB_REF`].
/// Only `{"$type": "blob"}` objects change: a `cid-link` may name DRISL data.
fn with_raw_blob_refs(value: &mut serde_json::Value) -> usize {
    match value {
        serde_json::Value::Object(map) => {
            let mut moved = 0;
            if map.get("$type").and_then(serde_json::Value::as_str) == Some("blob")
                && let Some(link) = map.get_mut("ref").and_then(|r| r.get_mut("$link"))
                && link == DRISL_BLOB_REF
            {
                *link = RAW_BLOB_REF.into();
                moved += 1;
            }
            moved + map.values_mut().map(with_raw_blob_refs).sum::<usize>()
        }
        serde_json::Value::Array(items) => items.iter_mut().map(with_raw_blob_refs).sum(),
        _ => 0,
    }
}

fn vectors(file: &str) -> Vec<Vector> {
    let path = format!(
        "{}/../../Tests/PetrelLexiconFixtureTests/Vectors/lexicon/{file}.json",
        env!("CARGO_MANIFEST_DIR")
    );
    let entries: Vec<serde_json::Value> =
        serde_json::from_slice(&std::fs::read(&path).unwrap()).unwrap();
    entries
        .into_iter()
        .map(|entry| {
            let mut data = entry["data"].clone();
            with_raw_blob_refs(&mut data);
            Vector {
                name: entry["name"].as_str().unwrap().to_owned(),
                as_written: serde_json::to_vec(&entry["data"]).unwrap(),
                json: serde_json::to_vec(&data).unwrap(),
            }
        })
        .collect()
}

/// Invalid vectors whose only fault is a value constraint. Structurally they
/// are valid instances of the generated type. The same set as the Swift suite.
const CONSTRAINT_ONLY: &[&str] = &[
    "wrong const value",
    "integer not in enum",
    // A string `enum` decodes forward-compatibly: a value a newer peer added
    // is kept verbatim in the enum's `Unknown` arm, as Jacquard does.
    "out of enum string",
    "out of integer range",
    "string too short",
    "string too long",
    "string too short (graphemes)",
    "string too long (graphemes)",
    "bytes too short",
    "bytes too long",
    "array too short",
    "array too long",
    "blob too large",
    "blob wrong type",
];

/// Structurally invalid, yet accepted by a strict decode: `null` in an
/// optional field that is not nullable. Petrel reads it as absent in an input
/// as well as in a record, so this is a known gap against the vectors, pinned
/// here so that closing it is a deliberate change.
const NULL_IN_A_NON_NULLABLE_FIELD: &str = "invalid non-nullable string field";

#[test]
fn every_valid_record_vector_decodes_strictly_and_reencodes_to_the_same_data() {
    let vectors = vectors("record-data-valid");
    assert_eq!(vectors.len(), 3);

    for vector in &vectors {
        let record: Record = from_json_strict(&vector.json)
            .unwrap_or_else(|error| panic!("vector '{}': {error}", vector.name));
        // `Value` reads `$bytes` and `$link`, so two spellings of the same
        // bytes compare equal: the vectors write `"$bytes": "123"`, which is
        // not the canonical base64 of the bytes it denotes.
        let original: Value = serde_json::from_slice(&vector.json).unwrap();
        let reencoded: Value = serde_json::from_slice(&to_json(&record).unwrap()).unwrap();
        assert_eq!(
            reencoded, original,
            "vector '{}' changed in a round trip",
            vector.name
        );
        assert_eq!(
            to_dag_cbor(&record).unwrap(),
            to_dag_cbor(&original).unwrap(),
            "vector '{}' changed its DAG-CBOR encoding",
            vector.name
        );
    }
}

#[test]
fn every_structurally_invalid_record_vector_is_rejected_by_a_strict_decode() {
    let vectors = vectors("record-data-invalid");
    assert_eq!(vectors.len(), 50);
    let names: BTreeSet<&str> = vectors.iter().map(|vector| vector.name.as_str()).collect();
    let constraint_only: BTreeSet<&str> = CONSTRAINT_ONLY.iter().copied().collect();
    assert!(constraint_only.is_subset(&names));

    let accepted: BTreeSet<&str> = vectors
        .iter()
        .filter(|vector| from_json_strict::<Record>(&vector.json).is_ok())
        .map(|vector| vector.name.as_str())
        .collect();

    assert!(accepted.contains(NULL_IN_A_NON_NULLABLE_FIELD));
    let mut known_accepted = constraint_only.clone();
    known_accepted.insert(NULL_IN_A_NON_NULLABLE_FIELD);
    let unexpectedly_accepted: Vec<_> = accepted.difference(&known_accepted).collect();
    assert!(
        unexpectedly_accepted.is_empty(),
        "structurally invalid but accepted: {unexpectedly_accepted:?}"
    );
    let unexpectedly_rejected: Vec<_> = constraint_only.difference(&accepted).collect();
    assert!(
        unexpectedly_rejected.is_empty(),
        "only a constraint is violated but rejected: {unexpectedly_rejected:?}"
    );
}

#[test]
fn a_lenient_decode_keeps_every_invalid_optional_field_as_written() {
    // Leniently, only a fault in a required field fails the record. Every
    // other invalid vector decodes, and the field that did not fit is kept
    // raw, so re-encoding reproduces the record and its CID.
    for vector in vectors("record-data-invalid") {
        let original: Value = serde_json::from_slice(&vector.json).unwrap();
        match from_json::<Record>(&vector.json) {
            // Leniently, `null` in an optional field that is not nullable
            // reads as absent and is not written back (see
            // `petrel_core::serde_bridge`), so a client never re-signs it.
            Ok(record) if vector.name == NULL_IN_A_NON_NULLABLE_FIELD => {
                assert_eq!(record.string, None);
                assert_eq!(record.extra_data, None);
            }
            Ok(record) => assert_eq!(
                to_dag_cbor(&record).unwrap(),
                to_dag_cbor(&original).unwrap(),
                "vector '{}' did not round-trip leniently",
                vector.name
            ),
            // Only `integer` is required. (The three `unknown wrong type`
            // vectors omit it too, so they fail on that before `unknown`.)
            Err(error) => {
                let data: serde_json::Value = serde_json::from_slice(&vector.json).unwrap();
                assert!(
                    !data["integer"].is_i64(),
                    "vector '{}' failed a lenient decode: {error}",
                    vector.name
                );
            }
        }
    }
}

#[test]
fn the_vectors_drisl_blob_refs_are_refused_as_the_spec_requires() {
    let vectors = vectors("record-data-valid");
    let full = vectors.iter().find(|vector| vector.name == "full").unwrap();
    let mut data: serde_json::Value = serde_json::from_slice(&full.as_written).unwrap();
    assert_eq!(
        with_raw_blob_refs(&mut data),
        3,
        "blob, sizeBlob and acceptBlob"
    );

    let error = from_json_strict::<Record>(&full.as_written).unwrap_err();
    assert!(error.to_string().contains("blob"), "{error}");
    assert!(
        format!("{error:?}").contains("raw codec"),
        "refused for another reason: {error:?}"
    );

    // A client reading such a record keeps it, and re-encodes it unchanged.
    let record: Record = from_json(&full.as_written).unwrap();
    assert_eq!(record.blob, None);
    let original: Value = serde_json::from_slice(&full.as_written).unwrap();
    assert_eq!(
        to_dag_cbor(&record).unwrap(),
        to_dag_cbor(&original).unwrap()
    );
}

#[test]
fn an_out_of_enum_string_is_kept_verbatim_and_re_encodes_byte_for_byte() {
    use petrel_lexicon_fixture::generated::example::lexicon::record::RecordEnumString;

    let vector = vectors("record-data-invalid")
        .into_iter()
        .find(|vector| vector.name == "out of enum string")
        .unwrap();
    for record in [
        from_json::<Record>(&vector.json).unwrap(),
        from_json_strict::<Record>(&vector.json).unwrap(),
    ] {
        let Some(RecordEnumString::Unknown(raw)) = &record.enum_string else {
            panic!("expected the Unknown arm, got {:?}", record.enum_string);
        };
        assert!(
            record.extra_data.is_none()
                || !record
                    .extra_data
                    .as_ref()
                    .unwrap()
                    .contains_key("enumString")
        );
        let original: Value = from_json(&vector.json).unwrap();
        assert_eq!(
            original.as_object().unwrap()["enumString"].as_str(),
            Some(raw.as_str())
        );
        assert_eq!(to_json(&record).unwrap(), to_json(&original).unwrap());
        assert_eq!(
            to_dag_cbor(&record).unwrap(),
            to_dag_cbor(&original).unwrap()
        );
    }
    // Known values still map to their own arm, and parsing never fails.
    assert_eq!(
        "fish".parse::<RecordEnumString>(),
        Ok(RecordEnumString::Fish)
    );
    assert_eq!(
        "newer".parse::<RecordEnumString>(),
        Ok(RecordEnumString::Unknown("newer".into()))
    );
}
