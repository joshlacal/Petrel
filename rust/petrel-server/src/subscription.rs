//! Server-side XRPC event-stream subscriptions: `GET /xrpc/<nsid>` upgraded to a WebSocket.
//!
//! [`XrpcRouter::subscription`] mounts a generated [`XrpcSubscription`] endpoint. Everything that can
//! fail with an ordinary XRPC error runs **before** the upgrade and answers with the normal
//! `{"error", "message"}` JSON envelope: the auth extractor `A` (any axum [`FromRequestParts`] such as
//! [`ServiceAuth`](crate::axum::ServiceAuth), [`DpopResourceAuth`](crate::axum::DpopResourceAuth), or
//! `()` for none), typed query params (`400 InvalidRequest`), a missing/invalid WebSocket upgrade
//! (`400 InvalidRequest`), and the optional `prepare` step of [`XrpcRouter::subscription_with`].
//!
//! After the upgrade the handler gets a typed [`SubscriptionSink`]:
//! - [`send`](SubscriptionSink::send) frames a message-union member as `{op: 1, t: "#member"}` + DAG-CBOR
//!   body (or the `xrpc.v1.json` envelope when the lexicon declares that subprotocol);
//! - [`send_error`](SubscriptionSink::send_error) emits an `op: -1` error frame, then closes;
//! - returning `Ok(())` closes gracefully; returning `Err` sends the error frame first.
//!
//! The outbound buffer is bounded ([`SubscriptionConfig::buffer_capacity`]). When it fills,
//! [`SlowConsumerPolicy::Disconnect`] (the default, matching the reference PDS) sends a
//! `ConsumerTooSlow` error frame ahead of the backlog and disconnects. The connection pings the client
//! and closes it after [`SubscriptionConfig::idle_timeout`] without inbound traffic, caps inbound
//! messages at [`SubscriptionConfig::max_inbound_message_bytes`], and ignores inbound data frames.
//! When the connection ends for any reason the handler future is dropped in place (no task is
//! spawned per connection beyond axum's upgrade task) and every sink clone reports
//! [`SinkError::Closed`].
//!
//! # Example
//!
//! ```no_run
//! use petrel_api::generated::com::atproto::label::subscribe_labels::{
//!     Error, Info, Message, SubscribeLabels,
//! };
//! use petrel_server::axum::XrpcRouter;
//! use petrel_server::subscription::SubscriptionError;
//!
//! let router = XrpcRouter::<()>::new()
//!     .subscription::<SubscribeLabels, (), _, _>(|_state, (), params, sink| async move {
//!         if params.cursor.is_some_and(|cursor| cursor > 1_000) {
//!             return Err(SubscriptionError::declared(Error::FutureCursor, None));
//!         }
//!         let info = Info { name: "OutdatedCursor".into(), message: None, extra_data: None };
//!         sink.send(&Message::Info(Box::new(info))).await?;
//!         sink.closed().await; // keep streaming until the client goes away
//!         Ok(())
//!     })
//!     .with_state(());
//! # let _ = router;
//! ```

mod connection;

use std::convert::Infallible;
use std::fmt;
use std::future::Future;
use std::marker::PhantomData;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, PoisonError};
use std::time::Duration;

use axum::Router;
use axum::extract::ws::rejection::WebSocketUpgradeRejection;
use axum::extract::ws::{Message, WebSocketUpgrade};
use axum::extract::{FromRequestParts, State};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::routing::get;
use petrel_core::{
    DeclaredXrpcError, FrameError, FromQueryParams, ToValue, XRPC_V1_JSON_SUBPROTOCOL,
    XrpcSubscription, encode_subscription_error, encode_subscription_message,
};
use tokio::sync::{Notify, mpsc};

use crate::axum::{XrpcParams, XrpcRejection, XrpcRouter};

/// ATProto error name sent when a consumer cannot keep up with the stream.
pub const CONSUMER_TOO_SLOW: &str = "ConsumerTooSlow";

