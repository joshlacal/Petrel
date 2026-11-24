use std::fmt;
use std::sync::Arc;

use petrel_core::Did;
use serde::{Deserialize, Serialize, de::DeserializeOwned};
use serde_json::value::RawValue;
use zeroize::Zeroizing;

use crate::oauth::SessionRecord;
use crate::rt::{MaybeSend, MaybeSync};

use super::events::SharedAuthEvents;
use super::{
    AuthEvent, AuthSubscription, SecretStore, StoreError, validate_key, validate_namespace,
};

mod catalog;

const VERSION: u8 = 1;
const MAX_FLOW_AGE_SECONDS: u64 = 600;
const SESSION: &str = "session";
const PENDING_SESSION: &str = "session.pending";
const DPOP_KEY: &str = "dpopKey";
const OAUTH_STATE: &str = "oauthState";

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

    pub(crate) fn emit_auth_event(&self, event: AuthEvent) {
        self.events.emit(&event);
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
            self.emit_auth_event(AuthEvent::StorageFailure {
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
    /// Compares the serialized bytes for the same DID in one backend operation.
    /// A concurrent sign-in changes those bytes and leaves the newer record intact.
    /// Backends without compare-and-swap return [`StoreError::Unsupported`].
    pub async fn compare_and_swap_session(
        &self,
        expected: &SessionRecord,
        replacement: &SessionRecord,
    ) -> Result<bool, StoreError> {
        let did = &expected.session.did;
        validate_record(expected, did)?;
        validate_record(replacement, did)?;
        let key = item_key(SESSION, did.as_str())?;
        let expected = encode(expected)?;
        let replacement = encode(replacement)?;
        let result = self
            .secrets
            .compare_and_swap(&self.namespace, &key, Some(&expected), Some(&replacement))
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

    /// Saves a software DPoP key scalar. Opaque platform keys live with the embedder.
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

    /// Stores a pending OAuth flow with its Unix issue time in seconds.
    pub async fn save_oauth_state<T: Serialize + MaybeSync>(
        &self,
        state: &str,
        issued_at: u64,
        payload: &T,
    ) -> Result<(), StoreError> {
        self.save(OAUTH_STATE, state, &Timed { issued_at, payload })
            .await
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
            return Ok(None);
        };
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
        self.delete(OAUTH_STATE, state).await
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
