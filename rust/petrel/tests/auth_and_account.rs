#![cfg(not(target_arch = "wasm32"))]

use std::{
    collections::{HashMap, HashSet},
    sync::{Arc, Mutex},
    time::Duration,
};

use base64::{Engine, engine::general_purpose::URL_SAFE_NO_PAD};
use bytes::Bytes;
use http::{Request, Response, StatusCode};
use petrel::{
    account::{AccountManager, AccountSwitchCoordinator, AccountSwitchError},
    auth::{
        AccountStatus, AccountStatusError, AccountStatusReason, AuthContinuityState,
        AuthContinuityTransactionResult, AuthFactorTokenRequiredError, AuthMode,
        GatewayAuthIdentity, LegacyPasswordStrategy, PasswordAuthError, RefreshCircuitBreaker,
        RefreshFailureKind, TokenRefreshResult,
    },
    client::AtProtoClient,
    net::{HttpTransport, SendOptions, TransportError},
    oauth::{Account, OAuthIdentity, OAuthIdentityError, OAuthIdentityResolver},
    rt::BoxFuture,
    storage::{MemorySecretStore, SessionStore},
    xrpc::{AuthCtx, AuthProvider, CallOptions, UnauthorizedAction, XrpcLabeler},
};
use petrel_core::{AtIdentifier, Did, Handle};
use url::Url;

const ALICE_DID: &str = "did:plc:passwordalice";
const ALICE_HANDLE: &str = "alice.test";
const ALICE_EMAIL: &str = "alice@example.com";
const ALICE_PASSWORD: &str = "app-password";
const AUTH_FACTOR_CODE: &str = "ABCDE-12345";

struct FakeResolver {
    records: Mutex<HashMap<String, (Did, Handle, Url)>>,
}

impl FakeResolver {
    fn new() -> Self {
        Self {
            records: Mutex::new(HashMap::new()),
        }
    }

    fn register(&self, did: &str, handle: &str, pds: &Url) {
        let mut guard = self.records.lock().unwrap();
        let entry = (
            did.parse::<Did>().unwrap(),
            handle.parse::<Handle>().unwrap(),
            pds.clone(),
        );
        guard.insert(did.to_owned(), entry.clone());
        guard.insert(handle.to_owned(), entry);
    }
}

impl OAuthIdentityResolver for FakeResolver {
    fn resolve_identity<'a>(
        &'a self,
        identifier: &'a AtIdentifier,
        _force_refresh: bool,
    ) -> BoxFuture<'a, Result<OAuthIdentity, OAuthIdentityError>> {
        let key = identifier.as_str().to_owned();
        let found = self.records.lock().unwrap().get(&key).cloned();
        Box::pin(async move {
            let (did, handle, pds) = found.ok_or(OAuthIdentityError)?;
            Ok(OAuthIdentity {
                did,
                handle: Some(handle),
                pds,
            })
        })
    }
}

#[derive(Clone)]
struct FakeAccount {
    did: String,
    handle: String,
    email: String,
    password: String,
    active: bool,
    status: Option<String>,
    requires_auth_factor: bool,
}

#[derive(Clone)]
struct RecordedCall {
    path: String,
    auth: Option<String>,
    dpop: Option<String>,
    body: serde_json::Value,
    status: u16,
}

struct FakePdsState {
    origin: String,
    accounts: HashMap<String, FakeAccount>,
    access_tokens: HashMap<String, String>,
    expired_access_tokens: HashSet<String>,
    refresh_tokens: HashMap<String, String>,
    recorded: Vec<RecordedCall>,
    create_session_did_override: Option<String>,
    forced_status: HashMap<String, u16>,
    refresh_delay_ms: u64,
    access_lifetime_secs: u64,
    counter: u64,
}

impl FakePdsState {
    fn new(origin: &str) -> Self {
        Self {
            origin: origin.to_owned(),
            accounts: HashMap::new(),
            access_tokens: HashMap::new(),
            expired_access_tokens: HashSet::new(),
            refresh_tokens: HashMap::new(),
            recorded: Vec::new(),
            create_session_did_override: None,
            forced_status: HashMap::new(),
            refresh_delay_ms: 0,
            access_lifetime_secs: 7200,
            counter: 0,
        }
    }

