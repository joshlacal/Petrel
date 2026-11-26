//! Ported PetrelLoad CLI and AuthEvent JSONL writer tests.
#![cfg(not(target_arch = "wasm32"))]

use std::io::Cursor;
use std::process::Command;
use std::sync::Arc;

use petrel::auth::AuthMode;
use petrel::oauth::Account;
use petrel::storage::{MemorySecretStore, SessionStore};
use petrel_core::Did;
use petrel_load::{
    ArgumentError, AuthEventJsonlWriter, AuthEventRecorderHandle, CallbackReadError,
    CliOAuthConfig, OAuthMetadataError, OAuthMetadataResponse, PetrelLoadCli, ScenarioPlan,
    open_session_store, open_session_store_in,
};
use serde_json::Value as JsonValue;
use tempfile::{NamedTempFile, TempDir};
use url::Url;

#[test]
fn parses_valid_options_and_rejects_invalid_and_removed_options() {
    let args = PetrelLoadCli::parse_args(&[
        "petrel-load",
        "--namespace",
        "com.example.petrel",
        "--endpoint",
        "app.bsky.feed.getTimeline",
        "--requests",
        "12",
        "--unauth",
    ])
    .unwrap();
    assert_eq!(
        args.get("namespace").map(String::as_str),
        Some("com.example.petrel")
    );
    assert_eq!(
        args.get("endpoint").map(String::as_str),
        Some("app.bsky.feed.getTimeline")
    );
    assert_eq!(args.get("requests").map(String::as_str), Some("12"));
    assert_eq!(args.get("unauth").map(String::as_str), Some("true"));

    assert_eq!(
        PetrelLoadCli::parse_args(&["petrel-load", "--method", "POST"]),
        Err(ArgumentError::UnknownOption("method".to_owned()))
    );
    assert_eq!(
        PetrelLoadCli::parse_args(&["petrel-load", "--endpoint"]),
        Err(ArgumentError::MissingValue("endpoint".to_owned()))
    );

    for (opt, val) in [
        ("requests", "nope"),
        ("requests", "0"),
        ("concurrency", "0"),
    ] {
        assert_eq!(
            PetrelLoadCli::parse_args(&["petrel-load", &format!("--{opt}"), val]),
            Err(ArgumentError::InvalidValue {
                option: opt.to_owned(),
                value: val.to_owned(),
            })
        );
    }

    for bad_url in [
        "not a URL",
        "relative/path",
        "ftp://example.com",
        "https:///missing-host",
    ] {
        assert_eq!(
            PetrelLoadCli::parse_args(&["petrel-load", "--base-url", bad_url]),
            Err(ArgumentError::InvalidValue {
                option: "base-url".to_owned(),
                value: bad_url.to_owned(),
            })
        );
    }

    assert_eq!(
        PetrelLoadCli::parse_args(&[
            "petrel-load",
            "--namespace",
            "com.example.petrel",
            "--endpoint",
            "app.bsky.actor.getProfile",
            "--oauth-start",
        ]),
        Err(ArgumentError::OAuthConfigurationRequired)
    );

    let full = PetrelLoadCli::parse_args(&[
        "petrel-load",
        "--namespace",
        "com.example.petrel",
        "--endpoint",
        "app.bsky.actor.getProfile",
        "--client-id",
        "https://client.example/oauth-client-metadata.json",
        "--redirect-uri",
        "com.example.client:/callback",
    ])
    .unwrap();
    let cfg = PetrelLoadCli::oauth_configuration(&full).unwrap().unwrap();
    assert_eq!(
        cfg.client_id,
        "https://client.example/oauth-client-metadata.json"
    );
    assert_eq!(cfg.redirect_uri.as_str(), "com.example.client:/callback");
    assert_eq!(cfg.scope, "atproto transition:generic");
}

