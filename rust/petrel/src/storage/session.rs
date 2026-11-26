use std::collections::BTreeMap;
use std::fmt;
use std::sync::Arc;

use petrel_core::Did;
use serde::{Deserialize, Serialize, de::DeserializeOwned};
use serde_json::value::RawValue;
use zeroize::Zeroizing;

use crate::crypto::random_bytes;
use crate::oauth::SessionRecord;
use crate::rt::{MaybeSend, MaybeSync};

use super::events::SharedAuthEvents;
use super::{
    AuthEvent, AuthSubscription, SecretStore, StoreError, validate_key, validate_namespace,
};

mod catalog;

const VERSION: u8 = 1;
const MAX_FLOW_AGE_SECONDS: u64 = 600;
const MAX_TRACKED_OAUTH_STATES: usize = 64;
const SESSION: &str = "session";
const PENDING_SESSION: &str = "session.pending";
const REFRESH_LEASE: &str = "session.refreshLease";
const DPOP_KEY: &str = "dpopKey";
const OAUTH_STATE: &str = "oauthState";
const OAUTH_STATE_INDEX: &str = "oauthStates";

/// A short-lived compare-and-swap lease serializing token refresh across clients
/// or tabs sharing one [`SessionStore`].
#[derive(Clone, Deserialize, Serialize)]
pub(crate) struct RefreshLease {
    instance_id: [u8; 16],
    holder: [u8; 16],
    based_on: [u8; 32],
    expires_at: u64,
}

pub(crate) enum RefreshLeaseAcquire {
    Acquired(RefreshLease),
    HeldByPeer,
    Unsupported,
}

/// A replacement produced by refreshing a specific committed session generation.
#[derive(Clone, Deserialize, Serialize)]
pub struct PendingRefresh {
    /// Fingerprint of the committed record this replacement supersedes.
    pub based_on: [u8; 32],
    /// Replacement account, tokens and key binding.
    pub record: SessionRecord,
}

impl fmt::Debug for PendingRefresh {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("PendingRefresh").finish_non_exhaustive()
    }
}

/// Stores OAuth account and session records in a namespace of a secret store.
///
/// The account, tokens, and DPoP key reference are published as one item.
/// Pending replacements occupy a separate item so a refresh can leave the
/// last committed record available until the new one is durably saved.
/// Clones share the catalog mutation lock and event observers. When a
/// backend lacks atomic compare-and-swap, use one store and its clones for
/// each namespace, or coordinate catalog mutations in the embedder.
#[derive(Clone)]
pub struct SessionStore {
    secrets: Arc<dyn SecretStore>,
    namespace: String,
    catalog_lock: Arc<async_lock::Mutex<()>>,
    events: SharedAuthEvents,
}

impl fmt::Debug for SessionStore {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("SessionStore").finish_non_exhaustive()
    }
}

impl SessionStore {
    /// Binds a typed store to a validated secret namespace.
    pub fn new(
        secrets: Arc<dyn SecretStore>,
        namespace: impl Into<String>,
    ) -> Result<Self, StoreError> {
        let namespace = namespace.into();
        validate_namespace(&namespace)?;
        Ok(Self {
            secrets,
            namespace,
            catalog_lock: Arc::default(),
            events: SharedAuthEvents::default(),
        })
    }

    /// Returns the underlying secret store.
    #[must_use]
    pub const fn secrets(&self) -> &Arc<dyn SecretStore> {
        &self.secrets
    }

    /// Returns the namespace this session store operates within.
    #[must_use]
    pub fn namespace(&self) -> &str {
        &self.namespace
    }

    /// Observes local auth events from this store and its clones.
    ///
    /// Callbacks run inline after storage releases its own locks. Schedule
    /// asynchronous follow-up work so the caller can finish its operation.
    /// Keep the returned subscription alive to continue observing.
    pub fn observe_auth_events<F>(&self, observer: F) -> AuthSubscription
    where
        F: Fn(&AuthEvent) + MaybeSend + MaybeSync + 'static,
    {
        self.events.subscribe(observer)
    }

