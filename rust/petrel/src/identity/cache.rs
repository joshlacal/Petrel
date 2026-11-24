use std::{
    collections::BTreeMap,
    future::{Future, ready},
    sync::{Mutex, PoisonError},
    time::Duration,
};

use petrel_core::{Did, Handle};
use web_time::SystemTime;

use crate::rt::{MaybeSend, MaybeSync};

use super::DidDocument;

/// Maximum age for a fresh hit, and for a stale hit after a transient failure.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CachePolicy {
    pub fresh_for: Duration,
    pub maximum_age: Duration,
}

impl Default for CachePolicy {
    fn default() -> Self {
        Self {
            fresh_for: Duration::from_secs(60 * 60),
            maximum_age: Duration::from_secs(24 * 60 * 60),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CacheEntry<T> {
    pub value: T,
    pub stored_at: SystemTime,
}

impl<T> CacheEntry<T> {
    pub(super) fn within(&self, age: Duration, now: SystemTime) -> bool {
        now.duration_since(self.stored_at)
            .is_ok_and(|actual| actual < age)
    }
}

/// Cache documents and candidate handles separately. The resolver verifies
/// the two sources agree before using a candidate as an identity.
pub trait IdentityCache: MaybeSend + MaybeSync {
    fn document(
        &self,
        did: &Did,
    ) -> impl Future<Output = Option<CacheEntry<DidDocument>>> + MaybeSend;
    fn handle(&self, handle: &Handle) -> impl Future<Output = Option<CacheEntry<Did>>> + MaybeSend;
    fn put_document(
        &self,
        document: CacheEntry<DidDocument>,
    ) -> impl Future<Output = ()> + MaybeSend;
    fn put_handle(
        &self,
        handle: Handle,
        candidate: CacheEntry<Did>,
    ) -> impl Future<Output = ()> + MaybeSend;
    fn remove_document(&self, did: &Did) -> impl Future<Output = ()> + MaybeSend;
    fn remove_handle(&self, handle: &Handle) -> impl Future<Output = ()> + MaybeSend;
    fn clear(&self) -> impl Future<Output = ()> + MaybeSend;
}

#[derive(Debug)]
pub struct InMemoryIdentityCache {
    documents: Mutex<BTreeMap<Did, CacheEntry<DidDocument>>>,
    handles: Mutex<BTreeMap<String, CacheEntry<Did>>>,
    capacity: usize,
}

impl InMemoryIdentityCache {
    pub fn new(capacity: usize) -> Self {
        Self {
            capacity: capacity.max(1),
            documents: Mutex::default(),
            handles: Mutex::default(),
        }
    }
}

impl Default for InMemoryIdentityCache {
    fn default() -> Self {
        Self::new(1024)
    }
}

impl IdentityCache for InMemoryIdentityCache {
    fn document(
        &self,
        did: &Did,
    ) -> impl Future<Output = Option<CacheEntry<DidDocument>>> + MaybeSend {
        ready(
            self.documents
                .lock()
                .unwrap_or_else(PoisonError::into_inner)
                .get(did)
                .cloned(),
        )
    }

    fn handle(&self, handle: &Handle) -> impl Future<Output = Option<CacheEntry<Did>>> + MaybeSend {
        ready(
            self.handles
                .lock()
                .unwrap_or_else(PoisonError::into_inner)
                .get(handle.normalized())
                .cloned(),
        )
    }

    fn put_document(
        &self,
        document: CacheEntry<DidDocument>,
    ) -> impl Future<Output = ()> + MaybeSend {
        let mut cache = self
            .documents
            .lock()
            .unwrap_or_else(PoisonError::into_inner);
        cache.insert(document.value.id.clone(), document);
        trim(&mut cache, self.capacity);
        ready(())
    }

    fn put_handle(
        &self,
        handle: Handle,
        candidate: CacheEntry<Did>,
    ) -> impl Future<Output = ()> + MaybeSend {
        let mut cache = self.handles.lock().unwrap_or_else(PoisonError::into_inner);
        cache.insert(handle.normalized().to_owned(), candidate);
        trim(&mut cache, self.capacity);
        ready(())
    }

    fn remove_document(&self, did: &Did) -> impl Future<Output = ()> + MaybeSend {
        self.documents
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .remove(did);
        ready(())
    }

    fn remove_handle(&self, handle: &Handle) -> impl Future<Output = ()> + MaybeSend {
        self.handles
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .remove(handle.normalized());
        ready(())
    }

    fn clear(&self) -> impl Future<Output = ()> + MaybeSend {
        self.documents
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .clear();
        self.handles
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
            .clear();
        ready(())
    }
}

fn trim<K: Clone + Ord, V>(cache: &mut BTreeMap<K, CacheEntry<V>>, capacity: usize) {
    if cache.len() <= capacity {
        return;
    }

    // Evict extra entries when full to avoid sorting on every insertion.
    let to_drop = cache.len() - capacity + capacity / 8;
    let mut entries: Vec<_> = cache.iter().collect();
    entries.sort_by_key(|(_, entry)| entry.stored_at);
    let oldest: Vec<_> = entries
        .into_iter()
        .take(to_drop)
        .map(|(key, _)| key.clone())
        .collect();
    for key in oldest {
        cache.remove(&key);
    }
}
