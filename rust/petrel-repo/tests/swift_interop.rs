mod common;

use base64::Engine as _;
use base64::engine::general_purpose::STANDARD;
use petrel_core::{Did, Value};
use petrel_repo::block_store::{BlockStore as _, InMemoryBlockStore};
use petrel_repo::car::{DataCARByteSource, PublicRepositoryCAR};
use petrel_repo::crypto::{P256Keypair, SigningPublicKey};
use petrel_repo::limits::RepositoryLimits;
use petrel_repo::repository::{OpenVerification, Repository};
use petrel_repo::types::RepositoryReadPolicy;

const TS_SINGLE_CAR_B64: &str = "OqJlcm9vdHOB2CpYJQABcRIgUb9RevQfWI09Cti+qt2f9y26xM/ODyenYvXHOsVg1y5ndmVyc2lvbgHgAQFxEiBRv1F69B9YjT0K2L6q3Z/3LbrEz84PJ6di9cc6xWDXLqZjZGlkeCBkaWQ6cGxjOmV3dmk3bnh6eW91bjZ6aHhyaHM2NG9pemNyZXZtM2p6ZmNpanBqMnoyYWNzaWdYQB7hxPKqGRgEAmLhl/9gcP6KPxZ27Kuq8TEgEBBanN00HTHYPItY2OYi1SSnFXNgWdHvUpPKbg5vyiaG9f+X27dkZGF0YdgqWCUAAXESIBpKoUfD4BmU7U13yh4x/ikZ9nAZ29Ek9LFlP8lJtWX3ZHByZXb2Z3ZlcnNpb24DdAFxEiAaSqFHw+AZlO1Nd8oeMf4pGfZwGdvRJPSxZT/JSbVl96JhZYGkYWtUYXBwLmJza3kuZmVlZC5wb3N0LzBhcABhdPZhdtgqWCUAAXESIGk0RaQWmdJnLmvjDnSWWlR7kWG7SDcI3sEQLvym/rEGYWz2YQFxEiBpNEWkFpnSZy5r4w50llpUe5Fhu0g3CN7BEC78pv6xBqJkdGV4dHgcaGVsbG8gZnJvbSBwaW5uZWQgVHlwZVNjcmlwdGUkdHlwZXJhcHAuYnNreS5mZWVkLnBvc3Q=";
const TS_SINGLE_COMMIT: &str = "bafyreicrx5ixv5a7lcgt2cwyx2vn3h7xfw5mjt6ob4t2oyxvy45mkygxfy";

const SWIFT_SINGLE_CAR_B64: &str = "OqJlcm9vdHOB2CpYJQABcRIgHw25ZLOi9veFni6BlDWV8p6DUays9xXQhlA9XEBvw5pndmVyc2lvbgHgAQFxEiAfDblks6L294WeLoGUNZXynoNRrKz3FdCGUD1cQG/DmqZjZGlkeCBkaWQ6cGxjOmV3dmk3bnh6eW91bjZ6aHhyaHM2NG9pemNyZXZtM2p6ZmNpanBqMnoyYWNzaWdYQC0dFnr9h93SKyTGvyPQtD/Z+4vttqkbFOcHm/HXgOFnP/mtQARw/ad39P0fgqCJnPWTFC1f0+7/zfaGVdrzyTpkZGF0YdgqWCUAAXESIBpKoUfD4BmU7U13yh4x/ikZ9nAZ29Ek9LFlP8lJtWX3ZHByZXb2Z3ZlcnNpb24DdAFxEiAaSqFHw+AZlO1Nd8oeMf4pGfZwGdvRJPSxZT/JSbVl96JhZYGkYWtUYXBwLmJza3kuZmVlZC5wb3N0LzBhcABhdPZhdtgqWCUAAXESIGk0RaQWmdJnLmvjDnSWWlR7kWG7SDcI3sEQLvym/rEGYWz2YQFxEiBpNEWkFpnSZy5r4w50llpUe5Fhu0g3CN7BEC78pv6xBqJkdGV4dHgcaGVsbG8gZnJvbSBwaW5uZWQgVHlwZVNjcmlwdGUkdHlwZXJhcHAuYnNreS5mZWVkLnBvc3Q=";
const SWIFT_SINGLE_COMMIT: &str = "bafyreia7bw4wjm5c633ylhroqgkdlfpst2bvdlfm64k5bbsqhvoea36dti";

