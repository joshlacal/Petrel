#![cfg(not(target_arch = "wasm32"))]

mod common;

use std::collections::{BTreeMap, HashMap};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};

use async_lock::Mutex;
use common::{TestClient, TestClock, TestServer, make_dpop_proof};
use petrel::identity::DnsResolver;
use petrel::rt::BoxFuture;
use petrel_core::{Cid, Did, Value, dagcbor};
use petrel_crypto::{ATProtoKeyCurve, ATProtoSigner, K256Keypair, P256Keypair, PublicKey};
use petrel_lexicon::{LexiconDnsResolver, LexiconResolutionError};
use petrel_repo::{
    CommitError, CommitSigner, InMemoryBlockStore, MstKeySyntax, MstOptions, MstProof,
    PublicRepositoryCAR, Repository, RepositoryBlock, RepositoryLimits, RepositoryPath,
    RepositoryReadPolicy, SigningAlgorithm, WriteBatch, WriteOp,
};
use petrel_server::OAuthServerError;
use petrel_server::clients::{
    OAuthApplicationType, OAuthClientKind, OAuthClientMetadata, OAuthClientResolving,
    OAuthRemoteFetchPolicy, OAuthRemoteFetchResponse, OAuthRemoteTransport,
    OAuthResolvedClientMetadata, OAuthTokenEndpointAuthMethod,
};
use petrel_server::dpop::OAuthDpopProofValidator;
use petrel_server::http::{OAuthHttpHeaders, OAuthHttpRequest};
use petrel_server::lexicon::{
    CachingOAuthLexiconResolver, OAuthLexiconDocument, OAuthLexiconResolution,
    OAuthLexiconResolverFailure, OAuthLexiconResolving, OAuthLexiconScopeResolution,
    OAuthScopeDescription, OAuthScopeResolutionStage, PetrelOAuthScopeResolver,
};
use petrel_server::lexicon_resolver::{
    AuthenticatedLexiconResolutionFailure, AuthenticatedOAuthLexiconResolver,
    OAuthLexiconAuthority, OAuthLexiconAuthorityError, OAuthLexiconAuthorityResolving,
    OAuthLexiconResolverConfigurationError,
};
use petrel_server::oauth::config::OAuthAccessTokenFormat;
use petrel_server::store::InMemoryOAuthStore;
use petrel_server::support::OAuthClock;
use url::Url;

const DEFAULT_NSID: &str = "com.example.foo.authBasic";
const DEFAULT_DID: &str = "did:plc:z72i7hdynmk6r22z27h6tvur";
const OTHER_DID: &str = "did:plc:ewvi7nxzyoun6zhxrhs64oiz";
const DEFAULT_PDS: &str = "https://pds.example.com";
const DEFAULT_TXT_NAME: &str = "_lexicon.foo.example.com";

#[derive(Clone)]
enum TestKeypair {
    P256(P256Keypair),
    Secp256k1(K256Keypair),
}

impl TestKeypair {
    fn generate(curve: ATProtoKeyCurve) -> Self {
        match curve {
            ATProtoKeyCurve::P256 => Self::P256(P256Keypair::generate().expect("p256 keypair")),
            ATProtoKeyCurve::Secp256k1 => {
                Self::Secp256k1(K256Keypair::generate().expect("k256 keypair"))
            }
        }
    }

    fn public_key(&self) -> PublicKey {
        match self {
            Self::P256(kp) => kp.public_key().clone(),
            Self::Secp256k1(kp) => kp.public_key().clone(),
        }
    }

    async fn sign_low_s(&self, msg: &[u8]) -> Result<Vec<u8>, CommitError> {
        let sig = match self {
            Self::P256(kp) => ATProtoSigner::sign(kp, msg).await,
            Self::Secp256k1(kp) => ATProtoSigner::sign(kp, msg).await,
        }
        .map_err(|e| CommitError::SigningFailed(e.to_string()))?;
        Ok(sig.to_vec())
    }
}

impl CommitSigner for TestKeypair {
    fn algorithm(&self) -> SigningAlgorithm {
        match self {
            Self::P256(_) => SigningAlgorithm::P256,
            Self::Secp256k1(_) => SigningAlgorithm::Secp256k1,
        }
    }

    fn sign<'a>(
        &'a self,
        unsigned_commit_bytes: &'a [u8],
    ) -> BoxFuture<'a, Result<Vec<u8>, CommitError>> {
        let kp = self.clone();
        Box::pin(async move { kp.sign_low_s(unsigned_commit_bytes).await })
    }
}

