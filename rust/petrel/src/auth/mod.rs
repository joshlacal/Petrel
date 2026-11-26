//! Authentication strategies, continuity tracking, hosting status, and refresh circuit breakers.

pub(crate) mod background;
mod circuit_breaker;
mod continuity;
mod legacy_password;
mod manager;
mod status;

pub use circuit_breaker::{CircuitState, RefreshCircuitBreaker, RefreshFailureKind};
pub use continuity::{
    AuthContinuitySnapshot, AuthContinuityState, AuthContinuityTransactionResult, AuthMode,
    GatewayAuthIdentity,
};
pub use legacy_password::{
    ASSUMED_ACCESS_TOKEN_LIFETIME_SECS, LegacyPasswordStrategy, LegacySession, PasswordAuthError,
    PasswordLoginResult, TokenRefreshResult,
};
pub use manager::{AuthManager, AuthManagerError};
pub use status::{
    AccountStatus, AccountStatusError, AccountStatusReason, AuthFactorTokenRequiredError,
};
