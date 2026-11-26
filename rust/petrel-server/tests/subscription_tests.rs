//! Loopback tests for server-side XRPC subscriptions (`petrel_server::subscription`).
#![cfg(all(not(target_arch = "wasm32"), feature = "ws"))]

use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use axum::Router;
use axum::body::Body;
use axum::http::{Request, StatusCode};
use futures_util::{SinkExt, StreamExt};
use petrel_api::generated::com::atproto::label::defs::Label;
use petrel_api::generated::com::atproto::label::subscribe_labels::{
    Error as LabelsError, Info, Labels, Message as LabelsMessage, SubscribeLabels,
};
use petrel_core::{Datetime, DecodedSubscriptionFrame, Did, Uri, decode_subscription_frame};
use petrel_firehose::{EventStreamError, EventStreamEvent, FirehoseStreamError, LabelSubscription};
use petrel_server::axum::{ServiceAuth, ServiceAuthState, XrpcRouter};
use petrel_server::jose::{OAuthCompactJwt, OAuthJwsAlgorithm, OAuthSigningKey};
use petrel_server::service_auth::{
    ServiceAuthAudience, ServiceAuthVerifier, StaticServiceAuthKeyResolver, public_key_from_jwk,
};
use petrel_server::subscription::{
    InboundDataPolicy, SinkError, SubscriptionConfig, SubscriptionError,
};
use tokio::net::TcpListener;
use tokio::sync::oneshot;
use tokio::time::timeout;
use tokio_tungstenite::tungstenite::client::IntoClientRequest;
use tokio_tungstenite::tungstenite::protocol::frame::coding::CloseCode;
use tokio_tungstenite::tungstenite::{self, Message as WsMessage};
use tower_service::Service as _;

const ALICE_DID: &str = "did:plc:alice234567234567abcdefg";
const AUDIENCE: &str = "did:web:labeler.example.com";
const WAIT: Duration = Duration::from_secs(5);

type Client =
    tokio_tungstenite::WebSocketStream<tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>>;

async fn serve(router: Router) -> SocketAddr {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move { axum::serve(listener, router).await });
    addr
}

fn url(addr: SocketAddr, query: &str) -> String {
    format!("ws://{addr}/xrpc/{}{query}", SubscribeLabels::NSID)
}

async fn connect(addr: SocketAddr, query: &str) -> Client {
    tokio_tungstenite::connect_async(url(addr, query))
        .await
        .expect("upgrade")
        .0
}

/// Next data/close frame, skipping pings.
async fn next_frame(client: &mut Client) -> Option<WsMessage> {
    loop {
        match timeout(WAIT, client.next()).await.expect("frame in time") {
            Some(Ok(WsMessage::Ping(_) | WsMessage::Pong(_))) => {}
            Some(Ok(message)) => return Some(message),
            Some(Err(_)) | None => return None,
        }
    }
}

fn decode(message: &WsMessage) -> DecodedSubscriptionFrame<LabelsMessage, LabelsError> {
    let WsMessage::Binary(bytes) = message else {
        panic!("expected binary frame, got {message:?}");
    };
    decode_subscription_frame::<SubscribeLabels>(bytes).expect("decodable frame")
}

fn info(name: &str, message: Option<String>) -> LabelsMessage {
    LabelsMessage::Info(Box::new(Info {
        name: name.to_owned(),
        message,
        extra_data: None,
    }))
}

fn sample_label() -> Label {
    Label::new(
        Did::parse(ALICE_DID).unwrap(),
        Uri::parse("at://did:plc:alice234567234567abcdefg/app.bsky.feed.post/3k").unwrap(),
        "spam".to_owned(),
        Datetime::parse("2026-11-26T00:00:00.000Z").unwrap(),
    )
}

/// Expect an HTTP (non-upgraded) rejection with an XRPC error envelope.
async fn expect_http_rejection(request: impl IntoClientRequest + Unpin, status: u16, error: &str) {
    match tokio_tungstenite::connect_async(request).await {
        Err(tungstenite::Error::Http(response)) => {
            assert_eq!(response.status().as_u16(), status);
            let body: serde_json::Value =
                serde_json::from_slice(response.body().as_deref().unwrap_or_default()).unwrap();
            assert_eq!(body["error"], error, "body: {body}");
        }
        other => panic!("expected HTTP {status} rejection, got {other:?}"),
    }
}

