#![cfg(not(target_arch = "wasm32"))]

mod common;

use std::collections::HashMap;
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr};
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};

use async_lock::Mutex;
use common::{TEST_ISSUER, TestClock};
use petrel::rt::BoxFuture;
use petrel_server::OAuthServerError;
use petrel_server::clients::{
    ClientAuthCredentials, OAuthApplicationType, OAuthClientAssertionValidator, OAuthClientKind,
    OAuthClientMetadata, OAuthClientMetadataLoader, OAuthClientResolving, OAuthPublicAddressPolicy,
    OAuthRemoteFetchPolicy, OAuthRemoteFetchResponse, OAuthRemoteTransport,
    OAuthResolvedClientMetadata, OAuthTokenEndpointAuthMethod, StaticOAuthClientResolver,
};
use petrel_server::http::OAuthHttpHeaders;
use petrel_server::jose::{
    OAuthCompactJwt, OAuthJsonWebKeySet, OAuthJwsAlgorithm, OAuthSigningKey,
};
use petrel_server::store::InMemoryOAuthStore;
use petrel_server::support::OAuthClock;
use serde::Serialize;
use url::Url;

#[test]
fn ssrf_policy_blocks_private_loopback_cgnat_teredo_6to4_and_mapped_v6() {
    let policy = OAuthPublicAddressPolicy::default();
    assert!(policy.is_public_ip(IpAddr::V4(Ipv4Addr::new(1, 1, 1, 1))));
    assert!(policy.is_public_ip(IpAddr::V6("2606:4700:4700::1111".parse().unwrap())));

    for blocked in [
        "127.0.0.1",
        "10.0.0.1",
        "172.16.0.1",
        "192.168.1.1",
        "169.254.169.254",
        "100.64.0.1",
        "198.18.0.1",
        "0.0.0.0",
        "224.0.0.1",
        "::1",
        "::",
        "fc00::1",
        "fe80::1",
        "2001:db8::1",
        "2002:7f00:0001::1",
        "2001::1",
        "::ffff:127.0.0.1",
        "::ffff:10.0.0.1",
        "64:ff9b::7f00:1",
    ] {
        let ip: IpAddr = blocked.parse().unwrap();
        assert!(!policy.is_public_ip(ip), "expected blocked IP: {blocked}");
    }

    assert!(
        policy
            .validate_url(&Url::parse("http://example.com/client.json").unwrap())
            .is_err()
    );
    assert!(
        policy
            .validate_url(&Url::parse("https://127.0.0.1/client.json").unwrap())
            .is_err()
    );
    assert!(
        policy
            .validate_url(&Url::parse("https://user:pw@example.com/client.json").unwrap())
            .is_err()
    );
    assert!(
        policy
            .validate_url(&Url::parse("https://example.com/client.json").unwrap())
            .is_ok()
    );
}

#[tokio::test]
async fn loopback_client_synthesis_validates_redirects_and_scopes() {
    let resolver = StaticOAuthClientResolver::new();
    let default = resolver.resolve("http://localhost").await.unwrap();
    assert_eq!(default.kind, OAuthClientKind::Loopback);
    assert!(
        default
            .metadata
            .redirect_uris
            .contains(&"http://127.0.0.1/".to_owned())
    );

    let with_params = resolver
        .resolve("http://localhost?redirect_uri=http%3A%2F%2F127.0.0.1%3A9999%2Fcb&scope=atproto%20transition%3Ageneric")
        .await
        .unwrap();
    assert_eq!(
        with_params.metadata.redirect_uris,
        vec!["http://127.0.0.1:9999/cb"]
    );

    assert!(resolver.resolve("http://localhost:8080").await.is_err());
    assert!(
        resolver
            .resolve("http://localhost?redirect_uri=https%3A%2F%2Fevil.example%2Fcb")
            .await
            .is_err()
    );
}