/// What happens when the bounded outbound buffer is full.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[non_exhaustive]
pub enum SlowConsumerPolicy {
    /// Fail the send, emit a `ConsumerTooSlow` error frame ahead of the backlog, and close (default).
    Disconnect,
    /// Apply backpressure: wait up to this long for buffer space, then disconnect as above.
    Wait(Duration),
}

/// What happens to inbound text/binary frames (event-stream clients send none).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[non_exhaustive]
pub enum InboundDataPolicy {
    /// Discard them (default; matches the reference implementation).
    Ignore,
    /// Close the connection with code 1003 (unsupported data).
    Close,
}

/// Per-route subscription connection settings.
#[derive(Debug, Clone)]
#[non_exhaustive]
pub struct SubscriptionConfig {
    /// Frames buffered per connection before [`SlowConsumerPolicy`] applies (minimum 1).
    pub buffer_capacity: usize,
    /// Policy when the buffer is full.
    pub slow_consumer: SlowConsumerPolicy,
    /// Interval between server pings (`None` disables pings).
    pub ping_interval: Option<Duration>,
    /// Close after this long without any inbound frame, pongs included (`None` disables).
    /// Checked on each ping tick, so it needs `ping_interval`.
    pub idle_timeout: Option<Duration>,
    /// How long a closing connection may take to flush its final frames and close handshake.
    pub close_timeout: Duration,
    /// Largest inbound WebSocket message/frame accepted; larger ones drop the connection.
    pub max_inbound_message_bytes: usize,
    /// Handling of inbound text/binary frames.
    pub inbound_data: InboundDataPolicy,
}

impl Default for SubscriptionConfig {
    fn default() -> Self {
        Self {
            buffer_capacity: 1024,
            slow_consumer: SlowConsumerPolicy::Disconnect,
            ping_interval: Some(Duration::from_secs(30)),
            idle_timeout: Some(Duration::from_secs(90)),
            close_timeout: Duration::from_secs(5),
            max_inbound_message_bytes: 4096,
            inbound_data: InboundDataPolicy::Ignore,
        }
    }
}

/// Failure to queue a frame on a [`SubscriptionSink`].
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[non_exhaustive]
pub enum SinkError {
    /// The connection is closed or closing.
    #[error("subscription stream is closed")]
    Closed,
    /// The buffer was full; a `ConsumerTooSlow` error frame was sent and the stream is closing.
    #[error("subscription consumer is too slow; stream closed")]
    ConsumerTooSlow,
    /// The message could not be framed.
    #[error(transparent)]
    Encode(#[from] FrameError),
}

/// Terminal outcome of a subscription handler.
#[derive(Debug)]
pub enum SubscriptionError<E> {
    /// Send this declared lexicon error frame, then close.
    Declared {
        /// Declared error.
        error: E,
        /// Optional human-readable message.
        message: Option<String>,
    },
    /// Send an error frame with an arbitrary name, then close.
    Named {
        /// Wire error name.
        error: String,
        /// Optional human-readable message.
        message: Option<String>,
    },
    /// A sink failure propagated with `?`. `Closed`/`ConsumerTooSlow` send nothing more;
    /// `Encode` sends an `InternalServerError` frame.
    Sink(SinkError),
}

impl<E> SubscriptionError<E> {
    /// A declared error frame.
    pub fn declared(error: E, message: impl Into<Option<String>>) -> Self {
        Self::Declared {
            error,
            message: message.into(),
        }
    }

    /// An error frame with an arbitrary wire name.
    pub fn named(error: impl Into<String>, message: impl Into<Option<String>>) -> Self {
        Self::Named {
            error: error.into(),
            message: message.into(),
        }
    }
}

impl<E> From<SinkError> for SubscriptionError<E> {
    fn from(error: SinkError) -> Self {
        Self::Sink(error)
    }
}

/// Result returned by subscription handlers.
pub type SubscriptionResult<E> = Result<(), SubscriptionError<E>>;

/// A frame encoded once for subscription `Sub`; cheap to clone, so one encoding can fan out to many sinks.
pub struct EncodedFrame<Sub> {
    message: Message,
    _sub: PhantomData<fn() -> Sub>,
}

impl<Sub> Clone for EncodedFrame<Sub> {
    fn clone(&self) -> Self {
        Self {
            message: self.message.clone(),
            _sub: PhantomData,
        }
    }
}

impl<Sub> fmt::Debug for EncodedFrame<Sub> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("EncodedFrame")
            .field("len", &self.len())
            .finish()
    }
}

