//! Running token exchanges independently of the caller, and timers for
//! builds without a runtime feature.
//!
//! A refresh-token exchange must finish once its request may have reached
//! the server: the server rotates the token when it answers, so dropping the
//! response loses the only copy of the replacement, and the next refresh
//! replays a consumed token. [`run_detached`] keeps the exchange running when
//! the caller's future is dropped (an HTTP handler whose client went away, a
//! `select!`, a timeout).
//!
//! | Build | Exchange runs on | Delays |
//! |---|---|---|
//! | `native`, inside a Tokio runtime | `tokio::spawn` | Tokio timer |
//! | `native`, no current Tokio runtime | the caller's task | Tokio timer |
//! | `wasm` on `wasm32` | `wasm_bindgen_futures::spawn_local` | browser timer |
//! | neither feature, not `wasm32` | the caller's task | a sleeping helper thread |
//! | neither feature, `wasm32` | the caller's task | none (bounded loops only) |
//!
//! Where the exchange runs on the caller's task, a dropped caller cancels it.
//! The refresh code then releases the refresh token for a later attempt.
//! Embedders without a runtime feature should poll refresh futures to
//! completion.

#[cfg(not(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", feature = "wasm")
)))]
use std::time::Duration;
use std::{future::Future, pin::Pin};

use futures_util::future::{FutureExt, Shared};

use crate::rt::MaybeSend;

/// Whether this build has a timer that actually waits. Loops that poll for a
/// peer must also cap their iteration count when it does not.
pub(crate) const HAS_TIMER: bool = cfg!(any(
    not(target_arch = "wasm32"),
    all(target_arch = "wasm32", feature = "wasm")
));

#[cfg(not(target_arch = "wasm32"))]
type Boxed<T> = Pin<Box<dyn Future<Output = T> + Send>>;
#[cfg(target_arch = "wasm32")]
type Boxed<T> = Pin<Box<dyn Future<Output = T>>>;

/// A handle that every caller interested in one exchange can await. Dropping a
/// handle never cancels the exchange while a runtime is driving it.
pub(crate) type Detached<T> = Shared<Boxed<T>>;

/// Starts `future` on the platform runtime and returns a handle to its
/// result. Without a runtime the handle drives the future itself.
pub(crate) fn run_detached<F>(future: F) -> Detached<F::Output>
where
    F: Future + MaybeSend + 'static,
    F::Output: Clone + MaybeSend + Sync + 'static,
{
    let boxed: Boxed<F::Output> = Box::pin(future);
    let shared = boxed.shared();
    let _ = spawn(shared.clone().map(drop));
    shared
}

/// Runs `future` to completion on the platform runtime. Returns `false`, having
/// dropped `future` unpolled, when there is no runtime to run it on.
#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
pub(crate) fn spawn<F: Future<Output = ()> + Send + 'static>(future: F) -> bool {
    match tokio::runtime::Handle::try_current() {
        Ok(handle) => {
            drop(handle.spawn(future));
            true
        }
        Err(_) => false,
    }
}

/// Runs `future` to completion on the browser event loop.
#[cfg(all(target_arch = "wasm32", feature = "wasm"))]
pub(crate) fn spawn<F: Future<Output = ()> + 'static>(future: F) -> bool {
    wasm_bindgen_futures::spawn_local(future);
    true
}

#[cfg(not(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", feature = "wasm")
)))]
pub(crate) fn spawn<F: Future<Output = ()> + MaybeSend + 'static>(future: F) -> bool {
    // No runtime to hand it to: callers poll the work themselves.
    drop(future);
    false
}

/// Waits for `duration` without any runtime: a helper thread sleeps and
/// wakes the task. On `wasm32` there are no threads and this returns at once.
#[cfg(not(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", feature = "wasm")
)))]
pub(crate) async fn thread_delay(duration: Duration) {
    #[cfg(not(target_arch = "wasm32"))]
    {
        let _ = on_thread(move || std::thread::sleep(duration)).await;
    }
    #[cfg(target_arch = "wasm32")]
    let _ = duration;
}

/// Runs a blocking closure on a new thread and waits for it without blocking
/// the polling executor. Returns `None` if no thread could be started.
#[cfg(all(not(target_arch = "wasm32"), any(not(feature = "native"), test)))]
pub(crate) async fn on_thread<F, T>(operation: F) -> Option<T>
where
    F: FnOnce() -> T + Send + 'static,
    T: Send + 'static,
{
    use std::{
        sync::{Arc, Mutex, PoisonError},
        task::{Poll, Waker},
    };

    struct Slot<T> {
        value: Option<T>,
        done: bool,
        waker: Option<Waker>,
    }

    let slot = Arc::new(Mutex::new(Slot {
        value: None,
        done: false,
        waker: None,
    }));
    let remote = Arc::clone(&slot);
    let spawned = std::thread::Builder::new()
        .name("petrel-blocking".into())
        .spawn(move || {
            // Mark completion even if `operation` panics.
            struct Finish<T>(Arc<Mutex<Slot<T>>>);
            impl<T> Drop for Finish<T> {
                fn drop(&mut self) {
                    let mut slot = self.0.lock().unwrap_or_else(PoisonError::into_inner);
                    slot.done = true;
                    if let Some(waker) = slot.waker.take() {
                        waker.wake();
                    }
                }
            }
            let finish = Finish(remote);
            let value = operation();
            finish
                .0
                .lock()
                .unwrap_or_else(PoisonError::into_inner)
                .value = Some(value);
        });
    if spawned.is_err() {
        return None;
    }
    std::future::poll_fn(|cx| {
        let mut slot = slot.lock().unwrap_or_else(PoisonError::into_inner);
        if slot.done {
            Poll::Ready(slot.value.take())
        } else {
            slot.waker = Some(cx.waker().clone());
            Poll::Pending
        }
    })
    .await
}

#[cfg(all(test, not(target_arch = "wasm32")))]
mod tests {
    use super::*;

    #[cfg(feature = "native")]
    #[tokio::test]
    async fn a_detached_future_finishes_after_its_handle_is_dropped() {
        use std::sync::{
            Arc,
            atomic::{AtomicBool, Ordering},
        };

        let gate = Arc::new(async_lock::Mutex::new(()));
        let hold = gate.lock().await;
        let finished = Arc::new(AtomicBool::new(false));
        let (flag, remote_gate) = (Arc::clone(&finished), Arc::clone(&gate));
        let mut handle = run_detached(async move {
            drop(remote_gate.lock().await);
            flag.store(true, Ordering::SeqCst);
        });
        // Poll the handle once, as a caller would, then drop it mid-flight.
        std::future::poll_fn(|cx| {
            assert!(Pin::new(&mut handle).poll(cx).is_pending());
            std::task::Poll::Ready(())
        })
        .await;
        drop(handle);
        drop(hold);
        for _ in 0..100 {
            if finished.load(Ordering::SeqCst) {
                return;
            }
            tokio::task::yield_now().await;
        }
        panic!("the detached future was cancelled with its handle");
    }

    #[tokio::test]
    async fn blocking_work_runs_on_a_helper_thread() {
        let caller = std::thread::current().id();
        let worker = on_thread(|| std::thread::current().id()).await.unwrap();
        assert_ne!(caller, worker);
    }
}
