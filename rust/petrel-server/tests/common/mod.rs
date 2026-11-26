#![allow(dead_code, unreachable_pub)]

use std::collections::HashMap;
use std::sync::Arc;
use std::sync::atomic::{AtomicI64, AtomicU64, Ordering};

use petrel::rt::BoxFuture;
use petrel_server::clients::{
    OAuthApplicationType, OAuthClientKind, OAuthClientMetadata, OAuthResolvedClientMetadata,
    OAuthTokenEndpointAuthMethod, StaticOAuthClientResolver,
};
use petrel_server::http::{OAuthForm, OAuthHttpHeaders, OAuthHttpRequest, OAuthHttpResponse};
use petrel_server::jose::{
    OAuthCompactJwt, OAuthJsonWebKeySet, OAuthJwsAlgorithm, OAuthSigningKey,
};
use petrel_server::lexicon::{
    OAuthLexiconScopeResolution, PetrelOAuthScopeResolver, StaticOAuthLexiconResolver,
};
use petrel_server::oauth::config::OAuthAccessTokenFormat;
use petrel_server::oauth::interface::{
    DefaultOAuthHtmlRenderer, OAuthAccountAuthenticateRequest, OAuthAccountAuthenticating,
    OAuthAuthenticatedAccount,
};
use petrel_server::oauth::{OAuthAuthorizationServer, OAuthAuthorizationServerConfiguration};
use petrel_server::store::{InMemoryOAuthStore, OAuthGrantBinding, OAuthServerStores};
use petrel_server::support::{OAuthClock, OAuthPkce, OAuthRandomSource};
use serde::{Deserialize, Serialize};

pub const TEST_ISSUER: &str = "https://auth.example.com";
pub const WEB_CLIENT_ID: &str = "https://web.example.com/client.json";
pub const WEB_REDIRECT: &str = "https://web.example.com/callback";
pub const CONFIDENTIAL_CLIENT_ID: &str = "https://conf.example.com/client.json";
pub const CONFIDENTIAL_REDIRECT: &str = "https://conf.example.com/callback";
pub const LOOPBACK_CLIENT_ID: &str = "http://localhost";
pub const LOOPBACK_REDIRECT: &str = "http://127.0.0.1:8080/callback";

pub const ALICE_DID: &str = "did:plc:alice234567234567abcdefg";
pub const ALICE_HANDLE: &str = "alice.example.com";
pub const BOB_DID: &str = "did:plc:bobbb234567234567abcdefg";
pub const BOB_HANDLE: &str = "bob.example.com";

#[derive(Debug)]
pub struct TestClock {
    now: AtomicI64,
}

impl TestClock {
    pub fn new(initial_secs: i64) -> Self {
        Self {
            now: AtomicI64::new(initial_secs),
        }
    }

    pub fn advance(&self, delta_secs: i64) {
        self.now.fetch_add(delta_secs, Ordering::SeqCst);
    }

    pub fn set(&self, secs: i64) {
        self.now.store(secs, Ordering::SeqCst);
    }
}

impl OAuthClock for TestClock {
    fn now_secs(&self) -> i64 {
        self.now.load(Ordering::SeqCst)
    }

    #[allow(clippy::cast_precision_loss)]
    fn now_unix_f64(&self) -> f64 {
        self.now_secs() as f64
    }
}

#[derive(Debug, Default)]
pub struct TestRandom {
    counter: AtomicU64,
}

impl TestRandom {
    pub fn new() -> Self {
        Self::default()
    }
}

impl OAuthRandomSource for TestRandom {
    fn bytes(&self, count: usize) -> Vec<u8> {
        let seq = self.counter.fetch_add(1, Ordering::SeqCst).wrapping_add(1);
        let mut out = vec![0_u8; count];
        for (i, byte) in out.iter_mut().enumerate() {
            *byte = ((seq.wrapping_mul(31).wrapping_add(i as u64).wrapping_mul(17)) & 0xff) as u8;
        }
        out
    }
}

#[derive(Debug, Default)]
pub struct TestAccounts {
    accounts: HashMap<String, (String, String, Option<String>)>,
}

impl TestAccounts {
    pub fn with_alice_and_bob() -> Self {
        let mut accounts = HashMap::new();
        accounts.insert(
            ALICE_HANDLE.to_owned(),
            (
                "alice-password".to_owned(),
                ALICE_DID.to_owned(),
                Some(ALICE_HANDLE.to_owned()),
            ),
        );
        accounts.insert(
            ALICE_DID.to_owned(),
            (
                "alice-password".to_owned(),
                ALICE_DID.to_owned(),
                Some(ALICE_HANDLE.to_owned()),
            ),
        );
        accounts.insert(
            BOB_HANDLE.to_owned(),
            (
                "bob-password".to_owned(),
                BOB_DID.to_owned(),
                Some(BOB_HANDLE.to_owned()),
            ),
        );
        Self { accounts }
    }
}

