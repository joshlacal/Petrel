use std::collections::VecDeque;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

use async_lock::Mutex;
use base64::Engine as _;
use bytes::Bytes;
use futures_util::StreamExt;
use petrel::net::TransportError;
use petrel::rt::BoxFuture;
use petrel_firehose::{
    FirehoseBackoffConfiguration, FirehoseCursorStorage, FirehoseSubscriptionError,
    FirehoseWebSocketSession, FirehoseWebSocketSessionFactory, InMemoryFirehoseCursorStorage,
};
use petrel_jetstream::{
    CursorStorageOperation, JetstreamApiVersion, JetstreamEvent, JetstreamHttpTransport,
    JetstreamIgnoredReason, JetstreamOptionsUpdate, JetstreamSubscription,
    JetstreamSubscriptionConfiguration, JetstreamSubscriptionError, JetstreamSubscriptionEvent,
    build_legacy_websocket_url, build_websocket_url,
};
use serde_json::json;
use url::Url;

#[cfg(not(target_arch = "wasm32"))]
use tokio::test as async_test;
#[cfg(target_arch = "wasm32")]
use wasm_bindgen_test::wasm_bindgen_test as async_test;

const RAW_DICT_B64: &str = "YXBwLmJza3kuZmVlZC5wb3N0YXBwLmJza3kuZ3JhcGguZm9sbG93ZGlkOnBsYzp7IiR0eXBlIjoibWVzc2FnZSIsInBheWxvYWQiOnsiY29sbGVjdGlvbiI6ImFwcC5ic2t5LmZlZWQucG9zdCJ9fQ==";
const RAW_FRAME_B64: &str = "KLUv/ST8XQQAkggcHGCJdRCdDUmJwQpiEePiKNHoNlb8svc1gQIAOC7Pk9iFr/pttwwdb6G5niHHUvA55STLeruzfP2AIcdSyWgICRIqEiqYQurtK2NfD597uxKVa9Ju2Hl9RykbCJjNrBPYFxnOd5iGdMs9ewkLN4heJggAUcwFbYNbatxbFyNiRjbDjAVKBNEEILneKeg=";
#[cfg(not(target_arch = "wasm32"))]
const RAW_V1_FRAME_B64: &str = "KLUv/SSvRQMAgoUTGYC3bbbjsQXjNyEstjdG5NYz6yaynDmYlRHLUtjVv5bbmr0C5HdCJXTUyJMUCx2fbF/Be2PGEA3w+hEqoWOGwuAHBMAybr+rkccffFwJCABRzLUxBCZj2oJxjuX5VMvDXaDeEAf8Xk7/";

type HttpHandlerFn = Arc<
    dyn Fn(&http::Request<Bytes>) -> Result<http::Response<Bytes>, TransportError> + Send + Sync,
>;

#[derive(Clone)]
struct ScriptedHttp {
    handler: HttpHandlerFn,
}

impl std::fmt::Debug for ScriptedHttp {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ScriptedHttp").finish_non_exhaustive()
    }
}

impl JetstreamHttpTransport for ScriptedHttp {
    fn send(
        &self,
        request: http::Request<Bytes>,
    ) -> BoxFuture<'_, Result<http::Response<Bytes>, TransportError>> {
        let h = Arc::clone(&self.handler);
        Box::pin(async move { h(&request) })
    }
}

#[derive(Debug)]
struct ScriptedWs {
    actions: Mutex<VecDeque<Result<Vec<u8>, FirehoseSubscriptionError>>>,
    sent_texts: Mutex<Vec<String>>,
    closed: AtomicBool,
}

impl ScriptedWs {
    fn new(actions: Vec<Result<Vec<u8>, FirehoseSubscriptionError>>) -> Self {
        Self {
            actions: Mutex::new(VecDeque::from(actions)),
            sent_texts: Mutex::new(Vec::new()),
            closed: AtomicBool::new(false),
        }
    }
}

