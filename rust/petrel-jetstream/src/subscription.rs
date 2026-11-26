//! Live Jetstream WebSocket subscription (`v2` `xrpc.v1.json` and legacy `v1` `/subscribe`)
//! with zstd dictionary negotiation, HTTP error probe classification, reconnect backoff,
//! `options_update` mutation, and cursor resume/deduplication.

use std::collections::{BTreeSet, VecDeque};
use std::sync::Arc;
use std::time::Duration;

use async_lock::Mutex;
use bytes::Bytes;
use futures_util::stream;
use petrel_firehose::{
    BoxedEventStream, EventStreamError, FirehoseBackoffConfiguration, FirehoseCursorStorage,
    FirehoseSubscriptionError, FirehoseWebSocketOptions, FirehoseWebSocketSession,
    FirehoseWebSocketSessionFactory, default_websocket_factory,
};
use serde_json::{Value as JsonValue, json};
use url::Url;

use crate::channel::TIMESTAMP_CURSOR_FLOOR;
use crate::event::{JetstreamEvent, JetstreamFilter};
use crate::http::{JetstreamHttpTransport, default_http_transport};
use crate::wire::{JetstreamWire, JetstreamWireFrame};
use crate::zstd::{
    DEFAULT_MAX_DICT_FRAME_BYTES, DEFAULT_MAX_DICTIONARY_BYTES, JetstreamZstd,
    JetstreamZstdDictionaryDecoder, ZSTD_FRAME_MAGIC,
};

const MAX_LEGACY_EVENTS_PER_SEQ: usize = 4_096;

/// Why a Jetstream frame was skipped instead of failing the stream.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum JetstreamIgnoredReason {
    /// Not a valid JSON object or missing envelope fields.
    MalformedFrame(String),
    /// Zstd decompression failed.
    Undecompressable(String),
    /// Unknown message `$type` or legacy `kind` (additive lexicon evolution).
    UnknownType,
    /// Known type with missing/invalid required payload fields.
    UndecodablePayload(String),
    /// Sequence number at or below an event already delivered on this connection.
    DuplicateSequence(i64),
}

/// Metadata describing a frame skipped by [`JetstreamSubscription`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct JetstreamIgnoredFrame {
    pub r#type: Option<String>,
    pub sequence: Option<i64>,
    pub reason: JetstreamIgnoredReason,
}

/// Events yielded by [`JetstreamSubscription::events`].
#[derive(Debug, Clone, PartialEq)]
pub enum JetstreamSubscriptionEvent {
    /// Decoded event matching the configured [`JetstreamFilter`].
    Event(JetstreamEvent),
    /// Protocol error frame sent by the server (followed by stream termination unless
    /// `ConsumerTooSlow` reconnect is enabled).
    StreamError {
        name: String,
        message: Option<String>,
    },
    /// Ignored/unusable frame (stream continues, cursor advances when v2 seq present).
    IgnoredFrame(JetstreamIgnoredFrame),
}

/// Which cursor storage operation failed.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum CursorStorageOperation {
    Load,
    Save,
}

/// Errors thrown by [`JetstreamSubscription`].
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum JetstreamSubscriptionError {
    #[error("Jetstream connection rejected (HTTP {status}{}{})", .error.as_deref().map_or(String::new(), |e| format!(", {e}")), .message.as_deref().map_or(String::new(), |m| format!(": {m}")))]
    ConnectionRejected {
        status: u16,
        error: Option<String>,
        message: Option<String>,
    },
    #[error("compression requested on legacy /subscribe API without legacy_zstd_dictionary")]
    MissingZstdDictionary,
    #[error("options_update is only supported on the legacy /subscribe API")]
    OptionsUpdateUnsupported,
    #[error("cursor storage failed during {operation:?}: {message}")]
    CursorStorageFailure {
        operation: CursorStorageOperation,
        message: String,
    },
    #[error(transparent)]
    Transport(#[from] FirehoseSubscriptionError),
    #[error(transparent)]
    Stream(#[from] EventStreamError),
}

/// The two Jetstream WebSocket dialects.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum JetstreamApiVersion {
    /// `/xrpc/network.bsky.jetstream.subscribeEvents` (seq cursors, `xrpc.v1.json`, `zstdDictionary`).
    V2,
    /// Legacy `/subscribe` (`time_us` cursors, `wantedCollections`/`wantedDids`, `options_update`).
    V1,
}

/// Subscriber-sourced `options_update` payload for the legacy `/subscribe` API.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct JetstreamOptionsUpdate {
    pub wanted_collections: Vec<String>,
    pub wanted_dids: Vec<String>,
    pub max_message_size_bytes: usize,
}

