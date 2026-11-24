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
const OTHER_DID: &str = "did:plc:zyxwvutsrqponmlkjihgfedc";
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
    revocation_attempts: usize,
    did_refreshes: usize,
    proof_jkts: Vec<String>,
    unexpected_requests: usize,
    service_requests: usize,
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
    TransientRefresh,
    RefreshAlwaysFails,
    InvalidGrant,
    OmitRefresh,
    LostAtproto,
    ReducedScope,
    MissingParNonce,
    RepeatedAsNonce,
    CabRepeatedNonce,
    CabDenied,
    PublicOnly,
    NoRevocationEndpoint,
    RevocationFailure,
    RevocationStaleNonce,
    ServiceTokenWrongIssuer,
    ServiceTokenBadExpiration,
    ServiceTokenRejected,
    PdsOriginChanged,
    PdsIssuerChanged,
    FrozenIssuerResourceMismatch,
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
        let calls = self.exchanges.lock().unwrap();
        let index = calls.par.len() - 1;
        let state = &calls.par[index]["state"];
        let mut callback = Url::parse(REDIRECT).unwrap();
        callback
            .query_pairs_mut()
            .append_pair("state", state)
            .append_pair("iss", issuer)
            .append_pair("code", &format!("fixture-code-{index}"));
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
        if uri.path() != "/xrpc/com.atproto.server.getServiceAuth" {
            assert!(request.headers().get(header::AUTHORIZATION).is_none());
        }
        let response = match (uri.host(), uri.path()) {
            (Some("pds.example"), "/.well-known/oauth-protected-resource") => {
                assert!(options.anonymous);
                let issuer = if matches!(self.scenario, Scenario::PdsIssuerChanged)
                    && self.exchanges.lock().unwrap().did_refreshes > 0
                {
                    "https://other-issuer.example"
                } else {
                    ISSUER
                };
                json_response(
                    200,
                    None,
                    &json!({"resource":PDS,"authorization_servers":[issuer]}),
                )
            }
            (Some("issuer.example"), "/.well-known/oauth-protected-resource") => {
                assert!(options.anonymous);
                json_response(404, None, &json!({}))
            }
            (Some("other-issuer.example"), "/.well-known/oauth-authorization-server") => {
                assert!(options.anonymous);
                json_response(
                    200,
                    None,
                    &serde_json::to_value(example_metadata("https://other-issuer.example"))
                        .unwrap(),
                )
            }
            (Some("issuer.example"), "/.well-known/oauth-authorization-server") => {
                assert!(options.anonymous);
                let mut metadata = example_metadata(ISSUER);
                if matches!(self.scenario, Scenario::PublicOnly) {
                    metadata.token_endpoint_auth_methods_supported = vec!["none".into()];
                }
                if matches!(self.scenario, Scenario::NoRevocationEndpoint) {
                    metadata.revocation_endpoint = None;
                }
                if matches!(self.scenario, Scenario::FrozenIssuerResourceMismatch)
                    && self.exchanges.lock().unwrap().did_refreshes == 0
                {
                    metadata.protected_resources =
                        Some(vec!["https://other-resource.example".into()]);
                }
                json_response(200, None, &serde_json::to_value(metadata).unwrap())
            }
            (Some("cab.example"), "/backend/oauth/client-assertion") => {
                self.cab_exchange(&request, &form)
            }
            (Some("issuer.example"), "/par") => self.par_exchange(&request, form),
            (Some("issuer.example"), "/token") => self.token_exchange(&request, &form).await,
            (Some("issuer.example"), "/revoke") => self.revoke_exchange(&request, &form),
            (Some("pds.example"), "/xrpc/com.atproto.server.getServiceAuth") => {
                self.service_auth_exchange(&request).await
            }
            _ => {
                self.exchanges.lock().unwrap().unexpected_requests += 1;
                panic!("unexpected fixture endpoint");
            }
        };
        Ok(response)
    }
    fn cab_exchange(
        &self,
        request: &Request<Bytes>,
        form: &HashMap<String, String>,
    ) -> Response<Bytes> {
        let proof = validate_proof(request);
        let mut calls = self.exchanges.lock().unwrap();
        let aud = form["aud"].clone();
        let challenged = calls.cab.len().is_multiple_of(2);
        calls.cab.push((aud, proof.clone()));
        if matches!(self.scenario, Scenario::CabDenied) {
            json_response(
                403,
                None,
                &json!({"error":"access_denied","error_description":"test refusal"}),
            )
        } else if challenged || matches!(self.scenario, Scenario::CabRepeatedNonce) {
            if challenged {
                assert!(proof.get("nonce").is_none());
            } else {
                assert_eq!(proof["nonce"], "cab-nonce");
            }
            json_response(400, Some("cab-nonce"), &json!({"error":"use_dpop_nonce"}))
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
                &json!({
                    "client_id": client,
                    "client_assertion": format!("fixture-assertion-{}", calls.cab.len())
                }),
            )
        }
    }

    fn par_exchange(
        &self,
        request: &Request<Bytes>,
        form: HashMap<String, String>,
    ) -> Response<Bytes> {
        let proof = validate_proof(request);
        assert_eq!(form["client_id"], CLIENT);
        assert_eq!(form["code_challenge_method"], "S256");
        if form["scope"] == SCOPE {
            assert!(
                std::str::from_utf8(request.body())
                    .unwrap()
                    .contains("%2523")
            );
        } else {
            assert_eq!(form["scope"], "atproto");
        }
        let mut calls = self.exchanges.lock().unwrap();
        if let Some(assertion) = form.get("client_assertion") {
            calls.assertions.push(assertion.clone());
        }
        calls.par.push(form);
        if matches!(self.scenario, Scenario::RepeatedAsNonce) {
            json_response(400, Some("fresh-nonce"), &json!({"error":"use_dpop_nonce"}))
        } else if matches!(self.scenario, Scenario::AsNonce) && calls.par.len() == 1 {
            assert!(proof.get("nonce").is_none());
            json_response(400, Some("fresh-nonce"), &json!({"error":"use_dpop_nonce"}))
        } else {
            if matches!(self.scenario, Scenario::AsNonce) {
                assert_eq!(proof["nonce"], "fresh-nonce");
            }
            let nonce =
                (!matches!(self.scenario, Scenario::MissingParNonce)).then_some("par-nonce");
            json_response(
                201,
                nonce,
                &json!({
                    "request_uri": format!("urn:example:fixture:{}", calls.par.len()),
                    "expires_in": 60
                }),
            )
        }
    }

    async fn token_exchange(
        &self,
        request: &Request<Bytes>,
        form: &HashMap<String, String>,
    ) -> Response<Bytes> {
        let proof = validate_proof(request);
        let grant = form["grant_type"].as_str();
        if grant == "authorization_code" {
            self.authorization_code_exchange(request, form, &proof)
        } else {
            assert_eq!(grant, "refresh_token");
            self.refresh_exchange(form, &proof).await
        }
    }

    fn authorization_code_exchange(
        &self,
        request: &Request<Bytes>,
        form: &HashMap<String, String>,
        proof: &Value,
    ) -> Response<Bytes> {
        assert_eq!(proof["nonce"], "par-nonce");
        let index: usize = form["code"]
            .strip_prefix("fixture-code-")
            .unwrap()
            .parse()
            .unwrap();
        let mut calls = self.exchanges.lock().unwrap();
        assert_eq!(
            crate::crypto::pkce_challenge(&form["code_verifier"]),
            calls.par[index]["code_challenge"]
        );
        calls.tokens += 1;
        if let Some(assertion) = form.get("client_assertion") {
            calls.assertions.push(assertion.clone());
        }
        let jws = split_compact_jws(request.headers()["dpop"].to_str().unwrap()).unwrap();
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
            Scenario::OmitRefresh => json_response(
                200,
                Some("token-nonce"),
                &json!({
                    "access_token": "access-only", "token_type": "DPoP", "scope": SCOPE, "sub": DID
                }),
            ),
            Scenario::SubjectMismatch => token_response(OTHER_DID, "first", Some("token-nonce")),
            Scenario::WrongThumbprint => json_response(
                200,
                Some("token-nonce"),
                &json!({
                    "access_token": "access-first", "refresh_token": "refresh-first",
                    "token_type":"DPoP", "scope":SCOPE, "sub":DID, "dpop_jkt":"unexpected"
                }),
            ),
            Scenario::MalformedRefreshToken => json_response(
                200,
                Some("token-nonce"),
                &json!({
                    "access_token": "access-first", "refresh_token": 12,
                    "token_type":"DPoP", "scope":SCOPE, "sub":DID
                }),
            ),
            _ => token_response(DID, "first", Some("token-nonce")),
        }
    }

    async fn refresh_exchange(
        &self,
        form: &HashMap<String, String>,
        proof: &Value,
    ) -> Response<Bytes> {
        assert_eq!(form["refresh_token"], "refresh-first");
        assert_eq!(proof["nonce"], "token-nonce");
        let count = {
            let mut exchanges = self.exchanges.lock().unwrap();
            exchanges.refreshes += 1;
            if let Some(assertion) = form.get("client_assertion") {
                exchanges.assertions.push(assertion.clone());
            }
            exchanges.refreshes
        };
        retry_delay(15).await;
        if matches!(self.scenario, Scenario::RetainedRefreshToken) {
            json_response(
                200,
                None,
                &json!({
                    "access_token": format!("access-rotation-{count}"),
                    "token_type":"DPoP", "scope":SCOPE, "sub":DID
                }),
            )
        } else {
            match self.scenario {
                Scenario::TransientRefresh if count == 1 => {
                    json_response(503, None, &json!({"error":"temporary"}))
                }
                Scenario::InvalidGrant => {
                    json_response(400, None, &json!({"error":"invalid_grant"}))
                }
                Scenario::LostAtproto => json_response(
                    200,
                    None,
                    &json!({
                        "access_token": "access-no-atproto", "refresh_token":"refresh-no-atproto",
                        "token_type": "DPoP", "scope": "transition:generic", "sub": DID
                    }),
                ),
                Scenario::ReducedScope => json_response(
                    200,
                    None,
                    &json!({
                        "access_token": "access-narrow", "refresh_token": "refresh-narrow",
                        "token_type": "DPoP", "scope": "atproto", "sub": DID
                    }),
                ),
                Scenario::RefreshAlwaysFails => {
                    json_response(503, None, &json!({"error":"temporary"}))
                }
                _ => token_response(DID, "second", None),
            }
        }
    }

    fn revoke_exchange(
        &self,
        request: &Request<Bytes>,
        form: &HashMap<String, String>,
    ) -> Response<Bytes> {
        let proof = validate_proof(request);
        let mut exchanges = self.exchanges.lock().unwrap();
        exchanges.revocation_attempts += 1;
        if let Some(assertion) = form.get("client_assertion") {
            exchanges.assertions.push(assertion.clone());
        }
        if matches!(self.scenario, Scenario::RevocationStaleNonce) {
            if exchanges.revocation_attempts == 1 {
                assert_eq!(proof["nonce"], "token-nonce");
                return json_response(
                    400,
                    Some("revocation-nonce"),
                    &json!({"error":"use_dpop_nonce"}),
                );
            }
            assert_eq!(proof["nonce"], "revocation-nonce");
        }
        if matches!(self.scenario, Scenario::RevocationFailure) {
            return json_response(503, None, &json!({"error":"temporarily_unavailable"}));
        }
        exchanges.revokes.push(form["token"].clone());
        json_response(200, None, &json!({}))
    }

    async fn service_auth_exchange(&self, request: &Request<Bytes>) -> Response<Bytes> {
        self.exchanges.lock().unwrap().service_requests += 1;
        assert_eq!(
            request.headers()[header::AUTHORIZATION],
            "DPoP access-first"
        );
        validate_proof(request);
        let mut params: HashMap<_, _> =
            url::form_urlencoded::parse(request.uri().query().unwrap().as_bytes())
                .into_owned()
                .collect();
        assert_eq!(
            params.remove("aud").as_deref(),
            Some("did:web:service.example#atproto_service")
        );
        assert_eq!(
            params.remove("lxm").as_deref(),
            Some("blue.example.service")
        );
        let exp = params.remove("exp").unwrap().parse::<u64>().unwrap();
        assert!(exp > super::protocol::unix_now().unwrap());
        match self.scenario {
            Scenario::ServiceTokenBadExpiration => {
                json_response(400, None, &json!({"error":"BadExpiration"}))
            }
            Scenario::ServiceTokenRejected => {
                json_response(418, None, &json!({"error":"UnknownFailure"}))
            }
            _ => {
                // The PDS owns this service signing key. The client is
                // responsible for inspecting the PDS response claims.
                let key = SoftwareDpopSigner::generate().unwrap();
                let issuer = if matches!(self.scenario, Scenario::ServiceTokenWrongIssuer) {
                    OTHER_DID
                } else {
                    DID
                };
                let input = crate::crypto::jws_signing_input(
                    &json!({"alg":"ES256","typ":"JWT"}),
                    &json!({
                        "iss":issuer,
                        "aud":"did:web:service.example",
                        "lxm":"blue.example.service",
                        "exp":exp
                    }),
                )
                .unwrap();
                let signature = key.sign(input.as_bytes()).await.unwrap();
                let token = crate::crypto::finish_es256_jws(input, &signature).unwrap();
                json_response(200, None, &json!({"token":token}))
            }
        }
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
            let pds = if force_refresh && matches!(self.scenario, Scenario::PdsOriginChanged) {
                "https://pds.example:8443"
            } else {
                PDS
            };
            Ok(OAuthIdentity {
                did: DID.parse().unwrap(),
                handle: None,
                pds: Url::parse(pds).unwrap(),
            })
        })
    }
}

