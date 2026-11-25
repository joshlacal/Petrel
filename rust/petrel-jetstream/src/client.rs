//! High-level Jetstream v2 orchestrating client (`Live`, `SnapshotThenLive`, `SnapshotOnly`).

use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::Duration;

use futures_util::StreamExt;
use futures_util::stream::FuturesUnordered;
use petrel_firehose::{
    BoxedEventStream, FirehoseBackoffConfiguration, FirehoseCursorStorage,
    FirehoseWebSocketOptions, FirehoseWebSocketSessionFactory, default_websocket_factory,
};
use url::Url;

use crate::channel::{JetstreamBatch, JetstreamBatchSender, jetstream_batch_channel};
use crate::event::{JetstreamEvent, JetstreamFilter};
use crate::http::{
    DEFAULT_MAX_SEGMENT_BYTES, JetstreamHttpError, JetstreamHttpTransport, JetstreamXrpcClient,
    JetstreamXrpcError, SnapshotPlan, SnapshotPlanRequest, default_http_transport,
};

const MAX_PLAN_SEGMENTS: usize = 16_384;
const MAX_PLAN_WORK_UNITS: usize = 16_384;
const MAX_PLAN_TOTAL_BLOCKS: usize = 262_144;
const MAX_BLOCKS_PER_CHUNK: usize = 32;
use crate::segment_block::{
    SegmentBlockDecoder, SegmentBlockError, SegmentBytesReader, SegmentEvent,
};
use crate::subscription::{
    CursorStorageOperation, JetstreamSubscription, JetstreamSubscriptionConfiguration,
    JetstreamSubscriptionError, JetstreamSubscriptionEvent,
};

/// Operating mode for [`JetstreamClient`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum JetstreamMode {
    /// Stream live events directly over WebSocket, skipping archive backfill.
    Live { cursor: Option<i64> },
    /// Backfill matching archive segments/blocks up to `sealed_tip_seq`, then cut over to live.
    SnapshotThenLive { after_seq: i64 },
    /// Backfill archive segments/blocks within `(after_seq, before_seq]` and finish.
    SnapshotOnly {
        after_seq: i64,
        before_seq: Option<i64>,
    },
}

impl Default for JetstreamMode {
    fn default() -> Self {
        Self::SnapshotThenLive { after_seq: 0 }
    }
}

