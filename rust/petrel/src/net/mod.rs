//! HTTP transport seam, and (Lane D) the address policy around it.
//!
//! Contract 7 of the Petrel Rust plan lives here and is frozen:
//! [`HttpTransport`], [`SendOptions`] and [`TransportError`].
//!
//! A transport sends exactly one HTTP exchange. It **never follows
//! redirects**: Petrel follows them itself, one hop at a time, so it can
//! strip `DPoP` and `atproto-proxy` when a redirect crosses origins, and so
//! authorization-server requests can refuse redirects outright.
//!
//! Lane D adds here (map: `maps/network-identity.md`, packages N1 to N3):
//! the origin type and the SSRF/IP policy, the reqwest transport with a
//! filtering DNS resolver (`native`), the fetch transport (`wasm`), response
//! size and decompression caps, and the Petrel-level redirect follower.
//! Embedders such as Tauri can supply their own [`HttpTransport`].
//!
//! Browser Fetch cannot enforce connection-IP, wire-byte, or decompression
//! ratio limits. It caps the decoded stream and blocks opaque redirects.

use std::future::Future;
use std::sync::Arc;
use std::time::Duration;

use bytes::Bytes;

use crate::rt::{BoxFuture, MaybeSend, MaybeSync};

/// Per-request transport options.
#[derive(Debug, Clone, Default)]
#[non_exhaustive]
pub struct SendOptions {
    /// Overall deadline for the exchange. `None` uses the transport default.
    pub timeout: Option<Duration>,
    /// Refuse a response body larger than this many bytes after decoding.
    /// `None` uses the transport default.
    pub max_response_bytes: Option<u64>,
    /// Allow direct access to an exact loopback destination for local
    /// development. Remote-to-loopback redirects are still refused.
    pub allow_loopback: bool,
    /// Suppress client headers and credentials for third-party discovery.
    pub anonymous: bool,
}

impl SendOptions {
    /// Options with every field at the transport default.
    pub fn new() -> Self {
        Self::default()
    }
}

/// A transport-level failure: no HTTP response was obtained.
///
/// An HTTP error status is not a transport error; it comes back as a
/// response.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[non_exhaustive]
pub enum TransportError {
    /// The deadline passed.
    #[error("request timed out")]
    Timeout,
    /// The connection could not be made or was lost.
    #[error("connection failed: {0}")]
    Connect(String),
    /// The connection dropped after the request may have been sent.
    #[error("connection interrupted: {0}")]
    ConnectionLost(String),
    /// The address policy refused the destination (private range, bad
    /// scheme, and so on). Never retried.
    #[error("destination refused by policy: {0}")]
    PolicyViolation(String),
    /// The response body exceeded the size limit.
    #[error("response larger than {limit} bytes")]
    ResponseTooLarge {
        /// The limit that was exceeded.
        limit: u64,
    },
    /// The request could not be sent as built.
    #[error("invalid request: {0}")]
    InvalidRequest(String),
    /// Anything else.
    #[error("transport error: {0}")]
    Other(String),
}

/// Sends one HTTP exchange. Implementations never follow redirects.
pub trait HttpTransport: MaybeSend + MaybeSync {
    /// Sends the request and returns the response with its body fully read.
    fn send(
        &self,
        request: http::Request<Bytes>,
        options: &SendOptions,
    ) -> impl Future<Output = Result<http::Response<Bytes>, TransportError>> + MaybeSend;
}

/// The object-safe form of [`HttpTransport`], implemented for every
/// transport. Use it where a transport is stored: [`SharedTransport`].
pub trait DynHttpTransport: MaybeSend + MaybeSync {
    /// See [`HttpTransport::send`].
    fn send_dyn<'a>(
        &'a self,
        request: http::Request<Bytes>,
        options: &'a SendOptions,
    ) -> BoxFuture<'a, Result<http::Response<Bytes>, TransportError>>;
}

impl<T: HttpTransport> DynHttpTransport for T {
    fn send_dyn<'a>(
        &'a self,
        request: http::Request<Bytes>,
        options: &'a SendOptions,
    ) -> BoxFuture<'a, Result<http::Response<Bytes>, TransportError>> {
        Box::pin(self.send(request, options))
    }
}

/// A transport shared between the XRPC client, the OAuth client and the
/// identity resolver.
pub type SharedTransport = Arc<dyn DynHttpTransport>;

#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
mod body;
#[cfg(all(target_arch = "wasm32", feature = "wasm"))]
mod browser;
#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
mod native;
pub mod policy;
mod redirect;

#[cfg(all(target_arch = "wasm32", feature = "wasm"))]
pub use browser::FetchTransport;
#[cfg(all(not(target_arch = "wasm32"), feature = "native"))]
pub use native::ReqwestTransport;
pub use policy::Origin;
pub use redirect::{RedirectPolicy, ResponseOrigin, send_with_redirects};
