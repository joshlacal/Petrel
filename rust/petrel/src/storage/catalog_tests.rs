use std::future::poll_fn;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::task::Poll;

use futures_util::future::join;
use petrel_core::Did;
use serde_json::json;

use crate::rt::BoxFuture;

use super::session_tests::session;
use super::{AuthEvent, MemorySecretStore, SecretStore, SessionStore, StoreError};

const FIRST: &str = "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa";
const SECOND: &str = "did:plc:bbbbbbbbbbbbbbbbbbbbbbbb";

async fn catalog_contract(backend: Arc<dyn SecretStore>) {
    let store = SessionStore::new(backend.clone(), "petrel").unwrap();
    let other_namespace = SessionStore::new(backend.clone(), "other").unwrap();
    let first = session(FIRST, "first-token");
    let second = session(SECOND, "second-token");
    let first_did = &first.account.did;
    let second_did = &second.account.did;

    // A prior Rust store wrote a v1 session record without a catalog.
    let old = serde_json::to_vec(&json!({"v": 1, "data": first})).unwrap();
    backend
        .put("petrel", &format!("session.{FIRST}"), &old)
        .await
        .unwrap();
    assert!(store.get_session(first_did).await.unwrap().is_some());
    assert!(store.list_account_dids().await.unwrap().is_empty());

    store.save_session(&first).await.unwrap();
    store.save_session(&first).await.unwrap();
    store.save_account(&second.account).await.unwrap();
    assert_eq!(
        store.list_account_dids().await.unwrap(),
        [first_did.clone(), second_did.clone()]
    );
    assert_eq!(
        store.get_account(first_did).await.unwrap().unwrap().did,
        *first_did
    );
    assert_eq!(
        store.get_account(second_did).await.unwrap().unwrap().did,
        *second_did
    );
    assert!(
        other_namespace
            .list_account_dids()
            .await
            .unwrap()
            .is_empty()
    );

    assert!(matches!(
        store
            .save_current_did(&Did::parse("did:web:absent.example.test").unwrap())
            .await,
        Err(StoreError::UnknownAccount)
    ));
    store.save_current_did(second_did).await.unwrap();
    let reopened = SessionStore::new(backend, "petrel").unwrap();
    assert_eq!(
        reopened.get_current_did().await.unwrap().as_ref(),
        Some(second_did)
    );
    reopened.delete_account(second_did).await.unwrap();
    assert!(reopened.get_current_did().await.unwrap().is_none());
    assert!(store.get_account(second_did).await.unwrap().is_none());
    assert_eq!(
        reopened.list_account_dids().await.unwrap(),
        [first_did.clone()]
    );

    reopened.save_current_did(first_did).await.unwrap();
    reopened.delete_current_did().await.unwrap();
    assert!(store.get_current_did().await.unwrap().is_none());
    reopened.delete_account(first_did).await.unwrap();
    assert!(store.get_account(first_did).await.unwrap().is_none());
    assert!(store.get_session(first_did).await.unwrap().is_some());
    assert!(store.list_account_dids().await.unwrap().is_empty());
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn memory_catalog_round_trip() {
    catalog_contract(Arc::new(MemorySecretStore::new())).await;
}

#[cfg(all(feature = "file-store", any(unix, windows)))]
#[tokio::test]
async fn file_catalog_round_trip() {
    let temporary = tempfile::tempdir().unwrap();
    let path = temporary.path().canonicalize().unwrap().join("store");
    let store = super::FileSecretStore::open(&path, &[8; 32]).unwrap();
    catalog_contract(Arc::new(store)).await;
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn interrupted_session_write_leaves_no_discoverable_orphan() {
    let backend = Arc::new(TestBackend::new(true));
    let store = SessionStore::new(backend.clone(), "petrel").unwrap();
    let first = session(FIRST, "first-token");
    backend.fail_session_write.store(true, Ordering::Relaxed);
    assert!(matches!(
        store.save_session(&first).await,
        Err(StoreError::Unavailable(_))
    ));
    assert!(
        backend
            .get("petrel", "accountDIDs")
            .await
            .unwrap()
            .is_some()
    );

    let reopened = SessionStore::new(backend.clone(), "petrel").unwrap();
    assert!(reopened.list_account_dids().await.unwrap().is_empty());
    assert!(
        reopened
            .get_account(&first.account.did)
            .await
            .unwrap()
            .is_none()
    );
    backend.fail_session_write.store(false, Ordering::Relaxed);
    reopened.save_session(&first).await.unwrap();
    assert_eq!(
        reopened.list_account_dids().await.unwrap(),
        [first.account.did]
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn concurrent_catalog_mutations_preserve_both_accounts() {
    for cas in [true, false] {
        let backend = Arc::new(TestBackend::new(cas));
        let first = SessionStore::new(backend.clone(), "petrel").unwrap();
        let second = if cas {
            SessionStore::new(backend, "petrel").unwrap()
        } else {
            // Stores without CAS share the same per-client mutex across clones.
            first.clone()
        };
        let first_account = session(FIRST, "first-token").account;
        let second_account = session(SECOND, "second-token").account;
        let (a, b) = join(
            first.save_account(&first_account),
            second.save_account(&second_account),
        )
        .await;
        a.unwrap();
        b.unwrap();
        assert_eq!(
            first.list_account_dids().await.unwrap(),
            [first_account.did, second_account.did]
        );
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn observing_selection_and_storage_failure_uses_no_secret_values() {
    let backend = Arc::new(TestBackend::new(true));
    let store = SessionStore::new(backend.clone(), "petrel").unwrap();
    let events = Arc::new(Mutex::new(Vec::new()));
    let observer = events.clone();
    let subscription =
        store.observe_auth_events(move |event| observer.lock().unwrap().push(event.clone()));
    let first = session(FIRST, "first-token");
    let did = &first.account.did;
    store.save_account(&first.account).await.unwrap();
    store.save_current_did(did).await.unwrap();
    store.save_current_did(did).await.unwrap();

    backend.fail_catalog_read.store(true, Ordering::Relaxed);
    let second = session(SECOND, "second-token");
    assert!(matches!(
        store.save_account(&second.account).await,
        Err(StoreError::Unavailable(_))
    ));
    backend.fail_catalog_read.store(false, Ordering::Relaxed);
    assert_eq!(store.list_account_dids().await.unwrap(), [did.clone()]);
    store.delete_account(did).await.unwrap();
    drop(subscription);
    store.emit_auth_event(AuthEvent::Logout { did: did.clone() });

    let events = events.lock().unwrap();
    assert_eq!(events.len(), 3);
    assert_eq!(
        events[0],
        AuthEvent::CurrentAccountChanged {
            previous: None,
            current: Some(did.clone())
        }
    );
    assert!(
        matches!(&events[1], AuthEvent::StorageFailure { did: Some(failed), .. } if *failed == second.account.did)
    );
    assert_eq!(
        events[2],
        AuthEvent::CurrentAccountChanged {
            previous: Some(did.clone()),
            current: None
        }
    );
}

struct TestBackend {
    inner: MemorySecretStore,
    cas: bool,
    fail_catalog_read: AtomicBool,
    fail_session_write: AtomicBool,
}

impl TestBackend {
    fn new(cas: bool) -> Self {
        Self {
            inner: MemorySecretStore::new(),
            cas,
            fail_catalog_read: AtomicBool::new(false),
            fail_session_write: AtomicBool::new(false),
        }
    }
}

impl SecretStore for TestBackend {
    fn get<'a>(
        &'a self,
        ns: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, StoreError>> {
        Box::pin(async move {
            if key == "accountDIDs" && self.fail_catalog_read.load(Ordering::Relaxed) {
                return Err(StoreError::Unavailable(
                    "injected catalog read failure".into(),
                ));
            }
            let value = self.inner.get(ns, key).await?;
            if key == "accountDIDs" {
                // Force another writer to attempt a read before this caller can publish.
                let mut yielded = false;
                poll_fn(|context| {
                    if yielded {
                        return Poll::Ready(());
                    }
                    yielded = true;
                    context.waker().wake_by_ref();
                    Poll::Pending
                })
                .await;
            }
            Ok(value)
        })
    }

    fn put<'a>(
        &'a self,
        ns: &'a str,
        key: &'a str,
        value: &'a [u8],
    ) -> BoxFuture<'a, Result<(), StoreError>> {
        Box::pin(async move {
            if key.starts_with("session.") && self.fail_session_write.load(Ordering::Relaxed) {
                return Err(StoreError::Unavailable(
                    "injected before session publication".into(),
                ));
            }
            self.inner.put(ns, key, value).await
        })
    }

    fn delete<'a>(&'a self, ns: &'a str, key: &'a str) -> BoxFuture<'a, Result<(), StoreError>> {
        self.inner.delete(ns, key)
    }

    fn take<'a>(
        &'a self,
        ns: &'a str,
        key: &'a str,
    ) -> BoxFuture<'a, Result<Option<Vec<u8>>, StoreError>> {
        self.inner.take(ns, key)
    }

    fn delete_namespace<'a>(&'a self, ns: &'a str) -> BoxFuture<'a, Result<(), StoreError>> {
        self.inner.delete_namespace(ns)
    }

    fn compare_and_swap<'a>(
        &'a self,
        ns: &'a str,
        key: &'a str,
        expected: Option<&'a [u8]>,
        new: Option<&'a [u8]>,
    ) -> BoxFuture<'a, Result<bool, StoreError>> {
        if self.cas {
            self.inner.compare_and_swap(ns, key, expected, new)
        } else {
            Box::pin(async { Err(StoreError::Unsupported) })
        }
    }
}
