mod common;

use std::collections::BTreeMap;

use petrel_api::generated::com::atproto::label::subscribe_labels::{
    Info as LabelInfo, Labels as LabelBatch, Message as LabelsMessage,
};
use petrel_core::{Cid, FrameHeader, SubscriptionFrame, ToValue, Value, dagcbor, encode_frame};
use petrel_firehose::{
    EventStreamEvent, EventStreamIgnoredFrame, FirehoseFrameEncoder, FirehoseFrameEncoderError,
    FirehoseFrameLimits, FirehoseStreamError, IgnoredFrameReason, LabelSubscription,
    PublicFirehoseAccountMaterial, PublicFirehoseAccountStatus, PublicFirehoseCommitMaterial,
    PublicFirehoseIdentityMaterial, PublicFirehoseRepoAction, PublicFirehoseRepoOp,
    PublicFirehoseSourceKey, PublicFirehoseSyncMaterial, PublicFirehoseTime, RelayEvent,
    RelayFrame, RelayFrameDecoder, RelayFrameDecodingMode, RelayVerifierError,
};

#[cfg(not(target_arch = "wasm32"))]
use tokio::test as async_test;
#[cfg(target_arch = "wasm32")]
use wasm_bindgen_test::wasm_bindgen_test as async_test;

fn encode_raw_frame(header: &Value, body: &Value) -> Vec<u8> {
    let mut out = dagcbor::encode(header);
    out.extend_from_slice(&dagcbor::encode(body));
    out
}

#[test]
fn firehose_frame_encoder_round_trips_all_event_types() {
    let cid_bytes = vec![0x01, 0x71, 0x12, 0x20];
    let mut full = cid_bytes;
    full.extend_from_slice(&[0xaa; 32]);
    let cid = Cid::from_bytes(&full).unwrap().to_string();
    let prev_cid = {
        let mut b = vec![0x01, 0x71, 0x12, 0x20];
        b.extend_from_slice(&[0xbb; 32]);
        Cid::from_bytes(&b).unwrap().to_string()
    };

    let commit_material = PublicFirehoseCommitMaterial {
        did: "did:plc:abc123def456".to_owned(),
        rev: "3k7v2abc23456".to_owned(),
        since: Some("3k7v2abc23454".to_owned()),
        commit_cid: cid.clone(),
        prev_data_cid: Some(prev_cid),
        ops: vec![PublicFirehoseRepoOp {
            action: PublicFirehoseRepoAction::Create,
            path: "app.bsky.feed.post/3k7v2abc23456".to_owned(),
            cid: Some(cid.clone()),
            prev: None,
        }],
        time: "2026-01-01T00:00:00.000Z".to_owned(),
    };

    let diff_car = common::encode_car(
        &[cid.parse().unwrap()],
        &[(cid.parse().unwrap(), vec![1, 2, 3])],
    );
    let commit_frame = FirehoseFrameEncoder::commit_frame(42, &commit_material, &diff_car).unwrap();
    let decoded_commit =
        RelayFrameDecoder::decode_with_mode(&commit_frame, RelayFrameDecodingMode::Strict).unwrap();
    let RelayEvent::Commit(c) = decoded_commit else {
        panic!("expected commit");
    };
    assert_eq!(c.seq, 42);
    assert_eq!(c.repo, commit_material.did);
    assert_eq!(c.rev, commit_material.rev);
    assert_eq!(c.since, commit_material.since);
    assert_eq!(c.blocks, diff_car);
    assert_eq!(c.ops.len(), 1);

    let sync_material = PublicFirehoseSyncMaterial {
        did: "did:plc:abc123def456".to_owned(),
        rev: "3k7v2abc23457".to_owned(),
        commit_cid: cid,
        time: "2026-01-01T00:00:01.000Z".to_owned(),
    };
    let sync_frame = FirehoseFrameEncoder::sync_frame(43, &sync_material, &diff_car).unwrap();
    assert!(matches!(
        RelayFrameDecoder::decode_with_mode(&sync_frame, RelayFrameDecodingMode::Strict).unwrap(),
        RelayEvent::Sync(s) if s.seq == 43 && s.rev == "3k7v2abc23457"
    ));

    let identity_material = PublicFirehoseIdentityMaterial {
        did: "did:plc:abc123def456".to_owned(),
        handle: Some("alice.example.com".to_owned()),
        time: "2026-01-01T00:00:02.000Z".to_owned(),
    };
    let id_frame = FirehoseFrameEncoder::identity_frame(44, &identity_material).unwrap();
    assert!(matches!(
        RelayFrameDecoder::decode_with_mode(&id_frame, RelayFrameDecodingMode::Strict).unwrap(),
        RelayEvent::Identity(i) if i.seq == 44 && i.handle.as_deref() == Some("alice.example.com")
    ));

    let account_material = PublicFirehoseAccountMaterial {
        did: "did:plc:abc123def456".to_owned(),
        active: false,
        status: Some(PublicFirehoseAccountStatus::Deactivated),
        time: "2026-01-01T00:00:03.000Z".to_owned(),
    };
    let acct_frame = FirehoseFrameEncoder::account_frame(45, &account_material).unwrap();
    assert!(matches!(
        RelayFrameDecoder::decode_with_mode(&acct_frame, RelayFrameDecodingMode::Strict).unwrap(),
        RelayEvent::Account(a) if a.seq == 45 && !a.active && a.status.as_deref() == Some("deactivated")
    ));

    let info_frame = FirehoseFrameEncoder::info_frame("OutdatedCursor", Some("too old")).unwrap();
    assert!(matches!(
        RelayFrameDecoder::decode_with_mode(&info_frame, RelayFrameDecodingMode::Strict).unwrap(),
        RelayEvent::Info(i) if i.name == "OutdatedCursor" && i.message.as_deref() == Some("too old")
    ));

    let err_frame = FirehoseFrameEncoder::error_frame("FutureCursor", Some("ahead")).unwrap();
    assert!(matches!(
        RelayFrameDecoder::decode_with_mode(&err_frame, RelayFrameDecodingMode::Strict).unwrap(),
        RelayEvent::Error(e) if e.error == "FutureCursor" && e.message.as_deref() == Some("ahead")
    ));
}

