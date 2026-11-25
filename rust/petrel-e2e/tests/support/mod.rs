use std::{
    future::{Future, ready},
    net::IpAddr,
    sync::{Arc, Mutex},
    time::{SystemTime, UNIX_EPOCH},
};

use bytes::Bytes;
use http::{Method, Request, Response, StatusCode, header};
use petrel::{
    crypto::{DpopSigner, SoftwareDpopSigner},
    identity::{
        DnsError, DnsResolver, HandleLookup, HandleStrategy, IdentityError, IdentityOptions,
        IdentityResolver,
    },
    net::{HttpTransport, ReqwestTransport, SendOptions, SharedTransport, TransportError},
    oauth::{
        ClientAuth, DpopKeyStore, OAuthClient, OAuthConfig, OAuthIdentityAdapter,
        OAuthIdentityResolver, OAuthTarget, Session, SessionRecord, dpop_proof,
    },
    rt::{BoxFuture, MaybeSend},
    storage::{MemorySecretStore, SessionStore, StoreError},
    xrpc::{CallOptions, XrpcClient},
};
use petrel_core::{
    Bytes as LexiconBytes, Did, Handle,
    xrpc::{UndeclaredError, XrpcMethod, XrpcRequest},
};
use petrel_e2e::{
    CAB_CLIENT_ID, CAB_REDIRECT, CabClient, CabServer, DEMO_DID, DEMO_HANDLE, DEMO_SCOPE,
    ExampleServer, FakePlc, ServerBins, headless_approve,
};
use serde_json::Value;
use url::{Origin, Url};

pub(super) const PUBLIC_CLIENT_ID: &str = concat!(
    "http://localhost?redirect_uri=http%3A%2F%2F127.0.0.1%2Fcallback",
    "&scope=atproto%20transition%3Ageneric",
);
const PUBLIC_REDIRECT: &str = "http://127.0.0.1:53124/callback";
pub(super) const SESSION_PATH: &str = "/xrpc/com.atproto.server.getSession";
pub(super) const TOKEN_PATH: &str = "/oauth/token";
pub(super) const CAB_PATH: &str = "/oauth/client-assertion";

pub(super) struct Fixture {
    issuer: ExampleServer,
    _plc: FakePlc,
    _cab: Option<CabServer>,
    pub(super) trace: Arc<ObservedTransport>,
    identity: Arc<dyn OAuthIdentityResolver>,
    config: OAuthConfig,
}

impl Fixture {
    pub(super) async fn public(bins: &ServerBins) -> Self {
        let issuer = ExampleServer::spawn(bins, &[])
            .await
            .expect("start Swift issuer");
        Self::assemble(issuer, None).await
    }

    pub(super) async fn confidential(
        bins: &ServerBins,
        require_nonce: bool,
        denied_jkts: &[&str],
    ) -> Self {
        let registration = CabClient::generate();
        let issuer = ExampleServer::spawn(bins, &[registration.metadata()])
            .await
            .expect("start Swift issuer with CAB client registration");
        let cab = registration
            .spawn(bins, issuer.origin(), require_nonce, denied_jkts)
            .await
            .expect("start Swift CAB");
        Self::assemble(issuer, Some(cab)).await
    }

    async fn assemble(issuer: ExampleServer, cab: Option<CabServer>) -> Self {
        let plc = FakePlc::start(DEMO_DID, issuer.origin())
            .await
            .expect("start synthetic PLC directory");
        let mut origins = vec![issuer.origin().origin(), plc.origin().origin()];
        let (client_id, redirect, auth) = match &cab {
            Some(cab) => {
                origins.push(cab.origin().origin());
                (
                    CAB_CLIENT_ID,
                    CAB_REDIRECT,
                    ClientAuth::Cab {
                        backend_url: cab.origin().clone(),
                        client_id: CAB_CLIENT_ID.to_owned(),
                    },
                )
            }
            None => (PUBLIC_CLIENT_ID, PUBLIC_REDIRECT, ClientAuth::Public),
        };
        let config = OAuthConfig::new(client_id, redirect.parse().unwrap(), DEMO_SCOPE, auth)
            .expect("configure fixture OAuth client")
            .with_loopback_development();
        let trace = Arc::new(ObservedTransport {
            native: ReqwestTransport::with_dns(NoDns).expect("create SDK HTTP transport"),
            origins,
            state: Mutex::default(),
        });
        let options = IdentityOptions {
            plc_directory: plc.origin().clone(),
            handle_strategy: HandleStrategy::Custom {
                lookup: Arc::new(DemoHandleLookup),
                fallback_to_direct: false,
            },
            allow_development_identifiers: true,
            ..IdentityOptions::default()
        };
        let resolver = IdentityResolver::new(trace.clone(), NoDns, options);
        Self {
            issuer,
            _plc: plc,
            _cab: cab,
            trace,
            identity: Arc::new(OAuthIdentityAdapter::new(resolver).with_loopback_development()),
            config,
        }
    }

