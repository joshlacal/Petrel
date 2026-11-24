//! The AT Protocol OAuth client.
//!
//! Contract 10 of the Petrel Rust plan lives here and is frozen:
//! [`ClientAuth`], with [`AssertionSigner`].
//!
//! Lane E adds here (map: `maps/oauth-auth.md`, packages O4 to O9):
//! authorization-server and protected-resource metadata discovery and
//! validation, PAR, the authorization flow and callback handling, token
//! refresh and revocation, the DPoP nonce store, and the session type that
//! implements [`crate::xrpc::AuthProvider`]. The wire contract for a client
//! assertion backend is `Petrel/docs/cab-backend-contract.md`.
//!
//! Invariants most often lost in a port (each has its Swift `path:line` in
//! the map):
//!
//! - Authorization-server requests never follow redirects and never carry an
//!   `Authorization` header.
//! - A fresh client assertion for every request *attempt*, including the
//!   nonce retry and revocation: an assertion's `jti` is single-use.
//! - Refresh is single-flight per DID.
//! - Fail closed where Swift is loose (plan decision 14): verify the
//!   `client_id` a CAB returns.

mod client;
mod dpop;
mod metadata;
mod models;
mod protocol;
mod refresh;
mod resource_auth;

pub use client::{
    DpopKeyStore, OAuthClient, OAuthConfig, OAuthError, OAuthIdentity, OAuthIdentityError,
    OAuthIdentityResolver, OAuthTarget,
};
pub use dpop::{DpopError, DpopNonces, dpop_proof, dpop_target};
pub use metadata::{
    AuthorizationServerMetadata, ClientAuthenticationMethod, MetadataDocument, MetadataError,
    ProtectedResourceMetadata, ValidatedAuthorizationServer,
};
pub use models::{Account, Session, SessionRecord};
pub use protocol::{AssertionBackendError, AssertionBackendErrorCode, OAuthProtocolError};
pub use resource_auth::SessionAuth;

use std::fmt;
use std::sync::Arc;

use crate::crypto::CryptoError;
use crate::rt::{BoxFuture, MaybeSend, MaybeSync};

/// Signs client assertions with a key this process holds (the
/// `private_key_jwt` method).
pub trait AssertionSigner: MaybeSend + MaybeSync {
    /// The `kid` to put in the assertion header. It must match a key in the
    /// client metadata's JWKS.
    fn key_id(&self) -> &str;

    /// Signs the JWS signing input with ES256. Returns raw 64-byte `r ‖ s`,
    /// low-S normalized.
    fn sign<'a>(&'a self, signing_input: &'a [u8]) -> BoxFuture<'a, Result<[u8; 64], CryptoError>>;
}

/// How the client authenticates to the authorization server.
///
/// Evaluated once per authorization-server request **attempt**, never cached
/// across attempts.
#[derive(Clone)]
#[non_exhaustive]
pub enum ClientAuth {
    /// A public client: `token_endpoint_auth_method` is `none`.
    Public,
    /// A confidential client that signs its own assertions.
    PrivateKeyJwt(Arc<dyn AssertionSigner>),
    /// A confidential client whose assertions are signed by a client
    /// assertion backend: a small server that holds the signing key so the
    /// app never does. Petrel asks it for a fresh assertion on each attempt.
    Cab {
        /// Base URL of the backend.
        backend_url: url::Url,
        /// The OAuth `client_id` the backend signs for. The `client_id` the
        /// backend returns is checked against this.
        client_id: String,
    },
}

impl fmt::Debug for ClientAuth {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Public => f.write_str("Public"),
            Self::PrivateKeyJwt(signer) => f
                .debug_struct("PrivateKeyJwt")
                .field("key_id", &signer.key_id())
                .finish(),
            Self::Cab {
                backend_url,
                client_id,
            } => f
                .debug_struct("Cab")
                .field("backend_url", &backend_url.as_str())
                .field("client_id", client_id)
                .finish(),
        }
    }
}
