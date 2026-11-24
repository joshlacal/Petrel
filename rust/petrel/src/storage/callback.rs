use std::fmt;

use js_sys::{Function, Promise, Uint8Array};
use wasm_bindgen::{JsCast, JsValue};
use wasm_bindgen_futures::JsFuture;

use crate::rt::BoxFuture;

use super::{SecretStore, StoreError, validate_key, validate_namespace};

/// Browser storage backed by an embedder callback.
///
/// The callback accepts `(operation, namespace, key, value)` and returns the
/// result directly or as a Promise. `get` and `take` return a Uint8Array or
/// null for a missing item. `put`, `delete`, and `delete_namespace` resolve
/// upon success. Rejection or an exception becomes a storage error.
/// Implement `take` in one read-write transaction, including when handling an
/// already missing key. The callback owns concurrency across browser contexts.
pub struct CallbackSecretStore {
    dispatch: Function,
}

impl CallbackSecretStore {
    pub fn new(dispatch: Function) -> Self {
        Self { dispatch }
    }

    async fn call(
        &self,
        operation: &str,
        ns: &str,
        key: Option<&str>,
        value: Option<&[u8]>,
    ) -> Result<JsValue, StoreError> {
        validate_namespace(ns)?;
        if let Some(key) = key {
            validate_key(key)?;
        }

        let result = self
            .dispatch
            .call4(
                &JsValue::NULL,
                &operation.into(),
                &ns.into(),
                &key.map_or(JsValue::NULL, JsValue::from_str),
                &value.map_or(JsValue::NULL, |bytes| Uint8Array::from(bytes).into()),
            )
            .map_err(|_| StoreError::Unavailable("browser callback threw".into()))?;
        JsFuture::from(Promise::resolve(&result))
            .await
            .map_err(|_| StoreError::Unavailable("browser callback rejected".into()))
    }

    async fn read(&self, op: &str, ns: &str, key: &str) -> Result<Option<Vec<u8>>, StoreError> {
        let result = self.call(op, ns, Some(key), None).await?;
        if result.is_null() {
            return Ok(None);
        }
        let bytes = result.dyn_into::<Uint8Array>().map_err(|_| {
            StoreError::Corrupt("browser callback must return bytes or null".into())
        })?;
        Ok(Some(bytes.to_vec()))
    }
}

impl fmt::Debug for CallbackSecretStore {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("CallbackSecretStore")
            .finish_non_exhaustive()
    }
}

impl SecretStore for CallbackSecretStore {
    fn get<'a>(
        &'a self,
        ns: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, StoreError>> {
        Box::pin(self.read("get", ns, key))
    }

    fn put<'a>(
        &'a self,
        ns: &'a str,
        key: &'a str,
        value: &'a [u8],
    ) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async move {
            self.call("put", ns, Some(key), Some(value))
                .await
                .map(|_| ())
        })
    }

    fn delete<'a>(&'a self, ns: &'a str, key: &'a str) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async move { self.call("delete", ns, Some(key), None).await.map(|_| ()) })
    }

    fn take<'a>(
        &'a self,
        ns: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, StoreError>> {
        Box::pin(self.read("take", ns, key))
    }

    fn delete_namespace<'a>(&'a self, ns: &'a str) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async move {
            self.call("delete_namespace", ns, None, None)
                .await
                .map(|_| ())
        })
    }
}

#[cfg(test)]
mod tests {
    use wasm_bindgen::prelude::*;

    use super::*;
    use crate::storage::contract_tests::secret_store_conformance;

    #[wasm_bindgen_test::wasm_bindgen_test]
    async fn callback_store_contract() {
        // Rust callback returning JavaScript promises, with one atomic map mutation per operation.
        let data = std::cell::RefCell::new(
            std::collections::HashMap::<(String, String), Uint8Array>::new(),
        );
        let callback = Closure::<dyn FnMut(String, String, JsValue, JsValue) -> Promise>::new(
            move |op: String, ns: String, key: JsValue, value: JsValue| -> Promise {
                let mut values = data.borrow_mut();
                let key = (ns.clone(), key.as_string().unwrap_or_default());
                match op.as_str() {
                    "get" if key.1 == "fault" => {
                        Promise::reject(&JsValue::from_str("injected error"))
                    }
                    "get" => Promise::resolve(
                        &values.get(&key).cloned().map_or(JsValue::NULL, Into::into),
                    ),
                    "take" => {
                        Promise::resolve(&values.remove(&key).map_or(JsValue::NULL, Into::into))
                    }
                    "put" => {
                        values.insert(key, value.dyn_into::<Uint8Array>().unwrap());
                        Promise::resolve(&JsValue::UNDEFINED)
                    }
                    "delete" => {
                        values.remove(&key);
                        Promise::resolve(&JsValue::UNDEFINED)
                    }
                    "delete_namespace" => {
                        values.retain(|(namespace, _), _| namespace != &ns);
                        Promise::resolve(&JsValue::UNDEFINED)
                    }
                    _ => Promise::reject(&JsValue::from_str("invalid operation")),
                }
            },
        );
        let store = CallbackSecretStore::new(callback.as_ref().unchecked_ref::<Function>().clone());
        secret_store_conformance(&store).await;
        assert!(matches!(
            store.get("one", "fault").await,
            Err(StoreError::Unavailable(_))
        ));
    }
}