    pub(crate) fn emit_auth_event(&self, event: &AuthEvent) {
        self.events.emit(event);
    }

    fn report_storage_result<T>(
        &self,
        did: Option<&Did>,
        operation: &'static str,
        result: Result<T, StoreError>,
    ) -> Result<T, StoreError> {
        if matches!(
            &result,
            Err(StoreError::Unavailable(_)
                | StoreError::Corrupt(_)
                | StoreError::KeyMismatch
                | StoreError::Other(_))
        ) {
            self.emit_auth_event(&AuthEvent::StorageFailure {
                operation,
                did: did.cloned(),
            });
        }
        result
    }

    /// Loads the committed record. A backend or decode failure is an error.
    pub async fn get_session(&self, did: &Did) -> Result<Option<SessionRecord>, StoreError> {
        let result = self.get_record(SESSION, did).await;
        self.report_storage_result(Some(did), "read session", result)
    }

    /// Publishes the account and its session together under their shared DID.
    pub async fn save_session(&self, record: &SessionRecord) -> Result<(), StoreError> {
        let did = &record.session.did;
        let result = async {
            validate_record(record, did)?;
            self.register_session_account(did).await?;
            self.save(SESSION, did.as_str(), record).await
        }
        .await;
        self.report_storage_result(Some(did), "save session", result)
    }

    /// Replaces the committed record only when it still matches `expected`.
    ///
    /// The stored record must hold the same tokens and key as `expected`. The
    /// swap itself is made against the bytes actually stored, so a record
    /// written by another encoder (a different field order, an escaped slash,
    /// a field this version does not know) still compares equal. A concurrent
    /// sign-in changes the stored bytes and leaves the newer record intact.
    /// Backends without compare-and-swap return [`StoreError::Unsupported`].
    pub async fn compare_and_swap_session(
        &self,
        expected: &SessionRecord,
        replacement: &SessionRecord,
    ) -> Result<bool, StoreError> {
        let did = &expected.session.did;
        let result = async {
            validate_record(expected, did)?;
            validate_record(replacement, did)?;
            let key = item_key(SESSION, did.as_str())?;
            let Some(stored) = self.secrets.get(&self.namespace, &key).await? else {
                return Ok(false);
            };
            let stored = Zeroizing::new(stored);
            let current: SessionRecord = decode(payload(&stored)?)?;
            if current.generation() != expected.generation() {
                return Ok(false);
            }
            let replacement = encode(replacement)?;
            self.secrets
                .compare_and_swap(&self.namespace, &key, Some(&stored), Some(&replacement))
                .await
        }
        .await;
        self.report_storage_result(Some(did), "replace session", result)
    }

    /// Removes the committed record. A pending record remains independently addressable.
    pub async fn delete_session(&self, did: &Did) -> Result<(), StoreError> {
        let result = self.delete(SESSION, did.as_str()).await;
        self.report_storage_result(Some(did), "delete session", result)
    }

    /// Loads a pending replacement for this DID.
    pub async fn get_pending_refresh(
        &self,
        did: &Did,
    ) -> Result<Option<PendingRefresh>, StoreError> {
        let pending: Option<PendingRefresh> = self.load(PENDING_SESSION, did.as_str()).await?;
        if let Some(ref pending) = pending {
            validate_record(&pending.record, did)?;
        }
        Ok(pending)
    }

    /// Saves a replacement token set pending a successful commit.
    pub async fn save_pending_refresh(&self, pending: &PendingRefresh) -> Result<(), StoreError> {
        let did = &pending.record.session.did;
        validate_record(&pending.record, did)?;
        self.save(PENDING_SESSION, did.as_str(), pending).await
    }

