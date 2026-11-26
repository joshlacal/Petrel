//! Pull-based event-stream pump, cursor coordinator, backoff schedule, and bounded channel.

use std::collections::VecDeque;
use std::pin::Pin;
use std::sync::Arc;
use std::time::Duration;

use async_lock::Mutex;
use futures_util::stream::{self, Stream};
use petrel::rt::{BoxFuture, MaybeSend, MaybeSync};
use url::Url;

use crate::limits::FirehoseFrameLimits;
use crate::transport::{
    FirehoseSubscriptionError, FirehoseWebSocketSession, FirehoseWebSocketSessionFactory,
};
use crate::types::RelayVerifierError;

/// Durable storage for the cursor of one event stream.
pub trait FirehoseCursorStorage: MaybeSend + MaybeSync + std::fmt::Debug {
    /// Loads the persisted cursor, or `None` to start at the live tip (`Some(0)` requests replay
    /// from the oldest retained event).
    fn load_cursor(&self) -> BoxFuture<'_, Result<Option<i64>, FirehoseSubscriptionError>>;

    /// Persists the highest acknowledged sequence number.
    fn save_cursor(&self, cursor: i64) -> BoxFuture<'_, Result<(), FirehoseSubscriptionError>>;
}

/// In-memory [`FirehoseCursorStorage`] suitable for tests and ephemeral consumers.
#[derive(Debug, Default)]
pub struct InMemoryFirehoseCursorStorage {
    cursor: Mutex<Option<i64>>,
}

impl InMemoryFirehoseCursorStorage {
    /// Creates an empty cursor store (`None`, starting at the live tip).
    pub fn new() -> Self {
        Self::with_initial_cursor(None)
    }

    /// Creates a store seeded with `initial_cursor` (`Some(0)` requests oldest retained replay).
    pub fn with_initial_cursor(initial_cursor: Option<i64>) -> Self {
        Self {
            cursor: Mutex::new(initial_cursor),
        }
    }
}

impl FirehoseCursorStorage for InMemoryFirehoseCursorStorage {
    fn load_cursor(&self) -> BoxFuture<'_, Result<Option<i64>, FirehoseSubscriptionError>> {
        Box::pin(async move { Ok(*self.cursor.lock().await) })
    }

    fn save_cursor(&self, cursor: i64) -> BoxFuture<'_, Result<(), FirehoseSubscriptionError>> {
        Box::pin(async move {
            *self.cursor.lock().await = Some(cursor);
            Ok(())
        })
    }
}

/// Exponential reconnect backoff with configurable jitter.
#[derive(Debug, Clone, PartialEq)]
pub struct FirehoseBackoffConfiguration {
    /// Initial delay before the first retry (default 500ms).
    pub initial_delay: Duration,
    /// Maximum delay cap (default 30s).
    pub max_delay: Duration,
    /// Exponential multiplier applied per attempt (default 2.0).
    pub multiplier: f64,
    /// Random spread fraction (`0.25` waits between 75% and 125% of computed delay; `0.0` disables).
    pub jitter: f64,
}

impl FirehoseBackoffConfiguration {
    /// Creates a backoff configuration with default timings (500ms -> 30s, 2.0x, 25% jitter).
    pub fn new() -> Self {
        Self {
            initial_delay: Duration::from_millis(500),
            max_delay: Duration::from_secs(30),
            multiplier: 2.0,
            jitter: 0.25,
        }
    }

    /// Deterministic exponential delay before jitter.
    pub fn next_delay(&self, current_delay: Option<Duration>) -> Duration {
        let Some(current) = current_delay else {
            return self.initial_delay;
        };
        let next_secs = current.as_secs_f64() * self.multiplier;
        let capped = next_secs.min(self.max_delay.as_secs_f64()).max(0.0);
        Duration::from_secs_f64(capped)
    }

