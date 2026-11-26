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
        options: &SendOptions,
    ) -> impl Future<Output = Result<Response<Bytes>, TransportError>> + petrel::rt::MaybeSend {
        let limit = options.max_response_bytes.unwrap_or(10 * 1024 * 1024);
        let result = {
            let guard = self.routes.lock().unwrap();
            let mut matched = None;
            for handler in guard.iter().rev() {
                if let Some(resp) = handler(&request) {
                    matched = Some(resp);
                    break;
                }
            }
            match matched {
                Some(resp) if resp.body().len() as u64 > limit => {
                    Err(TransportError::Other(format!(
                        "response {} bytes exceeds max_response_bytes {limit}",
                        resp.body().len()
                    )))
                }
                Some(resp) => Ok(resp),
                None => Err(TransportError::Other(format!(
                    "unhandled mock request: {} {}",
                    request.method(),
                    request.uri()
                ))),
            }
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
#[allow(clippy::too_many_lines)]
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
    assert!(
        doc.service(
            "did:web:space.example.com#atproto_space",
            Some("AtprotoSpaceHost")
        )
        .is_some()
    );

    // Interchangeable relative (`#atproto`) vs absolute (`<did>#atproto`) matching
    assert!(petrel_spaces::extract_signing_key(&doc, "#atproto").is_ok());
    assert!(petrel_spaces::extract_signing_key(&doc, "did:web:space.example.com#atproto").is_ok());
    assert!(matches!(
        petrel_spaces::extract_signing_key(&doc, "did:web:other.example.com#atproto"),
        Err(SpaceError::SigningKeyNotFound(_))
    ));

    let rel_doc_json = serde_json::json!({
        "id": "did:web:space.example.com",
        "service": [
            { "id": "#atproto_space", "type": "AtprotoSpaceHost", "serviceEndpoint": "https://space.example.com" }
        ],
        "verificationMethod": [
            {
                "id": "#atproto",
                "type": "JsonWebKey2020",
                "controller": "did:web:space.example.com",
                "publicKeyJwk": { "kty": "EC", "crv": "P-256", "x": x_b64, "y": y_b64 }
            }
        ]
    });
    let rel_doc =
        SpaceDidDocument::from_json_bytes(&serde_json::to_vec(&rel_doc_json).unwrap()).unwrap();
    assert!(petrel_spaces::extract_signing_key(&rel_doc, "#atproto").is_ok());
    assert!(
        petrel_spaces::extract_signing_key(&rel_doc, "did:web:space.example.com#atproto").is_ok()
    );
    assert!(matches!(
        petrel_spaces::extract_signing_key(&rel_doc, "did:web:other.example.com#atproto"),
        Err(SpaceError::SigningKeyNotFound(_))
    ));

    let foreign_doc_json = serde_json::json!({
        "id": "did:web:space.example.com",
        "verificationMethod": [
            {
                "id": "did:web:other.example.com#atproto",
                "type": "JsonWebKey2020",
                "controller": "did:web:other.example.com",
                "publicKeyJwk": { "kty": "EC", "crv": "P-256", "x": x_b64, "y": y_b64 }
            }
        ]
    });
    let foreign_doc =
        SpaceDidDocument::from_json_bytes(&serde_json::to_vec(&foreign_doc_json).unwrap()).unwrap();
    assert!(matches!(
        petrel_spaces::extract_signing_key(&foreign_doc, "#atproto"),
        Err(SpaceError::SigningKeyNotFound(_))
    ));
    assert!(matches!(
        petrel_spaces::extract_signing_key(&foreign_doc, "did:web:space.example.com#atproto"),
        Err(SpaceError::SigningKeyNotFound(_))
    ));
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
#[allow(clippy::too_many_lines)]
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
        &writer_did,
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
    let writer_doc_json = serde_json::json!({
        "id": writer_did.as_str(),
        "service": [{
            "id": "#atproto_pds",
            "type": "AtprotoPersonalDataServer",
            "serviceEndpoint": "https://pds.example.com"
        }],
        "verificationMethod": [{
            "id": format!("{writer_did}#atproto_kem"),
            "type": "P256KeyAgreement",
            "controller": writer_did.as_str(),
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
        if uri_str == format!("https://plc.directory/{writer_did_c}") {
            return Some(json_resp(200, &writer_doc_json));
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
                block_on(host_c.verify_presentation(req.headers(), &space_c, now)).unwrap();
            assert_eq!(verified.claims.iss, host_did_c.as_str());
            assert!(verified.nonce.is_some());
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
    let engine = SpaceSyncEngine::new(transport.clone(), cred_mgr.clone(), host_resolver);

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
        &host_did,
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

    let notices =
        block_on(host.revoke_user_credentials_and_build_notices(&space, &reader_did)).unwrap();
    assert_eq!(notices.len(), 1);
    assert_ne!(notices[0].credentials.len(), 0);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
#[allow(clippy::too_many_lines)]
#[test]
fn host_tracks_space_wide_prev_space_rev_across_writers_and_removals() {
    use petrel_api::generated::com::atproto::space::notify_space_update::InputUpdate;

    let now = 1_800_000_000_i64;
    let space =
        parse_space_ref("at:space/did:web:host.example.com/blue.catbird.mlsChat/3l2aaaaaaaaab")
            .unwrap();
    let host_did = Did::parse("did:web:host.example.com").unwrap();
    let writer_a = Did::parse("did:plc:writera11111111111111111").unwrap();
    let writer_b = Did::parse("did:plc:writerb11111111111111111").unwrap();
    let host_kp = SigningKeyPair::generate_p256().unwrap();

    let mut resolver = StaticDidResolver::new();
    resolver.insert_keypair(&host_did, &host_kp, Some("https://host.example.com"));

    let backend = Arc::new(InMemorySpaceHostBackend::new());
    let mut writers = HashSet::new();
    writers.insert(writer_a.clone());
    writers.insert(writer_b.clone());
    backend
        .put_space(petrel_spaces::HostedSpace {
            space: space.clone(),
            policy: OutputPolicy::MemberspacePolicy(Box::new(MemberspacePolicy::new())),
            allowed_readers: HashSet::new(),
            allowed_writers: writers,
            deleted: false,
        })
        .unwrap();

    let host = SpaceHost::with_in_memory_replay(
        host_did.clone(),
        host_kp,
        backend.clone(),
        Arc::new(resolver),
    );

    let r1 = backend.next_space_rev(1_800_000_000_000_001).unwrap();
    let r2 = backend.next_space_rev(1_800_000_000_000_002).unwrap();
    let r3 = backend.next_space_rev(1_800_000_000_000_003).unwrap();
    let r4 = backend.next_space_rev(1_800_000_000_000_004).unwrap();
    let r5 = backend.next_space_rev(1_800_000_000_000_005).unwrap();
    let writer_rev_1 = Tid::parse("3l2aaaaaaaaac").unwrap();
    let writer_rev_2 = Tid::parse("3l2aaaaaaaaad").unwrap();
    let writer_rev_3 = Tid::parse("3l2aaaaaaaaae").unwrap();
    let empty_hash = vec![0_u8; 32];

    let u1 = block_on(host.handle_notify_repo_update(
        &writer_a,
        &NotifyRepoUpdateInput::new(
            space.clone(),
            writer_a.clone(),
            writer_rev_1.clone(),
            AtBytes(empty_hash.clone()),
        ),
        r1.clone(),
    ))
    .unwrap();
    match u1 {
        InputUpdate::RepoWrite(w) => assert_eq!(w.prev_space_rev, None),
        other => panic!("unexpected update: {other:?}"),
    }

    let u2 = block_on(host.handle_notify_repo_update(
        &writer_b,
        &NotifyRepoUpdateInput::new(
            space.clone(),
            writer_b.clone(),
            writer_rev_1,
            AtBytes(empty_hash.clone()),
        ),
        r2.clone(),
    ))
    .unwrap();
    match u2 {
        InputUpdate::RepoWrite(w) => assert_eq!(w.prev_space_rev.as_ref(), Some(&r1)),
        other => panic!("unexpected update: {other:?}"),
    }

    let u3 = block_on(host.handle_notify_repo_update(
        &writer_a,
        &NotifyRepoUpdateInput::new(
            space.clone(),
            writer_a.clone(),
            writer_rev_2,
            AtBytes(empty_hash.clone()),
        ),
        r3.clone(),
    ))
    .unwrap();
    match u3 {
        InputUpdate::RepoWrite(w) => assert_eq!(w.prev_space_rev.as_ref(), Some(&r2)),
        other => panic!("unexpected update: {other:?}"),
    }

    let u4 = block_on(host.handle_remove_writer(
        &host_did,
        &RemoveWriterInput::new(space.clone(), writer_b),
        r4.clone(),
        now,
    ))
    .unwrap();
    match u4 {
        InputUpdate::RepoRemoved(rem) => assert_eq!(rem.prev_space_rev.as_ref(), Some(&r3)),
        other => panic!("unexpected update: {other:?}"),
    }

    let u5 = block_on(host.handle_notify_repo_update(
        &writer_a.clone(),
        &NotifyRepoUpdateInput::new(space, writer_a, writer_rev_3, AtBytes(empty_hash)),
        r5,
    ))
    .unwrap();
    match u5 {
        InputUpdate::RepoWrite(w) => assert_eq!(w.prev_space_rev.as_ref(), Some(&r4)),
        other => panic!("unexpected update: {other:?}"),
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
#[allow(clippy::too_many_lines)]
#[test]
fn sync_writer_ops_verified_rolls_back_on_later_page_failure() {
    let now = 1_800_000_000_i64;
    let space =
        parse_space_ref("at:space/did:web:host.example.com/blue.catbird.mlsChat/3l2aaaaaaaaac")
            .unwrap();
    let host_did = Did::parse("did:web:host.example.com").unwrap();
    let writer_did = Did::parse("did:plc:writer222222222222222222").unwrap();
    let reader_did = Did::parse("did:plc:reader222222222222222222").unwrap();
    let pds_did = Did::parse("did:web:pds.example.com").unwrap();

    let host_kp = SigningKeyPair::generate_p256().unwrap();
    let reader_kp = SigningKeyPair::generate_p256().unwrap();
    let (pds_kem_sk, pds_kem_did_key) = generate_p256_keypair().unwrap();

    let col = Nsid::parse("blue.catbird.mlsChat.message").unwrap();
    let seed_rkey = RecordKey::parse("3l2aaaaaaaaaa").unwrap();
    let page1_rkey = RecordKey::parse("3l2aaaaaaaaab").unwrap();
    let page2_rkey = RecordKey::parse("3l2aaaaaaaaac").unwrap();

    let mut seed_map = BTreeMap::new();
    seed_map.insert("text".to_owned(), Value::String("seed".to_owned()));
    let seed_cid = Cid::for_dag_cbor(&encode(&Value::Object(seed_map)));
    let seed_path = format!("{col}/{seed_rkey}");

    let mut page1_map = BTreeMap::new();
    page1_map.insert("text".to_owned(), Value::String("page1".to_owned()));
    let page1_val = Value::Object(page1_map);
    let page1_cid = Cid::for_dag_cbor(&encode(&page1_val));

    let mut page2_map = BTreeMap::new();
    page2_map.insert("text".to_owned(), Value::String("page2".to_owned()));
    let page2_val = Value::Object(page2_map);
    let page2_cid = Cid::for_dag_cbor(&encode(&page2_val));

    let mut initial_records = BTreeMap::new();
    initial_records.insert(seed_path.clone(), seed_cid.clone());
    let mut initial_hash = SpaceSetHash::new();
    initial_hash.add(&seed_path, &seed_cid.to_string());
    let initial_digest = initial_hash.digest();

    let rev_p1 = Tid::parse("3l2aaaaaaaaad").unwrap();
    let rev_p2 = Tid::parse("3l2aaaaaaaaae").unwrap();
    let bogus_data = [0xEE_u8; 32];

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
    let writer_doc_json = serde_json::json!({
        "id": writer_did.as_str(),
        "service": [{
            "id": "#atproto_pds",
            "type": "AtprotoPersonalDataServer",
            "serviceEndpoint": "https://pds.example.com"
        }],
        "verificationMethod": [{
            "id": format!("{writer_did}#atproto_kem"),
            "type": "P256KeyAgreement",
            "controller": writer_did.as_str(),
            "publicKeyMultibase": pds_kem_did_key.strip_prefix("did:key:").unwrap()
        }]
    });

    let space_c = space.clone();
    let host_did_c = host_did.clone();
    let host_kp_c = host_kp.clone();
    let writer_did_c = writer_did.clone();
    let col_c = col.clone();
    let fail_with_bad_mac = Arc::new(std::sync::atomic::AtomicBool::new(false));
    let fail_with_bad_mac_c = fail_with_bad_mac.clone();

    transport_impl.push(move |req| {
        let uri_str = req.uri().to_string();
        if uri_str == "https://host.example.com/.well-known/did.json" {
            return Some(json_resp(200, &host_doc_json));
        }
        if uri_str == format!("https://plc.directory/{writer_did_c}") {
            return Some(json_resp(200, &writer_doc_json));
        }
        if uri_str.contains("/xrpc/com.atproto.space.authorizeSpaceSync") {
            let input: AuthorizeSpaceSyncInput = serde_json::from_slice(req.body()).unwrap();
            let jwt = mint_credential_token(
                &host_kp_c,
                &host_did_c,
                &space_c,
                &input.credential_key,
                now,
                now + 600,
                Some("jti-sync-rollback"),
                None,
            )
            .unwrap();
            return Some(json_resp(
                200,
                &petrel_api::generated::com::atproto::space::authorize_space_sync::Output::new(jwt),
            ));
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
            if uri_str.contains("cursor=p2") {
                if fail_with_bad_mac_c.load(std::sync::atomic::Ordering::SeqCst) {
                    return Some(
                        Response::builder()
                            .status(200)
                            .header("content-type", "application/json")
                            .body(Bytes::from_static(b"{}"))
                            .unwrap(),
                    );
                }
                let mac = sign_commit_mac(
                    &secret,
                    &space_c,
                    &writer_did_c,
                    &rev_p2,
                    &bogus_data,
                    &accept.keyid,
                )
                .unwrap();
                let mut op = OpEntry::new(
                    rev_p2.clone(),
                    col_c.clone(),
                    page2_rkey.clone(),
                    Some(CidString::parse(page2_cid.to_string()).unwrap()),
                    None,
                );
                op.value = Some(page2_val.clone());
                let commit = Commit::new(
                    1,
                    writer_did_c.clone(),
                    space_c.clone(),
                    rev_p2.clone(),
                    AtBytes(bogus_data.to_vec()),
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
            let mac = sign_commit_mac(
                &secret,
                &space_c,
                &writer_did_c,
                &rev_p1,
                &bogus_data,
                &accept.keyid,
            )
            .unwrap();
            let mut op = OpEntry::new(
                rev_p1.clone(),
                col_c.clone(),
                page1_rkey.clone(),
                Some(CidString::parse(page1_cid.to_string()).unwrap()),
                None,
            );
            op.value = Some(page1_val.clone());
            let commit = Commit::new(
                1,
                writer_did_c.clone(),
                space_c.clone(),
                rev_p1.clone(),
                AtBytes(bogus_data.to_vec()),
            );
            let mut out = ListRepoOpsOutput::new(vec![op], commit);
            out.cursor = Some("p2".to_owned());
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
        None
    });

    let transport: SharedTransport = transport_impl;
    let host_resolver = Arc::new(SpaceHostResolver::new(transport.clone()));
    let minter = Arc::new(LocalMinter {
        reader_did,
        reader_kp,
        host_did,
        now,
    });
    let exchanger = Arc::new(HttpCredentialExchanger::new(
        transport.clone(),
        host_resolver.clone(),
        minter,
    ));
    let cred_mgr = Arc::new(SpaceCredentialManager::new(exchanger));
    let engine = SpaceSyncEngine::new(transport.clone(), cred_mgr.clone(), host_resolver);
    let pds_url = Url::parse("https://pds.example.com").unwrap();

    // Case 1: Page 1 mutates staged state; Page 2 fails final commit.data hash check.
    let mut records = initial_records.clone();
    let mut hash = initial_hash.clone();
    let err = block_on(engine.sync_writer_ops_verified(
        &space,
        &writer_did,
        &pds_url,
        Some(&pds_did),
        None,
        &mut records,
        &mut hash,
        now,
    ))
    .unwrap_err();
    assert!(matches!(err, SpaceError::DataHashMismatch { .. }));
    assert_eq!(records, initial_records);
    assert_eq!(hash.digest(), initial_digest);

    // Case 2: Page 1 mutates staged state; Page 2 fails mid-pagination header/MAC check.
    fail_with_bad_mac.store(true, std::sync::atomic::Ordering::SeqCst);
    let err2 = block_on(engine.sync_writer_ops_verified(
        &space,
        &writer_did,
        &pds_url,
        Some(&pds_did),
        None,
        &mut records,
        &mut hash,
        now,
    ))
    .unwrap_err();
    assert!(matches!(err2, SpaceError::MissingHeader(_)));
    assert_eq!(records, initial_records);
    assert_eq!(hash.digest(), initial_digest);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
#[test]
fn list_active_writers_errors_when_pagination_hits_page_limit() {
    use petrel_api::generated::com::atproto::space::{
        defs::RepoWrite,
        list_writers::{Output as ListWritersOutput, OutputRepos},
    };
    use std::sync::atomic::{AtomicUsize, Ordering};

    let now = 1_800_000_000_i64;
    let space =
        parse_space_ref("at:space/did:web:host.example.com/blue.catbird.mlsChat/3l2aaaaaaaaad")
            .unwrap();
    let host_did = Did::parse("did:web:host.example.com").unwrap();
    let writer_did = Did::parse("did:plc:writer333333333333333333").unwrap();
    let reader_did = Did::parse("did:plc:reader333333333333333333").unwrap();

    let host_kp = SigningKeyPair::generate_p256().unwrap();
    let reader_kp = SigningKeyPair::generate_p256().unwrap();
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

    let page_counter = Arc::new(AtomicUsize::new(0));
    let page_counter_c = page_counter.clone();
    let space_c = space.clone();
    let host_did_c = host_did.clone();
    let host_kp_c = host_kp.clone();
    let writer_did_c = writer_did.clone();
    let writer_rev = Tid::parse("3l2aaaaaaaaae").unwrap();
    let space_rev = Tid::parse("3l2aaaaaaaaaf").unwrap();

    let transport_impl = Arc::new(ScriptedTransport::default());
    transport_impl.push(move |req| {
        let uri_str = req.uri().to_string();
        if uri_str == "https://host.example.com/.well-known/did.json" {
            return Some(json_resp(200, &host_doc_json));
        }
        if uri_str.contains("/xrpc/com.atproto.space.authorizeSpaceSync") {
            let input: AuthorizeSpaceSyncInput = serde_json::from_slice(req.body()).unwrap();
            let jwt = mint_credential_token(
                &host_kp_c,
                &host_did_c,
                &space_c,
                &input.credential_key,
                now,
                now + 600,
                Some("jti-listwriters-limit"),
                None,
            )
            .unwrap();
            return Some(json_resp(
                200,
                &petrel_api::generated::com::atproto::space::authorize_space_sync::Output::new(jwt),
            ));
        }
        if uri_str.contains("/xrpc/com.atproto.space.listWriters") {
            let n = page_counter_c.fetch_add(1, Ordering::SeqCst);
            let out = ListWritersOutput {
                repos: vec![OutputRepos::RepoWrite(Box::new(RepoWrite::new(
                    writer_did_c.clone(),
                    writer_rev.clone(),
                    AtBytes(vec![0_u8; 32]),
                    space_rev.clone(),
                )))],
                cursor: Some(format!("cur-{n}")),
            };
            return Some(json_resp(200, &out));
        }
        None
    });

    let transport: SharedTransport = transport_impl;
    let host_resolver = Arc::new(SpaceHostResolver::new(transport.clone()));
    let minter = Arc::new(LocalMinter {
        reader_did,
        reader_kp,
        host_did: host_did.clone(),
        now,
    });
    let exchanger = Arc::new(HttpCredentialExchanger::new(
        transport.clone(),
        host_resolver.clone(),
        minter,
    ));
    let cred_mgr = Arc::new(SpaceCredentialManager::new(exchanger));
    let engine = SpaceSyncEngine::new(transport.clone(), cred_mgr.clone(), host_resolver);
    let host_url = Url::parse("https://host.example.com").unwrap();

    let err = block_on(engine.list_active_writers(&space, &host_url, Some(&host_did), None, now))
        .unwrap_err();
    assert!(matches!(err, SpaceError::MalformedPayload(_)));
    assert_eq!(page_counter.load(Ordering::SeqCst), 1000);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
#[allow(clippy::too_many_lines)]
#[test]
fn host_rejects_stale_and_duplicate_notify_repo_update() {
    use petrel_api::generated::com::atproto::space::{
        list_writers::OutputRepos, notify_space_update::InputUpdate,
    };

    let space =
        parse_space_ref("at:space/did:web:host.example.com/blue.catbird.mlsChat/3l2aaaaaaaaae")
            .unwrap();
    let host_did = Did::parse("did:web:host.example.com").unwrap();
    let writer = Did::parse("did:plc:writer444444444444444444").unwrap();
    let host_kp = SigningKeyPair::generate_p256().unwrap();

    let mut resolver = StaticDidResolver::new();
    resolver.insert_keypair(&host_did, &host_kp, Some("https://host.example.com"));

    let backend = Arc::new(InMemorySpaceHostBackend::new());
    let mut writers = HashSet::new();
    writers.insert(writer.clone());
    backend
        .put_space(petrel_spaces::HostedSpace {
            space: space.clone(),
            policy: OutputPolicy::MemberspacePolicy(Box::new(MemberspacePolicy::new())),
            allowed_readers: HashSet::new(),
            allowed_writers: writers,
            deleted: false,
        })
        .unwrap();

    let host =
        SpaceHost::with_in_memory_replay(host_did, host_kp, backend.clone(), Arc::new(resolver));

    let rev_old = Tid::parse("3l2aaaaaaaaaa").unwrap();
    let rev_cur = Tid::parse("3l2aaaaaaaaab").unwrap();
    let rev_new = Tid::parse("3l2aaaaaaaaac").unwrap();

    let s1 = backend.next_space_rev(1_800_000_000_000_010).unwrap();
    let s2 = backend.next_space_rev(1_800_000_000_000_020).unwrap();
    let s3 = backend.next_space_rev(1_800_000_000_000_030).unwrap();
    let s4 = backend.next_space_rev(1_800_000_000_000_040).unwrap();

    let data_cur = vec![0x22_u8; 32];
    let data_stale = vec![0x11_u8; 32];
    let data_dup = vec![0x99_u8; 32];
    let data_new = vec![0x33_u8; 32];

    let ok1 = block_on(host.handle_notify_repo_update(
        &writer,
        &NotifyRepoUpdateInput::new(
            space.clone(),
            writer.clone(),
            rev_cur.clone(),
            AtBytes(data_cur.clone()),
        ),
        s1.clone(),
    ))
    .unwrap();
    match ok1 {
        InputUpdate::RepoWrite(w) => assert_eq!(w.prev_space_rev, None),
        other => panic!("unexpected update: {other:?}"),
    }

    // Stale (older) repo_rev must fail without mutating state or advancing latest_space_rev.
    let stale_err = block_on(host.handle_notify_repo_update(
        &writer,
        &NotifyRepoUpdateInput::new(space.clone(), writer.clone(), rev_old, AtBytes(data_stale)),
        s2,
    ))
    .unwrap_err();
    assert!(matches!(
        stale_err,
        SpaceError::Xrpc {
            status: 409,
            ref error,
            ..
        } if error == "StaleRepoRev"
    ));

    // Duplicate repo_rev must also be rejected without publishing a new space_rev.
    let dup_err = block_on(host.handle_notify_repo_update(
        &writer,
        &NotifyRepoUpdateInput::new(
            space.clone(),
            writer.clone(),
            rev_cur.clone(),
            AtBytes(data_dup),
        ),
        s3,
    ))
    .unwrap_err();
    assert!(matches!(
        dup_err,
        SpaceError::Xrpc {
            status: 409,
            ref error,
            ..
        } if error == "StaleRepoRev"
    ));

    let listed = block_on(host.handle_list_writers(&space, None, 10)).unwrap();
    assert_eq!(listed.repos.len(), 1);
    match &listed.repos[0] {
        OutputRepos::RepoWrite(w) => {
            assert_eq!(w.repo_rev, rev_cur);
            assert_eq!(w.data.0, data_cur);
            assert_eq!(w.space_rev, s1);
        }
        other => panic!("unexpected listed writer state: {other:?}"),
    }

    // Subsequent newer repo_rev still links prev_space_rev directly to s1.
    let ok2 = block_on(host.handle_notify_repo_update(
        &writer.clone(),
        &NotifyRepoUpdateInput::new(space, writer, rev_new, AtBytes(data_new)),
        s4,
    ))
    .unwrap();
    match ok2 {
        InputUpdate::RepoWrite(w) => assert_eq!(w.prev_space_rev.as_ref(), Some(&s1)),
        other => panic!("unexpected update: {other:?}"),
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
#[allow(clippy::too_many_lines)]
#[test]
fn recover_writer_repo_via_star_propagates_max_archive_bytes_above_10mib() {
    let now = 1_800_000_000_i64;
    let space =
        parse_space_ref("at:space/did:web:host.example.com/blue.catbird.mlsChat/3l2aaaaaaaaaf")
            .unwrap();
    let host_did = Did::parse("did:web:host.example.com").unwrap();
    let writer_did = Did::parse("did:plc:writer555555555555555555").unwrap();
    let reader_did = Did::parse("did:plc:reader555555555555555555").unwrap();
    let pds_did = Did::parse("did:web:pds.example.com").unwrap();

    let host_kp = SigningKeyPair::generate_p256().unwrap();
    let reader_kp = SigningKeyPair::generate_p256().unwrap();
    let (pds_kem_sk, pds_kem_did_key) = generate_p256_keypair().unwrap();

    // Build a valid STAR archive > 10 MiB (12 records x ~920 KiB ~= 11 MiB).
    let col = Nsid::parse("blue.catbird.mlsChat.message").unwrap();
    let payload = "x".repeat(920 * 1024);
    let mut records_owned: Vec<(String, Value)> = Vec::with_capacity(12);
    let mut set_hash = SpaceSetHash::new();
    for idx in 0_u8..12 {
        let suffix = char::from(b'a' + idx);
        let rkey = RecordKey::parse(format!("3l2aaaaaaaaa{suffix}")).unwrap();
        let mut map = BTreeMap::new();
        map.insert(
            "$type".to_owned(),
            Value::String("blue.catbird.mlsChat.message".to_owned()),
        );
        map.insert("body".to_owned(), Value::String(payload.clone()));
        let val = Value::Object(map);
        let cid = Cid::for_dag_cbor(&encode(&val));
        let path = format!("{col}/{rkey}");
        set_hash.add(&path, &cid.to_string());
        records_owned.push((path, val));
    }
    let record_refs: Vec<(&str, &Value)> =
        records_owned.iter().map(|(p, v)| (p.as_str(), v)).collect();
    let writer_rev = Tid::parse("3l2aaaaaaaaag").unwrap();
    let star_bytes = write_star_repo(&space, &writer_did, &writer_rev, &record_refs).unwrap();
    assert!(
        star_bytes.len() > 10 * 1024 * 1024,
        "test STAR archive must exceed default 10 MiB transport cap"
    );
    let data = set_hash.digest();

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
    let writer_doc_json = serde_json::json!({
        "id": writer_did.as_str(),
        "service": [{
            "id": "#atproto_pds",
            "type": "AtprotoPersonalDataServer",
            "serviceEndpoint": "https://pds.example.com"
        }],
        "verificationMethod": [{
            "id": format!("{writer_did}#atproto_kem"),
            "type": "P256KeyAgreement",
            "controller": writer_did.as_str(),
            "publicKeyMultibase": pds_kem_did_key.strip_prefix("did:key:").unwrap()
        }]
    });

    let space_c = space.clone();
    let host_did_c = host_did.clone();
    let host_kp_c = host_kp.clone();
    let writer_did_c = writer_did.clone();
    let star_c = Arc::new(Bytes::from(star_bytes));

    let transport_impl = Arc::new(ScriptedTransport::default());
    transport_impl.push(move |req| {
        let uri_str = req.uri().to_string();
        if uri_str == "https://host.example.com/.well-known/did.json" {
            return Some(json_resp(200, &host_doc_json));
        }
        if uri_str == format!("https://plc.directory/{writer_did_c}") {
            return Some(json_resp(200, &writer_doc_json));
        }
        if uri_str.contains("/xrpc/com.atproto.space.authorizeSpaceSync") {
            let input: AuthorizeSpaceSyncInput = serde_json::from_slice(req.body()).unwrap();
            let jwt = mint_credential_token(
                &host_kp_c,
                &host_did_c,
                &space_c,
                &input.credential_key,
                now,
                now + 600,
                Some("jti-large-star"),
                None,
            )
            .unwrap();
            return Some(json_resp(
                200,
                &petrel_api::generated::com::atproto::space::authorize_space_sync::Output::new(jwt),
            ));
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
                &writer_rev,
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
                    .body((*star_c).clone())
                    .unwrap(),
            );
        }
        None
    });

    let transport: SharedTransport = transport_impl;
    let host_resolver = Arc::new(SpaceHostResolver::new(transport.clone()));
    let minter = Arc::new(LocalMinter {
        reader_did,
        reader_kp,
        host_did,
        now,
    });
    let exchanger = Arc::new(HttpCredentialExchanger::new(
        transport.clone(),
        host_resolver.clone(),
        minter,
    ));
    let cred_mgr =
        Arc::new(SpaceCredentialManager::new(exchanger).with_max_archive_bytes(16 * 1024 * 1024));
    let engine = SpaceSyncEngine::new(transport.clone(), cred_mgr.clone(), host_resolver);
    let pds_url = Url::parse("https://pds.example.com").unwrap();

    let recovered = block_on(engine.recover_writer_repo_via_star(
        &space,
        &writer_did,
        &pds_url,
        Some(&pds_did),
        now,
    ))
    .unwrap();
    assert_eq!(recovered.records.len(), 12);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
#[allow(clippy::too_many_lines)]
#[test]
fn sync_engine_uses_writer_did_for_audience_and_kem_and_retries_once_on_mac_mismatch() {
    use petrel_spaces::verify_credential_request;
    use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};

    let now = 1_800_000_000_i64;
    let space =
        parse_space_ref("at:space/did:web:host.example.com/blue.catbird.mlsChat/3l2aaaaaaaaag")
            .unwrap();
    let host_did = Did::parse("did:web:host.example.com").unwrap();
    let writer_did = Did::parse("did:plc:writer666666666666666666").unwrap();
    let reader_did = Did::parse("did:plc:reader666666666666666666").unwrap();
    let pds_did = Did::parse("did:web:pds.example.com").unwrap();

    let host_kp = SigningKeyPair::generate_p256().unwrap();
    let reader_kp = SigningKeyPair::generate_p256().unwrap();
    let (_old_kem_sk, old_kem_did_key) = generate_p256_keypair().unwrap();
    let (new_kem_sk, new_kem_did_key) = generate_p256_keypair().unwrap();
    let (rogue_kem_sk, _) = generate_p256_keypair().unwrap();
    let (_decoy_pds_sk, decoy_pds_did_key) = generate_p256_keypair().unwrap();

    let mut did_resolver = StaticDidResolver::new();
    did_resolver.insert_keypair(&host_did, &host_kp, Some("https://host.example.com"));
    let did_resolver = Arc::new(did_resolver);

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
        "verificationMethod": [{
            "id": format!("{pds_did}#atproto_kem"),
            "type": "P256KeyAgreement",
            "controller": pds_did.as_str(),
            "publicKeyMultibase": decoy_pds_did_key.strip_prefix("did:key:").unwrap()
        }]
    });
    let writer_doc_with_key = |kem_did_key: &str| {
        serde_json::json!({
            "id": writer_did.as_str(),
            "service": [{
                "id": "#atproto_pds",
                "type": "AtprotoPersonalDataServer",
                "serviceEndpoint": "https://pds.example.com"
            }],
            "verificationMethod": [{
                "id": format!("{writer_did}#atproto_kem"),
                "type": "P256KeyAgreement",
                "controller": writer_did.as_str(),
                "publicKeyMultibase": kem_did_key.strip_prefix("did:key:").unwrap()
            }]
        })
    };
    let writer_doc_old = writer_doc_with_key(&old_kem_did_key);
    let writer_doc_new = writer_doc_with_key(&new_kem_did_key);

    let writer_rev = Tid::parse("3l2aaaaaaaaah").unwrap();
    let data = [0x44_u8; 32];

    let pds_doc_fetches = Arc::new(AtomicUsize::new(0));
    let writer_doc_fetches = Arc::new(AtomicUsize::new(0));
    let get_latest_hits = Arc::new(AtomicUsize::new(0));
    let use_rogue_kem = Arc::new(AtomicBool::new(false));

    let pds_doc_fetches_c = pds_doc_fetches.clone();
    let writer_doc_fetches_c = writer_doc_fetches.clone();
    let get_latest_hits_c = get_latest_hits.clone();
    let use_rogue_kem_c = use_rogue_kem.clone();
    let space_c = space.clone();
    let host_did_c = host_did.clone();
    let host_kp_c = host_kp.clone();
    let writer_did_c = writer_did.clone();
    let writer_rev_c = writer_rev.clone();
    let did_resolver_c = did_resolver.clone();

    let transport_impl = Arc::new(ScriptedTransport::default());
    transport_impl.push(move |req| {
        let uri_str = req.uri().to_string();
        if uri_str == "https://host.example.com/.well-known/did.json" {
            return Some(json_resp(200, &host_doc_json));
        }
        if uri_str == "https://pds.example.com/.well-known/did.json" {
            pds_doc_fetches_c.fetch_add(1, Ordering::SeqCst);
            return Some(json_resp(200, &pds_doc_json));
        }
        if uri_str == format!("https://plc.directory/{writer_did_c}") {
            let fetch_idx = writer_doc_fetches_c.fetch_add(1, Ordering::SeqCst);
            return if fetch_idx == 0 {
                Some(json_resp(200, &writer_doc_old))
            } else {
                Some(json_resp(200, &writer_doc_new))
            };
        }
        if uri_str.contains("/xrpc/com.atproto.space.authorizeSpaceSync") {
            let input: AuthorizeSpaceSyncInput = serde_json::from_slice(req.body()).unwrap();
            let jwt = mint_credential_token(
                &host_kp_c,
                &host_did_c,
                &space_c,
                &input.credential_key,
                now,
                now + 600,
                Some("jti-writer-aud"),
                None,
            )
            .unwrap();
            return Some(json_resp(
                200,
                &petrel_api::generated::com::atproto::space::authorize_space_sync::Output::new(jwt),
            ));
        }
        if uri_str.contains("/xrpc/com.atproto.space.getLatestCommit") {
            get_latest_hits_c.fetch_add(1, Ordering::SeqCst);

            // Audience MUST be writer_did (repo owner), never pds_did or did:web:<pds-host>.
            assert_eq!(
                req.headers()
                    .get("atproto-space-audience")
                    .and_then(|v| v.to_str().ok()),
                Some(writer_did_c.as_str())
            );
            let verified = block_on(verify_credential_request(
                req.headers(),
                writer_did_c.as_str(),
                now,
                did_resolver_c.as_ref(),
            ))
            .unwrap();
            assert_eq!(verified.audience, writer_did_c.as_str());

            let accept = parse_accept_signature(
                req.headers()
                    .get("accept-signature")
                    .unwrap()
                    .to_str()
                    .unwrap(),
            )
            .unwrap();
            let server_sk = if use_rogue_kem_c.load(Ordering::SeqCst) {
                &rogue_kem_sk
            } else {
                &new_kem_sk
            };
            let secret = decapsulate_p256(server_sk, &accept.keyid).unwrap();
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
        None
    });

    let transport: SharedTransport = transport_impl;
    let host_resolver = Arc::new(SpaceHostResolver::new(transport.clone()));
    let minter = Arc::new(LocalMinter {
        reader_did,
        reader_kp,
        host_did,
        now,
    });
    let exchanger = Arc::new(HttpCredentialExchanger::new(
        transport.clone(),
        host_resolver.clone(),
        minter,
    ));
    let cred_mgr = Arc::new(SpaceCredentialManager::new(exchanger));
    let engine = SpaceSyncEngine::new(transport.clone(), cred_mgr.clone(), host_resolver);
    let pds_url = Url::parse("https://pds.example.com").unwrap();

    // First attempt uses cached old_kem_did_key -> HTTP 200 MacMismatch -> refreshes writer_did KEM once -> succeeds.
    let latest = block_on(engine.get_latest_commit_verified(
        &space,
        &writer_did,
        &pds_url,
        Some(&pds_did),
        now,
    ))
    .unwrap();
    assert_eq!(latest.commit.rev, writer_rev);
    assert_eq!(pds_doc_fetches.load(Ordering::SeqCst), 0);
    assert_eq!(writer_doc_fetches.load(Ordering::SeqCst), 2);
    assert_eq!(get_latest_hits.load(Ordering::SeqCst), 2);

    // When server signs with an unrelated key immediately after a forced refresh, resolver cooldown
    // prevents DID fetch amplification (stays at 2) and sync fails with MacMismatch after retrying once.
    use_rogue_kem.store(true, Ordering::SeqCst);
    let err = block_on(engine.get_latest_commit_verified(
        &space,
        &writer_did,
        &pds_url,
        Some(&pds_did),
        now,
    ))
    .unwrap_err();
    assert!(matches!(err, SpaceError::MacMismatch));
    assert_eq!(pds_doc_fetches.load(Ordering::SeqCst), 0);
    assert_eq!(writer_doc_fetches.load(Ordering::SeqCst), 2);
    assert_eq!(get_latest_hits.load(Ordering::SeqCst), 4);

    // Without force-refresh cooldown (e.g. after cooldown window elapses), MacMismatch refreshes
    // writer_did KEM at most once per call and still stops with MacMismatch.
    let unthrottled_resolver = Arc::new(
        SpaceHostResolver::new(transport.clone())
            .with_force_refresh_cooldown(std::time::Duration::ZERO),
    );
    let unthrottled_engine = SpaceSyncEngine::new(transport, cred_mgr, unthrottled_resolver);
    let err2 = block_on(unthrottled_engine.get_latest_commit_verified(
        &space,
        &writer_did,
        &pds_url,
        Some(&pds_did),
        now,
    ))
    .unwrap_err();
    assert!(matches!(err2, SpaceError::MacMismatch));
    assert_eq!(pds_doc_fetches.load(Ordering::SeqCst), 0);
    assert_eq!(writer_doc_fetches.load(Ordering::SeqCst), 4); // 1 initial cache fill + 1 forced refresh
    assert_eq!(get_latest_hits.load(Ordering::SeqCst), 6);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
#[allow(clippy::too_many_lines)]
#[test]
fn host_enforces_delegation_replay_cnf_binding_presentation_nonce_and_caller_authz() {
    use http::HeaderMap;
    use petrel_spaces::{
        NotifyRegistration, mint_delegation_token_with_cnf, sign_credential_request,
        sign_credential_request_minimal,
    };

    let now = 1_800_000_000_i64;
    let host_did = Did::parse("did:web:host.example.com").unwrap();
    let other_host = Did::parse("did:web:other.example.com").unwrap();
    let space_a =
        parse_space_ref("at:space/did:web:host.example.com/blue.catbird.mlsChat/3l2aaaaaaaaaa")
            .unwrap();
    let space_b =
        parse_space_ref("at:space/did:web:host.example.com/blue.catbird.mlsChat/3l2aaaaaaaaab")
            .unwrap();
    let foreign_space =
        parse_space_ref("at:space/did:web:other.example.com/blue.catbird.mlsChat/3l2aaaaaaaaac")
            .unwrap();

    let writer = Did::parse("did:plc:writer777777777777777777").unwrap();
    let reader = Did::parse("did:plc:reader777777777777777777").unwrap();
    let outsider = Did::parse("did:plc:outsider7777777777777777").unwrap();

    let host_kp = SigningKeyPair::generate_p256().unwrap();
    let reader_kp = SigningKeyPair::generate_p256().unwrap();
    let holder_kp_1 = SigningKeyPair::generate_p256().unwrap();
    let holder_kp_2 = SigningKeyPair::generate_p256().unwrap();
    let holder_kid_1 = holder_kp_1.did_key().unwrap();
    let holder_kid_2 = holder_kp_2.did_key().unwrap();

    let mut resolver = StaticDidResolver::new();
    resolver.insert_keypair(&host_did, &host_kp, Some("https://host.example.com"));
    resolver.insert_keypair(&reader, &reader_kp, None);
    let resolver = Arc::new(resolver);

    let backend = Arc::new(InMemorySpaceHostBackend::new());
    let mut readers = HashSet::new();
    readers.insert(reader.clone());
    let mut writers = HashSet::new();
    writers.insert(writer.clone());
    for space in [&space_a, &space_b] {
        backend
            .put_space(petrel_spaces::HostedSpace {
                space: space.clone(),
                policy: OutputPolicy::MemberspacePolicy(Box::new(MemberspacePolicy::new())),
                allowed_readers: readers.clone(),
                allowed_writers: writers.clone(),
                deleted: false,
            })
            .unwrap();
    }

    let host =
        SpaceHost::with_in_memory_replay(host_did.clone(), host_kp, backend.clone(), resolver);

    // 1. Foreign space authority rejected on authorizeSpaceSync / verify_presentation / notify / remove.
    let foreign_del = mint_delegation_token(
        &reader_kp,
        &reader,
        &other_host,
        &foreign_space,
        now,
        now + 60,
        None,
        None,
    )
    .unwrap();
    assert!(matches!(
        block_on(host.handle_authorize_space_sync(
            &AuthorizeSpaceSyncInput::new(foreign_space.clone(), holder_kid_1.clone()),
            Some(&foreign_del),
            now,
        )),
        Err(SpaceError::InvalidSubject(_))
    ));

    // 2. Delegation cnf.kid binding mismatch rejected; matching cnf.kid succeeds once and cannot replay.
    let bound_del = mint_delegation_token_with_cnf(
        &reader_kp,
        &reader,
        &host_did,
        &space_a,
        Some(&holder_kid_1),
        now,
        now + 60,
        Some("del-jti-once"),
        None,
    )
    .unwrap();
    assert!(matches!(
        block_on(host.handle_authorize_space_sync(
            &AuthorizeSpaceSyncInput::new(space_a.clone(), holder_kid_2.clone()),
            Some(&bound_del),
            now,
        )),
        Err(SpaceError::TokenRejected { .. })
    ));

    let (auth_out_1, _) = block_on(host.handle_authorize_space_sync(
        &AuthorizeSpaceSyncInput::new(space_a.clone(), holder_kid_1.clone()),
        Some(&bound_del),
        now,
    ))
    .unwrap();
    assert!(matches!(
        block_on(host.handle_authorize_space_sync(
            &AuthorizeSpaceSyncInput::new(space_a.clone(), holder_kid_1.clone()),
            Some(&bound_del),
            now,
        )),
        Err(SpaceError::TokenRejected { .. })
    ));

    // Mint second credential under holder_kp_2 for cross-holder nonce scoping test.
    let del_2 = mint_delegation_token_with_cnf(
        &reader_kp,
        &reader,
        &host_did,
        &space_a,
        Some(&holder_kid_2),
        now,
        now + 60,
        Some("del-jti-2"),
        None,
    )
    .unwrap();
    let (auth_out_2, _) = block_on(host.handle_authorize_space_sync(
        &AuthorizeSpaceSyncInput::new(space_a.clone(), holder_kid_2.clone()),
        Some(&del_2),
        now,
    ))
    .unwrap();

    // 3. Presentation requires nonce by default, rejects wrong target space, and scopes nonces per holder key.
    let min_hdrs =
        sign_credential_request_minimal(&auth_out_1.credential, &holder_kp_1, host_did.as_str())
            .unwrap();
    let mut min_map = HeaderMap::new();
    min_hdrs.apply_to_header_map(&mut min_map).unwrap();
    assert!(matches!(
        block_on(host.verify_presentation(&min_map, &space_a, now)),
        Err(SpaceError::MissingHeader(_))
    ));

    let hdrs_1 = sign_credential_request(
        &auth_out_1.credential,
        &holder_kp_1,
        host_did.as_str(),
        now,
        Some("shared-nonce-1"),
    )
    .unwrap();
    let mut map_1 = HeaderMap::new();
    hdrs_1.apply_to_header_map(&mut map_1).unwrap();
    assert!(matches!(
        block_on(host.verify_presentation(&map_1, &space_b, now)),
        Err(SpaceError::InvalidSubject(_))
    ));
    block_on(host.verify_presentation(&map_1, &space_a, now)).unwrap();
    assert!(matches!(
        block_on(host.verify_presentation(&map_1, &space_a, now)),
        Err(SpaceError::SignatureReplay)
    ));

    // Different holder key using the same nonce string succeeds once, then replays.
    let hdrs_2 = sign_credential_request(
        &auth_out_2.credential,
        &holder_kp_2,
        host_did.as_str(),
        now,
        Some("shared-nonce-1"),
    )
    .unwrap();
    let mut map_2 = HeaderMap::new();
    hdrs_2.apply_to_header_map(&mut map_2).unwrap();
    block_on(host.verify_presentation(&map_2, &space_a, now)).unwrap();
    assert!(matches!(
        block_on(host.verify_presentation(&map_2, &space_a, now)),
        Err(SpaceError::SignatureReplay)
    ));

    // 4. notifyRepoUpdate and removeWriter enforce caller identity, 32B commitment, and deleted-space guard.
    let s1 = backend.next_space_rev(1_800_000_000_000_100).unwrap();
    let s2 = backend.next_space_rev(1_800_000_000_000_101).unwrap();
    let r_rev = Tid::parse("3l2aaaaaaaaaa").unwrap();
    assert!(matches!(
        block_on(host.handle_notify_repo_update(
            &outsider,
            &NotifyRepoUpdateInput::new(
                space_a.clone(),
                writer.clone(),
                r_rev.clone(),
                AtBytes(vec![0_u8; 32]),
            ),
            s1.clone(),
        )),
        Err(SpaceError::Forbidden(_))
    ));
    assert!(matches!(
        block_on(host.handle_notify_repo_update(
            &writer,
            &NotifyRepoUpdateInput::new(
                space_a.clone(),
                writer.clone(),
                r_rev.clone(),
                AtBytes(vec![0_u8; 31]),
            ),
            s1.clone(),
        )),
        Err(SpaceError::MalformedPayload(_))
    ));
    assert!(matches!(
        block_on(host.handle_remove_writer(
            &outsider,
            &RemoveWriterInput::new(space_a.clone(), writer.clone()),
            s1.clone(),
            now,
        )),
        Err(SpaceError::Forbidden(_))
    ));
    // Self-removal by writer succeeds on active space.
    block_on(host.handle_remove_writer(
        &writer,
        &RemoveWriterInput::new(space_a.clone(), writer.clone()),
        s1,
        now,
    ))
    .unwrap();

    // Deleted space rejects both notifyRepoUpdate and removeWriter.
    backend
        .put_space(petrel_spaces::HostedSpace {
            space: space_a.clone(),
            policy: OutputPolicy::MemberspacePolicy(Box::new(MemberspacePolicy::new())),
            allowed_readers: readers,
            allowed_writers: writers,
            deleted: true,
        })
        .unwrap();
    assert!(matches!(
        block_on(host.handle_notify_repo_update(
            &writer,
            &NotifyRepoUpdateInput::new(
                space_a.clone(),
                writer.clone(),
                r_rev,
                AtBytes(vec![0_u8; 32]),
            ),
            s2.clone(),
        )),
        Err(SpaceError::SpaceDeleted(_))
    ));
    assert!(matches!(
        block_on(host.handle_remove_writer(
            &host_did,
            &RemoveWriterInput::new(space_a.clone(), writer),
            s2,
            now,
        )),
        Err(SpaceError::SpaceDeleted(_))
    ));

    // 5. Redacted Debug impls on SpaceCredential and NotifyRegistration hide secret tokens.
    let cred = SpaceCredential::from_issued_jwt(
        auth_out_1.credential.clone(),
        holder_kp_1,
        &space_a,
        None,
    )
    .unwrap();
    let cred_dbg = format!("{cred:?}");
    assert!(!cred_dbg.contains(&auth_out_1.credential));
    assert!(cred_dbg.contains("[REDACTED]"));

    let reg = NotifyRegistration {
        space: space_a,
        endpoint: "https://syncer.example.com/notify".to_owned(),
        token: "secret-notify-token".to_owned(),
        challenge: "secret-notify-challenge".to_owned(),
        confirmed: false,
        created_at: now,
    };
    let reg_dbg = format!("{reg:?}");
    assert!(!reg_dbg.contains("secret-notify-token"));
    assert!(!reg_dbg.contains("secret-notify-challenge"));
    assert!(reg_dbg.contains("[REDACTED]"));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]
#[test]
fn resolver_throttles_force_refresh_caches_negative_and_bounds_entries() {
    use petrel_spaces::SpaceDidResolver;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::time::Duration;

    let did_1 = Did::parse("did:plc:cache1111111111111111111").unwrap();
    let did_2 = Did::parse("did:plc:cache2222222222222222222").unwrap();
    let did_3 = Did::parse("did:plc:cache3333333333333333333").unwrap();
    let did_404 = Did::parse("did:plc:missing40444444444444444").unwrap();

    let hits = Arc::new(AtomicUsize::new(0));
    let hits_c = hits.clone();
    let transport_impl = Arc::new(ScriptedTransport::default());
    transport_impl.push(move |req| {
        hits_c.fetch_add(1, Ordering::SeqCst);
        let uri_str = req.uri().to_string();
        if let Some(did_str) = uri_str.strip_prefix("https://plc.directory/") {
            if did_str == "did:plc:missing40444444444444444" {
                return Some(Response::builder().status(404).body(Bytes::new()).unwrap());
            }
            return Some(json_resp(
                200,
                &serde_json::json!({
                    "id": did_str,
                    "service": [{
                        "id": "#atproto_space",
                        "type": "AtprotoSpaceHost",
                        "serviceEndpoint": "https://space.example.com"
                    }]
                }),
            ));
        }
        None
    });

    let transport: SharedTransport = transport_impl;
    let resolver = SpaceHostResolver::new(transport)
        .with_max_cache_entries(2)
        .with_negative_cache_ttl(Duration::from_secs(60))
        .with_force_refresh_cooldown(Duration::from_secs(60));

    // Negative cache: 404 fetched once, second !force_refresh hits negative cache, first force_refresh retries once,
    // second force_refresh within cooldown is throttled.
    assert!(matches!(
        block_on(resolver.resolve_did_document(&did_404, false)),
        Err(SpaceError::DidDocumentNotFound(_))
    ));
    assert_eq!(hits.load(Ordering::SeqCst), 1);
    assert!(matches!(
        block_on(resolver.resolve_did_document(&did_404, false)),
        Err(SpaceError::DidDocumentNotFound(_))
    ));
    assert_eq!(hits.load(Ordering::SeqCst), 1);
    assert!(matches!(
        block_on(resolver.resolve_did_document(&did_404, true)),
        Err(SpaceError::DidDocumentNotFound(_))
    ));
    assert_eq!(hits.load(Ordering::SeqCst), 2);
    assert!(matches!(
        block_on(resolver.resolve_did_document(&did_404, true)),
        Err(SpaceError::DidDocumentNotFound(_))
    ));
    assert_eq!(hits.load(Ordering::SeqCst), 2);

    // Cache bounding (max_cache_entries = 2): loading did_1, did_2, did_3 evicts oldest entries cleanly.
    block_on(resolver.resolve_did_document(&did_1, false)).unwrap();
    block_on(resolver.resolve_did_document(&did_2, false)).unwrap();
    block_on(resolver.resolve_did_document(&did_3, false)).unwrap();
    let before = hits.load(Ordering::SeqCst);
    // did_2 and did_3 are cached (0 network hits); did_1 was evicted so resolving it hits network once.
    block_on(resolver.resolve_did_document(&did_3, false)).unwrap();
    block_on(resolver.resolve_did_document(&did_2, false)).unwrap();
    assert_eq!(hits.load(Ordering::SeqCst), before);
    block_on(resolver.resolve_did_document(&did_1, false)).unwrap();
    assert_eq!(hits.load(Ordering::SeqCst), before + 1);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[allow(clippy::too_many_lines)]
#[test]
fn host_rejects_non_increasing_space_rev_in_upsert_and_remove_writer() {
    let now = 1_800_000_000_i64;
    let host_did = Did::parse("did:web:host.example.com").unwrap();
    let writer_a = Did::parse("did:plc:writeraaaaaaaaaaaaaaaaaa").unwrap();
    let writer_b = Did::parse("did:plc:writerbbbbbbbbbbbbbbbbbb").unwrap();
    let space =
        parse_space_ref("at:space/did:web:host.example.com/blue.catbird.mlsChat/3l2spacerevord")
            .unwrap();

    let mut allowed_writers = HashSet::new();
    allowed_writers.insert(writer_a.clone());
    allowed_writers.insert(writer_b.clone());

    let backend = Arc::new(InMemorySpaceHostBackend::new());
    backend
        .put_space(petrel_spaces::HostedSpace {
            space: space.clone(),
            policy: OutputPolicy::MemberspacePolicy(Box::new(MemberspacePolicy::new())),
            allowed_readers: HashSet::new(),
            allowed_writers,
            deleted: false,
        })
        .unwrap();

    let host = SpaceHost::with_in_memory_replay(
        host_did.clone(),
        SigningKeyPair::generate_p256().unwrap(),
        backend.clone(),
        Arc::new(StaticDidResolver::new()),
    );

    let s1 = backend.next_space_rev(1_800_000_000_000_200).unwrap();
    let s2 = backend.next_space_rev(1_800_000_000_000_201).unwrap();
    let s3 = backend.next_space_rev(1_800_000_000_000_202).unwrap();
    let s4 = backend.next_space_rev(1_800_000_000_000_203).unwrap();
    let r_a = Tid::parse("3l2aaaaaaaaaa").unwrap();
    let r_b = Tid::parse("3l2aaaaaaaaab").unwrap();

    // Writer A commits at higher space_rev s2.
    block_on(host.handle_notify_repo_update(
        &writer_a,
        &NotifyRepoUpdateInput::new(
            space.clone(),
            writer_a.clone(),
            r_a,
            AtBytes(vec![1_u8; 32]),
        ),
        s2.clone(),
    ))
    .unwrap();

    // Out-of-order writer B commit at older s1 or equal s2 must fail with 409 StaleSpaceRev.
    for stale in [&s1, &s2] {
        let err = block_on(host.handle_notify_repo_update(
            &writer_b,
            &NotifyRepoUpdateInput::new(
                space.clone(),
                writer_b.clone(),
                r_b.clone(),
                AtBytes(vec![2_u8; 32]),
            ),
            stale.clone(),
        ))
        .unwrap_err();
        assert!(
            matches!(err, SpaceError::Xrpc { status: 409, ref error, .. } if error == "StaleSpaceRev"),
            "unexpected error for stale upsert: {err:?}"
        );
    }

    // Out-of-order remove_writer at s1 or s2 must also fail with 409 StaleSpaceRev and leave writer A intact.
    for stale in [&s1, &s2] {
        let err = block_on(host.handle_remove_writer(
            &host_did,
            &RemoveWriterInput::new(space.clone(), writer_a.clone()),
            stale.clone(),
            now,
        ))
        .unwrap_err();
        assert!(
            matches!(err, SpaceError::Xrpc { status: 409, ref error, .. } if error == "StaleSpaceRev"),
            "unexpected error for stale remove: {err:?}"
        );
    }

    let initial_list = block_on(host.handle_list_writers(&space, None, 50)).unwrap();
    assert_eq!(initial_list.repos.len(), 1);
    assert!(matches!(
        &initial_list.repos[0],
        petrel_api::generated::com::atproto::space::list_writers::OutputRepos::RepoWrite(w)
            if w.repo == writer_a
    ));
    let after_s2 = block_on(host.handle_list_writers(&space, Some(s2.as_str()), 50)).unwrap();
    assert_eq!(after_s2.repos.len(), 0);

    // Newer space_rev s3 succeeds for writer B and is visible after cursor s2.
    let u_b = block_on(host.handle_notify_repo_update(
        &writer_b,
        &NotifyRepoUpdateInput::new(
            space.clone(),
            writer_b.clone(),
            r_b,
            AtBytes(vec![2_u8; 32]),
        ),
        s3.clone(),
    ))
    .unwrap();
    assert!(matches!(
        u_b,
        petrel_api::generated::com::atproto::space::notify_space_update::InputUpdate::RepoWrite(w)
            if w.prev_space_rev.as_ref() == Some(&s2)
    ));
    let delta_after_s2 = block_on(host.handle_list_writers(&space, Some(s2.as_str()), 50)).unwrap();
    assert_eq!(delta_after_s2.repos.len(), 1);

    // Newer space_rev s4 removes writer A with prev_space_rev == Some(s3).
    let rem_a = block_on(host.handle_remove_writer(
        &host_did,
        &RemoveWriterInput::new(space.clone(), writer_a),
        s4,
        now,
    ))
    .unwrap();
    assert!(matches!(
        rem_a,
        petrel_api::generated::com::atproto::space::notify_space_update::InputUpdate::RepoRemoved(
            r
        ) if r.prev_space_rev.as_ref() == Some(&s3)
    ));
}

#[cfg(not(target_arch = "wasm32"))]
#[allow(clippy::too_many_lines)]
#[tokio::test]
async fn credential_manager_concurrent_401_revocation_preserves_in_flight_refresh_and_replacement()
{
    use std::sync::atomic::{AtomicUsize, Ordering};
    use tokio::sync::Notify;

    struct BlockingExchanger {
        host_did: Did,
        host_kp: SigningKeyPair,
        calls: AtomicUsize,
        second_started: Arc<Notify>,
        allow_second_finish: Arc<Notify>,
    }

    impl CredentialExchanger for BlockingExchanger {
        fn exchange<'a>(
            &'a self,
            space: &'a SpaceRef,
            proof_key: &'a SigningKeyPair,
            now: i64,
        ) -> petrel_spaces::BoxFuture<'a, petrel_spaces::Result<SpaceCredential>> {
            Box::pin(async move {
                let n = self.calls.fetch_add(1, Ordering::SeqCst) + 1;
                if n == 2 {
                    self.second_started.notify_one();
                    self.allow_second_finish.notified().await;
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

    struct ConcurrentRevokeTransport {
        revoked_cred_jwt: String,
        both_sent_cred0: Arc<tokio::sync::Barrier>,
        release_second_401: Arc<Notify>,
        second_401_sent: Arc<Notify>,
        first_401_sent: AtomicUsize,
        hits: AtomicUsize,
    }

    impl HttpTransport for ConcurrentRevokeTransport {
        fn send(
            &self,
            request: Request<Bytes>,
            _options: &SendOptions,
        ) -> impl Future<Output = Result<Response<Bytes>, TransportError>> + petrel::rt::MaybeSend
        {
            self.hits.fetch_add(1, Ordering::SeqCst);
            let auth_hdr = request
                .headers()
                .get(http::header::AUTHORIZATION)
                .and_then(|v| v.to_str().ok())
                .unwrap_or_default()
                .to_owned();
            let is_revoked = auth_hdr.contains(&self.revoked_cred_jwt);
            let both_sent = self.both_sent_cred0.clone();
            let release_second = self.release_second_401.clone();
            let second_sent = self.second_401_sent.clone();
            let which = if is_revoked {
                Some(self.first_401_sent.fetch_add(1, Ordering::SeqCst))
            } else {
                None
            };
            async move {
                if let Some(idx) = which {
                    // Wait until BOTH concurrent requests have signed with cred_0 and reached HTTP send.
                    both_sent.wait().await;
                    if idx == 1 {
                        // Hold Request 2's 401 until Request 1 has already started exchange #2.
                        release_second.notified().await;
                        second_sent.notify_one();
                    }
                    return Ok(Response::builder()
                        .status(401)
                        .header("content-type", "application/json")
                        .body(Bytes::from_static(br#"{"error":"CredentialRevoked"}"#))
                        .unwrap());
                }
                Ok(Response::builder()
                    .status(200)
                    .body(Bytes::from_static(b"ok"))
                    .unwrap())
            }
        }
    }

    let now = 1_800_000_000_i64;
    let space =
        parse_space_ref("at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2conc401rev")
            .unwrap();
    let second_started = Arc::new(Notify::new());
    let allow_second_finish = Arc::new(Notify::new());
    let release_second_401 = Arc::new(Notify::new());
    let second_401_sent = Arc::new(Notify::new());
    let exchanger = Arc::new(BlockingExchanger {
        host_did: Did::parse("did:web:ds.catbird.blue").unwrap(),
        host_kp: SigningKeyPair::generate_p256().unwrap(),
        calls: AtomicUsize::new(0),
        second_started: second_started.clone(),
        allow_second_finish: allow_second_finish.clone(),
    });
    let mgr = Arc::new(SpaceCredentialManager::new(exchanger.clone()));
    let cred_0 = mgr.credential(&space, false, now).await.unwrap();

    let transport: SharedTransport = Arc::new(ConcurrentRevokeTransport {
        revoked_cred_jwt: cred_0.jwt.clone(),
        both_sent_cred0: Arc::new(tokio::sync::Barrier::new(2)),
        release_second_401: release_second_401.clone(),
        second_401_sent: second_401_sent.clone(),
        first_401_sent: AtomicUsize::new(0),
        hits: AtomicUsize::new(0),
    });
    let url = Url::parse("https://ds.catbird.blue/xrpc/com.atproto.space.getSpace").unwrap();
    let empty_headers = http::HeaderMap::new();

    // Launch two concurrent requests both using cached cred_0.
    let mgr_1 = mgr.clone();
    let tr_1 = transport.clone();
    let sp_1 = space.clone();
    let url_1 = url.clone();
    let hdr_1 = empty_headers.clone();
    let h1 = tokio::spawn(async move {
        mgr_1
            .send_signed_request(
                &tr_1,
                &sp_1,
                http::Method::GET,
                &url_1,
                None,
                &hdr_1,
                Bytes::new(),
                now,
                None,
            )
            .await
    });
    let mgr_2 = mgr.clone();
    let tr_2 = transport.clone();
    let sp_2 = space.clone();
    let url_2 = url.clone();
    let h2 = tokio::spawn(async move {
        mgr_2
            .send_signed_request(
                &tr_2,
                &sp_2,
                http::Method::GET,
                &url_2,
                None,
                &empty_headers,
                Bytes::new(),
                now,
                None,
            )
            .await
    });

    // Wait until Request 1 gets 401, evicts cred_0, and suspends mid-flight inside exchange #2.
    tokio::time::timeout(std::time::Duration::from_secs(2), second_started.notified())
        .await
        .expect("timed out waiting for exchange #2 to start");
    // Now deliver Request 2's delayed 401 for cred_0 while exchange #2 is in flight.
    release_second_401.notify_one();
    tokio::time::timeout(
        std::time::Duration::from_secs(2),
        second_401_sent.notified(),
    )
    .await
    .expect("timed out waiting for Request 2 401 to be delivered");
    tokio::time::sleep(std::time::Duration::from_millis(20)).await;
    allow_second_finish.notify_one();

    let (r1, r2) = tokio::time::timeout(std::time::Duration::from_secs(2), async {
        tokio::join!(h1, h2)
    })
    .await
    .expect("timed out waiting for h1/h2 completion");
    assert_eq!(r1.unwrap().unwrap().status(), StatusCode::OK);
    assert_eq!(r2.unwrap().unwrap().status(), StatusCode::OK);
    // Both requests share the single replacement credential cred_1 (2 exchanges total, zero InvalidationDuringExchange).
    assert_eq!(exchanger.calls.load(Ordering::SeqCst), 2);

    // Late 401 notification referencing stale cred_0 must NOT evict cached cred_1.
    let cred_1 = mgr.credential(&space, false, now).await.unwrap();
    assert_ne!(cred_1.jwt, cred_0.jwt);
    assert!(mgr.evict_credential_if_revoked(
        &cred_0,
        StatusCode::UNAUTHORIZED,
        br#"{"error":"CredentialRevoked"}"#,
    ));
    let still_cred_1 = mgr.credential(&space, false, now).await.unwrap();
    assert_eq!(still_cred_1.jwt, cred_1.jwt);
    assert_eq!(exchanger.calls.load(Ordering::SeqCst), 2);

    // Matching cred_1 eviction DOES evict cred_1 and trigger exchange #3.
    assert!(mgr.evict_credential_if_revoked(
        &cred_1,
        StatusCode::UNAUTHORIZED,
        br#"{"error":"CredentialRevoked"}"#,
    ));
    let cred_2 = mgr.credential(&space, false, now).await.unwrap();
    assert_ne!(cred_2.jwt, cred_1.jwt);
    assert_eq!(exchanger.calls.load(Ordering::SeqCst), 3);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn host_batches_revocation_notices_within_max_length_100() {
    use petrel_spaces::{MAX_CREDENTIALS_PER_REVOCATION_NOTICE, SpaceHostBackend};

    let now = 1_800_000_000_i64;
    let host_did = Did::parse("did:web:host.example.com").unwrap();
    let user = Did::parse("did:plc:batchuser1111111111111111").unwrap();
    let space =
        parse_space_ref("at:space/did:web:host.example.com/blue.catbird.mlsChat/3l2batchrevok")
            .unwrap();
    let foreign_space =
        parse_space_ref("at:space/did:web:other.example.com/blue.catbird.mlsChat/3l2batchother")
            .unwrap();

    let backend = Arc::new(InMemorySpaceHostBackend::new());
    let host = SpaceHost::with_in_memory_replay(
        host_did,
        SigningKeyPair::generate_p256().unwrap(),
        backend.clone(),
        Arc::new(StaticDidResolver::new()),
    );

    // Foreign space authority fails closed.
    assert!(matches!(
        block_on(host.revoke_user_credentials_and_build_notices(&foreign_space, &user)),
        Err(SpaceError::InvalidSubject(_))
    ));

    // Zero credentials -> empty Vec.
    let empty_notices =
        block_on(host.revoke_user_credentials_and_build_notices(&space, &user)).unwrap();
    assert_eq!(empty_notices.len(), 0);

    // Exact boundary: 100 credentials -> 1 notice of 100.
    for i in 0..MAX_CREDENTIALS_PER_REVOCATION_NOTICE {
        block_on(backend.record_issued_credential(&space, &user, &format!("jti-100-{i}"), now))
            .unwrap();
    }
    let exact_notices =
        block_on(host.revoke_user_credentials_and_build_notices(&space, &user)).unwrap();
    assert_eq!(exact_notices.len(), 1);
    assert_eq!(exact_notices[0].credentials.len(), 100);

    // Over limit: 205 credentials -> [100, 100, 5] preserving all unique JTIs.
    let mut expected_jtis = Vec::with_capacity(205);
    for i in 0..205 {
        let jti = format!("jti-205-{i}");
        expected_jtis.push(jti.clone());
        block_on(backend.record_issued_credential(&space, &user, &jti, now + i64::from(i)))
            .unwrap();
    }
    let batched = block_on(host.revoke_user_credentials_and_build_notices(&space, &user)).unwrap();
    assert_eq!(batched.len(), 3);
    assert_eq!(batched[0].credentials.len(), 100);
    assert_eq!(batched[1].credentials.len(), 100);
    assert_eq!(batched[2].credentials.len(), 5);
    let mut collected: Vec<String> = Vec::new();
    for notice in batched {
        assert_eq!(notice.space, space);
        assert!((1..=MAX_CREDENTIALS_PER_REVOCATION_NOTICE).contains(&notice.credentials.len()));
        collected.extend(notice.credentials);
    }
    assert_eq!(collected, expected_jtis);

    // Subsequent revocation has no active credentials remaining.
    let after = block_on(host.revoke_user_credentials_and_build_notices(&space, &user)).unwrap();
    assert_eq!(after.len(), 0);
}