    pub(super) fn client(&self, store: SessionStore) -> OAuthClient {
        let http: SharedTransport = self.trace.clone();
        OAuthClient::new(http, self.identity.clone(), store, self.config.clone())
            .expect("create SDK OAuth client")
    }

    pub(super) async fn sign_in(&self, client: &OAuthClient, client_id: &str) -> (Session, Url) {
        let authorize = client
            .start_authorization(demo_target())
            .await
            .expect("discover issuer and push authorization request");
        assert_eq!(authorize.origin(), self.issuer.origin().origin());
        assert_eq!(authorize.path(), "/oauth/authorize");
        let mut parameters = authorize.query_pairs().into_owned().collect::<Vec<_>>();
        parameters.sort_unstable();
        assert_eq!(parameters.len(), 2);
        assert_eq!(parameters[0].0, "client_id");
        assert_eq!(parameters[0].1, client_id);
        assert_eq!(parameters[1].0, "request_uri");
        assert!(
            parameters[1]
                .1
                .starts_with("urn:ietf:params:oauth:request_uri:")
        );

        let callback = headless_approve(self.issuer.origin(), &authorize)
            .await
            .expect("submit Swift sign-in and consent forms");
        let issuer = self.issuer.origin().origin().ascii_serialization();
        assert!(
            callback
                .query_pairs()
                .any(|(name, value)| name == "iss" && value == issuer)
        );
        assert_callback_value(&callback, "code");
        assert_callback_value(&callback, "state");
        let session = client
            .complete_authorization(&callback)
            .await
            .expect("exchange OAuth code");
        assert_eq!(session.did.as_str(), DEMO_DID);
        assert_eq!(session.scope(), DEMO_SCOPE);
        (session, callback)
    }

    pub(super) async fn get_session(&self, client: &Arc<OAuthClient>, did: &Did) {
        let http: SharedTransport = self.trace.clone();
        let xrpc = XrpcClient::new(self.issuer.origin().clone(), http)
            .expect("create SDK XRPC client")
            .with_auth_provider(Arc::new(client.session_auth(did.clone())));
        let mut options = CallOptions::default();
        options.transport.allow_loopback = true;
        let LexiconBytes(body) = xrpc
            .send::<GetSession>((), (), &options)
            .await
            .expect("read Swift getSession with the OAuth session");
        let session: Value = serde_json::from_slice(&body).expect("decode Swift getSession");
        assert_eq!(session["did"], DEMO_DID);
        assert_eq!(session["handle"], DEMO_HANDLE);
        assert_eq!(session["scope"], DEMO_SCOPE);
        assert_eq!(session["canPost"], true);
    }

    /// Present credentials issued by this local fixture after its client or
    /// session has changed. Use the SDK signer and one nonce retry.
    pub(super) async fn probe(
        &self,
        signer: &SoftwareDpopSigner,
        method: Method,
        path: &str,
        access_token: Option<&str>,
        form: Bytes,
    ) -> Response<Bytes> {
        let url = self.issuer.origin().join(path).unwrap();
        let mut nonce = None;
        let mut options = SendOptions::new();
        options.allow_loopback = true;
        for attempt in 0..2 {
            let dpop = dpop_proof(
                signer,
                &method,
                &url,
                unix_now(),
                access_token,
                nonce.as_deref(),
            )
            .await
            .expect("sign fixture request");
            let mut request = Request::builder()
                .method(&method)
                .uri(url.as_str())
                .header("DPoP", dpop);
            if let Some(token) = access_token {
                request = request.header(header::AUTHORIZATION, format!("DPoP {token}"));
            }
            if !form.is_empty() {
                request = request.header(header::CONTENT_TYPE, "application/x-www-form-urlencoded");
            }
            let request = request.body(form.clone()).expect("build fixture request");
            let response = self
                .trace
                .send(request, &options)
                .await
                .expect("send to local issuer");
            if attempt == 1 || error_code(response.body()).as_deref() != Some("use_dpop_nonce") {
                return response;
            }
            let value = response
                .headers()
                .get("DPoP-Nonce")
                .expect("Swift nonce challenge")
                .clone();
            // Own the rotating nonce between exchanges without keeping a response body.
            nonce = Some(value.to_str().expect("ASCII Swift nonce").to_owned());
        }
        unreachable!("the second exchange always returns");
    }
}