const TS_MULTILAYER_CAR_B64: &str = "OqJlcm9vdHOB2CpYJQABcRIgCMTE75Suq5ZpM1o6sgl63YFvmW7gP9C8yeX29VbEpO5ndmVyc2lvbgHgAQFxEiAIxMTvlK6rlmkzWjqyCXrdgW+ZbuA/0LzJ5fb1VsSk7qZjZGlkeCBkaWQ6cGxjOmV3dmk3bnh6eW91bjZ6aHhyaHM2NG9pemNyZXZtM2p6ZmNpanBqMnoyYWNzaWdYQJ4eF+DTWeXt2xNKFSIoTll9MwwxihuhXm3bpAJow/5BaIkRA5TdqR0EBdUCQV+Tl87csOErjTUnNtW/O2xYHZ1kZGF0YdgqWCUAAXESIIN5L62WmzjI7FhZIjBBHAzvC0jemU+BMvgHOzaN9K9bZHByZXb2Z3ZlcnNpb24D0QEBcRIgg3kvrZabOMjsWFkiMEEcDO8LSN6ZT4Ey+Ac7No30r1uiYWWBpGFrWCBjb20uZXhhbXBsZS5yZWNvcmQvM2pxZmNxem0zZngyamFwAGF02CpYJQABcRIgPlpvhTSc63XczFDGhL1FPsaFQvsjryisCvoA5LpjJMlhdtgqWCUAAXESIK4vt8InuOKG+1w7cZg4XiwUAGfXIdz3EwZAVdM3/cGFYWzYKlglAAFxEiC7q7JxNtKV/nYtvzJdwtKs5GD2pAulSwBQbVb9Vxo7e9EBAXESILursnE20pX+di2/Ml3C0qzkYPakC6VLAFBtVv1XGjt7omFlgaRha1ggY29tLmV4YW1wbGUucmVjb3JkLzNqcWZjcXptM2ZzMmphcABhdNgqWCUAAXESIBij9X1mHQ5Q3bR9VbKm0+xpc5EciH1dDsdYog33qXnIYXbYKlglAAFxEiB6E+hxsiwmbFe5oIJmP48TAVKWOeqgfKSl+bO7S88RZmFs2CpYJQABcRIgEGHq3H/enSXOuuW0t7DWOi3gDMSkwZ0VJAMHRPkMpC9TAXESID5ab4U0nOt13MxQxoS9RT7GhUL7I68orAr6AOS6YyTJomFlgGFs2CpYJQABcRIgWU6jdiVjpPDB6OLYjYG/H849LTLSAoapyBrRCuKcJSbzAQFxEiAQYercf96dJc665bS3sNY6LeAMxKTBnRUkAwdE+QykL6JhZYOkYWtYIGNvbS5leGFtcGxlLnJlY29yZC8zanFmY3F6bTNmbzJqYXAAYXT2YXbYKlglAAFxEiA4F0jimGrBmHyVzR6dxzphsvHhpJQJv4uAY3uHPr3ih6Rha0NwMmphcBgdYXT2YXbYKlglAAFxEiBWX4Qdeq0FiDG0Wr9wKjbzZg6YwJqDgyNJthkZjmqIzaRha0NyMmphcBgdYXT2YXbYKlglAAFxEiA8h4Q4nlcw2rD6PCl9j5mvtcYuHzi7Jwea+MIBufTrkWFs9oEBAXESIBij9X1mHQ5Q3bR9VbKm0+xpc5EciH1dDsdYog33qXnIomFlgaRha1ggY29tLmV4YW1wbGUucmVjb3JkLzNqcWZjcXptM2Z0MmphcABhdPZhdtgqWCUAAXESIC0OZiYBmUAyib4TM6dRNYZ8AoxG44OjA5Lwibkb1K7KYWz2vAEBcRIgWU6jdiVjpPDB6OLYjYG/H849LTLSAoapyBrRCuKcJSaiYWWCpGFrWCBjb20uZXhhbXBsZS5yZWNvcmQvM2pxZmNxem0zZnoyamFwAGF09mF22CpYJQABcRIgaE+Bm1VP6FIg1YxG9aMwfQaS1jaEEoq0XlvUGgquVUWkYWtFNGZjMmphcBgbYXT2YXbYKlglAAFxEiDhMz39KeuBVqXf4SIpbuv59kEMYcKjTcF9RkQuvNCZ2WFs9kwBcRIgri+3wie44ob7XDtxmDheLBQAZ9ch3PcTBkBV0zf9wYWiZHRleHRodmVjdG9yLTVlJHR5cGVyY29tLmV4YW1wbGUucmVjb3JkTAFxEiB6E+hxsiwmbFe5oIJmP48TAVKWOeqgfKSl+bO7S88RZqJkdGV4dGh2ZWN0b3ItM2UkdHlwZXJjb20uZXhhbXBsZS5yZWNvcmRMAXESIDgXSOKYasGYfJXNHp3HOmGy8eGklAm/i4Bje4c+veKHomR0ZXh0aHZlY3Rvci0wZSR0eXBlcmNvbS5leGFtcGxlLnJlY29yZEwBcRIgVl+EHXqtBYgxtFq/cCo282YOmMCag4MjSbYZGY5qiM2iZHRleHRodmVjdG9yLTFlJHR5cGVyY29tLmV4YW1wbGUucmVjb3JkTAFxEiA8h4Q4nlcw2rD6PCl9j5mvtcYuHzi7Jwea+MIBufTrkaJkdGV4dGh2ZWN0b3ItMmUkdHlwZXJjb20uZXhhbXBsZS5yZWNvcmRMAXESIC0OZiYBmUAyib4TM6dRNYZ8AoxG44OjA5Lwibkb1K7KomR0ZXh0aHZlY3Rvci00ZSR0eXBlcmNvbS5leGFtcGxlLnJlY29yZEwBcRIgaE+Bm1VP6FIg1YxG9aMwfQaS1jaEEoq0XlvUGgquVUWiZHRleHRodmVjdG9yLTZlJHR5cGVyY29tLmV4YW1wbGUucmVjb3JkTAFxEiDhMz39KeuBVqXf4SIpbuv59kEMYcKjTcF9RkQuvNCZ2aJkdGV4dGh2ZWN0b3ItN2UkdHlwZXJjb20uZXhhbXBsZS5yZWNvcmQ=";
const TS_MULTILAYER_COMMIT: &str = "bafyreiaiytco7ffovolgsm22hkzas6w5qfxzs3xah7ilzspf632vnrfe5y";
const TS_MULTILAYER_DATA: &str = "bafyreiedpex23fu3hdeoywczeiyecham54furxuzj6atf6ahhm3i35fplm";
const PINNED_DID_KEY: &str = "did:key:zDnaeXxvmFHMHjqgQTbadpWG7gPHwnga1i7SMwxrV2BSdUjAD";

