use petrel_core::xrpc::{self, QueryValue};
use petrel_core::{
    AtIdentifier, Cid, Datetime, Handle, Language, RateLimit, RecordKeyType, XrpcErrorBody,
};

#[test]
fn query_pairs_preserve_repetition_presence_and_wire_values() {
    let mut pairs = Vec::new();
    let cid = Cid::for_raw(b"bytes");
    let date = Datetime::parse("2000-01-01T01:20:30.00123+01:00").unwrap();
    let language = Language::parse("pt-BR").unwrap();
    let handle = Handle::parse("Alice.Example.COM").unwrap();
    xrpc::push_array_param(
        &mut pairs,
        "actors",
        &[
            AtIdentifier::from(handle.clone()),
            AtIdentifier::parse("did:plc:abc").unwrap(),
        ],
    );
    xrpc::push_optional_param(&mut pairs, "absent", None::<&String>);
    xrpc::push_param(&mut pairs, "cid", &cid);
    xrpc::push_param(&mut pairs, "date", &date);
    xrpc::push_param(&mut pairs, "lang", &language);
    xrpc::push_param(&mut pairs, "limit", &3_i64);
    xrpc::push_param(&mut pairs, "enabled", &true);

    assert_eq!(
        pairs,
        [
            ("actors", "alice.example.com".into()),
            ("actors", "did:plc:abc".into()),
            ("cid", cid.to_string()),
            ("date", date.as_str().into()),
            ("lang", "pt-BR".into()),
            ("limit", "3".into()),
            ("enabled", "true".into()),
        ]
    );
    assert_eq!(handle.as_str(), "Alice.Example.COM");
    assert_eq!(handle.to_query_value(), "alice.example.com");
}

#[test]
fn error_body_and_rate_limit() {
    let body = br#"{"error":"RateLimitExceeded","message":"Slow down"}"#;
    let parsed = XrpcErrorBody::parse(body).unwrap();
    assert_eq!(parsed.error, "RateLimitExceeded");
    assert_eq!(parsed.message.as_deref(), Some("Slow down"));
    assert_eq!(serde_json::to_vec(&parsed).unwrap(), body);
    assert!(XrpcErrorBody::parse(br#"{"message":"Missing error name"}"#).is_none());

    let rate = RateLimit::parse(|header| match header {
        "ratelimit-limit" => Some(" 100 "),
        "ratelimit-remaining" => Some("2"),
        "ratelimit-reset" => Some("1700000000.5"),
        "ratelimit-policy" => Some("100;w=300"),
        _ => None,
    })
    .unwrap();
    assert_eq!(rate.limit, 100);
    assert_eq!(rate.remaining, 2);
    assert!((rate.reset_unix_seconds - 1_700_000_000.5).abs() < f64::EPSILON);
    assert_eq!(rate.policy.as_deref(), Some("100;w=300"));
    assert!(
        RateLimit::parse(|name| Some(if name == "ratelimit-reset" {
            "NaN"
        } else {
            "1"
        }))
        .is_none()
    );
}

#[test]
fn collection_record_key_validation() {
    assert!(RecordKeyType::Tid.accepts("3jzfcijpj2z2a"));
    assert!(!RecordKeyType::Tid.accepts("self"));
    assert!(RecordKeyType::Nsid.accepts("com.example.Name"));
    assert!(RecordKeyType::Literal("self").accepts("self"));
    assert!(!RecordKeyType::Literal("self").accepts("Self"));
    assert!(!RecordKeyType::Any.accepts(".."));
    assert!(RecordKeyType::Other("future").accepts("key"));
}