#[test]
fn client_metadata_validation_enforces_atproto_profile() {
    let valid = serde_json::json!({
        "client_id": "https://app.example.com/oauth/client.json",
        "application_type": "web",
        "grant_types": ["authorization_code", "refresh_token"],
        "response_types": ["code"],
        "redirect_uris": ["https://app.example.com/cb"],
        "scope": "atproto transition:generic",
        "token_endpoint_auth_method": "none",
        "dpop_bound_access_tokens": true
    })
    .to_string();
    assert!(
        OAuthClientMetadata::decode_validated(
            "https://app.example.com/oauth/client.json",
            valid.as_bytes()
        )
        .is_ok()
    );

    // Mismatched host in redirect_uri for web app
    let bad_redirect = serde_json::json!({
        "client_id": "https://app.example.com/oauth/client.json",
        "application_type": "web",
        "grant_types": ["authorization_code"],
        "response_types": ["code"],
        "redirect_uris": ["https://other.example.com/cb"],
        "scope": "atproto",
        "token_endpoint_auth_method": "none",
        "dpop_bound_access_tokens": true
    })
    .to_string();
    assert!(
        OAuthClientMetadata::decode_validated(
            "https://app.example.com/oauth/client.json",
            bad_redirect.as_bytes()
        )
        .is_err()
    );

    // Native custom scheme must match reverse DNS of client_id host
    let native_ok = serde_json::json!({
        "client_id": "https://chat.example.com/oauth-client.json",
        "application_type": "native",
        "grant_types": ["authorization_code"],
        "response_types": ["code"],
        "redirect_uris": ["com.example.chat:/callback"],
        "scope": "atproto",
        "token_endpoint_auth_method": "none",
        "dpop_bound_access_tokens": true
    })
    .to_string();
    assert!(
        OAuthClientMetadata::decode_validated(
            "https://chat.example.com/oauth-client.json",
            native_ok.as_bytes()
        )
        .is_ok()
    );

    // Non-DPoP public client rejected
    let no_dpop = serde_json::json!({
        "client_id": "https://app.example.com/oauth/client.json",
        "application_type": "web",
        "grant_types": ["authorization_code"],
        "response_types": ["code"],
        "redirect_uris": ["https://app.example.com/cb"],
        "scope": "atproto",
        "token_endpoint_auth_method": "none",
        "dpop_bound_access_tokens": false
    })
    .to_string();
    assert!(
        OAuthClientMetadata::decode_validated(
            "https://app.example.com/oauth/client.json",
            no_dpop.as_bytes()
        )
        .is_err()
    );
}

struct MockRemoteTransport {
    calls: AtomicUsize,
    responses: Mutex<HashMap<String, Vec<OAuthRemoteFetchResponse>>>,
}

impl MockRemoteTransport {
    fn new() -> Self {
        Self {
            calls: AtomicUsize::new(0),
            responses: Mutex::new(HashMap::new()),
        }
    }

    async fn push(&self, url: &str, resp: OAuthRemoteFetchResponse) {
        self.responses
            .lock()
            .await
            .entry(url.to_owned())
            .or_default()
            .push(resp);
    }
}

impl OAuthRemoteTransport for MockRemoteTransport {
    fn fetch<'a>(
        &'a self,
        url: &'a Url,
        _etag: Option<&'a str>,
        _policy: &'a OAuthRemoteFetchPolicy,
    ) -> BoxFuture<'a, Result<OAuthRemoteFetchResponse, OAuthServerError>> {
        let key = url.as_str().to_owned();
        Box::pin(async move {
            self.calls.fetch_add(1, Ordering::SeqCst);
            let mut map = self.responses.lock().await;
            let queue = map
                .get_mut(&key)
                .ok_or_else(|| OAuthServerError::Unavailable("no mock response".into()))?;
            if queue.is_empty() {
                return Err(OAuthServerError::Unavailable("exhausted responses".into()));
            }
            Ok(queue.remove(0))
        })
    }
}

