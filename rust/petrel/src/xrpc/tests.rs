use std::{
    sync::{
        Arc, Mutex,
        atomic::{AtomicUsize, Ordering},
    },
    time::Duration,
};

use bytes::Bytes;
use futures_util::StreamExt;
use http::{HeaderValue, Method, Request, Response, StatusCode};
use petrel_core::{
    Bytes as CoreBytes,
    error::DecodeError,
    xrpc::{
        CursorOutput, CursorParams, ToQueryParams, UndeclaredError, XrpcMethod, XrpcOutput,
        XrpcRequest,
    },
};
use url::Url;

use super::*;
use crate::{
    net::{
        SendOptions,
        test_support::{MockTransport, reply},
    },
    rt::BoxFuture,
};

type MockHandler =
    fn(&Request<Bytes>, &SendOptions, usize) -> Result<Response<Bytes>, TransportError>;

#[derive(Default)]
struct MockAuth {
    unauthorized: AtomicUsize,
    prepared: AtomicUsize,
    seen_nonces: Mutex<Vec<(String, String, AuthCtx)>>,
}

impl AuthProvider for MockAuth {
    fn prepare(
        &self,
        mut request: Request<Bytes>,
    ) -> BoxFuture<'_, Result<(Request<Bytes>, AuthCtx), AuthError>> {
        Box::pin(async move {
            let attempt = self.prepared.fetch_add(1, Ordering::Relaxed);
            request
                .headers_mut()
                .insert("authorization", HeaderValue::from_static("DPoP test"));
            request.headers_mut().insert(
                "dpop",
                HeaderValue::from_str(&format!("proof-{attempt}")).unwrap(),
            );
            Ok((
                request,
                AuthCtx {
                    did: Some("did:plc:abc".parse().unwrap()),
                    jkt: Some("test-key".to_owned()),
                    session_generation: Some([42; 32]),
                },
            ))
        })
    }

    fn refresh_if_needed(&self) -> BoxFuture<'_, Result<(), AuthError>> {
        Box::pin(async { Ok(()) })
    }

    fn handle_unauthorized<'a>(
        &'a self,
        _response: &'a Response<Bytes>,
        _ctx: &'a AuthCtx,
    ) -> BoxFuture<'a, Result<UnauthorizedAction, AuthError>> {
        self.unauthorized.fetch_add(1, Ordering::Relaxed);
        Box::pin(async { Ok(UnauthorizedAction::Retry) })
    }

    fn update_dpop_nonce<'a>(
        &'a self,
        origin: &'a str,
        nonce: &'a str,
        ctx: &'a AuthCtx,
    ) -> BoxFuture<'a, ()> {
        self.seen_nonces
            .lock()
            .unwrap()
            .push((origin.to_owned(), nonce.to_owned(), ctx.clone()));
        Box::pin(async {})
    }
}

#[derive(Default)]
struct MockSleeper(Mutex<Vec<Duration>>);

impl Sleeper for MockSleeper {
    fn sleep(&self, duration: Duration) -> BoxFuture<'_, ()> {
        self.0.lock().unwrap().push(duration);
        Box::pin(async {})
    }
}

fn client(mock: Arc<MockTransport<MockHandler>>) -> XrpcClient {
    XrpcClient::new(Url::parse("https://pds.example.com").unwrap(), mock).unwrap()
}

const EMPTY: [(&str, &str); 0] = [];