#[cfg_attr(target_arch = "wasm32", wasm_bindgen_test::wasm_bindgen_test)]
#[cfg_attr(not(target_arch = "wasm32"), tokio::test)]
async fn pinned_swift_and_typescript_cars_verify_and_reexport_identically() {
    let did = Did::parse("did:plc:ewvi7nxzyoun6zhxrhs64oiz").unwrap();
    let keypair = P256Keypair::from_bytes(&[1_u8; 32]).unwrap();
    assert_eq!(keypair.did_key(), PINNED_DID_KEY);
    let pub_key = SigningPublicKey::from_did_key(PINNED_DID_KEY).unwrap();
    assert_eq!(&pub_key, keypair.public_key());

    // 1. Pinned TypeScript CAR
    let ts_bytes = STANDARD.decode(TS_SINGLE_CAR_B64).unwrap();
    let ts_repo = Repository::open_car(
        &ts_bytes,
        OpenVerification::SigningKey(pub_key.clone()),
        Some(&did),
    )
    .await
    .unwrap();
    assert_eq!(ts_repo.commit().cid.to_string(), TS_SINGLE_COMMIT);
    assert_eq!(ts_repo.revision().as_str(), "3jzfcijpj2z2a");
    let ts_record = ts_repo
        .record("app.bsky.feed.post", "0")
        .await
        .unwrap()
        .unwrap();
    assert_eq!(
        ts_record.record().unwrap().get("text"),
        Some(&Value::String("hello from pinned TypeScript".into()))
    );

    // 2. Pinned Swift PetrelRepo CAR (chunked streaming + byte-for-byte re-export)
    let swift_bytes = STANDARD.decode(SWIFT_SINGLE_CAR_B64).unwrap();
    let swift_store = std::sync::Arc::new(InMemoryBlockStore::new());
    let mut source = DataCARByteSource::with_chunk_size(swift_bytes.clone(), 5);
    let swift_repo = Repository::open_car_source(
        &mut source,
        swift_store,
        OpenVerification::SigningKey(pub_key.clone()),
        Some(&did),
        RepositoryLimits::standard(),
        RepositoryReadPolicy::strict(),
        true,
    )
    .await
    .unwrap();
    assert_eq!(swift_repo.commit().cid.to_string(), SWIFT_SINGLE_COMMIT);
    assert_eq!(swift_repo.commit().data_cid, ts_repo.commit().data_cid);
    assert_eq!(swift_repo.export_car().await.unwrap(), swift_bytes);

    // 3. Pinned TypeScript 8-record multi-layer MST CAR
    let ml_bytes = STANDARD.decode(TS_MULTILAYER_CAR_B64).unwrap();
    let ml_repo =
        Repository::open_car(&ml_bytes, OpenVerification::SigningKey(pub_key), Some(&did))
            .await
            .unwrap();
    assert_eq!(ml_repo.commit().cid.to_string(), TS_MULTILAYER_COMMIT);
    assert_eq!(ml_repo.commit().data_cid.to_string(), TS_MULTILAYER_DATA);
    assert_eq!(ml_repo.statistics().unwrap().record_count, 8);
    let ml_sink = petrel_repo::car::DataCARByteSink::new();
    ml_repo
        .export_car_to_sink(&ml_sink, petrel_repo::CARExportOrder::BreadthFirst)
        .await
        .unwrap();
    assert_eq!(ml_sink.into_bytes().await, ml_bytes);
    let _ = PublicRepositoryCAR;
    let _ = ml_repo.store().len().await.unwrap();
}

