//! Resilient high-level subscriptions for `com.atproto.sync.subscribeRepos` and generic
//! Lexicon `subscription` endpoints (`EventStreamSubscription` / `LabelSubscription`).

use std::marker::PhantomData;
use std::sync::Arc;
use std::time::Duration;

use petrel::rt::MaybeSend;
use petrel_api::generated::com::atproto::label::subscribe_labels::SubscribeLabels;
use petrel_core::{FromValue, SubscriptionFrame, XrpcSubscription, decode_frame_with};
use url::Url;

use crate::decoder::{
    EventStreamIgnoredFrame, IgnoredFrameReason, RelayFrame, RelayFrameDecoder,
    RelayFrameDecodingMode, lenient_frame_hints,
};
use crate::pump::{
    BoxedEventStream, EventStreamCursorCoordinator, EventStreamError, EventStreamPumpConfiguration,
    EventStreamStep, FirehoseBackoffConfiguration, FirehoseCursorStorage, FirehoseStreamError,
    InMemoryFirehoseCursorStorage, make_pump_stream,
};
use crate::transport::{
    FirehoseSubscriptionError, FirehoseWebSocketOptions, FirehoseWebSocketSessionFactory,
    default_websocket_factory,
};
use crate::types::RelayEvent;

/// Events emitted by [`FirehoseSubscription`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FirehoseSubscriptionEvent {
    /// A decoded `#commit`, `#sync`, `#identity`, `#account`, or `#info` message.
    Event(RelayEvent),
    /// The stream skipped from `expected - 1` to `received`; informational, the stream continues.
    SequenceGap { expected: i64, received: i64 },
    /// A frame skipped instead of ending the stream: unknown `op` or `t`, schema mismatch,
    /// a frame that failed canonical parsing, or a message the transport refused as too large
    /// (see [`IgnoredFrameReason`]).
    IgnoredFrame(EventStreamIgnoredFrame),
}

/// Connection configuration shared by [`FirehoseSubscription`] and [`EventStreamSubscription`].
#[derive(Debug, Clone)]
pub struct FirehoseSubscriptionConfiguration {
    /// Full WebSocket subscription URL, e.g. `wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos`.
    pub url: Url,
    /// Durable cursor store.
    pub cursor_storage: Arc<dyn FirehoseCursorStorage>,
    /// Reconnect exponential backoff parameters.
    pub backoff: FirehoseBackoffConfiguration,
    /// WebSocket session factory.
    pub session_factory: Arc<dyn FirehoseWebSocketSessionFactory>,
    /// Automatically advance the cursor once the consumer asks for the next element.
    ///
    /// When `false`, the cursor only moves when the consumer calls `acknowledge`. Every
    /// reconnect resumes from the last *acknowledged* cursor, so events delivered but not yet
    /// acknowledged are delivered again (at-least-once delivery): consumers must tolerate
    /// duplicates or acknowledge before they can lose an event.
    pub auto_acknowledge: bool,
    /// Reconnect from the cursor on `ConsumerTooSlow` instead of ending the stream.
    pub reconnects_on_consumer_too_slow: bool,
    /// Consecutive [`FirehoseSubscriptionError::FrameTooLarge`] failures tolerated at the same
    /// stream position before the stream ends (default 3; values below 1 act as 1).
    ///
    /// The transport cannot read an oversize message, so its sequence is unknown and it cannot
    /// be skipped. Each failure yields an [`IgnoredFrameReason::FrameTooLarge`] event and a
    /// reconnect with backoff from the same cursor (the relay may have been mid-way through a
    /// transient burst). The position is the last sequence decoded before the failure; any
    /// progress past it resets the count. When the limit is reached the stream ends with
    /// [`FirehoseSubscriptionError::FrameTooLargeAtCursor`] naming that sequence, so the
    /// consumer can raise `maximum_message_size` or move its stored cursor past the frame.
    pub oversize_frame_retry_limit: u32,
    /// A connection that stayed open at least this long resets reconnect backoff when it
    /// ends (default 30s).
    pub backoff_reset_after: Duration,
    /// A connection that delivered at least this many frames resets reconnect backoff when it
    /// ends (default 100). Until a connection is stable by either measure, backoff keeps
    /// growing, so a server that accepts, sends a frame or two, and closes cannot drive a
    /// reconnect loop at the initial delay.
    pub backoff_reset_after_frames: u64,
}

