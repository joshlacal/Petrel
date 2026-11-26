#![cfg(not(target_arch = "wasm32"))]

mod common;

use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, UNIX_EPOCH};

use axum::Router;
use axum::body::Body;
use axum::http::{Request, StatusCode};
use axum::routing::get;
use common::{TestServer, make_dpop_proof};
use petrel::identity::{
    DnsError, DnsResolver, IdentityOptions, IdentityResolver, InMemoryIdentityCache,
};
use petrel::net::{HttpTransport, SendOptions, SharedTransport, TransportError};
use petrel_api::generated::app::bsky::feed::get_timeline;
use petrel_api::generated::com::atproto::repo::put_record::{
    Error as PutRecordError, Input as PutRecordInput, Output as PutRecordOutput, PutRecord,
};
use petrel_core::{CidString, Datetime, RecordKey, XrpcRequest};
use petrel_server::axum::{
    DpopResourceAuth, DpopVerifierState, ServiceAuthLayer, ServiceAuthState, XrpcRouter,
    oauth_router,
};
use petrel_server::dpop::OAuthDpopProofValidator;
use petrel_server::jose::{OAuthCompactJwt, OAuthJwsAlgorithm, OAuthSigningKey};
use petrel_server::oauth::config::OAuthAccessTokenFormat;
use petrel_server::service_auth::{
    CachingServiceAuthKeyResolver, IdentityResolverServiceAuthKeyResolver,
    InMemoryServiceAuthReplayStore, PublicKey, ServiceAuthAudience, ServiceAuthError,
    ServiceAuthKeyResolver, ServiceAuthMethodPolicy, ServiceAuthReplayStore,
    ServiceAuthRequiredClaims, ServiceAuthVerifier, ServiceAuthVerifierConfig,
    StaticServiceAuthKeyResolver, VerifiedServiceAuth, public_key_from_jwk,
};
use petrel_server::xrpc::XrpcServerError;
use serde::Serialize;
use tower_service::Service as _;

#[derive(Serialize)]
struct ServiceJwtPayload<'a> {
    iss: &'a str,
    aud: &'a str,
    exp: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    iat: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    lxm: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    jti: Option<&'a str>,
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn service_auth_verifies_es256_es256k_replay_aud_lxm_and_exp_bounds() {
    let replay = Arc::new(InMemoryServiceAuthReplayStore::new());
    let alice_key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let bob_key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256k, None).unwrap();
    let alice_did = "did:plc:alice234567234567abcdefg";
    let bob_did = "did:plc:bobbb234567234567abcdefg";
    let resolver = Arc::new(StaticServiceAuthKeyResolver::new(HashMap::from([
        (
            alice_did.to_owned(),
            public_key_from_jwk(&alice_key.public_jwk(false).unwrap()).unwrap(),
        ),
        (
            bob_did.to_owned(),
            public_key_from_jwk(&bob_key.public_jwk(false).unwrap()).unwrap(),
        ),
    ])));

    let aud = "did:web:mls.catbird.blue#atproto_mls";
    let mut cfg = ServiceAuthVerifierConfig::new(ServiceAuthAudience::service(
        "did:web:mls.catbird.blue",
        "atproto_mls",
        true,
    ));
    cfg.required_claims = ServiceAuthRequiredClaims::SPECIFICATION;
    let verifier = ServiceAuthVerifier::from_config(cfg, resolver, Some(replay));
    let now = std::time::SystemTime::now();
    let now_secs = now
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
        .cast_signed();

    // Valid ES256 token
    let jwt_alice = OAuthCompactJwt::sign(
        &ServiceJwtPayload {
            iss: alice_did,
            aud,
            exp: now_secs + 120,
            iat: Some(now_secs),
            lxm: Some("blue.catbird.mlsChat.getConvos"),
            jti: Some("sa-jti-1"),
        },
        &alice_key,
        Some("JWT"),
        false,
    )
    .unwrap();
    let auth = verifier
        .verify_authorization_header_at(
            Some(&format!("Bearer {jwt_alice}")),
            &ServiceAuthMethodPolicy::Exactly("blue.catbird.mlsChat.getConvos".into()),
            now,
        )
        .await
        .expect("alice ES256 verifies");
    assert_eq!(auth.issuer, alice_did);
    assert_eq!(auth.algorithm, "ES256");

    // Replaying same jti fails
    let replay_err = verifier
        .verify_token_at(
            &jwt_alice,
            &ServiceAuthMethodPolicy::Exactly("blue.catbird.mlsChat.getConvos".into()),
            now,
        )
        .await
        .unwrap_err();
    assert_eq!(replay_err, ServiceAuthError::Replayed);

    // Valid ES256K token
    let jwt_bob = OAuthCompactJwt::sign(
        &ServiceJwtPayload {
            iss: bob_did,
            aud: "did:web:mls.catbird.blue",
            exp: now_secs + 120,
            iat: Some(now_secs),
            lxm: Some("blue.catbird.mlsChat.sendMessage"),
            jti: Some("sa-jti-2"),
        },
        &bob_key,
        Some("JWT"),
        false,
    )
    .unwrap();
    let auth_bob = verifier
        .verify_token_at(
            &jwt_bob,
            &ServiceAuthMethodPolicy::Exactly("blue.catbird.mlsChat.sendMessage".into()),
            now,
        )
        .await
        .expect("bob ES256K verifies");
    assert_eq!(auth_bob.algorithm, "ES256K");

    // Excessive lifetime (> 3600s default max lifetime) fails
    let too_long = OAuthCompactJwt::sign(
        &ServiceJwtPayload {
            iss: bob_did,
            aud,
            exp: now_secs + 4000,
            iat: Some(now_secs),
            lxm: Some("blue.catbird.mlsChat.sendMessage"),
            jti: Some("sa-jti-3"),
        },
        &bob_key,
        Some("JWT"),
        false,
    )
    .unwrap();
    assert!(matches!(
        verifier
            .verify_token_at(&too_long, &ServiceAuthMethodPolicy::Optional, now)
            .await,
        Err(ServiceAuthError::ExcessiveLifetime { .. })
    ));

    // Wrong method rejected
    let wrong_lxm = OAuthCompactJwt::sign(
        &ServiceJwtPayload {
            iss: alice_did,
            aud,
            exp: now_secs + 60,
            iat: Some(now_secs),
            lxm: Some("com.atproto.server.other"),
            jti: Some("sa-jti-4"),
        },
        &alice_key,
        Some("JWT"),
        false,
    )
    .unwrap();
    assert!(matches!(
        verifier
            .verify_token_at(
                &wrong_lxm,
                &ServiceAuthMethodPolicy::Exactly("blue.catbird.mlsChat.getConvos".into()),
                now,
            )
            .await,
        Err(ServiceAuthError::LexiconMethodMismatch { .. })
    ));
}

