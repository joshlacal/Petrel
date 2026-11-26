//! The XRPC request pipeline, and the seam where authentication plugs in.
//!
//! Contract 8 of the Petrel Rust plan lives here and is frozen:
//! [`AuthProvider`] and [`AuthCtx`].
//!
//! # Who retries what
//!
//! The split below is deliberate; getting it wrong doubles retries.
//!
//! - **The pipeline (Lane D, this module) owns the single DPoP nonce
//!   retry.** On a `use_dpop_nonce` challenge it calls
//!   [`AuthProvider::update_dpop_nonce`], then [`AuthProvider::prepare`]
//!   again on a fresh copy of the request, and sends once more. Exactly once.
//! - **The provider (Lane E, `crate::oauth`) owns token refresh.** The
//!   pipeline calls [`AuthProvider::refresh_if_needed`] before sending and
//!   [`AuthProvider::handle_unauthorized`] on a 401; the provider decides
//!   whether a refresh happened and whether the request is worth repeating.
//!
//! [`XrpcClient`] handles generated and raw requests, origin-scoped routing,
//! retries, and cursor pagination. Generated endpoint types implement the
//! traits in [`petrel_core::xrpc`].

use std::fmt;

use bytes::Bytes;
use petrel_core::Did;

use crate::net::TransportError;
use crate::rt::{BoxFuture, MaybeSend, MaybeSync};
use crate::storage::StoreError;

/// What [`AuthProvider::prepare`] bound a request to. The pipeline passes it
/// back unchanged, so a late response is never applied to a session that has
/// since been replaced.
#[derive(Clone, PartialEq, Eq, Default)]
pub struct AuthCtx {
    /// The account the request was signed for. `None` if unauthenticated.
    pub did: Option<Did>,
    /// RFC 7638 thumbprint of the DPoP key that signed the request. `None`
    /// if no DPoP proof was attached.
    pub jkt: Option<String>,
    /// Opaque provider-defined revision of the session that signed this request.
    /// A late response can refer to a superseded token even if the key is unchanged.
    pub session_generation: Option<[u8; 32]>,
}

impl fmt::Debug for AuthCtx {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("AuthCtx")
            .field("did", &self.did)
            .field("jkt", &self.jkt)
            .field(
                "session_generation",
                &self.session_generation.map(|_| "<redacted>"),
            )
            .finish()
    }
}

/// What the pipeline should do after a 401.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UnauthorizedAction {
    /// Credentials were refreshed: prepare and send the request once more.
    Retry,
    /// Nothing changed: surface the 401 to the caller.
    GiveUp,
}

/// Authentication failed before or after a request.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[non_exhaustive]
pub enum AuthError {
    /// There is no session to authenticate with.
    #[error("no session")]
    NoSession,
    /// The session is gone for good (refresh token rejected or revoked). The
    /// user has to sign in again.
    #[error("session expired: {0}")]
    SessionExpired(String),
    /// Refresh failed for a reason that may pass (network, 5xx). The session
    /// is still stored.
    #[error("token refresh failed: {0}")]
    RefreshFailed(String),
    /// The secret store failed. This is never "signed out".
    #[error(transparent)]
    Store(#[from] StoreError),
    /// A request to the authorization server could not be sent.
    #[error(transparent)]
    Transport(#[from] TransportError),
    /// The server rejected the request due to account hosting status.
    #[error(transparent)]
    AccountStatus(#[from] crate::auth::AccountStatusError),
    /// Anything else.
    #[error("{0}")]
    Other(String),
}

/// Attaches credentials to requests and keeps them fresh.
///
/// Stored as `dyn` by the XRPC client, so methods return [`BoxFuture`].
/// Implemented by the OAuth session in `crate::oauth` (Lane E); a client with
/// no provider sends unauthenticated requests.
pub trait AuthProvider: MaybeSend + MaybeSync {
    /// Adds `Authorization` and `DPoP` (and whatever else the scheme needs)
    /// to a request and reports what it was bound to. Credentials must be
    /// attached only when the request's origin is the session's PDS origin.
    fn prepare(
        &self,
        request: http::Request<Bytes>,
    ) -> BoxFuture<'_, Result<(http::Request<Bytes>, AuthCtx), AuthError>>;

    /// Refreshes the access token if it is at or near expiry. Single-flight
    /// per account. Called by the pipeline before each send.
    fn refresh_if_needed(&self) -> BoxFuture<'_, Result<(), AuthError>>;

    /// Reacts to a 401 or a 400 carrying `ExpiredToken`. The
    /// pipeline handles DPoP nonce challenges directly.
    fn handle_unauthorized<'a>(
        &'a self,
        response: &'a http::Response<Bytes>,
        ctx: &'a AuthCtx,
    ) -> BoxFuture<'a, Result<UnauthorizedAction, AuthError>>;

    /// Records a `DPoP-Nonce` seen on a response from `origin`. Nonces are
    /// keyed by (key thumbprint, origin) and kept in memory (plan decision
    /// 10).
    fn update_dpop_nonce<'a>(
        &'a self,
        origin: &'a str,
        nonce: &'a str,
        ctx: &'a AuthCtx,
    ) -> BoxFuture<'a, ()>;
}

mod client;
mod pages;
mod response;

pub use client::{CallOptions, Error, Sleeper, XrpcBody, XrpcClient};
pub use petrel_core::xrpc::{RateLimit, XrpcErrorBody};
pub use response::{ResponseMetadata, XrpcError, XrpcErrorKind, XrpcLabeler, XrpcResponse};

#[cfg(all(test, not(target_arch = "wasm32"), feature = "native"))]
mod tests;
