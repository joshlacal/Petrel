//! The Rust test server the end-to-end suite runs clients against.
//!
//! Native only. On `wasm32` this binary is compiled out entirely, so that
//! `cargo check --workspace --target wasm32-unknown-unknown` stays green; the
//! `no_main` attribute is what lets an empty binary crate build there.
#![cfg_attr(target_arch = "wasm32", no_main)]
#![cfg(not(target_arch = "wasm32"))]

use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;

use axum::Router;
use axum::extract::{FromRef, State};
use axum::http::header::CONTENT_TYPE;
use axum::http::{HeaderMap, HeaderValue, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use petrel::rt::BoxFuture;
use petrel_api::generated::app::bsky::feed::get_timeline;
use petrel_api::generated::com::atproto::repo::put_record::{
    Error as PutRecordError, Input as PutRecordInput, Output as PutRecordOutput, PutRecord,
};
use petrel_core::CidString;
use petrel_server::OAuthServerError;
use petrel_server::axum::{
    DpopResourceAuth, DpopVerifierState, ServiceAuth, ServiceAuthState, XrpcRouter, cab_router,
    oauth_router,
};
use petrel_server::cab::{
    CabKeyStore, CabServerConfig, CabServerCore, InMemoryCabDeviceStore, InMemoryCabReplayStore,
};
use petrel_server::clients::{
    OAuthApplicationType, OAuthClientKind, OAuthClientMetadata, OAuthResolvedClientMetadata,
    OAuthTokenEndpointAuthMethod, StaticOAuthClientResolver,
};
use petrel_server::jose::{
    OAuthJsonWebKey, OAuthJsonWebKeySet, OAuthJwsAlgorithm, OAuthSigningKey,
};
use petrel_server::oauth::config::OAuthAccessTokenFormat;
use petrel_server::oauth::interface::{
    DefaultOAuthHtmlRenderer, OAuthAccountAuthenticateRequest, OAuthAccountAuthenticating,
    OAuthAuthenticatedAccount,
};
use petrel_server::oauth::{OAuthAuthorizationServer, OAuthAuthorizationServerConfiguration};
use petrel_server::service_auth::{
    InMemoryServiceAuthReplayStore, PublicKey, ServiceAuthAudience, ServiceAuthError,
    ServiceAuthKeyResolver, ServiceAuthMethodPolicy, ServiceAuthVerifier,
    ServiceAuthVerifierConfig, public_key_from_jwk,
};
use petrel_server::store::{InMemoryOAuthStore, OAuthGrantBinding, OAuthServerStores};
use petrel_server::support::{SystemOAuthClock, SystemOAuthRandomSource};
use petrel_server::xrpc::XrpcServerError;
use serde::{Deserialize, Serialize};
use tokio::net::TcpListener;

const ALICE_DID: &str = "did:plc:alice1234567890abcdef";
const ALICE_HANDLE: &str = "alice.example";
const ALICE_PASSWORD: &str = "alice-password";
const BOB_DID: &str = "did:plc:bob1234567890abcdefgh";
const BOB_HANDLE: &str = "bob.example";
const BOB_PASSWORD: &str = "bob-password";

#[derive(Debug, Default)]
struct TestAccounts;

impl OAuthAccountAuthenticating for TestAccounts {
    fn authenticate(
        &self,
        req: OAuthAccountAuthenticateRequest,
    ) -> BoxFuture<'_, Result<Option<OAuthAuthenticatedAccount>, OAuthServerError>> {
        Box::pin(async move {
            let ident = req.form_fields.get("identifier").map_or("", String::as_str);
            let password = req.form_fields.get("password").map_or("", String::as_str);
            let matched = match (ident, password) {
                (ALICE_HANDLE | ALICE_DID, ALICE_PASSWORD) => Some((ALICE_DID, ALICE_HANDLE)),
                (BOB_HANDLE | BOB_DID, BOB_PASSWORD) => Some((BOB_DID, BOB_HANDLE)),
                _ => None,
            };
            Ok(matched.map(|(did, handle)| OAuthAuthenticatedAccount {
                binding: OAuthGrantBinding::Subject {
                    did: did.to_owned(),
                },
                handle: Some(handle.to_owned()),
            }))
        })
    }
}

#[derive(Debug, Default)]
struct DynamicTestKeyResolver {
    keys: tokio::sync::RwLock<HashMap<String, PublicKey>>,
}