    /// Applies [`Self::jitter`] to a delay produced by [`Self::next_delay`].
    pub fn jittered(&self, delay: Duration) -> Duration {
        if self.jitter <= 0.0 || delay.is_zero() {
            return delay;
        }
        let spread = self.jitter.min(1.0);
        let unit = random_unit_f64();
        let factor = (1.0 - spread) + unit * (2.0 * spread);
        Duration::from_secs_f64((delay.as_secs_f64() * factor).max(0.0))
    }
}

impl Default for FirehoseBackoffConfiguration {
    fn default() -> Self {
        Self::new()
    }
}

#[allow(clippy::cast_precision_loss)]
fn random_unit_f64() -> f64 {
    let mut buf = [0_u8; 8];
    if getrandom::getrandom(&mut buf).is_ok() {
        let bits = u64::from_le_bytes(buf) >> 11;
        // `bits < 2^53` and `1_u64 << 53` are both exact in IEEE-754 `f64`.
        (bits as f64) / ((1_u64 << 53) as f64)
    } else {
        0.5
    }
}

/// Terminal stream errors signalled by the server via `op: -1` error frames.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum EventStreamError {
    /// Cursor is ahead of the server's latest event.
    #[error("FutureCursor: {}", .0.as_deref().unwrap_or("cursor is in the future"))]
    FutureCursor(Option<String>),
    /// Consumer failed to keep up with the server stream.
    #[error("ConsumerTooSlow: {}", .0.as_deref().unwrap_or("consumer too slow"))]
    ConsumerTooSlow(Option<String>),
    /// Another protocol error frame sent by the server.
    #[error("{name}: {}", message.as_deref().unwrap_or("stream error"))]
    Other {
        name: String,
        message: Option<String>,
    },
}

impl EventStreamError {
    /// Maps a wire `(error, message)` pair to an [`EventStreamError`].
    pub fn from_wire(name: &str, message: Option<String>) -> Self {
        match name {
            "FutureCursor" => Self::FutureCursor(message),
            "ConsumerTooSlow" => Self::ConsumerTooSlow(message),
            _ => Self::Other {
                name: name.to_owned(),
                message,
            },
        }
    }

    /// Returns the wire error identifier.
    pub fn wire_name(&self) -> &str {
        match self {
            Self::FutureCursor(_) => "FutureCursor",
            Self::ConsumerTooSlow(_) => "ConsumerTooSlow",
            Self::Other { name, .. } => name,
        }
    }

    /// Returns any human-readable message attached by the server.
    pub fn wire_message(&self) -> Option<&str> {
        match self {
            Self::FutureCursor(msg)
            | Self::ConsumerTooSlow(msg)
            | Self::Other { message: msg, .. } => msg.as_deref(),
        }
    }
}