#[derive(Debug)]
struct ScriptedWsFactory {
    outcomes: Mutex<VecDeque<Result<Arc<ScriptedWs>, FirehoseSubscriptionError>>>,
    urls: Mutex<Vec<Url>>,
    subprotocols: Mutex<Vec<Vec<String>>>,
}

impl ScriptedWsFactory {
    fn new(outcomes: Vec<Result<Arc<ScriptedWs>, FirehoseSubscriptionError>>) -> Self {
        Self {
            outcomes: Mutex::new(VecDeque::from(outcomes)),
            urls: Mutex::new(Vec::new()),
            subprotocols: Mutex::new(Vec::new()),
        }
    }
}

#[derive(Debug)]
struct WrapWs(Arc<ScriptedWs>);

impl FirehoseWebSocketSession for WrapWs {
    fn receive_message(&self) -> BoxFuture<'_, Result<Vec<u8>, FirehoseSubscriptionError>> {
        Box::pin(async move {
            if self.0.closed.load(Ordering::SeqCst) {
                return Err(FirehoseSubscriptionError::ConnectionClosed);
            }
            self.0
                .actions
                .lock()
                .await
                .pop_front()
                .unwrap_or(Err(FirehoseSubscriptionError::ConnectionClosed))
        })
    }

    fn close(&self) -> BoxFuture<'_, ()> {
        Box::pin(async move {
            self.0.closed.store(true, Ordering::SeqCst);
        })
    }

    fn send_text<'a>(
        &'a self,
        text: &'a str,
    ) -> BoxFuture<'a, Result<(), FirehoseSubscriptionError>> {
        Box::pin(async move {
            self.0.sent_texts.lock().await.push(text.to_owned());
            Ok(())
        })
    }
}

impl FirehoseWebSocketSessionFactory for ScriptedWsFactory {
    fn make_session(
        &self,
        url: Url,
    ) -> BoxFuture<'_, Result<Box<dyn FirehoseWebSocketSession>, FirehoseSubscriptionError>> {
        self.make_session_with_subprotocols(url, Vec::new())
    }

    fn make_session_with_subprotocols(
        &self,
        url: Url,
        subprotocols: Vec<String>,
    ) -> BoxFuture<'_, Result<Box<dyn FirehoseWebSocketSession>, FirehoseSubscriptionError>> {
        Box::pin(async move {
            self.urls.lock().await.push(url);
            self.subprotocols.lock().await.push(subprotocols);
            self.outcomes
                .lock()
                .await
                .pop_front()
                .unwrap_or(Err(FirehoseSubscriptionError::ConnectionClosed))
                .map(|s| Box::new(WrapWs(s)) as Box<dyn FirehoseWebSocketSession>)
        })
    }
}

#[derive(Debug)]
struct FailingStorage {
    fail_load: bool,
    fail_save: bool,
}

impl FirehoseCursorStorage for FailingStorage {
    fn load_cursor(&self) -> BoxFuture<'_, Result<Option<i64>, FirehoseSubscriptionError>> {
        let fail = self.fail_load;
        Box::pin(async move {
            if fail {
                Err(FirehoseSubscriptionError::StorageFailure)
            } else {
                Ok(None)
            }
        })
    }

    fn save_cursor(&self, _cursor: i64) -> BoxFuture<'_, Result<(), FirehoseSubscriptionError>> {
        let fail = self.fail_save;
        Box::pin(async move {
            if fail {
                Err(FirehoseSubscriptionError::StorageFailure)
            } else {
                Ok(())
            }
        })
    }
}

fn fast_backoff() -> FirehoseBackoffConfiguration {
    FirehoseBackoffConfiguration {
        initial_delay: Duration::from_millis(1),
        max_delay: Duration::from_millis(2),
        multiplier: 2.0,
        jitter: 0.0,
    }
}

