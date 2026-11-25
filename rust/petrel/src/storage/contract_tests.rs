use futures_util::future::join;

use super::{SecretStore, StoreError};

pub(super) async fn secret_store_conformance(store: &dyn SecretStore) {
    assert_eq!(store.get("a", "k").await.unwrap(), None);
    store.put("a", "k", b"first").await.unwrap();
    store.put("b", "k", b"second").await.unwrap();
    assert_eq!(
        store.get("a", "k").await.unwrap().as_deref(),
        Some(b"first".as_slice())
    );
    assert!(matches!(
        store.put("a.k", "k", b"invalid").await,
        Err(StoreError::InvalidNamespace)
    ));
    assert!(matches!(
        store.put("a", "", b"invalid").await,
        Err(StoreError::InvalidKey)
    ));

    let (first, second) = join(store.take("a", "k"), store.take("a", "k")).await;
    assert_eq!(
        first.unwrap().or(second.unwrap()).as_deref(),
        Some(b"first".as_slice())
    );
    assert_eq!(store.get("a", "k").await.unwrap(), None);
    // Repeat to confirm exactly one claimant, without assuming acquisition order.
    store.put("a", "k", b"again").await.unwrap();
    let (first, second) = join(store.take("a", "k"), store.take("a", "k")).await;
    assert_ne!(first.unwrap().is_some(), second.unwrap().is_some());
    store.delete("a", "k").await.unwrap();
    store.delete("a", "k").await.unwrap();
    store.put("a", "extra", b"remove").await.unwrap();
    store.delete_namespace("a").await.unwrap();
    assert_eq!(store.get("a", "extra").await.unwrap(), None);
    assert_eq!(
        store.get("b", "k").await.unwrap().as_deref(),
        Some(b"second".as_slice())
    );
}
