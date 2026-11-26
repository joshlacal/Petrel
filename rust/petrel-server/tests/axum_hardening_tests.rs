#![cfg(not(target_arch = "wasm32"))]
//! Production-hardening behaviour of the Axum adapters: body limits, route-bound `lxm`,
//! error redaction, XRPC fallbacks, optional service auth, proxy-aware CAB rate limiting,
//! and `DPoP-Nonce` issuance.

mod common;

use std::collections::HashMap;
use std::sync::Arc;
use std::time::UNIX_EPOCH;

use axum::Router;
use axum::body::Body;
use axum::http::{HeaderName, Request, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::get;
use common::{TestClock, TestRandom, TestServer};
use petrel_api::generated::app::bsky::feed::get_timeline;
use petrel_api::generated::com::atproto::repo::put_record::{Output as PutRecordOutput, PutRecord};
use petrel_api::generated::com::atproto::repo::upload_blob::UploadBlob;
use petrel_core::{CidString, Datetime, XrpcRequest};
use petrel_server::axum::{
    AxumAdapterOptions, ClientIpSource, DpopNonceLayer, ServiceAuth, ServiceAuthRejection,
    ServiceAuthState, XrpcLxmBinding, XrpcRouteOptions, XrpcRouter, cab_router_with_options,
    oauth_router_with_options,
};
use petrel_server::cab::{
    CabKeyStore, CabServerConfig, CabServerCore, InMemoryCabDeviceStore, InMemoryCabReplayStore,
};
use petrel_server::jose::{OAuthCompactJwt, OAuthJwsAlgorithm, OAuthSigningKey};
use petrel_server::oauth::config::OAuthAccessTokenFormat;
use petrel_server::service_auth::{
    ServiceAuthAudience, ServiceAuthError, ServiceAuthMethodPolicy, ServiceAuthVerifier,
    StaticServiceAuthKeyResolver, public_key_from_jwk,
};
use petrel_server::xrpc::XrpcServerError;
use serde::Serialize;
use tower_service::Service as _;

const AUD: &str = "did:web:api.example.com";
const MIB: usize = 1024 * 1024;

#[derive(Serialize)]
struct Claims<'a> {
    iss: &'a str,
    aud: &'a str,
    exp: i64,
    iat: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    lxm: Option<&'a str>,
    jti: String,
}

struct Harness {
    key: OAuthSigningKey,
    state: ServiceAuthState,
}

impl Harness {
    fn new() -> Self {
        let key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
        let resolver = Arc::new(StaticServiceAuthKeyResolver::new(HashMap::from([(
            common::ALICE_DID.to_owned(),
            public_key_from_jwk(&key.public_jwk(false).unwrap()).unwrap(),
        )])));
        let verifier = Arc::new(ServiceAuthVerifier::new(
            ServiceAuthAudience::exactly(AUD),
            resolver,
        ));
        Self {
            key,
            state: ServiceAuthState::new(verifier),
        }
    }

    fn token(&self, lxm: Option<&str>) -> String {
        static COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        let now = std::time::SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs()
            .cast_signed();
        let n = COUNTER.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
        OAuthCompactJwt::sign(
            &Claims {
                iss: common::ALICE_DID,
                aud: AUD,
                exp: now + 60,
                iat: now,
                lxm,
                jti: format!("hardening-{n}"),
            },
            &self.key,
            Some("JWT"),
            false,
        )
        .unwrap()
    }
}

async fn body_json(resp: Response) -> serde_json::Value {
    let bytes = axum::body::to_bytes(resp.into_body(), 64 * 1024)
        .await
        .unwrap();
    serde_json::from_slice(&bytes).unwrap_or(serde_json::Value::Null)
}

async fn body_text(resp: Response) -> String {
    let bytes = axum::body::to_bytes(resp.into_body(), 64 * 1024)
        .await
        .unwrap();
    String::from_utf8_lossy(&bytes).into_owned()
}