/// Errors returned by [`JetstreamClient`].
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum JetstreamClientError {
    #[error(transparent)]
    Http(#[from] JetstreamHttpError),
    #[error(transparent)]
    Segment(#[from] SegmentBlockError),
    #[error(transparent)]
    Subscription(#[from] JetstreamSubscriptionError),
}

/// Configuration for [`JetstreamClient`].
#[derive(Debug, Clone)]
pub struct JetstreamClientConfiguration {
    pub host: Url,
    pub mode: JetstreamMode,
    pub filter: JetstreamFilter,
    pub batch_size: usize,
    pub download_concurrency: usize,
    pub max_segment_bytes: u64,
    pub compression: bool,
    pub api_key: Option<String>,
    pub cursor_storage: Option<Arc<dyn FirehoseCursorStorage>>,
    pub transport: Arc<dyn JetstreamHttpTransport>,
    pub session_factory: Arc<dyn FirehoseWebSocketSessionFactory>,
    pub backoff: FirehoseBackoffConfiguration,
}

impl JetstreamClientConfiguration {
    /// Creates client configuration with default live/backfill settings.
    pub fn new(host: Url) -> Self {
        let transport = default_http_transport()
            .unwrap_or_else(|e| Arc::new(FailingFallbackTransport(e.to_string())));
        Self {
            host,
            mode: JetstreamMode::default(),
            filter: JetstreamFilter::new(),
            batch_size: 64,
            download_concurrency: 4,
            max_segment_bytes: DEFAULT_MAX_SEGMENT_BYTES,
            compression: false,
            api_key: None,
            cursor_storage: None,
            transport,
            session_factory: default_websocket_factory(FirehoseWebSocketOptions::jetstream()),
            backoff: FirehoseBackoffConfiguration::new(),
        }
    }
}

#[derive(Debug)]
struct FailingFallbackTransport(String);

impl JetstreamHttpTransport for FailingFallbackTransport {
    fn send(
        &self,
        _request: http::Request<bytes::Bytes>,
    ) -> petrel::rt::BoxFuture<'_, Result<http::Response<bytes::Bytes>, petrel::net::TransportError>>
    {
        let msg = self.0.clone();
        Box::pin(async move { Err(petrel::net::TransportError::Connect(msg)) })
    }
}

/// High-level Jetstream v2 orchestrating client handling backfill, decoding, and live cutover.
#[derive(Debug)]
pub struct JetstreamClient {
    pub configuration: JetstreamClientConfiguration,
}

impl JetstreamClient {
    /// Creates a client from `configuration`.
    pub fn new(configuration: JetstreamClientConfiguration) -> Self {
        Self { configuration }
    }

    /// Streams ordered [`JetstreamBatch`] values with bounded backpressure (`capacity = 4`).
    pub fn events(&self) -> BoxedEventStream<Result<JetstreamBatch, JetstreamClientError>> {
        let (mut sender, stream) =
            jetstream_batch_channel(4, self.configuration.cursor_storage.clone());
        let config = self.configuration.clone();

        spawn_client_runner(async move {
            let cancel = sender.cancel_signal();
            let mut xrpc = JetstreamXrpcClient::new(
                config.host.clone(),
                Arc::clone(&config.transport),
                config.api_key.clone(),
            );
            xrpc.max_segment_bytes = config.max_segment_bytes;
            let runner = ClientRunner { config, xrpc };
            let err_opt = {
                let run_fut = std::pin::pin!(runner.run(&mut sender));
                let cancel_fut = std::pin::pin!(cancel.wait());
                match futures_util::future::select(run_fut, cancel_fut).await {
                    futures_util::future::Either::Left((Err(err), _)) => Some(err),
                    _ => None,
                }
            };
            if let Some(err) = err_opt {
                sender.finish_err(err).await;
            }
        });

        stream
    }
}

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
fn spawn_client_runner<F>(fut: F)
where
    F: std::future::Future<Output = ()> + Send + 'static,
{
    if let Ok(handle) = tokio::runtime::Handle::try_current() {
        handle.spawn(fut);
    }
}

#[cfg(all(target_arch = "wasm32", target_os = "unknown", feature = "wasm"))]
fn spawn_client_runner<F>(fut: F)
where
    F: std::future::Future<Output = ()> + 'static,
{
    wasm_bindgen_futures::spawn_local(fut);
}

#[cfg(not(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", target_os = "unknown", feature = "wasm")
)))]
fn spawn_client_runner<F>(_fut: F) {}

enum WorkUnit {
    Segment {
        name: String,
    },
    BlockRange {
        segment: String,
        first: usize,
        last: usize,
    },
}

enum DownloadedUnit {
    SegmentBytes(Vec<u8>),
    BlockFrames(Vec<Vec<u8>>),
}

struct CompactedSegmentError;

struct BackfillState {
    last_processed: i64,
    current_batch: Vec<JetstreamEvent>,
}

struct LiveTailFailure {
    last_cursor: i64,
    underlying: JetstreamSubscriptionError,
}

struct ClientRunner {
    config: JetstreamClientConfiguration,
    xrpc: JetstreamXrpcClient,
}

