#![cfg_attr(target_arch = "wasm32", allow(clippy::arc_with_non_send_sync))]

use std::collections::BTreeMap;
use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::task::{Context, Poll, RawWaker, RawWakerVTable, Waker};
use std::time::Duration;

use bytes::Bytes;
use petrel::identity::{DidDocument, IdentityOptions, IdentityResolver, SigningKey};
use petrel::net::{HttpTransport, SendOptions, SharedTransport, TransportError};
use petrel::rt::{BoxFuture, MaybeSend};
use petrel_core::{Cid, Did, Nsid, RecordKey};
use petrel_lexicon::{
    DefaultLexiconRepoProofVerifier, DefaultLexiconResolver, IdentityLexiconDidResolver,
    IdentityLexiconDnsResolver, LexiconAuthority, LexiconDidResolver, LexiconDnsResolver,
    LexiconHttpRecordFetcher, LexiconIdentityResolution, LexiconRepoProofVerifier,
    LexiconResolutionCache, LexiconResolutionError, LexiconResolver, LexiconSchemaOptions,
    ResolvedLexiconIdentity, VerifiedLexiconRecord,
};
use url::Url;

fn block_on_ready<F: Future>(future: F) -> F::Output {
    fn raw_waker() -> RawWaker {
        fn no_op(_: *const ()) {}
        fn clone(_: *const ()) -> RawWaker {
            raw_waker()
        }
        static VTABLE: RawWakerVTable = RawWakerVTable::new(clone, no_op, no_op, no_op);
        RawWaker::new(std::ptr::null(), &VTABLE)
    }
    let waker = unsafe_free_waker();
    let _ = raw_waker();
    let mut cx = Context::from_waker(&waker);
    let mut pinned = std::pin::pin!(future);
    match Pin::as_mut(&mut pinned).poll(&mut cx) {
        Poll::Ready(out) => out,
        Poll::Pending => panic!("test future unexpectedly returned Poll::Pending"),
    }
}

fn unsafe_free_waker() -> Waker {
    // Use `futures_util::task::noop_waker()` so zero unsafe code exists anywhere.
    futures_util::task::noop_waker()
}

struct MockDns {
    records: BTreeMap<String, Vec<String>>,
    calls: AtomicUsize,
}

impl LexiconDnsResolver for MockDns {
    fn lookup_txt<'a>(
        &'a self,
        domain: &'a str,
    ) -> BoxFuture<'a, Result<Vec<String>, LexiconResolutionError>> {
        Box::pin(async move {
            self.calls.fetch_add(1, Ordering::Relaxed);
            self.records.get(domain).cloned().ok_or_else(|| {
                LexiconResolutionError::AuthorityNotFound {
                    domain: domain.to_owned(),
                }
            })
        })
    }
}

struct MockDid {
    pds: Url,
    signing_key: Option<SigningKey>,
}

impl LexiconDidResolver for MockDid {
    fn resolve_identity<'a>(
        &'a self,
        _did: &'a Did,
        _force_refresh: bool,
    ) -> BoxFuture<'a, Result<ResolvedLexiconIdentity, LexiconResolutionError>> {
        Box::pin(async move {
            Ok(ResolvedLexiconIdentity {
                pds_endpoint: self.pds.clone(),
                signing_key: self.signing_key.clone(),
            })
        })
    }
}

struct MockHttpTransport {
    status: u16,
    body: Vec<u8>,
    last_uri: std::sync::Mutex<Option<String>>,
    calls: AtomicUsize,
}

impl HttpTransport for MockHttpTransport {
    fn send(
        &self,
        request: http::Request<Bytes>,
        _options: &SendOptions,
    ) -> impl Future<Output = Result<http::Response<Bytes>, TransportError>> + MaybeSend {
        let uri = request.uri().to_string();
        if let Ok(mut guard) = self.last_uri.lock() {
            *guard = Some(uri);
        }
        self.calls.fetch_add(1, Ordering::Relaxed);
        let status = self.status;
        let body = self.body.clone();
        async move {
            Ok(http::Response::builder()
                .status(status)
                .body(Bytes::from(body))
                .unwrap())
        }
    }
}

struct MockProofVerifier {
    cbor_payload: Vec<u8>,
    should_fail: bool,
    calls: AtomicUsize,
}

impl LexiconRepoProofVerifier for MockProofVerifier {
    fn verify_record_proof(
        &self,
        car_bytes: &[u8],
        _did: &Did,
        collection: &Nsid,
        rkey: &RecordKey,
        _signing_key: &SigningKey,
    ) -> Result<VerifiedLexiconRecord, LexiconResolutionError> {
        self.calls.fetch_add(1, Ordering::Relaxed);
        assert_eq!(collection.as_str(), "com.atproto.lexicon.schema");
        assert_eq!(rkey.as_str(), "com.example.ping");
        assert_eq!(car_bytes, b"CAR-PROOF-BYTES");
        if self.should_fail {
            return Err(LexiconResolutionError::ProofVerificationFailed {
                message: "invalid MST proof signature".to_owned(),
            });
        }
        Ok(VerifiedLexiconRecord {
            cid: Cid::for_dag_cbor(&self.cbor_payload),
            record_cbor: self.cbor_payload.clone(),
        })
    }
}