#[derive(Clone, Copy)]
enum ProofVariant {
    Valid,
    TwoCarRoots,
    CrossRepositorySubstitution,
    FlippedCommitSignatureByte,
    CommitSignedWithUnnamedKey,
    HighSSignature,
    RecordPresentButUnlinked,
    OmittedPathNode,
    RecordTypeMismatch(&'static str),
    LexiconIdMismatch(&'static str),
}

struct ProofFixture {
    car_bytes: Vec<u8>,
    record_cid: Cid,
    document_public_key: PublicKey,
    commit_public_key: PublicKey,
}

#[allow(clippy::too_many_lines)]
async fn build_proof_fixture_with_record(
    variant: ProofVariant,
    curve: ATProtoKeyCurve,
    record_json: serde_json::Value,
) -> ProofFixture {
    let doc_kp = TestKeypair::generate(curve);
    let alt_kp = TestKeypair::generate(curve);

    let (commit_did, signing_kp) = match variant {
        ProofVariant::CrossRepositorySubstitution => (OTHER_DID, alt_kp.clone()),
        ProofVariant::CommitSignedWithUnnamedKey => (DEFAULT_DID, alt_kp.clone()),
        _ => (DEFAULT_DID, doc_kp.clone()),
    };

    let record_json = match variant {
        ProofVariant::RecordTypeMismatch(wrong_type) => {
            let mut obj = record_json.as_object().expect("object").clone();
            obj.insert("$type".into(), serde_json::Value::String(wrong_type.into()));
            serde_json::Value::Object(obj)
        }
        ProofVariant::LexiconIdMismatch(wrong_id) => {
            let mut obj = record_json.as_object().expect("object").clone();
            obj.insert("id".into(), serde_json::Value::String(wrong_id.into()));
            serde_json::Value::Object(obj)
        }
        _ => record_json,
    };

    let target_bytes = serde_json::to_vec(&record_json).unwrap();
    let target_cbor = dagcbor::encode(&Value::from_json_record(&target_bytes).expect("to Value"));
    let target_cid = Cid::for_dag_cbor(&target_cbor);
    let sibling_bytes = serde_json::to_vec(&serde_json::json!({
        "$type": "com.atproto.lexicon.schema",
        "lexicon": 1,
        "id": "com.example.foo.sibling",
        "defs": { "main": { "type": "query" } }
    }))
    .unwrap();
    let sibling_cbor = dagcbor::encode(&Value::from_json_record(&sibling_bytes).unwrap());

    let write_policy = match variant {
        ProofVariant::RecordTypeMismatch(_) => RepositoryReadPolicy::data_model(),
        _ => RepositoryReadPolicy::strict(),
    };
    let repo = Repository::create_in_store(
        Did::parse(commit_did).unwrap(),
        &signing_kp,
        Arc::new(InMemoryBlockStore::new()),
        RepositoryLimits::standard(),
        write_policy,
    )
    .await
    .unwrap();
    let batch = match variant {
        ProofVariant::RecordPresentButUnlinked => WriteBatch::new(vec![WriteOp::Create {
            path: RepositoryPath::new("com.atproto.lexicon.schema", "com.example.foo.sibling")
                .unwrap(),
            record_cbor: sibling_cbor,
        }])
        .unwrap(),
        _ => WriteBatch::new(vec![
            WriteOp::Create {
                path: RepositoryPath::new("com.atproto.lexicon.schema", DEFAULT_NSID).unwrap(),
                record_cbor: target_cbor.clone(),
            },
            WriteOp::Create {
                path: RepositoryPath::new("com.atproto.lexicon.schema", "com.example.foo.sibling")
                    .unwrap(),
                record_cbor: sibling_cbor,
            },
        ])
        .unwrap(),
    };

    let committed = repo.commit_writes(batch, &signing_kp).await.unwrap();
    let bundle = committed
        .repository
        .record_proof("com.atproto.lexicon.schema", DEFAULT_NSID)
        .await
        .unwrap();

    let car_bytes = match variant {
        ProofVariant::TwoCarRoots => {
            let extra_root = Cid::for_dag_cbor(b"extra-root");
            PublicRepositoryCAR::write(&[bundle.commit_cid.clone(), extra_root], &bundle.blocks)
                .unwrap()
        }
        ProofVariant::FlippedCommitSignatureByte => {
            let mut blocks = bundle.blocks.clone();
            let mut commit_map: BTreeMap<String, Value> =
                match dagcbor::decode(&blocks[0].bytes).unwrap() {
                    Value::Object(m) => m,
                    _ => panic!("commit map"),
                };
            if let Some(Value::Bytes(sig)) = commit_map.get_mut("sig") {
                sig[0] ^= 0xff;
            }
            let new_bytes = dagcbor::encode(&Value::Object(commit_map));
            let new_cid = Cid::for_dag_cbor(&new_bytes);
            blocks[0] = RepositoryBlock::new(new_cid.clone(), new_bytes);
            PublicRepositoryCAR::write(&[new_cid], &blocks).unwrap()
        }
        ProofVariant::HighSSignature => {
            let mut blocks = bundle.blocks.clone();
            let mut commit_map: BTreeMap<String, Value> =
                match dagcbor::decode(&blocks[0].bytes).unwrap() {
                    Value::Object(m) => m,
                    _ => panic!("commit map"),
                };
            if let Some(Value::Bytes(sig)) = commit_map.get("sig") {
                let mut mutated = [0_u8; 64];
                mutated.copy_from_slice(sig);
                match curve {
                    ATProtoKeyCurve::P256 => {
                        let parsed = p256::ecdsa::Signature::from_slice(&mutated).unwrap();
                        let high_s: p256::Scalar = -*parsed.s();
                        mutated[32..64].copy_from_slice(&high_s.to_bytes());
                    }
                    ATProtoKeyCurve::Secp256k1 => {
                        let parsed = k256::ecdsa::Signature::from_slice(&mutated).unwrap();
                        let high_s: k256::Scalar = -*parsed.s();
                        mutated[32..64].copy_from_slice(&high_s.to_bytes());
                    }
                }
                commit_map.insert("sig".into(), Value::Bytes(mutated.to_vec()));
            }
            let new_bytes = dagcbor::encode(&Value::Object(commit_map));
            let new_cid = Cid::for_dag_cbor(&new_bytes);
            blocks[0] = RepositoryBlock::new(new_cid.clone(), new_bytes);
            PublicRepositoryCAR::write(&[new_cid], &blocks).unwrap()
        }
        ProofVariant::RecordPresentButUnlinked => {
            let mut blocks = bundle.blocks.clone();
            blocks.push(RepositoryBlock::new(target_cid.clone(), target_cbor));
            PublicRepositoryCAR::write(std::slice::from_ref(&bundle.commit_cid), &blocks).unwrap()
        }
        ProofVariant::OmittedPathNode => {
            // Drop MST path nodes between commit and target record block.
            let blocks = vec![
                bundle.blocks[0].clone(),
                bundle
                    .blocks
                    .iter()
                    .find(|b| b.cid == target_cid)
                    .cloned()
                    .unwrap(),
            ];
            PublicRepositoryCAR::write(std::slice::from_ref(&bundle.commit_cid), &blocks).unwrap()
        }
        _ => bundle.car().unwrap(),
    };

    let _ = (
        MstProof,
        MstKeySyntax::StrictAtProto,
        MstOptions::default(),
        RepositoryReadPolicy::strict(),
    );

    ProofFixture {
        car_bytes,
        record_cid: target_cid,
        document_public_key: doc_kp.public_key(),
        commit_public_key: signing_kp.public_key(),
    }
}

fn default_permission_set_json() -> serde_json::Value {
    serde_json::json!({
        "$type": "com.atproto.lexicon.schema",
        "lexicon": 1,
        "id": DEFAULT_NSID,
        "defs": {
            "main": {
                "type": "permission-set",
                "title": "Example Foo",
                "permissions": [
                    {
                        "type": "permission",
                        "resource": "repo",
                        "collection": ["com.example.foo.item"]
                    }
                ]
            }
        }
    })
}

#[derive(Default)]
struct StubDns {
    records: Mutex<HashMap<String, Vec<String>>>,
    failing: AtomicBool,
}

impl LexiconDnsResolver for StubDns {
    fn lookup_txt<'a>(
        &'a self,
        domain: &'a str,
    ) -> BoxFuture<'a, Result<Vec<String>, LexiconResolutionError>> {
        let domain = domain.to_owned();
        Box::pin(async move {
            if self.failing.load(Ordering::SeqCst) {
                return Err(LexiconResolutionError::DnsFailed {
                    domain,
                    message: "timed out".into(),
                });
            }
            Ok(self
                .records
                .lock()
                .await
                .get(&domain)
                .cloned()
                .unwrap_or_default())
        })
    }
}

