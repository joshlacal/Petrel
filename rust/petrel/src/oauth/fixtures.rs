//! In-memory OAuth test servers. Requests never leave the test process.

use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
};

use bytes::Bytes;
use futures_util::future::join_all;
use http::{Request, Response, header};
use serde_json::{Value, json};
use url::Url;

use crate::{
    crypto::{CryptoError, DpopSigner, Jwk, SoftwareDpopSigner, split_compact_jws},
    net::{HttpTransport, SendOptions, TransportError},
    rt::BoxFuture,
    storage::{MemorySecretStore, PendingRefresh, SessionStore},
    xrpc::AuthProvider,
};

use super::{
    AssertionBackendError, AssertionSigner, ClientAuth, OAuthClient, OAuthConfig, OAuthError,
    OAuthIdentity, OAuthIdentityError, OAuthIdentityResolver, OAuthProtocolError, OAuthTarget,
    metadata::example_metadata, protocol::retry_delay,
};

const ISSUER: &str = "https://issuer.example";
const PDS: &str = "https://pds.example";
const CAB: &str = "https://cab.example/backend";
const DID: &str = "did:plc:abcdefghijklmnopqrstuvwx";
const OTHER_DID: &str = "did:plc:otherabcdefghijklmnopq";
const REDIRECT: &str = "https://client.example/callback";
const CLIENT: &str = "https://client.example/client.json";
const SCOPE: &str = "atproto rpc:app.bsky.feed.getTimeline?aud=did:web:app.example%23bsky_appview";

#[derive(Default)]
struct Exchanges {
    par: Vec<HashMap<String, String>>,
    cab: Vec<(String, Value)>,
    assertions: Vec<String>,
    tokens: usize,
    refreshes: usize,
    revokes: Vec<String>,
    did_refreshes: usize,
    proof_jkts: Vec<String>,
    unexpected_requests: usize,
}

#[derive(Clone, Copy, Default)]
enum Scenario {
    #[default]
    Public,
    AsNonce,
    MissingExchangeNonce,
    SubjectMismatch,
    WrongThumbprint,
    MalformedRefreshToken,
    RetainedRefreshToken,
    TokenRedirect,
    CabNonce,
    CabClientMismatch,
}

struct Server {
    scenario: Scenario,
    exchanges: Mutex<Exchanges>,
}

impl Server {
    fn new(scenario: Scenario) -> Self {
        Self {
            scenario,
            exchanges: Mutex::new(Exchanges::default()),
        }
    }

    fn pushed_callback(&self, issuer: &str) -> Url {
        let state = self.exchanges.lock().unwrap().par[0]["state"].clone();
        let mut callback = Url::parse(REDIRECT).unwrap();
        callback
            .query_pairs_mut()
            .append_pair("state", &state)
            .append_pair("iss", issuer)
            .append_pair("code", "fixture-code");
        callback
    }

