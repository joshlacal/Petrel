//! Runtime abstraction: the `Send` story, and (Lane D) sleeping and clocks.
//!
//! Contract 6 of the Petrel Rust plan lives here and is frozen:
//! [`MaybeSend`], [`MaybeSync`] and [`BoxFuture`].
//!
//! Browser futures (fetch, timers, WebCrypto) are not `Send`, so a `Send`
//! bound that is right on native targets makes the crate unusable on
//! `wasm32`. These three items are `Send`/`Sync` on native targets and
//! unbounded on `wasm32`, so every trait in this crate is written once.
//!
//! Lane D adds here: a `sleep` function (tokio under `native`, gloo timers
//! under `wasm`) and the clock wrapper over `web-time` (`std::time` panics on
//! `wasm32-unknown-unknown`). Nothing in this crate may call
//! `std::time::Instant::now` or `SystemTime::now` directly.

use std::future::Future;
use std::pin::Pin;

/// `Send` on native targets, no bound on `wasm32`.
#[cfg(not(target_arch = "wasm32"))]
pub trait MaybeSend: Send {}
#[cfg(not(target_arch = "wasm32"))]
impl<T: ?Sized + Send> MaybeSend for T {}

/// `Send` on native targets, no bound on `wasm32`.
#[cfg(target_arch = "wasm32")]
pub trait MaybeSend {}
#[cfg(target_arch = "wasm32")]
impl<T: ?Sized> MaybeSend for T {}

/// `Sync` on native targets, no bound on `wasm32`.
#[cfg(not(target_arch = "wasm32"))]
pub trait MaybeSync: Sync {}
#[cfg(not(target_arch = "wasm32"))]
impl<T: ?Sized + Sync> MaybeSync for T {}

/// `Sync` on native targets, no bound on `wasm32`.
#[cfg(target_arch = "wasm32")]
pub trait MaybeSync {}
#[cfg(target_arch = "wasm32")]
impl<T: ?Sized> MaybeSync for T {}

/// A boxed future for traits stored as `dyn`: `Send` on native targets.
///
/// `dyn Future + MaybeSend` cannot be written (only auto traits may be added
/// to a trait object), hence the cfg-gated alias.
#[cfg(not(target_arch = "wasm32"))]
pub type BoxFuture<'a, T> = Pin<Box<dyn Future<Output = T> + Send + 'a>>;

/// A boxed future for traits stored as `dyn`: not `Send` on `wasm32`.
#[cfg(target_arch = "wasm32")]
pub type BoxFuture<'a, T> = Pin<Box<dyn Future<Output = T> + 'a>>;

mod timing;

pub use timing::DeadlineElapsed;
#[cfg(any(
    all(not(target_arch = "wasm32"), feature = "native"),
    all(target_arch = "wasm32", feature = "wasm")
))]
pub use timing::{sleep, timeout};
pub use web_time::{Instant, SystemTime, UNIX_EPOCH};
