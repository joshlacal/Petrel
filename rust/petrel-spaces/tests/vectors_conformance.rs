#![cfg(test)]

#[cfg(target_arch = "wasm32")]
wasm_bindgen_test::wasm_bindgen_test_configure!(run_in_browser);

use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll, Waker};

use base64::Engine as _;
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use petrel_core::{AtUri, Cid, Did, SpaceRef, Tid, Value, dagcbor, syntax::Grammar};
use petrel_crypto::{ATProtoJWTVerificationKey, Hex, PublicKey, SpaceSetHash};
use petrel_spaces::{
    DEFAULT_MAX_ARCHIVE_BYTES, InMemorySignatureReplayCache, MacProfile, SpaceBlobLocator,
    SpaceError, StaticDidResolver, check_presentation_replay, decapsulate_p256,
    encapsulate_p256_with_ephemeral, format_accept_signature, parse_space_ref, read_star_repo,
    replay_window_end, sign_commit_mac, sign_record_mac, verify_commit_mac,
    verify_credential_token, verify_delegation_token, verify_http_signature_against_key,
    verify_record_mac, write_star_repo,
};
use serde::Deserialize;

fn block_on<F: Future>(fut: F) -> F::Output {
    let waker = Waker::noop().clone();
    let mut cx = Context::from_waker(&waker);
    let mut pinned = Box::pin(fut);
    match Pin::as_mut(&mut pinned).poll(&mut cx) {
        Poll::Ready(val) => val,
        Poll::Pending => panic!("unexpected Pending in synchronous mock test future"),
    }
}

const V1_JSON: &str = include_str!("vectors/atproto_spaces_v1.json");
const SIG_V1_JSON: &str = include_str!("vectors/space_credential_signature_v1.json");
const REPLAY_V1_JSON: &str = include_str!("vectors/space_credential_replay_v1.json");

#[derive(Deserialize)]
struct V1Vectors {
    lthash: V1LtHash,
    kem_p256: V1KemP256,
    commit_mac: V1CommitMac,
    record_mac: V1RecordMac,
    rfc9421_low_s: V1Rfc9421,
    rfc9421_high_s: V1Rfc9421,
    delegation_jwt_did_plc: V1DelegationJwt,
    credential_jwt_did_web: V1CredentialJwt,
    star_repo: V1StarRepo,
}

#[derive(Deserialize)]
struct V1LtHash {
    record_a: V1LtRecord,
    record_b: V1LtRecord,
    empty_commitment_hex: String,
    only_a_commitment_hex: String,
    only_b_commitment_hex: String,
    combined_ab_commitment_hex: String,
    after_remove_a_commitment_hex: String,
}

#[derive(Deserialize)]
struct V1LtRecord {
    path: String,
    dagcbor_hex: String,
    cid: String,
}

#[derive(Deserialize)]
struct V1KemP256 {
    author_secret_hex: String,
    author_kem_did_key: String,
    ephemeral_secret_hex: String,
    key_share_did_key: String,
    shared_secret_hex: String,
    want_commit_mac_header: String,
    want_record_mac_header: String,
}

#[derive(Deserialize)]
struct V1CommitMac {
    shared_secret_hex: String,
    space: String,
    repo: String,
    rev: String,
    data_hex: String,
    mac_hex: String,
    covered_header: String,
    signature_input: String,
    signature: String,
}

#[derive(Deserialize)]
struct V1RecordMac {
    shared_secret_hex: String,
    record_uri: String,
    cid: String,
    mac_hex: String,
    covered_header: String,
    signature_input: String,
    signature: String,
}

#[derive(Deserialize)]
struct V1Rfc9421 {
    cnf_did_key: String,
    credential_jwt: String,
    audience_did: String,
    created: i64,
    nonce: String,
    authorization: String,
    atproto_space_audience: String,
    signature_input: String,
    signature: String,
}

#[derive(Deserialize)]
struct V1DelegationJwt {
    signer_did_key: String,
    iss: String,
    sub: String,
    aud: String,
    verify_now_sec: i64,
    jwt: String,
}

#[derive(Deserialize)]
struct V1CredentialJwt {
    authority_did_key: String,
    iss: String,
    sub: String,
    cnf_kid: String,
    verify_now_sec: i64,
    jwt: String,
}

#[derive(Deserialize)]
struct V1StarRepo {
    empty_swan_space: String,
    empty_swan_repo: String,
    empty_swan_rev: String,
    empty_swan_archive_hex: String,
    populated_space: String,
    populated_repo: String,
    populated_rev: String,
    populated_data_hex: String,
    populated_archive_hex: String,
}

