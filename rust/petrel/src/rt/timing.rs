#[cfg(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", feature = "wasm")
))]
use {
    futures_util::future::{Either, select},
    std::{future::Future, time::Duration},
};

/// Yield to the platform's timer for the specified duration.
#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
pub async fn sleep(duration: Duration) {
    tokio::time::sleep(duration).await;
}

#[cfg(all(target_arch = "wasm32", feature = "wasm"))]
pub async fn sleep(duration: Duration) {
    // Browser timer APIs accept at most a signed 32-bit millisecond count.
    const MAX_DELAY: u32 = 2_147_483_647;
    let mut delay_ms = duration.as_nanos().div_ceil(1_000_000);
    while delay_ms > u128::from(MAX_DELAY) {
        gloo_timers::future::TimeoutFuture::new(MAX_DELAY).await;
        delay_ms -= u128::from(MAX_DELAY);
    }
    gloo_timers::future::TimeoutFuture::new(u32::try_from(delay_ms).unwrap_or(MAX_DELAY)).await;
}

/// A timer expired before a future finished.
#[derive(Debug, Clone, Copy, PartialEq, Eq, thiserror::Error)]
#[error("deadline elapsed")]
pub struct DeadlineElapsed;

/// Race a future with the platform timer. When the timer fires the unfinished
/// future is dropped. The transport must cancel any I/O it owns on drop.
#[cfg(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", feature = "wasm")
))]
pub async fn timeout<F: Future>(
    duration: Duration,
    future: F,
) -> Result<F::Output, DeadlineElapsed> {
    match select(std::pin::pin!(future), std::pin::pin!(sleep(duration))).await {
        Either::Left((result, _)) => Ok(result),
        Either::Right(((), _)) => Err(DeadlineElapsed),
    }
}