#[test]
fn url_builders_derive_v2_and_v1_urls() {
    let base = Url::parse("https://jet.example/base").unwrap();
    let filter = petrel_jetstream::JetstreamFilter {
        kinds: vec![petrel_jetstream::JetstreamKind::Commit],
        dids: vec!["did:plc:abc".to_owned()],
        collections: vec!["app.bsky.feed.post".to_owned()],
    };
    let v2 = build_websocket_url(&base, &filter, Some(42), Some(99));
    assert_eq!(
        v2.as_str(),
        "wss://jet.example/base/xrpc/network.bsky.jetstream.subscribeEvents?kinds=commit&dids=did%3Aplc%3Aabc&collections=app.bsky.feed.post&cursor=42&zstdDictionary=99"
    );

    let v1 = build_legacy_websocket_url(&base, &filter, Some(100), true, Some(1024), true);
    assert_eq!(
        v1.as_str(),
        "wss://jet.example/base/subscribe?wantedCollections=app.bsky.feed.post&wantedDids=did%3Aplc%3Aabc&cursor=100&compress=true&maxMessageSizeBytes=1024&requireHello=true"
    );
}

#[async_test]
async fn v2_subscription_probes_errors_retries_unknown_dict_and_reports_ignored() {
    let b64 = base64::engine::general_purpose::STANDARD;
    let raw_dict = b64.decode(RAW_DICT_B64).unwrap();
    let raw_frame = b64.decode(RAW_FRAME_B64).unwrap();

    // First upgrade rejected, HTTP probe returns UnknownZstdDictionary -> re-fetches dict & retries!
    let http = Arc::new(ScriptedHttp {
        handler: Arc::new(move |req| {
            if req.uri().path().ends_with("getZstdDictionary") {
                Ok(http::Response::builder()
                    .status(200)
                    .body(Bytes::from(raw_dict.clone()))
                    .unwrap())
            } else {
                Ok(http::Response::builder()
                    .status(400)
                    .body(Bytes::from(
                        serde_json::to_vec(&json!({
                            "error": "UnknownZstdDictionary",
                            "message": "expired"
                        }))
                        .unwrap(),
                    ))
                    .unwrap())
            }
        }),
    });

    let ws_ok = Arc::new(ScriptedWs::new(vec![
        Ok(raw_frame),
        Ok(b"{not json".to_vec()),
        Ok(serde_json::to_vec(&json!({
            "$type": "message",
            "payload": {
                "$type": "network.bsky.jetstream.subscribeEvents#commit",
                "seq": 7, // duplicate seq 7 -> IgnoredFrame(DuplicateSequence)
                "did": "did:plc:abc", "time": "2026-01-01T00:00:00Z",
                "rev": "3k7v2abc23456", "operation": "create", "collection": "app.bsky.feed.post", "rkey": "r"
            }
        }))
        .unwrap()),
    ]));

    let factory = Arc::new(ScriptedWsFactory::new(vec![
        Err(FirehoseSubscriptionError::UpgradeRejected {
            status: 400,
            retry_after_ms: None,
        }),
        Ok(ws_ok.clone()),
    ]));

    let cursor_storage = Arc::new(InMemoryFirehoseCursorStorage::new());
    let mut cfg =
        JetstreamSubscriptionConfiguration::new(Url::parse("https://jet.example").unwrap());
    cfg.compression = true;
    cfg.cursor_storage = Some(cursor_storage.clone());
    cfg.session_factory = factory.clone();
    cfg.http_transport = http;
    cfg.backoff = fast_backoff();

    let sub = JetstreamSubscription::new(cfg);
    assert_eq!(
        sub.configuration.resolved_api_version(),
        JetstreamApiVersion::V2
    );
    // update_options on v2 must return OptionsUpdateUnsupported
    assert_eq!(
        sub.update_options(JetstreamOptionsUpdate::default()).await,
        Err(JetstreamSubscriptionError::OptionsUpdateUnsupported)
    );

    let mut stream = sub.events();
    let first = stream.next().await.unwrap().unwrap();
    assert!(
        matches!(first, JetstreamSubscriptionEvent::Event(JetstreamEvent::Commit(ref c)) if c.seq == 7)
    );
    let second = stream.next().await.unwrap().unwrap();
    assert!(matches!(
        second,
        JetstreamSubscriptionEvent::IgnoredFrame(ref ig)
            if matches!(ig.reason, JetstreamIgnoredReason::MalformedFrame(_))
    ));
    let third = stream.next().await.unwrap().unwrap();
    assert!(matches!(
        third,
        JetstreamSubscriptionEvent::IgnoredFrame(ref ig)
            if ig.reason == JetstreamIgnoredReason::DuplicateSequence(7)
    ));
    assert_eq!(
        factory.subprotocols.lock().await[0],
        vec!["xrpc.v1.json".to_owned()]
    );

    drop(stream);
    #[cfg(not(target_arch = "wasm32"))]
    tokio::task::yield_now().await;
    #[cfg(target_arch = "wasm32")]
    petrel::rt::sleep(Duration::from_millis(0)).await;
    assert!(ws_ok.closed.load(Ordering::SeqCst));
}

