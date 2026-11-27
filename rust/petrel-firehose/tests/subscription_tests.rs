mod common;

use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::Duration;

use futures_util::StreamExt;
use petrel_core::{Value, dagcbor};
use petrel_firehose::{
    EventStreamIgnoredFrame, FirehoseBackoffConfiguration, FirehoseCursorStorage, FirehoseEndpoint,
    FirehoseFrameEncoder, FirehoseStreamError, FirehoseSubscription,
    FirehoseSubscriptionConfiguration, FirehoseSubscriptionError, FirehoseSubscriptionEvent,
    FirehoseWebSocketOptions, IgnoredFrameReason, InMemoryFirehoseCursorStorage,
    PublicFirehoseIdentityMaterial, RelayEvent, bounded_firehose_channel,
};
use url::Url;

#[cfg(not(target_arch = "wasm32"))]
use tokio::test as async_test;
#[cfg(target_arch = "wasm32")]
use wasm_bindgen_test::wasm_bindgen_test as async_test;

fn encode_identity(seq: i64, did: &str) -> Vec<u8> {
    FirehoseFrameEncoder::identity_frame(
        seq,
        &PublicFirehoseIdentityMaterial {
            did: did.to_owned(),
            handle: Some(format!("user{seq}.test")),
            time: "2026-01-01T00:00:00.000Z".to_owned(),
        },
    )
    .unwrap()
}

fn encode_error_frame(error: &str, message: Option<&str>) -> Vec<u8> {
    FirehoseFrameEncoder::error_frame(error, message).unwrap()
}

#[test]
fn backoff_schedule_and_endpoint_url_derivation() {
    let mut backoff = FirehoseBackoffConfiguration::new();
    let d1 = backoff.next_delay(None);
    let d2 = backoff.next_delay(Some(d1));
    let d3 = backoff.next_delay(Some(Duration::from_secs(20)));
    assert_eq!(d1, Duration::from_millis(500));
    assert_eq!(d2, Duration::from_secs(1));
    assert_eq!(d3, Duration::from_secs(30));

    backoff.jitter = 0.25;
    for _ in 0..20 {
        let j = backoff.jittered(Duration::from_secs(4));
        assert!(j >= Duration::from_millis(2999));
        assert!(j <= Duration::from_millis(5001));
    }

    let svc = Url::parse("https://bsky.network/sub").unwrap();
    let ws_url = FirehoseEndpoint::subscription_url(&svc, "com.atproto.sync.subscribeRepos");
    assert_eq!(
        ws_url.as_str(),
        "wss://bsky.network/sub/xrpc/com.atproto.sync.subscribeRepos"
    );

    let http_svc = Url::parse("http://127.0.0.1:8080").unwrap();
    assert_eq!(
        FirehoseEndpoint::subscription_url(&http_svc, "com.atproto.label.subscribeLabels").as_str(),
        "ws://127.0.0.1:8080/xrpc/com.atproto.label.subscribeLabels"
    );

    assert_eq!(
        FirehoseWebSocketOptions::jetstream().text_frames,
        petrel_firehose::TextFrameHandling::Utf8Data
    );
}

