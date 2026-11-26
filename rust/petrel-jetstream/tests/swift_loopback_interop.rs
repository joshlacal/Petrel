#![cfg(not(target_arch = "wasm32"))]

use std::env;
use std::ffi::OsStr;
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::Arc;

use base64::Engine as _;
use futures_util::{SinkExt, StreamExt};
use petrel_firehose::{
    FirehoseFrameEncoder, FirehoseSubscription, FirehoseSubscriptionConfiguration,
    FirehoseSubscriptionEvent, FirehoseWebSocketOptions, PublicFirehoseAccountMaterial,
    PublicFirehoseAccountStatus, PublicFirehoseIdentityMaterial, RelayEvent,
    TungsteniteWebSocketFactory,
};
use petrel_jetstream::{
    JetstreamEvent, JetstreamSubscription, JetstreamSubscriptionConfiguration,
    JetstreamSubscriptionEvent,
};
use serde_json::json;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;
use tokio_tungstenite::tungstenite::Message;
use url::Url;

const BIN_ENV: &str = "PETREL_SWIFT_STREAM_PROBE_BIN";
const REQUIRED_ENV: &str = "PETREL_SWIFT_INTEROP_REQUIRED";

const STRUCT_DICT_B64: &str = "N6Qw7IHCfhEWEBjdAQAAAAAAAPD8////qJJCSrgdCgMxGAwGg5ra06WZbRtEgAABggsJDlAMCAgICAgICDgoCAgICAgICAwICAgICAgIWgiEZ0IIIYQQIiIiDwQ4cxAEQRAEQRAEQRAEIYQQQgghhIiIyAMBAAAABAAAAAgAAABudHMjY29tbWl0Iiwic2VxIjo3LCJkaWQiOiJkaWQ6cGxjOnVzZXIwMDA3IiwidGltZWVudHMjY29tbWl0Iiwic2VxIjo3LCJkaWQiOiJkaWQ6cGxjOnVzZXIwMDAyIiwidGltZW50cyNjb21taXQiLCJzZXEiOjcsImRpZCI6ImRpZDpwbGM6dXNlcjAwMDYiLCJ0aW1lbnRzI2NvbW1pdCIsInNlcSI6NywiZGlkIjoiZGlkOnBsYzp1c2VyMDAxMSIsInRpbWVudHMjY29tbWl0Iiwic2VxIjo3LCJkaWQiOiJkaWQ6cGxjOnVzZXIwMDEzIiwidGltZW50cyNjb21taXQiLCJzZXEiOjcsImRpZCI6ImRpZDpwbGM6dXNlcjAwMDgiLCJ0aW1udHMjY29tbWl0Iiwic2VxIjo3LCJkaWQiOiJkaWQ6cGxjOnVzZXIwMDAzIiwidGltZW50cyNjb21taXQiLCJzZXEiOjcsImRpZCI6ImRpZDpwbGM6dXNlcjAwMDQiLCJ0aW1lbnRzI2NvbW1pdCIsInNlcSI6NywiZGlkIjoiZGlkOnBsYzp1c2VyMDAxNSIsInRpbWVudHMjY29tbWl0Iiwic2VxIjo3LCJkaWQiOiJkaWQ6cGxjOnVzZXIwMDEyIiwidGltZW50cyNjb21taXQiLCJzZXEiOjcsImRpZCI6ImRpZDpwbGM6dXNlcjAwMTYiLCJ0aW1lbnRzI2NvbW1pdCIsInNlcSI6NywiZGlkIjoiZGlkOnBsYzp1c2VyMDAwMCIsInRpbWVudHMjY29tbWl0Iiwic2VxIjo3LCJkaWQiOiJkaWQ6cGxjOnVzZXIwMDE4IiwidGltZWlvbiI6ImFwcC5ic2t5LmZlZWQucG9zdCIsInJrZXkiOiIzazd2MmFiYzIzNDU2In19Iiwic2VxIjo3LCJkaWQiOiJkaWQ6cGxjOnVzZXIwMDAxIiwidGltZSI6IjIwMjYtMDFjMjM0NTYiLCJvcGVyYXRpb24iOiJjcmVhdGUiLCJjb2xsZWN0aW9uIjoiYXBwLmJzay5ic2t5LmpldHN0cmVhbS5zdWJzY3JpYmVFdmVudHMjY29tbWl0Iiwic2VxIjo3LCJkdHlwZSI6Im1lc3NhZ2UiLCJwYXlsb2FkIjp7IiR0eXBlIjoibmV0d29yay5ic2t5LmoyMDI2LTAxLTAxVDAwOjAwOjAwLjEyMzQ1NloiLCJyZXYiOiIzazd2MmFiYzIzNDU2Ig==";
const STRUCT_FRAME_B64: &str = "KLUv/SeBwn4R/MUAABhhYmMI/PIFrvN6oGRa5APM0VFrswcyeLneKeg=";

