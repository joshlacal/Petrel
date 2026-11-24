use std::sync::Arc;

use futures_util::future::join;
use serde_json::json;

use crate::oauth::SessionRecord;

use super::{MemorySecretStore, PendingRefresh, SecretStore, SessionStore, StoreError};

const FIRST: &str = "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa";
const SECOND: &str = "did:plc:bbbbbbbbbbbbbbbbbbbbbbbb";

pub(super) fn session(did: &str, access: &str) -> SessionRecord {
    serde_json::from_value(json!({
        "account": {
            "did": did,
            "handle": "example.test",
            "pds": "https://pds.example.test",
            "authorization_server": {"issuer": "https://as.example.test"},
        },
        "session": {
            "did": did,
            "access_token": access,
            "refresh_token": "fixture-refresh",
            "created_at": 1000,
            "expires_in": 900,
            "scope": "atproto"
        },
        "dpop_key_id": "key-fixture",
        "dpop_jkt": "thumbprint-fixture",
    }))
    .unwrap()
}

fn in_memory() -> (Arc<MemorySecretStore>, SessionStore) {
    let backend = Arc::new(MemorySecretStore::new());
    let sessions = SessionStore::new(backend.clone(), "petrel").unwrap();
    (backend, sessions)
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn session_replace_keeps_account_and_token_together_by_did() {
    let (_, sessions) = in_memory();
    let first = session(FIRST, "first-token");
    let other = session(SECOND, "other-token");
    sessions.save_session(&first).await.unwrap();
    sessions.save_session(&other).await.unwrap();
    let mut replacement = session(FIRST, "replacement-token");
    replacement.account.pds = "https://replacement.example.test".into();
    sessions.save_session(&replacement).await.unwrap();

    let restored = sessions
        .get_session(&first.account.did)
        .await
        .unwrap()
        .unwrap();
    assert_eq!(restored.account.pds, replacement.account.pds);
    assert_eq!(restored.session.access_token(), "replacement-token");
    assert_eq!(
        sessions
            .get_session(&other.session.did)
            .await
            .unwrap()
            .unwrap()
            .session
            .access_token(),
        "other-token"
    );

    sessions.delete_session(&first.account.did).await.unwrap();
    assert!(
        sessions
            .get_session(&first.account.did)
            .await
            .unwrap()
            .is_none()
    );
    assert!(
        sessions
            .get_session(&other.account.did)
            .await
            .unwrap()
            .is_some()
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn pending_session_is_available_without_changing_committed_state() {
    let (backend, sessions) = in_memory();
    let committed = session(FIRST, "committed-token");
    let pending = session(FIRST, "pending-token");
    sessions.save_session(&committed).await.unwrap();
    sessions
        .save_pending_refresh(&PendingRefresh {
            based_on: [21; 32],
            record: pending,
        })
        .await
        .unwrap();

    let reopened = SessionStore::new(backend, "petrel").unwrap();
    let did = &committed.account.did;
    let committed = reopened.get_session(did).await.unwrap().unwrap();
    assert_eq!(committed.session.access_token(), "committed-token");
    let pending = reopened.get_pending_refresh(did).await.unwrap().unwrap();
    assert_eq!(pending.based_on, [21; 32]);
    assert_eq!(pending.record.session.access_token(), "pending-token");

    let replacement = PendingRefresh {
        based_on: [22; 32],
        record: session(FIRST, "newer-pending-token"),
    };
    reopened.save_pending_refresh(&replacement).await.unwrap();
    assert!(
        !reopened
            .compare_and_delete_pending_refresh(&pending)
            .await
            .unwrap()
    );
    assert!(
        reopened
            .compare_and_delete_pending_refresh(&replacement)
            .await
            .unwrap()
    );
    reopened.delete_pending_session(did).await.unwrap();
    assert!(reopened.get_pending_refresh(did).await.unwrap().is_none());
    assert!(reopened.get_session(did).await.unwrap().is_some());
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn stale_refresh_does_not_replace_a_new_sign_in() {
    let (backend, sessions) = in_memory();
    let concurrent = SessionStore::new(backend, "petrel").unwrap();
    let original = session(FIRST, "before-refresh");
    let refreshed = session(FIRST, "first-refresh");
    let new_sign_in = session(FIRST, "fresh-sign-in");
    sessions.save_session(&original).await.unwrap();
    assert!(
        sessions
            .compare_and_swap_session(&original, &refreshed)
            .await
            .unwrap()
    );
    concurrent.save_session(&new_sign_in).await.unwrap();
    assert!(
        !sessions
            .compare_and_swap_session(&refreshed, &original)
            .await
            .unwrap()
    );

    let saved = sessions
        .get_session(&original.account.did)
        .await
        .unwrap()
        .unwrap();
    assert_eq!(saved.session.access_token(), "fresh-sign-in");
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn malformed_or_cross_account_session_is_an_error() {
    let (backend, sessions) = in_memory();
    let first = session(FIRST, "fixture-token");
    let other = session(SECOND, "other-account-token");
    let invalid = SessionRecord {
        account: first.account.clone(),
        session: other.session.clone(),
        dpop_key_id: first.dpop_key_id.clone(),
        dpop_jkt: first.dpop_jkt.clone(),
    };
    assert!(sessions.save_session(&invalid).await.is_err());

    let record_key = format!("session.{FIRST}");
    backend
        .put("petrel", &record_key, b"malformed JSON")
        .await
        .unwrap();
    assert!(matches!(
        sessions.get_session(&first.account.did).await,
        Err(StoreError::Corrupt(_))
    ));
    let wrong_owner = serde_json::to_vec(&json!({"v": 1, "data": other})).unwrap();
    backend
        .put("petrel", &record_key, &wrong_owner)
        .await
        .unwrap();
    assert!(matches!(
        sessions.get_session(&first.account.did).await,
        Err(StoreError::Corrupt(_))
    ));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn callback_state_is_consumed_once() {
    let (backend, sessions) = in_memory();
    let other = SessionStore::new(backend, "petrel").unwrap();
    sessions
        .save_oauth_state("state", 1000, &"payload")
        .await
        .unwrap();

    let (first, second) = join(
        sessions.consume_oauth_state::<String>("state", 1600),
        other.consume_oauth_state::<String>("state", 1600),
    )
    .await;
    let mut consumed = [first.unwrap(), second.unwrap()].into_iter().flatten();
    assert_eq!(consumed.next().as_deref(), Some("payload"));
    assert_eq!(consumed.next(), None);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn rejected_callback_states_are_consumed_before_validation() {
    let (backend, sessions) = in_memory();
    for (state, now) in [("future", 999), ("expired", 1601)] {
        sessions
            .save_oauth_state(state, 1000, &"payload")
            .await
            .unwrap();
        assert!(matches!(
            sessions.consume_oauth_state::<String>(state, now).await,
            Err(StoreError::InvalidFlowStateAge)
        ));
        assert!(
            sessions
                .consume_oauth_state::<String>(state, 1000)
                .await
                .unwrap()
                .is_none()
        );
    }
    backend
        .put("petrel", "oauthState.corrupt", b"{")
        .await
        .unwrap();
    assert!(matches!(
        sessions
            .consume_oauth_state::<String>("corrupt", 1000)
            .await,
        Err(StoreError::Corrupt(_))
    ));
    assert!(
        sessions
            .consume_oauth_state::<String>("corrupt", 1000)
            .await
            .unwrap()
            .is_none()
    );

    backend
        .put(
            "petrel",
            "oauthState.version",
            br#"{"v":2,"data":{"issued_at":1000,"payload":"fixture"}}"#,
        )
        .await
        .unwrap();
    assert!(matches!(
        sessions
            .consume_oauth_state::<String>("version", 1000)
            .await,
        Err(StoreError::Corrupt(_))
    ));
    assert!(
        sessions
            .consume_oauth_state::<String>("version", 1000)
            .await
            .unwrap()
            .is_none()
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn dpop_key_round_trip_and_removal_are_isolated_by_key_id() {
    let (_, sessions) = in_memory();
    sessions.save_dpop_key("a", &[11; 32]).await.unwrap();
    sessions.save_dpop_key("b", &[12; 32]).await.unwrap();
    assert_eq!(
        *sessions.get_dpop_key("a").await.unwrap().unwrap(),
        [11; 32]
    );
    sessions.delete_dpop_key("a").await.unwrap();
    assert!(sessions.get_dpop_key("a").await.unwrap().is_none());
    assert_eq!(
        *sessions.get_dpop_key("b").await.unwrap().unwrap(),
        [12; 32]
    );
}

#[cfg(all(feature = "file-store", unix))]
#[tokio::test]
async fn backend_read_failure_is_not_an_absent_session() {
    use std::os::unix::fs::PermissionsExt as _;

    use base64::Engine as _;
    use base64::engine::general_purpose::URL_SAFE_NO_PAD;

    let root = tempfile::tempdir().unwrap();
    let path = root.path().canonicalize().unwrap().join("store");
    let backend = super::FileSecretStore::open(&path, &[19; 32]).unwrap();
    let sessions = SessionStore::new(Arc::new(backend), "petrel").unwrap();
    let record = session(FIRST, "fixture-token");
    sessions.save_session(&record).await.unwrap();
    let file = path.join(URL_SAFE_NO_PAD.encode(format!("petrel.session.{FIRST}")));
    std::fs::set_permissions(file, std::fs::Permissions::from_mode(0o644)).unwrap();

    assert!(matches!(
        sessions.get_session(&record.account.did).await,
        Err(StoreError::Unavailable(_))
    ));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn refresh_replaces_a_record_another_encoder_wrote() {
    // The same record as another writer would store it: different key
    // order, an escaped slash, and a field this version does not know.
    let (backend, sessions) = in_memory();
    let original = session(FIRST, "before-refresh");
    let refreshed = session(FIRST, "after-refresh");
    sessions.save_session(&original).await.unwrap();

    let key = format!("session.{FIRST}");
    let stored = backend.get("petrel", &key).await.unwrap().unwrap();
    let mut envelope: serde_json::Value = serde_json::from_slice(&stored).unwrap();
    envelope["data"]["added_by_a_newer_version"] = json!(true);
    let foreign = serde_json::to_string_pretty(&envelope)
        .unwrap()
        .replace("https://", "https:\\/\\/");
    assert_ne!(foreign.as_bytes(), stored.as_slice());
    backend
        .put("petrel", &key, foreign.as_bytes())
        .await
        .unwrap();

    assert!(
        sessions
            .compare_and_swap_session(&original, &refreshed)
            .await
            .unwrap()
    );
    let saved = sessions
        .get_session(&original.account.did)
        .await
        .unwrap()
        .unwrap();
    assert_eq!(saved.session.access_token(), "after-refresh");
}