impl DynamicTestKeyResolver {
    async fn register(&self, did: String, key: PublicKey) {
        self.keys.write().await.insert(did, key);
    }
}

impl ServiceAuthKeyResolver for DynamicTestKeyResolver {
    fn signing_key<'a>(
        &'a self,
        did: &'a str,
        _force_refresh: bool,
    ) -> BoxFuture<'a, Result<PublicKey, ServiceAuthError>> {
        let did_owned = did.to_owned();
        Box::pin(async move {
            self.keys
                .read()
                .await
                .get(&did_owned)
                .cloned()
                .ok_or_else(|| ServiceAuthError::KeyResolutionFailed {
                    did: did_owned,
                    key_id: "#atproto".into(),
                    reason: "unregistered test key".into(),
                })
        })
    }
}

#[derive(Clone)]
struct ServerState {
    dpop: DpopVerifierState,
    service_auth: ServiceAuthState,
    sa_resolver: Arc<DynamicTestKeyResolver>,
    oauth: Arc<OAuthAuthorizationServer>,
    client_resolver: Arc<StaticOAuthClientResolver>,
}

impl FromRef<ServerState> for DpopVerifierState {
    fn from_ref(s: &ServerState) -> Self {
        s.dpop.clone()
    }
}

impl FromRef<ServerState> for ServiceAuthState {
    fn from_ref(s: &ServerState) -> Self {
        s.service_auth.clone()
    }
}

#[derive(Deserialize)]
struct RegisterClientBody {
    client_id: String,
    redirect_uris: Vec<String>,
    #[serde(default)]
    jwks: Option<OAuthJsonWebKeySet>,
    #[serde(default)]
    confidential: bool,
    #[serde(default)]
    scope: Option<String>,
}

#[derive(Deserialize)]
struct RegisterServiceAuthKeyBody {
    did: String,
    jwk: OAuthJsonWebKey,
}

#[derive(Serialize)]
struct ServiceAuthEcho {
    did: String,
    audience: String,
    lexicon_method: Option<String>,
    algorithm: String,
}

async fn get_session_dpop(
    State(st): State<ServerState>,
    DpopResourceAuth(grant): DpopResourceAuth,
) -> Response {
    let handle = match grant.did.as_str() {
        ALICE_DID => ALICE_HANDLE,
        BOB_DID => BOB_HANDLE,
        _ => "user.example",
    };
    let nonce = st.dpop.verifier.current_nonce();
    let mut headers = HeaderMap::new();
    headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
    if let Ok(val) = HeaderValue::from_str(&nonce) {
        headers.insert("dpop-nonce", val);
    }
    let body = serde_json::to_vec(&serde_json::json!({
        "did": grant.did,
        "handle": handle,
        "active": true,
        "scope": grant.expanded_scopes.scope_string(),
    }))
    .unwrap_or_else(|_| b"{}".to_vec());
    (StatusCode::OK, headers, body).into_response()
}

async fn register_client(State(st): State<ServerState>, body: axum::body::Bytes) -> StatusCode {
    let Ok(body) = serde_json::from_slice::<RegisterClientBody>(&body) else {
        return StatusCode::BAD_REQUEST;
    };
    let resolved = OAuthResolvedClientMetadata {
        kind: OAuthClientKind::Discoverable,
        metadata: OAuthClientMetadata {
            client_id: body.client_id,
            client_name: Some("Dynamic Test Client".into()),
            client_uri: None,
            logo_uri: None,
            tos_uri: None,
            policy_uri: None,
            application_type: if body.confidential {
                OAuthApplicationType::Web
            } else {
                OAuthApplicationType::Native
            },
            grant_types: vec!["authorization_code".into(), "refresh_token".into()],
            response_types: vec!["code".into()],
            redirect_uris: body.redirect_uris,
            scope: Some(
                body.scope
                    .unwrap_or_else(|| "atproto transition:generic".into()),
            ),
            token_endpoint_auth_method: if body.confidential {
                OAuthTokenEndpointAuthMethod::PrivateKeyJwt
            } else {
                OAuthTokenEndpointAuthMethod::None
            },
            token_endpoint_auth_signing_alg: body.confidential.then(|| "ES256".into()),
            dpop_bound_access_tokens: true,
            jwks_uri: None,
            jwks: body.jwks.clone(),
        },
        key_set: body.jwks,
    };
    st.client_resolver.register(resolved).await;
    StatusCode::CREATED
}