#[tokio::test]
async fn client_metadata_loader_caches_handles_304_and_fetches_jwks_uri() {
    let client_id = "https://remote.example.com/client.json";
    let jwks_uri = "https://remote.example.com/jwks.json";
    let key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("k1".into())).unwrap();
    let jwks_bytes = serde_json::to_vec(&OAuthJsonWebKeySet::new(vec![
        key.public_jwk(true).unwrap(),
    ]))
    .unwrap();
    let doc_bytes = serde_json::to_vec(&serde_json::json!({
        "client_id": client_id,
        "application_type": "web",
        "grant_types": ["authorization_code", "refresh_token"],
        "response_types": ["code"],
        "redirect_uris": ["https://remote.example.com/cb"],
        "scope": "atproto transition:generic",
        "token_endpoint_auth_method": "private_key_jwt",
        "token_endpoint_auth_signing_alg": "ES256",
        "dpop_bound_access_tokens": true,
        "jwks_uri": jwks_uri
    }))
    .unwrap();

    let transport = Arc::new(MockRemoteTransport::new());
    let mut h1 = OAuthHttpHeaders::default();
    h1.set("ETag", "\"v1\"");
    transport
        .push(
            client_id,
            OAuthRemoteFetchResponse {
                status: 200,
                headers: h1,
                body: doc_bytes,
            },
        )
        .await;
    transport
        .push(
            jwks_uri,
            OAuthRemoteFetchResponse {
                status: 200,
                headers: OAuthHttpHeaders::default(),
                body: jwks_bytes.clone(),
            },
        )
        .await;
    transport
        .push(
            client_id,
            OAuthRemoteFetchResponse {
                status: 304,
                headers: OAuthHttpHeaders::default(),
                body: Vec::new(),
            },
        )
        .await;
    transport
        .push(
            jwks_uri,
            OAuthRemoteFetchResponse {
                status: 200,
                headers: OAuthHttpHeaders::default(),
                body: jwks_bytes.clone(),
            },
        )
        .await;
    transport
        .push(
            jwks_uri,
            OAuthRemoteFetchResponse {
                status: 200,
                headers: OAuthHttpHeaders::default(),
                body: jwks_bytes,
            },
        )
        .await;

    let clock = Arc::new(TestClock::new(1_700_000_000));
    let cache = Arc::new(InMemoryOAuthStore::new());
    let loader = OAuthClientMetadataLoader::new(transport.clone(), cache).with_clock(clock.clone());

    let first = loader.resolve(client_id).await.unwrap();
    assert_eq!(first.kind, OAuthClientKind::Discoverable);
    assert!(first.key_set.is_some());
    assert_eq!(transport.calls.load(Ordering::SeqCst), 2);

    // Within TTL (300s): metadata and jwks_uri both come from cache (no extra transport calls).
    clock.advance(60);
    let _second = loader.resolve(client_id).await.unwrap();
    assert_eq!(transport.calls.load(Ordering::SeqCst), 2);

    // Past TTL (301s total): conditional GET returns 304 and refreshes jwks_uri.
    clock.advance(300);
    let third = loader.resolve(client_id).await.unwrap();
    assert_eq!(third.metadata.client_id, client_id);
    assert_eq!(transport.calls.load(Ordering::SeqCst), 4);
}

#[tokio::test]
async fn client_assertion_validator_rejects_replay_wrong_sub_wrong_aud_and_oversized_lifetime() {
    #[derive(Serialize)]
    struct Claims<'a> {
        iss: &'a str,
        sub: &'a str,
        aud: &'a str,
        jti: &'a str,
        iat: i64,
        exp: i64,
    }
    let clock = Arc::new(TestClock::new(1_700_000_000));
    let store = Arc::new(InMemoryOAuthStore::new());
    let digest = petrel_server::support::OAuthKeyedDigest::new(vec![5; 32]).unwrap();
    let validator = OAuthClientAssertionValidator::new(TEST_ISSUER, digest, store, clock.clone());

    let key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("c1".into())).unwrap();
    let jwks = OAuthJsonWebKeySet::new(vec![key.public_jwk(true).unwrap()]);
    let client_id = "https://conf.example.com/client.json";
    let now = clock.now_secs();
    let resolved = OAuthResolvedClientMetadata {
        kind: OAuthClientKind::Discoverable,
        metadata: OAuthClientMetadata {
            client_id: client_id.to_owned(),
            client_name: None,
            client_uri: None,
            logo_uri: None,
            tos_uri: None,
            policy_uri: None,
            application_type: OAuthApplicationType::Web,
            grant_types: vec!["authorization_code".into()],
            response_types: vec!["code".into()],
            redirect_uris: vec!["https://conf.example.com/cb".into()],
            scope: Some("atproto".into()),
            token_endpoint_auth_method: OAuthTokenEndpointAuthMethod::PrivateKeyJwt,
            token_endpoint_auth_signing_alg: Some("ES256".into()),
            dpop_bound_access_tokens: true,
            jwks_uri: None,
            jwks: Some(jwks.clone()),
        },
        key_set: Some(jwks),
    };
    let good = OAuthCompactJwt::sign(
        &Claims {
            iss: client_id,
            sub: client_id,
            aud: TEST_ISSUER,
            jti: "ca-1",
            iat: now,
            exp: now + 60,
        },
        &key,
        None,
        false,
    )
    .unwrap();
    let creds = ClientAuthCredentials {
        client_id,
        client_assertion_type: Some(
            OAuthClientAssertionValidator::CLIENT_ASSERTION_TYPE_JWT_BEARER,
        ),
        client_assertion: Some(&good),
    };
    validator.authenticate(&resolved, &creds).await.unwrap();
    // Replay rejected
    assert!(validator.authenticate(&resolved, &creds).await.is_err());

    // Wrong lifetime (> 60s)
    let long_life = OAuthCompactJwt::sign(
        &Claims {
            iss: client_id,
            sub: client_id,
            aud: TEST_ISSUER,
            jti: "ca-2",
            iat: now,
            exp: now + 120,
        },
        &key,
        None,
        false,
    )
    .unwrap();
    assert!(
        validator
            .authenticate(
                &resolved,
                &ClientAuthCredentials {
                    client_id,
                    client_assertion_type: Some(
                        OAuthClientAssertionValidator::CLIENT_ASSERTION_TYPE_JWT_BEARER
                    ),
                    client_assertion: Some(&long_life),
                },
            )
            .await
            .is_err()
    );
    let _ = Ipv6Addr::LOCALHOST;
}