fn assert_callback_value(callback: &Url, field: &str) {
    let mut entries = callback.query_pairs().filter(|(name, _)| name == field);
    assert!(
        entries.next().is_some_and(|(_, value)| !value.is_empty()),
        "missing {field}"
    );
    assert!(entries.next().is_none(), "duplicate {field}");
}

pub(super) fn demo_target() -> OAuthTarget {
    OAuthTarget::Identifier(DEMO_DID.parse().expect("valid demo DID"))
}

pub(super) fn session_store() -> SessionStore {
    SessionStore::new(Arc::new(MemorySecretStore::new()), "petrel-rust-e2e")
        .expect("create isolated session store")
}

pub(super) async fn snapshot(
    store: &SessionStore,
    did: &Did,
) -> (SessionRecord, SoftwareDpopSigner) {
    let record = store
        .get_session(did)
        .await
        .unwrap()
        .expect("stored OAuth session");
    let key = store
        .get_dpop_key(&record.dpop_key_id)
        .await
        .unwrap()
        .expect("stored DPoP key");
    (
        record,
        SoftwareDpopSigner::from_bytes(&key).expect("valid stored P-256 key"),
    )
}

pub(super) async fn restore(record: &SessionRecord, signer: &SoftwareDpopSigner) -> SessionStore {
    let store = session_store();
    store
        .save_session(record)
        .await
        .expect("restore the saved fixture session");
    store
        .save_dpop_key(&record.dpop_key_id, &signer.to_bytes())
        .await
        .expect("restore the saved fixture key");
    store
}

#[derive(Clone, Copy)]
struct NoDns;

impl DnsResolver for NoDns {
    fn txt(&self, _name: &str) -> impl Future<Output = Result<Vec<String>, DnsError>> + MaybeSend {
        ready(Err(DnsError::Lookup(
            "external DNS disabled in the fixture".into(),
        )))
    }

    fn lookup_ip(
        &self,
        _host: &str,
    ) -> impl Future<Output = Result<Vec<IpAddr>, DnsError>> + MaybeSend {
        ready(Err(DnsError::Lookup(
            "external DNS disabled in the fixture".into(),
        )))
    }
}

struct DemoHandleLookup;

impl HandleLookup for DemoHandleLookup {
    fn lookup<'a>(
        &'a self,
        handle: &'a Handle,
    ) -> BoxFuture<'a, Result<Option<Did>, IdentityError>> {
        Box::pin(async move {
            Ok((handle.as_str() == DEMO_HANDLE).then(|| DEMO_DID.parse().expect("valid demo DID")))
        })
    }
}

/// The denied-key fixture needs to know its device thumbprint before starting CAB.
pub(super) struct DeniedKey(pub(super) Arc<SoftwareDpopSigner>);

impl DpopKeyStore for DeniedKey {
    fn create<'a>(
        &'a self,
        _id: &'a str,
    ) -> BoxFuture<'a, Result<Arc<dyn DpopSigner>, StoreError>> {
        Box::pin(async move { Ok(self.0.clone() as Arc<dyn DpopSigner>) })
    }

    fn get<'a>(
        &'a self,
        _id: &'a str,
    ) -> BoxFuture<'a, Result<Option<Arc<dyn DpopSigner>>, StoreError>> {
        Box::pin(async move { Ok(Some(self.0.clone() as Arc<dyn DpopSigner>)) })
    }

    fn delete<'a>(&'a self, _id: &'a str) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async { Ok(()) })
    }
}

