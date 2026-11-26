use std::collections::BTreeMap;

use petrel_core::{
    Cid, DagCborError, DeclaredXrpcError, DecodeError, DecodedSubscriptionFrame, EncodeError,
    FrameError, FrameHeader, FromValue, MAXIMUM_FRAME_BYTES, SubscriptionFrame, ToQueryParams,
    ToValue, Value, XRPC_V1_JSON_SUBPROTOCOL, XrpcSubscription, dagcbor, decode_frame,
    decode_frame_with, decode_subscription_frame, encode_frame, encode_subscription_error,
    encode_subscription_message,
};

#[cfg(target_arch = "wasm32")]
use wasm_bindgen_test::wasm_bindgen_test;

fn obj(pairs: impl IntoIterator<Item = (&'static str, Value)>) -> Value {
    Value::Object(
        pairs
            .into_iter()
            .map(|(k, v)| (k.to_owned(), v))
            .collect::<BTreeMap<_, _>>(),
    )
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn decodes_commit_frame_with_cid_links_bytes_and_default_lexicon() {
    let cid = Cid::for_dag_cbor(&[0xa0]);
    let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz";
    let header = obj([
        ("op", Value::Integer(1)),
        ("t", Value::String("#commit".into())),
    ]);
    let payload = obj([
        ("seq", Value::Integer(27_060_984_573)),
        ("rebase", Value::Bool(false)),
        ("tooBig", Value::Bool(false)),
        ("repo", Value::String(did.into())),
        ("commit", Value::Link(cid.clone())),
        ("rev", Value::String("3jzfcijpj2z2a".into())),
        ("since", Value::Null),
        ("blocks", Value::Bytes(vec![1, 2, 3])),
        (
            "ops",
            Value::Array(vec![obj([
                ("action", Value::String("create".into())),
                (
                    "path",
                    Value::String("app.bsky.feed.post/3jzfcijpj2z2a".into()),
                ),
                ("cid", Value::Link(cid.clone())),
            ])]),
        ),
        ("blobs", Value::Array(vec![])),
        ("prevData", Value::Link(cid.clone())),
        ("time", Value::String("2026-08-08T12:00:00.000Z".into())),
    ]);

    let mut wire = dagcbor::encode(&header);
    wire.extend_from_slice(&dagcbor::encode(&payload));

    let decoded = decode_frame_with(&wire, Some("com.atproto.sync.subscribeRepos")).unwrap();
    match decoded {
        SubscriptionFrame::Message {
            header,
            message_type,
            payload,
            sequence,
        } => {
            assert_eq!(header.op, 1);
            assert_eq!(header.message_type.as_deref(), Some("#commit"));
            assert_eq!(message_type, "com.atproto.sync.subscribeRepos#commit");
            assert_eq!(sequence, Some(27_060_984_573));
            let map = payload.as_object().unwrap();
            assert_eq!(
                map.get("$type"),
                Some(&Value::String(
                    "com.atproto.sync.subscribeRepos#commit".into()
                ))
            );
            assert_eq!(map.get("commit"), Some(&Value::Link(cid)));
            assert_eq!(map.get("blocks"), Some(&Value::Bytes(vec![1, 2, 3])));
        }
        other => panic!("expected message frame, got {other:?}"),
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn decodes_and_encodes_error_unknown_op_and_unsequenced_frames() {
    let error_frame = SubscriptionFrame::Error {
        error: "FutureCursor".to_owned(),
        message: Some("Cursor in the future.".to_owned()),
    };
    let encoded = encode_frame(&error_frame).unwrap();
    assert_eq!(decode_frame(&encoded).unwrap(), error_frame);

    let unknown = SubscriptionFrame::UnknownOperation { op: 7 };
    let unknown_wire = encode_frame(&unknown).unwrap();
    assert_eq!(decode_frame(&unknown_wire).unwrap(), unknown);

    // Extra header fields are ignored and unsequenced messages yield sequence: None.
    let mut info_wire = dagcbor::encode(&obj([
        ("op", Value::Integer(1)),
        ("t", Value::String("#info".into())),
        ("extra", Value::Integer(1)),
    ]));
    info_wire.extend_from_slice(&dagcbor::encode(&obj([(
        "name",
        Value::String("OutdatedCursor".into()),
    )])));
    match decode_frame_with(&info_wire, Some("com.atproto.sync.subscribeRepos")).unwrap() {
        SubscriptionFrame::Message {
            message_type,
            sequence,
            ..
        } => {
            assert_eq!(message_type, "com.atproto.sync.subscribeRepos#info");
            assert_eq!(sequence, None);
        }
        other => panic!("expected message frame, got {other:?}"),
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn rejects_invalid_frames_limits_and_non_canonical_cbor() {
    assert_eq!(decode_frame(&[]), Err(FrameError::Empty));
    assert!(matches!(
        decode_frame(&vec![0u8; MAXIMUM_FRAME_BYTES + 1]),
        Err(FrameError::FrameTooLarge { .. })
    ));

    // Header only (missing payload)
    let header_only = dagcbor::encode(&obj([
        ("op", Value::Integer(1)),
        ("t", Value::String("#commit".into())),
    ]));
    assert_eq!(decode_frame(&header_only), Err(FrameError::MissingPayload));

    // Missing `t` on op: 1
    let mut no_t = dagcbor::encode(&obj([("op", Value::Integer(1))]));
    no_t.extend_from_slice(&dagcbor::encode(&obj([])));
    assert!(matches!(
        decode_frame(&no_t),
        Err(FrameError::InvalidHeader(_))
    ));

    // Trailing bytes after payload
    let mut trailing = encode_frame(&SubscriptionFrame::Error {
        error: "ConsumerTooSlow".to_owned(),
        message: None,
    })
    .unwrap();
    trailing.push(0x00);
    assert!(matches!(
        decode_frame(&trailing),
        Err(FrameError::DagCbor(DagCborError::TrailingBytes))
    ));

    // Payload must be a map
    let mut non_map = dagcbor::encode(&obj([
        ("op", Value::Integer(1)),
        ("t", Value::String("#commit".into())),
    ]));
    non_map.extend_from_slice(&dagcbor::encode(&Value::Array(vec![])));
    assert!(matches!(
        decode_frame(&non_map),
        Err(FrameError::InvalidPayload(_))
    ));

    // Exceeds DAG-CBOR depth limit (64)
    let mut deep = obj([]);
    for _ in 0..70 {
        deep = Value::Array(vec![deep]);
    }
    let mut deep_frame = dagcbor::encode(&obj([
        ("op", Value::Integer(1)),
        ("t", Value::String("#commit".into())),
    ]));
    deep_frame.extend_from_slice(&dagcbor::encode(&obj([("deep", deep)])));
    assert!(matches!(
        decode_frame(&deep_frame),
        Err(FrameError::DagCbor(DagCborError::DepthExceeded(64)))
    ));

    // Tag 42 CID link without 0x00 multibase prefix
    let cid = Cid::for_dag_cbor(&[0xa0]);
    let mut bad_link_frame = dagcbor::encode(&obj([
        ("op", Value::Integer(1)),
        ("t", Value::String("#commit".into())),
    ]));
    // Map {"a": tag(42, bstr(cid_bytes))} without 0x00 prefix
    bad_link_frame.push(0xa1);
    bad_link_frame.push(0x61);
    bad_link_frame.push(0x61);
    bad_link_frame.extend_from_slice(&[0xd8, 42]);
    let cid_len = u8::try_from(cid.as_bytes().len()).unwrap();
    bad_link_frame.push(0x58);
    bad_link_frame.push(cid_len);
    bad_link_frame.extend_from_slice(cid.as_bytes());
    assert!(matches!(
        decode_frame(&bad_link_frame),
        Err(FrameError::DagCbor(DagCborError::InvalidLink(_)))
    ));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn round_trips_with_frame_header_helper() {
    let header = FrameHeader::message("#sync");
    let frame = SubscriptionFrame::Message {
        header,
        message_type: "#sync".to_owned(),
        payload: obj([
            ("seq", Value::Integer(42)),
            ("did", Value::String("did:plc:abc".into())),
        ]),
        sequence: Some(42),
    };
    let wire = encode_frame(&frame).unwrap();
    let decoded = decode_frame_with(&wire, Some("com.atproto.sync.subscribeRepos")).unwrap();
    match decoded {
        SubscriptionFrame::Message {
            message_type,
            sequence,
            payload,
            ..
        } => {
            assert_eq!(message_type, "com.atproto.sync.subscribeRepos#sync");
            assert_eq!(sequence, Some(42));
            assert_eq!(
                payload.as_object().unwrap().get("$type"),
                Some(&Value::String(
                    "com.atproto.sync.subscribeRepos#sync".to_owned()
                ))
            );
        }
        other => panic!("expected message, got {other:?}"),
    }
}

#[derive(Debug, Clone, PartialEq)]
struct FakeJsonMessage {
    seq: Option<i64>,
    note: String,
}

impl ToValue for FakeJsonMessage {
    fn to_value(&self) -> Result<Value, EncodeError> {
        let mut map = BTreeMap::from([
            (
                "$type".to_owned(),
                Value::String("com.example.jsonStream#event".to_owned()),
            ),
            ("note".to_owned(), Value::String(self.note.clone())),
        ]);
        if let Some(seq) = self.seq {
            map.insert("seq".to_owned(), Value::Integer(seq));
        }
        Ok(Value::Object(map))
    }
}

impl FromValue for FakeJsonMessage {
    fn from_value(value: Value) -> Result<Self, DecodeError> {
        let mut reader = petrel_core::ObjectReader::new(value)?;
        Ok(Self {
            seq: reader.optional("seq")?,
            note: reader.required("note")?,
        })
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
enum FakeError {
    TooSlow,
    Unknown(String),
}

impl DeclaredXrpcError for FakeError {
    fn from_wire_name(name: &str) -> Self {
        match name {
            "TooSlow" => Self::TooSlow,
            other => Self::Unknown(other.to_owned()),
        }
    }

    fn wire_name(&self) -> &str {
        match self {
            Self::TooSlow => "TooSlow",
            Self::Unknown(other) => other.as_str(),
        }
    }

    fn is_declared(&self) -> bool {
        !matches!(self, Self::Unknown(_))
    }
}

struct FakeJsonSubscription;
impl XrpcSubscription for FakeJsonSubscription {
    const NSID: &'static str = "com.example.jsonStream";
    const SUBPROTOCOL: Option<&'static str> = Some(XRPC_V1_JSON_SUBPROTOCOL);
    const KNOWN_MESSAGE_TYPES: &'static [&'static str] = &["com.example.jsonStream#event"];
    type Params = ();
    type Message = FakeJsonMessage;
    type Error = FakeError;
}

struct FakeUnsupportedSubscription;
impl XrpcSubscription for FakeUnsupportedSubscription {
    const NSID: &'static str = "com.example.futureStream";
    const SUBPROTOCOL: Option<&'static str> = Some("xrpc.v9.future");
    const KNOWN_MESSAGE_TYPES: &'static [&'static str] = &[];
    type Params = ();
    type Message = FakeJsonMessage;
    type Error = FakeError;
}

fn assert_params_bound<P: ToQueryParams>() {}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn dispatches_xrpc_v1_json_and_rejects_unknown_subprotocols() {
    assert_params_bound::<<FakeJsonSubscription as XrpcSubscription>::Params>();

    let msg = FakeJsonMessage {
        seq: Some(42),
        note: "hello".to_owned(),
    };
    let wire = encode_subscription_message::<FakeJsonSubscription>(&msg).unwrap();
    let json: serde_json::Value = serde_json::from_slice(&wire).unwrap();
    assert_eq!(json["$type"], "message");
    assert_eq!(json["payload"]["$type"], "com.example.jsonStream#event");
    assert_eq!(json["payload"]["seq"], 42);
    assert_eq!(json["payload"]["note"], "hello");

    assert_eq!(
        decode_subscription_frame::<FakeJsonSubscription>(&wire).unwrap(),
        DecodedSubscriptionFrame::Message {
            message: msg.clone(),
            message_type: "com.example.jsonStream#event".to_owned(),
            sequence: Some(42),
        }
    );

    let err_wire =
        encode_subscription_error::<FakeJsonSubscription>(&FakeError::TooSlow, Some("lag"))
            .unwrap();
    assert_eq!(
        decode_subscription_frame::<FakeJsonSubscription>(&err_wire).unwrap(),
        DecodedSubscriptionFrame::Error {
            error: FakeError::TooSlow,
            message: Some("lag".to_owned()),
        }
    );

    let unknown_payload = br##"{"$type":"message","payload":{"$type":"#future","seq":7}}"##;
    assert!(matches!(
        decode_subscription_frame::<FakeJsonSubscription>(unknown_payload).unwrap(),
        DecodedSubscriptionFrame::UnknownMessageType {
            message_type,
            sequence: Some(7),
            ..
        } if message_type == "com.example.jsonStream#future"
    ));

    let unknown_envelope = br#"{"$type":"keepalive","ts":1}"#;
    assert!(matches!(
        decode_subscription_frame::<FakeJsonSubscription>(unknown_envelope).unwrap(),
        DecodedSubscriptionFrame::UnknownMessageType {
            message_type,
            sequence: None,
            ..
        } if message_type == "keepalive"
    ));

    // DAG-CBOR bytes must fail against xrpc.v1.json subscriptions.
    let cbor_wire = encode_frame(&SubscriptionFrame::Error {
        error: "TooSlow".to_owned(),
        message: None,
    })
    .unwrap();
    assert!(matches!(
        decode_subscription_frame::<FakeJsonSubscription>(&cbor_wire),
        Err(FrameError::Decode(_))
    ));

    assert_eq!(
        decode_subscription_frame::<FakeUnsupportedSubscription>(b"{}"),
        Err(FrameError::UnsupportedSubprotocol("xrpc.v9.future"))
    );
    assert_eq!(
        encode_subscription_message::<FakeUnsupportedSubscription>(&msg),
        Err(FrameError::UnsupportedSubprotocol("xrpc.v9.future"))
    );
    assert_eq!(
        encode_subscription_error::<FakeUnsupportedSubscription>(&FakeError::TooSlow, None),
        Err(FrameError::UnsupportedSubprotocol("xrpc.v9.future"))
    );
}