#[allow(clippy::manual_async_fn)]
impl DnsResolver for StubDns {
    fn txt(
        &self,
        name: &str,
    ) -> impl std::future::Future<Output = Result<Vec<String>, petrel::identity::DnsError>>
    + petrel::rt::MaybeSend {
        let name = name.to_owned();
        async move {
            if self.failing.load(Ordering::SeqCst) {
                return Err(petrel::identity::DnsError::Lookup("timed out".into()));
            }
            Ok(self
                .records
                .lock()
                .await
                .get(&name)
                .cloned()
                .unwrap_or_default())
        }
    }

    fn lookup_ip(
        &self,
        _host: &str,
    ) -> impl std::future::Future<Output = Result<Vec<std::net::IpAddr>, petrel::identity::DnsError>>
    + petrel::rt::MaybeSend {
        async { Ok(Vec::new()) }
    }
}

#[derive(Default)]
struct StubAuthorities {
    map: Mutex<HashMap<String, OAuthLexiconAuthority>>,
    forced_error: Mutex<Option<OAuthLexiconAuthorityError>>,
}

impl OAuthLexiconAuthorityResolving for StubAuthorities {
    fn resolve_authority<'a>(
        &'a self,
        did: &'a str,
    ) -> BoxFuture<'a, Result<OAuthLexiconAuthority, OAuthLexiconAuthorityError>> {
        let did = did.to_owned();
        Box::pin(async move {
            if let Some(err) = self.forced_error.lock().await.clone() {
                return Err(err);
            }
            self.map
                .lock()
                .await
                .get(&did)
                .cloned()
                .ok_or(OAuthLexiconAuthorityError::DocumentUnavailable)
        })
    }
}

struct StubTransport {
    pins: bool,
    routes: Mutex<HashMap<String, (u16, Vec<u8>)>>,
    requests: Mutex<Vec<String>>,
}

impl StubTransport {
    fn pinning() -> Self {
        Self {
            pins: true,
            routes: Mutex::new(HashMap::new()),
            requests: Mutex::new(Vec::new()),
        }
    }

    fn non_pinning(inner: &Self, routes: HashMap<String, (u16, Vec<u8>)>) -> Self {
        let _ = inner;
        Self {
            pins: false,
            routes: Mutex::new(routes),
            requests: Mutex::new(Vec::new()),
        }
    }

    async fn serve(&self, url: &str, status: u16, body: Vec<u8>) {
        self.routes
            .lock()
            .await
            .insert(url.to_owned(), (status, body));
    }

    async fn recorded_requests(&self) -> Vec<String> {
        self.requests.lock().await.clone()
    }
}

impl OAuthRemoteTransport for StubTransport {
    fn pins_connections(&self) -> bool {
        self.pins
    }

    fn fetch<'a>(
        &'a self,
        url: &'a Url,
        _etag: Option<&'a str>,
        _policy: &'a OAuthRemoteFetchPolicy,
    ) -> BoxFuture<'a, Result<OAuthRemoteFetchResponse, OAuthServerError>> {
        let key = url.as_str().to_owned();
        Box::pin(async move {
            self.requests.lock().await.push(key.clone());
            let (status, body) = self
                .routes
                .lock()
                .await
                .get(&key)
                .cloned()
                .unwrap_or((404, b"{}".to_vec()));
            Ok(OAuthRemoteFetchResponse {
                status,
                headers: OAuthHttpHeaders::default(),
                body,
            })
        })
    }
}

fn get_record_url() -> String {
    let mut url = Url::parse(DEFAULT_PDS).unwrap();
    url.set_path("/xrpc/com.atproto.sync.getRecord");
    url.query_pairs_mut()
        .append_pair("did", DEFAULT_DID)
        .append_pair("collection", "com.atproto.lexicon.schema")
        .append_pair("rkey", DEFAULT_NSID);
    url.to_string()
}

async fn make_scenario(
    variant: ProofVariant,
    signed_by_commit_key: bool,
    curve: ATProtoKeyCurve,
) -> (
    ProofFixture,
    Arc<StubTransport>,
    Arc<StubDns>,
    Arc<StubAuthorities>,
    Arc<TestClock>,
) {
    let fixture =
        build_proof_fixture_with_record(variant, curve, default_permission_set_json()).await;
    let transport = Arc::new(StubTransport::pinning());
    transport
        .serve(&get_record_url(), 200, fixture.car_bytes.clone())
        .await;
    let dns = Arc::new(StubDns::default());
    dns.records
        .lock()
        .await
        .insert(DEFAULT_TXT_NAME.into(), vec![format!("did={DEFAULT_DID}")]);
    let key = if signed_by_commit_key {
        fixture.commit_public_key.clone()
    } else {
        fixture.document_public_key.clone()
    };
    let authorities = Arc::new(StubAuthorities::default());
    authorities.map.lock().await.insert(
        DEFAULT_DID.into(),
        OAuthLexiconAuthority {
            pds_endpoint: Url::parse(DEFAULT_PDS).unwrap(),
            signing_key: key,
        },
    );
    let clock = Arc::new(TestClock::new(1_700_000_000));
    (fixture, transport, dns, authorities, clock)
}

fn build_resolver(
    transport: Arc<dyn OAuthRemoteTransport>,
    dns: Arc<dyn LexiconDnsResolver>,
    authorities: Arc<dyn OAuthLexiconAuthorityResolving>,
    clock: Arc<TestClock>,
) -> AuthenticatedOAuthLexiconResolver {
    AuthenticatedOAuthLexiconResolver::new(
        transport,
        OAuthRemoteFetchPolicy {
            max_bytes: AuthenticatedOAuthLexiconResolver::MAXIMUM_CAR_BYTES,
            ..OAuthRemoteFetchPolicy::default()
        },
        dns,
        authorities,
        clock,
    )
    .expect("construct AuthenticatedOAuthLexiconResolver")
}

#[tokio::test]
async fn resolves_valid_proof_on_both_curves() {
    for curve in ATProtoKeyCurve::ALL {
        let (fixture, transport, dns, authorities, clock) =
            make_scenario(ProofVariant::Valid, false, curve).await;
        let resolver = build_resolver(transport.clone(), dns, authorities, clock);
        let outcome = resolver
            .resolve(DEFAULT_NSID)
            .await
            .expect("valid proof resolves");
        match outcome {
            OAuthLexiconResolution::Resolved(doc) => {
                assert_eq!(doc.nsid, DEFAULT_NSID);
                assert_eq!(doc.source_did.as_deref(), Some(DEFAULT_DID));
                assert_eq!(
                    doc.cid.as_deref(),
                    Some(fixture.record_cid.to_string().as_str())
                );
                let set = doc.permission_set.as_ref().expect("permission-set");
                assert_eq!(
                    set.permissions
                        .iter()
                        .map(|p| p.resource.as_str())
                        .collect::<Vec<_>>(),
                    vec!["repo"]
                );
            }
            other => panic!("unexpected outcome: {other:?}"),
        }
        assert_eq!(transport.recorded_requests().await, vec![get_record_url()]);
    }
}

