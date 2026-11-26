#![cfg(target_arch = "wasm32")]

use std::collections::HashMap;
use std::sync::Arc;

use petrel_server::dpop::{DpopValidationContext, OAuthDpopNonceService, OAuthDpopProofValidator};
use petrel_server::jose::{OAuthCompactJwt, OAuthJwsAlgorithm, OAuthSigningKey};
use petrel_server::service_auth::{
    InMemoryServiceAuthReplayStore, ServiceAuthAudience, ServiceAuthMethodPolicy,
    ServiceAuthVerifier, StaticServiceAuthKeyResolver, public_key_from_jwk,
};
use petrel_server::store::{InMemoryOAuthStore, ReplayStoreDpopChecker};
use petrel_server::support::{OAuthClock, OAuthKeyedDigest, SystemOAuthClock};
use serde::Serialize;
use wasm_bindgen_test::wasm_bindgen_test;

#[derive(Serialize)]
struct DpopClaims<'a> {
    jti: &'a str,
    htm: &'a str,
    htu: &'a str,
    iat: i64,
    nonce: &'a str,
}

#[derive(Serialize)]
struct ServiceClaims<'a> {
    iss: &'a str,
    aud: &'a str,
    exp: i64,
    iat: i64,
    lxm: &'a str,
    jti: &'a str,
}

#[wasm_bindgen_test]
async fn wasm32_dpop_and_service_auth_verification() {
    let clock = Arc::new(SystemOAuthClock);
    let now = clock.now_secs();
    let digest = OAuthKeyedDigest::new(vec![4_u8; 32]).unwrap();
    let nonces = OAuthDpopNonceService::with_defaults(digest.clone());
    let nonce = nonces.current_nonce(now);
    let validator = OAuthDpopProofValidator::new(nonces, digest);
    let store = Arc::new(InMemoryOAuthStore::new());
    let checker = ReplayStoreDpopChecker::new(store, clock);

    let key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, None).unwrap();
    let proof = OAuthCompactJwt::sign(
        &DpopClaims {
            jti: "wasm-jti-1",
            htm: "POST",
            htu: "https://auth.example.com/oauth/token",
            iat: now,
            nonce: &nonce,
        },
        &key,
        Some("dpop+jwt"),
        true,
    )
    .unwrap();
    let validated = validator
        .validate_proof(
            &proof,
            DpopValidationContext {
                method: "POST",
                url: "https://auth.example.com/oauth/token",
                expected_access_token: None,
                expected_jkt: None,
                require_nonce: true,
            },
            &checker,
        )
        .await
        .expect("DPoP verifies on wasm32");
    assert_eq!(validated.jkt, key.thumbprint().unwrap());

    let did = "did:plc:wasmuser234567abcdefgabc";
    let sa_resolver = Arc::new(StaticServiceAuthKeyResolver::new(HashMap::from([(
        did.to_owned(),
        public_key_from_jwk(&key.public_jwk(false).unwrap()).unwrap(),
    )])));
    #[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
    let sa_replay = Arc::new(InMemoryServiceAuthReplayStore::new());
    let verifier = ServiceAuthVerifier::with_replay_store(
        ServiceAuthAudience::exactly("did:web:mls.example.com"),
        sa_resolver,
        sa_replay,
    );
    let sa_jwt = OAuthCompactJwt::sign(
        &ServiceClaims {
            iss: did,
            aud: "did:web:mls.example.com",
            exp: now + 60,
            iat: now,
            lxm: "blue.catbird.mlsChat.getConvos",
            jti: "wasm-sa-1",
        },
        &key,
        Some("JWT"),
        false,
    )
    .unwrap();
    let claims = verifier
        .verify_token(
            &sa_jwt,
            &ServiceAuthMethodPolicy::Exactly("blue.catbird.mlsChat.getConvos".into()),
        )
        .await
        .expect("service auth verifies on wasm32");
    assert_eq!(claims.issuer, did);
}