impl OAuthAccountAuthenticating for TestAccounts {
    fn authenticate(
        &self,
        request: OAuthAccountAuthenticateRequest,
    ) -> BoxFuture<'_, Result<Option<OAuthAuthenticatedAccount>, petrel_server::OAuthServerError>>
    {
        Box::pin(async move {
            let ident = request
                .form_fields
                .get("identifier")
                .map_or("", String::as_str);
            let password = request
                .form_fields
                .get("password")
                .map_or("", String::as_str);
            Ok(self
                .accounts
                .get(ident)
                .and_then(|(expected_pw, did, handle)| {
                    if expected_pw == password {
                        Some(OAuthAuthenticatedAccount {
                            binding: OAuthGrantBinding::Subject { did: did.clone() },
                            handle: handle.clone(),
                        })
                    } else {
                        None
                    }
                }))
        })
    }
}

#[derive(Serialize)]
struct DpopProofClaims<'a> {
    jti: &'a str,
    htm: &'a str,
    htu: &'a str,
    iat: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    nonce: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    ath: Option<&'a str>,
}

pub fn make_dpop_proof(
    key: &OAuthSigningKey,
    method: &str,
    url: &str,
    nonce: Option<&str>,
    ath: Option<&str>,
    iat: i64,
    jti: &str,
) -> String {
    let claims = DpopProofClaims {
        jti,
        htm: method,
        htu: url,
        iat,
        nonce,
        ath,
    };
    OAuthCompactJwt::sign(&claims, key, Some("dpop+jwt"), true).expect("sign DPoP proof")
}

#[derive(Deserialize)]
pub struct TokenResponse {
    pub access_token: String,
    pub token_type: String,
    pub expires_in: i64,
    pub refresh_token: String,
    pub scope: String,
    pub sub: String,
}

#[derive(Deserialize)]
pub struct ParResponse {
    pub request_uri: String,
    pub expires_in: i64,
}

pub struct TestServer {
    pub issuer: String,
    pub clock: Arc<TestClock>,
    pub random: Arc<TestRandom>,
    pub store: Arc<InMemoryOAuthStore>,
    pub clients: Arc<StaticOAuthClientResolver>,
    pub lexicons: Arc<StaticOAuthLexiconResolver>,
    pub confidential_key: OAuthSigningKey,
    pub server: OAuthAuthorizationServer,
}

impl TestServer {
    pub async fn new(access_token_format: OAuthAccessTokenFormat) -> Self {
        Self::new_with_issuer(TEST_ISSUER, access_token_format).await
    }

    pub async fn new_with_issuer(
        issuer: &str,
        access_token_format: OAuthAccessTokenFormat,
    ) -> Self {
        let clock = Arc::new(TestClock::new(1_700_000_000));
        let random = Arc::new(TestRandom::new());
        let store = Arc::new(InMemoryOAuthStore::new());
        let clients = Arc::new(StaticOAuthClientResolver::new());
        let lexicons = Arc::new(StaticOAuthLexiconResolver::new());
        let confidential_key =
            OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("conf-1".to_owned()))
                .expect("generate conf key");

        clients
            .register(OAuthResolvedClientMetadata {
                kind: OAuthClientKind::Discoverable,
                metadata: OAuthClientMetadata {
                    client_id: WEB_CLIENT_ID.to_owned(),
                    client_name: Some("Web Example".to_owned()),
                    client_uri: None,
                    logo_uri: None,
                    tos_uri: None,
                    policy_uri: None,
                    application_type: OAuthApplicationType::Web,
                    grant_types: vec!["authorization_code".to_owned(), "refresh_token".to_owned()],
                    response_types: vec!["code".to_owned()],
                    redirect_uris: vec![WEB_REDIRECT.to_owned()],
                    scope: Some("atproto transition:generic".to_owned()),
                    token_endpoint_auth_method: OAuthTokenEndpointAuthMethod::None,
                    token_endpoint_auth_signing_alg: None,
                    dpop_bound_access_tokens: true,
                    jwks_uri: None,
                    jwks: None,
                },
                key_set: None,
            })
            .await;