    fn issue_jwt(&mut self, sub: &str, lifetime: u64) -> String {
        self.counter += 1;
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        let header = URL_SAFE_NO_PAD.encode(br#"{"alg":"HS256","typ":"JWT"}"#);
        let payload = URL_SAFE_NO_PAD.encode(
            serde_json::to_vec(&serde_json::json!({
                "sub": sub,
                "iat": now,
                "exp": now + lifetime,
                "jti": self.counter,
            }))
            .unwrap(),
        );
        format!("{header}.{payload}.sig")
    }
}

struct FakePdsNetwork {
    servers: Mutex<HashMap<String, FakePdsState>>,
}

impl FakePdsNetwork {
    fn new(states: Vec<FakePdsState>) -> Self {
        let mut map = HashMap::new();
        for state in states {
            map.insert(state.origin.clone(), state);
        }
        Self {
            servers: Mutex::new(map),
        }
    }

    fn calls(&self, origin: &str, suffix: &str) -> Vec<RecordedCall> {
        self.servers.lock().unwrap()[origin]
            .recorded
            .iter()
            .filter(|call| call.path.ends_with(suffix))
            .cloned()
            .collect()
    }

    fn live_session_count(&self, origin: &str) -> usize {
        self.servers.lock().unwrap()[origin].refresh_tokens.len()
    }

    fn set_status(&self, origin: &str, did: &str, active: bool, status: Option<&str>) {
        let mut servers = self.servers.lock().unwrap();
        let acct = servers
            .get_mut(origin)
            .unwrap()
            .accounts
            .get_mut(did)
            .unwrap();
        acct.active = active;
        acct.status = status.map(str::to_owned);
    }

    fn set_forced_status(&self, origin: &str, method: Option<(&str, u16)>) {
        let mut servers = self.servers.lock().unwrap();
        let server = servers.get_mut(origin).unwrap();
        server.forced_status.clear();
        if let Some((m, code)) = method {
            server.forced_status.insert(m.to_owned(), code);
        }
    }

    fn set_refresh_delay_ms(&self, origin: &str, delay_ms: u64) {
        self.servers
            .lock()
            .unwrap()
            .get_mut(origin)
            .unwrap()
            .refresh_delay_ms = delay_ms;
    }

    fn expire_all_access_tokens(&self, origin: &str) {
        let mut servers = self.servers.lock().unwrap();
        let server = servers.get_mut(origin).unwrap();
        let tokens: Vec<String> = server.access_tokens.keys().cloned().collect();
        server.expired_access_tokens.extend(tokens);
    }
}

impl FakePdsState {
    fn handle_create_session(&mut self, body: &serde_json::Value) -> (u16, serde_json::Value) {
        let id = body["identifier"].as_str().unwrap_or("");
        let pw = body["password"].as_str().unwrap_or("");
        let token = body.get("authFactorToken").and_then(|v| v.as_str());
        let matched = self
            .accounts
            .values()
            .find(|a| a.did == id || a.handle == id || a.email == id)
            .cloned();
        let Some(acct) = matched.filter(|a| a.password == pw) else {
            return (
                401,
                serde_json::json!({"error": "AuthenticationRequired", "message": "Invalid identifier or password"}),
            );
        };
        if acct.requires_auth_factor && token.is_none() {
            return (401, serde_json::json!({"error": "AuthFactorTokenRequired"}));
        }
        if acct.requires_auth_factor && token != Some(AUTH_FACTOR_CODE) {
            return (
                401,
                serde_json::json!({"error": "AuthenticationRequired", "message": "bad token"}),
            );
        }
        if let Some(err) = account_status_error(acct.status.as_deref()) {
            return err;
        }
        let did = self
            .create_session_did_override
            .clone()
            .unwrap_or_else(|| acct.did.clone());
        let lifetime = self.access_lifetime_secs;
        let access = self.issue_jwt(&did, lifetime);
        let refresh = self.issue_jwt(&did, 86_400);
        self.access_tokens.insert(access.clone(), did.clone());
        self.refresh_tokens.insert(refresh.clone(), did.clone());
        (
            200,
            serde_json::json!({
                "accessJwt": access,
                "refreshJwt": refresh,
                "handle": acct.handle,
                "did": did,
                "active": acct.active,
                "status": acct.status,
            }),
        )
    }

