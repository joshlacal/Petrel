//! Per-connection driver: one future polling the handler, the writer, the reader, and keep-alive.

use std::future::{Future, pending};
use std::pin::pin;
use std::sync::Arc;

use axum::extract::ws::{CloseFrame, Message, Utf8Bytes, WebSocket};
use bytes::Bytes;
use futures_util::SinkExt;
use futures_util::stream::{SplitSink, StreamExt};
use petrel_core::XrpcSubscription;
use tokio::sync::mpsc;
use tokio::time::{Instant, MissedTickBehavior, interval_at, sleep_until};

use super::{
    Final, InboundDataPolicy, Outbound, Shared, SinkError, SubscriptionConfig, SubscriptionError,
    SubscriptionResult, SubscriptionSink,
};

/// Pings and supervisor-initiated finals; small because the writer drains it first.
const CONTROL_CAPACITY: usize = 8;

enum Control {
    Ping,
    Final(Final),
}

pub(super) async fn run<Sub, F, Fut>(socket: WebSocket, config: SubscriptionConfig, start: F)
where
    Sub: XrpcSubscription,
    F: FnOnce(SubscriptionSink<Sub>) -> Fut,
    Fut: Future<Output = SubscriptionResult<Sub::Error>>,
{
    let (data_tx, data_rx) = mpsc::channel(config.buffer_capacity.max(1));
    let (ctrl_tx, ctrl_rx) = mpsc::channel(CONTROL_CAPACITY);
    let shared = Arc::new(Shared::default());
    let sink = SubscriptionSink::<Sub>::new(data_tx, Arc::clone(&shared), config.slow_consumer);
    let (ws_tx, mut ws_rx) = socket.split();

    let mut handler = pin!(drive_handler(start, sink));
    let mut writer = pin!(write_loop(ws_tx, data_rx, ctrl_rx));
    let mut handler_done = false;
    let mut writer_done = false;

    let mut keepalive = config.ping_interval.map(|period| {
        let mut ticker = interval_at(Instant::now() + period, period);
        ticker.set_missed_tick_behavior(MissedTickBehavior::Delay);
        ticker
    });
    let mut last_seen = Instant::now();
    let mut deadline: Option<Instant> = None;

    // Supervisor-initiated close: stop sinks, jump the queue, bound the remaining lifetime.
    let initiate = |deadline: &mut Option<Instant>, last: Final| {
        if shared.begin_close() {
            let _ = ctrl_tx.try_send(Control::Final(last));
        }
        deadline.get_or_insert(Instant::now() + config.close_timeout);
    };

    loop {
        let expire = async {
            match deadline {
                Some(at) => sleep_until(at).await,
                None => pending().await,
            }
        };
        let tick = async {
            match keepalive.as_mut() {
                Some(ticker) => {
                    ticker.tick().await;
                }
                None => pending().await,
            }
        };
        tokio::select! {
            biased;
            () = expire => break,
            () = shared.notify.notified() => {
                if let Some(last) = shared.take_priority() {
                    let _ = ctrl_tx.try_send(Control::Final(last));
                }
                deadline.get_or_insert(Instant::now() + config.close_timeout);
            }
            result = &mut writer, if !writer_done => {
                writer_done = true;
                if result.is_err() {
                    break;
                }
                // Close sent; give the peer `close_timeout` to answer the handshake.
                deadline.get_or_insert(Instant::now() + config.close_timeout);
            }
            incoming = ws_rx.next() => match incoming {
                Some(Ok(Message::Close(_)) | Err(_)) | None => break,
                Some(Ok(Message::Text(_) | Message::Binary(_))) => {
                    last_seen = Instant::now();
                    if config.inbound_data == InboundDataPolicy::Close {
                        initiate(&mut deadline, Final::close(1003, "inbound data not accepted"));
                    }
                }
                Some(Ok(Message::Ping(_) | Message::Pong(_))) => last_seen = Instant::now(),
            },
            () = tick => {
                if config
                    .idle_timeout
                    .is_some_and(|limit| last_seen.elapsed() >= limit)
                {
                    initiate(&mut deadline, Final::close(1001, "idle timeout"));
                } else {
                    let _ = ctrl_tx.try_send(Control::Ping);
                }
            }
            () = &mut handler, if !handler_done => handler_done = true,
        }
    }
    // Returning drops the handler future (cancelling it), the writer, and the receiver, so every
    // remaining sink clone observes `SinkError::Closed` and `closed()` resolves.
}

async fn drive_handler<Sub, F, Fut>(start: F, sink: SubscriptionSink<Sub>)
where
    Sub: XrpcSubscription,
    F: FnOnce(SubscriptionSink<Sub>) -> Fut,
    Fut: Future<Output = SubscriptionResult<Sub::Error>>,
{
    let outcome = start(sink.clone()).await;
    let _ = match outcome {
        Ok(()) => sink.close(),
        Err(SubscriptionError::Declared { error, message }) => {
            sink.send_error(&error, message.as_deref())
        }
        Err(SubscriptionError::Named { error, message }) => {
            sink.send_error_named(&error, message.as_deref())
        }
        Err(SubscriptionError::Sink(SinkError::Encode(_))) => sink.send_error_named(
            "InternalServerError",
            Some("failed to encode subscription message"),
        ),
        Err(SubscriptionError::Sink(_)) => Ok(()),
    };
}

async fn write_loop(
    mut ws: SplitSink<WebSocket, Message>,
    mut data: mpsc::Receiver<Outbound>,
    mut ctrl: mpsc::Receiver<Control>,
) -> Result<(), axum::Error> {
    loop {
        let item = tokio::select! {
            biased;
            control = ctrl.recv() => match control {
                Some(Control::Ping) => Outbound::Frame(Message::Ping(Bytes::new())),
                Some(Control::Final(last)) => Outbound::Final(last),
                None => return Ok(()),
            },
            queued = data.recv() => queued.unwrap_or(Outbound::Final(Final::close(1000, ""))),
        };
        match item {
            Outbound::Frame(message) => ws.send(message).await?,
            Outbound::Final(last) => {
                if let Some(frame) = last.frame {
                    ws.send(frame).await?;
                }
                let close = CloseFrame {
                    code: last.close_code,
                    reason: Utf8Bytes::from_static(last.reason),
                };
                ws.send(Message::Close(Some(close))).await?;
                return Ok(());
            }
        }
    }
}