struct MockDidTransport {
    docs: HashMap<String, Vec<u8>>,
}

impl HttpTransport for MockDidTransport {
    #[allow(refining_impl_trait)]
    fn send(
        &self,
        req: http::Request<bytes::Bytes>,
        _opts: &SendOptions,
    ) -> std::pin::Pin<
        Box<
            dyn std::future::Future<Output = Result<http::Response<bytes::Bytes>, TransportError>>
                + Send,
        >,
    > {
        let url = req.uri().to_string();
        let found = self.docs.get(&url).cloned();
        Box::pin(async move {
            match found {
                Some(body) => Ok(http::Response::builder()
                    .status(200)
                    .header("content-type", "application/did+ld+json")
                    .body(bytes::Bytes::from(body))
                    .unwrap()),
                None => Ok(http::Response::builder()
                    .status(404)
                    .body(bytes::Bytes::new())
                    .unwrap()),
            }
        })
    }
}

struct StubDns;
impl DnsResolver for StubDns {
    fn txt(
        &self,
        _name: &str,
    ) -> impl std::future::Future<Output = Result<Vec<String>, DnsError>> + petrel::rt::MaybeSend
    {
        std::future::ready(Ok(Vec::new()))
    }
    fn lookup_ip(
        &self,
        _host: &str,
    ) -> impl std::future::Future<Output = Result<Vec<std::net::IpAddr>, DnsError>> + petrel::rt::MaybeSend
    {
        std::future::ready(Ok(Vec::new()))
    }
}