#[async_test]
async fn subscription_resumes_dedups_inclusive_cursor_and_reports_gaps() {
    let cursor_storage = Arc::new(InMemoryFirehoseCursorStorage::with_initial_cursor(Some(10)));

    let s1 = Arc::new(common::ScriptedSession::from_actions(vec![
        Ok(encode_identity(10, "did:plc:u1")), // replayed cursor event -> dropped!
        Ok(encode_identity(11, "did:plc:u1")),
        Err(FirehoseSubscriptionError::ConnectionClosed),
    ]));
    let s2 = Arc::new(common::ScriptedSession::from_actions(vec![
        Ok(encode_identity(11, "did:plc:u1")), // auto-acknowledged 11 -> dropped!
        Ok(encode_identity(15, "did:plc:u1")), // gap 12..15 -> SequenceGap + Event(15)
        Ok(encode_error_frame("FutureCursor", Some("done"))),
    ]));

    let factory = Arc::new(common::ScriptedWebSocketFactory::new(vec![Ok(s1), Ok(s2)]));
    let mut config = FirehoseSubscriptionConfiguration::new(
        Url::parse("wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos").unwrap(),
    );
    config.cursor_storage = cursor_storage.clone();
    config.session_factory = factory.clone();
    config.backoff = FirehoseBackoffConfiguration {
        initial_delay: Duration::from_millis(1),
        max_delay: Duration::from_millis(5),
        multiplier: 2.0,
        jitter: 0.0,
    };
    config.auto_acknowledge = true;

    let sub = FirehoseSubscription::new(config);
    let mut stream = sub.events();

    let ev1 = stream.next().await.unwrap().unwrap();
    assert!(matches!(
        ev1,
        FirehoseSubscriptionEvent::Event(RelayEvent::Identity(ref i)) if i.seq == 11
    ));

    let ev2 = stream.next().await.unwrap().unwrap();
    assert_eq!(
        ev2,
        FirehoseSubscriptionEvent::SequenceGap {
            expected: 12,
            received: 15
        }
    );

    let ev3 = stream.next().await.unwrap().unwrap();
    assert!(matches!(
        ev3,
        FirehoseSubscriptionEvent::Event(RelayEvent::Identity(ref i)) if i.seq == 15
    ));
    // Before asking for the next element, 15 is not yet acknowledged (11 was on ev2/ev3 poll).
    assert_eq!(cursor_storage.load_cursor().await.unwrap(), Some(11));

    // Asking for the next element acknowledges 15, then receives the terminal error frame.
    let ev4 = stream.next().await.unwrap();
    assert!(matches!(ev4, Err(FirehoseStreamError::Stream(_))));
    assert_eq!(cursor_storage.load_cursor().await.unwrap(), Some(15));

    let urls = factory.requested_urls.lock().await;
    assert_eq!(urls.len(), 2);
    assert_eq!(urls[0].query(), Some("cursor=10"));
    assert_eq!(urls[1].query(), Some("cursor=11"));
}

#[async_test]
async fn subscription_handles_cursor_zero_and_rejects_duplicate_and_regression() {
    // Cursor 0 suppresses gap notice on first event > 1.
    let s0 = Arc::new(common::ScriptedSession::from_actions(vec![
        Ok(encode_identity(100, "did:plc:u2")),
        Ok(encode_identity(100, "did:plc:u2")), // duplicate within same stream -> error
    ]));
    let factory = Arc::new(common::ScriptedWebSocketFactory::new(vec![Ok(s0)]));
    let mut config = FirehoseSubscriptionConfiguration::new(
        Url::parse("wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos").unwrap(),
    );
    config.cursor_storage = Arc::new(InMemoryFirehoseCursorStorage::with_initial_cursor(Some(0)));
    config.session_factory = factory;

    let sub = FirehoseSubscription::new(config);
    let mut stream = sub.events();
    let first = stream.next().await.unwrap().unwrap();
    assert!(matches!(
        first,
        FirehoseSubscriptionEvent::Event(RelayEvent::Identity(ref i)) if i.seq == 100
    ));
    let second = stream.next().await.unwrap();
    assert_eq!(
        second,
        Err(FirehoseStreamError::Subscription(
            FirehoseSubscriptionError::DuplicateSequence(100)
        ))
    );

    // Manual acknowledge regression error
    assert_eq!(sub.acknowledge(10).await, Ok(()));
    assert_eq!(
        sub.acknowledge(9).await,
        Err(FirehoseSubscriptionError::CursorRegression {
            expected: 11,
            received: 9
        })
    );
}