#[tokio::test]
async fn oauth_metadata_preflight_and_instructions() {
    let cfg = CliOAuthConfig {
        client_id: "https://client.example/oauth-client-metadata.json".to_owned(),
        redirect_uri: Url::parse("com.example.client:/callback").unwrap(),
        scope: "atproto transition:generic".to_owned(),
    };
    let valid_doc = serde_json::json!({
        "client_id": "https://client.example/oauth-client-metadata.json",
        "redirect_uris": ["com.example.client:/callback"],
        "grant_types": ["authorization_code", "refresh_token"],
        "scope": "atproto transition:generic",
        "response_types": ["code"],
        "dpop_bound_access_tokens": true,
    });

    PetrelLoadCli::validate_oauth_metadata(&cfg, |url| {
        let data = serde_json::to_vec(&valid_doc).unwrap();
        async move {
            Ok(OAuthMetadataResponse {
                final_url: url,
                status_code: 200,
                content_type: Some("application/json; charset=utf-8".to_owned()),
                data,
            })
        }
    })
    .await
    .unwrap();

    let bad_redirect = PetrelLoadCli::validate_oauth_metadata(&cfg, |url| {
        let bad = serde_json::json!({
            "client_id": "https://client.example/oauth-client-metadata.json",
            "redirect_uris": ["com.example.other:/callback"],
            "grant_types": ["authorization_code", "refresh_token"],
            "scope": "atproto transition:generic",
            "response_types": ["code"],
            "dpop_bound_access_tokens": true,
        });
        async move {
            Ok(OAuthMetadataResponse {
                final_url: url,
                status_code: 200,
                content_type: Some("application/json".to_owned()),
                data: serde_json::to_vec(&bad).unwrap(),
            })
        }
    })
    .await
    .unwrap_err();
    assert!(bad_redirect.downcast_ref::<OAuthMetadataError>().is_some());

    let instructions = PetrelLoadCli::oauth_completion_instructions(
        &cfg,
        "com.example.petrel",
        "app.bsky.actor.getProfile",
    );
    assert!(instructions.contains("com.example.client:/callback"));
    assert!(instructions.contains("--oauth-complete-stdin"));
}

#[test]
fn callback_reader_secret_reader_and_scenario_plans() {
    let inert = "com.example.client:/callback?code=$(whoami)&state=`id`\n";
    let read = PetrelLoadCli::read_callback(Cursor::new(inert.as_bytes())).unwrap();
    let parsed = PetrelLoadCli::parse_callback_url(&read).unwrap();
    assert_eq!(
        parsed.query_pairs().find(|(k, _)| k == "code").unwrap().1,
        "$(whoami)"
    );

    assert_eq!(
        PetrelLoadCli::read_callback(Cursor::new(b"")),
        Err(CallbackReadError::EmptyInput)
    );
    assert_eq!(
        PetrelLoadCli::read_callback(Cursor::new(b"  \n\t ")),
        Err(CallbackReadError::WhitespaceOnly)
    );
    assert_eq!(
        PetrelLoadCli::read_callback(Cursor::new(&[0xFF, 0xFE])),
        Err(CallbackReadError::InvalidUtf8)
    );

    assert_eq!(
        PetrelLoadCli::read_secret_line(Cursor::new(b"  s3cret \r\n")),
        Some("s3cret".to_owned())
    );
    assert_eq!(PetrelLoadCli::read_secret_line(Cursor::new(b"\n")), None);

    assert_eq!(
        PetrelLoadCli::scenario_plan("oauth-test", "authenticated-load", 20, 4),
        Some(ScenarioPlan::ConcurrentRequests {
            total: 20,
            concurrency: 4
        })
    );
    assert_eq!(
        PetrelLoadCli::scenario_plan("oauth-test", "refresh-sequence", 20, 4),
        Some(ScenarioPlan::SerialRefreshes { count: 5 })
    );
    assert_eq!(PetrelLoadCli::request_distribution(10, 3), vec![4, 3, 3]);
}

