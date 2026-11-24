use std::fmt;
#[cfg(target_arch = "wasm32")]
use std::rc::{Rc as ObserverRef, Weak as ObserverWeak};
#[cfg(not(target_arch = "wasm32"))]
use std::sync::{Arc as ObserverRef, Weak as ObserverWeak};
use std::sync::{Mutex, PoisonError};

use petrel_core::Did;

use crate::rt::{MaybeSend, MaybeSync};

/// A local authentication or credential-storage event.
#[derive(Clone, Debug, PartialEq, Eq)]
#[non_exhaustive]
pub enum AuthEvent {
    /// An operation that requires a signed-in account found no session.
    SessionMissing { did: Did },
    /// The authorization server rejected the account's refresh grant.
    RefreshTokenInvalid { did: Did },
    /// Local credentials for an account were cleared.
    Logout { did: Did },
    /// The persisted account selection changed.
    CurrentAccountChanged {
        previous: Option<Did>,
        current: Option<Did>,
    },
    /// A credential operation failed. Includes no token or backend error text.
    StorageFailure {
        operation: &'static str,
        did: Option<Did>,
    },
}

trait AuthObserver: Fn(&AuthEvent) + MaybeSend + MaybeSync {}
impl<T: Fn(&AuthEvent) + MaybeSend + MaybeSync> AuthObserver for T {}

/// Keeps an auth event observer registered until this handle is dropped.
#[must_use = "keep the subscription alive to receive events"]
pub struct AuthSubscription {
    _observer: ObserverRef<dyn AuthObserver>,
}

impl fmt::Debug for AuthSubscription {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("AuthSubscription")
            .finish_non_exhaustive()
    }
}

pub(super) type SharedAuthEvents = ObserverRef<AuthEvents>;

#[derive(Default)]
pub(super) struct AuthEvents {
    observers: Mutex<Vec<ObserverWeak<dyn AuthObserver>>>,
}

impl AuthEvents {
    pub(super) fn subscribe<F>(&self, observer: F) -> AuthSubscription
    where
        F: Fn(&AuthEvent) + MaybeSend + MaybeSync + 'static,
    {
        let observer: ObserverRef<dyn AuthObserver> = ObserverRef::new(observer);
        let mut observers = self
            .observers
            .lock()
            .unwrap_or_else(PoisonError::into_inner);
        observers.retain(|observer| observer.strong_count() != 0);
        observers.push(ObserverRef::downgrade(&observer));
        AuthSubscription {
            _observer: observer,
        }
    }

    pub(super) fn emit(&self, event: &AuthEvent) {
        let active = {
            let mut observers = self
                .observers
                .lock()
                .unwrap_or_else(PoisonError::into_inner);
            let mut active = Vec::new();
            observers.retain(|observer| {
                if let Some(observer) = observer.upgrade() {
                    active.push(observer);
                    true
                } else {
                    false
                }
            });
            active
        };
        for observer in active {
            observer(event);
        }
    }
}