        let conf_jwks =
            OAuthJsonWebKeySet::new(vec![confidential_key.public_jwk(true).expect("public jwk")]);
        clients
            .register(OAuthResolvedClientMetadata {
                kind: OAuthClientKind::Discoverable,
                metadata: OAuthClientMetadata {
                    client_id: CONFIDENTIAL_CLIENT_ID.to_owned(),
                    client_name: Some("Confidential Example".to_owned()),
                    client_uri: None,
                    logo_uri: None,
                    tos_uri: None,
                    policy_uri: None,
                    application_type: OAuthApplicationType::Web,
                    grant_types: vec!["authorization_code".to_owned(), "refresh_token".to_owned()],
                    response_types: vec!["code".to_owned()],
                    redirect_uris: vec![CONFIDENTIAL_REDIRECT.to_owned()],
                    scope: Some("atproto transition:generic".to_owned()),
                    token_endpoint_auth_method: OAuthTokenEndpointAuthMethod::PrivateKeyJwt,
                    token_endpoint_auth_signing_alg: Some("ES256".to_owned()),
                    dpop_bound_access_tokens: true,
                    jwks_uri: None,
                    jwks: Some(conf_jwks.clone()),
                },
                key_set: Some(conf_jwks),
            })
            .await;

        let mut cfg = OAuthAuthorizationServerConfiguration::with_testing_http_allowed(
            issuer,
            vec![7_u8; 32],
            issuer.starts_with("http://"),
        )
        .expect("config");
        let normalized_issuer = cfg.issuer.clone();
        cfg.access_token_format = access_token_format;
        let scope_resolver: Arc<dyn OAuthLexiconScopeResolution> =
            Arc::new(PetrelOAuthScopeResolver::new(lexicons.clone()));

        let server = OAuthAuthorizationServer::with_dependencies(
            cfg,
            OAuthServerStores::from_unified(store.clone()),
            Arc::new(TestAccounts::with_alice_and_bob()),
            clients.clone(),
            Some(scope_resolver),
            Arc::new(DefaultOAuthHtmlRenderer),
            clock.clone(),
            random.clone(),
        )
        .expect("build OAuth server");

        Self {
            issuer: normalized_issuer,
            clock,
            random,
            store,
            clients,
            lexicons,
            confidential_key,
            server,
        }
    }

    pub async fn get(&self, path: &str, query: Option<&str>) -> OAuthHttpResponse {
        let mut req = OAuthHttpRequest::new("GET", path);
        if let Some(q) = query {
            req = req.with_query(q);
        }
        self.server.handle(req).await
    }

    pub async fn post_form(
        &self,
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
        self.server
            .handle(
                OAuthHttpRequest::new("POST", path)
                    .with_headers(hdrs)
                    .with_body(body.into_bytes()),
            )
            .await
    }
}

pub struct TestClient<'a> {
    pub harness: &'a TestServer,
    pub client_id: String,
    pub redirect_uri: String,
    pub dpop_key: OAuthSigningKey,
    pub assertion_key: Option<OAuthSigningKey>,
    pub nonce: Option<String>,
    pub verifier: String,
    pub state: String,
    jti_seq: u64,
}

