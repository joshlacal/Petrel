#![cfg(feature = "com_atproto")]

use std::collections::BTreeMap;

use petrel_api::generated::com::atproto::admin::update_subject_status::Input as UpdateSubjectStatusInput;
use petrel_api::generated::com::atproto::sync::subscribe_repos::{
    Error as SubscribeReposError, Info, Message as SubscribeReposMessage, SubscribeRepos,
};
use petrel_core::{
    DecodedSubscriptionFrame, FrameHeader, SubscriptionFrame, Value, XrpcInput, XrpcSubscription,
    decode_subscription_frame, encode_frame, encode_subscription_message,
};

#[test]
fn xrpc_input_from_body_enforces_nested_strictness() {
    let body = br#"{"subject":{"$type":"com.atproto.admin.defs#repoRef","did":"did:plc:abc"},"takedown":{"applied":true,"ref":5}}"#;
    let err = UpdateSubjectStatusInput::from_body(body).unwrap_err();
    let message = err.to_string();
    assert!(message.contains("takedown"), "{message}");
    assert!(message.contains("ref"), "{message}");

    let valid = br#"{"subject":{"$type":"com.atproto.admin.defs#repoRef","did":"did:plc:abc"},"takedown":{"applied":true,"ref":"case-1"}}"#;
    let decoded = UpdateSubjectStatusInput::from_body(valid).unwrap();
    assert_eq!(decoded.takedown.unwrap().r#ref.as_deref(), Some("case-1"));
}

#[test]
fn generated_subscription_round_trips_messages_errors_and_unknowns() {
    assert_eq!(
        <SubscribeRepos as XrpcSubscription>::NSID,
        "com.atproto.sync.subscribeRepos"
    );
    assert_eq!(<SubscribeRepos as XrpcSubscription>::SUBPROTOCOL, None);

    let msg = SubscribeReposMessage::Info(Box::new(Info {
        name: "OutdatedCursor".to_owned(),
        message: Some("clamped".to_owned()),
        extra_data: None,
    }));
    let wire = encode_subscription_message::<SubscribeRepos>(&msg).unwrap();
    match decode_subscription_frame::<SubscribeRepos>(&wire).unwrap() {
        DecodedSubscriptionFrame::Message {
            message,
            message_type,
            sequence,
        } => {
            assert_eq!(message_type, "com.atproto.sync.subscribeRepos#info");
            assert_eq!(sequence, None);
            assert_eq!(message, msg);
        }
        other => panic!("expected typed message, got {other:?}"),
    }

    let err_wire = encode_frame(&SubscriptionFrame::Error {
        error: "FutureCursor".to_owned(),
        message: Some("too high".to_owned()),
    })
    .unwrap();
    assert_eq!(
        decode_subscription_frame::<SubscribeRepos>(&err_wire).unwrap(),
        DecodedSubscriptionFrame::Error {
            error: SubscribeReposError::FutureCursor,
            message: Some("too high".to_owned()),
        }
    );

    let future_msg_wire = encode_frame(&SubscriptionFrame::Message {
        header: FrameHeader::message("#futureEvent"),
        message_type: "#futureEvent".to_owned(),
        payload: Value::Object(BTreeMap::from([("seq".to_owned(), Value::Integer(99))])),
        sequence: Some(99),
    })
    .unwrap();
    match decode_subscription_frame::<SubscribeRepos>(&future_msg_wire).unwrap() {
        DecodedSubscriptionFrame::UnknownMessageType {
            message_type,
            sequence,
            ..
        } => {
            assert_eq!(message_type, "com.atproto.sync.subscribeRepos#futureEvent");
            assert_eq!(sequence, Some(99));
        }
        other => panic!("expected UnknownMessageType, got {other:?}"),
    }
}

#[cfg(feature = "network_bsky")]
#[test]
fn generated_jetstream_subscription_uses_xrpc_v1_json_subprotocol() {
    use petrel_api::generated::network::bsky::jetstream::subscribe_events::{
        Commit, Error as SubscribeEventsError, Info, Message as SubscribeEventsMessage,
        SubscribeEvents,
    };
    use petrel_core::{Datetime, Did, Nsid, RecordKey, Tid, XRPC_V1_JSON_SUBPROTOCOL};

    assert_eq!(
        <SubscribeEvents as XrpcSubscription>::SUBPROTOCOL,
        Some(XRPC_V1_JSON_SUBPROTOCOL)
    );

    let commit_msg = SubscribeEventsMessage::Commit(Box::new(Commit {
        seq: 42,
        did: Did::parse("did:plc:ewvi7nxzyoun6zhxrhs64oiz").unwrap(),
        time: Datetime::parse("2026-08-08T12:00:00.000Z").unwrap(),
        rev: Tid::parse("3jzfcijpj2z2a").unwrap(),
        operation: "create".to_owned(),
        collection: Nsid::parse("app.bsky.feed.post").unwrap(),
        rkey: RecordKey::parse("3jzfcijpj2z2a").unwrap(),
        record: None,
        cid: None,
        extra_data: None,
    }));
    let wire = encode_subscription_message::<SubscribeEvents>(&commit_msg).unwrap();
    let envelope: Value = petrel_core::from_json(&wire).unwrap();
    let root = envelope.as_object().unwrap();
    assert_eq!(
        root.get("$type"),
        Some(&Value::String("message".to_owned()))
    );
    let payload = root.get("payload").unwrap().as_object().unwrap();
    assert_eq!(
        payload.get("$type"),
        Some(&Value::String(
            "network.bsky.jetstream.subscribeEvents#commit".to_owned()
        ))
    );
    assert_eq!(payload.get("seq"), Some(&Value::Integer(42)));

    match decode_subscription_frame::<SubscribeEvents>(&wire).unwrap() {
        DecodedSubscriptionFrame::Message {
            message,
            message_type,
            sequence,
        } => {
            assert_eq!(
                message_type,
                "network.bsky.jetstream.subscribeEvents#commit"
            );
            assert_eq!(sequence, Some(42));
            assert_eq!(message, commit_msg);
        }
        other => panic!("expected typed Jetstream commit message, got {other:?}"),
    }

    let info_wire = br#"{"$type":"message","payload":{"$type":"network.bsky.jetstream.subscribeEvents#info","name":"OutdatedCursor","message":"resumed at 10"}}"#;
    match decode_subscription_frame::<SubscribeEvents>(info_wire).unwrap() {
        DecodedSubscriptionFrame::Message {
            message: SubscribeEventsMessage::Info(info),
            message_type,
            sequence,
        } => {
            assert_eq!(message_type, "network.bsky.jetstream.subscribeEvents#info");
            assert_eq!(sequence, None);
            assert_eq!(
                *info,
                Info {
                    name: "OutdatedCursor".to_owned(),
                    message: Some("resumed at 10".to_owned()),
                    extra_data: None,
                }
            );
        }
        other => panic!("expected Jetstream info message, got {other:?}"),
    }

    let err_wire = br#"{"$type":"error","error":"ConsumerTooSlow","message":"reader fell behind"}"#;
    assert_eq!(
        decode_subscription_frame::<SubscribeEvents>(err_wire).unwrap(),
        DecodedSubscriptionFrame::Error {
            error: SubscribeEventsError::ConsumerTooSlow,
            message: Some("reader fell behind".to_owned()),
        }
    );

    let future_msg_wire = br#"{"$type":"message","payload":{"$type":"network.bsky.jetstream.subscribeEvents#future","seq":99}}"#;
    assert!(matches!(
        decode_subscription_frame::<SubscribeEvents>(future_msg_wire).unwrap(),
        DecodedSubscriptionFrame::UnknownMessageType {
            message_type,
            sequence: Some(99),
            ..
        } if message_type == "network.bsky.jetstream.subscribeEvents#future"
    ));

    // DAG-CBOR error frame must not decode as an xrpc.v1.json frame.
    let cbor_err = encode_frame(&SubscriptionFrame::Error {
        error: "ConsumerTooSlow".to_owned(),
        message: None,
    })
    .unwrap();
    assert!(decode_subscription_frame::<SubscribeEvents>(&cbor_err).is_err());
}
