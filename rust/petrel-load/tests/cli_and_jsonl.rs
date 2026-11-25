//! Ported PetrelLoad CLI and AuthEvent JSONL writer tests.
#![cfg(not(target_arch = "wasm32"))]

use std::io::Cursor;
use std::process::Command;
use std::sync::Arc;

use petrel::oauth::Account;
use petrel::storage::{MemorySecretStore, SessionStore};
use petrel_core::Did;
use petrel_load::{
    ArgumentError, AuthEventJsonlWriter, AuthEventRecorderHandle, CallbackReadError,
    CliOAuthConfig, OAuthMetadataError, OAuthMetadataResponse, PetrelLoadCli, ScenarioPlan,
};
use serde_json::Value as JsonValue;
use tempfile::NamedTempFile;
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