    fn handle_refresh_session(&mut self, bearer: Option<&str>) -> (u16, serde_json::Value) {
        let maybe_did = bearer.and_then(|t| self.refresh_tokens.get(t)).cloned();
        let (Some(old_token), Some(did)) = (bearer, maybe_did) else {
            return (
                401,
                serde_json::json!({"error": "ExpiredToken", "message": "bad refresh"}),
            );
        };
        let acct = self.accounts[&did].clone();
        if let Some(err) = account_status_error(acct.status.as_deref()) {
            return err;
        }
        self.refresh_tokens.remove(old_token);
        let lifetime = self.access_lifetime_secs;
        let access = self.issue_jwt(&did, lifetime);
        let refresh = self.issue_jwt(&did, 86_400);
        self.access_tokens.insert(access.clone(), did.clone());
        self.refresh_tokens.insert(refresh.clone(), did);
        (
            200,
            serde_json::json!({
                "accessJwt": access,
                "refreshJwt": refresh,
                "handle": acct.handle,
                "did": acct.did,
                "active": acct.active,
                "status": acct.status,
            }),
        )
    }

    fn handle_get_session(&self, bearer: Option<&str>) -> (u16, serde_json::Value) {
        let Some(did) = bearer.and_then(|t| self.access_tokens.get(t)).cloned() else {
            return (401, serde_json::json!({"error": "InvalidToken"}));
        };
        let acct = self.accounts[&did].clone();
        if acct.status.as_deref() == Some("takendown") {
            return (
                401,
                serde_json::json!({"error": "AccountTakedown", "message": "Account has been taken down"}),
            );
        }
        (
            200,
            serde_json::json!({
                "handle": acct.handle,
                "did": acct.did,
                "active": acct.active,
                "status": acct.status,
            }),
        )
    }
    fn handle_get_profile(&self, bearer: Option<&str>) -> (u16, serde_json::Value) {
        let Some(token) = bearer else {
            return (401, serde_json::json!({"error": "AuthMissing"}));
        };
        if self.expired_access_tokens.contains(token) {
            return (
                400,
                serde_json::json!({"error": "ExpiredToken", "message": "Token has expired"}),
            );
        }
        let Some(did) = self.access_tokens.get(token).cloned() else {
            return (401, serde_json::json!({"error": "InvalidToken"}));
        };
        let acct = &self.accounts[&did];
        (
            200,
            serde_json::json!({
                "did": acct.did,
                "handle": acct.handle,
            }),
        )
    }
}

fn account_status_error(status: Option<&str>) -> Option<(u16, serde_json::Value)> {
    match status {
        Some("takendown") => Some((
            401,
            serde_json::json!({"error": "AccountTakedown", "message": "Account has been taken down"}),
        )),
        Some("suspended") => Some((
            401,
            serde_json::json!({"error": "AccountSuspended", "message": "Account is suspended"}),
        )),
        _ => None,
    }
}

impl HttpTransport for FakePdsNetwork {
    fn send(
        &self,
        request: Request<Bytes>,
        _options: &SendOptions,
    ) -> impl std::future::Future<Output = Result<Response<Bytes>, TransportError>> + Send {
        let uri = request.uri().to_string();
        let url = Url::parse(&uri).unwrap();
        let origin = url.origin().ascii_serialization();
        let path = url.path().to_owned();
        let auth = request
            .headers()
            .get("authorization")
            .and_then(|v| v.to_str().ok())
            .map(str::to_owned);
        let dpop = request
            .headers()
            .get("dpop")
            .and_then(|v| v.to_str().ok())
            .map(str::to_owned);
        let bearer = auth
            .as_deref()
            .and_then(|v| v.strip_prefix("Bearer "))
            .map(str::to_owned);
        let body: serde_json::Value =
            serde_json::from_slice(request.body()).unwrap_or_else(|_| serde_json::json!({}));

        let delay_ms = if path == "/xrpc/com.atproto.server.refreshSession" {
            self.servers.lock().unwrap()[&origin].refresh_delay_ms
        } else {
            0
        };
        let servers_ref = &self.servers;
        async move {
            if delay_ms > 0 {
                tokio::time::sleep(Duration::from_millis(delay_ms)).await;
            }
            let (status, payload) = {
                let mut servers = servers_ref.lock().unwrap();
                let server = servers.get_mut(&origin).expect("unknown test origin");
                let method = path.rsplit('/').next().unwrap_or("");
                let result = if let Some(&forced) = server.forced_status.get(method) {
                    (
                        forced,
                        serde_json::json!({"error": "InternalServerError", "message": "forced"}),
                    )
                } else {
                    match path.as_str() {
                        "/xrpc/com.atproto.server.createSession" => {
                            server.handle_create_session(&body)
                        }
                        "/xrpc/com.atproto.server.refreshSession" => {
                            server.handle_refresh_session(bearer.as_deref())
                        }
                        "/xrpc/com.atproto.server.deleteSession" => {
                            if let Some(tok) = bearer.as_deref()
                                && server.refresh_tokens.remove(tok).is_some()
                            {
                                (200, serde_json::json!({}))
                            } else {
                                (401, serde_json::json!({"error": "InvalidToken"}))
                            }
                        }
                        "/xrpc/com.atproto.server.getSession" => {
                            server.handle_get_session(bearer.as_deref())
                        }
                        "/xrpc/app.bsky.actor.getProfile" => {
                            server.handle_get_profile(bearer.as_deref())
                        }
                        _ => (404, serde_json::json!({"error": "MethodNotImplemented"})),
                    }
                };
                server.recorded.push(RecordedCall {
                    path,
                    auth,
                    dpop,
                    body,
                    status: result.0,
                });
                result
            };

            Ok(Response::builder()
                .status(status)
                .header("Content-Type", "application/json")
                .body(Bytes::from(serde_json::to_vec(&payload).unwrap()))
                .unwrap())
        }
    }
}

fn alice_account() -> FakeAccount {
    FakeAccount {
        did: ALICE_DID.to_owned(),
        handle: ALICE_HANDLE.to_owned(),
        email: ALICE_EMAIL.to_owned(),
        password: ALICE_PASSWORD.to_owned(),
        active: true,
        status: None,
        requires_auth_factor: false,
    }
}

#[test]
fn account_status_and_xrpc_error_mapping() {
    assert_eq!(
        AccountStatus::from_api(Some(true), None),
        AccountStatus::active()
    );
    assert!(AccountStatus::from_api(None, None).is_active);
    for (raw, expected) in [
        ("takendown", AccountStatusReason::Takendown),
        ("suspended", AccountStatusReason::Suspended),
        ("deleted", AccountStatusReason::Deleted),
        ("deactivated", AccountStatusReason::Deactivated),
        ("desynchronized", AccountStatusReason::Desynchronized),
        ("throttled", AccountStatusReason::Throttled),
    ] {
        let parsed = AccountStatus::from_api(Some(false), Some(raw));
        assert!(!parsed.is_active);
        assert_eq!(parsed.reason.as_ref(), Some(&expected));
        assert_eq!(parsed.reason.as_ref().unwrap().raw_value(), raw);
    }
    let future = AccountStatus::from_api(Some(false), Some("quarantined"));
    assert_eq!(
        future.reason,
        Some(AccountStatusReason::Other("quarantined".to_owned()))
    );
    assert_eq!(
        AccountStatus::from_api(Some(false), Some("takendown")).to_string(),
        "inactive (takendown)"
    );

    assert_eq!(
        AccountStatusError::from_xrpc_error("AccountTakedown", Some("gone")),
        Some(AccountStatusError::new(
            AccountStatus::new(false, Some(AccountStatusReason::Takendown)),
            Some("gone".to_owned())
        ))
    );
    assert!(AccountStatusError::from_xrpc_error("ExpiredToken", None).is_none());
    assert!(AccountStatusError::from_xrpc_body(br#"{"error":"AccountSuspended"}"#).is_some());
    assert!(AccountStatusError::from_xrpc_body(b"not json").is_none());
}

#[tokio::test]
async fn legacy_password_login_2fa_refresh_status_and_logout_lifecycle() {
    let pds_url = Url::parse("https://pds.password.test").unwrap();
    let entryway_url = Url::parse("https://entryway.password.test").unwrap();

    let mut pds_state = FakePdsState::new("https://pds.password.test");
    pds_state
        .accounts
        .insert(ALICE_DID.to_owned(), alice_account());
    let mut entryway_state = FakePdsState::new("https://entryway.password.test");
    entryway_state
        .accounts
        .insert(ALICE_DID.to_owned(), alice_account());

    let net = Arc::new(FakePdsNetwork::new(vec![pds_state, entryway_state]));
    let resolver = Arc::new(FakeResolver::new());
    resolver.register(ALICE_DID, ALICE_HANDLE, &pds_url);

    let secrets = Arc::new(MemorySecretStore::new());
    let store = SessionStore::new(secrets, "legacy-test").unwrap();
    let client = AtProtoClient::new(
        entryway_url.clone(),
        net.clone(),
        store,
        resolver.clone(),
        None,
        AuthMode::Legacy,
        false,
    )
    .unwrap();

    // 1. Handle sign-in routes straight to the PDS without sending credentials.
    let res = client
        .login_with_password(ALICE_HANDLE, ALICE_PASSWORD, None)
        .await
        .unwrap();
    assert_eq!(res.did.as_str(), ALICE_DID);
    assert_eq!(res.pds_url, pds_url);
    assert_eq!(
        net.calls("https://entryway.password.test", "createSession")
            .len(),
        0
    );
    let create = net
        .calls("https://pds.password.test", "createSession")
        .pop()
        .unwrap();
    assert!(create.auth.is_none());
    assert!(create.dpop.is_none());
    assert_eq!(create.body["identifier"], ALICE_HANDLE);
    assert_eq!(create.status, 200);
    assert_eq!(client.base_url().await, pds_url);
    assert_eq!(
        client.fetch_account_status().await.unwrap(),
        AccountStatus::active()
    );

    // 2. Labeler configuration works dynamically on AtProtoClient.
    client
        .configure_labelers(&[XrpcLabeler {
            did: "did:plc:ar7c4by46qjdydhdevvrndac".to_owned(),
            redact: true,
        }])
        .await
        .unwrap();
    assert_eq!(client.configured_labelers().await.unwrap().len(), 1);
    client.clear_labelers().await.unwrap();
    assert!(client.configured_labelers().await.is_none());

    // 3. Takedown refusal on getSession yields AccountStatus without refreshing or signing out.
    net.set_status(
        "https://pds.password.test",
        ALICE_DID,
        false,
        Some("takendown"),
    );
    let status = client.fetch_account_status().await.unwrap();
    assert_eq!(
        status,
        AccountStatus::new(false, Some(AccountStatusReason::Takendown))
    );
    assert_eq!(
        net.calls("https://pds.password.test", "refreshSession")
            .len(),
        0
    );

    // Reinstated -> logout deletes session on PDS using refresh JWT.
    net.set_status("https://pds.password.test", ALICE_DID, true, None);
    client.logout().await.unwrap();
    assert_eq!(net.live_session_count("https://pds.password.test"), 0);
    assert!(!client.has_valid_session().await);

    // 4. Email login targets configured fallback entryway and updates base_url to PDS.
    client.set_base_url(entryway_url.clone()).await.unwrap();
    client.switch_auth_mode(AuthMode::Legacy).await.unwrap();
    let email_res = client
        .login_with_password(ALICE_EMAIL, ALICE_PASSWORD, None)
        .await
        .unwrap();
    assert_eq!(email_res.pds_url, pds_url);
    assert_eq!(client.base_url().await, pds_url);
    assert_eq!(
        net.calls("https://entryway.password.test", "createSession")
            .len(),
        1
    );
}

#[tokio::test]
async fn legacy_password_2fa_wrong_password_mismatch_and_refresh_non_spend() {
    let pds_url = Url::parse("https://pds.password.test").unwrap();
    let mut pds_state = FakePdsState::new("https://pds.password.test");
    let mut acct = alice_account();
    acct.requires_auth_factor = true;
    pds_state.accounts.insert(ALICE_DID.to_owned(), acct);

    let net = Arc::new(FakePdsNetwork::new(vec![pds_state]));
    let resolver = Arc::new(FakeResolver::new());
    resolver.register(ALICE_DID, ALICE_HANDLE, &pds_url);

    let store = SessionStore::new(Arc::new(MemorySecretStore::new()), "pw-edge").unwrap();
    let accounts = Arc::new(AccountManager::new(store));
    let strategy = Arc::new(LegacyPasswordStrategy::new(
        accounts.clone(),
        net.clone(),
        resolver,
        pds_url.clone(),
    ));

    // Wrong password
    assert!(matches!(
        strategy
            .login_with_password(ALICE_HANDLE, "wrong", None)
            .await,
        Err(PasswordAuthError::InvalidCredentials)
    ));

    // 2FA required -> wrong code -> valid code
    assert!(matches!(
        strategy
            .login_with_password(ALICE_HANDLE, ALICE_PASSWORD, None)
            .await,
        Err(PasswordAuthError::AuthFactorTokenRequired(
            AuthFactorTokenRequiredError
        ))
    ));
    assert!(matches!(
        strategy
            .login_with_password(ALICE_HANDLE, ALICE_PASSWORD, Some("bad"))
            .await,
        Err(PasswordAuthError::InvalidCredentials)
    ));
    strategy
        .login_with_password(ALICE_HANDLE, ALICE_PASSWORD, Some(AUTH_FACTOR_CODE))
        .await
        .unwrap();

    // 5xx and 429 during refresh do NOT burn refresh token.
    net.set_forced_status(
        "https://pds.password.test",
        Some(("com.atproto.server.refreshSession", 503)),
    );
    assert!(matches!(
        strategy.refresh_token_if_needed(true).await,
        Err(PasswordAuthError::TokenRefreshFailed(_))
    ));
    net.set_forced_status(
        "https://pds.password.test",
        Some(("com.atproto.server.refreshSession", 429)),
    );
    assert!(matches!(
        strategy.refresh_token_if_needed(true).await,
        Err(PasswordAuthError::RateLimited)
    ));
    net.set_forced_status("https://pds.password.test", None);
    assert_eq!(
        strategy.refresh_token_if_needed(true).await.unwrap(),
        TokenRefreshResult::RefreshedSuccessfully
    );

    // Status error during refresh keeps session & records status.
    net.set_status(
        "https://pds.password.test",
        ALICE_DID,
        false,
        Some("suspended"),
    );
    assert!(matches!(
        strategy.refresh_token_if_needed(true).await,
        Err(PasswordAuthError::AccountStatus(AccountStatusError { .. }))
    ));
    assert_eq!(
        strategy
            .last_known_account_status(&ALICE_DID.parse().unwrap())
            .await,
        Some(AccountStatus::new(
            false,
            Some(AccountStatusReason::Suspended)
        ))
    );

    // Mismatched returned DID is discarded and deleted on server.
    net.set_status("https://pds.password.test", ALICE_DID, true, None);
    {
        let mut servers = net.servers.lock().unwrap();
        servers
            .get_mut("https://pds.password.test")
            .unwrap()
            .create_session_did_override = Some("did:plc:someoneelse".to_owned());
    }
    let before_sessions = net.live_session_count("https://pds.password.test");
    assert!(matches!(
        strategy
            .login_with_password(ALICE_HANDLE, ALICE_PASSWORD, Some(AUTH_FACTOR_CODE))
            .await,
        Err(PasswordAuthError::InvalidResponse(_))
    ));
    assert_eq!(
        net.live_session_count("https://pds.password.test"),
        before_sessions
    );
}

#[tokio::test]
async fn auth_continuity_state_account_manager_and_circuit_breaker() {
    let mut continuity = AuthContinuityState::new(AuthMode::Gateway {
        origin: Url::parse("https://gateway.example").unwrap(),
    });
    let s0 = continuity.snapshot();
    assert!(s0.did.is_none());
    assert!(s0.mode.is_gateway());

    continuity.observe_gateway_identity(Some(GatewayAuthIdentity::new(ALICE_DID, "secret-1")));
    let s1 = continuity.snapshot();
    assert_eq!(s1.did.as_deref(), Some(ALICE_DID));

    continuity.observe_gateway_identity(Some(GatewayAuthIdentity::new(ALICE_DID, "secret-2")));
    let s2 = continuity.snapshot();
    assert!(s2.generation > s1.generation);
    assert!(!format!("{s2:?}").contains("secret-2"));

    // Exhaustion at u64::MAX fails closed and clears principal permanently.
    let mut exhausted = AuthContinuityState::with_observed(
        AuthMode::Gateway {
            origin: Url::parse("https://gateway.example").unwrap(),
        },
        u64::MAX,
        Some(GatewayAuthIdentity::new(ALICE_DID, "secret")),
    );
    exhausted.invalidate();
    assert!(exhausted.is_exhausted());
    assert!(exhausted.snapshot().did.is_none());

    // AccountSwitchCoordinator rejects concurrent switches & completes cleanly.
    let coord = AccountSwitchCoordinator::new();
    let did_a: Did = ALICE_DID.parse().unwrap();
    let did_b: Did = "did:plc:bob".parse().unwrap();
    coord.begin_account_switch(None, &did_a).unwrap();
    assert!(coord.is_account_switch_in_progress());
    assert_eq!(
        coord.begin_account_switch(Some(&did_a), &did_b),
        Err(AccountSwitchError::SwitchInProgress)
    );
    coord.complete_account_switch();
    assert!(!coord.is_account_switch_in_progress());

    // AccountManager removal auto-switches when enabled.
    let store = SessionStore::new(Arc::new(MemorySecretStore::new()), "acct-mgr").unwrap();
    let mgr = AccountManager::new(store);
    mgr.add_account(&Account {
        did: did_a.clone(),
        handle: None,
        pds: "https://a.example".to_owned(),
        authorization_server: None,
        expected_issuer: None,
    })
    .await
    .unwrap();
    mgr.add_account(&Account {
        did: did_b.clone(),
        handle: None,
        pds: "https://b.example".to_owned(),
        authorization_server: None,
        expected_issuer: None,
    })
    .await
    .unwrap();
    mgr.remove_account(&did_a).await.unwrap();
    assert_eq!(mgr.current_did().await.unwrap(), Some(did_b));

    // AuthManager continuity transaction rejects stale snapshots.
    let resolver = Arc::new(FakeResolver::new());
    let net = Arc::new(FakePdsNetwork::new(vec![]));
    let client = AtProtoClient::new(
        Url::parse("https://gateway.example").unwrap(),
        net,
        SessionStore::new(Arc::new(MemorySecretStore::new()), "txn").unwrap(),
        resolver,
        None,
        AuthMode::Gateway {
            origin: Url::parse("https://gateway.example").unwrap(),
        },
        false,
    )
    .unwrap();
    let snap = client.auth_continuity_snapshot().await;
    assert_eq!(
        client
            .perform_with_exact_auth_continuity(&snap, || 42)
            .await,
        AuthContinuityTransactionResult::Performed(42)
    );
    client.switch_auth_mode(AuthMode::Legacy).await.unwrap();
    assert_eq!(
        client
            .perform_with_exact_auth_continuity(&snap, || 42)
            .await,
        AuthContinuityTransactionResult::ContinuityChanged
    );

    // RefreshCircuitBreaker ignores nonce challenges and opens on 3 real failures.
    let breaker = RefreshCircuitBreaker::new();
    breaker
        .record_failure(&did_a, RefreshFailureKind::NonceRecoverable)
        .await;
    assert!(breaker.can_attempt_refresh(&did_a).await);
    for _ in 0..3 {
        breaker
            .record_failure(&did_a, RefreshFailureKind::Server)
            .await;
    }
    assert!(!breaker.can_attempt_refresh(&did_a).await);
    assert!(breaker.force_half_open(&did_a).await);
    assert!(breaker.can_attempt_refresh(&did_a).await);
    assert!(!breaker.can_attempt_refresh(&did_a).await);
    breaker.record_success(&did_a).await;
    assert!(breaker.can_attempt_refresh(&did_a).await);
}

#[tokio::test]
async fn legacy_password_concurrent_refresh_coalesces_without_deadlock_and_recovers_http_400_expired_token()
 {
    let pds_url = Url::parse("https://pds.concurrent.test").unwrap();
    let mut pds_state = FakePdsState::new("https://pds.concurrent.test");
    pds_state
        .accounts
        .insert(ALICE_DID.to_owned(), alice_account());

    let net = Arc::new(FakePdsNetwork::new(vec![pds_state]));
    let resolver = Arc::new(FakeResolver::new());
    resolver.register(ALICE_DID, ALICE_HANDLE, &pds_url);

    let store = SessionStore::new(Arc::new(MemorySecretStore::new()), "pw-conc").unwrap();
    let accounts = Arc::new(AccountManager::new(store.clone()));
    let strategy = Arc::new(LegacyPasswordStrategy::new(
        accounts,
        net.clone(),
        resolver.clone(),
        pds_url.clone(),
    ));
    strategy
        .login_with_password(ALICE_HANDLE, ALICE_PASSWORD, None)
        .await
        .unwrap();

    // 1. Concurrent `refresh_token_if_needed(true)` must coalesce cleanly without deadlocking.
    net.set_refresh_delay_ms("https://pds.concurrent.test", 50);
    let futs = (0..8).map(|_| strategy.refresh_token_if_needed(true));
    let results =
        tokio::time::timeout(Duration::from_secs(5), futures_util::future::join_all(futs))
            .await
            .expect("concurrent refresh_token_if_needed must not deadlock");
    for res in results {
        assert_eq!(res.unwrap(), TokenRefreshResult::RefreshedSuccessfully);
    }
    assert_eq!(
        net.calls("https://pds.concurrent.test", "refreshSession")
            .len(),
        1
    );

    // 2. HTTP 400 with `ExpiredToken` triggers refresh & XRPC retry even when JWT exp is fresh.
    let client = AtProtoClient::new(
        pds_url,
        net.clone(),
        store,
        resolver,
        None,
        AuthMode::Legacy,
        false,
    )
    .unwrap();
    net.set_refresh_delay_ms("https://pds.concurrent.test", 0);
    net.expire_all_access_tokens("https://pds.concurrent.test");
    let resp = client
        .query(
            "app.bsky.actor.getProfile",
            [("actor", ALICE_DID)],
            &CallOptions::default(),
        )
        .await
        .unwrap();
    let body: serde_json::Value = serde_json::from_slice(&resp.body).unwrap();
    assert_eq!(body["did"], ALICE_DID);
    assert_eq!(
        net.calls("https://pds.concurrent.test", "refreshSession")
            .len(),
        2
    );
    let profile_calls = net.calls("https://pds.concurrent.test", "getProfile");
    assert_eq!(profile_calls.len(), 2);
    assert_eq!(profile_calls[0].status, 400);
    assert_eq!(profile_calls[1].status, 200);

    // Non-ExpiredToken HTTP 400 does NOT trigger a refresh.
    let bad_req = Response::builder()
        .status(StatusCode::BAD_REQUEST)
        .body(Bytes::from_static(br#"{"error":"InvalidRequest"}"#))
        .unwrap();
    let action = strategy
        .handle_unauthorized(&bad_req, &AuthCtx::default())
        .await
        .unwrap();
    assert_eq!(action, UnauthorizedAction::GiveUp);
}
