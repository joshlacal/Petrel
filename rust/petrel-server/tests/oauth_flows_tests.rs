#![cfg(not(target_arch = "wasm32"))]

mod common;

use std::collections::BTreeSet;
use std::sync::Arc;

use axum::Router;
use axum::body::Body;
use axum::http::{Request, StatusCode};
use axum::routing::get;
use common::{
    ALICE_DID, ALICE_HANDLE, CONFIDENTIAL_CLIENT_ID, CONFIDENTIAL_REDIRECT, TEST_ISSUER,
    TestClient, TestServer, WEB_CLIENT_ID, make_dpop_proof,
};
use petrel_oauth_scopes::ScopeSet;
use petrel_server::axum::{DpopResourceAuth, DpopVerifierState, oauth_router};
use petrel_server::dpop::OAuthDpopProofValidator;
use petrel_server::http::{OAuthForm, OAuthHttpHeaders};
use petrel_server::jose::{
    OAuthCompactJwt, OAuthJsonWebKeySet, OAuthJwsAlgorithm, OAuthJwtVerificationConstraints,
    OAuthSigningKey,
};
use petrel_server::lexicon::OAuthLexiconDocument;
use petrel_server::oauth::config::OAuthAccessTokenFormat;
use petrel_server::oauth::tokens::OAuthAccessTokenClaims;
use petrel_server::oauth::{
    OAuthAuthorizationServerConfiguration, OAuthAuthorizationServerMetadata,
    OAuthProtectedResourceMetadata, OAuthResourceServerVerifier, OAuthResourceVerificationMode,
};
use petrel_server::store::{InMemoryOAuthStore, OAuthStorePurging, OAuthTokenStore};
use petrel_server::support::{DigestPurpose, OAuthClock};
use tower_service::Service as _;

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn full_public_and_confidential_oauth_flows_rotation_and_revocation() {
    for format in [OAuthAccessTokenFormat::Opaque, OAuthAccessTokenFormat::Jwt] {
        let harness = TestServer::new(format).await;

        // Public client sign-in
        let mut web = TestClient::web(&harness);
        let tok1 = web
            .sign_in(ALICE_HANDLE, "alice-password", "atproto transition:generic")
            .await;
        assert_eq!(tok1.token_type, "DPoP");
        assert_eq!(tok1.sub, ALICE_DID);

        // Verify token via shared resource verifier
        let verifier = harness.server.resource_verifier();
        let resource_url = "https://pds.example.com/xrpc/com.atproto.server.getSession";
        let ath1 = OAuthDpopProofValidator::access_token_hash(&tok1.access_token);
        let res_nonce = verifier.current_nonce();
        let res_proof = make_dpop_proof(
            &web.dpop_key,
            "GET",
            resource_url,
            Some(&res_nonce),
            Some(&ath1),
            harness.clock.now_secs(),
            "res-1",
        );
        let grant = verifier
            .authenticate(
                "GET",
                resource_url,
                &OAuthHttpHeaders::new([
                    (
                        "Authorization",
                        format!("DPoP {}", tok1.access_token).as_str(),
                    ),
                    ("DPoP", res_proof.as_str()),
                ]),
            )
            .await
            .expect("verify issued access token");
        assert_eq!(grant.did, ALICE_DID);
        assert!(grant.require_repo("app.bsky.feed.post", "create").is_ok());

        // Stateless verification in JWT mode
        if format == OAuthAccessTokenFormat::Jwt {
            let jwks = harness.server.jwks().unwrap();
            let stateless = OAuthResourceServerVerifier::new(
                OAuthResourceVerificationMode::Stateless {
                    issuer: TEST_ISSUER.into(),
                    jwks,
                    expected_audience: Some(TEST_ISSUER.into()),
                },
                petrel_server::dpop::OAuthDpopNonceService::with_defaults(
                    petrel_server::support::OAuthKeyedDigest::new(vec![7_u8; 32]).unwrap(),
                ),
                petrel_server::support::OAuthKeyedDigest::new(vec![7_u8; 32]).unwrap(),
                harness.store.clone(),
                harness.clock.clone(),
            )
            .with_require_dpop_nonce(false);

            let proof2 = make_dpop_proof(
                &web.dpop_key,
                "GET",
                resource_url,
                None,
                Some(&ath1),
                harness.clock.now_secs(),
                "res-stateless",
            );
            let s_grant = stateless
                .authenticate(
                    "GET",
                    resource_url,
                    &OAuthHttpHeaders::new([
                        (
                            "Authorization",
                            format!("DPoP {}", tok1.access_token).as_str(),
                        ),
                        ("DPoP", proof2.as_str()),
                    ]),
                )
                .await
                .expect("stateless JWT verification");
            assert_eq!(s_grant.did, ALICE_DID);
        }

        // Refresh rotation succeeds and previous refresh token replay revokes session!
        let r_resp = web
            .send_post(
                "/oauth/token",
                &[
                    ("grant_type", "refresh_token"),
                    ("refresh_token", &tok1.refresh_token),
                ],
            )
            .await;
        assert_eq!(r_resp.status, 200, "refresh failed: {}", r_resp.text());
        let tok2: common::TokenResponse = serde_json::from_slice(&r_resp.body).unwrap();
        assert_ne!(tok2.refresh_token, tok1.refresh_token);

        // Wrong DPoP key cannot use tok2 refresh token
        let mut wrong_key_client = TestClient::web(&harness);
        wrong_key_client.nonce = web.nonce.clone();
        let thief_resp = wrong_key_client
            .send_post(
                "/oauth/token",
                &[
                    ("grant_type", "refresh_token"),
                    ("refresh_token", &tok2.refresh_token),
                ],
            )
            .await;
        assert_eq!(thief_resp.status, 400);

        // Replay old tok1.refresh_token revokes entire session
        let replay_resp = web
            .send_post(
                "/oauth/token",
                &[
                    ("grant_type", "refresh_token"),
                    ("refresh_token", &tok1.refresh_token),
                ],
            )
            .await;
        assert_eq!(replay_resp.status, 400);
        let post_replay = web
            .send_post(
                "/oauth/token",
                &[
                    ("grant_type", "refresh_token"),
                    ("refresh_token", &tok2.refresh_token),
                ],
            )
            .await;
        assert_eq!(post_replay.status, 400);

        // Confidential client sign-in + revoke
        let mut conf = TestClient::confidential(&harness);
        let c_tok = conf
            .sign_in(
                common::BOB_HANDLE,
                "bob-password",
                "atproto transition:generic",
            )
            .await;
        let rev_resp = conf
            .send_post("/oauth/revoke", &[("token", &c_tok.access_token)])
            .await;
        assert_eq!(rev_resp.status, 200);
        let after_revoke = conf
            .send_post(
                "/oauth/token",
                &[
                    ("grant_type", "refresh_token"),
                    ("refresh_token", &c_tok.refresh_token),
                ],
            )
            .await;
        assert_eq!(after_revoke.status, 400);
    }
}