#[tokio::test]
async fn auth_event_jsonl_writer_records_and_drains_on_session_store() {
    let temp = NamedTempFile::new().unwrap();
    let writer = Arc::new(AuthEventJsonlWriter::open(temp.path()).unwrap());
    let store = SessionStore::new(Arc::new(MemorySecretStore::new()), "load-jsonl-test").unwrap();
    let recorder = AuthEventRecorderHandle::attach(&store, writer);

    let did: Did = "did:plc:drain-test".parse().unwrap();
    let account = Account {
        did: did.clone(),
        handle: None,
        pds: "https://bsky.social".to_owned(),
        authorization_server: None,
        expected_issuer: None,
    };
    store.save_account(&account).await.unwrap();
    store.save_current_did(&did).await.unwrap();
    recorder.drain().await;

    let content = std::fs::read_to_string(temp.path()).unwrap();
    let lines: Vec<&str> = content.lines().collect();
    assert_ne!(lines, [] as [&str; 0]);
    let parsed: JsonValue = serde_json::from_str(lines.last().unwrap()).unwrap();
    assert!(
        parsed["event"]
            .as_str()
            .unwrap()
            .contains("did:plc:drain-test")
    );
    assert!(parsed["ts"].as_u64().is_some());
}

#[test]
fn cli_binary_rejects_incomplete_oauth_with_exit_2() {
    let bin = env!("CARGO_BIN_EXE_petrel-load");
    let out = Command::new(bin)
        .args([
            "--namespace",
            "com.example.petrel",
            "--endpoint",
            "app.bsky.actor.getProfile",
            "--oauth-start",
        ])
        .output()
        .unwrap();
    assert_eq!(out.status.code(), Some(2));
    let stderr = String::from_utf8_lossy(&out.stderr);
    assert!(stderr.contains("--client-id") && stderr.contains("--redirect-uri"));
}

struct TempDirCleanup(std::path::PathBuf);

impl Drop for TempDirCleanup {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

#[tokio::test]
async fn open_session_store_first_run_creates_private_dir_and_persists_accounts() {
    let base = TempDir::new().unwrap();
    let store = open_session_store_in(base.path(), "load-first-run").unwrap();
    let expected_dir = std::fs::canonicalize(base.path())
        .unwrap()
        .join("petrel-load-store-load-first-run");
    assert!(expected_dir.is_dir());

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mode = std::fs::metadata(&expected_dir)
            .unwrap()
            .permissions()
            .mode()
            & 0o777;
        assert_eq!(mode, 0o700);
    }

    let did: Did = "did:plc:load-store-test".parse().unwrap();
    let account = Account {
        did: did.clone(),
        handle: None,
        pds: "https://bsky.social".to_owned(),
        authorization_server: None,
        expected_issuer: None,
    };
    store.save_account(&account).await.unwrap();
    store.save_current_did(&did).await.unwrap();
    drop(store);

    let reopened = open_session_store_in(base.path(), "load-first-run").unwrap();
    assert_eq!(reopened.get_current_did().await.unwrap(), Some(did));

    // Also exercise the real temp_dir entrypoint (resolving OS temp symlinks before open).
    let unique_ns = format!("load-first-run-{}", std::process::id());
    let temp_store_dir = std::fs::canonicalize(std::env::temp_dir())
        .unwrap()
        .join(format!("petrel-load-store-{unique_ns}"));
    let _ = std::fs::remove_dir_all(&temp_store_dir);
    let _cleanup = TempDirCleanup(temp_store_dir.clone());
    let temp_store = open_session_store(&unique_ns).unwrap();
    assert!(temp_store_dir.is_dir());
    drop(temp_store);
}

#[tokio::test]
async fn run_cli_unauth_allows_loopback_targets_for_both_supported_endpoints() {
    use std::io::{Read, Write};
    use std::net::TcpListener;

    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    let seen_paths = Arc::new(std::sync::Mutex::new(Vec::<String>::new()));
    let seen_clone = Arc::clone(&seen_paths);

    let server = std::thread::spawn(move || {
        for _ in 0..2 {
            let (mut socket, _) = listener.accept().unwrap();
            let mut buf = [0u8; 2048];
            let n = socket.read(&mut buf).unwrap();
            let req = String::from_utf8_lossy(&buf[..n]);
            let first_line = req.lines().next().unwrap_or("").to_owned();
            seen_clone.lock().unwrap().push(first_line);
            let resp = b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}";
            socket.write_all(resp).unwrap();
        }
    });

    let unique_ns = format!("load-loopback-{}", std::process::id());
    let temp_store_dir = std::fs::canonicalize(std::env::temp_dir())
        .unwrap()
        .join(format!("petrel-load-store-{unique_ns}"));
    let _ = std::fs::remove_dir_all(&temp_store_dir);
    let _cleanup = TempDirCleanup(temp_store_dir);

    let base_url = format!("http://{addr}");
    for endpoint in ["app.bsky.actor.getProfile", "app.bsky.feed.getTimeline"] {
        petrel_load::run_cli(&[
            "petrel-load",
            "--namespace",
            &unique_ns,
            "--endpoint",
            endpoint,
            "--base-url",
            &base_url,
            "--requests",
            "1",
            "--concurrency",
            "1",
            "--unauth",
        ])
        .await
        .unwrap();
    }

    server.join().unwrap();
    let recorded = seen_paths.lock().unwrap();
    assert_eq!(recorded.len(), 2);
    assert!(recorded[0].starts_with("GET /xrpc/app.bsky.actor.getProfile?"));
    assert!(recorded[1].starts_with("GET /xrpc/app.bsky.feed.getTimeline?"));
}

