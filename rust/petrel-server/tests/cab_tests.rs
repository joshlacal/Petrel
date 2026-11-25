#![cfg(not(target_arch = "wasm32"))]

mod common;

use std::sync::Arc;

use axum::body::Body;
use axum::http::{Request, StatusCode};
use common::{TestClock, TestRandom, make_dpop_proof};
use petrel_server::axum::cab_router;
use petrel_server::cab::{
    CabKeyStore, CabRateLimiter, CabServerConfig, CabServerCore, InMemoryCabDeviceStore,
    InMemoryCabReplayStore,
};
use petrel_server::http::{OAuthHttpHeaders, OAuthHttpRequest};
use petrel_server::jose::{
    OAuthCompactJwt, OAuthJsonWebKeySet, OAuthJwsAlgorithm, OAuthJwtVerificationConstraints,
    OAuthSigningKey,
};
use petrel_server::support::OAuthClock;
use serde::Deserialize;
use tower_service::Service as _;

fn make_cab(
    mutate: impl FnOnce(&mut CabServerConfig),
) -> (Arc<CabServerCore>, OAuthSigningKey, Arc<TestClock>) {
    let key =
        OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("cab-key-1".into())).unwrap();
    let key_store = CabKeyStore::new(vec![key.clone()], "cab-key-1").unwrap();
    let mut cfg = CabServerConfig::new(
        "https://cab.example.com",
        "https://cab.example.com/oauth-client-metadata.json",
    );
    cfg.allowed_audiences = vec!["https://auth.example.com".into()];
    mutate(&mut cfg);
    let clock = Arc::new(TestClock::new(1_700_000_000));
    let cab = Arc::new(
        CabServerCore::with_clock_and_random(
            cfg,
            key_store,
            &[11_u8; 32],
            Arc::new(InMemoryCabDeviceStore::new()),
            Arc::new(InMemoryCabReplayStore::new()),
            clock.clone(),
            Arc::new(TestRandom::new()),
        )
        .unwrap(),
    );
    (cab, key, clock)
}

