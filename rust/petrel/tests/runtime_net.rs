#![cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]

use bytes::Bytes;
use http::{Method, Request};
use petrel::net::{RequestKey, ServerSentEvent, ServerSentEventParser, SseError};

#[cfg(not(target_arch = "wasm32"))]
use std::{
    future::ready,
    sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    },
};

#[cfg(not(target_arch = "wasm32"))]
use http::{HeaderMap, Response, StatusCode};
#[cfg(not(target_arch = "wasm32"))]
use petrel::{
    media::ImageMetadataStripper,
    net::{
        HttpTransport, RequestDeduplicator, SendOptions, TransportError,
        sse::{events_via_transport, fetch_events},
    },
    xrpc::{CallOptions, XrpcClient, XrpcLabeler},
};
#[cfg(not(target_arch = "wasm32"))]
use url::Url;

#[cfg(not(target_arch = "wasm32"))]
struct MockTransport<F>(F);

#[cfg(not(target_arch = "wasm32"))]
impl<F> HttpTransport for MockTransport<F>
where
    F: Fn(&Request<Bytes>, &SendOptions) -> Result<Response<Bytes>, TransportError>
        + petrel::rt::MaybeSend
        + petrel::rt::MaybeSync,
{
    fn send(
        &self,
        request: Request<Bytes>,
        options: &SendOptions,
    ) -> impl std::future::Future<Output = Result<Response<Bytes>, TransportError>> + petrel::rt::MaybeSend
    {
        ready((self.0)(&request, options))
    }
}