#[async_test]
async fn legacy_v1_subscription_sends_hello_and_options_update_and_dedups_same_time_us() {
    let f1 = serde_json::to_vec(&json!({
        "did": "did:plc:a", "time_us": 1000, "kind": "commit",
        "commit": { "rev": "3k7a", "operation": "create", "collection": "app.bsky.feed.post", "rkey": "1" }
    }))
    .unwrap();
    let f1_dup = f1.clone();
    let f1_distinct = serde_json::to_vec(&json!({
        "did": "did:plc:b", "time_us": 1000, "kind": "commit",
        "commit": { "rev": "3k7b", "operation": "create", "collection": "app.bsky.feed.post", "rkey": "2" }
    }))
    .unwrap();

    let ws = Arc::new(ScriptedWs::new(vec![Ok(f1), Ok(f1_dup), Ok(f1_distinct)]));
    let factory = Arc::new(ScriptedWsFactory::new(vec![Ok(ws.clone())]));

    let mut cfg =
        JetstreamSubscriptionConfiguration::new(Url::parse("wss://jet.example/subscribe").unwrap());
    cfg.require_hello = true;
    cfg.filter.collections = vec!["app.bsky.feed.post".to_owned()];
    cfg.session_factory = factory;
    cfg.backoff = fast_backoff();

    let sub = JetstreamSubscription::new(cfg);
    assert_eq!(
        sub.configuration.resolved_api_version(),
        JetstreamApiVersion::V1
    );
    let mut stream = sub.events();

    let ev1 = stream.next().await.unwrap().unwrap();
    assert!(
        matches!(ev1, JetstreamSubscriptionEvent::Event(JetstreamEvent::Commit(ref c)) if c.did == "did:plc:a")
    );

    sub.update_options(JetstreamOptionsUpdate {
        wanted_collections: vec!["app.bsky.feed.*".to_owned()],
        wanted_dids: vec![],
        max_message_size_bytes: 2048,
    })
    .await
    .unwrap();

    let ev2 = stream.next().await.unwrap().unwrap();
    assert!(
        matches!(ev2, JetstreamSubscriptionEvent::Event(JetstreamEvent::Commit(ref c)) if c.did == "did:plc:b")
    );

    let sent = ws.sent_texts.lock().await;
    assert_eq!(sent.len(), 2); // initial requireHello options_update + live update_options!
    assert!(sent[0].contains("\"options_update\""));
    assert!(sent[1].contains("2048"));
}