#[tokio::test]
async fn refuses_broken_proofs_on_both_curves() {
    let cases = [
        (
            ProofVariant::TwoCarRoots,
            false,
            AuthenticatedLexiconResolutionFailure::CarRootCountInvalid,
        ),
        (
            ProofVariant::CrossRepositorySubstitution,
            false,
            AuthenticatedLexiconResolutionFailure::CommitDidMismatch,
        ),
        (
            ProofVariant::CrossRepositorySubstitution,
            true,
            AuthenticatedLexiconResolutionFailure::CommitDidMismatch,
        ),
        (
            ProofVariant::FlippedCommitSignatureByte,
            false,
            AuthenticatedLexiconResolutionFailure::CommitSignatureInvalid,
        ),
        (
            ProofVariant::CommitSignedWithUnnamedKey,
            false,
            AuthenticatedLexiconResolutionFailure::CommitSignatureInvalid,
        ),
        (
            ProofVariant::HighSSignature,
            false,
            AuthenticatedLexiconResolutionFailure::CommitSignatureInvalid,
        ),
        (
            ProofVariant::RecordPresentButUnlinked,
            false,
            AuthenticatedLexiconResolutionFailure::RecordNotInProof,
        ),
        (
            ProofVariant::OmittedPathNode,
            false,
            AuthenticatedLexiconResolutionFailure::RecordNotInProof,
        ),
        (
            ProofVariant::RecordTypeMismatch("com.example.foo.item"),
            false,
            AuthenticatedLexiconResolutionFailure::RecordTypeMismatch,
        ),
        (
            ProofVariant::LexiconIdMismatch("com.example.foo.other"),
            false,
            AuthenticatedLexiconResolutionFailure::DocumentIdMismatch,
        ),
    ];

    for curve in ATProtoKeyCurve::ALL {
        for (variant, signed_by_commit_key, expected) in cases {
            let (_, transport, dns, authorities, clock) =
                make_scenario(variant, signed_by_commit_key, curve).await;
            let resolver = build_resolver(transport, dns, authorities, clock);
            let err = resolver
                .perform_resolution(DEFAULT_NSID)
                .await
                .expect_err("broken proof must be rejected");
            assert_eq!(err, expected);
            assert!(resolver.resolve(DEFAULT_NSID).await.is_err());
        }
    }
}

#[tokio::test]
async fn txt_record_must_name_exactly_one_did() {
    let cases = [
        (
            vec![],
            AuthenticatedLexiconResolutionFailure::NoAuthorityDidInTxt,
        ),
        (
            vec!["v=spf1 -all".to_owned()],
            AuthenticatedLexiconResolutionFailure::NoAuthorityDidInTxt,
        ),
        (
            vec![format!("did={DEFAULT_DID}"), format!("did={OTHER_DID}")],
            AuthenticatedLexiconResolutionFailure::MultipleAuthorityDidsInTxt,
        ),
        // Two identical lines are still two.
        (
            vec![format!("did={DEFAULT_DID}"), format!("did={DEFAULT_DID}")],
            AuthenticatedLexiconResolutionFailure::MultipleAuthorityDidsInTxt,
        ),
        (
            vec!["did=not-a-did".to_owned()],
            AuthenticatedLexiconResolutionFailure::InvalidAuthorityDidInTxt,
        ),
    ];

    for (records, expected) in cases {
        let (_, transport, dns, authorities, clock) =
            make_scenario(ProofVariant::Valid, false, ATProtoKeyCurve::P256).await;
        dns.records
            .lock()
            .await
            .insert(DEFAULT_TXT_NAME.into(), records);
        let resolver = build_resolver(transport.clone(), dns, authorities, clock);
        assert_eq!(
            resolver.perform_resolution(DEFAULT_NSID).await.unwrap_err(),
            expected
        );
        assert_eq!(transport.recorded_requests().await, Vec::<String>::new());
    }
}

#[tokio::test]
async fn dns_did_document_and_nsid_failures_map_to_typed_failures() {
    let (_, transport, dns, authorities, clock) =
        make_scenario(ProofVariant::Valid, false, ATProtoKeyCurve::P256).await;
    let resolver = build_resolver(transport.clone(), dns.clone(), authorities.clone(), clock);

    assert_eq!(
        resolver
            .perform_resolution("not an nsid")
            .await
            .unwrap_err(),
        AuthenticatedLexiconResolutionFailure::InvalidNsid
    );

    dns.failing.store(true, Ordering::SeqCst);
    assert_eq!(
        resolver.perform_resolution(DEFAULT_NSID).await.unwrap_err(),
        AuthenticatedLexiconResolutionFailure::DnsUnavailable
    );
    dns.failing.store(false, Ordering::SeqCst);

    *authorities.forced_error.lock().await = Some(OAuthLexiconAuthorityError::DocumentIncomplete);
    assert_eq!(
        resolver.perform_resolution(DEFAULT_NSID).await.unwrap_err(),
        AuthenticatedLexiconResolutionFailure::AuthorityDocumentIncomplete
    );

    *authorities.forced_error.lock().await = Some(OAuthLexiconAuthorityError::DocumentUnavailable);
    assert_eq!(
        resolver.perform_resolution(DEFAULT_NSID).await.unwrap_err(),
        AuthenticatedLexiconResolutionFailure::AuthorityDocumentUnavailable
    );
    assert_eq!(transport.recorded_requests().await, Vec::<String>::new());
}

