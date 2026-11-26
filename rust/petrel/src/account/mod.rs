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
        let selected = self
            .storage
            .save_account_selecting_if_unset(account)
            .await?;
        self.cache
            .lock()
            .await
            .insert(account.did.clone(), account.clone());
        if selected {
            self.selection_epoch.fetch_add(1, Ordering::AcqRel);
        }
        Ok(())
    }

    /// Updates an already-registered account's metadata without altering current selection.
    /// Returns `Ok(false)` if the account no longer exists in storage.
    pub async fn update_account(&self, account: &Account) -> Result<bool, AccountError> {
        if !self.storage.update_account_if_exists(account).await? {
            self.cache.lock().await.remove(&account.did);
            return Ok(false);
        }
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
        self.storage.save_current_did(did).await?;
        self.cache.lock().await.insert(did.clone(), account);
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

    /// Clears the current account selection only if it still points to `did`,
    /// returning `true` when `did` was cleared (or nothing was selected) and `false`
    /// if another account is now active.
    pub async fn clear_current_account_if_selected(&self, did: &Did) -> Result<bool, AccountError> {
        let cleared = self
            .storage
            .clear_current_did_if_selected_returning_cleared(did)
            .await?;
        if !cleared {
            return Ok(false);
        }
        self.selection_epoch.fetch_add(1, Ordering::AcqRel);
        Ok(true)
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
    /// then clearing session/DPoP/account data and conditionally auto-switching to another account
    /// atomically in the catalog only if `did` is still the active selection.
    pub async fn remove_account(&self, did: &Did) -> Result<(), AccountError> {
        let handler = self
            .removal_handler
            .lock()
            .ok()
            .and_then(|guard| guard.clone());
        if let Some(handler) = handler {
            handler.on_remove(did).await;
        }

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

        let auto_switch = self.auto_switch_on_removal.load(Ordering::Relaxed);
        let (previous, current) = self
            .storage
            .remove_account_and_update_selection(did, auto_switch)
            .await?;
        self.cache.lock().await.remove(did);
        if previous != current {
            self.selection_epoch.fetch_add(1, Ordering::AcqRel);
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use std::sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    };

    use futures_util::future::join;

    use super::*;
    use crate::storage::{MemorySecretStore, SecretStore};

    const ALICE: &str = "did:plc:aliceaaaaaaaaaaaaaaaaa";
    const BOB: &str = "did:plc:bobbbbbbbbbbbbbbbbbbbb";
    const CAROL: &str = "did:plc:carolccccccccccccccccc";

    fn account(did: &str) -> Account {
        Account {
            did: did.parse().expect("valid did"),
            handle: None,
            pds: "https://pds.example".to_owned(),
            authorization_server: None,
            expected_issuer: None,
        }
    }

    struct AsyncBarrier {
        opened: AtomicBool,
        waiter: std::sync::Mutex<Option<std::task::Waker>>,
    }

    impl AsyncBarrier {
        fn new() -> Self {
            Self {
                opened: AtomicBool::new(false),
                waiter: std::sync::Mutex::new(None),
            }
        }

        fn open(&self) {
            self.opened.store(true, Ordering::Release);
            if let Some(waker) = self.waiter.lock().unwrap().take() {
                waker.wake();
            }
        }

        async fn wait(&self) {
            std::future::poll_fn(|cx| {
                if self.opened.load(Ordering::Acquire) {
                    return std::task::Poll::Ready(());
                }
                *self.waiter.lock().unwrap() = Some(cx.waker().clone());
                if self.opened.load(Ordering::Acquire) {
                    std::task::Poll::Ready(())
                } else {
                    std::task::Poll::Pending
                }
            })
            .await;
        }
    }

    struct PausedDeleteSecretStore {
        inner: Arc<MemorySecretStore>,
        pause_key: String,
        armed: AtomicBool,
        entered: Arc<AsyncBarrier>,
        release: Arc<AsyncBarrier>,
    }

    impl PausedDeleteSecretStore {
        fn new(pause_key: String) -> (Self, Arc<AsyncBarrier>, Arc<AsyncBarrier>) {
            let entered = Arc::new(AsyncBarrier::new());
            let release = Arc::new(AsyncBarrier::new());
            (
                Self {
                    inner: Arc::new(MemorySecretStore::new()),
                    pause_key,
                    armed: AtomicBool::new(false),
                    entered: Arc::clone(&entered),
                    release: Arc::clone(&release),
                },
                entered,
                release,
            )
        }

        fn arm(&self) {
            self.armed.store(true, Ordering::Release);
        }
    }

    impl SecretStore for PausedDeleteSecretStore {
        fn get<'a>(
            &'a self,
            namespace: &'a str,
            key: &'a str,
        ) -> BoxFuture<'a, Result<Option<Vec<u8>>, StoreError>> {
            self.inner.get(namespace, key)
        }

        fn put<'a>(
            &'a self,
            namespace: &'a str,
            key: &'a str,
            value: &'a [u8],
        ) -> BoxFuture<'a, Result<(), StoreError>> {
            self.inner.put(namespace, key, value)
        }

        fn delete<'a>(
            &'a self,
            namespace: &'a str,
            key: &'a str,
        ) -> BoxFuture<'a, Result<(), StoreError>> {
            Box::pin(async move {
                if key == self.pause_key && self.armed.swap(false, Ordering::AcqRel) {
                    self.entered.open();
                    self.release.wait().await;
                }
                self.inner.delete(namespace, key).await
            })
        }

        fn take<'a>(
            &'a self,
            namespace: &'a str,
            key: &'a str,
        ) -> BoxFuture<'a, Result<Option<Vec<u8>>, StoreError>> {
            self.inner.take(namespace, key)
        }

        fn delete_namespace<'a>(
            &'a self,
            namespace: &'a str,
        ) -> BoxFuture<'a, Result<(), StoreError>> {
            self.inner.delete_namespace(namespace)
        }

        fn compare_and_swap<'a>(
            &'a self,
            namespace: &'a str,
            key: &'a str,
            expected: Option<&'a [u8]>,
            new: Option<&'a [u8]>,
        ) -> BoxFuture<'a, Result<bool, StoreError>> {
            self.inner.compare_and_swap(namespace, key, expected, new)
        }
    }

    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    async fn run_switch_during_removal_case(auto_switch: bool) {
        let alice: Did = ALICE.parse().unwrap();
        let _bob: Did = BOB.parse().unwrap();
        let carol: Did = CAROL.parse().unwrap();

        let (backend, entered, release) =
            PausedDeleteSecretStore::new(format!("legacySession.{ALICE}"));
        let backend = Arc::new(backend);
        let store = SessionStore::new(backend.clone(), "acct-race").unwrap();
        let mgr = Arc::new(AccountManager::new(store));
        mgr.set_auto_switch_on_removal(auto_switch);

        // `bob` sorts ahead of `carol`, so a naive fallback would replace `carol` with `bob`
        // when `auto_switch == true`, or clear `carol` when `auto_switch == false`.
        mgr.add_account(&account(ALICE)).await.unwrap();
        mgr.add_account(&account(BOB)).await.unwrap();
        mgr.add_account(&account(CAROL)).await.unwrap();
        assert_eq!(mgr.current_did().await.unwrap(), Some(alice.clone()));

        backend.arm();
        let epoch_before_remove = mgr.selection_epoch();
        let remove_fut = mgr.remove_account(&alice);
        let switch_fut = async {
            entered.wait().await;
            mgr.set_current_account(&carol).await.unwrap();
            let epoch_after_switch = mgr.selection_epoch();
            release.open();
            epoch_after_switch
        };
        let (remove_res, epoch_after_switch) = join(remove_fut, switch_fut).await;
        remove_res.unwrap();

        assert!(epoch_after_switch > epoch_before_remove);
        assert_eq!(mgr.current_did().await.unwrap(), Some(carol));
        assert_eq!(mgr.selection_epoch(), epoch_after_switch);
        assert!(mgr.get_account(&alice).await.unwrap().is_none());
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
    async fn concurrent_switch_during_account_removal_preserves_new_selection() {
        run_switch_during_removal_case(true).await;
        run_switch_during_removal_case(false).await;
    }

    struct SwitchOnRemoveHandler {
        mgr: Arc<AccountManager>,
        target: Did,
    }

    impl AccountRemovalHandler for SwitchOnRemoveHandler {
        fn on_remove<'a>(&'a self, _did: &'a Did) -> BoxFuture<'a, ()> {
            Box::pin(async move {
                self.mgr.set_current_account(&self.target).await.unwrap();
            })
        }
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    async fn removal_handler_switch_and_atomic_fallback_and_update_guard() {
        let alice: Did = ALICE.parse().unwrap();
        let bob: Did = BOB.parse().unwrap();
        let carol: Did = CAROL.parse().unwrap();

        let store = SessionStore::new(Arc::new(MemorySecretStore::new()), "acct-handler").unwrap();
        let mgr = Arc::new(AccountManager::new(store));
        mgr.add_account(&account(ALICE)).await.unwrap();
        mgr.add_account(&account(BOB)).await.unwrap();
        mgr.add_account(&account(CAROL)).await.unwrap();

        // Switch inside `AccountRemovalHandler::on_remove` must also be preserved.
        mgr.set_account_removal_handler(Some(Arc::new(SwitchOnRemoveHandler {
            mgr: Arc::clone(&mgr),
            target: carol.clone(),
        })));
        mgr.remove_account(&alice).await.unwrap();
        mgr.set_account_removal_handler(None);
        assert_eq!(mgr.current_did().await.unwrap(), Some(carol.clone()));

        // Without concurrent switch, removing active `carol` atomically falls back to `bob`.
        let epoch_before = mgr.selection_epoch();
        mgr.remove_account(&carol).await.unwrap();
        assert_eq!(mgr.current_did().await.unwrap(), Some(bob.clone()));
        assert_eq!(mgr.selection_epoch(), epoch_before + 1);

        // Removed account cannot be resurrected by `update_account`.
        assert!(!mgr.update_account(&account(CAROL)).await.unwrap());
        assert!(mgr.get_account(&carol).await.unwrap().is_none());
    }
}