impl JetstreamOptionsUpdate {
    /// Encodes the wire JSON text frame expected by Jetstream `/subscribe`.
    pub fn encode(&self) -> Result<String, serde_json::Error> {
        let obj = json!({
            "type": "options_update",
            "payload": {
                "wantedCollections": self.wanted_collections,
                "wantedDids": self.wanted_dids,
                "maxMessageSizeBytes": self.max_message_size_bytes,
            }
        });
        serde_json::to_string(&obj)
    }
}

/// Configuration for connecting to a live Jetstream WebSocket stream.
#[derive(Debug, Clone)]
pub struct JetstreamSubscriptionConfiguration {
    pub url: Url,
    pub filter: JetstreamFilter,
    pub cursor: Option<i64>,
    pub compression: bool,
    pub cursor_storage: Option<Arc<dyn FirehoseCursorStorage>>,
    pub backoff: FirehoseBackoffConfiguration,
    pub session_factory: Arc<dyn FirehoseWebSocketSessionFactory>,
    pub http_transport: Arc<dyn JetstreamHttpTransport>,
    pub api_version: Option<JetstreamApiVersion>,
    pub max_message_size_bytes: Option<usize>,
    pub require_hello: bool,
    pub legacy_zstd_dictionary: Option<Vec<u8>>,
    pub reconnects_on_consumer_too_slow: bool,
}

impl JetstreamSubscriptionConfiguration {
    /// Creates configuration with Jetstream WebSocket defaults (UTF-8 text frames enabled).
    pub fn new(url: Url) -> Self {
        let http_transport = default_http_transport().unwrap_or_else(|e| {
            // Fallback failing transport only if system DNS init fails catastrophically.
            Arc::new(FailingHttpTransport(e.to_string()))
        });
        Self {
            url,
            filter: JetstreamFilter::new(),
            cursor: None,
            compression: false,
            cursor_storage: None,
            backoff: FirehoseBackoffConfiguration::new(),
            session_factory: default_websocket_factory(FirehoseWebSocketOptions::jetstream()),
            http_transport,
            api_version: None,
            max_message_size_bytes: None,
            require_hello: false,
            legacy_zstd_dictionary: None,
            reconnects_on_consumer_too_slow: false,
        }
    }

    /// Resolves explicit `api_version` or infers [`JetstreamApiVersion::V1`] for `/subscribe`.
    pub fn resolved_api_version(&self) -> JetstreamApiVersion {
        if let Some(v) = self.api_version {
            return v;
        }
        let last = self
            .url
            .path_segments()
            .and_then(|mut segs| segs.rfind(|s| !s.is_empty()));
        if last == Some("subscribe") {
            JetstreamApiVersion::V1
        } else {
            JetstreamApiVersion::V2
        }
    }
}

#[derive(Debug)]
struct FailingHttpTransport(String);

impl JetstreamHttpTransport for FailingHttpTransport {
    fn send(
        &self,
        _request: http::Request<Bytes>,
    ) -> petrel::rt::BoxFuture<'_, Result<http::Response<Bytes>, petrel::net::TransportError>> {
        let msg = self.0.clone();
        Box::pin(async move { Err(petrel::net::TransportError::Connect(msg)) })
    }
}

#[derive(Debug, Clone)]
struct LiveOptionsState {
    filter: JetstreamFilter,
    max_message_size_bytes: Option<usize>,
    sessions: Vec<LiveSessionEntry>,
    next_id: u64,
}

#[derive(Debug, Clone)]
struct LiveSessionEntry {
    id: u64,
    session: Arc<dyn FirehoseWebSocketSession>,
}

impl LiveOptionsState {
    fn to_update(&self) -> JetstreamOptionsUpdate {
        JetstreamOptionsUpdate {
            wanted_collections: self.filter.collections.clone(),
            wanted_dids: self.filter.dids.clone(),
            max_message_size_bytes: self.max_message_size_bytes.unwrap_or(0),
        }
    }
}

/// Resilient consumer for Jetstream v2 and legacy v1 WebSocket streams.
#[derive(Debug)]
pub struct JetstreamSubscription {
    pub configuration: JetstreamSubscriptionConfiguration,
    live_options: Arc<Mutex<LiveOptionsState>>,
}

impl JetstreamSubscription {
    /// Creates a subscription from `configuration`.
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    pub fn new(configuration: JetstreamSubscriptionConfiguration) -> Self {
        let state = LiveOptionsState {
            filter: configuration.filter.clone(),
            max_message_size_bytes: configuration.max_message_size_bytes,
            sessions: Vec::new(),
            next_id: 0,
        };
        Self {
            configuration,
            live_options: Arc::new(Mutex::new(state)),
        }
    }