/// Unified stream error yielded by [`FirehoseSubscription`](crate::FirehoseSubscription) and
/// [`EventStreamSubscription`](crate::EventStreamSubscription).
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum FirehoseStreamError {
    #[error(transparent)]
    Subscription(#[from] FirehoseSubscriptionError),
    #[error(transparent)]
    Stream(#[from] EventStreamError),
    #[error(transparent)]
    Verifier(#[from] RelayVerifierError),
    #[error("frame decode error: {0}")]
    Frame(String),
}

impl From<crate::limits::FirehoseFrameEncoderError> for FirehoseStreamError {
    fn from(err: crate::limits::FirehoseFrameEncoderError) -> Self {
        match err {
            crate::limits::FirehoseFrameEncoderError::SequenceOutOfRange => {
                Self::Verifier(RelayVerifierError::SequenceOutOfRange)
            }
            other => Self::Frame(other.to_string()),
        }
    }
}

/// Persists the acknowledged cursor for one subscription and enforces monotonicity.
#[derive(Debug)]
pub(crate) struct EventStreamCursorCoordinator {
    storage: Arc<dyn FirehoseCursorStorage>,
    last_persisted_cursor: Mutex<Option<i64>>,
}

impl EventStreamCursorCoordinator {
    pub(crate) fn new(storage: Arc<dyn FirehoseCursorStorage>) -> Self {
        Self {
            storage,
            last_persisted_cursor: Mutex::new(None),
        }
    }

    pub(crate) async fn initialize_cursor(&self, cursor: Option<i64>) {
        let mut guard = self.last_persisted_cursor.lock().await;
        if guard.is_none() {
            *guard = cursor;
        }
    }

    /// Persists `sequence` as the cursor; rejects regressions or duplicates.
    pub(crate) async fn acknowledge(&self, sequence: i64) -> Result<(), FirehoseSubscriptionError> {
        let mut guard = self.last_persisted_cursor.lock().await;
        if let Some(last) = *guard
            && sequence <= last
        {
            return Err(FirehoseSubscriptionError::CursorRegression {
                expected: last + 1,
                received: sequence,
            });
        }
        self.save_locked(&mut guard, sequence).await
    }

    /// Automatic acknowledgement: ignores sequences that are not strictly newer.
    pub(crate) async fn advance_to(&self, sequence: i64) -> Result<(), FirehoseSubscriptionError> {
        let mut guard = self.last_persisted_cursor.lock().await;
        if let Some(last) = *guard
            && sequence <= last
        {
            return Ok(());
        }
        self.save_locked(&mut guard, sequence).await
    }

    async fn save_locked(
        &self,
        guard: &mut Option<i64>,
        sequence: i64,
    ) -> Result<(), FirehoseSubscriptionError> {
        self.storage
            .save_cursor(sequence)
            .await
            .map_err(|_| FirehoseSubscriptionError::StorageFailure)?;
        *guard = Some(sequence);
        Ok(())
    }

    pub(crate) async fn current_cursor(&self) -> Option<i64> {
        *self.last_persisted_cursor.lock().await
    }
}

/// Decoded action produced from a single WebSocket payload.
pub(crate) enum EventStreamStep<Output> {
    Deliver {
        output: Option<Output>,
        sequence: Option<i64>,
    },
    Fail(EventStreamError),
}

impl<Output> EventStreamStep<Output> {
    pub(crate) fn deliver(output: Output, sequence: Option<i64>) -> Self {
        Self::Deliver {
            output: Some(output),
            sequence,
        }
    }

    pub(crate) fn fail(error: EventStreamError) -> Self {
        Self::Fail(error)
    }
}

pub(crate) struct EventStreamPumpConfiguration {
    pub(crate) url: Url,
    pub(crate) cursor_storage: Arc<dyn FirehoseCursorStorage>,
    pub(crate) backoff: FirehoseBackoffConfiguration,
    pub(crate) session_factory: Arc<dyn FirehoseWebSocketSessionFactory>,
    pub(crate) auto_acknowledge: bool,
    pub(crate) reconnects_on_consumer_too_slow: bool,
}

#[cfg(not(target_arch = "wasm32"))]
pub(crate) type DecodeFn<Output> =
    Arc<dyn Fn(&[u8]) -> Result<EventStreamStep<Output>, FirehoseStreamError> + Send + Sync>;
#[cfg(target_arch = "wasm32")]
pub(crate) type DecodeFn<Output> =
    Arc<dyn Fn(&[u8]) -> Result<EventStreamStep<Output>, FirehoseStreamError>>;

#[cfg(not(target_arch = "wasm32"))]
pub(crate) type MakeGapFn<Output> = Arc<dyn Fn(i64, i64) -> Output + Send + Sync>;
#[cfg(target_arch = "wasm32")]
pub(crate) type MakeGapFn<Output> = Arc<dyn Fn(i64, i64) -> Output>;

#[cfg(not(target_arch = "wasm32"))]
pub type BoxedEventStream<T> = Pin<Box<dyn Stream<Item = T> + Send>>;
#[cfg(target_arch = "wasm32")]
pub type BoxedEventStream<T> = Pin<Box<dyn Stream<Item = T>>>;

struct PumpInner<Output> {
    configuration: EventStreamPumpConfiguration,
    coordinator: Arc<EventStreamCursorCoordinator>,
    decode: DecodeFn<Output>,
    make_gap: MakeGapFn<Output>,
    session: Option<Arc<dyn FirehoseWebSocketSession>>,
    pending: VecDeque<(Option<Output>, Option<i64>)>,
    watermark: Option<i64>,
    unacknowledged: Option<i64>,
    awaiting_first_sequence: bool,
    current_delay: Option<Duration>,
    pending_delay: Option<Duration>,
    finished: bool,
}

impl<Output> PumpInner<Output> {
    fn finish_sync(&mut self) -> Option<Arc<dyn FirehoseWebSocketSession>> {
        self.finished = true;
        self.pending.clear();
        self.session.take()
    }

    async fn close_session(&mut self) {
        if let Some(current) = self.session.take() {
            current.close().await;
        }
    }

    async fn finish(&mut self) {
        self.finished = true;
        self.pending.clear();
        self.close_session().await;
    }

    async fn auto_acknowledge(&self, sequence: i64) -> Result<(), FirehoseStreamError> {
        if !self.configuration.auto_acknowledge {
            return Ok(());
        }
        self.coordinator
            .advance_to(sequence)
            .await
            .map_err(FirehoseStreamError::Subscription)
    }

    async fn connect_if_needed(
        &mut self,
    ) -> Result<Arc<dyn FirehoseWebSocketSession>, FirehoseSubscriptionError> {
        if let Some(session) = &self.session {
            return Ok(Arc::clone(session));
        }
        let persisted = self
            .configuration
            .cursor_storage
            .load_cursor()
            .await
            .map_err(|_| FirehoseSubscriptionError::StorageFailure)?;
        self.coordinator.initialize_cursor(persisted).await;

        let resume = persisted.or(self.watermark);
        self.watermark = resume;
        self.awaiting_first_sequence = true;

        let url = url_with_cursor(&self.configuration.url, resume);
        let opened: Arc<dyn FirehoseWebSocketSession> =
            Arc::from(self.configuration.session_factory.make_session(url).await?);
        self.session = Some(Arc::clone(&opened));
        Ok(opened)
    }

    async fn handle(&mut self, data: &[u8]) -> Result<(), FirehoseStreamError> {
        let step = (self.decode)(data)?;
        match step {
            EventStreamStep::Fail(err) => {
                self.close_session().await;
                if matches!(err, EventStreamError::ConsumerTooSlow(_))
                    && self.configuration.reconnects_on_consumer_too_slow
                {
                    self.pending_delay = Some(self.next_backoff());
                    return Ok(());
                }
                Err(FirehoseStreamError::Stream(err))
            }
            EventStreamStep::Deliver { output, sequence } => {
                if let Some(seq) = sequence {
                    FirehoseFrameLimits::validate_sequence(seq)?;
                    if let Some(last) = self.watermark {
                        if seq == last && self.awaiting_first_sequence {
                            self.awaiting_first_sequence = false;
                            return Ok(());
                        }
                        if seq == last {
                            return Err(FirehoseStreamError::Subscription(
                                FirehoseSubscriptionError::DuplicateSequence(seq),
                            ));
                        }
                        if seq < last {
                            return Err(FirehoseStreamError::Subscription(
                                FirehoseSubscriptionError::CursorRegression {
                                    expected: last + 1,
                                    received: seq,
                                },
                            ));
                        }
                        if seq > last + 1 && last != 0 {
                            self.pending
                                .push_back((Some((self.make_gap)(last + 1, seq)), None));
                        }
                    }
                    self.awaiting_first_sequence = false;
                    self.watermark = Some(seq);
                }
                self.current_delay = None;
                if output.is_some() || sequence.is_some() {
                    self.pending.push_back((output, sequence));
                }
                Ok(())
            }
        }
    }

    fn next_backoff(&mut self) -> Duration {
        let delay = self.configuration.backoff.next_delay(self.current_delay);
        self.current_delay = Some(delay);
        self.configuration.backoff.jittered(delay)
    }

    fn retry_delay(&mut self, err: &FirehoseSubscriptionError) -> Option<Duration> {
        match err {
            FirehoseSubscriptionError::ConnectionClosed | FirehoseSubscriptionError::Network(_) => {
                Some(self.next_backoff())
            }
            FirehoseSubscriptionError::UpgradeRejected { status, .. } => {
                if *status == 429 || (*status >= 500 && *status != 501) {
                    let backoff = self.next_backoff();
                    Some(match err.retry_after() {
                        Some(retry_after) => backoff.max(retry_after),
                        None => backoff,
                    })
                } else {
                    None
                }
            }
            _ => None,
        }
    }

    async fn next(&mut self) -> Result<Option<Output>, FirehoseStreamError> {
        if self.finished {
            return Ok(None);
        }

        if let Some(seq) = self.unacknowledged.take()
            && let Err(e) = self.auto_acknowledge(seq).await
        {
            self.finish().await;
            return Err(e);
        }

        loop {
            while let Some((maybe_out, seq)) = self.pending.pop_front() {
                let Some(output) = maybe_out else {
                    if let Some(s) = seq
                        && let Err(e) = self.auto_acknowledge(s).await
                    {
                        self.finish().await;
                        return Err(e);
                    }
                    continue;
                };
                self.unacknowledged = seq;
                return Ok(Some(output));
            }

            if let Some(delay) = self.pending_delay.take() {
                petrel_sleep(delay).await;
            }

            let session = match self.connect_if_needed().await {
                Ok(s) => s,
                Err(err) => {
                    self.close_session().await;
                    if let Some(delay) = self.retry_delay(&err) {
                        self.pending_delay = Some(delay);
                        continue;
                    }
                    self.finish().await;
                    return Err(FirehoseStreamError::Subscription(err));
                }
            };

            let data = match session.receive_message().await {
                Ok(d) => d,
                Err(err) => {
                    self.close_session().await;
                    if let Some(delay) = self.retry_delay(&err) {
                        self.pending_delay = Some(delay);
                        continue;
                    }
                    self.finish().await;
                    return Err(FirehoseStreamError::Subscription(err));
                }
            };

            if let Err(err) = self.handle(&data).await {
                self.finish().await;
                return Err(err);
            }
        }
    }
}

struct PumpHandle<Output: MaybeSend + MaybeSync + 'static> {
    inner: Arc<Mutex<PumpInner<Output>>>,
}

impl<Output: MaybeSend + MaybeSync + 'static> Drop for PumpHandle<Output> {
    fn drop(&mut self) {
        // Best-effort synchronous close signal if lock is uncontended, plus async cleanup.
        if let Some(mut guard) = self.inner.try_lock() {
            if guard.finished {
                return;
            }
            if let Some(session) = guard.finish_sync() {
                spawn_close(session);
            }
            return;
        }
        let inner = Arc::clone(&self.inner);
        spawn_terminate(inner);
    }
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
fn spawn_close(session: Arc<dyn FirehoseWebSocketSession>) {
    if let Ok(handle) = tokio::runtime::Handle::try_current() {
        handle.spawn(async move {
            session.close().await;
        });
    }
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
fn spawn_terminate<Output: MaybeSend + MaybeSync + 'static>(inner: Arc<Mutex<PumpInner<Output>>>) {
    if let Ok(handle) = tokio::runtime::Handle::try_current() {
        handle.spawn(async move {
            let mut guard = inner.lock().await;
            guard.finish().await;
        });
    }
}

#[cfg(all(target_arch = "wasm32", target_os = "unknown", feature = "wasm"))]
fn spawn_close(session: Arc<dyn FirehoseWebSocketSession>) {
    wasm_bindgen_futures::spawn_local(async move {
        session.close().await;
    });
}

#[cfg(all(target_arch = "wasm32", target_os = "unknown", feature = "wasm"))]
fn spawn_terminate<Output: MaybeSend + MaybeSync + 'static>(inner: Arc<Mutex<PumpInner<Output>>>) {
    wasm_bindgen_futures::spawn_local(async move {
        let mut guard = inner.lock().await;
        guard.finish().await;
    });
}

#[cfg(not(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", target_os = "unknown", feature = "wasm")
)))]
fn spawn_close(_session: Arc<dyn FirehoseWebSocketSession>) {}

