#![cfg(feature = "com_atproto")]

//! An XRPC input is decoded strictly all the way down: a malformed optional
//! field is an error wherever it sits in the input, because a server that
//! reads it as "absent" would act on a request the caller did not make. The
//! same types still decode leniently everywhere else.

use petrel_api::generated::com::atproto::admin::defs::StatusAttr;
use petrel_api::generated::com::atproto::admin::update_subject_status::{
    Input as UpdateSubjectStatusInput, InputSubject,
};
use petrel_api::generated::com::atproto::repo::apply_writes::Input as ApplyWritesInput;
use petrel_core::{DecodeError, Value, from_json};

const REPO_REF: &str = r#"{"$type":"com.atproto.admin.defs#repoRef","did":"did:plc:abc"}"#;

#[test]
fn a_malformed_optional_field_of_an_object_nested_in_an_input_is_rejected() {
    // `ref` is an optional string of statusAttr. A number there is malformed.
    let body = format!(r#"{{"subject":{REPO_REF},"takedown":{{"applied":true,"ref":5}}}}"#);
    let error = from_json::<UpdateSubjectStatusInput>(body.as_bytes()).unwrap_err();
    assert!(
        matches!(error, DecodeError::Field { .. }),
        "expected the error to name the field, got {error:?}"
    );
    let message = error.to_string();
    assert!(message.contains("takedown"), "{message}");
    assert!(message.contains("ref"), "{message}");
}

#[test]
fn a_malformed_optional_field_of_a_union_member_inside_an_array_is_rejected() {
    // `rkey` is optional on applyWrites#create. A number is not a record key.
    let body = br#"{"repo":"did:plc:abc","writes":[{"$type":"com.atproto.repo.applyWrites#create","collection":"app.bsky.feed.post","rkey":5,"value":{}}]}"#;
    let error = from_json::<ApplyWritesInput>(body).unwrap_err();
    let message = error.to_string();
    assert!(message.contains("writes"), "{message}");
    assert!(message.contains("rkey"), "{message}");
}

#[test]
fn a_well_formed_nested_input_still_decodes_and_keeps_unknown_fields() {
    let body = format!(
        r#"{{"subject":{REPO_REF},"takedown":{{"applied":true,"ref":"case-1","future":7}}}}"#
    );
    let input: UpdateSubjectStatusInput = from_json(body.as_bytes()).unwrap();
    let takedown = input.takedown.unwrap();
    assert_eq!(takedown.r#ref.as_deref(), Some("case-1"));
    assert_eq!(
        takedown.extra_data.unwrap().get("future"),
        Some(&Value::Integer(7))
    );
    assert!(matches!(input.subject, InputSubject::RepoRef(_)));
}

#[test]
fn an_unknown_member_of_an_open_union_in_an_input_is_still_accepted() {
    let body = br#"{"subject":{"$type":"com.example.future#subject","x":1}}"#;
    let input: UpdateSubjectStatusInput = from_json(body).unwrap();
    assert!(matches!(input.subject, InputSubject::Unknown(_)));
}

#[test]
fn an_unknown_member_of_a_closed_union_in_an_input_is_rejected() {
    let body = br#"{"repo":"did:plc:abc","writes":[{"$type":"com.example.future#write","x":1}]}"#;
    assert!(from_json::<ApplyWritesInput>(body).is_err());
}

#[test]
fn the_same_object_decodes_leniently_outside_an_input() {
    let attr: StatusAttr = from_json(br#"{"applied":true,"ref":5}"#).unwrap();
    assert_eq!(attr.r#ref, None);
    assert_eq!(
        attr.extra_data.unwrap().get("ref"),
        Some(&Value::Integer(5))
    );
}