#[async_test]
async fn silent_failure_checks_storage_errors_and_missing_legacy_dict() {
    let mut cfg =
        JetstreamSubscriptionConfiguration::new(Url::parse("wss://jet.example/subscribe").unwrap());
    cfg.compression = true;
    cfg.backoff = fast_backoff();
    let sub = JetstreamSubscription::new(cfg);
    assert_eq!(
        sub.events().next().await.unwrap(),
        Err(JetstreamSubscriptionError::MissingZstdDictionary)
    );

    let mut cfg_load =
        JetstreamSubscriptionConfiguration::new(Url::parse("https://jet.example").unwrap());
    cfg_load.cursor_storage = Some(Arc::new(FailingStorage {
        fail_load: true,
        fail_save: false,
    }));
    let sub_load = JetstreamSubscription::new(cfg_load);
    assert!(matches!(
        sub_load.events().next().await.unwrap(),
        Err(JetstreamSubscriptionError::CursorStorageFailure {
            operation: CursorStorageOperation::Load,
            ..
        })
    ));

    // Explicit cursor overrides persisted cursor storage (must NOT overwrite 100 with 200).
    let storage = Arc::new(InMemoryFirehoseCursorStorage::with_initial_cursor(Some(
        200,
    )));
    let f100 = serde_json::to_vec(&json!({
        "$type": "message",
        "payload": {
            "$type": "network.bsky.jetstream.subscribeEvents#commit",
            "seq": 100, "did": "did:plc:explicit", "time": "2026-01-01T00:00:00Z",
            "rev": "3k7v2abc23456", "operation": "create", "collection": "app.bsky.feed.post", "rkey": "r100"
        }
    }))
    .unwrap();
    let ws = Arc::new(ScriptedWs::new(vec![Ok(f100)]));
    let factory = Arc::new(ScriptedWsFactory::new(vec![Ok(ws)]));
    let mut cfg_explicit =
        JetstreamSubscriptionConfiguration::new(Url::parse("https://jet.example").unwrap());
    cfg_explicit.cursor = Some(100);
    cfg_explicit.cursor_storage = Some(storage);
    cfg_explicit.session_factory = factory.clone();
    cfg_explicit.backoff = fast_backoff();
    let sub_explicit = JetstreamSubscription::new(cfg_explicit);
    let first = sub_explicit.events().next().await.unwrap().unwrap();
    assert!(matches!(
        first,
        JetstreamSubscriptionEvent::Event(JetstreamEvent::Commit(ref c)) if c.seq == 100
    ));
    let urls = factory.urls.lock().await;
    assert_eq!(urls.len(), 1);
    assert!(
        urls[0].query().unwrap_or("").contains("cursor=100"),
        "expected explicit cursor=100, got {}",
        urls[0]
    );
}

#[cfg(not(target_arch = "wasm32"))]
#[tokio::test]
async fn native_loopback_websocket_streams_compressed_json_and_options_update() {
    use futures_util::SinkExt;
    use petrel_firehose::{FirehoseWebSocketOptions, TungsteniteWebSocketFactory};
    use tokio::net::TcpListener;
    use tokio_tungstenite::tungstenite::Message;

    let b64 = base64::engine::general_purpose::STANDARD;
    let raw_dict = b64.decode(RAW_DICT_B64).unwrap();
    let raw_frame = b64.decode(RAW_V1_FRAME_B64).unwrap();
    let raw_frame_c = raw_frame.clone();

    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();

    let server_task = tokio::spawn(async move {
        let (stream, _) = listener.accept().await.unwrap();
        let mut ws = tokio_tungstenite::accept_async(stream).await.unwrap();
        // Expect initial requireHello options_update text message from client!
        let hello = ws.next().await.unwrap().unwrap();
        let Message::Text(txt) = hello else {
            panic!("expected options_update text");
        };
        assert!(txt.contains("\"options_update\""));

        // Send a compressed binary zstd frame using raw_dict
        ws.send(Message::Binary(raw_frame_c.into())).await.unwrap();
        ws.close(None).await.unwrap();
    });

    let mut cfg = JetstreamSubscriptionConfiguration::new(
        Url::parse(&format!("ws://127.0.0.1:{}/subscribe", addr.port())).unwrap(),
    );
    cfg.compression = true;
    cfg.require_hello = true;
    cfg.legacy_zstd_dictionary = Some(raw_dict);
    cfg.session_factory = Arc::new(TungsteniteWebSocketFactory::with_options(
        FirehoseWebSocketOptions::jetstream(),
    ));
    cfg.backoff = fast_backoff();

    let sub = JetstreamSubscription::new(cfg);
    let mut stream = sub.events();
    let first = stream.next().await.unwrap().unwrap();
    assert!(matches!(
        first,
        JetstreamSubscriptionEvent::Event(JetstreamEvent::Commit(ref c))
            if c.seq == 1_700_000_000_123_456 && c.did == "did:plc:abc"
    ));
    drop(stream);
    server_task.await.unwrap();
}