impl<'a> TestClient<'a> {
    pub fn web(harness: &'a TestServer) -> Self {
        Self {
            harness,
            client_id: WEB_CLIENT_ID.to_owned(),
            redirect_uri: WEB_REDIRECT.to_owned(),
            dpop_key: OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).expect("dpop key"),
            assertion_key: None,
            nonce: None,
            verifier: "test-verifier-0123456789012345678901234567890123456789-._~".to_owned(),
            state: "state-123".to_owned(),
            jti_seq: 0,
        }
    }

    pub fn confidential(harness: &'a TestServer) -> Self {
        Self {
            assertion_key: Some(harness.confidential_key.clone()),
            client_id: CONFIDENTIAL_CLIENT_ID.to_owned(),
            redirect_uri: CONFIDENTIAL_REDIRECT.to_owned(),
            ..Self::web(harness)
        }
    }

    pub fn challenge(&self) -> String {
        OAuthPkce::s256_challenge(&self.verifier)
    }

    fn next_jti(&mut self) -> String {
        self.jti_seq += 1;
        format!("jti-{}", self.jti_seq)
    }

    pub fn make_client_assertion(&mut self) -> String {
        #[derive(Serialize)]
        struct Claims<'c> {
            iss: &'c str,
            sub: &'c str,
            aud: &'c str,
            jti: String,
            iat: i64,
            exp: i64,
        }
        let key = self.assertion_key.as_ref().expect("assertion key").clone();
        let now = self.harness.clock.now_secs();
        let jti = self.next_jti();
        OAuthCompactJwt::sign(
            &Claims {
                iss: &self.client_id,
                sub: &self.client_id,
                aud: &self.harness.issuer,
                jti,
                iat: now,
                exp: now + 60,
            },
            &key,
            None,
            false,
        )
        .expect("sign assertion")
    }

    pub async fn send_post(
        &mut self,
        path: &str,
        base_fields: &[(&str, &str)],
    ) -> OAuthHttpResponse {
        for _ in 0..2 {
            let assertion = self
                .assertion_key
                .is_some()
                .then(|| self.make_client_assertion());
            let mut fields: Vec<(String, String)> =
                vec![("client_id".into(), self.client_id.clone())];
            if let Some(ref jwt) = assertion {
                fields.push((
                    "client_assertion_type".into(),
                    "urn:ietf:params:oauth:client-assertion-type:jwt-bearer".into(),
                ));
                fields.push(("client_assertion".into(), jwt.clone()));
            }
            for (k, v) in base_fields {
                fields.push(((*k).to_owned(), (*v).to_owned()));
            }
            let borrowed: Vec<(&str, &str)> = fields
                .iter()
                .map(|(k, v)| (k.as_str(), v.as_str()))
                .collect();
            let jti = self.next_jti();
            let url = url::Url::parse(&self.harness.issuer).map_or_else(
                |_| format!("{}{path}", self.harness.issuer),
                |parsed_issuer| {
                    let issuer_path = parsed_issuer.path().trim_end_matches('/');
                    if !issuer_path.is_empty() && path.starts_with(issuer_path) {
                        format!("{}{path}", parsed_issuer.origin().ascii_serialization())
                    } else {
                        format!("{}{path}", self.harness.issuer)
                    }
                },
            );
            let proof = make_dpop_proof(
                &self.dpop_key,
                "POST",
                &url,
                self.nonce.as_deref(),
                None,
                self.harness.clock.now_secs(),
                &jti,
            );
            let resp = self
                .harness
                .post_form(path, &borrowed, &[("DPoP", &proof)])
                .await;
            if let Some(fresh) = resp.headers.get("DPoP-Nonce") {
                self.nonce = Some(fresh.to_owned());
            }
            if resp.text().contains("\"use_dpop_nonce\"") {
                continue;
            }
            return resp;
        }
        panic!("server kept demanding DPoP nonce");
    }

    pub async fn push_request(&mut self, scope: &str) -> String {
        let challenge = self.challenge();
        let redirect = self.redirect_uri.clone();
        let state = self.state.clone();
        let resp = self
            .send_post(
                "/oauth/par",
                &[
                    ("response_type", "code"),
                    ("code_challenge", &challenge),
                    ("code_challenge_method", "S256"),
                    ("state", &state),
                    ("redirect_uri", &redirect),
                    ("scope", scope),
                ],
            )
            .await;
        assert_eq!(resp.status, 201, "PAR failed: {}", resp.text());
        let parsed: ParResponse = serde_json::from_slice(&resp.body).expect("PAR json");
        parsed.request_uri
    }

    pub async fn sign_in(
        &mut self,
        identifier: &str,
        password: &str,
        scope: &str,
    ) -> TokenResponse {
        let request_uri = self.push_request(scope).await;
        let query = format!(
            "client_id={}&request_uri={}",
            OAuthForm::encode_component(&self.client_id),
            OAuthForm::encode_component(&request_uri)
        );
        let page = self.harness.get("/oauth/authorize", Some(&query)).await;
        assert_eq!(page.status, 200, "authorize GET failed: {}", page.text());

        let cookie = page
            .headers
            .get("Set-Cookie")
            .and_then(|c| c.split(';').next())
            .expect("csrf cookie")
            .to_owned();
        let html = page.text();
        let flow_id = extract_hidden_input(&html, "flow_id");
        let csrf_token = extract_hidden_input(&html, "csrf_token");

        let consent_resp = self
            .harness
            .post_form(
                "/oauth/authorize",
                &[
                    ("flow_id", &flow_id),
                    ("csrf_token", &csrf_token),
                    ("identifier", identifier),
                    ("password", password),
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
        let parsed_loc = url::Url::parse(loc).expect("redirect url");
        let code = parsed_loc
            .query_pairs()
            .find(|(k, _)| k == "code")
            .map(|(_, v)| v.into_owned())
            .expect("code param");

        let verifier = self.verifier.clone();
        let redirect = self.redirect_uri.clone();
        let tok_resp = self
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
            tok_resp.status,
            200,
            "token exchange failed: {}",
            tok_resp.text()
        );
        serde_json::from_slice(&tok_resp.body).expect("token json")
    }
}

pub fn extract_hidden_input(html: &str, name: &str) -> String {
    let marker = format!("name=\"{name}\" value=\"");
    let start = html.find(&marker).expect("hidden input present") + marker.len();
    let rest = &html[start..];
    let end = rest.find('"').expect("closing quote");
    rest[..end].to_owned()
}