    async fn exchange(
        &self,
        request: Request<Bytes>,
        options: &SendOptions,
    ) -> Result<Response<Bytes>, TransportError> {
        let uri = request.uri();
        let form: HashMap<_, _> = url::form_urlencoded::parse(request.body())
            .into_owned()
            .collect();
        assert!(request.headers().get(header::AUTHORIZATION).is_none());
        let response = match (uri.host(), uri.path()) {
            (Some("pds.example"), "/.well-known/oauth-protected-resource") => {
                assert!(options.anonymous);
                json_response(
                    200,
                    None,
                    json!({"resource":PDS,"authorization_servers":[ISSUER]}),
                )
            }
            (Some("issuer.example"), "/.well-known/oauth-authorization-server") => {
                assert!(options.anonymous);
                json_response(
                    200,
                    None,
                    serde_json::to_value(example_metadata(ISSUER)).unwrap(),
                )
            }
            (Some("cab.example"), "/backend/oauth/client-assertion") => {
                let proof = validate_proof(&request);
                let mut calls = self.exchanges.lock().unwrap();
                let aud = form["aud"].clone();
                let challenged = calls.cab.len() % 2 == 0;
                calls.cab.push((aud, proof.clone()));
                if challenged {
                    assert!(proof.get("nonce").is_none());
                    json_response(400, Some("cab-nonce"), json!({"error":"use_dpop_nonce"}))
                } else {
                    assert_eq!(proof["nonce"], "cab-nonce");
                    let client = if matches!(self.scenario, Scenario::CabClientMismatch) {
                        "https://other.example/client.json"
                    } else {
                        CLIENT
                    };
                    json_response(
                        200,
                        None,
                        json!({
                            "client_id": client,
                            "client_assertion": format!("fixture-assertion-{}", calls.cab.len())
                        }),
                    )
                }
            }
            (Some("issuer.example"), "/par") => {
                let proof = validate_proof(&request);
                assert_eq!(form["client_id"], CLIENT);
                assert_eq!(form["code_challenge_method"], "S256");
                assert_eq!(form["scope"], SCOPE);
                assert!(
                    std::str::from_utf8(request.body())
                        .unwrap()
                        .contains("%2523")
                );
                let mut calls = self.exchanges.lock().unwrap();
                if let Some(assertion) = form.get("client_assertion") {
                    calls.assertions.push(assertion.clone());
                }
                calls.par.push(form);
                if matches!(self.scenario, Scenario::AsNonce) && calls.par.len() == 1 {
                    assert!(proof.get("nonce").is_none());
                    json_response(400, Some("fresh-nonce"), json!({"error":"use_dpop_nonce"}))
                } else {
                    if matches!(self.scenario, Scenario::AsNonce) {
                        assert_eq!(proof["nonce"], "fresh-nonce");
                    }
                    json_response(
                        201,
                        Some("par-nonce"),
                        json!({"request_uri":"urn:example:fixture"}),
                    )
                }
            }
            (Some("issuer.example"), "/token") => {
                let proof = validate_proof(&request);
                let grant = form["grant_type"].as_str();
                if grant == "authorization_code" {
                    assert_eq!(proof["nonce"], "par-nonce");
                    assert_eq!(form["code"], "fixture-code");
                    let mut calls = self.exchanges.lock().unwrap();
                    assert_eq!(
                        crate::crypto::pkce_challenge(&form["code_verifier"]),
                        calls.par.last().unwrap()["code_challenge"]
                    );
                    calls.tokens += 1;
                    if let Some(assertion) = form.get("client_assertion") {
                        calls.assertions.push(assertion.clone());
                    }
                    let jws =
                        split_compact_jws(request.headers()["dpop"].to_str().unwrap()).unwrap();
                    let header: Value = serde_json::from_slice(&jws.header).unwrap();
                    let key: Jwk = serde_json::from_value(header["jwk"].clone()).unwrap();
                    calls.proof_jkts.push(serde_json::to_string(&key).unwrap());
                    match self.scenario {
                        Scenario::TokenRedirect => Response::builder()
                            .status(303)
                            .header(header::LOCATION, "https://untrusted.example/token")
                            .body(Bytes::new())
                            .unwrap(),
                        Scenario::MissingExchangeNonce => token_response(DID, "first", None),
                        Scenario::SubjectMismatch => {
                            token_response(OTHER_DID, "first", Some("token-nonce"))
                        }
                        Scenario::WrongThumbprint => json_response(
                            200,
                            Some("token-nonce"),
                            json!({
                                "access_token": "access-first", "refresh_token": "refresh-first",
                                "token_type":"DPoP", "scope":SCOPE, "sub":DID, "dpop_jkt":"unexpected"
                            }),
                        ),
                        Scenario::MalformedRefreshToken => json_response(
                            200,
                            Some("token-nonce"),
                            json!({
                                "access_token": "access-first", "refresh_token": 12,
                                "token_type":"DPoP", "scope":SCOPE, "sub":DID
                            }),
                        ),
                        _ => token_response(DID, "first", Some("token-nonce")),
                    }
                } else {
                    assert_eq!(grant, "refresh_token");
                    assert_eq!(form["refresh_token"], "refresh-first");
                    assert_eq!(proof["nonce"], "token-nonce");
                    let count = {
                        let mut exchanges = self.exchanges.lock().unwrap();
                        exchanges.refreshes += 1;
                        exchanges.refreshes
                    };
                    retry_delay(15).await;
                    if matches!(self.scenario, Scenario::RetainedRefreshToken) {
                        json_response(
                            200,
                            None,
                            json!({
                                "access_token": format!("access-rotation-{count}"),
                                "token_type":"DPoP", "scope":SCOPE, "sub":DID
                            }),
                        )
                    } else {
                        token_response(DID, "second", None)
                    }
                }
            }
            (Some("issuer.example"), "/revoke") => {
                validate_proof(&request);
                self.exchanges
                    .lock()
                    .unwrap()
                    .revokes
                    .push(form["token"].clone());
                json_response(200, None, json!({}))
            }
            _ => {
                self.exchanges.lock().unwrap().unexpected_requests += 1;
                panic!("unexpected fixture endpoint");
            }
        };
        Ok(response)
    }
}