struct GetSession;

impl XrpcRequest for GetSession {
    const NSID: &'static str = "com.atproto.server.getSession";
    const METHOD: XrpcMethod = XrpcMethod::Query;
    const INPUT_ENCODING: Option<&'static str> = None;
    const OUTPUT_ENCODING: Option<&'static str> = Some("application/json");
    type Params = ();
    type Input = ();
    type Output = LexiconBytes;
    type Error = UndeclaredError;
}

#[derive(Debug, PartialEq, Eq)]
pub(super) struct Exchange {
    pub(super) status: StatusCode,
    pub(super) error: Option<String>,
}

pub(super) struct ObservedTransport {
    native: ReqwestTransport,
    origins: Vec<Origin>,
    state: Mutex<TraceState>,
}

#[derive(Default)]
struct TraceState {
    requests: Vec<(String, StatusCode, Option<String>)>,
    stale_resource_key: Option<SoftwareDpopSigner>,
    save_token_form: bool,
    token_form: Option<Bytes>,
}

impl ObservedTransport {
    pub(super) fn requests(&self, path: &str) -> Vec<Exchange> {
        self.state
            .lock()
            .unwrap()
            .requests
            .iter()
            .filter(|(request_path, _, _)| request_path == path)
            .map(|(_, status, error)| Exchange {
                status: *status,
                error: error.clone(),
            })
            .collect()
    }

    pub(super) fn inject_stale_resource_nonce(&self, signer: SoftwareDpopSigner) {
        self.state.lock().unwrap().stale_resource_key = Some(signer);
    }

    pub(super) fn capture_code_exchange(&self) {
        self.state.lock().unwrap().save_token_form = true;
    }

    pub(super) fn exchanged_code_form(&self) -> Bytes {
        self.state
            .lock()
            .unwrap()
            .token_form
            .take()
            .expect("captured successful code exchange")
    }
}

impl HttpTransport for ObservedTransport {
    async fn send(
        &self,
        mut request: Request<Bytes>,
        options: &SendOptions,
    ) -> Result<Response<Bytes>, TransportError> {
        let url = Url::parse(&request.uri().to_string())
            .map_err(|_| TransportError::InvalidRequest("invalid fixture URL".into()))?;
        if !self.origins.contains(&url.origin()) {
            return Err(TransportError::PolicyViolation(
                "outside the synthetic fixture".into(),
            ));
        }
        let stale_key = (url.path() == SESSION_PATH)
            .then(|| self.state.lock().unwrap().stale_resource_key.take())
            .flatten();
        if let Some(signer) = stale_key {
            let token = request
                .headers()
                .get(header::AUTHORIZATION)
                .and_then(|value| value.to_str().ok())
                .and_then(|value| value.strip_prefix("DPoP "))
                .ok_or_else(|| {
                    TransportError::InvalidRequest(
                        "fixture request lacks DPoP authorization".into(),
                    )
                })?;
            let proof = dpop_proof(
                &signer,
                request.method(),
                &url,
                unix_now(),
                Some(token),
                Some("stale-fixture-nonce"),
            )
            .await
            .map_err(|_| {
                TransportError::InvalidRequest("could not sign the stale fixture proof".into())
            })?;
            request
                .headers_mut()
                .insert("DPoP", proof.parse().expect("ASCII DPoP proof"));
        }
        let capture_body = url.path() == TOKEN_PATH && self.state.lock().unwrap().save_token_form;
        let form = capture_body.then(|| request.body().clone());
        let response = self.native.send(request, options).await?;
        let mut state = self.state.lock().unwrap();
        if response.status().is_success() && form.is_some() {
            state.token_form = form;
            state.save_token_form = false;
        }
        state.requests.push((
            url.path().to_owned(),
            response.status(),
            (!response.status().is_success())
                .then(|| error_code(response.body()))
                .flatten(),
        ));
        Ok(response)
    }
}

pub(super) fn error_code(body: &[u8]) -> Option<String> {
    serde_json::from_slice::<Value>(body)
        .ok()?
        .get("error")?
        .as_str()
        .map(str::to_owned)
}

fn unix_now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("valid clock")
        .as_secs()
}
