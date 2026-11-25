//! Circuit breaker preventing cascading refresh failures per DID.

use std::{collections::HashMap, time::Duration};

use async_lock::Mutex;
use petrel_core::Did;
use web_time::Instant;

/// Failure classification driving circuit-breaker weight and backoff bounds.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum RefreshFailureKind {
    /// Recoverable `use_dpop_nonce` rotation; never opens the breaker.
    NonceRecoverable,
    /// Connectivity or timeout error.
    Network,
    /// 5xx or unexpected server error.
    Server,
    /// Refresh token revoked or invalid grant.
    InvalidGrant,
    /// DPoP proof rejected.
    InvalidDPoPProof,
    /// OAuth metadata discovery unreachable.
    MetadataUnavailable,
    /// Other failure.
    Other,
}

/// Circuit state for one DID.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum CircuitState {
    /// Normal operation; refreshes proceed.
    Closed,
    /// Threshold exceeded; refreshes blocked until backoff elapses.
    Open,
    /// One probe refresh permitted to test recovery.
    HalfOpen,
}

#[derive(Debug, Clone)]
struct FailureInfo {
    consecutive_failures: u32,
    last_failure_time: Option<Instant>,
    state: CircuitState,
    half_open_test_in_progress: bool,
    backoff_exponent: u32,
    last_failure_kind: Option<RefreshFailureKind>,
}

impl Default for FailureInfo {
    fn default() -> Self {
        Self {
            consecutive_failures: 0,
            last_failure_time: None,
            state: CircuitState::Closed,
            half_open_test_in_progress: false,
            backoff_exponent: 0,
            last_failure_kind: None,
        }
    }
}

/// Per-DID exponential-backoff circuit breaker for token refresh attempts.
#[derive(Debug)]
pub struct RefreshCircuitBreaker {
    max_consecutive_failures: u32,
    reset_interval: Duration,
    tracking: Mutex<HashMap<Did, FailureInfo>>,
}

impl Default for RefreshCircuitBreaker {
    fn default() -> Self {
        Self::new()
    }
}

impl RefreshCircuitBreaker {
    /// Creates a circuit breaker with Swift parity defaults (3 failures, 300s reset base).
    #[must_use]
    pub fn new() -> Self {
        Self {
            max_consecutive_failures: 3,
            reset_interval: Duration::from_secs(300),
            tracking: Mutex::new(HashMap::new()),
        }
    }

    /// Returns `true` if a refresh may be attempted for `did`.
    pub async fn can_attempt_refresh(&self, did: &Did) -> bool {
        let mut tracking = self.tracking.lock().await;
        let info = tracking.entry(did.clone()).or_default();
        match info.state {
            CircuitState::Closed => true,
            CircuitState::Open => {
                if let Some(last_failure) = info.last_failure_time {
                    let backoff = calculate_backoff(info, self.reset_interval);
                    if last_failure.elapsed() >= backoff {
                        info.state = CircuitState::HalfOpen;
                        info.half_open_test_in_progress = false;
                        return true;
                    }
                }
                false
            }
            CircuitState::HalfOpen => {
                if info.half_open_test_in_progress {
                    false
                } else {
                    info.half_open_test_in_progress = true;
                    true
                }
            }
        }
    }

    /// Records a successful refresh, closing the circuit and resetting backoff.
    pub async fn record_success(&self, did: &Did) {
        let mut tracking = self.tracking.lock().await;
        if let Some(info) = tracking.get_mut(did) {
            *info = FailureInfo::default();
        }
    }

    /// Records a failed refresh with failure classification.
    pub async fn record_failure(&self, did: &Did, kind: RefreshFailureKind) {
        let mut tracking = self.tracking.lock().await;
        let info = tracking.entry(did.clone()).or_default();
        match kind {
            RefreshFailureKind::NonceRecoverable => {}
            RefreshFailureKind::InvalidGrant | RefreshFailureKind::InvalidDPoPProof => {
                info.consecutive_failures += 1;
                info.backoff_exponent = (info.backoff_exponent + 1).min(6);
            }
            RefreshFailureKind::MetadataUnavailable => {
                info.consecutive_failures += 1;
                info.backoff_exponent = (info.backoff_exponent + 1).min(8);
            }
            RefreshFailureKind::Network
            | RefreshFailureKind::Server
            | RefreshFailureKind::Other => {
                info.consecutive_failures += 1;
                info.backoff_exponent = (info.backoff_exponent + 1).min(5);
            }
        }
        info.last_failure_time = Some(Instant::now());
        info.last_failure_kind = Some(kind);

        match info.state {
            CircuitState::Closed => {
                if info.consecutive_failures >= self.max_consecutive_failures {
                    info.state = CircuitState::Open;
                }
            }
            CircuitState::HalfOpen => {
                info.state = CircuitState::Open;
                info.half_open_test_in_progress = false;
            }
            CircuitState::Open => {}
        }
    }

    /// Returns the current circuit state for `did`.
    pub async fn state(&self, did: &Did) -> CircuitState {
        self.tracking
            .lock()
            .await
            .get(did)
            .map_or(CircuitState::Closed, |info| info.state)
    }

    /// Clears circuit-breaker failure state for `did`.
    pub async fn reset(&self, did: &Did) {
        self.tracking.lock().await.remove(did);
    }

    /// Transitions an open circuit to `HalfOpen` for an immediate recovery probe.
    pub async fn force_half_open(&self, did: &Did) -> bool {
        let mut tracking = self.tracking.lock().await;
        let Some(info) = tracking.get_mut(did) else {
            return false;
        };
        if info.state != CircuitState::Open {
            return false;
        }
        info.state = CircuitState::HalfOpen;
        info.half_open_test_in_progress = false;
        true
    }

    /// Resets circuit-breaker state for all DIDs.
    pub async fn reset_all(&self) {
        self.tracking.lock().await.clear();
    }
}

fn calculate_backoff(info: &FailureInfo, default_reset: Duration) -> Duration {
    let base_secs = match info.last_failure_kind {
        Some(RefreshFailureKind::MetadataUnavailable) => 60.0,
        Some(RefreshFailureKind::InvalidGrant | RefreshFailureKind::InvalidDPoPProof) => 300.0,
        Some(RefreshFailureKind::Network | RefreshFailureKind::Server) => 30.0,
        _ => default_reset.as_secs_f64(),
    };
    let max_secs = match info.last_failure_kind {
        Some(RefreshFailureKind::MetadataUnavailable) => 3600.0,
        Some(RefreshFailureKind::InvalidGrant | RefreshFailureKind::InvalidDPoPProof) => 7200.0,
        _ => 1800.0,
    };
    let shift = i32::try_from(info.backoff_exponent.min(6)).unwrap_or(6);
    let exp = base_secs * 2.0_f64.powi(shift);
    let mut random_bytes = [0_u8; 2];
    let jitter = getrandom::getrandom(&mut random_bytes).map_or(1.0, |()| {
        let frac = f64::from(u16::from_ne_bytes(random_bytes)) / f64::from(u16::MAX);
        0.75 + 0.5 * frac
    });
    Duration::from_secs_f64((exp * jitter).min(max_secs))
}