impl FirehoseSubscriptionConfiguration {
    /// Creates configuration with default in-memory cursor storage, default backoff, and platform
    /// WebSocket transport.
    pub fn new(url: Url) -> Self {
        Self {
            url,
            cursor_storage: Arc::new(InMemoryFirehoseCursorStorage::new()),
            backoff: FirehoseBackoffConfiguration::new(),
            session_factory: default_websocket_factory(FirehoseWebSocketOptions::new()),
            auto_acknowledge: false,
            reconnects_on_consumer_too_slow: false,
            oversize_frame_retry_limit: 3,
            backoff_reset_after: Duration::from_secs(30),
            backoff_reset_after_frames: 100,
        }
    }

    pub(crate) fn pump_configuration(&self) -> EventStreamPumpConfiguration {
        EventStreamPumpConfiguration {
            url: self.url.clone(),
            cursor_storage: Arc::clone(&self.cursor_storage),
            backoff: self.backoff.clone(),
            session_factory: Arc::clone(&self.session_factory),
            auto_acknowledge: self.auto_acknowledge,
            reconnects_on_consumer_too_slow: self.reconnects_on_consumer_too_slow,
            oversize_frame_retry_limit: self.oversize_frame_retry_limit.max(1),
            backoff_reset_after: self.backoff_reset_after,
            backoff_reset_after_frames: self.backoff_reset_after_frames,
        }
    }
}

/// Endpoint URL derivation matching Swift `FirehoseEndpoint`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FirehoseEndpoint;

impl FirehoseEndpoint {
    /// Converts `https://host[/base]` (or `http://...`) to `wss://host[/base]/xrpc/<nsid>`.
    pub fn subscription_url(service: &Url, nsid: &str) -> Url {
        let mut out = service.clone();
        match out.scheme().to_ascii_lowercase().as_str() {
            "https" => {
                let _ = out.set_scheme("wss");
            }
            "http" => {
                let _ = out.set_scheme("ws");
            }
            _ => {}
        }
        let base = out.path().trim_matches('/');
        let new_path = if base.is_empty() {
            format!("/xrpc/{nsid}")
        } else {
            format!("/{base}/xrpc/{nsid}")
        };
        out.set_path(&new_path);
        out
    }
}

/// Resilient consumer of `com.atproto.sync.subscribeRepos`.
#[derive(Debug)]
pub struct FirehoseSubscription {
    /// Active subscription configuration.
    pub configuration: FirehoseSubscriptionConfiguration,
    coordinator: Arc<EventStreamCursorCoordinator>,
}

impl FirehoseSubscription {
    /// Creates a subscription from explicit configuration.
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    pub fn new(configuration: FirehoseSubscriptionConfiguration) -> Self {
        let coordinator = Arc::new(EventStreamCursorCoordinator::new(Arc::clone(
            &configuration.cursor_storage,
        )));
        Self {
            configuration,
            coordinator,
        }
    }

    /// Creates a firehose subscription from a service endpoint URL (e.g. `https://bsky.network`).
    pub fn from_service(
        service: &Url,
        cursor_storage: Arc<dyn FirehoseCursorStorage>,
        auto_acknowledge: bool,
    ) -> Self {
        let mut config = FirehoseSubscriptionConfiguration::new(
            FirehoseEndpoint::subscription_url(service, "com.atproto.sync.subscribeRepos"),
        );
        config.cursor_storage = cursor_storage;
        config.auto_acknowledge = auto_acknowledge;
        Self::new(config)
    }

    /// Persists `sequence` as the acknowledged cursor; rejects non-increasing values.
    pub async fn acknowledge(&self, sequence: i64) -> Result<(), FirehoseSubscriptionError> {
        self.coordinator.acknowledge(sequence).await
    }

    /// Persists the sequence number carried by `event` (no-op for `#info`/`#error`).
    pub async fn acknowledge_event(
        &self,
        event: &RelayEvent,
    ) -> Result<(), FirehoseSubscriptionError> {
        let Some(seq) = event.sequence() else {
            return Ok(());
        };
        self.acknowledge(seq).await
    }

    /// Returns the last persisted cursor.
    pub async fn current_cursor(&self) -> Option<i64> {
        self.coordinator.current_cursor().await
    }

    /// Connects and returns a pull-based stream of firehose events.
    ///
    /// A single bad frame never ends the stream: frames that fail canonical parsing or schema
    /// decoding arrive as [`FirehoseSubscriptionEvent::IgnoredFrame`]. The stream ends on a
    /// server `#error` frame (except `ConsumerTooSlow` when reconnecting is enabled), a
    /// non-retryable transport error, a sequence regression or duplicate, a cursor storage
    /// failure, or too many oversize frames at one position. With
    /// `auto_acknowledge == false`, reconnects redeliver unacknowledged events (see
    /// [`FirehoseSubscriptionConfiguration::auto_acknowledge`]).
    pub fn events(
        &self,
    ) -> BoxedEventStream<Result<FirehoseSubscriptionEvent, FirehoseStreamError>> {
        make_pump_stream(
            self.configuration.pump_configuration(),
            Arc::clone(&self.coordinator),
            Arc::new(Self::step),
            Arc::new(
                |expected, received| FirehoseSubscriptionEvent::SequenceGap { expected, received },
            ),
            Arc::new(FirehoseSubscriptionEvent::IgnoredFrame),
        )
    }