fn sample_signing_key() -> SigningKey {
    let doc: DidDocument = serde_json::from_str(
        r#"{
          "id": "did:plc:examplelexicon",
          "verificationMethod": [{
            "id": "did:plc:examplelexicon#atproto",
            "type": "Multikey",
            "controller": "did:plc:examplelexicon",
            "publicKeyMultibase": "zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme"
          }]
        }"#,
    )
    .unwrap();
    doc.signing_key().expect("valid sample DID signing key")
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn lexicon_authority_txt_domain_and_parsing() {
    let nsid = Nsid::parse("app.bsky.feed.post").unwrap();
    assert_eq!(
        LexiconAuthority::txt_domain(&nsid),
        "_lexicon.feed.bsky.app"
    );

    let did = LexiconAuthority::parse_txt_dids(
        "_lexicon.feed.bsky.app",
        &[
            "v=ignore".to_owned(),
            "did=did:plc:z72i7hdynmk6r22z27h6tvur".to_owned(),
            "did=did:plc:z72i7hdynmk6r22z27h6tvur".to_owned(),
        ],
    )
    .expect("duplicate identical DIDs should succeed");
    assert_eq!(did.as_str(), "did:plc:z72i7hdynmk6r22z27h6tvur");

    let ambiguous = LexiconAuthority::parse_txt_dids(
        "_lexicon.example.com",
        &["did=did:plc:alice".to_owned(), "did=did:plc:bob".to_owned()],
    );
    assert!(matches!(
        ambiguous,
        Err(LexiconResolutionError::AmbiguousAuthority { .. })
    ));

    let missing = LexiconAuthority::parse_txt_dids("_lexicon.example.com", &["nope".to_owned()]);
    assert!(matches!(
        missing,
        Err(LexiconResolutionError::AuthorityNotFound { .. })
    ));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn default_resolver_fetches_caches_and_verifies_repo_proof_seam() {
    let record_json = br#"{
      "$type": "com.atproto.lexicon.schema",
      "lexicon": 1,
      "id": "com.example.ping",
      "defs": {"main": {"type": "query"}}
    }"#;
    let record_val = petrel_lexicon::LexValue::from_record_json_bytes(
        record_json,
        petrel_lexicon::ParseOptions::standard(),
    )
    .unwrap();
    let record_cbor = record_val.to_dag_cbor();

    let mut txt = BTreeMap::new();
    txt.insert(
        "_lexicon.example.com".to_owned(),
        vec!["did=did:plc:examplelexicon".to_owned()],
    );
    let dns = Arc::new(MockDns {
        records: txt,
        calls: AtomicUsize::new(0),
    });
    let did_res = Arc::new(MockDid {
        pds: Url::parse("https://pds.example.com").unwrap(),
        signing_key: Some(sample_signing_key()),
    });
    let transport = Arc::new(MockHttpTransport {
        status: 200,
        body: b"CAR-PROOF-BYTES".to_vec(),
        last_uri: std::sync::Mutex::new(None),
        calls: AtomicUsize::new(0),
    });
    let verifier = Arc::new(MockProofVerifier {
        cbor_payload: record_cbor.clone(),
        should_fail: false,
        calls: AtomicUsize::new(0),
    });
    let shared_transport: SharedTransport = transport.clone();
    let fetcher = Arc::new(LexiconHttpRecordFetcher::with_proof_verifier(
        shared_transport,
        verifier.clone(),
    ));
    let resolver = DefaultLexiconResolver::new(
        dns.clone(),
        did_res,
        fetcher,
        LexiconResolutionCache::new(Duration::from_secs(60), 16),
    );

    let first = block_on_ready(resolver.resolve("com.example.ping")).expect("resolve via proof");
    assert_eq!(first.id, "com.example.ping");
    assert_eq!(verifier.calls.load(Ordering::Relaxed), 1);
    assert_eq!(transport.calls.load(Ordering::Relaxed), 1);
    assert!(
        transport
            .last_uri
            .lock()
            .unwrap()
            .as_deref()
            .unwrap()
            .contains("com.atproto.sync.getRecord")
    );

    // Second resolve hits cache (no additional DNS/HTTP/verifier calls)
    let second = block_on_ready(resolver.resolve("com.example.ping")).expect("cached resolve");
    assert_eq!(second, first);
    assert_eq!(dns.calls.load(Ordering::Relaxed), 1);
    assert_eq!(transport.calls.load(Ordering::Relaxed), 1);
    assert_eq!(verifier.calls.load(Ordering::Relaxed), 1);

    // force_refresh bypasses cache
    let refreshed = block_on_ready(resolver.resolve_with_options(
        "com.example.ping",
        true,
        LexiconSchemaOptions::strict(),
    ))
    .expect("forced refresh");
    assert_eq!(refreshed, first);
    assert_eq!(transport.calls.load(Ordering::Relaxed), 2);
    assert_eq!(verifier.calls.load(Ordering::Relaxed), 2);

    // Proof verification failure propagates as ProofVerificationFailed
    let bad_verifier = Arc::new(MockProofVerifier {
        cbor_payload: record_cbor,
        should_fail: true,
        calls: AtomicUsize::new(0),
    });
    let bad_resolver = DefaultLexiconResolver::new(
        dns,
        Arc::new(MockDid {
            pds: Url::parse("https://pds.example.com").unwrap(),
            signing_key: Some(sample_signing_key()),
        }),
        Arc::new(LexiconHttpRecordFetcher::with_proof_verifier(
            transport,
            bad_verifier,
        )),
        LexiconResolutionCache::default(),
    );
    let err = block_on_ready(bad_resolver.resolve("com.example.ping")).unwrap_err();
    assert!(matches!(
        err,
        LexiconResolutionError::ProofVerificationFailed { .. }
    ));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn unverified_http_fetcher_uses_get_record_and_checks_nsid_match() {
    let envelope = br#"{
      "uri": "at://did:plc:examplelexicon/com.atproto.lexicon.schema/com.example.ping",
      "value": {
        "$type": "com.atproto.lexicon.schema",
        "lexicon": 1,
        "id": "com.example.wrong",
        "defs": {"main": {"type": "query"}}
      }
    }"#;
    let transport = Arc::new(MockHttpTransport {
        status: 200,
        body: envelope.to_vec(),
        last_uri: std::sync::Mutex::new(None),
        calls: AtomicUsize::new(0),
    });
    let mut txt = BTreeMap::new();
    txt.insert(
        "_lexicon.example.com".to_owned(),
        vec!["did=did:plc:examplelexicon".to_owned()],
    );
    let resolver = DefaultLexiconResolver::new(
        Arc::new(MockDns {
            records: txt,
            calls: AtomicUsize::new(0),
        }),
        Arc::new(MockDid {
            pds: Url::parse("https://pds.example.com").unwrap(),
            signing_key: None,
        }),
        Arc::new(LexiconHttpRecordFetcher::unverified(transport.clone())),
        LexiconResolutionCache::default(),
    );
    let err = block_on_ready(resolver.resolve("com.example.ping")).unwrap_err();
    assert!(matches!(err, LexiconResolutionError::InvalidRecord { .. }));
    assert!(
        transport
            .last_uri
            .lock()
            .unwrap()
            .as_deref()
            .unwrap()
            .contains("com.atproto.repo.getRecord")
    );
}

