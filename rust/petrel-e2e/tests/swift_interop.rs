#![cfg(not(target_arch = "wasm32"))]

mod support;

use std::{sync::Arc, time::Duration};

use bytes::Bytes;
use http::{Method, StatusCode};
use petrel::{
    crypto::{DpopSigner, SoftwareDpopSigner},
    oauth::{AssertionBackendError, AssertionBackendErrorCode, OAuthError, OAuthProtocolError},
};
use petrel_e2e::{CAB_CLIENT_ID, DEMO_DID, ServerBins};

use support::{
    CAB_PATH, DeniedKey, Exchange, Fixture, PUBLIC_CLIENT_ID, SESSION_PATH, TOKEN_PATH,
    demo_target, error_code, restore, session_store, snapshot,
};

#[tokio::test]
async fn oauth_public() {
    let Some(bins) = ServerBins::from_env() else {
        return;
    };
    let fixture = Fixture::public(&bins).await;
    exercise_session(&fixture, PUBLIC_CLIENT_ID).await;
}

#[tokio::test]
async fn cab_confidential() {
    let Some(bins) = ServerBins::from_env() else {
        return;
    };
    let fixture = Fixture::confidential(&bins, false, &[]).await;
    exercise_session(&fixture, CAB_CLIENT_ID).await;
    assert!(
        fixture
            .trace
            .requests(CAB_PATH)
            .iter()
            .filter(|entry| entry.status == StatusCode::OK)
            .count()
            >= 4,
        "CAB minted assertions for PAR, code exchange, refresh and revocation",
    );
}

#[tokio::test]
async fn cab_nonce_dance() {
    let Some(bins) = ServerBins::from_env() else {
        return;
    };
    let fixture = Fixture::confidential(&bins, true, &[]).await;
    exercise_session(&fixture, CAB_CLIENT_ID).await;
    let exchanges = fixture.trace.requests(CAB_PATH);
    assert_eq!(
        exchanges.first(),
        Some(&Exchange {
            status: StatusCode::BAD_REQUEST,
            error: Some("use_dpop_nonce".into()),
        }),
    );
    assert_eq!(
        exchanges.get(1),
        Some(&Exchange {
            status: StatusCode::OK,
            error: None
        }),
    );
    for (index, exchange) in exchanges.iter().enumerate().skip(2) {
        if exchange.status != StatusCode::OK {
            assert_eq!(exchange.status, StatusCode::BAD_REQUEST);
            assert_eq!(exchange.error.as_deref(), Some("use_dpop_nonce"));
            assert_eq!(
                exchanges.get(index + 1).map(|entry| entry.status),
                Some(StatusCode::OK)
            );
        }
    }
}

#[tokio::test]
async fn cab_denied() {
    let Some(bins) = ServerBins::from_env() else {
        return;
    };
    let key = Arc::new(SoftwareDpopSigner::generate().expect("generate denied fixture key"));
    let jkt = key.public_jwk().thumbprint().unwrap();
    let fixture = Fixture::confidential(&bins, false, &[&jkt]).await;
    let client = fixture
        .client(session_store())
        .with_key_store(Arc::new(DeniedKey(key)));

    let error = client.start_authorization(demo_target()).await.unwrap_err();
    assert_eq!(
        error,
        OAuthError::Protocol(OAuthProtocolError::AssertionBackend(
            AssertionBackendError::Rejected {
                status: 403,
                code: Some(AssertionBackendErrorCode::AccessDenied),
            }
        )),
    );
    assert_eq!(
        fixture.trace.requests(CAB_PATH),
        [Exchange {
            status: StatusCode::FORBIDDEN,
            error: Some("access_denied".into()),
        }],
    );
    assert_eq!(fixture.trace.requests("/oauth/par"), []);
}

async fn exercise_session(fixture: &Fixture, client_id: &str) {
    let store = session_store();
    let client = Arc::new(fixture.client(store.clone()));
    let (first, _) = fixture.sign_in(&client, client_id).await;
    let did = &first.did;

    for (path, status) in [
        ("/.well-known/oauth-protected-resource", StatusCode::OK),
        ("/.well-known/oauth-authorization-server", StatusCode::OK),
        ("/oauth/par", StatusCode::CREATED),
        (TOKEN_PATH, StatusCode::OK),
    ] {
        assert!(
            fixture
                .trace
                .requests(path)
                .iter()
                .any(|request| request.status == status),
            "{path}"
        );
    }

    let plc_path = format!("/{DEMO_DID}");
    assert!(
        fixture
            .trace
            .requests(&plc_path)
            .iter()
            .filter(|request| request.status == StatusCode::OK)
            .count()
            >= 2,
        "OAuth should resolve the DID before PAR and refresh the DID document during callback verification",
    );

    let token_requests = fixture.trace.requests(TOKEN_PATH).len();
    fixture.get_session(&client, did).await;
    assert_eq!(
        fixture.trace.requests(TOKEN_PATH).len(),
        token_requests,
        "do not refresh a newly issued token on the first resource call"
    );
    let rotated = client
        .refresh(did, true)
        .await
        .expect("force refresh in Swift");
    assert!(
        first.access_token() != rotated.access_token(),
        "access token must rotate"
    );
    assert!(
        first.refresh_token().is_some()
            && rotated.refresh_token().is_some()
            && first.refresh_token() != rotated.refresh_token(),
        "refresh token must rotate",
    );
    fixture.get_session(&client, did).await;
    let (saved, signer) = snapshot(&store, did).await;
    assert!(client.logout(did).await.expect("revoke Swift session"));
    assert!(client.session(did).await.unwrap().is_none());
    assert_eq!(
        fixture.trace.requests("/oauth/revoke").last(),
        Some(&Exchange {
            status: StatusCode::OK,
            error: None
        }),
    );

    // A fresh SDK client still has the local credentials from before revocation.
    let stale_client = fixture.client(restore(&saved, &signer).await);
    assert_eq!(
        stale_client.refresh(did, true).await.unwrap_err(),
        OAuthError::InvalidGrant
    );
    assert!(
        fixture
            .trace
            .requests(TOKEN_PATH)
            .iter()
            .any(|request| request.error.as_deref() == Some("invalid_grant")),
        "the Swift token endpoint refused the stale refresh",
    );
    for access_token in [first.access_token(), rotated.access_token()] {
        assert_access_rejected(fixture, &signer, access_token).await;
    }
}

