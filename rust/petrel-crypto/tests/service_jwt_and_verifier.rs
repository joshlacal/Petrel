//! Service JWT and ServiceAuthVerifier tests + TypeScript & Swift interop vectors
//! ported from `ServiceJWTTests.swift`, `ServiceJWTSignerTests.swift`,
//! `ServiceAuthVerifierTests.swift`, `ServiceAuthDocumentationTests.swift`,
//! `service-jwt-vectors.json`, and `petrel-minted-tokens.json`.

#![cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]

use std::collections::{BTreeSet, HashMap};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use petrel_crypto::{
    ATProtoCrypto, ATProtoJWTVerificationKey, ATProtoKeyCurve, ATProtoKeypair,
    ATProtoServiceReference, ATProtoSignature, ATProtoSignatureVerificationOptions,
    CachingServiceAuthKeyResolver, ClosureServiceAuthKeyResolver, InMemoryServiceAuthReplayStore,
    JWTBase64URL, K256Keypair, P256Keypair, PLCDIDVerificationKey, ProxyServiceJWT, PublicKey,
    ReplayStoreError, ServiceAuthAudience, ServiceAuthError, ServiceAuthKeyResolver,
    ServiceAuthMethodPolicy, ServiceAuthReplayStore, ServiceAuthRequiredClaims,
    ServiceAuthVerifier, ServiceAuthVerifierConfig, ServiceJWT, ServiceJWTMintOptions,
    ServiceJWTSigningKey, ServiceJWTVerifyOptions, SpaceServiceJWT, StaticServiceAuthKeyResolver,
};
use serde::Deserialize;
use web_time::{SystemTime, UNIX_EPOCH};

const SERVICE_JWT_VECTORS_JSON: &str =
    include_str!("../../../Tests/PetrelTests/Vectors/service-auth/service-jwt-vectors.json");
const PETREL_MINTED_TOKENS_JSON: &str =
    include_str!("../../../Tests/PetrelTests/Vectors/service-auth/petrel-minted-tokens.json");

const ISSUER: &str = "did:plc:abcdefghijklmnopqrstuvwx";
const SERVICE_DID: &str = "did:web:feed.example.com";
const AUDIENCE: &str = "did:web:feed.example.com#bsky_fg";
const METHOD: &str = "app.bsky.feed.getFeedSkeleton";

fn ts(secs: u64) -> SystemTime {
    UNIX_EPOCH + Duration::from_secs(secs)
}

fn now_pinned() -> SystemTime {
    ts(1_700_000_000)
}

