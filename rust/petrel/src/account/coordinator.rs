use std::{
    future::poll_fn,
    sync::{
        Mutex,
        atomic::{AtomicBool, Ordering},
    },
    task::{Poll, Waker},
};

use petrel_core::Did;

/// Errors raised during account-switch coordination.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum AccountSwitchError {
    /// Another account switch is already in progress.
    #[error("another account switch is already in progress")]
    SwitchInProgress,
    /// Failed to synchronize state across components.
    #[error("failed to synchronize account state: {0}")]
    FailedToSynchronizeState(String),
    /// Failed to load or update account metadata.
    #[error("failed to load account metadata: {0}")]
    FailedToLoadMetadata(String),
    /// Invalid DPoP key binding detected during switch.
    #[error("invalid DPoP key binding detected")]
    InvalidDPoP,
}

/// Single-flight coordinator serializing account switch transitions across async callers.
#[derive(Debug, Default)]
pub struct AccountSwitchCoordinator {
    in_progress: AtomicBool,
    waiters: Mutex<Vec<Waker>>,
}

impl AccountSwitchCoordinator {
    /// Creates a new coordinator with no active switch.
    #[must_use]
    pub const fn new() -> Self {
        Self {
            in_progress: AtomicBool::new(false),
            waiters: Mutex::new(Vec::new()),
        }
    }

    /// Returns `true` if an account switch is currently underway.
    #[must_use]
    pub fn is_account_switch_in_progress(&self) -> bool {
        self.in_progress.load(Ordering::SeqCst)
    }

    /// Acquires the switch slot or fails with [`AccountSwitchError::SwitchInProgress`].
    pub fn begin_account_switch(
        &self,
        _from_did: Option<&Did>,
        _to_did: &Did,
    ) -> Result<(), AccountSwitchError> {
        self.in_progress
            .compare_exchange(false, true, Ordering::SeqCst, Ordering::SeqCst)
            .map(|_| ())
            .map_err(|_| AccountSwitchError::SwitchInProgress)
    }

    /// Marks the active account switch complete and wakes all waiting tasks.
    pub fn complete_account_switch(&self) {
        self.in_progress.store(false, Ordering::SeqCst);
        let waiters = {
            let mut guard = self
                .waiters
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner);
            std::mem::take(&mut *guard)
        };
        for waker in waiters {
            waker.wake();
        }
    }

    /// Releases the switch lock after an error, allowing callers to proceed.
    pub fn handle_switch_error(&self, _error: &dyn std::fmt::Display) {
        self.complete_account_switch();
    }

    /// Suspends until any active account switch completes.
    pub async fn wait_for_switch_to_complete(&self) {
        poll_fn(|cx| {
            if !self.in_progress.load(Ordering::SeqCst) {
                return Poll::Ready(());
            }
            let mut guard = self
                .waiters
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner);
            if !self.in_progress.load(Ordering::SeqCst) {
                return Poll::Ready(());
            }
            guard.push(cx.waker().clone());
            Poll::Pending
        })
        .await;
    }
}