#[tokio::test]
async fn round_trip_typed_messages_decode_with_firehose_client() {
    let router = XrpcRouter::<()>::new()
        .subscription::<SubscribeLabels, (), _, _>(|(), (), params, sink| async move {
            assert_eq!(params.cursor, None);
            sink.send(&info("OutdatedCursor", Some("hello".into())))
                .await?;
            sink.send(&LabelsMessage::Labels(Box::new(Labels::new(
                7,
                vec![sample_label()],
            ))))
            .await?;
            sink.closed().await;
            Ok(())
        })
        .with_state(());
    let addr = serve(router).await;

    // Raw frames: header `t` is the `#member` short form per the event-stream spec.
    let mut raw = connect(addr, "").await;
    let first = next_frame(&mut raw).await.unwrap();
    let WsMessage::Binary(bytes) = &first else {
        panic!("binary expected")
    };
    match petrel_core::decode_frame(bytes).unwrap() {
        petrel_core::SubscriptionFrame::Message { header, .. } => {
            assert_eq!(header.op, 1);
            assert_eq!(header.message_type.as_deref(), Some("#info"));
        }
        other => panic!("unexpected {other:?}"),
    }
    match decode(&next_frame(&mut raw).await.unwrap()) {
        DecodedSubscriptionFrame::Message {
            message: LabelsMessage::Labels(labels),
            sequence,
            ..
        } => {
            assert_eq!(sequence, Some(7));
            assert_eq!(labels.labels, vec![sample_label()]);
        }
        other => panic!("unexpected {other:?}"),
    }
    drop(raw);

    // The petrel-firehose consumer decodes the same stream.
    let service = url::Url::parse(&format!("http://{addr}")).unwrap();
    let subscription = LabelSubscription::labels(&service);
    let mut events = subscription.events();
    let first = timeout(WAIT, events.next())
        .await
        .unwrap()
        .unwrap()
        .unwrap();
    assert_eq!(
        first,
        EventStreamEvent::Message {
            message: info("OutdatedCursor", Some("hello".into())),
            sequence: None,
        }
    );
    match timeout(WAIT, events.next())
        .await
        .unwrap()
        .unwrap()
        .unwrap()
    {
        EventStreamEvent::Message {
            message: LabelsMessage::Labels(labels),
            sequence: Some(7),
        } => assert_eq!(labels.seq, 7),
        other => panic!("unexpected {other:?}"),
    }
}

#[tokio::test]
async fn handler_error_sends_error_frame_then_closes() {
    let router = XrpcRouter::<()>::new()
        .subscription::<SubscribeLabels, (), _, _>(|(), (), params, sink| async move {
            sink.send(&info("before", None)).await?;
            if params.cursor.is_some_and(|cursor| cursor > 100) {
                return Err(SubscriptionError::declared(
                    LabelsError::FutureCursor,
                    Some("cursor is ahead".to_owned()),
                ));
            }
            Ok(())
        })
        .with_state(());
    let addr = serve(router).await;

    let mut client = connect(addr, "?cursor=500").await;
    assert!(matches!(
        decode(&next_frame(&mut client).await.unwrap()),
        DecodedSubscriptionFrame::Message { .. }
    ));
    match decode(&next_frame(&mut client).await.unwrap()) {
        DecodedSubscriptionFrame::Error { error, message } => {
            assert_eq!(error, LabelsError::FutureCursor);
            assert_eq!(message.as_deref(), Some("cursor is ahead"));
        }
        other => panic!("unexpected {other:?}"),
    }
    match next_frame(&mut client).await {
        Some(WsMessage::Close(Some(frame))) => assert_eq!(frame.code, CloseCode::Normal),
        other => panic!("expected close, got {other:?}"),
    }

    // A handler returning Ok closes gracefully with no error frame.
    let mut client = connect(addr, "?cursor=1").await;
    let _ = next_frame(&mut client).await.unwrap();
    assert!(matches!(
        next_frame(&mut client).await,
        Some(WsMessage::Close(Some(frame))) if frame.code == CloseCode::Normal
    ));

    // The firehose consumer surfaces the error frame as a typed stream error.
    let subscription =
        LabelSubscription::new(petrel_firehose::FirehoseSubscriptionConfiguration::new(
            url::Url::parse(&url(addr, "?cursor=500")).unwrap(),
        ));
    let mut events = subscription.events();
    let _ = timeout(WAIT, events.next())
        .await
        .unwrap()
        .unwrap()
        .unwrap();
    match timeout(WAIT, events.next()).await.unwrap().unwrap() {
        Err(FirehoseStreamError::Stream(EventStreamError::FutureCursor(Some(message)))) => {
            assert_eq!(message, "cursor is ahead");
        }
        other => panic!("unexpected {other:?}"),
    }
}

