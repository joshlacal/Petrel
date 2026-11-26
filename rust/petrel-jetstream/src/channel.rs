//! Bounded backpressure batch handoff between [`JetstreamClient`] and its consumer.

use std::future::Future;
use std::pin::Pin;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll, Waker};

use futures_util::stream;
use petrel::rt::MaybeSend;
use petrel_firehose::{
    BoxedEventStream, FirehoseBoundedReceiver, FirehoseBoundedSender, FirehoseCursorStorage,
    bounded_firehose_channel,
};

use crate::event::JetstreamEvent;
use crate::subscription::{CursorStorageOperation, JetstreamSubscriptionError};

#[derive(Default, Debug)]
struct CancelState {
    cancelled: bool,
    wakers: Vec<Waker>,
}

/// Shared cancellation handle that wakes pending async tasks when the consumer stream drops.
#[derive(Debug, Clone, Default)]
pub(crate) struct CancelSignal {
    flag: Arc<AtomicBool>,
    state: Arc<Mutex<CancelState>>,
}

impl CancelSignal {
    fn new() -> Self {
        Self::default()
    }

    pub(crate) fn cancel(&self) {
        self.flag.store(true, Ordering::SeqCst);
        let wakers = {
            let mut guard = self
                .state
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner);
            if guard.cancelled {
                return;
            }
            guard.cancelled = true;
            std::mem::take(&mut guard.wakers)
        };
        for waker in wakers {
            waker.wake();
        }
    }

    pub(crate) fn is_cancelled(&self) -> bool {
        self.flag.load(Ordering::SeqCst)
    }

    pub(crate) fn wait(&self) -> CancelFuture<'_> {
        CancelFuture { signal: self }
    }
}

pub(crate) struct CancelFuture<'a> {
    signal: &'a CancelSignal,
}

impl Future for CancelFuture<'_> {
    type Output = ();

    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        if self.signal.is_cancelled() {
            return Poll::Ready(());
        }
        let mut guard = self
            .signal
            .state
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        if guard.cancelled {
            return Poll::Ready(());
        }
        if !guard.wakers.iter().any(|w| w.will_wake(cx.waker())) {
            guard.wakers.push(cx.waker().clone());
        }
        Poll::Pending
    }
}

/// Sequence numbers are far below this; Unix microsecond timestamps have exceeded it since 2001.
pub(crate) const TIMESTAMP_CURSOR_FLOOR: i64 = 1_000_000_000_000_000;

/// One batch of decoded Jetstream events emitted by [`JetstreamClient`].
#[derive(Debug, Clone, PartialEq)]
pub struct JetstreamBatch {
    /// Decoded events in ascending sequence order.
    pub events: Vec<JetstreamEvent>,
    /// Highest sequence number in the batch (or active cursor for info-only batches).
    pub last_cursor: i64,
}

impl JetstreamBatch {
    /// Creates a batch with explicit events and cursor.
    pub fn new(events: Vec<JetstreamEvent>, last_cursor: i64) -> Self {
        Self {
            events,
            last_cursor,
        }
    }
}

/// Producer end of a [`JetstreamBatchChannel`].
#[derive(Debug, Clone)]
pub struct JetstreamBatchSender<E> {
    tx: FirehoseBoundedSender<Result<JetstreamBatch, E>>,
    cancel: CancelSignal,
}

impl<E> JetstreamBatchSender<E> {
    /// Yields `batch` to the consumer, applying backpressure when the channel is full.
    /// Returns `false` if the consumer dropped or cancelled the stream.
    pub async fn yield_batch(&mut self, batch: JetstreamBatch) -> bool {
        if self.cancel.is_cancelled() {
            return false;
        }
        self.tx.send(Ok(batch)).await.is_ok()
    }

    /// Reports a terminal error to the consumer.
    pub async fn finish_err(&mut self, err: E) {
        if !self.cancel.is_cancelled() {
            let _ = self.tx.send(Err(err)).await;
        }
    }

    /// Returns true once the consumer has cancelled or dropped the stream.
    pub fn is_cancelled(&self) -> bool {
        self.cancel.is_cancelled()
    }

    pub(crate) fn cancel_signal(&self) -> CancelSignal {
        self.cancel.clone()
    }
}

struct ConsumerChannelState<E> {
    rx: FirehoseBoundedReceiver<Result<JetstreamBatch, E>>,
    cursor_storage: Option<Arc<dyn FirehoseCursorStorage>>,
    delivered_cursor: Option<i64>,
    saved_cursor: i64,
    cancel: CancelSignal,
}

impl<E> Drop for ConsumerChannelState<E> {
    fn drop(&mut self) {
        self.cancel.cancel();
    }
}

/// Creates a bounded batch handoff channel and consumer stream (`tokio::sync::mpsc` native /
/// `futures_channel::mpsc` `wasm32`) saving each batch's cursor once the consumer requests the
/// next batch.
pub fn jetstream_batch_channel<E>(
    capacity: usize,
    cursor_storage: Option<Arc<dyn FirehoseCursorStorage>>,
) -> (
    JetstreamBatchSender<E>,
    BoxedEventStream<Result<JetstreamBatch, E>>,
)
where
    E: From<JetstreamSubscriptionError> + MaybeSend + 'static,
{
    let (tx, rx) = bounded_firehose_channel(capacity.max(1));
    let cancel = CancelSignal::new();
    let sender = JetstreamBatchSender {
        tx,
        cancel: cancel.clone(),
    };

    let state = ConsumerChannelState {
        rx,
        cursor_storage,
        delivered_cursor: None,
        saved_cursor: 0,
        cancel,
    };

    let stream = Box::pin(stream::unfold(Some(state), |maybe_st| async move {
        let mut st = maybe_st?;
        if let Some(cursor) = st.delivered_cursor.take()
            && cursor > st.saved_cursor
            && cursor < TIMESTAMP_CURSOR_FLOOR
        {
            if let Some(storage) = &st.cursor_storage
                && let Err(err) = storage.save_cursor(cursor).await
            {
                let failure = JetstreamSubscriptionError::CursorStorageFailure {
                    operation: CursorStorageOperation::Save,
                    message: err.to_string(),
                };
                return Some((Err(E::from(failure)), None));
            }
            st.saved_cursor = cursor;
        }

        match st.rx.recv().await {
            Some(Ok(batch)) => {
                st.delivered_cursor = Some(batch.last_cursor);
                Some((Ok(batch), Some(st)))
            }
            Some(Err(err)) => Some((Err(err), None)),
            None => None,
        }
    }));

    (sender, stream)
}