#[tokio::test]
async fn client_assertion_validator_enforces_cnf_jkt_dpop_binding() {
    let clock = Arc::new(TestClock::new(1_700_000_000));
    let store = Arc::new(InMemoryOAuthStore::new());
    let digest = petrel_server::support::OAuthKeyedDigest::new(vec![5; 32]).unwrap();
    let validator = OAuthClientAssertionValidator::new(TEST_ISSUER, digest, store, clock.clone());

    let key = OAuthSigningKey::generate(OAuthJwsAlgorithm::Es256, Some("c1".into())).unwrap();
    let jwks = OAuthJsonWebKeySet::new(vec![key.public_jwk(true).unwrap()]);
    let client_id = "https://conf.example.com/client.json";
    let now = clock.now_secs();
    let resolved = OAuthResolvedClientMetadata {
        kind: OAuthClientKind::Discoverable,
        metadata: OAuthClientMetadata {
            client_id: client_id.to_owned(),
            client_name: None,
            client_uri: None,
            logo_uri: None,
            tos_uri: None,
            policy_uri: None,
            application_type: OAuthApplicationType::Web,
            grant_types: vec!["authorization_code".into()],
            response_types: vec!["code".into()],
            redirect_uris: vec!["https://conf.example.com/cb".into()],
            scope: Some("atproto".into()),
            token_endpoint_auth_method: OAuthTokenEndpointAuthMethod::PrivateKeyJwt,
            token_endpoint_auth_signing_alg: Some("ES256".into()),
            dpop_bound_access_tokens: true,
            jwks_uri: None,
            jwks: Some(jwks.clone()),
        },
        key_set: Some(jwks),
    };
    let bound = OAuthCompactJwt::sign(
        &serde_json::json!({
            "iss": client_id,
            "sub": client_id,
            "aud": TEST_ISSUER,
            "jti": "ca-cnf-1",
            "iat": now,
            "exp": now + 60,
            "cnf": { "jkt": "thumbprint-good" }
        }),
        &key,
        None,
        false,
    )
    .unwrap();
    let bound_creds = ClientAuthCredentials {
        client_id,
        client_assertion_type: Some(
            OAuthClientAssertionValidator::CLIENT_ASSERTION_TYPE_JWT_BEARER,
        ),
        client_assertion: Some(&bound),
    };
    assert!(
        validator
            .authenticate_with_dpop(&resolved, &bound_creds, Some("thumbprint-other"))
            .await
            .is_err()
    );
    assert!(
        validator
            .authenticate_with_dpop(&resolved, &bound_creds, None)
            .await
            .is_err()
    );
    validator
        .authenticate_with_dpop(&resolved, &bound_creds, Some("thumbprint-good"))
        .await
        .expect("matching DPoP thumbprint accepted");
}

