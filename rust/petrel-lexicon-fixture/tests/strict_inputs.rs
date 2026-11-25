//! An XRPC input declared as a union decodes strictly however it is reached,
//! while its member types still decode leniently on their own. An input
//! declared as a `ref` is the shared definition's own type, so it is strict
//! only through `FromValue::from_value_strict`.

use petrel_core::{DecodeError, FromValue, Value, from_json};

/// Decodes `json` the way an XRPC input is decoded: a malformed optional
/// field anywhere inside it is an error.
fn from_json_strict<T: FromValue>(json: &[u8]) -> Result<T, DecodeError> {
    T::from_value_strict(from_json::<Value>(json)?)
}

use petrel_lexicon_fixture::generated::com::example::widget::note::Note;
use petrel_lexicon_fixture::generated::com::example::widget::submit_union::{Input, InputUnion};
use petrel_lexicon_fixture::generated::io::my_site::_4ever::deep::nested::ns::submit_thing::{
    Input as SubmitThingInput, Thing,
};

/// A `note` member whose optional boolean `default` is a string.
const NOTE_WITH_BAD_DEFAULT: &[u8] = br#"{"$type":"com.example.widget.note","text":"x","created-at":"2026-11-25T00:00:00Z","default":"invalid"}"#;

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
fn a_union_input_rejects_a_member_field_that_does_not_decode() {
    let error = from_json::<Input>(NOTE_WITH_BAD_DEFAULT).unwrap_err();
    assert_eq!(path(&error), ["default"]);
}

#[test]
fn the_member_type_still_decodes_leniently_on_its_own() {
    let note: Note = from_json(NOTE_WITH_BAD_DEFAULT).unwrap();
    assert_eq!(note.default, None);
}

#[test]
fn a_union_input_accepts_a_valid_member_and_an_unknown_one() {
    let input: Input = from_json(
        br#"{"$type":"com.example.widget.note","text":"x","created-at":"2026-11-25T00:00:00Z","default":true}"#,
    )
    .unwrap();
    assert!(matches!(input, InputUnion::Note(note) if note.default == Some(true)));
    let input: Input = from_json(br#"{"$type":"com.example.future","anything":1}"#).unwrap();
    assert!(matches!(input, InputUnion::Unknown(_)));
}

#[test]
fn a_ref_input_is_strict_through_from_value_strict() {
    const BAD_COUNT: &[u8] = br#"{"name":"x","count":"seven"}"#;
    let thing: SubmitThingInput = from_json(BAD_COUNT).unwrap();
    assert_eq!(thing.count, None);
    let error = from_json_strict::<Thing>(BAD_COUNT).unwrap_err();
    assert_eq!(path(&error), ["count"]);
}