#[test]
fn firehose_frame_encoder_rejects_limits() {
    assert_eq!(
        FirehoseFrameLimits::validate_sequence(0),
        Err(FirehoseFrameEncoderError::SequenceOutOfRange)
    );
    assert_eq!(
        FirehoseFrameLimits::validate_sequence(-1),
        Err(FirehoseFrameEncoderError::SequenceOutOfRange)
    );
    assert!(FirehoseFrameLimits::validate_sequence(1).is_ok());
    assert!(FirehoseFrameLimits::validate_sequence(FirehoseFrameLimits::MAXIMUM_SEQUENCE).is_ok());

    let account = PublicFirehoseAccountMaterial {
        did: "did:plc:abc".to_owned(),
        active: true,
        status: Some(PublicFirehoseAccountStatus::Suspended),
        time: "2026-01-01T00:00:00.000Z".to_owned(),
    };
    assert_eq!(
        FirehoseFrameEncoder::account_frame(1, &account),
        Err(FirehoseFrameEncoderError::InvalidAccountStatus)
    );
}

#[test]
fn lenient_decoding_ignores_unknown_header_body_fields_and_drisl_float64() {
    let mut header = BTreeMap::new();
    header.insert("op".to_owned(), Value::Integer(1));
    header.insert("t".to_owned(), Value::String("#identity".to_owned()));
    header.insert("extra".to_owned(), Value::String("v2".to_owned()));

    let mut body = BTreeMap::new();
    body.insert("seq".to_owned(), Value::Integer(7));
    body.insert(
        "did".to_owned(),
        Value::String("did:plc:abc123def456".to_owned()),
    );
    body.insert(
        "time".to_owned(),
        Value::String("2026-01-01T00:00:00.000Z".to_owned()),
    );
    body.insert(
        "handle".to_owned(),
        Value::String("alice.bsky.social".to_owned()),
    );
    body.insert("extra".to_owned(), Value::String("ignored".to_owned()));

    // Inject raw CBOR map with float64(1.5) (major 7 addl 27 + 0x3ff8_0000_0000_0000) in "future".
    let header_bytes = dagcbor::encode(&Value::Object(header));
    let mut body_raw = vec![0xa5]; // 5-entry map: did, seq, time, extra, future (sorted by len then lex)
    for (k, v) in [
        ("did", Value::String("did:plc:abc123def456".to_owned())),
        ("seq", Value::Integer(7)),
        ("time", Value::String("2026-01-01T00:00:00.000Z".to_owned())),
        ("extra", Value::String("ignored".to_owned())),
    ] {
        body_raw.extend_from_slice(&dagcbor::encode(&Value::String(k.to_owned())));
        body_raw.extend_from_slice(&dagcbor::encode(&v));
    }
    body_raw.extend_from_slice(&dagcbor::encode(&Value::String("future".to_owned())));
    body_raw.push(0xfb);
    body_raw.extend_from_slice(&1.5_f64.to_be_bytes());

    let mut frame = header_bytes;
    frame.extend_from_slice(&body_raw);

    let decoded = RelayFrameDecoder::decode(&frame).unwrap();
    assert!(matches!(decoded, RelayEvent::Identity(i) if i.seq == 7));
    assert_eq!(
        RelayFrameDecoder::decode_with_mode(&frame, RelayFrameDecodingMode::Strict),
        Err(RelayVerifierError::InvalidFrameHeader)
    );
}