fn service_auth_router(calls: Arc<AtomicUsize>) -> (Router, OAuthSigningKey) {
    let key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let resolver = Arc::new(StaticServiceAuthKeyResolver::new(HashMap::from([(
        ALICE_DID.to_owned(),
        public_key_from_jwk(&key.public_jwk(false).unwrap()).unwrap(),
    )])));
    let verifier = Arc::new(ServiceAuthVerifier::new(
        ServiceAuthAudience::exactly(AUDIENCE),
        resolver,
    ));
    let router = XrpcRouter::<ServiceAuthState>::new()
        .subscription::<SubscribeLabels, ServiceAuth, _, _>(
            move |_state, ServiceAuth(auth), _params, sink| {
                calls.fetch_add(1, Ordering::SeqCst);
                async move {
                    sink.send(&info(&auth.issuer, None)).await?;
                    sink.closed().await;
                    Ok(())
                }
            },
        )
        .with_state(ServiceAuthState::new(verifier));
    (router, key)
}

#[derive(serde::Serialize)]
struct ServiceJwt<'a> {
    iss: &'a str,
    aud: &'a str,
    exp: i64,
    iat: i64,
    lxm: &'a str,
    jti: &'a str,
}

#[tokio::test]
async fn auth_rejected_before_upgrade_and_accepted_with_service_auth() {
    let calls = Arc::new(AtomicUsize::new(0));
    let (router, key) = service_auth_router(Arc::clone(&calls));
    let addr = serve(router).await;

    expect_http_rejection(url(addr, ""), 401, "MissingJwt").await;
    let mut bad = url(addr, "").into_client_request().unwrap();
    bad.headers_mut()
        .insert("authorization", "Bearer not-a-jwt".parse().unwrap());
    expect_http_rejection(bad, 401, "BadJwt").await;
    assert_eq!(calls.load(Ordering::SeqCst), 0, "handler must not run");

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
        .cast_signed();
    let jwt = OAuthCompactJwt::sign(
        &ServiceJwt {
            iss: ALICE_DID,
            aud: AUDIENCE,
            exp: now + 60,
            iat: now,
            lxm: SubscribeLabels::NSID,
            jti: "subscription-jti-1",
        },
        &key,
        Some("JWT"),
        false,
    )
    .unwrap();
    let mut good = url(addr, "").into_client_request().unwrap();
    good.headers_mut()
        .insert("authorization", format!("Bearer {jwt}").parse().unwrap());
    let (mut client, _) = tokio_tungstenite::connect_async(good).await.unwrap();
    match decode(&next_frame(&mut client).await.unwrap()) {
        DecodedSubscriptionFrame::Message {
            message: LabelsMessage::Info(info),
            ..
        } => assert_eq!(info.name, ALICE_DID),
        other => panic!("unexpected {other:?}"),
    }
    assert_eq!(calls.load(Ordering::SeqCst), 1);
}

#[tokio::test]
async fn query_param_failure_and_plain_get_return_400_envelopes() {
    let calls = Arc::new(AtomicUsize::new(0));
    let counter = Arc::clone(&calls);
    let mut router = XrpcRouter::<()>::new()
        .subscription::<SubscribeLabels, (), _, _>(move |(), (), _params, sink| {
            counter.fetch_add(1, Ordering::SeqCst);
            async move {
                sink.close()?;
                Ok(())
            }
        })
        .with_state(());
    let addr = serve(router.clone()).await;

    expect_http_rejection(url(addr, "?cursor=notanumber"), 400, "InvalidRequest").await;
    expect_http_rejection(url(addr, "?cursor=1&cursor=2"), 400, "InvalidRequest").await;

    // A GET without upgrade headers is a 400 XRPC envelope, not a socket.
    let request = Request::builder()
        .uri(format!("/xrpc/{}", SubscribeLabels::NSID))
        .body(Body::empty())
        .unwrap();
    let response = router.call(request).await.unwrap();
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    let body = axum::body::to_bytes(response.into_body(), 4096)
        .await
        .unwrap();
    let body: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(body["error"], "InvalidRequest");
    assert_eq!(calls.load(Ordering::SeqCst), 0);
}