#[tokio::test]
async fn fetch_policy_enforces_pinning_exact_200_and_256kib_cap() {
    let (fixture, transport, dns, authorities, clock) =
        make_scenario(ProofVariant::Valid, false, ATProtoKeyCurve::P256).await;

    // Non-pinning transport is refused before making any HTTP call.
    let non_pinning = Arc::new(StubTransport::non_pinning(
        &transport,
        HashMap::from([(get_record_url(), (200, fixture.car_bytes.clone()))]),
    ));
    let np_resolver = build_resolver(
        non_pinning.clone(),
        dns.clone(),
        authorities.clone(),
        clock.clone(),
    );
    assert_eq!(
        np_resolver
            .perform_resolution(DEFAULT_NSID)
            .await
            .unwrap_err(),
        AuthenticatedLexiconResolutionFailure::RecordFetchFailed
    );
    assert_eq!(non_pinning.recorded_requests().await, Vec::<String>::new());

    // Non-200 status refused.
    transport
        .serve(&get_record_url(), 404, b"{}".to_vec())
        .await;
    let resolver = build_resolver(
        transport.clone(),
        dns.clone(),
        authorities.clone(),
        clock.clone(),
    );
    assert_eq!(
        resolver.perform_resolution(DEFAULT_NSID).await.unwrap_err(),
        AuthenticatedLexiconResolutionFailure::RecordFetchFailed
    );

    // A policy above 256 KiB violates the CPU safety cap.
    let err = AuthenticatedOAuthLexiconResolver::new(
        transport,
        OAuthRemoteFetchPolicy {
            max_bytes: 512 * 1024,
            ..OAuthRemoteFetchPolicy::default()
        },
        dns,
        authorities,
        clock,
    )
    .unwrap_err();
    assert_eq!(
        err,
        OAuthLexiconResolverConfigurationError::FetchPolicyTooPermissive {
            maximum_body_bytes: 512 * 1024
        }
    );
}

#[tokio::test]
async fn authentic_non_permission_set_resolves_as_not_permission_set() {
    let query_json = serde_json::json!({
        "$type": "com.atproto.lexicon.schema",
        "lexicon": 1,
        "id": DEFAULT_NSID,
        "defs": { "main": { "type": "query" } }
    });
    let fixture =
        build_proof_fixture_with_record(ProofVariant::Valid, ATProtoKeyCurve::P256, query_json)
            .await;
    let transport = Arc::new(StubTransport::pinning());
    transport
        .serve(&get_record_url(), 200, fixture.car_bytes)
        .await;
    let dns = Arc::new(StubDns::default());
    dns.records
        .lock()
        .await
        .insert(DEFAULT_TXT_NAME.into(), vec![format!("did={DEFAULT_DID}")]);
    let authorities = Arc::new(StubAuthorities::default());
    authorities.map.lock().await.insert(
        DEFAULT_DID.into(),
        OAuthLexiconAuthority {
            pds_endpoint: Url::parse(DEFAULT_PDS).unwrap(),
            signing_key: fixture.document_public_key,
        },
    );
    let resolver = build_resolver(
        transport,
        dns,
        authorities,
        Arc::new(TestClock::new(1_700_000_000)),
    );
    assert_eq!(
        resolver.resolve(DEFAULT_NSID).await.unwrap(),
        OAuthLexiconResolution::NotPermissionSet
    );
}

fn did_document_json(did: &str, key: &PublicKey, pds: &str) -> Vec<u8> {
    serde_json::to_vec(&serde_json::json!({
        "id": did,
        "verificationMethod": [{
            "id": format!("{did}#atproto"),
            "type": "Multikey",
            "controller": did,
            "publicKeyMultibase": key.multikey(),
        }],
        "service": [{
            "id": "#atproto_pds",
            "type": "AtprotoPersonalDataServer",
            "serviceEndpoint": pds,
        }],
    }))
    .unwrap()
}

#[tokio::test]
async fn identity_authority_fetches_plc_through_same_pinned_transport_and_rotates_on_ttl() {
    let (fixture, transport, dns, _, clock) =
        make_scenario(ProofVariant::Valid, false, ATProtoKeyCurve::P256).await;
    let plc_url = format!("https://plc.directory/{DEFAULT_DID}");
    transport
        .serve(
            &plc_url,
            200,
            did_document_json(DEFAULT_DID, &fixture.document_public_key, DEFAULT_PDS),
        )
        .await;

    let resolver = AuthenticatedOAuthLexiconResolver::with_identity_authorities(
        transport.clone(),
        OAuthRemoteFetchPolicy {
            max_bytes: AuthenticatedOAuthLexiconResolver::MAXIMUM_CAR_BYTES,
            ..OAuthRemoteFetchPolicy::default()
        },
        dns,
        Some(clock.clone()),
    )
    .expect("construct with identity authorities");

    match resolver.resolve(DEFAULT_NSID).await.unwrap() {
        OAuthLexiconResolution::Resolved(doc) => assert!(doc.permission_set.is_some()),
        other => panic!("expected resolved permission set, got {other:?}"),
    }
    assert_eq!(
        transport.recorded_requests().await,
        vec![plc_url.clone(), get_record_url()]
    );

    // Second resolve shares the 5-minute cached authority DID document.
    let _ = resolver.resolve(DEFAULT_NSID).await.unwrap();
    let plc_fetches = transport
        .recorded_requests()
        .await
        .into_iter()
        .filter(|u| u.starts_with("https://plc.directory/"))
        .count();
    assert_eq!(plc_fetches, 1);

    // Authority rotates signing key to secp256k1; once 5 minutes lapse, new DID doc is fetched.
    let rotated = build_proof_fixture_with_record(
        ProofVariant::Valid,
        ATProtoKeyCurve::Secp256k1,
        default_permission_set_json(),
    )
    .await;
    transport
        .serve(
            &plc_url,
            200,
            did_document_json(DEFAULT_DID, &rotated.document_public_key, DEFAULT_PDS),
        )
        .await;
    transport
        .serve(&get_record_url(), 200, rotated.car_bytes)
        .await;
    clock.advance(AuthenticatedOAuthLexiconResolver::AUTHORITY_CACHE_TTL_SECS + 1);

    match resolver.resolve(DEFAULT_NSID).await.unwrap() {
        OAuthLexiconResolution::Resolved(doc) => {
            assert_eq!(
                doc.cid.as_deref(),
                Some(rotated.record_cid.to_string().as_str())
            );
        }
        other => panic!("expected resolved rotated permission set, got {other:?}"),
    }
    let plc_fetches_after = transport
        .recorded_requests()
        .await
        .into_iter()
        .filter(|u| u.starts_with("https://plc.directory/"))
        .count();
    assert_eq!(plc_fetches_after, 2);
}