#[tokio::test]
async fn cab_happy_path_mints_verifiable_client_assertion_with_cnf_jkt() {
    #[derive(Deserialize)]
    struct MintBody {
        client_id: String,
        client_assertion: String,
    }
    #[derive(Deserialize)]
    struct Cnf {
        jkt: String,
    }
    #[derive(Deserialize)]
    struct AssertionClaims {
        iss: String,
        sub: String,
        aud: String,
        cnf: Cnf,
    }
    let (cab, server_key, clock) = make_cab(|_| {});
    let device_key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let proof = make_dpop_proof(
        &device_key,
        "POST",
        "https://cab.example.com/oauth/client-assertion",
        None,
        None,
        clock.now_secs(),
        "cab-jti-1",
    );
    let mut headers = OAuthHttpHeaders::new([("DPoP", proof.as_str())]);
    headers.set("Content-Type", "application/x-www-form-urlencoded");
    let resp = cab
        .handle(
            OAuthHttpRequest::new("POST", "/oauth/client-assertion")
                .with_headers(headers)
                .with_body(b"aud=https%3A%2F%2Fauth.example.com".to_vec()),
        )
        .await;
    assert_eq!(resp.status, 200, "body: {}", resp.text());
    assert_eq!(resp.headers.get("Cache-Control"), Some("no-store"));

    let body: MintBody = serde_json::from_slice(&resp.body).unwrap();
    assert_eq!(
        body.client_id,
        "https://cab.example.com/oauth-client-metadata.json"
    );
    let pub_jwk = server_key.public_jwk(true).unwrap();
    let mut constraints = OAuthJwtVerificationConstraints::new(clock.now_secs());
    constraints.expected_issuer = Some(body.client_id.clone());
    constraints.expected_audience = Some("https://auth.example.com".into());
    let verified = OAuthCompactJwt::verify_with_jwk::<AssertionClaims>(
        &body.client_assertion,
        &pub_jwk,
        &constraints,
    )
    .unwrap();
    assert_eq!(verified.claims.iss, body.client_id);
    assert_eq!(verified.claims.sub, body.client_id);
    assert_eq!(verified.claims.aud, "https://auth.example.com");
    assert_eq!(verified.claims.cnf.jkt, device_key.thumbprint().unwrap());

    // Replay of same proof fails
    let mut headers2 = OAuthHttpHeaders::new([("DPoP", proof.as_str())]);
    headers2.set("Content-Type", "application/x-www-form-urlencoded");
    let replay = cab
        .handle(
            OAuthHttpRequest::new("POST", "/oauth/client-assertion")
                .with_headers(headers2)
                .with_body(b"aud=https%3A%2F%2Fauth.example.com".to_vec()),
        )
        .await;
    assert_eq!(replay.status, 400);
    assert!(replay.text().contains("invalid_dpop_proof"));
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn cab_enforces_denied_jkts_aud_allowlist_origin_policy_rate_limit_and_nonce() {
    let denied_key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let denied_jkt = denied_key.thumbprint().unwrap();
    let (cab, _, clock) = make_cab(|cfg| {
        cfg.denied_jkts = vec![denied_jkt];
        cfg.allowed_audiences = vec!["https://auth.example.com".into()];
        cfg.allowed_origins = vec!["https://app.example.com".into()];
        cfg.require_dpop_nonce = true;
        cfg.rate_limit_max_requests = 4;
        cfg.client_metadata = Some(serde_json::json!({
            "client_id": "https://cab.example.com/oauth-client-metadata.json",
            "token_endpoint_auth_method": "private_key_jwt",
            "dpop_bound_access_tokens": true
        }));
    });

    // Metadata endpoint & JWKS & health
    let meta = cab
        .handle(OAuthHttpRequest::new("GET", "/oauth-client-metadata.json"))
        .await;
    assert_eq!(meta.status, 200);
    let jwks_resp = cab
        .handle(OAuthHttpRequest::new("GET", "/.well-known/jwks.json"))
        .await;
    assert_eq!(jwks_resp.status, 200);
    let jwks = OAuthJsonWebKeySet::decode_validated(&jwks_resp.body).unwrap();
    assert_eq!(jwks.keys.len(), 1);

    // Nonce challenge -> retry
    let good_key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let proof1 = make_dpop_proof(
        &good_key,
        "POST",
        "https://cab.example.com/oauth/client-assertion",
        None,
        None,
        clock.now_secs(),
        "c-1",
    );
    let mut hdrs = OAuthHttpHeaders::new([
        ("DPoP", proof1.as_str()),
        ("Origin", "https://app.example.com"),
    ]);
    hdrs.set("Content-Type", "application/x-www-form-urlencoded");
    let chal = cab
        .handle(
            OAuthHttpRequest::new("POST", "/oauth/client-assertion")
                .with_headers(hdrs)
                .with_body(b"aud=https%3A%2F%2Fauth.example.com".to_vec()),
        )
        .await;
    assert_eq!(chal.status, 400);
    assert!(chal.text().contains("use_dpop_nonce"));
    let nonce = chal.headers.get("DPoP-Nonce").unwrap().to_owned();

    let proof2 = make_dpop_proof(
        &good_key,
        "POST",
        "https://cab.example.com/oauth/client-assertion",
        Some(&nonce),
        None,
        clock.now_secs(),
        "c-2",
    );
    let mut hdrs2 = OAuthHttpHeaders::new([
        ("DPoP", proof2.as_str()),
        ("Origin", "https://app.example.com"),
    ]);
    hdrs2.set("Content-Type", "application/x-www-form-urlencoded");
    let ok = cab
        .handle(
            OAuthHttpRequest::new("POST", "/oauth/client-assertion")
                .with_headers(hdrs2)
                .with_body(b"aud=https%3A%2F%2Fauth.example.com".to_vec()),
        )
        .await;
    assert_eq!(ok.status, 200);
    assert_eq!(
        ok.headers.get("Access-Control-Allow-Origin"),
        Some("https://app.example.com")
    );

    // Denied origin -> 403
    let bad_origin = OAuthHttpHeaders::new([("Origin", "https://evil.example.com")]);
    let r_origin = cab
        .handle(
            OAuthHttpRequest::new("POST", "/oauth/client-assertion")
                .with_headers(bad_origin)
                .with_body(b"aud=https%3A%2F%2Fauth.example.com".to_vec()),
        )
        .await;
    assert_eq!(r_origin.status, 403);

    // Rate limit exhaustion on unauthenticated GETs -> 429 (2 prior GETs + 2 more -> 5th hits 429)
    let mut app = cab_router::<()>(cab.clone());
    assert_eq!(
        app.call(Request::get("/health").body(Body::empty()).unwrap())
            .await
            .unwrap()
            .status(),
        StatusCode::OK
    );
    assert_eq!(
        app.call(Request::get("/health").body(Body::empty()).unwrap())
            .await
            .unwrap()
            .status(),
        StatusCode::OK
    );
    let resp = app
        .call(Request::get("/health").body(Body::empty()).unwrap())
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::TOO_MANY_REQUESTS);

    // Distinct DPoP caller (`other_key`) has its own jkt rate-limit bucket even when remote_address is None
    let other_key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let other_proof = make_dpop_proof(
        &other_key,
        "POST",
        "https://cab.example.com/oauth/client-assertion",
        Some(&nonce),
        None,
        clock.now_secs(),
        "other-1",
    );
    let mut other_hdrs = OAuthHttpHeaders::new([
        ("DPoP", other_proof.as_str()),
        ("Origin", "https://app.example.com"),
    ]);
    other_hdrs.set("Content-Type", "application/x-www-form-urlencoded");
    let other_ok = cab
        .handle(
            OAuthHttpRequest::new("POST", "/oauth/client-assertion")
                .with_headers(other_hdrs)
                .with_body(b"aud=https%3A%2F%2Fauth.example.com".to_vec()),
        )
        .await;
    assert_eq!(other_ok.status, 200);

    // Direct unit check on CabRateLimiter capacity & expired-bucket eviction
    let limiter = CabRateLimiter::with_max_keys(2, 60, 2);
    assert!(limiter.check("k1", 100).await.is_ok());
    assert!(limiter.check("k1", 100).await.is_ok());
    assert!(limiter.check("k1", 100).await.is_err());
    assert!(limiter.check("k2", 100).await.is_ok());
    assert!(limiter.check("k3", 100).await.is_err());
    assert!(limiter.check("k3", 200).await.is_ok());
}