#[cfg(not(target_arch = "wasm32"))]
mod live_swift_interop {
    use std::collections::BTreeMap;
    use std::path::{Path, PathBuf};
    use std::process::Command;

    use petrel_core::{Cid, Did, Value};
    use petrel_repo::crypto::{FixedSigningKey, K256Keypair, P256Keypair, SigningPublicKey};
    use petrel_repo::diff::{CommitDiff, CommitOperation};
    use petrel_repo::limits::RepositoryLimits;
    use petrel_repo::repository::{OpenVerification, Repository, create_op, update_op};
    use petrel_repo::types::{RepositoryPath, RepositoryReadPolicy, WriteBatch, WriteOp};
    use serde::{Deserialize, Serialize};

    #[derive(Debug, Serialize, Deserialize)]
    struct OpJson {
        action: String,
        collection: String,
        rkey: String,
        cid: Option<String>,
        prev: Option<String>,
    }

    #[derive(Debug, Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct SwiftManifest {
        did: String,
        p256_did_key: String,
        #[serde(rename = "p256CommitCID")]
        p256_commit_cid: String,
        #[serde(rename = "p256DataCID")]
        p256_data_cid: String,
        p256_rev: String,
        #[serde(rename = "p256PreviousDataCID")]
        p256_previous_data_cid: String,
        p256_ops: Vec<OpJson>,
        k256_did_key: String,
        #[serde(rename = "k256CommitCID")]
        k256_commit_cid: String,
        #[serde(rename = "k256DataCID")]
        k256_data_cid: String,
        k256_rev: String,
        present_collection: String,
        present_rkey: String,
        absent_collection: String,
        absent_rkey: String,
    }

    #[derive(Debug, Serialize)]
    #[serde(rename_all = "camelCase")]
    struct RustManifest {
        did: String,
        p256_did_key: String,
        #[serde(rename = "p256CommitCID")]
        p256_commit_cid: String,
        #[serde(rename = "p256DataCID")]
        p256_data_cid: String,
        p256_rev: String,
        p256_record_count: usize,
        #[serde(rename = "p256PreviousDataCID")]
        p256_previous_data_cid: String,
        p256_ops: Vec<OpJson>,
        k256_did_key: String,
        #[serde(rename = "k256CommitCID")]
        k256_commit_cid: String,
        #[serde(rename = "k256DataCID")]
        k256_data_cid: String,
        k256_rev: String,
        k256_record_count: usize,
        present_collection: String,
        present_rkey: String,
        present_text: String,
        absent_collection: String,
        absent_rkey: String,
    }

    fn post_val(text: &str) -> Value {
        let mut map = BTreeMap::new();
        map.insert(
            "$type".to_owned(),
            Value::String("app.bsky.feed.post".into()),
        );
        map.insert("text".to_owned(), Value::String(text.into()));
        map.insert(
            "createdAt".to_owned(),
            Value::String("2026-11-25T10:00:00.000Z".into()),
        );
        Value::Object(map)
    }

    fn encode_ops(ops: &[CommitOperation]) -> Vec<OpJson> {
        ops.iter()
            .map(|op| OpJson {
                action: op.action().to_owned(),
                collection: op.path().collection_str().to_owned(),
                rkey: op.path().record_key_str().to_owned(),
                cid: op.cid().map(ToString::to_string),
                prev: op.prev().map(ToString::to_string),
            })
            .collect()
    }

    fn decode_ops(ops: &[OpJson]) -> Vec<CommitOperation> {
        ops.iter()
            .map(|op| {
                let path = RepositoryPath::new(&op.collection, &op.rkey).unwrap();
                match op.action.as_str() {
                    "create" => CommitOperation::Create {
                        path,
                        cid: Cid::parse(op.cid.as_deref().unwrap()).unwrap(),
                    },
                    "update" => CommitOperation::Update {
                        path,
                        cid: Cid::parse(op.cid.as_deref().unwrap()).unwrap(),
                        prev: Cid::parse(op.prev.as_deref().unwrap()).unwrap(),
                    },
                    "delete" => CommitOperation::Delete {
                        path,
                        prev: Cid::parse(op.prev.as_deref().unwrap()).unwrap(),
                    },
                    other => panic!("unexpected op {other}"),
                }
            })
            .collect()
    }

    fn find_compiled_swift_driver(scratch: &Path) -> Option<PathBuf> {
        let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        let package_root = manifest_dir.parent()?.parent()?;
        let bin_dir = package_root.join(".build/out/Products/Debug");
        let module_maps_dir =
            package_root.join(".build/out/Intermediates.noindex/GeneratedModuleMaps");
        if !bin_dir.join("PetrelRepo.swiftmodule").exists() || !module_maps_dir.exists() {
            assert!(
                std::env::var("PETREL_SWIFT_INTEROP_REQUIRED").as_deref() != Ok("1"),
                "PetrelRepo Swift build artifacts missing at {}",
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

    #[allow(clippy::too_many_lines)]
    #[tokio::test]
    async fn bidirectional_live_swift_petrel_repo_and_rust_roundtrip() {
        let scratch = tempfile::tempdir().unwrap();
        let Some(driver) = find_compiled_swift_driver(scratch.path()) else {
            return;
        };

        // === Direction 1: Swift PetrelRepo -> Rust petrel-repo ===
        let swift_dir = scratch.path().join("swift_to_rust");
        std::fs::create_dir_all(&swift_dir).unwrap();
        let emit_out = Command::new(&driver)
            .arg("emit")
            .arg(&swift_dir)
            .output()
            .unwrap();
        assert!(
            emit_out.status.success(),
            "Swift emit failed: {}",
            String::from_utf8_lossy(&emit_out.stderr)
        );

        let manifest: SwiftManifest =
            serde_json::from_slice(&std::fs::read(swift_dir.join("swift_manifest.json")).unwrap())
                .unwrap();
        let did = Did::parse(&manifest.did).unwrap();
        let p256_pub = SigningPublicKey::from_did_key(&manifest.p256_did_key).unwrap();
        let swift_p256_car = std::fs::read(swift_dir.join("swift_p256.car")).unwrap();
        let p256_repo = Repository::open_car(
            &swift_p256_car,
            OpenVerification::SigningKey(p256_pub.clone()),
            Some(&did),
        )
        .await
        .unwrap();
        assert_eq!(p256_repo.commit().cid.to_string(), manifest.p256_commit_cid);
        assert_eq!(
            p256_repo.commit().data_cid.to_string(),
            manifest.p256_data_cid
        );
        assert_eq!(p256_repo.revision().as_str(), manifest.p256_rev);
        assert_eq!(p256_repo.statistics().unwrap().record_count, 3);
        assert_eq!(p256_repo.export_car().await.unwrap(), swift_p256_car);

        let present = Repository::verify_record_proof(
            &std::fs::read(swift_dir.join("swift_p256_proof_present.car")).unwrap(),
            &did,
            &manifest.present_collection,
            &manifest.present_rkey,
            OpenVerification::SigningKey(p256_pub.clone()),
        )
        .await
        .unwrap();
        assert!(present.record.is_some());

        let absent = Repository::verify_record_proof(
            &std::fs::read(swift_dir.join("swift_p256_proof_absent.car")).unwrap(),
            &did,
            &manifest.absent_collection,
            &manifest.absent_rkey,
            OpenVerification::SigningKey(p256_pub.clone()),
        )
        .await
        .unwrap();
        assert!(absent.record.is_none());

        let diff_ops = decode_ops(&manifest.p256_ops);
        CommitDiff::verify_commit_event(
            &std::fs::read(swift_dir.join("swift_p256_diff.car")).unwrap(),
            &Cid::parse(&manifest.p256_commit_cid).unwrap(),
            &did,
            &diff_ops,
            Some(&Cid::parse(&manifest.p256_previous_data_cid).unwrap()),
            &FixedSigningKey::from_public_key(p256_pub),
            &RepositoryLimits::standard(),
            &RepositoryReadPolicy::strict(),
        )
        .await
        .unwrap();

        let k256_pub = SigningPublicKey::from_did_key(&manifest.k256_did_key).unwrap();
        let k256_swift_car = std::fs::read(swift_dir.join("swift_k256.car")).unwrap();
        let k256_repo = Repository::open_car(
            &k256_swift_car,
            OpenVerification::SigningKey(k256_pub),
            Some(&did),
        )
        .await
        .unwrap();
        assert_eq!(k256_repo.commit().cid.to_string(), manifest.k256_commit_cid);
        assert_eq!(
            k256_repo.commit().data_cid.to_string(),
            manifest.k256_data_cid
        );
        assert_eq!(k256_repo.revision().as_str(), manifest.k256_rev);
        assert_eq!(k256_repo.export_car().await.unwrap(), k256_swift_car);

        // === Direction 2: Rust petrel-repo -> Swift PetrelRepo ===
        let rust_dir = scratch.path().join("rust_to_swift");
        std::fs::create_dir_all(&rust_dir).unwrap();
        let p256_signer = P256Keypair::generate().unwrap();
        let k256_signer = K256Keypair::generate().unwrap();

        let r0 = Repository::create(did.clone(), &p256_signer).await.unwrap();
        let res1 = r0
            .commit_writes(
                WriteBatch::new(vec![
                    create_op("app.bsky.feed.post", "3lon5dzeaihj2", &post_val("rust-one"))
                        .unwrap(),
                    create_op("app.bsky.feed.post", "3lon5dzeaihj3", &post_val("rust-two"))
                        .unwrap(),
                    create_op(
                        "app.bsky.feed.post",
                        "3lon5dzeaihj4",
                        &post_val("rust-three"),
                    )
                    .unwrap(),
                ])
                .unwrap(),
                &p256_signer,
            )
            .await
            .unwrap();
        let res2 = res1
            .repository
            .commit_writes(
                WriteBatch::new(vec![
                    WriteOp::Delete {
                        path: RepositoryPath::new("app.bsky.feed.post", "3lon5dzeaihj2").unwrap(),
                    },
                    update_op(
                        "app.bsky.feed.post",
                        "3lon5dzeaihj3",
                        &post_val("rust-two-updated"),
                    )
                    .unwrap(),
                    create_op(
                        "app.bsky.feed.post",
                        "3lon5dzeaihj5",
                        &post_val("rust-four"),
                    )
                    .unwrap(),
                ])
                .unwrap(),
                &p256_signer,
            )
            .await
            .unwrap();

        let r_head = &res2.repository;
        std::fs::write(
            rust_dir.join("rust_p256.car"),
            r_head.export_car().await.unwrap(),
        )
        .unwrap();
        std::fs::write(
            rust_dir.join("rust_proof_present.car"),
            r_head
                .record_proof("app.bsky.feed.post", "3lon5dzeaihj3")
                .await
                .unwrap()
                .car()
                .unwrap(),
        )
        .unwrap();
        std::fs::write(
            rust_dir.join("rust_proof_absent.car"),
            r_head
                .record_proof("app.bsky.feed.post", "3lon5dzeaihj2")
                .await
                .unwrap()
                .car()
                .unwrap(),
        )
        .unwrap();
        std::fs::write(rust_dir.join("rust_diff.car"), res2.diff_car()).unwrap();

        let kr0 = Repository::create(did.clone(), &k256_signer).await.unwrap();
        let kres = kr0
            .commit_writes(
                WriteBatch::new(vec![
                    create_op(
                        "app.bsky.feed.post",
                        "3lon5dzeaihj2",
                        &post_val("rust-k256"),
                    )
                    .unwrap(),
                ])
                .unwrap(),
                &k256_signer,
            )
            .await
            .unwrap();
        let kr_head = &kres.repository;
        std::fs::write(
            rust_dir.join("rust_k256.car"),
            kr_head.export_car().await.unwrap(),
        )
        .unwrap();

        let rust_manifest = RustManifest {
            did: did.as_str().to_owned(),
            p256_did_key: p256_signer.did_key(),
            p256_commit_cid: r_head.commit().cid.to_string(),
            p256_data_cid: r_head.commit().data_cid.to_string(),
            p256_rev: r_head.revision().as_str().to_owned(),
            p256_record_count: r_head.statistics().unwrap().record_count,
            p256_previous_data_cid: res2.previous_data_cid.as_ref().unwrap().to_string(),
            p256_ops: encode_ops(&res2.operations),
            k256_did_key: k256_signer.did_key(),
            k256_commit_cid: kr_head.commit().cid.to_string(),
            k256_data_cid: kr_head.commit().data_cid.to_string(),
            k256_rev: kr_head.revision().as_str().to_owned(),
            k256_record_count: kr_head.statistics().unwrap().record_count,
            present_collection: "app.bsky.feed.post".into(),
            present_rkey: "3lon5dzeaihj3".into(),
            present_text: "rust-two-updated".into(),
            absent_collection: "app.bsky.feed.post".into(),
            absent_rkey: "3lon5dzeaihj2".into(),
        };
        std::fs::write(
            rust_dir.join("rust_manifest.json"),
            serde_json::to_vec_pretty(&rust_manifest).unwrap(),
        )
        .unwrap();

        let verify_out = Command::new(&driver)
            .arg("verify")
            .arg(&rust_dir)
            .output()
            .unwrap();
        assert!(
            verify_out.status.success(),
            "Swift verify of Rust CAR/MST/commit/proof/diff failed: {}",
            String::from_utf8_lossy(&verify_out.stderr)
        );
    }
}