#[test]
fn lenient_decoding_ignores_unknown_ops_and_types_and_open_account_status() {
    // Unknown op = 2
    let mut header = BTreeMap::new();
    header.insert("op".to_owned(), Value::Integer(2));
    let mut body = BTreeMap::new();
    body.insert("seq".to_owned(), Value::Integer(10));
    let raw = encode_raw_frame(&Value::Object(header), &Value::Object(body));
    assert_eq!(
        RelayFrameDecoder::decode_frame(&raw, RelayFrameDecodingMode::Lenient).unwrap(),
        RelayFrame::Ignored(EventStreamIgnoredFrame {
            operation: 2,
            r#type: None,
            sequence: Some(10),
            reason: IgnoredFrameReason::UnknownOperation,
        })
    );
    assert_eq!(
        RelayFrameDecoder::decode_with_mode(&raw, RelayFrameDecodingMode::Strict),
        Err(RelayVerifierError::InvalidFrameHeader)
    );

    // Unknown deprecated type #handle
    let mut header2 = BTreeMap::new();
    header2.insert("op".to_owned(), Value::Integer(1));
    header2.insert("t".to_owned(), Value::String("#handle".to_owned()));
    let mut body2 = BTreeMap::new();
    body2.insert("seq".to_owned(), Value::Integer(11));
    let raw2 = encode_raw_frame(&Value::Object(header2), &Value::Object(body2));
    assert_eq!(
        RelayFrameDecoder::decode_frame(&raw2, RelayFrameDecodingMode::Lenient).unwrap(),
        RelayFrame::Ignored(EventStreamIgnoredFrame {
            operation: 1,
            r#type: Some("#handle".to_owned()),
            sequence: Some(11),
            reason: IgnoredFrameReason::UnknownType,
        })
    );

    // Open account status in lenient mode vs closed set in strict mode
    let mut h_acct = BTreeMap::new();
    h_acct.insert("op".to_owned(), Value::Integer(1));
    h_acct.insert("t".to_owned(), Value::String("#account".to_owned()));
    let mut b_acct = BTreeMap::new();
    b_acct.insert("seq".to_owned(), Value::Integer(12));
    b_acct.insert("did".to_owned(), Value::String("did:plc:abc".to_owned()));
    b_acct.insert(
        "time".to_owned(),
        Value::String("2026-01-01T00:00:00.000Z".to_owned()),
    );
    b_acct.insert("active".to_owned(), Value::Bool(false));
    b_acct.insert("status".to_owned(), Value::String("frozen".to_owned()));
    let raw_acct = encode_raw_frame(&Value::Object(h_acct), &Value::Object(b_acct));
    assert!(matches!(
        RelayFrameDecoder::decode(&raw_acct).unwrap(),
        RelayEvent::Account(a) if a.status.as_deref() == Some("frozen")
    ));
    assert_eq!(
        RelayFrameDecoder::decode_with_mode(&raw_acct, RelayFrameDecodingMode::Strict),
        Err(RelayVerifierError::InvalidAccountStatus)
    );
}

