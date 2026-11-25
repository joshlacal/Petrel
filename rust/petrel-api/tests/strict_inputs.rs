#![cfg(feature = "app_bsky")]
//! An XRPC input is decoded strictly at every depth; an output that carries
//! the same data still degrades it.

use petrel_api::generated::app::bsky::actor::get_preferences::Output as GetPreferencesOutput;
use petrel_api::generated::app::bsky::actor::put_preferences::Input as PutPreferencesInput;
use petrel_core::{DecodeError, from_json};

/// `labelerDid` is an optional `did` three levels down: preferences, a union
/// member, then the field.
const BAD_NESTED_DID: &[u8] = br#"{"preferences":[{"$type":"app.bsky.actor.defs#contentLabelPref","labelerDid":"not a did","label":"spam","visibility":"hide"}]}"#;

fn path(error: &DecodeError) -> Vec<&str> {
    let mut fields = Vec::new();
    let mut current = error;
    while let DecodeError::Field { field, source } = current {
        fields.push(field.as_str());
        current = source;
    }
    fields
}

#[test]
fn an_input_rejects_a_nested_optional_field_that_does_not_decode() {
    let error = from_json::<PutPreferencesInput>(BAD_NESTED_DID).unwrap_err();
    assert_eq!(path(&error), ["preferences", "labelerDid"]);
}

#[test]
fn an_output_with_the_same_data_still_degrades_it() {
    let output: GetPreferencesOutput = from_json(BAD_NESTED_DID).unwrap();
    assert_eq!(output.preferences.len(), 1);
}

#[test]
fn an_input_accepts_valid_nested_data_and_unknown_union_members() {
    let input: PutPreferencesInput = from_json(
        br#"{"preferences":[{"$type":"app.bsky.actor.defs#contentLabelPref","labelerDid":"did:plc:abc","label":"spam","visibility":"hide"},{"$type":"com.example.futurePref","anything":1}]}"#,
    )
    .unwrap();
    assert_eq!(input.preferences.len(), 2);
}