impl HttpTransport for Server {
    fn send(
        &self,
        request: Request<Bytes>,
        options: &SendOptions,
    ) -> impl std::future::Future<Output = Result<Response<Bytes>, TransportError>> + crate::rt::MaybeSend
    {
        self.exchange(request, options)
    }
}

impl OAuthIdentityResolver for Server {
    fn resolve_identity<'a>(
        &'a self,
        _: &'a petrel_core::AtIdentifier,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<OAuthIdentity, OAuthIdentityError>> {
        Box::pin(async move {
            if force_refresh {
                self.exchanges.lock().unwrap().did_refreshes += 1;
            }
            Ok(OAuthIdentity {
                did: DID.parse().unwrap(),
                handle: None,
                pds: Url::parse(PDS).unwrap(),
            })
        })
    }
}

struct FixtureAssertionKey(SoftwareDpopSigner);

impl AssertionSigner for FixtureAssertionKey {
    fn key_id(&self) -> &str {
        "fixture-key"
    }

    fn sign<'a>(&'a self, input: &'a [u8]) -> BoxFuture<'a, Result<[u8; 64], CryptoError>> {
        self.0.sign(input)
    }
}

fn json_response(status: u16, nonce: Option<&str>, body: Value) -> Response<Bytes> {
    let mut response = Response::builder()
        .status(status)
        .header(header::CONTENT_TYPE, "application/json; charset=utf-8");
    if let Some(nonce) = nonce {
        response = response.header("DPoP-Nonce", nonce);
    }
    response
        .body(Bytes::from(serde_json::to_vec(&body).unwrap()))
        .unwrap()
}

fn token_response(did: &str, rotation: &str, nonce: Option<&str>) -> Response<Bytes> {
    json_response(
        200,
        nonce,
        json!({
            "access_token": format!("access-{rotation}"),
            "refresh_token": format!("refresh-{rotation}"),
            "token_type": "DPoP",
            "expires_in": 300,
            "scope": SCOPE,
            "sub": did
        }),
    )
}

fn validate_proof(request: &Request<Bytes>) -> Value {
    let proof = split_compact_jws(request.headers()["dpop"].to_str().unwrap()).unwrap();
    let header: Value = serde_json::from_slice(&proof.header).unwrap();
    assert_eq!(header["alg"], "ES256");
    assert_eq!(header["typ"], "dpop+jwt");
    let key: Jwk = serde_json::from_value(header["jwk"].clone()).unwrap();
    key.verify_test_signature(proof.input.as_bytes(), &proof.signature)
        .unwrap();
    let claims: Value = serde_json::from_slice(&proof.claims).unwrap();
    assert_eq!(claims["htm"], request.method().as_str());
    assert_eq!(claims["htu"], request.uri().to_string());
    assert!(claims.get("ath").is_none());
    claims
}

fn client(server: &Arc<Server>, auth: ClientAuth) -> Arc<OAuthClient> {
    let storage = SessionStore::new(Arc::new(MemorySecretStore::new()), "fixtures").unwrap();
    let config = OAuthConfig::new(CLIENT, Url::parse(REDIRECT).unwrap(), SCOPE, auth).unwrap();
    Arc::new(OAuthClient::new(server.clone(), server.clone(), storage, config).unwrap())
}