    /// Replaces the subscription's filters live using legacy `options_update`.
    /// Returns [`JetstreamSubscriptionError::OptionsUpdateUnsupported`] on v2 streams.
    pub async fn update_options(
        &self,
        options: JetstreamOptionsUpdate,
    ) -> Result<(), JetstreamSubscriptionError> {
        if self.configuration.resolved_api_version() != JetstreamApiVersion::V1 {
            return Err(JetstreamSubscriptionError::OptionsUpdateUnsupported);
        }
        let encoded = options
            .encode()
            .map_err(|e| FirehoseSubscriptionError::Network(e.to_string()))?;

        let sessions = {
            let mut guard = self.live_options.lock().await;
            guard.filter.collections = options.wanted_collections;
            guard.filter.dids = options.wanted_dids;
            guard.max_message_size_bytes = Some(options.max_message_size_bytes);
            guard.sessions.clone()
        };

        for entry in sessions {
            entry.session.send_text(&encoded).await?;
        }
        Ok(())
    }

    /// Connects and returns a pull-based stream of Jetstream events.
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    pub fn events(
        &self,
    ) -> BoxedEventStream<Result<JetstreamSubscriptionEvent, JetstreamSubscriptionError>> {
        let runner = Arc::new(Mutex::new(SubscriptionRunner::new(
            self.configuration.clone(),
            Arc::clone(&self.live_options),
        )));
        let guard = RunnerHandle { runner };

        Box::pin(stream::unfold(Some(guard), |maybe_handle| async move {
            let handle = maybe_handle?;
            let next = {
                let mut inner = handle.runner.lock().await;
                inner.next().await
            };
            match next {
                Ok(Some(item)) => Some((Ok(item), Some(handle))),
                Ok(None) => None,
                Err(err) => Some((Err(err), None)),
            }
        }))
    }
}

struct RunnerHandle {
    runner: Arc<Mutex<SubscriptionRunner>>,
}

impl Drop for RunnerHandle {
    fn drop(&mut self) {
        if let Some(mut guard) = self.runner.try_lock() {
            if let Some((session, id, live)) = guard.take_session_sync() {
                spawn_close_session(session, id, live);
            }
            return;
        }
        let runner = Arc::clone(&self.runner);
        spawn_terminate_runner(runner);
    }
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
fn spawn_close_session(
    session: Arc<dyn FirehoseWebSocketSession>,
    id: u64,
    live: Arc<Mutex<LiveOptionsState>>,
) {
    if let Ok(handle) = tokio::runtime::Handle::try_current() {
        handle.spawn(async move {
            live.lock().await.sessions.retain(|s| s.id != id);
            session.close().await;
        });
    }
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
fn spawn_terminate_runner(runner: Arc<Mutex<SubscriptionRunner>>) {
    if let Ok(handle) = tokio::runtime::Handle::try_current() {
        handle.spawn(async move {
            runner.lock().await.close_session().await;
        });
    }
}

#[cfg(all(target_arch = "wasm32", target_os = "unknown", feature = "wasm"))]
fn spawn_close_session(
    session: Arc<dyn FirehoseWebSocketSession>,
    id: u64,
    live: Arc<Mutex<LiveOptionsState>>,
) {
    wasm_bindgen_futures::spawn_local(async move {
        live.lock().await.sessions.retain(|s| s.id != id);
        session.close().await;
    });
}

#[cfg(all(target_arch = "wasm32", target_os = "unknown", feature = "wasm"))]
fn spawn_terminate_runner(runner: Arc<Mutex<SubscriptionRunner>>) {
    wasm_bindgen_futures::spawn_local(async move {
        runner.lock().await.close_session().await;
    });
}

#[cfg(not(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", target_os = "unknown", feature = "wasm")
)))]
fn spawn_close_session(
    _session: Arc<dyn FirehoseWebSocketSession>,
    _id: u64,
    _live: Arc<Mutex<LiveOptionsState>>,
) {
}

#[cfg(not(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", target_os = "unknown", feature = "wasm")
)))]
fn spawn_terminate_runner(_runner: Arc<Mutex<SubscriptionRunner>>) {}

type TakenSession = (
    Arc<dyn FirehoseWebSocketSession>,
    u64,
    Arc<Mutex<LiveOptionsState>>,
);

#[allow(clippy::struct_excessive_bools)]
struct SubscriptionRunner {
    configuration: JetstreamSubscriptionConfiguration,
    api_version: JetstreamApiVersion,
    live_options: Arc<Mutex<LiveOptionsState>>,
    initial_cursor: Option<i64>,
    last_seq: Option<i64>,
    has_processed_events: bool,
    replay_cursor: Option<i64>,
    legacy_events_at_last_seq: BTreeSet<String>,
    legacy_events_order: VecDeque<String>,
    pending: VecDeque<(JetstreamSubscriptionEvent, Option<i64>)>,
    unacknowledged_cursor: Option<i64>,
    loaded_initial_cursor: bool,
    finished: bool,
    current_delay: Option<Duration>,
    pending_delay: Option<Duration>,
    active_session: Option<(u64, Arc<dyn FirehoseWebSocketSession>)>,
    connect_url: Option<Url>,
    received_frames_count: usize,
    dictionary_decoder: Option<JetstreamZstdDictionaryDecoder>,
    cached_dict_id: Option<u32>,
    has_retried_unknown_dictionary: bool,
    terminal_error: Option<JetstreamSubscriptionError>,
}

