#![cfg(test)]

#[cfg(target_arch = "wasm32")]
wasm_bindgen_test::wasm_bindgen_test_configure!(run_in_browser);

use std::collections::{BTreeMap, HashSet};
use std::future::Future;
use std::pin::Pin;
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll, Waker};

use bytes::Bytes;
use http::{Request, Response, StatusCode};
use petrel::net::{HttpTransport, SendOptions, SharedTransport, TransportError};
use petrel_api::generated::com::atproto::memberspace::policy::Policy as MemberspacePolicy;
use petrel_api::generated::com::atproto::space::{
    authorize_space_sync::Input as AuthorizeSpaceSyncInput,
    confirm_registration::Output as ConfirmRegistrationOutput,
    defs::Commit,
    get_latest_commit::Output as GetLatestCommitOutput,
    get_record::Output as GetRecordOutput,
    get_space::OutputPolicy,
    list_repo_ops::{OpEntry, Output as ListRepoOpsOutput},
    notify_repo_update::Input as NotifyRepoUpdateInput,
    remove_writer::Input as RemoveWriterInput,
};
use petrel_core::{
    Bytes as AtBytes, Cid, CidString, Did, Nsid, RecordKey, SpaceRef, Tid, Value, dagcbor::encode,
};
use petrel_crypto::SpaceSetHash;
use petrel_spaces::{
    CredentialExchanger, HttpCredentialExchanger, InMemorySpaceHostBackend, SigningKeyPair,
    SpaceCredential, SpaceCredentialManager, SpaceDidDocument, SpaceError, SpaceHost,
    SpaceHostResolver, SpaceSyncEngine, StaticDidResolver, classify_authorize_space_sync_error,
    decapsulate_p256, did_document_url, extract_authority_endpoints, generate_p256_keypair,
    mint_credential_token, mint_delegation_token, parse_accept_signature, parse_space_ref,
    sign_commit_mac, sign_record_mac, write_star_repo,
};
use url::Url;

fn block_on<F: Future>(fut: F) -> F::Output {
    let waker = Waker::noop().clone();
    let mut cx = Context::from_waker(&waker);
    let mut pinned = Box::pin(fut);
    match Pin::as_mut(&mut pinned).poll(&mut cx) {
        Poll::Ready(val) => val,
        Poll::Pending => panic!("unexpected Pending in synchronous mock test future"),
    }
}

type RouteHandler = Box<dyn Fn(&Request<Bytes>) -> Option<Response<Bytes>> + Send + Sync>;

#[derive(Default)]
struct ScriptedTransport {
    routes: Mutex<Vec<RouteHandler>>,
}

impl ScriptedTransport {
    fn push<F>(&self, handler: F)
    where
        F: Fn(&Request<Bytes>) -> Option<Response<Bytes>> + Send + Sync + 'static,
    {
        self.routes.lock().unwrap().push(Box::new(handler));
    }
}

impl HttpTransport for ScriptedTransport {
    fn send(
        &self,
        request: Request<Bytes>,
        _options: &SendOptions,
    ) -> impl Future<Output = Result<Response<Bytes>, TransportError>> + petrel::rt::MaybeSend {
        let result = {
            let guard = self.routes.lock().unwrap();
            let mut matched = None;
            for handler in guard.iter().rev() {
                if let Some(resp) = handler(&request) {
                    matched = Some(resp);
                    break;
                }
            }
            matched.ok_or_else(|| {
                TransportError::Other(format!(
                    "unhandled mock request: {} {}",
                    request.method(),
                    request.uri()
                ))
            })
        };
        std::future::ready(result)
    }
}

struct LocalMinter {
    reader_did: Did,
    reader_kp: SigningKeyPair,
    host_did: Did,
    now: i64,
}

impl petrel_spaces::DelegationMinter for LocalMinter {
    fn get_delegation_token<'a>(
        &'a self,
        space: &'a SpaceRef,
    ) -> petrel_spaces::BoxFuture<'a, petrel_spaces::Result<String>> {
        Box::pin(async move {
            mint_delegation_token(
                &self.reader_kp,
                &self.reader_did,
                &self.host_did,
                space,
                self.now,
                self.now + 60,
                None,
                None,
            )
        })
    }
}