impl ClientRunner {
    async fn run(
        &self,
        sender: &mut JetstreamBatchSender<JetstreamClientError>,
    ) -> Result<(), JetstreamClientError> {
        match self.config.mode {
            JetstreamMode::Live { cursor } => self.run_live_only(cursor, sender).await,
            JetstreamMode::SnapshotOnly {
                after_seq,
                before_seq,
            } => {
                let _ = self
                    .run_snapshot_backfill(after_seq, before_seq, sender)
                    .await?;
                Ok(())
            }
            JetstreamMode::SnapshotThenLive { after_seq } => {
                let mut current_after = after_seq;
                let mut consecutive_zero_progress = 0usize;

                while !sender.is_cancelled() {
                    let (sealed_tip, last_processed) = self
                        .run_snapshot_backfill(current_after, None, sender)
                        .await?;
                    let cutover = sealed_tip.max(last_processed);

                    match self.run_live_tail(cutover, sender).await {
                        Ok(()) => break,
                        Err(failure) => {
                            let is_cursor_too_old = matches!(
                                &failure.underlying,
                                JetstreamSubscriptionError::ConnectionRejected { status, error, .. }
                                if error.as_deref() == Some("CursorTooOld")
                                    || (*status == 400 && error.is_none())
                            );
                            if !is_cursor_too_old {
                                return Err(JetstreamClientError::Subscription(failure.underlying));
                            }
                            let resume_seq = failure.last_cursor.max(last_processed);
                            if resume_seq == current_after {
                                consecutive_zero_progress += 1;
                            } else {
                                consecutive_zero_progress = 0;
                            }
                            if consecutive_zero_progress >= 2 {
                                return Err(JetstreamClientError::Subscription(failure.underlying));
                            }
                            current_after = resume_seq;
                        }
                    }
                }
                Ok(())
            }
        }
    }

    async fn run_live_only(
        &self,
        mut initial_cursor: Option<i64>,
        sender: &mut JetstreamBatchSender<JetstreamClientError>,
    ) -> Result<(), JetstreamClientError> {
        if initial_cursor.is_none()
            && let Some(storage) = &self.config.cursor_storage
        {
            initial_cursor = storage.load_cursor().await.map_err(|e| {
                JetstreamClientError::Subscription(
                    JetstreamSubscriptionError::CursorStorageFailure {
                        operation: CursorStorageOperation::Load,
                        message: e.to_string(),
                    },
                )
            })?;
        }
        let mut sub_cfg = JetstreamSubscriptionConfiguration::new(self.config.host.clone());
        sub_cfg.filter = self.config.filter.clone();
        sub_cfg.cursor = initial_cursor;
        sub_cfg.compression = self.config.compression;
        sub_cfg.cursor_storage = None;
        sub_cfg.backoff = self.config.backoff.clone();
        sub_cfg.session_factory = Arc::clone(&self.config.session_factory);
        sub_cfg.http_transport = Arc::clone(&self.config.transport);

        let sub = JetstreamSubscription::new(sub_cfg);
        let mut stream = sub.events();
        let mut last_cursor = initial_cursor.unwrap_or(0);

        while let Some(item) = stream.next().await {
            if sender.is_cancelled() {
                break;
            }
            match item? {
                JetstreamSubscriptionEvent::Event(ev) => {
                    if let Some(seq) = ev.seq() {
                        last_cursor = seq;
                    }
                    if !sender
                        .yield_batch(JetstreamBatch::new(vec![ev], last_cursor))
                        .await
                    {
                        break;
                    }
                }
                JetstreamSubscriptionEvent::StreamError { .. }
                | JetstreamSubscriptionEvent::IgnoredFrame(_) => {}
            }
        }
        Ok(())
    }

    async fn run_live_tail(
        &self,
        cursor: i64,
        sender: &mut JetstreamBatchSender<JetstreamClientError>,
    ) -> Result<(), LiveTailFailure> {
        let mut sub_cfg = JetstreamSubscriptionConfiguration::new(self.config.host.clone());
        sub_cfg.filter = self.config.filter.clone();
        sub_cfg.cursor = Some(cursor);
        sub_cfg.compression = self.config.compression;
        sub_cfg.cursor_storage = None;
        sub_cfg.backoff = self.config.backoff.clone();
        sub_cfg.session_factory = Arc::clone(&self.config.session_factory);
        sub_cfg.http_transport = Arc::clone(&self.config.transport);

        let sub = JetstreamSubscription::new(sub_cfg);
        let mut stream = sub.events();
        let mut last_cursor = cursor;

        while let Some(item) = stream.next().await {
            if sender.is_cancelled() {
                break;
            }
            match item {
                Ok(JetstreamSubscriptionEvent::Event(ev)) => {
                    if let Some(seq) = ev.seq() {
                        if seq <= cursor {
                            continue;
                        }
                        last_cursor = seq;
                    }
                    if !sender
                        .yield_batch(JetstreamBatch::new(vec![ev], last_cursor))
                        .await
                    {
                        break;
                    }
                }
                Ok(
                    JetstreamSubscriptionEvent::StreamError { .. }
                    | JetstreamSubscriptionEvent::IgnoredFrame(_),
                ) => {}
                Err(err) => {
                    return Err(LiveTailFailure {
                        last_cursor,
                        underlying: err,
                    });
                }
            }
        }
        Ok(())
    }