struct MockPetrelDns;

#[allow(clippy::manual_async_fn)]
impl petrel::identity::DnsResolver for MockPetrelDns {
    fn txt(
        &self,
        _name: &str,
    ) -> impl Future<Output = Result<Vec<String>, petrel::identity::DnsError>> + MaybeSend {
        async { Ok(vec!["did=did:plc:alice".to_owned()]) }
    }

    #[cfg(not(target_arch = "wasm32"))]
    fn lookup_ip(
        &self,
        _host: &str,
    ) -> impl Future<Output = Result<Vec<std::net::IpAddr>, petrel::identity::DnsError>> + MaybeSend
    {
        async { Ok(vec![]) }
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn identity_adapters_construct_cleanly_on_native_and_wasm() {
    let transport: SharedTransport = Arc::new(MockHttpTransport {
        status: 404,
        body: Vec::new(),
        last_uri: std::sync::Mutex::new(None),
        calls: AtomicUsize::new(0),
    });
    let dns = Arc::new(MockPetrelDns);
    let identity = Arc::new(IdentityResolver::new(
        transport.clone(),
        MockPetrelDns,
        IdentityOptions::default(),
    ));
    let dns_adapter = IdentityLexiconDnsResolver::new(dns.clone());
    let txt = block_on_ready(dns_adapter.lookup_txt("_lexicon.example.com")).unwrap();
    assert_eq!(txt, vec!["did=did:plc:alice".to_owned()]);

    let did_adapter = IdentityLexiconDidResolver::new(identity.clone());
    let _ = did_adapter.inner();
    let _resolver = LexiconIdentityResolution::default_resolver(
        identity.clone(),
        dns.clone(),
        transport.clone(),
        LexiconResolutionCache::default(),
    );
    let _unverified = LexiconIdentityResolution::unverified_resolver(
        identity,
        dns,
        transport,
        LexiconResolutionCache::default(),
    );
}

fn encode_base58_btc(input: &[u8]) -> String {
    const ALPHABET: &[u8; 58] = b"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
    let mut digits = vec![0u8];
    for &byte in input {
        let mut carry = u32::from(byte);
        for d in &mut digits {
            carry += u32::from(*d) * 256;
            *d = u8::try_from(carry % 58).unwrap();
            carry /= 58;
        }
        while carry > 0 {
            digits.push(u8::try_from(carry % 58).unwrap());
            carry /= 58;
        }
    }
    let zeros = input.iter().take_while(|&&b| b == 0).count();
    let mut out = String::with_capacity(zeros + digits.len() + 1);
    out.push('z');
    for _ in 0..zeros {
        out.push('1');
    }
    for &d in digits.iter().rev() {
        out.push(char::from(ALPHABET[usize::from(d)]));
    }
    out
}

fn signing_key_from_multikey(did: &str, prefix: [u8; 2], compressed_sec1: &[u8]) -> SigningKey {
    let mut payload = Vec::with_capacity(2 + compressed_sec1.len());
    payload.extend_from_slice(&prefix);
    payload.extend_from_slice(compressed_sec1);
    let multibase = encode_base58_btc(&payload);
    let doc: DidDocument = serde_json::from_str(&format!(
        r#"{{
          "id": "{did}",
          "verificationMethod": [{{
            "id": "{did}#atproto",
            "type": "Multikey",
            "controller": "{did}",
            "publicKeyMultibase": "{multibase}"
          }}]
        }}"#,
    ))
    .unwrap();
    doc.signing_key().unwrap()
}