    /// Removes the pending record only if another writer hasn't replaced it.
    pub async fn compare_and_delete_pending_refresh(
        &self,
        pending: &PendingRefresh,
    ) -> Result<bool, StoreError> {
        let did = &pending.record.session.did;
        validate_record(&pending.record, did)?;
        let key = item_key(PENDING_SESSION, did.as_str())?;
        let expected = encode(pending)?;
        self.secrets
            .compare_and_swap(&self.namespace, &key, Some(&expected), None)
            .await
    }

    /// Removes the pending replacement for this DID.
    pub async fn delete_pending_session(&self, did: &Did) -> Result<(), StoreError> {
        self.delete(PENDING_SESSION, did.as_str()).await
    }

    pub(crate) async fn try_acquire_refresh_lease(
        &self,
        did: &Did,
        instance_id: [u8; 16],
        based_on: [u8; 32],
        now: u64,
        ttl_secs: u64,
    ) -> Result<RefreshLeaseAcquire, StoreError> {
        let key = item_key(REFRESH_LEASE, did.as_str())?;
        let existing = self.secrets.get(&self.namespace, &key).await?;
        if let Some(ref raw) = existing
            && let Ok(lease) = payload(raw).and_then(decode::<RefreshLease>)
            && lease.based_on == based_on
            && lease.expires_at > now
            && lease.instance_id != instance_id
        {
            return Ok(RefreshLeaseAcquire::HeldByPeer);
        }
        let holder =
            random_bytes::<16>().map_err(|_| StoreError::Unavailable("randomness".into()))?;
        let lease = RefreshLease {
            instance_id,
            holder,
            based_on,
            expires_at: now.saturating_add(ttl_secs),
        };
        let encoded = encode(&lease)?;
        match self
            .secrets
            .compare_and_swap(&self.namespace, &key, existing.as_deref(), Some(&encoded))
            .await
        {
            Ok(true) => Ok(RefreshLeaseAcquire::Acquired(lease)),
            Ok(false) => Ok(RefreshLeaseAcquire::HeldByPeer),
            Err(StoreError::Unsupported) => Ok(RefreshLeaseAcquire::Unsupported),
            Err(error) => Err(error),
        }
    }

    pub(crate) async fn release_refresh_lease(&self, did: &Did, lease: &RefreshLease) {
        let Ok(key) = item_key(REFRESH_LEASE, did.as_str()) else {
            return;
        };
        let Ok(encoded) = encode(lease) else {
            return;
        };
        let _ = self
            .secrets
            .compare_and_swap(&self.namespace, &key, Some(&encoded), None)
            .await;
    }

    /// Saves a software DPoP key scalar. Browser embedders should prefer
    /// [`crate::oauth::WebCryptoKeyStore`] via [`crate::oauth::OAuthClient::with_key_store`]
    /// so non-extractable WebCrypto private keys never touch byte storage.
    pub async fn save_dpop_key(&self, id: &str, scalar: &[u8; 32]) -> Result<(), StoreError> {
        self.save(DPOP_KEY, id, scalar).await
    }

    /// Loads a software DPoP key into a zeroizing buffer.
    pub async fn get_dpop_key(&self, id: &str) -> Result<Option<Zeroizing<[u8; 32]>>, StoreError> {
        Ok(self.load(DPOP_KEY, id).await?.map(Zeroizing::new))
    }

    /// Removes a software DPoP key.
    pub async fn delete_dpop_key(&self, id: &str) -> Result<(), StoreError> {
        self.delete(DPOP_KEY, id).await
    }

    /// Stores a pending OAuth flow with its Unix issue time in seconds,
    /// sweeping any previously tracked expired `oauthState.*` entries.
    pub async fn save_oauth_state<T: Serialize + MaybeSync>(
        &self,
        state: &str,
        issued_at: u64,
        payload: &T,
    ) -> Result<(), StoreError> {
        self.save(OAUTH_STATE, state, &Timed { issued_at, payload })
            .await?;
        let _guard = self.catalog_lock.lock().await;
        let mut index = self.load_oauth_state_index().await;
        self.prune_oauth_state_index(&mut index, issued_at, true)
            .await;
        index.insert(state.to_owned(), issued_at);
        let _ = self.save_oauth_state_index(&index).await;
        Ok(())
    }

