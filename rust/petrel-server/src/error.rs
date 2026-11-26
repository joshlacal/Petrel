use thiserror::Error;

/// The failure vocabulary of the authorization-server core.
#[derive(Debug, Clone, PartialEq, Eq, Error)]
pub enum OAuthServerError {
    /// A DID, NSID, client identifier, or URL was not well formed.
    #[error("invalid identifier: {0}")]
    InvalidIdentifier(String),
    /// The caller presented a credential, proof, or binding that does not authorize the operation.
    #[error("unauthorized: {0}")]
    Unauthorized(String),
    /// A credential, proof, or request outlived its validity window.
    #[error("credential or token expired")]
    Expired,
    /// Input could not be parsed or violated a structural limit.
    #[error("malformed input: {0}")]
    Malformed(String),
    /// A dependency (store, resolver, remote document) could not answer; retryable.
    #[error("unavailable: {0}")]
    Unavailable(String),
}