fn write_varint(mut val: u64, out: &mut Vec<u8>) {
    loop {
        let mut byte = u8::try_from(val & 0x7f).unwrap();
        val >>= 7;
        if val != 0 {
            byte |= 0x80;
        }
        out.push(byte);
        if val == 0 {
            break;
        }
    }
}

fn encode_car_v1(roots: &[Cid], blocks: &[(Cid, Vec<u8>)]) -> Vec<u8> {
    let mut header_map = BTreeMap::new();
    header_map.insert("version".to_owned(), petrel_core::Value::Integer(1));
    header_map.insert(
        "roots".to_owned(),
        petrel_core::Value::Array(
            roots
                .iter()
                .cloned()
                .map(petrel_core::Value::Link)
                .collect(),
        ),
    );
    let header_bytes = petrel_core::dagcbor::encode(&petrel_core::Value::Object(header_map));

    let mut out = Vec::new();
    write_varint(u64::try_from(header_bytes.len()).unwrap(), &mut out);
    out.extend_from_slice(&header_bytes);
    for (cid, body) in blocks {
        let frame_len = cid.as_bytes().len() + body.len();
        write_varint(u64::try_from(frame_len).unwrap(), &mut out);
        out.extend_from_slice(cid.as_bytes());
        out.extend_from_slice(body);
    }
    out
}

enum TestSigner {
    P256(p256::ecdsa::SigningKey),
    K256(k256::ecdsa::SigningKey),
}

impl TestSigner {
    fn public_signing_key(&self, did: &str) -> SigningKey {
        match self {
            Self::P256(sk) => {
                let sec1 = sk.verifying_key().to_encoded_point(true);
                signing_key_from_multikey(did, [0x80, 0x24], sec1.as_bytes())
            }
            Self::K256(sk) => {
                let sec1 = sk.verifying_key().to_encoded_point(true);
                signing_key_from_multikey(did, [0xe7, 0x01], sec1.as_bytes())
            }
        }
    }

    fn sign_low_s(&self, msg: &[u8]) -> [u8; 64] {
        match self {
            Self::P256(sk) => {
                use p256::ecdsa::{Signature, signature::Signer as _};
                let sig: Signature = sk.sign(msg);
                let normalized = sig.normalize_s().unwrap_or(sig);
                normalized.to_bytes().into()
            }
            Self::K256(sk) => {
                use k256::ecdsa::{Signature, signature::Signer as _};
                let sig: Signature = sk.sign(msg);
                let normalized = sig.normalize_s().unwrap_or(sig);
                normalized.to_bytes().into()
            }
        }
    }
}

struct RepoCommitSigner<'a>(&'a TestSigner);

impl petrel_repo::CommitSigner for RepoCommitSigner<'_> {
    fn algorithm(&self) -> petrel_repo::SigningAlgorithm {
        match self.0 {
            TestSigner::P256(_) => petrel_repo::SigningAlgorithm::P256,
            TestSigner::K256(_) => petrel_repo::SigningAlgorithm::Secp256k1,
        }
    }

    fn sign<'a>(
        &'a self,
        unsigned_commit_bytes: &'a [u8],
    ) -> BoxFuture<'a, Result<Vec<u8>, petrel_repo::CommitError>> {
        let sig = self.0.sign_low_s(unsigned_commit_bytes).to_vec();
        Box::pin(async move { Ok(sig) })
    }
}

