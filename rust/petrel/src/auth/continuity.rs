//! Authentication continuity snapshots and state machine.

use sha2::{Digest, Sha256};
use url::Url;

/// Active authentication mode for [`crate::client::AtProtoClient`] and [`super::AuthManager`].
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AuthMode {
    /// Unauthenticated raw XRPC calls only.
    None,
    /// Legacy app-password authentication (`createSession` / `refreshSession` Bearer tokens).
    Legacy,
    /// Public ATProto OAuth (`PAR` + `PKCE` + `DPoP`).
    PublicOAuth,
    /// Confidential BFF gateway origin.
    Gateway {
        /// Canonical gateway origin URL.
        origin: Url,
    },
    /// Confidential Client Assertion Backend (`CAB`).
    Cab {
        /// Client assertion backend base URL.
        backend_url: Url,
    },
}

impl AuthMode {
    /// Returns `true` when operating in confidential gateway mode.
    #[must_use]
    pub const fn is_gateway(&self) -> bool {
        matches!(self, Self::Gateway { .. })
    }
}

/// Non-secret value binding work to the current authentication principal and continuity epoch.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AuthContinuitySnapshot {
    /// Authenticated gateway principal DID, or `None` when not active.
    pub did: Option<String>,
    /// Authentication mode represented by this snapshot.
    pub mode: AuthMode,
    /// Monotonically increasing generation bumped on every continuity mutation.
    pub generation: u64,
}

/// Result of executing an operation under exact authentication continuity verification.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AuthContinuityTransactionResult<T> {
    /// Continuity held throughout the operation and produced `T`.
    Performed(T),
    /// Continuity changed before or during execution; work was discarded.
    ContinuityChanged,
}

/// Opaque fingerprint of a gateway session binding. Never leaves the auth module verbatim.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GatewayAuthIdentity {
    /// Account DID bound to the gateway session.
    pub did: String,
    session_fingerprint: [u8; 32],
}

impl GatewayAuthIdentity {
    /// Hashes `session` using SHA-256 so the secret value never enters snapshots or logs.
    #[must_use]
    pub fn new(did: impl Into<String>, session: &str) -> Self {
        let fingerprint: [u8; 32] = Sha256::digest(session.as_bytes()).into();
        Self {
            did: did.into(),
            session_fingerprint: fingerprint,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
enum Observation {
    Unobserved,
    Invalidated,
    Observed(Option<GatewayAuthIdentity>),
}

/// State machine enforcing fail-closed continuity invalidation and `u64::MAX` exhaustion.
#[derive(Debug, Clone)]
pub struct AuthContinuityState {
    mode: AuthMode,
    generation: u64,
    is_exhausted: bool,
    observation: Observation,
}

impl AuthContinuityState {
    /// Initializes an unobserved state for `mode` at generation `0`.
    #[must_use]
    pub const fn new(mode: AuthMode) -> Self {
        Self {
            mode,
            generation: 0,
            is_exhausted: false,
            observation: Observation::Unobserved,
        }
    }

    /// Initializes state with a known generation and observed gateway identity (useful in tests).
    #[must_use]
    pub const fn with_observed(
        mode: AuthMode,
        generation: u64,
        observed_gateway_identity: Option<GatewayAuthIdentity>,
    ) -> Self {
        Self {
            mode,
            generation,
            is_exhausted: false,
            observation: Observation::Observed(observed_gateway_identity),
        }
    }

    /// Returns the active authentication mode.
    #[must_use]
    pub const fn mode(&self) -> &AuthMode {
        &self.mode
    }

    /// Returns the current continuity generation.
    #[must_use]
    pub const fn generation(&self) -> u64 {
        self.generation
    }

    /// Returns `true` if `u64::MAX` was reached and the principal was permanently cleared.
    #[must_use]
    pub const fn is_exhausted(&self) -> bool {
        self.is_exhausted
    }

    /// Builds a non-secret [`AuthContinuitySnapshot`] for the current state.
    #[must_use]
    pub fn snapshot(&self) -> AuthContinuitySnapshot {
        let did = if self.is_exhausted || !self.mode.is_gateway() {
            None
        } else if let Observation::Observed(Some(identity)) = &self.observation {
            Some(identity.did.clone())
        } else {
            None
        };
        AuthContinuitySnapshot {
            did,
            mode: self.mode.clone(),
            generation: self.generation,
        }
    }

    /// Invalidates continuity before an async mutation suspends.
    /// Reaching `u64::MAX` marks the state exhausted so generation numbers never wrap.
    pub fn invalidate(&mut self) {
        self.observation = Observation::Invalidated;
        if self.is_exhausted {
            return;
        }
        if let Some(next) = self.generation.checked_add(1) {
            self.generation = next;
        } else {
            self.is_exhausted = true;
        }
    }

    /// Commits a new authentication mode. Leaving gateway mode invalidates observation.
    pub fn commit_mode(&mut self, new_mode: AuthMode) {
        let is_gateway = new_mode.is_gateway();
        self.mode = new_mode;
        if !is_gateway {
            self.observation = Observation::Invalidated;
        }
    }

    /// Reconciles an observed gateway identity, bumping generation if an out-of-band change occurred.
    pub fn observe_gateway_identity(&mut self, identity: Option<GatewayAuthIdentity>) {
        if !self.mode.is_gateway() || self.is_exhausted {
            return;
        }
        match &self.observation {
            Observation::Unobserved | Observation::Invalidated => {
                self.observation = Observation::Observed(identity);
            }
            Observation::Observed(previous) if *previous != identity => {
                self.invalidate();
                if !self.is_exhausted {
                    self.observation = Observation::Observed(identity);
                }
            }
            Observation::Observed(_) => {}
        }
    }

    /// Returns `true` if observing `identity` would advance the continuity generation.
    #[must_use]
    pub fn would_change_when_observing_gateway_identity(
        &self,
        identity: Option<&GatewayAuthIdentity>,
    ) -> bool {
        if !self.mode.is_gateway() || self.is_exhausted {
            return false;
        }
        matches!(&self.observation, Observation::Observed(previous) if previous.as_ref() != identity)
    }
}
