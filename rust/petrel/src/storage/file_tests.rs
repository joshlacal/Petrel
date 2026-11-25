use std::{fs, path::Path, sync::Arc};

use base64::Engine as _;
use base64::engine::general_purpose::STANDARD;
use tempfile::TempDir;

use super::{FileSecretStore, SecretStore, StoreError};
use crate::storage::contract_tests::secret_store_conformance;

const KEY: [u8; 32] = [23; 32];

fn store_path(root: &TempDir) -> std::path::PathBuf {
    // macOS temporary directory paths can include the /var symlink.
    root.path().canonicalize().unwrap().join("store")
}

#[tokio::test]
async fn encrypted_file_store_contract() {
    let root = tempfile::tempdir().unwrap();
    let path = store_path(&root);
    let store = FileSecretStore::open(&path, &KEY).unwrap();
    secret_store_conformance(&store).await;

    let reopened = FileSecretStore::open(&path, &KEY).unwrap();
    assert_eq!(
        reopened.get("b", "k").await.unwrap().as_deref(),
        Some(b"second".as_slice())
    );
}

#[tokio::test]
async fn file_compare_and_swap_compares_plaintext_and_preserves_newer_writes() {
    let root = tempfile::tempdir().unwrap();
    let path = store_path(&root);
    let store = FileSecretStore::open(&path, &KEY).unwrap();
    let second = FileSecretStore::open(&path, &KEY).unwrap();
    assert!(
        store
            .compare_and_swap("petrel", "item", None, Some(b"first"))
            .await
            .unwrap()
    );
    second.put("petrel", "item", b"newer").await.unwrap();
    assert!(
        !store
            .compare_and_swap("petrel", "item", Some(b"first"), None)
            .await
            .unwrap()
    );
    assert_eq!(
        store.get("petrel", "item").await.unwrap().as_deref(),
        Some(b"newer".as_slice())
    );
    assert!(
        store
            .compare_and_swap("petrel", "item", Some(b"newer"), None)
            .await
            .unwrap()
    );
    assert!(second.get("petrel", "item").await.unwrap().is_none());
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn independently_opened_stores_claim_state_once() {
    let root = tempfile::tempdir().unwrap();
    let path = store_path(&root);
    let first = FileSecretStore::open(&path, &KEY).unwrap();
    let second = FileSecretStore::open(&path, &KEY).unwrap();
    first
        .put("petrel", "flow", b"callback state")
        .await
        .unwrap();

    let barrier = Arc::new(std::sync::Barrier::new(2));
    let consume = |store: FileSecretStore| {
        let barrier = barrier.clone();
        tokio::spawn(async move {
            barrier.wait();
            store.take("petrel", "flow").await.unwrap()
        })
    };
    let one = consume(first);
    let two = consume(second);
    let mut winners = [one.await.unwrap(), two.await.unwrap()]
        .into_iter()
        .flatten();
    assert_eq!(
        winners.next().as_deref(),
        Some(b"callback state".as_slice())
    );
    assert_eq!(winners.next(), None);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn concurrent_different_master_keys_cannot_both_bind_a_directory() {
    let root = tempfile::tempdir().unwrap();
    let path = store_path(&root);
    let barrier = Arc::new(std::sync::Barrier::new(2));
    let open = |key: [u8; 32]| {
        let path = path.clone();
        let barrier = barrier.clone();
        tokio::spawn(async move {
            barrier.wait();
            FileSecretStore::open(path, &key)
        })
    };
    let first = open(KEY);
    let second = open([74; 32]);
    let results = [first.await.unwrap(), second.await.unwrap()];
    assert_eq!(results.iter().filter(|result| result.is_ok()).count(), 1);
    assert!(
        results
            .iter()
            .any(|result| matches!(result, Err(StoreError::KeyMismatch)))
    );
}

#[tokio::test]
async fn wrong_key_preserves_existing_ciphertext() {
    let root = tempfile::tempdir().unwrap();
    let path = store_path(&root);
    let store = FileSecretStore::open(&path, &KEY).unwrap();
    store
        .put("interop", "swift-token", b"credential")
        .await
        .unwrap();

    let snapshot = || {
        fs::read_dir(&path)
            .unwrap()
            .map(|entry| {
                let entry = entry.unwrap();
                (entry.file_name(), fs::read(entry.path()).unwrap())
            })
            .collect::<std::collections::BTreeMap<_, _>>()
    };
    let before = snapshot();
    assert!(matches!(
        FileSecretStore::open(&path, &[86; 32]),
        Err(StoreError::KeyMismatch)
    ));
    assert_eq!(snapshot(), before);
    assert!(
        before
            .values()
            .all(|bytes| !bytes.windows(10).any(|chunk| chunk == b"credential"))
    );
}

#[tokio::test]
async fn corrupt_ciphertext_is_neither_absence_nor_a_reusable_callback() {
    let root = tempfile::tempdir().unwrap();
    let path = store_path(&root);
    let store = FileSecretStore::open(&path, &KEY).unwrap();
    store
        .put("interop", "swift-token", b"single use")
        .await
        .unwrap();
    fs::write(path.join("aW50ZXJvcC5zd2lmdC10b2tlbg"), b"corrupt").unwrap();

    assert!(matches!(
        store.get("interop", "swift-token").await,
        Err(StoreError::Corrupt(_))
    ));
    assert!(matches!(
        store.take("interop", "swift-token").await,
        Err(StoreError::Corrupt(_))
    ));
    assert_eq!(store.get("interop", "swift-token").await.unwrap(), None);
}

#[cfg(unix)]
#[tokio::test]
async fn insecure_permissions_and_symlinks_fail_closed() {
    use std::os::unix::fs::{PermissionsExt as _, symlink};

    let root = tempfile::tempdir().unwrap();
    let path = store_path(&root);
    let store = FileSecretStore::open(&path, &KEY).unwrap();
    assert_eq!(
        fs::metadata(&path).unwrap().permissions().mode() & 0o777,
        0o700
    );
    store
        .put("interop", "swift-token", b"credential")
        .await
        .unwrap();
    let credential = path.join("aW50ZXJvcC5zd2lmdC10b2tlbg");
    assert_eq!(
        fs::metadata(&credential).unwrap().permissions().mode() & 0o777,
        0o600
    );

    fs::set_permissions(&credential, fs::Permissions::from_mode(0o644)).unwrap();
    assert!(store.get("interop", "swift-token").await.is_err());
    assert!(FileSecretStore::open(&path, &KEY).is_err());

    let alias = path.with_file_name("alias");
    symlink(&path, &alias).unwrap();
    assert!(FileSecretStore::open(&alias, &KEY).is_err());
    assert!(FileSecretStore::open(alias.join("nested"), &KEY).is_err());
}

#[tokio::test]
async fn reads_swift_file_encrypted_store_fixture() {
    // The owning Swift FileEncryptedStore generated these bytes with KEY.
    // They cover its directory key marker, filename encoding and combined AES-GCM format.
    let root = tempfile::tempdir().unwrap();
    let path = store_path(&root);
    let store = FileSecretStore::open(&path, &KEY).unwrap();
    store
        .put("interop", "swift-token", b"placeholder")
        .await
        .unwrap();
    fs::write(
        path.join(".petrel-key-check"),
        STANDARD.decode("KX04Hwock1f4uvLndz/niOqK9rEZwDWnSNv93ePxTXYrQtsaLlvdBD3hrcTqa5uJ0S/CfenM3bimxIK7tgN6").unwrap(),
    ).unwrap();
    fs::write(
        path.join("aW50ZXJvcC5zd2lmdC10b2tlbg"),
        STANDARD
            .decode("DSfyUqYH7i0a0Bgzwxchx19LUAqUN5sZvqp0zddzlOhI4+aGG6r2tlE=")
            .unwrap(),
    )
    .unwrap();

    let reopened = FileSecretStore::open(&path, &KEY).unwrap();
    assert_eq!(
        reopened
            .get("interop", "swift-token")
            .await
            .unwrap()
            .as_deref(),
        Some(b"Swift to Rust".as_slice())
    );
}

#[tokio::test]
#[ignore = "requires a directory populated by the Swift FileEncryptedStore interop driver"]
async fn swift_interop_exchange() {
    let root = std::env::var_os("PETREL_TEST_INTEROP_ROOT").unwrap();
    let root = Path::new(&root);
    let from_swift = FileSecretStore::open(root.join("swift-to-rust"), &KEY).unwrap();
    assert_eq!(
        from_swift
            .get("interop", "swift-token")
            .await
            .unwrap()
            .as_deref(),
        Some(b"Swift to Rust".as_slice())
    );
    let to_swift = FileSecretStore::open(root.join("rust-to-swift"), &KEY).unwrap();
    to_swift
        .put("interop", "rust-token", b"Rust to Swift")
        .await
        .unwrap();
}

#[tokio::test]
async fn one_damaged_entry_does_not_lock_the_rest_of_the_store() {
    let root = tempfile::tempdir().unwrap();
    let path = store_path(&root);
    let store = FileSecretStore::open(&path, &KEY).unwrap();
    store
        .put("interop", "swift-token", b"damaged")
        .await
        .unwrap();
    store.put("interop", "other", b"intact").await.unwrap();
    fs::write(path.join("aW50ZXJvcC5zd2lmdC10b2tlbg"), b"corrupt").unwrap();
    drop(store);

    let reopened = FileSecretStore::open(&path, &KEY).unwrap();
    assert_eq!(
        reopened.get("interop", "other").await.unwrap().as_deref(),
        Some(b"intact".as_slice())
    );
    assert!(matches!(
        reopened.get("interop", "swift-token").await,
        Err(StoreError::Corrupt(_))
    ));
    // The wrong key is still refused outright.
    assert!(matches!(
        FileSecretStore::open(&path, &[9; 32]),
        Err(StoreError::KeyMismatch)
    ));
}

#[tokio::test]
async fn v2_envelope_binds_namespace_and_key_as_aad_while_v1_remains_readable() {
    let root = tempfile::tempdir().unwrap();
    let path = store_path(&root);
    let store = FileSecretStore::open(&path, &KEY).unwrap();
    store.put("ns1", "k1", b"secret-v2").await.unwrap();

    // Verify v2 magic prefix on disk.
    let src_name = encode_entry_filename("ns1.k1");
    let raw = fs::read(path.join(&src_name)).unwrap();
    assert!(raw.starts_with(b"PTLSECv2"));

    // Copying/renaming ciphertext to a different key or namespace fails AAD auth.
    for target in ["ns1.k2", "ns2.k1"] {
        let dst_name = encode_entry_filename(target);
        fs::write(path.join(&dst_name), &raw).unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt as _;
            fs::set_permissions(path.join(&dst_name), fs::Permissions::from_mode(0o600)).unwrap();
        }
        let (ns, k) = target.split_once('.').unwrap();
        assert!(
            matches!(store.get(ns, k).await, Err(StoreError::Corrupt(_))),
            "renaming v2 entry to {target} must fail AAD verification"
        );
    }

    // Legacy v1 entry (Swift format) remains readable alongside v2 entries.
    fs::write(
        path.join(encode_entry_filename("interop.swift-token")),
        STANDARD
            .decode("DSfyUqYH7i0a0Bgzwxchx19LUAqUN5sZvqp0zddzlOhI4+aGG6r2tlE=")
            .unwrap(),
    )
    .unwrap();
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt as _;
        fs::set_permissions(
            path.join(encode_entry_filename("interop.swift-token")),
            fs::Permissions::from_mode(0o600),
        )
        .unwrap();
    }
    assert_eq!(
        store
            .get("interop", "swift-token")
            .await
            .unwrap()
            .as_deref(),
        Some(b"Swift to Rust".as_slice())
    );
    assert_eq!(
        store.get("ns1", "k1").await.unwrap().as_deref(),
        Some(b"secret-v2".as_slice())
    );

    // Rewriting a legacy v1 entry migrates it on disk to PTLSECv2 with AAD.
    store
        .put("interop", "swift-token", b"migrated-v2")
        .await
        .unwrap();
    let migrated_raw = fs::read(path.join(encode_entry_filename("interop.swift-token"))).unwrap();
    assert!(migrated_raw.starts_with(b"PTLSECv2"));
    assert_eq!(
        store
            .get("interop", "swift-token")
            .await
            .unwrap()
            .as_deref(),
        Some(b"migrated-v2".as_slice())
    );
}

fn encode_entry_filename(input: &str) -> String {
    base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(input)
}