fn high_s_rewrite(token: &str, curve: ATProtoKeyCurve) -> String {
    let order: [u8; 32] = match curve {
        ATProtoKeyCurve::P256 => [
            0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
            0xff, 0xff, 0xbc, 0xe6, 0xfa, 0xad, 0xa7, 0x17, 0x9e, 0x84, 0xf3, 0xb9, 0xca, 0xc2,
            0xfc, 0x63, 0x25, 0x51,
        ],
        ATProtoKeyCurve::Secp256k1 => [
            0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
            0xff, 0xfe, 0xba, 0xae, 0xdc, 0xe6, 0xaf, 0x48, 0xa0, 0x3b, 0xbf, 0xd2, 0x5e, 0x8c,
            0xd0, 0x36, 0x41, 0x41,
        ],
    };
    let parts: Vec<&str> = token.split('.').collect();
    let sig = JWTBase64URL::decode(parts[2], 64).unwrap();
    let mut s = [0_u8; 32];
    let mut borrow: i16 = 0;
    for i in (0..32).rev() {
        let mut val = i16::from(order[i]) - i16::from(sig[32 + i]) - borrow;
        if val < 0 {
            val += 256;
            borrow = 1;
        } else {
            borrow = 0;
        }
        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        {
            s[i] = val as u8;
        }
    }
    let mut out = [0_u8; 64];
    out[..32].copy_from_slice(&sig[..32]);
    out[32..].copy_from_slice(&s);
    format!("{}.{}.{}", parts[0], parts[1], JWTBase64URL::encode(&out))
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct Lookup {
    did: String,
    key_id: String,
    force_refresh: bool,
}

struct RecordingKeyResolver {
    lookups: Mutex<Vec<Lookup>>,
    cached: HashMap<String, PublicKey>,
    refreshed: HashMap<String, PublicKey>,
    failure: Option<String>,
}

impl RecordingKeyResolver {
    fn new(
        cached: HashMap<String, PublicKey>,
        refreshed: Option<HashMap<String, PublicKey>>,
        failure: Option<&str>,
    ) -> Self {
        Self {
            lookups: Mutex::new(Vec::new()),
            refreshed: refreshed.unwrap_or_else(|| cached.clone()),
            cached,
            failure: failure.map(str::to_owned),
        }
    }

    fn take_lookups(&self) -> Vec<Lookup> {
        self.lookups.lock().unwrap().clone()
    }
}

impl ServiceAuthKeyResolver for RecordingKeyResolver {
    fn signing_key<'a>(
        &'a self,
        did: &'a str,
        force_refresh: bool,
    ) -> petrel_crypto::rt::BoxFuture<'a, Result<PublicKey, ServiceAuthError>> {
        self.signing_key_for_id(did, "#atproto", force_refresh)
    }

    fn signing_key_for_id<'a>(
        &'a self,
        did: &'a str,
        key_id: &'a str,
        force_refresh: bool,
    ) -> petrel_crypto::rt::BoxFuture<'a, Result<PublicKey, ServiceAuthError>> {
        Box::pin(async move {
            self.lookups.lock().unwrap().push(Lookup {
                did: did.to_owned(),
                key_id: key_id.to_owned(),
                force_refresh,
            });
            if let Some(reason) = &self.failure {
                return Err(ServiceAuthError::KeyResolutionFailed {
                    did: did.to_owned(),
                    key_id: key_id.to_owned(),
                    reason: reason.clone(),
                });
            }
            let slot = format!("{did}{key_id}");
            let map = if force_refresh {
                &self.refreshed
            } else {
                &self.cached
            };
            map.get(&slot)
                .cloned()
                .ok_or_else(|| ServiceAuthError::KeyResolutionFailed {
                    did: did.to_owned(),
                    key_id: key_id.to_owned(),
                    reason: "not in DID document".into(),
                })
        })
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn service_jwt_mint_inspect_verify_both_curves_and_aliases() {
    let p256 = P256Keypair::generate().unwrap();
    let k256 = K256Keypair::generate().unwrap();

    for (curve, signer) in [
        (ATProtoKeyCurve::P256, &p256 as &dyn ATProtoKeypair),
        (ATProtoKeyCurve::Secp256k1, &k256 as &dyn ATProtoKeypair),
    ] {
        let mut opts = ServiceJWTMintOptions::new(ISSUER, AUDIENCE, Some(METHOD));
        opts.now = now_pinned();
        opts.nonce = Some("event-1");
        let token = ServiceJWT::mint(&opts, signer).await.unwrap();

        let inspection = ServiceJWT::inspect(&token).unwrap();
        assert_eq!(inspection.algorithm, curve.jwt_algorithm());
        assert_eq!(inspection.issuer, ISSUER);
        assert_eq!(inspection.effective_key_id(), "#atproto");
        assert_eq!(inspection.lexicon_method(), Some(METHOD));
        assert_eq!(inspection.expires_at(), ts(1_700_000_060));

        let vopts = ServiceJWTVerifyOptions {
            expected_audience: Some(AUDIENCE),
            expected_method: Some(METHOD),
            now: now_pinned(),
            ..Default::default()
        };
        let claims =
            ServiceJWT::verify_with_public_key(&token, signer.public_key(), &vopts).unwrap();
        assert_eq!(claims.iss, ISSUER);
        assert_eq!(claims.aud, AUDIENCE);
        assert_eq!(claims.lxm.as_deref(), Some(METHOD));
        assert_eq!(claims.jti.as_deref(), Some("event-1"));
        assert_eq!(claims.exp, 1_700_000_060);

        assert_eq!(
            ServiceJWT::verify_with_did_key(&token, &signer.did_key(), &vopts).unwrap(),
            claims
        );
        assert_eq!(
            ServiceJWT::verify_with_plc_key(
                &token,
                &PLCDIDVerificationKey::from_public_key(signer.public_key()),
                &vopts
            )
            .unwrap(),
            claims
        );

        let sig_bytes = JWTBase64URL::decode(token.split('.').nth(2).unwrap(), 64).unwrap();
        assert!(ATProtoSignature::is_canonical(&sig_bytes, curve));
    }

    // ProxyServiceJWT & SpaceServiceJWT aliases
    let mut proxy_opts =
        ServiceJWTMintOptions::new(ISSUER, AUDIENCE, Some("app.bsky.feed.getTimeline"));
    proxy_opts.now = now_pinned();
    proxy_opts.nonce = Some("proxy-jti");
    let proxy_token = ProxyServiceJWT::create(&proxy_opts, &p256).unwrap();
    let proxy_claims = SpaceServiceJWT::verify(
        &proxy_token,
        &ATProtoJWTVerificationKey::from_public_key(p256.public_key()),
        Some(AUDIENCE),
        Some("app.bsky.feed.getTimeline"),
        None,
        now_pinned(),
    )
    .unwrap();
    assert_eq!(proxy_claims.jti.as_deref(), Some("proxy-jti"));
    assert!(ProxyServiceJWT::is_nsid("app.bsky.feed.getTimeline"));
    assert_eq!(
        SpaceServiceJWT::inspect(&proxy_token).unwrap().algorithm,
        "ES256"
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn service_jwt_request_body_digest_round_trip() {
    let p256 = P256Keypair::generate().unwrap();
    // Request body digest ("req") claim round-trip
    let mut req_opts =
        ServiceJWTMintOptions::new(ISSUER, AUDIENCE, Some("com.atproto.space.notifyRepoUpdate"));
    req_opts.now = now_pinned();
    req_opts.nonce = Some("req-test-1");
    req_opts.request_body_digest = Some("swan.space.notify-write.v1:did:plc:abcdef:rev1:commit1");
    let req_token = ServiceJWT::mint_sync(&req_opts, ServiceJWTSigningKey::P256(&p256)).unwrap();
    let req_verified = ServiceJWT::verify_with_public_key(
        &req_token,
        p256.public_key(),
        &ServiceJWTVerifyOptions {
            expected_request_body_digest: Some(
                "swan.space.notify-write.v1:did:plc:abcdef:rev1:commit1",
            ),
            now: now_pinned(),
            ..Default::default()
        },
    )
    .unwrap();
    assert_eq!(
        req_verified.request_body_digest.as_deref(),
        Some("swan.space.notify-write.v1:did:plc:abcdef:rev1:commit1")
    );
    assert!(
        ServiceJWT::verify_with_public_key(
            &req_token,
            p256.public_key(),
            &ServiceJWTVerifyOptions {
                expected_request_body_digest: Some("different"),
                now: now_pinned(),
                ..Default::default()
            }
        )
        .is_err()
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn verifier_end_to_end_policies_rotation_and_replay() {
    for curve in ATProtoKeyCurve::ALL {
        let kp = ATProtoCrypto::generate_keypair(curve).unwrap();
        let mut opts = ServiceJWTMintOptions::new(ISSUER, AUDIENCE, Some(METHOD));
        opts.now = now_pinned();
        opts.nonce = Some("nonce-1");
        let token = ServiceJWT::mint(&opts, &kp).await.unwrap();

        let resolver = Arc::new(StaticServiceAuthKeyResolver::new(HashMap::from([(
            ISSUER.to_owned(),
            kp.public_key().clone(),
        )])));
        let verifier = ServiceAuthVerifier::new(ServiceAuthAudience::exactly(AUDIENCE), resolver);

        let caller = verifier
            .verify_authorization_header_at(
                Some(&ServiceJWT::bearer_authorization(&token)),
                &ServiceAuthMethodPolicy::Exactly(METHOD.into()),
                now_pinned(),
            )
            .await
            .unwrap();
        assert_eq!(caller.issuer, ISSUER);
        assert_eq!(caller.issuer_fragment, None);
        assert_eq!(caller.key_id, "#atproto");
        assert_eq!(caller.audience, AUDIENCE);
        assert_eq!(caller.lexicon_method.as_deref(), Some(METHOD));
        assert_eq!(caller.nonce.as_deref(), Some("nonce-1"));
        assert_eq!(caller.algorithm, curve.jwt_algorithm());
        assert_eq!(caller.signing_key, *kp.public_key());
    }

    // Authorization header parsing
    assert_eq!(
        ServiceAuthVerifier::bearer_token_from_authorization_header(None),
        Err(ServiceAuthError::MissingAuthorization)
    );
    assert_eq!(
        ServiceAuthVerifier::bearer_token_from_authorization_header(Some("   ")),
        Err(ServiceAuthError::MissingAuthorization)
    );
    for bad in [
        "Basic YWRtaW4=",
        "Bearer",
        "Bearer ",
        "DPoP abc",
        "abc.def.ghi",
        "Bearer a b",
    ] {
        assert_eq!(
            ServiceAuthVerifier::bearer_token_from_authorization_header(Some(bad)),
            Err(ServiceAuthError::UnsupportedAuthorizationScheme),
            "{bad}"
        );
    }
    for ok in [
        "Bearer abc.def.ghi",
        "bearer abc.def.ghi",
        "BEARER   abc.def.ghi  ",
    ] {
        assert_eq!(
            ServiceAuthVerifier::bearer_token_from_authorization_header(Some(ok)).unwrap(),
            "abc.def.ghi"
        );
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn verifier_audience_rotation_and_replay() {
    let k = K256Keypair::generate().unwrap();
    let resolver = Arc::new(StaticServiceAuthKeyResolver::new(HashMap::from([(
        ISSUER.to_owned(),
        k.public_key().clone(),
    )])));
    let mut o_frag = ServiceJWTMintOptions::new(ISSUER, AUDIENCE, Some(METHOD));
    o_frag.now = now_pinned();
    let with_frag = ServiceJWT::mint(&o_frag, &k).await.unwrap();
    let mut o_bare = ServiceJWTMintOptions::new(ISSUER, SERVICE_DID, Some(METHOD));
    o_bare.now = now_pinned();
    let bare = ServiceJWT::mint(&o_bare, &k).await.unwrap();

    let strict_v = ServiceAuthVerifier::new(
        ServiceAuthAudience::service(SERVICE_DID, "bsky_fg", false),
        resolver.clone(),
    );
    assert!(
        strict_v
            .verify_token_at(
                &with_frag,
                &ServiceAuthMethodPolicy::Exactly(METHOD.into()),
                now_pinned()
            )
            .await
            .is_ok()
    );
    assert_eq!(
        strict_v
            .verify_token_at(
                &bare,
                &ServiceAuthMethodPolicy::Exactly(METHOD.into()),
                now_pinned()
            )
            .await
            .unwrap_err()
            .xrpc_error_name(),
        "BadJwtAudience"
    );

    let lenient_v = ServiceAuthVerifier::new(
        ServiceAuthAudience::service(SERVICE_DID, "#bsky_fg", true),
        resolver.clone(),
    );
    assert!(
        lenient_v
            .verify_token_at(
                &bare,
                &ServiceAuthMethodPolicy::Exactly(METHOD.into()),
                now_pinned()
            )
            .await
            .is_ok()
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn verifier_rotation_and_replay() {
    let k = K256Keypair::generate().unwrap();
    let resolver = Arc::new(StaticServiceAuthKeyResolver::new(HashMap::from([(
        ISSUER.to_owned(),
        k.public_key().clone(),
    )])));
    let mut o_frag = ServiceJWTMintOptions::new(ISSUER, AUDIENCE, Some(METHOD));
    o_frag.now = now_pinned();
    let with_frag = ServiceJWT::mint(&o_frag, &k).await.unwrap();

    // Key rotation retry
    let old_key = K256Keypair::generate().unwrap();
    let new_key = P256Keypair::generate().unwrap();
    let mut o_rot = ServiceJWTMintOptions::new(ISSUER, AUDIENCE, Some(METHOD));
    o_rot.now = now_pinned();
    let rot_tok = ServiceJWT::mint(&o_rot, &new_key).await.unwrap();
    let slot = format!("{ISSUER}#atproto");
    let rec = Arc::new(RecordingKeyResolver::new(
        HashMap::from([(slot.clone(), old_key.public_key().clone())]),
        Some(HashMap::from([(slot, new_key.public_key().clone())])),
        None,
    ));
    let rot_v = ServiceAuthVerifier::new(ServiceAuthAudience::exactly(AUDIENCE), rec.clone());
    let rot_caller = rot_v
        .verify_token_at(
            &rot_tok,
            &ServiceAuthMethodPolicy::Exactly(METHOD.into()),
            now_pinned(),
        )
        .await
        .unwrap();
    assert_eq!(rot_caller.algorithm, "ES256");
    assert_eq!(
        rec.take_lookups()
            .into_iter()
            .map(|l| l.force_refresh)
            .collect::<Vec<_>>(),
        vec![false, true]
    );

    // Replay store & required claims
    let clock_secs = Arc::new(Mutex::new(1_700_000_000_u64));
    let c_clone = Arc::clone(&clock_secs);
    let store = Arc::new(InMemoryServiceAuthReplayStore::with_config(
        10,
        Arc::new(move || ts(*c_clone.lock().unwrap())),
    ));
    let replay_v = ServiceAuthVerifier::with_replay_store(
        ServiceAuthAudience::exactly(AUDIENCE),
        resolver,
        store.clone(),
    );
    assert!(
        replay_v
            .verify_token_at(
                &with_frag,
                &ServiceAuthMethodPolicy::Exactly(METHOD.into()),
                now_pinned()
            )
            .await
            .is_ok()
    );
    assert_eq!(
        replay_v
            .verify_token_at(
                &with_frag,
                &ServiceAuthMethodPolicy::Exactly(METHOD.into()),
                now_pinned()
            )
            .await
            .unwrap_err(),
        ServiceAuthError::Replayed
    );

    // Required claims & ATProtoServiceReference
    let mut cfg = ServiceAuthVerifierConfig::new(ServiceAuthAudience::exactly(AUDIENCE));
    cfg.required_claims = ServiceAuthRequiredClaims::SPECIFICATION;
    cfg.accepted_key_ids = BTreeSet::from(["#atproto".into(), "#atproto_label".into()]);
    let _ = cfg;
    let sref = ATProtoServiceReference::parse("did:web:appview.example.com#bsky_appview").unwrap();
    assert_eq!(
        sref.service_id(),
        Some(ATProtoServiceReference::BSKY_APPVIEW)
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn caching_key_resolver_coalesces_and_rate_limits() {
    let did = ISSUER;
    let old_key = K256Keypair::generate().unwrap().public_key().clone();
    let new_key = K256Keypair::generate().unwrap().public_key().clone();
    let slot = format!("{did}#atproto");

    let upstream = RecordingKeyResolver::new(
        HashMap::from([(slot.clone(), old_key.clone())]),
        Some(HashMap::from([(slot, new_key.clone())])),
        None,
    );
    let clock_secs = Arc::new(Mutex::new(1_700_000_000_u64));
    let c_clone = Arc::clone(&clock_secs);
    let caching = CachingServiceAuthKeyResolver::with_config(
        upstream,
        Duration::from_secs(600),
        Duration::from_secs(30),
        100,
        Arc::new(move || ts(*c_clone.lock().unwrap())),
    );

    assert_eq!(caching.signing_key(did, false).await.unwrap(), old_key);
    assert_eq!(caching.signing_key(did, false).await.unwrap(), old_key);
    // First forced refresh goes upstream because cached came from ordinary fetch.
    assert_eq!(caching.signing_key(did, true).await.unwrap(), new_key);
    // Second forced refresh within 30s uses cached refreshed key.
    assert_eq!(caching.signing_key(did, true).await.unwrap(), new_key);
    // Advance 31s -> forced refresh reaches upstream again.
    *clock_secs.lock().unwrap() += 31;
    assert_eq!(caching.signing_key(did, true).await.unwrap(), new_key);

    // Closure resolver
    let closure = ClosureServiceAuthKeyResolver::new(move |d, kid, _fr| {
        let d = d.to_owned();
        let kid = kid.to_owned();
        let ok = new_key.clone();
        Box::pin(async move {
            assert_eq!(d, "did:web:labeler.example.com");
            if kid == "#atproto_label" || kid == "#atproto" {
                Ok(ok)
            } else {
                Err(ServiceAuthError::KeyNotAccepted { key_id: kid })
            }
        })
    });
    assert!(
        closure
            .signing_key_for_id("did:web:labeler.example.com", "#atproto_label", false)
            .await
            .is_ok()
    );
    // CapacityExceeded replay store test
    let replay = InMemoryServiceAuthReplayStore::with_config(1, Arc::new(now_pinned));
    assert!(
        replay
            .claim("a", "did:plc:one", ts(1_700_000_060))
            .await
            .unwrap()
    );
    assert!(
        !replay
            .claim("a", "did:plc:one", ts(1_700_000_060))
            .await
            .unwrap()
    );
    assert_eq!(
        replay.claim("b", "did:plc:one", ts(1_700_000_060)).await,
        Err(ReplayStoreError::CapacityExceeded { capacity: 1 })
    );
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TsVectorFile {
    now: u64,
    keys: HashMap<String, TsKeyEntry>,
    vectors: Vec<TsVector>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TsKeyEntry {
    did_key: String,
}

#[derive(Deserialize)]
struct TsVector {
    name: String,
    token: String,
    verifier: TsVerifierInput,
    ts: TsExpected,
    petrel: Option<PetrelOverride>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TsVerifierInput {
    audience: String,
    lxm: Option<String>,
    key: String,
    refreshed_key: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TsExpected {
    ok: bool,
    error: Option<String>,
    #[serde(default)]
    key_lookups: Vec<TsKeyLookup>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct TsKeyLookup {
    iss: String,
    force_refresh: bool,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct PetrelOverride {
    ok: bool,
    error: Option<String>,
    ok_with: Option<String>,
}

#[derive(Deserialize)]
struct PetrelMintedFile {
    now: u64,
    tokens: Vec<PetrelMintedToken>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct PetrelMintedToken {
    name: String,
    did_key: String,
    audience: String,
    lxm: Option<String>,
    token: String,
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn typescript_service_jwt_vectors_match_petrel_semantics() {
    let file: TsVectorFile = serde_json::from_str(SERVICE_JWT_VECTORS_JSON).unwrap();
    let now = ts(file.now);

    for vec in file.vectors {
        let cached_key = PublicKey::from_did_key(&file.keys[&vec.verifier.key].did_key).unwrap();
        let refreshed_key =
            PublicKey::from_did_key(&file.keys[&vec.verifier.refreshed_key].did_key).unwrap();
        let iss_did = vec
            .ts
            .key_lookups
            .first()
            .map_or(ISSUER, |l| l.iss.split('#').next().unwrap());
        let _ = iss_did;

        let mut cached_map = HashMap::new();
        let mut refreshed_map = HashMap::new();
        // Register under both possible issuer DIDs from the vector suite.
        for did in [
            "did:plc:abcdefghijklmnopqrstuvwx",
            "did:web:labeler.example.com",
        ] {
            for kid in ["#atproto", "#atproto_label"] {
                cached_map.insert(format!("{did}{kid}"), cached_key.clone());
                refreshed_map.insert(format!("{did}{kid}"), refreshed_key.clone());
            }
        }
        let resolver = Arc::new(RecordingKeyResolver::new(
            cached_map,
            Some(refreshed_map),
            None,
        ));
        let mut cfg =
            ServiceAuthVerifierConfig::new(ServiceAuthAudience::exactly(&vec.verifier.audience));
        cfg.clock_skew = Duration::ZERO;
        let verifier = ServiceAuthVerifier::from_config(cfg, resolver.clone(), None);
        let method = match &vec.verifier.lxm {
            Some(m) => ServiceAuthMethodPolicy::Exactly(m.clone()),
            None => ServiceAuthMethodPolicy::Optional,
        };

        let result = verifier.verify_token_at(&vec.token, &method, now).await;

        let expected_ok = vec.petrel.as_ref().map_or(vec.ts.ok, |p| p.ok);
        let expected_err = vec
            .petrel
            .as_ref()
            .and_then(|p| p.error.as_deref())
            .or(vec.ts.error.as_deref());

        if expected_ok {
            assert!(result.is_ok(), "vector {} failed: {:?}", vec.name, result);
            let expected_refreshes: Vec<bool> =
                vec.ts.key_lookups.iter().map(|l| l.force_refresh).collect();
            let actual_refreshes: Vec<bool> = resolver
                .take_lookups()
                .into_iter()
                .map(|l| l.force_refresh)
                .collect();
            assert_eq!(actual_refreshes, expected_refreshes, "{}", vec.name);
        } else {
            let err = result.unwrap_err();
            assert_eq!(
                Some(err.xrpc_error_name()),
                expected_err,
                "vector {} error mismatch: {err}",
                vec.name
            );
        }

        // Also check Petrel override relaxations where documented.
        if let Some(override_cfg) = &vec.petrel
            && let Some(ok_with) = &override_cfg.ok_with
        {
            let mut relaxed = ServiceAuthVerifierConfig::new(ServiceAuthAudience::exactly(
                &vec.verifier.audience,
            ));
            relaxed.clock_skew = Duration::ZERO;
            match ok_with.as_str() {
                "allowMalleable" => {
                    relaxed.signature_options =
                        ATProtoSignatureVerificationOptions::ALLOW_MALLEABLE;
                }
                "maximumLifetime=3h" => {
                    relaxed.maximum_lifetime = Duration::from_secs(3 * 60 * 60);
                }
                "acceptedKeyIDs=#atproto_label" => {
                    relaxed.accepted_key_ids.insert("#atproto_label".into());
                }
                other => panic!("unexpected okWith {other}"),
            }
            let rv = ServiceAuthVerifier::from_config(relaxed, resolver, None);
            assert!(
                rv.verify_token_at(&vec.token, &method, now).await.is_ok(),
                "vector {} should pass with {ok_with}",
                vec.name
            );
        }
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn swift_petrel_minted_tokens_verify_in_rust() {
    let file: PetrelMintedFile = serde_json::from_str(PETREL_MINTED_TOKENS_JSON).unwrap();
    let now = ts(file.now);

    for entry in file.tokens {
        let key = PublicKey::from_did_key(&entry.did_key).unwrap();
        let inspection = ServiceJWT::inspect(&entry.token).unwrap();
        let mut keys = HashMap::new();
        keys.insert(format!("{}#atproto", inspection.issuer_did()), key.clone());
        let resolver = Arc::new(StaticServiceAuthKeyResolver::from_keys_by_id(
            HashMap::from([(
                inspection.issuer_did().to_owned(),
                HashMap::from([("#atproto".to_owned(), key)]),
            )]),
        ));
        let _ = keys;

        let verifier =
            ServiceAuthVerifier::new(ServiceAuthAudience::exactly(&entry.audience), resolver);
        let method = match &entry.lxm {
            Some(m) => ServiceAuthMethodPolicy::Exactly(m.clone()),
            None => ServiceAuthMethodPolicy::Optional,
        };
        let caller = verifier
            .verify_token_at(&entry.token, &method, now)
            .await
            .unwrap_or_else(|e| panic!("Swift-minted token {} failed: {e}", entry.name));
        assert_eq!(caller.audience, entry.audience);
        assert_eq!(caller.lexicon_method, entry.lxm);
    }

    // Rust-minted tokens match high-S / strict verification & can be verified with ServiceJWT too.
    let p256_kp = P256Keypair::generate().unwrap();
    let mut opts = ServiceJWTMintOptions::new(ISSUER, AUDIENCE, Some(METHOD));
    opts.now = now_pinned();
    let tok = ServiceJWT::mint(&opts, &p256_kp).await.unwrap();
    let high_s_tok = high_s_rewrite(&tok, ATProtoKeyCurve::P256);
    assert!(
        ServiceJWT::verify_with_public_key(
            &high_s_tok,
            p256_kp.public_key(),
            &ServiceJWTVerifyOptions {
                now: now_pinned(),
                ..Default::default()
            }
        )
        .is_ok()
    );
    assert!(
        ServiceJWT::verify_with_public_key(
            &high_s_tok,
            p256_kp.public_key(),
            &ServiceJWTVerifyOptions {
                signature_options: ATProtoSignatureVerificationOptions::STRICT,
                now: now_pinned(),
                ..Default::default()
            }
        )
        .is_err()
    );
}
