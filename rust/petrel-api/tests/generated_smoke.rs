#![cfg(all(feature = "app_bsky", feature = "com_atproto"))]

use petrel_api::generated::app::bsky::feed::get_timeline::{
    Output as GetTimelineOutput, Parameters as GetTimelineParams,
};
use petrel_api::generated::app::bsky::feed::post::{Post, ReplyRef};
use petrel_api::generated::com::atproto::repo::put_record::{Input as PutRecordInput, PutRecord};
use petrel_api::generated::com::atproto::repo::strong_ref::StrongRef;
use petrel_api::generated::com::atproto::server::get_service_auth::{
    GetServiceAuth, Output as GetServiceAuthOutput, Parameters as GetServiceAuthParams,
};
use petrel_core::xrpc::{CursorOutput, CursorParams};
use petrel_core::{
    Collection, DeclaredXrpcError, Nullable, RecordKeyType, ToQueryParams, Value, XrpcMethod,
    XrpcOutput, XrpcRequest, from_dag_cbor, from_json, to_dag_cbor, to_json,
};

#[test]
fn post_record_json_and_cbor_roundtrip_with_extra_data_and_lenient_optional() {
    let raw = br#"{"$type":"app.bsky.feed.post","createdAt":"2026-11-24T12:00:00Z","futureField":{"x":1},"langs":123,"text":"hello"}"#;
    let post: Post = from_json(raw).expect("lenient decode should succeed");
    assert_eq!(post.text, "hello");
    assert_eq!(post.langs, None);
    assert_eq!(<Post as Collection>::NSID, "app.bsky.feed.post");
    assert_eq!(<Post as Collection>::KEY, RecordKeyType::Tid);
    let extra = post.extra_data.as_ref().expect("extra_data kept");
    assert_eq!(
        extra["futureField"].as_object().unwrap()["x"],
        Value::Integer(1)
    );
    assert_eq!(extra["langs"], Value::Integer(123));

    let re_json = to_json(&post).expect("to_json");
    assert_eq!(re_json, raw);
    let cbor = to_dag_cbor(&post).expect("to_dag_cbor");
    let decoded_cbor: Post = from_dag_cbor(&cbor).expect("from_dag_cbor");
    assert_eq!(decoded_cbor, post);

    let strong = StrongRef::new(
        "at://did:plc:abc/app.bsky.feed.post/1".parse().unwrap(),
        "bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a"
            .parse()
            .unwrap(),
    );
    let _reply = ReplyRef::new(strong.clone(), strong);
}

#[test]
fn put_record_tri_state_swap_record() {
    let input_null = PutRecordInput {
        repo: "did:plc:abc".parse().unwrap(),
        collection: "app.bsky.feed.post".parse().unwrap(),
        rkey: "self".parse().unwrap(),
        validate: None,
        record: Value::Object(Default::default()),
        swap_record: Some(Nullable::Null),
        swap_commit: None,
    };
    let encoded = to_json(&input_null).unwrap();
    let decoded: PutRecordInput = from_json(&encoded).unwrap();
    assert_eq!(decoded.swap_record, Some(Nullable::Null));
    assert_eq!(<PutRecord as XrpcRequest>::METHOD, XrpcMethod::Procedure);
}

#[test]
fn get_service_auth_xrpc_surface() {
    assert_eq!(GetServiceAuth::NSID, "com.atproto.server.getServiceAuth");
    assert_eq!(GetServiceAuth::METHOD, XrpcMethod::Query);
    let params = GetServiceAuthParams::new("did:web:example.com".parse().unwrap());
    let mut pairs = Vec::new();
    params.to_query_params(&mut pairs);
    assert_eq!(pairs, [("aud", "did:web:example.com".to_owned())]);

    let out = GetServiceAuthOutput::from_body(br#"{"token":"jwt-abc"}"#).unwrap();
    assert_eq!(out.token, "jwt-abc");
    let err = <GetServiceAuth as XrpcRequest>::Error::from_wire_name("SomeUndeclaredError");
    assert!(!err.is_declared());
}

#[test]
fn get_timeline_implements_cursor_params_and_cursor_output() {
    let mut params = GetTimelineParams::new();
    assert_eq!(CursorParams::cursor(&params), None);
    params.set_cursor(Some("page-2".to_owned()));
    assert_eq!(CursorParams::cursor(&params), Some("page-2"));

    let out = GetTimelineOutput::from_body(br#"{"cursor":"page-3","feed":[]}"#).unwrap();
    assert_eq!(CursorOutput::cursor(&out), Some("page-3"));
}
