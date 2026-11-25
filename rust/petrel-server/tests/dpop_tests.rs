#![cfg(not(target_arch = "wasm32"))]

mod common;

use std::sync::Arc;

use common::{TestClock, make_dpop_proof};
use petrel_server::dpop::{
    DpopValidationContext, OAuthDpopError, OAuthDpopNonceService, OAuthDpopProofValidator,
};
use petrel_server::http::OAuthHttpHeaders;
use petrel_server::jose::{OAuthCompactJwt, OAuthJwsAlgorithm, OAuthSigningKey};
use petrel_server::store::{InMemoryOAuthStore, ReplayStoreDpopChecker};
use petrel_server::support::{OAuthClock, OAuthKeyedDigest, base64url_encode};

struct WrapClock(Arc<TestClock>);
impl OAuthClock for WrapClock {
    fn now_secs(&self) -> i64 {
        self.0.now_secs()
    }
    fn now_unix_f64(&self) -> f64 {
        self.0.now_unix_f64()
    }
}

fn build_validator(
    clock: Arc<TestClock>,
) -> (
    OAuthDpopProofValidator,
    OAuthDpopNonceService,
    ReplayStoreDpopChecker,
) {
    let secret = vec![9_u8; 32];
    let digest = OAuthKeyedDigest::new(secret.clone()).unwrap();
    let nonces = OAuthDpopNonceService::with_defaults(digest.clone());
    let store = Arc::new(InMemoryOAuthStore::new());
    let validator =
        OAuthDpopProofValidator::new(nonces.clone(), digest).with_clock(WrapClock(clock.clone()));
    let replay = ReplayStoreDpopChecker::new(store, clock);
    (validator, nonces, replay)
}

#[tokio::test]
async fn nonce_rotation_and_expiry_work_deterministically() {
    let clock = Arc::new(TestClock::new(1_700_000_000));
    let (validator, nonces, replay) = build_validator(clock.clone());
    let key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();

    // Missing nonce produces UseDpopNonce with fresh nonce.
    let missing_nonce = make_dpop_proof(
        &key,
        "POST",
        "https://auth.example.com/oauth/token",
        None,
        None,
        clock.now_secs(),
        "jti-1",
    );
    let err = validator
        .validate_proof(
            &missing_nonce,
            DpopValidationContext {
                method: "POST",
                url: "https://auth.example.com/oauth/token",
                expected_access_token: None,
                expected_jkt: None,
                require_nonce: true,
            },
            &replay,
        )
        .await
        .unwrap_err();
    let next_nonce = match err {
        OAuthDpopError::UseDpopNonce { next_nonce } => next_nonce,
        OAuthDpopError::InvalidDpopProof(msg) => panic!("expected UseDpopNonce, got {msg}"),
    };

    let valid = make_dpop_proof(
        &key,
        "POST",
        "https://auth.example.com/oauth/token",
        Some(&next_nonce),
        None,
        clock.now_secs(),
        "jti-2",
    );
    let ok = validator
        .validate_proof(
            &valid,
            DpopValidationContext {
                method: "POST",
                url: "https://auth.example.com/oauth/token",
                expected_access_token: None,
                expected_jkt: None,
                require_nonce: true,
            },
            &replay,
        )
        .await
        .unwrap();
    assert_eq!(ok.jkt, key.thumbprint().unwrap());

    // Replay of same jti is rejected.
    assert!(matches!(
        validator
            .validate_proof(
                &valid,
                DpopValidationContext {
                    method: "POST",
                    url: "https://auth.example.com/oauth/token",
                    expected_access_token: None,
                    expected_jkt: None,
                    require_nonce: true,
                },
                &replay,
            )
            .await,
        Err(OAuthDpopError::InvalidDpopProof(_))
    ));

    // Advance past 3 buckets -> old nonce rejected with fresh nonce challenge.
    clock.advance(600);
    assert!(!nonces.is_valid(&next_nonce, clock.now_secs()));
}

#[tokio::test]
async fn htu_normalization_ignores_query_fragment_case_and_default_port() {
    let clock = Arc::new(TestClock::new(1_700_000_000));
    let (validator, nonces, replay) = build_validator(clock.clone());
    let key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256k, None).unwrap();
    let nonce = nonces.current_nonce(clock.now_secs());

    for (idx, htu) in [
        "https://server.example.com/token",
        "HTTPS://SERVER.EXAMPLE.COM/token",
        "https://server.example.com:443/token",
        "https://server.example.com/token?ignored=1#frag",
    ]
    .iter()
    .enumerate()
    {
        let proof = make_dpop_proof(
            &key,
            "POST",
            htu,
            Some(&nonce),
            None,
            clock.now_secs(),
            &format!("jti-norm-{idx}"),
        );
        let validated = validator
            .validate_proof(
                &proof,
                DpopValidationContext {
                    method: "POST",
                    url: "https://server.example.com/token?actual=1",
                    expected_access_token: None,
                    expected_jkt: None,
                    require_nonce: true,
                },
                &replay,
            )
            .await
            .expect("normalized htu must pass");
        assert_eq!(validated.jkt, key.thumbprint().unwrap());
    }
}