#[tokio::test]
async fn oauth_rejects_refresh_with_wrong_proof_key() {
    let Some(bins) = ServerBins::from_env() else {
        return;
    };
    let fixture = Fixture::public(&bins).await;
    let client = Arc::new(fixture.client(session_store()));
    let (session, _) = fixture.sign_in(&client, PUBLIC_CLIENT_ID).await;
    let wrong_signer = SoftwareDpopSigner::generate().unwrap();
    let form = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("grant_type", "refresh_token")
        .append_pair("client_id", PUBLIC_CLIENT_ID)
        .append_pair(
            "refresh_token",
            session.refresh_token().expect("Swift refresh token"),
        )
        .finish();

    let response = fixture
        .probe(&wrong_signer, Method::POST, TOKEN_PATH, None, form.into())
        .await;
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    assert_eq!(
        error_code(response.body()).as_deref(),
        Some("invalid_grant")
    );
    fixture.get_session(&client, &session.did).await;
}

#[tokio::test]
async fn oauth_code_replay_revokes_session() {
    let Some(bins) = ServerBins::from_env() else {
        return;
    };
    let fixture = Fixture::public(&bins).await;
    let store = session_store();
    let client = Arc::new(fixture.client(store.clone()));
    fixture.trace.capture_code_exchange();
    let (session, callback) = fixture.sign_in(&client, PUBLIC_CLIENT_ID).await;
    let (_, signer) = snapshot(&store, &session.did).await;
    fixture.get_session(&client, &session.did).await;

    let exchanges = fixture.trace.requests(TOKEN_PATH);
    assert_eq!(
        client.complete_authorization(&callback).await.unwrap_err(),
        OAuthError::UnknownState
    );
    assert_eq!(
        fixture.trace.requests(TOKEN_PATH),
        exchanges,
        "SDK must consume callback state"
    );

    // Verify the local issuer's single-use grant independently of the SDK's guard.
    let form = fixture.trace.exchanged_code_form();
    let response = fixture
        .probe(&signer, Method::POST, TOKEN_PATH, None, form)
        .await;
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    assert_eq!(
        error_code(response.body()).as_deref(),
        Some("invalid_grant")
    );
    assert_access_rejected(&fixture, &signer, session.access_token()).await;
}

#[tokio::test]
async fn oauth_retries_stale_resource_nonce_once() {
    let Some(bins) = ServerBins::from_env() else {
        return;
    };
    let fixture = Fixture::public(&bins).await;
    let store = session_store();
    let client = Arc::new(fixture.client(store.clone()));
    let (session, _) = fixture.sign_in(&client, PUBLIC_CLIENT_ID).await;
    fixture.get_session(&client, &session.did).await;
    let (_, signer) = snapshot(&store, &session.did).await;
    let prior_requests = fixture.trace.requests(SESSION_PATH).len();

    fixture.trace.inject_stale_resource_nonce(signer);
    fixture.get_session(&client, &session.did).await;
    assert_nonce_retry(&fixture, prior_requests);
}

#[tokio::test]
#[ignore = "waits 125 seconds for the Swift server's real nonce clock"]
async fn oauth_recovers_after_nonce_rotation() {
    let Some(bins) = ServerBins::from_env() else {
        return;
    };
    let fixture = Fixture::public(&bins).await;
    let client = Arc::new(fixture.client(session_store()));
    let (session, _) = fixture.sign_in(&client, PUBLIC_CLIENT_ID).await;
    fixture.get_session(&client, &session.did).await;
    let prior_requests = fixture.trace.requests(SESSION_PATH).len();

    tokio::time::sleep(Duration::from_secs(125)).await;
    fixture.get_session(&client, &session.did).await;
    assert_nonce_retry(&fixture, prior_requests);
}

fn assert_nonce_retry(fixture: &Fixture, prior_requests: usize) {
    assert_eq!(
        &fixture.trace.requests(SESSION_PATH)[prior_requests..],
        [
            Exchange {
                status: StatusCode::UNAUTHORIZED,
                error: Some("use_dpop_nonce".into())
            },
            Exchange {
                status: StatusCode::OK,
                error: None
            },
        ],
    );
}

async fn assert_access_rejected(fixture: &Fixture, signer: &SoftwareDpopSigner, token: &str) {
    let response = fixture
        .probe(signer, Method::GET, SESSION_PATH, Some(token), Bytes::new())
        .await;
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    assert_eq!(
        error_code(response.body()).as_deref(),
        Some("invalid_token")
    );
}