#[cfg(not(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", target_os = "unknown", feature = "wasm")
)))]
fn spawn_terminate<Output: MaybeSend + MaybeSync + 'static>(_inner: Arc<Mutex<PumpInner<Output>>>) {
}

#[cfg(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", target_os = "unknown", feature = "wasm")
))]
async fn petrel_sleep(duration: Duration) {
    if !duration.is_zero() {
        petrel::rt::sleep(duration).await;
    }
}

#[cfg(not(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", target_os = "unknown", feature = "wasm")
)))]
async fn petrel_sleep(_duration: Duration) {}

pub(crate) fn make_pump_stream<Output>(
    configuration: EventStreamPumpConfiguration,
    coordinator: Arc<EventStreamCursorCoordinator>,
    decode: DecodeFn<Output>,
    make_gap: MakeGapFn<Output>,
) -> BoxedEventStream<Result<Output, FirehoseStreamError>>
where
    Output: MaybeSend + MaybeSync + 'static,
{
    let inner = Arc::new(Mutex::new(PumpInner {
        configuration,
        coordinator,
        decode,
        make_gap,
        session: None,
        pending: VecDeque::new(),
        watermark: None,
        unacknowledged: None,
        awaiting_first_sequence: true,
        current_delay: None,
        pending_delay: None,
        finished: false,
    }));

    let handle = PumpHandle { inner };

    Box::pin(stream::unfold(Some(handle), |maybe_handle| async move {
        let handle = maybe_handle?;
        let next = {
            let mut guard = handle.inner.lock().await;
            guard.next().await
        };
        match next {
            Ok(Some(item)) => Some((Ok(item), Some(handle))),
            Ok(None) => None,
            Err(err) => Some((Err(err), None)),
        }
    }))
}