#[tokio::test]
async fn include_end_to_end_with_authenticated_and_caching_resolver() {
    let (_, transport, dns, authorities, clock) =
        make_scenario(ProofVariant::Valid, false, ATProtoKeyCurve::P256).await;
    let auth_resolver: Arc<dyn OAuthLexiconResolving> =
        Arc::new(build_resolver(transport.clone(), dns, authorities, clock));
    let cache_store = Arc::new(InMemoryOAuthStore::new());
    let caching: Arc<dyn OAuthLexiconResolving> =
        Arc::new(CachingOAuthLexiconResolver::new(auth_resolver, cache_store));
    let scope_resolver: Arc<dyn OAuthLexiconScopeResolution> =
        Arc::new(PetrelOAuthScopeResolver::new(caching));

    let harness =
        TestServer::new_with_scope_resolver(OAuthAccessTokenFormat::Opaque, Some(scope_resolver))
            .await;
    let include_scope = format!("include:{DEFAULT_NSID}");
    let inc_client_id = "https://inc-auth.example.com/client.json";
    let inc_redirect = "https://inc-auth.example.com/cb";
    harness
        .clients
        .register(OAuthResolvedClientMetadata {
            kind: OAuthClientKind::Discoverable,
            metadata: OAuthClientMetadata {
                client_id: inc_client_id.to_owned(),
                client_name: Some("Auth Inc App".to_owned()),
                client_uri: None,
                logo_uri: None,
                tos_uri: None,
                policy_uri: None,
                application_type: OAuthApplicationType::Web,
                grant_types: vec!["authorization_code".into(), "refresh_token".into()],
                response_types: vec!["code".into()],
                redirect_uris: vec![inc_redirect.into()],
                scope: Some(format!("atproto {include_scope}")),
                token_endpoint_auth_method: OAuthTokenEndpointAuthMethod::None,
                token_endpoint_auth_signing_alg: None,
                dpop_bound_access_tokens: true,
                jwks_uri: None,
                jwks: None,
            },
            key_set: None,
        })
        .await;

    let mut client = TestClient::web(&harness);
    client.client_id = inc_client_id.into();
    client.redirect_uri = inc_redirect.into();
    let tok = client
        .sign_in(
            common::ALICE_HANDLE,
            "alice-password",
            &format!("atproto {include_scope}"),
        )
        .await;
    assert_eq!(tok.scope, format!("atproto {include_scope}"));

    let verifier = harness
        .server
        .resource_verifier()
        .with_require_dpop_nonce(false);
    let res_url = "https://pds.example.com/xrpc/com.atproto.repo.createRecord";
    let ath = OAuthDpopProofValidator::access_token_hash(&tok.access_token);
    let proof = make_dpop_proof(
        &client.dpop_key,
        "POST",
        res_url,
        None,
        Some(&ath),
        harness.clock.now_secs(),
        "auth-inc-1",
    );
    let grant = verifier
        .authenticate(
            "POST",
            res_url,
            &OAuthHttpHeaders::new([
                (
                    "Authorization",
                    format!("DPoP {}", tok.access_token).as_str(),
                ),
                ("DPoP", proof.as_str()),
            ]),
        )
        .await
        .expect("resource grant");
    assert!(grant.require_repo("com.example.foo.item", "create").is_ok());
    assert!(
        grant
            .require_repo("com.example.bar.item", "create")
            .is_err()
    );
    assert!(
        transport
            .recorded_requests()
            .await
            .contains(&get_record_url())
    );
}

struct MutableUpstream {
    docs: Mutex<HashMap<String, OAuthLexiconResolution>>,
    failing: AtomicBool,
    calls: AtomicUsize,
}

impl MutableUpstream {
    fn new(docs: HashMap<String, OAuthLexiconResolution>) -> Self {
        Self {
            docs: Mutex::new(docs),
            failing: AtomicBool::new(false),
            calls: AtomicUsize::new(0),
        }
    }
}

impl OAuthLexiconResolving for MutableUpstream {
    fn resolve(
        &self,
        nsid: &str,
    ) -> BoxFuture<'_, Result<OAuthLexiconResolution, OAuthLexiconResolverFailure>> {
        let key = nsid.to_owned();
        Box::pin(async move {
            self.calls.fetch_add(1, Ordering::SeqCst);
            if self.failing.load(Ordering::SeqCst) {
                return Err(OAuthLexiconResolverFailure::Unavailable("outage".into()));
            }
            Ok(self
                .docs
                .lock()
                .await
                .get(&key)
                .cloned()
                .unwrap_or(OAuthLexiconResolution::NotFound))
        })
    }
}

fn auth_basic_json(extra_collection: Option<&str>) -> Vec<u8> {
    let mut collections = vec![serde_json::Value::String("app.example.post".into())];
    if let Some(extra) = extra_collection {
        collections.push(serde_json::Value::String(extra.into()));
    }
    serde_json::to_vec(&serde_json::json!({
        "lexicon": 1,
        "id": "app.example.authBasic",
        "defs": {
            "main": {
                "type": "permission-set",
                "title": "Example basics",
                "detail": "Post and read your feed",
                "title:lang": {
                    "fr": "Bases d'Example"
                },
                "permissions": [
                    { "type": "permission", "resource": "repo", "collection": collections },
                    { "type": "permission", "resource": "rpc", "lxm": ["app.example.getFeed"], "inheritAud": true },
                    { "type": "permission", "resource": "rpc", "lxm": ["app.example.getProfile"], "aud": "*" },
                    { "type": "permission", "resource": "repo", "collection": ["com.other.thing"] },
                    { "type": "permission", "resource": "repo", "collection": ["*"] },
                    { "type": "permission", "resource": "blob", "accept": ["*/*"] },
                    { "type": "permission", "resource": "account", "attr": "email" },
                    { "type": "permission", "resource": "future" },
                    { "type": "permission", "resource": "rpc", "lxm": ["app.example.getThing"], "aud": "did:web:fixed.example.com#x" },
                    { "type": "permission", "resource": "repo", "collection": ["app.example.like"], "unexpected": "value" }
                ]
            }
        }
    }))
    .unwrap()
}