#[tokio::test]
async fn metadata_jwks_cors_par_validation_and_csrf_hardening() {
    let harness = TestServer::new(OAuthAccessTokenFormat::Jwt).await;

    let meta_resp = harness
        .get("/.well-known/oauth-authorization-server", None)
        .await;
    assert_eq!(meta_resp.status, 200);
    let meta: OAuthAuthorizationServerMetadata = serde_json::from_slice(&meta_resp.body).unwrap();
    assert_eq!(meta.issuer, TEST_ISSUER);
    assert!(meta.require_pushed_authorization_requests);
    assert_eq!(
        meta_resp.headers.get("Access-Control-Allow-Origin"),
        Some("*")
    );

    let pr_resp = harness
        .get("/.well-known/oauth-protected-resource", None)
        .await;
    assert_eq!(pr_resp.status, 200);
    let pr: OAuthProtectedResourceMetadata = serde_json::from_slice(&pr_resp.body).unwrap();
    assert!(pr.dpop_bound_access_tokens_required);

    let jwks_resp = harness.get("/oauth/jwks", None).await;
    assert_eq!(jwks_resp.status, 200);
    let jwks = OAuthJsonWebKeySet::decode_validated(&jwks_resp.body).unwrap();
    assert_eq!(jwks.keys.len(), 1);

    // Authorize GET requires PAR request_uri and returns no CORS headers + X-Frame-Options: DENY
    let missing_par = harness.get("/oauth/authorize", Some("client_id=x")).await;
    assert_eq!(missing_par.status, 400);
    assert_eq!(missing_par.headers.get("X-Frame-Options"), Some("DENY"));
    assert_eq!(missing_par.headers.get("Access-Control-Allow-Origin"), None);

    // PAR rejects missing atproto scope, openid scope, bad PKCE challenge, bad redirect_uri
    let mut client = TestClient::web(&harness);
    let chal = client.challenge();
    let bad_scope = client
        .send_post(
            "/oauth/par",
            &[
                ("response_type", "code"),
                ("code_challenge", &chal),
                ("code_challenge_method", "S256"),
                ("redirect_uri", common::WEB_REDIRECT),
                ("scope", "transition:generic"),
            ],
        )
        .await;
    assert_eq!(bad_scope.status, 400);

    let openid = client
        .send_post(
            "/oauth/par",
            &[
                ("response_type", "code"),
                ("code_challenge", &chal),
                ("code_challenge_method", "S256"),
                ("redirect_uri", common::WEB_REDIRECT),
                ("scope", "atproto openid"),
            ],
        )
        .await;
    assert_eq!(openid.status, 400);

    // CSRF mismatch on authorize POST fails with 403
    let uri = client.push_request("atproto transition:generic").await;
    let q = format!(
        "client_id={}&request_uri={}",
        OAuthForm::encode_component(WEB_CLIENT_ID),
        OAuthForm::encode_component(&uri)
    );
    let page = harness.get("/oauth/authorize", Some(&q)).await;
    let flow_id = common::extract_hidden_input(&page.text(), "flow_id");
    let csrf = common::extract_hidden_input(&page.text(), "csrf_token");
    let csrf_fail = harness
        .post_form(
            "/oauth/authorize",
            &[
                ("flow_id", &flow_id),
                ("csrf_token", &csrf),
                ("identifier", ALICE_HANDLE),
                ("password", "alice-password"),
                ("decision", "approve"),
            ],
            &[("Cookie", "__Host-petrel_oauth_csrf=wrong-cookie")],
        )
        .await;
    assert_eq!(csrf_fail.status, 403);
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn include_permission_set_expansion_and_store_purging() {
    let harness = TestServer::new(OAuthAccessTokenFormat::Jwt).await;
    let nsid = "app.example.permissionSet";
    let doc_json = serde_json::json!({
        "lexicon": 1,
        "id": nsid,
        "defs": {
            "main": {
                "type": "permission-set",
                "title": "Read Posts",
                "detail": "Allows reading feed posts",
                "permissions": [
                    { "type": "permission", "resource": "repo", "collection": ["app.example.post"], "action": ["create"] }
                ]
            }
        }
    })
    .to_string()
    .into_bytes();
    let doc = OAuthLexiconDocument::from_json(nsid, None, None, doc_json).unwrap();
    harness.lexicons.register(doc).await;

    // Register client declaring include:app.example.permissionSet
    let mut clients_raw = BTreeSet::new();
    clients_raw.insert("atproto".to_owned());
    clients_raw.insert(format!("include:{nsid}"));
    let _ = ScopeSet::from_raw_scopes(clients_raw);

    let inc_client_id = "https://inc.example.com/client.json";
    let inc_redirect = "https://inc.example.com/cb";
    harness
        .clients
        .register(petrel_server::clients::OAuthResolvedClientMetadata {
            kind: petrel_server::clients::OAuthClientKind::Discoverable,
            metadata: petrel_server::clients::OAuthClientMetadata {
                client_id: inc_client_id.to_owned(),
                client_name: Some("Inc App".to_owned()),
                client_uri: None,
                logo_uri: None,
                tos_uri: None,
                policy_uri: None,
                application_type: petrel_server::clients::OAuthApplicationType::Web,
                grant_types: vec!["authorization_code".into(), "refresh_token".into()],
                response_types: vec!["code".into()],
                redirect_uris: vec![inc_redirect.into()],
                scope: Some(format!("atproto include:{nsid}")),
                token_endpoint_auth_method:
                    petrel_server::clients::OAuthTokenEndpointAuthMethod::None,
                token_endpoint_auth_signing_alg: None,
                dpop_bound_access_tokens: true,
                jwks_uri: None,
                jwks: None,
            },
            key_set: None,
        })
        .await;

    let mut inc_client = TestClient::web(&harness);
    inc_client.client_id = inc_client_id.into();
    inc_client.redirect_uri = inc_redirect.into();
    let tok = inc_client
        .sign_in(
            ALICE_HANDLE,
            "alice-password",
            &format!("atproto include:{nsid}"),
        )
        .await;

    let verifier = harness
        .server
        .resource_verifier()
        .with_require_dpop_nonce(false);
    let res_url = "https://pds.example.com/xrpc/com.atproto.repo.createRecord";
    let ath = OAuthDpopProofValidator::access_token_hash(&tok.access_token);
    let proof = make_dpop_proof(
        &inc_client.dpop_key,
        "POST",
        res_url,
        None,
        Some(&ath),
        harness.clock.now_secs(),
        "inc-1",
    );
    let grant = verifier
        .authenticate(
            "POST",
            res_url,
            &OAuthHttpHeaders::new([
                (
                    "Authorization",
                    format!("DPoP {}", tok.access_token).as_str(),
                ),
                ("DPoP", proof.as_str()),
            ]),
        )
        .await
        .expect("grant with expanded permission set");
    assert!(grant.require_repo("app.example.post", "create").is_ok());
    assert!(grant.require_repo("app.bsky.feed.post", "create").is_err());

    // Advance time past refresh expiration (90 days) and purge
    harness.clock.advance(100 * 24 * 60 * 60);
    let purged = harness
        .store
        .purge_expired(harness.clock.now_secs())
        .await
        .unwrap();
    assert!(purged >= 1);
    assert_eq!(harness.store.snapshot_sessions().await.len(), 0);

    // Axum DpopResourceAuth integration smoke
    let mut cfg = OAuthAuthorizationServerConfiguration::new(TEST_ISSUER, vec![7_u8; 32]).unwrap();
    cfg.access_token_format = OAuthAccessTokenFormat::Jwt;
    let verifier_arc = Arc::new(
        harness
            .server
            .resource_verifier()
            .with_require_dpop_nonce(false),
    );
    let mut axum_app: Router = oauth_router::<DpopVerifierState>(Arc::new(harness.server))
        .merge(Router::new().route(
            "/resource",
            get(|DpopResourceAuth(g): DpopResourceAuth| async move { g.did }),
        ))
        .with_state(DpopVerifierState::new(
            verifier_arc,
            Some("https://api.example.com".into()),
        ));
    let unauth = axum_app
        .call(Request::get("/resource").body(Body::empty()).unwrap())
        .await
        .unwrap();
    assert_eq!(unauth.status(), StatusCode::UNAUTHORIZED);

    let _ = (
        CONFIDENTIAL_CLIENT_ID,
        CONFIDENTIAL_REDIRECT,
        OAuthCompactJwt::verify_with_jwks::<OAuthAccessTokenClaims>,
        OAuthJwtVerificationConstraints::new,
        OAuthJwsAlgorithm::Es256,
        OAuthSigningKey::generate,
        DigestPurpose::AccessToken,
        InMemoryOAuthStore::new,
        <InMemoryOAuthStore as OAuthTokenStore>::lookup_session,
    );
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn jwt_refresh_rotation_does_not_resurrect_intervening_revocation() {
    use common::{TestAccounts, TestClock, TestRandom, WEB_REDIRECT, extract_hidden_input};
    use petrel::rt::BoxFuture;
    use petrel_server::OAuthServerError;
    use petrel_server::clients::{
        OAuthApplicationType, OAuthClientKind, OAuthClientMetadata, OAuthResolvedClientMetadata,
        OAuthTokenEndpointAuthMethod, StaticOAuthClientResolver,
    };
    use petrel_server::http::{OAuthHttpRequest, OAuthHttpResponse};
    use petrel_server::oauth::OAuthAuthorizationServer;
    use petrel_server::oauth::interface::DefaultOAuthHtmlRenderer;
    use petrel_server::store::{
        OAuthRefreshRotationResult, OAuthServerStores, OAuthSession, RotateRefreshTokenParams,
    };
    use petrel_server::support::OAuthPkce;

    struct RevokeAfterRotateStore {
        inner: Arc<InMemoryOAuthStore>,
        revoke_at_secs: i64,
    }

    impl OAuthTokenStore for RevokeAfterRotateStore {
        fn store_session(
            &self,
            session: OAuthSession,
        ) -> BoxFuture<'_, Result<(), OAuthServerError>> {
            self.inner.store_session(session)
        }
        fn lookup_by_access_token_digest(
            &self,
            digest: &[u8],
        ) -> BoxFuture<'_, Result<Option<OAuthSession>, OAuthServerError>> {
            self.inner.lookup_by_access_token_digest(digest)
        }
        fn lookup_session(
            &self,
            session_id: &str,
        ) -> BoxFuture<'_, Result<Option<OAuthSession>, OAuthServerError>> {
            self.inner.lookup_session(session_id)
        }
        fn lookup_by_token_digest(
            &self,
            token_digest: &[u8],
        ) -> BoxFuture<'_, Result<Option<OAuthSession>, OAuthServerError>> {
            self.inner.lookup_by_token_digest(token_digest)
        }
        fn rotate_refresh_token<'a>(
            &'a self,
            params: RotateRefreshTokenParams<'a>,
        ) -> BoxFuture<'a, Result<OAuthRefreshRotationResult, OAuthServerError>> {
            Box::pin(async move {
                let res = self.inner.rotate_refresh_token(params).await?;
                if let OAuthRefreshRotationResult::Rotated { ref session, .. } = res {
                    let _ = self
                        .inner
                        .revoke_session(&session.session_id, self.revoke_at_secs)
                        .await?;
                }
                Ok(res)
            })
        }
        fn revoke_session(
            &self,
            session_id: &str,
            revoked_at_secs: i64,
        ) -> BoxFuture<'_, Result<bool, OAuthServerError>> {
            self.inner.revoke_session(session_id, revoked_at_secs)
        }
        fn revoke_by_token_digest(
            &self,
            token_digest: &[u8],
            revoked_at_secs: i64,
        ) -> BoxFuture<'_, Result<bool, OAuthServerError>> {
            self.inner
                .revoke_by_token_digest(token_digest, revoked_at_secs)
        }
    }

    async fn post_form(
        server: &OAuthAuthorizationServer,
        path: &str,
        fields: &[(&str, &str)],
        headers: &[(&str, &str)],
    ) -> OAuthHttpResponse {
        let body = fields
            .iter()
            .map(|(k, v)| {
                format!(
                    "{}={}",
                    OAuthForm::encode_component(k),
                    OAuthForm::encode_component(v)
                )
            })
            .collect::<Vec<_>>()
            .join("&");
        let mut hdrs = OAuthHttpHeaders::new(headers.iter().copied());
        hdrs.set("Content-Type", "application/x-www-form-urlencoded");
        server
            .handle(
                OAuthHttpRequest::new("POST", path)
                    .with_headers(hdrs)
                    .with_body(body.into_bytes()),
            )
            .await
    }

    let inner = Arc::new(InMemoryOAuthStore::new());
    let wrapped: Arc<dyn OAuthTokenStore> = Arc::new(RevokeAfterRotateStore {
        inner: inner.clone(),
        revoke_at_secs: 1_700_000_050,
    });
    let mut cfg = OAuthAuthorizationServerConfiguration::new(TEST_ISSUER, vec![7_u8; 32]).unwrap();
    cfg.access_token_format = OAuthAccessTokenFormat::Jwt;
    let client_resolver = Arc::new(StaticOAuthClientResolver::new().with_client(
        OAuthResolvedClientMetadata {
            kind: OAuthClientKind::Discoverable,
            metadata: OAuthClientMetadata {
                client_id: WEB_CLIENT_ID.to_owned(),
                client_name: Some("Web Example".to_owned()),
                client_uri: None,
                logo_uri: None,
                tos_uri: None,
                policy_uri: None,
                application_type: OAuthApplicationType::Web,
                grant_types: vec!["authorization_code".into(), "refresh_token".into()],
                response_types: vec!["code".into()],
                redirect_uris: vec![WEB_REDIRECT.to_owned()],
                scope: Some("atproto transition:generic".into()),
                token_endpoint_auth_method: OAuthTokenEndpointAuthMethod::None,
                token_endpoint_auth_signing_alg: None,
                dpop_bound_access_tokens: true,
                jwks_uri: None,
                jwks: None,
            },
            key_set: None,
        },
    ));
    let clock = Arc::new(TestClock::new(1_700_000_000));
    let mut stores = OAuthServerStores::from_unified(inner.clone());
    stores.tokens = wrapped;
    let server = OAuthAuthorizationServer::with_dependencies(
        cfg,
        stores,
        Arc::new(TestAccounts::with_alice_and_bob()),
        client_resolver,
        None,
        Arc::new(DefaultOAuthHtmlRenderer),
        clock.clone(),
        Arc::new(TestRandom::new()),
    )
    .unwrap();

    let dpop_key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let verifier = "rev-verifier-0123456789012345678901234567890123456789-._~";
    let challenge = OAuthPkce::s256_challenge(verifier);

    let par_url = format!("{TEST_ISSUER}/oauth/par");
    let par_fields = [
        ("client_id", WEB_CLIENT_ID),
        ("response_type", "code"),
        ("code_challenge", challenge.as_str()),
        ("code_challenge_method", "S256"),
        ("state", "s1"),
        ("redirect_uri", WEB_REDIRECT),
        ("scope", "atproto transition:generic"),
    ];
    let par_p0 = make_dpop_proof(
        &dpop_key,
        "POST",
        &par_url,
        None,
        None,
        clock.now_secs(),
        "j0",
    );
    let par_c = post_form(&server, "/oauth/par", &par_fields, &[("DPoP", &par_p0)]).await;
    let nonce = par_c.headers.get("dpop-nonce").unwrap().to_owned();
    let par_p1 = make_dpop_proof(
        &dpop_key,
        "POST",
        &par_url,
        Some(&nonce),
        None,
        clock.now_secs(),
        "j1",
    );
    let par_ok = post_form(&server, "/oauth/par", &par_fields, &[("DPoP", &par_p1)]).await;
    assert_eq!(par_ok.status, 201);
    let par: common::ParResponse = serde_json::from_slice(&par_ok.body).unwrap();

    let auth_req = OAuthHttpRequest::new("GET", "/oauth/authorize").with_query(format!(
        "client_id={}&request_uri={}",
        OAuthForm::encode_component(WEB_CLIENT_ID),
        OAuthForm::encode_component(&par.request_uri)
    ));
    let page = server.handle(auth_req).await;
    assert_eq!(page.status, 200);
    let cookie = page
        .headers
        .get("Set-Cookie")
        .unwrap()
        .split(';')
        .next()
        .unwrap()
        .to_owned();
    let html = page.text();
    let flow_id = extract_hidden_input(&html, "flow_id");
    let csrf_token = extract_hidden_input(&html, "csrf_token");
    let consent = post_form(
        &server,
        "/oauth/authorize",
        &[
            ("flow_id", &flow_id),
            ("csrf_token", &csrf_token),
            ("identifier", ALICE_HANDLE),
            ("password", "alice-password"),
            ("decision", "approve"),
        ],
        &[("Cookie", &cookie)],
    )
    .await;
    assert_eq!(consent.status, 303);
    let loc = consent.headers.get("Location").unwrap();
    let code = url::Url::parse(loc)
        .unwrap()
        .query_pairs()
        .find(|(k, _)| k == "code")
        .unwrap()
        .1
        .into_owned();

    let tok_url = format!("{TEST_ISSUER}/oauth/token");
    let tok_p = make_dpop_proof(
        &dpop_key,
        "POST",
        &tok_url,
        Some(&nonce),
        None,
        clock.now_secs(),
        "j2",
    );
    let tok_resp = post_form(
        &server,
        "/oauth/token",
        &[
            ("client_id", WEB_CLIENT_ID),
            ("grant_type", "authorization_code"),
            ("code", &code),
            ("code_verifier", verifier),
            ("redirect_uri", WEB_REDIRECT),
        ],
        &[("DPoP", &tok_p)],
    )
    .await;
    assert_eq!(tok_resp.status, 200);
    let tok: common::TokenResponse = serde_json::from_slice(&tok_resp.body).unwrap();

    clock.advance(10);
    let rot_p = make_dpop_proof(
        &dpop_key,
        "POST",
        &tok_url,
        Some(&nonce),
        None,
        clock.now_secs(),
        "j3",
    );
    let rot_resp = post_form(
        &server,
        "/oauth/token",
        &[
            ("client_id", WEB_CLIENT_ID),
            ("grant_type", "refresh_token"),
            ("refresh_token", &tok.refresh_token),
        ],
        &[("DPoP", &rot_p)],
    )
    .await;
    assert_eq!(rot_resp.status, 200);

    // Concurrent/post-rotation revocation must NOT be overwritten by a stale snapshot.
    let sessions = inner.snapshot_sessions().await;
    assert_eq!(sessions.len(), 1);
    assert!(sessions[0].revoked_at_secs.is_some());
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn revoke_propagates_token_store_failures_and_cnf_bound_par_rejects_mismatched_dpop() {
    use common::{CONFIDENTIAL_REDIRECT, TestAccounts, TestClock, TestRandom};
    use petrel::rt::BoxFuture;
    use petrel_server::OAuthServerError;
    use petrel_server::clients::{
        OAuthApplicationType, OAuthClientKind, OAuthClientMetadata, OAuthResolvedClientMetadata,
        OAuthTokenEndpointAuthMethod, StaticOAuthClientResolver,
    };
    use petrel_server::http::{OAuthHttpRequest, OAuthHttpResponse};
    use petrel_server::oauth::OAuthAuthorizationServer;
    use petrel_server::oauth::interface::DefaultOAuthHtmlRenderer;
    use petrel_server::store::{
        OAuthRefreshRotationResult, OAuthServerStores, OAuthSession, RotateRefreshTokenParams,
    };
    use petrel_server::support::OAuthPkce;

    async fn post_form(
        server: &OAuthAuthorizationServer,
        path: &str,
        fields: &[(&str, &str)],
        headers: &[(&str, &str)],
    ) -> OAuthHttpResponse {
        let body = fields
            .iter()
            .map(|(k, v)| {
                format!(
                    "{}={}",
                    OAuthForm::encode_component(k),
                    OAuthForm::encode_component(v)
                )
            })
            .collect::<Vec<_>>()
            .join("&");
        let mut hdrs = OAuthHttpHeaders::new(headers.iter().copied());
        hdrs.set("Content-Type", "application/x-www-form-urlencoded");
        server
            .handle(
                OAuthHttpRequest::new("POST", path)
                    .with_headers(hdrs)
                    .with_body(body.into_bytes()),
            )
            .await
    }

    struct FailingRevokeStore(Arc<InMemoryOAuthStore>);

    impl OAuthTokenStore for FailingRevokeStore {
        fn store_session(
            &self,
            session: OAuthSession,
        ) -> BoxFuture<'_, Result<(), OAuthServerError>> {
            self.0.store_session(session)
        }
        fn lookup_by_access_token_digest(
            &self,
            digest: &[u8],
        ) -> BoxFuture<'_, Result<Option<OAuthSession>, OAuthServerError>> {
            self.0.lookup_by_access_token_digest(digest)
        }
        fn lookup_session(
            &self,
            session_id: &str,
        ) -> BoxFuture<'_, Result<Option<OAuthSession>, OAuthServerError>> {
            self.0.lookup_session(session_id)
        }
        fn lookup_by_token_digest(
            &self,
            _token_digest: &[u8],
        ) -> BoxFuture<'_, Result<Option<OAuthSession>, OAuthServerError>> {
            Box::pin(async { Err(OAuthServerError::Unavailable("db offline".into())) })
        }
        fn rotate_refresh_token<'a>(
            &'a self,
            params: RotateRefreshTokenParams<'a>,
        ) -> BoxFuture<'a, Result<OAuthRefreshRotationResult, OAuthServerError>> {
            self.0.rotate_refresh_token(params)
        }
        fn revoke_session(
            &self,
            session_id: &str,
            revoked_at_secs: i64,
        ) -> BoxFuture<'_, Result<bool, OAuthServerError>> {
            self.0.revoke_session(session_id, revoked_at_secs)
        }
        fn revoke_by_token_digest(
            &self,
            _token_digest: &[u8],
            _revoked_at_secs: i64,
        ) -> BoxFuture<'_, Result<bool, OAuthServerError>> {
            Box::pin(async { Err(OAuthServerError::Unavailable("db offline".into())) })
        }
    }

    let backing = Arc::new(InMemoryOAuthStore::new());
    let mut stores = OAuthServerStores::from_unified(backing.clone());
    stores.tokens = Arc::new(FailingRevokeStore(backing));
    let clock = Arc::new(TestClock::new(1_700_000_000));
    let conf_key =
        OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("conf-1".into())).unwrap();
    let conf_jwks = OAuthJsonWebKeySet::new(vec![conf_key.public_jwk(true).unwrap()]);
    let clients = Arc::new(StaticOAuthClientResolver::new().with_client(
        OAuthResolvedClientMetadata {
            kind: OAuthClientKind::Discoverable,
            metadata: OAuthClientMetadata {
                client_id: CONFIDENTIAL_CLIENT_ID.to_owned(),
                client_name: Some("Conf".into()),
                client_uri: None,
                logo_uri: None,
                tos_uri: None,
                policy_uri: None,
                application_type: OAuthApplicationType::Web,
                grant_types: vec!["authorization_code".into(), "refresh_token".into()],
                response_types: vec!["code".into()],
                redirect_uris: vec![CONFIDENTIAL_REDIRECT.to_owned()],
                scope: Some("atproto transition:generic".into()),
                token_endpoint_auth_method: OAuthTokenEndpointAuthMethod::PrivateKeyJwt,
                token_endpoint_auth_signing_alg: Some("ES256".into()),
                dpop_bound_access_tokens: true,
                jwks_uri: None,
                jwks: Some(conf_jwks.clone()),
            },
            key_set: Some(conf_jwks),
        },
    ));
    let cfg = OAuthAuthorizationServerConfiguration::new(TEST_ISSUER, vec![7_u8; 32]).unwrap();
    let server = OAuthAuthorizationServer::with_dependencies(
        cfg,
        stores,
        Arc::new(TestAccounts::with_alice_and_bob()),
        clients,
        None,
        Arc::new(DefaultOAuthHtmlRenderer),
        clock.clone(),
        Arc::new(TestRandom::new()),
    )
    .unwrap();

    // Token-store error on both access_token and refresh_token revocation propagates 503
    for hint in ["access_token", "refresh_token"] {
        let mut hdrs = OAuthHttpHeaders::default();
        hdrs.set("Content-Type", "application/x-www-form-urlencoded");
        let resp = server
            .handle(
                petrel_server::http::OAuthHttpRequest::new("POST", "/oauth/revoke")
                    .with_headers(hdrs)
                    .with_body(format!("token=tok-1&token_type_hint={hint}").into_bytes()),
            )
            .await;
        assert_eq!(resp.status, 503);
    }

    // cnf.jkt-bound CAB assertion on PAR rejects mismatched DPoP key & accepts matching key
    let dpop_good = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let dpop_other = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let bound_jkt = dpop_good.public_jwk(false).unwrap().thumbprint();
    let assertion = OAuthCompactJwt::sign(
        &serde_json::json!({
            "iss": CONFIDENTIAL_CLIENT_ID,
            "sub": CONFIDENTIAL_CLIENT_ID,
            "aud": TEST_ISSUER,
            "jti": "cab-bound-jti-1",
            "iat": clock.now_secs(),
            "exp": clock.now_secs() + 60,
            "cnf": { "jkt": bound_jkt }
        }),
        &conf_key,
        None,
        false,
    )
    .unwrap();
    let verifier = "cab-verifier-0123456789012345678901234567890123456789-._~";
    let challenge = OAuthPkce::s256_challenge(verifier);
    let par_url = format!("{TEST_ISSUER}/oauth/par");

    // Get DPoP nonce first -> 400 use_dpop_nonce; jti NOT burned
    let p_init = make_dpop_proof(
        &dpop_good,
        "POST",
        &par_url,
        None,
        None,
        clock.now_secs(),
        "c0",
    );
    let chal = post_form(
        &server,
        "/oauth/par",
        &[
            ("client_id", CONFIDENTIAL_CLIENT_ID),
            (
                "client_assertion_type",
                "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
            ),
            ("client_assertion", &assertion),
            ("response_type", "code"),
            ("code_challenge", &challenge),
            ("code_challenge_method", "S256"),
            ("redirect_uri", CONFIDENTIAL_REDIRECT),
            ("scope", "atproto transition:generic"),
        ],
        &[("DPoP", &p_init)],
    )
    .await;
    assert_eq!(chal.status, 400);
    let nonce = chal.headers.get("dpop-nonce").unwrap().to_owned();

    // Replay same bound CAB assertion with a different DPoP key -> 401 invalid_client
    let p_wrong = make_dpop_proof(
        &dpop_other,
        "POST",
        &par_url,
        Some(&nonce),
        None,
        clock.now_secs(),
        "c1",
    );
    let mismatch = post_form(
        &server,
        "/oauth/par",
        &[
            ("client_id", CONFIDENTIAL_CLIENT_ID),
            (
                "client_assertion_type",
                "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
            ),
            ("client_assertion", &assertion),
            ("response_type", "code"),
            ("code_challenge", &challenge),
            ("code_challenge_method", "S256"),
            ("redirect_uri", CONFIDENTIAL_REDIRECT),
            ("scope", "atproto transition:generic"),
        ],
        &[("DPoP", &p_wrong)],
    )
    .await;
    assert_eq!(mismatch.status, 401);

    // Same assertion still succeeds with matching DPoP proof key -> 201
    let p_good = make_dpop_proof(
        &dpop_good,
        "POST",
        &par_url,
        Some(&nonce),
        None,
        clock.now_secs(),
        "c2",
    );
    let ok = post_form(
        &server,
        "/oauth/par",
        &[
            ("client_id", CONFIDENTIAL_CLIENT_ID),
            (
                "client_assertion_type",
                "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
            ),
            ("client_assertion", &assertion),
            ("response_type", "code"),
            ("code_challenge", &challenge),
            ("code_challenge_method", "S256"),
            ("redirect_uri", CONFIDENTIAL_REDIRECT),
            ("scope", "atproto transition:generic"),
        ],
        &[("DPoP", &p_good)],
    )
    .await;
    assert_eq!(ok.status, 201);
}

