//! Service authentication verification, key resolution, policies, and replay stores.

pub mod error;
pub mod key_resolver;
pub mod policy;
pub mod replay_store;
pub(crate) mod syntax;
pub mod verifier;

pub use error::ServiceAuthError;
pub use key_resolver::{
    CachingServiceAuthKeyResolver, ClockFn, ClosureServiceAuthKeyResolver, ServiceAuthKeyResolver,
    StaticServiceAuthKeyResolver,
};
pub use petrel_core::{ServiceRef, ServiceRefError};
pub use policy::{
    ServiceAuthAudience, ServiceAuthMethodPolicy, ServiceAuthPolicy, ServiceAuthRequiredClaims,
    VerifiedServiceAuth,
};
pub use replay_store::{InMemoryServiceAuthReplayStore, ReplayStoreError, ServiceAuthReplayStore};
pub use verifier::{
    ServiceAuthVerifier, ServiceAuthVerifierConfig, ServiceAuthVerifierConfiguration,
};

/// Alias matching Swift's `ATProtoServiceReference`.
pub type ATProtoServiceReference = ServiceRef;