#[tokio::test]
async fn identity_resolver_service_auth_key_resolver_resolves_did_document_keys() {
    let key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256k, None).unwrap();
    let jwk = key.public_jwk(false).unwrap();
    let did_key = jwk.did_key().unwrap();
    let multibase = did_key.strip_prefix("did:key:").unwrap();
    let did = "did:web:alice.example.com";
    let did_doc = serde_json::json!({
        "id": did,
        "verificationMethod": [{
            "id": format!("{did}#atproto"),
            "type": "Multikey",
            "controller": did,
            "publicKeyMultibase": multibase
        }]
    })
    .to_string()
    .into_bytes();

    let mut docs = HashMap::new();
    docs.insert(
        "https://alice.example.com/.well-known/did.json".to_owned(),
        did_doc,
    );
    let transport: SharedTransport = Arc::new(MockDidTransport { docs });
    let id_resolver = Arc::new(IdentityResolver::with_cache(
        transport,
        StubDns,
        IdentityOptions::default(),
        InMemoryIdentityCache::default(),
    ));
    let key_resolver = IdentityResolverServiceAuthKeyResolver::new(id_resolver);
    let resolved = key_resolver
        .signing_key(did, false)
        .await
        .expect("resolve DID key");
    assert_eq!(resolved.did_key(), jwk.did_key().unwrap());
}

#[derive(Clone)]
struct AppState {
    service_auth: ServiceAuthState,
    dpop_state: DpopVerifierState,
}

impl axum::extract::FromRef<AppState> for ServiceAuthState {
    fn from_ref(s: &AppState) -> Self {
        s.service_auth.clone()
    }
}