/// Appends or replaces the `cursor` query parameter on `base_url`.
pub(crate) fn url_with_cursor(base_url: &Url, cursor: Option<i64>) -> Url {
    let Some(cursor) = cursor else {
        return base_url.clone();
    };
    let mut url = base_url.clone();
    let existing: Vec<(String, String)> = url
        .query_pairs()
        .filter(|(k, _)| k != "cursor")
        .map(|(k, v)| (k.into_owned(), v.into_owned()))
        .collect();
    {
        let mut pairs = url.query_pairs_mut();
        pairs.clear();
        for (k, v) in existing {
            pairs.append_pair(&k, &v);
        }
        pairs.append_pair("cursor", &cursor.to_string());
    }
    url
}

/// Bounded asynchronous sender/receiver channel (`tokio::sync::mpsc` on native,
/// `futures_channel::mpsc` on wasm32) providing explicit backpressure.
pub(crate) mod channel {
    #[cfg(not(target_arch = "wasm32"))]
    pub use native_chan::{BoundedReceiver, BoundedSender, bounded};
    #[cfg(target_arch = "wasm32")]
    pub use wasm_chan::{BoundedReceiver, BoundedSender, bounded};

    #[cfg(not(target_arch = "wasm32"))]
    mod native_chan {
        use tokio::sync::mpsc;