#[cfg(unix)]
#[test]
fn auth_event_jsonl_writer_restricts_file_permissions_to_0600() {
    use std::os::unix::fs::PermissionsExt;

    let dir = TempDir::new().unwrap();
    let fresh_path = dir.path().join("nested").join("events.jsonl");
    let writer = AuthEventJsonlWriter::open(&fresh_path).unwrap();
    drop(writer);

    let fresh_mode = std::fs::metadata(&fresh_path).unwrap().permissions().mode() & 0o777;
    assert_eq!(fresh_mode, 0o600);

    // Pre-existing overly permissive regular file is also tightened on open.
    let existing_path = dir.path().join("existing.jsonl");
    std::fs::write(&existing_path, b"").unwrap();
    std::fs::set_permissions(&existing_path, std::fs::Permissions::from_mode(0o644)).unwrap();
    let writer = AuthEventJsonlWriter::open(&existing_path).unwrap();
    drop(writer);

    let existing_mode = std::fs::metadata(&existing_path)
        .unwrap()
        .permissions()
        .mode()
        & 0o777;
    assert_eq!(existing_mode, 0o600);
}

mod oauth_diagnostics_support {
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::{Arc, Mutex};

    use bytes::Bytes;
    use http::{Request, Response, StatusCode};
    use petrel::auth::AuthMode;
    use petrel::client::AtProtoClient;
    use petrel::crypto::{DpopSigner, SoftwareDpopSigner};
    use petrel::net::{HttpTransport, SendOptions, TransportError};
    use petrel::oauth::{
        Account, ClientAuth, OAuthClient, OAuthConfig, OAuthIdentity, OAuthIdentityError,
        OAuthIdentityResolver, Session, SessionRecord,
    };
    use petrel::rt::BoxFuture;
    use petrel::storage::{MemorySecretStore, SessionStore};
    use petrel_core::{AtIdentifier, Did};
    use serde_json::json;
    use url::Url;

    pub(super) const DID: &str = "did:plc:loaddiag";
    pub(super) const PDS_ORIGIN: &str = "https://pds.load-diag.example";