    async fn run_snapshot_backfill(
        &self,
        initial_after_seq: i64,
        target_before_seq: Option<i64>,
        sender: &mut JetstreamBatchSender<JetstreamClientError>,
    ) -> Result<(i64, i64), JetstreamClientError> {
        let mut current_after = initial_after_seq;
        let mut pinned_s: Option<i64> = None;
        let mut state = BackfillState {
            last_processed: initial_after_seq,
            current_batch: Vec::new(),
        };
        let mut replan_attempts = 0usize;

        while !sender.is_cancelled() {
            let req = SnapshotPlanRequest::from_filter(
                &self.config.filter,
                (current_after > 0).then_some(current_after),
                pinned_s.or(target_before_seq),
            );
            let plan = self.xrpc.plan_snapshot(&req).await?;

            if pinned_s.is_none() {
                pinned_s = Some(match target_before_seq {
                    Some(target) => plan.sealed_tip_seq.min(target),
                    None => plan.sealed_tip_seq,
                });
            }
            let Some(effective_limit) = pinned_s else {
                break;
            };
            if current_after >= effective_limit {
                break;
            }

            let work_units = plan_to_work_units(&plan)?;

            match self
                .process_work_units(
                    &work_units,
                    initial_after_seq,
                    effective_limit,
                    &mut state,
                    sender,
                )
                .await
            {
                Ok(()) => {}
                Err(WorkUnitError::Compacted) => {
                    replan_attempts += 1;
                    if replan_attempts > 1 && current_after == state.last_processed {
                        return Err(JetstreamClientError::Http(JetstreamHttpError::Xrpc(
                            JetstreamXrpcError {
                                status: 404,
                                error: Some("SegmentNotFound".to_owned()),
                                message: Some(
                                    "Segment compacted away and re-planning made no progress"
                                        .to_owned(),
                                ),
                            },
                        )));
                    }
                    current_after = state.last_processed;
                    continue;
                }
                Err(WorkUnitError::Client(err)) => return Err(err),
            }

            if plan.planned_through_seq >= effective_limit {
                break;
            }
            if plan.planned_through_seq <= current_after {
                return Err(JetstreamClientError::Http(JetstreamHttpError::Decode(
                    format!(
                        "snapshot plan made no progress: planned_through_seq {} <= current_after {}",
                        plan.planned_through_seq, current_after
                    ),
                )));
            }
            current_after = plan.planned_through_seq;
        }

        self.flush_batch(&mut state, sender).await;
        Ok((pinned_s.unwrap_or(initial_after_seq), state.last_processed))
    }

    async fn flush_batch(
        &self,
        state: &mut BackfillState,
        sender: &mut JetstreamBatchSender<JetstreamClientError>,
    ) {
        if state.current_batch.is_empty() {
            return;
        }
        let events = std::mem::take(&mut state.current_batch);
        let _ = sender
            .yield_batch(JetstreamBatch::new(events, state.last_processed))
            .await;
    }

    async fn process_work_units(
        &self,
        units: &[WorkUnit],
        initial_after_seq: i64,
        effective_limit: i64,
        state: &mut BackfillState,
        sender: &mut JetstreamBatchSender<JetstreamClientError>,
    ) -> Result<(), WorkUnitError> {
        if units.is_empty() {
            return Ok(());
        }
        let concurrency = self.config.download_concurrency.max(1);
        let max_window = concurrency.saturating_mul(2);
        let mut next_submit = 0usize;
        let mut next_process = 0usize;
        let mut buffer: BTreeMap<usize, DownloadedUnit> = BTreeMap::new();
        let mut inflight = FuturesUnordered::new();

        while next_submit < units.len()
            && inflight.len() < concurrency
            && (next_submit - next_process) < max_window
        {
            let idx = next_submit;
            inflight.push(self.download_indexed(idx, &units[idx]));
            next_submit += 1;
        }

        while let Some((idx, res)) = inflight.next().await {
            if sender.is_cancelled() {
                return Ok(());
            }
            let downloaded = res?;
            buffer.insert(idx, downloaded);

            while let Some(unit) = buffer.remove(&next_process) {
                self.process_downloaded_unit(
                    &unit,
                    initial_after_seq,
                    effective_limit,
                    state,
                    sender,
                )
                .await
                .map_err(WorkUnitError::Client)?;
                self.flush_batch(state, sender).await;
                next_process += 1;
            }

            while next_submit < units.len()
                && inflight.len() < concurrency
                && (next_submit - next_process) < max_window
            {
                let s_idx = next_submit;
                inflight.push(self.download_indexed(s_idx, &units[s_idx]));
                next_submit += 1;
            }
        }
        Ok(())
    }

