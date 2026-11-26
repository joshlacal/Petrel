#![cfg(not(target_arch = "wasm32"))]

use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::time::{SystemTime, UNIX_EPOCH};

use petrel_server::dpop::OAuthDpopProofValidator;
use petrel_server::jose::{OAuthCompactJwt, OAuthJwsAlgorithm, OAuthSigningKey};
use petrel_server::support::OAuthPkce;
use serde::{Deserialize, Serialize};

struct RustTestServerProcess {
    child: Child,
    base_url: String,
}

impl RustTestServerProcess {
    fn spawn() -> Self {
        let bin = env!("CARGO_BIN_EXE_petrel-rust-test-server");
        let mut child = Command::new(bin)
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .expect("spawn petrel-rust-test-server");
        let stdout = child.stdout.take().expect("stdout");
        let mut reader = BufReader::new(stdout);
        let mut line = String::new();
        reader.read_line(&mut line).expect("read URL line");
        let base_url = line
            .trim()
            .strip_prefix("PETREL_TEST_SERVER_URL=")
            .expect("PETREL_TEST_SERVER_URL prefix")
            .to_owned();
        std::thread::spawn(move || {
            let mut sink = String::new();
            while reader.read_line(&mut sink).unwrap_or(0) > 0 {
                sink.clear();
            }
        });
        Self { child, base_url }
    }
}

impl Drop for RustTestServerProcess {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

#[derive(Serialize)]
struct DpopClaims<'a> {
    jti: &'a str,
    htm: &'a str,
    htu: &'a str,
    iat: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    nonce: Option<&'a str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    ath: Option<&'a str>,
}

#[derive(Serialize)]
struct ServiceJwtClaims<'a> {
    iss: &'a str,
    aud: &'a str,
    exp: i64,
    iat: i64,
    lxm: &'a str,
    jti: &'a str,
}

#[derive(Deserialize)]
struct TokBody {
    access_token: String,
    refresh_token: String,
    sub: String,
}

fn find_swift_client_probe() -> Option<PathBuf> {
    if let Some(dir) = std::env::var_os("PETREL_E2E_SERVER_BIN_DIR") {
        let candidate = PathBuf::from(dir).join("petrel-swift-client-probe");
        if candidate.is_file() {
            return Some(candidate);
        }
    }
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let server_root = manifest_dir
        .parent()?
        .parent()?
        .join("Server")
        .join(".build");
    for profile in ["debug", "release"] {
        let p = server_root.join(profile).join("petrel-swift-client-probe");
        if p.is_file() {
            return Some(p);
        }
    }
    None
}

fn extract_input(html: &str, name: &str) -> String {
    let needle = format!("name=\"{name}\" value=\"");
    let start = html.find(&needle).expect("input present") + needle.len();
    let rest = &html[start..];
    let end = rest.find('"').expect("closing quote");
    rest[..end].to_owned()
}

fn unix_now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
        .cast_signed()
}

