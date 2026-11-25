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

#[wasm_bindgen_test]
#[allow(clippy::too_many_lines)]
async fn wasm32_authenticated_lexicon_resolver_verifies_repo_proof() {
    use async_lock::Mutex;
    use petrel::rt::BoxFuture;
    use petrel_core::{Did, Value, dagcbor};
    use petrel_crypto::{ATProtoSigner, P256Keypair, PublicKey};
    use petrel_lexicon::{LexiconDnsResolver, LexiconResolutionError};
    use petrel_repo::{
        CommitError, CommitSigner, Repository, RepositoryPath, SigningAlgorithm, WriteBatch,
        WriteOp,
    };
    use petrel_server::clients::{
        OAuthRemoteFetchPolicy, OAuthRemoteFetchResponse, OAuthRemoteTransport,
    };
    use petrel_server::http::OAuthHttpHeaders;
    use petrel_server::lexicon::OAuthLexiconResolution;
    use petrel_server::lexicon_resolver::{
        AuthenticatedOAuthLexiconResolver, OAuthLexiconAuthority, OAuthLexiconAuthorityError,
        OAuthLexiconAuthorityResolving,
    };
    use url::Url;

    struct WasmSigner(P256Keypair);
    impl CommitSigner for WasmSigner {
        fn algorithm(&self) -> SigningAlgorithm {
            SigningAlgorithm::P256
        }
        fn sign<'a>(&'a self, unsigned: &'a [u8]) -> BoxFuture<'a, Result<Vec<u8>, CommitError>> {
            let kp = self.0.clone();
            Box::pin(async move {
                let sig = ATProtoSigner::sign(&kp, unsigned)
                    .await
                    .map_err(|e| CommitError::SigningFailed(e.to_string()))?;
                Ok(sig.to_vec())
            })
        }
    }

    struct WasmDns(String, String);
    impl LexiconDnsResolver for WasmDns {
        fn lookup_txt<'a>(
            &'a self,
            domain: &'a str,
        ) -> BoxFuture<'a, Result<Vec<String>, LexiconResolutionError>> {
            let expected = self.0.clone();
            let did = self.1.clone();
            Box::pin(async move {
                if domain == expected {
                    Ok(vec![format!("did={did}")])
                } else {
                    Ok(vec![])
                }
            })
        }
    }

    struct WasmAuthority(PublicKey);
    impl OAuthLexiconAuthorityResolving for WasmAuthority {
        fn resolve_authority<'a>(
            &'a self,
            _did: &'a str,
        ) -> BoxFuture<'a, Result<OAuthLexiconAuthority, OAuthLexiconAuthorityError>> {
            let key = self.0.clone();
            Box::pin(async move {
                Ok(OAuthLexiconAuthority {
                    pds_endpoint: Url::parse("https://pds.example.com").unwrap(),
                    signing_key: key,
                })
            })
        }
    }

    struct WasmTransport {
        car: Vec<u8>,
        seen: Mutex<Vec<String>>,
    }
    impl OAuthRemoteTransport for WasmTransport {
        fn pins_connections(&self) -> bool {
            true
        }
        fn fetch<'a>(
            &'a self,
            url: &'a Url,
            _etag: Option<&'a str>,
            _policy: &'a OAuthRemoteFetchPolicy,
        ) -> BoxFuture<'a, Result<OAuthRemoteFetchResponse, petrel_server::OAuthServerError>>
        {
            let u = url.to_string();
            Box::pin(async move {
                self.seen.lock().await.push(u);
                Ok(OAuthRemoteFetchResponse {
                    status: 200,
                    headers: OAuthHttpHeaders::default(),
                    body: self.car.clone(),
                })
            })
        }
    }

    let did_str = "did:plc:z72i7hdynmk6r22z27h6tvur";
    let nsid = "com.example.foo.authBasic";
    let kp = P256Keypair::generate().expect("p256 keypair");
    let pk = kp.public_key().clone();
    let doc_json = serde_json::json!({
        "$type": "com.atproto.lexicon.schema",
        "lexicon": 1,
        "id": nsid,
        "defs": {
            "main": {
                "type": "permission-set",
                "title": "Wasm Test",
                "permissions": [
                    { "type": "permission", "resource": "repo", "collection": ["com.example.foo.item"] }
                ]
            }
        }
    });
    let doc_bytes = serde_json::to_vec(&doc_json).unwrap();
    let val = Value::from_json_record(&doc_bytes).expect("to Value");
    let cbor = dagcbor::encode(&val);
    let signer = WasmSigner(kp);
    let repo = Repository::create(Did::parse(did_str).unwrap(), &signer)
        .await
        .unwrap();
    let committed = repo
        .commit_writes(
            WriteBatch::new(vec![WriteOp::Create {
                path: RepositoryPath::new("com.atproto.lexicon.schema", nsid).unwrap(),
                record_cbor: cbor,
            }])
            .unwrap(),
            &signer,
        )
        .await
        .unwrap();
    let bundle = committed
        .repository
        .record_proof("com.atproto.lexicon.schema", nsid)
        .await
        .unwrap();
    let car = bundle.car().unwrap();

    #[allow(clippy::arc_with_non_send_sync)]
    let resolver = AuthenticatedOAuthLexiconResolver::new(
        Arc::new(WasmTransport {
            car,
            seen: Mutex::new(Vec::new()),
        }),
        OAuthRemoteFetchPolicy {
            max_bytes: AuthenticatedOAuthLexiconResolver::MAXIMUM_CAR_BYTES,
            ..OAuthRemoteFetchPolicy::default()
        },
        Arc::new(WasmDns("_lexicon.foo.example.com".into(), did_str.into())),
        Arc::new(WasmAuthority(pk)),
        Arc::new(SystemOAuthClock),
    )
    .expect("construct AuthenticatedOAuthLexiconResolver on wasm32");

    match resolver
        .perform_resolution(nsid)
        .await
        .expect("resolve on wasm32")
    {
        OAuthLexiconResolution::Resolved(doc) => {
            assert_eq!(doc.nsid, nsid);
            assert_eq!(doc.source_did.as_deref(), Some(did_str));
            assert!(doc.permission_set.is_some());
        }
        other => panic!("unexpected wasm resolution: {other:?}"),
    }
}