    pub(super) struct StaticResolver;
    impl OAuthIdentityResolver for StaticResolver {
        fn resolve_identity<'a>(
            &'a self,
            _identifier: &'a AtIdentifier,
            _force_refresh: bool,
        ) -> BoxFuture<'a, Result<OAuthIdentity, OAuthIdentityError>> {
            Box::pin(async {
                Ok(OAuthIdentity {
                    did: DID.parse().unwrap(),
                    handle: None,
                    pds: Url::parse(PDS_ORIGIN).unwrap(),
                })
            })
        }
    }

    pub(super) struct MockOAuthPdsTransport {
        pub(super) token_calls: AtomicUsize,
        pub(super) profile_calls: AtomicUsize,
        current_refresh: Mutex<String>,
        current_access: Mutex<String>,
        pub(super) seen_profile_auth: Mutex<Vec<String>>,
    }

    impl MockOAuthPdsTransport {
        pub(super) fn new() -> Self {
            Self {
                token_calls: AtomicUsize::new(0),
                profile_calls: AtomicUsize::new(0),
                current_refresh: Mutex::new("refresh-0".to_owned()),
                current_access: Mutex::new("access-0".to_owned()),
                seen_profile_auth: Mutex::new(Vec::new()),
            }
        }
    }

    impl HttpTransport for MockOAuthPdsTransport {
        fn send(
            &self,
            request: Request<Bytes>,
            _options: &SendOptions,
        ) -> impl std::future::Future<Output = Result<Response<Bytes>, TransportError>> + Send
        {
            let path = request.uri().path().to_owned();
            let auth_hdr = request
                .headers()
                .get(http::header::AUTHORIZATION)
                .and_then(|v| v.to_str().ok())
                .map(str::to_owned);
            let body_bytes = request.into_body();
            let result = match path.as_str() {
                "/oauth/token" => {
                    let count = self.token_calls.fetch_add(1, Ordering::SeqCst) + 1;
                    let params: Vec<(String, String)> = url::form_urlencoded::parse(&body_bytes)
                        .into_owned()
                        .collect();
                    let offered = params
                        .iter()
                        .find(|(k, _)| k == "refresh_token")
                        .map_or("", |(_, v)| v.as_str());
                    let mut cur_refresh = self.current_refresh.lock().unwrap();
                    if offered == cur_refresh.as_str() {
                        let next_refresh = format!("refresh-{count}");
                        let next_access = format!("access-{count}");
                        cur_refresh.clone_from(&next_refresh);
                        self.current_access.lock().unwrap().clone_from(&next_access);
                        (
                            StatusCode::OK,
                            json!({
                                "sub": DID,
                                "access_token": next_access,
                                "refresh_token": next_refresh,
                                "token_type": "DPoP",
                                "expires_in": 3600,
                                "scope": "atproto transition:generic",
                            }),
                        )
                    } else {
                        (
                            StatusCode::BAD_REQUEST,
                            json!({"error": "invalid_grant", "error_description": "stale refresh"}),
                        )
                    }
                }
                "/xrpc/app.bsky.actor.getProfile" => {
                    self.profile_calls.fetch_add(1, Ordering::SeqCst);
                    let expected_access = self.current_access.lock().unwrap().clone();
                    let expected_auth = format!("DPoP {expected_access}");
                    if let Some(ref hdr) = auth_hdr {
                        self.seen_profile_auth.lock().unwrap().push(hdr.clone());
                    }
                    if auth_hdr.as_deref() == Some(expected_auth.as_str()) {
                        (
                            StatusCode::OK,
                            json!({
                                "did": DID,
                                "handle": "diag.load.example",
                            }),
                        )
                    } else {
                        (StatusCode::UNAUTHORIZED, json!({"error": "InvalidToken"}))
                    }
                }
                _ => (StatusCode::NOT_FOUND, json!({"error": "NotFound"})),
            };
            std::future::ready(Ok(Response::builder()
                .status(result.0)
                .header("Content-Type", "application/json")
                .body(Bytes::from(serde_json::to_vec(&result.1).unwrap()))
                .unwrap()))
        }
    }

    pub(super) async fn setup_oauth_client(
        ns: &str,
    ) -> (
        Arc<AtProtoClient>,
        Arc<MockOAuthPdsTransport>,
        SessionStore,
        Did,
    ) {
        let did: Did = DID.parse().unwrap();
        let pds = Url::parse(PDS_ORIGIN).unwrap();
        let net = Arc::new(MockOAuthPdsTransport::new());
        let store = SessionStore::new(Arc::new(MemorySecretStore::new()), ns).unwrap();
        let resolver = Arc::new(StaticResolver);
        let cfg = OAuthConfig::new(
            "https://client.example/oauth-client-metadata.json",
            Url::parse("https://client.example/callback").unwrap(),
            "atproto transition:generic",
            ClientAuth::Public,
        )
        .unwrap();
        let oauth_client =
            Arc::new(OAuthClient::new(net.clone(), resolver.clone(), store.clone(), cfg).unwrap());

        let signer = SoftwareDpopSigner::generate().unwrap();
        let jkt = signer.public_jwk().thumbprint().unwrap();
        store
            .save_dpop_key("key-diag", &signer.to_bytes())
            .await
            .unwrap();
        let as_meta = serde_json::from_value(json!({
            "issuer": PDS_ORIGIN,
            "authorization_endpoint": format!("{PDS_ORIGIN}/oauth/authorize"),
            "token_endpoint": format!("{PDS_ORIGIN}/oauth/token"),
            "pushed_authorization_request_endpoint": format!("{PDS_ORIGIN}/oauth/par"),
            "revocation_endpoint": format!("{PDS_ORIGIN}/oauth/revoke"),
            "response_types_supported": ["code"],
            "grant_types_supported": ["authorization_code", "refresh_token"],
            "code_challenge_methods_supported": ["S256"],
            "token_endpoint_auth_methods_supported": ["none", "private_key_jwt"],
            "token_endpoint_auth_signing_alg_values_supported": ["ES256"],
            "dpop_signing_alg_values_supported": ["ES256"],
            "scopes_supported": ["atproto", "transition:generic"],
            "authorization_response_iss_parameter_supported": true,
            "require_pushed_authorization_requests": true,
            "client_id_metadata_document_supported": true,
        }))
        .unwrap();
        let account = Account {
            did: did.clone(),
            handle: Some("diag.load.example".parse().unwrap()),
            pds: PDS_ORIGIN.to_owned(),
            authorization_server: Some(as_meta),
            expected_issuer: Some(PDS_ORIGIN.to_owned()),
        };
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        let session: Session = serde_json::from_value(json!({
            "did": did,
            "access_token": "access-0",
            "refresh_token": "refresh-0",
            "created_at": now,
            "expires_in": 3600,
            "scope": "atproto transition:generic",
        }))
        .unwrap();
        store.save_account(&account).await.unwrap();
        store
            .save_session(&SessionRecord {
                account,
                session,
                dpop_key_id: "key-diag".to_owned(),
                dpop_jkt: jkt,
            })
            .await
            .unwrap();
        store.save_current_did(&did).await.unwrap();

        let client = Arc::new(
            AtProtoClient::new(
                pds,
                net.clone(),
                store.clone(),
                resolver,
                Some(oauth_client),
                AuthMode::PublicOAuth,
                false,
            )
            .unwrap(),
        );
        (client, net, store, did)
    }
}