impl<Sub: XrpcSubscription> EncodedFrame<Sub> {
    /// Encodes a message-union member (`op: 1`, `t` = `#member` within `Sub::NSID`).
    pub fn message(message: &Sub::Message) -> Result<Self, FrameError>
    where
        Sub::Message: ToValue,
    {
        Self::wrap(encode_subscription_message::<Sub>(message)?)
    }

    /// Encodes an error frame (`op: -1`).
    pub fn error(error: &Sub::Error, message: Option<&str>) -> Result<Self, FrameError> {
        Self::wrap(encode_subscription_error::<Sub>(error, message)?)
    }

    fn wrap(bytes: Vec<u8>) -> Result<Self, FrameError> {
        let message = if Sub::SUBPROTOCOL == Some(XRPC_V1_JSON_SUBPROTOCOL) {
            let text = String::from_utf8(bytes)
                .map_err(|_| FrameError::InvalidPayload("JSON frame is not UTF-8"))?;
            Message::Text(text.into())
        } else {
            Message::Binary(bytes.into())
        };
        Ok(Self {
            message,
            _sub: PhantomData,
        })
    }
}

impl<Sub> EncodedFrame<Sub> {
    /// Encoded length in bytes.
    pub fn len(&self) -> usize {
        match &self.message {
            Message::Text(text) => text.len(),
            Message::Binary(bytes) => bytes.len(),
            _ => 0,
        }
    }

    /// Whether the encoding is empty (never true for a valid frame).
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

/// Last frames of a connection: optional frame, then a close frame.
#[derive(Debug)]
struct Final {
    frame: Option<Message>,
    close_code: u16,
    reason: &'static str,
}

impl Final {
    const fn close(close_code: u16, reason: &'static str) -> Self {
        Self {
            frame: None,
            close_code,
            reason,
        }
    }
}

#[derive(Debug)]
enum Outbound {
    Frame(Message),
    Final(Final),
}

/// State shared by every sink clone and the connection driver.
#[derive(Debug, Default)]
struct Shared {
    closing: AtomicBool,
    /// Final frames that must jump the (full) queue.
    priority: Mutex<Option<Final>>,
    notify: Notify,
}

impl Shared {
    /// Marks the stream closing; true for the first caller only.
    fn begin_close(&self) -> bool {
        !self.closing.swap(true, Ordering::AcqRel)
    }

    fn is_closing(&self) -> bool {
        self.closing.load(Ordering::Acquire)
    }

    fn preempt(&self, last: Final) {
        self.priority
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .get_or_insert(last);
        self.notify.notify_one();
    }

    fn take_priority(&self) -> Option<Final> {
        self.priority
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .take()
    }
}

/// Typed, cloneable outbound half of one subscription connection.
pub struct SubscriptionSink<Sub> {
    tx: mpsc::Sender<Outbound>,
    shared: Arc<Shared>,
    policy: SlowConsumerPolicy,
    _sub: PhantomData<fn() -> Sub>,
}

impl<Sub> Clone for SubscriptionSink<Sub> {
    fn clone(&self) -> Self {
        Self {
            tx: self.tx.clone(),
            shared: Arc::clone(&self.shared),
            policy: self.policy,
            _sub: PhantomData,
        }
    }
}

impl<Sub> fmt::Debug for SubscriptionSink<Sub> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("SubscriptionSink")
            .field("closing", &self.shared.is_closing())
            .field("capacity", &self.tx.capacity())
            .field("policy", &self.policy)
            .finish()
    }
}

impl<Sub: XrpcSubscription> SubscriptionSink<Sub> {
    fn new(tx: mpsc::Sender<Outbound>, shared: Arc<Shared>, policy: SlowConsumerPolicy) -> Self {
        Self {
            tx,
            shared,
            policy,
            _sub: PhantomData,
        }
    }