impl axum::extract::FromRef<AppState> for DpopVerifierState {
    fn from_ref(s: &AppState) -> Self {
        s.dpop_state.clone()
    }
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn axum_xrpc_router_strict_input_query_params_declared_errors_and_auth_layers() {
    let oauth_harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;
    let verifier = Arc::new(
        oauth_harness
            .server
            .resource_verifier()
            .with_require_dpop_nonce(false),
    );

    let alice_key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let sa_resolver = Arc::new(StaticServiceAuthKeyResolver::new(HashMap::from([(
        common::ALICE_DID.to_owned(),
        public_key_from_jwk(&alice_key.public_jwk(false).unwrap()).unwrap(),
    )])));
    let sa_verifier = Arc::new(ServiceAuthVerifier::new(
        ServiceAuthAudience::exactly("did:web:api.example.com"),
        sa_resolver,
    ));

    let state = AppState {
        service_auth: ServiceAuthState::new(sa_verifier.clone()),
        dpop_state: DpopVerifierState::new(verifier, Some("https://api.example.com".to_owned())),
    };

    let mut router: Router = XrpcRouter::<AppState>::new()
        .authenticated_query::<get_timeline::GetTimeline, _, _>(
            |_st, auth: VerifiedServiceAuth, params| async move {
                assert_eq!(auth.issuer, common::ALICE_DID);
                if params.algorithm.as_deref() == Some("bad") {
                    return Err(XrpcServerError::InvalidRequest("bad algorithm".into()));
                }
                Ok(get_timeline::Output {
                    cursor: Some(format!("limit={}", params.limit)),
                    feed: Vec::new(),
                    start_cursor: None,
                })
            },
        )
        .procedure::<PutRecord, _, _>(|_st, _params, input: PutRecordInput| async move {
            if input.rkey.as_str() == "conflict" {
                return Err(XrpcServerError::declared_with_status(
                    409,
                    PutRecordError::InvalidSwap,
                    Some("swap check failed".to_owned()),
                ));
            }
            Ok(PutRecordOutput {
                cid: CidString::parse(
                    "bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454",
                )
                .unwrap(),
                uri: "at://did:plc:alice/app.bsky.feed.post/1".parse().unwrap(),
                commit: None,
                validation_status: None,
            })
        })
        .merge_router(Router::new().route(
            "/protected/dpop",
            get(|DpopResourceAuth(grant): DpopResourceAuth| async move { grant.did }),
        ))
        .merge_router(
            Router::new()
                .route(
                    "/protected/layered",
                    get(|req: Request<Body>| async move {
                        let auth = req.extensions().get::<VerifiedServiceAuth>().unwrap();
                        auth.issuer.clone()
                    }),
                )
                .layer(ServiceAuthLayer::new(sa_verifier)),
        )
        .merge_router(oauth_router(Arc::new(oauth_harness.server)))
        .with_state(state);

    let now_secs = std::time::SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
        .cast_signed();
    let jwt = OAuthCompactJwt::sign(
        &ServiceJwtPayload {
            iss: common::ALICE_DID,
            aud: "did:web:api.example.com",
            exp: now_secs + 60,
            iat: Some(now_secs),
            lxm: Some(get_timeline::GetTimeline::NSID),
            jti: Some("xrpc-jti-1"),
        },
        &alice_key,
        Some("JWT"),
        false,
    )
    .unwrap();

    // 1. Typed authenticated query + FromQueryParams
    let req = Request::builder()
        .method("GET")
        .uri("/xrpc/app.bsky.feed.getTimeline?limit=15&algorithm=reverse-chronological")
        .header("Authorization", format!("Bearer {jwt}"))
        .body(Body::empty())
        .unwrap();
    let resp = router.call(req).await.unwrap();
    assert_eq!(resp.status(), StatusCode::OK);
    let body = axum::body::to_bytes(resp.into_body(), 64 * 1024)
        .await
        .unwrap();
    let val: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(val["cursor"], "limit=15");

    // 2. Declared XRPC error JSON serialization (InvalidSwap)
    let conflict_body = serde_json::json!({
        "repo": common::ALICE_DID,
        "collection": "app.bsky.feed.post",
        "rkey": "conflict",
        "record": { "$type": "app.bsky.feed.post", "text": "hi", "createdAt": Datetime::now().unwrap().as_str() }
    })
    .to_string();
    let err_req = Request::builder()
        .method("POST")
        .uri("/xrpc/com.atproto.repo.putRecord")
        .header("Content-Type", "application/json")
        .body(Body::from(conflict_body))
        .unwrap();
    let err_resp = router.call(err_req).await.unwrap();
    assert_eq!(err_resp.status(), StatusCode::CONFLICT);
    let err_json: serde_json::Value = serde_json::from_slice(
        &axum::body::to_bytes(err_resp.into_body(), 64 * 1024)
            .await
            .unwrap(),
    )
    .unwrap();
    assert_eq!(err_json["error"], "InvalidSwap");
    assert_eq!(err_json["message"], "swap check failed");

    // 3. Strict XRPC input validation rejects malformed optional nested fields inside Input
    let invalid_optional_body = serde_json::json!({
        "repo": common::ALICE_DID,
        "collection": "app.bsky.feed.post",
        "rkey": RecordKey::parse("3k7b").unwrap().as_str(),
        "validate": "not-a-bool",
        "record": { "$type": "app.bsky.feed.post", "text": "hi", "createdAt": Datetime::now().unwrap().as_str() }
    })
    .to_string();
    let strict_req = Request::builder()
        .method("POST")
        .uri("/xrpc/com.atproto.repo.putRecord")
        .header("Content-Type", "application/json")
        .body(Body::from(invalid_optional_body))
        .unwrap();
    let strict_resp = router.call(strict_req).await.unwrap();
    assert_eq!(strict_resp.status(), StatusCode::BAD_REQUEST);

    // 4. Valid PutRecord succeeds cleanly
    let valid_body = serde_json::json!({
        "repo": common::ALICE_DID,
        "collection": "app.bsky.feed.post",
        "rkey": RecordKey::parse("3k7b").unwrap().as_str(),
        "record": { "$type": "app.bsky.feed.post", "text": "hi", "createdAt": Datetime::now().unwrap().as_str() }
    })
    .to_string();
    let ok_req = Request::builder()
        .method("POST")
        .uri("/xrpc/com.atproto.repo.putRecord")
        .header("Content-Type", "application/json")
        .body(Body::from(valid_body))
        .unwrap();
    let ok_resp = router.call(ok_req).await.unwrap();
    assert_eq!(ok_resp.status(), StatusCode::OK);

    // 4. ServiceAuthLayer sets VerifiedServiceAuth extension cleanly
    let layer_jwt = OAuthCompactJwt::sign(
        &ServiceJwtPayload {
            iss: common::ALICE_DID,
            aud: "did:web:api.example.com",
            exp: now_secs + 60,
            iat: Some(now_secs),
            lxm: None,
            jti: Some("xrpc-jti-2"),
        },
        &alice_key,
        Some("JWT"),
        false,
    )
    .unwrap();
    let layer_req = Request::builder()
        .method("GET")
        .uri("/protected/layered")
        .header("Authorization", format!("Bearer {layer_jwt}"))
        .body(Body::empty())
        .unwrap();
    let layer_resp = router.call(layer_req).await.unwrap();
    assert_eq!(layer_resp.status(), StatusCode::OK);
    let layer_body = axum::body::to_bytes(layer_resp.into_body(), 1024)
        .await
        .unwrap();
    assert_eq!(&layer_body[..], common::ALICE_DID.as_bytes());
    let _ = (
        Duration::from_secs(1),
        make_dpop_proof,
        OAuthDpopProofValidator::access_token_hash,
    );
}

#[tokio::test]
async fn service_auth_replay_retained_through_clock_skew_window() {
    use petrel_server::service_auth::OAuthReplayStoreServiceAuthAdapter;
    use petrel_server::store::InMemoryOAuthStore;
    use petrel_server::support::{OAuthClock as _, OAuthKeyedDigest, SystemOAuthClock};

    let alice_key =
        OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("#atproto".into())).unwrap();
    let resolver = Arc::new(StaticServiceAuthKeyResolver::new(HashMap::from([(
        common::ALICE_DID.to_owned(),
        public_key_from_jwk(&alice_key.public_jwk(false).unwrap()).unwrap(),
    )])));