async fn register_service_auth_key(
    State(st): State<ServerState>,
    body: axum::body::Bytes,
) -> StatusCode {
    let Ok(body) = serde_json::from_slice::<RegisterServiceAuthKeyBody>(&body) else {
        return StatusCode::BAD_REQUEST;
    };
    let Ok(key) = public_key_from_jwk(&body.jwk) else {
        return StatusCode::BAD_REQUEST;
    };
    st.sa_resolver.register(body.did, key).await;
    StatusCode::CREATED
}

async fn session_count(State(st): State<ServerState>) -> impl IntoResponse {
    let meta = st.oauth.authorization_server_metadata();
    json_response(
        StatusCode::OK,
        &serde_json::json!({ "issuer": meta.issuer }),
    )
}

async fn service_auth_echo(ServiceAuth(auth): ServiceAuth) -> impl IntoResponse {
    json_response(
        StatusCode::OK,
        &ServiceAuthEcho {
            did: auth.issuer,
            audience: auth.audience,
            lexicon_method: auth.lexicon_method,
            algorithm: auth.algorithm,
        },
    )
}

fn json_response<T: Serialize>(status: StatusCode, payload: &T) -> Response {
    let bytes = serde_json::to_vec(payload).unwrap_or_else(|_| b"{}".to_vec());
    let mut headers = HeaderMap::new();
    headers.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
    (status, headers, bytes).into_response()
}

fn parse_bind_addr() -> (String, String) {
    let mut host = "127.0.0.1".to_owned();
    let mut port = "0".to_owned();
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--host" => {
                if let Some(v) = args.next() {
                    host = v;
                }
            }
            "--port" => {
                if let Some(v) = args.next() {
                    port = v;
                }
            }
            _ => {}
        }
    }
    (host, port)
}