    // Signature fixed by `DecodeFn`; a single frame can no longer fail the stream.
    #[allow(clippy::unnecessary_wraps)]
    pub(crate) fn step(
        data: &[u8],
    ) -> Result<EventStreamStep<FirehoseSubscriptionEvent>, FirehoseStreamError> {
        let parsed = match RelayFrameDecoder::parse(data) {
            Ok(parsed) => parsed,
            Err(err) => {
                return Ok(malformed_frame_step(
                    data,
                    err.raw_value().to_owned(),
                    FirehoseSubscriptionEvent::IgnoredFrame,
                ));
            }
        };
        let frame = match RelayFrameDecoder::decode_parsed(&parsed, RelayFrameDecodingMode::Lenient)
        {
            Ok(f) => f,
            Err(err) => {
                // `op: 1` with a schema mismatch, or an `op: -1` error frame whose body is
                // not a valid error object. Only well-formed error frames end the stream.
                let reason = if parsed.operation == 1 {
                    IgnoredFrameReason::UndecodablePayload(err.raw_value().to_owned())
                } else {
                    IgnoredFrameReason::MalformedFrame(err.raw_value().to_owned())
                };
                let ignored = EventStreamIgnoredFrame {
                    operation: parsed.operation,
                    r#type: parsed.r#type.clone(),
                    sequence: parsed.sequence,
                    reason,
                };
                return Ok(EventStreamStep::deliver(
                    FirehoseSubscriptionEvent::IgnoredFrame(ignored),
                    parsed.sequence,
                ));
            }
        };

        match frame {
            RelayFrame::Event(RelayEvent::Error(err)) => Ok(EventStreamStep::fail(
                EventStreamError::from_wire(&err.error, err.message),
            )),
            RelayFrame::Event(event) => {
                let seq = event.sequence();
                Ok(EventStreamStep::deliver(
                    FirehoseSubscriptionEvent::Event(event),
                    seq,
                ))
            }
            RelayFrame::Ignored(ignored) => {
                let seq = ignored.sequence;
                Ok(EventStreamStep::deliver(
                    FirehoseSubscriptionEvent::IgnoredFrame(ignored),
                    seq,
                ))
            }
        }
    }
}

/// Elements emitted by [`EventStreamSubscription`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EventStreamEvent<Message> {
    /// A decoded subscription message union and its sequence number, if present.
    Message {
        message: Message,
        sequence: Option<i64>,
    },
    /// The stream skipped from `expected - 1` to `received`; informational, stream continues.
    SequenceGap { expected: i64, received: i64 },
    /// A frame skipped by the consumer (unknown `op` or payload mismatch).
    IgnoredFrame(EventStreamIgnoredFrame),
}

/// Resilient consumer for any Lexicon `subscription` endpoint decoding into `S::Message`.
#[derive(Debug)]
pub struct EventStreamSubscription<S: XrpcSubscription> {
    /// Connection settings (`url` is the full `wss://.../xrpc/<nsid>` URL).
    pub configuration: FirehoseSubscriptionConfiguration,
    /// Lexicon NSID expanded onto `#fragment` frame headers.
    pub nsid: String,
    coordinator: Arc<EventStreamCursorCoordinator>,
    _marker: PhantomData<fn() -> S>,
}