#[test]
fn decoder_rejects_non_canonical_cbor_and_unicode_key_collisions() {
    // Non-canonical integer encoding (23 encoded with 0x18 0x17 instead of 0x17)
    let bad_cbor = vec![
        0xa2, 0x62, b'o', b'p', 0x01, 0x61, b't', 0x65, b'#', b'i', b'n', b'f', b'o', 0xa1, 0x64,
        b'n', b'a', b'm', b'e', 0x63, b'o', b'p', b's',
    ];
    // Valid first; now test non-canonical int in body: { "op": 24-in-2-bytes }
    let non_canon = vec![
        0xa1, 0x62, b'o', b'p', 0x18, 0x01, // 1 encoded as 0x18 0x01 (non-canonical!)
        0xa0,
    ];
    assert_eq!(
        RelayFrameDecoder::parse(&non_canon).unwrap_err(),
        RelayVerifierError::NonCanonicalCbor
    );
    let _ = bad_cbor;

    // NFC vs NFD collision ("é" vs "e\u{0301}") in body map
    let mut header = BTreeMap::new();
    header.insert("op".to_owned(), Value::Integer(1));
    header.insert("t".to_owned(), Value::String("#info".to_owned()));
    let mut body = BTreeMap::new();
    body.insert("name".to_owned(), Value::String("ok".to_owned()));
    body.insert("\u{00e9}".to_owned(), Value::Integer(1));
    body.insert("e\u{0301}".to_owned(), Value::Integer(2));
    let raw = encode_raw_frame(&Value::Object(header), &Value::Object(body));
    assert_eq!(
        RelayFrameDecoder::parse(&raw).unwrap_err(),
        RelayVerifierError::InvalidCbor
    );
}

#[test]
fn source_keys_and_time_helpers_match_expected_formats() {
    assert_eq!(
        PublicFirehoseSourceKey::commit("did:plc:123", "bafycid"),
        "did:plc:123|commit|bafycid"
    );
    assert_eq!(
        PublicFirehoseSourceKey::sync_manual("did:plc:123", "ABCDEF"),
        "did:plc:123|sync|manual|abcdef"
    );
    assert_eq!(
        PublicFirehoseTime::encode(petrel::rt::UNIX_EPOCH),
        "1970-01-01T00:00:00.000Z"
    );
    assert!(PublicFirehoseTime::microseconds_from_seconds(-1.0).is_err());
    assert_eq!(
        PublicFirehoseTime::microseconds_from_seconds(1.5).unwrap(),
        1_500_000
    );
}