        #[derive(Debug, Clone)]
        pub struct BoundedSender<T>(mpsc::Sender<T>);

        #[derive(Debug)]
        pub struct BoundedReceiver<T>(mpsc::Receiver<T>);

        pub fn bounded<T>(capacity: usize) -> (BoundedSender<T>, BoundedReceiver<T>) {
            let (tx, rx) = mpsc::channel(capacity.max(1));
            (BoundedSender(tx), BoundedReceiver(rx))
        }

        impl<T> BoundedSender<T> {
            pub async fn send(&mut self, value: T) -> Result<(), T> {
                self.0.send(value).await.map_err(|e| e.0)
            }
        }

        impl<T> BoundedReceiver<T> {
            pub async fn recv(&mut self) -> Option<T> {
                self.0.recv().await
            }
        }
    }

    #[cfg(target_arch = "wasm32")]
    mod wasm_chan {
        use std::task::Poll;

        use futures_channel::mpsc;
        use futures_util::StreamExt;

        #[derive(Debug, Clone)]
        pub struct BoundedSender<T>(mpsc::Sender<T>);

        #[derive(Debug)]
        pub struct BoundedReceiver<T>(mpsc::Receiver<T>);

        pub fn bounded<T>(capacity: usize) -> (BoundedSender<T>, BoundedReceiver<T>) {
            // `futures_channel::mpsc::channel(n)` gives `n + senders` buffer; pass `capacity.saturating_sub(1)`.
            let (tx, rx) = mpsc::channel(capacity.saturating_sub(1));
            (BoundedSender(tx), BoundedReceiver(rx))
        }