    async fn download_indexed(
        &self,
        index: usize,
        unit: &WorkUnit,
    ) -> (usize, Result<DownloadedUnit, WorkUnitError>) {
        let res = self.download_unit_with_retry(unit).await;
        (index, res)
    }

    async fn download_unit_with_retry(
        &self,
        unit: &WorkUnit,
    ) -> Result<DownloadedUnit, WorkUnitError> {
        let mut attempts = 0usize;
        let mut current_delay: Option<Duration> = None;

        loop {
            attempts += 1;
            let res: Result<DownloadedUnit, JetstreamHttpError> = match unit {
                WorkUnit::Segment { name } => self
                    .xrpc
                    .get_segment(name)
                    .await
                    .map(DownloadedUnit::SegmentBytes),
                WorkUnit::BlockRange {
                    segment,
                    first,
                    last,
                } => {
                    if *last < *first {
                        Err(JetstreamHttpError::Decode(format!(
                            "invalid block range: first={first} > last={last}"
                        )))
                    } else {
                        let count = last - *first + 1;
                        let mut frames = Vec::with_capacity(count.min(MAX_BLOCKS_PER_CHUNK));
                        let mut err_opt = None;
                        for block_index in *first..=*last {
                            match self.xrpc.get_block(segment, block_index).await {
                                Ok(frame) => frames.push(frame),
                                Err(e) => {
                                    err_opt = Some(e);
                                    break;
                                }
                            }
                        }
                        match err_opt {
                            Some(e) => Err(e),
                            None => Ok(DownloadedUnit::BlockFrames(frames)),
                        }
                    }
                }
            };

            match res {
                Ok(unit) => return Ok(unit),
                Err(JetstreamHttpError::Xrpc(ref x))
                    if x.error.as_deref() == Some("SegmentNotFound") =>
                {
                    let _ = CompactedSegmentError;
                    return Err(WorkUnitError::Compacted);
                }
                Err(err) => {
                    if attempts >= 3 {
                        return Err(WorkUnitError::Client(JetstreamClientError::Http(err)));
                    }
                    let delay = self.config.backoff.next_delay(current_delay);
                    current_delay = Some(delay);
                    client_sleep(delay).await;
                }
            }
        }
    }

    async fn process_downloaded_unit(
        &self,
        unit: &DownloadedUnit,
        initial_after_seq: i64,
        effective_limit: i64,
        state: &mut BackfillState,
        sender: &mut JetstreamBatchSender<JetstreamClientError>,
    ) -> Result<(), JetstreamClientError> {
        match unit {
            DownloadedUnit::SegmentBytes(bytes) => {
                let mut reader = SegmentBytesReader::new(bytes)?;
                while let Some(block_events) = reader.next_block()? {
                    self.process_block_events(
                        &block_events,
                        initial_after_seq,
                        effective_limit,
                        state,
                        sender,
                    )
                    .await;
                }
            }
            DownloadedUnit::BlockFrames(frames) => {
                for frame in frames {
                    let block_events = SegmentBlockDecoder::decode_frame(frame)?;
                    self.process_block_events(
                        &block_events,
                        initial_after_seq,
                        effective_limit,
                        state,
                        sender,
                    )
                    .await;
                }
            }
        }
        Ok(())
    }

