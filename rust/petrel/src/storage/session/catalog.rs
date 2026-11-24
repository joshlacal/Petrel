use std::collections::BTreeMap;

use petrel_core::Did;
use serde::{Deserialize, Serialize};
use zeroize::Zeroizing;

use crate::{
    oauth::Account,
    storage::{AuthEvent, StoreError},
};

use super::{SESSION, SessionStore, decode, encode, payload};

const CATALOG: &str = "accountDIDs";

#[derive(Default, Deserialize, Serialize)]
struct AccountCatalog {
    accounts: BTreeMap<Did, AccountEntry>,
    current: Option<Did>,
}

#[derive(Deserialize, Serialize)]
enum AccountEntry {
    /// Explicit profiles remain discoverable without a session.
    Profile(Box<Account>),
    /// Visible through its v1 session bundle once that bundle is published.
    Session,
}

type SelectionChange = (Option<Did>, Option<Did>);

impl SessionStore {
    /// Saves standalone account metadata without replacing credentials.
    ///
    /// Explicitly saved metadata is used by the catalog. Token use continues
    /// to use the account and authorization binding in the session bundle.
    pub async fn save_account(&self, account: &Account) -> Result<(), StoreError> {
        let result = self
            .edit_catalog(|catalog| {
                catalog.accounts.insert(
                    account.did.clone(),
                    AccountEntry::Profile(Box::new(account.clone())),
                );
                Ok(())
            })
            .await
            .map(|_| ());
        self.report_storage_result(Some(&account.did), "save account", result)
    }

    /// Loads a catalog account, resolving session-backed entries by DID.
    pub async fn get_account(&self, did: &Did) -> Result<Option<Account>, StoreError> {
        let result = async {
            let mut catalog = self.read_catalog().await?;
            self.resolve_account(did, catalog.accounts.remove(did))
                .await
        }
        .await;
        self.report_storage_result(Some(did), "read account", result)
    }

    /// Removes account discovery and clears its selection in the same write.
    ///
    /// Credential deletion is a separate operation. A session remains
    /// addressable by its DID until it is explicitly deleted.
    pub async fn delete_account(&self, did: &Did) -> Result<(), StoreError> {
        let result = self
            .edit_catalog(|catalog| {
                catalog.accounts.remove(did);
                if catalog.current.as_ref() == Some(did) {
                    catalog.current = None;
                }
                Ok(())
            })
            .await;
        let selection = self.report_storage_result(Some(did), "delete account", result)?;
        self.emit_selection_change(selection);
        Ok(())
    }

    /// Lists distinct, discoverable account DIDs in lexical order.
    ///
    /// A save registers the DID before publishing a session. An interrupted
    /// save can leave a registration with no session, which is hidden.
    /// Older session bundles without an index remain readable by DID.
    /// Saving one through this store registers it for discovery.
    pub async fn list_account_dids(&self) -> Result<Vec<Did>, StoreError> {
        let result = async {
            let catalog = self.read_catalog().await?;
            let mut dids = Vec::with_capacity(catalog.accounts.len());
            for (did, account) in catalog.accounts {
                if self.resolve_account(&did, Some(account)).await?.is_some() {
                    dids.push(did);
                }
            }
            Ok(dids)
        }
        .await;
        self.report_storage_result(None, "list accounts", result)
    }

    /// Selects an account that is currently discoverable in this namespace.
    pub async fn save_current_did(&self, did: &Did) -> Result<(), StoreError> {
        if self.get_account(did).await?.is_none() {
            return Err(StoreError::UnknownAccount);
        }
        let result = self
            .edit_catalog(|catalog| {
                if !catalog.accounts.contains_key(did) {
                    return Err(StoreError::UnknownAccount);
                }
                catalog.current = Some(did.clone());
                Ok(())
            })
            .await;
        let selection = self.report_storage_result(Some(did), "save current account", result)?;
        self.emit_selection_change(selection);
        Ok(())
    }

    /// Returns the selected DID when its catalog account is discoverable.
    pub async fn get_current_did(&self) -> Result<Option<Did>, StoreError> {
        let result = async {
            let mut catalog = self.read_catalog().await?;
            let Some(did) = catalog.current.take() else {
                return Ok(None);
            };
            let entry = catalog.accounts.remove(&did);
            Ok(self.resolve_account(&did, entry).await?.map(|_| did))
        }
        .await;
        self.report_storage_result(None, "read current account", result)
    }