fn find_swift_probe_bin() -> Option<PathBuf> {
    if let Some(p) = env::var_os(BIN_ENV).filter(|v| !v.is_empty()) {
        let path = PathBuf::from(p);
        assert!(
            path.is_file(),
            "{BIN_ENV} points to missing file: {}",
            path.display()
        );
        return Some(path);
    }

    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    for rel in [
        "tests/swift_streaming_probe/.build/debug/petrel-swift-stream-probe",
        "tests/swift_streaming_probe/.build/out/Products/Debug/petrel-swift-stream-probe",
    ] {
        let candidate = manifest_dir.join(rel);
        if candidate.is_file() {
            return Some(candidate);
        }
    }

    let required = env::var_os(REQUIRED_ENV).as_deref() == Some(OsStr::new("1"));
    assert!(
        !required,
        "set {BIN_ENV} or build tests/swift_streaming_probe ({REQUIRED_ENV}=1)"
    );
    eprintln!(
        "skipped: set {BIN_ENV} or build tests/swift_streaming_probe to run Swift<->Rust stream interop"
    );
    None
}

async fn next_timeout<T, S>(stream: &mut S, label: &str) -> T
where
    S: futures_util::Stream<Item = T> + Unpin,
{
    tokio::time::timeout(std::time::Duration::from_secs(5), stream.next())
        .await
        .unwrap_or_else(|_| panic!("timeout {label}"))
        .unwrap_or_else(|| panic!("stream ended early before {label}"))
}

async fn verify_rust_firehose_from_swift(f_port: u16) {
    let f_url = Url::parse(&format!(
        "ws://127.0.0.1:{f_port}/xrpc/com.atproto.sync.subscribeRepos"
    ))
    .unwrap();
    let mut f_cfg = FirehoseSubscriptionConfiguration::new(f_url);
    f_cfg.session_factory = Arc::new(TungsteniteWebSocketFactory::new());
    let f_sub = FirehoseSubscription::new(f_cfg);
    let mut f_stream = f_sub.events();

    let e1 = next_timeout(&mut f_stream, "e1").await.unwrap();
    assert!(matches!(
        e1,
        FirehoseSubscriptionEvent::Event(RelayEvent::Identity(ref id))
            if id.seq == 1 && id.did == "did:plc:swiftinterop" && id.handle.as_deref() == Some("swift.interop.test")
    ));
    let e2 = next_timeout(&mut f_stream, "e2").await.unwrap();
    assert!(matches!(
        e2,
        FirehoseSubscriptionEvent::Event(RelayEvent::Account(ref acct))
            if acct.seq == 2 && !acct.active && acct.status.as_deref() == Some("deactivated")
    ));
    let e3 = next_timeout(&mut f_stream, "e3").await.unwrap();
    assert!(matches!(
        e3,
        FirehoseSubscriptionEvent::Event(RelayEvent::Info(ref info))
            if info.name == "SwiftInfo" && info.message.as_deref() == Some("hello-rust")
    ));
}

async fn verify_rust_jetstream_from_swift(j_port: u16) {
    let j_url = Url::parse(&format!("http://127.0.0.1:{j_port}")).unwrap();
    let mut j_cfg = JetstreamSubscriptionConfiguration::new(j_url);
    j_cfg.compression = true;
    j_cfg.backoff = petrel_firehose::FirehoseBackoffConfiguration {
        initial_delay: std::time::Duration::from_millis(10),
        max_delay: std::time::Duration::from_millis(50),
        multiplier: 2.0,
        jitter: 0.0,
    };
    j_cfg.session_factory = Arc::new(TungsteniteWebSocketFactory::with_options(
        FirehoseWebSocketOptions::jetstream(),
    ));
    let j_sub = JetstreamSubscription::new(j_cfg);
    let mut j_stream = j_sub.events();

    let j1 = next_timeout(&mut j_stream, "j1").await.unwrap();
    assert!(
        matches!(
            j1,
            JetstreamSubscriptionEvent::Event(JetstreamEvent::Commit(ref c))
                if c.seq == 1 && c.did == "did:plc:swiftjet"
        ),
        "unexpected j1: {j1:?}"
    );
    let j2 = next_timeout(&mut j_stream, "j2").await.unwrap();
    assert!(
        matches!(
            j2,
            JetstreamSubscriptionEvent::Event(JetstreamEvent::Commit(ref c))
                if c.seq == 2 && c.did == "did:plc:swiftjet" && c.decoded_record().is_some()
        ),
        "unexpected j2: {j2:?}"
    );
}

#[tokio::test]
async fn swift_loopback_server_to_rust_firehose_and_jetstream_clients() {
    let Some(bin) = find_swift_probe_bin() else {
        return;
    };

    let mut child = Command::new(&bin)
        .arg("serve")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .expect("spawn swift probe serve");

    let mut stdin = child.stdin.take().unwrap();
    let stdout = child.stdout.take().unwrap();
    let mut lines = BufReader::new(stdout).lines();

    let mut firehose_port: Option<u16> = None;
    let mut jetstream_port: Option<u16> = None;
    for _ in 0..10 {
        let Some(Ok(line)) = lines.next() else {
            break;
        };
        if let Some(v) = line.strip_prefix("FIREHOSE_PORT=") {
            firehose_port = v.trim().parse().ok();
        } else if let Some(v) = line.strip_prefix("JETSTREAM_PORT=") {
            jetstream_port = v.trim().parse().ok();
        }
        if firehose_port.is_some() && jetstream_port.is_some() {
            break;
        }
    }

    let f_port = firehose_port.expect("FIREHOSE_PORT from swift probe");
    let j_port = jetstream_port.expect("JETSTREAM_PORT from swift probe");

    verify_rust_firehose_from_swift(f_port).await;
    verify_rust_jetstream_from_swift(j_port).await;

    let _ = stdin.write_all(b"\n");
    drop(stdin);
    let status = child.wait().unwrap();
    assert!(status.success());
}