fn build_signed_lexicon_proof_car(
    did: &str,
    nsid: &str,
    record_json: &[u8],
    signer: &TestSigner,
    force_high_s: bool,
) -> (Vec<u8>, Vec<u8>) {
    let record_val = petrel_lexicon::LexValue::from_record_json_bytes(
        record_json,
        petrel_lexicon::ParseOptions::standard(),
    )
    .unwrap();
    let record_cbor = record_val.to_dag_cbor();
    let repo_did = Did::parse(did).unwrap();
    let commit_signer = RepoCommitSigner(signer);

    let bundle = block_on_ready(async {
        let repo = petrel_repo::Repository::create(repo_did, &commit_signer)
            .await
            .unwrap();
        let batch = petrel_repo::WriteBatch::new(vec![
            petrel_repo::WriteOp::Create {
                path: petrel_repo::RepositoryPath::new("com.atproto.lexicon.schema", nsid).unwrap(),
                record_cbor: record_cbor.clone(),
            },
            petrel_repo::WriteOp::Create {
                path: petrel_repo::RepositoryPath::new(
                    "com.atproto.lexicon.schema",
                    "com.example.sibling",
                )
                .unwrap(),
                record_cbor: record_cbor.clone(),
            },
        ])
        .unwrap();
        let committed = repo.commit_writes(batch, &commit_signer).await.unwrap();
        committed
            .repository
            .record_proof("com.atproto.lexicon.schema", nsid)
            .await
            .unwrap()
    });

    if force_high_s {
        let mut blocks = bundle.blocks;
        let petrel_core::Value::Object(mut commit_map) =
            petrel_lexicon::LexValue::from_record_dag_cbor(
                &blocks[0].bytes,
                petrel_lexicon::ParseOptions::standard(),
            )
            .unwrap()
            .into_value()
        else {
            panic!("commit must decode to object");
        };
        commit_map.remove("sig");
        let unsigned =
            petrel_core::dagcbor::encode(&petrel_core::Value::Object(commit_map.clone()));
        let low_s = signer.sign_low_s(&unsigned);
        let parsed = p256::ecdsa::Signature::from_slice(&low_s).unwrap();
        let high_s_scalar: p256::Scalar = -*parsed.s();
        let mut sig = [0u8; 64];
        sig[..32].copy_from_slice(&low_s[..32]);
        sig[32..64].copy_from_slice(&high_s_scalar.to_bytes());
        commit_map.insert("sig".to_owned(), petrel_core::Value::Bytes(sig.to_vec()));
        let new_commit_bytes =
            petrel_core::dagcbor::encode(&petrel_core::Value::Object(commit_map));
        let new_commit_cid = Cid::for_dag_cbor(&new_commit_bytes);
        blocks[0] = petrel_repo::RepositoryBlock::new(new_commit_cid.clone(), new_commit_bytes);
        let car = petrel_repo::PublicRepositoryCAR::write(&[new_commit_cid], &blocks).unwrap();
        return (car, record_cbor);
    }

    (bundle.car().unwrap(), record_cbor)
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn default_proof_verifier_validates_real_atproto_car_fixtures() {
    let diddoc_raw = include_str!("../../../Tests/PetrelRepoTests/Vectors/real-repo/diddoc.json");
    let diddoc: DidDocument = serde_json::from_str(diddoc_raw).unwrap();
    let did = Did::parse(diddoc.id.as_str()).unwrap();
    let signing_key = diddoc.signing_key().expect("atproto signing key");
    let verifier = DefaultLexiconRepoProofVerifier::default();

    let present_car =
        include_bytes!("../../../Tests/PetrelRepoTests/Vectors/real-repo/record-proof-present.car");
    let collection = Nsid::parse("app.bsky.actor.profile").unwrap();
    let present_rkey = RecordKey::parse("self").unwrap();
    let proven_record = verifier
        .verify_record_proof(present_car, &did, &collection, &present_rkey, &signing_key)
        .expect("real repo inclusion proof CAR should verify");
    assert_eq!(
        proven_record.cid,
        Cid::for_dag_cbor(&proven_record.record_cbor)
    );

    // Absent proof fixture must fail closed
    let absent_car =
        include_bytes!("../../../Tests/PetrelRepoTests/Vectors/real-repo/record-proof-absent.car");
    let absent_rkey = RecordKey::parse("doesnotexist").unwrap();
    let absent_err = verifier
        .verify_record_proof(absent_car, &did, &collection, &absent_rkey, &signing_key)
        .unwrap_err();
    assert!(matches!(
        absent_err,
        LexiconResolutionError::ProofVerificationFailed { .. }
    ));

    // Wrong DID must fail closed even on an otherwise valid real signed CAR
    let other_did = Did::parse("did:plc:z72i7hdynmk6r22z27h6tvur").unwrap();
    let wrong_did_err = verifier
        .verify_record_proof(
            present_car,
            &other_did,
            &collection,
            &present_rkey,
            &signing_key,
        )
        .unwrap_err();
    assert!(matches!(
        wrong_did_err,
        LexiconResolutionError::ProofVerificationFailed { .. }
    ));
}

struct RotatingDid {
    pds: Url,
    stale: SigningKey,
    fresh: SigningKey,
}

impl LexiconDidResolver for RotatingDid {
    fn resolve_identity<'a>(
        &'a self,
        _did: &'a Did,
        force_refresh: bool,
    ) -> BoxFuture<'a, Result<ResolvedLexiconIdentity, LexiconResolutionError>> {
        Box::pin(async move {
            Ok(ResolvedLexiconIdentity {
                pds_endpoint: self.pds.clone(),
                signing_key: Some(if force_refresh {
                    self.fresh.clone()
                } else {
                    self.stale.clone()
                }),
            })
        })
    }
}

