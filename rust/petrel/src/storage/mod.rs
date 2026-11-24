//! Secret storage.
//!
//! Contract 11 of the Petrel Rust plan lives here and is frozen:
//! [`SecretStore`] and [`StoreError`].
//!
//! Lane E adds here (map: `maps/serviceauth-space-storage.md`, packages ST1
//! to ST3): an in-memory store, the typed session store on top of the trait,
//! the encrypted file store behind the `file-store` feature, and a
//! conformance suite every store must pass, including injected I/O errors.
//! OS keychains and `IndexedDB` belong to the embedder, which implements
//! this trait.
//!
//! The rule that matters most: **a failed read is an error, never "signed
//! out".** [`SecretStore::get`] returns `Ok(None)` only when the item is
//! known to be absent. Treating a locked keychain or an I/O error as absence
//! is how sessions get wiped.

use crate::rt::{BoxFuture, MaybeSend, MaybeSync};

/// A secret store operation failed.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[non_exhaustive]
pub enum StoreError {
    /// The store cannot be reached right now (locked, I/O error). The item
    /// may well exist; retry later.
    #[error("secret store unavailable: {0}")]
    Unavailable(String),
    /// The stored bytes could not be decrypted or parsed.
    #[error("stored item is corrupt: {0}")]
    Corrupt(String),
    /// Anything else.
    #[error("secret store error: {0}")]
    Other(String),
}

/// Keyed storage for secrets (tokens, DPoP keys, flow state).
///
/// Items live under a `namespace` (one per account, plus fixed ones for
/// in-flight flows) and a `key`. Stored as `dyn`, so methods return
/// [`BoxFuture`].
pub trait SecretStore: MaybeSend + MaybeSync {
    /// Reads an item. `Ok(None)` only when it is absent.
    fn get<'a>(
        &'a self,
        namespace: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, StoreError>>;

    /// Writes an item, replacing any existing one.
    fn put<'a>(
        &'a self,
        namespace: &'a str,
        key: &'a str,
        value: &'a [u8],
    ) -> BoxFuture<'a, Result<(), StoreError>>;

    /// Deletes an item. Deleting an absent item succeeds.
    fn delete<'a>(
        &'a self,
        namespace: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<(), StoreError>>;

    /// Reads and deletes an item in one step, so two callers cannot both
    /// obtain it. Used to consume single-use state (the OAuth `state`).
    fn take<'a>(
        &'a self,
        namespace: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, StoreError>>;

    /// Deletes every item in a namespace (sign-out).
    fn delete_namespace<'a>(&'a self, namespace: &'a str) -> BoxFuture<'a, Result<(), StoreError>>;
}