#[tokio::test]
async fn ath_binding_and_header_multiplicity_enforced() {
    let clock = Arc::new(TestClock::new(1_700_000_000));
    let (validator, nonces, replay) = build_validator(clock.clone());
    let key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let nonce = nonces.current_nonce(clock.now_secs());
    let ath = OAuthDpopProofValidator::access_token_hash("at_secret_value");

    // Wrong ath rejected
    let bad = make_dpop_proof(
        &key,
        "GET",
        "https://pds.example.com/xrpc/com.atproto.server.getSession",
        Some(&nonce),
        Some("wrong-ath"),
        clock.now_secs(),
        "jti-bad-ath",
    );
    assert!(matches!(
        validator
            .validate_proof(
                &bad,
                DpopValidationContext {
                    method: "GET",
                    url: "https://pds.example.com/xrpc/com.atproto.server.getSession",
                    expected_access_token: Some("at_secret_value"),
                    expected_jkt: None,
                    require_nonce: true,
                },
                &replay,
            )
            .await,
        Err(OAuthDpopError::InvalidDpopProof(_))
    ));

    // Correct ath passes
    let good = make_dpop_proof(
        &key,
        "GET",
        "https://pds.example.com/xrpc/com.atproto.server.getSession",
        Some(&nonce),
        Some(&ath),
        clock.now_secs(),
        "jti-good-ath",
    );
    assert!(
        validator
            .validate_proof(
                &good,
                DpopValidationContext {
                    method: "GET",
                    url: "https://pds.example.com/xrpc/com.atproto.server.getSession",
                    expected_access_token: Some("at_secret_value"),
                    expected_jkt: None,
                    require_nonce: true,
                },
                &replay,
            )
            .await
            .is_ok()
    );

    // Duplicate DPoP headers rejected
    let mut headers = OAuthHttpHeaders::new([("DPoP", good.as_str()), ("DPoP", good.as_str())]);
    assert!(
        validator
            .validate_headers(
                &headers,
                DpopValidationContext {
                    method: "GET",
                    url: "https://pds.example.com/xrpc/com.atproto.server.getSession",
                    expected_access_token: Some("at_secret_value"),
                    expected_jkt: None,
                    require_nonce: true,
                },
                &replay,
            )
            .await
            .is_err()
    );

    // Non-dpop+jwt typ rejected; kid rejected
    let wrong_typ = OAuthCompactJwt::sign(
        &serde_json::json!({
            "jti": "t1", "htm": "POST", "htu": "https://pds.example.com/oauth/token", "iat": clock.now_secs(), "nonce": nonce
        }),
        &key,
        Some("JWT"),
        true,
    )
    .unwrap();
    headers.set("DPoP", wrong_typ);
    assert!(
        validator
            .validate_headers(
                &headers,
                DpopValidationContext {
                    method: "POST",
                    url: "https://pds.example.com/oauth/token",
                    expected_access_token: None,
                    expected_jkt: None,
                    require_nonce: true,
                },
                &replay,
            )
            .await
            .is_err()
    );
    let _ = base64url_encode;
}

#[tokio::test]
async fn dpop_replay_retained_for_future_skewed_iat_through_inclusive_expiry() {
    let clock = Arc::new(TestClock::new(1_700_000_000));
    let store = Arc::new(InMemoryOAuthStore::new());
    let digest = OAuthKeyedDigest::new(vec![9_u8; 32]).unwrap();
    let nonce_svc = OAuthDpopNonceService::with_defaults(digest.clone());
    let validator =
        OAuthDpopProofValidator::new(nonce_svc, digest).with_clock(WrapClock(clock.clone()));
    let replay = ReplayStoreDpopChecker::new(store, clock.clone());
    let key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();

    // Client clock is ahead by full 5s skew at first acceptance (T = 1_700_000_000).
    let iat = clock.now_secs() + 5;
    let proof = OAuthCompactJwt::sign(
        &serde_json::json!({
            "jti": "future-skew-jti-1",
            "htm": "POST",
            "htu": "https://cab.example.com/oauth/assertion",
            "iat": iat,
        }),
        &key,
        Some("dpop+jwt"),
        true,
    )
    .unwrap();
    let ctx = DpopValidationContext {
        method: "POST",
        url: "https://cab.example.com/oauth/assertion",
        expected_access_token: None,
        expected_jkt: None,
        require_nonce: false,
    };

    assert!(
        validator
            .validate_proof(&proof, ctx.clone(), &replay)
            .await
            .is_ok()
    );

    // Advance past `now + max_age(300) + skew(5)` to T + 310 (`iat + 305` inclusive limit).
    clock.set(1_700_000_310);
    let replay_err = validator
        .validate_proof(&proof, ctx, &replay)
        .await
        .expect_err("proof must still be blocked as replayed at inclusive expiry boundary");
    assert!(replay_err.to_string().contains("replayed"));
}