fn take_varint_len(c: &mut &[u8]) -> usize {
    let mut v = 0usize;
    for (i, &b) in c.iter().enumerate() {
        v |= usize::from(b & 0x7f) << (i * 7);
        if b < 0x80 {
            *c = &c[i + 1..];
            return v;
        }
    }
    0
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn default_http_fetcher_verifies_p256_secp256k1_and_rotates_keys() {
    let did_str = "did:plc:examplelexicon";
    let nsid_str = "com.example.ping";
    let record_json = br#"{
      "$type": "com.atproto.lexicon.schema",
      "lexicon": 1,
      "id": "com.example.ping",
      "defs": {"main": {"type": "query"}}
    }"#;

    let mut txt = BTreeMap::new();
    txt.insert(
        "_lexicon.example.com".to_owned(),
        vec![format!("did={did_str}")],
    );

    // Both P-256 and secp256k1 signed CARs resolve through LexiconHttpRecordFetcher::new (default verified)
    let p256_signer =
        TestSigner::P256(p256::ecdsa::SigningKey::from_bytes(&[7u8; 32].into()).unwrap());
    let k256_signer =
        TestSigner::K256(k256::ecdsa::SigningKey::from_bytes(&[9u8; 32].into()).unwrap());
    for signer in [&p256_signer, &k256_signer] {
        let (car, _) =
            build_signed_lexicon_proof_car(did_str, nsid_str, record_json, signer, false);
        let transport = Arc::new(MockHttpTransport {
            status: 200,
            body: car,
            last_uri: std::sync::Mutex::new(None),
            calls: AtomicUsize::new(0),
        });
        let resolver = DefaultLexiconResolver::new(
            Arc::new(MockDns {
                records: txt.clone(),
                calls: AtomicUsize::new(0),
            }),
            Arc::new(MockDid {
                pds: Url::parse("https://pds.example.com").unwrap(),
                signing_key: Some(signer.public_signing_key(did_str)),
            }),
            Arc::new(LexiconHttpRecordFetcher::new(transport.clone())),
            LexiconResolutionCache::default(),
        );
        let doc = block_on_ready(resolver.resolve(nsid_str)).expect("default verified resolve");
        assert_eq!(doc.id, nsid_str);
        assert!(
            transport
                .last_uri
                .lock()
                .unwrap()
                .as_deref()
                .unwrap()
                .contains("com.atproto.sync.getRecord")
        );
    }

    // Key rotation retry: initial stale cached key fails, forced refresh returns new key and succeeds
    let (rotated_car, _) =
        build_signed_lexicon_proof_car(did_str, nsid_str, record_json, &k256_signer, false);
    let rot_transport = Arc::new(MockHttpTransport {
        status: 200,
        body: rotated_car,
        last_uri: std::sync::Mutex::new(None),
        calls: AtomicUsize::new(0),
    });
    let rot_resolver = DefaultLexiconResolver::new(
        Arc::new(MockDns {
            records: txt.clone(),
            calls: AtomicUsize::new(0),
        }),
        Arc::new(RotatingDid {
            pds: Url::parse("https://pds.example.com").unwrap(),
            stale: p256_signer.public_signing_key(did_str),
            fresh: k256_signer.public_signing_key(did_str),
        }),
        Arc::new(LexiconHttpRecordFetcher::new(rot_transport.clone())),
        LexiconResolutionCache::default(),
    );
    assert_eq!(
        block_on_ready(rot_resolver.resolve(nsid_str)).unwrap().id,
        nsid_str
    );
    assert_eq!(rot_transport.calls.load(Ordering::Relaxed), 2);

    // Missing signing key in DID document fails closed with default fetcher
    let (p256_car, _) =
        build_signed_lexicon_proof_car(did_str, nsid_str, record_json, &p256_signer, false);
    let no_key_resolver = DefaultLexiconResolver::new(
        Arc::new(MockDns {
            records: txt,
            calls: AtomicUsize::new(0),
        }),
        Arc::new(MockDid {
            pds: Url::parse("https://pds.example.com").unwrap(),
            signing_key: None,
        }),
        Arc::new(LexiconHttpRecordFetcher::new(Arc::new(MockHttpTransport {
            status: 200,
            body: p256_car,
            last_uri: std::sync::Mutex::new(None),
            calls: AtomicUsize::new(0),
        }))),
        LexiconResolutionCache::default(),
    );
    assert!(matches!(
        block_on_ready(no_key_resolver.resolve(nsid_str)),
        Err(LexiconResolutionError::ProofVerificationFailed { .. })
    ));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
fn default_proof_verifier_rejects_tampering_high_s_missing_blocks_and_extra_roots() {
    let did_str = "did:plc:examplelexicon";
    let did = Did::parse(did_str).unwrap();
    let nsid_str = "com.example.ping";
    let collection = Nsid::parse("com.atproto.lexicon.schema").unwrap();
    let rkey = RecordKey::parse(nsid_str).unwrap();
    let record_json = br#"{
      "$type": "com.atproto.lexicon.schema",
      "lexicon": 1,
      "id": "com.example.ping",
      "defs": {"main": {"type": "query"}}
    }"#;

    let p256_signer =
        TestSigner::P256(p256::ecdsa::SigningKey::from_bytes(&[7u8; 32].into()).unwrap());
    let k256_signer =
        TestSigner::K256(k256::ecdsa::SigningKey::from_bytes(&[9u8; 32].into()).unwrap());
    let (p256_car, _) =
        build_signed_lexicon_proof_car(did_str, nsid_str, record_json, &p256_signer, false);

    let verifier = DefaultLexiconRepoProofVerifier::default();
    let p256_pub = p256_signer.public_signing_key(did_str);
    let k256_pub = k256_signer.public_signing_key(did_str);

    // Wrong key
    assert!(matches!(
        verifier.verify_record_proof(&p256_car, &did, &collection, &rkey, &k256_pub),
        Err(LexiconResolutionError::ProofVerificationFailed { .. })
    ));

    // High-S signature on valid P-256 unsigned commit: s' = n - s
    let (high_s_car, _) =
        build_signed_lexicon_proof_car(did_str, nsid_str, record_json, &p256_signer, true);
    assert!(matches!(
        verifier.verify_record_proof(&high_s_car, &did, &collection, &rkey, &p256_pub),
        Err(LexiconResolutionError::ProofVerificationFailed { .. })
    ));

    // Two roots in CAR header rejected
    let extra_root_car = encode_car_v1(&[Cid::for_dag_cbor(b"a"), Cid::for_dag_cbor(b"b")], &[]);
    assert!(matches!(
        verifier.verify_record_proof(&extra_root_car, &did, &collection, &rkey, &p256_pub),
        Err(LexiconResolutionError::ProofVerificationFailed { .. })
    ));

    // Missing MST node block (truncated CAR keeping only commit block) rejected
    let commit_only_car = {
        let mut cursor = p256_car.as_slice();
        let hlen = take_varint_len(&mut cursor);
        let h_end = p256_car.len() - cursor.len() + hlen;
        let mut after_h = &p256_car[h_end..];
        let flen = take_varint_len(&mut after_h);
        let f_end = p256_car.len() - after_h.len() + flen;
        p256_car[..f_end].to_vec()
    };
    assert!(matches!(
        verifier.verify_record_proof(&commit_only_car, &did, &collection, &rkey, &p256_pub),
        Err(LexiconResolutionError::ProofVerificationFailed { .. })
    ));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), test)]