        impl<T> BoundedSender<T> {
            pub async fn send(&mut self, value: T) -> Result<(), T> {
                let mut value = Some(value);
                let ready = futures_util::future::poll_fn(|cx| match self.0.poll_ready(cx) {
                    Poll::Ready(Ok(())) => Poll::Ready(Ok(())),
                    Poll::Ready(Err(_)) => Poll::Ready(Err(())),
                    Poll::Pending => Poll::Pending,
                })
                .await;
                if ready.is_err() {
                    return match value.take() {
                        Some(v) => Err(v),
                        None => unreachable!(),
                    };
                }
                let Some(item) = value.take() else {
                    unreachable!();
                };
                self.0
                    .try_send(item)
                    .map_err(futures_channel::mpsc::TrySendError::into_inner)
            }
        }

        impl<T> BoundedReceiver<T> {
            pub async fn recv(&mut self) -> Option<T> {
                self.0.next().await
            }
        }
    }
}

/// Bounded asynchronous stream channel backed by `tokio::sync::mpsc` on native and
/// `futures_channel::mpsc` on `wasm32`.
pub use channel::{
    BoundedReceiver as FirehoseBoundedReceiver, BoundedSender as FirehoseBoundedSender,
    bounded as bounded_firehose_channel,
};

#[cfg(test)]
mod tests {
    use super::*;
    use crate::transport::{FirehoseWebSocketOptions, default_websocket_factory};

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    async fn consumer_too_slow_does_not_reset_exponential_backoff_until_valid_frame() {
        let storage: Arc<dyn FirehoseCursorStorage> =
            Arc::new(InMemoryFirehoseCursorStorage::new());
        let mut backoff = FirehoseBackoffConfiguration::new();
        backoff.initial_delay = Duration::from_millis(10);
        backoff.max_delay = Duration::from_millis(100);
        backoff.multiplier = 2.0;
        backoff.jitter = 0.0;

        let config = EventStreamPumpConfiguration {
            url: Url::parse("wss://bsky.network/xrpc/com.atproto.sync.subscribeRepos").unwrap(),
            cursor_storage: Arc::clone(&storage),
            backoff,
            session_factory: default_websocket_factory(FirehoseWebSocketOptions::new()),
            auto_acknowledge: true,
            reconnects_on_consumer_too_slow: true,
        };
        let decode: DecodeFn<()> = Arc::new(|raw| {
            if raw == b"slow" {
                Ok(EventStreamStep::fail(EventStreamError::ConsumerTooSlow(
                    None,
                )))
            } else {
                Ok(EventStreamStep::deliver((), Some(1)))
            }
        });
        let make_gap: MakeGapFn<()> = Arc::new(|_, _| ());

        let mut pump = PumpInner {
            configuration: config,
            coordinator: Arc::new(EventStreamCursorCoordinator::new(storage)),
            decode,
            make_gap,
            session: None,
            pending: VecDeque::new(),
            watermark: None,
            unacknowledged: None,
            awaiting_first_sequence: false,
            current_delay: None,
            pending_delay: None,
            finished: false,
        };

        pump.handle(b"slow").await.unwrap();
        assert_eq!(pump.current_delay, Some(Duration::from_millis(10)));
        pump.handle(b"slow").await.unwrap();
        assert_eq!(pump.current_delay, Some(Duration::from_millis(20)));

        pump.handle(b"ok").await.unwrap();
        assert_eq!(pump.current_delay, None);
    }
}
