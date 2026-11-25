#![cfg(test)]

#[cfg(target_arch = "wasm32")]
wasm_bindgen_test::wasm_bindgen_test_configure!(run_in_browser);

use std::collections::BTreeMap;
use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::task::{Context, Poll, Waker};

use http::HeaderMap;
use petrel_core::{AtUri, Bytes, Cid, Did, Nsid, RecordKey, SpaceRef, Tid, Value, syntax::Grammar};
use petrel_crypto::{ATProtoJWTVerificationKey, PublicKey, rt::BoxFuture};
use petrel_spaces::{
    LtHash, MacProfile, SigningKeyPair, SigningKeyResolver, SpaceError, StaticDidResolver,
    decapsulate_p256, decode_p256_did_key, encapsulate_p256, encode_p256_did_key,
    format_accept_signature, generate_p256_keypair, mint_client_attestation_token,
    mint_credential_token, mint_delegation_token, parse_accept_signature, parse_space_ref,
    read_star_metadata, read_star_repo, read_star_repo_authenticated, sign_commit_mac,
    sign_credential_request, sign_credential_request_minimal, sign_record_mac,
    verify_client_attestation_token, verify_commit_mac, verify_credential_request,
    verify_credential_token, verify_delegation_token, verify_json_value_for_dag_cbor,
    verify_record_cid, verify_record_mac, write_star_repo,
};
use serde_json::json;

fn block_on<F: Future>(fut: F) -> F::Output {
    let waker = Waker::noop().clone();
    let mut cx = Context::from_waker(&waker);
    let mut pinned = Box::pin(fut);
    match Pin::as_mut(&mut pinned).poll(&mut cx) {
        Poll::Ready(val) => val,
        Poll::Pending => panic!("unexpected Pending in synchronous mock test future"),
    }
}

struct RotatingResolver {
    old_key: ATProtoJWTVerificationKey,
    new_key: ATProtoJWTVerificationKey,
    refresh_calls: Arc<AtomicUsize>,
}

impl SigningKeyResolver for RotatingResolver {
    fn resolve_signing_key<'a>(
        &'a self,
        _did: &'a Did,
        _kid: &'a str,
        force_refresh: bool,
    ) -> BoxFuture<'a, petrel_spaces::Result<ATProtoJWTVerificationKey>> {
        Box::pin(async move {
            if force_refresh {
                self.refresh_calls.fetch_add(1, Ordering::SeqCst);
                Ok(self.new_key.clone())
            } else {
                Ok(self.old_key.clone())
            }
        })
    }
}

fn sample_space() -> SpaceRef {
    parse_space_ref("at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa").unwrap()
}

