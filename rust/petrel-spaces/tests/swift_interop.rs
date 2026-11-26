#![cfg(all(test, not(target_arch = "wasm32")))]

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::process::Command;

use petrel_core::{AtUri, Cid, Did, Nsid, RecordKey, Tid, Value, dagcbor::encode, syntax::Grammar};
use petrel_crypto::{ATProtoJWTVerificationKey, Hex, PublicKey, SpaceSetHash};
use petrel_spaces::{
    MacProfile, SigningKeyPair, StaticDidResolver, decapsulate_p256, encapsulate_p256,
    format_accept_signature, generate_p256_keypair, mint_credential_token, parse_accept_signature,
    parse_space_ref, sign_commit_mac, sign_credential_request, sign_record_mac, verify_commit_mac,
    verify_credential_headers, verify_record_mac, write_star_repo,
};
use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SwiftEmitManifest {
    space_uri: String,
    record_uri: String,
    repo_did: String,
    rev: String,
    data_hex: String,
    author_kem_secret_hex: String,
    key_share_did_key: String,
    shared_secret_hex: String,
    accept_commit_header: String,
    accept_record_header: String,
    commit_covered_header: String,
    commit_signature_input: String,
    commit_signature: String,
    record_covered_header: String,
    record_signature_input: String,
    record_signature: String,
    record_cid: String,
    authority_did: String,
    authority_did_key: String,
    audience_did: String,
    authorization: String,
    signature_input: String,
    signature: String,
    created: i64,
    nonce: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct RustEmitManifest {
    space_uri: String,
    record_uri: String,
    repo_did: String,
    rev: String,
    data_hex: String,
    author_kem_secret_hex: String,
    author_kem_did_key: String,
    key_share_did_key: String,
    shared_secret_hex: String,
    accept_commit_header: String,
    commit_covered_header: String,
    commit_signature_input: String,
    commit_signature: String,
    record_covered_header: String,
    record_signature_input: String,
    record_signature: String,
    record_cid: String,
    authority_did_key: String,
    cnf_did_key: String,
    audience_did: String,
    credential_jwt: String,
    authorization: String,
    signature_input: String,
    signature: String,
    created: i64,
    nonce: String,
    star_archive_hex: String,
}

fn find_compiled_swift_driver(scratch: &Path) -> Option<PathBuf> {
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let package_root = manifest_dir.parent()?.parent()?;
    let bin_dir = package_root.join(".build/out/Products/Debug");
    let module_maps_dir = package_root.join(".build/out/Intermediates.noindex/GeneratedModuleMaps");
    if !bin_dir.join("Petrel.swiftmodule").exists() || !module_maps_dir.exists() {
        assert!(
            std::env::var("PETREL_SWIFT_INTEROP_REQUIRED").as_deref() != Ok("1"),
            "Petrel Swift build artifacts missing at {}",
            bin_dir.display()
        );
        return None;
    }

    let driver_src = manifest_dir.join("tests/swift_interop_driver.swift");
    let driver_bin = scratch.join("swift_interop_driver");

    let mut cmd = Command::new("xcrun");
    cmd.arg("swiftc")
        .arg("-parse-as-library")
        .arg("-I")
        .arg(&bin_dir);

    let mut module_maps: Vec<PathBuf> = std::fs::read_dir(&module_maps_dir)
        .ok()?
        .filter_map(Result::ok)
        .map(|e| e.path())
        .filter(|p| p.extension().and_then(|e| e.to_str()) == Some("modulemap"))
        .collect();
    module_maps.sort();
    for mm in module_maps {
        cmd.arg("-Xcc")
            .arg(format!("-fmodule-map-file={}", mm.display()));
    }

    let mut objs: Vec<PathBuf> = std::fs::read_dir(&bin_dir)
        .ok()?
        .filter_map(Result::ok)
        .map(|e| e.path())
        .filter(|p| p.extension().and_then(|e| e.to_str()) == Some("o"))
        .collect();
    objs.sort();
    for obj in objs {
        cmd.arg(obj);
    }

    cmd.args(["-framework", "Security", "-framework", "Foundation", "-o"])
        .arg(&driver_bin)
        .arg(&driver_src);

    let output = cmd.output().expect("invoke xcrun swiftc");
    assert!(
        output.status.success(),
        "swiftc failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    Some(driver_bin)
}

#[tokio::test]
async fn bidirectional_live_swift_petrel_spaces_interop() {
    let scratch = tempfile::tempdir().unwrap();
    let Some(driver) = find_compiled_swift_driver(scratch.path()) else {
        return;
    };
    verify_swift_to_rust(&driver, scratch.path()).await;
    verify_rust_to_swift(&driver, scratch.path());
}

async fn verify_swift_to_rust(driver: &Path, scratch: &Path) {
    let swift_dir = scratch.join("swift_to_rust");
    std::fs::create_dir_all(&swift_dir).unwrap();
    let emit_out = Command::new(driver)
        .arg("emit")
        .arg(&swift_dir)
        .output()
        .unwrap();
    assert!(
        emit_out.status.success(),
        "Swift emit failed: {}",
        String::from_utf8_lossy(&emit_out.stderr)
    );

    let sm: SwiftEmitManifest =
        serde_json::from_slice(&std::fs::read(swift_dir.join("swift_manifest.json")).unwrap())
            .unwrap();

    let kem_sec: [u8; 32] = Hex::decode(&sm.author_kem_secret_hex)
        .unwrap()
        .try_into()
        .unwrap();
    let rust_decap = decapsulate_p256(&kem_sec, &sm.key_share_did_key).unwrap();
    assert_eq!(Hex::encode(&*rust_decap), sm.shared_secret_hex);

    let parsed_accept = parse_accept_signature(&sm.accept_commit_header).unwrap();
    assert_eq!(parsed_accept.profile, MacProfile::Commit);
    assert_eq!(parsed_accept.keyid, sm.key_share_did_key);
    let parsed_rec_accept = parse_accept_signature(&sm.accept_record_header).unwrap();
    assert_eq!(parsed_rec_accept.profile, MacProfile::Record);

    let verified_cm = verify_commit_mac(
        &rust_decap,
        &sm.commit_covered_header,
        &sm.commit_signature_input,
        &sm.commit_signature,
    )
    .unwrap();
    assert_eq!(verified_cm.space.as_str(), sm.space_uri);
    assert_eq!(verified_cm.repo.as_str(), sm.repo_did);
    assert_eq!(verified_cm.rev.as_str(), sm.rev);
    assert_eq!(Hex::encode(&verified_cm.data), sm.data_hex);

    let verified_record_mac = verify_record_mac(
        &rust_decap,
        &sm.record_covered_header,
        &sm.record_signature_input,
        &sm.record_signature,
    )
    .unwrap();
    assert_eq!(verified_record_mac.uri.as_str(), sm.record_uri);
    assert_eq!(verified_record_mac.cid.to_string(), sm.record_cid);

    let auth_did = Did::parse(&sm.authority_did).unwrap();
    let auth_pk = PublicKey::from_did_key(&sm.authority_did_key).unwrap();
    let mut resolver = StaticDidResolver::new();
    resolver.insert_signing_key(
        auth_did,
        "#atproto",
        &ATProtoJWTVerificationKey::from_public_key(&auth_pk),
    );
    let verified_hdrs = verify_credential_headers(
        &sm.authorization,
        &sm.audience_did,
        &sm.signature_input,
        &sm.signature,
        &sm.audience_did,
        sm.created + 5,
        300,
        60,
        512,
        &resolver,
    )
    .await
    .unwrap();
    assert_eq!(verified_hdrs.claims.sub, sm.space_uri);
    assert_eq!(verified_hdrs.nonce.as_deref(), Some(sm.nonce.as_str()));
}

#[allow(clippy::too_many_lines)]
fn verify_rust_to_swift(driver: &Path, scratch: &Path) {
    let rust_dir = scratch.join("rust_to_swift");
    std::fs::create_dir_all(&rust_dir).unwrap();

    let space =
        parse_space_ref("at:space/did:web:ds.catbird.blue/blue.catbird.mlsChat/3l2aaaaaaaaaa")
            .unwrap();
    let repo = Did::parse("did:plc:ewvi7nxzyoun6zhxrhs64oiz").unwrap();
    let rev = Tid::parse("3l2aaaaaaaaac").unwrap();
    let col = Nsid::parse("blue.catbird.mlsChat.message").unwrap();
    let rkey = RecordKey::parse("3l2aaaaaaaaab").unwrap();
    let rec_uri = space.record_uri(&repo, &col, &rkey).unwrap();

    let mut rec_map = BTreeMap::new();
    rec_map.insert("$type".to_owned(), Value::String(col.as_str().to_owned()));
    rec_map.insert(
        "text".to_owned(),
        Value::String("rust-to-swift-space-interop".to_owned()),
    );
    let rec_val = Value::Object(rec_map);
    let rec_cbor = encode(&rec_val);
    let rec_cid = Cid::for_dag_cbor(&rec_cbor);
    let rec_path = format!("{col}/{rkey}");

    let mut set_hash = SpaceSetHash::new();
    set_hash.add(&rec_path, &rec_cid.to_string());
    let data = set_hash.digest();

    let (kem_sk, kem_did_key) = generate_p256_keypair().unwrap();
    let encap = encapsulate_p256(&kem_did_key).unwrap();
    let accept_commit = format_accept_signature(MacProfile::Commit, &encap.key_share).unwrap();
    let cm = sign_commit_mac(
        &encap.shared_secret,
        &space,
        &repo,
        &rev,
        &data,
        &encap.key_share,
    )
    .unwrap();
    let rm = sign_record_mac(&encap.shared_secret, &rec_uri, &rec_cid, &encap.key_share).unwrap();
    let star_bytes =
        write_star_repo(&space, &repo, &rev, &[(rec_path.as_str(), &rec_val)]).unwrap();

    let authority_did = Did::parse("did:web:ds.catbird.blue").unwrap();
    let authority_kp = SigningKeyPair::generate_p256().unwrap();
    let cnf_kp = SigningKeyPair::generate_p256().unwrap();
    let cnf_did_key = cnf_kp.did_key().unwrap();
    let audience_did = "did:plc:z72i7hdynmk6r22z27h6tvur";
    let now = 1_800_000_000i64;
    let nonce = "rust-nonce-0001";

    let cred_jwt = mint_credential_token(
        &authority_kp,
        &authority_did,
        &space,
        &cnf_did_key,
        now,
        now + 600,
        Some("rust-cred-jti-001"),
        None,
    )
    .unwrap();
    let req_hdrs =
        sign_credential_request(&cred_jwt, &cnf_kp, audience_did, now, Some(nonce)).unwrap();

    let rm_manifest = RustEmitManifest {
        space_uri: space.as_str().to_owned(),
        record_uri: rec_uri.as_str().to_owned(),
        repo_did: repo.as_str().to_owned(),
        rev: rev.as_str().to_owned(),
        data_hex: Hex::encode(&data),
        author_kem_secret_hex: Hex::encode(&*kem_sk),
        author_kem_did_key: kem_did_key,
        key_share_did_key: encap.key_share,
        shared_secret_hex: Hex::encode(&*encap.shared_secret),
        accept_commit_header: accept_commit,
        commit_covered_header: cm.covered_signature,
        commit_signature_input: cm.signature_input,
        commit_signature: cm.signature,
        record_covered_header: rm.covered_signature,
        record_signature_input: rm.signature_input,
        record_signature: rm.signature,
        record_cid: rec_cid.to_string(),
        authority_did_key: authority_kp.did_key().unwrap(),
        cnf_did_key,
        audience_did: audience_did.to_owned(),
        credential_jwt: cred_jwt,
        authorization: req_hdrs.authorization,
        signature_input: req_hdrs.signature_input,
        signature: req_hdrs.signature,
        created: now,
        nonce: nonce.to_owned(),
        star_archive_hex: Hex::encode(&star_bytes),
    };
    std::fs::write(
        rust_dir.join("rust_manifest.json"),
        serde_json::to_vec_pretty(&rm_manifest).unwrap(),
    )
    .unwrap();

    let verify_out = Command::new(driver)
        .arg("verify")
        .arg(&rust_dir)
        .output()
        .unwrap();
    assert!(
        verify_out.status.success(),
        "Swift verify failed:\nstdout: {}\nstderr: {}",
        String::from_utf8_lossy(&verify_out.stdout),
        String::from_utf8_lossy(&verify_out.stderr),
    );

    let _ = AtUri::parse_with_grammar(rec_uri.as_str(), Grammar::RestrictedOrSpace).unwrap();
}