#[tokio::test]
async fn slow_consumer_gets_consumer_too_slow_and_is_disconnected() {
    let (tripped_tx, tripped_rx) = oneshot::channel::<usize>();
    let tripped_tx = Arc::new(std::sync::Mutex::new(Some(tripped_tx)));
    let mut config = SubscriptionConfig::default();
    config.buffer_capacity = 4;
    let router = XrpcRouter::<()>::new()
        .subscription_with::<SubscribeLabels, (), _, _, _, std::convert::Infallible, _, _>(
            config,
            |(), (), _params| async { Ok(()) },
            move |(), sink| {
                let tripped_tx = Arc::clone(&tripped_tx);
                async move {
                    let payload = "x".repeat(64 * 1024);
                    for sent in 0..20_000 {
                        match sink.send(&info("bulk", Some(payload.clone()))).await {
                            Ok(()) => tokio::task::yield_now().await,
                            Err(SinkError::ConsumerTooSlow) => {
                                if let Some(tx) = tripped_tx.lock().unwrap().take() {
                                    let _ = tx.send(sent);
                                }
                                assert_eq!(
                                    sink.send(&info("after", None)).await,
                                    Err(SinkError::Closed)
                                );
                                return Err(SinkError::ConsumerTooSlow.into());
                            }
                            Err(other) => panic!("unexpected {other:?}"),
                        }
                    }
                    panic!("consumer never became too slow");
                }
            },
        )
        .with_state(());
    let addr = serve(router).await;

    // Do not read until the server has given up on us.
    let mut client = connect(addr, "").await;
    let sent = timeout(Duration::from_secs(20), tripped_rx)
        .await
        .unwrap()
        .unwrap();
    assert!(sent > 4);

    let mut data_frames = 0;
    let last_error = loop {
        let frame = next_frame(&mut client)
            .await
            .expect("error frame before EOF");
        match decode(&frame) {
            DecodedSubscriptionFrame::Message { .. } => data_frames += 1,
            DecodedSubscriptionFrame::Error { error, .. } => break error,
            other => panic!("unexpected {other:?}"),
        }
    };
    assert_eq!(
        last_error,
        LabelsError::Unknown("ConsumerTooSlow".to_owned())
    );
    assert!(data_frames < sent, "error frame jumped the backlog");
    assert!(matches!(
        next_frame(&mut client).await,
        Some(WsMessage::Close(Some(frame))) if frame.code == CloseCode::Policy
    ));
}

struct DropFlag(Option<oneshot::Sender<()>>);

impl Drop for DropFlag {
    fn drop(&mut self) {
        if let Some(tx) = self.0.take() {
            let _ = tx.send(());
        }
    }
}