fn put_record_ok() -> PutRecordOutput {
    PutRecordOutput {
        cid: CidString::parse("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
            .unwrap(),
        uri: "at://did:plc:alice/app.bsky.feed.post/1".parse().unwrap(),
        commit: None,
        validation_status: None,
    }
}

fn put_record_body(extra: &serde_json::Value) -> serde_json::Value {
    let mut body = serde_json::json!({
        "repo": common::ALICE_DID,
        "collection": "app.bsky.feed.post",
        "rkey": "3k7b",
        "record": { "$type": "app.bsky.feed.post", "text": "hi", "createdAt": Datetime::now().unwrap().as_str() }
    });
    if let (Some(dst), Some(src)) = (body.as_object_mut(), extra.as_object()) {
        for (k, v) in src {
            dst.insert(k.clone(), v.clone());
        }
    }
    body
}

fn padded_put_record(size: usize) -> String {
    let pad = "x".repeat(size);
    put_record_body(&serde_json::json!({ "padding": pad })).to_string()
}

fn post_json(uri: &str, body: String) -> Request<Body> {
    Request::post(uri)
        .header("Content-Type", "application/json")
        .body(Body::from(body))
        .unwrap()
}

fn timeline_output() -> get_timeline::Output {
    get_timeline::Output {
        cursor: None,
        feed: Vec::new(),
        start_cursor: None,
    }
}

// ---------------------------------------------------------------------------
// 1. Body limits
// ---------------------------------------------------------------------------

#[tokio::test]
async fn xrpc_body_limit_defaults_to_2mib_and_rejects_with_413_envelope() {
    let mut app: Router = XrpcRouter::<()>::new()
        .procedure::<PutRecord, _, _>(|(), _p, _i| async move { Ok(put_record_ok()) })
        .with_state(());

    let under = app
        .call(post_json(
            "/xrpc/com.atproto.repo.putRecord",
            padded_put_record(MIB),
        ))
        .await
        .unwrap();
    assert_eq!(under.status(), StatusCode::OK);

    let over = app
        .call(post_json(
            "/xrpc/com.atproto.repo.putRecord",
            padded_put_record(2 * MIB + 1),
        ))
        .await
        .unwrap();
    assert_eq!(over.status(), StatusCode::PAYLOAD_TOO_LARGE);
    let json = body_json(over).await;
    assert_eq!(json["error"], "PayloadTooLarge");
    assert!(json["message"].is_string());
}

#[tokio::test]
async fn xrpc_body_limit_router_default_and_per_route_override() {
    let mut app: Router = XrpcRouter::<()>::new()
        .procedure::<PutRecord, _, _>(|(), _p, _i| async move { Ok(put_record_ok()) })
        .procedure_bytes_with::<UploadBlob, _, _>(
            XrpcRouteOptions::new().body_limit(16 * MIB),
            |(), _p, body| async move {
                Err(XrpcServerError::InvalidRequest(format!(
                    "received {} bytes",
                    body.0.len()
                )))
            },
        )
        // Router-wide default set after registration still applies (order independent).
        .with_body_limit(4 * MIB)
        .with_state(());

    // 3 MiB JSON passes under the raised 4 MiB router default.
    let json_ok = app
        .call(post_json(
            "/xrpc/com.atproto.repo.putRecord",
            padded_put_record(3 * MIB),
        ))
        .await
        .unwrap();
    assert_eq!(json_ok.status(), StatusCode::OK);

    // 5 MiB JSON exceeds the router default.
    let json_over = app
        .call(post_json(
            "/xrpc/com.atproto.repo.putRecord",
            padded_put_record(5 * MIB),
        ))
        .await
        .unwrap();
    assert_eq!(json_over.status(), StatusCode::PAYLOAD_TOO_LARGE);

    // 10 MiB raw body reaches the handler on the 16 MiB per-route override.
    let raw_ok = app
        .call(
            Request::post("/xrpc/com.atproto.repo.uploadBlob")
                .header("Content-Type", "application/octet-stream")
                .body(Body::from(vec![0_u8; 10 * MIB]))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(raw_ok.status(), StatusCode::BAD_REQUEST);
    assert_eq!(
        body_json(raw_ok).await["message"],
        format!("received {} bytes", 10 * MIB)
    );

    let raw_over = app
        .call(
            Request::post("/xrpc/com.atproto.repo.uploadBlob")
                .body(Body::from(vec![0_u8; 16 * MIB + 1]))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(raw_over.status(), StatusCode::PAYLOAD_TOO_LARGE);
    assert_eq!(body_json(raw_over).await["error"], "PayloadTooLarge");
}

#[tokio::test]
async fn oauth_adapter_rejects_oversized_body_with_413_instead_of_empty_body() {
    let harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;
    let mut app: Router = oauth_router_with_options(
        Arc::new(harness.server),
        AxumAdapterOptions::default().with_body_limit(1024),
    );
    let resp = app
        .call(
            Request::post("/oauth/par")
                .header("Content-Type", "application/x-www-form-urlencoded")
                .body(Body::from(vec![b'a'; 2048]))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::PAYLOAD_TOO_LARGE);
    let json = body_json(resp).await;
    assert_eq!(json["error"], "invalid_request");
}

// ---------------------------------------------------------------------------
// 2. lxm binding
// ---------------------------------------------------------------------------

fn bearer(uri: &str, token: &str) -> Request<Body> {
    Request::get(uri)
        .header("Authorization", format!("Bearer {token}"))
        .body(Body::empty())
        .unwrap()
}

#[tokio::test]
async fn authenticated_routes_require_lxm_equal_to_route_nsid_by_default() {
    let h = Harness::new();
    let mut app: Router = XrpcRouter::<ServiceAuthState>::new()
        .authenticated_query::<get_timeline::GetTimeline, _, _>(|_s, _a, _p| async move {
            Ok(timeline_output())
        })
        .with_state(h.state.clone());
    let uri = "/xrpc/app.bsky.feed.getTimeline";

    let ok = app
        .call(bearer(uri, &h.token(Some(get_timeline::GetTimeline::NSID))))
        .await
        .unwrap();
    assert_eq!(ok.status(), StatusCode::OK);

    let missing = app.call(bearer(uri, &h.token(None))).await.unwrap();
    assert_eq!(missing.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(body_json(missing).await["error"], "BadJwtLexiconMethod");

    let wrong = app
        .call(bearer(uri, &h.token(Some("com.atproto.repo.putRecord"))))
        .await
        .unwrap();
    assert_eq!(wrong.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(body_json(wrong).await["error"], "BadJwtLexiconMethod");
}

#[tokio::test]
async fn authenticated_routes_can_opt_down_to_lxm_if_present() {
    let h = Harness::new();
    let routes = |router: XrpcRouter<ServiceAuthState>| {
        router.authenticated_query::<get_timeline::GetTimeline, _, _>(|_s, _a, _p| async move {
            Ok(timeline_output())
        })
    };
    let uri = "/xrpc/app.bsky.feed.getTimeline";

    // Router-wide opt-down.
    let mut app: Router = routes(XrpcRouter::new())
        .with_lxm_binding(XrpcLxmBinding::IfPresent)
        .with_state(h.state.clone());
    assert_eq!(
        app.call(bearer(uri, &h.token(None)))
            .await
            .unwrap()
            .status(),
        StatusCode::OK
    );
    assert_eq!(
        app.call(bearer(uri, &h.token(Some("com.atproto.repo.putRecord"))))
            .await
            .unwrap()
            .status(),
        StatusCode::UNAUTHORIZED
    );

    // Per-route opt-down.
    let mut per_route: Router = XrpcRouter::<ServiceAuthState>::new()
        .authenticated_query_with::<get_timeline::GetTimeline, _, _>(
            XrpcRouteOptions::new().lxm_binding(XrpcLxmBinding::IfPresent),
            |_s, _a, _p| async move { Ok(timeline_output()) },
        )
        .with_state(h.state.clone());
    assert_eq!(
        per_route
            .call(bearer(uri, &h.token(None)))
            .await
            .unwrap()
            .status(),
        StatusCode::OK
    );
}

#[tokio::test]
async fn match_route_policy_uses_original_uri_under_nest_and_fails_closed_off_xrpc() {
    let h = Harness::new();
    let state = h
        .state
        .clone()
        .with_policy(ServiceAuthMethodPolicy::MatchRoute);
    let inner: Router<ServiceAuthState> = Router::new().route(
        "/com.example.ping",
        get(|ServiceAuth(a): ServiceAuth| async move { a.issuer }),
    );
    let mut app: Router = Router::new()
        .nest("/xrpc", inner)
        .route(
            "/health",
            get(|ServiceAuth(a): ServiceAuth| async move { a.issuer }),
        )
        .with_state(state);

    let ok = app
        .call(bearer(
            "/xrpc/com.example.ping",
            &h.token(Some("com.example.ping")),
        ))
        .await
        .unwrap();
    assert_eq!(ok.status(), StatusCode::OK);

    let missing = app
        .call(bearer("/xrpc/com.example.ping", &h.token(None)))
        .await
        .unwrap();
    assert_eq!(missing.status(), StatusCode::UNAUTHORIZED);

    let wrong = app
        .call(bearer(
            "/xrpc/com.example.ping",
            &h.token(Some("com.example.other")),
        ))
        .await
        .unwrap();
    assert_eq!(wrong.status(), StatusCode::UNAUTHORIZED);

    // Non-XRPC path cannot derive an NSID: the required policy fails closed.
    let off_xrpc = app
        .call(bearer("/health", &h.token(Some("com.example.ping"))))
        .await
        .unwrap();
    assert_eq!(off_xrpc.status(), StatusCode::UNAUTHORIZED);
}

#[test]
fn match_route_policy_checked_without_route_fails_closed() {
    assert!(
        ServiceAuthMethodPolicy::MatchRoute
            .check(Some("com.example.ping"))
            .is_err()
    );
    assert!(ServiceAuthMethodPolicy::MatchRoute.check(None).is_err());
}

// ---------------------------------------------------------------------------
// 4. Error redaction
// ---------------------------------------------------------------------------

#[tokio::test]
async fn service_auth_and_internal_errors_do_not_leak_details_to_clients() {
    let key_err = ServiceAuthRejection(ServiceAuthError::KeyResolutionFailed {
        did: "did:plc:x".into(),
        key_id: "#atproto".into(),
        reason: "postgres://secret@db:5432 timed out".into(),
    })
    .into_response();
    assert_eq!(key_err.status(), StatusCode::UNAUTHORIZED);
    let text = body_text(key_err).await;
    assert!(!text.contains("secret"), "leaked: {text}");
    assert!(text.contains("BadJwtSignature"));

    let replay_err = ServiceAuthRejection(ServiceAuthError::ReplayStoreFailed(
        "redis://internal-host:6379 connection refused".into(),
    ))
    .into_response();
    assert_eq!(replay_err.status(), StatusCode::SERVICE_UNAVAILABLE);
    let text = body_text(replay_err).await;
    assert!(!text.contains("internal-host"), "leaked: {text}");

    let internal = XrpcServerError::<petrel_core::xrpc::UndeclaredError>::Internal(
        "relation \"users\" does not exist".into(),
    );
    let wire = internal.to_wire_body();
    assert_eq!(wire.error, "InternalServerError");
    assert!(!wire.message.unwrap_or_default().contains("users"));
    let text = body_text(internal.into_response()).await;
    assert!(!text.contains("users"), "leaked: {text}");
}

// ---------------------------------------------------------------------------
// 5. Input decoding: unknown fields
// ---------------------------------------------------------------------------

#[tokio::test]
async fn strict_input_decoding_accepts_unknown_fields_at_any_depth() {
    let mut app: Router = XrpcRouter::<()>::new()
        .procedure::<PutRecord, _, _>(|(), _p, _i| async move { Ok(put_record_ok()) })
        .with_state(());
    let mut body = put_record_body(&serde_json::json!({ "futureTopLevel": { "a": [1, 2] } }));
    body["record"]["futureNested"] = serde_json::json!({ "deep": true });
    let resp = app
        .call(post_json(
            "/xrpc/com.atproto.repo.putRecord",
            body.to_string(),
        ))
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);
}

// ---------------------------------------------------------------------------
// 7. Fallbacks, optional auth, DPoP-Nonce
// ---------------------------------------------------------------------------

#[tokio::test]
async fn xrpc_fallbacks_return_xrpc_envelopes() {
    let mut app: Router = XrpcRouter::<()>::new()
        .procedure::<PutRecord, _, _>(|(), _p, _i| async move { Ok(put_record_ok()) })
        .with_xrpc_fallbacks()
        .with_state(());

    let unknown = app
        .call(
            Request::get("/xrpc/com.example.nope")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(unknown.status(), StatusCode::NOT_IMPLEMENTED);
    assert_eq!(body_json(unknown).await["error"], "MethodNotImplemented");

    let wrong_method = app
        .call(
            Request::get("/xrpc/com.atproto.repo.putRecord")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(wrong_method.status(), StatusCode::BAD_REQUEST);
    assert_eq!(body_json(wrong_method).await["error"], "InvalidRequest");
}

#[tokio::test]
async fn optional_service_auth_extractor() {
    let h = Harness::new();
    let mut app: Router = Router::new()
        .route(
            "/xrpc/com.example.maybe",
            get(|auth: Option<ServiceAuth>| async move {
                auth.map_or_else(|| "anon".to_owned(), |ServiceAuth(a)| a.issuer)
            }),
        )
        .with_state(h.state.clone());

    let anon = app
        .call(
            Request::get("/xrpc/com.example.maybe")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(anon.status(), StatusCode::OK);
    assert_eq!(body_text(anon).await, "anon");

    let authed = app
        .call(bearer(
            "/xrpc/com.example.maybe",
            &h.token(Some("com.example.maybe")),
        ))
        .await
        .unwrap();
    assert_eq!(authed.status(), StatusCode::OK);
    assert_eq!(body_text(authed).await, common::ALICE_DID);

    let bad = app
        .call(bearer("/xrpc/com.example.maybe", "not-a-jwt"))
        .await
        .unwrap();
    assert_eq!(bad.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn dpop_nonce_layer_attaches_fresh_nonce_to_responses() {
    let harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;
    let verifier = Arc::new(harness.server.resource_verifier());
    let mut app: Router = Router::new()
        .route("/resource", get(|| async { "ok" }))
        .layer(DpopNonceLayer::new(verifier.clone()));
    let resp = app
        .call(Request::get("/resource").body(Body::empty()).unwrap())
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);
    let nonce = resp
        .headers()
        .get("dpop-nonce")
        .expect("DPoP-Nonce header")
        .to_str()
        .unwrap()
        .to_owned();
    assert_eq!(nonce, verifier.current_nonce());
}

// ---------------------------------------------------------------------------
// 6. CAB client key source behind a reverse proxy
// ---------------------------------------------------------------------------

fn make_cab(max_requests: usize) -> Arc<CabServerCore> {
    let key =
        OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("cab-key-1".into())).unwrap();
    let key_store = CabKeyStore::new(vec![key], "cab-key-1").unwrap();
    let mut cfg = CabServerConfig::new(
        "https://cab.example.com",
        "https://cab.example.com/oauth-client-metadata.json",
    );
    cfg.allowed_audiences = vec!["https://auth.example.com".into()];
    cfg.rate_limit_max_requests = max_requests;
    cfg.rate_limit_window_secs = 60;
    Arc::new(
        CabServerCore::with_clock_and_random(
            cfg,
            key_store,
            &[11_u8; 32],
            Arc::new(InMemoryCabDeviceStore::new()),
            Arc::new(InMemoryCabReplayStore::new()),
            Arc::new(TestClock::new(1_700_000_000)),
            Arc::new(TestRandom::new()),
        )
        .unwrap(),
    )
}

fn health(xff: Option<&str>) -> Request<Body> {
    let mut b = Request::get("/health");
    if let Some(v) = xff {
        b = b.header("X-Forwarded-For", v);
    }
    b.body(Body::empty()).unwrap()
}

#[tokio::test]
async fn cab_rate_limit_keys_on_trusted_proxy_header_when_configured() {
    let mut app: Router = cab_router_with_options(
        make_cab(1),
        AxumAdapterOptions::default().with_client_ip_source(ClientIpSource::TrustedHeader(
            HeaderName::from_static("x-forwarded-for"),
        )),
    );
    assert_eq!(
        app.call(health(Some("203.0.113.1")))
            .await
            .unwrap()
            .status(),
        StatusCode::OK
    );
    // Distinct client behind the same proxy has its own bucket.
    assert_eq!(
        app.call(health(Some("203.0.113.2")))
            .await
            .unwrap()
            .status(),
        StatusCode::OK
    );
    // Right-most value is the one the trusted proxy appended; a spoofed left value is ignored.
    assert_eq!(
        app.call(health(Some("198.51.100.9, 203.0.113.1")))
            .await
            .unwrap()
            .status(),
        StatusCode::TOO_MANY_REQUESTS
    );
}

#[tokio::test]
async fn cab_ignores_forwarded_header_unless_configured() {
    let mut app: Router = cab_router_with_options(make_cab(1), AxumAdapterOptions::default());
    // Without ConnectInfo and without a trusted header, everyone shares the unauth bucket.
    assert_eq!(
        app.call(health(Some("203.0.113.1")))
            .await
            .unwrap()
            .status(),
        StatusCode::OK
    );
    assert_eq!(
        app.call(health(Some("203.0.113.2")))
            .await
            .unwrap()
            .status(),
        StatusCode::TOO_MANY_REQUESTS
    );
}