#[tokio::test]
async fn revoke_falls_back_across_token_namespaces_when_token_type_hint_mismatches() {
    let harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;

    // 1. Refresh token presented with `token_type_hint=access_token` still revokes the session
    let mut c1 = TestClient::web(&harness);
    let t1 = c1
        .sign_in(
            common::ALICE_HANDLE,
            "alice-password",
            "atproto transition:generic",
        )
        .await;
    let rev1 = c1
        .send_post(
            "/oauth/revoke",
            &[
                ("token", &t1.refresh_token),
                ("token_type_hint", "access_token"),
            ],
        )
        .await;
    assert_eq!(rev1.status, 200);
    let after1 = c1
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &t1.refresh_token),
            ],
        )
        .await;
    assert_eq!(after1.status, 400);

    // 2. Access token presented with `token_type_hint=refresh_token` still revokes the session
    let mut c2 = TestClient::web(&harness);
    let t2 = c2
        .sign_in(
            common::BOB_HANDLE,
            "bob-password",
            "atproto transition:generic",
        )
        .await;
    let rev2 = c2
        .send_post(
            "/oauth/revoke",
            &[
                ("token", &t2.access_token),
                ("token_type_hint", "refresh_token"),
            ],
        )
        .await;
    assert_eq!(rev2.status, 200);
    let after2 = c2
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &t2.refresh_token),
            ],
        )
        .await;
    assert_eq!(after2.status, 400);
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn authorization_code_only_client_receives_no_refresh_token_and_cannot_refresh() {
    use common::WEB_REDIRECT;
    use petrel_server::clients::{
        OAuthApplicationType, OAuthClientKind, OAuthClientMetadata, OAuthResolvedClientMetadata,
        OAuthTokenEndpointAuthMethod,
    };

    let harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;
    let code_only_id = "https://code-only.example.com/client.json";
    let code_only_redirect = "https://code-only.example.com/callback";
    harness
        .clients
        .register(OAuthResolvedClientMetadata {
            kind: OAuthClientKind::Discoverable,
            metadata: OAuthClientMetadata {
                client_id: code_only_id.to_owned(),
                client_name: Some("Code Only".into()),
                client_uri: None,
                logo_uri: None,
                tos_uri: None,
                policy_uri: None,
                application_type: OAuthApplicationType::Web,
                grant_types: vec!["authorization_code".into()],
                response_types: vec!["code".into()],
                redirect_uris: vec![code_only_redirect.to_owned()],
                scope: Some("atproto transition:generic".into()),
                token_endpoint_auth_method: OAuthTokenEndpointAuthMethod::None,
                token_endpoint_auth_signing_alg: None,
                dpop_bound_access_tokens: true,
                jwks_uri: None,
                jwks: None,
            },
            key_set: None,
        })
        .await;

    let mut client = TestClient::web(&harness);
    client.client_id = code_only_id.to_owned();
    client.redirect_uri = code_only_redirect.to_owned();
    let request_uri = client.push_request("atproto transition:generic").await;
    let query = format!(
        "client_id={}&request_uri={}",
        OAuthForm::encode_component(code_only_id),
        OAuthForm::encode_component(&request_uri)
    );
    let page = harness.get("/oauth/authorize", Some(&query)).await;
    assert_eq!(page.status, 200);
    let cookie = page
        .headers
        .get("Set-Cookie")
        .unwrap()
        .split(';')
        .next()
        .unwrap()
        .to_owned();
    let html = page.text();
    let flow_id = common::extract_hidden_input(&html, "flow_id");
    let csrf_token = common::extract_hidden_input(&html, "csrf_token");
    let consent = harness
        .post_form(
            "/oauth/authorize",
            &[
                ("flow_id", &flow_id),
                ("csrf_token", &csrf_token),
                ("identifier", ALICE_HANDLE),
                ("password", "alice-password"),
                ("decision", "approve"),
            ],
            &[("Cookie", &cookie)],
        )
        .await;
    assert_eq!(consent.status, 303);
    let loc = consent.headers.get("Location").unwrap();
    let code = url::Url::parse(loc)
        .unwrap()
        .query_pairs()
        .find(|(k, _)| k == "code")
        .unwrap()
        .1
        .into_owned();

    let verifier = client.verifier.clone();
    let tok_resp = client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", &code),
                ("code_verifier", &verifier),
                ("redirect_uri", code_only_redirect),
            ],
        )
        .await;
    assert_eq!(tok_resp.status, 200);
    let tok_json: serde_json::Value = serde_json::from_slice(&tok_resp.body).unwrap();
    assert!(
        tok_json.get("refresh_token").is_none(),
        "client omitting refresh_token grant must not receive refresh_token"
    );

    // Even a client that previously obtained a refresh token cannot use it once metadata removes refresh_token
    let mut c2 = TestClient::web(&harness);
    let t2 = c2
        .sign_in(
            common::BOB_HANDLE,
            "bob-password",
            "atproto transition:generic",
        )
        .await;
    harness
        .clients
        .register(OAuthResolvedClientMetadata {
            kind: OAuthClientKind::Discoverable,
            metadata: OAuthClientMetadata {
                client_id: WEB_CLIENT_ID.to_owned(),
                client_name: Some("Web Example".into()),
                client_uri: None,
                logo_uri: None,
                tos_uri: None,
                policy_uri: None,
                application_type: OAuthApplicationType::Web,
                grant_types: vec!["authorization_code".into()],
                response_types: vec!["code".into()],
                redirect_uris: vec![WEB_REDIRECT.to_owned()],
                scope: Some("atproto transition:generic".into()),
                token_endpoint_auth_method: OAuthTokenEndpointAuthMethod::None,
                token_endpoint_auth_signing_alg: None,
                dpop_bound_access_tokens: true,
                jwks_uri: None,
                jwks: None,
            },
            key_set: None,
        })
        .await;
    let denied = c2
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &t2.refresh_token),
            ],
        )
        .await;
    assert_eq!(denied.status, 400);
    assert!(denied.text().contains("unauthorized_client"));
}

