//! Multi-account catalog management and single-flight account switch coordination.

mod coordinator;

use std::{
    collections::BTreeMap,
    fmt,
    sync::{
        Arc,
        atomic::{AtomicBool, AtomicU64, Ordering},
    },
};

use async_lock::Mutex;
use petrel_core::Did;

use crate::{
    oauth::Account,
    rt::{BoxFuture, MaybeSend, MaybeSync},
    storage::{SessionStore, StoreError},
};

pub use coordinator::{AccountSwitchCoordinator, AccountSwitchError};

/// Callback invoked before an account's local credentials are deleted so the caller
/// (typically the auth layer) can revoke its remote session while tokens are still present.
pub trait AccountRemovalHandler: MaybeSend + MaybeSync {
    /// Revokes remote session state for `did` before local removal proceeds.
    fn on_remove<'a>(&'a self, did: &'a Did) -> BoxFuture<'a, ()>;
}

impl<F> AccountRemovalHandler for F
where
    F: for<'a> Fn(&'a Did) -> BoxFuture<'a, ()> + MaybeSend + MaybeSync,
{
    fn on_remove<'a>(&'a self, did: &'a Did) -> BoxFuture<'a, ()> {
        (self)(did)
    }
}

/// Errors produced by [`AccountManager`].
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum AccountError {
    /// Underlying secret or session store error.
    #[error(transparent)]
    Store(#[from] StoreError),
    /// Requested DID does not exist in the account catalog.
    #[error("account not found: {0}")]
    NotFound(Did),
    /// Account metadata is invalid.
    #[error("invalid account metadata")]
    InvalidAccount,
}

/// Manages stored accounts, active account selection, and removal lifecycle.
pub struct AccountManager {
    storage: SessionStore,
    cache: Mutex<BTreeMap<Did, Account>>,
    auto_switch_on_removal: AtomicBool,
    selection_epoch: AtomicU64,
    removal_handler: std::sync::Mutex<Option<Arc<dyn AccountRemovalHandler>>>,
}

impl fmt::Debug for AccountManager {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("AccountManager")
            .field("namespace", &self.storage.namespace())
            .field(
                "auto_switch_on_removal",
                &self.auto_switch_on_removal.load(Ordering::Relaxed),
            )
            .finish_non_exhaustive()
    }
}

impl AccountManager {
    /// Creates an [`AccountManager`] backed by `storage`.
    #[must_use]
    pub fn new(storage: SessionStore) -> Self {
        Self {
            storage,
            cache: Mutex::new(BTreeMap::new()),
            auto_switch_on_removal: AtomicBool::new(true),
            selection_epoch: AtomicU64::new(0),
            removal_handler: std::sync::Mutex::new(None),
        }
    }

    /// Monotonic counter incremented whenever active account selection is updated or cleared.
    #[must_use]
    pub fn selection_epoch(&self) -> u64 {
        self.selection_epoch.load(Ordering::Acquire)
    }

    /// Returns the underlying [`SessionStore`].
    #[must_use]
    pub const fn storage(&self) -> &SessionStore {
        &self.storage
    }

    /// Configures whether removing the current account automatically switches to the next
    /// remaining account (`true` by default).
    pub fn set_auto_switch_on_removal(&self, enabled: bool) {
        self.auto_switch_on_removal
            .store(enabled, Ordering::Relaxed);
    }

    /// Installs a hook invoked before [`Self::remove_account`] deletes local credentials.
    pub fn set_account_removal_handler(&self, handler: Option<Arc<dyn AccountRemovalHandler>>) {
        if let Ok(mut guard) = self.removal_handler.lock() {
            *guard = handler;
        }
    }

    /// Invalidates the in-memory account cache for `did` (or all accounts when `None`).
    pub async fn invalidate_cache(&self, did: Option<&Did>) {
        let mut cache = self.cache.lock().await;
        match did {
            Some(did) => {
                cache.remove(did);
            }
            None => cache.clear(),
        }
    }

    /// Adds or updates an account in the catalog; selects it if no current account is active.
    pub async fn add_account(&self, account: &Account) -> Result<(), AccountError> {
        self.storage.save_account(account).await?;
        self.cache
            .lock()
            .await
            .insert(account.did.clone(), account.clone());
        if self.storage.get_current_did().await?.is_none() {
            self.set_current_account(&account.did).await?;
        }
        Ok(())
    }