#[tokio::test]
async fn cab_cors_preflight_options_handled_on_core_and_axum_router() {
    let (cab, _, _) = make_cab(|c| {
        c.allowed_origins = vec!["https://app.example.com".into()];
    });

    // Core OPTIONS preflight for /oauth/client-assertion
    let preflight = cab
        .handle(
            OAuthHttpRequest::new("OPTIONS", "/oauth/client-assertion").with_headers(
                OAuthHttpHeaders::new([
                    ("Origin", "https://app.example.com"),
                    ("Access-Control-Request-Method", "POST"),
                    ("Access-Control-Request-Headers", "content-type, dpop"),
                ]),
            ),
        )
        .await;
    assert_eq!(preflight.status, 204);
    assert_eq!(
        preflight.headers.get("Access-Control-Allow-Origin"),
        Some("https://app.example.com")
    );
    assert!(
        preflight
            .headers
            .get("Access-Control-Allow-Methods")
            .is_some_and(|v| v.contains("POST") && v.contains("OPTIONS"))
    );
    assert!(
        preflight
            .headers
            .get("Access-Control-Allow-Headers")
            .is_some_and(|v| v.contains("DPoP") && v.contains("Content-Type"))
    );

    // Axum cab_router passes OPTIONS through instead of returning 405
    let mut app = cab_router::<()>(cab);
    let axum_req = Request::builder()
        .method("OPTIONS")
        .uri("/v1/assertions")
        .header("Origin", "https://app.example.com")
        .header("Access-Control-Request-Method", "POST")
        .header("Access-Control-Request-Headers", "content-type, dpop")
        .body(Body::empty())
        .unwrap();
    let axum_resp = app.call(axum_req).await.unwrap();
    assert_eq!(axum_resp.status(), StatusCode::NO_CONTENT);
    assert_eq!(
        axum_resp
            .headers()
            .get("Access-Control-Allow-Origin")
            .and_then(|v| v.to_str().ok()),
        Some("https://app.example.com")
    );
    assert!(
        axum_resp
            .headers()
            .get("Access-Control-Allow-Headers")
            .and_then(|v| v.to_str().ok())
            .is_some_and(|v| v.contains("DPoP"))
    );

    // Non-allowed Origin OPTIONS is rejected with 403
    let evil_req = Request::builder()
        .method("OPTIONS")
        .uri("/oauth/client-assertion")
        .header("Origin", "https://evil.example.com")
        .body(Body::empty())
        .unwrap();
    let evil_resp = app.call(evil_req).await.unwrap();
    assert_eq!(evil_resp.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn cab_register_device_rejects_conflicting_key_replacement_and_allows_idempotent_same_key() {
    let (cab, _, clock) = make_cab(|c| {
        c.require_registered_device = true;
    });
    let key1 = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let jwk1 = key1.public_jwk(false).unwrap();
    let key2 = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let jwk2 = key2.public_jwk(false).unwrap();

    // Unauthenticated registration without DPoP proof fails closed
    let reg_body = serde_json::to_vec(&serde_json::json!({
        "device_id": "dev-locked-1",
        "jwk": jwk1
    }))
    .unwrap();
    let mut base_hdrs = OAuthHttpHeaders::default();
    base_hdrs.set("Content-Type", "application/json");
    let unauth = cab
        .handle(
            OAuthHttpRequest::new("POST", "/v1/devices/register")
                .with_headers(base_hdrs.clone())
                .with_body(reg_body.clone()),
        )
        .await;
    assert_eq!(unauth.status, 400);
    assert!(unauth.text().contains("invalid_dpop_proof"));

    // Body JWK mismatching verified DPoP proof key fails closed
    let mismatch_proof = make_dpop_proof(
        &key1,
        "POST",
        "https://cab.example.com/v1/devices/register",
        None,
        None,
        clock.now_secs(),
        "reg-mismatch",
    );
    let mut mismatch_hdrs = base_hdrs.clone();
    mismatch_hdrs.set("DPoP", mismatch_proof);
    let mismatch = cab
        .handle(
            OAuthHttpRequest::new("POST", "/v1/devices/register")
                .with_headers(mismatch_hdrs)
                .with_body(
                    serde_json::to_vec(&serde_json::json!({
                        "device_id": "dev-locked-1",
                        "jwk": jwk2
                    }))
                    .unwrap(),
                ),
        )
        .await;
    assert_eq!(mismatch.status, 400);
    assert!(mismatch.text().contains("invalid_dpop_proof"));

    // Proof-derived registration (jkt comes from verified DPoP proof) succeeds
    let proof1 = make_dpop_proof(
        &key1,
        "POST",
        "https://cab.example.com/v1/devices/register",
        None,
        None,
        clock.now_secs(),
        "reg-1",
    );
    let mut hdrs1 = base_hdrs.clone();
    hdrs1.set("DPoP", proof1);
    let first = cab
        .handle(
            OAuthHttpRequest::new("POST", "/v1/devices/register")
                .with_headers(hdrs1)
                .with_body(
                    serde_json::to_vec(&serde_json::json!({"device_id": "dev-locked-1"})).unwrap(),
                ),
        )
        .await;
    assert_eq!(first.status, 201, "body: {}", first.text());

    // Idempotent re-registration with identical key proof succeeds
    let proof1b = make_dpop_proof(
        &key1,
        "POST",
        "https://cab.example.com/v1/devices/register",
        None,
        None,
        clock.now_secs(),
        "reg-1b",
    );
    let mut hdrs1b = base_hdrs.clone();
    hdrs1b.set("DPoP", proof1b);
    let same = cab
        .handle(
            OAuthHttpRequest::new("POST", "/v1/devices/register")
                .with_headers(hdrs1b)
                .with_body(reg_body),
        )
        .await;
    assert_eq!(same.status, 201);

    // Conflicting key replacement for existing device_id is rejected with 409
    let proof2 = make_dpop_proof(
        &key2,
        "POST",
        "https://cab.example.com/v1/devices/register",
        None,
        None,
        clock.now_secs(),
        "reg-2",
    );
    let mut hdrs2 = base_hdrs;
    hdrs2.set("DPoP", proof2);
    let conflict = cab
        .handle(
            OAuthHttpRequest::new("POST", "/v1/devices/register")
                .with_headers(hdrs2)
                .with_body(
                    serde_json::to_vec(&serde_json::json!({
                        "device_id": "dev-locked-1",
                        "jwk": jwk2
                    }))
                    .unwrap(),
                ),
        )
        .await;
    assert_eq!(conflict.status, 409);
    assert!(conflict.text().contains("device_already_registered"));
}

#[tokio::test]
async fn cab_fails_closed_on_empty_audiences_origins_and_clamps_assertion_lifetime() {
    // Empty allowed_audiences & empty allowed_origins both fail closed
    let (cab, _, clock) = make_cab(|c| {
        c.allowed_audiences.clear();
        c.allowed_origins.clear();
    });
    let device_key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let proof = make_dpop_proof(
        &device_key,
        "POST",
        "https://cab.example.com/oauth/client-assertion",
        None,
        None,
        clock.now_secs(),
        "fail-closed-aud",
    );
    let mut no_origin_hdrs = OAuthHttpHeaders::new([("DPoP", proof.as_str())]);
    no_origin_hdrs.set("Content-Type", "application/x-www-form-urlencoded");
    let aud_rejected = cab
        .handle(
            OAuthHttpRequest::new("POST", "/oauth/client-assertion")
                .with_headers(no_origin_hdrs)
                .with_body(b"aud=https%3A%2F%2Fauth.example.com".to_vec()),
        )
        .await;
    assert_eq!(aud_rejected.status, 400);
    assert!(
        aud_rejected
            .text()
            .contains("aud is not in allowed_audiences")
    );

    let origin_rejected = cab
        .handle(
            OAuthHttpRequest::new("POST", "/oauth/client-assertion")
                .with_headers(OAuthHttpHeaders::new([("Origin", "https://evil.example")])),
        )
        .await;
    assert_eq!(origin_rejected.status, 403);
    assert!(
        origin_rejected
            .headers
            .get("Access-Control-Allow-Origin")
            .is_none()
    );

    // assertion_lifetime_secs outside 1..=60 is rejected at construction
    let key =
        OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("cab-key-1".into())).unwrap();
    let key_store = CabKeyStore::new(vec![key], "cab-key-1").unwrap();
    for bad_ttl in [0, 61] {
        let mut cfg = CabServerConfig::new(
            "https://cab.example.com",
            "https://cab.example.com/oauth-client-metadata.json",
        );
        cfg.assertion_lifetime_secs = bad_ttl;
        assert!(
            CabServerCore::with_clock_and_random(
                cfg,
                key_store.clone(),
                &[11_u8; 32],
                Arc::new(InMemoryCabDeviceStore::new()),
                Arc::new(InMemoryCabReplayStore::new()),
                clock.clone(),
                Arc::new(TestRandom::new()),
            )
            .is_err()
        );
    }
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn cab_enforces_unauth_rate_limit_before_dpop_crypto_when_remote_address_is_none() {
    // /v1/assertions (via direct handle & cab_router without ConnectInfo): invalid DPoP proofs
    // with distinct random keys / bad signatures hit the shared unauth rate limit before per-JKT
    // or ECDSA verification limits.
    let (cab_assertions, _, _) = make_cab(|c| {
        c.rate_limit_max_requests = 2;
        c.rate_limit_window_secs = 60;
    });
    let mut assertion_headers = OAuthHttpHeaders::new([("DPoP", "not.a.valid-jwt")]);
    assertion_headers.set("Content-Type", "application/x-www-form-urlencoded");
    let assertion_body = b"aud=https%3A%2F%2Fauth.example.com".to_vec();

    for attempt in 0..2 {
        let resp = cab_assertions
            .handle(
                OAuthHttpRequest::new("POST", "/v1/assertions")
                    .with_headers(assertion_headers.clone())
                    .with_body(assertion_body.clone()),
            )
            .await;
        assert_eq!(
            resp.status,
            400,
            "attempt {attempt} should fail DPoP validation: {}",
            resp.text()
        );
        assert!(resp.text().contains("invalid_dpop_proof"));
    }

    let throttled_assertion = cab_assertions
        .handle(
            OAuthHttpRequest::new("POST", "/v1/assertions")
                .with_headers(assertion_headers)
                .with_body(assertion_body.clone()),
        )
        .await;
    assert_eq!(throttled_assertion.status, 429);
    assert!(throttled_assertion.text().contains("rate_limited"));

    // Axum cab_router without ConnectInfo leaves remote_address = None and also enforces 429.
    let mut app = cab_router::<()>(cab_assertions);
    let axum_resp = app
        .call(
            Request::post("/v1/assertions")
                .header("Content-Type", "application/x-www-form-urlencoded")
                .header("DPoP", "not.a.valid-jwt")
                .body(Body::from(assertion_body))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(axum_resp.status(), StatusCode::TOO_MANY_REQUESTS);

    // /v1/devices/register without remote_address also enforces shared unauth rate limit upfront.
    let (cab_register, _, _) = make_cab(|c| {
        c.rate_limit_max_requests = 2;
        c.rate_limit_window_secs = 60;
    });
    let mut reg_headers = OAuthHttpHeaders::new([("DPoP", "still.not.valid")]);
    reg_headers.set("Content-Type", "application/json");
    let reg_body = br#"{"device_id":"dev-flood"}"#.to_vec();

    for attempt in 0..2 {
        let resp = cab_register
            .handle(
                OAuthHttpRequest::new("POST", "/v1/devices/register")
                    .with_headers(reg_headers.clone())
                    .with_body(reg_body.clone()),
            )
            .await;
        assert_eq!(
            resp.status,
            400,
            "attempt {attempt} should return 400 before throttling: {}",
            resp.text()
        );
        assert!(resp.text().contains("invalid_dpop_proof"));
    }

    let throttled_register = cab_register
        .handle(
            OAuthHttpRequest::new("POST", "/v1/devices/register")
                .with_headers(reg_headers)
                .with_body(reg_body),
        )
        .await;
    assert_eq!(throttled_register.status, 429);
    assert!(throttled_register.text().contains("rate_limited"));
}