#[tokio::test]
async fn client_metadata_loader_negative_caches_failures_and_purges_expired_metadata() {
    use petrel_server::store::{
        OAuthCachedClientMetadata, OAuthClientMetadataCache, OAuthStorePurging,
    };

    let client_id = "https://failing.example.com/client.json";
    let transport = Arc::new(MockRemoteTransport::new());
    transport
        .push(
            client_id,
            OAuthRemoteFetchResponse {
                status: 500,
                headers: OAuthHttpHeaders::default(),
                body: Vec::new(),
            },
        )
        .await;

    let clock = Arc::new(TestClock::new(1_700_000_000));
    let cache = Arc::new(InMemoryOAuthStore::new());
    let loader =
        OAuthClientMetadataLoader::new(transport.clone(), cache.clone()).with_clock(clock.clone());

    assert!(loader.resolve(client_id).await.is_err());
    assert_eq!(transport.calls.load(Ordering::SeqCst), 1);

    // Within 30s negative cache TTL: second resolve fails fast without triggering another fetch
    assert!(loader.resolve(client_id).await.is_err());
    assert_eq!(transport.calls.load(Ordering::SeqCst), 1);

    // purge_expired evicts expired client_metadata entries
    cache
        .put_cached_metadata(OAuthCachedClientMetadata {
            client_id: "https://expired.example.com/c.json".into(),
            raw_json: b"{}".to_vec(),
            fetched_at_secs: 1_700_000_000,
            expires_at_secs: 1_700_000_100,
            stale_until_secs: 1_700_000_200,
            etag: None,
        })
        .await
        .unwrap();
    clock.advance(500);
    assert!(cache.purge_expired(clock.now_secs()).await.unwrap() >= 1);
    assert!(
        cache
            .get_cached_metadata("https://expired.example.com/c.json")
            .await
            .unwrap()
            .is_none()
    );
}

#[tokio::test]
async fn matches_redirect_uri_port_insensitive_only_for_localhost_clients() {
    let resolver = StaticOAuthClientResolver::new();
    let default_loopback = resolver.resolve("http://localhost").await.unwrap().metadata;
    assert!(default_loopback.matches_redirect_uri("http://127.0.0.1:49152/"));
    assert!(default_loopback.matches_redirect_uri("http://[::1]:49152/"));
    assert!(default_loopback.matches_redirect_uri("http://127.0.0.1/"));
    assert!(!default_loopback.matches_redirect_uri("http://127.0.0.1:49152/callback"));
    assert!(!default_loopback.matches_redirect_uri("https://127.0.0.1:49152/"));
    assert!(!default_loopback.matches_redirect_uri("http://localhost:49152/"));
    assert!(!default_loopback.matches_redirect_uri("http://127.0.0.1:49152/?q=1"));

    let custom_loopback = resolver
        .resolve("http://localhost?redirect_uri=http%3A%2F%2F127.0.0.1%2Fcb%3Fv%3D1&scope=atproto")
        .await
        .unwrap()
        .metadata;
    assert!(custom_loopback.matches_redirect_uri("http://127.0.0.1:54321/cb?v=1"));
    assert!(!custom_loopback.matches_redirect_uri("http://127.0.0.1:54321/cb"));
    assert!(!custom_loopback.matches_redirect_uri("http://127.0.0.1:54321/other?v=1"));

    let standard_native = OAuthClientMetadata {
        client_id: "https://app.example.com/client.json".into(),
        client_name: None,
        client_uri: None,
        logo_uri: None,
        tos_uri: None,
        policy_uri: None,
        application_type: OAuthApplicationType::Native,
        grant_types: vec!["authorization_code".into()],
        response_types: vec!["code".into()],
        redirect_uris: vec!["http://127.0.0.1:8080/cb".into()],
        scope: Some("atproto".into()),
        token_endpoint_auth_method: OAuthTokenEndpointAuthMethod::None,
        token_endpoint_auth_signing_alg: None,
        dpop_bound_access_tokens: true,
        jwks_uri: None,
        jwks: None,
    };
    assert!(standard_native.matches_redirect_uri("http://127.0.0.1:8080/cb"));
    assert!(!standard_native.matches_redirect_uri("http://127.0.0.1:9090/cb"));
}