#[tokio::test]
async fn abrupt_client_close_cancels_handler_and_releases_producers() {
    let (dropped_tx, dropped_rx) = oneshot::channel();
    let (producer_tx, producer_rx) = oneshot::channel::<SinkError>();
    let slots = Arc::new(std::sync::Mutex::new(Some((dropped_tx, producer_tx))));
    let router = XrpcRouter::<()>::new()
        .subscription::<SubscribeLabels, (), _, _>(move |(), (), _params, sink| {
            let slots = Arc::clone(&slots);
            async move {
                let (dropped_tx, producer_tx) = slots.lock().unwrap().take().unwrap();
                let _flag = DropFlag(Some(dropped_tx));
                // A producer outside the connection future, as a broadcast fan-out would be.
                let producer = sink.clone();
                tokio::spawn(async move {
                    loop {
                        if let Err(error) = producer.send(&info("tick", None)).await {
                            producer.closed().await;
                            let _ = producer_tx.send(error);
                            return;
                        }
                        tokio::time::sleep(Duration::from_millis(5)).await;
                    }
                });
                std::future::pending::<()>().await;
                Ok(())
            }
        })
        .with_state(());
    let addr = serve(router).await;
    let metrics = tokio::runtime::Handle::current().metrics();
    let baseline = metrics.num_alive_tasks();

    let mut client = connect(addr, "").await;
    let _ = next_frame(&mut client).await.unwrap();
    assert!(metrics.num_alive_tasks() > baseline);
    // Drop the TCP stream without a close handshake.
    drop(client);

    timeout(WAIT, dropped_rx).await.unwrap().unwrap();
    let error = timeout(WAIT, producer_rx).await.unwrap().unwrap();
    assert_eq!(error, SinkError::Closed);
    timeout(WAIT, async {
        while metrics.num_alive_tasks() > baseline {
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .expect("connection tasks exit");
}

#[tokio::test]
async fn keepalive_pings_and_idle_timeout_closes_silent_client() {
    let mut config = SubscriptionConfig::default();
    config.ping_interval = Some(Duration::from_millis(50));
    config.idle_timeout = Some(Duration::from_millis(250));
    let router = XrpcRouter::<()>::new()
        .subscription_with::<SubscribeLabels, (), _, _, _, std::convert::Infallible, _, _>(
            config,
            |(), (), _params| async { Ok(()) },
            |(), sink| async move {
                sink.closed().await;
                Ok(())
            },
        )
        .with_state(());
    let addr = serve(router).await;

    // A reading client answers pings and survives well past the idle timeout.
    let mut live = connect(addr, "").await;
    let mut pings = 0;
    let stay = tokio::time::Instant::now() + Duration::from_millis(700);
    while tokio::time::Instant::now() < stay {
        match timeout(Duration::from_millis(100), live.next()).await {
            Ok(Some(Ok(WsMessage::Ping(_)))) => pings += 1,
            Ok(other) => panic!("live client got {other:?}"),
            Err(_) => {}
        }
    }
    assert!(pings >= 5, "only {pings} pings");

    // A client that never reads (so never pongs) is closed as idle.
    let mut silent = connect(addr, "").await;
    tokio::time::sleep(Duration::from_millis(600)).await;
    assert!(matches!(
        next_frame(&mut silent).await,
        Some(WsMessage::Close(Some(frame))) if frame.code == CloseCode::Away
    ));
}

#[tokio::test]
async fn inbound_data_is_ignored_and_oversize_or_close_policy_disconnects() {
    let build = |policy: InboundDataPolicy| {
        let mut config = SubscriptionConfig::default();
        config.inbound_data = policy;
        config.max_inbound_message_bytes = 1024;
        XrpcRouter::<()>::new()
            .subscription_with::<SubscribeLabels, (), _, _, _, std::convert::Infallible, _, _>(
                config,
                |(), (), _params| async { Ok(()) },
                |(), sink| async move {
                    sink.send(&info("hello", None)).await?;
                    tokio::time::sleep(Duration::from_millis(200)).await;
                    sink.send(&info("still-here", None)).await?;
                    sink.closed().await;
                    Ok(())
                },
            )
            .with_state(())
    };
    let addr = serve(build(InboundDataPolicy::Ignore)).await;

    let mut client = connect(addr, "").await;
    let _ = next_frame(&mut client).await.unwrap();
    client.send(WsMessage::text("ignored")).await.unwrap();
    client
        .send(WsMessage::binary(vec![1_u8, 2, 3]))
        .await
        .unwrap();
    match decode(&next_frame(&mut client).await.unwrap()) {
        DecodedSubscriptionFrame::Message {
            message: LabelsMessage::Info(info),
            ..
        } => assert_eq!(info.name, "still-here"),
        other => panic!("unexpected {other:?}"),
    }
    // Oversize inbound message: the server drops the connection without panicking.
    client
        .send(WsMessage::binary(vec![0_u8; 64 * 1024]))
        .await
        .unwrap();
    match next_frame(&mut client).await {
        None | Some(WsMessage::Close(_)) => {}
        Some(other) => panic!("unexpected {other:?}"),
    }

    let addr = serve(build(InboundDataPolicy::Close)).await;
    let mut client = connect(addr, "").await;
    let _ = next_frame(&mut client).await.unwrap();
    client.send(WsMessage::text("nope")).await.unwrap();
    assert!(matches!(
        next_frame(&mut client).await,
        Some(WsMessage::Close(Some(frame))) if frame.code == CloseCode::Unsupported
    ));
}