    /// Consumes flow state before checking its age or decoding the payload.
    ///
    /// A state can be redeemed once. An absent state yields `None`, and a
    /// malformed, future-dated or expired state is consumed and rejected.
    /// `now` is a Unix timestamp in seconds.
    pub async fn consume_oauth_state<T: DeserializeOwned>(
        &self,
        state: &str,
        now: u64,
    ) -> Result<Option<T>, StoreError> {
        let key = item_key(OAUTH_STATE, state)?;
        let Some(bytes) = self.secrets.take(&self.namespace, &key).await? else {
            let _ = self.remove_from_oauth_state_index(state, now).await;
            return Ok(None);
        };
        let _ = self.remove_from_oauth_state_index(state, now).await;
        let bytes = Zeroizing::new(bytes);
        let state: BorrowedTimed<'_> = decode(payload(&bytes)?)?;
        if now
            .checked_sub(state.issued_at)
            .is_none_or(|age| age > MAX_FLOW_AGE_SECONDS)
        {
            return Err(StoreError::InvalidFlowStateAge);
        }
        decode(state.payload).map(Some)
    }

    /// Discards a flow without decoding its payload, for cancellation.
    pub async fn delete_oauth_state(&self, state: &str) -> Result<(), StoreError> {
        self.delete(OAUTH_STATE, state).await?;
        let _guard = self.catalog_lock.lock().await;
        let mut index = self.load_oauth_state_index().await;
        if index.remove(state).is_some() {
            let _ = self.save_oauth_state_index(&index).await;
        }
        Ok(())
    }

    /// Deletes tracked `oauthState.*` entries whose age exceeds the flow window at `now`.
    pub async fn sweep_expired_oauth_states(&self, now: u64) -> Result<usize, StoreError> {
        let _guard = self.catalog_lock.lock().await;
        let mut index = self.load_oauth_state_index().await;
        let removed = self.prune_oauth_state_index(&mut index, now, false).await;
        if removed > 0 {
            self.save_oauth_state_index(&index).await?;
        }
        Ok(removed)
    }

    async fn remove_from_oauth_state_index(&self, state: &str, now: u64) -> Result<(), StoreError> {
        let _guard = self.catalog_lock.lock().await;
        let mut index = self.load_oauth_state_index().await;
        let removed_entry = index.remove(state).is_some();
        let swept = self.prune_oauth_state_index(&mut index, now, false).await;
        if removed_entry || swept > 0 {
            self.save_oauth_state_index(&index).await?;
        }
        Ok(())
    }

    async fn load_oauth_state_index(&self) -> BTreeMap<String, u64> {
        self.secrets
            .get(&self.namespace, OAUTH_STATE_INDEX)
            .await
            .ok()
            .flatten()
            .and_then(|bytes| payload(&bytes).ok().and_then(|raw| decode(raw).ok()))
            .unwrap_or_default()
    }

    async fn save_oauth_state_index(
        &self,
        index: &BTreeMap<String, u64>,
    ) -> Result<(), StoreError> {
        if index.is_empty() {
            self.secrets
                .delete(&self.namespace, OAUTH_STATE_INDEX)
                .await
        } else {
            let bytes = encode(index)?;
            self.secrets
                .put(&self.namespace, OAUTH_STATE_INDEX, &bytes)
                .await
        }
    }

    async fn prune_oauth_state_index(
        &self,
        index: &mut BTreeMap<String, u64>,
        now: u64,
        enforce_cap: bool,
    ) -> usize {
        let expired: Vec<String> = index
            .iter()
            .filter(|&(_, issued_at)| {
                now.checked_sub(*issued_at)
                    .is_some_and(|age| age > MAX_FLOW_AGE_SECONDS)
            })
            .map(|(state, _)| state.clone())
            .collect();
        let mut removed = 0;
        for state in expired {
            index.remove(&state);
            let _ = self.delete(OAUTH_STATE, &state).await;
            removed += 1;
        }
        if enforce_cap {
            while index.len() >= MAX_TRACKED_OAUTH_STATES {
                let Some(oldest) = index
                    .iter()
                    .min_by_key(|(_, issued_at)| **issued_at)
                    .map(|(state, _)| state.clone())
                else {
                    break;
                };
                index.remove(&oldest);
                let _ = self.delete(OAUTH_STATE, &oldest).await;
                removed += 1;
            }
        }
        removed
    }