    /// Encodes and queues one message-union member.
    pub async fn send(&self, message: &Sub::Message) -> Result<(), SinkError>
    where
        Sub::Message: ToValue,
    {
        self.send_encoded(EncodedFrame::message(message)?).await
    }

    /// Queues a pre-encoded frame (see [`EncodedFrame`]).
    pub async fn send_encoded(&self, frame: EncodedFrame<Sub>) -> Result<(), SinkError> {
        if self.shared.is_closing() {
            return Err(SinkError::Closed);
        }
        let item = Outbound::Frame(frame.message);
        match self.policy {
            SlowConsumerPolicy::Disconnect => match self.tx.try_send(item) {
                Ok(()) => Ok(()),
                Err(mpsc::error::TrySendError::Full(_)) => Err(self.too_slow()),
                Err(mpsc::error::TrySendError::Closed(_)) => Err(SinkError::Closed),
            },
            SlowConsumerPolicy::Wait(limit) => {
                match tokio::time::timeout(limit, self.tx.send(item)).await {
                    Ok(Ok(())) => Ok(()),
                    Ok(Err(_)) => Err(SinkError::Closed),
                    Err(_) => Err(self.too_slow()),
                }
            }
        }
    }

    /// Emits an `op: -1` error frame after already-queued frames, then closes the stream.
    pub fn send_error(&self, error: &Sub::Error, message: Option<&str>) -> Result<(), SinkError> {
        let frame = EncodedFrame::<Sub>::error(error, message)?;
        self.finish(Final {
            frame: Some(frame.message),
            close_code: 1000,
            reason: "",
        })
    }

    /// [`send_error`](Self::send_error) with an arbitrary wire error name.
    pub fn send_error_named(&self, name: &str, message: Option<&str>) -> Result<(), SinkError> {
        self.send_error(&Sub::Error::from_wire_name(name), message)
    }

    /// Closes gracefully (code 1000) after already-queued frames.
    pub fn close(&self) -> Result<(), SinkError> {
        self.finish(Final::close(1000, ""))
    }

    /// Whether the stream is closing or closed; further sends fail.
    pub fn is_closed(&self) -> bool {
        self.shared.is_closing() || self.tx.is_closed()
    }

    /// Resolves once the connection has ended (client gone, timeout, or close completed).
    pub async fn closed(&self) {
        self.tx.closed().await;
    }

    /// Free outbound buffer slots right now.
    pub fn capacity(&self) -> usize {
        self.tx.capacity()
    }

    fn too_slow(&self) -> SinkError {
        if self.shared.begin_close() {
            let error = Sub::Error::from_wire_name(CONSUMER_TOO_SLOW);
            let frame = EncodedFrame::<Sub>::error(&error, Some("stream consumer too slow"))
                .ok()
                .map(|frame| frame.message);
            self.shared.preempt(Final {
                frame,
                close_code: 1008,
                reason: "consumer too slow",
            });
        }
        SinkError::ConsumerTooSlow
    }

    fn finish(&self, last: Final) -> Result<(), SinkError> {
        if !self.shared.begin_close() {
            return Err(SinkError::Closed);
        }
        match self.tx.try_send(Outbound::Final(last)) {
            Ok(()) => Ok(()),
            Err(mpsc::error::TrySendError::Full(Outbound::Final(last))) => {
                self.shared.preempt(last);
                Ok(())
            }
            Err(_) => Err(SinkError::Closed),
        }
    }
}

/// Completes a WebSocket upgrade into a subscription stream driven by `start`.
///
/// Building block for routes that need extractors [`XrpcRouter`] does not model: run your own
/// checks in a plain axum handler, then return this response.
pub fn serve_subscription<Sub, F, Fut>(
    ws: WebSocketUpgrade,
    config: SubscriptionConfig,
    start: F,
) -> Response
where
    Sub: XrpcSubscription + 'static,
    Sub::Error: Send + 'static,
    F: FnOnce(SubscriptionSink<Sub>) -> Fut + Send + 'static,
    Fut: Future<Output = SubscriptionResult<Sub::Error>> + Send + 'static,
{
    let limit = config.max_inbound_message_bytes.max(256);
    let mut ws = ws.max_message_size(limit).max_frame_size(limit);
    if let Some(protocol) = Sub::SUBPROTOCOL {
        ws = ws.protocols([protocol]);
    }
    ws.on_upgrade(move |socket| connection::run::<Sub, _, _>(socket, config, start))
}