#[async_test]
#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
async fn subscription_rejects_zstd_frames_when_compression_disabled_and_bounds_legacy_seq_cache() {
    use petrel_jetstream::JetstreamZstd;

    // 1. Standalone zstd frame sent when compression == false must be rejected as Undecompressable.
    let compressed_json = JetstreamZstd::compress(
        br#"{"$type":"message","payload":{"$type":"network.bsky.jetstream.subscribeEvents#commit","seq":1,"did":"did:plc:abc","time":"2026-01-01T00:00:00Z","rev":"3k7v2abc23456","operation":"create","collection":"app.bsky.feed.post","rkey":"r"}}"#,
    )
    .unwrap();
    let ws1 = Arc::new(ScriptedWs::new(vec![Ok(compressed_json)]));
    let factory1 = Arc::new(ScriptedWsFactory::new(vec![Ok(ws1)]));
    let mut cfg1 =
        JetstreamSubscriptionConfiguration::new(Url::parse("https://jet.example").unwrap());
    cfg1.compression = false;
    cfg1.session_factory = factory1;
    cfg1.backoff = fast_backoff();
    let mut stream1 = JetstreamSubscription::new(cfg1).events();
    let ev = stream1.next().await.unwrap().unwrap();
    assert!(matches!(
        ev,
        JetstreamSubscriptionEvent::IgnoredFrame(ref ig)
            if matches!(ig.reason, JetstreamIgnoredReason::Undecompressable(_))
    ));

    // 2. Legacy v1 emitting > 4,096 distinct events at the same time_us continues boundedly.
    let mut legacy_frames = Vec::with_capacity(4_150);
    for idx in 0..4_150_usize {
        legacy_frames.push(Ok(serde_json::to_vec(&json!({
            "did": "did:plc:burst",
            "time_us": 1_700_000_000_000_000_i64,
            "kind": "commit",
            "commit": {
                "rev": "3k7v2abc23456",
                "operation": "create",
                "collection": "app.bsky.feed.post",
                "rkey": format!("r{idx:05}")
            }
        }))
        .unwrap()));
    }
    // Duplicate of recent key (r04149) must still be deduplicated, followed by a sentinel!
    legacy_frames.push(legacy_frames[4_149].clone());
    legacy_frames.push(Ok(serde_json::to_vec(&json!({
        "did": "did:plc:burst",
        "time_us": 1_700_000_000_000_001_i64,
        "kind": "commit",
        "commit": {
            "rev": "3k7v2abc23456",
            "operation": "create",
            "collection": "app.bsky.feed.post",
            "rkey": "sentinel"
        }
    }))
    .unwrap()));

    let ws2 = Arc::new(ScriptedWs::new(legacy_frames));
    let factory2 = Arc::new(ScriptedWsFactory::new(vec![Ok(ws2)]));
    let mut cfg2 = JetstreamSubscriptionConfiguration::new(
        Url::parse("https://jet.example/subscribe").unwrap(),
    );
    cfg2.session_factory = factory2;
    cfg2.backoff = fast_backoff();
    let mut stream2 = JetstreamSubscription::new(cfg2).events();
    let mut events = Vec::with_capacity(4_151);
    while events.len() < 4_151 {
        let ev = stream2.next().await.unwrap().unwrap();
        if let JetstreamSubscriptionEvent::Event(inner) = ev {
            events.push(inner);
        }
    }
    assert_eq!(events.len(), 4_151);
    assert!(matches!(
        events.last(),
        Some(JetstreamEvent::Commit(c)) if c.rkey == "sentinel"
    ));
}