impl<S> EventStreamSubscription<S>
where
    S: XrpcSubscription,
    S::Message: FromValue + MaybeSend + petrel::rt::MaybeSync + 'static,
{
    /// Creates a subscription consumer for `S`.
    pub fn new(configuration: FirehoseSubscriptionConfiguration) -> Self {
        Self::with_nsid(S::NSID, configuration)
    }

    /// Creates a subscription consumer with an explicit NSID override.
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    pub fn with_nsid(
        nsid: impl Into<String>,
        configuration: FirehoseSubscriptionConfiguration,
    ) -> Self {
        let coordinator = Arc::new(EventStreamCursorCoordinator::new(Arc::clone(
            &configuration.cursor_storage,
        )));
        Self {
            configuration,
            nsid: nsid.into(),
            coordinator,
            _marker: PhantomData,
        }
    }

    /// Persists `sequence` as the cursor; rejects non-increasing values.
    pub async fn acknowledge(&self, sequence: i64) -> Result<(), FirehoseSubscriptionError> {
        self.coordinator.acknowledge(sequence).await
    }

    /// Returns the last persisted cursor.
    pub async fn current_cursor(&self) -> Option<i64> {
        self.coordinator.current_cursor().await
    }

    /// Connects and returns messages as a pull-based stream.
    pub fn events(
        &self,
    ) -> BoxedEventStream<Result<EventStreamEvent<S::Message>, FirehoseStreamError>> {
        let nsid = self.nsid.clone();
        make_pump_stream(
            self.configuration.pump_configuration(),
            Arc::clone(&self.coordinator),
            Arc::new(move |data| Self::step(data, &nsid)),
            Arc::new(|expected, received| EventStreamEvent::SequenceGap { expected, received }),
            Arc::new(EventStreamEvent::IgnoredFrame),
        )
    }

    // Signature fixed by `DecodeFn`; a single frame can no longer fail the stream.
    #[allow(clippy::unnecessary_wraps)]
    pub(crate) fn step(
        data: &[u8],
        nsid: &str,
    ) -> Result<EventStreamStep<EventStreamEvent<S::Message>>, FirehoseStreamError> {
        let frame = match decode_frame_with(data, Some(nsid)) {
            Ok(frame) => frame,
            Err(err) => {
                return Ok(malformed_frame_step(
                    data,
                    err.to_string(),
                    EventStreamEvent::IgnoredFrame,
                ));
            }
        };

        match frame {
            SubscriptionFrame::Error { error, message } => Ok(EventStreamStep::fail(
                EventStreamError::from_wire(&error, message),
            )),
            SubscriptionFrame::UnknownOperation { op } => {
                let ignored = EventStreamIgnoredFrame {
                    operation: op,
                    r#type: None,
                    sequence: None,
                    reason: IgnoredFrameReason::UnknownOperation,
                };
                Ok(EventStreamStep::deliver(
                    EventStreamEvent::IgnoredFrame(ignored),
                    None,
                ))
            }
            SubscriptionFrame::Message {
                message_type,
                payload,
                sequence,
                ..
            } => match S::Message::from_value(payload) {
                Ok(message) => Ok(EventStreamStep::deliver(
                    EventStreamEvent::Message { message, sequence },
                    sequence,
                )),
                Err(err) => {
                    let ignored = EventStreamIgnoredFrame {
                        operation: 1,
                        r#type: Some(message_type),
                        sequence,
                        reason: IgnoredFrameReason::UndecodablePayload(err.to_string()),
                    };
                    Ok(EventStreamStep::deliver(
                        EventStreamEvent::IgnoredFrame(ignored),
                        sequence,
                    ))
                }
            },
        }
    }
}

/// Turns a frame that failed parsing into an ignored-frame step.
///
/// The sequence comes from a lenient read of the raw bytes, so the pump treats it as a hint:
/// it advances the cursor only when it is newer than the last sequence seen.
fn malformed_frame_step<Output>(
    data: &[u8],
    error: String,
    wrap: impl FnOnce(EventStreamIgnoredFrame) -> Output,
) -> EventStreamStep<Output> {
    let hints = lenient_frame_hints(data);
    let sequence = hints.sequence;
    let ignored = EventStreamIgnoredFrame {
        operation: hints.operation.unwrap_or(0),
        r#type: hints.r#type,
        sequence,
        reason: IgnoredFrameReason::MalformedFrame(error),
    };
    EventStreamStep::deliver_with_sequence_hint(wrap(ignored), sequence)
}

/// Consumer of `com.atproto.label.subscribeLabels`.
pub type LabelSubscription = EventStreamSubscription<SubscribeLabels>;

impl LabelSubscription {
    /// Creates a `com.atproto.label.subscribeLabels` consumer from a labeler service URL.
    pub fn labels(service: &Url) -> Self {
        Self::labels_with(
            service,
            Arc::new(InMemoryFirehoseCursorStorage::new()),
            FirehoseBackoffConfiguration::new(),
            default_websocket_factory(FirehoseWebSocketOptions::new()),
            false,
        )
    }

    /// Creates a `com.atproto.label.subscribeLabels` consumer with explicit configuration components.
    pub fn labels_with(
        service: &Url,
        cursor_storage: Arc<dyn FirehoseCursorStorage>,
        backoff: FirehoseBackoffConfiguration,
        session_factory: Arc<dyn FirehoseWebSocketSessionFactory>,
        auto_acknowledge: bool,
    ) -> Self {
        let nsid = SubscribeLabels::NSID;
        let mut config = FirehoseSubscriptionConfiguration::new(
            FirehoseEndpoint::subscription_url(service, nsid),
        );
        config.cursor_storage = cursor_storage;
        config.backoff = backoff;
        config.session_factory = session_factory;
        config.auto_acknowledge = auto_acknowledge;
        Self::new(config)
    }
}