#[async_test]
async fn consumer_too_slow_reconnects_only_when_opted_in_and_drop_closes_socket() {
    let s1 = Arc::new(common::ScriptedSession::from_actions(vec![
        Ok(encode_identity(5, "did:plc:slow")),
        Ok(encode_error_frame("ConsumerTooSlow", None)),
    ]));
    let s2 = Arc::new(common::ScriptedSession::from_actions(vec![Ok(
        encode_identity(6, "did:plc:slow"),
    )]));

    let factory = Arc::new(common::ScriptedWebSocketFactory::new(vec![
        Ok(s1.clone()),
        Ok(s2.clone()),
    ]));
    let mut config = FirehoseSubscriptionConfiguration::new(
        Url::parse("wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos").unwrap(),
    );
    config.session_factory = factory;
    config.backoff = FirehoseBackoffConfiguration {
        initial_delay: Duration::from_millis(1),
        max_delay: Duration::from_millis(5),
        multiplier: 2.0,
        jitter: 0.0,
    };
    config.auto_acknowledge = true;
    config.reconnects_on_consumer_too_slow = true;

    let sub = FirehoseSubscription::new(config);
    let mut stream = sub.events();
    assert!(matches!(
        stream.next().await.unwrap().unwrap(),
        FirehoseSubscriptionEvent::Event(RelayEvent::Identity(ref i)) if i.seq == 5
    ));
    assert!(matches!(
        stream.next().await.unwrap().unwrap(),
        FirehoseSubscriptionEvent::Event(RelayEvent::Identity(ref i)) if i.seq == 6
    ));
    assert!(s1.closed.load(std::sync::atomic::Ordering::SeqCst));

    // Dropping stream while idle closes active session s2.
    drop(stream);
    // Allow any async drop task to flush on native or wasm32.
    #[cfg(not(target_arch = "wasm32"))]
    tokio::task::yield_now().await;
    #[cfg(target_arch = "wasm32")]
    petrel::rt::sleep(Duration::from_millis(0)).await;
    assert!(s2.closed.load(std::sync::atomic::Ordering::SeqCst));
}

#[async_test]
async fn upgrade_rejection_retries_429_503_and_stops_on_501_400() {
    let s_ok = Arc::new(common::ScriptedSession::from_actions(vec![Ok(
        encode_identity(1, "did:plc:retry"),
    )]));
    let factory = Arc::new(common::ScriptedWebSocketFactory::new(vec![
        Err(FirehoseSubscriptionError::UpgradeRejected {
            status: 429,
            retry_after_ms: Some(1),
        }),
        Err(FirehoseSubscriptionError::UpgradeRejected {
            status: 503,
            retry_after_ms: None,
        }),
        Ok(s_ok),
    ]));
    let mut config = FirehoseSubscriptionConfiguration::new(
        Url::parse("wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos").unwrap(),
    );
    config.session_factory = factory;
    config.backoff = FirehoseBackoffConfiguration {
        initial_delay: Duration::from_millis(1),
        max_delay: Duration::from_millis(2),
        multiplier: 2.0,
        jitter: 0.0,
    };
    let sub = FirehoseSubscription::new(config);
    let mut stream = sub.events();
    assert!(stream.next().await.unwrap().is_ok());

    for fatal_status in [400_u16, 404, 501] {
        let f = Arc::new(common::ScriptedWebSocketFactory::new(vec![Err(
            FirehoseSubscriptionError::UpgradeRejected {
                status: fatal_status,
                retry_after_ms: Some(10),
            },
        )]));
        let mut cfg = FirehoseSubscriptionConfiguration::new(
            Url::parse("wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos").unwrap(),
        );
        cfg.session_factory = f;
        let sub = FirehoseSubscription::new(cfg);
        let err = sub.events().next().await.unwrap().unwrap_err();
        assert_eq!(
            err,
            FirehoseStreamError::Subscription(FirehoseSubscriptionError::UpgradeRejected {
                status: fatal_status,
                retry_after_ms: Some(10),
            })
        );
    }
}

#[async_test]
async fn lenient_stream_delivers_ignored_frame_for_invalid_commit_payload_without_stalling() {
    // Valid op=1 t=#commit header, invalid payload (missing commit/blocks/ops)
    let mut hdr = BTreeMap::new();
    hdr.insert("op".to_owned(), Value::Integer(1));
    hdr.insert("t".to_owned(), Value::String("#commit".to_owned()));
    let mut body = BTreeMap::new();
    body.insert("seq".to_owned(), Value::Integer(4));
    let mut bad_commit = dagcbor::encode(&Value::Object(hdr));
    bad_commit.extend_from_slice(&dagcbor::encode(&Value::Object(body)));

    let s = Arc::new(common::ScriptedSession::from_actions(vec![
        Ok(bad_commit),
        Ok(encode_identity(5, "did:plc:ok")),
    ]));
    let factory = Arc::new(common::ScriptedWebSocketFactory::new(vec![Ok(s)]));
    let mut cfg = FirehoseSubscriptionConfiguration::new(
        Url::parse("wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos").unwrap(),
    );
    cfg.session_factory = factory;
    let sub = FirehoseSubscription::new(cfg);
    let mut stream = sub.events();

    let first = stream.next().await.unwrap().unwrap();
    assert!(matches!(first, FirehoseSubscriptionEvent::IgnoredFrame(_)));
    let second = stream.next().await.unwrap().unwrap();
    assert!(matches!(
        second,
        FirehoseSubscriptionEvent::Event(RelayEvent::Identity(ref i)) if i.seq == 5
    ));

    let (mut tx, mut rx) = bounded_firehose_channel::<i64>(2);
    tx.send(1).await.unwrap();
    tx.send(2).await.unwrap();
    assert_eq!(rx.recv().await, Some(1));
    assert_eq!(rx.recv().await, Some(2));
}

