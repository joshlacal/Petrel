//! Server-side AT Protocol OAuth 2.1, DPoP resource verification, CAB, service-auth JWT
//! verification, and typed XRPC routing primitives.
//!
//! Pure protocol and cryptographic verification logic compiles cleanly on `wasm32-unknown-unknown`
//! (`--no-default-features --features wasm`), while Tokio/Axum/Reqwest integrations are gated behind
//! the `native` and `axum` features.

#![forbid(unsafe_code)]

#[cfg(all(not(target_arch = "wasm32"), feature = "axum"))]
pub mod axum;
pub mod cab;
pub mod clients;
pub mod dpop;
pub mod error;
pub mod http;
pub mod jose;
pub mod lexicon;
pub mod lexicon_resolver;
pub mod oauth;
pub mod service_auth;
pub mod store;
pub mod support;
pub mod xrpc;

pub use error::OAuthServerError;
pub use http::{OAuthHttpField, OAuthHttpHeaders, OAuthHttpRequest, OAuthHttpResponse, OAuthRoute};
pub use oauth::{
    OAuthAccessGrant, OAuthAccessTokenFormat, OAuthAuthorizationServer,
    OAuthAuthorizationServerConfiguration, OAuthResourceServerVerifier,
};
pub use service_auth::{
    ServiceAuthAudience, ServiceAuthError, ServiceAuthKeyResolver, ServiceAuthMethodPolicy,
    ServiceAuthReplayStore, ServiceAuthRequiredClaims, ServiceAuthVerifier,
    ServiceAuthVerifierConfig, VerifiedServiceAuth,
};

#[cfg(all(not(target_arch = "wasm32"), feature = "ws"))]
pub mod subscription;