impl SubscriptionRunner {
    fn new(
        configuration: JetstreamSubscriptionConfiguration,
        live_options: Arc<Mutex<LiveOptionsState>>,
    ) -> Self {
        let api_version = configuration.resolved_api_version();
        let initial_cursor = configuration.cursor;
        Self {
            configuration,
            api_version,
            live_options,
            initial_cursor,
            last_seq: None,
            has_processed_events: false,
            replay_cursor: None,
            legacy_events_at_last_seq: BTreeSet::new(),
            legacy_events_order: VecDeque::new(),
            pending: VecDeque::new(),
            unacknowledged_cursor: None,
            loaded_initial_cursor: false,
            finished: false,
            current_delay: None,
            pending_delay: None,
            active_session: None,
            connect_url: None,
            received_frames_count: 0,
            dictionary_decoder: None,
            cached_dict_id: None,
            has_retried_unknown_dictionary: false,
            terminal_error: None,
        }
    }

    fn max_decompressed_frame_bytes(&self) -> usize {
        self.configuration
            .max_message_size_bytes
            .filter(|&n| n > 0)
            .unwrap_or(DEFAULT_MAX_DICT_FRAME_BYTES)
    }

    fn reset_legacy_event_keys(&mut self, key: String) {
        self.legacy_events_at_last_seq.clear();
        self.legacy_events_order.clear();
        self.legacy_events_at_last_seq.insert(key.clone());
        self.legacy_events_order.push_back(key);
    }

    fn insert_legacy_event_key(&mut self, key: String) -> bool {
        if self.legacy_events_at_last_seq.contains(&key) {
            return false;
        }
        if self.legacy_events_order.len() >= MAX_LEGACY_EVENTS_PER_SEQ
            && let Some(oldest) = self.legacy_events_order.pop_front()
        {
            self.legacy_events_at_last_seq.remove(&oldest);
        }
        self.legacy_events_at_last_seq.insert(key.clone());
        self.legacy_events_order.push_back(key);
        true
    }

    fn take_session_sync(&mut self) -> Option<TakenSession> {
        self.finished = true;
        self.pending.clear();
        let (id, session) = self.active_session.take()?;
        Some((session, id, Arc::clone(&self.live_options)))
    }

    async fn close_session(&mut self) {
        if let Some((id, session)) = self.active_session.take() {
            self.live_options
                .lock()
                .await
                .sessions
                .retain(|s| s.id != id);
            session.close().await;
        }
    }

    async fn finish(&mut self) {
        self.finished = true;
        self.pending.clear();
        self.close_session().await;
    }

    async fn acknowledge_cursor(&self, cursor: i64) -> Result<(), JetstreamSubscriptionError> {
        let Some(storage) = &self.configuration.cursor_storage else {
            return Ok(());
        };
        storage.save_cursor(cursor).await.map_err(|e| {
            JetstreamSubscriptionError::CursorStorageFailure {
                operation: CursorStorageOperation::Save,
                message: e.to_string(),
            }
        })
    }