#[tokio::test]
async fn oauth_refresh_sequence_and_dpop_refresh_check_force_token_exchanges() {
    use std::sync::atomic::Ordering;
    let (client, net, store, did) =
        oauth_diagnostics_support::setup_oauth_client("load-force-refresh").await;

    // Even with a fresh 1-hour access token, `--oauth-test refresh-sequence` forces `count` (5)
    // token exchanges.
    petrel_load::run_cli_with_client(
        &client,
        &[
            "petrel-load",
            "--namespace",
            "load-force-refresh",
            "--endpoint",
            "app.bsky.actor.getProfile",
            "--client-id",
            "https://client.example/oauth-client-metadata.json",
            "--redirect-uri",
            "https://client.example/callback",
            "--oauth-test",
            "refresh-sequence",
        ],
        false,
    )
    .await
    .unwrap();
    assert_eq!(net.token_calls.load(Ordering::SeqCst), 5);
    assert_eq!(
        store
            .get_session(&did)
            .await
            .unwrap()
            .unwrap()
            .session
            .refresh_token(),
        Some("refresh-5")
    );

    // `--dpop-test refresh-check` also forces a real token exchange.
    petrel_load::run_cli_with_client(
        &client,
        &[
            "petrel-load",
            "--namespace",
            "load-force-refresh",
            "--endpoint",
            "app.bsky.actor.getProfile",
            "--client-id",
            "https://client.example/oauth-client-metadata.json",
            "--redirect-uri",
            "https://client.example/callback",
            "--dpop-test",
            "refresh-check",
        ],
        false,
    )
    .await
    .unwrap();
    assert_eq!(net.token_calls.load(Ordering::SeqCst), 6);
    assert_eq!(
        store
            .get_session(&did)
            .await
            .unwrap()
            .unwrap()
            .session
            .refresh_token(),
        Some("refresh-6")
    );
}