struct FixtureAssertionKey(SoftwareDpopSigner);

impl AssertionSigner for FixtureAssertionKey {
    fn key_id(&self) -> &'static str {
        "fixture-key"
    }

    fn sign<'a>(&'a self, input: &'a [u8]) -> BoxFuture<'a, Result<[u8; 64], CryptoError>> {
        self.0.sign(input)
    }
}

fn json_response(status: u16, nonce: Option<&str>, body: &Value) -> Response<Bytes> {
    let mut response = Response::builder()
        .status(status)
        .header(header::CONTENT_TYPE, "application/json; charset=utf-8");
    if let Some(nonce) = nonce {
        response = response.header("DPoP-Nonce", nonce);
    }
    response
        .body(Bytes::from(serde_json::to_vec(body).unwrap()))
        .unwrap()
}

fn token_response(did: &str, rotation: &str, nonce: Option<&str>) -> Response<Bytes> {
    json_response(
        200,
        nonce,
        &json!({
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
    key.verify_signature(proof.input.as_bytes(), &proof.signature)
        .unwrap();
    let claims: Value = serde_json::from_slice(&proof.claims).unwrap();
    assert_eq!(claims["htm"], request.method().as_str());
    let url = Url::parse(&request.uri().to_string()).unwrap();
    assert_eq!(claims["htu"], super::dpop_target(&url).unwrap());
    if let Some(authorization) = request.headers().get(header::AUTHORIZATION) {
        let token = authorization
            .to_str()
            .unwrap()
            .strip_prefix("DPoP ")
            .unwrap();
        assert_eq!(
            claims["ath"],
            crate::crypto::base64url(&crate::crypto::sha256(token.as_bytes()))
        );
    } else {
        assert!(claims.get("ath").is_none());
    }
    claims
}

#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
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
    let session = client
        .complete_authorization(&server.pushed_callback(ISSUER))
        .await
        .unwrap();
    client.refresh(&session.did, true).await.unwrap();
    assert!(client.logout(&session.did).await.unwrap());
    let calls = server.exchanges.lock().unwrap();
    assert_eq!(calls.assertions.len(), 5);
    let mut seen = std::collections::HashSet::new();
    let key = Jwk::try_from(&public_jwk).unwrap();
    for assertion in &calls.assertions {
        let jws = split_compact_jws(assertion).unwrap();
        key.verify_signature(jws.input.as_bytes(), &jws.signature)
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
            assert_eq!(calls.par.len(), 0);
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
    let late = json_response(401, None, &json!({"error": "ExpiredToken"}));
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

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn scope_and_state_overrides_are_explicit_and_cancellable() {
    let server = Arc::new(Server::new(Scenario::Public));
    let client = client(&server, ClientAuth::Public);
    let target = OAuthTarget::Identifier(DID.parse().unwrap());
    let options = super::OAuthStartOptions {
        scope: Some("atproto"),
        state_prefix: Some("loopback.test"),
    };
    let first = client
        .start_authorization_with_options(target.clone(), options)
        .await
        .unwrap();
    assert!(first.state.starts_with("loopback.test."));
    {
        let calls = server.exchanges.lock().unwrap();
        assert_eq!(calls.par[0]["scope"], "atproto");
        assert_eq!(calls.par[0]["login_hint"], DID);
    }
    let callback = server.pushed_callback(ISSUER);
    assert!(client.cancel_authorization(&first.state).await.unwrap());
    assert!(!client.cancel_authorization(&first.state).await.unwrap());
    assert_eq!(
        client.complete_authorization(&callback).await.unwrap_err(),
        OAuthError::UnknownState
    );
    let second = client
        .start_authorization_with_options(target.clone(), options)
        .await
        .unwrap();
    assert_ne!(first.state, second.state);
    assert_ne!(first.authorize_url, second.authorize_url);
    let invalid = super::OAuthStartOptions {
        scope: Some("transition:generic"),
        ..options
    };
    assert_eq!(
        client
            .start_authorization_with_options(target, invalid)
            .await
            .unwrap_err(),
        OAuthError::Scope
    );

    let mut denial = Url::parse(REDIRECT).unwrap();
    denial
        .query_pairs_mut()
        .append_pair("state", &second.state)
        .append_pair("error", "access_denied");
    assert_eq!(
        client.complete_authorization(&denial).await.unwrap_err(),
        OAuthError::Cancelled
    );
    assert_eq!(
        client.complete_authorization(&denial).await.unwrap_err(),
        OAuthError::UnknownState
    );
    let calls = server.exchanges.lock().unwrap();
    assert_eq!(calls.tokens, 0);
    assert_ne!(
        calls.par[0]["code_challenge"],
        calls.par[1]["code_challenge"]
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn refresh_classifies_terminal_and_transient_failures() {
    for scenario in [
        Scenario::TransientRefresh,
        Scenario::InvalidGrant,
        Scenario::LostAtproto,
        Scenario::ReducedScope,
        Scenario::OmitRefresh,
    ] {
        let server = Arc::new(Server::new(scenario));
        let client = client(&server, ClientAuth::Public);
        start(&client).await;
        let session = client
            .complete_authorization(&server.pushed_callback(ISSUER))
            .await
            .unwrap();
        let did = &session.did;
        match scenario {
            Scenario::TransientRefresh => {
                assert_eq!(
                    client.refresh(did, true).await.unwrap_err(),
                    OAuthError::ServerStatus(503)
                );
                assert_eq!(
                    client.refresh(did, true).await.unwrap().access_token(),
                    "access-second"
                );
                assert_eq!(server.exchanges.lock().unwrap().refreshes, 2);
            }
            Scenario::InvalidGrant => {
                assert_eq!(
                    client.refresh(did, true).await.unwrap_err(),
                    OAuthError::InvalidGrant
                );
                assert_eq!(
                    client.refresh(did, true).await.unwrap_err(),
                    OAuthError::UsedRefreshToken
                );
                assert_eq!(server.exchanges.lock().unwrap().refreshes, 1);
            }
            Scenario::LostAtproto => {
                assert_eq!(
                    client.refresh(did, true).await.unwrap_err(),
                    OAuthError::InvalidResponse
                );
                assert_eq!(
                    server.exchanges.lock().unwrap().revokes,
                    ["refresh-no-atproto"]
                );
                assert_eq!(client.session(did).await.unwrap().unwrap().scope(), SCOPE);
            }
            Scenario::ReducedScope => {
                assert_eq!(session.scope(), SCOPE);
                assert_eq!(client.refresh(did, true).await.unwrap().scope(), "atproto");
                assert_eq!(
                    client.session(did).await.unwrap().unwrap().scope(),
                    "atproto"
                );
            }
            Scenario::OmitRefresh => {
                assert_eq!(session.expires_in, 300);
                assert!(session.refresh_token().is_none());
                assert_eq!(
                    client.refresh(did, false).await.unwrap().access_token(),
                    "access-only"
                );
                assert_eq!(
                    client.refresh(did, true).await.unwrap_err(),
                    OAuthError::ExpiredSession
                );
                assert_eq!(server.exchanges.lock().unwrap().refreshes, 0);
            }
            _ => unreachable!(),
        }
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn par_nonce_is_required_and_repeated_challenges_are_bounded() {
    for (scenario, error, expected_calls) in [
        (Scenario::MissingParNonce, OAuthError::MissingNonce, 1),
        (
            Scenario::RepeatedAsNonce,
            OAuthError::NonceRetryExhausted,
            2,
        ),
    ] {
        let server = Arc::new(Server::new(scenario));
        let client = client(&server, ClientAuth::Public);
        let target = OAuthTarget::Identifier(DID.parse().unwrap());
        assert_eq!(client.start_authorization(target).await.unwrap_err(), error);
        assert_eq!(server.exchanges.lock().unwrap().par.len(), expected_calls);
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn the_backend_is_not_called_for_unsupported_cab_and_reports_typed_refusals() {
    for (scenario, count) in [
        (Scenario::CabRepeatedNonce, 2),
        (Scenario::CabDenied, 1),
        (Scenario::PublicOnly, 0),
    ] {
        let server = Arc::new(Server::new(scenario));
        let auth = ClientAuth::Cab {
            backend_url: Url::parse(CAB).unwrap(),
            client_id: CLIENT.into(),
        };
        let client = client(&server, auth);
        let target = OAuthTarget::Identifier(DID.parse().unwrap());
        let error = client.start_authorization(target).await.unwrap_err();
        match scenario {
            Scenario::CabRepeatedNonce => assert_eq!(
                error,
                OAuthProtocolError::AssertionBackend(AssertionBackendError::Rejected {
                    status: 400,
                    code: Some(super::AssertionBackendErrorCode::UseDpopNonce)
                })
                .into()
            ),
            Scenario::CabDenied => assert_eq!(
                error,
                OAuthProtocolError::AssertionBackend(AssertionBackendError::Rejected {
                    status: 403,
                    code: Some(super::AssertionBackendErrorCode::AccessDenied)
                })
                .into()
            ),
            Scenario::PublicOnly => assert!(matches!(
                error,
                OAuthError::Metadata(super::MetadataError::MissingValue { .. })
            )),
            _ => unreachable!(),
        }
        let calls = server.exchanges.lock().unwrap();
        assert_eq!(calls.cab.len(), count);
        assert_eq!(calls.par.len(), 0);
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn logout_always_removes_session_and_key_and_reports_confirmed_revocation() {
    for (scenario, revoked, revoke_requests) in [
        (Scenario::Public, true, 1),
        (Scenario::NoRevocationEndpoint, false, 0),
        (Scenario::RevocationFailure, false, 1),
    ] {
        let server = Arc::new(Server::new(scenario));
        let client = client(&server, ClientAuth::Public);
        start(&client).await;
        let session = client
            .complete_authorization(&server.pushed_callback(ISSUER))
            .await
            .unwrap();
        let did = &session.did;
        let stored = client.storage.get_session(did).await.unwrap().unwrap();
        assert_eq!(client.logout(did).await.unwrap(), revoked);
        assert!(
            client
                .storage
                .get_dpop_key(&stored.dpop_key_id)
                .await
                .unwrap()
                .is_none()
        );
        assert!(client.session(did).await.unwrap().is_none());
        let calls = server.exchanges.lock().unwrap();
        assert_eq!(calls.revocation_attempts, revoke_requests);
        assert_eq!(calls.revokes.len(), usize::from(revoked));
        assert!(calls.revokes.iter().all(|token| token == "refresh-first"));
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn typed_service_auth_uses_the_session_did_and_generated_endpoint() {
    use crate::service_auth::ServiceAuthRequestError as Error;
    use petrel_api::generated::com::atproto::server::get_service_auth::Error as EndpointError;
    use std::time::Duration;

    for (scenario, expected) in [
        (Scenario::CabNonce, None),
        (
            Scenario::ServiceTokenWrongIssuer,
            Some(Error::UnexpectedClaims),
        ),
        (
            Scenario::ServiceTokenBadExpiration,
            Some(Error::Declared(EndpointError::BadExpiration)),
        ),
        (
            Scenario::ServiceTokenRejected,
            Some(Error::RequestFailed(418)),
        ),
    ] {
        let server = Arc::new(Server::new(scenario));
        let mode = if matches!(scenario, Scenario::CabNonce) {
            ClientAuth::Cab {
                backend_url: Url::parse(CAB).unwrap(),
                client_id: CLIENT.into(),
            }
        } else {
            ClientAuth::Public
        };
        let client = client(&server, mode);
        start(&client).await;
        let session = client
            .complete_authorization(&server.pushed_callback(ISSUER))
            .await
            .unwrap();
        let auth = client.session_auth(session.did.clone());
        let audience = "did:web:service.example#atproto_service".parse().unwrap();
        let method = "blue.example.service".parse().unwrap();

        let invalid = auth
            .get_service_auth(&audience, Some(&method), Some(Duration::ZERO))
            .await;
        assert_eq!(invalid.unwrap_err(), Error::InvalidRequest);
        assert_eq!(server.exchanges.lock().unwrap().service_requests, 0);

        let result = auth
            .get_service_auth(&audience, Some(&method), Some(Duration::from_secs(60)))
            .await;
        if let Some(expected) = expected {
            assert_eq!(result.unwrap_err(), expected);
        } else {
            let token = result.unwrap();
            assert_eq!(token.claims().issuer.did(), &session.did);
            assert_eq!(token.claims().audience.did(), audience.did());
            assert_eq!(token.claims().method.as_ref(), Some(&method));
            assert!(token.authorization_header_value().unwrap().is_sensitive());
        }
        assert_eq!(server.exchanges.lock().unwrap().service_requests, 1);
    }
}

#[derive(Default)]
struct FaultStore {
    inner: MemorySecretStore,
    fail_take: std::sync::atomic::AtomicBool,
    fail_primary_session_write: std::sync::atomic::AtomicBool,
    pause_pending_session_write: std::sync::atomic::AtomicBool,
    pending_write_started: std::sync::atomic::AtomicBool,
}

impl crate::storage::SecretStore for FaultStore {
    fn get<'a>(
        &'a self,
        ns: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, crate::storage::StoreError>> {
        self.inner.get(ns, key)
    }

    fn put<'a>(
        &'a self,
        ns: &'a str,
        key: &'a str,
        value: &'a [u8],
    ) -> BoxFuture<'a, Result<(), crate::storage::StoreError>> {
        use std::sync::atomic::Ordering;

        if key.starts_with("session.pending.")
            && self.pause_pending_session_write.load(Ordering::Relaxed)
        {
            self.pending_write_started.store(true, Ordering::Relaxed);
            return Box::pin(std::future::pending());
        }
        if key.starts_with("session.did:")
            && self.fail_primary_session_write.load(Ordering::Relaxed)
        {
            return Box::pin(async {
                Err(crate::storage::StoreError::Unavailable(
                    "injected primary write failure".into(),
                ))
            });
        }
        self.inner.put(ns, key, value)
    }

    fn delete<'a>(
        &'a self,
        ns: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<(), crate::storage::StoreError>> {
        self.inner.delete(ns, key)
    }

    fn take<'a>(
        &'a self,
        ns: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, crate::storage::StoreError>> {
        if self.fail_take.load(std::sync::atomic::Ordering::Relaxed) {
            return Box::pin(async {
                Err(crate::storage::StoreError::Unavailable(
                    "injected store failure".into(),
                ))
            });
        }
        self.inner.take(ns, key)
    }

    fn delete_namespace<'a>(
        &'a self,
        namespace: &'a str,
    ) -> BoxFuture<'a, Result<(), crate::storage::StoreError>> {
        self.inner.delete_namespace(namespace)
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn denied_local_flow_stays_denied_when_state_consumption_failed() {
    use crate::storage::SecretStore as _;
    use std::sync::atomic::Ordering;

    let server = Arc::new(Server::new(Scenario::Public));
    let backend = Arc::new(FaultStore::default());
    let storage = SessionStore::new(backend.clone(), "fixtures").unwrap();
    let config = OAuthConfig::new(
        CLIENT,
        Url::parse(REDIRECT).unwrap(),
        SCOPE,
        ClientAuth::Public,
    )
    .unwrap();
    let client = OAuthClient::new(server.clone(), server.clone(), storage, config).unwrap();
    let flow = client
        .start_authorization_with_options(
            OAuthTarget::Identifier(DID.parse().unwrap()),
            super::OAuthStartOptions::default(),
        )
        .await
        .unwrap();

    let mut denied = Url::parse(REDIRECT).unwrap();
    denied
        .query_pairs_mut()
        .append_pair("error", "access_denied")
        .append_pair("state", &flow.state);
    backend.fail_take.store(true, Ordering::Relaxed);
    assert_eq!(
        client.complete_authorization(&denied).await.unwrap_err(),
        OAuthError::Cancelled
    );
    backend.fail_take.store(false, Ordering::Relaxed);
    assert!(
        backend
            .get("fixtures", &format!("oauthState.{}", flow.state))
            .await
            .unwrap()
            .is_some()
    );
    assert_eq!(
        client
            .complete_authorization(&server.pushed_callback(ISSUER))
            .await
            .unwrap_err(),
        OAuthError::UnknownState
    );
    assert_eq!(server.exchanges.lock().unwrap().tokens, 0);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn final_identity_binding_rejects_pds_port_issuer_or_resource_changes() {
    for (scenario, server_first, expected) in [
        (
            Scenario::PdsOriginChanged,
            false,
            OAuthError::IdentityChanged,
        ),
        (
            Scenario::PdsIssuerChanged,
            false,
            OAuthError::IdentityChanged,
        ),
        (
            Scenario::PdsIssuerChanged,
            true,
            OAuthError::IdentityChanged,
        ),
        (
            Scenario::FrozenIssuerResourceMismatch,
            true,
            OAuthError::Metadata(super::MetadataError::ResourceNotProtected),
        ),
    ] {
        let server = Arc::new(Server::new(scenario));
        let client = client(&server, ClientAuth::Public);
        let target = if server_first {
            OAuthTarget::Server(Url::parse(ISSUER).unwrap())
        } else {
            OAuthTarget::Identifier(DID.parse().unwrap())
        };
        client.start_authorization(target).await.unwrap();
        assert_eq!(
            client
                .complete_authorization(&server.pushed_callback(ISSUER))
                .await
                .unwrap_err(),
            expected
        );
        assert!(
            client
                .session(&DID.parse().unwrap())
                .await
                .unwrap()
                .is_none()
        );
        let exchanges = server.exchanges.lock().unwrap();
        assert_eq!(exchanges.did_refreshes, 1);
        assert_eq!(exchanges.tokens, 1);
        assert_eq!(exchanges.revokes, ["refresh-first"]);
        assert_eq!(exchanges.par[0].contains_key("login_hint"), !server_first);
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn resource_and_authorization_nonces_are_separate_even_on_one_origin() {
    let server = Arc::new(Server::new(Scenario::Public));
    let client = client(&server, ClientAuth::Public);
    start(&client).await;
    client
        .complete_authorization(&server.pushed_callback(ISSUER))
        .await
        .unwrap();
    let did = DID.parse().unwrap();
    let record = client.storage.get_session(&did).await.unwrap().unwrap();
    let resource = Url::parse(&format!("{PDS}/xrpc/example")).unwrap();
    client
        .protocol
        .nonces
        .put(&record.dpop_jkt, &resource, "as-only-nonce")
        .unwrap();
    let auth = client.session_auth(did);
    let make_request = || Request::get(resource.as_str()).body(Bytes::new()).unwrap();
    let (request, ctx) = auth.prepare(make_request()).await.unwrap();
    let proof = validate_proof(&request);
    assert!(proof.get("nonce").is_none());

    auth.update_dpop_nonce(PDS, "resource-only-nonce", &ctx)
        .await;
    let (request, _) = auth.prepare(make_request()).await.unwrap();
    let proof = validate_proof(&request);
    assert_eq!(proof["nonce"], "resource-only-nonce");
    assert_eq!(
        client
            .protocol
            .nonces
            .get(&record.dpop_jkt, &resource)
            .as_deref(),
        Some("as-only-nonce")
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn cab_revocation_retries_with_a_fresh_assertion_and_proof() {
    let server = Arc::new(Server::new(Scenario::RevocationStaleNonce));
    let client = client(
        &server,
        ClientAuth::Cab {
            backend_url: Url::parse(CAB).unwrap(),
            client_id: CLIENT.into(),
        },
    );
    start(&client).await;
    let session = client
        .complete_authorization(&server.pushed_callback(ISSUER))
        .await
        .unwrap();
    assert!(client.revoke_session(&session.did).await.unwrap());
    assert!(client.session(&session.did).await.unwrap().is_some());

    let calls = server.exchanges.lock().unwrap();
    assert_eq!(calls.revocation_attempts, 2);
    assert_eq!(calls.revokes, ["refresh-first"]);
    assert_eq!(
        calls.assertions,
        [
            "fixture-assertion-2",
            "fixture-assertion-4",
            "fixture-assertion-6",
            "fixture-assertion-8"
        ]
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn cancelled_refresh_does_not_lose_the_received_token_replacement() {
    use std::{
        future::{Future, poll_fn},
        sync::atomic::Ordering,
        task::Poll,
    };

    let server = Arc::new(Server::new(Scenario::Public));
    let backend = Arc::new(FaultStore::default());
    let storage = SessionStore::new(backend.clone(), "fixtures").unwrap();
    let config = OAuthConfig::new(
        CLIENT,
        Url::parse(REDIRECT).unwrap(),
        SCOPE,
        ClientAuth::Public,
    )
    .unwrap();
    let client = OAuthClient::new(server.clone(), server.clone(), storage.clone(), config).unwrap();
    start(&client).await;
    let session = client
        .complete_authorization(&server.pushed_callback(ISSUER))
        .await
        .unwrap();
    backend
        .pause_pending_session_write
        .store(true, Ordering::Relaxed);
    let mut refresh = Box::pin(client.refresh(&session.did, true));
    poll_fn(|cx| {
        assert!(refresh.as_mut().poll(cx).is_pending());
        if backend.pending_write_started.load(Ordering::Relaxed) {
            Poll::Ready(())
        } else {
            Poll::Pending
        }
    })
    .await;
    drop(refresh);
    backend
        .pause_pending_session_write
        .store(false, Ordering::Relaxed);

    let recovered = client.session(&session.did).await.unwrap().unwrap();
    assert_eq!(recovered.access_token(), "access-second");
    assert_eq!(
        storage
            .get_session(&session.did)
            .await
            .unwrap()
            .unwrap()
            .session
            .access_token(),
        "access-second"
    );
    assert_eq!(server.exchanges.lock().unwrap().refreshes, 1);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn durable_pending_refresh_survives_a_new_client_after_primary_write_failure() {
    use std::sync::atomic::Ordering;

    let server = Arc::new(Server::new(Scenario::Public));
    let backend = Arc::new(FaultStore::default());
    let storage = SessionStore::new(backend.clone(), "fixtures").unwrap();
    let config = OAuthConfig::new(
        CLIENT,
        Url::parse(REDIRECT).unwrap(),
        SCOPE,
        ClientAuth::Public,
    )
    .unwrap();
    let client = OAuthClient::new(
        server.clone(),
        server.clone(),
        storage.clone(),
        config.clone(),
    )
    .unwrap();
    start(&client).await;
    let session = client
        .complete_authorization(&server.pushed_callback(ISSUER))
        .await
        .unwrap();
    backend
        .fail_primary_session_write
        .store(true, Ordering::Relaxed);
    assert_eq!(
        client
            .refresh(&session.did, true)
            .await
            .unwrap()
            .access_token(),
        "access-second"
    );
    assert_eq!(
        storage
            .get_session(&session.did)
            .await
            .unwrap()
            .unwrap()
            .session
            .access_token(),
        "access-first"
    );
    assert!(
        storage
            .get_pending_refresh(&session.did)
            .await
            .unwrap()
            .is_some()
    );

    drop(client);
    backend
        .fail_primary_session_write
        .store(false, Ordering::Relaxed);
    let reopened = OAuthClient::new(server.clone(), server.clone(), storage, config).unwrap();
    assert_eq!(
        reopened
            .session(&session.did)
            .await
            .unwrap()
            .unwrap()
            .access_token(),
        "access-second"
    );
    assert_eq!(server.exchanges.lock().unwrap().refreshes, 1);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn callback_requires_issuer_code_and_exact_redirect_before_any_exchange() {
    let cases = [
        ("missing issuer", OAuthError::Callback),
        ("missing code", OAuthError::Callback),
        ("wrong host", OAuthError::RedirectUri),
        ("wrong port", OAuthError::RedirectUri),
        ("wrong path", OAuthError::RedirectUri),
    ];
    for (case, expected) in cases {
        let server = Arc::new(Server::new(Scenario::Public));
        let client = client(&server, ClientAuth::Public);
        start(&client).await;
        let good = server.pushed_callback(ISSUER);
        let mut bad = good.clone();
        match case {
            "missing issuer" | "missing code" => {
                let removed = if case == "missing issuer" {
                    "iss"
                } else {
                    "code"
                };
                let pairs: Vec<_> = good
                    .query_pairs()
                    .filter(|(name, _)| name != removed)
                    .collect();
                bad.query_pairs_mut().clear().extend_pairs(pairs);
            }
            "wrong host" => bad.set_host(Some("other.example")).unwrap(),
            "wrong port" => bad.set_port(Some(8443)).unwrap(),
            "wrong path" => bad.set_path("/other"),
            _ => unreachable!(),
        }
        assert_eq!(
            client.complete_authorization(&bad).await.unwrap_err(),
            expected,
            "{case}"
        );
        assert_eq!(
            client.complete_authorization(&good).await.unwrap_err(),
            OAuthError::UnknownState
        );
        assert_eq!(server.exchanges.lock().unwrap().tokens, 0);
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn callback_revalidates_the_saved_issuer_and_dpop_binding() {
    for key_mismatch in [false, true] {
        let server = Arc::new(Server::new(Scenario::Public));
        let client = client(&server, ClientAuth::Public);
        let flow = client
            .start_authorization_with_options(
                OAuthTarget::Identifier(DID.parse().unwrap()),
                super::OAuthStartOptions::default(),
            )
            .await
            .unwrap();
        let now = super::protocol::unix_now().unwrap();
        let mut state = client
            .storage
            .consume_oauth_state::<super::models::OAuthFlowState>(&flow.state, now)
            .await
            .unwrap()
            .unwrap();
        let expected = if key_mismatch {
            state.dpop_jkt = "unexpected-key".into();
            OAuthError::KeyBinding
        } else {
            state.metadata.issuer = "https://other-issuer.example".into();
            OAuthError::Metadata(super::MetadataError::IssuerMismatch)
        };
        client
            .storage
            .save_oauth_state(&flow.state, now, &state)
            .await
            .unwrap();

        assert_eq!(
            client
                .complete_authorization(&server.pushed_callback(ISSUER))
                .await
                .unwrap_err(),
            expected
        );
        assert_eq!(server.exchanges.lock().unwrap().tokens, 0);
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn malformed_client_assertion_signature_is_rejected_before_par() {
    struct InvalidSigningOutput;

    impl AssertionSigner for InvalidSigningOutput {
        fn key_id(&self) -> &'static str {
            "fixture-invalid-key"
        }
        fn sign<'a>(&'a self, _: &'a [u8]) -> BoxFuture<'a, Result<[u8; 64], CryptoError>> {
            Box::pin(std::future::ready(Ok([0; 64])))
        }
    }

    let server = Arc::new(Server::new(Scenario::Public));
    let client = client(
        &server,
        ClientAuth::PrivateKeyJwt(Arc::new(InvalidSigningOutput)),
    );
    let result = client
        .start_authorization(OAuthTarget::Identifier(DID.parse().unwrap()))
        .await;
    assert_eq!(
        result.unwrap_err(),
        OAuthProtocolError::Crypto(CryptoError::InvalidSignature).into()
    );
    assert_eq!(server.exchanges.lock().unwrap().par.len(), 0);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn elapsed_refresh_backoff_admits_only_one_probe() {
    let server = Arc::new(Server::new(Scenario::RefreshAlwaysFails));
    let client = client(&server, ClientAuth::Public);
    start(&client).await;
    let session = client
        .complete_authorization(&server.pushed_callback(ISSUER))
        .await
        .unwrap();
    let did = &session.did;
    for _ in 0..3 {
        assert_eq!(
            client.refresh(did, true).await.unwrap_err(),
            OAuthError::ServerStatus(503)
        );
    }
    assert_eq!(
        client.refresh(did, true).await.unwrap_err(),
        OAuthError::RefreshBackoff
    );
    assert_eq!(server.exchanges.lock().unwrap().refreshes, 3);

    client.allow_next_refresh_probe(did).await;
    let attempts = join_all((0..50).map(|_| client.refresh(did, true))).await;
    let probes = attempts
        .iter()
        .filter(|attempt| matches!(attempt, Err(OAuthError::ServerStatus(503))))
        .count();
    let deferred = attempts
        .iter()
        .filter(|attempt| matches!(attempt, Err(OAuthError::RefreshBackoff)))
        .count();
    assert_eq!(probes, 1);
    assert_eq!(deferred, 49);
    assert_eq!(server.exchanges.lock().unwrap().refreshes, 4);
}