    async fn get_record(&self, base: &str, did: &Did) -> Result<Option<SessionRecord>, StoreError> {
        let record = self.load(base, did.as_str()).await?;
        if let Some(ref record) = record {
            validate_record(record, did)?;
        }
        Ok(record)
    }

    async fn load<T: DeserializeOwned>(
        &self,
        base: &str,
        suffix: &str,
    ) -> Result<Option<T>, StoreError> {
        let key = item_key(base, suffix)?;
        self.secrets
            .get(&self.namespace, &key)
            .await?
            .map(|bytes| {
                let bytes = Zeroizing::new(bytes);
                decode(payload(&bytes)?)
            })
            .transpose()
    }

    async fn save<T: Serialize + MaybeSync>(
        &self,
        base: &str,
        suffix: &str,
        value: &T,
    ) -> Result<(), StoreError> {
        let key = item_key(base, suffix)?;
        let bytes = encode(value)?;
        self.secrets.put(&self.namespace, &key, &bytes).await
    }

    async fn delete(&self, base: &str, suffix: &str) -> Result<(), StoreError> {
        let key = item_key(base, suffix)?;
        self.secrets.delete(&self.namespace, &key).await
    }
}

fn item_key(base: &str, suffix: &str) -> Result<String, StoreError> {
    validate_key(suffix)?;
    Ok(format!("{base}.{suffix}"))
}

fn validate_record(record: &SessionRecord, did: &Did) -> Result<(), StoreError> {
    if record.account.did != *did || record.session.did != *did {
        return Err(StoreError::Corrupt(
            "session and account identifiers do not match".into(),
        ));
    }
    if record.dpop_key_id.is_empty() || record.dpop_jkt.is_empty() {
        return Err(StoreError::Corrupt(
            "session lacks a DPoP key binding".into(),
        ));
    }
    Ok(())
}

#[derive(Serialize)]
struct Envelope<T> {
    v: u8,
    data: T,
}

#[derive(Deserialize)]
struct BorrowedEnvelope<'a> {
    v: u8,
    #[serde(borrow)]
    data: &'a RawValue,
}

#[derive(Serialize)]
struct Timed<T> {
    issued_at: u64,
    payload: T,
}

#[derive(Deserialize)]
struct BorrowedTimed<'a> {
    issued_at: u64,
    #[serde(borrow)]
    payload: &'a RawValue,
}

fn encode(value: &impl Serialize) -> Result<Zeroizing<Vec<u8>>, StoreError> {
    let mut bytes = Zeroizing::new(Vec::new());
    serde_json::to_writer(
        &mut *bytes,
        &Envelope {
            v: VERSION,
            data: value,
        },
    )
    .map_err(|_| StoreError::Other("could not encode a typed secret".into()))?;
    Ok(bytes)
}

fn payload(bytes: &[u8]) -> Result<&RawValue, StoreError> {
    let envelope: BorrowedEnvelope<'_> = serde_json::from_slice(bytes)
        .map_err(|_| StoreError::Corrupt("invalid typed secret envelope".into()))?;
    if envelope.v != VERSION {
        return Err(StoreError::Corrupt(
            "unsupported typed secret version".into(),
        ));
    }
    Ok(envelope.data)
}

fn decode<'a, T: Deserialize<'a>>(raw: &'a RawValue) -> Result<T, StoreError> {
    serde_json::from_str(raw.get())
        .map_err(|_| StoreError::Corrupt("invalid typed secret payload".into()))
}