    let now_secs = SystemOAuthClock.now_secs();
    let token_exp_past_within_skew = now_secs - 20;

    let stores: [(&str, Arc<dyn ServiceAuthReplayStore>); 2] = [
        ("in_memory", Arc::new(InMemoryServiceAuthReplayStore::new())),
        (
            "oauth_adapter",
            Arc::new(OAuthReplayStoreServiceAuthAdapter::new(
                Arc::new(InMemoryOAuthStore::new()),
                OAuthKeyedDigest::new([11_u8; 32]).unwrap(),
            )),
        ),
    ];

    for (label, replay) in stores {
        let mut cfg =
            ServiceAuthVerifierConfig::new(ServiceAuthAudience::exactly("did:web:api.example.com"));
        cfg.clock_skew = Duration::from_secs(60);
        let verifier = ServiceAuthVerifier::from_config(cfg, resolver.clone(), Some(replay));

        let jwt = OAuthCompactJwt::sign(
            &ServiceJwtPayload {
                iss: common::ALICE_DID,
                aud: "did:web:api.example.com",
                exp: token_exp_past_within_skew,
                iat: Some(token_exp_past_within_skew - 60),
                lxm: Some("app.bsky.feed.getTimeline"),
                jti: Some(&format!("skew-replay-{label}")),
            },
            &alice_key,
            Some("JWT"),
            false,
        )
        .unwrap();

        let policy = ServiceAuthMethodPolicy::Exactly("app.bsky.feed.getTimeline".into());
        assert!(
            verifier.verify_token(&jwt, &policy).await.is_ok(),
            "{label}: first verification within skew must pass"
        );
        let replay_err = verifier
            .verify_token(&jwt, &policy)
            .await
            .expect_err("replay during skew window must fail");
        assert!(
            matches!(replay_err, ServiceAuthError::Replayed),
            "{label}: expected Replayed, got {replay_err:?}"
        );
    }
}

#[tokio::test]
async fn service_auth_layer_invokes_poll_ready_inner_instance() {
    use axum::response::IntoResponse;
    use futures_util::future::poll_fn;
    use petrel_server::axum::ServiceAuthLayer;
    use petrel_server::support::{OAuthClock as _, SystemOAuthClock};
    use std::convert::Infallible;
    use std::future::Future;
    use std::pin::Pin;
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::task::{Context, Poll};
    use tower_layer::Layer;
    use tower_service::Service;

    struct ReadinessStrictInner {
        ready_permit: bool,
        called_without_ready: Arc<AtomicBool>,
    }

    impl Clone for ReadinessStrictInner {
        fn clone(&self) -> Self {
            // A fresh clone has not been polled for readiness yet.
            Self {
                ready_permit: false,
                called_without_ready: self.called_without_ready.clone(),
            }
        }
    }

    impl ReadinessStrictInner {
        fn new(called_without_ready: Arc<AtomicBool>) -> Self {
            Self {
                ready_permit: false,
                called_without_ready,
            }
        }
    }

    impl Service<Request<Body>> for ReadinessStrictInner {
        type Response = axum::response::Response;
        type Error = Infallible;
        type Future = Pin<Box<dyn Future<Output = Result<Self::Response, Self::Error>> + Send>>;

        fn poll_ready(&mut self, _cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
            self.ready_permit = true;
            Poll::Ready(Ok(()))
        }

        fn call(&mut self, _req: Request<Body>) -> Self::Future {
            if !self.ready_permit {
                self.called_without_ready.store(true, Ordering::SeqCst);
            }
            self.ready_permit = false;
            let status = if self.called_without_ready.load(Ordering::SeqCst) {
                StatusCode::INTERNAL_SERVER_ERROR
            } else {
                StatusCode::OK
            };
            Box::pin(async move { Ok(status.into_response()) })
        }
    }

    let alice_key =
        OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("#atproto".into())).unwrap();
    let resolver = Arc::new(StaticServiceAuthKeyResolver::new(HashMap::from([(
        common::ALICE_DID.to_owned(),
        public_key_from_jwk(&alice_key.public_jwk(false).unwrap()).unwrap(),
    )])));
    let verifier = Arc::new(ServiceAuthVerifier::new(
        ServiceAuthAudience::exactly("did:web:api.example.com"),
        resolver,
    ));
    let called_without_ready = Arc::new(AtomicBool::new(false));
    let layer = ServiceAuthLayer::new(verifier);
    let mut svc = layer.layer(ReadinessStrictInner::new(called_without_ready.clone()));

    let jwt = OAuthCompactJwt::sign(
        &ServiceJwtPayload {
            iss: common::ALICE_DID,
            aud: "did:web:api.example.com",
            exp: SystemOAuthClock.now_secs() + 60,
            iat: Some(SystemOAuthClock.now_secs()),
            lxm: None,
            jti: Some("ready-test-1"),
        },
        &alice_key,
        Some("JWT"),
        false,
    )
    .unwrap();
    let req = Request::builder()
        .method("GET")
        .uri("/check")
        .header("Authorization", format!("Bearer {jwt}"))
        .body(Body::empty())
        .unwrap();
    poll_fn(|cx| svc.poll_ready(cx)).await.unwrap();
    let resp = svc.call(req).await.unwrap();
    assert_eq!(resp.status(), StatusCode::OK);
    assert!(!called_without_ready.load(Ordering::SeqCst));
}