#[cfg(debug_assertions)]
#[tokio::test]
async fn simulate_ambiguous_timeout_injects_pending_refresh_recovers_and_verifies_api() {
    use std::sync::atomic::Ordering;
    let (client, net, store, did) =
        oauth_diagnostics_support::setup_oauth_client("load-ambig-timeout").await;

    // Step 1: Verify debug injection stores PendingRefresh without promoting SESSION.
    client.simulate_ambiguous_refresh_timeout().await.unwrap();
    assert_eq!(net.token_calls.load(Ordering::SeqCst), 1);
    assert!(store.get_pending_refresh(&did).await.unwrap().is_some());
    assert_eq!(
        store
            .get_session(&did)
            .await
            .unwrap()
            .unwrap()
            .session
            .refresh_token(),
        Some("refresh-0")
    );

    // Step 2: Recovery via `refresh_token(true)` promotes PendingRefresh WITHOUT double-spending.
    assert!(client.refresh_token(true).await.unwrap());
    assert_eq!(net.token_calls.load(Ordering::SeqCst), 1);
    assert!(store.get_pending_refresh(&did).await.unwrap().is_none());
    assert_eq!(
        store
            .get_session(&did)
            .await
            .unwrap()
            .unwrap()
            .session
            .refresh_token(),
        Some("refresh-1")
    );

    // Step 3: Full CLI `--simulate-ambiguous-timeout` path injects (`token_calls` 1 -> 2),
    // promotes (`refresh-2`), and verifies `app.bsky.actor.getProfile` with `DPoP access-2`.
    petrel_load::run_cli_with_client(
        &client,
        &[
            "petrel-load",
            "--namespace",
            "load-ambig-timeout",
            "--endpoint",
            "app.bsky.actor.getProfile",
            "--client-id",
            "https://client.example/oauth-client-metadata.json",
            "--redirect-uri",
            "com.example.client:/callback",
            "--simulate-ambiguous-timeout",
        ],
        false,
    )
    .await
    .unwrap();
    assert_eq!(net.token_calls.load(Ordering::SeqCst), 2);
    assert_eq!(net.profile_calls.load(Ordering::SeqCst), 1);
    assert_eq!(
        net.seen_profile_auth.lock().unwrap().as_slice(),
        &["DPoP access-2".to_owned()]
    );
    assert!(store.get_pending_refresh(&did).await.unwrap().is_none());
    assert_eq!(
        store
            .get_session(&did)
            .await
            .unwrap()
            .unwrap()
            .session
            .refresh_token(),
        Some("refresh-2")
    );

    // Legacy mode rejects `--simulate-ambiguous-timeout` rather than silently succeeding.
    client.switch_auth_mode(AuthMode::Legacy).await.unwrap();
    assert!(client.simulate_ambiguous_refresh_timeout().await.is_err());
}

fn stored_pds_account(did: &Did, pds_url: &str) -> Account {
    let as_meta = serde_json::from_value(serde_json::json!({
        "issuer": pds_url,
        "authorization_endpoint": format!("{pds_url}/oauth/authorize"),
        "token_endpoint": format!("{pds_url}/oauth/token"),
        "pushed_authorization_request_endpoint": format!("{pds_url}/oauth/par"),
        "revocation_endpoint": format!("{pds_url}/oauth/revoke"),
        "response_types_supported": ["code"],
        "grant_types_supported": ["authorization_code", "refresh_token"],
        "code_challenge_methods_supported": ["S256"],
        "token_endpoint_auth_methods_supported": ["none", "private_key_jwt"],
        "token_endpoint_auth_signing_alg_values_supported": ["ES256"],
        "dpop_signing_alg_values_supported": ["ES256"],
        "scopes_supported": ["atproto", "transition:generic"],
        "authorization_response_iss_parameter_supported": true,
        "require_pushed_authorization_requests": true,
        "client_id_metadata_document_supported": true,
    }))
    .unwrap();
    Account {
        did: did.clone(),
        handle: Some("stored.pds.example".parse().unwrap()),
        pds: pds_url.to_owned(),
        authorization_server: Some(as_meta),
        expected_issuer: Some(pds_url.to_owned()),
    }
}