async fn read_json<T: serde::de::DeserializeOwned>(resp: reqwest::Response) -> T {
    let bytes = resp.bytes().await.unwrap();
    serde_json::from_slice(&bytes).unwrap()
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn rust_client_against_rust_server_oauth_dpop_xrpc_and_service_auth() {
    let server = RustTestServerProcess::spawn();
    let base = server.base_url.clone();
    let http = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .unwrap();

    // Verify metadata discovery
    let meta_resp = http
        .get(format!("{base}/.well-known/oauth-authorization-server"))
        .send()
        .await
        .unwrap();
    let meta: serde_json::Value = read_json(meta_resp).await;
    assert_eq!(meta["issuer"], base);

    // Loopback OAuth flow + PKCE + DPoP nonce retry + consent CSRF cookie
    let client_id = "http://localhost";
    let redirect_uri = "http://127.0.0.1/";
    let verifier = "e2e-verifier-0123456789012345678901234567890123456789-._~";
    let challenge = OAuthPkce::s256_challenge(verifier);
    let dpop_key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();

    let par_url = format!("{base}/oauth/par");
    let first_dpop = OAuthCompactJwt::sign(
        &DpopClaims {
            jti: "par-1",
            htm: "POST",
            htu: &par_url,
            iat: unix_now(),
            nonce: None,
            ath: None,
        },
        &dpop_key,
        Some("dpop+jwt"),
        true,
    )
    .unwrap();
    let par_params = [
        ("client_id", client_id),
        ("response_type", "code"),
        ("code_challenge", challenge.as_str()),
        ("code_challenge_method", "S256"),
        ("redirect_uri", redirect_uri),
        ("scope", "atproto transition:generic"),
        ("state", "st-e2e"),
    ];
    let chal = http
        .post(&par_url)
        .header("DPoP", first_dpop)
        .form(&par_params)
        .send()
        .await
        .unwrap();
    assert_eq!(chal.status(), 400);
    let nonce = chal
        .headers()
        .get("dpop-nonce")
        .unwrap()
        .to_str()
        .unwrap()
        .to_owned();

    let par_dpop = OAuthCompactJwt::sign(
        &DpopClaims {
            jti: "par-2",
            htm: "POST",
            htu: &par_url,
            iat: unix_now(),
            nonce: Some(&nonce),
            ath: None,
        },
        &dpop_key,
        Some("dpop+jwt"),
        true,
    )
    .unwrap();
    let par_ok = http
        .post(&par_url)
        .header("DPoP", par_dpop)
        .form(&par_params)
        .send()
        .await
        .unwrap();
    assert_eq!(par_ok.status(), 201);
    let par_json: serde_json::Value = read_json(par_ok).await;
    let request_uri = par_json["request_uri"].as_str().unwrap();

    // Browser GET + POST consent
    let auth_url = url::Url::parse_with_params(
        &format!("{base}/oauth/authorize"),
        &[("client_id", client_id), ("request_uri", request_uri)],
    )
    .unwrap();
    let auth_page = http.get(auth_url).send().await.unwrap();
    assert_eq!(auth_page.status(), 200);
    let cookie = auth_page
        .headers()
        .get("set-cookie")
        .unwrap()
        .to_str()
        .unwrap()
        .split(';')
        .next()
        .unwrap()
        .to_owned();
    let html = auth_page.text().await.unwrap();
    let flow_id = extract_input(&html, "flow_id");
    let csrf_token = extract_input(&html, "csrf_token");

    let consent = http
        .post(format!("{base}/oauth/authorize"))
        .header("Cookie", cookie)
        .form(&[
            ("flow_id", flow_id.as_str()),
            ("csrf_token", csrf_token.as_str()),
            ("identifier", "alice.example"),
            ("password", "alice-password"),
            ("decision", "approve"),
        ])
        .send()
        .await
        .unwrap();
    assert_eq!(consent.status(), 303);
    let loc = consent
        .headers()
        .get("location")
        .unwrap()
        .to_str()
        .unwrap()
        .to_owned();
    let loc_url = url::Url::parse(&loc).unwrap();
    let code = loc_url
        .query_pairs()
        .find(|(k, _)| k == "code")
        .unwrap()
        .1
        .into_owned();

    // Exchange code at /oauth/token
    let tok_url = format!("{base}/oauth/token");
    let tok_dpop = OAuthCompactJwt::sign(
        &DpopClaims {
            jti: "tok-1",
            htm: "POST",
            htu: &tok_url,
            iat: unix_now(),
            nonce: Some(&nonce),
            ath: None,
        },
        &dpop_key,
        Some("dpop+jwt"),
        true,
    )
    .unwrap();
    let tok_resp = http
        .post(&tok_url)
        .header("DPoP", tok_dpop)
        .form(&[
            ("client_id", client_id),
            ("grant_type", "authorization_code"),
            ("code", code.as_str()),
            ("code_verifier", verifier),
            ("redirect_uri", redirect_uri),
        ])
        .send()
        .await
        .unwrap();
    assert_eq!(tok_resp.status(), 200);
    let tok: TokBody = read_json(tok_resp).await;
    assert_eq!(tok.sub, "did:plc:alice1234567890abcdef");
    assert_ne!(tok.refresh_token, "");

    // Protected XRPC resource call (`com.atproto.server.getSession`)
    let sess_url = format!("{base}/xrpc/com.atproto.server.getSession");
    let ath = OAuthDpopProofValidator::access_token_hash(&tok.access_token);
    let sess_dpop = OAuthCompactJwt::sign(
        &DpopClaims {
            jti: "sess-1",
            htm: "GET",
            htu: &sess_url,
            iat: unix_now(),
            nonce: Some(&nonce),
            ath: Some(&ath),
        },
        &dpop_key,
        Some("dpop+jwt"),
        true,
    )
    .unwrap();
    let sess_resp = http
        .get(&sess_url)
        .header("Authorization", format!("DPoP {}", tok.access_token))
        .header("DPoP", sess_dpop)
        .send()
        .await
        .unwrap();
    assert_eq!(sess_resp.status(), 200);
    let sess_json: serde_json::Value = read_json(sess_resp).await;
    assert_eq!(sess_json["did"], "did:plc:alice1234567890abcdef");

    // Service auth registration + authenticated XRPC query with typed FromQueryParams
    let sa_did = "did:plc:alice234567234567abcdefg";
    let sa_key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256k, None).unwrap();
    let reg_sa_body = serde_json::to_vec(&serde_json::json!({
        "did": sa_did,
        "jwk": sa_key.public_jwk(false).unwrap()
    }))
    .unwrap();
    let reg_sa = http
        .post(format!("{base}/_test/registerServiceAuthKey"))
        .header("Content-Type", "application/json")
        .body(reg_sa_body)
        .send()
        .await
        .unwrap();
    assert_eq!(reg_sa.status(), 201);

    let sa_jwt = OAuthCompactJwt::sign(
        &ServiceJwtClaims {
            iss: sa_did,
            aud: "did:web:e2e.catbird.invalid#atproto_xrpc",
            exp: unix_now() + 60,
            iat: unix_now(),
            lxm: "app.bsky.feed.getTimeline",
            jti: "e2e-sa-1",
        },
        &sa_key,
        Some("JWT"),
        false,
    )
    .unwrap();
    let timeline = http
        .get(format!("{base}/xrpc/app.bsky.feed.getTimeline?limit=12"))
        .header("Authorization", format!("Bearer {sa_jwt}"))
        .send()
        .await
        .unwrap();
    assert_eq!(timeline.status(), 200);
    let tl_json: serde_json::Value = read_json(timeline).await;
    assert_eq!(tl_json["cursor"], format!("did={sa_did}&limit=12"));

    // Strict XRPC procedure validation & declared error check
    let bad_put_body = serde_json::to_vec(&serde_json::json!({
        "repo": "did:plc:alice1234567890abcdef",
        "collection": "app.bsky.feed.post",
        "rkey": "3k7b",
        "validate": "invalid-string-instead-of-bool",
        "record": { "$type": "app.bsky.feed.post", "text": "hello" }
    }))
    .unwrap();
    let bad_put = http
        .post(format!("{base}/xrpc/com.atproto.repo.putRecord"))
        .header("Content-Type", "application/json")
        .body(bad_put_body)
        .send()
        .await
        .unwrap();
    assert_eq!(bad_put.status(), 400);

    let swap_put_body = serde_json::to_vec(&serde_json::json!({
        "repo": "did:plc:alice1234567890abcdef",
        "collection": "app.bsky.feed.post",
        "rkey": "conflict",
        "record": { "$type": "app.bsky.feed.post", "text": "hello" }
    }))
    .unwrap();
    let swap_put = http
        .post(format!("{base}/xrpc/com.atproto.repo.putRecord"))
        .header("Content-Type", "application/json")
        .body(swap_put_body)
        .send()
        .await
        .unwrap();
    assert_eq!(swap_put.status(), 409);
    let swap_json: serde_json::Value = read_json(swap_put).await;
    assert_eq!(swap_json["error"], "InvalidSwap");
}

#[tokio::test]
async fn swift_petrel_client_against_rust_petrel_server() {
    let Some(probe_bin) = find_swift_client_probe() else {
        assert!(
            std::env::var_os("PETREL_E2E_REQUIRED").is_none(),
            "PETREL_E2E_REQUIRED is set but petrel-swift-client-probe binary is missing"
        );
        eprintln!(
            "skipping swift_petrel_client_against_rust_petrel_server: petrel-swift-client-probe not built"
        );
        return;
    };

    let server = RustTestServerProcess::spawn();
    let status = Command::new(&probe_bin)
        .arg("--base-url")
        .arg(&server.base_url)
        .status()
        .expect("run petrel-swift-client-probe");
    assert!(
        status.success(),
        "Swift Petrel client probe failed against Rust petrel-server at {}",
        server.base_url
    );
}