    async fn process_block_events(
        &self,
        events: &[SegmentEvent],
        initial_after_seq: i64,
        effective_limit: i64,
        state: &mut BackfillState,
        sender: &mut JetstreamBatchSender<JetstreamClientError>,
    ) {
        let batch_cap = self.config.batch_size.max(1);
        for ev in events {
            let seq = ev.seq;
            if seq > initial_after_seq && seq <= effective_limit && seq > state.last_processed {
                let Some(jetstream_event) = ev.to_jetstream_event() else {
                    continue;
                };
                if self.config.filter.matches(&jetstream_event) {
                    state.current_batch.push(jetstream_event);
                    state.last_processed = seq;
                    if state.current_batch.len() >= batch_cap {
                        self.flush_batch(state, sender).await;
                    }
                } else {
                    state.last_processed = seq;
                }
            }
        }
    }
}

enum WorkUnitError {
    Compacted,
    Client(JetstreamClientError),
}

fn plan_to_work_units(plan: &SnapshotPlan) -> Result<Vec<WorkUnit>, JetstreamClientError> {
    if plan.segments.len() > MAX_PLAN_SEGMENTS {
        return Err(JetstreamClientError::Http(JetstreamHttpError::Decode(
            format!(
                "snapshot plan segment count {} exceeds limit {MAX_PLAN_SEGMENTS}",
                plan.segments.len()
            ),
        )));
    }
    let mut work_units = Vec::new();
    let mut total_blocks = 0usize;
    for segment in &plan.segments {
        if segment.mode == "segment" {
            if work_units.len() >= MAX_PLAN_WORK_UNITS {
                return Err(JetstreamClientError::Http(JetstreamHttpError::Decode(
                    format!("snapshot plan work units exceed limit {MAX_PLAN_WORK_UNITS}"),
                )));
            }
            work_units.push(WorkUnit::Segment {
                name: segment.name.clone(),
            });
        } else if segment.mode == "blocks"
            && let Some(ranges) = &segment.blocks
        {
            for range in ranges {
                if range.last < range.first {
                    return Err(JetstreamClientError::Http(JetstreamHttpError::Decode(
                        format!(
                            "invalid snapshot block range in segment {}: first={} > last={}",
                            segment.name, range.first, range.last
                        ),
                    )));
                }
                let span = (range.last - range.first).checked_add(1).ok_or_else(|| {
                    JetstreamClientError::Http(JetstreamHttpError::Decode(
                        "snapshot block range overflows usize".to_owned(),
                    ))
                })?;
                total_blocks = total_blocks.checked_add(span).ok_or_else(|| {
                    JetstreamClientError::Http(JetstreamHttpError::Decode(
                        "snapshot plan total block count overflows".to_owned(),
                    ))
                })?;
                if total_blocks > MAX_PLAN_TOTAL_BLOCKS {
                    return Err(JetstreamClientError::Http(JetstreamHttpError::Decode(
                        format!(
                            "snapshot plan block count {total_blocks} exceeds limit {MAX_PLAN_TOTAL_BLOCKS}"
                        ),
                    )));
                }
                let mut chunk_first = range.first;
                while chunk_first <= range.last {
                    let chunk_last = chunk_first
                        .saturating_add(MAX_BLOCKS_PER_CHUNK - 1)
                        .min(range.last);
                    if work_units.len() >= MAX_PLAN_WORK_UNITS {
                        return Err(JetstreamClientError::Http(JetstreamHttpError::Decode(
                            format!("snapshot plan work units exceed limit {MAX_PLAN_WORK_UNITS}"),
                        )));
                    }
                    work_units.push(WorkUnit::BlockRange {
                        segment: segment.name.clone(),
                        first: chunk_first,
                        last: chunk_last,
                    });
                    if chunk_last == usize::MAX {
                        break;
                    }
                    chunk_first = chunk_last + 1;
                }
            }
        }
    }
    Ok(work_units)
}

#[cfg(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", target_os = "unknown", feature = "wasm")
))]
async fn client_sleep(duration: Duration) {
    if !duration.is_zero() {
        petrel::rt::sleep(duration).await;
    }
}

#[cfg(not(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", target_os = "unknown", feature = "wasm")
)))]
async fn client_sleep(_duration: Duration) {}