#[tokio::test]
async fn replaying_ancestor_refresh_token_after_multiple_rotations_revokes_session() {
    let harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;
    let mut client = TestClient::web(&harness);
    let t0 = client
        .sign_in(
            common::ALICE_HANDLE,
            "alice-password",
            "atproto transition:generic",
        )
        .await;

    // R0 -> R1
    harness.clock.advance(5);
    let r1 = client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &t0.refresh_token),
            ],
        )
        .await;
    assert_eq!(r1.status, 200);
    let t1: common::TokenResponse = serde_json::from_slice(&r1.body).unwrap();

    // R1 -> R2
    harness.clock.advance(5);
    let r2 = client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &t1.refresh_token),
            ],
        )
        .await;
    assert_eq!(r2.status, 200);
    let t2: common::TokenResponse = serde_json::from_slice(&r2.body).unwrap();

    // Replaying ancestor R0 must detect reuse and revoke the entire session (incl. R2)
    let replay_r0 = client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &t0.refresh_token),
            ],
        )
        .await;
    assert_eq!(replay_r0.status, 400);
    assert!(replay_r0.text().contains("reuse"));

    let after_revoke = client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &t2.refresh_token),
            ],
        )
        .await;
    assert_eq!(after_revoke.status, 400);

    let sessions = harness.store.snapshot_sessions().await;
    assert_eq!(sessions.len(), 1);
    assert!(sessions[0].revoked_at_secs.is_some());

    // Purge after expiry also removes the retained R0 spent digest
    harness.clock.advance(100 * 24 * 60 * 60);
    assert!(
        harness
            .store
            .purge_expired(harness.clock.now_secs())
            .await
            .unwrap()
            >= 1
    );
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn path_bearing_issuer_sets_matching_csrf_cookie_path_and_completes_authorize_flow() {
    // Root issuer retains Path=/oauth/authorize
    let root_harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;
    let mut root_client = TestClient::web(&root_harness);
    let root_request_uri = root_client.push_request("atproto transition:generic").await;
    let root_query = format!(
        "client_id={}&request_uri={}",
        OAuthForm::encode_component(&root_client.client_id),
        OAuthForm::encode_component(&root_request_uri)
    );
    let root_page = root_harness
        .get("/oauth/authorize", Some(&root_query))
        .await;
    assert_eq!(root_page.status, 200);
    let root_set_cookie = root_page
        .headers
        .get("Set-Cookie")
        .expect("root Set-Cookie");
    assert!(
        root_set_cookie.starts_with("__Host-petrel_oauth_csrf="),
        "expected HTTPS __Host- prefix, got {root_set_cookie}"
    );
    assert!(
        root_set_cookie.contains("Path=/; Secure"),
        "expected root __Host- cookie with Path=/; Secure, got {root_set_cookie}"
    );

    // Path-bearing HTTPS issuer derives Path=/auth/oauth/authorize and handles direct + nested routes
    let harness = TestServer::new_with_issuer(
        "https://auth.example.com/auth/",
        OAuthAccessTokenFormat::Opaque,
    )
    .await;
    let mut client = TestClient::web(&harness);
    let challenge = client.challenge();
    let redirect = client.redirect_uri.clone();
    let state = client.state.clone();
    let par_resp = client
        .send_post(
            "/auth/oauth/par",
            &[
                ("response_type", "code"),
                ("code_challenge", &challenge),
                ("code_challenge_method", "S256"),
                ("state", &state),
                ("redirect_uri", &redirect),
                ("scope", "atproto transition:generic"),
            ],
        )
        .await;
    assert_eq!(par_resp.status, 201, "PAR failed: {}", par_resp.text());
    let par_parsed: common::ParResponse = serde_json::from_slice(&par_resp.body).expect("PAR json");

    let query = format!(
        "client_id={}&request_uri={}",
        OAuthForm::encode_component(&client.client_id),
        OAuthForm::encode_component(&par_parsed.request_uri)
    );
    let page = harness.get("/auth/oauth/authorize", Some(&query)).await;
    assert_eq!(page.status, 200, "authorize GET failed: {}", page.text());
    let html = page.text();
    assert!(
        html.contains("action=\"https://auth.example.com/auth/oauth/authorize\""),
        "expected form action with /auth prefix, got html:\n{html}"
    );
    let set_cookie = page.headers.get("Set-Cookie").expect("Set-Cookie");
    assert!(
        set_cookie.starts_with("__Host-petrel_oauth_csrf="),
        "expected HTTPS __Host- prefix, got {set_cookie}"
    );
    assert!(
        set_cookie.contains("Path=/; Secure"),
        "expected __Host- cookie with Path=/; Secure, got {set_cookie}"
    );
    let csp = page
        .headers
        .get("Content-Security-Policy")
        .expect("CSP header");
    assert!(
        csp.contains("form-action 'self' https://web.example.com"),
        "expected redirect origin in CSP form-action, got {csp}"
    );

    let cookie = set_cookie
        .split(';')
        .next()
        .expect("csrf cookie pair")
        .to_owned();
    let flow_id = common::extract_hidden_input(&html, "flow_id");
    let csrf_token = common::extract_hidden_input(&html, "csrf_token");

    let consent_resp = harness
        .post_form(
            "/auth/oauth/authorize",
            &[
                ("flow_id", &flow_id),
                ("csrf_token", &csrf_token),
                ("identifier", ALICE_HANDLE),
                ("password", "alice-password"),
                ("decision", "approve"),
            ],
            &[("Cookie", &cookie)],
        )
        .await;
    assert_eq!(
        consent_resp.status,
        303,
        "authorize POST failed: {}",
        consent_resp.text()
    );
    let loc = consent_resp.headers.get("Location").expect("Location");
    let code = url::Url::parse(loc)
        .expect("redirect url")
        .query_pairs()
        .find(|(k, _)| k == "code")
        .map(|(_, v)| v.into_owned())
        .expect("code param");

    let verifier = client.verifier.clone();
    let redirect = client.redirect_uri.clone();
    let tok_resp = client
        .send_post(
            "/auth/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", &code),
                ("code_verifier", &verifier),
                ("redirect_uri", &redirect),
            ],
        )
        .await;
    assert_eq!(
        tok_resp.status,
        200,
        "token exchange failed: {}",
        tok_resp.text()
    );
    let tok: common::TokenResponse = serde_json::from_slice(&tok_resp.body).expect("token json");
    assert_eq!(tok.sub, ALICE_DID);

    // RFC 8414 suffix well-known route also resolves cleanly
    let wk = harness
        .get("/.well-known/oauth-authorization-server/auth", None)
        .await;
    assert_eq!(wk.status, 200);
    assert!(
        wk.text()
            .contains("\"issuer\":\"https://auth.example.com/auth\"")
    );

    // Axum Router::nest("/auth", oauth_router(...)) also emits matching cookie path and submits
    let request_uri_2 = client.push_request("atproto transition:generic").await;
    let nested_query = format!(
        "client_id={}&request_uri={}",
        OAuthForm::encode_component(&client.client_id),
        OAuthForm::encode_component(&request_uri_2)
    );
    let shared_server = Arc::new(harness.server);
    let mut app = Router::new().nest("/auth", oauth_router(shared_server));
    let nested_get = app
        .call(
            Request::builder()
                .method("GET")
                .uri(format!("/auth/oauth/authorize?{nested_query}"))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(nested_get.status(), StatusCode::OK);
    let nested_cookie_hdr = nested_get
        .headers()
        .get("set-cookie")
        .expect("nested set-cookie")
        .to_str()
        .unwrap()
        .to_owned();
    assert!(
        nested_cookie_hdr.starts_with("__Host-petrel_oauth_csrf=")
            && nested_cookie_hdr.contains("Path=/; Secure"),
        "expected nested __Host- cookie with Path=/; Secure, got {nested_cookie_hdr}"
    );

    let nested_body = axum::body::to_bytes(nested_get.into_body(), 1024 * 1024)
        .await
        .unwrap();
    let nested_html = String::from_utf8(nested_body.to_vec()).unwrap();
    let nested_flow_id = common::extract_hidden_input(&nested_html, "flow_id");
    let nested_csrf = common::extract_hidden_input(&nested_html, "csrf_token");
    let nested_cookie = nested_cookie_hdr.split(';').next().unwrap().to_owned();
    let form_body = format!(
        "flow_id={}&csrf_token={}&identifier={}&password={}&decision=approve",
        OAuthForm::encode_component(&nested_flow_id),
        OAuthForm::encode_component(&nested_csrf),
        OAuthForm::encode_component(ALICE_HANDLE),
        OAuthForm::encode_component("alice-password")
    );
    let nested_post = app
        .call(
            Request::builder()
                .method("POST")
                .uri("/auth/oauth/authorize")
                .header("Content-Type", "application/x-www-form-urlencoded")
                .header("Cookie", nested_cookie)
                .body(Body::from(form_body))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(nested_post.status(), StatusCode::SEE_OTHER);

    // Non-HTTPS path-bearing issuer omits ; Secure
    let http_harness =
        TestServer::new_with_issuer("http://127.0.0.1:8080/auth", OAuthAccessTokenFormat::Opaque)
            .await;
    let mut http_client = TestClient::web(&http_harness);
    let http_uri = http_client.push_request("atproto transition:generic").await;
    let http_query = format!(
        "client_id={}&request_uri={}",
        OAuthForm::encode_component(&http_client.client_id),
        OAuthForm::encode_component(&http_uri)
    );
    let http_page = http_harness
        .get("/auth/oauth/authorize", Some(&http_query))
        .await;
    assert_eq!(http_page.status, 200);
    let http_cookie = http_page
        .headers
        .get("Set-Cookie")
        .expect("http Set-Cookie");
    assert!(
        http_cookie.ends_with("Path=/auth/oauth/authorize"),
        "expected non-HTTPS cookie ending with Path=/auth/oauth/authorize, got {http_cookie}"
    );
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn revoke_enforces_client_ownership_and_confidential_authentication() {
    let harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;
    let mut conf = TestClient::confidential(&harness);
    let c_tok = conf
        .sign_in(ALICE_HANDLE, "alice-password", "atproto transition:generic")
        .await;

    let mut web = TestClient::web(&harness);
    let w_tok = web
        .sign_in(ALICE_HANDLE, "alice-password", "atproto transition:generic")
        .await;

    // 1. Omitted client_id cannot revoke a confidential client's token
    let omitted_client = harness
        .post_form("/oauth/revoke", &[("token", &c_tok.refresh_token)], &[])
        .await;
    assert_eq!(omitted_client.status, 401);
    assert!(omitted_client.text().contains("invalid_client"));

    // 2. Unrelated public client_id cannot bypass confidential auth or revoke confidential session
    let wrong_public_for_conf = harness
        .post_form(
            "/oauth/revoke",
            &[
                ("token", &c_tok.refresh_token),
                ("client_id", WEB_CLIENT_ID),
            ],
            &[],
        )
        .await;
    assert_eq!(wrong_public_for_conf.status, 200);

    // 3. Unrelated public client_id cannot revoke another public client's session
    let wrong_public_for_web = harness
        .post_form(
            "/oauth/revoke",
            &[
                ("token", &w_tok.access_token),
                ("client_id", common::LOOPBACK_CLIENT_ID),
            ],
            &[],
        )
        .await;
    assert_eq!(wrong_public_for_web.status, 200);

    // 4. Confidential client with valid assertion + wrong DPoP key cannot revoke its session
    let wrong_dpop_key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let conf_assertion = conf.make_client_assertion();
    let wrong_dpop_proof = make_dpop_proof(
        &wrong_dpop_key,
        "POST",
        &format!("{TEST_ISSUER}/oauth/revoke"),
        conf.nonce.as_deref(),
        None,
        harness.clock.now_secs(),
        "wrong-rev-dpop-1",
    );
    let conf_wrong_dpop = harness
        .post_form(
            "/oauth/revoke",
            &[
                ("token", &c_tok.access_token),
                ("client_id", CONFIDENTIAL_CLIENT_ID),
                (
                    "client_assertion_type",
                    "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
                ),
                ("client_assertion", &conf_assertion),
            ],
            &[("DPoP", &wrong_dpop_proof)],
        )
        .await;
    assert_eq!(conf_wrong_dpop.status, 401);

    // Both sessions remain active and can still refresh
    let c_refreshed = conf
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &c_tok.refresh_token),
            ],
        )
        .await;
    assert_eq!(
        c_refreshed.status, 200,
        "confidential session should still be active"
    );
    let c_tok2: common::TokenResponse =
        serde_json::from_slice(&c_refreshed.body).expect("refresh json");

    let w_refreshed = web
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &w_tok.refresh_token),
            ],
        )
        .await;
    assert_eq!(
        w_refreshed.status, 200,
        "public session should still be active"
    );
    let w_tok2: common::TokenResponse =
        serde_json::from_slice(&w_refreshed.body).expect("refresh json");

    // 5. Public client session can still be revoked without client_id (RFC 7009 / ATProto parity)
    let web_revoked = harness
        .post_form("/oauth/revoke", &[("token", &w_tok2.access_token)], &[])
        .await;
    assert_eq!(web_revoked.status, 200);
    let web_after = web
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &w_tok2.refresh_token),
            ],
        )
        .await;
    assert_eq!(web_after.status, 400);

    // 6. Confidential client revokes its own session when assertion + DPoP match
    let conf_revoked = conf
        .send_post("/oauth/revoke", &[("token", &c_tok2.access_token)])
        .await;
    assert_eq!(conf_revoked.status, 200);
    let conf_after = conf
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &c_tok2.refresh_token),
            ],
        )
        .await;
    assert_eq!(conf_after.status, 400);
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn spent_refresh_token_from_wrong_client_or_dpop_key_does_not_revoke_legitimate_session() {
    let harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;
    let mut web = TestClient::web(&harness);
    let t0 = web
        .sign_in(ALICE_HANDLE, "alice-password", "atproto transition:generic")
        .await;

    // Rotate t0 -> t1 so t0.refresh_token becomes a spent ancestor
    let r1 = web
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &t0.refresh_token),
            ],
        )
        .await;
    assert_eq!(r1.status, 200);
    let t1: common::TokenResponse = serde_json::from_slice(&r1.body).expect("t1");

    // Direct store-level assertions: wrong client_id or wrong dpop_jkt on spent digest
    // returns ClientMismatch and leaves session unrevoked
    let keyed = petrel_server::support::OAuthKeyedDigest::new(vec![7_u8; 32]).unwrap();
    let spent_digest = keyed.digest_str(&t0.refresh_token, DigestPurpose::RefreshToken);
    let web_jkt = web.dpop_key.public_jwk(false).unwrap().thumbprint();
    let wrong_client_res = harness
        .store
        .rotate_refresh_token(petrel_server::store::RotateRefreshTokenParams {
            presented_refresh_digest: &spent_digest,
            client_id: common::LOOPBACK_CLIENT_ID,
            dpop_jkt: &web_jkt,
            next_access_digest: vec![1; 32],
            next_refresh_digest: vec![2; 32],
            next_access_expires_at_secs: harness.clock.now_secs() + 300,
            next_session_expires_at_secs: harness.clock.now_secs() + 3600,
            now_secs: harness.clock.now_secs(),
            access_token_minter: None,
        })
        .await
        .unwrap();
    assert!(matches!(
        wrong_client_res,
        petrel_server::store::OAuthRefreshRotationResult::ClientMismatch
    ));

    let wrong_jkt_res = harness
        .store
        .rotate_refresh_token(petrel_server::store::RotateRefreshTokenParams {
            presented_refresh_digest: &spent_digest,
            client_id: WEB_CLIENT_ID,
            dpop_jkt: "other-thumbprint",
            next_access_digest: vec![3; 32],
            next_refresh_digest: vec![4; 32],
            next_access_expires_at_secs: harness.clock.now_secs() + 300,
            next_session_expires_at_secs: harness.clock.now_secs() + 3600,
            now_secs: harness.clock.now_secs(),
            access_token_minter: None,
        })
        .await
        .unwrap();
    assert!(matches!(
        wrong_jkt_res,
        petrel_server::store::OAuthRefreshRotationResult::ClientMismatch
    ));

    // HTTP-level check: another public client presenting the spent refresh token is rejected
    // without revoking the legitimate session
    let mut attacker_client = TestClient::web(&harness);
    attacker_client.client_id = common::LOOPBACK_CLIENT_ID.to_owned();
    let wrong_client_http = attacker_client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &t0.refresh_token),
            ],
        )
        .await;
    assert_eq!(wrong_client_http.status, 400);

    // Same client_id with a different DPoP key presenting the spent refresh token is rejected
    // without revoking the legitimate session
    let mut attacker_dpop = TestClient::web(&harness);
    let wrong_dpop_http = attacker_dpop
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &t0.refresh_token),
            ],
        )
        .await;
    assert_eq!(wrong_dpop_http.status, 400);

    // Legitimate client session is STILL active and t1 rotates cleanly to t2
    let sessions = harness.store.snapshot_sessions().await;
    assert_eq!(sessions.len(), 1);
    assert!(sessions[0].revoked_at_secs.is_none());
    let r2 = web
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &t1.refresh_token),
            ],
        )
        .await;
    assert_eq!(r2.status, 200);
    let t2: common::TokenResponse = serde_json::from_slice(&r2.body).expect("t2");

    // Replay by the legitimate client (matching client_id + matching DPoP key) DOES revoke
    let genuine_replay = web
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &t0.refresh_token),
            ],
        )
        .await;
    assert_eq!(genuine_replay.status, 400);
    assert!(genuine_replay.text().contains("reuse"));

    let after_revoke = web
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &t2.refresh_token),
            ],
        )
        .await;
    assert_eq!(after_revoke.status, 400);
    let sessions_after = harness.store.snapshot_sessions().await;
    assert!(sessions_after[0].revoked_at_secs.is_some());
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn opportunistic_purging_skips_static_routes_and_throttles_per_interval() {
    use std::sync::atomic::{AtomicUsize, Ordering};

    use petrel::rt::BoxFuture;
    use petrel_server::clients::StaticOAuthClientResolver;
    use petrel_server::error::OAuthServerError;
    use petrel_server::http::OAuthHttpRequest;
    use petrel_server::oauth::OAuthAuthorizationServer;
    use petrel_server::oauth::interface::DefaultOAuthHtmlRenderer;
    use petrel_server::store::{
        OAuthPushedAuthorizationRequest, OAuthRequestStore, OAuthServerStores,
    };

    struct CountingPurgeStore {
        inner: Arc<InMemoryOAuthStore>,
        calls: AtomicUsize,
    }

    impl OAuthStorePurging for CountingPurgeStore {
        fn purge_expired(&self, now_secs: i64) -> BoxFuture<'_, Result<usize, OAuthServerError>> {
            self.calls.fetch_add(1, Ordering::SeqCst);
            self.inner.purge_expired(now_secs)
        }
    }

    let store = Arc::new(InMemoryOAuthStore::new());
    let purger = Arc::new(CountingPurgeStore {
        inner: store.clone(),
        calls: AtomicUsize::new(0),
    });
    let mut stores = OAuthServerStores::from_unified(store.clone());
    stores.purging = Some(purger.clone());

    let clock = Arc::new(common::TestClock::new(1_700_000_000));
    let mut cfg = OAuthAuthorizationServerConfiguration::new(TEST_ISSUER, vec![7_u8; 32]).unwrap();
    cfg.purge_interval_secs = Some(60);

    let server = Arc::new(
        OAuthAuthorizationServer::with_dependencies(
            cfg,
            stores,
            Arc::new(common::TestAccounts::with_alice_and_bob()),
            Arc::new(StaticOAuthClientResolver::new()),
            None,
            Arc::new(DefaultOAuthHtmlRenderer),
            clock.clone(),
            Arc::new(common::TestRandom::new()),
        )
        .unwrap(),
    );

    // 1. OPTIONS preflights, discovery metadata, JWKS, and 404/405 never call purge_expired
    for (method, path) in [
        ("OPTIONS", "/oauth/token"),
        ("GET", "/.well-known/oauth-authorization-server"),
        ("GET", "/.well-known/oauth-protected-resource"),
        ("GET", "/oauth/jwks"),
        ("GET", "/unknown-route"),
        ("DELETE", "/oauth/token"),
    ] {
        let _ = server.handle(OAuthHttpRequest::new(method, path)).await;
    }
    assert_eq!(purger.calls.load(Ordering::SeqCst), 0);

    // 2. First stateful request runs one opportunistic purge
    let _ = server
        .handle(OAuthHttpRequest::new("POST", "/oauth/par"))
        .await;
    assert_eq!(purger.calls.load(Ordering::SeqCst), 1);

    // 3. Back-to-back stateful requests within 59s stay throttled (0 additional scans)
    clock.advance(59);
    for (method, path) in [
        ("POST", "/oauth/par"),
        ("GET", "/oauth/authorize"),
        ("POST", "/oauth/authorize"),
        ("POST", "/oauth/token"),
        ("POST", "/oauth/revoke"),
    ] {
        let _ = server.handle(OAuthHttpRequest::new(method, path)).await;
    }
    assert_eq!(purger.calls.load(Ordering::SeqCst), 1);

    // 4. Advancing across the 60s interval triggers exactly one singleflight purge even concurrently
    clock.advance(1);
    let _ = tokio::join!(
        server.handle(OAuthHttpRequest::new("POST", "/oauth/par")),
        server.handle(OAuthHttpRequest::new("POST", "/oauth/token")),
        server.handle(OAuthHttpRequest::new("POST", "/oauth/revoke")),
        server.handle(OAuthHttpRequest::new("GET", "/oauth/authorize")),
    );
    assert_eq!(purger.calls.load(Ordering::SeqCst), 2);

    // 5. Explicit server.purge_expired() always runs and resets the throttle watermark
    assert_eq!(server.purge_expired().await.unwrap(), 0);
    assert_eq!(purger.calls.load(Ordering::SeqCst), 3);
    clock.advance(30);
    let _ = server
        .handle(OAuthHttpRequest::new("POST", "/oauth/par"))
        .await;
    assert_eq!(purger.calls.load(Ordering::SeqCst), 3);

    // 6. Clock rollback triggers one purge and re-anchors throttling instead of wedging
    clock.set(1_699_999_000);
    let _ = server
        .handle(OAuthHttpRequest::new("POST", "/oauth/par"))
        .await;
    assert_eq!(purger.calls.load(Ordering::SeqCst), 4);
    clock.advance(30);
    let _ = server
        .handle(OAuthHttpRequest::new("POST", "/oauth/par"))
        .await;
    assert_eq!(purger.calls.load(Ordering::SeqCst), 4);

    // 7. Reclaiming expired entries works both via interval-elapsed request and explicit purge
    let created_at = clock.now_secs();
    store
        .store_pushed_request(OAuthPushedAuthorizationRequest {
            request_uri_digest: vec![9; 32],
            client_id: WEB_CLIENT_ID.into(),
            redirect_uri: common::WEB_REDIRECT.into(),
            scope: "atproto".into(),
            state: None,
            code_challenge: "c".into(),
            dpop_jkt: Some("j".into()),
            login_hint: None,
            response_mode: petrel_server::store::OAuthResponseMode::Query,
            created_at_secs: created_at,
            expires_at_secs: created_at + 10,
        })
        .await
        .unwrap();
    clock.advance(30); // total +60s since rollback watermark -> elapsed, PAR expires at +10
    let _ = server
        .handle(OAuthHttpRequest::new("POST", "/oauth/par"))
        .await;
    assert_eq!(purger.calls.load(Ordering::SeqCst), 5);
    assert!(
        store
            .consume_pushed_request(&[9; 32], created_at)
            .await
            .unwrap()
            .is_none(),
        "expired PAR should have been physically evicted by throttled purge"
    );

    // Negative purge_interval_secs is rejected by validation
    let mut bad_cfg =
        OAuthAuthorizationServerConfiguration::new(TEST_ISSUER, vec![7_u8; 32]).unwrap();
    bad_cfg.purge_interval_secs = Some(-1);
    assert!(bad_cfg.validate().is_err());
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn authorization_code_replay_revokes_session_and_par_validates_dpop_before_resolve() {
    use std::sync::atomic::{AtomicUsize, Ordering};

    use petrel::rt::BoxFuture;
    use petrel_server::clients::{
        OAuthClientResolving, OAuthResolvedClientMetadata, StaticOAuthClientResolver,
    };
    use petrel_server::error::OAuthServerError;
    use petrel_server::http::OAuthHttpRequest;
    use petrel_server::oauth::OAuthAuthorizationServer;
    use petrel_server::oauth::interface::DefaultOAuthHtmlRenderer;
    use petrel_server::store::OAuthServerStores;

    struct CountingClientResolver {
        inner: Arc<StaticOAuthClientResolver>,
        calls: AtomicUsize,
    }
    impl OAuthClientResolving for CountingClientResolver {
        fn resolve(
            &self,
            client_id: &str,
        ) -> BoxFuture<'_, Result<OAuthResolvedClientMetadata, OAuthServerError>> {
            self.calls.fetch_add(1, Ordering::SeqCst);
            self.inner.resolve(client_id)
        }
    }

    // 1. Authorization code replay revokes the previously issued session & tokens
    let harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;
    let mut client = TestClient::web(&harness);
    let request_uri = client.push_request("atproto transition:generic").await;
    let query = format!(
        "client_id={}&request_uri={}",
        OAuthForm::encode_component(&client.client_id),
        OAuthForm::encode_component(&request_uri)
    );
    let page = harness.get("/oauth/authorize", Some(&query)).await;
    assert_eq!(page.status, 200);
    let html = page.text();
    let cookie = page
        .headers
        .get("Set-Cookie")
        .unwrap()
        .split(';')
        .next()
        .unwrap()
        .to_owned();
    let flow_id = common::extract_hidden_input(&html, "flow_id");
    let csrf_token = common::extract_hidden_input(&html, "csrf_token");
    let consent = harness
        .post_form(
            "/oauth/authorize",
            &[
                ("flow_id", &flow_id),
                ("csrf_token", &csrf_token),
                ("identifier", ALICE_HANDLE),
                ("password", "alice-password"),
                ("decision", "approve"),
            ],
            &[("Cookie", &cookie)],
        )
        .await;
    assert_eq!(consent.status, 303);
    let loc = consent.headers.get("Location").unwrap();
    let code = url::Url::parse(loc)
        .unwrap()
        .query_pairs()
        .find(|(k, _)| k == "code")
        .unwrap()
        .1
        .into_owned();

    let verifier = client.verifier.clone();
    let redirect = client.redirect_uri.clone();
    let first_tok = client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", &code),
                ("code_verifier", &verifier),
                ("redirect_uri", &redirect),
            ],
        )
        .await;
    assert_eq!(first_tok.status, 200);
    let tok: common::TokenResponse = serde_json::from_slice(&first_tok.body).unwrap();

    // Replaying the same authorization code must fail AND revoke the session
    let replay = client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", &code),
                ("code_verifier", &verifier),
                ("redirect_uri", &redirect),
            ],
        )
        .await;
    assert_eq!(replay.status, 400);
    assert!(replay.text().contains("revoked"));
    let sessions = harness.store.snapshot_sessions().await;
    assert_eq!(sessions.len(), 1);
    assert!(sessions[0].revoked_at_secs.is_some());

    // Subsequent refresh fails because session was revoked
    let after = client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &tok.refresh_token),
            ],
        )
        .await;
    assert_eq!(after.status, 400);

    // 2. PAR & Token validate DPoP before calling clients.resolve (no SSRF amplification)
    let counting = Arc::new(CountingClientResolver {
        inner: harness.clients.clone(),
        calls: AtomicUsize::new(0),
    });
    let cfg = OAuthAuthorizationServerConfiguration::new(TEST_ISSUER, vec![7_u8; 32]).unwrap();
    let par_server = OAuthAuthorizationServer::with_dependencies(
        cfg,
        OAuthServerStores::from_unified(Arc::new(InMemoryOAuthStore::new())),
        Arc::new(common::TestAccounts::with_alice_and_bob()),
        counting.clone(),
        None,
        Arc::new(DefaultOAuthHtmlRenderer),
        harness.clock.clone(),
        Arc::new(common::TestRandom::new()),
    )
    .unwrap();

    let mut form_hdrs = OAuthHttpHeaders::default();
    form_hdrs.set("Content-Type", "application/x-www-form-urlencoded");
    let bad_par = par_server
        .handle(
            OAuthHttpRequest::new("POST", "/oauth/par")
                .with_headers(form_hdrs.clone())
                .with_body(
                    b"client_id=https%3A%2F%2Fattacker.invalid%2Fclient.json&response_type=code"
                        .to_vec(),
                ),
        )
        .await;
    assert_eq!(bad_par.status, 400);
    assert_eq!(counting.calls.load(Ordering::SeqCst), 0);

    let bad_token = par_server
        .handle(
            OAuthHttpRequest::new("POST", "/oauth/token")
                .with_headers(form_hdrs)
                .with_body(b"grant_type=authorization_code&client_id=https%3A%2F%2Fattacker.invalid%2Fclient.json".to_vec()),
        )
        .await;
    assert_eq!(bad_token.status, 400);
    assert_eq!(counting.calls.load(Ordering::SeqCst), 0);
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn public_vs_confidential_refresh_ttls_and_absolute_session_ceiling() {
    let harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;
    let mut web = TestClient::web(&harness);
    let mut tok = web
        .sign_in(ALICE_HANDLE, "alice-password", "atproto transition:generic")
        .await;

    let mut conf = TestClient::confidential(&harness);
    let c_tok = conf
        .sign_in(ALICE_HANDLE, "alice-password", "atproto transition:generic")
        .await;

    // Public client: refreshing at day 5 and day 10 keeps sliding access, but cannot exceed 14-day ceiling
    harness.clock.advance(5 * 24 * 60 * 60);
    let r1 = web
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &tok.refresh_token),
            ],
        )
        .await;
    assert_eq!(r1.status, 200);
    tok = serde_json::from_slice(&r1.body).unwrap();

    harness.clock.advance(5 * 24 * 60 * 60); // T + 10d
    let r2 = web
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &tok.refresh_token),
            ],
        )
        .await;
    assert_eq!(r2.status, 200);
    tok = serde_json::from_slice(&r2.body).unwrap();

    // At T + 14d (even though only 4d since r2), absolute 14d public session ceiling rejects refresh
    harness.clock.advance(4 * 24 * 60 * 60);
    let expired_pub = web
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &tok.refresh_token),
            ],
        )
        .await;
    assert_eq!(expired_pub.status, 400);

    // Confidential client at T + 14d..T + 20d is still valid (90d refresh TTL, 2y hard ceiling)
    harness.clock.advance(6 * 24 * 60 * 60);
    let conf_ok = conf
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &c_tok.refresh_token),
            ],
        )
        .await;
    assert_eq!(conf_ok.status, 200);

    // Invalid TTLs outside profile bounds fail config validation
    let day = 24 * 60 * 60;
    let mut bad_pub =
        OAuthAuthorizationServerConfiguration::new(TEST_ISSUER, vec![7_u8; 32]).unwrap();
    bad_pub.public_client_refresh_ttl_secs = 15 * day;
    assert!(bad_pub.validate().is_err());

    let mut bad_pub_ceil =
        OAuthAuthorizationServerConfiguration::new(TEST_ISSUER, vec![7_u8; 32]).unwrap();
    bad_pub_ceil.public_client_session_lifetime_secs = 15 * day;
    assert!(bad_pub_ceil.validate().is_err());
}