    #[allow(clippy::too_many_lines)]
    async fn next(
        &mut self,
    ) -> Result<Option<JetstreamSubscriptionEvent>, JetstreamSubscriptionError> {
        if self.finished {
            return Ok(None);
        }

        if let Some(cursor) = self.unacknowledged_cursor.take()
            && let Err(err) = self.acknowledge_cursor(cursor).await
        {
            self.finish().await;
            return Err(err);
        }

        if !self.loaded_initial_cursor {
            self.loaded_initial_cursor = true;
            if self.initial_cursor.is_none()
                && let Some(storage) = &self.configuration.cursor_storage
            {
                match storage.load_cursor().await {
                    Ok(Some(stored)) => self.initial_cursor = Some(stored),
                    Ok(None) => {}
                    Err(e) => {
                        self.finish().await;
                        return Err(JetstreamSubscriptionError::CursorStorageFailure {
                            operation: CursorStorageOperation::Load,
                            message: e.to_string(),
                        });
                    }
                }
            }
        }

        loop {
            if let Some((event, cursor)) = self.pending.pop_front() {
                self.unacknowledged_cursor = cursor;
                return Ok(Some(event));
            }
            if let Some(err) = self.terminal_error.take() {
                self.finish().await;
                return Err(err);
            }

            if let Some(delay) = self.pending_delay.take() {
                jetstream_sleep(delay).await;
            }

            let session = match self.active_session.as_ref().map(|(_, s)| Arc::clone(s)) {
                Some(s) => s,
                None => match self.connect().await {
                    Some(s) => s,
                    None => continue,
                },
            };

            let raw_data = match session.receive_message().await {
                Ok(d) => d,
                Err(err) => {
                    self.connection_failed(err).await;
                    continue;
                }
            };

            self.received_frames_count += 1;
            self.has_retried_unknown_dictionary = false;

            if raw_data.is_empty() {
                continue;
            }

            let frame_data = if !raw_data.starts_with(&ZSTD_FRAME_MAGIC) {
                raw_data
            } else if !self.configuration.compression {
                self.report_ignored(
                    None,
                    None,
                    JetstreamIgnoredReason::Undecompressable(
                        "zstd frame received while compression is disabled".to_owned(),
                    ),
                );
                continue;
            } else if let Some(decoder) = &self.dictionary_decoder {
                match decoder.decompress(&raw_data) {
                    Ok(d) => d,
                    Err(e) => {
                        self.report_ignored(
                            None,
                            None,
                            JetstreamIgnoredReason::Undecompressable(e.to_string()),
                        );
                        continue;
                    }
                }
            } else {
                match JetstreamZstd::decompress_with_limit(
                    &raw_data,
                    self.max_decompressed_frame_bytes(),
                ) {
                    Ok(d) => d,
                    Err(e) => {
                        self.report_ignored(
                            None,
                            None,
                            JetstreamIgnoredReason::Undecompressable(e.to_string()),
                        );
                        continue;
                    }
                }
            };

            let wire_frame = match self.api_version {
                JetstreamApiVersion::V1 => JetstreamWire::decode_legacy_frame(&frame_data),
                JetstreamApiVersion::V2 => JetstreamWire::decode_frame(&frame_data),
            };

            let wire_frame = match wire_frame {
                Ok(f) => f,
                Err(err) => {
                    self.report_ignored(
                        None,
                        None,
                        JetstreamIgnoredReason::MalformedFrame(err.to_string()),
                    );
                    continue;
                }
            };

            match wire_frame {
                JetstreamWireFrame::Skipped { r#type, seq } => {
                    self.report_ignored(r#type, seq, JetstreamIgnoredReason::UnknownType);
                }
                JetstreamWireFrame::Undecodable {
                    r#type,
                    seq,
                    reason,
                } => {
                    self.report_ignored(
                        r#type,
                        seq,
                        JetstreamIgnoredReason::UndecodablePayload(reason),
                    );
                }
                JetstreamWireFrame::Error { name, message } => {
                    self.close_session().await;
                    self.pending.push_back((
                        JetstreamSubscriptionEvent::StreamError {
                            name: name.clone(),
                            message: message.clone(),
                        },
                        None,
                    ));
                    let err = EventStreamError::from_wire(&name, message);
                    if matches!(err, EventStreamError::ConsumerTooSlow(_))
                        && self.configuration.reconnects_on_consumer_too_slow
                    {
                        self.schedule_retry();
                    } else {
                        self.terminal_error = Some(JetstreamSubscriptionError::Stream(err));
                    }
                }
                JetstreamWireFrame::Message(event) => {
                    self.current_delay = None;
                    if let Some(seq) = event.seq() {
                        match self.api_version {
                            JetstreamApiVersion::V2 => {
                                if let Some(last) = self.last_seq
                                    && seq <= last
                                {
                                    if Some(seq) == self.replay_cursor {
                                        self.replay_cursor = None;
                                    } else {
                                        self.report_ignored(
                                            Some(event.type_name().to_owned()),
                                            Some(seq),
                                            JetstreamIgnoredReason::DuplicateSequence(seq),
                                        );
                                    }
                                    continue;
                                }
                                self.replay_cursor = None;
                            }
                            JetstreamApiVersion::V1 => {
                                let key = legacy_event_key(&event);
                                if let Some(last) = self.last_seq {
                                    if seq < last {
                                        continue;
                                    }
                                    if seq == last {
                                        if !self.insert_legacy_event_key(key) {
                                            continue;
                                        }
                                    } else {
                                        self.reset_legacy_event_keys(key);
                                    }
                                } else {
                                    self.reset_legacy_event_keys(key);
                                }
                            }
                        }
                        self.last_seq = Some(seq);
                        self.has_processed_events = true;
                    }

                    let filter = self.live_options.lock().await.filter.clone();
                    let event_seq = event.seq();
                    if filter.matches(&event) {
                        self.pending
                            .push_back((JetstreamSubscriptionEvent::Event(event), event_seq));
                    } else if let Some(seq) = event_seq {
                        // Filtered-out events must still persist the cursor on the next delivery
                        // so a restart doesn't replay filtered history.
                        if let Err(err) = self.acknowledge_cursor(seq).await {
                            self.finish().await;
                            return Err(err);
                        }
                    }
                }
            }
        }
    }

    fn report_ignored(
        &mut self,
        r#type: Option<String>,
        sequence: Option<i64>,
        reason: JetstreamIgnoredReason,
    ) {
        let mut cursor = None;
        if self.api_version == JetstreamApiVersion::V2
            && let Some(seq) = sequence
            && seq < TIMESTAMP_CURSOR_FLOOR
            && self.last_seq.is_none_or(|last| seq > last)
        {
            self.last_seq = Some(seq);
            self.has_processed_events = true;
            self.replay_cursor = None;
            cursor = Some(seq);
        }
        self.pending.push_back((
            JetstreamSubscriptionEvent::IgnoredFrame(JetstreamIgnoredFrame {
                r#type,
                sequence,
                reason,
            }),
            cursor,
        ));
    }

    #[allow(clippy::too_many_lines)]
    async fn connect(&mut self) -> Option<Arc<dyn FirehoseWebSocketSession>> {
        if self.configuration.compression && self.dictionary_decoder.is_none() {
            let max_frame_bytes = self.max_decompressed_frame_bytes();
            match self.api_version {
                JetstreamApiVersion::V1 => {
                    let Some(dict) = self.configuration.legacy_zstd_dictionary.as_deref() else {
                        self.terminal_error =
                            Some(JetstreamSubscriptionError::MissingZstdDictionary);
                        return None;
                    };
                    if let Ok(dec) =
                        JetstreamZstdDictionaryDecoder::with_max_size(dict, max_frame_bytes)
                    {
                        self.dictionary_decoder = Some(dec);
                    } else {
                        self.terminal_error =
                            Some(JetstreamSubscriptionError::MissingZstdDictionary);
                        return None;
                    }
                }
                JetstreamApiVersion::V2 => {
                    if let Ok((data, id)) = self.load_dictionary(None).await
                        && let Ok(dec) =
                            JetstreamZstdDictionaryDecoder::with_max_size(&data, max_frame_bytes)
                    {
                        self.dictionary_decoder = Some(dec);
                        self.cached_dict_id = id;
                    } else {
                        self.schedule_retry();
                        return None;
                    }
                }
            }
        }

        let connect_cursor = if self.has_processed_events {
            if let Some(last) = self.last_seq {
                self.replay_cursor = Some(last);
                Some(last)
            } else {
                self.replay_cursor = None;
                self.initial_cursor
            }
        } else {
            self.replay_cursor = None;
            self.initial_cursor
        };

        let (filter, max_bytes, initial_update) = {
            let guard = self.live_options.lock().await;
            (
                guard.filter.clone(),
                guard.max_message_size_bytes,
                guard.to_update(),
            )
        };

        let empty_filter = JetstreamFilter::new();
        let url = match self.api_version {
            JetstreamApiVersion::V2 => build_websocket_url(
                &self.configuration.url,
                &filter,
                connect_cursor,
                if self.configuration.compression {
                    self.cached_dict_id
                } else {
                    None
                },
            ),
            JetstreamApiVersion::V1 => build_legacy_websocket_url(
                &self.configuration.url,
                if self.configuration.require_hello {
                    &empty_filter
                } else {
                    &filter
                },
                connect_cursor,
                self.configuration.compression,
                max_bytes,
                self.configuration.require_hello,
            ),
        };

        self.connect_url = Some(url.clone());
        self.received_frames_count = 0;

        let subprotocols = if self.api_version == JetstreamApiVersion::V2 {
            vec!["xrpc.v1.json".to_owned()]
        } else {
            Vec::new()
        };

        let session: Arc<dyn FirehoseWebSocketSession> = match self
            .configuration
            .session_factory
            .make_session_with_subprotocols(url, subprotocols)
            .await
        {
            Ok(s) => Arc::from(s),
            Err(err) => {
                self.connection_failed(err).await;
                return None;
            }
        };

        let session_id = {
            let mut guard = self.live_options.lock().await;
            guard.next_id += 1;
            let id = guard.next_id;
            guard.sessions.push(LiveSessionEntry {
                id,
                session: Arc::clone(&session),
            });
            id
        };
        self.active_session = Some((session_id, Arc::clone(&session)));

        if self.api_version == JetstreamApiVersion::V1 && self.configuration.require_hello {
            let current_update = self.live_options.lock().await.to_update();
            let _ = &initial_update;
            if let Ok(encoded) = current_update.encode()
                && let Err(err) = session.send_text(&encoded).await
            {
                self.connection_failed(err).await;
                return None;
            }
        }

        Some(session)
    }

    async fn connection_failed(&mut self, err: FirehoseSubscriptionError) {
        self.close_session().await;
        match &err {
            FirehoseSubscriptionError::UpgradeRejected { status, .. }
                if *status == 429 || (*status >= 500 && *status != 501) =>
            {
                self.schedule_retry();
                if let (Some(retry_after), Some(delay)) = (err.retry_after(), self.pending_delay) {
                    self.pending_delay = Some(delay.max(retry_after));
                }
                return;
            }
            FirehoseSubscriptionError::ConnectionClosed
            | FirehoseSubscriptionError::Network(_)
            | FirehoseSubscriptionError::UpgradeRejected { .. } => {}
            other => {
                self.terminal_error = Some(JetstreamSubscriptionError::Transport(other.clone()));
                return;
            }
        }

        if self.received_frames_count == 0
            && let Some(connect_url) = self.connect_url.clone()
            && let Some(rejection) = self.probe_classification(&connect_url, &err).await
        {
            self.terminal_error = Some(rejection);
            return;
        }
        self.schedule_retry();
    }

    async fn probe_classification(
        &mut self,
        connect_url: &Url,
        upgrade_error: &FirehoseSubscriptionError,
    ) -> Option<JetstreamSubscriptionError> {
        let upgrade_status = match upgrade_error {
            FirehoseSubscriptionError::UpgradeRejected { status, .. } => Some(*status),
            _ => None,
        };
        let probe_url = http_probe_url(connect_url);
        if let Ok(req) = http::Request::builder()
            .method(http::Method::GET)
            .uri(probe_url.as_str())
            .body(Bytes::new())
            && let Ok(resp) = self.configuration.http_transport.send(req).await
        {
            let status = resp.status().as_u16();
            if status >= 400 {
                let mut err_name: Option<String> = None;
                let mut err_msg: Option<String> = None;
                if let Ok(JsonValue::Object(obj)) = serde_json::from_slice::<JsonValue>(resp.body())
                {
                    err_name = obj
                        .get("error")
                        .and_then(JsonValue::as_str)
                        .map(str::to_owned);
                    err_msg = obj
                        .get("message")
                        .and_then(JsonValue::as_str)
                        .map(str::to_owned);
                } else if status != 426 {
                    let prefix = &resp.body()[..resp.body().len().min(512)];
                    let text = String::from_utf8_lossy(prefix).trim().to_owned();
                    if !text.is_empty() {
                        err_msg = Some(text);
                    }
                }

                if let Some(name) = err_name.as_deref()
                    && matches!(
                        name,
                        "CursorTooOld" | "UnknownZstdDictionary" | "InvalidRequest"
                    )
                {
                    if name == "UnknownZstdDictionary"
                        && !self.has_retried_unknown_dictionary
                        && self.api_version == JetstreamApiVersion::V2
                    {
                        self.has_retried_unknown_dictionary = true;
                        self.dictionary_decoder = None;
                        self.cached_dict_id = None;
                        return None;
                    }
                    return Some(JetstreamSubscriptionError::ConnectionRejected {
                        status,
                        error: err_name,
                        message: err_msg,
                    });
                }

                if (400..=499).contains(&status) && !matches!(status, 408 | 426 | 429) {
                    return Some(JetstreamSubscriptionError::ConnectionRejected {
                        status,
                        error: err_name,
                        message: err_msg,
                    });
                }
            }
        }

        if let Some(status) = upgrade_status
            && (400..=499).contains(&status)
            && !matches!(status, 408 | 426 | 429)
        {
            return Some(JetstreamSubscriptionError::ConnectionRejected {
                status,
                error: None,
                message: None,
            });
        }
        None
    }

    async fn load_dictionary(&self, id: Option<u32>) -> Result<(Vec<u8>, Option<u32>), ()> {
        let url = dictionary_url(&self.configuration.url, id);
        let req = http::Request::builder()
            .method(http::Method::GET)
            .uri(url.as_str())
            .body(Bytes::new())
            .map_err(|_| ())?;
        let resp = self
            .configuration
            .http_transport
            .send_with_max_bytes(req, Some(DEFAULT_MAX_DICTIONARY_BYTES as u64))
            .await
            .map_err(|_| ())?;
        if resp.status().as_u16() != 200 {
            return Err(());
        }
        let data = resp.body().to_vec();
        let dict_id = JetstreamZstd::dictionary_id(&data).or(id);
        Ok((data, dict_id))
    }

    fn schedule_retry(&mut self) {
        let delay = self.configuration.backoff.next_delay(self.current_delay);
        self.current_delay = Some(delay);
        self.pending_delay = Some(self.configuration.backoff.jittered(delay));
    }
}

fn legacy_event_key(event: &JetstreamEvent) -> String {
    match event {
        JetstreamEvent::Commit(c) => format!(
            "commit {} {} {} {} {}",
            c.did,
            c.rev,
            c.operation.as_str(),
            c.collection,
            c.rkey
        ),
        JetstreamEvent::Identity(i) => format!(
            "identity {} {}",
            i.did,
            i.identity
                .as_ref()
                .map_or_else(|| "-".to_owned(), |id| id.seq.to_string())
        ),
        JetstreamEvent::Account(a) => format!(
            "account {} {}",
            a.did,
            a.account
                .as_ref()
                .map_or_else(|| "-".to_owned(), |ac| ac.seq.to_string())
        ),
        JetstreamEvent::Sync(s) => format!(
            "sync {} {}",
            s.did,
            s.sync
                .as_ref()
                .map_or_else(|| "-".to_owned(), |sy| sy.seq.to_string())
        ),
        JetstreamEvent::Info(info) => format!("info {}", info.name),
    }
}

/// Builds the v2 `/xrpc/network.bsky.jetstream.subscribeEvents` WebSocket URL.
pub fn build_websocket_url(
    base_url: &Url,
    filter: &JetstreamFilter,
    cursor: Option<i64>,
    zstd_dictionary_id: Option<u32>,
) -> Url {
    let mut url = base_url.clone();
    match url.scheme() {
        "https" => {
            let _ = url.set_scheme("wss");
        }
        "http" => {
            let _ = url.set_scheme("ws");
        }
        _ => {}
    }
    let base_path = url.path().trim_matches('/');
    let xrpc = "xrpc/network.bsky.jetstream.subscribeEvents";
    let new_path = if base_path.is_empty() {
        format!("/{xrpc}")
    } else {
        format!("/{base_path}/{xrpc}")
    };
    url.set_path(&new_path);
    url.set_query(None);
    {
        let mut pairs = url.query_pairs_mut();
        for kind in &filter.kinds {
            pairs.append_pair("kinds", kind.as_str());
        }
        for did in &filter.dids {
            pairs.append_pair("dids", did);
        }
        for collection in &filter.collections {
            pairs.append_pair("collections", collection);
        }
        if let Some(c) = cursor {
            pairs.append_pair("cursor", &c.to_string());
        }
        if let Some(id) = zstd_dictionary_id {
            pairs.append_pair("zstdDictionary", &id.to_string());
        }
    }
    if url.query() == Some("") {
        url.set_query(None);
    }
    url
}

/// Builds the legacy `/subscribe` WebSocket URL.
pub fn build_legacy_websocket_url(
    base_url: &Url,
    filter: &JetstreamFilter,
    cursor: Option<i64>,
    compress: bool,
    max_message_size_bytes: Option<usize>,
    require_hello: bool,
) -> Url {
    let mut url = base_url.clone();
    match url.scheme() {
        "https" => {
            let _ = url.set_scheme("wss");
        }
        "http" => {
            let _ = url.set_scheme("ws");
        }
        _ => {}
    }
    let mut segments: Vec<String> = url
        .path_segments()
        .map(|it| it.filter(|s| !s.is_empty()).map(str::to_owned).collect())
        .unwrap_or_default();
    if segments.last().map(String::as_str) != Some("subscribe") {
        segments.push("subscribe".to_owned());
    }
    let new_path = format!("/{}", segments.join("/"));
    url.set_path(&new_path);
    url.set_query(None);
    {
        let mut pairs = url.query_pairs_mut();
        for collection in &filter.collections {
            pairs.append_pair("wantedCollections", collection);
        }
        for did in &filter.dids {
            pairs.append_pair("wantedDids", did);
        }
        if let Some(c) = cursor {
            pairs.append_pair("cursor", &c.to_string());
        }
        if compress {
            pairs.append_pair("compress", "true");
        }
        if let Some(max) = max_message_size_bytes {
            pairs.append_pair("maxMessageSizeBytes", &max.to_string());
        }
        if require_hello {
            pairs.append_pair("requireHello", "true");
        }
    }
    if url.query() == Some("") {
        url.set_query(None);
    }
    url
}

fn http_probe_url(ws_url: &Url) -> Url {
    let mut url = ws_url.clone();
    match url.scheme() {
        "wss" => {
            let _ = url.set_scheme("https");
        }
        "ws" => {
            let _ = url.set_scheme("http");
        }
        _ => {}
    }
    url
}

pub(crate) fn dictionary_url(base_url: &Url, id: Option<u32>) -> Url {
    let mut url = base_url.clone();
    match url.scheme() {
        "wss" => {
            let _ = url.set_scheme("https");
        }
        "ws" => {
            let _ = url.set_scheme("http");
        }
        _ => {}
    }
    let base_path = url.path().trim_matches('/');
    let xrpc = "xrpc/network.bsky.jetstream.getZstdDictionary";
    let new_path = if base_path.is_empty() {
        format!("/{xrpc}")
    } else {
        format!("/{base_path}/{xrpc}")
    };
    url.set_path(&new_path);
    url.set_query(None);
    if let Some(dict_id) = id {
        url.query_pairs_mut()
            .append_pair("id", &dict_id.to_string());
    }
    url
}

#[cfg(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", target_os = "unknown", feature = "wasm")
))]
async fn jetstream_sleep(duration: Duration) {
    if !duration.is_zero() {
        petrel::rt::sleep(duration).await;
    }
}

#[cfg(not(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", target_os = "unknown", feature = "wasm")
)))]
async fn jetstream_sleep(_duration: Duration) {}
