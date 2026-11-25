use std::{collections::HashMap, fmt, sync::Mutex};

use crate::rt::BoxFuture;
use zeroize::Zeroizing;

use super::{SecretStore, StoreError, validate_key, validate_namespace};

type Secrets = HashMap<String, HashMap<String, Zeroizing<Vec<u8>>>>;

/// Process-local secret store. Operations on its backing map are atomic.
#[derive(Default)]
pub struct MemorySecretStore {
    secrets: Mutex<Secrets>,
}

impl fmt::Debug for MemorySecretStore {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("MemorySecretStore").finish_non_exhaustive()
    }
}

impl MemorySecretStore {
    pub fn new() -> Self {
        Self::default()
    }

    fn with_secrets<T>(
        &self,
        namespace: &str,
        key: Option<&str>,
        operation: impl FnOnce(&mut Secrets) -> T,
    ) -> Result<T, StoreError> {
        validate_namespace(namespace)?;
        if let Some(key) = key {
            validate_key(key)?;
        }
        let mut secrets = self
            .secrets
            .lock()
            .map_err(|_| StoreError::Unavailable("in-memory lock is poisoned".into()))?;
        Ok(operation(&mut secrets))
    }
}

impl SecretStore for MemorySecretStore {
    fn get<'a>(
        &'a self,
        ns: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, StoreError>> {
        Box::pin(async move {
            self.with_secrets(ns, Some(key), |secrets| {
                secrets.get(ns)?.get(key).map(|value| value.to_vec())
            })
        })
    }

    fn put<'a>(
        &'a self,
        ns: &'a str,
        key: &'a str,
        value: &'a [u8],
    ) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async move {
            self.with_secrets(ns, Some(key), |secrets| {
                secrets
                    .entry(ns.to_owned())
                    .or_default()
                    .insert(key.to_owned(), Zeroizing::new(value.to_vec()));
            })
        })
    }

    fn delete<'a>(&'a self, ns: &'a str, key: &'a str) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async move {
            self.with_secrets(ns, Some(key), |secrets| {
                if let Some(items) = secrets.get_mut(ns) {
                    items.remove(key);
                }
            })
        })
    }

    fn take<'a>(
        &'a self,
        ns: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, StoreError>> {
        Box::pin(async move {
            self.with_secrets(ns, Some(key), |secrets| {
                secrets.get_mut(ns)?.remove(key).map(|value| value.to_vec())
            })
        })
    }

    fn delete_namespace<'a>(&'a self, ns: &'a str) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async move {
            self.with_secrets(ns, None, |secrets| {
                secrets.remove(ns);
            })
        })
    }

    fn compare_and_swap<'a>(
        &'a self,
        ns: &'a str,
        key: &'a str,
        expected: Option<&'a [u8]>,
        new: Option<&'a [u8]>,
    ) -> BoxFuture<'a, Result<bool, StoreError>> {
        Box::pin(async move {
            self.with_secrets(ns, Some(key), |secrets| {
                let current = secrets
                    .get(ns)
                    .and_then(|items| items.get(key))
                    .map(|stored| stored.as_slice());
                if current != expected {
                    return false;
                }
                if let Some(value) = new {
                    secrets
                        .entry(ns.to_owned())
                        .or_default()
                        .insert(key.to_owned(), Zeroizing::new(value.to_vec()));
                } else if let Some(items) = secrets.get_mut(ns) {
                    items.remove(key);
                }
                true
            })
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::contract_tests::secret_store_conformance;

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
    async fn memory_store_contract() {
        secret_store_conformance(&MemorySecretStore::new()).await;
    }

    #[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
    #[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
    async fn atomic_cas_returns_false_after_another_write() {
        let store = MemorySecretStore::new();
        assert!(
            store
                .compare_and_swap("namespace", "item", None, Some(b"first"))
                .await
                .unwrap()
        );
        assert!(
            !store
                .compare_and_swap("namespace", "item", None, Some(b"second"))
                .await
                .unwrap()
        );
        assert!(
            store
                .compare_and_swap("namespace", "item", Some(b"first"), None)
                .await
                .unwrap()
        );
        assert_eq!(store.get("namespace", "item").await.unwrap(), None);
    }

    #[cfg(not(target_arch = "wasm32"))]
    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn competing_consumers_only_one_receives_state() {
        let store = std::sync::Arc::new(MemorySecretStore::new());
        store.put("petrel", "state", b"single use").await.unwrap();
        let ready = std::sync::Arc::new(std::sync::Barrier::new(2));
        let consume = || {
            let store = store.clone();
            let ready = ready.clone();
            tokio::spawn(async move {
                ready.wait();
                store.take("petrel", "state").await.unwrap()
            })
        };
        let first = consume();
        let second = consume();
        let mut winners = [first.await.unwrap(), second.await.unwrap()]
            .into_iter()
            .flatten();
        assert_eq!(winners.next().as_deref(), Some(b"single use".as_slice()));
        assert_eq!(winners.next(), None);
    }

    #[cfg(not(target_arch = "wasm32"))]
    #[tokio::test]
    async fn poisoned_backend_is_a_read_error() {
        let store = MemorySecretStore::new();
        let outcome = std::panic::catch_unwind(|| {
            let _locked = store.secrets.lock().unwrap();
            panic!("injected lock poisoning");
        });
        assert!(outcome.is_err());
        assert!(matches!(
            store.get("petrel", "state").await,
            Err(StoreError::Unavailable(_))
        ));
    }
}