fn fast_config(
    factory: Arc<common::ScriptedWebSocketFactory>,
) -> FirehoseSubscriptionConfiguration {
    let mut config = FirehoseSubscriptionConfiguration::new(
        Url::parse("wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos").unwrap(),
    );
    config.session_factory = factory;
    config.backoff = FirehoseBackoffConfiguration {
        initial_delay: Duration::from_millis(1),
        max_delay: Duration::from_millis(5),
        multiplier: 2.0,
        jitter: 0.0,
    };
    config
}

fn identity_seq(event: &FirehoseSubscriptionEvent) -> Option<i64> {
    match event {
        FirehoseSubscriptionEvent::Event(RelayEvent::Identity(i)) => Some(i.seq),
        _ => None,
    }
}

#[async_test]
async fn malformed_frame_is_ignored_and_never_moves_the_cursor() {
    // Non-canonical body: `seq` encoded with a one-byte argument (0x18 0x02) instead of the
    // minimal immediate form. Canonical parsing rejects the frame; seq 2 is still readable.
    let mut hdr = BTreeMap::new();
    hdr.insert("op".to_owned(), Value::Integer(1));
    hdr.insert("t".to_owned(), Value::String("#identity".to_owned()));
    let mut non_canonical = dagcbor::encode(&Value::Object(hdr.clone()));
    non_canonical.extend_from_slice(&[0xA1, 0x63, b's', b'e', b'q', 0x18, 0x02]);
    // Truncated body: nothing recoverable, delivered without advancing the cursor.
    let mut garbage = dagcbor::encode(&Value::Object(hdr));
    garbage.push(0xFF);

    let s = Arc::new(common::ScriptedSession::from_actions(vec![
        Ok(encode_identity(1, "did:plc:ok")),
        Ok(non_canonical),
        Ok(garbage),
        Ok(encode_identity(3, "did:plc:ok")),
        Ok(encode_error_frame("FutureCursor", None)),
    ]));
    let storage = Arc::new(InMemoryFirehoseCursorStorage::new());
    let mut config = fast_config(Arc::new(common::ScriptedWebSocketFactory::new(vec![Ok(s)])));
    config.cursor_storage = storage.clone();
    config.auto_acknowledge = true;
    let sub = FirehoseSubscription::new(config);
    let mut stream = sub.events();

    assert_eq!(
        identity_seq(&stream.next().await.unwrap().unwrap()),
        Some(1)
    );
    let ignored = stream.next().await.unwrap().unwrap();
    assert!(
        matches!(
            ignored,
            FirehoseSubscriptionEvent::IgnoredFrame(EventStreamIgnoredFrame {
                operation: 1,
                sequence: Some(2),
                reason: IgnoredFrameReason::MalformedFrame(_),
                ref r#type,
            }) if r#type.as_deref() == Some("#identity")
        ),
        "{ignored:?}"
    );
    let unknown = stream.next().await.unwrap().unwrap();
    assert!(
        matches!(
            unknown,
            FirehoseSubscriptionEvent::IgnoredFrame(EventStreamIgnoredFrame {
                sequence: None,
                reason: IgnoredFrameReason::MalformedFrame(_),
                ..
            })
        ),
        "{unknown:?}"
    );
    // The malformed frame's self-reported sequence is untrusted, so the cursor stays at 1 and
    // the skipped range is reported as a gap before the next good event.
    assert_eq!(storage.load_cursor().await.unwrap(), Some(1));
    assert!(matches!(
        stream.next().await.unwrap().unwrap(),
        FirehoseSubscriptionEvent::SequenceGap { .. }
    ));
    assert_eq!(
        identity_seq(&stream.next().await.unwrap().unwrap()),
        Some(3)
    );
    assert!(matches!(
        stream.next().await.unwrap(),
        Err(FirehoseStreamError::Stream(_))
    ));
    assert_eq!(storage.load_cursor().await.unwrap(), Some(3));
}