#[async_test]
async fn event_stream_subscription_decodes_labels_info_unknown_and_errors() {
    use futures_util::StreamExt;
    use petrel_firehose::FirehoseSubscriptionConfiguration;
    use std::sync::Arc;
    use url::Url;

    let labels_msg = LabelsMessage::Labels(Box::new(LabelBatch {
        seq: 1,
        labels: Vec::new(),
        extra_data: Option::default(),
    }));
    let f1 = encode_frame(&SubscriptionFrame::Message {
        header: FrameHeader::message("#labels"),
        message_type: "com.atproto.label.subscribeLabels#labels".to_owned(),
        payload: labels_msg.to_value().unwrap(),
        sequence: Some(1),
    })
    .unwrap();

    let info_msg = LabelsMessage::Info(Box::new(LabelInfo {
        name: "Maintenance".to_owned(),
        message: Some("soon".to_owned()),
        extra_data: Option::default(),
    }));
    let f2_frame = SubscriptionFrame::Message {
        header: FrameHeader::message("#info"),
        message_type: "com.atproto.label.subscribeLabels#info".to_owned(),
        payload: info_msg.to_value().unwrap(),
        sequence: None,
    };
    let f2 = encode_frame(&f2_frame).unwrap();

    // Unknown op frame -> IgnoredFrame
    let mut h_unk = BTreeMap::new();
    h_unk.insert("op".to_owned(), Value::Integer(9));
    let f3 = encode_raw_frame(&Value::Object(h_unk), &Value::Object(BTreeMap::new()));

    // Error frame -> terminal Stream error
    let f4 = encode_frame(&SubscriptionFrame::Error {
        error: "FutureCursor".to_owned(),
        message: Some("ahead".to_owned()),
    })
    .unwrap();

    // Malformed frame (non-minimal integer in the header, no body) -> IgnoredFrame, not fatal.
    let f_bad = vec![0xA1, 0x62, b'o', b'p', 0x18, 0x01];

    let session = Arc::new(common::ScriptedSession::from_actions(vec![
        Ok(f1),
        Ok(f2),
        Ok(f3),
        Ok(f_bad),
        Ok(f4),
    ]));
    let factory = Arc::new(common::ScriptedWebSocketFactory::new(vec![Ok(session)]));

    let mut cfg = FirehoseSubscriptionConfiguration::new(
        Url::parse("wss://mod.bsky.app/xrpc/com.atproto.label.subscribeLabels").unwrap(),
    );
    cfg.session_factory = factory;
    let sub = LabelSubscription::new(cfg);
    let mut stream = sub.events();

    let first = stream.next().await.unwrap().unwrap();
    assert!(matches!(
        first,
        EventStreamEvent::Message {
            message: LabelsMessage::Labels(_),
            sequence: Some(1)
        }
    ));

    let second = stream.next().await.unwrap().unwrap();
    assert!(matches!(
        second,
        EventStreamEvent::Message {
            message: LabelsMessage::Info(_),
            sequence: None
        }
    ));

    let third = stream.next().await.unwrap().unwrap();
    assert!(matches!(
        third,
        EventStreamEvent::IgnoredFrame(EventStreamIgnoredFrame {
            operation: 9,
            reason: IgnoredFrameReason::UnknownOperation,
            ..
        })
    ));

    let malformed = stream.next().await.unwrap().unwrap();
    assert!(matches!(
        malformed,
        EventStreamEvent::IgnoredFrame(EventStreamIgnoredFrame {
            operation: 1,
            sequence: None,
            reason: IgnoredFrameReason::MalformedFrame(_),
            ..
        })
    ));

    let fourth = stream.next().await.unwrap();
    assert!(matches!(
        fourth,
        Err(FirehoseStreamError::Stream(
            petrel_firehose::EventStreamError::FutureCursor(Some(ref msg))
        )) if msg == "ahead"
    ));

    let _: SubscriptionFrame = petrel_core::decode_frame_with(
        &encode_frame(&f2_frame).unwrap(),
        Some("com.atproto.label.subscribeLabels"),
    )
    .unwrap();
}

#[test]
fn drisl_float64_fails_on_known_optional_fields_while_allowed_in_unknown_fields() {
    let mut header = BTreeMap::new();
    header.insert("op".to_owned(), Value::Integer(1));
    header.insert("t".to_owned(), Value::String("#identity".to_owned()));
    let header_bytes = dagcbor::encode(&Value::Object(header));

    // Known optional `handle` holding float64(1.5) (0xfb + IEEE754 bits) must fail!
    // Canonical map keys (len, lex): "did" (3), "seq" (3), "time" (4), "handle" (6)
    let mut bad_body = vec![0xa4];
    for (k, v) in [
        ("did", Value::String("did:plc:abc123def456".to_owned())),
        ("seq", Value::Integer(7)),
        ("time", Value::String("2026-01-01T00:00:00.000Z".to_owned())),
    ] {
        bad_body.extend_from_slice(&dagcbor::encode(&Value::String(k.to_owned())));
        bad_body.extend_from_slice(&dagcbor::encode(&v));
    }
    bad_body.extend_from_slice(&dagcbor::encode(&Value::String("handle".to_owned())));
    bad_body.push(0xfb);
    bad_body.extend_from_slice(&1.5_f64.to_be_bytes());

    let mut bad_frame = header_bytes;
    bad_frame.extend_from_slice(&bad_body);
    assert_eq!(
        RelayFrameDecoder::decode(&bad_frame),
        Err(RelayVerifierError::InvalidEventBody)
    );
}