#[tokio::test]
async fn resolve_cli_base_url_prefers_stored_pds_when_omitted() {
    let did: Did = "did:plc:storedpds111111111111111".parse().unwrap();
    let mem_store = SessionStore::new(Arc::new(MemorySecretStore::new()), "resolve-base").unwrap();
    assert_eq!(
        petrel_load::resolve_cli_base_url(None, &mem_store, false)
            .await
            .unwrap()
            .as_str(),
        "https://bsky.social/"
    );

    let pds_url = "https://custom.pds.example";
    let account = stored_pds_account(&did, pds_url);
    mem_store.save_account(&account).await.unwrap();
    mem_store.save_current_did(&did).await.unwrap();
    assert_eq!(
        petrel_load::resolve_cli_base_url(None, &mem_store, false)
            .await
            .unwrap()
            .as_str(),
        format!("{pds_url}/")
    );
    assert_eq!(
        petrel_load::resolve_cli_base_url(None, &mem_store, true)
            .await
            .unwrap()
            .as_str(),
        "https://bsky.social/"
    );
    assert_eq!(
        petrel_load::resolve_cli_base_url(Some("https://override.example"), &mem_store, false)
            .await
            .unwrap()
            .as_str(),
        "https://override.example/"
    );
}

#[tokio::test]
async fn omitted_base_url_uses_stored_account_pds_for_authenticated_run_cli() {
    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::time::{SystemTime, UNIX_EPOCH};

    use petrel::crypto::{DpopSigner, SoftwareDpopSigner};
    use petrel::oauth::{Session, SessionRecord};
    use serde_json::json;

    let did: Did = "did:plc:storedpds111111111111111".parse().unwrap();
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    let pds_url = format!("http://{addr}");
    let account = stored_pds_account(&did, &pds_url);

    let seen_requests = Arc::new(std::sync::Mutex::new(Vec::<String>::new()));
    let seen_clone = Arc::clone(&seen_requests);
    let server = std::thread::spawn(move || {
        let (mut socket, _) = listener.accept().unwrap();
        let mut buf = [0u8; 4096];
        let n = socket.read(&mut buf).unwrap();
        seen_clone
            .lock()
            .unwrap()
            .push(String::from_utf8_lossy(&buf[..n]).into_owned());
        let resp = b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}";
        socket.write_all(resp).unwrap();
    });

    let unique_ns = format!("load-stored-pds-{}", std::process::id());
    let temp_store_dir = std::fs::canonicalize(std::env::temp_dir())
        .unwrap()
        .join(format!("petrel-load-store-{unique_ns}"));
    let _ = std::fs::remove_dir_all(&temp_store_dir);
    let _cleanup = TempDirCleanup(temp_store_dir);

    let store = open_session_store(&unique_ns).unwrap();
    let signer = SoftwareDpopSigner::generate().unwrap();
    let jkt = signer.public_jwk().thumbprint().unwrap();
    store
        .save_dpop_key("key-stored", &signer.to_bytes())
        .await
        .unwrap();
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();
    let session: Session = serde_json::from_value(json!({
        "did": did,
        "access_token": "restored-access",
        "refresh_token": "restored-refresh",
        "created_at": now,
        "expires_in": 3600,
        "scope": "atproto transition:generic",
    }))
    .unwrap();
    store
        .save_session(&SessionRecord {
            account,
            session,
            dpop_key_id: "key-stored".to_owned(),
            dpop_jkt: jkt,
        })
        .await
        .unwrap();
    store.save_current_did(&did).await.unwrap();
    drop(store);

    petrel_load::run_cli(&[
        "petrel-load",
        "--namespace",
        &unique_ns,
        "--endpoint",
        "app.bsky.actor.getProfile",
        "--client-id",
        "https://client.example/oauth-client-metadata.json",
        "--redirect-uri",
        "https://client.example/callback",
        "--requests",
        "1",
        "--concurrency",
        "1",
    ])
    .await
    .unwrap();

    server.join().unwrap();
    let recorded = seen_requests.lock().unwrap();
    assert_eq!(recorded.len(), 1);
    let lower = recorded[0].to_ascii_lowercase();
    assert!(recorded[0].starts_with("GET /xrpc/app.bsky.actor.getProfile?"));
    assert!(lower.contains("\r\nauthorization: dpop restored-access\r\n"));
}