async fn start(client: &OAuthClient) {
    let authorize = client
        .start_authorization(OAuthTarget::Identifier(DID.parse().unwrap()))
        .await
        .unwrap();
    assert_eq!(
        authorize.as_str().split('?').next(),
        Some("https://issuer.example/authorize")
    );
    let params: Vec<_> = authorize
        .query_pairs()
        .map(|(key, _)| key.into_owned())
        .collect();
    assert_eq!(params, ["client_id", "request_uri"]);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn flow_refreshes_once_for_fifty_concurrent_calls_and_scopes_auth() {
    let server = Arc::new(Server::new(Scenario::Public));
    let client = client(&server, ClientAuth::Public);
    start(&client).await;
    let callback = server.pushed_callback(ISSUER);
    let session = client.complete_authorization(&callback).await.unwrap();
    assert_eq!(session.access_token(), "access-first");
    assert_eq!(
        client.complete_authorization(&callback).await.unwrap_err(),
        OAuthError::UnknownState
    );
    let did = DID.parse().unwrap();
    let calls = join_all((0..50).map(|_| client.refresh(&did, true))).await;
    for call in calls {
        assert_eq!(call.unwrap().access_token(), "access-second");
    }
    let auth = client.session_auth(did);
    let first_party = Request::get(format!("{PDS}/xrpc/example"))
        .body(Bytes::new())
        .unwrap();
    let (first_party, info) = auth.prepare(first_party).await.unwrap();
    assert_eq!(
        first_party.headers()[header::AUTHORIZATION],
        "DPoP access-second"
    );
    assert!(info.jkt.is_some());
    let other_port = Request::get("https://pds.example:8443/xrpc/example")
        .body(Bytes::new())
        .unwrap();
    let (other_port, info) = auth.prepare(other_port).await.unwrap();
    assert!(other_port.headers().get(header::AUTHORIZATION).is_none());
    assert!(other_port.headers().get("dpop").is_none());
    assert_eq!(info, crate::xrpc::AuthCtx::default());

    let calls = server.exchanges.lock().unwrap();
    assert_eq!(calls.tokens, 1);
    assert_eq!(calls.did_refreshes, 1);
    assert_eq!(calls.refreshes, 1);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn metadata_bindings_and_callback_are_enforced_before_or_after_exchange() {
    for (scenario, issuer, expected, decodes) in [
        (
            Scenario::Public,
            "https://other.example",
            OAuthError::Callback,
            0,
        ),
        (
            Scenario::MissingExchangeNonce,
            ISSUER,
            OAuthError::MissingNonce,
            1,
        ),
        (
            Scenario::SubjectMismatch,
            ISSUER,
            OAuthError::IdentityChanged,
            1,
        ),
        (
            Scenario::WrongThumbprint,
            ISSUER,
            OAuthError::InvalidResponse,
            1,
        ),
        (
            Scenario::MalformedRefreshToken,
            ISSUER,
            OAuthError::InvalidResponse,
            1,
        ),
        (
            Scenario::TokenRedirect,
            ISSUER,
            OAuthProtocolError::Redirect.into(),
            1,
        ),
    ] {
        let server = Arc::new(Server::new(scenario));
        let client = client(&server, ClientAuth::Public);
        start(&client).await;
        let callback = server.pushed_callback(issuer);
        assert_eq!(
            client.complete_authorization(&callback).await.unwrap_err(),
            expected
        );
        assert!(
            client
                .session(&DID.parse().unwrap())
                .await
                .unwrap()
                .is_none()
        );
        assert_eq!(
            client.complete_authorization(&callback).await.unwrap_err(),
            OAuthError::UnknownState
        );
        let calls = server.exchanges.lock().unwrap();
        assert_eq!(calls.tokens, decodes);
        assert_eq!(calls.unexpected_requests, 0);
        if matches!(
            scenario,
            Scenario::MissingExchangeNonce | Scenario::SubjectMismatch | Scenario::WrongThumbprint
        ) {
            assert_eq!(calls.revokes, ["refresh-first"]);
        } else if matches!(scenario, Scenario::MalformedRefreshToken) {
            assert_eq!(calls.revokes, ["access-first"]);
        }
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn private_assertions_are_distinct_across_nonce_retry_and_exchange() {
    let server = Arc::new(Server::new(Scenario::AsNonce));
    let signer = SoftwareDpopSigner::generate().unwrap();
    let public_jwk = signer.public_jwk();
    let client = client(
        &server,
        ClientAuth::PrivateKeyJwt(Arc::new(FixtureAssertionKey(signer))),
    );
    start(&client).await;
    client
        .complete_authorization(&server.pushed_callback(ISSUER))
        .await
        .unwrap();
    let calls = server.exchanges.lock().unwrap();
    assert_eq!(calls.assertions.len(), 3);
    let mut seen = std::collections::HashSet::new();
    let key = Jwk::try_from(&public_jwk).unwrap();
    for assertion in &calls.assertions {
        let jws = split_compact_jws(assertion).unwrap();
        key.verify_test_signature(jws.input.as_bytes(), &jws.signature)
            .unwrap();
        let claims: Value = serde_json::from_slice(&jws.claims).unwrap();
        assert_eq!(claims["aud"], ISSUER);
        assert_eq!(claims["iss"], CLIENT);
        assert_eq!(claims["sub"], CLIENT);
        assert!(seen.insert(claims["jti"].as_str().unwrap().to_owned()));
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn cab_nonce_is_private_to_each_assertion_and_backend_client_id_must_match() {
    for scenario in [Scenario::CabNonce, Scenario::CabClientMismatch] {
        let server = Arc::new(Server::new(scenario));
        let auth = ClientAuth::Cab {
            backend_url: Url::parse(CAB).unwrap(),
            client_id: CLIENT.into(),
        };
        let client = client(&server, auth);
        if matches!(scenario, Scenario::CabNonce) {
            start(&client).await;
            client
                .complete_authorization(&server.pushed_callback(ISSUER))
                .await
                .unwrap();
            let calls = server.exchanges.lock().unwrap();
            assert_eq!(calls.cab.len(), 4);
            assert_eq!(
                calls.assertions,
                ["fixture-assertion-2", "fixture-assertion-4"]
            );
            assert!(calls.cab.iter().all(|(aud, _)| aud == ISSUER));
        } else {
            let result = client
                .start_authorization(OAuthTarget::Identifier(DID.parse().unwrap()))
                .await;
            assert_eq!(
                result.unwrap_err(),
                OAuthProtocolError::AssertionBackend(AssertionBackendError::ClientIdMismatch)
                    .into()
            );
            let calls = server.exchanges.lock().unwrap();
            assert_eq!(calls.cab.len(), 2);
            assert!(calls.par.is_empty());
        }
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn restart_promotes_only_the_pending_replacement_for_the_active_generation() {
    let server = Arc::new(Server::new(Scenario::Public));
    let client = client(&server, ClientAuth::Public);
    start(&client).await;
    client
        .complete_authorization(&server.pushed_callback(ISSUER))
        .await
        .unwrap();
    let did = DID.parse().unwrap();
    let config = OAuthConfig::new(
        CLIENT,
        Url::parse(REDIRECT).unwrap(),
        SCOPE,
        ClientAuth::Public,
    )
    .unwrap();
    let storage = client.storage.clone();
    let old = storage.get_session(&did).await.unwrap().unwrap();
    let replacement = super::SessionRecord {
        session: super::Session::new(
            did.clone(),
            "access-after-restart".into(),
            Some("refresh-after-restart".into()),
            old.session.created_at + 1,
            300,
            &petrel_oauth_scopes::ScopeSet::parse(SCOPE).unwrap(),
        ),
        ..old.clone()
    };
    let pending = PendingRefresh {
        based_on: old.generation(),
        record: replacement,
    };
    storage.save_pending_refresh(&pending).await.unwrap();

    let reopened =
        OAuthClient::new(server.clone(), server.clone(), storage.clone(), config).unwrap();
    let session = reopened.session(&did).await.unwrap().unwrap();
    assert_eq!(session.access_token(), "access-after-restart");
    assert!(storage.get_pending_refresh(&did).await.unwrap().is_none());

    // A delayed pending publication from the prior generation is ignored.
    storage.save_pending_refresh(&pending).await.unwrap();
    let session = reopened.session(&did).await.unwrap().unwrap();
    assert_eq!(session.access_token(), "access-after-restart");
    assert!(storage.get_pending_refresh(&did).await.unwrap().is_none());
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn late_old_token_rejection_does_not_rotate_the_current_session() {
    let server = Arc::new(Server::new(Scenario::Public));
    let client = client(&server, ClientAuth::Public);
    start(&client).await;
    client
        .complete_authorization(&server.pushed_callback(ISSUER))
        .await
        .unwrap();
    let did: petrel_core::Did = DID.parse().unwrap();
    let auth = client.session_auth(did.clone());
    let request = Request::get(format!("{PDS}/xrpc/example"))
        .body(Bytes::new())
        .unwrap();
    let (_, old_ctx) = auth.prepare(request).await.unwrap();
    client.refresh(&did, true).await.unwrap();
    let late = json_response(401, None, json!({"error": "ExpiredToken"}));
    assert_eq!(
        auth.handle_unauthorized(&late, &old_ctx).await.unwrap(),
        crate::xrpc::UnauthorizedAction::Retry
    );
    assert_eq!(server.exchanges.lock().unwrap().refreshes, 1);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn a_valid_refresh_response_can_keep_the_same_refresh_token() {
    let server = Arc::new(Server::new(Scenario::RetainedRefreshToken));
    let client = client(&server, ClientAuth::Public);
    start(&client).await;
    client
        .complete_authorization(&server.pushed_callback(ISSUER))
        .await
        .unwrap();
    let did = DID.parse().unwrap();
    for expected in ["access-rotation-1", "access-rotation-2"] {
        let refreshed = client.refresh(&did, true).await.unwrap();
        assert_eq!(refreshed.access_token(), expected);
        assert_eq!(refreshed.refresh_token(), Some("refresh-first"));
    }
    assert_eq!(server.exchanges.lock().unwrap().refreshes, 2);
}