#[tokio::test]
async fn caching_resolver_serves_fresh_refreshes_stale_survives_outages_and_negative_caches() {
    let basic_doc =
        OAuthLexiconDocument::from_json("app.example.authBasic", None, None, auth_basic_json(None))
            .unwrap();
    let upstream = Arc::new(MutableUpstream::new(HashMap::from([(
        "app.example.authBasic".into(),
        OAuthLexiconResolution::Resolved(Box::new(basic_doc.clone())),
    )])));
    let clock = Arc::new(TestClock::new(1_700_000_000));
    let resolver =
        CachingOAuthLexiconResolver::new(upstream.clone(), Arc::new(InMemoryOAuthStore::new()))
            .with_clock(clock.clone())
            .with_ttls(86_400, 90 * 86_400)
            .with_backoffs(300, 300);

    assert!(matches!(
        resolver.resolve("app.example.authBasic").await,
        Ok(OAuthLexiconResolution::Resolved(_))
    ));
    assert!(matches!(
        resolver.resolve("app.example.authBasic").await,
        Ok(OAuthLexiconResolution::Resolved(_))
    ));
    assert_eq!(upstream.calls.load(Ordering::SeqCst), 1);

    clock.advance(86_401);
    assert!(matches!(
        resolver.resolve("app.example.authBasic").await,
        Ok(OAuthLexiconResolution::Resolved(_))
    ));
    assert_eq!(upstream.calls.load(Ordering::SeqCst), 2);

    // Outage serves stale value and respects backoff cooldown.
    upstream.failing.store(true, Ordering::SeqCst);
    clock.advance(86_401);
    assert!(matches!(
        resolver.resolve("app.example.authBasic").await,
        Ok(OAuthLexiconResolution::Resolved(_))
    ));
    assert!(matches!(
        resolver.resolve("app.example.authBasic").await,
        Ok(OAuthLexiconResolution::Resolved(_))
    ));
    assert_eq!(upstream.calls.load(Ordering::SeqCst), 3);

    clock.advance(301);
    assert!(matches!(
        resolver.resolve("app.example.authBasic").await,
        Ok(OAuthLexiconResolution::Resolved(_))
    ));
    assert_eq!(upstream.calls.load(Ordering::SeqCst), 4);

    // Past 90 days stale TTL, fails.
    clock.advance(91 * 86_400);
    assert!(resolver.resolve("app.example.authBasic").await.is_err());

    // Negative cache avoids hammering missing NSIDs, then recovers after cooldown.
    upstream.failing.store(false, Ordering::SeqCst);
    let before = upstream.calls.load(Ordering::SeqCst);
    assert_eq!(
        resolver.resolve("app.example.missing").await.unwrap(),
        OAuthLexiconResolution::NotFound
    );
    assert_eq!(
        resolver.resolve("app.example.missing").await.unwrap(),
        OAuthLexiconResolution::NotFound
    );
    assert_eq!(upstream.calls.load(Ordering::SeqCst), before + 1);

    let missing_doc = OAuthLexiconDocument::from_json("app.example.missing", None, None, {
        let mut v: serde_json::Value = serde_json::from_slice(&auth_basic_json(None)).unwrap();
        v["id"] = serde_json::Value::String("app.example.missing".into());
        serde_json::to_vec(&v).unwrap()
    })
    .unwrap();
    upstream.docs.lock().await.insert(
        "app.example.missing".into(),
        OAuthLexiconResolution::Resolved(Box::new(missing_doc)),
    );
    clock.advance(301);
    assert!(matches!(
        resolver.resolve("app.example.missing").await,
        Ok(OAuthLexiconResolution::Resolved(_))
    ));
}

#[tokio::test]
async fn caching_resolver_evicts_expired_and_caps_backoff_tracking_maps() {
    let basic_doc =
        OAuthLexiconDocument::from_json("app.example.authBasic", None, None, auth_basic_json(None))
            .unwrap();
    let mut initial = HashMap::new();
    for idx in 0..5 {
        let nsid = format!("app.example.outage{idx}");
        let mut v: serde_json::Value = serde_json::from_slice(&auth_basic_json(None)).unwrap();
        v["id"] = serde_json::Value::String(nsid.clone());
        let doc =
            OAuthLexiconDocument::from_json(&nsid, None, None, serde_json::to_vec(&v).unwrap())
                .unwrap();
        initial.insert(nsid, OAuthLexiconResolution::Resolved(Box::new(doc)));
    }
    initial.insert(
        "app.example.authBasic".into(),
        OAuthLexiconResolution::Resolved(Box::new(basic_doc)),
    );
    let upstream = Arc::new(MutableUpstream::new(initial));
    let clock = Arc::new(TestClock::new(1_700_000_000));
    let resolver =
        CachingOAuthLexiconResolver::new(upstream.clone(), Arc::new(InMemoryOAuthStore::new()))
            .with_clock(clock.clone())
            .with_ttls(60, 86_400)
            .with_backoffs(120, 120)
            .with_max_backoff_entries(3);

    // Populate cache for 5 NSIDs while upstream succeeds, then expire fresh TTL and trigger outage.
    for idx in 0..5 {
        assert!(
            resolver
                .resolve(&format!("app.example.outage{idx}"))
                .await
                .is_ok()
        );
    }
    clock.advance(61);
    upstream.failing.store(true, Ordering::SeqCst);
    for idx in 0..5 {
        assert!(
            resolver
                .resolve(&format!("app.example.outage{idx}"))
                .await
                .is_ok()
        );
    }
    // Missing NSIDs populate `negative_until` up to the configured cap of 3.
    upstream.failing.store(false, Ordering::SeqCst);
    for idx in 0..5 {
        assert_eq!(
            resolver
                .resolve(&format!("app.example.never{idx}"))
                .await
                .unwrap(),
            OAuthLexiconResolution::NotFound
        );
    }
    let (neg_len, outage_len) = resolver.backoff_tracking_counts().await;
    assert_eq!(neg_len, 3);
    assert_eq!(outage_len, 3);

    // Advancing past TTL prunes all expired entries even when those NSIDs never succeed again.
    clock.advance(121);
    assert_eq!(resolver.backoff_tracking_counts().await, (0, 0));
}