#[async_test]
async fn oversize_frame_reconnects_with_backoff_then_fails_naming_the_cursor() {
    let s1 = Arc::new(common::ScriptedSession::from_actions(vec![
        Ok(encode_identity(1, "did:plc:big")),
        Err(FirehoseSubscriptionError::FrameTooLarge),
    ]));
    let s2 = Arc::new(common::ScriptedSession::from_actions(vec![Err(
        FirehoseSubscriptionError::FrameTooLarge,
    )]));
    let s3 = Arc::new(common::ScriptedSession::from_actions(vec![Err(
        FirehoseSubscriptionError::FrameTooLarge,
    )]));
    let factory = Arc::new(common::ScriptedWebSocketFactory::new(vec![
        Ok(s1),
        Ok(s2),
        Ok(s3),
    ]));
    let mut config = fast_config(factory.clone());
    config.oversize_frame_retry_limit = 3;
    let sub = FirehoseSubscription::new(config);
    let mut stream = sub.events();

    assert_eq!(
        identity_seq(&stream.next().await.unwrap().unwrap()),
        Some(1)
    );
    for _ in 0..2 {
        assert!(matches!(
            stream.next().await.unwrap().unwrap(),
            FirehoseSubscriptionEvent::IgnoredFrame(EventStreamIgnoredFrame {
                sequence: None,
                reason: IgnoredFrameReason::FrameTooLarge,
                ..
            })
        ));
    }
    assert_eq!(
        stream.next().await.unwrap(),
        Err(FirehoseStreamError::Subscription(
            FirehoseSubscriptionError::FrameTooLargeAtCursor {
                cursor: Some(1),
                attempts: 3
            }
        ))
    );
    assert!(stream.next().await.is_none());
    let urls = factory.requested_urls.lock().await;
    assert_eq!(urls.len(), 3);
    assert!(urls[1..].iter().all(|u| u.query() == Some("cursor=1")));
}

#[async_test]
async fn oversize_frames_at_advancing_positions_do_not_accumulate() {
    let mut outcomes = Vec::new();
    for seq in 1..=4 {
        outcomes.push(Ok(Arc::new(common::ScriptedSession::from_actions(vec![
            Ok(encode_identity(seq, "did:plc:big")),
            Err(FirehoseSubscriptionError::FrameTooLarge),
        ]))));
    }
    outcomes.push(Ok(Arc::new(common::ScriptedSession::from_actions(vec![
        Ok(encode_error_frame("FutureCursor", None)),
    ]))));
    let mut config = fast_config(Arc::new(common::ScriptedWebSocketFactory::new(outcomes)));
    config.oversize_frame_retry_limit = 2;
    let sub = FirehoseSubscription::new(config);
    let mut stream = sub.events();

    for seq in 1..=4 {
        assert_eq!(
            identity_seq(&stream.next().await.unwrap().unwrap()),
            Some(seq)
        );
        assert!(matches!(
            stream.next().await.unwrap().unwrap(),
            FirehoseSubscriptionEvent::IgnoredFrame(_)
        ));
    }
    assert!(matches!(
        stream.next().await.unwrap(),
        Err(FirehoseStreamError::Stream(_))
    ));
}