    /// Updates an already-registered account's metadata without altering current selection.
    /// Returns `Ok(false)` if the account no longer exists in storage.
    pub async fn update_account(&self, account: &Account) -> Result<bool, AccountError> {
        if self.storage.get_account(&account.did).await?.is_none() {
            self.cache.lock().await.remove(&account.did);
            return Ok(false);
        }
        self.storage.save_account(account).await?;
        self.cache
            .lock()
            .await
            .insert(account.did.clone(), account.clone());
        Ok(true)
    }

    /// Refreshes the in-memory cache for `did` from durable storage.
    pub async fn update_account_from_storage(&self, did: &Did) -> Result<(), AccountError> {
        let account = self.storage.get_account(did).await?;
        let mut cache = self.cache.lock().await;
        match account {
            Some(account) => {
                cache.insert(did.clone(), account);
            }
            None => {
                cache.remove(did);
            }
        }
        Ok(())
    }

    /// Returns an account by DID from cache or durable storage.
    pub async fn get_account(&self, did: &Did) -> Result<Option<Account>, AccountError> {
        if let Some(cached) = self.cache.lock().await.get(did).cloned() {
            return Ok(Some(cached));
        }
        let loaded = self.storage.get_account(did).await?;
        if let Some(ref account) = loaded {
            self.cache.lock().await.insert(did.clone(), account.clone());
        }
        Ok(loaded)
    }

    /// Sets `did` as the active account.
    pub async fn set_current_account(&self, did: &Did) -> Result<(), AccountError> {
        let Some(account) = self.storage.get_account(did).await? else {
            return Err(AccountError::NotFound(did.clone()));
        };
        if account.did.as_str().is_empty() {
            return Err(AccountError::InvalidAccount);
        }
        self.cache.lock().await.insert(did.clone(), account);
        self.storage.save_current_did(did).await?;
        self.selection_epoch.fetch_add(1, Ordering::AcqRel);
        Ok(())
    }

    /// Returns the currently selected DID, if any.
    pub async fn current_did(&self) -> Result<Option<Did>, AccountError> {
        Ok(self.storage.get_current_did().await?)
    }

    /// Returns the currently selected account, if any.
    pub async fn get_current_account(&self) -> Result<Option<Account>, AccountError> {
        let Some(did) = self.storage.get_current_did().await? else {
            return Ok(None);
        };
        self.get_account(&did).await
    }

    /// Clears the current account selection without deleting stored accounts or credentials.
    pub async fn clear_current_account(&self) -> Result<(), AccountError> {
        self.storage.delete_current_did().await?;
        self.selection_epoch.fetch_add(1, Ordering::AcqRel);
        Ok(())
    }

    /// Lists all discoverable accounts in deterministic DID order.
    pub async fn list_accounts(&self) -> Result<Vec<Account>, AccountError> {
        let dids = self.storage.list_account_dids().await?;
        let mut accounts = Vec::with_capacity(dids.len());
        for did in dids {
            if let Some(account) = self.get_account(&did).await? {
                accounts.push(account);
            }
        }
        Ok(accounts)
    }

    /// Removes `did`, invoking any registered removal handler first while credentials still exist,
    /// then clearing session/DPoP/account data and optionally auto-switching to another account.
    pub async fn remove_account(&self, did: &Did) -> Result<(), AccountError> {
        let handler = self
            .removal_handler
            .lock()
            .ok()
            .and_then(|guard| guard.clone());
        if let Some(handler) = handler {
            handler.on_remove(did).await;
        }

        let was_current = self.storage.get_current_did().await?.as_ref() == Some(did);
        self.storage.delete_account(did).await?;
        self.cache.lock().await.remove(did);

        let _ = self.storage.delete_session(did).await;
        let _ = self.storage.delete_pending_session(did).await;
        let _ = self.storage.delete_dpop_key(did.as_str()).await;
        let _ = self
            .storage
            .secrets()
            .delete(
                self.storage.namespace(),
                &format!("legacySession.{}", did.as_str()),
            )
            .await;

        if was_current {
            let remaining = self.storage.list_account_dids().await?;
            if self.auto_switch_on_removal.load(Ordering::Relaxed)
                && let Some(first) = remaining.first()
                && self.set_current_account(first).await.is_ok()
            {
                // `set_current_account` already persisted the new DID and bumped `selection_epoch`.
            } else {
                self.storage.delete_current_did().await?;
                self.selection_epoch.fetch_add(1, Ordering::AcqRel);
            }
        }
        Ok(())
    }
}