#[tokio::test]
async fn caching_resolver_honors_negative_backoff_when_expired_cache_entry_exists() {
    let basic_doc =
        OAuthLexiconDocument::from_json("app.example.authBasic", None, None, auth_basic_json(None))
            .unwrap();
    let upstream = Arc::new(MutableUpstream::new(HashMap::from([(
        "app.example.authBasic".into(),
        OAuthLexiconResolution::Resolved(Box::new(basic_doc.clone())),
    )])));
    let clock = Arc::new(TestClock::new(1_700_000_000));
    let resolver =
        CachingOAuthLexiconResolver::new(upstream.clone(), Arc::new(InMemoryOAuthStore::new()))
            .with_clock(clock.clone())
            .with_ttls(60, 120)
            .with_backoffs(300, 300);

    // Populate persistent cache entry first.
    assert!(matches!(
        resolver.resolve("app.example.authBasic").await,
        Ok(OAuthLexiconResolution::Resolved(_))
    ));
    assert_eq!(upstream.calls.load(Ordering::SeqCst), 1);

    // Expire past `stale_until_secs` while upstream is down -> records negative backoff even though
    // `get_cached_lexicon` still returns `Some(entry)`.
    clock.advance(200);
    upstream.failing.store(true, Ordering::SeqCst);
    assert!(resolver.resolve("app.example.authBasic").await.is_err());
    assert_eq!(upstream.calls.load(Ordering::SeqCst), 2);

    // Subsequent calls within `negative_ttl_secs` must short-circuit without calling `upstream`.
    assert_eq!(
        resolver.resolve("app.example.authBasic").await.unwrap(),
        OAuthLexiconResolution::NotFound
    );
    assert_eq!(upstream.calls.load(Ordering::SeqCst), 2);

    // After negative backoff lapses and upstream recovers, upstream is called and cache refreshes.
    upstream.failing.store(false, Ordering::SeqCst);
    clock.advance(301);
    assert!(matches!(
        resolver.resolve("app.example.authBasic").await,
        Ok(OAuthLexiconResolution::Resolved(_))
    ));
    assert_eq!(upstream.calls.load(Ordering::SeqCst), 3);
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn permission_set_percent_audience_consent_and_unresolvable_par() {
    let basic_doc =
        OAuthLexiconDocument::from_json("app.example.authBasic", None, None, auth_basic_json(None))
            .unwrap();
    let other_doc = OAuthLexiconDocument::from_json(
        "app.example.other",
        None,
        None,
        serde_json::to_vec(&serde_json::json!({
            "lexicon": 1,
            "id": "app.example.other",
            "defs": { "main": { "type": "query" } }
        }))
        .unwrap(),
    )
    .unwrap();
    let upstream = Arc::new(MutableUpstream::new(HashMap::from([
        (
            "app.example.authBasic".into(),
            OAuthLexiconResolution::Resolved(Box::new(basic_doc)),
        ),
        (
            "app.example.other".into(),
            OAuthLexiconResolution::Resolved(Box::new(other_doc)),
        ),
    ])));
    let scope_resolver = Arc::new(PetrelOAuthScopeResolver::new(upstream.clone()));

    // Inherited % audience preserves `%26` vs `&`.
    let include_percent =
        "include:app.example.authBasic?aud=did:web:api.example.com%23svc%2526admin";
    let harness = TestServer::new_with_scope_resolver(
        OAuthAccessTokenFormat::Opaque,
        Some(scope_resolver.clone()),
    )
    .await;
    let client_id = "https://perm.example.com/client.json";
    let redirect = "https://perm.example.com/cb";
    harness
        .clients
        .register(OAuthResolvedClientMetadata {
            kind: OAuthClientKind::Discoverable,
            metadata: OAuthClientMetadata {
                client_id: client_id.to_owned(),
                client_name: Some("Perm App".to_owned()),
                client_uri: None,
                logo_uri: None,
                tos_uri: None,
                policy_uri: None,
                application_type: OAuthApplicationType::Web,
                grant_types: vec!["authorization_code".into(), "refresh_token".into()],
                response_types: vec!["code".into()],
                redirect_uris: vec![redirect.into()],
                scope: Some(format!(
                    "atproto {include_percent} include:app.example.other"
                )),
                token_endpoint_auth_method: OAuthTokenEndpointAuthMethod::None,
                token_endpoint_auth_signing_alg: None,
                dpop_bound_access_tokens: true,
                jwks_uri: None,
                jwks: None,
            },
            key_set: None,
        })
        .await;

    let mut client = TestClient::web(&harness);
    client.client_id = client_id.into();
    client.redirect_uri = redirect.into();
    let tok = client
        .sign_in(
            common::ALICE_HANDLE,
            "alice-password",
            &format!("atproto {include_percent}"),
        )
        .await;
    let verifier = harness
        .server
        .resource_verifier()
        .with_require_dpop_nonce(false);
    let rpc_url = "https://api.example.com/xrpc/app.example.getFeed";
    let ath = OAuthDpopProofValidator::access_token_hash(&tok.access_token);
    let proof = make_dpop_proof(
        &client.dpop_key,
        "GET",
        rpc_url,
        None,
        Some(&ath),
        harness.clock.now_secs(),
        "pct-1",
    );
    let grant = verifier
        .authenticate(
            "GET",
            rpc_url,
            &OAuthHttpHeaders::new([
                (
                    "Authorization",
                    format!("DPoP {}", tok.access_token).as_str(),
                ),
                ("DPoP", proof.as_str()),
            ]),
        )
        .await
        .expect("rpc grant");
    assert!(
        grant
            .require_rpc("app.example.getFeed", "did:web:api.example.com#svc%26admin")
            .is_ok()
    );
    assert!(
        grant
            .require_rpc("app.example.getFeed", "did:web:api.example.com#svc&admin")
            .is_err()
    );
    assert!(grant.require_repo("app.example.post", "create").is_ok());
    assert!(grant.require_repo("com.other.thing", "create").is_err());
    assert!(grant.require_repo("app.example.like", "create").is_err());

    // Localized consent description.
    let requested =
        petrel_oauth_scopes::ScopeSet::from_scope_string(&format!("atproto {include_percent}"));
    let expanded = scope_resolver
        .resolve_scopes(
            &requested,
            &requested,
            petrel_oauth_scopes::OAuthUnknownScopePolicy::Reject,
            OAuthScopeResolutionStage::Authorization,
            &["fr-CA", "en"],
        )
        .await
        .expect("localized summary");
    let perm_desc: &OAuthScopeDescription = expanded
        .descriptions
        .iter()
        .find(|d| d.source_nsid.as_deref() == Some("app.example.authBasic"))
        .expect("permission-set description");
    assert_eq!(perm_desc.title.as_deref(), Some("Bases d'Example"));
    assert_eq!(perm_desc.detail.as_deref(), Some("Post and read your feed"));

    // Non-permission-set include rejected at PAR with invalid_scope.
    let challenge = client.challenge();
    let par_non_perm = client
        .send_post(
            "/oauth/par",
            &[
                ("response_type", "code"),
                ("code_challenge", &challenge),
                ("code_challenge_method", "S256"),
                ("state", "s-nonperm"),
                ("redirect_uri", redirect),
                ("scope", "atproto include:app.example.other"),
            ],
        )
        .await;
    assert_eq!(par_non_perm.status, 400);
    assert!(par_non_perm.text().contains("invalid_scope"));

    // No scope_resolver configured -> include fails at PAR too.
    let no_resolver_harness =
        TestServer::new_with_scope_resolver(OAuthAccessTokenFormat::Opaque, None).await;
    no_resolver_harness
        .clients
        .register(harness.clients.resolve(client_id).await.unwrap())
        .await;
    let mut no_res_client = TestClient::web(&no_resolver_harness);
    no_res_client.client_id = client_id.into();
    no_res_client.redirect_uri = redirect.into();
    let challenge2 = no_res_client.challenge();
    let par_no_res = no_res_client
        .send_post(
            "/oauth/par",
            &[
                ("response_type", "code"),
                ("code_challenge", &challenge2),
                ("code_challenge_method", "S256"),
                ("state", "s-nores"),
                ("redirect_uri", redirect),
                ("scope", &format!("atproto {include_percent}")),
            ],
        )
        .await;
    assert_eq!(par_no_res.status, 400);
    assert!(par_no_res.text().contains("invalid_scope"));

    let _ = (OAuthHttpRequest::new("GET", "/"),);
}