#[tokio::test]
async fn error_responses_sanitize_internal_storage_errors() {
    use petrel::rt::BoxFuture;
    use petrel_server::error::OAuthServerError;
    use petrel_server::http::OAuthHttpRequest;
    use petrel_server::oauth::OAuthAuthorizationServer;
    use petrel_server::oauth::interface::DefaultOAuthHtmlRenderer;
    use petrel_server::store::{OAuthRequestStore, OAuthServerStores};

    struct SecretLeakingRequestStore;
    impl OAuthRequestStore for SecretLeakingRequestStore {
        fn store_pushed_request(
            &self,
            _record: petrel_server::store::OAuthPushedAuthorizationRequest,
        ) -> BoxFuture<'_, Result<(), OAuthServerError>> {
            Box::pin(async {
                Err(OAuthServerError::Unavailable(
                    "postgres://admin:supersecret@db.internal:5432/oauth".into(),
                ))
            })
        }
        fn consume_pushed_request(
            &self,
            _request_uri_digest: &[u8],
            _now_secs: i64,
        ) -> BoxFuture<
            '_,
            Result<Option<petrel_server::store::OAuthPushedAuthorizationRequest>, OAuthServerError>,
        > {
            Box::pin(async {
                Err(OAuthServerError::Unavailable(
                    "sqlite error at /var/db/secret.db".into(),
                ))
            })
        }
    }

    let harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;
    let mut stores = OAuthServerStores::from_unified(harness.store.clone());
    stores.requests = Arc::new(SecretLeakingRequestStore);
    let server = OAuthAuthorizationServer::with_dependencies(
        OAuthAuthorizationServerConfiguration::new(TEST_ISSUER, vec![7_u8; 32]).unwrap(),
        stores,
        Arc::new(common::TestAccounts::with_alice_and_bob()),
        harness.clients.clone(),
        None,
        Arc::new(DefaultOAuthHtmlRenderer),
        harness.clock.clone(),
        Arc::new(common::TestRandom::new()),
    )
    .unwrap();

    let resp = server
        .handle(
            OAuthHttpRequest::new("GET", "/oauth/authorize").with_query(format!(
                "client_id={}&request_uri=urn:ietf:params:oauth:request_uri:req_1",
                OAuthForm::encode_component(WEB_CLIENT_ID)
            )),
        )
        .await;
    assert_eq!(resp.status, 503);
    let text = resp.text();
    assert!(!text.contains("/var/db/secret.db"));
    assert!(text.contains("authorization service temporarily unavailable"));
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn mismatched_code_exchange_leaves_unused_code_and_spent_session_intact() {
    let harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;
    let mut client = TestClient::web(&harness);
    let request_uri = client.push_request("atproto transition:generic").await;
    let query = format!(
        "client_id={}&request_uri={}",
        OAuthForm::encode_component(&client.client_id),
        OAuthForm::encode_component(&request_uri)
    );
    let page = harness.get("/oauth/authorize", Some(&query)).await;
    assert_eq!(page.status, 200);
    let html = page.text();
    let cookie = page
        .headers
        .get("Set-Cookie")
        .unwrap()
        .split(';')
        .next()
        .unwrap()
        .to_owned();
    let flow_id = common::extract_hidden_input(&html, "flow_id");
    let csrf_token = common::extract_hidden_input(&html, "csrf_token");
    let consent = harness
        .post_form(
            "/oauth/authorize",
            &[
                ("flow_id", &flow_id),
                ("csrf_token", &csrf_token),
                ("identifier", ALICE_HANDLE),
                ("password", "alice-password"),
                ("decision", "approve"),
            ],
            &[("Cookie", &cookie)],
        )
        .await;
    assert_eq!(consent.status, 303);
    let loc = consent.headers.get("Location").unwrap();
    let code = url::Url::parse(loc)
        .unwrap()
        .query_pairs()
        .find(|(k, _)| k == "code")
        .unwrap()
        .1
        .into_owned();

    let verifier = client.verifier.clone();
    let redirect = client.redirect_uri.clone();

    // 1. Mismatch on UNUSED code (wrong client_id, wrong DPoP key, wrong verifier) does NOT burn code
    let mut wrong_client = TestClient::web(&harness);
    wrong_client.client_id = common::LOOPBACK_CLIENT_ID.to_owned();
    let mismatch_client_resp = wrong_client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", &code),
                ("code_verifier", &verifier),
                ("redirect_uri", &redirect),
            ],
        )
        .await;
    assert_eq!(mismatch_client_resp.status, 400);

    let mut wrong_dpop = TestClient::web(&harness);
    let mismatch_dpop_resp = wrong_dpop
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", &code),
                ("code_verifier", &verifier),
                ("redirect_uri", &redirect),
            ],
        )
        .await;
    assert_eq!(mismatch_dpop_resp.status, 400);

    let wrong_verifier = "wrong-verifier-0123456789012345678901234567890123456789";
    let mismatch_pkce_resp = client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", &code),
                ("code_verifier", wrong_verifier),
                ("redirect_uri", &redirect),
            ],
        )
        .await;
    assert_eq!(mismatch_pkce_resp.status, 400);

    // Legitimate client can STILL redeem the unburned code
    let legit_resp = client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", &code),
                ("code_verifier", &verifier),
                ("redirect_uri", &redirect),
            ],
        )
        .await;
    assert_eq!(
        legit_resp.status,
        200,
        "unused code must not be burned by prior mismatched exchanges: {}",
        legit_resp.text()
    );
    let tok: common::TokenResponse = serde_json::from_slice(&legit_resp.body).unwrap();

    // 2. Mismatch on SPENT code (wrong client_id, wrong DPoP key, wrong verifier) does NOT revoke session
    let spent_mismatch_client = wrong_client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", &code),
                ("code_verifier", &verifier),
                ("redirect_uri", &redirect),
            ],
        )
        .await;
    assert_eq!(spent_mismatch_client.status, 400);

    let spent_mismatch_dpop = wrong_dpop
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", &code),
                ("code_verifier", &verifier),
                ("redirect_uri", &redirect),
            ],
        )
        .await;
    assert_eq!(spent_mismatch_dpop.status, 400);

    let spent_mismatch_pkce = client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", &code),
                ("code_verifier", wrong_verifier),
                ("redirect_uri", &redirect),
            ],
        )
        .await;
    assert_eq!(spent_mismatch_pkce.status, 400);

    // Legitimate session is STILL active and can refresh cleanly
    let refresh_ok = client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &tok.refresh_token),
            ],
        )
        .await;
    assert_eq!(refresh_ok.status, 200);
    let tok2: common::TokenResponse = serde_json::from_slice(&refresh_ok.body).unwrap();

    // 3. Genuine bound replay (matching client_id, DPoP key, redirect_uri, PKCE) DOES revoke session
    let genuine_replay = client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", &code),
                ("code_verifier", &verifier),
                ("redirect_uri", &redirect),
            ],
        )
        .await;
    assert_eq!(genuine_replay.status, 400);
    assert!(genuine_replay.text().contains("revoked"));

    let after_revoke = client
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &tok2.refresh_token),
            ],
        )
        .await;
    assert_eq!(after_revoke.status, 400);
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn concurrent_code_replay_before_store_session_revokes_session_and_rejects_first_exchange() {
    use std::sync::atomic::{AtomicBool, Ordering};

    use petrel::rt::BoxFuture;
    use petrel_server::error::OAuthServerError;
    use petrel_server::oauth::OAuthAuthorizationServer;
    use petrel_server::oauth::interface::DefaultOAuthHtmlRenderer;
    use petrel_server::store::{
        OAuthRefreshRotationResult, OAuthServerStores, OAuthSession, RotateRefreshTokenParams,
    };
    use tokio::sync::Notify;

    struct InterleavedTokenStore {
        inner: Arc<InMemoryOAuthStore>,
        pause_once: AtomicBool,
        entered_store: Arc<Notify>,
        release_store: Arc<Notify>,
    }

    impl OAuthTokenStore for InterleavedTokenStore {
        fn store_session(
            &self,
            session: OAuthSession,
        ) -> BoxFuture<'_, Result<(), OAuthServerError>> {
            let inner = self.inner.clone();
            let should_pause = self.pause_once.swap(false, Ordering::SeqCst);
            let entered = self.entered_store.clone();
            let release = self.release_store.clone();
            Box::pin(async move {
                if should_pause {
                    entered.notify_one();
                    release.notified().await;
                }
                inner.store_session(session).await
            })
        }
        fn lookup_by_access_token_digest(
            &self,
            digest: &[u8],
        ) -> BoxFuture<'_, Result<Option<OAuthSession>, OAuthServerError>> {
            self.inner.lookup_by_access_token_digest(digest)
        }
        fn lookup_session(
            &self,
            session_id: &str,
        ) -> BoxFuture<'_, Result<Option<OAuthSession>, OAuthServerError>> {
            self.inner.lookup_session(session_id)
        }
        fn lookup_by_token_digest(
            &self,
            token_digest: &[u8],
        ) -> BoxFuture<'_, Result<Option<OAuthSession>, OAuthServerError>> {
            self.inner.lookup_by_token_digest(token_digest)
        }
        fn rotate_refresh_token<'a>(
            &'a self,
            params: RotateRefreshTokenParams<'a>,
        ) -> BoxFuture<'a, Result<OAuthRefreshRotationResult, OAuthServerError>> {
            self.inner.rotate_refresh_token(params)
        }
        fn revoke_session(
            &self,
            session_id: &str,
            revoked_at_secs: i64,
        ) -> BoxFuture<'_, Result<bool, OAuthServerError>> {
            self.inner.revoke_session(session_id, revoked_at_secs)
        }
        fn revoke_by_token_digest(
            &self,
            token_digest: &[u8],
            revoked_at_secs: i64,
        ) -> BoxFuture<'_, Result<bool, OAuthServerError>> {
            self.inner
                .revoke_by_token_digest(token_digest, revoked_at_secs)
        }
    }

    let base_harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;
    let entered_store = Arc::new(Notify::new());
    let release_store = Arc::new(Notify::new());
    let mut race_stores = OAuthServerStores::from_unified(base_harness.store.clone());
    race_stores.tokens = Arc::new(InterleavedTokenStore {
        inner: base_harness.store.clone(),
        pause_once: AtomicBool::new(true),
        entered_store: entered_store.clone(),
        release_store: release_store.clone(),
    });
    let race_harness = TestServer {
        issuer: base_harness.issuer.clone(),
        clock: base_harness.clock.clone(),
        random: base_harness.random.clone(),
        store: base_harness.store.clone(),
        clients: base_harness.clients.clone(),
        lexicons: base_harness.lexicons.clone(),
        confidential_key: base_harness.confidential_key.clone(),
        server: OAuthAuthorizationServer::with_dependencies(
            OAuthAuthorizationServerConfiguration::new(TEST_ISSUER, vec![7_u8; 32]).unwrap(),
            race_stores,
            Arc::new(common::TestAccounts::with_alice_and_bob()),
            base_harness.clients.clone(),
            None,
            Arc::new(DefaultOAuthHtmlRenderer),
            base_harness.clock.clone(),
            Arc::new(common::TestRandom::new()),
        )
        .unwrap(),
    };

    let mut c1 = TestClient::web(&race_harness);
    let request_uri = c1.push_request("atproto transition:generic").await;
    let query = format!(
        "client_id={}&request_uri={}",
        OAuthForm::encode_component(&c1.client_id),
        OAuthForm::encode_component(&request_uri)
    );
    let page = race_harness.get("/oauth/authorize", Some(&query)).await;
    let html = page.text();
    let cookie = page
        .headers
        .get("Set-Cookie")
        .unwrap()
        .split(';')
        .next()
        .unwrap()
        .to_owned();
    let flow_id = common::extract_hidden_input(&html, "flow_id");
    let csrf_token = common::extract_hidden_input(&html, "csrf_token");
    let consent = race_harness
        .post_form(
            "/oauth/authorize",
            &[
                ("flow_id", &flow_id),
                ("csrf_token", &csrf_token),
                ("identifier", ALICE_HANDLE),
                ("password", "alice-password"),
                ("decision", "approve"),
            ],
            &[("Cookie", &cookie)],
        )
        .await;
    assert_eq!(consent.status, 303);
    let code = url::Url::parse(consent.headers.get("Location").unwrap())
        .unwrap()
        .query_pairs()
        .find(|(k, _)| k == "code")
        .unwrap()
        .1
        .into_owned();

    // Capture c1's bound DPoP key & primed nonce for a clean concurrent bound replay with unique jti
    let verifier = c1.verifier.clone();
    let redirect = c1.redirect_uri.clone();
    let client_id = c1.client_id.clone();
    let dpop_key = c1.dpop_key.clone();
    let primed_nonce = c1.nonce.clone();

    let first_exchange = async {
        c1.send_post(
            "/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", &code),
                ("code_verifier", &verifier),
                ("redirect_uri", &redirect),
            ],
        )
        .await
    };

    let replay_and_release = async {
        entered_store.notified().await;
        // Request 1 has consumed `code`, has NOT yet persisted session; send concurrent bound replay
        let replay_proof = make_dpop_proof(
            &dpop_key,
            "POST",
            &format!("{TEST_ISSUER}/oauth/token"),
            primed_nonce.as_deref(),
            None,
            race_harness.clock.now_secs(),
            "concurrent-code-replay-jti",
        );
        let replay_resp = race_harness
            .post_form(
                "/oauth/token",
                &[
                    ("client_id", &client_id),
                    ("grant_type", "authorization_code"),
                    ("code", &code),
                    ("code_verifier", &verifier),
                    ("redirect_uri", &redirect),
                ],
                &[("DPoP", &replay_proof)],
            )
            .await;
        assert_eq!(replay_resp.status, 400);
        assert!(replay_resp.text().contains("revoked"));
        release_store.notify_one();
    };

    let (first_resp, ()) = tokio::join!(first_exchange, replay_and_release);
    assert_eq!(
        first_resp.status,
        400,
        "racing first exchange must not issue live tokens after concurrent replay: {}",
        first_resp.text()
    );
    assert!(!first_resp.text().contains("access_token"));

    // Persisted session (if recorded) must be marked revoked and unusable
    let sessions = race_harness.store.snapshot_sessions().await;
    assert!(sessions.iter().all(|s| s.revoked_at_secs.is_some()));
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn refresh_and_initial_grant_cap_jwt_exp_and_expires_in_at_session_hard_expiry() {
    use petrel_server::oauth::OAuthAuthorizationServer;
    use petrel_server::oauth::interface::DefaultOAuthHtmlRenderer;
    use petrel_server::store::OAuthServerStores;

    // Part A: Refreshing 1s before hard_expires_at_secs caps JWT exp, stored
    // access_token_expires_at_secs, and response expires_in at hard_expires_at_secs.
    let harness = TestServer::new(OAuthAccessTokenFormat::Jwt).await;
    let mut web = TestClient::web(&harness);
    let tok1 = web
        .sign_in(ALICE_HANDLE, "alice-password", "atproto transition:generic")
        .await;
    let hard = harness.store.snapshot_sessions().await[0]
        .hard_expires_at_secs
        .expect("public session has hard expiry");

    // Advance clock to 1 second before hard expiry and rotate refresh token.
    harness.clock.set(hard - 1);
    let refresh_resp = web
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "refresh_token"),
                ("refresh_token", &tok1.refresh_token),
            ],
        )
        .await;
    assert_eq!(
        refresh_resp.status,
        200,
        "refresh failed: {}",
        refresh_resp.text()
    );
    let tok2: common::TokenResponse = serde_json::from_slice(&refresh_resp.body).unwrap();
    assert_eq!(tok2.expires_in, 1);

    let sessions = harness.store.snapshot_sessions().await;
    assert_eq!(sessions[0].expires_at_secs, hard);
    assert_eq!(sessions[0].access_token_expires_at_secs, hard);

    let jwks = harness.server.jwks().unwrap();
    let mut jwt_constraints = OAuthJwtVerificationConstraints::new(hard - 1);
    jwt_constraints.allowed_algorithms = vec![OAuthJwsAlgorithm::Es256, OAuthJwsAlgorithm::Es256k];
    jwt_constraints.expected_type = Some("at+jwt".to_owned());
    jwt_constraints.expected_issuer = Some(TEST_ISSUER.into());
    jwt_constraints.expected_audience = Some(TEST_ISSUER.into());
    jwt_constraints.require_issued_at = true;
    jwt_constraints.require_expiration = true;
    let verified = OAuthCompactJwt::verify_with_jwks::<OAuthAccessTokenClaims>(
        &tok2.access_token,
        &jwks,
        &jwt_constraints,
    )
    .expect("refreshed JWT valid 1s before hard expiry");
    assert_eq!(verified.claims.exp, hard);

    let stateless = OAuthResourceServerVerifier::new(
        OAuthResourceVerificationMode::Stateless {
            issuer: TEST_ISSUER.into(),
            jwks,
            expected_audience: Some(TEST_ISSUER.into()),
        },
        petrel_server::dpop::OAuthDpopNonceService::with_defaults(
            petrel_server::support::OAuthKeyedDigest::new(vec![7_u8; 32]).unwrap(),
        ),
        petrel_server::support::OAuthKeyedDigest::new(vec![7_u8; 32]).unwrap(),
        harness.store.clone(),
        harness.clock.clone(),
    )
    .with_require_dpop_nonce(false);
    let shared = harness
        .server
        .resource_verifier()
        .with_require_dpop_nonce(false);
    let resource_url = "https://pds.example.com/xrpc/com.atproto.server.getSession";
    let ath2 = OAuthDpopProofValidator::access_token_hash(&tok2.access_token);

    // Accepted at hard - 1 via Stateless verifier
    let proof_ok = make_dpop_proof(
        &web.dpop_key,
        "GET",
        resource_url,
        None,
        Some(&ath2),
        harness.clock.now_secs(),
        "cap-ok",
    );
    assert!(
        stateless
            .authenticate(
                "GET",
                resource_url,
                &OAuthHttpHeaders::new([
                    (
                        "Authorization",
                        format!("DPoP {}", tok2.access_token).as_str()
                    ),
                    ("DPoP", proof_ok.as_str()),
                ]),
            )
            .await
            .is_ok()
    );

    // Advance +2s (past hard expiry): Shared verifier immediately rejects.
    harness.clock.advance(2);
    let proof_shared_exp = make_dpop_proof(
        &web.dpop_key,
        "GET",
        resource_url,
        None,
        Some(&ath2),
        harness.clock.now_secs(),
        "cap-shared-exp",
    );
    assert!(
        shared
            .authenticate(
                "GET",
                resource_url,
                &OAuthHttpHeaders::new([
                    (
                        "Authorization",
                        format!("DPoP {}", tok2.access_token).as_str()
                    ),
                    ("DPoP", proof_shared_exp.as_str()),
                ]),
            )
            .await
            .is_err()
    );

    // Advance past JWT clock_skew_secs (5s) — still < 10s vs 300s default TTL: Stateless rejects!
    harness.clock.advance(5);
    let proof_stateless_exp = make_dpop_proof(
        &web.dpop_key,
        "GET",
        resource_url,
        None,
        Some(&ath2),
        harness.clock.now_secs(),
        "cap-stateless-exp",
    );
    assert!(
        stateless
            .authenticate(
                "GET",
                resource_url,
                &OAuthHttpHeaders::new([
                    (
                        "Authorization",
                        format!("DPoP {}", tok2.access_token).as_str()
                    ),
                    ("DPoP", proof_stateless_exp.as_str()),
                ]),
            )
            .await
            .is_err()
    );

    // Part B: Initial authorization_code exchange also caps JWT exp & expires_in when session
    // lifetime is shorter than access_token_ttl_secs.
    let mut short_harness = TestServer::new(OAuthAccessTokenFormat::Jwt).await;
    let mut cfg = OAuthAuthorizationServerConfiguration::with_testing_http_allowed(
        TEST_ISSUER,
        vec![7_u8; 32],
        false,
    )
    .unwrap();
    cfg.access_token_format = OAuthAccessTokenFormat::Jwt;
    cfg.access_token_ttl_secs = 300;
    cfg.public_client_session_lifetime_secs = 120;
    cfg.public_client_refresh_ttl_secs = 120;
    short_harness.server = OAuthAuthorizationServer::with_dependencies(
        cfg,
        OAuthServerStores::from_unified(short_harness.store.clone()),
        Arc::new(common::TestAccounts::with_alice_and_bob()),
        short_harness.clients.clone(),
        None,
        Arc::new(DefaultOAuthHtmlRenderer),
        short_harness.clock.clone(),
        short_harness.random.clone(),
    )
    .unwrap();

    let mut short_web = TestClient::web(&short_harness);
    let t0 = short_harness.clock.now_secs();
    let short_tok = short_web
        .sign_in(ALICE_HANDLE, "alice-password", "atproto transition:generic")
        .await;
    assert_eq!(short_tok.expires_in, 120);
    let short_sessions = short_harness.store.snapshot_sessions().await;
    assert_eq!(short_sessions[0].expires_at_secs, t0 + 120);
    assert_eq!(short_sessions[0].access_token_expires_at_secs, t0 + 120);
    let short_jwks = short_harness.server.jwks().unwrap();
    let mut short_constraints = OAuthJwtVerificationConstraints::new(t0);
    short_constraints.allowed_algorithms =
        vec![OAuthJwsAlgorithm::Es256, OAuthJwsAlgorithm::Es256k];
    short_constraints.expected_type = Some("at+jwt".to_owned());
    short_constraints.expected_issuer = Some(TEST_ISSUER.into());
    short_constraints.expected_audience = Some(TEST_ISSUER.into());
    short_constraints.require_issued_at = true;
    short_constraints.require_expiration = true;
    let short_verified = OAuthCompactJwt::verify_with_jwks::<OAuthAccessTokenClaims>(
        &short_tok.access_token,
        &short_jwks,
        &short_constraints,
    )
    .unwrap();
    assert_eq!(short_verified.claims.exp, t0 + 120);
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn concurrent_authorize_flows_in_shared_cookie_jar_both_succeed_and_reject_invalid_csrf() {
    use petrel_server::http::OAuthHttpRequest;

    let harness = TestServer::new(OAuthAccessTokenFormat::Opaque).await;
    let mut client1 = TestClient::web(&harness);
    let mut client2 = TestClient::web(&harness);

    // Tab 1 starts authorize GET with empty cookie jar.
    let req_uri1 = client1.push_request("atproto transition:generic").await;
    let q1 = format!(
        "client_id={}&request_uri={}",
        OAuthForm::encode_component(&client1.client_id),
        OAuthForm::encode_component(&req_uri1)
    );
    let page1 = harness.get("/oauth/authorize", Some(&q1)).await;
    assert_eq!(page1.status, 200, "tab 1 GET failed: {}", page1.text());
    let set_cookie1 = page1.headers.get("Set-Cookie").expect("tab 1 Set-Cookie");
    assert!(set_cookie1.starts_with("__Host-petrel_oauth_csrf="));
    assert!(set_cookie1.contains("HttpOnly; SameSite=Lax; Path=/; Secure"));
    let cookie_jar = set_cookie1.split(';').next().unwrap().to_owned();
    let html1 = page1.text();
    let flow1 = common::extract_hidden_input(&html1, "flow_id");
    let csrf1 = common::extract_hidden_input(&html1, "csrf_token");

    // Tab 2 opens authorize GET for the same issuer in the SAME browser cookie jar.
    let req_uri2 = client2.push_request("atproto transition:generic").await;
    let q2 = format!(
        "client_id={}&request_uri={}",
        OAuthForm::encode_component(&client2.client_id),
        OAuthForm::encode_component(&req_uri2)
    );
    let mut hdrs2 = OAuthHttpHeaders::default();
    hdrs2.set("Cookie", &cookie_jar);
    let page2 = harness
        .server
        .handle(
            OAuthHttpRequest::new("GET", "/oauth/authorize")
                .with_query(q2)
                .with_headers(hdrs2),
        )
        .await;
    assert_eq!(page2.status, 200, "tab 2 GET failed: {}", page2.text());
    let set_cookie2 = page2.headers.get("Set-Cookie").expect("tab 2 Set-Cookie");
    let cookie_jar = set_cookie2.split(';').next().unwrap().to_owned();
    let html2 = page2.text();
    let flow2 = common::extract_hidden_input(&html2, "flow_id");
    let csrf2 = common::extract_hidden_input(&html2, "csrf_token");
    assert_ne!(flow1, flow2);
    assert_ne!(csrf1, csrf2);

    // Missing or invalid CSRF cookie on Tab 1 rejects 403 and does NOT consume Tab 1 flow.
    let missing_cookie_resp = harness
        .post_form(
            "/oauth/authorize",
            &[
                ("flow_id", &flow1),
                ("csrf_token", &csrf1),
                ("identifier", ALICE_HANDLE),
                ("password", "alice-password"),
                ("decision", "approve"),
            ],
            &[],
        )
        .await;
    assert_eq!(missing_cookie_resp.status, 403);

    let forged_cookie_resp = harness
        .post_form(
            "/oauth/authorize",
            &[
                ("flow_id", &flow1),
                ("csrf_token", &csrf1),
                ("identifier", ALICE_HANDLE),
                ("password", "alice-password"),
                ("decision", "approve"),
            ],
            &[("Cookie", "__Host-petrel_oauth_csrf=wrong-cookie")],
        )
        .await;
    assert_eq!(forged_cookie_resp.status, 403);

    // Tab 1 STILL completes consent cleanly even after Tab 2 overwrote jar's Set-Cookie header.
    let consent1 = harness
        .post_form(
            "/oauth/authorize",
            &[
                ("flow_id", &flow1),
                ("csrf_token", &csrf1),
                ("identifier", ALICE_HANDLE),
                ("password", "alice-password"),
                ("decision", "approve"),
            ],
            &[("Cookie", &cookie_jar)],
        )
        .await;
    assert_eq!(
        consent1.status,
        303,
        "tab 1 POST failed: {}",
        consent1.text()
    );
    let code1 = url::Url::parse(consent1.headers.get("Location").unwrap())
        .unwrap()
        .query_pairs()
        .find(|(k, _)| k == "code")
        .unwrap()
        .1
        .into_owned();
    let verifier1 = client1.verifier.clone();
    let redirect1 = client1.redirect_uri.clone();
    let tok1 = client1
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", &code1),
                ("code_verifier", &verifier1),
                ("redirect_uri", &redirect1),
            ],
        )
        .await;
    assert_eq!(tok1.status, 200);

    // Tab 2 ALSO completes consent cleanly using the same cookie jar + its own hidden csrf2.
    let consent2 = harness
        .post_form(
            "/oauth/authorize",
            &[
                ("flow_id", &flow2),
                ("csrf_token", &csrf2),
                ("identifier", ALICE_HANDLE),
                ("password", "alice-password"),
                ("decision", "approve"),
            ],
            &[("Cookie", &cookie_jar)],
        )
        .await;
    assert_eq!(
        consent2.status,
        303,
        "tab 2 POST failed: {}",
        consent2.text()
    );
    let code2 = url::Url::parse(consent2.headers.get("Location").unwrap())
        .unwrap()
        .query_pairs()
        .find(|(k, _)| k == "code")
        .unwrap()
        .1
        .into_owned();
    let verifier2 = client2.verifier.clone();
    let redirect2 = client2.redirect_uri.clone();
    let tok2 = client2
        .send_post(
            "/oauth/token",
            &[
                ("grant_type", "authorization_code"),
                ("code", &code2),
                ("code_verifier", &verifier2),
                ("redirect_uri", &redirect2),
            ],
        )
        .await;
    assert_eq!(tok2.status, 200);

    // Single-use browser flow rejects replay of Tab 2.
    let replay2 = harness
        .post_form(
            "/oauth/authorize",
            &[
                ("flow_id", &flow2),
                ("csrf_token", &csrf2),
                ("identifier", ALICE_HANDLE),
                ("password", "alice-password"),
                ("decision", "approve"),
            ],
            &[("Cookie", &cookie_jar)],
        )
        .await;
    assert_eq!(replay2.status, 400);

    // Valid CSRF cookie from an independent browser session still fails 403 on another flow.
    let mut client3 = TestClient::web(&harness);
    let req_uri3 = client3.push_request("atproto transition:generic").await;
    let q3 = format!(
        "client_id={}&request_uri={}",
        OAuthForm::encode_component(&client3.client_id),
        OAuthForm::encode_component(&req_uri3)
    );
    let page3 = harness.get("/oauth/authorize", Some(&q3)).await;
    let html3 = page3.text();
    let flow3 = common::extract_hidden_input(&html3, "flow_id");
    let csrf3 = common::extract_hidden_input(&html3, "csrf_token");
    let cross_browser = harness
        .post_form(
            "/oauth/authorize",
            &[
                ("flow_id", &flow3),
                ("csrf_token", &csrf3),
                ("identifier", ALICE_HANDLE),
                ("password", "alice-password"),
                ("decision", "approve"),
            ],
            &[("Cookie", &cookie_jar)],
        )
        .await;
    assert_eq!(cross_browser.status, 403);
}