#[tokio::main]
#[allow(clippy::too_many_lines)]
async fn main() {
    let (host, port) = parse_bind_addr();
    let bind: SocketAddr = format!("{host}:{port}").parse().expect("valid socket addr");
    let listener = TcpListener::bind(bind).await.expect("bind test server");
    let local_addr = listener.local_addr().expect("local_addr");
    let base_url = format!("http://127.0.0.1:{}", local_addr.port());

    let store = Arc::new(InMemoryOAuthStore::new());
    let client_resolver = Arc::new(StaticOAuthClientResolver::new());
    let cab_signing_key =
        OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("cab-e2e-1".into()))
            .expect("generate cab key");
    let cab_jwks = OAuthJsonWebKeySet::new(vec![cab_signing_key.public_jwk(true).unwrap()]);

    // Pre-register a confidential client using this server's CAB JWKS + loopback web/native clients.
    let cab_client_id = format!("{base_url}/oauth-client-metadata.json");
    let cab_redirect = format!("{base_url}/cab-callback");
    client_resolver
        .register(OAuthResolvedClientMetadata {
            kind: OAuthClientKind::Trusted,
            metadata: OAuthClientMetadata {
                client_id: cab_client_id.clone(),
                client_name: Some("Petrel Rust E2E CAB Client".into()),
                client_uri: None,
                logo_uri: None,
                tos_uri: None,
                policy_uri: None,
                application_type: OAuthApplicationType::Native,
                grant_types: vec!["authorization_code".into(), "refresh_token".into()],
                response_types: vec!["code".into()],
                redirect_uris: vec![
                    cab_redirect.clone(),
                    "http://127.0.0.1/callback".into(),
                    "http://127.0.0.1:8080/callback".into(),
                ],
                scope: Some("atproto transition:generic".into()),
                token_endpoint_auth_method: OAuthTokenEndpointAuthMethod::PrivateKeyJwt,
                token_endpoint_auth_signing_alg: Some("ES256".into()),
                dpop_bound_access_tokens: true,
                jwks_uri: None,
                jwks: Some(cab_jwks.clone()),
            },
            key_set: Some(cab_jwks),
        })
        .await;

    let mut cfg = OAuthAuthorizationServerConfiguration::with_testing_http_allowed(
        &base_url,
        vec![13_u8; 32],
        true,
    )
    .expect("oauth cfg");
    cfg.access_token_format = OAuthAccessTokenFormat::Jwt;

    let oauth = Arc::new(
        OAuthAuthorizationServer::with_dependencies(
            cfg,
            OAuthServerStores::from_unified(store),
            Arc::new(TestAccounts),
            client_resolver.clone(),
            None,
            Arc::new(DefaultOAuthHtmlRenderer),
            Arc::new(SystemOAuthClock),
            Arc::new(SystemOAuthRandomSource),
        )
        .expect("build OAuth server"),
    );

    let cab_key_store = CabKeyStore::new(vec![cab_signing_key], "cab-e2e-1").expect("cab keystore");
    let mut cab_cfg = CabServerConfig::new(&base_url, &cab_client_id);
    cab_cfg.allowed_audiences = vec![base_url.clone()];
    cab_cfg.client_metadata = Some(serde_json::json!({
        "client_id": cab_client_id,
        "client_name": "Petrel Rust E2E CAB Client",
        "application_type": "native",
        "grant_types": ["authorization_code", "refresh_token"],
        "response_types": ["code"],
        "redirect_uris": [cab_redirect, "http://127.0.0.1/callback"],
        "scope": "atproto transition:generic",
        "token_endpoint_auth_method": "private_key_jwt",
        "token_endpoint_auth_signing_alg": "ES256",
        "dpop_bound_access_tokens": true,
        "jwks_uri": format!("{base_url}/.well-known/jwks.json")
    }));
    let cab = Arc::new(
        CabServerCore::new(
            cab_cfg,
            cab_key_store,
            &[17_u8; 32],
            Arc::new(InMemoryCabDeviceStore::new()),
            Arc::new(InMemoryCabReplayStore::new()),
        )
        .expect("build cab server"),
    );

    let sa_resolver = Arc::new(DynamicTestKeyResolver::default());
    let sa_replay = Arc::new(InMemoryServiceAuthReplayStore::new());
    let sa_did = "did:web:e2e.catbird.invalid";
    let sa_cfg = ServiceAuthVerifierConfig::new(ServiceAuthAudience::any_of([
        sa_did.to_owned(),
        format!("{sa_did}#atproto_xrpc"),
        base_url.clone(),
    ]));
    let sa_verifier = Arc::new(ServiceAuthVerifier::from_config(
        sa_cfg,
        sa_resolver.clone(),
        Some(sa_replay),
    ));

    let verifier = Arc::new(oauth.resource_verifier());
    let state = ServerState {
        dpop: DpopVerifierState::new(verifier, Some(base_url.clone())),
        service_auth: ServiceAuthState::new(sa_verifier)
            .with_policy(ServiceAuthMethodPolicy::Optional),
        sa_resolver,
        oauth: oauth.clone(),
        client_resolver,
    };

    let router: Router = XrpcRouter::<ServerState>::new()
        .authenticated_query::<get_timeline::GetTimeline, _, _>(|_st, auth, params| async move {
            Ok(get_timeline::Output {
                cursor: Some(format!("did={}&limit={}", auth.issuer, params.limit)),
                feed: Vec::new(),
                start_cursor: None,
            })
        })
        .procedure::<PutRecord, _, _>(|_st, _params, input: PutRecordInput| async move {
            if input.rkey.as_str() == "conflict" {
                return Err(XrpcServerError::declared_with_status(
                    409,
                    PutRecordError::InvalidSwap,
                    Some("swap mismatch in e2e".to_owned()),
                ));
            }
            Ok(PutRecordOutput {
                cid: CidString::parse(
                    "bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454",
                )
                .unwrap(),
                uri: format!(
                    "at://{}/{}/{}",
                    input.repo.as_str(),
                    input.collection.as_str(),
                    input.rkey.as_str()
                )
                .parse()
                .unwrap(),
                commit: None,
                validation_status: Some("valid".to_owned()),
            })
        })
        .merge_router(
            Router::new()
                .route("/xrpc/com.atproto.server.getSession", get(get_session_dpop))
                .route("/xrpc/_test/serviceAuthEcho", get(service_auth_echo))
                .route("/_test/registerClient", post(register_client))
                .route(
                    "/_test/registerServiceAuthKey",
                    post(register_service_auth_key),
                )
                .route("/_test/info", get(session_count))
                .route("/cab-callback", get(|| async { "ok" })),
        )
        .merge_router(oauth_router(oauth))
        .merge_router(cab_router(cab))
        .with_state(state);

    let _unused: HashMap<String, String> = HashMap::new();
    println!("PETREL_TEST_SERVER_URL={base_url}");
    axum::serve(listener, router).await.expect("serve");
}