#[derive(Deserialize)]
struct SigVectors {
    cnf_did_key: String,
    authorization: String,
    atproto_space_audience: String,
    max_signature_age_secs: i64,
    max_clock_skew_secs: i64,
    max_nonce_bytes: usize,
    cases: Vec<SigCase>,
}

#[derive(Deserialize)]
struct SigCase {
    name: String,
    signature_input: Vec<String>,
    signature: Vec<String>,
    now_sec: i64,
    expect: String,
}

#[derive(Deserialize)]
struct ReplayVectors {
    max_signature_age_secs: i64,
    max_clock_skew_secs: i64,
    credential_expiry_skew_secs: i64,
    steps: Vec<ReplayStep>,
}

#[derive(Deserialize)]
struct ReplayStep {
    issuer: String,
    nonce: Option<String>,
    created: Option<i64>,
    expires: Option<i64>,
    credential_exp: i64,
    now_sec: i64,
    expect: String,
}

fn hex_bytes(s: &str) -> Vec<u8> {
    Hex::decode(s).expect("valid hex fixture")
}

fn hex32(s: &str) -> [u8; 32] {
    hex_bytes(s).try_into().expect("32-byte hex")
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn v1_lthash_vectors_match() {
    let v: V1Vectors = serde_json::from_str(V1_JSON).unwrap();

    let empty = SpaceSetHash::new();
    assert_eq!(Hex::encode(&empty.digest()), v.lthash.empty_commitment_hex);

    let a_cbor = hex_bytes(&v.lthash.record_a.dagcbor_hex);
    assert_eq!(
        Cid::for_dag_cbor(&a_cbor).to_string(),
        v.lthash.record_a.cid
    );

    let b_cbor = hex_bytes(&v.lthash.record_b.dagcbor_hex);
    assert_eq!(
        Cid::for_dag_cbor(&b_cbor).to_string(),
        v.lthash.record_b.cid
    );

    let mut only_a = SpaceSetHash::new();
    only_a.add(&v.lthash.record_a.path, &v.lthash.record_a.cid);
    assert_eq!(
        Hex::encode(&only_a.digest()),
        v.lthash.only_a_commitment_hex
    );

    let mut only_b = SpaceSetHash::new();
    only_b.add(&v.lthash.record_b.path, &v.lthash.record_b.cid);
    assert_eq!(
        Hex::encode(&only_b.digest()),
        v.lthash.only_b_commitment_hex
    );

    only_a.add(&v.lthash.record_b.path, &v.lthash.record_b.cid);
    assert_eq!(
        Hex::encode(&only_a.digest()),
        v.lthash.combined_ab_commitment_hex
    );

    only_a.remove(&v.lthash.record_a.path, &v.lthash.record_a.cid);
    assert_eq!(
        Hex::encode(&only_a.digest()),
        v.lthash.after_remove_a_commitment_hex
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn v1_kem_and_mac_vectors_match_nov24_at_space() {
    let v: V1Vectors = serde_json::from_str(V1_JSON).unwrap();

    let ephem = hex32(&v.kem_p256.ephemeral_secret_hex);
    let encap = encapsulate_p256_with_ephemeral(&v.kem_p256.author_kem_did_key, &ephem).unwrap();
    assert_eq!(encap.key_share, v.kem_p256.key_share_did_key);
    assert_eq!(
        Hex::encode(&*encap.shared_secret),
        v.kem_p256.shared_secret_hex
    );

    let author_secret = hex32(&v.kem_p256.author_secret_hex);
    let decap = decapsulate_p256(&author_secret, &v.kem_p256.key_share_did_key).unwrap();
    assert_eq!(Hex::encode(&*decap), v.kem_p256.shared_secret_hex);

    assert_eq!(
        format_accept_signature(MacProfile::Commit, &v.kem_p256.key_share_did_key).unwrap(),
        v.kem_p256.want_commit_mac_header
    );
    assert_eq!(
        format_accept_signature(MacProfile::Record, &v.kem_p256.key_share_did_key).unwrap(),
        v.kem_p256.want_record_mac_header
    );

    // Commit MAC (Nov 24 at:space/)
    assert!(v.commit_mac.space.starts_with("at:space/"));
    let cm_secret = hex32(&v.commit_mac.shared_secret_hex);
    let cm_space = parse_space_ref(&v.commit_mac.space).unwrap();
    let cm_repo = Did::parse(&v.commit_mac.repo).unwrap();
    let cm_rev = Tid::parse(&v.commit_mac.rev).unwrap();
    let cm_data = hex32(&v.commit_mac.data_hex);
    let signed_cm = sign_commit_mac(
        &cm_secret,
        &cm_space,
        &cm_repo,
        &cm_rev,
        &cm_data,
        &v.kem_p256.key_share_did_key,
    )
    .unwrap();
    assert_eq!(Hex::encode(&signed_cm.mac), v.commit_mac.mac_hex);
    assert_eq!(signed_cm.covered_signature, v.commit_mac.covered_header);
    assert_eq!(signed_cm.signature_input, v.commit_mac.signature_input);
    assert_eq!(signed_cm.signature, v.commit_mac.signature);
    let verified_cm = verify_commit_mac(
        &cm_secret,
        &v.commit_mac.covered_header,
        &v.commit_mac.signature_input,
        &v.commit_mac.signature,
    )
    .unwrap();
    assert_eq!(verified_cm.space, cm_space);
    assert_eq!(verified_cm.repo, cm_repo);
    assert_eq!(verified_cm.rev, cm_rev);
    assert_eq!(verified_cm.data, cm_data);

    // Record MAC (Nov 24 at:space/ 6-part record URI)
    assert!(v.record_mac.record_uri.starts_with("at:space/"));
    let rm_secret = hex32(&v.record_mac.shared_secret_hex);
    let rm_uri =
        AtUri::parse_with_grammar(&v.record_mac.record_uri, Grammar::RestrictedOrSpace).unwrap();
    let rm_cid = Cid::parse(&v.record_mac.cid).unwrap();
    let record_mac_hdrs =
        sign_record_mac(&rm_secret, &rm_uri, &rm_cid, &v.kem_p256.key_share_did_key).unwrap();
    assert_eq!(Hex::encode(&record_mac_hdrs.mac), v.record_mac.mac_hex);
    assert_eq!(
        record_mac_hdrs.covered_signature,
        v.record_mac.covered_header
    );
    assert_eq!(
        record_mac_hdrs.signature_input,
        v.record_mac.signature_input
    );
    assert_eq!(record_mac_hdrs.signature, v.record_mac.signature);
    let record_mac_verified = verify_record_mac(
        &rm_secret,
        &v.record_mac.covered_header,
        &v.record_mac.signature_input,
        &v.record_mac.signature,
    )
    .unwrap();
    assert_eq!(record_mac_verified.uri.as_str(), rm_uri.as_str());
    assert_eq!(record_mac_verified.cid, rm_cid);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn v1_jwts_and_rfc9421_low_and_high_s_vectors_match() {
    let v: V1Vectors = serde_json::from_str(V1_JSON).unwrap();

    // Delegation JWT (Nov 24 at:space/ sub)
    let del_iss = Did::parse(&v.delegation_jwt_did_plc.iss).unwrap();
    let del_pk = PublicKey::from_did_key(&v.delegation_jwt_did_plc.signer_did_key).unwrap();
    let mut resolver = StaticDidResolver::new();
    resolver.insert_signing_key(
        del_iss,
        "#atproto",
        &ATProtoJWTVerificationKey::from_public_key(&del_pk),
    );
    let del_claims = block_on(verify_delegation_token(
        &v.delegation_jwt_did_plc.jwt,
        &v.delegation_jwt_did_plc.aud,
        v.delegation_jwt_did_plc.verify_now_sec,
        &resolver,
    ))
    .unwrap();
    assert_eq!(del_claims.sub, v.delegation_jwt_did_plc.sub);
    assert!(del_claims.sub.starts_with("at:space/"));

    // Credential JWT (Nov 24 at:space/ sub)
    let cred_iss = Did::parse(&v.credential_jwt_did_web.iss).unwrap();
    let cred_pk = PublicKey::from_did_key(&v.credential_jwt_did_web.authority_did_key).unwrap();
    resolver.insert_signing_key(
        cred_iss,
        "#atproto",
        &ATProtoJWTVerificationKey::from_public_key(&cred_pk),
    );
    let cred_claims = block_on(verify_credential_token(
        &v.credential_jwt_did_web.jwt,
        v.credential_jwt_did_web.verify_now_sec,
        &resolver,
    ))
    .unwrap();
    assert_eq!(cred_claims.sub, v.credential_jwt_did_web.sub);
    assert_eq!(cred_claims.cnf.kid, v.credential_jwt_did_web.cnf_kid);

    // RFC 9421 Low-S and High-S
    for (name, vec) in [("low_s", &v.rfc9421_low_s), ("high_s", &v.rfc9421_high_s)] {
        let verified = verify_http_signature_against_key(
            &vec.authorization,
            &vec.atproto_space_audience,
            &vec.signature_input,
            &vec.signature,
            &vec.audience_did,
            &vec.cnf_did_key,
            vec.created,
            300,
            60,
            512,
        )
        .unwrap_or_else(|e| panic!("failed RFC 9421 vector {name}: {e}"));
        assert_eq!(verified.credential_jwt, vec.credential_jwt);
        assert_eq!(verified.nonce.as_deref(), Some(vec.nonce.as_str()));
        assert_eq!(verified.created, Some(vec.created));
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn v1_star_repo_vectors_match() {
    let v: V1Vectors = serde_json::from_str(V1_JSON).unwrap();

    // Empty STAR
    let empty_bytes = hex_bytes(&v.star_repo.empty_swan_archive_hex);
    let empty_repo = read_star_repo(&empty_bytes, DEFAULT_MAX_ARCHIVE_BYTES).unwrap();
    assert_eq!(
        empty_repo.metadata.space.as_str(),
        v.star_repo.empty_swan_space
    );
    assert_eq!(
        empty_repo.metadata.repo.as_str(),
        v.star_repo.empty_swan_repo
    );
    assert_eq!(empty_repo.metadata.rev.as_str(), v.star_repo.empty_swan_rev);
    assert_eq!(empty_repo.records.len(), 0);

    let reencoded_empty = write_star_repo(
        &empty_repo.metadata.space,
        &empty_repo.metadata.repo,
        &empty_repo.metadata.rev,
        &[],
    )
    .unwrap();
    assert_eq!(
        Hex::encode(&reencoded_empty),
        v.star_repo.empty_swan_archive_hex
    );

    // Populated STAR
    let pop_bytes = hex_bytes(&v.star_repo.populated_archive_hex);
    let pop_repo = read_star_repo(&pop_bytes, DEFAULT_MAX_ARCHIVE_BYTES).unwrap();
    assert_eq!(
        pop_repo.metadata.space.as_str(),
        v.star_repo.populated_space
    );
    assert_eq!(pop_repo.metadata.repo.as_str(), v.star_repo.populated_repo);
    assert_eq!(pop_repo.metadata.rev.as_str(), v.star_repo.populated_rev);
    assert_eq!(
        Hex::encode(&pop_repo.metadata.data),
        v.star_repo.populated_data_hex
    );
    assert_eq!(pop_repo.records.len(), 2);

    let refs: Vec<(&str, &Value)> = pop_repo
        .records
        .iter()
        .map(|r| (r.path.as_str(), &r.value))
        .collect();
    let reencoded_pop = write_star_repo(
        &pop_repo.metadata.space,
        &pop_repo.metadata.repo,
        &pop_repo.metadata.rev,
        &refs,
    )
    .unwrap();
    assert_eq!(
        Hex::encode(&reencoded_pop),
        v.star_repo.populated_archive_hex
    );
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn star_v02_cid_link_decodes_when_upgraded_to_nov24_space_uri() {
    // Same record CBOR with link (tag 42), rewritten to Nov 24 at:space/
    let space = SpaceRef::parse("at:space/did:example:space/app.bsky.group/test").unwrap();
    let repo = Did::parse("did:example:alice").unwrap();
    let rev = Tid::parse("3kbcq3p7ad422").unwrap();
    let link_cid =
        Cid::parse("bafyreidpnhlqcmg7f3bbn6zd7kr2p3x3ciaqgpy7333hlp3gc4vluyuzvm").unwrap();
    let mut map = std::collections::BTreeMap::new();
    map.insert("ref".to_owned(), Value::Link(link_cid.clone()));
    map.insert("text".to_owned(), Value::String("hello".to_owned()));
    map.insert("count".to_owned(), Value::Integer(1));
    let val = Value::Object(map);
    let archive =
        write_star_repo(&space, &repo, &rev, &[("app.bsky.feed.post/self", &val)]).unwrap();
    let decoded = read_star_repo(&archive, DEFAULT_MAX_ARCHIVE_BYTES).unwrap();
    assert_eq!(decoded.records.len(), 1);
    assert_eq!(
        decoded.records[0].cid,
        Cid::for_dag_cbor(&dagcbor::encode(&val))
    );
    assert_eq!(decoded.records[0].value, val);

    // Ensure raw tag 42 link round-trips intact and old base64 v02 (with at://) is rejected!
    let legacy_v02 = BASE64_STANDARD
        .decode("KmwBAKcBpmNyZXZtM2tiY3EzcDdhZDQyMmN2ZXIBZGRhdGFYIAPti/dnzI3Ij07mC2HCTa1QGHC6pGj8nXzGZVYsfhnaZHJlcG9xZGlkOmV4YW1wbGU6YWxpY2VlJHR5cGVyYXRwcm90by1zcGFjZS1yZXBvZXNwYWNleDBhdDovL2RpZDpleGFtcGxlOnNwYWNlL3NwYWNlL2FwcC5ic2t5Lmdyb3VwL3Rlc3QBF2FwcC5ic2t5LmZlZWQucG9zdC9zZWxmQKNjcmVm2CpYJQABcRIgZCjwIwS424yxB8iTNkgfD+rXKL83TKgBaNLHGTjO+udkdGV4dGVoZWxsb2Vjb3VudAEA")
        .unwrap();
    let err = read_star_repo(&legacy_v02, DEFAULT_MAX_ARCHIVE_BYTES).unwrap_err();
    assert!(matches!(err, SpaceError::LegacySpaceUriRejected(_)));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn space_credential_signature_v1_vectors_conform() {
    let v: SigVectors = serde_json::from_str(SIG_V1_JSON).unwrap();
    assert_eq!(v.cases.len(), 29);
    for case in &v.cases {
        let sig_input = case.signature_input.join(", ");
        let sig = case.signature.join(", ");
        let res = verify_http_signature_against_key(
            &v.authorization,
            &v.atproto_space_audience,
            &sig_input,
            &sig,
            &v.atproto_space_audience,
            &v.cnf_did_key,
            case.now_sec,
            v.max_signature_age_secs,
            v.max_clock_skew_secs,
            v.max_nonce_bytes,
        );
        match case.expect.as_str() {
            "accept" => assert!(
                res.is_ok(),
                "expected accept for case '{}', got {:?}",
                case.name,
                res
            ),
            "reject" => assert!(
                res.is_err(),
                "expected reject for case '{}', got Ok",
                case.name
            ),
            other => panic!("unexpected expect value '{other}'"),
        }
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn space_credential_replay_v1_vectors_conform() {
    let v: ReplayVectors = serde_json::from_str(REPLAY_V1_JSON).unwrap();
    let store = InMemorySignatureReplayCache::default();
    for (idx, step) in v.steps.iter().enumerate() {
        let _window_end = replay_window_end(
            step.created,
            step.expires,
            step.credential_exp,
            v.max_signature_age_secs,
            v.max_clock_skew_secs,
            v.credential_expiry_skew_secs,
        );
        let res = block_on(check_presentation_replay(
            &store,
            &step.issuer,
            step.nonce.as_deref(),
            step.created,
            step.expires,
            step.credential_exp,
            v.max_signature_age_secs,
            v.max_clock_skew_secs,
            v.credential_expiry_skew_secs,
            step.now_sec,
        ));
        match step.expect.as_str() {
            "accept" => assert!(
                res.is_ok(),
                "replay step {idx} expected accept, got {res:?}"
            ),
            "reject" => assert!(
                matches!(res, Err(SpaceError::SignatureReplay)),
                "replay step {idx} expected SignatureReplay, got {res:?}"
            ),
            other => panic!("unexpected expect '{other}'"),
        }
    }
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn nov24_space_ref_and_blob_locator_reject_legacy() {
    let valid_space =
        "at:space/did:web:ds.catbird.blue/blue.catbird.labyrinth.conversation/01980a11-gen1";
    let legacy_space =
        "at://did:web:ds.catbird.blue/space/blue.catbird.labyrinth.conversation/01980a11-gen1";
    let did = "did:plc:ewvi7nxzyoun6zhxrhs64oiz";
    let cid = "bafyreiewlrd6gvs3if3asi65l65ajstk7o5oyzh3m5fnbrngumaht5hq7m";

    assert!(parse_space_ref(valid_space).is_ok());
    assert!(matches!(
        parse_space_ref(legacy_space),
        Err(SpaceError::LegacySpaceUriRejected(_))
    ));
    assert!(
        parse_space_ref(
            "at://space/did:web:ds.catbird.blue/blue.catbird.labyrinth.conversation/01980a11-gen1"
        )
        .is_err()
    );

    let valid_loc = format!("{valid_space}|{did}|{cid}");
    let parsed = SpaceBlobLocator::parse(&valid_loc).unwrap();
    assert_eq!(parsed.encode(), valid_loc);

    let legacy_loc = format!("{legacy_space}|{did}|{cid}");
    assert!(matches!(
        SpaceBlobLocator::parse(&legacy_loc),
        Err(SpaceError::LegacySpaceUriRejected(_))
    ));
}