#[tokio::test]
async fn axum_dpop_rejects_unconfigured_forwarded_host_and_service_auth_throttles_forced_refresh() {
    use std::sync::atomic::{AtomicUsize, Ordering};

    use petrel::rt::BoxFuture;
    use petrel_server::support::{OAuthClock, SystemOAuthClock};

    struct CountingResolver {
        key: PublicKey,
        forced_calls: Arc<AtomicUsize>,
    }
    impl ServiceAuthKeyResolver for CountingResolver {
        fn signing_key<'a>(
            &'a self,
            _did: &'a str,
            force_refresh: bool,
        ) -> BoxFuture<'a, Result<PublicKey, ServiceAuthError>> {
            if force_refresh {
                self.forced_calls.fetch_add(1, Ordering::SeqCst);
            }
            let k = self.key.clone();
            Box::pin(async move { Ok(k) })
        }
    }

    // 1. DpopVerifierState::new(verifier, None) refuses spoofed Host/X-Forwarded-Proto fallback
    let oauth_harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;
    let verifier = Arc::new(
        oauth_harness
            .server
            .resource_verifier()
            .with_require_dpop_nonce(false),
    );
    let mut app: Router = Router::new()
        .route(
            "/protected",
            get(|DpopResourceAuth(g): DpopResourceAuth| async move { g.did }),
        )
        .with_state(DpopVerifierState::new(verifier, None));
    let spoofed = app
        .call(
            Request::get("/protected")
                .header("Host", "spoofed.example.com")
                .header("X-Forwarded-Proto", "https")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(spoofed.status(), StatusCode::UNAUTHORIZED);

    // 2. ServiceAuthVerifier + CachingServiceAuthKeyResolver throttles repeated forced DID key refreshes within cooldown
    let doc_key =
        OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("#atproto".into())).unwrap();
    let wrong_key =
        OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("#atproto".into())).unwrap();
    let forced_calls = Arc::new(AtomicUsize::new(0));
    let resolver = Arc::new(CachingServiceAuthKeyResolver::new(CountingResolver {
        key: public_key_from_jwk(&doc_key.public_jwk(false).unwrap()).unwrap(),
        forced_calls: forced_calls.clone(),
    }));
    let cfg = ServiceAuthVerifierConfig::new(ServiceAuthAudience::exactly("did:web:api.ex"));
    let sa_verifier = ServiceAuthVerifier::from_config(cfg, resolver, None);

    let now_secs = SystemOAuthClock.now_secs();
    let bad_jwt = OAuthCompactJwt::sign(
        &ServiceJwtPayload {
            iss: "did:plc:victm234567234567abcdefg",
            aud: "did:web:api.ex",
            exp: now_secs + 60,
            iat: Some(now_secs),
            lxm: None,
            jti: Some("bad-sig-1"),
        },
        &wrong_key,
        Some("JWT"),
        false,
    )
    .unwrap();
    for _ in 0..5 {
        assert!(
            sa_verifier
                .verify_token(&bad_jwt, &ServiceAuthMethodPolicy::Optional)
                .await
                .is_err()
        );
    }
    assert_eq!(forced_calls.load(Ordering::SeqCst), 1);
}