#[allow(clippy::too_many_lines)]
fn default_proof_verifier_enforces_mst_entry_node_and_zero_bounds() {
    let did_str = "did:plc:examplelexicon";
    let did = Did::parse(did_str).unwrap();
    let collection = Nsid::parse("com.atproto.lexicon.schema").unwrap();
    let p256_signer =
        TestSigner::P256(p256::ecdsa::SigningKey::from_bytes(&[7u8; 32].into()).unwrap());
    let p256_pub = p256_signer.public_signing_key(did_str);
    let commit_signer = RepoCommitSigner(&p256_signer);

    let make_record_cbor = |id: &str| {
        let json = serde_json::json!({
            "$type": "com.atproto.lexicon.schema",
            "lexicon": 1,
            "id": id,
            "defs": { "main": { "type": "query" } }
        });
        petrel_lexicon::LexValue::from_record_json_bytes(
            &serde_json::to_vec(&json).unwrap(),
            petrel_lexicon::ParseOptions::standard(),
        )
        .unwrap()
        .to_dag_cbor()
    };

    // Deterministically pick 3 layer-0 keys (all in the root MST node) and 1 layer-1 key (exact depth 1 -> 2 MST nodes).
    let mut layer0_keys = Vec::new();
    let mut higher_key: Option<String> = None;
    for idx in 0..256 {
        let candidate = format!("com.example.k{idx}");
        let depth = petrel_repo::mst::key_depth(
            format!("com.atproto.lexicon.schema/{candidate}").as_bytes(),
        );
        if depth == 0 && layer0_keys.len() < 3 {
            layer0_keys.push(candidate);
        } else if depth == 1 && higher_key.is_none() {
            higher_key = Some(candidate);
        }
        if layer0_keys.len() == 3 && higher_key.is_some() {
            break;
        }
    }
    let target_rkey = layer0_keys[0].clone();

    // 1) Single-node proof containing 3 layer-0 entries -> `node_entries == 3`.
    let (single_node_car, node_entries) = block_on_ready(async {
        let repo = petrel_repo::Repository::create(did.clone(), &commit_signer)
            .await
            .unwrap();
        let writes: Vec<petrel_repo::WriteOp> = layer0_keys
            .iter()
            .map(|k| petrel_repo::WriteOp::Create {
                path: petrel_repo::RepositoryPath::new("com.atproto.lexicon.schema", k).unwrap(),
                record_cbor: make_record_cbor(k),
            })
            .collect();
        let committed = repo
            .commit_writes(
                petrel_repo::WriteBatch::new(writes).unwrap(),
                &commit_signer,
            )
            .await
            .unwrap();
        let bundle = committed
            .repository
            .record_proof("com.atproto.lexicon.schema", &target_rkey)
            .await
            .unwrap();
        let root_cid = committed.commit.data_cid;
        let root_bytes = bundle
            .blocks
            .iter()
            .find(|b| b.cid == root_cid)
            .expect("root MST block in proof")
            .bytes
            .clone();
        let view = petrel_repo::mst::decode_mst_node(
            &root_bytes,
            petrel_repo::mst::MstKeySyntax::StrictAtProto,
            &petrel_repo::RepositoryReadPolicy::strict(),
            true,
        )
        .unwrap();
        assert_eq!(view.entries.len(), 3);
        (bundle.car().unwrap(), view.entries.len())
    });

    let rkey = RecordKey::parse(&target_rkey).unwrap();
    assert!(
        DefaultLexiconRepoProofVerifier::new()
            .with_max_mst_entries_per_node(node_entries)
            .verify_record_proof(&single_node_car, &did, &collection, &rkey, &p256_pub)
            .is_ok()
    );
    assert!(matches!(
        DefaultLexiconRepoProofVerifier::new()
            .with_max_mst_entries_per_node(node_entries - 1)
            .verify_record_proof(&single_node_car, &did, &collection, &rkey, &p256_pub),
        Err(LexiconResolutionError::ProofVerificationFailed { .. })
    ));

    // 2) Multi-node proof (layer>=1 root -> layer-0 child) enforces `with_max_mst_nodes(1)` rejection.
    let multi_keys = [target_rkey.clone(), higher_key.expect("higher-layer key")];
    let multi_node_car = block_on_ready(async {
        let repo = petrel_repo::Repository::create(did.clone(), &commit_signer)
            .await
            .unwrap();
        let writes: Vec<petrel_repo::WriteOp> = multi_keys
            .iter()
            .map(|k| petrel_repo::WriteOp::Create {
                path: petrel_repo::RepositoryPath::new("com.atproto.lexicon.schema", k).unwrap(),
                record_cbor: make_record_cbor(k),
            })
            .collect();
        let committed = repo
            .commit_writes(
                petrel_repo::WriteBatch::new(writes).unwrap(),
                &commit_signer,
            )
            .await
            .unwrap();
        committed
            .repository
            .record_proof("com.atproto.lexicon.schema", &target_rkey)
            .await
            .unwrap()
            .car()
            .unwrap()
    });
    assert!(
        DefaultLexiconRepoProofVerifier::new()
            .with_max_mst_nodes(2)
            .verify_record_proof(&multi_node_car, &did, &collection, &rkey, &p256_pub)
            .is_ok()
    );
    assert!(matches!(
        DefaultLexiconRepoProofVerifier::new()
            .with_max_mst_nodes(1)
            .verify_record_proof(&multi_node_car, &did, &collection, &rkey, &p256_pub),
        Err(LexiconResolutionError::ProofVerificationFailed { .. })
    ));

    // 3) Zero limits fail closed instead of silently clamping up to 1.
    for zero_verifier in [
        DefaultLexiconRepoProofVerifier::new().with_max_car_bytes(0),
        DefaultLexiconRepoProofVerifier::new().with_max_blocks(0),
        DefaultLexiconRepoProofVerifier::new().with_max_block_bytes(0),
        DefaultLexiconRepoProofVerifier::new().with_max_mst_nodes(0),
    ] {
        assert!(matches!(
            zero_verifier.verify_record_proof(
                &single_node_car,
                &did,
                &collection,
                &rkey,
                &p256_pub
            ),
            Err(LexiconResolutionError::ProofVerificationFailed { .. })
        ));
    }
}