#[tokio::test]
async fn nonce_retry_has_one_fresh_proof_and_records_nonce_with_context() {
    let mock = Arc::new(MockTransport::<MockHandler>::new(|_, _, ordinal| {
        let mut response = if ordinal == 0 {
            let mut response = reply(401, b"");
            response.headers_mut().insert(
                "www-authenticate",
                HeaderValue::from_static(r#"DPoP error="use_dpop_nonce""#),
            );
            response
        } else {
            reply(200, b"{}")
        };
        response.headers_mut().insert(
            "DPoP-Nonce",
            HeaderValue::from_static(if ordinal == 0 { "challenge" } else { "next" }),
        );
        Ok(response)
    }));
    let auth = Arc::new(MockAuth::default());
    client(mock.clone())
        .with_auth_provider(auth.clone())
        .query(
            "com.atproto.server.getSession",
            EMPTY,
            &CallOptions::default(),
        )
        .await
        .unwrap();

    let seen = mock.seen();
    assert_eq!(seen.len(), 2);
    assert_eq!(seen[0].0.headers()["dpop"], "proof-0");
    assert_eq!(seen[1].0.headers()["dpop"], "proof-1");
    let nonces = auth.seen_nonces.lock().unwrap();
    assert_eq!(nonces.len(), 2);
    assert_eq!(nonces[0].0, "https://pds.example.com");
    assert_eq!(nonces[0].1, "challenge");
    assert_eq!(nonces[1].1, "next");
    assert_eq!(nonces[0].2.did.as_ref().unwrap().as_str(), "did:plc:abc");
    assert_eq!(nonces[0].2.jkt.as_deref(), Some("test-key"));
    assert_eq!(nonces[0].2.session_generation, Some([42; 32]));
    assert!(format!("{:?}", nonces[0].2).contains("<redacted>"));
    assert_eq!(auth.unauthorized.load(Ordering::Relaxed), 0);
}

#[tokio::test]
async fn second_nonce_challenge_terminates_without_refresh() {
    let mock = Arc::new(MockTransport::<MockHandler>::new(|_, _, _| {
        let mut response = reply(401, br#"{"error":"use_dpop_nonce"}"#);
        response
            .headers_mut()
            .insert("dpop-nonce", HeaderValue::from_static("challenge"));
        Ok(response)
    }));
    let auth = Arc::new(MockAuth::default());
    let result = client(mock.clone())
        .with_auth_provider(auth.clone())
        .query(
            "com.atproto.server.getSession",
            EMPTY,
            &CallOptions::default(),
        )
        .await;
    assert!(matches!(result, Err(Error::MaxRetries)));
    assert_eq!(mock.seen().len(), 2);
    assert_eq!(auth.unauthorized.load(Ordering::Relaxed), 0);
}

#[tokio::test]
async fn proxied_service_error_does_not_refresh_the_pds_session() {
    let mock = Arc::new(MockTransport::<MockHandler>::new(|_, _, _| {
        Ok(reply(401, br#"{"error":"NotEnrolled"}"#))
    }));
    let auth = Arc::new(MockAuth::default());
    let result = client(mock.clone())
        .with_auth_provider(auth.clone())
        .query("chat.bsky.convo.listConvos", EMPTY, &CallOptions::default())
        .await;
    assert!(matches!(result, Err(Error::Xrpc(error)) if error.code == "NotEnrolled"));
    assert_eq!(mock.seen().len(), 1);
    assert_eq!(
        mock.seen()[0].0.headers()["atproto-proxy"],
        "did:web:api.bsky.chat#bsky_chat"
    );
    assert_eq!(auth.unauthorized.load(Ordering::Relaxed), 0);
}

#[tokio::test]
async fn expiry_error_requests_one_refresh_via_the_provider() {
    let mock = Arc::new(MockTransport::<MockHandler>::new(|_, _, ordinal| {
        Ok(if ordinal == 0 {
            reply(400, br#"{"error":"ExpiredToken"}"#)
        } else {
            reply(200, b"{}")
        })
    }));
    let auth = Arc::new(MockAuth::default());
    client(mock.clone())
        .with_auth_provider(auth.clone())
        .query(
            "com.atproto.server.getSession",
            EMPTY,
            &CallOptions::default(),
        )
        .await
        .unwrap();
    assert_eq!(mock.seen().len(), 2);
    assert_eq!(auth.unauthorized.load(Ordering::Relaxed), 1);
}

#[tokio::test]
async fn retries_only_safe_transient_responses_and_caps_attempts() {
    let mock = Arc::new(MockTransport::<MockHandler>::new(|_, _, _| {
        let mut resp = reply(503, b"");
        resp.headers_mut()
            .insert("retry-after", HeaderValue::from_static("2"));
        Ok(resp)
    }));
    let delays = Arc::new(MockSleeper::default());
    let client = client(mock.clone()).with_sleeper(delays.clone());
    assert!(
        client
            .query(
                "com.atproto.server.getSession",
                EMPTY,
                &CallOptions::default()
            )
            .await
            .is_err()
    );
    assert!(
        client
            .procedure(
                "com.atproto.repo.uploadBlob",
                EMPTY,
                None,
                &CallOptions::default()
            )
            .await
            .is_err()
    );

    let seen = mock.seen();
    assert_eq!(seen.len(), 4);
    assert_eq!(
        seen.iter()
            .filter(|(request, _)| request.method() == Method::GET)
            .count(),
        3
    );
    assert_eq!(*delays.0.lock().unwrap(), vec![Duration::from_secs(2); 2]);
}

#[tokio::test]
async fn never_retries_501_or_429_and_exposes_rate_limit() {
    for status in [501, 429] {
        let transport = Arc::new(MockTransport::new(
            move |_: &Request<Bytes>, _: &SendOptions, _| {
                let mut response = reply(status, b"");
                for (name, value) in [
                    ("ratelimit-limit", "300"),
                    ("ratelimit-remaining", "0"),
                    ("ratelimit-reset", "123"),
                ] {
                    response
                        .headers_mut()
                        .insert(name, HeaderValue::from_static(value));
                }
                Ok(response)
            },
        ));
        let delays = Arc::new(MockSleeper::default());
        let client = XrpcClient::new(
            Url::parse("https://pds.example.com").unwrap(),
            transport.clone(),
        )
        .unwrap()
        .with_sleeper(delays.clone());
        let result = client
            .query("app.bsky.feed.getTimeline", EMPTY, &CallOptions::default())
            .await;
        assert!(
            matches!(result, Err(Error::Xrpc(error)) if error.rate_limit().unwrap().limit == 300)
        );
        assert_eq!(transport.seen().len(), 1);
        assert!(delays.0.lock().unwrap().is_empty());
    }
}

#[tokio::test]
async fn request_building_uses_namespace_proxy_but_never_proxies_preferences_or_third_parties() {
    let transport = Arc::new(MockTransport::<MockHandler>::new(|_, _, _| {
        Ok(reply(200, b"{}"))
    }));
    let auth = Arc::new(MockAuth::default());
    let mut options = CallOptions::default();
    options
        .headers
        .insert("x-custom-client", HeaderValue::from_static("client-header"));
    let client = client(transport.clone())
        .with_auth_provider(auth.clone())
        .with_labelers(vec![XrpcLabeler {
            did: "did:plc:labeler".to_owned(),
            redact: true,
        }]);
    client
        .query(
            "app.bsky.feed.getTimeline",
            [
                ("q", "c++ & 1+1=2"),
                ("since", "2026-01-01T00:00:00+01:00"),
                ("cursor", "a+b/c=="),
            ],
            &options,
        )
        .await
        .unwrap();
    client
        .query("app.bsky.actor.getPreferences", EMPTY, &options)
        .await
        .unwrap();
    client
        .procedure(
            "app.bsky.actor.putPreferences",
            EMPTY,
            Some(XrpcBody::json("{}")),
            &options,
        )
        .await
        .unwrap();
    options.service = Some(Url::parse("https://pds.example.com:444").unwrap());
    client
        .query("app.bsky.feed.getTimeline", EMPTY, &options)
        .await
        .unwrap();
    options.service = Some(Url::parse("https://plc.directory").unwrap());
    client
        .query("com.atproto.identity.resolveHandle", EMPTY, &options)
        .await
        .unwrap();

    let seen = transport.seen();
    assert_eq!(
        seen[0].0.uri().query(),
        Some("q=c%2B%2B%20%26%201%2B1%3D2&since=2026-01-01T00:00:00%2B01:00&cursor=a%2Bb/c%3D%3D"),
    );
    assert_eq!(
        seen[0].0.headers()["atproto-proxy"],
        "did:web:api.bsky.app#bsky_appview"
    );
    assert_eq!(
        seen[0].0.headers()["atproto-accept-labelers"],
        "did:plc:labeler;redact"
    );
    assert!(!seen[1].0.headers().contains_key("atproto-proxy"));
    assert!(!seen[2].0.headers().contains_key("atproto-proxy"));
    for (request, options) in &seen[3..] {
        assert!(options.anonymous);
        for name in [
            "atproto-proxy",
            "atproto-accept-labelers",
            "dpop",
            "authorization",
            "x-custom-client",
        ] {
            assert!(
                !request.headers().contains_key(name),
                "{name} escaped origin policy"
            );
        }
    }
    assert_eq!(auth.prepared.load(Ordering::Relaxed), 3);
}

#[derive(Clone)]
struct PageParams(Option<String>);

impl ToQueryParams for PageParams {
    fn to_query_params(&self, pairs: &mut Vec<(&'static str, String)>) {
        if let Some(cursor) = &self.0 {
            pairs.push(("cursor", cursor.clone()));
        }
    }
}

impl CursorParams for PageParams {
    fn cursor(&self) -> Option<&str> {
        self.0.as_deref()
    }
    fn set_cursor(&mut self, cursor: Option<String>) {
        self.0 = cursor;
    }
}

struct PageOutput {
    cursor: Option<String>,
}

impl petrel_core::serde_bridge::FromValue for PageOutput {
    fn from_value(value: petrel_core::Value) -> Result<Self, DecodeError> {
        let mut reader = petrel_core::serde_bridge::ObjectReader::new(value)?;
        Ok(Self {
            cursor: reader.optional("cursor")?,
        })
    }
}

impl XrpcOutput for PageOutput {
    fn from_body(body: &[u8]) -> Result<Self, DecodeError> {
        petrel_core::from_json(body)
    }
}

impl CursorOutput for PageOutput {
    fn cursor(&self) -> Option<&str> {
        self.cursor.as_deref()
    }
}

struct Endpoint;

impl XrpcRequest for Endpoint {
    const NSID: &'static str = "app.bsky.feed.getTimeline";
    const METHOD: XrpcMethod = XrpcMethod::Query;
    const INPUT_ENCODING: Option<&'static str> = None;
    const OUTPUT_ENCODING: Option<&'static str> = Some("application/json");
    type Params = PageParams;
    type Input = ();
    type Output = PageOutput;
    type Error = UndeclaredError;
}

struct Binary;

impl XrpcRequest for Binary {
    const NSID: &'static str = "com.atproto.sync.getRepo";
    const METHOD: XrpcMethod = XrpcMethod::Query;
    const INPUT_ENCODING: Option<&'static str> = None;
    const OUTPUT_ENCODING: Option<&'static str> = Some("*/*");
    type Params = ();
    type Input = ();
    type Output = CoreBytes;
    type Error = UndeclaredError;
}

#[tokio::test]
async fn typed_requests_validate_content_type_and_decode_output() {
    let transport = Arc::new(MockTransport::<MockHandler>::new(|_, _, ordinal| {
        let mut response = reply(200, br#"{"cursor":"a"}"#);
        if ordinal != 0 {
            response.headers_mut().insert(
                http::header::CONTENT_TYPE,
                HeaderValue::from_static("text/plain"),
            );
        }
        Ok(response)
    }));
    let client = client(transport);
    let options = CallOptions::default();
    let (page, metadata) = client
        .send_with_metadata::<Endpoint>(PageParams(None), (), &options)
        .await
        .unwrap();
    assert_eq!(page.cursor.as_deref(), Some("a"));
    assert_eq!(metadata.status, StatusCode::OK);
    let typed = client
        .send::<Endpoint>(PageParams(None), (), &options)
        .await;
    assert!(matches!(typed, Err(Error::ContentType { .. })));
    let binary = client.send::<Binary>((), (), &options).await.unwrap();
    assert_eq!(binary.0, br#"{"cursor":"a"}"#);
}

#[tokio::test]
async fn pages_stop_on_repeat_and_on_error_and_respect_zero_limit() {
    let transport = Arc::new(MockTransport::<MockHandler>::new(|_, _, ordinal| {
        Ok(match ordinal {
            0 => reply(200, br#"{"cursor":"b"}"#),
            1 => reply(200, br#"{"cursor":"a"}"#),
            _ => reply(400, br#"{"error":"BadCursor"}"#),
        })
    }));
    let client = client(transport.clone());
    let options = CallOptions::default();
    let zero = client
        .pages::<Endpoint>(PageParams(None), &options, 0)
        .count()
        .await;
    assert_eq!(zero, 0);
    let pages = client
        .pages::<Endpoint>(PageParams(Some("a".to_owned())), &options, 10)
        .map(|page| page.unwrap().cursor.unwrap())
        .collect::<Vec<_>>()
        .await;
    assert_eq!(pages, ["b", "a"]);
    let pages = client
        .pages::<Endpoint>(PageParams(None), &options, 10)
        .collect::<Vec<_>>()
        .await;
    assert_eq!(pages.len(), 1);
    assert!(matches!(&pages[0], Err(Error::Xrpc(error)) if error.code == "BadCursor"));
    assert_eq!(transport.seen().len(), 3);
}

#[tokio::test]
async fn an_unsent_redirect_hop_does_not_retry_a_procedure_that_already_got_a_response() {
    let transport = Arc::new(MockTransport::<MockHandler>::new(|_, _, ordinal| {
        if ordinal == 0 {
            Ok(Response::builder()
                .status(303)
                .header("location", "/elsewhere")
                .body(Bytes::new())
                .unwrap())
        } else {
            Err(TransportError::Connect(
                "synthetic connection failure".to_owned(),
            ))
        }
    }));
    let delays = Arc::new(MockSleeper::default());
    let client = client(transport.clone()).with_sleeper(delays.clone());
    let result = client
        .procedure(
            "com.atproto.repo.uploadBlob",
            EMPTY,
            Some(XrpcBody::json("{}")),
            &CallOptions::default(),
        )
        .await;
    assert!(matches!(
        result,
        Err(Error::Transport(TransportError::ConnectionLost(_)))
    ));
    let seen = transport.seen();
    assert_eq!(seen.len(), 2);
    assert_eq!(seen[0].0.method(), Method::POST);
    assert_eq!(seen[1].0.method(), Method::GET);
    assert_eq!(delays.0.lock().unwrap().len(), 0);
}

#[tokio::test]
async fn explicit_routing_and_validated_body_headers_take_precedence() {
    let transport = Arc::new(MockTransport::<MockHandler>::new(|_, _, _| {
        Ok(reply(200, b"{}"))
    }));
    let mut client_headers = http::HeaderMap::new();
    client_headers.insert("atproto-proxy", HeaderValue::from_static("did:plc:client"));
    let client = client(transport.clone()).with_headers(client_headers);
    client
        .query("app.bsky.feed.getTimeline", EMPTY, &CallOptions::default())
        .await
        .unwrap();

    let mut opts = CallOptions {
        proxy: Some("did:plc:typed".to_owned()),
        accept_labelers: Some(vec![XrpcLabeler {
            did: "did:plc:typed-labeler".to_owned(),
            redact: true,
        }]),
        ..CallOptions::default()
    };
    opts.headers
        .insert("atproto-proxy", HeaderValue::from_static("did:plc:manual"));
    opts.headers.insert(
        "atproto-accept-labelers",
        HeaderValue::from_static("did:plc:manual-labeler"),
    );
    opts.headers.insert(
        "content-type",
        HeaderValue::from_static("invalid-media-type"),
    );
    client
        .procedure(
            "app.bsky.feed.createFixture",
            EMPTY,
            Some(XrpcBody::json("{}")),
            &opts,
        )
        .await
        .unwrap();

    let seen = transport.seen();
    assert_eq!(seen[0].0.headers()["atproto-proxy"], "did:plc:client");
    assert_eq!(seen[1].0.headers()["atproto-proxy"], "did:plc:typed");
    assert_eq!(
        seen[1].0.headers()["atproto-accept-labelers"],
        "did:plc:typed-labeler;redact"
    );
    assert_eq!(seen[1].0.headers()["content-type"], "application/json");
}

fn response_with_header(status: u16, header_value: &'static str) -> Response<Bytes> {
    let mut resp = reply(status, b"");
    resp.headers_mut()
        .insert("www-authenticate", HeaderValue::from_static(header_value));
    resp
}

#[tokio::test]
async fn non_nonce_401_skips_refresh_for_scope_dpop_empty_and_service_errors() {
    let no_refresh_cases: Vec<(&str, CallOptions, Response<Bytes>)> = vec![
        (
            "com.atproto.server.getSession",
            CallOptions::default(),
            reply(401, br#"{"error":"insufficient_scope"}"#),
        ),
        (
            "com.atproto.server.getSession",
            CallOptions::default(),
            reply(401, br#"{"error":"invalid_dpop_proof"}"#),
        ),
        (
            "com.atproto.server.getSession",
            CallOptions::default(),
            reply(401, b""),
        ),
        (
            "com.atproto.server.getSession",
            CallOptions::default(),
            response_with_header(401, r#"DPoP error="insufficient_scope""#),
        ),
        (
            "com.atproto.server.getSession",
            CallOptions::default(),
            response_with_header(401, r#"DPoP error="invalid_dpop_proof""#),
        ),
        (
            "chat.bsky.convo.listConvos",
            CallOptions::default(),
            reply(401, br#"{"error":"NotEnrolled"}"#),
        ),
        (
            "chat.bsky.convo.listConvos",
            CallOptions::default(),
            reply(401, br#"{"error":"AccountTakedown"}"#),
        ),
        (
            "chat.bsky.convo.listConvos",
            CallOptions::default(),
            reply(401, b""),
        ),
        (
            "chat.bsky.convo.listConvos",
            CallOptions::default(),
            reply(400, br#"{"error":"InvalidRequest"}"#),
        ),
        (
            "app.bsky.feed.getTimeline",
            CallOptions {
                service: Some(Url::parse("https://api.bsky.app").unwrap()),
                ..CallOptions::default()
            },
            reply(401, br#"{"error":"ExpiredToken"}"#),
        ),
    ];

    for (nsid, options, template_resp) in no_refresh_cases {
        let status = template_resp.status();
        let headers = template_resp.headers().clone();
        let body = template_resp.into_body();
        let mock = Arc::new(MockTransport::new(
            move |_: &Request<Bytes>, _: &SendOptions, _| {
                let mut resp = Response::builder()
                    .status(status)
                    .body(body.clone())
                    .unwrap();
                *resp.headers_mut() = headers.clone();
                Ok(resp)
            },
        ));
        let auth = Arc::new(MockAuth::default());
        let xrpc = XrpcClient::new(Url::parse("https://pds.example.com").unwrap(), mock.clone())
            .unwrap()
            .with_auth_provider(auth.clone());
        let err = xrpc.query(nsid, EMPTY, &options).await.unwrap_err();
        assert!(matches!(err, Error::Xrpc(_)), "unexpected err: {err:?}");
        assert_eq!(mock.seen().len(), 1, "should not retry {nsid}");
        assert_eq!(
            auth.unauthorized.load(Ordering::Relaxed),
            0,
            "should not refresh for {nsid}"
        );
    }
}

#[tokio::test]
async fn non_nonce_401_refreshes_for_own_pds_invalid_token_challenges() {
    let refresh_cases: Vec<(&str, Option<&str>, Response<Bytes>)> = vec![
        (
            "com.atproto.server.getSession",
            None,
            reply(401, br#"{"error":"invalid_token"}"#),
        ),
        (
            "com.atproto.server.getSession",
            None,
            reply(401, br#"{"error":"ExpiredToken"}"#),
        ),
        (
            "com.atproto.server.getSession",
            None,
            reply(401, br#"{"error":"InvalidToken"}"#),
        ),
        (
            "com.atproto.server.getSession",
            None,
            response_with_header(401, r#"DPoP error="invalid_token""#),
        ),
        (
            "com.atproto.server.getSession",
            None,
            response_with_header(401, r#"Bearer error="invalid_token""#),
        ),
        (
            "chat.bsky.convo.listConvos",
            Some("did:web:api.bsky.chat#bsky_chat"),
            reply(401, br#"{"error":"invalid_token"}"#),
        ),
        (
            "chat.bsky.convo.listConvos",
            Some("did:web:api.bsky.chat#bsky_chat"),
            reply(401, br#"{"error":"ExpiredToken"}"#),
        ),
        (
            "chat.bsky.convo.listConvos",
            Some("did:web:api.bsky.chat#bsky_chat"),
            reply(400, br#"{"error":"ExpiredToken"}"#),
        ),
        (
            "app.bsky.feed.getTimeline",
            Some("did:web:api.bsky.app#bsky_appview"),
            response_with_header(401, r#"DPoP error="invalid_token""#),
        ),
    ];

    for (nsid, expected_proxy, template_resp) in refresh_cases {
        let status = template_resp.status();
        let headers = template_resp.headers().clone();
        let body = template_resp.into_body();
        let mock = Arc::new(MockTransport::new(
            move |_: &Request<Bytes>, _: &SendOptions, ordinal| {
                if ordinal == 0 {
                    let mut resp = Response::builder()
                        .status(status)
                        .body(body.clone())
                        .unwrap();
                    *resp.headers_mut() = headers.clone();
                    Ok(resp)
                } else {
                    Ok(reply(200, b"{}"))
                }
            },
        ));
        let auth = Arc::new(MockAuth::default());
        XrpcClient::new(Url::parse("https://pds.example.com").unwrap(), mock.clone())
            .unwrap()
            .with_auth_provider(auth.clone())
            .query(nsid, EMPTY, &CallOptions::default())
            .await
            .unwrap();
        let seen = mock.seen();
        assert_eq!(seen.len(), 2, "should refresh and retry {nsid}");
        if let Some(proxy) = expected_proxy {
            assert_eq!(seen[0].0.headers()["atproto-proxy"], proxy);
            assert_eq!(seen[1].0.headers()["atproto-proxy"], proxy);
        }
        assert_eq!(auth.unauthorized.load(Ordering::Relaxed), 1);
    }
}

#[test]
fn call_options_debug_redacts_sensitive_headers() {
    let mut options = CallOptions::default();
    options.headers.insert(
        "authorization",
        HeaderValue::from_static("Bearer top-secret-token"),
    );
    options
        .headers
        .insert("dpop", HeaderValue::from_static("signed-dpop-proof"));
    options
        .headers
        .insert("cookie", HeaderValue::from_static("sid=secret"));
    options
        .headers
        .insert("accept", HeaderValue::from_static("application/json"));

    let rendered = format!("{options:?}");
    assert!(!rendered.contains("top-secret-token"), "{rendered}");
    assert!(!rendered.contains("signed-dpop-proof"), "{rendered}");
    assert!(!rendered.contains("sid=secret"), "{rendered}");
    assert!(rendered.contains("<REDACTED>"), "{rendered}");
    assert!(rendered.contains("application/json"), "{rendered}");
}