fn not_an_upgrade(rejection: &WebSocketUpgradeRejection) -> Response {
    XrpcRejection {
        status: StatusCode::BAD_REQUEST,
        error: "InvalidRequest".to_owned(),
        message: Some(format!(
            "subscription endpoint requires a WebSocket upgrade: {rejection}"
        )),
    }
    .into_response()
}

impl<S> XrpcRouter<S>
where
    S: Clone + Send + Sync + 'static,
{
    /// Registers an event-stream subscription (`GET /xrpc/{Sub::NSID}` + WebSocket upgrade) with
    /// [`SubscriptionConfig::default`].
    ///
    /// `A` authenticates before the upgrade (`()` for public streams); its rejection is returned as a
    /// normal HTTP response.
    #[must_use]
    pub fn subscription<Sub, A, F, Fut>(self, handler: F) -> Self
    where
        Sub: XrpcSubscription + 'static,
        Sub::Params: FromQueryParams + Send + 'static,
        Sub::Error: Send + 'static,
        A: FromRequestParts<S> + Send + 'static,
        F: Fn(S, A, Sub::Params, SubscriptionSink<Sub>) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = SubscriptionResult<Sub::Error>> + Send + 'static,
    {
        self.subscription_with::<Sub, A, _, _, _, Infallible, _, _>(
            SubscriptionConfig::default(),
            |state, auth, params| async move { Ok((state, auth, params)) },
            move |(state, auth, params), sink| handler(state, auth, params, sink),
        )
    }

    /// Registers a subscription with explicit `config` and an async `prepare` step that runs before
    /// the upgrade (cursor validation, ticket/slot checks, rate limits). `prepare` returning
    /// `Err(response)` answers the HTTP request with that response instead of upgrading; `Ok(ctx)`
    /// is passed to `handler` after the upgrade.
    #[must_use]
    #[allow(clippy::type_repetition_in_bounds)]
    pub fn subscription_with<Sub, A, P, PFut, C, R, F, Fut>(
        self,
        config: SubscriptionConfig,
        prepare: P,
        handler: F,
    ) -> Self
    where
        Sub: XrpcSubscription + 'static,
        Sub::Params: FromQueryParams + Send + 'static,
        Sub::Error: Send + 'static,
        A: FromRequestParts<S> + Send + 'static,
        P: Fn(S, A, Sub::Params) -> PFut + Clone + Send + Sync + 'static,
        PFut: Future<Output = Result<C, R>> + Send + 'static,
        R: IntoResponse + 'static,
        C: Send + 'static,
        F: Fn(C, SubscriptionSink<Sub>) -> Fut + Clone + Send + Sync + 'static,
        Fut: Future<Output = SubscriptionResult<Sub::Error>> + Send + 'static,
    {
        let path = format!("/xrpc/{}", Sub::NSID);
        let route = get(
            move |State(state): State<S>,
                  auth: A,
                  XrpcParams(params): XrpcParams<Sub::Params>,
                  ws: Result<WebSocketUpgrade, WebSocketUpgradeRejection>| {
                let prepare = prepare.clone();
                let handler = handler.clone();
                let config = config.clone();
                async move {
                    let ws = match ws {
                        Ok(ws) => ws,
                        Err(rejection) => return not_an_upgrade(&rejection),
                    };
                    let ctx = match prepare(state, auth, params).await {
                        Ok(ctx) => ctx,
                        Err(response) => return response.into_response(),
                    };
                    serve_subscription::<Sub, _, _>(ws, config, move |sink| handler(ctx, sink))
                }
            },
        );
        self.merge_router(Router::new().route(&path, route))
    }
}