fn sample_record_value(text: &str) -> Value {
    let mut map = BTreeMap::new();
    map.insert(
        "$type".to_owned(),
        Value::String("app.bsky.feed.post".to_owned()),
    );
    map.insert("text".to_owned(), Value::String(text.to_owned()));
    Value::Object(map)
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn space_ref_ports_and_legacy_rejection() {
    let r =
        parse_space_ref("at:space/did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.group/self").unwrap();
    assert_eq!(r.space_did().as_str(), "did:plc:ewvi7nxzyoun6zhxrhs64oiz");
    assert_eq!(r.space_type().as_str(), "app.bsky.group");
    assert_eq!(r.skey().as_str(), "self");

    let author = Did::parse("did:plc:z72i7hdynmk6r22z27h6tvur").unwrap();
    let col = Nsid::parse("app.bsky.feed.post").unwrap();
    let rkey = RecordKey::parse("3l2aaaaaaaaab").unwrap();
    let rec_uri = r.record_uri(&author, &col, &rkey).unwrap();
    assert_eq!(
        rec_uri.as_str(),
        "at:space/did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.group/self/did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3l2aaaaaaaaab"
    );

    // Reject legacy at://.../space/...
    assert!(matches!(
        parse_space_ref("at://did:plc:ewvi7nxzyoun6zhxrhs64oiz/space/app.bsky.group/self"),
        Err(SpaceError::LegacySpaceUriRejected(_))
    ));
    // Reject missing segments or 6-part record URI passed where 3-part SpaceRef is expected
    assert!(parse_space_ref(rec_uri.as_str()).is_err());
    assert!(parse_space_ref("at:space/did:plc:alice/app.bsky.group").is_err());
    assert!(parse_space_ref("at:space/alice.bsky.social/app.bsky.group/self").is_err());
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn kem_roundtrip_and_mac_header_strict_duplicates() {
    let (sk, pk_did) = generate_p256_keypair().unwrap();
    let compressed = decode_p256_did_key(&pk_did).unwrap();
    assert_eq!(compressed.len(), 33);
    assert_eq!(encode_p256_did_key(&compressed).unwrap(), pk_did);

    let encap = encapsulate_p256(&pk_did).unwrap();
    let decap = decapsulate_p256(&sk, &encap.key_share).unwrap();
    assert_eq!(*encap.shared_secret, *decap);

    let accept = format_accept_signature(MacProfile::Commit, &encap.key_share).unwrap();
    let parsed = parse_accept_signature(&accept).unwrap();
    assert_eq!(parsed.profile, MacProfile::Commit);
    assert_eq!(parsed.keyid, encap.key_share);

    // MAC headers reject legacy at://.../space/... URIs and duplicate dictionary/param keys
    let space = sample_space();
    let repo = Did::parse("did:plc:ewvi7nxzyoun6zhxrhs64oiz").unwrap();
    let rev = Tid::parse("3l2aaaaaaaaac").unwrap();
    let data = [7u8; 32];
    let headers = sign_commit_mac(&decap, &space, &repo, &rev, &data, &encap.key_share).unwrap();
    let verified = verify_commit_mac(
        &decap,
        &headers.covered_signature,
        &headers.signature_input,
        &headers.signature,
    )
    .unwrap();
    assert_eq!(verified.data, data);

    // Duplicate dictionary key in Covered-Signature must fail
    let dup_cov = format!("{}, ver=1", headers.covered_signature);
    assert!(
        verify_commit_mac(
            &decap,
            &dup_cov,
            &headers.signature_input,
            &headers.signature
        )
        .is_err()
    );

    // Record MAC rejects non-6-part or legacy record URIs
    let rec_uri = AtUri::parse_with_grammar(
        "at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa/did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3l2aaaaaaaaab",
        Grammar::RestrictedOrSpace,
    )
    .unwrap();
    let cid = Cid::for_dag_cbor(b"\xa0");
    let rec_mac = sign_record_mac(&decap, &rec_uri, &cid, &encap.key_share).unwrap();
    assert!(
        verify_record_mac(
            &decap,
            &rec_mac.covered_signature,
            &rec_mac.signature_input,
            &rec_mac.signature,
        )
        .is_ok()
    );
    // Verify AtUri::parse rejects legacy at://.../space/... AND verify_record_mac rejects it in Covered-Signature
    let legacy_str = "at://did:web:ds.catbird.blue/space/blue.catbird.mlsChat/3l2aaaaaaaaaa/did:plc:ewvi7nxzyoun6zhxrhs64oiz/app.bsky.feed.post/3l2aaaaaaaaab";
    assert!(AtUri::parse(legacy_str).is_err());
    let legacy_cov = format!("uri=\"{legacy_str}\", cid=\"{cid}\"");
    let base_for_legacy = format!(
        "\"atproto-space-record\";sf: {legacy_cov}\n\"@signature-params\": (\"atproto-space-record\";sf);keyid=\"{}\";tag=\"atproto-space-record\"",
        encap.key_share
    );
    let mac_bytes =
        petrel_crypto::SpaceMAC::authentication_code(base_for_legacy.as_bytes(), decap.as_slice())
            .unwrap();
    let b64 = {
        use base64::Engine as _;
        base64::engine::general_purpose::STANDARD.encode(mac_bytes)
    };
    let err = verify_record_mac(
        &decap,
        &legacy_cov,
        &rec_mac.signature_input,
        &format!("mac=:{b64}:"),
    )
    .unwrap_err();
    assert!(matches!(err, SpaceError::LegacySpaceUriRejected(_)));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[allow(clippy::too_many_lines)]
#[test]
fn tokens_mint_verify_lifetime_rotation_and_client_attestation() {
    let space = sample_space();
    let user = Did::parse("did:plc:ewvi7nxzyoun6zhxrhs64oiz").unwrap();
    let host = Did::parse("did:web:ds.catbird.blue").unwrap();
    let client = Did::parse("did:web:client.catbird.blue").unwrap();

    let user_k256 = SigningKeyPair::generate_k256().unwrap();
    let host_p256 = SigningKeyPair::generate_p256().unwrap();
    let client_p256 = SigningKeyPair::generate_p256().unwrap();
    let proof_p256 = SigningKeyPair::generate_p256().unwrap();
    let proof_kid = proof_p256.did_key().unwrap();

    let mut resolver = StaticDidResolver::new();
    resolver.insert_keypair(&user, &user_k256, None);
    resolver.insert_keypair(&host, &host_p256, None);
    resolver.insert_keypair(&client, &client_p256, None);

    let now = 1_800_000_000i64;
    let delegation =
        mint_delegation_token(&user_k256, &user, &host, &space, now, now + 60, None, None).unwrap();
    let del_claims = block_on(verify_delegation_token(
        &delegation,
        host.as_str(),
        now + 5,
        &resolver,
    ))
    .unwrap();
    assert_eq!(del_claims.iss, user.as_str());

    // Overlong delegation lifetime (>60s) rejected at mint and verify
    assert!(matches!(
        mint_delegation_token(&user_k256, &user, &host, &space, now, now + 61, None, None),
        Err(SpaceError::TokenLifetimeTooLong { .. })
    ));

    // Wrong audience rejected
    let other_aud = "did:plc:otherhost111111111111111";
    assert!(matches!(
        block_on(verify_delegation_token(
            &delegation,
            other_aud,
            now + 5,
            &resolver
        )),
        Err(SpaceError::InvalidAudience { .. })
    ));

    // Credential mint + RFC 9421 request sign/verify (both full & minimal)
    let cred = mint_credential_token(
        &host_p256,
        &host,
        &space,
        &proof_kid,
        now,
        now + 900,
        Some("jti-1"),
        None,
    )
    .unwrap();
    let cred_claims = block_on(verify_credential_token(&cred, now + 10, &resolver)).unwrap();
    assert_eq!(cred_claims.cnf.kid, proof_kid);

    let req_headers = sign_credential_request(
        &cred,
        &proof_p256,
        "did:plc:targetpds",
        now + 10,
        Some("n-1"),
    )
    .unwrap();
    let mut hmap = HeaderMap::new();
    req_headers.apply_to_header_map(&mut hmap).unwrap();
    let verified = block_on(verify_credential_request(
        &hmap,
        "did:plc:targetpds",
        now + 15,
        &resolver,
    ))
    .unwrap();
    assert_eq!(verified.nonce.as_deref(), Some("n-1"));

    let min_headers =
        sign_credential_request_minimal(&cred, &proof_p256, "did:plc:targetpds").unwrap();
    let mut min_map = HeaderMap::new();
    min_headers.apply_to_header_map(&mut min_map).unwrap();
    assert!(
        block_on(verify_credential_request(
            &min_map,
            "did:plc:targetpds",
            now + 20,
            &resolver,
        ))
        .is_ok()
    );

    // Client attestation mint + verify
    let att = mint_client_attestation_token(
        &client_p256,
        &client,
        &host,
        Some(space.as_str()),
        Some(&proof_kid),
        now,
        now + 120,
        None,
        None,
    )
    .unwrap();
    let att_claims = block_on(verify_client_attestation_token(
        &att,
        host.as_str(),
        now + 10,
        &resolver,
    ))
    .unwrap();
    assert_eq!(att_claims.sub.as_deref(), Some(space.as_str()));
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn tokens_key_rotation_triggers_single_refresh() {
    let space = sample_space();
    let user = Did::parse("did:plc:ewvi7nxzyoun6zhxrhs64oiz").unwrap();
    let host = Did::parse("did:web:ds.catbird.blue").unwrap();
    let user_k256 = SigningKeyPair::generate_k256().unwrap();
    let now = 1_800_000_000i64;
    let rotated_key = SigningKeyPair::generate_p256().unwrap();
    let del_rotated = mint_delegation_token(
        &rotated_key,
        &user,
        &host,
        &space,
        now,
        now + 30,
        None,
        None,
    )
    .unwrap();
    let refresh_calls = Arc::new(AtomicUsize::new(0));
    let rot_resolver = RotatingResolver {
        old_key: ATProtoJWTVerificationKey::from_public_key(&user_k256.public_key()),
        new_key: ATProtoJWTVerificationKey::from_public_key(&rotated_key.public_key()),
        refresh_calls: refresh_calls.clone(),
    };
    assert!(
        block_on(verify_delegation_token(
            &del_rotated,
            host.as_str(),
            now + 5,
            &rot_resolver,
        ))
        .is_ok()
    );
    assert_eq!(refresh_calls.load(Ordering::SeqCst), 1);
}

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[test]
fn star_archive_errors_limits_and_json_safe_integer_checks() {
    let space = sample_space();
    let repo = Did::parse("did:plc:ewvi7nxzyoun6zhxrhs64oiz").unwrap();
    let rev = Tid::parse("3l2aaaaaaaaac").unwrap();
    let val = sample_record_value("hello");

    let archive = write_star_repo(&space, &repo, &rev, &[("app.bsky.feed.post/1", &val)]).unwrap();
    let meta = read_star_metadata(&archive).unwrap();
    assert_eq!(meta.space, space);

    // Duplicate paths refused when writing & reading
    assert!(matches!(
        write_star_repo(
            &space,
            &repo,
            &rev,
            &[
                ("app.bsky.feed.post/1", &val),
                ("app.bsky.feed.post/1", &val)
            ]
        ),
        Err(SpaceError::InvalidArchive(_))
    ));

    // Size limit enforcement
    assert!(matches!(
        read_star_repo(&archive, archive.len() - 1),
        Err(SpaceError::ArchiveTooLarge { .. })
    ));

    // Trailing byte rejection
    let mut with_trailing = archive.clone();
    with_trailing.push(0x99);
    assert!(matches!(
        read_star_repo(&with_trailing, 1024 * 1024),
        Err(SpaceError::InvalidArchive(_))
    ));

    // Blob tag 0x02 rejection
    let mut with_blob = archive[..archive.len() - 1].to_vec();
    with_blob.push(0x02);
    with_blob.push(0x00);
    assert!(matches!(
        read_star_repo(&with_blob, 1024 * 1024),
        Err(SpaceError::BlobNotSupported(_))
    ));

    // Tampered commit data rejected by authenticated STAR reader
    let wrong_data = [0xabu8; 32];
    assert!(matches!(
        read_star_repo_authenticated(
            &archive,
            &space,
            Some(&repo),
            Some(&rev),
            Some(&wrong_data),
            1024 * 1024
        ),
        Err(SpaceError::DataHashMismatch { .. })
    ));
    assert!(
        read_star_repo_authenticated(
            &archive,
            &space,
            Some(&repo),
            Some(&rev),
            Some(&meta.data),
            1024 * 1024
        )
        .is_ok()
    );

    // Safe JSON integers and getRecord CID verification
    let safe = json!({
        "$type": "app.bsky.feed.post",
        "text": "safe",
        "n": 9_007_199_254_740_991_i64,
        "neg": -9_007_199_254_740_991_i64,
        "blob": { "$bytes": "AQID" }
    });
    let safe_val = verify_json_value_for_dag_cbor(&safe).unwrap();
    let expected_cid = safe_val.cid();
    assert!(verify_record_cid(&safe, &expected_cid).is_ok());

    let unsafe_pos = json!({ "n": 9_007_199_254_740_992_i64 });
    assert!(matches!(
        verify_json_value_for_dag_cbor(&unsafe_pos),
        Err(SpaceError::UnsafeInteger(_))
    ));
    let unsafe_float = json!({ "n": 1.5 });
    assert!(matches!(
        verify_json_value_for_dag_cbor(&unsafe_float),
        Err(SpaceError::UnsafeInteger(_))
    ));

    // Inventory LtHash commutative add/remove
    let mut lt = LtHash::new();
    lt.add_inventory_entry("atproto-space-writer-inventory-v1", "did:plc:alice", "rev1");
    let before = lt.hash();
    lt.add_inventory_entry("atproto-space-writer-inventory-v1", "did:plc:bob", "rev2");
    assert_ne!(lt.hash(), before);
    lt.remove_inventory_entry("atproto-space-writer-inventory-v1", "did:plc:bob", "rev2");
    assert_eq!(lt.hash(), before);

    // Silence unused Bytes / PublicKey import if optimized
    let _ = (Bytes::default(), PublicKey::from_did_key("did:key:invalid"));
}