/// Documents manual-acknowledgement redelivery: reconnects resume from the last acknowledged
/// cursor, so unacknowledged events are delivered again.
#[async_test]
async fn manual_ack_reconnect_redelivers_unacknowledged_events() {
    let s1 = Arc::new(common::ScriptedSession::from_actions(vec![
        Ok(encode_identity(1, "did:plc:ack")),
        Ok(encode_identity(2, "did:plc:ack")),
        Err(FirehoseSubscriptionError::ConnectionClosed),
    ]));
    let s2 = Arc::new(common::ScriptedSession::from_actions(vec![
        Ok(encode_identity(2, "did:plc:ack")),
        Ok(encode_error_frame("FutureCursor", None)),
    ]));
    let factory = Arc::new(common::ScriptedWebSocketFactory::new(vec![Ok(s1), Ok(s2)]));
    let sub = FirehoseSubscription::new(fast_config(factory.clone()));
    let mut stream = sub.events();

    assert_eq!(
        identity_seq(&stream.next().await.unwrap().unwrap()),
        Some(1)
    );
    sub.acknowledge(1).await.unwrap();
    assert_eq!(
        identity_seq(&stream.next().await.unwrap().unwrap()),
        Some(2)
    );
    // 2 is never acknowledged, so it comes back after the reconnect.
    assert_eq!(
        identity_seq(&stream.next().await.unwrap().unwrap()),
        Some(2)
    );
    assert!(stream.next().await.unwrap().is_err());
    assert_eq!(
        factory.requested_urls.lock().await[1].query(),
        Some("cursor=1")
    );
}

/// The keep-alive must not drop a healthy socket just because the consumer stopped pulling
/// for longer than the ping interval, yet must still detect a peer that never answers.
#[cfg(not(target_arch = "wasm32"))]
#[tokio::test]
async fn keep_alive_tolerates_slow_consumer_but_detects_dead_peer() {
    use futures_util::SinkExt;
    use petrel_firehose::{FirehoseWebSocketSessionFactory, TungsteniteWebSocketFactory};
    use tokio::net::TcpListener;
    use tokio_tungstenite::tungstenite::Message;

    let mut opts = FirehoseWebSocketOptions::new();
    opts.ping_interval = Some(Duration::from_millis(50));
    let factory = TungsteniteWebSocketFactory::with_options(opts);

    // 1. Healthy peer that answers pings, consumer idle for 8 ping intervals.
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    let frame = encode_identity(1, "did:plc:idle");
    let frame_c = frame.clone();
    let server = tokio::spawn(async move {
        let (stream, _) = listener.accept().await.unwrap();
        let ws = tokio_tungstenite::accept_async(stream).await.unwrap();
        let (mut tx, mut rx) = ws.split();
        // Reading answers pings (tungstenite queues and flushes the pong).
        let reader = tokio::spawn(async move { while let Some(Ok(_)) = rx.next().await {} });
        tokio::time::sleep(Duration::from_millis(400)).await;
        tx.send(Message::Binary(frame_c.into())).await.unwrap();
        tokio::time::sleep(Duration::from_millis(200)).await;
        reader.abort();
    });
    let session = factory
        .make_session(Url::parse(&format!("ws://127.0.0.1:{}/xrpc", addr.port())).unwrap())
        .await
        .unwrap();
    tokio::time::sleep(Duration::from_millis(400)).await;
    assert_eq!(session.receive_message().await, Ok(frame));
    session.close().await;
    server.await.unwrap();

    // 2. Peer that never reads, so never answers pings: a waiting consumer is unblocked.
    let dead_listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let dead_addr = dead_listener.local_addr().unwrap();
    let _dead = tokio::spawn(async move {
        let (stream, _) = dead_listener.accept().await.unwrap();
        let _ws = tokio_tungstenite::accept_async(stream).await.unwrap();
        tokio::time::sleep(Duration::from_secs(5)).await;
    });
    let session = factory
        .make_session(Url::parse(&format!("ws://127.0.0.1:{}/xrpc", dead_addr.port())).unwrap())
        .await
        .unwrap();
    let result = tokio::time::timeout(Duration::from_secs(2), session.receive_message())
        .await
        .expect("keep-alive must close an unresponsive connection");
    assert_eq!(result, Err(FirehoseSubscriptionError::ConnectionClosed));
}

