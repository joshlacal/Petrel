use std::collections::HashMap;
use std::fmt;
use std::sync::{Arc, Mutex};

use web_sys::CryptoKey;

use super::DpopKeyStore;
use crate::crypto::{DpopSigner, EcPublicJwk, WebCryptoDpopSigner};
use crate::rt::BoxFuture;
use crate::storage::StoreError;

/// Structured-clone storage backend for opaque browser WebCrypto DPoP key pairs.
///
/// Browser embedders (for example using IndexedDB) implement this trait so
/// non-extractable [`CryptoKey`] private handles can be persisted across page
/// reloads without exporting raw private key bytes into [`crate::storage::SecretStore`].
pub trait WebCryptoKeyStorage {
    /// Persists an opaque non-extractable [`CryptoKey`] alongside its public JWK.
    fn save_key<'a>(
        &'a self,
        id: &'a str,
        key: CryptoKey,
        jwk: EcPublicJwk,
    ) -> BoxFuture<'a, Result<(), StoreError>>;

    /// Loads a persisted key handle and its bound public JWK, if present.
    fn load_key<'a>(
        &'a self,
        id: &'a str,
    ) -> BoxFuture<'a, Result<Option<(CryptoKey, EcPublicJwk)>, StoreError>>;

    /// Deletes a persisted key entry. Absent entries succeed.
    fn delete_key<'a>(&'a self, id: &'a str) -> BoxFuture<'a, Result<(), StoreError>>;
}

/// [`DpopKeyStore`] backed by browser WebCrypto (`CryptoKey`) handles.
///
/// Private key material stays inside the browser's non-extractable WebCrypto
/// keystore and is never written as raw scalar bytes to [`crate::storage::SecretStore`].
pub struct WebCryptoKeyStore {
    storage: Arc<dyn WebCryptoKeyStorage>,
}

impl fmt::Debug for WebCryptoKeyStore {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("WebCryptoKeyStore").finish_non_exhaustive()
    }
}

impl WebCryptoKeyStore {
    /// Creates a WebCrypto-backed DPoP key store using the given handle vault.
    pub fn new(storage: Arc<dyn WebCryptoKeyStorage>) -> Self {
        Self { storage }
    }

    /// Creates a shared [`DpopKeyStore`] handle ready for [`super::OAuthClient::with_key_store`].
    #[allow(clippy::arc_with_non_send_sync)]
    pub fn shared(storage: Arc<dyn WebCryptoKeyStorage>) -> Arc<dyn DpopKeyStore> {
        Arc::new(Self::new(storage))
    }
}

impl DpopKeyStore for WebCryptoKeyStore {
    fn create<'a>(&'a self, id: &'a str) -> BoxFuture<'a, Result<Arc<dyn DpopSigner>, StoreError>> {
        Box::pin(async move {
            let signer = WebCryptoDpopSigner::generate()
                .await
                .map_err(|error| StoreError::Unavailable(error.to_string()))?;
            self.storage
                .save_key(id, signer.crypto_key().clone(), signer.public_jwk())
                .await?;
            Ok(Arc::new(signer) as Arc<dyn DpopSigner>)
        })
    }

    fn get<'a>(
        &'a self,
        id: &'a str,
    ) -> BoxFuture<'a, Result<Option<Arc<dyn DpopSigner>>, StoreError>> {
        Box::pin(async move {
            let Some((key, jwk)) = self.storage.load_key(id).await? else {
                return Ok(None);
            };
            let signer = WebCryptoDpopSigner::from_key(key, jwk)
                .await
                .map_err(|_| StoreError::Corrupt("WebCrypto DPoP key".into()))?;
            Ok(Some(Arc::new(signer) as Arc<dyn DpopSigner>))
        })
    }

    fn delete<'a>(&'a self, id: &'a str) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(self.storage.delete_key(id))
    }
}

/// Process-local [`WebCryptoKeyStorage`] holding opaque non-extractable
/// `CryptoKey` handles in memory (useful for single-tab flows and tests).
#[derive(Default)]
pub struct MemoryWebCryptoKeyStorage {
    keys: Mutex<HashMap<String, (CryptoKey, EcPublicJwk)>>,
}

impl fmt::Debug for MemoryWebCryptoKeyStorage {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("MemoryWebCryptoKeyStorage")
            .finish_non_exhaustive()
    }
}

impl MemoryWebCryptoKeyStorage {
    /// Creates an empty in-memory WebCrypto handle store.
    pub fn new() -> Self {
        Self::default()
    }
}

impl WebCryptoKeyStorage for MemoryWebCryptoKeyStorage {
    fn save_key<'a>(
        &'a self,
        id: &'a str,
        key: CryptoKey,
        jwk: EcPublicJwk,
    ) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async move {
            let mut guard = self
                .keys
                .lock()
                .map_err(|_| StoreError::Unavailable("WebCrypto handle lock poisoned".into()))?;
            guard.insert(id.to_owned(), (key, jwk));
            Ok(())
        })
    }

    fn load_key<'a>(
        &'a self,
        id: &'a str,
    ) -> BoxFuture<'a, Result<Option<(CryptoKey, EcPublicJwk)>, StoreError>> {
        Box::pin(async move {
            let guard = self
                .keys
                .lock()
                .map_err(|_| StoreError::Unavailable("WebCrypto handle lock poisoned".into()))?;
            Ok(guard.get(id).cloned())
        })
    }

    fn delete_key<'a>(&'a self, id: &'a str) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async move {
            let mut guard = self
                .keys
                .lock()
                .map_err(|_| StoreError::Unavailable("WebCrypto handle lock poisoned".into()))?;
            guard.remove(id);
            Ok(())
        })
    }
}