async fn spawn_rust_firehose_server() -> (u16, tokio::task::JoinHandle<()>) {
    let f_listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let f_port = f_listener.local_addr().unwrap().port();
    let f1 = FirehoseFrameEncoder::identity_frame(
        1,
        &PublicFirehoseIdentityMaterial {
            did: "did:plc:rustinterop".to_owned(),
            handle: Some("rust.interop.test".to_owned()),
            time: "2026-01-01T00:00:00.000Z".to_owned(),
        },
    )
    .unwrap();
    let f2 = FirehoseFrameEncoder::account_frame(
        2,
        &PublicFirehoseAccountMaterial {
            did: "did:plc:rustinterop".to_owned(),
            active: false,
            status: Some(PublicFirehoseAccountStatus::Suspended),
            time: "2026-01-01T00:00:01.000Z".to_owned(),
        },
    )
    .unwrap();
    let f3 = FirehoseFrameEncoder::info_frame("RustInfo", Some("hello-swift")).unwrap();

    let handle = tokio::spawn(async move {
        let (stream, _) = f_listener.accept().await.unwrap();
        let mut ws = tokio_tungstenite::accept_async(stream).await.unwrap();
        ws.send(Message::Binary(f1.into())).await.unwrap();
        ws.send(Message::Binary(f2.into())).await.unwrap();
        ws.send(Message::Binary(f3.into())).await.unwrap();
        ws.close(None).await.unwrap();
    });
    (f_port, handle)
}

async fn spawn_rust_jetstream_server() -> (u16, tokio::task::JoinHandle<()>) {
    let b64 = base64::engine::general_purpose::STANDARD;
    let struct_dict = b64.decode(STRUCT_DICT_B64).unwrap();
    let struct_frame = b64.decode(STRUCT_FRAME_B64).unwrap();
    let j_text = serde_json::to_string(&json!({
        "$type": "message",
        "payload": {
            "$type": "network.bsky.jetstream.subscribeEvents#commit",
            "seq": 1,
            "did": "did:plc:rustjet",
            "time": "2026-01-01T00:00:00.000000Z",
            "rev": "3k7v2abc23456",
            "operation": "create",
            "collection": "app.bsky.feed.post",
            "rkey": "3k7v2abc23456"
        }
    }))
    .unwrap();

    let j_listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let j_port = j_listener.local_addr().unwrap().port();
    let handle = tokio::spawn(async move {
        for _ in 0..2 {
            let (mut sock, _) = j_listener.accept().await.unwrap();
            let mut buf = [0u8; 2048];
            let n = sock.peek(&mut buf).await.unwrap();
            let req_head = String::from_utf8_lossy(&buf[..n]);
            if req_head.contains("getZstdDictionary") {
                let mut drain = vec![0u8; n];
                let _ = sock.read_exact(&mut drain).await;
                let resp_hdr = format!(
                    "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                    struct_dict.len()
                );
                sock.write_all(resp_hdr.as_bytes()).await.unwrap();
                sock.write_all(&struct_dict).await.unwrap();
                sock.shutdown().await.unwrap();
            } else {
                let mut ws = tokio_tungstenite::accept_async(sock).await.unwrap();
                ws.send(Message::Text(j_text.clone().into())).await.unwrap();
                ws.send(Message::Binary(struct_frame.clone().into()))
                    .await
                    .unwrap();
                ws.close(None).await.unwrap();
                break;
            }
        }
    });
    (j_port, handle)
}

#[tokio::test]
async fn rust_loopback_server_to_swift_firehose_and_jetstream_clients() {
    let Some(bin) = find_swift_probe_bin() else {
        return;
    };

    let (f_port, f_task) = spawn_rust_firehose_server().await;
    let (j_port, j_task) = spawn_rust_jetstream_server().await;

    let firehose_url = format!("ws://127.0.0.1:{f_port}/xrpc/com.atproto.sync.subscribeRepos");
    let jetstream_url = format!("http://127.0.0.1:{j_port}");

    let output = tokio::task::spawn_blocking(move || {
        Command::new(&bin)
            .args([
                "consume",
                "--firehose-url",
                &firehose_url,
                "--jetstream-url",
                &jetstream_url,
            ])
            .output()
            .expect("run swift probe consume")
    })
    .await
    .unwrap();

    assert!(
        output.status.success(),
        "swift probe consume failed ({}): stdout={}, stderr={}",
        output.status,
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("SWIFT_CONSUME_OK"), "stdout={stdout}");

    f_task.await.unwrap();
    j_task.await.unwrap();
}