#[cfg(not(target_arch = "wasm32"))]
#[tokio::test]
async fn native_loopback_websocket_server_streams_and_enforces_http_and_text_errors() {
    use futures_util::SinkExt;
    use petrel_firehose::{FirehoseWebSocketSessionFactory, TungsteniteWebSocketFactory};
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio::net::TcpListener;
    use tokio_tungstenite::tungstenite::Message;

    // 1. Live binary WebSocket stream using real TungsteniteWebSocketFactory over loopback TCP
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    let frame1 = encode_identity(1, "did:plc:loopback");
    let frame2 = encode_identity(2, "did:plc:loopback");
    let frame1_c = frame1.clone();
    let frame2_c = frame2.clone();

    let server_task = tokio::spawn(async move {
        let (stream, _) = listener.accept().await.unwrap();
        let mut ws = tokio_tungstenite::accept_async(stream).await.unwrap();
        ws.send(Message::Binary(frame1_c.into())).await.unwrap();
        ws.send(Message::Binary(frame2_c.into())).await.unwrap();
        ws.close(None).await.unwrap();
    });

    let ws_url = Url::parse(&format!(
        "ws://127.0.0.1:{}/xrpc/com.atproto.sync.subscribeRepos",
        addr.port()
    ))
    .unwrap();
    let mut cfg = FirehoseSubscriptionConfiguration::new(ws_url.clone());
    cfg.session_factory = Arc::new(TungsteniteWebSocketFactory::new());
    let sub = FirehoseSubscription::new(cfg);
    let mut stream = sub.events();

    let e1 = stream.next().await.unwrap().unwrap();
    let e2 = stream.next().await.unwrap().unwrap();
    assert!(
        matches!(e1, FirehoseSubscriptionEvent::Event(RelayEvent::Identity(ref i)) if i.seq == 1)
    );
    assert!(
        matches!(e2, FirehoseSubscriptionEvent::Event(RelayEvent::Identity(ref i)) if i.seq == 2)
    );
    drop(stream);
    server_task.await.unwrap();

    // 2. HTTP 429 Retry-After upgrade rejection
    let http_listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let http_addr = http_listener.local_addr().unwrap();
    let http_task = tokio::spawn(async move {
        let (mut sock, _) = http_listener.accept().await.unwrap();
        let mut buf = [0u8; 1024];
        let _ = sock.read(&mut buf).await;
        sock.write_all(
            b"HTTP/1.1 429 Too Many Requests\r\nRetry-After: 2\r\nContent-Length: 0\r\n\r\n",
        )
        .await
        .unwrap();
    });

    let factory = TungsteniteWebSocketFactory::new();
    let err = factory
        .make_session(Url::parse(&format!("ws://127.0.0.1:{}/xrpc", http_addr.port())).unwrap())
        .await
        .unwrap_err();
    assert_eq!(
        err,
        FirehoseSubscriptionError::UpgradeRejected {
            status: 429,
            retry_after_ms: Some(2000)
        }
    );
    http_task.await.unwrap();

    // 3. Text frame rejected on binary-only stream
    let txt_listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let txt_addr = txt_listener.local_addr().unwrap();
    let txt_task = tokio::spawn(async move {
        let (stream, _) = txt_listener.accept().await.unwrap();
        let mut ws = tokio_tungstenite::accept_async(stream).await.unwrap();
        ws.send(Message::Text("not binary".into())).await.unwrap();
    });
    let session = factory
        .make_session(Url::parse(&format!("ws://127.0.0.1:{}/xrpc", txt_addr.port())).unwrap())
        .await
        .unwrap();
    assert_eq!(
        session.receive_message().await,
        Err(FirehoseSubscriptionError::UnsupportedMessageFormat)
    );
    session.close().await;
    txt_task.await.unwrap();

    // 4. Connect timeout aborts a stalled TCP/TLS/WS handshake promptly.
    let stalled_listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let stalled_addr = stalled_listener.local_addr().unwrap();
    let _stalled_accept = tokio::spawn(async move {
        let (_sock, _) = stalled_listener.accept().await.unwrap();
        tokio::time::sleep(Duration::from_secs(5)).await;
    });
    let mut timeout_opts = FirehoseWebSocketOptions::new();
    timeout_opts.connect_timeout = Some(Duration::from_millis(50));
    let timeout_factory = TungsteniteWebSocketFactory::with_options(timeout_opts);
    let err = timeout_factory
        .make_session(Url::parse(&format!("ws://127.0.0.1:{}/xrpc", stalled_addr.port())).unwrap())
        .await
        .unwrap_err();
    assert!(matches!(err, FirehoseSubscriptionError::Network(_)));
}