fn json_resp(status: u16, body: &impl serde::Serialize) -> Response<Bytes> {
    Response::builder()
        .status(status)
        .header("content-type", "application/json")
        .body(Bytes::from(serde_json::to_vec(body).unwrap()))
        .unwrap()
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn host_resolver_did_document_urls_and_jwk_kem_extraction() {
    let plc_base = Url::parse("https://plc.directory").unwrap();

    let plc_did = Did::parse("did:plc:ewvi7nxzyoun6zhxrhs64oiz").unwrap();
    assert_eq!(
        did_document_url(&plc_did, &plc_base, false)
            .unwrap()
            .as_str(),
        "https://plc.directory/did:plc:ewvi7nxzyoun6zhxrhs64oiz"
    );

    let web_did = Did::parse("did:web:space.example.com").unwrap();
    assert_eq!(
        did_document_url(&web_did, &plc_base, false)
            .unwrap()
            .as_str(),
        "https://space.example.com/.well-known/did.json"
    );

    // Subpaths and non-localhost ports in did:web must be rejected
    let path_did = Did::parse("did:web:example.com:users:alice").unwrap();
    assert!(did_document_url(&path_did, &plc_base, false).is_err());
    let port_did = Did::parse("did:web:example.com%3A8443").unwrap();
    assert!(did_document_url(&port_did, &plc_base, false).is_err());

    // JWK #atproto signing + #atproto_kem + #atproto_space vs #atproto_pds preference
    let kp = SigningKeyPair::generate_p256().unwrap();
    let pub_uncomp = kp.public_key().uncompressed_representation();
    let x_b64 = petrel_crypto::JWTBase64URL::encode(&pub_uncomp[1..33]);
    let y_b64 = petrel_crypto::JWTBase64URL::encode(&pub_uncomp[33..65]);
    let (_, kem_did_key) = generate_p256_keypair().unwrap();
    let kem_mb = kem_did_key.strip_prefix("did:key:").unwrap();

    let doc_json = serde_json::json!({
        "id": "did:web:space.example.com",
        "service": [
            { "id": "#atproto_pds", "type": "AtprotoPersonalDataServer", "serviceEndpoint": "https://pds.example.com" },
            { "id": "#atproto_space", "type": "AtprotoSpaceHost", "serviceEndpoint": "https://space.example.com" }
        ],
        "verificationMethod": [
            {
                "id": "did:web:space.example.com#atproto",
                "type": "JsonWebKey2020",
                "controller": "did:web:space.example.com",
                "publicKeyJwk": { "kty": "EC", "crv": "P-256", "x": x_b64, "y": y_b64 }
            },
            {
                "id": "did:web:space.example.com#atproto_kem",
                "type": "P256KeyAgreement",
                "controller": "did:web:space.example.com",
                "publicKeyMultibase": kem_mb
            }
        ]
    });
    let doc = SpaceDidDocument::from_json_bytes(&serde_json::to_vec(&doc_json).unwrap()).unwrap();
    let endpoints = extract_authority_endpoints(&doc, false).unwrap();
    assert_eq!(endpoints.service_url.as_str(), "https://space.example.com/");
    assert_eq!(endpoints.service_type, "AtprotoSpaceHost");
    assert_eq!(endpoints.kem_key.as_deref(), Some(kem_did_key.as_str()));
    assert!(endpoints.signing_key.is_some());
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn credential_manager_refresh_deadline_revocation_and_error_classification() {
    let space =
        parse_space_ref("at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa")
            .unwrap();
    let host_did = Did::parse("did:web:ds.catbird.blue").unwrap();
    let host_kp = SigningKeyPair::generate_p256().unwrap();
    let proof_kp = SigningKeyPair::generate_p256().unwrap();

    // refreshDeadline formula: min(exp - 30, iat + (exp - iat) / 2)
    let jwt_900 = mint_credential_token(
        &host_kp,
        &host_did,
        &space,
        &proof_kp.did_key().unwrap(),
        1000,
        1900,
        Some("jti-a"),
        None,
    )
    .unwrap();
    let cred_900 =
        SpaceCredential::from_issued_jwt(jwt_900, proof_kp.clone(), &space, None).unwrap();
    assert_eq!(cred_900.refresh_deadline(), 1450);

    let jwt_40 = mint_credential_token(
        &host_kp,
        &host_did,
        &space,
        &proof_kp.did_key().unwrap(),
        1000,
        1040,
        Some("jti-b"),
        None,
    )
    .unwrap();
    let cred_40 = SpaceCredential::from_issued_jwt(jwt_40, proof_kp.clone(), &space, None).unwrap();
    assert_eq!(cred_40.refresh_deadline(), 1010);

    // authorizeSpaceSync error classification
    assert!(matches!(
        classify_authorize_space_sync_error(&space, 410, br#"{"error":"SpaceDeleted"}"#),
        SpaceError::SpaceDeleted(_)
    ));
    assert!(matches!(
        classify_authorize_space_sync_error(&space, 404, br#"{"error":"SpaceNotFound"}"#),
        SpaceError::SpaceNotFound(_)
    ));
    assert!(matches!(
        classify_authorize_space_sync_error(&space, 403, br#"{"error":"NotAuthorized"}"#),
        SpaceError::AuthorizationRefused { .. }
    ));
    assert!(matches!(
        classify_authorize_space_sync_error(&space, 401, br#"{"error":"InvalidToken"}"#),
        SpaceError::TokenRejected { .. }
    ));
    assert!(matches!(
        classify_authorize_space_sync_error(&space, 429, b""),
        SpaceError::TooManyRequests { .. }
    ));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn credential_manager_single_flight_and_invalidation_during_exchange() {
    struct CountingExchanger {
        host_did: Did,
        host_kp: SigningKeyPair,
        calls: std::sync::atomic::AtomicUsize,
        invalidate_during:
            Mutex<Option<(Arc<SpaceCredentialManager<CountingExchanger>>, SpaceRef)>>,
    }
    impl CredentialExchanger for CountingExchanger {
        fn exchange<'a>(
            &'a self,
            space: &'a SpaceRef,
            proof_key: &'a SigningKeyPair,
            now: i64,
        ) -> petrel_spaces::BoxFuture<'a, petrel_spaces::Result<SpaceCredential>> {
            Box::pin(async move {
                self.calls.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
                if let Some((mgr, target)) = self.invalidate_during.lock().unwrap().take() {
                    mgr.invalidate(&target);
                }
                let jwt = mint_credential_token(
                    &self.host_kp,
                    &self.host_did,
                    space,
                    &proof_key.did_key()?,
                    now,
                    now + 600,
                    None,
                    None,
                )?;
                SpaceCredential::from_issued_jwt(jwt, proof_key.clone(), space, None)
            })
        }
    }

    let space =
        parse_space_ref("at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa")
            .unwrap();
    let exchanger = Arc::new(CountingExchanger {
        host_did: Did::parse("did:web:ds.catbird.blue").unwrap(),
        host_kp: SigningKeyPair::generate_p256().unwrap(),
        calls: std::sync::atomic::AtomicUsize::new(0),
        invalidate_during: Mutex::new(None),
    });
    let mgr = Arc::new(SpaceCredentialManager::new(exchanger.clone()));
    let now = 1_800_000_000i64;

    // Two fetches in a row: second hits cache (1 exchange call)
    let c1 = block_on(mgr.credential(&space, false, now)).unwrap();
    let c2 = block_on(mgr.credential(&space, false, now + 10)).unwrap();
    assert_eq!(c1.jwt, c2.jwt);
    assert_eq!(exchanger.calls.load(std::sync::atomic::Ordering::SeqCst), 1);

    // 401 CredentialRevoked evicts cached entry
    assert!(mgr.evict_if_revoked(
        &space,
        StatusCode::UNAUTHORIZED,
        br#"{"error":"CredentialRevoked"}"#,
    ));
    let c3 = block_on(mgr.credential(&space, false, now + 10)).unwrap();
    assert_ne!(c3.jwt, c1.jwt);
    assert_eq!(exchanger.calls.load(std::sync::atomic::Ordering::SeqCst), 2);

    // Invalidation during in-flight exchange fails with InvalidationDuringExchange & does not cache
    mgr.invalidate(&space);
    *exchanger.invalidate_during.lock().unwrap() = Some((mgr.clone(), space.clone()));
    let err = block_on(mgr.credential(&space, false, now + 20)).unwrap_err();
    assert!(matches!(err, SpaceError::InvalidationDuringExchange));
    // Subsequent call must exchange fresh credential rather than reading a stale cancelled one
    let c4 = block_on(mgr.credential(&space, false, now + 20)).unwrap();
    assert_ne!(c4.jwt, c3.jwt);
}

#[cfg(not(target_arch = "wasm32"))]
#[tokio::test]
async fn credential_manager_true_concurrent_single_flight_coalescing() {
    struct YieldingExchanger {
        host_did: Did,
        host_kp: SigningKeyPair,
        calls: std::sync::atomic::AtomicUsize,
    }
    impl CredentialExchanger for YieldingExchanger {
        fn exchange<'a>(
            &'a self,
            space: &'a SpaceRef,
            proof_key: &'a SigningKeyPair,
            now: i64,
        ) -> petrel_spaces::BoxFuture<'a, petrel_spaces::Result<SpaceCredential>> {
            Box::pin(async move {
                tokio::time::sleep(std::time::Duration::from_millis(25)).await;
                self.calls.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
                let jwt = mint_credential_token(
                    &self.host_kp,
                    &self.host_did,
                    space,
                    &proof_key.did_key()?,
                    now,
                    now + 600,
                    None,
                    None,
                )?;
                SpaceCredential::from_issued_jwt(jwt, proof_key.clone(), space, None)
            })
        }
    }

    let space =
        parse_space_ref("at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa")
            .unwrap();
    let exchanger = Arc::new(YieldingExchanger {
        host_did: Did::parse("did:web:ds.catbird.blue").unwrap(),
        host_kp: SigningKeyPair::generate_p256().unwrap(),
        calls: std::sync::atomic::AtomicUsize::new(0),
    });
    let mgr = Arc::new(SpaceCredentialManager::new(exchanger.clone()));
    let now = 1_800_000_000i64;
    let (r1, r2, r3) = tokio::join!(
        mgr.credential(&space, false, now),
        mgr.credential(&space, false, now),
        mgr.credential(&space, false, now),
    );
    let c1 = r1.unwrap();
    assert_eq!(c1.jwt, r2.unwrap().jwt);
    assert_eq!(c1.jwt, r3.unwrap().jwt);
    assert_eq!(exchanger.calls.load(std::sync::atomic::Ordering::SeqCst), 1);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
#[allow(clippy::too_many_lines)]
#[test]
fn end_to_end_space_host_and_sync_engine_full_lifecycle() {
    let now = 1_800_000_000i64;
    let space =
        parse_space_ref("at:space/did:web:host.example.com/blue.catbird.mlsChat/3l2aaaaaaaaaa")
            .unwrap();
    let host_did = Did::parse("did:web:host.example.com").unwrap();
    let writer_did = Did::parse("did:plc:writer111111111111111111").unwrap();
    let reader_did = Did::parse("did:plc:reader111111111111111111").unwrap();
    let pds_did = Did::parse("did:web:pds.example.com").unwrap();

    let host_kp = SigningKeyPair::generate_p256().unwrap();
    let reader_kp = SigningKeyPair::generate_p256().unwrap();
    let (pds_kem_sk, pds_kem_did_key) = generate_p256_keypair().unwrap();

    let mut static_resolver = StaticDidResolver::new();
    static_resolver.insert_keypair(&host_did, &host_kp, Some("https://host.example.com"));
    static_resolver.insert_keypair(&reader_did, &reader_kp, Some("https://pds.example.com"));

    let backend = Arc::new(InMemorySpaceHostBackend::new());
    let mut readers = HashSet::new();
    readers.insert(reader_did.clone());
    let mut writers = HashSet::new();
    writers.insert(writer_did.clone());
    backend
        .put_space(petrel_spaces::HostedSpace {
            space: space.clone(),
            policy: OutputPolicy::MemberspacePolicy(Box::new(MemberspacePolicy::new())),
            allowed_readers: readers,
            allowed_writers: writers,
            deleted: false,
        })
        .unwrap();

    let host = Arc::new(SpaceHost::with_in_memory_replay(
        host_did.clone(),
        host_kp.clone(),
        backend.clone(),
        Arc::new(static_resolver),
    ));

    // Prepare writer record + STAR + Commit
    let col = Nsid::parse("blue.catbird.mlsChat.message").unwrap();
    let rkey = RecordKey::parse("3l2aaaaaaaaab").unwrap();
    let mut rec_map = BTreeMap::new();
    rec_map.insert(
        "$type".to_owned(),
        Value::String("blue.catbird.mlsChat.message".to_owned()),
    );
    rec_map.insert("text".to_owned(), Value::String("hi from rust".to_owned()));
    let rec_val = Value::Object(rec_map);
    let rec_cbor = encode(&rec_val);
    let rec_cid = Cid::for_dag_cbor(&rec_cbor);
    let rec_path = format!("{col}/{rkey}");

    let mut set_hash = SpaceSetHash::new();
    set_hash.add(&rec_path, &rec_cid.to_string());
    let data = set_hash.digest();
    let writer_rev = Tid::parse("3l2aaaaaaaaac").unwrap();
    let star_bytes = write_star_repo(
        &space,
        &writer_did,
        &writer_rev,
        &[(rec_path.as_str(), &rec_val)],
    )
    .unwrap();

    // Host processes notifyRepoUpdate
    let space_rev_1 = backend.next_space_rev(1_800_000_000_000_000).unwrap();
    block_on(host.handle_notify_repo_update(
        &NotifyRepoUpdateInput::new(
            space.clone(),
            writer_did.clone(),
            writer_rev.clone(),
            AtBytes(data.to_vec()),
        ),
        space_rev_1.clone(),
    ))
    .unwrap();

    // Scripted HTTP transport serving host DID doc, PDS DID doc (#atproto_kem), authorizeSpaceSync,
    // listWriters, getLatestCommit, getRecord, listRepoOps, and getRepo
    let transport_impl = Arc::new(ScriptedTransport::default());
    let host_doc_json = serde_json::json!({
        "id": host_did.as_str(),
        "service": [{
            "id": "#atproto_space",
            "type": "AtprotoSpaceHost",
            "serviceEndpoint": "https://host.example.com"
        }],
        "verificationMethod": [{
            "id": format!("{host_did}#atproto"),
            "type": "Multikey",
            "controller": host_did.as_str(),
            "publicKeyMultibase": host_kp.did_key().unwrap().strip_prefix("did:key:").unwrap()
        }]
    });
    let pds_doc_json = serde_json::json!({
        "id": pds_did.as_str(),
        "service": [{
            "id": "#atproto_pds",
            "type": "AtprotoPersonalDataServer",
            "serviceEndpoint": "https://pds.example.com"
        }],
        "verificationMethod": [{
            "id": format!("{pds_did}#atproto_kem"),
            "type": "P256KeyAgreement",
            "controller": pds_did.as_str(),
            "publicKeyMultibase": pds_kem_did_key.strip_prefix("did:key:").unwrap()
        }]
    });

    let space_c = space.clone();
    let host_c = host.clone();
    let host_did_c = host_did.clone();
    let pds_did_c = pds_did.clone();
    let writer_did_c = writer_did.clone();
    let writer_rev_c = writer_rev.clone();
    let rec_val_c = rec_val.clone();
    let col_c = col.clone();
    let rkey_c = rkey.clone();
    let rec_cid_c = rec_cid.clone();
    let star_c = star_bytes.clone();
    let revoked_once = Arc::new(std::sync::atomic::AtomicBool::new(false));
    let revoked_once_c = revoked_once.clone();

    transport_impl.push(move |req| {
        let uri_str = req.uri().to_string();
        if uri_str == "https://host.example.com/.well-known/did.json" {
            return Some(json_resp(200, &host_doc_json));
        }
        if uri_str == "https://pds.example.com/.well-known/did.json" {
            return Some(json_resp(200, &pds_doc_json));
        }
        if uri_str.contains("/xrpc/com.atproto.space.authorizeSpaceSync") {
            let input: AuthorizeSpaceSyncInput = serde_json::from_slice(req.body()).unwrap();
            let (out, reg) =
                block_on(host_c.handle_authorize_space_sync(&input, None, now)).unwrap();
            if let Some(r) = reg {
                let confirm_in = host_c.build_confirm_registration(&r);
                assert_eq!(confirm_in.token, r.token);
                block_on(host_c.verify_confirm_registration_response(
                    &r,
                    &ConfirmRegistrationOutput::new(r.challenge.clone()),
                ))
                .unwrap();
            }
            return Some(json_resp(200, &out));
        }
        if uri_str.contains("/xrpc/com.atproto.space.listWriters") {
            let verified =
                block_on(host_c.verify_presentation(req.headers(), Some(&space_c), now)).unwrap();
            assert_eq!(verified.claims.iss, host_did_c.as_str());
            let out = block_on(host_c.handle_list_writers(&space_c, None, 100)).unwrap();
            return Some(json_resp(200, &out));
        }
        if uri_str.contains("/xrpc/com.atproto.space.getLatestCommit") {
            // Simulate one 401 CredentialRevoked on very first hit to prove transparent re-exchange!
            if !revoked_once_c.swap(true, std::sync::atomic::Ordering::SeqCst) {
                return Some(json_resp(
                    401,
                    &serde_json::json!({"error": "CredentialRevoked", "message": "rotated"}),
                ));
            }
            let accept = parse_accept_signature(
                req.headers()
                    .get("accept-signature")
                    .unwrap()
                    .to_str()
                    .unwrap(),
            )
            .unwrap();
            let secret = decapsulate_p256(&pds_kem_sk, &accept.keyid).unwrap();
            let mac = sign_commit_mac(
                &secret,
                &space_c,
                &writer_did_c,
                &writer_rev_c,
                &data,
                &accept.keyid,
            )
            .unwrap();
            let commit = Commit::new(
                1,
                writer_did_c.clone(),
                space_c.clone(),
                writer_rev_c.clone(),
                AtBytes(data.to_vec()),
            );
            let body = serde_json::to_vec(&GetLatestCommitOutput::new(commit)).unwrap();
            return Some(
                Response::builder()
                    .status(200)
                    .header("content-type", "application/json")
                    .header("atproto-space-commit", mac.covered_signature)
                    .header("signature-input", mac.signature_input)
                    .header("signature", mac.signature)
                    .body(Bytes::from(body))
                    .unwrap(),
            );
        }
        if uri_str.contains("/xrpc/com.atproto.space.getRepo") {
            let accept = parse_accept_signature(
                req.headers()
                    .get("accept-signature")
                    .unwrap()
                    .to_str()
                    .unwrap(),
            )
            .unwrap();
            let secret = decapsulate_p256(&pds_kem_sk, &accept.keyid).unwrap();
            let mac = sign_commit_mac(
                &secret,
                &space_c,
                &writer_did_c,
                &writer_rev_c,
                &data,
                &accept.keyid,
            )
            .unwrap();
            return Some(
                Response::builder()
                    .status(200)
                    .header("atproto-space-commit", mac.covered_signature)
                    .header("signature-input", mac.signature_input)
                    .header("signature", mac.signature)
                    .body(Bytes::from(star_c.clone()))
                    .unwrap(),
            );
        }
        if uri_str.contains("/xrpc/com.atproto.space.getRecord") {
            let accept = parse_accept_signature(
                req.headers()
                    .get("accept-signature")
                    .unwrap()
                    .to_str()
                    .unwrap(),
            )
            .unwrap();
            let secret = decapsulate_p256(&pds_kem_sk, &accept.keyid).unwrap();
            let rec_uri = space_c.record_uri(&writer_did_c, &col_c, &rkey_c).unwrap();
            let mac = sign_record_mac(&secret, &rec_uri, &rec_cid_c, &accept.keyid).unwrap();
            let out = GetRecordOutput::new(
                rec_uri,
                CidString::parse(rec_cid_c.to_string()).unwrap(),
                rec_val_c.clone(),
            );
            return Some(
                Response::builder()
                    .status(200)
                    .header("content-type", "application/json")
                    .header("atproto-space-record", mac.covered_signature)
                    .header("signature-input", mac.signature_input)
                    .header("signature", mac.signature)
                    .body(Bytes::from(serde_json::to_vec(&out).unwrap()))
                    .unwrap(),
            );
        }
        if uri_str.contains("/xrpc/com.atproto.space.listRepoOps") {
            let accept = parse_accept_signature(
                req.headers()
                    .get("accept-signature")
                    .unwrap()
                    .to_str()
                    .unwrap(),
            )
            .unwrap();
            let secret = decapsulate_p256(&pds_kem_sk, &accept.keyid).unwrap();
            let mac = sign_commit_mac(
                &secret,
                &space_c,
                &writer_did_c,
                &writer_rev_c,
                &data,
                &accept.keyid,
            )
            .unwrap();
            let mut op = OpEntry::new(
                writer_rev_c.clone(),
                col_c.clone(),
                rkey_c.clone(),
                Some(CidString::parse(rec_cid_c.to_string()).unwrap()),
                None,
            );
            op.value = Some(rec_val_c.clone());
            let commit = Commit::new(
                1,
                writer_did_c.clone(),
                space_c.clone(),
                writer_rev_c.clone(),
                AtBytes(data.to_vec()),
            );
            let out = ListRepoOpsOutput::new(vec![op], commit);
            return Some(
                Response::builder()
                    .status(200)
                    .header("content-type", "application/json")
                    .header("atproto-space-commit", mac.covered_signature)
                    .header("signature-input", mac.signature_input)
                    .header("signature", mac.signature)
                    .body(Bytes::from(serde_json::to_vec(&out).unwrap()))
                    .unwrap(),
            );
        }
        let _ = &pds_did_c;
        None
    });

    let transport: SharedTransport = transport_impl;
    let host_resolver = Arc::new(SpaceHostResolver::new(transport.clone()));

    let minter = Arc::new(LocalMinter {
        reader_did: reader_did.clone(),
        reader_kp,
        host_did: host_did.clone(),
        now,
    });
    let exchanger = Arc::new(
        HttpCredentialExchanger::new(transport.clone(), host_resolver.clone(), minter)
            .with_notify_endpoint(
                &Url::parse("https://syncer.example.com/notify").unwrap(),
                Some("reg-tok".into()),
            )
            .unwrap(),
    );
    let cred_mgr = Arc::new(SpaceCredentialManager::new(exchanger));
    let engine = SpaceSyncEngine::new(transport, cred_mgr, host_resolver);

    let host_url = Url::parse("https://host.example.com").unwrap();
    let pds_url = Url::parse("https://pds.example.com").unwrap();

    // 1. list_active_writers
    let active =
        block_on(engine.list_active_writers(&space, &host_url, Some(&host_did), None, now))
            .unwrap();
    assert_eq!(active.active.len(), 1);
    assert_eq!(active.active[0].repo, writer_did);

    // 2. getLatestCommit (triggers 401 CredentialRevoked once, retries cleanly)
    let latest = block_on(engine.get_latest_commit_verified(
        &space,
        &writer_did,
        &pds_url,
        Some(&pds_did),
        now,
    ))
    .unwrap();
    assert!(revoked_once.load(std::sync::atomic::Ordering::SeqCst));
    assert_eq!(latest.commit.rev, writer_rev);

    // 3. getRecord verified (MAC + Nov 24 6-part URI + DAG-CBOR CID)
    let rec_out = block_on(engine.get_record_verified(
        &space,
        &writer_did,
        &col,
        &rkey,
        &pds_url,
        Some(&pds_did),
        now,
    ))
    .unwrap();
    assert_eq!(rec_out.cid, rec_cid);

    // 4. recover_writer_repo_via_star verified
    let star_recovered = block_on(engine.recover_writer_repo_via_star(
        &space,
        &writer_did,
        &pds_url,
        Some(&pds_did),
        now,
    ))
    .unwrap();
    assert_eq!(star_recovered.records.len(), 1);
    assert_eq!(star_recovered.records[0].value, rec_val);

    // 5. sync_writer_ops_verified updates local_records + SpaceSetHash matching commit.data
    let mut local_records: BTreeMap<String, Cid> = BTreeMap::new();
    let mut local_hash = SpaceSetHash::new();
    let synced = block_on(engine.sync_writer_ops_verified(
        &space,
        &writer_did,
        &pds_url,
        Some(&pds_did),
        None,
        &mut local_records,
        &mut local_hash,
        now,
    ))
    .unwrap();
    assert_eq!(synced.set_hash_digest, data);
    assert_eq!(local_records.get(&rec_path), Some(&rec_cid));

    // 6. removeWriter & revokeCredentials notice
    let space_rev_2 = backend.next_space_rev(1_800_000_000_000_000).unwrap();
    let removed_update = block_on(host.handle_remove_writer(
        &RemoveWriterInput::new(space.clone(), writer_did.clone()),
        space_rev_2,
        now,
    ))
    .unwrap();
    assert!(matches!(
        removed_update,
        petrel_api::generated::com::atproto::space::notify_space_update::InputUpdate::RepoRemoved(
            _
        )
    ));

    let notice = block_on(host.revoke_user_credentials_and_build_notice(&space, &reader_did))
        .unwrap()
        .expect("issued credential should be revoked");
    assert_ne!(notice.credentials.len(), 0);
}