fn get_request(headers: &[(&str, &str)]) -> Request<Bytes> {
    let mut builder = Request::builder()
        .method(Method::GET)
        .uri("https://pds.example.com/xrpc/app.bsky.feed.getTimeline");
    for &(name, value) in headers {
        builder = builder.header(name, value);
    }
    builder.body(Bytes::new()).unwrap()
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn request_key_partitioning_matches_swift_parity() {
    let key = |headers: &[(&str, &str)], ignored: &[&str]| {
        RequestKey::from_request(&get_request(headers), Some("did:plc:user"), ignored)
    };

    let base = key(
        &[("atproto-proxy", "did:web:api.bsky.app#bsky_appview")],
        &[],
    );
    assert!(base.is_some());
    assert_ne!(
        base,
        key(
            &[("atproto-proxy", "did:web:other.example.com#bsky_appview")],
            &[]
        )
    );
    assert_ne!(base, key(&[], &[]));
    assert_ne!(
        key(&[("atproto-accept-labelers", "did:plc:a")], &[]),
        key(&[("atproto-accept-labelers", "did:plc:b")], &[])
    );
    assert_ne!(
        key(&[("X-Widget-Variant", "a")], &[]),
        key(&[("X-Widget-Variant", "b")], &[])
    );

    // Authorization, DPoP, and ignored x-request-id do not split keys.
    let first = key(
        &[
            ("atproto-proxy", "did:web:api.bsky.app#bsky_appview"),
            ("Authorization", "DPoP token-1"),
            ("DPoP", "proof-1"),
            ("X-Request-Id", "11111111-1111-1111-1111-111111111111"),
        ],
        &["x-request-id"],
    );
    let second = key(
        &[
            ("atproto-proxy", "did:web:api.bsky.app#bsky_appview"),
            ("Authorization", "DPoP token-1"),
            ("DPoP", "proof-2"),
            ("X-Request-Id", "22222222-2222-2222-2222-222222222222"),
        ],
        &["X-REQUEST-ID"],
    );
    assert_eq!(first, second);

    // Unconfigured X-Request-Id splits keys.
    assert_ne!(
        key(&[("X-Request-Id", "a")], &[]),
        key(&[("X-Request-Id", "b")], &[])
    );

    // Header names are matched case-insensitively.
    assert_eq!(
        key(&[("Atproto-Proxy", "did:web:x#y")], &[]),
        key(&[("atproto-proxy", "did:web:x#y")], &[])
    );

    // Non-GET/HEAD requests do not deduplicate.
    let post = Request::builder()
        .method(Method::POST)
        .uri("https://pds.example.com/xrpc/app.bsky.feed.post")
        .body(Bytes::new())
        .unwrap();
    assert!(RequestKey::from_request(&post, Some("did:plc:user"), &[]).is_none());
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn request_key_redacts_debug_and_isolates_auth_states() {
    let secret_token = "Bearer super-secret-oauth-token-123";
    let secret_cookie = "sid=top-secret-cookie";
    let authed_req = get_request(&[
        ("Authorization", secret_token),
        ("Cookie", secret_cookie),
        ("atproto-proxy", "did:web:api.bsky.app#bsky_appview"),
    ]);
    let authed_key = RequestKey::from_request(&authed_req, None, &[]).unwrap();

    // Debug output must redact `auth_identity` and header values, and never retain raw token.
    let debug_str = format!("{authed_key:?}");
    assert!(!debug_str.contains(secret_token));
    assert!(!debug_str.contains("super-secret-oauth-token-123"));
    assert!(!debug_str.contains(secret_cookie));
    assert_ne!(authed_key.auth_identity.as_deref(), Some(secret_token));

    // Different `Authorization` tokens (when `auth_identity` is None) must not collide.
    let other_token_req = get_request(&[
        ("Authorization", "Bearer different-token-456"),
        ("Cookie", secret_cookie),
        ("atproto-proxy", "did:web:api.bsky.app#bsky_appview"),
    ]);
    let other_token_key = RequestKey::from_request(&other_token_req, None, &[]).unwrap();
    assert_ne!(authed_key, other_token_key);

    // Pre-auth (no Authorization) vs authenticated (with Authorization) never coalesce even if
    // the same DID is supplied, and different accounts never coalesce.
    let pre_auth_req = get_request(&[("atproto-proxy", "did:web:api.bsky.app#bsky_appview")]);
    let with_auth_req = get_request(&[
        ("Authorization", secret_token),
        ("atproto-proxy", "did:web:api.bsky.app#bsky_appview"),
    ]);
    let alice_pre = RequestKey::from_request(&pre_auth_req, Some("did:plc:alice"), &[]).unwrap();
    let alice_authed =
        RequestKey::from_request(&with_auth_req, Some("did:plc:alice"), &[]).unwrap();
    let bob_authed = RequestKey::from_request(&with_auth_req, Some("did:plc:bob"), &[]).unwrap();
    let anon = RequestKey::from_request(&pre_auth_req, None, &[]).unwrap();
    assert_ne!(alice_pre, alice_authed);
    assert_ne!(alice_authed, bob_authed);
    assert_ne!(alice_pre, anon);
}

#[cfg_attr(not(target_arch = "wasm32"), test)]
#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
fn sse_parser_whatwg_parity() {
    let parse_chunks = |chunks: &[&[u8]]| -> Result<Vec<ServerSentEvent>, SseError> {
        let mut parser = ServerSentEventParser::default();
        let mut out = Vec::new();
        for chunk in chunks {
            out.extend(parser.consume(chunk)?);
        }
        Ok(out)
    };

    let events =
        parse_chunks(&[b"data: {\"a\":1}\n\nevent: tick\ndata:first\ndata: second\nid: 7\n\n"])
            .unwrap();
    assert_eq!(
        events,
        vec![
            ServerSentEvent {
                event_type: "message".to_owned(),
                data: "{\"a\":1}".to_owned(),
                last_event_id: String::new(),
            },
            ServerSentEvent {
                event_type: "tick".to_owned(),
                data: "first\nsecond".to_owned(),
                last_event_id: "7".to_owned(),
            },
        ]
    );

    // CR, LF, CRLF across chunk boundaries.
    let line_endings =
        parse_chunks(&[b"data: a\r\n\r\ndata: b\r\r", b"data: c\r", b"\n\r", b"\n"]).unwrap();
    let datas: Vec<&str> = line_endings.iter().map(|e| e.data.as_str()).collect();
    assert_eq!(datas, vec!["a", "b", "c"]);

    // Split multi-byte UTF-8 across chunks.
    let raw = "data: café \u{1F426}\n\n".as_bytes();
    let split = raw.iter().position(|&b| b == 0xC3).unwrap() + 1;
    let utf8_events = parse_chunks(&[&raw[..split], &raw[split..]]).unwrap();
    assert_eq!(utf8_events.len(), 1);
    assert_eq!(utf8_events[0].data, "café \u{1F426}");

    // BOM, comments, unknown fields, and unterminated trailing event.
    let ignored_input = [
        &[0xEF_u8, 0xBB, 0xBF][..],
        b": keep-alive\n\nretry: 10\nfoo: bar\n\ndata: x\n\ndata: cut",
    ]
    .concat();
    let ignored = parse_chunks(&[&ignored_input]).unwrap();
    assert_eq!(ignored.len(), 1);
    assert_eq!(ignored[0].data, "x");

    // Maximum event bytes enforced.
    let mut small = ServerSentEventParser::new(16);
    assert!(matches!(
        small.consume(b"data: 0123456789\ndata: 0123456789\n\n"),
        Err(SseError::EventTooLarge { limit: 16 })
    ));
}

#[cfg(not(target_arch = "wasm32"))]
#[tokio::test]
async fn request_deduplicator_coalesces_concurrent_gets_and_isolates_proxies() {
    let deduplicator = Arc::new(RequestDeduplicator::new());
    let executed = Arc::new(AtomicUsize::new(0));
    let joined = Arc::new(AtomicUsize::new(0));
    let notify = Arc::new(tokio::sync::Notify::new());

    let req1 = get_request(&[("X-Request-Id", "11111111-1111-1111-1111-111111111111")]);
    let req2 = get_request(&[("X-Request-Id", "22222222-2222-2222-2222-222222222222")]);

    let d1 = Arc::clone(&deduplicator);
    let e1 = Arc::clone(&executed);
    let n1 = Arc::clone(&notify);
    let h1 = tokio::spawn(async move {
        d1.deduplicate(
            &req1,
            Some("did:plc:user"),
            &["X-Request-Id"],
            move || async move {
                e1.fetch_add(1, Ordering::SeqCst);
                n1.notified().await;
                Ok(Response::builder()
                    .status(StatusCode::OK)
                    .body(Bytes::from_static(b"shared"))
                    .unwrap())
            },
        )
        .await
    });

    while executed.load(Ordering::SeqCst) == 0 {
        tokio::task::yield_now().await;
    }
    assert!(
        deduplicator
            .is_request_in_flight(&req2, Some("did:plc:user"), &["X-Request-Id"])
            .await
    );

    let d2 = Arc::clone(&deduplicator);
    let e2 = Arc::clone(&executed);
    let j2 = Arc::clone(&joined);
    let h2 = tokio::spawn(async move {
        d2.deduplicate_with_hook(
            &req2,
            Some("did:plc:user"),
            &["X-Request-Id"],
            move || {
                j2.fetch_add(1, Ordering::SeqCst);
            },
            move || async move {
                e2.fetch_add(1, Ordering::SeqCst);
                Ok(Response::builder()
                    .status(StatusCode::OK)
                    .body(Bytes::from_static(b"second"))
                    .unwrap())
            },
        )
        .await
    });

    let (ra, rb) = {
        while joined.load(Ordering::SeqCst) == 0 {
            tokio::task::yield_now().await;
        }
        notify.notify_waiters();
        tokio::join!(h1, h2)
    };
    assert_eq!(ra.unwrap().unwrap().body(), &Bytes::from_static(b"shared"));
    assert_eq!(rb.unwrap().unwrap().body(), &Bytes::from_static(b"shared"));
    assert_eq!(executed.load(Ordering::SeqCst), 1);

    // Different proxies do not coalesce.
    let appview = get_request(&[("atproto-proxy", "did:web:api.bsky.app#bsky_appview")]);
    let other = get_request(&[("atproto-proxy", "did:web:other.example.com#bsky_appview")]);
    let (a, b) = tokio::join!(
        deduplicator.deduplicate(&appview, Some("did:plc:user"), &[], || async {
            Ok(Response::new(Bytes::from_static(b"appview")))
        }),
        deduplicator.deduplicate(&other, Some("did:plc:user"), &[], || async {
            Ok(Response::new(Bytes::from_static(b"other")))
        }),
    );
    assert_eq!(a.unwrap().body(), &Bytes::from_static(b"appview"));
    assert_eq!(b.unwrap().body(), &Bytes::from_static(b"other"));
}

#[cfg(not(target_arch = "wasm32"))]
#[tokio::test]
async fn sse_transport_validates_headers_and_refuses_redirects() {
    use futures_util::StreamExt;

    let transport = MockTransport(|req: &Request<Bytes>, _: &SendOptions| {
        let path = req.uri().path();
        match path {
            "/events" => Ok(Response::builder()
                .status(StatusCode::OK)
                .header("Content-Type", "text/event-stream; charset=utf-8")
                .body(Bytes::from_static(
                    b"data: {\"seq\":1}\n\n: ping\n\ndata: {\"seq\":2}\n\n",
                ))
                .unwrap()),
            "/json" => Ok(Response::builder()
                .status(StatusCode::OK)
                .header("Content-Type", "application/json")
                .body(Bytes::from_static(b"data: {}\n\n"))
                .unwrap()),
            "/fail" => Ok(Response::builder()
                .status(StatusCode::INTERNAL_SERVER_ERROR)
                .header("Content-Type", "text/event-stream")
                .body(Bytes::from_static(b"data: {}\n\n"))
                .unwrap()),
            "/redirect" => Ok(Response::builder()
                .status(StatusCode::FOUND)
                .header("Location", "https://example.com/events")
                .body(Bytes::new())
                .unwrap()),
            _ => unreachable!(),
        }
    });

    let opts = SendOptions::new();
    let ok_req = Request::builder()
        .uri("https://pds.example.com/events")
        .body(Bytes::new())
        .unwrap();
    let events = fetch_events(&transport, ok_req, &opts, 1024 * 1024)
        .await
        .unwrap();
    assert_eq!(events.len(), 2);
    assert_eq!(events[0].data, r#"{"seq":1}"#);
    assert_eq!(events[1].data, r#"{"seq":2}"#);

    let stream_req = Request::builder()
        .uri("https://pds.example.com/events")
        .body(Bytes::new())
        .unwrap();
    let streamed: Vec<_> = events_via_transport(&transport, stream_req, &opts, 1024)
        .collect()
        .await;
    assert_eq!(streamed.len(), 2);

    let json_req = Request::builder()
        .uri("https://pds.example.com/json")
        .body(Bytes::new())
        .unwrap();
    assert!(matches!(
        fetch_events(&transport, json_req, &opts, 1024).await,
        Err(SseError::InvalidContentType { .. })
    ));

    let fail_req = Request::builder()
        .uri("https://pds.example.com/fail")
        .body(Bytes::new())
        .unwrap();
    assert!(matches!(
        fetch_events(&transport, fail_req, &opts, 1024).await,
        Err(SseError::HttpStatus {
            status: StatusCode::INTERNAL_SERVER_ERROR
        })
    ));

    let redir_req = Request::builder()
        .uri("https://pds.example.com/redirect")
        .body(Bytes::new())
        .unwrap();
    assert!(matches!(
        fetch_events(&transport, redir_req, &opts, 1024).await,
        Err(SseError::InvalidContentType { .. } | SseError::HttpStatus { .. })
    ));
}

#[cfg(not(target_arch = "wasm32"))]
#[tokio::test]
async fn native_sse_client_validates_dns_answers_and_strips_anonymous_headers() {
    use std::net::IpAddr;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};

    struct StaticDns(Vec<IpAddr>);
    impl petrel::identity::DnsResolver for StaticDns {
        fn txt(
            &self,
            _name: &str,
        ) -> impl std::future::Future<Output = Result<Vec<String>, petrel::identity::DnsError>> + Send
        {
            ready(Ok(Vec::new()))
        }

        fn lookup_ip(
            &self,
            _host: &str,
        ) -> impl std::future::Future<Output = Result<Vec<IpAddr>, petrel::identity::DnsError>> + Send
        {
            ready(Ok(self.0.clone()))
        }
    }

    // 1. Non-literal HTTPS host resolving to private/loopback IP must fail policy before connecting.
    for addr in ["127.0.0.1".parse().unwrap(), "10.0.0.1".parse().unwrap()] {
        let client = petrel::net::sse::NativeSseClient::new(StaticDns(vec![addr])).unwrap();
        let req = Request::builder()
            .uri("https://evil.example/events")
            .body(Bytes::new())
            .unwrap();
        let err = client
            .connect(req, &SendOptions::new(), 1024)
            .await
            .unwrap_err();
        assert!(matches!(
            err,
            SseError::Transport(TransportError::PolicyViolation(_))
        ));
    }

    // 2. `SendOptions { anonymous: true, .. }` strips Authorization, Cookie, and DPoP headers.
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    let server = tokio::spawn(async move {
        let (mut sock, _) = listener.accept().await.unwrap();
        let mut buf = vec![0_u8; 4096];
        let n = sock.read(&mut buf).await.unwrap();
        let raw_req = String::from_utf8_lossy(&buf[..n]).to_string();
        sock.write_all(
            b"HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nConnection: close\r\n\r\ndata: ok\n\n",
        )
        .await
        .unwrap();
        raw_req
    });

    let sse = petrel::net::sse::NativeSseClient::system().unwrap();
    let req = Request::builder()
        .uri(format!("http://{addr}/events"))
        .header("accept", "text/event-stream")
        .header("authorization", "Bearer secret-token")
        .header("cookie", "sid=secret")
        .header("dpop", "secret-proof")
        .header("x-custom", "strip-non-allowlisted")
        .body(Bytes::new())
        .unwrap();
    let mut opts = SendOptions::new();
    opts.allow_loopback = true;
    opts.anonymous = true;
    let mut stream = sse.connect(req, &opts, 1024).await.unwrap();
    let ev = stream.next_event().await.unwrap().unwrap();
    assert_eq!(ev.data, "ok");
    let raw_req = server.await.unwrap().to_ascii_lowercase();
    assert!(!raw_req.contains("authorization:"));
    assert!(!raw_req.contains("cookie:"));
    assert!(!raw_req.contains("dpop:"));
    assert!(!raw_req.contains("x-custom:"));
    assert!(raw_req.contains("accept: text/event-stream"));
}

#[cfg(not(target_arch = "wasm32"))]
#[tokio::test]
async fn labelers_empty_list_sends_empty_header_and_upload_blob_checks_mime_and_size() {
    let seen_headers = Arc::new(std::sync::Mutex::new(Vec::<HeaderMap>::new()));
    let seen_ref = Arc::clone(&seen_headers);
    let transport = Arc::new(MockTransport(
        move |req: &Request<Bytes>, _: &SendOptions| {
            seen_ref.lock().unwrap().push(req.headers().clone());
            if req.uri().path().ends_with("uploadBlob") {
                Ok(Response::builder()
                .status(StatusCode::OK)
                .header("Content-Type", "application/json")
                .body(Bytes::from_static(
                    br#"{"blob":{"$type":"blob","ref":{"$link":"bafkreiccldh766hwcnuxnf2wh6jgzepf2nlu2lvcllt63eww5p6chi4ity"},"mimeType":"image/png","size":8}}"#,
                ))
                .unwrap())
            } else {
                Ok(Response::builder()
                    .status(StatusCode::OK)
                    .header("Content-Type", "application/json")
                    .body(Bytes::from_static(b"{}"))
                    .unwrap())
            }
        },
    ));

    let client =
        XrpcClient::new(Url::parse("https://pds.example.com").unwrap(), transport).unwrap();

    // Empty accept_labelers explicitly sends empty header value "".
    let opts_empty = CallOptions {
        accept_labelers: Some(Vec::new()),
        ..CallOptions::default()
    };
    client
        .query("app.bsky.feed.getTimeline", [("limit", "5")], &opts_empty)
        .await
        .unwrap();
    {
        let headers = seen_headers.lock().unwrap();
        assert_eq!(
            headers[0]
                .get("atproto-accept-labelers")
                .and_then(|v| v.to_str().ok()),
            Some("")
        );
    }

    // Deduplication preserves order and prefers redact=true.
    let deduped = XrpcLabeler::parse_header(
        "did:plc:ar7c4by46qjdydhdevvrndac, invalid-did, did:plc:ar7c4by46qjdydhdevvrndac;redact, did:plc:ewvi7nxzyoun6zhxrhs64oiz",
    );
    assert_eq!(deduped.len(), 2);
    assert!(deduped[0].redact);
    assert!(!deduped[1].redact);

    // upload_blob rejects oversized blobs and invalid MIME types before hitting transport.
    assert!(
        client
            .upload_blob(
                Bytes::from_static(b"123456"),
                "image/png",
                Some(5),
                &CallOptions::default()
            )
            .await
            .is_err()
    );
    assert!(
        client
            .upload_blob(
                Bytes::from_static(b"123"),
                "not-a-mime",
                None,
                &CallOptions::default()
            )
            .await
            .is_err()
    );

    let out = client
        .upload_blob(
            Bytes::from_static(b"12345678"),
            "image/png",
            Some(1024),
            &CallOptions::default(),
        )
        .await
        .unwrap();
    assert!(matches!(
        out.blob,
        petrel_core::Blob::Typed { ref mime_type, size: 8, .. } if mime_type == "image/png"
    ));
    assert_eq!(ImageMetadataStripper::strip_sniffed(b"not-an-image"), None);
}

#[cfg(not(target_arch = "wasm32"))]
mod debug_fixture_tests {
    use petrel::net::debug_fixture::{DebugFixtureTransport, FixtureTunnel, HostPolicy};
    use url::Url;

    fn sample_cert() -> Vec<u8> {
        vec![0x30, 0x82, 0x01, 0x00]
    }

    fn sample_manifest() -> serde_json::Value {
        serde_json::json!({
            "fixtureOnly": true,
            "origin": "https://gateway-test.request-fixture.catbird.blue",
            "corsOrigin": "http://127.0.0.1:5173",
            "caPem": "/fixture/ca.pem",
            "tlsCertificatePem": "/fixture/server.pem",
            "tlsSpkiSha256": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
            "hosts": {
                "gateway-test.request-fixture.catbird.blue": "127.0.0.1:34567",
                "alice-test.request-fixture.catbird.blue": "127.0.0.1:34567",
                "bob-test.request-fixture.catbird.blue": "127.0.0.1:34567",
                "chat.catbird.blue": "127.0.0.1:34567",
                "public.api.bsky.app": "127.0.0.1:34567",
            },
            "accounts": [
                {
                    "label": "alice",
                    "did": "did:web:alice-test.request-fixture.catbird.blue",
                    "deviceId": "00000000-0000-4000-8000-000000000001"
                },
                {
                    "label": "bob",
                    "did": "did:web:bob-test.request-fixture.catbird.blue",
                    "deviceId": "00000000-0000-4000-8000-000000000002"
                }
            ]
        })
    }

    fn legacy_policy() -> HostPolicy {
        HostPolicy::new(
            "request-fixture.catbird.blue",
            [
                "chat.catbird.blue".to_owned(),
                "public.api.bsky.app".to_owned(),
            ],
            std::iter::empty::<String>(),
        )
        .unwrap()
    }

    #[test]
    fn host_policy_validation_and_manifest_scoping() {
        for bad in [
            "",
            ".example.com",
            "Example.com",
            "example..com",
            "-x.example.com",
            "example.com.",
        ] {
            assert!(HostPolicy::new(bad, [], []).is_err(), "{bad}");
        }
        assert!(HostPolicy::new("fx.example.com", ["CHAT.example.com".to_owned()], []).is_err());
        assert!(HostPolicy::new("fx.example.com", ["a.fx.example.com".to_owned()], []).is_err());

        let manifest_bytes = serde_json::to_vec(&sample_manifest()).unwrap();
        let transport =
            DebugFixtureTransport::from_manifest(&manifest_bytes, &sample_cert(), &legacy_policy())
                .unwrap();

        assert!(
            transport
                .permits(&Url::parse("https://chat.catbird.blue/.well-known/did.json").unwrap())
        );
        for denied in [
            "https://example.com",
            "http://chat.catbird.blue",
            "https://chat.catbird.blue:444",
            "https://user@chat.catbird.blue",
            "https://chat.catbird.blue/#fragment",
            "https://127.0.0.1",
        ] {
            assert!(!transport.permits(&Url::parse(denied).unwrap()), "{denied}");
        }
        assert_eq!(transport.accounts().len(), 2);
        assert!(
            transport
                .approved_addresses(&Url::parse("https://chat.catbird.blue/x").unwrap())
                .is_ok()
        );
    }

    #[test]
    fn duplicate_json_keys_and_nonlocal_manifests_rejected() {
        let mut manifest = sample_manifest();
        manifest["fixtureOnly"] = serde_json::json!(false);
        assert!(
            DebugFixtureTransport::from_manifest(
                &serde_json::to_vec(&manifest).unwrap(),
                &sample_cert(),
                &legacy_policy(),
            )
            .is_err()
        );

        let text = serde_json::to_string(&sample_manifest()).unwrap();
        let dup = format!("{{\"fixtureOnly\":true,{}", &text[1..]);
        assert!(
            DebugFixtureTransport::from_manifest(dup.as_bytes(), &sample_cert(), &legacy_policy())
                .is_err()
        );

        let nested = text.replacen(
            "\"label\":\"alice\"",
            "\"label\":\"alice\",\"label\":\"alice\"",
            1,
        );
        assert_ne!(nested, text);
        assert!(
            DebugFixtureTransport::from_manifest(
                nested.as_bytes(),
                &sample_cert(),
                &legacy_policy()
            )
            .is_err()
        );
    }

    #[test]
    fn connect_tunnel_validation_matches_urlsession_and_rejects_smuggling() {
        assert_eq!(
            FixtureTunnel::authority(
                b"CONNECT chat.catbird.blue:443 HTTP/1.1\r\nHost: chat.catbird.blue:443\r\n\r\n"
            )
            .unwrap(),
            "chat.catbird.blue"
        );
        assert_eq!(
            FixtureTunnel::authority(
                b"CONNECT chat.catbird.blue:443 HTTP/1.1\r\nHost: chat.catbird.blue\r\nProxy-Connection: keep-alive\r\nConnection: keep-alive\r\n\r\n"
            )
            .unwrap(),
            "chat.catbird.blue"
        );

        for rejected in [
            &b"GET chat.catbird.blue:443 HTTP/1.1\r\nHost: chat.catbird.blue:443\r\n\r\n"[..],
            b"CONNECT chat.catbird.blue:444 HTTP/1.1\r\nHost: chat.catbird.blue\r\n\r\n",
            b"CONNECT chat.catbird.blue:443 HTTP/1.1\r\nHost: other.catbird.blue\r\n\r\n",
            b"CONNECT chat.catbird.blue:443 HTTP/1.1\r\nHost: chat.catbird.blue\r\nHost: chat.catbird.blue:443\r\n\r\n",
            b"CONNECT chat.catbird.blue:443 HTTP/1.1\r\nHost: chat.catbird.blue:443\r\nContent-Length: 2\r\n\r\n",
            b"CONNECT chat.catbird.blue:443 HTTP/1.1\r\nHost: chat.catbird.blue:443\r\n\r\ntrailing",
        ] {
            assert!(FixtureTunnel::authority(rejected).is_err());
        }
    }
}