    /// Clears the current selection if present.
    pub async fn delete_current_did(&self) -> Result<(), StoreError> {
        let result = self
            .edit_catalog(|catalog| {
                catalog.current = None;
                Ok(())
            })
            .await;
        let selection = self.report_storage_result(None, "clear current account", result)?;
        self.emit_selection_change(selection);
        Ok(())
    }

    pub(crate) async fn clear_current_did_if_selected(&self, did: &Did) -> Result<(), StoreError> {
        let result = self
            .edit_catalog(|catalog| {
                if catalog.current.as_ref() == Some(did) {
                    catalog.current = None;
                }
                Ok(())
            })
            .await;
        let selection = self.report_storage_result(Some(did), "clear current account", result)?;
        self.emit_selection_change(selection);
        Ok(())
    }

    pub(super) async fn register_session_account(&self, did: &Did) -> Result<(), StoreError> {
        self.edit_catalog(|catalog| {
            catalog
                .accounts
                .entry(did.clone())
                .or_insert(AccountEntry::Session);
            Ok(())
        })
        .await
        .map(|_| ())
    }

    async fn resolve_account(
        &self,
        did: &Did,
        entry: Option<AccountEntry>,
    ) -> Result<Option<Account>, StoreError> {
        match entry {
            Some(AccountEntry::Profile(account)) => Ok(Some(*account)),
            Some(AccountEntry::Session) => Ok(self
                .get_record(SESSION, did)
                .await?
                .map(|record| record.account)),
            None => Ok(None),
        }
    }

    async fn read_catalog(&self) -> Result<AccountCatalog, StoreError> {
        let raw = self
            .secrets
            .get(&self.namespace, CATALOG)
            .await?
            .map(Zeroizing::new);
        decode_catalog(raw.as_ref().map(|bytes| bytes.as_slice()))
    }

    async fn edit_catalog(
        &self,
        edit: impl Fn(&mut AccountCatalog) -> Result<(), StoreError>,
    ) -> Result<SelectionChange, StoreError> {
        // This mutex protects clones even if the backend has no CAS.
        // CAS also covers independent clients and native processes.
        let _guard = self.catalog_lock.lock().await;
        loop {
            let raw = self
                .secrets
                .get(&self.namespace, CATALOG)
                .await?
                .map(Zeroizing::new);
            let expected = raw.as_ref().map(|bytes| bytes.as_slice());
            let mut catalog = decode_catalog(expected)?;
            let previous = catalog.current.clone();
            edit(&mut catalog)?;
            let updated = encode(&catalog)?;
            let change = (previous, catalog.current);
            if expected == Some(updated.as_slice()) {
                return Ok(change);
            }
            match self
                .secrets
                .compare_and_swap(&self.namespace, CATALOG, expected, Some(&updated))
                .await
            {
                Ok(true) => return Ok(change),
                Ok(false) => continue,
                Err(StoreError::Unsupported) => {
                    self.secrets.put(&self.namespace, CATALOG, &updated).await?;
                    return Ok(change);
                }
                Err(error) => return Err(error),
            }
        }
    }

    fn emit_selection_change(&self, (previous, current): SelectionChange) {
        if previous != current {
            self.emit_auth_event(AuthEvent::CurrentAccountChanged { previous, current });
        }
    }
}

fn decode_catalog(bytes: Option<&[u8]>) -> Result<AccountCatalog, StoreError> {
    let Some(bytes) = bytes else {
        return Ok(AccountCatalog::default());
    };
    let catalog: AccountCatalog = decode(payload(bytes)?)?;
    let bad_account = catalog
        .accounts
        .iter()
        .any(|(did, entry)| matches!(entry, AccountEntry::Profile(account) if account.did != *did));
    let bad_selection = catalog
        .current
        .as_ref()
        .is_some_and(|did| !catalog.accounts.contains_key(did));
    if bad_account || bad_selection {
        return Err(StoreError::Corrupt("inconsistent account catalog".into()));
    }
    Ok(catalog)
}
