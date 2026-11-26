//! Account hosting status and legacy password error types.

use std::fmt;

use petrel_core::xrpc::XrpcErrorBody;

/// Specific hosting reason reported by a service alongside `active`.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum AccountStatusReason {
    /// Host or service took the account down long-term.
    Takendown,
    /// Host or service temporarily paused the account.
    Suspended,
    /// User or host deleted the account.
    Deleted,
    /// User paused the account or migrated away.
    Deactivated,
    /// Host detected a repository synchronization issue (may still be `active: true`).
    Desynchronized,
    /// Host paused processing due to rate limiting (may still be `active: true`).
    Throttled,
    /// Forward-compatible unrecognized wire status string.
    Other(String),
}

impl AccountStatusReason {
    /// Parses a wire status string, preserving unrecognized values verbatim.
    #[must_use]
    pub fn parse(status: &str) -> Self {
        match status {
            "takendown" => Self::Takendown,
            "suspended" => Self::Suspended,
            "deleted" => Self::Deleted,
            "deactivated" => Self::Deactivated,
            "desynchronized" => Self::Desynchronized,
            "throttled" => Self::Throttled,
            other => Self::Other(other.to_owned()),
        }
    }

    /// Returns the wire `status` string.
    #[must_use]
    pub fn raw_value(&self) -> &str {
        match self {
            Self::Takendown => "takendown",
            Self::Suspended => "suspended",
            Self::Deleted => "deleted",
            Self::Deactivated => "deactivated",
            Self::Desynchronized => "desynchronized",
            Self::Throttled => "throttled",
            Self::Other(other) => other.as_str(),
        }
    }
}

impl From<&str> for AccountStatusReason {
    fn from(value: &str) -> Self {
        Self::parse(value)
    }
}

/// Hosting status of an account as reported by `getSession`, `refreshSession`,
/// `getRepoStatus`, or XRPC status errors.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct AccountStatus {
    /// Whether the account is active at the service that reported this status.
    pub is_active: bool,
    /// Optional reason qualifying the status.
    pub reason: Option<AccountStatusReason>,
}

impl Default for AccountStatus {
    fn default() -> Self {
        Self::active()
    }
}

impl AccountStatus {
    /// An active account with no qualifying status string.
    #[must_use]
    pub const fn active() -> Self {
        Self {
            is_active: true,
            reason: None,
        }
    }

    /// Creates a status from explicit fields.
    #[must_use]
    pub const fn new(is_active: bool, reason: Option<AccountStatusReason>) -> Self {
        Self { is_active, reason }
    }

    /// Interprets `(active, status)` from an ATProto response. Omitted `active` defaults to `true`.
    #[must_use]
    pub fn from_api(active: Option<bool>, status: Option<&str>) -> Self {
        Self {
            is_active: active.unwrap_or(true),
            reason: status.map(AccountStatusReason::parse),
        }
    }
}

impl fmt::Display for AccountStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let state = if self.is_active { "active" } else { "inactive" };
        match &self.reason {
            Some(reason) => write!(f, "{state} ({})", reason.raw_value()),
            None => f.write_str(state),
        }
    }
}

/// Error returned when a server refuses a request due to account hosting status
/// (`AccountTakedown`, `AccountSuspended`, `AccountDeactivated`, `AccountDeleted`).
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub struct AccountStatusError {
    /// Reported hosting status.
    pub status: AccountStatus,
    /// Optional server explanation.
    pub message: Option<String>,
}

impl fmt::Display for AccountStatusError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let headline = match &self.status.reason {
            Some(AccountStatusReason::Takendown) => "This account has been taken down.",
            Some(AccountStatusReason::Suspended) => "This account has been suspended.",
            Some(AccountStatusReason::Deactivated) => "This account is deactivated.",
            Some(AccountStatusReason::Deleted) => "This account has been deleted.",
            _ => "This account is not active.",
        };
        match &self.message {
            Some(msg) if !msg.is_empty() => write!(f, "{headline} ({msg})"),
            _ => f.write_str(headline),
        }
    }
}

impl AccountStatusError {
    /// Creates an [`AccountStatusError`].
    #[must_use]
    pub const fn new(status: AccountStatus, message: Option<String>) -> Self {
        Self { status, message }
    }

    /// Maps an XRPC error wire name (`AccountTakedown`, etc.) to [`AccountStatusError`].
    #[must_use]
    pub fn from_xrpc_error(name: &str, message: Option<&str>) -> Option<Self> {
        let reason = match name {
            "AccountTakedown" => AccountStatusReason::Takendown,
            "AccountSuspended" => AccountStatusReason::Suspended,
            "AccountDeactivated" => AccountStatusReason::Deactivated,
            "AccountDeleted" => AccountStatusReason::Deleted,
            _ => return None,
        };
        Some(Self {
            status: AccountStatus::new(false, Some(reason)),
            message: message.map(str::to_owned),
        })
    }

    /// Recognizes a hosting-status refusal inside an XRPC JSON error response body.
    #[must_use]
    pub fn from_xrpc_body(body: &[u8]) -> Option<Self> {
        let parsed = XrpcErrorBody::parse(body)?;
        Self::from_xrpc_error(&parsed.error, parsed.message.as_deref())
    }
}

/// Error returned when `createSession` requires an emailed second-factor code
/// (`AuthFactorTokenRequired`).
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, thiserror::Error)]
#[error("A sign-in code was emailed to this account. Enter it to finish signing in.")]
pub struct AuthFactorTokenRequiredError;
